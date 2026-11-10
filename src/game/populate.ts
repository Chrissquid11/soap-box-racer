/**
 * What a fresh world starts with: its first entities, made after the systems are registered. Not on
 * a loaded world: the start scene (`src/assets/scenes/downhill.scene`) opens over them, and a rebuild of
 * the running game (the editor's hot swap) loads a save in their place. Everything is made from a
 * prefab; nothing here touches the page, so a node test builds the game from this file and
 * `systems.ts`.
 *
 * The kart and the camera chasing it. The course is the `course` system's: it loads the one the kart's
 * build names, its track and its hazards, and `race` puts the kart on its start line.
 */
import type { World } from '@vibe/engine';
import { ChaseCam } from './components.ts';
import { ChaseCamera, HomemadeKart } from './prefabs.ts';

/** The first entities: a fresh world's, never a loaded one's. After `registerSystems`. */
export function populate(world: World): void {
  const kart = world.instantiate(HomemadeKart);
  const camera = world.instantiate(ChaseCamera);
  world.store(ChaseCam).target[camera] = world.ref(kart);
}
