/* firmware/mcu/memory.x — STM32F407VGT6 memory map
 *
 * §A.6.1 Phase D+ deliverable.  Linker script for cortex-m-rt.
 * Used by `cargo build --target thumbv7em-none-eabihf` only.
 *
 * STM32F407VGT6 (Cortex-M4F @ 168 MHz, FPU):
 *   FLASH: 1 MiB at 0x08000000  (sectors 0–11, write-cycle ~10k)
 *   SRAM:  192 KiB total
 *     - 112 KiB main SRAM at 0x20000000 (CCM not mapped here)
 *     -  64 KiB CCM SRAM at 0x10000000 (D-bus only — no DMA)
 *     -  16 KiB backup SRAM at 0x40024000 (battery-backed)
 */

MEMORY
{
    FLASH (rx)      : ORIGIN = 0x08000000, LENGTH = 1024K
    RAM (rwx)       : ORIGIN = 0x20000000, LENGTH = 112K
    CCMRAM (rwx)    : ORIGIN = 0x10000000, LENGTH = 64K
}

/* CCM is fast (no contention with DMA) — put critical PID state here */
SECTIONS
{
    .ccmram (NOLOAD) :
    {
        *(.ccmram .ccmram.*);
    } > CCMRAM
}
