////////////////////////////////////////////////////////////////////////////////
//
// Filename:  rtl/easyaxil.v
// {{{
// Project:  WB2AXIPSP: bus bridges and other odds and ends
//
// Purpose:  Demonstrates a simple AXI-Lite interface.
//
//  This was written in light of my last demonstrator, for which others
//  declared that it was much too complicated to understand.  The goal of
//  this demonstrator is to have logic that's easier to understand, use,
//  and copy as needed.
//
//  Since there are two basic approaches to AXI-lite signaling, both with
//  and without skidbuffers, this example demonstrates both so that the
//  differences can be compared and contrasted.
//
// Creator:  Dan Gisselquist, Ph.D.
//    Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2019-2025, Gisselquist Technology, LLC
// {{{
// This file is part of the WB2AXIP project.
//
// The WB2AXIP project contains free software and gateware, licensed under the
// Apache License, Version 2.0 (the "License").  You may not use this project,
// or this file, except in compliance with the License.  You may obtain a copy
// of the License at
// }}}
//  http://www.apache.org/licenses/LICENSE-2.0
// {{{
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
// License for the specific language governing permissions and limitations
// under the License.
//
////////////////////////////////////////////////////////////////////////////////
//
// Small modifications made by Joe Devietti for CIS 5710:
//  * convert to memory instead of memory-mapped register file
//  * add extra AXIL read interface to support insn memory
//  * use SystemVerilog interfaces to simplify AXIL connections
//
`default_nettype none
// }}}


interface axil_if #(
      parameter int ADDR_WIDTH = 32
    , parameter int DATA_WIDTH = 32
);
  logic                      ARREADY;
  logic                      ARVALID;
  logic [    ADDR_WIDTH-1:0] ARADDR;
  logic [               2:0] ARPROT;

  logic                      RREADY;
  logic                      RVALID;
  logic [    DATA_WIDTH-1:0] RDATA;
  logic [               1:0] RRESP;

  logic                      AWREADY;
  logic                      AWVALID;
  logic [    ADDR_WIDTH-1:0] AWADDR;
  logic [               2:0] AWPROT;

  logic                      WREADY;
  logic                      WVALID;
  logic [    DATA_WIDTH-1:0] WDATA;
  logic [(DATA_WIDTH/8)-1:0] WSTRB;

  logic                      BREADY;
  logic                      BVALID;
  logic [               1:0] BRESP;

  modport manager(
      input ARREADY, RVALID, RDATA, RRESP, AWREADY, WREADY, BVALID, BRESP,
      output ARVALID, ARADDR, ARPROT, RREADY, AWVALID, AWADDR, AWPROT, WVALID, WDATA, WSTRB, BREADY
  );
  modport subord(
      input ARVALID, ARADDR, ARPROT, RREADY, AWVALID, AWADDR, AWPROT, WVALID, WDATA, WSTRB, BREADY,
      output ARREADY, RVALID, RDATA, RRESP, AWREADY, WREADY, BVALID, BRESP
  );
endinterface

// [BR]RESP codes, from Section A 3.4.4 of AXI4 spec
`define RESP_OK 2'b00
`define RESP_SUBORDINATE_ERROR 2'b10
`define RESP_DECODE_ERROR 2'b11

module  EasyAxilMemory #(
    // {{{
    //
    // Size of the AXI-lite bus.  These are fixed, since 1) AXI-lite
    // is fixed at a width of 32-bits by Xilinx def'n, and 2) since
    // we only ever have 4 configuration words.
    parameter [0:0]  OPT_SKIDBUFFER = 1'b0,
    parameter [0:0]  OPT_LOWPOWER = 0,
    parameter NUM_WORDS = 1024
    // }}}
  ) (
    // {{{
    input wire                            ACLK,
    input wire                            ARESETn,
`ifdef RISCV_FORMAL
    input wire [port_ro.DATA_WIDTH-1:0]   random_insn,
    input wire [port_ro.DATA_WIDTH-1:0]   random_data,
`endif
    axil_if.subord port_ro,
    axil_if.subord port_rw
    // }}}
  );

  ////////////////////////////////////////////////////////////////////////
  //
  // Register/wire signal declarations
  // {{{
  ////////////////////////////////////////////////////////////////////////
  //
  localparam  ADDRLSB = $clog2(port_ro.DATA_WIDTH)-3;

  wire  i_reset = !ARESETn;

  wire        axil_write_ready;
  wire  [port_ro.ADDR_WIDTH-ADDRLSB-1:0]  awskd_addr;
  //
  wire  [port_ro.DATA_WIDTH-1:0]  wskd_data;
  wire [port_ro.DATA_WIDTH/8-1:0]  wskd_strb;
  reg        axil_bvalid;
  //
  wire        axil_read_ready;
  wire  [port_ro.ADDR_WIDTH-ADDRLSB-1:0]  arskd_addr;
  reg  [port_ro.DATA_WIDTH-1:0]  axil_read_data;
  reg        axil_read_valid;

  // for T read-only port
  wire        t_axil_read_ready;
  wire  [port_ro.ADDR_WIDTH-ADDRLSB-1:0]  t_arskd_addr;
  reg  [port_ro.DATA_WIDTH-1:0]  t_axil_read_data;
  reg        t_axil_read_valid;

  localparam int AddrLsb = 2;  // since memory elements are 4B
  localparam int AddrMsb = $clog2(NUM_WORDS) + AddrLsb - 1;
