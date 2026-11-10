-- The racer: a cartoon soap-box driver in a red racing suit with yellow shoulders, a belt and chest pockets, brown
-- gloves and boots, a blue open-face helmet with a white stripe and a brown strap, goggles pushed up on it, a mop of
-- brown hair and a friendly grin. Modelled standing, feet at the origin, facing +z, its left +x, on the driver
-- library's skeleton (_driver.lua): the library binds nothing of this, but gives it its bones, its weights and every
-- clip the game plays (sit, lean, tuck, brace, cheer; the teammate's ready, push, stagger, flat), and the thrown
-- driver's ragdoll fits its rest pose.
local P = params{
  bob = {default=2.5, min=0, max=8, doc="How much the driver bobs in the seat, degrees"},
  lean = {default=22, min=5, max=40, doc="How far the driver leans into a turn, degrees"},
  segments = {default=14, min=8, max=24, integer=true, doc="Segments round each limb"},
  head = {default=1.18, min=0.8, max=1.3, doc="Head (and helmet) size"},
}

-- The palette (linear).
local RED = v3(0.66, 0.045, 0.025)
local RED_DARK = v3(0.42, 0.025, 0.015)
local YELLOW = v3(0.93, 0.5, 0.02)
local BLUE = v3(0.04, 0.09, 0.62)
local BLUE_DARK = v3(0.035, 0.08, 0.55)
local STRIPE = v3(0.9, 0.84, 0.62)
local GLOVE = v3(0.16, 0.065, 0.028)
local GLOVE_DARK = v3(0.1, 0.04, 0.018)
local BOOT = v3(0.1, 0.055, 0.03)
local SOLE = v3(0.04, 0.025, 0.015)
local STRAP = v3(0.3, 0.095, 0.028)
local METAL = v3(0.35, 0.35, 0.36)
local LENS = v3(0.04, 0.2, 0.75)
local SKIN = v3(0.76, 0.42, 0.26)
local LIP = v3(0.5, 0.19, 0.14)
local MOUTH = v3(0.2, 0.06, 0.04)
local EYE_WHITE = v3(0.82, 0.78, 0.74)
local IRIS = v3(0.13, 0.065, 0.028)
local LINER = v3(0.035, 0.035, 0.037)
local HAIR = v3(0.15, 0.055, 0.018)
local DARK = v3(0.025, 0.015, 0.012)
local BUCKLE = v3(0.3, 0.2, 0.1)

local suit_m = material{name="Racer suit", base_color=v3(1, 1, 1), roughness=0.85, metallic=0}
local skin_m = material{name="Racer skin", base_color=v3(1, 1, 1), roughness=0.65, metallic=0}
local helmet_m = material{name="Racer helmet", base_color=v3(1, 1, 1), roughness=0.3, metallic=0}
local leather_m = material{name="Racer leather", base_color=v3(1, 1, 1), roughness=0.7, metallic=0}
local glass_m = material{name="Racer goggles", base_color=v3(1, 1, 1), roughness=0.2, metallic=0.3}

local function body(K)
  local SEG = P.segments
  local function soft(m, a) return smooth_normals(m, {angle=a or 45}) end
  local function ell(at, r, segs) return translate(scale(sphere{radius=1, segments=segs or 16, rings=math.floor((segs or 16) / 2)}, {factor=r, pivot=origin()}), at) end

  -- ---- The suit: body lofted through its sections, sleeves and trouser legs swept down the limbs. ----
  do
    -- Each section: height, half width, half depth, how far forward.
    local secs = {
      {0.55, 0.06, 0.05, 0}, {0.565, 0.115, 0.09, 0}, {0.59, 0.15, 0.108, 0}, {0.63, 0.165, 0.118, 0},
      {0.68, 0.166, 0.12, 0.003}, {0.74, 0.16, 0.117, 0.005}, {0.8, 0.168, 0.12, 0.008}, {0.86, 0.18, 0.124, 0.008},
      {0.9, 0.184, 0.12, 0.004}, {0.935, 0.176, 0.11, 0}, {0.96, 0.15, 0.095, -0.004}, {0.98, 0.1, 0.075, -0.005},
      {0.99, 0.06, 0.056, -0.005},
    }
    local sections = {}
    local function cr(p0, p1, p2, p3, t)
      return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t)
    end
    local function section(q) return {p=K.slab(q[2], q[3], 2.6, 22), at=v3(0, q[1], q[4])} end
    for i = 1, #secs - 1 do
      local q0, q1, q2, q3 = secs[math.max(1, i - 1)], secs[i], secs[i + 1], secs[math.min(#secs, i + 2)]
      for k = 0, 1 do
        local t = k / 2
        local q = {}
        for c = 1, 4 do q[c] = cr(q0[c], q1[c], q2[c], q3[c], t) end
        sections[#sections + 1] = section(q)
      end
    end
    sections[#sections + 1] = section(secs[#secs])
    local torso = loft(sections, {caps=true})
    local pieces = {soft(torso, 60)}
    -- The stand-up collar, open a little at the front.
    pieces[#pieces + 1] = soft(translate(cylinder{radius=0.062, height=0.055, segments=SEG + 4}, v3(0, 1.0, -0.004)), 50)
    for side = -1, 1, 2 do
      local x = side
      -- Sleeve (a cuff turned back at the wrist) and trouser leg (a rolled cuff over the boot).
      pieces[#pieces + 1] = K.tube({{v3(0.19*x, 0.935, -0.005), 0.065}, {v3(0.24*x, 0.72, 0), 0.054}, {v3(0.254*x, 0.6, 0.012), 0.048}}, 5, true, false)
      pieces[#pieces + 1] = K.tube({{v3(0.252*x, 0.61, 0.011), 0.053}, {v3(0.258*x, 0.555, 0.016), 0.053}}, 1, false, false)
      pieces[#pieces + 1] = K.tube({{v3(0.098*x, 0.63, 0), 0.085}, {v3(0.1*x, 0.34, 0.01), 0.074}, {v3(0.1*x, 0.16, 0.006), 0.07}}, 5, true, false)
      pieces[#pieces + 1] = K.tube({{v3(0.1*x, 0.175, 0.006), 0.077}, {v3(0.1*x, 0.118, 0.005), 0.077}}, 1, false, false)
      -- Chest pockets, each with its flap; cargo pockets on the thighs' outsides.
      pieces[#pieces + 1] = translate(box{size=v3(0.06, 0.055, 0.014)}, v3(0.068*x, 0.84, 0.127))
      pieces[#pieces + 1] = translate(box{size=v3(0.066, 0.02, 0.02)}, v3(0.068*x, 0.873, 0.127))
      pieces[#pieces + 1] = translate(box{size=v3(0.016, 0.09, 0.075)}, v3(0.172*x, 0.43, 0.006))
      pieces[#pieces + 1] = translate(box{size=v3(0.022, 0.024, 0.081)}, v3(0.172*x, 0.48, 0.006))
    end
    -- The belt round the waist, its buckle in front.
    pieces[#pieces + 1] = translate(scale(cylinder{radius=1, height=0.036, segments=28}, {factor=v3(0.172, 1, 0.126), pivot=origin()}), v3(0, 0.71, 0.004))
    pieces[#pieces + 1] = translate(box{size=v3(0.05, 0.036, 0.012)}, v3(0, 0.71, 0.132))
    local suit = K.painted(join(table.unpack(pieces)), RED, {
      {BUCKLE, function(c, n) return c.z > 0.127 and math.abs(c.x) < 0.026 and math.abs(c.y - 0.71) < 0.019 end},
      {RED_DARK, function(c, n) return math.abs(c.y - 0.71) < 0.0185 and math.abs(c.x) < 0.18 end},
    })
    emit(K.bound(suit), {name="suit", material=suit_m})

    -- The yellow panels, each a piece laid over the suit with a clean edge: a yoke over each shoulder from the collar
    -- out, its front seam running down and out to the armpit, and a cap over each sleeve down to half way to the elbow.
    local panels = {}
    local over = scale(torso, {factor=v3(1.03, 1.012, 1.04), pivot=v3(0, 0.75, 0)})
    for side = -1, 1, 2 do
      local x = side
      local cut = rotate(translate(box{size=v3(0.22, 0.13, 0.4)}, v3(0.165 * x, 0.985, 0)), {angle=-26 * side, axis=axis_z(), pivot=v3(0.165 * x, 0.985, 0)})
      panels[#panels + 1] = soft(intersect(over, cut), 50)
      panels[#panels + 1] = K.tube({{v3(0.19*x, 0.937, -0.005), 0.07}, {v3(0.222*x, 0.8, -0.002), 0.062}}, 3, true, false)
    end
    emit(K.bound(K.painted(join(table.unpack(panels)), YELLOW, {})), {name="panels", material=suit_m})
  end

  -- ---- Gloves: brown mitts, a darker cuff, a thumb forward. ----
  do
    local parts = {}
    for side = -1, 1, 2 do
      local x = side
      parts[#parts + 1] = soft(ell(v3(0.266*x, 0.472, 0.024), v3(0.03, 0.058, 0.046), 14), 70)
      parts[#parts + 1] = soft(ell(v3(0.252*x, 0.49, 0.068), v3(0.018, 0.03, 0.017), 10), 70)
      parts[#parts + 1] = soft(translate(cone{radius=0.05, radius_top=0.056, height=0.036, segments=SEG}, v3(0.259*x, 0.522, 0.017)), 50)
    end
    emit(K.bound(K.painted(join(table.unpack(parts)), GLOVE, {
      {GLOVE_DARK, function(c, n) return c.y > 0.505 end},
    })), {name="gloves", material=leather_m})
  end

  -- ---- Boots: chunky brown boots, a rounded toe, a dark sole. ----
  do
    local parts = {}
    for side = -1, 1, 2 do
      local x = 0.1 * side
      local b = translate(box{size=v3(0.112, 0.085, 0.17)}, v3(x, 0.055, 0.02))
      b = bevel(b, {edges=sharp_edges(b, {angle=30}), width=0.02, segments=1})
      parts[#parts + 1] = soft(b, 40)
      parts[#parts + 1] = soft(ell(v3(x, 0.05, 0.1), v3(0.058, 0.048, 0.06), 14), 60)
      parts[#parts + 1] = soft(translate(cylinder{radius=0.064, height=0.05, segments=SEG}, v3(x, 0.11, 0.003)), 50)
      parts[#parts + 1] = translate(box{size=v3(0.122, 0.022, 0.235)}, v3(x, 0.011, 0.04))
    end
    emit(K.bound(K.painted(join(table.unpack(parts)), BOOT, {
      {SOLE, function(c, n) return c.y < 0.022 end},
    })), {name="boots", material=leather_m})
  end

  -- ---- The head: a young man's face, as near to life as a few thousand triangles go, grown about the chin (P.head). ----
  -- An oval face, broad at the cheekbones and narrowing to a defined jaw and chin; eyes set in sockets -- white, brown
  -- irises, dark lash lines -- under arched brows; a straight nose with a rounded tip and nostril wings; full lips in a
  -- small closed smile; wavy brown hair swept from under the helmet's brim, and more of it at the nape.
  local HP = v3(0, 1.04, 0)
  local function grow(m) return scale(m, {factor=P.head, pivot=HP}) end
  local function at(c) return HP + (c - HP) * (1 / P.head) end

  -- The head lofted from chin to crown: each section height, half width, half depth, how far forward.
  local ROUND = 2.5
  local WIDE = 1.14
  local HEAD = {
    {1.032, 0.022, 0.02, 0.07}, {1.04, 0.04, 0.036, 0.066}, {1.055, 0.06, 0.058, 0.055}, {1.075, 0.074, 0.078, 0.042},
    {1.1, 0.083, 0.091, 0.031}, {1.135, 0.09, 0.1, 0.021}, {1.17, 0.093, 0.104, 0.013}, {1.205, 0.093, 0.105, 0.007},
    {1.24, 0.087, 0.1, 0.002}, {1.268, 0.072, 0.086, 0}, {1.288, 0.046, 0.058, 0}, {1.297, 0.014, 0.018, 0},
  }
  local function cr(p0, p1, p2, p3, t)
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t)
  end
  local SUB = 3
  local function head_at(i, t)
    local q0, q1, q2, q3 = HEAD[math.max(1, i - 1)], HEAD[i], HEAD[i + 1], HEAD[math.min(#HEAD, i + 2)]
    local q = {}
    for c = 1, 4 do q[c] = cr(q0[c], q1[c], q2[c], q3[c], t) end
    q[2] = q[2] * WIDE
    return q
  end
  local function section_y(y)
    for i = 1, #HEAD - 1 do
      if y <= HEAD[i + 1][1] then
        local lo, hi = 0, 1
        for _ = 1, 30 do
          local mid = (lo + hi) / 2
          if head_at(i, mid)[1] < y then lo = mid else hi = mid end
        end
        return head_at(i, (lo + hi) / 2)
      end
    end
    return head_at(#HEAD - 1, 1)
  end
  -- A point on the face's front, `lift` proud of it, at (x, y).
  local function on_face(x, y, lift)
    local q = section_y(y)
    local u = math.min(1, math.abs(x) / q[2])
    return v3(x, y, q[4] + q[3] * (1 - u ^ ROUND) ^ (1 / ROUND) + lift)
  end

  local EYE_Y, EYE_X, EYE_R = 1.168, 0.035, 0.0135
  do
    local sections = {}
    for i = 1, #HEAD - 1 do
      for k = 0, SUB - 1 do
        local q = head_at(i, k / SUB)
        sections[#sections + 1] = {p=K.slab(q[2], q[3], ROUND, 40), at=v3(0, q[1], q[4])}
      end
    end
    local last = HEAD[#HEAD]
    sections[#sections + 1] = {p=K.slab(last[2], last[3], ROUND, 40), at=v3(0, last[1], last[4])}
    local skull = loft(sections, {caps=true})
    -- The eye sockets: a shallow hollow each side for the eye to sit in.
    local sockets = {}
    for side = -1, 1, 2 do
      sockets[#sockets + 1] = ell(on_face(EYE_X * side, EYE_Y, 0.004), v3(0.022, 0.012, 0.014), 16)
    end
    skull = subtract(skull, table.unpack(sockets))
    local parts = {smooth_normals(skull, {angle=55})}
    -- The nose: a bridge from between the brows down to a rounded tip, a wing either side of it.
    local top, tip = on_face(0, 1.17, -0.004), on_face(0, 1.124, 0.013)
    parts[#parts + 1] = smooth_normals(K.tube({{top, 0.0075}, {lerp(top, tip, 0.6), 0.0095}, {tip, 0.0105}}, 4, true, true), {angle=70})
    parts[#parts + 1] = smooth_normals(ell(tip + v3(0, -0.003, -0.005), v3(0.0125, 0.0105, 0.0105), 14), {angle=80})
    for side = -1, 1, 2 do
      parts[#parts + 1] = smooth_normals(ell(on_face(0.0135 * side, 1.115, 0.001), v3(0.009, 0.007, 0.008), 12), {angle=80})
    end
    -- The chin, a little forward and square.
    parts[#parts + 1] = smooth_normals(ell(on_face(0, 1.05, -0.016), v3(0.03, 0.018, 0.018), 14), {angle=80})
    parts[#parts + 1] = soft(translate(cylinder{radius=0.044, height=0.08, segments=SEG}, v3(0, 1.025, 0)), 60)
    emit(K.bound(K.painted(grow(join(table.unpack(parts))), SKIN, {})), {name="face", material=skin_m})

    -- The eyes: whites, brown irises with dark pupils, a dark lash line along each upper lid.
    local whites, irises, pupils, lashes = {}, {}, {}, {}
    for side = -1, 1, 2 do
      local c = on_face(EYE_X * side, EYE_Y, -0.012)
      whites[#whites + 1] = scale(sphere{radius=EYE_R, segments=16, rings=10}, {factor=v3(1.25, 0.8, 1), pivot=origin()})
      whites[#whites] = translate(whites[#whites], c)
      local front = c + v3(-0.002 * side, 0, EYE_R - 0.0006)
      irises[#irises + 1] = translate(cylinder{radius=0.0068, height=0.0016, segments=16, axis="z"}, front)
      pupils[#pupils + 1] = translate(cylinder{radius=0.003, height=0.0016, segments=12, axis="z"}, front + v3(0, 0, 0.0008))
      local lid = {}
      for i = 0, 8 do
        local t = i / 8
        local a = math.pi * (1 - t)
        local x = EYE_X * side + 0.017 * math.cos(a) * 1.0
        local y = EYE_Y + 0.0035 + 0.0075 * math.sin(a)
        lid[#lid + 1] = on_face(x, y, -0.0015)
      end
      lashes[#lashes + 1] = sweep(circle{radius=0.0016, segments=5}, path{points=lid}, {caps=true})
    end
    emit(K.bound(K.painted(grow(join(table.unpack(whites))), EYE_WHITE, {})), {name="eyes", material=skin_m})
    emit(K.bound(K.painted(grow(join(table.unpack(irises))), IRIS, {})), {name="irises", material=skin_m})
    emit(K.bound(K.painted(grow(join(join(table.unpack(pupils)), table.unpack(lashes))), DARK, {})), {name="pupils", material=skin_m})

    -- The brows: thick, arched, a little heavier at their inner ends.
    local BROW_P = poly{points={v2(0.006, 0), v2(0.003, 0.0032), v2(-0.003, 0.0032), v2(-0.006, 0), v2(-0.003, -0.0028), v2(0.003, -0.0028)}}
    local brows = {}
    for side = -1, 1, 2 do
      local pts, sc = {}, {}
      for i = 0, 6 do
        local t = i / 6
        local x = (0.013 + 0.05 * t) * side
        local y = 1.192 + 0.009 * math.sin(math.pi * (0.25 + 0.6 * t)) - 0.004 * t
        pts[#pts + 1] = on_face(x, y, -0.0005)
        sc[#sc + 1] = 1.25 - 0.55 * t
      end
      local b = sweep(BROW_P, path{points=pts}, {scale=sc, caps=true})
      brows[#brows + 1] = b
    end
    emit(K.bound(K.painted(grow(join(table.unpack(brows))), HAIR, {})), {name="brows", material=skin_m})

    -- The lips: an upper and a fuller lower, a dark line between them turning up a touch at the corners.
    local lips = {}
    lips[#lips + 1] = smooth_normals(ell(on_face(0, 1.09, -0.004), v3(0.024, 0.0055, 0.008), 14), {angle=80})
    lips[#lips + 1] = smooth_normals(ell(on_face(0, 1.0795, -0.004), v3(0.021, 0.0068, 0.009), 14), {angle=80})
    emit(K.bound(K.painted(grow(join(table.unpack(lips))), LIP, {})), {name="lips", material=skin_m})
    local line = {}
    for i = 0, 10 do
      local x = -0.028 + 0.056 * i / 10
      line[#line + 1] = on_face(x, 1.0855 + 0.004 * (x / 0.028) ^ 2, 0.0035)
    end
    emit(K.bound(K.painted(grow(sweep(circle{radius=0.0011, segments=5}, path{points=line}, {caps=true})), MOUTH, {})), {name="mouth", material=skin_m})
  end

  -- ---- Hair: wavy brown locks from under the brim across the forehead, more at the temples and the nape. ----
  do
    local parts = {}
    local function lock(base, dir, w, d, len, roll)
      local m = cone{radius=1, height=len, segments=5, anchor="base"}
      m = scale(m, {factor=v3(w, 1, d), pivot=origin()})
      m = rotate(m, {angle=roll or 0, axis=axis_y(), pivot=origin()})
      m = align(m, {from=axis_y(), to=normalize(dir), pivot=origin()})
      return translate(m, base)
    end
    -- The fringe: locks swept down and to his left, the middle ones longest.
    for i = -3, 3 do
      local x = i * 0.019
      local len = 0.05 - math.abs(i) * 0.006
      parts[#parts + 1] = lock(on_face(x, 1.244 - 0.01 * (i / 3) ^ 2, -0.006), v3(0.35, -1, 0.9), 0.017, 0.008, len, 20)
    end
    for side = -1, 1, 2 do
      parts[#parts + 1] = lock(v3(0.084 * side, 1.235, 0.062), v3(0.12 * side, -1, 0.3), 0.017, 0.009, 0.05)
      parts[#parts + 1] = lock(v3(0.09 * side, 1.2, 0.048), v3(0.08 * side, -1, 0.2), 0.014, 0.008, 0.045)
    end
    -- The nape: two rows of locks under the helmet's back.
    for row = 0, 1 do
      for i = -3, 3 do
        local x = i * 0.026 + row * 0.013
        parts[#parts + 1] = lock(v3(x, 1.1 - row * 0.02, -0.104 + math.abs(x) * 0.25 + row * 0.006), v3(x * 2, -1, -0.35), 0.018, 0.01, 0.045)
      end
    end
    emit(K.bound(K.painted(grow(soft(join(table.unpack(parts)), 50)), HAIR, {})), {name="hair", material=skin_m})
  end

  -- ---- The helmet: blue, a cream stripe over the crown, a thick dark liner round the face, hexagonal ear pads, a
  -- brown strap round it and big octagonal goggles up on its brow. ----
  local HMC, HMR = v3(0, 1.185, -0.018), v3(0.146, 0.155, 0.152)
  do
    -- The face's opening: a rounded rectangle pushed through from the front.
    local function opening(by, z0)
      local p = rounded_rect{w=0.2 + 2 * by, h=0.215 + 2 * by, radius=0.075 + by, segments=8}
      local m = rotate(extrude(p, {distance=0.3}), {angle=90, axis=axis_x(), pivot=origin()})
      return translate(m, v3(0, 1.132, z0 or 0.005))
    end
    -- And the sides scooped back towards the ears, so the face shows from the side.
    local function scoop(by)
      return translate(box{size=v3(0.5, 0.235 + 2 * by, 0.3)}, v3(0, 1.095, 0.15 - by))
    end
    local shell = ell(HMC, HMR, 28)
    local inner = ell(HMC, HMR * 0.9, 16)
    local under = translate(box{size=v3(0.5, 0.2, 0.5)}, v3(0, 0.955, 0))
    local hole = opening(0)
    local helmet = soft(subtract(shell, hole, scoop(0), under, inner), 40)
    local pads = {}
    for side = -1, 1, 2 do
      pads[#pads + 1] = soft(translate(cylinder{radius=0.045, height=0.018, segments=6, axis="x"}, v3(0.142 * side, 1.135, -0.055)), 20)
    end
    emit(K.bound(K.painted(grow(join(helmet, table.unpack(pads))), BLUE, {
      -- (Inside and on its cut edges, the liner's colour: only the rim shows of it.)
      {LINER, function(c, n) local q = at(c); return dot(n, q - HMC) < 0 or (q.z > -0.015 and q.y < 1.215) end},
      {BLUE_DARK, function(c, n) local q = at(c); return math.abs(q.x) > 0.145 and (q.y - 1.135) ^ 2 + (q.z + 0.055) ^ 2 < 0.047 ^ 2 end},
    })), {name="helmet", material=helmet_m})

    -- The liner: a thick dark rim round the opening, standing a little proud of the shell.
    local rim = intersect(ell(HMC, HMR * 1.035, 28), union(opening(0.016, -0.004), scoop(0.016)))
    rim = subtract(rim, opening(0.004, -0.03), scoop(0.004), under, ell(HMC, HMR * 0.86, 16))
    emit(K.bound(K.painted(grow(soft(rim, 35)), LINER, {})), {name="liner", material=leather_m})

    -- The stripe: a band laid over the crown, front to back, edges clean.
    local band = intersect(ell(HMC, HMR * 1.012, 26), translate(box{size=v3(0.06, 0.4, 0.5)}, v3(0, 1.2, 0)))
    band = subtract(band, opening(0.016, -0.004), scoop(0.016), under, ell(HMC, HMR * 0.95, 16))
    emit(K.bound(K.painted(grow(soft(band, 40)), STRIPE, {})), {name="stripe", material=helmet_m})

    -- The strap: round the helmet, up behind the goggles in front and down at the back.
    local strap = torus{major_radius=1, minor_radius=0.075, major_segments=36, minor_segments=4}
    strap = scale(strap, {factor=v3(0.153, 0.16, 0.158), pivot=origin()})
    strap = rotate(strap, {angle=-30, axis=axis_x(), pivot=origin()})
    strap = translate(strap, v3(0, 1.2, -0.02))
    emit(K.bound(K.painted(grow(soft(strap, 40)), STRAP, {})), {name="strap", material=leather_m})

    -- The goggles: two big octagonal grey frames with pale faceted lenses, a strap between them and a buckle at
    -- each side, tipped back on the helmet's brow.
    local LR = 0.041
    local frames, lenses = {}, {}
    for side = -1, 1, 2 do
      local fr = torus{major_radius=LR, minor_radius=0.011, major_segments=8, minor_segments=4, axis="z"}
      fr = rotate(fr, {angle=22.5, axis=axis_z(), pivot=origin()})
      fr = scale(fr, {factor=v3(1, 0.86, 1.4), pivot=origin()})
      local ln = scale(sphere{radius=1, segments=8, rings=4}, {factor=v3(LR * 0.95, LR * 0.82, 0.014), pivot=origin()})
      ln = rotate(ln, {angle=22.5, axis=axis_z(), pivot=origin()})
      local function turn(m) return translate(rotate(m, {angle=12 * side, axis=axis_y(), pivot=origin()}), v3(0.05 * side, 0, 0)) end
      frames[#frames + 1] = turn(fr)
      lenses[#lenses + 1] = turn(ln)
      frames[#frames + 1] = translate(box{size=v3(0.014, 0.026, 0.012)}, v3(0.098 * side, 0, -0.012))
    end
    local bridge = translate(box{size=v3(0.03, 0.016, 0.01)}, v3(0, 0, -0.006))
    local function place(m) return grow(translate(rotate(m, {angle=-28, axis=axis_x(), pivot=origin()}), v3(0, 1.28, 0.11))) end
    emit(K.bound(K.painted(place(soft(join(bridge, table.unpack(frames)), 30)), METAL, {
      {STRAP, function(c, n) local q = at(c); return math.abs(q.x) < 0.016 end},
    })), {name="goggles", material=glass_m})
    emit(K.bound(K.painted(place(soft(join(table.unpack(lenses)), 20)), LENS, {})), {name="lenses", material=glass_m})
  end
end

include("_driver.lua").build(P, "racer", {body=body})
