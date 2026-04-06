VERILATOR = verilator
CMAKE = cmake

SRCS = \
	rtl/cjue_core_g1.sv

.PHONY: clean

build: $(SRCS)
	$(VERILATOR) --binary -j 0 $(SRCS)
	$(CMAKE) --build firmware/build

clean:
	rm -rf obj_dir/
