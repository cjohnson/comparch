`define TILELINK_CHANNEL_A_OPCODE_GET 3'b100

`define TILELINK_CHANNEL_D_OPCODE_ACCESS_ACK_DATA 3'b001

interface tilelink_ul_if #(
    parameter DATA_BUS_WIDTH,
    parameter ADDRESS_FIELD_WIDTH,
    parameter SIZE_FIELD_WIDTH,
    parameter SOURCE_IDENTIFIER_FIELD_WIDTH,
    parameter SINK_IDENTIFIER_FIELD_WIDTH
);
  // Channel A
  logic [2:0] a_opcode;
  logic [2:0] a_param;
  logic [(SIZE_FIELD_WIDTH - 1):0] a_size;
  logic [(SOURCE_IDENTIFIER_FIELD_WIDTH - 1):0] a_source;
  logic [(ADDRESS_FIELD_WIDTH - 1):0] a_address;
  logic [(DATA_BUS_WIDTH - 1):0] a_mask;
  logic [((DATA_BUS_WIDTH * 8) - 1):0] a_data;
  logic a_corrupt;
  logic a_valid;
  logic a_ready;

  // Channel D
  logic [2:0] d_opcode;
  logic [1:0] d_param;
  logic [(SIZE_FIELD_WIDTH - 1):0] d_size;
  logic [(SOURCE_IDENTIFIER_FIELD_WIDTH - 1):0] d_source;
  logic [(SINK_IDENTIFIER_FIELD_WIDTH - 1):0] d_sink;
  logic d_denied;
  logic [((DATA_BUS_WIDTH * 8) - 1):0] d_data;
  logic d_corrupt;
  logic d_valid;
  logic d_ready;

  modport master(
      output a_opcode,
      output a_param,
      output a_size,
      output a_source,
      output a_address,
      output a_mask,
      output a_data,
      output a_corrupt,
      output a_valid,
      input a_ready,

      input d_opcode,
      input d_param,
      input d_size,
      input d_source,
      input d_sink,
      input d_denied,
      input d_data,
      input d_corrupt,
      input d_valid,
      output d_ready
  );

  modport slave(
      input a_opcode,
      input a_param,
      input a_size,
      input a_source,
      input a_address,
      input a_mask,
      input a_data,
      input a_corrupt,
      input a_valid,
      output a_ready,

      output d_opcode,
      output d_param,
      output d_size,
      output d_source,
      output d_sink,
      output d_denied,
      output d_data,
      output d_corrupt,
      output d_valid,
      input d_ready
  );
endinterface : tilelink_ul_if

module virtual_flash (
    input logic clk,
    input logic rst,

    tilelink_ul_if tilelink_ul_if
);
  logic [1023:0][7:0] memory;

  typedef enum {
    CHANNEL_A_RX,
    CHANNEL_D_TX
  } tx_state_t;

  typedef struct packed {
    tx_state_t state;

    logic [1:0]  size;
    logic        source;
    logic [31:0] address;
  } tx_handler_t;
  tx_handler_t handler, next_handler;

  always_comb begin
    next_handler = handler;

    case (handler.state)
      CHANNEL_A_RX: begin
        if (tilelink_ul_if.a_valid) begin
          next_handler.state = CHANNEL_D_TX;

          next_handler.size = tilelink_ul_if.a_size;
          next_handler.source = tilelink_ul_if.a_source;
          next_handler.address = tilelink_ul_if.a_address;
        end
      end
      CHANNEL_D_TX: begin
        if (tilelink_ul_if.d_ready) begin
          next_handler.state = CHANNEL_A_RX;
        end
      end
    endcase
  end

  always_comb begin
    tilelink_ul_if.a_ready = 1'b0;

    tilelink_ul_if.d_opcode = '0;
    tilelink_ul_if.d_param = '0;
    tilelink_ul_if.d_size = '0;
    tilelink_ul_if.d_source = '0;
    tilelink_ul_if.d_sink = '0;
    tilelink_ul_if.d_denied = '0;
    tilelink_ul_if.d_data = '0;
    tilelink_ul_if.d_corrupt = '0;
    tilelink_ul_if.d_valid = '0;

    case (handler.state)
      CHANNEL_A_RX: begin
        tilelink_ul_if.a_ready = 1'b1;
      end
      CHANNEL_D_TX: begin
        tilelink_ul_if.d_opcode = `TILELINK_CHANNEL_D_OPCODE_ACCESS_ACK_DATA;
        tilelink_ul_if.d_param = 2'b00;
        tilelink_ul_if.d_size = handler.size;
        tilelink_ul_if.d_source = handler.source;
        tilelink_ul_if.d_sink = 1'b0;
        tilelink_ul_if.d_denied = 1'b0;
        tilelink_ul_if.d_data[7:0] = memory[handler.address+0];
        tilelink_ul_if.d_data[15:8] = memory[handler.address+1];
        tilelink_ul_if.d_data[23:16] = memory[handler.address+2];
        tilelink_ul_if.d_data[31:24] = memory[handler.address+3];
        tilelink_ul_if.d_corrupt = 1'b0;
        tilelink_ul_if.d_valid = 1'b1;
      end
    endcase
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      handler.state <= CHANNEL_A_RX;

      handler.size <= 2'b00;
      handler.source <= 1'b0;
      handler.address <= 32'h00000000;
    end else begin
      handler <= next_handler;
    end
  end

endmodule : virtual_flash

`define FALSE 1'b0
`define TRUE 1'b1

`define RV32_OP_IMM 7'b0010011

