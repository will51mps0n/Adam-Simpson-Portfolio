# Cave Hunt: cave system builder (Roblox)

Two Studio scripts for an asymmetric hide-and-seek game: one player is the monster and everyone else hides.

| File | What it does |
| --- | --- |
| `CaveBuilder.lua` | Carves the whole cave out of terrain and fills it with rooms, tunnels, hiding spots, lights, a spawn and monster spawns. |
| `PlaceAssets.lua` | Takes **your** models from Workspace (shelves, container, big room, …) and puts copies on free spots around the cave. |

## 1. Build the cave

Paste this into the **Command Bar** (View → Command Bar), press Enter, then **File → Save**:

```lua
local H=game:GetService("HttpService") H.HttpEnabled=true local M=Instance.new("ModuleScript") M.Source=H:GetAsync("https://raw.githubusercontent.com/will51mps0n/Adam-Simpson-Portfolio/57e59422176e590d751889ac97c1fc96d3d7732c/roblox/cave-hunt/CaveBuilder.lua",true) require(M)()
```

It downloads `CaveBuilder.lua` from GitHub and runs it. It also turns on **Allow HTTP Requests** for the place, which the download needs.

Studio freezes for a few seconds while the terrain is carved. That's normal. When it's done, the Output window prints a summary and the camera jumps to Base Camp.

The cave sits **underground, around Y = -200, below your Baseplate**, so the map you already have up top isn't touched and can become the lobby later. To look around in Studio, select `Workspace.CaveSystem.Spawn.CaveSpawn` and press **F**.

