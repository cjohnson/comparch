// Copyright (c) 2026 Collin Johnson

#include "rv32i_io/core.h"

#include <fstream>
#include <iomanip>
#include <stdexcept>

bool IMemory::Read32LE(uint32_t address, uint32_t& data) {
  uint8_t byte;
  uint32_t out = 0;

  if (!Read8(address + 0u, byte)) return false;
  out |= byte << 0u;

  if (!Read8(address + 1u, byte)) return false;
  out |= byte << 8u;

  if (!Read8(address + 2u, byte)) return false;
  out |= byte << 16u;

  if (!Read8(address + 3u, byte)) return false;
  out |= byte << 24u;

  data = out;
  return true;
}

ReadOnlyMemory::ReadOnlyMemory(size_t size) : size_(size) {}

void ReadOnlyMemory::LoadBinary(const std::string& filename) {
  std::ifstream file(filename, std::ios::binary);
  if (!file) throw std::runtime_error{"Failed to open binary file"};

  file.seekg(0, std::ios::end);
  size_t size = file.tellg();
  file.seekg(0, std::ios::beg);

  if (size > memory_.size()) memory_.resize(size);

  file.read(reinterpret_cast<char*>(&memory_[0]), size);
}

bool ReadOnlyMemory::Read8(uint32_t address, uint8_t& data) {
  if (address >= memory_.size())
    data = 0;
  else
    data = memory_[address];
  return true;
}

void rv32i_io::Core::Process() {
  std::array<uint32_t, 32> next_user_registers;
  ProcessWriteback(next_user_registers);

  MemWbRegister next_memwb;
  ForwardPacket mem_forward;
  ProcessMemory(next_memwb, mem_forward);

  ExMemRegister next_exmem;
  ForwardPacket ex_forward;
  ProcessExecute(next_exmem, ex_forward);

  IdExRegister next_idex;
  ProcessDecode(next_user_registers, ex_forward, mem_forward, next_idex);

  uint32_t next_pc;
  IfIdRegister next_ifid;
  ProcessFetch(next_pc, next_ifid);

  if (rst) {
    pc = 0;
    ifid.valid = 0;

    user_registers = {0};
    idex.valid = 0;

    exmem.valid = 0;

    memwb.valid = 0;
  } else {
    pc = next_pc;
    ifid = next_ifid;

    user_registers = next_user_registers;
    idex = next_idex;

    exmem = next_exmem;

    memwb = next_memwb;
  }

  if (memwb.valid) {
    if (memwb.illegal) {
      std::cout << '[' << sc_time_stamp() << ']'
                << " [WARN] [HART 0]: Retired ILLEGAL instruction @ PC "
                << std::setfill('0') << std::setw(8) << std::hex << memwb.pc
                << '\n';
    } else {
      std::cout << '[' << sc_time_stamp() << ']'
                << " [TRACE] [HART 0]: Retired ";

      switch (memwb.opcode) {
        case Opcode::ADDI:
          std::cout << "ADDI";
          break;
        case Opcode::SLTI:
          std::cout << "SLTI";
          break;
        case Opcode::SLTIU:
          std::cout << "SLTIU";
          break;
        case Opcode::XORI:
          std::cout << "XORI";
          break;
        case Opcode::ORI:
          std::cout << "ORI";
          break;
        case Opcode::ANDI:
          std::cout << "ANDI";
          break;
        case Opcode::SLLI:
          std::cout << "SLLI";
          break;
        case Opcode::SRLI:
          std::cout << "SRLI";
          break;
        case Opcode::SRAI:
          std::cout << "SRAI";
          break;
        case Opcode::ADD:
          std::cout << "ADD";
          break;
      }

      std::cout << " instruction @ PC " << std::setfill('0') << std::setw(8)
                << std::hex << memwb.pc << '\n';
    }
  }
}

void rv32i_io::Core::ProcessFetch(uint32_t& next_pc, IfIdRegister& next_ifid) {
  next_pc = pc;

  next_ifid.valid = false;

  uint32_t inst;
  if (!memory->Read32LE(pc, inst)) return;

  next_pc = pc + 4;

  next_ifid.valid = true;
  next_ifid.inst = inst;
  next_ifid.pc = pc;
}

