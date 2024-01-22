if {![info exists env(BITSTREAM_FILE)]} {
    puts "BITSTREAM_FILE environment variable isn't set. Don't know what .bit file to use, exiting."
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

if {[catch {create_hw_bitstream -hw_device [ current_hw_device ] $env(BITSTREAM_FILE)} errorString]} {
    puts "Couldn't associate bitstream with the FPGA: $errorString"
    exit 1
}
if {[catch program_hw_devices errorString]} {
    puts "Error programming the FPGA: $errorString"
    exit 1
} else {
    puts "FPGA programmed successfully!"
}
