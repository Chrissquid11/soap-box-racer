-- Bristol Bombdown's own scenery kit (see THEME KITS in _course.lua), on top of the library's city: the pastel
-- terraces of Totterdown and Clifton rising up both hillsides behind the library's rows; graffiti murals on the gable
-- ends that stand proud of their neighbours; street trees along the pavements; a corner pub and a chippy above the
-- finish; the floating harbour beside it -- a cobbled quay with cranes, coloured boats and the SS Great Britain on the
-- water, a row of painted houses on the far bank; the Clifton Suspension Bridge across the valley beyond the finish;
-- and the balloon fiesta high overhead.
-- Every piece is one colour's (K.sub by colour) but the shaded tree crowns and the balloons, a few colours each.
local T = {keep = true}

-- The harbour's frame, in the world (the course's design is fixed: c02.lua): the finish line's middle, the way down
-- the road there (U) and the way to its right (R). `du` runs down the road from the finish, `dw` out to the right.
local OX, OZ = -115.24, -229.56
local UX, UZ, RX, RZ = -0.832, -0.555, 0.555, -0.832
local DU0, DU1 = -13, 63            -- the harbour's reach down the road
local QUAY0, WATER0, WATER1, QUAY1 = 9, 22, 72, 86   -- across: the near quay, the water, the far quay
local QUAY_Y, BED_Y, WATER_Y = 1.5, -3.4, -0.9
local function harbour(x, z)
  local dx, dz = x - OX, z - OZ
  return dx * UX + dz * UZ, dx * RX + dz * RZ
end

local END0, END1 = 6, 8             -- a quay across each end of the water too
-- 2 on the water, 1 on a quay, nil outside the harbour.
local function zone(x, z, off)
  if off < 8.5 then return nil end
  local du, dw = harbour(x, z)
  if du < DU0 or du > DU1 or dw < QUAY0 or dw > QUAY1 then return nil end
  if dw >= WATER0 and dw <= WATER1 and du >= DU0 + END0 and du <= DU1 - END1 then return 2 end
  return 1
end

function T.shape(x, z, off, y, _, _)
  local k = zone(x, z, off)
  if k == 2 then return BED_Y end
  if k == 1 then return math.min(y, QUAY_Y) end
  return nil
end

function T.paint(x, z, off, _, TK)
  local k = zone(x, z, off)
  if k == 2 then return TK.col(0.05, 0.2, 0.27) end
  if k == 1 then return (TK.hash(x, z) < 0.5) and TK.col(0.4, 0.39, 0.37) or TK.col(0.46, 0.44, 0.41) end
  return nil
end

