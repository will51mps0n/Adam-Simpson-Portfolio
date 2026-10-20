# Tiny Ninjas

A multiplayer Roblox platformer that plays like the classic Flash game N:
one-screen levels, momentum physics, wall jumps, and ninjas that can bump into each other.
Everything is generated from code with [Rojo](https://rojo.space).

## Build it

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder (it installs the Rojo version listed in `rokit.toml`).
2. Run `rojo build -o TinyNinjas.rbxlx`.
3. Open `TinyNinjas.rbxlx` in Roblox Studio and press Play.

For live editing: run `rojo plugin install` once, then `rojo serve`, and in Studio click Rojo > Connect.

## Where things are

| Path | What it holds |
| --- | --- |
| `src/shared/Config.luau` | Every tunable number: colors, camera, movement, timer |
| `src/shared/Levels/` | One file per level: an ASCII tile grid plus a list of objects |
| `src/shared/TileShapes.luau` | The tile characters and the shape each one draws |
| `src/shared/LevelBuilder.luau` | Turns a level into Parts |
| `src/client/` | Camera, level loading and (for now) the milestone 1 test helper |
| `src/server/` | Server setup |

### Tile characters

```
.  empty            #  full block

/  slope, solid bottom-right     \  slope, solid bottom-left
F  slope, solid top-left         7  slope, solid top-right

q w a s   convex quarter circle (rounded block corner), solid corner by keyboard position:  q w
Q W A S   concave quarter circle (quarter-pipe), solid corner by keyboard position:         a s
```

Everything outside a level's grid counts as wall.

## Progress

- [x] Milestone 1: level renderer and camera
- [ ] Milestone 2: the ninja
- [ ] Milestones 3-11: enemies, episodes, multiplayer, modes, editor, polish
