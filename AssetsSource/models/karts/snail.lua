-- Escargot Fast: a chunky lime-green slug kart, a big purple spiral shell behind the driver, a grinning head with
-- two eyes on stalks up front, all on a wooden frame with silver axles. One part, "snail", drawn by the game with
-- Render.model "karts/snail#snail" on the kart's bodywork entity (the chassis box hidden: it brings its own frame).
--
-- In the kart's body space, metres: origin the middle of the chassis box's top, +z forward, y up. The wheels (another
-- slot) sit at x ±0.5, z ±0.7, y -0.42; the driver at hips (0, -0.21, -0.25), so nothing but the seat and the
-- steering column comes into x ±0.28, z -0.5..0.45, y -0.2..0.9. Colours are painted on the vertices, one white
-- material.
local P = params{
  shell = { default = 0.54, min = 0.4, max = 0.62, doc = "Shell radius, metres" },
  stalk = { default = 0.5, min = 0.34, max = 0.7, doc = "Eye height above the chassis top, metres" },
  grin  = { default = 0.22, min = 0.12, max = 0.26, doc = "Mouth half-width, metres" },
}

local PAINT = material{name="Paint", base_color=v3(1, 1, 1), roughness=0.55, metallic=0}

local function all(m) return faces_where(m, function(_) return true end) end
local function paint(m, c) return paint_faces(m, {faces=all(m), color=c}) end
-- Faces of m for which fn(f) holds, painted c (none such: m as it was).
local function paint_if(m, c, fn)
  local sel = faces_where(m, fn)
  if set_count(sel) == 0 then return m end
  return paint_faces(m, {faces=sel, color=c})
