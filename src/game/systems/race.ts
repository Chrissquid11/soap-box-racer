/**
 * race, 60 Hz: a run from start to finish. In the garage the kart waits on the start line while the
 * builder is up; the builder's Race! (or Enter) counts down three seconds and lets it go; the clock
 * runs to the finish line, which only counts with the driver aboard -- a kart that crosses without
 * them waits for them to climb back in. R starts the same run again, B goes back to the garage. Off the
 * road, the driver out of the kart, or the kart near enough stopped, for more than six seconds in a row -- or
 * crashed, left on its side or its back for a couple of seconds (nobody sets it right)
 * (or fallen off the world at all), and the run is over (`Phase.over`, why in `Kart.out`): the results
 * say so, and R or Race again starts it afresh. Every new run puts the kart back on the line as new
 * (rebuilt: all its wheels on) and says `RaceReset`, so what was knocked about goes back too.
 */
import { NO_REF, NONE, physicsOf, RayHit, RigidBody, Transform, type World } from '@vibe/engine';
import { CRAWL, CRAWL_OUT_FOR, crippled } from '../damage.ts';
import { Build, Cause, COUNTDOWN, CRASHED_FOR, ON_ITS_ROOF, ROOF_FOR, FLYOVER, Kart, News, Order, OUT_FOR, Phase, RaceReset, RunOut, THROWN_FOR } from '../components.ts';
import { COURSES, TRACKS } from '../courses.ts';
import type { Track } from '../track.ts';
import { type SystemContext } from '@vibe/engine';
import { burst } from '../burst.ts';
import { headingAt, newRoute, progressAt, routeAt } from '../track.ts';
import { dealWeather } from '../weather.ts';

/** What a kart's chassis, wheels and bodywork stand once it is over the finish line, as a share of what they did: half. */
const FINISHED_WEAK = 0.5;
/** The kart waits this many samples behind the start line. */
const GRID_BACK = 3;
/** Below the course's height there by this much, it has fallen off the world: the run is over at once. */
const FALLEN = 25;
/** Off the road: further from its middle than its half width and this, or this far below it. */
const OFF_MARGIN = 1;
/** Seconds right off the side of the road (over the walls) before the kart falls to bits: `wear` wrecks it. */
const OFF_BREAKS = 0.15;
/** ...and only when it comes down out there (its fall stopped by this many m/s in a tick, or a wheel down) going at
 * least this fast (m/s, along or down): slower, it is only off the track. */
const OFF_SLAM = 3;
const OFF_SMASH_SPEED = 7;
/** Come down out there: after this long in the air over it, or this long on the ground out there at all. */
const OFF_FLOWN = 0.15;
const OFF_GROUNDED = 0.6;
const BELOW = 3;
/** Further under the road than this, over it, and a kart has slipped through it: set back this far above it. */
const SLIPPED = 1.2;
const RESET_LIFT = 0.8;
/** Metres under the road's nearest height that is under the ground anywhere on the course; and how far over the road
 * the look down for the ground there starts. */
const GROUND_BELOW = 2.5;
const GROUND_LOOK = 60;
const hit = new RayHit();
/** Rocked back upright (its up this much) after this long on its side: back on the job. */
const RIGHTED_AFTER = 0.6;
const UPRIGHT = 0.7;
/** In the duck pond: on the shortcut over its gap, this far below the road -- the run is over (a splash). */
const IN_POND = 1.2;
/** Off the road, progress may gain no more than this a tick: a kart cutting across the grass gains nothing by it. */
const OFF_GAIN = 0.05;
const route = newRoute();
/** Slower than this, m/s, it has near enough stopped. */
const STILL = 1;
/** On its side or its back: its up this little or less, slower than this (m/s), this many seconds -- crashed out. */
const ON_ITS_SIDE = 0.4;
const CRASH_STILL = 1.5;
/** Seconds a wrecked kart lies in bits (the crash cam) before the results. */
const WRECK = 3;

