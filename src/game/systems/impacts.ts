/**
 * impacts, 60 Hz: what a knock does to a kart. Each collision the kart's box has, as hard as it closed
 * (m/s, the kart's share of it): the contact point, in the kart's own frame, finds the part it hit -- the
 * wheel at the nearest corner, or else the bodywork -- and the part goes from healthy to damaged to failed
 * by `damage.ts`' rule (a light knock nothing; a severe one straight to failed; a cooldown between). A
 * failed wheel comes off and rolls away; failed bodywork shatters. Harder than the seat holds and the
 * driver is thrown. And upside down is a rollover: the driver goes then too, and the bodywork breaks up
 * under it. What came off flies on as debris; the cause is kept for the results.
 */
import { BoxCollider, CollisionEnter, type Entity, Hidden, Hierarchy, internKey, NONE, optional, Render, RigidBody, SphereCollider, type Store, type SystemContext, Transform, type World } from '@vibe/engine';
import { BODY, CHASSIS } from '../build.ts';
import { BodyBit, BodyGlass, Bodywork, Breakable, Build, Cause, ChassisLook, Corner, Debris, Kart, Kicker, News, PartName, PartState, Phase, Spring, Wheel } from '../components.ts';
import { callOut, DAMAGE, struck } from '../damage.ts';
import { TRACKS } from '../courses.ts';
import { rotate, unrotate, v3 } from '../kart-math.ts';
import { LooseBody, LooseShell, Splinter } from '../prefabs.ts';
import { SIGNATURES, type Signature } from '../signatures.ts';
import { dropWheel } from '../shed.ts';
import { burst } from '../burst.ts';
import { sparks } from '../sparks.ts';

/** Knocks softer than this do nothing at all: `damage.ts`' light. */
const FELT = DAMAGE.light;
/** A knock this hard (m/s) is heard, felt or not. */
const BUMP_HEARD = 0.8;
/** A knock along the kart's own up (within this, as a cosine) is its underside on the road; forgiven this much (m/s). */
const UNDERSIDE = 0.75;
const SCRAPE = 3.5;
/** The most splinters one knock sends flying, and the wear a rollover does (a share of what the chassis takes). */
const SPLINTERS = 9;
const ROLLED = 0.35;
/** Seconds a piece of news is fresh: a newer one waits that long before it may take its place. */
const NEWS_FRESH = 2.4;
/** A body knocked off: the chunks it shatters into (many, and big: BODY_CHUNK times the debris model, panels not
 * crumbs), how hard they fly (and more the harder the knock), and the grey of its scuffed underside. */
const BODY_SHARDS = 56;
const BODY_CHUNK = 1.5;
const BODY_BURST = 3.5;
const SCUFF = 0x8a8f96;
/** Every knock on the bodywork chips this many bits off it at most, each this big (over the debris model). */
const BODY_CHIPS = 12;
const CHIP_SIZE = 0.85;
/** Flipped over this far (its up pointing this far down), the kart is destroyed: its bodywork breaks up -- as hard as a
 * knock this fast at least -- and it is wrecked. */
const FLIPPED = -0.3;
const FLIP_BURST = 5;

const local = v3();