`ifndef RISCV_FORMAL
  reg [31:0] mem_array[NUM_WORDS];
`endif

  // }}}
  ////////////////////////////////////////////////////////////////////////
  //
  // AXI-lite signaling
  //
  ////////////////////////////////////////////////////////////////////////
  //
  // {{{

  //
  // Write signaling
  //
  // {{{

  generate if (OPT_SKIDBUFFER)
  begin : SKIDBUFFER_WRITE
    // {{{
    wire  awskd_valid, wskd_valid;

    skidbuffer #(.OPT_OUTREG(0),
        .OPT_LOWPOWER(OPT_LOWPOWER),
        .DW(port_ro.ADDR_WIDTH-ADDRLSB))
    axilawskid(//
      .i_clk(ACLK), .i_reset(i_reset),
      .i_valid(port_rw.AWVALID), .o_ready(port_rw.AWREADY),
      .i_data(port_rw.AWADDR[port_ro.ADDR_WIDTH-1:ADDRLSB]),
      .o_valid(awskd_valid), .i_ready(axil_write_ready),
      .o_data(awskd_addr));

    skidbuffer #(.OPT_OUTREG(0),
        .OPT_LOWPOWER(OPT_LOWPOWER),
        .DW(port_ro.DATA_WIDTH+port_ro.DATA_WIDTH/8))
    axilwskid(//
      .i_clk(ACLK), .i_reset(i_reset),
      .i_valid(port_rw.WVALID), .o_ready(port_rw.WREADY),
      .i_data({ port_rw.WDATA, port_rw.WSTRB }),
      .o_valid(wskd_valid), .i_ready(axil_write_ready),
      .o_data({ wskd_data, wskd_strb }));

    assign  axil_write_ready = awskd_valid && wskd_valid
        && (!port_rw.BVALID || port_rw.BREADY);
    // }}}
  end else begin : SIMPLE_WRITES
    // {{{
    reg  axil_awready;

    initial  axil_awready = 1'b0;
    always @(posedge ACLK) begin
      if (!ARESETn)
        axil_awready <= 1'b0;
      else
        axil_awready <= !axil_awready
          && (port_rw.AWVALID && port_rw.WVALID)
          && (!port_rw.BVALID || port_rw.BREADY);
    end

    assign  port_rw.AWREADY = axil_awready;
    assign  port_rw.WREADY  = axil_awready;

    assign   awskd_addr = port_rw.AWADDR[port_ro.ADDR_WIDTH-1:ADDRLSB];
    assign  wskd_data  = port_rw.WDATA;
    assign  wskd_strb  = port_rw.WSTRB;

    assign  axil_write_ready = axil_awready;
    // }}}
  end endgenerate

  initial  axil_bvalid = 0;
  always @(posedge ACLK) begin
    if (i_reset)
      axil_bvalid <= 0;
    else if (axil_write_ready)
      axil_bvalid <= 1;
    else if (port_rw.BREADY)
      axil_bvalid <= 0;
  end

  assign  port_rw.BVALID = axil_bvalid;
  assign  port_rw.BRESP = 2'b00;
  // }}}

  //
  // Read signaling (S port)
  //
  // {{{

  generate if (OPT_SKIDBUFFER)
  begin : SKIDBUFFER_READ
    // {{{
    wire  arskd_valid;

    skidbuffer #(.OPT_OUTREG(0),
        .OPT_LOWPOWER(OPT_LOWPOWER),
        .DW(port_ro.ADDR_WIDTH-ADDRLSB))
    axilarskid(//
      .i_clk(ACLK), .i_reset(i_reset),
      .i_valid(port_rw.ARVALID), .o_ready(port_rw.ARREADY),
      .i_data(port_rw.ARADDR[port_ro.ADDR_WIDTH-1:ADDRLSB]),
      .o_valid(arskd_valid), .i_ready(axil_read_ready),
      .o_data(arskd_addr));

    assign  axil_read_ready = arskd_valid
        && (!axil_read_valid || port_rw.RREADY);
    // }}}
  end else begin : SIMPLE_READS
    // {{{
    reg  axil_arready;

    always @(*) begin
      axil_arready = !port_rw.RVALID;
    end

    assign  arskd_addr = port_rw.ARADDR[port_ro.ADDR_WIDTH-1:ADDRLSB];
    assign  port_rw.ARREADY = axil_arready;
    assign  axil_read_ready = (port_rw.ARVALID && port_rw.ARREADY);
    // }}}
  end endgenerate

  initial  axil_read_valid = 1'b0;
  always @(posedge ACLK) begin
    if (i_reset)
      axil_read_valid <= 1'b0;
    else if (axil_read_ready)
      axil_read_valid <= 1'b1;
    else if (port_rw.RREADY)
      axil_read_valid <= 1'b0;
  end

  assign  port_rw.RVALID = axil_read_valid;
  assign  port_rw.RDATA  = axil_read_data;
  assign  port_rw.RRESP = 2'b00;
  // }}}

  //
  // Read signaling (T port)
  //
  // {{{

  generate if (OPT_SKIDBUFFER)
  begin : T_SKIDBUFFER_READ
    // {{{
    wire  t_arskd_valid;

    skidbuffer #(.OPT_OUTREG(0),
        .OPT_LOWPOWER(OPT_LOWPOWER),
        .DW(port_ro.ADDR_WIDTH-ADDRLSB))
    axilarskid(//
      .i_clk(ACLK), .i_reset(i_reset),
      .i_valid(port_ro.ARVALID), .o_ready(port_ro.ARREADY),
      .i_data(port_ro.ARADDR[port_ro.ADDR_WIDTH-1:ADDRLSB]),
      .o_valid(t_arskd_valid), .i_ready(t_axil_read_ready),
      .o_data(t_arskd_addr));

    assign  t_axil_read_ready = t_arskd_valid
        && (!t_axil_read_valid || port_ro.RREADY);
    // }}}
  end else begin : T_SIMPLE_READS
    // {{{
    reg  t_axil_arready;

    always @(*) begin
      t_axil_arready = !port_ro.RVALID;
    end

    assign  t_arskd_addr = port_ro.ARADDR[port_ro.ADDR_WIDTH-1:ADDRLSB];
    assign  port_ro.ARREADY = t_axil_arready;
    assign  t_axil_read_ready = (port_ro.ARVALID && port_ro.ARREADY);
    // }}}
  end endgenerate

  initial  t_axil_read_valid = 1'b0;
  always @(posedge ACLK) begin
    if (i_reset)
      t_axil_read_valid <= 1'b0;
    else if (t_axil_read_ready)
      t_axil_read_valid <= 1'b1;
    else if (port_ro.RREADY)
      t_axil_read_valid <= 1'b0;
  end

  assign  port_ro.RVALID = t_axil_read_valid;
  assign  port_ro.RDATA  = t_axil_read_data;
  assign  port_ro.RRESP = 2'b00;
  // }}}

  // }}}
  ////////////////////////////////////////////////////////////////////////
  //
  // AXI-lite register logic
  //
  ////////////////////////////////////////////////////////////////////////
  //
  // {{{

