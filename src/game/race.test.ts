/**
 * The game in node, physics on (`sim.ts`: the courses' roads, walls, ramps and jumps as collision meshes,
 * the kart as `populate` makes it, an autopilot at the keys). It checks the kart parks on its springs in
 * the garage, every chassis builds, a course loads with its hazards and a locked one will not run, the
 * starter build gets down the first course and over the line with its driver, a flimsy top-heavy build is
 * warned of, R puts everything back as new, and a flimsy build mashed about never spins itself apart.
 */
import { RigidBody } from '@vibe/engine';
import { suite } from '@vibe/engine/testing';
import { BODY, CHASSIS, newRating, rate, type Rating, rulesBreak, STARTER } from './build.ts';
import { Breakable, Build, Debris, Kart, Order, OUT_FOR, Phase, Prop, Pusher, RunOut, Wheel } from './components.ts';
import { COURSES, laidFlat } from './courses.ts';
import { makeSim } from './sim.ts';

const t = suite('game: soap box racer');
/** A check named with what was measured, so a failure says it. */
const check = (name: string, ok: boolean, saw: string): void => t.ok(`${name} (${saw})`, ok);

const sim = await makeSim();
const { world, e, ticks } = sim;
const kart = world.store(Kart);
const build = world.store(Build);
const wheel = world.store(Wheel);
const wheels = world.query({ with: [Wheel] });
const props = world.query({ with: [Prop] });
const bales = world.query({ with: [Breakable] });
const input = world.loop.input;
const grounded = (): number => {
  let n = 0;
  for (let i = 0; i < wheels.count; i++) if (wheel.grounded[wheels.members[i]!]) n++;
  return n;
};

// The garage: the first course loaded, the kart parked on its springs on the line.
ticks(2);
check('the first course loads, with its hazards', kart.course[e] === 0 && props.count > 0, `course ${kart.course[e]}, ${props.count} things to knock over`);
check('in the garage, parked on the line', kart.phase[e] === Phase.garage && kart.speed[e]! < 0.3, `phase ${kart.phase[e]} at ${kart.speed[e]!.toFixed(2)} m/s`);
check('sitting on all four wheels', grounded() === 4, `${grounded()} down`);

// Every chassis builds: its mass is the build's, and it stands on its wheels.
const rating: Rating = newRating();
const masses: string[] = [];
let built = true;
for (let c = 0; c < CHASSIS.length; c++) {
  build.chassis[e] = c;
  build.version[e] = build.version[e]! + 1;
  build.order[e] = Order.garage;
  ticks(1.5);
  const want = rate({ ...STARTER, chassis: c }, rating).mass;
  masses.push(`${CHASSIS[c]!.name} ${kart.mass[e]!.toFixed(0)} kg ${grounded()}w`);
  if (Math.abs(kart.mass[e]! - want) > 0.5 || grounded() !== 4) built = false;
}
check('every chassis builds and stands on its wheels', built, masses.join(', '));

// Every kart the garage offers, as it comes (a bare chassis, or a body on the chassis it comes on), is within the
// rules: the budget, the weight limit, the sizes and the ground clearance.
const outside: string[] = [];
for (let j = 0; j < CHASSIS.length; j++) {
  const why = rulesBreak(rate({ ...STARTER, chassis: j, body: 0 }, rating));
  if (why) outside.push(`${CHASSIS[j]!.name}: ${why} (${rating.warnings.join('; ')})`);
}
for (let j = 1; j < BODY.length; j++) {
  const why = rulesBreak(rate({ ...STARTER, chassis: BODY[j]!.on ?? 1, body: j }, rating));
  if (why) outside.push(`${BODY[j]!.name}: ${why} (${rating.warnings.join('; ')})`);
}
check('every kart in the garage, as it comes, is within the rules', outside.length === 0, outside.join(' | '));
build.chassis[e] = STARTER.chassis;
build.version[e] = build.version[e]! + 1;

