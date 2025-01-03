module hdmi_video (
    input clk_25MHz,
    input clk_125MHz,
    input clk_locked,
    output [9:0] x,
    output [9:0] y,
    input [23:0] color,
    output [3:0] gpdi_dp, gpdi_dn
    // output wire vga_vsync,
    // output wire vga_hsync,
    // output wire vga_blank
);
  wire vga_vsync, vga_hsync, vga_blank;

  vga_video vga_instance (
      .clk(clk_25MHz),
      .resetn(clk_locked),
      .vga_hsync(vga_hsync),
      .vga_vsync(vga_vsync),
      .vga_blank(vga_blank),
      .h_pos(x),
      .v_pos(y)
  );

  // VGA to digital video converter
  wire [1:0] tmds[3:0];
  wire [9:0] ignore_red, ignore_green, ignore_blue;
  vga2dvid vga2dvid_instance (
      .clk_pixel(clk_25MHz),
      .clk_shift(clk_125MHz),
      .in_color(color),
      .in_hsync(vga_hsync),
      .in_vsync(vga_vsync),
      .in_blank(vga_blank),
      .out_clock(tmds[3]),
      .out_red(tmds[2]),
      .out_green(tmds[1]),
      .out_blue(tmds[0]),
      .outp_red(ignore_red),
      .outp_green(ignore_green),
      .outp_blue(ignore_blue),
      .resetn(clk_locked)
  );

  // output TMDS SDR/DDR data to fake differential lanes
  fake_differential fake_differential_instance (
      .clk_shift(clk_125MHz),
      .in_clock(tmds[3]),
      .in_red(tmds[2]),
      .in_green(tmds[1]),
      .in_blue(tmds[0]),
      .out_p(gpdi_dp),
      .out_n(gpdi_dn)
  );
endmodule
