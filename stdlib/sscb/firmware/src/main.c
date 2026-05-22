/* main.c — SSCB mk1 firmware entry.
 * Source: module/engineering_pack/README.md §5.1.
 */
#include "stm32f4xx_min.h"
#include "sscb.h"

struct sscb_state sscb_state;
int16_t adc_buf[ADC_BLOCK_SIZE];

int main(void) {
    system_init();
    dwt_cycle_counter_enable();

    adc_spi_dma_init();
    comparator_init();
    gate_driver_init();
    host_iface_init();

    sscb_state.state_id = SSCB_STATE_IDLE;
    main_loop();

    /* not reached */
    return 0;
}

void main_loop(void) {
    for (;;) {
        /* §5.1 — ADC consumed in DMA2_Stream2_IRQHandler; here we run the
         * state machine + telemetry + WDT refresh in a flat foreground. */
        fault_sm_step();
        telemetry_send();
        wdt_refresh();
    }
}

/* §5.5 state machine — minimal mk1 implementation.
 * Mk.II adds RECLOSE_WAIT timer; mk1 leaves reset to host. */
void fault_sm_step(void) {
    switch (sscb_state.state_id) {
    case SSCB_STATE_IDLE:
        /* self-test passes externally; placeholder transition */
        sscb_state.state_id = SSCB_STATE_ARMED;
        break;
    case SSCB_STATE_ARMED:
        if (sscb_state.flags & (FLT_HW_TRIPPED | FLT_SW_TRIPPED)) {
            sscb_state.state_id = SSCB_STATE_TRIPPED;
            sscb_state.cycle_count++;
        }
        break;
    case SSCB_STATE_TRIPPED:
        /* host clears flags; mk1 returns to IDLE for re-arm. */
        if ((sscb_state.flags & (FLT_HW_TRIPPED | FLT_SW_TRIPPED)) == 0) {
            sscb_state.state_id = SSCB_STATE_IDLE;
        }
        break;
    case SSCB_STATE_RECLOSE_WAIT:
        /* mk1: never entered; Mk.II adds AUTORECLOSE_DELAY_MS timer here. */
        sscb_state.state_id = SSCB_STATE_IDLE;
        break;
    }
}

void telemetry_send(void) {
    /* UART3 ring-buffer drain; placeholder — full ring impl in §5.1 host_iface. */
}

void wdt_refresh(void) {
    /* IWDG reload — KR=0xAAAA. Stub here; production firmware writes to IWDG->KR. */
}

int32_t irms_estimate(const int16_t *p, uint16_t n) {
    /* Crude RMS: sum of squares / n, cast to int32. Production replaces with
     * fixed-point sqrt + EWMA. The §5.2 spec only requires "rolling RMS". */
    uint64_t sumsq = 0;
    for (uint16_t i = 0; i < n; i++) {
        int32_t s = p[i];
        sumsq += (uint64_t)(s * s);
    }
    return (int32_t)(sumsq / (n ? n : 1));
}

void fault_log_write(uint32_t timestamp, uint8_t cause) {
    /* Ring-buffered UART log; placeholder. */
    (void)timestamp;
    (void)cause;
}

void gpio_set_fault_low(void) {
    /* Drive /FAULT pin low. Pin assignment lives in engineering_pack §3 PCB.
     * Stub here — production sets GPIOx->BSRR with the pin's reset bit. */
}
