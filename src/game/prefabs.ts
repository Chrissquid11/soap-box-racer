/**
 * What the game makes: its prefabs, one token each, by key -- `prefab('crate')` is
 * `src/assets/prefabs/crate.prefab`, which says what the thing is built from: its entities, their
 * components and numbers, its model. A token (and a node, `Crate.node('lid')`) at module level; in a
 * system `ctx.cmd.instantiate(Crate)`, outside one `world.instantiate(Crate)`. Never a `kind(`.
 */
import { prefab } from '@vibe/engine';

/** The placeholder crate: spins (`Spin`) where it is put. */
export const Crate = prefab('crate');

/**
 * A crate with a body (`RigidBody`, `BoxCollider`): the physics stage drops it, and it tumbles and comes to rest on
 * the floor. Its numbers are the physics' -- never move it by its `Transform` every tick; push it (`Forces`).
 */
export const FallingCrate = prefab('falling-crate');

/** The floor: a collider with no body, so it never moves -- what the falling crate lands on. */
export const Floor = prefab('floor');

/** The camera the game is seen through (`Camera`, main): still, looking at the crate. Move it by its `Transform`. */
export const MainCamera = prefab('camera/main');
