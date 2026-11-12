-- The cruise course's scenery kit (see THEME KITS in _course.lua): the road runs down the decks of a giant liner in
-- rough seas. The ground is teak then white deck out to the ship's side (T.paint, T.shape), and beyond it a dark-blue
-- swell with wave crests as high as the rail and spray bursting up the hull. Along the road: white superstructure
-- blocks with rows of portholes and balcony windows, lifeboats on davits, red-and-black funnels, the captain's bridge
-- over the road with its radar mast, railings with life rings, swimming pools sloshing over (each with a slide), hot
-- tubs, bars, parasols, and deckchairs and sunloungers sliding about (some toppled); seagulls over it all.
local T = {trees = 0}

local RAIL, SIDE = 22, 31            -- metres off the road's edge: the railing, and the ship's side (the sea beyond)

-- The swell: long waves (the valley's grid is 6 m, so none shorter than 30 m).
local function swell(x, z)
  return 2.2 * math.sin(x * 0.11 + z * 0.05) + 1.6 * math.sin(z * 0.16 - x * 0.07 + 1.3)
end

-- The deck is level with the road across the ship (a little above it); the sea lies 11 m under the road by the hull
-- and, further out, on the plane that best fits this course's road (so it does not step with the nearest sample).
function T.shape(x, z, off, y, road_y, TK)
  if off <= 8 then return nil end
  if off <= SIDE then
    local t = math.min(1, (off - 8) / 4)
    return y + (road_y + 1.2 - y) * t
  end
  local t = math.max(0, math.min(1, (off - SIDE) / 70))
  t = t * t * (3 - 2 * t)
  local near = road_y - 11
  local far = math.max(-14, -0.0747 * x + 0.1916 * z + 106)
  return near + (far - near) * t + swell(x, z) * math.max(0.35, math.min(1, (off - SIDE) / 12))
end

local PC
function T.paint(x, z, off, ink, TK)
  if not PC then
    PC = {teak = {TK.col(0.52, 0.32, 0.15), TK.col(0.58, 0.37, 0.18), TK.col(0.46, 0.28, 0.13)},
      white = TK.col(0.88, 0.89, 0.88), pale = TK.col(0.78, 0.82, 0.84), hull = TK.col(0.8, 0.81, 0.82),
      wash = TK.col(0.45, 0.68, 0.78), foam = TK.col(0.86, 0.93, 0.95), lt = TK.col(0.06, 0.26, 0.5),
      sea = TK.col(0.03, 0.14, 0.34), deep = TK.col(0.015, 0.07, 0.2)}
  end
  local h = TK.hash(x, z)
  if off < 13 then return PC.teak[1 + math.floor(h * 2.99)] end
  if off < SIDE - 5 then return (h < 0.2) and PC.pale or PC.white end
  if off < SIDE + 3 then return PC.hull end
  if off < SIDE + 9 then return (h < 0.5) and PC.foam or PC.wash end
  local s = swell(x, z)
  if s > 3.2 or h < 0.02 then return PC.foam end
  if s > 1.2 then return PC.lt end
  if s > -1.3 then return PC.sea end
  return PC.deep
end

function T.build(K)
  local col = K.col
  local UP = v3(0, 1, 0)
  local pi = math.pi
  local pos, right, W, N = K.pos, K.right, K.W, K.N
  local function rnd(a, b) return K.g:range(a, b) end
  local EDGE = K.WALL_T + 1          -- the road's own margin: nothing of the kit's nearer its edge

  local function tris(b)
    local n = 0
    for _, f in ipairs(b.fs) do n = n + #f - 2 end
    for _, q in ipairs(b.more or {}) do for _, f in ipairs(q.fs) do n = n + #f - 2 end end
    return n
  end
  local before = tris(K.solid) + tris(K.deco)

  local WHITE, GREY, NAVY = col(0.92, 0.93, 0.92), col(0.7, 0.73, 0.76), col(0.03, 0.08, 0.25)
  local GLASS, AQUA = col(0.05, 0.14, 0.24), col(0.35, 0.75, 0.85)
  local RED, BLACK, ORANGE = col(0.85, 0.06, 0.04), col(0.03, 0.03, 0.035), col(1.0, 0.4, 0.02)
  local YEL, BLUE, GREEN, PINK, TEAL = col(0.98, 0.8, 0.05), col(0.08, 0.3, 0.9), col(0.1, 0.62, 0.2), col(0.98, 0.4, 0.65), col(0.05, 0.6, 0.62)
  local CANVAS = {RED, YEL, BLUE, GREEN, PINK, TEAL, ORANGE}
  local TEAK, TEAK_DK, WOOD = col(0.55, 0.34, 0.16), col(0.36, 0.2, 0.09), col(0.7, 0.5, 0.28)
  local WATER, WATER_DK, FOAM, MIST = col(0.2, 0.7, 0.95), col(0.08, 0.45, 0.8), col(0.93, 0.97, 0.98), col(0.7, 0.86, 0.93)
  local SEA, SEA_LT, DEEP = col(0.03, 0.14, 0.34), col(0.06, 0.28, 0.52), col(0.015, 0.07, 0.2)
  local SMOKE, GULL_G, SKIN, STEEL = col(0.3, 0.3, 0.32), col(0.55, 0.58, 0.62), col(0.85, 0.6, 0.45), col(0.6, 0.63, 0.66)
  local LAMP_R, LAMP_G = col(1, 0.1, 0.05), col(0.1, 0.9, 0.2)

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
  -- A plank from p0 to p1: `sv` its half width (a vector), t its half thickness.
  local function plank(root, c, p0, p1, sv, t)
    local d = (p1 - p0) * 0.5
    obox(root, c, (p0 + p1) * 0.5, sv, d, normalize(cross(d, sv)) * t)
  end
  -- A round tube through pts (rings square to its whole run), radius rr[j] at each, n-sided; c a colour, or
  -- colour(j, k) with a key for its piece. `squash` flattens it the second way.
  local function tube(root, c, pts, rr, n, hint, squash, key)
    local fn = type(c) == "function"
    local q = piece(root, key or c)
    local e1, e2 = perp(normalize(pts[#pts] - pts[1]), hint)
    local rings = {}
    for j, p in ipairs(pts) do
      local ring = {}
      for k = 0, n - 1 do
        local a = (k + 0.5) / n * pi * 2
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
  local function lump() return rnd(0.8, 1.2) end

  -- ---------------------------------------------------------------- where
  local function off(x, z) local _, d = K.ground_d(x, z); return d - K.HW end   -- metres off the road's edge
  local function clear(x, z, m) return off(x, z) > EDGE + (m or 0.4) end
  local function inside(x, z, m) return x > K.X0 + m and x < K.X1 - m and z > K.Z1 + m and z < K.Z0 - m end
  -- What is built already, kept by cell (in every cell a thing up to 10 m across could ask from).
  local grid, CELL = {}, 16
  local function free(x, z, r)
    local list = grid[math.floor(x / CELL) * 4096 + math.floor(z / CELL)]
    if not list then return true end
    for _, e in ipairs(list) do
      local dx, dz = x - e[1], z - e[2]
      local rr = e[3] + r
      if dx * dx + dz * dz < rr * rr then return false end
    end
    return true
  end
  local function take(x, z, r)
    local e = {x, z, r}
    local m = r + 10
    for gx = math.floor((x - m) / CELL), math.floor((x + m) / CELL) do
      for gz = math.floor((z - m) / CELL), math.floor((z + m) / CELL) do
        local key = gx * 4096 + gz
        grid[key] = grid[key] or {}
        grid[key][#grid[key] + 1] = e
      end
    end
  end
  -- A plot on the deck beside the road near sample i: a along the road by b out from it (half sizes), gap off the
  -- margin; inside the railing.
  local function site(i, side, a, b, gap)
    for _, di in ipairs({0, 2, -2, 4, -4, 6, -6}) do
      for _, sd in ipairs({side, -side}) do
        local j = math.max(3, math.min(N - 2, i + di))
        local w, u = right[j] * sd, K.along(j)
        local c = pos[j] + w * (W[j] + EDGE + gap + b)
        local ok = true
        for _, m in ipairs({{-1, -1}, {0, -1}, {1, -1}, {-1, 0}, {1, 0}, {-1, 1}, {0, 1}, {1, 1}, {-0.5, -1}, {0.5, -1}, {0, 0}}) do
          local p = c + u * (m[1] * a) + w * (m[2] * b)
          local o = off(p.x, p.z)
          if o < EDGE + gap * 0.5 or o > RAIL - 1 or not free(p.x, p.z, 0.5) then ok = false; break end
        end
        if ok then
          for du = -a, a + 0.01, a / 2 do take(c.x + u.x * du, c.z + u.z * du, b * 1.1) end
          local s = {u = u, w = w, a = a, b = b, i = j, c = v3(c.x, K.ground(c.x, c.z), c.z)}
          function s.at(du, dw)
            local p = c + u * du + w * dw
            return v3(p.x, K.ground(p.x, p.z), p.z)
          end
          return s
        end
      end
    end
    return nil
  end
  local made = {}
  local function count(k) made[k] = (made[k] or 0) + 1 end

  -- ---------------------------------------------------------------- small things
  local function port(cen, out) limb(K.deco, NAVY, cen - out * 0.05, cen + out * 0.07, 0.42, 0.42, 6) end
  local function lifering(cen, out)
    limb(K.deco, ORANGE, cen - out * 0.03, cen + out * 0.12, 0.5, 0.5, 8)
    limb(K.deco, WHITE, cen - out * 0.04, cen + out * 0.15, 0.24, 0.24, 6)
  end
  local function balcony(cen, u, w)
    obox(K.deco, GLASS, cen - w * 0.04, u * 0.8, UP * 0.85, w * 0.05)
    obox(K.deco, GREY, cen - w * 0.45 - UP * 0.95, u * 0.95, UP * 0.06, w * 0.42)
    obox(K.deco, AQUA, cen - w * 0.85 - UP * 0.5, u * 0.95, UP * 0.4, w * 0.03)
  end
  -- A lifeboat hanging at c beside a wall w * 0.95 behind it: orange hull, white canopy, two davits.
  local function lifeboat(c, u, w)
    egg(K.deco, ORANGE, c, u * 2.4, 0.9, 0.75, 7)
    obox(K.deco, WHITE, c + UP * 0.5, u * 1.5, UP * 0.3, w * 0.62)
    obox(K.deco, NAVY, c + UP * 0.5, u * 1.2, UP * 0.14, w * 0.65)
    for sd = -1, 1, 2 do
      local foot = c + u * (sd * 1.7) + w * 0.8
      beam(K.deco, GREY, foot - UP * 0.9, foot + UP * 1.9, 0.1, 0.1)
      beam(K.deco, GREY, foot + UP * 1.8 + w * 0.1, foot + UP * 1.8 - w * 0.95, 0.09, 0.09)
      beam(K.deco, BLACK, foot + UP * 1.75 - w * 0.8, foot + UP * 0.5 - w * 0.8, 0.03, 0.03)
    end
  end
  -- A funnel standing at `base`, r across, raked back up the road: red, a white band, red, a black top; smoke.
  local nfun = 0
  local function funnel(base, u, w, r, h)
    nfun = nfun + 1
    local BAND = {RED, WHITE, RED, BLACK}
    local rings, n = {}, 12
    for j, t in ipairs({0, 0.52, 0.62, 0.74, 1}) do
      local c = base + UP * (h * t) - u * (0.2 * h * t)
      local f = 1 - 0.2 * t
      rings[j] = {}
      for k = 0, n - 1 do
        local a = (k + 0.5) / n * 2 * pi
        rings[j][k + 1] = c + u * (math.cos(a) * r * 1.3 * f) + w * (math.sin(a) * r * f)
      end
    end
    K.prism(piece(K.solid, "funnel" .. nfun), rings, function(j) return BAND[j] end, RED, BLACK)
    local top = base + UP * h - u * (0.2 * h)
    for sd = -1, 1, 2 do
      local p = top + u * (sd * r * 0.45)
      limb(K.deco, BLACK, p - UP * 0.5, p + UP * 1.4, r * 0.28, r * 0.24, 7)
    end
    for k = 1, 4 do
      local c = top + UP * (1.5 + k * 2.2) - u * (k * k * 1.1) + w * rnd(-1, 1)
      local s = r * (0.5 + k * 0.17)
      K.ball(piece(K.deco, "smoke"), c, s, s * 0.8, s, 7, 4, lump, K.shaded(SMOKE))
    end
  end
  -- A radar mast: a pole with stays, a yard, a dome, a scanner bar and a lamp.
  local function mast(base, u, w, h)
    beam(K.deco, WHITE, base - UP * 0.3, base + UP * h, 0.14, 0.14)
    for sd = -1, 1, 2 do
      beam(K.deco, GREY, base + w * (sd * 1.5), base + UP * (h * 0.66), 0.05, 0.05)
    end
    beam(K.deco, WHITE, base + UP * (h * 0.7) - w * 2, base + UP * (h * 0.7) + w * 2, 0.07, 0.07)
    sph(K.deco, WHITE, base + UP * (h * 0.52) + u * 0.5, 0.6, 6)
    local a = rnd(0, pi)
    local d = u * math.cos(a) + w * math.sin(a)
    beam(K.deco, GREY, base + UP * (h + 0.2) - d * 1.5, base + UP * (h + 0.2) + d * 1.5, 0.22, 0.09)
    sph(K.deco, LAMP_R, base + UP * (h * 0.7 + 0.25) - w * 1.9, 0.16, 4)
    sph(K.deco, LAMP_G, base + UP * (h * 0.7 + 0.25) + w * 1.9, 0.16, 4)
  end

  -- ---------------------------------------------------------------- superstructure
  -- A white block: a half-length, b half-depth, h high over the deck's high end. o: boat (lifeboats on its road
  -- side), balcony (its top row balcony windows), tier (a deckhouse on top), funnel, mast.
  local function block(i, side, a, b, h, o)
    o = o or {}
    local m = o.boat and 1.9 or 0
    local s = site(i, side, a, b + m / 2, 0.9)
    if not s then return nil end
    local u, w = s.u, s.w
    local mid = v3(s.c.x, 0, s.c.z) + w * (m / 2)
    local lo, hi = math.huge, -math.huge
    for _, e in ipairs({{-1, -1}, {1, -1}, {1, 1}, {-1, 1}}) do
      local y = s.at(e[1] * a, e[2] * b + m / 2).y
      lo, hi = math.min(lo, y), math.max(hi, y)
    end
    lo = lo - 0.8
    local top = hi + h
    obox(K.solid, WHITE, mid + UP * ((lo + top) / 2), u * a, UP * ((top - lo) / 2), w * b)
    obox(K.deco, NAVY, mid + UP * (top - 0.5), u * (a + 0.05), UP * 0.14, w * (b + 0.05))
    obox(K.deco, GREY, mid + UP * (top + 0.1), u * (a + 0.35), UP * 0.1, w * (b + 0.35))
    local function F(du, y) return mid + u * du - w * b + UP * y end
    local ncol = math.floor((2 * a - 1.6) / 2.3)
    for k = 0, ncol - 1 do
      local du = (k - (ncol - 1) / 2) * 2.3
      local g = s.at(du, -b + m / 2).y
      local row = 0
      for y = top - 1.75, g + 1.0, -2.5 do
        if row == 0 and o.balcony then balcony(F(du, y), u, w)
        elseif not (row == 0 and o.boat) then port(F(du, y), w * -1) end
        row = row + 1
      end
    end
    -- (its uphill end, which the karts come down at)
    for _, dw in ipairs({-b * 0.45, b * 0.45}) do
      local e = mid - u * a + w * dw
      local g = K.ground(e.x, e.z)
      for y = top - 1.75, g + 1.0, -2.5 do port(e + UP * y, u * -1) end
    end
    local e = mid - u * a
    lifering(v3(e.x, K.ground(e.x, e.z) + 1.5, e.z), u * -1)
    if o.boat then
      for _, du in ipairs({-a * 0.5, a * 0.5}) do lifeboat(F(du, top - 1.7) - w * 0.95, u, w) end
    end
    local roof = top + 0.2
    if o.tier then
      obox(K.solid, WHITE, mid + UP * (top + 1.6), u * (a * 0.62), UP * 1.45, w * (b * 0.7))
      obox(K.deco, GLASS, mid + UP * (top + 1.9), u * (a * 0.62 - 0.4), UP * 0.55, w * (b * 0.7 + 0.05))
      obox(K.deco, GREY, mid + UP * (top + 3.15), u * (a * 0.62 + 0.3), UP * 0.1, w * (b * 0.7 + 0.3))
      roof = top + 3.25
    end
    if o.funnel then funnel(mid + UP * (roof - 0.3), u, w, o.funnel, o.funnel * 4.2) end
    if o.mast then mast(mid + UP * roof + u * (a * 0.3), u, w, o.mast) end
    count(o.funnel and "funnels" or "blocks")
    return s
  end

  -- The captain's bridge: a tower either side of the road and the wheelhouse across it, its wings out past them, a
  -- band of windows both ways, the radar mast on its roof.
  local function bridge(i)
    local c, r, t = pos[i], right[i], K.along(i)
    local ytop = c.y
    for j = math.max(1, i - 3), math.min(N, i + 3) do ytop = math.max(ytop, pos[j].y) end
    local y0 = ytop + 6.9
    local half, tw, td = W[i] + EDGE + 0.6, 2.3, 2.5
    for sd = -1, 1, 2 do
      local p = c + r * (sd * (half + tw))
      local flat = v3(p.x, 0, p.z)
      local gy = K.lowest(flat, t, r, td, tw) - 0.8
      obox(K.solid, WHITE, flat + UP * ((gy + y0) / 2), r * tw, UP * ((y0 - gy) / 2 + 0.2), t * td)
      obox(K.deco, NAVY, flat + UP * (c.y + 2.9), r * (tw + 0.05), UP * 0.14, t * (td + 0.05))
      for _, dr in ipairs({-0.95, 0.95}) do
        for _, y in ipairs({c.y + 1.9, c.y + 4.4}) do
          port(flat + r * dr - t * td + UP * y, t * -1)
        end
      end
      lifering(flat - r * (sd * tw) + UP * (c.y + 1.7), r * -sd)
      for du = -td, td, td do take(p.x + t.x * du, p.z + t.z * du, tw * 1.2) end
    end
    local span = half + tw * 2 + 4
    local bc = v3(c.x, y0 + 1.7, c.z)
    obox(K.deco, WHITE, bc, r * span, UP * 1.7, t * 2.7)
    obox(K.deco, NAVY, bc - UP * 0.75, r * (span + 0.04), UP * 0.16, t * 2.74)
    obox(K.deco, GREY, bc + UP * 1.82, r * (span + 0.4), UP * 0.12, t * 3.1)
    for sd = -1, 1, 2 do
      obox(K.deco, GLASS, bc + UP * 0.45 + t * (sd * 2.7), r * (span - 0.5), UP * 0.62, t * 0.06)
      for a = -span + 0.5, span - 0.49, (span * 2 - 1) / 14 do
        obox(K.deco, WHITE, bc + UP * 0.45 + t * (sd * 2.7) + r * a, r * 0.08, UP * 0.66, t * 0.1)
      end
      sph(K.deco, (sd < 0) and LAMP_R or LAMP_G, bc + UP * 2.25 + r * (sd * (span - 0.5)), 0.4, 5)
    end
    obox(K.deco, WHITE, bc + UP * 2.9, r * 3.2, UP * 1.0, t * 1.9)
    obox(K.deco, GLASS, bc + UP * 3.1, r * 2.8, UP * 0.4, t * 1.95)
    mast(bc + UP * 3.9, t, r, 8)
    count("bridge")
  end

  -- ---------------------------------------------------------------- pool, hot tub, bar
  -- A raised pool, its water piled up at the downhill end and slopping over; a slide winding down from a tower.
  local function pool(i, side)
    local s = site(i, side, 8, 5.5, 1.0)
    if not s then return end
    local u, w = s.u, s.w
    local a, b = 7.6, 3.6
    local mid = v3(s.c.x, 0, s.c.z) - w * 1.5
    local lo, hi = math.huge, -math.huge
    for _, e in ipairs({{-1, -1}, {1, -1}, {1, 1}, {-1, 1}}) do
      local y = s.at(e[1] * a, e[2] * b - 1.5).y
      lo, hi = math.min(lo, y), math.max(hi, y)
    end
    local top = hi + 1.0
    obox(K.solid, WHITE, mid + UP * ((lo - 0.8 + top) / 2), u * a, UP * ((top - lo + 0.8) / 2), w * b)
    obox(K.deco, AQUA, mid + UP * (top - 0.5), u * (a + 0.04), UP * 0.2, w * (b + 0.04))
    local function Pt(du, dw, y) return mid + u * du + w * dw + UP * (top + y) end
    local ia, ib = a - 0.5, b - 0.5
    K.hexa(piece(K.deco, WATER, WATER), Pt(-ia, -ib, -0.6), Pt(ia, -ib, -0.6), Pt(ia, ib, -0.6), Pt(-ia, ib, -0.6),
      Pt(-ia, -ib, -0.28), Pt(ia, -ib, 0.75), Pt(ia, ib, 0.6), Pt(-ia, ib, -0.2))
    -- the slop: a lip of water over the downhill rim, foam on it, and a sheet running off down the deck
    plank(K.deco, WATER_DK, Pt(ia - 2.2, 0, 0.5), Pt(a + 0.5, 0, 1.25), w * (ib - 0.3), 0.3)
    for k = -2, 2 do
      local r = rnd(0.5, 0.85)
      K.ball(piece(K.deco, "foam"), Pt(a + 0.3 + rnd(-0.3, 0.4), k * ib * 0.42, 1.2 + rnd(-0.2, 0.3)), r, r * 0.8, r, 6, 4, lump, K.flat(FOAM))
    end
    local p0, p1 = s.at(a + 0.3, -1.5), s.at(a + 4.2, -1.5)
    if clear(p1.x, p1.z, 3) then plank(K.deco, WATER, p0 + UP * 0.12, p1 + UP * 0.12, w * 2.6, 0.05) end
    -- the slide
    local tc = mid + w * (b + 0.3) - u * 2.5
    local ph = top + 6.2
    for _, e in ipairs({{-1, -1}, {1, -1}, {1, 1}, {-1, 1}}) do
      local q = tc + u * (e[1] * 0.9) + w * (e[2] * 0.9)
      beam(K.solid, WHITE, q + UP * (lo - 0.5), q + UP * (ph + 2.3), 0.1, 0.1)
    end
    obox(K.deco, TEAK, tc + UP * ph, u * 1.2, UP * 0.1, w * 1.2)
    tube(K.deco, function(_, k) return (k % 2 == 0) and RED or WHITE end, {tc + UP * (ph + 2.3), tc + UP * (ph + 3.5)}, {1.9, 0.05}, 8, nil, 1, "slidetop")
    for k = 1, 5 do obox(K.deco, STEEL, tc + w * 1.25 + UP * (lo + (ph - lo) * k / 6), u * 0.45, UP * 0.05, w * 0.08) end
    local prev
    for k = 0, 13 do
      local an = k * 0.75
      local rr = 3.0
      local q = tc + (u * math.cos(an) - w * math.sin(an)) * rr + UP * (ph + 0.6 - (ph - top - 0.3) * k / 13) - w * (k / 13 * 1.2)
      if prev then limb(K.deco, (k % 2 == 0) and YEL or PINK, prev, q + (q - prev) * 0.06, 0.62, 0.62, 6) end
      prev = q
    end
    count("pools")
  end

  local function hottub(i, side)
    local s = site(i, side, 2.5, 2.5, 0.8)
    if not s then return end
    local x, z = s.c.x, s.c.z
    local lo = K.lowest(v3(x, 0, z), s.u, s.w, 2.1, 2.1)
    local top = s.at(-2, 0).y + 0.95
    K.column(piece(K.solid, TEAK), x, z, lo - 0.6, top, 2.1, 2.1, 10, TEAK)
    K.column(piece(K.deco, WHITE), x, z, top - 0.3, top + 0.06, 2.2, 2.2, 10, WHITE, 0.2)
    K.column(piece(K.deco, TEAL), x, z, top - 0.2, top + 0.12, 1.75, 1.75, 10, TEAL, 0.1)
    for k = 1, 8 do
      local an, r = rnd(0, 6.28), rnd(0.2, 1.4)
      sph(K.deco, FOAM, v3(x + math.cos(an) * r, top + 0.12, z + math.sin(an) * r), rnd(0.16, 0.3), 4)
    end
    for k = 0, 1 do
      local an = k * 2.6 + rnd(0, 1)
      local p = v3(x + math.cos(an) * 1.2, top + 0.45, z + math.sin(an) * 1.2)
      sph(K.deco, SKIN, p, 0.26, 5)
      obox(K.deco, CANVAS[k + 2], p + UP * 0.24, v3(0.34, 0, 0), UP * 0.04, v3(0, 0, 0.34))
    end
    count("hot tubs")
  end

  local function bar(i, side)
    local s = site(i, side, 3.8, 2.6, 0.8)
    if not s then return end
    local u, w = s.u, s.w
    local mid = v3(s.c.x, 0, s.c.z)
    local lo = K.lowest(mid, u, w, 3.5, 2.3)
    local fy = s.at(-3.5, 0).y + 0.2
    local function Pt(du, dw, y) return mid + u * du + w * dw + UP * (fy + y) end
    obox(K.solid, TEAK, mid + UP * ((lo - 0.6 + fy) / 2), u * 3.5, UP * ((fy - lo + 0.6) / 2), w * 2.3)
    obox(K.solid, TEAK_DK, Pt(0, -1.2, 0.55), u * 3.0, UP * 0.55, w * 0.3)
    obox(K.deco, WHITE, Pt(0, -1.25, 1.14), u * 3.15, UP * 0.05, w * 0.45)
    obox(K.solid, WHITE, Pt(0, 1.9, 1.5), u * 3.1, UP * 1.5, w * 0.12)
    obox(K.deco, TEAK_DK, Pt(0, 1.6, 1.5), u * 2.8, UP * 0.04, w * 0.2)
    for k = 0, 9 do
      local p = Pt(-2.5 + k * 0.55, 1.6, 0)
      local c = CANVAS[k % #CANVAS + 1]
      K.column(piece(K.deco, c), p.x, p.z, fy + 1.54, fy + 2.1, 0.11, 0.05, 5, c)
    end
    for sd = -1, 1, 2 do
      beam(K.solid, WHITE, Pt(sd * 3.2, -1.9, -0.2), Pt(sd * 3.2, -1.9, 2.75), 0.08, 0.08)
    end
    for k = -4, 3 do
      plank(K.deco, (k % 2 == 0) and RED or WHITE, Pt((k + 0.5) * 0.85, 2.05, 3.25), Pt((k + 0.5) * 0.85, -2.3, 2.7), u * 0.42, 0.04)
    end
    for k = -1, 2 do
      local p = Pt(-0.9 + k * 1.3, -2.0, 0)
      K.column(piece(K.deco, STEEL), p.x, p.z, fy - 0.1, fy + 0.7, 0.06, 0.06, 5, STEEL)
      K.column(piece(K.deco, RED), p.x, p.z, fy + 0.7, fy + 0.82, 0.24, 0.24, 7, RED)
    end
    -- BAR, on a board over the back wall, read from the road.
    local rt = normalize(cross(w, UP))
    local bc = Pt(0, 1.9, 3.95)
    obox(K.deco, NAVY, bc, u * 2.0, UP * 0.65, w * 0.1)
    local function L(x, y) return bc - w * 0.16 + rt * x + UP * y end
    local function stroke(x0, y0, x1, y1) beam(K.deco, YEL, L(x0, y0), L(x1, y1), 0.075, 0.05, w) end
    stroke(-1.5, -0.42, -1.5, 0.42); stroke(-1.5, 0.4, -0.95, 0.4); stroke(-1.5, 0, -0.95, 0); stroke(-1.5, -0.4, -0.95, -0.4)
    stroke(-0.9, 0.05, -0.9, 0.38); stroke(-0.88, -0.38, -0.88, -0.05)
    stroke(-0.4, -0.42, 0, 0.42); stroke(0.01, 0.42, 0.4, -0.42); stroke(-0.22, -0.1, 0.22, -0.1)
    stroke(0.9, -0.42, 0.9, 0.42); stroke(0.9, 0.4, 1.45, 0.4); stroke(0.9, 0, 1.45, 0); stroke(1.5, 0.05, 1.5, 0.38)
    stroke(1.05, -0.03, 1.5, -0.42)
    lifering(Pt(-3.5, 0, 0.9) - u * 0.02, u * -1)
    count("bars")
  end

  -- ---------------------------------------------------------------- deck furniture
  -- A frame at p turned by yaw: upright (0), on its side (1) or tipped over backwards (2). P(a, h, b) and its side.
  local function frame(p, yaw, mode, sc)
    local f = v3(math.cos(yaw), 0, math.sin(yaw))
    local s, up = v3(-f.z, 0, f.x), UP
    if mode == 1 then s, up = UP, v3(f.z, 0, -f.x); p = p + UP * (0.36 * sc)
    elseif mode == 2 then up = f * -1; f = UP; p = p + UP * (0.66 * sc) end
    return function(a, h, b) return p + f * (a * sc) + up * (h * sc) + s * (b * sc) end, s
  end
  local function deckchair(p, yaw, mode, c)
    local sc = 1.3
    local P, s = frame(p, yaw, mode, sc)
    plank(K.deco, c, P(0.5, 0.38, 0), P(-0.05, 0.16, 0), s * (0.27 * sc), 0.02)
    plank(K.deco, c, P(-0.07, 0.17, 0), P(-0.6, 0.95, 0), s * (0.27 * sc), 0.02)
    for _, b in ipairs({-0.3, 0.3}) do
      plank(K.deco, WOOD, P(0.55, 0.02, b), P(-0.63, 1.0, b), s * 0.03, 0.035)
      plank(K.deco, WOOD, P(-0.5, 0.02, b), P(0.52, 0.42, b), s * 0.03, 0.035)
    end
  end
  local function lounger(p, yaw, mode, c)
    local sc = 1.3
    local P, s = frame(p, yaw, mode, sc)
    plank(K.deco, WHITE, P(-0.95, 0.3, 0), P(0.95, 0.3, 0), s * (0.33 * sc), 0.05)
    plank(K.deco, WHITE, P(-0.7, 0.0, 0), P(-0.7, 0.27, 0), s * (0.3 * sc), 0.05)
    plank(K.deco, WHITE, P(0.7, 0.0, 0), P(0.7, 0.27, 0), s * (0.3 * sc), 0.05)
    plank(K.deco, c, P(-0.2, 0.37, 0), P(0.93, 0.37, 0), s * (0.3 * sc), 0.04)
    plank(K.deco, c, P(-0.22, 0.38, 0), P(-0.9, 0.82, 0), s * (0.3 * sc), 0.04)
  end
  local npar = 0
  local function parasol(p, toppled)
    npar = npar + 1
    local c = CANVAS[npar % #CANVAS + 1]
    local up = UP
    if toppled then
      local an = rnd(0, 6.28)
      up = normalize(v3(math.cos(an), 0.22, math.sin(an)))
      p = p + UP * 1.2
    end
    limb(K.deco, WHITE, p - up * 0.2, p + up * 2.7, 0.05, 0.05, 4)
    tube(K.deco, function(_, k) return (k % 2 == 0) and c or WHITE end, {p + up * 2.25, p + up * 2.85}, {1.7, 0.04}, 8, nil, 1, "parasol" .. (npar % 7))
  end

  local function gull(p, yaw, sc, perched)
    local f = v3(math.cos(yaw), 0, math.sin(yaw))
    local s = v3(-f.z, 0, f.x)
    limb(K.deco, WHITE, p - f * (0.5 * sc), p + f * (0.2 * sc), 0.05 * sc, 0.17 * sc, 5)
    sph(K.deco, WHITE, p + f * (0.33 * sc) + UP * (0.07 * sc), 0.13 * sc, 5)
    limb(K.deco, YEL, p + f * (0.42 * sc) + UP * (0.06 * sc), p + f * (0.68 * sc) + UP * (0.02 * sc), 0.05 * sc, 0.015 * sc, 4)
    if perched then
      plank(K.deco, GULL_G, p - f * (0.5 * sc) + UP * (0.1 * sc), p + f * (0.1 * sc) + UP * (0.18 * sc), s * (0.14 * sc), 0.03 * sc)
      return
    end
    local flap = rnd(0.1, 0.6)
    for sd = -1, 1, 2 do
      local a0 = p + s * (sd * 0.1 * sc) + UP * (0.08 * sc)
      local a1 = p + s * (sd * 0.8 * sc) + UP * ((0.08 + flap) * sc)
      local a2 = p + s * (sd * 1.6 * sc) + UP * ((0.08 + flap * 0.35) * sc) - f * (0.18 * sc)
      plank(K.deco, WHITE, a0, a1, f * (0.2 * sc), 0.025 * sc)
      plank(K.deco, GULL_G, a1 - (a1 - a0) * 0.04, a2, f * (0.15 * sc), 0.025 * sc)
    end
  end

  -- ---------------------------------------------------------------- the sea's own
  -- A breaking wave: a ridge `len` long and h high rolling the way `turn` points, a white crest curling over.
  local nwave = 0
  local function wave(x, z, len, h, turn, foam)
    nwave = nwave + 1
    local f = v3(math.cos(turn), 0, math.sin(turn))
    local s = v3(-f.z, 0, f.x)
    local rings, n = {}, 6
    local crest
    for j = 0, n do
      local t = j / n * 2 - 1
      local hh = h * math.max(0.1, (1 - t * t) ^ 0.7)
      local c = v3(x, 0, z) + s * (t * len / 2) + f * (math.sin(j * 1.9 + x) * 0.05 * len)
      local y = K.ground(c.x, c.z) - 1.5
      c = v3(c.x, y, c.z)
      rings[j + 1] = {c - f * (1.8 * hh), c + f * (0.25 * hh) + UP * (hh + 1.5), c + f * (0.8 * hh) + UP * (hh * 0.7 + 1.5), c + f * (0.55 * hh)}
      if j == n / 2 then crest = rings[j + 1][2] end
    end
    K.prism(piece(K.deco, "wave" .. (nwave % 8)), rings, function(j, k)
      if k == 2 then return FOAM end
      if k == 1 then return (j % 2 == 0) and SEA_LT or SEA end
      return DEEP
    end, SEA, SEA)
    if foam then
      for k = -1, 1 do
        local r = h * rnd(0.12, 0.2)
        K.ball(piece(K.deco, "foam"), crest + s * (k * len * 0.2) + f * (h * 0.3) - UP * (math.abs(k) * h * 0.22), r * 1.5, r, r * 1.5, 6, 4, lump, K.flat(FOAM))
      end
    end
  end
  -- Spray bursting up at (x, z) from y: white spikes and lumps.
  local nspray = 0
  local function spray(x, z, y, sc)
    nspray = nspray + 1
    local q = piece(K.deco, "spray" .. (nspray % 5))
    for k = 1, 6 do
      local an = rnd(0, 6.283)
      local d = rnd(0, 1.8) * sc
      local c = v3(x + math.cos(an) * d, y, z + math.sin(an) * d)
      local tip = c + UP * (rnd(5, 11) * sc) + v3(math.cos(an), 0, math.sin(an)) * (rnd(0.3, 1.6) * sc)
      K.cone(q, K.ring(c, 0.8 * sc, 0.8 * sc, 5, an), c, tip, function(kk) return (kk % 2 == 0) and FOAM or MIST end, MIST)
    end
    for k = 1, 3 do
      local r = rnd(0.4, 0.8) * sc
      K.ball(q, v3(x + rnd(-2, 2) * sc, y + rnd(4, 9) * sc, z + rnd(-2, 2) * sc), r, r, r, 5, 3, lump, K.flat(FOAM))
    end
  end

  -- ================================================================ the ship, laid out down the road
  bridge(math.min(N - 3, math.max(K.start + 22, 36)))
  local B, BT, BB = {}, {tier = true, balcony = true}, {boat = true}
  local plan = {
    {19, -1, block, 6.5, 3.6, 11, BB}, {20, 1, block, 6.5, 3.6, 10, {balcony = true, mast = 6}},
    {48, 1, block, 7.5, 5.4, 7, {funnel = 4.4}}, {50, -1, pool},
    {62, 1, bar}, {66, -1, block, 7.5, 3.8, 12, BB},
    {72, 1, hottub}, {80, 1, block, 7, 4, 9.5, BT},
    {84, -1, block, 7.5, 5.4, 7, {funnel = 4.6}}, {96, 1, pool},
    {100, -1, hottub}, {108, -1, bar},
    {112, 1, block, 7.5, 3.8, 12, BB}, {122, -1, block, 7, 4, 9.5, BT},
    {128, 1, block, 7.5, 5.4, 7, {funnel = 4.4}}, {138, -1, block, 6.5, 3.8, 11, BB},
    {142, 1, hottub}, {150, 1, bar},
    {156, -1, pool}, {162, 1, block, 7, 4, 10, {tier = true, balcony = true, mast = 6}},
    {172, -1, block, 7.5, 5.4, 7, {funnel = 4.6}}, {176, 1, block, 7.5, 3.8, 12, BB},
    {186, -1, hottub}, {190, 1, pool},
    {194, -1, bar}, {204, -1, block, 7, 4, 9.5, BT},
    {208, 1, block, 7.5, 5.4, 7, {funnel = 4.4}}, {218, -1, block, 7.5, 3.8, 12, BB},
    {222, 1, hottub}, {238, 1, block, 6.5, 3.8, 8, BT}, {240, -1, block, 7.5, 5.4, 7, {funnel = 4.4}},
    {8, 1, block, 6, 3.6, 7, B}, {6, -1, block, 7, 5, 6.5, {funnel = 4}},
  }
  for _, e in ipairs(plan) do
    if e[3] == block then block(e[1], e[2], e[4], e[5], e[6], e[7]) else e[3](e[1], e[2]) end
  end
  -- (more deckhouses wherever a gap is left)
  local FILL = {BT, BB, {balcony = true}, {tier = true, mast = 6}}
  local k = 0
  for i = 28, N - 10, 17 do
    k = k + 1
    block(i, (k % 2 == 0) and 1 or -1, 6, 3.6, 8 + (k % 3) * 1.5, FILL[k % #FILL + 1])
  end

  -- The railing along each side of the ship: posts, a top rail and a mid rail; a life ring every so often, a gull
  -- perched here and there.
  local rail_pts = {}
  for side = -1, 1, 2 do
    local prev
    local k = 0
    for i = 1, N, 2 do
      local p = pos[i] + right[i] * (side * (W[i] + RAIL))
      local here
      if off(p.x, p.z) > RAIL - 1.2 and inside(p.x, p.z, 2) then
        k = k + 1
        local base = v3(p.x, K.ground(p.x, p.z), p.z)
        here = {base = base, top = base + UP * 1.25}
        beam(K.deco, WHITE, base - UP * 0.3, here.top, 0.06, 0.06)
        rail_pts[#rail_pts + 1] = {p = base, out = right[i] * side, i = i}
        if k % 6 == 3 then lifering(base + UP * 0.72 - right[i] * (side * 0.1), right[i] * -side) end
        if k % 9 == 5 then gull(here.top + UP * 0.22, rnd(0, 6.28), 1.5, true) end
      end
      if here and prev then
        beam(K.deco, WHITE, prev.top, here.top, 0.05, 0.05)
        beam(K.deco, WHITE, lerp(prev.base, prev.top, 0.5), lerp(here.base, here.top, 0.5), 0.035, 0.035)
      end
      prev = here
    end
  end

  -- Deckchairs and sunloungers in rows beside the road, half of the rows slid out of line (and some of those over);
  -- a parasol by most rows.
  local chairs, parasols = 0, 0
  local function row(i, side)
    local u, w = K.along(i), right[i] * side
    local n = math.floor(rnd(3, 7.99))
    local d0 = rnd(0.9, 7)
    local slid = rnd(0, 1) < 0.5
    local lounge = rnd(0, 1) < 0.45
    local c = K.pick(CANVAS)
    local face = math.atan(-w.z, -w.x)
    local drift = 0
    for k = 0, n - 1 do
      if slid then drift = drift + rnd(-0.3, 1.1) end
      local p = pos[i] + u * (k * 1.7 + (slid and rnd(-0.4, 0.4) or 0)) + w * (W[i] + EDGE + d0 + drift)
      local o = off(p.x, p.z)
      if o > EDGE + 0.9 and o < RAIL - 1.5 and free(p.x, p.z, 0.9) then
        take(p.x, p.z, 0.9)
        local mode = 0
        if slid and rnd(0, 1) < 0.45 then mode = (rnd(0, 1) < 0.6) and 1 or 2 end
        local yaw = face + (slid and rnd(-1.3, 1.3) or rnd(-0.08, 0.08))
        local q = v3(p.x, K.ground(p.x, p.z), p.z)
        if lounge then lounger(q, yaw, mode, c) else deckchair(q, yaw, mode, c) end
        chairs = chairs + 1
      end
    end
    local p = pos[i] + u * rnd(-1.5, n * 1.7) + w * (W[i] + EDGE + d0 + 1.9)
    local o = off(p.x, p.z)
    if o > EDGE + 2.2 and o < RAIL - 2 and free(p.x, p.z, 0.4) then
      take(p.x, p.z, 0.4)
      parasol(v3(p.x, K.ground(p.x, p.z), p.z), slid and rnd(0, 1) < 0.5)
      parasols = parasols + 1
    end
  end
  for i = 4, N - 6, 3 do
    for side = -1, 1, 2 do
      if math.abs(i - K.start) > 3 and K.hash(i, side * 5.1) < 0.86 then row(i, side) end
    end
  end
  -- (and the ones that slid all the way: heaps against the railing)
  for k = 7, #rail_pts, 9 do
    local e = rail_pts[k]
    for _ = 1, math.floor(rnd(3, 6.99)) do
      local p = e.p - e.out * rnd(0.9, 3) + K.along(e.i) * rnd(-2.5, 2.5)
      if off(p.x, p.z) > EDGE + 2 and free(p.x, p.z, 0.5) then
        take(p.x, p.z, 0.5)
        local q = v3(p.x, K.ground(p.x, p.z), p.z)
        local c = K.pick(CANVAS)
        if rnd(0, 1) < 0.5 then lounger(q, rnd(0, 6.28), 1, c) else deckchair(q, rnd(0, 6.28), (rnd(0, 1) < 0.5) and 1 or 2, c) end
        chairs = chairs + 1
      end
    end
  end

  -- Spray up the ship's sides, just outside the railing.
  local sprays = 0
  for k = 3, #rail_pts, 5 do
    local e = rail_pts[k]
    if K.hash(k, 2.7) < 0.6 then
      local p = e.p + e.out * rnd(3, 5.5)
      spray(p.x, p.z, e.p.y - 3.5, rnd(0.8, 1.35))
      sprays = sprays + 1
    end
  end

  -- The waves: great ones alongside, as high as the rail, and the rest all over the sea.
  local WIND = 0.72
  local waves = 0
  for i = 6, N - 4, 6 do
    for side = -1, 1, 2 do
      if K.hash(i * 1.3, side * 9.1) < 0.72 then
        local h = rnd(10, 16)
        local p = pos[i] + right[i] * (side * (W[i] + SIDE + h * 1.2 + rnd(6, 20)))
        if off(p.x, p.z) > SIDE + h * 1.2 + 4 and inside(p.x, p.z, 12) then
          wave(p.x, p.z, rnd(26, 44), h, WIND + rnd(-0.4, 0.4), true)
          waves = waves + 1
        end
      end
    end
  end
  for _ = 1, 260 do
    local x, z = K.spot(SIDE + 22)
    if x and inside(x, z, 10) and free(x, z, 8) then
      take(x, z, 8)
      local h = rnd(4.5, 9)
      wave(x, z, rnd(18, 36), h, WIND + rnd(-0.35, 0.35), h > 7)
      waves = waves + 1
      if waves >= 150 then break end
    end
  end

  -- Seagulls: wheeling over the decks (well over the road) and out over the rail.
  local gulls = 0
  for _ = 1, 60 do
    local i = math.floor(rnd(2, N - 1))
    local d = rnd(-34, 34)
    local p = pos[i] + right[i] * d
    gull(v3(p.x, pos[i].y + rnd(8.5, 20), p.z), rnd(0, 6.28), rnd(1.5, 2.6))
    gulls = gulls + 1
  end

  local list = {}
  for k, n in pairs(made) do list[#list + 1] = n .. " " .. k end
  table.sort(list)
  info(string.format("cruise kit: %d triangles; %s, %d chairs, %d parasols, %d waves, %d sprays, %d gulls",
    tris(K.solid) + tris(K.deco) - before, table.concat(list, ", "), chairs, parasols, waves, sprays, gulls))
end

return T
