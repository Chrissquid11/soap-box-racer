-- Course 1 of 20: Bunting Hill. The Cotswolds, England. A gentle first run down the bunting-strung hill, past the cake stall.
--
-- Written by scripts/courses.ts from its design in src/game/courses.ts: change the design there and run
-- `node scripts/courses.ts`, never this file by hand (src/game/courses.test.ts checks it). The road, the
-- walls, the valley and the arches are the shared library's (_course.lua).
local P = params{
  trees = {default=80, min=0, max=250, integer=true, doc="Trees scattered on the slopes"},
  bank  = {default=0.3, min=0.05, max=0.8, doc="How steeply the valley sides rise away from the road"},
}

include("_course.lua").build({
  points = {
    {0, 25.67, 20}, {0, 25.07, 0}, {-5.8, 21.83, -29.43}, {-9.14, 18.79, -59.24}, {-12.32, 14.99, -89.07}, {-17.09, 12.26, -118.69},
    {-22.34, 9.54, -148.23}, {-25.67, 6.83, -178.05}, {-28.49, 3.81, -207.92}, {-34.82, 0, -237.24}, {-37.35, 0.4, -248.97}, {-39.88, 1.2, -260.7},
  },
  berms = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
  half_width = 4.29,
  widths = {
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 0.999, 0.993, 0.983, 0.971, 0.956, 0.941, 0.93, 0.929, 0.927, 0.925, 0.922, 0.92, 0.919, 0.918, 0.918, 0.918, 0.919, 0.928, 0.95,
    0.976, 1.001, 1.023, 1.042, 1.051, 1.051, 1.051, 1.051, 1.051, 1.048, 1.042, 1.037, 1.026, 1.013, 1.003, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  },
  wall_h = 0.85,
  start_point = 2,
  finish_point = 10,
  road = {0.3, 0.22, 0.13},
  grass = {0.2, 0.46, 0.1},
  hay = {0.85, 0.62, 0.22},
  seed = 7,
  urban = false,
  start_ramp = false,
}, P)
