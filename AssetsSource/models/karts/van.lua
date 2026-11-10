-- Flower Power: a retro split-window camper van for a kart body, one part "van". A sage-green lower tub with wheel
-- arches, a cream window band of open windows and a split windscreen, a cream roof with skylights, a roof rack and a
-- little action camera; a cream V nose panel with a daisy emblem, round chrome-ringed headlamps, chrome bumpers, a
-- side door outline, engine louvres, and painted daisies and peace signs. The driver sits on a dark bucket seat in the
-- middle of the van, legs forward to the dashboard.
--
-- In the kart's body space, metres: the origin the middle of the (hidden) chassis box's top, +z forward, y up. The
-- cockpit keeps clear of x ±0.28, z -0.5..0.45 above y -0.2; the wheels (another slot) sit at x ±0.5, z ±0.7, y -0.42.
local p = params{
  roof_height = { default = 1.0, min = 0.95, max = 1.12, doc = "Height of the window band's top (the roof's foot), metres" },
  windows     = { default = 4, min = 3, max = 5, integer = true, doc = "Open windows along each side" },
  arch        = { default = 0.36, min = 0.3, max = 0.4, doc = "Wheel arch radius, metres" },
  daisies     = { default = 6, min = 0, max = 8, integer = true, doc = "Painted daisies on each side" },
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
  local m = extrude(rounded_rect{w=w, h=d, radius=r, segments=4}, {distance=h})
  if soft then
    local edge = 2 * r * math.sin(math.pi / 16)
    for _, side in ipairs({w - 2 * r, d - 2 * r}) do if side > 0.001 then edge = math.min(edge, side) end end
    m = bevel(m, {edges=convex_edges(m, {min_angle=60}), width=math.min(soft, edge * 0.4, h * 0.22), segments=2})
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

local sage    = C(0.24, 0.41, 0.27)
local sage_dk = C(0.12, 0.24, 0.15)
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

local W, L = 1.24, 2.3             -- the tub's width and length
local HW, HL = W / 2, L / 2
local BOT, BELT = -0.42, 0.33      -- the tub's bottom and top
local TOP = p.roof_height

-- The lower tub: sage, hollow, its floor 0.1 thick, wheel arches cut from its sides.
do
  local outer = rbox(W, BELT - BOT, L, 0.15, 0, BOT, 0, 0.05)
  local inner = rbox(W - 0.12, 1.0, L - 0.12, 0.1, 0, BOT + 0.1, 0)
  local cuts = {inner}
  for _, sx in ipairs({-1, 1}) do
    for _, z in ipairs({-0.7, 0.7}) do cuts[#cuts + 1] = cyl(p.arch, 0.4, sx * 0.62, -0.42, z, "x", 20) end
  end
  add(subtract(outer, table.unpack(cuts)), sage)
  -- the arches' lips: a dark half ring round each
  for _, sx in ipairs({-1, 1}) do
    for _, z in ipairs({-0.7, 0.7}) do
      local ring = torus{major_radius=p.arch + 0.012, minor_radius=0.018, major_segments=24, minor_segments=6, axis="x"}
      ring = subtract(ring, bx(0.2, 1, 1.2, 0, -0.5, 0))
      add(at(ring, sx * (HW - 0.005), -0.42, z), sage_dk)
    end
  end
end

-- The window band: cream, open windows down each side, a split windscreen in front and a window at the back.
do
  local outer = rbox(W - 0.03, TOP + 0.02 - (BELT - 0.02), L - 0.03, 0.14, 0, BELT - 0.02, 0)
  local inner = rbox(W - 0.13, 2, L - 0.13, 0.09, 0, BELT - 0.5, 0)
  local cuts = {inner}
  local y0, y1 = BELT + 0.1, TOP - 0.08
  local ym, h = (y0 + y1) / 2, y1 - y0
  local n = p.windows
  local zA, zB, post = -0.95, 0.84, 0.08
  local ww = (zB - zA - post * (n - 1)) / n
  for i = 0, n - 1 do
    local zc = zA + ww / 2 + i * (ww + post)
    cuts[#cuts + 1] = bx(W + 0.2, h, ww, 0, ym, zc)
  end
  -- the split windscreen, its centre post 0.08 wide
  for _, sx in ipairs({-1, 1}) do cuts[#cuts + 1] = bx(0.44, h, 0.4, sx * 0.27, ym, HL) end
  cuts[#cuts + 1] = bx(0.8, h * 0.82, 0.4, 0, ym + h * 0.06, -HL)
  add(subtract(outer, table.unpack(cuts)), cream)
end

-- The roof: cream, rounded, a little visor over the windscreen; skylights along its shoulders.
add(rbox(W + 0.02, 0.22, L + 0.04, 0.18, 0, TOP, 0.02, 0.07), cream)
for _, sx in ipairs({-1, 1}) do
  for i = 0, 3 do
    local z = -0.72 + i * 0.44
    add(rb(0.03, 0.065, 0.3, sx * (HW + 0.002), TOP + 0.1, z, 0.008), glass)
    add(rb(0.024, 0.085, 0.34, sx * (HW - 0.004), TOP + 0.1, z, 0.008), cream_dk)
  end
end

-- The roof rack: sage-green tube rails on posts, crossbars between them. The signature piece, posts and all.
do
  local ry = TOP + 0.31
  local rr = 0.018
  local function rack(m) add(m, sage_dk, nil, true) end
  for _, sx in ipairs({-1, 1}) do
    local x = sx * 0.46
    rack(rod(v3(x, ry, -0.85), v3(x, ry, 0.72), rr, 8))
    -- the rail's ends bent down to the roof
    rack(rod(v3(x, ry, 0.72), v3(x, TOP + 0.2, 0.84), rr, 8))
    rack(rod(v3(x, ry, -0.85), v3(x, TOP + 0.2, -0.97), rr, 8))
    for _, z in ipairs({-0.45, 0.0, 0.45}) do rack(rod(v3(x, TOP + 0.2, z), v3(x, ry, z), 0.014, 6)) end
  end
  for i = 0, 5 do
    local z = -0.75 + i * 0.29
    rack(rod(v3(-0.46, ry + 0.012, z), v3(0.46, ry + 0.012, z), 0.013, 6))
  end
end

-- The action camera on a post at the roof's front corner.
do
  local cx, cz = 0.3, 0.92
  local y = TOP + 0.21
  add(cyl(0.035, 0.02, cx, y + 0.005, cz, "y", 10), dark)
  add(rod(v3(cx, y, cz), v3(cx, y + 0.13, cz), 0.014, 8), dark)
  add(rb(0.1, 0.09, 0.08, cx, y + 0.17, cz, 0.012), dark)
  add(cyl(0.028, 0.03, cx + 0.02, y + 0.17, cz + 0.05, "z", 12), grey)
  add(cyl(0.017, 0.012, cx + 0.02, y + 0.17, cz + 0.068, "z", 10), glass)
  add(rb(0.03, 0.015, 0.03, cx - 0.025, y + 0.222, cz, 0.004), C(0.7, 0.05, 0.03))
end

-- The nose: a cream V panel on the front, a daisy emblem in a dark ring, round chrome-ringed headlamps, indicators.
local FZ = HL                     -- the tub's front face
do
  add(plate({{-0.47, BELT - 0.04}, {-0.47, 0.16}, {0, -0.2}, {0.47, 0.16}, {0.47, BELT - 0.04}}, FZ - 0.01, FZ + 0.008), cream)
  -- the emblem: a sage disc in a dark ring, a cream daisy on it
  local ez, ey = FZ + 0.008, 0.09
  add(cyl(0.11, 0.02, 0, ey, ez + 0.006, "z", 24), sage)
  local ring = torus{major_radius=0.11, minor_radius=0.014, major_segments=24, minor_segments=6, axis="z"}
  add(at(ring, 0, ey, ez + 0.01), sage_dk)
  for i = 0, 5 do
    local a = i * 60
    local pt = translate(petal(0.03, 0.016, 0.012), v3(0.047, 0, 0))
    pt = turn(pt, a, axis_z())
    add(at(pt, 0, ey, ez + 0.022), cream)
  end
  add(cyl(0.022, 0.016, 0, ey, ez + 0.026, "z", 12), yellow)
  for _, sx in ipairs({-1, 1}) do
    local hx, hy = sx * 0.38, -0.08
    add(cyl(0.115, 0.05, hx, hy, FZ + 0.01, "z", 20), chrome)
    -- the lens: a shallow dome, a big sphere's cap standing proud of the ring
    add(sph(0.14, hx, hy, FZ + 0.035 - 0.105, 16), white)
    add(sph(0.035, sx * 0.5, 0.22, FZ + 0.005, 10), amber)
  end
end

-- The back: tail lamps (amber over red) and a peace sign.
local BZ = -HL
for _, sx in ipairs({-1, 1}) do
  add(rb(0.09, 0.08, 0.04, sx * 0.47, 0.06, BZ - 0.01, 0.012), amber)
  add(rb(0.09, 0.09, 0.04, sx * 0.47, -0.035, BZ - 0.01, 0.012), red)
end

-- Bumpers: a chrome bar across the front, wrapping round the corners (one corner long gone); the back one lost
-- years ago, a scaffold plank roped on in its place.
add(rb(W + 0.04, 0.075, 0.1, 0, -0.33, HL + 0.05, 0.025, 2), chrome)
add(rb(0.075, 0.075, 0.2, HW - 0.015, -0.33, HL - 0.04, 0.025, 2), chrome)
add(rb(W + 0.1, 0.1, 0.06, 0, -0.33, -(HL + 0.05), 0.012), wood)
for _, sx in ipairs({-1, 1}) do
  for k = 0, 2 do add(cyl(0.058, 0.014, sx * (0.4 + k * 0.02), -0.33, -(HL + 0.05), "x", 10), rope) end
end

-- The side door outline, its handle, and the engine louvres at the back of each side.
for _, sx in ipairs({-1, 1}) do
  local x = sx * (HW + 0.002)
  local z0, z1, y0, y1 = -0.3, 0.3, -0.37, 0.27
  add(bx(0.016, y1 - y0, 0.016, x, (y0 + y1) / 2, z0), sage_dk)
  add(bx(0.016, y1 - y0, 0.016, x, (y0 + y1) / 2, z1), sage_dk)
  add(bx(0.016, 0.016, z1 - z0 + 0.016, x, y1, 0), sage_dk)
  add(rb(0.03, 0.025, 0.11, sx * (HW + 0.01), 0.19, 0.18, 0.008), grey)
  for i = 0, 4 do add(rb(0.016, 0.018, 0.2, x, 0.04 + i * 0.045, -0.88, 0.005), sage_dk) end
end

-- Decals: daisies (petals round a yellow eye) and peace signs, built facing +z then turned onto their face.
local function daisy(c)
  local ms = {}
  for i = 0, 5 do
    ms[#ms + 1] = turn(translate(petal(0.04, 0.022, 0.01, 6), v3(0.056, 0, 0)), i * 60 + 15, axis_z())
  end
  return ms, c
end
local function peace()
  local ms = {}
  ms[1] = torus{major_radius=0.075, minor_radius=0.011, major_segments=18, minor_segments=4, axis="z"}
  ms[2] = box{size=v3(0.018, 0.15, 0.012)}
  for _, s in ipairs({-1, 1}) do
    ms[#ms + 1] = turn(translate(box{size=v3(0.016, 0.075, 0.012)}, v3(0, -0.0375, 0)), s * 45, axis_z())
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
local function put_daisy(c, side, u, y)
  local ms = daisy()
  decal(ms, c, side, u, y)
  decal({cylinder{radius=0.024, height=0.016, segments=8, axis="z"}}, (c == yellow) and amber or yellow, side, u, y)
end
local SPOTS = {
  {0.9, 0.18, white}, {0.52, 0.02, yellow}, {0.63, 0.24, purple}, {-0.5, 0.17, yellow},
  {-0.47, -0.08, pink}, {0.14, 0.12, pink}, {-0.15, -0.22, yellow}, {0.95, -0.03, purple},
}
for i = 1, p.daisies do
  local s = SPOTS[i]
  put_daisy(s[3], "+x", s[1], s[2])
  put_daisy(s[3], "-x", -s[1], s[2])
end
decal(peace(), white, "+x", -0.1, -0.05)
decal(peace(), white, "-x", 0.1, -0.05)
decal(peace(), white, "-z", 0, -0.05)
for _, q in ipairs({{-0.25, 0.2, yellow}, {0.25, -0.2, pink}, {0.22, 0.2, purple}, {-0.24, -0.22, white}}) do
  put_daisy(q[3], "-z", q[1], q[2])
end

-- The bodges: tin patches riveted over the rust holes low down the sides and on the nose, duct tape over a cracked
-- arch and a split in the roof, a grey primer panel over the front left corner, and the right side door a
-- hand-brushed blue replacement.
do
  local function patch(w, h, x, y, z, side, c)
    -- A square of tin flat on a side (side = +-1: x faces) or the back/front (side = 0: z faces), rivets at its corners.
    if side == 0 then
      add(rb(w, h, 0.008, x, y, z, 0.003), c or tin)
      for _, dx in ipairs({-1, 1}) do for _, dy in ipairs({-1, 1}) do
        add(sph(0.011, x + dx * (w / 2 - 0.02), y + dy * (h / 2 - 0.02), z + (z > 0 and 0.005 or -0.005), 6), rivet)
      end end
    else
      add(rb(0.008, h, w, x, y, z, 0.003), c or tin)
      for _, dy in ipairs({-1, 1}) do for _, dz in ipairs({-1, 1}) do
        add(sph(0.011, x + side * 0.005, y + dy * (h / 2 - 0.02), z + dz * (w / 2 - 0.02), 6), rivet)
      end end
    end
  end
  patch(0.26, 0.14, HW + 0.006, 0.12, -1.0, 1)
  patch(0.18, 0.12, -(HW + 0.006), -0.1, 0.32, -1)
  patch(0.16, 0.12, -(HW + 0.006), 0.18, -1.0, -1)
  patch(0.2, 0.14, -0.3, -0.18, HL + 0.006, 0)
  -- the front left corner: a primer replacement panel, unpainted
  add(rb(0.008, 0.24, 0.42, -(HW + 0.006), BELT - 0.15, 0.84, 0.003), primer)
  -- the right side door: a hand-brushed blue replacement over the sage
  add(rb(0.008, 0.6, 0.58, HW + 0.008, -0.05, 0.0, 0.003), blue)
  -- duct tape: a cross over a crack in the back right arch, a strip along a split in the roof
  local ax, ay, az = HW + 0.025, -0.42 + p.arch + 0.02, -0.7
  for _, a in ipairs({35, -35}) do
    add(turn(rb(0.012, 0.035, 0.22, 0, 0, 0, 0.004), a, axis_x()), tape)
    pieces[#pieces][1] = at(pieces[#pieces][1], ax, ay, az)
  end
  add(rb(0.05, 0.012, 0.8, 0.3, TOP + 0.006, -0.3, 0.004), tape)
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
