# Fusion Compiler — router, step 5. Clock tree.
# Run from this folder:
#   fc_shell -f 05_cts.tcl | tee logs/cts.log
# Next: 06_route.tcl
#
# The SDC clock is router_clock. After placement that clock still has zero delay.
# This file builds a normal balanced tree.
# Setup is read on func_slow. Hold is read on func_fast.
#
# Other shapes are optional and replace this file. Do not run two of them.
#   cts/cts_standard_tree.tcl   same tree, plus the clock wire rule in cts_spec.tcl
#   cts/cts_htree.tcl           H-tree into a tap grid
#   cts/cts_mesh.tcl            mesh on M7/M8, fed by an H-tree
#   cts/cts_spine.tcl           trunks plus stripes
# There is no X-tree command.

set DESIGN_NAME     "router_top"
set DLIB            "./${DESIGN_NAME}.dlib"
set TARGET_SKEW_NS  0.050

file mkdir reports
open_lib $DLIB
open_block ${DESIGN_NAME}_place

set_qor_strategy -stage pnr -metric {timing}

set_propagated_clock [all_clocks]
set_clock_tree_options -target_skew $TARGET_SKEW_NS
set_app_options -name clock_opt.hold.effort -value high

clock_opt -from build_clock -to route_clock
clock_opt -from final_opto

redirect -file reports/cts_clock_qor.rpt { catch { report_clock_qor } }
redirect -file reports/cts_skew.rpt { catch { report_clock_timing -type skew } }
redirect -file reports/cts_qor.rpt { report_qor -summary }
redirect -file reports/cts_constraints.rpt { catch { report_constraint -all_violators } }
current_scenario func_slow
redirect -file reports/cts_setup.rpt {
  catch { report_timing -delay_type max -max_paths 20 -slack_lesser_than 0 -path_type full_clock }
}
current_scenario func_fast
redirect -file reports/cts_hold.rpt {
  catch { report_timing -delay_type min -max_paths 20 -slack_lesser_than 0 -path_type full_clock }
}

save_block -as ${DESIGN_NAME}_cts
save_lib -all
echo "CTS done. Skew target is $TARGET_SKEW_NS ns."
echo "Next is 06_route.tcl"
