/**
 * driverPose, 15 Hz: what the driver in the seat is doing, as the clip their `Animation` plays -- the
 * `karts/driver` model's own: leaning into the turn the kart is steered into, tucked down for speed,
 * braced with their arms up while the kart is in the air, cheering over the line, else just sitting
 * and riding -- and in the garage, fidgeting while the kart is built (looking round, stretching, drumming, peering
 * over the side). Changed only when it changes; the engine's `animate` crossfades (the seat's `fade`).
 */
import { Animation, Hierarchy, internKey, optional, type World } from '@vibe/engine';
import { Kart, Phase, Seat } from '../components.ts';

const SIT = internKey('Clip', 'sit');
const LEAN_LEFT = internKey('Clip', 'lean_left');
const LEAN_RIGHT = internKey('Clip', 'lean_right');
const TUCK = internKey('Clip', 'tuck');
const BRACE = internKey('Clip', 'brace');
const CHEER = internKey('Clip', 'cheer');
/** Radians of steering it takes to lean; seconds in the air before bracing. */
const LEANS = 0.06;
const BRACES = 0.25;
/** In the garage, waiting while the kart is built: sitting, and every IDLE_EVERY seconds one of the idle clips --
 * each once through, at the end of its turn (`_driver.lua`: each starts and ends sitting), taken in a shuffled turn. */
const IDLES = [internKey('Clip', 'idle_look'), internKey('Clip', 'idle_stretch'), internKey('Clip', 'idle_drum'), internKey('Clip', 'idle_check')] as const;
const IDLE_FOR = [4, 3.2, 2.4, 3.6] as const;
const IDLE_ORDER = [0, 2, 1, 3, 2, 0, 3, 1] as const;
const IDLE_EVERY = 7;

/** The garage's clip at `time` seconds: sitting, or the turn's idle clip over the last of its turn. */
function idleAt(time: number): number {
  const turn = Math.floor(time / IDLE_EVERY);
  const i = IDLE_ORDER[turn % IDLE_ORDER.length]!;
  return time - turn * IDLE_EVERY > IDLE_EVERY - IDLE_FOR[i]! ? IDLES[i]! : SIT;
}

export function driverPose(world: World): void {
  world.system({
    name: 'driverPose',
    rate: 15,
    stagger: false,
    with: [Seat],
    read: [Hierarchy, optional(Kart)],
    write: [Animation],
    update({ members, count, has, time }, [tree, kart], [anim]) {
      for (let n = 0; n < count; n++) {
        const e = members[n];
        const k = tree.parent[e];
        if (k === 0 || !has(k, Kart)) continue;
        let clip = SIT;
        if (kart.phase[k] === Phase.garage) clip = idleAt(time);
        else if (kart.phase[k] === Phase.finished) clip = CHEER;
        else if (kart.air[k] > BRACES) clip = BRACE;
        else if (kart.steer[k] > LEANS) clip = LEAN_LEFT;
        else if (kart.steer[k] < -LEANS) clip = LEAN_RIGHT;
        else if (kart.tucked[k]) clip = TUCK;
        if (anim.clip[e] !== clip) anim.clip[e] = clip;
      }
    },
  });
}
