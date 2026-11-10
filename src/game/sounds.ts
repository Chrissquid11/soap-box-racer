/**
 * The run's sound (a page-side install, `index.ts`' installs: render, never the simulation): what the kart is doing,
 * heard -- the procedurally made sounds of scripts/sounds.ts.
 *
 *   scrape     a bare axle on the road, while a wheel is gone and it is moving
 *   knock      a light knock (the kart jolted, nothing hurt); crash, a heavy one (a part damaged, or worse)
 *   gasp       the crowd, after a big incident: a wheel or the bodywork off, the driver thrown, a wreck
 *   cheer      the crowd, after a big jump, the duck pond cleared, or the finish
 *   splash     into the duck pond
 *   skid       a loop: tyres skidding while it drifts (a recording)
 *   metal_hit  with the crash, a part hurt: sheet metal struck (a recording)
 *   clatter_a, clatter_b   a wheel or the steering off: metal clattering away (recordings, by turns)
 *   crack      the bodywork cracking off (a recording)
 *   crowd_cheer  the crowd cheering: at the start (the countdown, GO), big air, the pond cleared, the finish
 *   ambience   a loop: the English countryside (birds, a breeze), quietly under every run
 *   crowd_bed  a loop: the crowd chattering, up at the start and the end, low through the run
 *   (the start: the same crowd cheer as the finish, as the countdown starts and at GO)
 *   crowd_ooh, crowd_gasp  the crowd at a crash, a part off, a wreck, a run ended short
 *   (the crowd recordings are CC0, from Freesound: see AssetsSource/audio/CREDITS.md)
 *   wreck      wrecked: a real car crash, metal on metal (a recording, not one of scripts/sounds.ts')
 *   beep, go   the start: a beep as each red lamp comes on through the countdown, and GO as they all turn green
 *   chime      a bonus star collected
 *   (fanfare: the HUD plays it, over the line in the top three, and on results that open the next course)
 *   roar       the crowd's big roar: as the countdown begins, at GO, and over the line
 *   ooh        "ooooh!" then cheers and laughs: at a crash (a part hurt), at the run's end short of the line
 *   (no music: the garage and the menus are quiet, the race its own sounds)
 *
 * Nothing plays before the page's first gesture (the engine unlocks audio then), and the engine's one mute
 * (the HUD's sound button, a hidden tab) silences it all: this never touches either.
 */
import { Hierarchy, type World } from '@vibe/engine';
import { Audio, type PlayOptions, type SoundLoop } from '@vibe/engine/assets';
import { COUNTDOWN, Kart, News, Phase, RunOut, Wheel } from './components.ts';
import { soundLoops } from '../ui/live.ts';

/** The loops' loudness at full speed (m/s), and how loud each gets. */
const FULL_SPEED = 22;
const SCRAPE = 0.5;
/** The background (recordings, CC0 from Freesound): the countryside's loudness, and the crowd's chatter waiting at the
 * start, through the run and after it, and how fast it moves between them (a share a second). */
const AMBIENCE = 0.21;
const BED_WAIT = 0.18;
const BED_RUN = 0.04;
const BED_AFTER = 0.14;
const BED_EASE = 1.5;
/** The skid's loudness at full speed (a recording: AssetsSource/audio/sfx/skid.wav). */
const SKID = 0.6;
/** A jolt (`Kart.shake`'s rise in a frame) this big is a light knock. */
const KNOCK_JOLT = 0.25;
/** A knock against anything (`Kart.bumps`): heard from this loud, louder the harder (to all of it at BUMP_FULL m/s),
 * never two within BUMP_GAP seconds; past BUMP_METAL m/s, metal rings with it. */
const BUMP_QUIET = 0.25;
const BUMP_FULL = 8;
const BUMP_GAP = 0.08;
const BUMP_METAL = 4;
/** The crowd's "ooh" at a crash: never again within this many seconds. */
const OOH_GAP = 1.6;

/** The crowd's moments (every crowd_* recording: cheers, oohs, gasps), this loud against what is asked. */
const CROWD = 0.35;

