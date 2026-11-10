-- The Can: a giant drinks can lying on its side along z, the driver sat in an opening cut into its top, on a blue
-- tubular frame with striped fenders over the wheels. One part, "can", drawn with Render.model "karts/can#can".
--
-- In the kart's body space, metres: the origin the middle of the (hidden) chassis box's top, +z forward, y up. The
-- can's bottom faces forward (a domed base), its top -- the lid with its ring-pull -- faces back. The cockpit keeps
-- clear of x ±0.28, z -0.5..0.45 above y -0.2; the wheels (another slot) sit at x ±0.5, z ±0.7, y -0.42.
-- Colours are painted on the vertices, one white material with a little metal in it.
local p = params{
  radius  = {default=0.4, min=0.385, max=0.42, doc="The can's radius, metres"},
  crumple = {default=0.008, min=0, max=0.014, doc="How dented the can's faces are, metres"},
  rim_cut = {default=0.17, min=0.1, max=0.18, doc="Height of the cockpit opening's edge, metres"},
  recline = {default=10, min=0, max=20, doc="The seat back's recline, degrees"},
}

local PAINT = material{name="CanMetal", base_color=v3(1, 1, 1), roughness=0.42, metallic=0.3}

local function all(m) return faces_where(m, function(_) return true end) end
local function paint(m, c) return paint_faces(m, {faces=all(m), color=c}) end
-- Faces of m for which fn(f) holds, painted c (none such: m as it was).
local function paint_if(m, c, fn)
  local sel = faces_where(m, fn)
  if set_count(sel) == 0 then return m end
  return paint_faces(m, {faces=sel, color=c})
end
-- A part of pieces, each { mesh, colour } or { mesh } already painted (an `angle` field: its own smoothing angle):
-- merged into one mesh with its colours on its vertices (merge, not join, which drops them).
local function part(name, pieces)
  local out = {}
  for i, pc in ipairs(pieces) do
    local m = pc[2] and paint(pc[1], pc[2]) or pc[1]
    out[i] = {mesh=smooth_normals(m, {angle=pc.angle or 40}), material=PAINT}
  end
  local merged = merge({parts=out, mode="compatible"})
  emit(merged[1].mesh, {name=name, material=merged[1].material})
  -- Its signature piece (sig=true): its own part, `<name>_sig` (_sig.lua), and left out of the wreck.
  local rest = include("_sig.lua").split(name, out, function(i) return pieces[i].sig end)
  -- Its wreck, as the same pieces broken: what stays on the kart when the bodywork is knocked off (_wreck.lua).
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
local function ball(rx, ry, rz, x, y, z, seg)
  local s = seg or 12
  return at(scale(sphere{radius=1, segments=s, rings=math.floor(s / 2)}, {factor=v3(rx, ry, rz), pivot=origin()}), x, y, z)
end
local function cyl(r, h, x, y, z, axis, seg) return at(cylinder{radius=r, height=h, segments=seg or 14, axis=axis or "y"}, x, y, z) end
-- A round rod from a to b, a hair short of each.
local function rod(a0, b0, r, seg)
  local a = lerp(a0, b0, 0.004)
  local b = lerp(a0, b0, 0.996)
  local d = b - a
  local up = v3(0, 1, 0)
  local m = cylinder{radius=r, height=length(d), segments=seg or 8}
  local dir = normalize(d)
  local c = dot(up, dir)
  if c < -0.9999 then m = rotate(m, {angle=180, axis=axis_x(), pivot=origin()})
  elseif c < 0.9999 then m = rotate(m, {angle=deg(math.acos(c)), axis=normalize(cross(up, dir)), pivot=origin()}) end
  return translate(m, (a + b) * 0.5)
end

local black  = C(0.035, 0.035, 0.04)
local dark   = C(0.12, 0.12, 0.13)
local grey   = C(0.45, 0.46, 0.5)
local silver = C(0.74, 0.76, 0.8)
local chrome = C(0.9, 0.91, 0.94)
local white  = C(0.95, 0.95, 0.95)
-- Grape: a deep purple livery (the frame and fenders a shade darker), a pink pinstripe along its swoosh's edge.
local blue   = C(0.3, 0.04, 0.55)
local tubeb  = C(0.22, 0.03, 0.42)
local pinstripe = C(0.95, 0.35, 0.7)

