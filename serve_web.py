#!/usr/bin/env python3
"""
Angel Game Web Server
High-performance multi-threaded HTTP server for Godot 4 Web exports.
Supports byte range requests, cross-origin isolation headers, and graceful disconnect handling.
"""

import argparse
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import mimetypes
import os
import re
import socket
import sys
import urllib.parse
import webbrowser

DEFAULT_PORT = 8060
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
WEB_DIR = os.path.join(BASE_DIR, "build", "web")

# MIME type configurations for Godot 4 Web exports
mimetypes.init()
mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("application/octet-stream", ".pck")
mimetypes.add_type("application/javascript", ".js")
mimetypes.add_type("text/html; charset=utf-8", ".html")
mimetypes.add_type("image/png", ".png")
mimetypes.add_type("image/x-icon", ".ico")

RANGE_REGEX = re.compile(r"^bytes=(\d*)-(\d*)$")
DISCONNECT_EXCEPTIONS = (
    ConnectionResetError,
    ConnectionAbortedError,
    BrokenPipeError,
    TimeoutError,
)


class ThreadingGodotServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True
    request_queue_size = 16
    block_on_close = False

    def handle_error(self, request, client_address):
        """Silences normal browser disconnects and socket abortions."""
        exc_type, _, _ = sys.exc_info()
        if exc_type in DISCONNECT_EXCEPTIONS:
            return
        super().handle_error(request, client_address)


class GodotWebRequestHandler(SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def end_headers(self):
        # Cross-Origin Isolation headers for Godot 4 Web execution
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Accept-Ranges", "bytes")
        super().end_headers()

    def do_GET(self):
        try:
            super().do_GET()
        except DISCONNECT_EXCEPTIONS:
            pass

    def do_HEAD(self):
        try:
            super().do_HEAD()
        except DISCONNECT_EXCEPTIONS:
            pass

    def send_head(self):
        """Serves files with HTTP Range (206 Partial Content) support."""
        path = self.translate_path(self.path)
        f = None
        if os.path.isdir(path):
            parts = urllib.parse.urlsplit(self.path)
            if not parts.path.endswith("/"):
                self.send_response(HTTPStatus.MOVED_PERMANENTLY)
                new_parts = (parts[0], parts[1], parts[2] + "/", parts[3], parts[4])
                self.send_header("Location", urllib.parse.urlunsplit(new_parts))
                self.send_header("Content-Length", "0")
                self.end_headers()
                return None
            for index in ("index.html", "index.htm"):
                candidate = os.path.join(path, index)
                if os.path.exists(candidate):
                    path = candidate
                    break
            else:
                return super().send_head()

        ctype = self.guess_type(path)
        try:
            f = open(path, "rb")
        except OSError:
            self.send_error(HTTPStatus.NOT_FOUND, "File not found")
            return None

        try:
            fs = os.fstat(f.fileno())
            file_len = fs.st_size
            range_header = self.headers.get("Range")

            if range_header:
                match = RANGE_REGEX.match(range_header.strip())
                if match:
                    start_str, end_str = match.groups()
                    if start_str and end_str:
                        start = int(start_str)
                        end = int(end_str)
                    elif start_str:
                        start = int(start_str)
                        end = file_len - 1
                    elif end_str:
                        start = max(0, file_len - int(end_str))
                        end = file_len - 1
                    else:
                        start = 0
                        end = file_len - 1

                    if start <= end < file_len:
                        self.send_response(HTTPStatus.PARTIAL_CONTENT)
                        self.send_header("Content-Type", ctype)
                        self.send_header("Content-Range", f"bytes {start}-{end}/{file_len}")
                        self.send_header("Content-Length", str(end - start + 1))
                        self.send_header("Last-Modified", self.date_time_string(fs.st_mtime))
                        self.end_headers()
                        f.seek(start)
                        self._range_bytes = end - start + 1
                        return f
                    else:
                        self.send_error(HTTPStatus.RANGE_NOT_SATISFIABLE)
                        self.send_header("Content-Range", f"bytes */{file_len}")
                        self.end_headers()
                        f.close()
                        return None

            # Standard full file response
            self._range_bytes = None
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(file_len))
            self.send_header("Last-Modified", self.date_time_string(fs.st_mtime))
            self.end_headers()
            return f
        except Exception:
            f.close()
            raise

    def copyfile(self, source, outputfile):
        """Streams content with 128KB buffering and safe disconnect suppression."""
        try:
            bufsize = 128 * 1024
            remaining = getattr(self, "_range_bytes", None)
            if remaining is not None:
                while remaining > 0:
                    chunk = source.read(min(bufsize, remaining))
                    if not chunk:
                        break
                    outputfile.write(chunk)
                    remaining -= len(chunk)
            else:
                while True:
                    chunk = source.read(bufsize)
                    if not chunk:
                        break
                    outputfile.write(chunk)
        except DISCONNECT_EXCEPTIONS:
            # Client aborted or refreshed connection - suppressed cleanly
            pass

    def log_message(self, format, *args):
        sys.stdout.write(f"[{self.log_date_time_string()}] {format % args}\n")
        sys.stdout.flush()


