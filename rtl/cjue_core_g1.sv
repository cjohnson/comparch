// Copyright (c) 2026 Collin Johnson

`include "riscv.svh"

typedef enum logic [1:0] {
  ALU_LEFT_HAND_SIDE_OPERAND_SELECT_RS1,
  ALU_LEFT_HAND_SIDE_OPERAND_SELECT_PC,
  ALU_LEFT_HAND_SIDE_OPERAND_SELECT_ZERO
} alu_left_hand_side_operand_select_e;

typedef enum logic [1:0] {
  ALU_RIGHT_HAND_SIDE_OPERAND_SELECT_RS2,
  ALU_RIGHT_HAND_SIDE_OPERAND_SELECT_I_TYPE_IMMEDIATE,
  ALU_RIGHT_HAND_SIDE_OPERAND_SELECT_U_TYPE_IMMEDIATE
} alu_right_hand_side_operand_select_e;

typedef enum {ALU_OPCODE_ADD} alu_opcode_e;

interface cjue_g1_core_if #(
    parameter int unsigned XLEN
) (
    output logic            memory_request,
    output logic [XLEN-1:0] memory_request_address,

    input logic            memory_response,
    input logic [XLEN-1:0] memory_response_data
);
  typedef struct packed {
    logic [4:0] destination_register;
    logic [XLEN-1:0] data;
    logic valid;
  } writeback_packet_t;

  typedef struct packed {
    riscv::instruction_t instruction;
    logic [XLEN-1:0] program_counter;

    logic valid;
  } ifid_packet_t;

  typedef struct packed {
    riscv::instruction_t instruction;
    logic [XLEN-1:0] program_counter;

    logic [4:0] destination_register;

    logic [XLEN-1:0] rs1_value;
    logic [XLEN-1:0] rs2_value;

    alu_left_hand_side_operand_select_e alu_left_hand_side_operand_select;
    alu_right_hand_side_operand_select_e alu_right_hand_side_operand_select;
    alu_opcode_e alu_opcode;

    logic illegal;
    logic valid;
  } idex_packet_t;

  typedef struct packed {
    logic [XLEN-1:0] program_counter;

    logic [4:0] destination_register;

    logic [XLEN-1:0] alu_result;

    logic illegal;
    logic valid;
  } exmem_packet_t;

  typedef struct packed {
    logic [XLEN-1:0] program_counter;

    logic [4:0] destination_register;

    logic [XLEN-1:0] result;

    logic illegal;
    logic valid;
  } memwb_packet_t;

  writeback_packet_t writeback_packet;

  logic ifid_ready;
  ifid_packet_t ifid, ifid_packet;

  logic idex_ready;
  idex_packet_t idex, idex_packet;

  logic exmem_ready;
  exmem_packet_t exmem, exmem_packet;

  logic memwb_ready;
  memwb_packet_t memwb, memwb_packet;

  modport fetch_stage(
      output memory_request,
      output memory_request_address,

      input memory_response,
      input memory_response_data,

      input ifid_ready,

      output ifid_packet
  );

  modport decode_stage(
      input writeback_packet,

      input idex_ready,
      output ifid_ready,

      input ifid,
      output idex_packet
  );

  modport execute_stage(input exmem_ready, output idex_ready, input idex, output exmem_packet);

  modport memory_stage(input memwb_ready, output exmem_ready, input exmem, output memwb_packet);

  modport writeback_stage(output memwb_ready, input memwb, output writeback_packet);
endinterface : cjue_g1_core_if

module cjue_g1_instruction_fetch_stage #(
    parameter int unsigned XLEN
) (
    input logic clk,
    input logic rst,

    cjue_g1_core_if core_if
);
  logic [XLEN-1:0] program_counter;

  assign core_if.memory_request = 1'b1;
  assign core_if.memory_request_address = program_counter;

  always_ff @(posedge clk) begin
    if (rst) begin
      program_counter <= 32'h00000000;
    end else if (core_if.memory_response && core_if.ifid_ready) begin
      program_counter <= program_counter + 32'h00000004;
    end
  end

  always_comb begin
    core_if.ifid_packet.valid = 1'b0;
    core_if.ifid_packet.instruction.data = 32'h00000000;
    core_if.ifid_packet.program_counter = 32'h00000000;

    if (core_if.memory_response) begin
      core_if.ifid_packet.valid = 1'b1;
      core_if.ifid_packet.instruction.data = core_if.memory_response_data;
      core_if.ifid_packet.program_counter = program_counter;
    end
  end
endmodule : cjue_g1_instruction_fetch_stage

module cjue_g1_instruction_decoder (
    input riscv::instruction_t instruction,

    output logic [4:0] destination_register,

    output logic [4:0] rs1_index,
    output logic [4:0] rs2_index,

    output alu_left_hand_side_operand_select_e alu_left_hand_side_operand_select,
    output alu_right_hand_side_operand_select_e alu_right_hand_side_operand_select,
    output alu_opcode_e alu_opcode,

    output logic illegal
);
  always_comb begin
    casez (instruction)
      `RISCV_INSTRUCTION_FORMAT_LUI: begin
        destination_register = instruction.u_type.rd;

        rs1_index = '0;
        rs2_index = '0;

        alu_left_hand_side_operand_select = ALU_LEFT_HAND_SIDE_OPERAND_SELECT_ZERO;
        alu_right_hand_side_operand_select = ALU_RIGHT_HAND_SIDE_OPERAND_SELECT_U_TYPE_IMMEDIATE;
        alu_opcode = ALU_OPCODE_ADD;

        illegal = 1'b0;
      end
      default begin
        destination_register = '0;

        rs1_index = '0;
        rs2_index = '0;

        alu_left_hand_side_operand_select = ALU_LEFT_HAND_SIDE_OPERAND_SELECT_RS1;
        alu_right_hand_side_operand_select = ALU_RIGHT_HAND_SIDE_OPERAND_SELECT_RS2;
        alu_opcode = ALU_OPCODE_ADD;

        illegal = 1'b1;
      end
    endcase
  end
