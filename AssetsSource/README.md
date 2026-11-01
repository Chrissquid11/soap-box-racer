# AssetsSource/ — source files

Every original a designer opens, and nothing the browser downloads. The pipeline
(`@vibe/pipeline`'s `src/assets/`, the whole design in the engine's `Docs/assets.md`)
makes the file the game loads from each source here; the source stays, for a
better conversion later.

This folder sits outside `src/` and `public/` on purpose: Vite never bundles
it, so a 400 MB `.blend` can live next to the model it produces without any
risk of it reaching a build.

**Why `AssetsSource/`.** It is the source of the assets: `src/assets/` holds the
files the game ships, `packs/` the ones it ships later, and this folder what
every one of them is made from -- every original, art or not: models, textures,
sprites, fonts, audio masters -- and nothing in it is ever in a build. The name
says what it is the source of, and reads apart from `src/` at a glance, which a
bare `Source/` beside it did not. The editor's Assets tool still calls it
**Source**: there it sits under "Not shipped", over Assets and Packs.

```
AssetsSource/
  models/{characters,props,environment}/     .lua .blend .fbx .obj .dae .stl .gltf .glb + parts
  textures/{characters,props,environment,ui}/  .png .jpg .tif .webp .psd .xcf .kra
  sprites/                       .aseprite, or a packer's .png + .json
  icons/  fonts/                 originals, where the shipped ones are made from something
  audio/{sfx,ui,music}/          .wav .flac .aif masters, DAW projects beside them
  packs/<name>/...               the same tree again, for what ships in a pack
  reference/                     photos, palettes, mockups (reference/ui/): nothing is made from these
```

## Rules

- **The source and its export have the same path.**
  `AssetsSource/models/props/crate.lua` ships as `src/assets/models/props/crate.glb`,
  `AssetsSource/packs/reef/audio/sfx/bubble.wav` as `packs/reef/audio/sfx/bubble.ogg`.
  Rename one and the other follows. One stem, one source, per folder: a
  `crate.lua` and a `crate.glb` side by side would both be `props/crate`, and
  the pipeline refuses to guess (`conflict`).
- **Export settings live in `<stem>.export.json`** beside the source, committed:
  `options` holds what differs from the defaults (edit it by hand, or in the
  tool), `built` is the pipeline's record of what was made from what, and is
  never edited. A folder's `export.json` sets defaults for everything under it
  (`{ "options": { "lossless": true } }` in `textures/ui/`). The defaults and
  every option's range are in `@vibe/pipeline/src/assets/recipes.ts` -- change a default
  for one game with a folder's `export.json`, never there.
- **`npm run export`** makes every export that is stale or missing; `npm run
  export -- props` only those whose path contains `props`; `-- --force`
  everything; `-- --check` exits 1 if anything is not current, which is what CI
  runs. Whether an export is current is decided by content hashes in the
  record, not by file dates, so a fresh clone agrees with every other machine.
- **While `npm run dev` runs, a source saved here is exported by itself** once
  it has been unchanged for half a second -- from Blender, Photoshop, the
  Finder -- and the running game takes the new file with no page reload. A
  `.blend` waits to be asked (Blender is slow): `npm run export`, or Export in
  the editor's Assets tool. A tool a source needs and this machine lacks
  (ffmpeg with libvorbis, say) leaves it `unmade`, saying how to get it.
- **A name starting with `_` never ships.** `_robot.glb` beside `robot.fbx` is its
  plain build (a game tab's conversion, or a `.blend`'s export by hand), and is
  committed so any machine can finish the export from it.
- **A source can be left out of the build** -- kept, versioned, never exported --
  by its "in the build" tick in the editor's Assets tool, or by hand: its
  `<stem>.export.json` gains `"include": false` at the top. Out, it is
  `excluded`: auto-export, `npm run export` and Export now pass it over (asked
  for by name, the CLI refuses it), `--check` ignores it, it is in no conflict
  and takes no key, and its export goes to the trash. Ticked back, the flag comes
  off and it is exported again. Two sources of one stem share one record, so the
  tick takes one of them out by its name instead (`_crate.glb`): that is how
  "crate.glb and crate.lua would both be props/crate" is settled without
  deleting either.
