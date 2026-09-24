# Fusion Compiler — router, step 2. Floorplan.
# Run from this folder:
#   fc_shell -f 02_floorplan.tcl | tee logs/floorplan.log
# Next: 03_power.tcl
#
# The router has no SRAM, so the die size comes from utilization.
# 0.55 leaves routing tracks. Raise it only after congestion is clean.
# core_offset is the empty ring for the power straps: left bottom right top.
# -flip_first_row true shares VDD and VSS between neighboring rows.
# -site must match the SAED row site.
#
# Other die controls, if a later spec needs them. Use only one initialize_floorplan.
#   -control_type die -side_length {W H}     fixed microns
#   -control_type aspect_ratio -side_ratio 1 width/height, size still floats
#   -control_type boundary -boundary {...}   L-shape or other polygon

set DESIGN_NAME  "router_top"
set DLIB         "./${DESIGN_NAME}.dlib"
set CORE_UTIL    0.55
set CORE_OFFSET  {8 8 8 8}
set SITE_NAME    "unit"
set PIN_LAYERS   {M4 M5}

file mkdir reports
open_lib $DLIB
open_block ${DESIGN_NAME}_compile

initialize_floorplan \
  -core_utilization $CORE_UTIL \
  -core_offset $CORE_OFFSET \
  -site $SITE_NAME \
  -flip_first_row true

# sides: 1 left, 2 top, 3 right, 4 bottom.
set_block_pin_constraints -self -allowed_layers $PIN_LAYERS -sides {1 2 3 4}
place_pins -self

# Only router_clock is named. The other ports were placed by the command above.
# The clock enters from the left so the tree has one start side.
set_individual_pin_constraints -ports [get_ports router_clock] -sides 1 -allowed_layers {M5}
place_pins -self

redirect -file reports/floorplan_utilization.rpt { report_utilization }
redirect -file reports/floorplan_legality.rpt { catch { check_legality -verbose } }
redirect -file reports/floorplan_physical.rpt { catch { check_design -checks pre_placement_stage } }
echo "Unplaced ports:"
sizeof_collection [get_ports -quiet -filter "physical_status==unplaced"]

save_block -as ${DESIGN_NAME}_floorplan
save_lib -all
echo "Floorplan done. Next is 03_power.tcl"
