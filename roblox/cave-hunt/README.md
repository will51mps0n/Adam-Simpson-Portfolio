# Cave Hunt (Roblox)

Studio scripts for an asymmetric hide-and-seek game: one player is the monster and everyone else hides in a dark cave.

| File | What it does |
| --- | --- |
| `CaveBuilder.lua` | Carves the cave out of terrain (rooms, tunnels, a Backrooms maze) and adds hiding spots, a spawn, monster spawns, and spots saved for your models. |
| `PlaceAssets.lua` | Takes **your** models from Workspace (closets, hiding spots, minecarts, big room, …) and puts copies around the cave. |
| `GameScripts.lua` | Installs the gameplay: head flashlights (**F**), hiding in any hiding spot (**E**), and the dark cave mood. |

## Quick start: one command does everything

Paste this into the **Command Bar**, press Return, then **File → Save**:

```lua
local H=game:GetService("HttpService") H.HttpEnabled=true local B="https://raw.githubusercontent.com/will51mps0n/Adam-Simpson-Portfolio/26203a0127e53bd0879a5decb247652e0f0abeb4/roblox/cave-hunt/" for _,f in ipairs({"CaveBuilder","PlaceAssets","GameScripts"}) do local M=Instance.new("ModuleScript") M.Source=H:GetAsync(B..f..".lua",true) require(M)() end
```

It downloads the three scripts from GitHub and runs them in order. It also turns on **Allow HTTP Requests** for the place, which the download needs. Studio freezes for 10–30 seconds while the terrain is carved.

Then press **Play**. You spawn in Base Camp. **F** switches your flashlight on and off. Walk up to a hiding spot and press **E** to hide, then **E** again to come out.

**If nothing seems to happen:** open the Output window (**Script** tab → **Output**) and run it again. Every step prints a line starting with `[CaveBuilder]`, `[PlaceAssets]` or `[GameScripts]`. If something fails, you get a message that starts with "Something went wrong". Copy that whole message and send it to Claude.

## What's in the cave

The cave is a big block of rock (1120 × 200 × 1120 studs) **in the middle of your Baseplate**. Anything that was standing where the rock goes is lifted onto the top of it, so nothing gets buried. Your monster ends up up there too, so drag it wherever you want it.

North is -Z. Base Camp is in the south, and the monster lairs are spread across the far side.

```
        LairNorthWest ------ LairNorth ------ LairNorthEast -------.
              |                  |                  |               \
 LairWest -- ShackTown ------ TheAbyss ------ SunkenLake -- LairEast -- BACKROOMS
    |             \              |              /    \_________________/
    |              `------ GreatCavern --------'
    |                     /      |      \
 OldMine ----------------'       |       `------------- CrystalGrotto
       \                         |                        /
        `-------------------- BaseCamp ------------------'
```

- **BaseCamp**: player spawn, campfire, tents, a few lanterns. It's the only well-lit place.
- **GreatCavern**: a huge hall with a roughly 90-stud open spot for your big room, 2 shacks, rock pillars, barricades.
- **OldMine**: timber supports, rails, mine carts you can hide in.
- **CrystalGrotto**: dimly glowing crystals.
- **ShackTown**: 5 shacks (each with a wardrobe inside), 2 outhouses, barricades.
- **SunkenLake**: a pool with a dock, an island with a barrel, a fisherman's shack.
- **TheAbyss**: a very tall cavern with pillars and 2 climbable scaffolds (one has a barrel on top).
- **Backrooms**: the cave breaks into a yellow-wallpaper maze with damp carpet and buzzing fluorescent panels (some dead, some flickering). Its dead ends hold hiding spots and your models.
- **5 lairs**: red-lit rooms with bones, one `MonsterSpawn` each, 410–670 studs from Base Camp.
- **About 17 nooks**: dead-end alcoves off the tunnels. Half have one of my hiding spots, and half are saved for your models.

**The mood:**
- **Lighting:** almost no lights, and the ones there are, are dim. The rock is darker and looks wetter.
- **Dust:** floating dust only shows up where light hits it, so you see it in your flashlight beam.
- **Inside the cave only:** `GameScripts` makes it near-black, foggy and washed out while you're in the cave, and puts it back to normal when you leave. In Studio's edit mode the cave stays visible so you can build.

## Your models

The first time `PlaceAssets` runs, it picks up the models in your Workspace (including ones in folders) and moves them into **ServerStorage → CaveAssets**:

