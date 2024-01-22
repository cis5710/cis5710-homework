set outputDir ./output
file mkdir $outputDir

# read the contents of a file and return it as a string
proc get_file_contents { filename } {
    if {[catch {
        set FH [open $filename r]
        set content [read $FH]
        close $FH
    } errorstring]} {
        error " File $filename could not be opened : $errorstring "
    }
    return $content
}

if {[get_file_contents .step] == "synthesis"} { # just doing synthesis
    read_verilog [get_file_contents .synthesis-source-files]
} else { # going all the way to implementation
    read_verilog [get_file_contents .implementation-source-files]
}


# Need to set_part so that IP blocks work correctly
# https://forums.xilinx.com/t5/Vivado-TCL-Community/project-part-don-t-match-when-run-tcl-command/td-p/440404
set_part xc7z020clg484-1

# only add IP blocks if there are any
if { [string length [get_file_contents .ip-blocks]] > 0 } {
    read_ip [get_file_contents .ip-blocks]

    # generate synthesis targets for IP blocks, so they will get synthesized by synth_design below
    if { [llength [get_ips]] > 0 } {
        generate_target all [get_ips]
        #synth_ip [get_ips charLib init_sequence_rom pixel_buffer] # <- doesn't work for some reason
    }
}

# synthesize for zedboard chip 

if {[get_file_contents .step] == "synthesis"} { # just doing synthesis
    synth_design -top [get_file_contents .top-synth-module] -part xc7z020clg484-1

} else { # going all the way to implementation instead
    if {[get_file_contents .top-impl-module] == ""} {
        error "This design has no top-level module defined for implementation. It can only be run through synthesis."
    }

    # only add constraint files if there are any
    if { [string length [get_file_contents .constraint-files]] > 0 } {
        read_xdc [get_file_contents .constraint-files]
    }

    # William's higher-optimization mode
    #synth_design -top [get_file_contents .top-impl-module] -part xc7z020clg484-1 -retiming -directive AreaOptimized_high -flatten_hierarchy full -gated_clock_conversion on
    synth_design -top [get_file_contents .top-impl-module] -part xc7z020clg484-1
}

# reports about the synthesized design
report_timing_summary -file $outputDir/post_synth_timing_summary_report.txt
report_utilization -file $outputDir/post_synth_utilization.txt
report_drc -file $outputDir/post_synth_drc_report.txt

puts "Synthesis complete!"
if {[get_file_contents .step] == "synthesis"} {
    exit
}

# Now, run implementation and generate a bitstream

# run place & route
opt_design
place_design
route_design

# William's higher-optimization mode
# opt_design -directive ExploreSequentialArea
# place_design -directive ExtraPostPlacementOpt
# route_design -directive Explore
# phys_opt_design -directive AggressiveExplore

puts "Implementation complete!"

# reports about the implemented design
report_power -file $outputDir/post_route_power_report.txt
report_clocks -file $outputDir/post_route_clocks_report.txt
report_design_analysis -file $outputDir/post_route_design_analysis_report.txt
report_utilization -file $outputDir/post_route_utilization_report.txt
report_route_status -file $outputDir/post_route_status_report.txt
report_timing -file $outputDir/post_route_timing_report.txt
report_timing_summary -file $outputDir/post_route_timing_summary_report.txt
report_drc -file $outputDir/post_route_drc_report.txt

# write out the bitstream
write_bitstream -force $outputDir/[get_file_contents .bitstream-filename]

puts "Writing bitstream complete!"
