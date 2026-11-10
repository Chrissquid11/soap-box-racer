/**
 * The garage's presets (`build.ts`' PRESETS, physics on, `sim.ts`): each is within the rules, rates as it says it
 * drives (the speed build quickest, the stunt build toughest, the stable build steadiest), and finishes the first
 * course; and where a course has a shortcut, the stunt build lands it and gains time by it.
 */
import { suite } from '@vibe/engine/testing';
import { newRating, PRESETS, rate, rulesBreak, STARTER } from './build.ts';
import { Build, Kart, RunOut } from './components.ts';
import { TRACKS } from './courses.ts';
import { makeSim } from './sim.ts';

const t = suite('game: the presets');
const ratingOf = (i: number): ReturnType<typeof newRating> => {
  const r = newRating();
  rate({ ...STARTER, ...PRESETS[i]!.choice }, r);
  return r;
};
const [speed, stunt, stable] = [0, 1, 2].map(ratingOf) as [ReturnType<typeof newRating>, ReturnType<typeof newRating>, ReturnType<typeof newRating>];
PRESETS.forEach((p, i) => {
  const why = rulesBreak(ratingOf(i));
  t.ok(`${p.name} is within the rules${why ? ` (${why})` : ''}`, why === '');
});
t.ok(`each rates as it says: speed ${speed.speed} the quickest, stunt ${stunt.toughness} the toughest, stable ${stable.stability} the steadiest`,
  speed.speed >= stunt.speed && speed.speed >= stable.speed && stunt.toughness >= speed.toughness && stable.stability >= speed.stability && stable.stability >= stunt.stability);

const sim = await makeSim();
const build = sim.world.store(Build);
const kart = sim.world.store(Kart);
const fit = (i: number): void => {
  for (const [k, v] of Object.entries({ ...STARTER, ...PRESETS[i]!.choice })) (build[k as keyof typeof STARTER] as Uint8Array)[sim.e] = v;
  build.version[sim.e] = build.version[sim.e]! + 1;
};
const times: number[] = [];
PRESETS.forEach((p, i) => {
  fit(i);
  const r = sim.run(0, 90, false);
  times.push(r.time);
  t.ok(`${p.name} finishes the first course (${r.finished ? `${r.time.toFixed(2)} s` : RunOut.enum[kart.out[sim.e]!]})`, r.finished);
});
// (The first course has no shortcut -- none of the first ten does: the stunt build's gamble is tried where one is.)
const withCut = TRACKS.findIndex((tr) => tr.cut !== null);
if (withCut >= 0) {
  fit(1);
  const round = sim.run(withCut, 90, false);
  fit(1);
  const cut = sim.run(withCut, 90, true);
  t.ok(`the stunt build lands the shortcut and gains time (${cut.time.toFixed(2)} s against ${round.time.toFixed(2)} s round)`, cut.finished && cut.tookCut && cut.time < round.time);
}
t.done();
