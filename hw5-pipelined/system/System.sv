`include "MyClockGen.v"
`include "DatapathPipelined.sv"
`include "txuartlite.v"
`include "rxuartlite.v"
//`include "rx2cpu_bridge.sv"

module SystemResourceCheck (
    input wire external_clk_25MHz,
    input wire [6:0] btn,
    output wire [7:0] led
);

  wire clk_proc, clk_locked;
  MyClockGen clock_gen (
    .input_clk_25MHz(external_clk_25MHz),
    .clk_proc(clk_proc),
    .locked(clk_locked)
  );

  wire [31:0] pc_to_imem, insn_from_imem, mem_data_addr, mem_data_loaded_value, mem_data_to_write;
  wire [3:0] mem_data_we;
  wire [31:0] trace_writeback_pc, trace_writeback_insn;
  cycle_status_e trace_writeback_cycle_status;

  MemorySingleCycle #(
      .NUM_WORDS(128)
  ) memory (
      .rst (!clk_locked),
      .clk (clk_proc),
      // imem is read-only
      .pc_to_imem(pc_to_imem),
      .insn_from_imem(insn_from_imem),
      // dmem is read-write
      .addr_to_dmem(mem_data_addr),
      .load_data_from_dmem(mem_data_loaded_value),
      .store_data_to_dmem (mem_data_to_write),
      .store_we_to_dmem  (mem_data_we)
  );

  DatapathPipelined datapath (
      .clk(clk_proc),
      .rst(!clk_locked),
      .pc_to_imem(pc_to_imem),
      .insn_from_imem(insn_from_imem),
      .addr_to_dmem(mem_data_addr),
      .store_data_to_dmem(mem_data_to_write),
      .store_we_to_dmem(mem_data_we),
      .load_data_from_dmem(mem_data_loaded_value),
      .halt(led[0]),
      .trace_writeback_pc(trace_writeback_pc),
      .trace_writeback_insn(trace_writeback_insn),
      .trace_writeback_cycle_status(trace_writeback_cycle_status)
  );

endmodule

