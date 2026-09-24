# Fusion Compiler — step 0, open the RTL or the gate netlist.
# Shell:  fc_shell -f 00_init.tcl | tee logs/init.log
# Next:    01_compile.tcl
#
# fc_shell is not icc2_shell and not dc_shell.
# The reference library is NDM. It holds timing and cell shapes together.
# A Design Compiler .db is not a Fusion Compiler reference library.

set DESIGN_NAME "msrv32_top"
set RTL_DIR     "/home1/BPPD09/DVNSurya/VLSI_PD/final/synth/rtl"
set SDC_FILE    "/home1/BPPD09/DVNSurya/VLSI_PD/final/synth/constraints/cons.sdc"
set TECH_FILE   "/home1/BPPD09/DVNSurya/VLSI_PD/Project/router_pnr_flow/ref/tech/saed32nm_1p9m.tf"
set LAYER_MAP   "/home1/BPPD09/DVNSurya/VLSI_PD/Project/router_pnr_flow/ref/tech/saed32nm_tf_itf_tluplus.map"
set TLU_MAX     "/home1/BPPD09/DVNSurya/VLSI_PD/Project/router_pnr_flow/ref/tech/saed32nm_1p9m_Cmax.lv.tluplus"
set TLU_MIN     "/home1/BPPD09/DVNSurya/VLSI_PD/Project/router_pnr_flow/ref/tech/saed32nm_1p9m_Cmin.lv.tluplus"
set REF_LIBS    [list /path/to/saed32lvt.ndm]
set NLIB        "./${DESIGN_NAME}.dlib"

set MIN_ROUTE_LAYER "M2"
set MAX_ROUTE_LAYER "M6"

file mkdir nlib reports logs outputs
set_host_options -max_cores 8

# -technology  : metal and via rules from the tech file.
# -ref_libs    : which cells compile_fusion is allowed to use.
create_lib -technology $TECH_FILE -ref_libs $REF_LIBS $NLIB

# OPTION A — start from RTL. Use this when Fusion Compiler does synthesis.
analyze -format verilog [glob ${RTL_DIR}/*.v]
elaborate $DESIGN_NAME
current_block $DESIGN_NAME
link_block

# OPTION B — start from a Design Compiler netlist. Comment A and uncomment B.
# Use this when synthesis is already finished and you only want place and route.
# read_verilog -top $DESIGN_NAME /path/to/riscv_netlist.v
# current_block $DESIGN_NAME
# link_block

read_parasitic_tech -tlup $TLU_MAX -layermap $LAYER_MAP -name tlup_max
read_parasitic_tech -tlup $TLU_MIN -layermap $LAYER_MAP -name tlup_min

# func_slow : setup timing, slow cells, max wire cap.
# func_fast : hold timing, fast cells, min wire cap.
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

# Signal routes stay off the cell-rail layer and off the top power layers.
set_ignored_layers -min_routing_layer $MIN_ROUTE_LAYER -max_routing_layer $MAX_ROUTE_LAYER

group_path -name REG2REG -from [all_registers -clock_pins] -to [all_registers -data_pins]
group_path -name IN2REG  -from [all_inputs] -to [all_registers -data_pins]
group_path -name REG2OUT -from [all_registers -clock_pins] -to [all_outputs]

# Preview the recipe without changing the design. Use this before the first compile.
# set_qor_strategy -stage synthesis -metric {timing total_power} -report_only

redirect -file reports/init_check_design.rpt { check_design }
redirect -file reports/init_check_timing.rpt { check_timing }
redirect -file reports/init_clocks.rpt { report_clocks }

save_block
save_lib -all
echo "Init done. Next is 01_compile.tcl"
