-- Cliffside Caravan Rally's scenery kit: a British seaside caravan park on a cliff top. Touring caravans on gravel
-- pitches down both sides of the road (stripes, awnings, gas bottles, windbreaks, deckchairs), washing lines strung
-- between them and high over the road, static caravans terraced up the slopes behind, a clubhouse by the finish, a
-- chip van and an ice-cream van, bunting, gulls on posts, gorse -- and, down the valley's right-hand edges, white chalk
-- cliffs dropping to the sea, with a lighthouse on the cliff top by the start.
local T = {trees = 0.2}

function T.build(K)
  local col, g, hash, pos, right, W, N = K.col, K.g, K.hash, K.pos, K.right, K.W, K.N
  local UP = v3(0, 1, 0)
  local SEED = K.C.seed or 1
  local WHITE, CREAM, PALE = col(0.9, 0.9, 0.86), col(0.88, 0.78, 0.52), col(0.8, 0.86, 0.8)
  local RED, BLUE, TEAL, ORANGE = col(0.72, 0.05, 0.04), col(0.04, 0.2, 0.62), col(0.0, 0.45, 0.42), col(0.92, 0.36, 0.02)
  local GREEN, BROWN, YELLOW, PINK = col(0.08, 0.42, 0.12), col(0.34, 0.17, 0.07), col(0.98, 0.78, 0.04), col(0.95, 0.3, 0.5)
  local GLASS, DARK, GRAVEL, WOOD = col(0.1, 0.17, 0.26), col(0.06, 0.06, 0.07), col(0.6, 0.57, 0.5), col(0.42, 0.27, 0.13)
  local STEEL, NAVY, GULL_G, LINE = col(0.55, 0.57, 0.6), col(0.03, 0.08, 0.3), col(0.5, 0.53, 0.58), col(0.12, 0.12, 0.13)
  local STRIPES = {RED, BLUE, TEAL, ORANGE, GREEN, BROWN}
  local BRIGHT = {RED, YELLOW, BLUE, WHITE, PINK, ORANGE, TEAL, GREEN}

  -- A piece of the solid part (S) or the drawn-only part (D) for one colour: one colour a piece costs no painting.
  local function S(c) local q = K.sub(K.solid, c); q.ink = c; return q end
  local function D(c) local q = K.sub(K.deco, c); q.ink = c; return q end
  -- An upright box: `base` the middle of its bottom, half-sizes hu along u and hw along w, h tall.
  local function box(b, base, u, w, hu, hw, h) K.slab(b, base, base + v3(0, h, 0), u * hu, w * hw) end
  -- A square bar from p to q, th its half thickness.
  local function bar(b, p, q, th)
    local d = normalize(q - p)
    local a = normalize(cross(d, (math.abs(d.y) > 0.9) and v3(1, 0, 0) or UP))
    K.slab(b, p, q, a * th, cross(d, a) * th)
  end
  -- A profile in the (u, up) plane -- {along u, height} points round it -- pushed hw each way along w.
  local function extrude(b, c, u, w, hw, prof, colour)
    local r1, r2 = {}, {}
    for k, p in ipairs(prof) do
      local q = c + u * p[1] + v3(0, p[2], 0)
      r1[k] = q - w * hw; r2[k] = q + w * hw
    end
    K.prism(b, {r1, r2}, K.flat(colour), colour, colour)
  end
  -- A drum (a wheel, an axle): centre c, its axis along w (hl each way), radius r in the (u, up) plane.
  local function drum(b, c, u, w, hl, r, colour)
    local r1, r2 = {}, {}
    for k = 0, 7 do
      local a = k / 8 * math.pi * 2
      local o = u * (math.cos(a) * r) + v3(0, math.sin(a) * r, 0)
      r1[k + 1] = c - w * hl + o; r2[k + 1] = c + w * hl + o
    end
    K.prism(b, {r1, r2}, K.flat(colour), colour, colour)
  end
  -- A gable roof along u over a footprint (hu, hw), its eaves at c.
  local function gable(b, c, u, w, hu, hw, rise, colour)
    local function sec(s)
      local e = c + u * (s * hu)
      return {e - w * hw, e + v3(0, rise, 0), e + w * hw}
    end
    K.prism(b, {sec(-1), sec(1)}, K.flat(colour), colour, colour)
  end
  local function one() return 1 end

  -- How far (x, z) is off the road's edge; ground taken (circles) by what is built already.
  local function edge(x, z) local _, d = K.ground_d(x, z); return d - K.HW end
  local taken = {}
  local function free(x, z, r)
    for _, q in ipairs(taken) do
      local dx, dz, rr = x - q[1], z - q[2], r + q[3]
      if dx * dx + dz * dz < rr * rr then return false end
    end
    return true
  end
  local function claim(x, z, r) taken[#taken + 1] = {x, z, r} end
  -- The lowest and the highest ground under a footprint.
  local function span(c, u, w, hu, hw)
    local lo, hi = math.huge, -math.huge
    for _, a in ipairs({{1, 1}, {-1, 1}, {-1, -1}, {1, -1}, {0, 0}}) do
      local p = c + u * (a[1] * hu) + w * (a[2] * hw)
      local y = K.ground(p.x, p.z)
      lo = math.min(lo, y); hi = math.max(hi, y)
    end
    return lo, hi
  end
  -- A levelled pitch: a gravel terrace under a footprint, its top returned.
  local function pad(c, u, w, hu, hw, share)
    local lo, hi = span(c, u, w, hu, hw)
    local y = lo + (hi - lo) * share + 0.08
    K.slab(S(GRAVEL), v3(c.x, lo - 0.7, c.z), v3(c.x, y, c.z), u * hu, w * hw)
    return y
  end

  -- A gull standing at p, looking along d; s its size. One in flight, wings out.
  local function gull(p, d, s)
    K.ball(D(WHITE), p + v3(0, 0.2 * s, 0), 0.2 * s, 0.17 * s, 0.2 * s, 6, 4, one, K.flat(WHITE))
    K.ball(D(WHITE), p + d * (0.2 * s) + v3(0, 0.4 * s, 0), 0.11 * s, 0.11 * s, 0.11 * s, 5, 3, one, K.flat(WHITE))
    local sd = v3(-d.z, 0, d.x)
    K.slab(D(GULL_G), p + d * (0.1 * s) + v3(0, 0.31 * s, 0), p - d * (0.42 * s) + v3(0, 0.27 * s, 0), sd * (0.17 * s), v3(0, 0.05 * s, 0))
    bar(D(YELLOW), p + d * (0.27 * s) + v3(0, 0.39 * s, 0), p + d * (0.45 * s) + v3(0, 0.36 * s, 0), 0.03 * s)
  end
  local function flier(p, d, s)
    local sd = v3(-d.z, 0, d.x)
    bar(D(WHITE), p - d * (0.35 * s), p + d * (0.35 * s), 0.09 * s)
    for k = -1, 1, 2 do
      K.slab(D(GULL_G), p + sd * (k * 0.08 * s), p + sd * (k * 0.95 * s) + v3(0, 0.3 * s, 0), d * (0.16 * s), v3(0, 0.025 * s, 0))
    end
  end

  -- A line from a to b sagging `sag` in the middle: its point at t, and the line itself.
  local function hang(a, b, sag)
    local function P(t) return lerp(a, b, t) - v3(0, sag * 4 * t * (1 - t), 0) end
    for k = 0, 4 do bar(D(LINE), P(k / 5 + 0.004), P((k + 1) / 5 - 0.004), 0.025) end
    local d = normalize(v3(b.x - a.x, 0, b.z - a.z))
    return P, d, v3(-d.z, 0, d.x), length(b - a)
  end
  -- A washing line: shirts, sheets, towels and trousers pegged along it (none hangs lower than 0.95 under it).
  local function washing(a, b, sag)
    local P, d, n, len = hang(a, b, sag)
    local count = math.floor(len / 1.25)
    for k = 1, count do
      local t = (k - 0.5) / count
      local h = hash(a.x + k * 7.3, a.z)
      local c = BRIGHT[math.floor(hash(k * 3.7, a.x + b.z) * #BRIGHT) + 1]
      local top = P(t) - v3(0, 0.03, 0)
      if t > 0.07 and t < 0.93 then
        if h < 0.3 then          -- a shirt: body and sleeves
          K.slab(D(c), top - v3(0, 0.8, 0), top, d * 0.3, n * 0.02)
          K.slab(D(c), top - v3(0, 0.3, 0), top - v3(0, 0.02, 0), d * 0.5, n * 0.024)
        elseif h < 0.55 then     -- a sheet
          K.slab(D(c), top - v3(0, 0.95, 0), top, d * 0.52, n * 0.02)
        elseif h < 0.8 then      -- a towel
          K.slab(D(c), top - v3(0, 0.9, 0), top, d * 0.26, n * 0.02)
        else                     -- trousers
          K.slab(D(BLUE), top - v3(0, 0.92, 0) - d * 0.17, top - d * 0.17, d * 0.13, n * 0.02)
          K.slab(D(BLUE), top - v3(0, 0.92, 0) + d * 0.17, top + d * 0.17, d * 0.13, n * 0.02)
        end
      end
    end
  end
  -- Bunting: pennants 0.6 wide and 0.7 deep along a line.
  local function bunting(a, b, sag)
    local P, d, n, len = hang(a, b, sag)
    local count = math.floor(len / 0.85)
    for k = 1, count do
      local p = P((k - 0.5) / count) - v3(0, 0.02, 0)
      local c = BRIGHT[(k + math.floor(a.x)) % #BRIGHT + 1]
      local tri = {p - d * 0.3, p + d * 0.3, p - v3(0, 0.7, 0)}
      local r1, r2 = {}, {}
      for q = 1, 3 do r1[q] = tri[q] - n * 0.015; r2[q] = tri[q] + n * 0.015 end
      K.prism(D(c), {r1, r2}, K.flat(c), c, c)
    end
  end

  -- A deckchair on the grass at p facing f: a striped sling in a wooden frame.
  local function deckchair(p, f, c)
    local q = 1.3
    local s = v3(-f.z, 0, f.x)
    p = v3(p.x, K.ground(p.x, p.z) - 0.05, p.z)
    local A, B = p + f * (0.35 * q) + v3(0, 0.28 * q, 0), p - f * (0.45 * q) + v3(0, 1.05 * q, 0)
    local nrm = normalize(cross(B - A, s)) * 0.018
    for k = -1, 1 do
      K.slab(D(k == 0 and WHITE or c), A + s * (k * 0.2 * q), B + s * (k * 0.2 * q), s * (0.097 * q), nrm)
    end
    for k = -1, 1, 2 do
      local o = s * (k * 0.34 * q)
      bar(D(WOOD), p + f * (0.55 * q) + o - v3(0, 0.3, 0), p - f * (0.5 * q) + o + v3(0, 1.12 * q, 0), 0.03)
      bar(D(WOOD), p - f * (0.65 * q) + o - v3(0, 0.3, 0), p + f * (0.05 * q) + o + v3(0, 0.62 * q, 0), 0.03)
    end
  end
  -- A windbreak: n striped panels zig-zagging along d through p, on wooden stakes.
  local function windbreak(p, d, n, ca, cb)
    local nr = v3(-d.z, 0, d.x)
    local y = K.ground(p.x, p.z)
    local pts = {}
    for k = 0, n do
      local q = p + d * ((k - n / 2) * 0.9) + nr * ((k % 2) * 0.3)
      pts[k] = v3(q.x, y, q.z)
      bar(D(WOOD), pts[k] - v3(0, 0.7, 0), pts[k] + v3(0, 1.5, 0), 0.035)
    end
    for k = 0, n - 1 do
      local a, b = pts[k], pts[k + 1]
      local m, hd = (a + b) * 0.5, (b - a) * 0.485
      local c = (k % 2 == 1) and WHITE or ((k % 4 == 0) and ca or cb)
      K.slab(D(c), m + v3(0, 0.1, 0), m + v3(0, 1.35, 0), hd, normalize(cross(hd, UP)) * 0.018)
    end
  end
  -- A striped awning off a wall: from p (the middle of its top edge) out along w by `out`, dropping `drop`, n strips
  -- `pitch` wide along u.
  local function awning(p, u, w, n, pitch, out, drop, ca, cb)
    for k = 1, n do
      local a = p + u * ((k - (n + 1) / 2) * pitch)
      K.slab(D((k % 2 == 1) and ca or cb), a, a + w * out - v3(0, drop, 0), u * (pitch * 0.485), v3(0, 0.03, 0))
    end
  end

  -- A touring caravan: c the middle of its pitch's top, u its length (the hitch at +u), w its door side.
  local function caravan(c, u, w, body, stripe)
    extrude(S(body), c, u, w, 1.1, {{-2.6, 0.8}, {-2.4, 0.45}, {2.4, 0.45}, {2.6, 0.8}, {2.6, 2.05}, {2.35, 2.6}, {-2.35, 2.6}, {-2.6, 2.05}}, body)
    box(D(stripe), c + v3(0, 1.0, 0), u, w, 2.625, 1.125, 0.3)
    local gl = D(GLASS)
    box(gl, c + u * -1.5 + w * 1.1 + v3(0, 1.45, 0), u, w, 0.55, 0.035, 0.55)
    box(gl, c + u * 1.4 + w * 1.1 + v3(0, 1.45, 0), u, w, 0.65, 0.035, 0.55)
    box(gl, c - w * 1.1 + v3(0, 1.45, 0), u, w, 1.3, 0.035, 0.55)
    box(gl, c + u * 2.6 + v3(0, 1.45, 0), u, w, 0.035, 0.8, 0.52)
    box(gl, c - u * 2.6 + v3(0, 1.45, 0), u, w, 0.035, 0.8, 0.52)
    box(D(stripe), c + u * 0.1 + w * 1.1 + v3(0, 0.5, 0), u, w, 0.3, 0.05, 1.85)
    drum(D(DARK), c - u * 0.2 + v3(0, 0.36, 0), u, w, 1.17, 0.36, DARK)
    bar(D(STEEL), c + u * 2.5 + v3(0, 0.5, 0), c + u * 3.8 + v3(0, 0.5, 0), 0.06)
    bar(D(STEEL), c + u * 3.65 - v3(0, 0.2, 0), c + u * 3.65 + v3(0, 0.5, 0), 0.04)
    local p1, p2 = c + u * 2.86 + w * 0.24, c + u * 2.86 - w * 0.24
    K.column(D(ORANGE), p1.x, p1.z, c.y + 0.5, c.y + 1.15, 0.17, 0.17, 6, ORANGE)
    K.column(D(BLUE), p2.x, p2.z, c.y + 0.5, c.y + 1.05, 0.17, 0.17, 6, BLUE)
  end

  -- A static caravan (a holiday home): long and low under a shallow roof, a deck and patio doors on its w side.
  local SHADES = {CREAM, PALE, WHITE, col(0.72, 0.82, 0.9), col(0.9, 0.84, 0.7)}
  local ROOFS = {col(0.3, 0.31, 0.33), col(0.16, 0.3, 0.2), col(0.36, 0.2, 0.12)}
  local function static(c, u, w, body, stripe, roof)
    box(S(DARK), c, u, w, 4.3, 1.45, 0.42)
    box(S(body), c + v3(0, 0.38, 0), u, w, 4.4, 1.55, 2.4)
    gable(S(roof), c + v3(0, 2.74, 0), u, w, 4.6, 1.78, 0.6, roof)
    box(D(stripe), c + v3(0, 1.0, 0), u, w, 4.42, 1.57, 0.22)
    local gl = D(GLASS)
    box(gl, c + u * -2.3 + w * 1.55 + v3(0, 0.5, 0), u, w, 0.9, 0.04, 1.85)
    box(gl, c + u * 0.7 + w * 1.55 + v3(0, 1.35, 0), u, w, 0.7, 0.04, 0.9)
    box(gl, c + u * 2.9 + w * 1.55 + v3(0, 1.35, 0), u, w, 0.7, 0.04, 0.9)
    box(gl, c + u * 4.4 + v3(0, 1.35, 0), u, w, 0.04, 1.0, 0.9)
    box(D(WOOD), c + u * -0.9 + w * 2.5 + v3(0, 0.02, 0), u, w, 3.2, 0.93, 0.36)
    local r0, r1 = c + u * -4.05 + w * 3.38 + v3(0, 1.3, 0), c + u * 2.25 + w * 3.38 + v3(0, 1.3, 0)
    bar(D(WHITE), r0, r1, 0.05)
    for k = 0, 3 do
      local p = lerp(r0, r1, k / 3 * 0.98 + 0.01)
      bar(D(WHITE), p - v3(0, 1.0, 0), p - v3(0, 0.06, 0), 0.045)
    end
    local p1 = c - u * 4.62 + w * 0.4
    K.column(D(ORANGE), p1.x, p1.z, c.y, c.y + 1.1, 0.19, 0.19, 6, ORANGE)
  end

  -- A van with a serving hatch on its w side: the ice-cream van (a great cone on its roof) or the chip van (a sign
  -- board and a cone of chips).
  local WAFER, CHOC = col(0.8, 0.52, 0.2), col(0.25, 0.11, 0.04)
  local function van(c, u, w, ice)
    local body, top, a1 = ice and WHITE or NAVY, ice and PINK or WHITE, ice and PINK or RED
    extrude(S(body), c, u, w, 1.0, {{-2.3, 0.45}, {2.3, 0.45}, {2.3, 1.25}, {1.75, 1.4}, {1.35, 2.55}, {-2.3, 2.55}}, body)
    box(D(top), c - u * 0.56 + v3(0, 1.95, 0), u, w, 1.76, 1.02, 0.63)
    box(D(GLASS), c - u * 0.7 + w * 1.0 + v3(0, 1.1, 0), u, w, 1.0, 0.04, 0.8)
    K.slab(D(GLASS), c + u * 1.74 + v3(0, 1.5, 0), c + u * 1.4 + v3(0, 2.42, 0), w * 0.88, u * 0.05)
    awning(c - u * 0.7 + w * 1.03 + v3(0, 2.1, 0), u, w, 5, 0.46, 1.1, 0.3, a1, WHITE)
    drum(D(DARK), c + u * 1.45 + v3(0, 0.36, 0), u, w, 1.05, 0.36, DARK)
    drum(D(DARK), c - u * 1.45 + v3(0, 0.36, 0), u, w, 1.05, 0.36, DARK)
    if ice then
      local p = c - u * 0.6
      K.column(D(WAFER), p.x, p.z, c.y + 2.5, c.y + 4.3, 0.1, 0.62, 8, WAFER)
      K.ball(D(WHITE), p + v3(0, 4.55, 0), 0.72, 0.6, 0.72, 8, 5, one, K.flat(WHITE))
      K.ball(D(PINK), p + v3(0, 5.2, 0), 0.5, 0.45, 0.5, 7, 4, one, K.flat(PINK))
      bar(D(CHOC), p + u * 0.25 + v3(0, 4.9, 0), p + u * 0.85 + v3(0, 5.95, 0), 0.1)
    else
      box(D(YELLOW), c - u * 0.5 + w * 0.85 + v3(0, 2.57, 0), u, w, 1.75, 0.07, 1.0)
      box(D(RED), c - u * 0.5 + w * 0.93 + v3(0, 2.87, 0), u, w, 1.35, 0.03, 0.4)
      local p = c - u * 0.7 - w * 0.2
      K.column(D(WHITE), p.x, p.z, c.y + 2.5, c.y + 3.9, 0.12, 0.6, 8, WHITE)
      for k = 0, 6 do
        local a = k * 0.9
        local o = v3(math.cos(a), 0, math.sin(a))
        bar(D(YELLOW), p + o * 0.15 + v3(0, 3.6, 0), p + o * (0.3 + 0.07 * k) + v3(0, 4.45 + 0.08 * (k % 3), 0), 0.08)
      end
    end
  end

  -- A site by the road: from sample i0 on, either side, a footprint (hu along the road, hw across) centred `off` past
  -- the road's edge, clear of every other bend and of what is built. Its centre, the road's way, the way out, or nil.
  local function site(i0, i1, off, hu, hw, first)
    for i = i0, i1, (i1 >= i0) and 2 or -2 do
      for s = 1, 2 do
        local side = ((s == 1) == (first == 1)) and 1 or -1
        local r, t = right[i] * side, K.along(i)
        local c = pos[i] + r * (W[i] + off)
        local ok = edge(c.x, c.z) > off - 0.8 and free(c.x, c.z, math.max(hu, hw) + 1)
        for _, a in ipairs({{1, 1}, {-1, 1}, {-1, -1}, {1, -1}}) do
          local p = c + t * (a[1] * hu) + r * (a[2] * hw)
          if ok and edge(p.x, p.z) < off - hw - 0.8 then ok = false end
        end
        if ok then return c, t, r end
      end
    end
  end

  -- The clubhouse: cream walls under a red roof, a veranda with a striped canopy towards the road, a sign on the
  -- ridge, a flagpole, parasols beside it.
  ;(function()
    local c, t, r = site(math.min(N - 3, K.fin + 4), math.min(N - 1, K.fin + 14), 12.5, 9, 6.6, 1)
    if not c then c, t, r = site(K.fin - 12, K.start + 20, 12.5, 9, 6.6, 1) end
    if not c then return end
    claim(c.x, c.z, 12.5)
    local u, w = t, r * -1
    local pc = c + w * 1.3
    local y = pad(pc, u, w, 9.2, 5.9, 0.7)
    c = v3(c.x, y, c.z)
    local TILE, WALL = col(0.62, 0.13, 0.08), col(0.9, 0.82, 0.6)
    box(S(WALL), c, u, w, 8, 4, 3.6)
    gable(S(TILE), c + v3(0, 3.55, 0), u, w, 8.7, 4.7, 2.5, TILE)
    box(D(WOOD), c + w * 5.4 + v3(0, 0.02, 0), u, w, 8.3, 1.38, 0.25)
    awning(c + w * 3.95 + v3(0, 3.35, 0), u, w, 8, 2.1, 2.9, 0.55, GREEN, WHITE)
    for k = -2, 2 do
      local p = c + u * (k * 4.05) + w * 6.6
      bar(D(WHITE), p + v3(0, 0.2, 0), p + v3(0, 2.85, 0), 0.08)
    end
    for _, o in ipairs({-6, -3.3, 3.3, 6}) do box(D(GLASS), c + u * o + w * 4 + v3(0, 1.2, 0), u, w, 1.0, 0.05, 1.3) end
    box(D(BLUE), c + w * 4 + v3(0, 0.25, 0), u, w, 1.1, 0.06, 2.35)
    box(D(GLASS), c + u * 8 + v3(0, 1.2, 0), u, w, 0.05, 2.2, 1.3)
    box(D(GLASS), c - u * 8 + v3(0, 1.2, 0), u, w, 0.05, 2.2, 1.3)
    box(D(BLUE), c + v3(0, 5.7, 0), u, w, 4.2, 0.12, 1.5)
    box(D(YELLOW), c + v3(0, 6.15, 0), u, w, 3.7, 0.16, 0.6)
    local f = c + u * 8.6 + w * 5.2
    K.column(S(WHITE), f.x, f.z, y - 0.2, y + 10, 0.1, 0.07, 6, WHITE)
    for k, fc in ipairs({RED, WHITE, BLUE}) do
      K.slab(D(fc), f + v3(0, 9.9 - k * 0.42, 0) + u * 0.1, f + v3(0, 9.9 - k * 0.42, 0) + u * 2.1, v3(0, 0.205, 0), w * 0.02)
    end
    bunting(c + u * 8.6 + w * 5.2 + v3(0, 8.2, 0), c - u * 8.3 + w * 6.6 + v3(0, 3.4, 0), 0.6)
    local par = K.sub(K.deco, "parasol")
    for k = 0, 2 do
      local p = c - u * (5.5 - k * 5.5) + w * 5.4
      K.column(D(WOOD), p.x, p.z, y + 0.2, y + 2.55, 0.05, 0.05, 5, WOOD)
      K.column(D(WHITE), p.x, p.z, y + 0.9, y + 0.98, 0.6, 0.6, 8, WHITE)
      local a, b2 = BRIGHT[k + 1], WHITE
      K.cone(par, K.ring(v3(p.x, y + 2.3, p.z), 1.15, 1.15, 8, 0), v3(p.x, y + 2.3, p.z), v3(p.x, y + 2.85, p.z),
        function(q) return (q % 2 == 0) and a or b2 end, WHITE)
    end
  end)()

  -- The vans, parked hatch to the road.
  for k, f in ipairs({0.2, 0.42, 0.63, 0.83}) do
    local i0 = math.floor(K.start + (K.fin - K.start) * f)
    local c, t, r = site(i0, math.min(N - 1, i0 + 16), 5.6, 3.0, 1.4, (k % 2 == 0) and 1 or -1)
    if c then
      claim(c.x, c.z, 4)
      local u, w = t, r * -1
      local y = pad(c, u, w, 3.0, 1.45, 0.9)
      van(v3(c.x, y, c.z), u, w, k % 2 == 1)
    end
  end

  -- Over the road, on tall poles each side: washing lines and bunting by turns, nothing lower than 6.5 m over it.
  ;(function()
    local n = 0
    for i = 6, N - 4, 9 do
      if math.abs(i - K.start) > 7 and math.abs(i - K.fin) > 7 then
        local r = right[i]
        local o = W[i] + 2.9
        local a, b = pos[i] + r * o, pos[i] - r * o
        if edge(a.x, a.z) > 2.4 and edge(b.x, b.z) > 2.4 and free(a.x, a.z, 0.6) and free(b.x, b.z, 0.6) then
          n = n + 1
          local top = pos[i].y + math.max(0, K.lift(i, 1) or 0, K.lift(i, -1) or 0) + 8.5
          for _, p in ipairs({a, b}) do
            claim(p.x, p.z, 0.5)
            K.column(S(WOOD), p.x, p.z, K.ground(p.x, p.z) - 0.8, top + 0.25, 0.14, 0.09, 6, WOOD)
          end
          a, b = v3(a.x, top, a.z), v3(b.x, top, b.z)
          if n % 2 == 1 then washing(a, b, 0.5) else bunting(a, b, 0.7) end
        end
      end
    end
  end)()

  -- The pitches: a touring caravan every ten metres or so down each side -- some side-on close to the road, some set
  -- back behind an awning, deckchairs and a windbreak -- with gulls on posts between, and washing lines from one
  -- caravan's pole to the next's.
  local function pitch(i, side, prev)
    local r, t = right[i] * side, K.along(i)
    local back = hash(i * 3.1, side + SEED) < 0.45
    local off = back and 10 or 6.4
    local c = pos[i] + r * (W[i] + off)
    if edge(c.x, c.z) < off - 0.8 or not free(c.x, c.z, 4.2) then return nil end
    for k = -1, 1, 2 do
      local p = c + t * (k * 3.7) - r * 1.3
      if edge(p.x, p.z) < 3.4 then return nil end
    end
    claim(c.x, c.z, 3.9)
    local u = t * ((hash(i, 7 + side) < 0.5) and 1 or -1)
    local w = r * -1
    local y = pad(c + u * 0.5, u, w, 3.7, 1.5, 0.9)
    local body = K.pick({WHITE, CREAM, WHITE, CREAM, PALE})
    local stripe = K.pick(STRIPES)
    local cc = v3(c.x, y, c.z)
    caravan(cc, u, w, body, stripe)
    if hash(i, 31) < 0.3 then gull(cc + u * g:range(-1.8, 1.8) + v3(0, 2.6, 0), normalize(t + r * g:range(-1, 1)), 1.5) end
    local bright = K.pick({RED, BLUE, TEAL, ORANGE, YELLOW, GREEN})
    if back then
      awning(cc - u * 0.3 + w * 1.12 + v3(0, 2.4, 0), u, w, 6, 0.63, 2.5, 0.45, stripe, WHITE)
      for k = -1, 1, 2 do
        local p = cc - u * 0.3 + u * (k * 1.8) + w * 3.55
        bar(D(STEEL), v3(p.x, K.ground(p.x, p.z) - 0.4, p.z), p + v3(0, 1.97, 0), 0.035)
      end
      deckchair(c + w * 4.9 + u * 0.95, w, bright)
      deckchair(c + w * 4.7 - u * 0.95, normalize(w + u * 0.3), K.pick(BRIGHT))
      local a, b = c + w * 6.4 + t * 2.9, c + w * 6.4 - t * 2.9
      if edge(a.x, a.z) > 2.7 and edge(b.x, b.z) > 2.7 then windbreak(c + w * 6.4, t, 6, bright, stripe) end
    else
      local a, b = c + w * 3.2 + t * 2.5, c + w * 3.2 - t * 2.5
      if hash(i, 53) < 0.6 and edge(a.x, a.z) > 2.6 and edge(b.x, b.z) > 2.6 then
        windbreak(c + w * 3.2, t, 5, bright, stripe)
        deckchair(c + w * 2.15 + u * 1.3, w, bright)
      end
    end
    -- Its washing poles (one at each end, behind it), put up when a line is strung from them.
    local me = {a = cc - t * 2.95 + r * 0.9 + v3(0, 4.9, 0), b = cc + t * 2.95 + r * 0.9 + v3(0, 4.9, 0), y = y}
    if prev then
      local d = length(me.a - prev.b)
      local m = (me.a + prev.b) * 0.5
      if d > 2.5 and d < 17 and edge(m.x, m.z) > 4.5 then
        bar(D(STEEL), prev.b - v3(0, 4.95, 0), prev.b + v3(0, 0.1, 0), 0.05)
        bar(D(STEEL), me.a - v3(0, 4.95, 0), me.a + v3(0, 0.1, 0), 0.05)
        washing(prev.b, me.a, 0.4)
      end
    end
    return me
  end
  for side = -1, 1, 2 do
    local acc, mid, prev = 3 + side * 2, false, nil
    for i = 3, N - 1 do
      acc = acc + length(pos[i] - pos[i - 1])
      if not mid and acc >= 5.2 then
        mid = true
        local p = pos[i] + right[i] * (side * (W[i] + 2.7))
        if hash(i, side * 5) < 0.75 and edge(p.x, p.z) > 2.3 and free(p.x, p.z, 0.6) then
          local y = K.ground(p.x, p.z)
          local h = 1.5 + hash(i, 3) * 0.9
          K.column(S(WOOD), p.x, p.z, y - 0.8, y + h, 0.1, 0.085, 6, WOOD)
          local a = g:range(0, 6.28)
          gull(v3(p.x, y + h, p.z), v3(math.cos(a), 0, math.sin(a)), 1.7)
        end
      end
      if acc >= 10.6 then
        prev = pitch(i, side, prev)
        acc, mid = 0, false
      end
    end
  end

  -- The static caravans: two terraced rows up each slope behind the pitches.
  for _, off in ipairs({19.5, 32}) do
    for side = -1, 1, 2 do
      local acc = off * 0.3
      for i = 3, N - 1 do
        acc = acc + length(pos[i] - pos[i - 1])
        if acc >= 14.5 then
          acc = 0
          local r, t = right[i] * side, K.along(i)
          local c = pos[i] + r * (W[i] + off)
          if hash(i, off + side) < 0.72 and edge(c.x, c.z) > off - 1 and free(c.x, c.z, 5) then
            claim(c.x, c.z, 5)
            local u, w = t * ((hash(i, off) < 0.5) and 1 or -1), r * -1
            local y = pad(c + w * 0.95, u, w, 4.9, 2.6, 0.85)
            static(v3(c.x, y, c.z), u, w, K.pick(SHADES), K.pick(STRIPES), K.pick(ROOFS))
          end
        end
      end
    end
  end

  -- Gorse: dark green clumps crowned in yellow flower, thick along the road and thinner up the slopes.
  ;(function()
    local G1, G2, FLOWER = col(0.1, 0.27, 0.08), col(0.06, 0.17, 0.06), col(0.98, 0.76, 0.03)
    local n = 0
    local function clump(x, z)
      n = n + 1
      local b = K.sub(K.deco, "gorse" .. (n % 4))
      for k = 1, (n % 3 == 0) and 3 or 2 do
        local px, pz = x + ((k == 1) and 0 or g:range(-1.2, 1.2)), z + ((k == 1) and 0 or g:range(-1.2, 1.2))
        local s = g:range(0.75, 1.3)
        local seedk = n * 5 + k
        K.ball(b, v3(px, K.ground(px, pz) + 0.35 * s, pz), 1.05 * s, 0.95 * s, 1.05 * s, 7, 4,
          function() return g:range(0.85, 1.12) end,
          function(wv)
            local ny = wv.y / math.max(1e-6, length(wv))
            if ny > 0.4 and hash(wv.x * 9.1 + seedk, wv.z * 7.7) < 0.7 then return FLOWER end
            return (ny > -0.2) and G1 or G2
          end)
      end
    end
    for _ = 1, 340 do
      local i = math.floor(g:range(3, N - 1))
      local side = (g:range(0, 1) < 0.5) and -1 or 1
      local f = g:range(0, 1)
      local off = 4.9 + f * f * 34
      local p = pos[i] + right[i] * (side * (W[i] + off))
      if edge(p.x, p.z) > 4.8 and free(p.x, p.z, 1.8) then clump(p.x, p.z) end
    end
    for _ = 1, 160 do
      local x, z = K.spot(26)
      if x and free(x, z, 1.8) then clump(x, z) end
    end
  end)()

  -- Gulls wheeling high over the park.
  for _ = 1, 26 do
    local i = math.floor(g:range(3, N - 1))
    local a = g:range(0, 6.28)
    flier(pos[i] + v3(g:range(-35, 35), g:range(13, 30), g:range(-35, 35)), v3(math.cos(a), 0, math.sin(a)), 1.7)
  end

  -- The sea side: the valley's right-hand edges (x = X1 and z = Z1) are the cliff's lip. White chalk faces drop from
  -- the turf to the sea far below, a scree at their foot, surf and shallows along it, stacks and sailing boats out
  -- in the blue; a white rail along the cliff top; the lighthouse on the lip by the start.
  ;(function()
    local X0, X1, Z0, Z1 = K.X0, K.X1, K.Z0, K.Z1
    local low = math.huge
    for i = 1, N do low = math.min(low, pos[i].y) end
    local sea = low - 32
    local CHALK = {col(0.93, 0.92, 0.86), col(0.84, 0.83, 0.76), col(0.76, 0.76, 0.7)}
    local SCREE, TURF = col(0.66, 0.66, 0.6), K.tint(K.GRASS, 0.85)
    local SEA, SHALLOW, SURF = col(0.03, 0.2, 0.5), col(0.05, 0.42, 0.62), col(0.82, 0.92, 0.95)
    -- (p0 the run's start on the lip, d along it, o out to sea.)
    local function cliffs(p0, d, o, len, key)
      local n = math.ceil(len / 13)
      for k = 0, n - 1 do
        local a, b = p0 + d * (k * len / n + 0.04), p0 + d * ((k + 1) * len / n - 0.04)
        local m = (a + b) * 0.5
        local yt = math.max(K.ground(a.x, a.z), K.ground(b.x, b.z), K.ground(m.x, m.z)) + 0.25
        local o1 = 1.5 + 4.5 * hash(k, key)
        local o2 = o1 + 5 + 12 * hash(k + 50, key)
        local function at(p, out, y) return v3(p.x, y, p.z) + o * out end
        K.hexa(D(CHALK[math.floor(hash(k, key + 9) * 3) + 1]),
          at(a, 0.06, sea - 1), at(b, 0.06, sea - 1), at(b, o2, sea - 1), at(a, o2, sea - 1),
          at(a, 0.06, yt), at(b, 0.06, yt), at(b, o1, yt), at(a, o1, yt))
        local hs = (yt - sea) * (0.18 + 0.2 * hash(k, key + 3))
        local a2, b2 = a + d * 0.7, b - d * 0.7
        K.hexa(D(SCREE),
          at(a2, 0.1, sea - 1.2), at(b2, 0.1, sea - 1.2), at(b2, o2 + 9, sea - 1.2), at(a2, o2 + 9, sea - 1.2),
          at(a2, 0.1, sea + hs), at(b2, 0.1, sea + hs), at(b2, o2 + 1.5, sea + hs), at(a2, o2 + 1.5, sea + hs))
      end
    end
    cliffs(v3(X1, 0, Z0), v3(0, 0, -1), v3(1, 0, 0), Z0 - Z1, 11)
    cliffs(v3(X1, 0, Z1), v3(-1, 0, 0), v3(0, 0, -1), X1 - X0, 23)
    -- (the corner between the two runs)
    local yc = K.ground(X1, Z1) + 0.25
    K.hexa(D(CHALK[1]),
      v3(X1 + 0.06, sea - 1, Z1 - 0.06), v3(X1 + 16, sea - 1, Z1 - 0.06), v3(X1 + 16, sea - 1, Z1 - 16), v3(X1 + 0.06, sea - 1, Z1 - 16),
      v3(X1 + 0.06, yc, Z1 - 0.06), v3(X1 + 4, yc, Z1 - 0.06), v3(X1 + 4, yc, Z1 - 4), v3(X1 + 0.06, yc, Z1 - 4))
    -- The sea, the shallows and the surf: flat sheets, each a little over the last.
    local function sheet(c, x0, x1, z0, z1, y)
      K.hexa(D(c), v3(x0, y - 0.4, z0), v3(x1, y - 0.4, z0), v3(x1, y - 0.4, z1), v3(x0, y - 0.4, z1),
        v3(x0, y, z0), v3(x1, y, z0), v3(x1, y, z1), v3(x0, y, z1))
    end
    sheet(SEA, X0 - 12, X1 + 150, Z1 - 150, Z0 + 12, sea)
    sheet(SHALLOW, X1 + 0.2, X1 + 46, Z1 - 46, Z0 + 12, sea + 0.12)
    sheet(SHALLOW, X0 - 12, X1, Z1 - 46, Z1 - 0.2, sea + 0.12)
    sheet(SURF, X1 + 0.4, X1 + 31, Z1 - 31, Z0 + 12, sea + 0.24)
    sheet(SURF, X0 - 12, X1 + 0.2, Z1 - 31, Z1 - 0.4, sea + 0.24)
    -- Chalk stacks off the corner and along the shore, turf on their heads.
    for k = 1, 7 do
      local along = hash(k, 77)
      local x, z
      if k % 2 == 0 then x, z = X1 + 40 + 45 * hash(k, 5), Z1 + (Z0 - Z1) * along
      else x, z = X0 + (X1 - X0) * along, Z1 - 40 - 45 * hash(k, 6) end
      local h = 14 + 22 * hash(k, 8)
      local rr = 4 + 4 * hash(k, 9)
      K.column(D(CHALK[k % 3 + 1]), x, z, sea - 1, sea + h, rr * 1.5, rr, 7, CHALK[k % 3 + 1], k)
      K.column(D(TURF), x, z, sea + h - 0.3, sea + h + 0.7, rr * 0.96, rr * 0.7, 7, TURF, k)
    end
    -- Sailing boats.
    for k = 1, 6 do
      local x, z
      if k % 2 == 0 then x, z = X1 + 60 + 70 * hash(k, 15), Z1 + (Z0 - Z1) * hash(k, 16)
      else x, z = X0 + (X1 - X0) * hash(k, 17), Z1 - 60 - 70 * hash(k, 18) end
      local a = hash(k, 19) * 6.28
      local d = v3(math.cos(a), 0, math.sin(a))
      local n = v3(-d.z, 0, d.x)
      local p = v3(x, sea + 0.3, z)
      K.slab(D((k % 3 == 0) and BLUE or RED), p - d * 4, p + d * 4, n * 1.3, v3(0, 0.7, 0))
      local tri = {p - d * 2.6 + v3(0, 1.2, 0), p + d * 2.2 + v3(0, 1.2, 0), p + d * 0.4 + v3(0, 10, 0)}
      local r1, r2 = {}, {}
      for q = 1, 3 do r1[q] = tri[q] - n * 0.08; r2[q] = tri[q] + n * 0.08 end
      K.prism(D(WHITE), {r1, r2}, K.flat(WHITE), WHITE, WHITE)
    end
    -- The rail along the cliff top.
    local function rail(p0, d, len)
      local n = math.floor(len / 8)
      local last
      for k = 0, n do
        local p = p0 + d * (k * len / n)
        local top = v3(p.x, K.ground(p.x, p.z) + 1.25, p.z)
        bar(D(WHITE), top - v3(0, 1.9, 0), top + v3(0, 0.12, 0), 0.09)
        if last then bar(D(WHITE), lerp(last, top, 0.02), lerp(last, top, 0.98), 0.06) end
        last = top
      end
    end
    rail(v3(X1 - 3.5, 0, Z0 - 4), v3(0, 0, -1), Z0 - Z1 - 8)
    rail(v3(X1 - 4.5, 0, Z1 + 3.5), v3(-1, 0, 0), X1 - X0 - 9)
    -- The lighthouse: red and white bands, a gallery, the lantern and its cap; the keeper's cottage beside it.
    local lx, lz = X1 - 11, pos[K.start].z - 34
    if edge(lx, lz) > 20 then
      local y = K.ground(lx, lz) - 1.5
      local H = 34
      local rings = {}
      for j = 0, 5 do
        local f = j / 5
        rings[#rings + 1] = K.ring(v3(lx, y + H * f, lz), 4.6 - 1.9 * f, 4.6 - 1.9 * f, 12, 0)
      end
      K.prism(K.sub(K.solid, "lighthouse"), rings, function(j, _) return (j % 2 == 1) and RED or WHITE end, WHITE, WHITE)
      K.column(S(DARK), lx, lz, y + H - 0.3, y + H + 0.4, 3.7, 3.7, 12, DARK)
      K.column(S(YELLOW), lx, lz, y + H + 0.3, y + H + 3.6, 2.0, 2.0, 8, YELLOW)
      K.cone(S(RED), K.ring(v3(lx, y + H + 3.55, lz), 2.5, 2.5, 8, 0), v3(lx, y + H + 3.55, lz), v3(lx, y + H + 5.8, lz), K.flat(RED), RED)
      box(D(BLUE), v3(lx - 4.5, y + 1.3, lz), v3(0, 0, 1), v3(1, 0, 0), 0.6, 0.25, 2.2)
      gull(v3(lx, y + H + 5.8, lz), v3(-1, 0, 0), 2.2)
      local c = v3(lx - 2, 0, lz - 11)
      local u, w = v3(0, 0, 1), v3(-1, 0, 0)
      local yk = pad(c, u, w, 4.6, 3.4, 0.8)
      c = v3(c.x, yk, c.z)
      box(S(WHITE), c, u, w, 4, 2.8, 2.9)
      gable(S(RED), c + v3(0, 2.85, 0), u, w, 4.4, 3.3, 1.9, RED)
      box(D(GLASS), c + w * 2.8 + u * 2 + v3(0, 1.1, 0), u, w, 0.7, 0.05, 1.0)
      box(D(GLASS), c + w * 2.8 - u * 2 + v3(0, 1.1, 0), u, w, 0.7, 0.05, 1.0)
      box(D(BLUE), c + w * 2.8 + v3(0, 0.05, 0), u, w, 0.5, 0.06, 2.0)
    end
  end)()
end

return T
