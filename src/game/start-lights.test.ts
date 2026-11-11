/**
 * The start (`startLights`, `race`), physics on (`sim.ts`): the arch's three lamps are dark in the garage, come on red
 * one at a time through the countdown and all go green at GO; and a kart flipped onto its roof is destroyed --
 * wrecked, every wheel off, the driver thrown -- and the run over after the crash cam.
 */
import { Hidden, Render, Transform } from '@vibe/engine';
import { suite } from '@vibe/engine/testing';
import { Build, Kart, Order, Phase, ROOF_FOR, RunOut, StartLamp, Wheel } from './components.ts';
import { makeSim } from './sim.ts';

const t = suite('game: the start lights and the roof');
const check = (name: string, ok: boolean, saw: string): void => t.ok(`${name} (${saw})`, ok);

const sim = await makeSim();
const { world, e, ticks } = sim;
const lamps = world.query({ with: [StartLamp] });
const kart = world.store(Kart);
const look = world.store(Render);
const at = world.store(Transform);
const wheel = world.store(Wheel);
const wheels = world.query({ with: [Wheel] });

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

// Flipped onto its roof: destroyed -- wrecked, every wheel off, all the damage it can take, the driver thrown -- and
// the run over once the crash cam has had its look (`race`' WRECK, 3 s).
sim.release();
at.qx[e] = 0; at.qy[e] = 0; at.qz[e] = 1; at.qw[e] = 0;
at.py[e] = at.py[e]! + 1.5;
let over = -1;
let wheelsOff = 0, worn = 0, thrown = false;
for (let n = 0; n < 6 * 60 && over < 0; n++) {
  ticks(1 / 60);
  if (kart.wrecked[e] && wheelsOff === 0) {
    for (let i = 0; i < wheels.count; i++) if (!wheel.attached[wheels.members[i]!]) wheelsOff++;
    worn = kart.damage[e]! / Math.max(1, kart.hp[e]!);
    thrown = kart.ejected[e] === 1 || kart.thrown[e] !== 0;
  }
  if (kart.phase[e] === Phase.over) over = n / 60;
}
check('flipped onto its roof, it is destroyed: every wheel off, all the damage it can take, the driver thrown',
  kart.out[e] === RunOut.wrecked && wheelsOff >= 4 && worn >= 1 && thrown, `out ${kart.out[e]}, wheels off ${wheelsOff}, damage ${(worn * 100).toFixed(0)}%, thrown ${thrown}`);
check('and the run is over after the crash cam', over > 0 && over < ROOF_FOR + 3, `over after ${over.toFixed(1)} s, up ${kart.upY[e]!.toFixed(2)}`);
t.done();
