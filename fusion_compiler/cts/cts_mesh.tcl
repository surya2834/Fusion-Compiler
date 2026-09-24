# Pattern: clock mesh, fed by an H-tree.
# When to use: skew must be tighter than a normal tree, and the top
# metals can be spent on the clock. Many drivers share one grid, so
# variation on a single buffer matters less.
#
# -grids {{h_start h_end h_step} {v_start v_end v_step}}
#   distances are microns. A smaller step lowers skew and blocks more tracks.
# -types {stripe stripe} lets route_clock_straps connect to both directions.
# -boxes {8 8} is the mesh-driver grid.
# -short_outputs ties every driver output onto the same mesh net.
#
# Run after placement, block already open:
#   source fusion_compiler/cts/cts_mesh.tcl

source fusion_compiler/cts/cts_spec.tcl

set MESH_NET    "clk_mesh"
set MESH_LAYERS {M7 M8}
set MESH_WIDTH  1.0
set MESH_BOXES  {8 8}

create_net $MESH_NET

create_clock_straps -nets [get_nets $MESH_NET] \
  -layers $MESH_LAYERS \
  -widths [list $MESH_WIDTH $MESH_WIDTH] \
  -types {stripe stripe} \
  -grids {{20 800 80} {20 800 80}}

create_clock_drivers -loads [get_nets $MESH_NET] \
  -boxes $MESH_BOXES \
  -lib_cells [get_lib_cells $CLK_BUF] \
  -short_outputs \
  -output_net_name $MESH_NET

synthesize_multisource_global_clock_trees \
  -nets [get_nets $MESH_NET] \
  -lib_cells [get_lib_cells $CLK_BUF] \
  -use_zroute_for_pin_connections

legalize_placement

create_clock_drivers -loads [get_nets $CLOCK_NAME] \
  -boxes {4 4} \
  -lib_cells [get_lib_cells $CLK_BUF]

route_clock_straps -nets [get_nets $MESH_NET]

synthesize_multisource_clock_taps

set_propagated_clock [get_clocks $CLOCK_NAME]
clock_opt -from build_clock -to route_clock

redirect -file reports/cts_mesh_skew.rpt { report_clock_timing -type skew }
redirect -file reports/cts_mesh_qor.rpt { report_clock_qor }

save_block -as ${DESIGN_NAME}_cts_mesh
echo "Mesh plus H-tree done."
