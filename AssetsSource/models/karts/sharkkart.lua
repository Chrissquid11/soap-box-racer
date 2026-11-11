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
  teeth = {default=8, min=5, max=10, integer=true, doc="Teeth along each jaw's front row"},
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
local shell  = C(0.2, 0.26, 0.36)
local finc   = C(0.22, 0.29, 0.4)
local cream  = C(0.8, 0.75, 0.62)
local gum    = C(0.36, 0.025, 0.035)
local tooth  = C(0.95, 0.92, 0.82)
local black  = C(0.02, 0.02, 0.025)
local dark   = C(0.07, 0.07, 0.08)
local slit   = C(0.04, 0.06, 0.1)
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

-- The body ----------------------------------------------------------------------------------------------------
-- A torpedo lofted from the tail's root to the snout, each ring a rounded oval across the spine: { z, y, half width,
-- up, down }. The cockpit is cut into its back; the mouth into its snout; the chin under the mouth is the lower jaw,
-- its own part.
local MC, MR = v3(0, -0.19, 1.0), v3(0.3, G, 0.34)
local FL, PZ0, PZ1 = -0.26, -0.56, 0.46
local PW = 0.3
local JAW_Y, JAW_Z = -0.19, 0.72        -- the jaw: everything of the snout below the mouth's middle and ahead of here
local function belly(c) return c.y < -0.11 end
local function in_pit(c)
  return math.abs(c.x) < PW + 0.004 and c.y > FL - 0.004 and c.z > PZ0 - 0.004 and c.z < PZ1 + 0.004
end
local function in_mouth(c)
  return ((c.x / MR.x) ^ 2 + ((c.y - MC.y) / MR.y) ^ 2 + ((c.z - MC.z) / MR.z) ^ 2) < 1.06
