/**
 * props, 60 Hz: the course's hazards remember where they stood, and every new run (`RaceReset`) puts
 * them back, still, and sweeps away the debris -- lost wheels, bodywork, thrown drivers.
 */
import { Hidden, Hierarchy, optional, RigidBody, Transform, WorldTransform, type World } from '@vibe/engine';
import { Breakable, Debris, Kart, Prop, RaceReset } from '../components.ts';
import { burst } from '../burst.ts';

/** A burst bale: the straw it flies apart into, how many bits and how hard, and where it is kept out of the way till the next run (under its home). */
const STRAW = [0xe0b24c, 0xc8943a, 0xf0cc6c, 0xb07a26];
const STRAW_BITS = 50;
const STRAW_BURST = 5;
/** How far the straw starts spread (metres: the whole bale), and how big each bit. */
const STRAW_SPREAD = 0.75;
const STRAW_SIZE = 1.6;
const PARKED = 10000;
/** A prop further than this from where it stood (metres, or as much turned) has been knocked: put back for a new run. */
const MOVED = 0.01;

export function props(world: World): void {
  const resets = world.events(RaceReset);
  world.system({
    name: 'props',
    rate: 60,
    after: ['impacts'],
    write: [Prop, Transform, RigidBody, optional(Breakable)],
    update(ctx, _read, [prop, at, rb, breakable]) {
      const { members, count, cmd, has } = ctx;
      let reset = false;
      for (let i = resets.begin(ctx); i < resets.end; i++) reset = true;
      for (let n = 0; n < count; n++) {
        const e = members[n];
        if (!prop.placed[e]) {
          prop.placed[e] = 1;
          prop.homeX[e] = at.px[e];
          prop.homeY[e] = at.py[e];
          prop.homeZ[e] = at.pz[e];
          prop.homeQX[e] = at.qx[e];
          prop.homeQY[e] = at.qy[e];
          prop.homeQZ[e] = at.qz[e];
          prop.homeQW[e] = at.qw[e];
        } else if (reset) {
          // Never knocked since it was set down: left as it is, asleep -- waking every prop on the course for nothing
          // costs the physics far more than the frame has (hundreds of bales and barriers on the first course).
          const moved = Math.abs(at.px[e] - prop.homeX[e]) + Math.abs(at.py[e] - prop.homeY[e]) + Math.abs(at.pz[e] - prop.homeZ[e]) > MOVED
            || Math.abs(at.qx[e] - prop.homeQX[e]) + Math.abs(at.qy[e] - prop.homeQY[e]) + Math.abs(at.qz[e] - prop.homeQZ[e]) > MOVED;
          if (!moved && !(has(e, Breakable) && breakable.broken[e])) continue;
          at.px[e] = prop.homeX[e];
          at.py[e] = prop.homeY[e];
          at.pz[e] = prop.homeZ[e];
          at.qx[e] = prop.homeQX[e];
          at.qy[e] = prop.homeQY[e];
          at.qz[e] = prop.homeQZ[e];
          at.qw[e] = prop.homeQW[e];
          rb.velocityX[e] = rb.velocityY[e] = rb.velocityZ[e] = 0;
          rb.angularVelocityX[e] = rb.angularVelocityY[e] = rb.angularVelocityZ[e] = 0;
          // Back where it stood, still: asleep again, as it began.
          rb.sleeping[e] = 1;
          if (has(e, Breakable)) {
            breakable.broken[e] = 0;
            breakable.struck[e] = 0;
            if (has(e, Hidden)) cmd.remove(e, Hidden);
          }
          continue;
        }
        if (!has(e, Breakable)) continue;
        // Hit hard enough: it bursts into straw, flung on the way the kart was going, and is gone till the next run --
        // out of sight and held still far under where it stood, its collider with it.
        if (!breakable.broken[e] && breakable.struck[e] >= breakable.strength[e]) {
          breakable.broken[e] = 1;
          if (!has(e, Hidden)) cmd.add(e, Hidden);
          burst(cmd, {
            x: at.px[e], y: at.py[e] + 0.2, z: at.pz[e], spread: STRAW_SPREAD,
            vx: rb.velocityX[e], vy: rb.velocityY[e], vz: rb.velocityZ[e],
            power: STRAW_BURST + breakable.struck[e] * 0.45, count: STRAW_BITS,
            colours: STRAW, size: STRAW_SIZE, seed: e, bolts: false,
          });
        }
        breakable.struck[e] = 0;
        if (breakable.broken[e]) {
          at.px[e] = prop.homeX[e];
          at.py[e] = prop.homeY[e] - PARKED;
          at.pz[e] = prop.homeZ[e];
          rb.velocityX[e] = rb.velocityY[e] = rb.velocityZ[e] = 0;
          rb.angularVelocityX[e] = rb.angularVelocityY[e] = rb.angularVelocityZ[e] = 0;
        }
      }
    },
  });
}

/** Below this height a piece has fallen off the world: the valley floor is at -20. */
const LOST = -40;
/** A loose piece (one with a body of its own: a shard, a splinter, a plank, a wheel -- not a thrown driver) this many
 * metres from the kart is long out of sight behind it: cleared, so a long run's knocks never pile up in the physics. */
const LEFT_BEHIND = 80;

/** sweep, 60 Hz: on a new run, what came off is cleared away -- each piece's root, which takes the rest -- and in a
 * run, what the kart has left far behind it. */
export function sweep(world: World): void {
  const resets = world.events(RaceReset);
  const karts = world.query({ with: [Kart, WorldTransform] });
  world.system({
    name: 'sweep',
    rate: 60,
    with: [Debris],
    read: [Hierarchy, WorldTransform],
    update(ctx, [tree, where]) {
      let reset = false;
      for (let i = resets.begin(ctx); i < resets.end; i++) reset = true;
      const k = karts.count > 0 ? karts.members[0]! : 0;
      const kx = k !== 0 ? where.px[k]! : 0, kz = k !== 0 ? where.pz[k]! : 0;
      for (let n = 0; n < ctx.count; n++) {
        const e = ctx.members[n];
        if (tree.parent[e] !== 0) continue;
        // A piece that has fallen off the world goes too, whatever the run is doing; and a loose one left far behind.
        const far = k !== 0 && ctx.has(e, RigidBody) && (where.px[e] - kx) ** 2 + (where.pz[e] - kz) ** 2 > LEFT_BEHIND * LEFT_BEHIND;
        if (reset || where.py[e] < LOST || far) ctx.cmd.destroy(e);
      }
    },
  });
}