`define RV32_I_TYPE_INSTRUCTION(opcode,
                                funct3) {{12{1'b?}}, {5{1'b?}}, ``funct3``, {5{1'b?}}, ``opcode``}

`define RV32_ADDI `RV32_I_TYPE_INSTRUCTION(`RV32_OP_IMM, 3'b000)

`define RV32_I_TYPE_SIGN_EXTEND(instruction) {{21{``instruction``[31]}}, ``instruction``[30:20]}

typedef struct packed {
  logic [11:0] imm;
  logic [4:0]  rs1;
  logic [2:0]  funct3;
  logic [4:0]  rd;
  logic [6:0]  opcode;
} rv32_i_type_instruction_t;

typedef union packed {
  logic [31:0] instruction;
  rv32_i_type_instruction_t i_type_instruction;
} rv32_instruction_t;

typedef enum {ALU_OPERAND_A_SELECT_RS1} alu_operand_a_select_t;

typedef enum {ALU_OPERAND_B_SELECT_I_IMM} alu_operand_b_select_t;

typedef enum {ALU_ADD} alu_opcode_t;

typedef struct packed {
  rv32_instruction_t instruction;

  logic [31:0] program_counter;
  logic valid;
} ifid_packet_t;

typedef struct packed {
  rv32_instruction_t instruction;

  logic [4:0] destination_register;

  logic [31:0] rs1_value;

  alu_operand_a_select_t alu_operand_a_select;
  alu_operand_b_select_t alu_operand_b_select;
  alu_opcode_t alu_opcode;

  logic [31:0] program_counter;
  logic illegal;
  logic valid;
} idex_packet_t;

typedef struct packed {
  logic [4:0] destination_register;

  logic [31:0] alu_result;

  logic [31:0] program_counter;
  logic illegal;
  logic valid;
} exmem_packet_t;

typedef struct packed {
  logic [4:0] destination_register;

  logic [31:0] result;

  logic [31:0] program_counter;
  logic illegal;
  logic valid;
} memwb_packet_t;

module rv32i_in_order_core_instruction_fetch_stage (
    input logic clk,
    input logic rst,

    input logic decode_stage_ready,

    input logic              instruction_valid,
    input rv32_instruction_t instruction,

    output logic [31:0] instruction_address,

    output ifid_packet_t ifid_packet
);
  logic [31:0] program_counter;

  always_ff @(posedge clk) begin
    if (rst) begin
      program_counter <= 32'd0;
    end else if (decode_stage_ready && instruction_valid) begin
      program_counter <= program_counter + 4;
    end
  end

  always_comb begin
    ifid_packet.instruction = '0;
    ifid_packet.program_counter = '0;
    ifid_packet.valid = `FALSE;

    if (decode_stage_ready && instruction_valid) begin
      ifid_packet.instruction = instruction;
      ifid_packet.program_counter = program_counter;
      ifid_packet.valid = `TRUE;
    end
  end

  assign instruction_address = program_counter;
endmodule : rv32i_in_order_core_instruction_fetch_stage

module rv32i_in_order_core_decoder (
    input rv32_instruction_t instruction,

    output logic [4:0] destination_register,

    output logic [4:0] rs1_index,

    output alu_operand_a_select_t alu_operand_a_select,
    output alu_operand_b_select_t alu_operand_b_select,
    output alu_opcode_t alu_opcode,

    output logic illegal
);
  always_comb begin
    destination_register = '0;

    rs1_index = '0;

    alu_operand_a_select = ALU_OPERAND_A_SELECT_RS1;
    alu_operand_b_select = ALU_OPERAND_B_SELECT_I_IMM;
    alu_opcode = ALU_ADD;

    illegal = `FALSE;

    casez (instruction)
      `RV32_ADDI: begin
        destination_register = instruction.i_type_instruction.rd;

        rs1_index = instruction.i_type_instruction.rs1;

        alu_operand_a_select = ALU_OPERAND_A_SELECT_RS1;
        alu_operand_b_select = ALU_OPERAND_B_SELECT_I_IMM;
        alu_opcode = ALU_ADD;
      end
      default: begin
        illegal = `TRUE;
      end
    endcase
  end
