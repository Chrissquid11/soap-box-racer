/**
 * Records the rivals' reference runs (src/game/ghost-runs.ts) from the game in node (src/game/sim.ts): each rival
 * driven down its course by the autopilot in its build, on its route, in its weather, its kart's place and turn kept
 * every GHOST_STEP seconds of the race clock from GO to the finish. Run it after a course or the handling changes --
 * `node scripts/ghost.ts` -- and the ghosts replay what the game does now. Only a run that finished is written.
 */
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Transform } from '@vibe/engine';
import { PRESETS, STARTER } from '../src/game/build.ts';
import { Build, Kart, Phase } from '../src/game/components.ts';
import { GHOST_STEP } from '../src/game/ghost-runs.ts';
import { makeSim } from '../src/game/sim.ts';

/** Who to record: a name, a course, a preset, a route, a weather (0 sunny). */
const RIVALS = [
  { name: 'Granny', course: 0, preset: 2, shortcut: false, weather: 0 },
] as const;

const sim = await makeSim();
const { world, e } = sim;
const kart = world.store(Kart);
const build = world.store(Build);
const at = world.store(Transform);
const out: string[] = [];
for (const r of RIVALS) {
  for (const [k, v] of Object.entries({ ...STARTER, ...PRESETS[r.preset]!.choice })) (build[k as keyof typeof STARTER] as Uint8Array)[e] = v;
  build.version[e] = build.version[e]! + 1;
  // A run, the autopilot at the keys (`sim.run`'s), the kart's place kept on the race clock's steps.
  const frames: number[] = [];
  let next = 0;
  const keep = (): void => {
    if (kart.phase[e] !== Phase.racing && kart.phase[e] !== Phase.finished) return;
    const t = kart.clock[e]!;
    if (t < next || kart.phase[e] === Phase.finished && frames.length > 0 && t > kart.finishTime[e]! + GHOST_STEP) return;
    next += GHOST_STEP;
    frames.push(...[at.px[e]!, at.py[e]!, at.pz[e]!, at.qx[e]!, at.qy[e]!, at.qz[e]!, at.qw[e]!].map((n) => Math.round(n * 1000) / 1000));
  };
  const run = sim.run(r.course, 120, r.shortcut, keep);
  if (!run.finished) throw new Error(`${r.name}'s run on course ${r.course + 1} did not finish`);
  out.push(`  {
    name: '${r.name}', course: ${r.course}, weather: ${r.weather}, shortcut: ${r.shortcut}, finish: ${Math.round(run.time * 100) / 100},
    frames: [${frames.join(', ')}],
  },`);
  console.info(`${r.name}: course ${r.course + 1}, ${run.time.toFixed(2)} s, ${frames.length / 7} frames`);
}

const file = new URL('../src/game/ghost-runs.ts', import.meta.url);
const head = `/**
 * The rivals' reference runs, recorded by scripts/ghost.ts from the game in node -- never by hand: each rival's kart
 * every GHOST_STEP seconds of the race clock from GO (x, y, z, then its turn as a quaternion: seven numbers a step),
 * on its course, in its weather, by its route; \`finish\` its finish time, which the HUD shows and the playback ends at.
 * The ghost system (\`systems/ghost.ts\`) replays one where it fits the course and the weather.
 */
export const GHOST_STEP = 0.1;

export interface GhostRun {
  readonly name: string;
  readonly course: number;
  readonly weather: number;
  readonly shortcut: boolean;
  readonly finish: number;
  readonly frames: readonly number[];
}

export const GHOST_RUNS: readonly GhostRun[] = [
${out.join('\n')}
];
`;
writeFileSync(file, head);
console.info(`wrote ${fileURLToPath(file)}`);
