/**
 * wear, 60 Hz: a kart falling to bits. Its `damage` (summed by `impacts` from every knock and by `vehicle` from
 * every landing too hard for its springs) against what its chassis takes (`hp`):
 *
 *   as it wears       it goes dull and scuffed, the chassis' and the bodywork's both
 *   half gone         the steering snaps off and flies away: what is left of it steers with half the lock
 *   worn on           at each of `damage.ts`' shedAt marks a part shakes loose and falls off -- the bodywork first,
 *                     then a wheel at a time -- and it drives on, limping
 *   smashed           one massive knock or landing, or right off the course (`Kart.smash`): wrecked -- the chassis
 *                     bursts into broken planks and splinters, every wheel, spring and the bodywork come off, the
 *                     driver is thrown, and `race` starts the run again WRECK later
 *
 * The race's reset and `assemble` put it all back as new.
 */
import { BoxCollider, Hidden, Hierarchy, NONE, optional, Render, RigidBody, Transform, type World } from '@vibe/engine';
import { BODY, CHASSIS } from '../build.ts';
import { BodyGlass, Bodywork, Build, Cause, ChassisLook, Corner, Kart, News, PartName, PartState, Phase, Spring, SteeringLook, Wheel } from '../components.ts';
import { callOut, shedShare } from '../damage.ts';
import { rotate, v3 } from '../kart-math.ts';
import { shatterBody } from './impacts.ts';
import { BrokenPlank, LooseBody, Splinter } from '../prefabs.ts';
import { dropWheel } from '../shed.ts';
import { burst } from '../burst.ts';

/** How dull the paint goes, worn right through: the share of its colour lost. */
const DULL = 0.5;
/** The share of its wear at which the steering snaps off, and the lock left after. */
const STEER_SNAPS = 0.5;
const STEER_LEFT = 0.5;
/** A wreck: the broken planks and the splinters it bursts into, and how hard they fly. */
const PLANKS = 5;
const SPLINTERS = 24;
const BURST = 8.5;
/** The shards of the chassis and of the bodywork a wreck throws besides (`burst.ts`). */
const CHASSIS_SHARDS = 28;
const BODY_SHARDS = 52;
/** A total wreck's big chunks (the frame, the bodywork): how far up they start off it, and the bodywork's mass (the
 * frame half as heavy again). */
const CHUNK_LIFT = 0.25;
const CHUNK_MASS = 12;
/** How big the bodywork's chunks are, over the debris model: big panels, as a knocked-off body's (`impacts`). */
const BODY_CHUNK = 1.5;
/** Worn past a mark: seconds at least between one part shaking loose and the next, and how hard bodywork shed so flies. */
const SHED_GAP = 0.6;
const SHED_BURST = 4;
/** No tint: a themed body's own colours. */
const NATURAL = 0xffffff;

const spot = v3();

/** `tint` dulled by `wear` (0 new, 1 worn through): each channel darkened and greyed toward brown. */
function dulled(tint: number, wear: number): number {
  const k = 1 - DULL * Math.min(1, wear);
  // Toward a muddy brown, not just black: scuffed, not burnt.
  const mud = (1 - k) * 0.6;
  const r = Math.round(((tint >> 16) & 255) * k + 110 * mud);
  const g = Math.round(((tint >> 8) & 255) * k + 85 * mud);
  const b = Math.round((tint & 255) * k + 60 * mud);
  return (r << 16) | (g << 8) | b;
}

