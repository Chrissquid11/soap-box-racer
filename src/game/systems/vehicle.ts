/**
 * vehicle, 60 Hz: how a kart drives. It is one rigid body, held up by four raycast wheels: each wheel
 * looks down from its corner, and where it finds the road its spring and damper push the chassis up
 * there, and its tyre pushes sideways and along against the slide -- up to its grip times the load on
 * it (a wheel with no load grips nothing). The brakes take from that grip too: more than it has, and
 * the wheels lock and skid. Air drag, the driver's push off and tuck, their lean (by themselves, into the turn: the weight
 * moved), and the kart's true centre of mass -- higher than its box's middle, the driver and the
 * bodywork up top -- which rolls it in corners as much as it should.
 *
 * Here too: a landing that bottoms a spring out too hard snaps the wheel off, and one harder still
 * throws the driver out; time in the air is style. In the garage and the countdown the wheels hold it
 * where it stands.
 */
import { BoxCollider, type Entity, Hidden, Hierarchy, NONE, optional, physicsOf, RayHit, Render, RigidBody, Transform, Forces, WorldTransform, impulseAt, type World } from '@vibe/engine';
import { DOWNHILL, Surface, surfaceAt, TRACKS, TYRE_GRIP } from '../courses.ts';
import { Cause, Corner, Kart, Kicker, News, PartName, PartState, Phase, Wheel } from '../components.ts';
import { callOut, DAMAGE, springOf, struck, travelShare } from '../damage.ts';
import { rotate, unrotate, v3 } from '../kart-math.ts';
import { gust, weatherOf } from '../weather.ts';
import { sparks } from '../sparks.ts';
import { dropWheel } from '../shed.ts';

const G = 9.81;
/** Where a wheel's ray starts, above its mount, so it never begins inside the road. */
const RAY_LIFT = 0.1;
/** A tyre bashed into a wall (`damage.ts`): the wheel has no collider of its own -- the box does the colliding -- so
 * each looks out for one: from its hub this far past its side (the tyre's outer face), and its radius and this far
 * ahead of a front one or behind a rear. What it finds must stand up (its normal this flat at most) to be a wall.
 * Slower than BASH_LOOK, no look. */
const BASH_SIDE = 0.12;
const BASH_AHEAD = 0.06;
const BASH_FLAT = 0.5;
const BASH_LOOK = 2;
/** Sparks: a lost wheel's bare axle throws them faster than this (m/s); a landing this hard past the soak, from under the chassis. */
const SPARKS_FROM = 2;
const SPARKS_LANDING = 0.5;
/** Air: ½ ρ, newtons per m² of drag area per (m/s)². */
const AIR = 0.6;
/** A tyre's friction: its wheel's grip times this (courses.ts' TYRE_GRIP, which the medals assume too). */
const TYRE = TYRE_GRIP;
/** How much of a corner's slide a tyre takes out in a tick, at most (the rest is next tick's). */
const BITE = 0.6;
/** m/s of a wheel pressed into the road while it rolls on it (a dip, the foot of a steep slope: never off the ground)
 * forgiven before it harms anything, on top of what the springs soak: steep hills are driven, not crashed. */
const ROLLING_ALLOWANCE = 4.5;
/** Seconds on the road before a wheel is rolling: a landing bottoms its spring out well within this. */
const ROLLING_AFTER = 0.3;
/** Every steering part quicker than its own rate by this much, and losing its lock with speed this much later: more
 * reactive all round, each part still as it compares with the others. */
const STEER_QUICK = 1.6;
const STEER_HOLD = 1.3;
/** The gravel trap: its grip a share of the road's, and its rolling drag this many times the road's (deep loose stones:
 * thin tyres dig in). The foam section's soapy road: this share of the grip. */
const GRAVEL_GRIP = 0.8;
const GRAVEL_DRAG = 9;
const SOAP_GRIP = 0.3;
/** A locked wheel slides with this share of its grip, and holds sideways with this share. */
const SKID_GRIP = 0.75;
const SKID_SIDE = 0.3;
/** The driver's push off: newtons, up to this speed. */
const PUSH = 420;
const PUSH_TOP = 4.5;
/** Pushing uphill: a nose up more than this (the sine of its slope: about 1.5 degrees) is uphill; there the push lasts
 * UPHILL_FOR seconds on the gentlest rise, less the steeper, and none at all from UPHILL_STEEP (about 7 degrees) up. */
const UPHILL_FROM = 0.025;
const UPHILL_FOR = 2;
const UPHILL_STEEP = 0.12;
/** Moving faster than this (m/s), uphill is the way it goes; slower, the way its nose points. */
const UPHILL_MOVING = 0.5;

/** The road's rise (its slope's sine, + up) at `progress` along course `course`, going the way (dx, dz) along it; off
 * the course (no progress), `otherwise`. */
function roadRise(course: number, progress: number, dx: number, dz: number, otherwise: number): number {
  const t = TRACKS[Math.min(course, TRACKS.length - 1)];
  if (!t || progress < 0) return otherwise;
  const i = Math.max(0, Math.min(t.samples - 2, Math.floor(progress)));
  const ax = t.sx[i + 1]! - t.sx[i]!, az = t.sz[i + 1]! - t.sz[i]!, ay = t.sy[i + 1]! - t.sy[i]!;
  const len = Math.hypot(ax, ay, az);
  if (len < 1e-6) return otherwise;
  return (ax * dx + az * dz >= 0 ? ay : -ay) / len;
}
/** The anti-roll bar: kilogram-metres squared a kilogram, a second. */
const ANTI_ROLL = 1.1;
/** Metres between its Transform and its world transform that mean it was set down somewhere new this tick. */
const MOVED = 2;
/** A ramp's grace, seconds, from the moment the last wheel leaves one and the kart is back on the road. */
const GRACE = 1;
/** In the air off a ramp: how fast it turns itself level (radians a second for each radian off), and how quickly it takes to it. */
const LEVEL = 3;
const LEVEL_EASE = 6;
/** On a ramp: how fast a roll about its nose is damped out (a share a second). */
const RAMP_STEADY = 10;
/** How hard a kart with nobody aboard drags its brakes. */
const EMPTY_BRAKE = 0.7;
/** m/s of landing past what the springs soak up that does no wear. */
const LANDING_FELT = 2;
/** The acceleration the true centre of mass feels: at most this (m/s²), eased toward the measured one this fast (per second). */
const ACCEL_MAX = 15;
const ACCEL_EASE = 12;
/** Under this speed (m/s), A/D drag the kart round on the spot, this many radians a second. */
const DRAG_ROUND = 1.5;
const DRAG_TURN = 1.4;
/** The most of its weight wings may hold up. */
const WING_MOST = 0.85;
/** Tucked in, the drag is this share. */
const TUCK = 0.78;
/** Metres the driver's lean moves the kart's weight sideways. */
const LEAN = 0.16;
/** The driver's own lean: all of it into a full-lock turn from this speed (m/s); stuck on its side this long
 * (`Kart.stuck`, seconds), rocking from side to side this many times a second to right it. */
