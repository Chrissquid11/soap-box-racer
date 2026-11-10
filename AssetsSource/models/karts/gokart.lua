-- A classic open go-kart for a kart body, one part "gokart". A red nose panel with white edges slopes up from a wide
-- white-and-blue front bumper towards the steering wheel, a white roundel with a red lightning bolt and a blank race
-- number plate on it; chunky side pods striped red, white and blue between the wheels; a black moulded bucket seat;
-- behind it a black engine block, a black tube rear bumper and two big flared black exhaust trumpets with yellow
-- rims, angled up and back. Under it all a black tube frame with its axle crossbars and stubs.
-- In the kart's body space, metres: the origin the middle of the (hidden) chassis box's top, +z forward, y up. The
-- cockpit keeps clear of x +-0.28, z -0.5..0.45 above y -0.2; the wheels (another slot) sit at x +-0.5, z +-0.7,
-- y -0.42, and the steering wheel (another slot) at (0, 0.1, 0.15).
local p = params{
  nose_rise   = { default = 0.0, min = -0.08, max = 0.08, doc = "Height of the nose panel's top by the steering wheel, metres" },
  pod_width   = { default = 0.4, min = 0.3, max = 0.46, doc = "How far the side pods stand out across, metres" },
  seat_back   = { default = 0.6, min = 0.45, max = 0.7, doc = "Height of the bucket seat's back, metres" },
  horn_length = { default = 0.85, min = 0.6, max = 1.0, doc = "Length of the exhaust trumpets, metres" },
  horn_flare  = { default = 0.15, min = 0.1, max = 0.19, doc = "Radius of the trumpets' flared mouths, metres" },
}

local PAINT = material{name="Paint", base_color=v3(1, 1, 1), roughness=0.5, metallic=0}

local function all(m) return faces_where(m, function(_) return true end) end
local function paint(m, c) return paint_faces(m, {faces=all(m), color=c}) end
-- A part of pieces, each { mesh, colour, angle }: merged into one mesh with its colours on its vertices, each piece's
-- normals smoothed up to its angle.
local function part(name, pieces)
  local out = {}
  for i, q in ipairs(pieces) do
    local m = q[2] and paint(q[1], q[2]) or q[1]
    out[i] = {mesh=smooth_normals(m, {angle=q[3] or 35}), material=PAINT}
  end
  local merged = merge({parts=out, mode="compatible"})
  emit(merged[1].mesh, {name=name, material=merged[1].material})
  -- Its wreck, as the same pieces broken: what stays on the kart when the bodywork is knocked off (_wreck.lua).
  -- Its signature piece (a piece marked true, 4th) comes off alone as `<name>_sig` (_sig.lua), the rest to the wreck.
  local rest = include("_sig.lua").split(name, out, function(i) return pieces[i][4] end)
  include("_wreck.lua").emit(name, rest)
end
local function C(r, g, b) return v3(r, g, b) end
local function at(m, x, y, z) return translate(m, v3(x, y, z)) end
-- A box with its edges bevelled.
local function rb(sx, sy, sz, x, y, z, w)
  local m = box{size=v3(sx, sy, sz)}
  return at(bevel(m, {edges=convex_edges(m), width=w or math.min(sx, sy, sz) * 0.2, segments=1}), x, y, z)
end
-- A box with its corners rounded about y, bevelled top and bottom, its base at y.
local function rbox(w, h, d, r, x, y, z, soft)
  local m = extrude(rounded_rect{w=w, h=d, radius=r, segments=4}, {distance=h})
  local edge = 2 * r * math.sin(math.pi / 16)
  m = bevel(m, {edges=convex_edges(m, {min_angle=60}), width=math.min(soft, edge * 0.4, h * 0.22), segments=2})
  return at(m, x, y, z)
end
local function cyl(r, h, x, y, z, axis, seg) return at(cylinder{radius=r, height=h, segments=seg or 14, axis=axis or "y"}, x, y, z) end
local function along(m, a, b)
  local dir = normalize(b - a)
  local c = dot(v3(0, 1, 0), dir)
  if c < -0.9999 then m = rotate(m, {angle=180, axis=axis_x(), pivot=origin()})
  elseif c < 0.9999 then m = rotate(m, {angle=deg(math.acos(c)), axis=normalize(cross(v3(0, 1, 0), dir)), pivot=origin()}) end
  return translate(m, (a + b) * 0.5)
