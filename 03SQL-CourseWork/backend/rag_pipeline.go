package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"math"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"
	"unicode"
	"unicode/utf16"
)

type ragSource struct {
	chunkID     int64
	contentID   int64
	kind        string
	title       string
	quote       string
	pageNo      *int
	startOffset int
	endOffset   int
	rank        int
	vectorScore float64
	textScore   float64
	graphScore  float64
}

type retrievedRecord struct {
	ChunkID     int64   `json:"chunk_id"`
	Rank        int     `json:"rank"`
	VectorScore float64 `json:"vector_score"`
	TextScore   float64 `json:"text_score"`
	GraphScore  float64 `json:"graph_score"`
}

type citationRecord struct {
	ChunkID     int64  `json:"chunk_id"`
	Quote       string `json:"quote"`
	PageNo      *int   `json:"page_no"`
	StartOffset int    `json:"start_offset"`
	EndOffset   int    `json:"end_offset"`
}

func (s *server) createRagQuery(w http.ResponseWriter, r *http.Request, p principal) {
	if s.rag == nil {
		problem(w, http.StatusServiceUnavailable, "RAG_UNAVAILABLE", "Генератор ответов не настроен")
		return
	}
	var input struct {
		Question    string `json:"question"`
		CommunityID string `json:"communityId"`
	}
	if !decodeJSON(w, r, &input, 16<<10) {
		return
	}
	input.Question = strings.TrimSpace(input.Question)
	if input.Question == "" || len(utf16.Encode([]rune(input.Question))) > 2000 {
		problem(w, http.StatusBadRequest, "INVALID_QUESTION", "Вопрос должен содержать от 1 до 2000 символов")
		return
	}
	embedRequest, _ := json.Marshal(map[string]string{"question": input.Question})
	if len(embedRequest) > 8192 {
		problem(w, http.StatusBadRequest, "INVALID_QUESTION", "Вопрос слишком велик для модели поиска")
		return
	}
	var communityID any
	if input.CommunityID != "" {
		id, err := parsePositiveID(input.CommunityID)
		if err != nil {
			problem(w, http.StatusBadRequest, "INVALID_ID", "Некорректный идентификатор сообщества")
			return
		}
		communityID = id
	}
	// Both providers must be reachable before any RAG turn is created.
	if err := s.rag.health(r.Context()); err != nil {
		s.logger.Warn("RAG chat health check failed", "error", err)
		problem(w, http.StatusServiceUnavailable, "RAG_UNAVAILABLE", "Модель ответов недоступна")
		return
	}
	embedding, err := s.rag.embedQuestion(r.Context(), input.Question)
	if err != nil {
		s.logger.Warn("RAG embedding request failed", "error", err)
		problem(w, http.StatusServiceUnavailable, "RAG_UNAVAILABLE", "Модель поиска недоступна")
		return
	}
	embeddingJSON, err := json.Marshal(embedding)
	if err != nil {
		problem(w, http.StatusInternalServerError, "RAG_ERROR", "Ошибка поискового вектора")
		return
	}
	entityJSON, _ := json.Marshal(questionEntityNames(input.Question))

	var sessionID int64
	err = s.db.QueryRowContext(r.Context(), "assistant.usp_StartRagSession",
		sql.Named("UserID", p.userID), sql.Named("CommunityID", communityID),
	).Scan(&sessionID)
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	var turnID, retrievalRunID int64
	var turnNo int
	var scopeCommunity sql.NullInt64
	err = s.db.QueryRowContext(r.Context(), "assistant.usp_StartRagTurn",
		sql.Named("SessionID", sessionID), sql.Named("UserID", p.userID),
		sql.Named("Question", input.Question), sql.Named("ModelVersion", embeddingVersion),
	).Scan(&turnID, &retrievalRunID, &turnNo, &scopeCommunity)
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	_ = turnNo
	_ = scopeCommunity
	finished := false
	defer func() {
		if finished {
			return
		}
		failCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if _, failErr := s.db.ExecContext(failCtx, "assistant.usp_FailRagTurn",
			sql.Named("TurnID", turnID), sql.Named("RetrievalRunID", retrievalRunID)); failErr != nil {
			s.logger.Error("Could not mark RAG turn failed", "turnID", turnID, "error", failErr)
		}
	}()

	rows, err := s.db.QueryContext(r.Context(), "assistant.usp_SearchRag",
		sql.Named("UserID", p.userID), sql.Named("Question", input.Question),
		sql.Named("QueryEmbedding", string(embeddingJSON)), sql.Named("TopK", 5),
		sql.Named("QueryEntitiesJson", string(entityJSON)), sql.Named("CommunityID", communityID),
	)
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	sources, err := readRagSources(rows)
	closeErr := rows.Close()
	if err == nil {
		err = closeErr
	}
	if err != nil {
		s.logger.Error("RAG search result invalid", "error", err)
		problem(w, http.StatusInternalServerError, "RAG_SEARCH_ERROR", "Не удалось прочитать источники")
		return
	}
	if len(sources) == 0 {
		_, err = s.db.ExecContext(r.Context(), "assistant.usp_SaveRagNoSources",
			sql.Named("TurnID", turnID), sql.Named("RetrievalRunID", retrievalRunID))
		if err != nil {
			s.sqlProblem(w, err)
			return
		}
		finished = true
		w.Header().Set("Location", "/api/v1/rag/queries/"+idString(turnID))
		writeJSON(w, http.StatusCreated, map[string]string{"queryId": idString(turnID), "status": "NO_SOURCES"})
		return
	}

	records := make([]retrievedRecord, 0, len(sources))
	for _, source := range sources {
		records = append(records, retrievedRecord{
			ChunkID: source.chunkID, Rank: source.rank,
			VectorScore: source.vectorScore, TextScore: source.textScore,
			GraphScore: source.graphScore,
		})
	}
	recordJSON, _ := json.Marshal(records)
	var recordedRunID int64
	var recordedCount int
	err = s.db.QueryRowContext(r.Context(), "assistant.usp_RecordRetrievedChunks",
		sql.Named("RetrievalRunID", retrievalRunID), sql.Named("UserID", p.userID),
		sql.Named("ChunksJson", string(recordJSON)),
	).Scan(&recordedRunID, &recordedCount)
	if err != nil {
		s.logger.Warn("RAG source access changed before generation", "turnID", turnID, "error", err)
		problem(w, http.StatusConflict, "SOURCES_CHANGED", "Доступ к источникам изменился; повторите запрос")
		return
	}
	if recordedRunID != retrievalRunID || recordedCount != len(sources) {
		problem(w, http.StatusInternalServerError, "RAG_RECORD_ERROR", "Не удалось зафиксировать источники")
		return
	}
	answer, err := s.rag.answer(r.Context(), input.Question, sources)
	if err != nil {
		s.logger.Warn("RAG chat generation failed", "turnID", turnID, "error", err)
		problem(w, http.StatusServiceUnavailable, "RAG_UNAVAILABLE", "Модель ответов недоступна")
		return
	}
	indices, err := citedSourceIndices(answer, len(sources))
	if err != nil {
		s.logger.Warn("RAG answer citations invalid", "turnID", turnID, "error", err)
		problem(w, http.StatusServiceUnavailable, "RAG_UNAVAILABLE", "Модель не вернула проверяемые ссылки на источники")
		return
	}
	citations := make([]citationRecord, 0, len(indices))
	for _, index := range indices {
		source := sources[index]
		citations = append(citations, citationRecord{
			ChunkID: source.chunkID, Quote: source.quote, PageNo: source.pageNo,
			StartOffset: source.startOffset, EndOffset: source.endOffset,
		})
	}
	citationsJSON, _ := json.Marshal(citations)
	_, err = s.db.ExecContext(r.Context(), "assistant.usp_SaveRagAnswer",
		sql.Named("TurnID", turnID), sql.Named("RetrievalRunID", retrievalRunID),
		sql.Named("AnswerText", answer), sql.Named("AnswerModel", s.rag.chatModel),
		sql.Named("CitationsJson", string(citationsJSON)))
	if err != nil {
		s.logger.Warn("RAG answer could not be committed", "turnID", turnID, "error", err)
		problem(w, http.StatusConflict, "SOURCES_CHANGED", "Доступ к источникам изменился; повторите запрос")
		return
	}
	finished = true
	w.Header().Set("Location", "/api/v1/rag/queries/"+idString(turnID))
	writeJSON(w, http.StatusCreated, map[string]string{"queryId": idString(turnID), "status": "COMPLETED"})
}

