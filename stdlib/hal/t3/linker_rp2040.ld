/* stdlib/hal/t3/linker_rp2040.ld — RP2040 minimal linker script for T3 harness.
 *
 * Phase: paper-tier scaffold. Not executed; lays groundwork for v1.3.0+.
 *
 * Target memory layout (per RP2040 Datasheet §2.6):
 *   ROM        @ 0x00000000   16 KB   (boot ROM; not used by harness)
 *   XIP_BASE   @ 0x10000000   2 MB    (external QSPI flash, runtime XIP)
 *   SRAM       @ 0x20000000   264 KB  (6 striped banks)
 *   SRAM4      @ 0x20040000   4 KB    (scratch X)
 *   SRAM5      @ 0x20041000   4 KB    (scratch Y)
 *
 * The harness boots from XIP flash (0x10000000); vector table is in
 * ROM at start of FLASH (must be 256-byte aligned per ARMv6-M VTOR).
 */

MEMORY {
    FLASH (rx)   : ORIGIN = 0x10000000, LENGTH = 2048K
    RAM   (rwx)  : ORIGIN = 0x20000000, LENGTH = 256K
    SRAM4 (rwx)  : ORIGIN = 0x20040000, LENGTH = 4K
    SRAM5 (rwx)  : ORIGIN = 0x20041000, LENGTH = 4K
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
    } > RAM

    .bss : {
        _sbss = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > RAM

    /* Stack starts at top of main SRAM, grows down. */
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);

    /DISCARD/ : { *(.ARM.exidx*) *(.ARM.attributes*) }
}

/* End of linker script — paper-tier; ARMv6-M-specific minimal layout. */
