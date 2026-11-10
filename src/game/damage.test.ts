/**
 * Part damage (`damage.ts`) in a race, physics on (`sim.ts`: the first course, the kart as `populate` makes it, the
 * autopilot at the keys). Knocks are made by pushing the kart sideways into the course's wall at a set speed; landings
 * by sending it down into the road. It checks a light brush does nothing; clipping the left front corner bends that
 * wheel, says so, and the kart then pulls left; a hard landing damages the suspension that took it -- or, bolted on,
 * the wheel; a long scrape does not run a part through its states at once; one wheel gone, it still finishes; and R
 * puts every part, notice and bit of debris back as new.
 */
import { type Entity, RigidBody, Transform } from '@vibe/engine';
import { suite } from '@vibe/engine/testing';
import { CHASSIS, STARTER } from './build.ts';
import { Breakable, Build, Corner, Debris, Kart, Order, PartName, PartState, Phase, Pusher, Wheel } from './components.ts';
import { COURSES, TRACKS } from './courses.ts';
import { DAMAGE } from './damage.ts';
import { makeSim } from './sim.ts';

/** The kart these were tuned on: the fruit crate (the starter once). */
const CRATE = CHASSIS.findIndex((c) => c.name === 'Fruit crate');

const t = suite('game: part damage');
const check = (name: string, ok: boolean, saw: string): void => t.ok(`${name} (${saw})`, ok);

const sim = await makeSim();
const { world, e, ticks } = sim;
const kart = world.store(Kart);
const build = world.store(Build);
const wheel = world.store(Wheel);
const rb = world.store(RigidBody);
const at = world.store(Transform);
const wheels = world.query({ with: [Wheel] });
const debris = world.query({ with: [Debris], without: [Pusher] });
const teammates = world.query({ with: [Pusher] });
/** The teammate's shove off (`pusher`) taken away: these runs start as they always did. */
const noPush = (): void => {
  for (let i = 0; i < teammates.count; i++) world.store(Pusher).push[teammates.members[i]!] = 0;
};
const bales = world.query({ with: [Breakable] });
/** The hay bales lining the road taken away: they burst and take a knock themselves, and the test is of the wall's. */
const clearBales = (): void => {
  const all: Entity[] = [];
  for (let i = 0; i < bales.count; i++) all.push(bales.members[i]!);
  for (const b of all) world.destroy(b);
};

/** The wheel at a corner. */
const at_ = (corner: number): number => {
  for (let i = 0; i < wheels.count; i++) if (wheel.corner[wheels.members[i]!] === corner) return wheels.members[i]!;
  return 0;
};
const states = (): string => {
  const w: string[] = [];
  for (let k = 0; k < 4; k++) w.push(`${['fl', 'fr', 'rl', 'rr'][k]} ${wheel.state[at_(k)]}/${wheel.spring[at_(k)]}`);
  return `${w.join(', ')}, body ${kart.bodyState[e]}`;
};
const whole = (): boolean => {
  for (let i = 0; i < wheels.count; i++) {
    const w = wheels.members[i]!;
    if (wheel.state[w] !== PartState.healthy || wheel.spring[w] !== PartState.healthy || !wheel.attached[w]) return false;
  }
  return kart.bodyState[e] === PartState.healthy;
};
/** The track's left, across it, where the kart is (a track's `across` is + to its right). */
const leftOf = (): { x: number; z: number } => {
  const tr = TRACKS[0]!;
  const j = Math.max(0, Math.min(tr.samples - 1, Math.round(kart.progress[e]!)));
  return { x: tr.tz[j]!, z: -tr.tx[j]! };
};
/** Where across the track the kart is, metres (+ its left). */
const across = (): number => {
  const tr = TRACKS[0]!;
  const j = Math.max(0, Math.min(tr.samples - 1, Math.round(kart.progress[e]!)));
  return -((at.px[e]! - tr.sx[j]!) * -tr.tz[j]! + (at.pz[e]! - tr.sz[j]!) * tr.tx[j]!);
};
const heading = (): number => {
  const qx = at.qx[e]!, qy = at.qy[e]!, qz = at.qz[e]!, qw = at.qw[e]!;
  return Math.atan2(2 * (qw * qy + qx * qz), 1 - 2 * (qx * qx + qy * qy));
};
/** A fresh run on the first course in `set`'s build, the autopilot driving it `drive` seconds once it is off. */
const fresh = (set: Partial<typeof STARTER>, drive: number): void => {
  sim.release();
  for (const [k, v] of Object.entries({ ...STARTER, chassis: CRATE, ...set })) (build[k as keyof typeof STARTER] as Uint8Array)[e] = v;
  build.version[e] = build.version[e]! + 1;
  build.course[e] = 0;
  build.open[e] = COURSES.length;
  build.order[e] = Order.restart;
  ticks(0.3);
  noPush();
  ticks(4, sim.autopilot);
  ticks(drive, sim.autopilot);
  sim.release();
};
/** Pushed sideways toward the track's left at `side` m/s (its speed along the road kept), for up to `secs` seconds;
 * `yaw` rad/s about its up for the first `turnFor` seconds. `each` after every tick. */
