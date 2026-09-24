# Fusion Compiler — router, step 6. Signal routing.
# Run from this folder:
#   fc_shell -f 06_route.tcl | tee logs/route.log
# Next: 07_finish.tcl
#
# Clock nets and power straps are already wired.
# This step wires the data nets, then repairs timing on those real wires.
# Antenna repair is on so a long metal into a gate can be broken during detail route.

set DESIGN_NAME "router_top"
set DLIB        "./${DESIGN_NAME}.dlib"

file mkdir reports
open_lib $DLIB
open_block ${DESIGN_NAME}_cts

set_qor_strategy -stage pnr -metric {timing}
set_app_options -name route.detail.antenna -value true

route_auto -max_detail_route_iterations 5
redirect -file reports/route_initial.rpt { catch { check_routes } }

route_opt

redirect -file reports/route_drc.rpt { catch { check_routes } }
redirect -file reports/route_antenna.rpt { catch { check_routes -antenna } }
redirect -file reports/route_legality.rpt { catch { check_legality -verbose } }
redirect -file reports/route_pg.rpt { catch { check_pg_connectivity } }
redirect -file reports/route_qor.rpt { report_qor -summary }
redirect -file reports/route_constraints.rpt { catch { report_constraint -all_violators } }
current_scenario func_slow
redirect -file reports/route_setup.rpt {
  catch { report_timing -delay_type max -max_paths 20 -slack_lesser_than 0 -path_type full_clock }
}
current_scenario func_fast
redirect -file reports/route_hold.rpt {
  catch { report_timing -delay_type min -max_paths 20 -slack_lesser_than 0 -path_type full_clock }
}

save_block -as ${DESIGN_NAME}_route
save_lib -all
echo "Route done. Opens and shorts in route_drc.rpt should be 0."
echo "Next is 07_finish.tcl"
