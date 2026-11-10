/**
 * slowmo, 60 Hz: the crash cam. A big crash -- the kart wrecked, its bodywork knocked off or broken up, its driver
 * thrown out, or the kart rolled over -- and the game drops into slow motion for a moment (`SLOW_FOR` game seconds
 * at `SLOW` speed: a couple of seconds of real time) while `chaseCam` swings round to watch it side on and the HUD
 * letterboxes the view. Each crash sets it off once; another inside the slow motion runs it on. Out of a run (the
 * garage, a new run) the game is at full speed again.
 */
import { type World } from '@vibe/engine';
import { Kart, Phase } from '../components.ts';

/** How slow, and for how many game seconds (real seconds over SLOW). */
export const SLOW = 0.25;
const SLOW_FOR = 0.6;
/** Game seconds after one crash cam before another may start (one rolling crash is one slow motion, not five). */
const QUIET = 2.5;
/** The impact freeze: its first tick (FREEZE game seconds) run at FREEZE_SCALE -- a beat (about a tenth of a second,
 * real time), not a stall that reads as the game stuttering. */
const FREEZE = 0.02;
const FREEZE_SCALE = 0.15;

export function slowmo(world: World): void {
  world.system({
    name: 'slowmo',
    rate: 60,
    after: ['wear', 'impacts', 'driver'],
    write: [Kart],
    update({ members, count, dt }, _read, [kart]) {
      let slow = false;
      let frozen = false;
      for (let n = 0; n < count; n++) {
        const e = members[n];
        const running = kart.phase[e] === Phase.racing || kart.phase[e] === Phase.finished || kart.phase[e] === Phase.over;
        // The big crashes so far this run: a new one is a crash to watch.
        const crashes = kart.wrecked[e] * 8 + kart.bodyLost[e] + kart.ejections[e] + kart.rollovers[e];
        if (!running || crashes < kart.crashes[e]) {
          // A new run (its counts back to nought), or out of one: no slow motion.
          kart.crashes[e] = crashes;
          kart.slowFor[e] = 0;
          continue;
        }
        if (crashes > kart.crashes[e]) {
          kart.crashes[e] = crashes;
          if (kart.slowFor[e] > 0 || kart.clock[e] - kart.slowAt[e] > QUIET) {
            if (kart.slowFor[e] <= 0) kart.slowAt[e] = kart.clock[e];
            kart.slowFor[e] = SLOW_FOR;
            kart.shake[e] = 1;
          }
        }
        if (kart.slowFor[e] > 0) {
          kart.slowFor[e] = Math.max(0, kart.slowFor[e] - dt);
          slow = true;
          // Its first moment frozen near still: the impact, held.
          if (kart.slowFor[e] > SLOW_FOR - FREEZE) frozen = true;
        }
      }
      const want = frozen ? FREEZE_SCALE : slow ? SLOW : 1;
      if (world.loop.timeScale !== want) world.loop.timeScale = want;
    },
  });
}
