/**
 * driver, 60 Hz: the driver thrown out and climbing back in. When `vehicle` or `impacts` says the
 * driver goes (`Kart.thrown`), the seated driver is hidden and a ragdoll -- ten bodies on joints,
 * knees and elbows hinged -- flies on from the seat with the kart's speed, tipped as the kart was,
 * leant back and tumbling, every limb flung its own way. Once it has come to rest (or after a few seconds
 * whatever it is doing) it is gone, and the driver is back in the seat -- if the kart is on its wheels. Nobody
 * sets a crashed kart right: one on its side or its back stays so, and `race` ends the run.
 */
import { Hidden, Hierarchy, internKey, NONE, optional, Render, RigidBody, Transform, type World } from '@vibe/engine';
import { OUTFITS } from '../build.ts';
import { Build, Cause, Kart, News, Seat } from '../components.ts';
import { rotate, v3 } from '../kart-math.ts';
import { RagArmL, RagArmR, RagForeArmL, RagForeArmR, RagHead, RagLegL, RagLegR, RagShinL, RagShinR, RagSkin, RagTorso, Ragdoll } from '../prefabs.ts';

/** Each outfit's model, by key: the thrown driver wears what the seated one did. */
const OUTFIT_MODEL = OUTFITS.map((o) => internKey('Model', o.model));

/** Thrown: leant back this far out of the seat (radians about its left), tumbling this fast (degrees a second, ± a third) with up to this much twist. */
const LEAN_BACK = -0.6;
const TUMBLE = 260;
const TWIST = 90;
/** m/s up a wrecked kart throws its driver: a long way. */
const WRECK_LAUNCH = 9;

const seat = v3();
const side = v3();
const upward = v3();
const PARTS = [RagTorso, RagHead, RagArmL, RagArmR, RagLegL, RagLegR, RagForeArmL, RagForeArmR, RagShinL, RagShinR] as const;
/** How hard each part is flung its own way, m/s: the body a little, the head more, the limbs most. */
const FLING = [0.3, 0.8, 1.6, 1.6, 1.2, 1.2, 1.4, 1.4, 1.0, 1.0] as const;

/** A number in [0, 1) from the moment and a salt: the same throw at the same moment, another at another. */
function jitter(t: number, salt: number): number {
  const x = Math.sin(t * 12.9898 + salt * 78.233) * 43758.5453;
  return x - Math.floor(x);
}

export function driver(world: World): void {
  world.system({
    name: 'driver',
    rate: 60,
    after: ['impacts'],
    read: [Hierarchy, optional(Build)],
    write: [Kart, Transform, RigidBody],
    update({ members, count, dt, cmd, has, ref }, [tree, build], [kart, at, rb]) {
      for (let n = 0; n < count; n++) {
        const e = members[n];
        const qx = at.qx[e], qy = at.qy[e], qz = at.qz[e], qw = at.qw[e];

        // Thrown out.
        if (kart.thrown[e] !== Cause.none && !kart.ejected[e]) {
          kart.ejected[e] = 1;
          kart.ejectTime[e] = 0;
          kart.ejections[e]++;
          kart.cause[e] = kart.thrown[e];
          kart.news[e] = kart.wrecked[e] ? News.wrecked : News.thrown;
          kart.newsAt[e] = kart.clock[e];
          for (let c = tree.firstChild[e]; c !== 0; c = tree.nextSibling[c]) if (has(c, Seat) && !has(c, Hidden)) cmd.add(c, Hidden);
          // The ragdoll's origin is the driver's feet: placed so its hips rise a little out of the seat.
          rotate(qx, qy, qz, qw, 0, kart.seatY[e] + 0.3 - 0.62, -0.25, seat);
          const rag = cmd.instantiate(Ragdoll);
          if (rag !== NONE) {
            const skin = cmd.part(rag, RagSkin);
            if (has(e, Build)) cmd.init(skin, Render).model[skin] = OUTFIT_MODEL[Math.min(build.outfit[e], OUTFITS.length - 1)]!;
            const place = cmd.init(rag, Transform);
            place.px[rag] = at.px[e] + seat.x;
            place.py[rag] = at.py[e] + seat.y;
            place.pz[rag] = at.pz[e] + seat.z;
            // Tipped as the kart is, and leant back out of the seat: never stood up straight. q = kart × lean.
            const ls = Math.sin(LEAN_BACK / 2), lc = Math.cos(LEAN_BACK / 2);
            place.qx[rag] = qw * ls + qx * lc;
            place.qy[rag] = qy * lc + qz * ls;
            place.qz[rag] = qz * lc - qy * ls;
            place.qw[rag] = qw * lc - qx * ls;
            // Its tumble: head over heels forward, about the kart's left, a little twist about its up.
            rotate(qx, qy, qz, qw, 1, 0, 0, side);
            rotate(qx, qy, qz, qw, 0, 1, 0, upward);
            const spin = TUMBLE * (0.7 + 0.6 * jitter(kart.clock[e], 0));
            const twist = TWIST * (jitter(kart.clock[e], 1) * 2 - 1);
            for (let p = 0; p < PARTS.length; p++) {
              const part = cmd.part(rag, PARTS[p]!);
              const body = cmd.init(part, RigidBody);
              // On with the kart's speed and up out of the seat, each part a little its own way -- the arms and
              // legs flung wider than the body -- so it flails from the first frame, never flying out in one piece.
              const fling = FLING[p]!;
              body.startVelocityX[part] = rb.velocityX[e] * 0.9 + (jitter(kart.clock[e], p + 2) * 2 - 1) * fling;
              // A wreck launches them skyward: a cannon-ball of a driver, limbs everywhere.
              body.startVelocityY[part] = Math.max(rb.velocityY[e], 0) + (kart.thrown[e] === Cause.wrecked ? WRECK_LAUNCH : 3.5) + jitter(kart.clock[e], p + 12) * fling;
              body.startVelocityZ[part] = rb.velocityZ[e] * 0.9 + (jitter(kart.clock[e], p + 22) * 2 - 1) * fling;
              body.startSpinX[part] = side.x * spin + upward.x * twist;
              body.startSpinY[part] = side.y * spin + upward.y * twist;
              body.startSpinZ[part] = side.z * spin + upward.z * twist;
              if (p === 0) kart.torso[e] = ref(part);
            }
            kart.ragdoll[e] = ref(rag);
          }
          continue;
        }

        // Thrown: there is no climbing back in -- `race` ends the run a moment later (THROWN_FOR).
        if (kart.ejected[e]) {
          kart.ejectTime[e] += dt;
          continue;
        }
      }
    },
  });
}

