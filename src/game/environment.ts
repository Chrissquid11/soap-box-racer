/**
 * The light and the air for courses hundreds of metres long. The engine's environment is made for a small
 * scene round the origin: its sun casts shadows in a box 16 m across about (0, 0, 0), and its fog closes in
 * at 18 to 60 m. A render system of the page's (one of the game entry's `installs`): each frame the sun's
 * shadow box rides with the kart the camera chases -- crisp shadows under the kart, the driver, the hazards
 * and the trees wherever the run is -- and the fog sits back so the far valley shows. The sun keeps the
 * engine's direction; the light is a warm afternoon's (the sun, the sky's fill, the grass's bounce), the
 * fog the horizon's haze, and a sky dome rides with the camera: blue overhead, hazy at the edge, a glow
 * round the sun and soft clouds.
 */
import * as THREE from 'three';
import { NONE, optional, View, WorldTransform, type World } from '@vibe/engine';
import { ChaseCam, Kart, Phase } from './components.ts';
import { weatherOf } from './weather.ts';
import { lowEnd } from './device.ts';

/** The shadow box: metres either side of the kart, and the sun's distance back along its own direction. */
const REACH = 28;
const BACK = 60;
/** The shadow map's size, and its biases against acne on the long gentle slopes. */
const MAP = 2048;
/** On a phone (`lowEnd`): a smaller box and map -- the shadows under the kart as crisp, fewer things drawn into them. */
const REACH_LOW = 16;
const MAP_LOW = 1024;
const reach = (): number => (lowEnd() ? REACH_LOW : REACH);
const mapSize = (): number => (lowEnd() ? MAP_LOW : MAP);
const BIAS = -0.0004;
const NORMAL_BIAS = 0.04;
/** Where the fog begins and where it is whole, metres. */
const FOG_NEAR = 110;
const FOG_FAR = 520;

/**
 * The colours of the day: a warm afternoon. The sky's zenith, its horizon haze (the fog's colour too, so
 * the far hills melt into it), the sun's light, the sky's fill from above and the grass's bounce from below.
 */
const ZENITH = new THREE.Color('#3f8fe0');
const HORIZON = new THREE.Color('#cde6f2');
const SUNLIGHT = new THREE.Color('#ffe6c2');
const SUN_POWER = 2.9;
const FILL_SKY = new THREE.Color('#cfe8ff');
const FILL_GROUND = new THREE.Color('#5f7d3a');
const FILL_POWER = 1.35;
/** The sky dome's radius: inside the chase camera's far plane (700 m). */
const DOME = 600;

/** A dome of sky round the camera: a gradient from the haze up to the zenith, a glow round the sun, and soft clouds. */
function skyDome(toward: THREE.Vector3): THREE.Mesh {
  const material = new THREE.ShaderMaterial({
    side: THREE.BackSide,
    depthWrite: false,
    fog: false,
    uniforms: {
      zenith: { value: ZENITH.clone() },
      horizon: { value: HORIZON.clone() },
      sunDir: { value: toward.clone() },
      sunColour: { value: SUNLIGHT },
      cover: { value: 0.3 },
    },
    vertexShader: /* glsl */ `
      varying vec3 vDir;
      void main() {
        vDir = normalize(position);
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }`,
    fragmentShader: /* glsl */ `
      uniform vec3 zenith; uniform vec3 horizon; uniform vec3 sunDir; uniform vec3 sunColour; uniform float cover;
      varying vec3 vDir;
      float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
      float noise(vec2 p) {
        vec2 i = floor(p), f = fract(p);
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
      }
      float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int k = 0; k < 5; k++) { v += a * noise(p); p *= 2.03; a *= 0.5; } return v; }
      void main() {
        vec3 d = normalize(vDir);
        float up = clamp(d.y, 0.0, 1.0);
        vec3 col = mix(horizon, zenith, pow(up, 0.55));
        // Below the horizon: the haze, so the valley's edge never shows a seam.
        if (d.y < 0.0) col = horizon;
        float s = max(dot(d, normalize(sunDir)), 0.0);
        col += sunColour * (pow(s, 600.0) * 2.5 + pow(s, 12.0) * 0.25);
        // Clouds: fbm on a plane above, thinning toward the horizon.
        if (d.y > 0.02) {
          vec2 p = d.xz / (d.y + 0.12) * 1.6;
          float low = mix(0.66, 0.18, cover);
          float c = smoothstep(low, low + 0.26, fbm(p));
          float lit = (0.88 + 0.12 * s) * (1.0 - 0.5 * smoothstep(0.6, 1.0, cover));
          col = mix(col, vec3(1.0, 0.99, 0.97) * lit, c * smoothstep(0.02, 0.25, d.y) * mix(0.85, 1.0, cover));
        }
        gl_FragColor = vec4(col, 1.0);
      }`,
  });
  const mesh = new THREE.Mesh(new THREE.SphereGeometry(DOME, 32, 16), material);
  mesh.frustumCulled = false;
  mesh.renderOrder = -1;
  mesh.name = 'sky dome';
  return mesh;
}

