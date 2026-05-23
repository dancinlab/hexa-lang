---
slug: dispatcher-hygiene
kind: rfc_draft
filed_at: 2026-05-24
filed_from: hexa-lang
priority: high
status: proposed
unblocks: [rfc_026, rfc_028]
---

# RFC 085 — Dispatcher hygiene: env-var passthrough + `.hexarc` + `--local` flag

- **Status**: proposed
- **Date**: 2026-05-24
- **Severity**: HIGH (cross-host UX · silent offload pain)
- **Priority**: P1
- **Promotes**: RFC 026 (env passthrough + `.hexarc`) + RFC 028 (`--local` / `HEXA_NO_REMOTE`)
- **Cross-link memory**: `[[feedback_resource_routing_ubu]]` (heavy work → ubu pool), `[[reference_hexa_module_loader_env_2026_05_20]]` (HEXA_LANG / HEXA_MODULE_LOADER 필수)

## 통합 근거

RFC 026 과 RFC 028 은 **같은 도메인** (`hexa run` cross-host dispatcher 행동) 의 두 측면이다:

- **026**: dispatch **하기로 했을 때** 환경 어떻게 전달할 것인가 (passing surface)
- **028**: dispatch **할지 말지** 어떻게 사용자가 통제할 것인가 (gating surface)

두 RFC 의 falsifier 셋은 서로를 가정한다 (026 F-026-3 env whitelist 는 028 의 `--remote` 경로에서만 의미가 있고, 028 F-028-1 `--local` 의 가치는 026 의 env loss 가 silent 일 때 가장 크다). 따라서 한 단위 — **dispatcher hygiene** — 로 promote 한다.

## §1. Motivation (silent offload + env loss)

### 1.1 silent offload pain

Mac 셸에서 `hexa run script.hexa` 호출 시 사용자는 자기 호출이 local 인지 remote 인지 알 수 없다:

```
$ uname -s              # Mac shell
Darwin

$ hexa run /tmp/env_probe.hexa
HOME = /home/aiden      # ← Linux (aiden 으로 silent offload)
USER = aiden
PWD = /tmp/resource-tcp-XXXX
```

결과:

1. **Path confusion**: `~/core/anima/foo` 가 Mac vs aiden 에서 다른 절대경로
2. **State surprise**: Mac 에서 쓴 파일이 aiden 에서 안 보임 (sshfs 마운트 외)
3. **Debugging mis-attribution**: 실패 원인을 잘못된 호스트에 귀속
4. **Resource overcommit**: 9GB ML 로드 한 번에 aiden OOM, Mac 셸은 ssh dies 까지 무지

### 1.2 env-var loss (HEXA_LANG drop)

dispatch 가 일어났을 때도, Mac 셸의 `HEXA_LANG=/Users/ghost/core/hexa-lang` 가 aiden 에 전달되지 않아 stdlib resolution 이 깨진다:

```
[module_loader] FATAL module not found: stdlib/bytes
  searched:
    HEXA_LANG=<unset>             # ← Mac side 에서는 set, aiden 에 전달 안 됨
    HEXA_STDLIB_ROOT=<unset>
    project_root=<none>
    caller_dir=/home/aiden/core/hexa-lang/stdlib
    cwd=/tmp/resource-tcp-XXXX
```

문제가 두 겹이다:

- **(a)** env 자체가 전달되지 않음 (passthrough 부재)
- **(b)** 전달되더라도 값이 host-local 경로라 의미 없음 (`/Users/ghost/...` 은 aiden 에 존재하지 않음 → translation 필요)

Memory cross-link:

- `[[reference_hexa_module_loader_env_2026_05_20]]` — `HEXA_MODULE_LOADER` / `HEXA_LANG` / `HEXA_MAC_BUILD_OK` 누락 시 compiled 빌드가 단 한 줄 warn 후 NULL-OBJECT silent fail. 본 RFC 의 env passthrough 가 이 surface 의 cross-host 짝.
- `[[feedback_resource_routing_ubu]]` — heavy 작업 (빌드 · drill · full-suite) 은 ubu-1/ubu-2 원격이 정책. 즉 silent offload 자체는 의도된 routing 의 일부지만, **사용자가 그것을 알 수 있어야** 한다는 것이 본 RFC.

## §2. Design

### 2.1 env-var allowlist (RFC 026 Mechanism 2 흡수)

