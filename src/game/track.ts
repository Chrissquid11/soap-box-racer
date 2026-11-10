/**
 * A course's centre line, as numbers: the Catmull-Rom curve through its control points that its Gladius
 * script (`AssetsSource/models/courses/_course.lua`) builds the road along, `SUB` samples a segment.
 * Each course's `Track` is sampled once, at module level, into constant arrays (`courses.ts` makes them
 * all); the systems measure the race along it (`progressAt`), and place the kart on its start line
 * (`headingAt`). Nothing here holds the world.
 */

/** Samples a segment between two control points: the Lua library's SUB too. */
export const SUB = 10;

/** One course's centre line, sampled. */
export interface Track {
  /** How many samples; the start line's and the finish line's. */
  readonly samples: number;
  readonly start: number;
  readonly finish: number;
  /** Half the road's width, metres, as designed: its width at the start and the finish (and at a shortcut's
   * junctions); between them the road narrows and widens about it (`hw`, `widthProfile`). */
  readonly halfWidth: number;
  /** Each sample's half width, metres: what the road is there (`halfWidthAt` between samples). */
  readonly hw: Float32Array;
  /** Each sample's position, and its flat unit direction down the road. */
  readonly sx: Float32Array;
  readonly sy: Float32Array;
  readonly sz: Float32Array;
  readonly tx: Float32Array;
  readonly tz: Float32Array;
  /** Each sample's berm: how far its outside edge is built up, metres -- + the right edge (across +), - the left --
   * the road sloping straight up to it from its inside edge, which stays at the centre line's height. */
  readonly bank: Float32Array;
  /** Its shortcut, measured (`withShortcut`), or null. */
  readonly cut: Cut | null;
}

/**
 * A course's shortcut as the race measures it: a straight road from the main road's sample `from` to its sample `to`
 * (a, b: the main road's centre there), `len` metres long, (ux, uz) its flat unit direction; the places along it
 * (shares of its length) of the pond's gap, the jump's lip (the gap's start) and the rough landing.
 */
export interface Cut {
  readonly from: number;
  readonly to: number;
  readonly ax: number; readonly ay: number; readonly az: number;
  readonly bx: number; readonly by: number; readonly bz: number;
  readonly ux: number; readonly uz: number;
  readonly len: number;
  readonly halfWidth: number;
  readonly pondFrom: number;
  readonly pondTo: number;
  readonly roughFrom: number;
  readonly roughTo: number;
  readonly jump: number;
}

/** A track with its shortcut measured onto it (none: as it was). */
export function withShortcut(track: Track, s: { from: number; to: number; halfWidth: number; pondFrom: number; pondTo: number; roughFrom: number; roughTo: number; jump: number } | null): Track {
  if (!s) return track;
  const ax = track.sx[s.from]!, az = track.sz[s.from]!;
  const bx = track.sx[s.to]!, bz = track.sz[s.to]!;
  const len = Math.hypot(bx - ax, bz - az) || 1;
  const ux = (bx - ax) / len, uz = (bz - az) / len;
  // Its road a straight slope, meeting the main road's surface just where its middle leaves the main road's edge and
  // where it comes back over it (so neither a step nor a lip there; over the main road it is drawn under it).
  const edge = (from: number, step: number): [number, number] => {
    let u = from;
    for (let k = 0; k < 400; k++, u += step) {
      const m = mainUnder(track, ax + ux * len * u, az + uz * len * u);
      if (m === null) return [u, mainUnder(track, ax + ux * len * (u - step), az + uz * len * (u - step)) ?? track.sy[s.from]!];
    }
    return [from, track.sy[s.from]!];
  };
  const [u0, y0] = edge(0, 0.002);
  const [u1, y1] = edge(1, -0.002);
  const slope = (y1 - y0) / Math.max(0.01, u1 - u0);
  const ay = y0 - slope * u0, by = y1 + slope * (1 - u1);
  return { ...track, cut: { ...s, ax, ay, az, bx, by, bz, ux, uz, len } };
}

