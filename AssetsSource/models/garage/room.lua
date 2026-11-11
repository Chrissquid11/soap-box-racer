-- The garage: a cluttered, untidy home garage-cum-shed where an amateur builds soapbox karts -- the backdrop the kart
-- sits in on the garage screen. One part, "room".
--
-- Metres; the origin the middle of the floor, the floor's top at y = 0, +z the kart's front. 11 m wide (x), 11 m
-- deep (z); the eaves 3.45 m up over the side walls (+-x), the ridge 4.6 m up, running along z. The kart sits at the
-- origin and the camera circles it at 4.2 m: nothing stands within 4.9 m of the centre between y 0.3 and 3.4 -- only
-- low clutter on the floor there (stains, offcuts, a tipped tin, an open toolbox, a cable) and, above 3.45 m,
-- the rafters, collar ties and the tube. (The eaves sit as low as that allows: a rafter's underside 4.9 m out is 3.455.)
--
-- Walls: a dwarf wall of rough stone, weathered and patched weatherboards above it on bare studs. Each seen from inside:
--   back  (-z, a gable): the WORKSHOP sign over the whiteboard of kart sketches (side view, plan with dimensions,
--                        notes, a photo under magnets, the marker tray) over an old cabinet; the corkboard of pinned
--                        plans; the pegboard of painted tool outlines; shelves of tins, jars, boxes; the parts drawers,
--                        a stepladder, a deckchair and a tin bath
--   left  (-x): the workbench under the dusty window, piled up -- a 3D printer, a soldering station, an open toolbox,
--               a drill press, the vice, clamps, tools, radio, mug; a bare bulb; goggles and ear defenders on a hook,
--               a poster, a calendar; the overflowing bin, a Workmate, garden tools in the front corner
--   right (+x): the bicycle hung on hooks, a dartboard, a half-built kart chassis and wheels leaning, the lawnmower,
--               the hose reel, crooked boxes and shelves in the back corner
--   front (+z, a gable): the double wooden doors (daylight under them), timber over them, a coat and wellies, a
--                        painted cupboard, the chest freezer, a pallet, old tyres in the corner
-- Colours are painted on the vertices, one white material.
local P = params{
  drop    = { default = 0.5, min = 0.2, max = 0.8, doc = "Fluorescent tube's chains below the ridge, metres" },
  rafters = { default = 10, min = 7, max = 14, integer = true, doc = "Roof rafters along the length" },
  tyres   = { default = 3, min = 1, max = 5, integer = true, doc = "Old tyres stacked in the front corner" },
  mess    = { default = true, doc = "Clutter on the floor: offcuts, sawdust, rags, a tipped tin, an open toolbox, a cable" },
  stuff   = { default = 1.1, min = 0.8, max = 1.3, doc = "Everything in the room (the doors too) this many times its size; the walls, roof and floor as they are" },
}

local PAINT = material{name="Paint", base_color=v3(1, 1, 1), roughness=0.75, metallic=0}

local function all(m) return faces_where(m, function(_) return true end) end
local function paint(m, c) return paint_faces(m, {faces=all(m), color=c}) end
local function C(r, g, b) return v3(r, g, b) end
local function shade(c, k) return v3(math.min(1, c.x * k), math.min(1, c.y * k), math.min(1, c.z * k)) end
-- A repeatable 0..1 noise for colour variation and wobble.
local function hash(i) local s = math.sin(i * 12.9898 + 78.233) * 43758.5453; return s - math.floor(s) end
local function vary(c, i, amt) return shade(c, 1 - amt + 2 * amt * hash(i)) end
local function at(m, x, y, z) return translate(m, v3(x, y, z)) end
local function bx(sx, sy, sz, x, y, z) return at(box{size=v3(sx, sy, sz)}, x, y, z) end
-- A box between two corners.
local function bmm(x0, y0, z0, x1, y1, z1)
  return bx(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0), (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
end
local function cyl(r, h, x, y, z, axis, seg) return at(cylinder{radius=r, height=h, segments=seg or 14, axis=axis or "y"}, x, y, z) end
local function sub(a, b) return v3(a.x - b.x, a.y - b.y, a.z - b.z) end
-- A rod of radius r from p to q.
local function tube(p, q, r, seg)
  local d = sub(q, p)
  local m = cylinder{radius=r, height=length(d), segments=seg or 8}
  m = align(m, {from=axis_y(), to=normalize(d), pivot=origin()})
  return at(m, (p.x + q.x) / 2, (p.y + q.y) / 2, (p.z + q.z) / 2)
end
-- A prism: the planar convex polygon pts (Vec3s) pushed out along off.
local function prism(pts, off)
  local n = #pts
  local o = pts
  if dot(cross(sub(pts[2], pts[1]), sub(pts[3], pts[1])), off) < 0 then
    o = {}
    for i = n, 1, -1 do o[#o + 1] = pts[i] end
  end
  local vs, fs = {}, {}
  for i = 1, n do
    local p = o[i]
    vs[i] = v3(p.x + off.x, p.y + off.y, p.z + off.z); vs[n + i] = p
  end
  local top, bot = {}, {}
  for i = 1, n do top[i] = i; bot[i] = 2 * n + 1 - i end
  fs[1] = top; fs[2] = bot
  for i = 1, n do
    local j = i % n + 1
    fs[#fs + 1] = {i, n + i, n + j, j}
  end
  return polyhedron{vertices=vs, faces=fs}
end
-- A flat slab over the floor: the polygon pts ({x, z} pairs, convex) from y0 up to y1.
local function slab(pts, y0, y1)
  local vs = {}
  for i, p in ipairs(pts) do vs[i] = v3(p[1], y0, p[2]) end
  return prism(vs, v3(0, y1 - y0, 0))
end
-- A convex blob on the floor: n points round (x, z), radii rx, rz, a little ragged.
local function blob(x, z, rx, rz, seed, y0, y1)
  local pts = {}
  for k = 0, 11 do
    local t = k * math.pi / 6
    local w = 0.85 + 0.15 * hash(seed + k)
    pts[#pts + 1] = {x + rx * w * math.cos(t), z + rz * w * math.sin(t)}
  end
  return slab(pts, y0, y1)
end
local function rot(m, ang, axis, pv) return rotate(m, {angle=ang, axis=axis, pivot=pv or origin()}) end

local CUT = nil -- (a cutaway to look inside: a set of walls, {front = true, right = true}, dropped with the roof; set by hand in a copy, never here)
local SKIP = false
local pieces = {}
local function add(m, c, angle) if not SKIP then pieces[#pieces + 1] = {m, c, angle} end end
-- Build pieces with put(m, c, angle) about the origin, then move every one by xf.
local function group(build, xf)
  local g = {}
  build(function(m, c, ang) g[#g + 1] = {m, c, ang} end)
  for _, p in ipairs(g) do add(xf(p[1]), p[2], p[3]) end
end

-- Palette (linear) ---------------------------------------------------------------------------------------------------
local concrete = C(0.16, 0.13, 0.095)   -- old, earthy, trodden
local joint    = C(0.075, 0.07, 0.064)
local oil      = C(0.03, 0.028, 0.026)
local sawdust  = C(0.42, 0.3, 0.16)
local blockC   = C(0.25, 0.21, 0.16)    -- rough stone
local mortar   = C(0.17, 0.15, 0.12)
local boardC   = C(0.33, 0.195, 0.095)
local backing  = C(0.03, 0.02, 0.012)
local studC    = C(0.3, 0.19, 0.1)      -- rough-sawn, darkened with age
local sheetC   = C(0.1, 0.095, 0.085)
local ridgeC   = C(0.17, 0.16, 0.14)
local skylight = C(0.62, 0.6, 0.48)
local wood     = C(0.36, 0.21, 0.09)
local woodDk   = C(0.18, 0.09, 0.04)
local woodPale = C(0.55, 0.4, 0.22)
local metal    = C(0.3, 0.31, 0.32)
local metalDk  = C(0.06, 0.065, 0.07)
local steel    = C(0.6, 0.61, 0.62)
local rubber   = C(0.02, 0.02, 0.022)
local white    = C(0.75, 0.74, 0.7)
local paper    = C(0.82, 0.8, 0.72)
local cream    = C(0.62, 0.55, 0.38)
local red      = C(0.55, 0.06, 0.03)
local orange   = C(0.85, 0.3, 0.04)
local yellow   = C(0.85, 0.6, 0.05)
local green    = C(0.07, 0.2, 0.08)
local blue     = C(0.05, 0.14, 0.42)
local vblue    = C(0.03, 0.12, 0.3)   -- an old vice's blue
local card     = C(0.34, 0.2, 0.09)
local tape     = C(0.5, 0.38, 0.2)
local terra    = C(0.5, 0.17, 0.07)
local glow     = C(1.0, 0.92, 0.7)
local tubeGlow = C(0.95, 0.98, 1.0)
local glass    = C(0.42, 0.46, 0.42)
local garden   = C(0.16, 0.26, 0.1)
local sky      = C(0.62, 0.66, 0.66)
local pegC     = C(0.3, 0.18, 0.09)
local shadowC  = C(0.02, 0.015, 0.012)
local inkK     = C(0.015, 0.015, 0.025)  -- the markers: black, red, blue
local inkR     = C(0.7, 0.03, 0.02)
local inkB     = C(0.02, 0.08, 0.6)

local W = 5.5               -- the half width (and half depth) at the walls' backs
local IN = W - 0.05         -- the inner face of the wall slabs
local EAVE, RIDGE = 3.45, 4.6
local RAFTER = 0.12         -- a rafter's depth under the sheets
local function roofY(x) return EAVE + (RIDGE - EAVE) * (1 - math.abs(x) / W) end
local STUD = 0.13           -- the studs' room-side face, out from the slab: things hung on the wall start here

-- Floor --------------------------------------------------------------------------------------------------------------
add(bmm(-W - 0.1, -0.2, -W - 0.1, W + 0.1, 0, W + 0.1), concrete)
for _, s in ipairs({-W / 2, W / 2}) do
  add(bmm(s - 0.01, 0, -IN, s + 0.01, 0.003, IN), joint)
  add(bmm(-IN, 0, s - 0.01, IN, 0.0035, s + 0.01), joint)
end
-- Oil stains: dark blots, a few overlapping.
for i, s in ipairs({{2.2, 1.9, 0.38}, {2.5, 2.25, 0.22}, {-2.3, -2.6, 0.42}, {-1.95, -2.9, 0.2}, {2.9, -2.6, 0.3},
                    {-2.8, 2.6, 0.27}, {0.3, -3.1, 0.18}, {3.5, 0.5, 0.25}}) do
  add(cyl(s[3], 0.002, s[1], 0.001 + i * 0.0002, s[2], "y", 20), shade(oil, 1 + 0.6 * hash(i)), 10)
end
-- A light pool under the tube.
do
  local e = {}
  for k = 0, 35 do e[#e + 1] = {1.8 * math.cos(k * math.pi / 18), 2.6 * math.sin(k * math.pi / 18)} end
  add(slab(e, 0, 0.002), shade(concrete, 1.35), 10)
end

-- Walls ----------------------------------------------------------------------------------------------------------------
-- Each wall in its own frame: along (a), up (y), and depth into the room from the wall's inner face.
-- toWorld(a, y, d) for each wall; a runs left to right as seen from inside.
local WALLS = {
  back  = function(a, y, d) return v3(a, y, -IN + d) end,
  front = function(a, y, d) return v3(-a, y, IN - d) end,
  left  = function(a, y, d) return v3(-IN + d, y, -a) end,
  right = function(a, y, d) return v3(IN - d, y, a) end,
}
local GABLE = {back = true, front = true}
-- A box on a wall: a0..a1 along it, y0..y1 up, d0..d1 out from the slab's face.
local function wbox(wall, a0, a1, y0, y1, d0, d1)
  local f = WALLS[wall]
  local p, q = f(a0, y0, d0), f(a1, y1, d1)
  return bmm(math.min(p.x, q.x), math.min(p.y, q.y), math.min(p.z, q.z), math.max(p.x, q.x), math.max(p.y, q.y), math.max(p.z, q.z))
end
local function wpt(wall, a, y, d) return WALLS[wall](a, y, d) end
-- A flat shape on a wall: the convex polygon ag ({a, y} pairs) from d0 out to d1.
local function wprism(wall, ag, d0, d1)
  local f = WALLS[wall]
  local pts = {}
  for i, p in ipairs(ag) do pts[i] = f(p[1], p[2], d0) end
  local o, q = f(0, 0, 0), f(0, 0, 1)
  local n = sub(q, o)
  return prism(pts, v3(n.x * (d1 - d0), n.y * (d1 - d0), n.z * (d1 - d0)))
end
-- A quad on a wall, w by h round (a, y), turned ang degrees.
local function wquad(wall, a, y, w, h, ang, d0, d1)
  local c, s = math.cos(math.rad(ang)), math.sin(math.rad(ang))
  local pts = {}
  for _, k in ipairs({{-1, -1}, {1, -1}, {1, 1}, {-1, 1}}) do
    local u, v = k[1] * w / 2, k[2] * h / 2
    pts[#pts + 1] = {a + u * c - v * s, y + u * s + v * c}
  end
  return wprism(wall, pts, d0, d1)
end

-- The openings: the doors in the front, the window (over the bench) in the left.
-- The doors: 20% bigger again than the rest of the stuff (DOORS), the coat and the freezer either side still clear.
local DOORS = 1.2
local OPEN = { front = {-1.3 * P.stuff * DOORS, 1.3 * P.stuff * DOORS, 0, 2.15 * P.stuff * DOORS}, left = {2.2, 3.8, 1.25, 2.3} }
-- a0..a1 at y0..y1 with the wall's opening taken out.
local function spans(wall, a0, a1, y0, y1)
  local o = OPEN[wall]
  if not o or y1 <= o[3] or y0 >= o[4] or a1 <= o[1] or a0 >= o[2] then return {{a0, a1}} end
  local r = {}
  if a0 < o[1] then r[#r + 1] = {a0, o[1]} end
  if a1 > o[2] then r[#r + 1] = {o[2], a1} end
  return r
end

local DWARF = 0.9           -- the dwarf wall's top
local BP = (EAVE - 0.96) / 16
local seed = 0
for name, _ in pairs(WALLS) do
  seed = seed + 1000
  SKIP = CUT ~= nil and CUT[name] == true
  local gable = GABLE[name]
  local half = gable and W + 0.05 or IN
  -- the slab behind, dark where the boards' gaps show it
  if gable then
    add(wprism(name, {{-half, 0}, {half, 0}, {half, roofY(half) + 0.06}, {0, RIDGE + 0.06}, {-half, roofY(half) + 0.06}}, -0.1, 0), backing)
  else
    add(wbox(name, -half, half, 0, EAVE + 0.06, -0.1, 0), backing)
  end
  -- the dwarf wall of rough stone: mortar behind, the stones proud of it by more or less, grey and brown
  for _, s in ipairs(spans(name, -half, half, 0, DWARF)) do add(wbox(name, s[1], s[2], 0, DWARF, 0, 0.03), mortar) end
  for row = 0, 3 do
    local y0 = row * 0.225
    local a = -half - (row % 2) * 0.225
    local k = 0
    while a < half do
      local b0, b1 = math.max(a + 0.005, -half), math.min(a + 0.445, half)
      if b1 - b0 > 0.02 then
        for _, s in ipairs(spans(name, b0, b1, y0, y0 + 0.215)) do
          add(wbox(name, s[1], s[2], y0 + 0.005, y0 + 0.22, 0, 0.03 + 0.025 * hash(seed + row * 70 + k)), vary(hash(seed + row * 90 + k) > 0.6 and C(0.22, 0.2, 0.18) or blockC, seed + row * 50 + k, 0.25))
        end
      end
      a = a + 0.45
      k = k + 1
    end
  end
  -- the sole plate on the blocks
  for _, s in ipairs(spans(name, -half, half, DWARF, 0.96)) do add(wbox(name, s[1], s[2], DWARF, 0.96, 0, STUD), studC) end
  -- weatherboards, each its own shade; on a gable they climb into the apex
  local i = 0
  while true do
    local y0 = 0.96 + i * BP
    local y1 = y0 + BP - 0.012
    local c = vary(boardC, seed + 300 + i, 0.28)
    local age = hash(seed + 500 + i)
    if age > 0.78 then c = vary(C(0.3, 0.28, 0.24), i, 0.15) elseif age < 0.1 then c = vary(C(0.12, 0.07, 0.04), i, 0.2) end   -- silvered by the weather; tarred
    if hash(seed + 400 + i) > 0.88 then c = vary(woodPale, i, 0.1) end     -- a board replaced since
    if y1 <= EAVE + 0.001 then
      for _, s in ipairs(spans(name, -half, half, y0, y1)) do add(wbox(name, s[1], s[2], y0, y1, 0, 0.02), c) end
    elseif gable then
      local h0, h1 = W * (1 - (y0 - EAVE) / (RIDGE - EAVE)), W * (1 - (y1 - EAVE) / (RIDGE - EAVE))
      if h1 < 0.08 then break end
      add(wprism(name, {{-h0, y0}, {h0, y0}, {h1, y1}, {-h1, y1}}, 0, 0.02), c)
    else
      break
    end
    i = i + 1
  end
  -- studs every 0.6 m, trimmers and a header round the opening, a noggin rail across
  local o = OPEN[name]
  local a = -half + 0.08
  while a < half - 0.02 do
    local top = gable and roofY(math.abs(a) + 0.03) - 0.04 or EAVE - 0.1
    if o and a > o[1] - 0.05 and a < o[2] + 0.05 then
      if top > o[4] + 0.12 then add(wbox(name, a - 0.025, a + 0.025, o[4] + 0.1, top, 0.02, STUD), studC) end
      if o[3] > 1.1 then add(wbox(name, a - 0.025, a + 0.025, 0.96, o[3] - 0.08, 0.02, STUD), studC) end
    elseif top > 1.0 then
      add(wbox(name, a - 0.025, a + 0.025, 0.96, top, 0.02, STUD), vary(studC, seed + 600 + a * 10, 0.08))
    end
    a = a + 0.6
  end
  if o then
    for _, ta in ipairs({o[1] - 0.05, o[2] + 0.05}) do add(wbox(name, ta - 0.03, ta + 0.03, o[3] > 0.5 and 0.96 or 0, o[4] + 0.1, 0.02, STUD), studC) end
    add(wbox(name, o[1] - 0.08, o[2] + 0.08, o[4], o[4] + 0.1, 0.02, STUD), studC)
    if o[3] > 0.5 then add(wbox(name, o[1] - 0.08, o[2] + 0.08, o[3] - 0.08, o[3], 0.02, STUD), studC) end
  end
  for _, s in ipairs(spans(name, -half + 0.05, half - 0.05, 2.0, 2.07)) do add(wbox(name, s[1], s[2], 2.0, 2.07, 0.02, STUD - 0.01), studC) end
  if not gable then add(wbox(name, -half, half, EAVE - 0.1, EAVE, 0.02, STUD + 0.02), studC) end
end

-- Roof: corrugated sheets on rafters, a ridge board, collar ties carrying stored timber --------------------------------
SKIP = CUT ~= nil
for _, s in ipairs({-1, 1}) do
  local xe = s * (W + 0.15)
  add(prism({v3(0, RIDGE, -W - 0.1), v3(xe, roofY(W + 0.15), -W - 0.1), v3(xe, roofY(W + 0.15), W + 0.1), v3(0, RIDGE, W + 0.1)}, v3(0, 0.05, 0)), sheetC)
  -- the corrugations: a lighter ridge every 0.16 m, running down the slope; a clear rooflight sheet on the left
  local k = 0
  local z = -W
  while z < W - 0.05 do
    local lit = s < 0 and z > -1.2 and z < 0.3
    local c = lit and skylight or vary(ridgeC, k, 0.08)
    add(prism({v3(0, RIDGE - 0.012, z), v3(s * W, roofY(W) - 0.012, z), v3(s * W, roofY(W) - 0.012, z + 0.08), v3(0, RIDGE - 0.012, z + 0.08)}, v3(0, 0.012, 0)), c)
    if lit then
      add(prism({v3(0, RIDGE - 0.006, z + 0.08), v3(s * W, roofY(W) - 0.006, z + 0.08), v3(s * W, roofY(W) - 0.006, z + 0.16), v3(0, RIDGE - 0.006, z + 0.16)}, v3(0, 0.006, 0)), shade(skylight, 0.8))
    end
    z = z + 0.16
    k = k + 1
  end
end
SKIP = false
add(bmm(-0.03, RIDGE - 0.2, -IN, 0.03, RIDGE, IN), studC)
local collars = {}
for i = 1, P.rafters do
  local z = -IN + 0.06 + (2 * IN - 0.12) * (i - 1) / (P.rafters - 1)
  for _, s in ipairs({-1, 1}) do
    add(prism({v3(0, RIDGE, z - 0.025), v3(s * IN, roofY(IN), z - 0.025), v3(s * IN, roofY(IN) - RAFTER, z - 0.025), v3(0, RIDGE - RAFTER, z - 0.025)}, v3(0, 0, 0.05)), vary(studC, i * 7 + s, 0.08))
  end
  if i % 3 == 2 and i < P.rafters then
    add(bmm(-4.1, 3.48, z + 0.025, 4.1, 3.6, z + 0.07), studC)
    collars[#collars + 1] = z
  end
end
-- stored up on the first two collars: lengths of timber, a rolled-up carpet, an old sledge
do
  local z0, z1 = collars[1] - 0.35, collars[2] + 0.35
  for i, x in ipairs({-3.3, -3.12, -2.94, -2.76}) do add(bmm(x, 3.6, z0 + 0.1 * i, x + 0.15, 3.645, z1 - 0.1 * i), vary(woodPale, i, 0.15)) end
  add(bmm(-3.2, 3.645, z0 + 0.3, -2.98, 3.69, z1 - 0.2), wood)
  add(cyl(0.08, z1 - z0 - 0.5, 2.5, 3.68, (z0 + z1) / 2, "z", 14), C(0.32, 0.22, 0.12), 40)
  add(cyl(0.081, 0.02, 2.5, 3.68, z0 + 0.3, "z", 14), C(0.2, 0.06, 0.04), 40)
  for _, x in ipairs({1.0, 1.5}) do add(bmm(x - 0.02, 3.6, z0 + 0.4, x + 0.02, 3.66, z0 + 1.3), red) end
  for k = 0, 3 do add(bmm(0.95, 3.66, z0 + 0.5 + k * 0.2, 1.55, 3.68, z0 + 0.6 + k * 0.2), woodPale) end
end

-- The fluorescent tube, hung on two chains from the ridge over the kart.
do
  local yt = RIDGE - 0.2 - P.drop
  for _, z in ipairs({-0.6, 0.6}) do add(cyl(0.006, P.drop, 0, yt + P.drop / 2, z, "y", 4), metalDk) end
  add(bmm(-0.06, yt - 0.05, -0.78, 0.06, yt, 0.78), white)
  add(bmm(-0.05, yt - 0.07, -0.76, -0.03, yt - 0.05, -0.72), metalDk)
  add(bmm(-0.05, yt - 0.07, 0.72, -0.03, yt - 0.05, 0.76), metalDk)
  add(cyl(0.022, 1.46, 0, yt - 0.075, 0, "z", 10), tubeGlow, 60)
end

-- Helpers for the stuff on benches and shelves -------------------------------------------------------------------------
local function tin(x, y, z, r, h, c)
  add(cyl(r, h, x, y + h / 2, z, "y", 16), c, 50)
  add(cyl(r * 1.02, 0.012, x, y + h + 0.006, z, "y", 16), steel, 50)
  add(cyl(r * 1.005, h * 0.35, x, y + h * 0.42, z, "y", 16), white, 50)
end
-- A jam jar: what's in it below, the empty glass above, a lid.
local function jar(x, y, z, r, h, stuff, lid)
  add(cyl(r, h * 0.65, x, y + h * 0.325, z, "y", 14), stuff, 40)
  add(cyl(r * 0.98, h * 0.35, x, y + h * 0.825, z, "y", 14), glass, 40)
  add(cyl(r * 1.04, 0.02, x, y + h + 0.01, z, "y", 14), lid, 40)
end
-- A cardboard box w by d (x, z) and h high on (x, y0, z), turned ang about y, with a strip of tape over its top.
local function cbox(x, y0, z, w, h, d, ang, i)
  group(function(put)
    put(bmm(-w / 2, 0, -d / 2, w / 2, h, d / 2), vary(card, i, 0.15))
    put(bmm(-w / 2 - 0.002, h, -0.03, w / 2 + 0.002, h + 0.002, 0.03), tape)
    put(bmm(-w / 2 - 0.002, h * 0.55, -0.03, -w / 2, h, 0.03), tape)
  end, function(m) return at(rot(m, ang, axis_y()), x, y0, z) end)
end
local function tyre(x, y, z, axis, R, r)
  add(at(torus{major_radius=R or 0.29, minor_radius=r or 0.11, major_segments=24, minor_segments=8, axis=axis or "y"}, x, y, z), rubber, 50)
end
-- A plank shelf on two brackets on a wall: a0..a1 along it, its top at y, deep dd.
local function wshelf(wall, a0, a1, y, dd)
  add(wbox(wall, a0, a1, y - 0.025, y, STUD, STUD + dd), wood)
  for _, a in ipairs({a0 + 0.12, a1 - 0.12}) do
    add(wbox(wall, a - 0.015, a + 0.015, y - 0.22, y - 0.025, STUD, STUD + 0.03), metalDk)
    add(wbox(wall, a - 0.015, a + 0.015, y - 0.05, y - 0.025, STUD, STUD + dd - 0.04), metalDk)
  end
end
-- Hand-drawn lines on a wall: a polyline of {a, y} points w wide, a hair (d) off the face.
local function stroke(wall, pts, w, c, d)
  for i = 1, #pts - 1 do
    local p, q = pts[i], pts[i + 1]
    local da, dy = q[1] - p[1], q[2] - p[2]
    local L = math.sqrt(da * da + dy * dy)
    if L > 1e-4 then
      local na, ny = -dy / L * w / 2, da / L * w / 2
      local ea, ey = da / L * w * 0.45, dy / L * w * 0.45
      add(wprism(wall, {{p[1] + na - ea, p[2] + ny - ey}, {q[1] + na + ea, q[2] + ny + ey}, {q[1] - na + ea, q[2] - ny + ey}, {p[1] - na - ea, p[2] - ny - ey}}, d, d + 0.0015), c)
    end
  end
end
local function circle(ca, cy, r, n)
  local t = {}
  for k = 0, n do local u = k * 2 * math.pi / n; t[#t + 1] = {ca + r * math.cos(u), cy + r * math.sin(u)} end
  return t
end
-- A hand's wobble on a polyline.
local function wobble(pts, amt, sd)
  local o = {}
  for i, p in ipairs(pts) do o[i] = {p[1] + (hash(sd + i) - 0.5) * amt, p[2] + (hash(sd + i + 100) - 0.5) * amt} end
  return o
end
-- Handwriting: a squiggle from a0 to a1 round y, h tall.
local function scrawl(a0, a1, y, h, sd)
  local t = {}
  local n = math.max(3, math.floor((a1 - a0) / 0.02))
  for k = 0, n do t[#t + 1] = {a0 + (a1 - a0) * k / n, y + h * 0.5 * math.sin(k * 2.3 + sd) + h * 0.25 * math.sin(k * 0.9 + sd * 3)} end
  return t
end
-- An arrowhead at q pointing away from p.
local function arrowhead(p, q, s)
  local da, dy = q[1] - p[1], q[2] - p[2]
  local L = math.sqrt(da * da + dy * dy)
  da, dy = da / L, dy / L
  local l = {q[1] - s * (da + dy * 0.6), q[2] - s * (dy - da * 0.6)}
  local r = {q[1] - s * (da - dy * 0.6), q[2] - s * (dy + da * 0.6)}
  return {l, q, r}
end

-- Block letters for the sign: each glyph its width in cells and its rects {x0, y0, x1, y1} on a 5-high grid.
local GLYPH = {
  W = {5, {{0,0,1,5},{4,0,5,5},{2,1,3,3},{1,0,2,1},{3,0,4,1}}},
  O = {3, {{0,0,1,5},{2,0,3,5},{1,0,2,1},{1,4,2,5}}},
  R = {3, {{0,0,1,5},{1,4,2,5},{2,3,3,4},{1,2,2,3},{2,0,3,2}}},
  K = {3, {{0,0,1,5},{1,2,2,3},{2,3,3,5},{2,0,3,2}}},
  S = {3, {{0,4,3,5},{0,3,1,4},{0,2,3,3},{2,1,3,2},{0,0,3,1}}},
  H = {3, {{0,0,1,5},{2,0,3,5},{1,2,2,3}}},
  P = {3, {{0,0,1,5},{1,4,3,5},{2,2,3,4},{1,2,2,3}}},
}
local function text(s, fn)
  local cx = 0
  for ch in s:gmatch(".") do
    local g = GLYPH[ch]
    for _, r in ipairs(g[2]) do fn(cx + r[1], r[2], cx + r[3], r[4]) end
    cx = cx + g[1] + 1
  end
  return cx - 1
end

-- What is in the room, as against the room itself: these runs of pieces are grown by P.stuff before the part is made
-- (the window and the doors are the room's: the doors grow with their opening, OPEN.front).
local STUFF = {}
local stuffFrom = #pieces + 1

-- Back wall: the WORKSHOP sign, the whiteboard of kart sketches, the cabinet under it ----------------------------------
do
  -- the sign: a cream board, red letters, an orange edge
  local u = 0.045
  local sw = text("WORKSHOP", function() end) * u
  add(wbox("back", -sw / 2 - 0.1, sw / 2 + 0.1, 2.52, 2.9, STUD, STUD + 0.02), cream)
  add(wbox("back", -sw / 2 - 0.1, sw / 2 + 0.1, 2.52, 2.55, STUD + 0.02, STUD + 0.023), orange)
  add(wbox("back", -sw / 2 - 0.1, sw / 2 + 0.1, 2.87, 2.9, STUD + 0.02, STUD + 0.023), orange)
  text("WORKSHOP", function(x0, y0, x1, y1)
    add(wbox("back", -sw / 2 + x0 * u, -sw / 2 + x1 * u, 2.6 + y0 * u, 2.6 + y1 * u, STUD + 0.02, STUD + 0.026), red)
  end)
  for _, a in ipairs({-sw / 2 - 0.05, sw / 2 + 0.05}) do add(cyl(0.008, 0.02, a, 2.71, -IN + STUD + 0.03, "z", 6), metalDk) end

  -- the whiteboard: an aluminium frame, the white face
  local a0, a1, y0, y1 = -1.3, 1.3, 1.15, 2.35
  local F = STUD + 0.02
  add(wbox("back", a0, a1, y0, y1, STUD, F), C(0.86, 0.87, 0.86))
  for _, r in ipairs({{a0 - 0.03, a1 + 0.03, y0 - 0.03, y0}, {a0 - 0.03, a1 + 0.03, y1, y1 + 0.03}, {a0 - 0.03, a0, y0, y1}, {a1, a1 + 0.03, y0, y1}}) do
    add(wbox("back", r[1], r[2], r[3], r[4], STUD, F + 0.012), C(0.55, 0.56, 0.58))
  end
  -- faint ghosts of old drawings rubbed out
  for k, g in ipairs({{-0.3, 1.95, 0.5, 0.2}, {0.6, 1.3, 0.6, 0.12}, {-0.9, 1.3, 0.4, 0.1}}) do
    add(wquad("back", g[1], g[2], g[3], g[4], 4 * k, F, F + 0.0005), C(0.8, 0.81, 0.815))
  end
  local LW = 0.013
  local dK, dR, dB = F + 0.001, F + 0.0013, F + 0.0016
  -- 1. The side view, left half: the body, wheels, the driver as a stick figure
  local body = {{-1.12, 1.6}, {-0.2, 1.6}, {-0.08, 1.7}, {-0.42, 1.77}, {-0.6, 1.77}, {-0.66, 1.94}, {-0.76, 1.94},
                {-0.8, 1.77}, {-1.12, 1.77}, {-1.12, 1.6}}
  stroke("back", wobble(body, 0.008, 1), LW, inkK, dK)
  for k, wx in ipairs({-0.98, -0.3}) do
    stroke("back", wobble(circle(wx, 1.58, 0.1, 16), 0.008, 10 + k * 20), LW, inkK, dK)
    stroke("back", circle(wx, 1.58, 0.022, 6), LW * 0.8, inkK, dK)
  end
  stroke("back", wobble(circle(-0.67, 2.03, 0.045, 10), 0.005, 60), LW * 0.9, inkB, dB)        -- the driver
  stroke("back", {{-0.69, 1.985}, {-0.72, 1.8}}, LW * 0.9, inkB, dB)
  stroke("back", {{-0.7, 1.92}, {-0.55, 1.86}, {-0.47, 1.85}}, LW * 0.9, inkB, dB)
  stroke("back", {{-0.72, 1.8}, {-0.45, 1.8}, {-0.3, 1.72}}, LW * 0.9, inkB, dB)
  stroke("back", {{-0.47, 1.78}, {-0.45, 1.9}}, LW, inkK, dK)                                     -- the steering
  -- its length: a dimension line with arrowheads and a scrawled figure
  local dp, dq = {-1.08, 1.4}, {-0.2, 1.4}
  stroke("back", {dp, dq}, LW * 0.8, inkK, dK)
  stroke("back", arrowhead(dq, dp, 0.04), LW * 0.8, inkK, dK)
  stroke("back", arrowhead(dp, dq, 0.04), LW * 0.8, inkK, dK)
  stroke("back", {{-1.12, 1.36}, {-1.12, 1.47}}, LW * 0.7, inkK, dK)
  stroke("back", {{-0.16, 1.36}, {-0.16, 1.47}}, LW * 0.7, inkK, dK)
  stroke("back", scrawl(-0.78, -0.5, 1.3, 0.04, 3), LW * 0.8, inkK, dK)
  -- a red note and arrow to the nose; the title scrawled above
  stroke("back", scrawl(-0.15, 0.12, 2.0, 0.04, 7), LW * 0.8, inkR, dR)
  stroke("back", scrawl(-0.15, 0.05, 1.94, 0.035, 9), LW * 0.8, inkR, dR)
  local np, nq = {-0.05, 1.9}, {-0.1, 1.74}
  stroke("back", {np, {-0.09, 1.82}, nq}, LW * 0.8, inkR, dR)
  stroke("back", arrowhead({-0.09, 1.82}, nq, 0.035), LW * 0.8, inkR, dR)
  stroke("back", scrawl(-1.15, -0.55, 2.22, 0.06, 5), LW * 1.1, inkK, dK)
  stroke("back", {{-1.15, 2.15}, {-0.5, 2.16}}, LW * 0.8, inkR, dR)                               -- underlined
  -- 2. The plan, right half: the body from above, axles, four wheels, the steering rope, dimensions in red
  local plan = {{0.2, 1.62}, {0.98, 1.64}, {1.08, 1.75}, {0.98, 1.86}, {0.2, 1.88}, {0.2, 1.62}}
  stroke("back", wobble(plan, 0.006, 80), LW, inkK, dK)
  for k, ax in ipairs({0.32, 0.9}) do
    stroke("back", {{ax, 1.5}, {ax + 0.01, 2.0}}, LW * 0.8, inkK, dK)
    for _, wy in ipairs({1.5, 2.0}) do
      stroke("back", wobble({{ax - 0.08, wy - 0.025}, {ax + 0.08, wy - 0.025}, {ax + 0.08, wy + 0.025}, {ax - 0.08, wy + 0.025}, {ax - 0.08, wy - 0.025}}, 0.005, 90 + k * 10 + wy * 10), LW, inkK, dK)
    end
  end
  stroke("back", {{0.9, 1.55}, {0.75, 1.68}, {0.6, 1.75}, {0.75, 1.82}, {0.9, 1.95}}, LW * 0.7, inkB, dB) -- the rope
  local hp, hq = {0.24, 1.38}, {0.98, 1.38}
  stroke("back", {hp, hq}, LW * 0.8, inkR, dR)
  stroke("back", arrowhead(hq, hp, 0.04), LW * 0.8, inkR, dR)
  stroke("back", arrowhead(hp, hq, 0.04), LW * 0.8, inkR, dR)
  stroke("back", scrawl(0.48, 0.74, 1.29, 0.04, 11), LW * 0.8, inkR, dR)
  local vp, vq = {1.18, 1.5}, {1.18, 2.0}
  stroke("back", {vp, vq}, LW * 0.8, inkR, dR)
  stroke("back", arrowhead(vq, vp, 0.04), LW * 0.8, inkR, dR)
  stroke("back", arrowhead(vp, vq, 0.04), LW * 0.8, inkR, dR)
  stroke("back", scrawl(1.21, 1.27, 1.75, 0.08, 13), LW * 0.7, inkR, dR)
  -- a list in blue, top right: bullets and words; a red question mark circled
  for k = 0, 2 do
    local y = 2.25 - k * 0.07
    stroke("back", circle(0.42, y, 0.008, 5), LW * 0.8, inkB, dB)
    stroke("back", scrawl(0.47, 0.75 + 0.08 * (k % 2), y, 0.03, 20 + k), LW * 0.75, inkB, dB)
  end
  stroke("back", {{1.0, 2.2}, {1.02, 2.25}, {1.07, 2.26}, {1.1, 2.22}, {1.07, 2.17}, {1.05, 2.13}}, LW, inkR, dR)
  stroke("back", circle(1.05, 2.08, 0.006, 5), LW, inkR, dR)
  stroke("back", wobble(circle(1.05, 2.19, 0.1, 14), 0.01, 130), LW * 0.8, inkR, dR)
  -- a printed photo of a kart, held up by two magnets
  local pa, py = -0.15, 2.17
  add(wquad("back", pa, py, 0.24, 0.17, -3, F, F + 0.002), white)
  add(wquad("back", pa, py + 0.025, 0.21, 0.09, -3, F + 0.002, F + 0.0025), C(0.35, 0.5, 0.65))
  add(wquad("back", pa, py - 0.05, 0.21, 0.045, -3, F + 0.002, F + 0.0025), C(0.15, 0.3, 0.1))
  add(wquad("back", pa + 0.01, py - 0.03, 0.09, 0.035, -3, F + 0.0025, F + 0.003), red)
  for k, mg in ipairs({{pa - 0.1, py + 0.075, red}, {pa + 0.1, py + 0.07, inkB}}) do
    add(cyl(0.016, 0.014, mg[1], mg[2], -IN + F + 0.007, "z", 12), mg[3], 40)
  end
  -- the tray: markers and an eraser
  add(wbox("back", a0 + 0.2, a1 - 0.2, y0 - 0.06, y0 - 0.03, STUD, STUD + 0.07), C(0.55, 0.56, 0.58))
  add(wbox("back", a0 + 0.2, a1 - 0.2, y0 - 0.03, y0 - 0.0, STUD + 0.06, STUD + 0.07), C(0.55, 0.56, 0.58))
  for k, mc in ipairs({inkK, inkR, inkB}) do
    local x = -0.4 + k * 0.17
    add(cyl(0.009, 0.12, x, y0 - 0.02, -IN + STUD + 0.03, "x", 8), white, 40)
    add(cyl(0.0095, 0.03, x + 0.07, y0 - 0.02, -IN + STUD + 0.03, "x", 8), mc, 40)
  end
  add(bmm(0.35, y0 - 0.03, -IN + STUD + 0.01, 0.5, y0 + 0.0, -IN + STUD + 0.055), C(0.12, 0.12, 0.13))
  add(bmm(0.35, y0 + 0.0, -IN + STUD + 0.015, 0.5, y0 + 0.02, -IN + STUD + 0.05), C(0.2, 0.3, 0.5))

  -- the cabinet under it: painted cream long ago, drawers, a worn top
  local d0, d1 = STUD, STUD + 0.35
  add(wbox("back", -1.3, 1.3, 0, 0.08, d0, d1 - 0.04), woodDk)
  add(wbox("back", -1.3, 1.3, 0.08, 0.82, d0, d1), C(0.5, 0.45, 0.3))
  add(wbox("back", -1.33, 1.33, 0.82, 0.86, d0, d1 + 0.02), wood)
  for col = 0, 2 do
    for row = 0, 1 do
      local a = -1.25 + col * 0.84
      local y = 0.13 + row * 0.35
      add(wbox("back", a, a + 0.8, y, y + 0.32, d1, d1 + 0.012), vary(C(0.55, 0.5, 0.34), col * 3 + row, 0.06))
      add(wbox("back", a + 0.33, a + 0.47, y + 0.2, y + 0.24, d1 + 0.012, d1 + 0.03), metalDk)
    end
  end
  -- on top: a red cantilever toolbox, a tin, an oil can, a pile of magazines
  add(wbox("back", 0.55, 1.15, 0.86, 1.06, d0 + 0.05, d0 + 0.32), red)
  add(wbox("back", 0.54, 1.16, 1.06, 1.1, d0 + 0.04, d0 + 0.33), shade(red, 1.25))
  local p = wpt("back", -0.9, 0.86, d0 + 0.2)
  tin(p.x, p.y, p.z, 0.1, 0.16, C(0.5, 0.48, 0.4))
  local q = wpt("back", -0.55, 0.86, d0 + 0.2)
  add(at(cone{radius=0.06, radius_top=0.02, height=0.1, segments=12, anchor="base"}, q.x, q.y, q.z), C(0.55, 0.45, 0.1), 40)
  add(tube(v3(q.x, q.y + 0.08, q.z), v3(q.x + 0.12, q.y + 0.18, q.z + 0.02), 0.005, 5), C(0.55, 0.45, 0.1))
  for k = 0, 4 do
    local m = wpt("back", 0.05, 0.86 + k * 0.012, d0 + 0.17)
    add(rot(bmm(-0.15, 0, -0.11, 0.15, 0.011, 0.11), 7 * k - 12, axis_y()), k % 2 == 0 and C(0.6, 0.55, 0.45) or C(0.2, 0.3, 0.5))
    pieces[#pieces] = {at(pieces[#pieces][1], m.x, m.y, m.z), pieces[#pieces][2], pieces[#pieces][3]}
  end
end

-- Back wall: the corkboard of pinned plans, the shelves, boxes under them -------------------------------------------
do
  local a0, a1, y0, y1 = 1.6, 2.65, 1.25, 2.15
  local F = STUD + 0.015
  add(wbox("back", a0, a1, y0, y1, STUD, F), C(0.45, 0.3, 0.15))
  for _, r in ipairs({{a0 - 0.03, a1 + 0.03, y0 - 0.03, y0}, {a0 - 0.03, a1 + 0.03, y1, y1 + 0.03}, {a0 - 0.03, a0, y0, y1}, {a1, a1 + 0.03, y0, y1}}) do
    add(wbox("back", r[1], r[2], r[3], r[4], STUD, F + 0.01), woodDk)
  end
  local sheets = {{1.83, 1.9, 0.36, 0.26, -4, paper}, {2.33, 1.95, 0.3, 0.3, 5, C(0.3, 0.45, 0.7)}, {1.95, 1.5, 0.34, 0.24, 3, paper},
                  {2.4, 1.48, 0.28, 0.22, -6, C(0.85, 0.75, 0.3)}, {2.12, 1.72, 0.18, 0.13, 10, C(0.85, 0.45, 0.5)}}
  for k, s in ipairs(sheets) do
    local d = F + 0.001 * k
    add(wquad("back", s[1], s[2], s[3], s[4], s[5], d, d + 0.001), s[6])
    add(cyl(0.008, 0.012, s[1], s[2] + s[4] / 2 - 0.02, -IN + d + 0.006, "z", 8), k % 2 == 0 and red or C(0.1, 0.3, 0.7), 40)
    -- a sketch on each: a few lines in pencil or biro
    local ink = (s[6] == paper) and C(0.08, 0.08, 0.15) or C(0.05, 0.05, 0.08)
    stroke("back", scrawl(s[1] - s[3] * 0.35, s[1] + s[3] * 0.3, s[2] + s[4] * 0.2, 0.02, 40 + k), 0.006, ink, d + 0.001)
    stroke("back", wobble(circle(s[1] - s[3] * 0.18, s[2] - s[4] * 0.15, s[4] * 0.16, 10), 0.004, 50 + k), 0.006, ink, d + 0.001)
    stroke("back", {{s[1] - s[3] * 0.05, s[2] - s[4] * 0.2}, {s[1] + s[3] * 0.35, s[2] - s[4] * 0.05}}, 0.006, ink, d + 0.001)
  end

  -- the shelves: tins, jam jars, a biscuit tin, boxes
  local s0, s1 = 2.9, 4.6
  local d0, d1 = STUD, STUD + 0.34
  for _, a in ipairs({s0 + 0.1, s1 - 0.1}) do add(wbox("back", a - 0.02, a + 0.02, 0.6, 2.5, d0, d0 + 0.02), metalDk) end
  local ys = {0.95, 1.55, 2.15}
  for _, y in ipairs(ys) do
    add(wbox("back", s0, s1, y - 0.025, y, d0, d1), wood)
    for _, a in ipairs({s0 + 0.1, s1 - 0.1}) do add(wbox("back", a - 0.012, a + 0.012, y - 0.06, y - 0.025, d0, d1 - 0.04), metalDk) end
  end
  local function onshelf(a, y, e) return wpt("back", a, y, d0 + e) end
  local cols = {C(0.6, 0.55, 0.42), white, C(0.1, 0.3, 0.12), blue}
  for k = 0, 3 do
    local p = onshelf(s0 + 0.22 + k * 0.42, ys[1], 0.17)
    tin(p.x, p.y, p.z, 0.09 + 0.02 * (k % 2), 0.13 + 0.05 * ((k + 1) % 2), cols[k + 1])
  end
  local stuffs = {metal, C(0.45, 0.33, 0.12), steel, metalDk, C(0.45, 0.33, 0.12)}
  local lids = {red, C(0.6, 0.55, 0.1), white, C(0.1, 0.2, 0.5), red}
  for k = 0, 4 do
    local p = onshelf(s0 + 0.18 + k * 0.13, ys[2], 0.12)
    jar(p.x, p.y, p.z, 0.045, 0.12, stuffs[k + 1], lids[k + 1])
  end
  local bt = onshelf(s0 + 1.1, ys[2], 0.17)
  add(cyl(0.13, 0.1, bt.x, bt.y + 0.05, bt.z, "y", 20), C(0.08, 0.15, 0.4), 40)
  add(cyl(0.132, 0.03, bt.x, bt.y + 0.095, bt.z, "y", 20), C(0.6, 0.12, 0.08), 40)
  add(wbox("back", s0 + 1.3, s1 - 0.05, ys[2], ys[2] + 0.2, d0 + 0.02, d1 - 0.02), C(0.6, 0.55, 0.45))
  add(wbox("back", s0 + 0.05, s0 + 0.7, ys[3], ys[3] + 0.3, d0 + 0.01, d1), vary(card, 3, 0.1))
  add(wbox("back", s0 + 0.75, s0 + 1.45, ys[3], ys[3] + 0.24, d0 + 0.01, d1 - 0.02), vary(card, 4, 0.1))
  add(wbox("back", s0 + 0.8, s0 + 1.3, ys[3] + 0.24, ys[3] + 0.38, d0 + 0.04, d1 - 0.06), vary(card, 5, 0.1))
  -- under: boxes stacked crooked
  local z0 = -IN + STUD
  cbox(3.25, 0, z0 + 0.3, 0.62, 0.45, 0.5, 4, 6)
  cbox(3.2, 0.45, z0 + 0.28, 0.5, 0.3, 0.4, -9, 7)
  cbox(3.3, 0.75, z0 + 0.3, 0.38, 0.22, 0.3, 14, 8)
  cbox(4.1, 0, z0 + 0.32, 0.66, 0.5, 0.55, -6, 9)
end

-- Back wall, left: the pegboard and its tool outlines; the parts drawers, stepladder, deckchair, tin bath ---------
do
  local PO = -3.1                       -- the board's middle along the wall
  local a0, a1, y0, y1 = PO - 1.5, PO + 1.5, 1.15, 2.4
  local F = STUD + 0.012
  add(wbox("back", a0, a1, y0, y1, STUD, F), pegC)
  add(wbox("back", a0 - 0.04, a1 + 0.04, y0 - 0.04, y0, STUD, F + 0.01), woodDk)
  add(wbox("back", a0 - 0.04, a1 + 0.04, y1, y1 + 0.04, STUD, F + 0.01), woodDk)
  for i = 0, 18 do
    for j = 0, 7 do
      local a, y = a0 + 0.1 + i * 0.155, y0 + 0.08 + j * 0.155
      add(wbox("back", a - 0.008, a + 0.008, y - 0.008, y + 0.008, F, F + 0.001), shade(pegC, 0.3))
    end
  end
  local function tool(rects, present)
    for _, r in ipairs(rects) do add(wbox("back", PO + r[1] - 0.012, PO + r[3] + 0.012, r[2] - 0.012, r[4] + 0.012, F, F + 0.002), shadowC) end
    if present then
      for _, r in ipairs(rects) do add(wbox("back", PO + r[1], PO + r[3], r[2], r[4], F + 0.006, F + 0.022), r[5]) end
    end
  end
  tool({{-1.27, 1.45, -1.23, 1.86, wood}, {-1.37, 1.86, -1.13, 1.93, metalDk}}, false)      -- hammer: on the bench
  for _, sd in ipairs({{-0.95, 0.24, red, true}, {-0.8, 0.18, yellow, false}, {-0.65, 0.13, red, false}}) do
    tool({{sd[1] - 0.006, 2.05 - sd[2], sd[1] + 0.006, 2.05, steel}, {sd[1] - 0.022, 2.05, sd[1] + 0.022, 2.18, sd[3]}}, sd[4])
  end
  for k = 0, 3 do
    local a, len = -0.42 + k * 0.15, 0.24 + 0.05 * k
    tool({{a - 0.012, 2.12 - len, a + 0.012, 2.12, steel}, {a - 0.03, 2.12, a + 0.03, 2.18, steel},
          {a - 0.025, 2.12 - len - 0.05, a + 0.025, 2.12 - len, steel}}, k == 0 or k == 3)
  end
  tool({{0.25, 1.62, 0.28, 1.84, red}, {0.31, 1.62, 0.34, 1.84, red}, {0.27, 1.84, 0.32, 1.96, metalDk}}, false)
  for k = 0, 2 do
    local a = 0.55 + k * 0.15
    tool({{a - 0.012, 1.78, a + 0.012, 1.97, steel}, {a - 0.022, 1.97, a + 0.022, 2.13, wood}}, k ~= 1)
  end
  tool({{1.05, 1.5, 1.11, 1.85, wood}, {1.11, 1.79, 1.4, 1.83, steel}}, true)
  tool({{1.05, 2.0, 1.4, 2.06, steel}, {1.15, 2.06, 1.3, 2.3, C(0.6, 0.4, 0.05)}}, false)

  -- the parts drawers in the corner: a grey steel case of little clear-fronted drawers
  local c0, c1 = -5.32, -4.72
  add(wbox("back", c0, c1, 0, 1.15, STUD, STUD + 0.32), C(0.34, 0.36, 0.38))
  for col = 0, 3 do
    for row = 0, 8 do
      local a = c0 + 0.03 + col * 0.14
      local y = 0.06 + row * 0.12
      add(wbox("back", a, a + 0.12, y, y + 0.1, STUD + 0.32, STUD + 0.335), vary(C(0.55, 0.6, 0.62), col * 9 + row, 0.08))
      add(wbox("back", a + 0.02, a + 0.1, y + 0.01, y + 0.06, STUD + 0.335, STUD + 0.337), vary(C(0.4, 0.35, 0.25), col * 13 + row, 0.3))
      add(wbox("back", a + 0.045, a + 0.075, y + 0.07, y + 0.085, STUD + 0.335, STUD + 0.35), metalDk)
    end
  end
  -- one drawer pulled out
  add(wbox("back", c0 + 0.31, c0 + 0.43, 0.54, 0.64, STUD + 0.335, STUD + 0.47), C(0.55, 0.6, 0.62))

  -- the stepladder and the deckchair leaning
  group(function(put)
    for _, x in ipairs({-0.24, 0.24}) do
      put(bmm(x - 0.025, 0, -0.035, x + 0.025, 1.75, 0.035), woodPale)
      put(bmm(x - 0.022, 0, -0.1, x + 0.022, 1.62, -0.05), shade(woodPale, 0.85))
    end
    for k = 1, 5 do put(bmm(-0.22, k * 0.3 - 0.02, -0.06, 0.22, k * 0.3 + 0.01, 0.06), shade(woodPale, 0.9)) end
    put(bmm(-0.26, 1.72, -0.12, 0.26, 1.76, 0.06), woodPale)
    for k = 0, 4 do put(bmm(-0.2 + 0.09 * k, 0.3 * (k % 3 + 1) + 0.01, -0.03, -0.15 + 0.09 * k, 0.3 * (k % 3 + 1) + 0.012, 0.03), white) end
  end, function(m) return at(rot(m, -9, axis_x()), -1.95, 0, -IN + STUD + 0.38) end)
  local stripes = {C(0.6, 0.06, 0.05), white, C(0.05, 0.3, 0.12), white, C(0.6, 0.06, 0.05), white}
  group(function(put)
    for _, x in ipairs({-0.28, 0.28}) do put(bmm(x - 0.02, 0, -0.015, x + 0.02, 1.25, 0.015), wood) end
    for _, y in ipairs({0.12, 1.18}) do put(bmm(-0.28, y - 0.015, -0.03, 0.28, y + 0.015, 0.0), wood) end
    for k = 0, 5 do put(bmm(-0.26 + k * 0.0867, 0.16, 0.0, -0.26 + (k + 1) * 0.0867, 1.12, 0.008), stripes[k + 1]) end
  end, function(m) return at(rot(rot(m, 180, axis_y()), -12, axis_x()), -3.5, 0, -IN + STUD + 0.3) end)
  -- the tin bath hung on a nail above the pegboard
  local e, e2 = {}, {}
  for k = 0, 23 do
    local t = k * math.pi / 12
    e[#e + 1] = {-3.5 + 0.45 * math.cos(t), 2.8 + 0.24 * math.sin(t)}
    e2[#e2 + 1] = {-3.5 + 0.49 * math.cos(t), 2.8 + 0.28 * math.sin(t)}
  end
  add(wprism("back", e, STUD, STUD + 0.24), C(0.42, 0.44, 0.44))
  add(wprism("back", e2, STUD, STUD + 0.03), C(0.32, 0.33, 0.33))
  for _, a in ipairs({-4.0, -3.0}) do add(wbox("back", a - 0.04, a + 0.04, 2.77, 2.83, STUD + 0.1, STUD + 0.18), metalDk) end
end

STUFF[#STUFF + 1] = {stuffFrom, #pieces}

-- Left wall: the window over the bench ------------------------------------------------------------------------------
do
  local o = OPEN.left
  local tr = o[4] - 0.36                -- the transom
  add(wbox("left", o[1], o[2], o[3], tr, 0, 0.01), garden)
  add(wbox("left", o[1], o[2], o[3] + 0.3, tr, 0, 0.008), shade(garden, 1.5))
  add(wbox("left", o[1], o[2], tr, o[4], 0, 0.01), sky)
  for i, sm in ipairs({{2.35, 1.35, 2.8, 1.6}, {3.2, 1.33, 3.7, 1.55}, {3.3, 2.0, 3.7, 2.2}, {2.5, 1.7, 2.9, 1.85}}) do
    add(wbox("left", sm[1], sm[3], sm[2], sm[4], 0.01, 0.012), vary(glass, i, 0.1))
  end
  local fc = C(0.55, 0.54, 0.48)
  local function fr(a0, a1, y0, y1, d1) add(wbox("left", a0, a1, y0, y1, 0, d1 or 0.1), fc) end
  local mid = (o[1] + o[2]) / 2
  fr(o[1], o[2], o[3], o[3] + 0.07); fr(o[1], o[2], o[4] - 0.07, o[4])
  fr(o[1], o[1] + 0.07, o[3], o[4]); fr(o[2] - 0.07, o[2], o[3], o[4])
  fr(mid - 0.035, mid + 0.035, o[3], o[4], 0.08); fr(o[1], o[2], tr - 0.03, tr + 0.03, 0.08)
  fr(o[1] + 0.05, o[2] - 0.05, o[3] + 0.3 - 0.012, o[3] + 0.3 + 0.012, 0.04)
  add(wbox("left", o[1] - 0.12, o[2] + 0.12, o[3] - 0.06, o[3], 0, 0.2), shade(fc, 0.85))
  local p = wpt("left", o[1] + 0.3, o[3], 0.12)
  add(at(cone{radius=0.06, radius_top=0.08, height=0.11, segments=14, anchor="base"}, p.x, p.y, p.z), terra, 40)
  for k = 0, 3 do add(tube(v3(p.x, p.y + 0.1, p.z), v3(p.x + 0.03 * math.cos(k * 1.7), p.y + 0.22 + 0.03 * k, p.z + 0.05 * math.sin(k * 1.7)), 0.004, 4), C(0.25, 0.18, 0.06)) end
  local q = wpt("left", o[2] - 0.3, o[3], 0.11)
  add(cyl(0.04, 0.1, q.x, q.y + 0.05, q.z, "y", 12), C(0.35, 0.37, 0.32), 40)
  add(cyl(0.042, 0.02, q.x, q.y + 0.11, q.z, "y", 12), red, 40)
  -- a shelf over the window, crammed: jars, tins, a box, a coffee tin of brushes
  wshelf("left", 1.95, 4.65, 2.62, 0.26)
  for k = 0, 4 do
    local pp = wpt("left", 2.1 + k * 0.12, 2.62, STUD + 0.12)
    jar(pp.x, pp.y, pp.z, 0.045, 0.11 + 0.02 * (k % 2), k % 2 == 0 and metal or C(0.45, 0.33, 0.12), k % 3 == 0 and red or C(0.6, 0.55, 0.1))
  end
  for k = 0, 2 do
    local pp = wpt("left", 2.85 + k * 0.24, 2.62, STUD + 0.13)
    tin(pp.x, pp.y, pp.z, 0.085, 0.13 + 0.03 * (k % 2), ({C(0.6, 0.55, 0.42), blue, C(0.1, 0.3, 0.12)})[k + 1])
  end
  add(wbox("left", 3.65, 4.2, 2.62, 2.84, STUD + 0.01, STUD + 0.25), vary(card, 60, 0.1))
  local bp = wpt("left", 4.4, 2.62, STUD + 0.12)
  add(cyl(0.06, 0.14, bp.x, bp.y + 0.07, bp.z, "y", 14), C(0.25, 0.1, 0.06), 40)
  for k = 0, 2 do
    local p0 = v3(bp.x + 0.02 * (k - 1), bp.y + 0.12, bp.z + 0.02 * (k - 1))
    add(tube(p0, v3(p0.x + 0.02 * (k - 1), bp.y + 0.32, p0.z + 0.03 * (k - 1)), 0.008, 6), wood)
  end
end

stuffFrom = #pieces + 1

-- Left wall: the workbench, piled up ------------------------------------------------------------------------------------
do
  local xb0, xb1 = -IN + STUD, -IN + 0.82      -- the bench's back and front
  local zA, zB = -1.9, -4.7                    -- its ends: near the middle, near the back wall
  local top = 0.9
  add(bmm(xb0, top - 0.06, zA, xb1, top, zB), wood)
  for i, st in ipairs({{-2.6, -0.2, 0.2}, {-3.9, 0.25, 0.16}, {-4.3, -0.3, 0.12}}) do
    add(cyl(st[3], 0.002, xb0 + 0.4 + st[2], top + 0.001, st[1], "y", 14), shade(wood, 0.55 + 0.1 * i), 10)
  end
  add(bmm(xb1 - 0.04, top - 0.2, zA, xb1, top - 0.06, zB), woodDk)
  for _, lx in ipairs({xb0 + 0.05, xb1 - 0.09}) do
    for _, lz in ipairs({zA - 0.06, (zA + zB) / 2, zB + 0.06}) do add(bmm(lx - 0.04, 0, lz - 0.04, lx + 0.04, top - 0.06, lz + 0.04), woodDk) end
  end
  add(bmm(xb0 + 0.01, 0.2, zA - 0.1, xb1 - 0.06, 0.24, zB + 0.1), wood)
  -- under it: a box, a crate of offcuts, tins
  cbox(xb0 + 0.3, 0.24, -2.3, 0.5, 0.38, 0.55, 5, 1)
  add(bmm(xb0 + 0.05, 0.24, -2.75, xb0 + 0.6, 0.5, -3.45), woodPale)
  for k = 0, 4 do add(bmm(xb0 + 0.1 + k * 0.09, 0.5, -3.4 + 0.05 * (k % 2), xb0 + 0.16 + k * 0.09, 0.62 + 0.05 * (k % 3), -2.8), vary(woodPale, k + 9, 0.2)) end
  tin(xb0 + 0.3, 0.24, -3.8, 0.1, 0.17, C(0.45, 0.4, 0.3))
  tin(xb0 + 0.32, 0.24, -4.15, 0.09, 0.14, blue)
  tin(xb0 + 0.3, 0.24, -4.45, 0.1, 0.18, C(0.5, 0.48, 0.42))

  -- the 3D printer at the near end: a black frame, the bed with a half-printed part, the gantry, a spool on top
  local px, pz = xb0 + 0.27, -2.2
  local blk = C(0.05, 0.05, 0.06)
  add(bmm(px - 0.21, top, pz - 0.2, px + 0.21, top + 0.06, pz + 0.2), blk)
  for _, dz in ipairs({-0.19, 0.19}) do add(bmm(px - 0.2, top + 0.06, pz + dz - 0.015, px - 0.17, top + 0.5, pz + dz + 0.015), blk) end
  add(bmm(px - 0.2, top + 0.5, pz - 0.2, px - 0.17, top + 0.53, pz + 0.2), blk)
  add(bmm(px - 0.13, top + 0.1, pz - 0.15, px + 0.17, top + 0.11, pz + 0.15), C(0.2, 0.2, 0.22))
  add(bmm(px - 0.03, top + 0.11, pz - 0.04, px + 0.05, top + 0.15, pz + 0.04), orange)
  add(bmm(px - 0.17, top + 0.28, pz - 0.19, px - 0.13, top + 0.31, pz + 0.19), steel)
  add(bmm(px - 0.13, top + 0.25, pz - 0.04, px - 0.02, top + 0.33, pz + 0.04), blk)
  add(cyl(0.008, 0.03, px - 0.06, top + 0.235, pz, "y", 6), C(0.6, 0.45, 0.1))
  add(cyl(0.1, 0.06, px - 0.11, top + 0.64, pz, "z", 20), orange, 40)
  add(cyl(0.035, 0.065, px - 0.11, top + 0.64, pz, "z", 10), blk, 40)
  add(bmm(px - 0.13, top + 0.53, pz - 0.01, px - 0.09, top + 0.6, pz + 0.01), blk)
  add(bmm(px + 0.12, top + 0.02, pz + 0.2, px + 0.2, top + 0.05, pz + 0.205), C(0.3, 0.6, 0.85))   -- its little screen

  -- the soldering station: a box with a dial and a glowing display, the iron in its coil, a board
  local sx, sz = xb0 + 0.18, -2.72
  add(bmm(sx - 0.08, top, sz - 0.09, sx + 0.08, top + 0.1, sz + 0.09), C(0.12, 0.2, 0.32))
  add(bmm(sx + 0.08, top + 0.055, sz - 0.07, sx + 0.082, top + 0.085, sz - 0.01), C(1.0, 0.35, 0.15))
  add(cyl(0.018, 0.02, sx + 0.09, top + 0.04, sz + 0.04, "x", 10), metalDk)
  local hz = sz - 0.22
  add(bmm(sx - 0.05, top, hz - 0.05, sx + 0.05, top + 0.015, hz + 0.05), C(0.6, 0.45, 0.1))
  add(tube(v3(sx, top + 0.02, hz), v3(sx + 0.08, top + 0.14, hz + 0.02), 0.02, 8), steel)
  add(tube(v3(sx + 0.03, top + 0.06, hz + 0.01), v3(sx + 0.16, top + 0.17, hz + 0.03), 0.009, 6), C(0.6, 0.2, 0.05))
  add(rot(bmm(-0.06, 0, -0.045, 0.06, 0.004, 0.045), 20, axis_y()), C(0.05, 0.3, 0.12))
  pieces[#pieces] = {at(pieces[#pieces][1], xb1 - 0.3, top, -2.85), pieces[#pieces][2], pieces[#pieces][3]}

  -- an open toolbox, its lid up, tools spilling out of it across the bench
  local tx, tz = xb0 + 0.22, -3.35
  add(bmm(tx - 0.13, top, tz - 0.25, tx + 0.13, top + 0.18, tz + 0.25), red)
  add(bmm(tx - 0.135, top + 0.18, tz - 0.255, tx - 0.11, top + 0.42, tz + 0.255), shade(red, 1.2))
  add(bmm(tx - 0.11, top + 0.15, tz - 0.23, tx + 0.11, top + 0.16, tz + 0.23), metalDk)
  for k = 0, 3 do add(tube(v3(tx - 0.05 + 0.03 * k, top + 0.12, tz - 0.15 + 0.1 * k), v3(tx - 0.03 + 0.05 * k, top + 0.3, tz - 0.12 + 0.12 * k), 0.008, 6), k % 2 == 0 and steel or yellow) end
  for k = 0, 2 do
    add(rot(bmm(-0.11, 0, -0.012, 0.11, 0.008, 0.012), 25 + 40 * k, axis_y()), steel)
    pieces[#pieces] = {at(pieces[#pieces][1], tx + 0.28 + 0.04 * k, top, tz - 0.15 + 0.15 * k), pieces[#pieces][2], pieces[#pieces][3]}
  end
  add(cyl(0.015, 0.3, xb1 - 0.18, top + 0.015, tz + 0.05, "z", 8), wood, 50)                     -- the hammer
  add(bmm(xb1 - 0.26, top, tz - 0.14, xb1 - 0.1, top + 0.045, tz - 0.1), metalDk)
  add(cyl(0.018, 0.1, xb1 - 0.12, top + 0.018, -2.3, "x", 8), yellow, 50)                        -- a screwdriver
  add(cyl(0.004, 0.14, xb1 - 0.24, top + 0.018, -2.3, "x", 6), steel)

  -- the drill press: a base, its column, the head and chuck, three handles
  local dx, dz = xb0 + 0.16, -3.95
  add(bmm(dx - 0.1, top, dz - 0.13, dx + 0.22, top + 0.03, dz + 0.13), C(0.1, 0.25, 0.15))
  add(cyl(0.025, 0.62, dx, top + 0.34, dz, "y", 12), steel)
  add(bmm(dx - 0.06, top + 0.48, dz - 0.07, dx + 0.2, top + 0.62, dz + 0.07), C(0.1, 0.25, 0.15))
  add(cyl(0.06, 0.12, dx + 0.02, top + 0.68, dz, "y", 14), C(0.1, 0.25, 0.15))
  add(cyl(0.015, 0.08, dx + 0.14, top + 0.44, dz, "y", 8), steel)
  add(cyl(0.006, 0.06, dx + 0.14, top + 0.37, dz, "y", 6), steel)
  add(bmm(dx + 0.06, top + 0.2, dz - 0.09, dx + 0.22, top + 0.22, dz + 0.09), metal)
  for k = 0, 2 do
    local t = k * 2.1
    add(tube(v3(dx + 0.07, top + 0.55, dz + 0.07), v3(dx + 0.07 + 0.12 * math.cos(t), top + 0.55 + 0.12 * math.sin(t), dz + 0.12), 0.005, 5), steel)
  end

  -- the vice at the far end, a plank of the kart's in it
  local vz = -4.38
  add(bmm(xb1 - 0.14, top, vz - 0.11, xb1 + 0.01, top + 0.13, vz + 0.11), vblue)
  add(bmm(xb1 + 0.04, top - 0.03, vz - 0.11, xb1 + 0.1, top + 0.13, vz + 0.11), vblue)
  add(bmm(xb1 + 0.01, top + 0.06, vz - 0.105, xb1 + 0.02, top + 0.125, vz + 0.105), steel)
  add(bmm(xb1 + 0.03, top + 0.06, vz - 0.105, xb1 + 0.04, top + 0.125, vz + 0.105), steel)
  for _, dz2 in ipairs({-0.07, 0.07}) do add(cyl(0.012, 0.16, xb1 + 0.02, top, vz + dz2, "x", 8), steel) end
  add(cyl(0.015, 0.16, xb1 + 0.16, top + 0.03, vz, "x", 8), steel)
  add(cyl(0.008, 0.3, xb1 + 0.22, top + 0.03, vz, "z", 6), steel)
  for _, dz2 in ipairs({-0.15, 0.15}) do add(at(sphere{radius=0.014, segments=8, rings=4}, xb1 + 0.22, top + 0.03, vz + dz2), steel, 60) end
  add(bmm(xb1 + 0.015, top + 0.06, vz - 0.32, xb1 + 0.035, top + 0.3, vz + 0.3), woodPale)

  -- two G-clamps holding an axle beam to the bench's front
  add(bmm(xb1 - 0.38, top, -2.55, xb1 - 0.05, top + 0.06, -3.25), woodPale)
  for _, cz in ipairs({-2.7, -3.1}) do
    local cc = C(0.65, 0.2, 0.03)
    add(bmm(xb1 + 0.03, top - 0.22, cz - 0.015, xb1 + 0.06, top + 0.1, cz + 0.015), cc)
    add(bmm(xb1 - 0.15, top + 0.07, cz - 0.015, xb1 + 0.06, top + 0.1, cz + 0.015), cc)
    add(bmm(xb1 - 0.15, top - 0.25, cz - 0.015, xb1 + 0.06, top - 0.22, cz + 0.015), cc)
    add(cyl(0.008, 0.06, xb1 - 0.12, top + 0.04, cz, "y", 6), steel)
    add(cyl(0.005, 0.1, xb1 - 0.12, top - 0.3, cz, "z", 6), steel)
  end

  -- the radio and the mug; plans in a pile, offcuts, a tape measure, shavings
  local rx, rz = xb0 + 0.1, -4.5
  add(bmm(rx - 0.07, top, rz - 0.16, rx + 0.07, top + 0.19, rz + 0.16), cream)
  add(bmm(rx + 0.07, top + 0.03, rz - 0.13, rx + 0.075, top + 0.15, rz + 0.03), C(0.18, 0.1, 0.05))
  add(bmm(rx + 0.07, top + 0.09, rz + 0.06, rx + 0.075, top + 0.15, rz + 0.13), C(0.75, 0.65, 0.4))
  add(bmm(rx - 0.01, top + 0.19, rz - 0.1, rx + 0.01, top + 0.22, rz + 0.1), C(0.2, 0.12, 0.06))
  add(tube(v3(rx - 0.03, top + 0.19, rz + 0.14), v3(rx - 0.03, top + 0.52, rz + 0.36), 0.003, 4), steel)
  local mx, mz = xb1 - 0.12, -2.05
  add(cyl(0.045, 0.1, mx, top + 0.05, mz, "y", 14), C(0.6, 0.15, 0.08), 40)
  add(cyl(0.04, 0.003, mx, top + 0.09, mz, "y", 14), C(0.2, 0.1, 0.04), 40)
  add(at(torus{major_radius=0.03, minor_radius=0.008, major_segments=10, minor_segments=5, axis="x"}, mx, top + 0.05, mz - 0.05), C(0.6, 0.15, 0.08), 50)
  for k = 0, 5 do
    add(rot(bmm(-0.15, 0, -0.105, 0.15, 0.004, 0.105), 9 * k - 20, axis_y()), k % 3 == 0 and C(0.3, 0.45, 0.7) or paper)
    pieces[#pieces] = {at(pieces[#pieces][1], xb1 - 0.32, top + k * 0.004, -3.7), pieces[#pieces][2], pieces[#pieces][3]}
  end
  for k = 0, 3 do
    add(rot(bmm(-0.2 + 0.03 * k, 0, -0.03, 0.2, 0.04, 0.03), 15 * k - 20, axis_y()), vary(woodPale, k + 70, 0.2))
    pieces[#pieces] = {at(pieces[#pieces][1], xb1 - 0.25, top + k * 0.04, -4.05), pieces[#pieces][2], pieces[#pieces][3]}
  end
  add(cyl(0.045, 0.035, xb1 - 0.16, top + 0.0175, -3.55, "y", 14), yellow, 40)
  for k = 0, 6 do add(at(torus{major_radius=0.02, minor_radius=0.005, major_segments=8, minor_segments=4, axis=(k % 2 == 0) and "x" or "z"}, xb1 - 0.4 + 0.05 * k, top + 0.01, -4.25 + 0.03 * (k % 3)), woodPale, 50) end

  -- the bare bulb over it, on its flex from the rafters
  local lx, lz, ly = -4.95, -3.3, 2.65
  local rb = roofY(4.95) - RAFTER
  add(cyl(0.005, rb - ly, lx, (ly + rb) / 2, lz, "y", 4), rubber)
  add(cyl(0.02, 0.05, lx, ly - 0.025, lz, "y", 10), C(0.55, 0.42, 0.15))
  add(at(sphere{radius=0.045, segments=12, rings=6}, lx, ly - 0.09, lz), glow, 60)
end

-- Left wall, middle and front: goggles and ear defenders, a saw, a poster, a calendar; the bin, a Workmate, tools --
do
  -- a hook with ear defenders and safety goggles hanging on it
  local ha = 1.0
  add(wbox("left", ha - 0.015, ha + 0.015, 1.85, 1.88, STUD, STUD + 0.12), metalDk)
  local hp = wpt("left", ha, 1.78, STUD + 0.08)
  add(at(torus{major_radius=0.085, minor_radius=0.008, major_segments=16, minor_segments=4, axis="x"}, hp.x, hp.y, hp.z), C(0.1, 0.1, 0.1), 50)
  for _, s in ipairs({-1, 1}) do add(cyl(0.045, 0.045, hp.x, hp.y - 0.08, hp.z + s * 0.085, "z", 14), C(0.75, 0.55, 0.05), 40) end
  local gp = wpt("left", ha, 1.62, STUD + 0.04)
  add(at(torus{major_radius=0.075, minor_radius=0.005, major_segments=14, minor_segments=4, axis="x"}, gp.x, gp.y, gp.z), C(0.1, 0.1, 0.1), 50)
  add(bmm(gp.x - 0.015, gp.y - 0.08, gp.z - 0.08, gp.x + 0.025, gp.y - 0.03, gp.z + 0.08), C(0.55, 0.62, 0.6))
  -- a hand saw on a nail
  add(wprism("left", {{1.45, 1.1}, {1.65, 1.1}, {1.72, 1.57}, {1.38, 1.57}}, STUD, STUD + 0.003), steel)
  add(wbox("left", 1.35, 1.75, 1.57, 1.73, STUD, STUD + 0.025), wood)
  -- a poster for a soapbox derby, and a calendar
  add(wbox("left", -1.25, -0.45, 1.25, 2.3, STUD, STUD + 0.003), C(0.85, 0.78, 0.55))
  add(wbox("left", -1.2, -0.5, 1.95, 2.22, STUD + 0.003, STUD + 0.005), red)
  add(wbox("left", -1.2, -0.5, 1.4, 1.9, STUD + 0.003, STUD + 0.005), C(0.25, 0.45, 0.65))
  add(wquad("left", -0.85, 1.55, 0.4, 0.14, -8, STUD + 0.005, STUD + 0.007), yellow)
  for k = 0, 1 do add(cyl(0.05, 0.004, wpt("left", -1.0 + k * 0.28, 1.47, 0).x + STUD + 0.008, 1.47, -(-1.0 + k * 0.28), "x", 14), rubber, 40) end
  for k = 0, 2 do add(wbox("left", -1.15, -0.55 - 0.1 * k, 2.03 + k * 0.05, 2.06 + k * 0.05, STUD + 0.005, STUD + 0.007), paper) end
  add(wbox("left", 0.1, 0.55, 1.5, 2.2, STUD, STUD + 0.004), paper)
  add(wbox("left", 0.14, 0.51, 1.88, 2.16, STUD + 0.004, STUD + 0.006), C(0.3, 0.45, 0.25))
  for r = 0, 3 do for c = 0, 4 do add(wbox("left", 0.15 + c * 0.072, 0.2 + c * 0.072, 1.55 + r * 0.075, 1.6 + r * 0.075, STUD + 0.004, STUD + 0.005), (r == 1 and c == 2) and red or C(0.6, 0.6, 0.55)) end end
  -- a coil of extension cable on a nail
  local cp = wpt("left", -1.6, 2.2, STUD + 0.03)
  add(at(torus{major_radius=0.16, minor_radius=0.022, major_segments=20, minor_segments=6, axis="x"}, cp.x, cp.y, cp.z), orange, 50)
  add(at(torus{major_radius=0.13, minor_radius=0.022, major_segments=20, minor_segments=6, axis="x"}, cp.x + 0.03, cp.y + 0.02, cp.z), orange, 50)

  -- the dustbin, overflowing: crumpled paper, a box sticking out, a bottle; its lid on the floor
  local bx0, bz0 = -5.0, 1.75
  add(cyl(0.27, 0.72, bx0, 0.36, bz0, "y", 24), C(0.38, 0.39, 0.38), 40)
  for _, y in ipairs({0.18, 0.42, 0.62}) do add(at(torus{major_radius=0.27, minor_radius=0.012, major_segments=24, minor_segments=4, axis="y"}, bx0, y, bz0), C(0.3, 0.31, 0.3), 50) end
  for k = 0, 7 do
    local t = k * 0.8
    local r = 0.06 + 0.03 * hash(k + 200)
    add(at(sphere{radius=r, segments=8, rings=4}, bx0 + 0.15 * math.cos(t) * (k % 3) / 2, 0.74 + 0.05 * (k % 3), bz0 + 0.15 * math.sin(t) * (k % 3) / 2), vary(paper, k + 210, 0.2), 20)
  end
  add(rot(bmm(-0.12, 0, -0.08, 0.12, 0.25, 0.08), 25, axis_z()), vary(card, 220, 0.1))
  pieces[#pieces] = {at(pieces[#pieces][1], bx0 + 0.05, 0.68, bz0 - 0.05), pieces[#pieces][2], pieces[#pieces][3]}
  add(tube(v3(bx0 - 0.1, 0.7, bz0 + 0.1), v3(bx0 - 0.15, 0.95, bz0 + 0.16), 0.03, 10), C(0.1, 0.3, 0.15))
  add(at(cone{radius=0.29, radius_top=0.05, height=0.06, segments=24, anchor="base"}, -4.55, 0, 2.35), C(0.42, 0.43, 0.42), 40)

  -- the Workmate with a plank on it, a shelf of tins over it
  local wx, wz = -4.98, 2.75
  local rail = function(x0, x1) add(bmm(x0, 0.72, wz - 0.3, x1, 0.78, wz + 0.3), metal) end
  rail(wx - 0.25, wx - 0.2); rail(wx + 0.2, wx + 0.25)
  add(bmm(wx - 0.24, 0.78, wz - 0.32, wx - 0.02, 0.83, wz + 0.32), woodPale)
  add(bmm(wx + 0.02, 0.78, wz - 0.32, wx + 0.24, 0.83, wz + 0.32), woodPale)
  for _, sz in ipairs({-0.26, 0.26}) do
    add(tube(v3(wx - 0.2, 0.72, wz + sz), v3(wx + 0.28, 0.02, wz + sz), 0.015, 6), C(0.65, 0.35, 0.03))
    add(tube(v3(wx + 0.2, 0.72, wz + sz), v3(wx - 0.28, 0.02, wz + sz), 0.015, 6), C(0.65, 0.35, 0.03))
  end
  add(bmm(wx - 0.3, 0.25, wz - 0.28, wx + 0.3, 0.27, wz + 0.28), C(0.65, 0.35, 0.03))
  add(bmm(wx - 0.1, 0.83, wz - 0.65, wx + 0.12, 0.85, wz + 0.55), woodPale)
  wshelf("left", -3.3, -2.15, 1.75, 0.27)
  local cols = {C(0.45, 0.42, 0.33), red, white}
  for k = 0, 2 do
    local p = wpt("left", -3.15 + k * 0.38, 1.75, STUD + 0.13)
    tin(p.x, p.y, p.z, 0.075 + 0.015 * (k % 2), 0.12 + 0.04 * ((k + 1) % 2), cols[k + 1])
  end

  -- garden tools leaning near the front corner: a spade, a fork, a rake, a broom
  local function handle(put, y0, y1) put(cyl(0.017, y1 - y0, 0, (y0 + y1) / 2, 0, "y", 8), wood, 40) end
  local tools = {
    function(put)
      put(bmm(-0.01, 0, -0.095, 0.01, 0.28, 0.095), steel)
      put(bmm(-0.015, 0.26, -0.03, 0.015, 0.33, 0.03), metalDk)
      handle(put, 0.3, 1.0)
      put(cyl(0.015, 0.13, 0, 1.06, 0, "z", 8), wood, 40)
    end,
    function(put)
      for k = 0, 3 do put(bmm(-0.008, 0, -0.09 + k * 0.06 - 0.007, 0.008, 0.27, -0.09 + k * 0.06 + 0.007), metalDk) end
      put(bmm(-0.012, 0.25, -0.1, 0.012, 0.3, 0.1), metalDk)
      handle(put, 0.3, 1.02)
      put(cyl(0.015, 0.13, 0, 1.08, 0, "z", 8), wood, 40)
    end,
    function(put)
      handle(put, 0, 1.5)
      put(bmm(-0.015, 1.5, -0.22, 0.015, 1.53, 0.22), metalDk)
      for k = 0, 11 do put(bmm(-0.075, 1.5, -0.2 + k * 0.0364 - 0.004, -0.015, 1.51, -0.2 + k * 0.0364 + 0.004), metalDk) end
    end,
    function(put)
      put(bmm(-0.025, 0, -0.2, 0.025, 0.07, 0.2), C(0.25, 0.17, 0.08))
      put(bmm(-0.035, 0.07, -0.21, 0.035, 0.12, 0.21), C(0.5, 0.12, 0.06))
      handle(put, 0.12, 1.35)
    end,
  }
  local spots = {{-5.02, 3.55, 11, 8}, {-5.05, 3.85, 10, -10}, {-4.98, 4.2, 12, 20}, {-5.02, 4.5, 11, -25}}
  for i, t in ipairs(tools) do
    local s = spots[i]
    group(t, function(m) return at(rot(rot(m, s[4], axis_y()), s[3], axis_z()), s[1], 0, s[2]) end)
  end
  -- old tyres in the front corner
  for i = 0, P.tyres - 1 do tyre(-4.92 + (i % 2) * 0.04, 0.11 + i * 0.22, 4.92) end
end

-- Right wall: the bicycle hung on two hooks ----------------------------------------------------------------------------
-- (BIKE: a grown-up's bike, a quarter bigger than first drawn -- grown about its hooks, so it still hangs from them.)
local BIKE = 1.25
do
  local bikeFrom = #pieces + 1
  local D = STUD + 0.24                 -- the frame's plane, out from the wall
  local BO = -0.55                      -- along the wall from where it was drawn
  local function bp(z, y, dd) return wpt("right", z + BO, y, D + (dd or 0)) end
  local frameC = C(0.04, 0.14, 0.38)
  local rear, front = {-2.65, 1.78}, {-1.6, 1.78}
  local bb = {-2.2, 1.7}
  local seat = {-2.37, 2.2}
  local htT, htB = {-1.7, 2.2}, {-1.66, 2.06}
  local function rod(p, q, r, c) add(tube(bp(p[1], p[2]), bp(q[1], q[2]), r, 8), c or frameC) end
  rod(seat, htT, 0.016); rod(bb, htB, 0.018); rod(bb, seat, 0.017); rod(htB, htT, 0.02)
  for _, dd in ipairs({-0.04, 0.04}) do
    add(tube(bp(bb[1], bb[2], dd), bp(rear[1], rear[2], dd), 0.009, 6), frameC)
    add(tube(bp(seat[1], seat[2], dd * 0.5), bp(rear[1], rear[2], dd), 0.008, 6), frameC)
    add(tube(bp(htB[1], htB[2], dd * 0.6), bp(front[1], front[2], dd), 0.01, 6), steel)
  end
  for _, w in ipairs({rear, front}) do
    local c = bp(w[1], w[2])
    add(at(torus{major_radius=0.33, minor_radius=0.02, major_segments=32, minor_segments=6, axis="x"}, c.x, c.y, c.z), rubber, 50)
    add(at(torus{major_radius=0.305, minor_radius=0.009, major_segments=32, minor_segments=4, axis="x"}, c.x, c.y, c.z), steel, 50)
    add(cyl(0.02, 0.1, c.x, c.y, c.z, "x", 8), steel)
    for k = 0, 11 do
      local t = k * math.pi / 6
      local side = (k % 2 == 0) and 0.04 or -0.04
      add(tube(v3(c.x + side, c.y, c.z), v3(c.x, c.y + 0.3 * math.sin(t), c.z + 0.3 * math.cos(t)), 0.0025, 3), steel)
    end
  end
  local sp = bp(-2.4, 2.34)
  rod(seat, {-2.4, 2.34}, 0.012, steel)
  add(bmm(sp.x - 0.07, sp.y, sp.z - 0.16, sp.x + 0.07, sp.y + 0.06, sp.z + 0.1), C(0.15, 0.08, 0.04))
  local hb = bp(-1.75, 2.3)
  rod(htT, {-1.75, 2.3}, 0.012, steel)
  add(cyl(0.012, 0.44, hb.x, hb.y, hb.z, "x", 8), steel)
  for _, dd in ipairs({-0.18, 0.18}) do add(cyl(0.018, 0.1, hb.x + dd, hb.y, hb.z, "x", 8), rubber) end
  local cb = bp(bb[1], bb[2], -0.06)
  add(at(torus{major_radius=0.09, minor_radius=0.012, major_segments=20, minor_segments=4, axis="x"}, cb.x, cb.y, cb.z), metalDk, 50)
  add(tube(v3(cb.x - 0.01, cb.y, cb.z), v3(cb.x - 0.01, cb.y - 0.17, cb.z + 0.03), 0.01, 6), steel)
  add(bmm(cb.x - 0.1, cb.y - 0.19, cb.z, cb.x - 0.01, cb.y - 0.16, cb.z + 0.08), rubber)
  for _, z in ipairs({-2.15, -1.9}) do
    local y = 2.18
    add(wbox("right", z + BO - 0.015, z + BO + 0.015, y - 0.04, y - 0.01, STUD, D + 0.05), C(0.6, 0.45, 0.05))
    add(wbox("right", z + BO - 0.015, z + BO + 0.015, y - 0.04, y + 0.04, D + 0.04, D + 0.06), C(0.6, 0.45, 0.05))
  end
  local hook = wpt("right", -2.025 + BO, 2.18, STUD)
  for i = bikeFrom, #pieces do pieces[i][1] = scale(pieces[i][1], {factor=BIKE, pivot=hook}) end
end

-- Right wall: the dartboard, the half-built chassis and wheels, the seed shelf, hose, mower, the back corner --------
do
  -- the dartboard with three darts in it
  local db = 0.0
  local rings = {{0.24, woodDk}, {0.19, rubber}, {0.17, C(0.5, 0.06, 0.04)}, {0.155, C(0.6, 0.55, 0.4)}, {0.1, C(0.05, 0.25, 0.08)}, {0.088, C(0.6, 0.55, 0.4)}, {0.03, C(0.05, 0.25, 0.08)}, {0.013, C(0.6, 0.06, 0.04)}}
  for k, r in ipairs(rings) do
    local p = wpt("right", db, 1.75, STUD + 0.015 + k * 0.003)
    add(cyl(r[1], 0.03, p.x, p.y, p.z, "x", 28), r[2], 40)
  end
  for k, dp in ipairs({{0.05, 0.06}, {-0.07, 0.02}, {0.02, -0.11}}) do
    local p = wpt("right", db + dp[1], 1.75 + dp[2], STUD + 0.04)
    local q = wpt("right", db + dp[1] * 1.3, 1.75 + dp[2] * 1.3 + 0.02, STUD + 0.17)
    add(tube(p, q, 0.005, 5), steel)
    add(wbox("right", db + dp[1] * 1.3 - 0.015, db + dp[1] * 1.3 + 0.015, 1.75 + dp[2] * 1.3, 1.75 + dp[2] * 1.3 + 0.04, STUD + 0.15, STUD + 0.19), k == 2 and yellow or red)
  end

  -- the half-built kart chassis leaning: two rails, cross-members, a front axle with one wheel on, a seat plank
  group(function(put)
    for _, z in ipairs({-0.27, 0.27}) do put(bmm(-0.02, 0, z - 0.025, 0.02, 1.6, z + 0.025), woodPale) end
    for _, y in ipairs({0.15, 0.8, 1.45}) do put(bmm(-0.02, y - 0.03, -0.25, 0.02, y + 0.03, 0.25), shade(woodPale, 0.9)) end
    put(bmm(0.02, 1.38, -0.45, 0.07, 1.46, 0.45), wood)
    put(cyl(0.01, 1.0, 0.045, 1.42, 0, "z", 6), steel)
    put(at(torus{major_radius=0.11, minor_radius=0.045, major_segments=18, minor_segments=6, axis="z"}, 0.045, 1.42, 0.5), rubber, 50)
    put(cyl(0.07, 0.05, 0.045, 1.42, 0.5, "z", 14), C(0.6, 0.55, 0.45), 40)
    put(bmm(-0.03, 0.25, -0.24, -0.012, 0.75, 0.24), vary(woodPale, 77, 0.1))
    for _, y in ipairs({0.15, 0.8, 1.45}) do for _, z in ipairs({-0.27, 0.27}) do put(cyl(0.008, 0.06, -0.03, y, z, "x", 6), steel) end end
  end, function(m) return at(rot(m, -11, axis_z()), IN - STUD - 0.35, 0, 1.9) end)
  -- spare kart wheels: two leaning on the wall, two lying flat
  for k, a in ipairs({2.75, 3.05}) do
    local p = wpt("right", a, 0.16, STUD + 0.06 + 0.06 * k)
    add(at(torus{major_radius=0.11, minor_radius=0.045, major_segments=18, minor_segments=6, axis="x"}, p.x, p.y, p.z), rubber, 50)
    add(cyl(0.07, 0.05, p.x, p.y, p.z, "x", 14), C(0.6, 0.55, 0.45), 40)
  end
  for k = 0, 1 do
    add(at(torus{major_radius=0.11, minor_radius=0.045, major_segments=18, minor_segments=6, axis="y"}, 4.72 + 0.03 * k, 0.045 + 0.09 * k, 2.95), rubber, 50)
    add(cyl(0.07, 0.05, 4.72 + 0.03 * k, 0.045 + 0.09 * k, 2.95, "y", 14), C(0.6, 0.55, 0.45), 40)
  end
  -- the seed shelf over them: trays, pots
  wshelf("right", 1.25, 3.2, 2.2, 0.3)
  for k = 0, 2 do
    add(wbox("right", 1.35 + k * 0.4, 1.7 + k * 0.4, 2.2, 2.26, STUD + 0.03, STUD + 0.26), rubber)
    add(wbox("right", 1.37 + k * 0.4, 1.68 + k * 0.4, 2.26, 2.265, STUD + 0.05, STUD + 0.24), C(0.12, 0.08, 0.04))
  end
  for k = 0, 1 do
    local p = wpt("right", 2.65 + k * 0.28, 2.2, STUD + 0.15)
    add(at(cone{radius=0.065, radius_top=0.09, height=0.12, segments=14, anchor="base"}, p.x, p.y, p.z), vary(terra, k + 5, 0.1), 40)
  end
  -- the hose reel, terracotta pots
  local hp = wpt("right", 3.65, 1.15, STUD)
  add(bmm(hp.x - 0.04, hp.y - 0.25, hp.z - 0.04, hp.x, hp.y + 0.25, hp.z + 0.04), C(0.6, 0.45, 0.05))
  for k = 0, 3 do add(at(torus{major_radius=0.22, minor_radius=0.02, major_segments=24, minor_segments=6, axis="x"}, hp.x - 0.06 - k * 0.04, hp.y, hp.z), C(0.1, 0.4, 0.1), 50) end
  for k = 0, 3 do add(at(cone{radius=0.1, radius_top=0.14, height=0.15, segments=16, anchor="base"}, 5.08, k * 0.08, 3.5), vary(terra, k, 0.1), 40) end
  -- the lawnmower: a green deck, a dome, wheels, a grass box, its handle
  local mx, mz = 4.97, 4.25
  add(bmm(mx - 0.3, 0.08, mz - 0.25, mx + 0.3, 0.24, mz + 0.25), C(0.1, 0.3, 0.07))
  add(cyl(0.2, 0.08, mx, 0.28, mz - 0.02, "y", 18), C(0.1, 0.3, 0.07), 40)
  add(cyl(0.11, 0.12, mx, 0.38, mz - 0.02, "y", 14), metalDk, 40)
  for _, wx in ipairs({mx - 0.31, mx + 0.31}) do
    for _, wz in ipairs({mz - 0.18, mz + 0.18}) do add(cyl(0.085, 0.04, wx, 0.085, wz, "x", 14), rubber, 40) end
  end
  add(bmm(mx - 0.24, 0.1, mz + 0.25, mx + 0.24, 0.42, mz + 0.55), C(0.06, 0.16, 0.05))
  for _, hx in ipairs({mx - 0.2, mx + 0.2}) do add(tube(v3(hx, 0.24, mz + 0.22), v3(hx, 0.95, mz + 0.8), 0.013, 6), metal) end
  add(cyl(0.016, 0.44, mx, 0.95, mz + 0.8, "x", 8), rubber)
  add(at(torus{major_radius=0.12, minor_radius=0.018, major_segments=16, minor_segments=5, axis="x"}, mx + 0.2, 0.78, mz + 0.65), orange, 50)

  -- the back corner: boxes stacked crooked, an old suitcase; shelves over them; a number plate
  cbox(5.05, 0, -5.0, 0.55, 0.5, 0.55, 7, 11)
  cbox(5.0, 0.5, -5.02, 0.48, 0.34, 0.45, -11, 12)
  cbox(5.08, 0.84, -4.98, 0.36, 0.24, 0.34, 19, 13)
  cbox(4.95, 0, -4.4, 0.45, 0.38, 0.45, -16, 14)
  add(bmm(4.85, 0, -4.05, 5.3, 0.2, -3.4), C(0.35, 0.16, 0.08))
  add(bmm(5.0, 0.2, -3.82, 5.15, 0.23, -3.62), C(0.15, 0.08, 0.04))
  wshelf("right", -5.3, -3.85, 1.45, 0.32)
  wshelf("right", -5.3, -3.85, 2.1, 0.32)
  add(wbox("right", -5.15, -4.75, 1.45, 1.72, STUD + 0.05, STUD + 0.28), C(0.6, 0.58, 0.5))
  add(wbox("right", -5.1, -4.8, 1.5, 1.67, STUD + 0.28, STUD + 0.29), metalDk)
  add(wbox("right", -4.6, -4.3, 1.45, 1.64, STUD + 0.06, STUD + 0.26), C(0.04, 0.04, 0.045))
  add(wbox("right", -4.57, -4.51, 1.64, 1.67, STUD + 0.1, STUD + 0.14), red)
  add(wbox("right", -4.39, -4.33, 1.64, 1.67, STUD + 0.1, STUD + 0.14), metalDk)
  local tp = wpt("right", -4.05, 1.45, STUD + 0.16)
  tin(tp.x, tp.y, tp.z, 0.09, 0.15, red)
  add(wbox("right", -5.2, -4.6, 2.1, 2.42, STUD + 0.02, STUD + 0.31), vary(card, 31, 0.1))
  add(wbox("right", -4.5, -3.95, 2.1, 2.33, STUD + 0.02, STUD + 0.3), vary(card, 32, 0.1))
  add(wbox("right", -5.1, -4.1, 2.6, 2.82, STUD, STUD + 0.01), yellow)
  for k = 0, 6 do
    local a = -5.04 + k * 0.13 + (k > 3 and 0.05 or 0)
    add(wbox("right", a, a + 0.085, 2.64, 2.78, STUD + 0.01, STUD + 0.013), rubber)
  end
end

STUFF[#STUFF + 1] = {stuffFrom, #pieces}

-- Front wall: the double wooden doors, timber over them -----------------------------------------------------------------
do
  local o = OPEN.front
  add(wbox("front", o[1], o[2], 0, 0.04, -0.02, 0.012), glow)
  add(wbox("front", -0.01, 0.01, 0, o[4], -0.02, 0.012), glow)
  add(wbox("front", o[1] - 0.1, o[1], 0, o[4] + 0.1, 0, STUD + 0.01), wood)
  add(wbox("front", o[2], o[2] + 0.1, 0, o[4] + 0.1, 0, STUD + 0.01), wood)
  local doorC = C(0.09, 0.19, 0.11)
  for side = -1, 1, 2 do
    local e0, e1 = side < 0 and o[1] or 0.012, side < 0 and -0.012 or o[2]
    local n = 6
    local w = (e1 - e0) / n
    for k = 0, n - 1 do
      add(wbox("front", e0 + k * w + 0.004, e0 + (k + 1) * w - 0.004, 0.04, o[4] - 0.03, 0.012, 0.035), vary(doorC, k + side * 20, 0.15))
    end
    local ys = {{0.22, 0.36}, {0.98, 1.12}, {1.75, 1.89}}
    for _, y in ipairs(ys) do add(wbox("front", e0 + 0.05, e1 - 0.05, y[1], y[2], 0.035, 0.065), shade(doorC, 0.8)) end
    local hinge, latch = side < 0 and e0 + 0.06 or e1 - 0.06, side < 0 and e1 - 0.06 or e0 + 0.06
    for b = 1, 2 do
      local ya, yb = ys[b][2], ys[b + 1][1]
      add(wprism("front", {{hinge, ya}, {hinge, ya + 0.13}, {latch, yb}, {latch, yb - 0.13}}, 0.035, 0.06), shade(doorC, 0.75))
    end
    for _, y in ipairs(ys) do
      local h0 = side < 0 and o[1] - 0.06 or o[2] - 0.38
      add(wbox("front", h0, h0 + 0.44, y[1] + 0.04, y[2] - 0.04, 0.065, 0.072), metalDk)
    end
  end
  add(wbox("front", -0.25, -0.05, 1.8, 1.84, 0.065, 0.09), metalDk)
  add(wbox("front", -0.04, 0.06, 1.79, 1.85, 0.065, 0.09), metalDk)
  add(wbox("front", -0.15, 0.15, 1.03, 1.07, 0.065, 0.1), metalDk)
  -- a rack of timber lengths over the doors
  for _, a in ipairs({-1.3, 0, 1.3}) do
    add(wbox("front", a - 0.02, a + 0.02, 2.38, 2.44, STUD, STUD + 0.36), metalDk)
    add(wbox("front", a - 0.02, a + 0.02, 2.26, 2.44, STUD, STUD + 0.03), metalDk)
  end
  for k, t in ipairs({{0.02, 0.07, 0.05}, {0.1, 0.17, 0.1}, {0.19, 0.24, 0.045}, {0.26, 0.34, 0.07}}) do
    add(wbox("front", -1.6 + 0.08 * k, 1.65 - 0.05 * k, 2.44, 2.44 + t[3], STUD + t[1], STUD + t[2]), vary(woodPale, k + 50, 0.15))
  end
end

stuffFrom = #pieces + 1

-- Front wall: a coat over wellies, the painted cupboard, the chest freezer, a pallet ------------------------------
do
  add(wbox("front", -3.2, -2.1, 1.7, 1.78, STUD, STUD + 0.03), wood)
  for _, a in ipairs({-3.0, -2.6, -2.3}) do add(wbox("front", a - 0.012, a + 0.012, 1.72, 1.76, STUD + 0.03, STUD + 0.1), metalDk) end
  local jc = C(0.12, 0.13, 0.07)
  add(wbox("front", -2.85, -2.35, 0.95, 1.7, STUD + 0.03, STUD + 0.2), jc)
  add(wbox("front", -2.95, -2.8, 1.0, 1.62, STUD + 0.05, STUD + 0.17), shade(jc, 0.85))
  add(wbox("front", -2.4, -2.25, 1.0, 1.62, STUD + 0.05, STUD + 0.17), shade(jc, 0.85))
  add(wbox("front", -2.7, -2.5, 1.62, 1.75, STUD + 0.17, STUD + 0.2), C(0.25, 0.15, 0.06))
  local cp = wpt("front", -3.0, 1.62, STUD + 0.1)
  add(cyl(0.1, 0.06, cp.x, cp.y, cp.z, "y", 14), C(0.25, 0.2, 0.12), 40)
  for k, a in ipairs({-2.75, -2.48}) do
    local p = wpt("front", a, 0, STUD + 0.3)
    add(rot(bmm(-0.05, 0, -0.14, 0.05, 0.08, 0.06), k == 2 and 12 or 0, axis_y()), C(0.05, 0.18, 0.06))
    pieces[#pieces] = {at(pieces[#pieces][1], p.x, 0, p.z), pieces[#pieces][2], pieces[#pieces][3]}
    add(cyl(0.06, 0.32, p.x, 0.24, p.z + 0.02, "y", 12), C(0.05, 0.18, 0.06), 40)
    add(cyl(0.062, 0.02, p.x, 0.39, p.z + 0.02, "y", 12), C(0.03, 0.1, 0.03), 40)
  end
  -- the old painted cupboard in the corner, boxes on it
  local cz0, cz1 = IN - STUD - 0.58, IN - STUD
  local cupC = C(0.22, 0.32, 0.3)
  add(bmm(3.45, 0, cz0, 4.4, 1.95, cz1), cupC)
  add(bmm(3.43, 1.95, cz0 - 0.02, 4.42, 2.0, cz1), shade(cupC, 0.8))
  add(bmm(3.47, 0.05, cz0 - 0.015, 3.92, 1.9, cz0), vary(cupC, 1, 0.08))
  add(bmm(3.94, 0.05, cz0 - 0.015, 4.38, 1.9, cz0), vary(cupC, 2, 0.08))
  for _, x in ipairs({3.87, 3.99}) do add(cyl(0.015, 0.03, x, 1.0, cz0 - 0.03, "z", 8), steel) end
  cbox(3.75, 2.0, (cz0 + cz1) / 2, 0.55, 0.3, 0.45, 6, 41)
  add(bmm(4.05, 2.0, cz0 + 0.1, 4.37, 2.16, cz1 - 0.1), C(0.3, 0.12, 0.06))
  -- the chest freezer, a box and a tin on it, a shelf of jars over it
  add(wbox("front", 2.0, 3.2, 0, 0.82, STUD + 0.02, STUD + 0.64), white)
  add(wbox("front", 1.98, 3.22, 0.82, 0.88, STUD, STUD + 0.66), shade(white, 1.08))
  add(wbox("front", 2.45, 2.75, 0.72, 0.78, STUD + 0.66, STUD + 0.69), metalDk)
  local fp = wpt("front", 2.85, 0.88, STUD + 0.33)
  cbox(fp.x, 0.88, fp.z, 0.4, 0.24, 0.3, -8, 21)
  local fq = wpt("front", 2.25, 0.88, STUD + 0.35)
  tin(fq.x, fq.y, fq.z, 0.08, 0.13, C(0.6, 0.55, 0.42))
  wshelf("front", 1.95, 3.25, 1.6, 0.28)
  for k = 0, 3 do
    local p = wpt("front", 2.15 + k * 0.14, 1.6, STUD + 0.12)
    jar(p.x, p.y, p.z, 0.045, 0.12, k % 2 == 0 and metal or C(0.45, 0.33, 0.12), k % 2 == 0 and red or C(0.6, 0.55, 0.1))
  end
  local tq = wpt("front", 2.95, 1.6, STUD + 0.15)
  tin(tq.x, tq.y, tq.z, 0.1, 0.17, white)
  -- a pallet leaning by it
  group(function(put)
    for k = 0, 4 do put(bmm(-0.5, 0.1 + k * 0.24, 0.0, 0.5, 0.2 + k * 0.24, 0.02), vary(woodPale, k + 30, 0.15)) end
    for _, x in ipairs({-0.45, 0, 0.45}) do put(bmm(x - 0.05, 0.05, 0.02, x + 0.05, 1.15, 0.11), vary(woodPale, x * 10 + 40, 0.15)) end
  end, function(m) return at(rot(m, 8, axis_x()), -3.95, 0, IN - STUD - 0.3) end)
end

-- The untidy floor: all of it low (under 0.3 m), so it can lie anywhere --------------------------------------------
if P.mess then
  -- sawdust piles and shavings under the bench and by the chassis; offcuts kicked about
  for i, s in ipairs({{-4.45, -4.1, 0.35, 0.06}, {-4.35, -3.3, 0.25, 0.045}, {-4.5, -2.4, 0.2, 0.03}, {4.55, 1.8, 0.28, 0.04}, {3.3, -4.75, 0.22, 0.03}}) do
    add(at(cone{radius=s[3], radius_top=s[3] * 0.25, height=s[4], segments=16, anchor="base"}, s[1], 0, s[2]), vary(sawdust, i, 0.08), 40)
    add(blob(s[1] + 0.1, s[2] + 0.05, s[3] * 1.8, s[3] * 1.4, i * 20, 0, 0.004), shade(sawdust, 0.85))
  end
  for i, o in ipairs({{-3.9, -3.0, 0.7, 25}, {-3.7, -2.0, 0.45, -40}, {4.2, 1.2, 0.6, 70}, {4.0, 2.4, 0.35, 10},
                      {2.6, -4.3, 0.55, -15}, {-1.2, 4.3, 0.5, 80}, {0.9, -4.4, 0.4, 35}, {-4.1, 0.5, 0.3, 60}}) do
    add(at(rot(bmm(-o[3] / 2, 0, -0.045, o[3] / 2, 0.035 + 0.01 * (i % 3), 0.045), o[4], axis_y()), o[1], 0, o[2]), vary(woodPale, i + 90, 0.2))
  end
  add(at(rot(bmm(-0.3, 0.035, -0.04, 0.3, 0.07, 0.04), 50, axis_y()), -3.85, 0, -2.95), vary(woodPale, 99, 0.2))
  -- rags
  add(slab({{-2.3, 1.5}, {-1.9, 1.42}, {-1.75, 1.75}, {-2.05, 2.05}, {-2.42, 1.9}}, 0, 0.02), C(0.5, 0.1, 0.06))
  add(slab({{2.8, 1.0}, {3.2, 0.95}, {3.3, 1.25}, {2.95, 1.4}}, 0, 0.018), C(0.55, 0.5, 0.42))
  add(slab({{-1.6, -3.6}, {-1.25, -3.75}, {-1.1, -3.45}, {-1.4, -3.3}}, 0, 0.016), C(0.25, 0.3, 0.45))
  -- a paint tin tipped over, its paint run out across the floor, the lid by it
  local px, pz = -2.55, -1.35
  add(at(rot(cylinder{radius=0.09, height=0.17, segments=16, axis="x"}, 20, axis_y()), px, 0.09, pz), C(0.1, 0.3, 0.12), 40)
  add(at(rot(cylinder{radius=0.088, height=0.06, segments=16, axis="x"}, 20, axis_y()), px + 0.01, 0.09, pz - 0.003), white, 40)
  add(blob(px + 0.25, pz - 0.12, 0.28, 0.2, 300, 0, 0.004), C(0.12, 0.35, 0.15))
  add(blob(px + 0.45, pz - 0.2, 0.12, 0.09, 310, 0, 0.0045), C(0.12, 0.35, 0.15))
  add(cyl(0.095, 0.008, px - 0.3, 0.004, pz + 0.25, "y", 16), C(0.1, 0.3, 0.12), 50)
  add(at(rot(bmm(-0.18, 0, -0.02, 0.18, 0.025, 0.02), 70, axis_y()), px - 0.1, 0, pz + 0.45), wood)
  -- an open toolbox on the floor, its lid flopped back, tools spilt round it
  local tx, tz = 2.25, -2.75
  group(function(put)
    put(bmm(-0.25, 0, -0.12, 0.25, 0.2, 0.12), C(0.6, 0.08, 0.04))
    put(bmm(-0.25, 0, -0.38, 0.25, 0.025, -0.13), shade(C(0.6, 0.08, 0.04), 1.2))
    put(bmm(-0.23, 0.17, -0.1, 0.23, 0.18, 0.1), metalDk)
    put(bmm(-0.04, 0.2, -0.015, 0.04, 0.24, 0.015), metalDk)
    for k = 0, 2 do put(rot(bmm(-0.03, 0.12, -0.01, 0.03, 0.27, 0.01), -15 + 15 * k, axis_z(), v3(0, 0.12, 0)), steel) end
  end, function(m) return at(rot(m, -20, axis_y()), tx, 0, tz) end)
  for k, t in ipairs({{0.45, 0.2, 30, 0.2}, {0.35, 0.45, -60, 0.16}, {-0.4, 0.3, 80, 0.24}, {0.6, -0.15, 10, 0.14}}) do
    add(at(rot(bmm(-t[4] / 2, 0, -0.012, t[4] / 2, 0.01, 0.012), t[3], axis_y()), tx + t[1], 0, tz + t[2]), steel)
  end
  add(at(rot(cylinder{radius=0.016, height=0.14, segments=8, axis="x"}, 40, axis_y()), tx - 0.2, 0.016, tz + 0.5), red, 40)
  add(at(rot(cylinder{radius=0.005, height=0.12, segments=6, axis="x"}, 40, axis_y()), tx - 0.3, 0.016, tz + 0.58), steel)
  add(at(rot(cylinder{radius=0.015, height=0.3, segments=8, axis="x"}, -25, axis_y()), tx + 0.55, 0.015, tz + 0.55), wood, 40)
  add(at(rot(bmm(-0.025, 0, -0.08, 0.025, 0.045, 0.08), -25, axis_y()), tx + 0.69, 0, tz + 0.49), metalDk)
  -- a tangle of extension cable from the wall to the bench, a plug at its end
  local cx, cz = -3.6, -0.7
  for k, l in ipairs({{0, 0, 0.22}, {0.15, 0.1, 0.18}, {-0.08, 0.18, 0.2}, {0.1, -0.12, 0.15}, {0.25, 0.25, 0.12}}) do
    add(at(torus{major_radius=l[3], minor_radius=0.011, major_segments=20, minor_segments=4, axis="y"}, cx + l[1], 0.011 + 0.004 * k, cz + l[2]), orange, 50)
  end
  local run = {{-5.3, 0.012, 0.1}, {-4.8, 0.012, -0.3}, {-4.2, 0.012, -0.5}, {-3.85, 0.012, -0.65}}
  for i = 1, #run - 1 do add(tube(v3(run[i][1], run[i][2], run[i][3]), v3(run[i + 1][1], run[i + 1][2], run[i + 1][3]), 0.011, 5), orange) end
  local run2 = {{-3.35, 0.014, -0.75}, {-3.3, 0.014, -1.3}, {-3.8, 0.014, -1.7}, {-4.5, 0.014, -1.85}}
  for i = 1, #run2 - 1 do add(tube(v3(run2[i][1], run2[i][2], run2[i][3]), v3(run2[i + 1][1], run2[i + 1][2], run2[i + 1][3]), 0.011, 5), orange) end
  add(bmm(-4.6, 0, -1.9, -4.5, 0.05, -1.8), C(0.1, 0.1, 0.1))
  -- crumpled paper fallen out of the bin, a tape roll, a spanner
  for k, cp in ipairs({{-4.5, 1.3}, {-4.3, 2.0}, {-4.65, 0.9}}) do add(at(sphere{radius=0.06, segments=8, rings=4}, cp[1], 0.05, cp[2]), vary(paper, k + 230, 0.2), 20) end
  add(cyl(0.12, 0.08, -1.7, 0.04, -2.6, "y", 20), C(0.08, 0.15, 0.4), 30)
  add(rot(bmm(1.5, 0.003, 2.3, 1.75, 0.015, 2.33), 30, axis_y(), v3(1.6, 0, 2.31)), steel)
end

-- Old-workshop odds and ends: a rusty horseshoe nailed up over the doors (for luck), an oil lantern on a nail by them,
-- a coil of rope hung on a stud, and cobwebs in the corners under the eaves.
do
  local rust = C(0.32, 0.13, 0.05)
  local o = OPEN.front
  -- the horseshoe, its open end up
  local hs = wpt("front", 0, o[4] + 0.3, STUD + 0.012)
  local shoe = subtract(torus{major_radius=0.09, minor_radius=0.014, major_segments=20, minor_segments=5, axis="z"}, bx(0.3, 0.12, 0.1, 0, 0.1, 0))
  add(at(shoe, hs.x, hs.y, hs.z), rust, 40)
  for _, s in ipairs({-1, 1}) do add(cyl(0.008, 0.03, hs.x + s * 0.06, hs.y - 0.06, hs.z + 0.01, "z", 6), metalDk) end
  -- the lantern: a tin base, a glass chimney in four wire posts, a tin cap and a wire bail on a nail
  local lp = wpt("front", o[1] - 0.25, 2.05, STUD + 0.14)
  add(cyl(0.07, 0.06, lp.x, lp.y, lp.z, "y", 14), C(0.45, 0.12, 0.06))
  add(cyl(0.045, 0.14, lp.x, lp.y + 0.1, lp.z, "y", 14), glass)
  add(cyl(0.012, 0.03, lp.x, lp.y + 0.08, lp.z, "y", 8), glow, 40)
  for k = 0, 3 do
    local t = k * math.pi / 2 + math.pi / 4
    add(cyl(0.004, 0.16, lp.x + 0.055 * math.cos(t), lp.y + 0.1, lp.z + 0.055 * math.sin(t), "y", 4), metalDk)
  end
  add(at(cone{radius=0.065, height=0.06, segments=14, anchor="base"}, lp.x, lp.y + 0.17, lp.z), C(0.45, 0.12, 0.06))
  add(tube(v3(lp.x - 0.05, lp.y + 0.2, lp.z), v3(lp.x, lp.y + 0.32, lp.z - 0.1), 0.004, 4), metalDk)
  add(tube(v3(lp.x + 0.05, lp.y + 0.2, lp.z), v3(lp.x, lp.y + 0.32, lp.z - 0.1), 0.004, 4), metalDk)
  -- the rope: a coil of loops hung on a stud on the left wall, its tail hanging down
  local rp = wpt("left", -2.95, 2.55, STUD + 0.05)
  local hemp = C(0.5, 0.38, 0.2)
  for k = 0, 4 do
    add(at(scale(torus{major_radius=0.17, minor_radius=0.018, major_segments=20, minor_segments=5, axis="x"}, {factor=v3(1, 1.25, 1), pivot=origin()}),
      rp.x + k * 0.012, rp.y - 0.2 - k * 0.012, rp.z + (k - 2) * 0.01), vary(hemp, k + 900, 0.12), 40)
  end
  add(tube(v3(rp.x + 0.05, rp.y - 0.4, rp.z + 0.12), v3(rp.x + 0.06, rp.y - 0.85, rp.z + 0.16), 0.016, 5), hemp)
  add(cyl(0.008, 0.08, rp.x - 0.03, rp.y, rp.z, "x", 6), metalDk)
  -- cobwebs: a grey sheet strung across each corner under the eaves
  local web = C(0.5, 0.5, 0.48)
  for _, sx in ipairs({-1, 1}) do
    for _, sz in ipairs({-1, 1}) do
      local cx, cz = sx * (IN - STUD), sz * (IN - STUD)
      local pts = {v3(cx, EAVE - 0.14, cz), v3(cx - sx * 0.45, EAVE - 0.14, cz), v3(cx, EAVE - 0.14, cz - sz * 0.45), v3(cx, EAVE - 0.55, cz)}
      add(prism({pts[1], pts[2], pts[4]}, v3(0, 0, -sz * 0.004)), web, 10)
      add(prism({pts[1], pts[3], pts[4]}, v3(-sx * 0.004, 0, 0)), web, 10)
    end
  end
end

STUFF[#STUFF + 1] = {stuffFrom, #pieces}

-- The stuff grown: each piece about the foot of the wall nearest it -- out from that wall and up from the floor --
-- and about its own middle along the wall, so it stays against its wall and on its floor, over its own spot, and
-- nothing is pushed along into a corner. A piece out in the room (the floor's clutter) grows about its own middle.
if P.stuff ~= 1 then
  for _, run in ipairs(STUFF) do
    for i = run[1], run[2] do
      local b = bbox(pieces[i][1])
      local c = b.center
      local pv
      local dx, dz = IN - math.abs(c.x), IN - math.abs(c.z)
      if math.min(dx, dz) > 1.2 then pv = v3(c.x, 0, c.z)
      elseif dx < dz then pv = v3(c.x < 0 and -IN or IN, 0, c.z)
      else pv = v3(c.x, 0, c.z < 0 and -IN or IN) end
      pieces[i][1] = scale(pieces[i][1], {factor=P.stuff, pivot=pv})
    end
  end
end

-- The part -------------------------------------------------------------------------------------------------------------
-- Each piece is its own closed shell; many butt against one another edge to edge (a board's end on a stud, a shelf's
-- brackets at its ends). A nudge of a few hundredths of a millimetre, different for each, keeps those shells
-- from sharing an edge once merged, which would read as non-manifold.
local out = {}
for i, p in ipairs(pieces) do
  local j = v3((hash(i * 3) - 0.5) * 1e-4, (hash(i * 3 + 1) - 0.5) * 1e-4, (hash(i * 3 + 2) - 0.5) * 1e-4)
  local m = translate(p[1], j)
  m = p[2] and paint(m, p[2]) or m
  out[i] = {mesh=smooth_normals(m, {angle=p[3] or 30}), material=PAINT}
end
local merged = merge({parts=out, mode="compatible"})
emit(merged[1].mesh, {name="room", material=merged[1].material, open=true})
