-- Jaws Ride: a whole cartoon shark for a kart body, one part "sharkkart". Slate grey on top, cream underneath, a big
-- open mouth out front with red gums and rows of white triangular teeth, black eyes, pectoral fins, the tail curving
-- up behind the driver into a tall fluke, an open cockpit cut into its back with a dark tub inside, all on a bright
-- yellow tube frame. The body is a blended field (sdf), meshed then thinned for a faceted toy look.
--
-- In the kart's body space, metres: the origin the middle of the (hidden) chassis box's top, +z forward, y up. The
-- cockpit keeps clear of x ±0.28, z -0.5..0.45 above y -0.2; the wheels (another slot) sit at x ±0.5, z ±0.7, y -0.42.
local p = params{
  girth       = {default=0.42, min=0.38, max=0.46, doc="Half the shark's width at its widest, metres"},
  gape        = {default=0.15, min=0.1, max=0.16, doc="Half the open mouth's height, metres"},
  tail_height = {default=1.3, min=1.05, max=1.5, doc="Height of the tail fluke's tips, metres"},
  teeth       = {default=9, min=5, max=11, integer=true, doc="Teeth along each jaw"},
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

local slate  = C(0.2, 0.25, 0.33)
local finc   = C(0.36, 0.43, 0.52)
local cream  = C(0.78, 0.72, 0.6)
local gum    = C(0.7, 0.03, 0.04)
local tooth  = C(0.95, 0.93, 0.85)
local black  = C(0.02, 0.02, 0.025)
local dark   = C(0.07, 0.07, 0.08)
local yellow = C(1.0, 0.62, 0.0)
local grey   = C(0.45, 0.46, 0.5)
local white  = C(1, 1, 1)

local W = p.girth
local G = p.gape
local TH = p.tail_height
local pieces = {}
-- While `sig` is true, what is added is the signature piece: the tail's fin (its fluke), flung off when the bodywork
-- goes.
local sig = false
local function add(m, c, angle) pieces[#pieces + 1] = {m, c, sig, angle=angle} end

-- The body ----------------------------------------------------------------------------------------------------
local BC, BR = v3(0, -0.05, 0.1), v3(W, 0.36, 1.05)
local MC, MR = v3(0, -0.14, 1.12), v3(0.37, G, 0.36)
local FL, PZ0, PZ1 = -0.26, -0.56, 0.46
local PW = 0.3
local function in_mouth(c)
  return ((c.x / MR.x) ^ 2 + ((c.y - MC.y) / MR.y) ^ 2 + ((c.z - MC.z) / MR.z) ^ 2) < 1.08
end
local function in_pit(c)
  return math.abs(c.x) < PW + 0.004 and c.y > FL - 0.004 and c.z > PZ0 - 0.004 and c.z < PZ1 + 0.004
end
do
  -- Rings along the spine, tail tip to snout: { z, y, half width, up, down } -- each a superellipse across the
  -- spine, so the tail's rings tilt as it curves up.
  local tl = TH - 0.68
  local st = {
    {-1.17, tl, 0.06, 0.06, 0.06},
    {-1.08, tl - 0.15, 0.09, 0.09, 0.09},
    {-0.95, tl - 0.37, 0.14, 0.14, 0.15},
    {-0.8, tl - 0.55, 0.2, 0.2, 0.22},
    {-0.62, -0.01, 0.27, 0.26, 0.29},
    {-0.4, -0.05, 0.34, 0.31, 0.34},
    {-0.1, -0.06, W * 0.97, 0.34, 0.36},
    {0.25, -0.06, W, 0.35, 0.36},
    {0.55, -0.06, W * 0.97, 0.34, 0.35},
    {0.8, -0.07, W * 0.87, 0.3, 0.32},
    {0.98, -0.09, W * 0.72, 0.25, 0.27},
    {1.1, -0.11, W * 0.52, 0.18, 0.2},
    {1.17, -0.12, W * 0.28, 0.1, 0.11},
  }
  local SEG, N = 22, 2.3
  local vs, fs = {}, {}
  local S = #st
  for i, s in ipairs(st) do
    local a = st[math.max(1, i - 1)]
    local b = st[math.min(S, i + 1)]
    local tz, ty = b[1] - a[1], b[2] - a[2]
    local tlen = math.sqrt(tz * tz + ty * ty)
    tz, ty = tz / tlen, ty / tlen
    local nz, ny = -ty, tz   -- the ring's "up", across the spine in the yz plane
    for j = 0, SEG - 1 do
      local t = 2 * math.pi * j / SEG
      local c, sn = math.cos(t), math.sin(t)
      local cx = (c < 0 and -1 or 1) * math.abs(c) ^ (2 / N)
      local sy = (sn < 0 and -1 or 1) * math.abs(sn) ^ (2 / N)
      local r = sy > 0 and s[4] or s[5]
      vs[#vs + 1] = v3(s[3] * cx, s[2] + ny * r * sy, s[1] + nz * r * sy)
    end
  end
  local function id(i, j) return (i - 1) * SEG + (j % SEG) + 1 end
  for i = 1, S - 1 do
    for j = 0, SEG - 1 do fs[#fs + 1] = {id(i, j), id(i, j + 1), id(i + 1, j + 1), id(i + 1, j)} end
  end
  -- the ends closed with a point each: the tail's tip and the snout
  vs[#vs + 1] = v3(0, tl + 0.03, -1.2)
  local tip = #vs
  vs[#vs + 1] = v3(0, -0.12, 1.21)
  local nose = #vs
  for j = 0, SEG - 1 do
    fs[#fs + 1] = {tip, id(1, j + 1), id(1, j)}
    fs[#fs + 1] = {nose, id(S, j), id(S, j + 1)}
  end
  local m = solid(vs, fs)

  local mouth = at(scale(sphere{radius=1, segments=20, rings=10}, {factor=MR, pivot=origin()}), MC.x, MC.y, MC.z)
  local pit = at(extrude(rounded_rect{w=2 * PW, h=PZ1 - PZ0, radius=0.07, segments=3}, {distance=1.0}), 0, FL, (PZ0 + PZ1) / 2)
  m = subtract(m, mouth, pit)
  m = paint(m, slate)
  -- the belly, cream below a line that rises towards the tail
  m = paint_if(m, cream, function(f)
    local c = f.center
    local line = -0.14 + math.max(0, -0.45 - c.z) * 0.7
    return c.y < line
  end)
  m = paint_if(m, gum, function(f) return in_mouth(f.center) end)
  m = paint_if(m, dark, function(f) return in_pit(f.center) end)
  add(m, nil, 25)
end

-- The front surface of the body at (x, y): its z.
local function front_z(x, y)
  local k = 1 - (x / BR.x) ^ 2 - ((y - BC.y) / BR.y) ^ 2
  return BC.z + BR.z * math.sqrt(math.max(0, k))
end

-- The teeth: white triangular points along both gums, pointing into the mouth.
do
  local n = p.teeth
  for i = 0, n - 1 do
    local x = -0.24 + 0.48 * i / (n - 1)
    local z = front_z(x, MC.y) - 0.035
    local k = 1 - (x / MR.x) ^ 2 - ((z - MC.z) / MR.z) ^ 2
    if k > 0.05 then
      local hh = MR.y * math.sqrt(k)
      local len = math.min(0.075, hh * 0.75)
      local function fang(y0, y1, r)
        add(along(cone{radius=r, height=math.abs(y1 - y0), segments=4, anchor="center"}, v3(x, y0, z), v3(x, y1, z)), tooth, 20)
      end
      fang(MC.y + hh + 0.012, MC.y + hh - len, 0.024)
      local xl = x + 0.024
      if i < n - 1 then
        local kl = 1 - (xl / MR.x) ^ 2 - ((z - MC.z) / MR.z) ^ 2
        if kl > 0.05 then
          local hl = MR.y * math.sqrt(kl)
          add(along(cone{radius=0.021, height=math.min(0.065, hl * 0.7) + 0.012, segments=4, anchor="center"},
            v3(xl, MC.y - hl - 0.012, z - 0.01), v3(xl, MC.y - hl + math.min(0.065, hl * 0.7), z - 0.01)), tooth, 20)
        end
      end
    end
  end
end

-- The eyes: black beads with a glint, high on the head's sides.
for _, sx in ipairs({-1, 1}) do
  local ex, ey, ez = W * 0.8, 0.06, 0.76
  add(ball(0.05, 0.055, 0.055, sx * ex, ey, ez, 12), black, 30)
  add(ball(0.014, 0.014, 0.014, sx * (ex + 0.035), ey + 0.025, ez + 0.02, 6), white, 30)
end

-- The pectoral fins: flat, swept back, drooping off the flanks.
for _, sx in ipairs({-1, 1}) do
  local fin = slab({{0.0, 0.34}, {0.0, 0.04}, {0.33, -0.24}, {0.38, -0.2}, {0.27, 0.15}}, function(u, v, w)
    return v3(u, w * 0.024 * (1 - u * 1.6), v)
  end)
  fin = bevel(fin, {edges=convex_edges(fin, {min_angle=50}), width=0.005, segments=1})
  fin = rotate(fin, {angle=-28, axis=axis_z(), pivot=origin()})
  if sx < 0 then fin = mirror(fin, {normal=v3(1, 0, 0), pivot=origin()}) end
  add(at(fin, sx * (W - 0.06), -0.17, 0.12), finc, 30)
end

-- The tail fluke: two lobes, flat across x, the front one rising forward, the back one sweeping back.
do
  local function lobe(pts)
    local m = slab(pts, function(u, v, w) return v3(w * 0.035, v, u) end)
    return bevel(m, {edges=convex_edges(m, {min_angle=50}), width=0.012, segments=1})
  end
  sig = true
  add(lobe({{-1.02, TH - 0.8}, {-0.86, TH}, {-0.97, TH - 0.03}, {-1.21, TH - 0.6}}), slate, 30)
  add(lobe({{-1.13, TH - 0.74}, {-1.47, TH - 0.04}, {-1.56, TH - 0.1}, {-1.27, TH - 0.78}}), slate, 30)
  sig = false
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
    -- saddles from the upper rail up into the shark's belly
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
