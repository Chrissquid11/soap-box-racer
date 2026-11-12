-- Flower Power: a retro split-window camper van for a kart body, one part "van". A sage-green lower tub with wheel
-- arches under a white belt moulding; a cream window band set in from it, open round-cornered windows with orange
-- curtain pelmets and a split windscreen; a thin stepped cream roof with skylights; on it a roof rack (the signature
-- piece) carrying a surfboard, a bedroll and a suitcase, and a little action camera. A cream V nose with a daisy
-- emblem, chrome-ringed headlamps, stalk mirrors, a chrome bumper, a side door outline, engine louvres, big painted
-- daisies and a peace sign on the back -- and the bodges: tin patches, tape, primer, a blue door, a plank for a back
-- bumper. The driver sits on a dark bucket seat in the middle of the van, legs forward to the dashboard.
--
-- In the kart's body space, metres: the origin the middle of the (hidden) chassis box's top, +z forward, y up. The
-- cockpit keeps clear of x ±0.28, z -0.5..0.45 above y -0.2; the wheels (another slot) sit at x ±0.5, z ±0.7, y -0.42.
local p = params{
  roof_height = { default = 1.0, min = 0.95, max = 1.12, doc = "Height of the window band's top (the roof's foot), metres" },
  windows     = { default = 4, min = 3, max = 5, integer = true, doc = "Open windows along each side" },
  arch        = { default = 0.36, min = 0.3, max = 0.4, doc = "Wheel arch radius, metres" },
  daisies     = { default = 5, min = 0, max = 8, integer = true, doc = "Painted daisies on each side" },
}

-- One paint per colour, all alike but for it: merge (compatible) folds them into one white material with each
-- piece's colour on its vertices -- the same result as paint_faces on a white material, without a call per piece.
local paints = {}
local function paint_of(c)
  local key = string.format("%.3f_%.3f_%.3f", c.x, c.y, c.z)
  if not paints[key] then paints[key] = material{name="Paint_" .. key, base_color=c, roughness=0.55, metallic=0} end
  return paints[key]
end
-- A part of pieces, each { mesh, colour, angle }: each piece's normals smoothed, then all merged into one mesh with
-- its colours on its vertices.
local function part(name, pieces)
  local out = {}
  for i, q in ipairs(pieces) do
    out[i] = {mesh=smooth_normals(q[1], {angle=q[3] or 40}), material=paint_of(q[2])}
  end
  local merged = merge({parts=out, mode="compatible"})
  emit(merged[1].mesh, {name=name, material=merged[1].material})
  -- Its signature piece (the pieces marked true, 4th): `<name>_sig`, left out of the wreck (_sig.lua).
  local rest = include("_sig.lua").split(name, out, function(i) return pieces[i][4] end)
  -- Its wreck, as the same pieces broken: what stays on the kart when the bodywork is knocked off (_wreck.lua).
  include("_wreck.lua").emit(name, rest)
end
local function C(r, g, b) return v3(r, g, b) end
local function at(m, x, y, z) return translate(m, v3(x, y, z)) end
local function bx(sx, sy, sz, x, y, z) return at(box{size=v3(sx, sy, sz)}, x, y, z) end
-- A box with its edges bevelled.
local function rb(sx, sy, sz, x, y, z, w, seg)
  local m = box{size=v3(sx, sy, sz)}
  return at(bevel(m, {edges=convex_edges(m), width=w or math.min(sx, sy, sz) * 0.2, segments=seg or 1}), x, y, z)
end
-- A box with its corners rounded about y, its base at y; `soft` rounds its top and bottom rims too.
local function rbox(w, h, d, r, x, y, z, soft)
  local m = extrude(rounded_rect{w=w, h=d, radius=r, segments=3}, {distance=h})
  if soft then
    local edge = 2 * r * math.sin(math.pi / 12)
    for _, side in ipairs({w - 2 * r, d - 2 * r}) do if side > 0.001 then edge = math.min(edge, side) end end
    m = bevel(m, {edges=convex_edges(m, {min_angle=60}), width=math.min(soft, edge * 0.4, h * 0.22), segments=1})
  end
  return at(m, x, y, z)
