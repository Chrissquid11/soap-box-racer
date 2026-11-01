/**
 * The game's systems, registered in order: one line each, one system a file in `systems/`.
 * Apart from `index.ts` so a worker can register the same systems over the same data without the
 * models, the scene or anything else of the page (`worker.ts`).
 *
 *   spin   60 Hz   everything with a Spin turns about its axis
 */
import type { World } from '@vibe/engine';
import { spin } from './systems/spin.ts';

/** Registration order is the order within a dependency level, and what `world.describe()` lists. */
export function registerSystems(world: World): void {
  spin(world);
}
