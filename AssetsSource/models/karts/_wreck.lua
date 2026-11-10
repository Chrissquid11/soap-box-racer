-- The wreck of a whole-kart body: what is left on the kart when the bodywork is knocked off mid-run (the game swaps the
-- body's part for this one, `<name>_wreck`, and flings the rest off as debris in its colours). Authored from the same
-- pieces the body is made of, so it is the same model, broken:
--   the base kept -- every piece that sits low (its top no higher than KEEP_LOW of the body's height up from its
--   bottom): the floor, the undercarriage, the seat, the lower sills;
--   a torn-off remnant of the rest -- of the higher pieces rising from the base (their foot in it: never one left
--   floating), the smaller ones on the left side, every other one (by their order), left standing as jagged stumps;
--   everything on the right and every big upper shell gone.
-- Used as `include("_wreck.lua").emit(name, out)` from a script's part(), `out` its pieces as merge() takes them. It says
-- how much of the body the wreck keeps (`warn` when under ENOUGH of its faces, or nothing high is kept: a body made
-- of a few big meshes, which wants authoring in more pieces for its breakup to read).
local KEEP_LOW = 0.4
local SMALL = 0.35
local ENOUGH = 0.15

local function all(m) return faces_where(m, function(_) return true end) end

local M = {}
function M.emit(name, out)
  local boxes, faces = {}, {}
  local lo, hi, total = math.huge, -math.huge, 0
  local wide = 0
  for i, q in ipairs(out) do
    local f = all(q.mesh)
    faces[i] = set_count(f)
    total = total + faces[i]
    local b = selection_bounds(q.mesh, f)
    boxes[i] = b
    lo = math.min(lo, b.min.y)
    hi = math.max(hi, b.max.y)
    wide = math.max(wide, b.size.x, b.size.z)
  end
  local height = hi - lo
  local cut = lo + height * KEEP_LOW
  local kept, keptFaces, stumps, upper = {}, 0, 0, 0
  for i, q in ipairs(out) do
    local b = boxes[i]
    local keep = false
    if b.max.y <= cut + height * 0.05 then
      keep = true
    else
      upper = upper + 1
      local small = math.max(b.size.x, b.size.y, b.size.z) <= wide * SMALL
      if small and b.min.y <= cut and b.center.x < -0.05 and upper % 2 == 0 then
        keep = true
        stumps = stumps + 1
      end
    end
    if keep then
      kept[#kept + 1] = q
      keptFaces = keptFaces + faces[i]
    end
  end
  -- Nothing low at all (a body that is one shell): the single lowest piece, so something of it stays on.
  if #kept == 0 then
    local best = 1
    for i = 2, #out do if boxes[i].center.y < boxes[best].center.y then best = i end end
    kept[1] = out[best]
    keptFaces = faces[best]
  end
  local share = keptFaces / math.max(1, total)
  if share < ENOUGH or #kept < 3 then
    warn(string.format("%s_wreck: keeps %d of %d pieces (%.0f%% of its faces) -- too few pieces to break up convincingly", name, #kept, #out, share * 100))
  elseif stumps == 0 then
    warn(string.format("%s_wreck: keeps %d of %d pieces (%.0f%%) but no torn stumps -- its upper body is a few big meshes", name, #kept, #out, share * 100))
  end
  local merged = merge({parts=kept, mode="compatible"})
  emit(merged[1].mesh, {name=name .. "_wreck", material=merged[1].material})
end
return M
