-- Kitchen Table Starfighter: a homemade cardboard-and-paint retro space fighter for a kart body, one part
-- "starfighter". A long pointed white nose with orange and teal stripes and a yellow panel, an open cockpit with a
-- dark bucket seat and a little windscreen, a squat engine block behind the driver carrying four stubby engine pods
-- -- two high on pylons, two low on swept delta fins -- each with a fan grille at its back and a laser cannon (a
-- painted cardboard tube) on the low ones; a teapot rides on the block as the co-pilot. Under it a dark tube frame.
--
-- In the kart's body space, metres: the origin the middle of the (hidden) chassis box's top, +z forward, y up. The
-- cockpit keeps clear of x +-0.28, z -0.5..0.45 above y -0.2; the wheels (another slot) sit at x +-0.5, z +-0.7,
-- y -0.42.
local p = params{
  nose_tip      = { default = 1.5, min = 1.3, max = 1.58, doc = "How far forward the nose's point reaches, metres" },
  pod_spread    = { default = 0.66, min = 0.56, max = 0.74, doc = "Across from the middle to the low engine pods, metres" },
  pod_length    = { default = 0.5, min = 0.4, max = 0.6, doc = "Length of each engine pod, metres" },
  cannon_length = { default = 0.75, min = 0.4, max = 0.95, doc = "Length of the laser cannon tubes, metres" },
}

local PAINT = material{name="Paint", base_color=v3(1, 1, 1), roughness=0.6, metallic=0}

local function all(m) return faces_where(m, function(_) return true end) end
local function paint(m, c) return paint_faces(m, {faces=all(m), color=c}) end
local function part(name, pieces)
  local out = {}
  for i, q in ipairs(pieces) do
    local m = q[2] and paint(q[1], q[2]) or q[1]
    out[i] = {mesh=smooth_normals(m, {angle=q[3] or 35}), material=PAINT}
  end
  local merged = merge({parts=out, mode="compatible"})
  emit(merged[1].mesh, {name=name, material=merged[1].material})
  -- Its signature piece (the pieces marked, 4th): `<name>_sig`, and left out of the wreck (_sig.lua).
  local rest = include("_sig.lua").split(name, out, function(i) return pieces[i][4] end)
  -- Its wreck, as the same pieces broken: what stays on the kart when the bodywork is knocked off (_wreck.lua).
  include("_wreck.lua").emit(name, rest)
end
local function C(r, g, b) return v3(r, g, b) end
local function at(m, x, y, z) return translate(m, v3(x, y, z)) end
local function rb(sx, sy, sz, x, y, z, w, seg)
  local m = box{size=v3(sx, sy, sz)}
  return at(bevel(m, {edges=convex_edges(m), width=w or math.min(sx, sy, sz) * 0.2, segments=seg or 1}), x, y, z)
end
local function rbox(w, h, d, r, x, y, z, soft)
  local m = extrude(rounded_rect{w=w, h=d, radius=r, segments=3}, {distance=h})
  soft = math.min(soft, 2 * r * math.sin(math.pi / 12) * 0.45, h * 0.22)
  m = bevel(m, {edges=convex_edges(m, {min_angle=60}), width=soft, segments=2})
  return at(m, x, y, z)
end
local function ball(rx, ry, rz, x, y, z, seg)
  local s = seg or 12
  return at(scale(sphere{radius=1, segments=s, rings=math.floor(s / 2)}, {factor=v3(rx, ry, rz), pivot=origin()}), x, y, z)
end
local function cyl(r, h, x, y, z, axis, seg) return at(cylinder{radius=r, height=h, segments=seg or 14, axis=axis or "y"}, x, y, z) end
local function along(m, a, b)
  local dir = normalize(b - a)
  local c = dot(v3(0, 1, 0), dir)
  if c < -0.9999 then m = rotate(m, {angle=180, axis=axis_x(), pivot=origin()})
  elseif c < 0.9999 then m = rotate(m, {angle=deg(math.acos(c)), axis=normalize(cross(v3(0, 1, 0), dir)), pivot=origin()}) end
  return translate(m, (a + b) * 0.5)
end
local function rod(a0, b0, r, seg)
  local a, b = lerp(a0, b0, 0.004), lerp(a0, b0, 0.996)
  return along(cylinder{radius=r, height=length(b - a), segments=seg or 8}, a, b)
