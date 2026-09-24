# Fusion Compiler — step 6, signal routing.
# Shell:  fc_shell -f 06_route.tcl | tee logs/route.log
# Next:    07_finish.tcl
#
# Clock nets and power straps are already wired.
# This step wires the data nets, then repairs timing on those real wires.

set DESIGN_NAME    "msrv32_top"
set NLIB           "./nlib/${DESIGN_NAME}.nlib"
set ANTENNA_DIODES ""

file mkdir reports
open_lib $NLIB
open_block ${DESIGN_NAME}_cts

set_qor_strategy -stage pnr -metric {timing}

# true: detail routing breaks long antenna metal or inserts a diode.
# Purpose: a long metal into a gate fails the foundry antenna rule.
set_app_options -name route.detail.antenna -value true

# Diode cell used when a jumper is not enough.
# Set the name only when that cell exists in the NDM.
if {$ANTENNA_DIODES ne ""} {
  set_app_options -name route.detail.diode_libcell_names -value $ANTENNA_DIODES
}

# Global route, then track assignment, then detail route.
# max_detail_route_iterations : how many times to retry a short or an open.
# 5 is a normal first value. Raise it when route_initial.rpt still has a few opens.
route_auto -max_detail_route_iterations 5
redirect -file reports/route_initial.rpt { check_routes }

# Moves cells and rewires after the real wire delay is known.
# Purpose: setup that got worse because the estimated wire was too short.
route_opt

# Incremental detail route. Uncomment when route_drc.rpt still shows opens or shorts.
# Purpose: fix remaining geometry without a full new global route.
# route_detail -incremental true
# route_opt

redirect -file reports/route_drc.rpt { check_routes }
redirect -file reports/route_antenna.rpt { check_routes -antenna }
redirect -file reports/route_legality.rpt { check_legality -verbose }
redirect -file reports/route_pg.rpt { check_pg_connectivity }
redirect -file reports/route_qor.rpt { report_qor -summary }
redirect -file reports/route_constraints.rpt { report_constraint -all_violators }
current_scenario func_slow
redirect -file reports/route_setup.rpt {
  report_timing -delay_type max -max_paths 20 -slack_lesser_than 0 -path_type full_clock
}
current_scenario func_fast
redirect -file reports/route_hold.rpt {
  report_timing -delay_type min -max_paths 20 -slack_lesser_than 0 -path_type full_clock
}

save_block -as ${DESIGN_NAME}_route
save_lib -all
echo "Route done. Opens and shorts in route_drc.rpt should be 0."
echo "Next is 07_finish.tcl"
