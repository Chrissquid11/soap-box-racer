/**
 * The breakup matches the garage build (`shed.ts`, `impacts.ts`' shatterBody, `wear.ts`), physics on (`sim.ts`): a
 * whole-kart body on a wide, long chassis with odd-sized wheels, worn right through mid-run so it sheds its parts a
 * moment apart. It checks:
 *  - the bodywork comes off as its wreck (`<model>_wreck`), not nothing, and the handling changes that same tick: the
 *    body's weight, drag and padding off the kart;
 *  - a wheel comes off from its own mount -- the widened track and the lengthened wheelbase -- at that end's size and in
 *    its own tint, its collider its radius, and the kart stops counting it at once;
 *  - R builds the kart exactly as the garage has it again: its body model, weight, drag, padding, every wheel on.
 */
import { BoxCollider, CylinderCollider, type Entity, Hidden, Hierarchy, internKey, Render, RigidBody, Transform } from '@vibe/engine';
import { suite } from '@vibe/engine/testing';
import { BODY, STARTER } from './build.ts';
import { Bodywork, Build, Kart, Order, Phase, RunOut, Wheel } from './components.ts';
import { CRAWL_OUT_FOR } from './damage.ts';
import { unrotate, v3 } from './kart-math.ts';
import { makeSim } from './sim.ts';

const t = suite('game: breakup');
const check = (name: string, ok: boolean, saw: string): void => t.ok(`${name} (${saw})`, ok);

const sim = await makeSim();
const { world, e, ticks } = sim;
const kart = world.store(Kart);
const build = world.store(Build);
const wheel = world.store(Wheel);
const rb = world.store(RigidBody);
const at = world.store(Transform);
const look = world.store(Render);
const tree = world.store(Hierarchy);
const cyl = world.store(CylinderCollider);
const wheels = world.query({ with: [Wheel] });
const loose = world.query({ with: [CylinderCollider, RigidBody, Render] });

const STEAM = BODY.findIndex((b) => b.name === 'Fizz Bomb');
const set = { ...STARTER, body: STEAM, chassisWidth: 140, chassisLength: 105, frontSize: 130, rearSize: 100 };
const garage = (): void => {
  for (const [k, v] of Object.entries(set)) (build[k as keyof typeof STARTER] as Uint8Array)[e] = v;
  build.version[e] = build.version[e]! + 1;
  build.order[e] = Order.garage;
};
const bodyPart = (): number => {
  for (let c = tree.firstChild[e]!; c !== 0; c = tree.nextSibling[c]!) if (world.has(c, Bodywork)) return c;
  return 0;
};
const MODEL = internKey('Model', BODY[STEAM]!.model);
const WRECK = internKey('Model', `${BODY[STEAM]!.model}_wreck`);

ticks(1);
garage();
ticks(1.5);
build.order[e] = Order.race;
ticks(4);
const fresh = { mass: kart.mass[e]!, body: rb.mass[e]!, drag: kart.drag[e]!, grip: kart.seatGrip[e]!, track: kart.halfTrack[e]!, base: kart.halfBase[e]! };
const sizes = new Map<number, { grow: number; radius: number; tint: number; front: boolean; x: number; z: number }>();
for (let i = 0; i < wheels.count; i++) {
  const c = wheels.members[i]!;
  sizes.set(c, { grow: at.sx[c]!, radius: wheel.radius[c]!, tint: look.tint[c]!, front: at.pz[c]! > 0, x: at.px[c]!, z: at.pz[c]! });
}

// Worn through: it sheds, the body first (its wreck), then a wheel.
kart.damage[e] = kart.hp[e]! * 1.05;
let bodyTick = -1, bodySaw = '', wheelSaw = '', wheelOk = false, sameTick = false;
const before = new Set<number>();
for (let i = 0; i < loose.count; i++) before.add(loose.members[i]!);
const local = v3();
for (let n = 0; n < 120 && !wheelSaw; n++) {
  ticks(1 / 60, sim.autopilot);
  if (bodyTick < 0 && !kart.bodyOn[e]) {
    bodyTick = n;
    const b = bodyPart();
    const dm = fresh.mass - kart.mass[e]!;
    bodySaw = `model ${look.model[b] === WRECK ? 'wreck' : look.model[b] === MODEL ? 'whole' : look.model[b]}, hidden ${world.has(b as Entity, Hidden)}, ` +
      `mass ${fresh.mass.toFixed(1)}→${kart.mass[e]!.toFixed(1)} (body ${BODY[STEAM]!.mass}), rb ${fresh.body.toFixed(1)}→${rb.mass[e]!.toFixed(1)}, ` +
      `drag ${fresh.drag.toFixed(2)}→${kart.drag[e]!.toFixed(2)}, seat ${fresh.grip.toFixed(1)}→${kart.seatGrip[e]!.toFixed(1)}`;
    sameTick = look.model[b] === WRECK && Math.abs(dm - BODY[STEAM]!.mass) < 0.01 && Math.abs(fresh.body - rb.mass[e]! - BODY[STEAM]!.mass) < 0.01 &&
      Math.abs(fresh.drag - kart.drag[e]! - BODY[STEAM]!.drag) < 0.01 && Math.abs(fresh.grip - kart.seatGrip[e]! - BODY[STEAM]!.cushion) < 0.01;
  }
  for (let i = 0; i < loose.count; i++) {
    const l = loose.members[i]!;
    if (before.has(l) || world.has(l, Wheel) || world.has(l, Kart)) continue;
    // A new loose wheel: which of the kart's came off this tick, and is it where, how big and what colour that one was?
    for (const [c, s] of sizes) {
      if (wheel.attached[c]) continue;
      unrotate(at.qx[e]!, at.qy[e]!, at.qz[e]!, at.qw[e]!, at.px[l]! - at.px[e]!, at.py[l]! - at.py[e]!, at.pz[l]! - at.pz[e]!, local);
      const scaled = Math.abs(at.sx[l]! - s.grow) < 1e-3;
      const radius = Math.abs(cyl.radius[l]! * at.sx[l]! - s.radius) < 1e-3;
      const tinted = look.tint[l] === s.tint && look.model[l] !== 0;
      const placed = Math.abs(local.x - s.x) < 0.35 && Math.abs(local.z - s.z) < 0.45;
      wheelOk = scaled && radius && tinted && placed && Math.sign(local.x) === Math.sign(s.x);
      wheelSaw = `${s.front ? 'front' : 'rear'} wheel off at (${local.x.toFixed(2)}, ${local.z.toFixed(2)}) of its mount (${s.x.toFixed(2)}, ${s.z.toFixed(2)}) ` +
        `-- the starter's half track 0.50 -- scale ${at.sx[l]!.toFixed(2)} of ${s.grow.toFixed(2)}, collider ${(cyl.radius[l]! * at.sx[l]!).toFixed(3)} m of ${s.radius.toFixed(3)}, tint ${tinted}`;
      break;
    }
  }
}
sim.release();
check('the bodywork comes off as its wreck, and the handling loses it that same tick', bodyTick >= 0 && sameTick, bodySaw || 'never came off');
check('a wheel comes off its widened, lengthened mount, at its size and colour', wheelOk && fresh.track > 0.55 && kart.phase[e] === Phase.racing, wheelSaw || 'no wheel came off');