interface Lit {
  readonly sun: THREE.DirectionalLight;
  readonly fill: THREE.HemisphereLight | null;
  readonly fog: THREE.Fog | null;
  readonly scene: THREE.Scene;
  readonly rain: THREE.LineSegments;
  readonly snow: THREE.Points;
  /** The sun's direction, from its target toward it, as the engine set it. */
  readonly toward: THREE.Vector3;
  readonly dome: THREE.Mesh;
  /** The sun's and the sky's strength for the weather, before the workshop dims them (`roomLight`). */
  sunPower: number;
  fillPower: number;
  /** The workshop's own lights: the tube over the kart and the bulb over the bench. */
  readonly tube: THREE.PointLight;
  readonly bulb: THREE.PointLight;
}

const eye = new THREE.Vector3();

const lit = new WeakMap<THREE.Object3D, Lit | null>();

/** The scene's sun, set up for a moving shadow box once, the first time the scene is seen. */
function sunOf(scene: THREE.Object3D): Lit | null {
  if (lit.has(scene)) return lit.get(scene)!;
  let sun: THREE.DirectionalLight | null = null;
  for (const o of scene.children) if ((o as THREE.DirectionalLight).isDirectionalLight) sun = o as THREE.DirectionalLight;
  if (!sun) {
    lit.set(scene, null);
    return null;
  }
  const toward = sun.position.clone().sub(sun.target.position).normalize();
  sun.shadow.mapSize.set(mapSize(), mapSize());
  sun.shadow.map?.dispose();
  sun.shadow.map = null;
  const cam = sun.shadow.camera;
  cam.left = cam.bottom = -reach();
  cam.right = cam.top = reach();
  cam.near = 1;
  cam.far = BACK * 2 + reach();
  cam.updateProjectionMatrix();
  sun.shadow.bias = BIAS;
  sun.shadow.normalBias = NORMAL_BIAS;
  if (!sun.target.parent) scene.add(sun.target);
  sun.color.copy(SUNLIGHT);
  sun.intensity = SUN_POWER;
  let hemi: THREE.HemisphereLight | null = null;
  for (const o of scene.children) {
    const fill = o as THREE.HemisphereLight;
    if (!fill.isHemisphereLight) continue;
    fill.color.copy(FILL_SKY);
    fill.groundColor.copy(FILL_GROUND);
    fill.intensity = FILL_POWER;
    hemi = fill;
  }
  const fog = (scene as THREE.Scene).fog;
  if (fog instanceof THREE.Fog) {
    fog.near = FOG_NEAR;
    fog.far = FOG_FAR;
    fog.color.copy(HORIZON);
  }
  const s = scene as THREE.Scene;
  if (s.background instanceof THREE.Color) s.background.copy(HORIZON);
  const dome = skyDome(toward);
  scene.add(dome);
  const { rain, snow } = falling();
  scene.add(rain, snow);
  // The workshop's lights: no shadows of their own (the sun's are the kart's), reaching the room's walls and no further.
  const tube = new THREE.PointLight(TUBE_COLOUR, 0, 9, 2);
  const bulb = new THREE.PointLight(BULB_COLOUR, 0, 6, 2);
  tube.visible = bulb.visible = false;
  // The tube casts the workshop's own shadow -- the kart's, straight down onto the floor under it -- off on a phone.
  if (!lowEnd()) {
    tube.castShadow = true;
    tube.shadow.mapSize.set(1024, 1024);
    tube.shadow.bias = -0.002;
    tube.shadow.radius = 3;
    tube.shadow.camera.near = 0.3;
    tube.shadow.camera.far = 9;
  }
  scene.add(tube, bulb);
  const found: Lit = { sun, toward, dome, fill: hemi, fog: fog instanceof THREE.Fog ? fog : null, scene: s, rain, snow, sunPower: SUN_POWER, fillPower: FILL_POWER, tube, bulb };
  lit.set(scene, found);
  return found;
}

