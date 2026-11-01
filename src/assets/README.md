# src/assets/ — the boot set

> The whole design: the engine's `Docs/project-setup.md` §6; how a
> source in `AssetsSource/` becomes a file here: the engine's `Docs/assets.md`.

**Everything here ships in the build and loads before the first frame**, so
keep it to what the menu and the first round actually need — it is a budget,
not a bucket. Anything else goes in `packs/`, fetched on demand
(`await Assets.mount('reef')`); see `packs/README.md`.

Files here are bundled: Vite fingerprints each one, rewrites every reference to
the hashed name and copies it into `dist/assets/`. Source art does not belong
here — it goes in `AssetsSource/`, at the same path, and `npm run export` makes
the file here from it (`AssetsSource/models/props/crate.lua` ships as
`models/props/crate.glb`; see `AssetsSource/README.md`).
A file that ships as it is -- an `.ogg`, a `.woff2`, a finished `.glb` -- can be
dropped in here directly.

```
src/assets/
  models/{characters,props,environment}/   .glb (images beside a .glb are its textures)
  textures/{characters,props,environment,ui}/  .ktx2, .webp, .png
  sprites/         atlases: <name>.png beside <name>.json
  icons/           .svg, .png -- for the UI
  fonts/           .woff2 (also .woff, .ttf, .otf; .json for an MSDF font)
  audio/
    music/         long, streamed, looping
    sfx/           short gameplay sounds, decoded into memory
    ui/            clicks and menu sounds
  levels/          .json, read by the engine's levels.ts
  prefabs/         .prefab (JSON inside, so told apart from any other JSON; the format is
                   Docs/prefabs.md §2), read by the engine's prefabs.ts; a .json here is no prefab
  scenes/          .scene (a world save inside, Docs/ecs.md §19), read by the engine's scenes.ts; written
                   by the editor's Scenes page; the one saying "start": true opens on start
  materials/       .material (JSON inside: a type, colours, numbers, texture maps by key; Docs/render.md
                   §4), compiled by the engine's assets/materials.ts; a Render.material names one by key
  keys.d.ts        GENERATED, gitignored — the key types
  globs.ts         GENERATED, gitignored — the registry's globs (one importer: bundle.ts)
  level-globs.ts   GENERATED, gitignored — the levels' glob (one importer: bundle.ts)
  prefab-globs.ts  GENERATED, gitignored — the prefabs' glob (one importer: prefab-bundle.ts)
  scene-globs.ts   GENERATED, gitignored — the scenes' glob (one importer: bundle.ts)
  material-globs.ts GENERATED, gitignored — the materials' glob (one importer: material-bundle.ts)
  pack-kinds.ts    GENERATED, gitignored — pack folders, model images, MIME (one importer: bundle.ts)
  prefab-bundle.ts GENERATED, gitignored — the prefab files handed to the engine (usePrefabFiles);
                   imported by bundle.ts and the game's worker; accepts its own hot updates
  material-bundle.ts GENERATED, gitignored — the material files handed to the engine (useMaterialFiles);
                   imported by bundle.ts alone; accepts its own hot updates
  bundle.ts        GENERATED, gitignored — the rest handed to the engine (useBundle); main.ts's
                   first import; accepts its own hot updates
```

The asset runtime itself is the engine's (`@vibe/engine`'s `src/`, imported as
`@vibe/engine/assets`): `assets/registry.ts` (key -> hashed URL), `assets/index.ts` (`Assets`:
`preload()`, `mount()` and the typed accessors), `assets/store.ts` (decoded assets, the loaders),
`assets/beside.ts` (a model's own textures, by name), `assets/packs.ts` (pack download, cache,
mount/unmount: a lazy chunk), `assets/zip.ts`, `assets/atlas.ts`, `audio.ts`; and in its index,
pure, `prefabs.ts`, `scenes.ts`, `levels.ts`. None of it imports a glob: the bundles hand them in.

## Adding an asset

Copy it into the right folder. That is the whole step — there is no manifest,
nothing to register, and therefore nothing for two people to conflict over.

**The key is the path under the kind's folder, minus the extension:**

