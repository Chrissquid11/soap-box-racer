/**
 * course, 60 Hz: the course the kart's build names (`Build.course`), loaded. When it is not the one
 * loaded (`Kart.course`), the old one goes -- its track and every hazard hang under one entity, so one
 * destroy takes them -- and the new one is made: its track (the `course/track` prefab drawn and collided
 * as that course's model) and its hazards, placed along its centre line as `courses.ts` designed them,
 * facing down the road and tilted with it, a jump scaled to the road's width. The kart goes back to the
 * garage on the new start line (`race` reads the course's track).
 */
import { type Entity, Hidden, internKey, MeshCollider, type PrefabToken, Render, type SystemContext, Transform, type World, NONE } from '@vibe/engine';
import { Bonus, Build, Chicane, Fan, FanRole, Kart, Order, StartLamp } from '../components.ts';
import { lowEnd } from '../device.ts';
import { COURSES, FEATURE_LONG, type Hazard, type HazardKind, JUMP, laidFlat, laidLength, RAMP, SPLASH_MODEL, TRACKS, WEDGE_LONG } from '../courses.ts';
import { liftAt, type Track } from '../track.ts';
import { Bale, Barrier, Bin, BonusStar, Cone, CourseSolid, CourseTrack, FoldingChair, Duck, Foam, Gravel, HayBale, Jump, Ramp, Rattler, Spectator, Splash, Stairs, Tunnel, StartArch, StartLampPart, Tyre, Underlay } from '../prefabs.ts';

const MODELS = COURSES.map((c) => internKey('Model', c.model));
/** The parts of each course's model (`_course.lua`'s) a kart collides with: the road, the hay walls, the ground, the
 * arches, the tree trunks, the rocks and the buildings -- and on a course with a shortcut, its road, the pond and the
 * signs at the split. Not the bunting and flags, the trees' foliage, the bushes or the road's paint: driven through. */
const SOLID = ['road', 'hay', 'grass', 'arches', 'trunks', 'rocks', 'buildings'] as const;
const SOLID_CUT = ['shortcut', 'pond', 'split signs'] as const;
const SOLID_PARTS = COURSES.map((c) => [...SOLID, ...(c.shortcut ? SOLID_CUT : [])].map((part) => internKey('Model', `${c.model}#${part}`)));
/** Metres a ramp or jump is sunk into the road: a hair, its feet laid on it (below). */
const KICKER_SINK = 0.01;

const near = { x: 0, y: 0, z: 0 };
const far = { x: 0, y: 0, z: 0 };

/** The point on a track's centre line `metres` along it (back, negative) from its sample `i`, into `out`. */
function alongTrack(t: Track, i: number, metres: number, out: { x: number; y: number; z: number }): void {
  const step = metres < 0 ? -1 : 1;
  let left = Math.abs(metres);
  let k = i;
  while (left > 0) {
    const n = k + step;
    if (n < 0 || n >= t.samples) break;
    const d = Math.hypot(t.sx[n]! - t.sx[k]!, t.sz[n]! - t.sz[k]!);
    if (d >= left) {
      const f = left / Math.max(1e-6, d);
      out.x = t.sx[k]! + (t.sx[n]! - t.sx[k]!) * f;
      out.y = t.sy[k]! + (t.sy[n]! - t.sy[k]!) * f;
      out.z = t.sz[k]! + (t.sz[n]! - t.sz[k]!) * f;
      return;
    }
    left -= d;
    k = n;
  }
  out.x = t.sx[k]!;
  out.y = t.sy[k]!;
  out.z = t.sz[k]!;
}
const PREFABS: Readonly<Record<HazardKind, PrefabToken>> = {
  ramp: Ramp, jump: Jump, bin: Bin, cone: Cone, bale: Bale, rattler: Rattler, wedge: Ramp, stairs: Stairs, gravel: Gravel,
  foam: Foam, tunnel: Tunnel, kicker: Jump, splash: Splash,
};
/** The kicker ramp's looks, one each in turn down a course and on round from course to course: the plain plywood
 * roller and its themes (`course/ramps.lua`), each collided as it is drawn. */
const RAMP_LOOKS = [
  'course/props#ramp', 'course/ramps#ramp_waves', 'course/ramps#ramp_candy', 'course/ramps#ramp_racing',
  'course/ramps#ramp_piano', 'course/ramps#ramp_table', 'course/ramps#ramp_barn',
].map((k) => internKey('Model', k));

/** The backstop under the road: samples a block spans, how thick it is, how far under the road its top is. */
const UNDER_SPAN = 2;
const UNDER_THICK = 3;
// (Well below the road: a straight block under a curve rises toward it in a dip -- an invisible bump if it is close.)
const UNDER_GAP = 0.3;
/** The blocks behind the walls: how thick, how far behind the wall's face, how far below the road they reach. */
const WALL_THICK = 1.2;
const WALL_GAP = 0.04;
/** Each block a little longer than its run, so the bends leave no gap between two. */
const OVERLAP = 1.25;

type Cmd = SystemContext['cmd'];



/** A block from (ax, ay, az) to (bx, by, bz) along its length, `w` across and `h` high, its middle `lift` over the line and `side` across it. */
function block(cmd: Cmd, root: Entity, ax: number, ay: number, az: number, bx: number, by: number, bz: number, w: number, h: number, lift: number, side: number): void {
  const e = cmd.instantiate(Underlay);
  if (e === NONE) return;
  const dx = bx - ax, dy = by - ay, dz = bz - az;
  const run = Math.hypot(dx, dz) || 1e-6;
  const yaw = Math.atan2(dx, dz);
  const pitch = Math.atan2(-dy, run);
  // Across the road, to its left: (-dz, dx) over the run (as `track.ts`' across).
  const lx = -dz / run, lz = dx / run;
  const at = cmd.init(e, Transform);
  at.px[e] = (ax + bx) / 2 + lx * side;
  at.py[e] = (ay + by) / 2 + lift / Math.cos(pitch);
  at.pz[e] = (az + bz) / 2 + lz * side;
  const sy = Math.sin(yaw / 2), cy = Math.cos(yaw / 2);
  const sx = Math.sin(pitch / 2), cx = Math.cos(pitch / 2);
  at.qx[e] = cy * sx;
  at.qy[e] = sy * cx;
  at.qz[e] = -sy * sx;
  at.qw[e] = cy * cx;
  at.sx[e] = w;
  at.sy[e] = h;
  at.sz[e] = Math.hypot(run, dy) * OVERLAP;
  cmd.setParent(e, root);
}

/**
 * The road's backstop: solid blocks the length of the course, under the road and behind both walls -- the road and
 * the walls are a thin surface a fast body can slip through in one step; these are metres thick. Never drawn. (A bare
 * course's blocks back its crowd barriers, BARRIER_BACK behind the road's edge.)
 */
/** How far behind a bare course's road edge its backstop stands: past its loose crowd barriers (BARRIER_OUT), room for one to
 * fall over backwards. */
const BARRIER_BACK = 2.6;

function layUnderlay(cmd: Cmd, t: Track, wall: number, root: Entity, bare: boolean): void {
  for (let i = 0; i < t.samples - 1; i += UNDER_SPAN) {
    const j = Math.min(t.samples - 1, i + UNDER_SPAN);
    const ax = t.sx[i]!, ay = t.sy[i]!, az = t.sz[i]!;
    // The widest the road is along the block (it narrows and widens): no block stands into it anywhere along.
    let half = 0;
    for (let k = i; k <= j; k++) half = Math.max(half, t.hw[k]!);
    const across = 2 * (half + WALL_THICK + WALL_GAP);
    const bx = t.sx[j]!, by = t.sy[j]!, bz = t.sz[j]!;
    // Under the road, as wide as the road and its walls.
    block(cmd, root, ax, ay, az, bx, by, bz, across, UNDER_THICK, -(UNDER_THICK / 2 + UNDER_GAP), 0);
    // Behind each wall: from under the road to the wall's top, a hair behind its face.
    const h = wall + UNDER_THICK;
    // (Raised with the wall where the edge is built up into a berm: the block stays as high as the wall it backs.)
    for (const s of [-1, 1]) {
      // None where the shortcut runs through the wall it backs.
      // A straight block along a bend cuts its corner: on the bend's outside its middle stands in from the curving
      // edge, on the inside its ends do -- each as far as the block's chord sags off the curve. Set back by that, so no
      // block stands out past the visible wall into the road: an invisible wall a sliding kart would hit.
      const turn = Math.abs(Math.atan2(t.tx[i]! * t.tz[j]! - t.tz[i]! * t.tx[j]!, t.tx[i]! * t.tx[j]! + t.tz[i]! * t.tz[j]!));
      const run = Math.hypot(bx - ax, bz - az);
      const sag = turn > 1e-4 ? (run * OVERLAP) ** 2 * turn / (8 * Math.max(run, 1e-3)) : 0;
      const off = s * (half + WALL_GAP + WALL_THICK / 2 + sag + (bare ? BARRIER_BACK : 0));
      const mx = (ax + bx) / 2 - ((t.tz[i]! + t.tz[j]!) / 2) * off, mz = (az + bz) / 2 + ((t.tx[i]! + t.tx[j]!) / 2) * off;
      if (inCut(t, mx, mz, WALL_THICK + 1)) continue;
      const up = Math.max(liftAt(t, i, s * t.hw[i]!), liftAt(t, j, s * t.hw[j]!));
      block(cmd, root, ax, ay, az, bx, by, bz, WALL_THICK, h + up, wall + up - (h + up) / 2, off);
    }
  }
}

