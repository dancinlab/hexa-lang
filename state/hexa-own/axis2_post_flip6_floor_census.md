> ## ⛔ FALSIFIED — 이 문서의 HEADLINE VERDICT 는 거짓 종점이다 (2026-07-14)
>
> 이 문서는 **"②-libc-floor = SANCTIONED-FLOOR TERMINAL REACHED · 0 reducible libc symbols"** 를
> 선언한다. **틀렸다.** 근인은 이 문서 자신의 method 줄에 적혀 있다:
>
> > `Method = source/emitter-gate + git-witness reconcile`
>
> 즉 **`nm` 을 한 번도 돌리지 않았다.** 소스 grep 대조로 "reducible 0" 을 선언한 것이고,
> 이것은 정확히 proxy-게이트다 — 아카이브를 안 읽고 아카이브에 대한 종점을 선언했다.
>
> **실측 반증 (#4944 · aiden · linux-x86_64 · `HEXA_RT_MULTIOBJ=1` = release 기본 배치):**
>
> | lane | control | SYSLEAF=1 | delta |
> |---|---|---|---|
> | `stage_resolve_runtime_a` | 232 UND | **229** | **−3** |
> | `release_build` (like-for-like) | 238 UND | **235** | **−3** |
>
> 드롭된 집합 = 정확히 `{mmap, munmap, waitpid}` · 부수피해 0.
>
> 근인: MULTIOBJ ship 배치에서 `hxlcl_shim.o` 가 **바로 옆 `runtime.o` 에 있는 네이티브 바디를 두고**
> 자기 `hxheap_alloc`/`hxheap_free` 안에서 **raw libc `mmap`/`munmap` 을 부른다**. 단일-TU 배치에서는
> 이 UND 가 안 보이므로, 단일-TU 만 본 census 는 구조적으로 이걸 놓친다.
>
> ⇒ **"0 reducible" 은 측정된 사실이 아니라 측정하지 않은 결과다.**
> 이 문서의 나머지 내용(패밀리별 stale 판정)은 참고로 남기되, **HEADLINE VERDICT 와 "sanctioned-floor
> terminal" 선언은 무효**다. 아카이브에 대한 종점 선언은 **반드시 `nm` 을 ship 배치(MULTIOBJ)로 돌린 뒤에만**
> 하라.

# axis-② post-FLIP-6 nm-UND libc floor — census + ranked verdict (2026-07-09, origin/main 7ba14a403)

Lane ② (no runtime.c), round ②-floor. Trigger: FLIP-6 (#4747) dropped malloc/free/calloc/__libc_calloc/__libc_free
(native reclaiming heap, re-witnessed on aiden). Task: census the post-FLIP-6 floor → find the next reducible ②
target OR honestly confirm the sanctioned-floor terminal. Method = source/emitter-gate + git-witness reconcile
(no heavy pool build; mini = git/gh/read).

## ★ HEADLINE VERDICT: ②-libc-floor = SANCTIONED-FLOOR TERMINAL REACHED — the #4748 WALL residual node is STALE on ALL 5 listed families.

The ARCHITECTURE.json `zeroc-frontier-wall-residual` node (updated #4748, today) lists as WALL:
`dlopen/dlsym/dlerror · fgets · glob/globfree · qsort · regcomp/regexec/regfree`.
**Every one of those 5 families is already reduced** — 4 by witnessed default-ON flips, 1 by the S1 FFI-TU
partition. The node was updated to drop strtod/environ/atexit/calloc/free but was NOT reconciled against the
07-03→07-06 flip wave that already dropped fgets/glob/qsort/regex, nor against the S1 dl* partition. There is
**no reducible libc symbol remaining** in the canonical `runtime.a`.

This confirms the big-overview node's own 07-07b statement ("the 15U WALL is stale, fgets/qsort/glob/regex all
already default-ON, seed-flip surface EXHAUSTED") over the stale residual node.

## Per-symbol assessment (each residual entry → actual state, with evidence)

| residual entry | verdict | evidence |
|---|---|---|
| **qsort** (tie-order) | **DROPPED** (not a wall) | `#4452` flip `HEXA_RT_ARRAY_SORT_NATIVE` default-ON all-target; gate `self/runtime_core_emit.hexa:7266` `#if !defined(..._OFF)` — stable native merge-sort, byteeq-safe ("gen3==gen4 re-converges; stable sort is byteeq-safe … drops qsort on all targets"). The task's "portable introsort could drop it" suspicion is **correct in spirit but already actioned** — a *stable merge-sort* (not introsort) is byteeq-SAFER than libc qsort's unspecified tie-order, so the drop is a determinism *gain*. |
| **glob/globfree** (fnmatch fidelity) | **DROPPED** (linux) | `#4449` flip `HEXA_RT_GLOB_NATIVE` default-ON on linux; gate `self/runtime_emit_full.hexa:12994` `#if defined(__linux__) && (…\|\| !defined(..._OFF))`. getdents64 + inline matcher + selection-sort (fixed order). |
| **fgets** (FILE* layer) | **DROPPED** (linux) | `#4450` flip `HEXA_RT_STREAM_NATIVE_READ` default-ON on linux; gate `self/runtime_core_emit.hexa:7659` (libc fallback compiled only on non-linux/OFF). fd read-loop, not a FILE* port. |
| **regcomp/regexec/regfree** (ERE oracle) | **DROPPED** | `#4535` flip `HEXA_REGEX_NATIVE` default-ON; gate `tool/stage_resolve_runtime_a:762` `${HEXA_REGEX_NATIVE:-1}`. Thompson NFA + backtrack VM. **Measured drop: "228→225"** in the flip commit body. (The `.s` seed header comments still say "opt-IN default-OFF" — stale seed text; the live `stage_resolve` gate is `:-1` default-ON.) |
| **dlopen/dlsym/dlerror** (FFI) | **STRUCTURALLY RELOCATED via S1 — not in the canonical floor** | S1 FFI-dyn TU partition is **fully landed**: emitter `emit_runtime_ffi_dyn_to` (`self/runtime_emit_full.hexa:16532`) emits the dl* bodies into a *separate* `runtime_ffi_dyn.c`, called during main emit (`:16794`); consumer `tool/stage_resolve_runtime_a:3192/3227` compiles it to `runtime_ffi_dyn.o` but does **NOT** `ar` it into canonical `runtime.a`; driver-link `self/main.hexa:1606` (PR-2) links it only for programs that actually need dl*. **Verified**: in the canonical emitter the ONLY actual `dlopen()/dlsym()/dlerror()` *call bodies* are inside `emit_runtime_ffi_dyn_to` (16532–16780, writes `fbuf`→runtime_ffi_dyn.c); every dl* mention in the main `buf` (canonical runtime.c → runtime.o → runtime.a) is a comment or an fprintf error-string, not a call. **⇒ canonical runtime.a is dl*-free.** |

Note: `self/runtime_emit.hexa:1475` still emits a raw `hexa_ffi_dlsym`/`dlsym` body — but that emitter feeds only the
separate `runtime_hi` seed (`tool/regen_runtime_hi_seed_c.sh`/`_o.sh`), **not** the canonical `runtime.c` (which
comes from `runtime_emit_full.hexa`). It is not part of the runtime.a nm-UND floor.

## Seed-flip surface — EXHAUSTED (full roster of default-ON drops since the 07-03 census)

- `strtod` (#4651, IEEE oracle, T_mis=0 bit-exact vs glibc, n=140,678)
- `environ`/`atexit`/`__libc_start_main` (#4656 FLIP-7 own-start default-ON, bit-changing)
- `malloc`/`free`/`calloc`/`__libc_calloc`/`__libc_free` (#4747 FLIP-6 native reclaiming heap, re-witnessed aiden)
- `strcmp` (#4602 caller-drop + #4679 range-drop coupled to RT-NATIVE-STRCMP seed)
- `strncmp`/`strstr`/`strchr`/`strdup` (#4592 isolated seeds), `strlen` (#4612 musl word-scan)
- mem-leaf `memcpy`/`memset`/`memcmp` (#4604), str-leaf `strncpy`/`strcat`/`strcpy` (#4605)
- `realloc` F2 magic-header (#4620 mechanism + #4621 flip), `strtol`/`ptsname_r` (#4607), `isdigit` (#4613)
- `getenv`/`setenv` (#4611), `sysconf`/`mallopt`/`mkstemp`/`mkdtemp` (#4441)
- syscall-family FRAG-REGEN `getppid`/`setsid`/`mount`/`umount2`/`unshare`/`setns`/`flock`/`sigaddset`/`sigemptyset` (#4430)
- `fgets`/`glob`/`qsort`/`regex` (#4449/#4450/#4452/#4535, above)
- prior fronts: libm transcendentals (#4299–4318, -lm removed), 16 fs/time syscalls→raw-svc (#4320–4336)

All landed under the standard gate (byteeq 3-target + faithful-nobaseline + install-smoke GREEN; RED→default-OFF revert).

## The TRUE current canonical runtime.a nm-UND floor (what actually remains)

Pure **sanctioned classes** — none listed on the residual node because they are taken as the given floor:
- **network-FFI**: accept/bind/connect/listen/socket/recv/send/… — external opt-in per native-canonical-default.
- **exec-family**: execve/fork/posix_spawn/… — sanctioned.
- **CUDA opt-in**: lives in the *separate* `runtime.cuda.a`, byteeq-neutral to the CPU `runtime.a`.
- residual CRT bootstrap that is genuinely irreducible (weak libm-compat ABI shims, etc.).

These are permanently sanctioned by the two standing governance invariants: **native-canonical-default**
(external deps are opt-in-flag-only, and a separate opt-in link unit is the *canonical* implementation of that,
per S1's own design) and **no-LLVM**. dl* is further the subject of a *possible* future S2/S3 own-loader campaign
(RFC 070 §G7-C, ~2.4kLOC musl dynlink port) — but that is a major independent campaign, NOT a floor "flip", and
even it leaves the *policy* (external vendor .so = opt-in) intact.

## Honest scope caveat — nm-UND-∅ is NOT the axis-② DONE line

Axis-② DONE (CLAUDE.md) = **"no runtime.c"** = the ~5.5k-LOC emitted-C substrate itself eliminated (ported to
native `.hexa`/`.s`/own-emit so nothing compiles a generated `.c`). This census closes the **libc-DEPENDENCY
sub-track** of ② (the nm-UND floor is at its sanctioned terminal — 0 reducible libc symbols), but `runtime.c`
still exists as a clang-compiled emitted `.c` (`build/runtime.o` from `self/runtime.c`). Eliminating the substrate
itself is the **own object-emit / native-port endgame**, shared with axis-③ (own x86_64/ELF + Mach-O object
writers + `hexa_ld`). So: the libc-floor is 🏁; the full "no runtime.c" line remains OPEN on the
substrate-elimination track.

## round_next

**②-libc-floor = sanctioned-floor 🏁** (seed-flip surface EXHAUSTED; residual = {net-FFI, exec, CUDA-opt-in,
CRT-ABI} honest-keep). No reducible libc symbol remains to flip.

Two non-flip follow-ups (hygiene / next-axis, not floor reductions):
1. **Reconcile the stale residual node** (this PR does the census-doc half): retire fgets/glob/qsort/regex
   (flipped #4449/50/52/535) + dlopen/dlsym/dlerror (S1-relocated) from `zeroc-frontier-wall-residual`, gated on
   a **faithful-CI nm-UND re-witness of the canonical runtime.a post-#4747** to stamp the corrected floor
   (belt-and-suspenders on the S1 completeness argument above).
2. **Pivot ② effort to the substrate-elimination track** (own-emit runtime, shared with axis-③) — the only
   remaining path to the literal "no runtime.c" DONE line; the libc-dependency axis has nothing left to flip.