/** The main road's surface under (x, z), or null where (x, z) is off it (beyond its edge). */
export function mainUnder(track: Track, x: number, z: number): number | null {
  mainSpot(track, x, z, SPOT);
  return Math.abs(SPOT.across) > SPOT.hw ? null : SPOT.y;
}

const SPOT = { across: 0, y: 0, hw: 0 };
/** Where (x, z) is against the main road: how far across it (metres, + right), the road's half width there and its
 * surface (its height between the two nearest samples, as the road is built: no steps), `across` held to the road's
 * edges for it. */
function mainSpot(track: Track, x: number, z: number, out: { across: number; y: number; hw: number }): void {
  const i = nearestSample(track, x, z);
  const along = (x - track.sx[i]!) * track.tx[i]! + (z - track.sz[i]!) * track.tz[i]!;
  const j = Math.max(0, Math.min(track.samples - 1, along >= 0 ? i + 1 : i - 1));
  const seg = Math.hypot(track.sx[j]! - track.sx[i]!, track.sz[j]! - track.sz[i]!) || 1;
  const f = j === i ? 0 : Math.min(1, Math.abs(along) / seg);
  const ai = (x - track.sx[i]!) * -track.tz[i]! + (z - track.sz[i]!) * track.tx[i]!;
  const aj = (x - track.sx[j]!) * -track.tz[j]! + (z - track.sz[j]!) * track.tx[j]!;
  out.across = ai + (aj - ai) * f;
  out.hw = track.hw[i]! + (track.hw[j]! - track.hw[i]!) * f;
  const held = Math.max(-out.hw, Math.min(out.hw, out.across));
  out.y = (track.sy[i]! + liftAt(track, i, held)) * (1 - f) + (track.sy[j]! + liftAt(track, j, held)) * f;
}

function nearestSample(track: Track, x: number, z: number): number {
  let best = 0, bd = Infinity;
  for (let i = 0; i < track.samples; i++) {
    const d = (track.sx[i]! - x) ** 2 + (track.sz[i]! - z) ** 2;
    if (d < bd) {
      bd = d;
      best = i;
    }
  }
  return best;
}

/** At each end of a shortcut the main road's wall on the shortcut's side is left out for this many samples either
 * way: a wide mouth where the roads part and meet, no wall nose between them to catch a kart. */
export const CUT_MOUTH = 8;
/** Whether the main road's wall at sample `i`, on its `side` (-1 left, +1 right), is left out for the shortcut: where
 * it runs through it, or in a mouth at either end on the shortcut's side. The course model (`_course.lua`) builds it
 * so. */
export function cutOpening(track: Track, i: number, side: number, x: number, z: number): boolean {
  const c = track.cut;
  if (c === null) return false;
  const u = ((x - c.ax) * c.ux + (z - c.az) * c.uz) / c.len;
  const d = (x - c.ax) * -c.uz + (z - c.az) * c.ux;
  if (u > -0.02 && u < 1.02 && Math.abs(d) < c.halfWidth + 0.6) return true;
  for (const [end, k] of [[c.from, 0.15], [c.to, 0.85]] as const) {
    if (Math.abs(i - end) > CUT_MOUTH) continue;
    // Which side of the road here the shortcut lies.
    const px = c.ax + c.ux * c.len * k, pz = c.az + c.uz * c.len * k;
    const across = (px - track.sx[i]!) * -track.tz[i]! + (pz - track.sz[i]!) * track.tx[i]!;
    if (Math.sign(across) === side) return true;
  }
  return false;
}

/** Over this many metres off the main road's edge the shortcut's road eases from the main road's height to its own
 * slope: no step where the two meet at an angle. */
export const CUT_BLEND = 6;
/**
 * The shortcut's road's height at (x, z), `u` its share along it: level across, its middle on its straight slope --
 * eased, near the main road, into the main road's surface (carried on past its edge) -- and where it lies over the main
 * road, never above it (a hair under it there: the main road is what is driven on). The course model (`_course.lua`)
 * builds it so; the race measures it so.
 */
