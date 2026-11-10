/**
 * disco, 30 Hz: the disco tunnel's lights strobing -- its two sets of coloured lamps (`course/tunnel`'s lights, each
 * a `Disco` set) shown by turns, FLASHES times a second, now and then both dark for a beat. Only the look.
 */
import { Hidden, type World } from '@vibe/engine';
import { Disco } from '../components.ts';

/** How many times a second the sets swap; every DARK_EVERY-th beat both are dark. */
const FLASHES = 7;
const DARK_EVERY = 5;

export function disco(world: World): void {
  world.system({
    name: 'disco',
    rate: 30,
    with: [Disco],
    read: [Disco],
    write: [],
    update({ members, count, time, cmd, has }, [disco]) {
      const beat = Math.floor(time * FLASHES);
      for (let n = 0; n < count; n++) {
        const e = members[n];
        const on = beat % DARK_EVERY !== 0 && beat % 2 === disco.set[e];
        const hidden = has(e, Hidden);
        if (on && hidden) cmd.remove(e, Hidden);
        else if (!on && !hidden) cmd.add(e, Hidden);
      }
    },
  });
}
