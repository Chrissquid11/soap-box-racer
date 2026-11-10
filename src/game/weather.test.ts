/**
 * The weather (`weather.ts`) changes how the course handles (`sim.ts`, physics on): on snow the same steer turns less --
 * wider (less grip), and a crosswind pushes a kart running hands-off sideways. And it is dealt each visit to a
 * course's garage: the first course's first visit always sunny, kept through a restart.
 */
import { RigidBody, Transform } from '@vibe/engine';
import { suite } from '@vibe/engine/testing';
import { STARTER } from './build.ts';
import { Build, Kart, Order, Phase, Pusher } from './components.ts';
import { COURSES } from './courses.ts';
import { makeSim } from './sim.ts';
import { Weather } from './weather.ts';

const t = suite('game: weather');
const check = (name: string, ok: boolean, saw: string): void => t.ok(`${name} (${saw})`, ok);

const sim = await makeSim();
const { world, e, ticks } = sim;
const kart = world.store(Kart);
const build = world.store(Build);
const rb = world.store(RigidBody);
const at = world.store(Transform);
const teammates = world.query({ with: [Pusher] });

ticks(1);
for (const [k, v] of Object.entries(STARTER)) (build[k as keyof typeof STARTER] as Uint8Array)[e] = v;
build.version[e] = build.version[e]! + 1;
build.course[e] = 0;
build.open[e] = COURSES.length;
build.order[e] = Order.garage;
ticks(0.5);
check('the first course, first visit: sunny', kart.weather[e] === Weather.sunny, `weather ${kart.weather[e]}`);

/** A fresh run in `weather`, driven `drive` seconds by the autopilot, then hands off for `coast`: how far it slid
 * sideways (m/s across its nose, at its worst) and how far across the world it ended up from where it was. */
/** The speed the hard turn starts from, m/s. */
const TURN_SPEED = 11;
const yawOf = (): number => { const qx = at.qx[e]!, qy = at.qy[e]!, qz = at.qz[e]!, qw = at.qw[e]!; return Math.atan2(2 * (qx * qz + qw * qy), 1 - 2 * (qx * qx + qy * qy)); };
const run = (weather: number, drive: number, coast: number, steer: boolean): { slide: number; turned: number; x: number; z: number } => {
  sim.release();
  build.order[e] = Order.restart;
  ticks(0.3);
  kart.weather[e] = weather;
  // (No teammate's shove: the same start each time.)
  for (let i = 0; i < teammates.count; i++) world.store(Pusher).push[teammates.members[i]!] = 0;
  ticks(3.5);
  ticks(drive, sim.autopilot);
  sim.release();
  let slide = 0;
  const yaw0 = yawOf();
  // A hard turn, full lock, from the same speed whatever the weather: how far it slides on the weather's grip.
  if (steer) {
    const qx = at.qx[e]!, qy = at.qy[e]!, qz = at.qz[e]!, qw = at.qw[e]!;
    const fx = 2 * (qx * qz + qw * qy), fz = 1 - 2 * (qx * qx + qy * qy);
    rb.velocityX[e] = fx * TURN_SPEED;
    rb.velocityZ[e] = fz * TURN_SPEED;
    world.loop.input.edge('KeyA', true);
  }
  ticks(coast, () => {
    const qx = at.qx[e]!, qy = at.qy[e]!, qz = at.qz[e]!, qw = at.qw[e]!;
    const lx = 1 - 2 * (qy * qy + qz * qz), lz = 2 * (qx * qz - qw * qy);
    slide = Math.max(slide, Math.abs(rb.velocityX[e]! * lx + rb.velocityZ[e]! * lz));
  });
  if (steer) world.loop.input.edge('KeyA', false);
  sim.release();
  const turned = Math.abs(Math.atan2(Math.sin(yawOf() - yaw0), Math.cos(yawOf() - yaw0)));
  return { slide, turned, x: at.px[e]!, z: at.pz[e]! };
};

const dry = run(Weather.sunny, 6, 0.4, true);
const snow = run(Weather.snow, 6, 0.4, true);
// Full lock from the same speed: on snow the tyres lose their grip and it ploughs on, turning far less.
check('on snow the same steer turns the kart far less than in the dry', snow.turned < dry.turned * 0.7, `turned in 0.4 s: dry ${(dry.turned * 57.3).toFixed(0)} deg, snow ${(snow.turned * 57.3).toFixed(0)} deg`);

const calm = run(Weather.sunny, 2, 1.5, false);
const windy = run(Weather.wind, 2, 1.5, false);
const blown = Math.hypot(windy.x - calm.x, windy.z - calm.z);
check('a crosswind pushes it off its line', blown > 0.3, `${blown.toFixed(2)} m off where it went in calm air`);

build.order[e] = Order.restart;
ticks(0.3);
const kept = kart.weather[e];
check('a restart keeps the weather dealt', kept === Weather.wind, `weather ${kept}`);
check('it raced', kart.phase[e] === Phase.countdown || kart.phase[e] === Phase.racing, `phase ${kart.phase[e]}`);
t.done();
