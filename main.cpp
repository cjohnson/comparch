// Copyright (c) 2026 Collin Johnson

#include <systemc.h>

#include "in_order_core.h"

int sc_main(int argc, char **argv) {
  sc_clock clk{"clock", 1, SC_NS};

  InOrderCore core{"core"};
  core.clk(clk);

  return 0;
}
