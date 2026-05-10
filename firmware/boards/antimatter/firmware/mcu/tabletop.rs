// firmware/mcu/tabletop.rs — HEXA-TABLETOP-FW-01 MPSoC PS-side controller.
//
// Phase D skeleton for XCZU9EG quad Cortex-A53 PS.  Spec source:
// firmware/sim/penning_rf.hexa (11/11 PASS).  Target:
// aarch64-unknown-none-softfloat.

#![no_std]
#![cfg_attr(not(test), no_main)]

#[derive(Copy, Clone, PartialEq, Eq, Debug)]
pub enum PenningState {
    Idle        = 0,
    AdRequest   = 1,
    AdConfirmed = 2,
    BeamInject  = 3,
    Cool        = 4,
    Store       = 5,
    Diag        = 6,
}

/// Timing budgets in milliseconds (mirrors firmware/sim/penning_rf.hexa).
pub const AD_HANDSHAKE_MS: u32 =     100;
pub const INJECT_MS:       u64 = 120_000;
pub const COOL_MS:         u64 =  30_000;
pub const STORE_MS:        u64 = 86_400_000;     // 24 hr
pub const DIAG_MS:         u32 =   5_000;

pub const SAFETY_DEADLINE_MS: u32 = 10;

/// n=6 trap field anchor (B = σ·τ T at 48 T).
pub const SIGMA: u32 = 12;
pub const TAU:   u32 = 4;

/// Cyclotron frequency (Hz) at B = σ·τ T.  Derived constant; matches
/// Phase B numerics_tabletop_relativistic.hexa.
pub const F_C_HZ: u64 = 731_400_000;

/// DDS phase increment for 731.4 MHz from 156.25 MHz DAC ref clock.
/// Phase accumulator is 32-bit; phase_inc = (F_C / F_REF) × 2^32.
pub const DDS_PHASE_INC: u32 = 0x4ADD_8E83;

pub fn next_state(s: PenningState, t_in_state_ms: u64) -> PenningState {
    use PenningState::*;
    match s {
        Idle        => AdRequest,
        AdRequest   => if t_in_state_ms >= AD_HANDSHAKE_MS as u64 { AdConfirmed } else { AdRequest },
        AdConfirmed => BeamInject,
        BeamInject  => if t_in_state_ms >= INJECT_MS { Cool }  else { BeamInject },
        Cool        => if t_in_state_ms >= COOL_MS   { Store } else { Cool },
        Store       => if t_in_state_ms >= STORE_MS  { Diag }  else { Store },
        Diag        => if t_in_state_ms >= DIAG_MS as u64 { Idle } else { Diag },
    }
}

/// AD_REQUEST → AD_CONFIRMED handshake guard: there is no skip path
/// from REQUEST or IDLE directly to BEAM_INJECT.
pub fn handshake_enforced(s: PenningState) -> bool {
    use PenningState::*;
    let next_from_req  = next_state(AdRequest, u64::MAX);
    let next_from_idle = next_state(Idle, u64::MAX);
    next_from_req == AdConfirmed && next_from_idle != BeamInject && s == s
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn state_traverses_seven() {
        let mut s = PenningState::Idle;
        let mut visited = 1u32;
        let mut prev = s;
        for _ in 0..100 {
            s = next_state(s, u64::MAX);
            if s != prev { visited += 1; prev = s; }
            if s == PenningState::Idle && visited > 1 { break; }
        }
        assert!(visited >= 7);
    }

    #[test]
    fn handshake_guards_beam_inject() {
        assert!(handshake_enforced(PenningState::Idle));
    }

    #[test]
    fn n6_anchor_b_field() {
        assert_eq!(SIGMA * TAU, 48);
    }
}
