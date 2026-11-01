/**
 * The game's entry: what the engine builds the world from (`GameEntry`, `@vibe/engine`) -- its
 * systems registered (`registerSystems`) and its first entities made (`populate`). Two calls, not one,
 * because a rebuild of the running game (the editor's hot swap) registers the systems again and loads
 * a save in place of the first entities.
 *
 *   components.ts   what exists: every component, relation, event and tag
 *   prefabs.ts      what is made: a token for each prefab file (src/assets/prefabs/)
 *   systems/        what happens: one system a file
 *   systems.ts      in what order
 *   populate.ts     what a fresh world starts with
 *   worker.ts       the worker thread's entry, for systems marked `parallel`
 *   index.ts        this: the entry, all of the above the engine is handed
 *
 * **The swap boundary's one dep**: the generated `live.ts` beside it is this file's one importer, and
 * accepts it, so a change anywhere under `src/game/` walks up to here and swaps into the running game,
 * no reload. A module of the game's the page is to see goes through here, never through a second
 * importer outside `src/game/`.
 */
// An import goes here, above the exports -- an install of the game's own (`installs`, run after its systems):
//   import { entityCountHud } from '../ui/entity-count.ts';
//   export const installs = [entityCountHud];
export { registerSystems } from './systems.ts';
export { populate } from './populate.ts';
