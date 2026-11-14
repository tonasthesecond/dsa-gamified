#!/usr/bin/env python3
"""Serves the Godot web export the way production Caddy will: one origin,
COOP/COEP headers for threads, and /api/* proxied to the compile service.

    python3 scripts/serve_web.py [--port 8000] [--root client/build/web] [--api http://127.0.0.1:8080]
"""
import argparse
import http.server
import os
import urllib.error
import urllib.request

ISOLATION = {
    "Cross-Origin-Opener-Policy": "same-origin",
    "Cross-Origin-Embedder-Policy": "require-corp",
    "Cross-Origin-Resource-Policy": "same-origin",
}


def make_handler(root, api):
    class Handler(http.server.SimpleHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=root, **kwargs)

        def end_headers(self):
            for name, value in ISOLATION.items():
                self.send_header(name, value)
            self.send_header("Cache-Control", "no-store")
            super().end_headers()

        def do_POST(self):
            if not self.path.startswith("/api/"):
                self.send_error(404)
                return
            length = int(self.headers.get("Content-Length") or 0)
            body = self.rfile.read(length)
            request = urllib.request.Request(api + self.path[len("/api"):], data=body, method="POST",
                                             headers={"Content-Type": self.headers.get("Content-Type", "text/plain")})
            try:
                with urllib.request.urlopen(request, timeout=60) as reply:
                    status, data = reply.status, reply.read()
            except urllib.error.HTTPError as error:
                status, data = error.code, error.read()
            except OSError as error:
                status, data = 502, ("compile service unreachable: %s" % error).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

    return Handler


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--root", default=os.path.join(os.path.dirname(__file__), "..", "client", "build", "web"))
    parser.add_argument("--api", default="http://127.0.0.1:8080")
    args = parser.parse_args()
    root = os.path.abspath(args.root)
    if not os.path.isfile(os.path.join(root, "index.html")):
        raise SystemExit("no index.html in %s: export the Web preset first" % root)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", args.port), make_handler(root, args.api.rstrip("/")))
    print("serving %s on http://localhost:%d (api -> %s)" % (root, args.port, args.api))
    server.serve_forever()


if __name__ == "__main__":
    main()
