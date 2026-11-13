/**
 * crowd, 60 Hz, late: the village fete watching the run. Each spectator (`course` dresses them: grown-ups, children,
 * flag and placard fans, parents filming, pensioners in deck chairs, supporters in fancy dress, mechanics, marshals)
 * plays the driver library's fan clips (`_driver.lua`) as their sort would, at their own pace, out of step:
 *
 *   waiting       chatting, shifting their weight, sipping their tea, a flag or placard held up
 *   kart passing  heads turned to follow it, pointing, filming, flags waved
 *   a stunt       cheering, arms up, clapping (the children and the fancy dress jumping)
 *   a crash       flinching, ducking, hands on heads (the mechanics wincing)
 *   a recovery,
 *   the finish    jumping, waving
 *
 * Reactions are staggered -- each starts up to REACT_LAG seconds late, by its own beat -- and a few (MISSING of them)
 * miss the action entirely, chatting on. Those near the kart turn to follow it (no more than TURN either way, a seated
 * one SEATED_TURN). Pensioners sit in their chairs (the figure lowered by SEAT_DROP). Those far off
 * (`HIDE`) are not drawn at all: a few pixels each, hundreds of draws saved.
 */
import { Animation, Hidden, internKey, Transform, type World } from '@vibe/engine';
import { ChaseCam, Fan, FanRole, FarHide, Kart, News, Phase } from '../components.ts';
import { lowEnd } from '../device.ts';

/** Within this many metres of the kart they react to what it does; within this, it is passing them. */
const REACT = 55;
const NEAR = 30;
/** Further from the camera (the kart, with none) than this they are not drawn; back within SHOW, drawn again (apart, so none flickers at the edge). */
const HIDE = 70;
const SHOW = 64;
/** On a phone (`lowEnd`): hidden sooner, every figure a few thousand triangles. */
const HIDE_LOW = 45;
const SHOW_LOW = 40;
/** Seconds a reaction lasts after the news; the most a spectator's reaction lags it; the share who miss it all. */
const REACT_FOR = 2.6;
const REACT_LAG = 0.7;
const MISSING = 0.12;
/** Turning to follow the kart: the most either way (radians), seated; how fast (a share a second). */
const TURN = 0.8;
const SEATED_TURN = 0.3;
const TURN_RATE = 3;
/** A seated figure lowered this far (metres, at its model's size: times its scale), thighs level and feet on the ground, onto its chair. */
const SEAT_DROP = 0.26;
/** A jump's height (metres at its model's size: times its scale), and its bounces a second. */
const HOP = 0.13;
const HOPS = 2.2;

const clip = (name: string): number => internKey('Clip', name);
const IDLE = clip('fan_idle'), CHAT = clip('fan_chat'), HOLD = clip('fan_hold');
const POINT = clip('fan_point'), FILM = clip('fan_film'), FLAGWAVE = clip('fan_flagwave'), WAVE = clip('fan_wave');
const CHEER = clip('fan_cheer'), CLAP = clip('fan_clap'), FLINCH = clip('fan_flinch'), JUMP = clip('fan_jump');
const SIT = clip('fan_sit'), SIT_CLAP = clip('fan_sit_clap'), SIT_SIP = clip('fan_sit_sip');

const STUNTS: ReadonlySet<number> = new Set([News.bigAir, News.cleanChicane, News.reverseFinish, News.twoWheels, News.drift, News.airSpin, News.bonus, News.clearedDucks, News.spin, News.reversing]);
const CRASHES: ReadonlySet<number> = new Set([News.lostWheel, News.lostBody, News.thrown, News.lostSteering, News.bent, News.wrecked]);
const RECOVERIES: ReadonlySet<number> = new Set([News.righted, News.limpedHome, News.backIn]);

/** What is going on, as the crowd sees it. */
const Moment = { waiting: 0, passing: 1, stunt: 2, crash: 3, recovery: 4 } as const;
type Moment = (typeof Moment)[keyof typeof Moment];
const R = FanRole;

/** The crowd's people (`models/people`, polyperfect's Low Poly Animated People: every role but the pensioners in their
 * deck chairs) have six clips -- idle, chat, film, wave, jump, flinch -- and play the rest as the nearest of them. */
const PEOPLE_CLIP = new Map<number, number>([
  [HOLD, IDLE], [clip('fan_sip'), CHAT], [POINT, WAVE], [FLAGWAVE, WAVE], [CLAP, WAVE], [CHEER, JUMP],
]);

