# ----------------------------------------------------------------------------
#     _____
#    /     \
#   /____   \____
#  / \===\   \==/
# /___\===\___\/  AVNET Design Resource Center
#      \======/         www.em.avnet.com/drc
#       \====/    
# ----------------------------------------------------------------------------
# 
#  Created With Avnet UCF Generator V0.4.0 
#     Date: Saturday, June 30, 2012 
#     Time: 12:18:55 AM 
# 
#  This design is the property of Avnet.  Publication of this
#  design is not authorized without written consent from Avnet.
#  
#  Please direct any questions to:
#     ZedBoard.org Community Forums
#     http://www.zedboard.org
# 
#  Disclaimer:
#     Avnet, Inc. makes no warranty for the use of this code or design.
#     This code is provided  "As Is". Avnet, Inc assumes no responsibility for
#     any errors, which may appear in this code, nor does it make a commitment
#     to update the information contained herein. Avnet, Inc specifically
#     disclaims any implied warranties of fitness for a particular purpose.
#                      Copyright(c) 2012 Avnet, Inc.
#                              All rights reserved.
# 
# ----------------------------------------------------------------------------
# 
#  Notes:
# 
#  10 August 2012
#     IO standards based upon Bank 34 and Bank 35 Vcco supply options of 1.8V, 
#     2.5V, or 3.3V are possible based upon the Vadj jumper (J18) settings.  
#     By default, Vadj is expected to be set to 1.8V but if a different 
#     voltage is used for a particular design, then the corresponding IO 
#     standard within this UCF should also be updated to reflect the actual 
#     Vadj jumper selection.
# 
#  09 September 2012
#     Net names are not allowed to contain hyphen characters '-' since this
#     is not a legal VHDL87 or Verilog character within an identifier.  
#     HDL net names are adjusted to contain no hyphen characters '-' but 
#     rather use underscore '_' characters.  Comment net name with the hyphen 
#     characters will remain in place since these are intended to match the 
#     schematic net names in order to better enable schematic search.
#
#  17 April 2014
#     Pin constraint for toggle switch SW7 was corrected to M15 location.
#
#  16 April 2015
#     Corrected the way that entire banks are assigned to a particular IO
#     standard so that it works with more recent versions of Vivado Design
#     Suite and moved the IO standard constraints to the end of the file 
#     along with some better organization and notes like we do with our SOMs.
#
#   6 June 2016
#     Corrected error in signal name for package pin N19 (FMC Expansion Connector)
#	
#
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# Clock Source - Bank 13
# ---------------------------------------------------------------------------- 
# per Section 2.5 of http://zedboard.org/sites/default/files/documentations/ZedBoard_HW_UG_v2_2.pdf
# this clock is set to 100MHz
set_property PACKAGE_PIN Y9 [get_ports {CLOCK_100MHz}];

# ----------------------------------------------------------------------------
# OLED Display - Bank 13
# ---------------------------------------------------------------------------- 
set_property PACKAGE_PIN U10  [get_ports {OLED_DC}];  # "OLED-DC"
set_property PACKAGE_PIN U9   [get_ports {OLED_RES}];  # "OLED-RES"
set_property PACKAGE_PIN AB12 [get_ports {OLED_SCLK}];  # "OLED-SCLK"
set_property PACKAGE_PIN AA12 [get_ports {OLED_SDIN}];  # "OLED-SDIN"
set_property PACKAGE_PIN U11  [get_ports {OLED_VBAT}];  # "OLED-VBAT"
set_property PACKAGE_PIN U12  [get_ports {OLED_VDD}];  # "OLED-VDD"

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
# VGA Output - Bank 33
# ---------------------------------------------------------------------------- 
# set_property PACKAGE_PIN Y21  [get_ports {VGA_OUT_BLUE[3]}];  # "VGA-B1"
# set_property PACKAGE_PIN Y20  [get_ports {VGA_OUT_BLUE[2]}];  # "VGA-B2"
# set_property PACKAGE_PIN AB20 [get_ports {VGA_OUT_BLUE[1]}];  # "VGA-B3"
# set_property PACKAGE_PIN AB19 [get_ports {VGA_OUT_BLUE[0]}];  # "VGA-B4"
# set_property PACKAGE_PIN AB22 [get_ports {VGA_OUT_GREEN[3]}];  # "VGA-G1"
# set_property PACKAGE_PIN AA22 [get_ports {VGA_OUT_GREEN[2]}];  # "VGA-G2"
# set_property PACKAGE_PIN AB21 [get_ports {VGA_OUT_GREEN[1]}];  # "VGA-G3"
# set_property PACKAGE_PIN AA21 [get_ports {VGA_OUT_GREEN[0]}];  # "VGA-G4"
# set_property PACKAGE_PIN V20  [get_ports {VGA_OUT_RED[3]}];  # "VGA-R1"
# set_property PACKAGE_PIN U20  [get_ports {VGA_OUT_RED[2]}];  # "VGA-R2"
# set_property PACKAGE_PIN V19  [get_ports {VGA_OUT_RED[1]}];  # "VGA-R3"
# set_property PACKAGE_PIN V18  [get_ports {VGA_OUT_RED[0]}];  # "VGA-R4"
# set_property PACKAGE_PIN AA19 [get_ports {VGA_HSYNCH}];  # "VGA-HS"
# set_property PACKAGE_PIN Y19  [get_ports {VGA_VSYNCH}];  # "VGA-VS"

