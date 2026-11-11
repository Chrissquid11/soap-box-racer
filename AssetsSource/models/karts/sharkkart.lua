-- Great White Hope: a cartoon shark for a kart body. A streamlined blue-grey shell with a cream underside, its snout
-- tapering to a mouth set into the head -- dark red inside, two rows of chunky white teeth, a thick lower jaw -- small
-- cross eyes under heavy brows, three gill slits a side, swept side fins, a small dorsal fin behind the seat and a short
-- upright crescent tail; an open cockpit cut into its back with a dark tub inside, all on a bright yellow tube frame.
-- The jaw, the side fins, the dorsal fin and the tail are their own parts (`sharkkart_<bit>`, and `_loose` centred):
-- the game knocks each off on its own (a frontal hit the jaw, a sideswipe a fin, a hard one from behind the tail).
--
-- In the kart's body space, metres: the origin the middle of the (hidden) chassis box's top, +z forward, y up. The
-- cockpit keeps clear of x ±0.28, z -0.5..0.45 above y -0.2; the wheels (another slot) sit at x ±0.5, z ±0.7, y -0.42.
local p = params{
  girth = {default=0.42, min=0.38, max=0.46, doc="Half the shark's width at its widest, metres"},
  gape  = {default=0.12, min=0.09, max=0.14, doc="Half the open mouth's height, metres"},
  teeth = {default=8, min=5, max=10, integer=true, doc="Teeth a side of the upper lip (the lower row follows)"},
}
local PAINT = material{name="Paint", base_color=v3(1, 1, 1), roughness=0.6, metallic=0}

local function all(m) return faces_where(m, function(_) return true end) end
local function paint(m, c) return paint_faces(m, {faces=all(m), color=c}) end
local function paint_if(m, c, fn)
  local sel = faces_where(m, fn)
  if set_count(sel) == 0 then return m end
  return paint_faces(m, {faces=sel, color=c})
end
local function part(name, pieces)
  local out = {}
  for i, pc in ipairs(pieces) do
    local m = pc[2] and paint(pc[1], pc[2]) or pc[1]
    out[i] = {mesh=smooth_normals(m, {angle=pc.angle or 35}), material=PAINT}
  end
  local merged = merge({parts=out, mode="compatible"})
  emit(merged[1].mesh, {name=name, material=merged[1].material})
  -- Its signature piece (the pieces marked, 3rd): `<name>_sig`, and left out of the wreck (_sig.lua).
  local rest = include("_sig.lua").split(name, out, function(i) return pieces[i][3] end)
  -- Its wreck, as the same pieces broken: what stays on the kart when the bodywork is knocked off (_wreck.lua).
  include("_wreck.lua").emit(name, rest)
end
local function C(r, g, b) return v3(r, g, b) end
local function at(m, x, y, z) return translate(m, v3(x, y, z)) end
local function bx(sx, sy, sz, x, y, z) return at(box{size=v3(sx, sy, sz)}, x, y, z) end
local function rb(sx, sy, sz, x, y, z, w, seg)
  local m = box{size=v3(sx, sy, sz)}
  return at(bevel(m, {edges=convex_edges(m), width=w or math.min(sx, sy, sz) * 0.2, segments=seg or 1}), x, y, z)
end
local function ball(rx, ry, rz, x, y, z, seg)
  local s = seg or 12
  return at(scale(sphere{radius=1, segments=s, rings=math.floor(s / 2)}, {factor=v3(rx, ry, rz), pivot=origin()}), x, y, z)
