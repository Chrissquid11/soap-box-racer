/**
 * The start (`startLights`, `race`), physics on (`sim.ts`): the arch's three lamps are dark in the garage, come on red
 * one at a time through the countdown and all go green at GO; and a kart flipped onto its roof is out of the run
 * ROOF_FOR seconds later, crashed.
 */
import { Hidden, Render, Transform } from '@vibe/engine';
import { suite } from '@vibe/engine/testing';
import { Build, Kart, Order, Phase, ROOF_FOR, RunOut, StartLamp } from './components.ts';
import { makeSim } from './sim.ts';

const t = suite('game: the start lights and the roof');
const check = (name: string, ok: boolean, saw: string): void => t.ok(`${name} (${saw})`, ok);

const sim = await makeSim();
const { world, e, ticks } = sim;
const lamps = world.query({ with: [StartLamp] });
const kart = world.store(Kart);
const look = world.store(Render);
const at = world.store(Transform);

/** The lamps lit, and their colour: 'red', 'green' or 'off' each, in order. */
const lit = (): string[] => {
  const out = ['off', 'off', 'off'];
  for (let n = 0; n < lamps.count; n++) {
    const l = lamps.members[n]!;
    const i = world.store(StartLamp).index[l]!;
    out[i] = world.has(l, Hidden) ? 'off' : look.tint[l]! & 0x00ff00 && (look.tint[l]! >> 16) < 0x80 ? 'green' : 'red';
  }
  return out;
};

ticks(1);
const garage = lit();
world.store(Build).order[e] = Order.race;
const seen: string[] = [];
let last = '';
for (let n = 0; n < 5 * 60; n++) {
  ticks(1 / 60);
  const now = lit().join(' ');
  if (now !== last) { seen.push(`${kart.clock[e]!.toFixed(1)}: ${now}`); last = now; }
  if (kart.phase[e] === Phase.racing && kart.clock[e]! > 0.5) break;
}
const reds = seen.map((s) => (s.match(/red/g) ?? []).length);
check('three lamps, dark in the garage', lamps.count === 3 && garage.every((l) => l === 'off'), `${lamps.count} lamps: ${garage.join(' ')}`);
check('through the countdown they come on red one at a time, then all green at GO',
  reds.includes(1) && reds.includes(2) && reds.includes(3) && last === 'green green green', seen.join(' | '));

// Flipped onto its roof: the run is over ROOF_FOR seconds later.
sim.release();
at.qx[e] = 0; at.qy[e] = 0; at.qz[e] = 1; at.qw[e] = 0;
at.py[e] = at.py[e]! + 1.5;
let over = -1;
for (let n = 0; n < 5 * 60 && over < 0; n++) {
  ticks(1 / 60);
  if (kart.phase[e] === Phase.over) over = n / 60;
}
check('flipped onto its roof, the run is over in about two seconds', over > 0 && over < ROOF_FOR + 1 && kart.out[e] === RunOut.crashed,
  `over after ${over.toFixed(1)} s, out ${kart.out[e]}, up ${kart.upY[e]!.toFixed(2)}`);
t.done();
