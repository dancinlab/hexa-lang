//! hexa-rtsc-firmware — shared library for chamber_drv + calorimetry_drv
//!
//! §A.6.1 Phase D+ deliverable.  Common code shared between the
//! synthesis-chamber MCU (chamber_drv.rs) and the calorimetry-rig MCU
//! (calorimetry_drv.rs).  All types are #[no_std]-compatible.
//!
//! n=6 lattice anchors live in the [`anchors`] module; both binaries
//! re-export them for spec traceability.

#![no_std]

pub mod anchors {
    //! n=6 lattice constants (= .roadmap §A.1).
    //!
    //! These are the same anchors used in `verify/calc_*.hexa` and
    //! `verify/numerics_*.hexa`.  Embedding them in firmware ensures
    //! that any hardware-derived measurement falls back to the same
    //! integer SSOT — no silent drift between code-layer and runtime.

    /// σ(6) = sum of divisors of 6 = 1+2+3+6 = 12.
    pub const SIGMA: u8 = 12;
    /// τ(6) = number of divisors of 6 = 4.
    pub const TAU: u8 = 4;
    /// φ(6) = Euler totient = #{k ≤ 6 : gcd(k,6)=1} = 2.
    pub const PHI: u8 = 2;
    /// sopfr(6) = sum of prime factors with multiplicity = 2+3 = 5.
    pub const SOPFR: u8 = 5;
    /// J₂(6) = Jordan totient = 24.
    pub const J2: u8 = 24;
    /// n = 6.
    pub const N: u8 = 6;

    /// Master identity: σ·φ = n·τ = J₂ = 24.
    pub const MASTER_IDENTITY: u8 = 24;

    /// Hc2 master gate: σ·τ = 48 T.
    pub const HC2_TARGET_T: u32 = 48;

    /// Static check that anchors satisfy the master identity.
    /// Will fail to compile if the lattice changes.
    const _: () = assert!(SIGMA as u32 * PHI as u32 == 24);
    const _: () = assert!(N as u32 * TAU as u32 == 24);
    const _: () = assert!(SIGMA as u32 * TAU as u32 == HC2_TARGET_T);
    const _: () = assert!(SIGMA - PHI == 10);  // false-positive multiplier
}

pub mod pid {
    //! Reusable PID controller (used by both chamber + calorimetry).

    pub struct PidController {
        pub kp: f32,
        pub ki: f32,
        pub kd: f32,
        pub integral: f32,
        pub last_error: f32,
        pub output_min: f32,
        pub output_max: f32,
    }

    impl PidController {
        pub const fn new(kp: f32, ki: f32, kd: f32) -> Self {
            Self {
                kp, ki, kd,
                integral: 0.0,
                last_error: 0.0,
                output_min: -1.0,
                output_max: 1.0,
            }
        }

        pub const fn with_limits(kp: f32, ki: f32, kd: f32, lo: f32, hi: f32) -> Self {
            Self {
                kp, ki, kd,
                integral: 0.0,
                last_error: 0.0,
                output_min: lo,
                output_max: hi,
            }
        }

        pub fn step(&mut self, setpoint: f32, measured: f32, dt: f32) -> f32 {
            let error = setpoint - measured;
            self.integral += error * dt;
            let derivative = (error - self.last_error) / dt;
            self.last_error = error;
            let raw = self.kp * error + self.ki * self.integral + self.kd * derivative;
            // saturate
            if raw > self.output_max { self.output_max }
            else if raw < self.output_min { self.output_min }
            else { raw }
        }

        pub fn reset(&mut self) {
            self.integral = 0.0;
            self.last_error = 0.0;
        }
    }
}

pub mod telemetry {
    //! Common telemetry/UART framing for streaming sensor data to host.
    //!
    //! Frame format (12 bytes):
    //!   [0]      0xAA   sync byte
    //!   [1]      0x55   sync byte
    //!   [2]      cmd    (frame type)
    //!   [3]      len    (payload bytes, 0..8)
    //!   [4..12]  payload (little-endian)
    //!   Trailer: 1-byte XOR checksum appended → 13 bytes total.

    pub const SYNC0: u8 = 0xAA;
    pub const SYNC1: u8 = 0x55;

    #[derive(Copy, Clone)]
    #[repr(u8)]
    pub enum FrameType {
        Heartbeat       = 0x01,
        TempReading     = 0x02,
        PressureReading = 0x03,
        InterlockTrip   = 0x04,
        StateChange     = 0x05,
        AdcSample       = 0x06,
        DacAck          = 0x07,
    }

    pub fn frame(cmd: FrameType, payload: &[u8], buf: &mut [u8; 13]) -> usize {
        buf[0] = SYNC0;
        buf[1] = SYNC1;
        buf[2] = cmd as u8;
        let len = payload.len().min(8);
        buf[3] = len as u8;
        let mut xor: u8 = 0xAA ^ 0x55 ^ buf[2] ^ buf[3];
        for i in 0..len {
            buf[4 + i] = payload[i];
            xor ^= payload[i];
        }
        for i in len..8 {
            buf[4 + i] = 0;
        }
        buf[12] = xor;
        13
    }
}

#[cfg(test)]
mod lib_tests {
    use super::anchors::*;
    use super::pid::*;
    use super::telemetry::*;

    #[test]
    fn anchors_master_identity() {
        assert_eq!(SIGMA as u32 * PHI as u32, MASTER_IDENTITY as u32);
        assert_eq!(N as u32 * TAU as u32, MASTER_IDENTITY as u32);
        assert_eq!(SIGMA as u32 * TAU as u32, HC2_TARGET_T);
    }

    #[test]
    fn pid_zero_at_setpoint() {
        let mut c = PidController::new(2.0, 0.0, 0.0);
        let out = c.step(100.0, 100.0, 0.25);
        assert!(out.abs() < 1e-6);
    }

    #[test]
    fn pid_saturates_at_max() {
        let mut c = PidController::with_limits(100.0, 0.0, 0.0, -0.5, 0.5);
        let out = c.step(100.0, 0.0, 0.25);   // huge error
        assert_eq!(out, 0.5);
    }

    #[test]
    fn telemetry_frame_format() {
        let mut buf = [0u8; 13];
        let n = frame(FrameType::Heartbeat, &[1, 2, 3], &mut buf);
        assert_eq!(n, 13);
        assert_eq!(buf[0], 0xAA);
        assert_eq!(buf[1], 0x55);
        assert_eq!(buf[2], 0x01);
        assert_eq!(buf[3], 3);
        assert_eq!(buf[4], 1);
        assert_eq!(buf[5], 2);
        assert_eq!(buf[6], 3);
        // checksum: 0xAA ^ 0x55 ^ 0x01 ^ 0x03 ^ 0x01 ^ 0x02 ^ 0x03
        let expected_xor: u8 = 0xAA ^ 0x55 ^ 0x01 ^ 0x03 ^ 0x01 ^ 0x02 ^ 0x03;
        assert_eq!(buf[12], expected_xor);
    }
}
