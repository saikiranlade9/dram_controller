//Sai Kiran Lade
//Unviersity of Florida

module dram # 
	(
		//Given Specification
		parameter   integer NUMBER_OF_COLUMNS = 8, //############## Need to check with TAs ##############
		parameter   integer NUMBER_OF_ROWS = 128,
		parameter   integer NUMBER_OF_BANKS = 8, // ############## Need to check with TAs ##############
		parameter   integer REFRESH_RATE = 125, // ms
		parameter   integer CLK_FREQUENCY = 10, //MHz ######## Need to check with TAs ##############
		parameter   integer DRAM_DATA_WIDTH = 2, // ############## Need to check with TAs ##############
		
		//deduced from the given spec
		//DONOT pass values to the following parameters while declaring the module.
		parameter integer COLUMN_WIDTH = $clog2(NUMBER_OF_COLUMNS/DRAM_DATA_WIDTH), //bits required to accommodate coulmn addresses
		parameter integer ROW_WIDTH = $clog2(NUMBER_OF_ROWS), //bits required to accommodate rows addresses
		parameter integer BANK_ID_WIDTH = $clog2(NUMBER_OF_BANKS), //bits required to accommodate bank id
		parameter integer U_ADDR_WIDTH = BANK_ID_WIDTH + ROW_WIDTH + COLUMN_WIDTH, // address format : <bank_id, row_address, col_address>
		parameter integer CYCLES_BETWEEN_REFRESH = $floor(CLK_FREQUENCY*REFRESH_RATE/1000), // number of clock cycles between consecutive refreshes
		parameter integer DRAM_ADDR_WIDTH = ROW_WIDTH > COLUMN_WIDTH ? ROW_WIDTH : COLUMN_WIDTH, // since either column address or row address is sent at a time, dram address width = max(row_width, column_width)
		parameter integer REFRESH_COUNTER_WIDTH = $clog2(CYCLES_BETWEEN_REFRESH) // bits required to accommodate cycles_between_refresh
	)
	(
		input                         	dram_rst_n, //reset, active low
		input                         	dram_clk, //input clock
		output	[DRAM_DATA_WIDTH-1:0]   dram_rd_data, // data requested from dram
		output							dram_refresh_done, //indicates completion of refresh(will remain asserted for one cycle only)
		input	[DRAM_DATA_WIDTH-1:0]   dram_wr_data, //data to be written
		input	[DRAM_ADDR_WIDTH-1:0]   dram_addr, // row or column address of the data
		input  	[BANK_ID_WIDTH-1:0]     dram_bank_id, //bank address
		input                          	dram_cs_n, //chip select
		input                          	dram_ras_n, //RAS(row address strobe) command
		input                          	dram_cas_n, //CAS(column address strobe) command
		input                          	dram_we_n, //WE(write enable) command
		input                          	dram_clk_en // clk enable
	);
	
	//commands to be executed 
	localparam	C_WIDTH = 4,
				C_NOP = 4'b0111, //no operation
				C_PRECHARGE = 4'b0010, // precharge
				C_ACTIVATE = 4'b0011, //activate
				C_READ = 4'b0101, //read
				C_WRITE = 4'b0100, //write
				C_REFRESH = 4'b10001; //refresh
	
	//states to perform refresh
	localparam	REF_S_WIDTH = 2,
				REF_S_START = 2'h0, 
				REF_S_ACT = 2'h1,
				REF_S_PRE = 2'h2,
				REF_S_DONE = 2'h3;
		
	reg 							refresh_request_r; //request refresh operation
	reg								refresh_time_out_r; //asserted when refresh is not performed in time
	reg								refreshing; // asserted while performing refresh operation
	reg	[REFRESH_COUNTER_WIDTH-1:0]	refresh_counter_r;
	reg								dram_refresh_done_w; //asserted for one cycle after refresh operation is done
	reg	[DRAM_ADDR_WIDTH-1:0]		ref_addr_r, next_ref_addr; // registers for addresses while refreshing
	reg	[REF_S_WIDTH-1:0]			state_r, next_state;
	reg [NUMBER_OF_COLUMNS-1:0]		banks[0:NUMBER_OF_ROWS-1][0:NUMBER_OF_BANKS-1]; // memory 
	reg [NUMBER_OF_COLUMNS-1:0] 	row_buffers[0:NUMBER_OF_BANKS-1]; // row buffers
	reg	[DRAM_DATA_WIDTH-1:0] 		dram_rd_data_r; // register to store read data
	
	reg 						ref_act_flag, // asserted when precharge operation is done while refreshing
								ref_pre_flag; // asserted when activate operation is done while refreshing
	
	wire	[C_WIDTH-1:0]	command; //<cs, ras, cas, we>
	
	
	assign	command = {dram_cs_n, dram_ras_n, dram_cas_n, dram_we_n}; 
	assign 	dram_refresh_done = dram_refresh_done_w;
	
	integer i, j, k;
	
	//update dram(banks) and row buffers 
	always@ (posedge dram_clk) begin
		if(!dram_rst_n) begin
			for(i=0; i<NUMBER_OF_BANKS; i=i+1) begin
				row_buffers[i] <= '0; //reset row buffer of bank(i)
				for(j=0; j<NUMBER_OF_ROWS; j=j+1) begin
					banks[j][i] <= '0; // reset row(j) of bank(i)
				end
			end
			dram_rd_data_r <= '0; 
			refresh_request_r <= 1'b0;
		end
		
		else if(!dram_cs_n) begin
			if(refresh_time_out_r) begin
				for(i=0; i<NUMBER_OF_BANKS; i=i+1) begin
					row_buffers[i] <= $random; //destroy row buffer of bank(i)
					for(j=0; j<NUMBER_OF_ROWS; j=j+1) begin
						banks[j][i] <= $random; //destroy row(j) of bank(i)
					end
				end
			end
			
			else if(refreshing) begin
				if(ref_act_flag) begin
					for(i=0; i<NUMBER_OF_BANKS; i=i+1) begin
						row_buffers[i] <= banks[ref_addr_r][i]; //activate row(ref_ref_addr) of bank(i)
					end
				end
				else if(ref_pre_flag) begin
					for(i=0; i<NUMBER_OF_BANKS; i=i+1) begin
						banks[ref_addr_r][i] <= row_buffers[i];  //precharge row(ref_ref_addr) of bank(i)
					end
				end
			end
			
			else begin
				case(command)
					
					C_PRECHARGE: banks[dram_addr][dram_bank_id] <=  row_buffers[dram_bank_id];
					
					C_ACTIVATE: row_buffers[dram_bank_id] <= banks[dram_addr][dram_bank_id];
					
					C_READ:	dram_rd_data_r <=  row_buffers[dram_bank_id][dram_addr*DRAM_DATA_WIDTH +: DRAM_DATA_WIDTH];
					
					C_WRITE: row_buffers[dram_bank_id][dram_addr*DRAM_DATA_WIDTH +: DRAM_DATA_WIDTH] <=  dram_wr_data;
					
					C_REFRESH: refresh_request_r <= 1'b1;
					
				endcase
			end
		end
	
	end
	
	always@ (posedge dram_clk) begin
		if(!dram_rst_n) begin 
			state_r <= REF_S_START;
			ref_addr_r <= '0;
		end
		else if(!dram_cs_n) begin
			state_r <= next_state;
			ref_addr_r <= next_ref_addr;
		end
	end
	
	always@ * begin
		next_state = state_r;
		next_ref_addr = ref_addr_r;
		refreshing = 1'b0;
		ref_act_flag = 1'b0;
		ref_pre_flag = 1'b0;
		dram_refresh_done_w = 1'b0;
		case(state_r) 
			REF_S_START: begin
				if(refresh_request_r) begin
					next_state = REF_S_ACT; 
				end
			end
			
			REF_S_ACT: begin
				next_state = REF_S_PRE;
				ref_act_flag = 1'b1;
				refreshing = 1'b0;
			end
			
			REF_S_PRE: begin
				ref_pre_flag = 1'b1;
				next_ref_addr = ref_addr_r + 1'b1;
				refreshing = 1'b0;
				if(ref_addr_r == REFRESH_COUNTER_WIDTH'(NUMBER_OF_BANKS)) next_state = REF_S_DONE;
				else next_state = REF_S_ACT;
			end
			
			REF_S_DONE: begin
				dram_refresh_done_w = 1'b1;
				next_ref_addr = '0;
				next_state = REF_S_START;
			end
		endcase
		
	end
	
	always@ (posedge dram_clk) begin
		if(!dram_rst_n) begin 
			refresh_counter_r <= '0; //reset counter
			refresh_time_out_r <= 1'b0;
		end
		else if(refreshing) begin
			refresh_counter_r <= '0; 
			refresh_time_out_r <= 1'b0;
		end
		else begin
			refresh_counter_r <= refresh_counter_r + 1'b1;
			if(refresh_counter_r == CYCLES_BETWEEN_REFRESH) begin
				refresh_time_out_r <= 1'b1;
				refresh_counter_r <= '0;
			end
		end
		
			
	end
	
endmodule