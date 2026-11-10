-- Couch Potato: an old overstuffed sofa bolted to a plank, one part "couch". A worn taupe-brown two-seater -- a deep
-- buttoned back of two big tufted cushions, fat rolled arms, two plump seat cushions on a skirted base -- sat on a
-- bare wooden deck of planks on two runners, a bent steel brace from the deck's front corner up to an arm.
--
-- In the kart's body space, metres: the origin the middle of the (hidden) chassis box's top, +z forward, y up. The
-- driver sits on the seat cushions at about y -0.17, z -0.25, legs forward; the wheels (another slot) at x ±0.5,
-- z ±0.7, y -0.42 -- the deck kept between them.
local p = params{
  back_top = { default = 0.45, min = 0.3, max = 0.6, doc = "Height of the sofa back's top, metres" },
  puff     = { default = 0.055, min = 0.02, max = 0.06, doc = "How round and squashy the cushions are, metres" },
  tufts    = { default = 3, min = 2, max = 4, integer = true, doc = "Rows of buttons in each back cushion" },
}

local paints = {}
local function paint_of(c)
  local key = string.format("%.3f_%.3f_%.3f", c.x, c.y, c.z)
  if not paints[key] then paints[key] = material{name="Paint_" .. key, base_color=c, roughness=0.8, metallic=0} end
  return paints[key]
