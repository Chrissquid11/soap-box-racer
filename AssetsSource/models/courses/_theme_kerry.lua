-- The Kerry Cliffs course's scenery kit (see THEME KITS in _course.lua), on top of the library's farms, fences and
-- marquees (keep = true): the Atlantic down the east side beyond a line of cliffs (T.shape drops the ground to the
-- sea bed, the kit lays the water over it and out past the valley's edge) with the two Skellig rocks out at sea;
-- emerald fields (T.paint) cut up by grey dry-stone walls; white-washed cottages, thatched or slated, with coloured
-- doors; a village street -- a red pub, yellow and blue shopfronts, painted houses, a tricolour -- and its stone
-- church in a walled graveyard of Celtic crosses; a round tower by a ruined chapel; a ruined castle tower on the
-- headland; a holy well with its rag tree; fuchsia hedges in red flower; blackface sheep with red and blue marks;
-- rocky outcrops; wind-bent trees (the library's own are left out: they would stand in the sea).
local T = {keep = true, trees = 0}

local SEA, BED = -9.5, -11.5
local function clamp01(v) return (v < 0) and 0 or ((v > 1) and 1 or v) end
-- The coast in plan: the sea is east of x = coast(z) -- a wobbling line down the east side, swinging west below the
-- bends as the road does.
local function coast(z)
  local c = 56 + 5 * math.sin(z * 0.05) + 3.5 * math.sin(z * 0.13 + 1)
  if z < -110 then c = c + (z + 110) * 0.55 end
  return c
end

-- The ground: on the sea's side it falls gently from the road to the cliff's edge (so the sea shows from the road),
-- then drops to the sea bed.
function T.shape(x, z, off, y, road_y, TK)
  if off <= 9 then return nil end
  local dxc = x - coast(z)
  if dxc < -50 then return nil end
  local target = math.max(road_y - 1.5 - 0.1 * (off - 9), SEA + 5)
  if target < y then y = y + (target - y) * clamp01((dxc + 50) / 22) * clamp01((off - 9) / 10) end
  -- (The sea bed is rough, never level enough for the library to stand a farm on; the water hides it.)
  if dxc > 0 then y = y + (BED - 7.5 * TK.hash(x, z) - y) * clamp01(dxc / 5) * clamp01((off - 30) / 6) end
  return y
end

local INK, EMER
function T.paint(x, z, off, ink, TK)
  if not INK then
    local c = TK.col
    INK = {bed = c(0.02, 0.16, 0.3), rock = {c(0.3, 0.3, 0.31), c(0.4, 0.39, 0.37), c(0.24, 0.24, 0.26)},
      crag = c(0.42, 0.42, 0.4), heath = c(0.3, 0.2, 0.3), em = c(0.03, 0.5, 0.1)}
    EMER = {}
  end
  if off < 4.2 then return nil end
  local dxc = x - coast(z)
  if off > 30 and dxc > 7 then return INK.bed end
  if off > 24 and dxc > -7 then return INK.rock[1 + math.floor(TK.hash(x, z) * 2.99)] end
  if off > 12 then
    local n = noise3(x, 0, z, {frequency = 0.045, seed = 5})
    if n > 0.5 then return INK.crag elseif n > 0.42 then return INK.heath end
  end
  local e = EMER[ink]
  if not e then e = TK.mix(ink, INK.em, 0.55); EMER[ink] = e end
  return e
end

function T.build(K)
  local col = K.col
  local UP = v3(0, 1, 0)
  local pos, right, W, N = K.pos, K.right, K.W, K.N
  local function rnd(a, b) return K.g:range(a, b) end
  local EDGE = K.WALL_T + 1          -- the road's own margin: nothing of the kit's nearer its edge

  local WHITE, DARK = col(0.94, 0.94, 0.9), col(0.05, 0.06, 0.08)
  local LIME = {col(0.95, 0.95, 0.9), col(0.9, 0.9, 0.84), col(0.96, 0.93, 0.85)}
  local THATCH, THATCH_D = col(0.78, 0.6, 0.22), col(0.5, 0.36, 0.14)
  local SLATE, SLATE2 = col(0.2, 0.22, 0.27), col(0.27, 0.28, 0.32)
  local ST1, ST2, ST3, ST4 = col(0.5, 0.5, 0.5), col(0.4, 0.4, 0.41), col(0.3, 0.3, 0.32), col(0.6, 0.59, 0.56)
  local STONES = {ST1, ST2, ST4}
  local MOSS, LICHEN, IVY = col(0.2, 0.36, 0.12), col(0.7, 0.68, 0.4), col(0.06, 0.3, 0.08)
  local RED, YEL, BLUE, GREEN, PINK, ORANGE, TEAL = col(0.85, 0.06, 0.05), col(0.98, 0.78, 0.05), col(0.06, 0.25, 0.85),
    col(0.05, 0.5, 0.15), col(0.95, 0.45, 0.6), col(0.95, 0.45, 0.04), col(0.05, 0.55, 0.55)
  local DOORS = {RED, BLUE, GREEN, YEL, TEAL, ORANGE}
  local GLASS, GOLD, WOOD, BARREL = col(0.08, 0.15, 0.26), col(0.9, 0.7, 0.15), col(0.36, 0.22, 0.1), col(0.45, 0.27, 0.1)
  local WOOL, WOOL2, FACE = col(0.93, 0.92, 0.86), col(0.84, 0.82, 0.74), col(0.06, 0.06, 0.06)
  local F_GREEN, F_GREEN2, F_LOW, FUCH, FUCH2 = col(0.07, 0.3, 0.1), col(0.1, 0.4, 0.12), col(0.04, 0.2, 0.07),
    col(0.9, 0.04, 0.12), col(0.75, 0.05, 0.5)
  local BARK = col(0.25, 0.16, 0.09)
  local CROWNS = {col(0.1, 0.36, 0.08), col(0.16, 0.42, 0.1), col(0.07, 0.3, 0.1)}
  local WATERS = {col(0.03, 0.26, 0.48), col(0.04, 0.32, 0.55), col(0.02, 0.2, 0.42), col(0.06, 0.38, 0.58)}
  local FOAM = col(0.92, 0.96, 0.97)
  local SK1, SK2, SK3, GUANO = col(0.27, 0.27, 0.3), col(0.36, 0.35, 0.36), col(0.18, 0.34, 0.14), col(0.88, 0.88, 0.84)

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
  -- A round tube through pts, radius rr[j] at each, n-sided, one colour; `squash` flattens it the second way.
  local function tube(root, c, pts, rr, n, hint, squash)
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
    K.prism(piece(root, c), rings, K.flat(c), c, c)
  end
  local T4 = {-0.95, -0.5, 0.5, 0.95}
  local function egg(root, c, cen, axis, r1, r2, n)
    local pts, rr = {}, {}
    for _, t in ipairs(T4) do
      pts[#pts + 1] = cen + axis * t
      rr[#rr + 1] = r1 * math.sqrt(1 - t * t)
    end
    tube(root, c, pts, rr, n or 6, nil, r2 / r1)
  end
  -- A face's shade on a lump, one set of colours a base colour (never made twice: a colour is a painting pass).
  local SH = {}
  local function shaded(base)
    if not SH[base] then SH[base] = K.shaded(base) end
    return SH[base]
  end

  -- ---------------------------------------------------------------- where
  local function off(x, z) local _, d = K.ground_d(x, z); return d - K.HW end   -- metres off the road's edge
  local function clear(x, z, m) return off(x, z) > EDGE + (m or 0.4) end
  local function land(x, z, m)
    return x < coast(z) - (m or 4) and x > K.X0 + 2 and x < K.X1 - 2 and z > K.Z1 + 2 and z < K.Z0 - 2
  end
  local function G(x, z) return v3(x, K.ground(x, z), z) end
  local taken = {}
  local function free(x, z, R)
    for _, t in ipairs(taken) do
      local dx, dz = t[1] - x, t[2] - z
      if dx * dx + dz * dz < (t[3] + R) * (t[3] + R) then return false end
    end
    return true
  end
  local function take(x, z, R) taken[#taken + 1] = {x, z, R} end
  local function flatten(d) return normalize(v3(d.x, 0, d.z)) end
  local function east(i) return (right[i].x >= 0) and 1 or -1 end
  -- The ground's lowest and highest under a footprint.
  local function stand(c, u, f, hu, hw)
    local lo, hi = math.huge, -math.huge
    for _, a in ipairs({{1, 1}, {-1, 1}, {-1, -1}, {1, -1}, {0, 0}}) do
      local p = c + u * (a[1] * hu) + f * (a[2] * hw)
      local y = K.ground(p.x, p.z)
      lo, hi = math.min(lo, y), math.max(hi, y)
    end
    return lo, hi
  end
  -- A plot at sample i on `side`, its near side d metres off the road's margin: its middle, u down the road, f its
  -- front (to the road). Nil where it would not be clear of the road, the sea or another plot.
  local function plot(i, side, d, hu, hw, shift)
    i = math.max(2, math.min(N - 1, i))
    local w = right[i] * side
    local u = flatten(K.along(i))
    local c = pos[i] + w * (W[i] + EDGE + d + hw) + u * (shift or 0)
    c = v3(c.x, 0, c.z)
    for _, a in ipairs({{1, 1}, {-1, 1}, {-1, -1}, {1, -1}, {0, 0}, {0, -1}, {1, 0}, {-1, 0}}) do
      local p = c + u * (a[1] * hu) + w * (a[2] * hw)
      if not clear(p.x, p.z, math.min(d, 6)) or not land(p.x, p.z, 3) then return nil end
    end
    local R = math.max(hu, hw) + 1.2
    if not free(c.x, c.z, R) then return nil end
    take(c.x, c.z, R)
    return c, u, w * -1
  end

  -- ---------------------------------------------------------------- houses
  -- A gabled house: footprint hu along u by hw along f (its front), walls h above the highest ground under it.
  -- o: wall, roof ("thatch" or a colour), door (a colour; none if nil), door_at, chim (offsets along u), wins (offsets
  -- along u, each a window on the front and the back), floors (1 or 2), trim.
  local function house(root, c, u, f, hu, hw, h, o)
    local lo, hi = stand(c, u, f, hu, hw)
    local y0, ye = lo - 0.6, hi + h
    local rise = o.rise or hw * 0.85
    local function P(du, dw, y) return v3(c.x, y, c.z) + u * du + f * dw end
    local rings = {}
    for s = -1, 1, 2 do
      rings[#rings + 1] = {P(s * hu, -hw, y0), P(s * hu, hw, y0), P(s * hu, hw, ye), P(s * hu, 0, ye + rise), P(s * hu, -hw, ye)}
    end
    K.prism(piece(root, o.wall), rings, K.flat(o.wall), o.wall, o.wall)
    local thatch = o.roof == "thatch"
    local rc = thatch and THATCH or o.roof
    local t, ov = thatch and 0.36 or 0.12, thatch and 0.45 or 0.3
    for s = -1, 1, 2 do
      local E = P(0, s * (hw + ov), ye - ov * rise / hw)
      local R = P(0, 0, ye + rise)
      local d = (R - E) * 0.5
      local n = normalize(cross(u, d))
      if n.y < 0 then n = n * -1 end
      obox(root, (s > 0 or thatch) and rc or K.pick({rc, rc, SLATE2}), (E + R) * 0.5 + n * (t * 0.5 + 0.03) + d * (0.02 * s), u * (hu + ov), d * 1.03, n * (t * 0.5))
    end
    if thatch then beam(root, THATCH_D, P(-hu - ov - 0.05, 0, ye + rise + 0.3), P(hu + ov + 0.05, 0, ye + rise + 0.3), 0.4, 0.14) end
    for _, du in ipairs(o.chim or {}) do
      local cc = o.chimc or o.wall
      obox(root, cc, P(du, 0, ye + rise + 0.35), u * 0.36, UP * 0.95, f * 0.32)
      obox(root, ST3, P(du, 0, ye + rise + 1.36), u * 0.42, UP * 0.06, f * 0.38)
      K.column(piece(root, ORANGE), P(du, 0, 0).x, P(du, 0, 0).z, ye + rise + 1.43, ye + rise + 1.8, 0.13, 0.11, 6, ORANGE)
    end
    local trim = o.trim or WHITE
    local function window(du, y, face, hx, hy)
      obox(root, trim, P(du, face * (hw + 0.03), y), u * (hx + 0.1), UP * (hy + 0.1), f * 0.04)
      obox(root, GLASS, P(du, face * (hw + 0.07), y), u * hx, UP * hy, f * 0.03)
      obox(root, trim, P(du, face * (hw + 0.12), y - hy - 0.12), u * (hx + 0.18), UP * 0.05, f * 0.08)
    end
    local floors = o.floors or 1
    for _, du in ipairs(o.wins or {}) do
      for fl = 1, floors do
        local y = ye - 1.05 - (floors - fl) * 2.7
        if not (fl == 1 and o.shop) then window(du, y, 1, 0.42, 0.5) end
        if o.back ~= false then window(du, y, -1, 0.42, 0.5) end
      end
    end
    if o.door then
      local du = o.door_at or 0
      local fp = P(du, hw, 0)
      local gy = math.max(K.ground(fp.x, fp.z), y0 + 0.7)
      obox(root, trim, P(du, hw + 0.03, gy + 0.95), u * 0.58, UP * 1.1, f * 0.04)
      obox(root, o.door, P(du, hw + 0.07, gy + 0.9), u * 0.45, UP * 0.98, f * 0.04)
      obox(root, ST1, P(du, hw + 0.4, gy - 0.1), u * 0.7, UP * 0.16, f * 0.36)
    end
    return y0, ye, rise, P
  end

  local function cottage(i, side, d, thatch, door, big)
    local hu, hw = big and 4.4 or 3.7, 2.5
    local c, u, f = plot(i, side, d, hu, hw)
    if not c then return end
    local wall = K.pick(LIME)
    house(K.solid, c, u, f, hu, hw, 2.5, {wall = wall, roof = thatch and "thatch" or SLATE, door = door, chim = big and {-hu + 0.5, hu - 0.5} or {hu - 0.5},
      wins = big and {-3.0, -1.45, 1.5, 3.0} or {-2.1, 2.1}, trim = thatch and door or WHITE, rise = thatch and 2.5 or 2.0})
    -- A turf stack or a bench by the door, a flower tub.
    local p = c + u * (hu + 0.9) + f * 0.4
    if clear(p.x, p.z, 1) then
      local gy = K.ground(p.x, p.z)
      obox(K.solid, THATCH_D, v3(p.x, gy + 0.5, p.z), u * 0.6, UP * 0.75, f * 1.1)
      obox(K.solid, WOOD, v3(p.x, gy + 1.3, p.z), u * 0.5, UP * 0.1, f * 1.0)
    end
  end

  -- ---------------------------------------------------------------- the village street
  local function shop(c, u, f, hu, o)
    local hw = 3.0
    local y0, ye, rise, P = house(K.solid, c, u, f, hu, hw, 5.5, {wall = o.wall, roof = SLATE, chim = {hu - 0.5}, chimc = ST2,
      wins = (hu > 3.2) and {-hu * 0.55, 0, hu * 0.55} or {-hu * 0.45, hu * 0.45}, floors = 2, shop = true, trim = o.trim, back = true, rise = 2.3})
    local fp = P(0, hw, 0)
    local gy = math.max(K.ground(fp.x, fp.z), y0 + 0.8)
    -- The shopfront: a plinth, a wide window, a door to one side, pilasters, a fascia board over it all and its name's
    -- lettering as a row of little blocks.
    obox(K.solid, o.fascia, P(0, hw + 0.1, gy + 2.85), u * (hu - 0.1), UP * 0.34, f * 0.12)
    obox(K.solid, o.trim, P(0, hw + 0.2, gy + 3.24), u * (hu - 0.02), UP * 0.06, f * 0.22)
    for k = -3, 3 do
      if (k + (o.gap or 9)) % 4 ~= 0 then obox(K.solid, o.letters or GOLD, P(k * hu * 0.2, hw + 0.24, gy + 2.85), u * (hu * 0.07), UP * 0.17, f * 0.03) end
    end
    obox(K.solid, o.plinth or DARK, P(0, hw + 0.06, gy + 0.3), u * (hu - 0.1), UP * 0.42, f * 0.08)
    local dx = o.door_at or (hu - 1.1)
    obox(K.solid, o.door, P(dx, hw + 0.1, gy + 1.15), u * 0.5, UP * 1.2, f * 0.065)
    obox(K.solid, GLASS, P(dx, hw + 0.15, gy + 1.7), u * 0.3, UP * 0.4, f * 0.02)
    local wx, wh = (dx > 0) and -0.75 or 0.75, hu - 1.75
    obox(K.solid, o.trim, P(wx, hw + 0.06, gy + 1.6), u * (wh + 0.14), UP * 0.9, f * 0.06)
    obox(K.solid, GLASS, P(wx, hw + 0.12, gy + 1.6), u * wh, UP * 0.76, f * 0.03)
    obox(K.solid, o.trim, P(wx, hw + 0.15, gy + 1.6), u * 0.05, UP * 0.76, f * 0.03)
    for s = -1, 1, 2 do obox(K.solid, o.fascia, P(s * (hu - 0.16), hw + 0.1, gy + 1.3), u * 0.14, UP * 1.3, f * 0.1) end
    return P, gy, hw
  end

  local function village()
    local i0 = 63
    local sd = east(i0)
    local u = flatten(K.along(i0))
    local w = right[i0] * sd
    local base = pos[i0] + w * (W[i0] + EDGE + 9.5 + 3.0)
    local row = {
      {hu = 4.2, wall = RED, trim = YEL, fascia = DARK, letters = GOLD, door = DARK, pub = true, gap = 0},
      {hu = 3.3, wall = YEL, trim = WHITE, fascia = GREEN, letters = WHITE, door = GREEN, gap = 1},
      {hu = 3.6, wall = BLUE, trim = WHITE, fascia = WHITE, letters = BLUE, door = RED, gap = 2},
      {hu = 3.1, wall = PINK, trim = WHITE, fascia = TEAL, letters = WHITE, door = TEAL, gap = 3},
      {hu = 3.4, wall = WHITE, trim = GREEN, fascia = ORANGE, letters = DARK, door = GREEN, gap = 1},
    }
    local total = 0
    for _, r in ipairs(row) do total = total + r.hu * 2 + 0.12 end
    local at = -total * 0.5
    for _, r in ipairs(row) do
      local c = base + u * (at + r.hu)
      at = at + r.hu * 2 + 0.12
      c = v3(c.x, 0, c.z)
      local ok = land(c.x, c.z, 6)
      for _, a in ipairs({{1, 1}, {-1, 1}, {0, 1}, {1, -1}, {-1, -1}}) do
        local p = c + u * (a[1] * r.hu) - w * (a[2] * 3.6)
        if not clear(p.x, p.z, 5) then ok = false end
      end
      if ok then
        take(c.x, c.z, r.hu + 1.5)
        local P, gy, hw = shop(c, u, w * -1, r.hu, r)
        if r.pub then
          -- The pub: a hanging sign, barrels and a bench outside, lamps by the door.
          beam(K.solid, DARK, P(-r.hu + 0.3, hw + 0.05, gy + 4.6), P(-r.hu + 0.3, hw + 1.1, gy + 4.6), 0.04, 0.04)
          obox(K.solid, GOLD, P(-r.hu + 0.3, hw + 0.7, gy + 4.05), u * 0.06, UP * 0.48, w * -0.4)
          obox(K.solid, GREEN, P(-r.hu + 0.3, hw + 0.7, gy + 4.05), u * 0.08, UP * 0.3, w * -0.25)
          for k = 0, 2 do
            local bp = P(-r.hu + 0.9 + k * 0.85, hw + 0.75 + (k % 2) * 0.3, 0)
            local by = K.ground(bp.x, bp.z)
            K.column(piece(K.solid, BARREL), bp.x, bp.z, by - 0.2, by + 0.95, 0.36, 0.36, 8, BARREL)
            K.column(piece(K.solid, DARK), bp.x, bp.z, by + 0.951, by + 0.99, 0.37, 0.3, 8, DARK)
          end
          local bn = P(0.6, hw + 0.9, 0)
          local by = K.ground(bn.x, bn.z)
          obox(K.solid, WOOD, v3(bn.x, by + 0.45, bn.z), u * 0.9, UP * 0.05, w * 0.22)
          for s = -1, 1, 2 do obox(K.solid, WOOD, v3(bn.x, by + 0.2, bn.z) + u * (s * 0.75), u * 0.05, UP * 0.3, w * 0.2) end
        end
      end
    end
    -- A flagpole and the tricolour at the street's top end.
    local fp = base - u * (total * 0.5 + 2.2) - w * 5
    if clear(fp.x, fp.z, 2) then
      local gy = K.ground(fp.x, fp.z)
      K.column(piece(K.solid, WHITE), fp.x, fp.z, gy - 0.3, gy + 9, 0.09, 0.06, 6, WHITE)
      for k, c in ipairs({GREEN, WHITE, ORANGE}) do
        obox(K.deco, c, v3(fp.x, gy + 8.1, fp.z) + u * (0.12 + (k - 0.5) * 0.72), u * 0.355, UP * 0.6, w * 0.03)
      end
    end
  end

  -- ---------------------------------------------------------------- stone things
  -- A dry-stone wall from p to q (x, z of each): blocks a couple of metres long, battered, stepping with the ground,
  -- cope stones along the top; left out where the road, the sea or a plot is in the way.
  local function drywall(px, pz, qx, qz, root)
    local len = math.sqrt((qx - px) ^ 2 + (qz - pz) ^ 2)
    if len < 1 then return end
    local n = math.max(1, math.floor(len / 2.3 + 0.5))
    local dir = v3((qx - px) / len, 0, (qz - pz) / len)
    local sd = v3(dir.z, 0, -dir.x)
    for k = 0, n - 1 do
      local t0, t1 = (k + 0.015) / n, (k + 0.985) / n
      local ax, az, bx, bz = px + (qx - px) * t0, pz + (qz - pz) * t0, px + (qx - px) * t1, pz + (qz - pz) * t1
      local mx, mz = (ax + bx) * 0.5, (az + bz) * 0.5
      if land(mx, mz, 5) and clear(mx, mz, 4.6) and free(mx, mz, 0.2) and K.hash(mx, mz) > 0.06 then
        local ya, yb = K.ground(ax, az), K.ground(bx, bz)
        local h = 0.95 + K.hash(mz, mx) * 0.35
        local c = STONES[1 + math.floor(K.hash(mx * 3, mz) * 2.99)]
        local a, b = v3(ax, ya, az), v3(bx, yb, bz)
        local s0, s1, dn, up = sd * 0.4, sd * 0.25, UP * -0.5, UP * h
        K.hexa(piece(root or K.solid, c, c), a - s0 + dn, b - s0 + dn, b + s0 + dn, a + s0 + dn, a - s1 + up, b - s1 + up, b + s1 + up, a + s1 + up)
        local m = (a + b) * 0.5 + UP * (h + 0.1) + dir * ((K.hash(mx, mz * 5) - 0.5) * 0.5)
        obox(root or K.solid, ST3, m, dir * 0.45 + UP * ((yb - ya) * 0.2), UP * 0.13, sd * 0.2)
      end
    end
  end
  local ROCKSH = function(w)
    local ny = w.y / math.max(1e-6, length(w))
    if ny > 0.5 then return (K.hash(w.x * 9, w.z * 7) < 0.25) and MOSS or ST4 elseif ny > -0.1 then return ST1 else return ST3 end
  end
  local function rock(root, p, rx, ry, rz)
    K.ball(piece(root, "rock"), p, rx, ry, rz, 7, 4, function() return rnd(0.72, 1.2) end, ROCKSH)
  end
  local function outcrop(x, z, s)
    local n = math.floor(rnd(2, 5))
    for k = 1, n do
      local px, pz = x + rnd(-1.6, 1.6) * s, z + rnd(-1.6, 1.6) * s
      if k == 1 then px, pz = x, z end
      if clear(px, pz, 2.5 * s) then
        local r = s * ((k == 1) and rnd(1.4, 2.0) or rnd(0.6, 1.2))
        rock(K.solid, G(px, pz) + UP * (r * 0.25), r * rnd(0.9, 1.3), r * rnd(0.8, 1.5), r * rnd(0.9, 1.3))
      end
    end
  end
  -- A Celtic cross, its face to f.
  local function cross_(root, p, f, h, c)
    local u = cross(UP, f)
    obox(root, c, p + UP * (h * 0.5 - 0.2), u * (h * 0.06), UP * (h * 0.5 + 0.2), f * (h * 0.045))
    obox(root, c, p + UP * (h * 0.78), u * (h * 0.24), UP * (h * 0.055), f * (h * 0.04))
    tube(root, c, {p + UP * (h * 0.78) - f * (h * 0.03), p + UP * (h * 0.78) + f * (h * 0.03)}, {h * 0.16, h * 0.16}, 8, UP)
    obox(root, c, p + UP * 0.12, u * (h * 0.14), UP * 0.2, f * (h * 0.1))
  end

  local function church()
    local hu, hw = 6.0, 3.2
    local c, u, f
    for _, i in ipairs({78, 76, 80, 74, 82}) do
      c, u, f = plot(i, east(i), 14, hu + 3, hw + 1)
      if c then break end
    end
    if not c then info("kerry: no room for the church"); return end
    local y0, ye, rise, P = house(K.solid, c, u, f, hu, hw, 4.6, {wall = ST1, roof = SLATE, rise = 3.4, back = false})
    -- Lancet windows down both sides, a rose in the east gable.
    for s = -1, 1, 2 do
      for k = -1, 1 do
        obox(K.solid, ST4, P(k * 3.2, s * (hw + 0.03), ye - 1.9), u * 0.42, UP * 1.3, f * 0.04)
        obox(K.solid, GLASS, P(k * 3.2, s * (hw + 0.07), ye - 1.9), u * 0.28, UP * 1.15, f * 0.03)
        obox(K.solid, (k == 0) and RED or BLUE, P(k * 3.2, s * (hw + 0.09), ye - 1.2), u * 0.28, UP * 0.3, f * 0.03)
      end
    end
    tube(K.solid, GLASS, {P(hu + 0.03, 0, ye + 0.9), P(hu + 0.1, 0, ye + 0.9)}, {0.9, 0.9}, 8, UP)
    -- The tower at the uphill end, its spire and a gold cross; the red door in it.
    local tc = P(-hu - 2.0, 0, 0)
    local th = ye + rise + 3.5
    local tr = 2.2
    local rings = {}
    for _, y in ipairs({y0, ye - 1, ye + 2, th}) do
      rings[#rings + 1] = {v3(tc.x, y, tc.z) - u * tr - f * tr, v3(tc.x, y, tc.z) + u * tr - f * tr, v3(tc.x, y, tc.z) + u * tr + f * tr, v3(tc.x, y, tc.z) - u * tr + f * tr}
    end
    K.prism(piece(K.solid, "church tower"), rings, function(j, _) return (j % 2 == 0) and ST2 or ST1 end, ST1, ST1)
    local top = v3(tc.x, th + 0.03, tc.z)
    K.cone(piece(K.solid, SLATE), {top - u * 2.5 - f * 2.5, top + u * 2.5 - f * 2.5, top + u * 2.5 + f * 2.5, top - u * 2.5 + f * 2.5}, top, top + UP * 7.5, K.flat(SLATE), SLATE)
    obox(K.solid, GOLD, top + UP * 8.1, u * 0.07, UP * 0.75, f * 0.07)
    obox(K.solid, GOLD, top + UP * 8.35, u * 0.4, UP * 0.07, f * 0.07)
    local gy = K.ground((tc + f * tr).x, (tc + f * tr).z)
    obox(K.solid, ST4, v3(tc.x, gy + 1.3, tc.z) + f * (tr + 0.03), u * 0.85, UP * 1.5, f * 0.04)
    obox(K.solid, RED, v3(tc.x, gy + 1.2, tc.z) + f * (tr + 0.07), u * 0.65, UP * 1.3, f * 0.04)
    for s = -1, 1, 2 do
      obox(K.solid, DARK, v3(tc.x, th - 1.6, tc.z) + f * (s * (tr + 0.04)), u * 0.4, UP * 0.8, f * 0.04)
      obox(K.solid, DARK, v3(tc.x, th - 1.6, tc.z) + u * (s * (tr + 0.04)), f * 0.4, UP * 0.8, u * 0.04)
    end
    -- The graveyard in front and beside: crosses and headstones, a wall round the lot.
    local a, b = hu + 5.5, hw + 5.5
    local cs = {c - u * a - f * (hw + 1.5), c + u * a - f * (hw + 1.5), c + u * a + f * b, c - u * a + f * b}
    for k = 1, 4 do
      local p, q = cs[k], cs[k % 4 + 1]
      if k == 3 then
        local m1, m2 = lerp(p, q, 0.4), lerp(p, q, 0.6)      -- the gate
        drywall(p.x, p.z, m1.x, m1.z); drywall(m2.x, m2.z, q.x, q.z)
      else
        drywall(p.x, p.z, q.x, q.z)
      end
    end
    for k = 1, 12 do
      local p = c + u * rnd(-a + 1, a - 1) + f * rnd(hw + 1.2, b - 1)
      if clear(p.x, p.z, 4) then
        local g0 = G(p.x, p.z)
        if k % 3 == 0 then obox(K.solid, K.pick(STONES), g0 + UP * 0.4, u * 0.3, UP * 0.6, f * 0.07)
        else cross_(K.solid, g0, f, rnd(1.5, 2.4), K.pick(STONES)) end
      end
    end
  end

  -- The round tower: a tall tapering drum of banded stone under a conical cap, its door well off the ground; beside
  -- it a roofless chapel's gables and a high cross.
  local function round_tower()
    local c, u, f
    for _, tr in ipairs({{24, -1, 14}, {26, -1, 16}, {22, -1, 18}, {30, -1, 14}, {34, -1, 14}}) do
      c, u, f = plot(tr[1], tr[2] * east(tr[1]), tr[3], 7, 4)
      if c then break end
    end
    if not c then info("kerry: no room for the round tower"); return end
    local tp = c - u * 4
    local lo, hi = stand(tp, u, f, 2.8, 2.8)
    local H = 27
    local rings, hs, rs = {}, {lo - 0.6, hi + 4, hi + 9, hi + 14, hi + 19, hi + 23, hi + H}, {2.9, 2.75, 2.6, 2.45, 2.3, 2.2, 2.1}
    for j, y in ipairs(hs) do rings[j] = K.ring(v3(tp.x, y, tp.z), rs[j], rs[j], 12, 0) end
    K.prism(piece(K.solid, "round tower"), rings, function(j, k) return ((j + math.floor(k / 2)) % 2 == 0) and ST1 or ((k % 3 == 0) and ST4 or ST2) end, ST2, ST2)
    local top = v3(tp.x, hi + H + 0.03, tp.z)
    K.cone(piece(K.solid, ST3), K.ring(top, 2.3, 2.3, 12, 0), top, top + UP * 4.6, K.flat(ST3), ST3)
    obox(K.solid, DARK, v3(tp.x, hi + 4.2, tp.z) + f * 2.72, u * 0.45, UP * 0.95, f * 0.1)
    for k = 0, 3 do
      local a = k * math.pi / 2 + 0.4
      local d = v3(math.cos(a), 0, math.sin(a))
      obox(K.solid, DARK, v3(tp.x, hi + H - 2, tp.z) + d * 2.1, cross(UP, d) * 0.3, UP * 0.6, d * 0.1)
      obox(K.solid, DARK, v3(tp.x, hi + 9 + k * 3.5, tp.z) + d * (2.62 - k * 0.1), cross(UP, d) * 0.2, UP * 0.45, d * 0.1)
    end
    -- The chapel: two gables and broken side walls, no roof.
    local cc = c + u * 3.5 - f * 0.5
    local l2, h2 = stand(cc, u, f, 3.2, 2.2)
    for s = -1, 1, 2 do
      local e = v3(cc.x, 0, cc.z) + u * (s * 3.2)
      local ring1 = {e - f * 2.2 + UP * (l2 - 0.5), e + f * 2.2 + UP * (l2 - 0.5), e + f * 2.2 + UP * (h2 + 2.6), e + UP * (h2 + ((s < 0) and 5.2 or 4.0)), e - f * 2.2 + UP * (h2 + 2.6)}
      local ring2 = {}
      for k, p in ipairs(ring1) do ring2[k] = p + u * (s * 0.6) end
      K.prism(piece(K.solid, ST2), {ring1, ring2}, K.flat(ST2), ST2, ST2)
      obox(K.solid, DARK, e + u * (s * 0.3) + UP * (h2 + 2.3), u * 0.34, UP * 0.7, f * 0.3)
    end
    for s = -1, 1, 2 do
      local m = v3(cc.x, 0, cc.z) + f * (s * 1.95)
      obox(K.solid, ST1, m + u * 1.0 + UP * ((l2 + h2 + 1.9) * 0.5), u * 2.15, UP * ((h2 + 1.9 - l2) * 0.5 + 0.25), f * 0.25)
      obox(K.solid, ST4, m - u * 1.9 + UP * ((l2 + h2 + 0.9) * 0.5), u * 1.2, UP * ((h2 + 0.9 - l2) * 0.5 + 0.2), f * 0.21)
    end
    local xp = c + f * 3.4 + u * 0.5
    if clear(xp.x, xp.z, 3) then cross_(K.solid, G(xp.x, xp.z), f, 3.6, ST4) end
  end

  -- The castle: a ruined tower house, its top broken down to stumps, one corner fallen; ivy up a side, slit windows,
  -- a dark doorway, rubble round its foot.
  local function castle()
    local hu, hw = 4.0, 3.4
    local c, u, f
    for _, tr in ipairs({{88, 1, 16}, {90, 1, 18}, {86, 1, 20}, {92, 1, 16}, {84, 1, 14}, {50, 1, 16}}) do
      c, u, f = plot(tr[1], tr[2] * east(tr[1]), tr[3], hu + 2, hw + 2)
      if c then break end
    end
    if not c then info("kerry: no room for the castle"); return end
    local lo, hi = stand(c, u, f, hu, hw)
    local function P(du, dw, y) return v3(c.x, y, c.z) + u * du + f * dw end
    local rings = {}
    for j, y in ipairs({lo - 0.8, hi + 1.2, hi + 4, hi + 6.5, hi + 9}) do
      local e = (j == 1) and 0.5 or ((j == 2) and 0.15 or 0)
      rings[j] = {P(-hu - e, -hw - e, y), P(hu + e, -hw - e, y), P(hu + e, hw + e, y), P(-hu - e, hw + e, y)}
    end
    K.prism(piece(K.solid, "castle"), rings, function(j, k) return ((j + k) % 2 == 0) and ST1 or ST2 end, ST3, ST3)
    local top = hi + 9
    -- What is left of the top floor: wall stumps of different heights, in from the faces a hair.
    local function stump(du0, du1, dw0, dw1, h, cc)
      obox(K.solid, cc, P((du0 + du1) * 0.5, (dw0 + dw1) * 0.5, top + h * 0.5 - 0.1 - h * 0.01), u * (math.abs(du1 - du0) * 0.5), UP * (h * 0.5 + 0.1 + h * 0.01), f * (math.abs(dw1 - dw0) * 0.5))
    end
    local e = 0.03
    stump(-hu + e, hu * 0.2, hw - 0.9, hw - e, 5.5, ST1)
    stump(hu * 0.22, hu * 0.7, hw - 0.9, hw - e, 3.0, ST2)
    stump(-hu + e, -hu + 0.9, -hw + e, hw - 0.93, 4.2, ST2)
    stump(-hu + 0.93, hu * 0.1, -hw + e, -hw + 0.9, 6.8, ST1)
    stump(hu * 0.12, hu * 0.5, -hw + e, -hw + 0.9, 2.2, ST4)
    stump(hu - 0.9, hu - e, -hw * 0.2, hw * 0.3, 1.4, ST2)
    for k = 0, 1 do stump(-hu + 1.2 + k * 1.5, -hu + 1.9 + k * 1.5, -hw + e + 0.02, -hw + 0.88, 7.8, ST1) end
    stump(-hu + e + 0.02, -hu * 0.55, hw - 0.88, hw - e - 0.02, 6.5, ST1)
    -- Doorway, slits, ivy.
    local gy = K.ground(P(0, hw, 0).x, P(0, hw, 0).z)
    obox(K.solid, DARK, P(-0.6, hw + 0.2, gy + 1.2), u * 0.7, UP * 1.4, f * 0.08)
    obox(K.solid, DARK, P(-0.6, hw + 0.2, gy + 2.75), u * 0.45, UP * 0.2, f * 0.08)
    for _, sl in ipairs({{-2.4, 5}, {1.6, 4.4}, {-0.6, 7.4}, {2.6, 7.6}}) do
      obox(K.solid, DARK, P(sl[1], hw + 0.03, hi + sl[2]), u * 0.14, UP * 0.65, f * 0.05)
      obox(K.solid, DARK, P(-sl[1], -hw - 0.03, hi + sl[2]), u * 0.14, UP * 0.65, f * 0.05)
    end
    obox(K.solid, DARK, P(hu + 0.03, 0.4, hi + 6), f * 0.5, UP * 0.8, u * 0.05)
    for k = 1, 7 do
      local y = hi + rnd(0.5, 8)
      obox(K.solid, (k % 2 == 0) and IVY or MOSS, P(hu - rnd(0.2, 2.2), hw + 0.06, y), u * rnd(0.5, 1.1), UP * rnd(0.6, 1.5), f * 0.07)
      obox(K.solid, (k % 2 == 0) and MOSS or IVY, P(hu + 0.06, hw - rnd(0.2, 2.6), y), f * rnd(0.5, 1.0), UP * rnd(0.6, 1.4), u * 0.07)
    end
    for k = 1, 9 do
      local a = rnd(0, math.pi * 2)
      local p = c + u * (math.cos(a) * (hu + rnd(1.2, 3))) + f * (math.sin(a) * (hw + rnd(1.2, 3)))
      if clear(p.x, p.z, 2) and land(p.x, p.z, 2) then
        local r = rnd(0.4, 1.0)
        rock(K.solid, G(p.x, p.z) + UP * (r * 0.2), r * 1.2, r * 0.8, r)
      end
    end
  end

  -- The holy well: a horseshoe of stones round dark water, a little stone hood over it with a cross on top, a white
  -- statue's niche, and the rag tree beside it hung with bright rags.
  local function holy_well()
    local c, u, f
    for _, tr in ipairs({{44, -1, 5.5}, {42, -1, 6}, {46, -1, 6}, {40, -1, 6}, {48, -1, 7}, {36, 1, 6}}) do
      c, u, f = plot(tr[1], tr[2] * east(tr[1]), tr[3], 3.5, 2.5)
      if c then break end
    end
    if not c then info("kerry: no room for the holy well"); return end
    local g0 = G(c.x, c.z)
    K.column(piece(K.solid, ST2), c.x, c.z, g0.y - 0.6, g0.y + 0.5, 1.5, 1.4, 10, ST2)
    K.column(piece(K.solid, DARK), c.x, c.z, g0.y + 0.501, g0.y + 0.54, 1.05, 1.05, 10, col(0.03, 0.12, 0.2))
    for k = 0, 6 do
      local a = math.pi * (0.15 + k * 0.28)
      local d = f * -math.sin(a) + u * math.cos(a)
      local p = g0 + d * 1.65
      rock(K.solid, v3(p.x, K.ground(p.x, p.z) + 0.35 + (k % 2) * 0.25, p.z), 0.5, 0.6 + (k % 3) * 0.2, 0.5)
    end
    -- The hood at the back: two slabs up, one across, a cross above.
    local b = g0 - f * 1.5
    for s = -1, 1, 2 do obox(K.solid, ST1, b + u * (s * 0.8) + UP * 0.9, u * 0.22, UP * 1.3, f * 0.5) end
    obox(K.solid, ST4, b + UP * 2.3, u * 1.2, UP * 0.16, f * 0.62)
    obox(K.solid, col(0.03, 0.03, 0.05), b - f * 0.3 + UP * 1.1, u * 0.56, UP * 1.0, f * 0.1)
    obox(K.solid, WHITE, b - f * 0.1 + UP * 1.0, u * 0.14, UP * 0.42, f * 0.1)
    obox(K.solid, BLUE, b - f * 0.08 + UP * 0.75, u * 0.17, UP * 0.2, f * 0.1)
    cross_(K.solid, b + UP * 2.46, f, 1.3, ST4)
    -- The rag tree: a bare thorn, bent from the wind.
    local tp = g0 + u * 2.6 - f * 0.4
    tp = G(tp.x, tp.z)
    local lean = flatten(u * 0.6 - f * 0.3)
    local k1 = tp + UP * 1.5 + lean * 0.3
    beam(K.solid, BARK, tp - UP * 0.3, k1, 0.13, 0.13)
    local rags = {RED, YEL, BLUE, WHITE, PINK, ORANGE, GREEN}
    for k = 1, 7 do
      local a = k * 0.9
      local tip = k1 + lean * rnd(0.5, 1.6) + v3(math.cos(a) * 0.8, rnd(0.4, 1.5), math.sin(a) * 0.8)
      beam(K.solid, BARK, k1 - UP * 0.05, tip, 0.045, 0.045)
      for q = 1, 2 do
        local hp = lerp(k1, tip, 0.45 + q * 0.25)
        obox(K.deco, rags[(k + q * 3) % #rags + 1], hp - UP * 0.2, u * 0.07, UP * 0.2, f * 0.015)
      end
    end
    -- A sign's white board by the road-side.
    local sp = g0 + f * 1.9 - u * 2.2
    if clear(sp.x, sp.z, 0.6) then
      sp = G(sp.x, sp.z)
      beam(K.solid, WOOD, sp - UP * 0.3, sp + UP * 1.3, 0.05, 0.05)
      obox(K.solid, WHITE, sp + UP * 1.5, u * 0.5, UP * 0.26, f * 0.03)
      obox(K.solid, GREEN, sp + UP * 1.5 + f * 0.035, u * 0.38, UP * 0.07, f * 0.012)
    end
  end

  -- ---------------------------------------------------------------- living things
  local FUCHSIA = function(w)
    local h = K.hash(math.floor(w.x * 37) + 0.5, math.floor(w.z * 37) + math.floor(w.y * 53))
    local ny = w.y / math.max(1e-6, length(w))
    if h < 0.3 and ny > -0.45 then return (h < 0.2) and FUCH or FUCH2 end
    if ny > 0.45 then return F_GREEN2 elseif ny > -0.3 then return F_GREEN else return F_LOW end
  end
  local function fuchsia(x, z, s)
    K.ball(piece(K.deco, "fuchsia"), v3(x, K.ground(x, z) + 0.65 * s, z), 1.15 * s, 1.1 * s, 1.15 * s, 8, 5, function() return rnd(0.82, 1.18) end, FUCHSIA)
  end
  local function sheep(x, z)
    local a = rnd(0, math.pi * 2)
    local d = v3(math.cos(a), 0, math.sin(a))
    local sd = v3(-d.z, 0, d.x)
    local s = rnd(0.95, 1.25)
    local g0 = G(x, z)
    local cen = g0 + UP * (0.66 * s)
    egg(K.deco, (rnd(0, 1) < 0.7) and WOOL or WOOL2, cen, d * (0.56 * s), 0.36 * s, 0.34 * s, 6)
    local graze = rnd(0, 1) < 0.5
    egg(K.deco, FACE, cen + d * (0.62 * s) + UP * ((graze and -0.3 or 0.2) * s), normalize(d + UP * (graze and -0.8 or -0.2)) * (0.2 * s), 0.11 * s, 0.12 * s, 5)
    for sx = -1, 1, 2 do
      for sz = -1, 1, 2 do
        local top = cen + d * (sx * 0.3 * s) + sd * (sz * 0.17 * s) - UP * (0.2 * s)
        beam(K.deco, FACE, top, v3(top.x, g0.y - 0.08, top.z), 0.045 * s, 0.045 * s)
      end
    end
    -- The farmer's mark: a daub of red or blue on the rump or the shoulder.
    local mark = (rnd(0, 1) < 0.55) and RED or BLUE
    obox(K.deco, mark, cen + d * ((rnd(0, 1) < 0.6 and -0.24 or 0.2) * s) + UP * (0.31 * s), d * (0.16 * s), UP * (0.04 * s), sd * (0.2 * s))
  end
  local function tree(x, z)
    local s = rnd(0.8, 1.4)
    local g0 = G(x, z)
    local lean = v3(-0.8, 0, 0.3) * s          -- bent away from the sea wind
    local k1 = g0 + UP * (2.4 * s) + lean * 0.5
    beam(K.solid, BARK, g0 - UP * 0.4, k1, 0.2 * s, 0.2 * s)
    local base = K.pick(CROWNS)
    local lump = function() return rnd(0.8, 1.2) end
    K.ball(piece(K.deco, base), k1 + UP * (1.2 * s) + lean * 0.5, 2.2 * s, 1.6 * s, 2.0 * s, 8, 5, lump, shaded(base))
    K.ball(piece(K.deco, base), k1 + UP * (1.0 * s) + lean * 1.9, 1.6 * s, 1.1 * s, 1.5 * s, 7, 4, lump, shaded(base))
  end

  -- ---------------------------------------------------------------- the Atlantic
  local crags = 0
  local function crag(root, x, z, y0, R, H, n, key, colour)
    for k = 1, n do
      -- (Each cone's underside at a depth of its own: none in another's plane.)
      crags = crags + 1
      y0 = y0 - 0.03 - (crags % 7) * 0.004
      local a = rnd(0, math.pi * 2)
      local off_ = (k == 1) and 0 or rnd(0.25, 0.75) * R
      local cx, cz = x + math.cos(a) * off_ * 1.5, z + math.sin(a) * off_ * 0.8
      local r = (k == 1) and R * 0.62 or R * rnd(0.3, 0.55)
      local h = (k == 1) and H or H * rnd(0.35, 0.8) * (1 - off_ / R * 0.4)
      local pts = {}
      for q = 0, 8 do
        local b = q / 9 * math.pi * 2
        local rr = r * rnd(0.75, 1.25)
        pts[#pts + 1] = v3(cx + math.cos(b) * rr, y0, cz + math.sin(b) * rr)
      end
      K.cone(piece(root, key), pts, v3(cx, y0, cz), v3(cx + rnd(-0.2, 0.2) * r, y0 + h, cz + rnd(-0.2, 0.2) * r), colour, SK1)
    end
  end
  local function atlantic()
    local CELL = 16
    for x = math.floor((coast(K.Z1 - 130) - 20) / CELL) * CELL, K.X1 + 240, CELL do
      for z = K.Z1 - 130, K.Z0 + 60, CELL do
        local mx, mz = x + CELL * 0.5, z + CELL * 0.5
        if mx > coast(mz) - 14 then
          local h = K.hash(mx, mz)
          local c = WATERS[1 + math.floor(h * 3.99)]
          local y = SEA + h * 0.12
          -- (A slab narrowing downwards: no side of it lies against its neighbour's.)
          local t, b = CELL * 0.5 - 0.02, CELL * 0.5 - 3
          K.hexa(piece(K.deco, c, c), v3(mx - b, y - 0.5, mz - b), v3(mx + b, y - 0.5, mz - b), v3(mx + b, y - 0.5, mz + b), v3(mx - b, y - 0.5, mz + b),
            v3(mx - t, y, mz - t), v3(mx + t, y, mz - t), v3(mx + t, y, mz + t), v3(mx - t, y, mz + t))
        end
      end
    end
    -- Surf along the cliffs' foot and white horses out at sea.
    for z = K.Z1 - 60, K.Z0 + 30, 7 do
      local x = coast(z) + 5.5 + K.hash(z, 3) * 2
      obox(K.deco, FOAM, v3(x, SEA + 0.2 + K.hash(z, 5) * 0.06, z), v3(1.2 + K.hash(z, 1) * 1.5, 0, 0), UP * 0.08, v3(0.4, 0, 3.3))
    end
    for k = 1, 70 do
      local z = rnd(K.Z1 - 100, K.Z0 + 40)
      local x = coast(z) + rnd(14, 200)
      obox(K.deco, FOAM, v3(x, SEA + 0.3 + k * 0.002, z), v3(rnd(0.5, 1.0), 0, 0.3), UP * 0.07, v3(-0.4, 0, rnd(2, 5)))
    end
    -- The Skelligs: Skellig Michael's twin peaks, green on its shoulders, and the Little Skellig white with gannets.
    local zc = (K.Z0 + K.Z1) * 0.5
    local mx, mz = coast(zc - 40) + 125, zc - 40
    local function michael(k) return (k % 4 == 0) and SK3 or ((k % 2 == 0) and SK2 or SK1) end
    crag(K.deco, mx, mz - 14, SEA - 0.5, 30, 58, 5, "skellig", michael)
    crag(K.deco, mx + 6, mz + 26, SEA - 0.5, 24, 44, 4, "skellig", michael)
    crag(K.deco, mx - 70, mz + 95, SEA - 0.5, 22, 30, 5, "little skellig", function(k) return (k % 3 == 0) and SK2 or GUANO end)
    -- Sea stacks off the cliffs.
    for k = 1, 9 do
      local z = K.Z1 + 20 + (K.Z0 - K.Z1 - 40) * (k - 0.5) / 9 + rnd(-8, 8)
      local x = coast(z) + rnd(14, 34)
      crag(K.deco, x, z, SEA - 0.5, rnd(3, 6), rnd(7, 16), 2, "stacks", function(q) return (q % 2 == 0) and SK2 or SK1 end)
    end
    -- Crags on the cliff's edge.
    for z = K.Z1 + 12, K.Z0 - 12, 13 do
      local x = coast(z) - 6 - K.hash(z, 9) * 3
      if land(x, z, 4) and off(x, z) > 26 then
        local r = 1.6 + K.hash(z, 2) * 2
        rock(K.deco, G(x, z) + UP * (r * 0.2), r * 1.2, r * 1.3, r * 1.1)
      end
    end
  end

  -- ---------------------------------------------------------------- the lot, placed
  village()
  church()
  round_tower()
  castle()
  holy_well()
  -- Two painted houses across the road from the street.
  for k, tr in ipairs({{60, -1, 11, PINK, TEAL}, {67, -1, 12, YEL, RED}}) do
    local c, u, f = plot(tr[1], tr[2] * east(tr[1]), tr[3], 3.4, 2.8)
    if c then
      house(K.solid, c, u, f, 3.4, 2.8, 5.3, {wall = tr[4], roof = SLATE, door = tr[5], chim = {-2.9, 2.9}, chimc = ST2, wins = {-2.1, 2.1}, floors = 2, rise = 2.2})
    end
  end
  local CO = {{4, 1, 11, true}, {7, -1, 12, false}, {16, -1, 11, true}, {19, 1, 12, false}, {31, 1, 10, true}, {37, -1, 12, true},
    {49, 1, 12, false}, {52, -1, 20, true}, {94, -1, 15, true}, {97, 1, 22, false}, {106, -1, 22, true}, {118, -1, 12, true},
    {121, 1, 12, false}, {127, -1, 13, true}, {72, -1, 26, true}, {12, -1, 30, false}, {42, -1, 30, true}, {112, 1, 26, true}}
  for k, co in ipairs(CO) do
    cottage(co[1], co[2] * east(co[1]), co[3], co[4], DOORS[(k - 1) % #DOORS + 1], k % 3 == 0)
  end

  -- Field walls: out from the road every so often, each way, with a wall along between them further back.
  local ends = {}
  for i = 5, N - 3, 8 do
    for sd = -1, 1, 2 do
      local w = right[i] * sd
      local a = rnd(-0.25, 0.25)
      local dir = flatten(w + K.along(i) * a)
      local p = pos[i] + w * (W[i] + EDGE + 5.2)
      local L = 0
      for step = 1, 26 do
        local q = p + dir * (L + 2.5)
        if not land(q.x, q.z, 6) or not clear(q.x, q.z, 4.6) then break end
        L = L + 2.5
      end
      if L > 7 then
        local q = p + dir * L
        drywall(p.x, p.z, q.x, q.z)
        local mid = p + dir * math.min(L, 27 + (i % 16))
        local prev = ends[sd]
        if prev and L > 24 and (mid - prev).x ^ 2 + (mid - prev).z ^ 2 < 45 * 45 then drywall(prev.x, prev.z, mid.x, mid.z) end
        ends[sd] = (L > 24) and mid or nil
      else
        ends[sd] = nil
      end
    end
  end
  -- Fuchsia hedges: runs of it along the road behind the crowd, both sides here and there.
  for st = 3, N - 9, 6 do
    local sd = ((st / 3) % 2 == 0) and 1 or -1
    if K.hash(st, 7) < 0.8 then
      for i = st, st + 4 do
        for h = 0, 1 do
          local p = lerp(pos[i], pos[i + 1], h * 0.5) + lerp(right[i], right[i + 1], h * 0.5) * (sd * (W[i] + EDGE + 6.2 + K.hash(i, h) * 0.5))
          if clear(p.x, p.z, 5) and land(p.x, p.z, 4) and free(p.x, p.z, -0.5) then fuchsia(p.x, p.z, 0.95 + K.hash(i, h + 4) * 0.35) end
        end
      end
    end
  end
  -- Outcrops, trees, and the sheep in their flocks.
  local n = 0
  for _ = 1, 400 do
    if n >= 34 then break end
    local x, z = K.spot(8)
    if x and land(x, z, 5) and free(x, z, 3) then
      n = n + 1
      outcrop(x, z, (n % 5 == 0) and rnd(1.8, 2.6) or rnd(0.7, 1.4))
    end
  end
  n = 0
  for _ = 1, 500 do
    if n >= 46 then break end
    local x, z = K.spot(11)
    if x and land(x, z, 8) and free(x, z, 3) then n = n + 1; tree(x, z) end
  end
  n = 0
  for _ = 1, 500 do
    if n >= 84 then break end
    local x, z = K.spot(9)
    if x and land(x, z, 8) and free(x, z, 4) then
      for _ = 1, math.floor(rnd(3, 7)) do
        local sx, sz = x + rnd(-5, 5), z + rnd(-5, 5)
        if clear(sx, sz, 6) and land(sx, sz, 6) and free(sx, sz, 1) then n = n + 1; sheep(sx, sz) end
      end
    end
  end
  atlantic()
  info(string.format("kerry: x %d..%d z %d..%d, start %d fin %d of %d", K.X0, K.X1, K.Z1, K.Z0, K.start, K.fin, N))
end

return T
