# HEXA-BENCH

@title: 🏁 HEXA-BENCH — flame vs PyTorch 정직 벤치마크

@goal: Honest head-to-head: flame CLMConvMoE train step vs PyTorch (eager + compile) across a batch
sweep at matched dtype, on the FREE pool GPU (aiden RTX 5070) — NOT a rented vast pod (g1 canonical-first).
Supersedes the single-point #2912 (batch=1 FP64, ~1656-2207x slower) with a fair curve: same shape, matched
dtype (TF32 — flame now has the FAST-2 TF32 path), throughput (samples/s) not just step/s. The point is an
HONEST scorecard of where flame stands + whether TF32/batch narrows the gap — flame's value is byte-exact/
no-LLVM/reproducible, NOT step-rate, so a large gap is EXPECTED and fine.

## milestones

- [ ] **BENCH-1 — matched-config batch sweep on aiden RTX 5070 (free pool GPU)** — flame (FP64 + TF32) vs
  torch (eager + torch.compile) at the SAME CLMConvMoE shape, batch sweep B=1,2,4,8 (sized to fit 12GB —
  shrink D if FP64 OOMs; report the config used). Metric: samples/s + step/s + the flame÷torch ratio per
  (dtype, B). Gate (g5): paste raw numbers verbatim; correctness note (flame byte-exact vs torch tolerance).
  Run via `sidecar pool on aiden` — NO vast rent, no leak risk. aiden RTX 5070 12GB idle confirmed.
- [ ] **BENCH-2 — honest scorecard + gap analysis** — does matched-dtype (TF32) + batch>1 narrow the
  ~1656x #2912 gap, and to what? Tabulate the curve, name the regime (if any) where flame is least-far-behind.
  Reflect the honest conclusion: flame's edge = reproducibility/no-LLVM, torch's = raw throughput. GPU 0 (doc).

## honest framing (g5)

flame is NOT a speed-competition tool — torch will almost certainly win throughput by a large margin (#2912
~1656x @ batch=1 FP64). The bench's value is (a) a FAIR, matched-dtype, batch-swept number replacing the
single worst-case point, and (b) measuring whether TF32+batch shrinks the gap at all. flame's actual value
(byte-exact · device-resident · no-LLVM · deterministic) is orthogonal to step-rate. Free pool GPU (aiden),
no vast cost. RTX 5070 12GB may OOM FP64 D1536 — shrink config + report it.