endmodule : cjue_g1_instruction_decoder

module cjue_g1_instruction_decode_stage #(
    parameter int unsigned XLEN
) (
    input logic clk,
    input logic rst,

    cjue_g1_core_if core_if
);
  logic [4:0] rs1_index;
  logic [4:0] rs2_index;

  logic [31:0][XLEN-1:0] registers, next_registers;

  cjue_g1_instruction_decoder decoder_0 (
      .instruction(core_if.ifid.instruction),

      .destination_register(core_if.idex_packet.destination_register),

      .rs1_index(rs1_index),
      .rs2_index(rs2_index),

      .alu_left_hand_side_operand_select(core_if.idex_packet.alu_left_hand_side_operand_select),
      .alu_right_hand_side_operand_select(core_if.idex_packet.alu_right_hand_side_operand_select),
      .alu_opcode(core_if.idex_packet.alu_opcode),

      .illegal(core_if.idex_packet.illegal)
  );

  always_comb begin
    next_registers = registers;

    if (core_if.writeback_packet.valid) begin
      next_registers[core_if.writeback_packet.destination_register] = core_if.writeback_packet.data;
      $display("Wrote %8x to X%0d.", core_if.writeback_packet.data,
               core_if.writeback_packet.destination_register);
    end

    core_if.idex_packet.rs1_value = next_registers[rs1_index];
    core_if.idex_packet.rs2_value = next_registers[rs2_index];
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < 32; i++) begin
        registers[i] <= 32'h00000000;
      end
    end else begin
      for (int i = 0; i < 32; i++) begin
        registers[i] <= next_registers[i];
      end
    end
  end

  assign core_if.idex_packet.instruction = core_if.ifid.instruction;
  assign core_if.idex_packet.program_counter = core_if.ifid.program_counter;

  assign core_if.idex_packet.valid = core_if.ifid.valid;

  assign core_if.ifid_ready = core_if.idex_ready;
endmodule : cjue_g1_instruction_decode_stage

module cjue_g1_alu #(
    parameter int unsigned XLEN
) (
    input logic [XLEN-1:0] left_hand_side_operand,
    input logic [XLEN-1:0] right_hand_side_operand,
    input alu_opcode_e opcode,

    output logic [XLEN-1:0] result
);
  always_comb begin
    case (opcode)
      ALU_OPCODE_ADD: result = left_hand_side_operand + right_hand_side_operand;
      default: result = 32'hffffffff;
    endcase
  end