def get_lan_ip():
    """Detects primary network IP address."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.settimeout(0.25)
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except (OSError, TimeoutError):
        return "127.0.0.1"


def find_available_port(starting_port, max_tries=10):
    """Return a free port, or None when the bounded range is exhausted."""
    if not isinstance(starting_port, int) or not 1 <= starting_port <= 65535:
        return None
    if not isinstance(max_tries, int) or max_tries < 1:
        return None
    end_port = min(65536, starting_port + max_tries)
    for port in range(starting_port, end_port):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                if s.connect_ex(("127.0.0.1", port)) != 0:
                    return port
        except OSError:
            continue
    return None


def _create_server(port):
    try:
        return ThreadingGodotServer(("0.0.0.0", port), GodotWebRequestHandler)
    except OSError as exc:
        print(f"Error: Could not bind Web server to port {port}: {exc}")
        return None


def main():
    parser = argparse.ArgumentParser(description="Host the Angel Godot Web build.")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="Port to host on (default: 8060)")
    parser.add_argument("--no-browser", action="store_true", help="Do not automatically open browser")
    # start_server.bat consumes this flag for its optional export step, but
    # Windows batch files cannot portably rewrite %* after SHIFT. Accept it
    # here as a hidden no-op so `start_server.bat --reexport --no-browser`
    # still reaches the server instead of failing argparse.
    parser.add_argument("--reexport", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()

    if not 1 <= args.port <= 65535:
        parser.error("--port must be between 1 and 65535")

    if not os.path.exists(os.path.join(WEB_DIR, "index.html")):
        print(f"Error: Web build not found at {WEB_DIR}")
        print("Please export the project first using Godot or start_server.bat")
        sys.exit(1)

    port = find_available_port(args.port)
    if port is None:
        print(f"Error: No available port in the range {args.port}-{min(65535, args.port + 9)}")
        sys.exit(1)
    lan_ip = get_lan_ip()

    httpd = _create_server(port)
    if httpd is None:
        sys.exit(1)

    local_url = f"http://localhost:{port}/"
    lan_url = f"http://{lan_ip}:{port}/"

    print("=" * 60)
    print("  ANGEL GAME WEB SERVER - ONLINE")
    print("=" * 60)
    print(f"  Local Host:      {local_url}")
    print(f"  Network/LAN:     {lan_url}")
    print("=" * 60)
    print("  Port to forward: 8060 (HTTP)")
    print("  Press Ctrl+C to shut down the server.")
    print("=" * 60)

    if not args.no_browser:
        try:
            webbrowser.open(local_url)
        except Exception as e:
            print(f"Note: Could not open browser automatically: {e}")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server...")
    finally:
        httpd.server_close()
        print("Server stopped.")


if __name__ == "__main__":
    main()
