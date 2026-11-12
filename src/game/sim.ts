/**
 * The game in node, for tests and tuning: a world with physics on, every course's road and hay walls
 * (and the ramps and jumps) built as collision meshes from its centre line -- the models' own shapes,
 * without the valley and trees -- the kart and its camera as `populate` makes them, and an autopilot at
 * the keys: A/D toward the road's centre line (round the hazards ahead), S into the corners, W off the line.
 * Node only (`node:fs`); the game never imports it.
 */
import { readFileSync } from 'node:fs';
import { compilePrefabs, installPhysics, Loop, type MeshData, PHYSICS_DEFAULTS, Transform, usePhysicsSettings, World } from '@vibe/engine';
import { prefabFilesFromDisk } from '@vibe/engine/node';
import { loadAmmo } from '@vibe/engine/physics-node';
import { Build, Kart, Order, Phase, Wheel } from './components.ts';
import { cornerSpeeds, COURSES, JUMP, kickerRise, laidFlat, RAMP, TRACKS } from './courses.ts';
import { wrap } from './kart-math.ts';
import { populate } from './populate.ts';
import { registerSystems } from './systems.ts';
import { aimAt, cutOpening, cutSurface, halfWidthAt, liftAt, type Track } from './track.ts';

/** Triangles, by quads, both faces. */
function mesh(build: (quad: (a: number[], b: number[], c: number[], d: number[]) => void) => void): MeshData {
  const positions: number[] = [];
  const indices: number[] = [];
  build((a, b, c, d) => {
    const i = positions.length / 3;
    positions.push(...a, ...b, ...c, ...d);
    indices.push(i, i + 1, i + 2, i, i + 2, i + 3, i, i + 2, i + 1, i, i + 3, i + 2);
  });
  return { positions, indices };
}

/** A course part these tests do not build (the ground, the trees ...): one triangle far out of the way. */
const NOWHERE: MeshData = { positions: [0, -900, 0, 1, -900, 0, 0, -900, 1], indices: [0, 1, 2] };

/** How wide the grass verge beside a shortcut's road is (metres): the course model's ground there. */
const VERGE = 4;

/** A course's road top and its two walls, along its curve. */
function roadOf(t: Track, wall: number): MeshData {
  return mesh((quad) => {
    // As `_course.lua` builds it: each edge raised by its berm, each wall from the ground to its height over the edge.
    const edge = (i: number, out: number, up: number): number[] => [t.sx[i]! - t.tz[i]! * out, t.sy[i]! + up, t.sz[i]! + t.tx[i]! * out];
    const top = (i: number, out: number): number => liftAt(t, i, out);
    const c = t.cut;
    for (let i = 0; i < t.samples - 1; i++) {
      // Each sample's own half width: the road narrowing and widening, its walls' faces on its edges.
      const w = t.hw[i]!, w2 = t.hw[i + 1]!;
      quad(edge(i, -w, top(i, -w)), edge(i, w, top(i, w)), edge(i + 1, w2, top(i + 1, w2)), edge(i + 1, -w2, top(i + 1, -w2)));
      for (const s of [-1, 1]) {
        const a = s * w, b = s * w2;
        const m = edge(i, a * 1.1, 0), m2 = edge(i + 1, b * 1.1, 0);
        // Where the shortcut runs through it, or the mouth either end of it: an opening, as the course builds it.
        if (cutOpening(t, i, s, (m[0]! + m2[0]!) / 2, (m[2]! + m2[2]!) / 2)) continue;
        quad(edge(i, a, -0.6), edge(i + 1, b, -0.6), edge(i + 1, b, top(i + 1, b) + wall), edge(i, a, top(i, a) + wall));
      }
    }
    // The shortcut's road, a hair under the main road (wherever it lies over it), with its gap over the pond.
    if (c !== null) {
      const STEPS = 60;
      const at = (u: number, across: number): number[] => {
        const x = c.ax + c.ux * c.len * u - c.uz * across, z = c.az + c.uz * c.len * u + c.ux * across;
        return [x, cutSurface(t, x, z, u) - 0.015, z];
      };
      for (let k = 0; k < STEPS; k++) {
        const u0 = k / STEPS, u1 = (k + 1) / STEPS;
        if (u1 > c.pondFrom && u0 < c.pondTo) continue;
        quad(at(u0, -c.halfWidth), at(u0, c.halfWidth), at(u1, c.halfWidth), at(u1, -c.halfWidth));
        // The grass either side, as the course model's ground meets it: a verge falling away a little.
        for (const side of [-1, 1]) {
          const inner = side * c.halfWidth, outer = side * (c.halfWidth + VERGE);
          const drop = (q: number[]): number[] => [q[0]!, q[1]! - 0.3, q[2]!];
          quad(at(u0, inner), drop(at(u0, outer)), drop(at(u1, outer)), at(u1, inner));
        }
      }
    }
  });
}

