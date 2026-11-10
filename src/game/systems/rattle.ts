/**
 * rattle, 60 Hz, late: homemade, and it shows. Every kart is put together a little crooked -- its bodywork bolted
 * on askew, its steering bent, each wheel on its own wonky camber and toe -- each build its own way (the same
 * build always the same), and it all shakes: the body and the chassis rattle the faster it goes and the harder it
 * is jolted, the steering judders, and every wheel wobbles on its buckled rim as it turns. Only the look: the
 * kart's box, its wheels' rays and its grip are as they were. After `wheelLook` and `steerLook`, which set the
 * wheels' and the steering's turns afresh each frame: this turns each of them a little more, in its own frame.
 * The chassis and the bodywork are never turned by anything else, so theirs is set from straight each frame.
 */
import { Hierarchy, optional, Transform, type World } from '@vibe/engine';
import { BinLid, Bodywork, Build, ChassisLook, Kart, PartState, Phase, SteeringLook, Wheel } from '../components.ts';
import { shedShare } from '../damage.ts';

const DEG = Math.PI / 180;
/** How crooked it was built, at most, degrees: the bodywork (yaw, roll, pitch), the steering, each wheel's camber and toe. */
const BODY_SKEW = [5.5, 4.5, 3] as const;
const STEER_SKEW = 11;
const CAMBER = 7;
const TOE = 4.5;
/** A wheel's buckle: how far it wobbles each turn, degrees. */
const BUCKLE = 5;
/** Degrees the chassis' own look sits off its box: built out of true. */
const CHASSIS_SKEW = 1.8;
/** Bent: degrees more of buckle and of lean a wheel bent right through has, and of tilt the bodywork takes worn through. */
const BENT_BUCKLE = 14;
const BENT_LEAN = 12;
const DENT = 9;
/** Degrees the bodywork leans, battered right through (`Kart.bodyDamage`). */
const BODY_DENT = 16;
/** The rattle at full shake, degrees: the bodywork, the chassis, the steering; and how fast, times a second. */
const BODY_RATTLE = 2.2;
const CHASSIS_RATTLE = 0.8;
const STEER_RATTLE = 4;
const RATTLE_HZ = 11;
/**
 * The warning before the bodywork goes: once it is dented (the next good knock takes it off) or worn within this share
 * of the mark it sheds at (`damage.ts`' shedAt), it works loose on its mounts -- a slow, big wobble, degrees, this many
 * times a second -- so you can see it coming.
 */
const LOOSE_NEAR = 0.12;
const LOOSE_WOBBLE = 6;
const LOOSE_HZ = 3.2;
/** The wheelie bin's lid, hanging open down its back: how far it flaps out from the bin at full shake (degrees),
 * and how fast; a little even at rest, more with speed and every jolt. Only ever out, away from the bin. */
const LID_FLAP = 22;
const LID_HZ = 2.3;
const LID_REST = 0.15;
/** Full shake at this speed (m/s), and this much more for each m/s² it is jolted up or down (to twice as much). */
const SHAKE_SPEED = 14;
const SHAKE_JOLT = 0.04;
/** A kart as new shakes this share of that -- its rattle and its wheels' wobble -- rising to all of it worn through
 * (`Kart.damage` over `Kart.hp`, or its bodywork battered). A bent wheel's own buckle is on top, always whole. */
const CALM = 0.25;
/** Built crooked shows only once it is off: straight in the garage and on the grid, the crooks easing in over this
 * many seconds of the run (`Kart.clock`). */
const CROOK_IN = 2;

const q = { x: 0, y: 0, z: 0, w: 1 };

/** -1..1 from a build's seed and a number: the same for the same pair. */
function crook(seed: number, n: number): number {
  let h = Math.imul(seed ^ (n * 0x9e3779b1), 0x85ebca6b);
  h = Math.imul(h ^ (h >>> 13), 0xc2b2ae35);
  return (((h ^ (h >>> 16)) >>> 0) / 4294967296) * 2 - 1;
}