module SystemDemo(
  input external_clk_25MHz,
  input ftdi_txd,
  input [6:0] btn,
  output [7:0] led,
  output ftdi_rxd,
  output wifi_gpio0);
  
  //CPU & MEMORY
  localparam int MmapOutput   = 32'hFF00_1000;
  localparam int MmapInput    = 32'hFF00_2000;

  wire clk_proc, clk_locked;
  MyClockGen clock_gen (
    .input_clk_25MHz(external_clk_25MHz),
    .clk_proc(clk_proc),
    .locked(clk_locked)
  );

  //uart receiver signal
  logic [7:0] rx_data;
  logic rx_ready;

  //uart2cpu signal
  logic [7:0] data2cpu_uart;
  logic [7:0] data2cpu_cpu;
  assign data2cpu_uart = rx_ready ? rx_data : 8'h00;
  assign led = data2cpu_cpu;

  //uart transmitter signal
  logic [7:0] tx_data;
  logic tx_ready; 
  logic tx_busy;

  //cpu2uart signal
  logic [7:0] data2uart_cpu;
  logic [7:0] data2uart_uart;
  assign tx_ready = !tx_busy;
  assign tx_data = data2uart_uart;
  
  rxuartlite uart_receive(
    .i_clk(external_clk_25MHz),
    .i_reset(1'b0),
    .i_uart_rx(ftdi_txd),
    .o_wr(rx_ready),
    .o_data(rx_data)
  );
    
  DP16KD #(
    .DATA_WIDTH_A(9), // Data width for port A
    .DATA_WIDTH_B(9), // Data width for port B
    .REGMODE_A("NOREG"), // Output register configuration for port A
    .REGMODE_B("NOREG"), // Output register configuration for port B
    .RESETMODE("SYNC"), // Reset mode
    .ASYNC_RESET_RELEASE("SYNC"), // Asynchronous reset release mode
    .WRITEMODE_A("NORMAL"), // Write mode for port A
    .WRITEMODE_B("NORMAL")  // Write mode for port B
  ) uart2cpu (
    // Address for uart: use only the first entry
    .ADA13(1'b0), .ADA12(1'b0), .ADA11(1'b0), .ADA10(1'b0), .ADA9(1'b0), .ADA8(1'b0), .ADA7(1'b0),
    .ADA6(1'b0), .ADA5(1'b0), .ADA4(1'b0), .ADA3(1'b0), .ADA2(1'b0), .ADA1(1'b0), .ADA0(1'b0),
    // Data from uart_Rx to CPU        
    .DIA8(1'b0), .DIA7(data2cpu_uart[7]), .DIA6(data2cpu_uart[6]),   
    .DIA5(data2cpu_uart[5]), .DIA4(data2cpu_uart[4]), .DIA3(data2cpu_uart[3]), 
    .DIA2(data2cpu_uart[2]), .DIA1(data2cpu_uart[1]), .DIA0(data2cpu_uart[0]),
    // Control signals for port A
    .CEA(1'b1),         // Clock enable for port A
    .OCEA(1'b1),        // Output clock enable for port A
    .CLKA(external_clk_25MHz),       // Clock for port A
    .WEA(rx_ready),         // Write enable for port A
    .RSTA(1'b0),        // Reset for port A

    // Address for port CPU read: same as uart
    .ADB13(1'b0), .ADB12(1'b0), .ADB11(1'b0), .ADB10(1'b0), .ADB9(1'b0), .ADB8(1'b0), .ADB7(1'b0),
    .ADB6(1'b0), .ADB5(1'b0), .ADB4(1'b0), .ADB3(1'b0), .ADB2(1'b0), .ADB1(1'b0), .ADB0(1'b0),
    //To clear after read
    .DIB8(1'b0), .DIB7(mem_data_to_write[7]), .DIB6(mem_data_to_write[6]),   
    .DIB5(mem_data_to_write[5]), .DIB4(mem_data_to_write[4]), .DIB3(mem_data_to_write[3]), 
    .DIB2(mem_data_to_write[2]), .DIB1(mem_data_to_write[1]), .DIB0(mem_data_to_write[0]),
    // Data output for CPU read 
    .DOB8(), .DOB7(data2cpu_cpu[7]), .DOB6(data2cpu_cpu[6]),   
    .DOB5(data2cpu_cpu[5]), .DOB4(data2cpu_cpu[4]), .DOB3(data2cpu_cpu[3]), 
    .DOB2(data2cpu_cpu[2]), .DOB1(data2cpu_cpu[1]), .DOB0(data2cpu_cpu[0]),
    // Control signals for port B
    .CEB(1'b1),         // Clock enable for port B
    .OCEB(1'b1),        // Output clock enable for port B
    .CLKB(clk_proc),       // Clock for port B
    .WEB(mem_data_addr == MmapInput && |mem_data_we), // Write enable for port B
    .RSTB(1'b0)//,        // Reset for port B
  );
  
  txuartlite uart_transmit(
    .i_clk(external_clk_25MHz),
    .i_reset(1'b0),
    .i_wr(tx_ready),
    .i_data(tx_data),
    .o_uart_tx(ftdi_rxd),
    .o_busy(tx_busy)
  );
  
  DP16KD #(
    .DATA_WIDTH_A(9), // Data width for port A
    .DATA_WIDTH_B(9), // Data width for port B
    .REGMODE_A("NOREG"), // Output register configuration for port A
    .REGMODE_B("NOREG"), // Output register configuration for port B
    .RESETMODE("SYNC"), // Reset mode
    .ASYNC_RESET_RELEASE("SYNC"), // Asynchronous reset release mode
    .WRITEMODE_A("NORMAL"), // Write mode for port A
    .WRITEMODE_B("NORMAL")  // Write mode for port B
  ) cpu2uart (
    // Address for CPU: use only the first entry
    .ADA13(1'b0), .ADA12(1'b0), .ADA11(1'b0), .ADA10(1'b0), .ADA9(1'b0), .ADA8(1'b0), .ADA7(1'b0),
    .ADA6(1'b0), .ADA5(1'b0), .ADA4(1'b0), .ADA3(1'b0), .ADA2(1'b0), .ADA1(1'b0), .ADA0(1'b0),
    // Data from CPU to uart_Tx        
    .DIA8(1'b0), .DIA7(data2uart_cpu[7]), .DIA6(data2uart_cpu[6]),   
    .DIA5(data2uart_cpu[5]), .DIA4(data2uart_cpu[4]), .DIA3(data2uart_cpu[3]), 
    .DIA2(data2uart_cpu[2]), .DIA1(data2uart_cpu[1]), .DIA0(data2uart_cpu[0]),
    // Control signals for port A
    .CEA(1'b1),         // Clock enable for port A
    .OCEA(1'b1),        // Output clock enable for port A
    .CLKA(clk_proc),       // Clock for port A
    .WEA(mem_data_addr == MmapOutput && |mem_data_we),  // Write enable for port A
    .RSTA(1'b0),        // Reset for port A

    // Address for port Uart_Tx read
    .ADB13(1'b0), .ADB12(1'b0), .ADB11(1'b0), .ADB10(1'b0), .ADB9(1'b0), .ADB8(1'b0), .ADB7(1'b0),
    .ADB6(1'b0), .ADB5(1'b0), .ADB4(1'b0), .ADB3(1'b0), .ADB2(1'b0), .ADB1(1'b0), .ADB0(1'b0),
    // Data output for Uart_Tx read 
    .DOB8(), .DOB7(data2uart_uart[7]), .DOB6(data2uart_uart[6]),   
    .DOB5(data2uart_uart[5]), .DOB4(data2uart_uart[4]), .DOB3(data2uart_uart[3]), 
    .DOB2(data2uart_uart[2]), .DOB1(data2uart_uart[1]), .DOB0(data2uart_uart[0]),
    // Control signals for port B
    .CEB(1'b1),         // Clock enable for port B
    .OCEB(1'b1),        // Output clock enable for port B
    .CLKB(external_clk_25MHz),       // Clock for port B
    .WEB(1'b0),         // Write enable for port B (disabled)
    .RSTB(1'b0)//,        // Reset for port B
  );

  wire [31:0] pc_to_imem, insn_from_imem, mem_data_addr, mem_data_loaded_value, mem_data_to_write;
  wire [3:0] mem_data_we;
  wire [31:0] trace_writeback_pc, trace_writeback_insn;
  cycle_status_e trace_writeback_cycle_status;

  assign data2uart_cpu = mem_data_to_write[7:0];

  MemorySingleCycle #(
      .NUM_WORDS(1024)
  ) memory (
      .rst (!clk_locked),
      .clk (clk_proc),
      // imem is read-only
      .pc_to_imem(pc_to_imem),
      .insn_from_imem(insn_from_imem),
      // dmem is read-write
      .addr_to_dmem(mem_data_addr),
      .load_data_from_dmem(mem_data_loaded_value),
      .store_data_to_dmem (mem_data_to_write),
      .store_we_to_dmem  (mem_data_addr == MmapOutput ? 4'd0 : mem_data_we)
  );

  DatapathPipelined datapath (
      .clk(clk_proc),
      .rst(!clk_locked),
      .pc_to_imem(pc_to_imem),
      .insn_from_imem(insn_from_imem),
      .addr_to_dmem(mem_data_addr),
      .store_data_to_dmem(mem_data_to_write),
      .store_we_to_dmem(mem_data_we),
      .load_data_from_dmem(mem_data_addr == MmapInput ? {24'd0, data2cpu_cpu} : mem_data_loaded_value),
      .halt(),
      .trace_writeback_pc(trace_writeback_pc),
      .trace_writeback_insn(trace_writeback_insn),
      .trace_writeback_cycle_status(trace_writeback_cycle_status)
  );

endmodule
