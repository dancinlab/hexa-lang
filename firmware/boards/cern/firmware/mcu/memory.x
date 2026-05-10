/* hexa-cern/firmware/mcu/memory.x — STM32H743ZIT6 linker script
 *
 * §A.6.1 step E3.1 — memory map for the LWFA benchtop laser-driver MCU.
 * Targets STM32H743ZIT6 (Cortex-M7 @ 480 MHz, 2 MB flash, 1 MB SRAM
 * across 5 banks) per §benchtop_v0_design.md §3 F2 BOM.
 *
 * Memory layout (STM32H743 datasheet RM0433 §2.3):
 *   FLASH        0x0800_0000 .. 0x081F_FFFF  (2 MB, dual-bank 1 MB each)
 *   DTCM RAM     0x2000_0000 .. 0x2001_FFFF  (128 KB, M7 tightly-coupled)
 *   AXI SRAM     0x2400_0000 .. 0x2407_FFFF  (512 KB, AHB-master visible)
 *   SRAM1        0x3000_0000 .. 0x3001_FFFF  (128 KB, D2 domain)
 *   SRAM2        0x3002_0000 .. 0x3003_FFFF  (128 KB, D2 domain)
 *   SRAM3        0x3004_0000 .. 0x3004_7FFF  ( 32 KB, D2 domain)
 *   SRAM4        0x3800_0000 .. 0x3800_FFFF  ( 64 KB, D3 domain)
 *   BACKUP SRAM  0x3880_0000 .. 0x3880_0FFF  (  4 KB, VBAT domain)
 *
 * Skeleton-tag: this memory.x is synthesized from public datasheet
 * specs and matches the most-widely-stocked STM32H7 SKU. If §A.6 step 1
 * (host facility) selects a different MCU, this file gets replaced with
 * the vendor's own.
 */

MEMORY
{
    FLASH      : ORIGIN = 0x08000000, LENGTH = 2048K
    DTCM       : ORIGIN = 0x20000000, LENGTH =  128K
    RAM        : ORIGIN = 0x24000000, LENGTH =  512K
    SRAM1      : ORIGIN = 0x30000000, LENGTH =  128K
    SRAM2      : ORIGIN = 0x30020000, LENGTH =  128K
    SRAM3      : ORIGIN = 0x30040000, LENGTH =   32K
    SRAM4      : ORIGIN = 0x38000000, LENGTH =   64K
    BSRAM      : ORIGIN = 0x38800000, LENGTH =    4K
}

/* Default to AXI SRAM (RAM) for general-purpose data; .bss / .data /
 * heap / stack live here. Critical realtime code can be moved to
 * DTCM by tagging functions with #[link_section = ".dtcm"]. */

/* Stack lives at top of AXI SRAM, growing down */
_stack_start = ORIGIN(RAM) + LENGTH(RAM);

/* DMA buffers must be in non-DTCM region (DMA can't cross DTCM/M7 boundary)
 * — provide a region-allocator alias so user code can place them in SRAM1. */
REGION_ALIAS("DMA_RAM", SRAM1);

/* Backup SRAM survives standby and software reset — useful for
 * persisting interlock-trip telemetry and fault logs across reboots. */
REGION_ALIAS("BACKUP", BSRAM);
