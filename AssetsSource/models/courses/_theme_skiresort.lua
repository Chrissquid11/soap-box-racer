-- The Ski Resort in Summer's scenery kit (see THEME KITS in _course.lua): an Alpine resort out of season. Green-brown
-- meadows with dirty leftover snow (painted, and drifts lying on it), two chairlifts crossing the course high over
-- the road -- pylons, cables, chairs, a shed at each end -- and a gondola off up to the peaks from its station,
-- wooden chalets and a HOTEL, piste signs and marker poles, orange safety nets round the bends, snow cannons, the
-- concrete trough of a bobsleigh run beside some straights (a sled left in it), a huge heap of machine snow with a
-- piste basher, grazing cows with bells, pines, and a ring of snowy peaks round the valley's edge.
local T = {trees = 0.8}

-- Where the last of the snow lies: above 0.76 a patch, just under it the slush round one.
local function snowf(x, z)
  return 0.5 + 0.25 * (math.sin(x * 0.052 + math.sin(z * 0.041) * 2.3 + 1.3) + math.sin(z * 0.047 + math.sin(x * 0.036) * 1.9))
end

local INKS
function T.paint(x, z, off, ink, TK)
  if not INKS then
    INKS = {base = TK.col(0.3, 0.44, 0.14), dry = TK.col(0.46, 0.42, 0.18), brown = TK.col(0.38, 0.3, 0.15),
      lush = TK.col(0.22, 0.48, 0.12), dark = TK.col(0.2, 0.36, 0.1), snow = TK.col(0.9, 0.92, 0.95),
      snow2 = TK.col(0.78, 0.8, 0.82), slush = TK.col(0.55, 0.52, 0.45), mud = TK.col(0.33, 0.25, 0.13),
      flower = TK.col(0.75, 0.7, 0.2)}
  end
  local s = snowf(x, z)
  local h2 = TK.hash(math.floor(x * 2) + 13, math.floor(z * 2) + 57)
  if s > 0.76 then return (h2 > 0.8) and INKS.snow2 or INKS.snow end
  if s > 0.71 then return (h2 > 0.5) and INKS.slush or INKS.mud end
  local h1 = 0.5 + 0.25 * (math.sin(x * 0.083 + math.sin(z * 0.057) * 2.1) + math.sin(z * 0.101 + math.sin(x * 0.066) * 1.7))
  if off < 2.5 and h2 > 0.55 then return INKS.mud end
  if h2 > 0.95 then return INKS.flower end
  if h2 < 0.06 then return INKS.dark end
  if h1 > 0.78 then return INKS.brown end
  if h1 > 0.6 then return INKS.dry end
  if h1 < 0.25 then return INKS.lush end
  return INKS.base
end

