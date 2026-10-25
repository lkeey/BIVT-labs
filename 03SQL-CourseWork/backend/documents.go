package main

import (
	"archive/zip"
	"bytes"
	"database/sql"
	"errors"
	"fmt"
	"io"
	"mime"
	"mime/multipart"
	"net/http"
	"path/filepath"
	"strings"
	"unicode/utf16"

	mssql "github.com/microsoft/go-mssqldb"
)

const hardMaxDocumentBytes int64 = 10 << 20

func documentSizeLimitText(maxBytes int64) string {
	if maxBytes%(1<<20) == 0 {
		return fmt.Sprintf("%d МиБ", maxBytes/(1<<20))
	}
	return fmt.Sprintf("%d байт", maxBytes)
}

type documentInput struct {
	title    string
	fileName string
	mimeType string
	file     []byte
	text     *string
}

func readDocumentInput(w http.ResponseWriter, r *http.Request, maxBytes int64) (documentInput, bool) {
	mediaType, params, err := mime.ParseMediaType(r.Header.Get("Content-Type"))
	if err != nil {
		problem(w, http.StatusUnsupportedMediaType, "UNSUPPORTED_MEDIA", "Ожидается JSON или multipart/form-data")
		return documentInput{}, false
	}
	var input documentInput
	switch mediaType {
	case "application/json":
		var body struct {
			Title string `json:"title"`
			Text  string `json:"text"`
		}
		if !decodeJSON(w, r, &body, maxBytes+2048) {
			return documentInput{}, false
		}
		input.title = body.Title
		input.text = &body.Text
		input.mimeType = "text/plain"
	case "multipart/form-data":
		boundary := params["boundary"]
		if boundary == "" {
			problem(w, http.StatusBadRequest, "INVALID_MULTIPART", "Отсутствует граница формы")
			return documentInput{}, false
		}
		r.Body = http.MaxBytesReader(w, r.Body, maxBytes+65536)
		reader := multipart.NewReader(r.Body, boundary)
		seenFile, seenTitle := false, false
		for {
			part, err := reader.NextPart()
			if err == io.EOF {
				break
			}
			if err != nil {
				var tooLarge *http.MaxBytesError
				if errors.As(err, &tooLarge) {
					problem(w, http.StatusRequestEntityTooLarge, "DOCUMENT_TOO_LARGE", "Размер запроса превышает "+documentSizeLimitText(maxBytes))
					return documentInput{}, false
				}
				problem(w, http.StatusBadRequest, "INVALID_MULTIPART", "Некорректная форма")
				return documentInput{}, false
			}
			switch part.FormName() {
			case "title":
				if seenTitle || part.FileName() != "" {
					problem(w, http.StatusBadRequest, "INVALID_MULTIPART", "Поле title повторяется")
					return documentInput{}, false
				}
				seenTitle = true
				data, err := io.ReadAll(io.LimitReader(part, 1025))
				if err != nil || len(data) > 1024 {
					problem(w, http.StatusBadRequest, "INVALID_TITLE", "Название слишком длинное")
					return documentInput{}, false
				}
				input.title = string(data)
			case "file":
				if seenFile || part.FileName() == "" {
					problem(w, http.StatusBadRequest, "INVALID_MULTIPART", "Ожидается один файл")
					return documentInput{}, false
				}
				seenFile = true
				input.fileName = filepath.Base(strings.ReplaceAll(part.FileName(), "\\", "/"))
				input.file, err = io.ReadAll(io.LimitReader(part, maxBytes+1))
				if err != nil || int64(len(input.file)) > maxBytes {
					problem(w, http.StatusRequestEntityTooLarge, "DOCUMENT_TOO_LARGE", "Размер файла превышает "+documentSizeLimitText(maxBytes))
					return documentInput{}, false
				}
			default:
				problem(w, http.StatusBadRequest, "INVALID_MULTIPART", "Неизвестное поле формы")
				return documentInput{}, false
			}
		}
		if !seenTitle || !seenFile {
			problem(w, http.StatusBadRequest, "INVALID_MULTIPART", "Нужны title и file")
			return documentInput{}, false
		}
		extension := strings.ToLower(filepath.Ext(input.fileName))
		switch extension {
		case ".pdf":
			if !bytes.HasPrefix(input.file, []byte("%PDF-")) {
				problem(w, http.StatusUnsupportedMediaType, "INVALID_PDF", "Файл не похож на PDF")
				return documentInput{}, false
			}
			input.mimeType = "application/pdf"
		case ".docx":
			if !isDOCX(input.file) {
				problem(w, http.StatusUnsupportedMediaType, "INVALID_DOCX", "Файл не похож на DOCX")
				return documentInput{}, false
			}
			input.mimeType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
		default:
			problem(w, http.StatusUnsupportedMediaType, "UNSUPPORTED_MEDIA", "Поддерживаются PDF и DOCX")
			return documentInput{}, false
		}
	default:
		problem(w, http.StatusUnsupportedMediaType, "UNSUPPORTED_MEDIA", "Ожидается JSON или multipart/form-data")
		return documentInput{}, false
	}
	if strings.TrimSpace(input.title) == "" || len(utf16.Encode([]rune(input.title))) > 250 {
		problem(w, http.StatusBadRequest, "INVALID_TITLE", "Название обязательно и не длиннее 250 символов")
		return documentInput{}, false
	}
	if input.text != nil {
		if strings.TrimSpace(*input.text) == "" {
			problem(w, http.StatusBadRequest, "INVALID_TEXT", "Текст документа не может быть пустым")
			return documentInput{}, false
		}
		if int64(2*len(utf16.Encode([]rune(*input.text)))) > maxBytes {
			problem(w, http.StatusRequestEntityTooLarge, "DOCUMENT_TOO_LARGE", "Текст длиннее "+documentSizeLimitText(maxBytes)+" в UTF-16")
			return documentInput{}, false
		}
	}
	return input, true
}

