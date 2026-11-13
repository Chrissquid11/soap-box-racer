/**
 * wheelLook, 60 Hz, late: each wheel drawn where its spring has it, turned as it is steered and
 * spinning as it rolls, and its spring (`Spring`, a sibling at the same corner) stretched from the
 * chassis down to it -- squashed on a landing, long in the air, hanging loose once its wheel is gone. Each leans in
 * from its hub to the edge of the chassis (or the body that is the whole kart), so it is seen to hold it up.
 * Its parent kart's numbers place them; the wheel's own (`vehicle`'s) turn it.
 */
import { BoxCollider, Hierarchy, optional, Transform, type World } from '@vibe/engine';
import { BODY, WHEELS } from '../build.ts';
import { Build, Corner, Kart, Spring, SpringMount, Wheel } from '../components.ts';

/** How far inboard of its wheel a spring stands, metres, and how far up into the chassis it reaches. */
const INBOARD = 0.1;
/** Inside a body that is the whole kart (`cover`), the spring stands close in by its wheel: outside the body, in sight. */
const INBOARD_COVERED = 0.045;
const INTO = 0.15;
/** The shortest a spring is drawn, metres: stiff suspension still shows its spring beside the wheel. */
const SHORTEST = 0.22;
/** How thick a spring is drawn, a share of its model: a little slighter than the model is made. */
const GIRTH = 0.7;
/** How far in from the side of the kart's box a spring's top is mounted, metres. */
const MOUNT_IN = 0.05;
/** A caster's fork (`karts/parts#caster_fork`, at the wheel's own size): its stem's top this far over the hub, and the
 * swivel this far ahead of it -- the spring comes straight down onto the stem, the wheel trailing behind. */
const CASTER_TOP = 0.235;
const CASTER_AHEAD = 0.035;

