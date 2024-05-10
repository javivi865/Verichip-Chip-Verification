`timescale 1ns/1ps

`define SET_WRITE(addr,val,bytes,chip)   \
   rw_ <= 1'b0;                          \
   chip_select <= chip;                  \
   byte_en <= bytes;                     \
   address <= addr;                      \
   data_in <= val; 

`define SET_READ(addr,chip)         \
   rw_ <= 1'b1;                     \
   chip_select <= chip;             \
   byte_en <= 2'b00;                \
   address <= addr;                 \
   data_in <= 16'h0;

`define CLEAR_BUS                   \
   chip_select    <= 1'b0;          \
   address        <= 7'h0;          \
   byte_en        <= 2'h0;          \
   rw_            <= 1'b1;          \
   data_in        <= 16'h0; 

`define CLEAR_ALL                   \
   export_disable <= 1'b0;          \
   maroon         <= 1'b0;          \
   gold           <= 1'b0;          \
   `CLEAR_BUS

`define CHECK_VAL(val)              \
   if ( data_out != val )           \
       $display("bad read, got %h but expected %h at %t",data_out,val,$time()); 
  //  else										
      // $display("read was fine, got %h and expected %h at %t", data_out,val,$time());

`define WRITE_REG(addr,wval,bytes,chip)	\
   wait(clk==1'b0);			\
   `SET_WRITE(addr,wval,bytes,chip)	\
   wait(clk==1'b1);			\
   `CLEAR_BUS				\
   wait(clk==1'b0);

`define READ_REG(addr,rval,chip)	\
   wait(clk==1'b0);			\
   `SET_READ(addr,chip)			\
   wait(clk==1'b1);			\
   wait(clk==1'b0);			\
   `CHECK_VAL(rval)			\
   wait(clk==1'b1);			\
   `CLEAR_BUS				\
   wait(clk==1'b0);  

`define READ_STATUS						\
   wait(clk==1'b1);						\
   `SET_READ(6'h04,1'b1)					\
   wait(clk==1'b0);						\
   if ( data_out == 16'h0000 )        				\
       $display("The chip is in the reset state");		\
   else if ( data_out == 16'h0001 )        			\
       $display("The chip is in the normal state");		\
   else if ( data_out == 16'h0002 )        			\
       $display("The chip is in the error_state");		\
   else if ( data_out == 16'h0008 )        			\
       $display("The chip is in the export_violation state");	\
   else								\		
       $display("Reserved bits are not 0 or INT are triggered");

`define CHECK_RW(addr,wval,rval,bytes,chip)    \
   `WRITE_REG(addr,wval,bytes,chip)            \
   `READ_REG(addr,rval,chip)

`define CHANGE_STATE(gold_input,maroon_input)	\
   wait(clk==1'b0);				\
   gold <= gold_input;				\
   maroon <= maroon_input;			\
   wait(clk==1'b1);				

`define SET_EXPORT_DISABLE(export_input)	\
   wait(clk==1'b0);				\
   export_disable <= export_input;		\
   wait(clk==1'b1);				\   
   wait(clk==1'b0);				\
   wait(clk==1'b1);

`define CHIP_RESET                  \
   wait( clk == 1'b0 );             \	
   rst_b <= 1'b0;                   \
   wait( clk == 1'b1 );             \
   rst_b <= 1'b1;                   
   //$display("The chip was reset");

module top_verichip ();

logic clk;                       // system clock
logic rst_b;                     // chip reset
logic export_disable;            // disable features
logic interrupt_1;               // first interrupt
logic interrupt_2;               // second interrupt

logic maroon;                    // maroon state machine input
logic gold;                      // gold state machine input

logic chip_select;               // target of r/w
logic [6:0] address;             // address bus
logic [1:0] byte_en;             // write byte enables
logic       rw_;                 // read/write
logic [15:0] data_in;            // input data bus

logic [15:0] data_out;           // output data bus

localparam VCHIP_VER_ADDR       = 7'h00;   // valid addresses 
localparam VCHIP_STA_ADDR       = 7'h04; 
localparam VCHIP_CMD_ADDR       = 7'h08; 
localparam VCHIP_CON_ADDR       = 7'h0C; 
localparam VCHIP_ALU_LEFT_ADDR  = 7'h10; 
localparam VCHIP_ALU_RIGHT_ADDR = 7'h14; 
localparam VCHIP_ALU_OUT_ADDR   = 7'h18; 

