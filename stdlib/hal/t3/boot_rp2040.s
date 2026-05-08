/* stdlib/hal/t3/boot_rp2040.s — RP2040 ARMv6-M minimal boot for T3 harness.
 *
 * Phase: paper-tier scaffold. Not executed.
 *
 * Provides: vector table at start of FLASH (0x10000100 typical for
 * Pico — second-stage boot loader sits at 0x10000000..0x100000FF;
 * harness code starts at 0x10000100 after VTOR offset).
 *
 * For T3 testing under Renode, the boot stage is simplified: reset
 * handler loads SP, copies .data from FLASH to RAM, zeros .bss,
 * then jumps to harness_main(). No interrupts wired (harness is
 * polling-only).
 *
 * Target: ARMv6-M (Cortex-M0+) — no nested IT, no THUMB-2, must
 * use .syntax unified and .thumb consistently.
 */

    .syntax unified
    .thumb
    .cpu cortex-m0plus

    .section .vector_table, "a", %progbits
    .global _vector_table
_vector_table:
    .word _stack_top              /* 0x00: initial SP */
    .word _reset_handler + 1      /* 0x04: reset (Thumb mode bit set) */
    .word _hard_fault + 1         /* 0x08: NMI */
    .word _hard_fault + 1         /* 0x0C: HardFault */
    /* ARMv6-M only has 16 system entries + IRQs; padding to 0x100 */
    .rept 28
    .word 0
    .endr

    .text
    .global _reset_handler
    .thumb_func
_reset_handler:
    /* 1. set up stack pointer (already loaded at reset, defensive) */
    ldr  r0, =_stack_top
    msr  msp, r0

    /* 2. copy .data from FLASH to RAM */
    ldr  r0, =_sdata          /* dest in RAM */
    ldr  r1, =_edata
    ldr  r2, =_etext          /* src in FLASH */
1:  cmp  r0, r1
    bcs  2f
    ldr  r3, [r2]
    str  r3, [r0]
    adds r0, #4
    adds r2, #4
    b    1b

2:  /* 3. zero .bss */
    ldr  r0, =_sbss
    ldr  r1, =_ebss
    movs r2, #0
3:  cmp  r0, r1
    bcs  4f
    str  r2, [r0]
    adds r0, #4
    b    3b

4:  /* 4. call harness_main() */
    bl   harness_main

    /* 5. spin if it returns */
_hang:
    b    _hang

    .global _hard_fault
    .thumb_func
_hard_fault:
    /* HardFault → spin; Renode log will see no further UART output */
    b    _hard_fault

/* End of boot_rp2040.s — minimal ARMv6-M reset path. */
