/* system_init.c — clock tree from engineering_pack §5.3.
 * HSE 8 MHz × PLL → SYSCLK 180 MHz, AHB 180, APB1 45, APB2 90.
 */
#include "stm32f4xx_min.h"
#include "sscb.h"

void system_init(void) {
    /* Enable HSE oscillator and wait for stable */
    RCC->CR |= RCC_CR_HSEON;
    while (!(RCC->CR & RCC_CR_HSERDY)) { /* spin */ }

    /* Configure PLL: HSE 8 MHz / M=4 = 2 MHz × N=180 = 360 MHz / P=2 = 180 MHz */
    /* PLLCFGR: PLLSRC=HSE, M=4, N=180, P=00b(/2), Q=7 */
    RCC->PLLCFGR = (1u << 22)         /* PLLSRC = HSE */
                 | (4u  << 0)         /* PLLM   = 4   */
                 | (180u << 6)        /* PLLN   = 180 */
                 | (0u   << 16)       /* PLLP   = /2  */
                 | (7u   << 24);      /* PLLQ   = /7  (USB 48 MHz, unused) */

    /* APB1 / APB2 prescalers: APB1 /4 (45 MHz), APB2 /2 (90 MHz), AHB /1 */
    RCC->CFGR = (5u << 10)            /* PPRE1 = 0b101 → /4 */
              | (4u <<  13);          /* PPRE2 = 0b100 → /2 */

    /* Spin up PLL */
    RCC->CR |= RCC_CR_PLLON;
    while (!(RCC->CR & RCC_CR_PLLRDY)) { /* spin */ }

    /* Switch SYSCLK to PLL */
    RCC->CFGR |= RCC_CFGR_SW_PLL;
    while ((RCC->CFGR & RCC_CFGR_SWS) != RCC_CFGR_SWS_PLL) { /* spin */ }

    /* NVIC priorities — engineering_pack §5.4 */
    NVIC_SetPriority(TIM1_BRK_TIM9_IRQn, 0);   /* hard trip post-process */
    NVIC_SetPriority(DMA2_Stream2_IRQn,  1);   /* ADC half-buffer */
    NVIC_SetPriority(SysTick_IRQn,       14);  /* 1 ms tick */

    NVIC_EnableIRQ(TIM1_BRK_TIM9_IRQn);
    NVIC_EnableIRQ(DMA2_Stream2_IRQn);
}

void comparator_init(void) {
    /* COMP1 + TIM1 BRK wiring — RM0090 §13 (COMP) + §17 (TIM1 BDTR.BKE).
     * Stub. Production sets COMP1->CSR.EN, COMP1->CSR.OUT routing to BRK_IN,
     * and TIM1->BDTR.BKE | BKP polarity. */
}

void host_iface_init(void) {
    /* SPI2 host command + UART3 921600-baud telemetry log.
     * Stub — full pin mapping in engineering_pack §3 PCB. */
}
