# Cave Hunt (Roblox)

Studio scripts for an asymmetric hide-and-seek game: one player is the monster and everyone else hides in a dark cave.

| File | What it does |
| --- | --- |
| `CaveBuilder.lua` | Carves the cave out of terrain (rooms, tunnels, a Backrooms maze) and adds hiding spots, a spawn, monster spawns, and spots saved for your models. |
| `PlaceAssets.lua` | Takes **your** models from Workspace (closets, hiding spots, minecarts, big room, …) and puts copies around the cave. |
| `GameScripts.lua` | Installs the gameplay: same-size hiders, flashlights (**F**), hiding (**E**), the monster, and the dark cave mood. |

## Quick start: one command does everything

Paste this into the **Command Bar**, press Return, then **File → Save**:

```lua
local H=game:GetService("HttpService") H.HttpEnabled=true local B="https://raw.githubusercontent.com/will51mps0n/Adam-Simpson-Portfolio/9c7b9c0a43ab4b7e1c0903f768c02e300ae71bdd/roblox/cave-hunt/" for _,f in ipairs({"CaveBuilder","PlaceAssets","GameScripts"}) do local M=Instance.new("ModuleScript") M.Source=H:GetAsync(B..f..".lua",true) require(M)(f=="CaveBuilder" and {OVERWRITE=true} or nil) end
```

It downloads the three scripts from GitHub and runs them in order. `OVERWRITE=true` rebuilds the cave if one is already there. It also turns on **Allow HTTP Requests** for the place, which the download needs. Studio freezes for 10–30 seconds while the terrain is carved.

**Rebuilding wipes everything inside `Workspace.CaveSystem`.** Things you put anywhere else are kept: Workspace itself, folders, ServerStorage. If the new rock would bury something of yours, it's moved onto the top of the rock, and the Output tells you what moved.

**If nothing seems to happen:** open the Output window (**Script** tab → **Output**) and run it again. Every step prints a line starting with `[CaveBuilder]`, `[PlaceAssets]` or `[GameScripts]`. If something fails, you get a message that starts with "Something went wrong". Copy that whole message and send it to Claude.

## Playing

Press **Play**. You spawn in Base Camp as a **hider**:
- **Your character:** the plain blocky Roblox body at the standard size, with your own head, face, hair, hats, skin colors and clothes.
- **Flashlight (F):** switches your head flashlight on and off. If StarterPack has a Tool with "flash" in its name (like your Advanced Flashlight), that tool is used instead and the head flashlight stays off.
- **Hiding (E):** walk up to any hiding spot and press **E** to hide inside it. You go invisible and your light switches off. Press **E** again to come out.

The **Play as Monster** button in the top-right corner turns you into the monster. Press it again ("Play as Hider") to switch back. It's there for testing until there's a round system that picks the monster at random.
- **Spawn:** you start in one of the 3 lairs, far from Base Camp.
- **Speed:** 26, against the hiders' 16.
- **Killing:** touching a hider who isn't hiding kills them.
- **Searching:** pressing **E** ("Search") on a hiding spot throws whoever is inside out, right next to you.
- **Vision:** you have no flashlight, but you see the cave with a dim red night vision.
- **Look:** by default the monster is your own character turned into a tall black creature with red eyes. To use your own monster model instead, put it in **ServerStorage** and name it `Monster`. It needs a `Humanoid` and a `HumanoidRootPart`. Its own server scripts (like an AI movement script) are switched off so they don't fight your controls; its LocalScripts, like Animate, still run.

## What's in the cave

The cave is a block of rock (800 × 200 × 800 studs) in the middle of your Baseplate.

```
             LairWest              LairNorth             LairEast
                |    \             /   |    \             /   |
                |   ShackTown ----'    |    `--- BACKROOMS    |
                |        \             |            /         |
             OldMine ---- GreatCavern -------------'    CrystalGrotto
                  \       /    |    \                 /
                   `----'      |     `--------------'
                            BaseCamp
