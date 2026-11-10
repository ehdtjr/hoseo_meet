#!/usr/bin/env python3
"""Loopback-only synthetic API for tool/session_recovery_probe.dart.

Not a JWT validator or application server. Never use real accounts/credentials.
Control: POST /control {"mode": "ok"|"transient"|"reject", "expire": true}.
Evidence: GET /snapshot returns ordered sanitized events, never token strings.
"""
import base64
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import threading
import time

LOCK = threading.RLock()
STATE = {"mode": "ok", "generation": 0, "expired": False, "events": []}


def token(ttl):
    STATE["generation"] += 1
    STATE["expired"] = False
    payload = json.dumps({"exp": int(time.time()) + ttl,
                          "generation": STATE["generation"]}).encode()
    return "probe." + base64.urlsafe_b64encode(payload).decode().rstrip("=") + ".synthetic"


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def reply(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def event(self, name, **data):
        STATE["events"].append({"event": name, "at": time.time(), **data})

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        with LOCK:
            if self.path == "/control":
                control = json.loads(body)
                if "mode" in control:
                    assert control["mode"] in ("ok", "transient", "reject")
                    STATE["mode"] = control["mode"]
                if control.get("expire"):
                    STATE["expired"] = True
                self.reply(200, {"ok": True})
            elif self.path.endswith("/auth/login"):
                access = token(3)
                self.event("login", generation=STATE["generation"], ttl=3)
                self.reply(200, {"access_token": access, "refresh_token": "synthetic-refresh"})
            elif self.path.endswith("/auth/refresh"):
                mode = STATE["mode"]
                self.event("refresh", mode=mode)
                if mode == "transient":
                    self.reply(503, {"detail": "Synthetic temporary failure"})
                elif mode == "reject":
                    self.reply(400, {"detail": "Synthetic rejected credential"})
                else:
                    access = token(3600)
                    self.reply(200, {"access_token": access, "refresh_token": "synthetic-refresh"})
            elif self.path.endswith("/auth/logout"):
                self.reply(200, {})
            else:
                self.reply(404, {})

    def do_GET(self):
        with LOCK:
            if self.path == "/snapshot":
                self.reply(200, STATE)
                return
            try:
                raw = self.headers["Authorization"].split()[1].split(".")[1]
                claims = json.loads(base64.urlsafe_b64decode(raw + "=" * (-len(raw) % 4)))
                valid = claims["exp"] > time.time() and not STATE["expired"]
            except (KeyError, IndexError, ValueError, TypeError):
                claims, valid = {}, False
            self.event("request", path=self.path, valid=valid,
                       generation=claims.get("generation"))
            if not valid:
                self.reply(401, {"detail": "Synthetic expired credential"})
            elif "/subscriptions" in self.path:
                self.reply(200, {"subscriptions": [{
                    "stream_id": 10, "creator_id": 1, "type": "meet",
                    "name": f"Session recovery room v{claims['generation']}",
                    "subscribers": [], "last_message": "No messages",
                }]})
            elif self.path.endswith("/random/match/queue"):
                self.reply(200, {"status": "idle"})
            else:
                self.reply(404, {})


if __name__ == "__main__":
    print("Synthetic session probe listening on 127.0.0.1:18810", flush=True)
    ThreadingHTTPServer(("127.0.0.1", 18810), Handler).serve_forever()