/** Each course's fastest speed at each sample (the medals' own), and how near it the autopilot dares go. */
const CORNERS = TRACKS.map(cornerSpeeds);
const CAUTION = 1.05;
/** The autopilot over a shortcut turns in to the road on over this many samples before the join. */
const TURN_IN = 14;
/** Seconds after GO the teammate pushes (`pusher.ts`' PUSH_FOR): the autopilot holds forward through it. */
const PUSHED_FOR = 1.6;

/** A kicker as `props.lua` makes it (courses.ts' RAMP, JUMP): its profile along z, in strips. */
const KICKER_STRIPS = 240;
const kicker = ({ w, l, h, hump }: { w: number; l: number; h: number; hump: boolean }): MeshData => mesh((quad) => {
  const at: [number, number][] = [];
  for (let i = 0; i <= KICKER_STRIPS; i++) at.push([-l / 2 + (i / KICKER_STRIPS) * l, h * kickerRise(hump, i / KICKER_STRIPS)]);
  for (let i = 0; i < at.length - 1; i++) {
    const [za, ya] = at[i]!, [zb, yb] = at[i + 1]!;
    // Its top, and its two sides down to the ground.
    quad([-w / 2, ya, za], [w / 2, ya, za], [w / 2, yb, zb], [-w / 2, yb, zb]);
    quad([w / 2, ya, za], [w / 2, 0, za], [w / 2, 0, zb], [w / 2, yb, zb]);
    quad([-w / 2, 0, za], [-w / 2, ya, za], [-w / 2, yb, zb], [-w / 2, 0, zb]);
  }
  const [zEnd, yEnd] = at[at.length - 1]!;
  if (yEnd > 0.01) quad([-w / 2, 0, zEnd], [w / 2, 0, zEnd], [w / 2, yEnd, zEnd], [-w / 2, yEnd, zEnd]);
});

export interface Sim {
  readonly world: World;
  /** The kart. */
  readonly e: number;
  /** Seconds of ticks, `each` before each; input stamped as a frame does. */
  ticks(seconds: number, each?: () => void): void;
  /** The autopilot, for one tick: call it from `ticks`' `each`. */
  autopilot(): void;
  /** A run on `course` (0 the first) in the build as it stands: the autopilot to the finish, or `limit` seconds --
   * over the course's shortcut, with `shortcut`, where it has one. */
  run(course: number, limit: number, shortcut?: boolean, each?: () => void): { finished: boolean; time: number; progress: number; tookCut: boolean };
  /** Keys let go. */
  release(): void;
}

