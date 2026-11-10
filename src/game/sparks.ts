/**
 * Sparks: metal on the road or a wall -- a lost wheel's bare axle dragging, the chassis bottoming out on a landing,
 * the kart sliding on its side or its back, a tyre or the box knocked into a wall. Each a glowing streak (`karts/spark`)
 * flung off the point it strikes, back the way the kart came and up, falling, stretched along its flight
 * (`fxMove`), gone in a moment. The same burst every time for the same seed (a hash, never the loop's chance).
 */
import { NONE, type SystemContext, Transform } from '@vibe/engine';
import { Fx } from './components.ts';
import { SparkFx } from './prefabs.ts';

type Cmd = SystemContext['cmd'];

/** Seconds a spark lives (each a share more or less), how hard they fly (m/s at `power` 1), and gravity on them. */
const LIFE = 0.32;
const FLY = 7;
/** Each burst this many times the sparks it is asked for: small ones, so more of them. */
const MORE = 1.5;
const FALL = 9.8;
/** A spark as it is born, metres: thin and short (fx.ts stretches it after). */
const BORN_THICK = 0.014;
const BORN_LONG = 0.05;

/** 0..1 from a spark's number and the burst's seed: the same for the same pair. */
function hash(n: number, seed: number): number {
  let h = (n * 374761393 + seed * 668265263) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}

/**
 * `count` sparks off (x, y, z): carried on at a share of (vx, vy, vz) -- what struck, moving -- and flung out every way
 * along the ground and up, `power` times as hard (1 a scrape, 2 a slam). They skip off the road at `ground` (metres up;
 * left out, where they start: struck on the road itself).
 */
export function sparks(cmd: Cmd, x: number, y: number, z: number, vx: number, vy: number, vz: number, count: number, power: number, seed: number, ground = y): void {
  const n = Math.round(count * MORE);
  for (let i = 0; i < n; i++) {
    const e = cmd.instantiate(SparkFx);
    if (e === NONE) return;
    const r1 = hash(i, seed), r2 = hash(i + 31, seed), r3 = hash(i + 67, seed);
    const a = r1 * Math.PI * 2;
    const out = FLY * power * (0.4 + r2 * 0.9);
    const at = cmd.init(e, Transform);
    at.px[e] = x;
    at.py[e] = y + 0.02;
    at.pz[e] = z;
    // Born a thin streak (`fxMove` stretches it along its flight from the next tick): never, for a frame, its model's
    // own size -- a metre cube, a white flash.
    at.qx[e] = at.qy[e] = at.qz[e] = 0;
    at.qw[e] = 1;
    at.sx[e] = at.sy[e] = BORN_THICK;
    at.sz[e] = BORN_LONG;
    const fx = cmd.init(e, Fx);
    fx.vx[e] = vx * 0.55 + Math.cos(a) * out;
    // Mostly skimming low along the ground, a few kicked higher.
    fx.vy[e] = Math.max(0, vy) * 0.3 + (0.3 + r3 * r3 * 2.4) * power;
    fx.vz[e] = vz * 0.55 + Math.sin(a) * out;
    fx.drag[e] = 0.6;
    fx.fall[e] = FALL;
    // (A spark's `from`: the height it skips off -- the road.)
    fx.from[e] = ground;
    fx.to[e] = 0;
    fx.life[e] = LIFE * (0.6 + r3 * 0.8);
    fx.age[e] = 0;
    fx.mark[e] = 0;
  }
}
