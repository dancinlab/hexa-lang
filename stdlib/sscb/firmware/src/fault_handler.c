/* fault_handler.c — verbatim from module/engineering_pack/README.md §5.2.
 *
 * Hard-trip path: COMP1 → TIM1 BRK_IN does the gate cutoff in hardware
 * (no MCU involvement). The TIM1_BRK_TIM9_IRQHandler runs after the cut
 * for logging only; latency here does not affect t_off.
 *
 * Soft-trip path: SPI1+DMA2_Stream2 streams Σ-Δ samples; on N consecutive
 * over-threshold samples we force TIM1->EGR.BG, which fires the same
 * BRK event the hardware comparator does, killing the PWM in one cycle.
 */
#include "stm32f4xx_min.h"
#include "sscb.h"

void TIM1_BRK_TIM9_IRQHandler(void) {
    if (TIM1->SR & TIM_SR_BIF) {
        /* PWM is already OFF via hardware BRK; this handler does logging
         * and state transition only — does NOT race against the cut. */
        TIM1->SR = ~TIM_SR_BIF;
        sscb_state.flags |= FLT_HW_TRIPPED;
        sscb_state.trip_timestamp = DWT->CYCCNT;
        sscb_state.trip_cause = TRIP_HW_COMPARATOR;
        gpio_set_fault_low();
        fault_log_write(sscb_state.trip_timestamp, TRIP_HW_COMPARATOR);
    }
}

void DMA2_Stream2_IRQHandler(void) {
    if (DMA2->LISR & DMA_LISR_HTIF2) {
        DMA2->LIFCR = DMA_LIFCR_CHTIF2;
        process_adc_block(&adc_buf[0], ADC_BLOCK_SIZE / 2);
    } else if (DMA2->LISR & DMA_LISR_TCIF2) {
        DMA2->LIFCR = DMA_LIFCR_CTCIF2;
        process_adc_block(&adc_buf[ADC_BLOCK_SIZE / 2], ADC_BLOCK_SIZE / 2);
    }
}

void process_adc_block(int16_t *p, uint16_t n) {
    uint8_t oc = 0;
    for (uint16_t i = 0; i < n; i++) {
        if (p[i] > TRIP_THRESH_COUNTS) {
            if (++oc >= OVERCURRENT_SAMPLES) {
                sscb_trip_soft(TRIP_SW_OVERCURRENT);
                return;
            }
        } else {
            oc = 0;
        }
    }
    sscb_state.irms_recent = irms_estimate(p, n);
}

void sscb_trip_soft(uint8_t cause) {
    /* Force a break event — same path as hardware COMP1 → TIM1 BRK */
    TIM1->EGR |= TIM_EGR_BG;
    sscb_state.flags |= FLT_SW_TRIPPED;
    sscb_state.trip_timestamp = DWT->CYCCNT;
    sscb_state.trip_cause = cause;
    gpio_set_fault_low();
    fault_log_write(sscb_state.trip_timestamp, cause);
}
