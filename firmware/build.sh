cd "$(dirname "$0")"

riscv32-unknown-elf-gcc \
	-march=rv32i \
	-mabi=ilp32 \
	-nostdlib \
	-ffreestanding \
	-o firmware.elf \
	start.s

riscv32-unknown-elf-objcopy \
	-O binary \
	firmware.elf \
	firmware.bin
