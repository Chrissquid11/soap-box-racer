/**
 * The effects: what a homemade kart throws up as it goes.
 *
 *   fxMove, 60 Hz       every puff and mark (`Fx`): drifted, slowed, dropped, grown or shrunk, back in its pool when
 *                       its life is up
 *   trails, 60 Hz       each kart's: dust off its wheels (in the colour of what they run on -- the road, or the grass
 *                       off it -- a trail widening with speed, a plume when they slide), curved skid marks where a
 *                       tyre slides or locks, sparks off the low side when it tips onto two wheels, a burst of dust
 *                       and a few bolts shaken loose on a hard landing, and the camera shaken with it. And each
 *                       themed kart's own: the Fizz Bomb sprays fizz on a landing, the snail leaves slime, the air
 *                       fryer bounces its chips out, the toilet splashes and trails paper when it spins, the sofa
 *                       unspools its knitting.
 *
 * Effects only: nothing here pushes anything. Kept short and behind the kart, so the road ahead stays clear.
 */
import { type Entity, Hierarchy, internKey, NONE, optional, Render, Transform, type SystemContext, type World } from '@vibe/engine';
import { BODY } from '../build.ts';
import { COURSES, TRACKS } from '../courses.ts';
import { Build, ChaseCam, Fx, Kart, PartName, PartState, Phase, Spark, Wheel } from '../components.ts';
import { sparks } from '../sparks.ts';
import { DAMAGE } from '../damage.ts';
import { Mark, Puff } from '../prefabs.ts';
import { burst, FX } from '../burst.ts';
import { liftAt } from '../track.ts';

type Cmd = SystemContext['cmd'];

/** A linear colour as the hex a tint takes (sRGB), each channel times `k`. */
function hex(c: readonly [number, number, number], k = 1): number {
  const s = (v: number): number => Math.max(0, Math.min(255, Math.round(Math.pow(Math.max(0, v * k), 1 / 2.2) * 255)));
  return (s(c[0]) << 16) | (s(c[1]) << 8) | s(c[2]);
}
/** Each course's dust (its road's, paler), its grass's, and its skid marks' (its road's, darker). */
const DUST = COURSES.map((c) => hex(c.road, 1.6));
const GRASS = COURSES.map((c) => hex(c.grass, 1.1));
const SKID = COURSES.map((c) => hex(c.road, 0.35));

/** Under this speed (m/s), no dust trail; the trail's puffs every so many ticks a rear wheel, by speed. */
const DUST_FROM = 4;
/** Sliding faster than this (m/s) across, a tyre throws a plume and lays a skid mark (every MARK_EVERY metres). */
const SLIDE = 2.2;
const MARK_EVERY = 0.7;
const MARK_LIFE = 4;
/** Tipped this far (its up this little), it is on two wheels: sparks off the low side. */
const TIPPED = 0.82;
/** A landing from this long in the air shakes bolts loose; and the camera's shake a second of air. */
const BOLTS_FROM = 0.7;
const SHAKE_PER_AIR = 0.35;
/** How fast the camera's shake eases out, a tick. */
const SHAKE_EASE = 0.04;

/** The themed bodies, by their index in BODY: the kart each effect is for. */
const FIZZ = BODY.findIndex((b) => b.name === 'Fizz Bomb');
const SNAIL = BODY.findIndex((b) => b.name === 'Escargot Fast');
const FRYER = BODY.findIndex((b) => b.name === 'Air Fryer Force One');
const TOILET = BODY.findIndex((b) => b.name === 'Bog Standard');
const SOFA = BODY.findIndex((b) => b.name === 'Couch Potato');
const FIZZ_COLOURS = [0x2a5ce8, 0xffffff, 0xd4e4ff] as const;
const SLIME = 0x7ee05a;
const YARN = 0xd23a3a;
const PAPER = 0xf4f4ee;
const SPLASH = 0x3fa8ff;
const CHIPS = [0xf2c14e, 0xe0a83a, 0xf7d77a] as const;

/** 0..1, the same for the same pair: the scatter of a puff. */
function jitter(a: number, b: number): number {
  const s = Math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
  return s - Math.floor(s);
}

