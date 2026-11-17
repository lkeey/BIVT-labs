package main

import (
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"
)

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func TestFirebaseTokenVerification(t *testing.T) {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now().Unix()
	for _, test := range []struct {
		name, audience, account      string
		expired, unsigned, wantError bool
	}{
		{name: "valid", audience: "coursework-test", account: `{"users":[{"localId":"user1","validSince":"1"}]}`},
		{name: "wrong project", audience: "other", wantError: true},
		{name: "expired", audience: "coursework-test", expired: true, wantError: true},
		{name: "unsigned emulator token rejected", audience: "coursework-test", unsigned: true, wantError: true},
		{name: "disabled", audience: "coursework-test", account: `{"users":[{"localId":"user1","validSince":"1","disabled":true}]}`, wantError: true},
		{name: "revoked", audience: "coursework-test", account: `{"users":[{"localId":"user1","validSince":"9999999999"}]}`, wantError: true},
	} {
		t.Run(test.name, func(t *testing.T) {
			v := newFirebaseTokenVerifier("coursework-test", "public-test-key")
			v.keys = map[string]*rsa.PublicKey{"test": &key.PublicKey}
			v.keysUntil = time.Now().Add(time.Hour)
			v.client.Transport = roundTripFunc(func(r *http.Request) (*http.Response, error) {
				if r.URL.Host != "identitytoolkit.googleapis.com" || r.URL.Path != "/v1/accounts:lookup" {
					t.Fatalf("unexpected URL: %s", r.URL)
				}
				return &http.Response{StatusCode: 200, Body: io.NopCloser(strings.NewReader(test.account)), Header: make(http.Header)}, nil
			})
			alg := "RS256"
			if test.unsigned {
				alg = "none"
			}
			header, _ := json.Marshal(map[string]any{"alg": alg, "kid": "test"})
			exp := now + 3600
			if test.expired {
				exp = now - 1
			}
			claims, _ := json.Marshal(map[string]any{"aud": test.audience, "iss": "https://securetoken.google.com/coursework-test", "sub": "user1", "exp": exp, "iat": now - 10, "auth_time": now - 20})
			token := base64.RawURLEncoding.EncodeToString(header) + "." + base64.RawURLEncoding.EncodeToString(claims)
			digest := sha256.Sum256([]byte(token))
			signature, err := rsa.SignPKCS1v15(rand.Reader, key, crypto.SHA256, digest[:])
			if err != nil {
				t.Fatal(err)
			}
			token += "." + base64.RawURLEncoding.EncodeToString(signature)
			result, err := v.VerifyIDTokenAndCheckRevoked(context.Background(), token)
			if (err != nil) != test.wantError {
				t.Fatalf("result=%v error=%v", result, err)
			}
			if err == nil && result.UID != "user1" {
				t.Fatal("wrong user")
			}
		})
	}
}
