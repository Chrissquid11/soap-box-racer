/**
 * The game's worker thread: the same systems over the same data, for the ones
 * marked `parallel` (Docs/ecs.md §10). `Game.startWorkers` starts these.
 *
 * It imports what defines components in the order the main thread does --
 * the engine first (its index: the ECS's built-ins, then `view.ts`'s; the
 * package's `sideEffects` keeps them and drops the rest, three.js with it),
 * then the game's own through its systems -- and registers
 * the same systems. `serve` checks both, and says what differs. The kinds
 * include every prefab's (a parallel system's members are made from them),
 * so the prefabs are compiled here as on the page, before anything is served:
 * the generated `assets/prefab-bundle.ts` hands their files to the engine
 * (`usePrefabFiles`), the uid index first (`uids.ts`, so a reference resolves by
 * uid here as on the page) -- the prefab half of the page's `assets/bundle.ts`, apart
 * so this thread carries none of the asset runtime.
 *
 * The editor tools' components after the game's (`../tools/components.ts`, engine-only), behind the
 * `DEBUG_BUILD` literal as the page's `boot` has them (`BootOptions.components`): a debug build's page and
 * worker hold one list in one order, and a release worker carries nothing of them.
 *
 * Nothing of the page may be imported here: no assets, no three.js scene, no
 * UI. `systems.ts` and what it imports are kept free of them for this.
 */
import '@vibe/engine';
import { Prefabs } from '@vibe/engine';
import { serve, webPort } from '@vibe/engine/worker';
import '../assets/prefab-bundle.ts';
import { registerSystems } from './systems.ts';

// The port first: what the page sends while the tools' components load is kept for `serve` (`webPort`).
const port = webPort();
if (DEBUG_BUILD) await import('../tools/components.ts');

Prefabs.compile();
serve(registerSystems, port);
