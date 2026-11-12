-- Course 5 of 20: Outback Rattler. The Outback, Australia. Red dirt and a jump halfway down. Land it straight.
--
-- Written by scripts/courses.ts from its design in src/game/courses.ts: change the design there and run
-- `node scripts/courses.ts`, never this file by hand (src/game/courses.test.ts checks it). The road, the
-- walls, the valley and the arches are the shared library's (_course.lua).
local P = params{
  trees = {default=104, min=0, max=250, integer=true, doc="Trees scattered on the slopes"},
  bank  = {default=0.3, min=0.05, max=0.8, doc="How steeply the valley sides rise away from the road"},
}

include("_course.lua").build({
  points = {
    {0, 62.86, 20}, {0, 62.26, 0}, {-0.41, 58.43, -30}, {7.32, 54.83, -58.99}, {22.26, 51.33, -85.01}, {39.16, 46.79, -109.79},
    {65.35, 41.57, -124.43}, {90.77, 37.28, -140.36}, {116.19, 31.82, -156.29}, {141.61, 27.23, -172.22}, {167.03, 19.74, -188.15}, {193.96, 15.77, -201.36},
    {223.96, 11.1, -201.39}, {248.86, 8.02, -184.65}, {256.98, 4.58, -155.77}, {243.92, 0, -128.76}, {238.7, 0.4, -117.96}, {233.47, 1.2, -107.15},
  },
  berms = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -0.79, -0.92, 0, 0, 0, 0},
  half_width = 3.15,
  widths = {
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.003, 1.017, 1.036, 1.051, 1.064, 1.072, 1.072, 1.072, 1.072, 1.072,
    1.065, 1.052, 1.034, 1.015, 0.998, 0.978, 0.95, 0.92, 0.892, 0.872, 0.862, 0.861, 0.861, 0.861, 0.861, 0.861, 0.861, 0.861, 0.861, 0.861,
    0.861, 0.861, 0.861, 0.861, 0.861, 0.861, 0.861, 0.861, 0.861, 0.864, 0.878, 0.897, 0.922, 0.952, 0.973, 0.98, 0.98, 0.98, 0.98, 0.98,
    0.982, 0.987, 0.962, 0.83, 0.666, 0.565, 0.56, 0.56, 0.56, 0.56, 0.56, 0.56, 0.56, 0.56, 0.56, 0.56, 0.56, 0.595, 0.74, 0.91,
    1.018, 1.026, 1.025, 1.024, 1.023, 1.023, 1.022, 1.02, 1.018, 1.015, 1.012, 1.008, 1.005, 1.002, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  },
  wall_h = 0.67,
  start_point = 2,
  finish_point = 16,
  road = {0.55, 0.22, 0.1},
  grass = {0.62, 0.42, 0.18},
  hay = {0.85, 0.6, 0.25},
  seed = 59,
  urban = false,
  railed = false,
  start_ramp = false,
}, P)
