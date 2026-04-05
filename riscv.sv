// Copyright (c) 2026 Collin Johnson

package riscv;
  // RISC-V base instruction format structs.
  //
  // Volume I: RISC-V Unprivileged ISA Specification
  // Chapter 2.1.2, Base Instruction Formats

  // Format of an R-Type instruction.
  typedef struct packed {
    logic [6:0] funct7;
    logic [4:0] rs2;
    logic [4:0] rs1;
    logic [2:0] funct3;
    logic [4:0] rd;
    logic [6:0] opcode;
  } r_type_instruction_t;

  // Format of an I-Type instruction.
  typedef struct packed {
    logic [11:0] imm;
    logic [4:0]  rs1;
    logic [2:0]  funct3;
    logic [4:0]  rd;
    logic [6:0]  opcode;
  } i_type_instruction_t;

  // Format of a U-Type instruction.
  typedef struct packed {
    logic [19:0] imm;
    logic [4:0]  rd;
    logic [6:0]  opcode;
  } u_type_instruction_t;

  // A union of the RISC-V instruction types.
  typedef union packed {
    logic [31:0] data;
    r_type_instruction_t r_type;
    i_type_instruction_t i_type;
    u_type_instruction_t u_type;
  } instruction_t;
endpackage : riscv