/** A puff at (x, y, z) drifting (vx, vy, vz), from `from` to `to` metres across over `life` seconds, tinted. */
export function puff(cmd: Cmd, x: number, y: number, z: number, vx: number, vy: number, vz: number, from: number, to: number, life: number, tint: number, fall = 0.4, fade = false): Entity {
  const e = cmd.instantiate(Puff);
  if (e === NONE) return NONE;
  const at = cmd.init(e, Transform);
  at.px[e] = x;
  at.py[e] = y;
  at.pz[e] = z;
  // Exaggerated (`burst.ts`' FX): bigger, longer, faster.
  at.sx[e] = at.sy[e] = at.sz[e] = from * FX.puff;
  const fx = cmd.init(e, Fx);
  fx.vx[e] = vx * FX.speed;
  fx.vy[e] = vy * FX.speed;
  fx.vz[e] = vz * FX.speed;
  fx.drag[e] = 2.5;
  fx.fall[e] = fall;
  fx.from[e] = from * FX.puff;
  fx.to[e] = to * FX.puff;
  fx.life[e] = life * FX.puffLife;
  fx.age[e] = 0;
  fx.mark[e] = 0;
  fx.fade[e] = fade ? 1 : 0;
  const view = cmd.init(e, Render);
  view.tint[e] = tint;
  view.material[e] = DUST_MATERIAL;   // (a pooled puff may come back from a fade)
  return e;
}

/** A skid mark on the road at (x, y, z), along heading `yaw`, `w` wide and `l` long, tinted. */
function mark(cmd: Cmd, x: number, y: number, z: number, yaw: number, w: number, l: number, tint: number): void {
  const e = cmd.instantiate(Mark);
  if (e === NONE) return;
  const at = cmd.init(e, Transform);
  at.px[e] = x;
  at.py[e] = y + 0.012;
  at.pz[e] = z;
  at.qx[e] = 0;
  at.qy[e] = Math.sin(yaw / 2);
  at.qz[e] = 0;
  at.qw[e] = Math.cos(yaw / 2);
  at.sx[e] = w;
  at.sy[e] = 1;
  at.sz[e] = l;
  const fx = cmd.init(e, Fx);
  fx.vx[e] = fx.vy[e] = fx.vz[e] = 0;
  fx.drag[e] = 0;
  fx.fall[e] = 0;
  fx.from[e] = w;
  fx.to[e] = w;
  fx.life[e] = MARK_LIFE;
  fx.age[e] = 0;
  fx.mark[e] = 1;
  cmd.init(e, Render).tint[e] = tint;
}

/** On its side or its back (its up no more than this) with its middle this near the road, metres: grinding along it. */
const SIDE_UP = 0.5;
const GRINDING = 0.95;

/** A spark's streak: its thickness, its least length, and its length more for each m/s it flies (metres). */
const SPARK_THICK = 0.014;
/** What a spark keeps of its fall as it skips off the road. */
const SPARK_BOUNCE = 0.35;
const SPARK_LONG = 0.02;
const SPARK_STRETCH = 0.016;

/** Metres from the chasing camera inside which a puff shrinks away: it drives through the dust the kart leaves, and
 * a puff in its face would fill the screen. */
const CLEAR_OF_CAMERA = 3;

/** A fading puff (`Fx.fade`): the dust as it starts, then fainter and fainter (materials/fx/dust-fade*) from FADE_FROM
 * of its life on; and the least it shrinks to by its end, a share of its size. */
const DUST_MATERIAL = internKey('Material', 'fx/dust');
const FADES = [1, 2, 3, 4, 5].map((i) => internKey('Material', `fx/dust-fade${i}`));
const FADE_FROM = 0.4;
const FADE_SHRINK = 0.85;