// Crippled (a wheel and the bodywork off) and barely crawling: the run is over in moments, not the whole OUT_FOR.
build.order[e] = Order.none;
let crawled = 0;
for (let n = 0; n < 6 * 60 && kart.phase[e] === Phase.racing; n++) {
  ticks(1 / 60, () => { rb.velocityX[e] = rb.velocityX[e]! * 0.2; rb.velocityZ[e] = rb.velocityZ[e]! * 0.2; });
  crawled += 1 / 60;
}
check('crippled and crawling, its run ends quickly', kart.phase[e] === Phase.over && kart.out[e] === RunOut.stopped && crawled < CRAWL_OUT_FOR + 1,
  `phase ${kart.phase[e]}, out ${kart.out[e]}, after ${crawled.toFixed(1)} s, wheels lost ${kart.wheelsLost[e]}, body lost ${kart.bodyLost[e]}`);

// R: the garage build again, exactly.
build.order[e] = Order.restart;
ticks(1);
let on = 0;
for (let i = 0; i < wheels.count; i++) if (wheel.attached[wheels.members[i]!]) on++;
const b = bodyPart();
check('R builds it exactly as the garage has it again', look.model[b] === MODEL && Math.abs(kart.mass[e]! - fresh.mass) < 0.01 && Math.abs(rb.mass[e]! - fresh.body) < 0.01 &&
  Math.abs(kart.drag[e]! - fresh.drag) < 1e-4 && Math.abs(kart.seatGrip[e]! - fresh.grip) < 1e-4 && on === 4 && kart.bodyOn[e] === 1 && kart.phase[e] !== Phase.over,
  `model ${look.model[b] === MODEL ? 'whole' : look.model[b]}, mass ${kart.mass[e]!.toFixed(1)} of ${fresh.mass.toFixed(1)}, drag ${kart.drag[e]!.toFixed(2)}, seat ${kart.seatGrip[e]!.toFixed(1)}, ${on} wheels, body on ${kart.bodyOn[e]}`);

// A total wreck: the kart goes as big recognisable chunks of itself -- the Fizz Bomb its can (its own body), the
// fruit crate its crate (its frame) -- with its wheels rolling off, each its own model.
const debris = world.query({ with: [BoxCollider, RigidBody, Render], without: [Kart] });
const wreckOf = (body: number, chassis: number): string => {
  for (const [k, v] of Object.entries({ ...STARTER, body, chassis })) (build[k as keyof typeof STARTER] as Uint8Array)[e] = v;
  build.version[e] = build.version[e]! + 1;
  build.order[e] = Order.restart;
  ticks(1);
  build.order[e] = Order.race;
  ticks(4);
  kart.smash[e] = 1;
  ticks(0.3);
  const models = new Set<number>();
  for (let i = 0; i < debris.count; i++) models.add(look.model[debris.members[i]!]!);
  const wheels = world.query({ with: [CylinderCollider, RigidBody, Render], without: [Kart] }).count;
  return `${[...models].map((m) => names.get(m) ?? '').filter(Boolean).join(', ')}; ${wheels} loose wheels`;
};
const names = new Map<number, string>([[internKey('Model', 'karts/can#can'), 'can'], [internKey('Model', 'karts/can#can_wreck'), 'can (wreck)'], [internKey('Model', 'karts/parts#chassis_crate'), 'crate']]);
const can = wreckOf(STEAM, 1);
check('a wrecked Fizz Bomb throws its can as a chunk, and its wheels', /can/.test(can) && /[1-9] loose wheels/.test(can), can);
const crate = wreckOf(0, 1);
check('a wrecked fruit crate throws its crate frame as a chunk, and its wheels', /crate/.test(crate) && /[1-9] loose wheels/.test(crate), crate);
t.done();