export function impacts(world: World): void {
  const hits = world.events(CollisionEnter);
  world.system({
    name: 'impacts',
    rate: 60,
    after: ['vehicle'],
    read: [Transform, Hierarchy, optional(Build)],
    write: [Kart, RigidBody, optional(Wheel), optional(Breakable), optional(Render), optional(BodyBit)],
    update(ctx, [at, tree, build], [kart, rb, wheel, breakable, look, bodyBits]) {
      const { members, count, cmd, has, deref } = ctx;
      for (let n = 0; n < count; n++) {
        const e = members[n];
        if (kart.phase[e] !== Phase.racing && kart.phase[e] !== Phase.finished) continue;
        // Upside down: rolled -- unless over a ramp, whose grace forgives it (it is levelling itself to land).
        if (kart.upY[e] < -0.1 && kart.grace[e] <= 0 && !kart.ejected[e] && kart.thrown[e] === Cause.none) {
          kart.thrown[e] = Cause.rolled;
          kart.rollovers[e]++;
          if (kart.rolledAt[e] < 0) {
            const t = TRACKS[Math.min(kart.course[e]!, TRACKS.length - 1)]!;
            kart.rolledAt[e] = (kart.progress[e]! - t.start) / Math.max(1, t.finish - t.start);
          }
          if (!kart.wrecked[e]) kart.damage[e] += kart.hp[e] * ROLLED;
          kart.causeSpeed[e] = kart.speed[e];
        }
        // A wheel bashed into a wall (`vehicle` noted it): the body's bit facing it, if hard enough -- a sideswipe meets
        // the wall with the wheels first, so this is how a fin comes off.
        if (kart.bashInto[e] > 0) {
          if (kart.bodyOn[e] && !kart.wrecked[e] && kart.grace[e] <= 0) {
            knockBits(ctx, tree, at, rb, look, bodyBits, e, Math.min(build ? build.body[e] : 0, BODY.length - 1), kart.bashFacing[e], kart.bashInto[e]);
          }
          kart.bashInto[e] = 0;
        }
        // Flipped over onto its back: destroyed. The bodywork under it all is crushed and breaks up, it takes all the
        // damage it can, and it is wrecked (`wear`: every wheel and spring off, the chassis in bits, the driver thrown).
        if (kart.upY[e] < FLIPPED && kart.grace[e] <= 0 && !kart.wrecked[e]) {
          if (kart.bodyOn[e]) shatterBody(ctx, tree, build, look, at, rb, kart, e, Math.max(kart.speed[e], FLIP_BURST));
          kart.damage[e] = Math.max(kart.damage[e], kart.hp[e]);
          kart.smash[e] = 1;
          if (kart.thrown[e] === Cause.none && !kart.ejected[e]) kart.thrown[e] = Cause.rolled;
        }
      }

      for (let i = hits.begin(ctx); i < hits.end; i++) {
        const a = deref(hits.a[i]);
        const b = deref(hits.b[i]);
        const e = a !== NONE && has(a, Kart) ? a : b !== NONE && has(b, Kart) ? b : NONE;
        if (e === NONE) continue;
        if (kart.phase[e] !== Phase.racing && kart.phase[e] !== Phase.finished) continue;
        if (kart.wrecked[e]) continue;
        const qx = at.qx[e], qy = at.qy[e], qz = at.qz[e], qw = at.qw[e];
        {
          const other = a === e ? b : a;
          if (other !== NONE && has(other, Debris)) continue;
          // Heard: every knock against something on the course -- not a ramp, nor the road under it.
          if (other === NONE || !has(other, Kicker)) {
            const bump = Math.max(hits.speed[i], hits.impulse[i] / Math.max(1, kart.mass[e]));
            const ux = 2 * (qx * qy - qw * qz), uy = 1 - 2 * (qx * qx + qz * qz), uz = 2 * (qy * qz + qw * qx);
            const below = Math.abs(hits.normalX[i] * ux + hits.normalY[i] * uy + hits.normalZ[i] * uz) > UNDERSIDE;
            const moves = other !== NONE && has(other, RigidBody) && rb.mass[other] > 0;
            if (bump >= BUMP_HEARD && (!below || moves)) {
              kart.bumps[e]++;
              kart.bumpSpeed[e] = bump;
              kart.bumpSoft[e] = other !== NONE && has(other, Breakable) ? 1 : 0;
            }
          }
          // A hay bale hit hard bursts (`props` does it): it takes the knock, and the kart feels none of it.
          if (other !== NONE && has(other, Breakable) && !breakable.broken[other]) {
            if (hits.speed[i] > breakable.struck[other]) breakable.struck[other] = hits.speed[i];
            if (hits.speed[i] >= breakable.strength[other]) continue;
          }
          // Over a ramp -- knocking against it, or in its grace off it -- nothing comes of a knock.
          if (kart.grace[e] > 0 || (other !== NONE && has(other, Kicker))) continue;
          // The knock the kart feels: its own change of speed. A wall (or anything without a body) takes the whole
          // closing speed; a bin a tenth of the kart's weight barely nudges it.
          const otherMass = other !== NONE && has(other, RigidBody) ? rb.mass[other] : 0;
          const share = otherMass > 0 ? otherMass / (otherMass + kart.mass[e]) : 1;
          // The closing speed the physics reports is the bodies' after the knock is solved -- against a wall, near
          // nothing -- so the contact's impulse says how hard it was too: the kart's change of speed along the normal.
          let speed = Math.max(hits.speed[i] * share, hits.impulse[i] / Math.max(1, kart.mass[e]));
          // The underside scraping the road (the knock from below it, against nothing that moves): a steep dip
          // bottoming it out, forgiven SCRAPE of it -- a wall, a prop or a fall on its side is felt in full.
          const ux = 2 * (qx * qy - qw * qz), uy = 1 - 2 * (qx * qx + qz * qz), uz = 2 * (qy * qz + qw * qx);
          const fromBelow = Math.abs(hits.normalX[i] * ux + hits.normalY[i] * uy + hits.normalZ[i] * uz) > UNDERSIDE;
          if (otherMass === 0 && fromBelow) speed -= SCRAPE;
          if (speed < FELT) continue;
          unrotate(qx, qy, qz, qw, hits.pointX[i] - at.px[e], hits.pointY[i] - at.py[e], hits.pointZ[i] - at.pz[e], local);
          // Which side took it (a scrape from below takes no side).
          if (!fromBelow) {
            kart.hitSide[e] = Math.max(-1, Math.min(1, local.x / Math.max(0.1, kart.halfTrack[e])));
            kart.hitEnd[e] = Math.max(-1, Math.min(1, local.z / Math.max(0.1, kart.halfBase[e])));
          }

          // Wear: every knock past what is felt, and splinters off it -- more the harder it was (`wear` does the rest).
          const hurt = speed - FELT;
          // Metal on the wall: sparks off the point it struck.
          sparks(cmd, hits.pointX[i], hits.pointY[i], hits.pointZ[i], rb.velocityX[e] * 0.4 + hits.normalX[i] * 2, 0, rb.velocityZ[e] * 0.4 + hits.normalZ[i] * 2,
            Math.min(16, 3 + Math.round(hurt * 2)), 1 + Math.min(1.5, hurt * 0.15), i * 13 + Math.round(kart.clock[e] * 60), at.py[e] - kart.rideY[e]);
          const tint = CHASSIS[Math.min(build.chassis[e], CHASSIS.length - 1)]!.colour;
          if (!kart.wrecked[e]) kart.damage[e] += hurt;
          // One massive knock -- harder than its chassis can take at all -- and it is in bits (`wear`).
          if (speed >= DAMAGE.wreckKnock + kart.hp[e]) kart.smash[e] = 1;
          const bits = Math.min(SPLINTERS, 1 + Math.floor(hurt / 2));
          for (let s = 0; s < bits; s++) {
            const bit = cmd.instantiate(Splinter);
            if (bit === NONE) break;
            const bat = cmd.init(bit, Transform);
            bat.px[bit] = hits.pointX[i];
            bat.py[bit] = hits.pointY[i] + 0.15;
            bat.pz[bit] = hits.pointZ[i];
            const brb = cmd.init(bit, RigidBody);
            // Off the hit, back the way the kart came from it, scattered.
            const spread = s - (bits - 1) / 2;
            brb.startVelocityX[bit] = rb.velocityX[e] * 0.5 + hits.normalX[i] * 2 + spread * 1.3;
            brb.startVelocityY[bit] = 2 + s * 0.6;
            brb.startVelocityZ[bit] = rb.velocityZ[e] * 0.5 + hits.normalZ[i] * 2 - spread * 1.1;
            cmd.init(bit, Render).tint[bit] = tint;
          }

          // The driver.
          if (speed > kart.seatGrip[e] && !kart.ejected[e] && kart.thrown[e] === Cause.none) {
            kart.thrown[e] = Cause.thrownKnock;
            kart.causeSpeed[e] = speed;
          }
          // The part it hit: the wheel at the nearest corner within reach, else the bodywork.
          const clock = kart.clock[e];
          let struckWheel = 0;
          let nearest = DAMAGE.cornerReach * DAMAGE.cornerReach;
          for (let c = tree.firstChild[e]; c !== 0; c = tree.nextSibling[c]) {
            if (!has(c, Wheel) || !wheel.attached[c]) continue;
            const k = wheel.corner[c];
            const dx = local.x - (k === Corner.fl || k === Corner.rl ? 1 : -1) * kart.halfTrack[e];
            const dz = local.z - (k === Corner.fl || k === Corner.fr ? 1 : -1) * kart.halfBase[e];
            const near = dx * dx + dz * dz;
            if (near <= nearest) {
              nearest = near;
              struckWheel = c;
            }
          }
          if (struckWheel !== 0) {
            const c = struckWheel as Entity;
            const k = wheel.corner[c];
            const was = wheel.state[c];
            const now = struck(was, wheel.stateAt[c], clock, speed, DAMAGE.light, kart.strength[e] * DAMAGE.wheelSevere);
            if (now === was) continue;
            wheel.state[c] = now;
            wheel.stateAt[c] = clock;
            kart.hurts[e]++;
            if (kart.onCut[e]) kart.cutHurt[e] |= 1 << wheel.corner[c]!;
            callOut(kart, e, PartName.wheelFL + k, now);
            if (now === PartState.damaged) {
              // Bent: drawn leant and buckled; `vehicle` makes it pull (a front) or slide (a rear).
              const front = k === Corner.fl || k === Corner.fr;
              wheel.bent[c] = Math.max(wheel.bent[c], front ? DAMAGE.frontBentLook : DAMAGE.rearBentLook);
              if (kart.news[e] !== News.lostWheel || clock - kart.newsAt[e] > NEWS_FRESH) {
                kart.news[e] = News.bent;
                kart.newsAt[e] = clock;
              }
              continue;
            }
            // Failed: off it comes, rolling away; the kart limps on three.
            wheel.attached[c] = 0;
            kart.wheelsLost[e]++;
            kart.cause[e] = Cause.wheelKnock;
            kart.causeSpeed[e] = speed;
            kart.news[e] = News.lostWheel;
            kart.newsAt[e] = clock;
            if (!has(c, Hidden)) cmd.add(c, Hidden);
            const loose = dropWheel(cmd, at, look, wheel, e, c);
            if (loose === NONE) continue;
            const lrb = cmd.init(loose, RigidBody);
            lrb.startVelocityX[loose] = rb.velocityX[e] + hits.normalX[i] * 3;
            lrb.startVelocityY[loose] = 4.5;   // boing: off it bounces, spinning like a top
            lrb.startSpinX[loose] = 1100;
            lrb.startSpinY[loose] = 450;
            lrb.startVelocityZ[loose] = rb.velocityZ[e] + hits.normalZ[i] * 3;
            continue;
          }
          // The bodywork: bits chip off every knock; a meaningful one dents it (damaged), the next -- or a severe one --
          // knocks it off (failed). Cosmetic: it changes nothing of the driving.
          if (!kart.bodyOn[e]) continue;
          const bo = BODY[Math.min(build ? build.body[e] : 0, BODY.length - 1)]!;
          burst(cmd, {
            x: hits.pointX[i], y: hits.pointY[i] + 0.2, z: hits.pointZ[i], spread: 0.3,
            vx: rb.velocityX[e] * 0.5, vy: rb.velocityY[e], vz: rb.velocityZ[e] * 0.5,
            power: 2 + hurt * 0.3, count: Math.min(BODY_CHIPS, 3 + Math.floor(hurt * 1.5)),
            colours: bo.debris ?? [tint, SCUFF], size: CHIP_SIZE, seed: e * 13 + Math.round(clock * 60), bolts: false,
          });
          // A bit of it that comes off on its own (`BODY`'s bits): the one facing the knock, if it was hard enough --
          // the front, the back, or that side (its left +x) -- off, tumbling away.
          if (bo.bits) {
            const end = local.z / Math.max(0.1, kart.halfBase[e]);
            knockBits(ctx, tree, at, rb, look, bodyBits, e, Math.min(build ? build.body[e] : 0, BODY.length - 1), end > BIT_END ? 1 : end < -BIT_END ? 2 : local.x >= 0 ? 3 : 4, speed);
          }
          const was = kart.bodyState[e];
          const now = struck(was, kart.bodyAt[e], clock, speed, DAMAGE.light, DAMAGE.light + kart.bodyStrength[e] * DAMAGE.bodySevere);
          if (now === was) continue;
          kart.hurts[e]++;
          if (now === PartState.damaged) {
            kart.bodyState[e] = now;
            kart.bodyAt[e] = clock;
            kart.bodyDamage[e] = Math.max(kart.bodyDamage[e], DAMAGE.bodyDentLook);
            callOut(kart, e, PartName.body, now);
          } else {
            shatterBody(ctx, tree, build, look, at, rb, kart, e, speed);
          }
        }
      }
    },
  });
}

