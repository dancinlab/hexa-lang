# QFORGE-PERF — measured baseline + roofline ceiling

> The Δ-baseline **denominator** for the QFORGE-PERF board. Every `🟢bench-needed`
> ⚡hardware-PR / 🧮algorithmic item is a speedup *ratio* — this file is what that
> ratio divides by. Until this landed, the board's denominator was empty (the
> `이 보드는 계획이지 측정치가 아니다` caveat). The proposals are still proposals;
> only the **baseline wall** and the **closed-form ceiling** below are measured.

provenance: `mini` · Apple M4 · 10 cores · macOS 26.5 · `hexa 0.1.0-dispatch` · 2026-06-01

## 1. What is measured

The single highest-leverage hot path the board cites: `qforge_h_apply`
(`stdlib/qforge/assembler.hexa:140`) — the dense O(n²) real-symmetric matvec
`v ↦ H·v` that **Davidson** AND **every Sternheimer CG iteration** call. It is the
innermost kernel under `elph_scf`, so its wall dominates the el-ph hot path.

```
[ build_ham O(n²) ] ──once──▶ [ qforge_h_apply  v↦H·v ] ──×reps──▶ [ checksum ]
                                  dense O(n²) matvec            (DCE guard +
                                  feed out→in each rep           Davidson/CG
                                  (Davidson/CG coupling)         iteration coupling)
```

Drivers (docs-only — `use` the engine read-only, edit nothing under `stdlib/qforge`):

| file | role |
|---|---|
| `bench/qforge/h_apply_core.hexa` | `qforge_h_apply_bench(n, reps)` — pure fn, no `main` |
| `bench/qforge/h_apply_n{256,512,1024}.hexa` | per-n literal wrappers (`hexa bench` does NOT forward `-- argv`) |
| `bench/qforge/roofline_bound.hexa` | closed-form roofline ceiling (deterministic → g5 verify) |

`reps` per n is sized so the matvec loop runs ~20 s — ≫ build/startup, so no
fixed-overhead anchor subtract is needed.

## 2. Measured CPU-scalar baseline

`FLOPs = reps · 2n²` (one matvec = n² fused multiply-add = 2n² flops).
`GFLOP/s = FLOPs / user_s / 1e9`. Re-measured fresh this session; reproduces the
prior run within noise.

| n | reps | user_s | GFLOP/s | checksum |
|---|---|---|---|---|
| 256  | 21000 | 19.74 | **0.1394** | 9.2795e+07 |
| 512  | 5200  | 19.36 | **0.1408** | 9.2694e+07 |
| 1024 | 1300  | 19.24 | **0.1417** | 7.9335e+07 |

**Baseline ≈ 0.140 GFLOP/s, flat in n.** Flatness is the memory-bound fingerprint:
arithmetic intensity is n-independent (`AI = 2n²/(b·n²) = 2/b`), so a memory-bound
kernel holds the same GFLOP/s across n — exactly what the table shows.

## 3. Closed-form roofline ceiling (RTX 5070, measured peak)

From `bench/qforge/roofline_bound.hexa`, verified 🟢 SUPPORTED-NUMERICAL — verbatim
verdict at `.verdicts/qforge-perf-roofline/h-apply-membound.txt`. GPU peaks are the
**measured** RTX 5070 achieved-peak from `domains/GPU-ROOFLINE.bench.md` (ubu-2,
2026-05-30): HBM 559.52 GB/s · FP32 CUDA-core 34.11 TFLOP/s · FP16 tensor 126.52 TFLOP/s.

| quantity | fp64 | fp32 |
|---|---|---|
| arithmetic intensity (flop/byte) | 0.25 | 0.50 |
| ridge point (compute_peak / BW, flop/byte) | — | 60.96 (CUDA) · 226.1 (tensor) |
| **memory-bound ceiling = BW·AI (GFLOP/s)** | **139.88** | **279.76** |

**VERDICT = MEMORY-BOUND.** `AI (0.25–0.5) ≪ ridge_fp32 (60.96) ≪ ridge_tc (226.1)`.
The binding roof is memory bandwidth, not FLOPs. A single dense GEMV **cannot reach
the tensor-core peak** — its AI is ~450× below the tensor ridge. Tensor peak is only
reachable by **batching matvecs into a GEMM** (raising AI), i.e. the Davidson-block /
multi-RHS path, not the lone `v↦H·v`.

## 4. Δ-baseline — what each board item divides by

```
CPU-scalar baseline          fp64 mem-ceiling       fp32 mem-ceiling
──────────────────           ────────────────       ────────────────
  0.140 GFLOP/s        ──▶      139.88 GFLOP/s   ──▶   279.76 GFLOP/s
                       ~1000× headroom            ~2000× headroom
```

| board item | denominator (this file) | honest ceiling |
|---|---|---|
| ⚡ H_apply GPU-GEMM | 0.140 GFLOP/s | ≤ ~1000× (fp64) / ~2000× (fp32) to **memory** roof — tensor peak unreachable for single GEMV |
| ⚡ Davidson VᵀHV GPU-GEMM | (same kernel, batched) | batching raises AI → tensor roof *becomes* reachable; this is where TF32/BF16 wins live |
| ⚡ Sternheimer CG GPU-resident | 0.140 GFLOP/s × (m_occ·max_iter calls) | BW-bound per matvec; win = killing host round-trips, not FLOP peak |
| 🧮 CheFSI / EPW-Wannier | matvec **count**, not GFLOP/s | orthogonal axis — fewer matvecs, each still BW-bound at this ceiling |

The headroom is large but **memory-bound capped**: the realistic ⚡ ceiling is the
140–280 GFLOP/s memory roof (~1000–2000×), *not* the 126 TFLOP/s tensor peak. Any
PR claiming > ~2000× on a single GEMV contradicts this roofline and is suspect.

## 5. Honest scope (g6/g63)

- **Measured & closed here:** the CPU-scalar baseline wall + the closed-form roofline
  ceiling + the memory-bound verdict. These are terminal (🟢).
- **NOT closed (still PROPOSAL):** every ⚡/🧮/🧠 *implementation* item. They need
  (a) a GPU pod (all currently STOPPING) and (b) edits under `stdlib/qforge` — which
  this domain does **not** touch (docs-only; a separate CaH6-run agent edits the
  engine · d9 worktree isolation). Each stays `- [ ]` until its own `hexa bench`
  Δ-vs-this-baseline lands.
- A ⚡/🧮 item flips to closed only when it posts `achieved GFLOP/s ÷ 0.140` here.

## 6. Verdict pointers

| claim | tier | verdict |
|---|---|---|
| dense H_apply matvec is memory-bound on RTX 5070 | 🟢 SUPPORTED-NUMERICAL | `.verdicts/qforge-perf-roofline/h-apply-membound.txt` |
| CPU-scalar baseline ≈ 0.140 GFLOP/s (flat in n) | 🟢 measured | this file §2 (reproduce: `HEXA_LANG=. hexa run bench/qforge/h_apply_n256.hexa`) |
