/**
 * The weather on a course, and what it does: how the tyres grip and the wheels roll (`vehicle`), a crosswind
 * pushing at the kart, how far the fog lets you see, how the sky and light look and what falls from it
 * (`environment.ts`), and how much slower the rivals were in it (`rivals.ts`: they rode in the same weather).
 *
 * Each visit to a course's garage it is dealt afresh (`race`: the same visit, the same weather for every restart):
 * the very first course is always sunny, the rest by chance -- sunny by far the likeliest, and snow only on a snowy
 * course (`Course.snowy`, its land white), where it snows SNOW_CHANCE of visits. Every number to tune is here.
 */
import { enumOf } from '@vibe/engine';

export const Weather = enumOf(['sunny', 'rain', 'fog', 'wind', 'snow'], 'sunny');

export interface WeatherKind {
  /** As the HUD says it, and what it warns. */
  readonly name: string;
  readonly warning: string;
  /** The tyres' grip, a share of the dry road's; and their rolling drag, times. */
  readonly grip: number;
  readonly rolling: number;
  /** A crosswind across the road, m/s² at its strongest gust (its side dealt with the weather). */
  readonly wind: number;
  /** The fog: where it begins and where it is whole, metres. */
  readonly fogNear: number;
  readonly fogFar: number;
  /** The sky: zenith and horizon (the fog's colour too), the sun's brightness and the sky's fill, a share of a sunny day's; the clouds' cover, 0 to 1. */
  readonly zenith: number;
  readonly horizon: number;
  readonly sun: number;
  readonly fill: number;
  readonly clouds: number;
  /** What falls: nothing, rain or snow. */
  readonly falls: 'none' | 'rain' | 'snow';
  /** The rivals' times in it, times their dry ones. */
  readonly slower: number;
  /** How likely, against the rest. */
  readonly chance: number;
}

export const WEATHER: readonly WeatherKind[] = [
  { name: 'Sunny', warning: '', grip: 1, rolling: 1, wind: 0, fogNear: 110, fogFar: 520, zenith: 0x3f8fe0, horizon: 0xcde6f2, sun: 1, fill: 1, clouds: 0.3, falls: 'none', slower: 1, chance: 0.72 },
  { name: 'Rain', warning: 'Wet: brake early!', grip: 0.72, rolling: 1.1, wind: 0, fogNear: 50, fogFar: 260, zenith: 0x56657a, horizon: 0x9aa6b2, sun: 0.35, fill: 0.85, clouds: 0.95, falls: 'rain', slower: 1.06, chance: 0.1 },
  { name: 'Fog', warning: 'Fog: bends come late!', grip: 0.95, rolling: 1, wind: 0, fogNear: 6, fogFar: 70, zenith: 0xb7c0c6, horizon: 0xd3d8db, sun: 0.45, fill: 1, clouds: 1, falls: 'none', slower: 1.03, chance: 0.08 },
  { name: 'Windy', warning: '', grip: 1, rolling: 1, wind: 4.5, fogNear: 120, fogFar: 560, zenith: 0x4a92d8, horizon: 0xd6e8f0, sun: 1, fill: 1, clouds: 0.6, falls: 'none', slower: 1.04, chance: 0.1 },
  { name: 'Snow', warning: 'Ice: hardly any grip!', grip: 0.55, rolling: 1.6, wind: 1.2, fogNear: 35, fogFar: 200, zenith: 0x8d9aab, horizon: 0xe4e9ee, sun: 0.55, fill: 1.15, clouds: 0.9, falls: 'snow', slower: 1.12, chance: 0 },
];

/** 0..1 from a pair of numbers: the same for the same pair. */
function hash(a: number, b: number): number {
  let h = Math.imul(a * 0x9e3779b1 + b * 0x85ebca6b + 0x27d4eb2f, 0xc2b2ae35);
  h = Math.imul(h ^ (h >>> 15), 0x165667b1);
  return ((h ^ (h >>> 13)) >>> 0) / 4294967296;
}

/** On a snowy course, the share of visits it snows. */
export const SNOW_CHANCE = 0.4;

/** The weather dealt for the `visit`th time a course's garage is come to (0 the first): snow only on a `snowy` one. */
export function dealWeather(course: number, visit: number, snowy = false): number {
  // The first course is always sunny: the first run a player has, and every one after it there.
  if (course === 0) return Weather.sunny;
  if (snowy && hash(course + 101, visit + 7) < SNOW_CHANCE) return Weather.snow;
  let total = 0;
  for (const w of WEATHER) total += w.chance;
  let r = hash(course + 1, visit + 1) * total;
  for (let i = 0; i < WEATHER.length; i++) {
    r -= WEATHER[i]!.chance;
    if (r < 0) return i;
  }
  return Weather.sunny;
}

/** The crosswind's gusting share at `time` seconds: between a third and all of its strength, rising and falling. */
export function gust(time: number): number {
  return 0.66 + 0.34 * Math.sin(time * 0.9) * Math.sin(time * 0.37 + 1.3);
}

/** A weather by its number, sunny for one out of range. */
export function weatherOf(w: number): WeatherKind {
  return WEATHER[w] ?? WEATHER[0]!;
}
