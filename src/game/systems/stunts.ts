/**
 * stunts, 60 Hz: showmanship beyond big air. Each scores style (`Kart.style`, the Showmanship medal's points) and is
 * shouted as it is pulled:
 *
 *   CLEAN CHICANE     through a chicane without a touch of its tyres or bales
 *   ON TWO WHEELS     one side's wheels both off the road, the other's both on, at speed, for a while
 *   DRIFT             sliding well sideways on the road at speed, for a while
 *   AIR SPIN          a whole turn (or more) about its up in the air, landed on its wheels
 *   360               a whole turn about its up on its wheels -- a spin-out, a doughnut -- each turn as it comes round
 *   REVERSING         rolling backwards (against the way its nose points) at a fair lick for REVERSE_FOR or more
 *   REVERSE FINISH    over the line facing back up the hill
 *   LIMPED HOME       over the line with a wheel or more gone
 *
 * The repeatable ones (two wheels, drift, the spins, reversing) each score less than the one before (`REPEAT`), as
 * jumps do.
 * Every number to tune is at the top.
 */
import { CollisionEnter, type Entity, Hierarchy, NONE, optional, RigidBody, type Store, Transform, type World } from '@vibe/engine';
import { Chicane, Corner, Kart, News, Phase, Wheel } from '../components.ts';
import { TRACKS } from '../courses.ts';

/** Points for each, and what earns them. */
const CLEAN_CHICANE = 120;
const REVERSE_FINISH = 300;
/** Facing back up the hill: its nose this far (the cosine) against the road's way down. */
const BACKWARDS = -0.5;
const LIMPED_HOME = 150;
/** On two wheels: at least this fast (m/s), this long (s) to count; points a second. */
const TWO_SPEED = 4;
const TWO_FOR = 0.6;
const TWO_PER_SECOND = 90;
/** A drift: at least this fast, sliding sideways at least this share of its speed, this long; points a second. */
const DRIFT_SPEED = 8;
const DRIFT_SLIP = 0.35;
const DRIFT_FOR = 0.8;
const DRIFT_PER_SECOND = 70;
/** An air spin: points for each whole turn (a little short of one counts), landed upright (its up at least this). */
const SPIN_POINTS = 200;
const SPIN_TURN = Math.PI * 2 * 0.9;
const UPRIGHT = 0.7;
/** A 360 on its wheels: points a whole turn (a little short of one counts); it stops counting a spin once it has
 * turned slower than SPIN_SLOW (rad/s) for SPIN_CALM seconds. */
const GROUND_SPIN_POINTS = 150;
const SPIN_SLOW = 1.2;
const SPIN_CALM = 0.5;
/** Reversing: rolling backwards (its velocity against its nose) at least this fast, at least this long; points a
 * second. */
const REVERSE_SPEED = 2.5;
const REVERSE_FOR = 2;
const REVERSE_PER_SECOND = 60;
/** Each repeatable stunt after the first scores this share of the last. */
const REPEAT = 0.85;

