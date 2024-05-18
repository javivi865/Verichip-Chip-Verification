module verichip4(input logic clk,                       // system clock
                 input logic rst_b,                     // chip reset
                 input logic export_disable,            // disable features
                 output logic interrupt_1,              // first interrupt
                 output logic interrupt_2,              // second interrupt

                 input logic maroon,                    // maroon state machine input
                 input logic gold,                      // gold state machine input

                 input logic chip_select,               // target of r/w
                 input logic [6:0] address,             // address bus
                 input logic [1:0] byte_en,             // write byte enables
                 input logic       rw_,                 // read/write
                 input logic [15:0] data_in,            // input data bus

                 output logic [15:0] data_out);          // output data bus

localparam VCHIP_ALU_VER = 4'h2;    // current ALU version
localparam VCHIP_MAJ_VER = 4'h1;
localparam VCHIP_MIN_VER = 4'h0;

localparam VCHIP_STATE_RESET = 4'h0;
localparam VCHIP_STATE_NORM  = 4'h1;
localparam VCHIP_STATE_ERR   = 4'h2;
localparam VCHIP_STATE_EXP   = 4'h8;
localparam VCHIP_STATE_LOST  = 4'hF;

localparam VCHIP_ADDR_VER = 7'h00;
localparam VCHIP_ADDR_STA = 7'h04;
localparam VCHIP_ADDR_CMD = 7'h08;
localparam VCHIP_ADDR_CON = 7'h0C;
localparam VCHIP_ADDR_LFT = 7'h10;
localparam VCHIP_ADDR_RGT = 7'h14;
localparam VCHIP_ADDR_ALU = 7'h18;

localparam VCHIP_CMD_NONE = 4'h0;

localparam VCHIP_STA_INT2 = 9;      // bit position of interrupt 2
localparam VCHIP_STA_INT1 = 8;      // bit position of interrupt 1

localparam VCHIP_CMD_LEFT = 3;      // left bit of command in command register
localparam VCHIP_CMD_VAL  = 15;     // valid bit
localparam VCHIP_CMD_NON = 4'h0;
localparam VCHIP_CMD_ADD = 4'h1;
localparam VCHIP_CMD_SUB = 4'h2;
localparam VCHIP_CMD_MVL = 4'h3;
localparam VCHIP_CMD_MVR = 4'h4;
localparam VCHIP_CMD_SWA = 4'h5;
localparam VCHIP_CMD_SHL = 4'h6;
localparam VCHIP_CMD_SHR = 4'h7;
localparam VCHIP_LAST_CMD = 4'h7;
localparam VCHIP_LAST_EXP_CMD = 4'h2;

// Version Register flops
logic export_dis;                   // if 1, export disable is 1
logic [15:0] version_reg;           // concat of bits

// Status Regiser flops
logic        int2;                  // interrupt 2
logic        int1;                  // interrupt 1
logic [3:0]  state;                 // state machine state
logic [15:0] status_reg;            // concat of bits
logic [3:0]  next_state;            // next state machine state

// Command Register flops
logic        valid;                 // command is valid
logic [3:0]  cmd;                   // the command
logic [15:0] cmd_reg;               // concat of bits
logic        bad_exp_cmd;           // bad command when export disable asserted
logic        bad_cmd;               // undefined command

// Configuration Register flops
logic int2_en;                      // enable interrupt 2
logic int1_en;                      // enable interrupt 1
logic [15:0] con_reg;               // concat of bits

// ALU Registers
logic [15:0] alu_left;              // left input
logic [15:0] alu_right;             // right input
logic [15:0] alu_out;               // result
logic        overflow;              // bad add/sub
logic [15:0] alu_result;            // result
logic [15:0] next_left;             // value from ALU to load
logic [15:0] next_right;            // value from ALU to load
logic        load_left;             // load value from ALU
logic        load_right;            // load value from ALU

logic [15:0] data_out_tmp;          // read data

always_ff @ ( posedge clk or negedge rst_b )
begin
  if ( !rst_b )
  begin
     export_dis <= export_disable;
     state      <= VCHIP_STATE_RESET;
     alu_out    <= 16'h0;
  end // if ( !rst_b )
  else
  begin
     export_dis <= export_disable;
     state <= next_state;
     alu_out <= alu_result;
  end // else: !if( !rst_b )
