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
  face = {default=2400, min=1200, max=5000, integer=true, doc="Triangles in the face"},
}

-- The palette (linear).
local RED = v3(0.66, 0.045, 0.025)
local RED_DARK = v3(0.42, 0.025, 0.015)
local YELLOW = v3(0.93, 0.5, 0.02)
local BLUE = v3(0.04, 0.09, 0.62)
local BLUE_DARK = v3(0.035, 0.08, 0.55)
local STRIPE = v3(0.9, 0.84, 0.62)
local GLOVE = v3(0.2, 0.08, 0.035)
local GLOVE_DARK = v3(0.1, 0.04, 0.018)
local BOOT = v3(0.13, 0.065, 0.034)
local SOLE = v3(0.04, 0.025, 0.015)
local STRAP = v3(0.3, 0.095, 0.028)
local METAL = v3(0.35, 0.35, 0.36)
local LENS = v3(0.04, 0.2, 0.75)
local SKIN = v3(0.82, 0.49, 0.33)
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
      {0.568, 0.05, 0.04, 0}, {0.58, 0.1, 0.07, 0}, {0.6, 0.142, 0.09, 0}, {0.63, 0.163, 0.102, 0},
      {0.68, 0.166, 0.113, 0.003}, {0.74, 0.16, 0.117, 0.005}, {0.8, 0.168, 0.12, 0.008}, {0.86, 0.18, 0.124, 0.008},
      {0.9, 0.184, 0.12, 0.004}, {0.935, 0.176, 0.11, 0}, {0.96, 0.15, 0.095, -0.004}, {0.98, 0.1, 0.075, -0.005},
      {0.99, 0.06, 0.056, -0.005},
    }
    local sections = {}
    local function cr(p0, p1, p2, p3, t)
      return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t)
    end
    local function section(q) return {p=K.slab(q[2], q[3], 2.6, 18), at=v3(0, q[1], q[4])} end
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
      pieces[#pieces + 1] = K.tube({{v3(0.192*x, 0.924, -0.005), 0.063}, {v3(0.24*x, 0.72, 0), 0.054}, {v3(0.254*x, 0.6, 0.012), 0.048}}, 4, true, false)
      pieces[#pieces + 1] = K.tube({{v3(0.252*x, 0.61, 0.011), 0.053}, {v3(0.258*x, 0.555, 0.016), 0.053}}, 1, false, false)
      pieces[#pieces + 1] = K.tube({{v3(0.098*x, 0.63, 0), 0.085}, {v3(0.1*x, 0.34, 0.01), 0.074}, {v3(0.1*x, 0.16, 0.006), 0.07}}, 4, true, false)
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
    -- The placket down the front, collar to belt.
    pieces[#pieces + 1] = translate(box{size=v3(0.022, 0.185, 0.012)}, v3(0, 0.8215, 0.1295))
    local suit = K.painted(join(table.unpack(pieces)), RED, {
      {BUCKLE, function(c, n) return c.z > 0.127 and math.abs(c.x) < 0.026 and math.abs(c.y - 0.71) < 0.019 end},
      {RED_DARK, function(c, n) return math.abs(c.y - 0.71) < 0.0185 and math.abs(c.x) < 0.18 end},
      {RED_DARK, function(c, n) return n.z > 0.5 and math.abs(c.x) < 0.0115 and c.z > 0.13 and c.y > 0.729 end},
      -- (The pockets' flaps, a shade darker.)
      {RED_DARK, function(c, n) return n.z > 0.5 and c.z > 0.13 and math.abs(math.abs(c.x) - 0.068) < 0.034 and math.abs(c.y - 0.873) < 0.011 end},
      {RED_DARK, function(c, n) return math.abs(n.x) > 0.5 and math.abs(c.x) > 0.18 and math.abs(c.y - 0.48) < 0.013 and c.y < 0.6 end},
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
      panels[#panels + 1] = K.tube({{v3(0.192*x, 0.925, -0.005), 0.066}, {v3(0.222*x, 0.8, -0.002), 0.0605}}, 3, true, false)
    end
    emit(K.bound(K.painted(join(table.unpack(panels)), YELLOW, {})), {name="panels", material=suit_m})
  end

  -- ---- Gloves: brown mitts, a darker cuff, a thumb forward. ----
  do
    local parts = {}
    for side = -1, 1, 2 do
      local x = side
      parts[#parts + 1] = soft(ell(v3(0.266*x, 0.47, 0.024), v3(0.034, 0.062, 0.05), 14), 70)
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

  -- ---- The head: a young man's face in the game's low-poly way, grown about the chin (P.head). ----
  -- One smooth surface (a blended field, meshed and thinned): a broad brow over set-back eyes, cheekbones, a straight
  -- nose with a rounded tip and wings, a firm jaw and chin. The eyes sit behind almond openings, so the lids are the
  -- face's own; brown irises, a glint in each; thick low brows; lips in a small closed smile; brown hair from under
  -- the helmet's brim, at the temples and at the nape.
  local HP = v3(0, 1.04, 0)
  local function grow(m) return scale(m, {factor=P.head, pivot=HP}) end
  local function at(c) return HP + (c - HP) * (1 / P.head) end
  local MIRROR = {normal=v3(1, 0, 0), pivot=origin()}
  local function both(s) return sdf_symmetry(s, MIRROR) end
  local function blob(c, r) return sdf_ellipsoid{radii=r, center=c} end
  local function orb(c, r) return sdf_sphere{radius=r, center=c} end
  local ring8 = circle{radius=1, segments=8}

  local EYE_X, EYE_Y, EYE_R = 0.035, 1.168, 0.017
  local head_f
  -- The face's front at (x, y): where a ray from in front first meets the field.
  local function surf(x, y, f)
    local lo, hi = 0.0, 0.25
    for _ = 1, 30 do
      local mid = (lo + hi) / 2
      if sdf_distance(f or head_f, v3(x, y, mid)) < 0 then lo = mid else hi = mid end
    end
    return (lo + hi) / 2
  end
  local function on_face(x, y, lift) return v3(x, y, surf(x, y) + (lift or 0)) end
  local eye_z
  do
    -- Cranium, the face's mass, the neck, the jaw's two sides to the chin, cheekbones, the muzzle, the brow ridge.
    local base = sdf_union{parts={
      blob(v3(0, 1.195, -0.008), v3(0.094, 0.1, 0.106)),
      blob(v3(0, 1.132, 0.02), v3(0.075, 0.086, 0.084)),
      sdf_cylinder{a=v3(0, 0.975, -0.012), b=v3(0, 1.09, -0.012), radius=0.043},
      both(sdf_capsule{a=v3(0.05, 1.1, 0), b=v3(0.017, 1.062, 0.071), radius=0.019}),
      orb(v3(0, 1.063, 0.078), 0.025),
      both(orb(v3(0.055, 1.144, 0.055), 0.03)),
      blob(v3(0, 1.092, 0.086), v3(0.028, 0.022, 0.018)),
      sdf_capsule{a=v3(-0.044, 1.196, 0.088), b=v3(0.044, 1.196, 0.088), radius=0.014},
    }, blend=0.024}
    -- The nose: a bridge from between the brows to a rounded tip, a wing either side.
    local nosed = sdf_union{parts={
      base,
      sdf_round_cone{a=v3(0, 1.18, 0.092), b=v3(0, 1.135, 0.112), radius_a=0.006, radius_b=0.0085},
      orb(v3(0, 1.13, 0.12), 0.0105),
      both(orb(v3(0.0125, 1.124, 0.105), 0.0075)),
    }, blend=0.01}
    eye_z = surf(EYE_X, EYE_Y, nosed)
    -- The eyes' openings, and the head's back and top (under the helmet, never seen) left off.
    head_f = sdf_subtract{from=nosed, cut={both(blob(v3(EYE_X, EYE_Y, eye_z + 0.001), v3(0.02, 0.0094, 0.011)))}, blend=0.003}
    head_f = sdf_intersect{parts={head_f, sdf_box{size=v3(0.4, 0.3, 0.24), center=v3(0, 1.115, 0.035)}}}
    local skin = sdf_mesh(head_f, {edge_length=0.0035, symmetry=MIRROR})
    skin = decimate(skin, {target_triangles=P.face, symmetry="x"})
    emit(K.bound(K.painted(soft(grow(skin), 70), SKIN, {})), {name="face", material=skin_m})

    -- The eyes: a white ball behind each opening, a brown iris, a dark pupil, a glint; a lash line along each upper lid.
    local whites, irises, pupils, glints, lashes = {}, {}, {}, {}, {}
    for side = -1, 1, 2 do
      local c = v3(EYE_X * side, EYE_Y, eye_z - 0.0025 - EYE_R)
      whites[#whites + 1] = translate(sphere{radius=EYE_R, segments=12, rings=6}, c)
      local look = c + v3(-0.001 * side, 0.0008, EYE_R)
      irises[#irises + 1] = ell(look + v3(0, 0, -0.0013), v3(0.007, 0.007, 0.002), 10)
      pupils[#pupils + 1] = ell(look + v3(0, 0, -0.0003), v3(0.003, 0.003, 0.0015), 8)
      glints[#glints + 1] = ell(look + v3(0.0022, 0.0022, 0.0006), v3(0.0012, 0.0012, 0.0007), 6)
      local lid = {}
      for i = 0, 8 do
        local a = math.pi * (1 - i / 8)
        local x = EYE_X * side + 0.0175 * math.cos(a)
        local y = EYE_Y + 0.0004 + 0.0079 * math.sin(a)
        lid[#lid + 1] = on_face(x, y, 0.0007)
      end
      lashes[#lashes + 1] = sweep(circle{radius=0.0012, segments=5}, path{points=lid}, {caps=true})
    end
    emit(K.bound(K.painted(grow(join(join(table.unpack(whites)), table.unpack(glints))), EYE_WHITE, {})), {name="eyes", material=skin_m})
    emit(K.bound(K.painted(grow(join(table.unpack(irises))), IRIS, {})), {name="irises", material=skin_m})
    emit(K.bound(K.painted(grow(join(join(table.unpack(pupils)), table.unpack(lashes))), DARK, {})), {name="pupils", material=skin_m})

    -- The brows: thick and low, a slight arch, heavier at their inner ends.
    local BROW_P = poly{points={v2(0.0045, 0), v2(0.0028, 0.0045), v2(-0.0028, 0.0045), v2(-0.0045, 0), v2(-0.0028, -0.0045), v2(0.0028, -0.0045)}}
    local brows = {}
    for side = -1, 1, 2 do
      local pts, sc = {}, {}
      for i = 0, 6 do
        local t = i / 6
        local x = (0.012 + 0.05 * t) * side
        local y = 1.191 + 0.006 * math.sin(math.pi * (0.15 + 0.6 * t)) - 0.003 * t
        pts[#pts + 1] = on_face(x, y, 0.0005)
        sc[#sc + 1] = 1.2 - 0.6 * t
      end
      brows[#brows + 1] = sweep(BROW_P, path{points=pts}, {scale=sc, caps=true})
    end
    emit(K.bound(K.painted(grow(join(table.unpack(brows))), HAIR, {})), {name="brows", material=skin_m})

    -- The lips: a thin upper and a fuller lower, each swelling from the corners; a dark line between them, turned up
    -- at its ends.
    local function mouth_y(x) return 1.091 + 0.005 * (x / 0.03) ^ 2 end
    local function lip(half, dy, r, sink, pow)
      local pts, sc = {}, {}
      for i = 0, 10 do
        local t = i / 10
        local s = math.sin(math.pi * t) ^ pow
        local x = -half + 2 * half * t
        pts[#pts + 1] = on_face(x, mouth_y(x) + dy * (0.3 + 0.7 * s), -sink)
        sc[#sc + 1] = 0.0007 + r * s
      end
      return smooth_normals(sweep(ring8, path{points=pts}, {scale=sc, caps=true}), {angle=70})
    end
    emit(K.bound(K.painted(grow(join(lip(0.025, 0.0029, 0.0037, 0.0022, 0.7), lip(0.022, -0.0048, 0.0048, 0.003, 0.8))), LIP, {})),
      {name="lips", material=skin_m})
    local line = {}
    for i = 0, 10 do
      local t = i / 10
      local x = -0.028 + 0.056 * t
      line[#line + 1] = on_face(x, mouth_y(x), 0.0002 + 0.0011 * math.sin(math.pi * t))
    end
    emit(K.bound(K.painted(grow(sweep(circle{radius=0.001, segments=5}, path{points=line}, {caps=true})), MOUTH, {})), {name="mouth", material=skin_m})
  end

  -- ---- Hair: a band of it under the brim and a fringe of locks swept down the forehead, locks at the temples, and a
  -- thatch at the nape below the helmet's back. ----
  do
    local parts = {}
    local function lock(base, dir, w, d, len, roll)
      local m = cone{radius=1, height=len, segments=6, anchor="base"}
      m = scale(m, {factor=v3(w, 1, d), pivot=origin()})
      m = rotate(m, {angle=roll or 0, axis=axis_y(), pivot=origin()})
      m = align(m, {from=axis_y(), to=normalize(dir), pivot=origin()})
      return translate(m, base)
    end
    local CAP_C, CAP_R = v3(0, 1.2, -0.006), v3(0.099, 0.098, 0.112)
    parts[#parts + 1] = intersect(ell(CAP_C, CAP_R, 16), translate(box{size=v3(0.3, 0.09, 0.2)}, v3(0, 1.253, 0.1)))
    local function on_cap(x, y)
      local u = 1 - (x / CAP_R.x) ^ 2 - ((y - CAP_C.y) / CAP_R.y) ^ 2
      return v3(x, y, CAP_C.z + CAP_R.z * math.sqrt(math.max(0, u)))
    end
    for i = -3, 3 do
      local x = i * 0.021 + 0.004
      local len = 0.034 - math.abs(i) * 0.004
      parts[#parts + 1] = lock(on_cap(x, 1.224) + v3(0, 0, -0.004), v3(0.3 + i * 0.04, -1, 0.3), 0.017, 0.009, len, 20)
    end
    for side = -1, 1, 2 do
      parts[#parts + 1] = lock(v3(0.083 * side, 1.218, 0.052), v3(0.04 * side, -1, 0.12), 0.015, 0.011, 0.062)
      parts[#parts + 1] = lock(v3(0.09 * side, 1.205, 0.03), v3(0.03 * side, -1, 0.1), 0.014, 0.011, 0.05)
    end
    -- The nape: a mass of it, two rows of locks hanging from under the helmet's back.
    parts[#parts + 1] = ell(v3(0, 1.094, -0.024), v3(0.084, 0.03, 0.076), 14)
    for row = 0, 1 do
      for i = -3, 3 do
        local x = i * 0.024 + row * 0.012
        if math.abs(x) < 0.08 then
          local z = -0.022 - (0.082 - row * 0.012) * math.sqrt(1 - (x / 0.09) ^ 2)
          parts[#parts + 1] = lock(v3(x, 1.09 - row * 0.008, z), v3(x * 1.2, -1, -0.12 - row * 0.05), 0.02, 0.012, 0.048 - row * 0.012)
        end
      end
    end
    emit(K.bound(K.painted(soft(grow(join(table.unpack(parts))), 50), HAIR, {})), {name="hair", material=skin_m})
  end

  -- ---- The helmet: a blue open-face shell -- a dome on a short skirt that comes round the jaw as cheek guards -- a
  -- cream stripe over the crown, a thick dark liner round the face, hexagonal ear pads, a brown strap round it and one
  -- under the jaw, and big octagonal goggles up on its brow. ----
  local HMC = v3(0, 1.185, -0.018)
  local HRX, HRY, HRZ = 0.132, 0.15, 0.146
  local BOTTOM = 1.075
  do
    -- How wide the shell is at a height, as a part of its widest.
    local function girth(y)
      if y >= HMC.y then return math.sqrt(math.max(0, 1 - ((y - HMC.y) / HRY) ^ 2)) end
      local t = (HMC.y - y) / (HMC.y - BOTTOM)
      return 1 - 0.07 * t * t
    end
    -- The shell's shape `k` times as big round, from `y0` up.
    local function helm(k, y0, n)
      local secs = {}
      local function add(y, f) secs[#secs + 1] = {p=K.slab(HRX * k * f, HRZ * k * f, 2, n or 28), at=v3(0, y, HMC.z)} end
      add(y0, girth(y0))
      for _, y in ipairs({1.11, 1.15}) do
        if y > y0 + 0.01 then add(y, girth(y)) end
      end
      for i = 0, 7 do
        local th = rad(i * 11.5)
        add(HMC.y + HRY * k * math.sin(th), math.cos(th))
      end
      add(HMC.y + HRY * k * math.sin(rad(87)), math.cos(rad(87)))
      return loft(secs, {caps=true})
    end
    -- The face's opening: a rounded rectangle pushed through from the front (`by` bigger all round, or `bx` at its
    -- sides: the shell is steep there, and a little across it is a lot along it) ...
    local function opening(by, z0, bx)
      local p = rounded_rect{w=0.212 + 2 * (bx or by), h=0.195 + 2 * by, radius=0.07 + (bx or by), segments=6}
      local m = rotate(extrude(p, {distance=0.3}), {angle=90, axis=axis_x(), pivot=origin()})
      return translate(m, v3(0, 1.13, z0 or 0))
    end
    -- ... and a window through from side to side, back to behind the eyes: the cheek guards are what is left below it.
    local function window(by)
      local p = rounded_rect{w=0.3, h=0.115 + 2 * by, radius=0.045 + by, segments=6}
      local m = rotate(extrude(p, {distance=0.4}), {angle=90, axis=axis_x(), pivot=origin()})
      m = rotate(m, {angle=90, axis=axis_y(), pivot=origin()})
      return translate(m, v3(-0.2, 1.1675, 0.212 - by))
    end
    local hollow = helm(0.9, 1.0, 16)
    local helmet = soft(subtract(helm(1, BOTTOM), opening(0.004), window(0.004), hollow), 40)
    local pads = {}
    for side = -1, 1, 2 do
      pads[#pads + 1] = soft(translate(cylinder{radius=0.042, height=0.02, segments=6, axis="x"}, v3(0.123 * side, 1.135, -0.04)), 20)
    end
    emit(K.bound(K.painted(grow(join(helmet, table.unpack(pads))), BLUE, {
      -- (Inside, the liner's colour.)
      {LINER, function(c, n) local q = at(c); return math.abs(q.x) < 0.125 and dot(n, q - HMC) < 0 end},
      {BLUE_DARK, function(c, n) local q = at(c); return math.abs(q.x) > 0.1325 and (q.y - 1.135) ^ 2 + (q.z + 0.04) ^ 2 < 0.044 ^ 2 end},
    })), {name="helmet", material=helmet_m})

    -- The liner: a thick dark pad round the opening, standing a little proud of the shell.
    local rim = intersect(helm(1.03, BOTTOM - 0.006), union(opening(0.016, -0.012, 0.005), window(0.016)))
    rim = subtract(rim, opening(0, -0.04), window(0), helm(0.92, 1.0, 16))
    emit(K.bound(K.painted(grow(soft(rim, 35)), LINER, {})), {name="liner", material=leather_m})

    -- The stripe: a band laid over the crown, front to back, edges clean.
    local band = intersect(helm(1.012, BOTTOM + 0.001), translate(box{size=v3(0.05, 0.4, 0.5)}, v3(0, 1.2, 0)))
    band = subtract(band, opening(0.016, -0.02, 0.005), window(0.016), helm(0.95, 1.0, 16))
    emit(K.bound(K.painted(grow(soft(band, 40)), STRIPE, {})), {name="stripe", material=helmet_m})

    -- The goggles' strap: round the helmet, up behind the goggles in front and down at the back; and the chin strap,
    -- from one cheek guard under the jaw to the other.
    local pts = {}
    for i = 0, 35 do
      local a = rad(i * 10)
      local y = 1.2 + 0.06 * math.cos(a)
      local g = girth(y) * 1.012
      pts[#pts + 1] = v3(HRX * g * math.sin(a), y, HMC.z + HRZ * g * math.cos(a))
    end
    local strap = sweep(rect{w=0.006, h=0.024}, path{points=pts, closed=true}, {up=axis_y()})
    local chin = {}
    for i = 0, 10 do
      local a = rad(-90 + i * 18)
      chin[#chin + 1] = v3(0.106 * math.sin(a), 1.092 - 0.047 * math.cos(a), 0.036 + 0.014 * math.cos(a))
    end
    local under = sweep(circle{radius=0.0055, segments=6}, path{points=chin}, {caps=true})
    emit(K.bound(K.painted(grow(join(soft(strap, 40), soft(under, 60))), STRAP, {})), {name="strap", material=leather_m})

    -- The goggles: two big octagonal grey frames with blue faceted lenses, a strap between them and a buckle at
    -- each side, tipped back on the helmet's brow.
    local LR = 0.043
    local frames, lenses = {}, {}
    for side = -1, 1, 2 do
      local fr = torus{major_radius=LR, minor_radius=0.011, major_segments=8, minor_segments=4, axis="z"}
      fr = rotate(fr, {angle=22.5, axis=axis_z(), pivot=origin()})
      fr = scale(fr, {factor=v3(1, 0.86, 1.4), pivot=origin()})
      local ln = scale(sphere{radius=1, segments=8, rings=4}, {factor=v3(LR * 0.95, LR * 0.82, 0.014), pivot=origin()})
      ln = rotate(ln, {angle=22.5, axis=axis_z(), pivot=origin()})
      local function turn(m) return translate(rotate(m, {angle=18 * side, axis=axis_y(), pivot=origin()}), v3(0.053 * side, 0, 0)) end
      frames[#frames + 1] = turn(fr)
      lenses[#lenses + 1] = turn(ln)
      frames[#frames + 1] = translate(box{size=v3(0.014, 0.03, 0.012)}, v3(0.104 * side, 0, -0.03))
    end
    local bridge = translate(box{size=v3(0.03, 0.016, 0.01)}, v3(0, 0, -0.004))
    local function place(m) return grow(translate(rotate(m, {angle=-32, axis=axis_x(), pivot=origin()}), v3(0, 1.262, 0.121))) end
    emit(K.bound(K.painted(place(soft(join(bridge, table.unpack(frames)), 30)), METAL, {
      {STRAP, function(c, n) local q = at(c); return math.abs(q.x) < 0.016 end},
    })), {name="goggles", material=glass_m})
    emit(K.bound(K.painted(place(soft(join(table.unpack(lenses)), 20)), LENS, {})), {name="lenses", material=glass_m})
  end
end

include("_driver.lua").build(P, "racer", {body=body})
