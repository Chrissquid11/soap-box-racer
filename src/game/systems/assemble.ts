/**
 * assemble, 60 Hz: a kart built anew. When its `Build.version` is one it has not built, the build's
 * numbers (`build.ts`' `rate`) go into its `Kart`, its body's mass and box, and its parts are dressed:
 * the chassis, the seat, the bodywork and the four wheels each given their model and put in place,
 * every wheel back on, the bodywork shown or not. The race puts `built` back to 0 to rebuild a kart
 * as new (all its wheels back) for a fresh run.
 */
import { BoxCollider, Hidden, Hierarchy, internKey, NONE, optional, Render, RigidBody, Transform, type World } from '@vibe/engine';
import { SteeringPart } from '../prefabs.ts';
import { BODY, BRAKE, CHASSIS, type Choice, DRIVER_MASS, newSized, OUTFITS, newRating, rate, type Rating, rulesBreak, SEAT_GRIP, sized, SIZES, STARTER, STEERING, SUSPENSION, WHEELS } from '../build.ts';
import { BinLid, BodyBit, Bodywork, BodyGlass, Build, ChassisLook, Corner, Kart, PartState, Phase, Seat, Spring, SteeringLook, Wheel } from '../components.ts';

/** The wheelie bin's lid (`parts.lua`' bin_lid) and where its hinge is on the bin: up, along (metres, at size 100%). */
const BIN_LID_MODEL = internKey('Model', 'karts/parts#bin_lid');
const BIN_HINGE = [0.365, -0.36] as const;
/** Each body's see-through piece's model (`BODY.glass`), in `BODY`'s order: `<model>_glass`. */
const GLASS_MODEL = BODY.map((b) => (b.glass && b.model ? internKey('Model', `${b.model}_glass`) : 0));


const choice: Choice = { ...STARTER };
const size = newSized();
/** A size held to what the builder offers. */
function within(v: number, i: number): number {
  const s = SIZES[i]!;
  return Math.max(s.min, Math.min(s.max, v));
}
const rating: Rating = newRating();
/** Each part's model, by key: interned once. */
const CHASSIS_MODEL = CHASSIS.map((c) => internKey('Model', c.model));
const WHEEL_MODEL = WHEELS.map((w) => internKey('Model', w.model));
const BODY_MODEL = BODY.map((b) => internKey('Model', b.model));
/** Each body's bits' models, by its BODY index and the bit's slot (`BodyBit`): `<model>_<part>`. */
const BIT_MODEL = BODY.map((b) => (b.bits ?? []).map((bit) => internKey('Model', `${b.model}_${bit.part}`)));
const STEER_MODEL = STEERING.map((s) => internKey('Model', s.model));
const SPRING_MODEL = SUSPENSION.map((s) => internKey('Model', s.model));
const OUTFIT_MODEL = OUTFITS.map((o) => internKey('Model', o.model));
/** Homemade karts are flimsy: what each part takes before it breaks, as a share of what `build.ts` lists. Low: the
 * fun is in it falling to bits. */
const FRAGILE_WHEELS = 0.32;
const FRAGILE_BODY = 0.25;
const FRAGILE_CHASSIS = 0.28;
const G = 9.81;
/** No tint: a part's own colours as modelled. */
const NATURAL = 0xffffff;
/** The fastest a kart may ring on its springs, radians a second: well inside what a 60 Hz tick follows. */
const RING = 30;
/** The driver: where their weight sits over the seat, and how far back of the middle (as build.ts has them). */
const DRIVER_LIFT = 0.3;
const DRIVER_Z = -0.25;
/** The driver model's hips, above its feet (driver.lua's HIPS). */
const DRIVER_HIPS = 0.62;

/** A point mass's inertia about the x axis through the chassis' middle, at height y and z along. */
function pointX(pm: number, y: number, z: number): number {
  return pm * (y * y + z * z);
}

