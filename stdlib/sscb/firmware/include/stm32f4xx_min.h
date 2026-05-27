/* stm32f4xx_min.h — minimal CMSIS-style register stub.
 *
 * NOT a redistribution of ST's Cube SDK headers. Defines only the registers
 * that the SSCB scaffold touches, using STM32F429xx absolute addresses from
 * the public ST RM0090 reference manual (which is documentation, not
 * licensed code). For a production build, replace this header with the
 * vendor stm32f4xx.h via `-I /path/to/CMSIS/Device/ST/STM32F4xx/Include`
 * and `-I /path/to/CMSIS/Core/Include`, then `#define USE_VENDOR_CMSIS`
 * before including this file.
 *
 * Ref: STMicroelectronics RM0090 Rev 19, "STM32F405/415, F407/417,
 * F427/437 and F429/439 advanced Arm-based 32-bit MCUs".
 */
#ifndef STM32F4XX_MIN_H
#define STM32F4XX_MIN_H

#include <stdint.h>

#ifdef USE_VENDOR_CMSIS
#include "stm32f4xx.h"
#else

/* ---- Memory map (RM0090 Table 1) ------------------------------------- */
#define PERIPH_BASE     0x40000000UL
#define APB1_BASE       (PERIPH_BASE + 0x00000000UL)
#define APB2_BASE       (PERIPH_BASE + 0x00010000UL)
#define AHB1_BASE       (PERIPH_BASE + 0x00020000UL)
#define AHB2_BASE       (PERIPH_BASE + 0x10000000UL)
#define AHB3_BASE       (PERIPH_BASE + 0x20000000UL)

/* ---- TIM1 (advanced timer, APB2) — RM0090 §17 ------------------------ */
typedef struct {
    volatile uint32_t CR1, CR2, SMCR, DIER, SR, EGR;
    volatile uint32_t CCMR1, CCMR2, CCER;
    volatile uint32_t CNT, PSC, ARR, RCR;
    volatile uint32_t CCR1, CCR2, CCR3, CCR4;
    volatile uint32_t BDTR, DCR, DMAR;
} TIM_TypeDef;
#define TIM1            ((TIM_TypeDef *)(APB2_BASE + 0x0000))

#define TIM_SR_BIF      (1u << 7)
#define TIM_EGR_BG      (1u << 7)

/* ---- DMA2 (AHB1) — RM0090 §10 ---------------------------------------- */
typedef struct {
    volatile uint32_t LISR, HISR;     /* low / high interrupt status */
    volatile uint32_t LIFCR, HIFCR;   /* low / high interrupt flag clear */
    /* per-stream regs follow but the scaffold only uses stream-2 LISR/LIFCR */
} DMA_TypeDef;
#define DMA2            ((DMA_TypeDef *)(AHB1_BASE + 0x6400))

#define DMA_LISR_HTIF2  (1u << 20)
#define DMA_LISR_TCIF2  (1u << 21)
#define DMA_LIFCR_CHTIF2 (1u << 20)
#define DMA_LIFCR_CTCIF2 (1u << 21)

/* ---- DWT (cycle counter, Cortex-M Core Debug) ------------------------ */
typedef struct {
    volatile uint32_t CTRL;
    volatile uint32_t CYCCNT;
} DWT_Type;
#define DWT             ((DWT_Type *)0xE0001000UL)
#define DWT_CTRL_CYCCNTENA (1u << 0)

/* ---- SCB / DEMCR (debug exception monitor) — for DWT enable --------- */
typedef struct {
    volatile uint32_t DEMCR;
} SCB_DBG_Type;
#define DEMCR           (*(volatile uint32_t *)0xE000EDFCUL)
#define DEMCR_TRCENA    (1u << 24)

/* ---- IRQ vector numbers (subset; RM0090 Table 62) ------------------- */
typedef enum {
    NonMaskableInt_IRQn      = -14,
    HardFault_IRQn           = -13,
    MemoryManagement_IRQn    = -12,
    BusFault_IRQn            = -11,
    UsageFault_IRQn          = -10,
    SVCall_IRQn              = -5,
    DebugMonitor_IRQn        = -4,
    PendSV_IRQn              = -2,
    SysTick_IRQn             = -1,

    DMA2_Stream2_IRQn        = 58,
    TIM1_BRK_TIM9_IRQn       = 24,
    COMP1_IRQn               = 22,   /* placeholder — RM0090 maps via EXTI line */
} IRQn_Type;

/* ---- NVIC (Cortex-M Core) ------------------------------------------- */
typedef struct {
    volatile uint32_t ISER[8];
    uint32_t          _r0[24];
    volatile uint32_t ICER[8];
    uint32_t          _r1[24];
    volatile uint32_t ISPR[8];
    uint32_t          _r2[24];
    volatile uint32_t ICPR[8];
    uint32_t          _r3[24];
    volatile uint32_t IABR[8];
    uint32_t          _r4[56];
    volatile uint8_t  IP[240];
} NVIC_Type;
#define NVIC            ((NVIC_Type *)0xE000E100UL)

static inline void NVIC_EnableIRQ(IRQn_Type irq) {
    if ((int)irq >= 0)
        NVIC->ISER[((uint32_t)irq) >> 5] = (1u << (((uint32_t)irq) & 0x1F));
}
static inline void NVIC_SetPriority(IRQn_Type irq, uint32_t prio) {
    if ((int)irq >= 0)
        NVIC->IP[(uint32_t)irq] = (uint8_t)((prio & 0x0F) << 4);
}

/* ---- RCC (clock control, AHB1) — RM0090 §6 -------------------------- */
typedef struct {
    volatile uint32_t CR;
    volatile uint32_t PLLCFGR;
    volatile uint32_t CFGR;
    volatile uint32_t CIR;
    volatile uint32_t AHB1RSTR, AHB2RSTR, AHB3RSTR; uint32_t _r0;
    volatile uint32_t APB1RSTR, APB2RSTR;          uint32_t _r1[2];
    volatile uint32_t AHB1ENR, AHB2ENR, AHB3ENR;   uint32_t _r2;
    volatile uint32_t APB1ENR, APB2ENR;
} RCC_TypeDef;
#define RCC             ((RCC_TypeDef *)(AHB1_BASE + 0x3800))

#define RCC_CR_HSEON    (1u << 16)
#define RCC_CR_HSERDY   (1u << 17)
#define RCC_CR_PLLON    (1u << 24)
#define RCC_CR_PLLRDY   (1u << 25)
#define RCC_CFGR_SW_PLL (0x2u << 0)
#define RCC_CFGR_SWS    (0x3u << 2)
#define RCC_CFGR_SWS_PLL (0x2u << 2)

#endif /* USE_VENDOR_CMSIS */

/* ---- ISR prototype attribute (used by startup vector table) ---------- */
#define ISR_HANDLER

/* SCB->DEMCR convenience for cycle-counter init */
static inline void dwt_cycle_counter_enable(void) {
    DEMCR |= DEMCR_TRCENA;
    DWT->CTRL |= DWT_CTRL_CYCCNTENA;
    DWT->CYCCNT = 0;
}

#endif /* STM32F4XX_MIN_H */