func readRagSources(rows *sql.Rows) ([]ragSource, error) {
	sources := make([]ragSource, 0, 5)
	for rows.Next() {
		var chunkID, contentID, authorID, communityID int64
		var kind, chunkText, title string
		var pageNo sql.NullInt64
		var start, end, sqlRank int
		var vectorScore, textScore, graphScore float64
		if err := rows.Scan(&chunkID, &contentID, &kind, &chunkText, &pageNo,
			&start, &end, &title, &authorID, &communityID, &sqlRank,
			&vectorScore, &textScore, &graphScore); err != nil {
			return nil, err
		}
		if chunkID <= 0 || contentID <= 0 || sqlRank <= 0 || start < 0 || end <= start ||
			(kind != "POST" && kind != "COMMENT" && kind != "DOCUMENT") ||
			!finiteRange(vectorScore, -1, 1) || !finiteRange(textScore, 0, 1) ||
			!finiteRange(graphScore, 0, 1) {
			return nil, errors.New("invalid SQL RAG source")
		}
		sqlLength := end - start
		utf16Length := len(utf16.Encode([]rune(chunkText)))
		runeLength := len([]rune(chunkText))
		if sqlLength != utf16Length && sqlLength != runeLength {
			return nil, errors.New("SQL RAG source offsets do not match text")
		}
		surrogateAwareCollation := sqlLength == runeLength && sqlLength != utf16Length
		quote, quoteLen := quotePrefix(chunkText, 1000, surrogateAwareCollation)
		if quoteLen == 0 {
			return nil, errors.New("empty SQL RAG source")
		}
		var page *int
		if pageNo.Valid {
			if pageNo.Int64 < 1 {
				return nil, errors.New("invalid RAG page number")
			}
			value := int(pageNo.Int64)
			page = &value
		}
		_ = authorID
		_ = communityID
		sources = append(sources, ragSource{
			chunkID: chunkID, contentID: contentID, kind: kind, title: title,
			quote: quote, pageNo: page, startOffset: start,
			endOffset: start + quoteLen, rank: sqlRank,
			vectorScore: roundedScore(vectorScore), textScore: roundedScore(textScore),
			graphScore: roundedScore(graphScore),
		})
		if len(sources) > 5 {
			return nil, errors.New("too many RAG results")
		}
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	sort.Slice(sources, func(i, j int) bool { return sources[i].rank < sources[j].rank })
	for i := range sources {
		sources[i].rank = i + 1
	}
	return sources, nil
}

func finiteRange(value, minimum, maximum float64) bool {
	return !math.IsNaN(value) && !math.IsInf(value, 0) && value >= minimum && value <= maximum
}

func roundedScore(value float64) float64 {
	return math.Round(value*1e6) / 1e6
}

// Cited source numbers are one-based positions in the exact retrieved set
// sent to the model. Reject malformed, absent, or out-of-range references.
func citedSourceIndices(answer string, sourceCount int) ([]int, error) {
	seen := make([]bool, sourceCount)
	for i := 0; i < len(answer); i++ {
		switch answer[i] {
		case '[':
			end := strings.IndexByte(answer[i+1:], ']')
			if end < 0 {
				return nil, errors.New("unclosed source reference")
			}
			end += i + 1
			content := answer[i+1 : end]
			number, err := strconv.Atoi(content)
			if err != nil || number < 1 || number > sourceCount || strconv.Itoa(number) != content {
				return nil, errors.New("invalid source reference")
			}
			seen[number-1] = true
			i = end
		case ']':
			return nil, errors.New("unexpected closing source bracket")
		}
	}
	indices := make([]int, 0, sourceCount)
	for i, cited := range seen {
		if cited {
			indices = append(indices, i)
		}
	}
	if len(indices) == 0 {
		return nil, errors.New("answer did not cite any source")
	}
	return indices, nil
}

func quotePrefix(source string, maxUTF16Units int, surrogateAwareCollation bool) (string, int) {
	var builder strings.Builder
	utf16Units := 0
	offsetUnits := 0
	for _, letter := range source {
		width := 1
		if letter > 0xffff {
			width = 2
		}
		if utf16Units+width > maxUTF16Units {
			break
		}
		builder.WriteRune(letter)
		utf16Units += width
		if surrogateAwareCollation {
			offsetUnits++
		} else {
			offsetUnits += width
		}
	}
	return builder.String(), offsetUnits
}

func questionEntityNames(question string) []string {
	words := strings.FieldsFunc(question, func(letter rune) bool {
		return !unicode.IsLetter(letter) && !unicode.IsNumber(letter)
	})
	if len(words) > 25 {
		words = words[:25]
	}
	seen := make(map[string]bool)
	names := make([]string, 0, 40)
	for width := 3; width >= 1; width-- {
		for i := 0; i+width <= len(words) && len(names) < 40; i++ {
			name := strings.Join(words[i:i+width], " ")
			if len(utf16.Encode([]rune(name))) < 2 || len(utf16.Encode([]rune(name))) > 500 {
				continue
			}
			key := strings.ToLower(name)
			if seen[key] {
				continue
			}
			seen[key] = true
			names = append(names, name)
		}
	}
	return names
}