export function assemble(world: World): void {
  world.system({
    name: 'assemble',
    rate: 60,
    read: [Build, Hierarchy],
    write: [Kart, RigidBody, BoxCollider, optional(Transform), optional(Render), optional(Wheel), optional(BodyBit)],
    update({ members, count, cmd, has, ref, deref }, [build, tree], [kart, body, box, at, look, wheel, bits]) {
      for (let n = 0; n < count; n++) {
        const e = members[n];
        if (kart.built[e] === build.version[e]) continue;
        kart.built[e] = build.version[e];

        choice.chassis = Math.min(build.chassis[e], CHASSIS.length - 1);
        choice.wheels = Math.min(build.wheels[e], WHEELS.length - 1);
        choice.suspension = Math.min(build.suspension[e], SUSPENSION.length - 1);
        choice.steering = Math.min(build.steering[e], STEERING.length - 1);
        choice.body = Math.min(build.body[e], BODY.length - 1);

        choice.outfit = Math.min(build.outfit[e], OUTFITS.length - 1);
        choice.chassisWidth = within(build.chassisWidth[e], 0);
        choice.chassisLength = within(build.chassisLength[e], 1);
        choice.frontSize = within(build.frontSize[e], 2);
        choice.rearSize = within(build.rearSize[e], 3);
        choice.springSize = within(build.springSize[e], 4);
        rate(choice, rating);
        const z = sized(choice, size);
        const wh = WHEELS[choice.wheels]!;
        const su = SUSPENSION[choice.suspension]!;
        const st = STEERING[choice.steering]!;
        const bo = BODY[choice.body]!;


        const m = rating.mass;
        kart.mass[e] = m;
        kart.halfTrack[e] = z.track / 2;
        kart.halfBase[e] = z.base / 2;
        kart.halfBack[e] = rating.behind;
        kart.halfHeight[e] = z.sizeY / 2;
        // A kart set on the line this tick was set at the old build's height: held as high again as the new one
        // rides above or below it, so wheels twice the size never start buried in the road (and kick it spinning).
        if (kart.phase[e] === Phase.garage || kart.phase[e] === Phase.countdown) at.py[e] += rating.rideY - kart.rideY[e];
        kart.rideY[e] = rating.rideY;
        // The whole kart's centre of mass, from the chassis' middle (the body's own origin).
        kart.comY[e] = rating.comY - rating.rideY;
        kart.comZ[e] = rating.comZ;
        const radius = (z.front + z.rear) / 2;
        kart.radius[e] = radius;
        kart.travel[e] = z.travel;
        // The springs, no stiffer than the box's inertia can follow tick by tick: rolling on a narrow plank or
        // pitching, it may not ring faster than RING radians a second (stiffer still and it shakes itself apart).
        const bx = z.sizeX, by = z.sizeY, bz = z.sizeZ;
        const roll = (m * (bx * bx + by * by)) / 12;
        const pitch = (m * (by * by + bz * bz)) / 12;
        const stiffest = Math.min(
          (RING * RING * roll) / (2 * (z.track / 2) ** 2),
          (RING * RING * pitch) / (2 * (z.base / 2) ** 2),
          (RING * RING * m) / 4,
        );
        // And no softer than will stand it up: a tall kart on soft springs is a pendulum stood on its head,
        // so the springs at its corners must hold its weight's pull over (half again) as it leans or pitches.
        const over = 1.5 * m * G * rating.comY;
        const softest = Math.max(over / (2 * (z.track / 2) ** 2), over / (2 * (z.base / 2) ** 2));
        kart.spring[e] = Math.min(Math.max((su.stiff * (m * G / 4)) / z.travel, softest), stiffest);
        kart.damper[e] = su.damp * 2 * Math.sqrt(kart.spring[e] * (m / 4));
        kart.grip[e] = wh.grip;
        kart.strength[e] = z.strength * FRAGILE_WHEELS;
        kart.soak[e] = z.soak;
        kart.lock[e] = st.lock;
        kart.steerRate[e] = st.rate;
        kart.steerFade[e] = st.fade;
        kart.levers[e] = st.levers ?? 0;
        kart.brake[e] = BRAKE.force;
        kart.drag[e] = rating.drag;
        kart.wobble[e] = wh.wobble;
        kart.thin[e] = wh.thin ? 1 : 0;
        kart.legal[e] = rulesBreak(rating) === '' ? 1 : 0;
        // A whole kart runs straight: only a bent or lost wheel pulls it off line (`damage.ts`).
        kart.pull[e] = 0;
        kart.seatGrip[e] = SEAT_GRIP + bo.cushion;
        kart.rolling[e] = z.rolling;
        kart.chute[e] = BRAKE.chute;
        kart.thrust[e] = bo.thrust;
        kart.fuelMax[e] = bo.fuel;
        kart.fuel[e] = bo.fuel;
        kart.wing[e] = bo.wing;
        kart.bodyStrength[e] = bo.strength * FRAGILE_BODY;
        kart.appeal[e] = rating.appeal;
        kart.bodyOn[e] = bo.model !== '' ? 1 : 0;
        kart.bodyDamage[e] = 0;
        kart.hitSide[e] = 0;
        kart.hitEnd[e] = 0;
        // Every part whole again (`damage.ts`), and nothing left for the HUD to call out.
        kart.bodyState[e] = PartState.healthy;
        kart.bodyAt[e] = -99;
        kart.callAt[e] = -99;
        // Bolted on is no suspension: a hard landing is the wheels'.
        kart.sprung[e] = choice.suspension > 0 ? 1 : 0;
        kart.hp[e] = z.hp * FRAGILE_CHASSIS;
        kart.steerOn[e] = 1;

        body.mass[e] = m;
        box.sizeX[e] = bx;
        box.sizeY[e] = by;
        box.sizeZ[e] = bz;

        const top = by / 2;
        const seatY = top - (choice.chassis === 0 ? 0 : by * 0.6);

        // The kart's true inertia, about the chassis' middle: the chassis itself, and the driver, the bodywork and
        // the wheels where they sit -- far more than the physics' solid box of the same mass has, with the driver
        // up high and the wheels out at the corners. `vehicle` takes only box ÷ true of each change in its spin.
        const wy = radius - rating.rideY;
        const hx = z.track / 2, hz = z.base / 2;
        const dy = seatY + DRIVER_LIFT, dz = CHASSIS[choice.chassis]!.seat ?? DRIVER_Z;
        const by2 = top + bo.lift, bz2 = bo.z * z.scaleZ;
        const cm = z.mass, wm = z.wheelMass;
        const trueX = (cm * (by * by + bz * bz)) / 12 + pointX(DRIVER_MASS, dy, dz) + pointX(bo.mass, by2, bz2) + pointX(wm, wy, hz);
        const trueY = (cm * (bx * bx + bz * bz)) / 12 + DRIVER_MASS * dz * dz + bo.mass * bz2 * bz2 + wm * (hx * hx + hz * hz);
        const trueZ = (cm * (bx * bx + by * by)) / 12 + DRIVER_MASS * dy * dy + bo.mass * by2 * by2 + wm * (hx * hx + wy * wy);
        kart.turnX[e] = Math.min(1, pitch / trueX);
        kart.turnY[e] = Math.min(1, (m * (bx * bx + bz * bz)) / 12 / trueY);
        kart.turnZ[e] = Math.min(1, roll / trueZ);

        // Its steering made under it the first time (a part of its own, not of the kart's prefab: a scene saved before
        // there was one still gets one); dressed with the rest below from then on.
        if (deref(kart.steering[e]) === NONE) {
          const s = cmd.instantiate(SteeringPart);
          if (s !== NONE) {
            cmd.setParent(s, e);
            const sat = cmd.init(s, Transform);
            sat.py[s] = seatY + st.up;
            sat.pz[s] = st.ahead;
            cmd.init(s, Render).model[s] = STEER_MODEL[choice.steering]!;
            kart.steering[e] = ref(s);
          }
        }

        // The parts, dressed and placed.
        kart.seatY[e] = seatY;
        for (let c = tree.firstChild[e]; c !== 0; c = tree.nextSibling[c]) {
          if (has(c, ChassisLook)) {
            look.model[c] = CHASSIS_MODEL[choice.chassis]!;
            look.tint[c] = NATURAL;
            at.sx[c] = z.scaleX;
            at.sy[c] = z.scale;
            at.sz[c] = z.scaleZ;
            // After a wreck, whole again -- hidden under a body that is the whole kart.
            if (bo.cover) { if (!has(c, Hidden)) cmd.add(c, Hidden); }
            else if (has(c, Hidden)) cmd.remove(c, Hidden);
          } else if (has(c, BodyGlass)) {
            // The body's see-through piece, where it has one, in its see-through material; placed as the body is.
            if (bo.glass && bo.model) {
              look.model[c] = GLASS_MODEL[choice.body]!;
              look.material[c] = internKey('Material', bo.glass);
              look.tint[c] = NATURAL;
              const natural = bo.natural === true;
              at.px[c] = 0; at.py[c] = top; at.pz[c] = bo.z * z.scaleZ;
              at.sx[c] = natural ? z.scaleX : 1; at.sy[c] = natural ? z.scale : 1; at.sz[c] = natural ? z.scaleZ : 1;
              if (has(c, Hidden)) cmd.remove(c, Hidden);
            } else if (!has(c, Hidden)) cmd.add(c, Hidden);
          } else if (has(c, BinLid)) {
            // The wheelie bin's lid, on its hinge at the top of the bin's back, at the bin's size; on no other chassis
            // (nor under a body that hides the chassis).
            const bin = CHASSIS[choice.chassis]!.name === 'Wheelie bin' && !bo.cover;
            if (bin) {
              look.model[c] = BIN_LID_MODEL;
              look.tint[c] = NATURAL;
              at.px[c] = 0;
              at.py[c] = BIN_HINGE[0] * z.scale;
              at.pz[c] = BIN_HINGE[1] * z.scaleZ;
              at.sx[c] = z.scaleX;
              at.sy[c] = z.scale;
              at.sz[c] = z.scaleZ;
              if (has(c, Hidden)) cmd.remove(c, Hidden);
            } else if (!has(c, Hidden)) cmd.add(c, Hidden);
          } else if (has(c, Spring)) {
            look.model[c] = SPRING_MODEL[choice.suspension]!;
            // Always in sight, whatever the body: under a body that is the whole kart, `wheelLook` stands it close by its wheel.
            if (has(c, Hidden)) cmd.remove(c, Hidden);
          } else if (has(c, Seat)) {
            at.px[c] = 0;
            at.py[c] = seatY - DRIVER_HIPS + 0.04;   // the model's feet are its origin: its hips on the seat
            at.pz[c] = CHASSIS[choice.chassis]!.seat ?? DRIVER_Z;
            look.model[c] = OUTFIT_MODEL[choice.outfit]!;
            if (has(c, Hidden)) cmd.remove(c, Hidden);
          } else if (has(c, SteeringLook)) {
            // In the driver's hands; `steerLook` tips it toward them and turns it.
            look.model[c] = STEER_MODEL[choice.steering]!;
            at.px[c] = 0;
            at.py[c] = seatY + st.up;
            at.pz[c] = st.ahead + (CHASSIS[choice.chassis]!.seat ?? DRIVER_Z) - DRIVER_Z;
            if (has(c, Hidden)) cmd.remove(c, Hidden);   // snapped off last run: back on
          } else if (has(c, Bodywork)) {
            look.model[c] = BODY_MODEL[choice.body]!;
            look.tint[c] = NATURAL;   // every part its own colours
            at.py[c] = top;
            at.pz[c] = bo.z * z.scaleZ;
            // A themed body is a shell over the whole kart: as wide, long and tall as its chassis is made.
            const natural = bo.natural === true;
            at.sx[c] = natural ? z.scaleX : 1;
            at.sy[c] = natural ? z.scale : 1;
            at.sz[c] = natural ? z.scaleZ : 1;
            const hide = bo.model === '';
            if (hide && !has(c, Hidden)) cmd.add(c, Hidden);
            else if (!hide && has(c, Hidden)) cmd.remove(c, Hidden);
            // Its bits that come off on their own, each in its slot under it, drawn where the body is (all back on).
            const models = BIT_MODEL[choice.body]!;
            for (let s = tree.firstChild[c]; s !== 0; s = tree.nextSibling[s]) {
              if (!has(s, BodyBit)) continue;
              bits.off[s] = 0;
              const model = models[bits.slot[s]];
              if (model !== undefined) {
                look.model[s] = model;
                look.tint[s] = NATURAL;
                if (has(s, Hidden)) cmd.remove(s, Hidden);
              } else if (!has(s, Hidden)) cmd.add(s, Hidden);
            }
          } else if (has(c, Wheel)) {
            const corner = wheel.corner[c];
            look.model[c] = WHEEL_MODEL[choice.wheels]!;
            const left = corner === Corner.fl || corner === Corner.rl;
            const front = corner === Corner.fl || corner === Corner.fr;
            // Each end its own size: the wheel's model scaled to its radius, and the radius its rays reach by.
            const r = front ? z.front : z.rear;
            const grow = r / wh.radius;
            at.px[c] = (left ? 1 : -1) * z.track / 2;
            at.py[c] = -top - z.travel + z.travel / su.stiff;
            at.pz[c] = (front ? 1 : -1) * z.base / 2;
            at.sx[c] = grow;
            at.sy[c] = grow;
            at.sz[c] = grow;
            wheel.radius[c] = r;
            wheel.attached[c] = 1;
            wheel.bent[c] = 0;   // a new build's wheels run true
            wheel.state[c] = PartState.healthy;
            wheel.stateAt[c] = -99;
            wheel.spring[c] = PartState.healthy;
            wheel.springAt[c] = -99;
            wheel.compression[c] = z.travel / su.stiff;
            if (has(c, Hidden)) cmd.remove(c, Hidden);
          }
        }
      }
    },
  });
}
