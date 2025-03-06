`include "MyClockGen.v"
`include "DatapathPipelined.sv"
`include "txuartlite.v"
`include "rxuartlite.v"

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

  localparam MAX_INPUT_WIDTH = 64;

  //uart receiver signal
  logic [7:0] rx_data;
  logic rx_ready;

  //uart transmitter signal
  logic [7:0] tx_data;
  logic tx_ready; 
  logic tx_busy;
  logic [$clog2(MAX_INPUT_WIDTH)-1:0] tx_index, tx_index_next;
  
  rxuartlite uart_receive(
    .i_clk(external_clk_25MHz),
    .i_reset(1'b0),
    .i_uart_rx(ftdi_txd),
    .o_wr(rx_ready),
    .o_data(rx_data)
  );

  txuartlite uart_transmit(
    .i_clk(external_clk_25MHz),
    .i_reset(1'b0),
    .i_wr(tx_ready),
    .i_data(tx_data),
    .o_uart_tx(ftdi_rxd),
    .o_busy(tx_busy)
  );

  //Have a pool to store all the input file
  //When "enter" key is pressed, the input is completed
  //When rx_ready is high, rx_dta will be registered
  logic [7:0] pool [0:MAX_INPUT_WIDTH-1];
  logic [7:0] pool_next [0:MAX_INPUT_WIDTH-1];

  //len points to the next space to be written
  logic [$clog2(MAX_INPUT_WIDTH)-1:0] len, len_next;

  //When input_done is high, the input is completed
  logic input_done, input_done_next;

  initial len = 0;
  initial input_done = 0;
  initial tx_index = 0;
  initial for(int i = 0; i < MAX_INPUT_WIDTH; i = i + 1) begin
    pool[i] = 8'h00;
  end

  always_comb begin
    //Initial value
    len_next = len;
    input_done_next = input_done;
    tx_index_next = tx_index;
    tx_data = 8'h00;

    for(int i = 0; i < MAX_INPUT_WIDTH; i = i + 1) begin
      pool_next[i] = pool[i];
    end

    //Change value
    //Input
    if(rx_ready && input_done == 0) begin
      pool_next[len] = rx_data;
      if(rx_data == 8'h0D) begin
        len_next = len;
        input_done_next = 1'b1;
      end
      else begin
        len_next = len + 1;
      end
    end
    //Output
    else if(tx_ready) begin
      tx_index_next = tx_index + 1;
      tx_data = pool[tx_index];
      if(tx_index == len) begin
        tx_index_next = 0;
        input_done_next = 0;
        len_next = 0;
        for(int i = 0; i < MAX_INPUT_WIDTH; i = i + 1) begin
          pool_next[i] = 8'h00;
        end
      end
    end
  end

  always_ff@(posedge external_clk_25MHz) begin
    len <= len_next;
    input_done <= input_done_next;
    tx_index <= tx_index_next;
    for(int i = 0; i < MAX_INPUT_WIDTH; i = i + 1) begin
      pool[i] <= pool_next[i];
    end
  end

  //Might be buggy
  assign led = {1'b0,len[2:0],3'b0,input_done};
  assign tx_ready = input_done && !tx_busy;
  assign wifi_gpio0 = 1'b1;

endmodule
