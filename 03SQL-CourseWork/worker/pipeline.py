"""Turn an immutable source revision into evidence-backed SQL index payloads."""

from __future__ import annotations

from array import array
from dataclasses import dataclass
from io import BytesIO
import json
import math
import re
from typing import Any, Optional
from xml.etree import ElementTree
from zipfile import BadZipFile, ZipFile


MAX_FILE_BYTES = 10 * 1024 * 1024
MAX_EXTRACTED_CHARS = 2_000_000
MAX_PDF_PAGES = 300
MAX_DOCX_UNCOMPRESSED_BYTES = 40 * 1024 * 1024
MAX_DOCX_MEMBERS = 1000
CHUNK_CHARS = 900
CHUNK_OVERLAP = 100
MODEL_NAME = "intfloat/multilingual-e5-small"
MODEL_REVISION = "fd1525a9fd15316a2d503bf26ab031a61d056e98"
EXTRACTOR_VERSION = "rules-ru-v1"


class ProcessingError(Exception):
    """A source cannot be indexed without changing its input or setup."""


def load_model() -> Any:
    """Load the pinned E5 weights once per process before handling work."""
    from sentence_transformers import SentenceTransformer

    model = SentenceTransformer(MODEL_NAME, device="cpu", trust_remote_code=False,
                                revision=MODEL_REVISION)
    samples = model.encode(["passage: проверка модели", "query: проверка модели"],
                           normalize_embeddings=True)
    if len(samples) != 2 or any(len(sample) != 384 for sample in samples):
        raise ProcessingError("Configured E5 model must output 384 dimensions")
    return model


@dataclass(frozen=True)
class Page:
    number: Optional[int]
    text: str


@dataclass(frozen=True)
class Extracted:
    text: str
    pages: list[tuple[Optional[int], int, int]]
    ocr_engine_version: Optional[str]


def _clean(value: str) -> str:
    # Keep a stable searchable projection; NUL is invalid in SQL text indexing.
    return value.replace("\x00", " ").replace("\r\n", "\n").replace("\r", "\n").strip()


def _assemble(pages: list[Page], ocr_version: Optional[str] = None) -> Extracted:
    parts: list[str] = []
    positions: list[tuple[Optional[int], int, int]] = []
    cursor = 0
    for page in pages:
        content = _clean(page.text)
        if not content:
            continue
        if parts:
            parts.append("\n\n")
            cursor += 2
        start = cursor
        parts.append(content)
        cursor += len(content)
        positions.append((page.number, start, cursor))
        if cursor > MAX_EXTRACTED_CHARS:
            raise ProcessingError("Extracted text exceeds the 2,000,000-character limit")
    if not positions:
        raise ProcessingError("No extractable text was found in the source")
    return Extracted("".join(parts), positions, ocr_version)


def _docx_text(payload: bytes) -> str:
    try:
        with ZipFile(BytesIO(payload)) as archive:
            members = archive.infolist()
            if len(members) > MAX_DOCX_MEMBERS or sum(m.file_size for m in members) > MAX_DOCX_UNCOMPRESSED_BYTES:
                raise ProcessingError("DOCX expands beyond the safe member/size limits")
            if "word/document.xml" not in archive.namelist():
                raise ProcessingError("DOCX does not contain word/document.xml")
            document_xml = archive.read("word/document.xml")
    except BadZipFile as exc:
        raise ProcessingError("DOCX is not a valid ZIP document") from exc
    try:
        root = ElementTree.fromstring(document_xml)
    except ElementTree.ParseError as exc:
        raise ProcessingError("DOCX document.xml is malformed") from exc
    namespace = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
    paragraphs: list[str] = []
    for paragraph in root.iter(namespace + "p"):
        pieces: list[str] = []
        for element in paragraph.iter():
            if element.tag == namespace + "t" and element.text:
                pieces.append(element.text)
            elif element.tag == namespace + "tab":
                pieces.append("\t")
            elif element.tag in (namespace + "br", namespace + "cr"):
                pieces.append("\n")
        text = "".join(pieces).strip()
        if text:
            paragraphs.append(text)
    return "\n".join(paragraphs)


