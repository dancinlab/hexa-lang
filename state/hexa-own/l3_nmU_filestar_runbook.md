# L3 runtime.c→0 — FILE* cluster nm-UND drop 측정 런북 (#4894 머지 후)

**#4894 MERGED (2026-07-12)** — HXLCL_STDIO_LINK #ifdef arm(default-OFF·byteeq-neutral)가 self/runtime_core_hxlcl_shim_emit.hexa + stage_resolve_runtime_a에 착지. 다음 = HEXA_RT_STDIO_LINK=1 MULTIOBJ 빌드로 FILE* libc-floor 심볼이 nm-UND에서 빠지는지 측정.

호스트: aiden(x86_64-linux) — summer는 CUDA env-leak, ghost는 darwin-arm64.

---
## Fable-5/agent nm-U 측정 런북 (origin/main read-only · file:line 증거)

I have the complete ground truth. Producing the runbook.

---

# L3 runtime.c→0 · FILE\* cluster-drop measurement runbook (post-#4894-merge)

**Verified from `origin/main` (386-commit-ahead working copy ignored).** #4894 (`feat/l3-axis2-stdio-filestar-multiobj-swap`) is OPEN/MERGEABLE, adds gate `HXLCL_STDIO_LINK` (default-OFF, byteeq-neutral) across 3 files. The gate `_zc_stdio_link` does **not** yet exist on `origin/main` (confirmed: only `_zc_stdio` present) — run this AFTER merge.

## Ground truth (what the swap mirrors)

The single-TU **amalgam** `self/runtime_emit_full.hexa` already proves the fake-fd model in production: `FILE* == (void*)(uintptr_t)(fd+1)`, encode at `:1310-1395`, macro redirects at `:2940-2954`:

```
fopen  → hxlcl_fopen   (mode→flags, hxlcl_open_sys, fd<=2 fail-closed, returns fd+1)
fclose → hxlcl_fclose  (v>=0x1000 libc-FILE* no-op; fd<3 no-op; else hxlcl_close)
fread  → hxlcl_fread   (_hxlcl_fp_fd → hxlcl_read loop)
fwrite → hxlcl_fwrite  (_hxlcl_fp_fd → hxlcl_write loop)   [hxlcl_write export gated by HEXA_RT_STDIO_NATIVE]
ftell  → hxlcl_ftell   (hxlcl_lseek SEEK_CUR)
fseek  → hxlcl_fseek   (hxlcl_lseek)
fdopen → hxlcl_fdopen  (returns fd+1)
fileno → _hxlcl_fp_fd
flock  → hxlcl_flock
```
Inner callees `hxlcl_open_sys/read/write/close/lseek` are already dissolved raw-svc leaves that stay retained shim/runtime.o globals → the isolated bodies' relocs resolve intra-archive (coupled-leaf class, not zero-reloc).

`origin/main` MULTIOBJ shim (`self/runtime_core_hxlcl_shim_emit.hexa:1344-1353`) currently has **libc delegates** (`hxlcl_fopen{return fopen(...)}`, etc.); `runtime_core.o` (S3) calls libc FILE\* directly (sysheaders `HEXA_RT_STDIO_NATIVE` block, `self/runtime_core_sysheaders.h:~165-180`, redirects only the **print** family `printf/fprintf/perror/snprintf` and explicitly leaves FILE\*+fflush on glibc). Those two are the residual UND sources #4894 closes.

---

## 1. Build command (pool — NOT mini; aiden/summer/ghost)

`tool/release_build` already defaults `HEXA_RT_MULTIOBJ=1` (`:77`) and `HEXA_RT_STDIO_NATIVE=1` (`stage_resolve_runtime_a:55`). The new `_zc_stdio_link` fires only when **`HEXA_RT_STDIO_LINK=1` AND `$_zc_stdio` is on** (STDIO_NATIVE coupling for the `hxlcl_write` export). So, belt-and-suspenders explicit:

```bash
# on aiden/summer (heavy build host), from repo root, seeds present:
HEXA_RT_MULTIOBJ=1 HEXA_RT_STDIO_NATIVE=1 HEXA_RT_STDIO_LINK=1 \
  bash tool/release_build 2>&1 | tee /tmp/l3_stdio_link_build.log
# stage 0b emits build/runtime.a (RA="$ROOT/build/runtime.a")
```
Baseline (gate-OFF) archive for the diff — same host, clean `build/`:
```bash
HEXA_RT_MULTIOBJ=1 HEXA_RT_STDIO_NATIVE=1 \
  bash tool/release_build 2>&1 | tee /tmp/l3_baseline_build.log
cp build/runtime.a /tmp/runtime.a.OFF     # snapshot before rebuilding ON
```
Guard check: `HEXA_RT_STDIO_LINK=1` with `HEXA_RT_STDIO_NATIVE=0` must **not** pass `-DHXLCL_STDIO_LINK` (stage blocks the unresolved-`hxlcl_write` case). Verify the stage log prints the `_zc_stdio_link` wiring line and that S3/S4 compile lines carry `-DHXLCL_STDIO_LINK`.

