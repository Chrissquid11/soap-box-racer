/**
 * The rivals (`rivals.ts`): every course has five different entrants, placed by the judges' points (`score.ts`), most
 * first, their winner's time between gold and bronze; a run is placed among them by its points; and the first course
 * can be won -- the autopilot in the starter kart outscores its leader (`sim.ts`), so nobody is stuck on it.
 */
import { suite } from '@vibe/engine/testing';
import { newRating, rate, STARTER } from './build.ts';
import { runPoints } from './score.ts';
import { Build, Kart, Order, Phase } from './components.ts';
import { COURSES } from './courses.ts';
import { placeOf, rivalsOf, standings, toBeat, wins } from './rivals.ts';
import { makeSim } from './sim.ts';

const t = suite('game: rivals');
const check = (name: string, ok: boolean, saw: string): void => t.ok(`${name} (${saw})`, ok);

let fields = true, why = '';
for (let c = 0; c < COURSES.length; c++) {
  const rs = rivalsOf(c);
  const [gold, silver] = COURSES[c]!.medals;
  const names = new Set(rs.map((r) => r.rider));
  const sorted = rs.every((r, i) => i === 0 || r.points <= rs[i - 1]!.points);
  const fastest = Math.min(...rs.map((r) => r.time ?? Infinity));
  if (rs.length !== 5 || names.size !== 5 || !sorted || fastest < gold || fastest > COURSES[c]!.medals[2]) {
    fields = false;
    why += ` course ${c + 1}: ${rs.map((r) => `${r.rider} ${r.points} pts ${r.time}`).join(', ')} (gold ${gold}, silver ${silver}, bronze ${COURSES[c]!.medals[2]});`;
  }
}
check('every course has five different rivals, most points first, the fastest between gold and bronze', fields, why || 'all good');

const lead = toBeat(0).points;
check('a run is placed among them by its points', placeOf(0, lead + 1) === 1 && placeOf(0, lead) === 2 && placeOf(0, 0) === 6 && wins(0, lead + 50) && !wins(0, lead - 50),
  `lead ${lead}: just over ${placeOf(0, lead + 1)}, level ${placeOf(0, lead)}, none ${placeOf(0, 0)}`);

// The first course is winnable: the starter kart, the autopilot at the keys.
const sim = await makeSim();
const { world, e, ticks } = sim;
const kart = world.store(Kart);
const build = world.store(Build);
ticks(1);
for (const [k, v] of Object.entries(STARTER)) (build[k as keyof typeof STARTER] as Uint8Array)[e] = v;
build.version[e] = build.version[e]! + 1;
build.course[e] = 0;
build.open[e] = COURSES.length;
build.order[e] = Order.restart;
ticks(0.5);
let s = 0;
while (kart.phase[e] !== Phase.finished && kart.phase[e] !== Phase.over && s < 120) {
  ticks(1, sim.autopilot);
  s++;
}
sim.release();
const time = kart.phase[e] === Phase.finished ? kart.finishTime[e]! : null;
const rating = newRating();
rate(STARTER, rating);
const whole = kart.wheelsLost[e] === 0 && kart.bodyLost[e] === 0 && kart.ejections[e] === 0;
const race = standings(0, 0, time).yourRace;
const points = runPoints(rating.appeal, kart.style[e]!, race, whole);
check('the first course can be won in the starter kart', time !== null && wins(0, points, 0, time), `the autopilot ${time?.toFixed(2) ?? 'did not finish'} s, ${points} pts (race place ${race}, style ${Math.round(kart.style[e]!)}, appeal ${rating.appeal}, whole ${whole}), the leader ${lead} pts`);
t.done();