export function stunts(world: World): void {
  const hits = world.events(CollisionEnter);
  const chicanes = world.query({ with: [Chicane] });
  world.system({
    name: 'stunts',
    rate: 60,
    after: ['race', 'vehicle', 'impacts'],
    read: [Transform, RigidBody, Hierarchy, optional(Wheel), optional(Chicane)],
    write: [Kart],
    update(ctx, [at, rb, tree, wheel, chicane], [kart]) {
      const { members, count, dt, has, deref } = ctx;

      // A touch of a chicane's wall: that chicane is not clean.
      for (let i = hits.begin(ctx); i < hits.end; i++) {
        const a = deref(hits.a[i]), b = deref(hits.b[i]);
        const k = a !== NONE && has(a, Kart) ? a : b !== NONE && has(b, Kart) ? b : NONE;
        if (k === NONE) continue;
        const other = k === a ? b : a;
        if (other !== NONE && has(other, Chicane)) kart.chicaneHits[k] |= 1 << chicane.index[other];
      }

      for (let n = 0; n < count; n++) {
        const e = members[n];
        const phase = kart.phase[e];
        const was = kart.lastProgress[e];
        kart.lastProgress[e] = kart.progress[e];
        if (phase !== Phase.racing && phase !== Phase.finished) continue;
        if (kart.course[e] >= TRACKS.length) continue;
        const track = TRACKS[kart.course[e]]!;
        const qx = at.qx[e], qy = at.qy[e], qz = at.qz[e], qw = at.qw[e];
        // Its nose and its left, in the world.
        const fx = 2 * (qx * qz + qw * qy), fz = 1 - 2 * (qx * qx + qy * qy);
        const lx = 1 - 2 * (qy * qy + qz * qz), lz = 2 * (qx * qz - qw * qy);
        const vx = rb.velocityX[e], vz = rb.velocityZ[e];
        const speed = Math.hypot(vx, vz);
        const clock = kart.clock[e];

        // Over the line this tick: how it crossed.
        if (phase === Phase.finished && !kart.finishJudged[e]) {
          kart.finishJudged[e] = 1;
          const j = Math.max(0, Math.min(track.samples - 1, track.finish));
          if (fx * track.tx[j]! + fz * track.tz[j]! < BACKWARDS) {
            score(kart, e, News.reverseFinish, REVERSE_FINISH, clock);
            kart.backwards[e] = 1;
          }
          else if (kart.wheelsLost[e] > 0) score(kart, e, News.limpedHome, LIMPED_HOME, clock);
        }
        if (phase === Phase.racing) {
          // Through a chicane: clean, if nothing of it was touched (and it went through whole, its driver aboard).
          for (let c = 0; c < chicanes.count; c++) {
            const w = chicanes.members[c]!;
            const bit = 1 << chicane.index[w];
            if (kart.chicaneDone[e] & bit) continue;
            const exit = chicane.exit[w];
            if (was < exit && kart.progress[e] >= exit) {
              kart.chicaneDone[e] |= bit;
              if (!(kart.chicaneHits[e] & bit) && !kart.wrecked[e] && !kart.ejected[e]) score(kart, e, News.cleanChicane, CLEAN_CHICANE, clock);
            }
          }
        }
        if (phase !== Phase.racing || kart.wrecked[e] || kart.ejected[e]) {
          kart.twoFor[e] = kart.driftFor[e] = kart.airYaw[e] = 0;
          kart.groundYaw[e] = kart.groundCalm[e] = kart.backFor[e] = 0;
          continue;
        }

        // Which wheels are down.
        let leftDown = 0, rightDown = 0, whole = 0;
        for (let c = tree.firstChild[e]; c !== 0; c = tree.nextSibling[c]) {
          if (!has(c, Wheel) || !wheel.attached[c]) continue;
          whole++;
          const k = wheel.corner[c];
          const left = k === Corner.fl || k === Corner.rl;
          if (wheel.grounded[c]) {
            if (left) leftDown++;
            else rightDown++;
          }
        }

        // On two wheels: a whole kart, one side both up, the other both down.
        const onTwo = whole === 4 && speed > TWO_SPEED && ((leftDown === 2 && rightDown === 0) || (leftDown === 0 && rightDown === 2));
        if (onTwo) kart.twoFor[e] += dt;
        else {
          if (kart.twoFor[e] >= TWO_FOR) repeatable(kart, e, News.twoWheels, kart.twoFor[e] * TWO_PER_SECOND, clock);
          kart.twoFor[e] = 0;
        }

        // A drift: on the road, sliding well sideways.
        const lateral = Math.abs(vx * lx + vz * lz);
        const drifting = leftDown + rightDown >= 3 && speed > DRIFT_SPEED && lateral > speed * DRIFT_SLIP;
        if (drifting) kart.driftFor[e] += dt;
        else {
          if (kart.driftFor[e] >= DRIFT_FOR) repeatable(kart, e, News.drift, kart.driftFor[e] * DRIFT_PER_SECOND, clock);
          kart.driftFor[e] = 0;
        }

        // A 360 on its wheels: its turn about the world's up added up while it is down and spinning; each whole turn
        // scored as it comes round. Turning slowly a while, the spin is over and the count starts again.
        const yawRate = rb.angularVelocityY[e];
        if (kart.air[e] === 0 && leftDown + rightDown >= 2) {
          kart.groundYaw[e] += yawRate * dt;
          kart.groundCalm[e] = Math.abs(yawRate) < SPIN_SLOW ? kart.groundCalm[e] + dt : 0;
          if (kart.groundCalm[e] > SPIN_CALM) kart.groundYaw[e] = 0;
          if (Math.abs(kart.groundYaw[e]) >= SPIN_TURN) {
            repeatable(kart, e, News.spin, GROUND_SPIN_POINTS, clock);
            kart.groundYaw[e] -= Math.sign(kart.groundYaw[e]) * Math.PI * 2;
          }
        } else kart.groundYaw[e] = kart.groundCalm[e] = 0;

        // Reversing: rolling the way its tail points, at a fair lick, on its wheels; scored as it stops, if long enough.
        const along = vx * fx + vz * fz;
        if (kart.air[e] === 0 && along < -REVERSE_SPEED) kart.backFor[e] += dt;
        else {
          if (kart.backFor[e] >= REVERSE_FOR) repeatable(kart, e, News.reversing, kart.backFor[e] * REVERSE_PER_SECOND, clock);
          kart.backFor[e] = 0;
        }

        // An air spin: its turn about the world's up, added up through the flight; judged on landing.
        if (kart.air[e] > 0) kart.airYaw[e] += rb.angularVelocityY[e] * dt;
        else if (kart.airYaw[e] !== 0) {
          const turns = Math.floor((Math.abs(kart.airYaw[e]) + Math.PI * 2 - SPIN_TURN) / (Math.PI * 2));
          if (turns > 0 && kart.upY[e] > UPRIGHT) repeatable(kart, e, News.airSpin, turns * SPIN_POINTS, clock);
          kart.airYaw[e] = 0;
        }
      }
    },
  });
}

type KartStore = Store<typeof Kart.schema>;

/** `points` of style for `news`, shouted now. */
function score(kart: KartStore, e: Entity, news: number, points: number, clock: number): void {
  const p = Math.round(points);
  kart.style[e] += p;
  kart.news[e] = news;
  kart.newsValue[e] = p;
  kart.newsAt[e] = clock;
}

/** As `score`, each one of these after the first the less. */
function repeatable(kart: KartStore, e: Entity, news: number, points: number, clock: number): void {
  score(kart, e, news, points * Math.pow(REPEAT, kart.repeats[e]), clock);
  kart.repeats[e]++;
}
