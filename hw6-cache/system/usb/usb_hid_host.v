// Usb_hid_host: A compact USB HID host core.
//
// nand2mario, 8/2023, based on work by hi631
// 
// This should support keyboard, mouse and gamepad input out of the box, over low-speed 
// USB (1.5Mbps). Just connect D+, D-, VBUS (5V) and GND, and two 15K resistors between 
// D+ and GND, D- and GND. Then provide a 12Mhz clock through usbclk.
//
// See https://github.com/nand2mario/usb_hid_host
// 

module usb_hid_host_rom(clk, adr, data);
   input clk;
   input [13:0] adr;
   output [3:0] data;
   reg [3:0]    data;
   reg [3:0]    mem [536];

   initial begin
      mem[0] = 4'h1;
      mem[1] = 4'h9;
      mem[2] = 4'h0;
      mem[3] = 4'h0;
      mem[4] = 4'he;
      mem[5] = 4'h9;
      mem[6] = 4'ha;
      mem[7] = 4'h2;
      mem[8] = 4'h8;
      mem[9] = 4'h0;
      mem[10] = 4'h0;
      mem[11] = 4'h1;
      mem[12] = 4'h8;
      mem[13] = 4'hc;
      mem[14] = 4'h0;
      mem[15] = 4'h0;
      mem[16] = 4'he;
      mem[17] = 4'hb;
      mem[18] = 4'h4;
      mem[19] = 4'h0;
      mem[20] = 4'hf;
      mem[21] = 4'h4;
      mem[22] = 4'h3;
      mem[23] = 4'h0;
      mem[24] = 4'hf;
      mem[25] = 4'h8;
      mem[26] = 4'h4;
      mem[27] = 4'h0;
      mem[28] = 4'h5;
      mem[29] = 4'hf;
      mem[30] = 4'h2;
      mem[31] = 4'h7;
      mem[32] = 4'h0;
      mem[33] = 4'h0;
      mem[34] = 4'h0;
      mem[35] = 4'h0;
      mem[36] = 4'hf;
      mem[37] = 4'h7;
      mem[38] = 4'h7;
      mem[39] = 4'h0;
      mem[40] = 4'h5;
      mem[41] = 4'hf;
      mem[42] = 4'h2;
      mem[43] = 4'h7;
      mem[44] = 4'h0;
      mem[45] = 4'ha;
      mem[46] = 4'h9;
      mem[47] = 4'h0;
      mem[48] = 4'hf;
      mem[49] = 4'h3;
      mem[50] = 4'h8;
      mem[51] = 4'h0;
      mem[52] = 4'h5;
      mem[53] = 4'h0;
      mem[54] = 4'h0;
      mem[55] = 4'h0;
      mem[56] = 4'hf;
      mem[57] = 4'h7;
      mem[58] = 4'h7;
      mem[59] = 4'h0;
      mem[60] = 4'h5;
      mem[61] = 4'hf;
      mem[62] = 4'h2;
      mem[63] = 4'h7;
      mem[64] = 4'h0;
      mem[65] = 4'ha;
      mem[66] = 4'he;
      mem[67] = 4'h0;
      mem[68] = 4'hc;
      mem[69] = 4'h4;
      mem[70] = 4'h6;
      mem[71] = 4'hc;
      mem[72] = 4'h5;
      mem[73] = 4'h7;
      mem[74] = 4'hf;
      mem[75] = 4'h3;
      mem[76] = 4'h8;
      mem[77] = 4'h0;
      mem[78] = 4'h5;
      mem[79] = 4'h0;
      mem[80] = 4'hf;
      mem[81] = 4'h7;
      mem[82] = 4'h7;
      mem[83] = 4'h0;
      mem[84] = 4'h5;
      mem[85] = 4'hf;
      mem[86] = 4'h2;
      mem[87] = 4'h7;
      mem[88] = 4'h0;
      mem[89] = 4'ha;
      mem[90] = 4'h4;
      mem[91] = 4'h1;
      mem[92] = 4'hc;
      mem[93] = 4'h6;
      mem[94] = 4'h0;
      mem[95] = 4'hf;
      mem[96] = 4'h3;
      mem[97] = 4'h8;
      mem[98] = 4'h0;
      mem[99] = 4'h5;
      mem[100] = 4'hf;
      mem[101] = 4'h4;
      mem[102] = 4'h3;
      mem[103] = 4'h0;
      mem[104] = 4'hf;
      mem[105] = 4'h6;
      mem[106] = 4'h5;
      mem[107] = 4'h0;
      mem[108] = 4'h5;
      mem[109] = 4'hf;
      mem[110] = 4'h2;
      mem[111] = 4'h7;
      mem[112] = 4'h0;
      mem[113] = 4'h0;
      mem[114] = 4'h0;
      mem[115] = 4'h0;
      mem[116] = 4'hf;
      mem[117] = 4'h7;
      mem[118] = 4'h7;
      mem[119] = 4'h0;
      mem[120] = 4'h5;
      mem[121] = 4'hf;
      mem[122] = 4'h2;
      mem[123] = 4'h7;
      mem[124] = 4'h0;
      mem[125] = 4'ha;
      mem[126] = 4'hd;
      mem[127] = 4'h1;
      mem[128] = 4'hf;
      mem[129] = 4'h3;
      mem[130] = 4'h8;
      mem[131] = 4'h0;
      mem[132] = 4'h5;
      mem[133] = 4'he;
      mem[134] = 4'hf;
      mem[135] = 4'h4;
      mem[136] = 4'h6;
      mem[137] = 4'h0;
      mem[138] = 4'h5;
      mem[139] = 4'hf;
      mem[140] = 4'h2;
      mem[141] = 4'h7;
      mem[142] = 4'h0;
      mem[143] = 4'h0;
      mem[144] = 4'hf;
      mem[145] = 4'hb;
      mem[146] = 4'h7;
      mem[147] = 4'h0;
      mem[148] = 4'h5;
      mem[149] = 4'hf;
      mem[150] = 4'h2;
      mem[151] = 4'h7;
      mem[152] = 4'h0;
      mem[153] = 4'ha;
      mem[154] = 4'h4;
      mem[155] = 4'h2;
      mem[156] = 4'hf;
      mem[157] = 4'h3;
      mem[158] = 4'h8;
      mem[159] = 4'h0;
      mem[160] = 4'h5;
      mem[161] = 4'hc;
      mem[162] = 4'hf;
      mem[163] = 4'hf;
      mem[164] = 4'hf;
      mem[165] = 4'h0;
      mem[166] = 4'h0;
      mem[167] = 4'h0;
      mem[168] = 4'h8;
      mem[169] = 4'h2;
      mem[170] = 4'h3;
      mem[171] = 4'h3;
      mem[172] = 4'h3;
      mem[173] = 4'h0;
      mem[174] = 4'h5;
      mem[175] = 4'hb;
      mem[176] = 4'h1;
      mem[177] = 4'h0;
      mem[178] = 4'he;
      mem[179] = 4'hf;
      mem[180] = 4'hf;
      mem[181] = 4'h7;
      mem[182] = 4'h0;
      mem[183] = 4'h5;
      mem[184] = 4'hf;
      mem[185] = 4'h2;
      mem[186] = 4'h7;
      mem[187] = 4'h0;
      mem[188] = 4'ha;
      mem[189] = 4'h0;
      mem[190] = 4'h0;
      mem[191] = 4'hf;
      mem[192] = 4'h3;
      mem[193] = 4'h8;
      mem[194] = 4'h0;
      mem[195] = 4'h5;
      mem[196] = 4'hf;
      mem[197] = 4'h0;
      mem[198] = 4'h0;
      mem[199] = 4'h0;
      mem[200] = 4'hc;
      mem[201] = 4'hf;
      mem[202] = 4'hf;
      mem[203] = 4'hf;
      mem[204] = 4'h0;
      mem[205] = 4'h0;
      mem[206] = 4'h0;
      mem[207] = 4'h0;
      mem[208] = 4'h4;
      mem[209] = 4'h1;
      mem[210] = 4'ha;
      mem[211] = 4'h0;
      mem[212] = 4'he;
      mem[213] = 4'hb;
      mem[214] = 4'h5;
      mem[215] = 4'h3;
      mem[216] = 4'h5;
      mem[217] = 4'h1;
      mem[218] = 4'h8;
      mem[219] = 4'h2;
      mem[220] = 4'he;
      mem[221] = 4'h3;
      mem[222] = 4'h3;
      mem[223] = 4'h0;
      mem[224] = 4'h5;
      mem[225] = 4'hb;
      mem[226] = 4'h7;
      mem[227] = 4'h3;
      mem[228] = 4'he;
      mem[229] = 4'h7;
      mem[230] = 4'h0;
      mem[231] = 4'h0;
      mem[232] = 4'h6;
      mem[233] = 4'h0;
      mem[234] = 4'h8;
      mem[235] = 4'h6;
      mem[236] = 4'hd;
      mem[237] = 4'h2;
      mem[238] = 4'h6;
      mem[239] = 4'h0;
      mem[240] = 4'h0;
      mem[241] = 4'h6;
      mem[242] = 4'h0;
      mem[243] = 4'h1;
      mem[244] = 4'h3;
      mem[245] = 4'h3;
      mem[246] = 4'h0;
      mem[247] = 4'h6;
      mem[248] = 4'h0;
      mem[249] = 4'h8;
      mem[250] = 4'h6;
      mem[251] = 4'h3;
      mem[252] = 4'hc;
      mem[253] = 4'h6;
      mem[254] = 4'h0;
      mem[255] = 4'h8;
      mem[256] = 4'h6;
      mem[257] = 4'h6;
      mem[258] = 4'h0;
      mem[259] = 4'h6;
      mem[260] = 4'h0;
      mem[261] = 4'h0;
      mem[262] = 4'h6;
      mem[263] = 4'h1;
      mem[264] = 4'h0;
      mem[265] = 4'h6;
      mem[266] = 4'h0;
      mem[267] = 4'h0;
      mem[268] = 4'h6;
      mem[269] = 4'h0;
      mem[270] = 4'h0;
      mem[271] = 4'h6;
      mem[272] = 4'h2;
      mem[273] = 4'h1;
      mem[274] = 4'h6;
      mem[275] = 4'h0;
      mem[276] = 4'h0;
      mem[277] = 4'h6;
      mem[278] = 4'h0;
      mem[279] = 4'he;
      mem[280] = 4'h6;
      mem[281] = 4'h4;
      mem[282] = 4'hf;
      mem[283] = 4'h3;
      mem[284] = 4'h3;
      mem[285] = 4'h0;
      mem[286] = 4'h7;
      mem[287] = 4'h0;
      mem[288] = 4'h6;
      mem[289] = 4'h0;
      mem[290] = 4'h8;
      mem[291] = 4'h6;
      mem[292] = 4'hd;
      mem[293] = 4'h2;
      mem[294] = 4'h6;
      mem[295] = 4'h0;
      mem[296] = 4'h0;
      mem[297] = 4'h6;
      mem[298] = 4'h0;
      mem[299] = 4'h1;
      mem[300] = 4'h3;
      mem[301] = 4'h3;
      mem[302] = 4'h0;
      mem[303] = 4'h6;
      mem[304] = 4'h0;
      mem[305] = 4'h8;
      mem[306] = 4'h6;
      mem[307] = 4'h3;
      mem[308] = 4'hc;
      mem[309] = 4'h6;
      mem[310] = 4'h0;
      mem[311] = 4'h8;
      mem[312] = 4'h6;
      mem[313] = 4'h6;
      mem[314] = 4'h0;
      mem[315] = 4'h6;
      mem[316] = 4'h0;
      mem[317] = 4'h0;
      mem[318] = 4'h6;
      mem[319] = 4'h2;
      mem[320] = 4'h0;
      mem[321] = 4'h6;
      mem[322] = 4'h0;
      mem[323] = 4'h0;
      mem[324] = 4'h6;
      mem[325] = 4'h0;
      mem[326] = 4'h0;
      mem[327] = 4'h6;
      mem[328] = 4'h8;
      mem[329] = 4'h1;
      mem[330] = 4'h6;
      mem[331] = 4'h0;
      mem[332] = 4'h0;
      mem[333] = 4'h6;
      mem[334] = 4'h2;
      mem[335] = 4'ha;
      mem[336] = 4'h6;
      mem[337] = 4'h4;
      mem[338] = 4'h5;
      mem[339] = 4'h3;
      mem[340] = 4'h3;
      mem[341] = 4'h0;
      mem[342] = 4'h7;
      mem[343] = 4'h0;
      mem[344] = 4'h6;
      mem[345] = 4'h0;
      mem[346] = 4'h8;
      mem[347] = 4'h6;
      mem[348] = 4'hd;
      mem[349] = 4'h2;
      mem[350] = 4'h6;
      mem[351] = 4'h0;
      mem[352] = 4'h0;
      mem[353] = 4'h6;
      mem[354] = 4'h0;
      mem[355] = 4'h1;
      mem[356] = 4'h3;
      mem[357] = 4'h3;
      mem[358] = 4'h0;
      mem[359] = 4'h6;
      mem[360] = 4'h0;
      mem[361] = 4'h8;
      mem[362] = 4'h6;
      mem[363] = 4'h3;
      mem[364] = 4'hc;
      mem[365] = 4'h6;
      mem[366] = 4'h0;
      mem[367] = 4'h0;
      mem[368] = 4'h6;
      mem[369] = 4'h5;
      mem[370] = 4'h0;
      mem[371] = 4'h6;
      mem[372] = 4'h1;
      mem[373] = 4'h0;
      mem[374] = 4'h6;
      mem[375] = 4'h0;
      mem[376] = 4'h0;
      mem[377] = 4'h6;
      mem[378] = 4'h0;
      mem[379] = 4'h0;
      mem[380] = 4'h6;
      mem[381] = 4'h0;
      mem[382] = 4'h0;
      mem[383] = 4'h6;
      mem[384] = 4'h0;
      mem[385] = 4'h0;
      mem[386] = 4'h6;
      mem[387] = 4'h0;
      mem[388] = 4'h0;
      mem[389] = 4'h6;
      mem[390] = 4'hb;
      mem[391] = 4'he;
      mem[392] = 4'h6;
      mem[393] = 4'h5;
      mem[394] = 4'h2;
      mem[395] = 4'h3;
      mem[396] = 4'h3;
      mem[397] = 4'h0;
      mem[398] = 4'h7;
      mem[399] = 4'h0;
      mem[400] = 4'h6;
      mem[401] = 4'h0;
      mem[402] = 4'h8;
      mem[403] = 4'h6;
      mem[404] = 4'hd;
      mem[405] = 4'h2;
      mem[406] = 4'h6;
      mem[407] = 4'h1;
      mem[408] = 4'h0;
      mem[409] = 4'h6;
      mem[410] = 4'h8;
      mem[411] = 4'he;
      mem[412] = 4'h3;
      mem[413] = 4'h3;
      mem[414] = 4'h0;
      mem[415] = 4'h6;
      mem[416] = 4'h0;
      mem[417] = 4'h8;
      mem[418] = 4'h6;
      mem[419] = 4'h3;
      mem[420] = 4'hc;
      mem[421] = 4'h6;
      mem[422] = 4'h0;
      mem[423] = 4'h0;
      mem[424] = 4'h6;
      mem[425] = 4'h9;
      mem[426] = 4'h0;
      mem[427] = 4'h6;
      mem[428] = 4'h1;
      mem[429] = 4'h0;
      mem[430] = 4'h6;
      mem[431] = 4'h0;
      mem[432] = 4'h0;
      mem[433] = 4'h6;
      mem[434] = 4'h0;
      mem[435] = 4'h0;
      mem[436] = 4'h6;
      mem[437] = 4'h0;
      mem[438] = 4'h0;
      mem[439] = 4'h6;
      mem[440] = 4'h0;
      mem[441] = 4'h0;
      mem[442] = 4'h6;
      mem[443] = 4'h0;
      mem[444] = 4'h0;
      mem[445] = 4'h6;
      mem[446] = 4'h7;
      mem[447] = 4'h2;
      mem[448] = 4'h6;
      mem[449] = 4'h5;
      mem[450] = 4'h2;
      mem[451] = 4'h3;
      mem[452] = 4'h3;
      mem[453] = 4'h0;
      mem[454] = 4'h7;
      mem[455] = 4'h0;
      mem[456] = 4'h1;
      mem[457] = 4'h8;
      mem[458] = 4'h6;
      mem[459] = 4'h2;
      mem[460] = 4'hd;
      mem[461] = 4'h0;
      mem[462] = 4'h0;
      mem[463] = 4'h0;
      mem[464] = 4'h1;
      mem[465] = 4'h2;
      mem[466] = 4'h0;
      mem[467] = 4'h0;
      mem[468] = 4'h8;
      mem[469] = 4'h4;
      mem[470] = 4'h7;
      mem[471] = 4'hb;
      mem[472] = 4'h5;
      mem[473] = 4'h7;
      mem[474] = 4'h7;
      mem[475] = 4'h0;
      mem[476] = 4'h6;
      mem[477] = 4'h0;
      mem[478] = 4'h8;
      mem[479] = 4'h6;
      mem[480] = 4'h9;
      mem[481] = 4'h6;
      mem[482] = 4'h6;
      mem[483] = 4'h0;
      mem[484] = 4'h0;
      mem[485] = 4'h6;
      mem[486] = 4'h0;
      mem[487] = 4'h1;
      mem[488] = 4'h3;
      mem[489] = 4'h3;
      mem[490] = 4'h0;
      mem[491] = 4'h7;
      mem[492] = 4'h6;
      mem[493] = 4'h0;
      mem[494] = 4'h8;
      mem[495] = 4'h6;
      mem[496] = 4'h9;
      mem[497] = 4'h6;
      mem[498] = 4'h6;
      mem[499] = 4'h1;
      mem[500] = 4'h0;
      mem[501] = 4'h6;
      mem[502] = 4'h8;
      mem[503] = 4'he;
      mem[504] = 4'h3;
      mem[505] = 4'h3;
      mem[506] = 4'h0;
      mem[507] = 4'h7;
      mem[508] = 4'h6;
      mem[509] = 4'h0;
      mem[510] = 4'h8;
      mem[511] = 4'h6;
      mem[512] = 4'h9;
      mem[513] = 4'h6;
      mem[514] = 4'h6;
      mem[515] = 4'h1;
      mem[516] = 4'h8;
      mem[517] = 4'h6;
      mem[518] = 4'h8;
      mem[519] = 4'h5;
      mem[520] = 4'h3;
      mem[521] = 4'h3;
      mem[522] = 4'h0;
      mem[523] = 4'h7;
      mem[524] = 4'h6;
      mem[525] = 4'h0;
      mem[526] = 4'h8;
      mem[527] = 4'h6;
      mem[528] = 4'h2;
      mem[529] = 4'hd;
      mem[530] = 4'h3;
      mem[531] = 4'h3;
      mem[532] = 4'h0;
      mem[533] = 4'h7;
      mem[534] = 4'h0;
      mem[535] = 4'h0;
   end
   always @(posedge clk) data <= mem[adr[9:0]];
