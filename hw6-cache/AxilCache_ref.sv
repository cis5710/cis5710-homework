`timescale 1ns / 1ns

// REFERENCE CODE

`define ADDR_WIDTH 32
`define DATA_WIDTH 32

/** encode a 1-hot signal into binary */
module encoder #(
    parameter int INPUT_WIDTH
) (
    input  logic [INPUT_WIDTH-1:0] one_hot,
    output logic [1 == INPUT_WIDTH ? 0 : $clog2(INPUT_WIDTH)-1:0] binary
);
    always_comb begin
`ifndef SYNTHESIS
        assert (1 == INPUT_WIDTH || $onehot(one_hot)) else $error("Input is not 1-hot encoded!");
`endif
        binary = '0; // Default value
        for (int i = 0; i < INPUT_WIDTH; i++) begin
            if (one_hot[i]) begin
                binary = i[1 == INPUT_WIDTH ? 0 : $clog2(INPUT_WIDTH)-1:0];
            end
        end
    end
endmodule

interface axi_if #(
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

/** This is a simple memory that uses the AXI-Lite interface. */
module AxilMemory #(
    parameter int NUM_WORDS = 1024
) (
    input wire ACLK,
    input wire ARESETn,
`ifdef RISCV_FORMAL
    input wire [`DATA_WIDTH] random_insn,
    input wire [`DATA_WIDTH] random_data,
`endif
    axi_if.subord port_ro,
    axi_if.subord port_rw
);
  localparam bit True = 1'b1;
  localparam bit False = 1'b0;
  localparam int AddrLsb = 2;  // since memory elements are 4B
  localparam int AddrMsb = $clog2(NUM_WORDS) + AddrLsb - 1;

`ifndef RISCV_FORMAL
  logic [31:0] mem_array[NUM_WORDS];
`endif
  logic [31:0] ro_araddr;
  logic ro_araddr_valid;

`ifdef SYNTHESIS
  initial begin
    $readmemh("mem_initial_contents.hex",mem_array);
  end
`endif

  assign port_ro.RRESP = `RESP_OK;
  assign port_ro.BRESP = `RESP_OK;
  assign port_rw.RRESP = `RESP_OK;
  assign port_rw.BRESP = `RESP_OK;

  always_ff @(posedge ACLK) begin
    if (!ARESETn) begin
      ro_araddr <= 0;
      ro_araddr_valid <= False;

      port_ro.ARREADY <= True;
      port_ro.AWREADY <= False;
      port_ro.WREADY  <= False;
      port_ro.RVALID <= False;
      port_ro.RDATA <= 0;

      port_rw.ARREADY <= True;
      port_rw.AWREADY <= True;
      port_rw.WREADY  <= True;
      port_rw.RVALID <= False;
      port_rw.RDATA <= 0;
    end else begin

      // port_ro is read-only

      if (ro_araddr_valid) begin
        // there is a buffered read request
        if (port_ro.RREADY) begin
          // manager accepted our response, we generate next response
          port_ro.RVALID <= True;
`ifdef RISCV_FORMAL
          port_ro.RDATA <= random_insn;
`else
          port_ro.RDATA  <= mem_array[ro_araddr[AddrMsb:AddrLsb]];
`endif
          ro_araddr <= 0;
          ro_araddr_valid <= False;
          port_ro.ARREADY <= True;
        end
      end else if (port_ro.ARVALID && port_ro.ARREADY) begin
        // we have accepted a read request
        if (port_ro.RVALID && !port_ro.RREADY) begin
          // We have sent a response but manager has not accepted it. Buffer the new read request.
          ro_araddr <= port_ro.ARADDR;
          ro_araddr_valid <= True;
          port_ro.ARREADY <= False;
        end else begin
          // We have sent a response and manager has accepted it. Or, we were not already sending a response.
          // Either way, send a response to the request we just accepted.
          port_ro.RVALID <= True;
`ifdef RISCV_FORMAL
          port_ro.RDATA <= random_insn;
`else
          port_ro.RDATA  <= mem_array[port_ro.ARADDR[AddrMsb:AddrLsb]];
