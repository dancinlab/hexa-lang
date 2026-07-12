All facts are in hand — and two of your assumed blockers turn out to be already closed on origin/main (own-link perf #4851, bug3 dyn-hybrid #4871+#4866 merged). Here is the roadmap.

---

# axis-③ own-link default-flip roadmap

## 0 · Answer to the dyn-binary question first

The "dynamically linked, interpreter /lib64/ld-linux, **no section header**" binary is **own-link output**, not system ld. It's the Road-A dyn-hybrid serializer (`elf_x86_64.hexa:3548-3660`: 4 phdrs PT_INTERP·PT_LOAD R-X·PT_LOAD RW·PT_DYNAMIC, `e_shnum=0`, ET_EXEC -no-pie @0x400000). System ld always writes section headers — `e_shnum=0` is own-link's signature. This shape is *expected* while runtime.a's residual libc floor persists: 20 GLOB_DAT imports remain (`state/hexa-own/bug3_residual_libc_20.md` — stdio FILE* ×9, strtod/strtol/strtoll, mmap/munmap, gmtime_r, ptsname_r/cfmakeraw, abort/_exit/__stack_chk_fail), so `n_dyn>0` → dyn serializer. `n_dyn==0` auto-reverts to pure static own-start (convergent by design). Static-floor closure tracks RFC061 runtime.c→0 — **orthogonal to this flip**, don't couple them.

## 1 · Gap census — own-link (`--linker=hexa`, linux-x86_64) vs system ld on the default leg

**DONE (all merged on origin/main):**
| capability | evidence |
|---|---|
| static own-start ET_EXEC, in-process, 0 execve | `link_elf_x86_64_ownstart_ar` `elf_x86_64.hexa:3101` (#4711–18) |
| archive extraction incl. STB_LOCAL floor-pull (n_dyn 39→20) | #4871 `f0810d165` **MERGED** |
| dyn-hybrid rc0: CRT1-HANDOFF entry + R_X86_64_COPY lane (stdout/stderr STT_OBJECT) + GLOB_DAT/6B-stub 3-way census | #4871 3-fix stack, LIVE_VERDICT=PASS on aiden |
| link perf — O(relocs×defs) wall | **FIXED** #4851 `adb39cbba` 1024-bucket def-index, full-binary link >90min→106s |
| output +x (silent zig-cc fallback killed) | #4866 `c9af152d3` |
| determinism (emit×2 + link×2 byte-identical + own-vs-own run) | `tool/ownlink_determinism_gate`, CI job `ownlink-determinism-x86_64` (nobaseline-gate.yml:1000) — GREEN but **advisory** |
| environ on own-start | #4868 |
| boxed-reader packed-tag discrimination (BUG-B) | #4873 — **in flight, the only unmerged dep** |

**WALL / open (what blocks the flip):**
1. **DT_INIT_ARRAY on the dyn path** — bug3 doc names it explicitly: runtime `.init_array` ctors are collected on the static path (`:1740/:1745`) but **미배선 in the dyn serializer**. A runtime.a member with a ctor silently skips init. Must close in PR-1.
2. **Corpus breadth = the biggest risk.** Own-link is proven on fixtures (`rt_pull.hexa`, CROSS_OK, the struct-of-arrays repro) — the default leg serves *every* user program. The bug3 class (mixed hxlcl/libc stdio lane, exit-flush teardown) was found only because one fixture exercised it; other libc-surface combos (pthread on the game-thread corpus, atexit, tty) are unaudited. And a **mislinked-but-executable** binary does NOT trigger the fall-through safety net — link "success" with wrong runtime behavior is the silent failure mode. The flip's evidence gate must be **run-parity** (own-link binary vs ld binary: stdout+rc equal) across the 361-corpus, not link-success.
3. pthread: leg-B links `-lpthread`; own-link dyn-routes pthread_* UNDs to DT_NEEDED `libc.so.6` — fine on glibc≥2.34 (NPTL merged), wrong on older glibc. Put thread programs in the parity corpus; document glibc≥2.34 floor.
4. `e_shnum=0` on the dyn path — nm/objdump/gdb degraded vs ld output. DX regression on shipped `hexa build` artifacts. Accept+document for PR-2, or add optional shdr emission later; not a flip blocker.
5. **arm64-linux: no own ELF linker at all** (`compiler/main.hexa:~1310` warns + falls back to system ld). Tier-B's host gate includes `Linuxaarch64` — the flip must be scoped `Linuxx86_64` inside the block. PR-3b.
6. darwin arm64: Mach-O `tool/hexa_ld.hexa` exists (track-2, `HEXA_LD`, external exec) — PR-3a.
7. `.so`/ET_DYN writer absent (RFC070 draft) — **not a blocker**: leg gate already excludes `shared=="1"`.

## 2 · The flip ladder

**PR-1 — opt-in route + evidence infra (branch off post-#4873 main)**
- **Insert the own-link leg** immediately before tier-B, i.e. between `self/main.hexa:3584` and `:3585`, mirroring the tier-C block shape (`:3655-3672`) but host-gated instead of target-gated:
  ```
  gate = env_var("HEXA_OWNLINK_DEFAULT") == "1" && uname=="Linuxx86_64"
         && shared!="1" && c_only!="1" && len(target)==0 && len(__actual_src)>0
  cmd  = HEXA_PREBUILT_RUNTIME=<resolve_prebuilt_runtime()> <resolve_native_cc()>
         _drv.hexa --backend=native --emit=exec --linker=hexa
         --target=x86_64-linux-gnu -o <tmp> <__actual_src>
  ```
  success → `mv` + `return ""`; any failure → fall through to tier-B `:3585` **unchanged** (ld → C-transpile net intact). `__actual_src` is already flattened here — tier-C uses it directly with `--emit=exec`, so no new flatten plumbing.
- **cmd_run**: extend the existing gate at `:4680` to `env("HEXA_LINK_HEXA")=="1" || env("HEXA_OWNLINK_DEFAULT")=="1"` (the block body at `:4681-4700` is already exactly this leg).
- **DT_INIT_ARRAY**: wire `.init_array` collection into the dyn serializer in `elf_x86_64.hexa` (emit `DT_INIT_ARRAY`/`DT_INIT_ARRAYSZ` when collected ctors > 0 and n_dyn>0), + a ctor fixture in `self/test/ownlink_determinism/`.
- **New CI job `ownlink-corpus-parity-x86_64`** (advisory, nobaseline-gate.yml, next to `:1000`): for each corpus program (reuse the flatten-faithful 361-corpus set), build twice — `HEXA_OWNLINK_DEFAULT=1` and default (ld) — run both, assert stdout+rc identical. This is the flip's promotion evidence.
- Byte-neutral OFF → merges on regular PR-CI green.

**PR-2 — the flip (default-ON, opt-out)**
- Two-line polarity change: `== "1"` → `!= "0"` for `HEXA_OWNLINK_DEFAULT` at the two PR-1 sites (cmd_build new block, cmd_run `:4680`).
- Same change promotes CI wiring: add `ownlink-determinism-x86_64` + `ownlink-corpus-parity-x86_64` into the required `selfhost-gates-summary` set (both must be *measured green* first, per CLAUDE.md — check the soak history before this PR).
- **Merge gate (all GREEN before merge):** ① selfhost-byteeq 3-target (gen3≡gen4 unaffected — the determinism gate's transitivity argument: .o byteeq ∘ deterministic link) ② `ownlink-determinism-x86_64` required ③ `ownlink-corpus-parity-x86_64` required ④ miscompile-zero + selfhost-codegen-guard (ENCODE-MISS=0, unchanged) ⑤ shipping smoke + **install.sh consumer smoke** (fresh-install `hexa build` output runs — catches stale-runtime.a interaction, the #4638 class) ⑥ pool builds on ghost/aiden/summer. Fall-through stays intact (own-link fail → ld → C) so release integrity holds even post-flip.
- Note in the PR body: shipped binary bytes change (own-link ≠ ld output) — allowed; it's not a byteeq-fixpoint surface. Document glibc≥2.34 + `e_shnum=0`.

**PR-3 — parity legs (post-flip, independent)**
- **3a darwin arm64**: wire `--linker=hexa` (already routed in `compiler/main.hexa` for `arm64-apple-darwin` via `HEXA_LD` → `tool/hexa_ld.hexa` Mach-O) into the darwin leg-B branch (`self/main.hexa:~3603-3620`), opt-in first, same ladder. Low urgency — the darwin leg itself is opt-in (`HEXA_NATIVE_DARWIN=1`).
- **3b arm64-linux**: requires a new aarch64 ELF own-linker (reloc resolver for AARCH64_CALL26/ADR_PREL/etc. + own-start). This is a campaign, not a PR — do NOT block anything on it; tier-B arm64 keeps `ld`.

## 3 · axis-① unlock (hexa_cc.c delegate removal)

The delegate fall-through is everything from `self/main.hexa:3677` (`let v2 = resolve_or_bootstrap_hexat()`) down in cmd_build, plus the clang fallback in cmd_run, with `resolve_or_bootstrap_hexat` itself at `:2664` (other call sites `:2131`, `:2255`). Removal condition — three legs, all measured:

1. **ENCODE-MISS==0 corpus-wide**: already gated — `miscompile-zero-gate` (corpus `--emit=obj`) + `selfhost-codegen-guard` CORPUS-1 (full self-emit). Keep required.
2. **C-fallback-count==0 census** (the new gate to build): a `cfallback-zero` CI job that builds the full corpus + stdlib tests on each default leg with `HEXA_RUN_NATIVE_TRACE=1` and asserts **zero** "→ C fallback" trace lines. ENCODE-MISS=0 alone is insufficient — fall-through also fires on runtime.a resolution misses, flatten failures, and link errors; the census catches all of them.
3. **All-3-target native legs default-ON**: axis-① needs native-*EMIT* everywhere (the delegate is the C-transpile, not ld) — linux-x86_64 ✅(post-PR-2, fully clang-0+binutils-0), arm64-linux ✅ today via emit=obj+ld (own-link not required), darwin ❌ opt-in `HEXA_NATIVE_DARWIN=1` — must flip default-ON first.

Plus scope honesty: `shared=="1"` (.so), `--c-only`, and non-x86_64-linux cross targets still route through hexat/C today. Realistic axis-① = **delete the cmd_build/cmd_run default-leg fall-through** at `:3677`+ once 1–3 hold (delegate stays reachable only from `--c-only`/shared/cross); *full* `hexa_cc.c` deletion additionally needs RFC070 native .so emit. Sequence it as: cfallback-zero advisory → measured 0 over N weeks → delete fall-through → retire `resolve_or_bootstrap_hexat` per remaining call site.

## 4 · Sequencing

`#4873 (BUG-B)` → **PR-1** (branch off post-#4873 main — confirmed; #4871/#4866 are already in, no other unmerged deps) → opt-in soak on the pool + advisory gates accumulating green → **PR-2** flip → **PR-3a/3b** in parallel with the axis-① `cfallback-zero` census → delegate fall-through deletion. One ordering caution: promote `ownlink-determinism-x86_64` and the parity job into `selfhost-gates-summary` only in PR-2 *after* their soak history is green — never wire an unmeasured job into the required gate (CLAUDE.md CI rule).

Biggest single risk, named: **silent run-behavior divergence on the dyn-hybrid path across the full corpus** (bug3-class: link succeeds, teardown/ctor/stdio wrong at runtime — the fall-through can't save you). The `ownlink-corpus-parity` gate in PR-1 is the direct counter; DT_INIT_ARRAY is the one known-open instance of the class — close it in the same PR.
