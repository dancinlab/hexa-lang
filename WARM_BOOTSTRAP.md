# 🍞 WARM_BOOTSTRAP — `.hexa only` (tracked `.c` = 0) 로 가는 안전 경로

> `완전한 .hexa only` 의 유일한 안전 경로. cold-bootstrap C 씨앗을 제거하되 release 를
> 깨지 않으려면, release.yml Stage-0 가 **이전 hexa 릴리스로 씨앗 .c 를 재생성(warm)** 한 뒤
> 컴파일하도록 재배선해야 한다. 순서를 어기면 INBOX #1985(전 release 차단) 재발.

## 배경 — 왜 `.c=0` 이 지금은 불가능한가

release.yml Stage-0 는 hexa 없는 fresh CI 에서 `clang -I self self/native/hexa_cc.c self/runtime.c -o hexa_v2`
로 **첫 hexa 를 C 에서 부트스트랩**한다. `self/runtime.c` 가 `#include "runtime_core.c"` + 16 `native/*.c`
(+ `runtime_hi_gen.c` · forge) 를 하므로 그 씨앗 .c 가 디스크에 있어야 한다.

`.c-text` 캠페인(76→3)이 그 씨앗을 git-rm+gitignore → Stage-0 全失(#1985) → #1992 가 19개 복원(.c=22).
= **cold-bootstrap 은 C 씨앗을 요구**. `.c=0` 은 cold 로는 구조적 불가.

## 해법 — COLD vs WARM

```
COLD (현재):  clang + 씨앗 C(tracked) → 첫 hexa           ← .c 필요 = .c≠0
WARM (목표):  edge 릴리스 hexa 다운로드 → 그 hexa 가
              emitter 로 씨앗 .c 재생성 → clang 컴파일      ← 씨앗 gitignore 가능 = .c=0
```
rustc/gcc 가 이전 릴리스 바이너리로 부트스트랩하는 바로 그 방식.

## Phase 1 — 메커니즘 PROVEN ✅ (2026-05-29)

`hexa-run tool/regen_native_runtime_c_includes.hexa` (로컬 prior-hexa) →
**18/18 씨앗 .c 재생성 + sha-identical to tracked** (`runtime_core` `331312ab…` · `runtime_hi_gen` `03c80311…`
+ 16 native). git clean. = prior hexa + emitter 가 씨앗을 byte-perfect 재생성함을 입증.
forge_tier_v1.c 는 sibling `tool/regen_dispatch_c_artifacts.hexa` 가 담당(19번째).

## Phase 2 — fresh edge publish (GATE · in_progress)

warm-regen 의 prior hexa = edge 릴리스 asset (`hexa-{darwin-arm64,linux-arm64,linux-x86_64}.tar.gz`).
현 edge 는 5/23(stale, pre-#1992) → 호환 risk. #1992/#1995 fix 후 fresh edge 가 publish 되어야
호환 prior hexa 확보. **GATE: release run 26593317915 (또는 후속) 의 edge publish 확인.**

## Phase 3 — release.yml warm-regen 배선 (fresh edge 후, fallback-safe)

각 Stage-0 앞에 추가 (macos `clang`/linux `gcc` job 공통, ASSET 만 target 별):
```yaml
- name: Stage 0-pre — warm-bootstrap regen seed .c (fallback-safe)
  shell: bash
  env: { GH_TOKEN: "${{ github.token }}" }
  run: |
    # 이전 edge hexa 로 씨앗 .c 재생성. ANY 실패 → tracked .c fallback (절대 빌드 중단 X).
    ASSET="hexa-darwin-arm64.tar.gz"   # linux job 은 hexa-linux-{x86_64,arm64}.tar.gz
    if gh release download edge --pattern "$ASSET" --dir /tmp/prior 2>/dev/null \
       && tar xzf "/tmp/prior/$ASSET" -C /tmp/prior 2>/dev/null; then
      PH="$(find /tmp/prior -type f -name hexa | head -1)"
      if [ -n "$PH" ] && "$PH" --version >/dev/null 2>&1; then
        "$PH" run tool/regen_native_runtime_c_includes.hexa --regen-only \
          && "$PH" run tool/regen_dispatch_c_artifacts.hexa --regen-only 2>/dev/null
        echo "warm: 씨앗 .c 재생성 from prior hexa"
      else echo "warm: prior hexa unusable → tracked .c"; fi
    else echo "warm: no prior edge → tracked .c (cold)"; fi
    test -f self/runtime_core.c || { echo "FATAL: 씨앗 부재"; exit 1; }
```
배선 후 **CI 에서 실제 재생성 동작 확인**(fresh edge hexa 가 emitter 실행 → 씨앗 생성 → green).
씨앗이 tracked 인 동안은 no-op refresh → 절대 안 깨짐. 이 단계가 green 이어야 Phase 4 진행.

## Phase 4 — 19 amalgamation 씨앗 제거 (.c −19)

Phase 3 CI-green 확인 후: `git rm` + `.gitignore`(sign-gated) 로 19개(runtime_core·16 native·hi_gen·forge)
제거 → warm-regen 이 load-bearing 이 되어 Stage-0 가 재생성본으로 컴파일. `.c` 22→3.

## Phase 5 — 루트 씨앗 (runtime.c · hexa_cc.c · bootstrap_compiler.c) → .c=0

남은 3 루트:
- `self/native/hexa_cc.c` (28K boot-image) — prior hexa `hexa cc --regen` 가 재생성 → warm-step 에 추가 → 제거.
- `self/runtime.c` (amalgamation 루트) — meta-generator(`tool/gen_c_text_emitter.hexa`)로 emitter 생성 → warm-regen 에 추가 → 제거.
- `self/bootstrap_compiler.c` — 동일(emitter 또는 regen 경로 확인) → 제거.
3 루트가 모두 warm-regen 되면 → **`.c=0` 달성**.

## ⚠ 순서 불변식 (CRITICAL)

```
PROVE(P1) → fresh-edge(P2) → WIRE+CI-green(P3) → REMOVE(P4,P5)
```
**절대 REMOVE 를 WIRE 앞에 하지 말 것** — 그게 #1985(전 release 차단)의 원인이었음.
각 제거는 직전 warm-regen 이 CI-green 임을 확인한 뒤에만. fallback-safe 단계로 항상 cold 경로 보존.

## 상태 (2026-05-29)

| Phase | 상태 |
|---|---|
| 1 메커니즘 | ✅ PROVEN (18/18 byte-identical) |
| 2 fresh edge | 🔄 GATE (#1992/#1995 후 release run 대기) |
| 3 CI 배선 | ⬜ (P2 후) |
| 4 19 씨앗 제거 | ⬜ (P3 green 후 · .c 22→3) |
| 5 루트 3 제거 | ⬜ (.c 3→0) |
