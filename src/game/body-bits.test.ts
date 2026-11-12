/**
 * A body's bits that come off on their own (`BODY`'s bits, `impacts`): the shark's jaw, side fins, dorsal fin and tail.
 * Built, all five are drawn on it; a sideswipe into the left wall takes its left fin, and only bits facing a knock go;
 * a rebuild puts them all back. Physics on (`sim.ts`): the knock is the kart pushed sideways into the course's wall.
 */
import { type Entity, Hidden, RigidBody, Transform } from '@vibe/engine';
import { suite } from '@vibe/engine/testing';
import { BODY, STARTER } from './build.ts';
import { BodyBit, Breakable, Build, Kart, Order, Pusher } from './components.ts';
import { COURSES, TRACKS } from './courses.ts';
import { makeSim } from './sim.ts';

const t = suite('game: body bits');
const check = (name: string, ok: boolean, saw: string): void => t.ok(`${name} (${saw})`, ok);

const SHARK = BODY.findIndex((b) => b.name === 'Great White Hope');
const shark = BODY[SHARK]!;
const TACO = BODY.findIndex((b) => b.name === 'Shell Suit');
/** The body built now, and its bits. */
let which = SHARK;
const bitsOf = (): readonly { part: string }[] => BODY[which]!.bits ?? [];

const sim = await makeSim();
const { world, e, ticks } = sim;
const kart = world.store(Kart);
const build = world.store(Build);
const rb = world.store(RigidBody);
const at = world.store(Transform);
const bit = world.store(BodyBit);
const slots = world.query({ with: [BodyBit] });
const teammates = world.query({ with: [Pusher] });
const bales = world.query({ with: [Breakable] });

/** The bits shown on the kart, and those knocked off, by name. */
const shown = (): string[] => {
  const out: string[] = [];
  for (let i = 0; i < slots.count; i++) {
    const s = slots.members[i]! as Entity;
    if (!world.has(s, Hidden) && !bit.off[s]) out.push(bitsOf()[bit.slot[s]!]?.part ?? '?');
  }
  return out.sort();
};
const off = (): string[] => {
  const out: string[] = [];
  for (let i = 0; i < slots.count; i++) {
    const s = slots.members[i]! as Entity;
    if (bit.off[s]) out.push(bitsOf()[bit.slot[s]!]?.part ?? '?');
  }
  return out.sort();
};
const across = (): number => {
  const tr = TRACKS[0]!;
  const j = Math.max(0, Math.min(tr.samples - 1, Math.round(kart.progress[e]!)));
  return -((at.px[e]! - tr.sx[j]!) * -tr.tz[j]! + (at.pz[e]! - tr.sz[j]!) * tr.tx[j]!);
};
const leftOf = (): { x: number; z: number } => {
  const tr = TRACKS[0]!;
  const j = Math.max(0, Math.min(tr.samples - 1, Math.round(kart.progress[e]!)));
  return { x: tr.tz[j]!, z: -tr.tx[j]! };
};

ticks(1);
const fresh = (): void => {
  sim.release();
  for (const [k, v] of Object.entries({ ...STARTER, body: which, chassis: BODY[which]!.on ?? 1 })) (build[k as keyof typeof STARTER] as Uint8Array)[e] = v;
  build.version[e] = build.version[e]! + 1;
  build.course[e] = 0;
  build.open[e] = COURSES.length;
  build.order[e] = Order.restart;
  ticks(0.3);
  for (let i = 0; i < teammates.count; i++) world.store(Pusher).push[teammates.members[i]!] = 0;
  ticks(4, sim.autopilot);
  ticks(2, sim.autopilot);
  sim.release();
  const gone: Entity[] = [];
  for (let i = 0; i < bales.count; i++) gone.push(bales.members[i]! as Entity);
  for (const b of gone) world.destroy(b);
};

fresh();
check('built, all five of its bits are on it', shown().length === 5 && off().length === 0, `shown ${shown().join(', ')}; off ${off().join(', ')}`);

/** Sideswiped into the left wall, flat (its middle, between the wheels, takes it), until something comes off: what did. */
const sideswipe = (): string[] => {
  const l0 = leftOf(), move = TRACKS[0]!.halfWidth - 1.0 - across();
  at.px[e] = at.px[e]! + l0.x * move;
  at.pz[e] = at.pz[e]! + l0.z * move;
  ticks(1 / 60);
  let hit = false;
  ticks(1, () => {
    if (hit) return;
    const l = leftOf();
    const lateral = rb.velocityX[e]! * l.x + rb.velocityZ[e]! * l.z;
    rb.velocityX[e] = rb.velocityX[e]! + l.x * (7 - lateral);
    rb.velocityZ[e] = rb.velocityZ[e]! + l.z * (7 - lateral);
    rb.angularVelocityY[e] = 0;
    if (off().length > 0) hit = true;
  });
  return off();
};

// The shark: its left fin off, its jaw and tail on.
const gone = sideswipe();
check('a sideswipe into the left wall takes the left fin', gone.includes('fin_l'), `off ${gone.join(', ') || 'nothing'}; body ${kart.bodyState[e]}, bodyOn ${kart.bodyOn[e]}, hit side ${kart.hitSide[e]!.toFixed(2)} end ${kart.hitEnd[e]!.toFixed(2)}, wear ${kart.damage[e]!.toFixed(2)}, across ${across().toFixed(2)} of ${TRACKS[0]!.halfWidth}, hurts ${kart.hurts[e]}, phase ${kart.phase[e]}`);
check('and leaves the jaw and the tail on', !gone.includes('jaw') && !gone.includes('tail') || !kart.bodyOn[e], `off ${gone.join(', ')}`);

// A rebuild: all back on.
fresh();
check('a rebuild puts them all back', shown().length === 5 && off().length === 0, `shown ${shown().join(', ')}`);

// The taco: both shell sides on; a sideswipe on the left takes the left side (with its filling) and not the right.
which = TACO;
fresh();
check('the taco built, both its shell sides are on it', shown().join(',') === 'panel_l,panel_r', `shown ${shown().join(', ')}`);
const spilt = sideswipe();
check('a sideswipe into the left wall takes its left side, not its right', spilt.includes('panel_l') && (!spilt.includes('panel_r') || !kart.bodyOn[e]), `off ${spilt.join(', ') || 'nothing'}`);

t.done();