end
local function cyl(r, h, x, y, z, axis, seg) return at(cylinder{radius=r, height=h, segments=seg or 14, axis=axis or "y"}, x, y, z) end
-- A mesh modelled along +y about its middle, turned onto the line a to b and centred on it.
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
-- A slab of a convex outline: pts are { u, v } pairs, place(u, v, w) the point at depth w (-1 or 1).
local function slab(pts, place)
  local vs, fs = {}, {}
  local n = #pts
  for i, q in ipairs(pts) do
    vs[i] = place(q[1], q[2], -1)
    vs[n + i] = place(q[1], q[2], 1)
  end
  local a, b = {}, {}
  for i = 1, n do
    a[i] = i
    b[i] = 2 * n + 1 - i
    local j = i % n + 1
    fs[#fs + 1] = {j, i, n + i, n + j}
  end
  fs[#fs + 1] = a
  fs[#fs + 1] = b
  local m = solid(vs, fs)
  return m
end

-- Blue-grey above, cream below; a dark red mouth and chunky white teeth; the bright yellow frame under it all.
local shell  = C(0.15, 0.21, 0.32)
local finc   = C(0.13, 0.185, 0.29)
local cream  = C(0.83, 0.78, 0.66)
local gum    = C(0.36, 0.025, 0.035)
local maw    = C(0.1, 0.008, 0.012)
local tongue = C(0.5, 0.07, 0.08)
local tooth  = C(0.95, 0.92, 0.82)
local black  = C(0.02, 0.02, 0.025)
local dark   = C(0.07, 0.07, 0.08)
local slit   = C(0.05, 0.075, 0.13)
local yellow = C(1.0, 0.62, 0.0)
local grey   = C(0.45, 0.46, 0.5)
local white  = C(1, 1, 1)

local W = p.girth
local G = p.gape
local pieces = {}
local function add(m, c, angle) pieces[#pieces + 1] = {m, c, false, angle=angle} end

-- The bits that come off on their own (the game's BODY bits): each its own part, drawn in place on the body as
-- `sharkkart_<bit>`, and again centred on its own middle as `sharkkart_<bit>_loose` to tumble away when it is knocked
-- off. Their bounds (centre and size, body space) are said for the game's table (build.ts' Great White Hope).
local function bit(name, list)
  local out = {}
  for i, pc in ipairs(list) do
    local m = pc[2] and paint(pc[1], pc[2]) or pc[1]
    out[i] = {mesh=smooth_normals(m, {angle=pc.angle or 35}), material=PAINT}
  end
  local merged = merge({parts=out, mode="compatible"})[1]
  emit(merged.mesh, {name="sharkkart_" .. name, material=merged.material})
  local b = bbox(merged.mesh)
  emit(translate(merged.mesh, v3(0, 0, 0) - b.center), {name="sharkkart_" .. name .. "_loose", material=merged.material})
  warn(string.format("bit %s: at {%.3f, %.3f, %.3f} size {%.3f, %.3f, %.3f}", name, b.center.x, b.center.y, b.center.z, b.size.x, b.size.y, b.size.z))
end

-- A tube through loops of points (each the same count), capped flat at both ends.
local function tube(loops)
  local vs, fs = {}, {}
  local k = #loops[1]
  for _, lp in ipairs(loops) do
    for _, v in ipairs(lp) do vs[#vs + 1] = v end
  end
  local function id(i, j) return (i - 1) * k + ((j - 1) % k) + 1 end
  for i = 1, #loops - 1 do
    for j = 1, k do fs[#fs + 1] = {id(i, j), id(i, j + 1), id(i + 1, j + 1), id(i + 1, j)} end
  end
  local c0, c1 = {}, {}
  for j = 1, k do
    c0[j] = id(1, k + 1 - j)
    c1[j] = id(#loops, j)
  end
  fs[#fs + 1] = c0
  fs[#fs + 1] = c1
  return solid(vs, fs)
end
-- A fin: stations from root to tip, each { leading edge (u, v), trailing edge (u, v), half thickness }, a lens across
-- each; place(u, v, w) the point at (u, v) in the fin's plane, w metres off it.
local function blade(stations, place)
  local loops = {}
  for i, st in ipairs(stations) do
    local l, tr, t = st[1], st[2], st[3]
    local function pt(s, w) return place(l[1] + (tr[1] - l[1]) * s, l[2] + (tr[2] - l[2]) * s, w) end
    loops[i] = {pt(0, 0), pt(0.3, t), pt(0.72, t * 0.6), pt(1, 0), pt(0.72, -t * 0.6), pt(0.3, -t)}
  end
  return tube(loops)
end

-- The body ----------------------------------------------------------------------------------------------------
-- A fat torpedo lofted from the tail's root (lifting toward the tail) to a blunt snout, each ring a rounded oval
-- across the spine: { z, y, half width, up, down }. The cockpit is cut into its back. The mouth is a wedge cut right
-- through the head from its corner (CZ, CY) forward -- a grin seen from the side as from the front -- under a flat
-- roof (the upper teeth's) and over the lower jaw, which is everything of the hull under the wedge: its own part.
local FL, PZ0, PZ1 = -0.26, -0.56, 0.46
local PW = 0.3
local N = 2.3
local NOSE, TAILTIP = v3(0, -0.03, 1.31), v3(0, 0.1, -1.02)
local ST = {
  {-1.0, 0.1, 0.06, 0.07, 0.07},
  {-0.88, 0.07, 0.12, 0.11, 0.12},
  {-0.72, 0.02, 0.25, 0.2, 0.24},
  {-0.45, -0.04, 0.37, 0.28, 0.32},
  {-0.1, -0.06, W * 0.98, 0.31, 0.34},
  {0.28, -0.06, W, 0.31, 0.34},
  {0.6, -0.06, W * 0.96, 0.3, 0.34},
  {0.85, -0.06, W * 0.86, 0.27, 0.335},
  {1.02, -0.06, W * 0.74, 0.22, 0.33},
  {1.15, -0.05, W * 0.56, 0.16, 0.29},
  {1.25, -0.04, W * 0.32, 0.09, 0.13},
}
-- The body's ring at z (between its rings): its middle's y, half width, up and down.
local function ring_at(z)
  local S = #ST
  if z <= ST[1][1] then return ST[1][2], ST[1][3], ST[1][4], ST[1][5] end
  for i = 1, S - 1 do
    local a, b = ST[i], ST[i + 1]
    if z <= b[1] then
      local t = (z - a[1]) / (b[1] - a[1])
      return a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] + (b[4] - a[4]) * t, a[5] + (b[5] - a[5]) * t
    end
  end
  local l = ST[S]
  local t = math.min(1, (z - l[1]) / (NOSE.z - l[1]))
  return l[2] + (NOSE.y - l[2]) * t, l[3] * (1 - t), l[4] * (1 - t), l[5] * (1 - t)
end
-- The body's half width at z, for things laid on its flanks; and at z and a height y, for things on its skin.
local function half_width(z)
  local _, w = ring_at(z)
  return w
end
local function half_x(z, y)
  local cy, w, up, dn = ring_at(z)
  local h = y > cy and up or dn
  if h < 1e-4 then return 0 end
  local t = math.abs(y - cy) / h
  if t >= 1 then return 0 end
  return w * (1 - t ^ N) ^ (1 / N)
end
-- The hull, or (inset) one that much smaller all round: what fills the mouth.
local function hull_mesh(d)
  local SEG = 24
  local vs, fs = {}, {}
  local S = #ST
  for _, s in ipairs(ST) do
    local w, up, dn = math.max(s[3] - d, 0.012), math.max(s[4] - d, 0.012), math.max(s[5] - d, 0.012)
    for j = 0, SEG - 1 do
      local t = 2 * math.pi * j / SEG
      local c, sn = math.cos(t), math.sin(t)
      local cx = (c < 0 and -1 or 1) * math.abs(c) ^ (2 / N)
      local sy = (sn < 0 and -1 or 1) * math.abs(sn) ^ (2 / N)
      vs[#vs + 1] = v3(w * cx, s[2] + (sy > 0 and up or dn) * sy, s[1])
    end
  end
  local function id(i, j) return (i - 1) * SEG + (j % SEG) + 1 end
  for i = 1, S - 1 do
    for j = 0, SEG - 1 do fs[#fs + 1] = {id(i, j), id(i, j + 1), id(i + 1, j + 1), id(i + 1, j)} end
  end
  vs[#vs + 1] = TAILTIP
  local tip = #vs
  vs[#vs + 1] = v3(0, NOSE.y, math.max(NOSE.z - d, ST[S][1] + 0.012))
  local nose = #vs
  for j = 0, SEG - 1 do
    fs[#fs + 1] = {tip, id(1, j + 1), id(1, j)}
    fs[#fs + 1] = {nose, id(S, j), id(S, j + 1)}
  end
  return solid(vs, fs)
end
local hull = hull_mesh(0)

-- The mouth, in profile (z, y): its corner, the roof running forward from it, the floor dropping to the open front.
local CZ, CY, FZ, RY = 0.72, -0.13, 1.45, -0.11
local OPEN = G * 1.05
local MZ, MY, FY = 0.92, CY - OPEN * 0.8, CY - OPEN
local function roof_y(z) return CY + (RY - CY) * (z - CZ) / (FZ - CZ) end
local function floor_y(z)
  if z < MZ then return CY + (MY - CY) * (z - CZ) / (MZ - CZ) end
  return MY + (FY - MY) * (z - MZ) / (FZ - MZ)
end
local function across(pts) return slab(pts, function(u, v, w) return v3(w * 0.6, v, u) end) end
-- Everything under the roof ahead of the corner (the jaw's side of the head), the wedge of air over the jaw, and the
-- smile: the corner's upturn, cut into the cheek.
local under = across({{CZ, CY}, {FZ, RY}, {FZ, -0.8}, {CZ, -0.8}})
local air = across({{CZ + (CZ - MZ) * 0.15, CY + (CY - MY) * 0.15}, {FZ, 0.05}, {FZ, FY}, {MZ, MY}})
local smile = across({{0.84, -0.11}, {0.84, -0.17}, {0.71, -0.15}, {0.67, -0.07}, {0.7, -0.06}})
local function belly(c)
  local cy, _, _, dn = ring_at(c.z)
  return (c.y - cy) / dn < -0.29
end
local function in_pit(c)
  return math.abs(c.x) < PW + 0.004 and c.y > FL - 0.004 and c.z > PZ0 - 0.004 and c.z < PZ1 + 0.004
end
local function cut_face(f) return math.abs(f.normal.x) < 0.03 and f.center.z > 0.6 and f.center.y < 0 end
do
  local pit = at(extrude(rounded_rect{w=2 * PW, h=PZ1 - PZ0, radius=0.07, segments=3}, {distance=1.0}), 0, FL, (PZ0 + PZ1) / 2)
  local m = subtract(hull, under, smile, pit)
  m = paint(m, shell)
  m = paint_if(m, cream, function(f) return f.center.z < CZ and belly(f.center) end)
  m = paint_if(m, gum, cut_face)
  -- (only faces turned into the cockpit -- its floor up, its walls inward: the hull's own big belly faces, whose middles
  -- can fall inside the cockpit's outline, stay their colour)
  m = paint_if(m, dark, function(f)
    local c, n = f.center, f.normal
    return in_pit(c) and (n.y > 0.5 or n.x * c.x < 0 or (n.z * c.z < 0 and math.abs(n.y) < 0.5))
  end)
  add(m, nil, 25)
end

-- Inside the mouth, set back from the lips: the palate under the roof and a dark throat behind the teeth (the head's),
-- the tongue on the jaw (it goes with it), and the dark line of the smile.
local Y1, Y2 = RY - (RY - FY) * 0.22, RY - (RY - FY) * 0.6
local tongue_mesh
do
  local inner, deep = hull_mesh(0.03), hull_mesh(0.075)
  add(intersect(inner, across({{CZ, CY}, {FZ, RY}, {FZ, Y1}})), gum, 30)
  add(intersect(deep, across({{CZ, CY}, {FZ, Y1}, {FZ, Y2}})), maw, 30)
  add(intersect(inner, smile), maw, 30)
  tongue_mesh = intersect(inner, across({{CZ, CY}, {FZ, Y2}, {FZ, FY}, {MZ, MY}}))
end

-- The teeth: a row of chunky white points round each lip -- the upper ones down from the snout's rim, the lower ones
-- up from the jaw's (they go with it), the two rows interleaved.
local upper, lower = {}, {}
do
  -- The lip's outline seen from above (the hull's skin at the lip's height), one side; teeth evenly along both.
  local function row(list, lip_y, count, dir, len0, shift)
    local pts = {}
    local z = 0.8
    while z < NOSE.z do
      local x = half_x(z, lip_y(z))
      if x < 0.012 and #pts > 0 then break end
      if x >= 0.012 then pts[#pts + 1] = {x, z} end
      z = z + 0.004
    end
    if #pts < 2 then return end
    local path = {}
    for i = 1, #pts do path[#path + 1] = {-pts[i][1], pts[i][2]} end
    for i = #pts, 1, -1 do path[#path + 1] = {pts[i][1], pts[i][2]} end
    local acc = {0}
    for i = 2, #path do
      acc[i] = acc[i - 1] + math.sqrt((path[i][1] - path[i - 1][1]) ^ 2 + (path[i][2] - path[i - 1][2]) ^ 2)
    end
    local total = acc[#path]
    local k = 1
    for i = 0, count - 1 do
      local s = total * (i + 0.5 + shift) / (count + 2 * shift)
      while k < #path - 1 and acc[k + 1] < s do k = k + 1 end
      local t = (s - acc[k]) / math.max(acc[k + 1] - acc[k], 1e-6)
      local x = (path[k][1] + (path[k + 1][1] - path[k][1]) * t) * 0.9
      local tz = path[k][2] + (path[k + 1][2] - path[k][2]) * t - 0.014
      local gap = roof_y(tz) - floor_y(tz)
      local len = math.min(len0, gap * 0.72)
      if len > 0.022 then
        local y0 = lip_y(tz)
        local r = math.min(0.03, len * 0.5)
        list[#list + 1] = {along(cone{radius=r, height=len + 0.012, segments=4, anchor="center"},
          v3(x, y0 - dir * 0.012, tz), v3(x, y0 + dir * len, tz)), tooth, 20}
      end
    end
  end
  row(upper, roof_y, 2 * p.teeth - 1, -1, 0.085, 0)
  row(lower, floor_y, 2 * p.teeth - 4, 1, 0.075, 0.25)
  for _, t in ipairs(upper) do add(t[1], t[2], t[3]) end
end

-- The eyes: small and cross -- a white with a big black pupil looking forward and a glint in it, under a heavy brow
-- that slants down to the snout.
for _, sx in ipairs({-1, 1}) do
  local ez, ey = 0.9, 0.035
  local ex = half_x(ez, ey) * 0.94
  add(ball(0.034, 0.06, 0.07, sx * ex, ey, ez, 14), white, 30)
  add(ball(0.026, 0.044, 0.046, sx * (ex + 0.015), ey - 0.006, ez + 0.02, 12), black, 30)
  add(ball(0.008, 0.011, 0.011, sx * (ex + 0.037), ey + 0.012, ez + 0.036, 8), white, 30)
  local brow = rb(0.055, 0.034, 0.2, 0, 0, 0, 0.01)
  brow = rotate(brow, {angle=24, axis=axis_x(), pivot=origin()})
  brow = rotate(brow, {angle=sx * -20, axis=axis_z(), pivot=origin()})
  brow = rotate(brow, {angle=sx * -12, axis=axis_y(), pivot=origin()})
  add(at(brow, sx * (ex + 0.002), ey + 0.058, ez + 0.005), finc, 30)
end

-- The gills: three slits down each flank behind the eye, leaning back, the hindmost the longest.
for _, sx in ipairs({-1, 1}) do
  for k = 0, 2 do
    local z = 0.47 + k * 0.075
    local x = half_x(z, -0.02) - 0.004
    local g = rb(0.02, 0.2 - k * 0.025, 0.02, 0, 0, 0, 0.006)
    g = rotate(g, {angle=-14, axis=axis_x(), pivot=origin()})
    add(at(g, sx * x, -0.015, z), slit, 30)
  end
end

-- The tub's seat: a dark moulded bucket, its base under the hips and its back behind the driver.
do
  add(rb(0.4, 0.05, 0.4, 0, -0.245, -0.3, 0.015, 2), dark)
  local back = rb(0.42, 0.62, 0.08, 0, 0.0, 0, 0.02, 2)
  back = rotate(back, {angle=-10, axis=axis_x(), pivot=v3(0, -0.31, 0)})
  add(at(back, 0, 0.06, -0.55), black, 35)
  for _, sx in ipairs({-1, 1}) do
    local b = rb(0.07, 0.36, 0.2, 0, 0, 0, 0.015, 2)
    b = rotate(b, {angle=sx * 20, axis=axis_y(), pivot=origin()})
    add(at(b, sx * 0.21, -0.06, -0.46), black, 35)   -- (in from the hull, which narrows toward the belly)
  end
end

-- The steering column: from under the wheel's hub forward and down into the cockpit's front wall.
add(rod(v3(0, 0.115, 0.15), v3(0, 0.0, 0.5), 0.018, 10), dark)

-- The frame: bright yellow tube under the shark ------------------------------------------------------------------
do
  local TR = 0.02
  local function tb(a, b, r) add(rod(a, b, r or TR, 10), yellow, 40) end
  local function knot(v, r) add(ball(r or TR * 1.15, r or TR * 1.15, r or TR * 1.15, v.x, v.y, v.z, 10), yellow, 40) end
  local LY, UY = -0.45, -0.33
  local LX, UX = 0.3, 0.37
  local ZE = 0.86
  for _, s in ipairs({-1, 1}) do
    local l0, l1 = v3(s * LX, LY, -ZE), v3(s * LX, LY, ZE)
    tb(l0, l1)
    local u0, u1 = v3(s * UX, UY, -0.78), v3(s * UX, UY, 0.78)
    tb(u0, u1)
    tb(u0, l0); tb(u1, l1)
    knot(u0); knot(u1); knot(l0); knot(l1)
    local zs = {-0.78, -0.36, 0.06, 0.42, 0.78}
    for i = 1, #zs - 1 do
      local a = (i % 2 == 1) and v3(s * LX, LY, zs[i]) or v3(s * UX, UY, zs[i])
      local b = (i % 2 == 1) and v3(s * UX, UY, zs[i + 1]) or v3(s * LX, LY, zs[i + 1])
      tb(a, b, TR * 0.8)
    end
    for _, z in ipairs({-0.3, 0.3}) do tb(v3(s * UX, UY, z), v3(s * 0.27, -0.25, z), TR * 0.8) end
    for _, z in ipairs({-0.7, 0.7}) do
      add(cyl(0.032, 0.07, s * 0.465, -0.42, z, "x", 14), grey, 30)
      add(cyl(0.022, 0.02, s * 0.51, -0.42, z, "x", 12), grey, 30)
      tb(v3(s * LX, LY, z), v3(s * 0.43, -0.42, z))
      tb(v3(s * UX, UY, z), v3(s * 0.43, -0.42, z), TR * 0.8)
    end
  end
  for _, z in ipairs({-0.7, 0.7}) do tb(v3(-0.47, -0.42, z), v3(0.47, -0.42, z), 0.024) end
  for _, z in ipairs({-ZE, ZE}) do tb(v3(-LX, LY, z), v3(LX, LY, z)) end
  tb(v3(-LX, LY, -0.3), v3(LX, LY, 0.3), TR * 0.8)
  tb(v3(LX, LY, -0.3), v3(-LX, LY, 0.3), TR * 0.8)
end

part("sharkkart", pieces)

-- The bits ---------------------------------------------------------------------------------------------------------
-- The lower jaw: the thick chin under the mouth, cream outside, dark red inside, the tongue and the lower teeth on it.
do
  local jaw = subtract(intersect(hull, under), air, smile)
  jaw = paint(jaw, cream)
  jaw = paint_if(jaw, gum, function(f)
    return math.abs(f.normal.x) < 0.03 and (f.center.z < CZ + 0.005 or f.center.y > floor_y(f.center.z) - 0.012)
  end)
  local list = {{jaw, nil, angle=25}, {tongue_mesh, tongue, angle=30}}
  for _, t in ipairs(lower) do list[#list + 1] = {t[1], t[2], angle=t[3]} end
  bit("jaw", list)
end

-- The side fins: broad at the root, swept back to a point and drooping off the flanks between the wheels (clear of
-- them: z -0.3..0.4, whatever the steering or the springs do).
for _, sx in ipairs({-1, 1}) do
  local fin = blade({
    {{-0.06, 0.39}, {-0.06, 0.05}, 0.034},
    {{0.08, 0.35}, {0.08, 0.03}, 0.03},
    {{0.18, 0.25}, {0.17, -0.04}, 0.024},
    {{0.27, 0.1}, {0.25, -0.13}, 0.018},
    {{0.33, -0.08}, {0.31, -0.22}, 0.012},
    {{0.365, -0.23}, {0.355, -0.28}, 0.006},
  }, function(u, v, w) return v3(u, w, v) end)
  fin = rotate(fin, {angle=-24, axis=axis_z(), pivot=origin()})
  if sx < 0 then fin = mirror(fin, {normal=v3(1, 0, 0), pivot=origin()}) end
  bit(sx > 0 and "fin_l" or "fin_r", {{at(fin, sx * (half_width(0.15) - 0.03), -0.16, 0), finc, angle=30}})
end

-- The dorsal fin: small, behind the seat, raked back to a hooked tip.
do
  local fin = blade({
    {{-0.6, 0.14}, {-0.91, 0.14}, 0.032},
    {{-0.655, 0.27}, {-0.89, 0.25}, 0.026},
    {{-0.73, 0.38}, {-0.895, 0.35}, 0.02},
    {{-0.82, 0.47}, {-0.925, 0.45}, 0.013},
    {{-0.915, 0.535}, {-0.965, 0.525}, 0.006},
  }, function(u, v, w) return v3(w, v, u) end)
  bit("dorsal", {{fin, finc, angle=30}})
end

-- The tail: the stalk's end, lifting, and a short upright crescent -- an upper lobe swept up and back, a smaller one
-- under it.
do
  local function lobe(st) return blade(st, function(u, v, w) return v3(w, v, u) end) end
  local stalk = ball(0.05, 0.075, 0.14, 0, 0.11, -1.03, 12)
  local up = lobe({
    {{-0.99, 0.17}, {-1.15, 0.07}, 0.036},
    {{-1.08, 0.31}, {-1.2, 0.2}, 0.03},
    {{-1.18, 0.45}, {-1.265, 0.37}, 0.022},
    {{-1.275, 0.56}, {-1.325, 0.51}, 0.014},
    {{-1.35, 0.625}, {-1.37, 0.605}, 0.006},
  })
  local dn = lobe({
    {{-0.99, 0.06}, {-1.15, 0.13}, 0.034},
    {{-1.08, -0.05}, {-1.2, 0.03}, 0.026},
    {{-1.17, -0.13}, {-1.25, -0.07}, 0.018},
    {{-1.265, -0.185}, {-1.29, -0.165}, 0.006},
  })
  bit("tail", {{stalk, shell, angle=30}, {up, finc, angle=30}, {dn, finc, angle=30}})
end