export function wear(world: World): void {
  world.system({
    name: 'wear',
    rate: 60,
    after: ['impacts', 'driver'],
    read: [Transform, Hierarchy, Build],
    write: [Kart, optional(Render), optional(Wheel), RigidBody],
    update(ctx, [at, tree, build], [kart, look, wheel, rb]) {
      const { members, count, cmd, has, deref } = ctx;
      for (let n = 0; n < count; n++) {
        const e = members[n];
        const running = kart.phase[e] === Phase.racing || kart.phase[e] === Phase.finished;
        const share = kart.damage[e] / Math.max(1, kart.hp[e]);
        // What the chassis breaks into: its own colour (`CHASSIS.colour`), as worn as it is.
        const paint = CHASSIS[Math.min(build.chassis[e], CHASSIS.length - 1)]!.colour;

        const want = dulled(paint, share);
        // Its look, its own colours as worn as it is (new again after a reset: share 0).
        // The bodywork's own paint the more battered of the kart's wear and its own (`Kart.bodyDamage`): it scuffs the faster.
        const bodyShare = Math.max(share, kart.bodyDamage[e]);
        const wantBody = dulled(NATURAL, bodyShare);
        const wantChassis = dulled(NATURAL, share);
        for (let c = tree.firstChild[e]; c !== 0; c = tree.nextSibling[c]) {
          if (has(c, ChassisLook) && look.tint[c] !== wantChassis) look.tint[c] = wantChassis;
          else if (has(c, Bodywork) && look.tint[c] !== wantBody) look.tint[c] = wantBody;
        }
        if (!running || kart.wrecked[e]) continue;
        const qx = at.qx[e], qy = at.qy[e], qz = at.qz[e], qw = at.qw[e];

        // Half gone: the steering snaps off.
        const snapped = kart.steerOn[e] === 1 && share >= STEER_SNAPS;
        if (snapped) {
          kart.steerOn[e] = 0;
          kart.lock[e] *= STEER_LEFT;
          kart.news[e] = News.lostSteering;
          kart.newsAt[e] = kart.clock[e];
          const s = deref(kart.steering[e]);
          if (s !== NONE) {
            if (!has(s, Hidden)) cmd.add(s, Hidden);
            rotate(qx, qy, qz, qw, at.px[s], at.py[s], at.pz[s], spot);
            const loose = cmd.instantiate(LooseBody);
            if (loose !== NONE) {
              const lat = cmd.init(loose, Transform);
              lat.px[loose] = at.px[e] + spot.x;
              lat.py[loose] = at.py[e] + spot.y + 0.2;
              lat.pz[loose] = at.pz[e] + spot.z;
              const lrb = cmd.init(loose, RigidBody);
              lrb.startVelocityX[loose] = rb.velocityX[e] * 0.7;
              lrb.startVelocityY[loose] = 5;
              lrb.startSpinX[loose] = 700;
              lrb.startSpinZ[loose] = 300;
              lrb.startVelocityZ[loose] = rb.velocityZ[e] * 0.7;
              cmd.init(loose, Render).model[loose] = look.model[s];
            }
          }
        }

        // Worn past another of its marks (`damage.ts`' shedAt): one more part shakes loose and falls off -- the bodywork
        // first, then a wheel -- one at a time, a moment apart, while it drives on.
        if (!kart.smash[e]) {
          if (share >= shedShare(kart.shed[e]) && kart.clock[e] - kart.shedClock[e] >= SHED_GAP) {
            kart.shed[e]++;
            kart.shedClock[e] = kart.clock[e];
            if (kart.bodyOn[e]) shatterBody(ctx, tree, build, look, at, rb, kart, e, Math.max(kart.speed[e], SHED_BURST));
            else {
              // A wheel: which of those still on, the same for the same run (its count of what it has shed).
              let on = 0;
              for (let c = tree.firstChild[e]; c !== 0; c = tree.nextSibling[c]) if (has(c, Wheel) && wheel.attached[c]) on++;
              let pick = on > 0 ? (kart.shed[e] * 7 + e) % on : -1;
              // Hit on one side (`Kart.hitSide`, `hitEnd`): the wheel nearest where, instead.
              const hs = kart.hitSide[e], he = kart.hitEnd[e];
              if (on > 0 && (hs !== 0 || he !== 0)) {
                let best = Infinity, n = 0;
                for (let c = tree.firstChild[e]; c !== 0; c = tree.nextSibling[c]) {
                  if (!has(c, Wheel) || !wheel.attached[c]) continue;
                  const k = wheel.corner[c];
                  const dx = (k === Corner.fl || k === Corner.rl ? 1 : -1) - hs;
                  const dz = (k === Corner.fl || k === Corner.fr ? 1 : -1) - he;
                  if (dx * dx + dz * dz < best) {
                    best = dx * dx + dz * dz;
                    pick = n;
                  }
                  n++;
                }
              }
              for (let c = tree.firstChild[e]; c !== 0 && pick >= 0; c = tree.nextSibling[c]) {
                if (!has(c, Wheel) || !wheel.attached[c] || pick-- > 0) continue;
                const k = wheel.corner[c];
                wheel.attached[c] = 0;
                wheel.state[c] = PartState.failed;
                wheel.stateAt[c] = kart.clock[e];
                kart.wheelsLost[e]++;
                kart.news[e] = News.lostWheel;
                kart.newsAt[e] = kart.clock[e];
                callOut(kart, e, PartName.wheelFL + k, PartState.failed);
                if (!has(c, Hidden)) cmd.add(c, Hidden);
                const side = k === Corner.fl || k === Corner.rl ? 1 : -1;
                const loose = dropWheel(cmd, at, look, wheel, e, c);
                if (loose === NONE) break;
                rotate(qx, qy, qz, qw, side * 2.5, 0, 0, spot);
                const lrb = cmd.init(loose, RigidBody);
                lrb.startVelocityX[loose] = rb.velocityX[e] + spot.x;
                lrb.startVelocityY[loose] = Math.max(rb.velocityY[e], 0) + 4;
                lrb.startVelocityZ[loose] = rb.velocityZ[e] + spot.z;
                lrb.startSpinX[loose] = 1100;
                lrb.startSpinY[loose] = 450;
              }
            }
          }
          continue;
        }
        // One massive hit (or right off the course): wrecked. In bits.
        kart.wrecked[e] = 1;
        kart.wreckedAt[e] = kart.clock[e];
        kart.cause[e] = Cause.wrecked;
        kart.causeSpeed[e] = kart.speed[e];
        kart.bodyOn[e] = 0;
        kart.news[e] = News.wrecked;
        kart.newsAt[e] = kart.clock[e];
        if (!kart.ejected[e]) kart.thrown[e] = Cause.wrecked;
        const vx = rb.velocityX[e], vy = rb.velocityY[e], vz = rb.velocityZ[e];
        for (let c = tree.firstChild[e]; c !== 0; c = tree.nextSibling[c]) {
          // The body's see-through piece (the pram's hood) goes with the body.
          if (has(c, BodyGlass)) {
            if (!has(c, Hidden)) cmd.add(c, Hidden);
            continue;
          }
          if (has(c, Wheel)) {
            if (!wheel.attached[c]) continue;
            wheel.attached[c] = 0;
            kart.wheelsLost[e]++;
            if (!has(c, Hidden)) cmd.add(c, Hidden);
            // Each wheel off its own corner, outward.
            const k = wheel.corner[c];
            const side = k === Corner.fl || k === Corner.rl ? 1 : -1;
            const loose = dropWheel(cmd, at, look, wheel, e, c);
            if (loose === NONE) continue;
            rotate(qx, qy, qz, qw, side * BURST * 0.6, 0, 0, spot);
            const lrb = cmd.init(loose, RigidBody);
            lrb.startVelocityX[loose] = vx + spot.x;
            lrb.startVelocityY[loose] = Math.max(vy, 0) + 4.5 + (k % 2) * 2;   // each its own way, spinning
            lrb.startSpinX[loose] = 900 + k * 150;
            lrb.startSpinY[loose] = (k % 2 ? -1 : 1) * 400;
            lrb.startVelocityZ[loose] = vz + spot.z;
          } else if (has(c, ChassisLook) || has(c, Bodywork) || has(c, Spring) || (has(c, SteeringLook) && !snapped)) {
            // The frame and the bodywork, still on it, go as big recognisable chunks of the kart itself -- its own
            // models at its own size, tumbling off on its speed -- the rest of it in splinters and shards (below).
            // (Steering snapped off this very tick is hidden already, above.)
            const shown = !has(c, Hidden);
            if ((has(c, ChassisLook) || has(c, Bodywork)) && shown && look.model[c]) {
              const chunk = cmd.instantiate(LooseBody);
              if (chunk !== NONE) {
                rotate(qx, qy, qz, qw, at.px[c], at.py[c], at.pz[c], spot);
                const cat = cmd.init(chunk, Transform);
                cat.px[chunk] = at.px[e] + spot.x;
                cat.py[chunk] = at.py[e] + spot.y + CHUNK_LIFT;
                cat.pz[chunk] = at.pz[e] + spot.z;
                cat.qx[chunk] = qx; cat.qy[chunk] = qy; cat.qz[chunk] = qz; cat.qw[chunk] = qw;
                const gx = at.sx[c] || 1, gy = at.sy[c] || 1, gz = at.sz[c] || 1;
                cat.sx[chunk] = gx; cat.sy[chunk] = gy; cat.sz[chunk] = gz;
                // Its collider the kart's box (in the model's own units: it scales with the chunk).
                const body = has(c, Bodywork);
                const box = cmd.init(chunk, BoxCollider);
                box.sizeX[chunk] = (kart.halfTrack[e] * 1.6) / gx;
                box.sizeY[chunk] = (kart.halfHeight[e] * (body ? 3 : 2)) / gy;
                box.sizeZ[chunk] = (kart.halfBase[e] * 2.2) / gz;
                box.centerY[chunk] = body ? (kart.halfHeight[e] * 1.5) / gy : 0;
                const view = cmd.init(chunk, Render);
                view.model[chunk] = look.model[c];
                view.tint[chunk] = look.tint[c];
                const crb = cmd.init(chunk, RigidBody);
                crb.mass[chunk] = body ? CHUNK_MASS : CHUNK_MASS * 1.5;
                crb.startVelocityX[chunk] = vx * 0.8 + (body ? 1.5 : -1) * spot.x;
                crb.startVelocityY[chunk] = Math.max(vy, 0) + (body ? 5 : 3);
                crb.startVelocityZ[chunk] = vz * 0.8 + (body ? 1.5 : -1) * spot.z;
                crb.startSpinX[chunk] = body ? 260 : -180;
                crb.startSpinZ[chunk] = body ? 140 : 90;
              }
            }
            if (shown) cmd.add(c, Hidden);
          }
        }
        // The chassis bursts: planks out of its box, splinters with them, all on with the kart's speed.
        const hx = kart.halfTrack[e], hy = kart.halfHeight[e], hz = kart.halfBase[e];
        for (let p = 0; p < PLANKS + SPLINTERS; p++) {
          const plank = p < PLANKS;
          const bit = cmd.instantiate(plank ? BrokenPlank : Splinter);
          if (bit === NONE) continue;
          // Spread round the box: a turn about it, up and down it, along it.
          const a = (p * 2.399) % (2 * Math.PI);
          const ox = Math.cos(a) * hx * 0.8, oy = ((p % 3) - 1) * hy * 0.7, oz = Math.sin(a) * hz * 0.8;
          rotate(qx, qy, qz, qw, ox, oy, oz, spot);
          const bat = cmd.init(bit, Transform);
          bat.px[bit] = at.px[e] + spot.x;
          bat.py[bit] = at.py[e] + spot.y + 0.1;
          bat.pz[bit] = at.pz[e] + spot.z;
          bat.qx[bit] = qx;
          bat.qy[bit] = qy;
          bat.qz[bit] = qz;
          bat.qw[bit] = qw;
          const out = BURST * (plank ? 0.7 : 1.2);
          const len = Math.hypot(spot.x, spot.z) || 1;
          const brb = cmd.init(bit, RigidBody);
          brb.startVelocityX[bit] = vx * 0.8 + (spot.x / len) * out;
          brb.startVelocityY[bit] = Math.max(vy, 0) + 2 + (p % 4) * 0.8;
          brb.startVelocityZ[bit] = vz * 0.8 + (spot.z / len) * out;
          cmd.init(bit, Render).tint[bit] = want;
        }
        // And the rest of it flies apart: shards of the chassis in its paint, of the bodywork in its own colours, and
        // bolts -- a cloud of bits up and out, harder the faster it was going.
        const bo = BODY[Math.min(build.body[e], BODY.length - 1)]!;
        const pace = Math.hypot(vx, vy, vz);
        burst(cmd, {
          x: at.px[e], y: at.py[e], z: at.pz[e], spread: Math.max(hx, hz),
          vx, vy, vz, power: BURST + pace * 0.3, count: CHASSIS_SHARDS,
          colours: [want, dulled(want, 1)], size: 0.6, seed: e * 7 + 1,
        });
        if (bo.model !== '') {
          burst(cmd, {
            x: at.px[e], y: at.py[e] + hy * 2, z: at.pz[e], spread: Math.max(hx, hz) * 1.2,
            vx, vy, vz, power: BURST * 1.25 + pace * 0.35, count: BODY_SHARDS,
            colours: bo.debris ?? [wantBody], size: BODY_CHUNK, seed: e * 7 + 2,
          });
        }
      }
    },
  });
}