const PLAY: PlayOptions = { volume: 1, rate: 1 };

export function kartSounds(world: World): () => void {
  const karts = world.query({ with: [Kart] });
  const kart = world.store(Kart);
  const wheel = world.store(Wheel);
  const tree = world.store(Hierarchy);
  let scrape: SoundLoop | null = null, skid: SoundLoop | null = null;
  // The background: the countryside (birds, a breeze) under every run, the crowd's chatter while they wait for the off.
  let ambience: SoundLoop | null = null, bed: SoundLoop | null = null, bedAt = 0, last = 0;
  let clatters = 0;
  let oohAt = -99;
  let bumps = 0, bumpAt = -99;
  let hurts = 0, shake = 0, newsAt = -99, phase = -1, out = 0, lamps = 0;
  const one = (key: AssetKeys.Sfx, volume: number, rate = 1): void => {
    PLAY.volume = key.startsWith('crowd_') ? volume * CROWD : volume;
    PLAY.rate = rate * (0.94 + Math.random() * 0.12);
    Audio.sfx(key, PLAY);
  };
  // Paused (the pause menu): every loop silent till the next frame sets it again (`ui/live.ts`' hushLoops).
  const hush = (): void => {
    if (scrape) scrape.volume = 0;
    if (skid) skid.volume = 0;
    if (ambience) ambience.volume = 0;
    if (bed) bed.volume = 0;
  };
  soundLoops.hush = hush;
  world.system({
    name: 'kart-sounds',
    phase: 'render',
    update() {
      if (karts.count === 0) return;
      const e = karts.members[0]!;
      // The loops, made once audio runs, their loudness set every frame.
      scrape ??= Audio.loop('scrape', 0);
      const p = kart.phase[e]!;
      const moving = p === Phase.racing || p === Phase.finished;
      const v = moving ? Math.min(1, kart.speed[e]! / FULL_SPEED) : 0;
      const grounded = kart.air[e] === 0;
      // (No rolling rumble and no damage rattle: both noise loops, they sounded like a badly tuned radio.)
      if (scrape) scrape.volume = kart.wheelsLost[e]! > 0 && grounded ? SCRAPE * Math.min(1, v * 3) : 0;
      // Tyres skidding while it slides sideways (a drift), on the road, louder the faster.
      skid ??= Audio.loop('skid', 0);
      ambience ??= Audio.loop('ambience', 0);
      bed ??= Audio.loop('crowd_bed', 0);
      // ... or braking hard enough to lock a wheel on the road.
      let locked = 0;
      for (let c = tree.firstChild[e]!; c !== 0; c = tree.nextSibling[c]!) {
        if (world.has(c, Wheel) && wheel.attached[c] && wheel.grounded[c] && wheel.locked[c]) locked++;
      }
      if (skid) skid.volume = grounded && (kart.driftFor[e]! > 0 || locked > 0) ? SKID * Math.min(1, v * 1.6) : 0;

      // (No constant background loops -- no wind, no crowd murmur: only what the kart does, and the crowd's moments.)
      const now = performance.now() / 1000;
      // The background, eased to how loud it is now: the countryside quietly under every run (none in the garage);
      // the crowd's chatter up while they wait at the start, low through the run, up again at the end.
      const dt = Math.min(0.1, now - last);
      last = now;
      if (ambience) ambience.volume = p === Phase.garage ? 0 : AMBIENCE;
      const wantBed = p === Phase.countdown ? BED_WAIT : p === Phase.racing ? BED_RUN : p === Phase.garage ? 0 : BED_AFTER;
      bedAt += (wantBed - bedAt) * Math.min(1, dt * BED_EASE);
      if (bed) bed.volume = bedAt;

      // A new run: nothing carried over.
      if (p === Phase.countdown || p === Phase.garage) {
        hurts = kart.hurts[e]!;
        shake = kart.shake[e]!;
        bumps = kart.bumps[e]!;
      }
      // Every knock against something on the course: a thud (a soft one into a bale), metal ringing with a hard one --
      // unless the crash below says it louder.
      if (kart.bumps[e]! !== bumps) {
        bumps = kart.bumps[e]!;
        if (kart.hurts[e]! === hurts && now - bumpAt > BUMP_GAP) {
          bumpAt = now;
          const s = kart.bumpSpeed[e]!;
          const loud = Math.min(1, BUMP_QUIET + (1 - BUMP_QUIET) * (s / BUMP_FULL));
          if (kart.bumpSoft[e]) one('knock', loud * 0.7, 0.6);
          else {
            one('knock', loud, 1);
            if (s > BUMP_METAL) one('metal_hit', loud * 0.45, 1.15);
          }
        }
      }
      // The start: a beep as each red lamp comes on (as `startLights` lights them), GO as the run starts.
      const lit = p === Phase.countdown && !kart.waiting[e] ? Math.min(3, Math.max(0, Math.floor(kart.clock[e]! + COUNTDOWN) + 1)) : 0;
      if (lit > lamps) one('beep', 0.7, 1);
      lamps = lit;
      // The hits: a part hurt is a crash; a big jolt with nothing hurt, a knock.
      if (kart.hurts[e]! > hurts) {
        one('metal_hit', 0.8);
        one('crash', 0.45);
        // And the crowd loves it.
        if (now - oohAt > OOH_GAP) {
          oohAt = now;
          one('crowd_ooh', 0.75);
        }
      }
      else if (kart.shake[e]! - shake > KNOCK_JOLT && bumpAt !== now) one('knock', Math.min(1, 0.4 + kart.shake[e]!), 1.1);
      hurts = kart.hurts[e]!;
      shake = kart.shake[e]!;
      // The crowd, on the run's big moments.
      if (kart.newsAt[e]! > newsAt + 0.001) {
        newsAt = kart.newsAt[e]!;
        const n = kart.news[e]!;
        if (n === News.lostWheel || n === News.lostBody || n === News.thrown || n === News.wrecked) {
          // A part off: metal clattering away (two recordings, by turns); the bodywork cracking apart.
          if (n === News.lostWheel) one(clatters++ % 2 === 0 ? 'clatter_a' : 'clatter_b', 0.85);
          if (n === News.lostBody) one('crack', 0.9);
          // Wrecked: the big metal smash (a recording, AssetsSource/audio/sfx/wreck.wav).
          if (n === News.wrecked) one('wreck', 1);
          one('crowd_gasp', 0.8);
          if (now - oohAt > OOH_GAP) {
            oohAt = now;
            one('crowd_ooh', 0.9);
          }
        }
        else if (n === News.bigAir || n === News.clearedDucks) one('crowd_cheer', 0.6);
        else if (n === News.lostSteering) one(clatters++ % 2 === 0 ? 'clatter_a' : 'clatter_b', 0.85);
        else if (n === News.bonus) one('chime', 0.8);
      } else if (kart.newsAt[e]! < newsAt - 0.001) newsAt = kart.newsAt[e]!;
      // Over the line: a cheer. Into the pond: a splash.
      if (p !== phase) {
        if (p === Phase.finished) {
          // (The fanfare is the HUD's, for a finish in the top three: race-hud.ts.)
          one('crowd_cheer', 1);
        }
        // The crowd: an "ooh" at a run ended short of the line. (No roar at the start: the countdown is its beeps alone.)
        if (p === Phase.over && phase !== Phase.over) one('crowd_ooh', 0.9);
        if (p === Phase.racing && phase === Phase.countdown) {
          one('go', 0.8);
          one('crowd_cheer', 0.8);
        }
        // The crowd cheering the kart up to the line as the countdown starts.
        if (p === Phase.countdown && phase !== Phase.countdown) one('crowd_cheer', 0.6);
        if (p === Phase.over && kart.out[e] === RunOut.pond && out !== RunOut.pond) one('splash', 1);
        phase = p;
      }
      out = kart.out[e]!;
    },
  });
  return () => {
    if (soundLoops.hush === hush) soundLoops.hush = null;
    scrape?.stop();
    skid?.stop();
    ambience?.stop();
    bed?.stop();
  };
}