**Options** go in the last brackets of the command, for example `require(M)({ SEED = 7 })` or `require(M)({ TUNNEL_SIZE = 1.3, DARK_LIGHTING = true })`. See [Settings](#settings) below.

**Getting a newer version:** when the scripts are updated, you get a new command with a new commit in the link. Once a cave exists, the script won't build over it unless you end the command with `require(M)({ OVERWRITE = true })`. **That wipes the cave and anything you changed inside it**, so make your hand edits outside `Workspace.CaveSystem`, or redo them after a rebuild.

## 2. Put your own models in the cave

After the cave is built, run this in the Command Bar, then **File → Save**:

```lua
local H=game:GetService("HttpService") H.HttpEnabled=true local M=Instance.new("ModuleScript") M.Source=H:GetAsync("https://raw.githubusercontent.com/will51mps0n/Adam-Simpson-Portfolio/57e59422176e590d751889ac97c1fc96d3d7732c/roblox/cave-hunt/PlaceAssets.lua",true) require(M)()
```

You don't need to set anything up first. **The first time it runs, it picks up the models already in your Workspace** and moves them into **ServerStorage → CaveAssets**, sorted by size:

- **Hiding**: at least 5 studs tall and no more than 30 studs across, like shelves or a container. The copies get the `HidingSpot` tag plus HidePoint/ExitPoint parts.
- **Decor**: everything else, including your big room.

It leaves alone the Baseplate, SpawnLocations, flat parts, and anything with a Humanoid or "monster" in its name, so your monster stays put. The Output window lists where each model went.

Then it puts copies in the cave: 3 of each hiding model, 2 of each decoration, and 1 of anything wider than 30 studs. The biggest go first, so your big room gets the roughly 90-stud open space in the Great Cavern.

- **Wrong folder?** Drag the model to the other folder in ServerStorage → CaveAssets and run the command again.
- **New models later:** drag them straight into CaveAssets → Hiding or Decor and run it again. After the first run it no longer looks in Workspace, so your lobby is safe. To make it look in Workspace again, end the command with `require(M)({ COLLECT_FROM_WORKSPACE = true })`.
- **Reshuffle:** run it again. It only replaces `Workspace.CaveSystem.PlacedAssets`.
- **Per-model control (attributes):** `Count` (number) sets how many copies; `CaveRole` (string) set to `Hiding`, `Decor` or `Skip` overrides the sorting.

## Map

North is -Z. Base Camp is in the south, and the monster lairs are spread across the far side.

```
        LairNorthWest ------ LairNorth ------ LairNorthEast
              |                  |                  |
 LairWest -- ShackTown ------ TheAbyss ------ SunkenLake -- LairEast
    |             \              |              /            |
    |              `------ GreatCavern --------'             |
    |                     /      |      \                    |
 OldMine ----------------'       |       `------------- CrystalGrotto
       \                         |                        /
        `-------------------- BaseCamp ------------------'
```

- **BaseCamp**: player spawn, campfire, tents, sign.
- **GreatCavern**: huge hall with a 90-stud open spot for your big room, 2 shacks, rock pillars, lockers and wardrobes.
- **OldMine**: timber supports, rails, mine carts you can hide in, lockers.
- **CrystalGrotto**: glowing crystals, crates and barrels.
- **ShackTown**: 5 shacks (each has a wardrobe inside) and 2 outhouses.
- **SunkenLake**: a pool with a dock, an island with a barrel, a fisherman's shack.
- **TheAbyss**: very tall cavern with pillars and 2 climbable scaffolds (one has a barrel on top).
- **5 lairs**: dark red rooms with bones, one `MonsterSpawn` each. They are 410–670 studs from Base Camp.
- **About 14 nooks**: small dead-end alcoves off the tunnels, each with a hiding spot.

The cave has about 49 hiding spots, about 90 lights, and around 20 PropSpots for your assets.

## Settings

Pass these in the last brackets of the command, like `require(M)({ SEED = 7, OVERWRITE = true })`.

**CaveBuilder**

| Setting | Default | Meaning |
| --- | --- | --- |
| `ORIGIN` | `Vector3.new(0, -200, 0)` | Where the cave is built (keep Y a multiple of 4) |
| `SEED` | `2024` | Change it to get a different random layout of tunnels and props |
| `OVERWRITE` | `false` | Must be `true` to rebuild once a cave exists. **This wipes your edits inside the cave.** |
| `TUNNEL_SIZE` | `1` | Tunnels are about 11–23 studs tall (nook passages about 9–12). Use `1.3` or more if the monster is big. |
| `DISABLE_OTHER_SPAWNS` | `true` | Disables your other SpawnLocations so playtests start in the cave |
| `DARK_LIGHTING` | `false` | Darker Lighting for a scarier mood (this affects the whole place) |
| `LIGHT_SHADOWS` | `false` | Shadows from the lanterns (prettier, but slower) |
| `MOVE_CAMERA` | `true` | Moves the Studio camera to Base Camp when it's done |

**PlaceAssets**

| Setting | Default | Meaning |
| --- | --- | --- |
| `SEED` | `false` | `false` = a new arrangement every run. A number gives the same arrangement each time. |
| `HIDING_COPIES` | `3` | Copies of each model in `Hiding` |
| `DECOR_COPIES` | `2` | Copies of each model in `Decor` |
| `BIG` | `30` | Models wider than this many studs are placed once (unless they have a `Count` attribute) |
| `COLLECT_FROM_WORKSPACE` | `"auto"` | `"auto"` = pick up models from Workspace only the first time (before CaveAssets exists); `true` = every run; `false` = never |

## Tags for the gameplay scripts

These are CollectionService tags, so they work wherever the object is in the tree.

| Tag | On | Notes |
| --- | --- | --- |
| `HidingSpot` | Model | Has `HidePoint` (where the hider goes) and `ExitPoint` (where they get knocked out to). Attributes: `HideType`, `Occupied`. Lockers, wardrobes and outhouses have a `Door` / `DoorL` / `DoorR` part. Barrels and crates have a `Lid`. |
| `MonsterSpawn` | Part | Attributes: `Room`, `DistanceFromPlayerSpawn` |
| `PlayerSpawn` | SpawnLocation | Base Camp |
| `PropSpot` | Part | Attributes: `MaxFootprint`, `MaxHeight`, `Room` |
| `CaveRoom` | Part | Invisible box around each room. Attribute: `RoomKind` (`Spawn`, `Big`, `Room`, `Lair`, `Nook`) |

## Remove the cave completely

```lua
workspace.CaveSystem:Destroy() workspace.Terrain:FillBlock(CFrame.new(0, -164, 0), Vector3.new(808, 208, 808), Enum.Material.Air)
```

(This assumes the default `ORIGIN`. Re-enable your old SpawnLocation by hand if it was disabled.)
