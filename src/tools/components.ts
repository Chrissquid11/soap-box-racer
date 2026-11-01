/**
 * The components the project's editor tools define -- a tile layer, a road's curve -- re-exported here, or
 * defined here: `@vibe/engine` alone, never the editor. `boot` awaits this module before the prefabs compile and
 * the world is made (`BootOptions.components`, behind `DEBUG_BUILD` in main.ts), and the game's worker imports it
 * after the game's own (`game/worker.ts`, the same literal), so the page and the worker hold one list of
 * components and the editor itself loads only when it is opened. Empty until a tool has one.
 */
export {};
