/**
 * A wheel coming off, as the garage built it: one loose wheel made where that wheel was mounted (its corner of the
 * track and the wheelbase the chassis' width and length set -- a wide chassis sheds from its widened mount), turned as
 * the kart was, at that end's size (the front and rear sizes), in its own model and tint, its collider the wheel's own
 * radius and width. Every place a wheel comes off (a knock, a wall, a landing, the shedding of a worn-out kart, the
 * wreck) makes it here, the same tick the wheel is hidden on the kart and stops counting for the driving
 * (`Wheel.attached` 0), so what you see go is what the handling loses.
 */
import { CylinderCollider, type Entity, NONE, Render, RigidBody, type SystemContext, Transform } from '@vibe/engine';
import { rotate, v3 } from './kart-math.ts';
import { LooseWheel } from './prefabs.ts';

type Cmd = SystemContext['cmd'];
type Arr = ArrayLike<number>;
/** The kart's and its wheels' places: the Transform store (the wheels' are on the kart, the kart's in the world). */
interface Places { px: Arr; py: Arr; pz: Arr; qx: Arr; qy: Arr; qz: Arr; qw: Arr; sx: Arr }
interface Looks { model: Arr; tint: Arr }
interface Wheels { radius: Arr }

/** A tyre's width as a share of its radius (as `build.ts` rates a kart's width), and a loose wheel's mass per metre of
 * radius, squared (kilograms: the pram wheel's 3 at 0.2 m, about). */
const TYRE_WIDE = 0.5;
const MASS_PER = 75;
const SPOT = v3();

/** Wheel `c` of kart `e`, off: a loose wheel in its place, its size and its colours, or NONE (the pool spent). Its
 * velocity and spin are the caller's (`cmd.init(loose, RigidBody)`), each the way that wheel was knocked off. */
export function dropWheel(cmd: Cmd, at: Places, look: Looks, wheel: Wheels, e: Entity, c: Entity): Entity {
  const loose = cmd.instantiate(LooseWheel);
  if (loose === NONE) return NONE;
  const qx = at.qx[e]!, qy = at.qy[e]!, qz = at.qz[e]!, qw = at.qw[e]!;
  rotate(qx, qy, qz, qw, at.px[c]!, at.py[c]!, at.pz[c]!, SPOT);
  const lat = cmd.init(loose, Transform);
  lat.px[loose] = at.px[e]! + SPOT.x;
  lat.py[loose] = at.py[e]! + SPOT.y;
  lat.pz[loose] = at.pz[e]! + SPOT.z;
  lat.qx[loose] = qx;
  lat.qy[loose] = qy;
  lat.qz[loose] = qz;
  lat.qw[loose] = qw;
  // The wheel's model drawn at the size it was on the kart; its collider in the model's own units (it scales with it).
  const grow = at.sx[c]! || 1;
  lat.sx[loose] = lat.sy[loose] = lat.sz[loose] = grow;
  const r = wheel.radius[c]! || 0.2;
  const shape = cmd.init(loose, CylinderCollider);
  shape.radius[loose] = r / grow;
  shape.height[loose] = Math.max(0.03, r * TYRE_WIDE) / grow;
  cmd.init(loose, RigidBody).mass[loose] = Math.max(0.5, MASS_PER * r * r);
  const view = cmd.init(loose, Render);
  view.model[loose] = look.model[c]!;
  view.tint[loose] = look.tint[c]!;
  return loose;
}
