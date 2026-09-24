# Fusion Compiler — router, step 3. Power grid.
# Run from this folder:
#   fc_shell -f 03_power.tcl | tee logs/power.log
# Next: 04_placement.tcl
#
# Order is fixed: logical connection, M1 rails, ring, then mesh.
# Signal routing stops at M6, so the straps use M7 and M8.
#
# mark_as_follow_pin: cell VDD and VSS pins connect only to rails with this set.
# The mesh compile must name the via rule down to those rails. A later
# compile_pg does not via shapes that were committed earlier, and it would
# add a second copy of the rails if the rail strategy were compiled again.

set DESIGN_NAME "router_top"
set DLIB        "./${DESIGN_NAME}.dlib"
set VDD_NET     "VDD"
set VSS_NET     "VSS"
set PG_VERTICAL_LAYER   "M7"
set PG_HORIZONTAL_LAYER "M8"
set PG_STRAP_WIDTH      1.0
set PG_STRAP_PITCH      15

file mkdir reports
open_lib $DLIB
open_block ${DESIGN_NAME}_floorplan

create_net -power $VDD_NET
create_net -ground $VSS_NET
connect_pg_net -automatic

create_pg_std_cell_conn_pattern rail_pat -layers {M1} -mark_as_follow_pin true
set_pg_strategy rail_strat -core \
  -pattern "{name: rail_pat} {nets: {$VDD_NET $VSS_NET}}"
compile_pg -strategies rail_strat

create_pg_ring_pattern ring_pat \
  -horizontal_layer $PG_HORIZONTAL_LAYER -horizontal_width $PG_STRAP_WIDTH -horizontal_spacing 1.0 \
  -vertical_layer   $PG_VERTICAL_LAYER   -vertical_width   $PG_STRAP_WIDTH -vertical_spacing 1.0
set_pg_strategy ring_strat -core \
  -pattern "{name: ring_pat} {nets: {$VDD_NET $VSS_NET}} {offset: {2 2}}"

# existing std_conn is the M1 rail pattern already compiled.
set_pg_strategy_via_rule mesh_via_rule -via_rule { \
  {{{strategies: mesh_strat} {layers: M7}} \
   {{existing: std_conn} {layers: M1}} \
   {via_master: default}} \
  {{intersection: undefined} {via_master: NIL}} \
}

create_pg_mesh_pattern mesh_pat -layers [list \
  "{vertical_layer: $PG_VERTICAL_LAYER} {width: $PG_STRAP_WIDTH} {spacing: interleaving} {pitch: $PG_STRAP_PITCH}" \
  "{horizontal_layer: $PG_HORIZONTAL_LAYER} {width: $PG_STRAP_WIDTH} {spacing: interleaving} {pitch: $PG_STRAP_PITCH}"]
set_pg_strategy mesh_strat -core \
  -pattern "{name: mesh_pat} {nets: {$VDD_NET $VSS_NET}}" \
  -extension {{stop: outermost_ring}}

compile_pg -strategies ring_strat
compile_pg -strategies mesh_strat -via_rule mesh_via_rule

redirect -file reports/power_connectivity.rpt { catch { check_pg_connectivity } }
redirect -file reports/power_drc.rpt { catch { check_pg_drc } }
redirect -file reports/power_vias.rpt { catch { check_pg_missing_vias } }

save_block -as ${DESIGN_NAME}_power
save_lib -all
echo "Power done. Next is 04_placement.tcl"
