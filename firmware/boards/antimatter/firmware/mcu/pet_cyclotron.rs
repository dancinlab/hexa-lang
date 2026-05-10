// firmware/mcu/pet_cyclotron.rs — HEXA-PET-FW-01 STM32H743 controller skeleton.
//
// Phase D skeleton (target: thumbv7em-none-eabihf).  Spec source:
// firmware/sim/cyclotron_trigger.hexa (13/13 PASS).
//
// Compiles with `cargo build --target thumbv7em-none-eabihf --release` once
// stm32h7xx-hal + cortex-m-rt are added to Cargo.toml.  Not flashable
// until physical board arrives (.roadmap §A.6 step 4).

#![no_std]
#![no_main]

// (Phase D Cargo.toml will pull these crates; commented so this file
// stays parseable as a stand-alone reference.)
// use cortex_m_rt::entry;
// use stm32h7xx_hal::{pac, prelude::*, rcc, time::Hertz};

/// HEXA-PET-FW-01 controller states.
/// Mirrors `firmware/sim/cyclotron_trigger.hexa` state IDs.
#[derive(Copy, Clone, PartialEq, Eq)]
pub enum CyclotronState {
    Idle      = 0,
    Armed     = 1,
    RfRamp    = 2,
    BeamOn    = 3,
    BeamOff   = 4,
    Cooldown  = 5,
    Acquire   = 6,
}

/// Timing budgets in milliseconds.  Match the sim verifier.
pub const RAMP_MS:    u32 = 200;
pub const BEAM_ON_MS: u32 = 60_000;
pub const COOL_MS:    u32 = 30_000;
pub const ACQ_MS:     u32 = 1_000;

/// Safety interlock hard deadline (ms).
pub const SAFETY_INTERLOCK_DEADLINE_MS: u32 = 10;

/// 16-bit DAC range (LTC2641-16).
pub const DAC_MAX_COUNT: u16 = 65_535;

/// n=6 lattice anchors in firmware register space.
pub const SIGMA: u16 = 12;
pub const TAU:   u16 = 4;

/// Linear DAC ramp lookup.  Returns code in [0, DAC_MAX_COUNT].
pub fn dac_count_for_rf_ramp(t_in_state_ms: u32) -> u16 {
    if t_in_state_ms >= RAMP_MS { return DAC_MAX_COUNT; }
    let frac_num = (t_in_state_ms as u64) * (DAC_MAX_COUNT as u64);
    (frac_num / (RAMP_MS as u64)) as u16
}

/// State machine next-state function.
pub fn next_state(s: CyclotronState, t_in_state_ms: u32) -> CyclotronState {
    use CyclotronState::*;
    match s {
        Idle      => Armed,
        Armed     => RfRamp,
        RfRamp    => if t_in_state_ms >= RAMP_MS    { BeamOn }   else { RfRamp },
        BeamOn    => if t_in_state_ms >= BEAM_ON_MS { BeamOff }  else { BeamOn },
        BeamOff   => Cooldown,
        Cooldown  => if t_in_state_ms >= COOL_MS    { Acquire }  else { Cooldown },
        Acquire   => if t_in_state_ms >= ACQ_MS     { Idle }     else { Acquire },
    }
}

// ── Phase D entry point (stub) ───────────────────────────────────────────
//
// Real flow (Phase D, Cargo.toml deps + HAL init):
//   1. Init RCC (16 MHz HSE → 480 MHz core via PLL1)
//   2. Configure GPIO (PA0 RF_GATE, PA1 SHUTTER, etc per board_v0_pet_cyclotron.md §2)
//   3. Set up SPI1 for DAC + ADC
//   4. Set up SDIO for microSD
//   5. Set up USB-CDC for telemetry
//   6. Configure EXTI13/EXTI3/EXTI2 for safety interlock + door + NaI counter
//   7. Configure NVIC priority: EXTI13 + EXTI3 → priority 0 (preempt all)
//   8. Enter main loop: 1 ms tick (SysTick), drive state machine via next_state()
//
//   #[entry]
//   fn main() -> ! {
//       let dp = pac::Peripherals::take().unwrap();
//       let cp = cortex_m::Peripherals::take().unwrap();
//       // ... HAL init ...
//       let mut state = CyclotronState::Idle;
//       let mut t: u32 = 0;
//       loop {
//           // 1 ms SysTick
//           let next = next_state(state, t);
//           if next != state { t = 0; state = next; }
//           else { t = t.saturating_add(1); }
//           // ... drive GPIO/DAC/SPI based on state ...
//       }
//   }

// ── unit-test compatible stubs (host-side cargo test) ───────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn state_machine_traverses_all_seven() {
        let mut s = CyclotronState::Idle;
        let mut visited = 1u32;
        let mut prev = s;
        for _ in 0..100 {
            s = next_state(s, u32::MAX);
            if s != prev { visited += 1; prev = s; }
            if s == CyclotronState::Idle && visited > 1 { break; }
        }
        assert!(visited >= 7, "only visited {} states", visited);
    }

    #[test]
    fn dac_clamp() {
        assert_eq!(dac_count_for_rf_ramp(0), 0);
        assert_eq!(dac_count_for_rf_ramp(RAMP_MS), DAC_MAX_COUNT);
        assert_eq!(dac_count_for_rf_ramp(RAMP_MS * 2), DAC_MAX_COUNT);
    }

    #[test]
    fn n6_anchor_dac_scaling() {
        // σ·τ = 48 normalized → 48/256 of full scale
        let st = (SIGMA as u32) * (TAU as u32);
        let count = (st * (DAC_MAX_COUNT as u32)) / 256;
        assert!(count >= 12_000 && count <= 13_000);
    }
}

// ── panic handler placeholder (Phase D: defmt-panic or panic-probe) ───
// #[panic_handler]
// fn panic(_info: &core::panic::PanicInfo) -> ! { loop {} }