/** Into `q`: a turn of x, then y, then z (radians, small: a crook or a rattle), as one quaternion. */
function turnOf(x: number, y: number, z: number): void {
  const sx = Math.sin(x / 2), cx = Math.cos(x / 2);
  const sy = Math.sin(y / 2), cy = Math.cos(y / 2);
  const sz = Math.sin(z / 2), cz = Math.cos(z / 2);
  q.w = cx * cy * cz + sx * sy * sz;
  q.x = sx * cy * cz - cx * sy * sz;
  q.y = cx * sy * cz + sx * cy * sz;
  q.z = cx * cy * sz - sx * sy * cz;
}

export function rattle(world: World): void {
  world.system({
    name: 'rattle',
    rate: 60,
    with: [Kart],
    after: ['wheelLook', 'steerLook'],
    read: [Hierarchy, Build, Kart, optional(Wheel)],
    write: [Transform],
    lateUpdate({ members, count, time, has }, [tree, build, kartStore, wheel], [at]) {
      for (let n = 0; n < count; n++) {
        const e = members[n];
        if (!has(e, Build)) continue;
        // The build's seed: the same parts, the same crooks.
        const seed = (build.chassis[e] * 131 + build.body[e] * 37 + build.wheels[e] * 11 + build.steering[e] * 5 + build.suspension[e] * 3 + 7) | 0;
        const parked = kartStore.phase[e] === Phase.garage;
        // How crooked it shows: none parked or on the grid, eased in as the run gets going, all of it after.
        const ph = kartStore.phase[e];
        const bent0 = ph === Phase.garage || ph === Phase.countdown ? 0 : ph === Phase.racing ? Math.min(1, Math.max(0, kartStore.clock[e] / CROOK_IN)) : 1;
        const jolt = Math.min(1, Math.abs(kartStore.accelY[e]) * SHAKE_JOLT);
        const t = time * RATTLE_HZ * 2 * Math.PI;
        // Knocked about: the more worn it is, the further its bodywork, its chassis and its steering are bent out of true.
        const worn = Math.min(1, kartStore.damage[e] / Math.max(1, kartStore.hp[e]));
        // And the looser it all rattles: a kart as new hardly shakes.
        const loose = CALM + (1 - CALM) * Math.min(1, Math.max(worn, kartStore.bodyDamage[e]));
        const shake = parked ? 0 : Math.min(2, Math.min(1, kartStore.speed[e] / SHAKE_SPEED) + jolt) * loose;
        const dent = worn * DENT * DEG * (crook(seed, 9) < 0 ? -1 : 1);
        // The bodywork battered on its own account too: knocked further askew the more it has been hit.
        // Sagging toward the side it was hit on (`Kart.hitSide`), and down at the end hit; never hit, its own crooked way.
        const hs = kartStore.hitSide[e], he = kartStore.hitEnd[e];
        const sag = hs !== 0 ? -Math.sign(hs) : crook(seed, 9) < 0 ? -1 : 1;
        const bodyDent = Math.max(worn, kartStore.bodyDamage[e]) * BODY_DENT * DEG * sag;
        const bodyNod = Math.max(worn, kartStore.bodyDamage[e]) * BODY_DENT * 0.5 * DEG * he;
        // About to come off: loose on its mounts, wobbling.
        const running = kartStore.phase[e] === Phase.racing || kartStore.phase[e] === Phase.finished;
        const going = running && kartStore.bodyOn[e] === 1
          && (kartStore.bodyState[e] === PartState.damaged || worn >= shedShare(kartStore.shed[e]) - LOOSE_NEAR);
        const tw = time * LOOSE_HZ * 2 * Math.PI;
        const wob = going ? LOOSE_WOBBLE * DEG * (0.6 + 0.4 * Math.min(1, kartStore.speed[e] / SHAKE_SPEED)) : 0;
        let part = 0;
        for (let c = tree.firstChild[e]; c !== 0; c = tree.nextSibling[c]) {
          part++;
          const p = part * 3.7;
          if (has(c, Bodywork)) {
            // Askew, and rattling on its bolts.
            const r = BODY_RATTLE * DEG * shake;
            turnOf(
              crook(seed, 1) * bent0 * BODY_SKEW[2] * DEG + bodyNod + Math.sin(t * 1.13 + p) * r * 0.6 + Math.sin(tw * 1.37) * wob * 0.5,
              crook(seed, 2) * bent0 * BODY_SKEW[0] * DEG + Math.sin(t * 0.91 + p) * r * 0.4 + Math.sin(tw * 0.71) * wob * 0.4,
              crook(seed, 3) * bent0 * BODY_SKEW[1] * DEG + bodyDent + Math.sin(t + p) * r + Math.sin(tw) * wob,
            );
            at.qx[c] = q.x; at.qy[c] = q.y; at.qz[c] = q.z; at.qw[c] = q.w;
          } else if (has(c, BinLid)) {
            const tl = time * LID_HZ * 2 * Math.PI;
            const swing = Math.abs(Math.sin(tl) * 0.65 + Math.sin(tl * 1.73 + 1.1) * 0.35);
            turnOf(swing * LID_FLAP * DEG * Math.min(1.5, LID_REST + shake), 0, 0);
            at.qx[c] = q.x; at.qy[c] = q.y; at.qz[c] = q.z; at.qw[c] = q.w;
          } else if (has(c, ChassisLook)) {
            const r = CHASSIS_RATTLE * DEG * shake;
            turnOf(Math.sin(t * 1.31 + p) * r, 0, Math.sin(t * 0.87 + p) * r + crook(seed, 4) * bent0 * CHASSIS_SKEW * DEG + dent * 0.3);
            at.qx[c] = q.x; at.qy[c] = q.y; at.qz[c] = q.z; at.qw[c] = q.w;
          } else if (has(c, SteeringLook)) {
            const r = STEER_RATTLE * DEG * shake;
            turnOf(Math.sin(t * 1.7 + p) * r * 0.5, 0, crook(seed, 5) * bent0 * STEER_SKEW * DEG + dent * 2 + Math.sin(t * 1.4 + p) * r);
            mul(at, c);
          } else if (has(c, Wheel) && wheel.attached[c]) {
            // Its camber and toe as built, and its buckle wobbling it about them once a turn.
            const k = wheel.corner[c] + 10;
            // Bent (`Wheel.bent`): a far bigger buckle, and leant over on its axle.
            const bent = wheel.bent[c];
            const buckle = (BUCKLE * (0.4 + 0.6 * Math.abs(crook(seed, k + 20))) * (CALM + (1 - CALM) * worn) * bent0 + bent * BENT_BUCKLE) * DEG;
            const lean = (crook(seed, k) * bent0 * CAMBER + bent * BENT_LEAN * (crook(seed, k + 40) < 0 ? -1 : 1)) * DEG;
            const spin = wheel.spin[c];
            turnOf(0, crook(seed, k + 30) * bent0 * TOE * DEG + Math.cos(spin) * buckle * 0.5, lean + Math.sin(spin) * buckle);
            // Turned in the frame it stands in (steered about y, rolling about x): before its own turn.
            pre(at, c);
          }
        }
      }
    },
  });
}

