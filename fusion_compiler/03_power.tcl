# Fusion Compiler — step 3, power grid.
# Shell:  fc_shell -f 03_power.tcl | tee logs/power.log
# Next:    04_placement.tcl
#
# Order is fixed: logical connection, M1 rails, ring, then mesh.
# A mesh drawn before the rails does not power the standard cells.

set DESIGN_NAME "msrv32_top"
set NLIB        "./nlib/${DESIGN_NAME}.nlib"
set VDD_NET     "VDD"
set VSS_NET     "VSS"
set PG_VERTICAL_LAYER   "M7"
set PG_HORIZONTAL_LAYER "M8"
set PG_STRAP_WIDTH      2.0
set PG_STRAP_PITCH      20

file mkdir reports
open_lib $NLIB
open_block ${DESIGN_NAME}_floorplan

# Purpose: every cell supply pin gets a net name before shapes are drawn.
create_net -power $VDD_NET
create_net -ground $VSS_NET
connect_pg_net -automatic

# M1 follow-pin rails. Purpose: the cells sit on this metal.
# Always run this for a standard-cell block.
create_pg_std_cell_conn_pattern rail_pat -layers {M1}
set_pg_strategy rail_strat -core \
  -pattern "{name: rail_pat} {nets: {$VDD_NET $VSS_NET}}"
compile_pg -strategies rail_strat

# Ring. Purpose: bring power in from the pads or the parent straps,
# in the gap left by core_offset.
# horizontal_width / vertical_width : strap thickness.
# horizontal_spacing / vertical_spacing : gap between VDD and VSS.
create_pg_ring_pattern ring_pat \
  -horizontal_layer $PG_HORIZONTAL_LAYER -horizontal_width $PG_STRAP_WIDTH -horizontal_spacing 1.0 \
  -vertical_layer   $PG_VERTICAL_LAYER   -vertical_width   $PG_STRAP_WIDTH -vertical_spacing 1.0
set_pg_strategy ring_strat -core \
  -pattern "{name: ring_pat} {nets: {$VDD_NET $VSS_NET}} {offset: {2 2}}"

# Mesh. Purpose: keep IR drop down inside the core.
# pitch : distance from one VDD strap to the next VDD strap.
# Start at 20. A smaller pitch drops less voltage and blocks more signal tracks.
# interleaving : VDD and VSS alternate, so two straps do not short.
create_pg_mesh_pattern mesh_pat -layers [list \
  "{vertical_layer: $PG_VERTICAL_LAYER} {width: $PG_STRAP_WIDTH} {spacing: interleaving} {pitch: $PG_STRAP_PITCH}" \
  "{horizontal_layer: $PG_HORIZONTAL_LAYER} {width: $PG_STRAP_WIDTH} {spacing: interleaving} {pitch: $PG_STRAP_PITCH}"]
set_pg_strategy mesh_strat -core \
  -pattern "{name: mesh_pat} {nets: {$VDD_NET $VSS_NET}}" \
  -extension {{stop: outermost_ring}}

# stop outermost_ring : mesh ends at the ring instead of running off the die.
compile_pg -strategies {ring_strat mesh_strat}

# check_pg_connectivity : an open rail. LVS and IR drop fail later.
# check_pg_drc          : the straps themselves violate width or spacing.
# check_pg_missing_vias : a layer change has no via, so the strap is open.
redirect -file reports/power_connectivity.rpt { check_pg_connectivity }
redirect -file reports/power_drc.rpt { check_pg_drc }
redirect -file reports/power_vias.rpt { check_pg_missing_vias }

save_block -as ${DESIGN_NAME}_power
save_lib -all
echo "Power done. Next is 04_placement.tcl"
