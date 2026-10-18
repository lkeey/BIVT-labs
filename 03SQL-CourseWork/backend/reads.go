package main

import (
	"database/sql"
	"net/http"
	"time"
)

type userProfile struct {
	UserID       string `json:"userId"`
	DisplayName  string `json:"displayName"`
	Bio          string `json:"bio"`
	FollowedByMe bool   `json:"followedByMe"`
}

func (s *server) profile(r *http.Request, viewerID, targetID int64) (userProfile, error) {
	var id int64
	var name string
	var bio sql.NullString
	var followed bool
	err := s.db.QueryRowContext(r.Context(), "auth.usp_GetUserProfile",
		sql.Named("UserID", viewerID), sql.Named("ProfileUserID", targetID),
	).Scan(&id, &name, &bio, &followed)
	return userProfile{UserID: idString(id), DisplayName: name, Bio: nullableString(bio), FollowedByMe: followed}, err
}

func (s *server) currentSession(w http.ResponseWriter, r *http.Request, p principal) {
	profile, err := s.profile(r, p.userID, p.userID)
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"expiresAt": p.expires.Format(time.RFC3339), "user": profile})
}

func (s *server) getProfile(w http.ResponseWriter, r *http.Request, p principal) {
	id, ok := pathID(w, r, "userId")
	if !ok {
		return
	}
	profile, err := s.profile(r, p.userID, id)
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	writeJSON(w, http.StatusOK, profile)
}

type community struct {
	CommunityID      string `json:"communityId"`
	Slug             string `json:"slug"`
	Name             string `json:"name"`
	Description      string `json:"description"`
	Visibility       string `json:"visibility"`
	OwnerUserID      string `json:"ownerUserId"`
	MembershipStatus string `json:"membershipStatus"`
}

func scanCommunity(scan func(...any) error) (community, int64, error) {
	var id, owner int64
	var slug, name, visibility, membership string
	var description sql.NullString
	err := scan(&id, &slug, &name, &description, &visibility, &owner, &membership)
	return community{
		CommunityID: idString(id), Slug: slug, Name: name,
		Description: nullableString(description), Visibility: visibility,
		OwnerUserID: idString(owner), MembershipStatus: membership,
	}, id, err
}

func (s *server) listCommunities(w http.ResponseWriter, r *http.Request, p principal) {
	after, limit, ok := pageParams(w, r)
	if !ok {
		return
	}
	rows, err := s.db.QueryContext(r.Context(), "social.usp_ListCommunities",
		sql.Named("UserID", p.userID), sql.Named("AfterCommunityID", after), sql.Named("Limit", limit))
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	defer rows.Close()
	items := make([]community, 0, limit)
	var lastID int64
	hasMore := false
	for rows.Next() {
		item, id, err := scanCommunity(rows.Scan)
		if err != nil {
			s.sqlProblem(w, err)
			return
		}
		if len(items) == limit {
			hasMore = true
			break
		}
		items = append(items, item)
		lastID = id
	}
	if err := rows.Err(); err != nil {
		s.sqlProblem(w, err)
		return
	}
	var cursor *string
	if hasMore {
		c := nextCursor(lastID)
		cursor = &c
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items, "nextCursor": cursor})
}