end

assign bad_exp_cmd = export_dis && valid && ( cmd > VCHIP_LAST_EXP_CMD );
assign bad_cmd     = valid && ( cmd > VCHIP_LAST_CMD );
assign overflow    = valid &&
                     ( ( ( cmd == VCHIP_CMD_ADD ) &&                                      // adding
                         ( ( alu_left[15] && alu_right[15] && !alu_result[15] ) ||        // two neg -> pos
                           ( !alu_left[15] && !alu_right[15] && alu_result[15] ) ) ) ||   // two pos -> neg
                        ( ( cmd == VCHIP_CMD_SUB ) &&                                     // subtracting
                          ( ( alu_left[15] && !alu_right[15] && !alu_result[15] ) ||      // neg - pos -> pos
                            ( !alu_left[15] && alu_right[15] && alu_result[15] ) ) ) );   // pos - neg -> neg

assign interrupt_1 = int1;
assign interrupt_2 = int2;

always_comb
begin
   case ( state )
     VCHIP_STATE_RESET:
     begin
        if ( !maroon && gold )
           next_state = VCHIP_STATE_NORM;
        else
           next_state = VCHIP_STATE_RESET;
     end // case: VCHIP_STATE_RESET

     VCHIP_STATE_NORM:
     begin
        if ( export_dis && valid && bad_exp_cmd )
           next_state = VCHIP_STATE_EXP;
        else if ( valid && ( bad_cmd || overflow ) )
           next_state = VCHIP_STATE_ERR;
        else
           next_state = VCHIP_STATE_NORM;
     end // case: VCHIP_STATE_NORM

     VCHIP_STATE_ERR:
     begin
        if ( maroon && !gold )
           next_state = VCHIP_STATE_NORM;
        else
           next_state = VCHIP_STATE_ERR;
     end // case: VCHIP_STATE_ERR

     VCHIP_STATE_EXP:
     begin
        next_state = VCHIP_STATE_EXP;
     end // case: VCHIP_STATE_EXP

     default:
     begin
        next_state = VCHIP_STATE_LOST;
     end // case: default

   endcase // case ( state )
end // always_comb

always_ff @ ( posedge clk or negedge rst_b )
begin
  if ( !rst_b )
  begin
     int1       <= 1'b0;
  end // if ( !rst_b )
  else if ( int1_en && ( state == VCHIP_STATE_NORM ) && valid &&
            ( bad_cmd || overflow ) )
  begin
     int1 <= 1'b1;
  end // if ( ( state == VCHIP_STATE_NORM ) && valid &&...
  else if ( chip_select && !rw_ && ( address == VCHIP_ADDR_STA ) && byte_en[1] )
  begin
     if ( data_in[VCHIP_STA_INT1] )
        int1 <= 1'b0;
  end // else: !if( !rst_b )
end // always_ff @ ( posedge clk or negedge rst_b )

always_ff @ ( posedge clk or negedge rst_b )
begin
  if ( !rst_b )
  begin
     int2       <= 1'b0;
  end // if ( !rst_b )
  else if ( int2_en && ( state == VCHIP_STATE_NORM ) && valid && bad_exp_cmd )
  begin
     int2 <= 1'b1;
  end // if ( ( state == VCHIP_STATE_NORM ) && valid &&...
  else if ( chip_select && !rw_ && ( address == VCHIP_ADDR_STA ) && byte_en[1] )
  begin
     if ( data_in[VCHIP_STA_INT2] )
        int2 <= 1'b0;
  end // else: !if( !rst_b )
end // always_ff @ ( posedge clk or negedge rst_b )

