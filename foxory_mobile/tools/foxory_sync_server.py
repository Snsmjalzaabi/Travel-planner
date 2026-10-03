#!/usr/bin/env python3
"""Tiny local sync server for Foxory Travel & Life.

Receives JSON uploads from the phone/app and stores timestamped backups
under ~/foxory-sync/. Serves those backups back for restore/download.
Personal LAN use only.

Endpoints
  GET  /health                     -> liveness
  GET  /sync/backups               -> list of stored backups (newest first)
  GET  /sync/download?device_id=X  -> newest backup for a device
  GET  /sync/download?file=NAME    -> one specific backup
  POST /sync/upload                -> store a backup
"""
from __future__ import annotations

import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

HOST = "0.0.0.0"
PORT = 9101
OUT_DIR = Path.home() / "foxory-sync"


class Handler(BaseHTTPRequestHandler):
    server_version = "FoxorySync/1.0"

    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path == "/health":
            self._json(200, {"ok": True, "service": "foxory-sync"})
            return

        if parsed.path == "/sync/backups":
            self._handle_list(parsed)
            return

        if parsed.path == "/sync/download":
            self._handle_download(parsed)
            return

        self._json(404, {"ok": False, "error": "not found"})

    def _handle_list(self, parsed):
        query = parse_qs(parsed.query)
        device = _safe_name((query.get("device_id") or [""])[0])
        device_dir = OUT_DIR / device if device else OUT_DIR
        if not device_dir.is_dir():
            self._json(200, {"ok": True, "backups": []})
            return

        backups = []
        for f in sorted(device_dir.glob("foxory-sync-*.json"), reverse=True):
            stat = f.stat()
            backups.append({
                "file": f.name,
                "bytes": stat.st_size,
                "modified": datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat(),
            })
        self._json(200, {"ok": True, "backups": backups})

    def _handle_download(self, parsed):
        query = parse_qs(parsed.query)

        # Specific file requested. Only ever serve files under OUT_DIR.
        requested = (query.get("file") or [""])[0]
        if requested:
            candidate = (OUT_DIR / requested).resolve()
            try:
                candidate.relative_to(OUT_DIR.resolve())
            except ValueError:
                self._json(400, {"ok": False, "error": "invalid file"})
                return
            if not candidate.is_file():
                self._json(404, {"ok": False, "error": "not found"})
                return
            self._send_backup(candidate)
            return

        device = _safe_name((query.get("device_id") or [""])[0])
        device_dir = OUT_DIR / device
        latest = device_dir / "latest.json"
        if latest.is_file():
            self._send_backup(latest)
            return

        candidates = sorted(device_dir.glob("foxory-sync-*.json"), reverse=True) if device_dir.is_dir() else []
        if not candidates:
            self._json(404, {"ok": False, "error": "no backup found for this device"})
            return
        self._send_backup(candidates[0])

    def _send_backup(self, path: Path):
        try:
            raw = path.read_bytes()
        except Exception as exc:
            self._json(500, {"ok": False, "error": str(exc)})
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Content-Disposition", f'attachment; filename="{path.name}"')
        self.end_headers()
        self.wfile.write(raw)

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path != "/sync/upload":
            self._json(404, {"ok": False, "error": "not found"})
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0:
                raise ValueError("empty upload")
            raw = self.rfile.read(length)
            data = json.loads(raw.decode("utf-8"))
            device_id = _safe_name(str(data.get("device_id") or self.headers.get("X-Device-ID") or "unknown-device"))
            stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

            device_dir = OUT_DIR / device_id
            device_dir.mkdir(parents=True, exist_ok=True)
            backup_path = device_dir / f"foxory-sync-{stamp}.json"
            latest_path = device_dir / "latest.json"

            formatted = json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True)
            backup_path.write_text(formatted + "\n", encoding="utf-8")
            latest_path.write_text(formatted + "\n", encoding="utf-8")

            tables = data.get("tables") or {}
            records = sum(len(v) for v in tables.values() if isinstance(v, list))
            self._json(200, {
                "ok": True,
                "records": records,
                "path": str(backup_path),
                "server_timestamp": stamp,
            })
        except Exception as exc:
            self._json(400, {"ok": False, "error": str(exc)})

    def log_message(self, format, *args):
        print(f"[{datetime.now().isoformat(timespec='seconds')}] {self.address_string()} {format % args}")

    def _json(self, status: int, payload: dict):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def _safe_name(value: str) -> str:
    return "".join(ch if ch.isalnum() or ch in "-_." else "_" for ch in value)[:80] or "unknown-device"


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"Foxory sync server listening on http://{HOST}:{PORT}")
    print(f"Backups: {OUT_DIR}")
    httpd.serve_forever()


if __name__ == "__main__":
    main()
