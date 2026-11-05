#!/usr/bin/env python3
"""Serve the Web export with the isolation headers required by threaded Godot."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.split("?", 1)[0].split("/", 2)[1] in ("rooms", "auth", "profiles"):
            self.proxy_signal()
        else:
            super().do_GET()

    def do_POST(self):
        if self.path.split("?", 1)[0].split("/", 2)[1] in ("rooms", "auth", "profiles"):
            self.proxy_signal()
        else:
            self.send_error(404)

    def proxy_signal(self):
        length = int(self.headers.get("Content-Length", "0"))
        if length > 32000:
            self.send_error(413)
            return
        data = self.rfile.read(length) if self.command == "POST" else None
        headers = {name: self.headers[name] for name in ("Content-Type", "Authorization", "X-Room-Token") if name in self.headers}
        request = Request("http://127.0.0.1:8787" + self.path, data=data, headers=headers, method=self.command)
        try:
            response = urlopen(request, timeout=5)
        except HTTPError as error:
            response = error
        except URLError:
            self.send_error(502, "Start the signaling server on port 8787")
            return
        with response:
            payload = response.read()
            self.send_response(response.status)
            self.send_header("Content-Type", response.headers.get("Content-Type", "application/json"))
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


if __name__ == "__main__":
    web_dir = Path(__file__).resolve().parent.parent / "build" / "web"
    port = int(os.environ.get("BID_WEB_PORT", "8080"))
    server = ThreadingHTTPServer(("127.0.0.1", port), partial(Handler, directory=str(web_dir)))
    print(f"BID! Web: http://127.0.0.1:{port}", flush=True)
    server.serve_forever()