export function race(world: World): void {
  const resets = world.events(RaceReset);
  const physics = physicsOf(world);
  const ground = physics.layers('Default', 'Ramps');
  world.system({
    name: 'race',
    rate: 60,
    write: [Kart, Build, RigidBody, Transform],
    update({ members, count, dt, input, cmd, ref, deref }, _read, [kart, build, rb, at]) {
      for (let n = 0; n < count; n++) {
        const e = members[n];
        // No course loaded yet: the `course` system makes one first, and the line is placed after.
        if (kart.course[e] >= TRACKS.length) continue;
        const track = TRACKS[kart.course[e]]!;
        let order = build.order[e];
        build.order[e] = Order.none;
        const phase = kart.phase[e];
        if (phase !== Phase.garage && (input.pressed('KeyR') || input.pressed('Pad3'))) order = Order.restart;
        if (phase !== Phase.garage && (input.pressed('KeyB') || input.pressed('Pad8'))) order = Order.garage;
        if (phase === Phase.garage && !build.menu[e] && input.pressed('Enter')) order = Order.tour;
        // At the line before a run from the garage: Space, Enter, W or the HUD's button skips the flyover, then starts.
        const go = order === Order.skip || (kart.waiting[e] && (input.pressed('Space') || input.pressed('Enter') || input.pressed('KeyW') || input.pressed('Pad0')));
        if (order === Order.skip) order = Order.none;
        if (go) {
          if (kart.flyover[e] > 0) kart.flyover[e] = 0;
          else kart.waiting[e] = 0;
        }
        // A run from the garage, with a flyover of the course first.
        const tour = order === Order.tour;
        if (tour) order = Order.race;
        // A locked course only shows: no run on it.
        const starting = order === Order.race;
        // Refused, it goes back to the garage on the course now loaded (a locked one picked from the list loads, to be seen).
        if (starting && kart.course[e] >= build.open[e]) order = phase === Phase.garage ? Order.none : Order.garage;
        // Nor in a kart outside the rules (over budget, over the weight limit, too big, too low) -- once the verdict is
        // the build's own: a build changed this very tick is judged by `assemble` after this, and the garage judges it
        // before it asks.
        if (starting && kart.built[e] === build.version[e] && !kart.legal[e]) order = Order.none;
        // Wrecked, in bits, short of the line: a moment to take it in, then the results (R restarts at any time). (Wrecked past it, in the
        // run-out, the finish stands.)
        if (phase === Phase.racing && kart.wrecked[e] && kart.clock[e] - kart.wreckedAt[e] > WRECK && order === Order.none) {
          kart.phase[e] = Phase.over;
          kart.out[e] = RunOut.wrecked;
          kart.finishTime[e] = kart.clock[e];
          continue;
        }
        // A kart seen for the first time is put on the line.
        if (kart.progress[e] < 0 && order === Order.none) order = Order.garage;

        if (order !== Order.none) {
          // Back on the line, as new.
          const s = track.start - GRID_BACK;
          const h = headingAt(track, s);
          at.px[e] = track.sx[s]!;
          at.py[e] = track.sy[s]! + kart.rideY[e] + 0.3;   // a little high: a new build settles onto its springs
          at.pz[e] = track.sz[s]!;
          at.qx[e] = 0;
          at.qy[e] = Math.sin(h / 2);
          at.qz[e] = 0;
          at.qw[e] = Math.cos(h / 2);
          rb.velocityX[e] = rb.velocityY[e] = rb.velocityZ[e] = 0;
          rb.angularVelocityX[e] = rb.angularVelocityY[e] = rb.angularVelocityZ[e] = 0;
          kart.lastVX[e] = kart.lastVY[e] = kart.lastVZ[e] = 0;
          kart.accelX[e] = kart.accelY[e] = kart.accelZ[e] = 0;
          kart.lastWX[e] = kart.lastWY[e] = kart.lastWZ[e] = 0;
          kart.built[e] = 0;
          const rag = deref(kart.ragdoll[e]);
          if (rag !== NONE) cmd.destroy(rag);
          kart.ragdoll[e] = NO_REF;
          kart.torso[e] = NO_REF;
          kart.ejected[e] = 0;
          kart.thrown[e] = Cause.none;
          kart.ejectTime[e] = 0;
          kart.stuck[e] = 0;
          kart.roofFor[e] = 0;
          kart.steer[e] = kart.lean[e] = kart.air[e] = 0;
          // Nothing of the last run's crash carried into this one: no judder, no slow motion.
          kart.shake[e] = kart.landed[e] = kart.slowFor[e] = 0;
          // (The crash cam's last slow motion forgotten: the new run's first crash gets its own.)
          kart.slowAt[e] = -99;
          kart.style[e] = 0;
          // No stunt half pulled carried over: no chicane touched or passed, nothing scored yet.
          kart.twoFor[e] = kart.driftFor[e] = kart.airYaw[e] = 0;
          kart.groundYaw[e] = kart.groundCalm[e] = kart.backFor[e] = 0;
          kart.chicaneHits[e] = kart.chicaneDone[e] = kart.repeats[e] = 0;
          kart.finishJudged[e] = 0;
          kart.onCut[e] = kart.tookCut[e] = 0;
          kart.hurts[e] = kart.cutHurt[e] = 0;
          kart.rolledAt[e] = -1;
          kart.limpFor[e] = kart.limpDist[e] = kart.lossSpeed[e] = 0;
          kart.backwards[e] = 0;
          kart.ducks[e] = 0;
          kart.jumps[e] = kart.wheelsLost[e] = kart.bodyLost[e] = kart.ejections[e] = kart.rollovers[e] = 0;
          kart.cause[e] = Cause.none;
          kart.causeSpeed[e] = 0;
          kart.damage[e] = 0;
          kart.shed[e] = 0;
          kart.shedClock[e] = -99;
          kart.smash[e] = 0;
          kart.grace[e] = 0;
          kart.wrecked[e] = 0;
          kart.wreckedAt[e] = 0;
          kart.offFor[e] = kart.outFor[e] = kart.stillFor[e] = 0;
          kart.offAir[e] = 0;
          kart.out[e] = RunOut.none;
          kart.news[e] = News.none;
          kart.newsAt[e] = -99;
          kart.finishTime[e] = 0;
          kart.progress[e] = progressAt(track, at.px[e], at.pz[e], -1);
          kart.phase[e] = order === Order.garage ? Phase.garage : Phase.countdown;
          kart.clock[e] = order === Order.garage ? 0 : -COUNTDOWN;
          kart.flyover[e] = tour && order === Order.race ? FLYOVER : 0;
          kart.waiting[e] = tour && order === Order.race ? 1 : 0;
          // The weather: dealt afresh on coming to a course's garage -- from a run, or a course newly picked; kept for
          // every restart and every part changed in the garage.
          if ((order === Order.garage && phase !== Phase.garage) || kart.weatherFor[e] !== kart.course[e]) {
            kart.weather[e] = dealWeather(kart.course[e], kart.weatherFor[e] === kart.course[e] ? kart.visits[e] : 0, COURSES[Math.min(kart.course[e], COURSES.length - 1)]!.snowy);
            kart.visits[e] = kart.weatherFor[e] === kart.course[e] ? kart.visits[e] + 1 : 1;
            kart.weatherFor[e] = kart.course[e];
            kart.windSide[e] = (kart.visits[e] + kart.course[e]) % 2 === 0 ? 1 : -1;
          }
          resets.kart[resets.emit()] = ref(e);
          continue;
        }

        if (phase === Phase.garage || phase === Phase.over) continue;
        // The flyover first, then the field on show till the player starts: the countdown waits for both.
        if (kart.waiting[e]) {
          kart.flyover[e] = Math.max(0, kart.flyover[e] - dt);
          continue;
        }
        kart.clock[e] += dt;
        // Where it is on either route (`routeAt`): off the road it gains no ground, so no corner is cut over the grass.
        const was = kart.progress[e];
        routeAt(track, at.px[e], at.pz[e], was, route);
        const offRoad = Math.abs(route.across) > route.halfWidth + OFF_MARGIN;
        kart.progress[e] = offRoad && phase === Phase.racing ? Math.min(route.progress, was + OFF_GAIN) : route.progress;
        kart.onCut[e] = route.onCut ? 1 : 0;
        // Driven on with a wheel gone: how long and how far (the results compare its pace with the speed it had).
        if (phase === Phase.racing && kart.wheelsLost[e] > 0) {
          if (kart.limpFor[e] === 0) kart.lossSpeed[e] = kart.speed[e];
          kart.limpFor[e] += dt;
          kart.limpDist[e] += kart.speed[e] * dt;
        }
        if (route.onCut && phase === Phase.racing) kart.tookCut[e] = 1;

        // Never through the ground, whatever it is doing (on the grid, racing, past the line, crashed): the course's
        // ground everywhere stands at or above the road's nearest height less a little, so GROUND_BELOW under that it
        // has slipped through. The ground there found by looking straight down from high over it, and the kart set
        // back on top, still going. (Over the shortcut's pond there is no ground to find; off the world's edge none
        // either -- that falls on, and FALLEN ends the run.)
        if (phase !== Phase.garage) {
          const g = Math.max(0, Math.min(track.samples - 1, Math.round(kart.progress[e])));
          const pond = track.cut !== null && route.onCut;
          if (!pond && at.py[e] < track.sy[g]! - GROUND_BELOW) {
            const from = track.sy[g]! + GROUND_LOOK;
            if (physics.raycast(at.px[e], from, at.pz[e], 0, -1, 0, GROUND_LOOK + FALLEN, ground, hit) && hit.y > at.py[e]) {
              at.py[e] = hit.y + kart.rideY[e] + RESET_LIFT;
              if (rb.velocityY[e] < 0) rb.velocityY[e] = 0;
            }
          }
        }

        // The run's end short of the line: off the road, the driver out, or near enough stopped -- any of them for
        // more than OUT_FOR seconds in a row. Fallen right off the world, at once. A wreck starts again on its own.
        if (phase === Phase.racing && !kart.wrecked[e]) {
          const j = Math.max(0, Math.min(track.samples - 1, Math.round(kart.progress[e])));
          const across = route.across;
          const half = route.halfWidth;
          const surface = route.surface;
          // In the duck pond: over the shortcut's gap and down in the water. A splash, and the run is over.
          const cut = track.cut;
          if (cut && route.onCut && route.u > cut.pondFrom && route.u < cut.pondTo + 0.02 && at.py[e] < surface - IN_POND) {
            kart.phase[e] = Phase.over;
            kart.out[e] = RunOut.pond;
            kart.finishTime[e] = kart.clock[e];
            splash(cmd, at.px[e], surface - 2, at.pz[e], e);
            continue;
          }
          // Over the pond and down on the far side, on the road: cleared the ducks (once a run).
          if (cut && route.onCut && !kart.ducks[e] && route.u > cut.pondTo + 0.02 && at.py[e] > surface - 0.5 && kart.air[e] === 0) {
            kart.ducks[e] = 1;
            kart.news[e] = News.clearedDucks;
            kart.newsValue[e] = 0;
            kart.newsAt[e] = kart.clock[e];
          }
          // Under the road it is riding over (it never should be: the course's backstop is solid under it) -- set
          // back on top of it at once, still going, rather than lost. (Not over the pond's gap: there is no road there.)
          const overGap = cut !== null && route.onCut && route.u > cut.pondFrom - 0.01 && route.u < cut.pondTo + 0.01;
          if (!overGap && at.py[e] < surface - SLIPPED && Math.abs(across) < half + OFF_MARGIN) {
            at.py[e] = surface + RESET_LIFT;
            if (rb.velocityY[e] < 0) rb.velocityY[e] = 0;
          }
          const over = Math.abs(across) > half + OFF_MARGIN;
          const off = over || (!overGap && at.py[e] < surface - BELOW);
          kart.offFor[e] = off ? kart.offFor[e] + dt : 0;
          // Off the side of the course: it falls apart the moment it comes down on something out there -- a wheel on the
          // ground, or its body slammed (its fall stopped all at once) -- if it is going fast enough then. In the air
          // over the walls nothing yet; rolled off slowly, it is only off the track (and the run over before long).
          // `wear` wrecks it this tick or the next, and a wreck starts the run again on its own.
          kart.offAir[e] = over ? Math.max(kart.offAir[e], kart.air[e]) : 0;
          if (over && kart.offFor[e] > OFF_BREAKS && !kart.smash[e]) {
            const slammed = rb.velocityY[e] - kart.lastVY[e] > OFF_SLAM;
            // Come down: after flying out there (not still scraping over the wall's top), or a while on the ground there.
            const down = (kart.air[e] === 0 || slammed) && (kart.offAir[e] > OFF_FLOWN || kart.offFor[e] > OFF_GROUNDED);
            const pace = Math.max(kart.speed[e], Math.max(0, -kart.lastVY[e]));
            if (down && pace >= OFF_SMASH_SPEED) kart.smash[e] = 1;
          }
          if (kart.smash[e]) continue;
          kart.outFor[e] = kart.ejected[e] ? kart.outFor[e] + dt : 0;
          // Crippled by damage and barely crawling: over soon (CRAWL_OUT_FOR), not after the whole OUT_FOR.
          const hurt = crippled(kart, e);
          kart.stillFor[e] = kart.speed[e] < (hurt ? CRAWL : STILL) ? kart.stillFor[e] + dt : 0;
          // Crashed: on its side or its back, near enough still -- nobody sets it right, so the run is over before long.
          const wasStuck = kart.stuck[e];
          kart.stuck[e] = kart.upY[e] < ON_ITS_SIDE && kart.speed[e] < CRASH_STILL ? kart.stuck[e] + dt : 0;
          // Flipped onto its roof: over in moments, sliding or not (a flip through the air is over sooner than that).
          kart.roofFor[e] = kart.upY[e] < ON_ITS_ROOF ? kart.roofFor[e] + dt : 0;
          if (wasStuck > RIGHTED_AFTER && kart.stuck[e] === 0 && kart.upY[e] > UPRIGHT && !kart.ejected[e]) {
            kart.news[e] = News.righted;
            kart.newsValue[e] = 0;
            kart.newsAt[e] = kart.clock[e];
          }
          let out: number = RunOut.none;
          if (kart.offFor[e] > OUT_FOR || at.py[e] < track.sy[j]! - FALLEN) out = RunOut.offTrack;
          else if (kart.outFor[e] > THROWN_FOR) out = RunOut.driverOut;
          else if (kart.stuck[e] > CRASHED_FOR || kart.roofFor[e] > ROOF_FOR) out = RunOut.crashed;
          else if (kart.stillFor[e] > (hurt ? CRAWL_OUT_FOR : OUT_FOR)) out = RunOut.stopped;
          if (out !== RunOut.none) {
            kart.phase[e] = Phase.over;
            kart.out[e] = out;
            kart.finishTime[e] = kart.clock[e];
            continue;
          }
        }

        if (phase === Phase.countdown && kart.clock[e] >= 0) {
          kart.phase[e] = Phase.racing;
          kart.news[e] = News.go;
          celebrate(cmd, track, track.start, GO_COLOURS, GO_BITS, e);
          kart.newsAt[e] = kart.clock[e];
        } else if (phase === Phase.racing && kart.progress[e] >= track.finish) {
          // The finish line counts only with the driver aboard.
          if (!kart.ejected[e]) {
            kart.phase[e] = Phase.finished;
            // Over the line the kart goes soft (FINISHED_WEAK): the run-out into the hay is where it falls to bits.
            kart.hp[e] *= FINISHED_WEAK;
            kart.strength[e] *= FINISHED_WEAK;
            kart.bodyStrength[e] *= FINISHED_WEAK;
            // Confetti from both sides of the line: gold among it for a gold time, a sorry few bits limping in on three wheels.
            const gold = kart.clock[e] <= COURSES[kart.course[e]]!.medals[0];
            const limping = kart.wheelsLost[e] > 0;
            celebrate(cmd, track, track.finish, gold ? GOLD_COLOURS : CONFETTI, limping ? LIMP_BITS : gold ? GOLD_BITS : CONFETTI_BITS, e);
            kart.finishTime[e] = kart.clock[e];
          } else if (kart.news[e] !== News.alone) {
            kart.news[e] = News.alone;
            kart.newsAt[e] = kart.clock[e];
          }
        }
      }
    },
  });
}

