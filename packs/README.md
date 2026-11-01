# packs/ — content fetched later

The build ships only what the menu and the first round need, so the game is
playable in a second or two. Everything else — new levels, a second biome,
seasonal props — lives here and is fetched as a `.zip` when it is wanted.

```
packs/
  reef/
    models/{characters,props,environment}/
    textures/{characters,props,environment}/
    sprites/                                  <name>.png + <name>.json
    audio/{sfx,ui,music}/
```

A pack mirrors the folders of `src/assets/`, minus `icons/` and `fonts/` —
those are handed to the UI as URLs, and a pack has bytes, not URLs. Its sources
live in `AssetsSource/packs/<name>/`, at the same paths, and `npm run export` makes
the files here from them, as for the boot set: the engine's `Docs/assets.md`
(§2, §3) and `AssetsSource/README.md`.

## Using one

```ts
await Assets.mount('reef', { onProgress: setBar });  // between rounds: decoding drops frames
scene.add(Assets.instance('reef:props/coral'));     // pack keys carry the pack's name
Audio.sfx('reef:bubble-pop');
await Assets.unmount('reef');                        // frees the GPU memory
```

Keys are compiler-checked like any other. A key from an unmounted pack still
typechecks, and throws `needs its pack -- await Assets.mount('reef') first` —
better than a blank model.

## How it ships

`npm run packs` (`@vibe/pipeline/src/assets/packs.ts`; and every `npm run build`, and the dev server) zips each folder
into `public/packs/<name>-<hash>.zip` and writes an `index.json`. The zip is
deterministic (fixed timestamps, sorted entries), so unchanged content keeps its
hash, and the hashed name makes the URL immutable: cached forever in the Cache
API, never served stale. `public/packs/` is gitignored — the folders here are
the source, the archives are derived.

**Where they come from is one setting**: `packs/` relative to the page by
default, so they ride along in the build's upload. `VITE_PACK_BASE_URL=https://cdn.../`
serves them from a CDN instead (which then needs CORS for the game's domain),
and lets a new level ship without a rebuild: upload the zip, update
`index.json`, and `Assets.availablePacks()` sees it.

## Rules

- **`.glb` only for models.** A pack is decoded from bytes with no base URL, so a
  `.gltf` cannot find its `.bin`.
- **A sprite atlas needs its `.json` beside the image**, same name.
- **Underscore-prefix to exclude.** `_wip/` or `_draft.glb` is skipped by both
  the zip and the generated types, exactly as in `src/assets/`.
- **Mount between rounds, not during one.** Decoding a pack drops frames.
