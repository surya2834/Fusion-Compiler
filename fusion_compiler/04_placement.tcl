# Fusion Compiler — router, step 4. Placement.
# Run from this folder:
#   fc_shell -f 04_placement.tcl | tee logs/placement.log
# Next: 05_cts.tcl
#
# place_opt places the cells and sizes them. The clock is still ideal.
# Hold is not the goal yet. A missing scan DEF must not stop this block.

set DESIGN_NAME "router_top"
set DLIB        "./${DESIGN_NAME}.dlib"

file mkdir reports
open_lib $DLIB
open_block ${DESIGN_NAME}_power

set_qor_strategy -stage pnr -metric {timing}

set_app_options -name place.coarse.continue_on_missing_scandef -value true
set_app_options -name place.coarse.max_density -value 0.65

place_opt

redirect -file reports/place_legality.rpt { catch { check_legality -verbose } }
redirect -file reports/place_congestion.rpt { report_congestion }
redirect -file reports/place_qor.rpt { report_qor -summary }
redirect -file reports/place_constraints.rpt { catch { report_constraint -all_violators } }
redirect -file reports/place_pg.rpt { catch { check_pg_connectivity } }
current_scenario func_slow
redirect -file reports/place_setup.rpt {
  catch { report_timing -delay_type max -max_paths 20 -slack_lesser_than 0 -path_type full_clock }
}

save_block -as ${DESIGN_NAME}_place
save_lib -all
echo "Placement done. Congestion overflow should be near 0."
echo "Next is 05_cts.tcl"
