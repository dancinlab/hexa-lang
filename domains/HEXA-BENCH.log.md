# HEXA-BENCH — log

## 2026-06-08 — domain registered

User asked for a PyTorch-vs-flame benchmark, then pointed out the sidecar pool has GPU hosts ("pool 있다며")
+ g1 (ai-native/canonical-first) → run on the FREE pool GPU (aiden RTX 5070, 12GB, idle/util 0%, mem 2MiB),
NOT a rented vast pod (saves $ + zero leak risk). summer also has a 5070 but its GPU mem is ~11.7GB occupied,
so aiden is the host. Supersedes the single-point #2912 (~1656-2207x @ batch=1 FP64) with a fair matched-dtype
batch sweep. RTX 5070 12GB may OOM FP64 D1536 → shrink config honestly. flame value = reproducibility/no-LLVM,
not step-rate; a large torch win is expected. BENCH-1 (sweep) → BENCH-2 (scorecard). Related: F-FUSION-VS-PYTORCH
#2912, HEXA-FLAME-FAST (closed-neg), reference_megastep_research.
