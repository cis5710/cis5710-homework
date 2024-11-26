# placement of pins used for interacting with the Zedboard's 8 LEDs and 8 switches

# ----------------------------------------------------------------------------
# User LEDs - Bank 33
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN U14 [get_ports {LED[7]}]
set_property PACKAGE_PIN U19 [get_ports {LED[6]}]
set_property PACKAGE_PIN W22 [get_ports {LED[5]}]
set_property PACKAGE_PIN V22 [get_ports {LED[4]}]
set_property PACKAGE_PIN U21 [get_ports {LED[3]}]
set_property PACKAGE_PIN U22 [get_ports {LED[2]}]
set_property PACKAGE_PIN T21 [get_ports {LED[1]}]
set_property PACKAGE_PIN T22 [get_ports {LED[0]}]

# ----------------------------------------------------------------------------
# User DIP Switches - Bank 35
# ---------------------------------------------------------------------------- 
set_property PACKAGE_PIN F22 [get_ports {SWITCH[0]}];
set_property PACKAGE_PIN G22 [get_ports {SWITCH[1]}];
set_property PACKAGE_PIN H22 [get_ports {SWITCH[2]}];
set_property PACKAGE_PIN F21 [get_ports {SWITCH[3]}];
set_property PACKAGE_PIN H19 [get_ports {SWITCH[4]}];
set_property PACKAGE_PIN H18 [get_ports {SWITCH[5]}];
set_property PACKAGE_PIN H17 [get_ports {SWITCH[6]}];
set_property PACKAGE_PIN M15 [get_ports {SWITCH[7]}];


# ----------------------------------------------------------------------------
# IOSTANDARD Constraints
#
# Note that these IOSTANDARD constraints are applied to all IOs currently
# assigned within an I/O bank.  If these IOSTANDARD constraints are 
# evaluated prior to other PACKAGE_PIN constraints being applied, then 
# the IOSTANDARD specified will likely not be applied properly to those 
# pins.  Therefore, bank wide IOSTANDARD constraints should be placed 
# within the XDC file in a location that is evaluated AFTER all 
# PACKAGE_PIN constraints within the target bank have been evaluated.
#
# Un-comment one or more of the following IOSTANDARD constraints according to
# the bank pin assignments that are required within a design.
# ---------------------------------------------------------------------------- 

# Note that the voltage for the LEDs is fixed to 3.3V on the ZedBoard
set_property IOSTANDARD LVCMOS33 [get_ports {LED[*]}];

# Set the voltage for the switches to 3.3V, though they can also be 1.8V or 2.5V
# (commented out below) if desired
set_property IOSTANDARD LVCMOS33 [get_ports {SWITCH[*]}];
#set_property IOSTANDARD LVCMOS25 [get_ports {SWITCH[*]}];
#set_property IOSTANDARD LVCMOS18 [get_ports {SWITCH[*]}];



# timing constraints for Zedboard LEDs and switches

# LEDs have zero setup/hold (min/max) timing requirements
#set_output_delay -clock [get_clocks GCLOCK] -min 0.000 [get_ports {LED[*]}]
#set_output_delay -clock [get_clocks GCLOCK] -max 0.000 [get_ports {LED[*]}]

# Switches have zero setup/hold (min/max) timing requirements
#set_input_delay -clock [get_clocks GCLOCK] -min 0.000 [get_ports {SWITCH[*]}]
#set_input_delay -clock [get_clocks GCLOCK] -max 0.000 [get_ports {SWITCH[*]}]
