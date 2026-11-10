/**
 * Small vector sums the kart's systems share, written into a caller's scratch (made once, at module
 * level) so a tick allocates nothing.
 */

export interface V3 {
  x: number;
  y: number;
  z: number;
}

export const v3 = (): V3 => ({ x: 0, y: 0, z: 0 });

/** `(x, y, z)` turned by the quaternion `(qx, qy, qz, qw)`, into `out`. */
export function rotate(qx: number, qy: number, qz: number, qw: number, x: number, y: number, z: number, out: V3): V3 {
  // t = 2 q × v; v' = v + w t + q × t
  const tx = 2 * (qy * z - qz * y);
  const ty = 2 * (qz * x - qx * z);
  const tz = 2 * (qx * y - qy * x);
  out.x = x + qw * tx + (qy * tz - qz * ty);
  out.y = y + qw * ty + (qz * tx - qx * tz);
  out.z = z + qw * tz + (qx * ty - qy * tx);
  return out;
}

/** `(x, y, z)` turned back by the quaternion: from the world into the body's own axes. */
export function unrotate(qx: number, qy: number, qz: number, qw: number, x: number, y: number, z: number, out: V3): V3 {
  return rotate(-qx, -qy, -qz, qw, x, y, z, out);
}

/** An angle brought into -π..π. */
export function wrap(a: number): number {
  while (a > Math.PI) a -= 2 * Math.PI;
  while (a < -Math.PI) a += 2 * Math.PI;
  return a;
}
