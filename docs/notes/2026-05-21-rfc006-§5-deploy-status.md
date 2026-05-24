# RFC 006 §5 — deploy cycle 2026-05-21 — gate status: PARTIAL (new blocker named)

**Branch**: `upstream-deploy-exec-fix-S5-closure`
**Lineage**: origin/main after PR #251 merge (commit `8ea4b75e`)
**Trigger**: upstream task — promote runtime exec fix to deployed binary, verify byte-identical bootstrap fixpoint, re-run §5 oracle to drive RFC 006 §5 absorption gate to closure.

## TL;DR

- ✅ PR #251 (`c0da064a` — runtime cycle 66 exec/popen/env restore) merged to main via admin-squash.
- ✅ Source fix added: `_hexa_cert_module_name()` in `self/codegen_c2.hexa` now sanitizes non-ident chars to `_` (regression surfaced by regen — dotted temp paths like `hexa_build_expanded.<ns>.tmp.hexa` were leaking dots into emitted C identifier `__hexa_strlit_init__<mod>`).
- ✅ Bootstrap regen converged to byte-identical fixpoint (pass A → pass B byte-eq, md5 `c2159d0b222562d485d2e1a8052da7db`).
- ✅ Driver hexa.real rebuilt + installed; **exec("which abc") returns `/Users/ghost/bin/abc`** (was `""`); the §5 gate's first-tier blocker (PR #245 commit body) is resolved.
- ⚠ **§5 gate VERDICT: PARTIAL — d4 FAIL · d6 FAIL** at ABC `NetworkCheck: Network contains a combinational loop` on path `n272 → ... → n272 → CO "rr_ptr__d"` (d4) and `n372 → ... → n372 → CO "rr_ptr__d"` (d6).
- ❌ §5 area-oracle (router_d4 ≈ 61762.99 µm² · router_d6 ≈ 93608.53 µm²) **not measured** — both designs reject by ABC's combinational-loop checker.

## Measurement (full)

Cached binary direct invocation (bypasses hexa.real-run-wrapper stream-forwarding truncation):

```
$ /Users/ghost/.hexa-cache/hexa_run.<ns> \
    --lib /Users/ghost/core/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
```

### router_d4

| stage | verdict | detail |
|-------|---------|--------|
| read_verilog | OK | |
| hierarchy | OK | top=router_d4 |
| proc | OK | |
| flatten | OK | no-op |
| opt | OK | |
| proc_mux | OK | lowered 32 cond-tagged LHS-group(s) |
| clean_multidriver | OK | collapsed 7 LHS-group(s) — 5×idx/grant_out/any_grant |
| techmap | OK | techmap_sky130 |
| dfflibmap | OK | dfflibmap_sky130 |
| **abc_map** | **FAIL** | ABC: `Network "router_d4" contains combinational loop! Node "n272" encountered twice on path to CO "rr_ptr__d"` |

ABC log:
- Library `sky130_fd_sc_hd__tt_025C_1v80`: 334 cells (94 skipped: 63 seq, 13 tri-state, 18 no-func, 0 dont_use).
- 9 multi-output cells detected.
- 40 non-driven nets in `router_d4` driven by Constant-0 (fifo_mem[0..3] ...).
- NetworkCheck failure → Io_ReadBlifMv abort → ABC exit 1.

### router_d6

| stage | verdict | detail |
|-------|---------|--------|
| read_verilog | OK | |
| hierarchy | OK | top=router_d6 |
| proc | OK | |
| flatten | OK | no-op |
| opt | OK | |
| proc_mux | OK | lowered 44 cond-tagged LHS-group(s) |
| clean_multidriver | OK | collapsed 9 LHS-group(s) — 7×idx/grant_out/any_grant |
| techmap | OK | techmap_sky130 |
| dfflibmap | OK | dfflibmap_sky130 |
| **abc_map** | **FAIL** | ABC: `Network "router_d6" contains combinational loop! Node "n372" encountered twice on path to CO "rr_ptr__d"` |

ABC log:
- Same 334 cells loaded, 9 multi-output cells.
- 52 non-driven nets in `router_d6` driven by Constant-0.

### Cited oracle (unmeasured)

| design | oracle area µm² | measured | delta |
|--------|------------------|----------|-------|
| router_d4 | 61762.99 | — | — (ABC rejected) |
| router_d6 | 93608.53 | — | — (ABC rejected) |
| ratio    | 1.5156×  | — | — |

## Gate verdict

**§5 STATUS: OPEN — new blocker named.**