resource-tcp dispatcher 가 dispatch payload 에 env 를 전달. allowlist:

```
allow_env = [
  "HEXA_*",        # HEXA_LANG, HEXA_STDLIB_ROOT, HEXA_MODULE_LOADER, HEXA_MEM_*, ...
  "ANIMA",         # anima project root
  "NEXUS",         # nexus root
  "BEDROCK_*",     # bedrock substrate vars
  "PYTHONPATH",    # python interop
]
```

값은 **translated** 로 전달 (literal 아님). 번역 룰은 `.hexarc` 의 `[dispatcher.translate]` 섹션에서 정의:

```toml
[dispatcher.translate]
"/Users/ghost/core" = "/home/aiden/core"   # mac → aiden
```

전달 받은 호스트는 받은 env 를 자신의 프로세스 환경에 주입 후 hexa.real 을 spawn.

기본값: passthrough **opt-in** (no breaking change). `.hexarc` 의 `[dispatcher]` 섹션 또는 `HEXA_DISPATCH_ENV_PASS=1` 로 활성.

### 2.2 `.hexarc` project config (RFC 026 Mechanism 1 흡수)

위치: `git rev-parse --show-toplevel` 또는 `$ANIMA` / `$NEXUS` 루트. 첫 startup 에 한 번 파싱.

스키마:

```toml
# .hexarc — project hexa config

[lang]
stdlib_path    = "$HEXA_HOME/core/hexa-lang/stdlib"   # host-aware var expansion
project_imports = ["./stdlib", "./tool"]

[mem]
default_cap_mb = 8000

[dispatcher]
prefer_local        = true
env_passthrough     = true
diagnostic_default  = "one_line"     # "off" | "one_line" | "verbose"

[dispatcher.translate]
"/Users/ghost/core" = "/home/aiden/core"

[dispatcher.host_overrides]
aiden = { stdlib_path = "/home/aiden/core/hexa-lang/stdlib" }
ubu-2 = { stdlib_path = "/home/aiden/core/hexa-lang/stdlib" }
```

variable expansion whitelist: `$HOME`, `$HEXA_HOME`, `$ANIMA`, `$NEXUS`, `$USER`.

### 2.3 `--local` flag + `HEXA_NO_REMOTE` env (RFC 028 흡수)

3-tier control:

| Surface | Effect | 우선순위 |
|---|---|---|
| `hexa --local run X` | force local | 1 (highest) |
| `HEXA_NO_REMOTE=1` | force local | 2 |
| `hexa --remote run X` | force remote | 3 |
| `HEXA_DISPATCH=remote\|local\|auto` | per-mode | 4 |
| `.hexarc` `prefer_local=true` | default local | 5 |
| (no override) | dispatcher routing decides | 6 (lowest) |

### 2.4 dispatch diagnostic (RFC 028 Tier C)

기본 default-on, 한 줄:

```
$ hexa run script.hexa
[hexa-runtime] dispatching to aiden:7321 (HEXA_LOCAL=1 to disable, HEXA_QUIET_DISPATCH=1 to hide)
HOME = /home/aiden
...
```

scripts 가 stdout 파싱하는 경우 `HEXA_QUIET_DISPATCH=1` 로 끄기.

`HEXA_DISPATCH_TRACE` 는 기존 verbose 채널로 보존 (host:port + env list + translate map 전체 dump).

### 2.5 `--local-or-fail` (RFC 028 F-028-4)

local 강제 실행이 feature 부재로 불가능할 때 (e.g., Mac 바이너리에 Linux-only FFI 가 빠짐) — `--local-or-fail` 은 **silent fallback 금지**, explicit error:

```
$ hexa --local-or-fail run cuda_train.hexa
[hexa-runtime] error: --local-or-fail requested, but feature 'cuda' missing on darwin/arm64
                (would have dispatched to ubu-2; rerun without --local-or-fail to allow)
```

## §3. Falsifiers (5)

