/**
 * The other entrants: on each course a field of five rivals -- a rider and their homemade kart each -- have
 * already had their run when the player's comes (the player always rides last). Their times are made up, the same
 * every time for the same course: the winner's a little slower than the gold medal on the first course and closing in
 * on it as the courses go on, the rest strung out behind; now and then one of them crashed out. Each is judged as the
 * player is (`score.ts`): their kart's appeal, their style, where their time places among everyone who finished (the
 * player too, once they have), in one piece or not -- and the field is placed by those points, most first. To go on to the next course the player has to top it (`progress.ts`). In foul
 * weather they were slower too (`weather.ts`), and their points with it.
 */
import { COURSES } from './courses.ts';
import { WEATHER } from './weather.ts';
import { runPoints } from './score.ts';

/** The field and the player, placed: the rivals with their points (most first), and the player's race-time place
 * (0: no finish, or not yet ridden). */
export interface Standings {
  readonly field: readonly Rival[];
  readonly yourRace: number;
}
import { STYLE_MEDALS } from './build.ts';

export interface Rival {
  readonly rider: string;
  readonly kart: string;
  /** Its bodywork (`BODY` in `build.ts`): what it looks like, in the league table. */
  readonly body: number;
  /** Seconds, or null: crashed out. */
  readonly time: number | null;
  /** Their kart's crowd appeal (0 to 5), their style points, and whether they finished in one piece. */
  readonly appeal: number;
  readonly style: number;
  readonly whole: boolean;
  /** The judges' points for the run (`score.ts`) -- before the player rides: what the league is placed by. */
  readonly points: number;
}

/** Riders, their karts, and each kart's bodywork (`BODY`'s index): what it looks like. */
const ENTRANTS: readonly (readonly [string, string, number])[] = [
  ['Nan Babbage', 'The Tea Trolley', 2],
  ['Big Dave', 'Bedrock Bertha', 23],
  ['Lil\' Petunia', 'Taco Dynasty', 22],
  ['Captain Gravy', 'Shaken Not Stirred', 10],
  ['Sir Wobbles', 'Wheelie Good', 26],
  ['Doris Thunder', 'Couch Rocket', 3],
  ['Kevin (aged 12)', 'Mum\'s Fruit Crate', 14],
  ['The Vicar', 'Holy Roller', 6],
  ['Señor Splat', 'The Toastmaster', 7],
  ['Professor Plonk', 'Prawn Cocktail', 9],
  ['Mad Maureen', 'Shopping Spree', 2],
  ['Gary Two-Wheels', 'Fin-ished', 21],
  ['Barry the Brave', 'Plank of Destiny', 1],
  ['Auntie Vroom', 'The Crumpet', 4],
  ['Dr. Brakes', 'Slow and Steady', 5],
  ['Wendy Wheels', 'Moo-ving Target', 8],
] as const;

/** What a rival who crashed out shows instead of a time. */
export const CRASHED_OUT = 'Crashed out';

/** The field's size, and how far behind the winner each of the rest is, in shares of the gap from gold to silver. */
const FIELD = 5;
const BEHIND = [0, 0.45, 0.95, 1.5, 2.3] as const;
/** The winner, in shares of the gap from gold to silver: this far off gold on the first course (most of the way to silver:
 * the starter kart, driven well, beats it; a first-timer is among the field), this far on the last. */
const FIRST_LEADS = 0.9;
const LAST_LEADS = 0.05;
/** The rivals' crowd appeal: from this on the first course, this more a course, and up to this more by the rider. (Every
 * garage kart rates 1.2 to 4 for appeal, so the field starts in the same range: the player can't win on looks alone.) */
const APPEAL_FROM = 1.0;
const APPEAL_RISE = 0.13;
const APPEAL_SPREAD = 1.2;
/** Their style, as a share of the course's silver showmanship medal: from this, this more by the last course, and up to
 * this more by the rider. In one piece: this share of those who finish. */
const STYLE_FROM = 0.45;
const STYLE_RISE = 0.25;
const STYLE_SPREAD = 0.3;
const WHOLE = 0.6;
/** A course's style bar (`score.ts`' styleBar, by its ramps and jumps), here where the courses are designed. */
function styleBarOf(d: number): number {
  const kickers = COURSES[d]!.hazards.filter((h) => h.kind === 'ramp' || h.kind === 'jump').length;
  return Math.max(1, kickers * 0.45);
}

/** 0..1 from a pair of numbers: the same for the same pair. */
function hash(a: number, b: number): number {
  let h = Math.imul(a * 0x9e3779b1 + b * 0x85ebca6b, 0xc2b2ae35);
  h = Math.imul(h ^ (h >>> 15), 0x27d4eb2f);
  return ((h ^ (h >>> 13)) >>> 0) / 4294967296;
}

