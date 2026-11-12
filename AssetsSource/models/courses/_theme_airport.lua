-- The airport course's scenery kit (see THEME KITS in _course.lua): an apron and a baggage hall down the valley.
-- Beside the road: conveyor belts carrying suitcases, baggage tugs towing carts, giant suitcases, luggage chutes down
-- the slopes, carousels on their decks, fuel trucks, departure boards, windsocks, floodlight masts and hi-vis cones;
-- over it, conveyor gantries; up the slopes, airliners parked on their stands with jet bridges to a glass-fronted
-- terminal, and two control towers. Every piece is a box, a tube or a prism in a frame turned to the road, written
-- straight into a piece a colour (K.sub), which costs no painting.
local T = {trees = 0}

function T.build(K)
  local v, N, pos, right, W = v3, K.N, K.pos, K.right, K.W
  local S, D = K.solid, K.deco
  local col, tint, sub, hexa, prism, flat = K.col, K.tint, K.sub, K.hexa, K.prism, K.flat
  local floor, max, min, sin, cos, pi = math.floor, math.max, math.min, math.sin, math.cos, math.pi
  local function rnd(lo, hi) return K.g:range(lo, hi) end
  local c = {
    WHITE = col(0.93, 0.93, 0.92), CONC = col(0.62, 0.62, 0.6), STEEL = col(0.66, 0.69, 0.72), DARK = col(0.3, 0.32, 0.35),
    BELT = col(0.05, 0.05, 0.06), TYRE = col(0.03, 0.03, 0.03), YELLOW = col(0.98, 0.76, 0.02), ORANGE = col(1, 0.36, 0.02),
    RED = col(0.85, 0.06, 0.04), BLUE = col(0.04, 0.22, 0.8), GLASS = col(0.2, 0.55, 0.85), GLASS2 = col(0.4, 0.72, 0.92),
    GLASS_DK = col(0.05, 0.12, 0.22), WING = col(0.78, 0.8, 0.84), GREEN = col(0.1, 0.75, 0.2), AMBER = col(1, 0.62, 0.05),
    LAMP = col(1, 0.95, 0.6), BOARD = col(0.02, 0.02, 0.04),
  }
  local BRIGHT = {col(0.85, 0.06, 0.04), col(0.05, 0.25, 0.85), col(0.06, 0.6, 0.15), col(0.9, 0.3, 0.02),
    col(0.55, 0.1, 0.75), col(0.95, 0.2, 0.5), col(0.02, 0.6, 0.7), col(0.95, 0.72, 0.03), col(0.45, 0.25, 0.1)}
  local LIVERY = {col(0.85, 0.06, 0.04), col(0.04, 0.22, 0.8), col(0.02, 0.6, 0.55), col(0.95, 0.5, 0.02), col(0.5, 0.1, 0.7)}

  -- The valley's height as built (its grid's cells, the higher of the two ways a cell is cut): what stands on it.
  local STEP
  do
    local x0, x1, z0, z1 = math.huge, -math.huge, -math.huge, math.huge
    for i = 1, N do
      local p = pos[i]
      x0 = min(x0, p.x); x1 = max(x1, p.x); z1 = min(z1, p.z); z0 = max(z0, p.z)
    end
    STEP = max(5, math.ceil(math.sqrt((x1 - x0 + 140) * (z0 - z1 + 140) / 9000)))
  end
  local cols, rows = floor((K.X1 - K.X0) / STEP) + 1, floor((K.Z0 - K.Z1) / STEP) + 1
  local nodes = {}
  local function node(cx, r)
    local k = r * cols + cx
    local y = nodes[k]
    if not y then y = K.ground(K.X0 + cx * STEP, K.Z0 - r * STEP); nodes[k] = y end
    return y
  end
  local function gh(x, z)
    local fx, fz = (x - K.X0) / STEP, (K.Z0 - z) / STEP
    local cx, r = max(0, min(cols - 2, floor(fx))), max(0, min(rows - 2, floor(fz)))
    local tx, tz = max(0, min(1, fx - cx)), max(0, min(1, fz - r))
    local y00, y10, y01, y11 = node(cx, r), node(cx + 1, r), node(cx, r + 1), node(cx + 1, r + 1)
    local A = (tx > tz) and (y00 + (y10 - y00) * tx + (y11 - y10) * tz) or (y00 + (y01 - y00) * tz + (y11 - y01) * tx)
    local B = (tx + tz < 1) and (y00 + (y10 - y00) * tx + (y01 - y00) * tz) or (y11 + (y01 - y11) * (1 - tx) + (y10 - y11) * (1 - tz))
    return max(A, B)
  end

  -- A frame: origin o, u along (a), w across (b), up (y), all times its scale s.
  local function mk(o, u, w, s) return {o = o, u = u, w = w, s = s or 1} end
  local function P(F, a, b, y)
    local s = F.s
    return F.o + F.u * (a * s) + F.w * (b * s) + v(0, y * s, 0)
  end
  -- The frame at sample i, `d` metres out from the road's edge on `side` (1 right, -1 left), on the ground: u down the
  -- road, w away from it. `pitched`: u and w lean with the ground (a vehicle's).
  local function frame(i, side, d, pitched)
    i = max(2, min(N - 1, floor(i + 0.5)))
    local w = right[i] * side
    local o = pos[i] + w * (W[i] + d)
    local u = K.along(i)
    if pitched then
      local a, b = pos[i - 1], pos[i + 1]
      u = v(u.x, (b.y - a.y) / max(0.1, math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)), u.z)
      local p, q = o + w * 1.2, o - w * 1.2
      w = v(w.x, (gh(p.x, p.z) - gh(q.x, q.z)) / 2.4, w.z)
    end
    return mk(v(o.x, gh(o.x, o.z), o.z), u, w)
  end
  local function at(F, a, b, y, s) return mk(P(F, a, b, y), F.u, F.w, s or F.s) end
  local function rot(F, ang)
    return mk(F.o, F.u * cos(ang) + F.w * sin(ang), F.w * cos(ang) - F.u * sin(ang), F.s)
  end
  -- Whether the frame's rectangle keeps `clear` metres off the road's edge (and inside the valley).
  local function fits(F, a0, a1, b0, b1, clear)
    for ka = 0, 4 do
      for kb = 0, 2 do
        local p = P(F, a0 + (a1 - a0) * ka / 4, b0 + (b1 - b0) * kb / 2, 0)
        if p.x < K.X0 + 4 or p.x > K.X1 - 4 or p.z > K.Z0 - 4 or p.z < K.Z1 + 4 then return false end
        local _, d = K.ground_d(p.x, p.z)
        if d - K.HW < clear then return false end
      end
    end
    return true
  end

  local function box(tgt, colour, F, a0, a1, b0, b1, y0, y1)
    local q = sub(tgt, colour)
    q.ink = colour
    hexa(q, P(F, a0, b0, y0), P(F, a1, b0, y0), P(F, a1, b1, y0), P(F, a0, b1, y0),
      P(F, a0, b0, y1), P(F, a1, b0, y1), P(F, a1, b1, y1), P(F, a0, b1, y1))
  end
  -- A six-sided shell of eight points {a, b, y}: its bottom ring, then the top ring above it.
  local function hex8(tgt, colour, F, p)
    local q = sub(tgt, colour)
    q.ink = colour
    local t = {}
    for k = 1, 8 do t[k] = P(F, p[k][1], p[k][2], p[k][3]) end
    hexa(q, t[1], t[2], t[3], t[4], t[5], t[6], t[7], t[8])
  end
  -- A tube along the frame's a (or b) axis through stations {t, off, cy, rh, rv}: at t along it, centred `off` to the
  -- side and cy up, radii rh across and rv up.
  local function tube(tgt, colour, F, axis, st, n)
    local rings = {}
    for j, s in ipairs(st) do
      rings[j] = {}
      for k = 0, n - 1 do
        local ang = (k + 0.5) / n * pi * 2
        if axis == "a" then rings[j][k + 1] = P(F, s[1], s[2] + cos(ang) * s[4], s[3] + sin(ang) * s[5])
        else rings[j][k + 1] = P(F, s[2] + cos(ang) * s[4], s[1], s[3] + sin(ang) * s[5]) end
      end
    end
    prism(sub(tgt, colour), rings, flat(colour), colour, colour)
  end
  local function wheel(tgt, F, a, b, r, wd)
    tube(tgt, c.TYRE, F, "b", {{b - wd / 2, a, r, r, r}, {b + wd / 2, a, r, r, r}}, 8)
  end
  local function pole(tgt, colour, F, a, b, y0, y1, r0, r1, n)
    local p = P(F, a, b, 0)
    K.column(sub(tgt, colour), p.x, p.z, F.o.y + y0 * F.s, F.o.y + y1 * F.s, r0, r1, n or 6, colour)
  end

  -- A level deck over the frame's rectangle: its top a hair over the highest ground there, its walls down past the
  -- lowest. Answers the frame on its top.
  local function terrace(F, a0, a1, b0, b1)
    local lo, hi = math.huge, -math.huge
    for ka = 0, 5 do
      for kb = 0, 4 do
        local p = P(F, a0 + (a1 - a0) * ka / 5, b0 + (b1 - b0) * kb / 4, 0)
        local y = max(gh(p.x, p.z), K.ground(p.x, p.z))
        lo = min(lo, y); hi = max(hi, y)
      end
    end
    local u = F.u
    local Tf = mk(v(F.o.x, hi + 0.2, F.o.z), v(u.x, 0, u.z), v(F.w.x, 0, F.w.z))
    box(S, c.CONC, Tf, a0, a1, b0, b1, lo - 1.5 - (hi + 0.2), 0)
    return Tf
  end
  -- The deck's yellow edge lines, and hazard stripes down its road-side wall.
  local function border(Tf, a0, a1, b0, b1)
    box(D, c.YELLOW, Tf, a0 + 0.3, a1 - 0.3, b0 + 0.3, b0 + 0.6, -0.05, 0.05)
    box(D, c.YELLOW, Tf, a0 + 0.3, a1 - 0.3, b1 - 0.6, b1 - 0.3, -0.05, 0.05)
    box(D, c.YELLOW, Tf, a0 + 0.3, a0 + 0.6, b0 + 0.7, b1 - 0.7, -0.05, 0.05)
    box(D, c.YELLOW, Tf, a1 - 0.6, a1 - 0.3, b0 + 0.7, b1 - 0.7, -0.05, 0.05)
    local a = a0 + 0.4
    while a + 0.9 <= a1 do
      box(D, c.YELLOW, Tf, a, a + 0.9, b0 - 0.07, b0 + 0.2, -1.2, -0.15)
      box(D, c.BELT, Tf, a + 0.92, a + 1.78, b0 - 0.06, b0 + 0.2, -1.2, -0.15)
      a = a + 1.8
    end
  end

  -- A suitcase standing on the frame: wd wide (along a), ht high, th thick; `simple` without handle, wheels and tag.
  local function suitcase(tgt, F, wd, ht, th, colour, simple)
    box(tgt, colour, F, -wd / 2, wd / 2, -th / 2, th / 2, 0.06 * ht, ht)
    local dk = tint(colour, 0.5)
    for s = -1, 1, 2 do
      box(D, dk, F, s * wd * 0.27 - wd * 0.05, s * wd * 0.27 + wd * 0.05, -th * 0.56, th * 0.56, 0.04 * ht, ht * 1.02)
    end
    if simple then return end
    for s = -1, 1, 2 do
      box(D, c.TYRE, F, s * wd * 0.38 - wd * 0.06, s * wd * 0.38 + wd * 0.06, -th * 0.3, th * 0.3, 0, 0.1 * ht)
      box(D, c.STEEL, F, s * wd * 0.15 - wd * 0.02, s * wd * 0.15 + wd * 0.02, -th * 0.08, th * 0.08, ht * 0.98, ht * 1.16)
    end
    box(D, c.TYRE, F, -wd * 0.19, wd * 0.19, -th * 0.11, th * 0.11, ht * 1.14, ht * 1.2)
    box(D, c.WHITE, F, -wd * 0.06, wd * 0.06, -th * 0.6, -th * 0.45, ht * 0.68, ht * 0.88)
  end
  local function any_case(tgt, F, size)
    local colour = K.pick(BRIGHT)
    if rnd(0, 1) < 0.5 then suitcase(tgt, F, size * rnd(0.7, 0.9), size * rnd(0.95, 1.2), size * 0.36, colour, false)
    else suitcase(tgt, F, size * rnd(0.85, 1.05), size * 0.38, size * rnd(0.6, 0.7), colour, true) end
  end

  -- A hi-vis cone.
  local function cone_at(F, a, b)
    local p = P(F, a, b, 0)
    local y = gh(p.x, p.z)
    local G = mk(v(p.x, y, p.z), v(1, 0, 0), v(0, 0, 1))
    box(D, c.ORANGE, G, -0.36, 0.36, -0.36, 0.36, -0.4, 0.09)
    local q = sub(D, c.ORANGE)
    local under = v(p.x, y + 0.07, p.z)
    K.cone(q, K.ring(under, 0.27, 0.27, 6, 0), under, v(p.x, y + 1.25, p.z), flat(c.ORANGE), c.ORANGE)
    K.column(sub(D, c.WHITE), p.x, p.z, y + 0.5, y + 0.78, 0.19, 0.125, 6, c.WHITE)
  end

  -- A baggage tug and a baggage cart, each on a pitched frame, its front down the road.
  local function tug(F)
    box(S, c.YELLOW, F, -1.3, 1.3, -0.75, 0.75, 0.35, 1.0)
    box(D, c.YELLOW, F, 0.45, 1.25, -0.7, 0.7, 0.9, 1.3)
    box(D, c.BELT, F, 1.25, 1.42, -0.8, 0.8, 0.3, 0.7)
    box(D, c.BELT, F, -0.9, -0.3, -0.5, 0.5, 0.95, 1.5)
    for sa = -1, 1, 2 do
      for sb = -1, 1, 2 do
        box(D, c.DARK, F, -0.5 + sa * 0.75 - 0.05, -0.5 + sa * 0.75 + 0.05, sb * 0.68 - 0.05, sb * 0.68 + 0.05, 0.95, 2.05)
        wheel(D, F, sa * 0.85, sb * 0.8, 0.42, 0.3)
      end
    end
    box(D, c.WHITE, F, -1.35, 0.4, -0.8, 0.8, 2.0, 2.12)
    box(D, c.ORANGE, F, -0.6, -0.35, -0.12, 0.12, 2.1, 2.35)
  end
  local function cart(F, colour)
    box(S, c.STEEL, F, -1.15, 1.15, -0.8, 0.8, 0.5, 0.7)
    box(D, c.DARK, F, 1.1, 1.8, -0.06, 0.06, 0.5, 0.6)
    for sa = -1, 1, 2 do
      for sb = -1, 1, 2 do
        box(D, c.TYRE, F, sa * 0.8 - 0.26, sa * 0.8 + 0.26, sb * 0.78 - 0.12, sb * 0.78 + 0.12, 0, 0.55)
        box(D, c.DARK, F, sa * 1.08 - 0.04, sa * 1.08 + 0.04, sb * 0.74 - 0.04, sb * 0.74 + 0.04, 0.65, 2.0)
      end
    end
    box(D, colour, F, -1.25, 1.25, -0.88, 0.88, 1.98, 2.12)
    suitcase(D, at(F, -0.6, 0.1, 0.7), 0.85, 1.0, 0.5, K.pick(BRIGHT), true)
    suitcase(D, at(F, 0.45, -0.25, 0.7), 0.9, 0.45, 0.6, K.pick(BRIGHT), true)
    suitcase(D, at(F, 0.4, 0.35, 0.7), 0.8, 0.8, 0.4, K.pick(BRIGHT), true)
  end

  -- An airliner on the level frame (its nose down the road, its wheels on y = 0), in its airline's colour.
  local function airliner(F, livery)
    tube(S, c.WHITE, F, "a", {{18, 0, 3.7, 0.2, 0.2}, {16.6, 0, 3.85, 1.2, 1.2}, {14.5, 0, 4.0, 1.9, 1.9}, {-7, 0, 4.0, 1.9, 1.9},
      {-14, 0, 4.6, 1.0, 1.0}, {-18, 0, 5.0, 0.25, 0.25}}, 10)
    box(D, livery, F, -7, 14.3, -1.85, 1.85, 3.45, 3.85)
    box(D, c.GLASS_DK, F, -6, 13.5, -1.86, 1.86, 4.2, 4.5)
    box(D, c.GLASS_DK, F, 15.2, 16.3, -1.15, 1.15, 4.55, 5.05)
    for sg = -1, 1, 2 do
      hex8(S, c.WING, F, {{3.5, sg * 1.2, 3.1}, {-3.5, sg * 1.2, 3.1}, {-7.5, sg * 16, 4.7}, {-5.2, sg * 16, 4.7},
        {3.5, sg * 1.2, 3.75}, {-3.5, sg * 1.2, 3.75}, {-7.5, sg * 16, 4.95}, {-5.2, sg * 16, 4.95}})
      hex8(D, livery, F, {{-5.2, sg * 15.7, 4.8}, {-7.5, sg * 15.7, 4.8}, {-7.5, sg * 16.1, 4.8}, {-5.2, sg * 16.1, 4.8},
        {-6.6, sg * 16.0, 6.8}, {-7.8, sg * 16.0, 6.8}, {-7.8, sg * 16.3, 6.8}, {-6.6, sg * 16.3, 6.8}})
      tube(D, c.STEEL, F, "a", {{2.6, sg * 5.5, 2.35, 0.95, 0.95}, {-0.6, sg * 5.5, 2.35, 0.8, 0.8}}, 8)
      tube(D, c.BELT, F, "a", {{2.75, sg * 5.5, 2.35, 0.72, 0.72}, {2.5, sg * 5.5, 2.35, 0.72, 0.72}}, 8)
      box(D, c.WING, F, -0.5, 1.8, sg * 5.5 - 0.15, sg * 5.5 + 0.15, 3.0, 3.7)
      hex8(D, c.WING, F, {{-12.5, sg * 0.6, 4.75}, {-16.5, sg * 0.6, 4.75}, {-17.6, sg * 6.2, 5.2}, {-15.8, sg * 6.2, 5.2},
        {-12.5, sg * 0.6, 5.0}, {-16.5, sg * 0.6, 5.0}, {-17.6, sg * 6.2, 5.32}, {-15.8, sg * 6.2, 5.32}})
      box(D, c.STEEL, F, -1.65, -1.35, sg * 2.8 - 0.12, sg * 2.8 + 0.12, 0.6, 3.3)
      wheel(D, F, -1.5, sg * 2.8, 0.65, 0.9)
    end
    hex8(S, livery, F, {{-9.5, -0.18, 5.3}, {-16.5, -0.18, 5.3}, {-16.5, 0.18, 5.3}, {-9.5, 0.18, 5.3},
      {-15.2, -0.1, 11.4}, {-17.8, -0.1, 11.4}, {-17.8, 0.1, 11.4}, {-15.2, 0.1, 11.4}})
    box(D, c.STEEL, F, 13, 13.3, -0.1, 0.1, 0.5, 2.4)
    wheel(D, F, 13.15, 0, 0.55, 0.6)
  end

  -- One module of the terminal on its deck: a white hall, a glass front to the road, a roof oversailing it on columns.
  local function hall(Tf, H)
    box(S, c.WHITE, Tf, -6, 6, 0.8, 9, -0.1, H)
    for cx = 0, 3 do
      for r = 0, 2 do
        local a0, y0 = -5.7 + cx * 2.9, 0.9 + r * (H - 2.6) / 3
        box(D, ((cx + r) % 2 == 0) and c.GLASS or c.GLASS2, Tf, a0, a0 + 2.7, 0.45, 0.9, y0, y0 + (H - 2.6) / 3 - 0.2)
      end
    end
    box(S, c.WHITE, Tf, -6.6, 6.6, -1.6, 9.4, H, H + 0.5)
    box(D, c.BLUE, Tf, -6.62, 6.62, -1.75, -1.5, H - 0.9, H + 0.6)
    for k = 0, 6 do
      if k ~= 3 then box(D, c.WHITE, Tf, -3.4 + k * 1.0, -2.7 + k * 1.0, -1.82, -1.7, H - 0.6, H + 0.25) end
    end
    for k = -1, 1 do pole(D, c.STEEL, Tf, k * 5.9, -1.0, -0.3, H + 0.05, 0.25, 0.25, 6) end
    box(D, c.GLASS_DK, Tf, -1.3, 1.3, 0.3, 0.6, 0, 2.4)
    box(D, c.YELLOW, Tf, -1.7, 1.7, -0.3, 0.7, 2.4, 2.65)
    box(D, c.STEEL, Tf, -4, -1.5, 3, 5.5, H + 0.4, H + 1.5)
    box(D, c.DARK, Tf, 1.5, 3.2, 5, 7, H + 0.4, H + 1.2)
  end

  -- A control tower at the frame: a red and white shaft, a flared glass cab, its roof and mast.
  local function tower(F)
    local x, z, y = F.o.x, F.o.z, F.o.y
    box(S, c.WHITE, F, -5, 5, -5, 5, -3, 4)
    box(D, c.GLASS, F, -4.4, 4.4, -5.15, 5.15, 1.2, 2.8)
    box(D, c.GLASS, F, -5.15, 5.15, -4.4, 4.4, 1.2, 2.8)
    box(D, c.BLUE, F, -5.2, 5.2, -5.2, 5.2, 3.6, 4.3)
    for k = 0, 5 do
      local colour = (k % 2 == 0) and c.WHITE or c.RED
      K.column(sub(S, colour), x, z, y + 4.3 + k * 4 + 0.01, y + 8.3 + k * 4, 2.5, 2.5, 8, colour)
    end
    K.column(sub(S, c.WHITE), x, z, y + 28.31, y + 30.6, 2.5, 5.2, 8, c.WHITE)
    K.column(sub(S, c.GLASS), x, z, y + 30.61, y + 34, 5.0, 5.9, 8, c.GLASS)
    K.column(sub(D, c.DARK), x, z, y + 30.5, y + 31.2, 5.45, 5.6, 8, c.DARK)
    K.column(sub(S, c.WHITE), x, z, y + 34.01, y + 34.8, 6.5, 6.5, 8, c.WHITE)
    K.column(sub(D, c.STEEL), x, z, y + 34.81, y + 35.8, 3.2, 2.2, 8, c.STEEL)
    K.column(sub(D, c.DARK), x, z, y + 35.81, y + 41.5, 0.16, 0.08, 5, c.DARK)
    box(D, c.RED, F, -0.3, 0.3, -0.3, 0.3, 41.3, 41.9)
    box(D, c.WHITE, F, 1.2, 1.5, -1.6, 1.6, 35.9, 37.6)
    box(D, c.DARK, F, 1.0, 1.7, -0.15, 0.15, 35.5, 36)
  end

  -- What stands deep up the slopes, a side: runs of samples the long near pieces (chutes, carousels) keep out of; and
  -- circles the scattered pieces keep out of.
  local deep, taken = {[1] = {}, [-1] = {}}, {}
  local function deep_free(side, i0, i1)
    for _, q in ipairs(deep[side]) do
      if i1 >= q[1] and i0 <= q[2] then return false end
    end
    return true
  end
  local function take(F, a, b, r)
    local p = P(F, a, b, 0)
    taken[#taken + 1] = {p.x, p.z, r}
  end
  local function free(x, z, r)
    for _, q in ipairs(taken) do
      if (x - q[1]) ^ 2 + (z - q[2]) ^ 2 < (r + q[3]) ^ 2 then return false end
    end
    return true
  end

  -- A stand: an airliner on its deck along the road, baggage carts and a belt loader beside it, cones round it; with
  -- `term`, the terminal's halls stepped down the slope behind it and a jet bridge to its door.
  local function stand(i, side, term)
    local Fp = frame(i, side, 24)
    if not (fits(Fp, -16, 16, -7, 4, 3) and fits(Fp, -8, 5, -15, 15, 3)) then return false end
    local Tf = terrace(Fp, -16, 16, -6.5, 3.5)
    border(Tf, -16, 16, -6.5, 3.5)
    box(D, c.YELLOW, Tf, -14.5, 14, -0.15, 0.15, -0.05, 0.06)
    box(D, c.YELLOW, Tf, 14, 14.4, -1.6, 1.6, -0.05, 0.06)
    for k = -3, 3 do box(D, c.YELLOW, Tf, k * 4 - 1.2, k * 4 + 1.2, -3.05, -2.8, -0.05, 0.06) end
    local Pl = at(Tf, 0, 0, 0, 0.85)
    local livery = K.pick(LIVERY)
    airliner(Pl, livery)
    tug(at(Tf, 5.5, -4.9, 0, 1.1))
    cart(at(Tf, 2.1, -4.9, 0, 1.1), livery)
    cart(at(Tf, -1.2, -4.9, 0, 1.1), livery)
    -- (the belt loader: a yellow truck, its belt up to the hold)
    box(D, c.YELLOW, Tf, -6.2, -4.6, -5.8, -2.4, 0.3, 0.9)
    hex8(D, c.BELT, Tf, {{-6, -5.9, 0.9}, {-4.8, -5.9, 0.9}, {-4.8, -1.5, 2.9}, {-6, -1.5, 2.9},
      {-6, -5.9, 1.15}, {-4.8, -5.9, 1.15}, {-4.8, -1.5, 3.15}, {-6, -1.5, 3.15}})
    for _, q in ipairs({{-15, -5.6}, {15, -5.6}, {-15, 2.6}, {15, 2.6}, {9, -5.6}, {-9, -5.6}}) do cone_at(Tf, q[1], q[2]) end
    deep[side][#deep[side] + 1] = {i - 8, i + 8}
    take(Fp, 0, 0, 24)
    if term then
      local best
      for k = -1, 1 do
        local Fm = frame(i + k * 5, side, 40)
        if fits(Fm, -7, 7, -2, 10, 12) then
          local Tm = terrace(Fm, -6.4, 6.4, -1.9, 9.6)
          hall(Tm, 9)
          take(Fm, 0, 4, 10)
          if k >= 0 and not best or k == 1 then best = Tm end
        end
      end
      if best then
        local a, b = P(best, 0, 0.7, 2.2), P(Pl, 10.5, 2.4, 4.3)
        local dir = b - a
        local h = v(dir.z, 0, -dir.x) * (1 / max(0.1, math.sqrt(dir.x ^ 2 + dir.z ^ 2)))
        local q = sub(S, c.WHITE); q.ink = c.WHITE
        K.slab(q, a, b, h * 1.3, v(0, 1.3, 0))
        q = sub(D, c.GLASS); q.ink = c.GLASS
        K.slab(q, a + dir * 0.1, a + dir * 0.9, h * 1.36, v(0, 0.45, 0))
        box(S, c.WHITE, Pl, 9.2, 11.8, 2.0, 4.8, 2.9, 5.8)
        box(D, livery, Pl, 9.15, 11.85, 1.95, 4.85, 5.3, 5.6)
        local m = a + dir * 0.62
        K.column(sub(S, c.STEEL), m.x, m.z, gh(m.x, m.z) - 1.5, m.y - 1.2, 0.55, 0.55, 8, c.STEEL)
        K.column(sub(D, c.YELLOW), m.x, m.z, gh(m.x, m.z) - 1.4, gh(m.x, m.z) + 1.2, 0.62, 0.62, 8, c.YELLOW)
      end
    end
    return true
  end

  -- A conveyor gantry over the road at sample i: legs clear of both walls, its belt (and its suitcases) 7.6 m up.
  local gantries = {}
  local function gantry(i)
    local Fc = mk(pos[i], K.along(i), right[i])
    local half = W[i] + 3.3
    for s = -1, 1, 2 do
      local Fl = frame(i, s, 3.3)
      if not fits(Fl, -1.6, 1.6, 0, 1, 2.6) then return false end
    end
    for s = -1, 1, 2 do
      local p = P(Fc, 0, s * (half + 0.4), 0)
      local y0 = gh(p.x, p.z) - 1.5 - pos[i].y
      for sa = -1, 1, 2 do
        box(S, c.STEEL, Fc, sa * 1.2 - 0.25, sa * 1.2 + 0.25, s * half, s * (half + 0.8), y0, 7.7)
        box(D, c.YELLOW, Fc, sa * 1.2 - 0.3, sa * 1.2 + 0.3, s * (half - 0.05), s * (half + 0.85), y0, y0 + 3.2)
      end
      box(D, c.STEEL, Fc, -1.2, 1.2, s * (half + 0.3), s * (half + 0.5), 3.4, 3.7)
    end
    box(S, c.DARK, Fc, -1.5, 1.5, -half - 1.2, half + 1.2, 7.6, 7.9)
    box(D, c.BELT, Fc, -1.1, 1.1, -half - 1.1, half + 1.1, 7.85, 8.02)
    for sa = -1, 1, 2 do
      box(D, c.YELLOW, Fc, sa * 1.42 - 0.14, sa * 1.42 + 0.14, -half - 1.3, half + 1.3, 7.5, 8.55)
    end
    for k = 0, 3 do
      local G = mk(P(Fc, 0, (-0.72 + k * 0.48) * half, 8.0), right[i], K.along(i))
      suitcase(D, G, rnd(1.6, 2.1), rnd(2.0, 2.7), 0.8, K.pick(BRIGHT), false)
    end
    gantries[#gantries + 1] = i
    return true
  end

  -- The near pieces, each from sample i on a side: true when it fitted and was built.
  local feats = {}
  -- A conveyor belt along the road on legs, yellow side rails, suitcases riding it.
  local function conveyor(i, side)
    local n = 9
    local Fs = {}
    for k = 0, n do
      Fs[k] = frame(i + k, side, 5.2)
      if not fits(Fs[k], -0.5, 0.5, -1.5, 1.5, 2.6) then return false end
    end
    local belt, r1, r2 = {}, {}, {}
    for k = 0, n do
      local F = Fs[k]
      belt[#belt + 1] = {P(F, 0, -1.1, 1.25), P(F, 0, 1.1, 1.25), P(F, 0, 1.1, 1.5), P(F, 0, -1.1, 1.5)}
      r1[#r1 + 1] = {P(F, 0, 1.04, 1.1), P(F, 0, 1.3, 1.1), P(F, 0, 1.3, 1.8), P(F, 0, 1.04, 1.8)}
      r2[#r2 + 1] = {P(F, 0, -1.3, 1.1), P(F, 0, -1.04, 1.1), P(F, 0, -1.04, 1.8), P(F, 0, -1.3, 1.8)}
      box(S, c.DARK, F, -0.14, 0.14, -1.22, 1.22, -1.6, 1.2)
      if k > 0 and k < n then
        box(D, c.STEEL, F, -0.08, 0.08, -1.0, 1.0, 1.45, 1.57)
        if k % 2 == 1 or rnd(0, 1) < 0.35 then
          local Fm = frame(i + k, side, 5.2)
          local a, b = Fs[k].o, Fs[k + 1].o
          any_case(D, rot(mk(v((a.x + b.x) / 2, (a.y + b.y) / 2 + 1.5, (a.z + b.z) / 2), Fm.u, Fm.w), rnd(-0.5, 0.5)), 1.75)
        end
      end
    end
    prism(sub(S, c.BELT), belt, flat(c.BELT), c.BELT, c.BELT)
    prism(sub(S, c.YELLOW), r1, flat(c.YELLOW), c.YELLOW, c.YELLOW)
    prism(sub(S, c.YELLOW), r2, flat(c.YELLOW), c.YELLOW, c.YELLOW)
    for _, k in ipairs({0, n}) do
      tube(D, c.STEEL, Fs[k], "b", {{-1.36, 0, 1.38, 0.42, 0.42}, {1.36, 0, 1.38, 0.42, 0.42}}, 8)
    end
    return true
  end
  -- A tug towing four carts down the road.
  local function train(i, side)
    local Fs = {}
    for k = 0, 4 do
      Fs[k] = frame(i + k, side, 4.6, true)
      if not fits(Fs[k], -1.6, 1.6, -1.1, 1.1, 2.4) then return false end
    end
    local colour = K.pick(BRIGHT)
    for k = 0, 3 do cart(Fs[k], colour) end
    tug(Fs[4])
    return true
  end
  -- Two or three giant suitcases.
  local function giants(i, side)
    local done_ = false
    for k = 0, 2 do
      if k < 2 or rnd(0, 1) < 0.5 then
        local F = frame(i + k * 1.6 + 0.5, side, 5 + rnd(0, 2.5))
        if fits(F, -2.6, 2.6, -2.6, 2.6, 2.2) then
          local wd = rnd(2.6, 3.8)
          local G = rot(at(F, 0, 0, -0.7), rnd(-0.6, 0.6))
          if rnd(0, 1) < 0.7 then suitcase(S, G, wd, wd * rnd(1.25, 1.6), wd * 0.38, K.pick(BRIGHT), false)
          else suitcase(S, G, wd * 1.2, wd * 0.5, wd * 0.8, K.pick(BRIGHT), true) end
          done_ = true
        end
      end
    end
    return done_
  end
  -- A departure board across the verge, facing up the road: rows of times, places, gates and whether on time.
  local function board(i, side)
    local F = frame(i + 1, side, 3.2)
    if not fits(F, -0.7, 0.7, 0, 9.6, 2.6) then return false end
    local p = P(F, 0, 8.9, 0)
    local Y = max(0, gh(p.x, p.z) - F.o.y)
    box(S, c.STEEL, F, -0.2, 0.2, 0.3, 0.7, -1.5, Y + 3.3)
    box(S, c.STEEL, F, -0.2, 0.2, 8.7, 9.1, -1.5, Y + 3.3)
    box(S, c.BOARD, F, -0.25, 0.25, 0, 9.4, Y + 3, Y + 8.6)
    box(D, c.BLUE, F, -0.33, -0.2, 0.2, 9.2, Y + 7.75, Y + 8.45)
    box(D, c.YELLOW, F, -0.38, -0.3, 0.45, 1.3, Y + 7.88, Y + 8.32)
    box(D, c.WHITE, F, -0.38, -0.3, 1.7, 6.2, Y + 7.95, Y + 8.25)
    for r = 0, 5 do
      local y0 = Y + 7.0 - r * 0.72
      box(D, c.WHITE, F, -0.33, -0.2, 0.4, 1.6, y0, y0 + 0.42)
      box(D, c.AMBER, F, -0.33, -0.2, 1.9, 1.9 + rnd(2.0, 3.8), y0, y0 + 0.42)
      box(D, c.WHITE, F, -0.33, -0.2, 6.0, 6.8, y0, y0 + 0.42)
      box(D, (rnd(0, 1) < 0.7) and c.GREEN or c.RED, F, -0.33, -0.2, 7.1, 8.9, y0, y0 + 0.42)
    end
    return true
  end
  -- A luggage chute down the slope to the road: a steel trough on legs from a blue drop house, suitcases sliding.
  local function chute(i, side)
    if not deep_free(side, i - 2, i + 4) then return false end
    local F = frame(i + 1, side, 0)
    if not fits(F, -2.3, 2.3, 2.7, 33, 2.4) then return false end
    local fl, s1, s2, ys = {}, {}, {}, {}
    for k = 0, 6 do
      local b = 4 + k * 4
      local p = P(F, 0, b, 0)
      local y = gh(p.x, p.z) - F.o.y + 0.9 + k * 0.85
      ys[k] = y
      fl[#fl + 1] = {P(F, -1.3, b, y), P(F, 1.3, b, y), P(F, 1.3, b, y + 0.2), P(F, -1.3, b, y + 0.2)}
      s1[#s1 + 1] = {P(F, 1.2, b, y + 0.02), P(F, 1.45, b, y + 0.02), P(F, 1.45, b, y + 1.0), P(F, 1.2, b, y + 1.0)}
      s2[#s2 + 1] = {P(F, -1.45, b, y + 0.02), P(F, -1.2, b, y + 0.02), P(F, -1.2, b, y + 1.0), P(F, -1.45, b, y + 1.0)}
      for sa = -1, 1, 2 do
        box(S, c.DARK, F, sa * 1.17 - 0.13, sa * 1.17 + 0.13, b - 0.15, b + 0.15, y - 0.9 - k * 0.85 - 1.6, y + 0.05)
      end
      if k > 0 and k < 6 and k % 2 == 1 then
        any_case(D, rot(at(F, 0, b + 2, (y + 0.85 / 2) + 0.2), rnd(-0.4, 0.4)), 1.7)
      end
    end
    prism(sub(S, c.STEEL), fl, flat(c.STEEL), c.STEEL, c.STEEL)
    prism(sub(S, c.YELLOW), s1, flat(c.YELLOW), c.YELLOW, c.YELLOW)
    prism(sub(S, c.YELLOW), s2, flat(c.YELLOW), c.YELLOW, c.YELLOW)
    box(S, c.STEEL, F, -1.7, 1.7, 2.7, 4.3, -1.5, ys[0] + 0.1)
    box(S, c.BLUE, F, -2.2, 2.2, 27.6, 32.5, ys[6] - 9, ys[6] + 3.2)
    box(D, c.BELT, F, -1.25, 1.25, 27.4, 27.8, ys[6] + 0.25, ys[6] + 2.3)
    box(D, c.YELLOW, F, -2.25, 2.25, 27.5, 32.6, ys[6] + 2.5, ys[6] + 2.9)
    take(F, 0, 18, 16)
    return true
  end
  -- A windsock and a floodlight mast.
  local function windsock(i, side)
    local F = frame(i, side, 4.5)
    if not fits(F, -1, 4, -1, 1, 2.4) then return false end
    pole(S, c.WHITE, F, 0, 0, -1.5, 7.2, 0.14, 0.09, 6)
    pole(D, c.RED, F, 0, 0, 2.0, 3.2, 0.17, 0.16, 6)
    for k = 0, 4 do
      local a0, r0, r1 = 0.15 + k * 0.72, 0.6 - k * 0.07, 0.6 - (k + 1) * 0.07
      tube(D, (k % 2 == 0) and c.ORANGE or c.WHITE, F, "a", {{a0, 0, 6.6 - k * 0.07, r0, r0}, {a0 + 0.7, 0, 6.53 - k * 0.07, r1, r1}}, 6)
    end
    local M = frame(i + 1, side, 6)
    if fits(M, -0.5, 0.5, -2, 2, 2.4) then
      pole(S, c.STEEL, M, 0, 0, -1.5, 13, 0.24, 0.14, 6)
      box(D, c.DARK, M, -0.15, 0.15, -1.9, 1.9, 12.6, 13.6)
      for k = 0, 3 do box(D, c.LAMP, M, -0.28, -0.1, -1.75 + k * 0.92, -1.05 + k * 0.92, 12.7, 13.5) end
    end
    return true
  end
  -- A baggage carousel on its deck: an oval of sloping plates round a steel island, suitcases riding, a giant one on top.
  local function carousel(i, side)
    if not deep_free(side, i - 1, i + 7) then return false end
    local F = frame(i + 3, side, 8.3)
    if not fits(F, -8.4, 8.4, -5, 5, 2.6) then return false end
    local Tf = terrace(F, -8.2, 8.2, -4.8, 4.8)
    border(Tf, -8.2, 8.2, -4.8, 4.8)
    local n = 18
    local function oval(ra, rb, y, shift)
      local out = {}
      for k = 0, n - 1 do
        local ang = (k + (shift or 0)) / n * pi * 2
        out[#out + 1] = P(Tf, cos(ang) * ra, sin(ang) * rb, y)
      end
      return out
    end
    prism(sub(S, c.STEEL), {oval(5, 1.6, -0.1), oval(5, 1.6, 1.7)}, flat(c.STEEL), c.STEEL, c.STEEL)
    prism(sub(D, c.YELLOW), {oval(4.7, 1.3, 1.6), oval(4.7, 1.3, 1.95)}, flat(c.YELLOW), c.YELLOW, c.YELLOW)
    prism(sub(S, c.DARK), {oval(7.1, 3.7, -0.1), oval(7.1, 3.7, 0.5)}, flat(c.DARK), c.DARK, c.DARK)
    local function pt(ra, rb, ang, y) return P(Tf, cos(ang) * ra, sin(ang) * rb, y) end
    for k = 0, n - 1 do
      local a0, a1 = (k + 0.04) / n * pi * 2, (k + 0.96) / n * pi * 2
      local colour = (k % 2 == 0) and c.BELT or c.DARK
      local q = sub(D, colour); q.ink = colour
      hexa(q, pt(4.95, 1.55, a0, 1.0), pt(4.95, 1.55, a1, 1.0), pt(7.25, 3.85, a1, 0.42), pt(7.25, 3.85, a0, 0.42),
        pt(4.95, 1.55, a0, 1.2), pt(4.95, 1.55, a1, 1.2), pt(7.25, 3.85, a1, 0.62), pt(7.25, 3.85, a0, 0.62))
      if k % 3 == 0 then
        local am = (k + 0.5) / n * pi * 2
        any_case(D, rot(mk(pt(6.1, 2.7, am, 0.9), Tf.u, Tf.w), rnd(0, 3)), 1.5)
      end
    end
    suitcase(S, rot(at(Tf, 0, 0, 1.9), rnd(-0.15, 0.15)), 4.2, 5.0, 1.5, K.pick(BRIGHT), false)
    for _, q in ipairs({{-7.6, -4.2}, {7.6, -4.2}, {-7.6, 4.2}, {7.6, 4.2}}) do cone_at(Tf, q[1], q[2]) end
    take(F, 0, 0, 10)
    return true
  end
  -- A fuel truck: a white cab, a red tank with its bands.
  local function fuel(i, side)
    local F = frame(i + 1.5, side, 5, true)
    if not fits(F, -4.6, 4.6, -1.7, 1.7, 2.4) then return false end
    box(S, c.DARK, F, -4, 4, -1.05, 1.05, 0.55, 0.95)
    box(S, c.WHITE, F, 2.4, 4.05, -1.2, 1.2, 0.8, 2.9)
    box(D, c.GLASS_DK, F, 3.9, 4.12, -1.0, 1.0, 1.75, 2.7)
    box(D, c.GLASS_DK, F, 2.9, 3.8, -1.25, 1.25, 1.8, 2.6)
    box(D, c.YELLOW, F, 4.0, 4.2, -1.2, 1.2, 0.6, 1.0)
    tube(S, c.RED, F, "a", {{-3.9, 0, 2.1, 1.25, 1.15}, {2.25, 0, 2.1, 1.25, 1.15}}, 10)
    tube(D, c.WHITE, F, "a", {{-1.4, 0, 2.1, 1.3, 1.2}, {-0.5, 0, 2.1, 1.3, 1.2}}, 10)
    tube(D, c.YELLOW, F, "a", {{-3.6, 0, 2.1, 1.29, 1.19}, {-3.2, 0, 2.1, 1.29, 1.19}}, 10)
    box(D, c.STEEL, F, -2.6, 1.4, -0.3, 0.3, 3.15, 3.4)
    box(D, c.ORANGE, F, 2.9, 3.2, -0.15, 0.15, 2.9, 3.2)
    for _, a in ipairs({3.1, -1.6, -3.0}) do
      for sb = -1, 1, 2 do wheel(D, F, a, sb * 1.0, 0.55, 0.45) end
    end
    cone_at(F, 5.4, -1.2); cone_at(F, -5.2, -1.2)
    return true
  end
  feats = {
    {len = 9, fn = conveyor}, {len = 4, fn = giants}, {len = 3, fn = board}, {len = 5, fn = train}, {len = 3, fn = chute},
    {len = 2, fn = windsock}, {len = 7, fn = carousel}, {len = 4, fn = fuel}, {len = 4, fn = giants}, {len = 9, fn = conveyor},
    {len = 5, fn = train}, {len = 3, fn = chute},
  }

  -- The stands and the towers first (the deep pieces), then the gantries, then the near pieces down both sides.
  local built = {stands = 0, towers = 0, near = 0, cones = 0, slope = 0}
  for _, q in ipairs({{32, 1, true}, {58, -1, false}, {84, 1, true}, {100, -1, true}, {130, 1, true}, {150, -1, false}, {8, 1, false}}) do
    if stand(q[1], q[2], q[3]) or stand(q[1], -q[2], q[3]) then built.stands = built.stands + 1 end
  end
  for _, q in ipairs({{114, -1, 15}, {18, -1, 16}, {70, 1, 30}}) do
    for _, side in ipairs({q[2], -q[2]}) do
      local F = frame(q[1], side, q[3])
      if deep_free(side, q[1] - 3, q[1] + 3) and fits(F, -6, 6, -6, 6, 4) then
        tower(F)
        deep[side][#deep[side] + 1] = {q[1] - 5, q[1] + 5}
        take(F, 0, 0, 9)
        built.towers = built.towers + 1
        break
      end
    end
  end
  for _, i in ipairs({24, 46, 68, 92, 118, 140}) do gantry(i) end
  for _, side in ipairs({1, -1}) do
    local i, k = 4, (side == 1) and 1 or 6
    while i < N - 5 do
      local f = feats[(k - 1) % #feats + 1]
      local hit
      for _, gs in ipairs(gantries) do
        if gs >= i - 1 and gs <= i + f.len + 1 then hit = gs end
      end
      if hit and hit - i < 3 then
        i = hit + 2
      elseif hit then
        if windsock(i, side) then built.near = built.near + 1 end
        i = hit + 2
      else
        if i + f.len < N - 3 and f.fn(i, side) then
          i = i + f.len + 1
          built.near = built.near + 1
        else
          i = i + 1
        end
        k = k + 1
      end
    end
    -- Cones along the verge.
    for j = 3, N - 2 do
      if K.hash(j, side * 7) < 0.55 then
        local F = frame(j, side, 2.45)
        if fits(F, -0.4, 0.4, -0.4, 0.4, 2.0) then cone_at(F, 0, 0); built.cones = built.cones + 1 end
      end
    end
  end

  -- Up the slopes: oversized suitcases, half sunk and leaning, and floodlight masts.
  for _ = 1, 150 do
    local x, z = K.spot(17)
    if x and free(x, z, 5) then
      local ang = rnd(0, pi * 2)
      local F = mk(v(x, gh(x, z), z), v(cos(ang), rnd(-0.15, 0.15), sin(ang)), v(-sin(ang), 0, cos(ang)))
      if rnd(0, 1) < 0.8 then
        local wd = rnd(3.5, 6.5)
        local G = at(F, 0, 0, -wd * 0.22)
        if rnd(0, 1) < 0.65 then suitcase(S, G, wd, wd * rnd(1.2, 1.5), wd * 0.38, K.pick(BRIGHT), false)
        else suitcase(S, G, wd * 1.2, wd * 0.5, wd * 0.8, K.pick(BRIGHT), true) end
      else
        F = mk(F.o, v(cos(ang), 0, sin(ang)), F.w)
        pole(S, c.STEEL, F, 0, 0, -1.5, 16, 0.3, 0.16, 6)
        box(D, c.DARK, F, -0.15, 0.15, -2.2, 2.2, 15.6, 16.8)
        for k = 0, 3 do box(D, c.LAMP, F, -0.3, -0.1, -2.05 + k * 1.07, -1.2 + k * 1.07, 15.7, 16.7) end
      end
      taken[#taken + 1] = {x, z, 5}
      built.slope = built.slope + 1
    end
  end
  info(string.format("airport: %d stands, %d towers, %d gantries, %d near pieces, %d cones, %d on the slopes",
    built.stands, built.towers, #gantries, built.near, built.cones, built.slope))
end

return T
