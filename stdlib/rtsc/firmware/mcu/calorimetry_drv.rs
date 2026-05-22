//! hexa-rtsc/firmware/mcu/calorimetry_drv.rs
//!
//! Calorimetry rig MCU driver — STM32F4 + AD5660 DAC + LTC2400 ADC.
//! §A.6.1 Phase D+ deliverable per .roadmap.hexa_rtsc.
//!
//! Spec   : doc/calorimetry_rig_v0.md (Stage A)
//! Sim    : firmware/sim/calorimetry_ctrl.hexa (Stage D+ companion)
//! HDL    : firmware/hdl/calorimetry_daq.v (Phase D+ FPGA)
//! Target : STM32F4 (Cortex-M4F @ 168 MHz)
//!
//! This MCU sits between the host PC and the calorimetry-rig FPGA.
//! Its job: orchestrate heat-pulse experiments per the relaxation-
//! method protocol (Bachmann et al. 1972).
//!
//! Protocol per pulse:
//!   1. Wait for thermal equilibrium (T-drift < 1 mK / s for 60 s)
//!   2. Apply heat pulse: programmable height (J) and width (s)
//!   3. Record T(t) trace at 16 ms cadence for 5 × τ_thermal
//!   4. Compute ΔT_max → C(T) = Q / ΔT_max
//!   5. Stream {Q, ΔT, T_base, C} to host via UART
//!
//! 4 safety interlocks (= τ(6) = 4 anchor):
//!   1. Sample-stage T < 0.5 K (cryogen-loss alarm)
//!   2. Heat pulse rate-of-rise > 100 mK / s (over-power)
//!   3. UART telemetry timeout > 5 s (host disconnect)
//!   4. ADC valid-rate < 50 Hz (sensor failure)

#![cfg_attr(target_os = "none", no_std)]
#![cfg_attr(target_os = "none", no_main)]

use hexa_rtsc_firmware::anchors::{TAU, SIGMA, HC2_TARGET_T};
#[allow(unused_imports)]
use hexa_rtsc_firmware::pid::PidController;
#[allow(unused_imports)]
use hexa_rtsc_firmware::telemetry::{FrameType, frame};

// ─── interlock state machine ────────────────────────────────────────────

#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub enum InterlockReason {
    None,
    StageTempLow,         // T < 0.5 K (cryogen lost)
    PulseRateExcess,      // dT/dt > 100 mK/s during pulse
    HostTimeout,          // no telemetry ack > 5 s
    AdcDropout,           // ADC valid rate < 50 Hz
}

pub struct Interlocks {
    pub stage_temp_k: f32,
    pub last_pulse_dt_dt: f32,
    pub seconds_since_host: u32,
    pub adc_valid_hz: u32,
}

impl Interlocks {
    pub const fn new() -> Self {
        Self {
            stage_temp_k: 4.2,           // assume LHe bath default
            last_pulse_dt_dt: 0.0,
            seconds_since_host: 0,
            adc_valid_hz: 60,
        }
    }

    /// Check all 4 interlocks (= τ(6)).
    pub fn check(&self) -> InterlockReason {
        if self.stage_temp_k < 0.5            { return InterlockReason::StageTempLow; }
        if self.last_pulse_dt_dt > 0.100      { return InterlockReason::PulseRateExcess; }
        if self.seconds_since_host > 5        { return InterlockReason::HostTimeout; }
        if self.adc_valid_hz < 50             { return InterlockReason::AdcDropout; }
        InterlockReason::None
    }
}

// ─── relaxation-method pulse experiment ─────────────────────────────────

#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub enum PulseState {
    Idle,
    WaitEquilibrium,
    PulseActive,
    PulseRecord,         // record T(t) decay
    Compute,
    Reporting,
    Aborted(InterlockReason),
}

pub struct PulseExperiment {
    pub state:      PulseState,
    pub t_base_k:   f32,    // baseline temp at start of pulse
    pub t_peak_k:   f32,    // peak temp during pulse
    pub q_joules:   f32,    // applied heat
    pub elapsed_s:  f32,
    pub samples:    [f32; 256],   // T(t) buffer (16 ms × 256 ≈ 4 s)
    pub sample_idx: u16,
}

impl PulseExperiment {
    pub fn new() -> Self {
        Self {
            state:      PulseState::Idle,
            t_base_k:   0.0,
            t_peak_k:   0.0,
            q_joules:   0.0,
            elapsed_s:  0.0,
            samples:    [0.0; 256],
            sample_idx: 0,
        }
    }