end
local function cyl(r, h, x, y, z, axis, seg) return at(cylinder{radius=r, height=h, segments=seg or 14, axis=axis or "y"}, x, y, z) end
local function sph(r, x, y, z, seg) return at(sphere{radius=r, segments=seg or 12, rings=math.floor((seg or 12) / 2)}, x, y, z) end
-- A flat oval, rx by ry in the xy plane, t thick along z, centred on the origin.
local function petal(rx, ry, t, n)
  local pts = {}
  n = n or 10
  for i = 0, n - 1 do
    local a = 2 * math.pi * i / n
    pts[#pts + 1] = v2(rx * math.cos(a), ry * math.sin(a))
  end
  return rotate(extrude(poly{points=pts}, {distance=t, anchor="center"}), {angle=90, axis=axis_x(), pivot=origin()})
end
local function along(m, a, b)
  local dir = normalize(b - a)
  local c = dot(v3(0, 1, 0), dir)
  if c < -0.9999 then m = rotate(m, {angle=180, axis=axis_x(), pivot=origin()})
  elseif c < 0.9999 then m = rotate(m, {angle=deg(math.acos(c)), axis=normalize(cross(v3(0, 1, 0), dir)), pivot=origin()}) end
  return translate(m, (a + b) * 0.5)
end
-- A round rod from a to b, a hair short of each.
local function rod(a0, b0, r, seg)
  local a, b = lerp(a0, b0, 0.004), lerp(a0, b0, 0.996)
  return along(cylinder{radius=r, height=length(b - a), segments=seg or 8}, a, b)
end
local function turn(m, angle, axis) return rotate(m, {angle=angle, axis=axis, pivot=origin()}) end
-- A closed polyhedron, its faces turned outward whichever way they were listed.
local function solid(vs, fs)
  local vol = 0
  for _, f in ipairs(fs) do
    for k = 2, #f - 1 do vol = vol + dot(vs[f[1]], cross(vs[f[k]], vs[f[k + 1]])) end
  end
  if vol < 0 then
    local rf = {}
    for i, f in ipairs(fs) do
      local r = {}
      for k = #f, 1, -1 do r[#r + 1] = f[k] end
      rf[i] = r
    end
    fs = rf
  end
  return polyhedron{vertices=vs, faces=fs}
end
-- A flat plate of a convex outline { {x, y}, ... } in the xy plane, from z0 to z1.
local function plate(pts, z0, z1)
  local vs, fs, n = {}, {}, #pts
  for _, q in ipairs(pts) do vs[#vs + 1] = v3(q[1], q[2], z0) end
  for _, q in ipairs(pts) do vs[#vs + 1] = v3(q[1], q[2], z1) end
  local a, b = {}, {}
  for i = 1, n do a[i] = n + 1 - i; b[i] = n + i end
  fs[1], fs[2] = a, b
  for i = 1, n do
    local j = i % n + 1
    fs[#fs + 1] = {i, j, n + j, n + i}
  end
  return solid(vs, fs)
end


local sage    = C(0.22, 0.42, 0.29)
local sage_dk = C(0.1, 0.22, 0.14)
local cream   = C(0.93, 0.89, 0.72)
local cream_dk = C(0.78, 0.73, 0.55)
local chrome  = C(0.78, 0.8, 0.84)
local grey    = C(0.45, 0.47, 0.5)
local dark    = C(0.06, 0.06, 0.07)
local seat_c  = C(0.12, 0.12, 0.13)
local glass   = C(0.03, 0.04, 0.05)
local yellow  = C(0.95, 0.68, 0.04)
local white   = C(0.95, 0.95, 0.93)
local purple  = C(0.36, 0.14, 0.62)
local pink    = C(0.92, 0.26, 0.52)
local amber   = C(1.0, 0.42, 0.02)
local red     = C(0.72, 0.02, 0.02)
local orange  = C(0.9, 0.3, 0.04)
-- Patched up: grey primer, rusty tin patches, silver duct tape, a plank, rope, a hand-brushed blue panel.
local primer  = C(0.56, 0.56, 0.52)
local tin     = C(0.5, 0.3, 0.16)
local rivet   = C(0.3, 0.3, 0.32)
local tape    = C(0.76, 0.77, 0.79)
local wood    = C(0.58, 0.4, 0.2)
local rope    = C(0.78, 0.64, 0.38)
local blue    = C(0.2, 0.42, 0.72)

local pieces = {}
local function add(m, c, a, sig) pieces[#pieces + 1] = {m, c, a, sig} end

-- A painted daisy: five petals in one outline, r across, flat in the xy plane (its eye is added where it goes).
local function daisy(r)
  local pts = {}
  for k = 0, 4 do
    for _, q in ipairs({{-36, 0.36}, {-15, 0.95}, {15, 0.95}}) do
      local a = math.rad(k * 72 + q[1] + 90)
      pts[#pts + 1] = v2(r * q[2] * math.cos(a), r * q[2] * math.sin(a))
    end
  end
  return {turn(extrude(poly{points=pts}, {distance=0.01, anchor="center"}), 90, axis_x())}
end

local W, L = 1.24, 2.3             -- the tub's width and length
local HW, HL = W / 2, L / 2
local BOT, BELT = -0.42, 0.33      -- the tub's bottom and top
local TOP = p.roof_height
local ROOF = 0.09                  -- the roof's thickness
local BW, BL = W - 0.07, L - 0.07  -- the window band, set in from the tub
local BHW, BHL = BW / 2, BL / 2

-- The lower tub: sage, hollow, its floor 0.1 thick, wheel arches cut from its sides.
do
  local outer = rbox(W, BELT - BOT, L, 0.16, 0, BOT, 0, 0.05)
  local inner = rbox(W - 0.12, 1.0, L - 0.12, 0.1, 0, BOT + 0.1, 0)
  local cuts = {inner}
  for _, sx in ipairs({-1, 1}) do
    for _, z in ipairs({-0.7, 0.7}) do cuts[#cuts + 1] = cyl(p.arch, 0.4, sx * 0.62, -0.42, z, "x", 16) end
  end
  add(subtract(outer, table.unpack(cuts)), sage)
  -- the arches' lips: a dark half ring round each
  for _, sx in ipairs({-1, 1}) do
    for _, z in ipairs({-0.7, 0.7}) do
      local ring = torus{major_radius=p.arch + 0.014, minor_radius=0.024, major_segments=16, minor_segments=4, axis="x"}
      ring = subtract(ring, bx(0.2, 1, 1.2, 0, -0.5, 0))
      add(at(ring, sx * (HW - 0.003), -0.42, z), sage_dk)
    end
  end
  -- the belt moulding: a white band round the tub's top, the two-tone's line
  add(subtract(rbox(W + 0.035, 0.055, L + 0.035, 0.17, 0, BELT - 0.025, 0),
    rbox(W - 0.16, 0.3, L - 0.16, 0.09, 0, BELT - 0.1, 0)), white)
end

-- The window band: cream, set in from the tub, open round-cornered windows down each side, a split windscreen in
-- front and a window at the back.
local WIN = {}                    -- the side windows' middles, for the curtains
local WY0, WY1 = BELT + 0.1, TOP - 0.07
do
  local outer = rbox(BW, TOP + 0.02 - (BELT - 0.02), BL, 0.14, 0, BELT - 0.02, 0)
  local inner = rbox(BW - 0.1, 2, BL - 0.1, 0.09, 0, BELT - 0.5, 0)
  local cuts = {inner}
  local ym, h = (WY0 + WY1) / 2, WY1 - WY0
  -- a round-cornered hole w wide, hh high, through along x ("x") or z
  local function hole(w, hh, axis, x, y, z)
    local m
    if axis == "x" then
      m = turn(extrude(rounded_rect{w=hh, h=w, radius=0.06, segments=2}, {distance=0.5, anchor="center"}), 90, axis_z())
    else
      m = turn(extrude(rounded_rect{w=w, h=hh, radius=0.06, segments=2}, {distance=0.5, anchor="center"}), 90, axis_x())
    end
    return at(m, x, y, z)
  end
  local n = p.windows
  local zA, zB, post = -0.93, 0.82, 0.09
  local ww = (zB - zA - post * (n - 1)) / n
  for i = 0, n - 1 do
    local zc = zA + ww / 2 + i * (ww + post)
    WIN[#WIN + 1] = zc
    for _, sx in ipairs({-1, 1}) do cuts[#cuts + 1] = hole(ww, h, "x", sx * BHW, ym, zc) end
  end
  -- the split windscreen, its centre post 0.07 wide
  for _, sx in ipairs({-1, 1}) do cuts[#cuts + 1] = hole(0.43, h, "z", sx * 0.25, ym, BHL) end
  cuts[#cuts + 1] = hole(0.8, h * 0.8, "z", 0, ym + h * 0.07, -BHL)
  add(subtract(outer, table.unpack(cuts)), cream)
  -- curtain pelmets along the side windows' tops, a drape tied back at each end of the row
  for _, sx in ipairs({-1, 1}) do
    local x = sx * (BHW - 0.035)
    for _, zc in ipairs(WIN) do add(bx(0.02, 0.085, ww + 0.04, x, WY1 - 0.03, zc), orange) end
    for _, e in ipairs({{zA, 1}, {zB, -1}}) do
      -- the plate lies in xy: its x turned onto z, toward the row's middle
      local m = plate({{0, 0}, {0.1, 0}, {0.035, -h * 0.75}, {0, -h * 0.75}}, -0.01, 0.01)
      m = turn(m, e[2] > 0 and -90 or 90, axis_y())
      add(at(m, x, WY1 - 0.06, e[1]), orange)
    end
  end
  -- wipers, parked
  for _, sx in ipairs({-1, 1}) do
    add(rod(v3(sx * 0.06, WY0 - 0.02, BHL + 0.008), v3(sx * 0.36, WY0 + 0.1, BHL + 0.008), 0.009, 4), dark)
  end
end

-- The roof: cream, thin (ROOF) so the chasing camera sees over it to the road: a wide eave with a peak over the
-- windscreen, a raised panel on it; skylights along its edge.
add(rbox(W + 0.03, 0.05, L + 0.06, 0.2, 0, TOP, 0.03, 0.02), cream)
add(rbox(W - 0.12, ROOF - 0.045, L - 0.14, 0.2, 0, TOP + 0.045, 0, 0.02), cream)
for _, sx in ipairs({-1, 1}) do
  for i = 0, 3 do
    add(bx(0.03, 0.026, 0.32, sx * (HW + 0.003), TOP + 0.025, -0.69 + i * 0.46), glass)
  end
end

-- The roof rack: sage-green tube rails on posts, crossbars between them, and what is strapped to it -- a surfboard,
-- a bedroll, a suitcase. The signature piece, posts, load and all.
do
  local ry = TOP + ROOF + 0.09
  local rr = 0.02
  local function rack(m, c, a) add(m, c or sage_dk, a, true) end
  for _, sx in ipairs({-1, 1}) do
    local x = sx * 0.46
    rack(rod(v3(x, ry, -0.85), v3(x, ry, 0.72), rr, 6))
    -- the rail's ends bent down to the roof
    rack(rod(v3(x, ry, 0.72), v3(x, TOP + ROOF - 0.02, 0.84), rr, 6))
    rack(rod(v3(x, ry, -0.85), v3(x, TOP + ROOF - 0.02, -0.97), rr, 6))
    for _, z in ipairs({-0.45, 0.0, 0.45}) do rack(rod(v3(x, TOP + ROOF - 0.02, z), v3(x, ry, z), 0.015, 5)) end
  end
  for i = 0, 4 do
    local z = -0.75 + i * 0.35
    rack(rod(v3(-0.46, ry + 0.012, z), v3(0.46, ry + 0.012, z), 0.014, 5))
  end
  local ly = ry + 0.026            -- the load's foot, on the crossbars
  -- the surfboard: orange, a cream stripe down it, its fin up at the tail
  local half = {{0.05, -0.76}, {0.14, -0.6}, {0.175, -0.2}, {0.165, 0.2}, {0.115, 0.52}, {0.05, 0.7}, {0, 0.76}}
  local pts = {}
  for i = 1, #half do pts[#pts + 1] = v2(half[i][1], half[i][2]) end
  for i = #half - 1, 1, -1 do pts[#pts + 1] = v2(-half[i][1], half[i][2]) end
  local board = extrude(poly{points=pts}, {distance=0.036})
  board = turn(board, 180, axis_y())
  local BXc, BZc = -0.2, -0.07
  rack(at(board, BXc, ly, BZc), orange, 30)
  rack(bx(0.06, 0.008, 1.3, BXc, ly + 0.038, BZc - 0.03), cream)
  local fin = turn(plate({{-0.07, 0}, {0.05, 0}, {-0.06, 0.07}}, -0.008, 0.008), -90, axis_y())
  rack(at(fin, BXc, ly + 0.036, BZc - 0.62), yellow)
  for _, z in ipairs({-0.4, 0.3}) do rack(bx(0.36, 0.012, 0.035, BXc, ly + 0.038, BZc + z), dark) end
  -- the bedroll: purple, two yellow straps
  rack(cyl(0.055, 0.44, 0.22, ly + 0.055, -0.5, "z", 10), purple)
  for _, z in ipairs({-0.62, -0.38}) do rack(cyl(0.059, 0.035, 0.22, ly + 0.055, z, "z", 10), yellow) end
  -- the suitcase: brown, cream straps, a handle
  rack(rb(0.36, 0.1, 0.44, 0.2, ly + 0.05, 0.14, 0.018), tin)
  for _, z in ipairs({0.03, 0.25}) do rack(bx(0.368, 0.108, 0.035, 0.2, ly + 0.05, z), cream) end
  rack(rb(0.03, 0.03, 0.12, 0.39, ly + 0.05, 0.14, 0.008), dark)
end

-- The action camera on a post at the roof's front corner.
do
  local cx, cz = 0.3, 0.92
  local y = TOP + ROOF - 0.01
  add(cyl(0.035, 0.02, cx, y + 0.005, cz, "y", 8), dark)
  add(rod(v3(cx, y, cz), v3(cx, y + 0.13, cz), 0.014, 6), dark)
  add(rb(0.1, 0.09, 0.08, cx, y + 0.17, cz, 0.012), dark)
  add(cyl(0.028, 0.03, cx + 0.02, y + 0.17, cz + 0.05, "z", 10), grey)
  add(cyl(0.017, 0.012, cx + 0.02, y + 0.17, cz + 0.068, "z", 8), glass)
  add(bx(0.03, 0.015, 0.03, cx - 0.025, y + 0.222, cz), C(0.7, 0.05, 0.03))
end

-- The nose: a cream V panel on the front, a daisy emblem in a dark ring, round chrome-ringed headlamps, indicators,
-- a mirror on a stalk each side.
local FZ = HL                     -- the tub's front face
do
  add(plate({{-0.47, BELT - 0.02}, {-0.47, 0.2}, {-0.27, -0.02}, {0, -0.25}, {0.27, -0.02}, {0.47, 0.2}, {0.47, BELT - 0.02}},
    FZ - 0.01, FZ + 0.01), cream)
  -- the emblem: a sage disc in a dark ring, a cream daisy on it
  local ez, ey = FZ + 0.01, 0.1
  add(cyl(0.125, 0.02, 0, ey, ez + 0.004, "z", 12), sage_dk)
  add(cyl(0.1, 0.02, 0, ey, ez + 0.01, "z", 12), sage)
  add(at(daisy(0.08)[1], 0, ey, ez + 0.02), cream)
  add(cyl(0.024, 0.016, 0, ey, ez + 0.022, "z", 6), yellow)
  for _, sx in ipairs({-1, 1}) do
    local hx, hy = sx * 0.37, -0.1
    add(cyl(0.125, 0.05, hx, hy, FZ + 0.01, "z", 12), chrome)
    add(cyl(0.095, 0.03, hx, hy, FZ + 0.03, "z", 12), C(1.0, 0.96, 0.78))
    add(sph(0.04, sx * 0.5, 0.2, FZ + 0.005, 8), amber)
    -- the mirror
    local mx, my, mz = sx * 0.632, 0.5, 1.0
    add(rod(v3(sx * (HW - 0.01), 0.16, 0.96), v3(mx, my - 0.03, mz), 0.013, 5), chrome)
    add(cyl(0.056, 0.022, mx, my, mz, "z", 10), chrome)
    add(cyl(0.043, 0.008, mx, my, mz - 0.012, "z", 10), glass)
  end
end

-- The back: tail lamps (amber over red).
local BZ = -HL
for _, sx in ipairs({-1, 1}) do
  add(bx(0.1, 0.085, 0.04, sx * 0.47, 0.07, BZ - 0.01), amber)
  add(bx(0.1, 0.1, 0.04, sx * 0.47, -0.035, BZ - 0.01), red)
end

-- Bumpers: a chrome bar across the front with two overriders, wrapping round the corners (one corner long gone);
-- the back one lost years ago, a scaffold plank roped on in its place.
add(rb(W + 0.04, 0.085, 0.1, 0, -0.33, HL + 0.05, 0.025), chrome)
add(rb(0.075, 0.085, 0.2, HW - 0.015, -0.33, HL - 0.04, 0.025), chrome)
for _, sx in ipairs({-1, 1}) do add(rb(0.05, 0.14, 0.05, sx * 0.3, -0.31, HL + 0.07, 0.015), chrome) end
add(rb(W + 0.1, 0.1, 0.06, 0, -0.33, -(HL + 0.05), 0.012), wood)
for _, sx in ipairs({-1, 1}) do
  for k = 0, 1 do add(cyl(0.06, 0.02, sx * (0.4 + k * 0.03), -0.33, -(HL + 0.05), "x", 6), rope) end
end

-- The side door outline, its handle, and the engine louvres at the back of each side.
for _, sx in ipairs({-1, 1}) do
  local x = sx * (HW + 0.002)
  local z0, z1, y0, y1 = -0.3, 0.3, -0.37, 0.27
  add(bx(0.016, y1 - y0, 0.02, x, (y0 + y1) / 2, z0), sage_dk)
  add(bx(0.016, y1 - y0, 0.02, x, (y0 + y1) / 2, z1), sage_dk)
  add(bx(0.016, 0.02, z1 - z0 + 0.02, x, y1, 0), sage_dk)
  add(rb(0.03, 0.03, 0.12, sx * (HW + 0.012), 0.19, 0.18, 0.008), chrome)
  for i = 0, 3 do add(bx(0.016, 0.024, 0.2, x, 0.05 + i * 0.055, -0.92), sage_dk) end
end

-- Decals: a peace sign and the daisies, built facing +z then turned onto their face.
local function peace(r)
  local ms = {}
  ms[1] = torus{major_radius=r, minor_radius=r * 0.14, major_segments=16, minor_segments=4, axis="z"}
  ms[2] = box{size=v3(r * 0.24, r * 2, 0.012)}
  for _, s in ipairs({-1, 1}) do
    ms[#ms + 1] = turn(translate(box{size=v3(r * 0.22, r, 0.012)}, v3(0, -r / 2, 0)), s * 45, axis_z())
  end
  return ms
end
-- Place a decal: `side` "+x", "-x" or "-z"; (u, y) on that face, u along z for a side, along x for the back.
local function decal(ms, c, side, u, y)
  for _, m in ipairs(ms) do
    local q
    if side == "+x" then q = at(turn(m, 90, axis_y()), HW + 0.004, y, u)
    elseif side == "-x" then q = at(turn(m, -90, axis_y()), -HW - 0.004, y, u)
    else q = at(turn(m, 180, axis_y()), u, y, BZ - 0.004) end
    add(q, c)
  end
end
local function put_daisy(c, side, u, y, r)
  r = r or 0.11
  decal(daisy(r), c, side, u, y)
  decal({cylinder{radius=r * 0.3, height=0.018, segments=6, axis="z"}}, (c == yellow) and orange or yellow, side, u, y)
end
-- u (along the side, forward of the middle), y, colour, radius
local SPOTS = {
  {0.5, 0.14, white, 0.12}, {-0.5, 0.16, yellow, 0.12}, {0.93, 0.02, pink, 0.1}, {-0.68, 0.22, pink, 0.07},
  {0.74, 0.22, yellow, 0.07}, {-1.03, -0.12, white, 0.09}, {0.1, -0.2, purple, 0.08}, {-0.1, 0.1, yellow, 0.08},
}
for i = 1, p.daisies do
  local s = SPOTS[i]
  put_daisy(s[3], "+x", s[1], s[2], s[4])
  put_daisy(s[3], "-x", -s[1], s[2], s[4])
end
decal(peace(0.13), white, "-z", 0, 0.04)
for _, q in ipairs({{-0.3, 0.2, yellow, 0.085}, {0.3, -0.17, pink, 0.1}, {0.27, 0.22, purple, 0.07}, {-0.28, -0.14, white, 0.1}}) do
  put_daisy(q[3], "-z", q[1], q[2], q[4])
end

-- The bodges: tin patches riveted over the rust holes low down the sides and on the nose, duct tape over a cracked
-- arch and a split in the roof, a grey primer panel over the front left corner, and the right side door a
-- hand-brushed blue replacement.
do
  local function patch(w, h, x, y, z, side, c)
    -- A square of tin flat on a side (side = +-1: x faces) or the back/front (side = 0: z faces), rivets at its corners.
    if side == 0 then
      add(bx(w, h, 0.01, x, y, z), c or tin)
      for _, dx in ipairs({-1, 1}) do for _, dy in ipairs({-1, 1}) do
        add(bx(0.022, 0.022, 0.01, x + dx * (w / 2 - 0.025), y + dy * (h / 2 - 0.025), z + (z > 0 and 0.005 or -0.005)), rivet)
      end end
    else
      add(bx(0.01, h, w, x, y, z), c or tin)
      for _, dy in ipairs({-1, 1}) do for _, dz in ipairs({-1, 1}) do
        add(bx(0.01, 0.022, 0.022, x + side * 0.005, y + dy * (h / 2 - 0.025), z + dz * (w / 2 - 0.025)), rivet)
      end end
    end
  end
  patch(0.24, 0.16, HW + 0.006, -0.2, -1.03, 1)
  patch(0.2, 0.14, -(HW + 0.006), -0.12, 0.2, -1)
  patch(0.18, 0.14, -(HW + 0.006), 0.2, -0.3, -1)
  patch(0.2, 0.14, -0.33, -0.2, HL + 0.012, 0)
  -- the front left corner: a primer replacement panel, unpainted
  add(bx(0.01, 0.2, 0.3, -(HW + 0.006), BELT - 0.14, 0.9), primer)
  -- the right side door: a hand-brushed blue replacement over the sage
  add(bx(0.01, 0.62, 0.58, HW + 0.003, -0.05, 0.0), blue)
  -- duct tape: a cross over a crack in the back right arch, a strip along a split in the roof
  local ax, ay, az = HW + 0.03, -0.42 + p.arch + 0.02, -0.7
  for _, a in ipairs({35, -35}) do
    add(at(turn(box{size=v3(0.012, 0.045, 0.24)}, a, axis_x()), ax, ay, az), tape)
  end
  add(bx(0.06, 0.012, 0.5, 0.52, TOP + 0.052, -0.3), tape)
end

-- Inside: a dark bucket seat, a dashboard, the steering column.
add(rbox(0.48, 0.1, 0.44, 0.08, 0, BOT + 0.09, -0.3, 0.02), seat_c)
do
  local m = rb(0.48, 0.66, 0.1, 0, 0, 0, 0.03, 2)
  m = turn(translate(m, v3(0, 0.33, 0)), -8, axis_x())
  add(at(m, 0, -0.24, -0.62), seat_c)
  for _, sx in ipairs({-1, 1}) do
    local b = turn(translate(rb(0.08, 0.4, 0.14, 0, 0, 0, 0.02), v3(0, 0.2, 0)), -8, axis_x())
    add(at(turn(b, sx * 20, axis_y()), sx * 0.22, -0.2, -0.6), seat_c)
  end
end
add(rb(W - 0.16, 0.3, 0.26, 0, 0.12, HL - 0.2, 0.04, 2), seat_c)
add(rod(v3(0, 0.1, 0.15), v3(0, 0.02, HL - 0.32), 0.022, 10), dark)
add(cyl(0.035, 0.05, 0, 0.08, 0.17, "z", 10), dark)

-- Underneath: axle crossbars, stubs to the hubs, two rails.
for _, z in ipairs({-0.7, 0.7}) do
  add(rod(v3(-0.47, -0.42, z), v3(0.47, -0.42, z), 0.03, 10), dark)
  for _, sx in ipairs({-1, 1}) do
    add(rod(v3(sx * 0.46, -0.42, z), v3(sx * 0.535, -0.42, z), 0.02, 10), grey)
    add(cyl(0.036, 0.03, sx * 0.47, -0.42, z, "x", 8), chrome)
  end
end
for _, sx in ipairs({-1, 1}) do add(rb(0.06, 0.05, 2.0, sx * 0.3, -0.445, 0, 0.012), dark) end

part("van", pieces)
