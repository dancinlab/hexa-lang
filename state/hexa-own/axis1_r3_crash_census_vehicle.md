# axis-① R3 — crash-census instrumentation vehicle (design + scaffold)

**Deliverable named by the ①-R2 census (`axis1_r2_crash_census.md`, #4742), Rank 2.**
Scaffold PR only — the harness is a MEASUREMENT vehicle that runs on the pool
(aiden/summer); it is not executed on mini.

---

## Why (the frontier the R2 census moved to)

The R2 census measured the LOUD abort class (HX1101/2/3/4 → C fallback) as
**NEAR-DRAINED**: no discrete `lower/` arm still fires on any in-tree `.hexa`
source (or/range/tuple HX1102 = 0 frequency; HX1103 defensive-empty; HX1104
dead; HX1101 residual = resolver, not lowering). Draining "another HX110x arm"
is a dry well.

What actually keeps `hexa_cc.c` alive on the default `cmd_build` path is:

1. the **x86_64 HexaVal pair-carry SILENT miscompile**
   (`F-RT-NATIVE-X86-CODEGEN-ROOTCAUSE`, `compiler/codegen/x86_64_linux.hexa`
   :609–682) — the raw 1-register value-model drops `rdx`/payload on a returned
   HexaVal `{tag,payload}` through a store → SIGSEGV in e.g. `hexa_array_push`.
   Owned by **②-R4** (a multi-week value-model rearch, not a lower/ arm); arm64
   is the byte-identical existence proof it is fixable.
2. the **absence of a live crash-census measurement** — the "13
   native-crash-where-clang-works" number is a **stale** legacy figure
   (`selfhost_done_criterion_dag_fable.md`, `no_runtime_c_no_cc_verdict.md`),
   several of whose members are already-closed compiler SIGSEGVs (escape-scan
   runaway #4693 & siblings). Nobody has a *measured* live count.

The delegate-fallback (`self/main.hexa` leg-B) catches emit/link *failures*
(loud → fall back to C, safe). It **cannot** see a native binary that emits,
links, runs, and returns the WRONG answer / SIGSEGVs. That silent class is the
only thing that can burn a user on a "green" `cmd_build` default-flip — so it is
the true trust-gate, and it has never been measured. R3 stands up the vehicle
that measures it.

## What (the differential)

`tool/native_c_crash_census` — a **NATIVE-vs-C `hexa build` differential** over a
real build corpus. For each program it builds BOTH ways through the *shipping*
consumer path and diffs (exit code + stdout):

| leg | invocation | role |
|-----|-----------|------|
| **C-oracle** | default `hexa build` (hexat → C-transpile → clang) | golden — the expected value |
| **native** | `HEXA_BUILD_NATIVE=1 HEXA_RUN_NATIVE_TRACE=1 hexa build` (aprime own-IR `--emit=obj` + `ld`, zero hexat/clang) | the path under test |

Because the C-oracle *is* the expected value, **no per-program hardcoded output
is needed** — the corpus is any real `.hexa` program. This is the property that
lets the census reuse the existing corpora wholesale.

### Serve-mode discrimination (the crux)

The native `hexa build` path **falls back to C** on any emit/link failure, so an
invocation that fell back is *not* a native measurement (its binary equals the
C-oracle — a safe COMPILE-coverage gap, not a silent miscompile). The harness
detects a genuine native serve by the success marker on the build stdout:

```
"(native backend, leg-B — no hexat, no clang)"      self/main.hexa:3570
```

Only a program that **SERVED native** and then **diverged** (rc or stdout) is a
census entry. A fallback is counted separately and never graded RED.

### Classification → the live count

| class | meaning | grade |
|-------|---------|-------|
| **PASS** | served native, `(rc,stdout) == C-oracle` | ok |
| **MISCOMPILE** | served native, produced a binary, but diverges from the oracle — or crashed (`rc≥128`) / hung (timeout `rc=124`) | the live census entry |
| **FALLBACK** | native fell back to C (loud abort / infra); served binary == oracle | safe residual (compile-coverage gap) |
| **SETUP** | the C-oracle itself failed to build/run → no differential | infra, skipped |

The printed **LIVE crash-where-clang-works count = MISCOMPILE total** — this is
the number that replaces the stale "13". `CENSUS_KNOWN=<basenames>` acknowledges
expected members (the tracked x86_64 pair-carry, census #1) so they are still
counted+printed but split out as `KNOWN`, leaving `NEW` as the regression axis.

## Exit contract (measurement + gate in one)

- `0` — no NEW silent miscompile (clean, or only `CENSUS_KNOWN`); the live count
  is printed regardless.
- `1` — ≥1 **NEW** native-crash-where-clang-works (a program the C path builds &
  runs correctly, silently miscompiled by the native path). The only red.
- `2` — SETUP/INFRA neutral: no driver / empty corpus / **no program served
  native here** (canary fell back — darwin/mini, non-x86_64/aarch64, or a
  runtime.a without own-start). The floor is not broken; run on the linux pool.
  CI remaps 2 → neutral.

A trivial arith **canary** gates up front: if even it will not native-serve, the
host cannot exercise leg-B → exit 2 immediately (mirrors the
`miscompile_zero_gate.sh` canary fence against a whole-host non-serving run
masquerading as "0 findings").

## Corpus (reused, per the task's "reuse the corpus" instruction)

Default `CENSUS_CORPUS = "self/test/miscompile_zero self/test/miscompile_class"`
— the two proven miscompile corpora, both real deterministic `.hexa` programs:

- `self/test/miscompile_zero/*.hexa` (c1..c14, g1..g2) — **program-level**: hex
  literals, stack locals, struct ctor, closures, recursion+array store, string
  methods, match control, try/catch, fn-addr, defer, array×try/catch. Covers the
  boxed-return-through-store shape (c7 recursion+array store, c14 array×try) that
  census #1 fires on.
- `self/test/miscompile_class/*.hexa` (m1..m12) — **primitive-level**, incl.
  **`m4_two_reg_value_abi`** (the 2-register HexaVal value ABI held live across a
  clobbering call — the closest isolated probe for census #1) and
  `m12_try_catch_setjmp`.

Both corpora were previously exercised only at the **emit level** (native
`--emit=obj` → ENCODE-MISS/udf, via `tool/miscompile_zero_gate.sh` and
`self/test/miscompile_class/run.sh`, using the *graduated* `gen2_fix` compiler
+ clang-link). This vehicle is **complementary**: it exercises the *shipping*
`hexa build` native leg-B (own-IR + `ld`, no clang) and diffs **runtime**
behaviour against the C build — catching the silent class on the exact consumer
path a `cmd_build` flip would ship, which the emit-level gates do not.

## Reuse of the existing native-build idiom

The harness reuses the build/driver recipe from
`tool/selfhost_native_build_gate` and `tool/miscompile_zero_gate.sh`:
- driver resolution (`HEXA` → PATH → `~/.hx/bin/hexa`, else neutral exit 2),
- the up-front canary → exit-2 infra fence,
- extension-less filename (the sidecar hook blocks `.sh` Write/Edit),
- `build/`-rooted (gitignored) work dir, never `/tmp`,
- SETUP/INFRA (2) vs REGRESSION (1) separation so an incapable runner is
  NEUTRAL, never a false RED.

It differs by driving the **shipping** `hexa build` (not `gen2_fix --emit=obj`)
and by using a **native-vs-C runtime differential** (not an emit-level
ENCODE-MISS/udf scan) — that is the new capability.

## How to run (round_next — pool)

```bash
# on aiden (or summer), from a fresh checkout with a native runtime.a (own-start):
bash tool/native_c_crash_census
# acknowledge the tracked #1 once identified (keeps the gate green on it):
CENSUS_KNOWN="m4_two_reg_value_abi c7_recursion_arrays" bash tool/native_c_crash_census
```

Expected first-run shape on x86_64-linux: the tracked HexaVal pair-carry (#1)
surfaces as one-or-more MISCOMPILE entries on the boxed-return-through-store
programs; everything else PASS or FALLBACK. That **live count** is the number
that finally retires the stale "13", and the specific entry list is the tracked
residual `②-R4` must clear before a trusted `cmd_build` x86_64 default-flip.

## Round map

- **①-R2 (#4742):** loud-abort class drained; named this vehicle as Rank 2. ✔
- **①-R3 (this PR):** scaffold `tool/native_c_crash_census` + this design doc.
  Byte-neutral (new tool + new state doc; no compiler/runtime/codegen change).
- **①-R4 (next, pool):** run the census on aiden → capture the live count +
  entry list; fold the number into `ARCHITECTURE.json` convergence + the R2
  census headline (retire the stale "13"). Wire ADVISORY on the CI summary with
  the x86 pair-carry acknowledged via `CENSUS_KNOWN` (green-on-known,
  red-on-new).
- **cross-lane:** the NEW-entry regression axis becomes a standing guard for
  ②-R4 — each value-model rearch rung must not add a new silent miscompile, and
  the KNOWN set shrinks to ∅ as the pair-carry is fixed (the real gate to a
  trusted x86_64 `cmd_build` default-flip = 0 MISCOMPILE, 0 KNOWN).
