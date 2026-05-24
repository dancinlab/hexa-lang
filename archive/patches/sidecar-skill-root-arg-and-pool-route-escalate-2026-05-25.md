# sidecar skill `--root` 빈-바이너리 버그 + pool-route 전면 escalate — CARDIO+ paper 작업서 발견

**Status (2026-05-25)**: HANDED-OFF — #1 (skill `--root` 빈-바이너리 guard) · #2 (pool-route 전면 escalate allowlist) → sidecar INBOX (sidecar PR #118). **#3 (`hexa verify --expr` ubu-2 segfault) = ✅ ROOT-CAUSED + FIXED** (transpile-stage stale `hexa_v2_linux_x86_64` 바이너리 — `_hx_self_rss_bytes` fscanf #594-class 버그가 fix-전 빌드에 잔존 · 소스는 이미 fix · branch `inbox/verify-cli-segfault-2026-05-25` 에서 재빌드 + 빌드레시피 amalgam-swap 수정 · ubu-2 e2e 🟢 검증 · §#3 상세).

**Reporter**: demiurge (CARDIO+ 메타도메인 X10 PAPER 작업 · 2026-05-25)
**Severity**: high (skill 2종 완전 차단 · 모든 Bash가 Linux host로 강제 → macOS-only 자원 도달 불가)
**Affected**: sidecar skill wrapper (`_imagine.hexa` · `_paper.hexa` · 동일 `--root` 패턴 쓰는 skill 전부) + pool-route PreToolUse hook
**Discovered through**: `/imagine` · `/paper` skill 호출이 `--root` compile error로 죽음 + 모든 Bash가 ubu-1/ubu-2로 escalate되어 mini(macOS) fal key·pdflatex 도달 불가

## TL;DR

3개 독립 회귀가 CARDIO+ paper 산출을 동시에 막음. 모두 우회 성공했으나 근본 fix는 hexa-lang/sidecar 소관:

