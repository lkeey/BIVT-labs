package main

import (
	"database/sql"
	"net/http"
	"regexp"
	"strings"
	"unicode/utf16"

	mssql "github.com/microsoft/go-mssqldb"
)

var slugPattern = regexp.MustCompile(`^[a-z0-9-]{3,100}$`)

type communityInput struct {
	Slug        string `json:"slug"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Visibility  string `json:"visibility"`
}

func (s *server) createCommunity(w http.ResponseWriter, r *http.Request, p principal) {
	var input communityInput
	if !decodeJSON(w, r, &input, 4096) {
		return
	}
	if !slugPattern.MatchString(input.Slug) || strings.TrimSpace(input.Name) == "" ||
		len(utf16.Encode([]rune(input.Name))) > 160 || len(utf16.Encode([]rune(input.Description))) > 1000 ||
		(input.Visibility != "PUBLIC" && input.Visibility != "PRIVATE") {
		problem(w, http.StatusBadRequest, "INVALID_COMMUNITY", "Некорректные параметры сообщества")
		return
	}
	var id int64
	var created bool
	err := s.db.QueryRowContext(r.Context(), "social.usp_CreateCommunity",
		sql.Named("OwnerUserID", p.userID), sql.Named("Slug", input.Slug),
		sql.Named("Name", input.Name), sql.Named("Visibility", mssql.VarChar(input.Visibility)),
		sql.Named("Description", input.Description),
	).Scan(&id, &created)
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	item, _, err := scanCommunity(func(dest ...any) error {
		return s.db.QueryRowContext(r.Context(), "social.usp_GetCommunity",
			sql.Named("UserID", p.userID), sql.Named("CommunityID", id)).Scan(dest...)
	})
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	status := http.StatusOK
	if created {
		status = http.StatusCreated
	}
	writeJSON(w, status, item)
}

type textInput struct {
	Body string `json:"body"`
}

func readTextInput(w http.ResponseWriter, r *http.Request) (string, bool) {
	var input textInput
	if !decodeJSON(w, r, &input, 64<<10) {
		return "", false
	}
	if strings.TrimSpace(input.Body) == "" || len(utf16.Encode([]rune(input.Body))) > 20000 {
		problem(w, http.StatusBadRequest, "INVALID_BODY", "Текст пуст или длиннее 20000 символов UTF-16")
		return "", false
	}
	return input.Body, true
}

func (s *server) publish(w http.ResponseWriter, r *http.Request, p principal, communityID int64, kind string, postID *int64, contentID *int64, status int) {
	body, ok := readTextInput(w, r)
	if !ok {
		return
	}
	var id, sourceRevisionID int64
	err := s.db.QueryRowContext(r.Context(), "social.usp_PublishContent",
		sql.Named("AuthorUserID", p.userID), sql.Named("CommunityID", communityID),
		sql.Named("Kind", mssql.VarChar(kind)), sql.Named("Body", body),
		sql.Named("ParentPostID", postID), sql.Named("ContentID", contentID),
	).Scan(&id, &sourceRevisionID)
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	writeJSON(w, status, map[string]string{
		"contentId": idString(id), "sourceRevisionId": idString(sourceRevisionID), "indexStatus": "PENDING",
	})
}

func (s *server) createPost(w http.ResponseWriter, r *http.Request, p principal) {
	communityID, ok := pathID(w, r, "communityId")
	if !ok {
		return
	}
	s.publish(w, r, p, communityID, "POST", nil, nil, http.StatusCreated)
}

func (s *server) createComment(w http.ResponseWriter, r *http.Request, p principal) {
	postID, ok := pathID(w, r, "postId")
	if !ok {
		return
	}
	item, _, err := scanPost(func(dest ...any) error {
		return s.db.QueryRowContext(r.Context(), "social.usp_GetPost",
			sql.Named("UserID", p.userID), sql.Named("PostID", postID)).Scan(dest...)
	})
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	communityID, err := parsePositiveID(item.CommunityID)
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	s.publish(w, r, p, communityID, "COMMENT", &postID, nil, http.StatusCreated)
}