const push = (side: number, secs: number, yaw = 0, turnFor = 0, each?: (s: number) => void): void => {
  let s = 0;
  ticks(secs, () => {
    const l = leftOf();
    const lateral = rb.velocityX[e]! * l.x + rb.velocityZ[e]! * l.z;
    rb.velocityX[e] = rb.velocityX[e]! + l.x * (side - lateral);
    rb.velocityZ[e] = rb.velocityZ[e]! + l.z * (side - lateral);
    if (s < turnFor) rb.angularVelocityY[e] = yaw;
    s += 1 / 60;
    each?.(s);
  });
};

ticks(1);

// A light brush along the wall: nothing.
fresh({}, 2);
clearBales();
{
  // Set beside the wall first (its box half a metre or so off it), then eased into it.
  const l = leftOf(), move = TRACKS[0]!.halfWidth - 0.8 - across();
  at.px[e] = at.px[e]! + l.x * move;
  at.pz[e] = at.pz[e]! + l.z * move;
  ticks(1 / 60);
}
push(DAMAGE.light * 0.4, 1.5);
check('a light brush along the wall damages nothing', whole() && kart.callAt[e]! < -1 && across() > TRACKS[0]!.halfWidth - 1, `${states()}, ${across().toFixed(2)} m across, cause ${kart.cause[e]} at ${kart.causeSpeed[e]!.toFixed(1)} m/s, called at ${kart.callAt[e]!.toFixed(2)} s, speed ${kart.speed[e]!.toFixed(1)}`);

// Clipping the left front corner into the wall: that wheel bent (or off), and the lower third says so.
fresh({}, 2);
clearBales();
const a0 = across(), d0 = kart.damage[e]!;
let flCalled = false;
push(6, 2.5, 1.2, 0.35, () => { if (kart.callPart[e] === PartName.wheelFL && kart.callAt[e]! > -1) flCalled = true; });
const fl = at_(Corner.fl);
const clipSaw = `across ${a0.toFixed(2)} -> ${across().toFixed(2)}, wear ${d0.toFixed(2)} -> ${kart.damage[e]!.toFixed(2)}, phase ${kart.phase[e]}, grace ${kart.grace[e]!.toFixed(2)}, half width ${TRACKS[0]!.halfWidth}`;
check('clipping the left front corner damages that wheel', wheel.state[fl]! >= PartState.damaged && flCalled,
  `${states()}, callout part ${kart.callPart[e]} state ${kart.callState[e]}, bent ${wheel.bent[fl]!.toFixed(2)}; ${clipSaw}`);
check('a bent wheel is drawn bent', wheel.state[fl] !== PartState.damaged || wheel.bent[fl]! >= DAMAGE.frontBentLook - 1e-6, `bent ${wheel.bent[fl]!.toFixed(2)}`);