export function cutSurface(track: Track, x: number, z: number, u: number): number {
  const c = track.cut!;
  const k = Math.max(0, Math.min(1, u));
  const mx = c.ax + c.ux * c.len * k, mz = c.az + c.uz * c.len * k;
  const line = c.ay + (c.by - c.ay) * k;
  mainSpot(track, mx, mz, SPOT);
  const out = Math.abs(SPOT.across) - SPOT.hw;
  const edge = SPOT.y;
  const w = Math.max(0, Math.min(1, 1 - out / CUT_BLEND));
  const ease = w * w * (3 - 2 * w);
  const level = edge * ease + line * (1 - ease);
  const main = mainUnder(track, x, z);
  return main === null ? level : Math.min(level, main);
}

/** Where a kart is on its course (`routeAt`): its progress (samples, on either route), how far across the road it
 * is from the middle of the one it is on (metres, + right), that road's half width and its height under it there; on
 * the shortcut or not, and how far along the shortcut (a share). */
export interface Route {
  progress: number;
  across: number;
  halfWidth: number;
  surface: number;
  onCut: boolean;
  u: number;
}
export function newRoute(): Route {
  return { progress: 0, across: 0, halfWidth: 0, surface: 0, onCut: false, u: 0 };
}

/**
 * Where (x, z) is on the course: on the main road (its progress and across, as `progressAt`), or -- off the main road
 * and on the shortcut's corridor -- on the shortcut, its progress the share of the way along it between the samples it
 * joins (so the race counts either route the same, and neither skips any of it). `hint` as `progressAt`'s.
 */
export function routeAt(track: Track, x: number, z: number, hint: number, out: Route): Route {
  const p = progressAt(track, x, z, hint);
  const j = Math.max(0, Math.min(track.samples - 1, Math.round(p)));
  const across = (x - track.sx[j]!) * -track.tz[j]! + (z - track.sz[j]!) * track.tx[j]!;
  out.progress = p;
  out.across = across;
  out.halfWidth = halfWidthAt(track, p);
  out.surface = track.sy[j]! + liftAt(track, j, across);
  out.onCut = false;
  out.u = 0;
  const c = track.cut;
  if (c === null || Math.abs(across) <= out.halfWidth + 0.5) return out;
  const u = ((x - c.ax) * c.ux + (z - c.az) * c.uz) / c.len;
  const d = (x - c.ax) * -c.uz + (z - c.az) * c.ux;
  // On the shortcut's corridor (or near enough it to be judged by it) and nearer its middle than the main road's.
  if (u < 0 || u > 1 || Math.abs(d) > c.halfWidth + 3 || Math.abs(d) >= Math.abs(across)) return out;
  // Only from where the main road last was round the shortcut's start (no jumping onto it from elsewhere).
  if (hint >= 0 && (hint < c.from - 12 || hint > c.to + 2)) return out;
  out.progress = c.from + u * (c.to - c.from);
  out.across = d;
  out.halfWidth = c.halfWidth;
  out.surface = cutSurface(track, x, z, u);
  out.onCut = true;
  out.u = u;
  return out;
}

/** How far over the centre line's height the road is at `across` metres from its middle (+ right) at sample `i`: its berm. */
export function liftAt(track: Track, i: number, across: number): number {
  const k = Math.max(0, Math.min(track.samples - 1, Math.round(i)));
  const b = track.bank[k]!;
  if (b === 0) return 0;
  const a = Math.max(-1, Math.min(1, across / track.hw[k]!));
  return b > 0 ? (b * (a + 1)) / 2 : (-b * (1 - a)) / 2;
}

function catmull(p0: number, p1: number, p2: number, p3: number, t: number): number {
  const t2 = t * t;
  const t3 = t2 * t;
  return 0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3);
}

/** The road's half width at `progress` (a sample, with a fraction): between the two samples either side of it. */
export function halfWidthAt(track: Track, progress: number): number {
  const p = Math.max(0, Math.min(track.samples - 1, progress));
  const i = Math.min(track.samples - 2, Math.floor(p));
  if (i < 0) return track.hw[0]!;
  return track.hw[i]! + (track.hw[i + 1]! - track.hw[i]!) * (p - i);
}

