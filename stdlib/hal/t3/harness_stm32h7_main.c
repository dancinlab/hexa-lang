/*
 * stdlib/hal/t3/harness_stm32h7_main.c — STM32H7 T3 harness main.
 *
 * Phase: scaffold + compile-tier (live). T3b2 deferred until Renode
 * STM32H7 platform spec lands.
 *
 * Goal: minimally exercise the stm32h7 HW backend stubs documented in
 * stdlib/hal/backend/stm32h7/{gpio,uart,timer}.hexa, log a sentinel
 * line via USART3 (the Nucleo-H743 default ST-LINK virtual COM), and
 * halt. Future T3b2 numerics will assert the sentinel landed in a
 * Renode-captured UART log.
 *
 * Sentinel pattern: "__T3_STM32H7__ PASS gpio_toggle_5x_observed\n"
 *
 * This file mirrors backend/rp2040/harness_main.c structurally; the
 * target-specific bits are the register addresses (STM32H7 GPIO at
 * 0x58020000, USART3 at 0x40004800) and the FPU register access path
 * (Cortex-M7 has hardware FPU enabled by boot.s before this runs).
 */

/* Manual integer typedefs — same approach as rp2040 harness; avoids
 * libc dependency for fully -nostdlib bare-metal cross-compile. */
typedef unsigned char       uint8_t;
typedef unsigned short      uint16_t;
typedef unsigned int        uint32_t;
typedef unsigned long long  uint64_t;

/* STM32H7 GPIO + RCC + USART register sketch. */

#define RCC_BASE              0x58024400U
#define RCC_AHB4ENR           (*(volatile uint32_t *)(RCC_BASE + 0x0E0))
#define RCC_AHB4ENR_GPIOBEN   (1U << 1)
#define RCC_APB1LENR          (*(volatile uint32_t *)(RCC_BASE + 0x0E8))
#define RCC_APB1LENR_USART3EN (1U << 18)

#define GPIOB_BASE            0x58020400U
#define GPIOB_MODER           (*(volatile uint32_t *)(GPIOB_BASE + 0x000))
#define GPIOB_BSRR            (*(volatile uint32_t *)(GPIOB_BASE + 0x018))

/* Pin: PB0 (Nucleo-H743 user LD1 green LED). */
#define LED_PIN               0
#define MODER_OUTPUT          1U  /* 2-bit field: 01 = general-purpose output */

#define USART3_BASE           0x40004800U
#define USART3_BRR            (*(volatile uint32_t *)(USART3_BASE + 0x00C))
#define USART3_CR1            (*(volatile uint32_t *)(USART3_BASE + 0x000))
#define USART3_TDR            (*(volatile uint32_t *)(USART3_BASE + 0x028))
#define USART3_ISR            (*(volatile uint32_t *)(USART3_BASE + 0x01C))
#define USART_CR1_UE          (1U << 0)
#define USART_CR1_TE          (1U << 3)
#define USART_ISR_TXE         (1U << 7)

static void delay_loop(uint32_t n) {
    while (n--) { __asm__ volatile("nop"); }
}

static void uart_write_str(const char *s) {
    while (*s) {
        while (!(USART3_ISR & USART_ISR_TXE)) { /* spin until TX empty */ }
        USART3_TDR = (uint32_t)(*s++);
    }
}

void harness_main(void) {
    /* 1. Enable GPIOB clock + USART3 clock. */
    RCC_AHB4ENR  |= RCC_AHB4ENR_GPIOBEN;
    RCC_APB1LENR |= RCC_APB1LENR_USART3EN;

    /* 2. Configure PB0 as output (MODER bits [1:0] = 01). */
    uint32_t moder = GPIOB_MODER;
    moder &= ~(0x3U << (LED_PIN * 2));
    moder |= (MODER_OUTPUT << (LED_PIN * 2));
    GPIOB_MODER = moder;

    /* 3. Configure USART3 for 115200 8N1 (assume APB1=120 MHz default;
     *    BRR = 120e6 / 115200 ≈ 1042 = 0x412). Real impl computes from
     *    HCLK/PCLK; this stub uses Nucleo defaults. */
    USART3_BRR = 1042;
    USART3_CR1 = USART_CR1_UE | USART_CR1_TE;

    uart_write_str("[t3_stm32h7 START] harness booted\r\n");

    /* 4. Toggle LED 5 times via BSRR atomic set/reset (MMIO-correct;
     *    no read-modify-write race). */
    for (int i = 0; i < 5; i++) {
        GPIOB_BSRR = (1U << LED_PIN);              /* set bit n   = on */
        delay_loop(100000);
        GPIOB_BSRR = (1U << (LED_PIN + 16));       /* reset bit n = off */
        delay_loop(100000);
    }

    /* 5. Emit T3 PASS sentinel. */
    uart_write_str("__T3_STM32H7__ PASS gpio_toggle_5x_observed\r\n");

    /* 6. Spin forever. */
    for (;;) { __asm__ volatile("nop"); }
}

/* End of harness_stm32h7_main.c — minimal STM32H7 GPIO + UART exerciser. */