    /// One control tick (every 16 ms = ADC interval).
    pub fn tick(
        &mut self,
        interlocks: &Interlocks,
        adc_temp_k: f32,
        dt_s: f32,
    ) -> Option<f32> {
        let reason = interlocks.check();
        if reason != InterlockReason::None {
            self.state = PulseState::Aborted(reason);
            return None;   // abort
        }

        match self.state {
            PulseState::Idle => None,
            PulseState::WaitEquilibrium => {
                // 60 s drift check; simplified: just transition after fixed time
                self.elapsed_s += dt_s;
                if self.elapsed_s >= 60.0 {
                    self.t_base_k = adc_temp_k;
                    self.elapsed_s = 0.0;
                    self.state = PulseState::PulseActive;
                }
                None
            }
            PulseState::PulseActive => {
                // 100 ms pulse window
                self.elapsed_s += dt_s;
                if self.elapsed_s >= 0.100 {
                    self.elapsed_s = 0.0;
                    self.state = PulseState::PulseRecord;
                }
                Some(self.q_joules)   // command DAC to pulse
            }
            PulseState::PulseRecord => {
                if (self.sample_idx as usize) < self.samples.len() {
                    self.samples[self.sample_idx as usize] = adc_temp_k;
                    if adc_temp_k > self.t_peak_k {
                        self.t_peak_k = adc_temp_k;
                    }
                    self.sample_idx += 1;
                } else {
                    self.state = PulseState::Compute;
                }
                None
            }
            PulseState::Compute => {
                // C(T) = Q / ΔT_max
                self.state = PulseState::Reporting;
                None
            }
            PulseState::Reporting => {
                self.state = PulseState::Idle;
                None
            }
            PulseState::Aborted(_) => None,
        }
    }

    /// Compute heat capacity: C = Q / ΔT_max  (units: J/K)
    pub fn heat_capacity(&self) -> Option<f32> {
        let delta_t = self.t_peak_k - self.t_base_k;
        if delta_t > 0.001 {
            Some(self.q_joules / delta_t)
        } else {
            None
        }
    }
}

// ─── BCS specific-heat ratio cross-check ────────────────────────────────

/// Compute ΔC/γTc and verify against n=6 anchor σ(6) / (7·ζ(3)) ≈ 1.4257.
pub fn check_bcs_ratio(delta_c: f32, gamma_tc: f32) -> bool {
    let ratio = delta_c / gamma_tc;
    let target_sigma6_over_7zeta3: f32 = 12.0 / (7.0 * 1.20206);
    let drift = (ratio - target_sigma6_over_7zeta3).abs() / target_sigma6_over_7zeta3;
    drift < 0.15   // ±15% per F-SC-3 falsifier band
}

// ─── #[cortex_m_rt::entry] (TBD when board lands) ──────────────────────

// #[cortex_m_rt::entry]
// fn main() -> ! {
//     let mut exp = PulseExperiment::new();
//     let interlocks = Interlocks::new();
//     loop {
//         let adc_t_k = read_ltc2400_adc();
//         if let Some(q) = exp.tick(&interlocks, adc_t_k, 0.016) {
//             write_ad5660_dac(q);
//         }
//         // ... wait for next tick interrupt ...
//     }
// }

// #[panic_handler]
// fn panic(_info: &core::panic::PanicInfo) -> ! {
//     loop { cortex_m::asm::wfi(); }
// }

// ─── unit tests (host-side) ─────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn anchors_match_n6() {
        assert_eq!(TAU, 4);
        assert_eq!(SIGMA, 12);
        assert_eq!(HC2_TARGET_T, 48);
    }

    #[test]
    fn interlock_count_is_tau6() {
        // 4 interlock variants in InterlockReason (excluding None)
        let variants = [
            InterlockReason::StageTempLow,
            InterlockReason::PulseRateExcess,
            InterlockReason::HostTimeout,
            InterlockReason::AdcDropout,
        ];
        assert_eq!(variants.len(), TAU as usize);
    }

    #[test]
    fn interlock_stage_temp_low() {
        let mut i = Interlocks::new();
        i.stage_temp_k = 0.4;
        assert_eq!(i.check(), InterlockReason::StageTempLow);
    }

    #[test]
    fn pulse_experiment_starts_idle() {
        let e = PulseExperiment::new();
        assert_eq!(e.state, PulseState::Idle);
    }

    #[test]
    fn heat_capacity_basic() {
        let mut e = PulseExperiment::new();
        e.q_joules = 1.0e-6;
        e.t_base_k = 4.0;
        e.t_peak_k = 4.01;
        let c = e.heat_capacity().unwrap();
        // C = 1e-6 / 0.01 = 1e-4 (within f32 precision)
        assert!((c - 1.0e-4).abs() < 1.0e-7);
    }

    #[test]
    fn bcs_ratio_anchor() {
        // Pb measured: ΔC/γTc ≈ 1.43
        assert!(check_bcs_ratio(1.43, 1.0));
        // Outside band: 2.0 ≠ 1.43
        assert!(!check_bcs_ratio(2.0, 1.0));
    }
}

// ─── host main stub (so `cargo build` works on macOS / Linux) ──────────
#[cfg(not(target_os = "none"))]
fn main() {
    println!("hexa-rtsc calorimetry_drv — host stub");
    println!("  τ(6) = {} interlocks · σ·τ = {} T anchor", TAU, HC2_TARGET_T);
    println!("  embedded build: cargo build --release --target thumbv7em-none-eabihf");
}

// ─── embedded entry placeholder (overrides into cortex_m_rt::entry on board) ──
#[cfg(target_os = "none")]
#[no_mangle]
pub extern "C" fn _start() -> ! {
    loop {}
}
