-- Moon Rocket: a white rocket capsule lying along z for a kart body, one part "moonrocket". A pointed nose cone out
-- front with a little hole in its tip, a flat rounded back, two dark grey bands round it, an open cockpit cut into its
-- top with a black bucket seat, a round navy mission badge and a striped flag painted on each side, all on a dark
-- grey tube frame.
--
-- In the kart's body space, metres: the origin the middle of the (hidden) chassis box's top, +z forward, y up. The
-- cockpit keeps clear of x ±0.28, z -0.5..0.45 above y -0.2; the wheels (another slot) sit at x ±0.5, z ±0.7, y -0.42.
local p = params{
  radius      = {default=0.4, min=0.36, max=0.42, doc="The rocket's radius, metres"},
  nose_length = {default=0.78, min=0.55, max=0.95, doc="Length of the nose cone, metres"},
  band_width  = {default=0.1, min=0.06, max=0.14, doc="Width of the dark grey bands, metres"},
  recline     = {default=10, min=0, max=20, doc="The seat back's recline, degrees"},
}

local PAINT = material{name="Paint", base_color=v3(1, 1, 1), roughness=0.5, metallic=0}

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
local function rod(a0, b0, r, seg)
  local a, b = lerp(a0, b0, 0.004), lerp(a0, b0, 0.996)
  local d = b - a
  local m = cylinder{radius=r, height=length(d), segments=seg or 8}
  local dir = normalize(d)
  local c = dot(v3(0, 1, 0), dir)
  if c < -0.9999 then m = rotate(m, {angle=180, axis=axis_x(), pivot=origin()})
  elseif c < 0.9999 then m = rotate(m, {angle=deg(math.acos(c)), axis=normalize(cross(v3(0, 1, 0), dir)), pivot=origin()}) end
  return translate(m, (a + b) * 0.5)
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
-- A solid of revolution about +z from { radius, z } pairs, counter-clockwise seen with radius right and z up.
local function lathe_z(pts, seg)
  local ps = {}
  for i, q in ipairs(pts) do ps[i] = v2(q[1], q[2]) end
  return rotate(revolve(poly{points=ps}, {segments=seg or 24}), {angle=90, axis=axis_x(), pivot=origin()})
end

local black  = C(0.035, 0.035, 0.04)
local dark   = C(0.1, 0.1, 0.11)
local band   = C(0.22, 0.22, 0.24)
local frameg = C(0.28, 0.29, 0.31)
local grey   = C(0.45, 0.46, 0.5)
local white  = C(0.93, 0.93, 0.92)
local navy   = C(0.02, 0.04, 0.2)
local gold   = C(0.85, 0.6, 0.05)
local moon   = C(0.55, 0.55, 0.58)
local red    = C(0.75, 0.03, 0.04)
local flagb  = C(0.03, 0.07, 0.4)
local orange = C(1.0, 0.4, 0.02)
local pure   = C(1, 1, 1)