always_ff @ ( posedge clk or negedge rst_b )
begin
  if ( !rst_b )
  begin
     valid <= 1'b0;
     cmd <= VCHIP_CMD_NONE;
  end // if ( !rst_b )
  else if ( next_state == VCHIP_STATE_EXP )
  begin
     valid <= 1'b0;
     cmd <= VCHIP_CMD_NONE;
  end // if ( next_state == VCHIP_STATE_EXP )
  else if ( state == VCHIP_STATE_ERR )
  begin
     valid <= 1'b0;
     cmd <= cmd;
  end // if ( state == VCHIP_STATE_ERR )
  else if ( chip_select && !rw_ && ( address == VCHIP_ADDR_CMD ) )
  begin
     valid <= data_in[VCHIP_CMD_VAL] && byte_en[1];
     if ( byte_en[0] )
        cmd <= data_in[VCHIP_CMD_LEFT:0];
  end // if ( chip_select && !rw_ && ( address == VCHIP_ADDR_CMD ) )
  else
  begin
     valid <= 1'b0;
  end // else: !if( chip_select && !rw_ && ( address == VCHIP_ADDR_CMD ) )
end // always_ff @ ( posedge clk or negedge rst_b )

always_ff @ ( posedge clk or negedge rst_b )
begin
  if ( !rst_b )
  begin
     int2_en    <= 1'b0;
     int1_en    <= 1'b0;
  end // if ( !rst_b )
  else if ( next_state == VCHIP_STATE_EXP )
  begin
     int2_en <= 1'b0;
     int1_en <= 1'b0;
  end // if ( next_state == VCHIP_STATE_EXP )
  else if ( state == VCHIP_STATE_ERR )
  begin
     int2_en <= int2_en;
     int1_en <= int1_en;
  end // if ( state == VCHIP_STATE_ERR )
  else if ( chip_select && !rw_ && ( address == VCHIP_ADDR_CON ) && byte_en[1] )
  begin
     int2_en <= data_in[VCHIP_STA_INT2];
     int1_en <= data_in[VCHIP_STA_INT1];
  end // else: !if( !rst_b )
end // always_ff @ ( posedge clk or negedge rst_b )

always_ff @ ( posedge clk or negedge rst_b )
begin
  if ( !rst_b )
  begin
     alu_left <= 16'h0;
  end // if ( !rst_b )
  else if ( next_state == VCHIP_STATE_EXP )
  begin
     alu_left <= 16'h0;
  end // if ( next_state == VCHIP_STATE_EXP )
  else if ( state == VCHIP_STATE_ERR )
  begin
     alu_left <= alu_left;
  end // if ( state == VCHIP_STATE_ERR )
  else if ( chip_select && !rw_ && ( address == VCHIP_ADDR_LFT ) )
  begin
     if ( byte_en[0] )
        alu_left[7:0] <= data_in[7:0];
     if ( byte_en[1] )
        alu_left[15:8] <= data_in[15:8];
  end // if ( chip_select && !rw_ && ( address == VCHIP_ADDR_LFT ) )
  else if ( load_left )
  begin
     alu_left <= next_left;
  end // if ( load_left )
end // always_ff @ ( posedge clk or negedge rst_b )

always_ff @ ( posedge clk or negedge rst_b )
begin
  if ( !rst_b )
  begin
     alu_right <= 16'h0;
  end // if ( !rst_b )
  else if ( next_state == VCHIP_STATE_EXP )
  begin
     alu_right <= 16'h0;
  end // if ( next_state == VCHIP_STATE_EXP )
  else if ( state == VCHIP_STATE_ERR )
  begin
     alu_right <= alu_right;
  end // if ( state == VCHIP_STATE_ERR )
  else if ( chip_select && !rw_ && ( address == VCHIP_ADDR_RGT ) )
  begin
     if ( byte_en[0] )
        alu_right[7:0] <= data_in[7:0];
     if ( byte_en[1] )
        alu_right[15:8] <= data_in[15:8];
  end // if ( chip_select && !rw_ && ( address == VCHIP_ADDR_LFT ) )
  else if ( load_right )
  begin
     alu_right <= next_right;
  end // if ( load_right )
end // always_ff @ ( posedge clk or negedge rst_b )

always_comb
begin
  if ( ( next_state == VCHIP_STATE_EXP ) && ( address != VCHIP_ADDR_STA ) )
     data_out = 16'h0;
  else if ( chip_select )
     data_out = data_out_tmp;
  else
     data_out = 16'h0;
end // always_comb