---

## 2. nm-U before/after diff (use the CI's exact invocation)

The authoritative floor uses **`nm -u`** (undefined-only) per `.github/workflows/nobaseline-gate.yml:352`. The FILE\* cluster is **not** in any exclusion filter (`grep -vE` chain at `:353-359` filters `_hxlcl_*`/cuda/sockets/CRT/exec/rand/strtod — stdio FILE\* passes through), so it currently appears in the "reducible libc floor" dump and must vanish.

**Cluster measurement (run on both archives):**
```bash
for A in /tmp/runtime.a.OFF build/runtime.a; do
  echo "== $A =="
  nm -u "$A" 2>/dev/null | awk '{print $2}' | sort -u \
    | grep -E '^(fopen|fread|fwrite|fclose|ftell|fseek|fseeko|ftello|fdopen|fileno|flock|fflush|fputs|fputc|setvbuf|rewind|fgets|getc|fscanf)$'
done
```
Also capture the full advisory floor delta (identical pipeline to CI):
```bash
nm -u build/runtime.a 2>/dev/null | awk '{print $2}' | sort -u \
  | grep -vE '^(_hx_|__hexa|__hx_|__blk_|rt_|hexa_|_hexa|_?hxlcl_|_GLOBAL)' \
  | grep -vE 'cuda|fatbin' > /tmp/floor.ON
# diff against the same over /tmp/runtime.a.OFF
```

**Expected — LEAVE the floor (cluster drop) when ON:**
`fopen`, `fread`, `fwrite`, `fclose`, `ftell`, `fseek` (the six named in the PR goal), plus `fdopen`, `fileno`, `flock` (the rest of the amalgam fake-fd-consuming set that the sysheaders redirect covers). These are replaced by intra-archive `hxlcl_*` refs (filtered out of the advisory by the `_?hxlcl_` pattern).

**Expected — STAY (and why):**
- `rewind`, `fgets`, `getc`/`getc_unlocked`, `fscanf` — **deliberately NOT redirected** (PR item 2). They only touch the real `stdin/stdout/stderr` glibc `FILE*` globals (`fp >= 0x1000` branch), never a fopen'd fake-fd; redirecting them would break real-std-stream I/O. Matches the amalgam exactly.
- `read`/`write`/`open`/`close`/`lseek`, `__errno_location`, `_exit`/`atexit`/`environ`, `malloc`/`free`/`memcpy`… — sanctioned syscall/CRT/mem floor, out of scope for this axis (and excluded from the advisory filter regardless).
- **`fflush`** — *the ambiguous one, verify empirically.* The amalgam keeps `fflush` on glibc for std streams; #4894's shim ON-arm adds an `hxlcl_fflush` no-op export, but whether the symbol leaves `nm -u` depends on whether the sysheaders `#undef/#define` block redirects `fflush` (PR item 2 lists rewind/fgets/getc/fscanf as *not* redirected but is silent on fflush). Read it in the diff — do not assume.
- **`fuel_abort`** is not a libc symbol; it emits `fprintf(stderr, "[hexa-runtime/fuel_abort]…")` (`self/runtime_core_emit.hexa:674`, already routed via the default-ON `HEXA_RT_STDIO_NATIVE` print redirect) **and** writes a real-fopen'd log via `fopen`+`fwrite`+`fflush(f)`+`fclose` (`self/runtime_core_sysheaders.h:171`). Under ON those FILE\* calls redirect to the fake-fd path (fopen→real fd+1, fwrite→hxlcl_write to the real file, fflush→no-op which is correct for unbuffered write(2), fclose→hxlcl_close) — so fuel_abort contributes **no** residual FILE\* UND. Its correctness is the smoke test in §3.

---

## 3. Byteeq-neutrality proof + landmine risk

