/* stdlib/hal/t3/boot_stm32h7.s — STM32H7 ARMv7-M minimal boot for T3 harness.
 *
 * Phase: scaffold + compile-tier (live). T3b2 deferred.
 *
 * Provides: vector table at start of FLASH (0x08000000) + reset handler
 * that sets up SP, copies .data from FLASH to DTCMRAM, zeros .bss,
 * enables FPU (CP10/CP11 in CPACR), then jumps to harness_main().
 *
 * Target: ARMv7-M (Cortex-M7) — supports Thumb-2; FPv5-D16 double-
 * precision FPU enabled before harness_main runs (so C code can use
 * float/double).
 */

    .syntax unified
    .thumb
    .cpu cortex-m7
    .fpu fpv5-d16

    .section .vector_table, "a", %progbits
    .global _vector_table
_vector_table:
    .word _stack_top              /* 0x00: initial SP */
    .word _reset_handler + 1      /* 0x04: reset (Thumb mode bit set) */
    .word _hard_fault + 1         /* 0x08: NMI */
    .word _hard_fault + 1         /* 0x0C: HardFault */
    .word _hard_fault + 1         /* 0x10: MemManage */
    .word _hard_fault + 1         /* 0x14: BusFault */
    .word _hard_fault + 1         /* 0x18: UsageFault */
    .word 0                       /* 0x1C: reserved */
    .word 0                       /* 0x20: reserved */
    .word 0                       /* 0x24: reserved */
    .word 0                       /* 0x28: reserved */
    .word _hard_fault + 1         /* 0x2C: SVCall */
    .word _hard_fault + 1         /* 0x30: DebugMonitor */
    .word 0                       /* 0x34: reserved */
    .word _hard_fault + 1         /* 0x38: PendSV */
    .word _hard_fault + 1         /* 0x3C: SysTick */
    /* IRQ 0..N — pad to fill out vector page; STM32H7 has ~150 IRQs */
    .rept 240
    .word 0
    .endr

    .text
    .global _reset_handler
    .thumb_func
_reset_handler:
    /* 1. Set up stack pointer (already loaded at reset, defensive). */
    ldr  r0, =_stack_top
    msr  msp, r0

    /* 2. Enable FPU (CP10 + CP11 full access in CPACR). */
    ldr  r0, =0xE000ED88          /* SCB_CPACR */
    ldr  r1, [r0]
    orr  r1, r1, #(0xF << 20)     /* CP10 + CP11 = 0b1111 << 20 (full access) */
    str  r1, [r0]
    dsb
    isb

    /* 3. Copy .data from FLASH to DTCMRAM. */
    ldr  r0, =_sdata              /* dest in DTCMRAM */
    ldr  r1, =_edata
    ldr  r2, =_etext              /* src in FLASH */
1:  cmp  r0, r1
    bcs  2f
    ldr  r3, [r2]
    str  r3, [r0]
    adds r0, #4
    adds r2, #4
    b    1b

2:  /* 4. Zero .bss. */
    ldr  r0, =_sbss
    ldr  r1, =_ebss
    movs r2, #0
3:  cmp  r0, r1
    bcs  4f
    str  r2, [r0]
    adds r0, #4
    b    3b

4:  /* 5. Call harness_main(). */
    bl   harness_main

    /* 6. Spin if it returns. */
_hang:
    b    _hang

    .global _hard_fault
    .thumb_func
_hard_fault:
    b    _hard_fault

/* End of boot_stm32h7.s — minimal ARMv7-M reset path with FPU enable. */