/** The clip for one of `role`, by its `beat` (0..1, its own), at `moment`. */
function clipFor(role: number, beat: number, moment: Moment): number {
  const seated = role === R.pensioner;
  switch (moment) {
    case Moment.stunt:
      if (seated) return SIT_CLAP;
      if (role === R.kid || role === R.costume) return JUMP;
      if (role === R.filmer) return FILM;
      if (role === R.flag || role === R.marshal) return FLAGWAVE;
      if (role === R.mechanic) return CLAP;
      return beat < 0.5 ? CHEER : CLAP;
    case Moment.crash:
      if (seated) return SIT;
      if (role === R.filmer) return FILM;
      if (role === R.kid) return beat < 0.5 ? POINT : FLINCH;
      return beat < 0.8 ? FLINCH : POINT;
    case Moment.recovery:
      if (seated) return SIT_CLAP;
      if (role === R.flag || role === R.marshal) return FLAGWAVE;
      if (role === R.filmer) return FILM;
      return beat < 0.55 ? JUMP : WAVE;
    case Moment.passing:
      if (seated) return beat < 0.5 ? SIT_CLAP : SIT;
      if (role === R.filmer) return FILM;
      if (role === R.flag || role === R.marshal) return FLAGWAVE;
      if (role === R.placard) return HOLD;
      if (role === R.costume) return CHEER;
      if (role === R.mechanic) return IDLE;
      if (role === R.kid) return beat < 0.5 ? POINT : JUMP;
      return beat < 0.3 ? POINT : beat < 0.65 ? CLAP : WAVE;
    default:
      if (seated) return beat < 0.6 ? SIT_SIP : SIT;
      if (role === R.flag || role === R.placard) return beat < 0.5 ? HOLD : CHAT;
      if (role === R.mechanic || role === R.marshal || role === R.kid) return IDLE;
      return beat < 0.45 ? CHAT : IDLE;
  }
}

/** Scenery (`FarHide`) further from the camera than this is not drawn; back within FAR_SHOW, drawn again -- the
 * small props' own, nearer than the crowd's: a bale or a barrier is a few pixels by then, and each is a draw. Checked this
 * often a second: it moves slowly past. */
const FAR_HIDE = 55;
const FAR_SHOW = 50;
const FAR_HIDE_LOW = 42;
const FAR_SHOW_LOW = 38;
const FAR_RATE = 5;

export function farHide(world: World): void {
  const karts = world.query({ with: [Kart, Transform] });
  const cams = world.query({ with: [ChaseCam, Transform] });
  world.system({
    name: 'far-hide',
    rate: FAR_RATE,
    with: [FarHide],
    read: [Transform],
    update({ members, count, cmd, has }, [at]) {
      if (karts.count === 0) return;
      const c = cams.count > 0 ? cams.members[0]! : karts.members[0]!;
      const cx = at.px[c]!, cy = at.py[c]!, cz = at.pz[c]!;
      const low = lowEnd(), farOut = low ? FAR_HIDE_LOW : FAR_HIDE, farIn = low ? FAR_SHOW_LOW : FAR_SHOW;
      for (let n = 0; n < count; n++) {
        const e = members[n]!;
        // Every way, up and down too: a burst bale parked far under the course (`props`) stays hidden.
        const dx = at.px[e]! - cx, dy = at.py[e]! - cy, dz = at.pz[e]! - cz;
        const d2 = dx * dx + dy * dy + dz * dz;
        const hidden = has(e, Hidden);
        if (!hidden && d2 > farOut * farOut) cmd.add(e, Hidden);
        else if (hidden && d2 < farIn * farIn) cmd.remove(e, Hidden);
      }
    },
  });
}

