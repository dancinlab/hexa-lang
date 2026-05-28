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
# from hexa emitters (B9.C-1 / B9.C-2 .c-leg pattern — see *_GEN below).
# B9.C-1 (#1847): adc_dma.c
# B9.C-2 (this batch): gate_driver.c · system_init.c · fault_handler.c · main.c
C_SRC := $(filter-out src/adc_dma.c \
                       src/gate_driver.c \
                       src/system_init.c \
                       src/fault_handler.c \
                       src/main.c, \
                       $(wildcard src/*.c))

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

# Hexa-emitted firmware sources (B9.C-2 batch — gate_driver / system_init /
# fault_handler / main). Same pattern as ADC_DMA above: each .c is generated
# at build time from its `_emit.hexa` SSOT; the hand-written `.c` was
# `git rm`d once the per-file byte-diff oracle proved gen ≡ orig 6/6 PASS.
GATE_DRIVER_GEN   ?= $(REPO_ROOT)/stdlib/sscb/firmware/src/gate_driver_emit.hexa
GATE_DRIVER_C     := src/gate_driver.c
SYSTEM_INIT_GEN   ?= $(REPO_ROOT)/stdlib/sscb/firmware/src/system_init_emit.hexa
SYSTEM_INIT_C     := src/system_init.c
FAULT_HANDLER_GEN ?= $(REPO_ROOT)/stdlib/sscb/firmware/src/fault_handler_emit.hexa
FAULT_HANDLER_C   := src/fault_handler.c
MAIN_GEN          ?= $(REPO_ROOT)/stdlib/sscb/firmware/src/main_emit.hexa
MAIN_C            := src/main.c

# Link order — preserved exactly from the pre-batch baseline (alphabetical
# `$(wildcard src/*.c)` sorts to fault_handler · gate_driver · main ·
# system_init; adc_dma was appended after that wildcard expansion; startup
# last). Holding the order = byte-identical firmware.elf vs the hand-
# written-source baseline (deterministic gold reference for the .c → .hexa
# transition).
OBJS := $(C_SRC:src/%.c=build/%.o) \
        build/fault_handler.o \
        build/gate_driver.o \
        build/main.o \
        build/system_init.o \
        build/adc_dma.o \
        $(S_SRC:startup/%.s=build/%.o)

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

# Hexa-emitted B9.C-2 batch — gate_driver / system_init / fault_handler /
# main. Same shape as the adc_dma rule above; each emitter is the SSOT.
$(GATE_DRIVER_C): $(GATE_DRIVER_GEN)
	$(HEXA_RUN) $(GATE_DRIVER_GEN) $@

build/gate_driver.o: $(GATE_DRIVER_C) | build
	$(CC) $(CFLAGS) -c $< -o $@

$(SYSTEM_INIT_C): $(SYSTEM_INIT_GEN)
	$(HEXA_RUN) $(SYSTEM_INIT_GEN) $@

build/system_init.o: $(SYSTEM_INIT_C) | build
	$(CC) $(CFLAGS) -c $< -o $@

$(FAULT_HANDLER_C): $(FAULT_HANDLER_GEN)
	$(HEXA_RUN) $(FAULT_HANDLER_GEN) $@

build/fault_handler.o: $(FAULT_HANDLER_C) | build
	$(CC) $(CFLAGS) -c $< -o $@

$(MAIN_C): $(MAIN_GEN)
	$(HEXA_RUN) $(MAIN_GEN) $@

build/main.o: $(MAIN_C) | build
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
	rm -f $(GATE_DRIVER_C)
	rm -f $(SYSTEM_INIT_C)
	rm -f $(FAULT_HANDLER_C)
	rm -f $(MAIN_C)

check:
	@command -v $(CC) >/dev/null 2>&1 || { echo "MISSING: $(CC)  (brew install --cask gcc-arm-embedded)"; exit 1; }
	@$(CC) --version | head -1
	@echo "OK: ARM toolchain ready"
