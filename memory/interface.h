// Copyright (c) 2026 Collin Johnson

#ifndef MEMORY_INTERFACE_H_
#define MEMORY_INTERFACE_H_

#include <systemc.h>

namespace memory {

struct IMemory : sc_interface {
  virtual bool Read8(uint32_t address, uint8_t& data) = 0;

  virtual bool Read32LE(uint32_t address, uint32_t& data);
};

}

#endif  // MEMORY_INTERFACE_H_