endmodule : cjue_g1_alu

module cjue_g1_execute_stage #(
    parameter int unsigned XLEN
) (
    cjue_g1_core_if core_if
);
  logic [XLEN-1:0] left_hand_side_operand;
  logic [XLEN-1:0] right_hand_side_operand;
  logic [XLEN-1:0] result;

  always_comb begin
    case (core_if.idex.alu_left_hand_side_operand_select)
      ALU_LEFT_HAND_SIDE_OPERAND_SELECT_RS1: left_hand_side_operand = core_if.idex.rs1_value;
      ALU_LEFT_HAND_SIDE_OPERAND_SELECT_PC: left_hand_side_operand = core_if.idex.program_counter;
      ALU_LEFT_HAND_SIDE_OPERAND_SELECT_ZERO: left_hand_side_operand = 32'h00000000;
      default: left_hand_side_operand = 32'hffffffff;
    endcase
  end

  always_comb begin
    case (core_if.idex.alu_right_hand_side_operand_select)
      ALU_RIGHT_HAND_SIDE_OPERAND_SELECT_RS2: right_hand_side_operand = core_if.idex.rs2_value;
      ALU_RIGHT_HAND_SIDE_OPERAND_SELECT_I_TYPE_IMMEDIATE:
      right_hand_side_operand = `RISCV_SIGN_EXTEND_I_TYPE_IMMEDIATE(core_if.idex.instruction.data);
      ALU_RIGHT_HAND_SIDE_OPERAND_SELECT_U_TYPE_IMMEDIATE:
      right_hand_side_operand = `RISCV_SIGN_EXTEND_U_TYPE_IMMEDIATE(core_if.idex.instruction.data);
      default: right_hand_side_operand = 32'hffffffff;
    endcase
  end

  cjue_g1_alu #(
      .XLEN(XLEN)
  ) alu_0 (
      .left_hand_side_operand(left_hand_side_operand),
      .right_hand_side_operand(right_hand_side_operand),
      .opcode(core_if.idex.alu_opcode),

      .result(core_if.exmem_packet.alu_result)
  );

  assign core_if.exmem_packet.program_counter = core_if.idex.program_counter;

  assign core_if.exmem_packet.destination_register = core_if.idex.destination_register;

  assign core_if.exmem_packet.illegal = core_if.idex.illegal;
  assign core_if.exmem_packet.valid = core_if.idex.valid;

  assign core_if.idex_ready = core_if.exmem_ready;
endmodule : cjue_g1_execute_stage

module cjue_g1_memory_stage #(
    parameter int unsigned XLEN
) (
    cjue_g1_core_if core_if
);
  assign core_if.memwb_packet.program_counter = core_if.exmem.program_counter;

  assign core_if.memwb_packet.destination_register = core_if.exmem.destination_register;

  assign core_if.memwb_packet.result = core_if.exmem.alu_result;

  assign core_if.memwb_packet.illegal = core_if.exmem.illegal;
  assign core_if.memwb_packet.valid = core_if.exmem.valid;

  assign core_if.exmem_ready = core_if.memwb_ready;
endmodule : cjue_g1_memory_stage

module cjue_g1_writeback_stage (
    cjue_g1_core_if core_if
);
  always_comb begin
    core_if.writeback_packet.destination_register = '0;
    core_if.writeback_packet.data = '0;
    core_if.writeback_packet.valid = 1'b0;

    if (core_if.memwb.valid && !core_if.memwb.illegal) begin
      core_if.writeback_packet.destination_register = core_if.memwb.destination_register;
      core_if.writeback_packet.data = core_if.memwb.result;
      core_if.writeback_packet.valid = 1'b1;
    end
  end

  assign core_if.memwb_ready = 1'b1;
endmodule : cjue_g1_writeback_stage

