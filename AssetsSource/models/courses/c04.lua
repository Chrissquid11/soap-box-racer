-- Course 4 of 20: Lisbon Lurch. Lisbon, Portugal. Cobbles and tram lines all the way down to the river. Brake before the bends.
--
-- Written by scripts/courses.ts from its design in src/game/courses.ts: change the design there and run
-- `node scripts/courses.ts`, never this file by hand (src/game/courses.test.ts checks it). The road, the
-- walls, the valley and the arches are the shared library's (_course.lua).
local P = params{
  trees = {default=24, min=0, max=250, integer=true, doc="Trees scattered on the slopes"},
  bank  = {default=0.3, min=0.05, max=0.8, doc="How steeply the valley sides rise away from the road"},
}

include("_course.lua").build({
  points = {
    {0, 54.83, 20}, {0, 54.83, 0}, {-8.47, 51.23, -28.78}, {-18.77, 46.43, -56.96}, {-33.06, 42.29, -83.34}, {-50.31, 38.65, -107.89},
    {-67.56, 32.31, -132.44}, {-84.81, 23.75, -156.99}, {-102.06, 15.25, -181.54}, {-126.93, 12.35, -198.32}, {-156.12, 7.7, -205.26}, {-185.63, 3.17, -199.87},
    {-208.82, 0, -180.84}, {-218.1, 0.4, -173.23}, {-227.37, 1.2, -165.62},
  },
  berms = {0, 0, 0, 0, 0, 0, 0, 0.14, 0, 0.56, 0, 0, 0, 0, 0},
  half_width = 3.71,
  widths = {
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1.002, 1.006, 1.011, 1.018, 1.026, 1.024, 1.012, 1, 0.99, 0.982, 0.978, 0.977, 0.977, 0.977, 0.977, 0.977, 0.977, 0.977, 0.977, 0.977,
    0.975, 0.967, 0.951, 0.928, 0.899, 0.867, 0.833, 0.801, 0.781, 0.806, 0.833, 0.858, 0.881, 0.899, 0.912, 0.919, 0.921, 0.921, 0.921, 0.921,
    0.921, 0.921, 0.921, 0.927, 0.938, 0.954, 0.973, 0.992, 1.01, 1.018, 1.021, 1.025, 1.031, 1.037, 1.042, 1.045, 1.045, 1.045, 1.045, 1.045,
    1.04, 1.032, 1.023, 1.011, 1.002, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1,
  },
  wall_h = 0.72,
  start_point = 2,
  finish_point = 13,
  road = {0.38, 0.34, 0.28},
  grass = {0.62, 0.56, 0.46},
  hay = {0.85, 0.07, 0.05},
  seed = 46,
  urban = true,
  start_ramp = false,
}, P)