- **Hiding**: names like Closet, Hiding Spot, Locker, Minecart, Crate, Shelf or Container, or anything in a folder named like that. Models just called "Model" go here if they're at least 5 studs tall and no more than 30 across. Copies get the `HidingSpot` tag, so **E** works on them.
- **Decor**: names like Light, Crystal, Fire or Lamp, and everything else, including your big room.
- **Left alone**: the Baseplate, SpawnLocations, flat parts, and anything with a Humanoid or "monster" in its name.

Every model goes in at least once, biggest first. Then extra copies go in while there's room: up to 6 of each hiding model, 2 of each decoration, and 1 of anything wider than 30 studs. Models with the same name count as one design. **Each model stands at the same height it stood at on your Baseplate**, so meshes that stick out of their part don't sink into the floor.

- **Wrong folder?** Drag it to the other folder in CaveAssets and run the command again.
- **New models later:** drag them into CaveAssets → Hiding or Decor and run it again.
- **Per-model control (attributes):** `Count` (number) sets how many copies; `CaveRole` (`Hiding`, `Decor` or `Skip`) overrides the sorting.

## Running one step at a time

Use the same command, with only the one script you want in `{...}`. For example, `{"PlaceAssets"}` reshuffles your models without rebuilding the cave.

To pass settings, run a single script and put them in the last brackets: replace the end of the command with `require(M)({ SEED = 7, OVERWRITE = true }) end`.

**Rebuilding:** once a cave exists, `CaveBuilder` won't build over it unless you pass `OVERWRITE = true`. **That wipes the cave and anything you changed inside it**, so keep hand edits outside `Workspace.CaveSystem`, or redo them afterwards. A cave made by an earlier test version of the script is replaced automatically.

## Settings

**CaveBuilder**

| Setting | Default | Meaning |
| --- | --- | --- |
| `ORIGIN` | `Vector3.new(0, 64, 0)` | Center of the cave (keep Y a multiple of 4) |
| `SEED` | `2024` | A different number gives a different layout of tunnels, props and maze |
| `OVERWRITE` | `false` | Must be `true` to rebuild once a cave exists. **This wipes your edits inside the cave.** |
| `TUNNEL_SIZE` | `1` | Tunnels are about 11–23 studs tall, and the Backrooms ceiling is 12. Use `1.3` or more if the monster is big. |
| `DARK_CAVE` | `true` | Only a few dim lights. `false` puts the lanterns back in the tunnels and rooms. |
| `DISABLE_OTHER_SPAWNS` | `true` | Disables your other SpawnLocations so playtests start in the cave |
| `LIGHT_SHADOWS` | `false` | Shadows from the cave's lights (prettier, but slower) |
| `MOVE_CAMERA` | `true` | Moves the Studio camera to Base Camp when it's done |

**PlaceAssets**

| Setting | Default | Meaning |
| --- | --- | --- |
| `SEED` | `false` | `false` = a new arrangement every run. A number gives the same arrangement each time. |
| `HIDING_COPIES` | `6` | Most copies of each hiding model |
| `DECOR_COPIES` | `2` | Most copies of each decoration |
| `BIG` | `30` | Models wider than this many studs are placed once (unless they have a `Count` attribute) |
| `COLLECT_FROM_WORKSPACE` | `"auto"` | `"auto"` = pick up models from Workspace only the first time (before CaveAssets exists); `true` = every run; `false` = never |

## For the gameplay scripts

These are CollectionService tags, so they work wherever the object is in the tree.

| Tag | On | Notes |
| --- | --- | --- |
| `HidingSpot` | Model | Has `HidePoint` (where the hider goes) and `ExitPoint` (where they come out). Attributes: `HideType`, `Occupied`. |
| `MonsterSpawn` | Part | Attributes: `Room`, `DistanceFromPlayerSpawn` |
| `PlayerSpawn` | SpawnLocation | Base Camp |
| `PropSpot` | Part | Attributes: `MaxFootprint`, `MaxHeight`, `Room` |
| `CaveRoom` | Part | Invisible box around each room. Attribute: `RoomKind` (`Spawn`, `Big`, `Room`, `Maze`, `Lair`, `Nook`) |
| `Flicker` | Light | Flickers every few seconds (handled by `CaveHunt_Client`) |

- **Knocking hiders out:** `ServerStorage.CaveHunt_KnockOut:Invoke(spotModel)` throws whoever is hiding in that spot out and returns that player. The monster's attack will use this.
- **Hidden players:** a hidden player has the attribute `Hidden = true`.

## Remove the cave completely

```lua
workspace.CaveSystem:Destroy() workspace.Terrain:FillBlock(CFrame.new(0, 100, 0), Vector3.new(1128, 208, 1128), Enum.Material.Air)
```

This assumes the default `ORIGIN`. Re-enable your old SpawnLocation by hand if it was disabled.
