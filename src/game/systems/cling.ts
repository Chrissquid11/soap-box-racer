/**
 * Foam and straw that stick: through the car wash's foam (`courses.ts`' Surface.soap) blobs of suds land on the kart and
 * its driver; a hay bale burst against it (`Kart.strawHit`, from `impacts`) leaves stalks of straw all over them. Each
 * rides along where it landed for CLING_LEAST to CLING_MOST seconds, then drops off -- falling away with the kart's
 * speed, tumbling, shrinking to nothing.
 *
 *   clingOn   60 Hz   new bits on each kart: suds while it runs through the foam, straw for each bale it bursts
 *   clingMove 60 Hz   every bit held to its kart, then dropping, then gone
 */
import { NONE, optional, Render, type SystemContext, Transform, type World } from '@vibe/engine';
import { surfaceAt, Surface } from '../courses.ts';
import { Cling, Kart, Phase } from '../components.ts';
import { rotate, v3 } from '../kart-math.ts';
import { ClingBit } from '../prefabs.ts';

type Cmd = SystemContext['cmd'];
type Rng = SystemContext['rng'];
type KartRef = ReturnType<SystemContext['ref']>;

/** Seconds a bit stays stuck: from this to this, each its own. */
const CLING_LEAST = 2;
const CLING_MOST = 4;
/** Seconds a bit takes to fall away once it lets go, and how hard it falls (m/s²). */
const DROP_FOR = 1;
const DROP_FALL = 9;
/** Suds: one every FOAM_EVERY ticks in the foam, faster than FOAM_FROM (m/s); each this big (metres), in these whites. */
const FOAM_EVERY = 5;
const FOAM_FROM = 1;
const FOAM_SIZE = 0.09;
const FOAM_COLOURS = [0xffffff, 0xf2f7ff, 0xe4f0ff] as const;
/** Straw: at most this many stalks for one knock; each this thick and long (metres), in these yellows. */
const STRAW_MOST = 14;
const STRAW_THICK = 0.022;
const STRAW_LONG = 0.24;
const STRAW_COLOURS = [0xe8c45a, 0xd9ad3c, 0xf2d77e, 0xc4952e] as const;
/** The share of bits that land on the driver (the rest on the kart), and where the driver sits (the seat's z). */
const ON_DRIVER = 0.5;
const SEAT_Z = -0.25;

const SPOT = v3();

/** A bit stuck to kart `e`: suds or straw, somewhere on it or its driver, from the loop's chance `r`. */
function stick(cmd: Cmd, kartRef: KartRef, straw: boolean, rng: Rng, seatY: number, halfTrack: number, halfBase: number): void {
  const b = cmd.instantiate(ClingBit);
  if (b === NONE) return;
  const c = cmd.init(b, Cling);
  c.kart[b] = kartRef;
  if (rng.next() < ON_DRIVER) {
    // On the driver: shoulders, chest, helmet.
    c.ox[b] = (rng.next() - 0.5) * 0.36;
    c.oy[b] = seatY + 0.3 + rng.next() * 0.5;
    c.oz[b] = SEAT_Z + (rng.next() - 0.5) * 0.26;
  } else {
    // On the kart: across its deck, front to back.
    c.ox[b] = (rng.next() - 0.5) * 1.6 * halfTrack;
    c.oy[b] = seatY + rng.next() * 0.15;
    c.oz[b] = (rng.next() - 0.5) * 1.7 * halfBase;
  }
  // Each its own way round on it: a stalk lies any which way, a blob is a blob.
  const yaw = rng.next() * Math.PI * 2, tilt = (rng.next() - 0.5) * 1.6;
  const sy = Math.sin(yaw / 2), cy = Math.cos(yaw / 2), sx = Math.sin(tilt / 2), cx = Math.cos(tilt / 2);
  c.lqx[b] = cy * sx;
  c.lqy[b] = sy * cx;
  c.lqz[b] = -sy * sx;
  c.lqw[b] = cy * cx;
  c.left[b] = CLING_LEAST + rng.next() * (CLING_MOST - CLING_LEAST);
  c.straw[b] = straw ? 1 : 0;
  const at = cmd.init(b, Transform);
  if (straw) {
    at.sx[b] = STRAW_THICK;
    at.sy[b] = STRAW_THICK;
    at.sz[b] = STRAW_LONG * (0.6 + rng.next() * 0.8);
  } else {
    const s = FOAM_SIZE * (0.6 + rng.next() * 0.9);
    at.sx[b] = s;
    at.sy[b] = s * 0.75;
    at.sz[b] = s;
  }
  const look = cmd.init(b, Render);
  look.tint[b] = straw ? STRAW_COLOURS[Math.floor(rng.next() * STRAW_COLOURS.length)]! : FOAM_COLOURS[Math.floor(rng.next() * FOAM_COLOURS.length)]!;
}

