# Fusion Compiler — step 4, placement.
# Shell:  fc_shell -f 04_placement.tcl | tee logs/placement.log
# Next:    05_cts.tcl
#
# place_opt stages, in order:
#   initial_place  coarse location from timing. Ideal clock. Scan chains pulled together.
#   initial_drc    remove buffer trees, fix high fanout and max transition.
#   initial_opto   timing, area, congestion, leakage.
#   final_place    small moves for timing and routability.
#   final_opto     another optimization pass.
#   legalize       every cell on a legal site.
# A plain place_opt runs all of them. That is what this script does.
# Hold is not the goal yet. The clock is still ideal.

set DESIGN_NAME "msrv32_top"
set NLIB        "./nlib/${DESIGN_NAME}.nlib"
set SCAN_DEF    ""

file mkdir reports
open_lib $NLIB
open_block ${DESIGN_NAME}_power

# PnR recipe. Use this after synthesis, before CTS.
# -metric timing is the first goal. Add total_power or leakage_power later.
set_qor_strategy -stage pnr -metric {timing}

# Missing scan DEF would stop placement. true lets the run continue.
# Remove this once SCAN_DEF points at a real file.
set_app_options -name place.coarse.continue_on_missing_scandef -value true

# 0.65 means a local area cannot be packed solid.
# Drop to 0.55 when place_congestion.rpt shows overflow.
set_app_options -name place.coarse.max_density -value 0.65

# true: placement keeps clock-gating cells near the flops they enable.
# Use this when the design has integrated clock gates.
# set_app_options -name place_opt.flow.clock_aware_placement -value true

# true: build a temporary clock during placement, then throw it away.
# Use this when setup after CTS is much worse than setup after placement.
# Leave it false on the first run. CTS builds the real tree in the next file.
# set_app_options -name place_opt.flow.trial_clock_tree -value true

if {$SCAN_DEF ne ""} {
  read_def $SCAN_DEF
}

# Full placement. One command runs every stage listed at the top.
place_opt

# Partial runs. Comment place_opt above if you use one of these.
# place_opt -to initial_place
#   Purpose: see locations before optimization changes the netlist.
# place_opt -from initial_drc
#   Purpose: placement already exists and you only want DRC and timing repair.
# place_opt -from final_place -to final_opto
#   Purpose: a small timing cleanup, not a new placement from scratch.

redirect -file reports/place_legality.rpt { check_legality -verbose }
redirect -file reports/place_congestion.rpt { report_congestion }
redirect -file reports/place_qor.rpt { report_qor -summary }
redirect -file reports/place_constraints.rpt { report_constraint -all_violators }
current_scenario func_slow
redirect -file reports/place_setup.rpt {
  report_timing -delay_type max -max_paths 20 -slack_lesser_than 0 -path_type full_clock
}

save_block -as ${DESIGN_NAME}_place
save_lib -all
echo "Placement done. Congestion overflow should be near 0."
echo "Next is 05_cts.tcl"
