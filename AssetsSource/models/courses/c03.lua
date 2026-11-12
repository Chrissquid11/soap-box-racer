-- Course 3 of 20: Kerry Cliffs. County Kerry, Ireland. Narrower, steeper, and the bins are out.
--
-- Written by scripts/courses.ts from its design in src/game/courses.ts: change the design there and run
-- `node scripts/courses.ts`, never this file by hand (src/game/courses.test.ts checks it). The road, the
-- walls, the valley and the arches are the shared library's (_course.lua).
local P = params{
  trees = {default=92, min=0, max=250, integer=true, doc="Trees scattered on the slopes"},
  bank  = {default=0.3, min=0.05, max=0.8, doc="How steeply the valley sides rise away from the road"},
}

include("_course.lua").build({
  points = {
    {0, 44.79, 20}, {0, 44.19, 0}, {5.49, 33.48, -29.49}, {10.44, 29.44, -59.08}, {6.04, 24.65, -88.75}, {-4.1, 20.29, -116.99},
    {-11.99, 16.85, -145.93}, {-20.13, 13.04, -174.8}, {-34.44, 8.92, -201.17}, {-57.35, 5.78, -220.54}, {-83.5, 2.72, -235.25}, {-108.58, 0, -251.72},
    {-118.61, 0.4, -258.31}, {-128.64, 1.2, -264.89},
  },
  berms = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
  half_width = 3.5,
  widths = {
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0.993, 0.974, 0.948, 0.92, 0.897, 0.876, 0.862, 0.859, 0.859,
    0.859, 0.859, 0.859, 0.859, 0.859, 0.859, 0.859, 0.859, 0.859, 0.858, 0.859, 0.861, 0.865, 0.872, 0.883, 0.899, 0.935, 0.97, 1.001, 1.026,
    1.042, 1.056, 1.067, 1.073, 1.075, 1.075, 1.075, 1.075, 1.075, 1.075, 1.075, 1.075, 1.075, 1.074, 1.072, 0.995, 0.817, 0.64, 0.56, 0.56,
    0.56, 0.56, 0.56, 0.56, 0.56, 0.56, 0.56, 0.56, 0.56, 0.56, 0.602, 0.744, 0.904, 0.999, 1.001, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  },
  wall_h = 0.76,
  start_point = 2,
  finish_point = 12,
  road = {0.26, 0.24, 0.2},
  grass = {0.12, 0.42, 0.1},
  hay = {0.82, 0.6, 0.2},
  seed = 33,
  urban = false,
  railed = true,
  bare = false,
  start_ramp = true,
}, P)
