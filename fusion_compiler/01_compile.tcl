# Fusion Compiler — step 1, map RTL to gates.
# Shell:  fc_shell -f 01_compile.tcl | tee logs/compile.log
# Next:    02_floorplan.tcl
#
# compile_fusion stages, in order:
#   initial_map   RTL operators become gates from the NDM library
#   logic_opto    resize and restructure those gates for timing and power
#   initial_place first coarse placement
#   initial_drc   high-fanout nets and max-transition repair
#   initial_opto  timing and congestion optimization on that placement
#   final_place   move cells again after optimization
#   final_opto    last logic optimization inside compile_fusion
#
# Three ways to run it. This script uses the regular flow.
#
# UNIFIED — compile_fusion with no -to.
#   Runs all seven stages, including placement.
#   Use only when you accept an automatic floorplan.
#
# REGULAR — this script. Stop at logic_opto.
#   Gates exist. Cells are not placed yet.
#   Use this when you want to draw the floorplan yourself in the next file.
#
# CLASSIC — compile_fusion -to initial_opto.
#   Includes a placement inside synthesis.
#   Use this when timing must see wire distance before CTS,
#   and you will not hand-edit the floorplan first.

set DESIGN_NAME "msrv32_top"
set NLIB        "./nlib/${DESIGN_NAME}.nlib"

file mkdir reports
open_lib $NLIB
open_block $DESIGN_NAME

# -stage synthesis : settings meant for mapping RTL, not for routing.
# -metric timing   : meet the clock first.
# Add total_power when leakage and dynamic power matter as much as slack.
# Add leakage_power when the library has LVT and HVT and leakage is the goal.
set_qor_strategy -stage synthesis -metric {timing}

# Optional. Writes the settings to a file so you can read what the recipe turned on.
# set_qor_strategy -stage synthesis -metric {timing} -output reports/qor_strategy_synth.tcl

# Stop after logic_opto so 02_floorplan.tcl still owns the die size.
compile_fusion -to logic_opto

# Other stopping points. Use only one. Comment the line above if you use one of these.
# compile_fusion -to initial_map
#   Use when you only want to see which cells were chosen, before optimization.
# compile_fusion -from logic_opto -to logic_opto
#   Use to repeat logic optimization after you change the SDC.
# compile_fusion -to initial_opto
#   Classic flow. Skips your own floorplan. Do not use it with 02_floorplan.tcl.

redirect -file reports/compile_qor.rpt { report_qor }
redirect -file reports/compile_area.rpt { report_area }
redirect -file reports/compile_timing.rpt { report_timing -max_paths 20 -slack_lesser_than 0 -path_type full_clock }
redirect -file reports/compile_constraints.rpt { report_constraint -all_violators }
redirect -file reports/compile_check_design.rpt { check_design }

save_block -as ${DESIGN_NAME}_compile
save_lib -all
echo "Compile stopped after logic_opto. Cells are not placed yet."
echo "Next is 02_floorplan.tcl"