/** The bales along the edges: one this many metres along the last (a bale is 1.15 m: a gap between, so no two touch and
 * one knocked never wakes the whole line -- the physics wakes all of a touching run at once), this far in from the wall's face
 * (their middles). */
const BALE_EVERY = 1.32;
const BALE_IN = 0.35;
/** The bales are laid between the road's samples, looked for every this many metres along it. */
const BALE_STEP = 0.25;
/** Over this many metres either side of a point, a road turning more than BEND (radians) is a bend -- bales round
 * its outside -- and more than HAIRPIN, a tight one: bales round its inside too. */
const BEND_REACH = 12;
const BEND = 0.32;
const HAIRPIN = 0.85;
/** On the straights, a short row of this many every this many metres, side to side. */
const ROW = 3;
const ROW_EVERY = 32;
/** None nearer the start line than this (the grid), nor this near a ramp or jump, nor this near another prop at its side. */
const CLEAR_START = 10;
const CLEAR_KICKER = 7;
const CLEAR_PROP = 2.5;
const MAX_BALES = 360;
/** A bare course (`Course.bare`: no walls): both edges lined end to end, start to end of the road, each bale this far
 * out past the road's edge (its middle: its inner face on the edge, where the wall's was); at most this many. */
const BALE_OUT = 0.3;
const MAX_EDGE_BALES = 720;
/** And behind its bales, a fence of loose steel crowd barriers each side (`layBarriers`): this far out past the road's
 * edge (`_course.lua`'s verge runs out past their feet). */
const BARRIER_OUT = 1.02;
/** A panel's length end to end (`course/barrier`'s model, 2.2 m, and a hair), and how finely the line is walked (a sample's share). */
const BARRIER_PANEL = 2.22;
const BARRIER_STEP = 0.05;
/** No barrier with its middle nearer an arch's middle than the road's half width and this (metres): the arch's posts stand there. */
const ARCH_CLEAR = 2.5;

type Placed = { kind: HazardKind; sample: number; across: number };

/**
 * The chicanes: on some courses, a straight or two with two walls across it from either side in turn, each reaching
 * past the middle -- the kart weaves left and right through them. Tyre stacks on one course, hay bales two high on
 * the next (their walls burst like the rest of them). Every third course from the third has none; a course past the
 * fifth of each set has two. The walls' first is CHICANE_GAP before its middle, the second as far after.
 */
const CHICANE_GAP = 7;
/** How far the chicane spans either side of its middle (nothing else there), metres. */
const CHICANE_SPAN = 12;
/** Each wall reaches this share of the road's width from its own side, a tyre stack (or a bale) this far from the next. */
const CHICANE_REACH = 0.5;
const TYRE_EVERY = 0.7;
/** A stack: this many tyres, each this high (metres) laid on the last, a little off square (x, z metres, a turn). */
const TYRES_HIGH = 3;
const TYRE_HIGH = 0.197;
const TYRE_OFFSETS: readonly (readonly [number, number, number])[] = [[0, 0, 0], [0.025, -0.015, 0.12], [-0.02, 0.02, -0.09]];
/** The top tyre's look: its sidewall banded red and white, as a circuit's are. */
const TYRE_TOP = internKey('Model', 'course/props#tyre_top');
/** A chicane's middle: on road this straight (radians over CHICANE_SPAN either way), this clear of a hazard, and of the line. */
const CHICANE_STRAIGHT = 0.18;
const CHICANE_CLEAR = 14;
const CHICANE_ENDS = 40;

/** Metres past a chicane's far wall at which a kart is through it (`stunts`). */
const CHICANE_PAST = 3;

/** A wall piece of chicane `index`, through at sample `exit`. */
function markChicane(cmd: Cmd, e: Entity, index: number, exit: number): void {
  const ch = cmd.add(e, Chicane);
  ch.index[e] = index;
  ch.exit[e] = exit;
}

function layChicanes(cmd: Cmd, t: Track, hazards: readonly Placed[], dist: Float32Array, startAt: number, finishAt: number, root: Entity, course: number): number[] {
  const set = course % 10;
  if (set < 2 || set % 3 === 1) return [];
  const want = set >= 5 ? 2 : 1;
  const tyres = course % 2 === 0;
  const n = t.samples;
  const heading = (i: number): number => Math.atan2(t.tx[i]!, t.tz[i]!);
  const sampleAt = (d: number): number => {
    let lo = 0, hi = n - 1;
    while (lo < hi) { const m = (lo + hi) >> 1; if (dist[m]! < d) lo = m + 1; else hi = m; }
    return Math.max(1, Math.min(n - 2, lo));
  };
  const okAt = (d: number): boolean => {
    if (d < startAt + CHICANE_ENDS || d > finishAt - CHICANE_ENDS) return false;
    const a = sampleAt(d - CHICANE_SPAN), b = sampleAt(d + CHICANE_SPAN);
    let turn = heading(b) - heading(a);
    turn = Math.atan2(Math.sin(turn), Math.cos(turn));
    if (Math.abs(turn) > CHICANE_STRAIGHT) return false;
    for (const hz of hazards) if (Math.abs(dist[Math.min(n - 1, Math.max(0, hz.sample))]! - d) < CHICANE_CLEAR) return false;
    return true;
  };
  const length = finishAt - startAt;
  const middles: number[] = [];
  for (let k = 0; k < want; k++) {
    // Near its share of the way down, the nearest place there is room for one.
    const aim = startAt + (length * (k + 1)) / (want + 1);
    for (let off = 0; off < length * 0.3; off += 2) {
      const d = okAt(aim + off) ? aim + off : okAt(aim - off) ? aim - off : -1;
      if (d < 0) continue;
      if (middles.every((m) => Math.abs(m - d) > CHICANE_SPAN * 3)) middles.push(d);
      break;
    }
  }
  for (let c = 0; c < middles.length; c++) {
    // Past its far wall, with room to spare: through it.
    const exit = sampleAt(middles[c]! + CHICANE_GAP + CHICANE_PAST);
    const first = (course + c) % 2 === 0 ? 1 : -1;
    for (let w = 0; w < 2; w++) {
      const side = w === 0 ? first : -first;
      const i = sampleAt(middles[c]! + (w === 0 ? -CHICANE_GAP : CHICANE_GAP));
      const h = heading(i);
      const run = Math.hypot(t.sx[i + 1]! - t.sx[i - 1]!, t.sz[i + 1]! - t.sz[i - 1]!) || 1;
      const slope = (t.sy[i + 1]! - t.sy[i - 1]!) / run;
      // As far across as the road is wide here (it narrows and widens).
      const half = t.hw[i]!;
      const reach = 2 * half * CHICANE_REACH;
      if (tyres) {
        // A row of tyre stacks from the wall out, each a little off the line, as they were rolled into place: each
        // stack TYRES_HIGH loose tyres one on another, none quite square on the one under it, the top one banded --
        // a knock sends them tumbling apart, each its own way.
        for (let a = 0.38; a < reach; a += TYRE_EVERY) {
          const across = side * (half - a);
          const wob = Math.sin(a * 7.3 + c) * 0.08;
          const x0 = t.sx[i]! - t.tz[i]! * across + t.tx[i]! * wob;
          const y0 = t.sy[i]! + footLift(t, i, across, 0.3) + 0.01;
          const z0 = t.sz[i]! + t.tx[i]! * across + t.tz[i]! * wob;
          for (let k = 0; k < TYRES_HIGH; k++) {
            const e = cmd.instantiate(Tyre);
            if (e === NONE) return middles;
            smallProp(cmd, e);
            markChicane(cmd, e, c, exit);
            const off = TYRE_OFFSETS[k]!;
            const at = cmd.init(e, Transform);
            at.px[e] = x0 + off[0];
            at.py[e] = y0 + TYRE_HIGH / 2 + k * TYRE_HIGH;
            at.pz[e] = z0 + off[1];
            const yaw = h + a * 2.1 + off[2];
            at.qy[e] = Math.sin(yaw / 2);
            at.qw[e] = Math.cos(yaw / 2);
            if (k === TYRES_HIGH - 1) cmd.init(e, Render).model[e] = TYRE_TOP;
            cmd.setParent(e, root);
          }
        }
      } else {
        // Bales laid across, two high, the top row a half bale over.
        const yaw = h + Math.PI / 2;
        const lean = Math.atan(slope * (Math.cos(yaw) * t.tx[i]! - Math.sin(yaw) * t.tz[i]!));
        const sy = Math.sin(yaw / 2), cy = Math.cos(yaw / 2);
        const sr = Math.sin(lean / 2), cr = Math.cos(lean / 2);
        for (let l = 0; l < 2; l++) {
          for (let a = 0.55 + l * 0.5; a < reach - 0.2; a += BALE_LONG) {
            const e = cmd.instantiate(HayBale);
            if (e === NONE) return middles;
            smallProp(cmd, e);
            markChicane(cmd, e, c, exit);
            const across = side * (half - a);
            const at = cmd.init(e, Transform);
            at.px[e] = t.sx[i]! - t.tz[i]! * across;
            at.py[e] = t.sy[i]! + footLift(t, i, across, 0.3) + 0.01 + l * (BALE_HIGH + 0.005);
            at.pz[e] = t.sz[i]! + t.tx[i]! * across;
            at.qx[e] = sy * sr;
            at.qy[e] = sy * cr;
            at.qz[e] = cy * sr;
            at.qw[e] = cy * cr;
            cmd.setParent(e, root);
          }
        }
      }
    }
  }
  return middles;
}