type Ctx = Pick<SystemContext, 'cmd' | 'has'>;

/** Each body's wreck (`<model>_wreck`, authored with it by `_wreck.lua`: the same pieces, the upper body torn away), by
 * `BODY`'s order; NO_WRECK for a body that has none (nothing, or a bolted-on part that goes whole). */
const NO_WRECK = 0;
/** Each body's signature piece's model (`signatures.ts`), in `BODY`'s order; NO_WRECK where it has none. */
const SIG_MODEL = BODY.map((b) => (SIGNATURES[b.name]?.at && b.model !== '' ? internKey('Model', `${b.model}_sig`) : NO_WRECK));
/** A signature piece leaves this much faster than the kart, m/s along it (and at least this fast), and this far up. */
const SIG_AHEAD = 3.5;
const SIG_LEAST = 7;
const SIG_UP = 1.5;
const SIG_MASS = 12;
/** A flung one: tossed this fast up and this fast out to its side (m/s), keeping this share of the kart's speed, light. */
const FLING_UP = 6;
const FLING_OUT = 2.5;
const FLING_KEEP = 0.7;
const FLING_MASS = 3;
const sigAt = v3();
const sigFwd = v3();

const WRECK_MODEL = BODY.map((b) => (b.cover && b.model !== '' ? internKey('Model', `${b.model}_wreck`) : NO_WRECK));

