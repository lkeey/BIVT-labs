package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestRemovedAssistantRoutes(t *testing.T) {
	s := &server{origin: "http://localhost:8080"}
	for _, path := range []string{"/api/v1/rag/queries", "/api/v1/rag/queries/1"} {
		for _, method := range []string{http.MethodGet, http.MethodPost} {
			response := httptest.NewRecorder()
			s.routes().ServeHTTP(response, httptest.NewRequest(method, path, nil))
			if response.Code != http.StatusNotFound {
				t.Fatalf("%s %s: got %d", method, path, response.Code)
			}
		}
	}
}

func TestSocialRoutesRequireAuthentication(t *testing.T) {
	s := &server{origin: "http://localhost:8080"}
	for _, path := range []string{"/api/v1/feed", "/api/v1/communities", "/api/v1/documents/1", "/api/v1/documents/1/file"} {
		response := httptest.NewRecorder()
		s.routes().ServeHTTP(response, httptest.NewRequest(http.MethodGet, path, nil))
		if response.Code != http.StatusUnauthorized {
			t.Fatalf("%s: got %d", path, response.Code)
		}
	}
}
