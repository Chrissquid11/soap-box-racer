/**
 * spin, 60 Hz: turns everything with a `Spin` about its own `axis`, `speed` radians a second. A 60 Hz
 * system is the one that writes `Transform`; one system a file, registered in `systems.ts`. An enum
 * is compared by its constants: `turn.axis[e] === Axis.x`.
 */
import { Transform, type World } from '@vibe/engine';
import { Axis, Spin } from '../components.ts';

export function spin(world: World): void {
  world.system({
    name: 'spin',
    rate: 60,
    read: [Spin],
    write: [Transform],
    update({ members, count, dt }, [turn], [at]) {
      for (let n = 0; n < count; n++) {
        const e = members[n];
        // The turn this tick, a rotation about its axis, applied after the one it has: the quaternion
        // (x, y, z, w) times (ax s, ay s, az s, c) for half the angle.
        const half = (turn.speed[e] * dt) / 2;
        const s = Math.sin(half);
        const c = Math.cos(half);
        const axis = turn.axis[e];
        const ax = axis === Axis.x ? s : 0;
        const ay = axis === Axis.y ? s : 0;
        const az = axis === Axis.z ? s : 0;
        const x = at.qx[e];
        const y = at.qy[e];
        const z = at.qz[e];
        const w = at.qw[e];
        const qx = w * ax + x * c + y * az - z * ay;
        const qy = w * ay - x * az + y * c + z * ax;
        const qz = w * az + x * ay - y * ax + z * c;
        const qw = w * c - x * ax - y * ay - z * az;
        // Kept unit length: f32 rounding would otherwise drift it over hours of turning.
        const length = Math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw);
        at.qx[e] = qx / length;
        at.qy[e] = qy / length;
        at.qz[e] = qz / length;
        at.qw[e] = qw / length;
      }
    },
  });
}
