-- The driver library: a small cartoon racer skinned to a Mixamo-named skeleton, with the clips the game plays as the
-- kart runs, in one of the outfits the garage offers. A leading underscore keeps it out of the build: each outfit's
-- own script (driver.lua, driver_chicken.lua ...) includes it and calls build with its params and its outfit:
--
--   racer   -- race overalls, an open-face crash helmet with goggles, a scarf, gloves and boots
--   chicken -- a chicken suit: feathered body, a hood with a comb and a beak, orange legs and feet, a tail
--   banana  -- a banana suit: yellow peel from the boots to a stalk over the head
--   viking  -- a fur-trimmed tunic, a horned helmet, a big ginger beard
--   granny  -- a pink spotted dressing gown, a grey bun in curlers, glasses and fluffy slippers
--
-- Every outfit has the same skeleton, clips and shape -- the thrown driver's ragdoll maps its bodies onto the rest
-- pose (src/game/ragdoll-skin.ts) and the game sits the hips (HIPS up) on the seat -- so they swap freely. Modelled
-- standing, feet on the ground at the origin, facing +z, its left +x.
--
-- Clips: sit (riding, a little bob), lean_left / lean_right (steering), tuck (head down for speed),
-- brace (arms up, a landing or a crash coming), cheer (over the line). All loop but brace.
--
-- Each limb is one tube swept down its bones (so it bends at its joint without a seam); the colours are painted on
-- the vertices over white materials.
local M = {}

