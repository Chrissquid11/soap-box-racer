-- Course 21 of 41: Airport Baggage Run. Through luggage chutes, past conveyor belts and oversized suitcases.
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
    {0, 68.75, 20}, {0, 68.15, 0}, {-9.07, 65.18, -28.59}, {-20.2, 60.05, -56.45}, {-30.73, 56.14, -84.54}, {-34.05, 51.79, -114.36},
    {-24.72, 48.13, -142.87}, {-12.64, 44.52, -170.33}, {-0.56, 37.21, -197.79}, {11.52, 29.14, -225.25}, {23.6, 23.63, -252.71}, {40.47, 18.25, -277.52},
    {67.45, 13.06, -290.64}, {96.59, 9.3, -297.78}, {125.37, 4.46, -306.24}, {155.3, 0, -304.26}, {167.27, 0.4, -303.47}, {179.25, 1.2, -302.68},
  },
  berms = {0, 0, 0, 0, 0, -0.4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
  half_width = 3.15,
  widths = {
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1.001, 1.006, 1.013, 1.023, 1.032, 1.03, 1.029, 1.028, 1.028, 1.028, 1.028, 1.028, 1.028, 1.028,
    1.028, 1.028, 1.028, 1.028, 1.028, 1.028, 1.028, 1.028, 1.028, 1.028, 1.028, 1.028, 1.028, 1.028, 1.022, 0.998, 0.918, 0.758, 0.626, 0.56,
    0.56, 0.56, 0.56, 0.56, 0.56, 0.56, 0.56, 0.56, 0.56, 0.56, 0.56, 0.617, 0.759, 0.915, 0.992, 1.003, 1.006, 1.006, 1.006, 1.006,
    1.006, 1.006, 1.006, 1.008, 1.013, 1.019, 1.024, 1.029, 1.031, 1.031, 1.031, 1.031, 1.031, 1.031, 1.031, 1.031, 1.031, 1.031, 1.031, 1.031,
    1.031, 1.03, 1.029, 1.027, 1.026, 1.025, 1.025, 1.025, 1.025, 1.025, 1.023, 1.018, 1.013, 1.006, 1.001, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  },
  wall_h = 0.67,
  start_point = 2,
  finish_point = 16,
  road = {0.14, 0.14, 0.15},
  grass = {0.46, 0.46, 0.48},
  hay = {0.95, 0.72, 0.04},
  seed = 267,
  urban = false,
  railed = false,
  bare = false,
  start_ramp = false,
  theme = "airport",
}, P)
