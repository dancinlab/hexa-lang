# ③ axis-round-6 self-emit COMPLETION measurement — VERDICT: WALL NOT CLEARED (unmeasurable — flag-ON build is a compiler-breaking regression)

**Date:** 2026-07-09/10 · **Measured on:** RunPod pod `bkvx5lsz779km4` (x86_64-linux, Ubuntu 22.04, clang-14, 1007 GB RAM / 4 cores; heavily oversubscribed shared host, load avg ~216 — but zero OOM pressure). **Repo:** origin/main `74a99970` (#4804 tip; carries the pack commits #4790 `700e53e5`, #4800 `8c8b997d`, #4801 `546c163d`). **Pod torn down + confirmed GONE.**

## TL;DR
The DONE metric (native own-emit `--emit=obj --backend=native --target=x86_64-linux-gnu` over the 52-file / 68,260-line compiler closure reaches the `x86_serialize` mark + emits a `.o` + exit 0) is **NOT ACHIEVED and CANNOT be measured as-is** — because building `aprime_cc` with `HEXA_SELFEMIT_PACK_OUT=1` produces a **self-broken compiler** that cannot compile ANY input. The pack-out fix (#4800/#4801), as integrated, is a **regression**: it miscompiles the compiler's own frontend.

- `x86_serialize` CG_PROFILE mark: **DID NOT PRINT.** The ON self-emit probe crashes after only `front_begin` — it never reached even `lex`.
- This is **NOT an OOM/infra kill** (peak RSS 632 MB, 1 TB free) and **NOT the serialize RSS wall** (never reached codegen). It is a **real frontend miscompile** caused by the fix.

## Evidence

### A) flag-ON `aprime_cc` build — stage-5 smoke FAILS
Built via `HEXA_SELFEMIT_PACK_OUT=1 bash tool/build_aprime.sh` (clean stage-0: runtime.a + hexat seed-converge FIXPOINT after 2 passes → hexat reflects current `self/codegen.hexa`; stage-1 flatten = 52 files/68,260 lines; stage-2 transpile = 71,952 lines C; stage-4 clang built `build/aprime_cc` = 3,423,008 B). Then the **built-in stage-5 smoke** (`fn main(){ let x = 6*7; exit(x) }`) FAILS:

```
HexaError [HX1101] /tmp/smk.hexa:1:1-3   unbound identifier `{name}` in lower (no binding visible from this scope)
HexaError [HX1101] /tmp/smk.hexa:2:3-6   unbound identifier `{name}` in lower ...
HexaError [HX1101] /tmp/smk.hexa:3:8-9   unbound identifier `{name}` in lower ...
hexa-compiler: 3 HIR->MIR diagnostic(s); aborting before codegen
build rc=2  (smoke FAIL — expected exit 42)
```
Every identifier (`main`, `x`, `exit`) is reported unbound; the diagnostic template `{name}` is even left uninterpolated — the compiler's binder/scope + string handling are corrupted.

### B) flag-ON native self-emit probe (the actual DONE-metric invocation) — SIGSEGV in the frontend
`HEXA_CG_PROFILE=1 HEXA_SELFEMIT_PACK_OUT=1 build/aprime_cc --emit=obj --backend=native --target=x86_64-linux-gnu --verbose /root/self_flat.hexa -o /tmp/self.o`

```
CG_PROFILE  phase=front_begin        delta_ms=0
[hexa-runtime/phase] pipeline_start rss=9MB arena_live=0KB arena_total=0KB
Command terminated by signal 11            <-- SIGSEGV
  Maximum resident set size (kbytes): 647176   (~632 MB)
  Elapsed (wall clock) time: 0:08.60
  User time: 7.97s  (98% CPU)
on probe rc=139   (128+SIGSEGV)
/tmp/self.o: does not exist
```
- **Marks reached:** `front_begin` only. NOT `lex`, `parse`, `bind`, `type_check`, `unit_check`, `lower_ast_to_hir`, `codegen`, `x86_pack_lir`, or **`x86_serialize`**.
- **Peak RSS at crash: 632 MB** — nowhere near the 6.82 GB "fixed" figure or the 19 GB "unfixed" wall. The crash is unrelated to serialize RSS; it dies in the frontend (lex/parse of the 68 k-line source) via the same flag-induced corruption that produced the HX1101 storm on trivial input. (On trivial input it aborts cleanly with diagnostics; on the large self-source it SIGSEGVs.)

### C) OFF-path control (clean rebuild, `HEXA_SELFEMIT_PACK_OUT` UNSET) — smoke PASSES
Same host, same clang-14, forced clean stage-0 (`rm build/hexat self/runtime.c`; hexat seed-converge FIXPOINT 2 passes), flag unset:
```
[4/5] clang: build/aprime_off (3,418,576 B)
[5/5] smoke: exit(42)==42 PASS — aprime_cc OK
off build rc=0
```
→ The OFF-path compiler compiles trivial code correctly. **This isolates the flag as the sole regression** (same toolchain/host/clang; the only difference is `HEXA_SELFEMIT_PACK_OUT`). (The OFF self-emit did not run — the ON driver aborted at its smoke before generating the flat, so the OFF driver hit a missing-input error; not needed — the smoke PASS is the decisive isolation.)

## Root cause (source-pinned)
`self/codegen.hexa:3356-3374` (introduced by #4800/#4801) — under the flag, the gen2 C-transpile backend registers **every** `[Int]`/`[i64]`/`[int]`-typed **parameter** of every function as a pack-out handle, then routes all `.push/.len/index-get/index-set` on those names through `hexa_arr_poly_*` assuming a TAG_ARRAY_I64:
```
if _selfemit_pack_out_enabled() {
    while _ppi < len(_gen2_current_fn_param_types) {
        let _pty = _gen2_current_fn_param_types[_ppi]
        if _pty == "[Int]" || _pty == "[i64]" || _pty == "[int]" {
            _selfemit_pack_out_add(_gen2_current_fn_params[_ppi])   // ALL [Int] params
        }
        _ppi = _ppi + 1
    }
}
```
The in-source comment claims: *"SOUND for a BOXED [Int] arg too: the poly readers branch on the tag and delegate to the boxed path for TAG_ARRAY … identical output for a non-packed arg."* **That soundness claim is empirically FALSIFIED** — the compiler is riddled with `[Int]`-typed params in its binder/scope/lexer machinery (receiving ordinary boxed HexaArr), and routing them through the poly readers corrupts them → HX1101 unbound-identifier on all names (trivial input) / SIGSEGV (large input). #4790 (per-fn label bucket) is orthogonal and not implicated.

## Verdict (per verdict-integrity: OOM vs codegen-wall distinction)
- **Serialize wall (`out:[Int]` 19 GB blowup) CLEARED? UNRESOLVED / unmeasurable.** The probe never reaches serialize (or even lex), so whether the packed serialize buffer would complete at 6.82 GB is untested with a working compiler.
- **Not OOM/infra:** crashes at 632 MB with ~1 TB free; SIGSEGV, not an earlyoom/OOM-killer signal.
- **Real regression:** `HEXA_SELFEMIT_PACK_OUT=1` miscompiles the compiler frontend. The RSS-drop 19 GB→6.82 GB previously "confirmed on aiden" must have been observed some other way (e.g. an isolated serialize microbench or an older/narrower flag state) — it is **not reproducible via a full flag-ON `aprime_cc` self-emit**, because that compiler cannot run.

## Next round (implementation, NOT this measurement task)
The fix must **narrow** the pack-out registration from "all `[Int]` params" to only the serialize buffer's genuinely-escaping accumulator lineage (the `out` return/append chain), OR make `hexa_arr_poly_*` truly tag-safe for boxed HexaArr args (the current soundness assumption is false in practice). Until then the ③ round-6 completion measurement is blocked. Re-measure after a corrected flag on a stable x86_64-linux host (aiden/summer when free, or a fresh pod) with the same probe.

## Reproduction notes
- Pod build was fully self-contained from a public `git clone -b main` + `apt-get install -y clang time`; **no pod-side deadlock** — the feared hexat-from-clang bootstrap completed in ~3–4 min (seed-converge FIXPOINT in 2 passes) with no `~/.hx` CUDA present. aiden's prebuilt hexat (@ #4798) was NOT usable: it predates #4800/#4801 so cannot emit the packed lowering — a fresh origin/main hexat is required.
- Probe flat self-source = exact `build_aprime.sh` stage-1 flatten (walk `compiler/main.hexa` import/use closure, stub `embedded.gen.hexa` ATLAS_* to empty) = 52 files, 68,260 lines.
