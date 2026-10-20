# Tiny Ninjas

A multiplayer Roblox platformer that plays like the classic Flash game N:
one-screen levels, momentum physics, wall jumps, and ninjas that can bump into each other.
Everything is generated from code with [Rojo](https://rojo.space).

## Install it from Studio (no tools needed)

1. In Roblox Studio, open a new Baseplate place (or your saved Tiny Ninjas place).
2. Open View > Command Bar, paste the install command, and press Enter.
3. Press Play to test, and File > Save to keep it.

The install command, with `COMMIT` replaced by the commit to install (each milestone message gives a ready-made one):

```lua
local C="COMMIT" local H=game:GetService("HttpService") H.HttpEnabled=true local M=Instance.new("ModuleScript") M.Source=H:GetAsync("https://raw.githubusercontent.com/will51mps0n/Adam-Simpson-Portfolio/"..C.."/tiny-ninjas/studio/install.luau",true) require(M)(C)
```

It downloads the game's scripts from that commit, replaces the old ones in the place, removes
Studio's default haze and glow effects, and turns HTTP back off.
`studio/install.luau` is generated: after adding, removing or moving a script, run `python3 tools/build_installer.py`.

## Controls

| | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Run | A / D or Left / Right | Left stick or d-pad | Big buttons bottom-left |
| Jump (hold for higher) | Space, W, Up or Z | A | Button bottom-right |
| Restart | K or R | Y | Small button above jump |

Until the menus arrive (milestone 4), the number keys 1-6 switch between the test levels.

## Or build it with Rojo

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder (it installs the Rojo version listed in `rokit.toml`).
2. Run `rojo build -o TinyNinjas.rbxlx`.
3. Open `TinyNinjas.rbxlx` in Roblox Studio and press Play.

For live editing: run `rojo plugin install` once, then `rojo serve`, and in Studio click Rojo > Connect.

## Where things are

| Path | What it holds |
| --- | --- |
| `src/shared/Config.luau` | Every tunable number: movement, enemies, colors, camera, timer |
| `src/shared/Levels/` | One file per level: an ASCII tile grid plus a list of objects |
| `src/shared/TileShapes.luau` | The tile characters and the shape each one draws |
| `src/shared/LevelBuilder.luau` | Turns a level into Parts |
| `src/shared/Sim/` | Pure simulation: collision, ninja movement, animation, ragdoll, object shapes |
| `src/shared/Net/Protocol.luau` | Remotes and the packed messages between server and clients |
| `src/server/LevelSession.luau` | A level being played: gold, switches, enemies, checks on what clients report |
| `src/server/Enemies/` | Enemy behavior, simulated on the server 30 times a second |
| `src/client/ClientSession.luau` | The game loop on each player's client |
| `src/client/World/` | Drawing objects and enemies, and checking what our ninja touches |
| `src/client/Ninja/NinjaRig.luau` | The stick-figure parts |

Each player's own client simulates their ninja and decides its deaths. Enemies, gold and
switches live on the server, which streams enemy positions to clients; each client draws
them a tenth of a second in the past (smoothly) and tests its ninja against what it draws.

### Tile characters

```
.  empty            #  full block

/  slope, solid bottom-right     \  slope, solid bottom-left
F  slope, solid top-left         7  slope, solid top-right

q w a s   convex quarter circle (rounded block corner), solid corner by keyboard position:  q w
Q W A S   concave quarter circle (quarter-pipe), solid corner by keyboard position:         a s
```

Everything outside a level's grid counts as wall.

### Level objects

Objects sit in a tile (`x`, `y` count from 0 at the top-left; halves like `4.5` sit between tiles):

| type | options |
| --- | --- |
| `spawn` | |
| `gold` | |
| `exitSwitch`, `exitDoor` | `group` pairs them (default 1) |
| `door` (opens when a ninja is near), `lockedDoor`, `trapDoor` | `orient = "v"` (default) or `"h"`; locked and trap doors: `switch = { x = , y = }` |
| `launchPad` | `dir = "up"` (default), `"right"`, `"upleft"`... |
| `bounceBlock` | |
| `oneWay` | `dir` = the side it's solid from, default `"up"` |
| `mine` | |
| `zapDrone`, `laserDrone`, `chaingunDrone` | `move = "cw"`, `"ccw"`, `"bounce"`, `"path"` or `"still"`; `dir`; `path = { { x = , y = }, ... }`; zap drones: `seeker = true` |
| `floorGuard` | stands on the floor of its tile |
| `thwump` | `dir` = its deadly side (default `"left"`) |
| `gaussTurret`, `rocketTurret` | |

## Progress

- [x] Milestone 1: level renderer and camera
- [x] Milestone 2: the ninja (movement, animation, ragdoll, gold / switch / exit, time bar)
- [x] Milestone 3: enemies and objects
- [ ] Milestones 4-11: episodes and menus, multiplayer, modes, editor, polish