/**
 * Hay bales lining the course's edges: round the outside of every bend and both sides of a hairpin, a short row now
 * and then on the straights -- each standing on the road against the wall, long along it, tilted with it. On a bare
 * course (`bare`: no walls) they are the walls: both edges lined end to end, the road's whole length, just off it.
 */
function layBales(cmd: Cmd, t: Track, hazards: readonly Placed[], root: Entity, course: number, bare: boolean): number[] {
  const n = t.samples;
  // How far along each sample is, metres.
  const dist = new Float32Array(n);
  for (let i = 1; i < n; i++) dist[i] = dist[i - 1]! + Math.hypot(t.sx[i]! - t.sx[i - 1]!, t.sz[i]! - t.sz[i - 1]!);
  const total = dist[n - 1]!;
  const per = total / Math.max(1, n - 1);
  const reach = Math.max(1, Math.round(BEND_REACH / per));
  const startAt = dist[Math.min(n - 1, Math.max(0, t.start))]!;
  const finishAt = dist[Math.min(n - 1, Math.max(0, t.finish))]!;
  const heading = (i: number): number => Math.atan2(t.tx[i]!, t.tz[i]!);
  const chicanes = layChicanes(cmd, t, hazards, dist, startAt, finishAt, root, course);
  let laid = 0;
  // Where each side's last bale went (its middle), so the next goes BALE_EVERY on from it along that edge -- end to end,
  // nearly touching, round the outside of a bend as on the inside. (The road's samples are metres apart: the bales are
  // laid between them, every BALE_STEP metres along.)
  let lastLX = NaN, lastLZ = NaN, lastRX = NaN, lastRZ = NaN;
  let i = 1;
  const most = bare ? MAX_EDGE_BALES : MAX_BALES;

  for (let d = bare ? 0.6 : startAt + CLEAR_START; d <= (bare ? total - 0.6 : finishAt + 6) && laid < most; d += BALE_STEP) {
    while (i + 2 < n && dist[i + 1]! <= d) i++;
    const f = Math.max(0, Math.min(1, (d - dist[i]!) / Math.max(1e-6, dist[i + 1]! - dist[i]!)));
    // Not through a chicane: its walls are its own.
    let inChicane = false;
    for (const c of chicanes) if (Math.abs(d - c) < CHICANE_SPAN) inChicane = true;
    if (inChicane && !bare) continue;
    const a = Math.max(0, i - reach), b = Math.min(n - 1, i + reach);
    let turn = heading(b) - heading(a);
    turn = Math.atan2(Math.sin(turn), Math.cos(turn));
    // The bend's outside: the way this point bulges from the chord across it (+ is the road's right, `track.ts`).
    const mx = (t.sx[a]! + t.sx[b]!) / 2, mz = (t.sz[a]! + t.sz[b]!) / 2;
    const outward = (t.sx[i]! - mx) * -t.tz[i]! + (t.sz[i]! - mz) * t.tx[i]!;
    const out = outward >= 0 ? 1 : -1;
    let sides = 0;   // bit 1 the outside, bit 2 the inside
    if (Math.abs(turn) > BEND) sides |= 1;
    if (Math.abs(turn) > HAIRPIN) sides |= 2;
    // A row on the straight: ROW bales on one side, every ROW_EVERY metres, the side turn about.
    if (bare) sides = 3;
    else if (sides === 0) {
      const into = (d - startAt) % ROW_EVERY;
      if (into < ROW * BALE_EVERY) sides = Math.floor((d - startAt) / ROW_EVERY) % 2 === 0 ? 1 : 2;
      else continue;
    }
    for (const bit of [1, 2]) {
      if (!(sides & bit) || laid >= most) continue;
      const side = bit === 1 ? out : -out;
      // Clear of the kickers (across the whole road) and of what already stands at that side.
      // (A bare course's line stands off the road: nothing on it is in its way.)
      let clear = true;
      for (let h = 0; h < hazards.length && clear && !bare; h++) {
        const hz = hazards[h]!;
        const gap = Math.abs(dist[Math.min(n - 1, Math.max(0, hz.sample))]! - d);
        if (laidFlat(hz.kind) && gap < CLEAR_KICKER) clear = false;
        else if (gap < CLEAR_PROP && Math.sign(hz.across) === side && Math.abs(hz.across) > t.hw[Math.min(n - 1, Math.max(0, hz.sample))]! - 2) clear = false;
      }
      if (!clear) continue;
      // The road here, between its samples i and i + 1.
      const cx0 = t.sx[i]! + (t.sx[i + 1]! - t.sx[i]!) * f, cz0 = t.sz[i]! + (t.sz[i + 1]! - t.sz[i]!) * f;
      let tx = t.tx[i]! + (t.tx[i + 1]! - t.tx[i]!) * f, tz = t.tz[i]! + (t.tz[i + 1]! - t.tz[i]!) * f;
      const tl = Math.hypot(tx, tz) || 1;
      tx /= tl;
      tz /= tl;
      const hw = t.hw[i]! + (t.hw[i + 1]! - t.hw[i]!) * f;
      const across = side * (bare ? hw + BALE_OUT : hw - BALE_IN);
      const bx = cx0 - tz * across, bz = cz0 + tx * across;
      // A bale's length on from the last on this side, along the edge.
      const lx = side > 0 ? lastLX : lastRX, lz = side > 0 ? lastLZ : lastRZ;
      if (!Number.isNaN(lx) && Math.hypot(bx - lx, bz - lz) < BALE_EVERY) continue;
      if (inCut(t, bx, bz, 1.5)) continue;
      const e = cmd.instantiate(HayBale);
      if (e === NONE) return chicanes;
      if (side > 0) { lastLX = bx; lastLZ = bz; } else { lastRX = bx; lastRZ = bz; }
      // (A bare course's edge -- hundreds of them in view -- casts no shadows: a draw each fewer, the frame rate kept.)
      if (bare) cmd.init(e, Render).castShadow[e] = 0;
      else smallProp(cmd, e);
      const at = cmd.init(e, Transform);
      at.px[e] = bx;
      at.py[e] = t.sy[i]! + (t.sy[i + 1]! - t.sy[i]!) * f + footLift(t, i, across, 0.3) * (1 - f) + footLift(t, i + 1, across, 0.3) * f + 0.01;
      at.pz[e] = bz;
      const yaw = Math.atan2(tx, tz);
      const run = Math.max(0.01, dist[i + 1]! - dist[i]!);
      const pitch = Math.atan2(t.sy[i]! - t.sy[i + 1]!, run);
      const sy = Math.sin(yaw / 2), cy = Math.cos(yaw / 2);
      const sx = Math.sin(pitch / 2), cx = Math.cos(pitch / 2);
      at.qx[e] = cy * sx;
      at.qy[e] = sy * cx;
      at.qz[e] = -sy * sx;
      at.qw[e] = cy * cx;
      cmd.setParent(e, root);
      laid++;
    }
  }
  if (bare) layBarriers(cmd, t, root);
  layRunOut(cmd, t, dist, finishAt, root);
  return chicanes;
}