function T.build(K)
  local col = K.col
  local UP = v3(0, 1, 0)
  local pos, right, W, N, HW = K.pos, K.right, K.W, K.N, K.HW
  local function rnd(a, b) return K.g:range(a, b) end
  local EDGE = K.WALL_T + 1

  local WHITE, BLACK = col(0.93, 0.93, 0.9), col(0.04, 0.04, 0.05)
  local PINK, YELLOW, BLUE, MINT = col(0.95, 0.42, 0.58), col(0.98, 0.8, 0.26), col(0.3, 0.58, 0.93), col(0.42, 0.86, 0.62)
  local LILAC, PEACH, CREAM, TURQ = col(0.66, 0.48, 0.88), col(0.98, 0.58, 0.34), col(0.93, 0.87, 0.68), col(0.2, 0.74, 0.78)
  local RED, GREEN, ORANGE = col(0.86, 0.12, 0.1), col(0.1, 0.6, 0.22), col(0.98, 0.45, 0.05)
  local PASTELS = {PINK, YELLOW, BLUE, MINT, PINK, YELLOW, BLUE, MINT, LILAC, PEACH, CREAM, TURQ}
  local BRIGHTS = {RED, YELLOW, BLUE, GREEN, ORANGE, PINK, TURQ, LILAC, WHITE}
  local SLATE, SLATE2, TILE = col(0.2, 0.22, 0.27), col(0.3, 0.3, 0.33), col(0.5, 0.2, 0.12)
  local ROOFS = {SLATE, SLATE2, TILE}
  local GLASS, BRICK, POT = col(0.1, 0.18, 0.3), col(0.55, 0.26, 0.17), col(0.75, 0.38, 0.2)
  local DOORS = {RED, col(0.05, 0.2, 0.5), col(0.06, 0.3, 0.12), BLACK, YELLOW}
  local TRUNK, LEAVES = col(0.3, 0.2, 0.12), {col(0.2, 0.55, 0.16), col(0.32, 0.62, 0.14), col(0.14, 0.45, 0.2)}
  local STONE, STONE2, COBBLE = col(0.72, 0.6, 0.44), col(0.6, 0.48, 0.36), col(0.5, 0.48, 0.45)
  local STEEL, STEEL2, IRON = col(0.55, 0.62, 0.68), col(0.36, 0.42, 0.48), col(0.12, 0.13, 0.15)
  local WATER, WOOD, GOLD = col(0.1, 0.4, 0.55), col(0.5, 0.34, 0.18), col(0.95, 0.7, 0.15)
  local PUB_G, CHIP_B, PAPER, CHIP = col(0.05, 0.25, 0.14), col(0.08, 0.3, 0.75), col(0.9, 0.88, 0.8), col(0.98, 0.78, 0.2)
  local BULB = col(1, 0.85, 0.45)

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
    obox(root, c, (p0 + p1) * 0.5, e1 * t1, d, e2 * (t2 or t1))
  end
  -- A round tube through pts, radius rr[j] at each, n-sided; c a colour, or colour(j, k) with a key for its piece.
  local function tube(root, c, pts, rr, n, key, hint)
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
  -- A gabled roof: ridge along u over centre c (at the eave's height), half-length hu and half-span hw, `rise` high.
  local function gable(root, c, cen, u, w, hu, hw, rise)
    local function sec(s)
      local e = cen + u * (s * hu)
      return {e - w * hw, e + UP * rise, e + w * hw}
    end
    K.prism(piece(root, c), {sec(-1), sec(1)}, K.flat(c), c, c)
  end
  local SHADE = {}
  local function tree(root, x, z, h, r)
    local gy = K.ground(x, z)
    K.column(piece(root, TRUNK), x, z, gy - 0.4, gy + h, 0.17, 0.11, 6, TRUNK)
    local leaf = K.pick(LEAVES)
    SHADE[leaf] = SHADE[leaf] or K.shaded(leaf)
    K.ball(piece(root, leaf), v3(x, gy + h + r * 0.55, z), r, r * 0.9, r, 7, 4, function() return rnd(0.86, 1.12) end, SHADE[leaf])
  end
  -- A lamp post with a lantern on top.
  local function lamp(root, x, z, h)
    local gy = K.ground(x, z)
    K.column(piece(root, IRON), x, z, gy - 0.3, gy + h, 0.11, 0.06, 6, IRON)
    obox(root, BULB, v3(x, gy + h + 0.28, z), v3(0.2, 0, 0), UP * 0.28, v3(0, 0, 0.2))
    obox(root, IRON, v3(x, gy + h + 0.62, z), v3(0.28, 0, 0), UP * 0.06, v3(0, 0, 0.28))
  end

  -- ---------------------------------------------------------------- where
  local function off(x, z) local _, d = K.ground_d(x, z); return d - HW end   -- metres off the road's edge
  local function in_harbour(x, z, m)
    local du, dw = harbour(x, z)
    return du > DU0 - m and du < DU1 + m and dw > QUAY0 - m and dw < QUAY1 + m
  end
  local taken = {}
  local function free(x, z, R)
    for _, t in ipairs(taken) do
      local dx, dz = t[1] - x, t[2] - z
      if dx * dx + dz * dz < (t[3] + R) * (t[3] + R) then return false end
    end
    return true
  end
  local function take(x, z, R) taken[#taken + 1] = {x, z, R} end

  -- ---------------------------------------------------------------- houses
  -- A painted terraced house: middle c (x, z), u along its front and w away from the road (its front faces -w), half
  -- frontage hu and half depth hw. Windows with white surrounds (`fine`) or bare glass, a door, a chimney with pots.
  local function house(root, c, u, w, hu, hw, floors, body, roofc, fine, seed)
    local gf = math.max(K.ground(c.x - u.x * hu - w.x * hw, c.z - u.z * hu - w.z * hw), K.ground(c.x + u.x * hu - w.x * hw, c.z + u.z * hu - w.z * hw))
    local y0 = K.lowest(c, u, w, hu, hw) - 0.6
    local eave = gf + floors * 2.8 + K.hash(seed, 9) * 0.45
    local cen = v3(c.x, 0, c.z)
    obox(root, body, cen + UP * ((y0 + eave) / 2), u * hu, UP * ((eave - y0) / 2), w * hw)
    local rise = 1.5 + hw * 0.2
    gable(root, roofc, cen + UP * (eave + 0.03), u, w, hu + 0.12, hw + 0.3, rise)
    local ch = cen + u * (hu * 0.62) + UP * (eave + rise * 0.5 + 0.7)
    obox(root, BRICK, ch, u * 0.32, UP * (rise * 0.5 + 0.5), w * 0.42)
    obox(root, POT, ch + UP * (rise * 0.5 + 0.68), u * 0.12, UP * 0.2, w * 0.12)
    local face = cen - w * (hw + 0.02)
    for fl = 0, floors - 1 do
      for q = -1, 1, 2 do
        local door = fl == 0 and q == -1
        local pc = face + u * (q * hu * 0.48) + UP * (gf + fl * 2.8 + (door and 1.05 or 1.55))
        local hx, hy = door and 0.48 or 0.5, door and 1.05 or 0.68
        if fine then obox(root, WHITE, pc, u * (hx + 0.16), UP * (hy + 0.16), w * 0.05) end
        obox(root, door and DOORS[1 + math.floor(K.hash(seed, 5) * #DOORS * 0.999)] or GLASS, pc, u * hx, UP * hy, w * 0.1)
      end
    end
    return gf, eave, rise
  end

  -- The hillside: four rows up each side behind the library's own, every house its own pastel.
  local function flat_along(i) local a = K.along(i); return normalize(v3(a.x, 0, a.z)) end
  local houses = 0
  for row = 1, 4 do
    local D = HW + 14 + row * 10
    for side = -1, 1, 2 do
      local last, last_hu = nil, 0
      for i = 2, N - 2 do
        for f = 0, 0.75, 0.25 do
          local hu = 2.5 + K.hash(i * 4 + f * 4, side * 3 + row * 17) * 1.0
          local hw = 3.2
          local r = normalize(lerp(right[i], right[i + 1], f)) * side
          local base = lerp(pos[i], pos[i + 1], f)
          local c = base + r * (D + W[i] + (W[i + 1] - W[i]) * f - HW)
          local u = flat_along(i)
          local far = last and length(v3(c.x - last.x, 0, c.z - last.z)) or 1e9
          if (not last or (far >= last_hu + hu + 0.3 and dot(c - last, u) > 0)) and K.hash(i + f, row * 5 + side) > 0.05 then
            local _, d = K.ground_d(c.x, c.z)
            if d > D - 2.5 and not in_harbour(c.x, c.z, 5) and free(c.x, c.z, hu * 0.95)
              and c.x > K.X0 + 6 and c.x < K.X1 - 6 and c.z > K.Z1 + 6 and c.z < K.Z0 - 6 then
              take(c.x, c.z, hu * 0.95)
              local seed = i * 31 + f * 8 + row * 7 + side
              local floors = 2 + math.floor(K.hash(seed, 2) * 1.6)
              local body = PASTELS[1 + math.floor(K.hash(seed, 3) * #PASTELS * 0.999)]
              local roofc = ROOFS[1 + math.floor(K.hash(seed, 4) * #ROOFS * 0.999)]
              house(K.deco, c, u, r, hu, hw, floors, body, roofc, true, seed)
              houses = houses + 1
              last, last_hu = c, hu
            end
          end
        end
      end
    end
  end

  -- ---------------------------------------------------------------- murals
  -- A mural on an upright wall: middle cen, a across it and n out of it, half sizes ha, hb. A ground of one colour
  -- and bold shapes over it: discs, diamonds, bars and a zigzag.
  local function mural(root, cen, a, n, ha, hb, seed)
    local function h(k) return K.hash(seed, k) end
    local function hue(k) return BRIGHTS[1 + math.floor(h(k) * #BRIGHTS * 0.999)] end
    local ground_c = ({BLACK, col(0.1, 0.12, 0.4), col(0.9, 0.2, 0.5), TURQ, col(0.25, 0.08, 0.35)})[1 + math.floor(h(1) * 4.999)]
    obox(root, ground_c, cen + n * 0.03, a * ha, UP * hb, n * 0.05)
    local m = math.min(ha, hb)
    for k = 1, 6 do
      local c = cen + a * ((h(k * 3 + 1) - 0.5) * 1.5 * (ha - m * 0.4)) + UP * ((h(k * 3 + 2) - 0.5) * 1.3 * (hb - m * 0.45)) + n * (0.07 + k * 0.012)
      local s = m * (0.25 + h(k * 3 + 3) * 0.3)
      local kind = math.floor(h(k * 7) * 3)
      local ink = hue(k * 11)
      if ink == ground_c then ink = WHITE end
      if kind == 0 then
        tube(root, ink, {c - n * 0.03, c + n * 0.03}, {s, s}, 10, nil, UP)
      elseif kind == 1 then
        local e1, e2 = normalize(a + UP), normalize(a - UP)
        obox(root, ink, c, e1 * (s * 0.75), e2 * (s * 0.75), n * 0.03)
      else
        local tilt = (h(k * 13) - 0.5) * 1.6
        local e1 = a * math.cos(tilt) + UP * math.sin(tilt)
        local e2 = UP * math.cos(tilt) - a * math.sin(tilt)
        obox(root, ink, c, e1 * (s * 1.3), e2 * (s * 0.22), n * 0.03)
      end
    end
    -- A zigzag along the foot, like a tag.
    local zc = hue(77)
    if zc == ground_c then zc = YELLOW end
    local steps = math.max(4, math.floor(ha / 0.7))
    for k = 0, steps - 1 do
      local x0, x1 = -ha * 0.85 + k * (1.7 * ha / steps), -ha * 0.85 + (k + 1) * (1.7 * ha / steps)
      local y0, y1 = (k % 2 == 0) and -0.8 or -0.5, (k % 2 == 0) and -0.5 or -0.8
      beam(root, zc, cen + a * x0 + UP * (hb * y0) + n * 0.17, cen + a * (x1 - 0.02) + UP * (hb * y1) + n * 0.17, 0.09, 0.03, n)
    end
  end

  -- The library's rows again, house for house as it placed them (_course.lua, "The city"): where one stands a
  -- floor or more over the neighbour up the road, or beside a gap, the gable facing up the road carries a mural.
  local murals = 0
  do
    local SET_BACK = HW + K.WALL_T + 4.5
    local centres, rows = {}, {[-1] = {}, [1] = {}}
    local run_ = 0
    for i = 2, N - 1 do
      run_ = run_ + length(pos[i] - pos[i - 1])
      if run_ >= 7.5 and math.abs(i - K.fin) > 14 then
        run_ = 0
        for side = -1, 1, 2 do
          local wid, deep = 3.2 + K.hash(i, side + 31) * 1.0, 4.5
          local r, t = right[i] * side, K.along(i)
          local c = pos[i] + r * (SET_BACK + W[i] - HW + deep)
          local ok = true
          for _, q in ipairs(centres) do if (q.x - c.x)^2 + (q.z - c.z)^2 < 49 then ok = false end end
          local hi = -math.huge
          for _, q in ipairs({{1, 1}, {-1, 1}, {1, -1}, {-1, -1}}) do
            local k = c + t * (q[1] * wid) + r * (q[2] * deep)
            local gy, d = K.ground_d(k.x, k.z)
            if d < SET_BACK - 0.5 then ok = false end
            hi = math.max(hi, gy)
          end
          if ok then
            centres[#centres + 1] = c
            local floors = 2 + math.floor(K.hash(i, side + 41) * 3)
            local list = rows[side]
            list[#list + 1] = {c = c, t = t, r = r, wid = wid, deep = deep, hi = hi, eave = hi + floors * 3, i = i}
          end
        end
      end
    end
    for side = -1, 1, 2 do
      for k, h in ipairs(rows[side]) do
        local p = rows[side][k - 1]
        local lo = h.hi + 0.6
        if p and length(v3(p.c.x - h.c.x, 0, p.c.z - h.c.z)) < p.wid + h.wid + 2.5 then lo = p.eave + 0.35 end
        local top = h.eave - 0.25
        if top - lo >= 2.3 and murals < 16 and K.hash(h.i, side + 3) < 0.85 then
          murals = murals + 1
          local cen = h.c - h.t * (h.wid + 0.06)
          mural(K.deco, v3(cen.x, (lo + top) / 2, cen.z), h.r, h.t * -1, h.deep - 0.5, (top - lo) / 2, h.i * 3 + side)
        end
      end
    end
  end

  -- ---------------------------------------------------------------- street trees
  do
    local run_ = 11
    for i = 3, N - 2 do
      run_ = run_ + length(pos[i] - pos[i - 1])
      if run_ >= 22 then
        run_ = 0
        if math.abs(i - K.fin) > 5 and math.abs(i - K.start) > 5 then
          for side = -1, 1, 2 do
            local p = pos[i] + right[i] * (side * (W[i] + K.WALL_T + 2.7))
            if off(p.x, p.z) > EDGE + 1.2 then tree(K.deco, p.x, p.z, rnd(2.6, 3.3), rnd(1.05, 1.3)) end
          end
        end
      end
    end
  end

  -- ---------------------------------------------------------------- the pub and the chippy
  -- A plot beside the road at sample i: its middle, u down the road, w away from it; nil if a corner crowds the road.
  local function plot(i, side, hu, hw, gap)
    local u, w = flat_along(i), right[i] * side
    local c = pos[i] + w * (W[i] + K.WALL_T + gap + hw)
    for _, q in ipairs({{1, 1}, {-1, 1}, {1, -1}, {-1, -1}, {0, -1}}) do
      local k = c + u * (q[1] * hu) + w * (q[2] * hw)
      if off(k.x, k.z) < K.WALL_T + gap - 0.6 then return nil end
    end
    take(c.x, c.z, math.max(hu, hw))
    return c, u, w
  end
  -- A plain shell and where it stands: the ground at its front (gf) and its sunk foot (y0).
  local function footing(c, u, w, hu, hw)
    local gf = math.max(K.ground(c.x - u.x * hu - w.x * hw, c.z - u.z * hu - w.z * hw), K.ground(c.x + u.x * hu - w.x * hw, c.z + u.z * hu - w.z * hw))
    return gf, K.lowest(c, u, w, hu, hw) - 0.6
  end

  local function pub(i, side)
    local hu, hw = 5.5, 4
    local c, u, w = plot(i, side, hu, hw, 5)
    if not c then return false end
    local S = K.solid
    local gf, y0 = footing(c, u, w, hu, hw)
    local cen = v3(c.x, 0, c.z)
    local mid, eave = gf + 3.3, gf + 6.6
    obox(S, PUB_G, cen + UP * ((y0 + mid) / 2), u * hu, UP * ((mid - y0) / 2), w * hw)
    obox(S, CREAM, cen + UP * ((mid + eave) / 2 + 0.01), u * (hu - 0.05), UP * ((eave - mid) / 2), w * (hw - 0.05))
    gable(S, SLATE, cen + UP * (eave + 0.03), u, w, hu + 0.3, hw + 0.4, 2.6)
    for _, s in ipairs({-0.75, 0.75}) do
      local ch = cen + u * (hu * s) + UP * (eave + 2.4)
      obox(S, BRICK, ch, u * 0.4, UP * 1.6, w * 0.5)
      obox(S, POT, ch + UP * 1.8 + u * 0.15, u * 0.12, UP * 0.22, w * 0.12)
      obox(S, POT, ch + UP * 1.8 - u * 0.15, u * 0.12, UP * 0.22, w * 0.12)
    end
    local face = cen - w * (hw + 0.02)
    -- The fascia: a black board with a gold line and gold letters' blocks, lamps over it.
    obox(S, BLACK, face + UP * (mid + 0.1), u * (hu - 0.3), UP * 0.42, w * 0.12)
    obox(S, GOLD, face + UP * (mid - 0.38) - w * 0.1, u * (hu - 0.3), UP * 0.05, w * 0.05)
    for k = -3, 3 do
      if k ~= 0 then obox(S, GOLD, face + UP * (mid + 0.12) + u * (k * 0.62) - w * 0.11, u * 0.2, UP * 0.22, w * 0.04) end
    end
    -- Big windows with cream frames below, a door in the middle; sashes above.
    for _, s in ipairs({-0.68, -0.32, 0.32, 0.68}) do
      local pc = face + u * (hu * s) + UP * (gf + 1.75)
      obox(S, CREAM, pc, u * 0.85, UP * 1.0, w * 0.06)
      obox(S, GLASS, pc, u * 0.7, UP * 0.85, w * 0.1)
      obox(S, CREAM, pc - w * 0.06, u * 0.05, UP * 0.85, w * 0.06)
      local pu = face + u * (hu * s) + UP * (mid + 1.75)
      obox(S, WHITE, pu, u * 0.62, UP * 0.9, w * 0.07)
      obox(S, GLASS, pu, u * 0.48, UP * 0.76, w * 0.11)
      -- A hanging basket between them.
      K.ball(piece(K.deco, PINK), face + u * (hu * s + (s < 0 and -1.05 or 1.05)) + UP * (gf + 2.9) - w * 0.45, 0.32, 0.28, 0.32, 6, 3,
        function() return 1 end, K.shaded(K.pick({PINK, RED, YELLOW})))
    end
    obox(S, RED, face + UP * (gf + 1.1), u * 0.6, UP * 1.1, w * 0.1)
    obox(S, GOLD, face + UP * (gf + 1.1) + u * 0.35 - w * 0.1, u * 0.05, UP * 0.05, w * 0.04)
    -- The hanging sign on its bracket, square to the road at the corner up the road.
    local sc = face - u * (hu - 0.6) + UP * (mid + 2.2)
    beam(K.deco, IRON, sc, sc - w * 1.5, 0.05, 0.05)
    obox(K.deco, RED, sc - w * 0.9 - UP * 0.75, u * 0.06, UP * 0.6, w * 0.5)
    tube(K.deco, GOLD, {sc - w * 0.9 - UP * 0.75 - u * 0.09, sc - w * 0.9 - UP * 0.75 + u * 0.09}, {0.32, 0.32}, 8)
    -- Picnic benches out the front.
    for _, s in ipairs({-0.5, 0.5}) do
      local b = cen + u * (hu * s) - w * (hw + 2.0)
      local gy = K.ground(b.x, b.z)
      b = v3(b.x, gy, b.z)
      obox(S, WOOD, b + UP * 0.72, u * 0.9, UP * 0.05, w * 0.4)
      for _, e in ipairs({-0.62, 0.62}) do
        obox(S, WOOD, b + UP * 0.42 + w * e, u * 0.9, UP * 0.04, w * 0.14)
        obox(S, WOOD, b + UP * 0.2 + u * e, u * 0.05, UP * 0.5, w * 0.7)
      end
    end
    -- A mural the whole height of the gable up the road.
    mural(K.deco, cen - u * (hu + 0.06) + UP * (gf + 3.4), w, u * -1, hw - 0.5, 2.9, 4242)
    return true
  end

  local function chippy(i, side)
    local hu, hw = 4.2, 3.6
    local c, u, w = plot(i, side, hu, hw, 5)
    if not c then return false end
    local S = K.solid
    local gf, y0 = footing(c, u, w, hu, hw)
    local cen = v3(c.x, 0, c.z)
    local mid, eave = gf + 3.1, gf + 6.0
    obox(S, WHITE, cen + UP * ((y0 + mid) / 2), u * hu, UP * ((mid - y0) / 2), w * hw)
    obox(S, BLUE, cen + UP * ((mid + eave) / 2 + 0.01), u * (hu - 0.05), UP * ((eave - mid) / 2), w * (hw - 0.05))
    gable(S, TILE, cen + UP * (eave + 0.03), u, w, hu + 0.25, hw + 0.35, 2.2)
    local face = cen - w * (hw + 0.02)
    -- The shop front: a wide window, a door, a deep blue fascia with a yellow fish on it.
    obox(S, GLASS, face + u * 1.1 + UP * (gf + 1.5), u * 2.4, UP * 0.9, w * 0.1)
    obox(S, CHIP_B, face + u * 1.1 + UP * (gf + 0.35), u * 2.5, UP * 0.3, w * 0.08)
    obox(S, CHIP_B, face - u * 2.7 + UP * (gf + 1.1), u * 0.6, UP * 1.1, w * 0.1)
    obox(S, CHIP_B, face + UP * (mid + 0.25), u * (hu - 0.2), UP * 0.55, w * 0.14)
    local fc = face + UP * (mid + 0.25) - w * 0.17
    local fish = {}
    for _, tt in ipairs({-0.97, -0.6, 0, 0.6, 0.97}) do
      local p, h = fc + u * (tt * 1.2), 0.4 * math.sqrt(1 - tt * tt)
      fish[#fish + 1] = {p - UP * h - w * 0.03, p + UP * h - w * 0.03, p + UP * h + w * 0.03, p - UP * h + w * 0.03}
    end
    K.prism(piece(S, CHIP), fish, K.flat(CHIP), CHIP, CHIP)
    K.prism(piece(S, CHIP), {{fc + u * 1.05 - w * 0.03, fc + u * 1.7 + UP * 0.4 - w * 0.03, fc + u * 1.7 - UP * 0.4 - w * 0.03},
      {fc + u * 1.05 + w * 0.03, fc + u * 1.7 + UP * 0.4 + w * 0.03, fc + u * 1.7 - UP * 0.4 + w * 0.03}}, K.flat(CHIP), CHIP, CHIP)
    -- A striped awning over the window.
    for k = 0, 7 do
      local a0 = face + u * (-1.0 + k * 0.6) + UP * (gf + 2.62)
      local ink = (k % 2 == 0) and CHIP_B or WHITE
      beam(K.deco, ink, a0, a0 - w * 1.3 - UP * 0.45, 0.295, 0.04, UP)
    end
    -- Windows of the flat above.
    for _, s in ipairs({-0.5, 0.5}) do
      local pu = face + u * (hu * s) + UP * (mid + 1.9)
      obox(S, WHITE, pu, u * 0.66, UP * 0.82, w * 0.06)
      obox(S, GLASS, pu, u * 0.5, UP * 0.66, w * 0.1)
    end
    -- On the roof's front, a giant cone of chips.
    local cc = cen - w * (hw - 0.6) + UP * (eave + 1.0)
    tube(K.deco, PAPER, {cc, cc + UP * 2.4}, {0.12, 1.0}, 8)
    for k = 1, 9 do
      local an = k * 2.4
      local b0 = cc + UP * 2.0 + v3(math.cos(an), 0, math.sin(an)) * (0.2 + (k % 3) * 0.22)
      beam(K.deco, CHIP, b0, b0 + UP * (0.9 + (k % 4) * 0.22) + v3(math.cos(an), 0, math.sin(an)) * 0.3, 0.1, 0.1)
    end
    -- An A-board on the pavement.
    local ab = cen - u * 2.0 - w * (hw + 1.6)
    ab = v3(ab.x, K.ground(ab.x, ab.z), ab.z)
    beam(S, CHIP_B, ab - u * 0.3, ab + UP * 1.0, 0.35, 0.03, u)
    beam(S, WHITE, ab + u * 0.3, ab + UP * 1.0, 0.35, 0.03, u)
    mural(K.deco, cen - u * (hu + 0.06) + UP * (gf + 3.1), w, u * -1, hw - 0.5, 2.6, 977)
    return true
  end

  local fin = K.fin
  for _, di in ipairs({-10, -11, -9, -12, -8}) do if pub(fin + di, 1) then break end end
  for _, di in ipairs({-9, -10, -8, -11, -7}) do if chippy(fin + di, -1) then break end end

  -- ---------------------------------------------------------------- the harbour
  local HU, HR = v3(UX, 0, UZ), v3(RX, 0, RZ)
  local function hp(du, dw, y) return v3(OX + UX * du + RX * dw, y or 0, OZ + UZ * du + RZ * dw) end
  local function hclear(du, dw, m) local p = hp(du, dw); return off(p.x, p.z) > (m or 6) end
  do
    local D = K.deco
    -- The water, one sheet.
    obox(D, WATER, hp((DU0 + END0 + DU1 - END1) / 2, (WATER0 + WATER1) / 2, WATER_Y - 0.3), HU * ((DU1 - END1 - DU0 - END0) / 2 + 3.5), UP * 0.3, HR * ((WATER1 - WATER0) / 2 + 3.5))
    -- The quays: a cobbled deck on each bank out over the water's edge, a pale coping along it, bollards.
    local deck = QUAY_Y + 0.12
    for du = DU0, DU1 - 4, 4 do
      for _, band in ipairs({{QUAY0 + 4.5, WATER0 + 4}, {WATER1 - 4, QUAY1 - 3}}) do
        if hclear(du, band[1], 5) and hclear(du + 4, band[1], 5) then
          local mid = (band[1] + band[2]) / 2
          obox(K.solid, COBBLE, hp(du + 2, mid, deck - 2.5), HU * 1.98, UP * 2.5, HR * ((band[2] - band[1]) / 2))
          local edge = (band[1] < WATER0) and band[2] - 0.35 or band[1] + 0.35
          obox(D, STONE, hp(du + 2, edge, deck + 0.06), HU * 1.97, UP * 0.1, HR * 0.4)
          if (du - DU0) % 8 == 0 then
            local b = hp(du + 2, (band[1] < WATER0) and band[2] - 1.2 or band[1] + 1.2, deck)
            K.column(piece(D, IRON), b.x, b.z, deck, deck + 0.55, 0.2, 0.26, 6, IRON)
          end
        end
      end
    end
    -- Lamps and trees along the near quay.
    for du = DU0 + 6, DU1 - 6, 16 do
      if hclear(du, QUAY0 + 6, 5) then
        local p = hp(du, QUAY0 + 6.2)
        lamp(D, p.x, p.z, 4.4)
      end
    end

    -- The cranes: a portal on four legs, a cab, a long jib out over the water, a counterweight behind.
    local function crane(du, turn)
      local base = hp(du, WATER0 - 0.5, deck)
      if not (hclear(du - 4, WATER0 - 5, 5) and hclear(du + 4, WATER0 - 5, 5)) then return end
      local S = K.solid
      for _, a in ipairs({-2.4, 2.4}) do
        for _, b in ipairs({-2.4, 2.4}) do
          beam(S, STEEL, base + HU * a + HR * b - UP * 0.2, base + HU * (a * 0.8) + HR * (b * 0.8) + UP * 6.5, 0.24, 0.24)
        end
        beam(S, STEEL, base + HU * a - HR * 2.3 + UP * 3.2, base + HU * a + HR * 2.3 + UP * 3.2, 0.14, 0.14)
      end
      obox(S, STEEL2, base + UP * 6.8, HU * 2.6, UP * 0.3, HR * 2.6)
      -- The turning top: its own way round.
      local f = HR * math.cos(turn) + HU * math.sin(turn)
      local s = HU * math.cos(turn) - HR * math.sin(turn)
      obox(S, STEEL, base + UP * 8.6 - f * 0.6, s * 1.7, UP * 1.5, f * 2.3)
      obox(S, GLASS, base + UP * 9.0 + f * 1.72, s * 1.4, UP * 0.6, f * 0.06)
      obox(S, STEEL2, base + UP * 10.2 - f * 0.6, s * 1.85, UP * 0.12, f * 2.45)
      obox(S, IRON, base + UP * 8.2 - f * 3.9, s * 1.3, UP * 1.0, f * 1.0)
      local foot, tip = base + UP * 9.6 + f * 1.6, base + UP * 21 + f * 15
      for _, e in ipairs({-0.55, 0.55}) do beam(K.deco, STEEL, foot + s * (e * 1.6), tip + s * (e * 0.4), 0.16, 0.2) end
      for k = 1, 5 do
        local q = lerp(foot, tip, k / 5.5)
        local wide = 1.6 - 1.2 * k / 5.5
        beam(K.deco, STEEL2, q - s * (wide * 0.55), q + s * (wide * 0.55), 0.09, 0.09)
      end
      local apex = base + UP * 14.5 - f * 1.2
      beam(K.deco, STEEL2, base + UP * 10.2 - f * 2.4, apex, 0.12, 0.12)
      beam(K.deco, STEEL2, base + UP * 10.2 + f * 0.8, apex, 0.12, 0.12)
      beam(K.deco, IRON, apex, tip, 0.05, 0.05)
      beam(K.deco, IRON, tip, tip - UP * 9, 0.04, 0.04)
      obox(K.deco, RED, tip - UP * 9.4, s * 0.3, UP * 0.4, f * 0.3)
    end
    crane(4, 0.1); crane(18, -0.35); crane(33, 0.3); crane(48, -0.1)

    -- Boats. A hull: stem to stern along `f` about c (at the waterline), half-length L, half-beam B, freeboard H.
    local function hull(root, c, f, L, B, H, ink, key)
      local s = normalize(cross(UP, f))
      local rings = {}
      for _, e in ipairs({{-1, 0.72}, {-0.55, 1}, {0.35, 1}, {0.8, 0.6}, {1.0, 0.06}}) do
        local m = c + f * (e[1] * L)
        local b = B * e[2]
        local lift_ = (e[1] > 0.5) and (e[1] - 0.5) * H * 0.5 or 0
        rings[#rings + 1] = {m - s * b + UP * (H + lift_), m - s * (b * 0.75) - UP * 0.35, m - UP * 0.6, m + s * (b * 0.75) - UP * 0.35, m + s * b + UP * (H + lift_)}
      end
      K.prism(piece(root, key or ink), rings, K.flat(ink), ink, ink)
    end
    local function small_boat(du, dw, heading, kind, ink)
      if not hclear(du, dw, 12) then return end
      local c = hp(du, dw, WATER_Y)
      local f = normalize(HU * math.cos(heading) + HR * math.sin(heading))
      local s = normalize(cross(UP, f))
      if kind == 0 then
        -- A narrowboat: long and low, a cabin most of its length, a tiller.
        hull(D, c, f, 8, 1.1, 0.6, ink)
        obox(D, K.pick({RED, GREEN, col(0.1, 0.2, 0.5)}), c - f * 0.6 + UP * 1.15, f * 5.6, UP * 0.55, s * 0.92)
        obox(D, CREAM, c - f * 0.6 + UP * 1.74, f * 5.7, UP * 0.05, s * 1.0)
        for k = -2, 2 do
          obox(D, GLASS, c + f * (k * 2.0 - 0.6) + UP * 1.25, f * 0.45, UP * 0.22, s * 0.95)
        end
        K.column(piece(D, IRON), (c + f * 3).x, (c + f * 3).z, WATER_Y + 1.7, WATER_Y + 2.4, 0.09, 0.09, 6, IRON)
      elseif kind == 1 then
        -- A sailing boat: a white cabin, a tall mast, a furled boom.
        hull(D, c, f, 4.5, 1.4, 0.8, ink)
        obox(D, WHITE, c - f * 0.4 + UP * 1.05, f * 1.6, UP * 0.3, s * 0.85)
        local m = c + f * 0.9
        K.column(piece(D, WHITE), m.x, m.z, WATER_Y + 0.6, WATER_Y + 9.5, 0.08, 0.05, 6, WHITE)
        beam(D, K.pick({RED, BLUE, WHITE}), m + UP * 1.9, m - f * 3.4 + UP * 1.9, 0.14, 0.14)
        obox(D, K.pick(BRIGHTS), m + UP * 9.2 - f * 0.4, f * 0.35, UP * 0.2, s * 0.02)
      else
        -- A ferry: a stubby hull, a wheelhouse, a striped canopy.
        hull(D, c, f, 5.5, 1.9, 0.9, ink)
        obox(D, WHITE, c + f * 2.2 + UP * 1.7, f * 1.1, UP * 0.85, s * 1.2)
        obox(D, GLASS, c + f * 2.2 + UP * 2.0, f * 1.14, UP * 0.3, s * 1.1)
        obox(D, ink, c - f * 1.6 + UP * 2.5, f * 2.6, UP * 0.07, s * 1.55)
        for _, a in ipairs({-3.9, 0.7}) do
          for _, b in ipairs({-1.4, 1.4}) do beam(D, WHITE, c + f * a + s * b + UP * 0.8, c + f * a + s * b + UP * 2.5, 0.05, 0.05) end
        end
      end
    end
    small_boat(4, 29, 0.0, 0, GREEN)
    small_boat(22, 29.5, 0.0, 0, RED)
    small_boat(40, 29, 3.14, 0, col(0.1, 0.2, 0.5))
    small_boat(48, 36, 0.1, 1, YELLOW)
    small_boat(6, 40, 0.5, 2, YELLOW)
    small_boat(30, 43, -0.4, 1, RED)
    small_boat(43, 50, 2.6, 1, TURQ)
    small_boat(0, 52, 1.2, 1, ORANGE)
    small_boat(51, 58, 1.5, 0, BLUE)
    small_boat(20, 51, 0.2, 2, PINK)
    small_boat(34, 36, 0.2, 1, BLUE)

    -- The SS Great Britain against the far quay: a long black hull with a white band, six masts, a black funnel.
    if hclear(26, 62, 14) then
      local c, f = hp(26, 62, WATER_Y), HU * -1
      local s = normalize(cross(UP, f))
      hull(D, c, f, 21, 3.0, 2.6, BLACK)
      hull(D, c + UP * 1.5, f, 21.15, 3.08, 0.55, WHITE)
      hull(D, c + UP * 2.62, f, 20.4, 2.7, 0.12, WOOD)
      for k = -6, 6 do
        for _, e in ipairs({-1, 1}) do obox(D, BLACK, c + f * (k * 2.4 - 1) + s * (e * 3.1) + UP * 1.85, f * 0.3, UP * 0.2, s * 0.1) end
      end
      obox(D, GOLD, c + f * 20.6 + UP * 2.9, f * 1.3, UP * 0.12, s * 0.3)
      for k = 0, 5 do
        local m = c + f * (-15 + k * 6)
        local h = (k == 1 or k == 2) and 19 or 15
        K.column(piece(D, WOOD), m.x, m.z, WATER_Y + 2.6, WATER_Y + 2.6 + h, 0.22, 0.1, 6, WOOD)
        beam(D, WOOD, m - s * 4 + UP * (2.6 + h * 0.55), m + s * 4 + UP * (2.6 + h * 0.55), 0.1, 0.1)
        beam(D, WOOD, m - s * 2.8 + UP * (2.6 + h * 0.82), m + s * 2.8 + UP * (2.6 + h * 0.82), 0.08, 0.08)
        obox(D, BRIGHTS[k % #BRIGHTS + 1], m + UP * (2.6 + h + 0.25) - f * 0.5, f * 0.5, UP * 0.25, s * 0.02)
      end
      local fn = c + f * 0 + UP * 2.6
      K.column(piece(D, BLACK), fn.x, fn.z, WATER_Y + 2.6, WATER_Y + 7.6, 0.9, 0.9, 10, BLACK)
      obox(D, RED, c - f * 20.5 + UP * 4.2, f * 0.9, UP * 0.5, s * 0.02)
      beam(D, WOOD, c - f * 20.8 + UP * 2.6, c - f * 20.8 + UP * 4.8, 0.05, 0.05)
    end

    -- The far bank's row of painted houses, facing the water.
    local du = DU0 + 3
    local n = 0
    while du < DU1 - 3 do
      local hu = 2.6 + K.hash(n, 71) * 0.9
      local c = hp(du + hu, QUAY1 - 6.5)
      if hclear(du + hu, QUAY1 - 6.5, 12) then
        house(K.deco, c, HU, HR, hu, 3.2, 3 + math.floor(K.hash(n, 72) * 1.5), PASTELS[n % 4 + 1 + ((n % 3 == 0) and 8 or 0)], ROOFS[n % 3 + 1], true, 500 + n)
        houses = houses + 1
      end
      du = du + hu * 2 + 0.12
      n = n + 1
    end
    for _, e in ipairs({{-8, QUAY0 + 5}, {26, QUAY0 + 5.5}, {58, QUAY0 + 5}}) do
      if hclear(e[1], e[2], 4) then local p = hp(e[1], e[2]); tree(D, p.x, p.z, 2.8, 1.2) end
    end
  end

  -- ---------------------------------------------------------------- the suspension bridge
  -- Across the valley beyond the finish: two stone towers on the valley's sides, the deck hung between them from white
  -- chains, high over the road on past the end.
  do
    local D = K.deco
    local t, a = flat_along(N), right[N]
    local c0 = pos[N] + t * 88
    -- The road on past the end bends: the bridge's middle over it.
    local best, s0 = 1e9, 0
    for s = -70, 70, 2 do
      local p = c0 + a * s
      local _, d = K.ground_d(p.x, p.z)
      if d < best then best, s0 = d, s end
    end
    c0 = c0 + a * s0
    local road_y = K.ground(c0.x, c0.z) + 0.5
    local SPAN, REACH = 50, 72
    local yd = road_y + 17
    local function bp(s, tt, y) return v3(c0.x + a.x * s + t.x * tt, y, c0.z + a.z * s + t.z * tt) end
    -- The deck, its girders and its railings.
    obox(D, IRON, bp(0, 0, yd - 0.3), a * REACH, UP * 0.3, t * 3.4)
    for _, e in ipairs({-1, 1}) do
      obox(D, STEEL2, bp(0, e * 3.3, yd - 0.75), a * (REACH - 0.5), UP * 0.5, t * 0.15)
      obox(D, WHITE, bp(0, e * 3.3, yd + 1.1), a * (REACH - 0.5), UP * 0.06, t * 0.06)
      for s = -REACH + 2, REACH - 2, 6 do
        if math.abs(math.abs(s) - SPAN) > 3 then obox(D, WHITE, bp(s, e * 3.3, yd + 0.55), a * 0.06, UP * 0.5, t * 0.05) end
      end
    end
    -- The towers: two tapering legs either side of the roadway, joined over it, a cap on top; a rock-faced pier below.
    local TOP = yd + 21
    for _, e in ipairs({-1, 1}) do
      local s = e * SPAN
      local g0 = math.min(K.ground(bp(s, -5, 0).x, bp(s, -5, 0).z), K.ground(bp(s, 5, 0).x, bp(s, 5, 0).z), yd - 1)
      obox(D, STONE2, bp(s, 0, (g0 - 2 + yd - 0.7) / 2), a * 3.4, UP * ((yd - 0.7 - g0 + 2) / 2), t * 6.6)
      for _, q in ipairs({-1, 1}) do
        local b, p = bp(s, q * 4.5, yd - 0.65), bp(s, q * 4.1, yd + 15)
        local function ring(cn, ha, ht) return {cn - a * ha - t * ht, cn + a * ha - t * ht, cn + a * ha + t * ht, cn - a * ha + t * ht} end
        K.prism(piece(D, STONE), {ring(b, 2.6, 1.7), ring(p, 2.0, 1.25)}, K.flat(STONE), STONE, STONE)
      end
      obox(D, STONE, bp(s, 0, yd + 17.4), a * 2.1, UP * 3.0, t * 5.5)
      obox(D, STONE2, bp(s, 0, yd + 13.9), a * 2.3, UP * 0.35, t * 5.9)
      obox(D, STONE2, bp(s, 0, TOP - 0.2), a * 2.7, UP * 0.4, t * 6.2)
      obox(D, STONE, bp(s, 0, TOP + 0.6), a * 1.6, UP * 0.45, t * 4.6)
    end
    -- The chains: a curve between the towers' tops, straight down to the anchorages; hangers to the deck.
    local function chain_y(s)
      if math.abs(s) <= SPAN then return yd + 2.2 + (TOP - 0.9 - yd - 2.2) * (s / SPAN)^2 end
      return TOP - 0.9 - (TOP - 0.9 - yd - 0.6) * (math.abs(s) - SPAN) / (REACH - SPAN - 2)
    end
    for _, e in ipairs({-1, 1}) do
      local SEG = 16
      for k = 0, SEG - 1 do
        local s1, s2 = -SPAN + k * (2 * SPAN / SEG), -SPAN + (k + 1) * (2 * SPAN / SEG)
        beam(D, WHITE, bp(s1 + 0.02, e * 3.6, chain_y(s1)), bp(s2 - 0.02, e * 3.6, chain_y(s2)), 0.2, 0.2, t)
        beam(D, WHITE, bp(s1 + 0.02, e * 3.6, chain_y(s1) - 0.8), bp(s2 - 0.02, e * 3.6, chain_y(s2) - 0.8), 0.14, 0.14, t)
        if k > 0 then obox(D, WHITE, bp(s1, e * 3.6, (chain_y(s1) + yd) / 2 - 0.2), a * 0.07, UP * ((chain_y(s1) - yd) / 2 - 0.3), t * 0.07) end
      end
      for _, q in ipairs({-1, 1}) do
        beam(D, WHITE, bp(q * (SPAN + 0.3), e * 3.6, chain_y(SPAN)), bp(q * (REACH - 2), e * 3.6, yd + 0.6), 0.2, 0.2, t)
        beam(D, WHITE, bp(q * (SPAN + 0.3), e * 3.6, chain_y(SPAN) - 0.8), bp(q * (REACH - 2.6), e * 3.6, yd + 0.4), 0.14, 0.14, t)
      end
    end
  end

  -- ---------------------------------------------------------------- the balloon fiesta
  -- Hot-air balloons high over the valley: an envelope of coloured gores or bands, a skirt, a basket on its ropes.
  local function balloon(n, cen, R, style, c1, c2, c3)
    local D = K.deco
    local key = "balloon" .. n
    local profile = {{0, 0.2}, {0.1, 0.36}, {0.28, 0.7}, {0.45, 0.93}, {0.62, 1.0}, {0.78, 0.9}, {0.9, 0.66}, {0.98, 0.3}}
    local H = R * 2.5
    local pts, rr = {}, {}
    for _, e in ipairs(profile) do pts[#pts + 1] = cen + UP * (e[1] * H); rr[#rr + 1] = e[2] * R end
    local cols3 = {c1, c2, c3}
    local function ink(j, k)
      if style == 0 then return (k % 2 == 0) and c1 or c2
      elseif style == 1 then return cols3[(j - 1) % 3 + 1]
      elseif style == 2 then return cols3[(j + k) % 3 + 1]
      else return (j == 3 or j == 4) and ((k % 2 == 0) and c2 or c3) or c1 end
    end
    tube(D, ink, pts, rr, 12, key, v3(1, 0, 0))
    local bc = cen - UP * (R * 0.75)
    local q = piece(D, key)
    q.ink = WOOD
    local b = R * 0.16
    K.hexa(q, bc + v3(-b, -b, -b), bc + v3(b, -b, -b), bc + v3(b, -b, b), bc + v3(-b, -b, b), bc + v3(-b, b, -b), bc + v3(b, b, -b), bc + v3(b, b, b), bc + v3(-b, b, b))
    for _, e in ipairs({{-1, -1}, {1, -1}, {1, 1}, {-1, 1}}) do
      beam(D, IRON, bc + v3(e[1] * b * 0.9, b, e[2] * b * 0.9), cen + v3(e[1] * R * 0.13, 0.05, e[2] * R * 0.13), 0.04, 0.04)
    end
  end
  do
    local spots = {{6, -34, 46, 5.5}, {14, 46, 58, 6.5}, {30, -70, 52, 6}, {40, 18, 70, 7}, {52, 80, 60, 6.5}, {62, -48, 64, 6},
      {74, 40, 50, 5.5}, {84, -90, 72, 7}, {96, -30, 58, 6}, {104, 110, 66, 7.5}, {114, 55, 80, 6.5}, {120, -60, 56, 6}}
    local schemes = {{RED, YELLOW, BLUE}, {PINK, WHITE, TURQ}, {ORANGE, YELLOW, RED}, {BLUE, WHITE, RED}, {GREEN, YELLOW, WHITE},
      {LILAC, PINK, YELLOW}, {YELLOW, BLACK, RED}, {TURQ, ORANGE, WHITE}}
    for n, e in ipairs(spots) do
      local i = math.min(N, e[1])
      local p = pos[i] + right[i] * e[2]
      local sc = schemes[(n - 1) % #schemes + 1]
      balloon(n, v3(p.x, pos[i].y + e[3], p.z), e[4], n % 4, sc[1], sc[2], sc[3])
    end
  end

  info(string.format("bristol: %d painted houses, %d murals", houses, murals))
end

return T