/** Each course's field, fastest first (a crashed one last), made once. */
const FIELDS: readonly (readonly Rival[])[] = COURSES.map((c, d) => {
  const [gold, silver] = c.medals;
  const gap = silver - gold;
  const lead = FIRST_LEADS + (LAST_LEADS - FIRST_LEADS) * (d / Math.max(1, COURSES.length - 1));
  // Five different entrants for this course.
  const picked: number[] = [];
  for (let n = 0; picked.length < FIELD; n++) {
    const i = Math.floor(hash(d + 1, n) * ENTRANTS.length);
    if (!picked.includes(i)) picked.push(i);
  }
  // One course in three, the slowest of them crashed out.
  const crash = hash(d + 7, 99) < 1 / 3;
  return picked.map((i, k) => {
    const [rider, kart, body] = ENTRANTS[i]!;
    const wobble = (hash(d, k + 50) - 0.5) * 0.2;
    const time = crash && k === FIELD - 1 ? null : Math.round((gold + gap * (lead + BEHIND[k]! + (k > 0 ? wobble : 0))) * 100) / 100;
    // Their kart's appeal and their style, better on the later courses; most finish in one piece.
    const appeal = Math.round(Math.min(5, APPEAL_FROM + d * APPEAL_RISE + hash(d, k + 80) * APPEAL_SPREAD) * 10) / 10;
    const style = Math.round(STYLE_MEDALS[1] * styleBarOf(d) * (STYLE_FROM + STYLE_RISE * (d / Math.max(1, COURSES.length - 1)) + hash(d, k + 90) * STYLE_SPREAD));
    const whole = time !== null && hash(d, k + 100) < WHOLE;
    return { rider, kart, body, time, appeal, style, whole, points: 0 };
  });
});

/** Each weather's fields: they rode in it too, the slower for it (`weather.ts`' slower). Their points not yet given. */
const IN_WEATHER: readonly (readonly (readonly Rival[])[])[] = WEATHER.map((w) =>
  FIELDS.map((field) => field.map((r) => ({ ...r, time: r.time === null ? null : Math.round(r.time * w.slower * 100) / 100 }))));

/** The race-time place of `time` among `times` (the others'): 1 + those faster, or level and riding before. */
function placeAmong(time: number | null, times: readonly (number | null)[]): number {
  if (time === null) return 0;
  let place = 1;
  for (const t of times) if (t !== null && t <= time) place++;
  return place;
}

/**
 * A course in a weather placed: each rival's points with their race-time place among everyone who finished -- the
 * player too, when `yourTime` is given (undefined: not ridden yet; null: no finish) -- most points first; and the
 * player's own race-time place.
 */
export function standings(course: number, weather = 0, yourTime?: number | null): Standings {
  const w = IN_WEATHER[weather] ?? IN_WEATHER[0]!;
  const base = w[Math.max(0, Math.min(w.length - 1, course))]!;
  const times = base.map((r) => r.time);
  const you = yourTime ?? null;
  const field = base.map((r, i) => {
    const others = times.filter((_, j) => j !== i);
    // A rival rode before the player: level with them, the rival is ahead.
    if (you !== null) others.push(you + 1e-6);
    return { ...r, points: runPoints(r.appeal, r.style, placeAmong(r.time, others), r.whole) };
  }).sort((a, b) => b.points - a.points);
  return { field, yourRace: placeAmong(you, times) };
}

/** The rivals on a course in a weather, before the player rides: most points first. */
export function rivalsOf(course: number, weather = 0): readonly Rival[] {
  return standings(course, weather).field;
}

/** The rival to beat on a course: its leader, most points. */
export function toBeat(course: number, weather = 0): Rival {
  return rivalsOf(course, weather)[0]!;
}

/** Where a run of `points` (its time `yourTime`, which moves the rivals' race-time points) places on a course, 1 the
 * first. A tie goes to whoever rode first. */
export function placeOf(course: number, points: number, weather = 0, yourTime?: number | null): number {
  let place = 1;
  for (const r of standings(course, weather, yourTime).field) if (r.points >= points) place++;
  return place;
}

/** Whether a run of `points` wins the course: first, ahead of every rival. */
export function wins(course: number, points: number, weather = 0, yourTime?: number | null): boolean {
  return placeOf(course, points, weather, yourTime) === 1;
}

/** What opens the next course: a finish in the top TOP_PLACES, or a finish scoring at least the course's target -- this
 * share of its leader's points (in the sunny), rounded to tens. First place is the course mastered, on top. */
export const TOP_PLACES = 3;
export const TARGET_SHARE = 0.8;
export function scoreTarget(course: number): number {
  return Math.round((toBeat(course, 0).points * TARGET_SHARE) / 10) * 10;
}
/** Which of the two a finish met, if either: 'top' (a top-three place) first, then 'score'; null for neither. */
export function unlockBy(course: number, points: number, weather = 0, yourTime?: number | null): 'top' | 'score' | null {
  if (placeOf(course, points, weather, yourTime) <= TOP_PLACES) return 'top';
  if (points >= scoreTarget(course)) return 'score';
  return null;
}