export function fxMove(world: World): void {
  const cameras = world.query({ with: [ChaseCam, Transform] });
  world.system({
    name: 'fxMove',
    rate: 60,
    write: [Fx, Transform, optional(Render)],
    update({ members, count, dt, cmd, has }, _read, [fx, at, look]) {
      const cam = cameras.count > 0 ? cameras.members[0]! : 0;
      const cx = cam !== 0 ? at.px[cam]! : 0, cy = cam !== 0 ? at.py[cam]! : 0, cz = cam !== 0 ? at.pz[cam]! : 0;
      for (let n = 0; n < count; n++) {
        const e = members[n];
        fx.age[e] += dt;
        const t = fx.age[e] / Math.max(0.01, fx.life[e]);
        if (t >= 1) {
          cmd.destroy(e);
          continue;
        }
        if (fx.mark[e]) {
          // A mark stays as laid, then thins away over its last tenth.
          if (t > 0.9) at.sx[e] = fx.from[e] * (1 - (t - 0.9) * 10);
          continue;
        }
        const slow = Math.max(0, 1 - fx.drag[e] * dt);
        fx.vx[e] *= slow;
        fx.vz[e] *= slow;
        fx.vy[e] = fx.vy[e] * slow - fx.fall[e] * dt;
        at.px[e] += fx.vx[e] * dt;
        at.py[e] += fx.vy[e] * dt;
        at.pz[e] += fx.vz[e] * dt;
        if (has(e, Spark)) {
          // Skipping off the road it was struck from (`Fx.from`: that height): a low bounce, most of its speed lost.
          if (at.py[e] < fx.from[e] && fx.vy[e] < 0) {
            at.py[e] = fx.from[e];
            fx.vy[e] = -fx.vy[e] * SPARK_BOUNCE;
            fx.vx[e] *= 0.6;
            fx.vz[e] *= 0.6;
          }
          // A streak along its flight: the faster, the longer; thinning as it dies.
          const vx = fx.vx[e], vy = fx.vy[e], vz = fx.vz[e];
          const flat = Math.hypot(vx, vz);
          const speed = Math.hypot(flat, vy);
          const yaw = Math.atan2(vx, vz), pitch = -Math.atan2(vy, Math.max(1e-4, flat));
          const sy = Math.sin(yaw / 2), cy = Math.cos(yaw / 2), sp = Math.sin(pitch / 2), cp = Math.cos(pitch / 2);
          at.qx[e] = cy * sp;
          at.qy[e] = sy * cp;
          at.qz[e] = -sy * sp;
          at.qw[e] = cy * cp;
          const thin = SPARK_THICK * (1 - t * 0.7);
          at.sx[e] = at.sy[e] = thin;
          at.sz[e] = SPARK_LONG + speed * SPARK_STRETCH;
          continue;
        }
        // Grows from its first size to its last, and over its last third shrinks away to nothing.
        const s = fx.from[e] + (fx.to[e] - fx.from[e]) * Math.min(1, t * 1.5);
        let k = t > 0.66 ? (1 - t) / 0.34 : 1;
        if (fx.fade[e]) {
          // Fading: hardly shrinking, fainter step by step through its last stretch.
          k = 1 - (1 - FADE_SHRINK) * t;
          const step = t < FADE_FROM ? -1 : Math.min(FADES.length - 1, Math.floor(((t - FADE_FROM) / (1 - FADE_FROM)) * FADES.length));
          if (has(e, Render)) look.material[e] = step < 0 ? DUST_MATERIAL : FADES[step]!;
        }
        // Near the camera, away to nothing: never a wall of dust across the view.
        if (cam !== 0) {
          const d = Math.hypot(at.px[e] - cx, at.py[e] - cy, at.pz[e] - cz);
          if (d < CLEAR_OF_CAMERA) k *= Math.max(0, (d - 0.5) / (CLEAR_OF_CAMERA - 0.5));
        }
        at.sx[e] = at.sy[e] = at.sz[e] = Math.max(0.001, s * k);
      }
    },
  });
}

