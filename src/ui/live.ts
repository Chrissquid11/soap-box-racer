/**
 * The game as the page's UI sees it: the world running now and its kart, put here each frame by the
 * race HUD's render system (`race-hud.ts`, one of the game entry's installs, made again on every
 * rebuild -- so it is always the world as it is now, never one kept from before). The garage writes
 * the player's build and orders through `orderRace` and `setSlot`, between ticks, as the editor's
 * inspector writes a field.
 */
import { NONE, type Entity, type World } from '@vibe/engine';
import { Build, Kart, Order } from '../game/components.ts';
import type { Choice } from '../game/build.ts';

export const live: { world: World | null; kart: Entity } = { world: null, kart: NONE };

/** Which screen shows while the kart waits off the course: the course select (first, and between runs) or the
 * garage (building the kart for the course picked). Separate screens: the garage never picks the course. */
export const screen: { now: 'courses' | 'garage' } = { now: 'courses' };

/** The slot names, as `Build`'s fields and `Choice`'s keys. */
export type Slot = keyof Choice;

/** The kart's build as it stands, into `out`; false with no kart. */
export function readBuild(out: Choice): boolean {
  const { world, kart } = live;
  if (!world || kart === NONE || !world.alive(kart)) return false;
  const b = world.store(Build);
  out.chassis = b.chassis[kart]!;
  out.wheels = b.wheels[kart]!;
  out.suspension = b.suspension[kart]!;
  out.steering = b.steering[kart]!;
  out.body = b.body[kart]!;
  out.outfit = b.outfit[kart]!;
  out.chassisWidth = b.chassisWidth[kart]!;
  out.chassisLength = b.chassisLength[kart]!;
  out.frontSize = b.frontSize[kart]!;
  out.rearSize = b.rearSize[kart]!;
  out.springSize = b.springSize[kart]!;
  return true;
}

/** One slot set to a part (or a size to its percent), and the kart rebuilt with it. */
export function setSlot(slot: Slot, index: number): void {
  const { world, kart } = live;
  if (!world || kart === NONE || !world.alive(kart)) return;
  const b = world.store(Build);
  b[slot][kart] = index;
  b.version[kart] = (b.version[kart]! + 1) & 0xffff || 1;
  // Set down on the line again, so a taller or shorter kart settles on its new wheels.
  b.order[kart] = Order.garage;
}

/** Ask the race for a run, a restart, or the garage. */
export function orderRace(order: number): void {
  const { world, kart } = live;
  if (!world || kart === NONE || !world.alive(kart)) return;
  world.store(Build).order[kart] = order;
}

export { Order };

/** The course the kart races (0 the first): it is loaded at once, the kart on its start line in the garage. */
export function setCourse(course: number): void {
  const { world, kart } = live;
  if (!world || kart === NONE || !world.alive(kart)) return;
  world.store(Build).course[kart] = course;
}

/** The course the kart's build names now. */
export function currentCourse(): number {
  const { world, kart } = live;
  if (!world || kart === NONE || !world.alive(kart)) return 0;
  return world.store(Build).course[kart]!;
}

/** Whether a menu (the course select) is up over the garage: Enter is the menu's then, never a run's start. */
export function setMenu(on: boolean): void {
  const { world, kart } = live;
  if (!world || kart === NONE || !world.alive(kart)) return;
  const b = world.store(Build);
  const v = on ? 1 : 0;
  if (b.menu[kart] !== v) b.menu[kart] = v;
}

/** How many courses are open, told to the kart: the race runs only those. */
export function setOpen(open: number): void {
  const { world, kart } = live;
  if (!world || kart === NONE || !world.alive(kart)) return;
  const b = world.store(Build);
  if (b.open[kart] !== open) b.open[kart] = open;
}

/** The weather dealt for the kart's course (`weather.ts`' Weather), sunny with no kart. */
export function currentWeather(): number {
  const { world, kart } = live;
  if (!world || kart === NONE || !world.alive(kart)) return 0;
  return world.store(Kart).weather[kart]!;
}

/** The run's sound loops silenced at once (`game/sounds.ts` puts it here while it runs): for the pause menu, which
 * stops the world -- and with it the render system that sets their loudness every frame, so a skid or a scrape would
 * otherwise drone on under the menu. The next frame after it sets them again. */
export const soundLoops: { hush: (() => void) | null } = { hush: null };

export function hushLoops(): void {
  soundLoops.hush?.();
}