endmodule : rv32i_in_order_core_decoder

module rv32i_in_order_core_instruction_decode_stage (
    input logic clk,
    input logic rst,

    input logic writeback_valid,
    input logic [4:0] writeback_register,
    input logic [31:0] writeback_data,

    input  ifid_packet_t ifid_packet,
    output idex_packet_t idex_packet
);
  logic [31:0][31:0] general_purpose_registers, next_general_purpose_registers;

  always_comb begin
    next_general_purpose_registers = general_purpose_registers;
    if (writeback_valid) begin
      next_general_purpose_registers[writeback_register] = writeback_data;
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < 32; ++i) begin
        general_purpose_registers[i] <= 32'd0;
      end
    end else begin
      general_purpose_registers[0] <= 32'd0;
      for (int i = 1; i < 32; ++i) begin
        general_purpose_registers[i] <= next_general_purpose_registers[i];
      end
    end
  end

  logic [4:0] rs1_index;

  rv32i_in_order_core_decoder decoder_0 (
      .instruction(ifid_packet.instruction),

      .destination_register(idex_packet.destination_register),

      .rs1_index(rs1_index),

      .alu_operand_a_select(idex_packet.alu_operand_a_select),
      .alu_operand_b_select(idex_packet.alu_operand_b_select),
      .alu_opcode(idex_packet.alu_opcode),

      .illegal(idex_packet.illegal)
  );

  assign idex_packet.instruction = ifid_packet.instruction;

  assign idex_packet.rs1_value = next_general_purpose_registers[rs1_index];

  assign idex_packet.program_counter = ifid_packet.program_counter;
  assign idex_packet.valid = ifid_packet.valid;
endmodule : rv32i_in_order_core_instruction_decode_stage

module alu (
    input [31:0] left_hand_side_operand,
    input [31:0] right_hand_side_operand,
    input alu_opcode_t opcode,

    output [31:0] result
);
  always_comb begin
    case (opcode)
      ALU_ADD: result = left_hand_side_operand + right_hand_side_operand;
      default: result = 32'hffffffff;
    endcase
  end
endmodule