/** The narrowest and the widest a course's road gets, as shares of its designed half width (`widthProfile`). */
export const WIDTH_LEAST = 0.72;
export const WIDTH_MOST = 1.08;
/** The road keeps its designed width this far past the start line (metres; and at least two segments: the start
 * ramp's plunge and the run off it), from this far before the finish line to the end, and this far either side of a
 * span the caller keeps (a shortcut's junction); a stretch the caller levels (a jump, a ramp ...) is held at one width
 * this far beyond its ends. */
const WIDTH_START_KEEP = 40;
const WIDTH_FINISH_KEEP = 45;
const WIDTH_KEEP_PAD = 25;
const WIDTH_LEVEL_PAD = 4;
/** Two held stretches nearer than this (metres) are held as one: the road never changes width in a hurry between. */
const WIDTH_MIN_GAP = 15;
/** Two held stretches' widths differ by no more than this share of the designed width a metre of road between them. */
const WIDTH_RATE = 0.006;
/** Off a held stretch the road eases into its own wander over this many metres. */
const WIDTH_EASE = 40;

/**
 * Each sample's share of the course's designed half width: the road wandering narrower and a little wider along the
 * course -- two slow waves (one long, one shorter) of its own, `seed`'s, over the metres of road, down to `least` (WIDTH_LEAST unless told)
 * at its narrowest and up to WIDTH_MOST at its widest -- never changing in a hurry (over tens of metres). Exactly 1
 * over the start (its grid, its ramp) and the last stretch to the finish and the run-out, and over each of `keep`
 * (sample spans: a shortcut's junctions, so its geometry still meets); and level -- one width from end to end -- over
 * each of `level` (what is laid across the road -- its middle sample and half its length, metres -- so it fits the
 * road all along it). Between held stretches the road eases from one's width to the next's, wandering on its own way
 * in between. Pure: the course's script (`_course.lua`) is handed the answer (`scripts/courses.ts`), so the road and
 * its walls are built as wide as the race measures them.
 */
