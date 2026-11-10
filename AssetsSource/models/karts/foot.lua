-- Foot Loose: a giant bare foot for a kart body, one part "foot". The driver sits in the ankle -- a tall column with
-- an arched opening in its front, a red tufted seat inside and a red stitched cuff round its open top -- legs out
-- along a well cut into the instep, the steering wheel ahead of them; five toes with their nails out front; under it a
-- black tube frame. Low-poly and faceted, skin coloured on the vertices.
--
-- In the kart's body space, metres: the origin the middle of the (hidden) chassis box's top, +z forward, y up. The
-- cockpit keeps clear of x ±0.28, z -0.5..0.45 above y -0.2; the wheels (another slot) sit at x ±0.5, z ±0.7, y -0.42.
local p = params{
  ankle_top = { default = 1.0, min = 0.9, max = 1.2, doc = "Height of the ankle column's top, metres" },
  arch_top  = { default = 0.8, min = 0.72, max = 0.9, doc = "Height of the arched opening in the ankle's front, metres" },
  toe_size  = { default = 1, min = 0.8, max = 1.2, doc = "The toes' size, a share of their usual" },
  facets    = { default = 26, min = 18, max = 40, integer = true, doc = "Facets round the foot (fewer, chunkier)" },
}

local PAINT = material{name="Skin", base_color=v3(1, 1, 1), roughness=0.7, metallic=0}

local function all(m) return faces_where(m, function(_) return true end) end
local function paint(m, c) return paint_faces(m, {faces=all(m), color=c}) end
-- A part of pieces, each { mesh, colour, angle }: merged into one mesh with its colours on its vertices, each piece's
-- normals smoothed up to its angle (small: faceted).
local function part(name, pieces)
  local out = {}
  for i, q in ipairs(pieces) do
    local m = q[2] and paint(q[1], q[2]) or q[1]
    out[i] = {mesh=smooth_normals(m, {angle=q[3] or 30}), material=PAINT}
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
local function ball(rx, ry, rz, x, y, z, seg)
  local s = seg or 10
  return at(scale(sphere{radius=1, segments=s, rings=math.floor(s / 2)}, {factor=v3(rx, ry, rz), pivot=origin()}), x, y, z)
end
local function cyl(r, h, x, y, z, axis, seg) return at(cylinder{radius=r, height=h, segments=seg or 12, axis=axis or "y"}, x, y, z) end
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
-- A box with rounded corners about y, bevelled top and bottom, its base at y.
local function rbox(w, h, d, r, x, y, z, soft)
  local m = extrude(rounded_rect{w=w, h=d, radius=r, segments=3}, {distance=h})
  soft = math.min(soft, 2 * r * math.sin(math.pi / 12) * 0.45, h * 0.22)
  m = bevel(m, {edges=convex_edges(m, {min_angle=60}), width=soft, segments=2})
  return at(m, x, y, z)
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
-- A superellipse's point at angle t: exponent n, its radii a (x) and b (the other axis).
local function se(t, n, a, b)
  local c, s = math.cos(t), math.sin(t)
  return a * (c < 0 and -1 or 1) * math.abs(c) ^ (2 / n), b * (s < 0 and -1 or 1) * math.abs(s) ^ (2 / n)
end
local function smooth(e0, e1, x)
  local t = math.max(0, math.min(1, (x - e0) / (e1 - e0)))
  return t * t * (3 - 2 * t)
end

local skin    = C(0.95, 0.68, 0.5)
local skin_dk = C(0.86, 0.58, 0.42)
local nail    = C(0.97, 0.93, 0.84)
local red     = C(0.78, 0.07, 0.09)
local red_dk  = C(0.6, 0.05, 0.07)
local stitch  = C(0.98, 0.95, 0.88)
local black   = C(0.05, 0.05, 0.06)
local grey    = C(0.55, 0.57, 0.6)
local silver  = C(0.8, 0.82, 0.86)