endmodule

module usb_hid_host (
    input  usbclk,		            // 12MHz clock
    input  usbrst_n,	            // reset
    inout  usb_dm, usb_dp,          // USB D- and D+

    output reg [1:0] typ,           // device type. 0: no device, 1: keyboard, 2: mouse, 3: gamepad
    output reg report,              // pulse after report received from device. 
                                    // key_*, mouse_*, game_* valid depending on typ
    output conerr,                  // connection or protocol error

    // keyboard
    output reg [7:0] key_modifiers,
    output reg [7:0] key1, key2, key3, key4,

    // mouse
    output reg [7:0] mouse_btn,     // {5'bx, middle, right, left}
    output reg signed [7:0] mouse_dx,      // signed 8-bit, cleared after `report` pulse
    output reg signed [7:0] mouse_dy,      // signed 8-bit, cleared after `report` pulse

    // gamepad 
    output reg game_l, game_r, game_u, game_d,  // left right up down
    output reg game_a, game_b, game_x, game_y, game_sel, game_sta,  // buttons

    // debug
    output [63:0] dbg_hid_report	// last HID report
);

wire data_rdy;          // data ready
wire data_strobe;       // data strobe for each byte
wire [7:0] ukpdat;		// actual data
reg [7:0] regs [7];     // 0 (VID_L), 1 (VID_H), 2 (PID_L), 3 (PID_H), 4 (INTERFACE_CLASS), 5 (INTERFACE_SUBCLASS), 6 (INTERFACE_PROTOCOL)
wire save;			    // save dat[b] to output register r
wire [3:0] save_r;      // which register to save to
wire [3:0] save_b;      // dat[b]
wire connected;
wire ignore;

