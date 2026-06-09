<!-- @plan: HEXA-CC-NATIVE N5→N6→N7 — drive the compiler to a C-free self-host fixpoint -->
<!-- @created: 2026-06-10 -->
<!-- @domain: HEXA-CC-NATIVE (active) -->
<!-- @policy: COMPLETENESS-FIRST LOOP · SESSION-AUTO ① 완성도 (HEXA-CC-NATIVE.md @policy) -->

# HEXA-CC-NATIVE N5 — plan: C-free self-host fixpoint

## 0. Goal (why this is THE milestone)

User goal: **"hexa self-hosted를 모든 프로젝트가 알아서 쓸 때까지"** — every project uses the
self-hosted toolchain, with NO C intermediate. The default `hexa build` today is still
`hexa → C → clang → .o → ld` (C-transpile). The C-free native path
(`hexa codegen → machine-code → hexa_ld`) exists and is PROVEN for small corpora (N3/N4 closed,
0 clang/as/ld forks, `.c=0 .a=0`), but it is **opt-in** and the compiler cannot yet rebuild
ITSELF C-free to a byte-eq fixpoint (N5). Closing N5→N6→N7 flips CLAUDE.md `@I`
"no LLVM · no C-transpile" from aspiration to achievement and makes the C-free path shippable as
default. THAT is the condition the goal requires.

## 1. Two fronts (the model from HEXA-CC-NATIVE.md)

```
 ① C-front (hand-authored .c)        │  ② BUILD-front (.c/.o/.a made DURING build)
 ─────────────────────              │  ─────────────────────
 ✅ CLOSED — HEXA-CC-ZERO 6/0        │  ⏳ THIS PLAN — HEXA-CC-NATIVE 3/5 open
 (transpiler hexa_cc.c git-rm,      │  default build still hexa→C→clang→.o→ld;
  warm-seed bootstrap)              │  native C-free path proven only for corpus
```

## 2. Current state (exhaustive — 전수조사 of 10 self-host domains)

| domain | done/open | role |
|---|---|---|
| HEXA-CC-ZERO | 6/0 ✅ | committed transpiler `.c` = 0 |
| SELFHOST-CI | 6/0 ✅ | gen2 byte-eq fixpoint (C-path) locked |
| C-ZERO | ✅ | ecosystem live-C → 0 (FFI shims retired) |
| RUNTIME-PORT | M3 open | runtime.c → hexa; irreducible floor ≈ 5.5k LOC measured |
| **HEXA-CC-NATIVE** | **3/5** | **build-front C = 0; THIS PLAN** |
| RUNTIME | 146/36 | broad native-compiler track |
| HEXA-SELFHOST+ | 0/6 | meta-domain (graduation) |
| SELFHOST-NEXT | 1/4 | post-fixpoint promotion |
| MISCOMPILE-ZERO | 6/4 | keep gen2 miscompile=0 |

HEXA-CC-NATIVE milestone ladder: **N0 ✅ · N1 ☐ · N2 (moot) · N3 ✅ · N4 ✅ · N5 ☐(in-progress) · N6 ☐ · N7 ☐**.

- N3/N4 CLOSED: `--backend=native --emit=obj` + `--linker=hexa` → executable, 0 clang/as/ld forks,
  `.c=0 .a=0`, exit 42 (verdicts `F-…-N3B-EXEC-LINK`, `F-…-N4-CHAIN`).
- N5 frontier = **native type-checker** chokes on the flattened 40k-line compiler.
  STEP0 MEASURED (2026-06-01, `F-…-N5PRE-STEP0-MEASURED`): a current-source `aprime_cc`
  emits **144** diagnostics on `compiler/main.hexa --emit=obj`. Falsifier PASS. Recipe ~15s.

## 3. The 144-diagnostic frontier (STEP0 measurement, tag-based)

```
144 total
├─ HX2001 ×80 (undefined name)
│  ├─ `as` ×61 + `)` ×7 ............ parser as-cast cascade  ─┐ STEP1 (~81, biggest lever)
│  │  (same root as HX0011 ×13) ...........................  ─┘
│  ├─ bytes_to_str_raw ×7 + __arr_alloc_items_zero(_int) ×2  ── STEP2 genuine-missing (~9)
│  └─ push ×2 (member-call) · i64 ×1 ...................... STEP2 tail
├─ HX3001 ×17 (HexaVal↔bool) ─┐
├─ HX3004 ×18 (return-type)   ├─ STEP3 HexaVal carrier-model gaps (types.hexa, ~51)
└─ HX2003 ×16 (not-callable) ─┘
```

## 4. Step ladder (COMPLETENESS-FIRST order)

| step | target | files | expected | gate |
|---|---|---|---|---|
| **STEP1** | parser brace-desync (HX0011 root; `as`/`)` are downstream) | `compiler/parse/parser.hexa` | 144 → ~63 | rebuild + re-measure |
| **STEP2** | genuine-missing intrinsics | `compiler/check/bind.hexa` allowlist + runtime SSOT | ~63 → ~51 | rebuild + re-measure |
| **STEP3** | HexaVal carrier typing | `compiler/check/types.hexa` | ~51 → ~0 | rebuild + re-measure |
| **N5** | self-host fixpoint | (none — verification) | gen2 ≡ gen3 byte-eq (darwin-arm64) | cmp=0 |
| **N6** | cross-arch | x86_64 runtime (N1) + linux build | per-arch byte-eq | cmp=0 ×2 |
| **N7** | CI gate | `.github/workflows/` | `.c/.o/.a=0` assert + fixpoint assert green (3-platform) | CI green |

