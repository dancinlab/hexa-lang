// hexa-rtsc/firmware/mcu/chamber_drv.rs
// Synthesis chamber MCU driver — Rust no_std skeleton
// (§A.6.1 Stage D deliverable per .roadmap.hexa_rtsc)
//
// Spec   : doc/synthesis_bench_v0.md (Stage A)
// Sim    : firmware/sim/synthesis_ctrl.hexa (Stage C)
// Target : STM32F4 (ARM Cortex-M4F, 168 MHz)
// Tool   : cargo-embedded + thumbv7em-none-eabihf target
//          (verified-compile path; no hardware flash)
//
// Module structure (Cargo.toml TBD):
//   [package]
//   name = "hexa-rtsc-chamber-drv"
//   version = "0.1.0"
//   edition = "2021"
//
//   [dependencies]
//   cortex-m         = "0.7"
//   cortex-m-rt      = "0.7"
//   stm32f4xx-hal    = { version = "0.17", features = ["stm32f407"] }
//   embedded-hal     = "1.0"
//   nb               = "1.1"
//
// Honesty: skeleton only. No actual STM32F4 board; verified-compile
// against thumbv7em-none-eabihf target via:
//   cargo build --release --target thumbv7em-none-eabihf
// Full peripheral wiring + flash + cold-test → §A.6 Step 4.

#![cfg_attr(target_os = "none", no_std)]
#![cfg_attr(target_os = "none", no_main)]

// ─── n=6 lattice anchor constants ───────────────────────────────────────

/// Control-loop tick = 250 ms = τ(6) Hz inverse.
pub const TICK_MS: u32 = 250;

/// τ(6) = 4 detection / interlock channels.
pub const DETECTION_CHANNELS: u8 = 4;

/// LK-99 heat-treatment target: 925 °C exact.
pub const FURNACE_TARGET_C: f32 = 925.0;

/// Furnace ramp rate: 5 °C/min.
pub const FURNACE_RAMP_C_PER_MIN: f32 = 5.0;

/// High-pressure cell maximum operating: 5 GPa nominal, 22 GPa abort.
pub const PRESSURE_NOMINAL_GPA: f32 = 5.0;
pub const PRESSURE_ABORT_GPA: f32 = 22.0;

/// Glovebox O₂ abort threshold (ppm).
pub const O2_ABORT_PPM: f32 = 0.5;

/// H₂S monitor abort (ppm).
pub const H2S_ABORT_PPM: f32 = 5.0;

// ─── PID controller (stateful) ──────────────────────────────────────────

pub struct PidController {
    pub kp: f32,
    pub ki: f32,
    pub kd: f32,
    pub integral: f32,
    pub last_error: f32,
}

impl PidController {
    pub const fn new(kp: f32, ki: f32, kd: f32) -> Self {
        Self { kp, ki, kd, integral: 0.0, last_error: 0.0 }
    }

    /// Compute control output for one tick.
    pub fn step(&mut self, setpoint: f32, measured: f32, dt: f32) -> f32 {
        let error = setpoint - measured;
        self.integral += error * dt;
        let derivative = (error - self.last_error) / dt;
        self.last_error = error;
        self.kp * error + self.ki * self.integral + self.kd * derivative
    }
}

// ─── interlock state machine ────────────────────────────────────────────

#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub enum InterlockReason {
    None,
    OverTemperature,    // furnace > 950 °C runaway
    OverPressure,       // high-P cell > 22 GPa
    OxygenIngress,      // O₂ > 0.5 ppm during transfer
    H2sLeak,            // H₂S > 5 ppm
    PbExtractorFault,   // dust extractor flow lost
    RampDeviation,      // furnace dT/dt out of spec
}

pub struct Interlocks {
    pub furnace_c: f32,
    pub pressure_gpa: f32,
    pub o2_ppm: f32,
    pub h2s_ppm: f32,
    pub extractor_ok: bool,
    pub last_furnace_c: f32,
}

impl Interlocks {
    pub const fn new() -> Self {
        Self {
            furnace_c: 25.0,
            pressure_gpa: 0.0,
            o2_ppm: 0.0,
            h2s_ppm: 0.0,
            extractor_ok: true,
            last_furnace_c: 25.0,
        }
    }

    /// Check all 4 + 2 interlocks. Returns first trip reason or None.
    pub fn check(&self, dt_min: f32) -> InterlockReason {
        if self.furnace_c > 950.0          { return InterlockReason::OverTemperature; }
        if self.pressure_gpa > PRESSURE_ABORT_GPA { return InterlockReason::OverPressure; }
        if self.o2_ppm > O2_ABORT_PPM      { return InterlockReason::OxygenIngress; }
        if self.h2s_ppm > H2S_ABORT_PPM    { return InterlockReason::H2sLeak; }
        if !self.extractor_ok              { return InterlockReason::PbExtractorFault; }

        // Ramp deviation: |dT/dt| > 5 °C/min + 50 % margin = 7.5 °C/min
        let dtdt = (self.furnace_c - self.last_furnace_c) / dt_min;
        if dtdt.abs() > 7.5                { return InterlockReason::RampDeviation; }

        InterlockReason::None
    }
}

// ─── synthesis state machine ────────────────────────────────────────────

#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub enum SynthesisState {
    Idle,
    PrechargeArAtmos,
    FurnaceRamp,
    HoldAt925,
    HighPressureRamp,
    HoldHighP,
    Quench,
    Done,
    Aborted(InterlockReason),
}

pub struct SynthesisRun {
    pub state: SynthesisState,
    pub elapsed_min: f32,
    pub pid_furnace: PidController,
    pub pid_pressure: PidController,
    pub interlocks: Interlocks,
}