export function cling(world: World): void {
  world.system({
    name: 'clingOn',
    rate: 60,
    write: [Kart],
    update({ members, count, cmd, rng, ref, tick }, [], [kart]) {
      for (let n = 0; n < count; n++) {
        const e = members[n];
        const racing = kart.phase[e] === Phase.racing || kart.phase[e] === Phase.finished;
        const hit = kart.strawHit[e];
        kart.strawHit[e] = 0;
        if (!racing || kart.ejected[e]) continue;
        for (let i = 0; i < Math.min(hit, STRAW_MOST); i++) stick(cmd, ref(e), true, rng, kart.seatY[e], kart.halfTrack[e], kart.halfBase[e]);
        if (kart.speed[e] > FOAM_FROM && tick % FOAM_EVERY === 0 && surfaceAt(kart.course[e], kart.progress[e]) === Surface.soap) {
          stick(cmd, ref(e), false, rng, kart.seatY[e], kart.halfTrack[e], kart.halfBase[e]);
        }
      }
    },
  });

  world.system({
    name: 'clingMove',
    rate: 60,
    after: ['clingOn'],
    read: [optional(Kart)],
    write: [Cling, Transform],
    update({ members, count, cmd, dt, deref, has }, [kart], [c, at]) {
      for (let n = 0; n < count; n++) {
        const b = members[n];
        const k = deref(c.kart[b]);
        // Its kart gone, or set down afresh in the garage: gone with it.
        const held = k !== NONE && has(k, Kart) && (kart.phase[k] === Phase.racing || kart.phase[k] === Phase.finished) && !kart.ejected[k];
        if (!c.dropping[b]) {
          if (k === NONE || !has(k, Kart) || kart.phase[k] === Phase.garage || kart.phase[k] === Phase.countdown) {
            cmd.destroy(b);
            continue;
          }
          c.left[b] -= dt;
          if (c.left[b] <= 0 || !held) {
            // Letting go: off with the kart's speed, a little out and up.
            c.dropping[b] = 1;
            c.vx[b] = kart.lastVX[k] * 0.8 + c.ox[b] * 2;
            c.vy[b] = 0.6;
            c.vz[b] = kart.lastVZ[k] * 0.8 + c.oz[b] * 0.5;
          }
          // Held where it landed on the kart, turned with it.
          const qx = at.qx[k], qy = at.qy[k], qz = at.qz[k], qw = at.qw[k];
          rotate(qx, qy, qz, qw, c.ox[b], c.oy[b], c.oz[b], SPOT);
          at.px[b] = at.px[k] + SPOT.x;
          at.py[b] = at.py[k] + SPOT.y;
          at.pz[b] = at.pz[k] + SPOT.z;
          const lx = c.lqx[b], ly = c.lqy[b], lz = c.lqz[b], lw = c.lqw[b];
          at.qx[b] = qw * lx + qx * lw + qy * lz - qz * ly;
          at.qy[b] = qw * ly - qx * lz + qy * lw + qz * lx;
          at.qz[b] = qw * lz + qx * ly - qy * lx + qz * lw;
          at.qw[b] = qw * lw - qx * lx - qy * ly - qz * lz;
          continue;
        }
        // Dropping: falling away, slowing in the air, tumbling, shrinking to nothing at the end.
        c.age[b] += dt;
        if (c.age[b] >= DROP_FOR) {
          cmd.destroy(b);
          continue;
        }
        c.vy[b] -= DROP_FALL * dt;
        c.vx[b] *= 1 - 1.5 * dt;
        c.vz[b] *= 1 - 1.5 * dt;
        at.px[b] += c.vx[b] * dt;
        at.py[b] += c.vy[b] * dt;
        at.pz[b] += c.vz[b] * dt;
        const shrink = 1 - 2.5 * dt * Math.max(0, c.age[b] / DROP_FOR - 0.5);
        at.sx[b] *= shrink;
        at.sy[b] *= shrink;
        at.sz[b] *= shrink;
      }
    },
  });
}
