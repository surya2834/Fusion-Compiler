# Fusion Compiler — router, step 7. Fillers and GDS.
# Run from this folder:
#   fc_shell -f 07_finish.tcl | tee logs/finish.log
#
# Fillers occupy empty sites for density. They are not logic.
# Connect their supply pins or LVS reports opens on the rails.
# Leave FILLER_CELLS empty until the SAED names are confirmed.
# Example, largest first: {FILL64_LVT FILL32_LVT FILL8_LVT FILL1_LVT}

set DESIGN_NAME "router_top"
set DLIB        "./${DESIGN_NAME}.dlib"
set FILLER_CELLS ""

file mkdir reports outputs
open_lib $DLIB
open_block ${DESIGN_NAME}_route

if {$FILLER_CELLS ne ""} {
  create_stdcell_fillers -lib_cells $FILLER_CELLS
  connect_pg_net -automatic
}

redirect -file reports/finish_legality.rpt { catch { check_legality -verbose } }
redirect -file reports/finish_pg.rpt { catch { check_pg_connectivity } }
redirect -file reports/finish_routes.rpt { catch { check_routes } }
redirect -file reports/finish_qor.rpt { report_qor -summary }

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
