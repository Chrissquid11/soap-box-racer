/**
 * The player's progress, kept in the browser between sessions (`game/save.ts` is how): the page's, not the game's --
 * the simulation never reads it; the garage shows it, the results write it.
 *
 * `?reset` on the address starts afresh: the save wiped as the page loads (the touch settings kept), and the word
 * taken off the address so a reload does not wipe it again.
 */
import { probing } from '@vibe/engine/boot';
import { makeProgress, SAVE_KEY } from '../game/save.ts';

export type { Finish } from '../game/save.ts';

// Studio mode's probe page evaluates this module in a hidden frame: it touches no storage there.
const storage = probing() || typeof localStorage === 'undefined' ? null : localStorage;
if (storage) {
  try {
    const url = new URL(location.href);
    if (url.searchParams.has('reset')) {
      storage.removeItem(SAVE_KEY);
      url.searchParams.delete('reset');
      history.replaceState(history.state, '', url.toString());
    }
  } catch {
    // No address to read: nothing to reset.
  }
}
const progress = makeProgress(storage);

export const { isOpen, bestTime, timeMedal, bestMedal, finished, mastered, unlockAll, resetAll, openCount } = progress;
