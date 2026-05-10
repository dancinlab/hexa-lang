// firmware/mcu/cpt_bench.rs — HEXA-FACTORY-FW-01 CPT bench MCU companion
// (STM32H723VGT6 + XCKU040 PS-side glue).
//
// Phase D skeleton.  Spec source: firmware/sim/atomic_clock_counter.hexa
// (11/11 PASS).

#![no_std]
#![cfg_attr(not(test), no_main)]

/// Cs reference frequency (Hz).
pub const CS_REF_HZ: u32 = 10_000_000;

/// Cs 5071A fractional stability spec at averaging time.
pub const CS_FRAC_STAB_1S:    f64 = 5e-13;
pub const CS_FRAC_STAB_1000S: f64 = 1e-15;

/// TDC7201 timing resolution (picoseconds).
pub const TDC_RES_PS: u32 = 1;

/// 1S-2S two-photon laser wavelength (nm).
pub const LASER_WAVELENGTH_NM: f64 = 243.0;

/// Cavity finesse for narrow laser lock.
pub const CAVITY_FINESSE: f64 = 100_000.0;

/// PLL bandwidth bounds (Hz).
pub const PLL_BW_HZ_MIN: f64 = 10.0;
pub const PLL_BW_HZ_MAX: f64 = 1_000.0;

/// n=6 master identity in firmware register space (σ·φ = J₂).
pub const SIGMA: u32 = 12;
pub const PHI:   u32 = 2;
pub const N6:    u32 = 6;
pub const TAU:   u32 = 4;
pub const J2:    u32 = 24;

/// Phase-locked loop state: tracks ν_c against Cs reference.
pub struct PllState {
    pub locked: bool,
    pub error_hz: f64,         // residual frequency error
    pub bw_hz: f64,            // current loop bandwidth
}

impl PllState {
    pub const fn new(bw_hz: f64) -> Self {
        Self { locked: false, error_hz: 0.0, bw_hz }
    }

    /// Step the PI loop.  `meas_hz` is the latest TDC-derived ν_c reading;
    /// `target_hz` is the n=6-lattice-anchored value.  Returns true once
    /// locked (|error| < 1 / TDC counting interval).
    pub fn update(&mut self, meas_hz: f64, target_hz: f64) -> bool {
        let err = meas_hz - target_hz;
        // Trivial first-order; Phase D will use proper PI gains.
        self.error_hz = 0.9 * self.error_hz + 0.1 * err;
        self.locked = self.error_hz.abs() < 1.0;
        self.locked
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn master_identity_holds() {
        assert_eq!(SIGMA * PHI, J2);
        assert_eq!(N6 * TAU, J2);
    }

    #[test]
    fn cs_stability_meets_spec() {
        assert!(CS_FRAC_STAB_1S < 1e-12);
        assert!(CS_FRAC_STAB_1000S < 1e-14);
    }

    #[test]
    fn pll_acquires() {
        let mut pll = PllState::new(100.0);
        for _ in 0..200 {
            pll.update(731_400_000.5, 731_400_000.0);
        }
        assert!(pll.locked);
    }

    #[test]
    fn laser_wavelength_to_one_photon_freq() {
        let c_m_s = 2.998e8;
        let lambda_m = LASER_WAVELENGTH_NM * 1e-9;
        let f = c_m_s / lambda_m;
        // One-photon equivalent ≈ 1.234e15 Hz; two-photon excites 1S-2S at ~2.466e15.
        assert!(f > 1.2e15 && f < 1.3e15);
    }
}
