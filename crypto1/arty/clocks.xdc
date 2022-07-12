# Setup global configs
set_property CFGBVS Vcco [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# System clock
create_clock -add -name xtal -period 10.00 -waveform {0 5} [get_ports { CLK_100M }];

# Create virtual clock for IO
create_clock -name slow_clk -period 1000.0

# Set transport clock as async to hclk
set_clock_groups -asynchronous -group transport_clk -group xtal -group slow_clk
