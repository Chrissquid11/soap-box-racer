/**
 * steerLook, 60 Hz, late: the kart's steering -- rope reins, a go-kart wheel, bike handlebars -- drawn in the
 * driver's hands, tipped back toward them by its part's `tilt` and turned about its own column by the wheels'
 * angle times its `turns` (a go-kart wheel turns three times as far as the wheels it steers). `assemble` gives
 * it its model and place; this its turn.
 */
import { Hierarchy, optional, Transform, type World } from '@vibe/engine';
import { STEERING } from '../build.ts';
import { Build, Kart, SteeringLook } from '../components.ts';

/** Each steering part's tilt, half of it in radians, as its sine and cosine: worked out once. */
const TILT_S = STEERING.map((s) => Math.sin((s.tilt * Math.PI) / 360));
const TILT_C = STEERING.map((s) => Math.cos((s.tilt * Math.PI) / 360));

export function steerLook(world: World): void {
  world.system({
    name: 'steerLook',
    rate: 60,
    with: [SteeringLook],
    read: [Hierarchy, optional(Kart), optional(Build)],
    write: [Transform],
    lateUpdate({ members, count, has }, [tree, kart, build], [at]) {
      for (let n = 0; n < count; n++) {
        const e = members[n];
        const k = tree.parent[e];
        if (k === 0 || !has(k, Kart) || !has(k, Build)) continue;
        const i = Math.min(build.steering[k], STEERING.length - 1);
        // Tipped about x, then turned about its own column: q = tilt × turn.
        const sx = TILT_S[i]!, cx = TILT_C[i]!;
        const half = (kart.steer[k] * STEERING[i]!.turns) / 2;
        const sy = Math.sin(half), cy = Math.cos(half);
        at.qx[e] = sx * cy;
        at.qy[e] = cx * sy;
        at.qz[e] = sx * sy;
        at.qw[e] = cx * cy;
      }
    },
  });
}
