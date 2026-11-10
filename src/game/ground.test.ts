/**
 * Never through the ground (`race`), physics on (`sim.ts`): a kart that has somehow slipped under the course -- mid
 * race, on the grid -- is found under it and set back on top straight away, still in its run.
 */
import { RigidBody, Transform } from '@vibe/engine';
import { suite } from '@vibe/engine/testing';
import { Build, Kart, Order, Phase } from './components.ts';
import { TRACKS } from './courses.ts';
import { makeSim } from './sim.ts';

const t = suite('game: never through the ground');
const check = (name: string, ok: boolean, saw: string): void => t.ok(`${name} (${saw})`, ok);

const sim = await makeSim();
const { world, e, ticks } = sim;
const kart = world.store(Kart);
const build = world.store(Build);
const at = world.store(Transform);
const rb = world.store(RigidBody);
const tr = TRACKS[0]!;

/** Sunk `deep` metres under the road at sample `s`, falling; then a moment. Where it ends up over the road there. */
const sink = (s: number, deep: number): number => {
  at.px[e] = tr.sx[s]!;
  at.pz[e] = tr.sz[s]!;
  at.py[e] = tr.sy[s]! - deep;
  rb.velocityY[e] = -6;
  kart.progress[e] = s;
  ticks(0.3);
  return at.py[e]! - tr.sy[s]!;
};

ticks(1);
build.order[e] = Order.restart;
ticks(0.5);
const onGrid = sink(tr.start - 3, 5);
const gridPhase = kart.phase[e];
check('slipped under the road on the grid, it is back on top at once', onGrid > -0.5, `${onGrid.toFixed(2)} m over the road, phase ${gridPhase}`);

ticks(4);
const mid = tr.start + 40;
const racing = sink(mid, 6);
check('slipped under the road mid race, it is back on top at once and still racing', racing > -0.5 && kart.phase[e] === Phase.racing,
  `${racing.toFixed(2)} m over the road, phase ${kart.phase[e]}, out ${kart.out[e]}`);
t.done();
