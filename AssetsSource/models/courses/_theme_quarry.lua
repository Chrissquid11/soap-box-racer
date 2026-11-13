-- Quarry Lunch Break's scenery kit (see THEME KITS in _course.lua): an open-cast stone quarry. The ground is grey and
-- buff rock: a levelled haul apron beside the road, then benched walls (T.shape: terraces at fixed heights, a steep
-- face between each). On pads cut level beside the road stand huge yellow dump trucks (one tipping), excavators (one
-- on a high bench, its bucket hung over the road), wheel loaders, a crusher plant with conveyors and its cone
-- stockpiles, a site office portakabin with the workers at lunch round a picnic table, a wheel wash gantry, a water
-- bowser, lighting towers, hi-vis signs ("DEAD SLOW"), traffic cones, boulders and muddy puddles.
-- Every piece is one colour's (K.sub by colour) but the shaded heaps and boulders, three tones each.
local T = {trees = 0.1, rocks = 0.5}

-- The ground. T.shape cuts the slopes into benches at fixed heights (BENCH apart: a wide level tread, then a steep
-- face) beyond a levelled haul apron beside the road, and notes each grid vertex's height (false on the apron) for
-- T.paint, which tells a tread's cell from a face's by its corners.
local HT = {}
local BENCH = 8
local function hkey(x, z) return x * 8191 + z end

function T.shape(x, z, off, y, road_y, TK)
  local whole = x == math.floor(x) and z == math.floor(z)
  if off < 8 then
    if whole then HT[hkey(x, z)] = false end
    return nil
  end
  local base = road_y + 0.4
  if off < 18 then
    if whole then HT[hkey(x, z)] = false end
    return y + (base - y) * math.min(1, (off - 8) / 4)
  end
  local raw = base + math.min((off - 18) * 0.42, 46) + noise3(x, 0, z, {frequency = 0.02, seed = 11}) * 1.5
  local f = raw / BENCH
  local fl = math.floor(f)
  local fr = f - fl
  local s = (fr < 0.7) and 0 or (fr - 0.7) / 0.3
  local yy = (fl + s) * BENCH
  if yy <= base then
    if whole then HT[hkey(x, z)] = false end
    return base
  end
  if whole then HT[hkey(x, z)] = yy end
  return yy
end

local PAL, CELL
local CORN = {{-1, -1}, {1, -1}, {1, 1}, {-1, 1}}
function T.paint(x, z, off, ink, TK)
  if not PAL then
    PAL = {mud = TK.col(0.3, 0.2, 0.1), mud2 = TK.col(0.24, 0.16, 0.08), puddle = TK.col(0.3, 0.36, 0.42),
      buff = TK.col(0.7, 0.58, 0.37), buff2 = TK.col(0.64, 0.52, 0.32), buff3 = TK.col(0.76, 0.65, 0.45),
      grey = TK.col(0.52, 0.52, 0.5), grey2 = TK.col(0.46, 0.46, 0.45), grey3 = TK.col(0.6, 0.59, 0.56),
      apron = TK.col(0.56, 0.5, 0.4), apron2 = TK.col(0.5, 0.45, 0.37), apron3 = TK.col(0.6, 0.56, 0.48),
      face = TK.col(0.25, 0.24, 0.23), face2 = TK.col(0.32, 0.29, 0.25), face3 = TK.col(0.4, 0.33, 0.22)}
  end
  if off < -0.5 then return nil end
  local h2 = TK.hash(math.floor(x / 3) + 31, math.floor(z / 3) + 7)
  if off < 4.5 then
    if h2 > 0.9 then return PAL.puddle end
    return (h2 > 0.4) and PAL.mud or PAL.mud2
  end
  if not CELL then
    for st = 5, 12 do
      if HT[hkey(x - st / 2, z - st / 2)] ~= nil and HT[hkey(x + st / 2, z + st / 2)] ~= nil then CELL = st; break end
    end
  end
  local lo, hi, n = math.huge, -math.huge, 0
  if CELL then
    for _, m in ipairs(CORN) do
      local h = HT[hkey(x + m[1] * CELL / 2, z + m[2] * CELL / 2)]
      if h then
        n = n + 1
        lo, hi = math.min(lo, h), math.max(hi, h)
      end
    end
  end
  if n == 0 then
    -- the apron: trodden stone, muddy by the road
    if off < 9 and h2 > 0.6 then return PAL.mud end
    if h2 > 0.75 then return PAL.apron3 end
    return (h2 > 0.35) and PAL.apron or PAL.apron2
  end
  if hi - lo > 1.5 or n < 4 then
    -- a face: strata, dark
    local band = math.floor((lo + hi) / 2 / 2.7 + h2 * 0.6) % 3
    return (band == 0) and PAL.face or ((band == 1) and PAL.face2 or PAL.face3)
  end
  -- a bench: buff and grey rock by turns up the wall
  if math.floor(lo / BENCH + 0.5) % 2 == 0 then
    if h2 > 0.8 then return PAL.buff3 end
    return (h2 > 0.35) and PAL.buff or PAL.buff2
  end
  if h2 > 0.8 then return PAL.grey3 end
  return (h2 > 0.35) and PAL.grey or PAL.grey2
end

