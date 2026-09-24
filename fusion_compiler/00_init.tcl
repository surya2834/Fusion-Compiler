# Fusion Compiler — router, step 0. Read RTL, libraries, and the SDC.
# Run from this folder:
#   fc_shell -f 00_init.tcl | tee logs/init.log
# Next: 01_compile.tcl
#
# Theory — three library kinds, do not mix them:
#   .db    Design Compiler timing only. Fusion Compiler does not open this.
#   .ndm   reference library. Cell timing and cell shapes. Listed below.
#   .dlib  this run. create_lib writes ./${DESIGN_NAME}.dlib in this folder.
#          Later scripts open that same directory. save_block -as stores
#          each stage inside it.
#
# check_design and check_timing return 0 when they find issues.
# fc_shell would stop the script on that return. catch writes the report
# and lets the run continue so you can read the file.

set DESIGN_NAME "router_top"
set RTL_DIR     "/home1/BPPD09/DVNSurya/VLSI_PD/Fusion_compiler_labs/FC_LABS/min_project/router_rtl"
set SDC_FILE    "./constraints/router.sdc"
set FC_REF      "/home1/BPPD09/DVNSurya/VLSI_PD/Project/router_pnr_flow/ref"
set TECH_FILE   "$FC_REF/tech/saed32nm_1p9m.tf"
set LAYER_MAP   "$FC_REF/tech/saed32nm_tf_itf_tluplus.map"
set TLU_MAX     "$FC_REF/tech/saed32nm_1p9m_Cmax.lv.tluplus"
set TLU_MIN     "$FC_REF/tech/saed32nm_1p9m_Cmin.lv.tluplus"
set REFLIB      "$FC_REF/CLIBs"
set REFERENCE_LIBRARY [list \
  $REFLIB/saed32_hvt.ndm \
  $REFLIB/saed32_lvt.ndm \
  $REFLIB/saed32_rvt.ndm \
  $REFLIB/saed32_sram_lp.ndm]
set DLIB        "./${DESIGN_NAME}.dlib"

set MIN_ROUTE_LAYER "M2"
set MAX_ROUTE_LAYER "M6"

file mkdir reports logs outputs
set_host_options -max_cores 8

create_lib -technology $TECH_FILE -ref_libs $REFERENCE_LIBRARY $DLIB

analyze -format verilog [glob ${RTL_DIR}/*.v]
elaborate $DESIGN_NAME
current_block $DESIGN_NAME

# This FC version does not link RTL with link_block.
# set_top_module resolves the submodules and makes router_top the top.
set_top_module $DESIGN_NAME

read_parasitic_tech -tlup $TLU_MAX -layermap $LAYER_MAP -name tlup_max
read_parasitic_tech -tlup $TLU_MIN -layermap $LAYER_MAP -name tlup_min

# func_slow : setup, slow cells, max wire cap.
# func_fast : hold, fast cells, min wire cap.
# Hold on the slow corner hides real hold violations.
create_mode func
create_corner slow
create_corner fast
create_scenario -name func_slow -mode func -corner slow
create_scenario -name func_fast -mode func -corner fast

current_scenario func_slow
read_sdc $SDC_FILE
set_scenario_status func_slow -active true -setup true -hold false
set_parasitic_parameters -corners slow -late_spec tlup_max -early_spec tlup_max

current_scenario func_fast
read_sdc $SDC_FILE
set_scenario_status func_fast -active true -setup false -hold true
set_parasitic_parameters -corners fast -late_spec tlup_min -early_spec tlup_min

# Signal routes stay off the cell rail (M1) and off the power layers (M7 and up).
set_ignored_layers -min_routing_layer $MIN_ROUTE_LAYER -max_routing_layer $MAX_ROUTE_LAYER

group_path -name REG2REG -from [all_registers -clock_pins] -to [all_registers -data_pins]
group_path -name IN2REG  -from [all_inputs] -to [all_registers -data_pins]
group_path -name REG2OUT -from [all_registers -clock_pins] -to [all_outputs]

redirect -file reports/init_references.rpt { report_references -nosplit }
redirect -file reports/init_check_design.rpt { catch { check_design -checks pre_placement_stage } }
redirect -file reports/init_check_timing.rpt { catch { check_timing } }
redirect -file reports/init_clocks.rpt { report_clocks }
echo "Read reports/init_check_design.rpt and reports/init_check_timing.rpt before compile."

save_block
save_lib -all
echo "Init done. Library is $DLIB. Next is 01_compile.tcl"
