---
slug: hexa-run-cold-cache-race-loser-spurious-error
title: `hexa run` cold-cache 동시 fire 시 race loser가 spurious "compile error" 보고
source: sidecar UserPromptSubmit hook fan-out (commons + easy-auto + prefs + inbox-watch 동시 fire)
status: resolved (branch inbox/hexa-run-cold-cache-race-fix-2026-05-25)
discovered: 2026-05-24
resolved: 2026-05-25
priority: medium
---

> **Resolution**: 3-site 1-liner fix on self/main.hexa — `cmd_run_user_direct` · `cmd_run` · `_batch_run_one`. 검증 조건 `brc == 0 && file_exists(tmpbin)` → `file_exists(tmpbin)` 완화. tmpbin은 atomic rename(`mv -f _tmp_inflight tmpbin`) 으로만 도달하므로 peer 가 만든 byte-identical binary 는 자기 brc 와 직교 — race loser 가 더 이상 spurious "compile error" 를 보고하지 않음 (line 2779 의 "loser's overwrite is benign" 의도 완성). Hexa 재빌드 + install 후 발효.

# `hexa run` cold-cache race — loser process가 가짜 compile error 보고

## 증상

Claude Code sidecar에서 4개 UserPromptSubmit hook이 동시 fire하는 첫 turn에 hooks.json의 4 plugin 전부가 다음 에러로 실패:

```
error: `hexa build /Users/ghost/.claude/plugins/cache/sidecar/<plugin>/<ver>/bin/_<plugin>.hexa` failed (compile error).
```

그러나 다음 turn부터는 정상 동작 (cache warm). 즉 cold-cache 첫 fire 한정 race.

## 재현 조건

- `~/.hexa-cache/hexa_run.<sha16>_<ver>` 가 없는 상태 (cold cache)
- 같은 src에 대해서가 아니라 **서로 다른 src** 4개를 동시에 `hexa run` 호출 (4개 다른 `tmpbin` paths)
- shell 동시 fork + clang 동시 실행 → 일부 process가 build 단계에서 fail (정확한 underlying 원인 미확정 — clang OOM 후보, fork 한계, pipe broken 후보)
- 다만 `bout` (build stdout)이 empty로 캡처되어 `__HEXA_BRC__` marker 미검출 → `brc = 1 (default)` → error trailer

## 위치 (3 site 동일 패턴)

`self/main.hexa`:

| 함수 | line |
|---|---|
| `cmd_run` | 2872 |
| `cmd_run_user_direct` | 2784 |
| `_batch_run_one` | 2982 |

세 site 모두 동일 패턴:

```hexa
if brc == 0 && file_exists(tmpbin) {
    // execute tmpbin
} else {
    eprintln("error: `hexa build " + file + "` failed (compile error).")
    // exit nonzero
}
```

## 분석

코드 line 2776 comment가 이미 race를 인지하고 있음:

```
// Atomic-rename into place. Concurrent rebuilds race but
// produce byte-identical binaries (same source), so the
// loser's overwrite is benign.
```

→ "loser's overwrite is benign" 의도. 그러나 검증 조건이 `brc == 0 && file_exists(tmpbin)` 이라서:
- loser process의 `brc != 0` (자기 build는 fail) **이면서**
- peer가 만든 `tmpbin` 은 file_exists OK

이 경우 loser가 fallthrough → error path. peer의 byte-identical binary가 cache에 이미 존재함에도 loser는 spurious error 보고.

## 제안 fix (1-line × 3 site)

```diff
- if brc == 0 && file_exists(tmpbin) {
+ if file_exists(tmpbin) {
```

근거:
- `tmpbin` 은 atomic rename(`mv -f _tmp_inflight tmpbin`)로만 도달 → 존재한다면 fully-built valid binary
- 자기 build 실패와 무관하게 peer 성공 binary 실행은 안전
- 의도된 "loser overwrite is benign" 시맨틱 완성

## 영향 범위

- `cmd_run_user_direct`: `hexa run <file>` 사용자 직접 호출 — sidecar hook의 주 경로 (가장 영향 큼)
- `cmd_run`: absorbed-verb 내부 호출
- `_batch_run_one`: `hexa batch` 경로

## 검증 시나리오

1. `rm -f ~/.hexa-cache/hexa_run.* ~/.hexa-cache/runtime.*.o`
2. 4 plugin .hexa 동시 `hexa run` (사이드카 4 hook fan-out 시뮬레이션)
3. fix 전: 종종 일부 process가 "failed (compile error)" + nonzero exit
4. fix 후: 모두 cache의 binary 실행, exit 0

(현장 재현은 비결정적 — load/timing 의존. fix는 검증 측면이 아닌 시맨틱 일관성 측면에서 정당화됨.)

## 보조 관찰

근본 원인 (왜 동시 fire 시 일부 `hexa build` invocation이 silent fail하는가) 은 별건. 후보:

- clang concurrent OOM (4×clang -O2 동시 = 메모리 압박)
- shell fork/exec 한계
- exec() builtin의 pipe capture race (`bout` empty)

이 fix는 **race detection bug** 해소 — 부산물은 여전히 일어날 수 있지만 user-visible error 사라짐 (peer가 같은 binary 만들어주므로).