// Bashed sideways into the wall hard, tyres first: a left wheel bent or off -- the wheels look out for the wall
// themselves (they have no collider; the box does the colliding).
fresh({}, 2);
clearBales();
push(8, 1.2);
let leftHurt = 0;
for (const k of [Corner.fl, Corner.rl]) if (wheel.state[at_(k)]! >= PartState.damaged) leftHurt++;
check('a tyre bashed into the wall at speed bends or comes off', leftHurt > 0, `${states()}, ${across().toFixed(2)} m across`);

// A bent left front pulls left: the same stretch driven hands off, healthy and then bent, turns further left bent.
const drift = (bend: boolean): number => {
  fresh({}, 3);
  if (bend) {
    const w = at_(Corner.fl);
    wheel.state[w] = PartState.damaged;
    wheel.stateAt[w] = kart.clock[e]!;
  }
  const h0 = heading();
  ticks(1.2);
  let d = heading() - h0;
  if (d > Math.PI) d -= 2 * Math.PI;
  if (d < -Math.PI) d += 2 * Math.PI;
  return d;
};
const straight = drift(false);
const bentDrift = drift(true);
check('a bent left front wheel pulls the kart left', bentDrift > straight + 0.01, `heading change hands off: healthy ${straight.toFixed(3)} rad, bent ${bentDrift.toFixed(3)} rad`);

// A hard landing: on long springs, the suspension takes it all; on short ones it passes on to the wheels too;
// bolted on, the wheels take it all.
/** Dropped onto the road from DROP metres up, coming down at `down` m/s as it meets it: a real landing, its wheels off
 * the road first (one pressed into it while rolling on it is a dip, and forgiven). */
const DROP = 1;
const drop = (down: number): void => {
  at.py[e] = at.py[e]! + DROP;
  rb.velocityY[e] = -Math.sqrt(Math.max(0, down * down - 2 * 9.81 * DROP));
  // Straight down: nothing knocked on the way (a wall, a bale), only the landing.
  rb.velocityX[e] = rb.velocityZ[e] = 0;
};
const landing = (set: Partial<typeof STARTER>, down: number): { springs: number; wheelsHurt: number; worst: number } => {
  fresh(set, 2);
  drop(down);
  ticks(0.6);
  let springs = 0, wheelsHurt = 0, worst = 0;
  for (let k = 0; k < 4; k++) {
    if (wheel.spring[at_(k)]! > 0) springs++;
    if (wheel.state[at_(k)]! > 0) wheelsHurt++;
    worst = Math.max(worst, wheel.state[at_(k)]!);
  }
  return { springs, wheelsHurt, worst };
};
const pogo = landing({ suspension: 3 }, 11);
check('a hard landing on long pogo springs damages the suspension, not the wheels', pogo.springs > 0 && pogo.wheelsHurt === 0, `${states()}, cause ${kart.cause[e]} at ${kart.causeSpeed[e]!.toFixed(1)}, travel ${kart.travel[e]!.toFixed(2)}, soak ${kart.soak[e]}, grace ${kart.grace[e]}`);
const short = landing({ suspension: 1, springSize: 50 }, 7);
check('the same on short bed springs passes it on: wheels bent or off', short.wheelsHurt > 0, `${states()}, travel ${kart.travel[e]!.toFixed(3)} m`);
let springs = 0, wheelsHurt = 0;
fresh({ suspension: 0 }, 2);
drop(4.5);
ticks(0.6);
springs = 0;
wheelsHurt = 0;
for (let k = 0; k < 4; k++) {
  if (wheel.spring[at_(k)]! > 0) springs++;
  if (wheel.state[at_(k)]! > 0) wheelsHurt++;
}
check('a hard landing bolted on (no suspension) damages the wheels instead', wheelsHurt > 0 && springs === 0, states());

