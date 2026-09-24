# Fusion Compiler — step 5, clock tree.
# Shell:  fc_shell -f 05_cts.tcl | tee logs/cts.log
# Next:    06_route.tcl
#
# clock_opt ranges used in the reference flow:
#   -from build_clock -to route_clock   build the tree and route the clock nets
#   -from final_opto                     size data cells and add hold delay
# Setup is read on func_slow. Hold is read on func_fast.

set DESIGN_NAME     "msrv32_top"
set NLIB            "./nlib/${DESIGN_NAME}.nlib"
set TARGET_SKEW_NS  0.050

file mkdir reports
open_lib $NLIB
open_block ${DESIGN_NAME}_place

set_qor_strategy -stage pnr -metric {timing}

# Propagated clock uses the tree delay. Ideal clock is still zero delay.
set_propagated_clock [all_clocks]

# How far apart clock sinks may be, in nanoseconds.
# 0.050 is a normal first target.
# Tighten it when hold fails because one sink is much later than another.
set_clock_tree_options -target_skew $TARGET_SKEW_NS

# More hold effort inserts small delay cells on short paths in final_opto.
set_app_options -name clock_opt.hold.effort -value high

# CCD moves clock and data at the same time.
# Purpose: a few setup paths that useful skew can fix.
# Leave it false on the first run. It can create new hold violations.
# set_app_options -name clock_opt.flow.enable_ccd -value true

# Build and route the clock.
clock_opt -from build_clock -to route_clock

# Data-path optimization with that real clock, including hold.
clock_opt -from final_opto

redirect -file reports/cts_clock_qor.rpt { report_clock_qor }
redirect -file reports/cts_skew.rpt { report_clock_timing -type skew }
redirect -file reports/cts_qor.rpt { report_qor -summary }
redirect -file reports/cts_constraints.rpt { report_constraint -all_violators }
current_scenario func_slow
redirect -file reports/cts_setup.rpt {
  report_timing -delay_type max -max_paths 20 -slack_lesser_than 0 -path_type full_clock
}
current_scenario func_fast
redirect -file reports/cts_hold.rpt {
  report_timing -delay_type min -max_paths 20 -slack_lesser_than 0 -path_type full_clock
}

save_block -as ${DESIGN_NAME}_cts
save_lib -all
echo "CTS done. Skew target is $TARGET_SKEW_NS ns."
echo "Next is 06_route.tcl"