export function wheelLook(world: World): void {
  world.system({
    name: 'wheelLook',
    rate: 60,
    read: [Wheel, Hierarchy, optional(Kart), optional(Spring), optional(Build), optional(BoxCollider), optional(SpringMount)],
    write: [Transform],
    lateUpdate({ members, count, has }, [wheel, tree, kart, spring, build, box, mount], [at]) {
      for (let n = 0; n < count; n++) {
        const e = members[n];
        const k = tree.parent[e];
        if (k === 0 || !has(k, Kart)) continue;
        const corner = wheel.corner[e];
        const left = corner === Corner.fl || corner === Corner.rl;
        const front = corner === Corner.fl || corner === Corner.fr;
        const side = left ? 1 : -1;
        const z = (front ? 1 : -1) * kart.halfBase[k];
        const covered = has(k, Build) && BODY[Math.min(build.body[k], BODY.length - 1)]!.cover === true;
        // Casters (`WheelPart.caster`): held from above in a fork, the spring straight over the wheel onto its stem.
        const caster = has(k, Build) && WHEELS[Math.min(build.wheels[k], WHEELS.length - 1)]!.caster === true;
        const inboard = caster ? 0 : covered ? INBOARD_COVERED : INBOARD;
        const grow = at.sx[e];
        const hub = -kart.halfHeight[k] - kart.travel[k] + (wheel.attached[e] ? wheel.compression[e] : 0);
        // Where the spring's foot is: the hub, or a caster's stem top over it, ahead of it.
        const foot = caster ? hub + CASTER_TOP * grow : hub;
        const footZ = caster ? CASTER_AHEAD * grow : 0;
        if (wheel.attached[e]) {
          at.px[e] = side * kart.halfTrack[k];
          at.py[e] = hub;
          at.pz[e] = z;
          // Steered about y, then rolled about x: q = yaw × spin.
          const yh = wheel.angle[e] / 2;
          const sh = (wheel.spin[e] % (2 * Math.PI)) / 2;
          const sy = Math.sin(yh), cy = Math.cos(yh);
          const sx = Math.sin(sh), cx = Math.cos(sh);
          at.qx[e] = cy * sx;
          at.qy[e] = sy * cx;
          at.qz[e] = -sy * sx;
          at.qw[e] = cy * cx;
        }
        // Its spring: from up inside the chassis down to the hub, each suspension's own model (`assemble`).
        for (let c = tree.firstChild[k]; c !== 0; c = tree.nextSibling[c]) {
          if (!has(c, Spring) || spring.corner[c] !== corner) continue;
          const top = Math.max(foot + SHORTEST, -kart.halfHeight[k] + Math.min(INTO, kart.halfHeight[k]));
          // From its foot (the hub, or a caster's stem) up and in to its mount at the side of the kart's box (never
          // leaning outward; a caster's straight up).
          const footX = Math.max(0.05, kart.halfTrack[k] - inboard);
          const edge = has(k, BoxCollider) ? box.sizeX[k] / 2 - MOUNT_IN : footX;
          const topX = caster ? footX : Math.max(0.05, Math.min(footX, edge));
          const dx = side * (topX - footX), dy = top - foot;
          const length = Math.sqrt(dx * dx + dy * dy);
          at.px[c] = side * (footX + topX) / 2;
          at.py[c] = (top + foot) / 2;
          at.pz[c] = z + footZ;
          // Its model stands along y: turned about z to lie along hub → mount.
          const half = Math.atan2(-dx, dy) / 2;
          at.qx[c] = 0;
          at.qy[c] = 0;
          at.qz[c] = Math.sin(half);
          at.qw[c] = Math.cos(half);
          at.sx[c] = GIRTH;
          at.sy[c] = length;
          at.sz[c] = GIRTH;
        }
        // What it is fixed to: a stub axle from its foot out into the hub, and -- with the chassis hidden under a body
        // that is the whole kart -- half a cross beam from its top in to the middle (the other side's half meets it).
        for (let c = tree.firstChild[k]; c !== 0; c = tree.nextSibling[c]) {
          if (!has(c, SpringMount) || mount.corner[c] !== corner) continue;
          const footX = Math.max(0.05, kart.halfTrack[k] - inboard);
          at.pz[c] = z + (caster && !mount.stub[c] ? footZ : 0);
          if (mount.stub[c] && caster) {
            // The caster's fork: at the hub, at the wheel's size, turned as the wheel steers (never spinning with it).
            at.px[c] = side * kart.halfTrack[k];
            at.py[c] = hub;
            const yh = (wheel.attached[e] ? wheel.angle[e] : 0) / 2;
            at.qx[c] = 0;
            at.qy[c] = Math.sin(yh);
            at.qz[c] = 0;
            at.qw[c] = Math.cos(yh);
            at.sx[c] = at.sy[c] = at.sz[c] = grow;
          } else if (mount.stub[c]) {
            at.qx[c] = at.qy[c] = at.qz[c] = 0;
            at.qw[c] = 1;
            const reach = Math.max(0.04, kart.halfTrack[k] - footX + 0.03);
            at.px[c] = side * (footX - 0.03 + reach / 2);
            at.py[c] = hub;
            at.sx[c] = reach;
            at.sy[c] = at.sz[c] = 1;
          } else {
            const top = Math.max(hub + SHORTEST, -kart.halfHeight[k] + Math.min(INTO, kart.halfHeight[k]));
            const edge = has(k, BoxCollider) ? box.sizeX[k] / 2 - MOUNT_IN : footX;
            const topX = caster ? footX : Math.max(0.05, Math.min(footX, edge));
            at.px[c] = side * topX / 2;
            at.py[c] = caster ? Math.max(foot + SHORTEST, -kart.halfHeight[k] + Math.min(INTO, kart.halfHeight[k])) : top;
            // Only where nothing else holds it up: an open chassis has its own frame there -- but a caster's spring stands
            // out over its wheel, past the chassis's side, so it hangs from the beam too.
            const beam = covered || caster;
            at.sx[c] = beam ? topX + 0.02 : 0.0001;
            at.sy[c] = at.sz[c] = beam ? 1.4 : 0.0001;
          }
        }
      }
    },
  });
}