export function widthProfile(track: Track, seed: number, keep: readonly (readonly [number, number])[] = [], level: readonly { readonly sample: number; readonly half: number }[] = [], least = WIDTH_LEAST): number[] {
  const n = track.samples;
  const along = new Float64Array(n);
  for (let i = 1; i < n; i++) along[i] = along[i - 1]! + Math.hypot(track.sx[i]! - track.sx[i - 1]!, track.sy[i]! - track.sy[i - 1]!, track.sz[i]! - track.sz[i - 1]!);
  const at = (i: number): number => along[Math.max(0, Math.min(n - 1, Math.round(i)))]!;
  // The waves: their lengths and phases drawn from the seed (a stable hash, no generator to keep in step).
  const h = (k: number): number => {
    const s = Math.sin(seed * 12.9898 + k * 78.233) * 43758.5453;
    return s - Math.floor(s);
  };
  const long = 200 + 80 * h(1), short = 100 + 40 * h(2);
  const p1 = h(3) * Math.PI * 2, p2 = h(4) * Math.PI * 2;
  const wave = (m: number): number => 0.65 * Math.sin((m / long) * Math.PI * 2 + p1) + 0.35 * Math.sin((m / short) * Math.PI * 2 + p2);
  const from = Math.max(at(track.start) + WIDTH_START_KEEP, at(track.start + 2 * SUB));
  const to = at(track.finish) - WIDTH_FINISH_KEEP;
  // Stretched so each course reaches both its narrowest and its widest somewhere between start and finish.
  let lo = -1e-6, hi = 1e-6;
  for (let i = 0; i < n; i++) {
    if (along[i]! < from || along[i]! > to) continue;
    const w = wave(along[i]!);
    lo = Math.min(lo, w);
    hi = Math.max(hi, w);
  }
  const raw = (m: number): number => {
    const w = wave(m);
    return w < 0 ? 1 + (1 - least) * (w / -lo) : 1 + (WIDTH_MOST - 1) * (w / hi);
  };
  // The held stretches, in metres: the start and the finish kept, the caller's kept and levelled; then joined where
  // they overlap or come near (a kept one keeping the whole), each held at one width.
  interface Held { a: number; b: number; kept: boolean }
  const held: Held[] = [{ a: -Infinity, b: from, kept: true }, { a: to, b: Infinity, kept: true }];
  for (const [s0, s1] of keep) held.push({ a: at(s0) - WIDTH_KEEP_PAD, b: at(s1) + WIDTH_KEEP_PAD, kept: true });
  for (const l of level) held.push({ a: at(l.sample) - l.half - WIDTH_LEVEL_PAD, b: at(l.sample) + l.half + WIDTH_LEVEL_PAD, kept: false });
  held.sort((x, y) => x.a - y.a);
  const joined: Held[] = [];
  for (const s of held) {
    const last = joined[joined.length - 1];
    if (last && s.a - last.b < WIDTH_MIN_GAP) {
      last.b = Math.max(last.b, s.b);
      last.kept ||= s.kept;
    } else joined.push({ ...s });
  }
  const value = joined.map((s) => (s.kept ? 1 : raw((s.a + s.b) / 2)));
  // Neighbouring held stretches' widths drawn together where the road between them is short (no more apart than
  // WIDTH_RATE a metre of it): each way along, a few times over, the kept ones never moved.
  for (let pass = 0; pass < 3; pass++) {
    for (const dir of [1, -1]) {
      for (let q = dir > 0 ? 1 : joined.length - 2; q >= 0 && q < joined.length; q += dir) {
        const o = q - dir;
        if (joined[q]!.kept || o < 0 || o >= joined.length) continue;
        const room = WIDTH_RATE * (dir > 0 ? joined[q]!.a - joined[o]!.b : joined[o]!.a - joined[q]!.b);
        value[q] = Math.max(value[o]! - room, Math.min(value[o]! + room, value[q]!));
      }
    }
  }
  const smooth = (x: number): number => {
    const t = Math.max(0, Math.min(1, x));
    return t * t * (3 - 2 * t);
  };
  const out: number[] = new Array(n);
  let k = 0;
  for (let i = 0; i < n; i++) {
    const m = along[i]!;
    while (k + 1 < joined.length && joined[k + 1]!.a <= m) k++;
    const s = joined[k]!;
    let f: number;
    if (m <= s.b) f = value[k]!;
    else {
      // Between held stretch k and the next: from one's width to the next's, the road's own wander eased in between.
      const next = joined[k + 1]!;
      const gap = next.a - s.b;
      const t = (m - s.b) / gap;
      const base = value[k]! + (value[k + 1]! - value[k]!) * smooth(t);
      const free = smooth((Math.min(m - s.b, next.a - m)) / WIDTH_EASE);
      f = base + (raw(m) - base) * free;
    }
    out[i] = Math.round(Math.max(WIDTH_LEAST, Math.min(WIDTH_MOST, f)) * 1000) / 1000;
  }
  return out;
}

/** A track sampled from its control points: the start line at `startPoint`, the finish at `finishPoint` (indices);
 * `widths` each sample's share of `halfWidth` (`widthProfile`; none: the designed width all along). */
