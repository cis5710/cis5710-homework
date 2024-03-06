`timescale 1ns / 1ns
`default_nettype none

module RiscvSystem(// input clock
                  input wire        CLOCK_100MHz,

                  // LEDs, buttons, switches
                  output wire [7:0] LED,
                  input wire        BTN_U,
                  input wire        BTN_D,
                  input wire        BTN_L,
                  input wire        BTN_R,
                  input wire        BTN_C,
                  input wire [7:0]  SWITCH,

                  // OLED
                  output wire       OLED_SDIN,
                  output wire       OLED_SCLK,
                  output wire       OLED_DC,
                  output wire       OLED_RES,
                  output wire       OLED_VBAT,
                  output wire       OLED_VDD
    );

   wire          clocks_ok;
   wire          clock_processor; // processor clock
  //  wire clock_mem;

  wire RESET_SWITCH;

  // NB: ZedBoard switches are active-high
  // TODO: should really debounce this first...
  assign RESET_SWITCH = ~SWITCH[0];

   // Mixed-Mode Clock Manager, see mmcm.v for details
  clk_wiz_0_clk_wiz mmcm (
    // Clock out ports
    .clk_proc(clock_processor),
    // Status and control signals
    .reset(RESET_SWITCH),
    .locked(clocks_ok),
    // Clock in ports
    .clk_in1(CLOCK_100MHz)
  );

  wire global_reset = RESET_SWITCH;

  wire [`REG_SIZE] pc_to_imem, insn_from_imem, addr_from_proc,
    load_data_from_dmem, store_data_from_proc;
  wire [3:0] store_we_from_proc;
  wire datapath_halted;

  wire [7:0] mem_data_loaded_value_oled;
  wire oled_on;

  localparam int MmapMemoryStart = 32'd0;
  localparam int MmapOledStart = 32'h2000_0000;

  // memory mapped devices
  logic [`REG_SIZE] load_data_to_proc;
  logic oled_we;
  logic [3:0] store_we_to_dmem;
  always_comb begin
    // by default, don't write to anything
    oled_we = 1'b0;
    store_we_to_dmem = 4'd0;

    if (addr_from_proc[31:6] == MmapOledStart[31:6]) begin // OLED display
      load_data_to_proc = {24'd0, mem_data_loaded_value_oled};
      oled_we = (store_we_from_proc == 4'b0001); // OLED device allows only byte accesses

    end else begin // otherwise, access regular memory
      load_data_to_proc = load_data_from_dmem;
      store_we_to_dmem = store_we_from_proc;
    end
  end

  OledDevice oled_device (
    // shared ports
    .rst(global_reset),
    .clock_mem(clock_processor),
    .oled_power_button(BTN_L),
    .oled_on(oled_on),

    // ports for the memory-mapped interface
    .addr(addr_from_proc[5:0]),
    .load_data(mem_data_loaded_value_oled),
    .store_data(store_data_from_proc[7:0]),
    .store_we(oled_we),

    // ports for the OLED display itself
    .OLED_CONTROL_CLK(clock_processor),
    .OLED_SDIN(OLED_SDIN),
    .OLED_SCLK(OLED_SCLK),
    .OLED_DC(OLED_DC),
    .OLED_RES(OLED_RES),
    .OLED_VBAT(OLED_VBAT),
    .OLED_VDD(OLED_VDD));

  MemorySingleCycle #(
      .NUM_WORDS(8192)
  ) mem (
      .rst      (global_reset),
      .clk (clock_processor),
      // imem is read-only
      .pc_to_imem(pc_to_imem),
      .insn_from_imem(insn_from_imem),
      // dmem is read-write
      .addr_to_dmem(addr_from_proc),
      .load_data_from_dmem(load_data_from_dmem),
      .store_data_to_dmem (store_data_from_proc),
      .store_we_to_dmem  (store_we_to_dmem)
  );

  DatapathPipelined datapath (
      .clk(clock_processor),
      .rst(global_reset),
      .pc_to_imem(pc_to_imem),
      .insn_from_imem(insn_from_imem),
      .addr_to_dmem(addr_from_proc),
      .store_data_to_dmem(store_data_from_proc),
      .store_we_to_dmem(store_we_from_proc),
      .load_data_from_dmem(load_data_to_proc),
      .halt(datapath_halted)
  );

  // wire up LEDs
  assign LED[0] = global_reset;
  assign LED[1] = clocks_ok;
  assign LED[2] = datapath_halted;
  assign LED[3] = oled_on;

endmodule
