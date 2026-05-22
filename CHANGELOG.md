# Changelog

Chronological log of notable changes. One section per ship batch, date-keyed. hexa-lang runs at high commit velocity (RFC-driven); this file carries the headline landings — `git log` is the detailed record.

For the full audit trail, see `git log`.

---

## 2026-05-23

- **drill honesty gate** — `_honesty_gate` read the BT-AI2 verdict through the wrong `Bt2Verdict` fields (`f_a`/`f_b` instead of `f_ai2_a`/`f_ai2_b`). Every `hexa drill` / `hexa kick` round emitted two spurious `map key 'f_a' not found` warnings, and the gate was dead — a missing key returns `void`, so `void > 0` was always false and F-AI2-A / F-AI2-B violations were never reported. Field names corrected to match the struct.

## 2026-05-22

- **GPU / TMA SGEMM** — TMA SWIZZLE_128B kernel work shattered the 0.85 cuBLAS-ratio ceiling: M=8192 ratio 0.819 → 0.978 (peak 0.992), M=512 parity 1.0000. N200–N206 cycle: first TMA+GEMM kernel bit-exact on sm_120, multi-stage DMA fusion, producer/consumer warp-spec, source-to-silicon E2E on sm_120a.
- **RFC 080 — atlas absorption** — Phase L/M/O: auto-PR absorption + `--target-absorb N` batched multi-cycle; `embed_fold` extraction; legacy DFS shards folded into `embedded.gen.hexa`.
- **runtime** — re-restored array-allocator hexa ports + `fileno()` shim after silent-wipe regressions; broad regression sweep (~121 ported fns).

## 2026-05-21

- **RFC 067 / 071 / 075** — TMA + GPU kernel rounds (wgmma + TMA + warp-spec probes).

## 2026-05-20

- **RFC 065 / 067 / 070** — heaviest ship day (463 commits); RFC 055 continuation.

## 2026-05-19

- **RFC 049 / 050 / 055 / 060 / 062** — multi-RFC build-out.

## 2026-05-18

- **RFC 057 / 058** — RFC cycle.

## 2026-05-17

- **RFC 044–049** — RFC cycle.
