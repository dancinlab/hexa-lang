---
title: hexa cloud exec — shell-mode 1-line dispatch verb
status: open
kind: feature
priority: high
filed-by: claude (sidecar session)
filed-at: 2026-05-24
related: hexa cloud (run · nohup · poll · copy-to · copy-from)
---

# hexa cloud exec — shell-mode 1-line dispatch

## 동기 (왜 만드는가)

현재 `hexa cloud` 의 `run` 은 **structured argv** 모드 — 매 토큰을 POSIX-quote 후 ssh 로 전달. 안전하지만 **복합 shell 표현이 불편**:

```sh
# 원하는 것 (한 줄, shell 문법):
hexa cloud exec runpod-h100 "cd /work && nvidia-smi | head -5"

# 현재 강제되는 형태 (argv 모드):
hexa cloud run runpod-h100 -- bash -lc "cd /work && nvidia-smi | head -5"
#  ^^^^^^^^^^^^^^^^^^^^^^^^^ 토큰을 bash -lc 안으로 한번 더 quote 필요
```

→ 사용자가 매번 `bash -lc "..."` 또는 dispatcher script 파일을 만들어 `bash run.sh` 형태로 우회. **g8 위반 패턴의 주된 원인**.

cloud-guard 가 raw `runpodctl`/`ssh` 는 차단하지만, dispatcher script 파일 안의 raw 호출은 우회 가능 → 새 verb 로 **합법 경로의 ergonomic 우월성** 확보가 더 깨끗한 해결책.

## 제안 시그니처

```
hexa cloud exec <host> [conn] -- <shell-command-string>
```

- `<host>` — ssh destination or `~/.ssh/config` alias (run/nohup 와 동일)
- `[conn]` — `--port <n>` · `--insecure` (run/nohup 와 동일)
- `<shell-command-string>` — `--` 뒤의 모든 인자를 **공백으로 join** 후 그대로 ssh `<host>` 의 default shell 에 전달

핵심 차이 vs `run`:

| 축 | `cloud run` | `cloud exec` |
|---|---|---|
| 모드 | structured argv | shell string |
| 원격 shell parsing | 없음 (POSIX-quote) | **있음** (login shell) |
| glob/redirect/pipe | 불가 | **가능** |
| 보안 | 호출자가 quote 통제 | 호출자가 shell 통제 (raw ssh 등가) |
| 적합 사용처 | 프로그램 직접 호출 | ad-hoc inspection · 복합 표현 |

`exec` 가 sandbox 가 아님을 매뉴얼에 명시 (`run` 이 안전, `exec` 는 편의).

## 구현 스케치

`hexa-lang/src/cloud/exec.hexa` (또는 cloud 패키지가 어디에 있든) 기준:

```hexa
fn exec_mode(host: string, conn: array, cmd_tokens: array) -> int {
    // join shell command tokens with single space — caller is responsible
    // for any quoting they want preserved.
    let cmd = cmd_tokens.join(" ")
    let ssh_argv = build_ssh_argv(host, conn) // 기존 helper 재사용
    ssh_argv.push(cmd)                         // append as-is (no POSIX-quote)
    let r = exec_with_status(ssh_argv.join(" "))
    return r[1]
}
```

`build_ssh_argv` 는 `cloud run` 과 동일 (port / insecure / known_hosts 처리).

## help 갱신

```
cloud exec     <host> [conn] -- <shell-cmd>            run shell command via ssh (DEFAULT SHELL PARSES IT)
```

`run` help line 에 cross-ref 한 줄 추가: `# for shell-mode ad-hoc dispatch, see `cloud exec``

## 시험 케이스 (regression 방어)

| # | 호출 | 기대 결과 |
|---|---|---|
| 1 | `cloud exec h100 -- echo hi` | `hi` |
| 2 | `cloud exec h100 -- "ls /work | head -3"` | 디렉토리 첫 3줄 (pipe 작동) |
| 3 | `cloud exec h100 -- "X=1; echo $X"` | `1` (shell 변수) |
| 4 | `cloud exec h100 --port 22033 -- whoami` | port flag 작동 |
| 5 | `cloud exec` (인자 부족) | usage 출력 + exit 2 |

## 우선순위

**High** — g8 우회의 주된 동기 제거. cloud-guard 와 한 쌍으로 작동 (guard 가 raw 호출 차단 + exec 가 합법 빠른 경로 제공).

## 관련 작업

- `sidecar/hooks/cloud-guard` 0.2.2 → dispatcher script 내용 scan 추가 (별개 PR)
- `sidecar/skills/cloud` → exec 안내 추가 (verb 머지 후)
