# done-axis-next-rounds plans (clean ref 53ee90270·conv-1·verify-corrected)

{
  "summary": "Scope the next measurement-independent DONE-criterion rounds (axis-② runtime.c libc-UND flip, axis-③ own x86_64/ELF emit+linker first step, + refresh the current libc-UND floor census) from a clean origin/main worktree",
  "agentCount": 6,
  "logs": [],
  "result": {
    "ref_sha": "53ee90270",
    "scoped": 3,
    "axes": [
      {
        "axis": "② no runtime.c — next byte-neutral libc-UND-drop round (nm-UND floor mop-up)",
        "head_confirmed": "53ee90270",
        "ready": false,
        "risk": "low",
        "plan_holds": false,
        "confidence": "high",
        "corrections": [
          "HEAD confirmed 53ee90270. The residual IDENTIFICATION is correct and well-supported: the 7 raw strcmp(key,...) caller sites all exist verbatim at HEAD (runtime_emit.hexa:1052/1053/1057, runtime_emit_full.hexa:5622/5623/5627, runtime_core_emit.hexa:4253), and SSOT line 162 (2026-07-06 reconcile, CI run 28745095773) independently names non-shim strcmp callers as '정직한 다음 타깃 ... non-shim strcmp caller 소멸 = codegen 라운드, seed-flip 아님', with floor 231 total / 54 reducible. Direction and reducibility are right.",
          "LEVER MECHANISM IS WRONG (disqualifying). The plan asserts 'rt_strcmp is already in scope in all three (defined runtime_core_emit.hexa:781, prototyped in runtime_core.h emit)'. FALSE: grep shows rt_strcmp is emitted at EXACTLY ONE place (runtime_core_emit.hexa:781, a DEFINITION), there is NO prototype emit line anywhere, and that sole def is gated `#ifdef HEXA_ZEROC_RT_CORE_STRCMP_DELEGATE` (default OFF). So (a) rt_strcmp does not exist in the default build at all, and (b) it is neither defined nor declared in runtime_emit.hexa (runtime.c TU) or runtime_emit_full.hexa (amalgam TU). Flipping a caller-only gate to emit `rt_strcmp(` in those two TUs yields an implicit-decl/undefined symbol — either a link break or rt_strcmp becomes a NEW nm-UND, defeating the drop. The 'one-token swap, already in scope' claim does not hold; the ON path as written won't apply. A working lever must either make rt_strcmp unconditional + add a shared prototype + couple the new caller gate to HEXA_ZEROC_RT_CORE_STRCMP_DELEGATE, OR (more naturally) redirect the callers to hxlcl_strcmp, the shim symbol that IS in cross-TU scope and already native-capable.",
          "CITED PR #4651 is fictitious. Plan: 'strtod = #4651 default-ON (this session)'. The strtod-tail native gate is default-ON at stage_resolve_runtime_a:707 but the PRs of record are #4639/#4645/#4646 (cited in the gate comment). The DAG independently flags 'I found no in-tree #4651'. Substance (strtod default-ON) is correct; the PR number is wrong.",
          "SANCTIONED/REDUCIBLE CONFLATION in the premise list. Plan bundles '__libc_start_main = FLIP-7 own-start #4656' among candidates 'ALREADY default-ON' being dropped. __libc_start_main is the IRREDUCIBLE CRT M8 seed (#3959), an explicitly SANCTIONED terminal floor per SSOT:141 ('__libc_start_main = irreducible seed') and SSOT:162's terminal set — not a reducible FLIP-7 drop. FLIP-7 covers atexit+environ only (SSOT:141: 'atexit·environ·__libc_calloc·__libc_free 는 여기 아님 — FLIP-7'). Also FLIP-7 flip-D own-start (commit e26552002/#4656) is marked bit-changing DRAFT, not a settled default.",
          "MINOR (non-disqualifying) macro-polarity imprecision in the premise list, though line numbers are correct: qsort gate at runtime_core_emit.hexa:7262 is `#if !defined(HEXA_RT_ARRAY_SORT_NATIVE_OFF)` (opt-OUT), not 'HEXA_RT_ARRAY_SORT_NATIVE'; glob at runtime_emit_full.hexa:12994 is `__linux__ && (HEXA_RT_GLOB_NATIVE || !HEXA_RT_GLOB_NATIVE_OFF)`; fgets fallback at runtime_core_emit.hexa:7655 keys on `!HEXA_RT_STREAM_NATIVE_READ && (!__linux__ || HEXA_RT_STREAM_NATIVE_READ_OFF)`. All are default-ON on linux (substance correct). Separately, the strcmp shim native gate (stage_resolve_runtime_a:1879) is TRI-STATE defaulting to 'auto', not a hard '1' — on a missing/bad seed it falls back to the libc-shim strcmp with a WARN, so the plan slightly overstates 'shim already went native default-ON'.",
          "NET: analysis, wall section, gate section, and residual identification are sound and well-cited, but the single concrete round-1 lever rests on a false claim about rt_strcmp's scope/prototype/default-availability, so it would not apply as written — plan_holds=false. Fix is small (retarget to hxlcl_strcmp or make rt_strcmp unconditional+prototyped+gate-coupled), and the strcmp-caller-drop remains the correct next reducible target."
        ],
        "residual": [
          "PREMISE CORRECTION (load-bearing): every candidate the task lists to weigh is ALREADY default-ON — the 15U WALL set is stale, predating the 2026-07-03 flip batch. Confirmed at HEAD 53ee90270 in the emitters: fgets = HEXA_RT_STREAM_NATIVE_READ default-ON linux (#4450, self/runtime_core_emit.hexa:7655); qsort = HEXA_RT_ARRAY_SORT_NATIVE default-ON (#4452, runtime_core_emit.hexa:7262, stable native merge-sort); glob/globfree = HEXA_RT_GLOB_NATIVE default-ON linux (#4449, self/runtime_emit_full.hexa:12994); regcomp/regexec/regfree = HEXA_REGEX_NATIVE default-ON (regex_rt seed resolver, tool/stage_resolve_runtime_a:762 `${HEXA_REGEX_NATIVE:-1}`); strtod = #4651 default-ON (this session); atexit/environ/__libc_start_main = FLIP-7 own-start #4656 (this session).",
          "AUTHORITATIVE current floor (07-06 SSOT reconcile, state/zeroc-29-floor-to-zero-endgame-ssot-2026-07-03.md:162, CI run 28745095773): nm-UND 231 total / 54 reducible (honest-libc ~51). SSOT line 45 states explicitly: 'un-levered reducible libc nm-UND leaf = 0' — the seed-flip surface is EXHAUSTED. No un-flipped seed family remains to pick.",
          "THE ONE remaining non-sanctioned reducible leaf = strcmp non-shim callers (SSOT:162 names it verbatim as '정직한 다음 타깃'). strcmp's shim edge already went native (#4591/#4602, hxlcl_strcmp word-scan; self/runtime_core_hxlcl_shim_emit.hexa:464 is the delegate def, not a residual), but ~7 RAW `strcmp(key, ...)` callers in the range/slice field-access body (hexa_range_field) keep strcmp in the union nm-UND: self/runtime_emit.hexa:1052/1053/1057, self/runtime_emit_full.hexa:5622/5623/5627, self/runtime_core_emit.hexa:4253 (all `strcmp(key,\"len\"|\"start\"|\"end\")`).",
          "Native replacement ALREADY EXISTS: rt_strcmp (byte-loop, self/runtime_core_emit.hexa:781-786), currently gated only on the DEFINITION side by HEXA_ZEROC_RT_CORE_STRCMP_DELEGATE — there is NO caller-side gate yet (verified: no HEXA_RT_*_STRCMP caller macro in emitters). No strcmp-caller commit landed between the 07-06 reconcile (13c1a35b9) and HEAD, so the residual persists at 53ee90270."
        ],
        "round1": [
          "LEVER: redirect the ~7 raw `strcmp(key,...)` caller sites in hexa_range_field to the existing native rt_strcmp, behind a NEW default-OFF caller gate (e.g. -DHEXA_RT_CORE_STRCMP_CALLER_NATIVE), mirroring the established hxlcl_* #ifdef redirect pattern (same shape as the existing HEXA_ZEROC_RT_CORE_STRCMP_DELEGATE def-gate). OFF = emit `strcmp(` verbatim → runtime.a byte-identical (byte-neutral); ON = emit `rt_strcmp(`.",
          "EXACT EDIT SITES (3 canonical runtime.a emitter TUs): self/runtime_emit.hexa:1052,1053,1057 · self/runtime_emit_full.hexa:5622,5623,5627 · self/runtime_core_emit.hexa:4253. Each is a one-token `strcmp`→`rt_strcmp` swap inside the emitted-C string literal, guarded by the new caller macro. rt_strcmp is already in scope in all three (defined runtime_core_emit.hexa:781, prototyped in runtime_core.h emit).",
          "MEASUREMENT: on aiden/summer rebuild runtime.a with the caller macro ON, then `nm -u build/runtime.a | grep -w strcmp` must go empty (faithful-nobaseline harness, .github/workflows/nobaseline-gate.yml advisory dump). Capture before/after floor count (expect 231→230, one class drop). OFF path must show runtime.a byte-identical (byte-neutral confirmation)."
        ],
        "gate": [
          "byteeq 3-target GREEN (x86_64-linux + arm64-linux + darwin-arm64) — this is a RECONVERGE flip: runtime.a bytes change but gen3≡gen4 is structurally unaffected (build_selfhost.sh uses a flag-free rt.o), run per protocol.",
          "faithful nm-DROP capture: strcmp absent from canonical Linux `runtime.a` nm-UND after flip (the existence proof), with ZERO new libc UND introduced (rt_strcmp adds no UND — pure byte-loop over hexa carriers).",
          "default-OFF PR is byte-neutral/ungated-mergeable (runtime.a identical with macro unset); the default-ON flip is the pool-gated round. install.sh consumer smoke 3/3 (never promote on x86-only).",
          "pool required: mini is git/gh-only — byteeq + faithful builds run on aiden/summer (SSOT:162 confirms mini-immediate-landing = 0 for all reducible flips)."
        ],
        "wall": "\"After strcmp-caller drop, the LAST non-sanctioned reducible leaf is FLIP-6 (WALL-2 __libc_calloc/__libc_free default-ON, mechanisms #4242/#4244 merged-OFF) — measured-BLOCKED on the arm64/darwin fp-ABI Route-C else-arm: tool/stage_resolve_runtime_a:1930 ignores non-x86_64-linux, so the native calloc/free body has no arm64/darwin xmm fp-ABI coverage (realloc F2 #4620/#4621 crossed this only after the magic-guard heap-family-split fix). Beyond FLIP-6 the floor bottoms out at the SANCTIONED terminal set (SSOT §3, not reducible — no portable algorithm): net-FFI (~11-15 syms: socket/connect/getaddrinfo/DNS resolver) · CRT __libc_start_main (M8 irreducible seed #3959) · exec-family (execve/execvp) · CUDA opt-in (__cudaRegisterFatBinary). Literal `nm -u` ∅ is UNREACHABLE; the honest ② endpoint for 'no runtime.c' is sanctioned-floor, distinct from the emitted-C-compile-step axis.\""
      },
      {
        "axis": "③ no clang / no external C compiler — round-1: kill the system `as` fork on the x86_64-linux native object-emit path (own ELF x86_64 writer already exists; only the default-select arm is missing)",
        "head_confirmed": "53ee90270",
        "ready": true,
        "risk": "low",
        "plan_holds": true,
        "confidence": "high",
        "corrections": [
          "head_sha confirmed 53ee90270; all cited file:line sites match at this HEAD.",
          "Non-breaking: self/main.hexa:4560-4561 are HEXA_RUN_NATIVE_TRACE eprintln lines, NOT the fallback mechanism; the real clang-fallback safety net is the `if !file_exists(tmpbin)` guard at :4566 — cite :4566 for the safety net.",
          "Non-breaking: leg-B native-emit failure falls back to the CLANG path (inner `hexa build` subprocess), not an `as` route; the phrasing 'loud-fail-to-as/clang' should read 'loud-fail-to-clang'.",
          "Non-breaking refinement: FLIP-7 own-`_start` (HEXA_ZEROC_OWN_START) is ALREADY default-ON in the leg-B link at self/main.hexa:4551 (crt-drop branch live, opt-out=0), so the wall-section premise 'static-first with FLIP-7 own-_start avoids crt1.o' is already partially realized on the leg-B link today, not purely future ③-R2 work.",
          "Verified SAFE: EDIT SITE 1 variables (emit_kind, backend_kind_user_set, target) all exist and are used identically in the sibling arm64 arm at :516-520, so the proposed 4-line x86_64 arm applies cleanly; env-guard default-OFF keeps byteeq neutral because the native ELF bytes differ from the as-produced .o.",
          "Verified SAFE: crossemit smoke x86 leg uses a pre-built freestanding `_start` fixture (hexa_elf_x86_64_start.o), confirming the plan's honest caveat that the proven surface is hand-built LIR, not a full-frontend-lowered real program — the extended-corpus measurement gate is genuinely needed.",
          "Floor taxonomy is correct and NOT conflated: `as`/binutils-ld/hexa_ld-ELF are reducible; BOOTSTRAP-FLOOR and darwin codesign/dyld/libSystem are correctly classified as sanctioned-permanent OS-interface residue, consistent with the endgame DAG."
        ],
        "residual": [
          "compiler/main.hexa:508-520 — the native-backend AUTO-FLIP covers ONLY `arm64-apple-darwin` (:508-512) and `arm64-linux-gnu` (:516-520). There is NO `x86_64-linux-gnu` arm, so a bare `--emit=obj --target=x86_64-linux-gnu` leaves backend_kind at the default (`system`).",
          "compiler/main.hexa:1006-1015 — the native ELF x86_64 emit branch (`pack_lir_x86_64` + `serialize_elf_x86_64`, NO host `as`) ALREADY EXISTS but is gated on `backend_kind == \"native\"`; with the missing auto-flip it is unreachable by default and can only be opted into via explicit `--backend=native`.",
          "compiler/main.hexa:1075 — because backend_kind stays `system`, x86_64 obj emit falls through to `let as_cmd = \"as \" + asm_path ...` → forks binutils `as` on the emitted `.s` text.",
          "self/main.hexa:4525 — the `hexa run` leg-B clang-free cold path invokes `aprime_cc _drv.hexa --emit=obj --target=x86_64-linux-gnu` WITHOUT `--backend=native`, so it hits the `as` fork today (clang-free but not `as`-free). Host-gated Linux-x86_64-only (:4495-4496).",
          "tool/selfhost_crossemit_smoke.sh + .github/workflows/selfhost-crossemit-smoke.yml — the x86_64 ELF serializer is ALREADY CI-proven for a freestanding `_start` program: asserts R_X86_64_PC32 relocs against .rodata AND .data and RUNs the linked binary natively (stdout==\"hi\", rc==7). Proven surface = small hand-built LIR, NOT a full-frontend-lowered real program.",
          "tool/hexa_ld.hexa:262-269 — hexa_ld hard-rejects anything but Mach-O arm64 (magic `0xfeedfacf` at :262, cputype `0x0100000c` ARM64 at :267-269); the leg-B x86_64 link still uses binutils `ld` + glibc crt (self/main.hexa:4542-4552). This is ③-R2, NOT round-1.",
          "compiler/main.hexa:1151-1152 — `--linker=hexa` is an unwired stub that warns and falls back to system ld."
        ],
        "round1": [
          "LEVER: add the missing x86_64-linux native-emit auto-select arm — the exact sibling of the arm64-linux block at compiler/main.hexa:516-520 — so `--emit=obj --target=x86_64-linux-gnu` routes to the already-present native ELF writer (main.hexa:1006-1015) instead of forking `as` (main.hexa:1075). Ship it default-OFF/byte-neutral first: guard the new arm with an opt-in env toggle (e.g. `env(\"HEXA_X86_NATIVE_OBJ\")==\"1\"`), so byteeq stays unchanged until the flip.",
          "EDIT SITE 1 (primary, ~4 lines): compiler/main.hexa immediately after :520 — `if !backend_kind_user_set && target == \"x86_64-linux-gnu\" && emit_kind == \"obj\" && env(\"HEXA_X86_NATIVE_OBJ\")==\"1\" { backend_kind = \"native\" }`. No new emit code needed — :1006-1015 already handles it.",
          "EDIT SITE 2 (zero-code, env-only): none required in self/main.hexa:4525 — the leg-B exec passes no `--backend`, so once the auto-flip arm fires the leg-B path picks up the native writer for free. (Alternative surgical variant: pass `--backend=native` at :4525 behind the same toggle; prefer the SITE-1 arm so all x86_64 `--emit=obj` consumers benefit uniformly.)",
          "MEASUREMENT (on aiden/summer, linux-x86_64 — mini is git/gh only): extend selfhost_crossemit_smoke.sh's x86_64 leg from the freestanding `_start` fixture to a REAL multi-fn leg-B `.hexa` corpus that forces the full reloc set — user-fn/runtime calls → R_X86_64_PLT32, .rodata string refs → R_X86_64_PC32, absolute data → R_X86_64_64. For each program: build once via the `as`-route and once via `--backend=native` (toggle ON), link both with `ld`+crt+runtime.a, RUN both, assert identical stdout+rc. Capture the pass/fail table + any missing-encoding/missing-reloc `ld` errors.",
          "KEY SAFETY FACT (verified): both routes consume the IDENTICAL x86_64 codegen LIR (`lmodule`) — the only delta is LIR→bytes (native `serialize_elf_x86_64` vs textual `.s`+`as`). So the native route introduces ZERO new value-model/codegen correctness risk over the `as` route; any x86_64_linux.hexa:609-682 pair-carry bug is shared by both and belongs to axis ②, not this round.",
          "FLIP: after the extended crossemit smoke is GREEN on the real corpus + byteeq 3-target GREEN (toggle-OFF keeps it neutral), drop the env guard → default-ON, re-run byteeq 3-target + install/consumer smoke; leg-B loud-fail-to-`as`/clang fallback (self/main.hexa:4560-4561) stays intact as the safety net."
        ],
        "gate": [
          "pool measurement: extended selfhost_crossemit_smoke.sh x86_64 leg — real multi-fn leg-B corpus, native-ELF-.o vs as-route link+RUN equivalence (identical stdout+rc), on aiden/summer (linux-x86_64), captured table",
          "byteeq 3-target GREEN — default-OFF toggle keeps it byte-neutral pre-flip; re-run after the default-ON flip",
          "install.sh / consumer shipping smoke GREEN after the flip (leg-B `hexa run` on a linux-x86_64 box produces an `as`-free binary; HEXA_RUN_NATIVE_TRACE=1 confirms `[run-native] clang-free` path taken)"
        ],
        "wall": "Round-1's immediate next wall is an ENCODER/SERIALIZER COVERAGE gap, not a substrate wall: the real leg-B corpus exercises instruction encodings + reloc kinds (R_X86_64_PLT32 for calls, GOTPCREL, wider immediates) beyond the freestanding `_start` fixture the crossemit smoke proves today — any `encode_x86_64_insn` opcode or `serialize_elf_x86_64` reloc/section the writer doesn't yet cover surfaces as a loud `ld` error and is closed mechanically per-instruction (the `as` textual path handles them for free). The DEEPER wall this round then exposes — and the real ③ frontier — is ③-R2: hexa_ld links Mach-O arm64 ONLY (tool/hexa_ld.hexa:262-269), so even `as`-free the leg-B link still shells binutils `ld` + glibc crt1.o. HONEST verdict: a full own ELF x86_64 linker IS reachable (no measured substrate wall — reference-match a minimal mold/lld subset; static-first with FLIP-7 own-`_start` avoids crt1.o + ld-linux entirely, dynamic mode needs PLT/GOT+DT_NEEDED); it is multi-week engineering volume, not an irreducible. The only genuinely PERMANENT walls in axis ③ are (a) darwin `codesign`+dyld/libSystem (OS interface, sanctioned residue, not a C compiler) and (b) BOOTSTRAP-FLOOR (from-nothing cold start needs a prior hexa binary — the Go model). The one HARD measured wall near this campaign, the x86_64 HexaVal pair-carry rearch (compiler/codegen/x86_64_linux.hexa:609-682), belongs to axis ② runtime-port and is SHARED by both emit routes, so it does NOT gate ③-R1."
      },
      {
        "axis": "zeroc #29 — ② no-runtime.c nm-UND libc floor census (all-levers-ON sanctioned-WALL target), post strtod (#4651) + own-start FLIP-7 (#4656) default-ON graduation. Reference frame = the 2026-07-03 all-levers-ON measurement (state/zeroc-flip-measure-2026-07-03.txt:17 = 15U), NOT the nobaseline default advisory dump (which pre-excludes __libc_/atexit/environ/strtod at nobaseline-gate.yml:337-339, so those were never in the reducible count).",
        "head_confirmed": "53ee90270",
        "ready": false,
        "risk": "low",
        "plan_holds": false,
        "confidence": "high",
        "corrections": [
          "STALE RESIDUAL — qsort already DEFAULT-ON, not 'pending flip'. runtime_core_emit.hexa:7262 emits `#if !defined(HEXA_RT_ARRAY_SORT_NATIVE_OFF) /* stable native merge-sort default-ON ... drops qsort */`. Native is the default branch (opt-OUT via _OFF); the plan's lever name 'HEXA_RT_ARRAY_SORT_NATIVE (default-OFF)' is wrong — the actual gate is HEXA_RT_ARRAY_SORT_NATIVE_OFF. qsort drops on a plain default build, so it is NOT in the current residual.",
          "STALE RESIDUAL — fgets already DEFAULT-ON on Linux. runtime_core_emit.hexa:7655 guards the libc-fgets branch with `#if !defined(HEXA_RT_STREAM_NATIVE_READ) && (!defined(__linux__) || defined(HEXA_RT_STREAM_NATIVE_READ_OFF))` — on Linux without _OFF the native read branch compiles, dropping fgets by default. Not 'pending default-OFF→ON flip'.",
          "STALE RESIDUAL — glob/globfree already DEFAULT-ON on Linux. runtime_emit_full.hexa:12994 `#if defined(__linux__) && (defined(HEXA_RT_GLOB_NATIVE) || !defined(HEXA_RT_GLOB_NATIVE_OFF))` compiles native glob by default on Linux, dropping BOTH glob and globfree. Not 'pending flip'. (The emitter comments still say 'default-OFF byte-neutral' but the operative preprocessor polarity is default-ON; those comments are stale leftovers.)",
          "RESIDUAL COUNT WRONG — because qsort/fgets/glob/globfree are already default-ON, the current default+Linux floor is materially SMALLER than the plan's predicted 12. The Step-3 gate ('expected count = 12', 'residual set must equal exactly {…qsort glob globfree fgets…}') would FAIL on a fresh HEAD measurement — those four are absent even without the extra -D macros. The plan enshrines the pre-graduation 2026-07-03 set and undercounts progress since 12224289.",
          "MISCITED / STALE MECHANISM — calloc/free. Plan cites 'no-binary FATAL at stage_resolve_runtime_a:1904-1906 + x86_64-linux-only Route-C emit, needs graceful-no-binary resolver-hardening'. Direct read: :1904-1906 is the RT-NATIVE-STRCMP block, NOT calloc/free. Calloc is at 2156-2235, free at ~1985-2060, both TRI-STATE `${HEXA_RT_NATIVE_CALLOC:-auto}` / `${HEXA_RT_NATIVE_FREE:-auto}` = graceful-auto DEFAULT (frozen-seed consume; the no-binary FATAL root-cause #4489/#4545 was ALREADY FIXED by switching live-emit→frozen seed). Seeds landed for ALL 3 targets (#4548/#4554 free, #4556 calloc; self/native/hxlcl_{calloc,free}_{x86_64,arm64-linux,arm64}.s) — NOT x86_64-linux-only. The 'graceful-no-binary hardening' the plan says is pending has already landed. The plan inherited this stale characterization verbatim from DAG:46, which is itself stale.",
          "CONFLATION — __libc_calloc/__libc_free are TRANSITIVE glibc-internal symbols (census:20 explicitly '(transitive)'), reduced only by removing the libc CONSUMERS (regex/glob/qsort/etc.), NOT by the arena calloc/free port. The plan conflates them with the reducible hxlcl_calloc/hxlcl_free shim leaves (which have native seeds). Also PR attribution wrong: plan says '#4242/#4244 merged, #4489 flip FALSIFIED'; #4242 is the OLD free precedent, actual merges are #4548/#4554/#4556, and #4489/#4545 is the no-binary root-cause that was FIXED, not a falsified flip. free additionally stays UND by default only because realloc-native suppresses its seed (stage_resolve_runtime_a:2004 `HEXA_RT_NATIVE_REALLOC:-auto != 0 → _rnfr_mode=0`), a mechanism the plan omits.",
          "UNVERIFIABLE PR — strtod #4651 is not in-tree (`grep -rn 4651 self/ tool/` = 0 hits); DAG:46 explicitly notes 'no in-tree #4651 — the strtod-tail flip of record is #4639/#4645/#4646'. The plan cites #4651 repeatedly for the strtod flip and gate.",
          "MINOR TENSION — dl* is listed in the residual 12 AND cited as asserted-∅ by the S1 HARD GATE (nobaseline-gate.yml:347-361). The FFI partition into runtime_ffi_dyn.o is itself a flip ('OFF-verification cannot validate this; the flip is the first real test'), so dl* is either in the floor (pre-partition, as measured) or ∅ (post-partition, gated) — not both. Acceptable as the sanctioned-wall target, but the residual set and the gate describe different runtime.a states.",
          "CORRECT parts to retain: HEAD 53ee90270; strtod/own-start default-ON (all 4 sites); atexit+environ drop under own-start (correctly overrides stale census:58 which labeled atexit a permanent WALL); dl* = permanent sanctioned FFI wall; regex (regcomp/regexec/regfree) genuinely default-OFF and pending (runtime_emit_full.hexa:50/13832 `#ifndef HEXA_REGEX_NATIVE` = libc branch default). The headline strtod/atexit/environ delta is real — it is just incomplete."
        ],
        "residual": [
          "DELTA 15U → 12U. Both flips confirmed DEFAULT-ON at HEAD: strtod stage_resolve_runtime_a:707 `${HEXA_RT_STRTOD_TAIL_NATIVE:-1}`; own-start :46 / build_selfhost.sh:163 / stage_build_hexa:37 / stage_prebuild_hexat:51 all `:-1` (Linux-guarded). From the 2026-07-03 all-levers-ON WALL set (zeroc-flip-measure-2026-07-03.txt:17), 3 symbols drop: strtod (T_mis=0, aiden n=140,678, #4645/#4646/#4651); atexit (own-start _hxlcl_atexit_ LIFO under -DHEXA_ZEROC_OWN_START, resolver:3106); environ (libc-environ capture ctor compiled out under own-start, #4657). __libc_start_main/_start/crt1 also drop via -nostartfiles but were CRT-family, never among the 15 reducible-counted symbols.",
          "REMAINING 12 (all-levers-ON floor): __libc_calloc __libc_free dlerror dlopen dlsym fgets glob globfree qsort regcomp regexec regfree.",
          "SANCTIONED-WALL / permanent-irreducible (3): dlopen, dlsym, dlerror — FFI, partitioned into runtime_ffi_dyn.o; nobaseline-gate.yml:347-361 S1 HARD GATE asserts canonical runtime.a carries ∅ dl* (these live as native-canonical CUDA/plugin FFI binds only). zeroc-floor-census-2026-07-03.md:58 '영구 WALL'.",
          "CONDITIONAL / reducible-blocked (2): __libc_calloc, __libc_free — WALL-2 arena port mechanism merged (#4242/#4244) but default-ON flip #4489 FALSIFIED: resolver no-binary FATAL at stage_resolve_runtime_a:1904-1906 + x86_64-linux-only Route-C emit. Needs graceful-no-binary resolver-hardening (retain libc shim, mirror :1930 IGNORED path) before flip. census:59 '조건부'.",
          "REDUCIBLE-PORTABLE / falsified-WALL, native impl exists, pending own default-OFF→ON flip (7): fgets → HEXA_RT_STREAM_NATIVE_READ (native fd read-loop poll_impl); qsort → HEXA_RT_ARRAY_SORT_NATIVE (NaN-last stable merge sort; cross-dep hexa_array_sort→qsort at runtime.c:5551, so sort must flip before glob); glob+globfree → HEXA_RT_GLOB_NATIVE (fs_glob+glob_matches, single-level */? only, smoke-gate, fixed-order cmp NOT via hexa_array_sort); regcomp+regexec+regfree → HEXA_REGEX_NATIVE (thompson+backtrack engine exists, add (?i)/[[:...:]] only; byteeq-NEUTRAL since main.hexa uses 0 regex so faithful/@ci_gate not 3-target byteeq). Source: zeroc-floor-census-2026-07-03.md:50-56 wall-reassess.",
          "NOTE the honest DEFAULT-path floor (no extra levers) is still larger than 12 — the 6 FRAG-REGEN/syscall macros (SIGSYS_SVC, DROP_MALLOPT, OWN_MKTEMP, RAND_NATIVE, PROC_SC0_RAW, SIGSET_NATIVE) + HEXA_ZEROC_FRAG_REGEN=1 remain default-OFF, so getppid/setsid/rand/sysconf/mallopt/mktemp/syscall-family reappear on a plain build. 12U is the all-levers-ON sanctioned target, the correct successor to the 15U reference."
        ],
        "round1": [
          "On aiden (x86_64-linux), from a clean checkout at 53ee90270 (never the stale main worktree). Reproduce the 2026-07-03 all-levers-ON recipe MINUS strtod/own-start macros (both now default-ON in the resolver):",
          "Step 1 (FRAG-REGEN + frag patches): `HEXA_ZEROC_FRAG_REGEN=1 tool/restore_frozen_seeds`",
          "Step 2 (build runtime.a with the 6 residual syscall/frag macros; strtod+own-start need NO -D now — resolver drives them default-ON): `CFLAGS_COMMON=\"-DHEXA_RT_SIGSYS_SVC -DHEXA_RT_DROP_MALLOPT -DHEXA_ZEROC_OWN_MKTEMP -DHEXA_ZEROC_RAND_NATIVE -DHEXA_ZEROC_PROC_SC0_RAW -DHEXA_ZEROC_SIGSET_NATIVE\" tool/stage_resolve_runtime_a`",
          "Step 3 (libc-only nm-UND floor, same filter as the census): `nm -u build/runtime.a | awk '{print $2}' | sort -u | grep -vE '^(_hx_|__hexa|__hx_|__blk_|rt_|hexa_|_hexa|hxlcl_|_GLOBAL)' | grep -vE 'cuda|fatbin' | tr '\\n' ' '`",
          "Step 4 (default-graduation proof — SEPARATE build with NO macros at all, to confirm strtod/atexit/environ are gone on the plain default path too): rebuild `tool/stage_resolve_runtime_a` with empty CFLAGS_COMMON, then `nm -u build/runtime.a | grep -E '^(strtod|atexit|environ)$'` must return EMPTY.",
          "Expected Step-3 output = the 12 symbols listed in residual; expected count `nm -u ... | wc -l` on the libc-only filter = 12."
        ],
        "gate": [
          "Progress proof = all-levers-ON nm-UND libc-floor count drops 15 → 12 (Step 3), with strtod, atexit, environ ABSENT from `nm -u build/runtime.a`.",
          "Default-graduation proof (Step 4): strtod/atexit/environ absent on a plain default build with zero extra -D — confirms the flips graduated from lever-gated to default-ON, not merely lever-reachable.",
          "Bit-changing flip integrity (already required for merge, re-confirm green on this HEAD): byteeq 3-target GREEN + faithful-nobaseline (linux-x86_64 + linux-arm64) GREEN + install.sh consumer smoke GREEN for both #4651 and #4656 (own-start is Linux-only bit-changing; darwin inert via uname guard).",
          "Residual set must equal exactly {__libc_calloc __libc_free dlerror dlopen dlsym fgets glob globfree qsort regcomp regexec regfree} — any extra symbol = a frag-regen/macro-wiring regression (e.g. the signal_flock sentinel-miss class, census:64-69)."
        ],
        "wall": "Sanctioned-floor set (the honest terminus of this axis) = dlopen/dlsym/dlerror — the permanent, irreducible FFI wall (native-canonical dynamic-plugin + CUDA opt-in binds; nobaseline-gate.yml:347-361 S1 HARD GATE). Conditionally on the wall until WALL-2 resolver-hardening lands: __libc_calloc/__libc_free (mechanism merged #4242/#4244, blocked by the no-binary FATAL at stage_resolve_runtime_a:1904-1906 + x86-only Route-C; #4489 flip FALSIFIED). The other 7 (fgets/glob/globfree/qsort/regcomp/regexec/regfree) are NOT walls — falsified as lazy-ceilings with native seeds/engines already in-tree, each one own-flip away. So the true irreducible libc floor of axis ② = 3 (dl*), or 5 if WALL-2 is abandoned. This is a link-time symbol floor, NOT a runtime.c compile-step floor — per the DAG (selfhost_done_criterion_dag_fable.md:46,124) it does not collide with the ①②③ DONE criterion."
      }
    ]
  },
  "workflowProgress": [
    {
      "type": "workflow_phase",
      "index": 1,
      "title": "Scope"
    },
    {
      "type": "workflow_phase",
      "index": 2,
      "title": "Verify"
    },
    {
      "type": "workflow_agent",
      "index": 1,
      "label": "scope:axis2-runtime-c",
      "phaseIndex": 1,
      "phaseTitle": "Scope",
      "agentId": "a849a22dc68481c34",
      "model": "claude-opus-4-8[1m]",
      "state": "done",
      "startedAt": 1783383990695,
      "queuedAt": 1783383990687,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "lastToolSummary": "② no runtime.c — next byte-neutral libc-UND-drop round (nm-…",
      "promptPreview": "CRITICAL (conv-1): read files ONLY from the clean current-main worktree at /Users/mini/dancinlab/hexa-lang/.worktrees/wf-ref2. FIRST run `git -C /Users/mini/dancinlab/hexa-lang/.worktrees/wf-ref2 rev-parse --short HEAD` and confirm it is 53ee90270 or a later origin/main commit. Do NOT read /Users/mini/dancinlab/hexa-lang directly — its working tree is on a stale branch ~175 commits behind and cont…",
      "lastProgressAt": 1783384344044,
      "tokens": 118417,
      "toolCalls": 20,
      "durationMs": 353349,
      "resultPreview": "{\"axis\":\"② no runtime.c — next byte-neutral libc-UND-drop round (nm-UND floor mop-up)\",\"head_sha_confirmed\":\"53ee90270\",\"residual\":[\"PREMISE CORRECTION (load-bearing): every candidate the task lists to weigh is ALREADY default-ON — the 15U WALL set is stale, predating the 2026-07-03 flip batch. Confirmed at HEAD 53ee90270 in the emitters: fgets = HEXA_RT_STREAM_NATIVE_READ default-ON linux (#4450,…"
    },
    {
      "type": "workflow_agent",
      "index": 2,
      "label": "scope:axis3-own-emit-linker",
      "phaseIndex": 1,
      "phaseTitle": "Scope",
      "agentId": "a75b451bf85f3e4c6",
      "model": "claude-opus-4-8[1m]",
      "state": "done",
      "startedAt": 1783383990695,
      "queuedAt": 1783383990687,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "lastToolSummary": "③ no clang / no external C compiler — round-1: kill the sys…",
      "promptPreview": "CRITICAL (conv-1): read files ONLY from the clean current-main worktree at /Users/mini/dancinlab/hexa-lang/.worktrees/wf-ref2. FIRST run `git -C /Users/mini/dancinlab/hexa-lang/.worktrees/wf-ref2 rev-parse --short HEAD` and confirm it is 53ee90270 or a later origin/main commit. Do NOT read /Users/mini/dancinlab/hexa-lang directly — its working tree is on a stale branch ~175 commits behind and cont…",
      "lastProgressAt": 1783384188988,
      "tokens": 80797,
      "toolCalls": 12,
      "durationMs": 198293,
      "resultPreview": "{\"axis\":\"③ no clang / no external C compiler — round-1: kill the system `as` fork on the x86_64-linux native object-emit path (own ELF x86_64 writer already exists; only the default-select arm is missing)\",\"head_sha_confirmed\":\"53ee90270\",\"residual\":[\"compiler/main.hexa:508-520 — the native-backend AUTO-FLIP covers ONLY `arm64-apple-darwin` (:508-512) and `arm64-linux-gnu` (:516-520). There is NO …"
    },
    {
      "type": "workflow_agent",
      "index": 3,
      "label": "scope:floor-census-refresh",
      "phaseIndex": 1,
      "phaseTitle": "Scope",
      "agentId": "ac74c84a579940c16",
      "model": "claude-opus-4-8[1m]",
      "state": "done",
      "startedAt": 1783383990695,
      "queuedAt": 1783383990687,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "lastToolSummary": "zeroc #29 — ② no-runtime.c nm-UND libc floor census (all-le…",
      "promptPreview": "CRITICAL (conv-1): read files ONLY from the clean current-main worktree at /Users/mini/dancinlab/hexa-lang/.worktrees/wf-ref2. FIRST run `git -C /Users/mini/dancinlab/hexa-lang/.worktrees/wf-ref2 rev-parse --short HEAD` and confirm it is 53ee90270 or a later origin/main commit. Do NOT read /Users/mini/dancinlab/hexa-lang directly — its working tree is on a stale branch ~175 commits behind and cont…",
      "lastProgressAt": 1783384221656,
      "tokens": 84823,
      "toolCalls": 11,
      "durationMs": 230961,
      "resultPreview": "{\"axis\":\"zeroc #29 — ② no-runtime.c nm-UND libc floor census (all-levers-ON sanctioned-WALL target), post strtod (#4651) + own-start FLIP-7 (#4656) default-ON graduation. Reference frame = the 2026-07-03 all-levers-ON measurement (state/zeroc-flip-measure-2026-07-03.txt:17 = 15U), NOT the nobaseline default advisory dump (which pre-excludes __libc_/atexit/environ/strtod at nobaseline-gate.yml:337-…"
    },
    {
      "type": "workflow_agent",
      "index": 4,
      "label": "verify:axis3-own-emit-linker",
      "phaseIndex": 2,
      "phaseTitle": "Verify",
      "agentId": "a3fbd669977f15179",
      "model": "claude-opus-4-8[1m]",
      "state": "done",
      "startedAt": 1783384189011,
      "queuedAt": 1783384189001,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "lastToolSummary": "axis3-own-emit-linker",
      "promptPreview": "CRITICAL (conv-1): read files ONLY from the clean current-main worktree at /Users/mini/dancinlab/hexa-lang/.worktrees/wf-ref2. FIRST run `git -C /Users/mini/dancinlab/hexa-lang/.worktrees/wf-ref2 rev-parse --short HEAD` and confirm it is 53ee90270 or a later origin/main commit. Do NOT read /Users/mini/dancinlab/hexa-lang directly — its working tree is on a stale branch ~175 commits behind and cont…",
      "lastProgressAt": 1783384325450,
      "tokens": 75793,
      "toolCalls": 12,
      "durationMs": 136439,
      "resultPreview": "{\"axis\":\"axis3-own-emit-linker\",\"plan_holds\":true,\"corrections\":[\"head_sha confirmed 53ee90270; all cited file:line sites match at this HEAD.\",\"Non-breaking: self/main.hexa:4560-4561 are HEXA_RUN_NATIVE_TRACE eprintln lines, NOT the fallback mechanism; the real clang-fallback safety net is the `if !file_exists(tmpbin)` guard at :4566 — cite :4566 for the safety net.\",\"Non-breaking: leg-B native-em…"
    },
    {
      "type": "workflow_agent",
      "index": 5,
      "label": "verify:floor-census-refresh",
      "phaseIndex": 2,
      "phaseTitle": "Verify",
      "agentId": "ae7c366d6522571bf",
      "model": "claude-opus-4-8[1m]",
      "state": "done",
      "startedAt": 1783384221662,
      "queuedAt": 1783384221661,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "lastToolSummary": "zeroc #29 — no-runtime.c nm-UND libc floor census refresh (…",
      "promptPreview": "CRITICAL (conv-1): read files ONLY from the clean current-main worktree at /Users/mini/dancinlab/hexa-lang/.worktrees/wf-ref2. FIRST run `git -C /Users/mini/dancinlab/hexa-lang/.worktrees/wf-ref2 rev-parse --short HEAD` and confirm it is 53ee90270 or a later origin/main commit. Do NOT read /Users/mini/dancinlab/hexa-lang directly — its working tree is on a stale branch ~175 commits behind and cont…",
      "lastProgressAt": 1783384546732,
      "tokens": 91454,
      "toolCalls": 13,
      "durationMs": 325070,
      "resultPreview": "{\"axis\":\"zeroc #29 — no-runtime.c nm-UND libc floor census refresh (all-levers-ON sanctioned-WALL target), reference frame = 2026-07-03 15U all-levers-ON measurement.\",\"plan_holds\":false,\"corrections\":[\"STALE RESIDUAL — qsort already DEFAULT-ON, not 'pending flip'. runtime_core_emit.hexa:7262 emits `#if !defined(HEXA_RT_ARRAY_SORT_NATIVE_OFF) /* stable native merge-sort default-ON ... drops qsort …"
    },
    {
      "type": "workflow_agent",
      "index": 6,
      "label": "verify:axis2-runtime-c",
      "phaseIndex": 2,
      "phaseTitle": "Verify",
      "agentId": "a4ccfa647a42abed8",
      "model": "claude-opus-4-8[1m]",
      "state": "done",
      "startedAt": 1783384344053,
      "queuedAt": 1783384344051,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "lastToolSummary": "axis2-runtime-c",
      "promptPreview": "CRITICAL (conv-1): read files ONLY from the clean current-main worktree at /Users/mini/dancinlab/hexa-lang/.worktrees/wf-ref2. FIRST run `git -C /Users/mini/dancinlab/hexa-lang/.worktrees/wf-ref2 rev-parse --short HEAD` and confirm it is 53ee90270 or a later origin/main commit. Do NOT read /Users/mini/dancinlab/hexa-lang directly — its working tree is on a stale branch ~175 commits behind and cont…",
      "lastProgressAt": 1783384585162,
      "tokens": 74593,
      "toolCalls": 12,
      "durationMs": 241109,
      "resultPreview": "{\"axis\":\"axis2-runtime-c\",\"plan_holds\":false,\"corrections\":[\"HEAD confirmed 53ee90270. The residual IDENTIFICATION is correct and well-supported: the 7 raw strcmp(key,...) caller sites all exist verbatim at HEAD (runtime_emit.hexa:1052/1053/1057, runtime_emit_full.hexa:5622/5623/5627, runtime_core_emit.hexa:4253), and SSOT line 162 (2026-07-06 reconcile, CI run 28745095773) independently names non…"
    }
  ],
  "totalTokens": 525877,
  "totalToolCalls": 80
}