/**
 * Writes the ten course models' Gladius scripts from the game's course designs (src/game/courses.ts):
 * AssetsSource/models/courses/c01.lua ... c10.lua, each a design handed to the shared library
 * `_course.lua`. Run it after changing a design -- `node scripts/courses.ts` -- and the dev server exports
 * the scripts that changed. `src/game/courses.test.ts` checks the scripts on disk still say what this writes.
 */
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { COURSES, type Course, TRACKS } from '../src/game/courses.ts';

const n = (x: number): string => String(Math.round(x * 1000) / 1000);
const v = (c: readonly number[]): string => `{${c.map(n).join(', ')}}`;

/** One course's script, as text. */
export function courseScript(c: Course): string {
  const points = c.points.map((p) => v(p));
  const rows: string[] = [];
  for (let i = 0; i < points.length; i += 6) rows.push(`    ${points.slice(i, i + 6).join(', ')},`);
  // Each sample's share of the half width (the road narrowing and widening), twenty a row.
  const widths: string[] = [];
  for (let i = 0; i < c.widths.length; i += 20) widths.push(`    ${c.widths.slice(i, i + 20).map(n).join(', ')},`);
  return `-- Course ${c.difficulty + 1} of ${COURSES.length}: ${c.name}. ${c.blurb}
--
-- Written by scripts/courses.ts from its design in src/game/courses.ts: change the design there and run
-- \`node scripts/courses.ts\`, never this file by hand (src/game/courses.test.ts checks it). The road, the
-- walls, the valley and the arches are the shared library's (_course.lua).
local P = params{
  trees = {default=${c.urban ? 24 : c.difficulty < 10 ? 80 + c.difficulty * 6 : 100 - (c.difficulty - 10) * 6}, min=0, max=250, integer=true, doc="Trees scattered on the slopes"},
  bank  = {default=0.3, min=0.05, max=0.8, doc="How steeply the valley sides rise away from the road"},
}

include("_course.lua").build({
  points = {
${rows.join('\n')}
  },
  berms = {${c.berms.map(n).join(', ')}},
  half_width = ${n(c.halfWidth)},
  widths = {
${widths.join('\n')}
  },
  wall_h = ${n(c.wallHeight)},
  start_point = ${c.startPoint + 1},
  finish_point = ${c.finishPoint + 1},
  road = ${v(c.road)},
  grass = ${v(c.grass)},
  hay = ${v(c.hay)},
  seed = ${7 + c.difficulty * 13},
  urban = ${c.urban},
  railed = ${c.railed},
  bare = ${c.bare},
  start_ramp = ${c.startRamp},${c.shortcut ? `
  shortcut = {from=${c.shortcut.from}, to=${c.shortcut.to}, half_width=${n(c.shortcut.halfWidth)}, pond_from=${n(c.shortcut.pondFrom)}, pond_to=${n(c.shortcut.pondTo)}, y_from=${n(TRACKS[c.difficulty]!.cut!.ay)}, y_to=${n(TRACKS[c.difficulty]!.cut!.by)}},` : ''}
}, P)
`;
}

/** Where a course's script lives. */
export function scriptPath(c: Course): URL {
  return new URL(`../AssetsSource/models/courses/c${String(c.difficulty + 1).padStart(2, '0')}.lua`, import.meta.url);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  for (const c of COURSES) {
    writeFileSync(scriptPath(c), courseScript(c));
    console.info(`wrote ${fileURLToPath(scriptPath(c))}: ${c.name}`);
  }
}