local R = p.radius
local AY = -0.02             -- the rocket's axis height
local ZB, ZC = -0.88, 0.5    -- its flat back, and where the nose cone starts
local TIP = ZC + p.nose_length
local pieces = {}
-- While `sig` is true, what is added is the signature piece: the rear band, rolled off when the bodywork goes.
local sig = false
local function add(m, c, angle) pieces[#pieces + 1] = {m, c, sig, angle=angle} end

-- The rocket --------------------------------------------------------------------------------------------------
do
  local prof = {{0, ZB}, {R * 0.72, ZB}, {R * 0.9, ZB + 0.012}, {R * 0.97, ZB + 0.03}, {R, ZB + 0.06}, {R, ZC}}
  local N = 8
  for i = 1, N - 1 do
    local t = i / N
    prof[#prof + 1] = {R * math.cos(t * math.pi / 2) ^ 0.7, ZC + t * (TIP - ZC)}
  end
  -- the tip, blunt, with a little hole in it
  prof[#prof + 1] = {0.045, TIP}
  prof[#prof + 1] = {0.022, TIP}
  prof[#prof + 1] = {0.022, TIP - 0.05}
  prof[#prof + 1] = {0, TIP - 0.05}
  local body = at(lathe_z(prof, 24), 0, AY, 0)

  -- The cockpit: a round-cornered well cut down into the top, its floor under the driver's legs.
  local FL = -0.26
  local Z0, Z1 = -0.58, 0.49
  local HW = 0.31
  local hole = at(extrude(rounded_rect{w=2 * HW, h=Z1 - Z0, radius=0.08, segments=4}, {distance=0.9}), 0, FL, (Z0 + Z1) / 2)
  body = subtract(body, hole)
  body = paint(body, white)
  body = paint_if(body, dark, function(f)
    local c = f.center
    return math.abs(c.x) < HW + 0.003 and c.y > FL - 0.003 and c.z > Z0 - 0.003 and c.z < Z1 + 0.003
  end)
  body = paint_if(body, black, function(f)
    local c = f.center
    return c.z > TIP - 0.055 and math.sqrt(c.x * c.x + (c.y - AY) ^ 2) < 0.03
  end)
  add(body, nil, 30)

  -- The two bands round it: rings standing proud of the skin.
  local bw = p.band_width
  for _, zc in ipairs({-0.72, ZC + 0.05}) do
    local a, b = zc - bw / 2, zc + bw / 2
    sig = zc < 0
    add(at(lathe_z({{R - 0.012, a}, {R + 0.018, a}, {R + 0.026, a + 0.008}, {R + 0.026, b - 0.008}, {R + 0.018, b},
      {R - 0.012, b}}, 24), 0, AY, 0), band, 30)
    sig = false
  end
end

-- The decals: thin painted shells lying on the rocket's side, each a convex outline of { z, y } points.
local function decal(pts, sx, lift, col)
  local vs, fs = {}, {}
  local n = #pts
  local function surf(z, y, off)
    local dy = y - AY
    return v3(sx * (math.sqrt(math.max(0, R * R - dy * dy)) + off), y, z)
  end
  local cz, cy = 0, 0
  for i, q in ipairs(pts) do
    vs[i] = surf(q[1], q[2], lift)
    vs[n + i] = surf(q[1], q[2], -0.004 - lift)
    cz, cy = cz + q[1], cy + q[2]
  end
  vs[2 * n + 1] = surf(cz / n, cy / n, lift)
  vs[2 * n + 2] = surf(cz / n, cy / n, -0.004 - lift)
  for i = 1, n do
    local j = i % n + 1
    fs[#fs + 1] = {2 * n + 1, i, j}
    fs[#fs + 1] = {2 * n + 2, n + j, n + i}
    fs[#fs + 1] = {i, n + i, n + j}
    fs[#fs + 1] = {i, n + j, j}
  end
  add(solid(vs, fs), col, 20)
end
local function disc(cz, cy, r, n, a0, a1)
  local pts = {}
  a0, a1 = a0 or 0, a1 or 360
  local full = (a1 - a0) >= 360
  local m = full and n - 1 or n
  for i = 0, m do
    local t = math.rad(a0 + (a1 - a0) * i / n)
    pts[#pts + 1] = {cz + r * math.cos(t), cy + r * math.sin(t)}
  end
  return pts
end
local function rect(z0, y0, z1, y1) return {{z0, y0}, {z1, y0}, {z1, y1}, {z0, y1}} end

for _, sx in ipairs({-1, 1}) do
  -- The mission badge: a gold rim, navy sky, a grey moon, a few stars and a little rocket taking off.
  local BZ, BY, K = 0.1, AY + 0.01, 1.3
  -- an outline drawn about the badge's middle at a unit size, placed and scaled up
  local function B(pts)
    local o = {}
    for i, q in ipairs(pts) do o[i] = {BZ + K * q[1], BY + K * q[2]} end
    return o
  end
  decal(B(disc(0, 0, 0.135, 28)), sx, 0.005, gold)
  decal(B(disc(0, 0, 0.115, 28)), sx, 0.009, navy)
  decal(B(disc(0, 0, 0.112, 12, 205, 335)), sx, 0.012, moon)
  for _, s in ipairs({{-0.06, 0.05}, {0.065, 0.06}, {-0.04, 0.085}, {0.075, 0.0}, {-0.075, -0.005}, {0.035, 0.09}}) do
    local z, y, d = s[1], s[2], 0.009
    decal(B({{z + d, y}, {z, y + d}, {z - d, y}, {z, y - d}}), sx, 0.013, pure)
  end
  -- the rocket: body, nose, fins and its flame
  decal(B(rect(-0.012, -0.03, 0.012, 0.045)), sx, 0.015, pure)
  decal(B({{-0.012, 0.045}, {0.012, 0.045}, {0, 0.075}}), sx, 0.016, red)
  decal(B({{-0.012, -0.03}, {-0.012, 0}, {-0.03, -0.035}}), sx, 0.016, red)
  decal(B({{0.012, -0.03}, {0.03, -0.035}, {0.012, 0}}), sx, 0.016, red)
  decal(B({{-0.009, -0.032}, {0.009, -0.032}, {0, -0.07}}), sx, 0.016, orange)

  -- The flag: red and white stripes, a blue canton towards the nose, a few white stars on it.
  local FZ0, FZ1, FY0, FY1 = -0.6, -0.2, AY - 0.1, AY + 0.14
  decal(rect(FZ0, FY0, FZ1, FY1), sx, 0.005, white)
  local h = (FY1 - FY0) / 7
  for k = 0, 6, 2 do decal(rect(FZ0 + 0.004, FY0 + k * h + 0.002, FZ1 - 0.004, FY0 + (k + 1) * h - 0.002), sx, 0.008, red) end
  local cz0, cy0 = FZ1 - 0.17, FY1 - 4 * h
  decal(rect(cz0, cy0, FZ1 - 0.004, FY1 - 0.003), sx, 0.011, flagb)
  for i = 0, 2 do
    for j = 0, 1 do
      local z, y, d = cz0 + 0.03 + i * 0.053, cy0 + 0.035 + j * 0.06, 0.008
      decal({{z + d, y}, {z, y + d}, {z - d, y}, {z, y - d}}, sx, 0.014, pure)
    end
  end
end

-- The seat: a black bucket, its base under the hips, its high bolstered back behind the driver, reclined.
do
  add(rb(0.44, 0.05, 0.38, 0, -0.245, -0.3, 0.015, 2), black)
  local function outline(pts)
    local o = {}
    for i, q in ipairs(pts) do o[i] = v2(q[1], q[2]) end
    return o
  end
  local backp = poly{
    points=outline({{-0.22, -0.24}, {0.22, -0.24}, {0.24, 0.2}, {0.21, 0.36}, {0.155, 0.42}, {0.15, 0.6},
                    {0.11, 0.65}, {-0.11, 0.65}, {-0.15, 0.6}, {-0.155, 0.42}, {-0.21, 0.36}, {-0.24, 0.2}}),
    holes={outline({{-0.07, 0.47}, {-0.07, 0.52}, {0.07, 0.52}, {0.07, 0.47}})},
  }
  local function stand(pr, thick, x0, y0, z1)
    local m = rotate(extrude(pr, {distance=thick}), {angle=90, axis=axis_x(), pivot=origin()})
    local b = bbox(m)
    return translate(m, v3(x0 - b.min.x, y0 - b.min.y, z1 - b.max.z))
  end
  local back = stand(backp, 0.09, -0.25, -0.24, -0.545)
  back = translate(back, v3(-bbox(back).center.x, 0, 0))
  local bol = poly{points=outline({{0.16, -0.22}, {0.235, -0.22}, {0.25, 0.2}, {0.215, 0.35}, {0.16, 0.33}, {0.175, 0.2}})}
  local b1 = stand(bol, 0.075, 0.16, -0.22, -0.502)
  local b2 = mirror(b1, {normal=v3(1, 0, 0), pivot=origin()})
  local seat = join(back, b1, b2)
  seat = rotate(seat, {angle=-p.recline, axis=axis_x(), pivot=v3(0, -0.24, -0.5)})
  add(seat, black, 35)
  local stitch = rotate(bx(0.3, 0.025, 0.004, 0, 0.12, -0.545 + 0.0015), {angle=-p.recline, axis=axis_x(), pivot=v3(0, -0.24, -0.5)})
  add(stitch, dark)
end

-- The steering column: from under the wheel's hub forward and down into the cockpit's front wall.
add(rod(v3(0, 0.115, 0.15), v3(0, 0.0, 0.5), 0.018, 10), dark)
add(at(scale(sphere{radius=1, segments=14, rings=7}, {factor=v3(0.05, 0.05, 0.02), pivot=origin()}), 0, 0.0, 0.49), black)

-- The frame: dark grey tube under the rocket ---------------------------------------------------------------------
do
  local TR = 0.02
  local function tb(a, b, r) add(rod(a, b, r or TR, 10), frameg, 40) end
  local function knot(v, r) add(ball(r or TR * 1.15, r or TR * 1.15, r or TR * 1.15, v.x, v.y, v.z, 10), frameg, 40) end
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
    -- diagonal braces between the rails
    local zs = {-0.78, -0.36, 0.06, 0.42, 0.78}
    for i = 1, #zs - 1 do
      local a = (i % 2 == 1) and v3(s * LX, LY, zs[i]) or v3(s * UX, UY, zs[i])
      local b = (i % 2 == 1) and v3(s * UX, UY, zs[i + 1]) or v3(s * LX, LY, zs[i + 1])
      tb(a, b, TR * 0.8)
    end
    -- saddles from the upper rail up into the rocket's belly
    for _, z in ipairs({-0.42, 0.28}) do tb(v3(s * UX, UY, z), v3(s * 0.3, -0.26, z), TR * 0.8) end
    -- the axle stubs and the uprights to the crossbars' ends
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

part("moonrocket", pieces)
