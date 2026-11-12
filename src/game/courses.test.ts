/**
 * The courses -- the first twenty and the themed tour after them: each designed as it should be -- harder each time, its road never crossing itself, its
 * hazards on the road, its finish downhill of its start -- and each course's Gladius script on disk still
 * the one `scripts/courses.ts` writes from its design (run `node scripts/courses.ts` after a change).
 */
import { readFileSync } from 'node:fs';
import { suite } from '@vibe/engine/testing';
import { courseScript, scriptPath } from '../../scripts/courses.ts';
import { COURSES, TRACKS } from './courses.ts';

const t = suite('game: the courses');

t.ok('twenty courses, then the themed tour of twenty-one', COURSES.length === 41 && COURSES.slice(20).every((c) => c.theme !== ''));
for (const c of COURSES) {
  t.ok(`${c.name}: its script on disk is its design`, readFileSync(scriptPath(c), 'utf8') === courseScript(c));
}
// Harder each time within each set of ten (the valley runs, then the mountain ones, which start again wider) --
// narrower and higher; the valley runs busier too (the mountain ones are harder by their hairpins, which leave less
// straight road for hazards). Busier counts the hazards but the cones: those are a chicane's pieces, as many as a
// chicane has, and a shorter course fits fewer chicanes but more of everything else.
const busy = (i: number): number => COURSES[i]!.hazards.filter((h) => h.kind !== 'cone').length;
const harder = COURSES.slice(0, 20).every((c, i) => i % 10 === 0 || (c.halfWidth <= COURSES[i - 1]!.halfWidth && c.points[0]![1] > COURSES[i - 1]!.points[0]![1] && (i >= 10 || busy(i) >= busy(i - 1))));
t.ok('each course narrower, higher and busier than the last of its set', harder);

for (const [i, c] of COURSES.entries()) {
  const track = TRACKS[i]!;
  // Its road never comes back across itself: samples far apart along it are far apart on the ground.
  let closest = Infinity;
  for (let a = 0; a < track.samples; a += 2) {
    for (let b = a + 40; b < track.samples; b += 2) {
      // (Measured edge to edge: each road as wide as it is there.)
      closest = Math.min(closest, Math.hypot(track.sx[a]! - track.sx[b]!, track.sz[a]! - track.sz[b]!) - track.hw[a]! - track.hw[b]!);
    }
  }
  t.ok(`${c.name}: its road never crosses itself (closest pass ${closest.toFixed(1)} m edge to edge)`, closest > 4);
  t.ok(`${c.name}: the finish is downhill of the start`, track.sy[track.finish]! < track.sy[track.start]! - 10);
  t.ok(`${c.name}: every hazard stands on the road`, c.hazards.every((h) => Math.abs(h.across) <= track.hw[h.sample]! && h.sample > track.start && h.sample < track.finish));
}
t.done();
