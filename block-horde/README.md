# Block Horde

A Roblox remake of the classic Flash zombie wave shooter formula: pick a room,
survive endless waves, and keep your kill multiplier high to unlock weapons.
Co-op for 1-6 players, with a lobby where you form parties.

## Install into Roblox Studio (one line)

1. Open a place in Studio (a new **Baseplate** is fine). Make sure you are **not** in Play mode.
2. **View > Command Bar**, paste this line, press **Enter**:

```lua
local H=game:GetService("HttpService") H.HttpEnabled=true local M=Instance.new("ModuleScript") M.Source=H:GetAsync("https://raw.githubusercontent.com/will51mps0n/Adam-Simpson-Portfolio/4b6682ba2ea50a5b34aaf03d6f9dc5bfdb79a33c/block-horde/studio/install.luau",true) require(M)()
```

3. The Output window prints `[Block Horde] installed build ...`. **File > Save**, then press **Play**.

Running the same line again installs the newest version (it replaces the
game's scripts and leaves everything else alone). The Baseplate, spawn pad,
haze and blur from the template are moved into `ServerStorage.BlockHordeRemoved`.

## How a game goes

- You spawn in the **lobby**. Walk onto one of the six glowing **party pads**.
- The first player on a pad is the **leader**: pick the room, difficulty
  (Beginner / Intermediate / Expert / Nightmare), party size (1-6) and
  friends-only, then press **START**. Others join by stepping onto the pad.
- In Studio the run plays right there in the arena. In the published game the
  party is teleported to its own private server, and back to a lobby after.
- Waves never end. Every kill adds 1 to your multiplier (more for several at
  once); it drains if you stop killing. Reaching x5, x10, x15... unlocks the
  Uzi, Shotgun, Barrels, Grenades, upgrades, Mines, Rockets, Railgun, Fake
  Walls and a Turret. When everyone is down you see the scores and go back.

## Controls

| Scheme | Move | Aim | Fire |
| --- | --- | --- | --- |
| Classic (default) | WASD / arrows, 8 directions | the way you last moved | Space |
| Mouse aim | WASD / arrows | mouse | click or Space |
| Touch | left-thumb stick | the stick direction | FIRE button |

1-9 and 0 pick weapons, Q / E cycle (or switch who you watch when you are down),
P pauses (solo only). Switch schemes with **SETTINGS** in the top right.

## Publishing (for teleports and high scores)

1. **File > Publish to Roblox**.
2. **Game Settings > Security**: turn on **Enable Studio Access to API Services** (high scores).
3. **Game Settings > Places**, open the place's settings, set **Max Players** to about 20
   (lobby size; each party's private server only holds its party).
4. Teleports only work in the published game (play it from the Roblox website or app),
   not in Studio.

## Tuning

Every number (camera, speeds, damage, fire rates, waves, enemies, colors,
sounds) is in `src/shared/Config.luau`. The unlock ladder is in
`src/shared/Unlocks.luau`. Rooms are made by `tools/make_rooms.py`.
To add sounds, paste Roblox audio ids into `Config.SOUNDS`.

## For developers

```sh
python3 tools/make_rooms.py           # regenerate src/shared/Rooms.luau
python3 tools/run_tests.py            # unit tests (needs the luau CLI)
python3 tools/build_installer.py      # rebuild studio/bundle.json + install.luau
rojo build -o BlockHorde.rbxlx        # optional: a place file
```

Type-check with [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp):
`rojo sourcemap -o sourcemap.json`, then
`luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions=@roblox=globalTypes.None.d.luau src`.

Layout: `src/shared` -> ReplicatedStorage.Shared, `src/server` ->
ServerScriptService.Server, `src/client` -> StarterPlayerScripts.Client,
`src/character` -> StarterCharacterScripts.
