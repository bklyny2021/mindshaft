# MindShaft

**MindShaft 0.2.2** — a Minecraft-style voxel survival sandbox for desktop, built in **Godot 4.7**.

You can mine and place blocks, gather resources, craft tools and armor, and explore a procedurally generated world with day/night, weather, animals, and NPC villagers. Your companion **Bob** follows you, helps you mine, and chats with you in-game.

## Features
- First-person (R toggles third-person) block mining & placing with mining-crack feedback
- Procedural infinite world with real textures, biomes, trees, water, and day/night cycle
- Passive animals, day/night cycle, weather
- Crafting (2×2 grid): wood → planks → crafting table, sticks, pickaxes, swords, axes, torches, iron armor
- Tool speeds: a pickaxe/axe mines its matching blocks faster; higher tiers are faster
- Combat: bare hands are weakest, swords scale by tier
- **Bob** the companion bot — follows your footsteps, helps you mine, and obeys in-game chat commands
- NPC villagers with homes and jobs that go inside and lock their doors at night
- Save/load: the world (your built/mined blocks, position, health) persists between sessions

## Run
Open the project in Godot 4.7 and press **Play**, or run:
```
godot --path .
```

## Controls
- **WASD** move · **mouse** look · **space** jump · **shift** sprint
- **Left-click** mine / attack · **Right-click** place / use
- **1–9 / scroll** select hotbar slot · **E** inventory & crafting
- **Enter** chat (talk to Bob) · **Esc** release mouse / menu

## License & credits
- Game code adapted from **Godotcraft** (MIT) — https://github.com/Godot-Templates/Godotcraft
- Block/item textures from the **ProgrammerArt** texture pack (CC-BY) — https://github.com/deathcap/ProgrammerArt
- Inspired by Mojang's Minecraft (this is an independent fan project, not affiliated)
