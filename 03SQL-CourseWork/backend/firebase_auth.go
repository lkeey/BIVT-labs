package main

import (
	"bytes"
	"context"
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"
)

const firebaseCertsURL = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"
const firebaseAccountsURL = "https://identitytoolkit.googleapis.com/v1/accounts:lookup"

type verifiedFirebaseToken struct {
	UID     string
	Expires int64
	Claims  map[string]any
}

type firebaseTokenVerifier struct {
	projectID string
	apiKey    string
	client    *http.Client
	mu        sync.Mutex
	keys      map[string]*rsa.PublicKey
	keysUntil time.Time
}

func newFirebaseTokenVerifier(projectID, apiKey string) *firebaseTokenVerifier {
	return &firebaseTokenVerifier{
		projectID: projectID,
		apiKey:    apiKey,
		client: &http.Client{
			Timeout: 5 * time.Second,
			CheckRedirect: func(*http.Request, []*http.Request) error {
				return errors.New("Firebase endpoint redirected")
			},
		},
	}
}

func (v *firebaseTokenVerifier) VerifyIDTokenAndCheckRevoked(ctx context.Context, raw string) (*verifiedFirebaseToken, error) {
	parts := strings.Split(raw, ".")
	if len(parts) != 3 {
		return nil, errors.New("invalid Firebase ID token")
	}
	headerBytes, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return nil, errors.New("invalid Firebase ID token header")
	}
	var header struct {
		Algorithm string `json:"alg"`
		KeyID     string `json:"kid"`
	}
	if err := json.Unmarshal(headerBytes, &header); err != nil || header.Algorithm != "RS256" || header.KeyID == "" {
		return nil, errors.New("invalid Firebase ID token header")
	}
	key, err := v.publicKey(ctx, header.KeyID)
	if err != nil {
		return nil, err
	}
	signature, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		return nil, errors.New("invalid Firebase ID token signature")
	}
	digest := sha256.Sum256([]byte(parts[0] + "." + parts[1]))
	if err := rsa.VerifyPKCS1v15(key, crypto.SHA256, digest[:], signature); err != nil {
		return nil, errors.New("invalid Firebase ID token signature")
	}
	claimsBytes, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil, errors.New("invalid Firebase ID token claims")
	}
	var claims struct {
		Audience        string `json:"aud"`
		Issuer          string `json:"iss"`
		Subject         string `json:"sub"`
		Expires         int64  `json:"exp"`
		IssuedAt        int64  `json:"iat"`
		AuthenticatedAt int64  `json:"auth_time"`
		Email           string `json:"email"`
		Name            string `json:"name"`
	}
	if err := json.Unmarshal(claimsBytes, &claims); err != nil {
		return nil, errors.New("invalid Firebase ID token claims")
	}
	now := time.Now().Unix()
	if claims.Audience != v.projectID || claims.Issuer != "https://securetoken.google.com/"+v.projectID ||
		claims.Subject == "" || claims.Expires <= now || claims.IssuedAt <= 0 || claims.IssuedAt > now ||
		claims.AuthenticatedAt <= 0 || claims.AuthenticatedAt > now || claims.AuthenticatedAt > claims.IssuedAt {
		return nil, errors.New("invalid Firebase ID token claims")
	}
	if err := v.checkAccount(ctx, raw, claims.Subject, claims.AuthenticatedAt); err != nil {
		return nil, err
	}
	return &verifiedFirebaseToken{
		UID:     claims.Subject,
		Expires: claims.Expires,
		Claims: map[string]any{
			"email": claims.Email,
			"name":  claims.Name,
		},
	}, nil
}

func (v *firebaseTokenVerifier) publicKey(ctx context.Context, kid string) (*rsa.PublicKey, error) {
	v.mu.Lock()
	defer v.mu.Unlock()
	if time.Now().Before(v.keysUntil) {
		if key := v.keys[kid]; key != nil {
			return key, nil
		}
		return nil, errors.New("unknown Firebase public key")
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, firebaseCertsURL, nil)
	if err != nil {
		return nil, err
	}
	resp, err := v.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, errors.New("Firebase public keys unavailable")
	}
	var certs map[string]string
	if err := json.NewDecoder(io.LimitReader(resp.Body, 64<<10)).Decode(&certs); err != nil || len(certs) == 0 {
		return nil, errors.New("invalid Firebase public keys")
	}
	keys := make(map[string]*rsa.PublicKey, len(certs))
	for id, encoded := range certs {
		block, _ := pem.Decode([]byte(encoded))
		if block == nil || block.Type != "CERTIFICATE" {
			return nil, errors.New("invalid Firebase public certificate")
		}
		certificate, err := x509.ParseCertificate(block.Bytes)
		if err != nil {
			return nil, errors.New("invalid Firebase public certificate")
		}
		key, ok := certificate.PublicKey.(*rsa.PublicKey)
		if !ok {
			return nil, errors.New("invalid Firebase public key")
		}
		keys[id] = key
	}
	maxAge := 0
	for _, directive := range strings.Split(resp.Header.Get("Cache-Control"), ",") {
		if value, ok := strings.CutPrefix(strings.TrimSpace(directive), "max-age="); ok {
			if parsed, err := strconv.Atoi(value); err == nil && parsed > 0 {
				maxAge = min(parsed, 24*60*60)
			}
		}
	}
	v.keys = keys
	v.keysUntil = time.Now().Add(time.Duration(maxAge) * time.Second)
	if key := keys[kid]; key != nil {
		return key, nil
	}
	return nil, errors.New("unknown Firebase public key")
}

func (v *firebaseTokenVerifier) checkAccount(ctx context.Context, idToken, uid string, authTime int64) error {
	payload, err := json.Marshal(map[string]string{"idToken": idToken})
	if err != nil {
		return err
	}
	endpoint := firebaseAccountsURL + "?key=" + url.QueryEscape(v.apiKey)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(payload))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := v.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return errors.New("Firebase account lookup rejected the token")
	}
	var result struct {
		Users []struct {
			UID        string `json:"localId"`
			ValidSince string `json:"validSince"`
			Disabled   bool   `json:"disabled"`
		} `json:"users"`
	}
	if err := json.NewDecoder(io.LimitReader(resp.Body, 64<<10)).Decode(&result); err != nil || len(result.Users) != 1 {
		return errors.New("invalid Firebase account lookup response")
	}
	account := result.Users[0]
	validSince, err := strconv.ParseInt(account.ValidSince, 10, 64)
	if err != nil || validSince < 0 || account.UID != uid || account.Disabled || authTime < validSince {
		return errors.New("Firebase account unavailable or token revoked")
	}
	return nil
}
