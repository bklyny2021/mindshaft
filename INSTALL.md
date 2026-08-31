# Installing MindShaft (with Bob, the LLM helper)

This guide walks you through installing **MindShaft 0.2.2** — a Minecraft-style voxel sandbox — and getting **Bob**, the LLM helper bot, running with live vision and chat.

---

## 1. Install the game (Godot)

MindShaft runs in **Godot 4.7** (a free, open-source engine). You only need the engine — no compile step, no build tools.

**Option A — Godot editor (recommended):**
1. Download **Godot 4.7** (standard release, not .NET) from https://godotengine.org/download
2. Download **MindShaft** source: `git clone https://github.com/bklyny2021/mindshaft.git` (or grab the ZIP from the repo page)
3. Open the Godot editor, click **Import**, choose `project.godot` from the folder you downloaded
4. Press the **Play** button (▶)

**Option B — Command line (if `godot` is on your PATH):**
```bash
cd mindshaft
godot --path .
```

**Controls:** WASD move · mouse look · space jump · shift sprint · left-click mine/attack · right-click place · 1–9/scroll select · **E** inventory & crafting · **Enter** chat.

> The game is fully playable right away — Bob's chat works with scripted replies without any extra setup.

---

## 2. Give Bob a real LLM brain (optional, but recommended)

Bob's companion behaviors (follow, help-mine, guard, stay) work as soon as you load the world. To let him **see through his own 90° camera** and get **live chat replies**, run his local brain, which needs two things already on your machine:

### 2a. Install Ollama
Download and install **Ollama** from https://ollama.com (free, runs locally, no cloud).

### 2b. Pull a vision-capable model
Bob's brain uses a local vision model via Ollama:
```bash
ollama pull qwen2.5vl:7b      # proven to work with Bob (a bit larger)
# or a smaller lighter option:
ollama pull gemma3:4b
```
> The server currently points at `qwen2.5vl:7b` (see `bob_server.py`). If you pull a different model, change the `VISION_MODEL` line in `bob_server.py` to match.

### 2c. Run the Bob server
```bash
python bob_server.py
```
This starts a small local bridge on `127.0.0.1:8642` — **no other dependencies** (it uses only the Python standard library). Leave it running in the background while you play.

---

## 3. Play together

1. Launch MindShaft (step 1) with the Bob server running (step 2c).
2. **Bob** spawns near you — a blue blocky companion that follows your footsteps and helps you mine whatever you're aiming at.
3. Press **Enter** to open the chat and talk to Bob:
   - `follow` — he tails you
   - `guard` — he patrols a ring around you
   - `stay` / `wait` — he holds position
   - `mine that` — he focuses on breaking your target
   - `help` — lists his commands

---

## 4. Saving your world

MindShaft **autosaves every 15 seconds** to `user://mindshaft_save.json` (your mined/placed blocks, position, and health). Quit and reopen anytime — your world comes back.

---

## Troubleshooting

- **Bob won't move / no vision:** make sure `bob_server.py` is running and Ollama is up (`curl http://127.0.0.1:11434/api/tags` should list your model). Check the console for "BobServer listening".
- **Bob lags behind on fast runs:** that's expected — he matches your pace but needs the trail to catch up; he stays close when you slow down.
- **Model not found:** run `ollama pull <name>` for the model in `VISION_MODEL`.
- **No sound:** MindShaft currently has no audio (a known roadmap item).

---

## License & credits

- Game code adapted from **Godotcraft** (MIT) — https://github.com/Godot-Templates/Godotcraft
- Textures from the **ProgrammerArt** pack (CC-BY) — https://github.com/deathcap/ProgrammerArt
- LLM helper uses a local model via **Ollama**
- Inspired by Mojang's Minecraft (independent fan project, not affiliated)
