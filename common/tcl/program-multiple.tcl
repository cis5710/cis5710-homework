# program a series of bitstreams, specified 1 per line in the file referenced by
# the BITSTREAM_FILE environment variable. Takes about 3 seconds to program each
# bitstream. The user is prompted to validate that each bitstream works as
# expected; those that do not are logged to the file 'notok.txt'.

# This is used for grading the lab demos.

if {![info exists env(BITSTREAM_FILE)]} {
    puts "BITSTREAM_FILE environment variable isn't set. Don't know what .bit files to use, exiting."
    exit 1
}
if {![file isfile $env(BITSTREAM_FILE)]} {
    puts "Bitstream file \"$env(BITSTREAM_FILE)\" does not exist, exiting."
    exit 1
}

if {[catch open_hw errorString]} {
    puts "Could not open hardware: $errorString"
    exit 1
}
if {[catch connect_hw_server errorString]} {
    puts "Could not connect to hardware server: $errorString"
    exit 1
}
if {[catch open_hw_target errorString]} {
    puts "Could not open hardware target: $errorString"
    puts "Is ZedBoard powered on and USB cable connected?"
    exit 1
}
if {[catch current_hw_device xc7z020_1 errorString]} {
    # as a practical matter, this is just setting a variable so I don't think it can fail
    puts "Couldn't set current hardware device: $errorString"
    exit 1
}

set a [open $env(BITSTREAM_FILE) r]              
while {[gets $a line]>=0} {
    puts "Trying $line"
    if {[catch {create_hw_bitstream -hw_device [ current_hw_device ] $line} errorString]} {
	puts "Couldn't associate bitstream with the FPGA for $line: $errorString"
    }
    if {[catch program_hw_devices errorString]} {
	puts "Error programming the FPGA with $line: $errorString"
    }
    puts -nonewline "ok? (blank for yes): "
    set ok [gets stdin]
    if {$ok != ""} {
	puts "$line NOT OK"
	set fp [open "notok.txt" w]
	puts $fp "$line NOT OK"
	close $fp
    }
}