/**
 * A bare course's crowd barriers: each side, panel after panel along a line BARRIER_OUT past the road's edge, the
 * whole road's length -- each panel from one point on that line to the next a panel's length on (BARRIER_PANEL), so
 * they meet end to end round a bend as on the straight, a fence; each its own loose body (`course/barrier`, its
 * collider a little short of its ends, so no two touch and wake each other).
 */
function layBarriers(cmd: Cmd, t: Track, root: Entity): void {
  const n = t.samples;
  const st = Math.max(0, Math.min(n - 1, t.start)), fin = Math.max(0, Math.min(n - 1, t.finish));
  for (const side of [-1, 1]) {
    // The line: a point a sample, BARRIER_OUT past the edge there, at the ground's height.
    let ax = 0, az = 0, ay = 0, have = false, i = 0, f = 0;
    const point = (k: number, u: number, out: { x: number; y: number; z: number }): void => {
      const j = Math.min(n - 2, k);
      const tx = t.tx[j]! + (t.tx[j + 1]! - t.tx[j]!) * u, tz = t.tz[j]! + (t.tz[j + 1]! - t.tz[j]!) * u;
      const tl = Math.hypot(tx, tz) || 1;
      const off = side * (t.hw[j]! + (t.hw[j + 1]! - t.hw[j]!) * u + BARRIER_OUT);
      out.x = t.sx[j]! + (t.sx[j + 1]! - t.sx[j]!) * u - (tz / tl) * off;
      out.z = t.sz[j]! + (t.sz[j + 1]! - t.sz[j]!) * u + (tx / tl) * off;
      out.y = t.sy[j]! + (t.sy[j + 1]! - t.sy[j]!) * u + footLift(t, j, off, 0.3) * (1 - u) + footLift(t, j + 1, off, 0.3) * u + 0.01;
    };
    const p = { x: 0, y: 0, z: 0 };
    // Walk the line in small steps, a panel each time the straight distance from the last panel's start reaches its length.
    for (i = 0; i < n - 1; i++) {
      for (f = 0; f < 1; f += BARRIER_STEP) {
        point(i, f, p);
        if (!have) { ax = p.x; ay = p.y; az = p.z; have = true; continue; }
        const dx = p.x - ax, dz = p.z - az;
        const run = Math.hypot(dx, dz);
        if (run < BARRIER_PANEL) continue;
        // (None where the start arch and the finish arch stand on their posts either side.)
        const mx = (ax + p.x) / 2, mz = (az + p.z) / 2;
        const byArch = Math.hypot(mx - t.sx[st]!, mz - t.sz[st]!) < t.halfWidth + ARCH_CLEAR || Math.hypot(mx - t.sx[fin]!, mz - t.sz[fin]!) < t.halfWidth + ARCH_CLEAR;
        if (!byArch && !inCut(t, mx, mz, 1.5)) {
          const g = cmd.instantiate(Barrier);
          if (g === NONE) return;
          const gt = cmd.init(g, Transform);
          gt.px[g] = (ax + p.x) / 2;
          gt.py[g] = Math.min(ay, p.y);
          gt.pz[g] = (az + p.z) / 2;
          const yaw = Math.atan2(dx, dz), pitch = Math.atan2(ay - p.y, run);
          const sy = Math.sin(yaw / 2), cy = Math.cos(yaw / 2), sx = Math.sin(pitch / 2), cx = Math.cos(pitch / 2);
          gt.qx[g] = cy * sx;
          gt.qy[g] = sy * cx;
          gt.qz[g] = -sy * sx;
          gt.qw[g] = cy * cx;
          cmd.setParent(g, root);
        }
        ax = p.x; ay = p.y; az = p.z;
      }
    }
  }
}

/** The run-out past the finish: rows of bales across it from this far past the line, this far apart, to this short of
 * the road's end -- every other row a half bale over, the last few stacked into a wall; at most RUN_OUT_MAX of them. */
const RUN_OUT_FROM = 8;
const RUN_OUT_ROWS = 2.8;
const RUN_OUT_END = 2;
const RUN_OUT_MAX = 130;
/** A bale across its row: 1.15 m long, a hair between two; and how high one stands (`course/hay-bale`). */
const BALE_LONG = 1.24;
const BALE_HIGH = 0.483;

/**
 * A field of bales past the finish line to smash through: rows of them across the road, each laid long across it,
 * the rows staggered, two high further on and a wall three high at the end -- a soft stop, all of it bursting.
 */
function layRunOut(cmd: Cmd, t: Track, dist: Float32Array, finishAt: number, root: Entity): void {
  const n = t.samples;
  const end = dist[n - 1]! - RUN_OUT_END;
  const first = finishAt + RUN_OUT_FROM;
  if (end <= first) return;
  const rows = Math.floor((end - first) / RUN_OUT_ROWS) + 1;
  // (The run-out keeps the road's designed width: `widthProfile` never narrows it past the finish.)
  const across = 2 * (t.halfWidth - 0.15);
  let laid = 0;
  let i = 1;
  for (let r = 0; r < rows && laid < RUN_OUT_MAX; r++) {
    const d = first + r * RUN_OUT_ROWS;
    while (i < n - 2 && dist[i]! < d) i++;
    // The road's heading and slope here; a bale laid across it is turned a quarter more, tilted about its length.
    const h = Math.atan2(t.tx[i]!, t.tz[i]!);
    const run = Math.hypot(t.sx[i + 1]! - t.sx[i - 1]!, t.sz[i + 1]! - t.sz[i - 1]!) || 1;
    const slope = (t.sy[i + 1]! - t.sy[i - 1]!) / run;
    const yaw = h + Math.PI / 2;
    // Its length (local x, after the turn) runs (cos yaw, -sin yaw) on the ground; it rises with the road along that.
    const lean = Math.atan(slope * (Math.cos(yaw) * t.tx[i]! - Math.sin(yaw) * t.tz[i]!));
    const sy = Math.sin(yaw / 2), cy = Math.cos(yaw / 2);
    const sr = Math.sin(lean / 2), cr = Math.cos(lean / 2);
    const fromEnd = rows - 1 - r;
    const layers = fromEnd === 0 ? 3 : fromEnd <= 2 ? 2 : 1;
    for (let l = 0; l < layers; l++) {
      // Each row (and each layer up) a half bale over from the one before: brickwork, no gap straight through.
      const offset = ((r + l) % 2) * 0.5;
      const count = Math.floor(across / BALE_LONG - offset);
      const start = -across / 2 + BALE_LONG * (0.5 + offset);
      for (let b = 0; b < count && laid < RUN_OUT_MAX; b++) {
        const a = start + b * BALE_LONG;
        const e = cmd.instantiate(HayBale);
        if (e === NONE) return;
        smallProp(cmd, e);
        const at = cmd.init(e, Transform);
        at.px[e] = t.sx[i]! - t.tz[i]! * a;
        at.py[e] = t.sy[i]! + footLift(t, i, a, 0.55) + 0.01 + l * (BALE_HIGH + 0.005);
        at.pz[e] = t.sz[i]! + t.tx[i]! * a;
        // Turned about y, then leant about its own z: q = yaw × lean.
        at.qx[e] = sy * sr;
        at.qy[e] = sy * cr;
        at.qz[e] = cy * sr;
        at.qw[e] = cy * cr;
        cmd.setParent(e, root);
        laid++;
      }
    }
  }
}

