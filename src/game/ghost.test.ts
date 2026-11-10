/**
 * The rival ghost (`systems/ghost.ts`, `ghost-runs.ts`, physics on, `sim.ts`): on the first course in the sunny a
 * ghost rides with the kart, on the race clock -- where its recording says at each moment, standing at its finish
 * from its finish time on (the time the HUD shows) -- and it has no body to collide with; on a course with no
 * recording, none.
 */
import { type Entity, RigidBody, Transform } from '@vibe/engine';
import { suite } from '@vibe/engine/testing';
import { Build, Ghost, Kart, Order } from './components.ts';
import { GHOST_RUNS } from './ghost-runs.ts';
import { ghostAt, ghostFor, GHOSTS_ON } from './systems/ghost.ts';
import { makeSim } from './sim.ts';

const t = suite('game: the rival ghost');
const sim = await makeSim();
const { world, e } = sim;
const kart = world.store(Kart), build = world.store(Build), at = world.store(Transform);
const ghosts = world.query({ with: [Ghost] });
const want = new Float64Array(7);

if (!GHOSTS_ON) {
  // The ghosts switched off: none fits, none rides.
  build.course[e] = 0;
  build.open[e] = 20;
  sim.ticks(0.2);
  build.order[e] = Order.race;
  sim.ticks(3);
  t.ok('the ghosts off: no recording is used and no ghost rides', ghostFor(0, 0) < 0 && ghosts.count === 0);
  t.done();
  process.exit(0);
}
const which = ghostFor(0, 0);
t.ok('a recording fits the first course in the sunny: Granny\'s', which >= 0 && GHOST_RUNS[which]!.name === 'Granny');
build.course[e] = 0;
build.open[e] = 20;
sim.ticks(0.2);
build.order[e] = Order.race;
sim.ticks(0.3);
kart.weather[e] = 0;
sim.ticks(5);
const g = ghosts.count ? ghosts.members[0]! : -1;
let worst = 0;
const run = GHOST_RUNS[which]!;
sim.ticks(6, () => {
  if (g < 0) return;
  ghostAt(run, Math.max(0, kart.clock[e]!), want);
  worst = Math.max(worst, Math.hypot(at.px[g]! - want[0]!, at.py[g]! - want[1]!, at.pz[g]! - want[2]!));
});
t.ok(`one ghost rides, on the race clock (worst ${worst.toFixed(3)} m off its recording)`, ghosts.count === 1 && worst < 0.5);
t.ok('it has no body: nothing collides with it', g >= 0 && !world.has(g as Entity, RigidBody));
ghostAt(run, run.finish + 5, want);
const end = new Float64Array(7);
ghostAt(run, run.finish, end);
t.ok(`it stands at its finish from its finish time on (${run.finish} s, the time the HUD shows)`, Math.hypot(want[0]! - end[0]!, want[2]! - end[2]!) < 1e-6);
t.ok('no recording on the second course: no ghost', ghostFor(1, 0) < 0);
t.done();