type Turns = { qx: { [e: number]: number }; qy: { [e: number]: number }; qz: { [e: number]: number }; qw: { [e: number]: number } };

/** The entity's turn, then `q` after it (in its own frame): its turn × q. */
function mul(at: Turns, e: number): void {
  const ax = at.qx[e]!, ay = at.qy[e]!, az = at.qz[e]!, aw = at.qw[e]!;
  at.qw[e] = aw * q.w - ax * q.x - ay * q.y - az * q.z;
  at.qx[e] = aw * q.x + ax * q.w + ay * q.z - az * q.y;
  at.qy[e] = aw * q.y - ax * q.z + ay * q.w + az * q.x;
  at.qz[e] = aw * q.z + ax * q.y - ay * q.x + az * q.w;
}

/** `q` first, then the entity's turn: q × its turn (q in its parent's frame, about where it stands). */
function pre(at: Turns, e: number): void {
  const bx = at.qx[e]!, by = at.qy[e]!, bz = at.qz[e]!, bw = at.qw[e]!;
  at.qw[e] = q.w * bw - q.x * bx - q.y * by - q.z * bz;
  at.qx[e] = q.w * bx + q.x * bw + q.y * bz - q.z * by;
  at.qy[e] = q.w * by - q.x * bz + q.y * bw + q.z * bx;
  at.qz[e] = q.w * bz + q.x * by - q.y * bx + q.z * bw;
}
