# ========================================================================
# arty_a7.xdc – Pin constraints for Arty A7-35T
# Target board: Digilent Arty A7-35T (Xilinx Artix-7 XC7A35T)
# ========================================================================

# Clock: 100 MHz onboard oscillator
set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVCMOS33 } [get_ports { clk }]
create_clock -period 10.000 -name sys_clk [get_ports { clk }]

# Buttons (active high on Arty A7)
set_property -dict { PACKAGE_PIN D9  IOSTANDARD LVCMOS33 } [get_ports { btn[0] }]
set_property -dict { PACKAGE_PIN C9  IOSTANDARD LVCMOS33 } [get_ports { btn[1] }]
set_property -dict { PACKAGE_PIN B9  IOSTANDARD LVCMOS33 } [get_ports { btn[2] }]
set_property -dict { PACKAGE_PIN B8  IOSTANDARD LVCMOS33 } [get_ports { btn[3] }]

# Switches
set_property -dict { PACKAGE_PIN A8  IOSTANDARD LVCMOS33 } [get_ports { sw[0] }]
set_property -dict { PACKAGE_PIN C11 IOSTANDARD LVCMOS33 } [get_ports { sw[1] }]
set_property -dict { PACKAGE_PIN C10 IOSTANDARD LVCMOS33 } [get_ports { sw[2] }]
set_property -dict { PACKAGE_PIN A10 IOSTANDARD LVCMOS33 } [get_ports { sw[3] }]

# LEDs
set_property -dict { PACKAGE_PIN H5  IOSTANDARD LVCMOS33 } [get_ports { led[0] }]
set_property -dict { PACKAGE_PIN J5  IOSTANDARD LVCMOS33 } [get_ports { led[1] }]
set_property -dict { PACKAGE_PIN T9  IOSTANDARD LVCMOS33 } [get_ports { led[2] }]
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports { led[3] }]
set_property -dict { PACKAGE_PIN V10 IOSTANDARD LVCMOS33 } [get_ports { led[4] }]
set_property -dict { PACKAGE_PIN V11 IOSTANDARD LVCMOS33 } [get_ports { led[5] }]
set_property -dict { PACKAGE_PIN U12 IOSTANDARD LVCMOS33 } [get_ports { led[6] }]
set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } [get_ports { led[7] }]
set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 } [get_ports { led[8] }]
set_property -dict { PACKAGE_PIN U13 IOSTANDARD LVCMOS33 } [get_ports { led[9] }]
set_property -dict { PACKAGE_PIN T13 IOSTANDARD LVCMOS33 } [get_ports { led[10] }]
set_property -dict { PACKAGE_PIN R13 IOSTANDARD LVCMOS33 } [get_ports { led[11] }]
set_property -dict { PACKAGE_PIN R14 IOSTANDARD LVCMOS33 } [get_ports { led[12] }]
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports { led[13] }]
set_property -dict { PACKAGE_PIN R15 IOSTANDARD LVCMOS33 } [get_ports { led[14] }]
set_property -dict { PACKAGE_PIN R16 IOSTANDARD LVCMOS33 } [get_ports { led[15] }]

# Configuration
set_property CFGBVS VCCO       [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
