/**
 * Whether the game runs on a phone or a tablet (a coarse pointer: a finger), where it draws less -- a smaller
 * shadow box, no shadows from the small props, the crowd and the far scenery hidden sooner. Only the look: never
 * read for anything the simulation decides. False under node (the tests); `?lowend` / `?highend` force it either way.
 */
let low: boolean | null = null;

export function lowEnd(): boolean {
  if (low !== null) return low;
  try {
    const q = new URLSearchParams(location.search);
    low = q.has('lowend') || (!q.has('highend') && typeof matchMedia === 'function' && matchMedia('(pointer: coarse)').matches);
  } catch {
    low = false;
  }
  return low;
}
