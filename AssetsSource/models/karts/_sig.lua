-- A body's signature piece: the one part of it that comes off as the joke of its breakup (the snail's shell, the
-- toilet's cistern, the can's pull tab). The game draws it as `<name>_sig` -- the pieces alone, centred on their own
-- middle, so it can roll or tumble about it -- and sends it off where it sat on the kart (`impacts.ts`' SIGNATURES
-- holds that middle and the size, which `box` reports).
-- Used from a script's part(), with `out` its pieces as merge() takes them and `is_sig(i)` true for the signature's:
--   local rest = include("_sig.lua").split(name, out, function(i) return pieces[i][4] end)
--   include("_wreck.lua").emit(name, rest)
-- so what flies off is gone from the wreck too.
local M = {}

-- `<name>_sig` emitted from the pieces `is_sig` picks, centred; answers the rest (all of them when none is picked),
-- and the signature's bounds in the body's space (nil when none).
function M.split(name, out, is_sig)
  local sig, rest = {}, {}
  for i, q in ipairs(out) do
    if is_sig(i) then sig[#sig + 1] = q else rest[#rest + 1] = q end
  end
  if #sig == 0 then
    warn(name .. "_sig: no pieces marked")
    return out, nil
  end
  local s = merge({parts=sig, mode="compatible"})
  local b = bbox(s[1].mesh)
  emit(translate(s[1].mesh, v3(0, 0, 0) - b.center), {name=name .. "_sig", material=s[1].material})
  return rest, b
end

-- Its bounds said as a diagnostic, for the game's table: centre and size, metres, in the body's space.
function M.box(name, b)
  if b then warn(string.format("%s_sig box: at {%.3f, %.3f, %.3f} size {%.3f, %.3f, %.3f}", name, b.center.x, b.center.y, b.center.z, b.size.x, b.size.y, b.size.z)) end
end

return M
