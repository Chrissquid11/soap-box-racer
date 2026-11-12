-- Course 2 of 20: Bristol Bombdown. Bristol, England. Down the terraced streets past the coloured houses. One cheeky ramp.
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
    {0, 29.8, 20}, {0, 29.2, 0}, {-1.3, 26.1, -29.97}, {-9.55, 23.43, -58.81}, {-17.06, 19.05, -87.85}, {-25.92, 16.38, -116.51},
    {-33.23, 13.91, -145.61}, {-46.94, 10.68, -172.3}, {-65.72, 6.85, -195.7}, {-90.28, 3.57, -212.92}, {-115.24, 0, -229.56}, {-125.22, 0.4, -236.22},
    {-135.21, 1.2, -242.87},
  },
  berms = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
  half_width = 4.1,
  widths = {
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0.988, 0.959, 0.932, 0.916, 0.906, 0.906, 0.906, 0.906, 0.906,
    0.913, 0.928, 0.946, 0.972, 0.997, 1.014, 1.017, 1.017, 1.017, 1.017, 1.017, 1.017, 1.017, 1.017, 1.017, 1.018, 1.019, 1.022, 1.024, 1.025,
    1.026, 1.026, 1.026, 1.026, 1.026, 1.026, 1.027, 1.029, 1.031, 1.034, 1.038, 1.041, 1.042, 1.042, 1.042, 1.042, 1.042, 1.041, 1.038, 1.036,
    1.035, 1.028, 1.018, 1.008, 1.002, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1,
  },
  wall_h = 0.81,
  start_point = 2,
  finish_point = 11,
  road = {0.1, 0.1, 0.11},
  grass = {0.42, 0.4, 0.37},
  hay = {0.8, 0.06, 0.04},
  seed = 20,
  urban = true,
  start_ramp = false,
}, P)