/** A knock this far along the kart's wheelbase from its middle (a share of its half) is to its front or its rear; nearer
 * the middle, to a side. */
const BIT_END = 0.55;
/** Each body's bits as they fly off: their centred models (`<model>_<part>_loose`) and how they go (tossed up and out,
 * as a signature piece flung: where they sat, their size), by BODY index and slot. */
const BIT_LOOSE = BODY.map((b) => (b.bits ?? []).map((bit) => internKey('Model', `${b.model}_${bit.part}_loose`)));
const BIT_SIG: readonly (readonly Signature[])[] = BODY.map((b) => (b.bits ?? []).map((bit) => ({ at: bit.at, size: bit.size, leave: 'fling' as const, caption: '' })));

/** The faces of the kart a knock can meet (`Kart.bashFacing`'s numbers): its front, its rear, its left, its right. */
const FRONT = 1, REAR = 2, LEFT = 3;

/**
 * A knock at `speed` m/s to the kart's `facing` face: the first of its body's bits still on that faces it -- the front,
 * the rear, or that side -- and was knocked hard enough for it (`BodyBitPart.harder` past a light knock), off.
 */
function knockBits(
  ctx: Ctx,
  tree: Store<typeof Hierarchy.schema>,
  at: Store<typeof Transform.schema>,
  rb: Store<typeof RigidBody.schema>,
  look: Store<typeof Render.schema>,
  bodyBits: Store<typeof BodyBit.schema>,
  e: Entity,
  which: number,
  facing: number,
  speed: number,
): void {
  const bits = BODY[which]!.bits;
  if (!bits) return;
  const hit = facing === FRONT ? 'front' : facing === REAR ? 'rear' : 'side';
  const side = facing === LEFT ? 1 : -1;
  for (let c = tree.firstChild[e]!; c !== 0; c = tree.nextSibling[c]!) {
    if (!ctx.has(c as Entity, Bodywork)) continue;
    for (let s = tree.firstChild[c]!; s !== 0; s = tree.nextSibling[s]!) {
      if (!ctx.has(s as Entity, BodyBit) || bodyBits.off[s]) continue;
      const bit = bits[bodyBits.slot[s]!];
      if (!bit || bit.hit !== hit || (bit.side !== undefined && bit.side !== side)) continue;
      if (speed < DAMAGE.light + bit.harder) continue;
      bodyBits.off[s] = 1;
      knockBit(ctx.cmd, ctx.has, at, rb, e, c as Entity, s as Entity, which, bodyBits.slot[s]!, look.tint[c]!);
      return;
    }
  }
}