const AUTO_LEAN_SPEED = 9;
/** Twin brake levers: the turn a lever pulled all the way swings the kart toward, rad/s; the speed it does so fully
 * from (slower, less: it pivots, it does not spin on the spot); and how quickly it gets there, a second. */
const LEVER_TURN = 1.7;
const LEVER_FULL_AT = 4;
const LEVER_SWING = 5;
const ROCK_AFTER = 0.4;
const ROCK_HZ = 1.2;
/** In the air at least this long (seconds), it counts as a jump -- big air; and the style it scores for every second it
 * was up (so the longer the flight, the more). */
const JUMP = 1;
const STYLE_PER_SECOND = 160;
/** Each jump after the first scores less: deliberate repeats are worth less than variety. */
const REPEAT = 0.7;
/** A thin rim (`Kart.thin`) whose landing damages it may buckle right over: from this hard past what the springs
 * soak (m/s), this likely (more the harder), drawn bent this far. (Its damage is `damage.ts`' as any other's.) */
const BUCKLE_FROM = 2.5;
const BUCKLE_CHANCE = 0.35;
const BUCKLED = 0.9;

/** 0..1 from the moment and the wheel's corner: the same for the same pair (never the loop's chance, for a replay's sake). */
function buckleChance(time: number, corner: number): number {
  const s = Math.sin(time * 91.7 + corner * 13.1) * 43758.5453;
  return s - Math.floor(s);
}

/** A wheel also looks down this share of its radius ahead of its hub and behind it (only to be drawn clear of the road). */
const PROBE = 0.7;
/** How far up a circle's edge is there, a share of its radius: 1 - √(1 - PROBE²). */
const PROBE_SAG = 1 - Math.sqrt(1 - PROBE * PROBE);
/** The most a drawn wheel rides up past its spring's stop, a share of its radius. */
const OVER_STOP = 0.9;

const hit = new RayHit();
const probe = new RayHit();
const rampHit = new RayHit();
const wallHit = new RayHit();
/**
 * Ramps and jumps: the kart's box passes through them (their physics layer, `Ramps`), so only the wheels ride them.
 * Each wheel looks for one from this far up over its mount, metres -- a ramp's face rises past the low ray's start
 * faster than the springs lift the kart -- and is pushed up out of one it has sunk into this fast, per metre sunk
 * (m/s, at most RAMP_LIFT_MAX).
 */
const RAMP_LOOK = 1.2;
const RAMP_LIFT = 12;
const RAMP_LIFT_MAX = 5;
const up = v3();
const fwd = v3();
const left = v3();
const mount = v3();
const com = v3();
const spin = v3();
const inertia = v3();
const arm = v3();
/** The kart being worked on: its turn and mass, for share(). */
const body = { qx: 0, qy: 0, qz: 0, qw: 1, m: 1 };

/**
 * How much of the kart one wheel's push in direction d at r (from the body's middle, world axes) moves: the
 * effective mass there -- its share of the kart's weight (a quarter: four wheels push at once) and of its turning,
 * by the box's inertia. A thin plank turns easily about its length, so a push at its wheels moves less mass than a
 * quarter of the kart: sized by this, no push overshoots.
 */
function share(rx: number, ry: number, rz: number, dx: number, dy: number, dz: number): number {
  unrotate(body.qx, body.qy, body.qz, body.qw, ry * dz - rz * dy, rz * dx - rx * dz, rx * dy - ry * dx, arm);
  const turn = (arm.x * arm.x) / inertia.x + (arm.y * arm.y) / inertia.y + (arm.z * arm.z) / inertia.z;
  return 1 / (4 / body.m + turn);
}

