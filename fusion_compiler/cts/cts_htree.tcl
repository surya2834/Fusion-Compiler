# Pattern: H-tree only. No clock mesh.
# When to use: a large block that needs matched global delay,
# without giving the top metals to a full mesh.
#
# What it builds:
#   one H-shaped global tree
#   a grid of tap drivers at the ends of that H
#   a small local tree from each tap to the nearby flops
#
# -topology htree_only is the only global shape this command accepts.
# Fusion Compiler has no X-tree option.
# -tap_boxes {columns rows} is the tap grid. {4 4} is 16 taps.
#   Use more taps when the skew report is still high.
# -htree_layers is one horizontal layer and one vertical layer.
#
# Run after placement:
#   fc_shell -f fusion_compiler/cts/cts_htree.tcl

set DESIGN_NAME "router_top"
set DLIB        "./${DESIGN_NAME}.dlib"
open_lib $DLIB
open_block ${DESIGN_NAME}_place

source [file join [file dirname [info script]] cts_spec.tcl]

set TAP_COLUMNS  4
set TAP_ROWS     4
set HTREE_LAYERS {M7 M8}

set cts_cells [get_lib_cells -quiet -filter "valid_purposes=~*cts*"]
set_lib_cell_purpose -exclude cts $cts_cells
set_lib_cell_purpose -include cts [get_lib_cells $CLK_BUF]
set_lib_cell_purpose -include cts [get_lib_cells $CLK_INV]

set_regular_multisource_clock_tree_options \
  -clock $CLOCK_NAME \
  -topology htree_only \
  -tap_boxes [list $TAP_COLUMNS $TAP_ROWS] \
  -tap_lib_cells [get_lib_cells $CLK_BUF] \
  -htree_lib_cells [get_lib_cells $CLK_INV] \
  -htree_layers $HTREE_LAYERS \
  -htree_routing_rule clk_ndr

# Both stages by default. -to tap_synthesis stops before the H is drawn.
synthesize_regular_multisource_clock_trees

set_lib_cell_purpose -include cts $cts_cells

set tap_count [expr {$TAP_COLUMNS * $TAP_ROWS}]
set_multisource_clock_tap_options \
  -clock $CLOCK_NAME \
  -driver_objects [get_cells -hierarchical -filter "is_clock_network_cell==true"] \
  -num_taps $tap_count

synthesize_multisource_clock_taps

set_propagated_clock [get_clocks $CLOCK_NAME]
clock_opt -from build_clock -to route_clock

redirect -file reports/cts_htree_skew.rpt { report_clock_timing -type skew }
redirect -file reports/cts_htree_qor.rpt { report_clock_qor }
report_regular_multisource_clock_tree_options

save_block -as ${DESIGN_NAME}_cts_htree
echo "H-tree done."