`ifdef RISCV_FORMAL
  assign axil_read_data = random_data;
  assign t_axil_read_data = random_insn == 0 ? random_insn+1 : random_insn;
`else
  always @(posedge ACLK) begin
    if (i_reset)
    begin
    end else if (axil_write_ready)
    begin
      if (wskd_strb[0]) begin
      mem_array[awskd_addr[AddrMsb-2:AddrLsb-2]][7:0] <= wskd_data[7:0];
      end
      if (wskd_strb[1]) begin
      mem_array[awskd_addr[AddrMsb-2:AddrLsb-2]][15:8] <= wskd_data[15:8];
      end
      if (wskd_strb[2]) begin
      mem_array[awskd_addr[AddrMsb-2:AddrLsb-2]][23:16] <= wskd_data[23:16];
      end
      if (wskd_strb[3]) begin
      mem_array[awskd_addr[AddrMsb-2:AddrLsb-2]][31:24] <= wskd_data[31:24];
      end
    end
  end

  initial begin
    axil_read_data = 0;
    t_axil_read_data = 0;
  end
  always @(posedge ACLK) begin
    if (OPT_LOWPOWER && !ARESETn) begin
      axil_read_data <= 0;
    end else if (!port_rw.RVALID || port_rw.RREADY) begin
      // NB: arskd_addr has already chopped off bits [1:0] as RDATA is 32b
      axil_read_data <= mem_array[arskd_addr[AddrMsb-2:AddrLsb-2]];

      if (OPT_LOWPOWER && !axil_read_ready) begin
        axil_read_data <= 0;
      end
    end

    if (OPT_LOWPOWER && !ARESETn) begin
        t_axil_read_data <= 0;
    end else if (!port_ro.RVALID || port_ro.RREADY) begin
      // NB: arskd_addr has already chopped off bits [1:0] as RDATA is 32b
      t_axil_read_data <= mem_array[t_arskd_addr[AddrMsb-2:AddrLsb-2]];

      if (OPT_LOWPOWER && !t_axil_read_ready) begin
          t_axil_read_data <= 0;
      end
    end
  end
