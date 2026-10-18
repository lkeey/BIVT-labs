package main

import (
	"database/sql"
	"net/http"
)

type citation struct {
	CitationID   string `json:"citationId"`
	ContentID    string `json:"contentId"`
	Kind         string `json:"kind"`
	Title        string `json:"title"`
	AuthorUserID string `json:"authorUserId"`
	Quote        string `json:"quote"`
	PageNo       *int   `json:"pageNo"`
	StartOffset  int    `json:"startOffset"`
	EndOffset    int    `json:"endOffset"`
	SourcePath   string `json:"sourcePath"`
}

func (s *server) getRagTurn(w http.ResponseWriter, r *http.Request, p principal) {
	id, ok := pathID(w, r, "queryId")
	if !ok {
		return
	}
	rows, err := s.db.QueryContext(r.Context(), "assistant.usp_GetRagTurn",
		sql.Named("UserID", p.userID), sql.Named("TurnID", id))
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	defer rows.Close()
	if !rows.Next() {
		if err := rows.Err(); err != nil {
			s.sqlProblem(w, err)
		} else {
			problem(w, http.StatusNotFound, "NOT_FOUND", "Запрос не найден")
		}
		return
	}
	var turnID int64
	var question, status string
	var answer, model sql.NullString
	var completedAt sql.NullTime
	if err := rows.Scan(&turnID, &question, &status, &answer, &model, &completedAt); err != nil {
		s.sqlProblem(w, err)
		return
	}
	if status == "REVOKED" {
		problem(w, http.StatusGone, "SOURCES_REVOKED", "Источники ответа больше недоступны")
		return
	}
	citations := make([]citation, 0)
	if !rows.NextResultSet() {
		if err := rows.Err(); err != nil {
			s.sqlProblem(w, err)
		} else {
			problem(w, http.StatusInternalServerError, "INVALID_RAG_RESULT", "База данных не вернула источники ответа")
		}
		return
	}
	for rows.Next() {
		var citationID, chunkID, contentID, authorID, communityID int64
		var kind, title, quote string
		var pageNo sql.NullInt64
		var start, end int
		if err := rows.Scan(&citationID, &chunkID, &contentID, &kind, &title,
			&authorID, &communityID, &quote, &pageNo, &start, &end); err != nil {
			s.sqlProblem(w, err)
			return
		}
		_ = chunkID
		_ = communityID
		path := "/api/v1/posts/" + idString(contentID)
		if kind == "COMMENT" {
			path = "/api/v1/comments/" + idString(contentID)
		}
		if kind == "DOCUMENT" {
			path = "/api/v1/documents/" + idString(contentID)
		}
		var page *int
		if pageNo.Valid {
			v := int(pageNo.Int64)
			page = &v
		}
		if status == "COMPLETED" {
			citations = append(citations, citation{
				CitationID: idString(citationID), ContentID: idString(contentID),
				Kind: kind, Title: title, AuthorUserID: idString(authorID),
				Quote: quote, PageNo: page, StartOffset: start, EndOffset: end, SourcePath: path,
			})
		}
	}
	if err := rows.Err(); err != nil {
		s.sqlProblem(w, err)
		return
	}
	if status == "COMPLETED" && len(citations) == 0 {
		problem(w, http.StatusInternalServerError, "INVALID_RAG_RESULT", "Завершённый ответ не содержит проверяемых источников")
		return
	}
	result := map[string]any{
		"queryId": idString(turnID), "question": question,
		"status": status, "answer": nil, "citations": citations,
	}
	if status == "COMPLETED" || status == "NO_SOURCES" {
		result["answer"] = nullableString(answer)
	}
	writeJSON(w, http.StatusOK, result)
}
