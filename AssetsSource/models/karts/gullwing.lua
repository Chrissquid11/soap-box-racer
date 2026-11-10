-- A boxy brushed-steel 1980s gull-wing coupe for a kart body, one part
-- "gullwing". A wedge bonnet with an orange grab-hoop and a "38" roundel (a white disc in a black ring), quad
-- rectangular headlamps either side of a black grille, a black lower body and bumpers, both doors swung up open off
-- roof rails, a fastback rear block with a louvred rear window, side louvres, orange-red tail lamps, blank plates
-- front and back, and a stack of chunky gadget boxes and pipe loops on the rear deck. Under it a dark tube frame.
--
-- In the kart's body space, metres: the origin the middle of the (hidden) chassis box's top, +z forward, y up. The
-- cockpit keeps clear of x +-0.28, z -0.5..0.45 above y -0.2; the wheels (another slot) sit at x +-0.5, z +-0.7,
-- y -0.42.
local p = params{
  door_angle  = { default = 28, min = 10, max = 50, doc = "How far the open doors' outer panels tip up past level, degrees" },
  louvres     = { default = 6, min = 3, max = 9, integer = true, doc = "Slats across the louvred rear window" },
  hoop_height = { default = 0.13, min = 0.07, max = 0.2, doc = "Height of the orange grab-hoop on the bonnet, metres" },
  gadgets     = { default = true, doc = "The stack of gadget boxes and pipe loops on the rear deck" },
}

local PAINT = material{name="Paint", base_color=v3(1, 1, 1), roughness=0.45, metallic=0}

local function all(m) return faces_where(m, function(_) return true end) end
local function paint(m, c) return paint_faces(m, {faces=all(m), color=c}) end
local function part(name, pieces)
  local out = {}
  for i, q in ipairs(pieces) do
    local m = q[2] and paint(q[1], q[2]) or q[1]
    out[i] = {mesh=smooth_normals(m, {angle=q[3] or 30}), material=PAINT}
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
local function bar(a0, b0, s)
  local a, b = lerp(a0, b0, 0.002), lerp(a0, b0, 0.998)
  return along(box{size=v3(s, length(b - a), s)}, a, b)
end
local function tube(pts, r, seg)
  return sweep(circle{radius=r, segments=seg or 8}, path{points=pts}, {caps=true})
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
-- Eight corners (a quad, then the same quad moved) as a solid.
local function hexa(q)
  return solid(q, {{1, 2, 3, 4}, {5, 8, 7, 6}, {1, 5, 6, 2}, {2, 6, 7, 3}, {3, 7, 8, 4}, {4, 8, 5, 1}})
end

local steel    = C(0.74, 0.76, 0.79)
local steel_dk = C(0.6, 0.62, 0.66)
local black    = C(0.06, 0.06, 0.07)
local dark     = C(0.17, 0.17, 0.19)
local grey     = C(0.38, 0.39, 0.42)
local silver   = C(0.84, 0.86, 0.9)
local orange   = C(1.0, 0.45, 0.06)
local tail     = C(0.95, 0.27, 0.06)
local amber    = C(1.0, 0.62, 0.1)
local lamp     = C(0.8, 0.9, 0.95)
local white    = C(0.96, 0.96, 0.94)
local glass    = C(0.12, 0.14, 0.17)

