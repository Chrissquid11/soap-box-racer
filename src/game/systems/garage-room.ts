/**
 * garageRoom, 60 Hz: the workshop the kart is built in. While the kart waits in the garage, the garage's room
 * (`garage/room`) stands round it -- its floor on the road under the start line, turned as the kart faces -- and the
 * course is out of sight (its root `Hidden`: the track, its walls and hazards, everything under it). Once a run is
 * asked for, the room goes out of sight and the course comes back: the kart is on the start line, as it always was.
 * Only what is drawn changes: the course's colliders stay, the kart never moves.
 */
import { Hidden, NONE, Transform, type World } from '@vibe/engine';
import { Kart, Phase } from '../components.ts';
import { TRACKS } from '../courses.ts';
import { headingAt, mainUnder } from '../track.ts';
import { GarageRoom } from '../prefabs.ts';

export function garageRoom(world: World): void {
  world.system({
    name: 'garageRoom',
    rate: 60,
    after: ['course', 'race'],
    write: [Kart, Transform],
    update({ members, count, cmd, has, ref, deref }, _read, [kart, at]) {
      for (let n = 0; n < count; n++) {
        const e = members[n];
        const course = kart.course[e];
        if (course >= TRACKS.length) continue;
        const inGarage = kart.phase[e] === Phase.garage;
        let room = deref(kart.room[e]);
        if (inGarage && room === NONE) {
          // Made this tick: placed and shown from the next (it is in the world by then).
          const made = cmd.instantiate(GarageRoom);
          if (made !== NONE) {
            kart.room[e] = ref(made);
            kart.roomCourse[e] = 255;
          }
        }
        // Round the kart where it waits: its middle on the kart, its floor on the road under it, turned as it faces
        // down the road there (the line's heading: the kart's own nose may be a hair off it).
        if (room !== NONE && inGarage && has(room, Transform)) {
          kart.roomCourse[e] = course;
          const t = TRACKS[course]!;
          const j = Math.max(0, Math.min(t.samples - 1, Math.round(kart.progress[e] >= 0 ? kart.progress[e] : t.start)));
          at.px[room] = at.px[e]!;
          // The floor on the road itself under the kart, where its wheels stand -- not its height less its ride height,
          // which long springs (a pogo's) hold well above, sinking its wheels through the floor.
          at.py[room] = mainUnder(t, at.px[e]!, at.pz[e]!) ?? at.py[e]! - kart.rideY[e];
          at.pz[room] = at.pz[e]!;
          const h = headingAt(t, j);
          at.qx[room] = 0;
          at.qy[room] = Math.sin(h / 2);
          at.qz[room] = 0;
          at.qw[room] = Math.cos(h / 2);
        }
        if (room !== NONE) {
          if (inGarage && has(room, Hidden)) cmd.remove(room, Hidden);
          else if (!inGarage && !has(room, Hidden)) cmd.add(room, Hidden);
        }
        // The course out of sight while the room is up.
        const root = deref(kart.courseRoot[e]);
        if (root !== NONE) {
          if (inGarage && !has(root, Hidden)) cmd.add(root, Hidden);
          else if (!inGarage && has(root, Hidden)) cmd.remove(root, Hidden);
        }
      }
    },
  });
}