export function course(world: World): void {
  world.system({
    name: 'course',
    rate: 60,
    write: [Kart, Build],
    update({ members, count, cmd, ref, deref }, _read, [kart, build]) {
      for (let n = 0; n < count; n++) {
        const e = members[n];
        const want = Math.min(build.course[e], COURSES.length - 1);
        if (kart.course[e] === want) continue;

        const old = deref(kart.courseRoot[e]);
        if (old !== NONE) cmd.destroy(old);
        const root = cmd.spawn();
        cmd.add(root, Transform);
        kart.courseRoot[e] = ref(root);
        kart.course[e] = want;

        const track = cmd.instantiate(CourseTrack);
        if (track !== NONE) {
          cmd.init(track, Render).model[track] = MODELS[want]!;
          cmd.setParent(track, root);
        }
        // Solid: the parts of it a kart can hit, each its own collider -- never the bunting, flags, foliage or paint.
        const parts = SOLID_PARTS[want]!;
        for (let n = 0; n < parts.length; n++) {
          const solid = cmd.instantiate(CourseSolid);
          if (solid === NONE) continue;
          cmd.init(solid, MeshCollider).mesh[solid] = parts[n]!;
          cmd.setParent(solid, root);
        }
        const t = TRACKS[want]!;
        layUnderlay(cmd, t, COURSES[want]!.wallHeight, root, COURSES[want]!.bare);
        const hazards = COURSES[want]!.hazards;
        let ramps = 0;
        for (let h = 0; h < hazards.length; h++) {
          const hz = hazards[h]!;
          const thing = cmd.instantiate(PREFABS[hz.kind]);
          if (thing === NONE) continue;
          const i = Math.max(1, Math.min(t.samples - 2, hz.sample));
          // Each ramp its own look: the next of them along the course, starting further on each course.
          if (hz.kind === 'ramp') cmd.init(thing, Render).model[thing] = RAMP_LOOKS[(want * 3 + ramps++) % RAMP_LOOKS.length]!;
          const at = cmd.init(thing, Transform);
          let yaw: number;
          let pitch: number;
          if (laidFlat(hz.kind)) {
            // A ramp or jump laid from the road at its near end to the road at its far one -- not tilted with the road
            // at its middle only: the road bends up and down under a long one, and its feet would stand proud of it on
            // a crest, a step to hit. Laid so, both feet are on the road, and the road's bend is hidden under it.
            const half = laidLength(hz) / 2;
            alongTrack(t, i, -half, near);
            alongTrack(t, i, half, far);
            const run = Math.hypot(far.x - near.x, far.z - near.z);
            at.px[thing] = (near.x + far.x) / 2;
            at.py[thing] = (near.y + far.y) / 2 - KICKER_SINK;
            at.pz[thing] = (near.z + far.z) / 2;
            yaw = Math.atan2(far.x - near.x, far.z - near.z);
            pitch = Math.atan2(near.y - far.y, run);
            // A wedge, or a side kicker, stands under one side of the road only.
            if (hz.kind === 'wedge' || hz.kind === 'kicker') {
              at.px[thing] -= t.tz[i]! * hz.across;
              at.pz[thing] += t.tx[i]! * hz.across;
              at.py[thing] += footLift(t, i, hz.across, 0);
            }
          } else {
            at.px[thing] = t.sx[i]! - t.tz[i]! * hz.across;
            at.py[thing] = t.sy[i]! + footLift(t, i, hz.across, 0.4) + 0.02;
            at.pz[thing] = t.sz[i]! + t.tx[i]! * hz.across;
            // Facing down the road (yaw), tilted with its slope (pitch about x: + turns its front down).
            yaw = Math.atan2(t.tx[i]!, t.tz[i]!);
            // A round bale turned to lie along the road: it cannot roll on down the hill.
            if (hz.kind === 'bale') yaw += Math.PI / 2;
            const run = Math.hypot(t.sx[i + 1]! - t.sx[i - 1]!, t.sz[i + 1]! - t.sz[i - 1]!);
            pitch = Math.atan2(t.sy[i - 1]! - t.sy[i + 1]!, run);
          }
          const sy = Math.sin(yaw / 2), cy = Math.cos(yaw / 2);
          const sx = Math.sin(pitch / 2), cx = Math.cos(pitch / 2);
          at.qx[thing] = cy * sx;
          at.qy[thing] = sy * cx;
          at.qz[thing] = -sy * sx;
          at.qw[thing] = cy * cx;
          // A bigger jump is longer as well as taller: the same angle, so a kart's nose never meets its face.
          at.sx[thing] = hz.width;
          // (A wedge is shorter than the ramp it is; the rest of the laid features are as long as modelled.)
          const scaled = hz.kind === 'ramp' || hz.kind === 'jump' || hz.kind === 'kicker';
          at.sy[thing] = scaled || hz.kind === 'wedge' ? hz.height : 1;
          at.sz[thing] = hz.kind === 'wedge' ? WEDGE_LONG : scaled ? hz.height : hz.kind === 'splash' ? FEATURE_LONG.splash / SPLASH_MODEL : 1;
          cmd.setParent(thing, root);
        }
        const chicanes = layBales(cmd, t, hazards, root, want, COURSES[want]!.bare);
        layBonuses(cmd, t, hazards, chicanes, root);
        layArch(cmd, t, root);
        layCrowd(cmd, t, root, want);
        layShortcut(cmd, t, root, want);
        // On the new start line, in the garage -- unless a run was asked for.
        if (build.order[e] === Order.none) build.order[e] = Order.garage;
      }
    },
  });
}

/** The bonuses: at most this many a course; what each kind is worth; how high over the road each hangs (metres, its
 * middle): in the air past a jump's lip (only a kart flying high and straight gets it), over a ramp, up a berm's
 * high side, and between a hazard and the wall beside it. A berm counts from this much build-up (metres). */
const BONUS_MOST = 10;
/** Stars at least this share of an even spacing apart (the course's length over BONUS_MOST + 1), and at most this many
 * not off a ramp, only to fill a stretch with none. */
const BONUS_GAP = 0.7;
const BONUS_FILL = 2;
const BONUS_JUMP = 120;
const BONUS_RAMP = 60;
const BONUS_BERM = 90;
const BONUS_SQUEEZE = 50;
const BONUS_JUMP_PAST = 7;
const BONUS_JUMP_HIGH = 2.3;
const BONUS_RAMP_PAST = 4;
const BONUS_RAMP_HIGH = 1.4;
/** Past a side kicker's lip, over its own line: high enough (its middle BONUS_KICK_HIGH up) that a kart only gets it
 * by flying off the kicker -- one driving past underneath stays out of reach (`bonus`' REACH). */
const BONUS_KICK = 100;
const BONUS_KICK_PAST = 5;
const BONUS_KICK_HIGH = 2.4;
const BONUS_LOW = 0.75;
const BONUS_BERM_FROM = 1.6;
const BONUS_EDGE = 0.55;
const BONUS_SQUEEZE_OUT = 1.15;

/** The sample `metres` on down the road from sample `i`. */
function sampleAhead(t: Track, i: number, metres: number): number {
  let left = metres;
  let k = i;
  while (left > 0 && k < t.samples - 2) {
    left -= Math.hypot(t.sx[k + 1]! - t.sx[k]!, t.sz[k + 1]! - t.sz[k]!);
    k++;
  }
  return k;
}

/** One bonus at sample `i`, `across` metres from the road's middle (+ right), `high` over the road there, worth `value`. */
function putBonus(cmd: Cmd, t: Track, i: number, across: number, high: number, value: number, root: Entity): void {
  const e = cmd.instantiate(BonusStar);
  if (e === NONE) return;
  const at = cmd.init(e, Transform);
  at.px[e] = t.sx[i]! - t.tz[i]! * across;
  at.py[e] = t.sy[i]! + liftAt(t, i, across) + high;
  at.pz[e] = t.sz[i]! + t.tx[i]! * across;
  cmd.init(e, Bonus).value[e] = value;
  cmd.setParent(e, root);
}

/** A star is never blocked from the front: nothing standing (a cone, a bale, a bin) within BONUS_OPEN metres before it
 * nearer its line than BONUS_LANE, and none in a chicane (CHICANE_SPAN of its middle). Blocked, it is moved across the
 * road to a clear line, else left out. */
