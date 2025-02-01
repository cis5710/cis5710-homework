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
      .trace_writeback_pc(trace_writeback_pc),
      .trace_writeback_insn(trace_writeback_insn),
      .trace_writeback_cycle_status(trace_writeback_cycle_status)
  );

endmodule
