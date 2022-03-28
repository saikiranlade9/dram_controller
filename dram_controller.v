// Sai Kiran Lade
// University of Florida

module dram_controller #
  (
    parameter   integer NUMBER_OF_COLUMNS = 8,
    parameter   integer NUMBER_OF_ROWS = 128,
    parameter   integer NUMBER_OF_BANKS = 8,
    parameter   integer REFRESH_RATE = 125, // ms
    parameter   integer CLK_FREQUENCY = 10, //MHz
    parameter   integer U_DATA_WIDTH = 8,
    parameter   integer DRAM_DATA_WIDTH = 8,

    parameter integer COLUMN_WIDTH = $clog2(NUMBER_OF_COLUMNS),
    parameter integer ROW_WIDTH = $clog2(NUMBER_OF_ROWS),
    parameter integer BANK_ID_WIDTH = $clog2(NUMBER_OF_BANKS),
    parameter integer U_ADDR_WIDTH = BANK_ID_WIDTH + ROW_WIDTH + COLUMN_WIDTH,
    parameter integer CYCLES_BETWEEN_REFRESH = $floor(CLK_FREQUENCY*REFRESH_RATE/1000),
    parameter integer DRAM_ADDR_WIDTH = ROW_WIDTH > COLUMN_WIDTH ? ROW_WIDTH : COLUMN_WIDTH,
    parameter integer REFRESH_COUNTER_WIDTH = $clog2(CYCLES_BETWEEN_REFRESH)
  )
  (
    //host interface
    input                         u_rst_n, //reset, active low
    input                         u_clk, //input clock
	input						  u_en, //enable for controller
    input   [U_ADDR_WIDTH-1:0]    u_addr, //address
    input   [U_DATA_WIDTH-1:0]    u_data_i, //write data
    input                         u_cmd, //command for controller
    output  [U_DATA_WIDTH-1:0]    u_data_o, //read data
    output                        u_data_valid, //valid flag for read data
    output                        u_cmd_ack, //acknowledge signal for commands
    output                        u_busy,

    //dram interface
    input   [DRAM_DATA_WIDTH-1:0]   dram_rd_data, 
    output  [DRAM_DATA_WIDTH-1:0]   dram_wr_data, //data
    output  [DRAM_ADDR_WIDTH-1:0]   dram_addr,
    output  [BANK_ID_WIDTH-1:0]     dram_bank_id, //bank address
    output                          dram_cs_n, //chip select
    output                          dram_ras_n, //RAS command
    output                          dram_cas_n, //CAS command
    output                          dram_we_n, //WE command
    output                          dram_clk_en
  );

    localparam
              STATE_WIDTH = 3,
			  S_INIT	  = 3'h6,
              S_IDLE      = 3'h0,
              S_PRECHARGE = 3'h1,
              S_ACTIVATE  = 3'h2,
              S_WRITE     = 3'h3,
              S_READ      = 3'h4,
              S_REFRESH   = 3'h5;
    //I/O registers
             
    reg [REFRESH_COUNTER_WIDTH-1:0] refresh_count_r;
    reg                             refresh_request_r;

    reg [DRAM_ADDR_WIDTH-1:0]       column_addr_r;
    reg [DRAM_ADDR_WIDTH-1:0]       row_addr_r;
    reg [BANK_ID_WIDTH-1:0]         bank_id_r;

    reg [STATE_WIDTH-1:0]           state_r, next_state, target_state_r, next_target_state;

    reg                             u_cmd_ack_r;
    reg                             u_cmd_r; 
    reg [U_DATA_WIDTH-1:0]          u_data_i_r;

	reg [NUMBER_OF_BANKS-1:0]		open_row_r;
	reg [ROW_WIDTH-1:0]				active_row_r[0:NUMBER_OF_BANKS-1];
    
    assign u_cmd_ack = u_cmd_ack_r;

    //sampling input data
    always@ (posedge u_clk) begin
      if(!rst_n) begin
        column_addr_r <= '0;
        row_addr_r <= '0;
        bank_id_r <= '0;
        u_cmd_r <= '0;
        u_cmd_ack_r <= '0;
        u_data_i_r <= '0;
      end
      else if(state_r == IDLE) begin
        column_addr_r <= {(ROW_WIDTH-COLUMN_WIDTH){1'b0}, u_addr[COLUMN_WIDTH-1:0]};
        row_addr_r <= u_addr[ROW_WIDTH+COLUMN_WIDTH-1:COLUMN_WIDTH];
        bank_id_r <= u_addr[U_ADDR_WIDTH-1:U_ADDR_WIDTH-BANK_ID_WIDTH];
        u_cmd_r <= u_cmd;
        u_cmd_ack_r <= '1;
        if(u_cmd) u_data_i_r <= u_data_i;
      end
      else  u_cmd_ack_r <= '0;
    end

    //refresh_logic
    always@ (posedge u_clk) begin
      if(!rst_n) begin
        refresh_count_r <= REFRESH_COUNTER_WIDTH'(CYCLES_BETWEEN_REFRESH);
        refresh_request_r <= '0;
      end
      else  begin
        if(!refresh_count_r) begin
          refresh_count_r <= REFRESH_COUNTER_WIDTH'(CYCLES_BETWEEN_REFRESH);
          refresh_request_r <= '1;
        end
        else  begin
          refresh_count_r--;
          refresh_request_r <= '0;
        end
      end
    end

	//Update state and target states
    always@ (posedge u_clk) begin
	  if(!rst_n) begin
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
			S_IDLE: begin
				if(refresh_request_r) begin
					if(!open_row_r) next_state = S_REFRESH;
					else next_state = S_PRECHARGE;
					next_target_state = S_REFRESH;
				end
				else if(u_cmd_ack_r) begin
					if(open_row_r[bank_id_r] && (row_addr_r == active_row_r[bank_id_r])) begin //ROW hit
						if(u_cmd)	next_state = S_WRITE; //WRITE REQ
						else	next_state = S_READ; //READ REQ
					end
					else if(open_row_r[bank_id_r] && (row_addr_r != active_row_r[bank_id_r])) begin //ROW miss
						next_state = S_PRECHARGE;
						if(u_cmd)	next_target_state = S_WRITE;
						else	next_target_state = S_READ;
					end
					else begin
						next_state = S_ACTIVATE;
						if(u_cmd)	next_target_state = S_WRITE;
						else	next_target_state = S_READ;
					end
				end
			end
			S_PRECHARGE: begin
				
			end
	end
	
		
		

    always@ (posedge clk) begin
      if(rst_n == 1'b0) begin
        state_r <= S_INIT;
        //#######################
        //initialize misc registers
        //#######################
      end
      else begin
        state_r <= next_state;
        //#######################
        //assign next state logic values for each register
        //#######################
      end
    end
    
    //logic for next states
    always@ * begin
      case(state) 
    end
















endmodule