| ID | Falsifier |
|---|---|
| **F-085-ENV-PASS** | dispatch payload 에 `HEXA_*` allowlist env 가 포함되고, target 호스트의 hexa.real 환경에 주입된다. cross-host smoke: Mac 셸에서 `HEXA_LANG=/Users/ghost/core/hexa-lang hexa run stdlib_probe.hexa` → aiden 에서 `HEXA_LANG=/home/aiden/core/hexa-lang` (translated) 가 보인다. |
| **F-085-HEXARC-LOAD** | repo 루트에 `.hexarc` 가 있으면 첫 startup 에 한 번 파싱되고 `[lang]` / `[dispatcher]` / `[mem]` 섹션이 런타임 설정으로 활성화된다. `.hexarc` 없으면 기본값 (현재 행동) 유지. |
| **F-085-LOCAL-FLAG** | `hexa --local run X` 는 ALWAYS local 실행. dispatcher 가 짧게 short-circuit 됨. `uname -s` 가 invoking host 의 OS 반환. |
| **F-085-NOREMOTE-ENV** | `HEXA_NO_REMOTE=1 hexa run X` 는 `--local` 과 동일 효과. precedence rule (§2.3) 에 따라 `--remote` flag 가 동시에 있으면 `--local` flag 가 이기지만, `--remote` flag vs `HEXA_NO_REMOTE` 의 경우 `--remote` 가 이긴다 (CLI flag > env). |
| **F-085-SILENT-OFFLOAD-WARN** | dispatch 가 일어나면 stderr 첫 줄에 `[hexa-runtime] dispatching to <host>:<port> (HEXA_LOCAL=1 to disable)` 가 default-on 으로 출력된다. `HEXA_QUIET_DISPATCH=1` 로 suppress 가능. |

## §4. Acceptance gate

3 부 closure:

1. **§3 5 falsifiers** all PASS (smoke test in `tool/cross_host_smoke/`)
2. **regression**: 기존 dispatcher-only 워크로드 (anima dispatch_s126.hexa 등) 가 동일 byte-eq corpus 로 동작
3. **본 RFC 의 본문 motivation 시나리오** (Mac → aiden HEXA_LANG drop) 가 zero workaround 로 동작:
   ```
   # before (현재)
   ssh ubu1 'cd ... && HEXA_LANG=... HEXA_MEM_UNLIMITED=1 hexa run ...'

   # after
   hexa run tool/hexa_native/safetensors_smoke.hexa
   ```

## §5. Scope / non-goals

- **In**: env passthrough · `.hexarc` parser · `--local` / `--remote` / `--local-or-fail` flags · diagnostic line · precedence rules
- **Out**: dispatch routing policy 자체의 변경 (heavy → ubu 등 정책은 `[[feedback_resource_routing_ubu]]` 의 별도 도메인) · `.hexarc` 의 무한 확장 (lang/mem/dispatcher 3 섹션만; ML / GPU 설정은 별도 RFC)
- **Future**: `.hexarc` host-aware schema 의 `[host_overrides]` 가 충분히 안정되면 translate map 을 deprecate 가능

## §6. Implementation sketch

- `.hexarc` parser: `self/hexarc_parser.hexa` (TOML subset; whitelist var expansion)
- dispatcher CLI parse: `self/main.hexa` 의 dispatcher engage 전 단계에 `--local` / `--remote` / `HEXA_NO_REMOTE` / `HEXA_DISPATCH` 처리
- resource-tcp payload 확장: `stdlib/cloud/dispatch_*.hexa` 의 connection setup 메시지에 env list 추가
- diagnostic line: 기존 `HEXA_DISPATCH_TRACE` mechanism 의 한 줄을 default-on 으로 promote
- 본 RFC 는 **doc-only**; 구현은 별도 PR (single-concern, 각 mechanism 마다 분리 가능)

## §7. Migration

- 모든 surface 가 **additive** — breaking change 없음
- env passthrough opt-in (`.hexarc` 또는 `HEXA_DISPATCH_ENV_PASS=1`)
- diagnostic line default-on 이지만 `HEXA_QUIET_DISPATCH=1` 로 즉시 회피
- `--local-or-fail` 은 신규 flag — 미사용 시 영향 없음

## §8. Cross-RFC

- **RFC 026** (env passthrough + `.hexarc`): 본 RFC 의 §2.1 + §2.2 로 흡수, 별도 land 불필요
- **RFC 028** (`--local` / `HEXA_NO_REMOTE`): 본 RFC 의 §2.3 + §2.4 + §2.5 로 흡수, 별도 land 불필요
- **RFC 024** (ML runtime memory cap): `.hexarc` 의 `[mem]` 섹션이 RFC 024 의 fresh-clone UX surface 와 정렬
- **`[[reference_hexa_module_loader_env_2026_05_20]]`**: env passthrough 가 cross-host 짝, single-host 짝은 module_loader env 의 명시 export