function T.build(K)
  local col = K.col
  local UP = v3(0, 1, 0)
  local pos, right, W, N = K.pos, K.right, K.W, K.N
  local function rnd(a, b) return K.g:range(a, b) end
  local EDGE = K.WALL_T + 1          -- the road's own margin: nothing of the kit's nearer its edge

  local WHITE, BLACK = col(0.93, 0.93, 0.9), col(0.03, 0.03, 0.03)
  local SNOW, SNOW2, GRIT = col(0.92, 0.94, 0.97), col(0.72, 0.75, 0.78), col(0.45, 0.4, 0.32)
  local STEEL, STEEL2, CABLE = col(0.55, 0.6, 0.6), col(0.3, 0.33, 0.35), col(0.08, 0.08, 0.09)
  local CONC, CONC2, CONC3 = col(0.66, 0.65, 0.61), col(0.5, 0.5, 0.48), col(0.78, 0.77, 0.72)
  local RED, YEL, BLUE, ORANGE, GREEN = col(0.88, 0.07, 0.05), col(0.98, 0.78, 0.05), col(0.08, 0.3, 0.9),
    col(1.0, 0.42, 0.02), col(0.1, 0.5, 0.18)
  local TIMBER, TIMBER2, TIMBER3 = col(0.36, 0.2, 0.09), col(0.25, 0.14, 0.06), col(0.5, 0.31, 0.14)
  local PLASTER, STONE, ROOF, ROOF2 = col(0.92, 0.88, 0.76), col(0.6, 0.58, 0.54), col(0.22, 0.2, 0.2), col(0.4, 0.22, 0.16)
  local GLASS, SHUTTER = col(0.1, 0.2, 0.35), col(0.1, 0.4, 0.2)
  local COW, COW2, PINK, HORN, GOLD = col(0.5, 0.25, 0.1), col(0.94, 0.9, 0.82), col(0.95, 0.6, 0.6), col(0.85, 0.8, 0.65),
    col(0.95, 0.7, 0.1)
  local PINES = {col(0.05, 0.24, 0.1), col(0.08, 0.3, 0.12), col(0.04, 0.2, 0.12)}
  local BARK = col(0.26, 0.16, 0.08)
  local ROCK, ROCK2, ROCK3 = col(0.42, 0.42, 0.45), col(0.33, 0.34, 0.38), col(0.5, 0.48, 0.47)

  -- ---------------------------------------------------------------- shapes
  local function piece(root, key, c)
    local q = K.sub(root, key)
    if c then q.ink = c end
    return q
  end
  -- A box of three half-vectors about its centre.
  local function obox(root, c, cen, a, b, d)
    K.hexa(piece(root, c, c), cen - a - b - d, cen + a - b - d, cen + a - b + d, cen - a - b + d,
      cen - a + b - d, cen + a + b - d, cen + a + b + d, cen - a + b + d)
  end
  local function perp(d, hint)
    local e1 = cross(d, hint or UP)
    if length(e1) < 0.05 then e1 = cross(d, v3(1, 0, 0)) end
    e1 = normalize(e1)
    return e1, normalize(cross(d, e1))
  end
  -- A bar from p0 to p1: t1 its half width across (level, or across `hint`), t2 the other half thickness.
  local function beam(root, c, p0, p1, t1, t2, hint)
    local d = (p1 - p0) * 0.5
    local e1, e2 = perp(normalize(d), hint)
    obox(root, c, (p0 + p1) * 0.5, e1 * t1, d, e2 * t2)
  end
  -- A round tube through pts, radius rr[j] at each, n-sided; c a colour, or colour(j, k) with a key for its piece.
  local function tube(root, c, pts, rr, n, hint, squash, key)
    local fn = type(c) == "function"
    local q = piece(root, key or c)
    local e1, e2 = perp(normalize(pts[#pts] - pts[1]), hint)
    local rings = {}
    for j, p in ipairs(pts) do
      local ring = {}
      for k = 0, n - 1 do
        local a = (k + 0.5) / n * math.pi * 2
        ring[#ring + 1] = p + e1 * (math.cos(a) * rr[j]) + e2 * (math.sin(a) * rr[j] * (squash or 1))
      end
      rings[j] = ring
    end
    K.prism(q, rings, fn and c or K.flat(c), fn and c(1, 1) or c, fn and c(#pts - 1, 1) or c)
  end
  local function limb(root, c, p0, p1, r0, r1, n) tube(root, c, {p0, p1}, {r0, r1}, n or 6) end
  local T5 = {-0.95, -0.6, 0, 0.6, 0.95}
  local function egg(root, c, cen, axis, r1, r2, n, hint, key)
    local pts, rr = {}, {}
    for _, t in ipairs(T5) do
      pts[#pts + 1] = cen + axis * t
      rr[#rr + 1] = r1 * math.sqrt(1 - t * t)
    end
    tube(root, c, pts, rr, n or 7, hint, r2 / r1, key)
  end
  local function sph(root, c, cen, r, n) egg(root, c, cen, UP * r, r, r, n or 6) end
  -- A gable roof: ridge along r (half length hl), half span hs across a, the eaves at e's height, `rise` to the ridge.
  local function roof(root, c, e, r, a, hl, hs, rise)
    local function sec(sg)
      local m = e + r * (sg * hl)
      return {m - a * hs, m + UP * rise, m + a * hs, m + a * hs - UP * 0.22, m - a * hs - UP * 0.22}
    end
    local lo = K.tint(c, 0.7)
    K.prism(piece(root, "roof"), {sec(-1), sec(1)}, function(_, k) return (k == 3 or k == 5 or k == 4) and lo or c end, lo, lo)
  end

  -- ---------------------------------------------------------------- where
  local function at(x, z) return v3(x, K.ground(x, z), z) end
  local function off(x, z) local _, d = K.ground_d(x, z); return d - K.HW end   -- metres off the road's edge
  local function clear(x, z, m) return off(x, z) > EDGE + (m or 0.4) end
  local function inside(x, z, m) return x > K.X0 + m and x < K.X1 - m and z > K.Z1 + m and z < K.Z0 - m end
  local lines = {}                   -- the lifts lines: nothing else stands under one
  local function near_line(x, z, m)
    for _, l in ipairs(lines) do
      local s = (x - l.ax) * l.d.x + (z - l.az) * l.d.z
      if s > -6 and s < l.L + 6 then
        local dx, dz = x - (l.ax + l.d.x * s), z - (l.az + l.d.z * s)
        if dx * dx + dz * dz < m * m then return true end
      end
    end
    return false
  end
  local taken = {}
  local function free(x, z, R)
    if near_line(x, z, R + 3.5) then return false end
    for _, t in ipairs(taken) do
      local dx, dz = t[1] - x, t[2] - z
      if dx * dx + dz * dz < (t[3] + R) * (t[3] + R) then return false end
    end
    return true
  end
  local function take(x, z, R) taken[#taken + 1] = {x, z, R} end
  -- A plot beside the road near sample i: a along the road by b out from it (half sizes), gap off the margin.
  local function site(i, side, a, b, gap)
    for _, di in ipairs({0, 3, -3, 6, -6, 10, -10, 15, -15, 20, -20}) do
      for _, sd in ipairs({side, -side}) do
        local j = math.max(3, math.min(N - 2, i + di))
        local w, u = right[j] * sd, K.along(j)
        local c = pos[j] + w * (W[j] + EDGE + gap + b)
        local R = math.max(a, b)
        local ok = free(c.x, c.z, R * 0.9)
        if ok then
          for _, m in ipairs({{-1, -1}, {0, -1}, {1, -1}, {-1, 0}, {1, 0}, {-1, 1}, {0, 1}, {1, 1}, {-0.5, -1}, {0.5, -1}, {0, 0}}) do
            local p = c + u * (m[1] * a) + w * (m[2] * b)
            if not clear(p.x, p.z, gap * 0.5) then ok = false; break end
          end
        end
        if ok then
          take(c.x, c.z, R * 0.9)
          local s = {u = u, w = w, a = a, b = b, i = j}
          s.c = at(c.x, c.z)
          function s.at(du, dw)
            local p = c + u * du + w * dw
            return at(p.x, p.z)
          end
          return s
        end
      end
    end
    return nil
  end

  -- ---------------------------------------------------------------- the lifts
  -- A lift from (ax, az) to (bx, bz): a shed at each end, pylons between (each slid along the line till it stands
  -- clear of the road), two cables, and chairs (or gondola cabins) hung from them. Every pylon is raised till the
  -- lowest thing hung from its cables is 6 m and more over the road, and off the ground everywhere else.
  local function lift(ax, az, bx, bz, kind, c1, c2)
    local d = normalize(v3(bx - ax, 0, bz - az))
    local L = length(v3(bx - ax, 0, bz - az))
    local e = v3(d.z, 0, -d.x)
    local HANG = (kind == "gondola") and 4.3 or 3.3
    local GA = (kind == "gondola") and 1.9 or 2.3          -- the cables' half gauge
    local nodes = {}
    local n = math.max(2, math.floor(L / 36 + 0.5))
    for k = 0, n do
      local s0 = k / n * L
      local found
      for _, sh in ipairs({0, 3, -3, 6, -6, 9, -9, 12, -12, 15, -15}) do
        local s = s0 + ((k == 0 or k == n) and math.abs(sh) * ((k == 0) and 1 or -1) or sh)
        local x, z = ax + d.x * s, az + d.z * s
        if off(x, z) > EDGE + ((k == 0 or k == n) and 7 or 4.5) then found = {s = s, x = x, z = z}; break end
      end
      if found then
        found.y = K.ground(found.x, found.z)
        found.h = (k == 0 or k == n) and 7 or 11
        found.fin = (k == 0 or k == n)
        nodes[#nodes + 1] = found
        take(found.x, found.z, found.fin and 7 or 2.5)
      end
    end
    local function top(nd) return v3(nd.x, nd.y + nd.h, nd.z) end
    -- (What each span needs of its cable, a point every 3 m: found once, the ground asked no more than that.)
    local needs = {}
    for j = 1, #nodes - 1 do
      local a, b = nodes[j], nodes[j + 1]
      local m = math.max(2, math.ceil((b.s - a.s) / 3))
      local list = {}
      for q = 0, m do
        local s = a.s + (b.s - a.s) * q / m
        local need = -1e9
        for sd = -1, 1, 2 do
          local gy, dd = K.ground_d(ax + d.x * s + e.x * GA * sd, az + d.z * s + e.z * GA * sd)
          need = math.max(need, (dd - K.HW < EDGE + 4) and (gy + 9.4 + HANG) or (gy + 1.8 + HANG))
        end
        list[#list + 1] = {q / m, need}
      end
      needs[j] = list
    end
    for _ = 1, 8 do
      local raised = false
      for j = 1, #nodes - 1 do
        local a, b = nodes[j], nodes[j + 1]
        local worst = 0
        for _, v in ipairs(needs[j]) do
          worst = math.max(worst, v[2] - (a.y + a.h + (b.y + b.h - a.y - a.h) * v[1]))
        end
        if worst > 0 then a.h = a.h + worst + 0.3; b.h = b.h + worst + 0.3; raised = true end
      end
      if not raised then break end
    end
    lines[#lines + 1] = {ax = ax, az = az, d = d, L = L}

    for j, nd in ipairs(nodes) do
      local t = top(nd)
      local base = v3(nd.x, nd.y - 0.6, nd.z)
      if nd.fin then
        -- The shed: a concrete plinth up to the deck, a boxy hall with a dark mouth towards the line, a coloured roof.
        local sg = (j == 1) and 1 or -1
        local big = (kind == "gondola") and 1.35 or 1
        local hl, hw = 4.2 * big, (GA + 1.6) * big
        local deck = t - UP * (HANG + 0.3)
        obox(K.solid, CONC, lerp(base, deck, 0.5), d * (hl - 0.3), UP * ((deck.y - base.y) * 0.5), e * (hw - 0.3))
        local hall = deck + UP * ((HANG + 1.6) * 0.5 + 0.02)
        obox(K.solid, CONC3, hall, d * hl, UP * ((HANG + 1.6) * 0.5), e * hw)
        obox(K.deco, BLACK, hall + d * (sg * (hl - 0.4)) - UP * 0.2, d * 0.45, UP * ((HANG + 1.6) * 0.5 - 0.5), e * (hw - 0.5))
        obox(K.deco, GLASS, hall + UP * 0.3 - d * (sg * 0.5), d * (hl * 0.55), UP * 0.7, e * (hw + 0.05))
        obox(K.solid, c1, hall + UP * ((HANG + 1.6) * 0.5 + 0.35), d * (hl + 0.6), UP * 0.33, e * (hw + 0.5))
        obox(K.solid, c1, hall + UP * ((HANG + 1.6) * 0.5 + 0.95), d * (hl - 0.6), UP * 0.25, e * (hw - 0.5))
        -- The bull wheel under an awning out front.
        K.column(piece(K.deco, STEEL2, STEEL2), t.x + d.x * sg * (hl + 0.2), t.z + d.z * sg * (hl + 0.2), t.y + 0.05, t.y + 0.3, GA, GA, 12, STEEL2)
      else
        K.column(piece(K.solid, CONC2, CONC2), nd.x, nd.z, base.y, nd.y + 0.5, 0.9, 0.8, 6, CONC2)
        K.column(piece(K.solid, STEEL, STEEL), nd.x, nd.z, nd.y + 0.45, t.y, 0.42, 0.24, 6, STEEL)
        obox(K.deco, YEL, v3(nd.x, nd.y + 2.2, nd.z) + d * 0.4, d * 0.04, UP * 0.3, e * 0.3)
        beam(K.deco, STEEL, t - e * (GA + 0.5) - UP * 0.1, t + e * (GA + 0.5) - UP * 0.1, 0.16, 0.16)
        for sd = -1, 1, 2 do
          local c = t + e * (GA * sd) + UP * 0.12
          obox(K.deco, STEEL2, c, d * 1.3, UP * 0.1, e * 0.09)
          obox(K.deco, c1, c + UP * 0.2 - e * (sd * 0.3), d * 0.5, UP * 0.07, e * 0.28)
        end
      end
    end
    -- The cables, and what hangs from them.
    local run = 4
    for j = 1, #nodes - 1 do
      local a, b = nodes[j], nodes[j + 1]
      local ta, tb = top(a) + UP * 0.27, top(b) + UP * 0.27
      local len = length(tb - ta)
      local dir = normalize(tb - ta)
      for sd = -1, 1, 2 do
        beam(K.deco, CABLE, ta + e * (GA * sd) + dir * 0.02, tb + e * (GA * sd) - dir * 0.02, 0.035, 0.035)
      end
      while run < len - 2.5 do
        if run > 2.5 then
          for sd = -1, 1, 2 do
            local f = d * sd                                  -- the way it faces: up one side, down the other
            local p = ta + dir * (run + (sd > 0 and 0 or 5.5)) + e * (GA * sd)
            if run + 5.5 < len - 2 or sd > 0 then
              local c = ((math.floor(run / 11) + j) % 2 == 0) and c1 or c2
              if kind == "gondola" then
                beam(K.deco, STEEL2, p, p - UP * 1.9, 0.05, 0.05)
                local cc = p - UP * 3.0
                obox(K.deco, c, cc - UP * 0.72, d * 1.05, UP * 0.42, e * 0.95)
                obox(K.deco, GLASS, cc + UP * 0.12, d * 1.0, UP * 0.4, e * 0.9)
                obox(K.deco, c, cc + UP * 0.82, d * 1.05, UP * 0.28, e * 0.95)
              else
                beam(K.deco, STEEL2, p, p - UP * 1.5, 0.04, 0.04)
                beam(K.deco, STEEL2, p - UP * 1.52 - e * 1.0, p - UP * 1.52 + e * 1.0, 0.04, 0.04)
                for q = -1, 1, 2 do
                  beam(K.deco, STEEL2, p - UP * 1.58 + e * (q * 0.97), p - UP * 2.55 + e * (q * 0.97), 0.03, 0.03)
                end
                obox(K.deco, c, p - UP * 2.62, e * 0.94, UP * 0.06, f * 0.3)
                obox(K.deco, c, p - UP * 2.25 - f * 0.33, e * 0.94, UP * 0.3, f * 0.04)
                beam(K.deco, STEEL2, p - UP * 3.1 + f * 0.5 - e * 0.9, p - UP * 3.1 + f * 0.5 + e * 0.9, 0.03, 0.03)
              end
            end
          end
        end
        run = run + 11
      end
      run = run - len
    end
  end
  lift(-64, -14, -73, -294, "chair", RED, YEL)
  lift(-150, -88, 5, -192, "chair", BLUE, ORANGE)
  lift(-128, -240, K.X0 + 6, -118, "gondola", RED, WHITE)

  -- ---------------------------------------------------------------- chalets and the hotel
  -- A window on a wall: at p, facing n (out), e along the wall.
  local function window(p, n, e, hw, hh, shut)
    obox(K.deco, WHITE, p + n * 0.03, e * (hw + 0.1), UP * (hh + 0.1), n * 0.04)
    obox(K.deco, GLASS, p + n * 0.06, e * hw, UP * hh, n * 0.04)
    if shut then
      for q = -1, 1, 2 do obox(K.deco, shut, p + n * 0.05 + e * (q * (hw + 0.38)), e * 0.24, UP * (hh + 0.05), n * 0.04) end
    end
  end
  local function chalet(s, hu, hw, shut)
    local u, w = s.u, s.w
    local lo = K.lowest(s.c, u, w, hu, hw) - 0.5
    local fl = s.c.y + hw * 0.3 + 0.2
    local n = w * -1                                           -- the front faces the road
    obox(K.solid, PLASTER, v3(s.c.x, (lo + fl + 2.5) * 0.5, s.c.z), u * hu, UP * ((fl + 2.5 - lo) * 0.5), w * hw)
    local tim = K.pick({TIMBER, TIMBER3})
    obox(K.solid, tim, v3(s.c.x, fl + 3.85, s.c.z), u * (hu + 0.18), UP * 1.3, w * (hw + 0.18))
    -- A low wide roof, its gable to the road, a snow-white... no: bare boards, stones on it.
    local rc = K.pick({ROOF, ROOF2})
    roof(K.solid, rc, v3(s.c.x, fl + 5.1, s.c.z), w, u, hw + 1.5, hu + 1.3, (hu + 1.3) * 0.42)
    obox(K.solid, TIMBER2, v3(s.c.x, fl + 5.9, s.c.z), u * (hu * 0.5), UP * 0.75, w * (hw + 0.1))   -- the gable's boards
    obox(K.solid, STONE, v3(s.c.x, fl + 7.0, s.c.z) + u * (hu * 0.5) + w * (hw * 0.4), u * 0.4, UP * 1.4, w * 0.4)
    -- The balcony along the front, with its geraniums.
    local bc = v3(s.c.x, fl + 2.72, s.c.z) + n * (hw + 0.75)
    obox(K.solid, TIMBER2, bc, u * (hu + 0.1), UP * 0.08, n * 0.55)
    obox(K.solid, TIMBER2, bc + UP * 0.55 + n * 0.5, u * (hu + 0.1), UP * 0.42, n * 0.05)
    obox(K.deco, RED, bc + UP * 1.08 + n * 0.5, u * (hu - 0.1), UP * 0.13, n * 0.16)
    obox(K.deco, GREEN, bc + UP * 0.9 + n * 0.5, u * (hu - 0.05), UP * 0.07, n * 0.14)
    local face = v3(s.c.x, 0, s.c.z) + n * hw
    for q = -1, 1, 2 do
      window(face + u * (q * hu * 0.55) + UP * (fl + 1.4), n, u, 0.5, 0.55, shut)
      window(face + n * 0.18 + u * (q * hu * 0.55) + UP * (fl + 3.9), n, u, 0.5, 0.5, shut)
    end
    obox(K.deco, TIMBER2, face + n * 0.05 + UP * (fl + 1.0), u * 0.5, UP * 1.0, n * 0.05)
    obox(K.solid, STONE, face + n * 0.8 + UP * ((lo + fl) * 0.5), u * 0.9, UP * ((fl - lo) * 0.5), n * 0.8)   -- the step
  end
  -- Block capitals along e, facing n, from p (the word's bottom left): strokes on a unit square, h high.
  local GLYPH = {
    H = {{0, 0, 0, 1}, {1, 0, 1, 1}, {0.06, 0.5, 0.94, 0.5}},
    O = {{0, 0, 0, 1}, {1, 0, 1, 1}, {0.06, 0.03, 0.94, 0.03}, {0.06, 0.97, 0.94, 0.97}},
    T = {{0.5, 0, 0.5, 0.94}, {0, 0.97, 1, 0.97}},
    E = {{0, 0, 0, 1}, {0.06, 0.03, 1, 0.03}, {0.06, 0.5, 0.8, 0.5}, {0.06, 0.97, 1, 0.97}},
    L = {{0, 0, 0, 1}, {0.06, 0.03, 1, 0.03}},
  }
  local function word(text, p, e, n, h, c)
    local x = 0
    for ch in text:gmatch(".") do
      for k, st in ipairs(GLYPH[ch] or {}) do
        local a = p + e * (x + st[1] * h * 0.6) + UP * (st[2] * h)
        local b = p + e * (x + st[3] * h * 0.6) + UP * (st[4] * h)
        local dv = (b - a) * 0.5
        local across = (st[1] == st[3]) and e or UP
        obox(K.deco, c, (a + b) * 0.5 + n * (k * 0.004), dv, across * (h * 0.08), n * (0.07 + k * 0.004))
      end
      x = x + h * 0.6 + h * 0.28
    end
  end
  local function hotel(s)
    local u, w = s.u, s.w
    local hu, hw = s.a - 1.2, s.b - 2.2
    local lo = K.lowest(s.c, u, w, hu, hw) - 0.5
    local fl = s.c.y + hw * 0.3 + 0.2
    local n = w * -1
    local cen = v3(s.c.x, 0, s.c.z)
    obox(K.solid, STONE, cen + UP * ((lo + fl + 3.2) * 0.5), u * (hu + 0.15), UP * ((fl + 3.2 - lo) * 0.5), w * (hw + 0.15))
    obox(K.solid, PLASTER, cen + UP * (fl + 6.25), u * hu, UP * 3.0, w * hw)
    obox(K.solid, TIMBER, cen + UP * (fl + 10.8), u * (hu + 0.2), UP * 1.5, w * (hw + 0.2))
    roof(K.solid, ROOF2, cen + UP * (fl + 12.25), u, w, hu + 1.6, hw + 2.0, (hw + 2.0) * 0.5)
    for q = -1, 1, 2 do
      obox(K.solid, STONE, cen + UP * (fl + 15.5) + u * (q * hu * 0.6) + w * 1.5, u * 0.5, UP * 1.6, w * 0.5)
    end
    local face = cen + n * hw
    local cols = math.floor(hu * 2 / 2.6)
    for fy = 0, 3 do
      local y = fl + 1.7 + fy * 3.05
      for k = 1, cols do
        local du = (k - (cols + 1) * 0.5) * 2.6
        if not (fy == 0 and math.abs(du) < 1.4) then
          window(face + n * ((fy == 0) and 0.15 or (fy == 3) and 0.2 or 0) + u * du + UP * y, n, u, 0.55, 0.7, (fy > 0) and SHUTTER or nil)
        end
      end
      if fy > 0 then
        local bc = face + n * 0.85 + UP * (y - 1.25)
        obox(K.solid, TIMBER2, bc, u * (hu + 0.05), UP * 0.08, n * 0.6)
        obox(K.solid, TIMBER3, bc + UP * 0.55 + n * 0.55, u * (hu + 0.05), UP * 0.4, n * 0.05)
        obox(K.deco, RED, bc + UP * 1.06 + n * 0.55, u * (hu - 0.2), UP * 0.12, n * 0.15)
      end
    end
    obox(K.deco, TIMBER2, face + n * 0.2 + UP * (fl + 1.2), u * 1.0, UP * 1.2, n * 0.06)
    obox(K.solid, STONE, face + n * 1.1 + UP * ((lo + fl) * 0.5), u * 2.2, UP * ((fl - lo) * 0.5), n * 1.0)
    obox(K.solid, RED, face + n * 1.3 + UP * (fl + 2.95), u * 2.4, UP * 0.1, n * 1.2)            -- the porch's awning
    -- HOTEL along the roof's eaves, read from the road.
    local e = normalize(cross(w, UP))
    local h = 1.7
    local wide = 5 * h * 0.6 + 4 * h * 0.28
    local bp = face + n * 2.2 + UP * (fl + 12.5) - e * (wide * 0.5)
    obox(K.deco, TIMBER2, bp + e * (wide * 0.5) - UP * 0.2, e * (wide * 0.5 + 0.4), UP * 0.12, n * 0.12)
    word("HOTEL", bp, e, n, h, RED)
  end

  -- ---------------------------------------------------------------- small things
  -- A fan snow cannon at p, blowing along f: a blue carriage, a mast, a fat yellow barrel tilted up.
  local function cannon(p, f, tall)
    local e = v3(f.z, 0, -f.x)
    local h = tall or 1.5
    obox(K.solid, BLUE, p + UP * 0.45, f * 0.8, UP * 0.3, e * 0.55)
    for q = -1, 1, 2 do
      beam(K.deco, STEEL2, p + UP * 0.3 + e * (q * 0.5) + f * 0.5, p - UP * 0.4 + e * (q * 1.1) + f * 1.0, 0.06, 0.06)
    end
    beam(K.deco, STEEL2, p + UP * 0.3 - f * 0.6, p - UP * 0.4 - f * 1.3, 0.06, 0.06)
    K.column(piece(K.solid, STEEL, STEEL), p.x, p.z, p.y + 0.7, p.y + h + 0.1, 0.16, 0.13, 6, STEEL)
    local ax = normalize(f + UP * 0.45)
    local c = p + UP * (h + 0.6)
    tube(K.solid, YEL, {c - ax * 0.95, c - ax * 0.6, c + ax * 0.8}, {0.3, 0.58, 0.62}, 9)
    tube(K.deco, STEEL2, {c + ax * 0.82, c + ax * 0.98}, {0.68, 0.66}, 9)
    tube(K.deco, BLACK, {c + ax * 0.9, c + ax * 1.02}, {0.52, 0.5}, 9)
  end
  -- A piste sign facing up the road: a pole, a coloured disc on white (blue, red or black run), a board under it.
  local function piste_sign(p, f, c, bc)
    local e = v3(f.z, 0, -f.x)
    beam(K.solid, STEEL, p - UP * 0.4, p + UP * 3.0, 0.05, 0.05)
    tube(K.deco, WHITE, {p + UP * 2.45 - f * 0.03, p + UP * 2.45 + f * 0.07}, {0.56, 0.56}, 10)
    tube(K.deco, c, {p + UP * 2.45 + f * 0.05, p + UP * 2.45 + f * 0.11}, {0.42, 0.42}, 10)
    obox(K.deco, bc, p + UP * 1.6 + f * 0.07, e * 0.6, UP * 0.2, f * 0.03)
    obox(K.deco, WHITE, p + UP * 1.6 + f * 0.1, e * 0.35, UP * 0.06, f * 0.03)
  end
  -- A hiker's signpost: yellow fingers.
  local function fingerpost(p, turn)
    beam(K.solid, STEEL, p - UP * 0.4, p + UP * 2.7, 0.045, 0.045)
    for k = 0, 2 do
      local a = turn + k * 1.9
      local f = v3(math.cos(a), 0, math.sin(a))
      beam(K.deco, YEL, p + UP * (2.5 - k * 0.3) + f * 0.08, p + UP * (2.5 - k * 0.3) + f * 0.95, 0.11, 0.02, UP)
    end
  end
  -- A pine: a trunk and three tiers.
  local function pine(x, z, s)
    local y = K.ground(x, z) - 0.3
    local g = K.pick(PINES)
    local q = piece(K.deco, g)
    local lo = K.tint(g, 0.6)
    K.column(piece(K.deco, BARK, BARK), x, z, y, y + 2.4 * s, 0.22 * s, 0.14 * s, 5, BARK, rnd(0, 6))
    local hi = K.tint(g, 1.25)
    for tier = 0, 2 do
      local by = y + (1.3 + tier * 1.75) * s
      local base = v3(x, by, z)
      K.cone(q, K.ring(base, (2.2 - tier * 0.55) * s, (2.2 - tier * 0.55) * s, 7, tier * 0.6 + x), base,
        base + UP * ((tier == 2) and 3.2 * s or 2.7 * s), function(k) return (k % 3 == 0) and hi or g end, lo)
    end
  end
  -- A cow, facing f: red-brown and white, a white face, horns, a great gold bell; grazing, its head down.
  local function cow(p, f, s, graze)
    local e = v3(f.z, 0, -f.x)
    local seed = math.floor(rnd(0, 97))
    local function patch(j, k) return (K.hash(j * 7 + seed, k * 3 + seed) > 0.62) and COW2 or COW end
    local body = p + UP * (1.2 * s)
    egg(K.solid, patch, body, f * (1.1 * s), 0.5 * s, 0.56 * s, 8, nil, "cow")
    for _, m in ipairs({{0.7, 1}, {0.7, -1}, {-0.75, 1}, {-0.75, -1}}) do
      local top = body + f * (m[1] * s) + e * (m[2] * 0.28 * s) - UP * (0.25 * s)
      limb(K.deco, (m[2] > 0) and COW or COW2, top, v3(top.x, p.y - 0.1, top.z), 0.13 * s, 0.09 * s, 5)
    end
    local sh = body + f * (0.85 * s) + UP * (0.2 * s)
    local head = graze and (p + f * (1.75 * s) + UP * (0.42 * s)) or (body + f * (1.6 * s) + UP * (0.55 * s))
    limb(K.deco, COW, sh, head - f * (0.1 * s), 0.3 * s, 0.2 * s, 6)
    local hd = normalize((head - sh) + f * (graze and 0.3 or 1.2) * s)
    egg(K.deco, COW2, head + hd * (0.15 * s), hd * (0.42 * s), 0.21 * s, 0.24 * s, 6)
    sph(K.deco, PINK, head + hd * (0.5 * s), 0.13 * s, 5)
    local crown = head - hd * (0.12 * s)
    local hu = normalize(cross(e, hd))
    if hu.y < 0 then hu = hu * -1 end
    for q = -1, 1, 2 do
      limb(K.deco, HORN, crown + e * (q * 0.14 * s) + hu * (0.15 * s), crown + e * (q * 0.34 * s) + hu * (0.42 * s), 0.05 * s, 0.015 * s, 4)
      obox(K.deco, COW, crown + e * (q * 0.3 * s) + hu * (0.08 * s), e * (0.12 * s), hu * (0.035 * s), hd * (0.07 * s))
    end
    -- The bell on its collar.
    local neck = lerp(sh, head, 0.6) - UP * (0.3 * s)
    obox(K.deco, RED, lerp(sh, head, 0.6), e * (0.27 * s), UP * (0.27 * s), hd * (0.05 * s))
    obox(K.deco, GOLD, neck - UP * (0.12 * s), e * (0.15 * s), UP * (0.18 * s), f * (0.12 * s))
    sph(K.deco, PINK, body - f * (0.45 * s) - UP * (0.5 * s), 0.2 * s, 5)
    limb(K.deco, COW, body - f * (1.03 * s) + UP * (0.25 * s), body - f * (1.2 * s) - UP * (0.6 * s), 0.05 * s, 0.035 * s, 4)
  end

  -- ---------------------------------------------------------------- the buildings' plots
  local hs = site(40, 1, 12, 8, 3)
  if hs then hotel(hs) end
  for _, v in ipairs({{18, -1}, {120, 1}, {170, -1}, {215, 1}, {262, 1}, {318, -1}, {360, 1}, {405, -1}, {450, 1}, {490, -1}}) do
    local s = site(v[1], v[2], 5.5, 4.2, 3.5)
    if s then chalet(s, rnd(3.6, 4.4), 3.2, K.pick({SHUTTER, RED, false})) end
  end

  -- The huge heap of machine snow: grubby, a cannon up on a tower still pointed at it, a piste basher parked by it.
  local heap = site(295, -1, 13, 10, 4) or site(200, 1, 13, 10, 4)
  if heap then
    local c = heap.c + heap.u * -2 + heap.w * 1
    local q = piece(K.solid, "heap")
    local function dirt(wv)
      local ny = wv.y / math.max(1e-6, length(wv))
      local h = rnd(0, 1)
      if h < 0.1 then return GRIT elseif h < 0.3 or ny < 0.25 then return SNOW2 end
      return SNOW
    end
    K.ball(q, c - UP * 2.5, 10, 8.5, 8, 13, 8, function() return rnd(0.85, 1.1) end, dirt)
    local c2 = heap.c + heap.u * 6.5 - heap.w * 2
    K.ball(q, v3(c2.x, K.ground(c2.x, c2.z) - 1.2, c2.z), 5, 4, 4.5, 10, 6, function() return rnd(0.85, 1.1) end, dirt)
    local tp = heap.at(-11, -7)
    K.column(piece(K.solid, STEEL, STEEL), tp.x, tp.z, tp.y - 0.5, tp.y + 6.5, 0.3, 0.2, 6, STEEL)
    cannon(tp + UP * 6.2, normalize(v3(c.x - tp.x, 0, c.z - tp.z)), 0.4)
    -- The piste basher: tracks, a red cab, the blade out front, the tiller behind.
    local bp = heap.at(9.5, -7.2)
    local f, e = heap.u, heap.w
    for sd = -1, 1, 2 do
      obox(K.solid, BLACK, bp + UP * 0.55 + e * (sd * 1.35), f * 2.6, UP * 0.5, e * 0.5)
    end
    obox(K.solid, RED, bp + UP * 1.25, f * 2.3, UP * 0.45, e * 1.25)
    obox(K.solid, RED, bp + UP * 2.3 + f * 0.7, f * 1.0, UP * 0.62, e * 1.05)
    obox(K.deco, GLASS, bp + UP * 2.35 + f * 0.78, f * 0.96, UP * 0.42, e * 1.08)
    obox(K.solid, STEEL, bp + UP * 0.75 + f * 3.3, f * 0.12, UP * 0.65, e * 2.3)
    obox(K.solid, YEL, bp + UP * 0.6 - f * 3.2, f * 0.4, UP * 0.3, e * 2.1)
    obox(K.deco, ORANGE, bp + UP * 3.05 + f * 0.7, f * 0.15, UP * 0.1, e * 0.3)
  end

  -- ---------------------------------------------------------------- the bobsleigh run
  -- A concrete trough beside a straight, well off the road: a floor and two walls (the far one higher and leaning in,
  -- as a bob run's banking), a red and white lip, a strut across now and then; skipped wherever it would not be clear.
  local function trough(i0, i1, side)
    local sets = {{}, {}, {}}
    local last
    local sled = false
    local function flush()
      if #sets[1] >= 2 then
        local lip = function(j, k) return (k == 3) and ((j % 2 == 0) and RED or WHITE) or ((k == 4) and CONC3 or CONC) end
        K.prism(piece(K.solid, "trough"), sets[1], function(_, k) return (k == 3) and CONC3 or CONC2 end, CONC2, CONC2)
        K.prism(piece(K.solid, "trough"), sets[2], lip, CONC, CONC)
        K.prism(piece(K.solid, "trough"), sets[3], lip, CONC, CONC)
      end
      sets = {{}, {}, {}}
      last = nil
    end
    for i = i0, i1, 3 do
      local w = right[i] * side
      local c = pos[i] + w * (W[i] + EDGE + 3.6)
      local ok = clear(c.x, c.z, 1.8) and free(c.x, c.z, 2.2)
      if ok then
        local far = c + w * 2.2
        ok = clear(far.x, far.z, 3.5)
      end
      if ok and last and dot(c - last, K.along(i)) < 1.5 then ok = false end
      if not ok then
        flush()
      else
        local g = K.ground(c.x, c.z)
        local b = v3(c.x, g, c.z)
        local lo = UP * -1.2
        sets[1][#sets[1] + 1] = {b - w * 1.1 + lo, b + w * 1.1 + lo, b + w * 1.1 + UP * 0.3, b - w * 1.1 + UP * 0.3}
        sets[2][#sets[2] + 1] = {b - w * 1.13 + lo, b - w * 1.42 + lo, b - w * 1.38 + UP * 1.5, b - w * 1.14 + UP * 1.5}
        sets[3][#sets[3] + 1] = {b + w * 1.42 + lo, b + w * 1.13 + lo, b + w * 0.75 + UP * 2.5, b + w * 1.05 + UP * 2.5}
        if #sets[1] % 5 == 3 then
          beam(K.deco, CONC2, b - w * 1.55 + UP * 1.3, b - w * 2.3 - UP * 0.8, 0.14, 0.14)
          beam(K.deco, CONC2, b + w * 1.35 + UP * 2.2, b + w * 2.6 - UP * 0.8, 0.16, 0.16)
        end
        if not sled and #sets[1] == 6 then
          sled = true
          local f = K.along(i)
          local sc = b + UP * 0.72 + w * 0.1
          egg(K.deco, RED, sc, f * 1.5, 0.42, 0.36, 7)
          obox(K.deco, BLACK, sc + UP * 0.3 - f * 0.2, f * 0.7, UP * 0.1, w * 0.3)
          for q = -1, 1, 2 do obox(K.deco, STEEL, sc - UP * 0.36 + w * (q * 0.3), f * 1.1, UP * 0.05, w * 0.03) end
        end
        last = c
      end
    end
    flush()
  end
  trough(58, 106, 1)
  trough(150, 204, -1)
  trough(238, 294, 1)
  trough(328, 384, -1)
  trough(418, 500, 1)

  -- ---------------------------------------------------------------- along the road
  -- Orange safety netting round the outside of the bends; marker poles, piste signs and cannons along the rest.
  local RUNS = {BLUE, RED, BLACK}
  local prev
  for i = 6, N - 6, 4 do
    local a0, a1 = K.along(i), K.along(math.min(N, i + 5))
    local turn = dot(a1, right[i])
    local here
    if math.abs(turn) > 0.14 then
      local sd = (turn > 0) and -1 or 1
      local p = pos[i] + right[i] * (sd * (W[i] + EDGE + 1.0))
      if clear(p.x, p.z, 0.6) and free(p.x, p.z, 0.3) then
        local b = at(p.x, p.z)
        here = {b = b, sd = sd}
        beam(K.solid, STEEL2, b - UP * 0.4, b + UP * 1.9, 0.045, 0.045)
        if prev and prev.sd == sd and length(prev.b - b) < 9 then
          for _, y in ipairs({0.75, 1.55}) do
            beam(K.deco, ORANGE, prev.b + UP * y, b + UP * y, 0.015, 0.26, UP)
          end
        end
      end
    end
    prev = here
  end
  for i = 10, N - 4, 9 do
    for sd = -1, 1, 2 do
      local p = pos[i] + right[i] * (sd * (W[i] + EDGE + 0.5))
      if clear(p.x, p.z, 0.3) and free(p.x, p.z, 0.2) then
        local b = at(p.x, p.z)
        beam(K.deco, ORANGE, b - UP * 0.3, b + UP * 1.5, 0.035, 0.035)
        beam(K.deco, BLACK, b + UP * 1.51, b + UP * 1.75, 0.04, 0.04)
      end
    end
  end
  local nsign = 0
  for i = 24, N - 10, 31 do
    nsign = nsign + 1
    local sd = (nsign % 2 == 0) and 1 or -1
    local p = pos[i] + right[i] * (sd * (W[i] + EDGE + 1.6))
    if clear(p.x, p.z, 1.2) and free(p.x, p.z, 0.8) then
      take(p.x, p.z, 0.8)
      piste_sign(at(p.x, p.z), K.along(i) * -1, RUNS[nsign % 3 + 1], K.pick({ORANGE, YEL, GREEN}))
    end
    local j = math.min(N - 3, i + 14)
    local q = pos[j] + right[j] * (-sd * (W[j] + EDGE + 3.0))
    if clear(q.x, q.z, 2.4) and free(q.x, q.z, 1.6) then
      take(q.x, q.z, 1.6)
      cannon(at(q.x, q.z), normalize(K.along(j) * 0.6 + right[j] * sd), rnd(1.3, 2.4))
    end
  end
  for _ = 1, 9 do
    local x, z = K.spot(4)
    if x and free(x, z, 1) and off(x, z) < 14 then fingerpost(at(x, z), rnd(0, 6)) end
  end

  -- ---------------------------------------------------------------- the meadows
  -- Cows near the road, in twos and threes; drifts of old snow where the paint has it; pines in stands.
  local herd = 0
  for _ = 1, 400 do
    if herd >= 9 then break end
    local x, z = K.spot(5)
    if x and off(x, z) < 16 and inside(x, z, 10) and free(x, z, 4) and snowf(x, z) < 0.7 then
      herd = herd + 1
      take(x, z, 4)
      for k = 1, (herd % 2 == 0) and 3 or 2 do
        local cx, cz = x + rnd(-3, 3), z + rnd(-3, 3)
        if k == 1 then cx, cz = x, z end
        if clear(cx, cz, 2.5) then
          local a = rnd(0, 6.28)
          cow(at(cx, cz), v3(math.cos(a), 0, math.sin(a)), rnd(0.95, 1.2), rnd(0, 1) < 0.6)
        end
      end
    end
  end
  local drifts = 0
  for _ = 1, 3000 do
    if drifts >= 70 then break end
    local x = rnd(K.X0 + 6, K.X1 - 6)
    local z = rnd(K.Z1 + 6, K.Z0 - 6)
    if snowf(x, z) > 0.77 and free(x, z, 2.5) then
      local gy, dd = K.ground_d(x, z)
      local o = dd - K.HW
      if o > EDGE + 4.5 and o < 45 then
        drifts = drifts + 1
        local r = rnd(2.2, 4.5)
        K.ball(piece(K.deco, "drift"), v3(x, gy - 0.25, z), r, r * rnd(0.22, 0.34), r * rnd(0.7, 1), 8, 4,
          function() return rnd(0.85, 1.1) end, function(wv)
            local h = rnd(0, 1)
            return (h < 0.08) and GRIT or ((h < 0.3) and SNOW2 or SNOW)
          end)
      end
    end
  end
  local pines = 0
  for _ = 1, 420 do
    if pines >= 300 then break end
    local x, z = K.spot(11)
    if x and inside(x, z, 11) and free(x, z, 9) then
      for k = 1, 4 do
        local px, pz = x + ((k > 1) and rnd(-6, 6) or 0), z + ((k > 1) and rnd(-6, 6) or 0)
        pine(px, pz, rnd(0.9, 1.7))
        pines = pines + 1
      end
    end
  end

  -- ---------------------------------------------------------------- the peaks
  -- Round the valley's edge: jagged grey mountains, snow from half way up.
  local function peak(x, z, r, y0, y1)
    local turn = rnd(0, 6)
    local n = 9
    local function loop(rad, y, jag)
      local pts = {}
      for k = 0, n - 1 do
        local a = turn + k / n * math.pi * 2
        local rr = rad * rnd(1 - jag, 1 + jag)
        pts[#pts + 1] = v3(x + math.cos(a) * rr, y + rnd(-jag, jag) * (y1 - y0) * 0.25, z + math.sin(a) * rr)
      end
      return pts
    end
    local hgt = y1 - y0
    local rings = {loop(r, y0, 0.12), loop(r * 0.62, y0 + hgt * 0.45, 0.2), loop(r * 0.3, y0 + hgt * 0.76, 0.22), loop(r * 0.03, y1, 0)}
    K.prism(piece(K.deco, "peak"), rings, function(j, k)
      if j == 1 then return (k % 2 == 0) and ROCK or ROCK2 end
      if j == 2 then return (k % 3 == 0) and ROCK3 or ((k % 3 == 1) and SNOW or SNOW2) end
      return (k % 2 == 0) and SNOW or SNOW2
    end, ROCK2, SNOW)
  end
  local function edge_y(x, z)
    return K.ground(math.max(K.X0 + 2, math.min(K.X1 - 2, x)), math.max(K.Z1 + 2, math.min(K.Z0 - 2, z)))
  end
  local OUT = 38
  local per = {}
  for x = K.X0, K.X1, 50 do per[#per + 1] = {x, K.Z0 + OUT}; per[#per + 1] = {x, K.Z1 - OUT} end
  for z = K.Z1 + 25, K.Z0 - 25, 50 do per[#per + 1] = {K.X0 - OUT, z}; per[#per + 1] = {K.X1 + OUT, z} end
  for _, p in ipairs(per) do
    local x, z = p[1] + rnd(-9, 9), p[2] + rnd(-9, 9)
    local ey = edge_y(x, z)
    peak(x, z, rnd(42, 60), ey - 45, ey + rnd(55, 120))
  end
end

return T
