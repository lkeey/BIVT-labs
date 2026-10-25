package main

import (
	"database/sql"
	"net/http"
	"time"

	mssql "github.com/microsoft/go-mssqldb"
)

type membership struct {
	CommunityID string `json:"communityId"`
	UserID      string `json:"userId"`
	Status      string `json:"status"`
	Role        string `json:"role"`
}

func (s *server) listPendingMemberships(w http.ResponseWriter, r *http.Request, p principal) {
	communityID, ok := pathID(w, r, "communityId")
	if !ok {
		return
	}
	after, limit, ok := pageParams(w, r)
	if !ok {
		return
	}
	rows, err := s.db.QueryContext(r.Context(), "social.usp_ListPendingMemberships",
		sql.Named("ActorUserID", p.userID), sql.Named("CommunityID", communityID),
		sql.Named("AfterMembershipID", after), sql.Named("Limit", limit+1))
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	defer rows.Close()
	items := make([]membership, 0, limit)
	var lastID int64
	hasMore := false
	for rows.Next() {
		var membershipID, userID int64
		var displayName sql.NullString
		var joinedAt time.Time
		if err := rows.Scan(&membershipID, &userID, &displayName, &joinedAt); err != nil {
			s.sqlProblem(w, err)
			return
		}
		if len(items) == limit {
			hasMore = true
			break
		}
		items = append(items, membership{CommunityID: idString(communityID),
			UserID: idString(userID), Status: "PENDING", Role: "MEMBER"})
		lastID = membershipID
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

func (s *server) setMembership(w http.ResponseWriter, r *http.Request, p principal) {
	communityID, ok := pathID(w, r, "communityId")
	if !ok {
		return
	}
	targetID, ok := pathID(w, r, "userId")
	if !ok {
		return
	}
	var input struct {
		Status string `json:"status"`
		Role   string `json:"role"`
	}
	if !decodeJSON(w, r, &input, 1024) {
		return
	}
	if input.Role == "" {
		input.Role = "MEMBER"
	}
	if (input.Status != "PENDING" && input.Status != "ACTIVE" && input.Status != "BLOCKED") ||
		(input.Role != "ADMIN" && input.Role != "MODERATOR" && input.Role != "MEMBER") {
		problem(w, http.StatusBadRequest, "INVALID_MEMBERSHIP", "Некорректные статус или роль")
		return
	}
	var membershipID int64
	var status, role string
	err := s.db.QueryRowContext(r.Context(), "social.usp_SetMembership",
		sql.Named("ActorUserID", p.userID), sql.Named("CommunityID", communityID),
		sql.Named("TargetUserID", targetID),
		sql.Named("MemberStatus", mssql.VarChar(input.Status)),
		sql.Named("Role", mssql.VarChar(input.Role)),
	).Scan(&membershipID, &status, &role)
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	writeJSON(w, http.StatusOK, membership{CommunityID: idString(communityID),
		UserID: idString(targetID), Status: status, Role: role})
}

func (s *server) requestMembership(w http.ResponseWriter, r *http.Request, p principal) {
	communityID, ok := pathID(w, r, "communityId")
	if !ok {
		return
	}
	var membershipID sql.NullInt64
	var status, role string
	var created bool
	err := s.db.QueryRowContext(r.Context(), "social.usp_RequestMembership",
		sql.Named("UserID", p.userID), sql.Named("CommunityID", communityID),
	).Scan(&membershipID, &status, &role, &created)
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	httpStatus := http.StatusOK
	if created {
		httpStatus = http.StatusCreated
	}
	writeJSON(w, httpStatus, map[string]string{
		"communityId": idString(communityID), "userId": idString(p.userID),
		"status": status, "role": role,
	})
}

func (s *server) leaveCommunity(w http.ResponseWriter, r *http.Request, p principal) {
	communityID, ok := pathID(w, r, "communityId")
	if !ok {
		return
	}
	var membershipID sql.NullInt64
	var status string
	err := s.db.QueryRowContext(r.Context(), "social.usp_LeaveCommunity",
		sql.Named("UserID", p.userID), sql.Named("CommunityID", communityID),
	).Scan(&membershipID, &status)
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *server) setFollow(w http.ResponseWriter, r *http.Request, p principal, enabled bool) {
	targetID, ok := pathID(w, r, "userId")
	if !ok {
		return
	}
	var result bool
	err := s.db.QueryRowContext(r.Context(), "social.usp_SetFollow",
		sql.Named("FollowerUserID", p.userID), sql.Named("FollowedUserID", targetID),
		sql.Named("Enabled", enabled),
	).Scan(&result)
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *server) followUser(w http.ResponseWriter, r *http.Request, p principal) {
	s.setFollow(w, r, p, true)
}

func (s *server) unfollowUser(w http.ResponseWriter, r *http.Request, p principal) {
	s.setFollow(w, r, p, false)
}

func (s *server) editPost(w http.ResponseWriter, r *http.Request, p principal) {
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
	communityID, err := parsePositiveID(item.CommunityID)
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	s.publish(w, r, p, communityID, "POST", nil, &id, http.StatusOK)
}

func (s *server) editComment(w http.ResponseWriter, r *http.Request, p principal) {
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
	postID, err := parsePositiveID(item.PostID)
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	postItem, _, err := scanPost(func(dest ...any) error {
		return s.db.QueryRowContext(r.Context(), "social.usp_GetPost",
			sql.Named("UserID", p.userID), sql.Named("PostID", postID)).Scan(dest...)
	})
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	communityID, err := parsePositiveID(postItem.CommunityID)
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	s.publish(w, r, p, communityID, "COMMENT", &postID, &id, http.StatusOK)
}

func (s *server) revokeContent(w http.ResponseWriter, r *http.Request, p principal, parameter, kind string) {
	id, ok := pathID(w, r, parameter)
	if !ok {
		return
	}
	_, err := s.db.ExecContext(r.Context(), "assistant.usp_RevokeContentAccess",
		sql.Named("ActorUserID", p.userID), sql.Named("ContentID", id),
		sql.Named("NewStatus", mssql.VarChar("HIDDEN")), sql.Named("AllowRag", false),
		sql.Named("ExpectedKind", mssql.VarChar(kind)),
	)
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *server) deletePost(w http.ResponseWriter, r *http.Request, p principal) {
	s.revokeContent(w, r, p, "postId", "POST")
}

func (s *server) deleteComment(w http.ResponseWriter, r *http.Request, p principal) {
	s.revokeContent(w, r, p, "commentId", "COMMENT")
}

func (s *server) setReactionValue(w http.ResponseWriter, r *http.Request, p principal, kind *string) {
	id, ok := pathID(w, r, "contentId")
	if !ok {
		return
	}
	var value any
	if kind != nil {
		value = mssql.VarChar(*kind)
	}
	var saved sql.NullString
	err := s.db.QueryRowContext(r.Context(), "social.usp_SetReaction",
		sql.Named("UserID", p.userID), sql.Named("ContentID", id),
		sql.Named("ReactionType", value),
	).Scan(&saved)
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *server) setReaction(w http.ResponseWriter, r *http.Request, p principal) {
	var input struct {
		Type string `json:"type"`
	}
	if !decodeJSON(w, r, &input, 1024) {
		return
	}
	if input.Type != "LIKE" && input.Type != "HELPFUL" && input.Type != "INSIGHTFUL" {
		problem(w, http.StatusBadRequest, "INVALID_REACTION", "Неизвестный тип реакции")
		return
	}
	s.setReactionValue(w, r, p, &input.Type)
}

func (s *server) removeReaction(w http.ResponseWriter, r *http.Request, p principal) {
	s.setReactionValue(w, r, p, nil)
}

func (s *server) moderateContent(w http.ResponseWriter, r *http.Request, p principal) {
	id, ok := pathID(w, r, "contentId")
	if !ok {
		return
	}
	_, err := s.db.ExecContext(r.Context(), "social.usp_ModerateContent",
		sql.Named("ActorUserID", p.userID), sql.Named("ContentID", id))
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
