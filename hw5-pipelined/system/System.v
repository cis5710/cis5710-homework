`default_nettype none
module txuartlite (
	i_clk,
	i_reset,
	i_wr,
	i_data,
	o_uart_tx,
	o_busy
);
	parameter [4:0] TIMING_BITS = 5'd24;
	localparam TB = TIMING_BITS;
	parameter [TB - 1:0] CLOCKS_PER_BAUD = 217;
	input wire i_clk;
	input wire i_reset;
	input wire i_wr;
	input wire [7:0] i_data;
	output reg o_uart_tx;
	output wire o_busy;
	localparam [3:0] TXUL_BIT_ZERO = 4'h0;
	localparam [3:0] TXUL_STOP = 4'h8;
	localparam [3:0] TXUL_IDLE = 4'hf;
	reg [TB - 1:0] baud_counter;
	reg [3:0] state;
	reg [7:0] lcl_data;
	reg r_busy;
	reg zero_baud_counter;
	initial r_busy = 1'b1;
	initial state = TXUL_IDLE;
	always @(posedge i_clk)
		if (i_reset) begin
			r_busy <= 1'b1;
			state <= TXUL_IDLE;
		end
		else if (!zero_baud_counter)
			r_busy <= 1'b1;
		else if (state > TXUL_STOP) begin
			state <= TXUL_IDLE;
			r_busy <= 1'b0;
			if (i_wr && !r_busy) begin
				r_busy <= 1'b1;
				state <= TXUL_BIT_ZERO;
			end
		end
		else begin
			r_busy <= 1'b1;
			if (state <= TXUL_STOP)
				state <= state + 1'b1;
			else
				state <= TXUL_IDLE;
		end
	assign o_busy = r_busy;
	initial lcl_data = 8'hff;
	always @(posedge i_clk)
		if (i_reset)
			lcl_data <= 8'hff;
		else if (i_wr && !r_busy)
			lcl_data <= i_data;
		else if (zero_baud_counter)
			lcl_data <= {1'b1, lcl_data[7:1]};
	initial o_uart_tx = 1'b1;
	always @(posedge i_clk)
		if (i_reset)
			o_uart_tx <= 1'b1;
		else if (i_wr && !r_busy)
			o_uart_tx <= 1'b0;
		else if (zero_baud_counter)
			o_uart_tx <= lcl_data[0];
	initial zero_baud_counter = 1'b1;
	initial baud_counter = 0;
	always @(posedge i_clk)
		if (i_reset) begin
			zero_baud_counter <= 1'b1;
			baud_counter <= 0;
		end
		else begin
			zero_baud_counter <= baud_counter == 1;
			if (state == TXUL_IDLE) begin
				baud_counter <= 0;
				zero_baud_counter <= 1'b1;
				if (i_wr && !r_busy) begin
					baud_counter <= CLOCKS_PER_BAUD - 1'b1;
					zero_baud_counter <= 1'b0;
				end
			end
			else if (!zero_baud_counter)
				baud_counter <= baud_counter - 1'b1;
			else if (state > TXUL_STOP) begin
				baud_counter <= 0;
				zero_baud_counter <= 1'b1;
			end
			else if (state == TXUL_STOP)
				baud_counter <= CLOCKS_PER_BAUD - 2;
			else
				baud_counter <= CLOCKS_PER_BAUD - 1'b1;
		end
endmodule
`default_nettype none
module rxuartlite (
	i_clk,
	i_reset,
	i_uart_rx,
	o_wr,
	o_data
);
	parameter TIMER_BITS = 10;
	parameter [TIMER_BITS - 1:0] CLOCKS_PER_BAUD = 217;
	localparam TB = TIMER_BITS;
	localparam [3:0] RXUL_BIT_ZERO = 4'h0;
	localparam [3:0] RXUL_BIT_ONE = 4'h1;
	localparam [3:0] RXUL_BIT_TWO = 4'h2;
	localparam [3:0] RXUL_BIT_THREE = 4'h3;
	localparam [3:0] RXUL_BIT_FOUR = 4'h4;
	localparam [3:0] RXUL_BIT_FIVE = 4'h5;
	localparam [3:0] RXUL_BIT_SIX = 4'h6;
	localparam [3:0] RXUL_BIT_SEVEN = 4'h7;
	localparam [3:0] RXUL_STOP = 4'h8;
	localparam [3:0] RXUL_WAIT = 4'h9;
	localparam [3:0] RXUL_IDLE = 4'hf;
	input wire i_clk;
	input wire i_reset;
	input wire i_uart_rx;
	output reg o_wr;
	output reg [7:0] o_data;
	wire [TB - 1:0] half_baud;
	reg [3:0] state;
	assign half_baud = {1'b0, CLOCKS_PER_BAUD[TB - 1:1]};
	reg [TB - 1:0] baud_counter;
	reg zero_baud_counter;
	reg q_uart;
	reg qq_uart;
	reg ck_uart;
	reg [TB - 1:0] chg_counter;
	reg half_baud_time;
	reg [7:0] data_reg;
	initial q_uart = 1'b1;
	initial qq_uart = 1'b1;
	initial ck_uart = 1'b1;
	always @(posedge i_clk)
		if (i_reset)
			{ck_uart, qq_uart, q_uart} <= 3'b111;
		else
			{ck_uart, qq_uart, q_uart} <= {qq_uart, q_uart, i_uart_rx};
	initial chg_counter = {TB {1'b1}};
	always @(posedge i_clk)
		if (i_reset)
			chg_counter <= {TB {1'b1}};
		else if (qq_uart != ck_uart)
			chg_counter <= 0;
		else if (chg_counter != {TB {1'b1}})
			chg_counter <= chg_counter + 1;
	initial half_baud_time = 0;
	always @(posedge i_clk)
		if (i_reset)
			half_baud_time <= 0;
		else
			half_baud_time <= !ck_uart && (chg_counter >= (half_baud - (1'b1 + 1'b1)));
	initial state = RXUL_IDLE;
	always @(posedge i_clk)
		if (i_reset)
			state <= RXUL_IDLE;
		else if (state == RXUL_IDLE) begin
			state <= RXUL_IDLE;
			if (!ck_uart && half_baud_time)
				state <= RXUL_BIT_ZERO;
		end
		else if ((state >= RXUL_WAIT) && ck_uart)
			state <= RXUL_IDLE;
		else if (zero_baud_counter) begin
			if (state <= RXUL_STOP)
				state <= state + 1;
		end
	always @(posedge i_clk)
		if (zero_baud_counter && (state != RXUL_STOP))
			data_reg <= {qq_uart, data_reg[7:1]};
	initial o_wr = 1'b0;
	initial o_data = 8'h00;
	always @(posedge i_clk)
		if (i_reset) begin
			o_wr <= 1'b0;
			o_data <= 8'h00;
		end
		else if ((zero_baud_counter && (state == RXUL_STOP)) && ck_uart) begin
			o_wr <= 1'b1;
			o_data <= data_reg;
		end
		else
			o_wr <= 1'b0;
	initial baud_counter = 0;
	always @(posedge i_clk)
		if (i_reset)
			baud_counter <= 0;
		else if (((state == RXUL_IDLE) && !ck_uart) && half_baud_time)
			baud_counter <= CLOCKS_PER_BAUD - 1'b1;
		else if (state == RXUL_WAIT)
			baud_counter <= 0;
		else if (zero_baud_counter && (state < RXUL_STOP))
			baud_counter <= CLOCKS_PER_BAUD - 1'b1;
		else if (!zero_baud_counter)
			baud_counter <= baud_counter - 1'b1;
	initial zero_baud_counter = 1'b1;
	always @(posedge i_clk)
		if (i_reset)
			zero_baud_counter <= 1'b1;
		else if (((state == RXUL_IDLE) && !ck_uart) && half_baud_time)
			zero_baud_counter <= 1'b0;
		else if (state == RXUL_WAIT)
			zero_baud_counter <= 1'b1;
		else if (zero_baud_counter && (state < RXUL_STOP))
			zero_baud_counter <= 1'b0;
		else if (baud_counter == 1)
			zero_baud_counter <= 1'b1;
endmodule
module SystemDemo (
	external_clk_25MHz,
	ftdi_txd,
	btn,
	led,
	ftdi_rxd,
	wifi_gpio0
);
	reg _sv2v_0;
	input external_clk_25MHz;
	input ftdi_txd;
	input [6:0] btn;
	output wire [7:0] led;
	output wire ftdi_rxd;
	output wire wifi_gpio0;
	localparam MAX_INPUT_WIDTH = 64;
	wire [7:0] rx_data;
	wire rx_ready;
	reg [7:0] tx_data;
	wire tx_ready;
	wire tx_busy;
	reg [5:0] tx_index;
	reg [5:0] tx_index_next;
	rxuartlite uart_receive(
		.i_clk(external_clk_25MHz),
		.i_reset(1'b0),
		.i_uart_rx(ftdi_txd),
		.o_wr(rx_ready),
		.o_data(rx_data)
	);
	txuartlite uart_transmit(
		.i_clk(external_clk_25MHz),
		.i_reset(1'b0),
		.i_wr(tx_ready),
		.i_data(tx_data),
		.o_uart_tx(ftdi_rxd),
		.o_busy(tx_busy)
	);
	reg [7:0] pool [0:63];
	reg [7:0] pool_next [0:63];
	reg [5:0] len;
	reg [5:0] len_next;
	reg input_done;
	reg input_done_next;
	initial len = 0;
	initial input_done = 0;
	initial tx_index = 0;
	initial begin : sv2v_autoblock_1
		reg signed [31:0] i;
		for (i = 0; i < MAX_INPUT_WIDTH; i = i + 1)
			pool[i] = 8'h00;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		len_next = len;
		input_done_next = input_done;
		tx_index_next = tx_index;
		tx_data = 8'h00;
		begin : sv2v_autoblock_2
			reg signed [31:0] i;
			for (i = 0; i < MAX_INPUT_WIDTH; i = i + 1)
				pool_next[i] = pool[i];
		end
		if (rx_ready && (input_done == 0)) begin
			pool_next[len] = rx_data;
			if (rx_data == 8'h0d) begin
				len_next = len;
				input_done_next = 1'b1;
			end
			else
				len_next = len + 1;
		end
		else if (tx_ready) begin
			tx_index_next = tx_index + 1;
			tx_data = pool[tx_index];
			if (tx_index == len) begin
				tx_index_next = 0;
				input_done_next = 0;
				len_next = 0;
				begin : sv2v_autoblock_3
					reg signed [31:0] i;
					for (i = 0; i < MAX_INPUT_WIDTH; i = i + 1)
						pool_next[i] = 8'h00;
				end
			end
		end
	end
	always @(posedge external_clk_25MHz) begin
		len <= len_next;
		input_done <= input_done_next;
		tx_index <= tx_index_next;
		begin : sv2v_autoblock_4
			reg signed [31:0] i;
			for (i = 0; i < MAX_INPUT_WIDTH; i = i + 1)
				pool[i] <= pool_next[i];
		end
	end
	assign led = {1'b0, len[2:0], 3'b000, input_done};
	assign tx_ready = input_done && !tx_busy;
	assign wifi_gpio0 = 1'b1;
	initial _sv2v_0 = 0;
endmodule