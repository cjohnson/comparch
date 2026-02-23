cmake_minimum_required(VERSION 3.20)
project(firmware LANGUAGES C ASM)

add_executable(firmware.elf
  start.s
)

target_compile_options(firmware.elf PRIVATE
  -march=rv32i
  -mabi=ilp32
  -ffreestanding
)

target_link_options(firmware.elf PRIVATE
  -march=rv32i
  -mabi=ilp32
  -nostdlib
  -ffreestanding
  -T ${CMAKE_CURRENT_LIST_DIR}/firmware.ld
  -Wl,-Map=${CMAKE_CURRENT_BINARY_DIR}/firmware.map
)

add_custom_command(
  TARGET firmware.elf POST_BUILD
  COMMAND "${CMAKE_OBJCOPY}" -O binary
          "$<TARGET_FILE:firmware.elf>"
          "${CMAKE_CURRENT_BINARY_DIR}/firmware.bin"
  BYPRODUCTS "${CMAKE_CURRENT_BINARY_DIR}/firmware.bin"
  COMMENT "Generating flash image (firmware.bin)"
  VERBATIM
)

add_custom_command(
  TARGET firmware.elf POST_BUILD
  COMMAND "${CMAKE_OBJDUMP}" -d
          "$<TARGET_FILE:firmware.elf>"
          > "${CMAKE_CURRENT_BINARY_DIR}/firmware.dis"
  COMMAND "${CMAKE_OBJDUMP}" -S
          "$<TARGET_FILE:firmware.elf>"
          > "${CMAKE_CURRENT_BINARY_DIR}/firmware.lst"
  BYPRODUCTS
          "${CMAKE_CURRENT_BINARY_DIR}/firmware.dis"
          "${CMAKE_CURRENT_BINARY_DIR}/firmware.lst"
  COMMENT "Generating disassembly (firmware.dis, firmware.lst)"
  VERBATIM
)