local pieces = {}
-- While `sig` is true, what is added is the signature piece: the +x gull-wing door, flung off when the bodywork goes.
local sig = false
local function add(m, c, a) pieces[#pieces + 1] = {m, c, a, sig} end

local W = 0.38          -- the body's half-width
local YB = -0.36        -- the steel body's bottom
local ZF, ZR = 1.08, -1.08
local CF, CR = 0.45, -0.56   -- the cockpit's front and back

-- A chamfered section at z: half-width w, from YB up to its top yt.
local function sect(z, w, yt, ch)
  ch = ch or 0.06
  return { v3(w, YB, z), v3(w, yt - ch, z), v3(w - ch, yt, z), v3(-(w - ch), yt, z), v3(-w, yt - ch, z), v3(-w, YB, z) }
end

-- The bonnet: a wedge from the dash forward, its top falling to the nose.
local function bonnet_top(z) return 0.06 - 0.1 * (z - CF) / (ZF - CF) end
add(loft_rings({ sect(CF, W, bonnet_top(CF)), sect(ZF - 0.04, W, bonnet_top(ZF - 0.04)), sect(ZF, W - 0.02, bonnet_top(ZF) - 0.02, 0.05) }), steel, 20)
-- The rear block: a flat top behind the seat, then a fastback down to the tail.
local DECK = 0.6
add(loft_rings({ sect(CR, W, DECK), sect(-0.78, W, DECK), sect(ZR + 0.04, W, 0.3), sect(ZR, W - 0.02, 0.28, 0.05) }), steel, 20)
-- The sides of the cockpit, up to the door sills; the floor.
for _, sx in ipairs({-1, 1}) do
  add(rb(0.07, 0.4, CF - CR + 0.02, sx * (W - 0.035), YB + 0.2, (CF + CR) * 0.5, 0.015), steel, 20)
end
add(rb(2 * W - 0.1, 0.04, CF - CR, 0, -0.32, (CF + CR) * 0.5, 0.01), dark, 20)

-- The black lower body: skirts down each side and round the ends, and chunky bumpers.
for _, sx in ipairs({-1, 1}) do
  add(rb(0.03, 0.17, ZF - ZR - 0.02, sx * (W + 0.008), YB + 0.075, 0, 0.008), black, 20)
end
add(rb(2 * W + 0.02, 0.17, 0.03, 0, YB + 0.075, ZF + 0.002, 0.008), black, 20)
add(rb(2 * W + 0.02, 0.17, 0.03, 0, YB + 0.075, ZR - 0.002, 0.008), black, 20)
for _, sz in ipairs({-1, 1}) do
  add(rb(2 * W + 0.08, 0.13, 0.12, 0, -0.34, sz * (ZF + 0.05), 0.03), black, 20)
end

-- The front: quad rectangular headlamps either side, a black grille between, indicators, a blank plate.
do
  local fz = ZF + 0.004
  local ly = -0.16
  for _, sx in ipairs({-1, 1}) do
    add(rb(0.26, 0.112, 0.032, sx * 0.24, ly, fz, 0.006), black, 20)
    for _, x in ipairs({0.17, 0.3}) do
      add(rb(0.1, 0.07, 0.03, sx * x, ly, fz + 0.012, 0.008), lamp, 20)
    end
    add(rb(0.08, 0.04, 0.03, sx * 0.3, -0.33, ZF + 0.115, 0.006), amber, 20)
  end
  add(rb(0.2, 0.11, 0.03, 0, ly, fz, 0.006), black, 20)
  for i = 0, 2 do add(rb(0.18, 0.012, 0.02, 0, ly - 0.035 + i * 0.035, fz + 0.012, 0.003), grey, 20) end
  for i = -1, 1 do add(rb(0.012, 0.1, 0.02, i * 0.05, ly, fz + 0.012, 0.003), grey, 20) end
end
-- A blank plate: a pale panel with two grey stripes for its letters.
local function plate(z, dir)
  add(rb(0.3, 0.09, 0.02, 0, -0.33, z, 0.006), C(0.88, 0.88, 0.86), 20)
  for _, y in ipairs({-0.312, -0.348}) do add(rb(0.22, 0.016, 0.02, 0, y, z + dir * 0.006, 0.004), grey, 20) end
end
plate(ZF + 0.115, 1)
plate(ZR - 0.115, -1)

-- The bonnet's orange grab-hoop and its "38" roundel (a white disc, a black ring), tilted to the bonnet's slope.
do
  local slope = deg(math.atan(0.1 / (ZF - CF)))
  local hz = 0.78
  local hy = bonnet_top(hz)
  local H = p.hoop_height
  local pts = {}
  for i = 0, 10 do
    local t = math.pi * i / 10
    pts[#pts + 1] = v3(-0.17 * math.cos(t), hy - 0.01 + H * math.sin(t) ^ 0.6, hz)
  end
  add(tube(pts, 0.018, 10), orange, 40)
  for _, sx in ipairs({-1, 1}) do add(cyl(0.032, 0.02, sx * 0.17, hy + 0.005, hz, "y", 10), dark, 40) end
  local rz = 0.62
  local ry = bonnet_top(rz)
  local ring = cylinder{radius=0.115, height=0.012, segments=24}
  local disc = cylinder{radius=0.082, height=0.016, segments=24}
  ring = rotate(ring, {angle=slope, axis=axis_x(), pivot=origin()})
  disc = rotate(disc, {angle=slope, axis=axis_x(), pivot=origin()})
  add(at(ring, 0.22, ry + 0.002, rz), black, 40)
  add(at(disc, 0.22, ry + 0.004, rz), white, 40)
end

-- The dash: a black panel on the bonnet's back, and the steering column into it.
add(rb(2 * W - 0.1, 0.16, 0.04, 0, -0.04, CF - 0.01, 0.01), black, 20)
add(rod(v3(0, 0.1, 0.15), v3(0, -0.02, CF - 0.02), 0.022, 10), black, 40)
add(cyl(0.035, 0.05, 0, 0.08, 0.17, "y", 10), black, 40)

-- The seat: a black bucket against the rear block.
add(rbox(0.46, 0.05, 0.4, 0.07, 0, -0.27, -0.3, 0.015), black, 40)
do
  local m = rb(0.48, 0.62, 0.07, 0, 0.31, 0, 0.02)
  m = rotate(m, {angle=-8, axis=axis_x(), pivot=origin()})
  add(at(m, 0, -0.27, CR + 0.02), dark, 40)
  for _, sx in ipairs({-1, 1}) do
    local b = rb(0.06, 0.4, 0.14, 0, 0.2, 0, 0.015)
    b = rotate(b, {angle=sx * 25, axis=axis_y(), pivot=origin()})
    add(at(b, sx * 0.24, -0.25, CR + 0.06), black, 40)
  end
end

-- The windscreen frame and roof rails: black A-pillars up from the bonnet, a header ahead of the cockpit, rails back
-- to the rear block that the doors hang from.
local RX, RY = 0.32, DECK
local HZ = CF + 0.03
for _, sx in ipairs({-1, 1}) do
  add(bar(v3(sx * (W - 0.03), 0.03, CF + 0.12), v3(sx * RX, RY, HZ), 0.05), black, 20)
  add(bar(v3(sx * RX, RY, HZ), v3(sx * RX, RY, CR - 0.04), 0.05), black, 20)
end
add(bar(v3(-RX, RY, HZ), v3(RX, RY, HZ), 0.05), black, 20)

-- The doors, swung up open: each a roof panel standing up off its rail, then the side panel tipping out and up from
-- its top, a dark window in it; a gas strut holding it.
do
  local a = math.rad(p.door_angle)
  local RH = 0.36      -- the roof panel's height
  local SL = 0.56      -- the side panel's length
  local T = 0.05
  for _, sx in ipairs({-1, 1}) do
    -- a slab from p0 to p1 (x, y), its inner edge spanning z0 (back, front), its outer z1
    local function slab(p0, p1, z0, z1, c)
      local d = normalize(p1 - p0)
      local n = v3(-d.y, d.x, 0) * (T * 0.5)
      local q = {
        p0 - n + v3(0, 0, z0[1]), p0 - n + v3(0, 0, z0[2]), p1 - n + v3(0, 0, z1[2]), p1 - n + v3(0, 0, z1[1]),
        p0 + n + v3(0, 0, z0[1]), p0 + n + v3(0, 0, z0[2]), p1 + n + v3(0, 0, z1[2]), p1 + n + v3(0, 0, z1[1]),
      }
      local m = hexa(q)
      m = bevel(m, {edges=convex_edges(m, {min_angle=50}), width=0.008, segments=1})
      add(m, c, 20)
      return d, n
    end
    local base = v3(sx * RX, RY + 0.03, 0)
    local top = v3(sx * RX, RY + RH, 0)
    local tip = top + v3(sx * math.cos(a), math.sin(a), 0) * SL
    sig = sx > 0
    slab(base, top, {-0.5, 0.36}, {-0.5, 0.3}, steel)
    local d, n = slab(top, tip, {-0.5, 0.3}, {-0.46, 0.4}, steel)
    -- the window: a dark pane through the side panel near its top
    local w0 = top + d * 0.06
    local w1 = top + d * 0.3
    local m = hexa({
      w0 - n * 1.4 + v3(0, 0, -0.36), w0 - n * 1.4 + v3(0, 0, 0.2), w1 - n * 1.4 + v3(0, 0, 0.24), w1 - n * 1.4 + v3(0, 0, -0.36),
      w0 + n * 1.4 + v3(0, 0, -0.36), w0 + n * 1.4 + v3(0, 0, 0.2), w1 + n * 1.4 + v3(0, 0, 0.24), w1 + n * 1.4 + v3(0, 0, -0.36),
    })
    add(m, glass, 20)
    sig = false
    -- the hinges on the rail
    for _, z in ipairs({-0.35, 0.2}) do add(rb(0.06, 0.05, 0.06, sx * RX, RY + 0.04, z, 0.01), grey, 20) end
    -- the gas strut from the sill up to the side panel's underside
    local sp = top + d * 0.38 - n
    add(rod(v3(sx * (W - 0.04), 0.06, -0.12), v3(sp.x, sp.y, -0.12), 0.016, 8), silver, 40)
    add(rod(v3(sx * (W - 0.04), 0.06, -0.12), lerp(v3(sx * (W - 0.04), 0.06, -0.12), v3(sp.x, sp.y, -0.12), 0.5), 0.024, 8), dark, 40)
  end
end

-- The rear: louvres across the fastback, side louvres in the quarters, orange-red tail lamps.
do
  local slope = deg(math.atan((DECK - 0.3) / ((-0.78) - (ZR + 0.04))))
  local n = p.louvres
  local panel = rb(2 * W - 0.14, 0.02, 0.3, 0, 0, 0, 0.005)
  panel = rotate(panel, {angle=slope, axis=axis_x(), pivot=origin()})
  local mid = lerp(v3(0, DECK, -0.78), v3(0, 0.3, ZR + 0.04), 0.5)
  add(at(panel, 0, mid.y + 0.005, mid.z), glass, 20)
  for i = 1, n do
    local t = (i - 0.5) / n
    local c = lerp(v3(0, DECK, -0.8), v3(0, 0.3, ZR + 0.06), t)
    local s = rb(2 * W - 0.1, 0.022, 0.03, 0, 0, 0, 0.006)
    s = rotate(s, {angle=slope - 25, axis=axis_x(), pivot=origin()})
    add(at(s, 0, c.y + 0.025, c.z), black, 20)
  end
  for _, sx in ipairs({-1, 1}) do
    for i = 0, 3 do
      add(rb(0.02, 0.025, 0.24, sx * (W + 0.002), 0.4 - i * 0.06, -0.8, 0.006), black, 20)
    end
    -- tail lamps: a dark surround, orange-red lenses in a grid
    add(rb(0.26, 0.13, 0.03, sx * 0.22, 0.02, ZR - 0.004, 0.006), black, 20)
    for gx = 0, 2 do
      for gy = 0, 1 do
        add(rb(0.072, 0.05, 0.02, sx * (0.14 + gx * 0.08), -0.008 + gy * 0.058, ZR - 0.016, 0.006), gx == 0 and amber or tail, 20)
      end
    end
  end
  add(rb(0.3, 0.13, 0.025, 0, 0.02, ZR - 0.004, 0.006), steel_dk, 20)
end

-- The gadgets on the deck: chunky grey boxes stacked across it, two big pipe loops over them, a canister.
if p.gadgets then
  local y = DECK
  add(rb(0.56, 0.1, 0.18, 0, y + 0.05, -0.68, 0.015), dark, 20)
  add(rb(0.2, 0.1, 0.14, -0.17, y + 0.15, -0.69, 0.015), grey, 20)
  add(rb(0.16, 0.08, 0.12, 0.18, y + 0.14, -0.67, 0.015), grey, 20)
  add(rb(0.12, 0.06, 0.1, 0.18, y + 0.21, -0.67, 0.012), dark, 20)
  for _, sx in ipairs({-1, 1}) do add(rb(0.06, 0.04, 0.03, sx * 0.17, y + 0.08, -0.585, 0.008), C(0.2, 0.7, 0.3), 20) end
  add(cyl(0.05, 0.16, 0, y + 0.18, -0.7, "y", 12), silver, 40)
  add(cyl(0.056, 0.02, 0, y + 0.27, -0.7, "y", 12), dark, 40)
  for _, x in ipairs({-0.07, 0.07}) do
    local pts = {}
    for i = 0, 12 do
      local t = math.pi * i / 12
      pts[#pts + 1] = v3(x, y + 0.1 + 0.2 * math.sin(t), -0.68 - 0.13 * math.cos(t))
    end
    add(tube(pts, 0.025, 10), silver, 40)
    for _, k in ipairs({1, 13}) do add(cyl(0.036, 0.04, pts[k].x, y + 0.11, pts[k].z, "y", 10), grey, 40) end
  end
end

-- The frame: dark tube under it all -- side rails, axle crossbars and stubs.
do
  local FX, FY, TR = 0.26, -0.47, 0.022
  local function tb(a, b, r) add(rod(a, b, r or TR, 8), dark, 40) end
  for _, sx in ipairs({-1, 1}) do
    tb(v3(sx * FX, FY, -1.05), v3(sx * FX, FY, 1.05))
    for _, z in ipairs({-0.7, 0.7}) do
      add(rod(v3(sx * 0.46, -0.42, z), v3(sx * 0.535, -0.42, z), 0.02, 10), grey, 40)
      add(cyl(0.034, 0.03, sx * 0.47, -0.42, z, "x", 8), silver, 40)
    end
  end
  for _, z in ipairs({-0.7, 0.7}) do tb(v3(-0.47, -0.42, z), v3(0.47, -0.42, z), 0.024) end
  tb(v3(-FX, FY, -1.04), v3(FX, FY, -1.04))
  tb(v3(-FX, FY, 1.04), v3(FX, FY, 1.04))
end

part("gullwing", pieces)
