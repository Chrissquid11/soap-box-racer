/**
 * The balance the garage, the medals and the rivals are tuned to (no physics: the numbers alone, fast): the crowd
 * loves the hard-to-drive karts and Crate Expectations least of the themed ones; the starter plank slides before it
 * rolls, near enough; every course's medals are in order and its rivals' times bracket them -- the winner between
 * gold and silver, the field out past bronze or near it; and the field's crowd appeal starts in the garage's range.
 */
import { suite } from '@vibe/engine/testing';
import { BODY, newRating, rate, STARTER } from './build.ts';
import { COURSES, TYRE_GRIP } from './courses.ts';
import { rivalsOf } from './rivals.ts';

const t = suite('game: balance');
const r = newRating();

// Appeal: every themed kart with a look of 5 out-appeals Crate Expectations, each on the chassis it comes on.
const appealOf = (body: number): number => rate({ ...STARTER, chassis: BODY[body]!.on ?? 1, body }, r).appeal;
const crate = BODY.findIndex((b) => b.name === 'Crate Expectations');
const crateAppeal = appealOf(crate);
const duller = BODY.map((b, i) => [b, i] as const).filter(([b, i]) => b.natural && b.appeal === 5 && appealOf(i) <= crateAppeal).map(([b]) => b.name);
t.ok(`Crate Expectations (${crateAppeal.toFixed(2)}) is the crowd's least favourite themed kart${duller.length ? ` -- not: ${duller.join(', ')}` : ''}`, duller.length === 0);

// The starter: wide enough on its wheels that it slides near where it would tip (TYRE_GRIP), not well before.
rate(STARTER, r);
t.ok(`the starter's tipping point (${r.tip.toFixed(2)} g) is within 5% of the tyres' grip (${TYRE_GRIP} g)`, r.tip >= TYRE_GRIP * 0.95);

// Every course: medals in order, the rivals' winner between gold and silver, their slowest finisher past silver.
let why = '';
for (let c = 0; c < COURSES.length; c++) {
  const [gold, silver, bronze] = COURSES[c]!.medals;
  const times = rivalsOf(c).map((x) => x.time).filter((x): x is number => x !== null).sort((a, b) => a - b);
  if (!(gold < silver && silver < bronze) || times[0]! < gold || times[0]! > silver || times[times.length - 1]! <= silver) {
    why += ` ${c + 1}: ${gold}/${silver}/${bronze} rivals ${times.join(' ')};`;
  }
}
t.ok(`every course's medals in order, its rivals bracketing them${why}`, why === '');

// The field's appeal on the first course starts where the garage's karts do (the starter rates about 2).
const firstAppeal = rivalsOf(0).map((x) => x.appeal);
t.ok(`the first course's rivals rate 1 to 2.5 for appeal (${firstAppeal.join(', ')})`, Math.min(...firstAppeal) >= 1 && Math.max(...firstAppeal) <= 2.5);
t.done();