end
local function part(name, pieces)
  local out = {}
  for i, q in ipairs(pieces) do
    out[i] = {mesh=smooth_normals(q[1], {angle=q[3] or 40}), material=paint_of(q[2])}
  end
  local merged = merge({parts=out, mode="compatible"})
  emit(merged[1].mesh, {name=name, material=merged[1].material})
  -- The sofa (the pieces marked true, 4th): its own part, `<name>_sig`, centred on its own middle -- the game slides
  -- it off and lets it overtake the kart when the bodywork goes; the wreck is what is left, the bare deck.
  local sig, rest = {}, {}
  for i, q in ipairs(pieces) do
    if q[4] then sig[#sig + 1] = out[i] else rest[#rest + 1] = out[i] end
  end
  local s = merge({parts=sig, mode="compatible"})
  local b = bbox(s[1].mesh)
  emit(translate(s[1].mesh, v3(0, 0, 0) - b.center), {name=name .. "_sig", material=s[1].material})
  local w = merge({parts=rest, mode="compatible"})
  emit(w[1].mesh, {name=name .. "_wreck", material=w[1].material})
end
local function C(r, g, b) return v3(r, g, b) end
local function at(m, x, y, z) return translate(m, v3(x, y, z)) end
-- A box with its edges rounded over `w` (a cushion, when w is big).
local function rb(sx, sy, sz, x, y, z, w, seg)
  local m = box{size=v3(sx, sy, sz)}
  return at(bevel(m, {edges=convex_edges(m), width=w or math.min(sx, sy, sz) * 0.2, segments=seg or 2}), x, y, z)
end
local function sph(r, x, y, z, seg) return at(sphere{radius=r, segments=seg or 10, rings=math.floor((seg or 10) / 2)}, x, y, z) end
local function along(m, a, b)
  local dir = normalize(b - a)
  local c = dot(v3(0, 1, 0), dir)
  if c < -0.9999 then m = rotate(m, {angle=180, axis=axis_x(), pivot=origin()})
  elseif c < 0.9999 then m = rotate(m, {angle=deg(math.acos(c)), axis=normalize(cross(v3(0, 1, 0), dir)), pivot=origin()}) end
  return translate(m, (a + b) * 0.5)
end
local function rod(a, b, r, seg) return along(cylinder{radius=r, height=length(b - a), segments=seg or 10}, a, b) end

local FABRIC = C(0.42, 0.33, 0.27)
local CUSHION = C(0.52, 0.41, 0.33)
local SHADOW = C(0.24, 0.17, 0.13)
local BUTTON = C(0.2, 0.14, 0.1)
local WOOD = C(0.58, 0.42, 0.25)
local WOOD_DARK = C(0.42, 0.29, 0.16)
local STEEL = C(0.5, 0.52, 0.55)

local P = p.puff
local pieces = {}
local function add(m, c, a) pieces[#pieces + 1] = {m, c, a} end

-- The deck: four planks side by side along the kart on two runners, a crosswise plank at each end.
local DECK_Y = -0.32
for i = -2, 1 do
  add(rb(0.185, 0.035, 1.62, (i + 0.5) * 0.19, DECK_Y, -0.04, 0.006, 1), (i % 2 == 0) and WOOD or C(0.62, 0.46, 0.28))
end
for _, x in ipairs({-0.26, 0.26}) do add(rb(0.07, 0.06, 1.5, x, DECK_Y - 0.045, -0.04, 0.008, 1), WOOD_DARK) end
for _, z in ipairs({0.72, -0.8}) do add(rb(0.76, 0.03, 0.1, 0, DECK_Y + 0.03, z, 0.006, 1), WOOD_DARK) end

-- The sofa: its skirted base, two seat cushions, the arms, the back. (Its signature: it comes off whole.)
local sofa_from = #pieces + 1
local BASE_Y0 = DECK_Y + 0.02
local SEAT_Y = -0.2                -- the base's top, the seat cushions on it
local FRONT, BACK = 0.2, -0.66     -- the sofa's front and back faces
local HALF = 0.58                  -- its half width over the arms
add(rb(HALF * 2 - 0.08, SEAT_Y - BASE_Y0, FRONT - BACK - 0.02, 0, (BASE_Y0 + SEAT_Y) / 2, (FRONT + BACK) / 2, 0.03), FABRIC)
-- A dark band low round the skirt.
add(rb(HALF * 2 - 0.06, 0.025, FRONT - BACK, 0, BASE_Y0 + 0.02, (FRONT + BACK) / 2, 0.01, 1), SHADOW)
for _, s in ipairs({-1, 1}) do
  -- Seat cushions: plump, a little gap between them.
  add(rb(0.4, 0.12, 0.6, s * 0.205, SEAT_Y + 0.05, -0.08, math.min(P, 0.058), 2), CUSHION, 60)
  -- The arms: a panel up the side, a fat roll along its top, its front end a round scroll.
  local ax = s * (HALF - 0.08)
  add(rb(0.16, 0.3, FRONT - BACK, ax, SEAT_Y + 0.08, (FRONT + BACK) / 2, 0.04), FABRIC)
  add(at(capsule{radius=0.105, height=FRONT - BACK - 0.02, segments=18, rings=6, axis="z"}, ax + s * 0.01, SEAT_Y + 0.26, (FRONT + BACK) / 2), CUSHION, 70)
  add(at(cylinder{radius=0.075, height=0.02, segments=18, axis="z"}, ax + s * 0.01, SEAT_Y + 0.26, FRONT + 0.075), SHADOW)
end

-- The back: a frame behind, and two deep tufted cushions leaning on it, buttoned in a diamond.
local BT = p.back_top
add(rb(HALF * 2 - 0.1, BT - SEAT_Y + 0.02, 0.16, 0, (BT + SEAT_Y) / 2, BACK + 0.08, 0.05), FABRIC)
local CUSH_Y0, CUSH_Y1 = SEAT_Y + 0.1, BT - 0.03
local CZ = BACK + 0.24
for _, s in ipairs({-1, 1}) do
  local cx = s * 0.205
  add(rb(0.4, CUSH_Y1 - CUSH_Y0, 0.17, cx, (CUSH_Y0 + CUSH_Y1) / 2, CZ, P * 1.3, 2), CUSHION, 60)
  -- Buttons, rows staggered: each dimpled into the cushion's face.
  local rows = p.tufts
  for r = 1, rows do
    local y = CUSH_Y0 + (CUSH_Y1 - CUSH_Y0) * r / (rows + 1)
    local cols = (r % 2 == 1) and {-0.1, 0.1} or {0}
    for _, dx in ipairs(cols) do
      add(sph(0.016, cx + dx, y, CZ + 0.085, 10), BUTTON, 80)
    end
  end
end
-- A roll of fabric along the back's top edge.
add(at(capsule{radius=0.07, height=HALF * 2 - 0.24, segments=16, rings=6, axis="x"}, 0, BT + 0.02, BACK + 0.1), CUSHION, 70)

for i = sofa_from, #pieces do pieces[i][4] = true end

-- The brace: a bent steel tube from the deck's front corner up to the right arm's front, bolted at each end.
local a = v3(0.34, DECK_Y + 0.02, 0.62)
local b = v3(0.4, SEAT_Y + 0.02, 0.36)
local c = v3(HALF - 0.08, SEAT_Y + 0.2, FRONT - 0.02)
add(rod(a, b, 0.018), STEEL)
add(rod(b, c, 0.018), STEEL)
add(sph(0.02, b.x, b.y, b.z, 10), STEEL, 80)
for _, q in ipairs({a, c}) do add(sph(0.026, q.x, q.y, q.z, 10), STEEL, 80) end

part("couch", pieces)