-- `V`, for the casual outfit (a spectator): its colours -- shirt, trousers, shoes, skin, hair -- whether its sleeves
-- are short, its hat ("cap", "flatcap", or none: hair), a high-vis jacket's reflective bands (`hivis`), and what it
-- holds in its right hand (`prop`: "phone", "cup", "flag" or "placard", in `propColour` and `propColour2`).
function M.build(P, O, V)
  V = V or {}
  local CASUAL = O == "casual"
  -- A costume in the crowd (`V.crowd`): a driver's outfit, but drawn as a spectator is -- one merged mesh, few segments.
  local MERGED = CASUAL or V.crowd == true
  -- A crowd figure's round parts (its head, its hat, its badges, its hands' bits) at half the segments: a crowd is
  -- many figures far off, and its curves read the same at a few metres. (Its limbs keep P.segments: the circle is untouched.)
  local function lowres(f)
    return function(o)
      local c = {}
      for k, v in pairs(o) do c[k] = v end
      for _, k in ipairs({"segments", "rings", "major_segments", "minor_segments"}) do
        if type(c[k]) == "number" then c[k] = math.max(k == "rings" and 3 or 6, math.floor(c[k] * 0.5 + 0.5)) end
      end
      return f(c)
    end
  end
  local sphere = MERGED and lowres(sphere) or sphere
  local cylinder = MERGED and lowres(cylinder) or cylinder
  local torus = MERGED and lowres(torus) or torus
  local cone = MERGED and lowres(cone) or cone
  local capsule = MERGED and lowres(capsule) or capsule
  -- A spectator is drawn hundreds of times down a course: its parts are kept back here and emitted as one mesh at
  -- the end ("fan"), one draw a figure, not one a part. (A driver keeps its parts: the game tints and hides them.)
  local emit_part = emit
  local held_parts = {}
  -- (Kept unbound -- `skinned` hands back a marker -- merged, then bound once: a merge drops a binding. What is bound
  -- its own way, the prop in the hand, is emitted as it is.)
  local emit = function(m, o)
    if MERGED and type(m) == "table" and m.unbound then held_parts[#held_parts + 1] = {mesh=smooth_normals(m.unbound, {angle=50}), material=o.material}
    else emit_part(m, o) end
  end
  local cloth = material{name="Overalls", base_color=v3(1,1,1), roughness=0.85, metallic=0}
  local skin_m = material{name="Skin", base_color=v3(1,1,1), roughness=0.65, metallic=0}
  local helmet_m = material{name="Helmet", base_color=v3(1,1,1), roughness=0.22, metallic=0}
  local lens_m = material{name="Goggles", base_color=v3(1,1,1), roughness=0.15, metallic=0.25}
  local boot_m = material{name="Boots", base_color=v3(1,1,1), roughness=0.7, metallic=0}
  local metal_m = material{name="Metal", base_color=v3(1,1,1), roughness=0.35, metallic=0.6}

  -- The palette (linear).
  local RED = v3(0.75, 0.035, 0.025)
  local WHITE = v3(0.92, 0.92, 0.9)
  local YELLOW = v3(1.0, 0.68, 0.02)
  local BLACK = v3(0.025, 0.025, 0.03)
  local GREY = v3(0.2, 0.2, 0.22)
  local BLUE = v3(0.015, 0.16, 0.75)
  local CYAN = v3(0.08, 0.6, 0.9)
  local SKIN = v3(0.86, 0.52, 0.36)
  local CHEEK = v3(0.9, 0.34, 0.28)
  local LIP = v3(0.4, 0.08, 0.06)
  local LEATHER = v3(0.4, 0.17, 0.05)
  local FEATHER = v3(0.95, 0.93, 0.86)
  local ORANGE = v3(1.0, 0.36, 0.02)
  local COMB = v3(0.85, 0.02, 0.03)
  local PEEL = v3(1.0, 0.82, 0.08)
  local BRUISE = v3(0.22, 0.12, 0.03)
  local STALK = v3(0.35, 0.45, 0.06)
  local FUR = v3(0.55, 0.42, 0.28)
  local WOOL = v3(0.12, 0.2, 0.08)
  local IRON = v3(0.45, 0.46, 0.5)
  local IVORY = v3(0.9, 0.85, 0.7)
  local GINGER = v3(0.85, 0.28, 0.03)
  local GOLD = v3(0.95, 0.6, 0.08)
  local PINK = v3(0.95, 0.42, 0.62)
  local BABY = v3(0.4, 0.62, 1.0)
  local SILVER = v3(0.72, 0.72, 0.74)
  local TIGHTS = v3(0.72, 0.5, 0.36)
  local LEOPARD = v3(0.8, 0.48, 0.12)
  local SPOT = v3(0.12, 0.06, 0.02)
  local DARK_HAIR = v3(0.06, 0.03, 0.015)
  local BONE = v3(0.92, 0.88, 0.76)
  local GREEN = v3(0.04, 0.42, 0.06)
  local BLOND = v3(0.95, 0.72, 0.3)
  local SAUCE = v3(0.62, 0.015, 0.01)
  if CASUAL then SKIN = V.skin or SKIN end

  local HIPS = 0.62
  local SHOULDER = 0.95

  -- The skeleton: hips up the spine to the head; arms from the shoulders, legs from the hips.
  local joints = {
    joint{name="Hips", head=v3(0, HIPS, 0), tail=v3(0, 0.74, 0)},
    joint{name="Spine", head=v3(0, 0.74, 0), tail=v3(0, 0.98, 0), parent="Hips"},
    joint{name="Neck", head=v3(0, 0.98, 0), tail=v3(0, 1.04, 0), parent="Spine"},
    joint{name="Head", head=v3(0, 1.04, 0), tail=v3(0, 1.3, 0), parent="Neck"},
  }
  for side = -1, 1, 2 do
    local s = side > 0 and "Left" or "Right"
    local x = side
    joints[#joints + 1] = joint{name=s .. "Arm", head=v3(0.21*x, SHOULDER, 0), tail=v3(0.24*x, 0.72, 0), parent="Spine"}
    joints[#joints + 1] = joint{name=s .. "ForeArm", head=v3(0.24*x, 0.72, 0), tail=v3(0.26*x, 0.5, 0.02), parent=s .. "Arm"}
    joints[#joints + 1] = joint{name=s .. "UpLeg", head=v3(0.1*x, HIPS - 0.02, 0), tail=v3(0.1*x, 0.34, 0.01), parent="Hips"}
    joints[#joints + 1] = joint{name=s .. "Leg", head=v3(0.1*x, 0.34, 0.01), tail=v3(0.1*x, 0.07, 0), parent=s .. "UpLeg"}
  end
  local skel = skeleton{name="driver", joints=joints, forward=v3(0, 0, 1), up=v3(0, 1, 0)}

  -- Each joint's reach, for the weights: a limb's vertices go to the bone they sit along.
  local envs = {
    envelope{joint="Hips", radius=0.24},
    envelope{joint="Spine", radius=0.22},
    envelope{joint="Neck", radius=0.08},
    envelope{joint="Head", radius=0.2},
  }
  for _, s in ipairs({"Left", "Right"}) do
    envs[#envs + 1] = envelope{joint=s .. "Arm", radius=0.085}
    envs[#envs + 1] = envelope{joint=s .. "ForeArm", radius=0.085}
    envs[#envs + 1] = envelope{joint=s .. "UpLeg", radius=0.13}
    envs[#envs + 1] = envelope{joint=s .. "Leg", radius=0.16}
  end
  -- The head (and all it wears), boots and hands are rigid: wholly the head's, the shin's and the forearm's.
  local regions = {
    region{joint="Head", min=v3(-0.4, 1.035, -0.3), max=v3(0.4, 1.8, 0.35), weight=1},
  }
  for side = -1, 1, 2 do
    local s = side > 0 and "Left" or "Right"
    local x = 0.1 * side
    regions[#regions + 1] = region{joint=s .. "Leg", min=v3(x - 0.1, -0.01, -0.1), max=v3(x + 0.1, 0.13, 0.26), weight=1}
    local hx = 0.265 * side
    regions[#regions + 1] = region{joint=s .. "ForeArm", min=v3(hx - 0.075, 0.4, -0.07), max=v3(hx + 0.075, 0.555, 0.13), weight=1}
  end
  local function bound(m) return bind(m, skel, {method="envelope", envelopes=envs, regions=regions}) end
  local function skinned(m) if MERGED then return {unbound=m} end return bound(m) end

  -- A driver's head is a little big: everything on it is modelled at the old size about the face, then grown by HEAD_GROW about
  -- the jaw (HEAD_PIVOT), so the chin stays on the neck. Its paint rules read the old, unscaled coordinates (unhead).
  -- (A spectator's head is its natural size: an ordinary person in the crowd, not a cartoon.)
  -- (The giant baby's is bigger still: a baby is mostly head.)
  local HEAD_GROW = CASUAL and 1.0 or (O == "baby" and 1.32 or 1.12)
  local HEAD_PIVOT = v3(0, 1.03, 0)
  local function head_grow(m) return scale(m, {factor=HEAD_GROW, pivot=HEAD_PIVOT}) end
  local function unhead(c) return HEAD_PIVOT + (c - HEAD_PIVOT) * (1 / HEAD_GROW) end

  -- Painting: `rules` in order, each { colour, fn(centre, normal) -> bool }, the first to hold wins; `base` where none does.
  -- `map`, given, turns a face's centre into the coordinates the rules are written in.
  local function painted(m, base, rules, map)
    m = paint_faces(m, {faces=faces_where(m, function(_) return true end), color=base})
    for i = #rules, 1, -1 do
      local r = rules[i]
      local sel = faces_where(m, function(f) return r[2](map and map(f.center) or f.center, f.normal) == true end)
      if set_count(sel) > 0 then m = paint_faces(m, {faces=sel, color=r[1]}) else warn(O .. ": unpainted rule " .. i) end
    end
    return m
  end

  local SEG = P.segments
  local unit = circle{radius=1, segments=SEG}

  -- A tube swept through `keys` ({position, radius} ...), `steps` sections between each pair, its radius eased along
  -- it; a rounded dome over an end with `dome_a` / `dome_b`, else a flat cap.
  local function tube(keys, steps, dome_a, dome_b)
    -- (A crowd figure: half the sections along it, and a coarser dome.)
    if MERGED then steps = math.max(1, math.ceil(steps / 2)) end
    local rings = MERGED and 2 or 4
    local pts, sc = {}, {}
    local function add(p, r) pts[#pts + 1] = p; sc[#sc + 1] = r end
    local function dome(k, toward, outward)
      local d = normalize(k[1] - toward[1])
      local order = {}
      for i = 1, rings do order[i] = outward and i or rings + 1 - i end
      for _, i in ipairs(order) do
        local th = rad(i * 76 / rings)
        add(k[1] + d * (k[2] * math.sin(th)), k[2] * math.cos(th))
      end
    end
    if dome_a then dome(keys[1], keys[2], false) end
    for j = 1, #keys - 1 do
      local a, b = keys[j], keys[j + 1]
      for s = 0, steps - 1 do
        local t = s / steps
        local e = t * t * (3 - 2 * t)
        add(lerp(a[1], b[1], t), a[2] + (b[2] - a[2]) * e)
      end
    end
    add(keys[#keys][1], keys[#keys][2])
    if dome_b then dome(keys[#keys], keys[#keys - 1], true) end
    return smooth_normals(sweep(unit, path{points=pts}, {scale=sc, caps=true}), {angle=60})
  end

  -- A rounded slab of a section, a superellipse (n = 2 an ellipse, more squarer).
  local function slab(rx, rz, n, count)
    if MERGED then count = math.max(8, math.floor(count / 2)) end
    local pts = {}
    for i = 0, count - 1 do
      local a = 2 * math.pi * i / count
      local c, s = math.cos(a), math.sin(a)
      local function sp(v) return (v >= 0 and 1 or -1) * math.abs(v) ^ (2 / n) end
      pts[#pts + 1] = v2(rx * sp(c), rz * sp(s))
    end
    return poly{points=pts}
  end

  local function ball(r, at, f, segs)
    local sg = segs or (MERGED and 10 or 24)
    local m = sphere{radius=r, segments=sg, rings=math.floor(sg / 2)}
    if f then m = scale(m, {factor=f, pivot=origin()}) end
    return translate(m, at)
  end

  -- An open-face hood or helmet shell round the head: its face cut out, its bottom cut off
  -- at the neck.
  local function shell(f)
    local s = ball(1, v3(0, 1.16, -0.008), f or v3(0.135, 0.13, 0.142), 40)
    local opening = translate(capsule{radius=0.1, height=0.12, segments=32, rings=6, axis="z"}, v3(0, 1.1, 0.13))
    return smooth_normals(subtract(s, opening, translate(box{size=v3(0.4, 0.1, 0.4)}, v3(0, 0.99, 0))), {angle=50})
  end

  local function front(c, n) return n.z > 0.45 end
  local function legs(c) return c.y < 0.6 and math.abs(c.x) < 0.2 end
  local function arms(c) return math.abs(c.x) > 0.2 end

  -- An outfit of its own (`V.body`): its script models the figure on this skeleton with this kit, and the library
  -- adds the clips (driver.lua: the racer).
  if V.body then
    V.body({skel=skel, bound=bound, painted=painted, tube=tube, slab=slab, ball=ball, shell=shell, HIPS=HIPS, SHOULDER=SHOULDER})
  else
  -- The suit's paint, outfit by outfit: its base colour and its rules.
  local SUIT = {
    racer = {RED, {
      {YELLOW, function(c, n) return front(c, n) and math.abs(c.x) < 0.03 and c.y > 0.7 and c.y < 0.738 end},
      {BLACK, function(c, n) return c.y > 0.7 and c.y < 0.738 and math.abs(c.x) < 0.19 end},
      {BLACK, function(c, n) return c.y > 0.975 and math.abs(c.x) < 0.12 end},
      {GREY, function(c, n) return n.z > 0.25 and c.y > 0.29 and c.y < 0.4 and math.abs(math.abs(c.x) - 0.1) < 0.06 end},
      {BLACK, function(c, n) return c.y < 0.15 and math.abs(c.x) < 0.2 end},
      {BLACK, function(c, n) return c.y < 0.58 and arms(c) end},
      {WHITE, function(c, n) return legs(c) and math.abs(c.x) > 0.13 and math.abs(n.x) > 0.96 end},
      {YELLOW, function(c, n) return arms(c) and math.abs(n.x) > 0.95 and c.y < 0.9 end},
      {YELLOW, function(c, n) return c.y > 0.905 and math.abs(c.x) > 0.075 end},
      {WHITE, function(c, n) return c.y > 0.882 and c.y <= 0.905 and math.abs(c.x) < 0.19 end},
      {BLUE, function(c, n) return math.abs(c.x) < 0.2 and c.y > 0.74 and c.y < 0.9 and math.abs(n.x) > 0.75 end},
    }},
    chicken = {FEATHER, {
      -- Bare orange chicken legs below the fluffy knees.
      {ORANGE, function(c, n) return c.y < 0.3 and math.abs(c.x) < 0.2 end},
      -- A ruffle of feathers at the knees, and shaggy tufts down the sides.
      {WHITE, function(c, n) return c.y < 0.36 and math.abs(c.x) < 0.2 end},
      {WHITE, function(c, n) return math.abs(n.x) > 0.8 and (math.floor(c.y / 0.035) % 2) == 0 end},
    }},
    banana = {PEEL, {
      -- The black-brown end at the feet, the peel's seams, and a few bruises.
      {BRUISE, function(c, n) return c.y < 0.13 and math.abs(c.x) < 0.2 end},
      {BRUISE, function(c, n) return not arms(c) and (math.abs(c.x) < 0.01 or (math.abs(n.x) > 0.97 and c.y > 0.6)) end},
      {BRUISE, function(c, n) return n.z > 0.3 and ((c.x - 0.06)^2 + (c.y - 0.8)^2 < 0.018^2 or (c.x + 0.05)^2 + (c.y - 0.67)^2 < 0.013^2) end},
      {STALK, function(c, n) return c.y > 0.975 end},
    }},
    viking = {LEATHER, {
      -- A broad belt and a gold buckle.
      {GOLD, function(c, n) return front(c, n) and math.abs(c.x) < 0.035 and c.y > 0.69 and c.y < 0.745 end},
      {BLACK, function(c, n) return c.y > 0.69 and c.y < 0.745 and math.abs(c.x) < 0.19 end},
      -- A fur collar over the shoulders, fur cuffs, and wool trousers bound with straps.
      {FUR, function(c, n) return c.y > 0.9 end},
      {FUR, function(c, n) return c.y < 0.6 and arms(c) end},
      {BLACK, function(c, n) return c.y < 0.45 and math.abs(c.x) < 0.2 and (math.floor((c.y + c.x * 0.3) / 0.04) % 2) == 0 end},
      {WOOL, function(c, n) return c.y < 0.6 and math.abs(c.x) < 0.2 end},
    }},
    granny = {PINK, {
      -- The dressing gown's cord, its white spots, its fluffy collar and cuffs, and tan tights below its hem.
      {TIGHTS, function(c, n) return c.y < 0.36 and math.abs(c.x) < 0.2 end},
      {WHITE, function(c, n) return c.y > 0.7 and c.y < 0.725 and math.abs(c.x) < 0.19 end},
      {WHITE, function(c, n) return c.y > 0.96 end},
      {WHITE, function(c, n) return c.y < 0.58 and arms(c) end},
      -- A white patch pocket on the chest.
      {WHITE, function(c, n) return n.z > 0.5 and c.x > 0.03 and c.x < 0.11 and c.y > 0.8 and c.y < 0.87 end},
    }},
    chef = {WHITE, {
      -- Black and white checked trousers, and the double-breasted jacket's two rows of black buttons.
      {BLACK, function(c, n) return c.y < 0.6 and math.abs(c.x) < 0.2 and (math.floor(c.x / 0.03) + math.floor(c.y / 0.03)) % 2 == 0 end},
      {WHITE, function(c, n) return c.y < 0.6 and math.abs(c.x) < 0.2 end},
      {BLACK, function(c, n) return n.z > 0.5 and math.abs(math.abs(c.x) - 0.055) < 0.011 and c.y > 0.72 and c.y < 0.93 and (c.y % 0.05) < 0.016 end},
    }},
    baby = {BABY, {
      -- A pale blue vest, a big white nappy, bare chubby legs and arms, a white bib with a yellow duck on it.
      {SKIN, function(c, n) return c.y < 0.43 and math.abs(c.x) < 0.2 end},
      {WHITE, function(c, n) return c.y < 0.68 and math.abs(c.x) < 0.2 end},
      {SKIN, function(c, n) return arms(c) and c.y < 0.84 end},
      {YELLOW, function(c, n) return n.z > 0.4 and (c.x / 0.035)^2 + ((c.y - 0.875) / 0.03)^2 < 1 end},
      {WHITE, function(c, n) return n.z > 0.3 and (c.x / 0.11)^2 + ((c.y - 0.9) / 0.1)^2 < 1 end},
    }},
    caveman = {LEOPARD, {
      -- A spotted animal skin over one shoulder, a rope belt, bare arms and legs.
      {SKIN, function(c, n) return c.y < 0.46 and math.abs(c.x) < 0.2 end},
      {SKIN, function(c, n) return arms(c) end},
      {SKIN, function(c, n) return c.x < -0.04 and c.y > 0.86 end},
      {FUR, function(c, n) return c.y > 0.66 and c.y < 0.69 end},
      {SPOT, function(c, n) return (math.floor(c.x / 0.045) + math.floor(c.y / 0.045) * 3 + math.floor(c.z / 0.045) * 7) % 5 == 0 end},
    }},
    hotsauce = {SAUCE, {
      -- The bottle's label on the chest: white, a red chilli on it, flames licking up from its bottom edge.
      {COMB, function(c, n) return n.z > 0.3 and (c.x / 0.06)^2 + ((c.y - 0.81) / 0.022)^2 < 1 end},
      {GREEN, function(c, n) return n.z > 0.3 and c.x > 0.055 and c.x < 0.085 and math.abs(c.y - 0.818) < 0.012 end},
      {ORANGE, function(c, n) return n.z > 0.3 and math.abs(c.x) < 0.13 and c.y > 0.66 and c.y < 0.72 + 0.025 * math.sin(c.x * 90) end},
      {YELLOW, function(c, n) return n.z > 0.3 and math.abs(c.x) < 0.13 and c.y > 0.66 and c.y < 0.745 + 0.03 * math.sin(c.x * 90) end},
      {WHITE, function(c, n) return n.z > 0.3 and math.abs(c.x) < 0.13 and c.y > 0.66 and c.y < 0.89 end},
      {BLACK, function(c, n) return c.y < 0.15 and math.abs(c.x) < 0.2 end},
    }},
  }
  -- A spectator: a shirt or jumper, trousers or jeans, the forearms bare with short sleeves.
  SUIT.casual = {V.shirt or BLUE, {
    {V.trousers or GREY, function(c, n) return c.y < 0.62 and math.abs(c.x) < 0.2 end},
  }}
  if V.short then table.insert(SUIT.casual[2], 1, {SKIN, function(c, n) return arms(c) and c.y < 0.8 end}) end
  -- A marshal's high-vis: two silver reflective bands round the body, one round each sleeve.
  if V.hivis then table.insert(SUIT.casual[2], 1, {SILVER, function(c, n)
    return c.y > 0.62 and ((c.y > 0.735 and c.y < 0.765) or (c.y > 0.835 and c.y < 0.865) or (arms(c) and c.y < 0.66))
  end}) end
  local suit = SUIT[O] or error("no outfit " .. tostring(O))

  -- The suit: the body lofted through its sections, sleeves and trouser legs swept down the limbs, a collar.
  do
    -- Each section: height, half width, half depth, and how far forward.
    local secs = {
      {0.548, 0.05, 0.045, 0}, {0.562, 0.1, 0.08, 0}, {0.585, 0.133, 0.1, 0}, {0.62, 0.152, 0.11, 0},
      {0.67, 0.155, 0.112, 0.002}, {0.72, 0.148, 0.108, 0.004}, {0.77, 0.152, 0.11, 0.006}, {0.82, 0.162, 0.115, 0.008},
      {0.87, 0.17, 0.116, 0.008}, {0.91, 0.17, 0.112, 0.004}, {0.94, 0.162, 0.104, 0}, {0.965, 0.14, 0.09, -0.004},
      {0.982, 0.1, 0.07, -0.005}, {0.992, 0.06, 0.055, -0.005},
    }
    -- A chicken is plump, a banana long and thin at the top: the body's girth, section by section.
    local girth = ({chicken = 1.22, granny = 1.14, casual = 1.03, chef = 1.16, baby = 1.26, hotsauce = 1.2, caveman = 1.12})[O] or 1.08
    local sections = {}
    -- Three sections to each step of the table, eased (Catmull-Rom) through it, so the body is smooth and fine enough
    -- to paint its belt and panels on.
    local function cr(p0, p1, p2, p3, t)
      return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t)
    end
    local function section(q)
      -- The girth swells the belly most, the shoulders and the neck not at all.
      local g = 1 + (girth - 1) * math.max(0, 1 - math.abs(q[1] - 0.76) / 0.2)
      return {p=slab(q[2] * g, q[3] * g, 2.6, 40), at=v3(0, q[1], q[4])}
    end
    for i = 1, #secs - 1 do
      local q0, q1, q2, q3 = secs[math.max(1, i - 1)], secs[i], secs[i + 1], secs[math.min(#secs, i + 2)]
      for k = 0, 2 do
        local t = k / 3
        local q = {}
        for c = 1, 4 do q[c] = cr(q0[c], q1[c], q2[c], q3[c], t) end
        sections[#sections + 1] = section(q)
      end
    end
    sections[#sections + 1] = section(secs[#secs])
    local body = smooth_normals(loft(sections, {caps=true}), {angle=60})
    local pieces = {body}
    pieces[#pieces + 1] = smooth_normals(translate(cylinder{radius=0.05, height=0.05, segments=SEG}, v3(0, 1.0, -0.003)), {angle=60})
    for side = -1, 1, 2 do
      local x = side
      pieces[#pieces + 1] = tube({{v3(0.19*x, 0.935, -0.005), 0.06}, {v3(0.24*x, 0.72, 0), 0.05}, {v3(0.257*x, 0.535, 0.016), 0.044}}, 8, true, false)
      pieces[#pieces + 1] = tube({{v3(0.096*x, 0.63, 0), 0.08}, {v3(0.1*x, 0.34, 0.01), 0.066}, {v3(0.1*x, 0.11, 0.005), 0.062}, {v3(0.1*x, 0.095, 0.005), 0.068}}, 8, true, false)
    end
    emit(skinned(painted(join(table.unpack(pieces)), suit[1], suit[2])), {name="overalls", material=cloth})
  end

  -- The racer's number: a white roundel with a black 7 on it, on the chest's left, turned to face out of the chest.
  if O == "racer" then
    local out = v3(math.sin(rad(18)), 0, math.cos(rad(18)))
    local at = v3(0.075, 0.845, 0.116)
    local function place(x) return translate(rotate(x, {angle=18, axis=axis_y(), pivot=origin()}), at) end
    local badge = place(join(cylinder{radius=0.04, height=0.008, segments=28, axis="z"},
      translate(box{size=v3(0.04, 0.011, 0.005)}, v3(0, 0.016, 0.005)),
      translate(rotate(box{size=v3(0.011, 0.04, 0.005)}, {angle=-24, axis=axis_z(), pivot=origin()}), v3(0.006, -0.008, 0.005))))
    badge = painted(badge, WHITE, {
      {BLACK, function(c, n) return dot(c - at, out) > 0.0045 end},
    })
    emit(skinned(badge), {name="number", material=cloth})
  end

  -- The head and neck, the drivers' and the spectators' alike: an ordinary friendly face -- small dark eyes under
  -- brows, a modest nose, neat ears and a closed smile. A driver's is grown a little (HEAD_GROW, its helmet or hood
  -- with it); a spectator's is its natural size.
  do
    local grow = CASUAL and function(m) return m end or head_grow
    local head = ball(1, v3(0, 1.12, 0.005), v3(0.1, 0.106, 0.1), 32)
    local nose = ball(1, v3(0, 1.11, 0.1), v3(0.016, 0.022, 0.018), 14)
    local neck = translate(cylinder{radius=0.042, height=0.09, segments=SEG}, v3(0, 1.015, -0.004))
    local mouth = ball(1, v3(0, 1.074, 0.096), v3(0.026, 0.007, 0.007), 14)
    local parts = {smooth_normals(head, {angle=80}), smooth_normals(nose, {angle=80}), smooth_normals(neck, {angle=60}), smooth_normals(mouth, {angle=80})}
    local eyes = {}
    for side = -1, 1, 2 do
      parts[#parts + 1] = smooth_normals(ball(1, v3(0.1 * side, 1.115, -0.003), v3(0.016, 0.03, 0.022), 12), {angle=80})
      local e = v3(0.036 * side, 1.135, 0.091)
      eyes[#eyes + 1] = e
      parts[#parts + 1] = smooth_normals(ball(0.011, e, nil, 12), {angle=80})
      parts[#parts + 1] = translate(rotate(box{size=v3(0.03, 0.006, 0.008)}, {angle=-6 * side, axis=axis_z(), pivot=origin()}), v3(0.037 * side, 1.158, 0.093))
    end
    emit(skinned(painted(grow(join(table.unpack(parts))), SKIN, {
      {BLACK, function(c, n) return length(c - eyes[1]) < 0.013 or length(c - eyes[2]) < 0.013 end},
      {V.hair or BLACK, function(c, n) return c.y > 1.153 and c.y < 1.165 and c.z > 0.085 end},
      {LIP, function(c, n) return c.y > 1.066 and c.y < 1.082 and c.z > 0.092 and math.abs(c.x) < 0.028 end},
    }, not CASUAL and unhead or nil)), {name="skin", material=skin_m})
  end


  -- What each wears on its head, and anything more it has. All of it grows with the head.
  if O == "racer" then
    -- The helmet: gloss blue, a white stripe over its crown between two yellow ones, a white rim.
    local m = head_grow(shell())
    m = painted(m, BLUE, {
      {WHITE, function(c, n) return math.abs(c.x) < 0.016 and c.y > 1.12 end},
      {YELLOW, function(c, n) return math.abs(c.x) < 0.036 and c.y > 1.12 end},
      {WHITE, function(c, n) return c.y < 1.06 or (c.z > 0.05 and (c.x^2 + (c.y - 1.1)^2) < 0.108^2) end},
    }, unhead)
    emit(skinned(m), {name="helmet", material=helmet_m})

    -- The goggles, pushed up on the brow so the eyes can goggle: two big cyan lenses in black rims tipped up to the
    -- sky, a bridge, and the strap round the helmet.
    local TILT = 25
    local dir = v3(0, math.sin(rad(TILT)), math.cos(rad(TILT)))
    local function on_brow(x, at) return translate(rotate(x, {angle=-TILT, axis=axis_x(), pivot=origin()}), at) end
    local parts = {smooth_normals(translate(torus{major_radius=0.125, minor_radius=0.009, major_segments=48, minor_segments=8},
      v3(0, 1.215, -0.008)), {angle=70})}
    local glass = {}
    for side = -1, 1, 2 do
      local at = v3(0.045 * side, 1.222, 0.116)
      glass[#glass + 1] = at + dir * 0.015
      parts[#parts + 1] = smooth_normals(on_brow(cylinder{radius=0.035, height=0.03, segments=24, axis="z"}, at), {angle=40})
      parts[#parts + 1] = smooth_normals(on_brow(translate(ball(1, origin(), v3(0.029, 0.029, 0.008), 20), v3(0, 0, 0.015)), at), {angle=80})
    end
    parts[#parts + 1] = on_brow(box{size=v3(0.024, 0.014, 0.02)}, v3(0, 1.222, 0.118))
    emit(skinned(painted(head_grow(join(table.unpack(parts))), BLACK, {
      {CYAN, function(c, n)
        for _, g in ipairs(glass) do
          if length(c - g) < 0.03 and dot(c - g, dir) > 0.0015 then return true end
        end
        return false
      end},
    }, unhead)), {name="goggles", material=lens_m})

    -- The scarf: a knitted band round the neck in red and yellow, its two ends streaming out behind.
    local ring = smooth_normals(translate(torus{major_radius=0.058, minor_radius=0.022, major_segments=32, minor_segments=12},
      v3(0, 0.995, -0.004)), {angle=70})
    local a = tube({{v3(0.025, 0.99, -0.07), 0.02}, {v3(0.055, 0.94, -0.11), 0.018}, {v3(0.085, 0.88, -0.15), 0.015}}, 5, true, true)
    local b = tube({{v3(-0.015, 0.985, -0.072), 0.019}, {v3(-0.005, 0.93, -0.1), 0.017}, {v3(0.01, 0.865, -0.125), 0.014}}, 5, true, true)
    emit(skinned(painted(join(ring, a, b), YELLOW, {
      {RED, function(c, n) return (math.floor((c.y * 1.3 - c.z + c.x * 0.4) / 0.024) % 2) == 0 end},
    })), {name="scarf", material=cloth})

  elseif O == "chicken" then
    -- The hood: white, a big floppy red comb along its crown, a big orange beak over the brow, a red wattle under the
    -- chin.
    local parts = {shell(v3(0.14, 0.135, 0.146))}
    local comb = {{0, 1.305, 0.075, 0.04}, {0, 1.33, 0.025, 0.048}, {0, 1.32, -0.035, 0.044}, {0, 1.29, -0.085, 0.034}}
    for _, k in ipairs(comb) do parts[#parts + 1] = smooth_normals(ball(1, v3(k[1], k[2], k[3]), v3(0.02, k[4], k[4] * 0.8), 16), {angle=80}) end
    local beak = rotate(cone{radius=0.045, height=0.1, segments=20, axis="z"}, {angle=8, axis=axis_x(), pivot=origin()})
    parts[#parts + 1] = smooth_normals(translate(scale(beak, {factor=v3(1.25, 0.7, 1), pivot=origin()}), v3(0, 1.225, 0.168)), {angle=50})
    parts[#parts + 1] = smooth_normals(ball(1, v3(0, 1.025, 0.085), v3(0.022, 0.032, 0.016), 14), {angle=80})
    emit(skinned(painted(head_grow(join(table.unpack(parts))), FEATHER, {
      {ORANGE, function(c, n) return c.z > 0.13 and c.y > 1.19 and c.y < 1.27 and math.abs(c.x) < 0.065 end},
      {COMB, function(c, n) return c.y > 1.265 and math.abs(c.x) < 0.03 end},
      {COMB, function(c, n) return c.y < 1.06 and c.z > 0.06 and math.abs(c.x) < 0.03 end},
    }, unhead)), {name="hood", material=cloth})
    -- The tail: a fan of feathers sticking up out of the seat of the suit.
    local tail = {}
    for i = -2, 2 do
      local f = ball(1, origin(), v3(0.03, 0.09, 0.016), 14)
      f = rotate(f, {angle=-35, axis=axis_x(), pivot=origin()})
      f = rotate(f, {angle=i * 18, axis=axis_z(), pivot=origin()})
      tail[#tail + 1] = smooth_normals(translate(f, v3(i * 0.03, 0.72 + (2 - math.abs(i)) * 0.015, -0.16)), {angle=80})
    end
    emit(skinned(painted(join(table.unpack(tail)), FEATHER, {})), {name="tail", material=cloth})

  elseif O == "banana" then
    -- The hood: the peel closing over the head to a bent green-brown stalk.
    local stalk = tube({{v3(0, 1.27, -0.01), 0.035}, {v3(0.005, 1.34, -0.005), 0.028}, {v3(0.02, 1.41, 0.005), 0.022}, {v3(0.05, 1.46, 0.01), 0.019}}, 5, false, false)
    emit(skinned(painted(head_grow(join(shell(v3(0.138, 0.14, 0.145)), stalk)), PEEL, {
      {BRUISE, function(c, n) return c.y > 1.45 end},
      {STALK, function(c, n) return c.y > 1.29 end},
      {BRUISE, function(c, n) return math.abs(c.x) < 0.012 and c.z < 0 end},
    }, unhead)), {name="hood", material=cloth})

  elseif O == "viking" then
    -- The helmet: an iron bowl a size too big, perched up over the eyes, with a riveted band and a nose guard, and two
    -- big curved horns.
    local bowl = ball(1, v3(0, 1.19, -0.005), v3(0.122, 0.12, 0.127), 36)
    bowl = smooth_normals(subtract(bowl, translate(box{size=v3(0.4, 0.3, 0.4)}, v3(0, 1.04, 0))), {angle=50})
    local band = smooth_normals(translate(torus{major_radius=0.12, minor_radius=0.012, major_segments=48, minor_segments=8}, v3(0, 1.196, -0.005)), {angle=70})
    local guard = translate(box{size=v3(0.022, 0.07, 0.012)}, v3(0, 1.165, 0.126))
    emit(skinned(painted(head_grow(join(bowl, band, guard)), IRON, {
      {GOLD, function(c, n) return c.y > 1.183 and c.y < 1.21 end},
    }, unhead)), {name="helmet", material=metal_m})
    local horns = {}
    for side = -1, 1, 2 do
      local x = side
      horns[#horns + 1] = tube({{v3(0.1*x, 1.225, 0), 0.024}, {v3(0.172*x, 1.265, 0.01), 0.019}, {v3(0.217*x, 1.345, 0.025), 0.013},
        {v3(0.23*x, 1.435, 0.04), 0.006}}, 5, false, true)
    end
    emit(skinned(painted(head_grow(join(table.unpack(horns))), IVORY, {
      {FUR, function(c, n) return math.abs(c.x) < 0.125 end},
    }, unhead)), {name="horns", material=helmet_m})
    -- The beard: a big ginger bush under the grin, a handlebar moustache curling up over it, two braids down the front.
    local beard = {smooth_normals(ball(1, v3(0, 0.985, 0.072), v3(0.088, 0.065, 0.052), 24), {angle=80})}
    for side = -1, 1, 2 do
      local tache = rotate(ball(1, origin(), v3(0.042, 0.012, 0.014), 14), {angle=14 * side, axis=axis_z(), pivot=origin()})
      beard[#beard + 1] = smooth_normals(translate(tache, v3(0.036 * side, 1.083, 0.104)), {angle=80})
      beard[#beard + 1] = tube({{v3(0.035*side, 0.96, 0.1), 0.017}, {v3(0.04*side, 0.9, 0.118), 0.013}, {v3(0.04*side, 0.85, 0.122), 0.01}}, 4, true, true)
    end
    emit(skinned(painted(head_grow(join(table.unpack(beard))), GINGER, {
      {GOLD, function(c, n) return c.y < 0.865 end},
    }, unhead)), {name="beard", material=cloth})

  elseif O == "granny" then
    -- The hair: a grey cap of curls round the back of the head, a big bun on top, rollers along the front.
    local hair = {shell(v3(0.116, 0.118, 0.115))}
    hair[#hair + 1] = smooth_normals(ball(0.065, v3(0, 1.25, -0.07), nil, 20), {angle=80})
    -- Each roller's centre and axis, so the paint finds the rollers alone (pink and blue by turns).
    local rollers = {}
    for i = -2, 2 do
      local roller = cylinder{radius=0.019, height=0.05, segments=14, axis="x"}
      local a = rad(i * 22)
      local at = v3(math.sin(a) * 0.085, 1.222 - math.abs(i) * 0.01, 0.045 + math.cos(a) * 0.03)
      rollers[#rollers + 1] = {at, v3(math.cos(a), 0, math.sin(a)), i % 2 == 0}
      hair[#hair + 1] = smooth_normals(translate(rotate(roller, {angle=-i * 22, axis=axis_y(), pivot=origin()}), at), {angle=50})
    end
    local function on_roller(c, pink)
      for _, r in ipairs(rollers) do
        local d = c - r[1]
        local along = dot(d, r[2])
        if r[3] == pink and math.abs(along) < 0.0255 and length(d - r[2] * along) < 0.0205 then return true end
      end
      return false
    end
    emit(skinned(painted(head_grow(join(table.unpack(hair))), SILVER, {
      {PINK, function(c, n) return on_roller(c, true) end},
      {BABY, function(c, n) return on_roller(c, false) end},
    }, unhead)), {name="hair", material=cloth})
    -- The glasses: two big round rims in front of the eyes, a bridge, and arms back to the ears.
    local specs = {}
    for side = -1, 1, 2 do
      specs[#specs + 1] = smooth_normals(translate(torus{major_radius=0.037, minor_radius=0.0045, major_segments=28, minor_segments=6, axis="z"},
        v3(0.042 * side, 1.15, 0.134)), {angle=70})
      specs[#specs + 1] = translate(box{size=v3(0.005, 0.005, 0.13)}, v3(0.08 * side, 1.152, 0.07))
    end
    specs[#specs + 1] = translate(box{size=v3(0.012, 0.005, 0.005)}, v3(0, 1.152, 0.136))
    emit(skinned(painted(head_grow(join(table.unpack(specs))), GOLD, {})), {name="glasses", material=metal_m})

  elseif O == "chef" then
    -- The hat: a tall white toque, a band round the brow and a big puffed top. A curly black moustache, a red
    -- neckerchief knotted at the throat.
    local band = smooth_normals(translate(cylinder{radius=0.112, height=0.15, segments=32}, v3(0, 1.255, -0.008)), {angle=40})
    local puff = smooth_normals(ball(1, v3(0, 1.35, -0.012), v3(0.15, 0.085, 0.15), 32), {angle=80})
    emit(skinned(painted(head_grow(join(band, puff)), WHITE, {
      {SILVER, function(c, n) return c.y < 1.215 end},
    }, unhead)), {name="hat", material=cloth})
    local tache = {}
    for side = -1, 1, 2 do
      local t = rotate(ball(1, origin(), v3(0.04, 0.011, 0.013), 14), {angle=-16 * side, axis=axis_z(), pivot=origin()})
      tache[#tache + 1] = smooth_normals(translate(t, v3(0.033 * side, 1.087, 0.102)), {angle=80})
    end
    emit(skinned(painted(head_grow(join(table.unpack(tache))), BLACK, {})), {name="tache", material=cloth})
    local ring = smooth_normals(translate(torus{major_radius=0.058, minor_radius=0.02, major_segments=32, minor_segments=12},
      v3(0, 0.995, -0.004)), {angle=70})
    local knot = smooth_normals(ball(1, v3(0, 0.975, 0.07), v3(0.03, 0.026, 0.02), 14), {angle=80})
    emit(skinned(painted(join(ring, knot), RED, {})), {name="scarf", material=cloth})

  elseif O == "baby" then
    -- One kiss-curl of blond hair on top of the big bald head, and a dummy in the mouth.
    local curl = smooth_normals(translate(torus{major_radius=0.02, minor_radius=0.006, major_segments=20, minor_segments=8, axis="x"}, v3(0, 1.246, 0.035)), {angle=70})
    emit(skinned(painted(head_grow(curl), BLOND, {}, unhead)), {name="hair", material=cloth})
    local shield = smooth_normals(translate(scale(cylinder{radius=1, height=0.01, segments=24, axis="z"}, {factor=v3(0.034, 0.024, 1), pivot=origin()}), v3(0, 1.074, 0.104)), {angle=40})
    local ring = smooth_normals(translate(torus{major_radius=0.017, minor_radius=0.005, major_segments=20, minor_segments=6, axis="z"}, v3(0, 1.074, 0.114)), {angle=70})
    emit(skinned(painted(head_grow(join(shield, ring)), BABY, {
      {PINK, function(c, n) return c.z > 0.109 end},
    }, unhead)), {name="dummy", material=helmet_m})

  elseif O == "caveman" then
    -- A great shaggy mane of dark hair with a bone stuck through it, and a bushy beard to match.
    local mane = ball(1, v3(0, 1.165, -0.03), v3(0.14, 0.13, 0.14), 32)
    mane = smooth_normals(subtract(mane, translate(capsule{radius=0.1, height=0.12, segments=32, rings=6, axis="z"}, v3(0, 1.1, 0.13)),
      translate(box{size=v3(0.4, 0.12, 0.4)}, v3(0, 0.98, 0.05))), {angle=60})
    local tufts = {mane}
    for i = -2, 2 do
      tufts[#tufts + 1] = smooth_normals(ball(1, v3(i * 0.05, 1.262 - math.abs(i) * 0.02, 0.05 - math.abs(i) * 0.02), v3(0.035, 0.03, 0.035), 12), {angle=80})
    end
    emit(skinned(painted(head_grow(join(table.unpack(tufts))), DARK_HAIR, {}, unhead)), {name="hair", material=cloth})
    local bone = {translate(cylinder{radius=0.012, height=0.2, segments=10, axis="x"}, v3(0, 1.27, -0.03))}
    for side = -1, 1, 2 do
      for k = -1, 1, 2 do
        bone[#bone + 1] = ball(0.019, v3(0.1 * side, 1.27 + 0.012 * k, -0.03), nil, 10)
      end
    end
    emit(skinned(painted(head_grow(join(table.unpack(bone))), BONE, {}, unhead)), {name="bone", material=cloth})
    local beard = {smooth_normals(ball(1, v3(0, 0.99, 0.07), v3(0.095, 0.075, 0.055), 24), {angle=80})}
    for side = -1, 1, 2 do
      beard[#beard + 1] = smooth_normals(ball(1, v3(0.075 * side, 1.06, 0.07), v3(0.03, 0.05, 0.035), 14), {angle=80})
      local tache = rotate(ball(1, origin(), v3(0.042, 0.014, 0.015), 14), {angle=-10 * side, axis=axis_z(), pivot=origin()})
      beard[#beard + 1] = smooth_normals(translate(tache, v3(0.034 * side, 1.087, 0.104)), {angle=80})
    end
    emit(skinned(painted(head_grow(join(table.unpack(beard))), DARK_HAIR, {}, unhead)), {name="beard", material=cloth})

  elseif O == "hotsauce" then
    -- The hood is the bottle's shoulders, closing up over the head to its neck and a green screw cap, a drip of sauce
    -- running down the side.
    local neck = smooth_normals(translate(cylinder{radius=0.06, height=0.12, segments=28}, v3(0, 1.32, -0.008)), {angle=40})
    local lip = smooth_normals(translate(torus{major_radius=0.06, minor_radius=0.01, major_segments=28, minor_segments=8}, v3(0, 1.375, -0.008)), {angle=70})
    local cap = smooth_normals(translate(cylinder{radius=0.068, height=0.06, segments=28}, v3(0, 1.422, -0.008)), {angle=40})
    local drip = tube({{v3(0.11, 1.25, 0.03), 0.014}, {v3(0.128, 1.18, 0.04), 0.012}, {v3(0.13, 1.12, 0.045), 0.016}}, 4, true, true)
    emit(skinned(painted(head_grow(join(shell(), neck, lip, cap, drip)), SAUCE, {
      {GREEN, function(c, n) return c.y > 1.391 end},
    }, unhead)), {name="hood", material=helmet_m})
  end

  -- A spectator's hair, or a cap over it: the hair a cap of its own colour over the crown and down the back, short
  -- over the ears; a cap a crown and a peck, the hair showing below it at the back.
  if CASUAL then
    local hair = ball(1, v3(0, 1.13, -0.01), v3(0.108, 0.104, 0.108), 32)
    hair = subtract(hair, translate(box{size=v3(0.3, 0.12, 0.2)}, v3(0, 1.08, 0.1)), translate(box{size=v3(0.3, 0.1, 0.3)}, v3(0, 1.0, 0)))
    local pieces = {smooth_normals(hair, {angle=60})}  -- (the hair alone: the cap is its own part)
    if V.hat == "flatcap" then
      -- A flat cap: a low tweed crown, its peak short over the brow.
      local crown = ball(1, v3(0, 1.185, 0.008), v3(0.116, 0.05, 0.122), 28)
      crown = subtract(crown, translate(box{size=v3(0.3, 0.1, 0.3)}, v3(0, 1.135, 0)))
      local peak = translate(scale(cylinder{radius=1, height=0.01, segments=20}, {factor=v3(0.09, 1, 0.05), pivot=origin()}), v3(0, 1.185, 0.105))
      emit(skinned(painted(join(smooth_normals(crown, {angle=60}), peak), V.cap or GREY, {})), {name="cap", material=cloth})
    end
    if V.hat == "cap" then
      local crown = ball(1, v3(0, 1.165, -0.005), v3(0.112, 0.085, 0.114), 28)
      crown = subtract(crown, translate(box{size=v3(0.3, 0.1, 0.3)}, v3(0, 1.11, 0)))
      local peak = translate(scale(cylinder{radius=1, height=0.008, segments=20}, {factor=v3(0.085, 1, 0.07), pivot=origin()}), v3(0, 1.17, 0.11))
      emit(skinned(painted(join(smooth_normals(crown, {angle=60}), peak), V.cap or RED, {})), {name="cap", material=cloth})
    end
    emit(skinned(painted(pieces[1], V.hair or BLACK, {})), {name="hair", material=cloth})
  end

  -- What a spectator holds in the right hand, gripped in its fist and bound to the forearm (so it goes where the hand
  -- goes): a phone held up to film, a cup of tea, a flag on a pole or a homemade placard on a stick. A pole runs on
  -- out of the fist the way the forearm points: hanging down at rest, held up high as the arm is raised.
  if CASUAL and V.prop then
    local hand = v3(-0.266, 0.47, 0.03)
    local c1, c2 = V.propColour or RED, V.propColour2 or WHITE
    local m, rules, base
    if V.prop == "phone" then
      m = translate(box{size=v3(0.012, 0.13, 0.065)}, hand + v3(0.03, 0.0, 0.045))
      base, rules = BLACK, {{CYAN, function(c, n) return n.x > 0.9 end}}
    elseif V.prop == "cup" then
      m = join(smooth_normals(translate(cylinder{radius=0.034, height=0.085, segments=16}, hand + v3(0, 0.01, 0.07)), {angle=40}),
        translate(box{size=v3(0.012, 0.04, 0.03)}, hand + v3(0.04, 0.01, 0.07)))
      base, rules = c1, {{v3(0.35, 0.18, 0.06), function(c, n) return n.y > 0.9 and c.y > hand.y + 0.05 end}}
    else
      local isFlag = V.prop == "flag"
      local pole = translate(cylinder{radius=0.009, height=0.62, segments=8}, hand + v3(0, -0.29, 0.02))
      local fh, fw = isFlag and 0.17 or 0.3, isFlag and 0.26 or 0.42
      local low = hand.y - 0.57
      local POLE = v3(0.45, 0.32, 0.18)
      if isFlag then
        -- A flag flying out from the pole: two colours, a band across the field.
        local cloth = translate(box{size=v3(0.004, fh, fw)}, v3(hand.x, low + fh / 2, hand.z + 0.02 + fw / 2))
        m = join(pole, cloth)
        base = POLE
        rules = {{c2, function(c, n) return c.y < low + fh + 0.001 and c.z > hand.z + 0.03 and c.y > low + fh * 0.35 and c.y < low + fh * 0.65 end},
          {c1, function(c, n) return c.y < low + fh + 0.001 and c.z > hand.z + 0.03 end}}
      else
        -- A homemade placard: a white board square to the road, in front of the pole, its painted words three bold
        -- bands across its front.
        local board = translate(box{size=v3(fw, fh, 0.016)}, v3(hand.x, low + fh / 2, hand.z + 0.04))
        m = join(pole, board)
        base = WHITE
        rules = {{POLE, function(c, n) return c.z < hand.z + 0.031 and math.abs(c.x - hand.x) < 0.012 end},
          {c1, function(c, n) return math.abs(n.z) > 0.9 and ((c.y - low) % 0.1) > 0.03 and ((c.y - low) % 0.1) < 0.07 and math.abs(c.x - hand.x) < fw / 2 - 0.03 end}}
      end
    end
    m = painted(m, base, rules)
    local held = bind(m, skel, {method="envelope", envelopes=envs, regions={region{joint="RightForeArm", min=v3(-1, -1, -1), max=v3(1, 2, 1), weight=1}}})
    emit(held, {name="prop", material=cloth})
  end

  -- The hands, big cartoon mitts: leather gauntlets for the racer and the viking; white wing-tips for the chicken, white cartoon gloves
  -- for the banana, pink rubber washing-up gloves for the granny.
  do
    local parts = {}
    for side = -1, 1, 2 do
      local x = side
      parts[#parts + 1] = smooth_normals(ball(1, v3(0.266 * x, 0.468, 0.024), v3(0.044, 0.06, 0.054), 20), {angle=80})
      parts[#parts + 1] = tube({{v3(0.25 * x, 0.5, 0.056), 0.02}, {v3(0.242 * x, 0.472, 0.088), 0.016}}, 3, false, true)
      parts[#parts + 1] = smooth_normals(translate(cone{radius=0.045, radius_top=0.056, height=0.05, segments=SEG}, v3(0.26 * x, 0.515, 0.017)), {angle=50})
    end
    local hand = ({chicken = FEATHER, banana = WHITE, granny = PINK, viking = FUR, casual = SKIN, chef = WHITE, baby = SKIN, caveman = SKIN, hotsauce = YELLOW})[O] or LEATHER
    local cuff = ({chicken = FEATHER, banana = WHITE, granny = YELLOW, viking = FUR, casual = SKIN, chef = WHITE, baby = SKIN, caveman = SKIN, hotsauce = YELLOW})[O] or BLACK
    local trim = ({chicken = FEATHER, banana = BLACK, granny = YELLOW, viking = LEATHER, casual = V.short and SKIN or (V.shirt or BLUE),
      chef = WHITE, baby = SKIN, caveman = SKIN, hotsauce = SAUCE})[O] or WHITE
    emit(skinned(painted(join(table.unpack(parts)), hand, {
      {trim, function(c, n) return c.y > 0.528 end},
      {cuff, function(c, n) return c.y > 0.505 end},
    })), {name="gloves", material=boot_m})
  end

  -- The feet, clown-big: boots for the racer and the viking (fur-topped), big orange chicken feet, banana-brown shoes, and
  -- fluffy pink slippers for the granny.
  do
    local parts = {}
    for side = -1, 1, 2 do
      local x = 0.1 * side
      local foot = ball(1, v3(x, 0.064, 0.062), v3(0.068, 0.048, 0.132), 24)
      local ankle = translate(cylinder{radius=0.064, height=0.1, segments=SEG}, v3(x, 0.1, -0.005))
      local sole = box{size=v3(0.138, 0.024, 0.262)}
      sole = translate(bevel(sole, {edges=sharp_edges(sole, {angle=30}), width=0.009, segments=2}), v3(x, 0.012, 0.058))
      parts[#parts + 1] = smooth_normals(foot, {angle=80})
      parts[#parts + 1] = smooth_normals(ankle, {angle=50})
      parts[#parts + 1] = smooth_normals(sole, {angle=40})
      if O == "chicken" then
        -- Three long toes splayed out in front.
        for t = -1, 1 do
          parts[#parts + 1] = tube({{v3(x, 0.03, 0.12), 0.017}, {v3(x + t * 0.05, 0.02, 0.215), 0.012}}, 3, false, true)
        end
      elseif O == "granny" then
        parts[#parts + 1] = smooth_normals(ball(1, v3(x, 0.078, 0.13), v3(0.05, 0.038, 0.044), 16), {angle=80})
      end
    end
    local rules = ({
      casual = {V.shoes or WHITE, {
        {WHITE, function(c, n) return c.y < 0.027 end},
      }},
      racer = {BLACK, {
        {GREY, function(c, n) return c.y < 0.027 end},
        {RED, function(c, n) return c.z > 0.13 end},
        {WHITE, function(c, n) return n.y > 0.35 and c.z > 0.03 and c.z < 0.118 and math.abs(math.abs(c.x) - 0.1) < 0.022 and
          (math.floor(c.z / 0.016) % 2 == 0) end},
      }},
      chicken = {ORANGE, {}},
      banana = {BRUISE, {
        {BLACK, function(c, n) return c.y < 0.027 end},
      }},
      viking = {LEATHER, {
        {FUR, function(c, n) return c.y > 0.1 end},
        {BLACK, function(c, n) return c.y < 0.027 end},
      }},
      granny = {PINK, {
        {WHITE, function(c, n) return c.y > 0.1 or (c.z > 0.08 and c.y > 0.045) end},
        {BABY, function(c, n) return c.y < 0.027 end},
      }},
      -- Black kitchen clogs; knitted white booties; bare feet, bound with fur; black boots under the bottle.
      chef = {BLACK, {
        {GREY, function(c, n) return c.y < 0.027 end},
      }},
      baby = {WHITE, {
        {BABY, function(c, n) return c.y > 0.1 and c.y < 0.125 end},
      }},
      caveman = {SKIN, {
        {FUR, function(c, n) return c.y > 0.1 end},
        {TIGHTS, function(c, n) return c.y < 0.027 end},
      }},
      hotsauce = {BLACK, {
        {GREY, function(c, n) return c.y < 0.027 end},
      }},
    })[O]
    emit(skinned(painted(join(table.unpack(parts)), rules[1], rules[2])), {name="boots", material=boot_m})
  end
  end -- (V.body)

  -- The clips. Each pose is how far each joint swings from the rest pose, degrees.
  if MERGED and #held_parts > 0 then
    local one = merge({parts=held_parts, mode="all"})
    for k, q in ipairs(one) do emit_part(bound(q.mesh), {name=k == 1 and "fan" or ("fan" .. k), material=q.material}) end
  end

  local function seated(extra)
    local pose = {
      LeftUpLeg = {forward=88}, RightUpLeg = {forward=88},
      LeftLeg = {forward=-10}, RightLeg = {forward=-10},
      LeftArm = {forward=55, left=8}, RightArm = {forward=55, left=-8},
      LeftForeArm = {forward=25}, RightForeArm = {forward=25},
    }
    for k, v in pairs(extra or {}) do pose[k] = v end
    return pose
  end

  emit_action(action{name="sit", skeleton=skel, loop=true, airborne={{0, 1.2}}, keys={
    {time=0, pose=seated()},
    {time=0.6, pose=seated({Spine={forward=P.bob}, Head={forward=-P.bob}})},
    {time=1.2, pose=seated()},
  }})
  emit_action(action{name="lean_left", skeleton=skel, loop=true, airborne={{0, 1}}, keys={
    {time=0, pose=seated({Spine={left=P.lean}, Head={left=-P.lean*0.4}, LeftArm={forward=40, left=4}, RightArm={forward=70, left=-8}})},
    {time=1, pose=seated({Spine={left=P.lean}, Head={left=-P.lean*0.4}, LeftArm={forward=40, left=4}, RightArm={forward=70, left=-8}})},
  }})
  emit_action(action{name="lean_right", skeleton=skel, loop=true, airborne={{0, 1}}, keys={
    {time=0, pose=seated({Spine={left=-P.lean}, Head={left=P.lean*0.4}, LeftArm={forward=70, left=8}, RightArm={forward=40, left=-4}})},
    {time=1, pose=seated({Spine={left=-P.lean}, Head={left=P.lean*0.4}, LeftArm={forward=70, left=8}, RightArm={forward=40, left=-4}})},
  }})
  emit_action(action{name="tuck", skeleton=skel, loop=true, airborne={{0, 1}}, keys={
    {time=0, pose=seated({Spine={forward=38}, Head={forward=-25}, LeftArm={forward=35, left=8}, RightArm={forward=35, left=-8}, LeftForeArm={forward=60}, RightForeArm={forward=60}})},
    {time=1, pose=seated({Spine={forward=38}, Head={forward=-25}, LeftArm={forward=35, left=8}, RightArm={forward=35, left=-8}, LeftForeArm={forward=60}, RightForeArm={forward=60}})},
  }})
  emit_action(action{name="brace", skeleton=skel, loop=false, airborne={{0, 0.25}}, keys={
    {time=0, pose=seated()},
    {time=0.25, pose=seated({Spine={forward=-12}, LeftArm={forward=150, left=25}, RightArm={forward=150, left=-25}, LeftForeArm={forward=10}, RightForeArm={forward=10}, Head={forward=10}})},
  }})
  -- Idling in the seat while the kart is built (the garage, driver-pose.ts): each starts and ends sitting, so the game
  -- can drop one in between stretches of plain sitting. Looking round the workshop; a big stretch; fingers drummed on
  -- a knee, head nodding along; leaning over the side for a look at the wheel.
  emit_action(action{name="idle_look", skeleton=skel, loop=true, airborne={{0, 4}}, keys={
    {time=0, pose=seated()},
    {time=0.7, pose=seated({Head={twist=40, forward=-4}, Spine={twist=10}})},
    {time=1.6, pose=seated({Head={twist=40, forward=-4}, Spine={twist=10}})},
    {time=2.4, pose=seated({Head={twist=-38, forward=6}, Spine={twist=-8}})},
    {time=3.3, pose=seated({Head={twist=-38, forward=6}, Spine={twist=-8}})},
    {time=4, pose=seated()},
  }})
  emit_action(action{name="idle_stretch", skeleton=skel, loop=true, airborne={{0, 3.2}}, keys={
    {time=0, pose=seated()},
    {time=0.8, pose=seated({Spine={forward=-14}, Head={forward=-18}, LeftArm={forward=165, left=12}, RightArm={forward=165, left=-12}, LeftForeArm={forward=8}, RightForeArm={forward=8}})},
    {time=1.8, pose=seated({Spine={forward=-16, left=6}, Head={forward=-20}, LeftArm={forward=170, left=16}, RightArm={forward=170, left=-16}, LeftForeArm={forward=4}, RightForeArm={forward=4}})},
    {time=2.5, pose=seated({Spine={forward=4}})},
    {time=3.2, pose=seated()},
  }})
  local function drum(up)
    return seated({RightArm={forward=40, left=-6}, RightForeArm={forward=55 - up * 18}, Head={forward=up * 6, left=4}})
  end
  emit_action(action{name="idle_drum", skeleton=skel, loop=true, airborne={{0, 2.4}}, keys={
    {time=0, pose=seated()}, {time=0.3, pose=drum(0)}, {time=0.45, pose=drum(1)}, {time=0.6, pose=drum(0)}, {time=0.75, pose=drum(1)},
    {time=0.9, pose=drum(0)}, {time=1.05, pose=drum(1)}, {time=1.2, pose=drum(0)}, {time=1.35, pose=drum(1)}, {time=1.5, pose=drum(0)},
    {time=1.65, pose=drum(1)}, {time=1.8, pose=drum(0)}, {time=2.4, pose=seated()},
  }})
  emit_action(action{name="idle_check", skeleton=skel, loop=true, airborne={{0, 3.6}}, keys={
    {time=0, pose=seated()},
    {time=0.9, pose=seated({Spine={left=22, forward=14}, Head={left=10, forward=22}, LeftArm={forward=20, left=30}, LeftForeArm={forward=30}})},
    {time=2.4, pose=seated({Spine={left=24, forward=16}, Head={left=12, forward=26, twist=10}, LeftArm={forward=20, left=30}, LeftForeArm={forward=30}})},
    {time=3.6, pose=seated()},
  }})
  emit_action(action{name="cheer", skeleton=skel, loop=true, airborne={{0, 0.7}}, keys={
    {time=0, pose=seated({LeftArm={forward=10, left=160}, RightArm={forward=10, left=-160}, LeftForeArm={forward=20}, RightForeArm={forward=20}})},
    {time=0.35, pose=seated({Spine={forward=-8}, LeftArm={forward=10, left=140}, RightArm={forward=10, left=-140}, LeftForeArm={forward=50}, RightForeArm={forward=50}, Head={forward=-15}})},
    {time=0.7, pose=seated({LeftArm={forward=10, left=160}, RightArm={forward=10, left=-160}, LeftForeArm={forward=20}, RightForeArm={forward=20}})},
  }})

  -- On foot: the same character as the teammate who pushes the kart off the line (src/game/systems/pusher.ts), its
  -- elbows and knees bending. The game lowers the whole figure by each clip's GROUND (pusher.ts' CROUCH, RUN_DIP,
  -- STUMBLE_DIP must match), so the road is at y = GROUND here: each planted foot is solved onto it.
  --   ready   -- crouched behind the kart, hands on its back, bouncing on the toes
  --   push    -- sprinting bent over behind it, arms out shoving, legs driving (one stride a second at speed 1,
  --              a planted foot sweeping back RUN_SWEEP metres in RUN_STANCE of it -- pusher.ts' STRIDE, their ratio)
  --   stagger -- let go: arms windmilling, legs stumbling on
  --   flat    -- face down on the road, arms flung out ahead, feet kicking feebly
  -- Angles are world angles, degrees forward of straight down (a limb) or of straight up (the torso), turned into
  -- the joints' own: leaning the hips forward swings the legs (and, through the spine, the arms) back as far.
  local THIGH, SHIN = 0.26, 0.27
  local function lean_of(lean) return {forward=lean} end
  -- The hip joint, for a lean: it hangs 0.02 under the hips' pivot (HIPS).
  local function hip_at(lean, ground)
    local r = math.rad(lean)
    return HIPS - 0.02 * math.cos(r) - ground, -0.02 * math.sin(r)
  end
  -- How far the sole's lowest point (heel or toe, rigid with the shin) is under the ankle, for a shin angle.
  local function sole_drop(shin)
    local s = math.rad(shin)
    local heel = 0.07 * math.cos(s) + 0.07 * math.sin(s)
    local toe = 0.07 * math.cos(s) - 0.19 * math.sin(s)
    return math.max(heel, toe)
  end
  -- Two-bone IK: the thigh's and shin's world angles that put the ankle at (az, ay) from a hip at (hz, hy) (y up),
  -- knee in front. Out of reach, the leg straight towards it.
  local function solve(hy, hz, ay, az)
    local dy, dz = hy - ay, az - hz
    local d = math.min(math.sqrt(dy * dy + dz * dz), (THIGH + SHIN) * 0.999)
    local a = math.deg(math.atan(dz, dy))
    local function acos(x) return math.acos(math.max(-1, math.min(1, x))) end
    local alpha = math.deg(acos((THIGH * THIGH + d * d - SHIN * SHIN) / (2 * THIGH * d)))
    local beta = math.deg(acos((SHIN * SHIN + d * d - THIGH * THIGH) / (2 * SHIN * d)))
    return a + alpha, a - beta
  end
  -- A foot at (z forward of the hip, lift above the road): its leg's world angles, the sole on the road at lift 0.
  local function foot(lean, ground, z, lift)
    local hy, hz = hip_at(lean, ground)
    local th, sh = solve(hy, hz, 0.07 + lift, z)
    for _ = 1, 3 do th, sh = solve(hy, hz, sole_drop(sh) + lift, z) end
    return {th, sh}
  end
  -- A pose: hips lean, spine and head on top; each leg {thigh, shin} and each arm {upper, fore} in world angles.
  local function on_foot(lean, spine, head, l, r, la, ra, spread)
    spread = spread or 6
    local back = lean + spine
    return {
      Hips=lean_of(lean), Spine={forward=spine}, Head={forward=head},
      LeftUpLeg={forward=l[1] + lean}, LeftLeg={forward=l[2] - l[1]},
      RightUpLeg={forward=r[1] + lean}, RightLeg={forward=r[2] - r[1]},
      LeftArm={forward=la[1] + back, left=spread}, LeftForeArm={forward=la[2]},
      RightArm={forward=ra[1] + back, left=-spread}, RightForeArm={forward=ra[2]},
    }
  end

  -- Ready: crouched, one foot forward, hands on the kart's back; a bounce in the knees -- the feet stay put, so the
  -- crouch deepens a touch by leaning in.
  local READY_GROUND = 0.12
  local function ready(k)
    local lean = 34 + k * 6
    return on_foot(lean, 12, -42 - k * 4,
      foot(lean, READY_GROUND, 0.16, 0), foot(lean, READY_GROUND, -0.24, 0),
      {70 - k * 4, 18 + k * 8}, {70 - k * 4, 18 + k * 8})
  end
  emit_action(action{name="ready", skeleton=skel, loop=true, airborne={{0, 0.5}}, keys={
    {time=0, pose=ready(0)}, {time=0.25, pose=ready(1)}, {time=0.5, pose=ready(0)},
  }})

  -- Push: a run cycle, 8 keys a stride. Each foot is planted for RUN_STANCE of it, sweeping back from +RUN_REACH to
  -- RUN_REACH - RUN_SWEEP under the hips; then it swings through: the heel kicked up behind, the knee driven forward.
  local RUN_GROUND, RUN_LEAN, RUN_STANCE, RUN_REACH, RUN_SWEEP = 0.08, 40, 0.35, 0.24, 0.52
  local function run_foot(u)
    u = u % 1
    if u < RUN_STANCE then return foot(RUN_LEAN, RUN_GROUND, RUN_REACH - RUN_SWEEP * u / RUN_STANCE, 0) end
    local w = (u - RUN_STANCE) / (1 - RUN_STANCE)
    local ease = w * w * (3 - 2 * w)
    local z = RUN_REACH - RUN_SWEEP + RUN_SWEEP * ease - 0.14 * math.sin(math.pi * w)
    return foot(RUN_LEAN, RUN_GROUND, z, 0.3 * math.sin(math.pi * w) ^ 0.8)
  end
  local push_keys = {}
  for i = 0, 8 do
    local t = i / 8
    -- The shove pumps with each step: the arms give a little as a foot lands, then drive.
    local pump = math.sin(4 * math.pi * t)
    push_keys[#push_keys + 1] = {time=t, pose=on_foot(RUN_LEAN + pump * 2, 14, -46, run_foot(t), run_foot(t + 0.5),
      {74 + pump * 4, 14 - pump * 8}, {74 + pump * 4, 14 - pump * 8})}
  end
  emit_action(action{name="push", skeleton=skel, loop=true, airborne={{0, 1}}, keys=push_keys})

  -- Stagger: upright, quick stumbling steps (four keys a step), arms windmilling.
  local STUMBLE_GROUND = 0.06
  local function stumble_foot(u)
    u = u % 1
    if u < 0.4 then return foot(10, STUMBLE_GROUND, 0.2 - 0.4 * u / 0.4, 0) end
    local w = (u - 0.4) / 0.6
    return foot(10, STUMBLE_GROUND, -0.2 + 0.4 * w, 0.18 * math.sin(math.pi * w))
  end
  local MILL = {{-20, 150}, {150, 30}, {80, 10}, {150, -60}}
  local stagger_keys = {}
  for i = 1, 5 do
    local t = (i - 1) * 0.15
    local u = (i - 1) / 4
    local l, r = MILL[(i - 1) % 4 + 1], MILL[(i + 1) % 4 + 1]
    local pose = on_foot(10, -6, -10, stumble_foot(u), stumble_foot(u + 0.5), {l[1], 35}, {r[1], 50})
    pose.LeftArm.left = 40 + l[2] * 0.15
    pose.RightArm.left = -40 - r[2] * 0.15
    stagger_keys[i] = {time=t, pose=pose}
  end
  emit_action(action{name="stagger", skeleton=skel, loop=true, airborne={{0, 0.6}}, keys=stagger_keys})

  local function flat(kick)
    -- Lying, the legs point straight back (-86); kicking, the heels come up behind. Arms flung out ahead.
    return on_foot(86, 0, -35, {-86, -86 - kick}, {-84, -114 + kick}, {80, 10}, {80, 10}, 25)
  end
  emit_action(action{name="flat", skeleton=skel, loop=true, airborne={{0, 1.4}}, keys={
    {time=0, pose=flat(0)},
    {time=0.7, pose=flat(30)},
    {time=1.4, pose=flat(0)},
  }})

  -- The spectators (src/game/systems/crowd.ts) are this figure too, standing behind the walls, feet on the ground,
  -- moving as people in a crowd do -- a little:
  --   fan_idle -- arms down, a slow shift of weight from foot to foot
  --   fan_wave -- one hand raised, waving from the elbow
  --   fan_clap -- clapping, hands meeting in front of the chest
  local function stand(sway, la, ra, spread_l, spread_r, lean)
    lean = lean or 0
    -- Standing: both legs straight down to the road (a hair apart, front and back), feet flat.
    local pose = on_foot(lean, -lean * 0.5, -3, {2, 2}, {-2, -2}, la, ra)
    pose.LeftArm.left = spread_l
    pose.RightArm.left = -spread_r
    pose.Spine.left = sway
    pose.Head = {forward=-3, left=-sway * 0.5}
    return pose
  end
  emit_action(action{name="fan_idle", skeleton=skel, loop=true, airborne={{0, 3}}, keys={
    {time=0, pose=stand(1.5, {3, 8}, {2, 10}, 5, 5)},
    {time=1.5, pose=stand(-1.5, {2, 10}, {3, 8}, 5, 5)},
    {time=3, pose=stand(1.5, {3, 8}, {2, 10}, 5, 5)},
  }})
  emit_action(action{name="fan_wave", skeleton=skel, loop=true, airborne={{0, 1.4}}, keys={
    {time=0, pose=stand(1, {3, 10}, {20, 95}, 5, 115)},
    {time=0.35, pose=stand(0.5, {3, 10}, {20, 120}, 5, 125)},
    {time=0.7, pose=stand(-0.5, {3, 10}, {20, 95}, 5, 115)},
    {time=1.05, pose=stand(0, {3, 10}, {20, 120}, 5, 125)},
    {time=1.4, pose=stand(1, {3, 10}, {20, 95}, 5, 115)},
  }})
  emit_action(action{name="fan_clap", skeleton=skel, loop=true, airborne={{0, 0.5}}, keys={
    {time=0, pose=stand(0, {28, 95}, {28, 95}, -6, -6, 2)},
    {time=0.25, pose=stand(0, {32, 80}, {32, 80}, 4, 4, 3)},
    {time=0.5, pose=stand(0, {28, 95}, {28, 95}, -6, -6, 2)},
  }})

  -- The village fete's crowd (src/game/systems/crowd.ts picks among them by what is going on):
  --   waiting:   fan_chat (turned to a neighbour, a hand talking), fan_sip (a drink to the lips), fan_hold (a flag or
  --              placard held up), fan_idle
  --   passing:   fan_point, fan_film (a phone held up in both hands), fan_flagwave (a flag swung overhead), fan_wave
  --   a stunt:   fan_cheer (both arms up, pumping), fan_clap
  --   a crash:   fan_flinch (ducking, hands on the head)
  --   finish:    fan_jump (arms flung up -- the game bobs the figure off the ground)
  --   seated (a pensioner in a folding chair, the game lowering the figure onto it): fan_sit, fan_sit_clap, fan_sit_sip
  local function talk(t, a)
    local pose = stand(1, {6, 10}, {12 + a * 8, 55 + a * 25}, 5, 8)
    pose.Head = {forward=-2, left=18 + t * 6}
    return pose
  end
  emit_action(action{name="fan_chat", skeleton=skel, loop=true, airborne={{0, 2.4}}, keys={
    {time=0, pose=talk(0, 0)}, {time=0.6, pose=talk(1, 1)}, {time=1.2, pose=talk(0, 0.3)}, {time=1.8, pose=talk(-1, 0.9)}, {time=2.4, pose=talk(0, 0)},
  }})
  local function sip(up)
    local pose = stand(0.5, {4, 10}, {25 + up * 10, 70 + up * 75}, 5, 14)
    pose.Head = {forward=-3 - up * 12, left=0}
    return pose
  end
  emit_action(action{name="fan_sip", skeleton=skel, loop=true, airborne={{0, 4}}, keys={
    {time=0, pose=sip(0)}, {time=1.2, pose=sip(0)}, {time=1.8, pose=sip(1)}, {time=2.6, pose=sip(1)}, {time=3.2, pose=sip(0)}, {time=4, pose=sip(0)},
  }})
  emit_action(action{name="fan_hold", skeleton=skel, loop=true, airborne={{0, 2}}, keys={
    {time=0, pose=stand(1, {4, 10}, {65, 112}, 5, 10)},
    {time=1, pose=stand(-1, {4, 10}, {70, 106}, 5, 12)},
    {time=2, pose=stand(1, {4, 10}, {65, 112}, 5, 10)},
  }})
  emit_action(action{name="fan_point", skeleton=skel, loop=true, airborne={{0, 1.6}}, keys={
    {time=0, pose=stand(0, {6, 12}, {82, 6}, 5, 10, 4)},
    {time=0.8, pose=stand(1, {6, 12}, {78, 10}, 5, 14, 5)},
    {time=1.6, pose=stand(0, {6, 12}, {82, 6}, 5, 10, 4)},
  }})
  emit_action(action{name="fan_film", skeleton=skel, loop=true, airborne={{0, 2}}, keys={
    {time=0, pose=stand(0, {45, 95}, {50, 100}, -14, -10, 2)},
    {time=1, pose=stand(1, {47, 92}, {52, 97}, -14, -10, 2)},
    {time=2, pose=stand(0, {45, 95}, {50, 100}, -14, -10, 2)},
  }})
  emit_action(action{name="fan_flagwave", skeleton=skel, loop=true, airborne={{0, 0.8}}, keys={
    {time=0, pose=stand(2, {4, 12}, {20, 40}, 5, 135, 0)},
    {time=0.4, pose=stand(-2, {4, 12}, {20, 10}, 5, 172, 0)},
    {time=0.8, pose=stand(2, {4, 12}, {20, 40}, 5, 135, 0)},
  }})
  emit_action(action{name="fan_cheer", skeleton=skel, loop=true, airborne={{0, 0.6}}, keys={
    {time=0, pose=stand(0, {15, 50}, {15, 50}, 140, 140, -4)},
    {time=0.3, pose=stand(0, {8, 15}, {8, 15}, 168, 168, -6)},
    {time=0.6, pose=stand(0, {15, 50}, {15, 50}, 140, 140, -4)},
  }})
  local function duck(k)
    return stand(0, {140 - k * 10, 135}, {140 - k * 10, 135}, 45, 45, 18 + k * 8)
  end
  emit_action(action{name="fan_flinch", skeleton=skel, loop=true, airborne={{0, 1}}, keys={
    {time=0, pose=duck(0)}, {time=0.5, pose=duck(1)}, {time=1, pose=duck(0)},
  }})
  emit_action(action{name="fan_jump", skeleton=skel, loop=true, airborne={{0, 0.5}}, keys={
    {time=0, pose=stand(0, {15, 60}, {15, 60}, 135, 135, 8)},
    {time=0.25, pose=stand(0, {5, 10}, {5, 10}, 168, 168, -4)},
    {time=0.5, pose=stand(0, {15, 60}, {15, 60}, 135, 135, 8)},
  }})
  -- Seated: thighs out level, shins straight down to the ground (the game lowers the figure onto its chair).
  local function sit(la, ra, spread_l, spread_r, head)
    local pose = on_foot(0, -5, head or -3, {86, 4}, {84, -4}, la, ra)
    pose.LeftArm.left = spread_l
    pose.RightArm.left = -spread_r
    return pose
  end
  emit_action(action{name="fan_sit", skeleton=skel, loop=true, airborne={{0, 3}}, keys={
    {time=0, pose=sit({30, 55}, {30, 55}, 6, 6)}, {time=1.5, pose=sit({32, 50}, {28, 58}, 6, 6, 4)}, {time=3, pose=sit({30, 55}, {30, 55}, 6, 6)},
  }})
  emit_action(action{name="fan_sit_clap", skeleton=skel, loop=true, airborne={{0, 0.6}}, keys={
    {time=0, pose=sit({40, 95}, {40, 95}, -8, -8)}, {time=0.3, pose=sit({44, 80}, {44, 80}, 4, 4)}, {time=0.6, pose=sit({40, 95}, {40, 95}, -8, -8)},
  }})
  local function sit_sip(up)
    return sit({30, 55}, {28 + up * 10, 70 + up * 75}, 6, 14, -3 - up * 12)
  end
  emit_action(action{name="fan_sit_sip", skeleton=skel, loop=true, airborne={{0, 4}}, keys={
    {time=0, pose=sit_sip(0)}, {time=1.2, pose=sit_sip(0)}, {time=1.8, pose=sit_sip(1)}, {time=2.6, pose=sit_sip(1)}, {time=3.2, pose=sit_sip(0)}, {time=4, pose=sit_sip(0)},
  }})
end

return M
