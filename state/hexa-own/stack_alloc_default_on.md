# HEXA_STACK_ALLOC default-ON flip — attempt #3 (SOUND scan) — FLIPPED (byteeq-gated)

Status: **FLIPPED to opt-OUT on the SOUND scan.** `_stack_alloc_enabled()` now returns
`env("HEXA_STACK_ALLOC") != "0"` (self/codegen.hexa ~L12756) — default-ON, disable only with
`HEXA_STACK_ALLOC=0`. BIT-CHANGING codegen → the release gate is **byteeq 3-target `gen3≡gen4`
(PR-CI) + install/shipping smoke**, NOT a local merge. PR opened `--base main`; DO NOT self-merge.

Branch `feat/mem-stack-alloc-default-on-v3`, off `origin/main` @ `ccd544c12` (#4695 tip — INCLUDES
both escape-scan holes fixed). Build/prove host: aiden (x86_64-linux, clang-18).

## Both escape-scan holes CLOSED (the scan is now SOUND) — confirmed in this checkout
1. **#4690 — `node.args` (expr-form)**: `_expr_escapes_arr_name` scans the call-arg list
   (self/codegen.hexa ~L13313) so an array handed to an opaque sink as a call arg
   (`f(empty)`, `box.push(empty)`) is caught as an escape. Mirrors the value-scan c17 fix.
2. **#4693 — `TryCatch`/`RecoverStmt` (stmt-form)**: `_stmt_escapes_arr_name` routes try_body
   (`node.left`) / catch_body (`node.right`) through the STATEMENT scan `_stmts_escape_arr_name`
   (self/codegen.hexa ~L13376) instead of mis-dispatching a statement-list through the
   expression walker (the `map key 'kind'/'left' not found` runaway → SIGSEGV of attempt #2).
3. **#4695 — sibling-parity audit**: the arr-scan/value-scan divergence family is CLOSED — no
   third latent hole. The two fixes above are the complete set.

## ★MANDATORY full-corpus re-proof on the SOUND scan (aiden x86_64-linux) — ALL CLEAN
Fixed transpiler `build/hexa_v2` built from a regenerated `self/native/hexa_cc.c` that embeds the
fixed scan (regen driven by the installed v0.577.0 with stack OFF → byte-clean bootstrap; the
own-start/coherent-runtime infra wall was quarantined via `HEXA_ZEROC_OWN_START=0`, orthogonal to
the escape scan). Proof driven with `HEXA_STACK_ALLOC=1` = the exact discipline that caught the 2
prior walls.

| check | result |
|-------|--------|
| CONTROL: try/catch+array minimal repro, stack-ON transpile | **rc=0 PASS** (attempt #2 SIGSEGV'd here) |
| (a) full corpus differential transpile — 980 modules (self+stdlib+compiler), ON vs OFF | **new-SIGSEGV=0, rc-diffs=0** (nonzero-rc 146==146 = baseline in-isolation dep failures, stack-independent) |
| (b) module_loader.hexa `ml_hset_new` emitted-C (ON) | `HexaVal empty = hexa_array_new();` → **HEAP** (escape via `buckets.push(empty)` correctly caught; NOT `__stk_empty`) |
| (c) law_io.hexa (try/catch + bounded array) stack-ON transpile | **rc=0, no SIGSEGV**; classification correct (`bad`/`suffixes` → `__stk_`, escaping returns → `hexa_array_new()`) |
| (d) runnable sample (example/*.hexa) ON vs OFF | **new-segv=0, output byte-identical (diffs=0)** |

Emitted-C inspection is the authoritative check (module_loader + law_io). Zero false-negatives,
zero crashes.

## Real-workload win — REAL and large (re-measured on the sound scan)
alloc-heavy: 5M-iter loop, each iter a non-escaping `let tri=[i,i+1,i+2]` (read-only).
Emitted C confirms `tri` → `__stk_tri` stack under ON.

| config | array_new | push | grow | Max RSS | output |
|--------|-----------|------|------|---------|--------|
| OFF    | 5,000,000 | 15,000,000 | 5,000,000 | 943,048 KB (~921 MB) | 37500007500000 |
| ON     | **0** | **0** | **0** | **5,384 KB (~5.3 MB)** | 37500007500000 |

25M allocations → 0; RSS **~175×** lower; output byte-identical. (Prior #4691 cite: 5.6MB/182×;
same magnitude, absolute RSS varies slightly by host/run.) The lever is worth shipping.

## Attempt-#2 wall — NOW RESOLVED
Attempt #2 aborted on the try/catch+array compiler SIGSEGV (the `_stmt_escapes_arr_name` missing
`TryCatch` arm). That hole is #4693, now on main and re-proven closed here (CONTROL repro rc=0,
law_io rc=0, 980-module corpus 0 new SIGSEGV). This is attempt #3; the scan is sound (family
closed per #4695), and the re-proof passed clean — no third distinct false-negative appeared.

## Release gate (next, NOT done locally)
BIT-CHANGING: the merge gate is **byteeq 3-target GREEN (gen3≡gen4 on all 3 targets) + install.sh
consumer smoke GREEN**, run on PR-CI, and an orchestrator promotion decision. Do NOT self-merge.
