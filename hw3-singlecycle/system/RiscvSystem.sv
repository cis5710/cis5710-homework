`timescale 1ns / 1ns

module RiscvSystem(/* Clock */
                  input wire        CLOCK_100MHz,

                  /* VGA ports */
                  // output wire       VGA_HSYNCH,
                  // output wire       VGA_VSYNCH,
                  // output wire [3:0] VGA_OUT_RED,
                  // output wire [3:0] VGA_OUT_GREEN,
                  // output wire [3:0] VGA_OUT_BLUE,

		  // LEDs, buttons, switches
                  output wire [7:0] LED,
		  input wire        BTN_U,
                  input wire        BTN_D,
                  input wire        BTN_L,
                  input wire        BTN_R,
                  input wire        BTN_C,
                  input wire [7:0]  SWITCH
		  );
   
   // CLOCK MANAGEMENT
  //  wire          GLOBAL_WE;    // global we, toggled to build a single-step clock
   wire          GLOBAL_RST = SWITCH[0]; // NB: ZedBoard switches are active-low
   wire          clocks_ok;
   wire          clock_processor; // processor clock
   wire          clock_vga; // VGA clock: 25 MHz
   wire          clock_vga_inv; // inverted version of clock_vga
   wire clock_mem;

   // Mixed-Mode Clock Manager, see mmcm.v for details
  clk_wiz_0_clk_wiz mmcm (
  // Clock out ports
  .clk_proc(clock_processor),
  .clk_mem(clock_mem),
  // Status and control signals
  .reset(GLOBAL_RST),
  .locked(clocks_ok),
 // Clock in ports
  .clk_in1(CLOCK_100MHz)
  );
   
  // //  /* Generate "single-step clock" by one-pulsing the global
  // //   write-enable. The one-pulse circuitry cleans up the signal edges
  // //   for us.
  // //   TODO: single-step clock is broken
  // //    */
  // //  wire          global_we_pulse;
  // //  one_pulse clk_pulse(.clk( clock_processor ), 
  // //                      .rst( 1'b0 ),
  // //                      .btn( 1'b0 ), // FPGA buttons are active-low
  // //                      .pulse_out( global_we_pulse ));
   
  // //  /* Clean up trailing edges of the GLOBAL_WE switch input */
  // //  wire          global_we_switch;
   
  // //  Nbit_reg #(1, 0) gwe_cleaner(.in(SWITCH[0]), // FPGA switches are active-low
  // //                               .out( global_we_switch ), 
  // //                               .clk( clock_processor ), 
  // //                               .we( 1'b1 ), 
  // //                               .gwe( 1'b1 ), 
  // //                               .rst( GLOBAL_RST ));
   
   
  // //  wire          i1re, i2re, dre, gwe_out;
  // //  lc4_we_gen we_gen(.clk( clock_processor ),
  // //                    .i1re( i1re ),
  // //                    .i2re( i2re ),
  // //                    .dre( dre ),
  // //                    .gwe( gwe_out ));
   
   
  //  assign GLOBAL_WE = clocks_ok;
   
   
   
  //  /* Clean up the edges of the manual reset signal. Only the trailing
  //   edge should really matter, though. 
  //   TODO: fix the manual reset signal
  //   */
  //  wire          rst_btn;
  //  Nbit_reg #(1, 0) reset_cleaner(.in( 1'b0 ),
	// 			  .out( rst_btn ), 
  //                                 .clk( clock_processor ), 
  //                                 .we( 1'b1 ), 
  //                                 .gwe( 1'b1 ), 
  //                                 .rst( 1'b0 ));
  //  assign GLOBAL_RST = rst_btn;

   assign LED[0] = ~GLOBAL_RST;
  //  assign LED[7:1] = proc_leds[7:1];

  // wire [31:0] pc, insn, mem_data_addr, mem_data_loaded_value, mem_data_to_write;
  // wire [3:0] mem_data_we;

  wire reset_processor = ~clocks_ok | GLOBAL_RST;

  RiscvProcessor proc (
    .clock_proc(clock_processor),
    .clock_mem(clock_mem),
    .rst(reset_processor),
    .halt(LED[1])
  );


   // MEMORY INTERFACE
   // INSTRUCTIONS
  //  wire [15:0]   imem1_addr, imem2_addr;
  //  wire [15:0]   imem1_out, imem2_out;
  //  // DATA MEMORY
  //  wire [15:0]   dmem_addr;
  //  wire [15:0]   dmem_in;
  //  wire          dmem_we;
  //  wire [15:0]   dmem_mout;
   
  //  // DEVICE INTERFACES
  //  // P/S2 KEYBOARD
  //  wire          read_kbsr = ~dmem_we & (dmem_addr == 16'hFE00);
  //  wire          kbsr;
  //  wire          read_kbdr = ~dmem_we & (dmem_addr == 16'hFE02);
  //  wire [7:0]    kbdr;
  //  // TIMER
  //  wire          read_tsr = ~dmem_we & (dmem_addr == 16'hFE08);
  //  wire          write_tir = dmem_we & (dmem_addr == 16'hFE0A);
  //  wire          tsr;
  //  // VGA
  //  wire [13:0]   vga_addr;
  //  wire [15:0]   vga_data;
   
  //  // MEMORY/DEVICE MUX
  //  wire [15:0]   dmem_out = dmem_we ? 16'h0000 :
  //                (dmem_addr == 16'hFE00) ? {kbsr, {15{1'b0}}} :
  //                (dmem_addr == 16'hFE02) ? {8'h00, kbdr} :
  //                (dmem_addr == 16'hFE08) ? {tsr, {15{1'b0}}} :
  //                (dmem_addr < 16'hFE00) ? dmem_mout : 16'h0000;
   
   
   // PROCESSOR
   // NB: we leave the testing outputs disconnected

  //  wire [7:0]    proc_leds; 
  //  lc4_processor proc_inst(.clk( clock_processor ),
  //                          .rst(GLOBAL_RST),
  //                          .gwe(GLOBAL_WE),
  //                          .o_cur_pc(imem1_addr),
  //                          .i_cur_insn(imem1_out),
  //                          .o_dmem_addr(dmem_addr),
  //                          .i_cur_dmem_data(dmem_out),
  //                          .o_dmem_we(dmem_we),
  //                          .o_dmem_towrite(dmem_in),
  //                          .switch_data( {SWITCH[7:1], 1'b0} ),
  //                          .led_data( proc_leds )
  //                          );
   
  //  assign imem2_addr = 16'd0;
   
  //  // MEMORY
   
  //  // The memory for bit-mapped video and other I/O. Port a is a read-only
  //  // port for the VGA video. Port b is a read-write port for memory-mapped
  //  // I/O data. The addresses used in the memory are only 14 bits because the
  //  // most-significant bits are always 11. Port b is accessed in the memory
  //  // stage of a pipeline; memory-mapped I/O is implemented by executing loads
  //  // and stores to I/O memory.          

  //  lc4_memory memory (.idclk(clock_processor),
  //                     .i1re(i1re),
  //                     .i2re(i2re),
  //                     .dre(dre),
  //                     .gwe(GLOBAL_WE),
  //                     .rst(GLOBAL_RST),
  //                     .i1addr(imem1_addr),
  //                     .i2addr(imem2_addr),
  //                     .i1out(imem1_out),
  //                     .i2out(imem2_out),
  //                     .daddr(dmem_addr),
  //                     .din(dmem_in),
  //                     .dout(dmem_mout),
  //                     .dwe(dmem_we),
  //                     .vaddr({2'b11, vga_addr}),
  //                     .vout(vga_data),     //VGA data out
  //                     .vclk(clock_vga)
  //                     ); 
   
   
  //  // PS/2 KEYBOARD CONTROLLER
  //  fake_pb_kbd fake_kbd_inst( .read_kbsr( read_kbsr ),
  //                             .kbsr( kbsr ), 
  //                             .read_kbdr( read_kbdr ),
  //                             .kbdr( kbdr ),
	// 		      .proc_clk( clock_processor ),
	// 		      .reset( GLOBAL_RST ),
	// 		      .ZED_PB( {BTN_U, BTN_L, BTN_D, BTN_R, BTN_C} ));
   
   
  //  // Timer device
  //  timer_device timer(.write_interval( write_tir ),
  //                     .interval_in( dmem_in ),
  //                     .read_status( read_tsr ),
  //                     .status_out ( tsr ),
  //                     .GWE(GLOBAL_WE),
  //                     .RST(GLOBAL_RST),
  //                     .CLK(clock_processor));
   
  //  // vga_controller handles the VGA signals.
  //  vga_controller vga_cntrl_inst(.PIXEL_CLK(clock_vga_inv),
  //                                .RESET(GLOBAL_RST),
  //                                .VGA_HSYNCH(VGA_HSYNCH),
  //                                .VGA_VSYNCH(VGA_VSYNCH),
  //                                .VGA_OUT_RED(VGA_OUT_RED),
  //                                .VGA_OUT_GREEN(VGA_OUT_GREEN),
  //                                .VGA_OUT_BLUE(VGA_OUT_BLUE),
  //                                .VGA_ADDR(vga_addr),
  //                                .VGA_DATA(vga_data[14:0]));
   
endmodule
