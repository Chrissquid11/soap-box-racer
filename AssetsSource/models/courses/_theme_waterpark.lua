-- The Abandoned Water Park's scenery kit (see THEME KITS in _course.lua): cracked pale concrete and faded blue tile
-- with weeds in the joints; big tube flumes in faded red, yellow and blue snaking beside the road on tall legs (and
-- over it, high up); rusty slide towers with a helter-skelter tube round each; empty pools with green puddles, a wave
-- pool, a lazy river channel, and one last pool with water in it at the finish; a shuttered snack bar, lifeguard
-- chairs, broken sunloungers and parasols, palms (some dead), graffiti walls, chain-link fences, inflatable rings.
-- Every piece is one colour's (K.sub by colour) but the flumes, the roofs and the parasols, a few colours each.
local T = {trees = 0, rocks = 0}

local function h2(a, b)
  local s = math.sin(a * 127.1 + b * 311.7) * 43758.5453
  return s - math.floor(s)
end

local INK
function T.paint(x, z, off, ink, TK)
  if not INK then
    INK = {c1 = TK.col(0.74, 0.72, 0.66), c2 = TK.col(0.68, 0.66, 0.61), c3 = TK.col(0.79, 0.77, 0.72),
      crack = TK.col(0.38, 0.37, 0.34), t1 = TK.col(0.4, 0.62, 0.78), t2 = TK.col(0.66, 0.8, 0.86),
      weed = TK.col(0.36, 0.5, 0.2), weed2 = TK.col(0.5, 0.55, 0.25), stain = TK.col(0.55, 0.5, 0.38)}
  end
  local h = h2(math.floor(x * 3.1), math.floor(z * 3.1))
  local hw = (h * 61.7) % 1
  local tile = ((math.floor(x / 2.6) + math.floor(z / 2.6)) % 2 == 0) and INK.t1 or INK.t2
  if off < 2.6 then                                   -- a band of pool tile along the road
    if h < 0.1 then return INK.crack end
    return tile
  end
  if hw < 0.05 + math.min(0.1, off * 0.002) then return (h < 0.5) and INK.weed or INK.weed2 end
  local zone = h2(math.floor(x / 15), math.floor(z / 15))
  if zone < 0.3 then                                  -- a tiled terrace, tiles missing
    if h < 0.14 then return INK.c2 end
    return tile
  end
  if h < 0.06 then return INK.crack end
  if h < 0.11 then return INK.stain end
  return (h < 0.4) and INK.c1 or ((h < 0.7) and INK.c2 or INK.c3)
end