`endif

  // Make Verilator happy
  // {{{
  // Verilator lint_off UNUSED
//   wire  unused;
//   assign  unused = &{ 1'b0, port_rw.AWPROT, port_rw.ARPROT,
//       port_rw.ARADDR[ADDRLSB-1:0],
//       port_rw.AWADDR[ADDRLSB-1:0] };
  // Verilator lint_on  UNUSED
  // }}}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
// Formal properties
// {{{
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
`ifdef  FORMAL
  ////////////////////////////////////////////////////////////////////////
  //
  // The AXI-lite control interface
  //
  ////////////////////////////////////////////////////////////////////////
  //
  // {{{
  localparam  F_AXIL_LGDEPTH = 4;
  wire  [F_AXIL_LGDEPTH-1:0]  faxil_rd_outstanding,
          faxil_wr_outstanding,
          faxil_awr_outstanding;

  faxil_slave #(
    // {{{
    .C_AXI_DATA_WIDTH(port_ro.DATA_WIDTH),
    .C_AXI_ADDR_WIDTH(port_ro.ADDR_WIDTH),
    .F_LGDEPTH(F_AXIL_LGDEPTH),
    .F_AXI_MAXWAIT(3),
    .F_AXI_MAXDELAY(3),
    .F_AXI_MAXRSTALL(5),
    .F_OPT_COVER_BURST(4)
    // }}}
  ) faxil(
    // {{{
    .i_clk(ACLK), .i_axi_reset_n(ARESETn),
    //
    .i_axi_awvalid(port_rw.AWVALID),
    .i_axi_awready(port_rw.AWREADY),
    .i_axi_awaddr( port_rw.AWADDR),
    .i_axi_awprot( port_rw.AWPROT),
    //
    .i_axi_wvalid(port_rw.WVALID),
    .i_axi_wready(port_rw.WREADY),
    .i_axi_wdata( port_rw.WDATA),
    .i_axi_wstrb( port_rw.WSTRB),
    //
    .i_axi_bvalid(port_rw.BVALID),
    .i_axi_bready(port_rw.BREADY),
    .i_axi_bresp( port_rw.BRESP),
    //
    .i_axi_arvalid(port_rw.ARVALID),
    .i_axi_arready(port_rw.ARREADY),
    .i_axi_araddr( port_rw.ARADDR),
    .i_axi_arprot( port_rw.ARPROT),
    //
    .i_axi_rvalid(port_rw.RVALID),
    .i_axi_rready(port_rw.RREADY),
    .i_axi_rdata( port_rw.RDATA),
    .i_axi_rresp( port_rw.RRESP),
    //
    .f_axi_rd_outstanding(faxil_rd_outstanding),
    .f_axi_wr_outstanding(faxil_wr_outstanding),
    .f_axi_awr_outstanding(faxil_awr_outstanding)
    // }}}
    );

  always @(*) begin
    if (OPT_SKIDBUFFER)
    begin
      assert(faxil_awr_outstanding== (port_rw.BVALID ? 1:0)
        +(port_rw.AWREADY ? 0:1));
      assert(faxil_wr_outstanding == (port_rw.BVALID ? 1:0)
        +(port_rw.WREADY ? 0:1));

      assert(faxil_rd_outstanding == (port_rw.RVALID ? 1:0)
        +(port_rw.ARREADY ? 0:1));
    end else begin
      assert(faxil_wr_outstanding == (port_rw.BVALID ? 1:0));
      assert(faxil_awr_outstanding == faxil_wr_outstanding);

      assert(faxil_rd_outstanding == (port_rw.RVALID ? 1:0));
    end
  end

  //
  // Check that our low-power only logic works by verifying that anytime
  // port_rw.RVALID is inactive, then the outgoing data is also zero.
  //
  always @(*)
  if (OPT_LOWPOWER && !port_rw.RVALID)
    assert(port_rw.RDATA == 0);
  // }}}
  ////////////////////////////////////////////////////////////////////////
  //
  // Register return checking
  // {{{
  ////////////////////////////////////////////////////////////////////////
  //
  //
