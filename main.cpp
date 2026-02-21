// Copyright (c) 2026 Collin Johnson

#include <systemc.h>

#include "rv32i_io/core.h"

int sc_main(int argc, char **argv) {
  sc_clock clk{"clock", 1, SC_NS};
  sc_signal<bool> rst;

  ReadOnlyMemory bios_rom{1024};
  bios_rom.LoadBinary("bios.bin");

  rv32i_io::Core core{"core"};
  core.clk(clk);
  core.rst(rst);
  core.memory(bios_rom);

  // Simulation

  rst = true;
  sc_start(1, SC_NS);

  rst = false;
  sc_start(5, SC_NS);

  return 0;
}
