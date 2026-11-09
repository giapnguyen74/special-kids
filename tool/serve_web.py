"""Dev server for the Flutter web build. Sends no-cache (browsers always load the newest build) and
cross-origin isolation headers (needed if we later switch to the WebAssembly renderer).
Usage: python3 tool/serve_web.py <dir> <port>"""
import sys
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


Handler.extensions_map[".wasm"] = "application/wasm"
Handler.extensions_map[".mjs"] = "text/javascript"

if __name__ == "__main__":
    directory, port = sys.argv[1], int(sys.argv[2])
    ThreadingHTTPServer(("127.0.0.1", port), partial(Handler, directory=directory)).serve_forever()