`define  CHECK_REGISTERS
`ifdef  CHECK_REGISTERS
  faxil_register #(
    // {{{
    .AW(port_ro.ADDR_WIDTH),
    .DW(port_ro.DATA_WIDTH),
    .ADDR(0)
    // }}}
  ) fr0 (
    // {{{
    .S_AXI_ACLK(ACLK),
    .S_AXI_ARESETN(ARESETn),
    .S_AXIL_AWW(axil_write_ready),
    .S_AXIL_AWADDR({ awskd_addr, {(ADDRLSB){1'b0}} }),
    .S_AXIL_WDATA(wskd_data),
    .S_AXIL_WSTRB(wskd_strb),
    .S_AXIL_BVALID(port_rw.BVALID),
    .S_AXIL_AR(axil_read_ready),
    .S_AXIL_ARADDR({ arskd_addr, {(ADDRLSB){1'b0}} }),
    .S_AXIL_RVALID(port_rw.RVALID),
    .S_AXIL_RDATA(port_rw.RDATA),
    .i_register(r0)
    // }}}
  );

  faxil_register #(
    // {{{
    .AW(port_ro.ADDR_WIDTH),
    .DW(port_ro.DATA_WIDTH),
    .ADDR(4)
    // }}}
  ) fr1 (
    // {{{
    .S_AXI_ACLK(ACLK),
    .S_AXI_ARESETN(ARESETn),
    .S_AXIL_AWW(axil_write_ready),
    .S_AXIL_AWADDR({ awskd_addr, {(ADDRLSB){1'b0}} }),
    .S_AXIL_WDATA(wskd_data),
    .S_AXIL_WSTRB(wskd_strb),
    .S_AXIL_BVALID(port_rw.BVALID),
    .S_AXIL_AR(axil_read_ready),
    .S_AXIL_ARADDR({ arskd_addr, {(ADDRLSB){1'b0}} }),
    .S_AXIL_RVALID(port_rw.RVALID),
    .S_AXIL_RDATA(port_rw.RDATA),
    .i_register(r1)
    // }}}
  );

  faxil_register #(
    // {{{
    .AW(port_ro.ADDR_WIDTH),
    .DW(port_ro.DATA_WIDTH),
    .ADDR(8)
    // }}}
  ) fr2 (
    // {{{
    .S_AXI_ACLK(ACLK),
    .S_AXI_ARESETN(ARESETn),
    .S_AXIL_AWW(axil_write_ready),
    .S_AXIL_AWADDR({ awskd_addr, {(ADDRLSB){1'b0}} }),
    .S_AXIL_WDATA(wskd_data),
    .S_AXIL_WSTRB(wskd_strb),
    .S_AXIL_BVALID(port_rw.BVALID),
    .S_AXIL_AR(axil_read_ready),
    .S_AXIL_ARADDR({ arskd_addr, {(ADDRLSB){1'b0}} }),
    .S_AXIL_RVALID(port_rw.RVALID),
    .S_AXIL_RDATA(port_rw.RDATA),
    .i_register(r2)
    // }}}
  );

  faxil_register #(
    // {{{
    .AW(port_ro.ADDR_WIDTH),
    .DW(port_ro.DATA_WIDTH),
    .ADDR(12)
    // }}}
  ) fr3 (
    // {{{
    .S_AXI_ACLK(ACLK),
    .S_AXI_ARESETN(ARESETn),
    .S_AXIL_AWW(axil_write_ready),
    .S_AXIL_AWADDR({ awskd_addr, {(ADDRLSB){1'b0}} }),
    .S_AXIL_WDATA(wskd_data),
    .S_AXIL_WSTRB(wskd_strb),
    .S_AXIL_BVALID(port_rw.BVALID),
    .S_AXIL_AR(axil_read_ready),
    .S_AXIL_ARADDR({ arskd_addr, {(ADDRLSB){1'b0}} }),
    .S_AXIL_RVALID(port_rw.RVALID),
    .S_AXIL_RDATA(port_rw.RDATA),
    .i_register(r3)
    // }}}
  );
`endif
  // }}}
  ////////////////////////////////////////////////////////////////////////
  //
  // Cover checks
  //
  ////////////////////////////////////////////////////////////////////////
  //
  // {{{

  // While there are already cover properties in the formal property
  // set above, you'll probably still want to cover something
  // application specific here

  // }}}
`endif
// }}}
endmodule

////////////////////////////////////////////////////////////////////////////////
//
// Filename:  rtl/skidbuffer.v
// {{{
// Project:  WB2AXIPSP: bus bridges and other odds and ends
//
// Purpose:  A basic SKID buffer.
// {{{
//  Skid buffers are required for high throughput AXI code, since the AXI
//  specification requires that all outputs be registered.  This means
//  that, if there are any stall conditions calculated, it will take a clock
//  cycle before the stall can be propagated up stream.  This means that
//  the data will need to be buffered for a cycle until the stall signal
//  can make it to the output.
//
//  Handling that buffer is the purpose of this core.
//
//  On one end of this core, you have the i_valid and i_data inputs to
//  connect to your bus interface.  There's also a registered o_ready
//  signal to signal stalls for the bus interface.
//
//  The other end of the core has the same basic interface, but it isn't
//  registered.  This allows you to interact with the bus interfaces
//  as though they were combinatorial logic, by interacting with this half
//  of the core.
//
//  If at any time the incoming !stall signal, i_ready, signals a stall,
//  the incoming data is placed into a buffer.  Internally, that buffer
//  is held in r_data with the r_valid flag used to indicate that valid
//  data is within it.
// }}}
// Parameters:
// {{{
//  DW or data width
//    In order to make this core generic, the width of the data in the
//    skid buffer is parameterized
//
//  OPT_LOWPOWER
//    Forces both o_data and r_data to zero if the respective *VALID
//    signal is also low.  While this costs extra logic, it can also
//    be used to guarantee that any unused values aren't toggling and
//    therefore unnecessarily using power.
//
//    This excess toggling can be particularly problematic if the
//    bus signals have a high fanout rate, or a long signal path
//    across an FPGA.
//
//  OPT_OUTREG
//    Causes the outputs to be registered
//
//  OPT_PASSTHROUGH
//    Turns the skid buffer into a passthrough.  Used for formal
//    verification only.
// }}}
// Creator:  Dan Gisselquist, Ph.D.
//    Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2019-2025, Gisselquist Technology, LLC
// {{{
// This file is part of the WB2AXIP project.
//
// The WB2AXIP project contains free software and gateware, licensed under the
// Apache License, Version 2.0 (the "License").  You may not use this project,
// or this file, except in compliance with the License.  You may obtain a copy
// of the License at
// }}}
//  http://www.apache.org/licenses/LICENSE-2.0
// {{{
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
// License for the specific language governing permissions and limitations
// under the License.
//
////////////////////////////////////////////////////////////////////////////////
//
`default_nettype none
// }}}
module skidbuffer #(
    // {{{
    parameter  [0:0]  OPT_LOWPOWER = 0,
    parameter  [0:0]  OPT_OUTREG = 1,
    //
    parameter  [0:0]  OPT_PASSTHROUGH = 0,
    parameter    DW = 8,
    parameter  [0:0]  OPT_INITIAL = 1'b1
    // }}}
  ) (
    // {{{
    input  wire      i_clk, i_reset,
    input  wire      i_valid,
    output  wire      o_ready,
    input  wire  [DW-1:0]  i_data,
    output  wire      o_valid,
    input  wire      i_ready,
    output  reg  [DW-1:0]  o_data
    // }}}
  );

  wire  [DW-1:0]  w_data;

  generate if (OPT_PASSTHROUGH)
  begin : PASSTHROUGH
    // {{{
    assign  { o_valid, o_ready } = { i_valid, i_ready };

    always @(*)
    if (!i_valid && OPT_LOWPOWER)
      o_data = 0;
    else
      o_data = i_data;

    assign  w_data = 0;

    // Keep Verilator happy
    // Verilator lint_off UNUSED
    // {{{
    wire  unused_passthrough;
    assign  unused_passthrough = &{ 1'b0, i_clk, i_reset };
    // }}}
    // Verilator lint_on  UNUSED
    // }}}
  end else begin : LOGIC
    // We'll start with skid buffer itself
    // {{{
    reg      r_valid;
    reg  [DW-1:0]  r_data;

    // r_valid
    // {{{
    initial if (OPT_INITIAL) r_valid = 0;
    always @(posedge i_clk)
    if (i_reset)
      r_valid <= 0;
    else if ((i_valid && o_ready) && (o_valid && !i_ready))
      // We have incoming data, but the output is stalled
      r_valid <= 1;
    else if (i_ready)
      r_valid <= 0;
    // }}}

    // r_data
    // {{{
    initial if (OPT_INITIAL) r_data = 0;
    always @(posedge i_clk)
    if (OPT_LOWPOWER && i_reset)
      r_data <= 0;
    else if (OPT_LOWPOWER && (!o_valid || i_ready))
      r_data <= 0;
    else if ((!OPT_LOWPOWER || !OPT_OUTREG || i_valid) && o_ready)
      r_data <= i_data;

    assign  w_data = r_data;
    // }}}

    // o_ready
    // {{{
    assign o_ready = !r_valid;
    // }}}

    //
    // And then move on to the output port
    //
    if (!OPT_OUTREG)
    begin : NET_OUTPUT
      // Outputs are combinatorially determined from inputs
      // {{{
      // o_valid
      // {{{
      assign  o_valid = !i_reset && (i_valid || r_valid);
      // }}}

      // o_data
      // {{{
      always @(*)
      if (r_valid)
        o_data = r_data;
      else if (!OPT_LOWPOWER || i_valid)
        o_data = i_data;
      else
        o_data = 0;
      // }}}
      // }}}
    end else begin : REG_OUTPUT
      // Register our outputs
      // {{{
      // o_valid
      // {{{
      reg  ro_valid;

      initial if (OPT_INITIAL) ro_valid = 0;
      always @(posedge i_clk)
      if (i_reset)
        ro_valid <= 0;
      else if (!o_valid || i_ready)
        ro_valid <= (i_valid || r_valid);

      assign  o_valid = ro_valid;
      // }}}

      // o_data
      // {{{
      initial if (OPT_INITIAL) o_data = 0;
      always @(posedge i_clk)
      if (OPT_LOWPOWER && i_reset)
        o_data <= 0;
      else if (!o_valid || i_ready)
      begin

        if (r_valid)
          o_data <= r_data;
        else if (!OPT_LOWPOWER || i_valid)
          o_data <= i_data;
        else
          o_data <= 0;
      end
      // }}}

      // }}}
    end
    // }}}
  end endgenerate

  // Keep Verilator happy
  // {{{
  // verilator coverage_off
  // Verilator lint_off UNUSED
  wire  unused;
  assign  unused = &{ 1'b0, w_data };
  // Verilator lint_on  UNUSED
  // verilator coverage_on
  // }}}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
// Formal properties
// {{{
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
`ifdef  FORMAL
`ifdef  SKIDBUFFER
`define  ASSUME  assume
`else
`define  ASSUME  assert
`endif

  reg  f_past_valid;

  initial  f_past_valid = 0;
  always @(posedge i_clk)
    f_past_valid <= 1;

  always @(*)
  if (!f_past_valid)
    assume(i_reset);

  ////////////////////////////////////////////////////////////////////////
  //
  // Incoming stream properties / assumptions
  // {{{
  ////////////////////////////////////////////////////////////////////////
  //
  always @(posedge i_clk)
  if (!f_past_valid)
  begin
    `ASSUME(!i_valid || !OPT_INITIAL);
  end else if ($past(i_valid && !o_ready && !i_reset) && !i_reset)
    `ASSUME(i_valid && $stable(i_data));

`ifdef  VERIFIC
`define  FORMAL_VERIFIC
  // Reset properties
  property RESET_CLEARS_IVALID;
    @(posedge i_clk) i_reset |=> !i_valid;
  endproperty

  property IDATA_HELD_WHEN_NOT_READY;
    @(posedge i_clk) disable iff (i_reset)
    i_valid && !o_ready |=> i_valid && $stable(i_data);
  endproperty

`ifdef  SKIDBUFFER
  assume  property (IDATA_HELD_WHEN_NOT_READY);
`else
  assert  property (IDATA_HELD_WHEN_NOT_READY);
`endif
`endif
  // }}}
  ////////////////////////////////////////////////////////////////////////
  //
  // Outgoing stream properties / assumptions
  // {{{
  ////////////////////////////////////////////////////////////////////////
  //

  generate if (!OPT_PASSTHROUGH)
  begin

    always @(posedge i_clk)
    if (!f_past_valid) // || $past(i_reset))
    begin
      // Following any reset, valid must be deasserted
      assert(!o_valid || !OPT_INITIAL);
    end else if ($past(o_valid && !i_ready && !i_reset) && !i_reset)
      // Following any stall, valid must remain high and
      // data must be preserved
      assert(o_valid && $stable(o_data));

  end endgenerate
  // }}}
  ////////////////////////////////////////////////////////////////////////
  //
  // Other properties
  // {{{
  ////////////////////////////////////////////////////////////////////////
  //
  //
  generate if (!OPT_PASSTHROUGH)
  begin
    // Rule #1:
    //  If registered, then following any reset we should be
    //  ready for a new request
    // {{{
    always @(posedge i_clk)
    if (f_past_valid && $past(OPT_OUTREG && i_reset))
      assert(o_ready);
    // }}}

    // Rule #2:
    //  All incoming data must either go directly to the
    //  output port, or into the skid buffer
    // {{{
`ifndef  VERIFIC
    always @(posedge i_clk)
    if (f_past_valid && !$past(i_reset) && $past(i_valid && o_ready
      && (!OPT_OUTREG || o_valid) && !i_ready))
      assert(!o_ready && w_data == $past(i_data));
`else
    assert property (@(posedge i_clk)
      disable iff (i_reset)
      (i_valid && o_ready
        && (!OPT_OUTREG || o_valid) && !i_ready)
        |=> (!o_ready && w_data == $past(i_data)));
`endif
    // }}}

    // Rule #3:
    //  After the last transaction, o_valid should become idle
    // {{{
    if (!OPT_OUTREG)
    begin
      // {{{
      always @(posedge i_clk)
      if (f_past_valid && !$past(i_reset) && !i_reset
          && $past(i_ready))
      begin
        assert(o_valid == i_valid);
        assert(!i_valid || (o_data == i_data));
      end
      // }}}
    end else begin
      // {{{
      always @(posedge i_clk)
      if (f_past_valid && !$past(i_reset))
      begin
        if ($past(i_valid && o_ready))
          assert(o_valid);

        if ($past(!i_valid && o_ready && i_ready))
          assert(!o_valid);
      end
      // }}}
    end
    // }}}

    // Rule #4
    //  Same thing, but this time for o_ready
    // {{{
    always @(posedge i_clk)
    if (f_past_valid && $past(!o_ready && i_ready))
      assert(o_ready);
    // }}}

    // If OPT_LOWPOWER is set, o_data and w_data both need to be
    // zero any time !o_valid or !r_valid respectively
    // {{{
    if (OPT_LOWPOWER)
    begin
      always @(*)
      if ((OPT_OUTREG || !i_reset) && !o_valid)
        assert(o_data == 0);

      always @(*)
      if (o_ready)
        assert(w_data == 0);

    end
    // }}}
  end endgenerate
  // }}}

  always @(posedge i_clk)
  if (!OPT_PASSTHROUGH && !i_reset && !o_ready)
    assert(o_valid);

  ////////////////////////////////////////////////////////////////////////
  //
  // Cover checks
  // {{{
  ////////////////////////////////////////////////////////////////////////
  //
  //
`ifdef  SKIDBUFFER
  generate if (!OPT_PASSTHROUGH)
  begin
    reg  f_changed_data;

    initial  f_changed_data = 0;
    always @(posedge i_clk)
    if (i_reset)
      f_changed_data <= 1;
    else if (i_valid && $past(!i_valid || o_ready))
    begin
      if (i_data != $past(i_data + 1))
        f_changed_data <= 0;
    end else if (!i_valid && i_data != 0)
      f_changed_data <= 0;


`ifndef  VERIFIC
    reg  [3:0]  cvr_steps, cvr_hold;

    always @(posedge i_clk)
    if (i_reset)
    begin
      cvr_steps <= 0;
      cvr_hold  <= 0;
    end else begin
      cvr_steps <= cvr_steps + 1;
      cvr_hold  <= cvr_hold  + 1;
      case(cvr_steps)
       0: if (o_valid || i_valid)
        cvr_steps <= 0;
       1: if (!i_valid || !i_ready)
        cvr_steps <= 0;
       2: if (!i_valid || !i_ready)
        cvr_steps <= 0;
       3: if (!i_valid || !i_ready)
        cvr_steps <= 0;
       4: if (!i_valid ||  i_ready)
        cvr_steps <= 0;
       5: if (!i_valid || !i_ready)
        cvr_steps <= 0;
       6: if (!i_valid || !i_ready)
        cvr_steps <= 0;
       7: if (!i_valid ||  i_ready)
        cvr_steps <= 0;
       8: if (!i_valid ||  i_ready)
        cvr_steps <= 0;
       9: if (!i_valid || !i_ready)
        cvr_steps <= 0;
      10: if (!i_valid || !i_ready)
        cvr_steps <= 0;
      11: if (!i_valid || !i_ready)
        cvr_steps <= 0;
      12: begin
        cvr_steps <= cvr_steps;
        cover(!o_valid && !i_valid && f_changed_data);
        if (!o_valid || !i_ready)
          cvr_steps <= 0;
        else
          cvr_hold <= cvr_hold + 1;
        end
      default: assert(0);
      endcase
    end

`else
    // Cover test
    cover property (@(posedge i_clk)
      disable iff (i_reset)
      (!o_valid && !i_valid)
      ##1 i_valid &&  i_ready [*3]
      ##1 i_valid && !i_ready
      ##1 i_valid &&  i_ready [*2]
      ##1 i_valid && !i_ready [*2]
      ##1 i_valid &&  i_ready [*3]
      // Wait for the design to clear
      ##1 o_valid && i_ready [*0:5]
      ##1 (!o_valid && !i_valid && f_changed_data));
`endif
  end endgenerate
`endif  // SKIDBUFFER
  // }}}
`endif
// }}}
endmodule

`ifndef SYNTHESIS
/** This is used for testing AxilMemory in simulation, since Verilator doesn't allow
 SV interfaces in top-level modules. Currently, only port_ro is connected. */
module AxilMemoryTester #(
    // these parameters are for the AXIL interface
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
) (
    input wire ACLK,
    input wire ARESETn,

    input wire                       MEM_ARVALID,
    output  wire                    MEM_ARREADY,
    input wire  [    ADDR_WIDTH-1:0] MEM_ARADDR,
    input wire  [               2:0] MEM_ARPROT,
    output  wire                    MEM_RVALID,
    input wire                       MEM_RREADY,
    output  wire [  ADDR_WIDTH-1:0] MEM_RDATA,
    output  wire [             1:0] MEM_RRESP,
    input wire                       MEM_AWVALID,
    output  wire                    MEM_AWREADY,
    input wire  [    ADDR_WIDTH-1:0] MEM_AWADDR,
    input wire  [               2:0] MEM_AWPROT,
    input wire                       MEM_WVALID,
    output  wire                    MEM_WREADY,
    input wire  [    DATA_WIDTH-1:0] MEM_WDATA,
    input wire  [(DATA_WIDTH/8)-1:0] MEM_WSTRB,
    output  wire                    MEM_BVALID,
    input wire                       MEM_BREADY,
    output  wire [             1:0] MEM_BRESP
);

   axil_if #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
   ) mem_axil ();
   assign mem_axil.manager.ARVALID = MEM_ARVALID;
   assign MEM_ARREADY = mem_axil.manager.ARREADY;
   assign mem_axil.manager.ARADDR = MEM_ARADDR;
   assign mem_axil.manager.ARPROT = MEM_ARPROT;
   assign MEM_RVALID = mem_axil.manager.RVALID;
   assign mem_axil.manager.RREADY = MEM_RREADY;
   assign MEM_RRESP = mem_axil.manager.RRESP;
   assign MEM_RDATA = mem_axil.manager.RDATA;
   assign mem_axil.manager.AWVALID = MEM_AWVALID;
   assign MEM_AWREADY = mem_axil.manager.AWREADY;
   assign mem_axil.manager.AWADDR = MEM_AWADDR;
   assign mem_axil.manager.AWPROT = MEM_AWPROT;
   assign mem_axil.manager.WVALID = MEM_WVALID;
   assign MEM_WREADY = mem_axil.manager.WREADY;
   assign mem_axil.manager.WDATA = MEM_WDATA;
   assign mem_axil.manager.WSTRB = MEM_WSTRB;
   assign MEM_BVALID = mem_axil.manager.BVALID;
   assign mem_axil.manager.BREADY = MEM_BREADY;
   assign MEM_BRESP = mem_axil.manager.BRESP;

   axil_if #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
   ) mem_unused ();
   assign mem_unused.RREADY = 1;
   assign mem_unused.BREADY = 1;
   
  EasyAxilMemory #(
     .OPT_SKIDBUFFER(1),
     .OPT_LOWPOWER(0),
     .NUM_WORDS(8192)
  ) the_mem (
        .ACLK(ACLK),
        .ARESETn(ARESETn),
        .port_ro(mem_axil.subord),
        .port_rw(mem_unused.subord)
  );

endmodule // AxilMemoryTester
`endif // !SYNTHESIS
