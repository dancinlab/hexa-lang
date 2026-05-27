# SSCB mk1 firmware — STM32F429ZIT6 cross-compile (CMSIS-only).
#
# Usage:
#   make check     # toolchain present?
#   make all       # → build/firmware.elf, .bin, .hex
#   make size      # arm-none-eabi-size summary
#   make clean

PREFIX  := arm-none-eabi-
CC      := $(PREFIX)gcc
LD      := $(PREFIX)gcc
OBJCOPY := $(PREFIX)objcopy
SIZE    := $(PREFIX)size

CPU     := cortex-m4
FPU     := fpv4-sp-d16
FLOAT   := hard

LDSCRIPT := linker/stm32f429zi.ld

CFLAGS := \
  -mcpu=$(CPU) -mthumb -mfpu=$(FPU) -mfloat-abi=$(FLOAT) \
  -ffreestanding \
  -isystem include/freestanding \
  -Iinclude \
  -ffunction-sections -fdata-sections \
  -O2 -Wall -Wextra -std=c99 -g

ASFLAGS := \
  -mcpu=$(CPU) -mthumb -mfpu=$(FPU) -mfloat-abi=$(FLOAT) \
  -g

LDFLAGS := \
  -mcpu=$(CPU) -mthumb -mfpu=$(FPU) -mfloat-abi=$(FLOAT) \
  -T$(LDSCRIPT) \
  -Wl,--gc-sections \
  -Wl,-Map=build/firmware.map \
  -nostdlib -nostartfiles -ffreestanding

C_SRC := $(wildcard src/*.c)
S_SRC := $(wildcard startup/*.s)

OBJS := $(C_SRC:src/%.c=build/%.o) $(S_SRC:startup/%.s=build/%.o)

.PHONY: all clean check size
all: build/firmware.elf build/firmware.bin build/firmware.hex

build:
	mkdir -p build

build/%.o: src/%.c | build
	$(CC) $(CFLAGS) -c $< -o $@

build/%.o: startup/%.s | build
	$(CC) $(ASFLAGS) -c $< -o $@

build/firmware.elf: $(OBJS) $(LDSCRIPT) | build
	$(LD) $(LDFLAGS) $(OBJS) -lgcc -o $@
	$(SIZE) $@

build/firmware.bin: build/firmware.elf
	$(OBJCOPY) -O binary $< $@

build/firmware.hex: build/firmware.elf
	$(OBJCOPY) -O ihex $< $@

size: build/firmware.elf
	$(SIZE) -A build/firmware.elf

clean:
	rm -rf build

check:
	@command -v $(CC) >/dev/null 2>&1 || { echo "MISSING: $(CC)  (brew install --cask gcc-arm-embedded)"; exit 1; }
	@$(CC) --version | head -1
	@echo "OK: ARM toolchain ready"
