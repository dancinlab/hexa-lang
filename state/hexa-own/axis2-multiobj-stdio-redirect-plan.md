All questions are resolved. Here's the decision.

# Verdict: **B** (family redirect in the MULTIOBJ TU), landed as a 2-PR ladder (default-OFF → measured flip). Not A, not C.

## (1) Is B safe? YES — with one mandatory shape: the stdio family swaps **atomically**, not print-only

**The oracle proving safety already ships.** The single-TU amalgam routes runtime_core.c's *exact same call sites* through the hxlcl_* stdio family today — the macro block at `self/runtime_emit_full.hexa:2897–2926` (`printf/fprintf/fputs/fputc/fflush/putchar/perror/snprintf/sprintf/fopen/fclose/fread/fwrite/ftell/fseek/fdopen/fileno/setvbuf`). Every format string in runtime_core.c (`%lld`, `%s`, `%d`, `%.1f`, OOM literals, `[OOB] %s`, the 16-arg `%lld` ALLOC_STATS line) is already exercised through `hxlcl_vsnprintf` (`runtime_emit_full.hexa:838` — handles `%d/%u/%lld/%s/%%` + a real `%f/%g/%e` with precision) in the single-TU lane. B creates zero new format demands; it applies a proven redirect to the same code. `fprintf(stderr, …)` is fully handled: `hxlcl_fprintf` (`:1146`) resolves the stream via `_hxlcl_fp_fd` (`:1328`), which pointer-compares real glibc `stdout`/`stderr`/`stdin` → fd 1/2/0.

**Does anything need real glibc FILE*?** No. runtime_core.c's only non-std FILE* uses are the fuel_abort log (`fopen`'d, then `fwrite`+`fflush` — emitter lines 674–678) and the pipe/`fileno` path — both run on the amalgam's fake-FILE* model (`(void*)(fd+1)`) in the single-TU ship today. In MULTIOBJ each TU is a coherent island (runtime.o = fake model, runtime_core.o = glibc model); B moves runtime_core.o onto the same fake model as runtime.o, which makes cross-TU FILE* passing *safer* than today, not riskier.

**The two real landmines (both avoidable by design, and both live in "B-lite" variants):**
1. **No partial redirect.** Redirecting only `printf/fflush` while leaving `fopen/fwrite` on glibc breaks fuel_abort: `fflush(f)` becomes the no-op `hxlcl_fflush` (`runtime_emit_full.hexa:1165`) on a *real buffered* FILE*, then abort → log lost. Conversely, redirecting `fwrite` without `fopen` feeds a real FILE* into `_hxlcl_fp_fd` → −1 → silent write drop. Copy the amalgam's stdio subset **verbatim, as one block**.
2. **The shim's existing `hxlcl_fopen`/`hxlcl_fread` are real-glibc wrappers** (`runtime_core_hxlcl_shim_emit.hexa` emitter lines 1344/1347: `return (void*)fopen(p,m)`). They must be replaced with 1:1 ports of the amalgam's fake-fd bodies, or the family is incoherent. Verify with `nm` that runtime_core.o is their only consumer (it is, per the sysheaders contract).

**Wrong/incomplete assumptions in the prompt — flag:**
- `runtime_core_sysheaders.h` declares **no** print-family prototypes (no `hxlcl_printf/fprintf/fputs/fflush/fwrite/putchar/snprintf`) and the shim defines none of them. B is not "add #defines" — it needs new external-linkage shim bodies + prototypes. Bigger than stated, still mechanical (bodies are verbatim ports).
- The measured "×4" UND set is almost certainly **incomplete**: `$_zeroc_nobuiltin` (`stage_resolve_runtime_a:1214`) disables only mem/str builtins, so clang's printf-lowering is active — the U `fputs`/`fwrite` are lowered no-arg `fprintf(stderr,"lit")` sites; but arg-ful sites (`map key '%s' not found`, ALLOC_STATS, OOB) **cannot lower** and should leave U `fprintf` (plus likely U `snprintf`/`fopen`/`fclose`) in runtime_core.o. Re-run `nm -u` on the .o; B's family block covers them all anyway.
- The sysheaders header comment ("force-included ONLY under HEXA_ZEROC_RTCORE_SHIM_TU, default OFF, DEFAULT build never sees it") is **stale** — it is force-included in the default MULTIOBJ ship compile at `tool/stage_resolve_runtime_a:3184`. That staleness is arguably why this bug shipped; fix the comment in the same PR.

