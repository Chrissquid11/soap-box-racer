/**
 * The player's progress through the courses, as kept between sessions -- in whatever storage it is given (the page's
 * localStorage, through `ui/progress.ts`; a stand-in in the tests): the best time on each, and how many are open. The
 * first is open from the start; each after opens once the one before it is finished in the top three, or with at least
 * its score target (`rivals.ts`' unlockBy). First place on a course is kept too (mastered), and the best time in the
 * bathtub on each (the Fastest Bathtub award). An older save's open courses stay open. Plain data; no world.
 */
import { COURSES } from './courses.ts';
import { placeOf, unlockBy } from './rivals.ts';

/** Where it is kept: a key's text (none given: progress lasts the session). */
export interface SaveStore {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
}

export const SAVE_KEY = 'downhill-mayhem/progress';

/** How many are open, as the races opened them: the first at least. */
function openFrom(won: number): number {
  return Math.max(1, Math.min(COURSES.length, won));
}

interface Saved {
  /** How many courses are open. */
  open: number;
  best: (number | null)[];
  /** Each course won outright (first place): mastered. */
  firsts: boolean[];
  /** Each course's best time in the bathtub chassis, or null. */
  tubBest: (number | null)[];
}

/** What a finish did: a new best time; the next course opened, and by which condition (or none met); its place; a
 * first win of the course; and, in the bathtub, a new best for it (the first bathtub finish only sets one). */
export interface Finish {
  best: boolean;
  opened: boolean;
  by: 'top' | 'score' | null;
  place: number;
  mastered: boolean;
  tubBest: boolean;
}

/** The bathtub's chassis (`build.ts`' CHASSIS). */
const BATHTUB = 2;

/** The progress kept in `storage` (null: none), read from it now. */
export function makeProgress(storage: SaveStore | null): {
  isOpen(course: number): boolean;
  bestTime(course: number): number | null;
  timeMedal(course: number, time: number): number;
  bestMedal(course: number): number | null;
  finished(course: number, time: number, points: number, weather?: number, chassis?: number): Finish;
  mastered(course: number): boolean;
  unlockAll(): void;
  /** Every course locked again but the first, every best time and first place forgotten: a new game. */
  resetAll(): void;
  openCount(): number;
} {
  const fresh = (): Saved => ({ open: 1, best: COURSES.map(() => null), firsts: COURSES.map(() => false), tubBest: COURSES.map(() => null) });
  const load = (): Saved => {
    if (!storage) return fresh();
    try {
      const raw = JSON.parse(storage.getItem(SAVE_KEY) ?? 'null') as Partial<Saved> | null;
      if (!raw) return fresh();
      const best = COURSES.map((_, i) => (typeof raw.best?.[i] === 'number' ? raw.best[i]! : null));
      // (`won` is how many the races opened: an older save's stay open.)
      const won = typeof (raw as { won?: unknown }).won === 'number' ? (raw as { won: number }).won : 1;
      const firsts = COURSES.map((_, i) => raw.firsts?.[i] === true);
      const tubBest = COURSES.map((_, i) => (typeof raw.tubBest?.[i] === 'number' ? raw.tubBest[i]! : null));
      return { open: openFrom(won), best, firsts, tubBest };
    } catch {
      return fresh();
    }
  };
  const saved = load();
  const store = (): void => {
    if (!storage) return;
    try {
      storage.setItem(SAVE_KEY, JSON.stringify({ won: saved.open, best: saved.best, firsts: saved.firsts, tubBest: saved.tubBest }));
    } catch {
      // A full or blocked storage: progress lasts the session.
    }
  };
  const bestTime = (course: number): number | null => saved.best[course] ?? null;
  const timeMedal = (course: number, time: number): number => {
    const limits = COURSES[course]!.medals;
    for (let i = 0; i < 3; i++) if (time <= limits[i]!) return i;
    return 3;
  };
  return {
    isOpen: (course) => course < saved.open,
    bestTime,
    timeMedal,
    bestMedal: (course) => {
      const best = bestTime(course);
      return best == null ? null : timeMedal(course, best);
    },
    finished: (course, time, points, weather = 0, chassis = -1) => {
      let best = false;
      const was = saved.best[course];
      if (was == null || time < was) {
        saved.best[course] = time;
        best = true;
      }
      const by = unlockBy(course, points, weather, time);
      const wasOpen = saved.open;
      if (by) saved.open = Math.max(saved.open, Math.min(COURSES.length, course + 2));
      const place = placeOf(course, points, weather, time);
      const mastered = place === 1 && !saved.firsts[course];
      if (place === 1) saved.firsts[course] = true;
      // The bathtub's best: its first finish sets it (no award yet); after that, only a faster one beats it.
      let tubBest = false;
      if (chassis === BATHTUB) {
        const tub = saved.tubBest[course];
        if (tub == null) saved.tubBest[course] = time;
        else if (time < tub) {
          saved.tubBest[course] = time;
          tubBest = true;
        }
      }
      store();
      return { best, opened: saved.open > wasOpen, by, place, mastered, tubBest };
    },
    mastered: (course) => saved.firsts[course] === true,
    unlockAll: () => {
      saved.open = COURSES.length;
      store();
    },
    resetAll: () => {
      Object.assign(saved, fresh());
      store();
    },
    openCount: () => saved.open,
  };
}
