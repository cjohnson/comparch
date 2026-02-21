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
  std::array<uint32_t, 32> next_user_registers = user_registers;

  if (memwb.valid) {
    next_user_registers[memwb.rd] = memwb.v;
  }

  MemWbRegister next_memwb;
  next_memwb.valid = false;

  if (exmem.valid) {
    next_memwb.valid = exmem.valid;
    next_memwb.illegal = exmem.illegal;

    next_memwb.pc = exmem.pc;

    next_memwb.rd = exmem.rd;
    next_memwb.v = exmem.v;
  }

  ExMemRegister next_exmem;
  next_exmem.valid = false;

  if (idex.valid) {
    next_exmem.valid = true;
    next_exmem.illegal = idex.illegal;

    next_exmem.pc = idex.pc;

    next_exmem.rd = idex.rd;
    next_exmem.v = idex.v1 + idex.v2;
  }

  IdExRegister next_idex;
  next_idex.valid = false;

  if (ifid.valid) {
    next_idex.valid = true;
    next_idex.illegal = false;

    next_idex.pc = ifid.pc;

    uint32_t opcode = (ifid.inst) & 0b1111111;
    if (opcode == 0b0010011) {
      next_idex.rd = (ifid.inst >> 7) & 0b11111;
      uint32_t funct3 = (ifid.inst >> 12) & 0b111;

      if (funct3 == 0b000) {
        uint32_t rs1 = (ifid.inst >> 15) & 0b11111;

        if (next_exmem.valid && next_exmem.rd == rs1)
          next_idex.v1 = next_exmem.v;
        else
          next_idex.v1 = next_user_registers[rs1];

        uint32_t imm = (ifid.inst >> 20) & 0b111111111111;
        int m = 1U << (12 - 1);
        imm = (imm ^ m) - m;

        next_idex.v2 = imm;
      }
    } else {
      next_idex.illegal = true;
    }
  }

  uint32_t next_pc = pc;

  IfIdRegister next_ifid;
  next_ifid.valid = false;

  uint32_t inst;
  if (memory->Read32LE(pc, inst)) {
    next_pc = pc + 4;

    next_ifid.valid = true;
    next_ifid.inst = inst;
    next_ifid.pc = pc;
  }

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

  if (ifid.valid) {
    std::cout << '[' << sc_time_stamp() << ']' << " [TRACE] [HART 0] IF/ID:\n";
    std::cout << "    PC=" << std::setfill('0') << std::setw(8) << std::hex
              << ifid.pc << '\n';
    std::cout << "    INST=" << std::setfill('0') << std::setw(8) << std::hex
              << ifid.inst << '\n';
  }

  if (idex.valid && !idex.illegal) {
    std::cout << '[' << sc_time_stamp() << ']' << " [TRACE] [HART 0] ID/EX:\n";
    std::cout << "    PC=" << std::setfill('0') << std::setw(8) << std::hex
              << idex.pc << '\n';
    std::cout << "    RD=" << std::dec << idex.rd << '\n';
    std::cout << "    V1=" << std::setfill('0') << std::setw(8) << std::hex
              << idex.v1 << '\n';
    std::cout << "    V2=" << std::setfill('0') << std::setw(8) << std::hex
              << idex.v2 << '\n';
  }

  if (exmem.valid && !exmem.illegal) {
    std::cout << '[' << sc_time_stamp() << ']' << " [TRACE] [HART 0] EX/MEM:\n";
    std::cout << "    PC=" << std::setfill('0') << std::setw(8) << std::hex
              << exmem.pc << '\n';
    std::cout << "    RD=" << std::dec << exmem.rd << '\n';
    std::cout << "    V=" << std::setfill('0') << std::setw(8) << std::hex
              << exmem.v << '\n';
  }

  if (memwb.valid && !memwb.illegal) {
    std::cout << '[' << sc_time_stamp() << ']' << " [TRACE] [HART 0] MEM/WB:\n";
    std::cout << "    PC=" << std::setfill('0') << std::setw(8) << std::hex
              << memwb.pc << '\n';
    std::cout << "    RD=" << std::dec << memwb.rd << '\n';
    std::cout << "    V=" << std::setfill('0') << std::setw(8) << std::hex
              << memwb.v << '\n';
  }
  if (memwb.valid && memwb.illegal) {
    std::cout << '[' << sc_time_stamp() << ']'
              << " [WARN] [HART 0] Writeback: Retired illegal instruction.\n";
  }
}
