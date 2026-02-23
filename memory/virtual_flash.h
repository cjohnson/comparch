// Copyright (c) 2026 Collin Johnson

#ifndef MEMORY_VIRTUAL_FLASH_H_
#define MEMORY_VIRTUAL_FLASH_H_

#include <cstdint>
#include <vector>

#include "memory/interface.h"

namespace memory {

struct VirtualFlash : public IMemory {
  VirtualFlash(size_t size_bytes);

  void LoadImageFromFile(const std::string& filename);

  bool Read8(uint32_t address, uint8_t& data) override;

 private:
  std::vector<uint8_t> memory_;
  size_t size_bytes_;
};

}  // namespace memory

#endif  // MEMORY_VIRTUAL_FLASH_H_
