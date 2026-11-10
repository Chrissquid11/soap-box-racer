/**
 * A burst of shards: what a knocked-off body or a wreck flies apart into -- jagged panels, chunks, slivers, strips
 * of trim and the odd bolt (`karts/debris.lua`), each a size of its own, tinted from the colours of what broke,
 * flung out from where it broke on the kart's own speed, up, out and spinning. Debris (swept away next run).
 *
 * The scatter is the same every time for the same burst (a hash of the piece's number and a seed), never the loop's
 * chance: a replay or a test sees the same mess.
 */
import { internKey, NONE, Render, RigidBody, type SystemContext, Transform } from '@vibe/engine';
import { Shard } from './prefabs.ts';

type Cmd = SystemContext['cmd'];

const SHAPES = ['karts/debris#shard_a', 'karts/debris#shard_b', 'karts/debris#shard_c', 'karts/debris#shard_d'].map((k) => internKey('Model', k));
const BOLT = internKey('Model', 'karts/debris#bolt');
/** One piece in this many is a bolt (its own steel grey: untinted). */
const BOLT_EVERY = 6;
const UNTINTED = 0xffffff;
/** A piece's mass at the debris model's own size, kilograms (it goes as its area). */
const SHARD_MASS = 0.35;

/**
 * How exaggerated every effect is: a cartoon's, not life's. Every puff (`fx.ts`: dust, smoke, fizz, splashes, landing
 * rings) and every burst (shards, straw, confetti) is this much bigger, lasts this much longer, flies this much faster;
 * a burst has this many times the pieces (to its pool's room). A puff (dust, smoke) grows only `puff` and lasts
 * `puffLife`: more and they hang about behind the kart, filling the chasing camera's view. 1 everywhere is as built.
 */
export const FX = { size: 1.7, life: 1.4, speed: 1.35, count: 1.6, puff: 0.85, puffLife: 1 } as const;

/** 0..1 from a piece's number and the burst's seed: the same for the same pair. */
function hash(n: number, seed: number): number {
  let h = (n * 374761393 + seed * 668265263) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}

export interface Burst {
  /** Where it breaks, world metres, and how far about it the pieces start. */
  x: number;
  y: number;
  z: number;
  spread: number;
  /** The kart's speed, carried on. */
  vx: number;
  vy: number;
  vz: number;
  /** How hard the pieces fly out, m/s, and how many. */
  power: number;
  count: number;
  /** The colours of what broke: each piece one of them. */
  colours: readonly number[];
  /** The size of the biggest piece over the model's own (about 0.2 m). */
  size: number;
  seed: number;
  /** Bolts among the pieces (a kart's); false for what has none (a hay bale). */
  bolts?: boolean;
}

/** The burst's pieces made, each flying. */
export function burst(cmd: Cmd, b: Burst): void {
  const count = Math.round(b.count * FX.count);
  for (let i = 0; i < count; i++) {
    const e = cmd.instantiate(Shard);
    if (e === NONE) return;
    const r1 = hash(i, b.seed), r2 = hash(i + 101, b.seed), r3 = hash(i + 211, b.seed), r4 = hash(i + 307, b.seed);
    // Out in every direction about the middle, mostly round it and up.
    const a = r1 * Math.PI * 2;
    const up = 0.25 + r2 * 0.75;
    const out = Math.sqrt(1 - up * up);
    const dx = Math.cos(a) * out, dy = up, dz = Math.sin(a) * out;
    const at = cmd.init(e, Transform);
    at.px[e] = b.x + dx * b.spread * r3;
    at.py[e] = b.y + dy * b.spread * r3 + 0.1;
    at.pz[e] = b.z + dz * b.spread * r3;
    const turn = r4 * Math.PI;
    at.qx[e] = Math.sin(turn) * 0.6;
    at.qy[e] = Math.cos(turn) * 0.3;
    at.qz[e] = Math.sin(turn * 1.7) * 0.5;
    at.qw[e] = Math.cos(turn);
    const norm = Math.hypot(at.qx[e]!, at.qy[e]!, at.qz[e]!, at.qw[e]!) || 1;
    at.qx[e] = at.qx[e]! / norm;
    at.qy[e] = at.qy[e]! / norm;
    at.qz[e] = at.qz[e]! / norm;
    at.qw[e] = at.qw[e]! / norm;
    const bolt = b.bolts !== false && i % BOLT_EVERY === BOLT_EVERY - 1;
    const s = (bolt ? 1 : b.size * (0.55 + r3 * 0.6)) * FX.size;
    at.sx[e] = s;
    at.sy[e] = s * (0.8 + r4 * 0.4);
    at.sz[e] = s;
    const speed = b.power * (0.55 + r2 * 0.9) * FX.speed;
    const rb = cmd.init(e, RigidBody);
    // As heavy as it is big: a big panel tumbles and lands with weight, a crumb flits.
    rb.mass[e] = Math.max(0.2, SHARD_MASS * s * s);
    rb.startVelocityX[e] = b.vx * 0.75 + dx * speed;
    rb.startVelocityY[e] = Math.max(b.vy, 0) * 0.5 + dy * speed + 1.5;
    rb.startVelocityZ[e] = b.vz * 0.75 + dz * speed;
    const look = cmd.init(e, Render);
    look.model[e] = bolt ? BOLT : SHAPES[Math.floor(r1 * SHAPES.length) % SHAPES.length]!;
    look.tint[e] = bolt ? UNTINTED : b.colours[i % b.colours.length] ?? UNTINTED;
  }
}