end
-- A square tube from a to b, s across (w across and s deep when w given).
local function bar(a0, b0, s, w)
  local a, b = lerp(a0, b0, 0.002), lerp(a0, b0, 0.998)
  return along(box{size=v3(w or s, length(b - a), s)}, a, b)
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
-- Rings of points (each the same count, in order round), joined in order and capped at both ends.
local function loft_rings(rings)
  local vs, fs = {}, {}
  local n = #rings[1]
  for _, r in ipairs(rings) do for _, v in ipairs(r) do vs[#vs + 1] = v end end
  local function id(i, j) return i * n + (j % n) + 1 end
  for i = 0, #rings - 2 do
    for j = 0, n - 1 do fs[#fs + 1] = {id(i, j), id(i, j + 1), id(i + 1, j + 1), id(i + 1, j)} end
  end
  local a, b = {}, {}
  for j = 0, n - 1 do a[#a + 1] = id(0, n - 1 - j); b[#b + 1] = id(#rings - 1, j) end
  fs[#fs + 1] = a
  fs[#fs + 1] = b
  return solid(vs, fs)
end
-- A painted-on strip: two edges of points on a surface, the strip a thin slab a hair proud of it along `n`.
local function strip(ea, eb, n)
  local rings = {}
  for i = 1, #ea do
    rings[i] = { ea[i] + n * 0.005, eb[i] + n * 0.005, eb[i] - n * 0.012, ea[i] - n * 0.012 }
  end
  return loft_rings(rings)
end

local white   = C(0.95, 0.95, 0.92)
local cream   = C(0.88, 0.87, 0.82)
local orange  = C(0.98, 0.44, 0.08)
local teal    = C(0.04, 0.6, 0.62)
local yellow  = C(0.99, 0.82, 0.12)
local black   = C(0.05, 0.05, 0.06)
local dark    = C(0.16, 0.16, 0.18)
local grey    = C(0.5, 0.52, 0.55)
local silver  = C(0.78, 0.8, 0.84)
local glass   = C(0.3, 0.55, 0.62)
local pot     = C(0.55, 0.78, 0.86)

local pieces = {}
-- While `sig` is true, what is added is the signature piece: the +x high engine pod, flung off when the bodywork goes.
local sig = false
local function add(m, c, a) pieces[#pieces + 1] = {m, c, a, sig} end

-- The nose: six-sided sections (flat sides, a chamfered top) from the cockpit's front out to a point.
local NOSE0 = 0.45
local SECT = {
  -- z share (0 at the cockpit, 1 at the tip), half-width, bottom, top of the sides, top
  {0.0,  0.36, -0.40, -0.02, 0.12},
  {0.33, 0.31, -0.40, -0.07, 0.05},
  {0.66, 0.22, -0.39, -0.14, -0.06},
  {0.92, 0.09, -0.36, -0.24, -0.19},
  {1.0,  0.035, -0.33, -0.28, -0.25},
}
local TIP = p.nose_tip
local function sz(s) return NOSE0 + s[1] * (TIP - NOSE0) end
-- The section at z, interpolated: w, yb, ym, yt.
local function sect(z)
  for i = 1, #SECT - 1 do
    local a, b = SECT[i], SECT[i + 1]
    local za, zb = sz(a), sz(b)
    if z <= zb + 1e-9 then
      local t = math.max(0, math.min(1, (z - za) / (zb - za)))
      return a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] + (b[4] - a[4]) * t, a[5] + (b[5] - a[5]) * t
    end
  end
  local s = SECT[#SECT]
  return s[2], s[3], s[4], s[5]
end
local CH = 0.58      -- the top's share of the width
do
  local rings = {}
  for i, s in ipairs(SECT) do
    local z, w, yb, ym, yt = sz(s), s[2], s[3], s[4], s[5]
    rings[i] = { v3(w, yb, z), v3(w, ym, z), v3(w * CH, yt, z), v3(-w * CH, yt, z), v3(-w, ym, z), v3(-w, yb, z) }
  end
  add(loft_rings(rings), white, 20)
end
-- stations along z from a to b, through every section between
local function stations(a, b, n)
  local zs = {}
  for i = 0, n do zs[#zs + 1] = a + (b - a) * i / n end
  for _, s in ipairs(SECT) do local z = sz(s); if z > a and z < b then zs[#zs + 1] = z end end
  table.sort(zs)
  return zs
end
-- a stripe along the nose's side x = sx * w, between shares t0 and t1 of the side's height
local function side_stripe(sx, z0, z1, t0, t1, c)
  local ea, eb = {}, {}
  for _, z in ipairs(stations(z0, z1, 2)) do
    local w, yb, ym = sect(z)
    ea[#ea + 1] = v3(sx * w, yb + (ym - yb) * t0, z)
    eb[#eb + 1] = v3(sx * w, yb + (ym - yb) * t1, z)
  end
  add(strip(ea, eb, v3(sx, 0, 0)), c, 20)
end
for _, sx in ipairs({-1, 1}) do
  side_stripe(sx, 0.55, 0.45 + (TIP - 0.45) * 0.62, 0.55, 0.82, orange)
  side_stripe(sx, 0.55, 0.45 + (TIP - 0.45) * 0.5, 0.32, 0.42, teal)
end
-- the yellow panel on the nose's top, and a teal one near the cockpit
local function top_panel(z0, z1, s0, s1, c)
  local ea, eb = {}, {}
  for _, z in ipairs(stations(z0, z1, 1)) do
    local w, _, _, yt = sect(z)
    ea[#ea + 1] = v3(s0 * w * CH, yt, z)
    eb[#eb + 1] = v3(s1 * w * CH, yt, z)
  end
  add(strip(ea, eb, v3(0, 1, 0)), c, 20)
end
top_panel(0.45 + (TIP - 0.45) * 0.45, 0.45 + (TIP - 0.45) * 0.7, -0.75, 0.75, yellow)
top_panel(0.62, 0.72, -0.8, -0.2, teal)

-- The windscreen: a tinted slab leaning back off the nose's top at the cockpit, in an orange frame.
do
  local m = rb(0.42, 0.14, 0.02, 0, 0, 0, 0.006)
  m = rotate(m, {angle=-35, axis=axis_x(), pivot=origin()})
  add(at(m, 0, 0.17, 0.5), glass, 20)
  local f = rb(0.46, 0.03, 0.03, 0, 0, 0, 0.008)
  f = rotate(f, {angle=-35, axis=axis_x(), pivot=origin()})
  add(at(f, 0, 0.23, 0.465), orange, 20)
end

-- The cockpit's sides and floor, from the nose back to the engine block.
for _, sx in ipairs({-1, 1}) do
  add(rb(0.06, 0.5, 1.05, sx * 0.33, -0.15, -0.075, 0.015), white, 20)
  -- an orange stripe along each side
  add(rb(0.012, 0.07, 0.95, sx * 0.362, -0.05, -0.08, 0.004), orange, 20)
  add(rb(0.012, 0.03, 0.95, sx * 0.362, -0.13, -0.08, 0.004), teal, 20)
  -- cardboard tabs taped on: grey squares down the side
  for i = 0, 2 do add(rb(0.012, 0.06, 0.06, sx * 0.362, -0.3, -0.45 + i * 0.35, 0.004), cream, 20) end
end
add(rb(0.62, 0.04, 1.05, 0, -0.42, -0.075, 0.01), dark, 20)

-- The seat: a dark bucket, cushion under the hips and a back against the engine block.
add(rbox(0.46, 0.05, 0.4, 0.07, 0, -0.27, -0.3, 0.015), dark, 40)
do
  local m = rb(0.48, 0.6, 0.07, 0, 0.3, 0, 0.02)
  m = rotate(m, {angle=-8, axis=axis_x(), pivot=origin()})
  add(at(m, 0, -0.27, -0.55), dark, 40)
  for _, sx in ipairs({-1, 1}) do
    local b = rb(0.06, 0.4, 0.14, 0, 0.2, 0, 0.015)
    b = rotate(b, {angle=sx * 25, axis=axis_y(), pivot=origin()})
    add(at(b, sx * 0.24, -0.25, -0.5), black, 40)
  end
end

-- The steering column: from under the wheel forward and down into the dash.
add(rod(v3(0, 0.1, 0.15), v3(0, -0.12, 0.5), 0.022, 10), black, 40)
add(cyl(0.035, 0.05, 0, 0.08, 0.17, "y", 10), black, 40)

-- The engine block behind the seat: a bevelled box, an orange band, a dark exhaust panel at its back.
local BZ0, BZ1, BTOP = -0.59, -1.2, 0.3
add(rb(0.74, BTOP + 0.42, BZ0 - BZ1, 0, (BTOP - 0.42) * 0.5, (BZ0 + BZ1) * 0.5, 0.05), white, 20)
add(rb(0.76, 0.07, BZ0 - BZ1 - 0.04, 0, 0.12, (BZ0 + BZ1) * 0.5, 0.01), orange, 20)
add(rb(0.5, 0.36, 0.03, 0, -0.08, BZ1 - 0.005, 0.01), dark, 20)
for i = 0, 3 do add(rb(0.44, 0.03, 0.02, 0, -0.2 + i * 0.08, BZ1 - 0.02, 0.006), grey, 20) end
-- a stubby tail fin on top, at the back
do
  local vs = {
    v3(-0.02, BTOP - 0.02, -0.98), v3(-0.02, BTOP - 0.02, -1.2), v3(-0.02, BTOP + 0.3, -1.22), v3(-0.02, BTOP + 0.3, -1.12),
    v3(0.02, BTOP - 0.02, -0.98), v3(0.02, BTOP - 0.02, -1.2), v3(0.02, BTOP + 0.3, -1.22), v3(0.02, BTOP + 0.3, -1.12),
  }
  add(solid(vs, {{1, 2, 3, 4}, {5, 8, 7, 6}, {1, 5, 6, 2}, {2, 6, 7, 3}, {3, 7, 8, 4}, {4, 8, 5, 1}}), white, 20)
  add(rb(0.05, 0.06, 0.11, 0, BTOP + 0.26, -1.17, 0.01), orange, 20)
end

-- An engine pod along z: a white can, an orange band, a nose cone forward, a dark exhaust ring and a fan grille at
-- its back.
local PL = p.pod_length
local PR = 0.11
local function pod(x, y, zf)
  local zb = zf - PL
  local zc = (zf + zb) * 0.5
  add(cyl(PR, PL - 0.1, x, y, zc + 0.05 - 0.05, "z", 16), white, 40)
  local cn = cone{radius=PR, radius_top=0.05, height=0.12, segments=16, axis="z"}
  add(at(cn, x, y, zf - 0.04 + 0.0), white, 40)
  add(cyl(PR + 0.008, 0.06, x, y, zf - 0.13, "z", 16), orange, 40)
  add(cyl(PR + 0.014, 0.08, x, y, zb + 0.05, "z", 16), grey, 40)
  -- the fan: a dark disc, a hub and blades across it
  add(cyl(PR - 0.008, 0.02, x, y, zb, "z", 16), black, 40)
  add(cyl(0.03, 0.04, x, y, zb - 0.01, "z", 10), silver, 40)
  for k = 0, 3 do
    local bl = box{size=v3(0.19, 0.022, 0.012)}
    bl = rotate(bl, {angle=k * 45 + 22.5, axis=axis_z(), pivot=origin()})
    add(at(bl, x, y, zb - 0.014), grey, 40)
  end
end
local PZF = -0.66
local LX, LY = p.pod_spread, 0.17
local UX, UY = 0.4, 0.52
for _, sx in ipairs({-1, 1}) do
  sig = sx > 0
  pod(sx * UX, UY, PZF - 0.04)
  sig = false
  pod(sx * LX, LY, PZF)
  -- pylons from the block's top to the high pods
  add(bar(v3(sx * 0.22, BTOP - 0.02, -0.82), v3(sx * UX, UY, -0.82), 0.04, 0.18), white, 20)
  add(bar(v3(sx * 0.22, BTOP - 0.02, -1.0), v3(sx * UX, UY, -1.0), 0.04, 0.14), white, 20)
  -- the swept delta fin from the block's side out under the low pod
  do
    local x0, x1 = sx * 0.37, sx * (LX + 0.16)
    local zr0, zr1 = -0.3, -1.18
    local zt0, zt1 = PZF - PL * 0.65, PZF - PL - 0.04
    local y0, y1 = 0.06, LY - PR + 0.01
    local vs = {
      v3(x0, y0 - 0.02, zr0), v3(x0, y0 - 0.02, zr1), v3(x1, y1 - 0.02, zt1), v3(x1, y1 - 0.02, zt0),
      v3(x0, y0 + 0.02, zr0), v3(x0, y0 + 0.02, zr1), v3(x1, y1 + 0.02, zt1), v3(x1, y1 + 0.02, zt0),
    }
    add(solid(vs, {{1, 2, 3, 4}, {5, 8, 7, 6}, {1, 5, 6, 2}, {2, 6, 7, 3}, {3, 7, 8, 4}, {4, 8, 5, 1}}), white, 20)
    -- a teal chevron painted on its top
    local function fp(u, v) -- u along the root-to-tip, v front-to-back share
      local zr = zr0 + (zr1 - zr0) * v
      local zt = zt0 + (zt1 - zt0) * v
      return v3(x0 + (x1 - x0) * u, y0 + (y1 - y0) * u + 0.02, zr + (zt - zr) * u)
    end
    local n = normalize(cross(fp(1, 0) - fp(0, 0), fp(0, 1) - fp(0, 0)))
    if n.y < 0 then n = v3(-n.x, -n.y, -n.z) end
    add(strip({fp(0.2, 0.55), fp(0.8, 0.55)}, {fp(0.2, 0.75), fp(0.8, 0.75)}, n), teal, 20)
  end
  -- the laser cannon on the low pod's outside: a tube forward, an orange muzzle, a red tip
  do
    local cx, cy = sx * (LX + PR + 0.03), LY
    local z0, z1 = PZF - PL + 0.1, PZF - PL + 0.1 + p.cannon_length + 0.25
    add(rb(0.05, 0.05, 0.22, sx * (LX + PR + 0.0), LY, PZF - 0.2, 0.01), grey, 20)
    add(rod(v3(cx, cy, z0), v3(cx, cy, z1), 0.022, 10), cream, 40)
    add(rod(v3(cx, cy, z1 - 0.02), v3(cx, cy, z1 + 0.09), 0.032, 10), orange, 40)
    add(rod(v3(cx, cy, z1 + 0.09), v3(cx, cy, z1 + 0.13), 0.014, 8), C(0.85, 0.1, 0.08), 40)
    add(rod(v3(cx, cy, z1 - 0.3), v3(cx, cy, z1 - 0.25), 0.03, 10), orange, 40)
  end
  -- short cannons on the high pods
  do
    local cx, cy = sx * (UX + 0.0), UY + PR + 0.02
    sig = sx > 0
    add(rod(v3(cx, cy, PZF - 0.2), v3(cx, cy, PZF + 0.18), 0.018, 8), cream, 40)
    add(rod(v3(cx, cy, PZF + 0.12), v3(cx, cy, PZF + 0.2), 0.026, 8), orange, 40)
    sig = false
  end
end

-- The co-pilot: a teapot on the block, its spout out front like a periscope, a teal band and a white lid.
do
  local tz, ty = -0.86, BTOP + 0.11
  add(ball(0.15, 0.12, 0.15, 0, ty, tz, 16), pot, 45)
  add(cyl(0.152, 0.03, 0, ty + 0.0, tz, "y", 16), teal, 45)
  add(cyl(0.09, 0.03, 0, BTOP + 0.01, tz, "y", 14), pot, 45)
  add(cyl(0.085, 0.03, 0, ty + 0.12, tz, "y", 14), white, 45)
  add(ball(0.03, 0.03, 0.03, 0, ty + 0.155, tz, 8), teal, 45)
  add(sweep(circle{radius=0.028, segments=8}, path{points={v3(0, ty - 0.02, tz + 0.11), v3(0, ty + 0.03, tz + 0.19), v3(0, ty + 0.1, tz + 0.23)}}, {caps=true, scale=0.7}), pot, 45)
  local h = torus{major_radius=0.065, minor_radius=0.018, major_segments=14, minor_segments=6, axis="x"}
  add(at(h, 0, ty + 0.01, tz - 0.15), pot, 45)
  -- two little black dots for eyes, looking forward
  for _, sx in ipairs({-1, 1}) do add(ball(0.018, 0.022, 0.012, sx * 0.05, ty + 0.05, tz + 0.135, 8), black, 45) end
end

-- The frame: dark tube under it all -- side rails, axle crossbars and stubs.
do
  local RX, RY, TR = 0.26, -0.47, 0.022
  local function tb(a, b, r) add(rod(a, b, r or TR, 8), dark, 40) end
  for _, sx in ipairs({-1, 1}) do
    tb(v3(sx * RX, RY, -1.15), v3(sx * RX, RY, 1.0))
    tb(v3(sx * RX, RY + 0.005, 0.5), v3(sx * 0.47, -0.425, 0.7), 0.014)
    tb(v3(sx * RX, RY + 0.005, -0.5), v3(sx * 0.47, -0.425, -0.7), 0.014)
    for _, z in ipairs({-0.7, 0.7}) do
      add(rod(v3(sx * 0.46, -0.42, z), v3(sx * 0.535, -0.42, z), 0.02, 10), grey, 40)
      add(cyl(0.034, 0.03, sx * 0.47, -0.42, z, "x", 8), silver, 40)
    end
  end
  for _, z in ipairs({-0.7, 0.7}) do tb(v3(-0.47, -0.42, z), v3(0.47, -0.42, z), 0.024) end
  tb(v3(-RX, RY, -1.14), v3(RX, RY, -1.14))
  tb(v3(-RX, RY, 0.98), v3(RX, RY, 0.98))
end

part("starfighter", pieces)
