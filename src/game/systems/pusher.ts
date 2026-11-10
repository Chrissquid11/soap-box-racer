/**
 * pusher, 60 Hz: a teammate on foot pushes the kart off the line. Through the countdown they crouch behind it, hands
 * on its back, bouncing on their toes; at GO they sprint after it bent double, arms locked out shoving -- a shove
 * forward on the kart every tick, for PUSH_FOR seconds, as hard as the player says: full while forward (W, Up) is
 * held, EASY of it while not -- legs driving; then they let go, stagger on a few steps,
 * arms windmilling, and fall flat on their face on the road, where they lie kicking feebly till the next run
 * (`karts/teammate` is Debris: the sweep clears them). Made (`cmd`) on the countdown's first tick, one a run.
 *
 * They are the driver's own figure in the driver's own outfit -- one team, one kit -- playing the on-foot clips the
 * driver library has (`_driver.lua`: ready, push, stagger, flat), elbows and knees bending. This system places them
 * (feet on the road, lowered as the knees bend), turns them to the kart's way and picks the clip; the push is the
 * kart's own Forces. Their prefab: karts/teammate.
 */
import { Animation, Forces, internKey, NONE, optional, Render, Transform, type World } from '@vibe/engine';
import { OUTFITS } from '../build.ts';
import { Build, Kart, Phase, Pusher } from '../components.ts';
import { TRACKS } from '../courses.ts';
import { rotate, v3 } from '../kart-math.ts';
import { Teammate } from '../prefabs.ts';

/** Seconds after GO they push (how hard is `Pusher.push`, the prefab's); a kart gone further than this in one tick
 * (set back on its line, put somewhere new) is let go of at once. */
const PUSH_FOR = 1.6;
const LOST = 3;
/** Where they stand: their feet this far behind the kart's back (`Kart.halfBack`: its bodywork's or chassis' or rear
 * tyres' furthest back, never just its wheelbase), metres -- as far as their arms reach, hands on it, never in it -- and
 * this far to its left, shoving at its back corner: the chasing camera sees past them to the kart. */
const BEHIND = 0.7;
const ASIDE = 0.5;
/** Never in a wall: their middle kept this far inside the road's edge (their body's half width and a little), and
 * this far on from the wall across the road's top end -- wherever the kart stands, on a bend or hard by a barrier. */
const WALL_ROOM = 0.45;
const TOP_ROOM = 0.6;
/** How far each clip is lowered (metres): its GROUND in _driver.lua, where it solves the planted feet onto the road. Flat
 * on their face, the hips come down to this over the road. */
const CROUCH = 0.12;
const RUN_DIP = 0.08;
const STUMBLE_DIP = 0.06;
const LYING = 0.48;
/** At speed 1 the push clip's planted foot sweeps back this fast (m/s): its RUN_SWEEP over its RUN_STANCE. */
const STRIDE = 1.49;
const STRIDE_SLOWEST = 0.7;
/** After letting go: the staggering steps on, and the fall (seconds), how fast they stumble on (m/s at first). */
const STAGGER = 0.55;
const FALL = 0.35;
const STUMBLE = 4;
/** The shove with forward not held, a share of the full one. */
const EASY = 0.35;

const READY = internKey('Clip', 'ready');
const PUSH = internKey('Clip', 'push');
const STAGGERING = internKey('Clip', 'stagger');
const FLAT = internKey('Clip', 'flat');
/** Each outfit's model: the teammate wears the driver's. */
const OUTFIT_MODEL = OUTFITS.map((o) => internKey('Model', o.model));

const fwd = v3();

