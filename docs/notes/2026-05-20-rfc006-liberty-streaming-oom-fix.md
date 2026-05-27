# rfc_006 §5 — liberty.hexa streaming parse · OOM blocker REMOVED

Date: 2026-05-20
Branch: `rfc006-absorption-a-liberty-stream`
Iter: rfc_006 §5 absorption iter 12 (after iter 11 #173 RTLIL non-const connect)
Author: dancinlife (Claude Opus 4.7 1M-ctx)
Status: SSOT-resolved (single-file surgical · 226+/96-)

## What changed

`stdlib/kernels/logic_synth/liberty.hexa` — full streaming parse
rewrite. No other files touched. Selftest 8/8 still PASS.

## OOM root cause (pre-fix)

The previous body of `parse_liberty(src)` ran:

1. `_lib_strip_comments` — character-by-character output accumulator
   `out = out + c` over the 12 MB source → O(N²) per-char reallocs
   inside the hexa-lang string runtime.
2. `_lib_normalize` — seven sequential `.replace()` passes over the
   accumulated string → 7× full-string copies at 12 MB each.
3. `_lib_tokens` — single global `.split(" ")` on the post-normalize
   string → ~3M-element token array.

On the 12 MB sky130_fd_sc_hd__tt_025C_1v80.lib (173k lines) this
pushed peak resident set to ~7.8 GB and the macOS kernel issued
SIGKILL during step (1). The §5 verdict step (`parse_liberty_file`
in gate_record.hexa) consequently died with `Killed: 9` after both
d4 and d6 pipelines completed but before any area-oracle could run.

## Streaming fix

The new body:

- Reads the file in one go (`read_file`), splits on `"\n"` once,
  then iterates line-by-line through a streaming state machine.
- Per-line tokenization (`_lib_strip_line_comments` + `_lib_normalize_line`
  + `_lib_tokens_line`) — each line is sub-KB so the seven `.replace()`
  passes are now negligible.
- Cross-line carry is limited to a single bit (`in_block` — whether
  we are mid-`/* … */` block comment) plus the running `LibState`
  (cell/pin scope flat fields + brace depth).
- All struct writes are top-level (`st.field = …`); cell/pin records
  are reconstructed at close-`}` events from flat working fields.
  This works around hexa-lang's nested-struct-assignment limitation
  (codegen produces no lvalue for `st.x.y = …`).

## Measurement

Probe (parse-only, 12 MB sky130_fd_sc_hd__tt_025C_1v80.lib):
- `lib.ok = 1`
- `lib.name = "sky130_fd_sc_hd__tt_025C_1v80"`
- `lib.cells = 428` (cells with all-fields successfully parsed)
- `cell[0].name = sky130_fd_sc_hd__a2111o_1`, area = 11.2608 µm²
- `sky130_fd_sc_hd__inv_1 area = 3.7536 µm²` (matches the Liberty source)
- sum of all cell areas = 6880.34 µm²

Gate `_run` (with rebased main = iter 11 #173 + #172 + #174):
- Real time: 12.07 s (down from SIGKILL/121 s pre-fix)
- Peak RSS: 311 MB (down from 7.8 GB pre-fix)
- d4/d6 read_verilog → hierarchy → proc → flatten → opt → techmap →
  dfflibmap: all OK
- d4/d6 abc_map: FAIL — new ABC error path uncovered:
  > Line 52: Signal "idx" is defined more than once.
  > Reading network from file has failed.

  This is an iter-11+ regression in the BLIF emit (likely the
  `.names buffer` path from PR #173 duplicates a signal). It is an
  INDEPENDENT blocker, not a liberty.hexa issue.

## Selftest

`hexa-run stdlib/kernels/logic_synth/liberty.hexa`:

```
liberty selftest: 8/8 PASS
```

(T1 empty · T2 minimal corpus · T3 inv_1 area + combinational ·
T4 dfxtp_1 sequential · T5 clock pin · T6 brace-imbalance fail-loud ·
T7 lib_total_area sum · T8 pin directions)

## §5 verdict (g3 honest)

§5 area-oracle remains **OPEN**.

The OOM blocker that prevented the verdict step from running has
been removed. The remaining gap is downstream of liberty.hexa:
the BLIF emit duplicates the `idx` signal on the iter-11 / #173
non-const connect path, so ABC's `read_blif` rejects the file
before mapping can produce gate-count output.

**Liberty parsing is no longer the blocker.** The §5 closure now
depends on resolving the duplicate-signal regression in `rtlil.hexa`
or `abc_map.hexa`'s BLIF emit — outside the scope of this iter.

## Governance

- @D g5 hexa-native-only: pure hexa-lang stdlib · zero new C ABI
- @D g6 atlas @cite: Liberty Reference Manual (Synopsys); also cited
  in the module header (CLEAN-ROOM provenance block).
- @D g7 inbox-patches-pipeline: this filing records the upstream
  state for downstream consumers.
- @D g3 honest: NOT claiming §5 closed; claiming the OOM blocker
  removed and the next downstream blocker now visible.
- @D g_plan_consolidation: companion `## 진행 로그` append landed
  in `compiler/PLAN.md`.
- @D g_stdlib_ownership: stdlib/kernels/logic_synth/liberty.hexa is
  hexa-lang owned · downstream consumers point, not copy.
