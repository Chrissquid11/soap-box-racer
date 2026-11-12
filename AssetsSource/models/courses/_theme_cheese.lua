-- Cheese-Rolling Hill's scenery kit (see THEME KITS in _course.lua): a very steep, rough English hillside of
-- tussocky grass -- giant Double Gloucester wheels bowling down it (one cut open at the top, its wedge beside it),
-- crowds of spectators on the slopes, picnic blankets whose baskets and hampers have set off downhill, bunting along
-- and over the road, a St John Ambulance tent and its ambulance, hay bale piles, a maypole on the hilltop at the
-- start, woodland at the hill's sides and the village pub (and a cottage or two) on the green at the bottom.
-- Every piece is one colour's (K.sub by colour) but the wheels, the maypole and the trees' crowns, a few each.
local T = {trees = 0.8}

-- The ground: steeper than the library's valley beyond the crowd's strip, lumpy, and levelled into a village green
-- where the road runs out at the bottom.
function T.shape(x, z, off, y, road_y, TK)
  if off <= 8 then return nil end
  local f = math.min(1, (off - 8) / 6)
  local hill = math.max(0, math.min(1, (road_y - 3) / 8))
  local lumps = math.sin(x * 0.37 + math.sin(z * 0.23) * 2) * math.sin(z * 0.33 + math.sin(x * 0.19) * 2) * 0.45
  local y1 = y + (math.min((off - 8) * 0.22, 14) * hill + lumps) * f
  local village = math.max(0, math.min(1, (6 - road_y) / 4)) * f * (1 - math.max(0, math.min(1, (off - 22) / 14)))
  if village > 0 then y1 = y1 + (road_y - 0.5 + off * 0.03 - y1) * village end
  return y1
end

-- Rough grassland: patches of rank, dry and dark grass, tussocks' dark dots, trampled mud by the road.
local INKS
function T.paint(x, z, off, ink, TK)
  if not INKS then
    INKS = {base = TK.col(0.2, 0.44, 0.1), dry = TK.col(0.42, 0.5, 0.15), dark = TK.col(0.13, 0.34, 0.08),
      tuss = TK.col(0.09, 0.26, 0.06), straw = TK.col(0.55, 0.5, 0.2), lush = TK.col(0.26, 0.52, 0.12),
      mud = TK.col(0.32, 0.24, 0.11)}
  end
  local h1 = 0.5 + 0.25 * (math.sin(x * 0.071 + math.sin(z * 0.047) * 2.2) + math.sin(z * 0.093 + math.sin(x * 0.058) * 1.8))
  local h2 = TK.hash(math.floor(x * 2) + 31, math.floor(z * 2) + 17)
  if off < 3 and h2 > 0.45 then return INKS.mud end
  if h2 > 0.93 then return INKS.tuss end
  if h2 < 0.04 then return INKS.straw end
  if h1 > 0.8 then return INKS.dry end
  if h1 < 0.2 then return INKS.dark end
  if h1 > 0.55 then return INKS.lush end
  return INKS.base
end