```

- **BaseCamp**: player spawn, campfire, tents, a few lanterns. It's the only well-lit place.
- **GreatCavern**: the central hall. It has a roughly 88-stud open spot for your big room, 2 shacks, rock pillars, barricades, and a climbable scaffold with a barrel on top.
- **OldMine**: timber supports, rails, mine carts you can hide in.
- **CrystalGrotto**: dimly glowing crystals.
- **ShackTown**: 5 shacks (each with a wardrobe inside) and 2 outhouses.
- **Backrooms**: the cave breaks into a yellow-wallpaper maze with damp carpet and fluorescent panels. About half the panels are dead and the rest flicker. Its dead ends hold hiding spots and your models.
- **3 lairs**: red-lit rooms with bones, one `MonsterSpawn` each, about 390–490 studs from Base Camp.
- **About 14 nooks**: dead-end alcoves off the tunnels. Half have one of my hiding spots, and half are saved for your models.

**The mood:**
- **Lighting:** very few lights, all dim. The rock is darker and looks wetter.
- **Dust:** floating dust only shows up in your flashlight beam.
- **Inside the cave only:** `GameScripts` makes it near-black, foggy and washed out while you're in the cave, and puts it back to normal when you leave. In Studio's edit mode the cave stays visible so you can build.

## Your models

The first time `PlaceAssets` runs, it picks up the models in your Workspace (including ones in folders) and moves them into **ServerStorage → CaveAssets**:

- **Hiding**: names like Closet, Hiding Spot, Locker, Minecart, Crate, Shelf or Container, or anything in a folder named like that. Models just called "Model" go here if they're at least 5 studs tall and no more than 30 across. Copies get the `HidingSpot` tag, so **E** works on them.
- **Decor**: names like Light, Crystal, Fire or Lamp, and everything else, including your big room.
- **Left alone**: the Baseplate, SpawnLocations, flat parts, and anything with a Humanoid or "monster" in its name.

After that first run it only uses CaveAssets, so new things you put in Workspace (like Smiler or your puddles) stay where you put them.

**How they're placed:**
- **Every model goes in at least once, biggest first.** Then extra copies go in while there's room: up to 6 of each hiding model, 2 of each decoration, and 1 of anything wider than 30 studs. Models with the same name count as one design.
- **Height:** each model stands at the same height it stood at on your Baseplate, so meshes that stick out of their part don't sink into the floor.
- **Lights:** lights inside your models are dimmed to 35% to keep the cave dark (`ASSET_LIGHT_SCALE`).
- **Output report:** lists what went in, and warns about anything that didn't fit.

**Making changes:**
- **Wrong folder?** Drag it to the other folder in CaveAssets and run the command again.
- **New models later:** drag them into CaveAssets → Hiding or Decor and run it again.
- **Per-model control (attributes):** `Count` (number) sets how many copies; `CaveRole` (`Hiding`, `Decor` or `Skip`) overrides the sorting.

## Running one step at a time

Use the same command, with only the scripts you want in `{...}`.
- **Reshuffle your models:** use `{"PlaceAssets"}`. It doesn't rebuild the cave.
- **Pass settings:** put them in the table near the end. For example, change `{OVERWRITE=true}` to `{OVERWRITE=true, SEED=7}` for a different layout.

## Settings

**CaveBuilder**

| Setting | Default | Meaning |
| --- | --- | --- |
| `ORIGIN` | `Vector3.new(0, 64, 0)` | Center of the cave (keep Y a multiple of 4) |
| `SEED` | `2024` | A different number gives a different layout of tunnels, props and maze |
| `OVERWRITE` | `false` | Must be `true` to rebuild once a cave exists (the quick-start command sets it). **This wipes everything inside `Workspace.CaveSystem`.** |
| `TUNNEL_SIZE` | `1` | Tunnels are about 11–23 studs tall, and the Backrooms ceiling is 12. Use `1.3` or more if the monster is huge. The built-in monster is about 8 studs tall. |
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
| `ASSET_LIGHT_SCALE` | `0.35` | How bright the lights inside your models are in the cave (1 = as you made them) |
| `COLLECT_FROM_WORKSPACE` | `"auto"` | `"auto"` = pick up models from Workspace only the first time (before CaveAssets exists); `true` = every run; `false` = never |

## For gameplay scripts

These are CollectionService tags, so they work wherever the object is in the tree.

| Tag | On | Notes |
| --- | --- | --- |
| `HidingSpot` | Model | Has `HidePoint` (where the hider goes) and `ExitPoint` (where they come out). Attributes: `HideType`, `Occupied`. |
| `MonsterSpawn` | Part | Attributes: `Room`, `DistanceFromPlayerSpawn` |
| `PlayerSpawn` | SpawnLocation | Base Camp |
| `PropSpot` | Part | Attributes: `MaxFootprint`, `MaxHeight`, `Room` |
| `CaveRoom` | Part | Invisible box around each room. Attribute: `RoomKind` (`Spawn`, `Big`, `Room`, `Maze`, `Lair`, `Nook`) |
| `Flicker` | Light | Flickers every few seconds (handled by `CaveHunt_Client`) |

| Player attribute | Meaning |
| --- | --- |
| `Role` | `"Hider"` or `"Monster"` |
| `Hidden` | `true` while hiding |

`ServerStorage.CaveHunt_KnockOut:Invoke(spotModel)` throws whoever is hiding in that spot out and returns that player.

## Remove the cave completely

```lua
workspace.CaveSystem:Destroy() workspace.Terrain:FillBlock(CFrame.new(0, 100, 0), Vector3.new(808, 208, 808), Enum.Material.Air)
```

This assumes the default `ORIGIN`. Re-enable your old SpawnLocation by hand if it was disabled.
