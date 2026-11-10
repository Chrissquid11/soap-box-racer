/**
 * bonus, 60 Hz: the gold stars on the course (`course` lays them). Each spins and bobs where it hangs; driven through
 * with the driver aboard, it is gone in a burst of sparks and its points are the kart's style, shouted. A new run puts
 * every one back.
 */
import { Hidden, optional, Transform, type World } from '@vibe/engine';
import { Bonus, Kart, News, Phase } from '../components.ts';
import { sparks } from '../sparks.ts';

/** Metres from the kart's middle that collects one; how fast they spin (radians a second), how far and fast they bob. */
const REACH = 1.7;
const SPIN = 2.4;
const BOB = 0.14;
const BOB_RATE = 2.2;
/** The burst when one is collected: sparks, and how hard they fly. */
const BURST = 14;
const BURST_POWER = 0.9;

export function bonus(world: World): void {
  const karts = world.query({ with: [Kart, Transform] });
  world.system({
    name: 'bonus',
    rate: 60,
    after: ['race'],
    write: [Bonus, Transform, optional(Kart)],
    update({ members, count, time, cmd, has }, _read, [star, at, kart]) {
      if (karts.count === 0) return;
      const k = karts.members[0]!;
      const phase = kart.phase[k];
      const fresh = phase === Phase.garage || phase === Phase.countdown;
      const racing = phase === Phase.racing && !kart.ejected[k] && !kart.wrecked[k];
      const kx = at.px[k], ky = at.py[k], kz = at.pz[k];
      for (let n = 0; n < count; n++) {
        const e = members[n];
        if (!star.placed[e]) {
          star.placed[e] = 1;
          star.baseY[e] = at.py[e];
        }
        // A new run: every one back.
        if (fresh && star.taken[e]) {
          star.taken[e] = 0;
          if (has(e, Hidden)) cmd.remove(e, Hidden);
        }
        if (star.taken[e]) continue;
        const a = time * SPIN + e;
        at.qx[e] = 0;
        at.qy[e] = Math.sin(a / 2);
        at.qz[e] = 0;
        at.qw[e] = Math.cos(a / 2);
        at.py[e] = star.baseY[e] + Math.sin(time * BOB_RATE + e) * BOB;
        if (!racing) continue;
        const dx = at.px[e] - kx, dy = at.py[e] - ky, dz = at.pz[e] - kz;
        if (dx * dx + dy * dy + dz * dz > REACH * REACH) continue;
        star.taken[e] = 1;
        cmd.add(e, Hidden);
        kart.style[k] += star.value[e];
        // Two in the one tick: one piece of news, both stars' points.
        const again = kart.news[k] === News.bonus && kart.newsAt[k] === kart.clock[k];
        kart.news[k] = News.bonus;
        kart.newsValue[k] = (again ? kart.newsValue[k] : 0) + star.value[e];
        kart.newsX[k] = at.px[e];
        kart.newsY[k] = at.py[e];
        kart.newsZ[k] = at.pz[e];
        kart.newsAt[k] = kart.clock[k];
        sparks(cmd, at.px[e], at.py[e], at.pz[e], 0, 2, 0, BURST, BURST_POWER, e + Math.round(time * 60), at.py[e] - 1);
      }
    },
  });
}
