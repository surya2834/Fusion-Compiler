# Fusion Compiler — step 7, fillers and GDS.
# Shell:  fc_shell -f 07_finish.tcl | tee logs/finish.log
# Next:    PrimeTime on the SPEF, then IC Validator DRC and LVS.
#
# FILLER_CELLS example, largest first:
#   {SAEDLVT14_FILL64 SAEDLVT14_FILL32 SAEDLVT14_FILL8 SAEDLVT14_FILL1}

set DESIGN_NAME "msrv32_top"
set NLIB        "./nlib/${DESIGN_NAME}.nlib"
set FILLER_CELLS ""
set SIGNOFF_DRC_RUNSET ""

file mkdir reports outputs
open_lib $NLIB
open_block ${DESIGN_NAME}_route

# Fillers occupy empty row sites.
# Purpose: foundry density rules. They are not logic.
# Run only after signal routing. A filler added earlier blocks a track.
if {$FILLER_CELLS ne ""} {
  create_stdcell_fillers -lib_cells $FILLER_CELLS
}

# Filler cells also have supply pins. Connect them or LVS reports opens.
connect_pg_net -automatic

redirect -file reports/finish_legality.rpt { check_legality -verbose }
redirect -file reports/finish_pg.rpt { check_pg_connectivity }
redirect -file reports/finish_routes.rpt { check_routes }
redirect -file reports/finish_qor.rpt { report_qor -summary }

# signoff_check_drc uses the foundry deck.
# Purpose: the router check is not the deck the foundry will run.
# Leave the variable empty until you have that runset.
# signoff_fix_drc asks the detail router to repair what the deck reported.
if {$SIGNOFF_DRC_RUNSET ne ""} {
  set_app_options -name signoff.check_drc.runset -value $SIGNOFF_DRC_RUNSET
  signoff_check_drc
  signoff_fix_drc
  signoff_check_drc
}

# -hierarchy design_lib : write the block and the reference cell shapes it uses.
# -keep_data_type       : keep foundry datatype numbers in the GDS.
write_gds -long_names -design $DESIGN_NAME -hierarchy design_lib -keep_data_type \
  ./outputs/${DESIGN_NAME}.gds
write_verilog ./outputs/${DESIGN_NAME}.v
write_def ./outputs/${DESIGN_NAME}.def
write_sdc -output ./outputs/${DESIGN_NAME}.sdc
write_parasitics -output ./outputs/${DESIGN_NAME}.spef

save_block -as ${DESIGN_NAME}_finish
save_lib -all
echo "GDS is ./outputs/${DESIGN_NAME}.gds"
echo "This GDS is not tapeout-clean until PrimeTime and IC Validator are clean."
