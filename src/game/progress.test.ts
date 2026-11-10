/**
 * Progress (`save.ts`, `rivals.ts`' unlockBy): a top-three finish opens the next course, and so does a finish at
 * the course's score target in any place; a first place is kept as mastery; what is opened is kept -- an older save's
 * open courses stay open, and a replay that does worse never closes one; the bathtub's best is set by its first finish
 * and beaten only by a faster one.
 */
import { suite } from '@vibe/engine/testing';
import { placeOf, scoreTarget, standings, TOP_PLACES, unlockBy } from './rivals.ts';
import { makeProgress, SAVE_KEY } from './save.ts';

const t = suite('game: progress and unlocks');

// The rules, on the first course in the sunny.
const field = standings(0, 0).field;
const third = field[TOP_PLACES - 1]!.points;
const target = scoreTarget(0);
t.ok(`a top-three finish opens the next (beating the third's ${third} pts)`, unlockBy(0, third + 1, 0, null) === 'top' && placeOf(0, third + 1, 0, null) <= TOP_PLACES);
// A finish past the target but outside the top three: the score opens it (on a course whose third beats the target).
let scored = false;
for (let c = 0; c < 20 && !scored; c++) {
  const f = standings(c, 0).field;
  const tg = scoreTarget(c);
  if (f[TOP_PLACES - 1]!.points > tg + 1) scored = unlockBy(c, tg, 0, null) === 'score';
}
t.ok(`a finish at the score target, outside the top three, opens the next too (course 1's target ${target} pts)`, scored);
t.ok('neither, and it stays shut', unlockBy(0, 1, 0, null) === null);

// Kept: an old save (every course it opened still open), a worse replay (nothing closed), mastery, the bathtub's best.
const store = new Map<string, string>();
store.set(SAVE_KEY, JSON.stringify({ won: 5, best: [30, 40, null, 50, 60] }));
const progress = makeProgress({ getItem: (k) => store.get(k) ?? null, setItem: (k, v) => void store.set(k, v) });
t.ok('an older save keeps its five courses open', progress.openCount() === 5 && progress.isOpen(4) && !progress.isOpen(5));
const poor = progress.finished(0, 99, 1, 0, 1);
t.ok('a poor replay closes nothing', progress.openCount() === 5 && poor.by === null && !poor.opened);
const win = progress.finished(4, 20, field[0]!.points + 5000, 0, 2);
t.ok(`winning course 5 opens course 6, by a top-three finish, and masters it (place ${win.place})`, win.opened && win.by === 'top' && win.mastered && progress.openCount() === 6 && progress.mastered(4));
t.ok('the first bathtub finish sets its best without an award', !win.tubBest);
const slower = progress.finished(4, 25, 1, 0, 2);
const faster = progress.finished(4, 18, 1, 0, 2);
t.ok('a slower bathtub run is no best; a faster one is', !slower.tubBest && faster.tubBest);
const saved = JSON.parse(store.get(SAVE_KEY)!) as { won: number; firsts: boolean[]; tubBest: (number | null)[] };
t.ok('all of it saved', saved.won === 6 && saved.firsts[4] === true && saved.tubBest[4] === 18);
// A reload: the game made again over the same storage -- the course unlocked still open, its best and mastery kept.
const reloaded = makeProgress({ getItem: (k) => store.get(k) ?? null, setItem: (k, v) => void store.set(k, v) });
t.ok('after a reload the unlock, the best and the mastery are all still there', reloaded.openCount() === 6 && reloaded.isOpen(5) && reloaded.mastered(4) && reloaded.bestTime(4) === 18);
t.done();
