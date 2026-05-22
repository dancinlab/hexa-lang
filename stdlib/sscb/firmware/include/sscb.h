/* sscb.h — SSCB mk1 firmware state + macros.
 * Source-of-truth: module/engineering_pack/README.md §5.2.
 * If a macro/struct member changes upstream, mirror here and rebuild.
 */
#ifndef SSCB_H
#define SSCB_H

#include <stdint.h>

/* §5.2 trip thresholds */
#define TRIP_THRESH_COUNTS    16384  /* 250 A → 125 mV → 16384 ADC counts */
#define OVERCURRENT_SAMPLES   3      /* 3 consecutive over-threshold samples */
#define AUTORECLOSE_DELAY_MS  500    /* mk1: manual reclose only (Mk.II adds auto) */

/* §5.2 trip-cause enum */
#define TRIP_HW_COMPARATOR    1
#define TRIP_SW_OVERCURRENT   2
#define TRIP_SW_THERMAL       3
#define TRIP_SW_HOST_REQUEST  4

/* §5.2 fault flags (bitfield) */
#define FLT_HW_TRIPPED        (1u << 0)
#define FLT_SW_TRIPPED        (1u << 1)
#define FLT_THERMAL_WARN      (1u << 2)
#define FLT_SELF_TEST_FAIL    (1u << 3)

/* §5.5 state machine — IDLE / ARMED / TRIPPED / RECLOSE_WAIT */
enum sscb_state_id {
    SSCB_STATE_IDLE         = 0,
    SSCB_STATE_ARMED        = 1,
    SSCB_STATE_TRIPPED      = 2,
    SSCB_STATE_RECLOSE_WAIT = 3,
};

/* §5.2 sscb_state struct — single global instance, NO heap. */
struct sscb_state {
    uint32_t flags;
    uint32_t trip_timestamp;       /* DWT->CYCCNT @ 180 MHz */
    uint8_t  trip_cause;
    uint8_t  state_id;             /* enum sscb_state_id */
    int32_t  irms_recent;          /* rolling RMS estimate, A·1e-3 */
    uint32_t cycle_count;          /* trip lifetime counter */
};

extern struct sscb_state sscb_state;

/* §5.1 ADC block */
#define ADC_BLOCK_SIZE   256       /* samples (ping-pong half = 128) */
extern int16_t adc_buf[ADC_BLOCK_SIZE];

/* §5.2 firmware entry points */
void sscb_trip_soft(uint8_t cause);
void process_adc_block(int16_t *p, uint16_t n);
int32_t irms_estimate(const int16_t *p, uint16_t n);
void fault_log_write(uint32_t timestamp, uint8_t cause);
void gpio_set_fault_low(void);

/* §5.1 init order (called from main()) */
void system_init(void);
void adc_spi_dma_init(void);
void comparator_init(void);
void gate_driver_init(void);
void host_iface_init(void);
void main_loop(void);

/* main_loop substeps (§5.1) */
void fault_sm_step(void);
void telemetry_send(void);
void wdt_refresh(void);

#endif /* SSCB_H */
