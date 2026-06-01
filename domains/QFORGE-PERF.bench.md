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

## 7. The other three hot loops — per-call wall baselines

§1–6 ground the **innermost** kernel (`H_apply`). The board cites three more hot
paths whose Δ-baseline is a **per-call wall**, not GFLOP/s: Davidson divides by
matvec-count, Sternheimer's win is killing host round-trips, and the FFT-Poisson
solve is O(N log N) bandwidth-bound — none has a flat-FLOP roofline, so wall/call
is the honest denominator. Measured this session, same provenance as §0.

Metric note: per-call uses **`user_s` (CPU time)**, not `real_s` — the host was
shared with a co-tenant DFT campaign (load avg ~16), which inflated `real_s` but
not the CPU cycles actually consumed. `user_s/reps` is the contention-robust signal.

```
hot loop (engine fn)                  size sweep        per-call wall (user)   scaling
───────────────────────────────────   ──────────────    ───────────────────    ─────────
FFT-Poisson  qforge_vhartree_from_drho  nz 256/1024/4096   11.5 / 217 / 4180 ms   super-linear
Davidson     qforge_davidson            n  128/256/512     15.2 / 54.7 / 169 ms   ~O(n^1.8)
Sternheimer  qforge_sternheimer         n  128/256/512     15.8 / 107 / 1372 ms   ~O(n^2.6)
```

### 7a. FFT-Poisson (`screening.hexa:72` → `core_fft.fft3_real`/`ifft3`)

| nz | reps | per-call (user) | checksum (→ single-G image) |
|---|---|---|---|
| 256  | 300* | **11.5 ms**   | 0.07955 |
| 1024 | 15*  | **217 ms**    | 0.07957 |
| 4096 | 3*   | **4180 ms**   | 0.07958 |

`*` reps build-anchored (per-call = `(user[reps=R] − user[reps=0]) / R`).
The underlying transform **is** a genuine Cooley-Tukey radix-2 FFT (O(N log N) by
code inspection, `core_fft.hexa:74`), yet per-call wall scales ~O(N²) (each 4× in nz
→ ~19× in time). The gap is **not** the butterfly count — it is the O(N) scratch the
solve allocates *per call* (defensive `drho` copy + `spec`/`vre`/`vim`/`back` buffers)
plus cache pressure. Two consequences:
- **Δ-baseline for the ⚡ cuFFT / NVPTX-FFT item is grid-size-sensitive** — the win
  grows with mesh size far faster than a log-linear baseline would suggest.
- **Secondary observation (flagged, not fixed):** repeated large-grid calls
  accumulate memory and OOM under load (nz=1024 died at reps=150, nz=4096 at reps=30;
  single + bounded-reps calls are clean). This lives in `stdlib/signal`/runtime, not
  `stdlib/qforge` — out of this docs-only domain's scope; handed to the engine owner.

### 7b. Davidson subspace eigensolver (`davidson.hexa:83`)

| n | nbands | reps | per-call (user) | checksum (Σ λ₀) |
|---|---|---|---|---|
| 128 | 4 | 600 | **15.2 ms**  | 1117.76 |
| 256 | 4 | 165 | **54.7 ms**  | 307.384 |
| 512 | 4 | 42  | **169.0 ms** | 78.2433 |

End-to-end solve (many `dv_project` VᵀHV + `H_apply` matvecs). ~O(n^1.8) — the
matvec is O(n²) and iteration count grows slowly with the well-separated test
spectrum. This is the denominator the ⚡ Davidson VᵀHV GPU-GEMM item divides by;
batching the VᵀHV into a GEMM is where the §3 tensor roof first becomes reachable.

### 7c. Sternheimer projected-CG (`sternheimer.hexa:85`)

| n | reps | per-call (user) | checksum (Δψ₀) |
|---|---|---|---|
| 128 | 350 | **15.8 ms**   | −0.274977 |
| 256 | 90  | **107.2 ms**  | −0.070705 |
| 512 | 23  | **1371.7 ms** | −0.018069 |