/** What falls in foul weather: rain as streaks, snow as flakes, each a box of them about the camera. */
const DROPS = 1400;
const FALL_BOX = 36;
const FALL_HIGH = 20;
const RAIN_SPEED = 16;
const RAIN_STREAK = 0.55;
const SNOW_SPEED = 1.6;
function falling(): { rain: THREE.LineSegments; snow: THREE.Points } {
  const rainAt = new Float32Array(DROPS * 6);
  const snowAt = new Float32Array(DROPS * 3);
  for (let i = 0; i < DROPS; i++) {
    const x = (Math.random() - 0.5) * FALL_BOX, y = Math.random() * FALL_HIGH, z = (Math.random() - 0.5) * FALL_BOX;
    rainAt.set([x, y, z, x, y + RAIN_STREAK, z], i * 6);
    snowAt.set([x, y, z], i * 3);
  }
  const rg = new THREE.BufferGeometry();
  rg.setAttribute('position', new THREE.BufferAttribute(rainAt, 3));
  const rain = new THREE.LineSegments(rg, new THREE.LineBasicMaterial({ color: 0xb8c8dc, transparent: true, opacity: 0.55, fog: false }));
  const sg = new THREE.BufferGeometry();
  sg.setAttribute('position', new THREE.BufferAttribute(snowAt, 3));
  const snow = new THREE.Points(sg, new THREE.PointsMaterial({ color: 0xffffff, size: 0.14, transparent: true, opacity: 0.9, fog: false }));
  for (const o of [rain, snow]) {
    o.frustumCulled = false;
    o.visible = false;
    o.name = 'weather';
  }
  return { rain, snow };
}

/** `v` wrapped round into the `size` about `mid`. */
function wrapTo(v: number, mid: number, size: number): number {
  return mid + ((((v - mid + size / 2) % size) + size) % size) - size / 2;
}

/** The drops of weather `w` moved on by `dt` seconds, each kept in its box about the eye (wrapped round as it leaves it). */
function fall(l: Lit, w: number, dt: number, time: number): void {
  const kind = weatherOf(w).falls;
  l.rain.visible = kind === 'rain';
  l.snow.visible = kind === 'snow';
  if (kind === 'none') return;
  const rain = kind === 'rain';
  const a = (rain ? l.rain : l.snow).geometry.getAttribute('position') as THREE.BufferAttribute;
  const p = a.array as Float32Array;
  const stride = rain ? 6 : 3;
  for (let i = 0; i < DROPS; i++) {
    const o = i * stride;
    let x = p[o]!, y = p[o + 1]!, z = p[o + 2]!;
    if (rain) y -= RAIN_SPEED * dt;
    else {
      y -= SNOW_SPEED * dt;
      x += Math.sin(time * 0.8 + i) * 0.4 * dt;
      z += Math.cos(time * 0.6 + i * 1.3) * 0.4 * dt;
    }
    x = wrapTo(x, eye.x, FALL_BOX);
    z = wrapTo(z, eye.z, FALL_BOX);
    y = wrapTo(y, eye.y, FALL_HIGH);
    p[o] = x; p[o + 1] = y; p[o + 2] = z;
    if (rain) { p[o + 3] = x + 0.06; p[o + 4] = y + RAIN_STREAK; p[o + 5] = z; }
  }
  a.needsUpdate = true;
}

const want = new THREE.Color();
/** The sky, the fog and the light eased toward the weather `w` (`weather.ts`), `dt` seconds on. */
function weatherLook(l: Lit, w: number, dt: number): void {
  const to = weatherOf(w);
  const k = Math.min(1, dt * 1.5);
  const u = (l.dome.material as THREE.ShaderMaterial).uniforms;
  (u.zenith!.value as THREE.Color).lerp(want.setHex(to.zenith), k);
  (u.horizon!.value as THREE.Color).lerp(want.setHex(to.horizon), k);
  u.cover!.value += (to.clouds - u.cover!.value) * k;
  if (l.fog) {
    l.fog.near += (to.fogNear - l.fog.near) * k;
    l.fog.far += (to.fogFar - l.fog.far) * k;
    l.fog.color.copy(u.horizon!.value as THREE.Color);
  }
  if (l.scene.background instanceof THREE.Color) l.scene.background.copy(u.horizon!.value as THREE.Color);
  l.sunPower += (SUN_POWER * to.sun - l.sunPower) * k;
  l.fillPower += (FILL_POWER * to.fill - l.fillPower) * k;
}

