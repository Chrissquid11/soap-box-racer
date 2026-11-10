/**
 * chaseCam, 60 Hz, late: the camera chasing its kart. Racing, it swings round behind the way the kart
 * is going (its velocity, or its nose when slow), catching up `follow` times a second, and looks down
 * at it. In the garage it circles the kart slowly, close, for the builder. Late, after the step, so it
 * follows this tick's kart.
 */
import { Camera, NONE, optional, physicsOf, RayHit, Transform, WorldTransform, type World } from '@vibe/engine';
import { ChaseCam, FLYOVER, Kart, Phase } from '../components.ts';
import { TRACKS } from '../courses.ts';
import { rotate, v3, wrap } from '../kart-math.ts';
import { lowEnd } from '../device.ts';

/** On a phone (`lowEnd`: a small screen) the run's camera this much nearer the kart, and lower with it, so the kart
 * reads big. (The garage's orbit keeps its own distance.) */
const PHONE_NEAR = 0.6;
/** ... and its lens: this many degrees at rest (not FOV, nor widened for a tall screen), and this share of the
 * widening with speed. */
const PHONE_FOV = 50;
const PHONE_WIDEN = 0.5;
/** ... after the push off: from this many seconds after GO (the teammate's shove, `pusher`'s PUSH_FOR), over this many. */
const PHONE_AFTER = 1.6;
const PHONE_EASE_IN = 1.2;

const nose = v3();
/** The garage's slow circle, radians a second, and how close it comes. */
const ORBIT = 0.35;
/** Turning it by hand: radians a pixel dragged, radians a second with Q or E held, and the seconds left alone before it
 * circles on by itself (`ChaseCam.dragX` and `idle` keep track). */
const DRAG_TURN = 0.008;
const KEY_TURN = 1.8;
const ORBIT_RESUME = 3;
const ORBIT_DISTANCE = 4.2;
const ORBIT_HEIGHT = 1.5;
/** Racing and moving, the camera comes this share of its distance and of its height nearer the kart: all of it from
 * NEAR_FROM + NEAR_RAMP m/s, none below NEAR_FROM (eased in and out as it chases). */
const NEAR = 0.78;
/** Racing (on the line and away), the camera this share of its ChaseCam distance behind and of its height above:
 * nearer, and looking further down on the kart. */
const RACE_CLOSE = 0.88;
const RACE_HIGH = 1.1;
const NEAR_LOW = 0.86;
const NEAR_FROM = 1.5;
const NEAR_RAMP = 4;
/** Metres off the kart past which the camera jumps to it rather than glide. */
const SNAP = 30;
/** The crash cam: how far round from behind it swings (side on), how close and how high, and how fast (a share a game second). */
const CRASH_SIDE = Math.PI * 0.55;
const CRASH_DISTANCE = 4.6;
const CRASH_HEIGHT = 1.3;
const CRASH_SWING = 10;
/** Racing, it looks this far ahead of the kart along the way it is going (and its `look` above the road there): the
 * road coming shows, the kart low in the frame -- easier to steer by. */
const LOOK_AHEAD = 2.2;
/** The view's angle (degrees) at rest, and how much wider at full speed: from FOV_FROM m/s, all of it by FOV_FULL;
 * eased in at FOV_EASE a second. */
const FOV = 66;
const FOV_WIDEN = 12;
const FOV_FROM = 6;
const FOV_FULL = 20;
const FOV_EASE = 2.5;
/** A tall screen (a phone held upright) sees a narrow slice across: the view this many degrees wider for each unit
 * the screen is narrower than square, so the road either side still shows. A wide screen (a PC) is as it was. */
