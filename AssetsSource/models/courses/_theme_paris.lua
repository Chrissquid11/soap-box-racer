-- The paris course's own scenery kit (see THEME KITS in _course.lua), on top of the library's city: the white domes of
-- Sacre-Coeur on terraces above the start, the Eiffel Tower beyond the finish, cream Haussmann blocks with zinc mansards
-- and iron balconies behind the rows, iron balconies and cafe terraces (red awnings, round tables, wicker chairs) on the
-- rows themselves, plane trees, candelabra lamps, Morris columns, Wallace fountains and painters at their easels along
-- the pavements, and a square at the finish with a carousel, a Metro entrance and the Place du Tertre's easels.
-- (The rows' houses are found again here exactly as the library's "The city" places them: change that, change `rows`.)
local T = {keep = true}

function T.build(K)
  local hexa, prism, ring, column, cone, ball = K.hexa, K.prism, K.ring, K.column, K.cone, K.ball
  local col, tint, hash = K.col, K.tint, K.hash
  local floor, max, min, cos, sin, pi, abs, sqrt = math.floor, math.max, math.min, math.cos, math.sin, math.pi, math.abs, math.sqrt
  local pos, right, W, N, HW, WALL = K.pos, K.right, K.W, K.N, K.HW, K.WALL_T
  local Y = v3(0, 1, 0)
  local solid, deco = K.solid, K.deco

  -- Colours (linear).
  local C = {
    cream = {col(0.86, 0.79, 0.63), col(0.9, 0.84, 0.7), col(0.8, 0.74, 0.6)},
    ledge = col(0.94, 0.9, 0.8), zinc = col(0.4, 0.45, 0.5), zinc_hi = col(0.52, 0.57, 0.62),
    glass = col(0.1, 0.15, 0.22), iron = col(0.03, 0.03, 0.035), chim = col(0.7, 0.6, 0.46), terra = col(0.7, 0.25, 0.1),
    red = col(0.78, 0.04, 0.04), awn_w = col(0.95, 0.93, 0.86),
    shop = {col(0.3, 0.04, 0.05), col(0.04, 0.2, 0.1), col(0.05, 0.1, 0.3), col(0.08, 0.08, 0.08)},
    marble = col(0.92, 0.92, 0.9), wicker = col(0.75, 0.52, 0.22), wicker_dk = col(0.5, 0.3, 0.1),
    green = col(0.04, 0.2, 0.11), green_hi = col(0.1, 0.34, 0.2), globe = col(1, 0.93, 0.68),
    posters = {col(0.9, 0.1, 0.08), col(0.95, 0.75, 0.1), col(0.1, 0.3, 0.8), col(0.95, 0.93, 0.85), col(0.9, 0.4, 0.05),
      col(0.1, 0.55, 0.3), col(0.6, 0.1, 0.5), col(0.05, 0.05, 0.06)},
    bark = col(0.62, 0.6, 0.48), bark2 = col(0.45, 0.47, 0.36), leaf = {col(0.3, 0.5, 0.1), col(0.22, 0.42, 0.08), col(0.38, 0.55, 0.14)},
    white = col(0.94, 0.92, 0.86), white2 = col(0.86, 0.84, 0.78), white_hi = col(1, 0.99, 0.95), dark = col(0.12, 0.13, 0.17),
    step = col(0.78, 0.76, 0.7), lawn = col(0.2, 0.48, 0.12), stonewall = col(0.82, 0.78, 0.68),
    eiffel = col(0.38, 0.26, 0.16), eiffel2 = col(0.5, 0.36, 0.22),
    gold = col(0.95, 0.72, 0.1), blue = col(0.1, 0.25, 0.7), canvas = col(0.96, 0.95, 0.9), wood = col(0.5, 0.32, 0.14),
    skin = col(0.85, 0.6, 0.45), navy = col(0.06, 0.1, 0.35), sign = col(0.93, 0.84, 0.45), orange = col(0.95, 0.3, 0.04),
    canopy = col(0.62, 0.78, 0.6), horse = {col(0.95, 0.95, 0.92), col(0.3, 0.16, 0.08), col(0.1, 0.1, 0.1), col(0.8, 0.7, 0.5)},
    paint = {col(0.2, 0.5, 0.9), col(0.9, 0.3, 0.2), col(0.95, 0.8, 0.2), col(0.3, 0.7, 0.3), col(0.7, 0.3, 0.7), col(0.95, 0.55, 0.7)},
  }

  local function S(b, c) local q = K.sub(b, c); q.ink = c; return q end
  local function one() return 1 end
  local flats, shades = {}, {}
  local function flat(c) local f = flats[c]; if not f then f = function() return c end; flats[c] = f end; return f end
  local function shade(c) local f = shades[c]; if not f then f = K.shaded(c); shades[c] = f end; return f end
  local function pickh(list, a, b) return list[1 + floor(hash(a, b) * #list * 0.9999)] end

  -- A box: its middle and its three half-extents.
  local function box(b, c, p, ax, ay, az)
    local a, d = p - az, p + az
    hexa(S(b, c), a - ax - ay, a + ax - ay, a + ax + ay, a - ax + ay, d - ax - ay, d + ax - ay, d + ax + ay, d - ax + ay)
  end
  -- A bar from p to q, th thick; `long` stretches it (a hair, so bars end to end share no corner).
  local function beam(b, c, p, q, th, long)
    local d = (q - p) * (0.5 * (long or 1))
    local s = cross(d, Y)
    if length(s) < 1e-5 then s = v3(1, 0, 0) end
    s = normalize(s)
    box(b, c, (p + q) * 0.5, d, normalize(cross(s, d)) * th, s * th)
  end
  -- An upright tube standing on p.
  local function tube(b, c, p, h, r0, r1, n, turn) column(S(b, c), p.x, p.z, p.y, p.y + h, r0, r1, n, c, turn or 0) end
  local function blob(b, c, p, rx, ry, rz, segs, rings_) ball(S(b, c), p, rx, ry, rz, segs, rings_, one, shade(c)) end
  -- A dome standing on p: R wide, H high, n round, m bands; one colour, or colour(j, k) under `key`.
  local function dome(b, c, p, R, H, n, m, key, turn)
    local rings = {}
    for j = 0, m do
      local a = j / m * pi * 0.5 * 0.93
      rings[#rings + 1] = ring(p + Y * (H * sin(a)), R * cos(a), R * cos(a), n, turn or 0)
    end
    if key then prism(K.sub(b, key), rings, c, c(1, 1), c(m, 1)) else prism(S(b, c), rings, flat(c), c, c) end
  end
  local function gy(x, z) return K.ground(x, z) end
  local function gp(p) return v3(p.x, K.ground(p.x, p.z), p.z) end
  local function off(p) local _, d = K.ground_d(p.x, p.z); return d - HW end

  -- Frames: a middle c, u along it, w its depth (away from the road). A box by its ranges along each and its heights.
  local function fpt(F, a, bb, y) local m = F.c + F.u * a + F.w * bb; return v3(m.x, y, m.z) end
  local function fbox(b, c, F, a0, a1, b0, b1, y0, y1)
    box(b, c, fpt(F, (a0 + a1) / 2, (b0 + b1) / 2, (y0 + y1) / 2), F.u * ((a1 - a0) / 2), Y * ((y1 - y0) / 2), F.w * ((b1 - b0) / 2))
  end

  -- Ground spoken for (circles), and a rectangle of it claimed: every corner at least `need` off the road's edge.
  local taken = {}
  local function free(x, z, r)
    for _, o in ipairs(taken) do
      local dx, dz, rr = x - o[1], z - o[2], r + o[3]
      if dx * dx + dz * dz < rr * rr then return false end
    end
    return true
  end
  local CORN = {{1, 1}, {-1, 1}, {-1, -1}, {1, -1}, {0, 0}, {1, 0}, {-1, 0}, {0, 1}, {0, -1}}
  local function place(c, u, w, hu, hw, need)
    local lo, hi = 1e9, -1e9
    for _, s in ipairs(CORN) do
      local q = c + u * (s[1] * hu) + w * (s[2] * hw)
      if q.x < K.X0 + 3 or q.x > K.X1 - 3 or q.z < K.Z1 + 3 or q.z > K.Z0 - 3 then return nil end
      local y, d = K.ground_d(q.x, q.z)
      if d - HW < need then return nil end
      lo, hi = min(lo, y), max(hi, y)
    end
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
    return {c = c, u = u, w = w, lo = lo, hi = hi, hu = hu, hw = hw}
  end

  -- A cafe table and its two wicker chairs (either side along t), standing on the ground at p.
  local function table_set(p, t, r, k)
    p = gp(p)
    tube(solid, C.iron, p - Y * 0.2, 0.24, 0.2, 0.2, 6)
    tube(solid, C.iron, p, 0.72, 0.035, 0.035, 4)
    tube(solid, C.marble, p + Y * 0.71, 0.05, 0.38, 0.38, 8)
    for sgn = -1, 1, 2 do
      local q = gp(p + t * (sgn * 0.68))
      local wk = ((k + sgn) % 3 == 0) and C.red or C.wicker
      box(solid, C.wicker_dk, q + Y * 0.21, t * 0.19, Y * 0.23, r * 0.2)
      box(solid, C.wicker, q + Y * 0.46, t * 0.23, Y * 0.035, r * 0.23)
      box(solid, wk, q + t * (sgn * 0.21) + Y * 0.7, t * 0.03, Y * 0.24, r * 0.22)
    end
  end

  -- THE ROWS, as the library placed them: each house's middle, frontage and floors.
  local rows = {}
  do
    local SET_BACK = HW + WALL + 4.5
    local run_ = 0
    for i = 2, N - 1 do
      run_ = run_ + length(pos[i] - pos[i - 1])
      if run_ >= 7.5 and abs(i - K.fin) > 14 then
        run_ = 0
        for side = -1, 1, 2 do
          local wid, deep = 3.2 + hash(i, side + 31) * 1.0, 4.5
          local r, t = right[i] * side, K.along(i)
          local c = pos[i] + r * (SET_BACK + W[i] - HW + deep)
          local ok = true
          for _, q in ipairs(rows) do if (q.c.x - c.x)^2 + (q.c.z - c.z)^2 < 49 then ok = false end end
          local hi = -math.huge
          for _, q in ipairs({{1, 1}, {-1, 1}, {1, -1}, {-1, -1}}) do
            local k = c + t * (q[1] * wid) + r * (q[2] * deep)
            local y, d = K.ground_d(k.x, k.z)
            if d < SET_BACK - 0.5 then ok = false end
            hi = max(hi, y)
          end
          if ok then
            rows[#rows + 1] = {c = c, i = i, side = side, t = t, r = r, wid = wid, deep = deep, hi = hi,
              floors = 2 + floor(hash(i, side + 41) * 3)}
          end
        end
      end
    end
  end

  -- Each house of the rows: an iron balcony across its first floor (and its top floor's rail, on the tall ones); a
  -- third of them a cafe -- a shopfront, a red awning, tables and chairs on the pavement.
  local cafes = 0
  for _, h in ipairs(rows) do
    local t, r = h.t, h.r
    local face = h.c - r * h.deep
    local function balcony(y, bars)
      local half = h.wid - 0.35
      box(solid, C.iron, v3(face.x, y, face.z) - r * 0.3, t * half, Y * 0.06, r * 0.34)
      box(solid, C.iron, v3(face.x, y + 0.95, face.z) - r * 0.58, t * half, Y * 0.035, r * 0.03)
      box(solid, C.iron, v3(face.x, y + 0.5, face.z) - r * 0.58, t * (half - 0.02), Y * 0.02, r * 0.02)
      for q = 0, bars - 1 do
        local a = ((q + 0.5) / bars * 2 - 1) * (half - 0.03)
        box(solid, C.iron, v3(face.x, y + 0.5, face.z) - r * 0.58 + t * a, t * 0.025, Y * 0.43, r * 0.025)
      end
    end
    balcony(h.hi + 3.9, 6)
    if h.floors >= 3 then balcony(h.hi + (h.floors - 1) * 3 + 0.9, 2) end
    if h.i > 26 and hash(h.i, h.side + 53) < 0.4 then
      cafes = cafes + 1
      local g0, g1 = gy((face - t * h.wid).x, (face - t * h.wid).z), gy((face + t * h.wid).x, (face + t * h.wid).z)
      local glo, ghi = min(g0, g1), max(g0, g1)
      local top = ghi + 2.75
      local shop = pickh(C.shop, h.i, h.side + 59)
      box(solid, shop, v3(face.x, (glo - 0.4 + top + 0.9) / 2, face.z) - r * 0.02, t * (h.wid - 0.2), Y * ((top + 0.9 - glo + 0.4) / 2), r * 0.09)
      box(solid, C.glass, v3(face.x, ghi + 1.75, face.z) - r * 0.06, t * (h.wid - 0.9), Y * 0.85, r * 0.08)
      box(solid, C.gold, v3(face.x, top + 0.55, face.z) - r * 0.08, t * (h.wid - 1.2), Y * 0.14, r * 0.05)
      -- The awning: a red wedge out over the pavement, a pale valance along its lip.
      local a0, a1 = v3(face.x, top + 0.25, face.z) - r * 0.05, v3(face.x, top - 0.45, face.z) - r * 1.9
      local tw, th = t * (h.wid - 0.3), Y * 0.05
      hexa(S(solid, C.red), a0 - tw - th, a0 + tw - th, a1 + tw - th, a1 - tw - th, a0 - tw + th, a0 + tw + th, a1 + tw + th, a1 - tw + th)
      box(solid, C.awn_w, a1 - Y * 0.2 - r * 0.02, t * (h.wid - 0.32), Y * 0.17, r * 0.025)
      for q = -1, 1 do
        local p = face - r * 1.2 + t * (q * h.wid * 0.62)
        if off(p) > WALL + 2.2 then table_set(p, t, r, q + h.i) end
      end
    end
  end

  -- SACRE-COEUR, on its terraces above the start: the white basilica, its tall egg of a dome on a windowed drum, four
  -- cupolas round it, the campanile behind; lawns and a flight of steps down toward the road.
  do
    local i0 = min(N - 2, K.start + 9)
    local r = right[i0] * -1
    local F = {c = pos[i0] + r * (W[i0] + WALL + 31), u = K.along(i0), w = r}
    local lo, hi, near = 1e9, -1e9, 1e9
    for _, q in ipairs({{-20, -17}, {20, -17}, {-16, 0}, {16, 0}, {-16, 38}, {16, 38}, {0, 19}, {0, -12}}) do
      local p = fpt(F, q[1], q[2], 0)
      local y, d = K.ground_d(p.x, p.z)
      lo, hi, near = min(lo, y), max(hi, y), min(near, d - HW)
    end
    if near > WALL + 9 then
      for b = -12, 34, 9 do for a = -12, 12, 12 do local p = fpt(F, a, b, 0); taken[#taken + 1] = {p.x, p.z, 10} end end
      local Y0 = min(hi + 0.5, pos[K.start].y + 17)
      local base = lo - 1.5
      -- The podium and the two terraces below it, their lawns, the steps up the middle.
      fbox(deco, C.stonewall, F, -16, 16, 0, 38, base, Y0)
      fbox(deco, C.stonewall, F, -18, 18, -6, 0.6, base, Y0 - 4.5)
      fbox(deco, C.stonewall, F, -20, 20, -12, -5.4, base, Y0 - 9)
      for sgn = -1, 1, 2 do
        fbox(deco, C.lawn, F, sgn * 10.8 - 6.6, sgn * 10.8 + 6.6, -5.6, -0.2, Y0 - 4.7, Y0 - 4.42)
        fbox(deco, C.lawn, F, sgn * 11.8 - 7.6, sgn * 11.8 + 7.6, -11.6, -6.3, Y0 - 9.2, Y0 - 8.92)
        -- A clipped tree at each lawn's end.
        for _, q in ipairs({{sgn * 14.5, -3, 4.5}, {sgn * 16.5, -9, 9}}) do
          local p = fpt(F, q[1], q[2], Y0 - q[3])
          tube(deco, C.bark2, p - Y * 0.2, 2.2, 0.2, 0.15, 5)
          blob(deco, C.leaf[2], p + Y * 3.2, 1.6, 1.7, 1.6, 7, 4)
        end
      end
      for f, fl in ipairs({{-17.4, Y0 - 13.5}, {-10.6, Y0 - 9}, {-4.7, Y0 - 4.5}}) do
        for j = 0, 5 do
          local ha = 3.4 - 0.03 * j - 0.01 * f
          fbox(deco, C.step, F, -ha, ha, fl[1] + j * 0.78, fl[1] + 5.2 + 0.01 * j, fl[2] - 1.5 - 0.01 * j, fl[2] + (j + 1) * 0.75)
        end
      end
      local function B(c, a0, a1, b0, b1, h0, h1) fbox(deco, c, F, a0, a1, b0, b1, Y0 + h0, Y0 + h1) end
      B(C.white2, -11.5, 11.5, 8, 26, -0.5, 9)           -- the aisles
      B(C.white, -9, 9, 5, 29, -0.4, 15)                 -- the nave
      B(C.white, -7, 7, 2, 5.3, -0.3, 10)                -- the porch, its three arched doors, its gable
      for q = -1, 1 do
        B(C.dark, q * 4.3 - 1.1, q * 4.3 + 1.1, 1.93, 2.2, 0.3, 5.4)
        B(C.dark, q * 4.3 - 0.75, q * 4.3 + 0.75, 1.94, 2.2, 5.35, 6.3)
        B(C.dark, q * 4.3 - 0.5, q * 4.3 + 0.5, 4.93, 5.2, 10.6, 13.4)
      end
      prism(S(deco, C.white_hi), {{fpt(F, -7.4, 1.8, Y0 + 9.9), fpt(F, 7.4, 1.8, Y0 + 9.9), fpt(F, 0, 1.8, Y0 + 12.8)},
        {fpt(F, -7.4, 5.4, Y0 + 9.9), fpt(F, 7.4, 5.4, Y0 + 9.9), fpt(F, 0, 5.4, Y0 + 12.8)}}, flat(C.white_hi), C.white_hi, C.white_hi)
      -- A drum with a ring of dark windows, an egg of a dome on it, a lantern and a spike.
      local TONES = {C.white2, C.white, C.white, C.white_hi, C.white_hi, C.white_hi}
      local function cupola(a, b, h, R, dh, H, n)
        local p = fpt(F, a, b, Y0 + h)
        prism(K.sub(deco, "drum"), {ring(p, R, R, n, 0), ring(p + Y * (dh * 0.25), R, R, n, 0), ring(p + Y * (dh * 0.8), R, R, n, 0),
          ring(p + Y * dh, R * 1.04, R * 1.04, n, 0)}, function(j, k) return (j == 2 and k % 2 == 0) and C.dark or C.white end, C.white, C.white)
        dome(deco, function(j) return TONES[min(#TONES, j)] end, p + Y * (dh - 0.1), R * 0.98, H, n, 5, "dome")
        local top = p + Y * (dh + H * 0.985)
        tube(deco, C.white, top - Y * (H * 0.06), R * 0.32, R * 0.2, R * 0.2, 6)
        dome(deco, C.white_hi, top + Y * (R * 0.24), R * 0.24, R * 0.4, 6, 2)
        tube(deco, C.white_hi, top + Y * (R * 0.55), R * 0.5, R * 0.04, R * 0.015, 4)
      end
      cupola(0, 17, 14.6, 5.4, 9.5, 12.5, 16)
      for _, q in ipairs({{-7.4, 8}, {7.4, 8}, {-7.4, 26}, {7.4, 26}}) do cupola(q[1], q[2], 14.7, 2.4, 3.6, 5.2, 8) end
      -- The campanile.
      B(C.white, -3.3, 3.3, 30, 36.6, -0.6, 36)
      for sgn = -1, 1, 2 do
        B(C.dark, sgn * 1.4 - 0.8, sgn * 1.4 + 0.8, 29.9, 30.1, 25, 33)
        B(C.dark, sgn * 1.4 - 0.8, sgn * 1.4 + 0.8, 36.5, 36.7, 25, 33)
        for _, bb in ipairs({31.9, 34.7}) do B(C.dark, sgn * 3.38 - 0.1, sgn * 3.38 + 0.1, bb - 0.8, bb + 0.8, 25, 33) end
      end
      B(C.white_hi, -3.6, 3.6, 29.7, 36.9, 35.6, 36.4)
      cupola(0, 33.3, 36.2, 3.0, 2.6, 6.5, 8)
    else
      info("paris: no room for Sacre-Coeur (" .. near .. ")")
    end
  end

  -- THE EIFFEL TOWER, far beyond the finish, on the line the course runs down: four lattice legs, three platforms,
  -- the arches between its feet, the spire.
  do
    local a, b = pos[K.start], pos[K.fin]
    local d = normalize(v3(b.x - a.x, 0, b.z - a.z))
    local s = v3(-d.z, 0, d.x)
    local best, bx, bz = -1e9, nil, nil
    for fwd = 60, 240, 15 do
      for lat = -90, 90, 15 do
        local x, z = b.x + d.x * fwd + s.x * lat, b.z + d.z * fwd + s.z * lat
        if x > K.X0 + 26 and x < K.X1 - 26 and z > K.Z1 + 26 and z < K.Z0 - 26 then
          local _, dd = K.ground_d(x, z)
          if dd - HW > 46 then
            local score = min(dd, 70) - abs(lat) * 0.25 - abs(fwd - 150) * 0.1
            if score > best then best, bx, bz = score, x, z end
          end
        end
      end
    end
    if bx then
      taken[#taken + 1] = {bx, bz, 27}
      local by = 1e9
      for _, q in ipairs({{1, 1}, {-1, 1}, {-1, -1}, {1, -1}}) do by = min(by, gy(bx + (d.x * q[1] + s.x * q[2]) * 20, bz + (d.z * q[1] + s.z * q[2]) * 20)) end
      by = by - 1
      local function P(u, w, h) return v3(bx + d.x * u + s.x * w, by + h, bz + d.z * u + s.z * w) end
      local function lin(tab, h)
        for k = 2, #tab do
          if h <= tab[k][1] then local f = (h - tab[k - 1][1]) / (tab[k][1] - tab[k - 1][1]); return tab[k - 1][2] + (tab[k][2] - tab[k - 1][2]) * f end
        end
        return tab[#tab][2]
      end
      local PROF, LW = {{0, 20.5}, {19.2, 11.4}, {38.2, 6.4}, {60, 3.8}, {92, 1.9}}, {{0, 8.2}, {19.2, 5.3}, {38.2, 3.7}}
      local IR = C.eiffel
      local function strut(p, q, th) beam(deco, IR, p, q, th, 1.012) end
      local function panel(c0, c1, post, brace, both)
        for q = 1, 4 do
          local q2 = q % 4 + 1
          strut(c0[q], c1[q], post)
          strut(c1[q], c1[q2], brace)
          strut(c0[q], c1[q2], brace)
          if both or q == 1 or q == 4 then strut(c0[q2], c1[q], brace) end
        end
      end
      for _, sg in ipairs({{1, 1}, {-1, 1}, {-1, -1}, {1, -1}}) do
        local function corners(h)
          local o, i_ = lin(PROF, h), lin(PROF, h) - lin(LW, h)
          return {P(sg[1] * o, sg[2] * o, h), P(sg[1] * o, sg[2] * i_, h), P(sg[1] * i_, sg[2] * i_, h), P(sg[1] * i_, sg[2] * o, h)}
        end
        for _, hs in ipairs({{0, 6.5, 13, 19.2}, {21.3, 26.8, 32.4, 38.2}}) do
          for k = 1, 3 do panel(corners(hs[k]), corners(hs[k + 1]), 0.48, 0.24, false) end
        end
      end
      local UP = {39.6, 46, 53, 61, 70, 80, 92}
      for k = 1, #UP - 1 do
        local function corners(h)
          local o = lin(PROF, h)
          return {P(o, o, h), P(-o, o, h), P(-o, -o, h), P(o, -o, h)}
        end
        panel(corners(UP[k]), corners(UP[k + 1]), 0.42, 0.2, true)
      end
      -- The arches between the feet.
      for side = 1, 4 do
        local last
        for j = 0, 8 do
          local sv = -1 + j / 4
          local h = 4 + 13.4 * sqrt(max(0, 1 - sv * sv))
          local fd, al = lin(PROF, h) - 0.4, sv * 12.6
          local p = (side == 1) and P(al, fd, h) or ((side == 2) and P(al, -fd, h) or ((side == 3) and P(fd, al, h) or P(-fd, al, h)))
          if last then strut(last, p, 0.36) end
          last = p
        end
      end
      for _, q in ipairs({{19.2, 21.3, 12.5}, {38.2, 39.6, 7.3}, {92, 94.2, 2.8}}) do
        box(deco, C.eiffel2, P(0, 0, (q[1] + q[2]) / 2), d * q[3], Y * ((q[2] - q[1]) / 2), s * q[3])
      end
      tube(deco, IR, P(0, 0, 94.1), 4.6, 1.5, 1.2, 8)
      tube(deco, IR, P(0, 0, 98.6), 11.5, 0.4, 0.08, 5)
    else
      info("paris: no room for the Eiffel Tower")
    end
  end

  -- A plane tree: a pale mottled trunk, a crown of two or three light green masses.
  local function plane(p, s, k)
    local rings = {}
    for j = 0, 3 do rings[j + 1] = ring(p + Y * (-0.4 + j * 1.55 * s), (0.3 - j * 0.045) * s, (0.3 - j * 0.045) * s, 6, j * 0.4) end
    prism(K.sub(solid, "plane"), rings, function(j, q) return ((j + q + k) % 3 == 0) and C.bark2 or C.bark end, C.bark, C.bark)
    local lf = C.leaf[k % 3 + 1]
    blob(deco, lf, p + Y * (5.6 * s), 1.45 * s, 1.5 * s, 1.45 * s, 8, 5)
    blob(deco, C.leaf[(k + 1) % 3 + 1], p + Y * (7.3 * s) + v3(0.2, 0, -0.15) * s, 1.15 * s, 1.2 * s, 1.15 * s, 7, 4)
  end
  -- A candelabra street lamp: a dark green post, a globe on each arm and one on top.
  local function lamp(p, t)
    tube(solid, C.green, p - Y * 0.3, 1.0, 0.17, 0.1, 6)
    tube(solid, C.green, p + Y * 0.6, 3.1, 0.06, 0.045, 5)
    box(solid, C.green, p + Y * 3.35, t * 0.55, Y * 0.035, cross(t, Y) * 0.035)
    for sgn = -1, 1, 2 do blob(deco, C.globe, p + Y * 3.62 + t * (sgn * 0.5), 0.19, 0.21, 0.19, 6, 4) end
    blob(deco, C.globe, p + Y * 3.95, 0.23, 0.26, 0.23, 6, 4)
  end
  -- A Morris column: a drum of posters under a green dome.
  local function morris(p, k)
    tube(solid, C.green, p - Y * 0.3, 0.7, 0.62, 0.6, 10)
    local ps = {}
    for q = 1, 10 do ps[q] = pickh(C.posters, k * 13 + q, 3) end
    prism(K.sub(solid, "posters"), {ring(p + Y * 0.35, 0.52, 0.52, 10, 0), ring(p + Y * 1.55, 0.52, 0.52, 10, 0), ring(p + Y * 2.75, 0.52, 0.52, 10, 0)},
      function(j, q) return ps[(q + j * 3) % 10 + 1] end, C.green, C.green)
    tube(solid, C.green, p + Y * 2.7, 0.3, 0.68, 0.66, 10)
    dome(solid, C.green, p + Y * 2.95, 0.6, 0.6, 10, 3)
    tube(solid, C.green_hi, p + Y * 3.5, 0.45, 0.07, 0.02, 4)
  end
  -- A Wallace fountain: four caryatids on a plinth holding up a little green dome.
  local function wallace(p)
    tube(solid, C.green, p - Y * 0.3, 0.85, 0.44, 0.36, 8)
    tube(solid, C.green_hi, p + Y * 0.5, 0.45, 0.3, 0.26, 8, 0.3)
    for q = 0, 3 do
      local a = q * pi / 2 + pi / 4
      tube(solid, C.green, p + Y * 0.9 + v3(cos(a), 0, sin(a)) * 0.2, 0.95, 0.065, 0.05, 5)
    end
    tube(solid, C.green_hi, p + Y * 1.8, 0.12, 0.4, 0.42, 8)
    dome(solid, C.green, p + Y * 1.9, 0.4, 0.42, 8, 3)
    tube(solid, C.green_hi, p + Y * 2.28, 0.3, 0.05, 0.015, 4)
  end
  -- A bench: green slats on iron ends, its back to the road.
  local function bench(p, t, r)
    box(solid, C.green_hi, p + Y * 0.45, t * 0.9, Y * 0.035, r * 0.22)
    box(solid, C.green_hi, p + Y * 0.75 - r * 0.2, t * 0.9, Y * 0.2, r * 0.03)
    for sgn = -1, 1, 2 do box(solid, C.iron, p + Y * 0.2 + t * (sgn * 0.75), t * 0.03, Y * 0.24, r * 0.2) end
  end
  -- A painter at an easel, the picture facing up the road; some under a parasol.
  local function easel(p, t, r, k)
    local top = p + Y * 1.75 + t * 0.14
    beam(solid, C.wood, p - r * 0.32 - Y * 0.1, top, 0.025)
    beam(solid, C.wood, p + r * 0.32 - Y * 0.1, top, 0.025)
    beam(solid, C.wood, gp(p + t * 0.6) - Y * 0.1, top, 0.025)
    box(solid, C.canvas, p + Y * 1.15 + t * 0.05, r * 0.38, Y * 0.3, t * 0.02)
    box(solid, pickh(C.paint, k, 5), p + Y * 1.22 + t * 0.03, r * 0.33, Y * 0.19, t * 0.015)
    box(solid, pickh(C.paint, k, 9), p + Y * 0.98 + t * 0.025, r * 0.33, Y * 0.09, t * 0.012)
    local m = gp(p + r * 0.8 - t * 0.45)
    local smock = (k % 2 == 0) and C.navy or C.canvas
    tube(solid, smock, m - Y * 0.15, 1.5, 0.24, 0.16, 6)
    blob(deco, C.skin, m + Y * 1.5, 0.13, 0.15, 0.13, 6, 4)
    tube(deco, (k % 3 == 0) and C.red or C.iron, m + Y * 1.6, 0.06, 0.19, 0.17, 6)
    if k % 2 == 1 then
      local q = gp(p + r * 0.75 + t * 0.35)
      tube(solid, C.marble, q - Y * 0.2, 2.6, 0.03, 0.03, 4)
      local pc = pickh(C.posters, k, 17)
      local c0 = q + Y * 2.15
      cone(K.sub(deco, "parasol"), ring(c0, 1.15, 1.15, 8, 0), c0 + Y * 0.02, c0 + Y * 0.55, function(n) return (n % 2 == 0) and pc or C.awn_w end, C.awn_w)
    end
  end

  -- THE PAVEMENTS: down both sides between the barriers and the rows, by turns a plane tree, a lamp, a plane tree and
  -- one of the street's own -- a Morris column, a painter, a Wallace fountain, a bench.
  local count = {trees = 0, lamps = 0, easels = 0}
  for side = -1, 1, 2 do
    local run, k = 3, 0
    for i = 25, N - 2 do
      run = run + length(pos[i] - pos[i - 1])
      if run >= 8.5 then
        run = 0
        k = k + 1
        local r, t = right[i] * side, K.along(i)
        local kind = k % 4
        local nearfin = i > K.fin - 43 and i < K.fin + 4
        local d = (kind == 3) and 1.95 or ((kind == 1) and 1.6 or 2.6)
        local p = gp(pos[i] + r * (W[i] + WALL + d))
        if off(p) >= WALL + d - 0.25 and abs(i - K.fin) > 3 then
          if kind == 1 or (kind == 0 and nearfin) then
            lamp(p, t); count.lamps = count.lamps + 1
          elseif kind ~= 3 then
            if not nearfin then plane(p, 0.9 + hash(i, side) * 0.25, k); count.trees = count.trees + 1 end
          else
            local n = floor(k / 4) % 4
            if n == 0 then morris(p, i + side)
            elseif n == 2 then wallace(p)
            elseif i < 110 or n == 1 then easel(p, t, r, i + side); count.easels = count.easels + 1
            else bench(p, t, r * -1) end
          end
        end
      end
    end
  end

  -- THE SQUARE AT THE FINISH, where the rows stand back: the carousel on one side; the Metro entrance, the painters of
  -- the Place du Tertre and a fountain on the other; plane trees.
  local function at(i, side, d) return pos[i] + right[i] * (side * (W[i] + WALL + d)) end
  do
    -- The carousel: a striped canopy over a ring of galloping horses on gold poles.
    -- (The library's two marquees and their bales stand here too: one each side, before the line.)
    for sd = -1, 1, 2 do
      local ms = max(2, min(N - 1, K.fin - 10 + sd * 3))
      local mc = at(ms, sd, 8.5)
      taken[#taken + 1] = {mc.x, mc.z, 4.2}
      mc = mc + K.along(ms) * 5.5
      taken[#taken + 1] = {mc.x, mc.z, 2.2}
    end
    local i = max(2, K.fin - 4)
    local c = at(i, -1, 6.3)
    local lo, hi, ok = 1e9, -1e9, off(c) > WALL + 6 and free(c.x, c.z, 4.8)
    for q = 0, 7 do
      local y = gy(c.x + cos(q * pi / 4) * 4.4, c.z + sin(q * pi / 4) * 4.4)
      lo, hi = min(lo, y), max(hi, y)
    end
    if ok then
      taken[#taken + 1] = {c.x, c.z, 4.8}
      local g0 = hi + 0.15
      local p = v3(c.x, g0, c.z)
      tube(solid, C.red, v3(c.x, lo - 0.5, c.z), g0 + 0.3 - lo + 0.5, 4.4, 4.4, 16)
      tube(solid, C.awn_w, p + Y * 0.2, 0.22, 4.2, 4.2, 16, 0.1)
      local PAN = {C.gold, C.awn_w, C.blue, C.awn_w}
      prism(K.sub(solid, "carousel"), {ring(p + Y * 0.3, 1.3, 1.3, 8, 0), ring(p + Y * 4.4, 1.3, 1.3, 8, 0)}, function(_, q) return PAN[q % 4 + 1] end, C.gold, C.gold)
      prism(K.sub(solid, "carousel"), {ring(p + Y * 3.75, 4.75, 4.75, 16, 0), ring(p + Y * 4.3, 4.85, 4.85, 16, 0)},
        function(_, q) return (q % 2 == 0) and C.awn_w or C.red end, C.awn_w, C.red)
      cone(K.sub(solid, "carousel"), ring(p + Y * 4.25, 4.7, 4.7, 16, 0), p + Y * 4.28, p + Y * 6.5, function(q) return (q % 2 == 0) and C.red or C.awn_w end, C.awn_w)
      blob(deco, C.gold, p + Y * 6.6, 0.3, 0.35, 0.3, 6, 4)
      tube(deco, C.gold, p + Y * 6.8, 1.2, 0.04, 0.02, 4)
      for q = 0, 11 do
        local outer = q % 3 ~= 2
        local a = q / 12 * pi * 2
        local rad = outer and 3.4 or 2.2
        local o, tg = v3(cos(a), 0, sin(a)), v3(-sin(a), 0, cos(a))
        local f = p + o * rad
        tube(solid, C.gold, f + Y * 0.35, 3.8, 0.04, 0.04, 4)
        local hc = pickh(C.horse, q, 7)
        local hb = f + Y * (1.35 + ((q % 2 == 0) and 0.35 or 0))
        ball(S(solid, hc), hb, 0.2, 0.26, 0.6, 6, 4, one, shade(hc))
        -- (the ball's long axis is z: a horse by itself, turned to the ring by its neck, legs and tail)
        beam(solid, hc, hb + tg * 0.3 + Y * 0.1, hb + tg * 0.62 + Y * 0.62, 0.1)
        box(solid, hc, hb + tg * 0.78 + Y * 0.62, tg * 0.2, Y * 0.09, o * 0.08)
        box(solid, pickh(C.posters, q, 3), hb + Y * 0.25, tg * 0.2, Y * 0.05, o * 0.23)
        for sgn = -1, 1, 2 do beam(solid, hc, hb + tg * (sgn * 0.35) - Y * 0.1, hb + tg * (sgn * 0.6) - Y * 0.7, 0.055) end
      end
    else
      info("paris: no room for the carousel")
    end

    -- The Metro entrance: green ironwork round the stairs, a glass butterfly canopy, two stalks with red lamps and the
    -- cream sign between them, facing up the road.
    i = max(2, K.fin - 13)
    local F = place(at(i, 1, 3.9), K.along(i), right[i], 2.9, 1.5, WALL + 1.6)
    if F then
      local g0 = F.hi + 0.12
      local G, GH = C.green, C.green_hi
      fbox(solid, C.step, F, -2.75, 2.75, -1.35, 1.35, F.lo - 0.5, g0)
      fbox(solid, C.dark, F, -2.3, 2.3, -0.95, 0.95, g0 - 0.3, g0 + 0.04)
      for sgn = -1, 1, 2 do
        fbox(solid, G, F, -2.55, 2.55, sgn * 1.18 - 0.035, sgn * 1.18 + 0.035, g0 + 0.2, g0 + 1.05)
        for q = 0, 2 do fbox(solid, C.sign, F, q * 1.7 - 2.3, q * 1.7 - 1.1, sgn * 1.18 - 0.05, sgn * 1.18 + 0.05, g0 + 0.42, g0 + 0.85) end
        for _, a in ipairs({-2.6, 0, 2.6}) do
          tube(solid, G, fpt(F, a, sgn * 1.18, g0 - 0.1), 3.25, 0.075, 0.055, 5)
          blob(solid, GH, fpt(F, a, sgn * 1.18, g0 + 1.2), 0.11, 0.11, 0.11, 5, 3)
        end
        -- The canopy's pane on this side, rising from the middle to its edge.
        local th = Y * 0.04
        local i0, i1, o0, o1 = fpt(F, -3.0, sgn * 0.04, g0 + 2.95), fpt(F, 3.0, sgn * 0.04, g0 + 2.95), fpt(F, -3.0, sgn * 1.75, g0 + 3.6), fpt(F, 3.0, sgn * 1.75, g0 + 3.6)
        hexa(S(solid, C.canopy), i0 - th, i1 - th, o1 - th, o0 - th, i0 + th, i1 + th, o1 + th, o0 + th)
        beam(solid, G, o0 + Y * 0.02, o1 + Y * 0.02, 0.05)
        for _, a in ipairs({-2.98, 0, 2.98}) do beam(solid, G, fpt(F, a, sgn * 0.05, g0 + 3.0), fpt(F, a, sgn * 1.74, g0 + 3.65), 0.045) end
        -- The stalk and its lamp.
        local s0, s1, s2, s3 = fpt(F, -3.05, sgn * 1.45, g0 - 0.2), fpt(F, -3.2, sgn * 1.6, g0 + 2.2), fpt(F, -3.15, sgn * 1.5, g0 + 3.5), fpt(F, -3.1, sgn * 1.2, g0 + 4.25)
        beam(solid, G, s0, s1, 0.06, 1.01); beam(solid, G, s1, s2, 0.05, 1.01); beam(solid, G, s2, s3, 0.04, 1.01)
        blob(deco, C.orange, s3 + Y * 0.1, 0.2, 0.26, 0.2, 6, 4)
      end
      fbox(solid, G, F, -3.2, -3.12, -1.5, 1.5, g0 + 2.45, g0 + 3.3)
      fbox(solid, C.sign, F, -3.26, -3.18, -1.38, 1.38, g0 + 2.55, g0 + 3.2)
      fbox(solid, G, F, -3.29, -3.24, -1.1, 1.1, g0 + 2.78, g0 + 2.98)
    else
      info("paris: no room for the Metro")
    end

    -- The Place du Tertre: painters in two ranks past the line; a fountain and benches opposite; plane trees behind.
    local k = 0
    for j = K.fin + 5, min(N - 2, K.fin + 13), 2 do
      for _, d in ipairs({2.4, 6.2}) do
        k = k + 1
        local p = gp(at(j + ((d > 3) and 1 or 0), -1, d))
        if off(p) > WALL + d - 0.4 and free(p.x, p.z, 1) then
          easel(p, K.along(j), right[j] * -1, k * 2 + ((d > 3) and 1 or 0))
          count.easels = count.easels + 1
        end
      end
    end
    local j = min(N - 2, K.fin + 8)
    local p = gp(at(j, 1, 5))
    if off(p) > WALL + 4.4 then
      taken[#taken + 1] = {p.x, p.z, 1.5}
      wallace(p)
      for sgn = -1, 1, 2 do bench(gp(p + K.along(j) * (sgn * 2.6)), right[j], K.along(j) * sgn) end
    end
    for _, q in ipairs({{-13, 1, 10.5}, {-9, -1, 3}, {-12, -1, 3}, {-1, 1, 10}, {5, 1, 10.5}, {13, 1, 9.5}, {9, -1, 10.5}, {14, -1, 10.5}, {-4, 1, 3}}) do
      local n = max(2, min(N - 2, K.fin + q[1]))
      local tp = gp(at(n, q[2], q[3]))
      if off(tp) > WALL + q[3] - 0.5 and free(tp.x, tp.z, 1.2) then
        taken[#taken + 1] = {tp.x, tp.z, 1.2}
        plane(tp, 1.15, n)
        count.trees = count.trees + 1
      end
    end
  end

  -- HAUSSMANN BLOCKS behind the rows (and fronting the square at the finish): six storeys of cream stone stepping down
  -- the hill, tall dark windows, black iron balconies along the second and fifth floors, a grey zinc mansard with
  -- dormers, chimney walls with their rows of pots.
  local blocks = 0
  local function block(F, full, k)
    local hu, hw = F.hu, F.hw
    local b = full and solid or deco
    local fy = gy(fpt(F, 0, -hw, 0).x, fpt(F, 0, -hw, 0).z)
    local flo = max(fy, F.lo + 1.5) + ((k % 3) - 1) * 0.5
    local FH = 3.3
    local yt = flo + 6 * FH + 0.6
    local cream = C.cream[k % 3 + 1]
    fbox(b, cream, F, -hu, hu, -hw, hw, F.lo - 0.8, yt)
    fbox(b, C.ledge, F, -hu - 0.15, hu + 0.15, -hw - 0.3, -hw + 0.4, yt - 0.3, yt + 0.06)
    local cols = 5
    for q = 1, cols do
      local a = ((q - 0.5) / cols * 2 - 1) * hu
      for fl = (full and 1 or 2), 5 do
        local y = flo + fl * FH
        fbox(b, C.glass, F, a - 0.55, a + 0.55, -hw - 0.07, -hw + 0.1, y + 0.75, y + 2.85)
      end
      -- The dormer on the mansard over each column of windows.
      fbox(b, C.ledge, F, a - 0.62, a + 0.62, -hw + 0.3, -hw + 1.9, yt + 0.5, yt + 2.3)
      fbox(b, C.glass, F, a - 0.4, a + 0.4, -hw + 0.24, -hw + 0.4, yt + 1.05, yt + 2.05)
    end
    for _, fl in ipairs({2, 5}) do
      local y = flo + fl * FH + 0.72
      fbox(b, C.ledge, F, -hu + 0.2, hu - 0.2, -hw - 0.62, -hw + 0.1, y - 0.13, y + 0.03)
      fbox(b, C.iron, F, -hu + 0.3, hu - 0.3, -hw - 0.56, -hw - 0.5, y + 0.05, y + 0.92)
    end
    -- The mansard.
    local function rect(e, ed, y) return fpt(F, -hu - e, -hw - ed, y), fpt(F, hu + e, -hw - ed, y), fpt(F, hu + e, hw + ed, y), fpt(F, -hu - e, hw + ed, y) end
    local a0, a1, a2, a3 = rect(0.2, 0.2, yt + 0.05)
    local b0, b1, b2, b3 = rect(-0.7, -1.7, yt + 3.4)
    hexa(S(b, C.zinc), a0, a1, a2, a3, b0, b1, b2, b3)
    fbox(b, C.zinc_hi, F, -hu + 0.9, hu - 0.9, -hw + 1.9, hw - 1.9, yt + 3.3, yt + 3.75)
    for sgn = -1, 1, 2 do
      fbox(b, C.chim, F, sgn * (hu - 1.3) - 0.3, sgn * (hu - 1.3) + 0.3, -2.2, 2.2, yt + 2, yt + 5.3)
      for q = -1, 1 do tube(b, C.terra, fpt(F, sgn * (hu - 1.3), q * 1.4, yt + 5.2), 0.8, 0.2, 0.16, 5) end
    end
    if full then
      -- A cafe along its foot: glass, a long red awning, tables out in front.
      fbox(b, pickh(C.shop, k, 3), F, -hu + 0.3, hu - 0.3, -hw - 0.1, -hw + 0.1, F.lo - 0.5, flo + 3.6)
      fbox(b, C.glass, F, -hu + 0.9, hu - 0.9, -hw - 0.16, -hw + 0.05, fy + 0.9, flo + 2.7)
      fbox(b, C.gold, F, -hu + 1.5, hu - 1.5, -hw - 0.16, -hw + 0.05, flo + 3.85, flo + 4.2)
      local top = max(flo, F.hi - 2.2) + 3.1
      local p0, p1, q0, q1 = fpt(F, -hu + 0.4, -hw - 0.05, top + 0.4), fpt(F, hu - 0.4, -hw - 0.05, top + 0.4), fpt(F, -hu + 0.4, -hw - 2.3, top - 0.4), fpt(F, hu - 0.4, -hw - 2.3, top - 0.4)
      local th = Y * 0.05
      hexa(S(b, C.red), p0 - th, p1 - th, q1 - th, q0 - th, p0 + th, p1 + th, q1 + th, q0 + th)
      fbox(b, C.awn_w, F, -hu + 0.42, hu - 0.42, -hw - 2.31, -hw - 2.26, top - 0.75, top - 0.42)
      for q = -2, 2 do
        local p = fpt(F, q * hu * 0.4, -hw - 1.5 - (q % 2) * 1.5, 0)
        if off(p) > WALL + 2.5 and free(p.x, p.z, 1) then table_set(p, F.u, F.w, q + k) end
      end
    end
    blocks = blocks + 1
  end
  for side = -1, 1, 2 do
    local run = 8
    for i = 3, N - 2 do
      run = run + length(pos[i] - pos[i - 1])
      if run >= 14.6 then
        local full = abs(i - K.fin) <= 12
        local front = full and 13.5 or 17.4
        local hu, hw = 6.6, 5.5
        local r = right[i] * side
        local F = place(pos[i] + r * (W[i] + WALL + front + hw), K.along(i), r, hu, hw, WALL + front - 1.2)
        if F then
          run = 0
          block(F, full, i + side)
        end
      end
    end
  end

  info(string.format("paris: %d houses dressed, %d cafes, %d blocks, %d plane trees, %d lamps, %d easels", #rows, cafes, blocks, count.trees, count.lamps, count.easels))
end

return T
