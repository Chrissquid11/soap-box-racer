/**
 * ragdollLimit, 60 Hz: a thrown driver flops, never spasms.
 *
 * - No part spins faster than a flailing person can: a thin arm has almost no inertia about its own length, so the
 *   joints' small corrections can wind it up to a blur; held under SPIN radians a second, every part flops instead.
 * - No part flies off from the rest of the body faster than APART metres a second: a joint stretched (a fling, a
 *   hard knock on one limb) snaps back in a single violent step, and the snap kicks the next joint, and the next --
 *   the jitter. Each part's speed is held within APART of the whole body's (the mean of its parts), so a stretched
 *   joint closes over a few ticks instead.
 *
 * The parts of one ragdoll never collide with one another (`physics.json`: Ragdoll passes through Ragdoll): a thigh
 * pressed against the other at the hips, or an arm against the head, fought every step.
 */
import { Hierarchy, RigidBody, type World } from '@vibe/engine';
import { RagdollBone } from '../components.ts';

/** Radians a second: a limb whipping round fast, but never a propeller. */
const SPIN = 25;
/** Metres a second a part may move apart from (or into) the rest of its body. */
const APART = 14;
/** Ragdolls at once this tick, at most, that are held together (more are only held to SPIN). */
const MOST = 8;

/** Each ragdoll's parts this tick: its root, how many, and their summed velocity. */
const roots = new Int32Array(MOST);
const parts = new Int32Array(MOST);
const sumX = new Float32Array(MOST);
const sumY = new Float32Array(MOST);
const sumZ = new Float32Array(MOST);

export function ragdollLimit(world: World): void {
  world.system({
    name: 'ragdollLimit',
    rate: 60,
    with: [RagdollBone],
    read: [Hierarchy],
    write: [RigidBody],
    update({ members, count }, [tree], [rb]) {
      // The whole of each body: its parts' mean velocity.
      let bodies = 0;
      for (let n = 0; n < count; n++) {
        const e = members[n];
        const root = tree.parent[e];
        let b = 0;
        while (b < bodies && roots[b] !== root) b++;
        if (b === bodies) {
          if (bodies === MOST) continue;
          roots[b] = root;
          parts[b] = 0;
          sumX[b] = sumY[b] = sumZ[b] = 0;
          bodies++;
        }
        parts[b]++;
        sumX[b] += rb.velocityX[e];
        sumY[b] += rb.velocityY[e];
        sumZ[b] += rb.velocityZ[e];
      }
      for (let n = 0; n < count; n++) {
        const e = members[n];
        const wx = rb.angularVelocityX[e], wy = rb.angularVelocityY[e], wz = rb.angularVelocityZ[e];
        const w = Math.sqrt(wx * wx + wy * wy + wz * wz);
        if (w > SPIN) {
          const k = SPIN / w;
          rb.angularVelocityX[e] = wx * k;
          rb.angularVelocityY[e] = wy * k;
          rb.angularVelocityZ[e] = wz * k;
        }
        const root = tree.parent[e];
        let b = 0;
        while (b < bodies && roots[b] !== root) b++;
        if (b === bodies || parts[b] < 2) continue;
        const mx = sumX[b] / parts[b], my = sumY[b] / parts[b], mz = sumZ[b] / parts[b];
        const dx = rb.velocityX[e] - mx, dy = rb.velocityY[e] - my, dz = rb.velocityZ[e] - mz;
        const d = Math.sqrt(dx * dx + dy * dy + dz * dz);
        if (d <= APART) continue;
        const k = APART / d;
        rb.velocityX[e] = mx + dx * k;
        rb.velocityY[e] = my + dy * k;
        rb.velocityZ[e] = mz + dz * k;
      }
    },
  });
}
