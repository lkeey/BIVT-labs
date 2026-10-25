"""Claim SQL outbox events and commit a verifiable search projection."""

from __future__ import annotations

import argparse
from contextlib import closing
import logging
import os
import sys
from threading import Event, Thread
from typing import Any

import pyodbc

from pipeline import MODEL_NAME, MODEL_REVISION, ProcessingError, build_payload, extract_source, load_model


LOG = logging.getLogger("coursework.index_worker")
CONNECTION_VARIABLE = "COURSEWORK_SQL_ODBC_CONNECTION_STRING"


def connect() -> pyodbc.Connection:
    connection_string = os.environ.get(CONNECTION_VARIABLE)
    if not connection_string:
        raise ProcessingError(f"{CONNECTION_VARIABLE} is not set")
    # The configured SQL role should have EXECUTE on worker procedures only.
    return pyodbc.connect(connection_string, autocommit=True, timeout=15)


def sql_supplementary_width(connection: pyodbc.Connection) -> int:
    # SQL LEN/SUBSTRING count supplementary characters as one or two positions,
    # depending on the database collation. Match the server, not Python's len.
    row = connection.cursor().execute("SELECT LEN(CAST(? AS nvarchar(10)))", "😀").fetchone()
    width = int(row[0])
    if width not in (1, 2):
        raise ProcessingError("SQL collation has unexpected offset semantics")
    return width


def claim_one(connection: pyodbc.Connection) -> Any:
    cursor = connection.cursor()
    cursor.execute("EXEC ops.usp_RequeueExpiredIndexOutbox @BatchSize=?", 10)
    cursor.fetchall()
    cursor.execute("EXEC ops.usp_ClaimIndexOutbox @BatchSize=?", 1)
    return cursor.fetchone()


def claimed_source(connection: pyodbc.Connection, event_id: int, claim_token: str) -> dict[str, Any]:
    cursor = connection.cursor()
    cursor.execute(
        "EXEC ops.usp_GetClaimedIndexSource @EventID=?, @ClaimToken=?",
        event_id, claim_token,
    )
    row = cursor.fetchone()
    if row is None:
        raise ProcessingError("Claimed source was not returned by SQL")
    return {column[0]: value for column, value in zip(cursor.description, row)}


class LeaseGuard:
    """Renew an individual claim while OCR and embedding work runs."""

    def __init__(self, event_id: int, claim_token: str) -> None:
        self.event_id = event_id
        self.claim_token = claim_token
        self.stop = Event()
        self.failed = Event()
        self.thread = Thread(target=self._heartbeat, name=f"index-lease-{event_id}", daemon=True)

    def __enter__(self) -> "LeaseGuard":
        self.thread.start()
        return self

    def __exit__(self, *_: Any) -> None:
        self.stop.set()
        self.thread.join(timeout=20)

    def _heartbeat(self) -> None:
        while not self.stop.wait(60):
            try:
                with closing(connect()) as connection:
                    connection.cursor().execute(
                        "EXEC ops.usp_RenewIndexLease @EventID=?, @ClaimToken=?",
                        self.event_id, self.claim_token,
                    )
            except Exception:
                LOG.error("Could not renew lease for outbox event %s", self.event_id)
                self.failed.set()
                return

    def ensure_active(self) -> None:
        if self.failed.is_set():
            raise ProcessingError("Index claim lease could not be renewed")


def complete_failure(event_id: int, claim_token: str, problem: Exception) -> None:
    # Keep SQL messages curated. An arbitrary driver's exception could include
    # connection details or document text and must not be stored in LastError.
    if isinstance(problem, ProcessingError):
        detail = str(problem)[:1800]
    else:
        detail = f"Unexpected worker error: {type(problem).__name__}"
    with closing(connect()) as connection:
        connection.cursor().execute(
            "EXEC ops.usp_CompleteIndexOutbox "
            "@EventID=?, @ClaimToken=?, @Succeeded=0, @ErrorMessage=?",
            event_id, claim_token, detail,
        )


def process_one(connection: pyodbc.Connection, event: Any, model: Any,
                supplementary_width: int) -> None:
    event_id = int(event.EventID)
    claim_token = str(event.ClaimToken)
    operation = str(event.Operation)
    try:
        with LeaseGuard(event_id, claim_token) as guard:
            if operation == "DELETE":
                connection.cursor().execute(
                    "EXEC ops.usp_CommitIndexDeletion @EventID=?, @ClaimToken=?",
                    event_id, claim_token,
                )
                LOG.info("Deleted index for outbox event %s", event_id)
                return
            if operation != "UPSERT":
                raise ProcessingError("Unknown outbox operation")
            source = claimed_source(connection, event_id, claim_token)
            if source["ModelName"] != MODEL_NAME or source["Dimensions"] != 384:
                raise ProcessingError("Outbox event requests an unsupported embedding model")
            if source["ModelVersion"] != MODEL_REVISION:
                raise ProcessingError("Outbox model revision does not match the worker")
            if not source["IsCurrent"] or source["ContentStatus"] != "PUBLISHED" or not source["AllowRag"]:
                # A newer revision or synchronous revocation already hides it.
                connection.cursor().execute(
                    "EXEC ops.usp_CompleteIndexOutbox "
                    "@EventID=?, @ClaimToken=?, @Succeeded=1",
                    event_id, claim_token,
                )
                LOG.info("Skipped stale outbox event %s", event_id)
                return
            extracted = extract_source(
                str(source["Kind"]), source["MimeType"], source["FileBytes"],
                source["PlainText"], source["ExtractedText"],
            )
            guard.ensure_active()
            chunks_json, mentions_json, relations_json = build_payload(extracted, model, supplementary_width)
            guard.ensure_active()
            connection.cursor().execute(
                "EXEC ops.usp_CommitIndexResult "
                "@EventID=?, @ClaimToken=?, @ExtractedText=?, @ChunksJson=?, "
                "@MentionsJson=?, @RelationsJson=?, @OcrEngineVersion=?",
                event_id, claim_token, extracted.text, chunks_json,
                mentions_json, relations_json, extracted.ocr_engine_version,
            )
            LOG.info("Indexed outbox event %s", event_id)
    except Exception as exc:
        LOG.error("Indexing event %s failed: %s", event_id,
                  str(exc) if isinstance(exc, ProcessingError) else type(exc).__name__)
        try:
            complete_failure(event_id, claim_token, exc)
        except Exception:
            LOG.error("Could not record failure for outbox event %s; lease may have expired", event_id)
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description="Process SQL coursework indexing outbox")
    parser.add_argument("--loop", action="store_true", help="Poll continuously (default: process at most one event)")
    parser.add_argument("--poll-seconds", type=float, default=10.0)
    args = parser.parse_args()
    if args.poll_seconds < 1 or args.poll_seconds > 300:
        parser.error("--poll-seconds must be between 1 and 300")
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    try:
        with closing(connect()) as connection:
            supplementary_width = sql_supplementary_width(connection)
            model = load_model()
            while True:
                event = claim_one(connection)
                if event is None:
                    if not args.loop:
                        return 0
                    Event().wait(args.poll_seconds)
                    continue
                try:
                    process_one(connection, event, model, supplementary_width)
                except Exception:
                    if not args.loop:
                        return 1
                    Event().wait(args.poll_seconds)
                if not args.loop:
                    return 0
    except KeyboardInterrupt:
        return 130
    except ProcessingError as exc:
        LOG.error("Worker setup failed: %s", exc)
        return 2
    except Exception as exc:
        LOG.error("Worker setup failed: %s", type(exc).__name__)
        return 2


if __name__ == "__main__":
    sys.exit(main())
