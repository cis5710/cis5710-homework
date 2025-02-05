`include "cla.sv"
module SystemDemo(input wire [6:0] btn,
                 output wire [7:0] led);
   wire [31:0] sum;
   cla cla_inst(.a(32'd26), .b({27'b0, btn[1], btn[2], btn[5], btn[4], btn[6]}), .cin(1'b0), .sum(sum));
   assign led = sum[7:0];
endmodule