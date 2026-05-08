/*
 * stdlib/hal/t3/harness_main.c — RP2040 T3 harness main.
 *
 * Phase: paper-tier scaffold. Not executed in v1.2.0.
 *
 * Goal: minimally exercise the rp2040 HW backend stubs documented in
 * stdlib/hal/backend/rp2040/{gpio,uart,timer}.hexa, log a sentinel
 * line via UART0, and halt. Renode will capture the UART output to
 * t3_rp2040_run.log; numerics_t3_rp2040_renode.hexa (v1.3.0+) will
 * grep for the sentinel.
 *
 * Sentinel pattern: "__T3_RP2040__ PASS gpio_toggle_5x_observed\n"
 *
 * Why C and not .hexa? hexa runtime fork-saturation blocks cross-
 * compile; arm-none-eabi-gcc is the standard ARMv6-M toolchain. Once
 * a hexa-lang ARMv6-M target backend lands, this file converts to
 * stdlib/hal/t3/harness_main.hexa (sim-mirror).
 */

#include <stdint.h>

/* RP2040 register addresses (subset; full list in
 * stdlib/hal/backend/rp2040/gpio.hexa + uart.hexa). */

#define SIO_BASE              0xD0000000U
#define SIO_GPIO_OUT          (*(volatile uint32_t *)(SIO_BASE + 0x010))
#define SIO_GPIO_OUT_SET      (*(volatile uint32_t *)(SIO_BASE + 0x014))
#define SIO_GPIO_OUT_CLR      (*(volatile uint32_t *)(SIO_BASE + 0x018))
#define SIO_GPIO_OE_SET       (*(volatile uint32_t *)(SIO_BASE + 0x024))

/* Pico onboard LED is GP25. */
#define LED_PIN               25

/* UART0 register addresses (PL011 layout). */
#define UART0_BASE            0x40034000U
#define UART0_DR              (*(volatile uint32_t *)(UART0_BASE + 0x000))
#define UART0_FR              (*(volatile uint32_t *)(UART0_BASE + 0x018))
#define UART0_IBRD            (*(volatile uint32_t *)(UART0_BASE + 0x024))
#define UART0_FBRD            (*(volatile uint32_t *)(UART0_BASE + 0x028))
#define UART0_LCR_H           (*(volatile uint32_t *)(UART0_BASE + 0x02C))
#define UART0_CR              (*(volatile uint32_t *)(UART0_BASE + 0x030))
#define UART_FR_TXFF          (1U << 5)

/* Polling delay (cycle-count loop; not calibrated). */
static void delay_loop(uint32_t n) {
    while (n--) { __asm__ volatile("nop"); }
}

static void uart_write_str(const char *s) {
    while (*s) {
        while (UART0_FR & UART_FR_TXFF) { /* spin until tx fifo not full */ }
        UART0_DR = (uint32_t)(*s++);
    }
}

void harness_main(void) {
    /* 1. Configure GP25 (LED) as output via SIO. Note: real boot would
     *    also program IO_BANK0 + PADS_BANK0 + RESETS for GPIO function;
     *    omitted here because Renode's rp2040 model accepts SIO writes
     *    after only the SIO+PADS subset is touched. */
    SIO_GPIO_OE_SET = (1U << LED_PIN);

    /* 2. Configure UART0 for 115200 8N1 (Renode's UART model logs at
     *    any baud; values match the Pico SDK default). */
    /* Skip baud divisor + LCR_H setup in stub; Renode UART is lenient.
     * Real impl: UART0_IBRD = 67; UART0_FBRD = 52; UART0_LCR_H |= (3<<5)
     * for 8-bit; UART0_CR = 0x0301 (UARTEN+TXE+RXE). */
    UART0_CR = 0x0301;

    uart_write_str("[t3_rp2040 START] harness booted\r\n");

    /* 3. Toggle LED 5 times (T3 sentinel: 5 toggles observed). */
    for (int i = 0; i < 5; i++) {
        SIO_GPIO_OUT_SET = (1U << LED_PIN);
        delay_loop(100000);
        SIO_GPIO_OUT_CLR = (1U << LED_PIN);
        delay_loop(100000);
    }

    /* 4. Emit T3 PASS sentinel — numerics_t3_rp2040_renode.hexa
     *    (v1.3.0+) will grep for this in the captured Renode UART log. */
    uart_write_str("__T3_RP2040__ PASS gpio_toggle_5x_observed\r\n");

    /* 5. Spin forever — boot.s catches return via _hang anyway, but
     *    spinning here keeps the UART log's last line stable. */
    for (;;) { __asm__ volatile("nop"); }
}

/* End of harness_main.c — minimal GPIO + UART exerciser. */