const BONUS_OPEN = 18;
const BONUS_LANE = 1.4;

/**
 * The course's bonuses, no more than BONUS_MOST, spaced evenly down it: off its ramps -- in the air past a jump's
 * lip, a side kicker's, a ramp's, where only a kart that took it reaches -- and only to fill a long stretch with none,
 * one up a steep berm's high side or between a hazard and the wall. Each with a clear run at it (`clearLine`).
 */
function layBonuses(cmd: Cmd, t: Track, hazards: readonly Hazard[], chicanes: readonly number[], root: Entity): void {
  const n = t.samples;
  const dist = new Float32Array(n);
  for (let i = 1; i < n; i++) dist[i] = dist[i - 1]! + Math.hypot(t.sx[i]! - t.sx[i - 1]!, t.sz[i]! - t.sz[i - 1]!);
  const at = (i: number): number => dist[Math.max(0, Math.min(n - 1, i))]!;
  // Where across the road a star at sample `i` can go with nothing standing in front of it: `across` if clear, else
  // the nearest clear line of a few across the road, else null (in a chicane, or nowhere clear).
  const clearLine = (i: number, across: number): number | null => {
    const d = at(i);
    if (chicanes.some((c) => Math.abs(d - c) < CHICANE_SPAN + 2)) return null;
    const open = (a: number): boolean => hazards.every((hz) => {
      if (laidFlat(hz.kind)) return true;
      const before = d - at(hz.sample);
      return before < -1 || before > BONUS_OPEN || Math.abs(hz.across - a) >= BONUS_LANE + (hz.width - 1) * 0.5;
    });
    const edge = t.hw[Math.max(0, Math.min(n - 1, i))]! - BONUS_EDGE;
    const tries = [across, 0, edge, -edge, edge / 2, -edge / 2].sort((x, y) => Math.abs(x - across) - Math.abs(y - across));
    for (const a of tries) if (open(a)) return a;
    return null;
  };
  // Every place a star could go: off a ramp of some kind first (a side kicker's, a jump's, a ramp's: in the air past
  // its lip, where only a kart that took it reaches), then the few off-ramp ones (a berm's high side, the gap between a
  // hazard and the wall) kept to fill a long empty stretch.
  interface Spot { i: number; across: number; high: number; value: number; ramp: boolean; clear: boolean }
  const spots: Spot[] = [];
  for (const hz of hazards) {
    if (hz.kind === 'kicker') spots.push({ i: sampleAhead(t, hz.sample, (JUMP.l * hz.height) / 2 + BONUS_KICK_PAST), across: hz.across, high: BONUS_KICK_HIGH, value: BONUS_KICK, ramp: true, clear: false });
    else if (hz.kind === 'jump') spots.push({ i: sampleAhead(t, hz.sample, (JUMP.l * hz.height) / 2 + BONUS_JUMP_PAST), across: 0, high: BONUS_JUMP_HIGH * Math.max(1, hz.height), value: BONUS_JUMP, ramp: true, clear: true });
    else if (hz.kind === 'ramp') spots.push({ i: sampleAhead(t, hz.sample, (RAMP.l * hz.height) / 2 + BONUS_RAMP_PAST), across: hz.across, high: BONUS_RAMP_HIGH, value: BONUS_RAMP, ramp: true, clear: true });
  }
  for (let i = 2; i < t.samples - 2; i++) {
    const b = t.bank[i]!;
    if (Math.abs(b) < BONUS_BERM_FROM || Math.abs(b) < Math.abs(t.bank[i - 1]!) || Math.abs(b) < Math.abs(t.bank[i + 1]!)) continue;
    spots.push({ i, across: Math.sign(b) * (t.hw[i]! - BONUS_EDGE), high: BONUS_LOW, value: BONUS_BERM, ramp: false, clear: true });
  }
  for (const hz of hazards) {
    if (hz.kind === 'ramp' || hz.kind === 'jump' || hz.kind === 'kicker') continue;
    const side = hz.across >= 0 ? 1 : -1;
    const edge = t.hw[Math.max(0, Math.min(t.samples - 1, hz.sample))]! - BONUS_EDGE;
    const across = Math.max(-edge, Math.min(edge, hz.across + side * BONUS_SQUEEZE_OUT));
    if (Math.abs(across - hz.across) < BONUS_SQUEEZE_OUT * 0.6) continue;
    spots.push({ i: Math.max(1, Math.min(t.samples - 2, hz.sample)), across, high: BONUS_LOW, value: BONUS_SQUEEZE, ramp: false, clear: true });
  }
  // Where each can actually go (a clear run at it; a kicker's over its own line), and out of every chicane.
  const usable: Spot[] = [];
  for (const sp of spots) {
    if (chicanes.some((c) => Math.abs(at(sp.i) - c) < CHICANE_SPAN + 2)) continue;
    if (sp.clear) {
      const a = clearLine(sp.i, sp.across);
      if (a === null) continue;
      sp.across = a;
    }
    usable.push(sp);
  }
  // Spread evenly: none nearer the last than the course's length over its share of stars (BONUS_GAP of it). The ramp
  // ones first, the most worth first; then up to BONUS_FILL others, each into the longest stretch still empty.
  const from = at(t.start), to = at(t.finish);
  const gap = ((to - from) / (BONUS_MOST + 1)) * BONUS_GAP;
  const kept: Spot[] = [];
  const roomAt = (d: number): boolean => kept.every((k) => Math.abs(at(k.i) - d) >= gap);
  for (const sp of usable.filter((u) => u.ramp).sort((x, y) => y.value - x.value || x.i - y.i)) {
    if (kept.length >= BONUS_MOST) break;
    if (roomAt(at(sp.i))) kept.push(sp);
  }
  for (let f = 0; f < BONUS_FILL && kept.length < BONUS_MOST; f++) {
    const marks = [from, ...kept.map((k) => at(k.i)).sort((x, y) => x - y), to];
    let best: Spot | null = null, bestGap = gap * 2.2;
    for (let m = 0; m + 1 < marks.length; m++) {
      const span = marks[m + 1]! - marks[m]!;
      if (span <= bestGap) continue;
      const mid = (marks[m]! + marks[m + 1]!) / 2;
      let pick: Spot | null = null;
      for (const sp of usable) {
        if (sp.ramp || kept.includes(sp)) continue;
        const d = at(sp.i);
        if (d <= marks[m]! + gap || d >= marks[m + 1]! - gap) continue;
        if (!pick || Math.abs(d - mid) < Math.abs(at(pick.i) - mid)) pick = sp;
      }
      if (pick) {
        best = pick;
        bestGap = span;
      }
    }
    if (!best) break;
    kept.push(best);
  }
  for (const sp of kept) putBonus(cmd, t, sp.i, sp.across, sp.high, sp.value, root);
}

/**
 * How high to stand something `half` metres either side of its middle at `across` on a bermed road: on the higher of
 * its two edges, so on a bank it rests on the road (a hair proud of its low side) rather than sunk into it.
 */
function footLift(t: Track, i: number, across: number, half: number): number {
  return Math.max(liftAt(t, i, across - half), liftAt(t, i, across + half));
}

/** The arch's clear span between its feet as modelled (`course/arch.lua`), metres; and the room it leaves either side of the road's walls. */
const ARCH_SPAN = 10;
const ARCH_ROOM = 1.6;

/** The inflatable arch over the start line, facing down the road, as wide as its walls and their bales (and scaled to it). */
function layArch(cmd: Cmd, t: Track, root: Entity): void {
  const e = cmd.instantiate(StartArch);
  if (e === NONE) return;
  const i = Math.max(0, Math.min(t.samples - 1, t.start));
  const at = cmd.init(e, Transform);
  at.px[e] = t.sx[i]!;
  at.py[e] = t.sy[i]!;
  at.pz[e] = t.sz[i]!;
  const yaw = Math.atan2(t.tx[i]!, t.tz[i]!);
  at.qx[e] = 0;
  at.qy[e] = Math.sin(yaw / 2);
  at.qz[e] = 0;
  at.qw[e] = Math.cos(yaw / 2);
  // (At the start the road is its designed width: `widthProfile` keeps it so.)
  const k = (2 * (t.halfWidth + ARCH_ROOM)) / ARCH_SPAN;
  at.sx[e] = at.sy[e] = at.sz[e] = k;
  cmd.setParent(e, root);
  // Its three start lamps, on it (each its own model on the arch's skeleton, swaying with it), dark till the countdown.
  for (let n = 0; n < LAMP_MODELS.length; n++) {
    const lamp = cmd.instantiate(StartLampPart);
    if (lamp === NONE) continue;
    cmd.init(lamp, Render).model[lamp] = LAMP_MODELS[n]!;
    cmd.init(lamp, StartLamp).index[lamp] = n;
    cmd.add(lamp, Hidden);
    cmd.setParent(lamp, e);
  }
}
/** The start lamps' models, the first lit first. */
const LAMP_MODELS = [1, 2, 3].map((n) => internKey('Model', `course/arch_lamp_${n}`));

