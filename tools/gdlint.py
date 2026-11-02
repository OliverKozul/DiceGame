"""Report every GDScript error and warning exactly as the Godot editor shows them.

Starts a headless Godot editor with its language server, opens every .gd file in the
project and prints the diagnostics it publishes. Exit code 1 if anything was reported.

    python tools/gdlint.py [--godot PATH] [--project DIR]
"""
from __future__ import annotations

import argparse
import json
import os
import socket
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import unquote, urlparse

DEFAULT_GODOT = os.environ.get(
    "GODOT", r"C:\Users\Oli\Downloads\win64-g46-s163-gs4171-editor\GodotSteam4.6.exe"
)
SKIP_DIRS = {".godot", ".git", "addons"}
SEVERITY = {1: "ERROR", 2: "WARNING", 3: "INFO", 4: "HINT"}


class Lsp:
    def __init__(self, sock: socket.socket) -> None:
        self.sock = sock
        self.buf = b""
        self.next_id = 1

    def send(self, method: str, params: dict, request: bool = False) -> int | None:
        msg: dict = {"jsonrpc": "2.0", "method": method, "params": params}
        msg_id = None
        if request:
            msg_id = self.next_id
            self.next_id += 1
            msg["id"] = msg_id
        body = json.dumps(msg).encode("utf-8")
        self.sock.sendall(b"Content-Length: %d\r\n\r\n" % len(body) + body)
        return msg_id

    def read(self, timeout: float) -> dict | None:
        self.sock.settimeout(timeout)
        while True:
            head_end = self.buf.find(b"\r\n\r\n")
            if head_end >= 0:
                length = 0
                for line in self.buf[:head_end].split(b"\r\n"):
                    if line.lower().startswith(b"content-length:"):
                        length = int(line.split(b":")[1])
                start = head_end + 4
                if len(self.buf) - start >= length:
                    body = self.buf[start : start + length]
                    self.buf = self.buf[start + length :]
                    return json.loads(body.decode("utf-8"))
            try:
                chunk = self.sock.recv(65536)
            except socket.timeout:
                return None
            if not chunk:
                return None
            self.buf += chunk


def uri_key(uri: str) -> str:
    path = unquote(urlparse(uri).path).lstrip("/")
    return os.path.normcase(os.path.normpath(path))


def find_free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default=DEFAULT_GODOT)
    ap.add_argument("--project", default=str(Path(__file__).resolve().parent.parent))
    ap.add_argument("--settle", type=float, default=20.0, help="max seconds of silence to wait")
    args = ap.parse_args()

    project = Path(args.project).resolve()
    files = sorted(
        p for p in project.rglob("*.gd") if not (SKIP_DIRS & set(p.relative_to(project).parts))
    )
    port = find_free_port()
    proc = subprocess.Popen(
        [args.godot, "--headless", "--editor", "--path", str(project), "--lsp-port", str(port)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        sock = None
        deadline = time.time() + 120
        while time.time() < deadline:
            try:
                sock = socket.create_connection(("127.0.0.1", port), timeout=1)
                break
            except OSError:
                if proc.poll() is not None:
                    print("Godot exited before the language server started", file=sys.stderr)
                    return 2
                time.sleep(0.5)
        if sock is None:
            print("Could not connect to the Godot language server", file=sys.stderr)
            return 2

        lsp = Lsp(sock)
        init_id = lsp.send(
            "initialize",
            {"processId": os.getpid(), "rootUri": project.as_uri(), "capabilities": {}},
            request=True,
        )
        while True:
            msg = lsp.read(60)
            if msg is None:
                print("No initialize response", file=sys.stderr)
                return 2
            if msg.get("id") == init_id:
                break
        lsp.send("initialized", {})

        diagnostics: dict[str, list] = {}
        for path in files:
            lsp.send(
                "textDocument/didOpen",
                {
                    "textDocument": {
                        "uri": path.as_uri(),
                        "languageId": "gdscript",
                        "version": 1,
                        "text": path.read_text(encoding="utf-8"),
                    }
                },
            )
        wanted = {uri_key(p.as_uri()) for p in files}
        while not wanted.issubset(diagnostics):
            msg = lsp.read(args.settle)
            if msg is None:
                break
            if msg.get("method") == "textDocument/publishDiagnostics":
                diagnostics[uri_key(msg["params"]["uri"])] = msg["params"]["diagnostics"]

        count = 0
        for path in files:
            for d in diagnostics.get(uri_key(path.as_uri()), []):
                count += 1
                line = d["range"]["start"]["line"] + 1
                sev = SEVERITY.get(d.get("severity", 1), "?")
                rel = path.relative_to(project).as_posix()
                print(f"{rel}:{line}: {sev}: {d['message']}")
        missing = [p for p in files if uri_key(p.as_uri()) not in diagnostics]
        for path in missing:
            print(f"{path.relative_to(project).as_posix()}: no diagnostics received (not checked)")
        print(f"{len(files)} scripts checked, {count} problem(s)")
        return 1 if count or missing else 0
    finally:
        proc.kill()


if __name__ == "__main__":
    sys.exit(main())
