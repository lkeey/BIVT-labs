"""Private, bounded HTTP endpoint for pinned E5 query embeddings."""

from __future__ import annotations

import argparse
import hmac
from http.server import BaseHTTPRequestHandler, HTTPServer
import ipaddress
import json
import logging
import math
import os
import signal
import sys
from threading import BoundedSemaphore, Event, Thread
from typing import Any

from pipeline import MODEL_NAME, MODEL_REVISION, ProcessingError, load_model


LOG = logging.getLogger("coursework.embed_service")
TOKEN_ENV = "COURSEWORK_EMBED_BEARER_TOKEN"
MAX_BODY_BYTES = 8192
MAX_QUESTION_CHARS = 2000
SOCKET_TIMEOUT_SECONDS = 10
INFERENCE_TIMEOUT_SECONDS = 30


def embed_question(model: Any, question: str) -> list[float]:
    vectors = model.encode(["query: " + question], normalize_embeddings=True,
                           show_progress_bar=False)
    if len(vectors) != 1:
        raise ProcessingError("Embedding model returned the wrong number of vectors")
    values = [float(value) for value in vectors[0]]
    if len(values) != 384 or not all(math.isfinite(value) for value in values):
        raise ProcessingError("Embedding model returned an invalid 384D vector")
    norm = math.sqrt(sum(value * value for value in values))
    if not 0.98 <= norm <= 1.02:
        raise ProcessingError("Embedding model returned an unnormalized vector")
    return values


class EmbeddingHTTPServer(HTTPServer):
    allow_reuse_address = True
    request_queue_size = 8

    def __init__(self, address: tuple[str, int], model: Any, token: str) -> None:
        super().__init__(address, EmbeddingHandler)
        self.model = model
        self.token = token
        self.inference_slots = BoundedSemaphore(1)


class EmbeddingHandler(BaseHTTPRequestHandler):
    server: EmbeddingHTTPServer

    def setup(self) -> None:
        super().setup()
        self.connection.settimeout(SOCKET_TIMEOUT_SECONDS)

    def log_message(self, format: str, *args: Any) -> None:
        # Never log a request body or the Authorization header.
        LOG.info("HTTP %s %s", getattr(self, "command", "?"),
                 getattr(self, "path", "?").split("?", 1)[0])

    def _send(self, status: int, data: dict[str, Any], *, authenticate: bool = False) -> None:
        payload = json.dumps(data, ensure_ascii=False, allow_nan=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        if authenticate:
            self.send_header("WWW-Authenticate", "Bearer")
        self.end_headers()
        try:
            self.wfile.write(payload)
        except OSError:
            pass  # Client disconnected; no source text or credential is logged.

    def do_GET(self) -> None:
        if self.path != "/healthz":
            self._send(404, {"error": "NOT_FOUND"})
            return
        self._send(200, {"status": "ready", "model": MODEL_NAME, "revision": MODEL_REVISION})

    def do_POST(self) -> None:
        if self.path != "/embed":
            self._send(404, {"error": "NOT_FOUND"})
            return
        token = self.server.token
        if token:
            authorization = self.headers.get("Authorization", "")
            scheme, separator, supplied = authorization.partition(" ")
            supplied = supplied if separator and scheme.lower() == "bearer" else ""
            if not hmac.compare_digest(supplied, token):
                self._send(401, {"error": "UNAUTHORIZED"}, authenticate=True)
                return
        if self.headers.get("Transfer-Encoding"):
            self._send(400, {"error": "CONTENT_LENGTH_REQUIRED"})
            return
        content_type = self.headers.get("Content-Type", "").partition(";")[0].strip().lower()
        if content_type != "application/json":
            self._send(415, {"error": "UNSUPPORTED_MEDIA_TYPE"})
            return
        length_header = self.headers.get("Content-Length")
        if length_header is None:
            self._send(411, {"error": "CONTENT_LENGTH_REQUIRED"})
            return
        try:
            length = int(length_header)
        except ValueError:
            self._send(400, {"error": "INVALID_CONTENT_LENGTH"})
            return
        if length < 1 or length > MAX_BODY_BYTES:
            self._send(413, {"error": "BODY_TOO_LARGE"})
            return
        try:
            body = self.rfile.read(length)
            if len(body) != length:
                raise ValueError("Truncated request body")
            request = json.loads(body.decode("utf-8", errors="strict"))
        except (OSError, UnicodeError, ValueError):
            self._send(400, {"error": "INVALID_JSON"})
            return
        if not isinstance(request, dict) or not isinstance(request.get("question"), str):
            self._send(400, {"error": "QUESTION_REQUIRED"})
            return
        question = request["question"].strip()
        if not 1 <= len(question) <= MAX_QUESTION_CHARS:
            self._send(400, {"error": "QUESTION_LENGTH"})
            return
        if not self.server.inference_slots.acquire(blocking=False):
            self._send(503, {"error": "EMBEDDING_BUSY"})
            return
        completed = Event()
        result: dict[str, Any] = {}

        def run_embedding() -> None:
            try:
                result["embedding"] = embed_question(self.server.model, question)
            except Exception:
                result["error"] = True
            finally:
                completed.set()
                self.server.inference_slots.release()

        try:
            # A hung native-model call cannot be cancelled in Python. One daemon
            # thread can outlive its 30-second HTTP deadline, but the busy slot
            # prevents starting another inference until it actually completes.
            Thread(target=run_embedding, name="e5-query", daemon=True).start()
        except RuntimeError:
            self.server.inference_slots.release()
            self._send(503, {"error": "EMBEDDING_UNAVAILABLE"})
            return
        if not completed.wait(INFERENCE_TIMEOUT_SECONDS):
            self._send(504, {"error": "EMBEDDING_TIMEOUT"})
            return
        if result.get("error"):
            LOG.error("Query embedding failed")
            self._send(503, {"error": "EMBEDDING_UNAVAILABLE"})
            return
        self._send(200, {"embedding": result["embedding"], "model": MODEL_NAME,
                         "revision": MODEL_REVISION})


def main() -> int:
    parser = argparse.ArgumentParser(description="Private E5 query embedding service")
    parser.add_argument("--host", default="127.0.0.1", help="IPv4 bind address")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    try:
        address = ipaddress.IPv4Address(args.host)
    except ipaddress.AddressValueError:
        parser.error("--host must be an IPv4 address")
    if not 1 <= args.port <= 65535:
        parser.error("--port must be between 1 and 65535")
    token = os.environ.get(TOKEN_ENV, "")
    if not address.is_loopback and len(token) < 32:
        parser.error(f"Non-loopback binding requires a random {TOKEN_ENV} of at least 32 characters")
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    try:
        model = load_model()
        server = EmbeddingHTTPServer((str(address), args.port), model, token)
    except Exception as exc:
        LOG.error("Embedding service setup failed: %s", type(exc).__name__)
        return 2

    stopped = Event()
    for signum in (signal.SIGINT, signal.SIGTERM):
        signal.signal(signum, lambda *_: stopped.set())
    thread = Thread(target=server.serve_forever, kwargs={"poll_interval": 0.2},
                    name="embedding-http", daemon=False)
    thread.start()
    LOG.info("Query embedding service listening on %s:%s", address, args.port)
    try:
        stopped.wait()
    except KeyboardInterrupt:
        pass
    finally:
        server.shutdown()
        thread.join(timeout=INFERENCE_TIMEOUT_SECONDS + SOCKET_TIMEOUT_SECONDS)
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
