/**
 * Each body's signature piece (`signatures.ts`, `impacts.ts`' shatterBody), physics on (`sim.ts`). It checks:
 *  - every entry names a body there is, and every piece has its size and how it leaves;
 *  - the snail worn through mid-run: its shell comes off as its own model (`snail_sig`) where it sat on the kart, and
 *    rolls off faster than the kart -- a second on, it is ahead of it.
 */
import { Render, RigidBody, Transform, internKey } from '@vibe/engine';
import { suite } from '@vibe/engine/testing';
import { BODY, STARTER } from './build.ts';
import { Build, Kart, Order } from './components.ts';
import { unrotate, v3 } from './kart-math.ts';
import { SIGNATURES } from './signatures.ts';
import { makeSim } from './sim.ts';

const t = suite('game: signatures');
const check = (name: string, ok: boolean, saw: string): void => t.ok(`${name} (${saw})`, ok);

const names = new Set(BODY.map((b) => b.name));
const unknown = Object.keys(SIGNATURES).filter((n) => !names.has(n));
const unshaped = Object.entries(SIGNATURES).filter(([, s]) => s.at && (!s.size || !s.leave)).map(([n]) => n);
check('every signature is a body, every piece sized and sent somewhere', unknown.length === 0 && unshaped.length === 0,
  `unknown ${unknown.join(', ') || 'none'}; unshaped ${unshaped.join(', ') || 'none'}`);

const sim = await makeSim();
const { world, e, ticks } = sim;
const kart = world.store(Kart);
const build = world.store(Build);
const at = world.store(Transform);
const look = world.store(Render);
const pieces = world.query({ with: [RigidBody, Render] });

const SNAIL = BODY.findIndex((b) => b.name === 'Escargot Fast');
const SHELL = internKey('Model', `${BODY[SNAIL]!.model}_sig`);
for (const [k, v] of Object.entries({ ...STARTER, body: SNAIL })) (build[k as keyof typeof STARTER] as Uint8Array)[e] = v;
build.version[e] = build.version[e]! + 1;
build.order[e] = Order.garage;
ticks(1.5);
build.order[e] = Order.race;
ticks(5, sim.autopilot);

kart.damage[e] = kart.hp[e]! * 1.05;
const local = v3();
let shell = 0, placed = '', near = false;
for (let n = 0; n < 120 && !shell; n++) {
  ticks(1 / 60, sim.autopilot);
  for (let i = 0; i < pieces.count; i++) {
    const p = pieces.members[i]!;
    if (look.model[p] !== SHELL) continue;
    shell = p;
    unrotate(at.qx[e]!, at.qy[e]!, at.qz[e]!, at.qw[e]!, at.px[p]! - at.px[e]!, at.py[p]! - at.py[e]!, at.pz[p]! - at.pz[e]!, local);
    near = Math.abs(local.x) < 0.3 && local.z < 0 && local.z > -1.6;
    placed = `at (${local.x.toFixed(2)}, ${local.y.toFixed(2)}, ${local.z.toFixed(2)}) of the kart`;
  }
}
check('the snail sheds its shell as its own piece, from behind the driver', shell !== 0 && near, placed || 'no shell came off');
ticks(1.2, sim.autopilot);
let ahead = '', overtook = false;
if (shell) {
  unrotate(at.qx[e]!, at.qy[e]!, at.qz[e]!, at.qw[e]!, at.px[shell]! - at.px[e]!, at.py[shell]! - at.py[e]!, at.pz[shell]! - at.pz[e]!, local);
  overtook = local.z > 0.5;
  ahead = `${local.z.toFixed(2)} m along the kart, kart at ${kart.speed[e]!.toFixed(1)} m/s`;
}
sim.release();
check('the shell overtakes the kart', overtook, ahead || 'no shell');
t.done();
