// Copyright (c) 2026 Collin Johnson

`ifndef RISCV_SVH_
`define RISCV_SVH_

// Base opcode case-matching macro definitions
//
// Volume I: RISC-V Unprivileged ISA Specification
// Chapter 35.1, RV32/RV64G Instruction Set Listings
// Table 1, RISC-V base opcode map, inst[1:0]=11

// Base opcode for most register-immediate instructions
// Ex: ADDI, SLTI, ANDI, etc.
`define RV32_BASE_OPCODE_OP_IMM {2'b00, 3'b100, 2'b11}

// Base opcode for AUIPC (add upper immediate to pc) instructions
`define RV32_BASE_OPCODE_AUIPC {2'b00, 3'b101, 2'b11}

// Base opcode for most register-register instructions
// Ex: ADD, SUB, SLL, etc.
`define RV32_BASE_OPCODE_OP {2'b01, 3'b100, 2'b11}

// Base opcode for LUI (load upper immediate) instructions
`define RV32_BASE_OPCODE_LUI {2'b01, 3'b101, 2'b11}

// Base instruction format case-matching macro definitions
//
// Volume I: RISC-V Unprivileged ISA Specification
// Chapter 2.1.2, Base Instruction Formats

// R-Type instruction format for the provided base opcode,
// funct3 and funct7 to match against in a casez block.
`define RV32_R_TYPE_INSTRUCTION(opcode, funct3, funct7) \
    {``funct7``, {5{1'b?}}, {5{1'b?}}, ``funct3``, {5{1'b?}}, ``opcode``}

// I-Type instruction format for the provided base opcode and
// funct3 to match against in a casez block.
`define RV32_I_TYPE_INSTRUCTION(opcode, funct3) \
    {{12{1'b?}}, {5{1'b?}}, ``funct3``, {5{1'b?}}, ``opcode``}

// Shift-specialized I-Type instruction format for the provided
// opcode, funct3, and shift specifier.
`define RV32_SHIFT_I_TYPE_INSTRUCTION(opcode, funct3, shift_specifier) \
    {``shift_specifier``, {5{1'b?}}, {5{1'b?}}, ``funct3``, {5{1'b?}}, ``opcode``}

// U-Type instruction format for the provided base opcode
// to match against in a casez block.
`define RV32_U_TYPE_INSTRUCTION(opcode) \
    {{20{1'b?}}, {5{1'b?}}, ``opcode``}

// Instruction format case-matching macro definitions
//
// Volume I: RISC-V Unprivileged ISA Specification
// Chapter 35.1, RV32/RV64G Instruction Set Listings

// LUI (load upper immediate) instruction format to match against.
`define RV32_LUI `RV32_U_TYPE_INSTRUCTION(`RV32_BASE_OPCODE_LUI)

// AUIPC (add upper immediate to pc) instruction format to match against.
`define RV32_AUIPC `RV32_U_TYPE_INSTRUCTION(`RV32_BASE_OPCODE_AUIPC)

// ADDI (add signed immediate to register) instruction format to match
// against.
`define RV32_ADDI `RV32_I_TYPE_INSTRUCTION(`RV32_BASE_OPCODE_OP_IMM, 3'b000)

// SLTI (set less than immediate) instruction format to match against.
`define RV32_SLTI `RV32_I_TYPE_INSTRUCTION(`RV32_BASE_OPCODE_OP_IMM, 3'b010)

// SLTIU (set less than immediate, compare as unsigned) instruction format
// to match against.
`define RV32_SLTIU `RV32_I_TYPE_INSTRUCTION(`RV32_BASE_OPCODE_OP_IMM, 3'b011)

// XORI (register xor with immediate) instruction format to match against.
`define RV32_XORI `RV32_I_TYPE_INSTRUCTION(`RV32_BASE_OPCODE_OP_IMM, 3'b100)

// ORI (register or with immediate) instruction format to match against.
`define RV32_ORI `RV32_I_TYPE_INSTRUCTION(`RV32_BASE_OPCODE_OP_IMM, 3'b110)

// ANDI (register and with immediate) instruction format to match against.
`define RV32_ANDI `RV32_I_TYPE_INSTRUCTION(`RV32_BASE_OPCODE_OP_IMM, 3'b111)

// SLLI (shift left logical register by immediate) instruction format to
// match against.
`define RV32_SLLI \
    `RV32_SHIFT_I_TYPE_INSTRUCTION(`RV32_BASE_OPCODE_OP_IMM, 3'b001, 7'b0000000)

// SRLI (shift right logical register by immediate) instruction format to
// match against.
`define RV32_SRLI \
    `RV32_SHIFT_I_TYPE_INSTRUCTION(`RV32_BASE_OPCODE_OP_IMM, 3'b101, 7'b0000000)

// SRAI (shift right arithmetic register by immediate) instruction format
// to match against.
`define RV32_SRAI \
    `RV32_SHIFT_I_TYPE_INSTRUCTION(`RV32_BASE_OPCODE_OP_IMM, 3'b101, 7'b0100000)

// ADD (add register to register) instruction format to match against.
`define RV32_ADD `RV32_R_TYPE_INSTRUCTION(`RV32_BASE_OPCODE_OP, 3'b000, 7'b0000000)

// SUB (subtract register from register) instruction format to match against.
`define RV32_SUB `RV32_R_TYPE_INSTRUCTION(`RV32_BASE_OPCODE_OP, 3'b000, 7'b0100000)

// SLL (shift left logical register by register) instruction format to match
// against.
`define RV32_SLL `RV32_R_TYPE_INSTRUCTION(`RV32_BASE_OPCODE_OP, 3'b001, 7'b0000000)

// SLT (set less than register) instruction format to match against.
`define RV32_SLT `RV32_R_TYPE_INSTRUCTION(`RV32_BASE_OPCODE_OP, 3'b010, 7'b0000000)

// SLTU (set less than register, compare as unsigned) instruction format to match
// against.
`define RV32_SLTU `RV32_R_TYPE_INSTRUCTION(`RV32_BASE_OPCODE_OP, 3'b011, 7'b0000000)

// XOR (register xor with register) instruction format to match against.
`define RV32_XOR `RV32_R_TYPE_INSTRUCTION(`RV32_BASE_OPCODE_OP, 3'b100, 7'b0000000)

// SRL (shift right logical register by register) instruction format to match
// against.
`define RV32_SRL `RV32_R_TYPE_INSTRUCTION(`RV32_BASE_OPCODE_OP, 3'b101, 7'b0000000)

// SRAI (shift right arithmetic register by register) instruction format to match
// against.
`define RV32_SRA `RV32_R_TYPE_INSTRUCTION(`RV32_BASE_OPCODE_OP, 3'b101, 7'b0100000)

// OR (register or with register) instruction format to match against.
`define RV32_OR `RV32_R_TYPE_INSTRUCTION(`RV32_BASE_OPCODE_OP, 3'b110, 7'b0000000)

// AND (register and with register) instruction format to match against.
`define RV32_AND `RV32_R_TYPE_INSTRUCTION(`RV32_BASE_OPCODE_OP, 3'b111, 7'b0000000)

`endif  // RISCV_SVH_