end
local ST = {
  {-0.98, 0.0, 0.07, 0.07, 0.07},
  {-0.86, -0.01, 0.13, 0.13, 0.13},
  {-0.7, -0.03, 0.27, 0.22, 0.24},
  {-0.45, -0.05, 0.37, 0.29, 0.32},
  {-0.1, -0.06, W * 0.98, 0.31, 0.34},
  {0.28, -0.06, W, 0.31, 0.34},
  {0.6, -0.07, W * 0.95, 0.29, 0.32},
  {0.85, -0.08, W * 0.82, 0.25, 0.28},
  {1.05, -0.1, W * 0.6, 0.19, 0.22},
  {1.2, -0.12, W * 0.32, 0.1, 0.12},
}
-- The body's half width at z (between its rings), for things laid on its flanks.
local function half_width(z)
  for i = 1, #ST - 1 do
    local a, b = ST[i], ST[i + 1]
    if z <= b[1] then return a[3] + (b[3] - a[3]) * (z - a[1]) / (b[1] - a[1]) end
  end
  return ST[#ST][3]
end
local hull
do
  local SEG, N = 24, 2.3
  local vs, fs = {}, {}
  local S = #ST
  for _, s in ipairs(ST) do
    for j = 0, SEG - 1 do
      local t = 2 * math.pi * j / SEG
      local c, sn = math.cos(t), math.sin(t)
      local cx = (c < 0 and -1 or 1) * math.abs(c) ^ (2 / N)
      local sy = (sn < 0 and -1 or 1) * math.abs(sn) ^ (2 / N)
      vs[#vs + 1] = v3(s[3] * cx, s[2] + (sy > 0 and s[4] or s[5]) * sy, s[1])
    end
  end
  local function id(i, j) return (i - 1) * SEG + (j % SEG) + 1 end
  for i = 1, S - 1 do
    for j = 0, SEG - 1 do fs[#fs + 1] = {id(i, j), id(i, j + 1), id(i + 1, j + 1), id(i + 1, j)} end
  end
  vs[#vs + 1] = v3(0, 0.0, -1.01)
  local tip = #vs
  vs[#vs + 1] = v3(0, -0.12, 1.27)
  local nose = #vs
  for j = 0, SEG - 1 do
    fs[#fs + 1] = {tip, id(1, j + 1), id(1, j)}
    fs[#fs + 1] = {nose, id(S, j), id(S, j + 1)}
  end
  hull = solid(vs, fs)
end
local mouth = at(scale(sphere{radius=1, segments=22, rings=12}, {factor=MR, pivot=origin()}), MC.x, MC.y, MC.z)
local chin = bx(1.2, 0.6, 1.0, 0, JAW_Y - 0.3, JAW_Z + 0.5)
do
  local pit = at(extrude(rounded_rect{w=2 * PW, h=PZ1 - PZ0, radius=0.07, segments=3}, {distance=1.0}), 0, FL, (PZ0 + PZ1) / 2)
  local m = subtract(hull, mouth, pit, chin)
  m = paint(m, shell)
  m = paint_if(m, cream, function(f) return belly(f.center) end)
  m = paint_if(m, gum, function(f) return in_mouth(f.center) end)
  m = paint_if(m, dark, function(f) return in_pit(f.center) end)
  add(m, nil, 25)
end

-- The teeth: two rows of chunky white points round the mouth -- the upper ones down from the snout, the lower ones up
-- from the jaw (they go with it) -- the front row big, a smaller row behind.
local upper, lower = {}, {}
do
  local n = p.teeth
  for row = 0, 1 do
    local zc = MC.z + MR.z * (row == 0 and 0.48 or 0.28)
    local big = row == 0 and 1 or 0.72
    for i = 0, n - 1 - row do
      local x = (-0.21 + 0.42 * (i + row * 0.5) / (n - 1)) * (row == 0 and 1 or 0.9)
      local k = 1 - (x / MR.x) ^ 2 - ((zc - MC.z) / MR.z) ^ 2
      if k > 0.04 then
        local hh = MR.y * math.sqrt(k)
        local len = math.min(0.08, hh * 0.7) * big
        local r = 0.03 * big
        local function fang(list, y0, y1)
          list[#list + 1] = {along(cone{radius=r, height=math.abs(y1 - y0), segments=4, anchor="center"}, v3(x, y0, zc), v3(x, y1, zc)), tooth, 20}
        end
        fang(upper, MC.y + hh + 0.015, MC.y + hh - len)
        fang(lower, MC.y - hh - 0.015, MC.y - hh + len * 0.9)
      end
    end
  end
  for _, t in ipairs(upper) do add(t[1], t[2], t[3]) end
end

-- The eyes: small and cross, a white each with a black pupil looking forward, under a heavy slate brow.
for _, sx in ipairs({-1, 1}) do
  local ez = 0.86
  local ex = half_width(ez) * 0.86
  local ey = 0.07
  add(ball(0.03, 0.042, 0.05, sx * ex, ey, ez, 14), white, 30)
  add(ball(0.016, 0.026, 0.026, sx * (ex + 0.022), ey - 0.003, ez + 0.022, 10), black, 30)
  local brow = rb(0.035, 0.022, 0.13, 0, 0, 0, 0.008)
  brow = rotate(brow, {angle=sx * -18, axis=axis_z(), pivot=origin()})
  brow = rotate(brow, {angle=14, axis=axis_x(), pivot=origin()})
  add(at(brow, sx * (ex + 0.008), ey + 0.05, ez + 0.005), finc, 30)
end

-- The gills: three slits down each flank behind the eye, leaning back.
for _, sx in ipairs({-1, 1}) do
  for k = 0, 2 do
    local z = 0.5 + k * 0.07
    local x = half_width(z) * 0.985
    local g = rb(0.02, 0.17 - k * 0.015, 0.018, 0, 0, 0, 0.006)
    g = rotate(g, {angle=-12, axis=axis_x(), pivot=origin()})
    add(at(g, sx * x, -0.02, z), slit, 30)
  end
end

-- The tub's seat: a dark moulded bucket, its base under the hips and its back behind the driver.
do
  add(rb(0.46, 0.05, 0.4, 0, -0.245, -0.3, 0.015, 2), dark)
  local back = rb(0.5, 0.62, 0.08, 0, 0.0, 0, 0.02, 2)
  back = rotate(back, {angle=-10, axis=axis_x(), pivot=v3(0, -0.31, 0)})
  add(at(back, 0, 0.06, -0.55), black, 35)
  for _, sx in ipairs({-1, 1}) do
    local b = rb(0.07, 0.36, 0.2, 0, 0, 0, 0.015, 2)
    b = rotate(b, {angle=sx * 20, axis=axis_y(), pivot=origin()})
    add(at(b, sx * 0.25, -0.08, -0.46), black, 35)
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
-- The lower jaw: the chin under the mouth, cream outside, dark red inside, the lower teeth along it.
do
  local jaw = subtract(intersect(hull, chin), mouth)
  jaw = paint(jaw, cream)
  jaw = paint_if(jaw, gum, function(f) return in_mouth(f.center) end)
  local list = {{jaw, nil, 25}}
  for _, t in ipairs(lower) do list[#list + 1] = {t[1], t[2], angle=t[3]} end
  bit("jaw", list)
end

-- The side fins: swept back and drooping off the flanks between the wheels (clear of them: z -0.3..0.38, whatever
-- the steering or the springs do).
for _, sx in ipairs({-1, 1}) do
  local fin = slab({{0.0, 0.36}, {0.0, 0.06}, {0.3, -0.26}, {0.36, -0.24}, {0.24, 0.16}}, function(u, v, w)
    return v3(u, w * 0.026 * (1 - u * 1.6), v)
  end)
  fin = bevel(fin, {edges=convex_edges(fin, {min_angle=50}), width=0.006, segments=1})
  fin = rotate(fin, {angle=-26, axis=axis_z(), pivot=origin()})
  if sx < 0 then fin = mirror(fin, {normal=v3(1, 0, 0), pivot=origin()}) end
  bit(sx > 0 and "fin_l" or "fin_r", {{at(fin, sx * (half_width(0.15) - 0.05), -0.16, 0.02), finc, angle=30}})
end

-- The dorsal fin: small, behind the seat, raked back.
do
  local fin = slab({{-0.62, 0.17}, {-0.8, 0.5}, {-0.87, 0.49}, {-0.92, 0.17}}, function(u, v, w)
    return v3(w * 0.03 * (1 - (v - 0.17) * 1.5), v, u)
  end)
  fin = bevel(fin, {edges=convex_edges(fin, {min_angle=50}), width=0.008, segments=1})
  bit("dorsal", {{fin, finc, angle=30}})
end

-- The tail: the stalk's end and a short upright crescent -- an upper lobe swept up and back, a smaller one under it.
do
  local function lobe(pts)
    local m = slab(pts, function(u, v, w) return v3(w * 0.035, v, u) end)
    return bevel(m, {edges=convex_edges(m, {min_angle=50}), width=0.01, segments=1})
  end
  local stalk = at(scale(sphere{radius=1, segments=14, rings=8}, {factor=v3(0.06, 0.08, 0.16), pivot=origin()}), 0, 0.0, -1.02)
  local up = lobe({{-1.0, 0.02}, {-1.06, 0.12}, {-1.24, 0.5}, {-1.31, 0.52}, {-1.2, 0.2}, {-1.15, -0.02}})
  local dn = lobe({{-1.0, 0.0}, {-1.15, -0.04}, {-1.22, -0.26}, {-1.17, -0.27}, {-1.06, -0.1}})
  bit("tail", {{stalk, shell, angle=30}, {up, shell, angle=30}, {dn, shell, angle=30}})
end
