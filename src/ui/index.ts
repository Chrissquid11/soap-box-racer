/**
 * The project's UI, made over the game: the HUD and the pause menu (`hud.ts`, `pause-menu.ts`) added to the canvas UI.
 * `main.ts` hands it to `boot()` as this module's import (`ui: { import: () => import('./ui/index.ts') }`, this `ui`
 * export the hook), never a static import: a UI module that does not load -- a bad named import, a top-level throw -- is then
 * boot's to catch, and in studio mode (`?studio`) the editor still comes up to fix it.
 */
import type { UiHook } from '@vibe/engine/boot';
import { Hud } from './hud.ts';
import { PauseMenu } from './pause-menu.ts';

export const ui: UiHook = (_game, ui, actions) => ({ hud: ui.add(new Hud(ui, actions), 'hud'), menu: ui.add(new PauseMenu(actions.resume), 'menu') });
