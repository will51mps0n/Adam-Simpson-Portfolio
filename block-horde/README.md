# Block Horde

A Roblox remake of the classic Flash zombie wave shooter formula (pick a room,
survive endless waves, keep your kill multiplier high to unlock weapons).
The whole game is code, built into a place file with [Rojo](https://rojo.space).

## Play it

1. Download `BlockHorde.rbxlx` from this folder.
2. Double-click it (or File > Open in Roblox Studio).
3. Press **Play** (F5). For co-op: **Test** tab > **Clients and Servers** > 2 players > **Start**.

## Controls

| Scheme | Move | Aim | Fire |
| --- | --- | --- | --- |
| Classic (default) | WASD / arrows, 8 directions | the way you last moved | Space |
| Mouse aim | WASD / arrows | mouse | click or Space |
| Touch | left-thumb stick | the stick direction | FIRE button |

1-9 and 0 pick weapons, Q / E cycle, P pauses (solo only). Switch schemes with the
**SETTINGS** button in the top right.

## Tuning

Every number (camera, speeds, damage, fire rates, colors) is in
`src/shared/Config.luau`. The unlock ladder is in `src/shared/Unlocks.luau`.
Rooms are ASCII maps in `src/shared/Rooms.luau`.

## Milestones

- [x] 1. Camera, blocky hero, movement, pistol shooting (practice targets)
- [ ] 2. Rooms from ASCII maps (Boxy, Columns, Castle, Mazey)
- [ ] 3. Enemies at scale (server sim, flow field, client rendering)
- [ ] 4. Waves, multiplier, unlocks, HUD
- [ ] 5. All weapons, placeables, ammo boxes
- [ ] 6. Devils, runners, mummies, vampires
- [ ] 7. Lobby, voting, high scores, sounds, polish

## For developers

```sh
rokit install                         # installs rojo (see rokit.toml)
rojo build -o BlockHorde.rbxlx        # build the place file
rojo serve                            # live sync into Studio (Rojo plugin > Connect)
luau tests/spec.luau                  # unit tests for the shared math
```

Type-check with [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp):
`rojo sourcemap -o sourcemap.json`, then
`luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions=@roblox=globalTypes.None.d.luau src`.

Layout: `src/shared` -> ReplicatedStorage.Shared, `src/server` ->
ServerScriptService.Server, `src/client` -> StarterPlayerScripts.Client.
