-- The start arch's rig, shared by the arch (arch.lua) and its three start lamps (arch_lamp_1..3.lua): its sizes, its
-- skeleton -- up each leg, round each half of the curve, the sign (the Crown) hanging off the left half -- and its clip
-- `wobble`, the inflatable's sway. The lamps are models of their own on the same skeleton playing the same clip, so the
-- game can light each one (`startLights`) while it sways with the sign it hangs under.
local M = {}

-- Metres: each leg's centre line across, the cushions' height, where the straight legs end and the curve's rise over
-- them, the sign's middle, the start lights' middle.
M.LX = 5.8
M.BASE_H = 0.6
M.LEG_TOP = 2.4
M.ARCH_B = 2.8
M.SIGN_Y = 6.1
M.LY = 4.68
-- The lamps across, their lenses' radius and how far out from the housing's middle each face's is.
M.LAMP_X = {-0.52, 0, 0.52}
M.LENS = 0.14
M.LENS_Z = 0.525

-- The wobble's defaults (each script's params{} the same: the arch and its lamps must sway alike).
M.SWAY = 2.5
M.PERIOD = 3.2

function M.skeleton()
  local LX, BASE_H, LEG_TOP, ARCH_B = M.LX, M.BASE_H, M.LEG_TOP, M.ARCH_B
  local ARC_TIP = v3(LX * 0.5, LEG_TOP + ARCH_B * 0.87, 0)
  local joints = {
    joint{name="Root", head=v3(0, 0, 0), tail=v3(0, BASE_H, 0)},
  }
  for _, s in ipairs({{"L", -1}, {"R", 1}}) do
    local n, x = s[1], s[2]
    joints[#joints + 1] = joint{name=n .. "Leg", head=v3(x * LX, BASE_H, 0), tail=v3(x * LX, LEG_TOP, 0), parent="Root"}
    joints[#joints + 1] = joint{name=n .. "Curve", head=v3(x * LX, LEG_TOP, 0), tail=v3(x * ARC_TIP.x, ARC_TIP.y, 0), parent=n .. "Leg"}
  end
  -- The sign hangs off the left half of the curve (the right sways the same): carried with the tube, bobbing on it.
  joints[#joints + 1] = joint{name="Crown", head=v3(0, LEG_TOP + ARCH_B - 0.4, 0), tail=v3(0, M.SIGN_Y + 1, 0), parent="LCurve"}
  return skeleton{name="arch", joints=joints, forward=v3(0, 0, 1), up=v3(0, 1, 0)}
end

-- One beat of the sway: side to side (`left`) and to and fro (`forward`), degrees, the curve and the sign each lagging.
function M.wobble(skel, sway, period)
  local SWAY, ROCK, PERIOD, KEYS = sway, sway * 0.6, period, 12
  local keys = {}
  for k = 0, KEYS do
    local t = PERIOD * k / KEYS
    local a = 2 * math.pi * k / KEYS
    local side = SWAY * math.sin(a)
    local fro = ROCK * math.sin(2 * a + 0.8)
    local lag = SWAY * math.sin(a - 0.9)
    local bob = SWAY * math.sin(a - 1.6)
    -- (Both legs leaning together is a shear: the top slides over, level. The sign undoes the tilt it inherits from
    -- the left half of the curve, keeping only its own bob.)
    local tilt = side + (lag - side) * 0.8
    local pose = {Crown={left=-tilt + (bob - lag) * 0.5, forward=-fro * 1.5 + fro * 0.3}}
    for _, n in ipairs({"L", "R"}) do
      pose[n .. "Leg"] = {left=side, forward=fro}
      pose[n .. "Curve"] = {left=(lag - side) * 0.8, forward=fro * 0.5}
    end
    keys[#keys + 1] = {time=t, pose=pose}
  end
  emit_action(action{name="wobble", skeleton=skel, loop=true, keys=keys})
end

-- Start lamp `i` (1 the left as the karts see it, from -z): its lit lens on both faces of the housing, just proud of
-- the arch's own (dark) lens, white -- the game tints it red, then green -- glowing a little of itself; bound whole to
-- the Crown, swaying with the sign.
function M.lamp(P, i)
  local skel = M.skeleton()
  local GLASS = material{name="Lamp", base_color=v3(1, 1, 1), emissive=v3(0.1, 0.1, 0.1), roughness=0.25, metallic=0}
  local pieces = {}
  for _, side in ipairs({-1, 1}) do
    -- From -z the karts' left is +x; from +z it is -x: lamp 1 is the first lit from the karts' side.
    local x = M.LAMP_X[side < 0 and (4 - i) or i]
    pieces[#pieces + 1] = translate(cylinder{radius=M.LENS * 0.96, height=0.014, segments=28, axis="z"}, v3(x, M.LY, side * (M.LENS_Z + 0.026)))
  end
  local m = smooth_normals(join(table.unpack(pieces)), {angle=40})
  local held = bind(m, skel, {method="envelope", envelopes={envelope{joint="Crown", radius=3}},
    regions={region{joint="Crown", min=v3(-5, -1, -5), max=v3(5, 10, 5), weight=1}}})
  emit(held, {name="lamp", material=GLASS})
  M.wobble(skel, P.sway, P.period)
end

return M
