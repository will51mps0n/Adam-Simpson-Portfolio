# Cave Hunt: cave system builder (Roblox)

Two Studio scripts for an asymmetric hide-and-seek game: one player is the monster and everyone else hides.

| File | What it does |
| --- | --- |
| `CaveBuilder.lua` | Carves the whole cave out of terrain and fills it with rooms, tunnels, hiding spots, lights, a spawn and monster spawns. |
| `PlaceAssets.lua` | Copies **your** models (shelves, container, big room, …) onto free spots around the cave. |

## 1. Build the cave

**Option A (quickest):** open `CaveBuilder.lua`, copy all of it, paste it into the **Command Bar** (View → Command Bar) and press Enter.

**Option B (easier to tweak later):**
1. In Explorer, add a **ModuleScript** to **ServerStorage** and name it `CaveBuilder`.
2. Paste the contents of `CaveBuilder.lua` into it.
3. Run this in the Command Bar:

```lua
require(game.ServerStorage.CaveBuilder:Clone())
```

(`:Clone()` makes Studio re-read the script each time, so edits to the CONFIG take effect.)

Studio freezes for a few seconds while the terrain is carved. That's normal. When it's done, the Output window prints a summary and the camera jumps to Base Camp.

The cave sits **underground, around Y = -200, below your Baseplate**, so the map you already have up top isn't touched and can become the lobby later. To look around in Studio, select `Workspace.CaveSystem.Spawn.CaveSpawn` and press **F**.

## 2. Add your own assets (optional)

1. In **ServerStorage**, create a Folder `CaveAssets` containing two Folders: `Hiding` and `Decor`.
2. Drag your models in. Things people hide in go in `Hiding`, decoration goes in `Decor`. Your big room can go in either.
3. Run `PlaceAssets.lua` the same way (paste it into the Command Bar, or use a ModuleScript plus `require`).

The biggest models are placed first, so your big room gets the big open spot in the Great Cavern (about 90 studs across). Hiding models get the `HidingSpot` tag and HidePoint/ExitPoint parts automatically. Run it again to reshuffle; it only replaces `CaveSystem.PlacedAssets`. To control how many copies of a model get placed, give it a number attribute named `Count`.

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

## Settings (top of `CaveBuilder.lua`)

| Setting | Default | Meaning |
| --- | --- | --- |
| `ORIGIN` | `(0, -200, 0)` | Where the cave is built (keep Y a multiple of 4) |
| `SEED` | `2024` | Change it to get a different random layout of tunnels and props |
| `OVERWRITE` | `false` | Must be `true` to rebuild once a cave exists. **This wipes your edits inside the cave.** |
| `TUNNEL_SIZE` | `1` | Tunnels are about 11–23 studs tall (nook passages about 9–12). Use `1.3` or more if the monster is big. |
| `DISABLE_OTHER_SPAWNS` | `true` | Disables your other SpawnLocations so playtests start in the cave |
| `DARK_LIGHTING` | `false` | Darker Lighting for a scarier mood (this affects the whole place) |
| `LIGHT_SHADOWS` | `false` | Shadows from the lanterns (prettier, but slower) |

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
