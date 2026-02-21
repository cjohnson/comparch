// Copyright (c) 2026 Collin Johnson

#ifndef IN_ORDER_CORE_CORE_H_
#define IN_ORDER_CORE_CORE_H_

#include <systemc.h>

#include <array>
#include <vector>

struct IMemory : sc_interface {
  virtual bool Read8(uint32_t address, uint8_t& data) = 0;

  virtual bool Read32LE(uint32_t address, uint32_t& data);
};

struct ReadOnlyMemory : IMemory {
  ReadOnlyMemory(size_t size);

  void LoadBinary(const std::string& filename);

  bool Read8(uint32_t address, uint8_t& data) override;

 private:
  std::vector<uint8_t> memory_;
  size_t size_;
};

namespace rv32i_io {

struct IfIdRegister {
  bool valid;
  uint32_t pc;

  uint32_t inst;
};

struct IdExRegister {
  bool valid;
  bool illegal;

  uint32_t pc;

  uint32_t rd;
  uint32_t v1;
  uint32_t v2;
};

struct ExMemRegister {
  bool valid;
  bool illegal;

  uint32_t pc;

  uint32_t rd;
  uint32_t v;
};

struct MemWbRegister {
  bool valid;
  bool illegal;

  uint32_t pc;

  uint32_t rd;
  uint32_t v;
};

SC_MODULE(Core) {
  sc_in_clk clk{"clk"};
  sc_in<bool> rst{"rst"};

  sc_port<IMemory> memory{"memory"};

  void Process();

  SC_CTOR(Core) {
    SC_METHOD(Process);
    sensitive << clk.pos();
  }

 private:
  uint32_t pc;
  IfIdRegister ifid;

  std::array<uint32_t, 32> user_registers;
  IdExRegister idex;

  ExMemRegister exmem;

  MemWbRegister memwb;
};

}  // namespace rv32i_io

#endif  // IN_ORDER_CORE_CORE_H_