/**
 * The workshop's light (the garage, `garageRoom`'s room round the kart): the daylight through its roof and window
 * turned well down and warmed, and the room lit from within -- the fluorescent tube over the kart, and the bare bulb
 * over the workbench throwing a warm pool in its corner -- so the corners go dim and the kart sits in the light.
 * Its places in the room's own metres (room.lua), at the room's size (the shed prefab's scale) and turn.
 */
const INSIDE_SUN = 0.3;
const INSIDE_FILL = 0.2;
const INSIDE_SUNLIGHT = new THREE.Color('#ffc890');
const INSIDE_SKY = new THREE.Color('#ffd6a0');
const INSIDE_GROUND = new THREE.Color('#3b2a1a');
const TUBE_AT = new THREE.Vector3(0, 3.8, 0);
const TUBE_COLOUR = new THREE.Color('#fff0d2');
const TUBE_POWER = 20;
const BULB_AT = new THREE.Vector3(-4.9, 2.75, -3.3);
const BULB_COLOUR = new THREE.Color('#ff9d4a');
const BULB_POWER = 9;
const lamp = new THREE.Vector3();
const turn = new THREE.Quaternion();

/** The light as it is in the open (`inside` 0) or in the workshop (1), the room at (x, y, z), turned `q`, scaled `s`. */
function roomLight(l: Lit, inside: number, x: number, y: number, z: number, q: THREE.Quaternion, s: number): void {
  l.sun.intensity = l.sunPower * (1 - (1 - INSIDE_SUN) * inside);
  l.sun.color.copy(SUNLIGHT).lerp(INSIDE_SUNLIGHT, inside);
  if (l.fill) {
    l.fill.intensity = l.fillPower * (1 - (1 - INSIDE_FILL) * inside);
    l.fill.color.copy(FILL_SKY).lerp(INSIDE_SKY, inside);
    l.fill.groundColor.copy(FILL_GROUND).lerp(INSIDE_GROUND, inside);
  }
  l.tube.visible = l.bulb.visible = inside > 0;
  if (inside <= 0) return;
  l.tube.intensity = TUBE_POWER * inside;
  l.bulb.intensity = BULB_POWER * inside;
  l.tube.position.copy(lamp.copy(TUBE_AT).multiplyScalar(s).applyQuaternion(q)).add(eye.set(x, y, z));
  l.bulb.position.copy(lamp.copy(BULB_AT).multiplyScalar(s).applyQuaternion(q)).add(eye.set(x, y, z));
}

/** The game entry's install: the sun's shadow box kept on the chased kart. */
export function environment(world: World): () => void {
  world.system({
    name: 'environment',
    phase: 'render',
    with: [ChaseCam],
    read: [View, ChaseCam, optional(WorldTransform), optional(Kart)],
    update({ members, count, deref, has, frameDt, tick }, [view, chase, where, kart]) {
      for (let n = 0; n < count; n++) {
        const e = members[n];
        const camera = view.get(e);
        const scene = camera?.parent;
        if (!scene) continue;
        const l = sunOf(scene);
        if (!l) continue;
        // The sky rides with the camera: never reached, never clipped.
        camera.getWorldPosition(eye);
        l.dome.position.copy(eye);
        const k = deref(chase.target[e]);
        if (k === NONE) continue;
        // The weather on its course: the sky, the fog, the light and what falls.
        weatherLook(l, kart.weather[k]!, frameDt);
        // In the garage, the workshop's light round the kart (its room where `garageRoom` stood it).
        const room = kart.phase[k] === Phase.garage ? deref(kart.room[k]!) : NONE;
        if (room !== NONE && has(room, WorldTransform)) {
          turn.set(where.qx[room]!, where.qy[room]!, where.qz[room]!, where.qw[room]!);
          roomLight(l, 1, where.px[room]!, where.py[room]!, where.pz[room]!, turn, where.sx[room]! || 1);
        } else roomLight(l, 0, 0, 0, 0, turn, 1);
        fall(l, kart.weather[k]!, frameDt, tick / 60);
        const x = where.px[k], y = where.py[k], z = where.pz[k];
        // Snapped to a coarse grid, so the shadows' edges do not crawl as the box slides.
        const step = (2 * reach()) / mapSize() * 4;
        const sx = Math.round(x / step) * step, sy = Math.round(y / step) * step, sz = Math.round(z / step) * step;
        l.sun.target.position.set(sx, sy, sz);
        l.sun.position.set(sx + l.toward.x * BACK, sy + l.toward.y * BACK, sz + l.toward.z * BACK);
        l.sun.target.updateMatrixWorld();
      }
    },
  });
  return () => {};
}