- **Names are lowercase letters, digits and dashes**, one dot before the
  extension: `round-over.wav`. The live host is case-sensitive and macOS is not.
- **These are Git LFS files.** `.gitattributes` already covers `.blend`,
  `.aseprite`, `.psd`, `.kra`, `.xcf`, `.wav` and the rest. A fresh clone needs
  `git lfs install` before the filters engage.
- **Backups are gitignored** (`*.blend1`, `*.aseprite-backup`, `*.psd~`) so
  they never get pushed to the LFS server as junk.
- **Export at the size the game draws at**, not the size you authored at.

## What becomes what

| Source | Ships as | How |
| --- | --- | --- |
| `.lua` (Gladius) | `.glb` | `gladius run`, then finished, textures to WebP, Draco |
| `.blend` | `.glb` | Blender in the background where it is installed; elsewhere `_<stem>.glb`, exported by hand |
| `.fbx` `.obj` `.dae` `.stl` | `.glb` | a game tab converts it (three's loaders) into `_<stem>.glb`, then as above |
| `.gltf`, `.glb` | `.glb` | packed with the files it names, finished, Draco |
| `.png` `.jpg` `.webp` `.tif` (textures) | `.webp` | resized to `max` (2048), quality 90 or lossless |
| `.psd` `.xcf` | `.webp` | flattened (Photoshop's own composite where the file has one), then as above |
| `.kra` | `.webp` | Krita's own merged image, then as above |
| `.aseprite` | `.png` + `.json` | `aseprite --sheet-pack`, frames packed |
| a packer's `.png`/`.webp` + `.json` | the same | copied together |
| `.wav` `.flac` `.aif` | `.ogg` | ffmpeg, Vorbis; sounds made mono when both channels match, leading silence cut |
| `.ogg` `.opus` `.mp3` `.m4a` `.woff2` `.svg` `.ktx2` ... | the same | copied as they are |

A file that ships as it is can also go straight into `src/assets/` (or a
pack): a bought `.glb` that arrived finished is fine there, and nothing nags
about it. Anything else here -- a DAW project, notes -- is kept, not converted.

## Tools

The steps need `gladius`, `ffmpeg` (with **libvorbis**: Homebrew's own ffmpeg
has only the experimental native encoder -- use a static build from
ffmpeg.org, or the `homebrew-ffmpeg/ffmpeg` tap), `magick`, `blender` and
`aseprite`. Each is found on the PATH, in its app's usual place (Blender in
`/Applications`, Aseprite there or in Steam), in an environment variable named
for it (`FFMPEG=/path/to/ffmpeg`), or at a path kept in the gitignored
`assets.local.json`. A tool that is missing makes its sources `unmade`, with
what to install, never a failure.

## Gladius models: one look

`npm run export` builds every `.lua` model the same way, so the models match:

1. `gladius run --textures embedded --optimise-anim 5` builds the plain `.glb`.
2. `finish` **smooth-shades** it -- faces meeting at under 70 degrees (`angle`)
   are one smooth surface, sharper corners stay crisp -- and drops materials
   nothing uses.
3. Any texture is packed as WebP, then Draco writes the compressed copy the game
   loads into `src/assets/models/`.

What a script owes the pipeline:

- **Colour on the vertices, over one white material** (`paint_faces`). Paint last:
  `join` and most ops drop colour.
- **One mesh a look.** Build the parts apart, then `merge` them. Parts the game moves
  on their own stay separate nodes.

`models/props/crate.lua` is the placeholder the new game spins (`src/assets/prefabs/crate.prefab`
names its export): delete it, its `crate.export.json` and its export once the game has art of its own.

## On Linux

The dev server watches every folder here; on Linux each folder costs an
inotify watch, and a big tree can run out. Raise the limit once:
`echo fs.inotify.max_user_watches=524288 | sudo tee /etc/sysctl.d/40-inotify.conf && sudo sysctl --system`.