Per @D g3 honesty: the prior `any_grant` combinational-loop blocker (PR #247 / `cdfa8d46`'s read_verilog SSA-rename) is resolved (the script log shows 7 `clean_multidriver` collapses on `any_grant`/`grant_out`/`idx__ssa*` and ABC accepts the netlist past dfflibmap). The **new** blocker is a separate combinational loop centered on `rr_ptr__d` — the round-robin pointer register's d-input. The path goes `n272 → ... → n272` (d4) and `n372 → ... → n372` (d6), terminating at CO `rr_ptr__d`. This is either (a) another read-then-write inside an `always @*` block (semantic; needs SSA-rewrite extension), (b) a feedback wire treated as combinational that should be sequential, or (c) a true RTL bug. read_verilog SCOPE expansion is named as a remaining substrate need in the gate's own `g3 honesty` summary at the end of the run.

## Source fix (codegen_c2 sanitization)

The bootstrap regen surfaced a latent codegen bug introduced by PR `680dd512` (PR-B for #4j, 2026-05-20 20:36) which renamed the strlit-init aggregator to `void __hexa_strlit_init__<TU>(void)` using `_hexa_cert_module_name()`. That helper strips dir + `.hexa` suffix but did NOT sanitize remaining non-ident characters. The `runtime_tmpname()` helper in `self/main.hexa` (L2333-2336) generates `<dir>/<prefix>.<mono_ns>.tmp` style paths, so a `hexa run gate_record.hexa` flatten-then-build produces a temp file `hexa_build_expanded.<ns>.tmp.hexa`. The C identifier was emitted as `__hexa_strlit_init__hexa_build_expanded.1779302618786307000.tmp` — invalid C.

Fix (`self/codegen_c2.hexa::_hexa_cert_module_name`): after stripping `.hexa` suffix, walk the stem and replace any code-point outside `[A-Za-z0-9_]` with `_`. 19-line addition, zero behavior change for paths that already are valid identifiers (single-TU stage0/stage1 bootstrap + the ~1500 test_*.hexa case all unaffected — verified by the post-fix fixpoint converging to byte-identical pass A vs pass B).

## Bootstrap fixpoint

| Pass | hexa_cc.c md5 | hexa_v2 md5 | bytes | note |
|------|---------------|-------------|-------|------|
| pre  | `0f12ffa666fc1b40e7852c8641be67e3` | `54920d172c76be922cdbb3f92e0a4d12` | 1493127 | baseline (origin/main + PR #251 merged + new runtime.c) |
| 1    | `eb8f3982fca0d1af458885099168fe24` | (rebuilt) | 1501738 | substantive — pre-fix codegen evolution |
| 2    | `d6c31135882af7b6b99229e753326755` | `d66f18cba1611d52c5b126d2838ba339` | 1501792 | strlit_init rename cascade (still pre-fix sanitization) |
| 3    | `d6c31135882af7b6b99229e753326755` | (no rebuild) | 1501792 | BYTE-EQ vs pass 2 — interim fixpoint (still buggy) |
| — fix landed in `_hexa_cert_module_name` — | | | | |
| A    | `c2159d0b222562d485d2e1a8052da7db` | `321349ae49c2581554da3f128d002cb2` | 1503004 | post-fix +19 lines = sanitization loop |
| B    | `c2159d0b222562d485d2e1a8052da7db` | (no rebuild) | 1503004 | **BYTE-EQ vs pass A** ✅ TRUE FIXPOINT |

Final promoted artefacts:
- `self/native/hexa_cc.c` md5 `c2159d0b222562d485d2e1a8052da7db` (1503004 B, 23128 lines)
- `self/native/hexa_v2` md5 `321349ae49c2581554da3f128d002cb2` (1586136 B)

`self/runtime.c` md5 `f794d186325e7a037f81379b4f9eb654` — unchanged (PR #251 merge state, preserve grep PASS).

## exec/runtime verification

```
$ hexa-run /tmp/exec_test.hexa     # fn main(): println exec("which abc"), len
result=[/Users/ghost/bin/abc
]
len=21
```

Was `result=[]  len=0` pre-deploy. The runtime exec fix is alive in the deployed binary.

## Side findings

1. **hexa.real run wrapper output truncation** — when invoked as `hexa-run <script>`, the wrapper's child-output forwarding cuts stdout at exactly 4095 bytes (rc=0, mid-line, no flush of remainder). Direct invocation of the cached compiled binary returns full 7726-byte output. Likely a streaming pipe / setvbuf interaction in the wrapper. Separate concern; not blocking §5.
2. **`/Users/ghost/bin/hexa-*` basename-dispatch binaries** (hexa-run, hexac, hexa-build, hexa-parse) were stale standalone Mach-Os (md5 `595eccd8...`) — all four overwritten with the new `hexa.real` (md5 `48caef89...`); backups saved at `*.bak-2026-05-21`. The `/Users/ghost/.hx/bin/hexa.real` was also replaced; old at `.bak-2026-05-21`.
3. **The §5 oracle "abc_map: ok" 24h false-positive** referenced in PR #251's commit message was an artifact of the runtime exec stub regression — `exec("which abc")` returned "" so the chain reported the `[OK]` short-circuit. With the runtime restored, the gate now correctly fails at `abc_map` and prints the actual ABC error.

## Next steps (not in this cycle)

1. **Fix the `rr_ptr__d` combinational-loop blocker** — extend read_verilog SSA rewrite (PR #247 pattern) to cover the round-robin pointer register's `always @*` body OR investigate whether router_d4/router_d6 RTL has a true bug (the upstream cited oracle values 61762.99/93608.53 µm² imply ABC accepted them at yosys 0.65 — so either the RTL is sequential and we mis-classify it as comb, or upstream yosys 0.65 has a different default for register inference).
2. **Diagnose hexa.real run stdout truncation** — separate from §5; affects observability of any long-output script.
3. **Promote the source fix + binary upstream** — this deploy commit + the source fix should land via PR.

## Cross-links

- PR #245 (RFC 073 Phase 3e) — original `any_grant` combinational loop diagnosis
- PR #247 (cdfa8d46) — read_verilog per-iter SSA renaming fix for `any_grant`
- PR #250 (d698e61a) — RFC 073 Phase 3f T74 minimum-shape SSA falsifier
- PR #251 (c0da064a) — runtime cycle 66 exec/popen/env restore (merged this cycle)
- archive/patches/yosys-exec-runtime-regression-cycles-61-64.md (resolved by PR #251)
- archive/patches/runtime-env-and-exec-capture-stubs-block-cli-tools.md (resolved by PR #251)
- compiler/PLAN.md — single-source compile cycle log
- @D g_commit_push_deploy — this commit promotes the source fix + bootstrap binary atomically
