# Pattern: standard balanced clock tree.
# When to use: a normal block. Run this pattern first.
# The tool inserts buffers and inverters and balances the flops.
# It does not build an H, a mesh, or a spine.
#
# Run from fc_shell after placement:
#   fc_shell -f fusion_compiler/cts/cts_standard_tree.tcl

set DESIGN_NAME "router_top"
set DLIB        "./${DESIGN_NAME}.dlib"
open_lib $DLIB
open_block ${DESIGN_NAME}_place

source [file join [file dirname [info script]] cts_spec.tcl]

set_propagated_clock [get_clocks $CLOCK_NAME]

# build_clock to route_clock : grow the tree and route the clock nets.
clock_opt -from build_clock -to route_clock

redirect -file reports/cts_tree_skew.rpt { report_clock_timing -type skew }
redirect -file reports/cts_tree_qor.rpt { report_clock_qor }

# final_opto : size data cells and add hold delay. Use after skew looks right.
clock_opt -from final_opto

redirect -file reports/cts_tree_setup.rpt {
  report_timing -delay_type max -max_paths 20 -slack_lesser_than 0
}
redirect -file reports/cts_tree_hold.rpt {
  report_timing -delay_type min -max_paths 20 -slack_lesser_than 0
}

save_block -as ${DESIGN_NAME}_cts_tree
echo "Standard tree done."