void rv32i_io::Core::ProcessDecode(
    const std::array<uint32_t, 32>& next_user_registers,
    const ForwardPacket& ex_forward, const ForwardPacket& mem_forward,
    IdExRegister& next_idex) {
  next_idex.valid = false;
  if (!ifid.valid) return;

  next_idex.valid = true;
  next_idex.illegal = false;

  next_idex.pc = ifid.pc;

  auto sign_extend = [](uint32_t x, uint32_t b) {
    int m = 1U << (b - 1);
    return (x ^ m) - m;
  };

  auto read_register = [&](uint32_t r, uint32_t& v) {
    if (ex_forward.valid && ex_forward.rd == r) {
      if (!ex_forward.data_valid) return false;
      v = ex_forward.data;
      return true;
    }

    if (mem_forward.valid && mem_forward.rd == r) {
      if (!mem_forward.data_valid) return false;
      v = mem_forward.data;
      return true;
    }

    v = next_user_registers[r];
    return true;
  };

  uint32_t opcode = (ifid.inst) & 0b1111111;
  if (opcode == 0b0010011) {
    next_idex.rd = (ifid.inst >> 7) & 0b11111;

    uint32_t imm = (ifid.inst >> 20) & 0b111111111111;

    uint32_t funct3 = (ifid.inst >> 12) & 0b111;
    switch (funct3) {
      case 0b000:
        next_idex.opcode = Opcode::ADDI;
        break;
      case 0b010:
        next_idex.opcode = Opcode::SLTI;
        break;
      case 0b011:
        next_idex.opcode = Opcode::SLTIU;
        break;
      case 0b100:
        next_idex.opcode = Opcode::XORI;
        break;
      case 0b110:
        next_idex.opcode = Opcode::ORI;
        break;
      case 0b111:
        next_idex.opcode = Opcode::ANDI;
        break;
      case 0b001:
        next_idex.opcode = Opcode::SLLI;
        break;
      case 0b101: {
        int arithmetic_flag = (imm >> 10) & 0x1;
        next_idex.opcode = arithmetic_flag ? Opcode::SRAI : Opcode::SRLI;
        break;
      }
      default:
        next_idex.illegal = true;
        break;
    }

    uint32_t rs1 = (ifid.inst >> 15) & 0b11111;
    if (!read_register(rs1, next_idex.v1)) {
      next_idex.valid = false;
      return;
    }

    switch (funct3) {
      case 0b000:
      case 0b010:
      case 0b011:
      case 0b100:
      case 0b110:
      case 0b111:
        next_idex.imm = sign_extend(imm, 12);
        break;
      case 0b001:
      case 0b101:
        next_idex.imm = imm & 0b11111;
        break;
      default:
        next_idex.illegal = true;
        break;
    }
  } else if (opcode == 0b0110011) {
    next_idex.rd = (ifid.inst >> 7) & 0b11111;

    uint32_t funct3 = (ifid.inst >> 12) & 0b111;
    switch (funct3) {
      case 0b000:
        next_idex.opcode = Opcode::ADD;
        break;
      default:
        next_idex.illegal = true;
        break;
    }

    uint32_t rs1 = (ifid.inst >> 15) & 0b11111;
    if (!read_register(rs1, next_idex.v1)) {
      next_idex.valid = false;
      return;
    }

    uint32_t rs2 = (ifid.inst >> 20) & 0b11111;
    if (!read_register(rs2, next_idex.v2)) {
      next_idex.valid = false;
      return;
    }
  } else {
    next_idex.illegal = true;
  }
}

void rv32i_io::Core::ProcessExecute(ExMemRegister& next_exmem,
                                    ForwardPacket& forward) {
  next_exmem.valid = false;

  forward.valid = false;

  if (!idex.valid) return;

  next_exmem.valid = true;
  next_exmem.illegal = idex.illegal;

  next_exmem.pc = idex.pc;

  next_exmem.opcode = idex.opcode;
  next_exmem.rd = idex.rd;

  switch (idex.opcode) {
    case Opcode::ADDI:
      next_exmem.v = idex.v1 + idex.imm;
      break;
    case Opcode::SLTI: {
      int32_t sv1 = (int32_t)idex.v1;
      int32_t sv2 = (int32_t)idex.imm;
      next_exmem.v = (sv1 < sv2) ? 1 : 0;
      break;
    }
    case Opcode::SLTIU:
      next_exmem.v = (idex.v1 < idex.imm) ? 1 : 0;
      break;
    case Opcode::XORI:
      next_exmem.v = idex.v1 ^ idex.imm;
      break;
    case Opcode::ORI:
      next_exmem.v = idex.v1 | idex.imm;
      break;
    case Opcode::ANDI:
      next_exmem.v = idex.v1 & idex.imm;
      break;
    case Opcode::SLLI:
      next_exmem.v = idex.v1 << idex.imm;
      break;
    case Opcode::SRLI:
      next_exmem.v = idex.v1 >> idex.imm;
      break;
    case Opcode::SRAI: {
      int32_t sv1 = (int32_t)idex.v1;
      int32_t sv2 = (int32_t)idex.imm;
      next_exmem.v = sv1 >> sv2;
      break;
    }
    case Opcode::ADD:
      next_exmem.v = idex.v1 + idex.v2;
      break;
    default:
      next_exmem.illegal = true;
      next_exmem.v = 0;
      break;
  }

  switch (idex.opcode) {
    case Opcode::ADDI:
    case Opcode::SLTI:
    case Opcode::SLTIU:
    case Opcode::XORI:
    case Opcode::ORI:
    case Opcode::ANDI:
    case Opcode::SLLI:
    case Opcode::SRLI:
    case Opcode::SRAI:
    case Opcode::ADD:
      forward.valid = true;
      forward.rd = idex.rd;
      forward.data_valid = true;
      forward.data = next_exmem.v;
      break;
    default:
      break;
  }
}

void rv32i_io::Core::ProcessMemory(MemWbRegister& next_memwb,
                                   ForwardPacket& forward) {
  next_memwb.valid = false;

  forward.valid = false;

  if (!exmem.valid) return;

  next_memwb.valid = exmem.valid;
  next_memwb.illegal = exmem.illegal;

  next_memwb.pc = exmem.pc;

  next_memwb.opcode = exmem.opcode;
  next_memwb.v = exmem.v;
  next_memwb.rd = exmem.rd;

  switch (exmem.opcode) {
    case Opcode::ADDI:
    case Opcode::SLTI:
    case Opcode::SLTIU:
    case Opcode::XORI:
    case Opcode::ORI:
    case Opcode::ANDI:
    case Opcode::SLLI:
    case Opcode::SRLI:
    case Opcode::SRAI:
    case Opcode::ADD:
      forward.valid = true;
      forward.rd = exmem.rd;
      forward.data_valid = true;
      forward.data = next_memwb.v;
      break;
    default:
      break;
  }
}

void rv32i_io::Core::ProcessWriteback(
    std::array<uint32_t, 32>& next_user_registers) {
  next_user_registers = user_registers;
  if (memwb.valid) next_user_registers[memwb.rd] = memwb.v;
}
