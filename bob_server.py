#!/usr/bin/env python3
"""
BobServer — the local bridge that gives Bob (MindShaft 0.2.0) a real brain.

Bob's 90-degree camera captures a PNG in the game. This server:
  1. Receives that screenshot + a short world-state line via HTTP (JSON POST).
  2. Asks the local baby LLM (gemma3:1b via Ollama, under 1GB, vision-capable)
     to decide Bob's next action.
  3. Returns a JSON command: {"action": "follow|stay|mine|move|jump|none",
     "dir": "forward|left|right|back"} that the game executes on Bob.

Runs as a background process on 127.0.0.1:8642 (windowless). No external deps
beyond the stdlib http.server; talks to Ollama's HTTP API.
"""
import base64
import json
import os
import sys
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

OLLAMA = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434/api/generate")
VISION_MODEL = "qwen2.5vl:7b"        # proven vision model (already installed + tested)
VISION_BACKEND = True

SYSTEM = (
    "You are Bob, a friendly Minecraft companion bot inside MindShaft. "
    "Look at the screenshot of what your camera sees and the world state. "
    "Reply with ONE action only from this exact set: "
    "follow, stay, mine, move_forward, move_left, move_right, move_back, jump, none. "
    "Prefer 'follow' to stay with the player unless you see an obstacle or the "
    "state says mine. Reply with just the action word."
)


def call_llm(image_b64: str, world_state: str) -> str:
    body = {
        "model": VISION_MODEL,
        "prompt": f"{SYSTEM}\nWorld state: {world_state}\nWhat action?",
        "stream": False,
        "images": [image_b64] if VISION_BACKEND else [],
    }
    req = urllib.request.Request(
        OLLAMA,
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        data = json.loads(r.read().decode("utf-8"))
    return (data.get("response") or "").strip()


def decide(world_state: str, screenshot_b64: str) -> dict:
    action = "follow"
    try:
        if screenshot_b64:
            action = call_llm(screenshot_b64, world_state)
        # sanitize to known actions
        known = {"follow","stay","mine","move_forward","move_left","move_right","move_back","jump","none"}
        word = action.strip().split()[0].lower().strip(".,!?\"'") if action else "follow"
        if word not in known:
            word = "follow"
        return {"action": word}
    except Exception as e:  # network/model hiccup -> safe default
        return {"action": "follow", "note": f"llm_error:{e}"}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self._respond(200, {"status": "ok", "model": VISION_MODEL})

    def do_POST(self):
        try:
            ln = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(ln).decode("utf-8"))
            world = payload.get("world_state", "")
            b64 = payload.get("screenshot", "")
            result = decide(world, b64)
            self._respond(200, result)
        except Exception as e:
            self._respond(500, {"action": "follow", "note": f"err:{e}"})

    def _respond(self, code: int, obj: dict):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        sys.stderr.write("[bob] " + (fmt % args) + "\n")


if __name__ == "__main__":
    port = int(os.environ.get("BOB_PORT", "8642"))
    print(f"BobServer listening on 127.0.0.1:{port} (model {VISION_MODEL})", flush=True)
    HTTPServer(("127.0.0.1", port), Handler).serve_forever()
