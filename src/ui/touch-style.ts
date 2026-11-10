/**
 * Which touch controls the player chose (the pause menu's switch): the slanted buttons (the default: steer bottom
 * middle, push and brake bottom right) or the virtual D-pad (up push, down brake, left and right steer, under one
 * thumb). Kept in the browser between sessions; the page's choice, never the game's.
 */
import { probing } from '@vibe/engine/boot';

export type TouchStyle = 'dpad' | 'buttons';

const KEY = 'downhill-mayhem/touch-style';
const store: Storage | null = probing() || typeof localStorage === 'undefined' ? null : localStorage;
let style: TouchStyle = 'buttons';
try {
  if (store?.getItem(KEY) === 'dpad') style = 'dpad';
} catch {
  // No storage: the default.
}

export function touchStyle(): TouchStyle {
  return style;
}

/** The D-pad's sensitivity, the pause menu's choice: low, medium (the default) or high -- how far the thumb must
 * go from the middle before a way is pressed (`deadZone`). */
export const SENSITIVITIES = ['Low', 'Medium', 'High'] as const;
const SENSITIVITY_KEY = 'downhill-mayhem/touch-sensitivity';
let sensitivity = 1;
try {
  const saved = Number(store?.getItem(SENSITIVITY_KEY));
  if (Number.isInteger(saved) && saved >= 0 && saved < SENSITIVITIES.length && store?.getItem(SENSITIVITY_KEY) !== null) sensitivity = saved;
} catch {
  // No storage: the default.
}

export function touchSensitivity(): number {
  return sensitivity;
}

export function setTouchSensitivity(next: number): void {
  sensitivity = next;
  try {
    store?.setItem(SENSITIVITY_KEY, String(next));
  } catch {
    // No storage: this session only.
  }
}

export function setTouchStyle(next: TouchStyle): void {
  style = next;
  try {
    store?.setItem(KEY, next);
  } catch {
    // No storage: this session only.
  }
}
