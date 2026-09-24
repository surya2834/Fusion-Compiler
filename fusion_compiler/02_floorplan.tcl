# Fusion Compiler — step 2, floorplan.
# Shell:  fc_shell -f 02_floorplan.tcl | tee logs/floorplan.log
# Next:    03_power.tcl
#
# Only ONE initialize_floorplan may run. Option A is active.
# Comment A and uncomment B, C, or D when that case matches the spec.

set DESIGN_NAME  "msrv32_top"
set NLIB         "./nlib/${DESIGN_NAME}.nlib"
set CORE_UTIL    0.55
set CORE_OFFSET  {10 10 10 10}
set SITE_NAME    "unit"
set DIE_WIDTH    800
set DIE_HEIGHT   800
set PIN_LAYERS   {M4 M5}
set TAP_CELL     ""
set TAP_DISTANCE 40
set ENDCAP_LEFT  ""
set ENDCAP_RIGHT ""

file mkdir reports
open_lib $NLIB
open_block ${DESIGN_NAME}_compile

# OPTION A — utilization decides the die size.
# Purpose: first floorplan, when the chip size is not fixed yet.
# 0.55 leaves routing tracks. Raise it toward 0.65 only after congestion is clean.
# core_offset is the empty ring between the die edge and the cell rows.
# Four numbers: left, bottom, right, top.
# Use about 10 when a power ring will sit in that gap.
# Use about 2 when pins sit on the core edge and there is no ring.
# -flip_first_row true shares VDD and VSS between neighboring rows.
# -site picks the row height. It must match the NDM site.
initialize_floorplan \
  -core_utilization $CORE_UTIL \
  -core_offset $CORE_OFFSET \
  -site $SITE_NAME \
  -flip_first_row true

# OPTION B — width and height are already specified, in microns.
# Purpose: the block must fit a fixed opening in the parent chip.
# Utilization becomes an output. Read it in the utilization report.
# initialize_floorplan \
#   -control_type die \
#   -side_length [list $DIE_WIDTH $DIE_HEIGHT] \
#   -core_offset $CORE_OFFSET \
#   -site $SITE_NAME \
#   -flip_first_row true

# OPTION C — aspect ratio is fixed, exact microns can move.
# side_ratio 1.0 is square. 2.0 is twice as wide as it is tall.
# Purpose: a wide or tall slot, when the spec does not give microns.
# initialize_floorplan \
#   -control_type aspect_ratio \
#   -side_ratio 1.0 \
#   -core_utilization $CORE_UTIL \
#   -core_offset $CORE_OFFSET \
#   -site $SITE_NAME \
#   -flip_first_row true

# OPTION D — outline is not a rectangle.
# Purpose: an L-shape around a large macro.
# Points are die corners in order, in microns.
# initialize_floorplan \
#   -control_type boundary \
#   -boundary {{0 0} {900 0} {900 400} {400 400} {400 900} {0 900}} \
#   -core_offset {10 10 10 10} \
#   -site $SITE_NAME \
#   -flip_first_row true

# MACROS. Skip if there is no SRAM.
# origin is the lower-left corner. fixed means placement cannot move it.
# R0 is no rotation. R180 or MY turns pins toward a channel.
# set_attribute [get_cells u_sram] origin {120 80}
# set_attribute [get_cells u_sram] orientation R0
# set_attribute [get_cells u_sram] physical_status fixed

# Tool places the macro, then you freeze it.
# Purpose: you do not know a good coordinate yet.
# create_placement -floorplan
# set_fixed_objects [get_cells -hierarchical -filter "is_hard_macro==true"]

# Halo around the macro, microns: left bottom right top.
# hard: cells cannot sit there. Purpose: a routing channel at the macro pins.
# soft: cells are discouraged. Purpose: the core is too tight for a hard halo.
# create_keepout_margin -type hard -outer {10 10 10 10} [get_cells u_sram]

# PINS. sides: 1 left, 2 top, 3 right, 4 bottom.
# Purpose of the first command: no side has been assigned yet.
set_block_pin_constraints -self -allowed_layers $PIN_LAYERS -sides {1 2 3 4}
place_pins -self

# Purpose: clock or a bus must face the block it connects to.
# set_individual_pin_constraints -ports [get_ports clk] -sides 1 -allowed_layers {M5}
# set_individual_pin_constraints -ports [get_ports data_in*] -sides 1 -allowed_layers {M4}
# set_individual_pin_constraints -ports [get_ports data_out*] -sides 3 -allowed_layers {M4}
# place_pins -self

# BLOCKAGES. Leave commented on the first floorplan.
# hard: empty channel between macros.
# create_placement_blockage -name channel -type hard -boundary {{200 200} {260 500}}
# partial: thin out a region that report_congestion later shows as full.
# 40 means about 40 percent of the sites stay empty.
# create_placement_blockage -name spread_alu -type partial -blocked_percentage 40 \
#   -boundary {{100 100} {300 300}}
# bound: pull a timing group into one box after a path is late because cells are far apart.
# create_bound -name alu_bound -boundary {{100 100} {280 280}} [get_cells u_alu/*]

# TAPS AND ENDCAPS. Foundry rules. DRC fails later without them.
# stagger offsets the tap on alternate rows so the ties are not one vertical wall.
if {$TAP_CELL ne ""} {
  create_tap_cells -lib_cell $TAP_CELL -distance $TAP_DISTANCE -pattern stagger
}
if {$ENDCAP_LEFT ne "" && $ENDCAP_RIGHT ne ""} {
  create_boundary_cells -left_boundary_cell $ENDCAP_LEFT -right_boundary_cell $ENDCAP_RIGHT
}

redirect -file reports/floorplan_utilization.rpt { report_utilization }
redirect -file reports/floorplan_legality.rpt { check_legality -verbose }
redirect -file reports/floorplan_physical.rpt { check_design -checks physical_constraints }
echo "Unplaced ports:"
sizeof_collection [get_ports -quiet -filter "physical_status==unplaced"]

save_block -as ${DESIGN_NAME}_floorplan
save_lib -all
echo "Floorplan done. Next is 03_power.tcl"
