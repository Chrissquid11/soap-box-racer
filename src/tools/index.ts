/**
 * The project's own editor tools, Config pages and inspector blocks (a tool's components are `components.ts`): debug code, as the editor is -- `main.ts` reaches
 * this file only through its DEBUG-gated `import()`, and a release build carrying anything of
 * `src/tools/` fails (`debugGuard`). `boot` loads it as the editor is first made and hands the lists to the editor (`ProjectTools`,
 * `@vibe/engine/boot`).
 *
 * A tool is an `EditorTool` -- a tab with its cards and keys, or a panel within another tab -- and a
 * page a `ConfigPage` in the Config tree, both as `@vibe/editor`'s `index.ts` defines them (its header
 * has an example of each; the engine's `examples/tools/` has a tile tool using every point). Empty until
 * the game has one.
 */
import type { BlockItem, ConfigPage, EditorTool } from '@vibe/editor';

export const tools: EditorTool[] = [];
export const pages: ConfigPage[] = [];
export const blocks: BlockItem[] = [];
