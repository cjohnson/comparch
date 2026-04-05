// Copyright (c) 2026 Collin Johnson

`include "riscv.svh"

interface cjue_g1_core_if #(
    parameter int unsigned XLEN
) (
    output logic            memory_request,
    output logic [XLEN-1:0] memory_request_address,

    input logic            memory_response,
    input logic [XLEN-1:0] memory_response_data
);
  typedef struct packed {
    riscv::instruction_t instruction;
    logic [XLEN-1:0] program_counter;

    logic valid;
  } ifid_packet_t;

  typedef struct packed {
    riscv::instruction_t instruction;
    logic [XLEN-1:0] program_counter;

    logic [4:0] destination_register;

    logic illegal;
    logic valid;
  } idex_packet_t;

  logic ifid_ready;
  ifid_packet_t ifid, ifid_packet;

  logic idex_ready;
  idex_packet_t idex, idex_packet;

  modport fetch_stage(
      output memory_request,
      output memory_request_address,

      input memory_response,
      input memory_response_data,

      input ifid_ready,

      output ifid_packet
  );

  modport decode_stage(input idex_ready, output ifid_ready, input ifid, output idex_packet);
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

    output logic illegal
);
  always_comb begin
    destination_register = '0;

    rs1_index = '0;
    rs2_index = '0;

    illegal = 1'b1;

    casez (instruction)
      `RISCV_INSTRUCTION_FORMAT_LUI: begin
        destination_register = instruction.u_type.rd;

        illegal = 1'b0;
      end
      default begin
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

  cjue_g1_instruction_decoder decoder_0 (
      .instruction(core_if.ifid.instruction),

      .destination_register(core_if.idex_packet.destination_register),

      .rs1_index(rs1_index),
      .rs2_index(rs2_index),

      .illegal(core_if.idex_packet.illegal)
  );

  assign core_if.idex_packet.program_counter = core_if.ifid.program_counter;

  assign core_if.idex_packet.valid = core_if.ifid.valid;

  assign core_if.ifid_ready = core_if.idex_ready;
endmodule : cjue_g1_instruction_decode_stage

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

  always_comb begin
    if (core_if.idex.valid) begin
      $display("Retired: rd=%5b @ %8x", core_if.idex.destination_register,
               core_if.idex.program_counter);
    end
  end

  assign core_if.idex_ready = 1'b1;
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