// Off a jump: a clean landing is forgiven its allowance (`DAMAGE.jumpAllowance`); an overshoot past it is not.
const jumpLanding = (down: number): number => {
  fresh({ suspension: 1 }, 2);
  kart.grace[e] = 1;
  drop(down);
  ticks(0.6);
  let hurt = 0;
  for (let k = 0; k < 4; k++) if (wheel.spring[at_(k)]! > 0 || wheel.state[at_(k)]! > 0) hurt++;
  return hurt;
};
const clean = jumpLanding(7), overshoot = jumpLanding(13);
check('a clean landing off a jump does no harm', clean === 0, `${clean} corners hurt at 7 m/s`);
check('an overshot jump landing damages the corners it lands on', overshoot > 0, `${overshoot} corners hurt at 13 m/s; ${states()}`);

// A long scrape along the wall: no part goes from healthy to failed inside its cooldown.
fresh({}, 2);
clearBales();
const changed: number[] = new Array(9).fill(-99);
const was: number[] = new Array(9).fill(0);
let tooFast = '';
push(4.5, 2.5, 0, 0, (s) => {
  for (let k = 0; k < 9; k++) {
    const now = k < 4 ? wheel.state[at_(k)]! : k < 8 ? wheel.spring[at_(k - 4)]! : kart.bodyState[e]!;
    if (now !== was[k]) {
      if (s - changed[k]! < DAMAGE.cooldown - 0.02) tooFast += ` part ${k} ${was[k]}→${now} after ${(s - changed[k]!).toFixed(2)} s;`;
      changed[k] = s;
      was[k] = now;
    }
  }
});
check('a long scrape does not run a part through its states at once', tooFast === '', `${states()}${tooFast}`);

// One wheel gone, the right rear: it limps on to the finish; R then puts everything back.
fresh({}, 0.5);
const rr = at_(Corner.rr);
wheel.state[rr] = PartState.failed;
wheel.attached[rr] = 0;
kart.wheelsLost[e] = 1;
let s = 0;
while (kart.phase[e] !== Phase.finished && kart.phase[e] !== Phase.over && s < 150) {
  ticks(1, sim.autopilot);
  s++;
}
sim.release();
check('on three wheels it still finishes', kart.phase[e] === Phase.finished, `phase ${kart.phase[e]} at ${kart.progress[e]!.toFixed(0)} of ${TRACKS[0]!.finish} after ${s} s, ${kart.finishTime[e]!.toFixed(1)} s, wheels lost ${kart.wheelsLost[e]}, out ${kart.out[e]}, cause ${kart.cause[e]}, up ${kart.upY[e]!.toFixed(2)}, wrecked ${kart.wrecked[e]}`);
build.order[e] = Order.restart;
ticks(1);
check('R puts every part, notice and bit of debris back as new', whole() && kart.callAt[e]! < -1 && debris.count === 0 && kart.wheelsLost[e] === 0,
  `${states()}, callout at ${kart.callAt[e]}, ${debris.count} bits, wheels lost ${kart.wheelsLost[e]}`);
// Flying off the side of the course: nothing breaks while it is in the air out there -- only once it comes down.
fresh({}, 2);
{
  const tr = TRACKS[0]!;
  const j = Math.max(0, Math.min(tr.samples - 1, Math.round(kart.progress[e]!)));
  const out = -(tr.halfWidth + 3);   // the track's left (its across is + to its right)
  at.px[e] = tr.sx[j]! - tr.tz[j]! * out;
  at.py[e] = tr.sy[j]! + 3;
  at.pz[e] = tr.sz[j]! + tr.tx[j]! * out;
  rb.velocityX[e] = tr.tx[j]! * 12;
  rb.velocityY[e] = 2;
  rb.velocityZ[e] = tr.tz[j]! * 12;
}
ticks(0.8);
check('flying off the side, it does not break up in the air', !kart.wrecked[e] && !kart.smash[e], `wrecked ${kart.wrecked[e]}, smash ${kart.smash[e]}, off ${kart.offFor[e]!.toFixed(2)} s, air ${kart.air[e]!.toFixed(2)} s`);
t.done();