// Another course: loaded in the old one's place; locked, it will not run.
build.course[e] = 4;
ticks(1);
// (The round bales among the hazards burst too: Breakable, counted with the walls' bales.)
const standing = COURSES[4]!.hazards.filter((h) => !laidFlat(h.kind) && h.kind !== 'bale').length;
check('a course loads in place of the last, its edges lined with bales', kart.course[e] === 4 && bales.count > 20 && props.count - bales.count === standing,
  `course ${kart.course[e]}, ${props.count - bales.count} props for ${COURSES[4]!.hazards.length} hazards, ${bales.count} bales`);
build.open[e] = 1;
build.order[e] = Order.race;
ticks(0.5);
check('a locked course will not run', kart.phase[e] === Phase.garage, `phase ${kart.phase[e]}`);

// The starter build, down the first course with the autopilot.
const first = sim.run(0, 120);
check('the starter build gets down the first course and over the line', first.finished,
  `${first.finished ? `in ${first.time.toFixed(1)} s (medals ${COURSES[0]!.medals.join('/')})` : `stuck at ${first.progress.toFixed(0)}`}, thrown ${kart.ejections[e]}, wheels lost ${kart.wheelsLost[e]}`);

// A plank under a city car piled with luggage, on casters bolted on, is warned of; and up on tall bike wheels, top
// heavy (a tall kart's weight is slung low -- `rate` -- but not that low).
const flimsy = rate({ ...STARTER, chassis: 0, body: BODY.findIndex((b) => b.name === 'Moving Violation'), wheels: 1, suspension: 0 }, rating);
const flimsyWarned = flimsy.warnings.some((w) => w.startsWith('No suspension'));
const flimsyWords = flimsy.warnings.join(' | ');
const perched = rate({ ...STARTER, chassis: 0, body: BODY.findIndex((b) => b.name === 'Moving Violation'), wheels: 2, suspension: 0 }, rating);
check('a top-heavy flimsy build is warned of', flimsyWarned && perched.warnings.some((w) => w.startsWith('Top heavy')), `${flimsyWords}; on bike wheels: ${perched.warnings.join(' | ')}`);

// R: back on the line, as new.
input.edge('KeyR', true);
ticks(0.1);
input.edge('KeyR', false);
ticks(1);
let attached = 0;
for (let i = 0; i < wheels.count; i++) if (wheel.attached[wheels.members[i]!]) attached++;
check('R starts again: counting down on the line, every wheel on', kart.phase[e] === Phase.countdown && kart.progress[e]! < 12 && attached === 4,
  `phase ${kart.phase[e]}, at ${kart.progress[e]!.toFixed(1)}, ${attached} wheels`);

// The build that once shook itself apart -- a plank on bike wheels, bolted on: driven with keys
// mashed at random, it may tumble, but never spins like a blown-up body.
build.chassis[e] = 0;
build.wheels[e] = 2;
build.suspension[e] = 0;
build.version[e] = build.version[e]! + 1;
build.order[e] = Order.race;
const rb = world.store(RigidBody);
let seed = 7;
let fastest = 0;
const mash = ['KeyA', 'KeyD', 'KeyS', 'KeyW', 'KeyQ', 'KeyE'];
const down = new Set<string>();
ticks(20, () => {
  seed = (seed * 1103515245 + 12345) % 2147483648;
  if (seed % 20 === 0) {
    const k = mash[seed % mash.length]!;
    if (down.has(k)) down.delete(k);
    else down.add(k);
    input.edge(k, down.has(k));
  }
  fastest = Math.max(fastest, Math.hypot(rb.angularVelocityX[e]!, rb.angularVelocityY[e]!, rb.angularVelocityZ[e]!));
});
check('a flimsy build mashed about never spins itself apart', fastest < 25, `fastest turn ${fastest.toFixed(1)} rad/s`);
for (const k of down) input.edge(k, false);

