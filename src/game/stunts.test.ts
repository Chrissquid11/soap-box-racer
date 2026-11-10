/**
 * Showmanship stunts (`systems/stunts.ts`) in a race, physics on (`sim.ts`): a chicane gone through is judged clean
 * or touched, and scores only clean; over the line facing back up the hill is a reverse finish; one wheel gone over
 * it, limped home; R forgets every stunt.
 */
import { RigidBody, Transform } from '@vibe/engine';
import { suite } from '@vibe/engine/testing';
import { STARTER } from './build.ts';
import { Build, Chicane, Kart, News, Order, Phase, Wheel } from './components.ts';
import { COURSES, TRACKS } from './courses.ts';
import { headingAt } from './track.ts';
import { makeSim } from './sim.ts';

const t = suite('game: stunts');
const check = (name: string, ok: boolean, saw: string): void => t.ok(`${name} (${saw})`, ok);

const sim = await makeSim();
const { world, e, ticks } = sim;
const kart = world.store(Kart);
const build = world.store(Build);
const rb = world.store(RigidBody);
const at = world.store(Transform);
const wheel = world.store(Wheel);
const wheels = world.query({ with: [Wheel] });
const walls = world.query({ with: [Chicane] });

const fresh = (course: number): void => {
  sim.release();
  for (const [k, v] of Object.entries(STARTER)) (build[k as keyof typeof STARTER] as Uint8Array)[e] = v;
  build.version[e] = build.version[e]! + 1;
  build.course[e] = course;
  build.open[e] = COURSES.length;
  build.order[e] = Order.restart;
  ticks(0.3);
  ticks(3.2);
};
/** Set down at sample `s` of the course, `back` facing up the hill or not, rolling down it at `speed`. */
const place = (s: number, back: boolean, speed: number): void => {
  const tr = TRACKS[kart.course[e]!]!;
  const h = headingAt(tr, s) + (back ? Math.PI : 0);
  at.px[e] = tr.sx[s]!;
  at.py[e] = tr.sy[s]! + kart.rideY[e]! + 0.15;
  at.pz[e] = tr.sz[s]!;
  at.qx[e] = 0; at.qy[e] = Math.sin(h / 2); at.qz[e] = 0; at.qw[e] = Math.cos(h / 2);
  rb.velocityX[e] = tr.tx[s]! * speed; rb.velocityY[e] = 0; rb.velocityZ[e] = tr.tz[s]! * speed;
  rb.angularVelocityX[e] = rb.angularVelocityY[e] = rb.angularVelocityZ[e] = 0;
  kart.progress[e] = s;
  kart.lastProgress[e] = s;
};

ticks(1);

// The first course with chicanes. Driven down it: each chicane passed is judged, and scores only clean.
let course = 0;
for (; course < COURSES.length; course++) {
  fresh(course);
  if (walls.count > 0) break;
}
const count = new Set<number>();
for (let i = 0; i < walls.count; i++) count.add(world.store(Chicane).index[walls.members[i]!]!);
// Set down rolling a little before the first chicane: the test is of the judging, not of surviving the course before it.
{
  const tr = TRACKS[course]!;
  let first = tr.samples - 1;
  for (let i = 0; i < walls.count; i++) {
    const w = walls.members[i]!;
    let best = 0, bd = Infinity;
    for (let j = 0; j < tr.samples; j++) {
      const d = Math.hypot(tr.sx[j]! - at.px[w]!, tr.sz[j]! - at.pz[w]!);
      if (d < bd) { bd = d; best = j; }
    }
    first = Math.min(first, best);
  }
  let from = first, run = 0;
  while (from > 1 && run < 30) { run += Math.hypot(tr.sx[from]! - tr.sx[from - 1]!, tr.sz[from]! - tr.sz[from - 1]!); from--; }
  place(from, false, 8);
}
let cleanShouts = 0, lastAt = -1;
let s = 0;
while (kart.phase[e] !== Phase.finished && kart.phase[e] !== Phase.over && s < 150 * 60) {
  ticks(1 / 60, sim.autopilot);
  s++;
  if (kart.news[e] === News.cleanChicane && kart.newsAt[e] !== lastAt) { cleanShouts++; lastAt = kart.newsAt[e]!; }
}
sim.release();
const done = kart.chicaneDone[e]!, hit = kart.chicaneHits[e]!;
let clean = 0, passed = 0;
for (const c of count) if (done & (1 << c)) { passed++; if (!(hit & (1 << c))) clean++; }
check('a course with chicanes has them, and each one gone through is judged', count.size > 0 && passed === count.size,
  `course ${course + 1}: ${count.size} chicanes, ${passed} passed, phase ${kart.phase[e]} after ${(s / 60).toFixed(0)} s, at ${kart.progress[e]!.toFixed(0)}, cause ${kart.cause[e]}, out ${kart.out[e]}`);