## (2) Byteeq class — B is the cleaner flip

- **A** (flip `HEXA_ZEROC_EXIT_FLUSH` ON): bit-changing in the **amalgam** (`hxlcl_exit`) → touches both single-TU and MULTIOBJ lanes, all 3 targets. And it permanently re-pins U `fflush` (its flush must call real glibc fflush, since the amalgam macro-no-ops `fflush`) — a standing axis-② regression.
- **B**: bit-changing **only in the MULTIOBJ lane** (sysheaders.h + shim emitter are S3/S4-only inputs; `runtime_emit_full.hexa` untouched → single-TU runtime.a byte-identical, dev/byteeq lanes see zero diff). One lane, one flip, and it converges MULTIOBJ ship semantics onto the already-canonical single-TU behavior — polarity-correct (native-canonical default).

## (3) Ranked recommendation

**1st — B, as a 2-PR ladder** (matches the repo's flip discipline):

*PR-1 (default-OFF, byte-neutral):*
- `self/runtime_core_sysheaders.h` — add (a) prototypes for `hxlcl_vsnprintf/snprintf/sprintf/printf/fprintf/fputs/fputc/fflush/putchar/perror/fwrite/fclose/fdopen/setvbuf` + `_hxlcl_fp_fd` next to the existing block (~:63–115); (b) after the mem-leaf block (~:140), the stdio redirect block copied verbatim from `runtime_emit_full.hexa:2897–2926` (stdio subset incl. `fileno→_hxlcl_fp_fd`), guarded `#ifdef HEXA_RT_STDIO_NATIVE`.
- `self/runtime_core_hxlcl_shim_emit.hexa` — add external-linkage 1:1 ports of the amalgam bodies (`runtime_emit_full.hexa:838–1180` print/format family + `1293–1400` fopen/fclose/`_hxlcl_fp_fd`/fread/fwrite/ftell/fseek/fdopen/setvbuf), **replacing** the real-glibc `hxlcl_fopen`/`hxlcl_fread` wrappers (emitter lines 1344/1347) under the same gate.
- `tool/stage_resolve_runtime_a:3184/:3197` — plumb the env→`-DHEXA_RT_STDIO_NATIVE` define into S3+S4 (mirror the `$_mo_rtcore_def` pattern).

*PR-2 (the flip):* make `HEXA_RT_STDIO_NATIVE` default-ON in stage_resolve (keep `HEXA_RT_STDIO_LIBC`-style opt-out, mirroring the `HEXA_RT_MEM_LIBC` precedent), after the soak gate below.

*Soak gate for the flip:* byteeq 3-target PR-CI GREEN (single-TU lane must be byte-identical — a diff there means the edit leaked out of the MULTIOBJ lane) · `nm -u` on MULTIOBJ runtime.a asserting `printf/fprintf/fputs/fwrite/fflush/snprintf/fopen/fclose` all dropped (nobaseline-gate advisory dump is the venue) · `release_build` + install.sh consumer smoke on the pool (the `fileno`/exec startup path is the known killer — the `:2926` comment documents the SIGSEGV class) · the own-start repro as a permanent smoke: own-start ON, `println`+`exit(0)`, stdout→pipe, assert non-empty, **plus a mid-run SIGABRT variant** (B keeps output, A can't — this is the differentiating test) · fuel_abort file-log smoke (fopen'd-FILE* write survives the family swap).

**2nd — A as fallback only** if implementation surfaces a real landmine (e.g. an unexpected external consumer of the shim's real-glibc `hxlcl_fopen`). It's validated and small, but it's a symptom patch: clean-exit-only, leaves the ship lane glibc-buffered, and moves axis-② backward.

**Not C:** under B there is no runtime-owned buffered stream left to flush — flipping #4852 ON adds nothing for the runtime while permanently re-adding U `fflush` to the archive. Keep #4852 as the landed default-OFF escape hatch for exotic user-FFI glibc-buffered streams.
