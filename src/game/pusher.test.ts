/**
 * The teammate at the start (`systems/pusher.ts`, physics on, `sim.ts`): one stands behind the kart through the
 * countdown -- clear of its back, however long the kart -- shoves it off at GO (it gets going with nobody at the keys,
 * and faster with forward held), then lets go and ends flat on their face; a restart brings a fresh one.
 */
import { suite } from '@vibe/engine/testing';
import { Transform } from '@vibe/engine';
import { BODY, STARTER } from './build.ts';
import { Build, Kart, Order, Phase, Pusher } from './components.ts';
import { COURSES } from './courses.ts';
import { makeSim } from './sim.ts';

const t = suite('game: teammate push-off');
const check = (name: string, ok: boolean, saw: string): void => t.ok(`${name} (${saw})`, ok);

const sim = await makeSim();
const { world, e, ticks } = sim;
const kart = world.store(Kart);
const build = world.store(Build);
const pu = world.store(Pusher);
const pushers = world.query({ with: [Pusher] });

ticks(1);
for (const [k, v] of Object.entries(STARTER)) (build[k as keyof typeof STARTER] as Uint8Array)[e] = v;
build.version[e] = build.version[e]! + 1;
build.course[e] = 0;
build.open[e] = COURSES.length;
build.order[e] = Order.restart;
ticks(1);
check('a teammate waits behind the kart in the countdown', kart.phase[e] === Phase.countdown && pushers.count === 1 && pu.state[pushers.members[0]!] === 0,
  `phase ${kart.phase[e]}, ${pushers.count} teammates`);
sim.release();
ticks(3);
const off = kart.speed[e]!;
ticks(0.5);
const state = pushers.count ? pu.state[pushers.members[0]!] : -1;
check('at GO they shove it off gently, nobody at the keys', kart.phase[e] === Phase.racing && off > 0.4, `${off.toFixed(2)} m/s a moment after GO`);
ticks(1.5);
check('then they let go and fall flat on their face', pushers.count === 1 && pu.state[pushers.members[0]!] === 3, `state ${state} then ${pushers.count ? pu.state[pushers.members[0]!] : -1}`);
// Forward held through the push: a harder shove, a faster start.
build.order[e] = Order.restart;
ticks(0.5);
sim.release();
const input = world.loop.input;
input.edge('KeyW', true);
ticks(3);
ticks(1.4);
const hard = kart.speed[e]!;
input.edge('KeyW', false);
build.order[e] = Order.restart;
ticks(0.5);
ticks(3);
ticks(1.4);
const easy = kart.speed[e]!;
check('forward held, they push harder', hard > easy + 0.5, `${hard.toFixed(2)} m/s held, ${easy.toFixed(2)} m/s not`);
// The longest kart: the teammate's feet clear of its back by as far as their arms reach.
const longest = Math.max(0, BODY.findIndex((b) => b.name === 'Gravity Well'));
for (const [k, v] of Object.entries({ ...STARTER, body: longest, chassis: BODY[longest]!.on ?? 1 })) (build[k as keyof typeof STARTER] as Uint8Array)[e] = v;
build.version[e] = build.version[e]! + 1;
build.order[e] = Order.restart;
ticks(1);
const at = world.store(Transform);
const p = pushers.members[0]!;
const qx = at.qx[e]!, qy = at.qy[e]!, qz = at.qz[e]!, qw = at.qw[e]!;
const fx = 2 * (qx * qz + qw * qy), fz = 1 - 2 * (qx * qx + qy * qy);
const behind = -((at.px[p]! - at.px[e]!) * fx + (at.pz[p]! - at.pz[e]!) * fz) / (Math.hypot(fx, fz) || 1);
check('clear of the back of the longest kart', behind > kart.halfBack[e]! + 0.6, `feet ${behind.toFixed(2)} m behind its middle, its back ${kart.halfBack[e]!.toFixed(2)} m`);
build.order[e] = Order.restart;
ticks(0.5);
check('a restart brings a fresh one, ready', pushers.count === 1 && pu.state[pushers.members[0]!] === 0, `${pushers.count} teammates, state ${pushers.count ? pu.state[pushers.members[0]!] : -1}`);
t.done();
