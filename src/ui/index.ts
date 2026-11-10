/**
 * The project's UI, made over the game: the HUD and the pause menu (`hud.ts`, `pause-menu.ts`), the
 * run's HUD and results (`race-hud.ts`) and the garage, the kart builder (`garage.ts`), added to the
 * canvas UI. `main.ts` hands it to `boot()` as this module's import (`ui: { import: () =>
 * import('./ui/index.ts') }`, this `ui` export the hook), never a static import: a UI module that does
 * not load -- a bad named import, a top-level throw -- is then boot's to catch, and in studio mode
 * (`?studio`) the editor still comes up to fix it.
 *
 * The game's face (`kit.ts`) loads as the UI comes up: once it is in, every label is drawn again in it and
 * every widget laid out again, its words measured anew.
 */
import type { UiHook } from '@vibe/engine/boot';
import type { Units, Widget } from '@vibe/engine/ui';
import { phoneSized, SCREEN_M } from './screen-theme.ts';
import { setTouchFloor } from './slant-button.ts';
import { CourseSelect } from './course-select.ts';
import { Garage } from './garage.ts';
import { Hud } from './hud.ts';
import { loadKartyFont, refaceAll } from './kit.ts';
import { PauseMenu } from './pause-menu.ts';
import { RaceHud, showRaceHud } from './race-hud.ts';
import { touchFirst, TouchControls } from './touch-controls.ts';

/** The units a widget is laid out in: the engine's, the menus' unit shrunk on a narrow screen so a menu laid out for
 * SCREEN_M.fitWidth fits across it -- the engine's follows the height alone -- but on a phone (either way up) never
 * under SCREEN_M.phoneUnit, its words still easy to read: each screen lays itself out for a phone (`phoneSized`).
 * And anything pressed at least a finger high (`setTouchFloor`) on a phone or a touch screen. */
function fitted(units: Units): Units {
  const phone = phoneSized(units);
  setTouchFloor(phone || touchFirst() ? SCREEN_M.touch : 0);
  const fit = Math.min(units.m, units.width / SCREEN_M.fitWidth);
  const m = phone ? Math.max(fit, SCREEN_M.phoneUnit) : fit;
  return m !== units.m ? { ...units, m } : units;
}

/** Each of its layouts handed the fitted units. */
function fitWidth(widget: Widget): void {
  const layout = widget.layout?.bind(widget);
  if (layout) widget.layout = (units: Units) => layout(fitted(units));
}

export const ui: UiHook = (game, ui, actions) => {
  const race = showRaceHud(ui.add(new RaceHud(), 'hud'));
  const touch = ui.add(new TouchControls(game), 'hud');
  const garage = ui.add(new Garage(), 'hud');
  race.attach(garage);
  const select = ui.add(new CourseSelect(), 'hud');
  race.attachSelect(select);
  const hud = ui.add(new Hud(ui, actions), 'hud');
  const menu = ui.add(new PauseMenu(actions.resume), 'menu');
  const widgets: Widget[] = [race, touch, garage, select, hud, menu];
  for (const w of widgets) {
    fitWidth(w);
    w.layout?.(ui.units);
  }
  void loadKartyFont().then(() => {
    ui.onPixiSide(() => {
      refaceAll();
      for (const w of widgets) w.layout?.(ui.units);
    });
  });
  return { hud, menu };
};