localparam VCHIP_ALU_VALID = 16'h8000; // the valid bit 
localparam VCHIP_ALU_ADD   = 16'h0001; // the various commands 
localparam VCHIP_ALU_SUB   = 16'h0002; // OR the valid bit with the commands to do something
localparam VCHIP_ALU_MVL   = 16'h0003;
localparam VCHIP_ALU_MVR   = 16'h0004;
localparam VCHIP_ALU_SWA   = 16'h0005;
localparam VCHIP_ALU_SHL   = 16'h0006;
localparam VCHIP_ALU_SHR   = 16'h0007;

initial      // get the clock running
begin
   clk <= 1'b0;
   while ( 1 )
   begin
      #5 clk <= 1'b1;
      #5 clk <= 1'b0;
   end
end

initial
begin
   
   $display(" ");
   $display(" ");

   // START WITH A NICE CLEAN INTERFACE AND A RESET
   `CLEAR_ALL
   `CHIP_RESET

   // CHECK READ/WRITE IN RESET STATE (SECTION 2.0,5.6,6.1)
   //$display("CHECK READ/WRITE IN RESET STATE (SECTION 2.0,5.6,6.1)");
   // `READ_STATUS
   //$display("Read what is currently in the register");
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h0000,1'b1)
   //$display("Attempt to write AAAA and make sure AAAA is read back");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'hAAAA,2'b11,1'b1)
   //$display("Attempt to write 0000 and make sure 0000 is read back");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h0000,16'h0000,2'b11,1'b1)
   //$display("Attempt to write FFFF and make sure FFFF is read back");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'hFFFF,2'b11,1'b1)
   //$display("Attempt to write 5555 and make sure 5555 is read back");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display(" ");

   // CHECK READING RESET BITS AFTER RESET IS TRIGGER (SECTION 2.0,5.6,6.1)
   //$display("CHECK READING RESET BITS AFTER RESET IS TRIGGER IN RESET STATE(SECTION 2.0,5.6,6.1)");
   //`READ_STATUS
   //$display("Attempt to write AAAA and make sure AAAA is read back");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'hAAAA,2'b11,1'b1)
   `CHIP_RESET
   //`READ_STATUS
   //$display("Read the register and make sure we get 0000 after reset");
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h0000,1'b1)
   //$display(" ");

   // CHECK READING RESET BITS AFTER RESET IS TRIGGER (SECTION 2.0,5.6,6.1)
   //$display("CHECK READING RESET BITS AFTER RESET IS TRIGGER IN NORMAL STATE(SECTION 2.0,5.6,6.1)");
   //`READ_STATUS
   `CHANGE_STATE(1'b1,1'b0)
   //`READ_STATUS
   //$display("Attempt to write AAAA and make sure AAAA is read back");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'hAAAA,2'b11,1'b1)
   `CHIP_RESET
   //`READ_STATUS
   //$display("Read the register and make sure we get 0000 after reset");
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h0000,1'b1)
   //$display(" ");

   // CHECK READING RESET BITS AFTER RESET IS TRIGGER (SECTION 2.0,5.6,6.1)
   //$display("CHECK READING RESET BITS AFTER RESET IS TRIGGER IN EXPORT_VIOLATION STATE(SECTION 2.0,5.6,6.1)");
   `CLEAR_ALL
   `CHIP_RESET
   //`READ_STATUS
   `CHANGE_STATE(1'b1,1'b0)
   //`READ_STATUS
   //$display("Attempt to write AAAA and make sure AAAA is read back");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'hAAAA,2'b11,1'b1)
   `SET_EXPORT_DISABLE(1'b1)
   //$display("The export_disable is %b", export_disable);
   `WRITE_REG(VCHIP_CMD_ADDR,16'h800A,2'b11,1'b1)
   //`READ_STATUS
   `CHIP_RESET
   //`READ_STATUS
   //$display("Read the register and make sure we get 0000 after reset");
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h0000,1'b1)
   //$display(" ");

   // CHECK READING RESET BITS AFTER RESET IS TRIGGER (SECTION 2.0,5.6,6.1)
   //$display("CHECK READING RESET BITS AFTER RESET IS TRIGGER IN ERROR_STATE(SECTION 2.0,5.6,6.1)");
   `CLEAR_ALL
   `CHIP_RESET
   //`READ_STATUS
   `CHANGE_STATE(1'b1,1'b0)
   //`READ_STATUS
   //$display("Attempt to write AAAA and make sure AAAA is read back");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'hAAAA,2'b11,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h800A,2'b11,1'b1)
   //`READ_STATUS
   `CHIP_RESET
   //`READ_STATUS
   //$display("Read the register and make sure we get 0000 after reset");
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h0000,1'b1)
   //$display(" ");

   // CHECK READ/WRITE IN NORMAL STATE (SECTION 5.6,6.2)
   //$display("CHECK WRITE/READ IN NORMAL STATE (SECTION 5.6,6.2)");
   `CLEAR_ALL
   `CHIP_RESET
   `CHANGE_STATE(1'b1,1'b0)
   //`READ_STATUS
   //$display("Making sure we read 0000 for the register");
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h0000,1'b1)
   //$display("Writing and reading back AAAA");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'hAAAA,2'b11,1'b1)
   //$display("Writing and reading back 0000");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h0000,16'h0000,2'b11,1'b1)
   //$display("Writing and reading back 5555");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display("Writing and reading back FFFF");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'hFFFF,2'b11,1'b1)
   //$display(" ");

  
   // CHECK FOR EXPORT_VIOLATION READ/WRITE (SECTION 5.6,6.3)
   //$display("CHECK WRITE/READ FROM EXPORT_VIOLATION STATE (SECTION 5.6,6.3)");
   `CHIP_RESET
   `CLEAR_ALL
   `CHANGE_STATE(1'b1,1'b0)
   //`READ_STATUS
   //$display("Writing and reading back FFFF");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'hFFFF,2'b11,1'b1)
   `SET_EXPORT_DISABLE(1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h800A,2'b11,1'b1)
   //`READ_STATUS
   //$display("Attempting to read from the ALU Left Register");
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h0000,1'b1)
   //$display("Attempting to write/read 5555");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h0000,2'b11,1'b1)
   //$display("Attempting to write/read 0000");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h0000,16'h0000,2'b11,1'b1)
   //$display("Attempting to write/read FFFF");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'h0000,2'b11,1'b1)
   //$display("Attempting to write/read AAAA");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'h0000,2'b11,1'b1)
   //$display(" ");

   // CHECK WRITE/READ IN THE ERROR_STATE (SECTION 5.6,6.4)
   //$display("CHECK WRITE/READ IN THE ERROR_STATE FOR (SECTION 5.6,6.4)");
   `CLEAR_ALL  
   `CHIP_RESET
   `CHANGE_STATE(1'b1,1'b0)
   //`READ_STATUS
   
   // FFFF
   //$display("Writing FFFF to ALU_LEFT and confirm");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'hFFFF,2'b11,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h800A,2'b11,1'b1)
   //`READ_STATUS
   //$display("Reading ALU_LEFT after entering error_state");
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'hFFFF,1'b1)
   //$display("Attempting to write something different"); 
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'hFFFF,2'b11,1'b1)
   `CHANGE_STATE(1'b0,1'b1)
   //`READ_STATUS
   `CLEAR_ALL
   //$display(" ");
   
   // 5555
   //$display("Writing 5555 to ALU_LEFT and confirm");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h800A,2'b11,1'b1)
   //`READ_STATUS
   //$display("Reading ALU_LEFT after entering error_state");
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h5555,1'b1)
   //$display("Attempting to write something different"); 
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'h5555,2'b11,1'b1)
   `CHANGE_STATE(1'b0,1'b1)
   //`READ_STATUS   
   `CLEAR_ALL
   //$display(" ");
   
   // 0000
   //$display("Writing 0000 to ALU_LEFT and confirm");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h0000,16'h0000,2'b11,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h800A,2'b11,1'b1)
   //`READ_STATUS
   //$display("Reading ALU_LEFT after entering error_state");
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h0000,1'b1)
   //$display("Attempting to write something different"); 
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'h0000,2'b11,1'b1)
   `CHANGE_STATE(1'b0,1'b1)
   //`READ_STATUS    
   `CLEAR_ALL
   //$display(" ");
   
   // AAAA
   //$display("Writing AAAA to ALU_LEFT and confirm");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'hAAAA,2'b11,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h800A,2'b11,1'b1)
   //`READ_STATUS
   //$display("Reading ALU_LEFT after entering error_state");
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'hAAAA,1'b1)
   //$display("Attempting to write something different"); 
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'hAAAA,2'b11,1'b1)
   //$display(" ");

   
   // CHECK BYTE ENABLE (SECTION 5.6,3.0)
   //$display("CHECK BYTE ENABLE (SECTION 5.6,3.0)");
  
   // RESET STATE FFFF
   //$display("RESET STATE BYTE ENABLE FFFF");
   `CLEAR_ALL 
   `CHIP_RESET
   //`READ_STATUS
   //$display("Writing something to the ALU LEFT");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display("Testing with 00 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'h5555,2'b00,1'b1)
   //$display("Testing with 01 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'h55FF,2'b01,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display("Testing with 10 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'hFF55,2'b10,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display("Testing with 11 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'hFFFF,2'b11,1'b1)
   //$display(" ");

   // RESET STATE AAAA
   //$display("CHECK BYTE ENABLE (SECTION 5.6,3.0)");
   //$display("RESET STATE BYTE ENABLE AAAA");
   //`READ_STATUS
   //$display("Writing something to the ALU LEFT");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display("Testing with 00 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'h5555,2'b00,1'b1)
   //$display("Testing with 01 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'h55AA,2'b01,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display("Testing with 10 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'hAA55,2'b10,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display("Testing with 11 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'hAAAA,2'b11,1'b1)
   //$display(" ");

   // RESET STATE 5555
   //$display("CHECK BYTE ENABLE (SECTION 5.6,3.0)");
   //$display("RESET STATE BYTE ENABLE 5555");
   //`READ_STATUS
   //$display("Writing something to the ALU LEFT");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'hFFFF,2'b11,1'b1)
   //$display("Testing with 00 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'hFFFF,2'b00,1'b1)
   //$display("Testing with 01 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'hFF55,2'b01,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'hFFFF,2'b11,1'b1)
   //$display("Testing with 10 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h55FF,2'b10,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'hFFFF,2'b11,1'b1)
   //$display("Testing with 11 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display(" ");

   // RESET STATE 0000
   //$display("CHECK BYTE ENABLE (SECTION 5.6,3.0)");
   //$display("RESET STATE BYTE ENABLE 0000");
   //`READ_STATUS
   //$display("Writing something to the ALU LEFT");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display("Testing with 00 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h0000,16'h5555,2'b00,1'b1)
   //$display("Testing with 01 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h0000,16'h5500,2'b01,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display("Testing with 10 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h0000,16'h0055,2'b10,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display("Testing with 11 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h0000,16'h0000,2'b11,1'b1)
   //$display(" ");


   // CHECK BYTE ENABLE (SECTION 5.6,3.0)
   //$display("CHECK BYTE ENABLE (SECTION 5.6,3.0)");
   //$display("NORMAL STATE BYTE ENABLE FFFF");
   `CHANGE_STATE(1'b1,1'b0)
   `CLEAR_ALL
   //`READ_STATUS
   //$display("Writing something to the ALU LEFT");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display("Testing with 00 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'h5555,2'b00,1'b1)
   //$display("Testing with 01 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'h55FF,2'b01,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display("Testing with 10 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'hFF55,2'b10,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display("Testing with 11 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'hFFFF,2'b11,1'b1)
   //$display(" ");

   // CHECK BYTE ENABLE (SECTION 5.6,3.0)
   //$display("NORMAL STATE BYTE ENABLE AAAA");
   //`READ_STATUS
   //$display("Writing something to the ALU LEFT");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display("Testing with 00 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'h5555,2'b00,1'b1)
   //$display("Testing with 01 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'h55AA,2'b01,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display("Testing with 10 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'hAA55,2'b10,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display("Testing with 11 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'hAAAA,2'b11,1'b1)
   //$display(" ");

   // CHECK BYTE ENABLE (SECTION 5.6,3.0)
   //$display("NORMAL STATE BYTE ENABLE 5555");
   //`READ_STATUS
   //$display("Writing something to the ALU LEFT");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'hFFFF,2'b11,1'b1)
   //$display("Testing with 00 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'hFFFF,2'b00,1'b1)
   //$display("Testing with 01 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'hFF55,2'b01,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'hFFFF,2'b11,1'b1)
   //$display("Testing with 10 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h55FF,2'b10,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'hFFFF,2'b11,1'b1)
   //$display("Testing with 11 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display(" ");

   // CHECK BYTE ENABLE (SECTION 5.6,3.0)
   //$display("NORMAL STATE BYTE ENABLE 0000");
   //`READ_STATUS
   //$display("Writing something to the ALU LEFT");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display("Testing with 00 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h0000,16'h5555,2'b00,1'b1)
   //$display("Testing with 01 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h0000,16'h5500,2'b01,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display("Testing with 10 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h0000,16'h0055,2'b10,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display("Testing with 11 byte enable");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h0000,16'h0000,2'b11,1'b1)
   //$display(" ");


   // CHECK READ/WRITE WITH/WITHOUT CHIP SELECT (SECTION 5.6,3.0)
   //$display("CHECK WRITE/READ WITH CHIP SELECT (SECTION 5.6,3.0)");
   `CLEAR_ALL
   `CHIP_RESET
   //`READ_STATUS
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h0000,1'b1)
   //$display("Writing and reading back AAAA");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'hAAAA,2'b11,1'b1)
   //$display("Writing and reading back 0000");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h0000,16'h0000,2'b11,1'b1)
   //$display("Writing and reading back 5555");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display("Writing and reading back FFFF");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'hFFFF,2'b11,1'b1)
   //$display(" ");

   // CHECK READ/WRITE WITH/WITHOUT CHIP SELECT (SECTION 5.6,3.0)
   //$display("CHECK WRITE/READ WITHOUT CHIP SELECT (SECTION 5.6,3.0)");
   // `READ_STATUS
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'hFFFF,1'b1)
   //$display("Writing and reading back AAAA");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'h0000,2'b11,1'b0)
   //$display("Writing and reading back AAAA");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'h0000,2'b11,1'b0)
   //$display("Writing and reading back 5555");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h0000,2'b11,1'b0)
   //$display("Writing and reading back FFFF");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'h0000,2'b11,1'b0)
   //$display("Writing to ALU_LEFT with chip select to test 0000");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'hFFFF,2'b11,1'b1)
   //$display("Writing and reading back 0000");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h0000,16'h0000,2'b11,1'b0)
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'hFFFF,1'b1)
   //$display(" ");

   // CHECK ALIASING IN NORMAL/RESET STATE (SECTION 5.6,3.0,5.0)
   //$display("CHECK ALIASING IN RESET STATE (SECTION 5.6,3.0,5.0)");
   `CLEAR_ALL
   `CHIP_RESET
   //`READ_STATUS
   //$display("Writing to ALU_LEFT FFFF");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'hFFFF,2'b11,1'b1)
   //$display("Attempting to read with address 7'h50");
   `READ_REG(7'h50,16'h0000,1'b1);
   //$display("Attempting to write/read with address 7'h50");
   `CHECK_RW(7'h50,16'hAAAA,16'h0000,2'b11,1'b1)
   //$display("Reading back the correct the ALU LEFT Reg");
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'hFFFF,1'b1); 
   //$display(" ");

   // CHECK ALIASING IN NORMAL/RESET STATE (SECTION 5.6,3.0,5.0)
   //$display("CHECK ALIASING IN NORMAL STATE (SECTION 5.6,3.0,5.0)");
   `CHANGE_STATE(1'b1,1'b0)
   `CLEAR_ALL
   //`READ_STATUS
   //$display("Writing to ALU_LEFT 5555");
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)
   //$display("Attempting to read with address 7'h50");
   `READ_REG(7'h50,16'h0000,1'b1);
   //$display("Attempting to write/read with address 7'h50");
   `CHECK_RW(7'h50,16'hFFFF,16'h0000,2'b11,1'b1)
   //$display("Reading back the correct the ALU LEFT Reg");
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h5555,1'b1); 
   //$display(" ");
   //$display(" ");



   #5 $finish;    // THIS MUST BE THE LAST THING YOU EXECUTE!
end // initial begin


initial
begin
   $fsdbDumpfile("top_test.fsdb");
   $fsdbDumpvars(0,verichip);
end

// instantiate the VeriChip!
verichip verichip (.clk           ( clk            ),    // system clock
                   .rst_b         ( rst_b          ),    // chip reset
                   .export_disable( export_disable ),    // disable features
                   .interrupt_1   ( interrupt_1    ),    // first interrupt
                   .interrupt_2   ( interrupt_2    ),    // second interrupt
 
                   .maroon        ( maroon         ),    // maroon state machine input
                   .gold          ( gold           ),    // gold state machine input

                   .chip_select   ( chip_select    ),    // target of r/w
                   .address       ( address        ),    // address bus
                   .byte_en       ( byte_en        ),    // write byte enables
                   .rw_           ( rw_            ),    // read/write
                   .data_in       ( data_in        ),    // data bus

                   .data_out      ( data_out       ) );  // output data bus

endmodule // top_verichip

