-- The garden centre course's scenery kit (see THEME KITS in _course.lua): glass greenhouses and polytunnels, rows of
-- plant tables, compost bays and heaps, garden gnomes (some giant), painted sheds, the shop with its sign, trolleys,
-- pallets of compost bags, terracotta pot pyramids, hanging baskets on posts down both verges, fountains and ponds,
-- and a sprinkler tunnel of pipe arches high over the road.
local T = {trees = 0.5}

local FONT = {
  G = {"01110", "10001", "10000", "10111", "10001", "10001", "01110"},
  A = {"01110", "10001", "10001", "11111", "10001", "10001", "10001"},
  R = {"11110", "10001", "10001", "11110", "10100", "10010", "10001"},
  D = {"11110", "10001", "10001", "10001", "10001", "10001", "11110"},
  E = {"11111", "10000", "10000", "11110", "10000", "10000", "11111"},
  N = {"10001", "11001", "10101", "10011", "10001", "10001", "10001"},
  C = {"01110", "10001", "10000", "10000", "10000", "10001", "01110"},
  T = {"11111", "00100", "00100", "00100", "00100", "00100", "00100"},
}

function T.build(K)
  local hexa, prism, ring, column, cone, ball = K.hexa, K.prism, K.ring, K.column, K.cone, K.ball
  local col, tint, hash, g = K.col, K.tint, K.hash, K.g
  local floor, max, min, cos, sin, pi = math.floor, math.max, math.min, math.cos, math.sin, math.pi
  local pos, right, W, N = K.pos, K.right, K.W, K.N
  local Y = v3(0, 1, 0)
  local solid, deco = K.solid, K.deco

  -- Colours (linear).
  local WHITE, BLACK = K.WHITE_C, K.BLACK
  local GLASS, GLASS_HI = col(0.3, 0.62, 0.72), col(0.5, 0.8, 0.88)
  local BRICK, STONE, CREAM = col(0.4, 0.12, 0.07), col(0.42, 0.4, 0.35), col(0.85, 0.76, 0.52)
  local TERRA, SOIL = col(0.62, 0.2, 0.07), col(0.07, 0.04, 0.025)
  local COMPOST = {col(0.11, 0.06, 0.03), col(0.17, 0.1, 0.05), col(0.3, 0.24, 0.08)}
  local WOOD, WOOD_DK = col(0.36, 0.2, 0.09), col(0.2, 0.11, 0.05)
  local LEAF = {col(0.06, 0.3, 0.04), col(0.12, 0.42, 0.05), col(0.04, 0.22, 0.06)}
  local FLOWER = {col(0.85, 0.03, 0.03), col(0.95, 0.7, 0.02), col(0.95, 0.15, 0.4), col(0.4, 0.08, 0.7),
    col(0.95, 0.3, 0.02), col(0.92, 0.92, 0.85), col(0.08, 0.2, 0.9)}
  local HAT, SKIN, NOSE, BEARD = col(0.85, 0.02, 0.02), col(0.85, 0.5, 0.32), col(0.8, 0.3, 0.22), col(0.92, 0.92, 0.9)
  local JACKET = {col(0.05, 0.2, 0.8), col(0.05, 0.5, 0.12), col(0.9, 0.65, 0.02), col(0.45, 0.08, 0.6), col(0.02, 0.5, 0.55)}
  local BOOT, BUCKLE = col(0.05, 0.03, 0.02), col(0.95, 0.75, 0.05)
  local WATER, SPRAY, PIPE = col(0.05, 0.3, 0.75), col(0.6, 0.85, 1), col(0.03, 0.2, 0.75)
  local BAG = {col(0.9, 0.7, 0.03), col(0.45, 0.06, 0.55), col(0.1, 0.5, 0.1), col(0.9, 0.3, 0.03), col(0.05, 0.3, 0.7)}
  local SIGN_G, DOOR, RED = col(0.02, 0.2, 0.06), col(0.03, 0.14, 0.06), col(0.8, 0.03, 0.03)
  local STEEL, IRON = col(0.5, 0.52, 0.55), col(0.03, 0.06, 0.04)
  local POLY, POLY_END, POLY_RIB = col(0.8, 0.86, 0.8), col(0.6, 0.7, 0.62), col(0.4, 0.5, 0.42)
  local SHED = {col(0.35, 0.65, 0.5), col(0.3, 0.5, 0.8), col(0.85, 0.75, 0.5), col(0.85, 0.4, 0.35), col(0.36, 0.2, 0.09)}
  local ROOF = col(0.1, 0.11, 0.12)

  local function S(b, c) local q = K.sub(b, c); q.ink = c; return q end
  local function one() return 1 end
  local function lumpy() return g:range(0.84, 1.16) end
  local flats, shades = {}, {}
  local function flat(c) local f = flats[c]; if not f then f = function() return c end; flats[c] = f end; return f end
  local function shade(c) local f = shades[c]; if not f then f = K.shaded(c); shades[c] = f end; return f end
  local function pickh(list, a, b) return list[1 + floor(hash(a, b) * #list * 0.9999)] end

  -- A box: its middle and its three half-extents.
  local function box(b, c, p, ax, ay, az)
    local a, d = p - az, p + az
    hexa(S(b, c), a - ax - ay, a + ax - ay, a + ax + ay, a - ax + ay, d - ax - ay, d + ax - ay, d + ax + ay, d - ax + ay)
  end
  -- A bar from p to q, th thick.
  local function beam(b, c, p, q, th, th2)
    local d = (q - p) * 0.5
    local s = cross(d, Y)
    if length(s) < 1e-5 then s = v3(1, 0, 0) end
    s = normalize(s)
    box(b, c, (p + q) * 0.5, d, normalize(cross(s, d)) * (th2 or th), s * th)
  end
  -- An upright tube standing on p.
  local function tube(b, c, p, h, r0, r1, n, turn) column(S(b, c), p.x, p.z, p.y, p.y + h, r0, r1, n, c, turn or 0) end
  local function blob(b, c, p, rx, ry, rz, segs, rings_, lump) ball(S(b, c), p, rx, ry, rz, segs, rings_, lump or one, shade(c)) end
  local function gy(x, z) return K.ground(x, z) end
  local function gp(p) return v3(p.x, K.ground(p.x, p.z), p.z) end

  -- Frames: a spot's middle c (its y the floor), u along it, w its depth (away from the road).
  local function at(F, a, h, b) return F.c + F.u * a + Y * h + F.w * b end
  local function fb(b, c, F, a, bb, ha, hb, y0, y1)
    box(b, c, F.c + F.u * a + F.w * bb + Y * ((y0 + y1) * 0.5), F.u * ha, Y * ((y1 - y0) * 0.5), F.w * hb)
  end

  -- How far off the road's edge; ground spoken for.
  local EDGE = K.WALL_T + 1
  local function off(x, z) local _, d = K.ground_d(x, z); return d - K.HW end
  local function clear(p, r) return off(p.x, p.z) >= EDGE + 0.5 + (r or 0) end
  local taken = {}
  local function free(x, z, r)
    for _, o in ipairs(taken) do
      local dx, dz, rr = x - o[1], z - o[2], r + o[3]
      if dx * dx + dz * dz < rr * rr then return false end
    end
    return true
  end
  local CORN = {{1, 1}, {-1, 1}, {-1, -1}, {1, -1}, {0, 0}, {1, 0}, {-1, 0}, {0, 1}, {0, -1}}
  local function place(c, u, w, hu, hw, lift)
    local lo, hi = 1e9, -1e9
    for _, s in ipairs(CORN) do
      local q = c + u * (s[1] * hu) + w * (s[2] * hw)
      if q.x < K.X0 + 3 or q.x > K.X1 - 3 or q.z < K.Z1 + 3 or q.z > K.Z0 - 3 then return nil end
      local y, d = K.ground_d(q.x, q.z)
      if d - K.HW < EDGE + 0.7 then return nil end
      lo, hi = min(lo, y), max(hi, y)
    end
    if hi - lo > 4.5 then return nil end   -- not across a cliff
    local r, L = min(hu, hw), max(hu, hw)
    local n = max(1, floor(L / r + 0.5))
    local long = (hu >= hw) and u or w
    local cs = {}
    for k = 1, n do
      local q = c + long * (((k - 0.5) / n * 2 - 1) * L)
      if not free(q.x, q.z, r) then return nil end
      cs[k] = q
    end
    for _, q in ipairs(cs) do taken[#taken + 1] = {q.x, q.z, r} end
    local fy = lo + (hi - lo) * (lift or 0.6)
    return {c = v3(c.x, fy, c.z), u = u, w = w, lo = lo, hi = hi, hu = hu, hw = hw, base = lo - 0.5 - fy}
  end
  local function plot(i, side, d0, hu, hw, lift)
    local r = right[i] * side
    return place(pos[i] + r * (W[i] + d0 + hw), K.along(i), r, hu, hw, lift)
  end

  -- A terracotta pot standing on p: R its mouth, h its height.
  local function pot(b, p, R, h, n, rim)
    local rings = {ring(p, R * 0.66, R * 0.66, n, 0), ring(p + Y * (h * (rim and 0.74 or 1)), R, R, n, 0)}
    if rim then
      rings[3] = ring(p + Y * (h * 0.77), R * 1.15, R * 1.15, n, 0)
      rings[4] = ring(p + Y * h, R * 1.15, R * 1.15, n, 0)
    end
    prism(S(b, TERRA), rings, flat(TERRA), TERRA, SOIL)
  end
  -- A big planter: a rimmed pot with a clipped ball, a little tree or a mound of flowers.
  local function planter(p, R, kind, c)
    pot(solid, p - Y * 0.3, R, R * 1.3 + 0.3, 8, true)
    local top = p + Y * (R * 1.3)
    if kind == 1 then
      blob(deco, c, top + Y * (R * 0.9), R * 1.15, R * 1.05, R * 1.15, 7, 4, lumpy)
    elseif kind == 2 then
      tube(deco, WOOD_DK, top - Y * 0.1, R * 1.9, R * 0.14, R * 0.1, 5)
      blob(deco, c, top + Y * (R * 2.5), R * 1.1, R * 1.0, R * 1.1, 7, 4, lumpy)
    else
      blob(deco, LEAF[2], top + Y * (R * 0.25), R * 1.1, R * 0.55, R * 1.1, 6, 3)
      blob(deco, c, top + Y * (R * 0.6), R * 0.95, R * 0.6, R * 0.95, 6, 3, lumpy)
    end
  end

  -- A plant table: slatted top on four legs (each to its own ground), a row of potted plants on it.
  local LEGS = {{-1, -1}, {1, -1}, {1, 1}, {-1, 1}}
  local function plant_table(p, u, w, hl, hwid, key)
    local top, legs = -1e9, {}
    for k, s in ipairs(LEGS) do
      local q = p + u * (s[1] * (hl - 0.14)) + w * (s[2] * (hwid - 0.12))
      legs[k] = {q, gy(q.x, q.z)}
      top = max(top, legs[k][2])
    end
    top = top + 0.8
    for _, l in ipairs(legs) do
      local y0 = l[2] - 0.35
      box(solid, WOOD_DK, v3(l[1].x, (y0 + top) * 0.5, l[1].z), u * 0.07, Y * ((top - y0) * 0.5), w * 0.07)
    end
    box(solid, WOOD, v3(p.x, top + 0.07, p.z), u * hl, Y * 0.07, w * hwid)
    local n = 5
    local theme = pickh(FLOWER, key, 3)
    local kind = floor(hash(key, 7) * 4)
    for k = 1, n do
      local q = v3(p.x, top + 0.142, p.z) + u * (((k - 0.5) / n * 2 - 1) * (hl - 0.1))
      pot(deco, q, 0.28, 0.36, 5, false)
      local c = theme
      if kind == 1 then c = pickh(FLOWER, key, k) elseif kind == 2 and k % 2 == 0 then c = LEAF[2] end
      if kind == 3 then
        -- a little conifer
        local base = q + Y * 0.34
        cone(S(deco, LEAF[1 + k % 3]), ring(base, 0.3, 0.3, 5, k), base, base + Y * 1.0, flat(LEAF[1 + k % 3]), LEAF[1 + k % 3])
      else
        ball(S(deco, c), q + Y * 0.58, 0.4, 0.3, 0.4, 5, 3, one, shade(c))
      end
    end
  end

  -- A glass greenhouse: brick footing, glass walls and a glass gable roof, white glazing bars, a door at each end.
  local function greenhouse(F, hu, hw)
    local base, eave, rise = 0.5, 2.7, hw * 0.62
    fb(solid, BRICK, F, 0, 0, hu, hw, F.base, base)
    fb(solid, GLASS, F, 0, 0, hu - 0.06, hw - 0.06, base + 0.01, eave)
    local function sec(a)
      return {at(F, a, eave + 0.02, -(hw + 0.1)), at(F, a, eave + rise, 0), at(F, a, eave + 0.02, hw + 0.1)}
    end
    prism(S(solid, GLASS_HI), {sec(-hu - 0.1), sec(hu + 0.1)}, flat(GLASS_HI), GLASS_HI, GLASS_HI)
    local n = max(2, floor(2 * hu / 1.6 + 0.5))
    for k = 0, n do
      local a = -hu + 2 * hu * k / n
      for sgn = -1, 1, 2 do
        fb(solid, WHITE, F, a, sgn * hw, 0.055, 0.055, base + 0.02, eave - 0.07)
        beam(solid, WHITE, at(F, a, eave + 0.1, sgn * (hw + 0.08)), at(F, a, eave + rise + 0.07, 0), 0.05)
      end
    end
    for sgn = -1, 1, 2 do
      fb(solid, WHITE, F, 0, sgn * hw, hu + 0.07, 0.075, eave - 0.06, eave + 0.09)
      fb(solid, DOOR, F, sgn * hu, 0, 0.07, 0.6, base - 0.45, 2.25)
      for s2 = -1, 1, 2 do
        fb(solid, WHITE, F, sgn * hu, s2 * 0.78, 0.06, 0.05, base + 0.02, eave + rise * (1 - 0.78 / hw) - 0.05)
      end
    end
    fb(solid, WHITE, F, 0, 0, hu + 0.16, 0.08, eave + rise - 0.03, eave + rise + 0.13)
  end

  -- A polytunnel: a long white half-round skin over hoops, a door in each end.
  local function polytunnel(F, hu, hw)
    local h = hw * 0.9
    local function sec(a, sc)
      local pts = {}
      for k = 0, 6 do
        local an = k / 6 * pi
        pts[#pts + 1] = at(F, a, 0.3 + sin(an) * h * sc, cos(an) * hw * sc)
      end
      pts[#pts + 1] = at(F, a, F.base, -hw * sc)
      pts[#pts + 1] = at(F, a, F.base, hw * sc)
      return pts
    end
    prism(S(solid, POLY), {sec(-hu, 1), sec(hu, 1)}, flat(POLY), POLY_END, POLY_END)
    local n = max(2, floor(2 * hu / 2.6 + 0.5))
    for k = 0, n do
      local a = (-hu + 0.15) + (2 * hu - 0.3) * k / n
      prism(S(solid, POLY_RIB), {sec(a - 0.07, 1.035), sec(a + 0.07, 1.035)}, flat(POLY_RIB), POLY_RIB, POLY_RIB)
    end
    for sgn = -1, 1, 2 do fb(solid, DOOR, F, sgn * hu, 0, 0.06, 0.7, F.base, 2.1) end
  end

  -- A painted shed: plank walls, a felt gable roof, a door and a window to the road.
  local function shed(F, a0, b0, hu, hw, c)
    local y1, rise, over = 2.1, hw * 0.55, 0.25
    fb(solid, c, F, a0, b0, hu, hw, F.base, y1)
    local function sec(a)
      return {at(F, a, y1, b0 - hw - over), at(F, a, y1 + rise, b0), at(F, a, y1, b0 + hw + over),
        at(F, a, y1 - 0.14, b0 + hw + over), at(F, a, y1 - 0.14, b0 - hw - over)}
    end
    prism(S(solid, ROOF), {sec(a0 - hu - over), sec(a0 + hu + over)}, flat(ROOF), ROOF, ROOF)
    fb(solid, WHITE, F, a0 - hu * 0.35, b0 - hw, 0.45, 0.05, -0.3, 1.8)
    fb(solid, GLASS, F, a0 + hu * 0.45, b0 - hw, 0.4, 0.05, 1.0, 1.6)
    for s1 = -1, 1, 2 do for s2 = -1, 1, 2 do
      fb(solid, WHITE, F, a0 + s1 * hu, b0 + s2 * hw, 0.07, 0.07, F.base + 0.01, y1 - 0.15)
    end end
  end

  -- A garden gnome standing on p, h tall, facing f: red pointed hat, white beard, a bright jacket, boots.
  local function gnome(b, p, h, f, jacket)
    local sd = normalize(cross(f, Y))
    for k = -1, 1, 2 do
      box(b, BOOT, p + sd * (k * 0.1 * h) + f * (0.05 * h) + Y * (0.035 * h), sd * (0.075 * h), Y * (0.05 * h), f * (0.13 * h))
    end
    prism(S(b, jacket), {ring(p + Y * (0.06 * h), 0.2 * h, 0.2 * h, 8, 0), ring(p + Y * (0.3 * h), 0.23 * h, 0.23 * h, 8, 0),
      ring(p + Y * (0.53 * h), 0.13 * h, 0.13 * h, 8, 0)}, flat(jacket), jacket, jacket)
    column(S(b, BOOT), p.x, p.z, p.y + 0.25 * h, p.y + 0.31 * h, 0.236 * h, 0.24 * h, 8, BOOT, 0)
    box(b, BUCKLE, p + f * (0.235 * h) + Y * (0.28 * h), sd * (0.04 * h), Y * (0.04 * h), f * (0.02 * h))
    ball(S(b, SKIN), p + Y * (0.61 * h), 0.15 * h, 0.15 * h, 0.15 * h, 7, 4, one, flat(SKIN))
    ball(S(b, BEARD), p + Y * (0.47 * h) + f * (0.12 * h), 0.15 * h, 0.18 * h, 0.11 * h, 6, 3, one, flat(BEARD))
    ball(S(b, NOSE), p + Y * (0.62 * h) + f * (0.15 * h), 0.05 * h, 0.05 * h, 0.05 * h, 4, 2, one, flat(NOSE))
    local hc = p + Y * (0.67 * h)
    cone(S(b, HAT), ring(hc, 0.19 * h, 0.19 * h, 8, 0), hc, p + Y * (1.02 * h) - f * (0.07 * h), flat(HAT), HAT)
    for k = -1, 1, 2 do
      beam(b, jacket, p + sd * (k * 0.17 * h) + Y * (0.49 * h), p + sd * (k * 0.3 * h) + Y * (0.27 * h) + f * (0.06 * h), 0.05 * h)
      if h > 2.5 then
        box(b, BLACK, p + sd * (k * 0.06 * h) + f * (0.135 * h) + Y * (0.655 * h), sd * (0.02 * h), Y * (0.025 * h), f * (0.02 * h))
        ball(S(b, SKIN), p + sd * (k * 0.31 * h) + Y * (0.25 * h) + f * (0.07 * h), 0.055 * h, 0.055 * h, 0.055 * h, 4, 2, one, flat(SKIN))
      end
    end
  end
  -- A toadstool: white stalk, red cap.
  local function toadstool(p, h)
    tube(deco, BEARD, p - Y * 0.3, 0.62 * h + 0.3, 0.13 * h, 0.09 * h, 6)
    ball(S(deco, HAT), p + Y * (0.62 * h), 0.45 * h, 0.3 * h, 0.45 * h, 6, 3, one, shade(HAT))
  end

  -- A compost heap: a lumpy mound sunk in the ground.
  local function heap(c, rx, ry, rz, base)
    ball(S(solid, base), c, rx, ry, rz, 9, 6, lumpy, shade(base))
  end

  -- A garden trolley: a flat bed on four wheels, a handle, and its load.
  local function trolley(p, u, w, c, load, key)
    local o = gp(p)
    for _, s in ipairs(LEGS) do
      box(deco, BLACK, o + u * (s[1] * 0.5) + w * (s[2] * 0.36) + Y * 0.03, u * 0.13, Y * 0.3, w * 0.05)
    end
    box(deco, c, o + Y * 0.4, u * 0.75, Y * 0.06, w * 0.42)
    for s = -1, 1, 2 do
      beam(deco, STEEL, o + u * 0.72 + w * (s * 0.38) + Y * 0.42, o + u * 0.98 + w * (s * 0.38) + Y * 1.1, 0.03)
    end
    box(deco, STEEL, o + u * 0.98 + Y * 1.1, u * 0.03, Y * 0.03, w * 0.42)
    if load == 1 then
      for k = 0, 2 do
        box(deco, pickh(BAG, key, k), o + Y * (0.58 + k * 0.23) + u * ((k % 2) * 0.06 - 0.1), u * 0.55, Y * 0.11, w * 0.36)
      end
    else
      for k = -1, 1, 2 do
        local q = o + u * (k * 0.34 - 0.08) + Y * 0.462
        pot(deco, q, 0.27, 0.34, 5, false)
        local fc = pickh(FLOWER, key, k)
        ball(S(deco, fc), q + Y * 0.55, 0.38, 0.3, 0.38, 5, 3, one, shade(fc))
      end
    end
  end

  -- A pallet of compost bags: n layers of two.
  local function bag_stack(p, u, w, n, key)
    local o = gp(p)
    box(solid, WOOD, o - Y * 0.12, u * 0.85, Y * 0.42, w * 0.68)
    local c = pickh(BAG, key, 1)
    local c2 = tint(c, 0.75)
    for l = 0, n - 1 do
      for k = -1, 1, 2 do
        local j = (hash(key + l, k) - 0.5) * 0.08
        box(solid, ((l + (k + 1) / 2) % 2 == 0) and c or c2, o + Y * (0.43 + l * 0.25) + u * (k * 0.41 + j) + w * j,
          u * 0.385, Y * 0.12, w * 0.62)
      end
    end
  end

  -- A pyramid of terracotta pots on a pallet: three by three, two by two, one.
  local function pyramid(p, u, w, R)
    local o = gp(p)
    local hi = o.y
    for _, s in ipairs(LEGS) do
      local q = p + u * (s[1] * R * 3) + w * (s[2] * R * 3)
      hi = max(hi, gy(q.x, q.z))
    end
    local lo = hi - 2.2
    box(solid, WOOD, v3(o.x, (lo + hi + 0.15) * 0.5, o.z), u * (R * 3.6), Y * ((hi + 0.15 - lo) * 0.5), w * (R * 3.6))
    local h = R * 1.7
    for l = 0, 2 do
      local m = 3 - l
      for a = 1, m do for b = 1, m do
        local q = v3(o.x, hi + 0.152 + l * h * 0.99, o.z) + u * ((a - (m + 1) / 2) * R * 2.35) + w * ((b - (m + 1) / 2) * R * 2.35)
        pot(solid, q, R, h, 6, true)
      end end
    end
  end

  -- A post with a cross arm along the road and a hanging basket of flowers at each end.
  local function basket_post(p, t, key)
    local o = gp(p)
    tube(solid, IRON, o - Y * 0.3, 4.2, 0.09, 0.06, 5)
    box(deco, IRON, o + Y * 3.75, t * 1.05, Y * 0.05, cross(t, Y) * 0.05)
    ball(S(deco, IRON), o + Y * 4.0, 0.14, 0.14, 0.14, 4, 2, one, flat(IRON))
    for s = -1, 1, 2 do
      local q = o + t * (s * 0.9)
      box(deco, IRON, q + Y * 3.45, t * 0.02, Y * 0.26, cross(t, Y) * 0.02)
      ball(S(deco, WOOD_DK), q + Y * 2.95, 0.42, 0.34, 0.42, 6, 3, one, flat(WOOD_DK))
      local fc = pickh(FLOWER, key, s)
      ball(S(deco, fc), q + Y * 3.14, 0.55, 0.3, 0.55, 6, 3, lumpy, shade(fc))
    end
  end

  -- A stone fountain: a round basin of water, a bowl on a pillar, a plume of spray.
  local function fountain(F)
    local c = F.c
    tube(solid, STONE, c + Y * F.base, 0.7 - F.base, 2.5, 2.5, 10)
    tube(solid, WATER, c + Y * 0.2, 0.56, 2.15, 2.15, 10, 0.2)
    tube(solid, STONE, c + Y * 0.3, 1.7, 0.42, 0.28, 6)
    tube(solid, STONE, c + Y * 2.0, 0.45, 0.35, 1.25, 8)
    tube(solid, WATER, c + Y * 2.2, 0.3, 0.9, 1.08, 8, 0.3)
    tube(solid, STONE, c + Y * 2.4, 0.9, 0.2, 0.14, 5)
    local tip = c + Y * 4.6
    cone(S(deco, SPRAY), ring(c + Y * 2.55, 0.75, 0.75, 6, 0), c + Y * 2.55, tip, flat(SPRAY), SPRAY)
    for k = 0, 3 do
      local an = k / 4 * pi * 2 + 0.4
      local d = v3(cos(an), 0, sin(an))
      beam(deco, SPRAY, c + d * 1.0 + Y * 2.45, c + d * 1.75 + Y * 0.8, 0.07)
    end
  end
  -- A pond: a stone rim, water, lily pads -- and a gnome fishing.
  local function pond(F, key)
    local c = v3(F.c.x, F.hi, F.c.z)
    tube(solid, STONE, c - Y * (F.hi - F.lo + 0.5), F.hi - F.lo + 0.85, 3.0, 3.0, 12)
    tube(solid, WATER, c, 0.4, 2.55, 2.55, 12, 0.2)
    for k = 0, 3 do
      local an = k * 1.7 + hash(key, k) * 2
      local q = c + v3(cos(an), 0, sin(an)) * (0.6 + 0.4 * k) + Y * 0.39
      tube(deco, LEAF[2], q, 0.04, 0.38, 0.38, 6, an)
      if k % 2 == 0 then ball(S(deco, FLOWER[3]), q + Y * 0.12, 0.16, 0.12, 0.16, 4, 2, one, flat(FLOWER[3])) end
    end
    local f = normalize(F.w * 0.8 + F.u * 0.6)
    local gpnt = c - f * 2.78 + Y * 0.35
    gnome(deco, gpnt, 1.7, f, pickh(JACKET, key, 5))
    local hand = gpnt + Y * 0.5 + f * 0.25
    local end_ = c - f * 0.6 + Y * 2.3
    beam(deco, WOOD_DK, hand, end_, 0.03)
    box(deco, WHITE, end_ - Y * 0.95, F.u * 0.012, Y * 0.95, F.w * 0.012)
    ball(S(deco, HAT), end_ - Y * 1.88, 0.09, 0.09, 0.09, 4, 2, one, flat(HAT))
  end

  -- Block capitals standing off a board: o the top left corner, rt the reading direction, nrm out of the board.
  local function text(b, c, o, rt, nrm, px, str)
    for ci = 1, #str do
      local rows = FONT[string.sub(str, ci, ci)]
      if rows then
        for r = 1, 7 do
          local row, x = rows[r], 1
          while x <= 5 do
            if string.sub(row, x, x) == "1" then
              local e = x
              while e < 5 and string.sub(row, e + 1, e + 1) == "1" do e = e + 1 end
              local mid = ((ci - 1) * 6 + (x - 1 + e) / 2) * px
              box(b, c, o + rt * mid - Y * ((r - 0.5) * px) + nrm * 0.03, rt * ((e - x + 1) * px / 2 - 0.012),
                Y * (px / 2 - 0.012), nrm * 0.07)
              x = e + 1
            else
              x = x + 1
            end
          end
        end
      end
    end
  end

  -- The shop: a long cream building with a glazed front, a striped awning, a green roof and GARDEN CENTRE along it.
  local function shop(F)
    local hu, hw, H = F.hu, F.hw, 4.4
    fb(solid, CREAM, F, 0, 0, hu, hw, F.base, H)
    fb(solid, SIGN_G, F, 0, 0, hu + 0.4, hw + 0.4, H + 0.01, H + 0.5)
    fb(solid, GLASS, F, 0, -hw, hu - 1, 0.06, 0.8, 3.0)
    for k = 0, 10 do
      fb(solid, WHITE, F, -(hu - 1) + k * (hu - 1) / 5, -hw, 0.07, 0.1, 0.8, 3.0)
    end
    fb(solid, WHITE, F, 0, -hw, hu - 0.9, 0.09, 2.96, 3.12)
    fb(solid, DOOR, F, (hu - 1) / 10, -hw, 1.0, 0.13, -0.5, 2.7)
    local slope = F.w * -0.95 + Y * -0.28
    local nrm = normalize(cross(F.u, slope))
    local n = 24
    for k = 0, n - 1 do
      local a = -(hu - 0.4) + (k + 0.5) * (2 * hu - 0.8) / n
      box(solid, (k % 2 == 0) and RED or WHITE, at(F, a, 3.5, -hw - 0.9), F.u * ((hu - 0.4) / n - 0.004), nrm * 0.04, slope)
    end
    -- the sign along the roof
    local px = 0.26
    local rt = normalize(cross(F.w, Y))
    local wide = (13 * 6 - 1) * px
    fb(solid, SIGN_G, F, 0, -hw - 0.3, wide / 2 + 0.6, 0.15, H + 0.45, H + 3.1)
    fb(solid, BUCKLE, F, 0, -hw - 0.3, wide / 2 + 0.75, 0.12, H + 3.1, H + 3.3)
    text(solid, WHITE, at(F, 0, H + 2.7, -hw - 0.45) - rt * (wide / 2), rt, F.w * -1, px, "GARDEN CENTRE")
    -- a gnome on the roof, planters at its corners
    gnome(solid, at(F, 0, H + 0.5, 1.2), 4.6, normalize(F.w * -0.8 - F.u * 0.6), JACKET[1])
    for s = -1, 1, 2 do
      planter(at(F, s * (hu - 1.2), H + 0.5, 1.5), 0.8, 1, LEAF[1])
      planter(at(F, s * (hu * 0.5), H + 0.5, 1.5), 0.7, 3, FLOWER[s + 3])
    end
    -- the forecourt: a line of trolleys, planters by the door, pots
    for k = 0, 6 do
      local p = at(F, -hu + 1.2 + k * 1.15, 0, -hw - 2.7)
      if clear(p, 1.2) then trolley(p, F.w, F.u, pickh({RED, PIPE, STEEL}, k, 9), 1 + k % 2, k + 40) end
    end
    for k = 0, 4 do
      local p = at(F, 3.5 + k * 1.7, 0, -hw - 2.6)
      if clear(p, 1) then planter(gp(p), 0.55, 1 + k % 3, (k % 3 == 2) and FLOWER[1 + k] or LEAF[1 + k % 3]) end
    end
  end

  -- The sign by the start: GARDEN / CENTRE on a board square to the road, read coming down it.
  local function totem(i, side)
    local px = 0.3
    local wide = 35 * px
    local r, t = right[i] * side, K.along(i)
    local F
    for d = 1.3, 9, 1.5 do
      F = place(pos[i] + r * (W[i] + EDGE + d + wide / 2 + 0.6), t, r, 0.6, wide / 2 + 0.6, 1)
      if F then break end
    end
    if not F then return end
    local y0, y1 = 3.0, 8.6
    for s = -1, 1, 2 do fb(solid, WOOD_DK, F, 0, s * (wide / 2 - 0.4), 0.16, 0.16, F.base, y1 + 0.5) end
    fb(solid, SIGN_G, F, -0.02, 0, 0.14, wide / 2 + 0.6, y0, y1)
    fb(solid, BUCKLE, F, -0.02, 0, 0.12, wide / 2 + 0.75, y1, y1 + 0.2)
    local rt = right[i]
    local o = F.c - t * 0.16 - rt * (wide / 2) + Y * (y1 - 0.5)
    text(solid, WHITE, o, rt, t * -1, px, "GARDEN")
    text(solid, WHITE, o - Y * (8.5 * px), rt, t * -1, px, "CENTRE")
    -- flowers along its foot
    for k = 0, 6 do
      local p = at(F, -1.2, 0, (k - 3) * 1.6)
      if clear(p, 0.8) then
        local fc = FLOWER[1 + k % #FLOWER]
        ball(S(deco, fc), gp(p) + Y * 0.2, 0.75, 0.55, 0.75, 6, 3, lumpy, shade(fc))
      end
    end
  end

  -- The sprinkler tunnel: blue pipe arches high over the road, a rail joining them each side, spray fanning down.
  local function tunnel(i0, i1, step)
    local last
    for i = i0, i1, step do
      local r = right[i]
      local d = W[i] + EDGE + 0.9
      local pl, pr = gp(pos[i] - r * d), gp(pos[i] + r * d)
      if clear(pl, 0.2) and clear(pr, 0.2) then
        local top = pos[i].y + 7.6
        local tl, tr = v3(pl.x, top, pl.z), v3(pr.x, top, pr.z)
        tube(solid, PIPE, pl - Y * 0.4, top - pl.y + 0.55, 0.16, 0.13, 6)
        tube(solid, PIPE, pr - Y * 0.4, top - pr.y + 0.55, 0.16, 0.13, 6)
        beam(deco, PIPE, tl - r * 0.2, tr + r * 0.2, 0.13)
        -- braces, never lower than 6.3 m
        beam(deco, PIPE, tl - Y * 1.3, tl + r * 1.6 - Y * 0.05, 0.07)
        beam(deco, PIPE, tr - Y * 1.3, tr - r * 1.6 - Y * 0.05, 0.07)
        for k = -2, 2 do
          local c = pos[i] + r * (k * W[i] * 0.42) + Y * 6.25
          cone(S(deco, SPRAY), ring(c, 0.62, 0.62, 5, k), c, v3(c.x, top - 0.1, c.z), flat(SPRAY), SPRAY)
        end
        -- spray down the outside of each post, to the verge
        for s = -1, 1, 2 do
          local b0 = (s < 0) and pl or pr
          local c = b0 + r * (s * 1.3) + Y * 0.6
          if clear(c, 1) then
            cone(S(deco, SPRAY), ring(c, 0.9, 0.9, 5, 0), c, v3(b0.x, top - 0.4, b0.z), flat(SPRAY), SPRAY)
          end
        end
        if last then
          beam(deco, PIPE, last[1], tl, 0.09)
          beam(deco, PIPE, last[2], tr, 0.09)
          beam(deco, PIPE, last[1] - Y * 3.6, tl - Y * 3.6, 0.07)
          beam(deco, PIPE, last[2] - Y * 3.6, tr - Y * 3.6, 0.07)
        end
        last = {tl, tr}
      else
        last = nil
      end
    end
  end

  -- THE LAYOUT.
  local D0 = EDGE + 1.7
  local FIRST = 2 * K.SUB + 4
  local TUN0, TUN1 = 122, 140

  -- The shop where the road runs level, the sign after the start ramp.
  for _, try in ipairs({{76, 1}, {76, -1}, {74, 1}, {78, -1}, {166, 1}, {166, -1}}) do
    local F = plot(try[1], try[2], EDGE + 4.2, 11.5, 4, 0.12)
    if F then shop(F); break end
  end
  totem(FIRST + 2, 1)
  tunnel(TUN0, TUN1, 2)

  -- Hanging baskets down both verges.
  for i = FIRST, N - 2, 4 do
    for side = -1, 1, 2 do
      local j = i + ((side > 0) and 2 or 0)
      if j <= N - 1 and math.abs(j - K.start) > 2 and math.abs(j - K.fin) > 2 and (j < TUN0 - 1 or j > TUN1 + 1) then
        local p = pos[j] + right[j] * (side * (W[j] + EDGE + 0.8))
        if clear(p, 0.15) then basket_post(p, K.along(j), j) end
      end
    end
  end

  -- The plots along the road, a kind each.
  local kinds = {}
  local function facing(F) return normalize(F.w * -0.75 - F.u * 0.66) end
  function kinds.tables(i, side)
    local F = plot(i, side, D0, 5.6, 3.5)
    if not F then return false end
    for row = -1, 1 do
      for k = -1, 1, 2 do
        plant_table(at(F, k * 2.85, 0, row * 2.3), F.u, F.w, 2.5, 0.62, i * 7 + row * 3 + k + side * 100)
      end
    end
    return true
  end
  function kinds.green(i, side)
    local F = plot(i, side, D0, 5.6, 2.7)
    if not F then return false end
    greenhouse(F, 5.6, 2.7)
    return true
  end
  function kinds.gnomes(i, side)
    local F = plot(i, side, D0, 4.2, 2.4)
    if not F then return false end
    local f = facing(F)
    gnome(solid, gp(at(F, 0, 0, 0.6)) - Y * 0.1, 3.4 + hash(i, side) * 1.4, f, pickh(JACKET, i, side))
    for k, a in ipairs({-3.4, -1.9, 1.9, 3.4}) do
      local p = gp(at(F, a, 0, -0.9 + (k % 2) * 1.2)) - Y * 0.05
      gnome(deco, p, 1.2 + hash(i, k) * 0.6, f, pickh(JACKET, i + k, side + 3))
    end
    for k, a in ipairs({-2.7, -0.9, 1.0, 2.8}) do
      toadstool(gp(at(F, a, 0, -1.9 + (k % 2) * 0.5)), 0.8 + hash(k, i) * 0.7)
    end
    return true
  end
  function kinds.small_gnomes(i, side)
    local F = plot(i, side, D0, 2.2, 1.3)
    if not F then return false end
    local f = facing(F)
    for k, a in ipairs({-1.4, 0, 1.4}) do
      gnome(deco, gp(at(F, a, 0, (k % 2) * 0.6 - 0.3)) - Y * 0.05, 1.4 + hash(i, k) * 0.9, f, pickh(JACKET, i + k, side + 5))
    end
    return true
  end
  function kinds.big_gnome(i, side)
    local F = plot(i, side, D0 + 0.6, 2.8, 2.8, 1)
    if not F then return false end
    tube(solid, STONE, F.c + Y * F.base, 0.7 - F.base, 2.3, 2.1, 8)
    gnome(solid, F.c + Y * 0.69, 6 + hash(i, side) * 2.5, facing(F), pickh(JACKET, i, side + 1))
    return true
  end
  function kinds.bags(i, side)
    local F = plot(i, side, D0, 5.0, 2.5)
    if not F then return false end
    for k = 0, 3 do
      for row = 0, 1 do
        local p = at(F, (k - 1.5) * 2.3, 0, row * 2.3 - 1.0)
        if row == 0 and hash(i + k, side) < 0.3 then
          trolley(p, F.u, F.w, pickh({RED, PIPE, STEEL}, i, k), 1 + k % 2, i + k)
        else
          bag_stack(p, F.u, F.w, 2 + floor(hash(i + k, row + side) * 5) + row, i * 3 + k + row * 11)
        end
      end
    end
    return true
  end
  function kinds.compost(i, side)
    local F = plot(i, side, D0, 5.6, 3.0)
    if not F then return false end
    fb(solid, WOOD, F, 0, 2.85, 5.6, 0.12, F.base, 2.0)
    for k = 0, 3 do fb(solid, WOOD_DK, F, -5.48 + k * 3.653, 0, 0.12, 2.7, F.base + 0.01, 1.8) end
    for k = 0, 2 do
      local c = pickh(COMPOST, i + k, side + 2)
      heap(at(F, -3.65 + k * 3.653, -0.2, 0.3), 1.6, 1.3 + hash(i, k) * 1.2, 2.3, c)
      if k == 1 then
        -- a fork stuck in the middle heap
        local top = at(F, 0.3, 1.0, 0)
        beam(deco, WOOD, top, top + Y * 2.0 + F.u * 0.4, 0.04)
        box(deco, STEEL, top + Y * 0.9 + F.u * 0.18, F.u * 0.03, Y * 0.03, F.w * 0.22)
      end
    end
    return true
  end
  function kinds.pots(i, side)
    local F = plot(i, side, D0, 4.6, 2.2)
    if not F then return false end
    pyramid(at(F, -2.35, 0, 0), F.u, F.w, 0.52)
    pyramid(at(F, 2.35, 0, 0), F.u, F.w, 0.52)
    return true
  end
  function kinds.shed(i, side)
    local F = plot(i, side, D0, 4.8, 2.5)
    if not F then return false end
    shed(F, -2.3, 0.5, 2.3, 1.8, pickh(SHED, i, side))
    planter(gp(at(F, 1.3, 0, -1.2)), 0.6, 1 + i % 3, (i % 3 == 0) and LEAF[1] or pickh(FLOWER, i, 2))
    planter(gp(at(F, 3.6, 0, 0.8)), 0.75, 2, LEAF[2])
    gnome(deco, gp(at(F, 2.5, 0, -1.3)) - Y * 0.05, 1.5, facing(F), pickh(JACKET, i, 8))
    trolley(at(F, 3.4, 0, -1.4), F.u, F.w, RED, 2, i)
    return true
  end
  function kinds.water(i, side)
    local F = plot(i, side, D0, 3.2, 3.2, (i % 2 == 0) and 0.8 or 0.6)
    if not F then return false end
    if i % 2 == 0 then fountain(F) else pond(F, i) end
    return true
  end

  local SEQ = {"tables", "green", "gnomes", "bags", "tables", "compost", "pots", "shed", "water", "tables", "green", "big_gnome"}
  local k = 0
  for i = FIRST + 1, N - 3, 5 do
    k = k + 1
    for side = -1, 1, 2 do
      local kind = SEQ[(k + ((side > 0) and 5 or 0)) % #SEQ + 1]
      if not kinds[kind](i, side) then
        if not kinds.small_gnomes(i, side) then kinds.small_gnomes(i + 2, side) end
      end
    end
  end

  -- The second row, further up the slopes: bigger things.
  local function big(F, kind, key)
    if kind == 1 then
      polytunnel(F, F.hu, F.hw)
    elseif kind == 2 then
      greenhouse(F, F.hu, F.hw)
    elseif kind == 3 then
      local c = pickh(COMPOST, key, 1)
      heap(v3(F.c.x, F.lo - 0.4, F.c.z), F.hu, 2.6 + hash(key, 2) * 1.6, F.hw, c)
      heap(v3(F.c.x, F.lo - 0.3, F.c.z) + F.u * (F.hu * 0.75), F.hu * 0.5, 1.6, F.hw * 0.6, pickh(COMPOST, key, 3))
    else
      shed(F, 0, 0, F.hu, F.hw, pickh(SHED, key, 4))
    end
  end
  local SIZES = {{8, 3}, {6.5, 3.2}, {4.6, 4}, {2.6, 2}}
  local row2 = 0
  for i = FIRST + 4, N - 3, 6 do
    for side = -1, 1, 2 do
      row2 = row2 + 1
      local kind = 1 + (row2 + ((side > 0) and 2 or 0)) % 5
      local r = right[i] * side
      if kind == 5 then
        local F = place(pos[i] + r * (W[i] + D0 + 13 + hash(i, side) * 4), K.along(i), r, 2.5, 2.5, 0.4)
        if F then gnome(solid, F.c - Y * 0.2, 7 + hash(i, side + 4) * 4, facing(F), pickh(JACKET, i, side + 6)) end
      else
        local sz = SIZES[kind]
        local F = place(pos[i] + r * (W[i] + D0 + 9.5 + sz[2] + hash(i, side) * 3), K.along(i), r, sz[1], sz[2])
        if F then big(F, kind, i + side) end
      end
    end
  end

  -- And scattered over the far slopes: polytunnels, greenhouses, heaps and giant gnomes looking down at the road.
  local function to_road(x, z)
    local best, bi = 1e18, 1
    for i = 1, N, 4 do
      local dx, dz = pos[i].x - x, pos[i].z - z
      if dx * dx + dz * dz < best then best, bi = dx * dx + dz * dz, i end
    end
    return normalize(v3(pos[bi].x - x, 0, pos[bi].z - z))
  end
  local far = 0
  for n = 1, 150 do
    if far >= 46 then break end
    local x, z = K.spot(24)
    if x then
      local f = to_road(x, z)
      local u = v3(f.z, 0, -f.x)
      local kind = 1 + n % 5
      if kind == 5 then
        local F = place(v3(x, 0, z), u, f * -1, 3, 3, 0.4)
        if F then gnome(solid, F.c - Y * 0.2, 8 + g:range(0, 6), f, pickh(JACKET, n, 1)); far = far + 1 end
      else
        local sz = SIZES[kind]
        local F = place(v3(x, 0, z), u, f * -1, sz[1] * 1.15, sz[2] * 1.15)
        if F then big(F, kind, n); far = far + 1 end
      end
    end
  end
end

return T