check('only a clean chicane scores', cleanShouts === clean, `${clean} clean (touched bits ${hit}), ${cleanShouts} shouted`);

// Over the line facing backwards: a reverse finish.
fresh(0);
const tr = TRACKS[0]!;
place(tr.finish - 6, true, 6);
const style0 = kart.style[e]!;
ticks(2.5);
check('over the line facing back up the hill is a reverse finish', kart.phase[e] === Phase.finished && kart.style[e]! >= style0 + 300,
  `phase ${kart.phase[e]}, news ${kart.news[e]}, style ${style0} -> ${kart.style[e]}`);

// Over it facing the right way with a wheel gone: limped home.
fresh(0);
for (let i = 0; i < wheels.count; i++) {
  const w = wheels.members[i]!;
  if (wheel.corner[w] === 3) { wheel.attached[w] = 0; wheel.state[w] = 2; }
}
kart.wheelsLost[e] = 1;
place(tr.finish - 6, false, 8);
ticks(6, sim.autopilot);
sim.release();
check('over the line with a wheel gone, it limped home', kart.phase[e] === Phase.finished && kart.news[e] === News.limpedHome,
  `phase ${kart.phase[e]}, news ${kart.news[e]}, style ${kart.style[e]}`);

// Spun round on its wheels: a 360 for each whole turn.
fresh(0);
const mid = tr.start + 40;
place(mid, false, 0);
ticks(0.4);
let spins = 0, lastSpinAt = -1;
ticks(1.6, () => {
  rb.angularVelocityY[e] = 7;
  if (kart.news[e] === News.spin && kart.newsAt[e] !== lastSpinAt) { spins++; lastSpinAt = kart.newsAt[e]!; }
});
check('spun round on its wheels, each whole turn is a 360', spins >= 1, `${spins} spins shouted, style ${kart.style[e]}, air ${kart.air[e]!.toFixed(2)}`);

// Rolled backwards for a good while: reversing, scored as it stops.
fresh(0);
place(mid, true, 6);
let reversed = false;
ticks(2.6, () => {
  rb.velocityX[e] = tr.tx[mid]! * 6;
  rb.velocityZ[e] = tr.tz[mid]! * 6;
});
ticks(0.6, () => {
  rb.velocityX[e] = rb.velocityZ[e] = 0;
  if (kart.news[e] === News.reversing) reversed = true;
});
check('rolled backwards two seconds or more: reversing scores', reversed, `news ${kart.news[e]}, style ${kart.style[e]}, phase ${kart.phase[e]}`);

// R: every stunt forgotten.
build.order[e] = Order.restart;
ticks(0.5);
check('R forgets every stunt', kart.style[e] === 0 && kart.chicaneDone[e] === 0 && kart.chicaneHits[e] === 0 && kart.repeats[e] === 0 && !kart.finishJudged[e],
  `style ${kart.style[e]}, chicanes ${kart.chicaneDone[e]}/${kart.chicaneHits[e]}, judged ${kart.finishJudged[e]}`);
t.done();
