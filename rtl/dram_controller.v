// Sai Kiran Lade
// University of Florida

`include "timescale.vh"


module dram_controller #
  (
	//Given Specification
    parameter   integer NUMBER_OF_COLUMNS = 8,
    parameter   integer NUMBER_OF_ROWS = 128,
    parameter   integer NUMBER_OF_BANKS = 8, 
    parameter   integer REFRESH_RATE = 125, // ms
    parameter   integer CLK_FREQUENCY = 100, //KHz 
    parameter   integer U_DATA_WIDTH = 2,
    parameter   integer DRAM_DATA_WIDTH = 2, 
	
	//deduced from the given spec
	//DONOT pass values to the following parameters while declaring the module.
    parameter integer COLUMN_WIDTH = $clog2(NUMBER_OF_COLUMNS/DRAM_DATA_WIDTH), //bits required to accommodate coulmn addresses
    parameter integer ROW_WIDTH = $clog2(NUMBER_OF_ROWS), //bits required to accommodate rows addresses
    parameter integer BANK_ID_WIDTH = $clog2(NUMBER_OF_BANKS), //bits required to accommodate bank id
    parameter integer U_ADDR_WIDTH = BANK_ID_WIDTH + ROW_WIDTH + COLUMN_WIDTH, // address format : <bank_id, row_address, col_address>
    parameter integer CYCLES_BETWEEN_REFRESH = CLK_FREQUENCY*REFRESH_RATE - 100, // number of clock cycles between consecutive refreshes //changes
    parameter integer DRAM_ADDR_WIDTH = ROW_WIDTH > COLUMN_WIDTH ? ROW_WIDTH : COLUMN_WIDTH, // since either column address or row address is sent at a time, dram address width = max(row_width, column_width)
    parameter integer REFRESH_COUNTER_WIDTH = $clog2(CYCLES_BETWEEN_REFRESH) // bits required to accommodate cycles_between_refresh
  )
  (
    //user interface
    input                         u_rst_n, //reset, active low
    input                         u_clk, //input clock
	input						  u_en, //enables dram controller
    input   [U_ADDR_WIDTH-1:0]    u_addr, //address : <bank_id, row_address, col_address>
    input   [U_DATA_WIDTH-1:0]    u_data_i, //write data
    input                         u_cmd, //command for controller
    output  [U_DATA_WIDTH-1:0]    u_data_o, //read data
    output                        u_data_valid, //valid flag for read data
    output                        u_cmd_ack, //signal to acknowlege the execution of the requested command
    output                        u_busy, // busy signal


    //dram interface
    input   [DRAM_DATA_WIDTH-1:0]   dram_rd_data, // data requested from dram
	input							dram_refresh_done, //indicates completion of refresh(will remain asserted for one cycle only)
    output  [DRAM_DATA_WIDTH-1:0]   dram_wr_data, //data to be written
    output  [DRAM_ADDR_WIDTH-1:0]   dram_addr, // row or column address of the data
    output  [BANK_ID_WIDTH-1:0]     dram_bank_id, //bank address
    output                          dram_cs_n, //chip select
    output                          dram_ras_n, //RAS(row address strobe) command
    output                          dram_cas_n, //CAS(column address strobe) command
    output                          dram_we_n, //WE(write enable) command
    output                          dram_clk_en // clk enable
  );
	
    localparam
              STATE_WIDTH = 3,
              S_IDLE      = 3'h0, 
              S_PRECHARGE = 3'h1,
              S_ACTIVATE  = 3'h2,
              S_WRITE     = 3'h3,
              S_READ      = 3'h4,
              S_REFRESH   = 3'h5,
			  S_INIT	  = 3'h6,
			  S_REF_SETUP = 3'h7; // ######### changes made ###############
			  
    //I/O registers
             
    reg [REFRESH_COUNTER_WIDTH-1:0] refresh_count_r; // register to store cycles count between refreshes
    reg                             refresh_request_r; // status register to request refresh 

    reg [DRAM_ADDR_WIDTH-1:0]       column_addr_r; // coulmn address
    reg [DRAM_ADDR_WIDTH-1:0]       row_addr_r; // row address
    reg [BANK_ID_WIDTH-1:0]         bank_id_r; // bank id

    reg [STATE_WIDTH-1:0]           state_r, next_state, 
									target_state_r, next_target_state; 

    reg                             u_cmd_ack_r;
    reg                             u_cmd_r; 
    reg [U_DATA_WIDTH-1:0]          u_data_i_r;

	reg [NUMBER_OF_BANKS-1:0]		open_row_r;
	reg [ROW_WIDTH-1:0]				active_row_r[0:NUMBER_OF_BANKS-1];
	
	
   
    reg                          cs_n; //chip select
    reg                          ras_n; //RAS command
    reg                          cas_n; //CAS command
    reg                          we_n; //WE command
    reg                          clk_en;
    
	// registers used to realize data_valid flag logic
	reg							 read_flag, u_data_valid_r;
	
	reg	[U_DATA_WIDTH-1:0]		 u_data_o_r; //read data is sampled in this register
	
	reg	[DRAM_ADDR_WIDTH-1:0]	dram_addr_w;
	
	reg [47:0]	dram_state; 
	integer i;
	reg [BANK_ID_WIDTH-1:0] ref_bank_id;
	reg [DRAM_ADDR_WIDTH-1:0] ref_set_addr;
	
	
    assign u_cmd_ack = u_cmd_ack_r;
	
	assign dram_wr_data = u_data_i_r;
	assign dram_bank_id = ((state_r == S_PRECHARGE) && (target_state_r == S_REF_SETUP || target_state_r == S_REF_SETUP) ) ? ref_bank_id :  bank_id_r;
	assign dram_cs_n = u_en ? cs_n : 1'b0; //chip select = 0 when dram controller is disabled 
	assign dram_ras_n = ras_n;
	assign dram_cas_n = cas_n;
	assign dram_we_n = we_n;
	assign dram_clk_en = (u_en) ? clk_en : 1'b0; // clk enable = 0 when dram controller is disabled  ########## INSPECTION REQUIRED ###############
	assign u_busy = (state_r == S_IDLE) ? 1'b0 : 1'b1; 
	assign dram_addr = dram_addr_w;

	assign u_data_valid = u_data_valid_r;
	assign u_data_o = u_data_o_r;
	
	// convert state variable to string type for seeing state names in simulation
	always @ * begin
		case(state_r)
			S_IDLE: dram_state = "S_IDLE";
			S_ACTIVATE: dram_state = "S_ACTI";
			S_PRECHARGE: dram_state = "S_PREC";
			S_READ:	dram_state = "S_READ";
			S_WRITE: dram_state = "S_WRIT";
			S_REFRESH: dram_state = "S_REFR";
			S_REF_SETUP: dram_state = "S_RSET";
		endcase
	end
	
	//sampling input data
    always@ (posedge u_clk) begin
      if(!u_rst_n) begin
        column_addr_r <= 0;
        row_addr_r <= 0;
        bank_id_r <= 0;
        u_cmd_r <= 0;
        u_cmd_ack_r <= 0;
        u_data_i_r <= 0;
      end
      else if((state_r == S_IDLE) && (u_en == 1'b1) && (!u_cmd_ack)) begin
        column_addr_r <= {{(ROW_WIDTH-COLUMN_WIDTH){1'b0}}, u_addr[COLUMN_WIDTH-1:0]};
        row_addr_r <= u_addr[COLUMN_WIDTH +: ROW_WIDTH];
        bank_id_r <= u_addr[ROW_WIDTH+COLUMN_WIDTH +: BANK_ID_WIDTH];
        u_cmd_r <= u_cmd; //1 implies WRITE operation 0 implies READ operation
        u_cmd_ack_r <= 1'b1; //command execution confirmation
        if(u_cmd) u_data_i_r <= u_data_i; //sample input data incase of WRITE operation
      end
      else  u_cmd_ack_r <= 0;
    end
    
    //Update state and target states
    always@ (posedge u_clk) begin
	  if(!u_rst_n) begin
		state_r <= S_IDLE;
		target_state_r <= S_IDLE;
	  end
	  else if(u_en) begin
		state_r <= next_state;
		target_state_r <= next_target_state;
	  end
	end
	
	//FSM
	always@ * begin
		next_state = state_r;
		next_target_state = target_state_r;
		case(state_r)
			S_INIT: next_state = S_REFRESH; //boot the memory
			
			S_IDLE: begin
				if(refresh_request_r) begin 
					if(!open_row_r) next_state = S_REFRESH; //when there is no open row, execute refresh
					else begin
						next_state = S_REF_SETUP; // when there are any open rows execute precharge and close all the rows
						next_target_state = S_REF_SETUP;
					end
				end
				else if(u_cmd_ack_r) begin //confirms that inputs are sampled into respective registers
					if(open_row_r[bank_id_r] && (row_addr_r == active_row_r[bank_id_r])) begin //ROW hit
						if(u_cmd)	next_state = S_WRITE; //WRITE REQ
						else	next_state = S_READ; //READ REQ
					end
					else if(open_row_r[bank_id_r] && (row_addr_r != active_row_r[bank_id_r])) begin //ROW miss
						next_state = S_PRECHARGE; //dram address should be active_row address
						if(u_cmd)	next_target_state = S_WRITE;
						else	next_target_state = S_READ;
					end
					else begin // when row buffer is empty
						next_state = S_ACTIVATE;
						if(u_cmd)	next_target_state = S_WRITE;
						else	next_target_state = S_READ;
					end
				end
			end
			
			S_PRECHARGE: begin
				if(target_state_r == S_REFRESH) next_state = S_REFRESH; //closing all rows to perform refresh 
				else if(target_state_r == S_REF_SETUP) next_state = S_REF_SETUP;
				else next_state = S_ACTIVATE; //closing a row to open another //dram address should address of the active row buffer
			end
			
			S_ACTIVATE: next_state = target_state_r; //activate rows for read or write operation
			
			S_WRITE: next_state = S_IDLE;
			
			S_READ: next_state = S_IDLE;
			
			S_REF_SETUP: begin
				if(!open_row_r) begin 
					next_state = S_REFRESH;
					next_target_state = S_REFRESH;	
				end
				else begin 
					next_state = S_PRECHARGE;
					next_target_state = S_REF_SETUP;
				end
			end
			
			S_REFRESH: 
			     if(dram_refresh_done) begin 
			         next_state = S_IDLE;
			         next_target_state = S_IDLE;
			     end 
		endcase
	end
    
      //send appropriate commands
    always@ * begin
		clk_en	= 1'b1;
		cs_n	= 1'b0;
		ras_n	= 1'b1;
		cas_n	= 1'b1;
		we_n	= 1'b1;
		case(state_r)
			S_IDLE: begin
				//do nothing
			end
			
			S_PRECHARGE: begin
				ras_n = 1'b0;
				we_n = 1'b0;
			end
			
			S_ACTIVATE: ras_n = 1'b0;
			
			S_WRITE: begin
				cas_n = 1'b0;
				we_n = 1'b0;
			end
			
			S_READ: cas_n = 1'b0;
			
			S_REFRESH: begin
				ras_n = 1'b0;
				cas_n = 1'b0;
				we_n = 2'b0;
			end
		endcase
	  
    end
    
    // address mapping
	always@ * begin
		dram_addr_w = column_addr_r;
		case(state_r)
			S_PRECHARGE: begin
				if((state_r == S_PRECHARGE) && (target_state_r == S_REF_SETUP || target_state_r == S_REF_SETUP) ) dram_addr_w = ref_set_addr;
				else dram_addr_w = active_row_r[bank_id_r];  //load the address of existing data in row buffer.
			end
			S_ACTIVATE: dram_addr_w = row_addr_r;
			
			S_WRITE: dram_addr_w = column_addr_r;
			
			S_READ: dram_addr_w = column_addr_r;
		endcase
	end

    //Track active rows
	always@ (posedge u_clk) begin
		if(!u_rst_n) begin
			open_row_r <= 0;
			for (i=0; i<NUMBER_OF_BANKS; i = i+1) begin
				active_row_r[i] <= 0;
			end
		end
		else begin
			case(state_r) 
				S_ACTIVATE: begin
					active_row_r[bank_id_r] <= row_addr_r;
					open_row_r[bank_id_r] <= 1'b1;
				end
				S_PRECHARGE: begin
					if(target_state_r == S_REFRESH)	open_row_r <= 0; //close all banks
					if(target_state_r == S_REF_SETUP) open_row_r[ref_bank_id] <= 1'b0;
					else open_row_r[bank_id_r] <= 1'b0; // close that particular bank					
				end
			endcase
		end
	end
    

    //refresh_logic
    always@ (posedge u_clk) begin
      if(!u_rst_n) begin
        refresh_count_r <= CYCLES_BETWEEN_REFRESH[REFRESH_COUNTER_WIDTH-1:0];
        refresh_request_r <= 0;
      end
      else  begin
        if(!refresh_count_r) begin
			//execute the following line only when refresh operation is done. //###############################
          if(dram_refresh_done) begin
            refresh_count_r <= CYCLES_BETWEEN_REFRESH[REFRESH_COUNTER_WIDTH-1:0];
            refresh_request_r <= 0;
          end
          else refresh_request_r <= 1'b1;
        end
        else  begin
          refresh_count_r <= refresh_count_r - 1'b1;
          refresh_request_r <= 0;
        end
      end
    end

	always @* begin
		for(i=0; i<NUMBER_OF_BANKS; i=i+1) begin
			if(open_row_r[i]) begin
				ref_bank_id = i;
				i = NUMBER_OF_BANKS;
			end
		end
	end
	

	always@ (posedge u_clk) begin
		if(!u_rst_n) begin
			ref_set_addr <= 0;
		end
		else if(u_en && (state_r == S_REF_SETUP)) begin
			if(open_row_r[ref_bank_id])
				ref_set_addr <= active_row_r[ref_bank_id];
		end
	
	end

	//sampling read data and sending it user through u_data_o
	always@ (posedge u_clk) begin
		if(!u_rst_n) begin
			u_data_o_r <= 0;
			u_data_valid_r <= 1'b0;
			read_flag <= 1'b0;
		end
		else begin
			if(state_r == S_READ)  read_flag <= 1'b1; //realization is similar to 2 cycle delay logic(data_valid is delayed signal of read_flag)
			else if(state_r == S_IDLE && read_flag == 1'b1) begin
				u_data_o_r <= dram_rd_data;
				u_data_valid_r <= 1'b1;
				read_flag <= 1'b0;
			end
			else u_data_valid_r <= 1'b0;
		end
	end
	


endmodule



