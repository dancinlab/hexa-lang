// firmware/mcu/thrust_bench.rs — HEXA-PROPULSION-FW-01 thrust bench MCU
// companion (STM32H743 + XCVU13P PS-side glue).
//
// Phase D skeleton.  Spec source: firmware/sim/thrust_acquisition.hexa
// (10/10 PASS).

#![no_std]
#![cfg_attr(not(test), no_main)]

/// FPGA trigger latency budget (nanoseconds).
pub const TRIGGER_LATENCY_NS: u32 = 100;

/// Watt-balance noise floor (nN).  Sub-μN sensitivity.
pub const WATT_FLOOR_NN: f64 = 100.0;     // 0.1 μN

/// Pion ToF discriminator gate width (ns).  Cosmic-ray bg rejection.
pub const TOF_GATE_NS: f64 = 50.0;

/// BGO calorimeter trigger threshold (keV).
pub const BGO_THRESH_KEV: f64 = 200.0;

/// p̄ release pulse duration (ms).
pub const TAU_BURN_MS: f64 = 1.0;

/// p̄ per shot.
pub const N_PBAR_PER_RUN: u64 = 1_000_000_000;

/// n=6 fleet count (σ - φ).
pub const SIGMA: u32 = 12;
pub const PHI:   u32 = 2;
pub const FLEET_COUNT: u32 = SIGMA - PHI;     // = 10

/// Trigger fan-out skew budget (ns).
pub const FANOUT_SKEW_NS: f64 = 1.0;

/// Per-event impulse magnitude (N·s) at 2/3 charged-pion fraction:
/// Δp ≈ 2 m_p c × 2/3 ≈ 6.69e-19 N·s.
pub const DP_PER_EVENT_NS: f64 = 6.69e-19;

/// Compute total thrust (N) from N_pbar over τ_burn (s).
pub fn thrust_n(n_pbar: u64, tau_burn_s: f64) -> f64 {
    let dp_total = (n_pbar as f64) * DP_PER_EVENT_NS;
    dp_total / tau_burn_s
}

/// Coincidence window check: BGO and ToF must fire within
/// `coinc_window_ns` of each other.
pub fn coincidence_ok(bgo_t_ns: f64, tof_t_ns: f64, coinc_window_ns: f64) -> bool {
    (bgo_t_ns - tof_t_ns).abs() <= coinc_window_ns
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fleet_anchor_holds() {
        assert_eq!(FLEET_COUNT, 10);
    }

    #[test]
    fn thrust_one_run_is_micronewton_class() {
        let f = thrust_n(N_PBAR_PER_RUN, TAU_BURN_MS / 1000.0);
        // 0.67 μN expected (1e9 × 6.69e-19 / 1e-3)
        assert!(f >= 0.1e-6 && f <= 10.0e-6);
    }

    #[test]
    fn thrust_above_watt_floor() {
        let f = thrust_n(N_PBAR_PER_RUN, TAU_BURN_MS / 1000.0);
        let snr = f / (WATT_FLOOR_NN * 1e-9);
        assert!(snr >= 5.0);
    }

    #[test]
    fn coincidence_within_window() {
        assert!(coincidence_ok(10.0, 12.0, 50.0));   // 2 ns Δ within 50 ns window
        assert!(!coincidence_ok(10.0, 100.0, 50.0)); // 90 ns Δ outside
    }

    #[test]
    fn trigger_latency_under_one_us() {
        assert!(TRIGGER_LATENCY_NS <= 1000);
    }

    #[test]
    fn fanout_skew_under_5ns() {
        assert!(FANOUT_SKEW_NS <= 5.0);
    }
}
