/* startup_stm32f429.s — minimal CMSIS-style startup for STM32F429ZIT6.
 *
 * Vector table (Cortex-M4 + STM32F4 IRQs the scaffold actually uses).
 * On reset: copy .data initializers from FLASH to RAM, zero .bss, jump
 * to main(). All other vectors point to a default infinite-loop handler;
 * production firmware overrides them with named C handlers via the
 * linker's "weak" alias pattern.
 */
    .syntax unified
    .cpu cortex-m4
    .fpu fpv4-sp-d16
    .thumb

    .global g_pfnVectors
    .global Default_Handler
    .global Reset_Handler

    .extern _sidata
    .extern _sdata
    .extern _edata
    .extern _sbss
    .extern _ebss
    .extern _estack
    .extern main
    .extern TIM1_BRK_TIM9_IRQHandler
    .extern DMA2_Stream2_IRQHandler

/* ---- Vector table ---------------------------------------------------- */
    .section .isr_vector,"a",%progbits
    .type g_pfnVectors, %object
    .size g_pfnVectors, . - g_pfnVectors
g_pfnVectors:
    .word _estack
    .word Reset_Handler
    .word Default_Handler          /* NMI */
    .word Default_Handler          /* HardFault */
    .word Default_Handler          /* MemManage */
    .word Default_Handler          /* BusFault */
    .word Default_Handler          /* UsageFault */
    .word 0,0,0,0                  /* Reserved */
    .word Default_Handler          /* SVC */
    .word Default_Handler          /* DebugMon */
    .word 0
    .word Default_Handler          /* PendSV */
    .word Default_Handler          /* SysTick */
    /* External IRQs 0..N — only the two we care about are named, rest default */
    .rept 24
        .word Default_Handler
    .endr
    .word TIM1_BRK_TIM9_IRQHandler /* IRQ 24 */
    .rept (58 - 24 - 1)
        .word Default_Handler
    .endr
    .word DMA2_Stream2_IRQHandler  /* IRQ 58 */
    /* trailing IRQs unused — Default_Handler covers them */
    .rept 32
        .word Default_Handler
    .endr

/* ---- Reset_Handler --------------------------------------------------- */
    .section .text.Reset_Handler
    .weak Reset_Handler
    .type Reset_Handler, %function
Reset_Handler:
    ldr r0, =_estack
    mov sp, r0

    /* Copy .data from flash to RAM */
    ldr r0, =_sdata
    ldr r1, =_edata
    ldr r2, =_sidata
    movs r3, #0
.copy_data:
    cmp r0, r1
    bge .zero_bss
    ldr r4, [r2, r3]
    str r4, [r0, r3]
    adds r3, r3, #4
    adds r0, r0, #4
    b   .copy_data

.zero_bss:
    ldr r0, =_sbss
    ldr r1, =_ebss
    movs r2, #0
.bss_loop:
    cmp r0, r1
    bge .start_main
    str r2, [r0]
    adds r0, r0, #4
    b   .bss_loop

.start_main:
    bl main
.hang:
    b .hang

/* ---- Default_Handler ------------------------------------------------- */
    .section .text.Default_Handler,"ax",%progbits
    .weak Default_Handler
    .type Default_Handler, %function
Default_Handler:
    b Default_Handler