function T.build(K)
  local col = K.col
  local UP = v3(0, 1, 0)
  local pos, right, W, N = K.pos, K.right, K.W, K.N
  local function rnd(a, b) return K.g:range(a, b) end
  local EDGE = K.WALL_T + 1          -- the road's own margin: nothing of the kit's nearer its edge
  local PI2 = math.pi * 2

  local WHITE, DARK = col(0.93, 0.93, 0.9), col(0.05, 0.06, 0.08)
  local CONC, CONC2, CONC3 = col(0.76, 0.74, 0.68), col(0.64, 0.62, 0.57), col(0.42, 0.42, 0.4)
  local TILEW, TILEB, POOLB, POOLD = col(0.85, 0.9, 0.9), col(0.35, 0.58, 0.78), col(0.52, 0.78, 0.86), col(0.2, 0.42, 0.62)
  local SLIME, SLIME2, WATER = col(0.34, 0.55, 0.1), col(0.2, 0.38, 0.1), col(0.1, 0.6, 0.9)
  local F_RED, F_YEL, F_BLUE = col(0.88, 0.27, 0.22), col(0.97, 0.8, 0.25), col(0.22, 0.48, 0.88)
  local RUST, RUST2, STEELW, STEEL, MESH = col(0.58, 0.27, 0.1), col(0.42, 0.19, 0.08), col(0.74, 0.76, 0.74),
    col(0.5, 0.53, 0.52), col(0.62, 0.66, 0.62)
  local PLAST = col(0.9, 0.89, 0.82)
  local PINK, TEAL, ORANGE, PURPLE, GREEN = col(0.95, 0.5, 0.6), col(0.3, 0.72, 0.66), col(0.96, 0.55, 0.18),
    col(0.6, 0.35, 0.78), col(0.4, 0.78, 0.3)
  local FADED = {F_RED, F_YEL, F_BLUE, PINK, TEAL, ORANGE}
  local SPRAY = {col(1, 0.2, 0.6), col(0.3, 0.9, 0.2), col(1, 0.55, 0.05), col(0.65, 0.25, 0.95), col(0.1, 0.8, 0.9), col(0.98, 0.9, 0.1)}
  local TRUNK, TRUNK2 = col(0.5, 0.36, 0.2), col(0.4, 0.28, 0.15)
  local FROND, FROND2, DEAD = col(0.15, 0.55, 0.12), col(0.3, 0.62, 0.1), col(0.6, 0.45, 0.15)
  local WEEDS = {col(0.3, 0.55, 0.12), col(0.42, 0.62, 0.15), col(0.62, 0.6, 0.25)}
  local CREAM, SHUT, WAFER = col(0.95, 0.88, 0.7), col(0.55, 0.57, 0.58), col(0.85, 0.62, 0.3)

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
  -- A round tube through pts (parallel rings square to its whole run), radius rr[j] at each, n-sided.
  local function tube(root, c, pts, rr, n, hint, squash)
    local q = piece(root, c)
    local e1, e2 = perp(normalize(pts[#pts] - pts[1]), hint)
    local rings = {}
    for j, p in ipairs(pts) do
      local ring = {}
      for k = 0, n - 1 do
        local a = (k + 0.5) / n * PI2
        ring[#ring + 1] = p + e1 * (math.cos(a) * rr[j]) + e2 * (math.sin(a) * rr[j] * (squash or 1))
      end
      rings[j] = ring
    end
    K.prism(q, rings, K.flat(c), c, c)
  end
  local function limb(root, c, p0, p1, r0, r1, n) tube(root, c, {p0, p1}, {r0, r1}, n or 6) end
  local T5 = {-0.95, -0.6, 0, 0.6, 0.95}
  local function sph(root, c, cen, r, n)
    local pts, rr = {}, {}
    for _, t in ipairs(T5) do
      pts[#pts + 1] = cen + UP * (r * t)
      rr[#rr + 1] = r * math.sqrt(1 - t * t)
    end
    tube(root, c, pts, rr, n or 6)
  end
  -- A flume: a tube bent along pts (each ring square to the run there), lighter on top, a pale joint every few
  -- rings, its ends dark (open mouths).
  local function flume(pts, r, c, name, n)
    n = n or 10
    local pale, low = K.mix(c, WHITE, 0.5), K.tint(c, 0.72)
    local rings = {}
    for j, p in ipairs(pts) do
      local t = normalize(pts[math.min(#pts, j + 1)] - pts[math.max(1, j - 1)])
      local e1 = cross(t, UP)
      if length(e1) < 0.05 then e1 = v3(1, 0, 0) end
      e1 = normalize(e1)
      local e2 = normalize(cross(e1, t))
      local ring = {}
      for k = 0, n - 1 do
        local a = (k + 0.5) / n * PI2
        ring[#ring + 1] = p + e1 * (math.cos(a) * r) + e2 * (math.sin(a) * r)
      end
      rings[j] = ring
    end
    K.prism(piece(K.deco, "flume" .. name), rings, function(j, k)
      if j % 5 == 0 then return pale end
      return (k <= n / 2) and c or low
    end, DARK, DARK)
  end
  -- An inflatable ring: about cen, square to nrm, R to the tube's middle, rr the tube's radius, in two colours.
  local function ringtoy(root, cen, nrm, R, rr, c1, c2)
    local e1, e2 = perp(normalize(nrm))
    local m = 8
    for k = 0, m - 1 do
      local a0, a1 = (k - 0.06) / m * PI2, (k + 1.06) / m * PI2
      limb(root, (k % 2 == 0) and c1 or c2, cen + e1 * (math.cos(a0) * R) + e2 * (math.sin(a0) * R),
        cen + e1 * (math.cos(a1) * R) + e2 * (math.sin(a1) * R), rr, rr, 6)
    end
  end
  -- Blocky letters, five rows of three: on a face from `org` (the text's top left), tx along it, up, nrm out of it.
  local FONT = {A = "010101111101101", C = "111100100100111", D = "110101101101110", E = "111100111100111",
    H = "101101111101101", I = "111010010010111", K = "101101110101101", L = "100100100100111",
    N = "101111111101101", O = "111101101101111", P = "111101111100100", R = "110101110101101",
    S = "111100111001111", T = "111010010010010", U = "101101101101111", V = "101101101101010",
    W = "101101111111101", Y = "101101010010010", ["8"] = "111101111101111"}
  local function text(root, c, org, tx, up, nrm, str, px, drop)
    for n = 1, #str do
      local gl = FONT[string.sub(str, n, n)]
      if gl and n ~= drop then
        for row = 0, 4 do
          local c0 = nil
          for cc = 0, 3 do
            local on = cc < 3 and string.sub(gl, row * 3 + cc + 1, row * 3 + cc + 1) == "1"
            if on and not c0 then c0 = cc end
            if not on and c0 then
              local mid = ((n - 1) * 4 + (c0 + cc) * 0.5) * px
              obox(root, c, org + tx * mid - up * ((row + 0.5) * px) + nrm * (px * 0.1),
                tx * ((cc - c0) * px * 0.5 - px * 0.04), up * (px * 0.46), nrm * (px * 0.25))
              c0 = nil
            end
          end
        end
      end
    end
  end

  -- ---------------------------------------------------------------- where
  local function off(x, z) local _, d = K.ground_d(x, z); return d - K.HW end   -- metres off the road's edge
  local function clear(x, z, m) return off(x, z) > EDGE + (m or 0.4) end
  -- The nearest sample of the road, and how far off its edge there.
  local function near(x, z)
    local best, bi = 1e18, 1
    for i = 1, N, 6 do
      local dx, dz = pos[i].x - x, pos[i].z - z
      local d = dx * dx + dz * dz
      if d < best then best, bi = d, i end
    end
    for i = math.max(1, bi - 6), math.min(N, bi + 6) do
      local dx, dz = pos[i].x - x, pos[i].z - z
      local d = dx * dx + dz * dz
      if d < best then best, bi = d, i end
    end
    return bi, math.sqrt(best) - W[bi]
  end
  local function grounded(p, dy) return v3(p.x, K.ground(p.x, p.z) + (dy or 0), p.z) end
  -- (What is taken, in a grid of 18 m cells: nothing taken is wider than a cell, so a look at the nine round a point finds it.)
  local taken, CELL = {}, 18
  local function free(x, z, R)
    local cx, cz = math.floor(x / CELL), math.floor(z / CELL)
    for ix = cx - 1, cx + 1 do
      for iz = cz - 1, cz + 1 do
        local cell = taken[ix * 4096 + iz]
        if cell then
          for _, t in ipairs(cell) do
            local dx, dz = t[1] - x, t[2] - z
            if dx * dx + dz * dz < (t[3] + R) * (t[3] + R) then return false end
          end
        end
      end
    end
    return true
  end
  local function take(x, z, R)
    local k = math.floor(x / CELL) * 4096 + math.floor(z / CELL)
    local cell = taken[k]
    if not cell then cell = {}; taken[k] = cell end
    cell[#cell + 1] = {x, z, R}
  end
  -- A plot: centre c, u along and w out (level), half sizes a and b; with its ground's lowest and highest, P a point
  -- of it at a height, at one on its ground, block a box of it.
  local function plot(c, u, w, a, b, i)
    local s = {u = u, w = w, a = a, b = b, i = i}
    s.c = v3(c.x, K.ground(c.x, c.z), c.z)
    function s.P(du, dw, y)
      local p = c + u * du + w * dw
      return v3(p.x, y, p.z)
    end
    function s.at(du, dw)
      local p = c + u * du + w * dw
      return v3(p.x, K.ground(p.x, p.z), p.z)
    end
    function s.block(root, cc, u0, u1, w0, w1, y0, y1)
      K.hexa(piece(root, cc, cc), s.P(u0, w0, y0), s.P(u1, w0, y0), s.P(u1, w1, y0), s.P(u0, w1, y0),
        s.P(u0, w0, y1), s.P(u1, w0, y1), s.P(u1, w1, y1), s.P(u0, w1, y1))
    end
    local lo, hi = 1e9, -1e9
    for _, m in ipairs({{-1, -1}, {1, -1}, {1, 1}, {-1, 1}, {0, 0}, {0, -1}, {0, 1}, {-1, 0}, {1, 0}}) do
      local y = s.at(m[1] * a, m[2] * b).y
      lo, hi = math.min(lo, y), math.max(hi, y)
    end
    s.lo, s.hi = lo, hi
    return s
  end
  -- A plot beside the road near sample i: a along the road by b out from it (half sizes), gap off the margin.
  local PROBE = {{-1, -1}, {0, -1}, {1, -1}, {-1, 0}, {1, 0}, {-1, 1}, {0, 1}, {1, 1}, {-0.5, -1}, {0.5, -1}, {0, 0}}
  local PROBE_S = {{-1, -1}, {1, -1}, {0, -1}, {-1, 1}, {1, 1}}
  local function site(i, side, a, b, gap)
    for _, di in ipairs({0, 2, -2, 4, -4, 7, -7, 10, -10, 14, -14}) do
      for _, sd in ipairs({side, -side}) do
        local j = math.max(3, math.min(N - 2, i + di))
        local w, u = right[j] * sd, K.along(j)
        u = normalize(v3(u.x, 0, u.z))
        local c = pos[j] + w * (W[j] + EDGE + gap + b)
        local R = math.max(a, b)
        local ok = free(c.x, c.z, R * 0.9)
        if ok then
          for _, m in ipairs((R > 3) and PROBE or PROBE_S) do
            local p = c + u * (m[1] * a) + w * (m[2] * b)
            if not clear(p.x, p.z, gap * 0.5) then ok = false; break end
          end
        end
        if ok then
          take(c.x, c.z, R * 0.9)
          return plot(c, u, w, a, b, j)
        end
      end
    end
    return nil
  end
  -- A plot far from the road, turned any way.
  local function far(R, clr)
    for _ = 1, 8 do
      local x, z = K.spot(clr)
      if x and free(x, z, R) then
        take(x, z, R)
        local a = rnd(0, PI2)
        return plot(v3(x, 0, z), v3(math.cos(a), 0, math.sin(a)), v3(-math.sin(a), 0, math.cos(a)), R * 0.7, R * 0.7, 0)
      end
    end
    return nil
  end

  -- ---------------------------------------------------------------- the entrance sign over the road
  do
    local i = K.start + 12
    local t = K.along(i)
    t = normalize(v3(t.x, 0, t.z))
    local r = right[i]
    local half = W[i] + EDGE + 1.1
    local y0 = pos[i].y + math.max(0, K.lift(i, 1), K.lift(i, -1)) + 6.8
    for sd = -1, 1, 2 do
      local f = pos[i] + r * (sd * half)
      obox(K.solid, CONC2, v3(f.x, (K.ground(f.x, f.z) - 0.6 + y0 + 2.4) * 0.5, f.z), r * 0.4, UP * ((y0 + 2.4 - K.ground(f.x, f.z) + 0.6) * 0.5), t * 0.4)
      take(f.x, f.z, 1.2)
      ringtoy(K.deco, v3(f.x, y0 + 3.2, f.z), t, 0.75, 0.24, (sd < 0) and F_RED or F_YEL, WHITE)
    end
    local mid = v3(pos[i].x, y0 + 1.0, pos[i].z)
    obox(K.deco, TILEB, mid, r * (half + 0.9), UP * 0.95, t * 0.14)
    obox(K.deco, F_YEL, mid + UP * 1.02, r * (half + 1.1), UP * 0.06, t * 0.2)
    obox(K.deco, F_YEL, mid - UP * 1.02, r * (half + 1.1), UP * 0.06, t * 0.2)
    local tx = normalize(cross(t, UP))               -- a rider's right, coming down the road
    local px = 0.2
    text(K.deco, WHITE, mid - tx * (12 * 4 * px * 0.5 - px * 0.5) + UP * (2.5 * px) - t * 0.14, tx, UP, t * -1, "SPLASH WORLD", px, 9)
  end

  -- ---------------------------------------------------------------- the flumes beside (and over) the road
  local LEGS = {STEELW, STEELW, RUST}
  local function legs(pts, r)
    for j = 2, #pts - 1, 4 do
      local p = pts[j]
      local _, e = near(p.x, p.z)
      if e > EDGE + 0.8 then
        local t = normalize(pts[j + 1] - pts[j - 1])
        local e1 = normalize(cross(v3(t.x, 0, t.z), UP))
        local tf = normalize(v3(t.x, 0, t.z))
        local c = K.pick(LEGS)
        local fa, fb = p + e1 * (r + 0.7), p - e1 * (r + 0.7)
        local _, ea = near(fa.x, fa.z)
        local _, eb = near(fb.x, fb.z)
        local under = p - UP * (r + 0.1)
        obox(K.solid, c, under, e1 * (r + 0.5), UP * 0.1, tf * 0.22)
        if ea > EDGE + 0.4 and eb > EDGE + 0.4 then
          beam(K.solid, c, grounded(fa, -0.6), under + e1 * (r * 0.5), 0.13, 0.13)
          beam(K.solid, c, grounded(fb, -0.6), under - e1 * (r * 0.5), 0.13, 0.13)
          if p.y - K.ground(p.x, p.z) > 5.5 then
            local ga, gb = grounded(fa, 0), grounded(fb, 0)
            beam(K.deco, c, lerp(ga, under + e1 * (r * 0.5), 0.15), lerp(gb, under - e1 * (r * 0.5), 0.7), 0.05, 0.05)
          end
        else
          beam(K.solid, c, grounded(p, -0.6), under, 0.16, 0.16)
        end
      end
    end
  end
  -- From sample i0 to i1, side0 of the road (crossing to side1 half way, if another), r the tube's radius, amp how
  -- high it rolls.
  local function run(i0, i1, side0, side1, r, c, name, amp, phase)
    local flat_, want, need = {}, {}, {}
    for i = i0, i1, 2 do
      local f = (i - i0) / (i1 - i0)
      local s = side0
      if side1 ~= side0 then
        local u = math.max(0, math.min(1, (f - 0.38) / 0.24))
        s = side0 + (side1 - side0) * (u * u * (3 - 2 * u))
      end
      local o = W[i] + EDGE + r + 1.0 + 1.5 * (1 + math.sin(f * 11 + phase))
      local p = pos[i] + right[i] * (s * o)
      local ii, e = near(p.x, p.z)
      local y = K.ground(p.x, p.z) + r + 1.6 + amp * (1 + math.sin(f * 8 + phase * 2))
      local lift = 0
      if e < EDGE + r + 0.5 then
        lift = math.max(0, pos[ii].y + math.max(0, K.lift(ii, 1), K.lift(ii, -1)) + 6.6 + r - y)
      end
      flat_[#flat_ + 1], want[#want + 1], need[#need + 1] = p, y, lift
      if e > 0.5 then take(p.x, p.z, r + 1.4) end
    end
    local n = #flat_
    local wide = {}
    for j = 1, n do
      local m = 0
      for k = math.max(1, j - 6), math.min(n, j + 6) do m = math.max(m, need[k]) end
      wide[j] = m
    end
    local pts = {}
    for j = 1, n do
      local s, cnt = 0, 0
      for k = math.max(1, j - 3), math.min(n, j + 3) do s = s + wide[k]; cnt = cnt + 1 end
      pts[j] = v3(flat_[j].x, want[j] + math.max(need[j], s / cnt), flat_[j].z)
    end
    flume(pts, r, c, name)
    legs(pts, r)
  end
  local function outside(i)
    local a, b = K.along(math.max(1, i - 12)), K.along(math.min(N, i + 12))
    return (dot(b - a, right[i]) > 0) and -1 or 1
  end
  run(38, 100, 1, -1, 1.0, F_RED, "a", 2.4, 0.3)
  run(118, 178, outside(142), outside(142), 1.05, F_YEL, "b", 2.8, 1.4)
  run(228, 284, outside(252), outside(252), 1.05, F_BLUE, "c", 2.8, 2.2)
  run(292, 332, -1, 1, 0.95, F_RED, "d", 2.2, 4.0)
  run(340, 392, outside(360), outside(360), 1.05, F_YEL, "e", 2.8, 0.9)
  run(404, 466, 1, -1, 1.0, F_BLUE, "f", 2.4, 3.1)

  -- ---------------------------------------------------------------- the lazy river: a dry channel winding by the road
  local function river(i0, i1, side)
    local hw = 1.4
    local bed, k1, k2 = {}, {}, {}
    local mids = {}
    for i = i0, i1, 2 do
      local rt = right[i] * side
      local o = W[i] + EDGE + 0.7 + 0.45 + hw + 1.1 * (1 + math.sin(i * 0.21))
      local c = pos[i] + rt * o
      local y = math.max(K.ground(c.x, c.z), K.ground(c.x - rt.x * (hw + 0.4), c.z - rt.z * (hw + 0.4)),
        K.ground(c.x + rt.x * (hw + 0.4), c.z + rt.z * (hw + 0.4))) + 0.15
      local function sec(l0, l1, top, bot)
        local a, b = c + rt * l0, c + rt * l1
        return {v3(a.x, top, a.z), v3(b.x, top, b.z), v3(b.x, bot, b.z), v3(a.x, bot, a.z)}
      end
      bed[#bed + 1] = sec(-hw, hw, y, y - 1.7)
      k1[#k1 + 1] = sec(-hw - 0.42, -hw - 0.03, y + 0.6, y - 1.6)
      k2[#k2 + 1] = sec(hw + 0.03, hw + 0.42, y + 0.6, y - 1.6)
      mids[#mids + 1] = {c = v3(c.x, y, c.z), rt = rt}
      take(c.x, c.z, hw + 0.9)
    end
    K.prism(piece(K.solid, POOLB), bed, K.flat(POOLB), POOLB, POOLB)
    K.prism(piece(K.solid, CONC), k1, K.flat(CONC), CONC, CONC)
    K.prism(piece(K.solid, CONC), k2, K.flat(CONC), CONC, CONC)
    -- slime in the bed, and a ring left behind
    for j = 2, #mids - 4, 5 do
      local rings = {}
      local sh = rnd(-0.5, 0.5)
      for k = 0, 2 do
        local m = mids[j + k]
        local hw2 = (k == 1) and 0.85 or 0.4
        local a, b = m.c + m.rt * (sh - hw2), m.c + m.rt * (sh + hw2)
        rings[#rings + 1] = {a + UP * 0.05, b + UP * 0.05, b - UP * 0.05, a - UP * 0.05}
      end
      local c = (j % 2 == 0) and SLIME or SLIME2
      K.prism(piece(K.deco, c), rings, K.flat(c), c, c)
    end
    for j = 6, #mids - 2, 9 do
      local m = mids[j]
      ringtoy(K.deco, m.c + UP * 0.2 + m.rt * rnd(-0.4, 0.4), v3(rnd(-0.2, 0.2), 1, rnd(-0.2, 0.2)), 0.5, 0.17, K.pick(FADED), WHITE)
    end
  end
  river(182, 226, 1)
  river(300, 336, 1)

  -- ---------------------------------------------------------------- small things
  local function lounger(p, d)
    local e = normalize(cross(d, UP))
    local a, b = grounded(p - d * 0.5), grounded(p + d * 0.5)
    local d3 = normalize(b - a)
    local up = normalize(cross(e, d3))
    if up.y < 0 then up = up * -1 end
    local mid = (a + b) * 0.5
    local chance = rnd(0, 1)
    local c = K.pick(FADED)
    local back = normalize(d3 * -0.75 + up * 0.66)
    if chance < 0.18 then                             -- on its side
      local oe = e
      e, up = up, oe
      mid = mid + UP * 0.3
      back = normalize(d3 * -0.75 + up * 0.66)
    elseif chance < 0.36 then                         -- its back fallen flat
      back = normalize(d3 * -1 + up * 0.05)
    elseif chance < 0.48 then                         -- a leg gone
      d3 = normalize(d3 + up * 0.28)
      up = normalize(cross(e, d3))
      if up.y < 0 then up = up * -1 end
      mid = mid + UP * 0.05
      back = normalize(d3 * -0.75 + up * 0.66)
    end
    obox(K.deco, c, mid + up * 0.32, d3 * 0.55, up * 0.04, e * 0.32)
    local hinge = mid + up * 0.33 - d3 * 0.58
    obox(K.deco, c, hinge + back * 0.42, back * 0.4, normalize(cross(back, e)) * 0.035, e * 0.32)
    obox(K.deco, PLAST, mid + up * 0.14 + d3 * 0.42, d3 * 0.03, up * 0.15, e * 0.3)
    if chance >= 0.48 or chance < 0.36 then obox(K.deco, PLAST, mid + up * 0.14 - d3 * 0.42, d3 * 0.03, up * 0.15, e * 0.3) end
  end
  local function parasol(p, c, open)
    local base = grounded(p, -0.2)
    local top = base + UP * 2.5 + v3(rnd(-0.3, 0.3), 0, rnd(-0.3, 0.3))
    beam(K.solid, STEELW, base, top, 0.035, 0.035)
    local q = piece(K.deco, "parasol")
    if open then
      local under = top - UP * 0.45
      K.cone(q, K.ring(under, 1.35, 1.35, 8, rnd(0, 1)), under, top + UP * 0.12, function(k) return (k % 2 == 0) and c or WHITE end, CONC2)
    else
      local under = top - UP * 1.5
      K.cone(q, K.ring(under, 0.2, 0.2, 6, 0), under, top + UP * 0.1, function(k) return (k % 2 == 0) and c or WHITE end, CONC2)
    end
  end
  local function chair(p, d)
    local e = normalize(cross(d, UP))
    local H = 2.4
    local lean = v3(rnd(-0.2, 0.2), 0, rnd(-0.2, 0.2))
    local function foot(a, b) return grounded(p + d * (a * 0.7) + e * (b * 0.62), -0.25) end
    local function head(a, b, h) return p + d * (a * 0.36) + e * (b * 0.42) + UP * h + lean * (h / H) end
    for a = -1, 1, 2 do
      for b = -1, 1, 2 do beam(K.solid, PLAST, foot(a, b), head(a, b, H), 0.055, 0.055) end
    end
    obox(K.solid, PLAST, head(0, 0, H + 0.05), d * 0.46, UP * 0.05, e * 0.52)
    obox(K.deco, F_RED, head(-1, 0, H + 0.62), e * 0.5, UP * 0.52, d * 0.04)
    obox(K.deco, WHITE, head(-1, 0, H + 0.62) + d * 0.045, e * 0.09, UP * 0.3, d * 0.012)
    obox(K.deco, WHITE, head(-1, 0, H + 0.62) + d * 0.047, e * 0.3, UP * 0.09, d * 0.012)
    for k = 1, 4 do
      beam(K.deco, PLAST, lerp(foot(1, -1), head(1, -1, H), k / 5), lerp(foot(1, 1), head(1, 1, H), k / 5), 0.035, 0.035)
    end
    if rnd(0, 1) < 0.5 then
      ringtoy(K.deco, head(1, 1, H * 0.55) + e * 0.15, e + UP * 0.3, 0.45, 0.15, F_RED, WHITE)
    end
  end
  local function palm(x, z, h, dead)
    local base = v3(x, K.ground(x, z) - 0.4, z)
    local ang = rnd(0, 6.28)
    local dir = v3(math.cos(ang), 0, math.sin(ang))
    local lean = rnd(0.12, 0.42)
    local pts, rr = {}, {}
    for k = 0, 4 do
      local f = k / 4
      pts[k + 1] = base + UP * (h * f) + dir * (lean * h * f * f)
      rr[k + 1] = 0.36 - 0.17 * f
    end
    for j = 1, 4 do limb(K.solid, (j % 2 == 0) and TRUNK or TRUNK2, pts[j], pts[j + 1] + UP * 0.05, rr[j], rr[j + 1] * 1.12, 6) end
    local top = pts[5]
    local n = dead and 4 or 7
    local a0 = rnd(0, 6.28)
    for k = 1, n do
      local a = a0 + k / n * 6.283 + rnd(-0.2, 0.2)
      local o = v3(math.cos(a), 0, math.sin(a))
      local c = (k % 2 == 0) and FROND or FROND2
      local droop = rnd(0.7, 1.5)
      local reach = rnd(1.6, 2.2)
      if dead or k == 3 then c = DEAD; droop = 2.6; reach = 0.9 end
      local mid = top + o * reach + UP * rnd(0.3, 0.6)
      beam(K.deco, c, top - o * 0.1, mid, 0.36, 0.035)
      beam(K.deco, c, mid - o * 0.05, mid + o * (reach * 0.75) - UP * droop, 0.24, 0.03)
    end
    sph(K.deco, TRUNK2, top - UP * 0.3 + dir * 0.25, 0.2, 5)
  end
  local function loose_ring(p, R)
    local c = K.pick(FADED)
    if rnd(0, 1) < 0.25 then
      ringtoy(K.deco, p + UP * (R + R * 0.3), v3(rnd(-1, 1), 0.15, rnd(-1, 1)), R, R * 0.33, c, WHITE)   -- stood on edge
    else
      ringtoy(K.deco, p + UP * (R * 0.3), v3(rnd(-0.25, 0.25), 1, rnd(-0.25, 0.25)), R, R * 0.33, c, WHITE)
    end
  end

  -- ---------------------------------------------------------------- pools
  -- An empty basin on its plot, its rim level with the highest ground there: "wave" a wave pool (a sloping floor,
  -- the machine's wall at its deep end), "splash" the one with water left in it.
  local function pool(s, kind)
    local a, b, t = s.a, s.b, 0.45
    local top, bot = s.hi + 0.3, s.lo - 0.6
    local depth = (kind == "wave") and 2.3 or 1.6
    local fl = top - depth
    s.block(K.solid, CONC, -a, a, -b, -b + t, bot, top)
    s.block(K.solid, CONC, -a, a, b - t, b, bot, top)
    s.block(K.solid, CONC2, -a, -a + t, -b + t + 0.02, b - t - 0.02, bot, top)
    s.block(K.solid, CONC2, a - t, a, -b + t + 0.02, b - t - 0.02, bot, top)
    -- coping tiles, and the waterline's band of them
    s.block(K.deco, TILEW, -a - 0.08, a + 0.08, -b - 0.08, -b + t + 0.08, top + 0.01, top + 0.1)
    s.block(K.deco, TILEW, -a - 0.08, a + 0.08, b - t - 0.08, b + 0.08, top + 0.01, top + 0.1)
    s.block(K.deco, TILEW, -a - 0.08, -a + t + 0.08, -b + t + 0.11, b - t - 0.11, top + 0.01, top + 0.1)
    s.block(K.deco, TILEW, a - t - 0.08, a + 0.08, -b + t + 0.11, b - t - 0.11, top + 0.01, top + 0.1)
    s.block(K.deco, TILEB, -a + t + 0.03, a - t - 0.03, -b + t - 0.03, -b + t + 0.03, top - 0.4, top - 0.06)
    s.block(K.deco, TILEB, -a + t + 0.03, a - t - 0.03, b - t - 0.03, b - t + 0.03, top - 0.4, top - 0.06)
    s.block(K.deco, TILEB, -a + t - 0.03, -a + t + 0.03, -b + t + 0.06, b - t - 0.06, top - 0.4, top - 0.06)
    s.block(K.deco, TILEB, a - t - 0.03, a - t + 0.03, -b + t + 0.06, b - t - 0.06, top - 0.4, top - 0.06)
    local ia, ib = a - t, b - t
    local function disc(du, dw, y, r, c)
      local p0, p1 = s.P(du, dw, y - 0.06), s.P(du, dw, y + 0.05)
      local turn = rnd(0, 1)
      K.prism(piece(K.deco, c), {K.ring(p0, r, r * 0.8, 9, turn), K.ring(p1, r, r * 0.8, 9, turn)}, K.flat(c), c, c)
    end
    if kind == "splash" then
      s.block(K.deco, WATER, -ia - 0.1, ia + 0.1, -ib - 0.1, ib + 0.1, bot + 0.05, top - 0.3)
      ringtoy(K.deco, s.P(-ia * 0.4, ib * 0.3, top - 0.2), v3(0.05, 1, 0), 0.6, 0.2, F_RED, WHITE)
      ringtoy(K.deco, s.P(ia * 0.45, -ib * 0.35, top - 0.2), v3(-0.05, 1, 0.05), 0.6, 0.2, F_YEL, WHITE)
      ringtoy(K.deco, s.P(ia * 0.1, -ib * 0.1, top - 0.2), v3(0, 1, 0.08), 0.5, 0.17, PINK, WHITE)
    elseif kind == "wave" then
      -- the floor runs down from the beach (+u) to the deep end (-u)
      local y0, y1 = top - depth, top - 0.2
      K.hexa(piece(K.solid, POOLB, POOLB), s.P(-ia - 0.1, -ib - 0.1, bot + 0.05), s.P(ia + 0.1, -ib - 0.1, bot + 0.05),
        s.P(ia + 0.1, ib + 0.1, bot + 0.05), s.P(-ia - 0.1, ib + 0.1, bot + 0.05),
        s.P(-ia - 0.1, -ib - 0.1, y0), s.P(ia + 0.1, -ib - 0.1, y1), s.P(ia + 0.1, ib + 0.1, y1), s.P(-ia - 0.1, ib + 0.1, y0))
      -- the wave machine: a tall wall with dark grilles, striped
      s.block(K.solid, CONC3, -a - 1.3, -a - 0.03, -b, b, bot, top + 1.7)
      for k = -2, 2 do
        s.block(K.deco, DARK, -a + t - 0.04, -a + t + 0.06, k * ib * 0.38 - ib * 0.14, k * ib * 0.38 + ib * 0.14, top - 1.9, top - 0.6)
      end
      s.block(K.deco, F_BLUE, -a - 1.35, -a + 0.0, -b - 0.05, b + 0.05, top + 0.9, top + 1.3)
      s.block(K.deco, WHITE, -a - 1.33, -a - 0.01, -b - 0.04, b + 0.04, top + 0.45, top + 0.75)
      local lvl = y0 + (y1 - y0) * 0.42
      K.prism(piece(K.deco, SLIME), {
        {s.P(-ia + 0.02, -ib * 0.8, lvl - 1.0), s.P(-ia + 0.02, ib * 0.7, lvl - 1.0), s.P(-ia + 0.02 + 2 * ia * 0.42, ib * 0.5, lvl - 0.02), s.P(-ia + 0.02 + 2 * ia * 0.42, -ib * 0.6, lvl - 0.02)},
        {s.P(-ia + 0.02, -ib * 0.8, lvl), s.P(-ia + 0.02, ib * 0.7, lvl), s.P(-ia + 0.02 + 2 * ia * 0.42, ib * 0.5, lvl), s.P(-ia + 0.02 + 2 * ia * 0.42, -ib * 0.6, lvl)},
      }, K.flat(SLIME), SLIME, SLIME)
      ringtoy(K.deco, s.P(-ia * 0.5, ib * 0.2, lvl + 0.12), v3(0.1, 1, 0), 0.6, 0.2, F_YEL, WHITE)
      ringtoy(K.deco, s.P(ia * 0.5, -ib * 0.3, y0 + (y1 - y0) * 0.75 + 0.2), v3(-0.3, 1, 0.1), 0.6, 0.2, F_BLUE, WHITE)
    else
      s.block(K.solid, POOLB, -ia - 0.1, ia + 0.1, -ib - 0.1, ib + 0.1, bot + 0.05, fl)
      for k = -1, 1, 2 do
        s.block(K.deco, POOLD, -ia + 0.5, ia - 0.5, k * ib * 0.4 - 0.08, k * ib * 0.4 + 0.08, fl - 0.05, fl + 0.02)
      end
      local m = math.min(ia, ib)
      disc(rnd(-0.3, 0.3) * ia, rnd(-0.1, 0.1) * ib, fl + 0.02, m * rnd(0.55, 0.8), SLIME)
      disc(rnd(0.4, 0.6) * ia, rnd(-0.3, 0.3) * ib, fl + 0.04, m * 0.3, SLIME2)
      if rnd(0, 1) < 0.7 then
        ringtoy(K.deco, s.P(-ia * 0.5, ib * 0.3, fl + 0.22), v3(rnd(-0.2, 0.2), 1, rnd(-0.2, 0.2)), 0.55, 0.18, K.pick(FADED), WHITE)
      end
    end
    -- the steps' handrails at one corner
    for k = -1, 1, 2 do
      local w0 = ib * 0.5 + k * 0.3
      local p0, p1, p2, p3 = s.P(a + 0.25, w0, top - 0.1), s.P(a + 0.25, w0, top + 0.85), s.P(ia - 0.2, w0, top + 0.85), s.P(ia - 0.2, w0, top - 1.1)
      beam(K.deco, STEELW, p0, p1, 0.035, 0.035)
      beam(K.deco, STEELW, p1 - s.u * 0.03, p2 - s.u * 0.03, 0.035, 0.035)
      beam(K.deco, STEELW, p2 + UP * 0.03, p3, 0.035, 0.035)
    end
  end

  -- ---------------------------------------------------------------- the slide tower: rusty, a tube wound round it
  local function tower(s, c, hgt, name)
    local base = s.c.y
    local L, R, r = 1.5, 4.2, 0.85
    local legsxz = {}
    for q, m in ipairs({{-1, -1}, {1, -1}, {1, 1}, {-1, 1}}) do
      local f = s.at(m[1] * L, m[2] * L)
      legsxz[q] = f
      beam(K.solid, RUST, f - UP * 0.6, v3(f.x, base + hgt + 2.3, f.z), 0.14, 0.14)
    end
    beam(K.solid, RUST2, s.c - UP * 0.6, v3(s.c.x, base + hgt + 0.9, s.c.z), 0.17, 0.17)
    local levels = {hgt * 0.34, hgt * 0.67, hgt}
    local prev = 0
    for li, h in ipairs(levels) do
      obox(K.solid, (li == 3) and RUST2 or STEEL, v3(s.c.x, base + h, s.c.z), s.u * (L + 0.55), UP * 0.07, s.w * (L + 0.55))
      for q = 1, 4 do
        local A, B = legsxz[q], legsxz[q % 4 + 1]
        if (q + li) % 2 == 0 then A, B = B, A end
        beam(K.deco, RUST2, v3(A.x, base + prev + 0.25, A.z), v3(B.x, base + h - 0.25, B.z), 0.05, 0.05)
      end
      -- a flight of stairs up the outer face
      local sg = (li % 2 == 0) and 1 or -1
      beam(K.deco, STEEL, s.P(-L * sg, L + 0.45, base + prev + 0.1), s.P(L * sg, L + 0.45, base + h), 0.38, 0.05)
      prev = h
    end
    for q = 1, 4 do
      local A, B = legsxz[q], legsxz[q % 4 + 1]
      beam(K.deco, RUST, v3(A.x, base + hgt + 1.05, A.z), v3(B.x, base + hgt + 1.05, B.z), 0.045, 0.045)
    end
    local rc = v3(s.c.x, base + hgt + 2.3, s.c.z)
    local pale = K.mix(c, WHITE, 0.5)
    K.cone(piece(K.deco, "roof" .. name), K.ring(rc, 2.9, 2.9, 8, 0.39), rc, rc + UP * 1.6, function(k) return (k % 2 == 0) and c or pale end, DARK)
    local turns, n = 2.25, 27
    local a0 = rnd(0, PI2)
    local pts = {}
    for k = 0, n do
      local f = k / n
      local a = a0 + f * turns * PI2
      local rad = (k == 0) and 1.9 or ((k == 1) and 3.3 or R)
      local x, z = s.c.x + math.cos(a) * rad, s.c.z + math.sin(a) * rad
      local y = base + (hgt + 0.95) * (1 - f) + (r + 0.5) * f
      pts[#pts + 1] = v3(x, math.max(y, K.ground(x, z) + r + 0.25), z)
    end
    flume(pts, r, c, name)
    for k = 3, n - 1, 3 do
      local p = pts[k]
      beam(K.deco, STEEL, v3(s.c.x, p.y - 0.1, s.c.z), p - UP * (r * 0.4), 0.07, 0.07)
    end
  end

  -- ---------------------------------------------------------------- the snack bar, shut
  local function snackbar(s)
    local a, b = s.a, s.b
    local y0 = s.hi + 0.15
    s.block(K.solid, CONC2, -a, a, -b, b, s.lo - 0.6, y0)
    s.block(K.solid, CREAM, -a + 0.4, a - 0.4, -b + 0.5, b - 0.3, y0 + 0.01, y0 + 2.7)
    s.block(K.deco, TEAL, -a + 0.05, a - 0.05, -b + 0.05, b - 0.1, y0 + 2.72, y0 + 2.92)
    local f = -b + 0.5                                -- the front, facing the road
    s.block(K.deco, SHUT, -a + 1.0, a - 2.0, f - 0.06, f + 0.05, y0 + 1.05, y0 + 2.25)
    for k = 0, 4 do
      s.block(K.deco, CONC3, -a + 1.02, a - 2.02, f - 0.08, f - 0.05, y0 + 1.15 + k * 0.24, y0 + 1.19 + k * 0.24)
    end
    s.block(K.deco, PLAST, -a + 0.8, a - 1.8, f - 0.45, f + 0.05, y0 + 0.95, y0 + 1.04)
    s.block(K.deco, RUST2, a - 1.5, a - 0.7, f - 0.05, f + 0.05, y0 + 0.02, y0 + 2.0)
    -- the awning, in tired stripes
    local n = 7
    local x0, x1 = -a + 0.8, a - 1.8
    for k = 0, n - 1 do
      local u0, u1 = x0 + (x1 - x0) * k / n + 0.02, x0 + (x1 - x0) * (k + 1) / n - 0.02
      local c = (k % 2 == 0) and F_RED or WHITE
      if k ~= 4 then
        K.hexa(piece(K.deco, c, c), s.P(u0, f - 0.9, y0 + 2.0), s.P(u1, f - 0.9, y0 + 2.0), s.P(u1, f - 0.02, y0 + 2.5), s.P(u0, f - 0.02, y0 + 2.5),
          s.P(u0, f - 0.9, y0 + 2.06), s.P(u1, f - 0.9, y0 + 2.06), s.P(u1, f - 0.02, y0 + 2.56), s.P(u0, f - 0.02, y0 + 2.56))
      end
    end
    -- the sign on the roof: SNACKS, a letter gone, and a giant cornet
    local tx = normalize(cross(s.w, UP))
    local px = 0.2
    local sc = s.P(0, -b + 0.3, y0 + 2.94 + 0.75)
    local sgn = (dot(tx, s.u) > 0) and 1 or -1
    obox(K.deco, F_YEL, sc - tx * 0.6, tx * 2.7, UP * 0.72, s.w * 0.08)
    text(K.deco, F_RED, sc - tx * (0.6 + 6 * 4 * px * 0.5 - px * 0.5) + UP * (2.5 * px) - s.w * 0.08, tx, UP, s.w * -1, "SNACKS", px, 4)
    local cc = s.P(sgn * (a - 1.1), 0, y0 + 2.93)
    local rim = cc + UP * 1.7
    tube(K.deco, WAFER, {cc + UP * 0.05, rim}, {0.06, 0.62}, 8)
    sph(K.deco, PINK, rim + UP * 0.38, 0.68, 8)
    -- a board in the hatch, and rings stacked by the door
    local bc = s.P(-0.5, f - 0.1, y0 + 1.7)
    obox(K.deco, WHITE, bc, tx * 0.95, UP * 0.3, s.w * 0.02)
    text(K.deco, F_RED, bc - tx * (6 * 4 * 0.07 * 0.5 - 0.035) + UP * (2.5 * 0.07) - s.w * 0.02, tx, UP, s.w * -1, "CLOSED", 0.07, 0)
    for k = 0, 2 do
      ringtoy(K.deco, s.P(sgn * (a - 0.45) * -1, -b + 0.6, y0 + 0.17 + k * 0.3), v3(rnd(-0.06, 0.06), 1, rnd(-0.06, 0.06)), 0.5, 0.16, FADED[k + 1], WHITE)
    end
  end

  -- ---------------------------------------------------------------- a graffiti wall
  local TAGS = {"NO WAVES", "KEEP OUT", "SK8", "DRY", "SPLASH", "WET PAINT", "CLOSED", "SLIDE", "NO DIVING"}
  local function graffiti(s, n)
    local hl, hh = s.a, 1.35
    local y = s.hi + hh - 0.1
    s.block(K.solid, CONC, -hl, hl, -0.14, 0.14, s.lo - 0.6, y + hh)
    local tx = normalize(cross(s.w, UP))
    local face = s.P(0, -0.14, y)
    local str = TAGS[(n - 1) % #TAGS + 1]
    local px = math.min(0.3, (hl * 2 - 0.5) / (#str * 4))
    -- blobs of colour behind, the tag over them, a line under it
    local c1, c2 = SPRAY[(n - 1) % #SPRAY + 1], SPRAY[(n + 2) % #SPRAY + 1]
    for k = 1, 3 do
      obox(K.deco, c2, face + tx * rnd(-hl * 0.6, hl * 0.6) + UP * rnd(-0.4, 0.4) - s.w * 0.01, tx * rnd(0.5, 1.1), UP * rnd(0.3, 0.7), s.w * (0.006 + 0.002 * k))
    end
    text(K.deco, c1, face - tx * (#str * 4 * px * 0.5 - px * 0.5) + UP * (2.5 * px + 0.1) - s.w * 0.03, tx, UP, s.w * -1, str, px, 0)
    obox(K.deco, WHITE, face - UP * (2.5 * px + 0.12) - s.w * 0.03, tx * (#str * 2 * px), UP * 0.05, s.w * 0.012)
  end

  -- ---------------------------------------------------------------- placing: the big things first
  local pools = {}
  local function add_pool(i, side, a, b, kind)
    local s = site(i, side, a, b, 0.9)
    if s then pool(s, kind); pools[#pools + 1] = s end
    return s
  end
  -- the last splash pool at the finish, a chute dropping into it from up the bank
  do
    local s = add_pool(K.fin + 6, 1, 5, 3.6, "splash") or add_pool(K.fin - 12, 1, 4.5, 3.2, "splash")
    if s then
      local top = s.hi + 0.3
      local hd = s.P(0, s.b + 7, 0)
      if clear(hd.x, hd.z, 1.5) then
        local gy = K.ground(hd.x, hd.z)
        local hy = math.max(gy + 3, top + 4.5)
        local pts = {v3(hd.x, hy, hd.z), s.P(0, s.b + 4.5, hy - 0.4), s.P(0, s.b + 2, (hy + top) * 0.5 + 0.6), s.P(0, s.b - 0.6, top + 1.3), s.P(0, 0.4, top + 0.9)}
        flume(pts, 0.85, F_YEL, "z")
        beam(K.solid, RUST, v3(hd.x, gy - 0.6, hd.z), v3(hd.x, hy - 0.8, hd.z), 0.16, 0.16)
        local m = s.P(0, s.b + 2, 0)
        beam(K.solid, RUST, v3(m.x, K.ground(m.x, m.z) - 0.6, m.z), v3(m.x, (hy + top) * 0.5 - 0.3, m.z), 0.14, 0.14)
        take(hd.x, hd.z, 1.5); take(m.x, m.z, 1.5)
      end
    end
  end
  for n, spec in ipairs({{150, 1, F_RED, 11}, {305, -1, F_YEL, 12}, {70, 1, F_BLUE, 10}, {420, 1, F_RED, 10.5}}) do
    local s = site(spec[1], -outside(spec[1]) * spec[2], 5.7, 5.7, 0.9)
    if s then tower(s, spec[3], spec[4], "t" .. n) end
  end
  add_pool(204, -1, 5.5, 5, "wave")
  do
    local s = site(92, -1, 3.8, 2.3, 0.9)
    if s then snackbar(s) end
  end
  for _, spec in ipairs({{28, -1}, {110, 1}, {188, -1}, {262, 1}, {318, -1}, {372, 1}, {398, -1}, {448, 1}}) do
    add_pool(spec[1], spec[2], rnd(3.6, 4.6), rnd(2.6, 3.2), "dry")
  end
  -- the park away from the road: more towers and basins
  for n, c in ipairs({F_BLUE, F_YEL, F_RED, F_BLUE}) do
    local s = far(8.2, 14)
    if s then tower(s, c, rnd(10, 13), "u" .. n) end
  end
  for _ = 1, 7 do
    local s = far(6.5, 12)
    if s then pool(s, "dry") end
  end
  -- lifeguard chairs by the pools
  for n, s in ipairs(pools) do
    local c = site(s.i + ((n % 2 == 0) and 9 or -9), 1, 0.95, 0.95, 0.8)
    if c then chair(c.c, c.w * -1) end
  end
  for n, i in ipairs({52, 134, 245, 352, 470}) do
    local c = site(i, (n % 2 == 0) and 1 or -1, 0.95, 0.95, 0.8)
    if c then chair(c.c, c.w * -1) end
  end
  -- graffiti walls facing the road
  do
    local n = 0
    for i = 16, N - 12, 37 do
      n = n + 1
      local s = site(i, (n % 2 == 0) and 1 or -1, 2.6, 0.5, 0.8)
      if s then graffiti(s, n) end
    end
  end
  -- rows of sunloungers, a parasol to some
  do
    local n = 0
    for i = 20, N - 8, 15 do
      n = n + 1
      local cnt = 2 + n % 3
      local s = site(i, (n % 2 == 0) and -1 or 1, cnt * 0.62 + 0.3, 1.1, 0.8)
      if s then
        for k = 1, cnt do
          local du = (k - (cnt + 1) * 0.5) * 1.25
          local p = s.P(du + rnd(-0.1, 0.1), rnd(-0.2, 0.2), 0)
          local turn = rnd(-0.35, 0.35)
          lounger(p, normalize(s.w * -1 + s.u * turn))
        end
        if n % 2 == 0 then parasol(s.P(0.62, 0.7, 0), K.pick(FADED), n % 4 ~= 0) end
      end
    end
  end
  -- palms along the road and about the park, a third of them dead
  for i = 8, N - 5, 8 do
    local sd = (rnd(0, 1) < 0.5) and 1 or -1
    local p = pos[i] + right[i] * (sd * (W[i] + EDGE + 1.0 + rnd(0, 7)))
    if clear(p.x, p.z, 0.8) and free(p.x, p.z, 0.9) then
      take(p.x, p.z, 0.9)
      palm(p.x, p.z, rnd(5.5, 8.5), rnd(0, 1) < 0.33)
    end
  end
  for _ = 1, 60 do
    local x, z = K.spot(5)
    if x and free(x, z, 1) then
      take(x, z, 1)
      palm(x, z, rnd(5.5, 9), rnd(0, 1) < 0.33)
    end
  end
  -- inflatable rings lying about
  for i = 14, N - 6, 13 do
    local sd = (rnd(0, 1) < 0.5) and 1 or -1
    local p = pos[i] + right[i] * (sd * (W[i] + EDGE + 1.2 + rnd(0, 4)))
    if clear(p.x, p.z, 1.0) and free(p.x, p.z, 0.8) then
      take(p.x, p.z, 0.8)
      loose_ring(grounded(p), rnd(0.5, 0.75))
    end
  end

  -- ---------------------------------------------------------------- chain-link fences along the road, torn
  local function fence(i0, i1, side)
    local posts = {}
    for i = i0, i1, 3 do
      local p = pos[i] + right[i] * (side * (W[i] + EDGE + 0.3))
      local rec = false
      if clear(p.x, p.z, 0.05) then
        local base = grounded(p)
        rec = {base = base, top = base + UP * (2.1 * rnd(0.93, 1.05)) + v3(rnd(-0.12, 0.12), 0, rnd(-0.12, 0.12))}
      end
      posts[#posts + 1] = rec
    end
    for idx = 1, #posts do
      local a, b = posts[idx], posts[idx + 1]
      if a then beam(K.solid, STEEL, a.base - UP * 0.4, a.top, 0.05, 0.05) end
      if a and b then
        local torn = rnd(0, 1)
        if torn > 0.1 then beam(K.solid, STEEL, a.top - UP * 0.04, b.top - UP * 0.04, 0.03, 0.03) end
        if torn > 0.22 then
          local m = 3
          beam(K.deco, MESH, lerp(a.base, a.top, 0.5), lerp(b.base, b.top, 0.5), 0.012, 0.022)
          for k = 0, m - 1 do
            local b0, b1 = lerp(a.base, b.base, k / m) + UP * 0.1, lerp(a.base, b.base, (k + 1) / m) + UP * 0.1
            local t0, t1 = lerp(a.top, b.top, k / m) - UP * 0.06, lerp(a.top, b.top, (k + 1) / m) - UP * 0.06
            beam(K.deco, MESH, b0, t1, 0.009, 0.022)
            beam(K.deco, MESH, b1, t0, 0.015, 0.022)
          end
        elseif torn > 0.1 then                        -- the mesh hanging off one post
          beam(K.deco, MESH, a.top - UP * 0.1, lerp(a.base, b.base, 0.6) + UP * 0.1, 0.012, 0.022)
          beam(K.deco, MESH, lerp(a.base, a.top, 0.5), lerp(a.base, b.base, 0.35) + UP * 0.1, 0.012, 0.022)
        end
      end
    end
  end
  do
    local n = 0
    for i = 14, N - 34, 44 do
      n = n + 1
      fence(i, i + 27, (n % 2 == 0) and 1 or -1)
    end
  end

  -- ---------------------------------------------------------------- weeds through the cracks
  local function tuft(p)
    local c = K.pick(WEEDS)
    local q = piece(K.deco, c)
    for _ = 1, 3 do
      local b = p + v3(rnd(-0.15, 0.15), -rnd(0.03, 0.09), rnd(-0.15, 0.15))
      K.cone(q, K.ring(b, 0.08, 0.08, 3, rnd(0, 2)), b, b + v3(rnd(-0.25, 0.25), rnd(0.4, 0.95), rnd(-0.25, 0.25)), K.flat(c), c)
    end
  end
  for _ = 1, 500 do
    local i = math.floor(rnd(3, N - 2))
    local sd = (rnd(0, 1) < 0.5) and 1 or -1
    local f = rnd(0, 1)
    local p = pos[i] + right[i] * (sd * (W[i] + EDGE + 0.25 + f * f * 11))
    local y, d = K.ground_d(p.x, p.z)
    if d - K.HW > EDGE + 0.15 then tuft(v3(p.x, y, p.z)) end
  end
end

return T
