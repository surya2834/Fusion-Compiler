# Fusion Compiler — router, step 1. Map RTL to gates and stop before placement.
# Run from this folder:
#   fc_shell -f 01_compile.tcl | tee logs/compile.log
# Next: 02_floorplan.tcl
#
# compile_fusion stages, in order:
#   initial_map   RTL operators become gates from the reference library
#   logic_opto    resize and restructure those gates for timing
#   initial_place first coarse placement
#   initial_drc   high-fanout nets and max-transition repair
#   initial_opto  timing and congestion optimization on that placement
#   final_place   move cells again after optimization
#   final_opto    last logic optimization inside compile_fusion
#
# This script stops at logic_opto so 02_floorplan.tcl still owns the die.
# compile_fusion with no -to would place the cells and skip that control.

set DESIGN_NAME "router_top"
set DLIB        "./${DESIGN_NAME}.dlib"

file mkdir reports
open_lib $DLIB
open_block $DESIGN_NAME

set_qor_strategy -stage synthesis -metric {timing}

compile_fusion -to logic_opto

redirect -file reports/compile_qor.rpt { report_qor }
redirect -file reports/compile_area.rpt { report_area }
redirect -file reports/compile_timing.rpt { catch { report_timing -max_paths 20 -slack_lesser_than 0 -path_type full_clock } }
redirect -file reports/compile_constraints.rpt { catch { report_constraint -all_violators } }
redirect -file reports/compile_check_design.rpt { catch { check_design -checks pre_placement_stage } }

save_block -as ${DESIGN_NAME}_compile
save_lib -all
echo "Compile stopped after logic_opto. Cells are not placed yet."
echo "Next is 02_floorplan.tcl"