local R = p.radius
local AY = -0.05          -- the can's axis height
local HALF = 0.962        -- half its length, rim to rim
local pieces = {}
local function add(m, c, angle, sig) pieces[#pieces + 1] = {m, c, angle=angle, sig=sig} end

-- The can --------------------------------------------------------------------------------------------------
-- A solid of revolution about z from a { radius, z } profile running from the lid's middle (back) round the rims to
-- the dome's middle (front), built by hand so every vertex can be dented: the side's radius takes a little noise,
-- fading out towards the rims, and each quad is split along alternating diagonals -- low-poly crumpled metal.
do
  local k = R / 0.4
  local prof = {
    {0, -0.915}, {0.16, -0.915}, {0.3, -0.913}, {0.336 * k, -0.913}, {0.346 * k, -0.92}, {0.352 * k, -0.945},
    {0.362 * k, -0.958}, {0.376 * k, -0.962}, {0.389 * k, -0.953}, {0.39 * k, -0.937}, {0.383 * k, -0.926},
    {0.394 * k, -0.89}, {R, -0.84},
  }
  for i = 0, 16 do prof[#prof + 1] = {R, -0.76 + i * 0.095} end
  local tail = {
    {R, 0.84}, {0.394 * k, 0.885}, {0.378 * k, 0.922}, {0.366 * k, 0.948}, {0.358 * k, 0.962}, {0.344 * k, 0.962},
    {0.334 * k, 0.95}, {0.3, 0.922}, {0.2, 0.888}, {0.1, 0.87}, {0, 0.864},
  }
  for _, q in ipairs(tail) do prof[#prof + 1] = q end

  local SEG = 36
  local verts, faces = {}, {}
  local idx = {}
  local n = #prof
  for i = 1, n do
    local r, z = prof[i][1], prof[i][2]
    idx[i] = {}
    if r == 0 then
      verts[#verts + 1] = v3(0, AY, z)
      for j = 1, SEG do idx[i][j] = #verts end
    else
      -- The dents: full along the side, fading over the shoulders, a whisper on the ends.
      local w = 1
      local az = math.abs(z)
      if az > 0.8 then w = math.max(0.15, 1 - (az - 0.8) / 0.05) end
      if r < 0.33 * k then w = 0.35 end
      for j = 1, SEG do
        local t = (j - 1) / SEG * 2 * math.pi
        local cx, cy = math.cos(t), math.sin(t)
        local d = p.crumple * w * noise3(cx * 1.3, cy * 1.3, z * 1.6, {frequency=2.2, octaves=2, seed=7})
        local rr = r + d
        local zz = z
        if r < 0.33 * k then rr = r; zz = z + d * (z < 0 and -1 or 1) end
        verts[#verts + 1] = v3(rr * cx, AY + rr * cy, zz)
        idx[i][j] = #verts
      end
    end
  end
  for i = 1, n - 1 do
    for j = 1, SEG do
      local j2 = j % SEG + 1
      local a, b, c, d = idx[i][j], idx[i][j2], idx[i + 1][j2], idx[i + 1][j]
      if prof[i][1] == 0 then
        faces[#faces + 1] = {a, c, d}
      elseif prof[i + 1][1] == 0 then
        faces[#faces + 1] = {a, b, c}
      elseif (i + j) % 2 == 0 then
        faces[#faces + 1] = {a, b, c}
        faces[#faces + 1] = {a, c, d}
      else
        faces[#faces + 1] = {a, b, d}
        faces[#faces + 1] = {b, c, d}
      end
    end
  end
  local can = polyhedron{vertices=verts, faces=faces}

  -- The cockpit: the top sliced off level over the seat and the driver's legs, and the can hollowed under it.
  local RC = p.rim_cut
  local Z0, Z1 = -0.62, 0.46
  local top = bx(1.2, 0.6, Z1 - Z0, 0, RC + 0.3, (Z0 + Z1) / 2)
  local CW, FL = 0.29, -0.26
  local hole = bx(2 * CW, RC - FL + 0.05, Z1 - (Z0 + 0.015), 0, (FL + RC + 0.05) / 2, (Z0 + 0.015 + Z1) / 2)
  can = subtract(can, top, hole)

  -- The livery's edges cut in: a diagonal down the side from the front (blue above it), the blue's back edge across
  -- the middle, and its front edge where the base's shoulder starts.
  local P1 = v3(0, AY + R * 0.1, 0.95)
  local P2 = v3(0, AY - R, -0.13)
  local dir = P1 - P2
  local DN = normalize(v3(0, dir.z, -dir.y))
  local ZB, ZF = -0.13, 0.845
  can = knife(can, {normal=DN, point=P1})
  can = knife(can, {normal=DN, point=P1 - DN * 0.065})
  can = knife(can, {normal=v3(0, 0, 1), point=v3(0, 0, ZB)})
  can = knife(can, {normal=v3(0, 0, 1), point=v3(0, 0, ZF)})

  can = paint(can, silver)
  can = paint_if(can, blue, function(f)
    local c = f.center
    return c.z > ZB and c.z < ZF and dot(c - P1, DN) > 0
  end)
  -- the pink pinstripe just under the swoosh's edge
  can = paint_if(can, pinstripe, function(f)
    local c = f.center
    local d = dot(c - P1, DN)
    return c.z > ZB and c.z < ZF and d < 0 and d > -0.065
  end)
  -- The rims and the lid a brighter metal.
  can = paint_if(can, chrome, function(f)
    local c = f.center
    local r = math.sqrt(c.x * c.x + (c.y - AY) * (c.y - AY))
    return math.abs(c.z) > 0.9 and r > 0.33 * k
  end)
  -- Inside the cockpit dark, and the cut edge a black rubber trim.
  can = paint_if(can, dark, function(f)
    local c = f.center
    return math.abs(c.x) < CW + 0.002 and c.y < RC - 0.002 and c.y > FL - 0.002 and c.z > Z0 + 0.01 and c.z < Z1 - 0.01
  end)
  can = paint_if(can, black, function(f)
    return f.normal.y > 0.95 and math.abs(f.center.y - RC) < 0.002
  end)
  add(can, nil, 6)

  -- The ring-pull on the lid: a tab with a finger hole, its rivet, the scored ring round it.
  local function rr_pts(cx, cy, w, h, r, n, cw)
    local pts = {}
    local corners = {{cx + w / 2 - r, cy + h / 2 - r, 0}, {cx - w / 2 + r, cy + h / 2 - r, 90},
                     {cx - w / 2 + r, cy - h / 2 + r, 180}, {cx + w / 2 - r, cy - h / 2 + r, 270}}
    for _, cn in ipairs(corners) do
      for s = 0, n do
        local a = math.rad(cn[3] + s * 90 / n)
        pts[#pts + 1] = v2(cn[1] + r * math.cos(a), cn[2] + r * math.sin(a))
      end
    end
    if cw then
      local rev = {}
      for i = #pts, 1, -1 do rev[#rev + 1] = pts[i] end
      return rev
    end
    return pts
  end
  local LZ = -0.915
  local tabp = poly{points=rr_pts(0, 0.07, 0.15, 0.27, 0.06, 5), holes={rr_pts(0, 0.135, 0.085, 0.09, 0.035, 4, true)}}
  local tab = extrude(tabp, {distance=0.01})
  tab = rotate(tab, {angle=90, axis=axis_x(), pivot=origin()})
  local tb = bbox(tab)
  tab = translate(tab, v3(0, AY - (tb.min.y + tb.max.y) / 2 + 0.07, LZ - 0.006 - tb.max.z))
  add(tab, chrome, 30, true)
  add(cyl(0.02, 0.014, 0, AY, LZ - 0.006, "z", 16), grey, 30, true)
  add(at(torus{major_radius=0.06, minor_radius=0.006, major_segments=28, minor_segments=6, axis="z"}, 0, AY, LZ - 0.002), silver, 30)
  -- The opening scored below the rivet, a teardrop.
  add(at(scale(torus{major_radius=1, minor_radius=0.06, major_segments=24, minor_segments=5, axis="z"},
      {factor=v3(0.06, 0.075, 0.1), pivot=origin()}), 0, AY - 0.13, LZ - 0.001), silver, 30)
end

-- The seat: a black bucket, its base under the hips, its high back (bolstered, a narrower head section with a slot)
-- behind the driver at z -0.5, reclined about its foot.
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
  -- A profile stood up in the xy plane, thick along z: its lowest-left corner at (x0, y0), its front face at z1.
  local function stand(pr, thick, x0, y0, z1)
    local m = rotate(extrude(pr, {distance=thick}), {angle=90, axis=axis_x(), pivot=origin()})
    local b = bbox(m)
    return translate(m, v3(x0 - b.min.x, y0 - b.min.y, z1 - b.max.z))
  end
  local back = stand(backp, 0.09, -0.25, -0.24, -0.545)
  back = translate(back, v3(-bbox(back).center.x, 0, 0))
  -- The bolsters either side, standing proud of the back, and over the shoulders.
  local bol = poly{points=outline({{0.16, -0.22}, {0.235, -0.22}, {0.25, 0.2}, {0.215, 0.35}, {0.16, 0.33}, {0.175, 0.2}})}
  local b1 = stand(bol, 0.075, 0.16, -0.22, -0.502)
  local b2 = mirror(b1, {normal=v3(1, 0, 0), pivot=origin()})
  local seat = join(back, b1, b2)
  seat = rotate(seat, {angle=-p.recline, axis=axis_x(), pivot=v3(0, -0.24, -0.5)})
  add(seat, black, 35)
  -- A grey stitch band across the back.
  local band = rotate(bx(0.3, 0.025, 0.004, 0, 0.12, -0.545 + 0.0015), {angle=-p.recline, axis=axis_x(), pivot=v3(0, -0.24, -0.5)})
  add(band, dark)
end

-- The steering column: a short rod from under the wheel's hub forward and down into the can's front bulkhead.
add(rod(v3(0, 0.115, 0.15), v3(0, 0.02, 0.465), 0.018, 10), dark)
add(at(scale(sphere{radius=1, segments=14, rings=7}, {factor=v3(0.05, 0.05, 0.02), pivot=origin()}), 0, 0.02, 0.46), black)

-- The frame: blue tube under the can -------------------------------------------------------------------------
do
  local TR = 0.02
  local function tb(a, b, r) add(rod(a, b, r or TR, 10), tubeb, 40) end
  local function knot(v, r) add(ball(r or TR * 1.15, r or TR * 1.15, r or TR * 1.15, v.x, v.y, v.z, 10), tubeb, 40) end
  local LY, UY = -0.45, -0.33
  local LX, UX = 0.3, 0.37
  local ZE = 0.86
  for _, s in ipairs({-1, 1}) do
    -- The lower and upper side rails.
    local l0, l1 = v3(s * LX, LY, -ZE), v3(s * LX, LY, ZE)
    tb(l0, l1)
    local u0, u1 = v3(s * UX, UY, -0.78), v3(s * UX, UY, 0.78)
    tb(u0, u1)
    tb(u0, l0); tb(u1, l1)
    knot(u0); knot(u1); knot(l0); knot(l1)
    -- The triangulated braces between them.
    local zs = {-0.78, -0.48, -0.18, 0.12, 0.42, 0.78}
    for i = 1, #zs - 1 do
      local a = (i % 2 == 1) and v3(s * LX, LY, zs[i]) or v3(s * UX, UY, zs[i])
      local b = (i % 2 == 1) and v3(s * UX, UY, zs[i + 1]) or v3(s * LX, LY, zs[i + 1])
      tb(a, b, TR * 0.8)
    end
    for _, z in ipairs({-0.48, -0.18, 0.12, 0.42}) do tb(v3(s * LX, LY, z), v3(s * UX, UY, z), TR * 0.8) end
    -- The axle stubs, steel, out of the crossbars' ends into the wheels' hubs.
    for _, z in ipairs({-0.7, 0.7}) do
      add(cyl(0.032, 0.07, s * 0.465, -0.42, z, "x", 14), grey, 30)
      add(cyl(0.022, 0.02, s * 0.51, -0.42, z, "x", 12), chrome, 30)
      -- The upright from the lower rail to the crossbar's end, and a gusset strut to the upper rail.
      tb(v3(s * LX, LY, z), v3(s * 0.43, -0.42, z))
      tb(v3(s * UX, UY, z), v3(s * 0.43, -0.42, z), TR * 0.8)
    end
  end
  -- The axle crossbars, and the cross members at each end.
  for _, z in ipairs({-0.7, 0.7}) do tb(v3(-0.47, -0.42, z), v3(0.47, -0.42, z), 0.024) end
  for _, z in ipairs({-ZE, ZE}) do tb(v3(-LX, LY, z), v3(LX, LY, z)) end
  tb(v3(-LX, LY, -0.3), v3(LX, LY, 0.3), TR * 0.8)
  tb(v3(LX, LY, -0.3), v3(-LX, LY, 0.3), TR * 0.8)

  -- The front nerf bar: a loop out ahead of the front axle, tied back to the rails.
  local NZ = 1.12
  local loop = {
    v3(-LX, LY, ZE), v3(-0.33, -0.47, 1.04), v3(-0.34, -0.42, NZ), v3(-0.33, -0.3, NZ + 0.01),
    v3(-0.28, -0.25, NZ), v3(0.28, -0.25, NZ), v3(0.33, -0.3, NZ + 0.01), v3(0.34, -0.42, NZ),
    v3(0.33, -0.47, 1.04), v3(LX, LY, ZE),
  }
  for i = 1, #loop - 1 do tb(loop[i], loop[i + 1]) end
  for i = 2, #loop - 1 do knot(loop[i]) end
  tb(v3(-0.33, -0.47, 1.04), v3(0.33, -0.47, 1.04))
  tb(v3(-0.33, -0.3, NZ + 0.01), v3(-UX, UY, 0.78), TR * 0.8)
  tb(v3(0.33, -0.3, NZ + 0.01), v3(UX, UY, 0.78), TR * 0.8)
  tb(v3(-0.1, -0.25, NZ), v3(-0.1, -0.47, 1.04), TR * 0.8)
  tb(v3(0.1, -0.25, NZ), v3(0.1, -0.47, 1.04), TR * 0.8)
end

-- The fenders: quarter-round bands over the wheels, blue with a white stripe down the middle, on short struts.
do
  -- A curved band about the x axis through (y0, z0): radii r0..r1, across x0..x1, from angle a0 to a1 (degrees from
  -- +z towards +y).
  local function band(x0, x1, r0, r1, a0, a1, y0, z0, n)
    local vs, fs = {}, {}
    for i = 0, n do
      local t = math.rad(a0 + (a1 - a0) * i / n)
      local cz, cy = math.cos(t), math.sin(t)
      for _, q in ipairs({{x0, r0}, {x1, r0}, {x1, r1}, {x0, r1}}) do
        vs[#vs + 1] = v3(q[1], y0 + q[2] * cy, z0 + q[2] * cz)
      end
    end
    local function V(i, c) return i * 4 + c end
    for i = 0, n - 1 do
      for c = 1, 4 do
        local c2 = c % 4 + 1
        fs[#fs + 1] = {V(i, c), V(i + 1, c), V(i + 1, c2), V(i, c2)}
      end
    end
    fs[#fs + 1] = {V(0, 1), V(0, 2), V(0, 3), V(0, 4)}
    fs[#fs + 1] = {V(n, 4), V(n, 3), V(n, 2), V(n, 1)}
    return polyhedron{vertices=vs, faces=fs}
  end
  local W = 0.12
  for _, s in ipairs({-1, 1}) do
    for _, z in ipairs({-0.7, 0.7}) do
      local a0, a1 = 35, 140
      if z < 0 then a0, a1 = 40, 145 end
      local xc = s * 0.5
      local xa, xb = xc - W / 2, xc + W / 2
      local function strip(u0, u1, col)
        add(band(math.min(u0, u1), math.max(u0, u1), 0.24, 0.262, a0, a1, -0.42, z, 16), col, 35)
      end
      strip(xa, xc - 0.0185, blue)
      strip(xc - 0.018, xc + 0.018, white)
      strip(xc + 0.0185, xb, blue)
      -- Two struts from the frame's upright up under the fender's inner edge.
      local inner = xc - s * W / 2 + s * 0.012
      for _, a in ipairs({a0 + 30, a1 - 30}) do
        local t = math.rad(a)
        local top = v3(inner, -0.42 + 0.24 * math.sin(t) - 0.004, z + 0.24 * math.cos(t))
        add(rod(top, v3(s * 0.37, -0.33, z + (math.cos(t) > 0 and 0.08 or -0.08)), 0.014, 8), tubeb, 40)
      end
    end
  end
end

part("can", pieces)
