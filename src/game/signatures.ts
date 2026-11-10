/**
 * Each body's signature piece: the one bit of it that comes off as the joke of its breakup, when the bodywork goes
 * (`impacts`' shatterBody) -- its model's `<part>_sig` (the piece alone, centred on its own middle: `_sig.lua`), where
 * that middle sat in the body's space (`at`, metres), its size, how it leaves, and what the HUD calls out.
 *
 *   roll    a ball rolling off down the road ahead of the kart: it overtakes it (the snail's shell)
 *   slide   a box sliding off and away down the road, faster than the kart (the sofa taking the lead)
 *   fling   a small thing tossed up and off to its side, tumbling (the can's pull tab, the toilet's cistern)
 *
 * A body with a caption and no piece (`at` left out) has its joke in its wreck alone (the crate, down to its plank).
 */
export interface Signature {
  readonly at?: readonly [number, number, number];
  readonly size?: readonly [number, number, number];
  readonly leave?: 'roll' | 'slide' | 'fling';
  /** Degrees it is turned about its up as it comes off: a hoop facing forward turned side on, to roll down the road. */
  readonly yaw?: number;
  readonly caption: string;
}

export const SIGNATURES: Readonly<Record<string, Signature>> = {
  'Escargot Fast': { at: [0, 0.361, -0.98], size: [0.695, 0.923, 0.789], leave: 'roll', caption: 'THE SHELL IS FASTER' },
  'Couch Potato': { at: [0, 0.12, -0.23], size: [1.23, 0.84, 1.05], leave: 'slide', caption: 'FURNITURE IN THE LEAD' },
  'Crate Expectations': { caption: 'DOWN TO THE PLANK' },
  'Fizz Bomb': { at: [0, 0.02, -0.923], size: [0.15, 0.27, 0.017], leave: 'fling', caption: 'OPENED UNDER PRESSURE' },
  'Air Fryer Force One': { at: [0, -0.1, -0.295], size: [0.76, 0.403, 1.45], leave: 'slide', caption: 'BASKET CASE' },
  'Bog Standard': { at: [0.017, 0.325, -0.82], size: [0.723, 0.85, 0.49], leave: 'fling', caption: 'FLUSHED IT' },
  'The Bread Bull': { at: [0, 0.38, -0.22], size: [0.83, 0.44, 0.46], leave: 'fling', caption: 'TOAST' },
  'Abduction Reduction': { at: [-0.227, 0.345, -0.922], size: [0.08, 0.49, 0.107], leave: 'fling', caption: 'ABDUCTION ABORTED' },
  'The Existential Prawn': { at: [0, 0.44, 1.3], size: [1.107, 0.607, 0.446], leave: 'fling', caption: 'FEELERS GONE' },
  'Rock Bottom': { at: [0, -0.215, 1.325], size: [1.32, 0.539, 0.544], leave: 'roll', caption: 'BACK TO THE STONE AGE' },
  'Pram Pushing': { at: [0.16, -0.244, 0.993], size: [0.206, 0.288, 0.154], leave: 'fling', caption: 'TEDDY OUT THE PRAM' },
  'Moving Violation': { at: [0, 0.884, -0.164], size: [1.39, 1.417, 1.441], leave: 'fling', caption: 'MOVING OUT' },
  'Bolt From The Blue': { at: [0, -0.389, 1.32], size: [1.36, 0.172, 0.2], leave: 'slide', caption: 'BUMPER STICKERED' },
  'The Cyber Shed': { at: [0.517, 0.538, -0.155], size: [0.123, 0.763, 2.25], leave: 'fling', caption: 'PANEL BEATEN' },
  'Teapot One': { at: [0.4, 0.536, -0.845], size: [0.248, 0.28, 0.77], leave: 'fling', caption: 'FLIGHT CANCELLED' },
  'Gull Throttle': { at: [0.559, 0.936, -0.051], size: [0.527, 0.611, 0.899], leave: 'fling', caption: 'TIME TRAVEL POSTPONED' },
  'Lunar Tick': { at: [0, -0.02, -0.72], size: [0.852, 0.852, 0.1], leave: 'roll', yaw: 90, caption: 'STAGE SEPARATION' },
  'Great White Hope': { at: [0, 0.903, -1.209], size: [0.07, 0.788, 0.693], leave: 'fling', caption: 'FIN-ISHED' },
  'Shell Suit': { at: [0.01, 0.33, -0.06], size: [1.363, 1.196, 2.135], leave: 'fling', caption: 'TACO SPILL' },
  'Foot Loose': { at: [-0.31, -0.261, 0.85], size: [0.295, 0.338, 0.398], leave: 'roll', caption: 'TOE-TAL DAMAGE' },
  'Pole Vault': { at: [0, -0.385, 1.325], size: [1.46, 0.17, 0.33], leave: 'slide', caption: 'AERO PACKAGE DOWNGRADED' },
  'Gravity Well': { at: [0.415, -0.276, -0.06], size: [0.028, 0.306, 1.86], leave: 'slide', caption: 'FAIRING POORLY' },
  'Hippy Van': { at: [0, 1.261, -0.065], size: [0.956, 0.148, 1.833], leave: 'fling', caption: "HOLIDAY'S OVER" },
  'Old Faithful': { at: [0, -0.02, -1.329], size: [0.8, 0.34, 0.027], leave: 'slide', caption: 'DELIVERY COMPLETE' },
  'Full Steam': { at: [0, 0.831, 1.11], size: [0.278, 0.482, 0.278], leave: 'fling', caption: 'SERVICE DISRUPTED' },
};
