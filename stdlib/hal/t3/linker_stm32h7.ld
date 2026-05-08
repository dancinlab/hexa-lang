/* stdlib/hal/t3/linker_stm32h7.ld — STM32H7 minimal linker script for T3 harness.
 *
 * Phase: scaffold + compile-tier (live). Lays groundwork for T3b2.
 *
 * Target memory layout (per RM0433 §2.4 Memory map):
 *   ITCMRAM    @ 0x00000000   64 KB    (instruction TCM, single-cycle)
 *   FLASH      @ 0x08000000   2048 KB  (main FLASH; 8 banks × 256 KB)
 *   DTCMRAM    @ 0x20000000   128 KB   (data TCM, single-cycle)
 *   SRAM_AXI   @ 0x24000000   512 KB   (D1 domain main RAM)
 *   SRAM1..4   @ 0x30000000   288 KB   (D2 domain SRAM1+2+3 = 288K)
 *   SRAM_D3    @ 0x38000000   64 KB    (D3 / VBAT backup domain)
 *
 * The harness boots from FLASH (0x08000000); vector table at start of
 * FLASH (must be 512-byte aligned per ARMv7-M VTOR rules).
 *
 * Stack lives in DTCMRAM (single-cycle access, no caching latency).
 */

MEMORY {
    FLASH    (rx)   : ORIGIN = 0x08000000, LENGTH = 2048K
    ITCMRAM  (rwx)  : ORIGIN = 0x00000000, LENGTH = 64K
    DTCMRAM  (rwx)  : ORIGIN = 0x20000000, LENGTH = 128K
    SRAM_AXI (rwx)  : ORIGIN = 0x24000000, LENGTH = 512K
    SRAM_D2  (rwx)  : ORIGIN = 0x30000000, LENGTH = 288K
    SRAM_D3  (rwx)  : ORIGIN = 0x38000000, LENGTH = 64K
}

ENTRY(_reset_handler)

SECTIONS {
    .text : {
        KEEP(*(.vector_table))
        *(.text*)
        *(.rodata*)
        . = ALIGN(4);
        _etext = .;
    } > FLASH

    .data : AT(_etext) {
        _sdata = .;
        *(.data*)
        . = ALIGN(4);
        _edata = .;
    } > DTCMRAM

    .bss : {
        _sbss = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > DTCMRAM

    /* Stack at top of DTCMRAM (grows down; single-cycle access). */
    _stack_top = ORIGIN(DTCMRAM) + LENGTH(DTCMRAM);

    /DISCARD/ : { *(.ARM.exidx*) *(.ARM.attributes*) }
}

/* End of linker script — paper-tier; ARMv7-M-specific minimal layout. */
