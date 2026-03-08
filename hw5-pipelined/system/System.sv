`include "MyClockGen.v"
`include "DatapathPipelined.sv"

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
      .trace_completed_pc(trace_writeback_pc),
      .trace_completed_insn(trace_writeback_insn),
      .trace_completed_cycle_status(trace_writeback_cycle_status)
  );

endmodule

module SystemDemo(
  input wire external_clk_25MHz,
  input wire [6:0] btn,
  output wire [7:0] led,
  output wire [27:0] gp);

  // Memory mapped devices
  localparam int MmapGpioStart   = 32'hFF00_1000;
  localparam int LastGpioIndex   = 27;
  localparam int MmapGpioEnd     = MmapGpioStart + LastGpioIndex;
  localparam int MmapLeds        = 32'hFF00_2000;
  localparam int MmapButtons     = 32'hFF00_3000;

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

  // Memory-mapped devices, output-only
  wire is_gpio_write = (mem_data_we != 0) && (MmapGpioStart <= mem_data_addr && mem_data_addr <= MmapGpioEnd);
  wire is_led_write = (mem_data_we != 0) && (mem_data_addr == MmapLeds);
  wire is_button_read = mem_data_addr == MmapButtons;
  logic [7:0] led_reg;
  logic [27:0] gpio_reg;
  always_ff @(posedge clk_proc) begin
    if (!clk_locked) begin
      led_reg <= 0;
      gpio_reg <= 0;
    end else begin
      if (is_gpio_write) begin
        gpio_reg[mem_data_addr - MmapGpioStart] <= mem_data_to_write[0];
      end else if (is_led_write) begin
        led_reg <= mem_data_to_write[7:0];
      end
    end
  end
  assign gp = gpio_reg;
  assign led = led_reg;

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
      .store_we_to_dmem  (is_gpio_write ? 4'd0 : mem_data_we)
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
      .halt(),
      .trace_completed_pc(trace_writeback_pc),
      .trace_completed_insn(trace_writeback_insn),
      .trace_completed_cycle_status(trace_writeback_cycle_status)
  );

endmodule