end
-- A part of pieces, each { mesh, colour?, angle? } (no colour: already painted): merged into one mesh with its
-- colours on its vertices (merge, not join, which drops them), each piece's normals smoothed below its angle.
local function part(name, pieces)
  local out = {}
  for i, p in ipairs(pieces) do
    local m = p[2] and paint(p[1], p[2]) or p[1]
    out[i] = {mesh=smooth_normals(m, {angle=p[3] or 40}), material=PAINT}
  end
  local merged = merge({parts=out, mode="compatible"})
  emit(merged[1].mesh, {name=name, material=merged[1].material})
  -- Its signature piece (a piece marked true, 4th): its own part, `<name>_sig`, centred on its own middle -- the game
  -- sends it rolling off ahead of the kart when the bodywork goes -- and left out of the wreck.
  local sig, rest = {}, {}
  for i, q in ipairs(pieces) do
    if q[4] then sig[#sig + 1] = out[i] else rest[#rest + 1] = out[i] end
  end
  if #sig > 0 then
    local s = merge({parts=sig, mode="compatible"})
    local b = bbox(s[1].mesh)
    emit(translate(s[1].mesh, v3(0, 0, 0) - b.center), {name=name .. "_sig", material=s[1].material})
  end
  -- Its wreck, as the same pieces broken: what stays on the kart when the bodywork is knocked off (_wreck.lua).
  include("_wreck.lua").emit(name, rest)
end
local function C(r, g, b) return v3(r, g, b) end
local function shade(c, k) return v3(math.min(1, c.x * k), math.min(1, c.y * k), math.min(1, c.z * k)) end

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
-- An ellipsoid: a sphere scaled to its three radii.
local function ball(rx, ry, rz, x, y, z, seg)
  local s = seg or 12
  return at(scale(sphere{radius=1, segments=s, rings=math.floor(s / 2)}, {factor=v3(rx, ry, rz), pivot=origin()}), x, y, z)
end
local function cyl(r, h, x, y, z, axis, seg) return at(cylinder{radius=r, height=h, segments=seg or 14, axis=axis or "y"}, x, y, z) end
-- A round rod from a to b, a hair short of each (two rods meeting end to end must not share a vertex).
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

local black  = C(0.03, 0.03, 0.035)
local grey   = C(0.42, 0.44, 0.47)
local silver = C(0.78, 0.8, 0.84)
local white  = C(0.97, 0.97, 0.95)
local lime   = C(0.5, 0.82, 0.1)
local purple = C(0.66, 0.3, 0.9)
local maroon = C(0.32, 0.04, 0.08)
local pink   = C(0.95, 0.42, 0.5)
local yellow = C(1.0, 0.82, 0.08)
local brown  = C(0.55, 0.31, 0.14)
local birch  = C(0.85, 0.6, 0.32)

local p = {}

-- The hull --------------------------------------------------------------------------------------------------------
-- A loft of cross-sections down its length: a long low slug, a hump under the shell and a tail poking out behind
-- it, rising at the front into a round head; a rolled lip along each side wall riding a wavy line, and between the
-- walls the cockpit, a trough sunk down its middle. The mouth is an open grin cut into the head's front.
-- A smooth curve through { z, value } keys, z ascending: eased between neighbours.
local function keys(t)
  return function(z)
    if z <= t[1][1] then return t[1][2] end
    for i = 1, #t - 1 do
      local a, b = t[i], t[i + 1]
      if z <= b[1] then
        local s = (z - a[1]) / (b[1] - a[1])
        return a[2] + (b[2] - a[2]) * (0.5 - 0.5 * math.cos(math.pi * s))
      end
    end
    return t[#t][2]
  end
end
local Z0, Z1 = -1.38, 1.11
-- Bottom, half-width, the side walls' top (the lip), the top's middle where there is no trough, how much trough.
local bot = keys{{-1.38, -0.05}, {-1.3, -0.17}, {-1.12, -0.29}, {-0.9, -0.335}, {0.8, -0.335}, {0.94, -0.3}, {1.04, -0.21}, {1.11, -0.06}}
local wid = keys{{-1.38, 0.02}, {-1.32, 0.15}, {-1.18, 0.28}, {-0.98, 0.37}, {-0.8, 0.4}, {0.6, 0.4}, {0.78, 0.38},
  {0.92, 0.34}, {1.02, 0.27}, {1.08, 0.16}, {1.11, 0.05}}
local lip = keys{{-1.38, -0.03}, {-1.3, 0.02}, {-1.12, 0.08}, {-0.86, 0.13}, {-0.56, 0.11}, {-0.26, 0.0},
  {0.1, 0.07}, {0.4, 0.0}, {0.56, 0.12}, {0.7, 0.21}, {0.9, 0.2}, {1.0, 0.15}, {1.07, 0.07}, {1.11, 0.0}}
local crown = keys{{-1.38, -0.02}, {-1.3, 0.04}, {-1.12, 0.14}, {-0.86, 0.2}, {-0.64, 0.19}, {0.5, 0.14},
  {0.62, 0.32}, {0.76, 0.41}, {0.88, 0.39}, {0.99, 0.3}, {1.07, 0.15}, {1.11, 0.03}}
local trough = keys{{-0.7, 0}, {-0.6, 1}, {0.45, 1}, {0.54, 0}}
local IX, FLOOR = 0.285, -0.275
local function section(z)
  local B, W, T, Tc, d = bot(z), wid(z), lip(z), crown(z), trough(z)
  local H = T - B
  local lx = W * 0.8 + ((W + IX) / 2 - W * 0.8) * d
  local right = {
    {0, B}, {0.55 * W, B}, {0.86 * W, B + 0.1 * H}, {W, B + 0.38 * H}, {0.985 * W, B + 0.62 * H},
    {0.94 * W, B + 0.83 * H}, {0.86 * W + 0.14 * lx - 0.14 * W * 0.86, T - 0.015 - 0.0 * H}, {lx, T},
  }
  -- The inside: a dome over to the crown, or the trough's wall and floor.
  local dome, pit = {}, {
    {IX + 0.018, T - 0.012}, {IX, T - 0.05}, {IX, (T + FLOOR) / 2}, {IX - 0.004, FLOOR + 0.04}, {IX - 0.04, FLOOR},
    {IX * 0.45, FLOOR}, {0, FLOOR},
  }
  for k = 1, #pit do
    local a = (k / #pit) * math.pi / 2
    dome[k] = {lx * math.cos(a), T + (Tc - T) * math.sin(a)}
  end
  for k = 1, #pit do
    right[#right + 1] = {dome[k][1] + (pit[k][1] - dome[k][1]) * d, dome[k][2] + (pit[k][2] - dome[k][2]) * d}
  end
  -- The whole loop, round from the bottom's middle up the right (-x looking forward... +x) and down the left.
  local ring = {}
  for i = 1, #right do ring[#ring + 1] = v3(right[i][1], right[i][2], z) end
  for i = #right - 1, 2, -1 do ring[#ring + 1] = v3(-right[i][1], right[i][2], z) end
  return ring
end
local function hull_mesh()
  local zs = {}
  local n = 64
  for i = 0, n do
    local t = i / n
    -- Bunched towards the two ends, where the shape turns fastest.
    zs[#zs + 1] = Z0 + (Z1 - Z0) * (t - 0.035 * math.sin(2 * math.pi * t))
  end
  local verts, faces, m = {}, {}, 0
  for i, z in ipairs(zs) do
    local ring = section(z)
    m = #ring
    for _, v in ipairs(ring) do verts[#verts + 1] = v end
  end
  local function id(i, j) return (i - 1) * m + ((j - 1) % m) + 1 end
  for i = 1, #zs - 1 do
    for j = 1, m do faces[#faces + 1] = {id(i, j), id(i, j + 1), id(i + 1, j + 1), id(i + 1, j)} end
  end
  local back, front = {}, {}
  for j = 1, m do back[#back + 1] = id(1, m + 1 - j); front[#front + 1] = id(#zs, j) end
  faces[#faces + 1] = back
  faces[#faces + 1] = front
  return polyhedron{vertices=verts, faces=faces}
end
local hull = hull_mesh()
-- The grin: the lower half of an ellipsoid scooped out of the head's front, its top edge straight.
local mcx, mcy, mcz, mry, mrz = 0, 0.07, 1.09, 0.19, 0.21
local scoop = intersect(ball(P.grin, mry, mrz, mcx, mcy, mcz, 20), bx(0.8, 0.4, 0.6, 0, mcy - 0.2, mcz))
hull = subtract(hull, scoop)
hull = paint(hull, lime)
hull = paint_if(hull, shade(lime, 0.7), function(f) return f.normal.y < -0.6 end)
hull = paint_if(hull, shade(lime, 0.82), function(f)
  return math.abs(f.center.x) < IX + 0.002 and f.center.y < 0.05 and f.center.z > -0.6 and f.center.z < 0.55
end)
hull = paint_if(hull, maroon, function(f)
  local c = f.center
  local e = ((c.x - mcx) / P.grin) ^ 2 + ((c.y - mcy) / mry) ^ 2 + ((c.z - mcz) / mrz) ^ 2
  return e < 1.04 and c.y < mcy + 0.004 and c.z > 0.8
end)
p[#p + 1] = {hull, nil, 50}
-- The eye stalks, out of the head's top, leaning forward and out.
local eye_y = P.stalk
for _, side in ipairs({-1, 1}) do
  local pts = {}
  for i = 0, 8 do
    local t = i / 8
    pts[#pts + 1] = v3(side * (0.1 + 0.09 * t), 0.24 + (eye_y - 0.3) * t, 0.76 + 0.16 * t - 0.04 * math.sin(math.pi * t))
  end
  p[#p + 1] = {sweep(circle{radius=0.058, segments=10}, path{points=pts}, {caps=true, scale=0.78}), lime}
end
-- The tongue, lolling in the bottom of the grin.
p[#p + 1] = {ball(P.grin * 0.5, 0.04, 0.08, 0, -0.085, 1.0, 14), pink}

-- The eyes: a green cup on each stalk's tip, a yellow eyeball proud of it, a big black pupil and a white glint.
for _, side in ipairs({-1, 1}) do
  local ex, ey, ez = side * 0.2, eye_y, 0.93
  p[#p + 1] = {ball(0.1, 0.1, 0.095, ex, ey + 0.01, ez - 0.028, 14), lime, 30}
  p[#p + 1] = {ball(0.09, 0.09, 0.09, ex + side * 0.005, ey, ez + 0.014, 16), yellow}
  p[#p + 1] = {ball(0.05, 0.055, 0.026, ex + side * 0.01, ey + 0.004, ez + 0.09, 14), black}
  p[#p + 1] = {ball(0.016, 0.016, 0.01, ex + side * 0.03, ey + 0.03, ez + 0.113, 8), white}
end

-- The shell ----------------------------------------------------------------------------------------------------------
-- A tube coiled along a log spiral about the x axis, its section a wide ellipse that grows with the spiral, so each
-- whorl overlaps the one inside it and the groove winds in on both flat-ish sides. Faceted, as drawn.
local function coil(S)
  local k = 0.34                     -- the section's radial half-size, per spiral radius
  local q = 2.0                      -- growth per turn
  local b = math.log(q) / (2 * math.pi)
  local turns = 2.9
  local per = 18
  local N = math.floor(turns * per)
  local M = 12
  local R0 = S / (1 + k)
  local W0 = S * 0.7                -- the shell's half-width across, at its middle
  -- How wide the shell is at a distance from its axis: a squashed ball, the spiral's eye a little sunk.
  local function across(rho)
    local t = math.min(1, rho / (S * 1.03))
    return W0 * math.sqrt(1 - t * t) ^ 1.4 * (0.9 + 0.1 * math.min(1, rho / (0.45 * S)))
  end
  local a0 = math.rad(-80)           -- the mouth of the shell, down and forward into the hull
  local verts, faces = {}, {}
  local function ring(s)
    local R = R0 * math.exp(-b * s)
    local a = a0 + s
    local u = v3(0, math.sin(a), math.cos(a))
    return R, u
  end
  for i = 0, N do
    local s = (N - i) / N * turns * 2 * math.pi
    local R, u = ring(s)
    for j = 0, M - 1 do
      -- Round the whorl's section, squared off so its sides follow the ball and dip into the groove at its edges.
      local ph = 2 * math.pi * j / M
      local rho = R + k * R * math.cos(ph)
      local sn = math.sin(ph)
      local x = (sn < 0 and -1 or 1) * across(rho) * math.abs(sn) ^ 0.75
      verts[#verts + 1] = u * rho + v3(x, 0, 0)
    end
  end
  local function id(i, j) return i * M + (j % M) + 1 end
  for i = 0, N - 1 do
    for j = 0, M - 1 do
      faces[#faces + 1] = {id(i, j), id(i + 1, j), id(i + 1, j + 1), id(i, j + 1)}
    end
  end
  -- The tip, a point at the spiral's eye.
  local Rt, ut = ring(turns * 2 * math.pi + 0.6)
  verts[#verts + 1] = ut * Rt
  local tip = #verts
  for j = 0, M - 1 do faces[#faces + 1] = {tip, id(0, j), id(0, j + 1)} end
  -- The mouth, a flat cap.
  local cap = {}
  for j = M - 1, 0, -1 do cap[#cap + 1] = id(N, j) end
  faces[#faces + 1] = cap
  return polyhedron{vertices=verts, faces=faces}
end
local shell = coil(P.shell)
local sb = bbox(shell)
-- Its front just behind the seat back, its belly sat down on the hump.
shell = translate(shell, v3(0, -0.1 - sb.min.y, -0.585 - sb.max.z))
p[#p + 1] = {shell, purple, 12, true}

-- The seat ----------------------------------------------------------------------------------------------------------
-- A wooden seat back, a plank curved round the driver's back, tipped back, its top rounded; a plank seat under the
-- hips.
local function plank()
  local n = 12
  local half, y0, y1, r, th = 0.33, -0.25, 0.4, 0.14, 0.045
  local verts, faces = {}, {}
  for i = 0, n do
    local x = -half + 2 * half * i / n
    local ex = math.max(0, math.abs(x) - (half - r))
    local top = y1 - (r - math.sqrt(math.max(0, r * r - ex * ex)))
    for _, y in ipairs({y0, top}) do
      local lean = -(y - y0) * 0.16
      local zf = -0.5 - 0.045 * (1 - (x / half) ^ 2) + lean
      verts[#verts + 1] = v3(x, y, zf)
      verts[#verts + 1] = v3(x, y, zf - th)
    end
  end
  -- Per column i: 4 verts, front-bottom, back-bottom, front-top, back-top.
  local function v(i, k) return i * 4 + k end
  for i = 0, n - 1 do
    faces[#faces + 1] = {v(i, 1), v(i + 1, 1), v(i + 1, 3), v(i, 3)}   -- front
    faces[#faces + 1] = {v(i, 2), v(i, 4), v(i + 1, 4), v(i + 1, 2)}   -- back
    faces[#faces + 1] = {v(i, 3), v(i + 1, 3), v(i + 1, 4), v(i, 4)}   -- top
    faces[#faces + 1] = {v(i, 1), v(i, 2), v(i + 1, 2), v(i + 1, 1)}   -- bottom
  end
  faces[#faces + 1] = {v(0, 1), v(0, 3), v(0, 4), v(0, 2)}
  faces[#faces + 1] = {v(n, 1), v(n, 2), v(n, 4), v(n, 3)}
  return polyhedron{vertices=verts, faces=faces}
end
p[#p + 1] = {plank(), brown, 30}
p[#p + 1] = {rbox(0.5, 0.04, 0.38, 0.05, 0, -0.262, -0.27, 0.012), brown}

-- The steering column, from under the wheel forward and down into the dash; a collar where it goes in.
p[#p + 1] = {rod(v3(0, 0.1, 0.1), v3(0, -0.06, 0.5), 0.02, 10), silver}
p[#p + 1] = {rod(v3(0, -0.035, 0.44), v3(0, -0.06, 0.5), 0.034, 12), grey}

-- The frame ----------------------------------------------------------------------------------------------------------
-- Light-wood crossbeams at the axles, silver axles through them out to the hubs, silver plates and hex bolts at the
-- beams' ends; wooden rails and silver tubes front to back beneath the hull.
for _, z in ipairs({-0.7, 0.7}) do
  p[#p + 1] = {rb(0.94, 0.07, 0.09, 0, -0.42, z, 0.008), birch}
  p[#p + 1] = {cyl(0.022, 1.0, 0, -0.42, z, "x", 12), silver}
  for _, sx in ipairs({-1, 1}) do
    p[#p + 1] = {rb(0.08, 0.1, 0.104, sx * 0.39, -0.42, z, 0.006), silver}
    for _, sz in ipairs({-1, 1}) do
      p[#p + 1] = {cyl(0.016, 0.014, sx * 0.39, -0.42, z + sz * 0.057, "z", 6), grey, 20}
    end
    -- A post up from the beam to the hull.
    p[#p + 1] = {rb(0.05, 0.09, 0.012, sx * 0.17, -0.355, z + 0.051, 0.003), silver}
    p[#p + 1] = {cyl(0.012, 0.01, sx * 0.17, -0.365, z + 0.061, "z", 6), grey, 20}
  end
end
for _, sx in ipairs({-1, 1}) do
  p[#p + 1] = {rb(0.05, 0.05, 1.44, sx * 0.27, -0.405, 0, 0.006), birch}
  p[#p + 1] = {cyl(0.016, 1.46, sx * 0.12, -0.428, 0, "z", 10), silver}
  p[#p + 1] = {rb(0.064, 0.064, 0.14, sx * 0.27, -0.405, 0, 0.005), silver}
  p[#p + 1] = {cyl(0.014, 0.012, sx * 0.302, -0.405, 0, "x", 6), grey, 20}
end

part("snail", p)