export function trails(world: World): void {
  world.system({
    name: 'trails',
    rate: 60,
    after: ['vehicle'],
    read: [Hierarchy, Build, Transform],
    write: [Kart, optional(Wheel)],
    update({ members, count, cmd, has, time }, [tree, build, at], [kart, wheel]) {
      const tick = Math.round(time * 60);
      for (let n = 0; n < count; n++) {
        const e = members[n];
        kart.shake[e] = Math.max(0, kart.shake[e] - SHAKE_EASE);
        const phase = kart.phase[e];
        if (phase !== Phase.racing && phase !== Phase.finished) {
          kart.landed[e] = 0;
          continue;
        }
        const c = Math.min(kart.course[e], COURSES.length - 1);
        const t = TRACKS[c]!;
        const speed = kart.speed[e];
        const vx = kart.lastVX[e], vz = kart.lastVZ[e];
        const heading = Math.atan2(vx, vz);
        const body = build.body[e];
        // The Fizz Bomb's can dented (`damage.ts`): a short spray of fizz out of the dent, a few puffs a tick.
        if (body === FIZZ && kart.callPart[e] === PartName.body && kart.callState[e] === PartState.damaged && kart.clock[e] - kart.callAt[e] < DAMAGE.fizzFor) {
          for (let s = 0; s < 3; s++) {
            const r = jitter(tick, s + 140), q = jitter(tick, s + 150);
            puff(cmd, at.px[e] + (r - 0.5) * 0.3, at.py[e] + 0.8, at.pz[e] + (q - 0.5) * 0.3, (r - 0.5) * 4 + vx * 0.5, 2.5 + q * 3, (q - 0.5) * 4 + vz * 0.5, 0.08, 0.3, 0.8, FIZZ_COLOURS[(tick + s) % 3]!, 5);
          }
        }
        // On the road or off it, by where the kart is across it.
        const j = Math.max(0, Math.min(t.samples - 1, Math.round(kart.progress[e])));
        const across = (at.px[e] - t.sx[j]!) * -t.tz[j]! + (at.pz[e] - t.sz[j]!) * t.tx[j]!;
        const off = Math.abs(across) > t.hw[j]!;
        const dust = off ? GRASS[c]! : DUST[c]!;
        let low = 0;
        let lowX = 0, lowY = 0, lowZ = 0;
        for (let w = tree.firstChild[e]; w !== 0; w = tree.nextSibling[w]) {
          if (!has(w, Wheel) || !wheel.attached[w]) continue;
          if (!wheel.grounded[w]) continue;
          low++;
          lowX += wheel.hitX[w];
          lowY += wheel.hitY[w];
          lowZ += wheel.hitZ[w];
          const corner = wheel.corner[w];
          const rear = corner >= 2;
          const x = wheel.hitX[w], y = wheel.hitY[w], z = wheel.hitZ[w];
          const r1 = jitter(tick, corner), r2 = jitter(tick + 17, corner);
          // The trail: off the rear wheels, more and bigger the faster it goes.
          const every = speed > 14 ? 4 : speed > 9 ? 6 : speed > DUST_FROM ? 9 : 0;
          if (rear && every > 0 && (tick + corner * 3) % every === 0) {
            const grow = Math.min(1, speed / 18);
            puff(cmd, x, y + 0.06, z, -vx * 0.12 + (r1 - 0.5) * 0.8, 0.5 + r2 * 0.6, -vz * 0.12 + (r2 - 0.5) * 0.8,
              0.12, 0.45 + grow * 0.7, 0.55 + grow * 0.4, dust);
          }
          const slip = wheel.slip[w];
          if (slip > SLIDE) {
            // A plume thrown out sideways, and a skid mark laid where it slides.
            if ((tick + corner) % 4 === 0) {
              puff(cmd, x, y + 0.08, z, -vx * 0.1 + (r1 - 0.5) * slip * 0.5, 0.7 + r2, -vz * 0.1 + (r2 - 0.5) * slip * 0.5,
                0.18, 0.6 + Math.min(0.8, slip * 0.08), 0.7, dust);
            }
            const dx = x - wheel.markX[w], dz = z - wheel.markZ[w];
            if (dx * dx + dz * dz > MARK_EVERY * MARK_EVERY) {
              wheel.markX[w] = x;
              wheel.markZ[w] = z;
              const ink = body === SNAIL ? SLIME : body === SOFA ? YARN : body === TOILET ? PAPER : off ? GRASS[c]! : SKID[c]!;
              const wide = body === SNAIL ? 0.3 : 0.13;
              mark(cmd, x, y, z, heading, wide, MARK_EVERY * 1.25, ink);
            }
          } else {
            wheel.markX[w] = x;
            wheel.markZ[w] = z;
          }
        }
        // Up on two wheels: sparks off the low side, where the chassis scrapes.
        if (kart.upY[e] < TIPPED && low > 0 && low <= 2 && speed > 4 && tick % 2 === 0) {
          const sx = lowX / low, sy = lowY / low, sz = lowZ / low;
          sparks(cmd, sx, sy, sz, -vx * 0.5, 0, -vz * 0.5, 4, 1.2, tick);
        }
        // On its side or its back and sliding: the chassis grinding along the road, sparks all the way.
        if (kart.upY[e] < SIDE_UP && low === 0 && speed > 2.5 && tick % 2 === 0) {
          const ground = t.sy[j]! + liftAt(t, j, across);
          if (at.py[e] - ground < GRINDING) sparks(cmd, at.px[e], ground, at.pz[e], -vx * 0.4, 0, -vz * 0.4, 3 + Math.min(4, Math.floor(speed / 4)), 1.3, tick + 7);
        }
        // The toilet, spinning: a splash, and a ribbon of paper behind.
        if (body === TOILET && Math.abs(kart.lastWY[e]) > 3 && tick % 3 === 0) {
          puff(cmd, at.px[e], at.py[e] + 0.4, at.pz[e], (jitter(tick, 3) - 0.5) * 3, 1.5, (jitter(tick, 4) - 0.5) * 3, 0.15, 0.4, 0.6, SPLASH, 6);
          mark(cmd, at.px[e], t.sy[j]! + liftAt(t, j, across), at.pz[e], heading, 0.14, 0.5, PAPER);
        }
        // A landing: dust off every wheel; harder, bolts shaken loose and the camera with it; the themed karts' own.
        const air = kart.landed[e];
        if (air > 0) {
          kart.landed[e] = 0;
          kart.shake[e] = Math.max(kart.shake[e], Math.min(1, air * SHAKE_PER_AIR));
          const x = at.px[e], y = at.py[e] - kart.rideY[e] + 0.1, z = at.pz[e];
          for (let s = 0; s < 6; s++) {
            const a = (s / 6) * Math.PI * 2;
            puff(cmd, x + Math.cos(a) * 0.6, y, z + Math.sin(a) * 0.9, Math.cos(a) * 2.5 - vx * 0.1, 0.4, Math.sin(a) * 2.5 - vz * 0.1, 0.2, 0.9, 0.8, dust);
          }
          if (air > BOLTS_FROM) {
            burst(cmd, { x, y: y + 0.3, z, spread: 0.4, vx: vx * 0.5, vy: 0, vz: vz * 0.5, power: 2.5, count: 6, colours: [0x9aa0a8], size: 0.5, seed: tick, bolts: true });
          }
          if (body === FIZZ) {
            // The can, shaken: fizz from its pull tab, straight up and everywhere.
            for (let s = 0; s < 16; s++) {
              const r = jitter(tick, s + 60), q = jitter(tick, s + 80);
              puff(cmd, x, y + 0.9, z, (r - 0.5) * 3, 3 + q * 4, (q - 0.5) * 3, 0.1, 0.35, 0.9, FIZZ_COLOURS[s % 3]!, 5);
            }
          } else if (body === FRYER && air > BOLTS_FROM * 0.7) {
            burst(cmd, { x, y: y + 0.7, z, spread: 0.3, vx: vx * 0.6, vy: 0, vz: vz * 0.6, power: 3, count: 10, colours: CHIPS, size: 0.55, seed: tick + 5, bolts: false });
          } else if (body === TOILET) {
            for (let s = 0; s < 10; s++) {
              const r = jitter(tick, s + 90);
              puff(cmd, x, y + 0.6, z, (r - 0.5) * 3, 2 + r * 2, (jitter(tick, s + 99) - 0.5) * 3, 0.12, 0.35, 0.7, SPLASH, 7);
            }
          }
        }
      }
    },
  });
}
