-- The driver in the granny outfit: the driver library's (_driver.lua), its one skeleton and its clips.
local P = params{
  bob = {default=2.5, min=0, max=8, doc="How much the driver bobs in the seat, degrees"},
  lean = {default=22, min=5, max=40, doc="How far the driver leans into a turn, degrees"},
  segments = {default=20, min=10, max=32, integer=true, doc="Segments round each limb"},
}
include("_driver.lua").build(P, "granny")
