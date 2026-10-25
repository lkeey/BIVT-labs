"""Index the PostgreSQL demonstration database with the same pinned pipeline."""

from __future__ import annotations

import argparse
from contextlib import closing
import logging
import os
import sys
from threading import Event, Thread
from typing import Any

import psycopg
from psycopg.rows import dict_row

from pipeline import MODEL_NAME, MODEL_REVISION, ProcessingError, build_payload, extract_source, load_model


LOG = logging.getLogger("coursework.postgres_index_worker")
CONNECTION_VARIABLE = "COURSEWORK_POSTGRES_DSN"


def connect() -> psycopg.Connection:
    dsn = os.environ.get(CONNECTION_VARIABLE)
    if not dsn:
        raise ProcessingError(f"{CONNECTION_VARIABLE} is not set")
    # Database functions check the claim token, state and source revision again
    # before committing any projection. Never log the DSN or server errors.
    return psycopg.connect(dsn, connect_timeout=15, autocommit=True, row_factory=dict_row)


def _columns(row: dict[str, Any]) -> dict[str, Any]:
    """Accept either quoted SQL-style names or PostgreSQL lowercase names."""
    return {key.replace("_", "").lower(): value for key, value in row.items()}


def claim_one(connection: psycopg.Connection) -> dict[str, Any] | None:
    with connection.cursor() as cursor:
        cursor.execute("SELECT * FROM ops.requeue_expired_index_outbox(%s)", (10,))
        cursor.fetchall()
        cursor.execute("SELECT * FROM ops.claim_index_outbox(%s)", (1,))
        row = cursor.fetchone()
    return _columns(row) if row is not None else None


def claimed_source(connection: psycopg.Connection, event_id: int,
                   claim_token: str) -> dict[str, Any]:
    with connection.cursor() as cursor:
        cursor.execute("SELECT * FROM ops.get_claimed_index_source(%s::bigint, %s::uuid)",
                       (event_id, claim_token))
        row = cursor.fetchone()
    if row is None:
        raise ProcessingError("Claimed source was not returned by PostgreSQL")
    return _columns(row)


class LeaseGuard:
    """Renew a PostgreSQL outbox claim while OCR and embedding work runs."""

    def __init__(self, event_id: int, claim_token: str) -> None:
        self.event_id = event_id
        self.claim_token = claim_token
        self.stop = Event()
        self.failed = Event()
        self.thread = Thread(target=self._heartbeat, name=f"pg-index-lease-{event_id}", daemon=True)

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
                    with connection.cursor() as cursor:
                        cursor.execute("SELECT ops.renew_index_lease(%s::bigint, %s::uuid)",
                                       (self.event_id, self.claim_token))
            except Exception:
                LOG.error("Could not renew lease for outbox event %s", self.event_id)
                self.failed.set()
                return

    def ensure_active(self) -> None:
        if self.failed.is_set():
            raise ProcessingError("Index claim lease could not be renewed")


def complete_failure(event_id: int, claim_token: str, problem: Exception) -> None:
    # A driver exception may contain connection details or source text.
    detail = (str(problem)[:1800] if isinstance(problem, ProcessingError)
              else f"Unexpected worker error: {type(problem).__name__}")
    with closing(connect()) as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT ops.complete_index_outbox(%s::bigint, %s::uuid, %s, %s)",
                           (event_id, claim_token, False, detail))


def process_one(connection: psycopg.Connection, event: dict[str, Any], model: Any | None) -> Any | None:
    event_id = int(event["eventid"])
    claim_token = str(event["claimtoken"])
    operation = str(event["operation"])
    try:
        with LeaseGuard(event_id, claim_token) as guard:
            if operation == "DELETE":
                with connection.cursor() as cursor:
                    cursor.execute("SELECT ops.commit_index_deletion(%s::bigint, %s::uuid)",
                                   (event_id, claim_token))
                LOG.info("Deleted index for outbox event %s", event_id)
                return model
            if operation != "UPSERT":
                raise ProcessingError("Unknown outbox operation")
            source = claimed_source(connection, event_id, claim_token)
            if source["modelname"] != MODEL_NAME or source["dimensions"] != 384:
                raise ProcessingError("Outbox event requests an unsupported embedding model")
            if source["modelversion"] != MODEL_REVISION:
                raise ProcessingError("Outbox model revision does not match the worker")
            if (not source["iscurrent"] or source["contentstatus"] != "PUBLISHED"
                    or not source["allowrag"]):
                with connection.cursor() as cursor:
                    cursor.execute("SELECT ops.complete_index_outbox(%s::bigint, %s::uuid, %s, %s)",
                                   (event_id, claim_token, True, None))
                LOG.info("Skipped stale outbox event %s", event_id)
                return model
            extracted = extract_source(
                str(source["kind"]), source["mimetype"], source["filebytes"],
                source["plaintext"], source["extractedtext"],
            )
            guard.ensure_active()
            if model is None:
                model = load_model()
            guard.ensure_active()
            # PostgreSQL text offsets count Unicode code points, as Python does.
            chunks_json, mentions_json, relations_json = build_payload(extracted, model, 1)
            guard.ensure_active()
            with connection.cursor() as cursor:
                cursor.execute(
                    "SELECT * FROM ops.commit_index_result("
                    "%s::bigint, %s::uuid, %s, %s::jsonb, %s::jsonb, %s::jsonb, %s)",
                    (event_id, claim_token, extracted.text, chunks_json,
                     mentions_json, relations_json, extracted.ocr_engine_version),
                )
            LOG.info("Indexed outbox event %s", event_id)
            return model
    except Exception as exc:
        LOG.error("Indexing event %s failed: %s", event_id,
                  str(exc) if isinstance(exc, ProcessingError) else type(exc).__name__)
        try:
            complete_failure(event_id, claim_token, exc)
        except Exception:
            LOG.error("Could not record failure for outbox event %s; lease may have expired", event_id)
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description="Process PostgreSQL coursework indexing outbox")
    parser.add_argument("--loop", action="store_true", help="Poll continuously (default: process one event)")
    parser.add_argument("--poll-seconds", type=float, default=10.0)
    parser.add_argument("--max-jobs", type=int, default=1,
                        help="Maximum events per finite invocation (1-20; ignored with --loop)")
    args = parser.parse_args()
    if args.poll_seconds < 1 or args.poll_seconds > 300:
        parser.error("--poll-seconds must be between 1 and 300")
    if not 1 <= args.max_jobs <= 20:
        parser.error("--max-jobs must be between 1 and 20")
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    try:
        with closing(connect()) as connection:
            model = None
            processed = 0
            while True:
                event = claim_one(connection)
                if event is None:
                    if not args.loop:
                        return 0
                    Event().wait(args.poll_seconds)
                    continue
                try:
                    model = process_one(connection, event, model)
                except Exception:
                    if not args.loop:
                        return 1
                    Event().wait(args.poll_seconds)
                processed += 1
                if not args.loop and processed >= args.max_jobs:
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
