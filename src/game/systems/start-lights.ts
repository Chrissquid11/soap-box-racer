/**
 * startLights, 30 Hz: the start arch's three lamps (`StartLamp`, `course/arch_lamp_1..3`: each its own model on the
 * arch's skeleton, swaying with it) telling the kart when to go. Dark while it waits; through the countdown they come
 * on red one at a time, a second apart -- the first at the countdown's start, the third with a second to go -- and at
 * GO all three turn green, staying lit GREEN_FOR seconds into the run, then dark again. Only the look.
 */
import { Hidden, optional, Render, type World } from '@vibe/engine';
import { COUNTDOWN, Kart, Phase, StartLamp } from '../components.ts';

/** The lamps' colours: red while it waits, green to go. */
const WAIT = 0xff2216;
const GO = 0x2bff4a;
/** Seconds into the run the green stays lit. */
const GREEN_FOR = 2.5;

export function startLights(world: World): void {
  const karts = world.query({ with: [Kart] });
  world.system({
    name: 'startLights',
    rate: 30,
    with: [StartLamp],
    read: [StartLamp, optional(Kart)],
    write: [Render],
    update({ members, count, cmd, has }, [lamp, kart], [look]) {
      if (karts.count === 0) return;
      const k = karts.members[0]!;
      const phase = kart.phase[k]!;
      const clock = kart.clock[k]!;
      // How many are lit red (0 to 3), or all green.
      let red = 0;
      let green = false;
      if (phase === Phase.countdown && !kart.waiting[k]) red = Math.min(3, Math.max(0, Math.floor(clock + COUNTDOWN) + 1));
      else if ((phase === Phase.racing || phase === Phase.finished) && clock < GREEN_FOR) green = true;
      for (let n = 0; n < count; n++) {
        const e = members[n]!;
        const on = green || lamp.index[e]! < red;
        const hidden = has(e, Hidden);
        if (on) {
          look.tint[e] = green ? GO : WAIT;
          if (hidden) cmd.remove(e, Hidden);
        } else if (!hidden) cmd.add(e, Hidden);
      }
    },
  });
}
