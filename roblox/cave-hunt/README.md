# Cave Hunt (Roblox)

Studio scripts for an asymmetric hide-and-seek game: one player is the monster and everyone else hides in a dark cave.

| File | What it does |
| --- | --- |
| `CaveBuilder.lua` | Carves the cave out of terrain (4 rooms joined by tunnels) and adds a spawn, monster spawns, banks of lockers along the walls, and lots of spots saved for your models. |
| `PlaceAssets.lua` | Takes **your** models (closets, hiding spots, minecarts, lights, big room, …) and fills the cave with copies. |
| `GameScripts.lua` | Installs the gameplay: rounds with spectating and admin commands, same-size hiders, flashlights, hiding, phones, the monster and its abilities, coins and the troll shop, and the dark cave mood. |

## Quick start: one command does everything

Paste this into the **Command Bar**, press Return, then **File → Save**:

```lua
local H=game:GetService("HttpService") H.HttpEnabled=true local B="https://raw.githubusercontent.com/will51mps0n/Adam-Simpson-Portfolio/30f45fb094d69deba6f2283acba73566d0e85c1b/roblox/cave-hunt/" for _,f in ipairs({"CaveBuilder","PlaceAssets","GameScripts"}) do local M=Instance.new("ModuleScript") M.Source=H:GetAsync(B..f..".lua",true) require(M)(f=="CaveBuilder" and {OVERWRITE=true} or nil) end
```

It downloads the three scripts from GitHub and runs them in order. `OVERWRITE=true` rebuilds the cave if one is already there. It also turns on **Allow HTTP Requests** for the place, which the download needs. Studio freezes for 10–30 seconds while the terrain is carved.

**Rebuilding wipes everything inside `Workspace.CaveSystem`.** Things you put anywhere else are kept: Workspace itself, folders, ServerStorage. If the new rock would bury something of yours, it's moved onto the top of the rock, and the Output tells you what moved.

**If nothing seems to happen:** open the Output window (**Script** tab → **Output**) and run it again. Every step prints a line starting with `[CaveBuilder]`, `[PlaceAssets]` or `[GameScripts]`. If something fails, you get a message that starts with "Something went wrong". Copy that whole message and send it to Claude.

## Playing

Press **Play**. You spawn in Base Camp as a **hider**. The bar at the top of the screen shows what the round is doing.

**Rounds**
1. **Picking the monster:** once 2 or more players are in the game, a 15-second break counts down. Then one player is picked at random as the monster. Everyone else starts at Base Camp.
2. **Hiding (20 seconds):** the monster is frozen at its lair with a black screen while everyone hides.
3. **The hunt (5 minutes):** the monster wins if it catches every hider. The hiders win if anyone is still alive when time runs out.
4. **After the round:** the result shows for 8 seconds, then everyone's back at Base Camp as a hider and the next break starts.
- **Rewards:** surviving a round is worth 25 coins, and so is catching everyone as the monster.
- **On your own** (fewer than 2 players) it's free play: no rounds start by themselves, but an admin can start one.

**Spectating:** when you're caught you don't respawn. You watch the others until the round ends.
- **Switching who you watch:** the **<** and **>** buttons at the bottom of the screen, or **Q** and **E**.
- **Joining mid-round:** players who join during a round spectate until the next one.

**Admin commands**
- **Who's an admin:** in Studio, everyone. In a published game: the game's owner (or rank 255 of the owning group), plus anyone you add to `ADMINS` at the top of `ServerScriptService.CaveHunt_Rounds`, e.g. `local ADMINS = { 12345678, "MyFriend" }`.
- **Admin panel:** admins get an **Admin** button under the Shop button. It has Restart round, Make me the monster, Make me a hider, Spectate, Stop rounds, and a list of players to make the monster.
- **Chat commands:** the same things work typed in chat. Names can be shortened (`;monster bo` finds Bob):