export function pusher(world: World): void {
  const pushers = world.query({ with: [Pusher] });
  world.system({
    name: 'pusher',
    rate: 60,
    after: ['vehicle'],
    with: [Kart],
    read: [optional(Build)],
    write: [optional(Pusher), optional(Animation), Transform, Kart, Forces],
    update({ members, count, dt, input, cmd, deref, ref, has }, [build], [pu, anim, at, kart, forces]) {
      // One made for a kart on its countdown that has none, in its driver's outfit.
      for (let n = 0; n < count; n++) {
        const k = members[n];
        if (kart.phase[k] !== Phase.countdown || deref(kart.pusher[k]) !== NONE) continue;
        const p = cmd.instantiate(Teammate);
        if (p === NONE) continue;
        cmd.init(p, Pusher).kart[p] = ref(k);
        if (has(k, Build)) cmd.init(p, Render).model[p] = OUTFIT_MODEL[Math.min(build.outfit[k], OUTFITS.length - 1)]!;
        kart.pusher[k] = ref(p);
      }

      for (let n = 0; n < pushers.count; n++) {
        const e = pushers.members[n]!;
        const k = deref(pu.kart[e]);
        if (k === NONE) continue;
        const clock = kart.clock[k];
        rotate(at.qx[k], at.qy[k], at.qz[k], at.qw[k], 0, 0, 1, fwd);
        const flat = Math.hypot(fwd.x, fwd.z) || 1;
        const fx = fwd.x / flat, fz = fwd.z / flat;
        // Ready, then pushing: behind the kart's back, on the road under it.
        if (pu.state[e] === 0 && kart.phase[k] === Phase.racing) {
          pu.state[e] = 1;
          pu.since[e] = clock;
        }
        let clip = READY, speed = 1, dip = CROUCH;
        if (pu.state[e] <= 1) {
          const back = kart.halfBack[k] + BEHIND;
          // The kart's left (its +x), flat: (fz, -fx).
          const ox = -fx * back + fz * ASIDE, oz = -fz * back - fx * ASIDE;
          const jumped = Math.hypot(at.px[k] + ox - pu.x[e], at.pz[k] + oz - pu.z[e]) > LOST;
          if (pu.state[e] === 1 && jumped) {
            pu.state[e] = 2;
            pu.since[e] = clock;
          }
          pu.x[e] = at.px[k] + ox;
          // The road under their feet: under the kart, and up (or down) the slope it is pitched on, `back` behind.
          pu.y[e] = at.py[k] - kart.rideY[k] - fwd.y * back;
          pu.z[e] = at.pz[k] + oz;
          // Kept on the road: inside its edges and on from its top end's wall (never standing in a barrier).
          const track = TRACKS[Math.min(kart.course[k], TRACKS.length - 1)];
          if (track) {
            const i = Math.max(0, Math.min(track.samples - 1, Math.round(kart.progress[k] - back / 2)));
            const tx = track.tx[i]!, tz = track.tz[i]!;
            const dx = pu.x[e] - track.sx[i]!, dz = pu.z[e] - track.sz[i]!;
            const along = dx * tx + dz * tz;
            const edge = track.hw[i]! - WALL_ROOM;
            const across = Math.max(-edge, Math.min(edge, -dx * tz + dz * tx));
            // At the road's first sample, the wall closing it off is behind it: on from that.
            const on = i === 0 ? Math.max(along, TOP_ROOM) : along;
            pu.x[e] = track.sx[i]! - tz * across + tx * on;
            pu.z[e] = track.sz[i]! + tx * across + tz * on;
          }
          pu.yaw[e] = Math.atan2(fx, fz);
          if (pu.state[e] === 1) {
            // Sprinting and shoving: the legs keep pace with the kart.
            clip = PUSH;
            dip = RUN_DIP;
            speed = Math.max(STRIDE_SLOWEST, kart.speed[k] / STRIDE);
            // As hard as the player asks: forward held, all they have; let go, a gentle shove.
            const hard = input.down('KeyW') || input.down('ArrowUp') || input.down('Pad0') ? 1 : EASY;
            const m = kart.mass[k];
            forces.impulseX[k] += fx * m * pu.push[e] * hard * dt;
            forces.impulseZ[k] += fz * m * pu.push[e] * hard * dt;
            if (clock - pu.since[e] > PUSH_FOR || kart.wrecked[k] || kart.ejected[k]) {
              pu.state[e] = 2;
              pu.since[e] = clock;
            }
          }
        } else {
          // Let go: a few staggering steps on, slowing, then flat on their face where they stopped.
          const t = clock - pu.since[e];
          if (pu.state[e] === 2) {
            const go = Math.max(0, 1 - t / STAGGER) * STUMBLE * dt;
            pu.x[e] += Math.sin(pu.yaw[e]) * go;
            pu.z[e] += Math.cos(pu.yaw[e]) * go;
            const falling = Math.min(1, Math.max(0, (t - STAGGER) / FALL));
            clip = falling > 0 ? FLAT : STAGGERING;
            dip = STUMBLE_DIP + (LYING - STUMBLE_DIP) * falling;
            if (t > STAGGER + FALL) pu.state[e] = 3;
          } else {
            clip = FLAT;
            dip = LYING;
          }
        }
        if (anim.clip[e] !== clip) anim.clip[e] = clip;
        anim.speed[e] = speed;
        // Feet on the road, turned to the kart's way.
        at.px[e] = pu.x[e];
        at.py[e] = pu.y[e] - dip;
        at.pz[e] = pu.z[e];
        at.qx[e] = 0;
        at.qy[e] = Math.sin(pu.yaw[e] / 2);
        at.qz[e] = 0;
        at.qw[e] = Math.cos(pu.yaw[e] / 2);
      }
    },
  });
}
