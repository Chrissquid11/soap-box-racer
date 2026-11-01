/**
 * The game's data model: every component, relation, event and tag, in one file -- read it first, it
 * says what exists. What is made of them is a prefab (`prefabs.ts`, the files under
 * `src/assets/prefabs/`); what happens to them is `systems/`.
 *
 * Numbers go in a `component` (typed arrays, fast) -- an enum, flags, a colour, a vector, a ref to an
 * entity and an asset's key are numbers too, each with its own widget in the inspector. A yes or no is
 * a `tag`. A list, a dictionary, text or a record is a `dataComponent`. A field systems set as the game
 * runs is `runtime`: a save keeps it, a prefab file never says it. Every component at module level.
 * Which kind for what, and the options (`min`, `max`, `slider`, `label`, `help`, `group` …): the
 * `engine` skill's `fields` page.
 */
import { component, enumOf, f32 } from '@vibe/engine';

/** An axis to turn about: an enum -- a drop-down in the inspector, `"x"` in a file, `Axis.x` in code. */
export const Axis = enumOf(['y', 'x', 'z'], 'y');

/**
 * Turns about one of its own axes: `speed` in radians a second (a slider, -6 to 6: negative turns the
 * other way), `axis` which one. Both set in its prefab file, or in the inspector.
 */
export const Spin = component('Spin', {
  speed: f32(0.6, { min: -6, max: 6, slider: true, step: 0.1, label: 'Turn speed', help: 'Radians a second; negative turns the other way' }),
  axis: Axis.as('y', { help: 'Which of its own axes it turns about' }),
}, { menu: 'Motion', help: 'Turns about one of its own axes' });
