package main

import (
	"context"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"mime"
	"net/http"
	"strconv"
	"strings"
	"time"
)

type principal struct {
	userID  int64
	expires time.Time
}

type authedHandler func(http.ResponseWriter, *http.Request, principal)

func (s *server) withUser(next authedHandler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		parts := strings.Fields(r.Header.Get("Authorization"))
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") || len(parts[1]) > 8192 {
			problem(w, http.StatusUnauthorized, "UNAUTHORIZED", "Требуется Firebase ID token")
			return
		}
		ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
		defer cancel()
		token, err := s.auth.VerifyIDTokenAndCheckRevoked(ctx, parts[1])
		if err != nil || token == nil || token.UID == "" {
			problem(w, http.StatusUnauthorized, "UNAUTHORIZED", "Недействительный или отозванный токен")
			return
		}
		var email, displayName any
		if value, ok := token.Claims["email"].(string); ok && value != "" {
			email = value
		}
		if value, ok := token.Claims["name"].(string); ok && value != "" {
			displayName = value
		}
		var userID int64
		err = s.db.QueryRowContext(ctx, "auth.usp_GetOrCreateFirebaseUser",
			sql.Named("FirebaseUID", token.UID),
			sql.Named("Email", email),
			sql.Named("DisplayName", displayName),
		).Scan(&userID)
		if err != nil {
			s.logger.Error("Firebase user mapping failed", "error", err)
			problem(w, http.StatusForbidden, "ACCOUNT_UNAVAILABLE", "Учётная запись недоступна")
			return
		}
		if userID <= 0 {
			problem(w, http.StatusForbidden, "ACCOUNT_UNAVAILABLE", "Учётная запись недоступна")
			return
		}
		p := principal{userID: userID, expires: time.Unix(token.Expires, 0).UTC()}
		next(w, r, p)
	}
}

func (s *server) withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin != "" && origin != s.origin {
			problem(w, http.StatusForbidden, "ORIGIN_DENIED", "Источник запроса не разрешён")
			return
		}
		if origin == s.origin {
			w.Header().Set("Vary", "Origin")
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
			w.Header().Set("Access-Control-Max-Age", "600")
		}
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		ctx, cancel := context.WithTimeout(r.Context(), 90*time.Second)
		defer cancel()
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func problem(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, map[string]string{"code": code, "message": message})
}

func decodeJSON(w http.ResponseWriter, r *http.Request, target any, maxBytes int64) bool {
	mediaType, _, err := mime.ParseMediaType(r.Header.Get("Content-Type"))
	if err != nil || mediaType != "application/json" {
		problem(w, http.StatusUnsupportedMediaType, "JSON_REQUIRED", "Ожидается application/json")
		return false
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxBytes)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		var tooLarge *http.MaxBytesError
		if errors.As(err, &tooLarge) {
			problem(w, http.StatusRequestEntityTooLarge, "BODY_TOO_LARGE", "Тело запроса слишком большое")
			return false
		}
		problem(w, http.StatusBadRequest, "INVALID_JSON", "Некорректный JSON")
		return false
	}
	var trailing any
	if err := decoder.Decode(&trailing); !errors.Is(err, io.EOF) {
		problem(w, http.StatusBadRequest, "INVALID_JSON", "Дополнительные данные после JSON")
		return false
	}
	return true
}

func pathID(w http.ResponseWriter, r *http.Request, name string) (int64, bool) {
	id, err := strconv.ParseInt(r.PathValue(name), 10, 64)
	if err != nil || id <= 0 {
		problem(w, http.StatusBadRequest, "INVALID_ID", "Некорректный идентификатор")
		return 0, false
	}
	return id, true
}

func pageParams(w http.ResponseWriter, r *http.Request) (after int64, limit int, ok bool) {
	limit = 20
	if raw := r.URL.Query().Get("limit"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil || parsed < 1 || parsed > 50 {
			problem(w, http.StatusBadRequest, "INVALID_PAGE", "limit должен быть от 1 до 50")
			return 0, 0, false
		}
		limit = parsed
	}
	if raw := r.URL.Query().Get("cursor"); raw != "" {
		decoded, err := base64.RawURLEncoding.DecodeString(raw)
		if err != nil {
			problem(w, http.StatusBadRequest, "INVALID_CURSOR", "Некорректный курсор")
			return 0, 0, false
		}
		after, err = strconv.ParseInt(string(decoded), 10, 64)
		if err != nil || after <= 0 {
			problem(w, http.StatusBadRequest, "INVALID_CURSOR", "Некорректный курсор")
			return 0, 0, false
		}
	}
	return after, limit, true
}

func nextCursor(id int64) string {
	return base64.RawURLEncoding.EncodeToString([]byte(strconv.FormatInt(id, 10)))
}

func idString(id int64) string { return strconv.FormatInt(id, 10) }

func parsePositiveID(raw string) (int64, error) {
	id, err := strconv.ParseInt(raw, 10, 64)
	if err != nil || id <= 0 {
		return 0, errors.New("invalid positive ID")
	}
	return id, nil
}

func nullableString(value sql.NullString) string {
	if value.Valid {
		return value.String
	}
	return ""
}

func (s *server) sqlProblem(w http.ResponseWriter, err error) {
	var numbered interface{ SQLErrorNumber() int32 }
	if errors.As(err, &numbered) {
		switch numbered.SQLErrorNumber() {
		case 2601, 2627, 51154, 51177, 51182:
			problem(w, http.StatusConflict, "CONFLICT", "Данные уже существуют")
			return
		case 51005, 51015, 51037, 51070, 51071, 51151, 51152, 51163,
			51165, 51172, 51173, 51175, 51201, 51203, 51205, 51207, 51209:
			problem(w, http.StatusNotFound, "NOT_FOUND", "Материал отсутствует или недоступен")
			return
		case 51001, 51002, 51003, 51009, 51014, 51035, 51155, 51156, 51157,
			51168, 51171, 51178, 51179, 51180, 51202, 51204, 51206, 51208:
			problem(w, http.StatusBadRequest, "INVALID_REQUEST", "Некорректные данные")
			return
		case 51004, 51006, 51007, 51011, 51036, 51158, 51159, 51160,
			51161, 51162, 51164, 51166, 51170, 51176:
			problem(w, http.StatusForbidden, "FORBIDDEN", "Операция запрещена")
			return
		case 51008:
			problem(w, http.StatusUnsupportedMediaType, "UNSUPPORTED_MEDIA", "Неподдерживаемый формат документа")
			return
		case 51010:
			problem(w, http.StatusRequestEntityTooLarge, "DOCUMENT_TOO_LARGE", "Размер документа превышает 10 МиБ")
			return
		case 51200, 51032:
			problem(w, http.StatusForbidden, "ACCOUNT_UNAVAILABLE", "Учётная запись недоступна")
			return
		}
	}
	if errors.Is(err, sql.ErrNoRows) {
		problem(w, http.StatusNotFound, "NOT_FOUND", "Материал отсутствует или недоступен")
		return
	}
	s.logger.Error("SQL operation failed", "error", err)
	problem(w, http.StatusInternalServerError, "DATABASE_ERROR", "Ошибка базы данных")
}
