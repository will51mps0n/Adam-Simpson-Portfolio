# Dev checks (not part of the game)

Roblox Studio can't run in a cloud session, so these check the game without it.

**Smoke test.** `smoke.luau` runs the server lighting and the whole milestone 1
test stage in [Lune](https://github.com/lune-org/lune), presses every button and
plays the animations. Lune checks every property name and type, so typos fail
here instead of in Studio.

```sh
rojo build -o SplashSquad.rbxlx
lune run dev/smoke.luau SplashSquad.rbxlx
```

**Preview pictures.** In `preview/`:

1. `run.luau` loads `SplashSquad.rbxlx` in [Lune](https://github.com/lune-org/lune),
   runs the real ModuleScripts (CharacterBuilder, Face, KidAnimator, ...) and
   writes every part, face drawing and animation pose to `scenes.json`.
   Any runtime error in the character or animation code shows up here.
2. `render.mjs` draws those scenes with three.js in headless Chromium and saves
   contact sheets (lineup, faces, hats, poses) as PNGs.

The pictures are an approximation (different lighting and outline renderer),
good for checking proportions, faces and poses, not final looks.

```sh
rojo build -o SplashSquad.rbxlx
lune run dev/preview/run.luau SplashSquad.rbxlx dev/preview/scenes.json
cd dev/preview && npm install && node render.mjs out            # all sheets
node render.mjs out faces,poses                                  # just some
```
