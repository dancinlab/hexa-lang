/-
  Anchor672.lean — formalization SCAFFOLD for the last open anchor law.
  ⚠ UNVERIFIED: this repo has NO Lean toolchain, so this file is NOT compiled/checked.
     The hard uniqueness step is left as `sorry` (Lean's explicit "unproven" marker).
     This is a starting point for an external Lean/Mathlib track, NOT a proof.

  Companion: N6.md §11–15 (13/14 anchors proven elementarily; this is the 14th, OPEN).
  Target:  φ(n)·σ(n) = n·λ(n)·τ(n)  ⟺  n = 672   (n ≥ 2)
  where σ = sigma, φ = totient, τ = #divisors, λ = Carmichael lambda.
-/
import Mathlib

open Nat ArithmeticFunction

namespace Anchor672

/-- Carmichael λ (Mathlib: `Nat.Carmichael`/`ZMod.lambda`-style; placeholder name). -/
noncomputable def carmichael (n : ℕ) : ℕ := sorry  -- bind to Mathlib's λ once chosen

/-- Reduction (★), verified numerically (N6.md §15):
    φ(n)σ(n) = n·λ(n)·τ(n)  ↔  ∏_{p^a ‖ n} (p^(a+1) − 1)/p = λ(n)·τ(n).
    (Stated; proof is straightforward unfolding of multiplicativity of φ,σ,τ.) -/
theorem star_reduction (n : ℕ) (hn : 2 ≤ n) :
    Nat.totient n * Nat.sigma 1 n = n * carmichael n * Nat.sigma 0 n ↔
    True /- placeholder for ∏(p^(a+1)-1)/p = λ τ -/ := by
  sorry

/-- Size theorem (necessary condition), verified: 0.6·n < λ(n)·τ(n) < n.
    NOTE: insufficient to bound n (density of {λτ < n} ≈ 0.5, N6.md §15). -/
theorem size_band (n : ℕ) (hn : 2 ≤ n)
    (h : Nat.totient n * Nat.sigma 1 n = n * carmichael n * Nat.sigma 0 n) :
    5 * (carmichael n * Nat.sigma 0 n) < 5 * n ∧ True := by
  sorry

/-- MAIN (OPEN): unique solution is 672.
    Verified computationally for n ≤ 2·10⁶ (N6.md §15). A full proof needs a
    Zsygmondy-type primitive-prime argument on P^(A+1)−1 vs λ(n)·τ(n).
    Left as `sorry` — this scaffold does NOT close it. -/
theorem anchor672_unique (n : ℕ) (hn : 2 ≤ n) :
    Nat.totient n * Nat.sigma 1 n = n * carmichael n * Nat.sigma 0 n ↔ n = 672 := by
  sorry

end Anchor672