/** Bit `s` (slot `slot` of the body `c` on kart `e`) knocked off: out of sight on the kart, and tumbling away. */
function knockBit(
  cmd: Ctx['cmd'],
  has: Ctx['has'],
  at: Store<typeof Transform.schema>,
  rb: Store<typeof RigidBody.schema>,
  e: Entity,
  c: Entity,
  s: Entity,
  which: number,
  slot: number,
  tint: number,
): void {
  if (!has(s, Hidden)) cmd.add(s, Hidden);
  const sig = BIT_SIG[which]![slot];
  const model = BIT_LOOSE[which]![slot];
  if (sig && model !== undefined) signature(cmd, at, rb, e, c, sig, model, tint);
}

/**
 * The bodywork comes off, shattered: shards of it everywhere in its own colours, from all over it, harder the harder it
 * went. A body that is the whole kart leaves its wreck on it (WRECK_MODEL: the base, the seat, torn stumps -- what is
 * left matching what flew off); a bolted-on part goes whole. And at that same tick the kart drives as it now is: the
 * bodywork's weight off it, its drag, its lift (wings), its boost and its padding gone (`assemble` put them on; a
 * restart builds it all again from the garage).
 */
export function shatterBody(
  { cmd, has }: Ctx,
  tree: Store<typeof Hierarchy.schema>,
  build: Store<typeof Build.schema>,
  look: Store<typeof Render.schema>,
  at: Store<typeof Transform.schema>,
  rb: Store<typeof RigidBody.schema>,
  kart: Store<typeof Kart.schema>,
  e: Entity,
  speed: number,
): void {
  kart.bodyOn[e] = 0;
  kart.bodyLost[e]++;
  if (kart.bodyState[e] !== PartState.failed) {
    kart.bodyState[e] = PartState.failed;
    kart.bodyAt[e] = kart.clock[e]!;
    callOut(kart, e, PartName.body, PartState.failed);
  }
  kart.cause[e] = Cause.bodyKnock;
  kart.causeSpeed[e] = speed;
  kart.news[e] = News.lostBody;
  kart.newsAt[e] = kart.clock[e]!;
  const which = Math.min(has(e, Build) ? build.body[e]! : 0, BODY.length - 1);
  const bo = BODY[which]!;
  const wreck = WRECK_MODEL[which]!;
  // The handling, as the kart now is.
  kart.mass[e] = Math.max(1, kart.mass[e]! - bo.mass);
  rb.mass[e] = Math.max(1, rb.mass[e]! - bo.mass);
  kart.drag[e] = Math.max(0.02, kart.drag[e]! - bo.drag);
  kart.wing[e] = 0;
  kart.thrust[e] = 0;
  kart.seatGrip[e] = Math.max(0, kart.seatGrip[e]! - bo.cushion);
  for (let c = tree.firstChild[e]!; c !== 0; c = tree.nextSibling[c]!) {
    // A body that was the whole kart with no wreck of its own leaves its chassis showing (its wreck stands on it).
    // The body's see-through piece goes with it.
    if (has(c as Entity, BodyGlass)) {
      if (!has(c as Entity, Hidden)) cmd.add(c as Entity, Hidden);
      continue;
    }
    if (has(c as Entity, ChassisLook) || has(c as Entity, Spring)) {
      if (bo.cover && (wreck === NO_WRECK || has(c as Entity, Spring)) && has(c as Entity, Hidden)) cmd.remove(c as Entity, Hidden);
      continue;
    }
    if (!has(c as Entity, Bodywork)) continue;
    if (wreck !== NO_WRECK) look.model[c] = wreck;
    else if (!has(c as Entity, Hidden)) cmd.add(c as Entity, Hidden);
    // Its bits still on it go with it, each tumbling off its own way (their slots in order under it: bit0, bit1 ...).
    let slot = 0;
    for (let s = tree.firstChild[c]!; s !== 0; s = tree.nextSibling[s]!) {
      if (!has(s as Entity, BodyBit)) continue;
      if (slot < (bo.bits?.length ?? 0) && !has(s as Entity, Hidden)) knockBit(cmd, has, at, rb, e, c as Entity, s as Entity, which, slot, look.tint[c]!);
      slot++;
    }
    const sig = SIGNATURES[bo.name];
    if (sig && SIG_MODEL[which] !== NO_WRECK) signature(cmd, at, rb, e, c as Entity, sig, SIG_MODEL[which]!, look.tint[c]!);
    burst(cmd, {
      x: at.px[e]!, y: at.py[e]! + kart.halfHeight[e]! + 0.3, z: at.pz[e]!, spread: 1.0,
      vx: rb.velocityX[e]!, vy: rb.velocityY[e]!, vz: rb.velocityZ[e]!,
      power: BODY_BURST + speed * 0.35, count: BODY_SHARDS,
      colours: bo.debris ?? [look.tint[c]!, SCUFF], size: BODY_CHUNK, seed: e + kart.bodyLost[e]! * 31,
    });
  }
}