module rv32i_in_order_core_instruction_execute_stage (
    input  idex_packet_t  idex_packet,
    output exmem_packet_t exmem_packet
);
  logic [31:0] left_hand_side_operand;
  logic [31:0] right_hand_side_operand;
  logic [31:0] alu_result;

  always_comb begin
    case (idex_packet.alu_operand_a_select)
      ALU_OPERAND_A_SELECT_RS1: left_hand_side_operand = idex_packet.rs1_value;
      default: left_hand_side_operand = 32'hffffffff;
    endcase
  end

  always_comb begin
    case (idex_packet.alu_operand_b_select)
      ALU_OPERAND_B_SELECT_I_IMM:
      right_hand_side_operand = `RV32_I_TYPE_SIGN_EXTEND(idex_packet.instruction);
      default: right_hand_side_operand = 32'hffffffff;
    endcase
  end

  alu alu_0 (
      .left_hand_side_operand(left_hand_side_operand),
      .right_hand_side_operand(right_hand_side_operand),
      .opcode(idex_packet.alu_opcode),

      .result(exmem_packet.alu_result)
  );

  assign exmem_packet.destination_register = idex_packet.destination_register;

  assign exmem_packet.program_counter = idex_packet.program_counter;
  assign exmem_packet.illegal = idex_packet.illegal;
  assign exmem_packet.valid = idex_packet.valid;
endmodule : rv32i_in_order_core_instruction_execute_stage

module rv32i_in_order_core_instruction_memory_stage (
    input  exmem_packet_t exmem_packet,
    output memwb_packet_t memwb_packet
);
  assign memwb_packet.destination_register = exmem_packet.destination_register;

  assign memwb_packet.result = exmem_packet.alu_result;

  assign memwb_packet.program_counter = exmem_packet.program_counter;
  assign memwb_packet.illegal = exmem_packet.illegal;
  assign memwb_packet.valid = exmem_packet.valid;
endmodule : rv32i_in_order_core_instruction_memory_stage

module rv32i_in_order_core_instruction_writeback_stage (
    input memwb_packet_t memwb_packet,

    output logic writeback_valid,
    output logic [4:0] writeback_register,
    output logic [31:0] writeback_data
);
  assign writeback_valid = memwb_packet.valid;
  assign writeback_register = memwb_packet.destination_register;
  assign writeback_data = memwb_packet.result;
endmodule : rv32i_in_order_core_instruction_writeback_stage

module rv32i_in_order_core (
    // Clock and reset signals
    input logic clk,
    input logic rst,

    // TileLink interface
    tilelink_ul_if tilelink_ul_if
);
  logic              [31:0] instruction_address;
  logic                     instruction_valid;
  rv32_instruction_t        instruction;

  ifid_packet_t ifid_register, ifid_packet;

  logic decode_stage_ready;
  idex_packet_t idex_register, idex_packet;

  exmem_packet_t exmem_register, exmem_packet;

  memwb_packet_t memwb_register, memwb_packet;

  logic writeback_valid;
  logic [4:0] writeback_register;
  logic [31:0] writeback_data;

  typedef enum {
    CHANNEL_A_TX,
    CHANNEL_D_RX,
    TX_COMPLETE
  } tx_state_t;

  typedef struct packed {
    logic valid;

    logic [31:0] address;
    logic [31:0] data;

    tx_state_t state;
  } tx_handler_t;
  tx_handler_t handler, next_handler;

  always_comb begin
    next_handler = handler;

    if (!handler.valid) begin
      next_handler.valid = `TRUE;

      next_handler.address = instruction_address;
      next_handler.data = 32'd0;

      next_handler.state = CHANNEL_A_TX;
    end else begin
      case (handler.state)
        CHANNEL_A_TX: begin
          if (tilelink_ul_if.a_ready) begin
            next_handler.state = CHANNEL_D_RX;
          end
        end
        CHANNEL_D_RX: begin
          if (tilelink_ul_if.d_valid) begin
            next_handler.state = TX_COMPLETE;
            next_handler.data  = tilelink_ul_if.d_data;
          end
        end
        TX_COMPLETE: begin
          if (instruction_address != handler.address) begin
            next_handler.valid = `TRUE;

            next_handler.address = instruction_address;
            next_handler.data = 32'd0;

            next_handler.state = CHANNEL_A_TX;
          end
        end
      endcase
    end
  end

  always_comb begin
    tilelink_ul_if.a_opcode = '0;
    tilelink_ul_if.a_param = '0;
    tilelink_ul_if.a_size = '0;
    tilelink_ul_if.a_source = '0;
    tilelink_ul_if.a_address = '0;
    tilelink_ul_if.a_mask = '0;
    tilelink_ul_if.a_data = '0;
    tilelink_ul_if.a_corrupt = '0;
    tilelink_ul_if.a_valid = '0;

    tilelink_ul_if.d_ready = '0;

    if (handler.valid) begin
      case (handler.state)
        CHANNEL_A_TX: begin
          tilelink_ul_if.a_opcode = `TILELINK_CHANNEL_A_OPCODE_GET;
          tilelink_ul_if.a_param = 3'b000;
          tilelink_ul_if.a_size = 2'b10;
          tilelink_ul_if.a_source = 1'b0;
          tilelink_ul_if.a_address = handler.address;
          tilelink_ul_if.a_mask = 4'b1111;
          tilelink_ul_if.a_data = 32'h00000000;
          tilelink_ul_if.a_corrupt = 1'b0;
          tilelink_ul_if.a_valid = 1'b1;
        end
        CHANNEL_D_RX: begin
          tilelink_ul_if.d_ready = 1'b1;
        end
      endcase
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      handler.valid <= `FALSE;

      handler.address <= 32'd0;
      handler.data <= 32'd0;

      handler.state <= CHANNEL_A_TX;
    end else begin
      handler <= next_handler;
    end
  end

  always_comb begin
    instruction_valid = `FALSE;
    instruction.instruction = 32'h00000000;

    if (handler.state == TX_COMPLETE && handler.address == instruction_address) begin
      instruction_valid = `TRUE;
      instruction.instruction = handler.data;
    end
  end

  rv32i_in_order_core_instruction_fetch_stage fetch_stage_0 (
      .clk(clk),
      .rst(rst),

      .decode_stage_ready(decode_stage_ready),

      .instruction_valid(instruction_valid),
      .instruction(instruction),

      .instruction_address(instruction_address),

      .ifid_packet(ifid_packet)
  );

  always_ff @(posedge clk) begin
    if (rst) begin
      ifid_register <= '0;
    end else begin
      ifid_register <= ifid_packet;
    end
  end

  rv32i_in_order_core_instruction_decode_stage decode_stage_0 (
      .clk(clk),
      .rst(rst),

      .writeback_valid(writeback_valid),
      .writeback_register(writeback_register),
      .writeback_data(writeback_data),

      .ifid_packet(ifid_register),
      .idex_packet(idex_packet)
  );

  always_ff @(posedge clk) begin
    if (rst) begin
      idex_register <= '0;
    end else begin
      idex_register <= idex_packet;
    end
  end

  assign decode_stage_ready = `TRUE;

  rv32i_in_order_core_instruction_execute_stage execute_stage_0 (
      .idex_packet (idex_register),
      .exmem_packet(exmem_packet)
  );

  always_ff @(posedge clk) begin
    if (rst) begin
      exmem_register <= '0;
    end else begin
      exmem_register <= exmem_packet;
    end
  end

  rv32i_in_order_core_instruction_memory_stage memory_stage_0 (
      .exmem_packet(exmem_register),
      .memwb_packet(memwb_packet)
  );

  always_ff @(posedge clk) begin
    if (rst) begin
      memwb_register <= '0;
    end else begin
      memwb_register <= memwb_packet;
    end
  end

  rv32i_in_order_core_instruction_writeback_stage writeback_stage_0 (
      .memwb_packet(memwb_register),

      .writeback_valid(writeback_valid),
      .writeback_register(writeback_register),
      .writeback_data(writeback_data)
  );