**Default-OFF stays byte-identical — how to verify (the required PR-CI gate):**
- Single-TU (Case-A) never compiles the shim TU / never sees the gate.
- MULTIOBJ default (`HEXA_RT_STDIO_LINK` unset): the shim preprocesses to the `#else` arm **verbatim** (the current libc delegates) → `hxlcl_shim.o` byte-identical; sysheaders emits nothing for the unused prototypes → `runtime_core.o` byte-identical; stage passes an empty `-D`.
- Proof = the standing **byteeq 3-target** gate on `selfhost-gates-summary` with the gate OFF: single-TU `runtime.a` must be BYTE-identical to the pre-#4894 baseline (`.text` byte-eq; ignore DWARF-cwd artifact per the known-artifact note). Confirm the PR-CI byteeq lane is GREEN 3/3 and the `ld -r` S5 multidef gate = 0 on the ON build (static fake-fd in runtime.o vs shim-exported — the PR calls this out).

**FILE\*/fuel_abort landmine (a consumer the swap misses → link break or silent misdirect):**
1. **Unresolved `hxlcl_write` (link break):** `HXLCL_STDIO_LINK` ON while `HEXA_RT_STDIO_NATIVE` OFF → `hxlcl_fwrite` references an unexported `hxlcl_write`. The stage `_zc_stdio_link` guard blocks this combo, **but a measurement script passing `-DHXLCL_STDIO_LINK` directly to `$CC` bypasses the guard** — always drive the build through `tool/release_build`/`stage_resolve_runtime_a`, never a hand-rolled `-D`.
2. **A FILE\* consumer outside the redirected set (silent misdirect):** any `runtime_core.o` writer that does `fprintf`/`fputs`/`fputc` to a **fopen'd fake-fd** (not std streams) would decode wrong — `fprintf` is redirected to `hxlcl_fprintf((void*)fp,…)` which must decode `(fd+1)` via `_hxlcl_fp_fd`; if it instead assumes a real glibc `FILE*` it SIGSEGVs (the exact `fileno`-on-fake-fd crash class documented at `runtime_emit_full.hexa:2948-2954`). The amalgam's ship-proven invariant is "writers only target stdin/stdout/stderr" — the swap is safe **iff** that holds. Verify by grepping `runtime_core.c`'s emitter for any `fprintf/fputs/fputc/fscanf` whose stream arg is a fopen'd handle, not std.
3. **fseeko/ftello (64-bit offset variants):** if any consumer uses `fseeko/ftello` they are **not** in the amalgam macro set (only `fseek/ftell`) → they'd stay glibc UND and, worse, operate on a fake-fd if the header maps them. Confirm `nm -u` shows neither as a *newly stranded* consumer of a fake handle.

**Required smoke (shipping path, after ON build):**
```bash
HEXA_PREBUILT_RUNTIME=build/runtime.a  # link consumer against the ON archive
# rebuild hexat via stage_build_hexa, then:
hexa build <hello.hexa> && ./hello            # exit0 / hello coherent
hexa run   <exit42.hexa>; echo $?             # 42
# fuel_abort real-log path (fopen+fwrite+fflush+fclose on a fake-fd):
#   trigger a fuel_abort with a log path set and confirm the log file
#   contents are byte-correct (this exercises the exact FILE* family that dropped).
```
Promote (flip default-ON) only after: byteeq 3-target GREEN (gate OFF) + `ld -r` multidef=0 + all-3-target `nm -u` cluster-drop confirmed + fuel_abort log smoke GREEN. Never on x86-only.

### Anchor reference (origin/main line numbers)
- Advisory nm-UND dump + exact `nm -u … | awk … | grep -vE` pipeline: `.github/workflows/nobaseline-gate.yml:339-362` (S1 dl* hard gate at `:396-410` for the invocation pattern).
- Stage flags: `_zc_stdio` def `tool/stage_resolve_runtime_a:54-55`; `HEXA_RT_MULTIOBJ` gate `:1481`; S3 `runtime_core.o` compile carrying `$_zc_stdio` `:~3211`; S4 `hxlcl_shim.o` compile `:~3224`; S5 `ld -r` multidef gate `:~3230+`. (`_zc_stdio_link` + S3/S4 `-DHXLCL_STDIO_LINK` land with #4894 at the PR-cited `~:66-67`.)
- Current libc-delegate FILE\* block (becomes the `#else` arm): `self/runtime_core_hxlcl_shim_emit.hexa:1344-1353`.
- sysheaders print-only redirect (FILE\*/fflush kept on glibc today): `self/runtime_core_sysheaders.h:165-180`; FILE\* protos `:91-98`.
- Amalgam fake-fd ground truth: `self/runtime_emit_full.hexa:1310-1395` (bodies), `:2940-2954` (macros).