/** The crowd: a cluster of spectators every so many metres down each side, at most this many; how far behind the
 * wall's face the first row stands, and the next. */
const CROWD_EVERY = 6;
const CROWD_MOST = 200;
/** On a phone (`lowEnd`): this share of the crowd, and of the packed rows at the start and the finish. */
const LOW_CROWD = 0.3;
const CROWD_BACK = 1.4;
const CROWD_ROW = 0.9;
/** The finish's own crowd, packed in: from this many metres before the line to this many past it, both sides, rows
 * this many deep, a fan every CROWD_PACK metres along each row; at most FINISH_MOST of them. */
const FINISH_BEFORE = 30;
const FINISH_AFTER = 14;
const FINISH_ROWS = 3;
const CROWD_PACK = 1.1;
const FINISH_MOST = 160;
/** The start's own crowd, packed in the same way: from this many metres behind the start line to this many past it, at
 * most START_MOST (none on a start ramp's raised deck: they would stand in the air). */
const START_BEFORE = 12;
const START_AFTER = 28;
const START_MOST = 110;
/**
 * The village fete's crowd, a mix (FAN_MIX, round and round down the course): families -- grown-ups and their
 * children (KID_HEIGHT of a grown-up's height) -- racing fans with flags and homemade placards, parents filming,
 * supporters in fancy dress (clown, viking, pirate, wizard),
 * mechanics in overalls and marshals in high-vis. Each is one of polyperfect's Low Poly Animated People (`models/people`),
 * grown to an adult's height
 * (FAN_HEIGHT times), each a little taller or shorter than the next (FAN_SIZE, either way). `crowd` moves them.
 */
const FAN_HEIGHT = 1.6;
const FAN_SIZE = 0.07;
const KID_HEIGHT = 0.68;
const R = FanRole;
const FAN_MIX: readonly number[] = [R.adult, R.kid, R.adult, R.flag, R.filmer, R.adult, R.adult, R.costume, R.kid, R.placard,
  R.adult, R.mechanic, R.filmer, R.adult, R.marshal, R.adult, R.kid, R.costume, R.adult, R.flag];
/** A small prop (a bale, a tyre, a deck chair): on a phone (`lowEnd`) it casts no shadow -- one fewer draw of it, every frame. */
function smallProp(cmd: Cmd, e: Entity): void {
  if (lowEnd()) cmd.init(e, Render).castShadow[e] = 0;
}
const looks = (...keys: string[]): number[] => keys.map((key) => internKey('Model', key));
// (polyperfect's Low Poly Animated People, `models/people`, every one: the old figures and their pensioners in deck chairs are gone.)
const FAN_LOOKS: readonly (readonly number[])[] = [
  looks('people/man_casual', 'people/woman_casual', 'people/man_shorts', 'people/woman_shorts', 'people/man_business', 'people/woman_farm', 'people/man_winter', 'people/woman_large'),
  looks('people/boy_cap', 'people/girl_shorts', 'people/girl_winter'),
  looks('people/man_shorts', 'people/woman_casual'),
  looks('people/man_casual', 'people/woman_farm'),
  looks('people/woman_shorts', 'people/man_business'),
  looks('people/man_winter', 'people/woman_large'), // (pensioners: none now -- see FAN_MIX)
  looks('people/man_clown', 'people/woman_viking', 'people/man_pirate', 'people/man_wizard'),
  looks('people/man_mechanic'),
  looks('people/man_police', 'people/woman_hivis'),
];
/** One spectator: who they are (by `k`, through FAN_MIX), their look and size -- and, a pensioner, their deck chair
 * set under them (where there is a `root` to set it in; else they stand, as a grown-up). */
function dressFan(cmd: Cmd, e: Entity, k: number, root?: Entity): void {
  const mod = (n: number, m: number): number => ((n % m) + m) % m;
  let role = FAN_MIX[mod(k * 7 + 3, FAN_MIX.length)]!;
  if (role === R.pensioner && root === undefined) role = R.adult;
  const choices = FAN_LOOKS[role]!;
  cmd.init(e, Render).model[e] = choices[mod(k * 3 + e, choices.length)]!;
  cmd.init(e, Fan).role[e] = role;
  const at = cmd.init(e, Transform);
  const s = FAN_HEIGHT * (role === R.kid ? KID_HEIGHT : 1) * (1 + FAN_SIZE * Math.sin(e * 7.31));
  at.sx[e] = at.sy[e] = at.sz[e] = s;
  if (role === R.pensioner && root !== undefined) {
    const chair = cmd.instantiate(FoldingChair);
    if (chair === NONE) return;
    smallProp(cmd, chair);
    const ct = cmd.init(chair, Transform);
    ct.px[chair] = at.px[e];
    ct.py[chair] = at.py[e];
    ct.pz[chair] = at.pz[e];
    ct.qx[chair] = at.qx[e];
    ct.qy[chair] = at.qy[e];
    ct.qz[chair] = at.qz[e];
    ct.qw[chair] = at.qw[e];
    ct.sx[chair] = ct.sy[chair] = ct.sz[chair] = s / FAN_HEIGHT;
    cmd.setParent(chair, root);
  }
}

/** Spectators behind the walls all the way down, in ones, twos and threes, each facing the road (`crowd` makes them cheer). */
function layCrowd(cmd: Cmd, t: Track, root: Entity, course: number): void {
  let placed = 0;
  let along = 0;
  let next = 0;
  // Spread far enough apart on a long course that the most there are reach all the way down to the finish (two a
  // cluster, on average, each side).
  let length = 0;
  for (let i = 1; i < t.samples; i++) length += Math.hypot(t.sx[i]! - t.sx[i - 1]!, t.sz[i]! - t.sz[i - 1]!);
  const every = Math.max(CROWD_EVERY, (length * 4) / CROWD_MOST);
  // The finish's own packed crowd's stretch (below): the crowd down the course leaves it to them.
  const [lo, hi] = stretch(t, t.finish, FINISH_BEFORE, FINISH_AFTER);
  const packStart = !COURSES[course]!.startRamp;
  const [slo, shi] = stretch(t, t.start, START_BEFORE, START_AFTER);
  // On a phone (`lowEnd`) a thinner crowd: every spectator a draw of thousands of triangles.
  const most = lowEnd() ? CROWD_MOST * LOW_CROWD : CROWD_MOST;
  for (let i = 1; i < t.samples - 1 && placed < most; i++) {
    along += Math.hypot(t.sx[i]! - t.sx[i - 1]!, t.sz[i]! - t.sz[i - 1]!);
    if (along < next || (i >= lo - 1 && i <= hi + 1) || (packStart && i >= slo - 1 && i <= shi + 1)) continue;
    next = along + every;
    for (const side of [-1, 1]) {
      const n = 1 + ((i * 7 + side * 3 + course) % 3 + 3) % 3;
      for (let p = 0; p < n && placed < most; p++) {
        const k = i * 5 + p * 3 + (side > 0 ? 1 : 0) + course;
        const r = fan(cmd, t, root, i, side, (p % 2) * CROWD_ROW, (p - (n - 1) / 2) * 0.8, k);
        if (r < 0) return;
        placed += r;
      }
    }
  }
  // And the finish packed: a crowd rows deep either side, from before the line to past it, there to see them in; and
  // the start the same, there to see them off.
  const thin = lowEnd() ? LOW_CROWD : 1;
  if (pack(cmd, t, root, course, lo, hi, Math.round(FINISH_MOST * thin)) < 0) return;
  if (packStart) pack(cmd, t, root, course, slo, shi, Math.round(START_MOST * thin));
}