| File | Key | Accessor |
| --- | --- | --- |
| `models/characters/crab.glb` | `characters/crab` | `Assets.instance('characters/crab')` |
| `textures/environment/sand.ktx2` | `environment/sand` | `Assets.texture('environment/sand')` |
| `sprites/fx.png` (+ `fx.json`) | `fx` | `Assets.atlas('fx')` |
| `icons/coin.svg` | `coin` | `Assets.iconUrl('coin')` |
| `audio/sfx/pickup.ogg` | `pickup` | `Audio.sfx('pickup')` |
| `audio/music/beach.ogg` | `beach` | `Audio.music('beach')` |
| `prefabs/crate.prefab` | `crate` | `prefab('crate')` (`src/game/prefabs.ts`) |
| `scenes/forest/camp.scene` | `forest/camp` | `game.load(scene('forest/camp'))` (the engine's `scenes.ts`) |

Keys are compiler-checked. `@vibe/pipeline/src/assets/keys.ts` writes `keys.d.ts` from
these folders -- and `globs.ts`, `level-globs.ts`, `prefab-globs.ts`, `scene-globs.ts` and `pack-kinds.ts` from the
extension lists in `@vibe/pipeline/src/assets/kinds.ts` -- on install, dev, typecheck and
build, and the Vite plugin re-runs it whenever a file appears while the dev
server is up — so a newly dropped model has a working key a moment later.
`npm run assets` does it by hand.

**In the dev server, a file here added, removed or re-exported never reloads
the page.** The glob file it changes has one importer, a generated bundle that accepts its own
hot updates: only that bundle is evaluated again, and it hands the fresh globs to the engine, which
copies them into the maps every importer holds (`useBundle`, `usePrefabFiles`, `hot.ts`) -- a prefab file is then compiled
again and every instance in the world follows it (Docs/prefabs.md §7); `index.ts`
decodes a new key into the store and forgets a removed one; a file rewritten in
place is not a module change at all, and the plugin sends the page a `reload`
for it instead (swapped into what is drawn by the editor, Docs/assets.md §8).
The editor's selection, undo stack and unsaved scene stay as they were.

## Conventions

- **A key is the path lowercased; a file keeps its name.** `models/props/Big Crate.glb` is
  `Assets.instance('props/big crate')`, and any spelling finds it (`'Props/Big Crate'`). Never
  two names that differ only by case (`Crate.glb` beside `crate.gltf`: one key) -- the key
  generator and the editor refuse it. A case-only rename goes through the editor or `git mv`
  (macOS's git does not see one otherwise, and the live host would 404); `npm test` and `npm run
  export -- --check` catch the rest.
  The live host is case-sensitive and macOS is not: a name that differs in case
  from its reference works locally and 404s live.
- **A leading `_` excludes a file or folder from the build.** `_crab-v2.glb`, or
  a whole `_unused/` folder, is invisible to the globs, the key generator and the
  pack zipper — the way to keep a work-in-progress export next to its siblings.
  It is also what the editor's Assets tool does with a file delivered as it is
  (no source) when its "in the build" tick is turned off: `crab.glb` is renamed
  `_crab.glb`, its key leaves `keys.d.ts`, and ticking it renames it back. An
  export is in or out as its source is: unticked, the source's record says
  `"include": false` and the export goes to the trash
  (the engine's `Docs/assets.md` §2, "In the build").
- **Two files that differ only by extension fail the build.** `crab.glb` and
  `crab.gltf` want the same key; rename one.
- **`.glb`, not `.gltf` + `.bin`.** A separate buffer file does not survive
  hashing — the loader resolves it relative to a name that has changed. A
  `.gltf` whose buffers are files is said on the terminal whenever the keys
  are made; one with them inline (`data:`) is whole.
- **`instance()`, never `model().scene.clone()`, for anything rigged.** It
  clones through `SkeletonUtils`; a plain clone leaves every copy bound to the
  original's bones.
- **Nothing gets a URL by string concatenation.** After hashing,
  `'models/' + name + '.glb'` points at a file that does not exist, and 404s
  only in production. Go through `Assets`.
- **A format goes on the list only once `store.ts` can decode it.** There is one
  list, `KINDS` in `@vibe/pipeline/src/assets/kinds.ts`: the globs, the key types, the pack
  zipper and `packs.ts`'s folders all come from it (Vite needs the globs as
  literals, so `keys.ts` writes them out into `globs.ts`). Each generated glob file has
  exactly one importer, a bundle; a second would be another path for a hot update to
  reach `main.ts` by, with nobody accepting it: a page reload on every drop
  (`imports.test.ts` checks).

## KTX2 and Draco

`.ktx2` keeps a texture compressed on the GPU. Nothing has to be set up: drop
one in and the store switches to `KTX2Loader`, which fetches the transcoder
Vite bundled alongside it. **Do not call `setTranscoderPath()`** — an empty path
is what makes it use the bundled, hashed copy. Call `Assets.useRenderer()` once
the Game exists (main.ts does), so packs mounted later can decode `.ktx2`.

The KTX2 transcoder (~530 kB) and the Draco decoder are lazy chunks: in `dist/`
regardless, but no player downloads one unless a file actually needs it. Keep
their imports in `store.ts` dynamic.