| Command | What it does |
| --- | --- |
| `;restart` or `;start` | A new round now, with a random monster. Also restarts rounds after `;end`. |
| `;restart Bob` | A new round now, with Bob as the monster. |
| `;monster` | A new round now, with you as the monster. |
| `;monster Bob` | A new round now, with Bob as the monster. |
| `;hider` | Back to Base Camp as a hider. If you're the monster, a new round starts with someone else as the monster. |
| `;hider Bob` | Brings Bob back as a hider (also brings back someone who was caught). |
| `;spectate` / `;spectate Bob` | Switch to spectating. `;hider` brings you back. |
| `;end` | Stop the round. Everyone goes back to Base Camp, and rounds don't start by themselves until `;start`. |

**Testing with more than one player in Studio:** go to the **Test** tab, set the player count next to **Clients and Servers** to 2, and press **Start**. You get a window for each player.

**Round settings** (top of `ServerScriptService.CaveHunt_Rounds`):

| Setting | Default | Meaning |
| --- | --- | --- |
| `HIDE_TIME` | `20` | Seconds the hiders get before the monster is let loose |
| `ROUND_TIME` | `300` | Seconds the monster has to catch everyone |
| `INTERMISSION` | `15` | Break between rounds |
| `MIN_PLAYERS` | `2` | Rounds start by themselves once this many players are in |
| `AUTO_ROUNDS` | `true` | `false` = rounds only start when an admin starts them |

**Hiders**
- **Your character:** the plain blocky Roblox body at the standard size, with your own head, face, hair, hats, skin colors and clothes.
- **Flashlight (F):** switches your head flashlight on and off. If StarterPack has a Tool with "flash" in its name (like your Advanced Flashlight), that tool is used instead and the head flashlight stays off.
- **Hiding (E):** walk up to any hiding spot and press **E** to hide inside it. You go invisible and your light switches off. Press **E** again to come out.
- **Phone (hotbar, 8s cooldown):** pick another hider from the list. Their phone rings for 4 seconds: everyone nearby hears it, and "RING RING" flashes above them with a blue glow, even if they're inside a closet. They get a message saying who's calling.

**The monster**
- **Spawn and speed:** it spawns at the far end of the Great Cavern, the Old Mine or the Crystal Grotto. Speed is 26, against the hiders' 16.
- **Killing:** touching a hider who isn't hiding kills them.
- **Searching:** pressing **E** ("Search") on a hiding spot throws whoever is inside out.
- **Vision:** no flashlight. Instead it has green night vision that shows the whole cave. **N** switches it off and on (off is a dim red view).
- **Hotbar abilities:**
  1. **Leap** (6s): a big lunge forward and up.
  2. **Sense** (15s): for 4 seconds, every hider is outlined through walls and occupied hiding spots glow.
  3. **Scent** (20s): for 8 seconds, a glowing trail shows where each hider walked in the last 30 seconds.
  4. **Roar** (25s): hiders within 140 studs get their screen shaken and their lights knocked out for 5 seconds.
- **Look: your monster model.** `GameScripts` looks in Workspace for it: a model with "monster" in its name, or else a character model (one with a `Humanoid`, like your Smiler). It moves the model to **ServerStorage** and says so in the Output. To pick a different one, put it in ServerStorage, name it `Monster`, and run the command again.
  - **A rigged character** (`Humanoid` + `HumanoidRootPart`): whoever is the monster plays as it.
    - Its own scripts (AI, chasing) are switched off.
    - **Animations:** animations made by another creator won't load in your game (that's the "not authorized" errors). So if it's built like a normal Roblox character, it gets Roblox's standard walk and run animations. To keep its own, give the model a `KeepAnimations` attribute set to true.
  - **Any other model:** the monster's character wears it like a costume: welded on, with the player's own body hidden.
  - **Size:** taller than 11 studs gets shrunk to fit the tunnels (`MONSTER_MAX_HEIGHT` at the top of `CaveHunt_Players`).
  - **No model found:** the monster is your own character in black with red eyes.

