/* adc_dma.c — SPI1 + DMA2_Stream2 setup (Σ-Δ 16-bit @ 1 MSPS).
 * Source: module/engineering_pack/README.md §5.1 adc_spi_dma_init.
 */
#include "stm32f4xx_min.h"
#include "sscb.h"

void adc_spi_dma_init(void) {
    /* Production firmware:
     *   1. enable RCC AHB1ENR.DMA2EN, APB2ENR.SPI1EN
     *   2. configure SPI1 as 16-bit master, 30 MHz SCK
     *   3. configure DMA2_Stream2: peripheral SPI1->DR, memory adc_buf,
     *      circular ping-pong size = ADC_BLOCK_SIZE, DIR = peripheral→memory
     *   4. enable DMA half-transfer + transfer-complete interrupts
     *
     * Pin map (engineering_pack §3 PCB):
     *   SPI1_SCK  PA5  AF5
     *   SPI1_MISO PA6  AF5  ← Σ-Δ ADC modulator output
     *   SPI1_MOSI PA7  AF5  (unused; Σ-Δ is RX-only here)
     *
     * Stub — full register sequence belongs in §5.x once written; this file
     * exists to materialize the §5.1 init function so main.c links cleanly.
     */
}