`endif
        end
      end else if (port_ro.RVALID && port_ro.RREADY) begin
        // No incoming request. We have sent a response and manager has accepted it
        port_ro.RVALID <= False;
        port_ro.RDATA  <= 0;
        port_ro.ARREADY <= True;
      end

      // port_rw is read-write

      // NB: we take a shortcut on port_rw because the manager will always be RREADY/BREADY
      // as 1) the datapath never stalls in the W stage and 2) the cache is always ready
      if (port_rw.ARVALID && port_rw.ARREADY) begin
        port_rw.RVALID <= True;
`ifdef RISCV_FORMAL
        port_rw.RDATA <= random_data;
`else
        port_rw.RDATA  <= mem_array[port_rw.ARADDR[AddrMsb:AddrLsb]];
`endif
      end else if (port_rw.RVALID) begin
        port_rw.RVALID <= False;
        port_rw.RDATA  <= 0;
      end

      if (port_rw.AWVALID && port_rw.AWREADY && port_rw.WVALID && port_rw.WREADY) begin
`ifndef RISCV_FORMAL
        if (port_rw.WSTRB[0]) begin
          mem_array[port_rw.AWADDR[AddrMsb:AddrLsb]][7:0] <= port_rw.WDATA[7:0];
        end
        if (port_rw.WSTRB[1]) begin
          mem_array[port_rw.AWADDR[AddrMsb:AddrLsb]][15:8] <= port_rw.WDATA[15:8];
        end
        if (port_rw.WSTRB[2]) begin
          mem_array[port_rw.AWADDR[AddrMsb:AddrLsb]][23:16] <= port_rw.WDATA[23:16];
        end
        if (port_rw.WSTRB[3]) begin
          mem_array[port_rw.AWADDR[AddrMsb:AddrLsb]][31:24] <= port_rw.WDATA[31:24];
        end
`endif
        port_rw.BVALID <= True;
      end else if (port_rw.BVALID) begin
        port_rw.BVALID <= False;
      end
    end
  end

endmodule

typedef enum {
  CACHE_AVAILABLE = 0,
  CACHE_AWAIT_FILL_RESPONSE = 1,
  CACHE_AWAIT_WRITEBACK_RESPONSE = 2,
  CACHE_AWAIT_MANAGER_READY = 3
} cache_state_t;

module AxilCache #(
    /** size of each cache block, in bits */
    parameter int BLOCK_SIZE_BITS = 32,
    /** associativity of the cache */
    parameter int WAYS = 1,
    /** number of blocks in each way of the cache */
    parameter int NUM_SETS = 4
) (
    input wire ACLK,
    input wire ARESETn,
    axi_if.subord  proc,
    axi_if.manager mem
);

  localparam int BlockOffsetBits = $clog2(BLOCK_SIZE_BITS / 8);
  localparam int IndexBits = $clog2(NUM_SETS);
  localparam int TagBits = proc.ADDR_WIDTH - (IndexBits + BlockOffsetBits);
  localparam int AddrMsb = (IndexBits + BlockOffsetBits) - 1;

  // veril8or 5.030 can't expose packed arrays to cocotb, unfortunately, fields are packed into a single bit string.
  // cocotb also cannot access an unpacked array of bits like `logic foo[LEN]`.
  // With `logic [LEN-1:0] foo`, cocotb sees an int and we can read, but not write, individual bits via indexing.
  // However, with a bit inside a packed struct wrapper, cocotb can index it naturally!
  typedef struct packed {
      logic l;
  } lru_t;

  // cache state
  cache_state_t current_state;
  // logic [BLOCK_SIZE_BITS-1:0] data[NUM_SETS][WAYS];
  // logic [TagBits-1:0] tag[NUM_SETS][WAYS];
  logic [BLOCK_SIZE_BITS-1:0] data[NUM_SETS];
  logic [TagBits-1:0] tag[NUM_SETS];
  logic [WAYS-1:0] valid[NUM_SETS];
  logic [WAYS-1:0] dirty[NUM_SETS];
  lru_t lru[NUM_SETS];

  // initialize cache state to all zeroes
  genvar seti, wayi;
  for (seti = 0; seti < NUM_SETS; seti = seti + 1) begin : gen_cache_init
    initial begin
      valid[seti] = '0;
      dirty[seti] = '0;
      lru[seti] = '0;
      data[seti] = 0;
      tag[seti] = 0;
    end
  end

