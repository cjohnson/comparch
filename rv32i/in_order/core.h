// Copyright (c) 2026 Collin Johnson

#ifndef RV32I_IN_ORDER_CORE_H_
#define RV32I_IN_ORDER_CORE_H_

#include <systemc.h>

#include "tilelink/master_agent.h"

namespace rv32i::in_order {

SC_MODULE(Core) {
  sc_in_clk clk{"clk"};
  sc_in<bool> rst{"rst"};

  std::shared_ptr<tilelink::MasterAgent<4, 32, 2, 1, 1>> instruction_data_agent;

  void Process();

  SC_CTOR(Core) {
    SC_CTHREAD(Process, clk.pos());
    async_reset_signal_is(rst, true);

    instruction_data_agent->clock(clk);
  }
};

}  // namespace rv32i::in_order

#endif  // RV32I_IN_ORDER_CORE_H_