// Sizes: from tiny wheels to tractor tyres twice the size, rebuilt on the line wherever it was -- it sets down on
// its new wheels (not buried in the road by them, nor kicked spinning by the move), and stands on all four.
const resize = (set: Partial<typeof STARTER>): void => {
  for (const [k, v] of Object.entries({ ...STARTER, ...set })) (build[k as keyof typeof STARTER] as Uint8Array)[e] = v;
  build.version[e] = build.version[e]! + 1;
  build.order[e] = Order.garage;
};
resize({ frontSize: 50, rearSize: 50 });
ticks(1.5);
resize({ wheels: 4, frontSize: 200, rearSize: 200, chassisWidth: 140, chassisLength: 140, springSize: 160 });
let wildest = 0;
ticks(2, () => { wildest = Math.max(wildest, Math.hypot(rb.angularVelocityX[e]!, rb.angularVelocityY[e]!, rb.angularVelocityZ[e]!)); });
const big = rate({ ...STARTER, wheels: 4, frontSize: 200, rearSize: 200, chassisWidth: 140, chassisLength: 140, springSize: 160 }, rating);
check('resized on the line, it sets down calmly on its new wheels', wildest < 5 && grounded() === 4 && Math.abs(kart.mass[e]! - big.mass) < 0.5,
  `fastest turn ${wildest.toFixed(1)} rad/s, ${grounded()} down, ${kart.mass[e]!.toFixed(0)} kg of ${big.mass.toFixed(0)}`);

// Worn right through mid-run: it does not wreck -- parts shake loose and fall off, a moment apart, and it drives on.
resize({});
build.order[e] = Order.race;
ticks(4);
kart.damage[e] = kart.hp[e]! * 1.05;
ticks(1.5, sim.autopilot);
let limping = 0;
for (let i = 0; i < wheels.count; i++) if (wheel.attached[wheels.members[i]!]) limping++;
const worn = `wrecked ${kart.wrecked[e]}, phase ${kart.phase[e]}, ${kart.shed[e]} parts shed, ${limping} wheels on`;
const wornOk = !kart.wrecked[e] && kart.phase[e] === Phase.racing && kart.shed[e] === 2 && limping >= 2 && limping < 4;
// One massive hit (`Kart.smash`): wrecked -- every wheel off, the driver thrown, in bits -- a moment later the results
// (the run over, wrecked), and R puts it whole again on the line, the bits swept away.
build.order[e] = Order.restart;
ticks(4);
kart.smash[e] = 1;
ticks(0.3);
const debris = world.query({ with: [Debris], without: [Pusher] });
let on = 0;
for (let i = 0; i < wheels.count; i++) if (wheel.attached[wheels.members[i]!]) on++;
const bits = debris.count;
const wreck = `wrecked ${kart.wrecked[e]}, ${on} wheels on, driver out ${kart.ejected[e]}, ${bits} bits`;
ticks(3.5);
const wreckOver = kart.phase[e] === Phase.over && kart.out[e] === RunOut.wrecked;
build.order[e] = Order.restart;
ticks(0.5);
on = 0;
for (let i = 0; i < wheels.count; i++) if (wheel.attached[wheels.members[i]!]) on++;
// Stopped mid-run for more than six seconds: the run is over, and says why; R starts it again.
build.order[e] = Order.race;
ticks(4);
let held = 0;
ticks(OUT_FOR + 1, () => {
  rb.velocityX[e] = rb.velocityY[e] = rb.velocityZ[e] = 0;
  if (kart.phase[e] === Phase.racing) held += 1 / 60;
});
const overNow = kart.phase[e] === Phase.over && kart.out[e] === RunOut.stopped;
build.order[e] = Order.restart;
ticks(0.2);
// (Held from a second after the start: it was already crawling, under walking pace, for some of that.)
check('stopped six seconds, the run is over', overNow && held > OUT_FOR - 1.5 && held < OUT_FOR + 0.5 && kart.phase[e] === Phase.countdown,
  `over ${overNow} after ${held.toFixed(1)} s held still, then phase ${kart.phase[e]}`);
check('worn through it sheds parts one by one and drives on', wornOk, worn);
check('one massive hit and it falls to bits, the run over, then R starts it again whole', bits > 10 && wreckOver && kart.wrecked[e] === 0 && on === 4 && kart.damage[e] === 0 && debris.count === 0,
  `${wreck}; over ${wreckOver}; then wrecked ${kart.wrecked[e]}, ${on} wheels on, ${debris.count} bits left`);
t.done();