assign version_reg = { export_dis, 3'h0, VCHIP_ALU_VER, VCHIP_MAJ_VER, VCHIP_MIN_VER };
assign status_reg  = { 6'h0, int2, int1, 4'h0, state };
assign cmd_reg     = { valid, 11'h0, cmd };
assign con_reg     = { 6'h0, int2_en, int1_en, 8'h0 };

always_comb
begin
  case ( address )
    VCHIP_ADDR_VER: data_out_tmp = version_reg;
    VCHIP_ADDR_STA: data_out_tmp = status_reg;
    VCHIP_ADDR_CMD: data_out_tmp = cmd_reg;
    VCHIP_ADDR_CON: data_out_tmp = con_reg;
    VCHIP_ADDR_LFT: data_out_tmp = alu_left;
    VCHIP_ADDR_RGT: data_out_tmp = alu_right;
    VCHIP_ADDR_ALU: data_out_tmp = alu_out;

    default: data_out_tmp = 16'h0;
  endcase // case ( address )
end // always_comb

// build the ALU
always_comb
begin
   if ( next_state == VCHIP_STATE_EXP )
   begin
      alu_result = 16'h0;
      load_left = 1'b0;
      load_right = 1'b0;
      next_left = 16'h0;
      next_right = 16'h0;
   end // if ( next_state == VCHIP_STATE_EXP )

   else if ( ( state != VCHIP_STATE_NORM ) || !valid || bad_cmd )
   begin
      alu_result = alu_out;
      load_left = 1'b0;
      load_right = 1'b0;
      next_left = 16'h0;
      next_right = 16'h0;
   end // if ( ( state != VCHIP_STATE_NORM ) || !valid || bad_cmd )

   else
   begin
      case ( cmd )
        VCHIP_CMD_NONE:
        begin
           alu_result = alu_out;
           load_left = 1'b0;
           load_right = 1'b0;
           next_left = 16'h0;
           next_right = 16'h0;
        end // case: VCHIP_CMD_NONE

        VCHIP_CMD_ADD:
        begin
           alu_result = alu_left + alu_right;
           load_left = 1'b0;
           load_right = 1'b0;
           next_left = 16'h0;
           next_right = 16'h0;
        end // case: VCHIP_CMD_ADD

        VCHIP_CMD_SUB:
        begin
           alu_result = alu_left - alu_right;
           load_left = 1'b0;
           load_right = 1'b0;
           next_left = 16'h0;
           next_right = 16'h0;
        end // case: VCHIP_CMD_SUB

        VCHIP_CMD_MVL:   // move out to left
        begin
           alu_result = alu_out;
           load_left = 1'b1;
           load_right = 1'b0;
           next_left = alu_out;
           next_right = 16'h0;
        end // case: VCHIP_CMD_MVL

        VCHIP_CMD_MVR:   // move out to right
        begin
           alu_result = alu_out;
           load_left = 1'b0;
           load_right = 1'b1;
           next_left = 16'h0;
           next_right = alu_out;
        end // case: VCHIP_CMD_MVR

        VCHIP_CMD_SWA:
        begin
           alu_result = alu_out;
           load_left = 1'b1;
           load_right = 1'b1;
           next_left = alu_right;
           next_right = alu_left;
        end // case: VCHIP_CMD_SWA

        VCHIP_CMD_SHL:
        begin
           alu_result = alu_left << alu_right;
           load_left = 1'b0;
           load_right = 1'b0;
           next_left = 16'h0;
           next_right = 16'h0;
        end // case: VCHIP_CMD_SHL

        VCHIP_CMD_SHR:
        begin
           alu_result = alu_left >> alu_right;
           load_left = 1'b0;
           load_right = 1'b0;
           next_left = 16'h0;
           next_right = 16'h0;
        end // case: VCHIP_CMD_SHR

        default:
        begin
           alu_result = alu_out;
           load_left = 1'b0;
           load_right = 1'b0;
           next_left = 16'h0;
           next_right = 16'h0;
        end // case: default
      endcase // case ( cmd )
   end // else: !if( ( state != VCHIP_STATE_NORM ) || !valid || bad_cmd )
end // always_comb

endmodule
       
