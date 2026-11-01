# karty

A Squidwright game on the engine's packages: `@vibe/engine` (what the game runs on), `@vibe/editor`
(the editor -- studio mode, `?studio` -- debug builds only) and `@vibe/pipeline` (the `vibe` CLI every script runs).

- **Four skills, written into `.claude/skills/` by `vibe sync` on `npm install`** (the editor's Claude has the
  same): read a skill's `SKILL.md` index, then only the page the task needs.
  - **`vibe`** -- the engine's rules that are easy to break: load it before changing anything under `src/game/`,
    `src/ui/`, `src/tools/` or `src/assets/`.
  - **`engine`** -- how to make the game, a page per engine system from the installed packages: the project's
    shape (`game`, first), the ECS, the field kinds (`fields`: which kind for what -- a slider, an enum, flags, a
    ref, an asset's key, a list or a dictionary -- and the inspector's widget for each), the loop, prefabs, render,
    cameras, physics, assets, UI, audio, input, debug, testing, and this project's own editor tools (`tools`).
  - **`studio`** -- how to drive the editors through the studio's MCP tools, a page per
    editor: the scene, the assets, the Model tab, a playtest, the code, the Config tab -- and a page for each
    tool of this project's own.
  - **`gladius`** -- a model is a Gladius script under `AssetsSource/models/`: making and changing one.
- **A tool of this project's comes with its MCP tools and its page**: what a person can do with its buttons,
  menus and keys, Claude can do through `mcpTools` (`src/tools/index.ts`, served as `project_<name>`). Each action
  declares its tool -- `button(mcp, …)`, `MenuItem.mcp`, `ToolKey.mcp`: a tool's name, `'ui'`, or
  `projectNone('<why>')` -- and the tool has its page, `<id>.skill.md` beside its code, joining `studio`. `npm test`'s
  `mcp` check refuses a raw `el('button')` without its `// mcp: …`, and its `skills` check an MCP tool no page
  covers (the `engine` skill's `tools` page says how).
- The installed packages carry their TypeScript sources (`node_modules/@vibe/*/src/`): the engine's code can
  always be read.
- `npm run dev` serves the game on port 5190; `npm run typecheck` and `npm test` (the tests, then
  the engine's checks) check a change. Never edit a file `vibe assets` writes -- each one the
  `.gitignore` lists: `src/assets/keys.d.ts`, `globs.ts` and every `*-globs.ts`, `pack-kinds.ts`, `bundle.ts`,
  `prefab-bundle.ts`, `material-bundle.ts`, `uids.ts`, and `src/game/live.ts`.
- **Physics is on** (Ammo, a stage of every tick): `physics.json` beside `vite.config.ts` holds its settings --
  gravity, substeps, layers -- and `"enabled": false` turns it off, Ammo left out of every build (Config ▸ Game ▸
  Physics writes it). The start scene's falling crate lands on its floor; `src/game/fall.test.ts` is how a physics
  test goes. The `engine` skill's `physics` page is the how.
- When `engine/` is a git submodule it is the engine's checkout with its own history: a change there
  is the engine's, committed in `engine/` separately.

This game's own rules go below.
