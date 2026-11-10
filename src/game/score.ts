/**
 * A run's points, the same for the player (`race-hud.ts`' results) and the rivals (`rivals.ts`): the judges' three
 * pillars -- creativity (the kart's crowd appeal), showmanship (style points: stunts and bonuses) and race time (where
 * the time places among everyone who finished: 1st the most) -- and a bonus for over the line in one piece. The
 * league is placed by these points.
 */
import { STYLE_MEDALS } from './build.ts';
import { COURSES } from './courses.ts';

/** Creativity: crowd appeal (0 to 5) as points, and the points each medal asks (gold, silver, bronze). */
export const CREATIVITY_POINTS = 100;
export const CREATIVITY_MEDALS = [400, 260, 140] as const;
/** Race time: the points for 1st, 2nd, 3rd ... among those who finished (the player and the rivals); none for no finish. */
export const RACE_POINTS = [400, 300, 220, 160, 110, 70] as const;
/** Over the line in one piece -- every wheel on, the bodywork on, never thrown out. */
export const ONE_PIECE = 300;

/** How much more style a course's showmanship medals ask: its ramps and jumps, more to score on. */
export function styleBar(course: number): number {
  const c = COURSES[Math.max(0, Math.min(COURSES.length - 1, course))]!;
  const kickers = c.hazards.filter((h) => h.kind === 'ramp' || h.kind === 'jump').length;
  return Math.max(1, kickers * 0.45);
}

/** The showmanship medal limits on a course (gold, silver, bronze style points). */
export function styleMedals(course: number): [number, number, number] {
  const bar = styleBar(course);
  return [STYLE_MEDALS[0] * bar, STYLE_MEDALS[1] * bar, STYLE_MEDALS[2] * bar];
}

/** The race-time points for finishing `place` (1 the fastest); 0 for no finish (place 0). */
export function racePoints(place: number): number {
  if (place < 1) return 0;
  return RACE_POINTS[Math.min(RACE_POINTS.length - 1, place - 1)]!;
}

/** A run's points: crowd appeal 0..5, style points, its race-time place (0: did not finish), and whether in one piece. */
export function runPoints(appeal: number, style: number, racePlace: number, whole: boolean): number {
  return Math.round(appeal * CREATIVITY_POINTS) + Math.round(style) + racePoints(racePlace) + (racePlace > 0 && whole ? ONE_PIECE : 0);
}
