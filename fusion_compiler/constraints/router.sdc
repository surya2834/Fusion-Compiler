# Timing constraints for router_top.
# Clock port in the RTL is "router_clock". Period is in nanoseconds.
# 10 ns is 100 MHz. Tighten CLK_PERIOD after the first compile meets timing.

set CLK_PERIOD 10.0
set CLK_NAME   router_clock
set CLK_PORT   router_clock

create_clock -name $CLK_NAME -period $CLK_PERIOD \
  -waveform [list 0 [expr {$CLK_PERIOD / 2.0}]] [get_ports $CLK_PORT]

# Setup margin covers jitter. Hold margin stays small so hold is not hidden.
set_clock_uncertainty -setup 0.25 [get_clocks $CLK_NAME]
set_clock_uncertainty -hold  0.05 [get_clocks $CLK_NAME]
set_clock_transition 0.10 [get_clocks $CLK_NAME]

# Every input except the clock is data launched by the same clock.
# 3 ns is the time already used outside this block.
set DATA_IN [remove_from_collection [all_inputs] [get_ports $CLK_PORT]]

set_input_delay  -max 3.0 -clock $CLK_NAME $DATA_IN
set_input_delay  -min 0.2 -clock $CLK_NAME $DATA_IN
set_output_delay -max 3.0 -clock $CLK_NAME [all_outputs]
set_output_delay -min 0.2 -clock $CLK_NAME [all_outputs]

# Slew into the pins, and a light load on each output. Units follow the library.
set_input_transition 0.10 $DATA_IN
set_load 0.02 [all_outputs]

set_max_transition 0.15 [current_design]
set_max_fanout 16 [current_design]

# resetn in this router is sampled on posedge clock, so it stays a data pin.
# If the RTL uses "or negedge resetn", replace the input delay on resetn with:
#   set_false_path -from [get_ports resetn]