**STEP1 finding (2026-06-10, static — refines the verdict's "as-cast cascade" framing):** the source
fully handles `as` — `compiler/lex/lexer.hexa:92` (`as`→`KwAs`) → `compiler/parse/parser.hexa:715`
(G10 postfix cast) → `compiler/check/types.hexa:1823` (`op=="as"`). And every REAL cast in the
compiler has a bare-Ident target (`as string`/`as f64`/`as i64`/`as int`/`as T`…); there are NO
complex-target casts (`as T?`/`as [T]`/`as T<X>`) that `parser.hexa:720 expect(Ident)` would reject.
So the `as`×61 + `)`×7 HX2001 are **downstream noise of an HX0011 brace-shape desync** (the recurring
`col 33-35` in `_evidence/n5pre-step0-measure-diag.txt`), NOT a missing as-cast rule. STEP1's true
target = pinpoint + fix that HX0011 brace construct in the native parser. Pinpointing needs the
reproduce loop (flatten `compiler/main.hexa` → `aprime_cc --emit=obj` → span-mapped HX0011) since the
flattened temp (`/tmp/cc-m2-flat.hexa`) is disposable and source line numbers drift.

## 5. Reproduce recipe (PROVEN ~15s — `F-…-N5PRE-STEP0-MEASURED`)

The bootstrap chain MUST be made current before each measurement (3 pieces):

1. **Transpiler**: `hexa cc` → rebuilds installed transpiler to `~/.hx/bin/self/native/hexa_v2`
   (lowers `__map_raw_len`, which the stale `self/native/hexat` cannot). Pass to `build_aprime.sh -v`.
2. **Runtime**: `hexa run self/runtime_core_emit.hexa <out>` regenerates `runtime_core.c` +
   `runtime_hi_gen.c` (supplies `float_to_bits`/`bits_to_float`). Copy `runtime.c` + `native/*.c` +
   `forge/*.c` **`.c`-ONLY** from `build/self` (never clobber `.hexa` sources).
3. **Compiler source**: clean worktree off current `origin/main`.

Then: `bash tool/build_aprime.sh -v <hexa_v2>` (guarded `nice -n 19`) →
`/tmp/aprime_fresh` Mach-O arm64, smoke `exit(6*7)==42` →
`aprime_fresh _drv.hexa --emit=obj --target=arm64-apple-darwin -o /tmp/x.o <flattened main>` →
count `HexaError [HX….]` tags.

**Falsifier (measurement-honesty gate, MUST pass every measurement)**: a source with an intentional
undefined name MUST emit `[HX2001] undefined name` + exit 1. If it doesn't, the measurement tool is
broken — STOP, do not trust the count.

## 6. GUIDANCE / runbook (안내 — read before executing any step)

```
[ edit step ] ──▶ [ rebuild aprime_cc ] ──▶ [ re-measure 144→N ] ──▶ [ verdict + flip if N drops ]
   local             POOL only                 falsifier-gated          g5/g63 verbatim
   read+edit         (summer/aiden/mini)        ~15s                     no green → no flip
```

- **WHERE rebuilds run**: aprime_cc rebuild is HEAVY. Run on **pool** (`sidecar pool on summer …`
  linux / `… aiden` linux / darwin = mini). **NEVER** an unguarded heavy build on the local Mac
  (kill-storm). Known recipe gaps (STEP0b verdicts): linux `build_aprime.sh` hardcodes
  `clang -arch arm64` (Mach-O only) + glibc `<malloc.h>` typedef clash + `hxlcl_*` Linux shim gaps;
  darwin needs the `.c`-ONLY runtime populate from §5 (a full `cp -R */` clobbers `.hexa` and breaks
  transpile). darwin-arm64 (mini) via the §5 recipe is the PROVEN measurement host.
- **HONESTY STOPs (g5/g63)**: do NOT flip a milestone without a green falsifier-gated re-measure +
  a verbatim verdict in `.verdicts/hexa-cc-native/`. Do NOT build a Frankenstein tree (generated `.c`
  clobbering sources). Do NOT guess-implement a runtime intrinsic — if a symbol is genuine-missing,
  add it to the runtime SSOT matching the codegen calling convention, or defer with a scoped note.
- **SESSION-AUTO (HEXA-CC-NATIVE @policy)**: within a work session, auto-adopt the ① 완성도 branch
  and loop STEP→STEP without asking, EXCEPT halt for (a) irreversible/external-publish/destructive
  actions, (b) main-integrity threats, (c) honesty (g5/g63) risk.
- **Default build stays C-path until N7 green** — the native C-free path ships as a parallel opt-in
  (`--backend=native --emit=obj --linker=hexa`) so release is never at risk mid-campaign.

## 7. Done-definition (the goal condition)

The user goal is met when: **N5 (gen2≡gen3 C-free byte-eq, darwin-arm64) + N6 (cross-arch) + N7 (CI
gate asserting `.c/.o/.a=0` + fixpoint, 3-platform) are all green and merged**, at which point
`hexa build` can default to the native C-free path and EVERY project builds with zero C intermediate.

## 8. Final reflection (record at the very end)

On campaign completion, reflect the achievement into **commons.tape** (governance SSOT — **sign-gated**;
needs `sidecar sign <key>` to unlock the agent edit) + the domain log + a persisted verdict. Until
then, this plan + per-step verdicts under `.verdicts/hexa-cc-native/` are the durable record.
