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

# Hand-written firmware C sources, MINUS any files now generated at build time
# from hexa emitters (B9.C-1 .c-leg pattern — see ADC_DMA_GEN below).
C_SRC := $(filter-out src/adc_dma.c,$(wildcard src/*.c))

HEXA_RUN  ?= hexa-run
REPO_ROOT ?= $(abspath $(CURDIR)/../../..)

# Hexa-emitted startup `.s` (F5 RFC 063/064 stm32f429 leg).
# `startup_stm32f429.s` is generated at build time from
# stdlib/hal/boot_emit.hexa::stm32f429_emit_full_startup_s; the hand-
# written `.s` was `git rm`d once the byte-diff oracle
# (stdlib/sscb/firmware/startup/boot_byte_diff_stm32f429.hexa) proved
# gen ≡ orig 10/10 PASS (.isr_vector + .text.Reset_Handler +
# .text.Default_Handler + reloc lists for all three).
STARTUP_GEN ?= $(REPO_ROOT)/stdlib/sscb/firmware/startup/startup_stm32f429_gen.hexa
S_GEN     := startup/startup_stm32f429.s
S_SRC     := $(S_GEN)

# Hexa-emitted adc_dma.c (B9.C-1 .c-leg — first .c parallel of the F5 .s leg).
# `src/adc_dma.c` is generated at build time from
# stdlib/sscb/firmware/src/adc_dma_emit.hexa::emit_adc_dma_c; the hand-
# written `.c` was `git rm`d once the byte-diff oracle
# (stdlib/sscb/firmware/src/adc_dma_byte_diff.hexa) proved
# gen ≡ orig 6/6 PASS (source-text · whole-file .o no-debug ·
# .text.adc_spi_dma_init section with -g).
ADC_DMA_GEN ?= $(REPO_ROOT)/stdlib/sscb/firmware/src/adc_dma_emit.hexa
ADC_DMA_C   := src/adc_dma.c

OBJS := $(C_SRC:src/%.c=build/%.o) build/adc_dma.o $(S_SRC:startup/%.s=build/%.o)

.PHONY: all clean check size
all: build/firmware.elf build/firmware.bin build/firmware.hex

build:
	mkdir -p build

build/%.o: src/%.c | build
	$(CC) $(CFLAGS) -c $< -o $@

# Hexa-emitted startup.s — regenerated whenever the emitter or its
# inputs change. Quad dependency captures the full chain: per-target
# generator, CMSIS composer, vector-table emitter, prologue emitter.
$(S_GEN): $(STARTUP_GEN) \
          $(REPO_ROOT)/stdlib/hal/boot_emit.hexa \
          $(REPO_ROOT)/stdlib/hal/vector_table_emit.hexa \
          $(REPO_ROOT)/stdlib/hal/reset_prologue_emit.hexa
	$(HEXA_RUN) $(STARTUP_GEN) $@

# Hexa-emitted adc_dma.c — regenerated whenever the emitter changes.
# Generator owns the SSOT; the .c on disk is a build artifact.
$(ADC_DMA_C): $(ADC_DMA_GEN)
	$(HEXA_RUN) $(ADC_DMA_GEN) $@

build/adc_dma.o: $(ADC_DMA_C) | build
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
	rm -f $(S_GEN)
	rm -f $(ADC_DMA_C)

check:
	@command -v $(CC) >/dev/null 2>&1 || { echo "MISSING: $(CC)  (brew install --cask gcc-arm-embedded)"; exit 1; }
	@$(CC) --version | head -1
	@echo "OK: ARM toolchain ready"
