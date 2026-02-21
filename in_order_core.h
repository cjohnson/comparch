// Copyright (c) 2026 Collin Johnson

#ifndef IN_ORDER_CORE_H_
#define IN_ORDER_CORE_H_

#include <systemc.h>

SC_MODULE(InOrderCore) {
  sc_in_clk clk;

  void Process();

  SC_CTOR(InOrderCore) {
    SC_METHOD(Process);
    sensitive << clk.pos();
  }
};

#endif // IN_ORDER_CORE_H_
