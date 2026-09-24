# Pattern: clock spine.
# When to use: a tall or wide block where one direction needs a strong clock
# and a full mesh would block too much metal.
#
# A spine is one or more long trunks. Stripes hang off a trunk and do not
# touch the stripes of the next trunk. That gap is the backoff.
#
# -spine_direction vertical : trunks run vertically. Use horizontal for a wide block.
# -length  : how far each stripe sticks out from its trunk, in microns.
# -backoff : minimum gap between stripes of different trunks.
# -types {stripe user_route} : stripe can be connected later. user_route is the trunk.
#
# This is not an X-tree. Fusion Compiler has no X-tree command.
#
# Run after placement, block already open:
#   source fusion_compiler/cts/cts_spine.tcl

source fusion_compiler/cts/cts_spec.tcl

set SPINE_NET "clk_spine"

create_net $SPINE_NET

create_clock_straps -nets [get_nets $SPINE_NET] \
  -layers {M7 M8} \
  -widths {0.8 1.2} \
  -types {stripe user_route} \
  -grids {{20 800 100} {40 800 160}} \
  -length 120 \
  -backoff 5 \
  -spine_direction vertical

create_clock_drivers -loads [get_nets $SPINE_NET] \
  -boxes {2 8} \
  -lib_cells [get_lib_cells $CLK_BUF] \
  -short_outputs \
  -output_net_name $SPINE_NET

synthesize_multisource_global_clock_trees \
  -nets [get_nets $SPINE_NET] \
  -lib_cells [get_lib_cells $CLK_BUF] \
  -use_zroute_for_pin_connections

legalize_placement

# fishbone : several flops share one finger into the stripe. Default.
#   Use when the stripe pitch is large and a private wire per flop is wasteful.
#   -fishbone_fanout caps how many flops share that finger.
# comb : each flop gets its own short wire to the nearest stripe.
#   Use when fingers would make the last stage too long.
route_clock_straps -nets [get_nets $SPINE_NET] -topology fishbone -fishbone_fanout 8
# route_clock_straps -nets [get_nets $SPINE_NET] -topology comb

set_propagated_clock [get_clocks $CLOCK_NAME]
clock_opt -from build_clock -to route_clock

redirect -file reports/cts_spine_skew.rpt { report_clock_timing -type skew }
redirect -file reports/cts_spine_qor.rpt { report_clock_qor }

save_block -as ${DESIGN_NAME}_cts_spine
echo "Spine done. Fishbone connect is active. Comb is the commented line."
