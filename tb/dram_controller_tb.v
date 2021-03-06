// Sai Kiran Lade
// University of Florida

`include "timescale.vh"


module dram_controller_tb;

	localparam	 integer NUMBER_OF_TESTS = 10000;
	
	//Given Specification
    localparam   integer NUMBER_OF_COLUMNS = 8;
    localparam   integer NUMBER_OF_ROWS = 128;
    localparam   integer NUMBER_OF_BANKS = 8; 
    localparam   integer REFRESH_RATE = 125; // ms
    localparam   integer CLK_FREQUENCY = 100; //KHz 
    localparam   integer U_DATA_WIDTH = 2;
    localparam   integer DRAM_DATA_WIDTH = 2; 
	
	//deduced from the given spec
	//DONOT pass values to the following localparams while declaring the module.
    localparam integer COLUMN_WIDTH = $clog2(NUMBER_OF_COLUMNS/DRAM_DATA_WIDTH); //bits required to accommodate coulmn addresses
    localparam integer ROW_WIDTH = $clog2(NUMBER_OF_ROWS); //bits required to accommodate rows addresses
    localparam integer BANK_ID_WIDTH = $clog2(NUMBER_OF_BANKS); //bits required to accommodate bank id
    localparam integer U_ADDR_WIDTH = BANK_ID_WIDTH + ROW_WIDTH + COLUMN_WIDTH; // address format : <bank_id; row_address; col_address>
    localparam integer CYCLES_BETWEEN_REFRESH = CLK_FREQUENCY*REFRESH_RATE; // number of clock cycles between consecutive refreshes //changes
    localparam integer DRAM_ADDR_WIDTH = ROW_WIDTH > COLUMN_WIDTH ? ROW_WIDTH : COLUMN_WIDTH; // since either column address or row address is sent at a time; dram address width = max(row_width; column_width)
    localparam integer REFRESH_COUNTER_WIDTH = $clog2(CYCLES_BETWEEN_REFRESH); // bits required to accommodate cycles_between_refresh
	
	reg                         u_rst_n; //reset; active low
    reg                         u_clk = 1'b0; //reg clock
	reg						  	u_en; //enables dram controller
    reg   [U_ADDR_WIDTH-1:0]    u_addr; //address : <bank_id; row_address; col_address>
    reg   [U_DATA_WIDTH-1:0]    u_data_i; //write data
    reg                         u_cmd; //command for controller
    wire  [U_DATA_WIDTH-1:0]    u_data_o; //read data
    wire                        u_data_valid; //valid flag for read data
    wire                        u_cmd_ack; //signal to acknowlege the execution of the requested command
    wire                        u_busy; // busy signal
	
	wire   [DRAM_DATA_WIDTH-1:0]   dram_rd_data; // data requested from dram
	wire						   dram_refresh_done; //indicates completion of refresh(will remain asserted for one cycle only)
    wire  [DRAM_DATA_WIDTH-1:0]   dram_wr_data; //data to be written
    wire  [DRAM_ADDR_WIDTH-1:0]   dram_addr; // row or column address of the data
    wire  [BANK_ID_WIDTH-1:0]     dram_bank_id; //bank address
    wire                          dram_cs_n; //chip select
    wire                          dram_ras_n; //RAS(row address strobe) command
    wire                          dram_cas_n; //CAS(column address strobe) command
    wire                          dram_we_n; //WE(write enable) command
    wire                          dram_clk_en; // clk enable
	
	reg [U_DATA_WIDTH-1:0]			prev_data_i; 
	reg	[U_ADDR_WIDTH-1:0]			prev_addr; 
	reg								prev_cmd;
	reg [U_DATA_WIDTH-1:0]			prev_data_o;
	reg [COLUMN_WIDTH-1:0]			prev_col_addr;
	reg [BANK_ID_WIDTH-1:0]			prev_bank_id;
	reg [ROW_WIDTH-1:0]				prev_row_addr;
	
	reg [NUMBER_OF_COLUMNS-1:0]		dummy[0:NUMBER_OF_ROWS-1][0:NUMBER_OF_BANKS-1]; // dummy memory 
	
	
	reg [$clog2(NUMBER_OF_TESTS)-1: 0] tests_failed = 0;
	
	
	integer i, j;
	
	dram_controller #
		(
			.NUMBER_OF_COLUMNS(NUMBER_OF_COLUMNS),
			.NUMBER_OF_ROWS(NUMBER_OF_ROWS),
			.NUMBER_OF_BANKS(NUMBER_OF_BANKS),
			.REFRESH_RATE(REFRESH_RATE),
			.CLK_FREQUENCY(CLK_FREQUENCY),
			.U_DATA_WIDTH(U_DATA_WIDTH),
			.DRAM_DATA_WIDTH(DRAM_DATA_WIDTH)
		)
	controller
		(
			.u_rst_n(u_rst_n),
			.u_clk(u_clk),
			.u_en(u_en),
			.u_addr(u_addr),
			.u_data_i(u_data_i),
			.u_cmd(u_cmd),
			.u_data_o(u_data_o),
			.u_data_valid(u_data_valid),
			.u_cmd_ack(u_cmd_ack),
			.u_busy(u_busy),
			
			.dram_rd_data(dram_rd_data),
			.dram_refresh_done(dram_refresh_done),
			.dram_wr_data(dram_wr_data),
			.dram_addr(dram_addr),
			.dram_bank_id(dram_bank_id),
			.dram_cs_n(dram_cs_n),
			.dram_ras_n(dram_ras_n),
			.dram_cas_n(dram_cas_n),
			.dram_we_n(dram_we_n),
			.dram_clk_en(dram_clk_en)
		);
		
	dram #
		(
			.NUMBER_OF_COLUMNS(NUMBER_OF_COLUMNS),
			.NUMBER_OF_ROWS(NUMBER_OF_ROWS),
			.NUMBER_OF_BANKS(NUMBER_OF_BANKS),
			.REFRESH_RATE(REFRESH_RATE),
			.CLK_FREQUENCY(CLK_FREQUENCY),
			.DRAM_DATA_WIDTH(DRAM_DATA_WIDTH)
		)
	memory
		(
			.dram_clk(u_clk),
			.dram_rst_n(u_rst_n),
			.dram_rd_data(dram_rd_data),
			.dram_refresh_done(dram_refresh_done),
			.dram_wr_data(dram_wr_data),
			.dram_addr(dram_addr),
			.dram_bank_id(dram_bank_id),
			.dram_cs_n(dram_cs_n),
			.dram_ras_n(dram_ras_n),
			.dram_cas_n(dram_cas_n),
			.dram_we_n(dram_we_n),
			.dram_clk_en(dram_clk_en)
		);
	
	//clock generator
	initial begin : generate_clock
	   $timeformat(-6, 0, "us");
		while(1)
	#5	u_clk = ~u_clk; //wait for 5us
	end
	
	initial begin : drive_inputs
		$timeformat(-6, 0, "us");
		u_rst_n <= 1'b1;
		u_en <= 1'b0;
		u_addr <= 0;
		u_data_i <= 0;
		u_cmd <= 0;
		
		for(i=0; i<10; i=i+1) @(posedge u_clk); //wait for 10 cycles
	
		u_rst_n <= 1'b0;
		
		for(i=0; i<10; i=i+1) @(posedge u_clk); //wait for 10 cycles
		
		u_rst_n <= 1'b1; 
		@(posedge u_clk);
		u_en <= 1'b1;
		
		for(i=0; i<NUMBER_OF_TESTS; i=i+1) begin
			wait(u_busy == 1'b0);
			@(negedge u_clk);
			u_addr <= $random;
			u_data_i <= $random;
			u_cmd <= $random;
			wait(u_cmd_ack == 1'b1);
			@(posedge u_clk);
			@(posedge u_clk);
		end
		
		wait(u_busy == 1'b1);
		
		for(i=0; i<10; i=i+1) @(posedge u_clk); //wait for 10 cycles
		
		$display("*******************************************************************************");
		$display("*******************************************************************************");
		$display("%0d tests passed out of %0d", NUMBER_OF_TESTS-tests_failed, NUMBER_OF_TESTS);
		$display("time: %0t: Simulation Closed!", $time);
		$display("*******************************************************************************");
		$display("*******************************************************************************");
		
		disable generate_clock;
		disable scoreboard ;	
	end

	reg [7:0] count = 0;
	integer m, n;
	
	initial begin : reset_dummy
		for(m=0; m<NUMBER_OF_BANKS; m=m+1) begin
			for(n=0; n<NUMBER_OF_ROWS; n=n+1) begin
				dummy[n][m] = 8'h00; // reset row(j) of bank(i)
				count = count + 1'b1; 
			end
		end
	end
	
	always begin : scoreboard
	   $timeformat(-6, 0, "us");
        @(posedge u_clk);
		if(!u_rst_n) begin
			// if(!u_rst_n) begin
				// for(i=0; i<NUMBER_OF_BANKS; i=i+1) begin
					// for(j=0; j<NUMBER_OF_ROWS; j=j+1) begin
						// dummy[j][i] = 0; // reset row(j) of bank(i)
					// end
				// end
			// end
			wait(u_cmd_ack == 1'b1);
			prev_addr = u_addr;
			prev_data_i = u_data_i;
			prev_cmd = u_cmd;
			
			prev_col_addr = prev_addr[COLUMN_WIDTH-1:0];
			prev_row_addr = prev_addr[COLUMN_WIDTH +: ROW_WIDTH];
			prev_bank_id = prev_addr[ROW_WIDTH+COLUMN_WIDTH +: BANK_ID_WIDTH];
			
			if(prev_cmd) dummy[prev_row_addr][prev_bank_id][prev_col_addr +: COLUMN_WIDTH] = prev_data_i; //write the data to dummy memory if it's a write transaction
			
			wait(u_busy == 1'b0); 
			if(prev_cmd == 1'b0) begin //READ
				wait(u_data_valid);
				prev_data_o = u_data_o;
				if(prev_data_o !== dummy[prev_row_addr][prev_bank_id][prev_col_addr +: COLUMN_WIDTH]) begin
					$display("ERROR: (time %0t): READ_OP: %d read instead of %d", $time, prev_data_o, dummy[prev_row_addr][prev_bank_id][prev_col_addr +: COLUMN_WIDTH]);
					tests_failed = tests_failed + 1;
				end
			end
		end
    end
	
endmodule