module cjue_core_g1 (
    input logic clk,
    input logic rst,

    output logic            memory_request,
    output logic [XLEN-1:0] memory_request_address,

    input logic            memory_response,
    input logic [XLEN-1:0] memory_response_data
);
  localparam int unsigned XLEN = 32;

  cjue_g1_core_if #(
      .XLEN(XLEN)
  ) core_if (
      .memory_request(memory_request),
      .memory_request_address(memory_request_address),

      .memory_response(memory_response),
      .memory_response_data(memory_response_data)
  );

  cjue_g1_instruction_fetch_stage #(
      .XLEN(XLEN)
  ) instruction_fetch_stage_0 (
      .clk(clk),
      .rst(rst),

      .core_if(core_if.fetch_stage)
  );

  always_ff @(posedge clk) begin
    if (rst) begin
      core_if.ifid <= '0;
    end else if (core_if.ifid_ready) begin
      core_if.ifid <= core_if.ifid_packet;
    end
  end

  cjue_g1_instruction_decode_stage #(
      .XLEN(XLEN)
  ) instruction_decode_stage_0 (
      .clk(clk),
      .rst(rst),

      .core_if(core_if.decode_stage)
  );

  always_ff @(posedge clk) begin
    if (rst) begin
      core_if.idex <= '0;
    end else if (core_if.idex_ready) begin
      core_if.idex <= core_if.idex_packet;
    end
  end

  cjue_g1_execute_stage #(.XLEN(XLEN)) execute_stage_0 (.core_if(core_if.execute_stage));

  always_ff @(posedge clk) begin
    if (rst) begin
      core_if.exmem <= '0;
    end else if (core_if.exmem_ready) begin
      core_if.exmem <= core_if.exmem_packet;
    end
  end

  cjue_g1_memory_stage #(.XLEN(XLEN)) memory_stage_0 (.core_if(core_if.memory_stage));

  always_ff @(posedge clk) begin
    if (rst) begin
      core_if.memwb <= '0;
    end else if (core_if.memwb_ready) begin
      core_if.memwb <= core_if.memwb_packet;
    end
  end

  cjue_g1_writeback_stage writeback_stage_0 (.core_if(core_if.writeback_stage));

  always_comb begin
    if (core_if.memwb.valid) begin
      if (core_if.memwb.illegal) begin
        $display("Retired: (illegal)");
      end else begin
        $display("Retired: rd=%5b, v=%8x @ %8x", core_if.memwb.destination_register,
                 core_if.memwb.result, core_if.memwb.program_counter);
      end
    end
  end
endmodule : cjue_core_g1

module testbench;
  logic        clk;
  logic        rst;

  logic        memory_request;
  logic [31:0] memory_request_address;

  logic        memory_response;
  logic [31:0] memory_response_data;

  cjue_core_g1 core_0 (
      .clk(clk),
      .rst(rst),

      .memory_request(memory_request),
      .memory_request_address(memory_request_address),

      .memory_response(memory_response),
      .memory_response_data(memory_response_data)
  );

  initial begin
    clk = 0;
    forever clk = #10 ~clk;
  end

  string firmware_image_filename = "firmware/build/firmware.bin";
  int    firmware_image_file;
  int    read_code;

  always_comb begin
    memory_response = 1'b0;
    memory_response_data = 32'h00000000;

    if (memory_request) begin
      memory_response = 1'b1;

      memory_response_data[7:0] = memory[memory_request_address+32'd0];
      memory_response_data[15:8] = memory[memory_request_address+32'd1];
      memory_response_data[23:16] = memory[memory_request_address+32'd2];
      memory_response_data[31:24] = memory[memory_request_address+32'd3];
    end
  end

  logic [7:0] memory[1024];

  initial begin
    firmware_image_file = $fopen(firmware_image_filename, "r");
    if (firmware_image_file == 0) begin
      $display("Failed to open firmware binary %s.", firmware_image_filename);
      $finish;
    end

    read_code = $fread(memory, firmware_image_file, 0, 16 * 8);
    if (read_code == 0) begin
      $display("Failed to read firmware binary.");
    end else begin
      $display("Loaded %0d bytes of firmware binary into ROM.", read_code);
    end

    $display("Asserting reset...");
    rst = 1;

    @(negedge clk);
    $display("Deasserting reset...");
    rst = 0;

    #800;
    $finish;
  end

endmodule : testbench
