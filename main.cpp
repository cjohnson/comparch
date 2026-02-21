#include <systemc.h>

int sc_main(int argc, char **argv) {
  sc_clock clock{"clock", 1, SC_NS};

  return 0;
}
