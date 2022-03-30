// Sai Kiran Lade
// University of Florida

`timescale 1 ns / 100 ps

module dram_controller_tb;

	localparam	 integer NUMBER_OF_TESTS = 10000;
	//Given Specification
    localparam   integer NUMBER_OF_COLUMNS = 8;
    localparam   integer NUMBER_OF_ROWS = 128;
    localparam   integer NUMBER_OF_BANKS = 8; 
    localparam   integer REFRESH_RATE = 125; // ms
    localparam   integer CLK_FREQUENCY = 100; //KHz 
    localparam   integer U_DATA_WIDTH = 8;
    localparam   integer DRAM_DATA_WIDTH = 2; 
	
	//deduced from the given spec
	//DONOT pass values to the following localparams while declaring the module.
    localparam integer COLUMN_WIDTH = $clog2(NUMBER_OF_COLUMNS/DRAM_DATA_WIDTH); //bits required to accommodate coulmn addresses
    localparam integer ROW_WIDTH = $clog2(NUMBER_OF_ROWS); //bits required to accommodate rows addresses
    localparam integer BANK_ID_WIDTH = $clog2(NUMBER_OF_BANKS); //bits required to accommodate bank id
    localparam integer U_ADDR_WIDTH = BANK_ID_WIDTH + ROW_WIDTH + COLUMN_WIDTH; // address format : <bank_id; row_address; col_address>
    localparam integer CYCLES_BETWEEN_REFRESH = $floor(CLK_FREQUENCY*REFRESH_RATE/1000); // number of clock cycles between consecutive refreshes //changes
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
	
	wire   [DRAM_DATA_WIDTH-1:0]   dram_rd_data, // data requested from dram
	wire						   dram_refresh_done, //indicates completion of refresh(will remain asserted for one cycle only)
    wire  [DRAM_DATA_WIDTH-1:0]   dram_wr_data, //data to be written
    wire  [DRAM_ADDR_WIDTH-1:0]   dram_addr, // row or column address of the data
    wire  [BANK_ID_WIDTH-1:0]     dram_bank_id, //bank address
    wire                          dram_cs_n, //chip select
    wire                          dram_ras_n, //RAS(row address strobe) command
    wire                          dram_cas_n, //CAS(column address strobe) command
    wire                          dram_we_n, //WE(write enable) command
    wire                          dram_clk_en // clk enable
	
	dram_controller #
		(
			.NUMBER_OF_COLUMNS(NUMBER_OF_COLUMNS),
			.NUMBER_OF_ROWS(NUMBER_OF_ROWS),
			.
		)
	controller
		(
		);
		
	dram #
		(
		)
	memory
		(
		);
	
	//clock generator
	initial begin
		while(1)
	#5 	u_clk = ~u_clk;
	end
	
	initial begin 
		$timeformat(-9, 0, "ns");
		
		u_rst_n = 1'b1;
		u_en = 1'b0;
		u_addr = '0;
		u_data_i = '0;
		u_cmd = '0;
		
		for(int i=0; i<10; i=i+1) @posedge(u_clk); //wait for 10 cycles
		
		u_rst_n = 1'b0;
		
		for(int i=0; i<10; i++) @posedge(u_clk); //wait for 10 cycles
		
		u_rst_n = 1'b1; 
		@posedge(u_clk);
		u_en = 1'b1;
		
		for(int i=0; i<NUMBER_OF_TESTS; i=i+1) begin
			u_addr = $random;
			u_data_i = $random;
			u_cmd = $random;
			wait(u_cmd_ack == 1'b1);
			@posedge(u_clk);
		end
		
		
		
	
	end