function T.build(K)
  local col = K.col
  local UP = v3(0, 1, 0)
  local pos, right, W, N = K.pos, K.right, K.W, K.N
  local function rnd(a, b) return K.g:range(a, b) end
  local EDGE = K.WALL_T + 1          -- the road's own margin: nothing of the kit's nearer its edge

  local WHITE, BLACK = col(0.93, 0.93, 0.9), col(0.03, 0.03, 0.03)
  local CHEESE, RIND, PASTE, LABEL = col(0.98, 0.6, 0.08), col(0.5, 0.14, 0.05), col(1.0, 0.78, 0.3), col(0.95, 0.9, 0.7)
  local RED, YEL, BLUE, GREEN, PINK, PURPLE, ORANGE, TEAL = col(0.88, 0.08, 0.05), col(0.98, 0.8, 0.05),
    col(0.08, 0.3, 0.9), col(0.1, 0.62, 0.2), col(0.98, 0.45, 0.7), col(0.55, 0.15, 0.8), col(0.95, 0.42, 0.03),
    col(0.05, 0.6, 0.62)
  local SHIRTS = {RED, YEL, BLUE, GREEN, PINK, PURPLE, ORANGE, TEAL, WHITE}
  local LEGS = {col(0.1, 0.14, 0.32), col(0.2, 0.2, 0.22), col(0.5, 0.42, 0.28)}
  local SKIN = {col(0.95, 0.7, 0.55), col(0.8, 0.55, 0.38), col(0.5, 0.32, 0.2)}
  local FLAGS = {RED, WHITE, BLUE, YEL, GREEN}
  local WICKER, WICKER2 = col(0.62, 0.42, 0.18), col(0.45, 0.28, 0.1)
  local WOOD, WOOD2, DARKWOOD = col(0.5, 0.34, 0.18), col(0.4, 0.27, 0.14), col(0.16, 0.1, 0.06)
  local HAY, HAY2 = K.HAY, K.tint(K.HAY, 0.8)
  local STONE, STONE2, SLATE, THATCH = col(0.8, 0.64, 0.38), col(0.68, 0.53, 0.3), col(0.25, 0.26, 0.3), col(0.62, 0.5, 0.25)
  local GLASS, GOLD = col(0.12, 0.2, 0.32), col(0.95, 0.75, 0.1)
  local SJ_GREEN, AMB_YEL, AMB_GRN, LIGHT = col(0.02, 0.35, 0.16), col(0.85, 0.95, 0.1), col(0.05, 0.5, 0.2), col(0.1, 0.4, 1.0)
  local TUSS = {col(0.1, 0.28, 0.06), col(0.3, 0.46, 0.1), col(0.5, 0.5, 0.18), col(0.16, 0.36, 0.08)}
  local LEAF = {col(0.1, 0.32, 0.06), col(0.16, 0.4, 0.08), col(0.07, 0.25, 0.05), col(0.24, 0.44, 0.1)}
  local BARK = col(0.28, 0.17, 0.09)

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
  local function tube(root, c, pts, rr, n, hint, key)
    local fn = type(c) == "function"
    local q = piece(root, key or c)
    local e1, e2 = perp(normalize(pts[#pts] - pts[1]), hint)
    local rings = {}
    for j, p in ipairs(pts) do
      local ring = {}
      for k = 0, n - 1 do
        local a = (k + 0.5) / n * math.pi * 2
        ring[#ring + 1] = p + e1 * (math.cos(a) * rr[j]) + e2 * (math.sin(a) * rr[j])
      end
      rings[j] = ring
    end
    K.prism(q, rings, fn and c or K.flat(c), fn and c(1, 1) or c, fn and c(#pts - 1, 1) or c)
  end
  local function limb(root, c, p0, p1, r0, r1, n) tube(root, c, {p0, p1}, {r0, r1}, n or 6) end
  local function sph(root, c, cen, r, n)
    local pts, rr = {}, {}
    for _, t in ipairs({-0.95, -0.55, 0, 0.55, 0.95}) do
      pts[#pts + 1] = cen + UP * (t * r)
      rr[#rr + 1] = r * math.sqrt(1 - t * t)
    end
    tube(root, c, pts, rr, n or 6)
  end
  local function randdir(flatness)
    local a = rnd(0, 6.283)
    return normalize(v3(math.cos(a), rnd(-1, 1) * (flatness or 1), math.sin(a)))
  end

  -- ---------------------------------------------------------------- where
  local function off(x, z) local _, d = K.ground_d(x, z); return d - K.HW end   -- metres off the road's edge
  local function clear(x, z, m) return off(x, z) > EDGE + (m or 0.4) end
  local function gy(x, z) return K.ground(x, z) end
  local function on(p, lift) return v3(p.x, gy(p.x, p.z) + (lift or 0), p.z) end
  -- What is taken, in a grid of 24 m cells.
  local grid = {}
  local function cell(x, z) return math.floor(x / 24) * 4096 + math.floor(z / 24) end
  local function free(x, z, R)
    for dx = -1, 1 do
      for dz = -1, 1 do
        local list = grid[cell(x + dx * 24, z + dz * 24)]
        if list then
          for _, t in ipairs(list) do
            local ex, ez = t[1] - x, t[2] - z
            if ex * ex + ez * ez < (t[3] + R) * (t[3] + R) then return false end
          end
        end
      end
    end
    return true
  end
  local function take(x, z, R)
    local k = cell(x, z)
    grid[k] = grid[k] or {}
    table.insert(grid[k], {x, z, math.min(R, 16)})
  end
  -- A plot beside the road near sample i: a along the road by b out from it (half sizes), gap off the margin.
  local function site(i, side, a, b, gap)
    for _, di in ipairs({0, 2, -2, 4, -4, 7, -7, 10, -10, 14, -14}) do
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
          s.c = v3(c.x, gy(c.x, c.z), c.z)
          function s.at(du, dw, lift)
            local p = c + u * du + w * dw
            return v3(p.x, gy(p.x, p.z) + (lift or 0), p.z)
          end
          return s
        end
      end
    end
    return nil
  end
  -- The way downhill at a point (level, unit), and how steep.
  local function downhill(x, z)
    local dx, dz = gy(x + 1.5, z) - gy(x - 1.5, z), gy(x, z + 1.5) - gy(x, z - 1.5)
    local l = math.sqrt(dx * dx + dz * dz)
    if l < 0.02 then return v3(1, 0, 0), 0 end
    return v3(-dx / l, 0, -dz / l), l / 3
  end
  local made = {}
  local function count(k, n) made[k] = (made[k] or 0) + (n or 1) end

  -- ---------------------------------------------------------------- cheeses
  -- A wheel: centre, its axle's direction, radius r, thickness th. The faces orange, the rim a red-brown rind,
  -- a pale label on each face.
  local function wheel(root, cen, axis, r, th)
    local function c(j, _) return (j == 2) and RIND or CHEESE end
    tube(root, c, {cen - axis * (th * 0.5), cen - axis * (th * 0.36), cen + axis * (th * 0.36), cen + axis * (th * 0.5)},
      {r * 0.86, r, r, r * 0.86}, 16, nil, "cheese")
    limb(root, LABEL, cen - axis * (th * 0.5 + 0.05), cen + axis * (th * 0.5 + 0.05), r * 0.36, r * 0.36, 10)
    limb(root, RIND, cen - axis * (th * 0.5 + 0.09), cen + axis * (th * 0.5 + 0.09), r * 0.14, r * 0.14, 8)
  end
  -- A sector of a wheel lying flat: from angle a0 to a1 about the upright through cen (its bottom's middle).
  local function sector(root, cen, r, th, a0, a1, n)
    local function loop(y)
      local pts = {cen + UP * y}
      for k = 0, n do
        local a = a0 + (a1 - a0) * k / n
        pts[#pts + 1] = cen + v3(math.cos(a) * r, y, math.sin(a) * r)
      end
      return pts
    end
    K.prism(piece(root, "cheese"), {loop(0), loop(th)}, function(_, k) return (k == 1 or k == n + 2) and PASTE or RIND end,
      CHEESE, CHEESE)
  end
  -- A rolling wheel standing on its rim at x, z.
  local function rolling(root, x, z, r)
    local d = downhill(x, z)
    local axle = normalize(v3(-d.z, 0, d.x) + d * rnd(-0.35, 0.35) + UP * rnd(-0.22, 0.22))
    wheel(root, v3(x, gy(x, z) + r * 0.96, z), axle, r, r * 0.5)
    count("wheels")
  end

  -- ---------------------------------------------------------------- people
  -- A figure at a ground point p, facing f (level): legs, a bright top, a head; arms up for some, sitting for some.
  local function person(p, f, sc, sit)
    local D = K.deco
    local s = v3(-f.z, 0, f.x)
    local shirt, legs, skin = K.pick(SHIRTS), K.pick(LEGS), K.pick(SKIN)
    local o = p - UP * 0.15
    local hip = sit and 0.3 or 0.95
    if sit then
      obox(D, legs, o + (UP * 0.3 + f * 0.4) * sc, s * (0.24 * sc), UP * (0.14 * sc), f * (0.45 * sc))
    else
      obox(D, legs, o + UP * (0.48 * sc), s * (0.22 * sc), UP * (0.48 * sc), f * (0.14 * sc))
    end
    obox(D, shirt, o + UP * ((hip + 0.36) * sc), s * (0.29 * sc), UP * (0.34 * sc), f * (0.17 * sc))
    obox(D, skin, o + UP * ((hip + 0.9) * sc), s * (0.16 * sc), UP * (0.17 * sc), f * (0.16 * sc))
    local arms = rnd(0, 1)
    if arms < 0.4 then
      for side = -1, 1, 2 do
        local sh = o + UP * ((hip + 0.62) * sc) + s * (side * 0.33 * sc)
        beam(D, shirt, sh, sh + (UP * 0.62 + s * (side * rnd(0.1, 0.4)) + f * 0.1) * sc, 0.07 * sc, 0.07 * sc)
      end
    elseif arms < 0.55 then
      local sh = o + UP * ((hip + 0.62) * sc) + s * (0.33 * sc)
      beam(D, shirt, sh, sh + (UP * 0.3 + s * 0.2 + f * 0.55) * sc, 0.07 * sc, 0.07 * sc)
    end
    count("spectators")
  end
  -- A crowd on the slope behind sample i: rows along the road, each a step further up.
  local function crowd(i, side, n, rows, out)
    local u, w = K.along(i), right[i] * side
    local base = pos[i] + w * (W[i] + out)
    if not free(base.x, base.z, 3) then return end
    take(base.x, base.z, math.max(2.5, n * 0.45))
    for r = 0, rows - 1 do
      for k = 1, n do
        local p = base + u * ((k - (n + 1) / 2) * 1.0 + rnd(-0.25, 0.25) + r * 0.4) + w * (r * 1.5 + rnd(-0.3, 0.3))
        local y, d = K.ground_d(p.x, p.z)
        if d - K.HW > EDGE + 7.5 and rnd(0, 1) < 0.85 then
          local f = normalize(w * -1 + u * rnd(-0.6, 0.6))
          person(v3(p.x, y, p.z), f, rnd(1.05, 1.3))
        end
      end
    end
  end

  -- ---------------------------------------------------------------- picnics
  -- A basket at cen in a frame (a its length, b up, d across), size sc: wicker, a darker lid ajar, a handle, a
  -- gingham cloth showing.
  local function basket(root, cen, a, b, d, sc)
    obox(root, WICKER, cen, a * (0.55 * sc), b * (0.32 * sc), d * (0.36 * sc))
    obox(root, RED, cen + b * (0.34 * sc) + a * (0.1 * sc), a * (0.4 * sc), b * (0.04 * sc), d * (0.3 * sc))
    local lidb = normalize(b + d * 0.7)
    obox(root, WICKER2, cen + b * (0.5 * sc) - d * (0.42 * sc), a * (0.56 * sc), lidb * (0.03 * sc),
      normalize(cross(a, lidb)) * (0.34 * sc))
    local h0, h1 = cen + b * (0.3 * sc) - a * (0.5 * sc), cen + b * (0.3 * sc) + a * (0.5 * sc)
    local t0, t1 = h0 + b * (0.5 * sc) + a * (0.15 * sc), h1 + b * (0.5 * sc) - a * (0.15 * sc)
    beam(root, WICKER2, h0, t0, 0.04 * sc, 0.04 * sc, d)
    beam(root, WICKER2, t0 + a * 0.01, t1 - a * 0.01, 0.04 * sc, 0.04 * sc, d)
    beam(root, WICKER2, t1, h1, 0.04 * sc, 0.04 * sc, d)
    count("baskets")
  end
  local function frame()
    local a = randdir()
    local b, d = perp(a)
    return a, b, d
  end
  local FOOD = {RED, GREEN, WHITE, YEL, ORANGE}
  -- Baskets and what was in them, bounding away downhill from x, z until the road's margin.
  local function tumble(x, z, n, sc)
    local p = v3(x, 0, z)
    for k = 1, n do
      local d = downhill(p.x, p.z)
      p = p + (d + v3(rnd(-0.3, 0.3), 0, rnd(-0.3, 0.3))) * rnd(2.2, 3.6)
      if not clear(p.x, p.z, sc * 0.8 + 0.3) then break end
      local a, b, dd = frame()
      local hop = (k % 2 == 1) and rnd(0.5, 1.6) or 0.1
      basket(K.deco, on(p, sc * 0.5 + hop), a, b, dd, sc)
      for _ = 1, 2 do
        local q = p + v3(rnd(-1.4, 1.4), 0, rnd(-1.4, 1.4))
        local qy, qd = K.ground_d(q.x, q.z)
        local function on(_, lift) return v3(q.x, qy + lift, q.z) end
        if qd - K.HW > EDGE + 0.5 then
          local c = K.pick(FOOD)
          if c == GREEN then
            local a2 = randdir(0.5)
            limb(K.deco, GREEN, on(q, 0.3 + rnd(0, 0.8)), on(q, 0.3) + a2 * 0.6 + UP * rnd(0, 0.8), 0.13, 0.06, 5)
          elseif c == WHITE then
            limb(K.deco, WHITE, on(q, 0.2 + rnd(0, 1)), on(q, 0.26 + rnd(0, 1)) + randdir() * 0.05, 0.3, 0.3, 7)
          else
            sph(K.deco, c, on(q, 0.2 + rnd(0, 1.2)), 0.2, 5)
          end
        end
      end
    end
  end
  -- A blanket laid to the slope at x, z (half size h), gingham in two colours; folk sat round it; its hamper gone.
  local function picnic(x, z, h, runaway)
    local ang = rnd(0, 6.283)
    local u, w = v3(math.cos(ang), 0, math.sin(ang)), v3(-math.sin(ang), 0, math.cos(ang))
    local c = v3(x, gy(x, z) + 0.12, z)
    local a = (on(c + u * h) - on(c - u * h)) * 0.5
    local b = (on(c + w * h) - on(c - w * h)) * 0.5
    local n = normalize(cross(a, b))
    if n.y < 0 then n = n * -1 end
    local main = K.pick({RED, BLUE, GREEN, PINK})
    obox(K.deco, main, c, a, n * 0.05, b)
    for _, o in ipairs({-0.5, 0.5}) do
      obox(K.deco, WHITE, c + a * o + n * 0.02, a * 0.14, n * 0.05, b * 1.02)
      obox(K.deco, WHITE, c + b * o + n * 0.025, a * 1.02, n * 0.05, b * 0.14)
    end
    for k = 1, math.floor(rnd(2, 5)) do
      local t = ang + k * 1.7 + rnd(-0.3, 0.3)
      local o = v3(math.cos(t), 0, math.sin(t))
      local p = c + o * (h + 0.3)
      if clear(p.x, p.z, 7.5) then person(on(p), o * (rnd(0, 1) < 0.6 and -1 or 1), rnd(1.05, 1.25), rnd(0, 1) < 0.6) end
    end
    -- A plate or two and a bottle left behind.
    limb(K.deco, WHITE, c + a * 0.3 + n * 0.08, c + a * 0.3 + n * 0.13, 0.3, 0.3, 7)
    limb(K.deco, GREEN, c - b * 0.3 + n * 0.08, c - b * 0.3 + n * 0.75, 0.12, 0.05, 5)
    if runaway then tumble(x, z, math.floor(rnd(2, 5.5)), rnd(0.9, 1.5))
    else basket(K.deco, c + a * -0.4 + b * 0.35 + n * 0.42, normalize(a), n, normalize(cross(a, n)), 1.0) end
    count("picnics")
  end

  -- ---------------------------------------------------------------- bunting
  local function pennant(p, t, c)
    local n = normalize(cross(t, UP))
    local a, b, tip = p - t * 0.26, p + t * 0.26, p - UP * 0.72
    K.prism(piece(K.deco, c), {{a - n * 0.015, b - n * 0.015, tip - n * 0.015}, {a + n * 0.015, b + n * 0.015, tip + n * 0.015}},
      K.flat(c), c, c)
  end
  local flagn = 0
  -- A string from p0 to p1 (both pole tops), sagging, hung with pennants.
  local function string_of(p0, p1, sag, every)
    local len = length(p1 - p0)
    local parts = math.max(2, math.floor(len / 4 + 0.5))
    local prev = p0
    for k = 1, parts do
      local t = k / parts
      local q = lerp(p0, p1, t) - UP * (sag * math.sin(t * math.pi))
      beam(K.deco, WHITE, prev, q, 0.02, 0.02)
      prev = q
    end
    local n = math.max(2, math.floor(len / every))
    local dir = normalize(v3(p1.x - p0.x, 0, p1.z - p0.z))
    for k = 1, n do
      local t = (k - 0.5) / n
      flagn = flagn + 1
      pennant(lerp(p0, p1, t) - UP * (sag * math.sin(t * math.pi) * 0.96 + 0.03), dir, FLAGS[flagn % #FLAGS + 1])
    end
    count("bunting spans")
  end
  local function pole(p, h, r)
    local top = on(p) + UP * h
    K.column(piece(K.solid, WOOD2, WOOD2), p.x, p.z, gy(p.x, p.z) - 0.5, top.y + 0.1, r, r * 0.8, 6, WOOD2)
    return top
  end
  local function roadside_bunting(i0, i1, side)
    local prev
    for i = i0, i1, 3 do
      local p = pos[i] + right[i] * (side * (W[i] + EDGE + 1.7))
      if clear(p.x, p.z, 1.2) and free(p.x, p.z, 0.3) then
        local top = pole(p, 3.7, 0.08)
        if prev and length(top - prev) < 16 then string_of(prev, top, 0.45, 1.15) end
        prev = top
      else
        prev = nil
      end
    end
  end
  local function over_bunting(i)
    local tops = {}
    local y = pos[i].y + 8.4
    for side = -1, 1, 2 do
      local p = pos[i] + right[i] * (side * (W[i] + EDGE + 1.2))
      if not clear(p.x, p.z, 0.6) then return end
      tops[#tops + 1] = v3(p.x, y, p.z)
    end
    for _, t in ipairs(tops) do
      K.column(piece(K.solid, WOOD, WOOD), t.x, t.z, gy(t.x, t.z) - 0.5, y + 0.15, 0.16, 0.11, 6, WOOD)
      sph(K.deco, GOLD, t + UP * 0.35, 0.24, 6)
      take(t.x, t.z, 0.6)
    end
    string_of(tops[1], tops[2], 0.7, 0.8)
    -- A second string a little way down the road, crossing to the same poles' tops lower.
    string_of(tops[1] - UP * 0.05 + K.along(i) * 0.12, tops[2] - UP * 0.05 + K.along(i) * 0.12, 0.25, 0.8)
  end

  -- ---------------------------------------------------------------- hay
  local function bale(root, cen, u, w, c)
    obox(root, c, cen, u * 0.78, UP * 0.38, w * 0.43)
  end
  local function bale_pile(x, z, wide)
    local ang = rnd(0, 6.283)
    local u, w = v3(math.cos(ang), 0, math.sin(ang)), v3(-math.sin(ang), 0, math.cos(ang))
    local y = gy(x, z)
    for l = 0, wide - 1 do
      local n = wide - l
      for k = 1, n do
        for r = -1, 1, 2 do
          local c = v3(x, y + 0.3 + l * 0.8, z) + u * ((k - (n + 1) / 2) * 1.62) + w * (r * 0.46)
          if l == 0 then
            -- the bottom course stands down into the slope
            obox(K.solid, HAY2, c - UP * 0.5, u * 0.78, UP * 0.88, w * 0.43)
          else
            bale(K.solid, c, u, w, ((k + l + r) % 3 == 0) and HAY2 or HAY)
          end
        end
      end
    end
    count("bale piles")
  end
  local function round_bale(x, z)
    local d = downhill(x, z)
    local axle = normalize(v3(-d.z, 0, d.x) + d * rnd(-0.5, 0.5))
    local c = v3(x, gy(x, z) + 0.95, z)
    limb(K.solid, HAY, c - axle * 0.75, c + axle * 0.75, 1.05, 1.05, 10)
    limb(K.solid, HAY2, c - axle * 0.78, c + axle * 0.78, 0.5, 0.5, 8)
    count("round bales")
  end

  -- ---------------------------------------------------------------- tussocks and woods
  local FLAT = {}
  for _, c in ipairs(TUSS) do FLAT[c] = K.flat(c) end
  local function tussock(x, z, sc, y)
    y = (y or gy(x, z)) - 0.12
    local c = K.pick(TUSS)
    local q = piece(K.deco, c)
    local base = v3(x, y, z)
    local r = rnd(0.4, 0.6) * sc
    K.cone(q, K.ring(base, r, r * 0.8, 4, rnd(0, 1.5)), base, base + v3(rnd(-0.3, 0.3) * sc, rnd(0.6, 1.0) * sc, rnd(-0.3, 0.3) * sc),
      FLAT[c], c)
  end
  -- A crown's bands, dark below to light on top: one colour function a leaf colour.
  local CROWN = {}
  for k, base in ipairs(LEAF) do
    local lo, hi = K.tint(base, 0.72), K.tint(base, 1.22)
    CROWN[k] = function(j, _) return (j == 1) and lo or ((j == 2) and base or hi) end
  end
  local function tree(x, z, s, y)
    K.column(piece(K.deco, BARK, BARK), x, z, y - 0.6, y + 3.4 * s, 0.34 * s, 0.22 * s, 5, BARK)
    local k = math.min(#LEAF, math.floor(rnd(1, #LEAF + 1)))
    local c = v3(x, y + 2.6 * s, z)
    local r = 2.6 * s
    tube(K.deco, CROWN[k], {c, c + v3(rnd(-0.3, 0.3), 1.5, rnd(-0.3, 0.3)) * s, c + v3(rnd(-0.5, 0.5), 3.9, rnd(-0.5, 0.5)) * s,
      c + v3(rnd(-0.4, 0.4), 5.9, rnd(-0.4, 0.4)) * s}, {r * 0.5, r * rnd(0.92, 1.1), r * rnd(0.7, 0.85), r * 0.22}, 6, nil, "crown" .. k)
    count("woodland trees")
  end

  -- ---------------------------------------------------------------- buildings
  -- A stone house on plot s: half sizes hu by hw, walls h high at its road-side front, a gabled roof along the road.
  -- Returns its frame for the dressing: front (the wall's middle at the ground), yf, top.
  local function house(s, hu, hw, h, wallc, roofc, rise)
    local u, w = s.u, s.w
    local mid = v3(s.c.x, 0, s.c.z)
    local front = mid - w * hw
    local yf = gy(front.x, front.z)
    local lo = K.lowest(s.c, u, w, hu, hw) - 0.7
    local top = yf + h
    obox(K.solid, wallc, mid + UP * ((lo + top) / 2), u * hu, UP * ((top - lo) / 2), w * hw)
    local function sec(sgn)
      local e = mid + UP * (top + 0.04) + u * (sgn * (hu + 0.35))
      return {e - w * (hw + 0.45), e + UP * rise, e + w * (hw + 0.45)}
    end
    K.prism(piece(K.solid, roofc), {sec(-1), sec(1)}, K.flat(roofc), roofc, roofc)
    -- a chimney at each end
    for sgn = -1, 1, 2 do
      obox(K.solid, STONE2, mid + UP * (top + rise * 0.6 + 0.9) + u * (sgn * (hu - 0.7)), u * 0.42, UP * (rise * 0.4 + 0.95), w * 0.42)
      obox(K.deco, DARKWOOD, mid + UP * (top + rise + 2.0) + u * (sgn * (hu - 0.7)), u * 0.2, UP * 0.18, w * 0.2)
    end
    local F = {front = front, yf = yf, top = top, u = u, w = w, mid = mid}
    function F.window(du, dy, hw2, hh)
      local c = front + UP * (yf + dy) + u * du - w * 0.03
      obox(K.deco, WHITE, c, u * (hw2 + 0.1), UP * (hh + 0.1), w * 0.05)
      obox(K.deco, GLASS, c - w * 0.03, u * hw2, UP * hh, w * 0.05)
      obox(K.deco, WHITE, c - w * 0.05, u * 0.04, UP * hh, w * 0.05)
    end
    function F.door(du, c)
      obox(K.deco, c, front + UP * (yf + 1.0) + u * du - w * 0.04, u * 0.55, UP * 1.15, w * 0.06)
      obox(K.deco, STONE2, front + UP * (yf + 2.3) + u * du - w * 0.06, u * 0.8, UP * 0.14, w * 0.1)
    end
    return F
  end

  local function table_set(p, u, w, parasol)
    local y = p.y
    local c = v3(p.x, y, p.z)
    obox(K.solid, WOOD, c + UP * 0.78, u * 0.95, UP * 0.05, w * 0.45)
    for sgn = -1, 1, 2 do
      obox(K.solid, WOOD2, c + UP * 0.45 + w * (sgn * 0.75), u * 0.95, UP * 0.04, w * 0.16)
      obox(K.solid, WOOD2, c + UP * 0.2 + u * (sgn * 0.7), u * 0.05, UP * 0.52, w * 0.82)
    end
    if parasol then
      K.column(piece(K.deco, WHITE, WHITE), c.x, c.z, y + 0.84, y + 2.7, 0.04, 0.04, 5, WHITE)
      local cc = v3(c.x, y + 2.35, c.z)
      local c1, c2 = parasol, WHITE
      K.cone(piece(K.deco, "parasol"), K.ring(cc, 1.5, 1.5, 8, 0.3), cc + UP * 0.02, cc + UP * 0.6,
        function(k) return (k % 2 == 0) and c1 or c2 end, c2)
    end
  end
  local function barrel(p)
    K.prism(piece(K.solid, "barrel"), {K.ring(p - UP * 0.2, 0.36, 0.36, 8, 0), K.ring(p + UP * 0.25, 0.46, 0.46, 8, 0),
      K.ring(p + UP * 0.7, 0.46, 0.46, 8, 0), K.ring(p + UP * 1.1, 0.36, 0.36, 8, 0)},
      function(j, _) return (j == 2) and DARKWOOD or WOOD end, WOOD2, WOOD2)
  end

  local function pub(i, side)
    local s = site(i, side, 8.5, 5.0, 3.2)
    if not s then return false end
    local F = house(s, 7.0, 3.6, 5.6, STONE, SLATE, 2.6)
    local u, w, front, yf = F.u, F.w, F.front, F.yf
    F.door(0, RED)
    for _, du in ipairs({-4.8, -2.4, 2.4, 4.8}) do F.window(du, 1.5, 0.6, 0.65) end
    for _, du in ipairs({-4.8, -2.4, 0, 2.4, 4.8}) do F.window(du, 4.1, 0.55, 0.55) end
    -- flower baskets between the windows
    for _, du in ipairs({-3.6, -1.2, 1.2, 3.6}) do
      sph(K.deco, K.pick({RED, PINK, PURPLE, YEL}), front + UP * (yf + 2.75) + u * du - w * 0.4, 0.3, 6)
      sph(K.deco, GREEN, front + UP * (yf + 2.55) + u * du - w * 0.4, 0.26, 5)
    end
    -- the name board over the door: a cheese between two dark boards
    obox(K.deco, DARKWOOD, front + UP * (yf + 2.95) - w * 0.08, u * 2.6, UP * 0.3, w * 0.06)
    for _, du in ipairs({-1.9, -1.1, 1.1, 1.9}) do
      obox(K.deco, GOLD, front + UP * (yf + 2.95) + u * du - w * 0.13, u * 0.25, UP * 0.12, w * 0.03)
    end
    wheel(K.deco, front + UP * (yf + 2.95) - w * 0.2, w, 0.5, 0.2)
    -- the hanging sign on its post by the road: a cheese on a blue board
    local sp = s.at(-6.3, -s.b - 1.6)
    if clear(sp.x, sp.z, 0.5) then
      beam(K.solid, DARKWOOD, sp - UP * 0.5, sp + UP * 5.2, 0.12, 0.12, u)
      beam(K.deco, DARKWOOD, sp + UP * 5.0, sp + UP * 5.0 + u * 2.0, 0.08, 0.08)
      local bc = sp + UP * 3.9 + u * 1.15
      obox(K.deco, BLUE, bc, u * 0.8, UP * 0.95, w * 0.06)
      obox(K.deco, GOLD, bc, u * 0.88, UP * 1.03, w * 0.03)
      wheel(K.deco, bc, w, 0.55, 0.36)
    end
    -- the beer garden: tables under parasols, barrels by the door
    local k = 0
    for _, du in ipairs({-6.5, -3.2, 3.2, 6.5}) do
      k = k + 1
      local p = s.at(du, -s.b - 0.2)
      if clear(p.x, p.z, 1.6) then
        table_set(p, u, w, ({RED, GREEN, BLUE, YEL})[k])
        for sgn = -1, 1, 2 do
          if rnd(0, 1) < 0.8 then person(on(p + w * (sgn * 0.75) + u * rnd(-0.5, 0.5), 0.3), w * -sgn, 1.1, true) end
        end
      end
    end
    for _, du in ipairs({-1.3, 1.3, 1.95}) do barrel(on(front + u * du - w * 0.7)) end
    count("pubs")
    return true
  end

  local function cottage(i, side, thatch)
    local s = site(i, side, 5.2, 4.0, 2.4)
    if not s then return end
    local F = house(s, 4.2, 3.0, 3.4, thatch and WHITE or STONE, thatch and THATCH or SLATE, thatch and 3.0 or 2.3)
    F.door(-1.6, K.pick({BLUE, GREEN, RED}))
    F.window(1.4, 1.5, 0.6, 0.6)
    F.window(-3.2, 1.5, 0.45, 0.6)
    -- a dry stone wall along the front, a gap for the gate
    for _, seg in ipairs({{-5.0, -2.4}, {-0.8, 5.0}}) do
      local a, b = s.at(seg[1], -s.b + 0.3), s.at(seg[2], -s.b + 0.3)
      if clear(a.x, a.z, 0.3) and clear(b.x, b.z, 0.3) then beam(K.solid, STONE2, a + UP * 0.25, b + UP * 0.25, 0.22, 0.6) end
    end
    count("cottages")
  end

  -- The St John Ambulance post: a white tent, green trimmed, its black roundel and white eight-pointed cross over
  -- the door; an ambulance parked beside it; a flag.
  local function first_aid(i, side)
    local s = site(i, side, 7.0, 3.6, 2.6)
    if not s then return false end
    local u, w = s.u, s.w
    local tc = s.at(-3.0, 0)
    local mid = v3(tc.x, 0, tc.z)
    local lo = K.lowest(tc, u, w, 3.0, 3.0) - 0.5
    local yf = gy((mid - w * 3.0).x, (mid - w * 3.0).z)
    local top = yf + 2.7
    obox(K.solid, WHITE, mid + UP * ((lo + top) / 2), u * 3.0, UP * ((top - lo) / 2), w * 3.0)
    obox(K.deco, SJ_GREEN, mid + UP * (top + 0.02), u * 3.2, UP * 0.22, w * 3.2)
    local cc = mid + UP * (top + 0.26)
    K.cone(piece(K.deco, WHITE, WHITE), K.ring(cc, 4.5, 4.5, 4, math.atan(w.z, w.x) + math.pi / 4), cc, cc + UP * 2.3, K.flat(WHITE), WHITE)
    sph(K.deco, SJ_GREEN, cc + UP * 2.4, 0.25, 6)
    local front = mid - w * 3.0
    obox(K.deco, BLACK, front + UP * (yf + 1.05) - w * 0.03, u * 0.9, UP * 1.1, w * 0.05)
    obox(K.deco, SJ_GREEN, front + UP * (yf + 2.35) - w * 0.06, u * 2.9, UP * 0.3, w * 0.05)
    -- the roundel, up on the roof's front
    local rc = front + UP * (top + 1.25) - w * 0.25
    limb(K.deco, BLACK, rc + w * 0.1, rc - w * 0.1, 1.05, 1.05, 14)
    limb(K.deco, WHITE, rc + w * 0.07, rc - w * 0.07, 1.16, 1.16, 14)
    for q = 0, 3 do
      local a = q * math.pi / 2
      local d = u * math.cos(a) + UP * math.sin(a)
      local e = u * -math.sin(a) + UP * math.cos(a)
      local tip, o = rc + d * 0.08, rc + d * 0.82
      local n = w * 0.14
      K.prism(piece(K.deco, WHITE, WHITE), {{tip - n, o - e * 0.34 - n, o - d * 0.16 - n, o + e * 0.34 - n},
        {tip + n, o - e * 0.34 + n, o - d * 0.16 + n, o + e * 0.34 + n}}, K.flat(WHITE), WHITE, WHITE)
    end
    -- the ambulance
    local ac = s.at(3.4, -0.4)
    local base = ac + UP * 0.5
    obox(K.solid, WHITE, base + UP * 1.25, u * 2.3, UP * 1.2, w * 1.1)
    obox(K.solid, AMB_YEL, base + UP * 0.75 + u * 3.0, u * 0.68, UP * 0.7, w * 1.05)
    obox(K.deco, GLASS, base + UP * 1.5 + u * 2.55, u * 0.3, UP * 0.42, w * 1.0)
    for k = 0, 5 do
      obox(K.deco, (k % 2 == 0) and AMB_YEL or AMB_GRN, base + UP * 0.9 + u * (-1.92 + k * 0.767), u * 0.38, UP * 0.3, w * 1.13)
    end
    obox(K.deco, LIGHT, base + UP * 2.56 + u * 1.5, u * 0.18, UP * 0.11, w * 0.7)
    for _, du in ipairs({-1.4, 2.7}) do
      local c = base + UP * 0.02 + u * du
      limb(K.solid, BLACK, c - w * 1.16, c + w * 1.16, 0.52, 0.52, 8)
    end
    -- the flag: white, a green cross
    local fp = s.at(-6.6, -s.b + 0.2)
    if clear(fp.x, fp.z, 0.4) then
      K.column(piece(K.solid, WHITE, WHITE), fp.x, fp.z, fp.y - 0.5, fp.y + 7, 0.08, 0.06, 6, WHITE)
      local fc = fp + UP * 6.1 + u * 1.0
      obox(K.deco, WHITE, fc, u * 0.9, UP * 0.6, w * 0.02)
      obox(K.deco, SJ_GREEN, fc, u * 0.5, UP * 0.16, w * 0.035)
      obox(K.deco, SJ_GREEN, fc, u * 0.16, UP * 0.42, w * 0.04)
    end
    -- two first-aiders in green and a casualty sat down
    for k = -1, 1 do
      local p = s.at(-3.0 + k * 1.3, -s.b + 0.5)
      if clear(p.x, p.z, 0.5) then person(p, w * -1, 1.15, k == 0) end
    end
    count("first aid posts")
    return true
  end

  -- The maypole on the hilltop: a red and white barber's twist, a crown of ribbons out to a ring of dancers, a ball
  -- and St George's flag at the top.
  local function maypole(i, side)
    local s = site(i, side, 6.5, 6.5, 1.5)
    if not s then return false end
    local c = s.c
    local H = 15
    local rings = {}
    for j = 0, 15 do rings[#rings + 1] = K.ring(v3(c.x, c.y - 0.6 + j * (H + 0.6) / 15, c.z), 0.32 - j * 0.008, 0.32 - j * 0.008, 8, 0) end
    K.prism(piece(K.solid, "maypole"), rings, function(j, k) return ((j + k) % 4 < 2) and RED or WHITE end, WHITE, WHITE)
    local top = v3(c.x, c.y + H, c.z)
    limb(K.deco, GOLD, top - UP * 1.2, top - UP * 0.95, 1.2, 1.2, 12)
    sph(K.deco, GOLD, top + UP * 0.5, 0.55, 7)
    local RIB = {RED, YEL, BLUE, GREEN, PINK, WHITE}
    for k = 1, 12 do
      local a = k / 12 * 6.283
      local o = v3(math.cos(a), 0, math.sin(a))
      local g0 = c + o * 6.2
      local foot = on(g0, 1.3)
      if clear(g0.x, g0.z, 0.4) then
        beam(K.deco, RIB[k % 6 + 1], top - UP * 1.05 + o * 1.1, foot, 0.09, 0.02)
        person(on(g0 + o * 0.25), normalize(v3(-o.z, 0, o.x)), 1.2)
      end
    end
    K.column(piece(K.deco, WHITE, WHITE), c.x, c.z, top.y + 0.9, top.y + 4.6, 0.06, 0.05, 5, WHITE)
    local fc = top + UP * 3.7 + s.u * 1.35
    obox(K.deco, WHITE, fc, s.u * 1.25, UP * 0.8, s.w * 0.02)
    obox(K.deco, RED, fc, s.u * 1.27, UP * 0.16, s.w * 0.035)
    obox(K.deco, RED, fc, s.u * 0.16, UP * 0.82, s.w * 0.04)
    count("maypoles")
    return true
  end

  -- The show cheese by the start: a great wheel lying on a stack of bales, cut open, its wedge drawn out beside it.
  local function cut_cheese(i, side)
    local s = site(i, side, 5.0, 4.6, 1.2)
    if not s then return false end
    local c = s.c
    local lo = K.lowest(c, s.u, s.w, 3.6, 3.6) - 0.6
    local top = gy((c - s.w * 3.6).x, (c - s.w * 3.6).z) + 1.1
    for a = -1, 1, 2 do
      for b = -1, 1, 2 do
        obox(K.solid, ((a + b) == 0) and HAY2 or HAY, v3(c.x, (lo + top) / 2, c.z) + s.u * (a * 1.83) + s.w * (b * 1.83),
          s.u * 1.8, UP * ((top - lo) / 2), s.w * 1.8)
      end
    end
    local face = math.atan(-s.w.z, -s.w.x)          -- the cut faces the road
    local r, th = 3.4, 1.9
    sector(K.solid, v3(c.x, top + 0.03, c.z), r, th, face + 0.5, face + 6.283 - 0.5, 18)
    local out = (s.w * -1) * 1.5 + s.u * 0.4
    if clear((c + out + s.w * -3.4).x, (c + out + s.w * -3.4).z, 0.3) then
      sector(K.solid, v3(c.x, top + 0.03, c.z) + out, r, th, face - 0.42, face + 0.42, 4)
    end
    limb(K.deco, LABEL, v3(c.x, top + th + 0.02, c.z) + s.w * 1.2, v3(c.x, top + th + 0.1, c.z) + s.w * 1.2, 1.0, 1.0, 10)
    count("cut cheeses")
    return true
  end

  -- ---------------------------------------------------------------- the hill, laid out down the road
  local S, Fn = K.start, K.fin
  maypole(math.max(4, S - 2), -1)
  cut_cheese(S + 5, 1)
  if not pub(Fn - 6, 1) then pub(Fn - 14, -1) end
  cottage(Fn - 18, -1, true)
  cottage(Fn + 6, -1, false)
  cottage(Fn - 26, 1, false)
  local span = Fn - S
  first_aid(S + math.floor(span * 0.47), -1)
  first_aid(S + math.floor(span * 0.8), 1)
  cut_cheese(S + math.floor(span * 0.62), -1)

  -- Bunting over the road, and along it in stretches.
  for k = 0, 7 do over_bunting(math.min(N - 3, S + 2 + math.floor(span * k / 7.3))) end
  for i0 = S + 8, Fn - 12, 36 do
    roadside_bunting(i0, math.min(Fn - 4, i0 + 21), 1)
    roadside_bunting(math.min(Fn - 6, i0 + 15), math.min(Fn - 4, i0 + 33), -1)
  end

  -- Beside the road, wherever there is room: lo..hi metres past the margin, a thing `rad` wide.
  local function scatter(n, lo, hi, rad, fn)
    local done = 0
    for _ = 1, n * 5 do
      if done >= n then break end
      local i = math.floor(rnd(3, N - 2))
      local sd = (rnd(0, 1) < 0.5) and -1 or 1
      local p = pos[i] + right[i] * (sd * (W[i] + EDGE + rnd(lo, hi)))
      if clear(p.x, p.z, rad + 0.2) and free(p.x, p.z, rad) then
        take(p.x, p.z, rad)
        fn(p.x, p.z, i, sd)
        done = done + 1
      end
    end
    return done
  end
  -- The cheeses: big ones bowling along beside the road, bigger ones up the slopes.
  scatter(16, 2.2, 6, 2.0, function(x, z) rolling(K.solid, x, z, rnd(1.3, 2.0)) end)
  scatter(10, 9, 26, 3.6, function(x, z) rolling(K.solid, x, z, rnd(2.4, 3.6)) end)
  scatter(14, 1.6, 7, 2.4, function(x, z) bale_pile(x, z, (rnd(0, 1) < 0.5) and 3 or 2) end)
  scatter(14, 2.0, 12, 1.6, function(x, z) round_bale(x, z) end)

  -- The crowds: on the slopes behind the game's own, down the whole road.
  for i = 6, N - 5, 4 do
    for side = -1, 1, 2 do
      if rnd(0, 1) < 0.4 then
        crowd(i, side, math.floor(rnd(4, 8)), math.floor(rnd(1, 3.99)), EDGE + rnd(8.2, 12))
      end
    end
  end
  -- Picnics above them, most with their hampers away down the hill.
  scatter(28, 12, 34, 2.8, function(x, z) picnic(x, z, rnd(1.5, 2.3), rnd(0, 1) < 0.7) end)
  -- Runaway baskets right by the road, big enough to read.
  scatter(12, 1.6, 5, 1.5, function(x, z)
    local a, b, d = frame()
    basket(K.solid, v3(x, gy(x, z) + 0.8, z), a, b, d, rnd(1.5, 2.1))
  end)

  -- Tussocks everywhere.
  local tussocks = 0
  for _ = 1, 950 do
    local x, z = rnd(K.X0 + 5, K.X1 - 5), rnd(K.Z1 + 5, K.Z0 - 5)
    local y, d = K.ground_d(x, z)
    if d - K.HW > EDGE + 1.2 then tussock(x, z, rnd(0.9, 1.9), y); tussocks = tussocks + 1 end
  end
  for _ = 1, 260 do
    local i = math.floor(rnd(3, N - 2))
    local p = pos[i] + right[i] * (((rnd(0, 1) < 0.5) and -1 or 1) * (W[i] + EDGE + rnd(1.2, 9)))
    local y, d = K.ground_d(p.x, p.z)
    if d - K.HW > EDGE + 1.0 then tussock(p.x, p.z, rnd(0.8, 1.4), y); tussocks = tussocks + 1 end
  end

  -- Out on the slopes: more wheels, the odd picnic, and the woods at the hill's sides.
  local function far(n, clearance, R, fn)
    for _ = 1, n * 4 do
      local x, z = K.spot(clearance)
      if x and free(x, z, R) then
        take(x, z, R)
        fn(x, z)
        n = n - 1
        if n <= 0 then break end
      end
    end
  end
  far(9, 18, 6, function(x, z) rolling(K.deco, x, z, rnd(3.2, 5.5)) end)
  far(10, 16, 4, function(x, z) picnic(x, z, rnd(1.8, 2.6), true) end)
  for _ = 1, 560 do
    local x, z = rnd(K.X0 + 5, K.X1 - 5), rnd(K.Z1 + 5, K.Z0 - 5)
    local clump = K.hash(math.floor(x / 26), math.floor(z / 26))
    if clump > 0.35 then
      local y, d = K.ground_d(x, z)
      local o = d - K.HW
      if o > 34 and (o > 52 or clump > 0.6) and free(x, z, 1.6) then
        take(x, z, 1.6)
        tree(x, z, rnd(0.9, 1.6), y)
      end
    end
  end

  local list = {}
  for k, n in pairs(made) do list[#list + 1] = n .. " " .. k end
  table.sort(list)
  info("cheese: " .. table.concat(list, ", ") .. string.format(", %d tussocks", tussocks))
end

return T