ukp ukp(
    .usbrst_n(usbrst_n), .usbclk(usbclk),
    .usb_dp(usb_dp), .usb_dm(usb_dm), .usb_oe(ignore),
    .ukprdy(data_rdy), .ukpstb(data_strobe), .ukpdat(ukpdat), .save(save), .save_r(save_r), .save_b(save_b),
    .connected(connected), .conerr(conerr));

reg  [3:0] rcvct;		// counter for recv data
reg  data_strobe_r, data_rdy_r;	// delayed data_strobe and data_rdy
reg  [7:0] dat[8];		// data in last response
assign dbg_hid_report = {dat[7], dat[6], dat[5], dat[4], dat[3], dat[2], dat[1], dat[0]};
// assign dbg_regs = regs;

// Gamepad types, see response_recognition below
// localparam D_GENERIC = 0;
// localparam D_GAMEPAD = 1;			
// localparam D_DS2_ADAPTER = 2;
// reg [3:0] dev = D_GENERIC;			// device type recognized through VID/PID
// assign dbg_dev = dev;

reg valid = 0;		    // whether current gamepad report is valid

always @(posedge usbclk) begin : process_in_data
    data_rdy_r <= data_rdy; data_strobe_r <= data_strobe;
    report <= 0;                    // ensure pulse
    if (report == 1) begin
        // clear mouse movement for later
        mouse_dx <= 0; mouse_dy <= 0;
    end
    if(~data_rdy) rcvct <= 0;
    else begin
        if(data_strobe && ~data_strobe_r) begin  // rising edge of ukp data strobe
            dat[rcvct[2:0]] <= ukpdat;

            if (typ == 1) begin     // keyboard
                case (rcvct)
                0: key_modifiers <= ukpdat;
                2: key1 <= ukpdat;
                3: key2 <= ukpdat;
                4: key3 <= ukpdat;
                5: key4 <= ukpdat;
                endcase
            end else if (typ == 2) begin    // mouse
                case (rcvct)
                0: mouse_btn <= ukpdat;
                1: mouse_dx <= ukpdat;
                2: mouse_dy <= ukpdat;
                endcase
            end else if (typ == 3) begin    // gamepad
                // A typical report layout:
                // - d[3] is X axis (0: left, 255: right)
                // - d[4] is Y axis
                // - d[5][7:4] is buttons YBAX
                // - d[6][5:4] is buttons START,SELECT
                // Variations:
                // - Some gamepads uses d[0] and d[1] for X and Y axis.
                // - Some transmits a different set when d[0][1:0] is 2 (a dualshock adapater)
                case (rcvct)
                0: begin
                    if (ukpdat[1:0] != 2'b10) begin
                        // for DualShock2 adapter, 2'b10 marks an irrelevant record
                        valid <= 1;
                        game_l <= 0; game_r <= 0; game_u <= 0; game_d <= 0;
                    end else
                        valid <= 0;
                    if (ukpdat==8'h00) {game_l, game_r} <= 2'b10;
                    if (ukpdat==8'hff) {game_l, game_r} <= 2'b01;
                end
                1: begin
                    if (ukpdat==8'h00) {game_u, game_d} <= 2'b10;
                    if (ukpdat==8'hff) {game_u, game_d} <= 2'b01;
                end
                3: if (valid) begin 
                    if (ukpdat[7:6]==2'b00) {game_l, game_r} <= 2'b10;
                    if (ukpdat[7:6]==2'b11) {game_l, game_r} <= 2'b01;
                end
                4: if (valid) begin 
                    if (ukpdat[7:6]==2'b00) {game_u, game_d} <= 2'b10;
                    if (ukpdat[7:6]==2'b11) {game_u, game_d} <= 2'b01;
                end
                5: if (valid) begin
                    game_x <= ukpdat[4];
                    game_a <= ukpdat[5];
                    game_b <= ukpdat[6];
                    game_y <= ukpdat[7];
                end
                6: if (valid) begin
                    game_sel <= ukpdat[4];
                    game_sta <= ukpdat[5];
                end
                endcase
                // TODO: add any special handling if needed 
                // (using the detected controller type in 'dev')                
            end
            rcvct <= rcvct + 1;
        end
    end
    if(~data_rdy && data_rdy_r && typ != 0)    // falling edge of ukp data ready
        report <= 1;
end

reg save_delayed;
reg connected_r;
always @(posedge usbclk) begin : response_recognition
    save_delayed <= save;
    if (save) begin
        regs[save_r[2:0]] <= dat[save_b[2:0]];
    end else if (save_delayed && ~save && save_r == 6) begin     
        // falling edge of save for bInterfaceProtocol
        if (regs[4] == 3) begin  // bInterfaceClass. 3: HID, other: non-HID
            if (regs[5] == 1)    // bInterfaceSubClass. 1: Boot device
                typ <= regs[6] == 1 ? 1 : 2;     // bInterfaceProtocol. 1: keyboard, 2: mouse
            else
                typ <= 3;       // gamepad
        end else
            typ <= 0;                   
    end
    connected_r <= connected;
    if (~connected & connected_r) typ <= 0;   // clear device type on disconnect
end

endmodule

module ukp(
    input usbrst_n,
    input usbclk,				// 12MHz clock
    inout usb_dp, usb_dm,		// D+, D-
    output usb_oe,
    output reg ukprdy, 			// data frame is outputing
    output ukpstb,				// strobe for a byte within the frame
    output reg [7:0] ukpdat,	// output data when ukpstb=1
    output reg save,			// save: regs[save_r] <= dat[save_b]
    output reg [3:0] save_r, save_b,
    output reg connected,
    output conerr
);

    parameter S_OPCODE = 0;
    parameter S_LDI0 = 1;
    parameter S_LDI1 = 2;
    parameter S_B0 = 3;
    parameter S_B1 = 4;
    parameter S_B2 = 5;
    parameter S_S0 = 6;
    parameter S_S1 = 7;
    parameter S_S2 = 8;
    parameter S_TOGGLE0 = 9;
    parameter S_TOGGLE1 = 10;

    wire [3:0] inst;
    reg  [3:0] insth;
    wire sample;						// 1: an IN sample is available
    // reg connected = 0;
    reg inst_ready = 0, up = 0, um = 0, cond = 0, nak = 0, dmis = 0;
    reg ug, ugw, nrzon;					// ug=1: output enabled, 0: hi-Z
    reg bank = 0, record1 = 0;
    reg [1:0] mbit = 0;					// 1: out4/outb is transmitting
    reg [3:0] state = 0, stated;
    reg [7:0] wk = 0;					// W register
    reg [7:0] sb = 0;					// out value
    reg [3:0] sadr;						// out4/outb write ptr
    reg [13:0] pc = 0, wpc;				// program counter, wpc = next pc
    reg [2:0] timing = 0;				// T register (0~7)
    reg [3:0] lb4 = 0, lb4w;
    reg [13:0] interval = 0;
    reg [6:0] bitadr = 0;				// 0~127
    reg [7:0] data = 0;					// received data
    reg [2:0] nrztxct, nrzrxct;			// NRZI trans/recv count for bit stuffing
    wire interval_cy = interval == 12001;
    wire next = ~(state == S_OPCODE & (
        inst ==2 & dmi |								// start
        (inst==4 || inst==5) & timing != 0 |			// out0/hiz
        inst ==13 & (~sample | (dpi | dmi) & wk != 1) |	// in 
        inst ==14 & ~interval_cy						// wait
    ));
    wire branch = state == S_B1 & cond;
    wire retpc  = state == S_OPCODE && inst==7  ? 1 : 0;
    wire jmppc  = state == S_OPCODE && inst==15 ? 1 : 0;
    wire dbit   = sb[7-sadr[2:0]];
    wire record;
    reg  dmid;
    reg [23:0] conct;
    assign conerr = conct[23] || ~usbrst_n;

    usb_hid_host_rom ukprom(.clk(usbclk), .adr(pc), .data(inst));

    always @(posedge usbclk) begin
        if(~usbrst_n) begin 
            pc <= 0; connected <= 0; cond <= 0; inst_ready <= 0; state <= S_OPCODE; timing <= 0; 
            mbit <= 0; bitadr <= 0; nak <= 1; ug <= 0;
        end else begin
            dpi <= usb_dp; dmi <= usb_dm;
            save <= 0;		// ensure pulse
            if (inst_ready) begin
                // Instruction decoding
                case(state)
                    S_OPCODE: begin
                        insth <= inst;
                        if(inst==1) state <= S_LDI0;						// op=ldi
                        if(inst==3) begin sadr <= 3; state <= S_S0; end		// op=out4
                        if(inst==4) begin /*ug <= 9; jld */ ug <= 1; up <= 0; um <= 0; end
                        if(inst==5) begin ug <= 0; end
                        if(inst==6) begin sadr <= 7; state <= S_S0; end		// op=outb
                        if (inst[3:2]==2'b10) begin							// op=10xx(BZ,BC,BNAK,DJNZ)
                            state <= S_B0;
                            case (inst[1:0])
                                2'b00: cond <= ~dmi;
                                2'b01: cond <= connected;
                                2'b10: cond <= nak;
                                2'b11: cond <= wk != 1;
                            endcase
                        end
                        if(inst==11 | inst==13 & sample) wk <= wk - 8'd1;	// op=DJNZ,IN
                        if(inst==15) begin state <= S_B2; cond <= 1; end	// op=jmp
                        if(inst==12) state <= S_TOGGLE0;
                    end
                    // Instructions with operands
                    // ldi
                    S_LDI0: begin	wk[3:0] <= inst; state <= S_LDI1;	end
                    S_LDI1: begin	wk[7:4] <= inst; state <= S_OPCODE; end
                    // branch/jmp
                    S_B2: begin lb4w <= inst; state <= S_B0; end
                    S_B0: begin lb4  <= inst; state <= S_B1; end
                    S_B1: state <= S_OPCODE;
                    // out
                    S_S0: begin sb[3:0] <= inst; state <= S_S1; end
                    S_S1: begin sb[7:4] <= inst; state <= S_S2; mbit <= 1; end
                    // toggle and save
                    S_TOGGLE0: begin 
                        if (inst == 15) connected <= ~connected;// toggle
                        else save_r <= inst;                    // save
                        state <= S_TOGGLE1;
                      end
                    S_TOGGLE1: begin
                        if (inst != 15) begin
                            save_b <= inst;
                            save <= 1;
                        end
                        state <= S_OPCODE;
                    end
                endcase
                // pc control
                if (mbit==0) begin 
                    if(jmppc) wpc <= pc + 4;
                    if (next | branch | retpc) begin
                        if(retpc) pc <= wpc;					// ret
                        else if(branch)
                            if(insth==15)						// jmp
                                pc <= { inst, lb4, lb4w, 2'b00 };
                            else								// branch
                                pc <= { 4'b0000, inst, lb4, 2'b00 };
                        else	pc <= pc + 1;					// next
                        inst_ready <= 0;
                    end
                end
            end
            else inst_ready <= 1;
            // bit transmission (out4/outb)
            if (mbit==1 && timing == 0) begin
                if(ug==0) nrztxct <= 0;
                else
                    if(dbit) nrztxct <= nrztxct + 1;
                    else     nrztxct <= 0;
                if(insth == 4'd6) begin
                    if(nrztxct!=6) begin up <= dbit ?  up : ~up; um <= dbit ? ~up :  up; end
                    else           begin up <= ~up; um <= up; nrztxct <= 0; end
                end else begin
                    up <=  sb[{1'b1,sadr[1:0]}]; um <= sb[sadr[2:0]];
                end
                ug <= 1'b1; 
                if(nrztxct!=6) sadr <= sadr - 4'd1;
                if(sadr==0) begin mbit <= 0; state <= S_OPCODE; end
            end
            // start instruction
            dmid <= dmi;
            if (inst_ready & state == S_OPCODE & inst == 4'b0010) begin // op=start 
                bitadr <= 0; nak <= 1; nrzrxct <= 0;
            end else 
                if(ug==0 && dmi!=dmid) timing <= 1;
                else                   timing <= timing + 1;
            // IN instruction
            if (sample) begin
                if (bitadr == 8) nak <= dmi;
                if(nrzrxct!=6) begin
                    data[6:0] <= data[7:1]; 
                    data[7] <= dmis ~^ dmi;		    // ~^/^~ is XNOR, testing bit equality
                    bitadr <= bitadr + 1; nrzon <= 0;
                end else nrzon <= 1;
                dmis <= dmi;
                if(dmis ~^ dmi) nrzrxct <= nrzrxct + 1;
                else           nrzrxct <= 0;
                if (~dmi && ~dpi) ukprdy <= 0;      // SE0: packet is finished. Mouses send length 4 reports.
            end
            if (ug==0) begin
                if(bitadr==24) ukprdy <= 1;			// ignore first 3 bytes
                if(bitadr==88) ukprdy <= 0;			// output next 8 bytes
            end
            if ((bitadr>11 & bitadr[2:0] == 3'b000) & (timing == 2)) ukpdat <= data;
            // Timing
            interval <= interval_cy ? 0 : interval + 1;
            record1 <= record;
            if (~record & record1) bank <= ~bank;
            // Connection status & WDT
            ukprdyd <= ukprdy;
            nakd <= nak;
            if (ukprdy && ~ukprdyd || inst_ready && state == S_OPCODE && inst == 4'b0010) 
                conct <= 0;     // reset watchdog on data received or START instruction
            else begin 
                if(conct[23:22]!=2'b11) conct <= conct + 1;
                else begin pc <= 0; conct <= 0; end		// !! WDT ON
            end 
        end
    end

    assign usb_dp = ug ? up : 1'bZ;
    assign usb_dm = ug ? um : 1'bZ;
    assign usb_oe = ug;
    assign sample = inst_ready & state == S_OPCODE & inst == 4'b1101 & timing == 4; // IN
    assign record = connected & ~nak;
    assign ukpstb = ~nrzon & ukprdy & (bitadr[2:0] == 3'b100) & (timing == 2);
    reg    dpi, dmi; 
    reg    ukprdyd;
    reg    nakd;
endmodule

