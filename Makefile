VERILATOR = verilator
CMAKE = cmake

SRCS = \
	rv32i/in_order/core.sv

.PHONY: clean

build: $(SRCS)
	$(VERILATOR) --binary -j 0 $(SRCS)
	$(CMAKE) --build firmware/build

clean:
	rm -rf obj_dir/
