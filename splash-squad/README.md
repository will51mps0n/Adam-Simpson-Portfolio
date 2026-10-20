# Splash Squad

A cute multiplayer Roblox game that plays like the classic Flash raft artillery
games: cartoon kids on rafts lob tennis balls, rockets and grenades to knock
each other into the water. ("Splash Squad" is a placeholder name.)

Everything is built from code with [Rojo](https://rojo.space): no uploaded
meshes or images.

## Play it

1. Download `SplashSquad.rbxlx` from this folder.
2. Double-click it (or open it from Roblox Studio with File > Open from File).
3. Press **Play** (F5).

## Progress

- [x] **Milestone 1: the cute kids.** A test stage on a dock with the whole cast.
      Try every face and move with the buttons, dress kids up in the wardrobe.
- [ ] Milestone 2: the beach and aiming
- [ ] Milestone 3: solo story with AI gangs
- [ ] Milestone 4: multiplayer core and Co-op Story
- [ ] Milestone 5: versus modes
- [ ] Milestone 6: saving, wardrobe, polish

## Where things live

| To change | Edit |
| --- | --- |
| Sizes, face layout, animation timing, lighting | `src/shared/Config.luau` |
| Colors | `src/shared/Data/Palette.luau` |
| Hair styles, hats, clothes, prices | `src/shared/Data/Outfits.luau` |
| The kids and their outfits | `src/shared/Data/Characters.luau` |
| How a kid is built | `src/shared/Character/` |
| Animations and splashes | `src/client/Animation/`, `src/client/Effects/` |
| The milestone 1 test stage | `src/client/Showcase/` |

## Live editing (optional)

With [Rokit](https://github.com/rojo-rbx/rokit) installed, in this folder:

```sh
rokit install          # installs the Rojo version pinned in rokit.toml
rojo plugin install    # once, adds the Rojo plugin to Studio
rojo serve
```

Then in Studio click **Rojo > Connect**. Saving a file updates the game live.
To rebuild the place file: `rojo build -o SplashSquad.rbxlx`.
