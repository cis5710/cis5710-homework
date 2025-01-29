`include "MyClockGen.v"
`include "DatapathSingleCycle.sv"
`include "system/debouncer.v"

module SystemResourceCheck (
    input wire external_clk_25MHz,
    input wire [6:0] btn,
    output wire [7:0] led
);

  wire clk_proc, clk_mem, clk_locked;
  MyClockGen clock_gen (
    .input_clk_25MHz(external_clk_25MHz),
    .clk_proc(clk_proc),
    .clk_mem(clk_mem),
    .locked(clk_locked)
    );

  wire [31:0] pc_to_imem, insn_from_imem, mem_data_addr, mem_data_loaded_value, mem_data_to_write;
  wire [3:0] mem_data_we;

  MemorySingleCycle #(
      .NUM_WORDS(128)
  ) memory (
      .rst      (!clk_locked),
      .clock_mem (clk_mem),
      // imem is read-only
      .pc_to_imem(pc_to_imem),
      .insn_from_imem(insn_from_imem),
      // dmem is read-write
      .addr_to_dmem(mem_data_addr),
      .load_data_from_dmem(mem_data_loaded_value),
      .store_data_to_dmem (mem_data_to_write),
      .store_we_to_dmem  (mem_data_we)
  );

  DatapathSingleCycle datapath (
      .clk(clk_proc),
      .rst(!clk_locked),
      .pc_to_imem(pc_to_imem),
      .insn_from_imem(insn_from_imem),
      .addr_to_dmem(mem_data_addr),
      .store_data_to_dmem(mem_data_to_write),
      .store_we_to_dmem(mem_data_we),
      .load_data_from_dmem(mem_data_loaded_value),
      .halt(led[0])
  );

endmodule

module SystemDemo (
    input wire external_clk_25MHz,
    input wire [6:0] btn,
    output wire [7:0] led
);

  localparam int MmapButtons   = 32'hFF00_1000;
  localparam int MmapLeds      = 32'hFF00_2000;

  // NB: ULX3S btn[0] is active-low: it sends 1 when not pressed, and 0 when pressed
  wire rst_button_n;
  wire [30:0] ignore;
  debouncer #(.NIN(1)) db (
      .i_clk(clk_proc),
      .i_in(btn[0]),
      .o_debounced(rst_button_n),
      .o_debug(ignore)
  );

  wire clk_proc, clk_mem, clk_locked;
  MyClockGen clock_gen (
    .input_clk_25MHz(external_clk_25MHz),
    .clk_proc(clk_proc),
    .clk_mem(clk_mem),
    .locked(clk_locked)
    );
  wire rst = !rst_button_n || !clk_locked; // rst is high if rst button is pressed or clock isn't locked yet

  wire [31:0] pc_to_imem, insn_from_imem, mem_data_addr, mem_data_loaded_value, mem_data_to_write;
  wire [3:0] mem_data_we;

  // LEDs

  logic [7:0] led_state;
  assign led = led_state;
  always_ff @(posedge clk_mem) begin
    if (rst) begin
      led_state <= 0;
    end else begin
      if (mem_data_addr == MmapLeds && mem_data_we[0] == 1) begin
        led_state <= mem_data_to_write[7:0];
      end
    end
  end

  MemorySingleCycle #(
      .NUM_WORDS(1024)
  ) memory (
      .rst      (rst),
      .clock_mem (clk_mem),
      // imem is read-only
      .pc_to_imem(pc_to_imem),
      .insn_from_imem(insn_from_imem),
      // dmem is read-write
      .addr_to_dmem(mem_data_addr),
      .load_data_from_dmem(mem_data_loaded_value),
      .store_data_to_dmem (mem_data_to_write),
      .store_we_to_dmem  (mem_data_addr == MmapLeds ? 4'd0 : mem_data_we)
  );

  wire halt;
  DatapathSingleCycle datapath (
      .clk(clk_proc),
      .rst(rst),
      .pc_to_imem(pc_to_imem),
      .insn_from_imem(insn_from_imem),
      .addr_to_dmem(mem_data_addr),
      .store_data_to_dmem(mem_data_to_write),
      .store_we_to_dmem(mem_data_we),
      .load_data_from_dmem(mem_data_addr == MmapButtons ? {25'd0,btn} : mem_data_loaded_value),
      .halt(halt)
  );

endmodule
