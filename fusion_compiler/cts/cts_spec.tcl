# Shared clock spec. 05_cts.tcl and every pattern in this folder source it.
# It does not open a library. The .dlib must already be open.
#
# Theory — skew is the spread of clock arrival at the flops.
# A tree balances that with buffers. An H-tree matches the global wires.
# A mesh shorts many drivers so one weak buffer cannot skew the block.
# A spine is a trunk with side stripes, for a long thin floorplan.
# Edit the cell names and layers so they match the SAED NDM.
#
# Purpose of each setting:
#   target_skew       how far apart the flops may receive the clock
#   max_transition    slowest allowed slew on a clock net
#   max_capacitance   largest load one clock cell may drive
#   NDR               clock wires wider and farther apart than signal wires
#   root / internal   the trunk and the middle of the tree use the NDR
#   sink             the last wire into the flop can use the default rule
#   cts purpose      only these cells may be inserted in the clock tree

set CLOCK_NAME   "router_clock"
set CLK_BUF      "*/CKBUF*"
set CLK_INV      "*/CKINV*"
set CLK_MIN_LAYER "M5"
set CLK_MAX_LAYER "M6"
set TARGET_SKEW   0.050
set CLK_MAX_TRAN  0.150
set CLK_MAX_CAP   0.200

create_routing_rule clk_ndr -default_reference_rule \
  -widths   {M5 0.2 M6 0.2 M7 0.4 M8 0.4} \
  -spacings {M5 0.2 M6 0.2 M7 0.4 M8 0.4}

set_clock_routing_rules -rules clk_ndr \
  -net_type {root internal} \
  -min_routing_layer $CLK_MIN_LAYER \
  -max_routing_layer $CLK_MAX_LAYER

set_clock_routing_rules -default_rule -net_type sink

set_clock_tree_options -clocks [get_clocks $CLOCK_NAME] \
  -target_skew $TARGET_SKEW \
  -max_transition $CLK_MAX_TRAN \
  -max_capacitance $CLK_MAX_CAP

# Root of the tree stays on the wide rule until the fanout drops below this.
set_clock_tree_options -root_ndr_fanout_limit 64

set_lib_cell_purpose -include cts [get_lib_cells $CLK_BUF]
set_lib_cell_purpose -include cts [get_lib_cells $CLK_INV]

# Delay cells are for hold on data paths, not for building the clock.
# set_lib_cell_purpose -exclude cts [get_lib_cells */DEL*]

report_clock_routing_rules
report_clock_tree_options
echo "CTS spec applied for clock $CLOCK_NAME"
