#!/usr/bin/env python3
"""Serve the repo on the LAN and collect guest measurements posted to /measure."""
import http.server
import os
import socketserver
import sys
from datetime import datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "measurements")
LOG = "/tmp/opencode/collect-server.log"
os.makedirs(OUT, exist_ok=True)
os.makedirs("/tmp/opencode", exist_ok=True)


def log(msg):
    line = f"{datetime.now().isoformat(timespec='seconds')} {msg}"
    print(line, flush=True)
    with open(LOG, "a") as f:
        f.write(line + "\n")


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def do_POST(self):
        if self.path != "/measure":
            self.send_error(404, "not found")
            return
        n = int(self.headers.get("Content-Length", "0") or 0)
        body = self.rfile.read(n)
        name = "guest-" + datetime.now().strftime("%Y%m%d-%H%M%S") + ".txt"
        path = os.path.join(OUT, name)
        with open(path, "wb") as f:
            f.write(body)
        log(f"POST /measure from {self.client_address[0]} saved {name} ({len(body)} bytes)")
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"ok\n")

    def log_message(self, fmt, *args):
        log(f"{self.client_address[0]} {fmt % args}")


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    log(f"serving {ROOT} on 0.0.0.0:{port}")
    Server(("0.0.0.0", port), Handler).serve_forever()
