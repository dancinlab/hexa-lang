/* gate_driver.c — TIM1 PWM 30 MHz + dead-time + COMP1→BRK_IN.
 * Source: module/engineering_pack/README.md §5.1 gate_driver_init.
 */
#include "stm32f4xx_min.h"
#include "sscb.h"

void gate_driver_init(void) {
    /* TIM1 advanced timer config:
     *   APB2 → TIM1 input clock = 180 MHz (TIM1 special, not /2)
     *   PSC = 0, ARR = 5  → 30 MHz PWM (180 MHz / 6 = 30 MHz)
     *   CCR1 = duty (50 % nominal, 0 on trip)
     *   BDTR.DTG = dead-time generator value (e.g. 80 ns @ 180 MHz = 14)
     *   BDTR.BKE = 1, BKP = 0 (active-low BRK_IN from COMP1)
     *   BDTR.MOE = 1 to enable main output, automatically cleared on BRK
     *
     * On any BRK trigger (hardware COMP1 or software TIM1->EGR.BG):
     *   - MOE clears in 1 timer tick (~5.5 ns @ 180 MHz)
     *   - PWM outputs go to OSSI/OSSR-defined safe state
     *   - TIM1->SR.BIF latches → TIM1_BRK_TIM9_IRQHandler does logging
     *
     * Stub here — production fills in the register writes. The §5.2 verbatim
     * fault_handler.c above relies on TIM1->EGR.BG being a valid break-event
     * trigger, which BDTR.BKE=1 guarantees.
     */
}
