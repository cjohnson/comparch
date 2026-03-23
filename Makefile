VERILATOR = verilator

SRCS = \
	rv32i/in_order/core.sv

.PHONY: clean

build: $(SRCS)
	$(VERILATOR) --binary -j 0 $(SRCS)

clean:
	rm -rf obj_dir/
