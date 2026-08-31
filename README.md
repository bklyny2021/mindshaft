# MindShaft

**MindShaft 0.2.2** — a Minecraft-style voxel survival sandbox for desktop, built in **Godot 4.7**, with an **LLM-powered helper bot**.

You can mine and place blocks, gather resources, craft tools and armor, and explore a procedurally generated world with day/night, weather, animals, and NPC villagers. Your companion **Bob** — a local LLM-driven helper — follows you, helps you mine, sees the world through his own first-person camera, and chats with you in-game.

## Features
- First-person (R toggles third-person) block mining & placing with mining-crack feedback
- Procedural infinite world with real textures, biomes, trees, water, and day/night cycle
- Passive animals, day/night cycle, weather
- Crafting (2×2 grid): wood → planks → crafting table, sticks, pickaxes, swords, axes, torches, iron armor
- Tool speeds: a pickaxe/axe mines its matching blocks faster; higher tiers are faster
- Combat: bare hands are weakest, swords scale by tier
- **Bob the LLM helper bot** — follows your footsteps, helps you mine, sees through his own 90° camera, and obeys live in-game chat commands (`follow` / `guard` / `stay` / `mine that` / `help`). Powered by a local vision-capable model via `bob_server.py`.
- NPC villagers with homes and jobs that go inside and lock their doors at night
- Save/load: the world (your built/mined blocks, position, health) persists between sessions

## Run
Open the project in Godot 4.7 and press **Play**, or run:
```
godot --path .
```

> **Full install guide (with Bob):** see [INSTALL.md](INSTALL.md).

### Optional: run Bob's LLM brain
Bob's chat works out of the box with scripted replies. To give him a real vision-driven brain, start the local bridge (needs Ollama + a vision model):
```
python bob_server.py
```

## Controls
- **WASD** move · **mouse** look · **space** jump · **shift** sprint
- **Left-click** mine / attack · **Right-click** place / use
- **1–9 / scroll** select hotbar slot · **E** inventory & crafting
- **Enter** chat (talk to Bob) · **Esc** release mouse / menu

## License & credits
- Game code adapted from **Godotcraft** (MIT) — https://github.com/Godot-Templates/Godotcraft
- Block/item textures from the **ProgrammerArt** texture pack (CC-BY) — https://github.com/deathcap/ProgrammerArt
- LLM helper uses a local model via **Ollama** (optional)
- Inspired by Mojang's Minecraft (this is an independent fan project, not affiliated)