const TALL_WIDEN = 26;
function tallWiden(): number {
  const w = typeof innerWidth === 'number' ? innerWidth : 0, h = typeof innerHeight === 'number' ? innerHeight : 0;
  return w > 0 && h > w ? (1 - w / h) * TALL_WIDEN : 0;
}
/** Metres the camera shakes, at full shake. */
const SHAKE = 0.26;
/** The least it keeps above the ground under it, and short of anything between it and the kart, metres. */
const CLEAR = 0.7;
const STANDOFF = 0.35;
/** How far above itself it starts looking down for the ground: a little -- not so far that it finds what hangs overhead
 * (the start and finish arches' banners), which lifted it up onto them. A hillside higher than that is between it and
 * the kart, and the sight line below brings it in short of it. */
const LOOK_DOWN_FROM = 1.2;
/** How fast it comes in short of something in the way, and goes back out once clear: a share a second. */
const PULL_IN = 12;
const PULL_OUT = 2.5;

/** The flyover: metres above the road, samples behind the point it is over, and samples ahead it looks. */
const FLY_HIGH = 9;
const FLY_LOOK = 40;

const hit = new RayHit();

export function chaseCam(world: World): void {
  const physics = physicsOf(world);
  const ground = physics.layers('Default', 'Ramps');
  world.system({
    name: 'chaseCam',
    rate: 60,
    read: [optional(WorldTransform), optional(Kart)],
    write: [ChaseCam, Transform, optional(Camera)],
    lateUpdate({ members, count, dt, time, deref, has, input }, [where, kart], [cam, at, lens]) {
      for (let n = 0; n < count; n++) {
        const e = members[n];
        const k = deref(cam.target[e]);
        if (k === NONE) continue;
        const kx = where.px[k], ky = where.py[k], kz = where.pz[k];
        const garage = kart.phase[k] === Phase.garage;

        // The flyover before a run: high over the road from the start down to the finish, eased, looking on down it.
        // At its end the chase picks up from the kart at once (far off: `snap`).
        const course = kart.course[k];
        if (kart.flyover[k] > 0 && course < TRACKS.length) {
          const t = TRACKS[course]!;
          const a = 1 - kart.flyover[k] / FLYOVER;
          const s = a * a * (3 - 2 * a);
          const p = Math.min(t.samples - 2, t.start + (t.finish - t.start) * s);
          const i = Math.floor(p), f = p - i;
          const q = Math.min(t.samples - 2, p + FLY_LOOK);
          const j = Math.floor(q), g = q - j;
          const ox = t.sx[i]! + (t.sx[i + 1]! - t.sx[i]!) * f;
          const oy = t.sy[i]! + (t.sy[i + 1]! - t.sy[i]!) * f + FLY_HIGH;
          const oz = t.sz[i]! + (t.sz[i + 1]! - t.sz[i]!) * f;
          const dx = t.sx[j]! + (t.sx[j + 1]! - t.sx[j]!) * g - ox;
          const dy = t.sy[j]! + (t.sy[j + 1]! - t.sy[j]!) * g - oy;
          const dz = t.sz[j]! + (t.sz[j + 1]! - t.sz[j]!) * g - oz;
          at.px[e] = ox;
          at.py[e] = oy;
          at.pz[e] = oz;
          const turn = Math.atan2(-dx, -dz);
          const pitch = Math.atan2(dy, Math.sqrt(dx * dx + dz * dz)) / 2;
          const sy = Math.sin(turn / 2), cy = Math.cos(turn / 2);
          const sx = Math.sin(pitch), cx = Math.cos(pitch);
          at.qx[e] = cy * sx;
          at.qy[e] = sy * cx;
          at.qz[e] = -sy * sx;
          at.qw[e] = cy * cx;
          if (has(e, Camera)) lens.fov[e] = FOV + tallWiden();
          // Picked up afresh behind the kart once it ends.
          cam.ready[e] = 0;
          continue;
        }

        // Which way it is going: its velocity across the ground once moving, else its nose.
        rotate(where.qx[k], where.qy[k], where.qz[k], where.qw[k], 0, 0, 1, nose);
        let heading = Math.atan2(nose.x, nose.z);
        const vx = kart.lastVX[k], vz = kart.lastVZ[k];
        if (vx * vx + vz * vz > 9) heading = Math.atan2(vx, vz);

        // First sight, or the kart far off all at once (a new course, a restart, set back on the line): there at once.
        const far = (kx - cam.x[e]) ** 2 + (ky - cam.y[e]) ** 2 + (kz - cam.z[e]) ** 2 > SNAP * SNAP;
        if (!cam.ready[e] || far) {
          cam.ready[e] = 1;
          cam.keep[e] = 1;
          cam.yaw[e] = heading;
          cam.x[e] = kx;
          cam.y[e] = ky + cam.height[e];
          cam.z[e] = kz;
        }
        // On a phone, nearer -- but not through the push off (the countdown, and the teammate's shove after GO): there
        // the whole start as on any screen, then eased in over PHONE_EASE_IN seconds.
        const phoneIn = !lowEnd() || kart.phase[k] === Phase.countdown ? 0
          : kart.phase[k] === Phase.racing ? Math.min(1, Math.max(0, (kart.clock[k] - PHONE_AFTER) / PHONE_EASE_IN)) : 1;
        const near = 1 + (PHONE_NEAR - 1) * phoneIn;
        let distance = cam.distance[e] * near;
        let height = cam.height[e] * near;
        let ease = Math.min(1, cam.follow[e] * dt);
        if (garage) {
          // Turned by hand: dragged round (the main button held on the view, not on a panel: the UI takes those), or
          // Q and E; left alone ORBIT_RESUME seconds, it circles on by itself again.
          const keys = (input.down('KeyE') ? 1 : 0) - (input.down('KeyQ') ? 1 : 0);
          if (input.down('Pointer0')) {
            const x = input.pointer.x;
            if (cam.dragX[e] >= 0) cam.yaw[e] = wrap(cam.yaw[e] - (x - cam.dragX[e]) * DRAG_TURN);
            cam.dragX[e] = x;
            cam.idle[e] = 0;
          } else cam.dragX[e] = -1;
          if (keys !== 0) {
            cam.yaw[e] = wrap(cam.yaw[e] + keys * KEY_TURN * dt);
            cam.idle[e] = 0;
          }
          cam.idle[e] += dt;
          if (cam.idle[e] > ORBIT_RESUME) cam.yaw[e] = wrap(cam.yaw[e] + ORBIT * dt);
          distance = ORBIT_DISTANCE;
          height = ORBIT_HEIGHT;
          ease = Math.min(1, 3 * dt);
        } else if (kart.slowFor[k] > 0) {
          // The crash cam (`slowmo`): swung round to watch it side on, close, low -- quickly, as game time is slow.
          const side = wrap(heading + CRASH_SIDE);
          cam.yaw[e] = wrap(cam.yaw[e] + wrap(side - cam.yaw[e]) * Math.min(1, CRASH_SWING * dt));
          distance = CRASH_DISTANCE;
          height = CRASH_HEIGHT;
          ease = Math.min(1, CRASH_SWING * dt);
        } else {
          cam.yaw[e] = wrap(cam.yaw[e] + wrap(heading - cam.yaw[e]) * Math.min(1, cam.follow[e] * 0.8 * dt));
          // Racing, closer in than its ChaseCam says and a little higher: looking down on the kart (RACE_CLOSE, RACE_HIGH).
          distance *= RACE_CLOSE;
          height *= RACE_HIGH;
          // Once it is rolling, a little nearer and lower: on the line the whole kart and the road ahead, away the kart.
          const moving = Math.min(1, Math.max(0, (kart.speed[k] - NEAR_FROM) / NEAR_RAMP));
          distance *= 1 - (1 - NEAR) * moving;
          height *= 1 - (1 - NEAR_LOW) * moving;
        }
        const yaw = cam.yaw[e];
        const tx = kx - Math.sin(yaw) * distance;
        const ty = ky + height;
        const tz = kz - Math.cos(yaw) * distance;
        cam.x[e] += (tx - cam.x[e]) * ease;
        cam.y[e] += (ty - cam.y[e]) * ease;
        cam.z[e] += (tz - cam.z[e]) * ease;
        let ox = cam.x[e], oy = cam.y[e], oz = cam.z[e];
        // Never in the ground. (Not in the garage: the course is out of sight there, its room round the kart instead.)
        if (!garage) {
          // Above the ground under it: the hill behind a kart going downhill lifts it, and it stays lifted.
          const top = oy + LOOK_DOWN_FROM;
          if (physics.raycast(ox, top, oz, 0, -1, 0, top - oy + 60, ground, hit) && hit.y + CLEAR > oy) {
            oy = cam.y[e] = hit.y + CLEAR;
          }
          // Nothing between it and the kart: a bank, a hairpin's hillside, a wall -- it comes in short of it.
          const fx = kx, fy = ky + cam.look[e], fz = kz;
          const lx = ox - fx, ly = oy - fy, lz = oz - fz;
          const reach = Math.sqrt(lx * lx + ly * ly + lz * lz);
          let want = 1;
          if (reach > 0.01 && physics.raycast(fx, fy, fz, lx, ly, lz, reach, ground, hit)) {
            want = Math.max(0, hit.distance - STANDOFF) / reach;
          }
          // Eased, not jumped to: in quickly (it must not sit in a wall for long), back out slowly.
          const rate = want < cam.keep[e] ? PULL_IN : PULL_OUT;
          cam.keep[e] += (want - cam.keep[e]) * Math.min(1, rate * dt);
          const keep = Math.min(1, cam.keep[e]);
          if (keep < 0.999) {
            ox = fx + lx * keep;
            oy = fy + ly * keep;
            oz = fz + lz * keep;
          }
        }
        // Shaken by a hard landing or a crash (`trails`, `slowmo`): a judder, easing out.
        const shake = kart.shake[k] * SHAKE;
        if (shake > 0) {
          ox += Math.sin(time * 47) * shake;
          oy += Math.sin(time * 61 + 1) * shake * 0.6;
          oz += Math.cos(time * 53) * shake;
        }
        at.px[e] = ox;
        at.py[e] = oy;
        at.pz[e] = oz;
        // The view widens with speed (none in the garage): the road rushes at you.
        if (has(e, Camera)) {
          const fast = garage ? 0 : Math.min(1, Math.max(0, (kart.speed[k] - FOV_FROM) / (FOV_FULL - FOV_FROM)));
          // On a phone, in the run: a narrower lens, not widened for a tall screen, and less with speed -- the kart big.
          const usual = FOV + FOV_WIDEN * fast + tallWiden();
          const phone = PHONE_FOV + FOV_WIDEN * PHONE_WIDEN * fast;
          const want = garage ? usual : usual + (phone - usual) * phoneIn;
          lens.fov[e] += (want - lens.fov[e]) * Math.min(1, dt * FOV_EASE);
        }

        // Look at the kart -- racing, a little ahead of it: a camera looks down its -z, so turned by atan2(-dx, -dz),
        // then pitched.
        const ahead = garage || kart.slowFor[k] > 0 ? 0 : LOOK_AHEAD;
        const dx = kx + Math.sin(yaw) * ahead - ox;
        const dy = ky + cam.look[e] - oy;
        const dz = kz + Math.cos(yaw) * ahead - oz;
        const turn = Math.atan2(-dx, -dz);
        const pitch = Math.atan2(dy, Math.sqrt(dx * dx + dz * dz)) / 2;
        const sy = Math.sin(turn / 2), cy = Math.cos(turn / 2);
        const sx = Math.sin(pitch), cx = Math.cos(pitch);
        at.qx[e] = cy * sx;
        at.qy[e] = sy * cx;
        at.qz[e] = -sy * sx;
        at.qw[e] = cy * cx;
      }
    },
  });
}
