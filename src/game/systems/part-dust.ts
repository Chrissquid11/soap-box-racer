/**
 * partDust, 60 Hz: in the garage, a part swapped (or resized) shows it with a brief puff of workshop dust where that
 * part sits on the kart -- the wheels at their corners, the steering in the driver's hands, the driver on the seat,
 * the chassis and bodywork round the kart's middle. Only a change: the build the garage opens on raises none.
 */
import { type Entity, Hierarchy, NONE, type SystemContext, Transform, type World } from '@vibe/engine';
import { Build, BuildSeen, Debris, Kart, Phase, Seat, SteeringLook, Wheel } from '../components.ts';
import { rotate, v3 } from '../kart-math.ts';
import { puff } from './fx.ts';

type Cmd = SystemContext['cmd'];
type Has = SystemContext['has'];
type Arr = ArrayLike<number>;
interface Places { px: Arr; py: Arr; pz: Arr; qx: Arr; qy: Arr; qz: Arr; qw: Arr }
interface Tree { firstChild: Arr; nextSibling: Arr }

/** Where a change raises its dust: all four wheels, the front or rear pair, the steering, the seat, the middle. */
const WHEELS = 0, FRONT = 1, REAR = 2, STEERING = 3, SEAT = 4, MIDDLE = 5;

/** The dust's colour (near white), how many puffs a spot, how big they start and grow to (metres),
 * and how long they last (seconds). */
const DUST = 0xf2eee6;
const PUFFS = 6;
const FROM = 0.08;
const TO = 0.28;
const LIFE = 1.32;

const SPOT = v3();

/** 0..1, the same for the same pair: the scatter of a puff. */
function jitter(a: number, b: number): number {
  const s = Math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
  return s - Math.floor(s);
}

/** A little cloud of dust at (x, y, z) on kart `e` (its own frame), `size` times the usual. */
function cloud(cmd: Cmd, at: Places, e: Entity, x: number, y: number, z: number, size: number, seed: number): void {
  rotate(at.qx[e]!, at.qy[e]!, at.qz[e]!, at.qw[e]!, x, y, z, SPOT);
  const wx = at.px[e]! + SPOT.x, wy = at.py[e]! + SPOT.y, wz = at.pz[e]! + SPOT.z;
  for (let p = 0; p < PUFFS; p++) {
    const a = (p / PUFFS + jitter(seed, p) * 0.3) * Math.PI * 2;
    // Hanging round the part: a slow spread out, hardly any rise.
    const out = 0.03 + jitter(seed + 3, p) * 0.045;
    // Not debris: a part changed sets the kart down afresh (`RaceReset`), and the sweep clears the debris then --
    // this dust is made that same moment, and fades away by itself.
    const d = puff(cmd,wx + Math.cos(a) * 0.08 * size, wy + (jitter(seed + 5, p) - 0.3) * 0.1 * size, wz + Math.sin(a) * 0.08 * size,
      Math.cos(a) * out * size, 0.008 + jitter(seed + 9, p) * 0.012, Math.sin(a) * out * size,
      FROM * size, TO * size, LIFE * (0.8 + jitter(seed + 11, p) * 0.4), DUST, 0, true);
    if (d !== NONE) cmd.remove(d, Debris);
  }
}

/** Dust where `spot` is on kart `e`: at each place on it that part is. */
function dust(cmd: Cmd, has: Has, tree: Tree, at: Places, e: Entity, spot: number, seed: number): void {
  if (spot === MIDDLE) {
    cloud(cmd, at, e, 0, 0.1, 0.35, 1.5, seed);
    cloud(cmd, at, e, 0, 0.1, -0.35, 1.5, seed + 1);
    return;
  }
  for (let c = tree.firstChild[e]!; c !== 0; c = tree.nextSibling[c]!) {
    if (spot === STEERING) {
      if (has(c as Entity, SteeringLook)) cloud(cmd, at, e, at.px[c]!, at.py[c]!, at.pz[c]!, 0.8, seed);
    } else if (spot === SEAT) {
      if (has(c as Entity, Seat)) cloud(cmd, at, e, at.px[c]!, at.py[c]! + 0.6, at.pz[c]!, 1.2, seed);
    } else if (has(c as Entity, Wheel)) {
      const front = at.pz[c]! > 0;
      if (spot === WHEELS || (spot === FRONT && front) || (spot === REAR && !front)) cloud(cmd, at, e, at.px[c]!, at.py[c]!, at.pz[c]!, 1, seed + c);
    }
  }
}

export function partDust(world: World): void {
  world.system({
    name: 'partDust',
    rate: 60,
    after: ['assemble'],
    with: [Kart, Build, BuildSeen],
    read: [Kart, Build, Hierarchy, Transform],
    write: [BuildSeen],
    update({ members, count, cmd, has, time }, [kart, build, tree, at], [was]) {
      const tick = Math.round(time * 60);
      for (let n = 0; n < count; n++) {
        const e = members[n]!;
        const first = !was.known[e];
        was.known[e] = 1;
        // In the garage, each slot or size that changed since: its dust. (The first look only takes note.)
        const show = !first && kart.phase[e] === Phase.garage;
        if (show) {
          if (was.chassis[e] !== build.chassis[e] || was.body[e] !== build.body[e]
            || was.chassisWidth[e] !== build.chassisWidth[e] || was.chassisLength[e] !== build.chassisLength[e]) dust(cmd, has, tree, at, e, MIDDLE, tick);
          if (was.wheels[e] !== build.wheels[e] || was.suspension[e] !== build.suspension[e] || was.springSize[e] !== build.springSize[e]) dust(cmd, has, tree, at, e, WHEELS, tick + 7);
          else {
            if (was.frontSize[e] !== build.frontSize[e]) dust(cmd, has, tree, at, e, FRONT, tick + 13);
            if (was.rearSize[e] !== build.rearSize[e]) dust(cmd, has, tree, at, e, REAR, tick + 17);
          }
          if (was.steering[e] !== build.steering[e]) dust(cmd, has, tree, at, e, STEERING, tick + 23);
          if (was.outfit[e] !== build.outfit[e]) dust(cmd, has, tree, at, e, SEAT, tick + 29);
        }
        was.chassis[e] = build.chassis[e]!;
        was.wheels[e] = build.wheels[e]!;
        was.suspension[e] = build.suspension[e]!;
        was.steering[e] = build.steering[e]!;
        was.body[e] = build.body[e]!;
        was.outfit[e] = build.outfit[e]!;
        was.chassisWidth[e] = build.chassisWidth[e]!;
        was.chassisLength[e] = build.chassisLength[e]!;
        was.frontSize[e] = build.frontSize[e]!;
        was.rearSize[e] = build.rearSize[e]!;
        was.springSize[e] = build.springSize[e]!;
      }
    },
  });
}
