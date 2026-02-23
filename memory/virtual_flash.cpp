// Copyright (c) 2026 Collin Johnson

#include "memory/virtual_flash.h"

memory::VirtualFlash::VirtualFlash(size_t size_bytes)
    : size_bytes_(size_bytes) {}

void memory::VirtualFlash::LoadImageFromFile(const std::string& filename) {
  std::ifstream file(filename, std::ios::binary);
  if (!file) {
    throw std::runtime_error{
        "Failed to open flash image from file; File does not exist."};
  }

  file.seekg(0, std::ios::end);
  size_t size = file.tellg();
  file.seekg(0, std::ios::beg);

  if (size > memory_.size()) memory_.resize(size);

  file.read(reinterpret_cast<char*>(&memory_[0]), size);
}

bool memory::VirtualFlash::Read8(uint32_t address, uint8_t& data) {
  if (address >= memory_.size())
    data = 0;
  else
    data = memory_[address];
  return true;
}