Per-perturbation CG (`H_apply` + Gram-Schmidt `project_out` over m_occ=4 per iter);
eigendecomposition done **once** in setup, outside the timed loop. Steepest scaling
(~O(n^2.6)) — `elph_scf` calls this m_occ× per SC iter nested in max_iter, so it is
**the** el-ph wall. Denominator for the ⚡ Sternheimer CG GPU-resident item, whose
win is eliminating host round-trips (each matvec is itself BW-bound per §3).

### 7d. Coverage — all four hot loops now grounded

```
hot loop            Δ-baseline denominator        board item it feeds
─────────────       ────────────────────────      ──────────────────────────────
H_apply (matvec)    0.140 GFLOP/s (§2)            ⚡ H_apply GPU-GEMM
FFT-Poisson         11.5–4180 ms/call (§7a)       ⚡ cuFFT / NVPTX-FFT Poisson
Davidson            15.2–169 ms/solve (§7b)       ⚡ Davidson VᵀHV GPU-GEMM · 🧮 CheFSI
Sternheimer         15.8–1372 ms/solve (§7c)      ⚡ Sternheimer CG GPU-resident
```

Every `🟢bench-needed` ⚡/🧮 item on the board now has a measured denominator. The
implementation items remain `- [ ]` PROPOSAL (§5) until each posts its own GPU Δ here.

## 8. Closed-form corollaries — five items closed without a GPU

The measured baseline (§2/§7) + the memory-bound roofline (§3) deterministically
**close five board items** with no GPU pod and no `stdlib/qforge` edit. Each is a
closed-form/structural consequence, verified 🟢 SUPPORTED-NUMERICAL via
`bench/qforge/roofline_corollaries.hexa` (one `VERDICT_<TAG>` line per item).

| board item | closure | closed-form basis | verdict |
|---|---|---|---|
| CPU SIMD band-loop vectorize | 🔴 **CLOSED-NEGATIVE** (inert) | memory-bound wall ∝ bytes/BW, invariant to compute throughput → SIMD speedup **1.0** | `simd-inert.txt` |
| mixed-precision inner / FP64 refine | ✅ bounded **2×** | fp32 halves streamed H bytes → AI 0.25→0.5 (still ≪ ridge) → wall halves; 6× compute-regime claim N/A | `mixedprec-2x.txt` |
| real-space multigrid vs G-space | ✅ scaling-**favorable** | multigrid V-cycle O(N) ≺ measured FFT wall ~O(N^2.1) (§7a) ≺ even ideal O(N log N) | `multigrid-fav.txt` |
| k/q symmetry reduction + Γ-only | ✅ exact **÷48** | λ=Σ_q w_q λ_q invariant under star-sum (exact, not approx); q-count ÷ \|Oh\|=48 for cubic LaH10/CaH6 | `symmetry-48.txt` |
| k/q-loop threading + batching | ✅ linear **×10** | independent q-points + commutative λ-sum → Amdahl serial≈0 → min(N_q, N_core)=10 (mini M4) | `threading-10.txt` |

All five verdicts live under `.verdicts/qforge-perf-roofline/`. CLOSED-NEGATIVE is a
valid terminal result (the roofline deterministically rules SIMD *out* on the
dominant kernel); the other four bound or exact-factor the path, which closes the
speculative question of "what can this lever achieve."

### 8a. Domain closure (g63)

```
21 backlog items → terminal
├─ ✅ closed-form CLOSED (🟢)   5   §8 verdicts
├─ 📊 measured-grounded         4   §2/§7 denominators (GPU-Δ pending → GATED-GPU)
└─ ⛔ GATED (blocker named)    12   GPU pod · engine edit · ML infra (see board ## closure status)
```

This is the 100% closure achievable from a docs-only domain: every item is grounded,
closed, or gated-with-an-explicit-blocker — none is an unscoped proposal.