export function crowd(world: World): void {
  const karts = world.query({ with: [Kart, Transform] });
  // Measured from the camera: the flyover before a run passes crowds far from the kart.
  const cams = world.query({ with: [ChaseCam, Transform] });
  const kartStore = world.store(Kart);
  world.system({
    name: 'crowd',
    rate: 60,
    with: [Fan],
    write: [Fan, Animation, Transform],
    lateUpdate({ members, count, cmd, has, time }, _read, [fan, anim, at]) {
      if (karts.count === 0) return;
      const kart = karts.members[0]!;
      const c = cams.count > 0 ? cams.members[0]! : kart;
      const cx = at.px[c]!, cz = at.pz[c]!;
      const kx = at.px[kart]!, kz = at.pz[kart]!;
      const low = lowEnd(), hide = low ? HIDE_LOW : HIDE, show = low ? SHOW_LOW : SHOW;
      // The run's latest news, and how long ago.
      const racing = kartStore.phase[kart] === Phase.racing || kartStore.phase[kart] === Phase.finished;
      const since = kartStore.clock[kart]! - kartStore.newsAt[kart]!;
      const news = kartStore.news[kart]!;
      const finished = kartStore.phase[kart] === Phase.finished;
      const event: Moment = !racing ? Moment.waiting : finished ? Moment.recovery : since >= 0 && since < REACT_FOR
        ? STUNTS.has(news) ? Moment.stunt : CRASHES.has(news) ? Moment.crash : RECOVERIES.has(news) ? Moment.recovery : Moment.waiting
        : Moment.waiting;
      for (let n = 0; n < count; n++) {
        const e = members[n];
        if (!fan.placed[e]) {
          fan.placed[e] = 1;
          fan.baseY[e] = at.py[e];
          fan.baseYaw[e] = 2 * Math.atan2(at.qy[e], at.qw[e]);
          fan.yaw[e] = fan.baseYaw[e];
          fan.beat[e] = Math.abs((Math.sin(e * 12.9898) * 43758.5453) % 1);
          // Each out of step with the next.
          anim.time[e] = fan.beat[e] * 3;
        }
        const dx = at.px[e] - cx, dz = at.pz[e] - cz;
        const d2 = dx * dx + dz * dz;
        const hidden = has(e, Hidden);
        // Out of sight: not drawn, and their animation stopped (the engine steps every playing clip, seen or not).
        if (!hidden && d2 > hide * hide) {
          cmd.add(e, Hidden);
          anim.speed[e] = 0;
        } else if (hidden && d2 < show * show) {
          cmd.remove(e, Hidden);
          anim.speed[e] = 0.85 + fan.beat[e] * 0.3;
        }
        if (hidden) continue;
        const role = fan.role[e];
        const beat = fan.beat[e];
        const seated = role === R.pensioner;
        const kdx = kx - at.px[e], kdz = kz - at.pz[e];
        const k2 = kdx * kdx + kdz * kdz;
        // What this one makes of the moment: the news (if near enough, not one who misses it, past their own lag),
        // else the kart going by, else waiting.
        let moment: Moment = Moment.waiting;
        if (event !== Moment.waiting && k2 < REACT * REACT && beat > MISSING && (finished || since > beat * REACT_LAG)) moment = event;
        else if (racing && k2 < NEAR * NEAR && beat > MISSING * 0.5) moment = Moment.passing;
        const asked = clipFor(role, beat, moment);
        const want = seated ? asked : PEOPLE_CLIP.get(asked) ?? asked;
        if (anim.clip[e] !== want) {
          anim.clip[e] = want;
          anim.speed[e] = 0.85 + beat * 0.3;
        }
        // Heads turned to follow the kart while it is near: the whole figure turned a little, eased.
        const turn = seated ? SEATED_TURN : TURN;
        let to = fan.baseYaw[e];
        if (racing && k2 < REACT * REACT) {
          let off = Math.atan2(kdx, kdz) - fan.baseYaw[e];
          off = Math.atan2(Math.sin(off), Math.cos(off));
          to += Math.max(-turn, Math.min(turn, off));
        }
        fan.yaw[e] += (to - fan.yaw[e]) * Math.min(1, TURN_RATE / 60);
        at.qx[e] = 0;
        at.qy[e] = Math.sin(fan.yaw[e] / 2);
        at.qz[e] = 0;
        at.qw[e] = Math.cos(fan.yaw[e] / 2);
        // Sitting down in the chair; jumping, up off the ground on the beat.
        const h = at.sy[e];
        // (The people's own jump clip leaves the ground by itself: the bounce only for a seated figure's, which has none.)
        const hop = want === JUMP && seated ? Math.abs(Math.sin((time * HOPS + beat) * Math.PI)) * HOP * h : 0;
        at.py[e] = fan.baseY[e] - (seated ? SEAT_DROP * h : 0) + hop;
      }
    },
  });
}