export function vehicle(world: World): void {
  const physics = physicsOf(world);
  const ground = physics.layers('Default', 'Ramps');
  const ramps = physics.layers('Ramps');
  world.system({
    name: 'vehicle',
    rate: 60,
    after: ['race'],
    read: [Transform, WorldTransform, Hierarchy, BoxCollider, optional(Render)],
    write: [Kart, RigidBody, Forces, optional(Wheel)],
    update({ members, count, dt, input, time, cmd, has }, [at, wt, tree, box, look], [kart, rb, forces, wheel]) {
      for (let n = 0; n < count; n++) {
        const e = members[n];
        const qx = at.qx[e], qy = at.qy[e], qz = at.qz[e], qw = at.qw[e];
        rotate(qx, qy, qz, qw, 0, 1, 0, up);
        rotate(qx, qy, qz, qw, 0, 0, 1, fwd);
        rotate(qx, qy, qz, qw, 1, 0, 0, left);
        kart.upY[e] = up.y;
        const px = at.px[e], py = at.py[e], pz = at.pz[e];
        // Set somewhere new this tick (the line, a restart): its world transform is still where it was, and every
        // push at a wheel would turn it about that -- hundreds of metres off, a spin it cannot survive. One tick
        // without them; the race has just stilled it anyway.
        const moved = Math.abs(wt.px[e] - px) + Math.abs(wt.py[e] - py) + Math.abs(wt.pz[e] - pz);
        if (moved > MOVED) continue;
        const vx = rb.velocityX[e], vy = rb.velocityY[e], vz = rb.velocityZ[e];
        const wx = rb.angularVelocityX[e], wy = rb.angularVelocityY[e], wz = rb.angularVelocityZ[e];
        // What this system turns it by is gathered from nothing, so its true inertia can be applied to it at the end.
        const turnedX = forces.angularImpulseX[e], turnedY = forces.angularImpulseY[e], turnedZ = forces.angularImpulseZ[e];
        const speed = Math.sqrt(vx * vx + vy * vy + vz * vz);
        kart.speed[e] = speed;
        const m = kart.mass[e];
        // The box's own inertia, as the physics has it (a solid box of the kart's whole mass), about its own axes:
        // what every push at a wheel is sized by (share()), so none overshoots and sets it spinning.
        const sx2 = box.sizeX[e] * box.sizeX[e], sy2 = box.sizeY[e] * box.sizeY[e], sz2 = box.sizeZ[e] * box.sizeZ[e];
        inertia.x = (m * (sy2 + sz2)) / 12;
        inertia.y = (m * (sx2 + sz2)) / 12;
        inertia.z = (m * (sx2 + sy2)) / 12;
        body.qx = qx;
        body.qy = qy;
        body.qz = qz;
        body.qw = qw;
        body.m = m;
        const phase = kart.phase[e];
        const parked = phase === Phase.garage || phase === Phase.countdown;
        // The weather (`weather.ts`): its grip and rolling drag at every tyre, its crosswind below.
        const sky = weatherOf(kart.weather[e]);
        // The road under it (`courses.ts`' surfaces): a gravel trap drags and grips a little less; the foam section's soapy
        // road hardly grips at all.
        const surface = surfaceAt(kart.course[e], kart.progress[e]);
        const groundGrip = surface === Surface.gravel ? GRAVEL_GRIP : surface === Surface.soap ? SOAP_GRIP : 1;
        const groundDrag = surface === Surface.gravel ? GRAVEL_DRAG : 1;
        const driving = phase === Phase.racing && !kart.ejected[e];

        // What the driver asks: steer (+ left), brake, push / tuck, lean (+ left).
        let steerIn = 0;
        let brakeIn = 0;
        let pushing = false;
        let leanIn = 0;
        if (driving) {
          if (input.down('KeyA') || input.down('ArrowLeft')) steerIn += 1;
          if (input.down('KeyD') || input.down('ArrowRight')) steerIn -= 1;
          const stick = input.axis(0);
          if (Math.abs(stick) > 0.15) steerIn = -stick;
          if (input.down('KeyS') || input.down('ArrowDown') || input.down('Space') || input.down('Pad7')) brakeIn = 1;
          pushing = input.down('KeyW') || input.down('ArrowUp') || input.down('Pad0');
        } else if (phase === Phase.finished) {
          brakeIn = 0.6;
        } else if (phase === Phase.racing && kart.ejected[e]) {
          // Nobody aboard: it drags to a stop rather than run off down the hill, so its driver can catch it up.
          brakeIn = EMPTY_BRAKE;
        }
        // Less lock the faster it goes: half of it at the steering's fade speed (reins go numb early, a go-kart wheel stays sharp).
        // Twin brake levers: `steer` is how far a lever is pulled (+ the left one), never faded with speed.
        const levers = kart.levers[e];
        const lock = levers > 0 ? kart.lock[e] : kart.lock[e] / (1 + speed / Math.max(1, kart.steerFade[e] * STEER_HOLD));
        const steerTo = steerIn * lock;
        const step = kart.steerRate[e] * STEER_QUICK * dt;
        kart.steer[e] += Math.max(-step, Math.min(step, steerTo - kart.steer[e]));
        // The driver leans by themselves: into the turn the kart is steered into, the more the faster it goes (its
        // weight thrown to the inside keeps it on its wheels); stuck on its side, rocking side to side to right it.
        if (driving) {
          if (kart.stuck[e] > ROCK_AFTER) leanIn = Math.sin(kart.clock[e] * ROCK_HZ * 2 * Math.PI) >= 0 ? 1 : -1;
          else leanIn = Math.max(-1, Math.min(1, (kart.steer[e] / Math.max(0.01, lock)) * Math.min(1, speed / AUTO_LEAN_SPEED)));
        }
        kart.lean[e] += (leanIn - kart.lean[e]) * Math.min(1, dt * 6);

        const dragging = driving && speed < DRAG_ROUND && steerIn !== 0;

        // The wheels.
        let grounded = 0;
        let onKicker = false;
        const travel = kart.travel[e];
        for (let c = tree.firstChild[e]; c !== 0; c = tree.nextSibling[c]) {
          if (!has(c, Wheel)) continue;
          if (!wheel.attached[c]) {
            wheel.grounded[c] = 0;
            // Failed and gone (`damage.ts`): the bare axle stub holds its corner up, low -- the kart sits down on that
            // corner -- with no grip, scraping along the road: slower, and dragged toward that corner. Still drivable.
            if (phase !== Phase.garage) {
              const dk = wheel.corner[c];
              const dLeft = dk === Corner.fl || dk === Corner.rl, dFront = dk === Corner.fl || dk === Corner.fr;
              rotate(qx, qy, qz, qw, (dLeft ? 1 : -1) * kart.halfTrack[e], -kart.halfHeight[e], (dFront ? 1 : -1) * kart.halfBase[e], mount);
              const sr = (wheel.radius[c] > 0.01 ? wheel.radius[c] : kart.radius[e]) * DAMAGE.stubLift;
              const sreach = RAY_LIFT + travel + sr;
              if (physics.raycast(px + mount.x + up.x * RAY_LIFT, py + mount.y + up.y * RAY_LIFT, pz + mount.z + up.z * RAY_LIFT, -up.x, -up.y, -up.z, sreach, ground, hit)) {
                const sx_ = sreach - hit.distance;
                const sclose = -((vx + (wy * mount.z - wz * mount.y)) * up.x + (vy + (wz * mount.x - wx * mount.z)) * up.y + (vz + (wx * mount.y - wy * mount.x)) * up.z);
                const sload = Math.max(0, kart.spring[e] * Math.min(sx_, travel) + kart.damper[e] * sclose);
                impulseAt(forces, wt, e, up.x * sload * dt, up.y * sload * dt, up.z * sload * dt, hit.x, hit.y, hit.z);
                if (speed > 0.5) {
                  const j = (sload * DAMAGE.stubScrape * dt) / speed;
                  impulseAt(forces, wt, e, -vx * j, -vy * j, -vz * j, hit.x, hit.y, hit.z);
                }
                // The bare axle on the road: a shower of sparks behind it.
                const frame = Math.round(time * 60);
                if (speed > SPARKS_FROM && (frame + dk) % 2 === 0) sparks(cmd, hit.x, hit.y, hit.z, -vx * 0.35, 0, -vz * 0.35, 2 + Math.min(3, Math.floor(speed / 6)), 1, frame * 4 + dk);
              }
            }
            continue;
          }
          // Its own radius: the front and rear wheels may be built different sizes.
          const radius = wheel.radius[c] > 0.01 ? wheel.radius[c] : kart.radius[e];
          const reach = RAY_LIFT + travel + radius;
          const k = wheel.corner[c];
          const isLeft = k === Corner.fl || k === Corner.rl;
          const front = k === Corner.fl || k === Corner.fr;
          rotate(qx, qy, qz, qw, (isLeft ? 1 : -1) * kart.halfTrack[e], -kart.halfHeight[e], (front ? 1 : -1) * kart.halfBase[e], mount);
          const ox = px + mount.x + up.x * RAY_LIFT;
          const oy = py + mount.y + up.y * RAY_LIFT;
          const oz = pz + mount.z + up.z * RAY_LIFT;
          // Straight as it is steered: only a damaged wheel (below) or a lost one (its stub's drag) takes it off line.
          let angle = front && levers === 0 ? kart.steer[e] : 0;
          // Damaged (`damage.ts`): a front wheel toed out toward its side -- the kart pulls that way, a little -- a rear
          // one shimmying as it turns. Fixed amounts for the state, never stacked.
          const damaged = wheel.state[c] === PartState.damaged;
          if (damaged) {
            if (front) angle += (isLeft ? 1 : -1) * DAMAGE.frontToe;
            else angle += Math.sin(wheel.spin[c]) * DAMAGE.rearWobble;
          }
          const wheelGrip = damaged ? (front ? DAMAGE.frontGrip : DAMAGE.rearGrip) : 1;
          const wheelDrag = damaged && front ? 1 + DAMAGE.frontDrag : 1;
          const sprung = springOf(wheel.spring[c]);
          wheel.angle[c] = angle;
          // Bashed into a wall: the speed its hub goes into it (along the wall's normal) as any knock -- bent, or off.
          let walled = false;
          if (!parked && phase === Phase.racing && kart.grace[e] <= 0 && speed > BASH_LOOK) {
            // From its hub, where its spring has it (as `wheelLook` draws it): never down in the road on a landing.
            const drop = travel - Math.min(travel, wheel.compression[c]);
            const hx = px + mount.x - up.x * drop, hy = py + mount.y - up.y * drop, hz = pz + mount.z - up.z * drop;
            const side = isLeft ? 1 : -1, ahead = front ? 1 : -1;
            let wall = physics.raycast(hx, hy, hz, left.x * side, left.y * side, left.z * side, BASH_SIDE, ground, wallHit) && Math.abs(wallHit.normalY) < BASH_FLAT;
            if (!wall) wall = physics.raycast(hx, hy, hz, fwd.x * ahead, fwd.y * ahead, fwd.z * ahead, radius + BASH_AHEAD, ground, wallHit) && Math.abs(wallHit.normalY) < BASH_FLAT;
            // A wall: the course itself, standing -- not a ramp, nor a prop that gives (a bale, a cone, a tyre stack: a knock of their own).
            walled = wall && !(wallHit.entity !== 0 && (has(wallHit.entity as Entity, Kicker) || has(wallHit.entity as Entity, RigidBody)));
            // Only as it meets the wall: rubbing along it after is a scrape, which the box's own knocks judge.
            if (walled && !wheel.walled[c]) {
              const hmx = hx - px, hmy = hy - py, hmz = hz - pz;
              const bx = vx + (wy * hmz - wz * hmy), by = vy + (wz * hmx - wx * hmz), bz = vz + (wx * hmy - wy * hmx);
              const into = -(bx * wallHit.normalX + by * wallHit.normalY + bz * wallHit.normalZ);
              // The rim on the wall: sparks off it, the harder the more.
              if (into > DAMAGE.light * 0.6) sparks(cmd, wallHit.x, wallHit.y, wallHit.z, vx * 0.3, 0, vz * 0.3, Math.min(14, 4 + Math.round(into * 1.5)), 1.4, Math.round(time * 60) * 4 + k, hy - radius);
              const was = wheel.state[c];
              const now = struck(was, wheel.stateAt[c], kart.clock[e], into, DAMAGE.light, kart.strength[e] * DAMAGE.wheelSevere);
              if (now !== was) {
                wheel.state[c] = now;
                wheel.stateAt[c] = kart.clock[e];
                kart.hurts[e]++;
                if (kart.onCut[e]) kart.cutHurt[e] |= 1 << wheel.corner[c]!;
                callOut(kart, e, PartName.wheelFL + k, now);
                if (now === PartState.damaged) {
                  wheel.bent[c] = Math.max(wheel.bent[c], front ? DAMAGE.frontBentLook : DAMAGE.rearBentLook);
                  kart.news[e] = News.bent;
                  kart.newsAt[e] = kart.clock[e];
                } else {
                  // Off it comes, bouncing back off the wall.
                  wheel.attached[c] = 0;
                  wheel.grounded[c] = 0;
                  kart.wheelsLost[e]++;
                  kart.cause[e] = Cause.wheelKnock;
                  kart.causeSpeed[e] = into;
                  kart.news[e] = News.lostWheel;
                  kart.newsAt[e] = kart.clock[e];
                  if (!has(c, Hidden)) cmd.add(c, Hidden);
                  const loose = dropWheel(cmd, at, look, wheel, e, c);
                  if (loose !== NONE) {
                    const lrb = cmd.init(loose, RigidBody);
                    lrb.startVelocityX[loose] = vx * 0.6 + wallHit.normalX * 3;
                    lrb.startVelocityY[loose] = 4;
                    lrb.startVelocityZ[loose] = vz * 0.6 + wallHit.normalZ * 3;
                    lrb.startSpinX[loose] = 1100;
                    lrb.startSpinY[loose] = 450;
                  }
                  continue;
                }
              }
            }
          }
          wheel.walled[c] = walled ? 1 : 0;
          let found = physics.raycast(ox, oy, oz, -up.x, -up.y, -up.z, reach, ground, hit);
          // A ramp risen above the ray's start (it found the road under it, or nothing): looked for from higher up.
          if (physics.raycast(ox + up.x * RAMP_LOOK, oy + up.y * RAMP_LOOK, oz + up.z * RAMP_LOOK, -up.x, -up.y, -up.z, RAMP_LOOK + reach, ramps, rampHit)
            && (!found || rampHit.distance - RAMP_LOOK < hit.distance)) {
            found = true;
            hit.entity = rampHit.entity;
            hit.x = rampHit.x; hit.y = rampHit.y; hit.z = rampHit.z;
            hit.normalX = rampHit.normalX; hit.normalY = rampHit.normalY; hit.normalZ = rampHit.normalZ;
            hit.distance = rampHit.distance - RAMP_LOOK;   // below nought: sunk into it
          }
          if (!found) {
            wheel.grounded[c] = 0;
            wheel.onRoad[c] = 0;
            wheel.slip[c] = 0;
            wheel.locked[c] = 0;
            wheel.compression[c] += (0 - wheel.compression[c]) * Math.min(1, dt * 10);
            wheel.spin[c] += (fwd.x * vx + fwd.y * vy + fwd.z * vz) / radius * dt * 0.98;
            continue;
          }
          grounded++;
          // On the road a while: rolling, not landing -- a dip or the foot of a steep slope pressing it down, which is
          // forgiven its share (`ROLLING_ALLOWANCE`) as a real landing from the air (bottoming out just after) is not.
          wheel.onRoad[c] += dt;
          const rolling = wheel.onRoad[c] > ROLLING_AFTER;
          wheel.grounded[c] = 1;
          // On a ramp or a jump: its grace (below), and none of a landing's harm on it.
          const kicker = hit.entity !== 0 && has(hit.entity as Entity, Kicker);
          if (kicker) onKicker = true;
          const forgiving = parked || kicker || kart.grace[e] > 0;
          // Riding a ramp's face (or parked): no harm at all. Landing off one: its parts judged as any landing, past an
          // allowance (`DAMAGE.jumpAllowance`) -- so a clean jump is free, an overshoot hurts as the build is made.
          const spared = parked || kicker;
          const allowance = kart.grace[e] > 0 ? DAMAGE.jumpAllowance : rolling ? ROLLING_ALLOWANCE : 0;
          const x = reach - hit.distance;
          // How fast this corner comes down onto the road: its own velocity (the body's, and its turn) into the
          // ground. Not the change in the spring's length, which a wheel rolling onto a kerb or a ramp's edge would
          // read as a crash landing.
          const mx = mount.x, my = mount.y, mz = mount.z;
          const pvx = vx + (wy * mz - wz * my), pvy = vy + (wz * mx - wx * mz), pvz = vz + (wx * my - wy * mx);
          let closing = -(pvx * up.x + pvy * up.y + pvz * up.z);
          // On a ramp its face comes at the wheel as the kart runs on: into its slope (along its normal) counts too.
          if (kicker) closing = Math.max(closing, -(pvx * hit.normalX + pvy * hit.normalY + pvz * hit.normalZ));
          // Where the wheel is drawn (`wheelLook`): high enough that none of its tyre is in the road. Bottomed out,
          // the road may be higher than the spring lets the hub go, and a rising road ahead of it or behind it
          // (a ramp's lip, a steepening hill) touches the tyre before the road under its hub does -- so the drawn
          // wheel rides up past its stop into its arch, rather than sink into the ground.
          let drawn = x;
          for (let p = -1; p <= 1; p += 2) {
            const d = p * radius * PROBE;
            if (!physics.raycast(ox + fwd.x * d, oy + fwd.y * d, oz + fwd.z * d, -up.x, -up.y, -up.z, reach, ground, probe)) continue;
            const need = reach - probe.distance - radius * PROBE_SAG;
            if (need > drawn) drawn = need;
          }
          wheel.compression[c] = Math.min(drawn, travel + radius * OVER_STOP);

          // The spring and the damper: never pulling down.
          // The damper never takes out more than the closing speed there is in one tick.
          const upShare = share(mx, my, mz, up.x, up.y, up.z);
          // Its suspension as damaged as it is: a weaker spring (the corner sags), a weaker damper (it settles slowly, bounces).
          const damper = kart.damper[e] * sprung.damper;
          const damping = closing > 0 ? Math.min(damper * closing, (upShare * closing) / dt) : Math.max(damper * closing, (upShare * closing) / dt);
          let load = kart.spring[e] * sprung.spring * Math.min(x, travel) + damping;
          if (load < 0) load = 0;
          // Bottomed out: the stop takes what closing speed is left in one go -- and may break something.
          // Sunk into a ramp past its stop: pushed back up out of it.
          if (kicker && x > travel) load += (upShare * Math.min(RAMP_LIFT_MAX, (x - travel) * RAMP_LIFT)) / dt;
          if (x >= travel && closing > 0) {
            load += (upShare * closing) / dt;
            // A landing harder than the springs soak up wears the chassis too (four tenths of it a corner) -- but never
            // on or off a ramp, which forgives it (and never parked).
            if (!forgiving && closing > kart.soak[e] + LANDING_FELT + allowance) kart.damage[e] += (closing - kart.soak[e] - LANDING_FELT - allowance) * 0.4;
            // And damages the corner that took it (`damage.ts`): its suspension -- or, with none (bolted on), or that
            // already failed, its wheel. A severe landing fails it at once; one landing over several ticks is one hit.
            const hard = closing - kart.soak[e] - allowance;
            // Bottomed out hard: the chassis' underside on the road, sparks out from under it.
            if (!spared && hard > SPARKS_LANDING) sparks(cmd, hit.x, hit.y, hit.z, vx * 0.4, 0, vz * 0.4, Math.min(12, 3 + Math.round(hard * 2)), 1.5, Math.round(time * 60) * 4 + k + 1);
            let wheelFails = false;
            // One massive landing -- a fall from a great height, a jump overshot by miles -- and it is in bits (`wear`).
            if (!spared && hard >= DAMAGE.wreckLanding) kart.smash[e] = 1;
            if (!spared) {
              const severe = kart.strength[e] * DAMAGE.landingSevere;
              // Its suspension takes it -- and its wheel a share of it too, the more the shorter the travel (`DAMAGE`'s
              // shortTravel..fullTravel): short springs bottom out and pass the blow on. Bolted on, or the spring gone,
              // the wheel takes it all.
              const springHolds = kart.sprung[e] === 1 && wheel.spring[c] !== PartState.failed;
              if (springHolds) {
                const was = wheel.spring[c];
                const now = struck(was, wheel.springAt[c], kart.clock[e], hard, DAMAGE.landingLight, severe);
                if (now !== was) {
                  wheel.spring[c] = now;
                  wheel.springAt[c] = kart.clock[e];
                  kart.hurts[e]++;
                  callOut(kart, e, PartName.springFL + k, now);
                }
              }
              const passed = springHolds ? hard * travelShare(kart.travel[e]) : hard;
              if (passed >= DAMAGE.landingLight) {
                const was = wheel.state[c];
                const now = struck(was, wheel.stateAt[c], kart.clock[e], passed, DAMAGE.landingLight, severe);
                if (now !== was) {
                  wheel.state[c] = now;
                  wheel.stateAt[c] = kart.clock[e];
                  kart.hurts[e]++;
                  if (kart.onCut[e]) kart.cutHurt[e] |= 1 << wheel.corner[c]!;
                  callOut(kart, e, PartName.wheelFL + k, now);
                  if (now === PartState.failed) wheelFails = true;
                  else {
                    wheel.bent[c] = Math.max(wheel.bent[c], front ? DAMAGE.frontBentLook : DAMAGE.rearBentLook);
                    // A thin rim: now and then it buckles right over -- a taco of a wheel that still, just, goes round.
                    if (kart.thin[e] && passed > BUCKLE_FROM && buckleChance(time, k) < BUCKLE_CHANCE + (passed - BUCKLE_FROM) * 0.1) wheel.bent[c] = BUCKLED;
                    kart.news[e] = News.bent;
                    kart.newsAt[e] = kart.clock[e];
                  }
                }
              }
            }
            if (wheelFails) {
              wheel.attached[c] = 0;
              kart.wheelsLost[e]++;
              kart.cause[e] = Cause.wheelLanding;
              kart.causeSpeed[e] = closing;
              kart.news[e] = News.lostWheel;
              kart.newsAt[e] = kart.clock[e];
              if (!has(c, Hidden)) cmd.add(c, Hidden);
              const loose = dropWheel(cmd, at, look, wheel, e, c);
              if (loose !== NONE) {
                const lrb = cmd.init(loose, RigidBody);
                lrb.startVelocityX[loose] = vx + left.x * (isLeft ? 2 : -2);
                lrb.startVelocityY[loose] = Math.max(vy, 0) + 4.5;   // boing
                lrb.startSpinX[loose] = 1100;
                lrb.startSpinY[loose] = 450;
                lrb.startVelocityZ[loose] = vz + left.z * (isLeft ? 2 : -2);
              }
              continue;
            }
            // Thrown out of the seat by a landing too hard for it -- never off a ramp, which forgives that (and the wear).
            if (!forgiving && !kart.ejected[e] && kart.thrown[e] === Cause.none && closing > kart.seatGrip[e] + kart.soak[e]) {
              kart.thrown[e] = Cause.thrownLanding;
              kart.causeSpeed[e] = closing;
            }
          }
          const sx = up.x * load * dt, sy = up.y * load * dt, sz = up.z * load * dt;
          impulseAt(forces, wt, e, sx, sy, sz, hit.x, hit.y, hit.z);

          // The tyre: along the wheel, and across it, on the road's plane.
          const ca = Math.cos(angle), sa = Math.sin(angle);
          let fx = fwd.x * ca + left.x * sa, fy = fwd.y * ca + left.y * sa, fz = fwd.z * ca + left.z * sa;
          const nd = fx * hit.normalX + fy * hit.normalY + fz * hit.normalZ;
          fx -= hit.normalX * nd;
          fy -= hit.normalY * nd;
          fz -= hit.normalZ * nd;
          const fl = Math.sqrt(fx * fx + fy * fy + fz * fz) || 1;
          fx /= fl;
          fy /= fl;
          fz /= fl;
          // Across: the normal × along (to the wheel's left).
          const lx = hit.normalY * fz - hit.normalZ * fy;
          const ly = hit.normalZ * fx - hit.normalX * fz;
          const lz = hit.normalX * fy - hit.normalY * fx;
          // The road's speed under the tyre: the body's, and its turn about the centre.
          const rx = hit.x - px, ry = hit.y - py, rz = hit.z - pz;
          const cvx = vx + (wy * rz - wz * ry);
          const cvy = vy + (wz * rx - wx * rz);
          const cvz = vz + (wx * ry - wy * rx);
          const along = cvx * fx + cvy * fy + cvz * fz;
          const across = cvx * lx + cvy * ly + cvz * lz;
          wheel.spin[c] += (along / radius) * dt;

          // The friction circle, as an impulse: less on a damaged wheel, and on a bouncing corner whose suspension is damaged
          // (the more it bounces, the more -- rough ground costs, smooth hardly).
          const rough = 1 - Math.min(DAMAGE.roughMax, Math.abs(closing) * sprung.rough);
          const most = kart.grip[e] * wheelGrip * rough * sky.grip * groundGrip * TYRE * load * dt;
          const acrossShare = share(rx, ry, rz, lx, ly, lz);
          const alongShare = share(rx, ry, rz, fx, fy, fz);
          let jAcross = dragging ? 0 : -across * acrossShare * BITE;
          let jAlong = 0;
          let locked = false;
          if (parked) {
            // The handbrake: held where it stands, as firmly as the springs allow.
            jAlong = -along * alongShare * BITE;
          } else {
            const roll = Math.min(Math.abs(along) * alongShare, kart.rolling[e] * sky.rolling * groundDrag * wheelDrag * load * dt);
            jAlong = -Math.sign(along) * roll;
            // A brake lever pulled: this side's rear wheel braked, the kart swung round it.
            const pulled = levers > 0 && !front && driving ? Math.max(0, (isLeft ? 1 : -1) * kart.steer[e]) * levers : 0;
            if (brakeIn > 0 || pulled > 0) {
              const demand = (brakeIn * kart.brake[e] + pulled) * load * dt;
              if (demand > most && Math.abs(along) > 0.5) {
                locked = true;
                jAlong -= Math.sign(along) * Math.min(Math.abs(along) * alongShare, most * SKID_GRIP);
              } else {
                jAlong -= Math.sign(along) * Math.min(Math.abs(along) * alongShare, demand);
              }
            }
          }
          wheel.locked[c] = locked ? 1 : 0;
          // For `fx`: where it touches, and how fast it slides there -- across, or along when locked.
          wheel.hitX[c] = hit.x;
          wheel.hitY[c] = hit.y;
          wheel.hitZ[c] = hit.z;
          wheel.slip[c] = locked ? Math.max(Math.abs(across), Math.abs(along)) : Math.abs(across);
          if (locked) {
            jAcross *= SKID_SIDE;
            wheel.spin[c] -= (along / radius) * dt;
          }
          const total = Math.sqrt(jAcross * jAcross + jAlong * jAlong);
          const cap = parked ? most * 4 : most;
          if (total > cap && total > 0) {
            jAcross *= cap / total;
            jAlong *= cap / total;
          }
          impulseAt(forces, wt, e, fx * jAlong + lx * jAcross, fy * jAlong + ly * jAcross, fz * jAlong + lz * jAcross, hit.x, hit.y, hit.z);
        }

        // Twin brake levers: the braked rear wheel slides, and the kart pivots round it -- swung toward a turn rate of its
        // own (the tyres then drag its run back in line with its nose, which is where the speed goes).
        if (levers > 0 && driving && grounded >= 2 && kart.steer[e] !== 0) {
          const want = kart.steer[e] * LEVER_TURN * Math.min(1, speed / LEVER_FULL_AT);
          const now = rb.angularVelocityX[e] * up.x + rb.angularVelocityY[e] * up.y + rb.angularVelocityZ[e] * up.z;
          const add = (want - now) * Math.min(1, dt * LEVER_SWING);
          if (Math.sign(add) === Math.sign(kart.steer[e])) {
            rb.angularVelocityX[e] += up.x * add;
            rb.angularVelocityY[e] += up.y * add;
            rb.angularVelocityZ[e] += up.z * add;
          }
        }

        // A ramp's grace: full while a wheel rides one; held through the flight off it; running down once back on the
        // road, so the landing is forgiven too.
        if (onKicker) kart.grace[e] = GRACE;
        else if (grounded >= 2) kart.grace[e] = Math.max(0, kart.grace[e] - dt);
        // On a ramp, steadied: any roll about its nose damped out hard, so a lean never builds into a tip going up.
        if (onKicker && phase === Phase.racing) {
          const rollRate = rb.angularVelocityX[e] * fwd.x + rb.angularVelocityY[e] * fwd.y + rb.angularVelocityZ[e] * fwd.z;
          const cut = rollRate * Math.min(1, dt * RAMP_STEADY);
          rb.angularVelocityX[e] -= fwd.x * cut;
          rb.angularVelocityY[e] -= fwd.y * cut;
          rb.angularVelocityZ[e] -= fwd.z * cut;
        }
        // And in the air off one, it levels itself -- its lean and pitch eased out, its turn about its own up left be
        // -- so it comes down on its wheels.
        if (kart.grace[e] > 0 && grounded === 0 && phase === Phase.racing) {
          // The turn that would bring its up to the world's: up × (0, 1, 0).
          const ex = -up.z, ez = up.x;
          const yaw = rb.angularVelocityY[e];
          const ease = Math.min(1, dt * LEVEL_EASE);
          rb.angularVelocityX[e] += (ex * LEVEL - rb.angularVelocityX[e]) * ease;
          rb.angularVelocityZ[e] += (ez * LEVEL - rb.angularVelocityZ[e]) * ease;
          rb.angularVelocityY[e] = yaw;
        }
        // Parked (the garage, the grid): sat level side to side -- its lean about its nose eased out, its pitch left to
        // the slope -- so a tall kart on soft springs never sits wonky before it has even raced.
        if (parked && grounded > 0) {
          const ex = -up.z, ez = up.x;
          const want = (ex * fwd.x + ez * fwd.z) * LEVEL;
          const has = rb.angularVelocityX[e] * fwd.x + rb.angularVelocityY[e] * fwd.y + rb.angularVelocityZ[e] * fwd.z;
          const add = (want - has) * Math.min(1, dt * LEVEL_EASE);
          rb.angularVelocityX[e] += fwd.x * add;
          rb.angularVelocityY[e] += fwd.y * add;
          rb.angularVelocityZ[e] += fwd.z * add;
        }

        // The rocket: while W is held and there is fuel left, a push along the kart -- on the ground or not.
        const boosting = driving && pushing && kart.thrust[e] > 0 && kart.fuel[e] > 0;
        kart.boosting[e] = boosting ? 1 : 0;
        if (boosting) {
          kart.fuel[e] = Math.max(0, kart.fuel[e] - dt);
          forces.impulseX[e] += fwd.x * kart.thrust[e] * dt;
          forces.impulseY[e] += fwd.y * kart.thrust[e] * dt;
          forces.impulseZ[e] += fwd.z * kart.thrust[e] * dt;
        }
        // The wings: in the air, lift with the square of the speed across the ground, never more than nearly
        // all its weight -- a long glide off a jump, not a flight.
        if (kart.wing[e] > 0 && grounded === 0 && up.y > 0.3) {
          const flat = vx * vx + vz * vz;
          const lift = Math.min(AIR * kart.wing[e] * flat * up.y, m * G * WING_MOST);
          forces.impulseY[e] += lift * dt;
        }

        // The driver's feet: a push off the road, along the kart, while slow and on the ground -- however many wheels are left.
        // Uphill, only a moment: on a gentle rise a couple of seconds at most (UPHILL_FOR), less the steeper, and on
        // a steep one (UPHILL_STEEP) none at all -- this is a downhill race, and gravity wins.
        // (The road's own slope where it is, the way it is going along it -- not its nose, which sits up on three
        // wheels, nor its bounce, which a scraping axle throws up and down.)
        const rise = roadRise(kart.course[e], kart.progress[e], speed > UPHILL_MOVING ? vx : fwd.x, speed > UPHILL_MOVING ? vz : fwd.z, fwd.y);
        if (pushing && grounded > 0 && rise > UPHILL_FROM) kart.uphillFor[e] += dt;
        else if (rise <= UPHILL_FROM) kart.uphillFor[e] = 0;
        const legs = rise <= UPHILL_FROM || kart.uphillFor[e] < UPHILL_FOR * Math.max(0, 1 - rise / UPHILL_STEEP);
        if (pushing && grounded > 0 && speed < PUSH_TOP && legs) {
          forces.impulseX[e] += fwd.x * PUSH * dt;
          forces.impulseY[e] += fwd.y * PUSH * dt;
          forces.impulseZ[e] += fwd.z * PUSH * dt;
        }

        // An anti-roll bar: the lean about its nose damped while three wheels or more are down. A top-heavy kart still
        // goes over; a sensible one leans and slides instead.
        if (grounded >= 3) {
          const rollRate = wx * fwd.x + wy * fwd.y + wz * fwd.z;
          const damp = -rollRate * m * ANTI_ROLL * dt;
          forces.angularImpulseX[e] += fwd.x * damp;
          forces.angularImpulseY[e] += fwd.y * damp;
          forces.angularImpulseZ[e] += fwd.z * damp;
        }

        // Nearly stopped -- against a bale, say -- the driver hops out and drags it round: A/D turn it on the spot (the
        // tyres let it, above), at DRAG_TURN radians a second about its own up.
        if (dragging && grounded > 0) {
          const spin = wx * up.x + wy * up.y + wz * up.z;
          const add = steerIn * DRAG_TURN - spin;
          rb.angularVelocityX[e] = wx + up.x * add;
          rb.angularVelocityY[e] = wy + up.y * add;
          rb.angularVelocityZ[e] = wz + up.z * add;
        }

        // A crosswind, gusting: across the kart's way (its left, from the side the weather dealt), while it runs.
        if (phase === Phase.racing && sky.wind > 0) {
          const push = m * sky.wind * gust(time) * kart.windSide[e] * dt;
          forces.impulseX[e] += left.x * push;
          forces.impulseZ[e] += left.z * push;
          // It slides the kart, not tips it: the tyres holding against it at the road, far below the kart's middle,
          // would lean it over on its springs from the start (a held list, which reads as a fault) -- that twist
          // undone, as if the wind pushed it low down.
          const h = kart.rideY[e];
          forces.angularImpulseX[e] -= h * push * (up.y * left.z - up.z * left.y);
          forces.angularImpulseY[e] -= h * push * (up.z * left.x - up.x * left.z);
          forces.angularImpulseZ[e] -= h * push * (up.x * left.y - up.y * left.x);
        }

        // Air drag, tucked in when pushing at speed.
        const tucked = pushing && speed >= PUSH_TOP;
        kart.tucked[e] = tucked ? 1 : 0;
        // The parachute opens while braking: drag area of its own, so it brakes hardest at speed.
        const chute = brakeIn > 0 ? kart.chute[e] * brakeIn : 0;
        const drag = AIR * (kart.drag[e] * (tucked ? TUCK : 1) + chute) * speed * dt;
        forces.impulseX[e] -= vx * drag;
        forces.impulseY[e] -= vy * drag;
        forces.impulseZ[e] -= vz * drag;

        // The slope's extra pull (courses.ts' DOWNHILL): gravity's share along the ground, again, while it runs on its
        // wheels and the brakes are off -- never in the air (a jump flies as gravity has it), never against the brakes.
        if (driving && grounded >= 2 && brakeIn === 0) {
          const k = m * G * DOWNHILL * up.y * dt;
          forces.impulseX[e] += k * up.x;
          forces.impulseY[e] -= m * G * DOWNHILL * dt - k * up.y;
          forces.impulseZ[e] += k * up.z;
        }

        // The true centre of mass: gravity and the kart's own acceleration acting there, not at the box's
        // middle. In free fall the two cancel; in a corner it leans the kart out as a real one would.
        // Its acceleration smoothed over a few ticks and held to what driving makes: a knock's one-tick spike, fed
        // back as a turn, would set it spinning.
        let ax = (vx - kart.lastVX[e]) / dt;
        let ay = (vy - kart.lastVY[e]) / dt;
        let az = (vz - kart.lastVZ[e]) / dt;
        const al = Math.sqrt(ax * ax + ay * ay + az * az);
        if (al > ACCEL_MAX) {
          ax *= ACCEL_MAX / al;
          ay *= ACCEL_MAX / al;
          az *= ACCEL_MAX / al;
        }
        const ease = Math.min(1, dt * ACCEL_EASE);
        ax = kart.accelX[e] += (ax - kart.accelX[e]) * ease;
        ay = kart.accelY[e] += (ay - kart.accelY[e]) * ease;
        az = kart.accelZ[e] += (az - kart.accelZ[e]) * ease;
        rotate(qx, qy, qz, qw, kart.lean[e] * LEAN, kart.comY[e], kart.comZ[e], com);
        // Parked, none: its high centre of mass, balanced on soft springs, would tip it to one side as it sits.
        const pulled = parked ? 0 : m;
        const gx = -ax * pulled, gy = (-G - ay) * pulled, gz = -az * pulled;
        forces.angularImpulseX[e] += (com.y * gz - com.z * gy) * dt;
        forces.angularImpulseY[e] += (com.z * gx - com.x * gz) * dt;
        forces.angularImpulseZ[e] += (com.x * gy - com.y * gx) * dt;
        kart.lastVX[e] = vx;
        kart.lastVY[e] = vy;
        kart.lastVZ[e] = vz;
        // Its true inertia: the physics turns it as a solid box of its mass, far too easily (a driver up high and
        // wheels out at the corners are far harder to turn), so every turn this system gave it this tick -- the
        // springs', the tyres', the true centre of mass's -- is taken at box ÷ true (kart.turn*, by assemble),
        // about its own axes. Knocks and landings are the physics' own, and left as they are.
        unrotate(qx, qy, qz, qw, forces.angularImpulseX[e] - turnedX, forces.angularImpulseY[e] - turnedY, forces.angularImpulseZ[e] - turnedZ, spin);
        rotate(qx, qy, qz, qw, spin.x * kart.turnX[e], spin.y * kart.turnY[e], spin.z * kart.turnZ[e], spin);
        forces.angularImpulseX[e] = turnedX + spin.x;
        forces.angularImpulseY[e] = turnedY + spin.y;
        forces.angularImpulseZ[e] = turnedZ + spin.z;

        // Air time is style -- once it comes down the right way up.
        if (phase === Phase.racing && grounded === 0) kart.air[e] += dt;
        else if (grounded > 0) {
          const air = kart.air[e];
          kart.air[e] = 0;
          if (air > 0.3 && phase === Phase.racing) kart.landed[e] = air;
          if (phase === Phase.racing && air > JUMP && up.y > 0.7 && !kart.ejected[e]) {
            const points = Math.round(air * STYLE_PER_SECOND * Math.pow(REPEAT, kart.jumps[e]));
            kart.jumps[e]++;
            kart.style[e] += points;
            kart.news[e] = News.bigAir;
            kart.newsValue[e] = points;
            kart.newsAt[e] = kart.clock[e];
          }
        }
      }
    },
  });
}