`ifndef FORMAL
  always_comb begin
    // TODO: generalize LRU state
    assert (WAYS <= 2);
    // memory addresses should always be 4B-aligned
    assert (!proc.ARVALID || proc.ARADDR[1:0] == 2'b00);
    assert (proc.ARPROT == 3'd0);
    assert (!proc.AWVALID || proc.AWADDR[1:0] == 2'b00);
    assert (proc.AWPROT == 3'd0);
    // cache is single-ported
    assert (!(proc.ARVALID && (proc.AWVALID || proc.WVALID)));
  end
`endif
  // our cache never raises any errors
  assign proc.RRESP = `RESP_OK;
  assign proc.BRESP = `RESP_OK;

  // cache lookup (pure combinational)
  localparam bit True = 1'b1;
  localparam bit False = 1'b0;
  wire [proc.ADDR_WIDTH-1:0] req_addr = proc.ARVALID ? proc.ARADDR : proc.AWVALID ? proc.AWADDR : 0;
  wire [IndexBits-1:0] cache_index = req_addr[AddrMsb -: IndexBits];
  wire [TagBits-1:0] req_tag = req_addr[proc.ADDR_WIDTH-1 -: TagBits];
  wire is_read_request = (proc.ARVALID && proc.ARREADY);
  wire is_write_request = (proc.AWVALID && proc.WVALID && proc.AWREADY && proc.WREADY);
  wire is_request = is_read_request || is_write_request;
  // either we're not sending a response, or our response was accepted
  wire can_send_new_response = !proc.RVALID || (proc.RVALID && proc.RREADY);
  wire [WAYS-1:0] way_hit_1hot;
  for (wayi = 0; wayi < WAYS; wayi = wayi + 1) begin: gen_way_hit
    // assign way_hit_1hot[wayi] = valid[cache_index][wayi] && (tag[cache_index][wayi] == req_tag);
    assign way_hit_1hot[wayi] = valid[cache_index][wayi] && (tag[cache_index] == req_tag);
  end
  wire [1 == WAYS ? 0 : $clog2(WAYS)-1:0] way_hit_index;
  encoder #(.INPUT_WIDTH(WAYS)) way_encoder (.one_hot(way_hit_1hot), .binary(way_hit_index));
  wire cache_hit = |way_hit_1hot;
  wire is_read = proc.ARVALID;

  wire victim_way_index = 1 == WAYS ? 0 : lru[cache_index].l;
  wire victim_is_dirty = dirty[cache_index][victim_way_index];
  // wire [proc.ADDR_WIDTH-1:0] victim_addr = {tag[cache_index][victim_way_index],cache_index,{BlockOffsetBits{1'b0}}};
  wire [proc.ADDR_WIDTH-1:0] victim_addr = {tag[cache_index],cache_index,{BlockOffsetBits{1'b0}}};

  // TODO: we assume that we cannot have read & write requests in same cycle
  // TODO: we assume awaddr, wdata & wstrb always arrive in the same cycle

  logic read_miss;
  typedef struct packed {
    logic is_read;
    logic [proc.ADDR_WIDTH-1:0] req_addr;
    logic [proc.DATA_WIDTH-1:0] wdata;
    logic [(proc.DATA_WIDTH/8)-1:0] wstrb;
    logic [IndexBits-1:0] cache_index;
    logic [TagBits-1:0] tag;
    logic [1 == WAYS ? 0 : $clog2(WAYS)-1:0] way_hit_index;
    logic [1 == WAYS ? 0 : $clog2(WAYS)-1:0] victim_way_index;
  } request_t;
  request_t saved;

  always_ff @(posedge ACLK) begin
    if (!ARESETn) begin
      current_state <= CACHE_AVAILABLE;
      read_miss <= False;
      saved <= '0;
      proc.ARREADY <= True;
      proc.RVALID <= False;
      proc.RDATA <= 0;

      proc.AWREADY <= True;
      proc.WREADY <= True;
      proc.BVALID <= 0;

      mem.ARVALID <= False;
      mem.ARADDR <= 0;
      mem.RREADY <= False;

      mem.AWVALID <= False;
      mem.AWADDR <= 0;
      mem.WVALID <= False;
      mem.WDATA <= 0;
      mem.WSTRB <= 0;
      mem.BREADY <= False;
    end else begin
      case (current_state)
        CACHE_AVAILABLE: begin
          proc.ARREADY <= True;
          proc.AWREADY <= True;
          proc.WREADY <= True;
          if (is_request && cache_hit) begin
            if (can_send_new_response) begin
              // update lru
              lru[cache_index].l <= ~way_hit_index;
              if (is_read) begin
                proc.RVALID <= True;
                // proc.RDATA <= data[cache_index][way_hit_index];
                proc.RDATA <= data[cache_index];
              end else begin // write
                proc.BVALID <= True;
                if (proc.WSTRB[0]) begin
                  // data[cache_index][way_hit_index][7:0] <= proc.WDATA[7:0];
                  data[cache_index][7:0] <= proc.WDATA[7:0];
                  dirty[cache_index][way_hit_index] <= 1;
                end
                if (proc.WSTRB[1]) begin
                  // data[cache_index][way_hit_index][15:8] <= proc.WDATA[15:8];
                  data[cache_index][15:8] <= proc.WDATA[15:8];
                  dirty[cache_index][way_hit_index] <= 1;
                end
                if (proc.WSTRB[2]) begin
                  // data[cache_index][way_hit_index][23:16] <= proc.WDATA[23:16];
                  data[cache_index][23:16] <= proc.WDATA[23:16];
                  dirty[cache_index][way_hit_index] <= 1;
                end
                if (proc.WSTRB[3]) begin
                  // data[cache_index][way_hit_index][31:24] <= proc.WDATA[31:24];
                  data[cache_index][31:24] <= proc.WDATA[31:24];
                  dirty[cache_index][way_hit_index] <= 1;
                end
              end
            end else begin
              // manager hasn't accepted our response, stop accepting new requests
              proc.ARREADY <= False;
              saved <= '{
                is_read: is_read,
                req_addr: req_addr,
                wstrb: proc.WSTRB,
                wdata: proc.WDATA,
                cache_index: cache_index,
                tag: req_tag,
                way_hit_index: way_hit_index,
                victim_way_index: victim_way_index
              };
              current_state <= CACHE_AWAIT_MANAGER_READY;
            end

            // if manager isn't ready for our response, stop accepting requests
            if (!proc.RREADY || !proc.BREADY) begin
              proc.ARREADY <= False;
              proc.AWREADY <= False;
              proc.WREADY <= False;
            end
          end else if (is_request && !cache_hit) begin
            proc.ARREADY <= False;
            proc.AWREADY <= False;
            proc.WREADY <= False;
            read_miss <= is_read;
            saved <= '{
              is_read: is_read,
              req_addr: req_addr,
              wstrb: proc.WSTRB,
              wdata: proc.WDATA,
              cache_index: cache_index,
              tag: req_tag,
              way_hit_index: way_hit_index,
              victim_way_index: victim_way_index
            };
            if (!victim_is_dirty) begin
              // clean miss: send read request to memory
              mem.ARVALID <= True;
              mem.ARADDR <= req_addr;
              mem.RREADY <= True;
              current_state <= CACHE_AWAIT_FILL_RESPONSE;
            end else begin
              // dirty miss: writeback dirty line
              mem.AWVALID <= True;
              mem.AWADDR <= victim_addr;
              mem.WVALID <= True;
              // mem.WDATA <= data[cache_index][victim_way_index];
              mem.WDATA <= data[cache_index];
              mem.WSTRB <= 4'hF;
              mem.BREADY <= True;
              current_state <= CACHE_AWAIT_WRITEBACK_RESPONSE;
            end
          end
          if ((proc.RVALID && proc.RREADY) && !(is_read_request && cache_hit)) begin
            proc.RVALID <= False;
            proc.RDATA <= 0;
          end
          if ((proc.BVALID && proc.BREADY) && !(is_write_request && cache_hit)) begin
            proc.BVALID <= False;
          end
        end

        CACHE_AWAIT_MANAGER_READY: begin
          if (proc.RREADY) begin
            assert(saved.is_read);
            lru[saved.cache_index].l <= ~saved.way_hit_index;
            proc.RVALID <= True;
            // proc.RDATA <= data[saved.cache_index][saved.way_hit_index];
            proc.RDATA <= data[saved.cache_index];
            current_state <= CACHE_AVAILABLE;
          end
        end

        CACHE_AWAIT_FILL_RESPONSE: begin
          if (mem.ARREADY) begin
            // our request was received by the memory
            mem.ARVALID <= False;
            mem.ARADDR <= 0;
          end
          if (mem.RVALID && mem.RRESP == `RESP_OK) begin
            // fill data from memory into cache
            // data[saved.cache_index][saved.victim_way_index] <= mem.RDATA;
            data[saved.cache_index] <= mem.RDATA;
            valid[saved.cache_index][saved.victim_way_index] <= True;
            dirty[saved.cache_index][saved.victim_way_index] <= False;
            // tag[saved.cache_index][saved.victim_way_index] <= saved.tag;
            tag[saved.cache_index] <= saved.tag;
            mem.RREADY <= False;

            // respond to proc
            current_state <= CACHE_AVAILABLE;
            proc.ARREADY <= True;
            proc.AWREADY <= True;
            proc.WREADY <= True;

            // perform cache hit
            lru[saved.cache_index].l <= ~saved.way_hit_index;
            if (read_miss) begin
              proc.RDATA <= mem.RDATA;
              proc.RVALID <= True;
            end else begin
              proc.BVALID <= True;
              if (saved.wstrb[0]) begin
                // data[saved.cache_index][saved.way_hit_index][7:0] <= saved.wdata[7:0];
                data[saved.cache_index][7:0] <= saved.wdata[7:0];
                dirty[saved.cache_index][saved.way_hit_index] <= 1;
              end
              if (saved.wstrb[1]) begin
                // data[saved.cache_index][saved.way_hit_index][15:8] <= saved.wdata[15:8];
                data[saved.cache_index][15:8] <= saved.wdata[15:8];
                dirty[saved.cache_index][saved.way_hit_index] <= 1;
              end
              if (saved.wstrb[2]) begin
                // data[saved.cache_index][saved.way_hit_index][23:16] <= saved.wdata[23:16];
                data[saved.cache_index][23:16] <= saved.wdata[23:16];
                dirty[saved.cache_index][saved.way_hit_index] <= 1;
              end
              if (saved.wstrb[3]) begin
                // data[saved.cache_index][saved.way_hit_index][31:24] <= saved.wdata[31:24];
                data[saved.cache_index][31:24] <= saved.wdata[31:24];
                dirty[saved.cache_index][saved.way_hit_index] <= 1;
              end
            end
          end
        end

        CACHE_AWAIT_WRITEBACK_RESPONSE: begin
          if (mem.AWREADY) begin
            // our request was received by the memory
            mem.AWVALID <= False;
            mem.AWADDR <= 0;
            mem.WVALID <= False;
            mem.WDATA <= 0;
            mem.WSTRB <= 0;
          end
          if (mem.BVALID && mem.BRESP == `RESP_OK) begin
            // writeback was completed by memory, now send fill request
            mem.ARVALID <= True;
            mem.ARADDR <= saved.req_addr;
            mem.RREADY <= True;
            mem.BREADY <= False;
            current_state <= CACHE_AWAIT_FILL_RESPONSE;
          end
        end

        default: begin
        end
      endcase
    end
  end

endmodule // AxilCache

`ifndef SYNTHESIS
/** This is used for testing AxilCache in simulation, since Verilator doesn't allow
SV interfaces in top-level modules */
module AxilCacheTester #(
    // these parameters are for the AXIL interface
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    // these parameters are for the cache
    parameter int BLOCK_SIZE_BITS = 32,
    parameter int WAYS = 1,
    parameter int NUM_SETS = 4
) (
    input wire ACLK,
    input wire ARESETn,

    input  wire                       CACHE_ARVALID,
    output logic                      CACHE_ARREADY,
    input  wire  [    ADDR_WIDTH-1:0] CACHE_ARADDR,
    input  wire  [               2:0] CACHE_ARPROT,
    output logic                      CACHE_RVALID,
    input  wire                       CACHE_RREADY,
    output logic [    ADDR_WIDTH-1:0] CACHE_RDATA,
    output logic [               1:0] CACHE_RRESP,
    input  wire                       CACHE_AWVALID,
    output logic                      CACHE_AWREADY,
    input  wire  [    ADDR_WIDTH-1:0] CACHE_AWADDR,
    input  wire  [               2:0] CACHE_AWPROT,
    input  wire                       CACHE_WVALID,
    output logic                      CACHE_WREADY,
    input  wire  [    DATA_WIDTH-1:0] CACHE_WDATA,
    input  wire  [(DATA_WIDTH/8)-1:0] CACHE_WSTRB,
    output logic                      CACHE_BVALID,
    input  wire                       CACHE_BREADY,
    output logic [               1:0] CACHE_BRESP,

    output wire                       MEM_ARVALID,
    input  logic                      MEM_ARREADY,
    output wire  [    ADDR_WIDTH-1:0] MEM_ARADDR,
    output wire  [               2:0] MEM_ARPROT,
    input  logic                      MEM_RVALID,
    output wire                       MEM_RREADY,
    input  logic [    ADDR_WIDTH-1:0] MEM_RDATA,
    input  logic [               1:0] MEM_RRESP,
    output wire                       MEM_AWVALID,
    input  logic                      MEM_AWREADY,
    output wire  [    ADDR_WIDTH-1:0] MEM_AWADDR,
    output wire  [               2:0] MEM_AWPROT,
    output wire                       MEM_WVALID,
    input  logic                      MEM_WREADY,
    output wire  [    DATA_WIDTH-1:0] MEM_WDATA,
    output wire  [(DATA_WIDTH/8)-1:0] MEM_WSTRB,
    input  logic                      MEM_BVALID,
    output wire                       MEM_BREADY,
    input  logic [               1:0] MEM_BRESP
);

  axi_if #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
  ) cache_axi ();
  assign cache_axi.manager.ARVALID = CACHE_ARVALID;
  assign CACHE_ARREADY = cache_axi.manager.ARREADY;
  assign cache_axi.manager.ARADDR = CACHE_ARADDR;
  assign cache_axi.manager.ARPROT = CACHE_ARPROT;
  assign CACHE_RVALID = cache_axi.manager.RVALID;
  assign cache_axi.manager.RREADY = CACHE_RREADY;
  assign CACHE_RRESP = cache_axi.manager.RRESP;
  assign CACHE_RDATA = cache_axi.manager.RDATA;
  assign cache_axi.manager.AWVALID = CACHE_AWVALID;
  assign CACHE_AWREADY = cache_axi.manager.AWREADY;
  assign cache_axi.manager.AWADDR = CACHE_AWADDR;
  assign cache_axi.manager.AWPROT = CACHE_AWPROT;
  assign cache_axi.manager.WVALID = CACHE_WVALID;
  assign CACHE_WREADY = cache_axi.manager.WREADY;
  assign cache_axi.manager.WDATA = CACHE_WDATA;
  assign cache_axi.manager.WSTRB = CACHE_WSTRB;
  assign CACHE_BVALID = cache_axi.manager.BVALID;
  assign cache_axi.manager.BREADY = CACHE_BREADY;
  assign CACHE_BRESP = cache_axi.manager.BRESP;

  axi_if #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
  ) mem_axi ();
   assign MEM_ARVALID = mem_axi.subord.ARVALID;
   assign mem_axi.subord.ARREADY = MEM_ARREADY;
   assign MEM_ARADDR = mem_axi.subord.ARADDR;
   assign MEM_ARPROT = mem_axi.subord.ARPROT;
   assign mem_axi.subord.RVALID = MEM_RVALID;
   assign MEM_RREADY = mem_axi.subord.RREADY;
   assign mem_axi.subord.RRESP = MEM_RRESP;
   assign mem_axi.subord.RDATA = MEM_RDATA;
   assign MEM_AWVALID = mem_axi.subord.AWVALID;
   assign mem_axi.subord.AWREADY = MEM_AWREADY;
   assign MEM_AWADDR = mem_axi.subord.AWADDR;
   assign MEM_AWPROT = mem_axi.subord.AWPROT;
   assign MEM_WVALID = mem_axi.subord.WVALID;
   assign mem_axi.subord.WREADY = MEM_WREADY;
   assign MEM_WDATA = mem_axi.subord.WDATA;
   assign MEM_WSTRB = mem_axi.subord.WSTRB;
   assign mem_axi.subord.BVALID = MEM_BVALID;
   assign MEM_BREADY = mem_axi.subord.BREADY;
   assign mem_axi.subord.BRESP = MEM_BRESP;

  AxilCache #(
    .BLOCK_SIZE_BITS(BLOCK_SIZE_BITS),
    .WAYS(WAYS),
    .NUM_SETS(NUM_SETS)
  ) cache (
      .ACLK(ACLK),
      .ARESETn(ARESETn),
      .proc(cache_axi.subord),
      .mem(mem_axi.manager)
  );
endmodule // AxilCacheTester
`endif
