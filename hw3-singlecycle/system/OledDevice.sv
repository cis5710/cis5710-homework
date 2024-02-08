
/*
A memory-mapped device for interacting with the ZedBoard's OLED display. Each value of addr corresponds to
one ASCII character on the display, which is 4 rows of 16 characters each. If `store_we` is set, the value
from `store_data` will be written to `addr` which will appear on the display.
 */
module OledDevice(
    // general ports
    input wire rst,
    input wire clock_mem,
    input wire oled_power_button,
    // whether the OLED display is on or not
    output logic oled_on,

    // ports for the memory-mapped interface
    // we have only 64 characters, which can only be accessed at byte granularity
    input wire [5:0] addr,
    output logic [7:0] load_data,
    input wire [7:0] store_data,
    input wire store_we,

    // ports for the OLED display itself
    input wire        OLED_CONTROL_CLK,
    output wire       OLED_SDIN,
    output wire       OLED_SCLK,
    output wire       OLED_DC,
    output wire       OLED_RES,
    output wire       OLED_VBAT,
    output wire       OLED_VDD);

    // memory is arranged as a 2D array with 4 rows of 16 columns each, just like the OLED display.
    logic [7:0] mem[4][16];

    initial begin
        $readmemh("oled_initial_contents.hex", mem, 0);
    end

    // use same clock edge as the data memory
    always @(negedge clock_mem) begin
        if (rst) begin
        end else begin
            if (store_we) begin
                mem[addr[5:4]][addr[3:0]] <= store_data;
            end
            // read happens before the write, returning the overwritten value
            load_data <= mem[addr[5:4]][addr[3:0]];
        end
    end

wire oled_rst;
debouncer #(.COUNT_MAX(8191), .COUNT_WIDTH(13)) db_oled_power_button
(.clk(OLED_CONTROL_CLK), .A(oled_power_button), .B(oled_rst));

//state machine codes
   localparam Idle       = 0;
   localparam Init       = 1;
   localparam Active     = 2;
   localparam Done       = 3;
   localparam FullDisp   = 4; // jld: used in Digilent demo but not for us
   localparam Write      = 5;
   localparam WriteWait  = 6;
   localparam UpdateWait = 7;
    
    localparam AUTO_START = 1; // determines whether the OLED will be automatically initialized when the board is programmed
    	
    //state machine registers.
    reg [2:0] state = (AUTO_START == 1) ? Init : Idle;
    reg [5:0] count = 0;//loop index variable
    reg       once = 0;//bool to see if we have set up local pixel memory in this session
        
    //oled control signals
    //command start signals, assert high to start command
    reg        update_start = 0;        //update oled display over spi
    reg        disp_on_start = AUTO_START;       //turn the oled display on
    reg        disp_off_start = 0;      //turn the oled display off
    reg        toggle_disp_start = 0;   //turns on every pixel on the oled, or returns the display to before each pixel was turned on
    reg        write_start = 0;         //writes a character bitmap into local memory
    //data signals for oled controls
    reg        update_clear = 0;        //when asserted high, an update command clears the display, instead of filling from memory
    reg  [8:0] write_base_addr = 0;     //location to write character to, two most significant bits are row position, 0 is topmost. bottom seven bits are X position, addressed by pixel x position.
    reg  [7:0] write_ascii_data = 0;    //ascii value of character to write to memory
    //active high command ready signals, appropriate start commands are ignored when these are not asserted high
    wire       disp_on_ready;
    wire       disp_off_ready;
    wire       toggle_disp_ready;
    wire       update_ready;
    wire       write_ready;

    //instantiate OLED controller
    OLEDCtrl m_OLEDCtrl (
        .clk                (OLED_CONTROL_CLK),
        .write_start        (write_start),
        .write_ascii_data   (write_ascii_data),
        .write_base_addr    (write_base_addr),
        .write_ready        (write_ready),
        .update_start       (update_start),
        .update_ready       (update_ready),
        .update_clear       (update_clear),
        .disp_on_start      (disp_on_start),
        .disp_on_ready      (disp_on_ready),
        .disp_off_start     (disp_off_start),
        .disp_off_ready     (disp_off_ready),
        .toggle_disp_start  (toggle_disp_start),
        .toggle_disp_ready  (toggle_disp_ready),
        .SDIN               (OLED_SDIN),
        .SCLK               (OLED_SCLK),
        .DC                 (OLED_DC),
        .RES                (OLED_RES),
        .VBAT               (OLED_VBAT),
        .VDD                (OLED_VDD)
    );

   always @(posedge OLED_CONTROL_CLK) begin
    write_ascii_data <= mem[write_base_addr[8:7]][write_base_addr[6:3]];
   end

   wire init_done = disp_off_ready | toggle_disp_ready | write_ready | update_ready;//parse ready signals for clarity
   wire init_ready = disp_on_ready;
   always@(posedge OLED_CONTROL_CLK)
     case (state)
       Idle: begin
          if (oled_rst == 1'b1 && init_ready == 1'b1) begin
             disp_on_start <= 1'b1;
             state <= Init;
          end
          once <= 0;
          oled_on <= 1'b0;
       end
       Init: begin
          disp_on_start <= 1'b0;
          if (oled_rst == 1'b0 && init_done == 1'b1)
            state <= Active;
       end
       Active: begin // hold until ready, then accept input
          if (oled_rst && disp_off_ready) begin
             disp_off_start <= 1'b1;
             state <= Done;
          end else if (once == 0 && write_ready) begin
             write_start <= 1'b1;
             write_base_addr <= 'b0;
             state <= WriteWait;
          end else if (once == 1) begin
             update_start <= 1'b1;
             update_clear <= 1'b0;
             state <= UpdateWait;
          end
       end // case: Active
       Write: begin
          write_start <= 1'b1;
          write_base_addr <= write_base_addr + 9'h8;
          //write_ascii_data updated with write_base_addr
          state <= WriteWait;
       end
       WriteWait: begin
          write_start <= 1'b0;
          if (write_ready == 1'b1)
            if (write_base_addr == 9'h1f8) begin
               oled_on <= 1'b1;
               once <= 1;
               state <= Active;
            end else begin
               state <= Write;
            end
       end // case: WriteWait
       UpdateWait: begin
          update_start <= 0;
          if (init_done == 1'b1) begin
             state <= Active;
             once <= 0;
          end
       end
       Done: begin
          disp_off_start <= 1'b0;
          if (oled_rst == 1'b0 && init_ready == 1'b1)
            state <= Idle;
       end
       default: state <= Idle;
     endcase

endmodule
