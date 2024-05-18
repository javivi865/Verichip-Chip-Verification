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
       $display("The chip is in state 0");			\
   else if ( data_out == 16'h0001 )       			\
       $display("The chip is in state 1");			\
   else if ( data_out == 16'h0002 )        			\
       $display("The chip is in state 2");			\
   else if ( data_out == 16'h0008 )        			\
       $display("The chip is in state 8");			\
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

`define CHANGE_WRITE(gold_input,maroon_input,wval)	\
   wait(clk==1'b0);					\
   `SET_WRITE(6'h08,wval,2'b11,1'b1)			\
   wait(clk==1'b1);					\
   gold <= gold_input;                  		\
   maroon <= maroon_input;				\
   wait(clk==1'b0);				 		

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

module top_verichip3 ();

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

logic [15:0] idx;

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

   // ALU IN RESET STATE (SECTION 5.0, 5.2, 5.3, 5.5, 5.6, 5.7, 6.1)
   $display("ALU IN RESET STATE (SECTION 5.0, 5.2, 5.3, 5.5, 5.6, 5.7, 6.1)");

   $display("");
   $display("Valid bit=1'b0, export_disable = 1'b0 test  %t",$time());
 
   for(idx=16'h0000; idx <=16'h000F;idx++)
      begin
         `READ_REG(VCHIP_STA_ADDR,16'h0000,1'b1)
         `CHECK_RW(VCHIP_ALU_LEFT_ADDR,idx+1,idx+1,2'b11,1'b1) 
         `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,idx+5,idx+5,2'b11,1'b1) 
         `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
         `WRITE_REG(VCHIP_CMD_ADDR,idx,2'b11,1'b1)
         `READ_REG(VCHIP_ALU_LEFT_ADDR,idx+1,1'b1)
         `READ_REG(VCHIP_ALU_RIGHT_ADDR,idx+5,1'b1)
         `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
         `READ_REG(VCHIP_STA_ADDR,16'h0000,1'b1)
      end
  
   $display("");
   $display("Valid bit=1'b1, export_disable = 1'b0 test  %t",$time());
   for(idx=16'h8000; idx <=16'h800F;idx++)
      begin
         `READ_REG(VCHIP_STA_ADDR,16'h0000,1'b1)
         `CHECK_RW(VCHIP_ALU_LEFT_ADDR,idx+1,idx+1,2'b11,1'b1) 
         `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,idx+5,idx+5,2'b11,1'b1) 
         `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
         `WRITE_REG(VCHIP_CMD_ADDR,idx,2'b11,1'b1)
         `READ_REG(VCHIP_ALU_LEFT_ADDR,idx+1,1'b1)
         `READ_REG(VCHIP_ALU_RIGHT_ADDR,idx+5,1'b1)
         `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
         `READ_REG(VCHIP_STA_ADDR,16'h0000,1'b1)
      end

   $display("");
   $display("Valid bit=1'b0, export_disable = 1'b1 test  %t",$time());
   `SET_EXPORT_DISABLE(1'b1) 
   for(idx=16'h0000; idx <=16'h000F;idx++)
      begin
         `READ_REG(VCHIP_STA_ADDR,16'h0000,1'b1)
         `CHECK_RW(VCHIP_ALU_LEFT_ADDR,idx+1,idx+1,2'b11,1'b1) 
         `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,idx+5,idx+5,2'b11,1'b1) 
         `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
         `WRITE_REG(VCHIP_CMD_ADDR,idx,2'b11,1'b1)
         `READ_REG(VCHIP_ALU_LEFT_ADDR,idx+1,1'b1)
         `READ_REG(VCHIP_ALU_RIGHT_ADDR,idx+5,1'b1)
         `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
         `READ_REG(VCHIP_STA_ADDR,16'h0000,1'b1)
      end

  $display("");
  $display("Valid bit=1'b1, export_disable = 1'b1 test  %t",$time());
  for(idx=16'h8000; idx <=16'h800F;idx++)
     begin
        `READ_REG(VCHIP_STA_ADDR,16'h0000,1'b1)
        `CHECK_RW(VCHIP_ALU_LEFT_ADDR,idx+1,idx+1,2'b11,1'b1) 
        `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,idx+5,idx+5,2'b11,1'b1) 
        `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
        `WRITE_REG(VCHIP_CMD_ADDR,idx,2'b11,1'b1)
        `READ_REG(VCHIP_ALU_LEFT_ADDR,idx+1,1'b1)
        `READ_REG(VCHIP_ALU_RIGHT_ADDR,idx+5,1'b1)
        `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
        `READ_REG(VCHIP_STA_ADDR,16'h0000,1'b1)
     end

   $display("");
   // ALU IN NORMAL STATE (SECTION 5.0, 5.2, 5.3, 5.5, 5.6, 5.7, 6.2)
   $display("ALU IN NORMAL STATE (SECTION 5.0, 5.2, 5.3, 5.5, 5.6, 5.7, 6.2");
   
   $display("");
   $display("Valid bit=1'b0, export_disable = 1'b0 test  %t",$time());
   // Writing values to the ALU Registers and reading ALU Out back
   `CHIP_RESET
   `CLEAR_ALL
   `CHANGE_STATE(1'b1,1'b0)
   `CLEAR_ALL
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
  
   for(idx=16'h0000; idx <=16'h000F;idx++)
      begin
         `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
         `CHECK_RW(VCHIP_ALU_LEFT_ADDR,idx+50,idx+50,2'b11,1'b1) 
         `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,idx+7,idx+7,2'b11,1'b1) 
         `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
         `WRITE_REG(VCHIP_CMD_ADDR,idx,2'b11,1'b1)
         `READ_REG(VCHIP_ALU_LEFT_ADDR,idx+50,1'b1)
         `READ_REG(VCHIP_ALU_RIGHT_ADDR,idx+7,1'b1)
         `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
         `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
      end

   $display("");
   $display("Valid bit=1'b0, export_disable = 1'b1 test  %t",$time());
   `SET_EXPORT_DISABLE(1'b1)
   for(idx=16'h0000; idx <=16'h000F;idx++)
      begin
         `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
         `CHECK_RW(VCHIP_ALU_LEFT_ADDR,idx+50,idx+50,2'b11,1'b1) 
         `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,idx+7,idx+7,2'b11,1'b1) 
         `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
         `WRITE_REG(VCHIP_CMD_ADDR,idx,2'b11,1'b1)
         `READ_REG(VCHIP_ALU_LEFT_ADDR,idx+50,1'b1)
         `READ_REG(VCHIP_ALU_RIGHT_ADDR,idx+7,1'b1)
         `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
         `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
      end
   `CLEAR_ALL

     $display("");
     $display("Valid bit=1'b1, export_disable = 1'b0 test  %t",$time());
// Testing with CMD 8000
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA, 16'hAAAA, 2'b11, 1'b1)
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h5555, 16'h5555, 2'b11, 1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8000,2'b11,1'b1)
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'hAAAA,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h5555,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   
   // Testing with CMD 8001
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA, 16'hAAAA, 2'b11, 1'b1)
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h5555, 16'h5555, 2'b11,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8001,2'b11,1'b1)  // Testing AAAA + 5555
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'hAAAA,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h5555,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'hFFFF,1'b1) 
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)// NO OF
   
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h000E,16'h000E,2'b11,1'b1)  // Testing 14 + 15
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h000F,16'h000F,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'hFFFF,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8001,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h000E,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h000F,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h001D,1'b1) // RESULTS IN 29 NO OF
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hF000,16'hF000,2'b11,1'b1)  // Testing F000 + h9704
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h9704,16'h9704,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h001D,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8001,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'hF000,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h9704,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h8704,1'b1) 
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h7FFF,16'h7FFF,2'b11,1'b1)  // Testing 7FFF + 4000 for OF Pos
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h4000,16'h4000,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h8704,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8001,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h7FFF,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h4000,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'hBFFF,1'b1)
   `READ_REG(VCHIP_STA_ADDR,16'h0002,1'b1)
   `CHANGE_STATE(1'b0,1'b1)
   `CLEAR_ALL 
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hE890,16'hE890,2'b11,1'b1)  // Testing E890 + 9704 for OF Neg
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h9704,16'h9704,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'hBFFF,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8001,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'hE890,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h9704,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h7F94,1'b1) 
   `READ_REG(VCHIP_STA_ADDR,16'h0002,1'b1)
   `CHANGE_STATE(1'b0,1'b1)
   `CLEAR_ALL 
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
     
    
   //Testing with CMD 8002
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'hFFFF,2'b11,1'b1)  // Testing FFFF - AAAA 2 neg nos
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'hAAAA,16'hAAAA,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h7F94,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8002,2'b11,1'b1)
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'hFFFF,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'hAAAA,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h5555,1'b1)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hF000,16'hF000,2'b11,1'b1)  
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h9704,16'h9704,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h5555,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8002,2'b11,1'b1)
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'hF000,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h9704,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h58FC,1'b1) 
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h000E,16'h000E,2'b11,1'b1)  
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'hFFF1,16'hFFF1,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h58FC,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8002,2'b11,1'b1)
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h000E,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'hFFF1,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h001D,1'b1)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h7FFF,16'h7FFF,2'b11,1'b1)  // Testing 7FFF - 8001 POS OF
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h8001,16'h8001,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h001D,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8002,2'b11,1'b1)
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h7FFF,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h8001,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'hFFFE,1'b1)
   `READ_REG(VCHIP_STA_ADDR,16'h0002,1'b1)
   `CHANGE_STATE(1'b0,1'b1)
   `CLEAR_ALL 
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
    
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h8001,16'h8001,2'b11,1'b1)  // Testing 8001 - 7FFF NEG OF
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h7FFF,16'h7FFF,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'hFFFE,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8002,2'b11,1'b1)
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h8001,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h7FFF,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0002,1'b1)
   `READ_REG(VCHIP_STA_ADDR,16'h0002,1'b1)
   `CHANGE_STATE(1'b0,1'b1)
   `CLEAR_ALL 
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   
   //Testing with CMD 8003
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'hFFFF,2'b11,1'b1)  // Testing FFFF - AAAA
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'hAAAA,16'hAAAA,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0002,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8003,2'b11,1'b1)
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h0002,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'hAAAA,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0002,1'b1)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)

   //Testing with CMD 8004
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h5555,16'h5555,2'b11,1'b1)  // Testing 5555   8888
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h8888,16'h8888,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0002,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8004,2'b11,1'b1)
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h5555,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h0002,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0002,1'b1)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)

   //Testing with CMD 8005
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h0F0E,16'h0F0E,2'b11,1'b1)  // Testing 0F0E 0FF0
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h0FF0,16'h0FF0,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0002,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8005,2'b11,1'b1)
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h0FF0,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h0F0E,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0002,1'b1)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)

   //Testing with CMD 8006
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'hAAAA,2'b11,1'b1)  // Testing AAAA 0001
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h0001,16'h0001,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0002,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8006,2'b11,1'b1)
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'hAAAA,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h0001,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h5554,1'b1)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)

   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h000E,16'h000E,2'b11,1'b1)  // Testing AAAA 0000
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h0000,16'h0000,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h5554,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8006,2'b11,1'b1)
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h000E,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h0000,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h000E,1'b1)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)

   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'hAAAA,2'b11,1'b1)  // Testing AAAA FFFF
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'hFFFF,16'hFFFF,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h000E,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8006,2'b11,1'b1)
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'hAAAA,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'hFFFF,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)

   //Testing with CMD 8007
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'hAAAA,2'b11,1'b1)  // Testing AAAA 0001
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h0001,16'h0001,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8007,2'b11,1'b1)
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'hAAAA,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h0001,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h5555,1'b1)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)

   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h000E,16'h000E,2'b11,1'b1)  // Testing AAAA 0000
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h0000,16'h0000,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h5555,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8007,2'b11,1'b1)
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h000E,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h0000,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h000E,1'b1)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)

   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA,16'hAAAA,2'b11,1'b1)  
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'hFFFF,16'hFFFF,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h000E,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8007,2'b11,1'b1)
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'hAAAA,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'hFFFF,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)

   //Testing with Reserved commands
   `CHIP_RESET
   `CLEAR_ALL
   `CHANGE_STATE(1'b1,1'b0)
   `CLEAR_ALL
   for(idx=16'h8008; idx <=16'h800F;idx++)
      begin
         `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
         `CHECK_RW(VCHIP_ALU_LEFT_ADDR,idx+90,idx+90,2'b11,1'b1) 
         `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,idx+10,idx+10,2'b11,1'b1) 
         `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
         `WRITE_REG(VCHIP_CMD_ADDR,idx,2'b11,1'b1)
         `READ_REG(VCHIP_ALU_LEFT_ADDR,idx+90,1'b1)
         `READ_REG(VCHIP_ALU_RIGHT_ADDR,idx+10,1'b1)
         `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
         `READ_REG(VCHIP_STA_ADDR,16'h0002,1'b1)
         `CHANGE_STATE(1'b0,1'b1)
         `CLEAR_ALL 
         `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
      end

   $display("");
   $display("Valid bit=1'b1, export_disable = 1'b1 test  %t",$time());
   `SET_EXPORT_DISABLE(1'b1)
// Testing with CMD 8000
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA, 16'hAAAA, 2'b11, 1'b1)
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h5555, 16'h5555, 2'b11, 1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8000,2'b11,1'b1)
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'hAAAA,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h5555,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   
   // Testing with CMD 8001
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hAAAA, 16'hAAAA, 2'b11, 1'b1)
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h5555, 16'h5555, 2'b11, 1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8001,2'b11,1'b1)  
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'hAAAA,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h5555,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'hFFFF,1'b1) 
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h000E,16'h000E,2'b11,1'b1)  
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h000F,16'h000F,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'hFFFF,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8001,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h000E,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h000F,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h001D,1'b1) 
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hF000,16'hF000,2'b11,1'b1)  
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h9704,16'h9704,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h001D,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8001,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'hF000,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h9704,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h8704,1'b1) 
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h7FFF,16'h7FFF,2'b11,1'b1)  
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h4000,16'h4000,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h8704,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8001,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h7FFF,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h4000,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'hBFFF,1'b1)
   `READ_REG(VCHIP_STA_ADDR,16'h0002,1'b1)
   `CHANGE_STATE(1'b0,1'b1)
   `CLEAR_ALL 
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `SET_EXPORT_DISABLE(1'b1)
   
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hE890,16'hE890,2'b11,1'b1)  
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h9704,16'h9704,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'hBFFF,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8001,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'hE890,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h9704,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h7F94,1'b1) 
   `READ_REG(VCHIP_STA_ADDR,16'h0002,1'b1)
   `CHANGE_STATE(1'b0,1'b1)
   `CLEAR_ALL 
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `SET_EXPORT_DISABLE(1'b1)
     
    
   //Testing with CMD 8002
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hFFFF,16'hFFFF,2'b11,1'b1)
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'hAAAA,16'hAAAA,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h7F94,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8002,2'b11,1'b1)
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'hFFFF,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'hAAAA,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h5555,1'b1)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'hF000,16'hF000,2'b11,1'b1)  
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h9704,16'h9704,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h5555,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8002,2'b11,1'b1)
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'hF000,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h9704,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h58FC,1'b1) 
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h000E,16'h000E,2'b11,1'b1)  
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'hFFF1,16'hFFF1,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h58FC,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8002,2'b11,1'b1)
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h000E,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'hFFF1,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h001D,1'b1)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h7FFF,16'h7FFF,2'b11,1'b1)  
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h8001,16'h8001,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h001D,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8002,2'b11,1'b1)
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h7FFF,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h8001,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'hFFFE,1'b1)
   `READ_REG(VCHIP_STA_ADDR,16'h0002,1'b1)
   `CHANGE_STATE(1'b0,1'b1)
   `CLEAR_ALL 
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `SET_EXPORT_DISABLE(1'b1)
    
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   `CHECK_RW(VCHIP_ALU_LEFT_ADDR,16'h8001,16'h8001,2'b11,1'b1)  
   `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,16'h7FFF,16'h7FFF,2'b11,1'b1) 
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'hFFFE,1'b1)
   `WRITE_REG(VCHIP_CMD_ADDR,16'h8002,2'b11,1'b1)
   `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h8001,1'b1)
   `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h7FFF,1'b1)
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0002,1'b1)
   `READ_REG(VCHIP_STA_ADDR,16'h0002,1'b1)
   `CHANGE_STATE(1'b0,1'b1)
   `CLEAR_ALL 
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   
   //Testing with Reserved commands
   `CHIP_RESET
   `CLEAR_ALL
   `CHANGE_STATE(1'b1,1'b0)
   `CLEAR_ALL
   `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
   `SET_EXPORT_DISABLE(1'b1)
   for(idx=16'h8003; idx <=16'h800F;idx++)
      begin
         `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
         `CHECK_RW(VCHIP_ALU_LEFT_ADDR,idx+88,idx+88,2'b11,1'b1)  
         `CHECK_RW(VCHIP_ALU_RIGHT_ADDR,idx+44,idx+44,2'b11,1'b1) 
         `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
         `WRITE_REG(VCHIP_CMD_ADDR,idx,2'b11,1'b1)
         `READ_REG(VCHIP_ALU_LEFT_ADDR,16'h0000,1'b1)
         `READ_REG(VCHIP_ALU_RIGHT_ADDR,16'h0000,1'b1)
         `READ_REG(VCHIP_ALU_OUT_ADDR,16'h0000,1'b1)
         `READ_REG(VCHIP_STA_ADDR,16'h0008,1'b1)
         `CHIP_RESET
         `CLEAR_ALL
         `CHANGE_STATE(1'b1,1'b0)
         `CLEAR_ALL
         `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
         `SET_EXPORT_DISABLE(1'b1)
      end

   wait(clk==1'b0);
   wait(clk==1'b1);
   wait(clk==1'b0);
   $finish;    // THIS MUST BE THE LAST THING YOU EXECUTE!
end // initial begin


//initial
//begin
  // $fsdbDumpfile("top_test.fsdb");
  // $fsdbDumpvars(0,verichip3);
//end

// instantiate the VeriChip!
verichip3 verichip3 (.clk           ( clk            ),    // system clock
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

endmodule // top_verichip3