function T.build(K)
  local col = K.col
  local UP = v3(0, 1, 0)
  local pos, right, W, N = K.pos, K.right, K.W, K.N
  local function rnd(a, b) return K.g:range(a, b) end
  local EDGE = K.WALL_T + 1          -- the road's own margin: nothing of the kit's nearer its edge
  local S, D = K.solid, K.deco

  local WHITE, BLACK = col(0.93, 0.93, 0.9), col(0.03, 0.03, 0.03)
  local YEL, YEL2 = col(0.98, 0.66, 0.02), col(0.8, 0.48, 0.02)
  local TYRE, HUB = col(0.05, 0.05, 0.055), col(0.85, 0.6, 0.08)
  local DARK, GREY, GREYL = col(0.12, 0.12, 0.13), col(0.4, 0.41, 0.42), col(0.62, 0.63, 0.63)
  local STEEL, STEELL, BUCKET = col(0.45, 0.47, 0.5), col(0.72, 0.74, 0.76), col(0.2, 0.2, 0.22)
  local TRACK = col(0.09, 0.09, 0.1)
  local GLASS, LAMP = col(0.1, 0.22, 0.36), col(1.0, 0.95, 0.6)
  local PADC = col(0.6, 0.56, 0.48)
  local GRAVEL, BUFFG, DARKG, SANDY = col(0.5, 0.5, 0.5), col(0.72, 0.6, 0.38), col(0.3, 0.3, 0.32), col(0.82, 0.72, 0.5)
  local ROCKS = {col(0.5, 0.48, 0.45), col(0.62, 0.53, 0.38), col(0.4, 0.4, 0.4)}
  local PLANT, PLANT2, RUST, BELT = col(0.08, 0.32, 0.52), col(0.06, 0.22, 0.38), col(0.55, 0.24, 0.08), col(0.04, 0.04, 0.04)
  local HIVO, HIVY = col(1.0, 0.33, 0.02), col(0.72, 0.95, 0.05)
  local SIGNY, RED = col(1.0, 0.85, 0.02), col(0.85, 0.07, 0.04)
  local CABIN, ROOFC, OBLUE = col(0.78, 0.82, 0.74), col(0.86, 0.86, 0.84), col(0.08, 0.25, 0.6)
  local WOOD, WOOD2 = col(0.55, 0.38, 0.2), col(0.42, 0.28, 0.14)
  local SKIN, SKIN2, NAVY = col(0.9, 0.65, 0.48), col(0.5, 0.32, 0.2), col(0.06, 0.08, 0.22)
  local WBLUE, CYAN = col(0.05, 0.4, 0.85), col(0.45, 0.85, 1.0)
  local MUDW, PUDDLE = col(0.26, 0.17, 0.08), col(0.42, 0.5, 0.56)
  local LOO = col(0.05, 0.55, 0.6)

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
        local a = (k + 0.5) / n * math.pi * 2
        ring[#ring + 1] = p + e1 * (math.cos(a) * rr[j]) + e2 * (math.sin(a) * rr[j] * (squash or 1))
      end
      rings[j] = ring
    end
    K.prism(q, rings, K.flat(c), c, c)
  end
  local function limb(root, c, p0, p1, r0, r1, n) tube(root, c, {p0, p1}, {r0, r1}, n or 6) end
  local T5 = {-0.95, -0.6, 0, 0.6, 0.95}
  local function egg(root, c, cen, axis, r1, r2, n, hint)
    local pts, rr = {}, {}
    for _, t in ipairs(T5) do
      pts[#pts + 1] = cen + axis * t
      rr[#rr + 1] = r1 * math.sqrt(1 - t * t)
    end
    tube(root, c, pts, rr, n or 6, hint, r2 / r1)
  end
  local function sph(root, c, cen, r, n) egg(root, c, cen, UP * r, r, r, n or 6) end
  local function at(p, y) return v3(p.x, y, p.z) end
  local function flatdir(i)
    local u = K.along(i)
    return normalize(v3(u.x, 0, u.z))
  end
  local SHD = {}
  local function shd(c)
    if not SHD[c] then SHD[c] = {fn = K.shaded(c), hi = K.tint(c, 1.16), lo = K.tint(c, 0.78)} end
    return SHD[c]
  end

  -- A thing's own frame: P(a, h, b) is a forward, h up, b to its side (times its scale).
  local function frame(o, f, sc, side)
    sc = sc or 1
    local s = side or v3(-f.z, 0, f.x)
    local F = {o = o, f = f, s = s, sc = sc}
    function F.P(a, h, b) return o + (f * a + UP * h + s * (b or 0)) * sc end
    function F.box(root, c, a, h, b, ha, hh, hb) obox(root, c, F.P(a, h, b), f * (ha * sc), UP * (hh * sc), s * (hb * sc)) end
    function F.wheel(root, a, h, b, r, hw)
      limb(root, TYRE, F.P(a, h, b - hw), F.P(a, h, b + hw), r * sc, r * sc, 12)
      limb(root, HUB, F.P(a, h, b - hw - 0.05), F.P(a, h, b + hw + 0.05), r * 0.42 * sc, r * 0.42 * sc, 8)
    end
    return F
  end

  -- ---------------------------------------------------------------- lettering: 5 rows a glyph, a box a run
  local FONT = {
    A = {"010", "101", "111", "101", "101"}, B = {"110", "101", "110", "101", "110"}, C = {"011", "100", "100", "100", "011"},
    D = {"110", "101", "101", "101", "110"}, E = {"111", "100", "110", "100", "111"}, F = {"111", "100", "110", "100", "100"},
    G = {"0111", "1000", "1011", "1001", "0110"}, H = {"101", "101", "111", "101", "101"}, I = {"1", "1", "1", "1", "1"},
    K = {"1001", "1010", "1100", "1010", "1001"}, L = {"100", "100", "100", "100", "111"},
    M = {"10001", "11011", "10101", "10001", "10001"}, N = {"1001", "1101", "1011", "1001", "1001"},
    O = {"111", "101", "101", "101", "111"}, P = {"110", "101", "110", "100", "100"}, R = {"110", "101", "110", "101", "101"},
    Q = {"0110", "1001", "1001", "1010", "0101"},
    S = {"011", "100", "010", "001", "110"}, T = {"111", "010", "010", "010", "010"}, U = {"101", "101", "101", "101", "111"},
    W = {"10001", "10001", "10101", "11011", "10001"}, Y = {"101", "101", "010", "010", "010"},
  }
  local function textw(str)
    local w = 0
    for k = 1, #str do
      local gl = FONT[str:sub(k, k)]
      w = w + (gl and #gl[1] or 2) + 1
    end
    return w - 1
  end
  -- str centred on cen: tx the way it reads, up its up, nrm towards the reader; px a pixel's size.
  local function text(root, c, cen, tx, up, nrm, str, px)
    local x = -textw(str) / 2
    for i = 1, #str do
      local gl = FONT[str:sub(i, i)]
      if gl then
        for r = 1, 5 do
          local row, k = gl[r], 1
          while k <= #row do
            if row:sub(k, k) == "1" then
              local k2 = k
              while k2 < #row and row:sub(k2 + 1, k2 + 1) == "1" do k2 = k2 + 1 end
              obox(root, c, cen + tx * ((x + (k - 1 + k2) / 2) * px) + up * ((3 - r) * px) + nrm * 0.035,
                tx * ((k2 - k + 1) * px / 2 - px * 0.04), up * (px * 0.47), nrm * 0.03)
              k = k2 + 1
            else
              k = k + 1
            end
          end
        end
        x = x + #gl[1] + 1
      else
        x = x + 3
      end
    end
  end

  -- ---------------------------------------------------------------- where
  -- The road's samples in a grid of cells: how far off the road's edge a place is (true within CELL metres of it).
  local CELL = 8
  local cells = {}
  for i = 1, N do
    local k = math.floor(pos[i].x / CELL) * 8191 + math.floor(pos[i].z / CELL)
    local l = cells[k]
    if not l then l = {}; cells[k] = l end
    l[#l + 1] = i
  end
  local function offq(x, z)
    local cx, cz = math.floor(x / CELL), math.floor(z / CELL)
    local best, bi = 1e9, nil
    for ax = cx - 1, cx + 1 do
      for az = cz - 1, cz + 1 do
        local l = cells[ax * 8191 + az]
        if l then
          for _, i in ipairs(l) do
            local dx, dz = pos[i].x - x, pos[i].z - z
            local d = math.sqrt(dx * dx + dz * dz) - W[i]
            if d < best then best, bi = d, i end
          end
        end
      end
    end
    return best, bi
  end
  local function clear(x, z, m) return offq(x, z) > EDGE + (m or 0.4) end
  local function far(x, z, m)
    local _, d = K.ground_d(x, z)
    return d - K.HW > EDGE + m
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
  -- The road's highest top from sample i - k to i + k (a berm's build-up with it).
  local function roadmax(i, k)
    local y = -1e9
    for j = math.max(1, i - k), math.min(N, i + k) do
      y = math.max(y, pos[j].y + math.max(K.lift(j, 1), K.lift(j, -1)))
    end
    return y
  end
  local DL = length(v3(pos[N - 1].x - pos[2].x, 0, pos[N - 1].z - pos[2].z)) > 0 and 0 or 0
  do
    local sum = 0
    for i = 2, N do sum = sum + length(v3(pos[i].x - pos[i - 1].x, 0, pos[i].z - pos[i - 1].z)) end
    DL = sum / (N - 1)
  end
  -- A level plot beside the road between samples i0 and i1, the flattest there is: a along the road by b out from it
  -- (half sizes), gap off the margin. s.o its middle at the height of its top; s.u along, s.w out.
  local function site(i0, i1, side, a, b, gap, maxsp, step)
    local best
    local ka = math.ceil((a + 1) / DL) + 1
    local sides = (side == 0) and {1, -1} or {side, -side}
    for j = math.max(ka + 2, i0), math.min(N - ka - 1, i1), step or 3 do
      local y0, y1, y2 = pos[j - ka].y, pos[j].y, pos[j + ka].y
      local hi, lo = math.max(y0, y1, y2), math.min(y0, y1, y2)
      if hi - lo <= maxsp then
        for _, sd in ipairs(sides) do
          local w, u = right[j] * sd, flatdir(j)
          local c = pos[j] + w * (W[j] + EDGE + gap + b)
          local R = math.max(a, b) * 0.85
          local score = (hi - lo) + ((side ~= 0 and sd ~= side) and 0.5 or 0)
          if (not best or score < best.score) and free(c.x, c.z, R) then
            local ok = true
            local na = math.max(2, math.ceil(a / 2.5))
            for kk = -na, na do
              for kb = -1, 1 do
                local p = c + u * (kk / na * (a + 1.5)) + w * (kb * (b + 0.6))
                local d, bi = offq(p.x, p.z)
                if d < EDGE + 0.3 or (bi and math.abs(bi - j) > 45 and d < 9) then ok = false; break end
              end
              if not ok then break end
            end
            if ok then best = {score = score, c = c, u = u, w = w, hi = hi + 0.65, lo = lo - 0.6, i = j, sd = sd} end
          end
        end
      end
    end
    if not best then return nil end
    local s = best
    take(s.c.x, s.c.z, math.max(a, b) * 0.85)
    s.a, s.b = a, b
    s.y = s.hi
    return s
  end
  -- The plot's pad: a block of rock cut level, its sides battered out at the ends and the back.
  local function pad(s, c)
    local a, b = s.a + 0.5, s.b + 0.5
    local y1, y0 = s.y - 0.04, s.lo - 1.2
    local function Q(da, db, y)
      local p = s.c + s.u * da + s.w * db
      return v3(p.x, y, p.z)
    end
    K.hexa(piece(S, c or PADC, c or PADC), Q(-a - 0.9, -b, y0), Q(a + 0.9, -b, y0), Q(a + 0.9, b + 0.9, y0), Q(-a - 0.9, b + 0.9, y0),
      Q(-a, -b, y1), Q(a, -b, y1), Q(a, b, y1), Q(-a, b, y1))
    s.o = v3(s.c.x, s.y, s.c.z)
  end

  -- ---------------------------------------------------------------- heaps, boulders, puddles, cones
  -- A cone of stone R across at the ground (its ring sunk, so it sits on a slope), three tones round it.
  local function pile(x, z, R, c, y0, steep)
    local y = y0 or K.ground(x, z)
    local st = steep or 0.75
    local n = 11
    local pts = {}
    local a0 = rnd(0, 6.28)
    for k = 1, n do
      local a = a0 + k / n * 6.2832
      local rr = R * 1.5 * rnd(0.92, 1.08)
      pts[k] = v3(x + math.cos(a) * rr, y - R * st * 0.5, z + math.sin(a) * rr)
    end
    local sh = shd(c)
    K.cone(piece(S, c), pts, v3(x, y - R * st * 0.5, z), v3(x + rnd(-0.2, 0.2), y + R * st, z + rnd(-0.2, 0.2)), function(k)
      local l = math.cos(a0 + (k + 0.5) / n * 6.2832 - 0.9)
      return (l > 0.4) and sh.hi or ((l > -0.4) and c or sh.lo)
    end, sh.lo)
  end
  local function boulder(x, z, r, y0)
    local c = K.pick(ROCKS)
    local y = y0 or K.ground(x, z)
    K.ball(piece(S, c), v3(x, y + r * 0.25, z), r * rnd(0.9, 1.4), r * rnd(0.6, 0.95), r * rnd(0.85, 1.3), 7, 4,
      function() return rnd(0.78, 1.18) end, shd(c).fn)
  end
  -- A muddy puddle lying on the ground as it slopes, a patch of sky in it.
  local function puddle(x, z, r)
    local n = 8
    local lo, top, sky = {}, {}, {}
    local ys, mean = {}, 0
    local a0 = rnd(0, 6.28)
    local rs = {}
    for k = 1, n do
      local a = a0 + k / n * 6.2832
      rs[k] = r * rnd(0.85, 1.1)
      local px, pz = x + math.cos(a) * rs[k], z + math.sin(a) * rs[k]
      ys[k] = K.ground(px, pz)
      mean = mean + ys[k] / n
    end
    for k = 1, n do
      local a = a0 + k / n * 6.2832
      local px, pz = x + math.cos(a) * rs[k], z + math.sin(a) * rs[k]
      lo[k] = v3(px, ys[k] - 0.5, pz)
      top[k] = v3(px, ys[k] + 0.06, pz)
    end
    K.prism(piece(D, MUDW), {lo, top}, K.flat(MUDW), MUDW, MUDW)
    local lo2, top2 = {}, {}
    for k = 1, n do
      local a = a0 + k / n * 6.2832
      local q = 0.58
      local px, pz = x + math.cos(a) * rs[k] * q + r * 0.12, z + math.sin(a) * rs[k] * q
      local yy = mean + (ys[k] - mean) * q
      lo2[k] = v3(px, yy - 0.3, pz)
      top2[k] = v3(px, yy + 0.1, pz)
    end
    K.prism(piece(D, PUDDLE), {lo2, top2}, K.flat(PUDDLE), PUDDLE, PUDDLE)
  end
  local function tcone(x, z)
    local y = K.ground(x, z)
    local c = v3(x, y + 0.05, z)
    obox(D, HIVO, v3(x, y + 0.02, z), v3(0.27, 0, 0), UP * 0.04, v3(0, 0, 0.27))
    K.cone(piece(D, HIVO), K.ring(c, 0.2, 0.2, 6, 0.3), c, v3(x, y + 0.85, z), function() return HIVO end, HIVO)
    K.column(piece(D, WHITE), x, z, y + 0.38, y + 0.52, 0.135, 0.105, 6, WHITE, 0.3)
  end

  -- ---------------------------------------------------------------- machines
  -- A dump truck, o under its middle, f its nose's way; its body tipped up tipa radians, or laden.
  local function truck(o, f, sc, tipa, laden)
    local F = frame(o, f, sc)
    for sg = -1, 1, 2 do
      F.wheel(S, 2.7, 1.25, sg * 2.0, 1.25, 0.5)
      F.wheel(S, -2.3, 1.25, sg * 1.75, 1.25, 0.8)
      F.box(D, LAMP, 4.84, 1.55, sg * 1.75, 0.03, 0.16, 0.28)
      F.box(D, RED, -4.22, 1.6, sg * 0.9, 0.03, 0.12, 0.2)
    end
    F.box(S, DARK, 0.2, 1.55, 0, 4.0, 0.4, 1.15)
    F.box(S, YEL, 3.55, 2.55, 0, 0.95, 0.75, 1.7)
    F.box(D, DARK, 4.53, 2.55, 0, 0.05, 0.5, 1.1)
    F.box(S, YEL2, 4.6, 1.5, 0, 0.22, 0.32, 2.3)
    F.box(S, GREY, 2.9, 3.36, 0, 1.75, 0.06, 2.45)
    F.box(S, YEL, 2.5, 4.17, -1.25, 0.8, 0.75, 0.9)
    F.box(D, GLASS, 3.32, 4.3, -1.25, 0.03, 0.42, 0.72)
    F.box(D, GLASS, 2.5, 4.3, -2.17, 0.6, 0.42, 0.03)
    F.box(D, GLASS, 2.5, 4.3, -0.33, 0.6, 0.42, 0.03)
    beam(D, GREYL, F.P(4.9, 0.6, -1.5), F.P(4.62, 3.3, -1.5), 0.3 * sc, 0.04 * sc)
    F.box(D, YEL2, 2.9, 4.1, 2.4, 1.7, 0.04, 0.04)
    F.box(D, YEL2, 1.3, 3.75, 2.4, 0.04, 0.33, 0.04)
    F.box(D, YEL2, 4.5, 3.75, 2.4, 0.04, 0.33, 0.04)
    limb(D, DARK, F.P(1.5, 3.4, 1.6), F.P(1.5, 5.0, 1.6), 0.12 * sc, 0.12 * sc, 6)
    local Pv = F.P(-3.3, 2.25, 0)
    local ca, sa = math.cos(tipa), math.sin(tipa)
    local fa, fu = f * ca + UP * sa, UP * ca - f * sa
    local function BP(p, q, b) return Pv + (fa * p + fu * q + F.s * b) * sc end
    K.hexa(piece(S, YEL, YEL), BP(-1.3, 1.3, -1.9), BP(5.2, 0.12, -1.9), BP(5.2, 0.12, 1.9), BP(-1.3, 1.3, 1.9),
      BP(-1.7, 2.7, -2.55), BP(5.2, 2.7, -2.55), BP(5.2, 2.7, 2.55), BP(-1.7, 2.7, 2.55))
    obox(S, YEL, BP(6.9, 2.82, 0), fa * (1.8 * sc), fu * (0.12 * sc), F.s * (2.55 * sc))
    for _, p in ipairs({0.6, 2.4, 4.2}) do
      for sg = -1, 1, 2 do obox(D, YEL2, BP(p, 1.72, sg * 2.34), fa * (0.12 * sc), fu * (0.85 * sc), F.s * (0.1 * sc)) end
    end
    if tipa > 0.1 then
      limb(D, STEELL, F.P(0.6, 1.9, 0), BP(3.9, 0.2, 0), 0.16 * sc, 0.12 * sc, 6)
    elseif laden then
      K.ball(piece(S, GRAVEL), BP(2.2, 2.7, 0), 2.3 * sc, 0.95 * sc, 2.1 * sc, 8, 4, function() return rnd(0.85, 1.12) end, shd(GRAVEL).fn)
    end
  end

  -- A digger's bucket hung from St, its teeth back towards the machine (g the boom's way, s across).
  local function bucket(St, g, s, sc)
    local function B(a, h, b) return St + (g * a + UP * h + s * b) * sc end
    K.hexa(piece(S, BUCKET, BUCKET), B(-0.95, -1.3, -0.8), B(0.45, -1.3, -0.8), B(0.45, -1.3, 0.8), B(-0.95, -1.3, 0.8),
      B(-0.8, 0.05, -0.85), B(0.8, 0.05, -0.85), B(0.8, 0.05, 0.85), B(-0.8, 0.05, 0.85))
    for _, b in ipairs({-0.6, -0.2, 0.2, 0.6}) do
      obox(S, STEELL, B(-0.93, -1.4, b), g * (0.1 * sc), UP * (0.15 * sc), s * (0.09 * sc))
    end
  end
  -- An excavator: o under its tracks (which run along f), its house and boom turned to g; E its boom's far end and
  -- St its stick's (given, or digging at the ground ahead of it).
  local function excavator(o, f, g, sc, E, St, Kn)
    local F = frame(o, f, sc)
    for sg = -1, 1, 2 do
      local b = sg * 1.45
      F.box(S, TRACK, 0, 0.5, b, 2.3, 0.5, 0.42)
      limb(S, TRACK, F.P(2.3, 0.5, b - 0.41), F.P(2.3, 0.5, b + 0.41), 0.5 * sc, 0.5 * sc, 8)
      limb(S, TRACK, F.P(-2.3, 0.5, b - 0.41), F.P(-2.3, 0.5, b + 0.41), 0.5 * sc, 0.5 * sc, 8)
      F.box(D, YEL2, 0, 0.5, b + sg * 0.43, 1.9, 0.2, 0.02)
    end
    F.box(S, DARK, 0, 0.62, 0, 1.3, 0.3, 1.05)
    K.column(piece(S, DARK), o.x, o.z, o.y + 0.9 * sc, o.y + 1.2 * sc, 1.0 * sc, 1.0 * sc, 8, DARK)
    local G = frame(o + UP * (1.15 * sc), g, sc)
    G.box(S, YEL, -0.4, 0.8, 0, 2.1, 0.7, 1.45)
    G.box(S, DARK, -2.72, 0.8, 0, 0.3, 0.62, 1.42)
    G.box(S, YEL2, -1.3, 1.68, 0, 1.0, 0.2, 1.3)
    G.box(S, YEL, 0.95, 2.2, -0.85, 0.8, 0.72, 0.55)
    G.box(D, GLASS, 1.76, 2.3, -0.85, 0.03, 0.5, 0.45)
    G.box(D, GLASS, 0.95, 2.35, -1.41, 0.6, 0.42, 0.03)
    G.box(D, GLASS, 0.95, 2.35, -0.29, 0.6, 0.42, 0.03)
    limb(D, DARK, G.P(-1.6, 1.85, 0.8), G.P(-1.6, 2.7, 0.8), 0.09 * sc, 0.09 * sc, 6)
    local Bp = G.P(1.2, 1.3, 0.35)
    E = E or (Bp + (g * 4.6 + UP * 2.6) * sc)
    St = St or (Bp + (g * 5.6 - UP * 1.4) * sc)
    Kn = Kn or (lerp(Bp, E, 0.55) + UP * (0.9 * sc))
    beam(S, YEL, Bp, Kn, 0.3 * sc, 0.42 * sc)
    beam(S, YEL, Kn, E, 0.28 * sc, 0.36 * sc)
    sph(S, YEL2, Kn, 0.5 * sc, 6)
    sph(S, YEL2, E, 0.42 * sc, 6)
    beam(S, YEL, E, St, 0.24 * sc, 0.3 * sc)
    limb(D, STEELL, G.P(1.9, 0.9, 0.35), lerp(Bp, Kn, 0.62) - UP * (0.25 * sc), 0.1 * sc, 0.1 * sc, 6)
    limb(D, STEELL, Kn + UP * (0.6 * sc), E + UP * (0.5 * sc), 0.09 * sc, 0.09 * sc, 6)
    bucket(St, g, G.s, sc)
    return Bp
  end

  -- A wheel loader, its bucket up and full.
  local function loader(o, f, sc)
    local F = frame(o, f, sc)
    for sg = -1, 1, 2 do
      F.wheel(S, 1.6, 0.9, sg * 1.3, 0.9, 0.4)
      F.wheel(S, -1.6, 0.9, sg * 1.3, 0.9, 0.4)
      beam(S, YEL, F.P(1.3, 1.7, sg * 0.75), F.P(3.6, 2.9, sg * 0.75), 0.12 * sc, 0.22 * sc)
    end
    F.box(S, YEL, -1.7, 1.75, 0, 1.5, 0.65, 1.05)
    F.box(S, DARK, -3.3, 1.5, 0, 0.14, 0.5, 1.0)
    F.box(S, YEL, 1.2, 1.4, 0, 1.1, 0.45, 0.85)
    F.box(S, YEL, -0.3, 2.95, 0, 0.75, 0.75, 0.8)
    F.box(D, GLASS, 0.47, 3.05, 0, 0.03, 0.5, 0.65)
    F.box(D, GLASS, -0.3, 3.05, 0.81, 0.55, 0.45, 0.03)
    F.box(D, GLASS, -0.3, 3.05, -0.81, 0.55, 0.45, 0.03)
    F.box(D, HIVO, -0.3, 3.8, 0, 0.12, 0.09, 0.12)
    local function B(a, h, b) return F.P(a, h, b) end
    K.hexa(piece(S, BUCKET, BUCKET), B(3.4, 2.3, -1.6), B(4.6, 2.5, -1.6), B(4.6, 2.5, 1.6), B(3.4, 2.3, 1.6),
      B(3.3, 3.5, -1.6), B(5.1, 3.4, -1.6), B(5.1, 3.4, 1.6), B(3.3, 3.5, 1.6))
    K.ball(piece(S, BUFFG), B(4.15, 3.4, 0), 1.0 * sc, 0.6 * sc, 1.3 * sc, 7, 4, function() return rnd(0.85, 1.12) end, shd(BUFFG).fn)
  end

  -- A site pick-up: white, an amber beacon, hi-vis stripes.
  local function pickup(o, f)
    local F = frame(o, f, 1.15)
    for sg = -1, 1, 2 do
      F.wheel(S, 1.4, 0.4, sg * 0.85, 0.4, 0.14)
      F.wheel(S, -1.4, 0.4, sg * 0.85, 0.4, 0.14)
      F.box(D, HIVY, 0, 0.75, sg * 0.93, 2.3, 0.09, 0.012)
    end
    F.box(S, WHITE, 0, 0.8, 0, 2.45, 0.35, 0.92)
    F.box(S, WHITE, 0.25, 1.5, 0, 0.85, 0.36, 0.86)
    F.box(D, GLASS, 1.11, 1.5, 0, 0.02, 0.28, 0.76)
    F.box(D, GLASS, 0.25, 1.52, 0.865, 0.7, 0.26, 0.012)
    F.box(D, GLASS, 0.25, 1.52, -0.865, 0.7, 0.26, 0.012)
    F.box(D, HIVO, 0.25, 1.94, 0, 0.3, 0.07, 0.1)
    F.box(D, DARK, -1.55, 1.2, 0, 0.85, 0.06, 0.85)
  end

  -- A water bowser on its trailer.
  local function bowser(o, f)
    local F = frame(o, f, 1.2)
    limb(S, WBLUE, F.P(-1.7, 1.75, 0), F.P(1.7, 1.75, 0), 0.95 * 1.2, 0.95 * 1.2, 10)
    F.box(S, DARK, 0, 0.75, 0, 2.0, 0.12, 0.8)
    F.wheel(S, -0.5, 0.55, 1.05, 0.55, 0.2)
    F.wheel(S, -0.5, 0.55, -1.05, 0.55, 0.2)
    beam(S, DARK, F.P(1.9, 0.72, 0), F.P(3.4, 0.6, 0), 0.07, 0.07)
    F.box(S, DARK, 2.6, 0.32, 0, 0.06, 0.32, 0.06)
    K.column(piece(D, GREYL), F.P(0.3, 0, 0).x, F.P(0.3, 0, 0).z, o.y + 2.68 * 1.2, o.y + 2.86 * 1.2, 0.3, 0.3, 8, GREYL)
    F.box(D, STEEL, -1.95, 0.75, 0, 0.05, 0.05, 1.1)
    for _, b in ipairs({-0.9, -0.45, 0, 0.45, 0.9}) do F.box(D, CYAN, -2.0, 0.42, b, 0.03, 0.26, 0.05) end
    for sg = -1, 1, 2 do
      text(D, WHITE, F.P(0, 1.75, sg * 0.905), F.f * (-sg), UP, F.s * sg, "WATER", 0.115)
    end
  end

  -- A lighting tower on its trolley.
  local function lights(o, f)
    local F = frame(o, f, 1)
    F.box(S, YEL, 0, 0.6, 0, 0.9, 0.4, 0.6)
    F.wheel(D, -0.3, 0.3, 0.68, 0.3, 0.08)
    F.wheel(D, -0.3, 0.3, -0.68, 0.3, 0.08)
    beam(S, STEEL, F.P(0, 0.9, 0), F.P(0, 8.0, 0), 0.07, 0.07)
    beam(D, STEEL, F.P(1.6, 0, 1.2), F.P(0, 1.0, 0), 0.04, 0.04)
    beam(D, STEEL, F.P(1.6, 0, -1.2), F.P(0, 1.0, 0), 0.04, 0.04)
    F.box(D, DARK, 0, 8.0, 0, 0.06, 0.06, 1.0)
    for _, b in ipairs({-0.75, -0.25, 0.25, 0.75}) do
      F.box(D, DARK, 0.02, 8.0, b, 0.1, 0.24, 0.2)
      F.box(D, LAMP, 0.14, 8.0, b, 0.03, 0.2, 0.17)
    end
  end

  -- ---------------------------------------------------------------- people
  local VESTS, HATS = {HIVO, HIVY}, {WHITE, YEL, WBLUE, RED}
  local people = 0
  -- A worker: sitting (thighs forward along f, as on a bench 0.47 up) or standing; o at the ground.
  local function worker(o, f, sc, sitting, holds)
    people = people + 1
    local F = frame(o, f, sc)
    local P = F.P
    local vest, hat = VESTS[people % 2 + 1], HATS[people % 4 + 1]
    local skin = (people % 3 == 0) and SKIN2 or SKIN
    local hip = sitting and 0.56 or 0.92
    for sg = -1, 1, 2 do
      local b = sg * 0.1
      if sitting then
        limb(D, NAVY, P(-0.05, hip, b), P(0.4, hip, b), 0.085 * sc, 0.07 * sc, 5)
        limb(D, NAVY, P(0.4, hip + 0.02, b), P(0.42, 0.06, b), 0.065 * sc, 0.055 * sc, 5)
        F.box(D, BLACK, 0.47, 0.05, b, 0.12, 0.05, 0.06)
      else
        limb(D, NAVY, P(0, hip, b), P(0, 0.06, b), 0.085 * sc, 0.06 * sc, 5)
        F.box(D, BLACK, 0.05, 0.05, b, 0.13, 0.05, 0.06)
      end
      local sh = P(0, hip + 0.56, sg * 0.24)
      local el = P(0.2, hip + 0.3, sg * 0.25)
      local hand = sitting and P(0.46, hip + 0.36, sg * 0.14) or ((sg > 0 and holds) and P(0.36, hip + 0.52, 0.18) or P(0.05, hip + 0.02, sg * 0.27))
      if not sitting and not (sg > 0 and holds) then el = P(0.02, hip + 0.3, sg * 0.27) end
      limb(D, vest, sh, el, 0.06 * sc, 0.055 * sc, 5)
      limb(D, skin, el, hand, 0.05 * sc, 0.04 * sc, 5)
    end
    egg(D, vest, P(0.01, hip + 0.33, 0), UP * (0.36 * sc), 0.2 * sc, 0.2 * sc, 6)
    F.box(D, STEELL, 0.01, hip + 0.3, 0, 0.15, 0.03, 0.2)
    sph(D, skin, P(0.03, hip + 0.8, 0), 0.125 * sc, 6)
    egg(D, hat, P(0.03, hip + 0.88, 0), UP * (0.09 * sc), 0.15 * sc, 0.15 * sc, 6)
    F.box(D, hat, 0.15, hip + 0.86, 0, 0.09, 0.012, 0.1)
    if sitting then
      F.box(D, WHITE, 0.5, hip + 0.4, 0.1, 0.06, 0.03, 0.08)
    elseif holds then
      K.column(piece(D, WHITE), P(0.38, 0, 0.18).x, P(0.38, 0, 0.18).z, P(0, hip + 0.5, 0).y, P(0, hip + 0.64, 0).y, 0.05 * sc, 0.055 * sc, 6, WHITE)
    end
  end
  -- A picnic table (along f) with the crew at lunch on its benches.
  local function picnic(o, f, sc, side, crew)
    local F = frame(o, f, sc, side)
    F.box(S, WOOD, 0, 0.8, 0, 1.15, 0.04, 0.42)
    for sg = -1, 1, 2 do
      F.box(S, WOOD, 0, 0.47, sg * 0.72, 1.15, 0.03, 0.15)
      local a = sg * 0.85
      beam(S, WOOD2, F.P(a, 0, -0.78), F.P(a, 0.77, 0.3), 0.05 * sc, 0.04 * sc)
      beam(S, WOOD2, F.P(a + 0.09, 0, 0.78), F.P(a + 0.09, 0.77, -0.3), 0.05 * sc, 0.04 * sc)
      F.box(S, WOOD2, a - 0.1, 0.41, 0, 0.04, 0.03, 0.86)
    end
    local seats = {{-0.6, 1}, {0.55, -1}, {0.6, 1}, {-0.5, -1}}
    for k = 1, math.min(crew, 4) do
      local a, sg = seats[k][1], seats[k][2]
      worker(F.P(a, 0, sg * 0.74), F.s * (-sg), sc, true)
    end
    F.box(D, RED, -0.15, 0.9, 0.05, 0.15, 0.06, 0.1)
    F.box(D, WBLUE, 0.25, 0.9, -0.1, 0.12, 0.06, 0.09)
    K.column(piece(D, HIVO), F.P(0, 0, 0).x, F.P(0, 0, 0).z, F.P(0, 0.84, 0).y, F.P(0, 1.14, 0).y, 0.055 * sc, 0.055 * sc, 6, HIVO)
    K.column(piece(D, STEELL), F.P(0.9, 0, 0.1).x, F.P(0.9, 0, 0.1).z, F.P(0, 0.84, 0).y, F.P(0, 1.2, 0).y, 0.11 * sc, 0.09 * sc, 7, STEELL)
  end

  -- ---------------------------------------------------------------- signs
  -- A hi-vis board across the roadside at sample i, read by who comes down the road: lines of text on two posts.
  local function sign(i, sd, lines, bc, tc)
    local u, w = flatdir(i), right[i] * sd
    local maxw = 0
    for _, l in ipairs(lines) do maxw = math.max(maxw, textw(l)) end
    local px = math.min(0.3, 4.6 / (maxw + 3))
    local hw = (maxw + 3) * px / 2
    local hh = (#lines * 6 + 1) * px / 2
    local c = pos[i] + w * (W[i] + EDGE + 0.6 + hw)
    for k = -2, 2 do
      local p = c + w * (k * 0.5 * (hw + 0.3))
      if not clear(p.x, p.z, 0.25) then return false end
    end
    if not free(c.x, c.z, hw) then return false end
    take(c.x, c.z, hw)
    local gy = K.ground(c.x, c.z)
    local tx = normalize(cross(u, UP))
    local cen = v3(c.x, math.max(pos[i].y, gy) + 2.1 + hh, c.z)
    obox(D, bc, cen, tx * hw, UP * hh, u * 0.05)
    obox(D, BLACK, cen + u * 0.04, tx * (hw + px * 0.6), UP * (hh + px * 0.6), u * 0.04)
    for l, str in ipairs(lines) do
      text(D, tc, cen + UP * (hh - (3.5 + (l - 1) * 6) * px) - u * 0.055, tx, UP, u * -1, str, px)
    end
    for e = -1, 1, 2 do
      local p = cen + tx * (e * (hw - 0.3)) + u * 0.16
      beam(S, STEEL, v3(p.x, gy - 2.5, p.z), p + UP * (hh * 0.7), 0.08, 0.08)
    end
    return true
  end

  -- ---------------------------------------------------------------- the crusher plant
  local function conveyor(p0, p1, wd, base_y)
    beam(S, PLANT2, p0, p1, wd * 0.5, 0.2)
    beam(D, BELT, p0 + UP * 0.24, p1 + UP * 0.24, wd * 0.5 - 0.1, 0.035)
    beam(D, GRAVEL, lerp(p0, p1, 0.08) + UP * 0.33, lerp(p0, p1, 0.97) + UP * 0.33, wd * 0.24, 0.07)
    local e = normalize(cross(p1 - p0, UP))
    limb(D, DARK, p1 - e * (wd * 0.55), p1 + e * (wd * 0.55), 0.3, 0.3, 8)
    for _, t in ipairs({0.5, 0.93}) do
      local p = lerp(p0, p1, t)
      for sg = -1, 1, 2 do
        beam(S, STEEL, v3(p.x + e.x * sg * 1.4, base_y, p.z + e.z * sg * 1.4), p + e * (sg * wd * 0.4) - UP * 0.12, 0.08, 0.08)
      end
      beam(D, STEEL, lerp(v3(p.x + e.x * 1.4, base_y, p.z + e.z * 1.4), p, 0.5), lerp(v3(p.x - e.x * 1.4, base_y, p.z - e.z * 1.4), p, 0.5), 0.05, 0.05)
    end
  end
  local function plant(s)
    local F = frame(s.o, s.u, 1, s.w)
    local P = F.P
    local y0 = s.y - 0.3
    -- the feed hopper over the jaw crusher
    local hc = P(-11, 0, 1.5)
    for _, m in ipairs({{-1.7, -1.7}, {1.7, -1.7}, {1.7, 1.7}, {-1.7, 1.7}}) do
      beam(S, STEEL, at(P(-11 + m[1], 0, 1.5 + m[2]), y0), P(-11 + m[1], 4.6, 1.5 + m[2]), 0.12, 0.12)
    end
    local function sq(h, r)
      return {P(-11 - r, h, 1.5 - r), P(-11 + r, h, 1.5 - r), P(-11 + r, h, 1.5 + r), P(-11 - r, h, 1.5 + r)}
    end
    K.prism(piece(S, RUST), {sq(3.0, 0.9), sq(5.9, 2.7)}, K.flat(RUST), RUST, RUST)
    K.ball(piece(S, GRAVEL), P(-11, 5.85, 1.5), 2.2, 0.9, 2.2, 8, 4, function() return rnd(0.85, 1.1) end, shd(GRAVEL).fn)
    F.box(S, PLANT, -11, 1.5, 1.5, 1.5, 1.5, 1.45)
    limb(S, HIVO, P(-11, 1.9, -0.3), P(-11, 1.9, -0.02), 1.15, 1.15, 10)
    limb(S, HIVO, P(-11, 1.9, 3.02), P(-11, 1.9, 3.3), 1.15, 1.15, 10)
    conveyor(P(-9.2, 0.9, 1.5), P(-1.2, 8.9, 1.5), 1.2, y0)
    -- the screen house on its legs, a walkway round it
    for _, m in ipairs({{-2.3, -0.4}, {2.9, -0.4}, {2.9, 3.4}, {-2.3, 3.4}}) do
      beam(S, STEEL, at(P(m[1], 0, m[2]), y0), P(m[1], 5.5, m[2]), 0.14, 0.14)
    end
    beam(D, STEEL, P(-2.3, 0.3, -0.4), P(2.9, 5.2, -0.4), 0.06, 0.06)
    beam(D, STEEL, P(2.9, 0.3, -0.4), P(-2.3, 5.2, -0.4), 0.06, 0.06)
    F.box(S, GREY, 0.3, 5.47, 1.5, 3.4, 0.08, 2.7)
    F.box(S, PLANT, 0.3, 7.05, 1.5, 2.8, 1.5, 2.0)
    F.box(S, GREYL, 0.3, 8.66, 1.5, 3.0, 0.1, 2.2)
    for _, m in ipairs({{-1, 0, 3.4, 0.04, -1.2, 1.5}, {1, 0, 3.4, 0.04, 4.2, 1.5}}) do
      F.box(D, YEL, 0.3, 6.55, m[5], 3.4, 0.05, 0.05)
    end
    F.box(D, YEL, -3.1, 6.55, 1.5, 0.05, 0.05, 2.7)
    F.box(D, YEL, 3.7, 6.55, 1.5, 0.05, 0.05, 2.7)
    for _, m in ipairs({{-3.1, -1.2}, {3.7, -1.2}, {3.7, 4.2}, {-3.1, 4.2}, {0.3, -1.2}, {0.3, 4.2}}) do
      F.box(D, YEL, m[1], 6.03, m[2], 0.04, 0.5, 0.04)
    end
    beam(S, YEL, P(8.6, 0.1, -1.0), P(3.6, 5.45, -1.0), 0.5, 0.09)
    local tx = normalize(cross(s.w, UP))
    F.box(D, SIGNY, 0.3, 7.2, -0.53, 2.5, 0.75, 0.03)
    text(D, BLACK, P(0.3, 7.2, -0.57), tx, UP, s.w * -1, "CRUSHER", 0.17)
    -- three conveyors out to their heaps
    local heaps = {
      {P(2.4, 4.9, 1.5), P(10.6, 6.9, 2.0), P(11.2, 0, 2.0), 5.6, GRAVEL},
      {P(0.4, 4.9, 3.0), P(0.6, 6.5, 10.6), P(0.6, 0, 11.2), 5.0, BUFFG},
      {P(-2.0, 4.9, 3.0), P(-8.2, 6.0, 9.6), P(-8.6, 0, 10.1), 4.5, DARKG},
    }
    for _, h in ipairs(heaps) do
      conveyor(h[1], h[2], 1.0, y0)
      if far(h[3].x, h[3].z, h[4] * 1.6 + 1) then pile(h[3].x, h[3].z, h[4], h[5], s.y, 0.9) end
    end
  end

  -- ---------------------------------------------------------------- the site office and the lunch break
  local function office(s)
    local F = frame(s.o, s.u, 1, s.w)
    local tx = normalize(cross(s.w, UP))
    for _, m in ipairs({{-7.5, -0.7}, {-1.5, -0.7}, {-1.5, 1.5}, {-7.5, 1.5}}) do F.box(S, GREY, m[1], 0.2, m[2], 0.3, 0.2, 0.3) end
    F.box(S, CABIN, -4.5, 1.72, 0.4, 3.6, 1.3, 1.4)
    F.box(S, ROOFC, -4.5, 3.09, 0.4, 3.75, 0.06, 1.55)
    F.box(D, OBLUE, -4.5, 0.75, -1.015, 3.6, 0.13, 0.02)
    F.box(D, GLASS, -6.6, 1.95, -1.02, 0.7, 0.45, 0.03)
    F.box(D, GLASS, -4.6, 1.95, -1.02, 0.7, 0.45, 0.03)
    F.box(D, OBLUE, -2.3, 1.45, -1.02, 0.45, 0.98, 0.03)
    F.box(S, GREY, -2.3, 0.2, -1.42, 0.6, 0.2, 0.32)
    F.box(D, SIGNY, -4.9, 2.72, -1.02, 2.3, 0.26, 0.03)
    text(D, BLACK, F.P(-4.9, 2.72, -1.055), tx, UP, s.w * -1, "SITE OFFICE", 0.085)
    beam(D, STEEL, F.P(-7.6, 3.1, 1.2), F.P(-7.6, 5.2, 1.2), 0.03, 0.03)
    -- a portable loo, the picnic table and the crew
    F.box(S, LOO, 8.6, 1.2, 1.6, 0.62, 1.2, 0.62)
    F.box(S, WHITE, 8.6, 2.46, 1.6, 0.68, 0.06, 0.68)
    F.box(D, WHITE, 8.6, 1.3, 0.965, 0.42, 0.95, 0.02)
    picnic(F.P(3.2, 0, -0.3), s.u, 1.35, s.w, 4)
    worker(F.P(6.2, 0, -1.6), s.w * -1, 1.35, false, true)
    worker(F.P(0.3, 0, -1.9), normalize(s.u * -0.5 - s.w), 1.35, false, false)
    for k = 1, 3 do
      local p = F.P(-0.6 + k * 0.05, 0, 1.4 + k * 0.5)
      tcone(p.x, p.z)
    end
  end

  -- ---------------------------------------------------------------- the wheel wash: a gantry over the road
  local function wash(i)
    local u, r = flatdir(i), right[i]
    local span = W[i] + EDGE + 1.95
    local H = roadmax(i, 4) + 6.6
    local c = pos[i]
    local tx = normalize(cross(u, UP))
    for sd = -1, 1, 2 do
      local tc = c + r * (sd * span)
      take(tc.x, tc.z, 2.2)
      local gy = K.ground(tc.x, tc.z)
      K.column(piece(S, WBLUE), tc.x, tc.z, gy - 1.5, c.y + 3.6, 1.15, 1.15, 10, WBLUE)
      K.column(piece(S, GREYL), tc.x, tc.z, c.y + 3.62, c.y + 3.85, 1.22, 0.9, 10, GREYL)
      beam(S, STEEL, at(tc - u * 0.55, c.y + 3.8), at(tc - u * 0.55, H + 0.1), 0.1, 0.1)
      beam(S, STEEL, at(tc + u * 0.55, c.y + 3.8), at(tc + u * 0.55, H + 0.1), 0.1, 0.1)
      beam(D, STEEL, at(tc - u * 0.55, c.y + 4.0), at(tc + u * 0.55, H - 0.2), 0.05, 0.05)
      for _, h in ipairs({1.0, 2.0, 3.0}) do
        local p = at(tc - r * (sd * 1.2), c.y + h)
        beam(D, STEELL, p - u * 0.9, p + u * 0.9, 0.05, 0.05)
        for _, a in ipairs({-0.7, 0, 0.7}) do
          beam(D, CYAN, p + u * a - r * (sd * 0.05), p + u * a - r * (sd * 0.6) - UP * 0.25, 0.035, 0.035)
        end
      end
    end
    obox(S, YEL, at(c, H + 0.42), r * (span + 0.75), UP * 0.38, u * 0.4)
    for k = -5, 5 do
      local p = at(c + r * (k / 5 * (span - 1.6)), H - 0.19)
      obox(D, CYAN, p, r * 0.05, UP * 0.2, u * 0.05)
      obox(D, CYAN, p + u * 0.25 + UP * 0.05, r * 0.04, UP * 0.14, u * 0.04)
    end
    local px = math.min(0.26, (span * 2 - 1) / (textw("WHEEL WASH") + 3))
    local hw, hh = (textw("WHEEL WASH") + 3) * px / 2, 3.5 * px
    local cen = at(c, H + 0.86 + hh)
    obox(D, WBLUE, cen, tx * hw, UP * hh, u * 0.06)
    text(D, WHITE, cen - u * 0.065, tx, UP, u * -1, "WHEEL WASH", px)
    for sd = -1, 1, 2 do
      for k = 1, 3 do
        local p = c + r * (sd * (W[i] + EDGE + rnd(1.6, 5.5))) + u * rnd(-7, 7)
        if clear(p.x, p.z, 1.4) and free(p.x, p.z, 0.2) then puddle(p.x, p.z, rnd(0.8, 1.2)) end
      end
    end
  end

  -- ================================================================ the quarry, laid out
  local st, fn = K.start, K.fin
  local made = {}
  local function mk(n) made[#made + 1] = n end
  local run = fn - st

  -- the excavator on its bench, its bucket hung over the road
  s = site(st + math.floor(run * 0.3), fn - 60, 0, 5.4, 4.5, 1.0, 6, 3) or site(st + 20, fn - 20, 0, 5.4, 4.5, 1.0, 30, 2)
  if s then
    local i = s.i
    local top = roadmax(i, 9)
    s.y = math.max(s.y, top + 3.2)
    pad(s)
    local sc = 1.7
    local g = s.w * -1
    local c = pos[i]
    local E = at(c + s.w * 0.6, top + 15.0)
    local St = at(c - s.w * 1.1, top + 6.75 + 1.56 * sc)
    local Kn = at(c + s.w * (W[i] + EDGE + 0.5), top + 13.2)
    excavator(s.o, s.u, g, sc, E, St, Kn)
    mk(string.format('overdigger@%d clear %.2f at %.0f,%.0f,%.0f', i, St.y - 1.56 * sc - top, c.x, c.y, c.z))
    boulder(s.o.x + s.u.x * 4.3 + s.w.x * 2.5, s.o.z + s.u.z * 4.3 + s.w.z * 2.5, 1.0, s.y)
  end

  -- the crusher plant, on the flattest big plot there is
  local s = site(st + 30, fn - 6, 0, 17, 8.5, 3, 6, 4)
  if s then pad(s); plant(s); mk(string.format('plant@%d at %.0f,%.0f,%.0f', s.i, s.c.x, s.y, s.c.z)) end

  -- the office and the lunch break, early on
  s = site(st + 4, st + math.floor(run * 0.3), 0, 10, 3.4, 1.6, 5, 2) or site(st + 4, fn, 0, 10, 3.4, 1.6, 8, 3)
  if s then pad(s); office(s); mk(string.format('office@%d at %.0f,%.0f,%.0f', s.i, s.c.x, s.y, s.c.z)) end

  -- the wheel wash
  do
    local best
    for i = st + math.floor(run * 0.45), fn - 20, 3 do
      local span = W[i] + EDGE + 1.95
      local a, b = pos[i] + right[i] * span, pos[i] - right[i] * span
      local grade = math.abs(pos[i - 4].y - pos[i + 4].y) + math.max(K.lift(i, 1), K.lift(i, -1)) * 3
      if free(a.x, a.z, 3) and free(b.x, b.z, 3) and clear(a.x, a.z, 0.6) and clear(b.x, b.z, 0.6) and (not best or grade < best[2]) then
        best = {i, grade}
      end
    end
    if best then
      wash(best[1])
      mk(string.format('wash@%d at %.0f,%.0f,%.0f', best[1], pos[best[1]].x, pos[best[1]].y, pos[best[1]].z))
      s = site(best[1] + 8, best[1] + 40, 0, 3.4, 1.7, 1.2, 5, 2)
      if s then pad(s); bowser(s.o, s.u); mk('bowser@' .. s.i) end
    end
  end

  -- dump trucks down the hill, one tipping its load
  for k = 0, 6 do
    local i0 = st + math.floor(run * k / 7)
    local tipping = (k == 2 or k == 5)
    local sc = 1.12
    s = site(i0 + 3, i0 + math.floor(run / 7), (k % 2 == 0) and 1 or -1, (tipping and 8.2 or 5.6) * sc, 3.0 * sc, 1.0, 5, 2)
    if s then
      mk('truck@' .. s.i)
      pad(s)
      local f = (K.hash(k, 3) > 0.5) and s.u or s.u * -1
      if tipping then
        truck(s.o + f * (2.4 * sc), f, sc, 0.82, false)
        local p = s.o - f * (6.0 * sc)
        pile(p.x, p.z, 2.3, GRAVEL, s.y, 0.75)
      else
        truck(s.o, f, sc, 0, K.hash(k, 9) > 0.35)
        worker(s.o + f * (5.65 * sc) - s.w * (1.2 * sc), s.w * -1, 1.35, false, k % 2 == 0)
      end
    end
  end

  -- excavators digging at the walls, loaders, pick-ups
  for k = 0, 3 do
    local i0 = st + math.floor(run * (k + 0.5) / 4)
    s = site(i0 - 40, i0 + 40, (k % 2 == 0) and -1 or 1, 4.6, 4.2, 1.2, 5, 2)
    if s then
      mk('digger@' .. s.i)
      pad(s)
      local g = normalize(s.w + s.u * ((k % 2 == 0) and 0.45 or -0.45))
      local sc = 1.15
      local reach = s.o + g * (8.2 * sc)
      if far(reach.x, reach.z, 2.5) then
        excavator(s.o, s.u, g, sc)
        boulder(reach.x - g.x * 0.5, reach.z - g.z * 0.5, 1.1)
        boulder(reach.x + g.z * 1.6, reach.z - g.x * 1.6, 0.8)
      else
        local Bp = s.o + UP * (2.45 * sc)
        excavator(s.o, s.u, g, sc, Bp + (g * 2.6 + UP * 4.2) * sc, Bp + (g * 3.4 + UP * 1.2) * sc)
      end
    end
  end
  for k = 0, 3 do
    local i0 = st + math.floor(run * (k + 0.2) / 4)
    s = site(i0 - 30, i0 + 50, (k % 2 == 0) and 1 or -1, 5.6, 2.6, 1.0, 5, 2)
    if s then mk('loader@' .. s.i); pad(s); loader(s.o - s.u * 0.8, (k % 2 == 0) and s.u or s.u * -1, 1.2) end
  end
  for k = 0, 4 do
    local i0 = st + math.floor(run * (k + 0.6) / 5)
    s = site(i0 - 30, i0 + 30, (k % 2 == 0) and -1 or 1, 3.2, 1.5, 1.0, 4, 2)
    if s then mk('pickup@' .. s.i); pad(s); pickup(s.o, (k % 2 == 0) and s.u or s.u * -1) end
  end
  -- a second crew at lunch further down
  s = site(st + math.floor(run * 0.55), fn, 0, 3.4, 2.4, 1.4, 4, 2)
  if s then
    pad(s)
    picnic(s.o, s.u, 1.35, s.w, 3)
    worker(s.o + s.u * 2.6 - s.w * 1.2, s.w * -1, 1.35, false, true)
  end

  -- the signs
  local SIGNS = {
    {{"DEAD", "SLOW"}, SIGNY, BLACK}, {{"HARD", "HATS"}, WBLUE, WHITE}, {{"DEAD", "SLOW"}, SIGNY, BLACK},
    {{"DANGER", "BLASTING"}, RED, WHITE}, {{"DEAD", "SLOW"}, HIVO, BLACK}, {{"SLOW", "TRUCKS"}, SIGNY, BLACK},
    {{"DEAD", "SLOW"}, SIGNY, BLACK}, {{"DANGER", "MUD"}, RED, WHITE}, {{"DEAD", "SLOW"}, HIVY, BLACK},
    {{"LUNCH", "BREAK"}, WBLUE, WHITE}, {{"DEAD", "SLOW"}, SIGNY, BLACK}, {{"DEAD", "SLOW"}, HIVO, BLACK},
  }
  for k, sg in ipairs(SIGNS) do
    local i0 = st + math.floor(run * (k - 0.6) / #SIGNS)
    local done = false
    for _, di in ipairs({0, 4, -4, 8, -8, 12, -12, 16}) do
      for _, sd in ipairs({(k % 2 == 0) and 1 or -1, (k % 2 == 0) and -1 or 1}) do
        local i = math.max(6, math.min(N - 6, i0 + di))
        if not done and sign(i, sd, sg[1], sg[2], sg[3]) then done = true; mk('sign@' .. i) end
      end
    end
  end

  -- lighting towers
  for k = 0, 5 do
    local i0 = st + math.floor(run * (k + 0.35) / 6)
    for _, di in ipairs({0, 5, -5, 10, -10}) do
      local i = math.max(6, math.min(N - 6, i0 + di))
      local sd = (k % 2 == 0) and -1 or 1
      local p = pos[i] + right[i] * (sd * (W[i] + EDGE + 1.6))
      if clear(p.x, p.z, 1.0) and free(p.x, p.z, 1.6) then
        take(p.x, p.z, 1.6)
        lights(v3(p.x, K.ground(p.x, p.z) - 0.1, p.z), right[i] * -sd)
        break
      end
    end
  end

  -- rows of traffic cones, puddles and rubble by the road
  for k = 1, 12 do
    local i = math.floor(rnd(st + 5, fn - 5))
    local sd = (k % 2 == 0) and 1 or -1
    for m = 0, 4 do
      local j = math.min(N - 2, i + m * 2)
      local p = pos[j] + right[j] * (sd * (W[j] + EDGE + 0.5 + m * 0.12))
      if clear(p.x, p.z, 0.3) and free(p.x, p.z, 0.3) then tcone(p.x, p.z) end
    end
  end
  for k = 1, 26 do
    local i = math.floor(rnd(st + 3, fn - 3))
    local sd = (k % 2 == 0) and 1 or -1
    local r = rnd(0.8, 1.5)
    local p = pos[i] + right[i] * (sd * (W[i] + EDGE + r + rnd(0.4, 3.0)))
    if clear(p.x, p.z, r + 0.2) and free(p.x, p.z, r) then
      take(p.x, p.z, r)
      puddle(p.x, p.z, r)
    end
  end
  for k = 1, 90 do
    local i = math.floor(rnd(4, N - 4))
    local sd = (k % 2 == 0) and 1 or -1
    local r = rnd(0.5, 1.3)
    local p = pos[i] + right[i] * (sd * (W[i] + EDGE + r * 1.5 + rnd(0.8, 6.0)))
    if clear(p.x, p.z, r * 1.5 + 0.3) and free(p.x, p.z, r) then
      take(p.x, p.z, r)
      boulder(p.x, p.z, r)
    end
  end

  -- stockpiles and blasted rock out on the apron and the benches
  local HEAPS = {GRAVEL, BUFFG, DARKG, SANDY}
  local n = 0
  for _ = 1, 60 do
    if n < 26 then
      local R = rnd(2.4, 5.0)
      local x, z = K.spot(R * 1.6 + 2.5)
      if x and free(x, z, R) then
        take(x, z, R)
        n = n + 1
        pile(x, z, R, HEAPS[n % 4 + 1])
      end
    end
  end
  -- more trucks and diggers parked up on the benches, where one is level
  local function level(x, z, R)
    local y = K.ground(x, z)
    for k = 0, 7 do
      local a = k * 0.7854
      if math.abs(K.ground(x + math.cos(a) * R, z + math.sin(a) * R) - y) > 0.3 then return nil end
    end
    return y
  end
  local parked = 0
  for _ = 1, 160 do
    if parked < 9 then
      local x, z = K.spot(15)
      local y = x and free(x, z, 8) and level(x, z, 7.5)
      if y then
        take(x, z, 8)
        parked = parked + 1
        local a = rnd(0, 6.283)
        local f = v3(math.cos(a), 0, math.sin(a))
        if parked % 3 == 0 then
          excavator(v3(x, y, z), f, normalize(f + v3(-f.z, 0, f.x) * 0.6), 1.25)
        else
          truck(v3(x, y, z), f, 1.25, 0, parked % 2 == 0)
        end
      end
    end
  end
  mk('parked ' .. parked)
  for _ = 1, 220 do
    local x, z = K.spot(6)
    if x and free(x, z, 1) then boulder(x, z, rnd(0.8, 2.6)) end
  end
  info('quarry: ' .. n .. ' heaps, ' .. table.concat(made, ' '))
end

return T
