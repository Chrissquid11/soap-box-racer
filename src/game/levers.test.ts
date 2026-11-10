/**
 * Twin brake levers (`STEERING`'s levers, `vehicle`): the front wheels stay straight, and steering left pulls the left
 * lever, braking the left rear wheel -- the kart swings left, the way handlebars would turn it, and pays for it in speed.
 */
import { RigidBody, Transform } from '@vibe/engine';
import { suite } from '@vibe/engine/testing';
import { STARTER, STEERING } from './build.ts';
import { Build, Order, Pusher } from './components.ts';
import { COURSES } from './courses.ts';
import { makeSim } from './sim.ts';

const t = suite('game: brake levers');
const check = (name: string, ok: boolean, saw: string): void => t.ok(`${name} (${saw})`, ok);

const LEVERS = STEERING.findIndex((s) => (s.levers ?? 0) > 0);
const BARS = STEERING.findIndex((s) => s.name === 'Bike handlebars');
const SPEED = 10;

const sim = await makeSim();
const { world, e, ticks } = sim;
const build = world.store(Build);
const rb = world.store(RigidBody);
const at = world.store(Transform);
const teammates = world.query({ with: [Pusher] });

ticks(1);
for (const [k, v] of Object.entries(STARTER)) (build[k as keyof typeof STARTER] as Uint8Array)[e] = v;
build.course[e] = 0;
build.open[e] = COURSES.length;

const yawOf = (): number => { const qx = at.qx[e]!, qy = at.qy[e]!, qz = at.qz[e]!, qw = at.qw[e]!; return Math.atan2(2 * (qx * qz + qw * qy), 1 - 2 * (qx * qx + qy * qy)); };
/** On `steering`, from SPEED m/s down the course, `key` held for `hold` seconds: how far it turned (signed) and how fast it goes after. */
const run = (steering: number, key: string | null, hold: number): { turned: number; speed: number } => {
  sim.release();
  build.steering[e] = steering;
  build.version[e] = build.version[e]! + 1;
  build.order[e] = Order.restart;
  ticks(0.3);
  for (let i = 0; i < teammates.count; i++) world.store(Pusher).push[teammates.members[i]!] = 0;
  ticks(3.5);
  ticks(2, sim.autopilot);
  sim.release();
  const qx = at.qx[e]!, qy = at.qy[e]!, qz = at.qz[e]!, qw = at.qw[e]!;
  const fx = 2 * (qx * qz + qw * qy), fz = 1 - 2 * (qx * qx + qy * qy);
  rb.velocityX[e] = fx * SPEED;
  rb.velocityZ[e] = fz * SPEED;
  const yaw0 = yawOf();
  if (key) world.loop.input.edge(key, true);
  ticks(hold);
  if (key) world.loop.input.edge(key, false);
  const d = yawOf() - yaw0;
  return { turned: Math.atan2(Math.sin(d), Math.cos(d)), speed: Math.hypot(rb.velocityX[e]!, rb.velocityZ[e]!) };
};

check('there are twin brake levers', LEVERS >= 0, `steering ${LEVERS}`);
const bars = run(BARS, 'KeyA', 0.6);
const left = run(LEVERS, 'KeyA', 0.6);
const right = run(LEVERS, 'KeyD', 0.6);
const straight = run(LEVERS, null, 0.6);
const deg = (r: number): string => (r * 57.3).toFixed(0);
check('the left lever swings it left, as handlebars turn it -- and sharper (hairpins)', Math.sign(left.turned) === Math.sign(bars.turned) && Math.abs(left.turned) > Math.abs(bars.turned) * 1.2,
  `levers ${deg(left.turned)} deg, bars ${deg(bars.turned)} deg`);
check('the right lever swings it the other way', Math.sign(right.turned) === -Math.sign(left.turned) && Math.abs(right.turned) > 0.15, `${deg(right.turned)} deg`);
check('hands off, it runs straight', Math.abs(straight.turned) < 0.08, `${deg(straight.turned)} deg`);
check('every turn costs speed, more than handlebars', left.speed < straight.speed - 0.5 && left.speed < bars.speed, `after the turn ${left.speed.toFixed(1)} m/s, bars ${bars.speed.toFixed(1)} m/s, straight ${straight.speed.toFixed(1)} m/s`);
t.done();
