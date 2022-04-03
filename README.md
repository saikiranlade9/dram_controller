# dram_controller
A simple dram controller implementation for course work 

## Specifications: 

Given problem statement: A DRAM controller is an on-chip component of the processor, responsible for communicating with off chip DRAM systems. Data is stored inside multiple banks in interleaved fashion. All banks of the DRAM can be accessed parallelly. Each bank has a two-dimensional matrix of bit cells(capacitor) and a row buffer.  

Below are the steps/commands to read data from DRAM:  

**RA (row access):** An address in DRAM gets divided into a tuple. Bankid selects the bank; while the rowid selects a row and all the bit cells in the row are stored in the row buffer.  

**CA (column access):** A column is selected by the colid and the bit corresponding to that column stored in the row buffer is sent out of the bank.  

**PRE (precharge):** When all the required columns are read out, the entire row in the row buffer is written back into the original row position of the bank (since the capacitors leak the charge over time which may corrupt the data).  

When a request of different row arrives at controller, first the existing row inside the row buffer needs to pre precharged before the new row’s RA step begins. Assuming the number of banks is 8. Each bank has a 128 X 8 matrix of bit cells, i.e., each bank can hold 1024 bits of data. Write a Verilog code to implement this design. Besides the above-mentioned functionality, there are additional commands that need to be supported.  

**REFRESH:** Even though all rows of the DRAM bank are not accessed, still because of the leaky nature of capacitors, each row of the DRAM bank needs to be periodically refreshed. During the refresh time of a row, same row access is prohibited. Assume refresh rate is 125ms.  

**Constraints:**  

Since inside the DRAM there is no additional command buffer, all the commands need to be sent one by one (sequentially).  

Each command has its own execution delay. So, the controller has to send the commands in such a way that all such delay constraints of DRAM can be maintained, and no command gets ignored.  

Periodically REFRESH command needs to be issued  

Though each bank can be accessed simultaneously but at a time only one bank can transfer data to DRAM controller via DRAM bus. 

### Specifications derived from the above description: 

  Number of banks 			= 	8  
  Number of columns in each bank	= 	8 
  Number of rows in each bank		= 	128 
  Refresh Rate				= 	125 ms 

**Assumptions:** 

**Refreshing:** We assumed that there is an additional command(REFRESH) to solely refresh the dram. We have modelled dram in Verilog for testing the controller design. When the dram sees the REFRESH command, it'll activate rows of same index from each bank simultaneously followed by precharging them. This repeats for NUMBER_OF_ROWS times refreshing one set of rows(rows of same index from each bank) at a time.  

**Missing or contradictory assumptions:** 

**Frequency:** Since frequency is not provided in the specification, we assumed it to be 100K Hz. In that case there will be a refresh every 12500 cycles. 

**Data width:** Since data width is not provided in the specification, we assumed it to be 2. In that case, there would be 4 possible data elements of width 2 in each row. 

**Modifications:** 

**Commands:** Instead of packing all the command signals(ras, cas, we, cs, bank_addr) into a single command, we sent those command signals individually.

## Design Interface:

**Inputs and Outputs:**   

**User Interface:** 
u_rst_n	      : reset, active low 

u_clk	        : clock 

u_en		      : enable for dram controller 

u_addr	      : address <bank_id, row_address, column_address> 

u_data_i      : input write data 

u_cmd		      : read (0) or write (1) 

u_data_valid  : valid signal for output read data 

u_cmd_ack		  : acknowledge signal for input data and input commands. This signal, when asserted, confirms that the dram controller has started executing the           previous requested operation. 

u_busy		    : busy signal, asserted while the dram is executing operations. 

u_data_o		  : output read data 

**DRAM Interface:** 
dram_addr		: address, column address for READ and WRITE commands; row address for ACTIVATE and PRECHARGE commands. 

dram_bank_id		: bank ID  

dram_cs_n		: chip select, active low 

dram_ras_n		: row address strobe, active low 

dram_cas_n		: column address strobe, active low 

dram_we_n		: write enable, active low 

dram_clk_en		: clock enable, active low 

dram_refresh_done	: asserted when dram is done refreshing 

dram_rd_data		: read data 

 
## FSM Diagram:  
