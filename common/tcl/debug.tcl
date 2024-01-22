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


# project lives in a hidden directory
set outputDir ./.debug-project
file mkdir $outputDir

create_project project_1 $outputDir -part xc7z020clg484-1 -force
set_property board_part em.avnet.com:zed:part0:1.3 [current_project]

add_files -fileset sources_1 [get_file_contents .synthesis-source-files]
add_files -fileset sim_1 [get_file_contents .simulation-source-files]
if { [string length [get_file_contents .constraint-files]] > 0 } {
    add_files -fileset constrs_1 [get_file_contents .constraint-files]
}

# Update compile order for the source and simulation filesets
set_property top [get_file_contents .top-synth-module] [get_filesets sources_1]
set_property top [get_file_contents .top-level-testbench] [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# magic to work around llvm linking error c/o: https://www.xilinx.com/support/answers/67272.html
set_property -name {xsim.elaborate.xelab.more_options} -value {-cc gcc} -objects [get_filesets sim_1]

# launch GUI so that user can run testbench interactively
start_gui