export function sampleTrack(points: readonly (readonly [number, number, number])[], halfWidth: number, startPoint: number, finishPoint: number, berms: readonly number[] = [], widths: readonly number[] = []): Track {
  const n = points.length;
  const samples = (n - 1) * SUB + 1;
  const sx = new Float32Array(samples);
  const sy = new Float32Array(samples);
  const sz = new Float32Array(samples);
  const tx = new Float32Array(samples);
  const tz = new Float32Array(samples);
  const point = (i: number, axis: number): number => points[Math.min(n - 1, Math.max(0, i))]![axis]!;
  let k = 0;
  for (let i = 0; i < n - 1; i++) {
    for (let s = 0; s < SUB; s++) {
      const t = s / SUB;
      sx[k] = catmull(point(i - 1, 0), point(i, 0), point(i + 1, 0), point(i + 2, 0), t);
      sy[k] = catmull(point(i - 1, 1), point(i, 1), point(i + 1, 1), point(i + 2, 1), t);
      sz[k] = catmull(point(i - 1, 2), point(i, 2), point(i + 1, 2), point(i + 2, 2), t);
      k++;
    }
  }
  sx[k] = point(n - 1, 0);
  sy[k] = point(n - 1, 1);
  sz[k] = point(n - 1, 2);
  for (let i = 0; i < samples; i++) {
    const a = Math.max(0, i - 1);
    const b = Math.min(samples - 1, i + 1);
    const dx = sx[b]! - sx[a]!;
    const dz = sz[b]! - sz[a]!;
    const d = Math.hypot(dx, dz) || 1;
    tx[i] = dx / d;
    tz[i] = dz / d;
  }
  // The berms, each point's, straight from one point's to the next's along the samples (as `_course.lua` builds them).
  const bank = new Float32Array(samples);
  for (let i = 0; i < samples; i++) {
    const p = Math.floor(i / SUB), t = (i % SUB) / SUB;
    bank[i] = (berms[p] ?? 0) * (1 - t) + (berms[Math.min(n - 1, p + 1)] ?? 0) * t;
  }
  const hw = new Float32Array(samples);
  for (let i = 0; i < samples; i++) hw[i] = halfWidth * (widths[i] ?? 1);
  return { samples, start: startPoint * SUB, finish: finishPoint * SUB, halfWidth, hw, sx, sy, sz, tx, tz, bank, cut: null };
}

/** The heading (radians about y, 0 facing +z) down the road at a sample: a kart's forward is (sin h, 0, cos h). */
export function headingAt(track: Track, sample: number): number {
  const i = Math.min(track.samples - 1, Math.max(0, Math.round(sample)));
  return Math.atan2(track.tx[i]!, track.tz[i]!);
}

/**
 * How far down the course (x, z) is, in samples with a fraction: projected onto the nearest segment.
 * `hint` is the last answer for the same kart (a search near it), or a negative number to search all.
 */
export function progressAt(track: Track, x: number, z: number, hint: number): number {
  const { sx, sz, samples } = track;
  let lo = 0;
  let hi = samples - 1;
  if (hint >= 0) {
    lo = Math.max(0, Math.floor(hint) - 6);
    hi = Math.min(samples - 1, Math.floor(hint) + 10);
  }
  let best = Infinity;
  let at = lo;
  for (let i = lo; i <= hi; i++) {
    const dx = sx[i]! - x;
    const dz = sz[i]! - z;
    const d = dx * dx + dz * dz;
    if (d < best) {
      best = d;
      at = i;
    }
  }
  // Along the segment either side of the nearest sample.
  const i = Math.min(at, samples - 2);
  const ax = sx[i + 1]! - sx[i]!;
  const az = sz[i + 1]! - sz[i]!;
  const len2 = ax * ax + az * az || 1;
  const t = ((x - sx[i]!) * ax + (z - sz[i]!) * az) / len2;
  if (t < 0 && i > 0) {
    const px = sx[i]! - sx[i - 1]!;
    const pz = sz[i]! - sz[i - 1]!;
    const pl = px * px + pz * pz || 1;
    const tp = ((x - sx[i - 1]!) * px + (z - sz[i - 1]!) * pz) / pl;
    return i - 1 + Math.min(1, Math.max(0, tp));
  }
  return i + Math.min(1, Math.max(0, t));
}

/** Where on the road `ahead` samples past `progress` is, with a sideways offset (metres, + to the right): written into `out`. */
export function aimAt(track: Track, progress: number, ahead: number, offset: number, out: { x: number; z: number }): void {
  const { sx, sz, tx, tz, samples } = track;
  const p = Math.min(samples - 1, progress + ahead);
  const i = Math.min(samples - 2, Math.floor(p));
  const f = p - i;
  const x = sx[i]! + (sx[i + 1]! - sx[i]!) * f;
  const z = sz[i]! + (sz[i + 1]! - sz[i]!) * f;
  // Right of a direction (tx, tz) is (-tz, tx).
  out.x = x - tz[i]! * offset;
  out.z = z + tx[i]! * offset;
}
