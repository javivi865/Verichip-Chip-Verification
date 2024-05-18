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

module top_verichip2 ();

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
   
   //$display(" ");
   //$display(" ");

   // START WITH A NICE CLEAN INTERFACE AND A RESET
   `CLEAR_ALL
   `CHIP_RESET

   // STATE MACHINE IN RESET STATE (SECTION 4.0, 5.2, 5.3, 6.1, 6.5 )
   //$display("STATE MACHINE IN RESET STATE (SECTION 4.0, 5.2, 5.3, 6.1, 6.5 )");
   
   //$display("");
   //$display("1 %t",$time());
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b0)
   `CHANGE_WRITE(1'b0,1'b0,16'h8000)
   `READ_REG(VCHIP_STA_ADDR,16'h0000,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("2 %t",$time());
   `CLEAR_ALL
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b0)
   `CHANGE_WRITE(1'b1,1'b0,16'h8000)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("3 %t",$time());
   `CLEAR_ALL
   `CHIP_RESET
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b0)
   `CHANGE_WRITE(1'b0,1'b1,16'h8000)
   `READ_REG(VCHIP_STA_ADDR,16'h0000,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("4 %t",$time());
   `CLEAR_ALL
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b0)
   `CHANGE_WRITE(1'b1,1'b1,16'h8000)
   `READ_REG(VCHIP_STA_ADDR,16'h0000,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("5 %t",$time());
   `CLEAR_ALL
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b0)
   `CHANGE_WRITE(1'b0,1'b0,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0000,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("6 %t",$time());
   `CLEAR_ALL
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b0)
   `CHANGE_WRITE(1'b1,1'b0,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   //`READ_STATUS

   //$display(" ");
   //$display("7 %t",$time());
   `CLEAR_ALL
   `CHIP_RESET
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b0)
   `CHANGE_WRITE(1'b0,1'b1,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0000,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("8 %t",$time());
   `CLEAR_ALL
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b0)
   `CHANGE_WRITE(1'b1,1'b1,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0000,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("9 %t",$time());
   `CLEAR_ALL
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b1)
   `CHANGE_WRITE(1'b0,1'b0,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0000,1'b1)
   //`READ_STATUS
   
   //$display("");
   //$display("10 %t",$time());
   `CLEAR_ALL
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b1)
   `CHANGE_WRITE(1'b1,1'b0,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("11 %t",$time());
   `CLEAR_ALL
   `CHIP_RESET
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b1)
   `CHANGE_WRITE(1'b0,1'b1,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0000,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("12 %t",$time());
   `CLEAR_ALL
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b1)
   `CHANGE_WRITE(1'b1,1'b1,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0000,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("13 %t",$time());
   //`READ_STATUS
   `CHIP_RESET
   `READ_REG(VCHIP_STA_ADDR,16'h0000,1'b1)
   //`READ_STATUS

   // STATE MACHINE IN NORMAL STATE (SECTION 4.0, 5.2, 5.3, 6.2, 6.5 )
   //$display("STATE MACHINE IN NORMAL STATE (SECTION 4.0, 5.2, 5.3, 6.2, 6.5 )");
   `CLEAR_ALL
   `CHIP_RESET
   
   //$display("");
   //$display("1 %t",$time());
   //`READ_STATUS
   `CHANGE_STATE(1'b1,1'b0)
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b0)
   `CHANGE_WRITE(1'b0,1'b0,16'h8000)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("2 %t",$time());
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b0)
   `CHANGE_WRITE(1'b1,1'b0,16'h8000)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("3 %t",$time());
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b0)
   `CHANGE_WRITE(1'b0,1'b1,16'h8000)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("4 %t",$time());
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b0)
   `CHANGE_WRITE(1'b1,1'b1,16'h8000)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("5 %t",$time());
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b0)
   `CHANGE_WRITE(1'b0,1'b0,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0002,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("6 %t",$time());
   `CHANGE_STATE(1'b0,1'b1)
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b0)
   `CHANGE_WRITE(1'b1,1'b0,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0002,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("7 %t",$time());
   `CHANGE_STATE(1'b0,1'b1)
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b0)
   `CHANGE_WRITE(1'b0,1'b1,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0002,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("8 %t",$time());
   `CHANGE_STATE(1'b0,1'b1)
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b0)
   `CHANGE_WRITE(1'b1,1'b1,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0002,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("9 %t",$time());
   `CHANGE_STATE(1'b0,1'b1)
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b1)
   `CHANGE_WRITE(1'b0,1'b0,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0008,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("10 %t",$time());
   `CHIP_RESET
   `CLEAR_ALL
   `CHANGE_STATE(1'b1,1'b0)
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b1)
   `CHANGE_WRITE(1'b1,1'b0,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0008,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("11 %t",$time());
   `CHIP_RESET
   `CLEAR_ALL
   `CHANGE_STATE(1'b1,1'b0)
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b1)
   `CHANGE_WRITE(1'b0,1'b1,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0008,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("12 %t",$time());
   `CHIP_RESET
   `CLEAR_ALL
   `CHANGE_STATE(1'b1,1'b0)
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b1)
   `CHANGE_WRITE(1'b1,1'b1,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0008,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("13 %t",$time());
   `CHIP_RESET
   `CLEAR_ALL
   `CHANGE_STATE(1'b1,1'b0)
   //`READ_STATUS
   `CHIP_RESET
   `READ_REG(VCHIP_STA_ADDR,16'h0000,1'b1)
   //`READ_STATUS

   // STATE MACHINE IN ERR_STATE (SECTION 4.0, 5.2, 5.3, 6.4, 6.5 )
   //$display("STATE MACHINE IN ERR_STATE (SECTION 4.0, 5.2, 5.3, 6.4, 6.5 )");
   `CLEAR_ALL
   `CHIP_RESET
   
   //$display("");
   //$display("1 %t",$time());
   //`READ_STATUS
   `CHANGE_STATE(1'b1,1'b0)
   //`READ_STATUS
   `CHANGE_WRITE(1'b0,1'b0,16'h800A)
   //`READ_STATUS
   `CHANGE_WRITE(1'b0,1'b0,16'h8000)
   `READ_REG(VCHIP_STA_ADDR,16'h0002,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("2 %t",$time());
   //`READ_STATUS
   `CHANGE_WRITE(1'b1,1'b0,16'h8000)
   `READ_REG(VCHIP_STA_ADDR,16'h0002,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("3 %t",$time());
   //`READ_STATUS
   `CHANGE_WRITE(1'b0,1'b1,16'h8000)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("4 %t",$time());
   //`READ_STATUS
   `CHANGE_WRITE(1'b0,1'b0,16'h800A)
   //`READ_STATUS
   `CHANGE_WRITE(1'b1,1'b1,16'h8000)
   `READ_REG(VCHIP_STA_ADDR,16'h0002,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("5 %t",$time());
   //`READ_STATUS
   `CHANGE_WRITE(1'b0,1'b0,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0002,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("6 %t",$time());
   //`READ_STATUS
   `CHANGE_WRITE(1'b1,1'b0,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0002,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("7 %t",$time());
   //`READ_STATUS
   `CHANGE_WRITE(1'b0,1'b1,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("8 %t",$time());
   //`READ_STATUS
   `CHANGE_WRITE(1'b0,1'b0,16'h800A)
   //`READ_STATUS
   `CHANGE_WRITE(1'b1,1'b1,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0002,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("9 %t",$time());
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b1)
   `CHANGE_WRITE(1'b0,1'b0,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0002,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("10 %t",$time());
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b1)
   `CHANGE_WRITE(1'b1,1'b0,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0002,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("11 %t",$time());
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b1)
   `CHANGE_WRITE(1'b0,1'b1,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0001,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("12 %t",$time());
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b0)
   `CHANGE_WRITE(1'b0,1'b0,16'h800A)
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b1)
   `CHANGE_WRITE(1'b1,1'b1,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0002,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("13 %t",$time());
   //`READ_STATUS
   `CHIP_RESET
   `READ_REG(VCHIP_STA_ADDR,16'h0000,1'b1)
   //`READ_STATUS


   // STATE MACHINE IN EXPORT_STATE (SECTION 4.0, 5.2, 5.3, 6.3, 6.5 )
   //$display("STATE MACHINE IN EXPORT_STATE (SECTION 4.0, 5.2, 5.3, 6.3, 6.5 )");
   `CLEAR_ALL
   `CHIP_RESET
   
   //$display("");
   //$display("1 %t",$time());
   //`READ_STATUS
   `CHANGE_STATE(1'b1,1'b0)
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b1)
   `CHANGE_WRITE(1'b0,1'b0,16'h800A)
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b0)
   `CHANGE_WRITE(1'b0,1'b0,16'h8000)
   `READ_REG(VCHIP_STA_ADDR,16'h0008,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("2 %t",$time());
   //`READ_STATUS
   `CHANGE_WRITE(1'b1,1'b0,16'h8000)
   //`READ_STATUS

   //$display("");
   //$display("3 %t",$time());
   //`READ_STATUS
   `CHANGE_WRITE(1'b0,1'b1,16'h8000)
   `READ_REG(VCHIP_STA_ADDR,16'h0008,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("4 %t",$time());
   //`READ_STATUS
   `CHANGE_WRITE(1'b1,1'b1,16'h8000)
   `READ_REG(VCHIP_STA_ADDR,16'h0008,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("5 %t",$time());
   //`READ_STATUS
   `CHANGE_WRITE(1'b0,1'b0,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0008,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("6 %t",$time());
   //`READ_STATUS
   `CHANGE_WRITE(1'b1,1'b0,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0008,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("7 %t",$time());
   //`READ_STATUS
   `CHANGE_WRITE(1'b0,1'b1,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0008,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("8 %t",$time());
   //`READ_STATUS
   `CHANGE_WRITE(1'b1,1'b1,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0008,1'b1)
   //`READ_STATUS

   //$display("");
   //$display("9 %t",$time());
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b1)
   `CHANGE_WRITE(1'b0,1'b0,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0008,1'b1)
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b0)

   //$display("");
   //$display("10 %t",$time());
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b1)
   `CHANGE_WRITE(1'b1,1'b0,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0008,1'b1)
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b0)

   //$display("");
   //$display("11 %t",$time());
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b1)
   `CHANGE_WRITE(1'b0,1'b1,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0008,1'b1)
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b0)

   //$display("");
   //$display("12 %t",$time());
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b1)
   `CHANGE_WRITE(1'b1,1'b1,16'h800A)
   `READ_REG(VCHIP_STA_ADDR,16'h0008,1'b1)
   //`READ_STATUS
   `SET_EXPORT_DISABLE(1'b0)

   //$display("");
   //$display("13 %t",$time());
   //`READ_STATUS
   `CHIP_RESET
   `READ_REG(VCHIP_STA_ADDR,16'h0000,1'b1)
   //`READ_STATUS

   #5 $finish;    // THIS MUST BE THE LAST THING YOU EXECUTE!
end // initial begin


//initial
//begin
//   $fsdbDumpfile("top_test.fsdb");
//   $fsdbDumpvars(0,verichip2);
//end

// instantiate the VeriChip!
verichip2 verichip2 (.clk           ( clk            ),    // system clock
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

endmodule // top_verichip2

