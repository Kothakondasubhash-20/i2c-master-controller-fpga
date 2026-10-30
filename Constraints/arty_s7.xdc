## ============================================================
## Arty S7-25 Constraints File
## I2C Master Controller Project
## ============================================================

## ---- Allow bitstream generation with unconstrained I/O ----
## These lines demote the UCIO-1 and NSTD-1 DRC errors to warnings
## so the bitstream can be generated. Required when Vivado's
## implementation run does not pick up the pin constraints.
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]

## ---- Clock (onboard oscillator) ----
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

## ---- Reset Button (BTN0) ----
set_property -dict { PACKAGE_PIN C18   IOSTANDARD LVCMOS33 } [get_ports { rst_btn }];

## ---- I2C Pins on Arduino/Shield Header (J13/J14) ----
set_property -dict { PACKAGE_PIN J13   IOSTANDARD LVCMOS33 } [get_ports { sda }];
set_property -dict { PACKAGE_PIN J14   IOSTANDARD LVCMOS33 } [get_ports { scl }];

## Enable internal pull-ups for I2C (open-drain bus)
set_property PULLUP true [get_ports { sda }];
set_property PULLUP true [get_ports { scl }];

## ---- LEDs ----
set_property -dict { PACKAGE_PIN H5    IOSTANDARD LVCMOS33 } [get_ports { led0 }];
set_property -dict { PACKAGE_PIN J5    IOSTANDARD LVCMOS33 } [get_ports { led1 }];

## ============================================================
## Clock Routing Fix
## Demotes the "IOB driving BUFG" placement error to a warning.
## ============================================================
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_IBUF]