end
-- A round rod from a to b, a hair short of each (two rods meeting end to end must not share a vertex).
local function rod(a0, b0, r, seg)
  local a, b = lerp(a0, b0, 0.004), lerp(a0, b0, 0.996)
  return along(cylinder{radius=r, height=length(b - a), segments=seg or 8}, a, b)
end
-- A square tube from a to b, s across.
local function bar(a0, b0, s)
  local a, b = lerp(a0, b0, 0.002), lerp(a0, b0, 0.998)
  local m = box{size=v3(s, length(b - a), s)}
  local long = edges_where(m, function(e) return math.abs(e.direction.y) > 0.9 end)
  local edges = set_subtract(long, set_subtract(long, convex_edges(m, {min_angle=60})))
  return along(bevel(m, {edges=edges, width=s * 0.18, segments=1}), a, b)
end
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
-- A prism across x from x0 to x1 of an outline of { z, y } points (in order round it).
local function prism(x0, x1, pts)
  local vs, fs = {}, {}
  local n = #pts
  for _, q in ipairs(pts) do vs[#vs + 1] = v3(x0, q[2], q[1]) end
  for _, q in ipairs(pts) do vs[#vs + 1] = v3(x1, q[2], q[1]) end
  local a, b = {}, {}
  for i = 1, n do a[#a + 1] = n + 1 - i; b[#b + 1] = n + i end
  fs[1], fs[2] = a, b
  for i = 1, n do
    local j = i % n + 1
    fs[#fs + 1] = {i, j, n + j, n + i}
  end
  return solid(vs, fs)
end
-- A round solid along +y from 0 up: rings { radius, y } joined in order, the first and last capped.
local function rings(list, seg)
  local vs, fs = {}, {}
  for _, r in ipairs(list) do
    for j = 0, seg - 1 do
      local t = 2 * math.pi * j / seg
      vs[#vs + 1] = v3(r[1] * math.cos(t), r[2], r[1] * math.sin(t))
    end
  end
  local R = #list
  local function id(i, j) return i * seg + (j % seg) + 1 end
  for i = 0, R - 2 do
    for j = 0, seg - 1 do fs[#fs + 1] = {id(i, j), id(i, j + 1), id(i + 1, j + 1), id(i + 1, j)} end
  end
  local a, b = {}, {}
  for j = 0, seg - 1 do a[#a + 1] = id(0, seg - 1 - j); b[#b + 1] = id(R - 1, j) end
  fs[#fs + 1] = a
  fs[#fs + 1] = b
  return solid(vs, fs)
end

local red    = C(0.86, 0.09, 0.09)
local white  = C(0.96, 0.96, 0.94)
local blue   = C(0.08, 0.24, 0.82)
local black  = C(0.05, 0.05, 0.06)
local dark   = C(0.15, 0.15, 0.17)
local grey   = C(0.55, 0.57, 0.6)
local yellow = C(1.0, 0.8, 0.05)

local pieces = {}
local function add(m, c, a, sig) pieces[#pieces + 1] = {m, c, a, sig} end

-- The nose panel: a white wedge sloping up from the bumper to the cockpit, a red one a touch narrower over it.
local NF, NB = 1.24, 0.44           -- its front and back, along z
local YF, YB = -0.30, p.nose_rise   -- its top's height there
local NBOT = -0.44
local slope = (YB - YF) / (NF - NB)
local TH = math.atan(slope)
local function ytop(z) return YF + (NF - z) * slope end
do local m = prism(-0.31, 0.31, {{NF, NBOT}, {NF, YF}, {NB, YB}, {NB, NBOT}}); add(bevel(m, {edges=convex_edges(m), width=0.02, segments=2}), white, 30) end
do local m = prism(-0.235, 0.235, {{NF + 0.008, NBOT + 0.01}, {NF + 0.008, YF + 0.014}, {NB - 0.008, YB + 0.014}, {NB - 0.008, NBOT + 0.01}}); add(bevel(m, {edges=convex_edges(m), width=0.008, segments=1}), red, 30) end
-- Something flat (modelled lying in xz, its face up) laid on the red panel at z, lifted off it by `lift`.
local function onslope(m, z, lift)
  m = rotate(m, {angle=deg(TH), axis=axis_x(), pivot=origin()})
  local n = v3(0, math.cos(TH), math.sin(TH))
  return translate(m, v3(0, ytop(z) + 0.014, z) + n * lift)
end
-- the roundel: a white disc with a red lightning bolt
do
  local z = NB + (NF - NB) * 0.62
  add(onslope(cyl(0.115, 0.012, 0, 0, 0, "y", 24), z, 0.002), white, 30)
  local bolt = poly{points={
    v2(0.022, 0.085), v2(-0.05, -0.008), v2(-0.008, -0.008), v2(-0.026, -0.085), v2(0.05, 0.014), v2(0.008, 0.014),
  }}
  -- the profile lies in xz, extruded up off the disc's top
  local m = scale(extrude(bolt, {distance=0.008}), {factor=1.25, pivot=origin()})
  add(onslope(m, z, 0.007), red, 10)
end
-- the race-number plate: a blue square, a white one inside it (left blank for the number)
do
  local z = NB + (NF - NB) * 0.2
  add(onslope(rb(0.21, 0.01, 0.19, 0, 0, 0, 0.003), z, 0.004), blue, 20)
  add(onslope(rb(0.17, 0.01, 0.15, 0, 0, 0, 0.003), z, 0.008), white, 20)
  -- dashes round the white, as a stitched border
  for i = -3, 3 do
    for _, dz in ipairs({-0.087, 0.087}) do
      add(onslope(translate(box{size=v3(0.012, 0.006, 0.006)}, v3(i * 0.024, 0, 0)), z + dz, 0.011), white, 20)
    end
  end
end

-- The front bumper: wide, white over blue, in front of the front wheels.
-- (the signature piece: it comes off as `gokart_sig`)
add(rbox(1.34, 0.08, 0.19, 0.06, 0, -0.475, 1.32, 0.012), blue, 30, true)
add(rbox(1.36, 0.095, 0.2, 0.07, 0, -0.3975, 1.32, 0.02), white, 30, true)

-- The side pods: chunky stripes, blue under white under red, between the wheels.
for _, sx in ipairs({-1, 1}) do
  local w = p.pod_width
  local x = sx * (0.3 + w * 0.5)
  add(rbox(w - 0.01, 0.095, 0.43, 0.08, x, -0.4725, 0, 0.012), blue, 30)
  add(rbox(w, 0.09, 0.44, 0.085, x, -0.378, 0, 0.012), white, 30)
  add(rbox(w + 0.02, 0.1, 0.46, 0.09, x, -0.29, 0, 0.025), red, 30)
end

-- The bucket seat: black, a cushion under the hips, a moulded back and bolsters curling forward round the driver.
add(rb(0.4, 0.2, 0.34, 0, -0.37, -0.3, 0.02), dark, 20)
add(rbox(0.46, 0.04, 0.42, 0.08, 0, -0.27, -0.27, 0.012), black, 40)
do
  local H = p.seat_back
  local function slab(w, h, t, r, seg, bw)
    local m = extrude(rounded_rect{w=w, h=h, radius=r, segments=seg or 5}, {distance=t, anchor="center"})
    m = rotate(m, {angle=90, axis=axis_x(), pivot=origin()})
    return bevel(m, {edges=convex_edges(m, {min_angle=60}), width=bw or 0.019, segments=2})
  end
  local m = translate(slab(0.5, H, 0.08, 0.13), v3(0, H * 0.5, 0))
  m = rotate(m, {angle=-10, axis=axis_x(), pivot=origin()})
  add(at(m, 0, -0.25, -0.56), black, 40)
  for _, sx in ipairs({-1, 1}) do
    local b = translate(slab(0.1, H * 0.62, 0.12, 0.035, 2, 0.01), v3(0, H * 0.31, 0))
    b = rotate(b, {angle=sx * 28, axis=axis_y(), pivot=origin()})
    b = rotate(b, {angle=-10, axis=axis_x(), pivot=origin()})
    add(at(b, sx * 0.225, -0.25, -0.575), black, 40)
    -- the cushion's side lips
    add(rb(0.06, 0.07, 0.36, sx * 0.25, -0.215, -0.29, 0.02), black, 30)
  end
end

-- The engine block behind the seat, the trumpets standing out of it.
add(rb(0.46, 0.3, 0.3, 0, -0.31, -0.84, 0.03), dark, 20)
add(rb(0.36, 0.05, 0.22, 0, -0.14, -0.84, 0.012), black, 20)
do
  local L, F = p.horn_length, p.horn_flare
  local SEG = 16
  local horn = rings({
    {0.065, 0}, {0.065, 0.05}, {0.055, 0.1}, {0.058, L * 0.45}, {0.072, L * 0.68},
    {F * 0.68, L * 0.86}, {F, L - 0.01}, {F, L}, {F - 0.03, L}, {F * 0.55, L * 0.88}, {0.04, L * 0.7},
  }, SEG)
  local rim = at(torus{major_radius=F - 0.012, minor_radius=0.02, major_segments=24, minor_segments=8, axis="y"}, 0, L, 0)
  local collar = cyl(0.08, 0.06, 0, 0.03, 0, "y", SEG)
  for _, sx in ipairs({-1, 1}) do
    local a = v3(sx * 0.12, -0.14, -0.84)
    local b = a + normalize(v3(sx * 0.12, 0.85, -0.42)) * L
    local function place(m) return along(translate(m, v3(0, -L * 0.5, 0)), a, b) end
    add(place(horn), black, 40)
    add(place(rim), yellow, 50)
    add(place(collar), dark, 40)
  end
end

-- The steering column: from just under the wheel down to the floor pan between the driver's legs.
add(rod(v3(0, 0.08, 0.17), v3(0, -0.46, 0.5), 0.022, 10), dark, 40)
add(cyl(0.035, 0.05, 0, 0.07, 0.18, "y", 10), black, 40)

-- The frame: black tube -- side rails, axle crossbars, the stubs to the hubs, the floor pan, the rear bumper.
do
  local RX, RY, TR = 0.34, -0.46, 0.022
  local function tb(a, b, r) add(rod(a, b, r or TR, 8), black, 40) end
  for _, sx in ipairs({-1, 1}) do
    tb(v3(sx * RX, RY, -1.2), v3(sx * RX, RY, 1.24))
    for _, z in ipairs({-0.7, 0.7}) do
      add(rod(v3(sx * 0.46, -0.42, z), v3(sx * 0.535, -0.42, z), 0.02, 10), grey, 40)
      add(cyl(0.034, 0.03, sx * 0.47, -0.42, z, "x", 8), dark, 40)
    end
    -- the rear bumper's uprights, and braces up from the rails to its top bar
    add(bar(v3(sx * 0.44, -0.47, -1.22), v3(sx * 0.44, -0.2, -1.22), 0.05), black, 20)
    add(bar(v3(sx * 0.16, -0.47, -1.22), v3(sx * 0.16, -0.2, -1.22), 0.04), black, 20)
    add(bar(v3(sx * RX, RY + 0.02, -1.0), v3(sx * 0.3, -0.22, -1.2), 0.04), black, 20)
    -- the side pods' brackets
    tb(v3(sx * RX, RY + 0.01, -0.15), v3(sx * 0.5, -0.47 + 0.005, -0.15), 0.016)
    tb(v3(sx * RX, RY + 0.01, 0.15), v3(sx * 0.5, -0.47 + 0.005, 0.15), 0.016)
  end
  for _, z in ipairs({-0.7, 0.7}) do tb(v3(-0.47, -0.42, z), v3(0.47, -0.42, z), 0.024) end
  tb(v3(-RX, RY, -1.0), v3(RX, RY, -1.0))
  add(bar(v3(-0.5, -0.2, -1.24), v3(0.5, -0.2, -1.24), 0.06), black, 20)
  add(bar(v3(-0.5, -0.45, -1.24), v3(0.5, -0.45, -1.24), 0.05), black, 20)
  -- the floor pan under the driver
  add(rb(0.66, 0.014, 1.0, 0, -0.474, -0.05, 0.004), dark, 20)
end

part("gokart", pieces)
