// Project F: FPGA Graphics - Simple 800x600p60 Display
// (C)2023 Will Green, open source hardware released under the MIT License
// Learn more at https://projectf.io/posts/fpga-graphics/

`default_nettype none
`timescale 1ns / 1ps

module simple_800_600 (
    input  wire logic clk_pix,   // pixel clock
    input  wire logic rst_pix,   // reset in pixel clock domain
    output      logic [11:0] sx, // horizontal screen position
    output      logic [11:0] sy, // vertical screen position
    output      logic hsync,     // horizontal sync
    output      logic vsync,     // vertical sync
    output      logic de         // data enable (low in blanking interval)
    );

/*
Name          800x600p60           Name         1280x720p60
Standard        VESA DMT           Standard       CTA-770.3
VIC                  N/A           VIC                    4
Short Name           N/A           Short Name          720p
Aspect Ratio         4:3           Aspect Ratio        16:9

Pixel Clock       40.000 MHz       Pixel Clock       74.250 MHz
TMDS Clock       400.000 MHz       TMDS Clock       742.500 MHz
Pixel Time          25.0 ns ±0.5%  Pixel Time          13.5 ns ±0.5%
Horizontal Freq.  37.897 kHz       Horizontal Freq.  45.000 kHz
Line Time           26.4 μs        Line Time           22.2 μs
Vertical Freq.    60.317 Hz        Vertical Freq.    60.000 Hz
Frame Time          16.6 ms        Frame Time          16.7 ms

Horizontal Timings                 Horizontal Timings
Active Pixels        800           Active Pixels       1280
Front Porch           40           Front Porch          110
Sync Width           128           Sync Width            40
Back Porch            88           Back Porch           220
Blanking Total       256           Blanking Total       370
Total Pixels        1056           Total Pixels        1650
Sync Polarity        pos           Sync Polarity        pos

Vertical Timings                   Vertical Timings
Active Lines         600           Active Lines         720
Front Porch            1           Front Porch            5
Sync Width             4           Sync Width             5
Back Porch            23           Back Porch            20
Blanking Total        28           Blanking Total        30
Total Lines          628           Total Lines          750
Sync Polarity        pos           Sync Polarity        pos
*/

    // horizontal timings
    parameter HA_END = 799;          // end of active pixels
    parameter HS_STA = HA_END + 40;  // sync starts after front porch
    parameter HS_END = HS_STA + 128; // sync ends
    parameter LINE   = 1055;         // last pixel on line (after back porch)

    // vertical timings
    parameter VA_END = 599;           // end of active pixels
    parameter VS_STA = VA_END + 1;    // sync starts after front porch
    parameter VS_END = VS_STA + 4;    // sync ends
    parameter SCREEN = 627;           // last line on screen (after back porch)

    always_comb begin
        hsync = (sx >= HS_STA && sx < HS_END);  // positive polarity
        vsync = (sy >= VS_STA && sy < VS_END);  // positive polarity
        de = (sx <= HA_END && sy <= VA_END);
    end

    // calculate horizontal and vertical screen position
    always_ff @(posedge clk_pix) begin
        if (sx == LINE) begin  // last pixel on line?
            sx <= 0;
            sy <= (sy == SCREEN) ? 0 : sy + 1;  // last line on screen?
        end else begin
            sx <= sx + 1;
        end
        if (rst_pix) begin
            sx <= 0;
            sy <= 0;
        end
    end
endmodule
