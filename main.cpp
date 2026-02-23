// Copyright (c) 2026 Collin Johnson

#include <systemc.h>

#include "memory/virtual_flash.h"
#include "rv32i_io/core.h"

int sc_main(int argc, char** argv) {
  if (argc < 2) {
    std::cerr << "Usage: " << argv[0] << " <firmware binary path>\n";
    return 1;
  }
  std::string firmware_binary_path = argv[1];

  sc_clock clk{"clock", 1, SC_NS};
  sc_signal<bool> rst;

  memory::VirtualFlash rom{64 * (1 << 10)};
  rom.LoadImageFromFile(firmware_binary_path);

  rv32i_io::Core core{"core"};
  core.clk(clk);
  core.rst(rst);
  core.memory(rom);

  // Simulation

  rst = true;
  sc_start(1, SC_NS);

  rst = false;
  sc_start(12, SC_NS);

  std::cout << "\n";
  std::cout << "Final machine state:\n";
  for (uint32_t r = 0; r < 32; ++r) {
    if (core.user_registers[r] != 0)
      std::cout << "r[" << r << "] = 0x" << core.user_registers[r] << "\n";
  }

  return 0;
}
