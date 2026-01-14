`include "CarryLookaheadAdder.sv"

/** Runs all 16-bit inputs against the CLA, showing progress via LEDs. */
module SystemDemo (
   input  wire        external_clk_25MHz,
   input  wire [6:0]  btn,
   output logic [7:0] led
);

   logic [31:0] ab;
   wire [15:0] a, b;
   wire [31:0] expected_sum;
   wire [31:0] actual_sum;

   wire rst = ~btn[0];

   // Error register
   logic error;

   // Chunk tracking
   wire [2:0] chunk = ab[31:29];   // current 1/8th being tested
   logic [7:0] completed;          // progress bar

   CarryLookaheadAdder cla_inst (
      .a   (a),
      .b   (b),
      .cin (1'b0),
      .sum (actual_sum)
   );

   // Combinational math
   always_comb begin
      a = ab[31:16];
      b = ab[15:0];
      expected_sum = a + b;
   end

   // Main test loop
   always_ff @(posedge external_clk_25MHz) begin
      if (rst) begin
         ab         <= 32'd0;
         error      <= 1'b0;
         completed  <= 8'd0;
      end else if (!error) begin
         // Check result
         if (actual_sum != expected_sum) begin
            error <= 1'b1;   // freeze on error
         end else begin
            ab <= ab + 1;

            // If chunk just finished, mark it complete
            if (ab[28:0] == 29'h1FFFFFFF) begin
               completed[chunk] <= 1'b1;
            end
         end
      end
   end

   // LED display logic

   logic [23:0] blink;

   // Blink counter
   always_ff @(posedge external_clk_25MHz) begin
      if (rst) begin
         blink  <= 0;
      end else begin
         blink <= blink + 1;
      end
   end

   always_comb begin
      if (error) begin
         led = completed;
      end else begin
         led = completed | ({7'd0, blink[23]} << chunk);
      end
   end

endmodule
