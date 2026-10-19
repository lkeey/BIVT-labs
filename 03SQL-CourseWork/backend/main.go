package main

import (
	"context"
	"database/sql"
	"errors"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"strings"
	"sync/atomic"
	"syscall"
	"time"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"
	_ "github.com/microsoft/go-mssqldb"
)

type server struct {
	db     *sql.DB
	auth   *auth.Client
	logger *slog.Logger
	origin string
	rag    *ragProvider
	// One in-flight RAG generation per API process bounds CPU and model load.
	ragBusy atomic.Bool
}

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	dsn := os.Getenv("SQLSERVER_DSN")
	projectID := os.Getenv("FIREBASE_PROJECT_ID")
	origin := os.Getenv("CORS_ORIGIN")
	if dsn == "" || projectID == "" || origin == "" {
		logger.Error("SQLSERVER_DSN, FIREBASE_PROJECT_ID and CORS_ORIGIN are required")
		os.Exit(1)
	}
	parsedOrigin, err := url.Parse(origin)
	if err != nil || parsedOrigin.Host == "" || parsedOrigin.User != nil ||
		parsedOrigin.Path != "" || parsedOrigin.RawQuery != "" || parsedOrigin.Fragment != "" ||
		(parsedOrigin.Scheme != "https" && !(parsedOrigin.Scheme == "http" &&
			strings.HasPrefix(parsedOrigin.Host, "localhost:"))) {
		logger.Error("CORS_ORIGIN must be an exact HTTPS origin or local development origin")
		os.Exit(1)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	app, err := firebase.NewApp(ctx, &firebase.Config{ProjectID: projectID})
	if err != nil {
		logger.Error("Firebase initialization failed", "error", err)
		os.Exit(1)
	}
	authClient, err := app.Auth(ctx)
	if err != nil {
		logger.Error("Firebase Auth initialization failed", "error", err)
		os.Exit(1)
	}
	db, err := sql.Open("sqlserver", dsn)
	if err != nil {
		logger.Error("SQL driver initialization failed", "error", err)
		os.Exit(1)
	}
	defer db.Close()
	db.SetMaxOpenConns(12)
	db.SetMaxIdleConns(6)
	db.SetConnMaxLifetime(30 * time.Minute)
	if err = db.PingContext(ctx); err != nil {
		logger.Error("SQL Server is unavailable", "error", err)
		os.Exit(1)
	}

	rag, ragErr := newRagProvider()
	if ragErr != nil {
		logger.Warn("RAG provider configuration is unavailable", "error", ragErr)
	}
	s := &server{db: db, auth: authClient, logger: logger, origin: origin, rag: rag}
	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8080"
	}
	httpServer := &http.Server{
		Addr:              addr,
		Handler:           s.routes(),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       20 * time.Second,
		WriteTimeout:      100 * time.Second,
		IdleTimeout:       90 * time.Second,
		MaxHeaderBytes:    16 << 10,
	}
	stopCtx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go func() {
		<-stopCtx.Done()
		shutdownCtx, done := context.WithTimeout(context.Background(), 10*time.Second)
		defer done()
		if err := httpServer.Shutdown(shutdownCtx); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("HTTP shutdown failed", "error", err)
		}
	}()
	logger.Info("coursework API listening", "addr", addr)
	if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		logger.Error("HTTP server failed", "error", err)
		os.Exit(1)
	}
}

func (s *server) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		if err := s.db.PingContext(ctx); err != nil {
			problem(w, http.StatusServiceUnavailable, "DATABASE_UNAVAILABLE", "База данных недоступна")
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
	})
	mux.HandleFunc("GET /api/v1/auth/sessions/current", s.withUser(s.currentSession))
	mux.HandleFunc("GET /api/v1/users/{userId}", s.withUser(s.getProfile))
	mux.HandleFunc("GET /api/v1/communities", s.withUser(s.listCommunities))
	mux.HandleFunc("POST /api/v1/communities", s.withUser(s.createCommunity))
	mux.HandleFunc("GET /api/v1/communities/{communityId}", s.withUser(s.getCommunity))
	mux.HandleFunc("POST /api/v1/communities/{communityId}/memberships", s.withUser(s.requestMembership))
	mux.HandleFunc("GET /api/v1/communities/{communityId}/memberships", s.withUser(s.listPendingMemberships))
	mux.HandleFunc("PATCH /api/v1/communities/{communityId}/memberships/{userId}", s.withUser(s.setMembership))
	mux.HandleFunc("DELETE /api/v1/communities/{communityId}/memberships/current", s.withUser(s.leaveCommunity))
	mux.HandleFunc("PUT /api/v1/users/{userId}/follow", s.withUser(s.followUser))
	mux.HandleFunc("DELETE /api/v1/users/{userId}/follow", s.withUser(s.unfollowUser))
	mux.HandleFunc("GET /api/v1/communities/{communityId}/posts", s.withUser(s.listPosts))
	mux.HandleFunc("POST /api/v1/communities/{communityId}/posts", s.withUser(s.createPost))
	mux.HandleFunc("GET /api/v1/posts/{postId}", s.withUser(s.getPost))
	mux.HandleFunc("PATCH /api/v1/posts/{postId}", s.withUser(s.editPost))
	mux.HandleFunc("DELETE /api/v1/posts/{postId}", s.withUser(s.deletePost))
	mux.HandleFunc("GET /api/v1/posts/{postId}/comments", s.withUser(s.listComments))
	mux.HandleFunc("POST /api/v1/posts/{postId}/comments", s.withUser(s.createComment))
	mux.HandleFunc("GET /api/v1/comments/{commentId}", s.withUser(s.getComment))
	mux.HandleFunc("PATCH /api/v1/comments/{commentId}", s.withUser(s.editComment))
	mux.HandleFunc("DELETE /api/v1/comments/{commentId}", s.withUser(s.deleteComment))
	mux.HandleFunc("PUT /api/v1/content/{contentId}/reaction", s.withUser(s.setReaction))
	mux.HandleFunc("DELETE /api/v1/content/{contentId}/reaction", s.withUser(s.removeReaction))
	mux.HandleFunc("PUT /api/v1/content/{contentId}/moderation/hide", s.withUser(s.moderateContent))
	mux.HandleFunc("GET /api/v1/communities/{communityId}/documents", s.withUser(s.listDocuments))
	mux.HandleFunc("POST /api/v1/communities/{communityId}/documents", s.withUser(s.createDocument))
	mux.HandleFunc("GET /api/v1/documents/{documentId}", s.withUser(s.getDocument))
	mux.HandleFunc("POST /api/v1/documents/{documentId}/versions", s.withUser(s.createDocumentVersion))
	mux.HandleFunc("GET /api/v1/documents/{documentId}/file", s.withUser(s.getDocumentFile))
	mux.HandleFunc("GET /api/v1/rag/queries/{queryId}", s.withUser(s.getRagTurn))
	mux.HandleFunc("POST /api/v1/rag/queries", s.withUser(s.createRagQuery))
	mux.HandleFunc("GET /api/v1/feed", s.withUser(s.getFeed))
	return s.withCORS(mux)
}
