// firmware/mcu/lib.rs — workspace lib root for Phase D firmware skeletons.
//
// Each per-board file (pet_cyclotron.rs / tabletop.rs / cpt_bench.rs /
// thrust_bench.rs) is `#![no_std] #![no_main]` for embedded targets.
// At the host-test layer (`cargo test`), they compile as plain library
// modules under this `std` root so the unit tests can run.
//
// Phase D will split each into its own crate with vendor HAL deps and
// per-board `memory.x` linker scripts.

// On host: enable std for tests.  On embedded: no_std, no_main per file.
#![cfg_attr(not(any(test, feature = "host_test")), no_std)]

#[cfg(any(test, feature = "host_test"))]
#[path = "pet_cyclotron.rs"]
pub mod pet_cyclotron;

#[cfg(any(test, feature = "host_test"))]
#[path = "tabletop.rs"]
pub mod tabletop;

#[cfg(any(test, feature = "host_test"))]
#[path = "cpt_bench.rs"]
pub mod cpt_bench;

#[cfg(any(test, feature = "host_test"))]
#[path = "thrust_bench.rs"]
pub mod thrust_bench;