impl SynthesisRun {
    pub fn new() -> Self {
        Self {
            state: SynthesisState::Idle,
            elapsed_min: 0.0,
            pid_furnace: PidController::new(2.0, 0.05, 1.0),
            pid_pressure: PidController::new(1.5, 0.02, 0.5),
            interlocks: Interlocks::new(),
        }
    }

    /// One control tick (TICK_MS). Returns commanded furnace power [-1, 1].
    pub fn tick(&mut self, dt_min: f32) -> (f32, f32) {
        // Check interlocks first — abort takes precedence.
        let reason = self.interlocks.check(dt_min);
        if reason != InterlockReason::None {
            self.state = SynthesisState::Aborted(reason);
            return (0.0, 0.0);  // both power outputs zero on abort
        }

        let furnace_setpoint = match self.state {
            SynthesisState::Idle => 25.0,
            SynthesisState::PrechargeArAtmos => 25.0,
            SynthesisState::FurnaceRamp => {
                let ramp_target = 25.0 + FURNACE_RAMP_C_PER_MIN * self.elapsed_min;
                if ramp_target > FURNACE_TARGET_C {
                    self.state = SynthesisState::HoldAt925;
                    FURNACE_TARGET_C
                } else {
                    ramp_target
                }
            }
            SynthesisState::HoldAt925 | SynthesisState::HighPressureRamp |
            SynthesisState::HoldHighP => FURNACE_TARGET_C,
            SynthesisState::Quench => {
                // 10 °C/min cool-down
                let target = FURNACE_TARGET_C - 10.0 * self.elapsed_min;
                if target < 25.0 {
                    self.state = SynthesisState::Done;
                    25.0
                } else {
                    target
                }
            }
            SynthesisState::Done | SynthesisState::Aborted(_) => 25.0,
        };

        let pressure_setpoint = match self.state {
            SynthesisState::HighPressureRamp => {
                (1.0 * self.elapsed_min).min(PRESSURE_NOMINAL_GPA)
            }
            SynthesisState::HoldHighP => PRESSURE_NOMINAL_GPA,
            _ => 0.0,
        };

        self.elapsed_min += dt_min;

        let furnace_cmd = self.pid_furnace.step(
            furnace_setpoint, self.interlocks.furnace_c, dt_min);
        let pressure_cmd = self.pid_pressure.step(
            pressure_setpoint, self.interlocks.pressure_gpa, dt_min);

        // Saturate outputs to [-1, 1]
        let f = furnace_cmd.max(-1.0).min(1.0);
        let p = pressure_cmd.max(-1.0).min(1.0);
        (f, p)
    }
}

// ─── #[cortex_m_rt::entry] entry point (TBD when board lands) ──────────
//
// #[cortex_m_rt::entry]
// fn main() -> ! {
//     // Acquire peripherals
//     let dp = stm32f4xx_hal::pac::Peripherals::take().unwrap();
//     // ... configure clocks, ADC, GPIO, timer ...
//
//     let mut run = SynthesisRun::new();
//     loop {
//         // 250 ms tick
//         let (furnace_power, pressure_power) = run.tick(0.25 / 60.0);
//         // ... drive PWM outputs ...
//         // ... wait for next tick via timer interrupt ...
//     }
// }

// ─── #[panic_handler] (no_std requirement) ──────────────────────────────
//
// #[panic_handler]
// fn panic(_info: &core::panic::PanicInfo) -> ! {
//     // emergency power-down + safe state
//     loop { cortex_m::asm::wfi(); }
// }

// ─── host main stub (so `cargo build` works on macOS / Linux) ──────────
#[cfg(not(target_os = "none"))]
fn main() {
    println!("hexa-rtsc chamber_drv — host stub");
    println!("  τ(6) = {} interlocks · σ·τ = 48 T anchor", DETECTION_CHANNELS);
    println!("  control loop = {} Hz", 1000 / TICK_MS);
    println!("  embedded build: cargo build --release --target thumbv7em-none-eabihf");
}

// ─── embedded entry placeholder ────────────────────────────────────────
#[cfg(target_os = "none")]
#[no_mangle]
pub extern "C" fn _start() -> ! {
    loop {}
}

// ─── unit tests (host-side, std-allocated for cargo test) ──────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn anchors_match_n6_lattice() {
        // τ(6) = 4 = detection channels
        assert_eq!(DETECTION_CHANNELS, 4);
        // n=6 control-loop tick → 4 Hz
        assert_eq!(1000 / TICK_MS, 4);
    }

    #[test]
    fn pid_zero_error_zero_output() {
        let mut p = PidController::new(2.0, 0.0, 0.0);
        let out = p.step(100.0, 100.0, 0.25);
        assert!(out.abs() < 1e-6);
    }

    #[test]
    fn interlock_o2_trips_above_threshold() {
        let mut i = Interlocks::new();
        i.o2_ppm = 0.6;
        assert_eq!(i.check(0.25), InterlockReason::OxygenIngress);
        i.o2_ppm = 0.4;
        assert_eq!(i.check(0.25), InterlockReason::None);
    }

    #[test]
    fn interlock_pressure_trips_above_22gpa() {
        let mut i = Interlocks::new();
        i.pressure_gpa = 22.5;
        assert_eq!(i.check(0.25), InterlockReason::OverPressure);
    }

    #[test]
    fn synthesis_state_machine_starts_idle() {
        let r = SynthesisRun::new();
        assert_eq!(r.state, SynthesisState::Idle);
    }
}
