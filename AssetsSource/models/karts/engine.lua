-- Little Number Three: a chunky toy steam tank-engine for a kart body, one part "engine". A deep green round boiler
-- along the front with a black smokebox and a tall flared black chimney, a brass steam dome, side water tanks lined in
-- gold with a gold "3" on each, a red footplate frame with wheel arches, a red buffer beam with round black buffers and
-- a coupling hook, three little spoked driving wheels each side on a coupling rod, and an open-sided cab at the back --
-- a spectacle plate with two brass-rimmed portholes in front, a back wall, low side sheets with vent slats, and a roof
-- on four posts -- with a coal bunker behind it. The driver sits on a black bucket seat in the cab.
--
-- In the kart's body space, metres: the origin the middle of the (hidden) chassis box's top, +z forward, y up. The
-- cockpit keeps clear of x ±0.28, z -0.5..0.45 above y -0.2; the wheels (another slot) sit at x ±0.5, z ±0.7, y -0.42.
local p = params{
  boiler_radius  = { default = 0.3, min = 0.24, max = 0.32, doc = "Radius of the boiler, metres" },
  chimney_height = { default = 0.38, min = 0.25, max = 0.5, doc = "Height of the chimney above the smokebox, metres" },
  arch           = { default = 0.34, min = 0.31, max = 0.38, doc = "Wheel arch radius, metres" },
  segments       = { default = 22, min = 12, max = 32, integer = true, doc = "Segments round the boiler and smokebox" },
  spokes         = { default = 8, min = 6, max = 12, integer = true, doc = "Spokes in each little driving wheel (even)" },
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
  -- Its wreck, as the same pieces broken: what stays on the kart when the bodywork is knocked off (_wreck.lua).
  -- Its signature piece (a piece marked true, 4th) comes off alone as `<name>_sig` (_sig.lua), the rest to the wreck.
  local rest = include("_sig.lua").split(name, out, function(i) return pieces[i][4] end)
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

local green    = C(0.05, 0.36, 0.14)
local green_dk = C(0.02, 0.2, 0.07)
local gold     = C(0.95, 0.72, 0.12)
local brass    = C(0.85, 0.62, 0.2)
local red      = C(0.75, 0.04, 0.03)
local red_dk   = C(0.5, 0.02, 0.02)
local black    = C(0.05, 0.05, 0.06)
local iron     = C(0.16, 0.16, 0.18)
local silver   = C(0.72, 0.74, 0.78)
local glass    = C(0.03, 0.04, 0.05)
local seat_c   = C(0.07, 0.07, 0.08)
-- Patched up: grey primer, rusty tin patches, silver duct tape, planks.
local primer   = C(0.56, 0.56, 0.52)
local tin      = C(0.5, 0.3, 0.16)
local rivet    = C(0.3, 0.3, 0.32)
local tape     = C(0.76, 0.77, 0.79)
local wood     = C(0.58, 0.4, 0.2)

local pieces = {}
-- `SIG` true while adding the signature's pieces (the chimney): marked 4th, for part().
local SIG = false
local function add(m, c, a) pieces[#pieces + 1] = {m, c, a, SIG} end

local W = 1.26
local HW = W / 2
local ZB, ZF = -1.25, 1.2          -- the frame's back and front
local ZC, L = (ZB + ZF) / 2, ZF - ZB
local BOT, DECK = -0.42, 0.0       -- the frame's bottom and the footplate's top
local R = p.boiler_radius
local BY = DECK + R + 0.03         -- the boiler's axis height
local SEG = p.segments
local CAB_F, CAB_B = 0.48, -0.84   -- the spectacle plate's back face, the back wall's front face
local ROOF = 1.08                  -- the cab roof's foot

-- The frame: a red tub, hollow, its floor 0.1 thick, wheel arches cut from its sides; the footplate on top, open over
-- the cockpit.
do
  local outer = rbox(W, DECK - 0.06 - BOT, L, 0.1, 0, BOT, ZC, 0.04)
  local inner = rbox(W - 0.12, 1.0, L - 0.12, 0.06, 0, BOT + 0.1, ZC)
  local cuts = {inner}
  for _, sx in ipairs({-1, 1}) do
    for _, z in ipairs({-0.7, 0.7}) do cuts[#cuts + 1] = cyl(p.arch, 0.4, sx * 0.62, -0.42, z, "x", 22) end
  end
  add(subtract(outer, table.unpack(cuts)), red)
  local deck = rb(W + 0.02, 0.06, L + 0.02, 0, DECK - 0.03, ZC, 0.012)
  add(subtract(deck, bx(0.62, 0.3, 1.0, 0, DECK, -0.02)), red)
  -- the arches' lips: a dark half ring round each
  for _, sx in ipairs({-1, 1}) do
    for _, z in ipairs({-0.7, 0.7}) do
      local ring = torus{major_radius=p.arch + 0.012, minor_radius=0.018, major_segments=24, minor_segments=6, axis="x"}
      ring = subtract(ring, bx(0.2, 1, 1.2, 0, -0.5, 0))
      add(at(ring, sx * (HW - 0.005), -0.42, z), red_dk)
    end
  end
end

-- The buffer beams: red, front and back; round black buffers on stems and a coupling hook at the front.
do
  add(rb(W + 0.04, 0.3, 0.08, 0, -0.15, ZF + 0.04, 0.015, 2), red)
  add(rb(W + 0.04, 0.26, 0.08, 0, -0.17, ZB - 0.04, 0.015, 2), red)
  for _, sx in ipairs({-1, 1}) do
    add(cyl(0.035, 0.1, sx * 0.42, -0.13, ZF + 0.13, "z", 12), iron)
    add(cyl(0.05, 0.04, sx * 0.42, -0.13, ZF + 0.1, "z", 12), black)
    add(cyl(0.085, 0.03, sx * 0.42, -0.13, ZF + 0.19, "z", 18), black)
  end
  add(rb(0.07, 0.07, 0.04, 0, -0.13, ZF + 0.1, 0.01), iron)
  add(rb(0.03, 0.03, 0.12, 0, -0.13, ZF + 0.17, 0.006), black)
  add(rb(0.03, 0.08, 0.03, 0, -0.16, ZF + 0.22, 0.006), black)
end

-- The boiler: deep green, lying along z, brass bands; a black smokebox in front on a black saddle, its round door.
local SZ0, SZ1 = 1.0, ZF + 0.02   -- the smokebox's back and front
do
  add(cyl(R, SZ0 - CAB_F + 0.02, 0, BY, (CAB_F + SZ0) / 2, "z", SEG), green)
  for _, z in ipairs({CAB_F + 0.1, SZ0 - 0.02}) do
    add(at(torus{major_radius=R + 0.004, minor_radius=0.012, major_segments=SEG, minor_segments=6, axis="z"}, 0, BY, z), brass)
  end
  add(cyl(R + 0.025, SZ1 - SZ0, 0, BY, (SZ0 + SZ1) / 2, "z", SEG), black)
  add(rb(0.44, BY - DECK, SZ1 - SZ0 - 0.02, 0, (BY + DECK) / 2, (SZ0 + SZ1) / 2, 0.02), black)
  -- the door: a plain plate in a rim (nothing on it, so the front never reads as a face)
  add(at(torus{major_radius=R - 0.02, minor_radius=0.014, major_segments=SEG, minor_segments=6, axis="z"}, 0, BY, SZ1 + 0.005), iron)
  add(cyl(R - 0.035, 0.03, 0, BY, SZ1 + 0.01, "z", SEG), black)
end

-- The chimney: tall and black on the smokebox, flared at the top with a rolled rim.
do
  local cz = (SZ0 + SZ1) / 2
  local y0 = BY + R - 0.04
  local h = p.chimney_height
  SIG = true
  add(at(cone{radius=0.12, radius_top=0.085, height=0.08, segments=16}, 0, y0 + 0.04, cz), black)
  add(cyl(0.08, h, 0, y0 + 0.02 + h / 2, cz, "y", 16), black)
  add(at(cone{radius=0.08, radius_top=0.125, height=0.09, segments=16}, 0, y0 + h + 0.045, cz), black)
  add(at(torus{major_radius=0.125, minor_radius=0.014, major_segments=16, minor_segments=6, axis="y"}, 0, y0 + h + 0.09, cz), black)
  SIG = false
end

-- The steam dome (brass, rounded) and a little brass safety valve behind it.
do
  local dz = 0.8
  local y0 = BY + R - 0.05
  add(cyl(0.11, 0.09, 0, y0 + 0.045, dz, "y", 16), brass)
  add(sph(0.11, 0, y0 + 0.1, dz, 16), brass)
  add(cyl(0.05, 0.06, 0, y0 + 0.03, CAB_F + 0.15, "y", 12), brass)
  add(sph(0.035, 0, y0 + 0.07, CAB_F + 0.15, 10), brass)
end

-- The side tanks: green, alongside the boiler, gold lining and a gold "3" on each.
local TZ0, TZ1 = CAB_F + 0.02, SZ0 - 0.02
local TX0, TX1 = R + 0.03, HW - 0.01
local TH = 0.56
-- A gold frame on the face x = fx: z0..z1, y0..y1, its bars t wide.
local function lining(fx, z0, z1, y0, y1, t, c)
  add(bx(0.012, t, z1 - z0, fx, y0, (z0 + z1) / 2), c)
  add(bx(0.012, t, z1 - z0, fx, y1, (z0 + z1) / 2), c)
  add(bx(0.015, y1 - y0 + t * 0.9, t, fx, (y0 + y1) / 2, z0), c)
  add(bx(0.015, y1 - y0 + t * 0.9, t, fx, (y0 + y1) / 2, z1), c)
end
for _, sx in ipairs({-1, 1}) do
  local tw = TX1 - TX0
  add(rbox(tw, TH, TZ1 - TZ0, 0.05, sx * (TX0 + TX1) / 2, DECK, (TZ0 + TZ1) / 2, 0.03), green)
  local fx = sx * (TX1 + 0.004)
  lining(fx, TZ0 + 0.05, TZ1 - 0.05, DECK + 0.07, DECK + TH - 0.07, 0.016, gold)
  -- the number 3, read from this side (the viewer's right is -z on +x, +z on -x)
  local zc, yc = (TZ0 + TZ1) / 2, DECK + TH / 2
  local s = -sx
  local fx2 = sx * (TX1 + 0.008)
  add(bx(0.014, 0.04, 0.15, fx2, yc + 0.11, zc), gold)
  add(bx(0.014, 0.04, 0.11, fx2, yc, zc + s * 0.02), gold)
  add(bx(0.014, 0.04, 0.15, fx2, yc - 0.11, zc), gold)
  add(bx(0.018, 0.25, 0.04, fx2, yc, zc + s * 0.05), gold)
  -- a filler cap on top
  add(cyl(0.04, 0.03, sx * (TX0 + TX1) / 2, DECK + TH + 0.01, TZ1 - 0.1, "y", 12), brass)
end

-- The cab: a spectacle plate in front with two brass-rimmed portholes, a back wall with a window, low side sheets with
-- vent slats and gold lining, a roof on four corner posts. Open above the side sheets, and between the plate and roof.
do
  local plate_m = plate({{-HW + 0.02, DECK}, {HW - 0.02, DECK}, {HW - 0.02, 0.8}, {HW - 0.16, 0.92},
    {-HW + 0.16, 0.92}, {-HW + 0.02, 0.8}}, CAB_F, CAB_F + 0.04)
  local holes = {}
  for _, sx in ipairs({-1, 1}) do holes[#holes + 1] = cyl(0.09, 0.2, sx * 0.36, 0.7, CAB_F + 0.02, "z", 20) end
  add(subtract(plate_m, table.unpack(holes)), green)
  for _, sx in ipairs({-1, 1}) do
    for _, z in ipairs({CAB_F - 0.005, CAB_F + 0.045}) do
      add(at(torus{major_radius=0.098, minor_radius=0.016, major_segments=20, minor_segments=6, axis="z"}, sx * 0.36, 0.7, z), brass)
    end
  end
  -- the back wall: only as high as the side sheets, so the road shows over it from behind (the chase camera's view),
  -- a rail along its top
  local BH = 0.42
  add(rb(W - 0.04, BH, 0.04, 0, DECK + BH / 2, CAB_B - 0.02, 0.012), green)
  add(rb(W - 0.02, 0.03, 0.05, 0, DECK + BH, CAB_B - 0.02, 0.01), green_dk)
  -- the low side sheets
  local sz0, sz1 = CAB_B, CAB_F
  local sh = 0.42
  for _, sx in ipairs({-1, 1}) do
    add(rb(0.04, sh, sz1 - sz0, sx * (HW - 0.03), DECK + sh / 2, (sz0 + sz1) / 2, 0.012), green)
    add(rb(0.05, 0.03, sz1 - sz0 + 0.01, sx * (HW - 0.03), DECK + sh, (sz0 + sz1) / 2, 0.012), green_dk)
    local fx = sx * (HW - 0.004)
    lining(fx, sz0 + 0.05, sz1 - 0.05, DECK + 0.06, DECK + sh - 0.07, 0.014, gold)
    -- vent slats towards the back
    for i = 0, 3 do add(rb(0.016, 0.022, 0.2, sx * (HW - 0.001), DECK + 0.13 + i * 0.05, sz0 + 0.2, 0.006), green_dk) end
  end
  -- the corner posts and the roof, a gentle crown with a rain strip each side
  for _, sx in ipairs({-1, 1}) do
    for _, z in ipairs({CAB_B + 0.03, CAB_F - 0.03}) do
      add(rod(v3(sx * (HW - 0.04), DECK + sh, z), v3(sx * (HW - 0.04), ROOF, z), 0.025, 10), green_dk)
    end
  end
  add(rbox(W + 0.06, 0.06, CAB_F - CAB_B + 0.2, 0.08, 0, ROOF, (CAB_F + CAB_B) / 2, 0.025), green)
  add(rbox(W - 0.3, 0.04, CAB_F - CAB_B + 0.12, 0.08, 0, ROOF + 0.05, (CAB_F + CAB_B) / 2, 0.015), green_dk)
  for _, sx in ipairs({-1, 1}) do
    add(rb(0.02, 0.02, CAB_F - CAB_B + 0.2, sx * (HW + 0.025), ROOF + 0.005, (CAB_F + CAB_B) / 2, 0.006), gold)
  end
  -- a brass whistle on the plate's top
  add(cyl(0.02, 0.1, 0.18, 0.97, CAB_F + 0.03, "y", 10), brass)
  add(cyl(0.035, 0.05, 0.18, 1.04, CAB_F + 0.03, "y", 10), brass)
end

-- The coal bunker behind the cab: green, lined, heaped with coal.
do
  local z0, z1 = ZB + 0.04, CAB_B - 0.04
  -- (low: the road behind shows over it)
  add(rbox(W - 0.08, 0.26, z1 - z0, 0.06, 0, DECK, (z0 + z1) / 2, 0.02), green)
  for _, sx in ipairs({-1, 1}) do lining(sx * (HW - 0.034), z0 + 0.05, z1 - 0.05, DECK + 0.06, DECK + 0.2, 0.014, gold) end
  local lumps = {{-0.3, -1.1}, {-0.1, -1.0}, {0.12, -1.12}, {0.3, -0.98}, {0.0, -1.15}, {-0.2, -0.95}, {0.22, -1.06}}
  for i, q in ipairs(lumps) do add(sph(0.07 + (i % 3) * 0.012, q[1], DECK + 0.25, q[2], 8), black) end
end

-- The bodges: tin patches riveted over the rust on both tanks and the bunker, duct tape round a leak in the boiler
-- and over a crack in the roof, the left side sheet a primer-grey replacement, and a plank nailed over the back of
-- the bunker where its plate rusted through.
do
  local function patch(w, h, x, y, z, side, c)
    -- A square of tin flat on an x face (side = +-1), rivets at its corners.
    add(rb(0.008, h, w, x, y, z, 0.003), c or tin)
    for _, dy in ipairs({-1, 1}) do for _, dz in ipairs({-1, 1}) do
      add(sph(0.011, x + side * 0.005, y + dy * (h / 2 - 0.02), z + dz * (w / 2 - 0.02), 6), rivet)
    end end
  end
  patch(0.2, 0.14, TX1 + 0.01, DECK + 0.13, TZ1 - 0.16, 1)
  patch(0.16, 0.12, -(TX1 + 0.01), DECK + TH - 0.14, TZ0 + 0.14, -1)
  patch(0.18, 0.1, HW - 0.03, DECK + 0.13, ZB + 0.25, 1)
  -- the left side sheet: a primer replacement over the green
  add(rb(0.008, 0.36, CAB_F - CAB_B - 0.12, -(HW - 0.004), DECK + 0.21, (CAB_F + CAB_B) / 2, 0.003), primer)
  -- duct tape wound round the boiler over a leak, two turns
  for k = 0, 1 do
    add(at(cylinder{radius=R + 0.012, height=0.05, segments=SEG, axis="z"}, 0, BY, 0.9 - k * 0.06), tape)
  end
  -- a strip over a crack in the roof
  add(rb(0.06, 0.012, 0.7, -0.3, ROOF + 0.065, (CAB_F + CAB_B) / 2, 0.004), tape)
  -- the plank across the bunker's back
  add(rb(W - 0.04, 0.1, 0.03, 0, DECK + 0.13, ZB + 0.025, 0.008), wood)
  for _, sx in ipairs({-1, 1}) do add(sph(0.012, sx * 0.5, DECK + 0.13, ZB + 0.008, 6), rivet) end
end

-- The little driving wheels: three each side on the frame between the real wheels, green rims and spokes, brass
-- hubs, a silver coupling rod across their crank pins.
do
  local wr, wy = 0.13, -0.29
  local n = math.max(2, math.floor(p.spokes / 2))
  for _, sx in ipairs({-1, 1}) do
    local x = sx * (HW + 0.025)
    for _, z in ipairs({-0.26, 0, 0.26}) do
      add(at(torus{major_radius=wr - 0.016, minor_radius=0.018, major_segments=20, minor_segments=6, axis="x"}, x, wy, z), green)
      for i = 0, n - 1 do
        add(at(turn(box{size=v3(0.016, 2 * wr - 0.04, 0.018)}, i * 180 / n, axis_x()), x, wy, z), green)
      end
      add(cyl(0.035, 0.04, x, wy, z, "x", 12), brass)
      add(cyl(0.016, 0.05, sx * (HW + 0.05), wy + 0.06, z, "x", 8), silver)
    end
    add(rb(0.02, 0.035, 0.6, sx * (HW + 0.07), wy + 0.06, 0, 0.008), silver)
  end
end

-- Inside: a black bucket seat, the steering column to the spectacle plate.
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
add(rod(v3(0, 0.1, 0.15), v3(0, -0.02, CAB_F + 0.01), 0.022, 10), black)
add(cyl(0.035, 0.05, 0, 0.08, 0.17, "z", 10), black)

-- Underneath: axle crossbars, stubs to the hubs, two rails.
for _, z in ipairs({-0.7, 0.7}) do
  add(rod(v3(-0.47, -0.42, z), v3(0.47, -0.42, z), 0.03, 10), black)
  for _, sx in ipairs({-1, 1}) do
    add(rod(v3(sx * 0.46, -0.42, z), v3(sx * 0.535, -0.42, z), 0.02, 10), iron)
    add(cyl(0.036, 0.03, sx * 0.47, -0.42, z, "x", 8), silver)
  end
end
for _, sx in ipairs({-1, 1}) do add(rb(0.06, 0.05, 2.2, sx * 0.3, -0.445, ZC, 0.012), black) end

part("engine", pieces)