1. **skill `--root` 빈-바이너리 버그** — `_imagine.hexa`/`_paper.hexa`가 PATH에 없으면 wrapper의 `hexa run "$H" --root …`에서 `$H`가 빈 문자열 → `hexa run --root …` → `--root`를 소스 파일로 오인 → `source file not found: --root`
2. **pool-route 전면 escalate** — load-escalated (non-claude load > 150%) 시 *모든* Bash를 ubu-1/ubu-2로 SSH 라우팅 → macOS-only 자원 (fal key in Keychain · /Library/TeX pdflatex · `pool` CLI 자체) 도달 불가
3. **`hexa verify --expr` ubu-2 segfault** — routed 환경서 `verify_cli.hexa` build가 Segmentation fault (core dumped) → bio calc fn (hill · fick1 · ldl_pct · exp_release, PR #658 atlas 등록분) verify path 막힘

(#1·#2는 신규 · #3는 [[bio-verify-kernel-extension-2026-05-25]] + [[pool-cli-compile-errors-2026-05-25]]와 인접하나 segfault 증상은 별개 기록)

## #1 skill `--root` 빈-바이너리 버그

### Reproduction
```
$ command -v _imagine.hexa     # → (empty, routed 환경서 PATH에 없음)
$ /imagine <prompt> <out.png> -s landscape_16_9
  → hexa run "" --root <dir>/.. <args>
  error: `hexa build --root` failed (compile error).
  error: source file not found: --root
```
`/paper new` · `/paper compile` 도 동일 (`_paper.hexa` 빈 → `--root` 오인).

### Root cause
skill wrapper 패턴:
```sh
H="$(command -v _<skill>.hexa)"; hexa run "$H" --root "$(dirname "$H")/.." <args>
```
`command -v`가 빈 문자열 반환 시 guard 없음 → `hexa run` 첫 인자가 `--root`가 됨.

### Suggested fix
- wrapper에 빈-바이너리 guard: `[ -z "$H" ] && { echo "skill binary _<skill>.hexa not on PATH (host=$(hostname))"; exit 127; }`
- 또는 `hexa run` 자체가 `--root`를 옵션으로 먼저 파싱 (현재는 첫 positional을 무조건 소스 파일 취급)
- routed 환경서 skill 바이너리 PATH 보장 (sidecar install이 ubu host에도 skill symlink 배치, 또는 pool-route가 skill 호출은 escalate 제외)

## #2 pool-route 전면 escalate (load-escalated)

### Reproduction
```
$ uptime    # Mac load > 150%
$ pool on mini '...'
  → routed to ubu-1 → "bash: pool: 명령어를 찾을 수 없음"  (ubu에 pool CLI 없음)
$ secret get fal.api_key
  → routed to ubu → Keychain 없음 (macOS-only)
$ pdflatex main.tex
  → /Library/TeX/texbin (macOS) 인데 ubu로 routed 시 미존재
```

### Root cause
load-escalated 분기가 호스트-특이적 명령 (macOS Keychain `secret` · `pool` CLI 자체 · macOS pdflatex)까지 무차별 escalate. `SIDECAR_NO_POOL_ROUTE=1` override도 일부 무시됨.

### Suggested fix
- escalate 제외 목록(allowlist): `secret` · `pool` · `pdflatex`/`pdftex` · `_*.hexa` skill wrapper · macOS-path 절대경로 (`/Library/…` · `/opt/homebrew/…`)
- `SIDECAR_NO_POOL_ROUTE=1` 강제 존중 (현재 load-escalate 분기가 무시) — hard override여야
- `pool on <host>` 자체는 절대 재escalate 금지 (idempotency)

## #3 `hexa verify --expr` ubu-2 segfault

### Reproduction
```
$ hexa verify --expr hill 100 200 4     # routed to ubu-2
  error: `hexa build /home/summer/.hx/bin/tool/verify_cli.hexa` failed (compile error).
    Segmentation fault (core dumped)
$ hexa verify rubric                      # read-only path 는 OK (작동)
```
read-only (`rubric`/`--fence`)는 작동 · `--expr` (recompute) build만 segfault.

### ✅ ROOT-CAUSED + FIXED (2026-05-24, ubu-2 실측)

**Stage = TRANSPILE** (NOT clang, NOT runtime). `hexa verify --expr` 가 `verify_cli.hexa`
를 build → `[1/2]` 단계가 `self/native/hexa_v2_linux_x86_64 <expanded>.hexa out.c`
를 호출하는데 **transpiler 바이너리 자체가 SIGSEGV**. clang은 도달조차 못 함
(`error: transpile failed — C file not produced`).

**Crashing frame** (gdb bt, ubu-2 x86_64):
```
#0 __vfscanf_internal (s=0x4, format="%ld %ld")   ← fscanf(garbage FILE*=0x4, …) → SIGSEGV
#1 __isoc23_fscanf
#2 _hx_self_rss_bytes()      ← 범인
#3 hexa_array_push()         ← mem-cap RSS tick poller
#4 hexa_str_chars()
#5 tokenize()
#6 main()
```

**원인** = `_hx_self_rss_bytes()` 의 **이미 고쳐진 #594-class 버그**. fopen-shim 이
`(void*)(fd+1)` 를 반환하는데 `fscanf` 는 remap 안 되어 그 small-int 를 `FILE*` 로
deref → SIGSEGV. `HEXA_MEM_CAP_MB=4096` 가 모든 transpile 의 `[1/2]` 에 주입되어
(pool Linux host 디스패치) 매번 발화. **소스(`self/runtime_core.c:301`)는 이미 syscall
(`hxlcl_open_sys("/proc/self/statm")`) 로 고쳐져 있음 (#634/#748)** — fscanf 없음.

**Environment vs source = STALE BINARY.** origin/main 에 커밋된
`self/native/hexa_v2_linux_x86_64` (md5 `d08a647e…`, #634 동반 커밋) 가 **fix 이전
runtime 으로 빌드된 stale 바이너리** — `strings` 에 `%ld %ld` (fscanf fmt) 잔존.
clean rebuild 한 바이너리에는 `%ld %ld` 없음. summer 의 `hexa_v2_fresh` 도 동일 stale
(fix 전 빌드). mini(macOS) 가 정상이던 이유 = mini transpiler 는 fix-후 빌드.

증명 (ubu-2, 3중):
| binary | `%ld %ld` (fscanf) | verify_cli transpile |
|---|---|---|
| 커밋 `hexa_v2_linux_x86_64` (origin/main) | **YES** | **SEGV** |
| clean rebuild (fix 소스) | **NO** | **OK · 249KB C · e2e `--expr hill` → 🟢 0.998004 (\|Δ\|=1.1e-16)** |

**왜 stale 됐나 (durable root cause)** = `tool/build_hexa_v2_linux.hexa` 의 빌드 레시피가
`hexa_cc.c` (head `#include "runtime.h"` = 프로토타입 전용) 를 그대로 compile → runtime
**body 가 link 안 됨** (`undefined reference to hexa_str` …). 즉 이 레시피로는 애초에
바이너리를 재생성할 수 없었음 → #634/#748 의 runtime fix 가 Linux transpiler 에 영영
안 흘러들어옴. 표준 `hexa build` 는 `runtime.h`→`runtime.c` amalgam swap 으로 body 를
끌어오는데 이 스크립트만 그 단계가 빠져 있었음.

### Fix (this PR — branch `inbox/verify-cli-segfault-2026-05-25`)
1. **`self/native/hexa_v2_linux_x86_64` 재빌드** (fix 소스 amalgam, ubu-2). `%ld %ld` 제거,
   verify_cli transpile RC=0 + `--expr hill` e2e 🟢 측정 확인. ⚠ glibc-static (ubu-2 빌드,
   musl-cross 는 Mac 전용) 이라 1.78MB→3.3MB — 기능 동일, follow-up 으로 Mac musl 재regen 시
   사이즈 회복 가능.
2. **`tool/build_hexa_v2_linux.hexa` amalgam-swap 추가** (durable fix — 향후 재빌드가
   stale 안 되도록 runtime.h→runtime.c 단계 삽입).

검증 호스트: ubu-2 (x86_64). 회귀 smoke (sum 1..100=5050) PASS.

## CARDIO+ 작업서 실제 우회 (참고)

| 차단 | 우회 |
|---|---|
| paper compile | `pdflatex -interaction=nonstopmode main.tex` × 3-pass 직접 (skill 안 거침) |
| figure 생성 | `curl https://fal.run/fal-ai/flux/schnell -H "Authorization: Key $(secret get fal.api_key)"` 직접 |
| BasicTeX 의존 | authblk·enumitem 미설치 → 표준 매크로 전환 |
| verify --expr | read-only `--fence` + 선행 V3 numerical 인용으로 honest 우회 |

## 영향 범위

- demiurge CARDIO+ V2 🔵 push 막힘 (#3) — bio calc fn verify 불가
- 모든 `/imagine`·`/paper` skill 사용자 (#1)
- macOS-자원 의존 작업 전반 (#2) — fal image · secret · pool · macOS TeX

## metadata
```
status: handed-off
type: infra-regression
priority: P1 (#1·#2 skill 전면 차단 · #3 V2 push blocker)
size: hook allowlist (#2) ~30 LOC · wrapper guard (#1) ~5 LOC × N skills · verify_cli segfault (#3) 조사 필요
reporter: demiurge CARDIO+
related: pool-route-overaggressive-hexa-cloud · pool-cli-compile-errors · bio-verify-kernel-extension
```