local pieces = {}
local function add(m, c, a, sig) pieces[#pieces + 1] = {m, c, a, sig} end

-- The ankle's place: its middle along z, its outer and inner radii across (x) and along (z).
local AZ = -0.45
local AO, BO = 0.42, 0.34
local AI, BI = 0.33, 0.26
local A0 = -0.3                 -- its foot, buried in the foot
local A1 = p.ankle_top
local FLOOR = -0.27              -- the cockpit well's floor

-- The foot: cross-sections along z (half its width, its bottom, its top), lofted. Over the cockpit -- the ankle's
-- inside and the instep ahead of it -- its top is let down to the well's floor between rims either side.
local SEG = p.facets
do
  local ST = {
    {-0.97, 0.18, -0.4, -0.2},
    {-0.93, 0.33, -0.43, -0.08},
    {-0.82, 0.41, -0.43, 0.0},
    {-0.6, 0.44, -0.43, 0.1},
    {-0.35, 0.45, -0.43, 0.16},
    {-0.1, 0.46, -0.43, 0.18},
    {0.15, 0.48, -0.43, 0.13},
    {0.4, 0.5, -0.43, 0.04},
    {0.6, 0.5, -0.43, -0.04},
    {0.74, 0.47, -0.42, -0.1},
    {0.8, 0.4, -0.4, -0.15},
  }
  local vs, fs = {}, {}
  for _, s in ipairs(ST) do
    local z, w, yb, yt = s[1], s[2], s[3], s[4]
    local mid, h = (yb + yt) * 0.5, (yt - yb) * 0.5
    -- the well: deepest between z -0.72 and 0.4, fading out over 0.1 either end
    local dip = smooth(-0.82, -0.72, z) * (1 - smooth(0.4, 0.5, z))
    for j = 0, SEG - 1 do
      local t = 2 * math.pi * (j + 0.5) / SEG
      local x, y = se(t, 2.8, w, h)
      y = mid + y
      if y > mid and dip > 0 then
        local k = dip * (1 - smooth(0.26, 0.37, math.abs(x)))
        y = y + (FLOOR - y) * k
      end
      -- a gentle sag along the sole's middle, as an arch
      if y < mid then y = y + 0.025 * math.exp(-((z + 0.15) / 0.35) ^ 2) * (1 - math.abs(x) / w) end
      vs[#vs + 1] = v3(x, y, z)
    end
  end
  local R = #ST
  local function id(i, j) return i * SEG + (j % SEG) + 1 end
  for i = 0, R - 2 do
    for j = 0, SEG - 1 do fs[#fs + 1] = {id(i, j), id(i, j + 1), id(i + 1, j + 1), id(i + 1, j)} end
  end
  local a, b = {}, {}
  for j = 0, SEG - 1 do a[#a + 1] = id(0, SEG - 1 - j); b[#b + 1] = id(R - 1, j) end
  fs[#fs + 1] = a
  fs[#fs + 1] = b
  local foot = solid(vs, fs)
  -- the well's floor and walls a little darker, as in shadow
  local well = faces_where(foot, function(f) return f.center.y < -0.2 and math.abs(f.center.x) < 0.34 and f.normal.y > 0.3 end)
  foot = paint(foot, skin)
  if set_count(well) > 0 then foot = paint_faces(foot, {faces=well, color=skin_dk}) end
  pieces[#pieces + 1] = {foot, nil, 28}
end

-- The ankle: a wall round an oval, tapering up, with an arch out of its front from the well up to arch_top.
do
  local N = SEG * 2
  local HALF = 0.95              -- the arch's half-width, radians either side of straight ahead
  local function bottom(t)
    local off = math.abs(math.atan(math.sin(t - math.pi / 2), math.cos(t - math.pi / 2)))
    local u = off / HALF
    if u >= 1 then return A0 end
    return A0 + (p.arch_top - A0) * math.sqrt(1 - u * u)
  end
  local function taper(y) return 1.06 - 0.12 * (y - A0) / (A1 - A0) end
  local function ring(t, y, a, b)
    local x, z = se(t, 2.4, a, b)
    local k = taper(y)
    return v3(x * k, y, AZ + z * k)
  end
  local vs, fs = {}, {}
  for j = 0, N - 1 do
    local t = 2 * math.pi * (j + 0.5) / N
    local yb = bottom(t)
    -- the back a touch higher than the front, as a leg's cut
    local yt = A1 + 0.04 * -math.sin(t)
    vs[#vs + 1] = ring(t, yb, AO, BO)
    vs[#vs + 1] = ring(t, yt, AO, BO)
    vs[#vs + 1] = ring(t, yt, AI, BI)
    vs[#vs + 1] = ring(t, yb, AI, BI)
  end
  local function id(j, k) return (j % N) * 4 + k end
  for j = 0, N - 1 do
    for k = 1, 4 do
      local k2 = k % 4 + 1
      fs[#fs + 1] = {id(j, k), id(j + 1, k), id(j + 1, k2), id(j, k2)}
    end
  end
  add(solid(vs, fs), skin, 28)

  -- The cuff round its open top: a red band, white stitches round it.
  local CN = N
  local cv, cf = {}, {}
  local prof = { {-0.035, -0.012}, {-0.035, 0.03}, {0.09, 0.03}, {0.09, -0.012} }   -- {up, out}
  for j = 0, CN - 1 do
    local t = 2 * math.pi * (j + 0.5) / CN
    local yt = A1 + 0.04 * -math.sin(t)
    local k = taper(yt)
    for _, q in ipairs(prof) do
      local a, b
      if q[2] < 0 then a, b = AI + q[2], BI + q[2] else a, b = AO + q[2], BO + q[2] end
      local x, z = se(t, 2.4, a, b)
      cv[#cv + 1] = v3(x * k, yt + q[1], AZ + z * k)
    end
  end
  local function cid(j, k) return (j % CN) * 4 + k end
  for j = 0, CN - 1 do
    for k = 1, 4 do
      local k2 = k % 4 + 1
      cf[#cf + 1] = {cid(j, k), cid(j + 1, k), cid(j + 1, k2), cid(j, k2)}
    end
  end
  add(solid(cv, cf), red, 50)
  -- the stitches: little dashes along the cuff's outside, every other step
  for j = 0, CN - 1, 2 do
    local t = 2 * math.pi * (j + 0.5) / CN
    local yt = A1 + 0.04 * -math.sin(t)
    local k = taper(yt)
    local x0, z0 = se(t - 0.03, 2.4, AO + 0.033, BO + 0.033)
    local x1, z1 = se(t + 0.03, 2.4, AO + 0.033, BO + 0.033)
    add(rod(v3(x0 * k, yt + 0.028, AZ + z0 * k), v3(x1 * k, yt + 0.028, AZ + z1 * k), 0.007, 4), stitch)
  end
end

-- The seat inside the ankle: a red cushion under the hips and a tufted back of stacked rolls against the back wall.
add(rbox(0.46, 0.05, 0.42, 0.08, 0, FLOOR, -0.32, 0.015), red, 40)
for i = 0, 3 do
  local y = -0.15 + i * 0.16
  local m = rbox(0.46, 0.13, 0.13, 0.05, 0, 0, 0, 0.03)
  m = rotate(m, {angle=-10, axis=axis_x(), pivot=origin()})
  -- (Inside the back wall, never through it.)
  add(at(m, 0, y, -0.55 - i * 0.015), i % 2 == 0 and red or red_dk, 50)
end

-- The toes: five lumps out front, the big one widest, each with its nail on top.
do
  local TOES = {
    {-0.31, 0.155, 0.16, 0.22, 0.85},
    {-0.11, 0.11, 0.135, 0.2, 0.85},
    {0.09, 0.105, 0.13, 0.19, 0.83},
    {0.265, 0.095, 0.12, 0.17, 0.8},
    {0.41, 0.085, 0.11, 0.15, 0.75},
  }
  local s = p.toe_size
  for i, t in ipairs(TOES) do
    local big = i == 1          -- the big toe and its nail: the signature piece
    local x, rx, ry, rz, z = t[1], t[2] * s, t[3] * s, t[4] * s, t[5]
    local y = -0.43 + ry
    add(ball(rx, ry, rz, x, y, z, 10), skin, 30, big)
    -- the nail: a flat oval over the toe's tip, tipped down with it
    local n = ball(rx * 0.62, 0.02, rz * 0.42, 0, 0, 0, 8)
    n = rotate(n, {angle=22, axis=axis_x(), pivot=origin()})
    add(at(n, x, y + ry * 0.88, z + rz * 0.42), nail, 30, big)
  end
end

-- The steering column: from just under the wheel, forward and down to the frame through the well.
add(rod(v3(0, 0.1, 0.15), v3(0, -0.3, 0.5), 0.022, 10), black, 40)
add(cyl(0.035, 0.05, 0, 0.08, 0.17, "y", 10), black, 40)

-- The frame: black tube under the foot -- side rails, axle crossbars, a zigzag truss along each side, axle stubs.
do
  local RX, RY, TR = 0.34, -0.47, 0.022
  local function tb(a, b, r) add(rod(a, b, r or TR, 8), black, 40) end
  for _, sx in ipairs({-1, 1}) do
    tb(v3(sx * RX, RY, -0.95), v3(sx * RX, RY, 0.92))
    tb(v3(sx * 0.4, -0.42, -0.62), v3(sx * 0.4, -0.42, 0.62), 0.016)
    for i = 0, 5 do
      local z0 = -0.6 + i * 0.2
      tb(v3(sx * RX, RY + 0.005, z0), v3(sx * 0.4, -0.425, z0 + 0.2), 0.012)
    end
    for _, z in ipairs({-0.7, 0.7}) do
      add(rod(v3(sx * 0.46, -0.42, z), v3(sx * 0.535, -0.42, z), 0.02, 10), grey, 40)
      add(cyl(0.034, 0.03, sx * 0.47, -0.42, z, "x", 8), silver, 40)
    end
  end
  for _, z in ipairs({-0.7, 0.7}) do tb(v3(-0.47, -0.42, z), v3(0.47, -0.42, z), 0.024) end
  tb(v3(-RX, RY, -0.94), v3(RX, RY, -0.94))
  tb(v3(-RX, RY, 0.9), v3(RX, RY, 0.9))
  -- an X under the middle
  tb(v3(-RX, RY - 0.01, -0.5), v3(RX, RY - 0.015, 0.5), 0.016)
  tb(v3(RX, RY - 0.01, -0.5), v3(-RX, RY - 0.005, 0.5), 0.016)
end

part("foot", pieces)