/** A splash out of the duck pond: white and blue water thrown up and out. */
const SPLASH = [0xffffff, 0xbfe6ff, 0x5ab4f0, 0x2a7fd0] as const;
function splash(cmd: SystemContext['cmd'], x: number, y: number, z: number, seed: number): void {
  burst(cmd, { x, y, z, spread: 0.8, vx: 0, vy: 7, vz: 0, power: 5, count: 40, colours: SPLASH, size: 0.4, seed: seed * 7 + 3, bolts: false });
}

/** GO!: orange streamers from either side of the start line; over the line, confetti (gold among it for a gold time). */
const GO_COLOURS = [0xf58a1f, 0xffb24a, 0xffffff] as const;
const CONFETTI = [0xff4d6d, 0x3fa8ff, 0xffd23f, 0x5ee07a, 0xffffff, 0xb46bff] as const;
const GOLD_COLOURS = [0xffd23f, 0xf2b10c, 0xffffff, 0xffe9a3] as const;
const GO_BITS = 14;
const CONFETTI_BITS = 26;
const GOLD_BITS = 40;
const LIMP_BITS = 6;

/** A burst from either side of the road at sample `s`, up and in over it. */
function celebrate(cmd: SystemContext['cmd'], t: Track, s: number, colours: readonly number[], bits: number, seed: number): void {
  const i = Math.max(0, Math.min(t.samples - 1, s));
  for (const side of [-1, 1]) {
    const across = side * (t.hw[i]! + 0.4);
    burst(cmd, {
      x: t.sx[i]! - t.tz[i]! * across, y: t.sy[i]! + 1.2, z: t.sz[i]! + t.tx[i]! * across, spread: 0.3,
      vx: t.tz[i]! * side * 3, vy: 5, vz: -t.tx[i]! * side * 3,
      power: 3, count: bits, colours, size: 0.35, seed: seed * 3 + (side > 0 ? 1 : 0) + s, bolts: false,
    });
  }
}