/**
 * A body's signature piece off (`SIGNATURES`): made where it sat on the kart, as the kart is turned, and sent off down
 * the road ahead of it -- faster than the kart, so it overtakes -- rolling (a ball the size of it) or sliding (a box).
 */
function signature(
  cmd: Ctx['cmd'],
  at: Store<typeof Transform.schema>,
  rb: Store<typeof RigidBody.schema>,
  e: Entity,
  c: Entity,
  sig: Signature,
  model: number,
  tint: number,
): void {
  const qx = at.qx[e]!, qy = at.qy[e]!, qz = at.qz[e]!, qw = at.qw[e]!;
  // The body's own scale, each axis (a natural body is stretched to its chassis: assemble).
  const gx = at.sx[c] || 1, gy = at.sy[c] || 1, gz = at.sz[c] || 1;
  const piece = sig.leave === 'roll' ? cmd.instantiate(LooseShell) : cmd.instantiate(LooseBody);
  if (piece === NONE) return;
  const sa = sig.at ?? [0, 0, 0];
  rotate(qx, qy, qz, qw, at.px[c]! + sa[0] * gx, at.py[c]! + sa[1] * gy, at.pz[c]! + sa[2] * gz, sigAt);
  rotate(qx, qy, qz, qw, 0, 0, 1, sigFwd);
  const t = cmd.init(piece, Transform);
  t.px[piece] = at.px[e]! + sigAt.x;
  t.py[piece] = at.py[e]! + sigAt.y + 0.05;
  t.pz[piece] = at.pz[e]! + sigAt.z;
  // Turned about its own up first, if it says so (a hoop side on): the kart's turn × that.
  const half = ((sig.yaw ?? 0) * Math.PI) / 360, ys = Math.sin(half), yc = Math.cos(half);
  t.qx[piece] = qx * yc - qz * ys;
  t.qy[piece] = qy * yc + qw * ys;
  t.qz[piece] = qz * yc + qx * ys;
  t.qw[piece] = qw * yc - qy * ys;
  // Turned side on (a yaw), its x and z scales swap with it.
  const side = Math.abs(Math.sin(half * 2)) > 0.7;
  t.sx[piece] = side ? gz : gx; t.sy[piece] = gy; t.sz[piece] = side ? gx : gz;
  const view = cmd.init(piece, Render);
  view.model[piece] = model;
  view.tint[piece] = tint;
  // Along the road, faster than the kart: its speed along its nose and a push more, flat.
  const vx = rb.velocityX[e]!, vy = rb.velocityY[e]!, vz = rb.velocityZ[e]!;
  const along = Math.max(SIG_LEAST, vx * sigFwd.x + vy * sigFwd.y + vz * sigFwd.z + SIG_AHEAD);
  const flat = Math.max(0.01, Math.hypot(sigFwd.x, sigFwd.z));
  const dx = sigFwd.x / flat, dz = sigFwd.z / flat;
  const prb = cmd.init(piece, RigidBody);
  const size = sig.size ?? [0.3, 0.3, 0.3];
  prb.mass[piece] = SIG_MASS;
  prb.startVelocityX[piece] = dx * along;
  prb.startVelocityY[piece] = Math.max(vy, 0) + SIG_UP;
  prb.startVelocityZ[piece] = dz * along;
  if (sig.leave === 'fling') {
    // Up and out to the side it sat on (the middle: either, by the kart), tumbling, keeping some of the kart's speed.
    const side = (sig.at?.[0] ?? 0) > 0.05 ? 1 : (sig.at?.[0] ?? 0) < -0.05 ? -1 : e % 2 ? 1 : -1;
    rotate(qx, qy, qz, qw, side, 0, 0, sigAt);
    prb.mass[piece] = FLING_MASS;
    prb.startVelocityX[piece] = vx * FLING_KEEP + sigAt.x * FLING_OUT;
    prb.startVelocityY[piece] = Math.max(vy, 0) + FLING_UP;
    prb.startVelocityZ[piece] = vz * FLING_KEEP + sigAt.z * FLING_OUT;
    prb.startSpinX[piece] = 520 * side;
    prb.startSpinY[piece] = 300;
    prb.startSpinZ[piece] = -410;
    const box = cmd.init(piece, BoxCollider);
    box.sizeX[piece] = Math.max(0.08, size[0]);
    box.sizeY[piece] = Math.max(0.08, size[1]);
    box.sizeZ[piece] = Math.max(0.08, size[2]);
    box.centerX[piece] = 0;
    box.centerY[piece] = 0;
    box.centerZ[piece] = 0;
  } else if (sig.leave === 'roll') {
    // Rolling, not skidding: turning at its speed over its radius, about the road's sideways (up × velocity) -- its
    // collider's radius in its own units (the engine scales it by the piece's largest scale), its turn by the world's.
    const r = Math.max(size[1], size[2]) * 0.5;
    cmd.init(piece, SphereCollider).radius[piece] = r;
    const spin = (along / (r * Math.max(gx, gy, gz))) * (180 / Math.PI);
    prb.startSpinX[piece] = dz * spin;
    prb.startSpinY[piece] = 0;
    prb.startSpinZ[piece] = -dx * spin;
  } else {
    const box = cmd.init(piece, BoxCollider);
    box.sizeX[piece] = Math.max(0.06, size[0]);
    box.sizeY[piece] = Math.max(0.06, size[1]);
    box.sizeZ[piece] = Math.max(0.06, size[2]);
    box.centerX[piece] = 0;
    box.centerY[piece] = 0;
    box.centerZ[piece] = 0;
    prb.startSpinX[piece] = 0;
    prb.startSpinY[piece] = (e % 2 ? 1 : -1) * 40;
    prb.startSpinZ[piece] = 0;
  }
}