func isDOCX(data []byte) bool {
	reader, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return false
	}
	hasContentTypes, hasDocument := false, false
	for _, f := range reader.File {
		if f.Name == "[Content_Types].xml" {
			hasContentTypes = true
		}
		if f.Name == "word/document.xml" {
			hasDocument = true
		}
	}
	return hasContentTypes && hasDocument
}

func (s *server) createDocument(w http.ResponseWriter, r *http.Request, p principal) {
	communityID, ok := pathID(w, r, "communityId")
	if !ok {
		return
	}
	s.saveDocument(w, r, p, communityID, nil)
}

func (s *server) createDocumentVersion(w http.ResponseWriter, r *http.Request, p principal) {
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
	communityID, err := parsePositiveID(item.CommunityID)
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	s.saveDocument(w, r, p, communityID, &id)
}

func (s *server) saveDocument(w http.ResponseWriter, r *http.Request, p principal, communityID int64, existingContentID *int64) {
	input, ok := readDocumentInput(w, r, s.maxDocumentBytes)
	if !ok {
		return
	}
	var plainText any
	if input.text != nil {
		plainText = *input.text
	}
	var fileBytes any
	if len(input.file) > 0 {
		fileBytes = input.file
	}
	var contentID, versionID, revisionID int64
	err := s.db.QueryRowContext(r.Context(), "knowledge.usp_SaveDocumentVersion",
		sql.Named("AuthorUserID", p.userID), sql.Named("CommunityID", communityID),
		sql.Named("ContentID", existingContentID),
		sql.Named("Title", input.title), sql.Named("FileName", input.fileName),
		sql.Named("MimeType", mssql.VarChar(input.mimeType)),
		sql.Named("FileBytes", fileBytes), sql.Named("PlainText", plainText),
	).Scan(&contentID, &versionID, &revisionID)
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	writeJSON(w, http.StatusAccepted, map[string]string{
		"contentId": idString(contentID), "documentVersionId": idString(versionID),
		"sourceRevisionId": idString(revisionID), "processingStatus": "PROCESSING",
	})
}

func (s *server) getDocumentFile(w http.ResponseWriter, r *http.Request, p principal) {
	id, ok := pathID(w, r, "documentId")
	if !ok {
		return
	}
	var versionID, sizeBytes int64
	var name sql.NullString
	var mimeType string
	var digest, fileBytes []byte
	var plainText sql.NullString
	err := s.db.QueryRowContext(r.Context(), "knowledge.usp_GetDocumentFile",
		sql.Named("UserID", p.userID), sql.Named("ContentID", id),
	).Scan(&versionID, &name, &mimeType, &sizeBytes, &digest, &fileBytes, &plainText)
	if err != nil {
		s.sqlProblem(w, err)
		return
	}
	_ = versionID
	_ = name
	_ = sizeBytes
	_ = digest
	var body []byte
	var extension string
	switch mimeType {
	case "text/plain":
		if !plainText.Valid {
			problem(w, http.StatusNotFound, "NOT_FOUND", "Файл недоступен")
			return
		}
		body = []byte(plainText.String)
		mimeType = "text/plain; charset=utf-8"
		extension = ".txt"
	case "application/pdf":
		body = fileBytes
		extension = ".pdf"
	case "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
		body = fileBytes
		extension = ".docx"
	default:
		problem(w, http.StatusNotFound, "NOT_FOUND", "Файл недоступен")
		return
	}
	w.Header().Set("Content-Type", mimeType)
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("Content-Disposition", `attachment; filename="document-`+idString(id)+extension+`"`)
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(body)
}
