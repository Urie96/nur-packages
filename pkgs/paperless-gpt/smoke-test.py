"""Exercise the installed binary without a real Paperless or LLM service."""

import http.server
import json
import os
import re
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

binary, version, fixture = sys.argv[1:]
pdf = Path(fixture).read_bytes()


class PaperlessMock(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.headers.get("Authorization") != "Token test-token":
            self.send_error(403)
            return
        path = urllib.parse.urlparse(self.path).path
        if path == "/api/documents/1/download/":
            body = pdf
            content_type = "application/pdf"
        else:
            if path == "/api/tags/":
                results = [
                    {"id": i, "name": name, "document_count": 0}
                    for i, name in enumerate(
                        ["paperless-gpt-failed", "paperless-gpt-auto-complete"], 1
                    )
                ]
                data = {"count": len(results), "next": None, "results": results}
            elif path in ("/api/custom_fields/", "/api/documents/"):
                data = {"count": 0, "next": None, "results": []}
            elif path == "/api/documents/1/":
                data = {
                    "id": 1,
                    "title": "Packaging test",
                    "content": "Test document",
                    "tags": [],
                    "original_file_name": "sample.pdf",
                }
            else:
                self.send_error(404)
                return
            body = json.dumps(data).encode()
            content_type = "application/json"
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


# Explicitly bind both services to loopback, including outside the Nix sandbox.
mock = http.server.ThreadingHTTPServer(("127.0.0.1", 0), PaperlessMock)
threading.Thread(target=mock.serve_forever, daemon=True).start()
with socket.socket() as listener:
    listener.bind(("127.0.0.1", 0))
    port = listener.getsockname()[1]
base_url = f"http://127.0.0.1:{port}"

# Do not use proxy settings for the local test servers.
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def get(path, timeout=5):
    return opener.open(base_url + path, timeout=timeout)


with tempfile.TemporaryDirectory() as work:
    env = dict(os.environ)
    env.update(
        HOME=work,
        PAPERLESS_BASE_URL=f"http://127.0.0.1:{mock.server_port}",
        PAPERLESS_API_TOKEN="test-token",
        LLM_PROVIDER="openai",
        LLM_MODEL="gpt-4o",
        OPENAI_API_KEY="test-key",
        OPENAI_BASE_URL=f"http://127.0.0.1:{mock.server_port}/v1",
        VISION_LLM_PROVIDER="openai",
        VISION_LLM_MODEL="gpt-4o",
        OCR_PROVIDER="llm",
        LISTEN_INTERFACE=f"127.0.0.1:{port}",
        PAPERLESS_GPT_CACHE_DIR=f"{work}/cache",
    )
    with open(f"{work}/server.log", "w+") as log:
        process = subprocess.Popen([binary], cwd=work, env=env, stdout=log, stderr=log)
        try:
            deadline = time.monotonic() + 90
            while True:
                assert process.poll() is None, "paperless-gpt exited during startup"
                try:
                    with get("/api/version") as response:
                        assert json.load(response)["version"] == version
                    break
                except (urllib.error.URLError, TimeoutError):
                    if time.monotonic() >= deadline:
                        raise TimeoutError("paperless-gpt did not become ready")
                    time.sleep(0.2)

            # There is no source tree in the working directory: the frontend
            # must be embedded, defaults must come from the installed package.
            with get("/") as response:
                html = response.read().decode()
            asset = re.search(r'src="(\./assets/[^\"]+\.js)"', html)
            assert asset, "embedded index.html has no JavaScript bundle"
            with get(asset[1][1:]) as response:
                assert len(response.read()) > 1000
            assert not Path(work, "default_prompts").exists()
            assert len(list(Path(work, "prompts").glob("*.tmpl"))) >= 8
            assert Path(work, "db/modification_history.db").is_file()

            # Rendering a real PDF also checks that the PDFium WASM module is
            # present in the Go vendor tree and in the installed executable.
            with get("/api/documents/1/pages/0/image", timeout=120) as response:
                assert response.headers.get_content_type() == "image/jpeg"
                assert response.read().startswith(b"\xff\xd8\xff")
            print(
                "Passed: startup, version, embedded frontend, prompts, SQLite, PDF rendering"
            )
        except BaseException:
            log.flush()
            log.seek(0)
            print(log.read(), file=sys.stderr)
            raise
        finally:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            mock.shutdown()
            mock.server_close()
