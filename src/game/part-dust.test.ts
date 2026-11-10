/**
 * The garage's dust (`partDust`): a part swapped there raises a puff of dust on the kart, and it is still there a
 * moment later -- not swept away with the debris by the reset the swap sets off (`RaceReset`, `sweep`).
 */
import { internKey, Render, Transform } from '@vibe/engine';
import { suite } from '@vibe/engine/testing';
import { STARTER } from './build.ts';
import { Build, Fx, Kart, Order, Phase } from './components.ts';
import { COURSES } from './courses.ts';
import { makeSim } from './sim.ts';

const t = suite('game: garage dust');
const check = (name: string, ok: boolean, saw: string): void => t.ok(`${name} (${saw})`, ok);

/** The dust's tint (part-dust.ts' DUST). */
const DUST = 0xf2eee6;

const sim = await makeSim();
const { world, e, ticks } = sim;
const build = world.store(Build);
const kart = world.store(Kart);
const look = world.store(Render);
const at = world.store(Transform);
const puffs = world.query({ with: [Fx, Render] });
const dust = (): number => {
  let n = 0;
  for (let i = 0; i < puffs.count; i++) if (look.tint[puffs.members[i]!] === DUST) n++;
  return n;
};

ticks(1);
for (const [k, v] of Object.entries(STARTER)) (build[k as keyof typeof STARTER] as Uint8Array)[e] = v;
build.course[e] = 0;
build.open[e] = COURSES.length;
build.version[e] = build.version[e]! + 1;
build.order[e] = Order.garage;
ticks(0.5);
check('in the garage', kart.phase[e] === Phase.garage, `phase ${kart.phase[e]}`);
check('no dust before anything is changed', dust() === 0, `${dust()} puffs`);

// A part swapped, as the garage does it (`setSlot`): the slot set, the kart rebuilt and set down on the line.
build.wheels[e] = (build.wheels[e]! + 1) % 8;
build.version[e] = build.version[e]! + 1;
build.order[e] = Order.garage;
ticks(0.1);
check('a part swapped raises dust, and it lasts a moment', dust() >= 4, `${dust()} puffs after 0.1 s`);
// Late in its life: still most of its size, worn faint (a fainter dust material) rather than shrunk away.
ticks(0.9);
const faint = internKey('Material', 'fx/dust');
let fading = 0, big = 0, seen = 0;
for (let i = 0; i < puffs.count; i++) {
  const p = puffs.members[i]!;
  if (look.tint[p] !== DUST) continue;
  seen++;
  if (look.material[p] !== faint) fading++;
  if (at.sx[p]! > 0.15) big++;
}
check('late on it fades rather than shrinks', seen > 0 && fading === seen && big === seen, `${seen} puffs, ${fading} faded, ${big} still full size`);
ticks(2);
check('and it clears by itself', dust() === 0, `${dust()} puffs after 2 s more`);

t.done();