def _pdf_pages(payload: bytes) -> tuple[list[Page], Optional[str]]:
    import pypdfium2

    document = None
    try:
        document = pypdfium2.PdfDocument(payload)
        count = len(document)
        if count > MAX_PDF_PAGES:
            raise ProcessingError("PDF exceeds the 300-page indexing limit")
        pages: list[Page] = []
        ocr_version = None
        total_chars = 0
        for page_index in range(count):
            page = document[page_index]
            try:
                text_page = page.get_textpage()
                try:
                    extracted = _clean(text_page.get_text_bounded())
                finally:
                    text_page.close()
                # Sparse pages often contain only a page number over a scanned image.
                if len(extracted) < 30:
                    try:
                        import pytesseract

                        area = page.get_width() * page.get_height()
                        if area <= 0:
                            raise ProcessingError("PDF page has invalid dimensions")
                        scale = min(1.5, math.sqrt(15_000_000 / area))
                        if scale < 0.5:
                            raise ProcessingError("PDF page is too large for bounded OCR")
                        bitmap = page.render(scale=scale)
                        try:
                            image = bitmap.to_pil()
                            try:
                                recognised = _clean(pytesseract.image_to_string(
                                    image, lang="rus", config="--psm 3", timeout=120
                                ))
                            finally:
                                image.close()
                        finally:
                            bitmap.close()
                        if recognised:
                            extracted = recognised
                            ocr_version = "tesseract-rus/" + str(pytesseract.get_tesseract_version())[:60]
                    except Exception as exc:
                        if isinstance(exc, ProcessingError):
                            raise
                        raise ProcessingError("Russian OCR is unavailable or failed") from exc
            finally:
                page.close()
            total_chars += len(extracted)
            if total_chars > MAX_EXTRACTED_CHARS:
                raise ProcessingError("Extracted text exceeds the 2,000,000-character limit")
            pages.append(Page(page_index + 1, extracted))
        return pages, ocr_version
    except ProcessingError:
        raise
    except Exception as exc:
        raise ProcessingError("PDF extraction failed or the file is encrypted") from exc
    finally:
        if document is not None:
            document.close()


def extract_source(kind: str, mime_type: Optional[str], file_bytes: Any,
                   plain_text: Optional[str], indexed_text: Optional[str]) -> Extracted:
    if kind in ("POST", "COMMENT"):
        return _assemble([Page(None, indexed_text or "")])
    if kind != "DOCUMENT":
        raise ProcessingError("Unsupported content kind")
    if mime_type == "text/plain":
        return _assemble([Page(None, plain_text or "")])
    if not file_bytes:
        raise ProcessingError("Document bytes are missing")
    payload = bytes(file_bytes)
    if len(payload) > MAX_FILE_BYTES:
        raise ProcessingError("Document exceeds the 10 MiB upload limit")
    if mime_type == "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
        return _assemble([Page(None, _docx_text(payload))])
    if mime_type == "application/pdf":
        pages, ocr_version = _pdf_pages(payload)
        return _assemble(pages, ocr_version)
    raise ProcessingError("Unsupported document MIME type")


def _offset_table(text: str, supplementary_width: int) -> array:
    offsets = array("I", [0])
    count = 0
    for character in text:
        count += supplementary_width if ord(character) > 0xFFFF else 1
        offsets.append(count)
    return offsets


def _chunk_spans(extracted: Extracted) -> list[tuple[int, Optional[int], int, int]]:
    spans: list[tuple[int, Optional[int], int, int]] = []
    for page_number, page_start, page_end in extracted.pages:
        cursor = page_start
        while cursor < page_end:
            while cursor < page_end and extracted.text[cursor].isspace():
                cursor += 1
            if cursor >= page_end:
                break
            proposed = min(cursor + CHUNK_CHARS, page_end)
            end = proposed
            if proposed < page_end:
                tail = extracted.text[max(cursor + 1, proposed - 180):proposed]
                boundary = max(tail.rfind(". "), tail.rfind("! "), tail.rfind("? "), tail.rfind("\n"))
                if boundary >= 0:
                    end = max(cursor + 1, proposed - len(tail) + boundary + 1)
                else:
                    blank = tail.rfind(" ")
                    if blank >= 0:
                        end = max(cursor + 1, proposed - len(tail) + blank)
            while end > cursor and extracted.text[end - 1].isspace():
                end -= 1
            if end <= cursor:
                end = proposed
            spans.append((len(spans) + 1, page_number, cursor, end))
            if end >= page_end:
                break
            next_cursor = max(cursor + 1, end - CHUNK_OVERLAP)
            while next_cursor < end and not extracted.text[next_cursor - 1].isspace():
                next_cursor += 1
            cursor = next_cursor
    return spans