func (s *server) getCommunity(w http.ResponseWriter, r *http.Request, p principal) {
	id, ok := pathID(w, r, "communityId")
	if !ok {
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
	writeJSON(w, http.StatusOK, item)
}

type post struct {
	ContentID    string `json:"contentId"`
	CommunityID  string `json:"communityId"`
	AuthorUserID string `json:"authorUserId"`
	Body         string `json:"body"`
	PublishedAt  string `json:"publishedAt"`
}

func scanPost(scan func(...any) error) (post, int64, error) {
	var id, communityID, authorID int64
	var body string
	var publishedAt time.Time
	err := scan(&id, &communityID, &authorID, &body, &publishedAt)
	return post{ContentID: idString(id), CommunityID: idString(communityID),
		AuthorUserID: idString(authorID), Body: body, PublishedAt: publishedAt.UTC().Format(time.RFC3339Nano)}, id, err
}

func (s *server) listPosts(w http.ResponseWriter, r *http.Request, p principal) {
	communityID, ok := pathID(w, r, "communityId")
	if !ok {
		return
	}
	after, limit, ok := pageParams(w, r)
	if !ok {
		return
	}
	rows, err := s.db.QueryContext(r.Context(), "social.usp_ListPosts",
		sql.Named("UserID", p.userID), sql.Named("CommunityID", communityID),
		sql.Named("AfterContentID", after), sql.Named("Limit", limit))
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	defer rows.Close()
	items := make([]post, 0, limit)
	var lastID int64
	for rows.Next() {
		item, id, err := scanPost(rows.Scan)
		if err != nil {
			s.sqlProblem(w, err)
			return
		}
		if len(items) == limit {
			c := nextCursor(lastID)
			writeJSON(w, http.StatusOK, map[string]any{"items": items, "nextCursor": c})
			return
		}
		items = append(items, item)
		lastID = id
	}
	if err := rows.Err(); err != nil {
		s.sqlProblem(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items, "nextCursor": nil})
}

func (s *server) getPost(w http.ResponseWriter, r *http.Request, p principal) {
	id, ok := pathID(w, r, "postId")
	if !ok {
		return
	}
	item, _, err := scanPost(func(dest ...any) error {
		return s.db.QueryRowContext(r.Context(), "social.usp_GetPost",
			sql.Named("UserID", p.userID), sql.Named("PostID", id)).Scan(dest...)
	})
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	writeJSON(w, http.StatusOK, item)
}

type comment struct {
	ContentID    string `json:"contentId"`
	PostID       string `json:"postId"`
	AuthorUserID string `json:"authorUserId"`
	Body         string `json:"body"`
	PublishedAt  string `json:"publishedAt"`
}

func scanComment(scan func(...any) error) (comment, int64, error) {
	var id, postID, authorID int64
	var body string
	var publishedAt time.Time
	err := scan(&id, &postID, &authorID, &body, &publishedAt)
	return comment{ContentID: idString(id), PostID: idString(postID),
		AuthorUserID: idString(authorID), Body: body, PublishedAt: publishedAt.UTC().Format(time.RFC3339Nano)}, id, err
}

func (s *server) listComments(w http.ResponseWriter, r *http.Request, p principal) {
	postID, ok := pathID(w, r, "postId")
	if !ok {
		return
	}
	after, limit, ok := pageParams(w, r)
	if !ok {
		return
	}
	rows, err := s.db.QueryContext(r.Context(), "social.usp_ListComments",
		sql.Named("UserID", p.userID), sql.Named("PostID", postID),
		sql.Named("AfterContentID", after), sql.Named("Limit", limit))
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	defer rows.Close()
	items := make([]comment, 0, limit)
	var lastID int64
	for rows.Next() {
		item, id, err := scanComment(rows.Scan)
		if err != nil {
			s.sqlProblem(w, err)
			return
		}
		if len(items) == limit {
			c := nextCursor(lastID)
			writeJSON(w, http.StatusOK, map[string]any{"items": items, "nextCursor": c})
			return
		}
		items = append(items, item)
		lastID = id
	}
	if err := rows.Err(); err != nil {
		s.sqlProblem(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items, "nextCursor": nil})
}

func (s *server) getComment(w http.ResponseWriter, r *http.Request, p principal) {
	id, ok := pathID(w, r, "commentId")
	if !ok {
		return
	}
	item, _, err := scanComment(func(dest ...any) error {
		return s.db.QueryRowContext(r.Context(), "social.usp_GetComment",
			sql.Named("UserID", p.userID), sql.Named("CommentID", id)).Scan(dest...)
	})
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	writeJSON(w, http.StatusOK, item)
}

type document struct {
	ContentID        string `json:"contentId"`
	CommunityID      string `json:"communityId"`
	AuthorUserID     string `json:"authorUserId"`
	Title            string `json:"title"`
	MimeType         string `json:"mimeType"`
	VersionNo        int    `json:"versionNo"`
	ProcessingStatus string `json:"processingStatus"`
}

func scanDocument(scan func(...any) error) (document, int64, error) {
	var id, communityID, authorID int64
	var title, mimeType, status string
	var versionNo int
	err := scan(&id, &communityID, &authorID, &title, &mimeType, &versionNo, &status)
	return document{ContentID: idString(id), CommunityID: idString(communityID),
		AuthorUserID: idString(authorID), Title: title, MimeType: mimeType,
		VersionNo: versionNo, ProcessingStatus: status}, id, err
}

func (s *server) listDocuments(w http.ResponseWriter, r *http.Request, p principal) {
	communityID, ok := pathID(w, r, "communityId")
	if !ok {
		return
	}
	after, limit, ok := pageParams(w, r)
	if !ok {
		return
	}
	rows, err := s.db.QueryContext(r.Context(), "knowledge.usp_ListDocuments",
		sql.Named("UserID", p.userID), sql.Named("CommunityID", communityID),
		sql.Named("AfterContentID", after), sql.Named("Limit", limit))
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	defer rows.Close()
	items := make([]document, 0, limit)
	var lastID int64
	for rows.Next() {
		item, id, err := scanDocument(rows.Scan)
		if err != nil {
			s.sqlProblem(w, err)
			return
		}
		if len(items) == limit {
			c := nextCursor(lastID)
			writeJSON(w, http.StatusOK, map[string]any{"items": items, "nextCursor": c})
			return
		}
		items = append(items, item)
		lastID = id
	}
	if err := rows.Err(); err != nil {
		s.sqlProblem(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items, "nextCursor": nil})
}

func (s *server) getDocument(w http.ResponseWriter, r *http.Request, p principal) {
	id, ok := pathID(w, r, "documentId")
	if !ok {
		return
	}
	item, _, err := scanDocument(func(dest ...any) error {
		return s.db.QueryRowContext(r.Context(), "knowledge.usp_GetDocument",
			sql.Named("UserID", p.userID), sql.Named("DocumentID", id)).Scan(dest...)
	})
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	writeJSON(w, http.StatusOK, item)
}

type feedItem struct {
	Rank         int     `json:"rank"`
	ContentID    string  `json:"contentId"`
	Kind         string  `json:"kind"`
	CommunityID  string  `json:"communityId"`
	AuthorUserID string  `json:"authorUserId"`
	Score        float64 `json:"score"`
	ReasonCode   string  `json:"reasonCode"`
	ReasonText   string  `json:"reasonText"`
}

func (s *server) getFeed(w http.ResponseWriter, r *http.Request, p principal) {
	if r.URL.Query().Has("cursor") {
		problem(w, http.StatusBadRequest, "INVALID_PAGE", "Лента рассчитывается заново и не поддерживает курсор")
		return
	}
	_, limit, ok := pageParams(w, r)
	if !ok {
		return
	}
	rows, err := s.db.QueryContext(r.Context(), "assistant.usp_GenerateRecommendations",
		sql.Named("UserID", p.userID), sql.Named("Limit", limit))
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	defer rows.Close()
	items := make([]feedItem, 0, limit)
	for rows.Next() {
		var rank int
		var contentID, communityID, authorID int64
		var score float64
		var kind, reasonCode, reasonText string
		if err := rows.Scan(&rank, &contentID, &kind, &score, &reasonCode, &reasonText, &communityID, &authorID); err != nil {
			s.sqlProblem(w, err)
			return
		}
		items = append(items, feedItem{Rank: rank, ContentID: idString(contentID), Kind: kind,
			CommunityID: idString(communityID), AuthorUserID: idString(authorID),
			Score: score, ReasonCode: reasonCode, ReasonText: reasonText})
	}
	if err := rows.Err(); err != nil {
		s.sqlProblem(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}
