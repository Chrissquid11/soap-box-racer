# karty

A Squidwright game: three.js and PixiJS on `@vibe/engine`, made by `vibe new`.

```bash
git lfs install      # once per machine, before any clone (a source-mode clone: --recurse-submodules)
npm install          # postinstall: the generated files (vibe assets) and Claude's files (vibe sync)
npm run dev          # the editor on http://localhost:5190/?studio (the game alone at /)
```

- **Studio mode is the editor**: `?studio` on the dev server's URL (F5's "Studio (dev)", or the
  `[vibe] studio:` line `npm run dev` prints) -- the whole page, never closed: `1` Scene (the entity
  tree, the scene, one inspector, the Assets panel along the bottom), `2` Config (Systems, Scenes,
  Physics, Tools, Preferences, Keys, Claude's settings), `3` Model (a Gladius script's build), `4` the Assets
  panel's keys, `5` Studio (the console, tsc's problems, the tests, the build, Code, Git: no terminal),
  `Mod+;` Claude Code's prompt, `?` every key. `T` runs a playtest, `P` pauses it, Esc stops it.
- **The plain page** (`/`) is the game as a player has it, with the debug keys: `P` and Esc pause, `U`
  hides the UI, `?debug` the debug panel. A release build has no editor at all.
- **The scripts**, each a `vibe` command: `npm run typecheck`, `npm test` (the tests, then the engine's
  checks), `npm run build` (into `dist/`, no editor), `npm run build:debug`, `npm run preview`,
  `npm run export` (every stale source in `AssetsSource/` exported), `npm run assets`, `npm run packs`.
- **Before studio mode reloads**, it evaluates the changed modules in a hidden probe frame of the same
  origin (a `throw` holds the reload): a module with a top-level side effect (storage, a fetch, sound)
  checks `probing()` from `@vibe/engine/boot` first; `boot()` itself does.
- **The game** is `src/game/` (components, prefab tokens, systems), its page `src/main.ts` (its hooks
  into `boot()`), its HUD and menu `src/ui/`, its own editor tools `src/tools/`, its art
  `AssetsSource/` exported into `src/assets/` (a file there is its key: no manifest).
- **Physics is on**: Ammo (Bullet) steps every tick -- the start scene's crate falls onto its floor. Its settings
  are `physics.json` (Config ▸ Game ▸ Physics); `"enabled": false` turns it off and leaves Ammo out of the build.
- **The engine** is `engine/` in source mode (a submodule, its own commits); in published mode
  `vendor/` holds its three tarballs, committed through LFS. The engine's docs are its `Docs/`.
