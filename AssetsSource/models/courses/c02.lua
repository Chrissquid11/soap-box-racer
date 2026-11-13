-- Course 2 of 41: Bristol Bombdown. Bristol, England. Down the terraced streets past the coloured houses. One cheeky ramp.
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
    {0, 29.8, 20}, {0, 29.2, 0}, {-1.3, 26.1, -29.97}, {-9.55, 23.43, -58.81}, {-17.06, 19.05, -87.85}, {-25.92, 18.79, -116.51},
    {-33.23, 15.12, -145.61}, {-46.94, 10.68, -172.3}, {-65.72, 6.85, -195.7}, {-90.28, 3.57, -212.92}, {-115.24, 0, -229.56}, {-125.22, 0.4, -236.22},
    {-135.21, 1.2, -242.87},
  },
  berms = {0, 0, 0, 0, 0, 0, 0, 0.31, 0, 0, 0, 0, 0},
  half_width = 3.68,
  widths = {
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0.997, 0.987, 0.972, 0.953, 0.939, 0.956, 0.97, 0.98, 0.985,
    0.986, 0.986, 0.986, 0.986, 0.986, 0.986, 0.986, 0.986, 0.986, 0.986, 0.986, 0.986, 0.986, 0.986, 0.986, 0.987, 0.994, 1.004, 1.012, 1.018,
    1.023, 1.026, 1.026, 1.026, 1.026, 1.026, 1.027, 1.029, 1.032, 1.035, 1.037, 1.043, 1.049, 1.054, 1.058, 1.059, 1.059, 1.059, 1.059, 1.059,
    1.054, 1.044, 1.033, 1.016, 1.004, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
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
  railed = true,
  bare = false,
  start_ramp = false,
  theme = "bristol",
}, P)
