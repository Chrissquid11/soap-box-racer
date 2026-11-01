/**
 * What a fresh world starts with: its first entities, made after the systems are registered. Not on
 * a loaded world: the start scene (`src/assets/scenes/start.scene`) opens over them, and a rebuild of
 * the running game (the editor's hot swap) loads a save in their place. Everything is made from a
 * prefab; nothing here touches the page, so a node test builds the game from this file and
 * `systems.ts`.
 */
import { Transform, type World } from '@vibe/engine';
import { Crate, FallingCrate, Floor, MainCamera } from './prefabs.ts';

/** The first entities: a fresh world's, never a loaded one's. After `registerSystems`. */
export function populate(world: World): void {
  // At the origin, as its file makes it.
  world.instantiate(Crate);
  // Physics (physics.json, on): a floor, and a crate dropped onto it from two metres up, beside the spinning one.
  world.instantiate(Floor);
  const box = world.instantiate(FallingCrate);
  const at = world.store(Transform);
  at.px[box] = 1.5;
  at.py[box] = 2;
  // What the game is seen through: a `Camera`, main, where its file puts it. The start scene has its own, and is
  // loaded in place of all this -- so one main camera either way.
  world.instantiate(MainCamera);
}