/** The samples `before` metres back and `after` metres on from sample `at`, held to the road. */
function stretch(t: Track, at: number, before: number, after: number): [number, number] {
  const mid = Math.max(1, Math.min(t.samples - 2, at));
  let lo = mid, hi = mid;
  for (let d = 0; lo > 1 && d < before; lo--) d += Math.hypot(t.sx[lo]! - t.sx[lo - 1]!, t.sz[lo]! - t.sz[lo - 1]!);
  for (let d = 0; hi < t.samples - 2 && d < after; hi++) d += Math.hypot(t.sx[hi + 1]! - t.sx[hi]!, t.sz[hi + 1]! - t.sz[hi]!);
  return [lo, hi];
}

/** A crowd packed rows deep either side of the road from sample `lo` to `hi`, at most `most` of them: answers how many,
 * or -1 when there are no more spectators to be had. */
function pack(cmd: Cmd, t: Track, root: Entity, course: number, lo: number, hi: number, most: number): number {
  let packed = 0;
  // On a phone, the front rows only (those behind are mostly hidden by them anyway).
  const rows = lowEnd() ? Math.max(1, Math.ceil(FINISH_ROWS * LOW_CROWD)) : FINISH_ROWS;
  for (let i = lo; i <= hi && packed < most; i++) {
    const seg = Math.max(0.01, Math.hypot(t.sx[i + 1]! - t.sx[i]!, t.sz[i + 1]! - t.sz[i]!));
    const each = Math.max(1, Math.round(seg / CROWD_PACK));
    for (const side of [-1, 1]) {
      for (let row = 0; row < rows; row++) {
        for (let q = 0; q < each && packed < most; q++) {
          // Each row staggered half a place on the one in front, a little give either way.
          const slide = (q + 0.5) * (seg / each) - seg / 2 + (row % 2) * CROWD_PACK * 0.5;
          const r = fan(cmd, t, root, i, side, CROWD_ROW + row * CROWD_ROW, slide, i * 11 + row * 5 + q * 3 + (side > 0 ? 7 : 0) + course);
          if (r < 0) return -1;
          packed += r;
        }
      }
    }
  }
  return packed;
}

/** One spectator behind the wall at sample `i`, on `side` (+1 right), `back` metres further back than the front
 * row and `slide` along the road, facing it, dressed by `k`: answers 1 placed, 0 left out (on the shortcut, or in
 * its pond), -1 none to be had. */
function fan(cmd: Cmd, t: Track, root: Entity, i: number, side: number, back: number, slide: number, k: number): number {
  const e = cmd.instantiate(Spectator);
  if (e === NONE) return -1;
  const across = side * (t.hw[i]! + CROWD_BACK + back);
  const fx = t.sx[i]! - t.tz[i]! * across + t.tx[i]! * slide, fz = t.sz[i]! + t.tx[i]! * across + t.tz[i]! * slide;
  // Not on the shortcut where it leaves the road (nor in the pond).
  if (inCut(t, fx, fz, 2)) {
    cmd.destroy(e);
    return 0;
  }
  const at = cmd.init(e, Transform);
  at.px[e] = fx;
  at.py[e] = t.sy[i]!;
  at.pz[e] = fz;
  // Facing the road: toward its middle, across it.
  const yaw = side > 0 ? Math.atan2(t.tz[i]!, -t.tx[i]!) : Math.atan2(-t.tz[i]!, t.tx[i]!);
  at.qx[e] = 0;
  at.qy[e] = Math.sin(yaw / 2);
  at.qz[e] = 0;
  at.qw[e] = Math.cos(yaw / 2);
  dressFan(cmd, e, k, root);
  cmd.setParent(e, root);
  return 1;
}

/** Whether (x, z) is on the course's shortcut (within `margin` of its road, from end to end), or in its pond. */
function inCut(t: Track, x: number, z: number, margin: number): boolean {
  const c = t.cut;
  if (c === null) return false;
  const u = ((x - c.ax) * c.ux + (z - c.az) * c.uz) / c.len;
  const d = (x - c.ax) * -c.uz + (z - c.az) * c.ux;
  if (u > -0.02 && u < 1.02 && Math.abs(d) < c.halfWidth + margin) return true;
  const mid = (c.pondFrom + c.pondTo) / 2;
  const ra = ((c.pondTo - c.pondFrom) * c.len) / 2 + 5 + margin, rd = 10 + margin;
  return ((u - mid) * c.len / ra) ** 2 + (d / rd) ** 2 < 1;
}

/** The pond's ducks (giant, bobbing round it), how big; the spectators either side of it, how many a side. */
const DUCKS = 6;
const DUCK_SIZE = 3.2;
const POND_FANS = 7;

/**
 * The shortcut's pieces (the fete's, over the duck pond): its jump, the lip at the pond's near edge, laid along it;
 * the rough patch on the landing (a bone rattler, the shortcut's width); giant ducks on the water; spectators lining
 * the pond's banks, facing the jump.
 */
function layShortcut(cmd: Cmd, t: Track, root: Entity, course: number): void {
  const c = t.cut;
  if (c === null) return;
  const yaw = Math.atan2(c.ux, c.uz);
  const heightAt = (u: number): number => c.ay + (c.by - c.ay) * u;
  const place = (e: Entity, u: number, across: number, lift: number, pitch: number, turn: number): void => {
    const at = cmd.init(e, Transform);
    at.px[e] = c.ax + c.ux * c.len * u - c.uz * across;
    at.py[e] = heightAt(u) + lift;
    at.pz[e] = c.az + c.uz * c.len * u + c.ux * across;
    const y = yaw + turn;
    const sy = Math.sin(y / 2), cy = Math.cos(y / 2);
    const sx = Math.sin(pitch / 2), cx = Math.cos(pitch / 2);
    at.qx[e] = cy * sx;
    at.qy[e] = sy * cx;
    at.qz[e] = -sy * sx;
    at.qw[e] = cy * cx;
    cmd.setParent(e, root);
  };
  // The fall along the shortcut a metre (its pitch: + turns its front down).
  const pitch = Math.atan2(c.ay - c.by, c.len);
  // The jump: its lip at the pond's near edge.
  const jumpLen = JUMP.l * c.jump;
  const jump = cmd.instantiate(Jump);
  if (jump !== NONE) {
    place(jump, c.pondFrom - jumpLen / 2 / c.len, 0, -KICKER_SINK, pitch, 0);
    const at = cmd.init(jump, Transform);
    at.sx[jump] = (2 * c.halfWidth) / JUMP.w;
    at.sy[jump] = c.jump;
    at.sz[jump] = c.jump;
  }
  // The rough landing: a bone rattler the shortcut's width.
  const rough = cmd.instantiate(Rattler);
  if (rough !== NONE) {
    place(rough, (c.roughFrom + c.roughTo) / 2, 0, -KICKER_SINK, pitch, 0);
    const at = cmd.init(rough, Transform);
    at.sx[rough] = 2 * c.halfWidth;
    at.sz[rough] = ((c.roughTo - c.roughFrom) * c.len) / 8;
  }
  // Giant ducks on the water, round the pond (clear of the jump's line), turned every way.
  const mid = (c.pondFrom + c.pondTo) / 2;
  for (let k = 0; k < DUCKS; k++) {
    const duck = cmd.instantiate(Duck);
    if (duck === NONE) break;
    const a = (k / DUCKS) * Math.PI * 2 + 0.4;
    const along = Math.cos(a) * 9, across = Math.sin(a) > 0 ? 6 + Math.sin(a) * 2.5 : -6 + Math.sin(a) * 2.5;
    place(duck, mid + along / c.len, across, -2.6 - 0.3, 0, a * 1.7);
    const at = cmd.init(duck, Transform);
    at.sx[duck] = at.sy[duck] = at.sz[duck] = DUCK_SIZE;
  }
  // Spectators either side of the pond's banks, facing across it at the jump.
  for (const side of [-1, 1]) {
    for (let p = 0; p < POND_FANS; p++) {
      const e = cmd.instantiate(Spectator);
      if (e === NONE) return;
      const k = p * 3 + (side > 0 ? 1 : 0) + course;
      const along = (p - (POND_FANS - 1) / 2) * 2.4;
      place(e, mid + along / c.len, side * 13.5, -2.2, 0, side > 0 ? -Math.PI / 2 : Math.PI / 2);
      dressFan(cmd, e, k);
    }
  }
}
