-- The start arch's lamp 3 of 3 (the last, on the right): its lens, lit, on the arch's own skeleton
-- swaying as the arch does (_arch_rig.lua). The game shows it over the arch's dark lens and tints it (`startLights`).
local RIG = include("_arch_rig.lua")
local P = params{
  sway = { default = RIG.SWAY, min = 0, max = 5, doc = "How far the arch sways (as arch.lua's), degrees" },
  period = { default = RIG.PERIOD, min = 1.5, max = 8, doc = "Seconds for one sway (as arch.lua's)" },
}
RIG.lamp(P, 3)
