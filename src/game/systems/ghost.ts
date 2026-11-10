/**
 * ghost, 60 Hz, late: the rival ghost to chase -- a see-through kart replaying a recorded run (`ghost-runs.ts`) on the
 * race clock: from the countdown (waiting at its start) to its finish (stopped there after), each moment's place
 * between the two recorded steps either side of it. Only where a recorded run fits the course and the weather; G hides
 * it and shows it again. It has no body: nothing collides with it. Only the look.
 */
import { Hidden, NO_REF, NONE, Transform, type World } from '@vibe/engine';
import { Ghost, Kart, Phase } from '../components.ts';
import { TRACKS } from '../courses.ts';
import { GHOST_RUNS, GHOST_STEP, type GhostRun } from '../ghost-runs.ts';
import { GhostKart } from '../prefabs.ts';

/** How far (metres, across the ground) a recorded run's end may be from its course's finish line and still be this
 * course's run: further, the course has been redrawn since it was recorded (scripts/ghost.ts records it again),
 * and replaying it would fly a ghost through the sky over a road that is no longer there. */
const STALE = 12;

/** Whether a recorded run still fits its course as drawn now: it ends at (past) the finish line. */
function fitsTrack(run: GhostRun): boolean {
  const t = TRACKS[run.course];
  const n = run.frames.length / 7;
  if (!t || n < 2) return false;
  const a = (n - 1) * 7;
  const f = Math.max(0, Math.min(t.samples - 1, t.finish));
  return Math.hypot(run.frames[a]! - t.sx[f]!, run.frames[a + 2]! - t.sz[f]!) < STALE;
}
const FITS = GHOST_RUNS.map(fitsTrack);

/** The rival ghosts on or off: off for now (no ghost rides, and the HUD names none to beat). */
export const GHOSTS_ON = false;

/** The recorded run that fits a course in a weather, and the course as it is drawn now: its index, or -1 (always, with
 * the ghosts off). */
export function ghostFor(course: number, weather: number): number {
  if (!GHOSTS_ON) return -1;
  return GHOST_RUNS.findIndex((r, i) => r.course === course && r.weather === weather && FITS[i]);
}

/** Where a run's kart is at race time `t` (clamped to its run), into `out` (x y z qx qy qz qw). */
export function ghostAt(run: GhostRun, t: number, out: Float64Array): void {
  const n = run.frames.length / 7;
  const f = Math.max(0, Math.min(n - 1, Math.min(t, run.finish) / GHOST_STEP));
  const i = Math.min(n - 2, Math.floor(f));
  const k = Math.max(0, Math.min(1, f - i));
  const a = i * 7, b = (i + 1) * 7;
  for (let j = 0; j < 3; j++) out[j] = run.frames[a + j]! + (run.frames[b + j]! - run.frames[a + j]!) * k;
  // The turn: the nearer way round, blended and set back to unit length.
  let dot = 0;
  for (let j = 3; j < 7; j++) dot += run.frames[a + j]! * run.frames[b + j]!;
  const sign = dot < 0 ? -1 : 1;
  let len = 0;
  for (let j = 3; j < 7; j++) {
    out[j] = run.frames[a + j]! * (1 - k) + run.frames[b + j]! * sign * k;
    len += out[j]! * out[j]!;
  }
  len = Math.sqrt(len) || 1;
  for (let j = 3; j < 7; j++) out[j] = out[j]! / len;
}

const pose = new Float64Array(7);

export function ghost(world: World): void {
  world.system({
    name: 'ghost',
    rate: 60,
    with: [Kart],
    read: [],
    write: [Kart, Transform],
    lateUpdate({ members, count, cmd, ref, deref, has, input }, _read, [kart, at]) {
      for (let n = 0; n < count; n++) {
        const e = members[n];
        if (input.pressed('KeyG')) kart.ghostOff[e] = kart.ghostOff[e] ? 0 : 1;
        const which = ghostFor(kart.course[e], kart.weather[e]);
        let g = deref(kart.ghost[e]);
        const phase = kart.phase[e];
        const running = phase === Phase.countdown || phase === Phase.racing || phase === Phase.finished;
        // Made the first time it is wanted; gone when no run fits (another course, other weather).
        if (which < 0) {
          if (g !== NONE) cmd.destroy(g);
          kart.ghost[e] = NO_REF;
          continue;
        }
        if (g === NONE) {
          if (!running) continue;
          g = cmd.instantiate(GhostKart);
          if (g === NONE) continue;
          const gh = cmd.init(g, Ghost);
          gh.kart[g] = ref(e);
          gh.run[g] = which;
          kart.ghost[e] = ref(g);
        }
        const show = running && !kart.ghostOff[e];
        const hidden = has(g, Hidden);
        if (show && hidden) cmd.remove(g, Hidden);
        else if (!show && !hidden) cmd.add(g, Hidden);
        if (!show) continue;
        ghostAt(GHOST_RUNS[which]!, Math.max(0, kart.clock[e]), pose);
        at.px[g] = pose[0]!;
        at.py[g] = pose[1]!;
        at.pz[g] = pose[2]!;
        at.qx[g] = pose[3]!;
        at.qy[g] = pose[4]!;
        at.qz[g] = pose[5]!;
        at.qw[g] = pose[6]!;
      }
    },
  });
}
