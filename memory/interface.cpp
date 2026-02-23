// Copyright (c) 2026 Collin Johnson

#include "memory/interface.h"

bool memory::IMemory::Read32LE(uint32_t address, uint32_t& data) {
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