/** A fresh game in node: the world, its kart, the course it starts on loaded. */
export async function makeSim(): Promise<Sim> {
  const settings = JSON.parse(readFileSync(new URL('../../physics.json', import.meta.url), 'utf8')) as Partial<typeof PHYSICS_DEFAULTS>;
  usePhysicsSettings({ ...PHYSICS_DEFAULTS, ...settings });
  compilePrefabs(prefabFilesFromDisk(new URL('../assets/prefabs/', import.meta.url)));
  const meshes: Record<string, MeshData> = { 'course/props#ramp': kicker(RAMP), 'course/props#jump': kicker(JUMP) };
  COURSES.forEach((c, i) => {
    // The course's solid parts (`course`' SOLID): its road and walls are the road part here; the rest, none to hit.
    meshes[`${c.model}#road`] = roadOf(TRACKS[i]!, c.wallHeight);
  });
  const materials: Record<string, unknown> = {};
  for (const key of ['chassis', 'padded']) materials[key] = JSON.parse(readFileSync(new URL(`../assets/physics-materials/${key}.physmat`, import.meta.url), 'utf8'));

  const ammo = await loadAmmo();
  const world = new World({ loop: new Loop({ seed: 1 }) });
  installPhysics(world, {
    ammo,
    mesh: (model, part) => meshes[part ? `${model}#${part}` : model] ?? (part && model.startsWith('courses/') ? NOWHERE : null),
    material: (key) => materials[key] ?? null,
  });
  registerSystems(world);
  const karts = world.query({ with: [Kart] });
  populate(world);
  world.flush();
  const e = karts.members[0]!;
  const kart = world.store(Kart);
  const build = world.store(Build);
  const at = world.store(Transform);
  const input = world.loop.input;
  void Wheel;

  const ticks = (seconds: number, each?: () => void): void => {
    for (let i = 0; i < seconds * 60; i++) {
      each?.();
      input.stamp(world.loop.tick);
      world.loop.runTick();
    }
  };
  const held = new Set<string>();
  const hold = (code: string, on: boolean): void => {
    if (held.has(code) === on) return;
    input.edge(code, on);
    if (on) held.add(code);
    else held.delete(code);
  };
  const aim = { x: 0, z: 0 };
  const onward = { x: 0, z: 0 };
  let takeCut = false;
  const autopilot = (): void => {
    if (kart.phase[e] !== Phase.racing) return;
    const c = Math.min(kart.course[e]!, COURSES.length - 1);
    const track = TRACKS[c]!;
    const p = kart.progress[e]!;
    const qx = at.qx[e]!, qy = at.qy[e]!, qz = at.qz[e]!, qw = at.qw[e]!;
    const heading = Math.atan2(2 * (qw * qy + qx * qz), 1 - 2 * (qx * qx + qy * qy));
    const speed = kart.speed[e]!;
    const ahead = 2.5 + speed * 0.2;
    // Round whatever stands ahead (not what is laid the whole road wide: ramps, jumps, rattlers, stairs, gravel ...): to
    // the wider side of the one reaching nearest the middle -- a cone funnel's last cone, not its first.
    let lane = 0;
    let nearest = Infinity;
    for (const h of COURSES[c]!.hazards) {
      if ((laidFlat(h.kind) && h.kind !== 'wedge') || h.sample < p - 1 || h.sample > p + 10 || Math.abs(h.across) >= nearest) continue;
      nearest = Math.abs(h.across);
      lane = h.across > 0 ? h.across - 2.6 : h.across + 2.6;
      const half = halfWidthAt(track, p);
      lane = Math.max(-half + 1, Math.min(half - 1, lane));
    }
    aimAt(track, p, ahead, lane, aim);
    // Over the shortcut, when asked: aimed down its middle from just before it leaves the road, eased over its last
    // TURN_IN samples round onto the road on past the join (the shortcut's own progress runs over the road round's
    // samples: never those) -- turning in before the join, as a driver would, and not standing on the brakes as it
    // merges.
    const cut = track.cut;
    let onCutLine = false;
    const joining = takeCut && cut !== null && p >= cut.to - TURN_IN && p < cut.to + TURN_IN;
    if (takeCut && cut !== null && p >= cut.from - 6 && p < cut.to) {
      const u = Math.max(0, ((at.px[e]! - cut.ax) * cut.ux + (at.pz[e]! - cut.az) * cut.uz) / cut.len);
      const t = Math.min(1, u + (ahead + 4) / cut.len);
      const w = Math.max(0, Math.min(1, (p - (cut.to - TURN_IN)) / TURN_IN));
      aimAt(track, cut.to, ahead, 0, onward);
      aim.x = (cut.ax + cut.ux * cut.len * t) * (1 - w) + onward.x * w;
      aim.z = (cut.az + cut.uz * cut.len * t) * (1 - w) + onward.z * w;
      onCutLine = true;
    }
    const off = wrap(Math.atan2(aim.x - at.px[e]!, aim.z - at.pz[e]!) - heading);
    const want = Math.max(-0.4, Math.min(0.4, off * 1.2));
    hold('KeyA', kart.steer[e]! < want - 0.015);
    hold('KeyD', kart.steer[e]! > want + 0.015);
    // Braking as a driver would: well off its line, or faster than the bend coming up can be taken.
    const coming = CORNERS[c]![Math.min(track.samples - 1, Math.max(0, Math.round(p) + 1))]!;
    hold('KeyS', (!joining && Math.abs(off) > 0.3 && speed > 8) || (!onCutLine && speed > coming * CAUTION));
    // Forward held through the teammate's push (the hard shove), and to get going or over the shortcut.
    hold('KeyW', speed < 4 || onCutLine || kart.clock[e]! < PUSHED_FOR);
  };
  const release = (): void => {
    for (const k of [...held]) hold(k, false);
  };
  const run = (course: number, limit: number, shortcut = false, each?: () => void): { finished: boolean; time: number; progress: number; tookCut: boolean } => {
    takeCut = shortcut;
    build.course[e] = course;
    build.open[e] = COURSES.length;
    ticks(0.2);
    build.order[e] = Order.race;
    // The run begins at the next tick: until then the kart may still show the last one's finish.
    ticks(0.1);
    let s = 0;
    while (kart.phase[e] !== Phase.finished && kart.phase[e] !== Phase.over && s < limit) {
      ticks(1, () => {
        autopilot();
        each?.();
      });
      s++;
    }
    release();
    return { finished: kart.phase[e] === Phase.finished, time: kart.finishTime[e]!, progress: kart.progress[e]!, tookCut: kart.tookCut[e] === 1 };
  };
  return { world, e, ticks, autopilot, run, release };
}
