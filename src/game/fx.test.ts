/**
 * The effects (`systems/fx.ts`) are made: driving down the first course (`sim.ts`, physics on, the autopilot) throws
 * dust off the wheels and lays skid marks -- puffs and marks alive in the world -- and a landing kicks up a ring of
 * dust. (Its trails system once had no members at all -- its wheel writes made `Wheel` required of the kart itself --
 * and not a puff was seen.)
 */
import { suite } from '@vibe/engine/testing';
import { STARTER } from './build.ts';
import { Build, Fx, Kart, Order, Spark, Wheel } from './components.ts';
import { COURSES } from './courses.ts';
import { makeSim } from './sim.ts';

const t = suite('game: effects');
const check = (name: string, ok: boolean, saw: string): void => t.ok(`${name} (${saw})`, ok);

const sim = await makeSim();
const { world, e, ticks } = sim;
const kart = world.store(Kart);
const build = world.store(Build);
const fx = world.query({ with: [Fx] });
const sparkQ = world.query({ with: [Spark] });
const wheel = world.store(Wheel);
const wheels = world.query({ with: [Wheel] });

ticks(1);
for (const [k, v] of Object.entries(STARTER)) (build[k as keyof typeof STARTER] as Uint8Array)[e] = v;
build.version[e] = build.version[e]! + 1;
build.course[e] = 0;
build.open[e] = COURSES.length;
build.order[e] = Order.restart;
ticks(0.3);
let most = 0;
ticks(9, () => {
  sim.autopilot();
  most = Math.max(most, fx.count);
});
sim.release();
check('driving down the course throws dust and lays marks', most >= 10, `${most} effects alive at once, at ${kart.speed[e]!.toFixed(1)} m/s`);
// A wheel gone: its bare axle drags on the road, throwing sparks.
build.order[e] = Order.restart;
ticks(0.3);
for (let i = 0; i < wheels.count; i++) if (wheel.corner[wheels.members[i]!] === 3) wheel.attached[wheels.members[i]!] = 0;
let sparked = 0;
ticks(8, () => {
  sim.autopilot();
  sparked = Math.max(sparked, sparkQ.count);
});
sim.release();
check('a lost wheel\'s axle dragging on the road throws sparks', sparked > 0, `${sparked} sparks alive at once, at ${kart.speed[e]!.toFixed(1)} m/s`);
t.done();