# ----------------------------------------------------------------------------
# User Push Buttons - Bank 34
# ---------------------------------------------------------------------------- 
set_property PACKAGE_PIN T18 [get_ports {BTN_U}];  # "BTNU"
set_property PACKAGE_PIN R16 [get_ports {BTN_D}];  # "BTND"
set_property PACKAGE_PIN N15 [get_ports {BTN_L}];  # "BTNL"
set_property PACKAGE_PIN R18 [get_ports {BTN_R}];  # "BTNR"
set_property PACKAGE_PIN P16 [get_ports {BTN_C}];  # "BTNC"

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

# Set the bank voltage for the buttons to 1.8V by default.
set_property IOSTANDARD LVCMOS18 [get_ports {BTN_U}];
set_property IOSTANDARD LVCMOS18 [get_ports {BTN_D}];
set_property IOSTANDARD LVCMOS18 [get_ports {BTN_L}];
set_property IOSTANDARD LVCMOS18 [get_ports {BTN_R}];
set_property IOSTANDARD LVCMOS18 [get_ports {BTN_C}];

# Set the voltage for the switches to 1.8V, though they can also be 2.5V or 3.3V
# (commented out below) if desired
#set_property IOSTANDARD LVCMOS33 [get_ports {SWITCH[*]}];
#set_property IOSTANDARD LVCMOS25 [get_ports {SWITCH[*]}];
set_property IOSTANDARD LVCMOS18 [get_ports {SWITCH[*]}];

# Note that the bank voltage for IO Bank 13 is fixed to 3.3V on ZedBoard. 
set_property IOSTANDARD LVCMOS33 [get_ports {OLED_DC}];
set_property IOSTANDARD LVCMOS33 [get_ports {OLED_RES}];
set_property IOSTANDARD LVCMOS33 [get_ports {OLED_SCLK}];
set_property IOSTANDARD LVCMOS33 [get_ports {OLED_SDIN}];
set_property IOSTANDARD LVCMOS33 [get_ports {OLED_VBAT}];
set_property IOSTANDARD LVCMOS33 [get_ports {OLED_VDD}];

# Note that the voltages for the LEDs, clock, and VGA signals are fixed to 3.3V
set_property IOSTANDARD LVCMOS33 [get_ports {LED[*]}];
set_property IOSTANDARD LVCMOS33 [get_ports {CLOCK_100MHz}];
# set_property IOSTANDARD LVCMOS33 [get_ports {VGA_OUT_BLUE[*]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {VGA_OUT_GREEN[*]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {VGA_OUT_RED[*]}]
# set_property IOSTANDARD LVCMOS33 [get_ports VGA_HSYNCH]
# set_property IOSTANDARD LVCMOS33 [get_ports VGA_VSYNCH]


# CLOCK SIGNAL

create_clock -period 10 -name CLOCK_100MHz [get_ports {CLOCK_100MHz}]

# timing constraints for Zedboard I/O pins

# no setup/hold (min/max) timing requirements on LEDs, buttons or switches
# set_output_delay -clock [get_clocks CLOCK_100MHz] -min 0.000 [get_ports {LED[*]}]
# set_output_delay -clock [get_clocks CLOCK_100MHz] -max 0.000 [get_ports {LED[*]}]
# set_input_delay -clock [get_clocks CLOCK_100MHz] -min 0.000 [get_ports {SWITCH[*]}]
# set_input_delay -clock [get_clocks CLOCK_100MHz] -max 0.000 [get_ports {SWITCH[*]}]
# set_input_delay -clock [get_clocks CLOCK_100MHz] -min 0.000 [get_ports {BTN_U}]
# set_input_delay -clock [get_clocks CLOCK_100MHz] -min 0.000 [get_ports {BTN_D}]
# set_input_delay -clock [get_clocks CLOCK_100MHz] -min 0.000 [get_ports {BTN_L}]
# set_input_delay -clock [get_clocks CLOCK_100MHz] -min 0.000 [get_ports {BTN_R}]
# set_input_delay -clock [get_clocks CLOCK_100MHz] -min 0.000 [get_ports {BTN_C}]
# set_input_delay -clock [get_clocks CLOCK_100MHz] -max 0.000 [get_ports {BTN_U}]
# set_input_delay -clock [get_clocks CLOCK_100MHz] -max 0.000 [get_ports {BTN_D}]
# set_input_delay -clock [get_clocks CLOCK_100MHz] -max 0.000 [get_ports {BTN_L}]
# set_input_delay -clock [get_clocks CLOCK_100MHz] -max 0.000 [get_ports {BTN_R}]
# set_input_delay -clock [get_clocks CLOCK_100MHz] -max 0.000 [get_ports {BTN_C}]
# TODO: do VGA pins have setup/hold constraints?