endmodule : rv32i_in_order_core

module tb;
  logic clk;
  logic rst;

  tilelink_ul_if #(4, 32, 2, 1, 1) tilelink_ul_if ();

  rv32i_in_order_core core0 (
      .clk(clk),
      .rst(rst),

      .tilelink_ul_if(tilelink_ul_if.master)
  );

  virtual_flash rom0 (
      .clk(clk),
      .rst(rst),

      .tilelink_ul_if(tilelink_ul_if.slave)
  );

  // Clock generator
  initial begin
    clk = 0;
    forever clk = #20 ~clk;
  end

  always_comb begin
    if (core0.memwb_register.valid) begin
      $display("Retired Instruction %8x: V: %8x, Illegal: %b", core0.memwb_register.program_counter,
               core0.memwb_register.result, core0.memwb_register.illegal);
    end
  end

  initial begin
    rst = 1;
    rom0.memory[3:0] = {12'd1, 5'd1, 3'b000, 5'd1, `RV32_OP_IMM};

    @(negedge clk);
    rst = 0;

    #800;

    $display("Final register state:");
    for (int i = 0; i < 32; ++i) begin
      if (core0.decode_stage_0.general_purpose_registers[i] != 0) begin
        $display("X%2d: %8x", i, core0.decode_stage_0.general_purpose_registers[i]);
      end
    end
    $finish;
  end
endmodule
