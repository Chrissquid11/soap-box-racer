/**
 * A course's two routes, where one has a shortcut (none of the first ten does) (`courses.ts`' Shortcut, `track.ts`' routeAt, physics on, `sim.ts`): the road round
 * the duck pond finishes; the shortcut over it -- its jump, the pond's gap and the rough landing -- finishes too in a
 * kart built for it, and faster; and the race counts either route the same (no checkpoint skipped).
 */
import { suite } from '@vibe/engine/testing';
import { STARTER } from './build.ts';
import { Build, Kart, RunOut } from './components.ts';
import { TRACKS } from './courses.ts';
import { makeSim } from './sim.ts';

const t = suite('game: the duck pond shortcut');
/** The shortcut's advantage, driven cleanly in a kart built for it, against the road round in the same kart: from at
 * least ADVANTAGE[0] to at most ADVANTAGE[1] -- short and straight over the pond against a long, gentle half circle
 * round it, it is worth a lot if it is landed, and the pond is the price of missing it. */
const ADVANTAGE = [0.1, 0.35] as const;
const sim = await makeSim();
const build = sim.world.store(Build);
const kart = sim.world.store(Kart);
const why = (): string => `${RunOut.enum[kart.out[sim.e]!]}, cause ${kart.cause[sim.e]}, wheels lost ${kart.wheelsLost[sim.e]}, rollovers ${kart.rollovers[sim.e]}`;
const fit = (set: Partial<typeof STARTER>): void => {
  for (const [k, v] of Object.entries({ ...STARTER, ...set })) (build[k as keyof typeof STARTER] as Uint8Array)[sim.e] = v;
  build.version[sim.e] = build.version[sim.e]! + 1;
};

// None of the first ten courses has one (the player learns the road first); the first course that does is tried.
const first = TRACKS.findIndex((tr) => tr.cut !== null);
t.ok(`none of the first ten courses has a shortcut (the first: ${first < 0 ? 'none' : first + 1})`, first < 0 || first >= 10);
if (first >= 0) {
  fit({});
  const main = sim.run(first, 90, false);
  t.ok(`the road round finishes (${main.time.toFixed(2)} s, shortcut ${main.tookCut})`, main.finished && !main.tookCut);
  // A kart for the shortcut: tough treads and shock absorbers.
  fit({ wheels: 7, suspension: 2 });
  const cut = sim.run(first, 90, true);
  t.ok(`the shortcut finishes (${cut.time.toFixed(2)} s, progress ${cut.progress.toFixed(1)}: ${why()})`, cut.finished && cut.tookCut);
  fit({ wheels: 7, suspension: 2 });
  const round = sim.run(first, 90, false);
  const roundWhy = why();
  t.ok(`and saves time in the same kart: ${cut.time.toFixed(2)} s against ${round.time.toFixed(2)} s round (${((1 - cut.time / round.time) * 100).toFixed(1)}%; round: ${round.finished ? 'finished' : `${roundWhy}, progress ${round.progress.toFixed(1)}`})`,
    cut.finished && round.finished && cut.time < round.time * (1 - ADVANTAGE[0]) && cut.time > round.time * (1 - ADVANTAGE[1]));
}
t.done();
