# FLIP-7 flip-D — BLOCKED (measured): `environ` UND survives in the MULTIOBJ ship-shape

**Verdict (#4656 CI, faithful-nobaseline linux-x86_64 + linux-arm64):** the S5.5 own-start nm-clean
ship gate (#4634) FATAL'd — doing its job:
```
[stage_resolve_runtime_a] RFC061 §M8 OWN-START nm-clean FATAL (MULTIOBJ ship shape): undefined
own-start symbols in the ld -r merge =[environ ] __dso_handle_undef=0 — the own-start flip would
link-die under -nostartfiles. atexit/environ must be own (_hxlcl_atexit_register #4409 /
_hxlcl_environ alias #4631); __dso_handle must be the weak-hidden def (#4410). Refusing to ship.
```

- **byteeq 3-target PASSED** — darwin byte-identical (the 2 added Linux guards on stage_resolve:46 +
  build_selfhost:163 are correct), linux re-converged. So the flip edits themselves are sound.
- **atexit + __dso_handle are clean** (own; #4409/#4410). ONLY `environ` is still undefined.

**Root cause (Fable's #4631 environ design PREDICTED this exact case):** the environ ELF alias
`_hxlcl_environ` + the shim `#define environ _hxlcl_environ` redirect (#4631) does NOT cover every
environ consumer in the HEXA_RT_MULTIOBJ=1 ship shape. Some merged member (candidate: runtime_core.o
from runtime_core.c, or cuda_host.o) still carries `U environ` under OWN_START=1 — Fable's design
note flagged: "nm -u build/runtime_core.o | grep -cw environ — if nonzero, runtime_core.o has its
own environ reads and needs the same redirect (separate finding, same pattern)."

**Named round (NOT tune-to-green):** find which MULTIOBJ member has `U environ` under OWN_START=1
(nm -u each of runtime.o/runtime_core.o/hxlcl_shim.o/cuda_host.o), and extend the environ redirect
(the `#ifdef HEXA_ZEROC_OWN_START / #define environ _hxlcl_environ` block) to that TU's emitter so
its environ reads bind the own cell. Then re-run flip D. The S5.5 gate is the pass criterion.

Also RED (likely downstream of the runtime.a build refusal, re-check after fix): try/catch setjmp
m12 (native lane), stdlib selftest (@ci_gate x86_64 — was flaky cloud-timeout before), @grace
consent trailers. The flip PR #4656 stays DRAFT.

## Parallel probe (mini, read-only) — narrows the culprit

- **runtime_core.o is NOT the culprit**: `grep environ self/runtime_core_emit.hexa` = 0 direct refs;
  it reads env via `hxlcl_getenv(...)` (the shim's getenv), an INDIRECT dependency → its .o carries
  `U hxlcl_getenv`, not `U environ`. So Fable's runtime_core.o hypothesis is falsified.
- environ literal refs live in: **hxlcl_shim_emit (28)**, **runtime_emit_full amalgam (19)**,
  **restore_frozen_seeds OP-19e (23)**.
- **Key asymmetry**: atexit is CLEAN but environ is UND in the SAME MULTIOBJ merge under the SAME
  `$_zc_own_def` define — so it is NOT a missing-`-D`-on-S4 problem (that would break atexit too).
  The `#define environ _hxlcl_environ` redirect (shim :114) must be STRUCTURALLY incomplete: an
  environ use positioned before the `#define`, or in a code path the macro doesn't cover, or the
  amalgam/OP-19e path emits a raw `extern char **environ;` + read that the alias doesn't satisfy.
  → Fable should focus on the shim :114 redirect ORDERING vs its environ uses (28), and the amalgam
  emitter's own environ handling — not runtime_core.o.
