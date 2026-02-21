cmake_minimum_required(VERSION 3.20)
project(comparch LANGUAGES CXX)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(SYSTEMC_HOME "" CACHE PATH "Path to SystemC installation")
if (SYSTEMC_HOME STREQUAL "")
  message(FATAL_ERROR
    "SYSTEMC_HOME is not set.\n"
    "Configure like:\n"
    "  cmake -S . -B build -DSYSTEMC_HOME=/path/to/systemc\n"
    "Expected layout:\n"
    "  <SYSTEMC_HOME>/include/systemc\n"
    "  <SYSTEMC_HOME>/lib (or lib64) containing libsystemc"
  )
endif()

set(CMAKE_PREFIX_PATH ${SYSTEMC_HOME})
find_package(SystemCLanguage CONFIG REQUIRED)

add_executable(comparch
  main.cpp)
target_link_libraries(comparch SystemC::systemc)