def build_payload(extracted: Extracted, model: Any, supplementary_width: int) -> tuple[str, str, str]:
    if supplementary_width not in (1, 2):
        raise ProcessingError("Unexpected SQL supplementary-character width")
    spans = _chunk_spans(extracted)
    if not spans:
        raise ProcessingError("No chunks could be created")
    offsets = _offset_table(extracted.text, supplementary_width)
    chunk_texts = [extracted.text[start:end] for _, _, start, end in spans]
    vectors = model.encode(
        ["passage: " + value for value in chunk_texts],
        batch_size=16, normalize_embeddings=True, show_progress_bar=False
    )
    if len(vectors) != len(spans):
        raise ProcessingError("Embedding model returned the wrong number of vectors")
    chunks: list[dict[str, Any]] = []
    for (number, page_no, start, end), content, vector in zip(spans, chunk_texts, vectors):
        values = [float(value) for value in vector]
        if len(values) != 384 or not all(math.isfinite(value) for value in values) or not any(values):
            raise ProcessingError("Embedding model returned an invalid 384D vector")
        chunks.append({
            "chunk_no": number, "text": content, "page_no": page_no,
            "start_offset": offsets[start], "end_offset": offsets[end],
            "embedding": values,
        })
    mentions, relations = _extract_evidence(extracted.text, spans, offsets)
    return (
        json.dumps(chunks, ensure_ascii=False, allow_nan=False),
        json.dumps(mentions, ensure_ascii=False),
        json.dumps(relations, ensure_ascii=False),
    )


_PERSON = r"[А-ЯЁ][а-яё]+\s+[А-ЯЁ][а-яё]+"
_LABEL = r"[А-ЯЁA-Z][\wЁё-]*(?:\s+[А-ЯЁA-Z][\wЁё-]*){0,2}"
_PATTERNS = (
    (re.compile(rf"(?P<person>{_PERSON})\s+работает\s+в\s+(?:компании|организации)\s+«?(?P<org>{_LABEL})»?"),
     ("person", "PERSON"), ("org", "ORGANIZATION"), "WORKS_AT"),
    (re.compile(rf"(?P<person>{_PERSON})\s+участвует\s+в\s+(?:мероприятии|проекте)\s+«?(?P<event>{_LABEL})»?"),
     ("person", "PERSON"), ("event", "EVENT"), "PARTICIPATES_IN"),
    (re.compile(rf"(?:Фестиваль|Конференция|Форум|Семинар)\s+«?(?P<event>{_LABEL})»?\s+проходит\s+в\s+(?:(?:городе|г\.)\s+)?(?P<place>{_LABEL})"),
     ("event", "EVENT"), ("place", "PLACE"), "TAKES_PLACE_IN"),
)
_TOPIC = re.compile(r"(?:^|[\n.;])\s*[Тт]ема\s*:\s*(?P<topic>[^\n.;:]{2,100})")


def _extract_evidence(text: str, spans: list[tuple[int, Optional[int], int, int]],
                      offsets: array) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    mentions: list[dict[str, Any]] = []
    relations: list[dict[str, Any]] = []
    for chunk_no, _, start, end in spans:
        content = text[start:end]
        local: dict[tuple[str, int, int], int] = {}

        def mention(entity_type: str, match: re.Match[str], group: str) -> int:
            absolute_start = start + match.start(group)
            absolute_end = start + match.end(group)
            key = (entity_type, absolute_start, absolute_end)
            if key in local:
                return local[key]
            local_id = len(mentions) + 1
            local[key] = local_id
            evidence = text[absolute_start:absolute_end]
            mentions.append({
                "local_id": local_id,
                "entity_type": entity_type,
                "entity_name": evidence.strip(),
                "chunk_no": chunk_no,
                "start_offset": offsets[absolute_start],
                "end_offset": offsets[absolute_end],
                "evidence_text": evidence,
                "confidence": 0.7,
                "extractor_version": EXTRACTOR_VERSION,
            })
            return local_id

        for pattern, origin, target, predicate in _PATTERNS:
            for match in pattern.finditer(content):
                origin_id = mention(origin[1], match, origin[0])
                target_id = mention(target[1], match, target[0])
                relation_start = start + match.start()
                relation_end = start + match.end()
                relations.append({
                    "from_local_id": origin_id,
                    "to_local_id": target_id,
                    "predicate_code": predicate,
                    "chunk_no": chunk_no,
                    "start_offset": offsets[relation_start],
                    "end_offset": offsets[relation_end],
                    "evidence_text": text[relation_start:relation_end],
                    "confidence": 0.65,
                    "extractor_version": EXTRACTOR_VERSION,
                })
        for match in _TOPIC.finditer(content):
            mention("TOPIC", match, "topic")
    return mentions, relations
