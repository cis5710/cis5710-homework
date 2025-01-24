`include "MyClockGen.v"
`include "DatapathSingleCycle.sv"

module debounce (
    input  wire clk,
    output wire btn_out,
    input  wire btn_in
);
  // reg [7:0] cnt = 0;
    reg [23:0] clk_cnt = 0;
    reg prev_btn = 0;
    assign btn_out = prev_btn;

    always_ff @(posedge clk) begin
        clk_cnt <= clk_cnt + 1;
    end

    always_ff @(posedge clk_cnt[20]) begin
        prev_btn <= btn_in;
        // if (prev_btn == 1'b0 && btn[1]==1'b1)
        //     cnt <= cnt + 1;
    end

endmodule

module SystemResourceCheck (
    input wire external_clk_25MHz,
    input wire [6:0] btn,
    output wire [7:0] led
);

// NB: btn[0] is active-low: it sends 1 when not pressed, and 0 when pressed
  wire rst_n;
  debounce db0 (
      .clk(clk_proc),
      .btn_in(btn[0]),
      .btn_out(rst_n)
  );
  assign led[1] = !rst_n;

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
      .NUM_WORDS(8192)
  ) memory (
      .rst      (!rst_n),
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
      .rst(!rst_n),
      .pc_to_imem(pc_to_imem),
      .insn_from_imem(insn_from_imem),
      .addr_to_dmem(mem_data_addr),
      .store_data_to_dmem(mem_data_to_write),
      .store_we_to_dmem(mem_data_we),
      .load_data_from_dmem(mem_data_loaded_value),
      .halt(led[0])
  );

endmodule
