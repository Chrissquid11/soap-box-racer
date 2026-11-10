/**
 * The side kickers (`courses.ts`' layKickers, `course`' bonuses), physics on (`sim.ts`): every course has a few, each
 * over part of the road only, hard against an edge, with room to drive past; and on the first course, a kart driven
 * straight at one at a fair lick flies off it and collects the star past its lip -- while one driven straight down
 * the road beside it, past the same place, does not.
 */
import { RigidBody, Transform } from '@vibe/engine';
import { suite } from '@vibe/engine/testing';
import { STARTER } from './build.ts';
import { Bonus, Build, Kart, Order, Phase } from './components.ts';
import { COURSES, TRACKS } from './courses.ts';
import { headingAt } from './track.ts';
import { makeSim } from './sim.ts';

const t = suite('game: side kickers');
const check = (name: string, ok: boolean, saw: string): void => t.ok(`${name} (${saw})`, ok);

// Every course: some, each leaving a lane clear beside it.
const counts = COURSES.map((c) => c.hazards.filter((h) => h.kind === 'kicker').length);
// The lane left beside each, metres: the road's width less the kicker's and its gap to the edge.
let tightest = Infinity;
COURSES.forEach((c, i) => {
  for (const h of c.hazards) if (h.kind === 'kicker') tightest = Math.min(tightest, TRACKS[i]!.hw[h.sample]! + Math.abs(h.across) - (h.width * 10) / 2);
});
check('every course has side kickers, each leaving room to drive past', counts.every((n) => n >= 1) && tightest > 2,
  `${counts.join(' ')} a course; the narrowest lane left beside one ${tightest.toFixed(1)} m`);

const sim = await makeSim();
const { world, e, ticks } = sim;
const kart = world.store(Kart);
const build = world.store(Build);
const rb = world.store(RigidBody);
const at = world.store(Transform);
const star = world.store(Bonus);
const stars = world.query({ with: [Bonus] });

const fresh = (): void => {
  sim.release();
  for (const [k, v] of Object.entries(STARTER)) (build[k as keyof typeof STARTER] as Uint8Array)[e] = v;
  build.version[e] = build.version[e]! + 1;
  build.course[e] = 0;
  build.open[e] = COURSES.length;
  build.order[e] = Order.restart;
  ticks(0.3);
  ticks(3.5);
};
const tr = TRACKS[0]!;
const kick = COURSES[0]!.hazards.find((h) => h.kind === 'kicker')!;
/** Set down `back` samples before the kicker, `across` the road, rolling straight down it at `speed`. */
const place = (across: number, back: number, speed: number): void => {
  const s = kick.sample - back;
  const h = headingAt(tr, s);
  at.px[e] = tr.sx[s]! - tr.tz[s]! * across;
  at.py[e] = tr.sy[s]! + kart.rideY[e]! + 0.15;
  at.pz[e] = tr.sz[s]! + tr.tx[s]! * across;
  at.qx[e] = 0; at.qy[e] = Math.sin(h / 2); at.qz[e] = 0; at.qw[e] = Math.cos(h / 2);
  rb.velocityX[e] = tr.tx[s]! * speed; rb.velocityY[e] = 0; rb.velocityZ[e] = tr.tz[s]! * speed;
  rb.angularVelocityX[e] = rb.angularVelocityY[e] = rb.angularVelocityZ[e] = 0;
  kart.progress[e] = s;
  kart.lastProgress[e] = s;
};
/** The kicker's own star: the first past it along the road, over its line (its `across`). */
const kickStar = (): number => {
  let best = 0, first = Infinity;
  for (let i = 0; i < stars.count; i++) {
    const b = stars.members[i]!;
    let near = 0, nd = Infinity;
    for (let j = 0; j < tr.samples; j++) {
      const d = Math.hypot(tr.sx[j]! - at.px[b]!, tr.sz[j]! - at.pz[b]!);
      if (d < nd) { nd = d; near = j; }
    }
    const across = -(at.px[b]! - tr.sx[near]!) * tr.tz[near]! + (at.pz[b]! - tr.sz[near]!) * tr.tx[near]!;
    if (near > kick.sample && near < first && Math.abs(across - kick.across) < 0.6) { first = near; best = b; }
  }
  return best;
};
const drive = (across: number): { got: boolean; peak: number; phase: number } => {
  fresh();
  place(across, 5, 13);
  const b = kickStar();
  let peak = 0;
  for (let n = 0; n < 240; n++) {
    ticks(1 / 60, () => sim.release());
    peak = Math.max(peak, kart.air[e]!);
    if (b && star.taken[b]) return { got: true, peak, phase: kart.phase[e]! };
  }
  return { got: b !== 0 && star.taken[b] === 1, peak, phase: kart.phase[e]! };
};
const on = drive(kick.across);
const past = drive(0);
check('straight at a side kicker: off it and into its star', on.got, `star ${on.got ? 'collected' : 'missed'}, ${on.peak.toFixed(2)} s in the air, phase ${on.phase}`);
check('straight down the road beside it: the star stays', !past.got && past.phase === Phase.racing, `star ${past.got ? 'collected' : 'left'}, phase ${past.phase}`);
t.done();
