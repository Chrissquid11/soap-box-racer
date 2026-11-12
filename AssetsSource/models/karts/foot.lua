-- Foot Loose: a giant severed bare foot for a kart body, one part "foot". The driver sits in the ankle -- a tall
-- column flaring into the heel, a rounded opening in its front, a black padded seat inside -- legs out along a well cut
-- into the instep, the steering column ahead of them. The ankle's cut top has a dark-red rim, painted blood running
-- down from it in drips, and an ivory bone standing out of the flesh; five fat toes with cream nails make the nose
-- (the big one on the kart's right: the signature piece, which rolls off). Peach skin, a touch uneven, with a couple
-- of faint seams and a silver tape repair by the heel; under it a navy tube frame, silver bolts at its joints.
-- Colours on the vertices. No wheels and no steering wheel: the game draws those.
--
-- In the kart's body space, metres: the origin the middle of the (hidden) chassis box's top, +z forward, y up, +x the
-- kart's left. The cockpit keeps clear of x ±0.28, z -0.5..0.45 above y -0.2; the wheels (another slot) sit at
-- x ±0.5, z ±0.7, y -0.42.
local p = params{
  ankle_top = { default = 1.0, min = 0.9, max = 1.1, doc = "Height of the ankle's cut top, metres" },
  arch_top  = { default = 0.78, min = 0.7, max = 0.84, doc = "Height of the opening in the ankle's front, metres" },
  toe_size  = { default = 1, min = 0.8, max = 1.1, doc = "The toes' size, a share of their usual" },
  facets    = { default = 26, min = 18, max = 40, integer = true, doc = "Facets round the foot (fewer, chunkier)" },
  drips     = { default = 11, min = 0, max = 16, integer = true, doc = "Blood drips down the ankle" },
  bone      = { default = 0.17, min = 0.08, max = 0.2, doc = "How far the bone stands out of the ankle, metres" },
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
  local sig = include("_sig.lua")
  local rest, sb = sig.split(name, out, function(i) return pieces[i][4] end)
  sig.box(name, sb)
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

local skin    = C(0.96, 0.66, 0.5)
local skin_dk = C(0.86, 0.55, 0.41)
local seam    = C(0.8, 0.5, 0.38)
local nail    = C(0.97, 0.9, 0.76)
local red     = C(0.62, 0.05, 0.07)
local red_dk  = C(0.4, 0.03, 0.05)
local ivory   = C(0.95, 0.9, 0.76)
local black   = C(0.06, 0.06, 0.07)
local black2  = C(0.1, 0.1, 0.115)
local navy    = C(0.07, 0.11, 0.27)
local silver  = C(0.78, 0.8, 0.84)
local tape    = C(0.7, 0.72, 0.76)

local pieces = {}
local function add(m, c, a, sig) pieces[#pieces + 1] = {m, c, a, sig} end

-- A band: rings of the same count of points joined each to the next (and the last to the first when closed, else
-- capped), each ring a closed profile.
local function band(rings, closed)
  local K = #rings[1]
  local vs, fs = {}, {}
  for _, r in ipairs(rings) do for _, v in ipairs(r) do vs[#vs + 1] = v end end
  local R = #rings
  local function id(i, k) return ((i - 1) % R) * K + ((k - 1) % K) + 1 end
  for i = 1, closed and R or R - 1 do
    for k = 1, K do fs[#fs + 1] = {id(i, k), id(i + 1, k), id(i + 1, k + 1), id(i, k + 1)} end
  end
  if not closed then
    local a, b = {}, {}
    for k = 1, K do a[k] = id(1, k); b[k] = id(R, K + 1 - k) end
    fs[#fs + 1] = a
    fs[#fs + 1] = b
  end
  return solid(vs, fs)
end

-- The ankle's place: its middle along z, its outer and inner radii across (x) and along (z).
local AZ = -0.45
local AO, BO = 0.42, 0.34
local AI, BI = 0.33, 0.26
local A0 = -0.3                 -- its foot, buried in the foot
local A1 = p.ankle_top
local FLOOR = -0.27              -- the cockpit well's floor
local SEG = p.facets

-- The foot: stations along z (half its width, its bottom, its top), a smooth curve through them.
local ST = {
  {-0.97, 0.17, -0.2, -0.02},
  {-0.94, 0.31, -0.31, 0.1},
  {-0.86, 0.42, -0.36, 0.21},
  {-0.6, 0.46, -0.37, 0.26},
  {-0.35, 0.47, -0.37, 0.12},
  {-0.1, 0.47, -0.37, 0.05},
  {0.15, 0.48, -0.37, 0.04},
  {0.4, 0.495, -0.37, 0.02},
  {0.58, 0.5, -0.37, 0.0},
  {0.7, 0.49, -0.36, -0.02},
  {0.78, 0.44, -0.35, -0.06},
}
local function station(z)
  local n = #ST
  local i = 1
  while i < n - 1 and z > ST[i + 1][1] do i = i + 1 end
  local a, b = ST[i], ST[i + 1]
  local d = b[1] - a[1]
  local t = math.max(0, math.min(1, (z - a[1]) / d))
  local out = {}
  for k = 2, 4 do
    local pa, nb = ST[math.max(1, i - 1)], ST[math.min(n, i + 2)]
    local m0 = (b[k] - pa[k]) / (b[1] - pa[1]) * d
    local m1 = (nb[k] - a[k]) / (nb[1] - a[1]) * d
    local t2, t3 = t * t, t * t * t
    out[k] = (2 * t3 - 3 * t2 + 1) * a[k] + (t3 - 2 * t2 + t) * m0 + (-2 * t3 + 3 * t2) * b[k] + (t3 - t2) * m1
  end
  return out[2], out[3], out[4]
end
-- A point of its skin: at z, at angle t round its section (0 the kart's left, a quarter turn the top), grown by `out`.
-- Over the cockpit -- the ankle's inside and the instep ahead of it -- its top is let down to the well's floor between
-- rims either side; a little uneven all over, as handmade.
local function skin_at(z, t, out)
  local w, yb, yt = station(z)
  local mid, h = (yb + yt) * 0.5, (yt - yb) * 0.5
  local lump = 1 + 0.014 * math.sin(z * 9.1 + t * 2.0) * math.cos(z * 5.3 - t * 3.0)
  local x, y = se(t, 2.8, (w + (out or 0)) * lump, (h + (out or 0)) * lump)
  y = mid + y
  local dip = smooth(-0.84, -0.72, z) * (1 - smooth(0.4, 0.5, z))
  if y > mid and dip > 0 then
    local k = dip * (1 - smooth(0.27, 0.38, math.abs(x)))
    y = y + (FLOOR - y) * k
  end
  -- a gentle sag along the sole's middle, as an arch
  if y < mid then y = y + 0.025 * math.exp(-((z + 0.15) / 0.35) ^ 2) * (1 - math.abs(x) / w) end
  return v3(x, y, z)
end
do
  local zs = {}
  for i = 1, #ST - 1 do
    zs[#zs + 1] = ST[i][1]
    zs[#zs + 1] = (ST[i][1] + ST[i + 1][1]) * 0.5
  end
  zs[#zs + 1] = ST[#ST][1]
  local rings = {}
  for i, z in ipairs(zs) do
    local r = {}
    for j = 0, SEG - 1 do r[#r + 1] = skin_at(z, 2 * math.pi * (j + 0.5) / SEG) end
    rings[i] = r
  end
  local foot = band(rings, false)
  -- the well's floor and walls a little darker, as in shadow
  local well = faces_where(foot, function(f) return f.center.y < -0.2 and math.abs(f.center.x) < 0.34 and f.normal.y > 0.3 end)
  foot = paint(foot, skin)
  if set_count(well) > 0 then foot = paint_faces(foot, {faces=well, color=skin_dk}) end
  pieces[#pieces + 1] = {foot, nil, 40}

  -- A faint seam round the forefoot, behind the toes: a thin raised band on the skin.
  local sr = {}
  for j = 0, SEG - 1 do
    local t = 2 * math.pi * (j + 0.5) / SEG
    local z0 = 0.535 + 0.035 * math.cos(2 * t)
    sr[#sr + 1] = { skin_at(z0 - 0.007, t, -0.02), skin_at(z0 - 0.007, t, 0.004), skin_at(z0 + 0.007, t, 0.004), skin_at(z0 + 0.007, t, -0.02) }
  end
  add(band(sr, true), seam, 40)

  -- The tape repair on the heel's right: two strips of silver tape crossed, lying on the skin.
  local z0, t0 = -0.8, math.pi - 0.3
  local P = skin_at(z0, t0)
  local u = normalize(skin_at(z0 + 0.03, t0) - skin_at(z0 - 0.03, t0))
  local v = normalize(skin_at(z0, t0 - 0.05) - skin_at(z0, t0 + 0.05))
  local n = normalize(cross(u, v))
  if n.x > 0 then n = n * -1 end
  v = normalize(cross(n, u))
  local function strip(ang, a, b, lift, c)
    local ca, sa = math.cos(rad(ang)), math.sin(rad(ang))
    local uu, vv = u * ca + v * sa, v * ca - u * sa
    local vs = {}
    for _, s in ipairs({ {-1, -1, -1}, {1, -1, -1}, {1, 1, -1}, {-1, 1, -1}, {-1, -1, 1}, {1, -1, 1}, {1, 1, 1}, {-1, 1, 1} }) do
      vs[#vs + 1] = P + uu * (s[1] * a) + vv * (s[2] * b) + n * (lift + s[3] * 0.02)
    end
    add(solid(vs, { {1, 2, 3, 4}, {8, 7, 6, 5}, {2, 1, 5, 6}, {3, 2, 6, 7}, {4, 3, 7, 8}, {1, 4, 8, 5} }), c, 20)
  end
  strip(-12, 0.08, 0.034, -0.008, tape)
  strip(28, 0.06, 0.03, -0.004, silver)
end

-- The ankle: a wall round an oval, flaring into the heel at its foot and tapering a little up, with a rounded opening
-- out of its front from the well up to arch_top.
do
  local N = SEG * 2
  local HALF = 1.5              -- the opening's half-width, radians either side of straight ahead
  local EDGE = HALF + 0.12       -- where the back's seam stops short of it
  local function off(t) return math.abs(math.atan(math.sin(t - math.pi / 2), math.cos(t - math.pi / 2))) end
  local function bottom(t)
    local u = off(t) / HALF
    if u >= 1 then return A0 end
    return A0 + (p.arch_top - A0) * (1 - u ^ 3.2) ^ (1 / 3.2)
  end
  local function taper(y) return 1.0 - 0.07 * (y - A0) / (A1 - A0) end
  -- (the flare: widest a little above the heel's top, where the wall rolls out over the foot as a boot's does)
  local function flare(y) return (1 - smooth(0.02, 0.66, y)) * smooth(-0.3, 0.08, y) end
  local function ring(t, y, a, b)
    local x, z = se(t, 2.3, a, b)
    local k = taper(y)
    local f = flare(y)
    return v3(x * (k + 0.07 * f), y, AZ + z * (k + 0.42 * f))
  end
  -- the back a touch higher than the front, as a leg's cut
  local function top(t) return A1 + 0.02 * -math.sin(t) end
  local rings = {}
  for j = 0, N - 1 do
    local t = 2 * math.pi * (j + 0.5) / N
    local yb, yt = bottom(t), top(t)
    local r = {}
    for _, f in ipairs({0, 0.3, 0.42, 0.54, 0.68, 1}) do r[#r + 1] = ring(t, yb + (yt - yb) * f, AO, BO) end
    for _, f in ipairs({1, 0.42, 0}) do r[#r + 1] = ring(t, yb + (yt - yb) * f, AI, BI) end
    rings[#rings + 1] = r
  end
  add(band(rings, true), skin, 40)

  -- A faint seam round the ankle's back, from one side of the opening to the other (the angles run from the kart's
  -- left through the front: start past the opening, at three quarters of a turn's far side).
  local sr = {}
  for j = 0, N - 1 do
    local t = math.pi / 2 + 2 * math.pi * (j + 0.5) / N
    if off(t) > EDGE then
      local y = 0.36 + 0.05 * math.cos(t * 2)
      sr[#sr + 1] = { ring(t, y - 0.007, AO - 0.02, BO - 0.02), ring(t, y - 0.007, AO + 0.004, BO + 0.004), ring(t, y + 0.007, AO + 0.004, BO + 0.004), ring(t, y + 0.007, AO - 0.02, BO - 0.02) }
    end
  end
  add(band(sr, false), seam, 40)

  -- The cut's rim: a fat dark-red roll round the open top, its lower edge wavy where the blood starts to run.
  local function hang(t) return 0.035 + 0.03 * (0.5 + 0.5 * math.sin(7 * t + 1)) * (0.6 + 0.4 * math.sin(3 * t + 2)) end
  local cr = {}
  for j = 0, N - 1 do
    local t = 2 * math.pi * (j + 0.5) / N
    local yt = top(t)
    local lo = yt - hang(t)
    cr[#cr + 1] = {
      ring(t, yt - 0.02, AI - 0.02, BI - 0.02),
      ring(t, lo - 0.02, AO - 0.01, BO - 0.01),
      ring(t, lo, AO + 0.022, BO + 0.022),
      ring(t, yt - 0.012, AO + 0.045, BO + 0.045),
      ring(t, yt + 0.035, AO + 0.045, BO + 0.045),
      ring(t, yt + 0.06, AO + 0.018, BO + 0.018),
      ring(t, yt + 0.06, AI - 0.004, BI - 0.004),
      ring(t, yt + 0.03, AI - 0.02, BI - 0.02),
    }
  end
  add(band(cr, true), red, 60)

  -- The blood: drips of paint running down from the rim, each a long bead with a fat drop at its end.
  for i = 0, p.drips - 1 do
    local r1 = (math.sin(i * 12.9898 + 1.3) * 43758.5453) % 1
    local r2 = (math.sin(i * 78.233 + 0.7) * 12543.123) % 1
    local t = 2 * math.pi * (i + 0.15 + 0.5 * r2) / p.drips
    local len = 0.09 + 0.2 * r1
    local y1 = top(t) - 0.04
    local y0 = math.max(y1 - len, bottom(t) + 0.06)
    for _, tt in ipairs({t - 0.12, t + 0.12}) do y0 = math.max(y0, bottom(tt) + 0.06) end
    if y1 - y0 > 0.05 then
      local wd = 0.02 + 0.008 * r2
      local a = ring(t, (y0 + y1) * 0.5, AO, BO)
      add(ball(wd, (y1 - y0) * 0.5 + 0.01, wd, a.x, a.y, a.z, 6), red, 60)
      local b = ring(t, y0, AO + 0.004, BO + 0.004)
      add(ball(wd * 1.45, wd * 1.9, wd * 1.3, b.x, b.y + wd * 0.5, b.z, 6), red, 60)
    end
  end

  -- The flesh inside the cut, closing the ankle over the driver's head, and the bone standing out of it.
  local fy = A1 - 0.06
  local k = taper(fy)
  local flesh = scale(cylinder{radius=1, height=0.05, segments=SEG, axis="y"}, {factor=v3((AI + 0.03) * k, 1, (BI + 0.03) * k), pivot=origin()})
  add(at(flesh, 0, fy, AZ), red_dk, 30)
  local bt = A1 + p.bone
  add(at(cone{radius=0.085, radius_top=0.066, height=bt - fy, segments=10, axis="y"}, 0, (bt + fy) * 0.5, AZ), ivory, 60)
  for _, sx in ipairs({-1, 1}) do
    add(ball(0.074, 0.066, 0.078, sx * 0.052, bt + 0.005, AZ + sx * 0.008, 10), ivory, 60)
  end
end

-- The seat inside the ankle: a black padded cushion under the hips and a back of stacked rolls against the back wall.
add(rbox(0.46, 0.05, 0.42, 0.08, 0, FLOOR, -0.32, 0.015), black, 40)
for i = 0, 2 do
  local y = -0.15 + i * 0.2
  local m = rbox(0.46, 0.17, 0.13, 0.05, 0, 0, 0, 0.03)
  m = rotate(m, {angle=-10, axis=axis_x(), pivot=origin()})
  -- (Inside the back wall, never through it.)
  add(at(m, 0, y, -0.55 - i * 0.02), i % 2 == 0 and black2 or black, 50)
end

-- A fat blunt lump (a superellipsoid, its poles fore and aft): radii rx, ry, rz about x, y, z; n its bluntness (2 a
-- plain ellipsoid).
local function lump(rx, ry, rz, x, y, z, seg, n)
  local function pw(v) return (v < 0 and -1 or 1) * math.abs(v) ^ (2 / n) end
  local R = math.floor(seg / 2)
  local vs, fs = {}, {}
  vs[1] = v3(x, y, z - rz)
  for i = 1, R - 1 do
    local ph = -math.pi / 2 + math.pi * i / R
    local c, sn = pw(math.cos(ph)), pw(math.sin(ph))
    for j = 0, seg - 1 do
      local th = 2 * math.pi * (j + 0.5) / seg
      vs[#vs + 1] = v3(x + rx * c * pw(math.cos(th)), y + ry * c * pw(math.sin(th)), z + rz * sn)
    end
  end
  vs[#vs + 1] = v3(x, y, z + rz)
  local last = #vs
  local function id(i, j) return 1 + (i - 1) * seg + (j % seg) + 1 end
  for j = 0, seg - 1 do
    fs[#fs + 1] = {1, id(1, j), id(1, j + 1)}
    fs[#fs + 1] = {last, id(R - 1, j + 1), id(R - 1, j)}
    for i = 1, R - 2 do fs[#fs + 1] = {id(i, j), id(i + 1, j), id(i + 1, j + 1), id(i, j + 1)} end
  end
  return solid(vs, fs)
end

-- The toes: five big fat blunt lumps squashed together across the whole front, the big one (the kart's right) the
-- largest and the rest stepping down, each with a big flat nail on its top toward the tip.
do
  local TOES = {
    {-0.345, 0.155, 0.2, 0.3, 0.73},
    {-0.1, 0.118, 0.178, 0.28, 0.74},
    {0.107, 0.107, 0.162, 0.26, 0.73},
    {0.287, 0.096, 0.147, 0.24, 0.71},
    {0.418, 0.078, 0.132, 0.21, 0.68},
  }
  local s = p.toe_size
  local NB = 2.5
  for i, t in ipairs(TOES) do
    local big = i == 1          -- the big toe and its nail: the signature piece
    local x, rx, ry, rz, z = t[1], t[2] * s, t[3] * s, t[4] * s, t[5]
    local y = -0.385 + ry
    add(lump(rx, ry, rz, x, y, z, big and 14 or 12, NB), skin, 50, big)
    -- the nail: a flat oval let into the toe's top toward its tip, tipped down with it
    local dz = 0.45
    local up = (1 - dz ^ NB) ^ (1 / NB)
    local ang = deg(math.atan(ry / rz * dz ^ (NB - 1) * (1 - dz ^ NB) ^ (1 / NB - 1)))
    local n = lump(rx * 0.56, 0.02, rz * 0.3, 0, 0, 0, 10, 3)
    n = rotate(n, {angle=ang, axis=axis_x(), pivot=origin()})
    add(at(n, x, y + ry * up - 0.01, z + rz * dz), nail, 50, big)
  end
end

-- The steering column: from just under the wheel, forward and down to the frame through the well.
add(rod(v3(0, 0.1, 0.15), v3(0, -0.3, 0.5), 0.022, 10), black, 40)
add(cyl(0.035, 0.05, 0, 0.08, 0.17, "y", 10), black, 40)

-- The frame: navy tube under the foot -- a lower and an upper rail each side, posts and braces between them at the
-- axles, crossbars, axle rods out to the wheels -- with a silver bolt at each joint.
do
  local RX, RY, TR = 0.36, -0.475, 0.024
  local UX, UY = 0.4, -0.4
  local function tb(a, b, r) add(rod(a, b, r or TR, 6), navy, 40) end
  local function bolt(x, y, z, sx) add(cyl(0.016, 0.014, x + sx * 0.007, y, z, "x", 6), silver, 30) end
  for _, sx in ipairs({-1, 1}) do
    tb(v3(sx * RX, RY, -0.95), v3(sx * RX, RY, 0.92))
    tb(v3(sx * UX, UY, -0.86), v3(sx * UX, UY, 0.86), 0.02)
    for _, e in ipairs({-1, 1}) do
      -- a post at the rail's end, a brace leaning in from the middle
      tb(v3(sx * RX, RY, e * 0.86), v3(sx * UX, UY, e * 0.86), 0.02)
      tb(v3(sx * RX, RY, e * 0.3), v3(sx * UX, UY, e * 0.5), 0.016)
      bolt(sx * (UX + 0.02), UY, e * 0.86, sx)
      bolt(sx * (UX + 0.02), UY, e * 0.5, sx)
      bolt(sx * (RX + 0.024), RY, e * 0.3, sx)
      bolt(sx * (RX + 0.024), RY, e * 0.86, sx)
    end
    bolt(sx * (UX + 0.02), UY, 0, sx)
    for _, z in ipairs({-0.7, 0.7}) do
      add(rod(v3(sx * 0.42, -0.42, z), v3(sx * 0.535, -0.42, z), 0.02, 10), silver, 40)
      add(cyl(0.036, 0.03, sx * 0.445, -0.42, z, "x", 8), navy, 40)
    end
  end
  for _, z in ipairs({-0.7, 0.7}) do tb(v3(-0.42, -0.42, z), v3(0.42, -0.42, z), 0.024) end
  tb(v3(-RX, RY, -0.94), v3(RX, RY, -0.94))
  tb(v3(-RX, RY, 0.9), v3(RX, RY, 0.9))
  tb(v3(-RX, RY, -0.3), v3(RX, RY, -0.3), 0.02)
  tb(v3(-RX, RY, 0.3), v3(RX, RY, 0.3), 0.02)
end

part("foot", pieces)