**How hotbar items work:** pick one (its number key, or click its slot) and it's used straight away. While it recharges, its slot counts down the seconds.

## Coins and the troll shop

**Coins** show on the leaderboard (top right, next to your name). Everyone starts with **40**.
- **Hiders:** +1 coin every 5 seconds while you're alive in the cave.
- **Coin pickups:** about 10 glowing gold coins lie in front of random hiding spots. Walk into one for +5. New ones keep appearing.
- **The monster:** +15 for catching a hider, +5 for pulling one out of a hiding spot. Coins stay with you when you switch back to hider.

**Everything in the shop is free for now** (for testing). The prices below kick in when you set `FREE_SHOP = false` at the top of `ServerScriptService.CaveHunt_Shop`. Running the command again sets it back to free.

**The shop:** click the **Shop** button in the top-right corner, or press **B**. Bought items go in your hotbar. Each use spends one, and buying the same thing again stacks it ("Glowstick x3"). Items stay in your hotbar after you die. The monster can only buy the items marked "anyone".

| Item | Price | Who | What it does |
| --- | --- | --- | --- |
| **Snitch** | 30 | hiders | Pick a hider. The monster sees them highlighted through walls for 5 seconds (or the spot they're hiding in). They get warned. Works while you're hiding. |
| **Glowstick** | 10 | anyone | Throws a green glowstick where you're looking. It lights up the area for 25 seconds. |
| **Fake Noise** | 15 | anyone | A phone rings where you're aiming for 5 seconds, to send the monster the wrong way. Works while you're hiding. |
| **Spot Lock** | 20 | hiders | Jams the nearest hiding spot for 10 seconds ("JAMMED" shows above it). Nobody can get in, but the monster can still search it. |
| **Swap** | 35 | hiders | Pick a hider who isn't hiding, and you swap places. |
| **Banana Peel** | 15 | anyone | Drops a peel at your feet. The next person to step on it (not you) sits down and can't move for 2 seconds. |
| **Air Horn** | 10 | anyone | HONK. Shakes the screen of everyone within 60 studs, and the monster hears it from far away. |
| **Fake Hider** | 20 | hiders | The nearest empty hiding spot shows up as taken in the monster's Sense for 60 seconds. If the monster searches it, they're told it was a decoy. |

Except for Snitch and Fake Noise, items can't be used while you're hiding.

**Changing prices** (used once `FREE_SHOP` is `false`): the items are Tools in **ServerStorage → CaveHunt_Tools**. Select one and change its `Price` attribute in the Properties window. `Who` is `Hider` (hiders only) or `Any`. Running the command again resets them.

**Changing the coin amounts:** see the top of `ServerScriptService.CaveHunt_Shop`: `START_COINS`, `INCOME`, `INCOME_EVERY`, `REWARDS`, `PICKUPS` and `PICKUP_VALUE`.

**Sounds:** everything uses sounds built into Roblox. To use your own, change these to any sound ID, e.g. `"rbxassetid://1234567"`:
- `ROAR_SOUND` at the top of `ServerScriptService.CaveHunt_Players`.
- `RINGTONE`, `AIRHORN_SOUND` and `SLIP_SOUND` at the top of `ServerScriptService.CaveHunt_Shop`.

The air horn is a built-in beep played low and loud, so it's the one most worth swapping for a real horn sound.

## What's in the cave

The cave is a block of rock (720 × 200 × 720 studs) in the middle of your Baseplate. North is -Z.

```
      OldMine ------------- GreatCavern ------------- CrystalGrotto
           \                     |                      /
            `---------------- BaseCamp ----------------'
```

- **BaseCamp**: player spawn, campfire, tents, a few lanterns. It's the only well-lit place.
- **GreatCavern**: the central hall. It has a roughly 88-stud open spot for your big room, 2 shacks, rock pillars, barricades, and a climbable scaffold with a barrel on top.
- **OldMine**: timber supports, rails, mine carts you can hide in.
- **CrystalGrotto**: dimly glowing crystals.
- **Lockers:** about 25, in banks of 2–3. They stand with their backs against the rock and their doors facing the middle of the room: one bank in Base Camp, four in the Great Cavern, three in the Old Mine and two in the Crystal Grotto.
- **Tunnels and nooks:** dead-end alcoves off the tunnels.
- **Monster spawns:** at the far ends of the Great Cavern, Old Mine and Crystal Grotto, marked by a dim red glow.

**Room for your props:** there are about 65 spots in the rooms, along the tunnels and in the nooks.
- **Tunnel spots** are sized to the real width of the tunnel at that point, measured up to head height, so nothing pokes into a wall that curves in.
- **Small props tucked against a wall:** if one lands where the floor starts sloping up to the wall, it's slid back toward open floor.

**The mood:**
- **Lighting:** very few lights, all dim. The rock is darker and looks wetter.
- **Dust:** floating dust only shows up in your flashlight beam.
- **Inside the cave only:** no fog, and no sun, sky or ambient light. Hiders only see what a light shines on: flashlights, the lanterns at Base Camp, and glowing crystals. The monster sees with night vision. Everything goes back to normal when you leave the cave. In Studio's edit mode the cave stays visible so you can build.

## Your models

The first time `PlaceAssets` runs, it picks up the models in your Workspace (including ones in folders) and moves them into **ServerStorage → CaveAssets**:

- **Hiding**: names like Closet, Hiding Spot, Locker, Minecart, Crate, Shelf or Container, or anything in a folder named like that. Models just called "Model" go here if they're at least 5 studs tall and no more than 30 across. Copies get the `HidingSpot` tag, so **E** works on them.
- **Decor**: names like Light, Crystal, Fire or Lamp, and everything else, including your big room.
- **Left alone**: the Baseplate, SpawnLocations, flat parts, and anything with a Humanoid or "monster" in its name. `GameScripts` then picks up your monster from these.

After that first run it only uses CaveAssets. To add more props, drag them into **CaveAssets → Hiding** or **Decor**.

**How they're placed:**
- **Every model goes in at least once, biggest first.** Then extra copies go in while there's room: up to 6 of each hiding model, 4 of each decoration, and 1 of anything wider than 30 studs. Small props can share a spot.
- **Height:** each model's *visible* bottom rests on the highest point of the floor under it, so nothing sinks into the floor. Invisible helper parts (hitboxes and the like) are ignored when working this out.
- **Lights:** lights inside your models are dimmed to 35% to keep the cave dark (`ASSET_LIGHT_SCALE`).
- **Output report:** lists what went in, and warns about anything that didn't fit.

**Making changes:**
- **Wrong folder?** Drag it to the other folder in CaveAssets and run the command again.
- **Per-model control (attributes):** `Count` (number) sets how many copies; `CaveRole` (`Hiding`, `Decor` or `Skip`) overrides the sorting.

## Running one step at a time

Use the same command, with only the scripts you want in `{...}`.
- **Reshuffle your props:** use `{"PlaceAssets"}`. It doesn't rebuild the cave.
- **Pass settings:** put them in the table near the end. For example, change `{OVERWRITE=true}` to `{OVERWRITE=true, SEED=7}` for a different layout.

## Settings

**CaveBuilder**

| Setting | Default | Meaning |
| --- | --- | --- |
| `ORIGIN` | `Vector3.new(0, 64, 0)` | Center of the cave (keep Y a multiple of 4) |
| `SEED` | `2024` | A different number gives a different layout of tunnels and props |
| `OVERWRITE` | `false` | Must be `true` to rebuild once a cave exists (the quick-start command sets it). **This wipes everything inside `Workspace.CaveSystem`.** |
| `TUNNEL_SIZE` | `1` | Tunnels are about 11–23 studs tall. Use `1.3` or more if the monster is huge. The built-in monster is about 8 studs tall. |
| `DARK_CAVE` | `true` | Only a few dim lights. `false` puts the lanterns back in the tunnels and rooms. |
| `DISABLE_OTHER_SPAWNS` | `true` | Disables your other SpawnLocations so playtests start in the cave |
| `LIGHT_SHADOWS` | `false` | Shadows from the cave's lights (prettier, but slower) |
| `MOVE_CAMERA` | `true` | Moves the Studio camera to Base Camp when it's done |

**PlaceAssets**

| Setting | Default | Meaning |
| --- | --- | --- |
| `SEED` | `false` | `false` = a new arrangement every run. A number gives the same arrangement each time. |
| `HIDING_COPIES` | `6` | Most copies of each hiding model |
| `DECOR_COPIES` | `4` | Most copies of each decoration |
| `BIG` | `30` | Models wider than this many studs are placed once (unless they have a `Count` attribute) |
| `ASSET_LIGHT_SCALE` | `0.35` | How bright the lights inside your models are in the cave (1 = as you made them) |
| `COLLECT_FROM_WORKSPACE` | `"auto"` | `"auto"` = pick up models from Workspace only the first time (before CaveAssets exists); `true` = every run; `false` = never |

## For gameplay scripts

These are CollectionService tags, so they work wherever the object is in the tree.

| Tag | On | Notes |
| --- | --- | --- |
| `HidingSpot` | Model | Has `HidePoint` (where the hider goes) and `ExitPoint` (where they come out). Attributes: `HideType`, `Occupied`, `OccupantId` (the UserId inside), `LockedUntil` (Spot Lock, server time), `FakeOccupied` (Fake Hider). |
| `MonsterSpawn` | Part | Attributes: `Room`, `DistanceFromPlayerSpawn` |
| `PlayerSpawn` | SpawnLocation | Base Camp |
| `PropSpot` | Part | Attributes: `MaxFootprint`, `MaxHeight`, `Room` |
| `CaveRoom` | Part | Invisible box around each room. Attribute: `RoomKind` |
| `Flicker` | Light | Flickers every few seconds (handled by `CaveHunt_Client`) |
| `CaveCoin` | Part | A coin pickup (spawned by `CaveHunt_Shop`) |

| Player attribute | Meaning |
| --- | --- |
| `Role` | `"Hider"`, `"Monster"` or `"Spectator"` |
| `IsAdmin` | `true` for admins |
| `Hidden` | `true` while hiding |

- **Knocking hiders out:** `ServerStorage.CaveHunt_KnockOut:Invoke(spotModel)` throws whoever is hiding in that spot out and returns that player.
- **Switching roles:** `ServerStorage.CaveHunt_Roles:Invoke(player, "Monster")` (or `"Hider"`, `"Spectator"`).
- **The round:** `ReplicatedStorage.CaveHunt_Round` has the attributes `State` (`Waiting`, `Intermission`, `Starting`, `Hiding`, `Hunting`, `Over`), `EndsAt` (server time), `Monster`, `HidersLeft` and `Message`.
- **Spawning:** `CaveHunt_Rounds` turns off `Players.CharacterAutoLoads` while the game runs and spawns players itself, so caught hiders stay out until the round ends.
- **Hotbar items:** the templates live in `ServerStorage.CaveHunt_Tools`. Shop items have the attributes `Item`, `Price`, `Who` and `Order`.
- **Giving coins from your own scripts:** `ServerStorage.CaveHunt_Reward:Fire(player, "Catch")` (or `"Find"`) pays out that reward. Coins are `player.leaderstats.Coins`.
- **Adding back other room types:** add a room with `kind = "Lair"` (monster lair) or `kind = "Maze"` (the Backrooms) to `ROOMS` in `CaveBuilder.lua`.

## Remove the cave completely

```lua
workspace.CaveSystem:Destroy() workspace.Terrain:FillBlock(CFrame.new(0, 100, 0), Vector3.new(728, 208, 728), Enum.Material.Air)
```

This assumes the default `ORIGIN`. Re-enable your old SpawnLocation by hand if it was disabled.
