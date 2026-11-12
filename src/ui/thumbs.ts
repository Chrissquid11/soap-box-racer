/**
 * Pictures of the parts for the garage's cards: each part's own model (`karts/parts#wheel_bike`, a themed body ...)
 * drawn once, three-quarters on from the front, lit as the course is, into a texture the card shows. Drawn by a
 * small renderer of its own on its own canvas -- never the game's, whose context Pixi shares -- the first time a
 * picture is asked for, then kept; the renderer let go once every picture asked for is drawn.
 */
import * as THREE from 'three';
import { Texture } from 'pixi.js';
import { Assets } from '@vibe/engine/assets';

/** A picture's side, in pixels of the canvas it is drawn on (the card scales it). */
const SIDE = 256;
/** Where the camera looks from: in front, to the left, above -- as the garage's mockup sees the kart. */
const FROM = new THREE.Vector3(-0.85, 0.55, 1).normalize();

const made = new Map<string, Texture>();
let renderer: THREE.WebGLRenderer | null = null;
let stage: { scene: THREE.Scene; camera: THREE.PerspectiveCamera } | null = null;
let idle: ReturnType<typeof setTimeout> | null = null;

function setUp(): { r: THREE.WebGLRenderer; scene: THREE.Scene; camera: THREE.PerspectiveCamera } {
  if (!renderer) {
    renderer = new THREE.WebGLRenderer({ canvas: document.createElement('canvas'), antialias: true, alpha: true, preserveDrawingBuffer: true });
    renderer.setPixelRatio(1);
    renderer.setSize(SIDE, SIDE, false);
    renderer.setClearColor(0x000000, 0);
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
  }
  if (!stage) {
    const scene = new THREE.Scene();
    scene.add(new THREE.HemisphereLight(0xdfeeff, 0x4a3b2a, 1.6));
    const sun = new THREE.DirectionalLight(0xfff0dc, 2.6);
    sun.position.set(-2, 4, 3);
    scene.add(sun);
    const rim = new THREE.DirectionalLight(0x9fc4ff, 1.1);
    rim.position.set(3, 2, -3);
    scene.add(rim);
    stage = { scene, camera: new THREE.PerspectiveCamera(30, 1, 0.01, 100) };
  }
  return { r: renderer, ...stage };
}

/** Whether a drawn picture has nothing in it: every pixel of a coarse grid across it see-through. */
function blank(ctx: CanvasRenderingContext2D): boolean {
  const data = ctx.getImageData(0, 0, SIDE, SIDE).data;
  const step = 8;
  for (let y = 0; y < SIDE; y += step) for (let x = 0; x < SIDE; x += step) if (data[(y * SIDE + x) * 4 + 3]! > 8) return false;
  return true;
}

/** Let go of the renderer a moment after the last picture: they are all drawn by then. */
function letGoSoon(): void {
  if (idle) clearTimeout(idle);
  idle = setTimeout(() => {
    renderer?.dispose();
    renderer?.forceContextLoss();
    renderer = null;
    idle = null;
  }, 2000);
}

const box = new THREE.Box3();
const middle = new THREE.Vector3();
const span = new THREE.Vector3();

/** A model or one of its parts (`karts/parts#wheel_bike`), as an object to draw: null if it is not loaded. */
function instanceOf(key: string): THREE.Object3D | null {
  const hash = key.indexOf('#');
  const model = hash < 0 ? key : key.slice(0, hash);
  const part = hash < 0 ? null : key.slice(hash + 1);
  if (!Assets.modelIfPresent(model)) return null;
  try {
    return Assets.instance(model as never, part);
  } catch {
    return null;
  }
}

/** A second model drawn with the first: `key` at (0, y, z) of it (a kart's bodywork on its chassis). */
export interface With {
  key: string;
  y: number;
  z: number;
}

/**
 * The picture of a model or one of its parts (`karts/parts#wheel_bike`) -- with `also` on it, and the `extra` parts
 * of the same model drawn in place with it, when given: drawn now
 * if it has not been, null if a model is not loaded. Call it on the Pixi side (the texture is uploaded there).
 */
export function thumb(key: string, also?: With, extra?: readonly string[]): Texture | null {
  const name = `${also ? `${key}|${also.key}@${also.y},${also.z}` : key}${extra?.length ? `+${extra.join('+')}` : ''}`;
  const have = made.get(name);
  if (have) return have;
  const first = instanceOf(key);
  if (!first) return null;
  let object: THREE.Object3D = first;
  if (also || extra?.length) {
    object = new THREE.Group();
    object.add(first);
  }
  if (also) {
    const second = instanceOf(also.key);
    if (!second) return null;
    second.position.set(0, also.y, also.z);
    object.add(second);
  }
  // More parts drawn in place with it (a body's bits that come off on their own: the taco's shells, the shark's fins).
  for (const k of extra ?? []) {
    const more = instanceOf(k);
    if (!more) return null;
    object.add(more);
  }
  const { r, scene, camera } = setUp();
  scene.add(object);
  object.updateMatrixWorld(true);
  box.setFromObject(object);
  box.getCenter(middle);
  box.getSize(span);
  // Far enough back that the whole of it fits, with a little room.
  const radius = Math.max(0.01, span.length() / 2);
  const distance = (radius / Math.sin(THREE.MathUtils.degToRad(camera.fov / 2))) * 0.92;
  camera.position.copy(middle).addScaledVector(FROM, distance);
  camera.near = distance / 50;
  camera.far = distance * 4;
  camera.lookAt(middle);
  camera.updateProjectionMatrix();
  r.render(scene, camera);
  scene.remove(object);
  // Copied out of the renderer's canvas, which the next picture draws over.
  const copy = document.createElement('canvas');
  copy.width = SIDE;
  copy.height = SIDE;
  const ctx = copy.getContext('2d');
  ctx?.drawImage(r.domElement, 0, 0);
  // Drawn blank (a renderer just made, a model mid-reload): not kept -- asked again, it is drawn again.
  if (ctx && blank(ctx)) {
    letGoSoon();
    return null;
  }
  const texture = Texture.from(copy);
  made.set(name, texture);
  letGoSoon();
  return texture;
}
