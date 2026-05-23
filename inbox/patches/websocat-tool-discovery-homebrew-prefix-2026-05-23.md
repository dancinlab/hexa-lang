# `stdlib/websocket.hexa::ws_available` — `websocat` 발견 실패 (non-interactive ssh 환경의 homebrew prefix)

## §1 — TL;DR

`stdlib/websocket.hexa::ws_available` 는 `$PATH` 만 검사 (`command -v websocat`).
non-interactive ssh 환경에서는 user login script (`.zprofile` / `.zshrc`) 가 fire
하지 않아 homebrew prefix (`/opt/homebrew/bin`, `/usr/local/bin`) 가 `$PATH` 에
들어가지 않는다. 그 결과 mini 같은 host 에서 `websocat` 가 실제로
`/opt/homebrew/bin/websocat` 에 존재함에도 daemon launch 시 `FATAL: websocat not
available` 로 silent exit.

**Suggested fix (단일)**: `ws_available` 가 known-location probe → `$PATH` fallback
순서로 동작. **`stdlib/websocket.hexa` 1회 implementation, downstream caller 무수정**.
caller workaround (PATH-prepend) 는 g11 위반 (bridge 가 launch 환경 의존).

---

## §2 — Reporter / Severity / Affected

- **Reporter**: anima cycle 10/EA evidence (`dancinlab/anima` HEXAD/CHAT/server/akida_bridge.hexa)
- **Severity**: medium — silent daemon exit at launch, deploy 자동화 일관성 깨짐
  (interactive ssh 에선 정상, 자동화 deploy 만 fail → 재현 어렵고 debug 비싸다)
- **Affected**:
  - `stdlib/websocket.hexa::ws_available` (primary)
  - 그것을 호출하는 모든 daemon (현재 알려진 첫 사례 = anima `akida_bridge.hexa`)
  - 일반화: brew-installed tool 을 PATH-probe 로 찾는 모든 stdlib fn (`nc`, `jq`, `timeout` 등 — §8 honest C3 (c))

---

## §3 — Symptom (verbatim evidence)

anima cycle 10/EA bridge restart attempt 1 의 fail log:

```
$ cat ~/anima_chat_pack/logs/akida_bridge.err
[akida_bridge] FATAL: websocat not available — install via brew install websocat
```

실제 mini host 에는 websocat 가 존재:

```
$ ssh mini -- '/opt/homebrew/bin/websocat --version'
websocat 1.13.0
```

그러나 non-interactive ssh 의 `$PATH` 가 homebrew prefix 를 누락:

```
$ ssh mini -- 'echo $PATH'
/usr/bin:/bin:/usr/sbin:/sbin
```

비교 — interactive ssh:

```
$ ssh mini
mini$ echo $PATH
/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
```

cycle 10/EA 임시 workaround (attempt 2 PASS):

```sh
ssh mini -- "export PATH=\"/opt/homebrew/bin:\$PATH\" && nohup hexa run akida_bridge.hexa daemon ..."
```

---

## §4 — Root cause

`stdlib/websocket.hexa::ws_available` 의 실제 구현 (line 92-99):

```hexa
pub fn ws_available() {
    let result = #{}
    let ws = to_string(exec("command -v websocat >/dev/null 2>&1 && echo y || echo n")).trim()
    let py = to_string(exec("command -v python3 >/dev/null 2>&1 && echo y || echo n")).trim()
    result["websocat"] = ws == "y"
    result["python3"] = py == "y"
    result["any"] = result["websocat"] || result["python3"]
    return result
}
```

- `command -v websocat` 는 `$PATH` 만 검사
- non-interactive ssh = login script 미실행 = system default PATH = homebrew prefix 누락
- homebrew prefix injection 은 `/opt/homebrew/bin/brew shellenv` 평가 결과 — interactive shell 만 (`.zprofile` / `.zshrc` 에서 `eval "$(brew shellenv)"`) fire

결과: daemon 이 `if !ws_available()["websocat"] { FATAL }` 분기에서 false negative
종료, log file 은 0 bytes (sibling patch `proc-spawn-supervised-daemon-silent-exit.md`
의 stderr autoflush gap 도 동시작용).

---

## §5 — Suggested fix (단일, 다른 옵션 메뉴 금지 per g21)

`stdlib/websocket.hexa` 내부에 신규 helper `ws_locate_websocat() -> string` 추가,
다음 **순서로** probe 후 첫 hit 의 absolute path 반환 (no hit → empty string):

1. `/opt/homebrew/bin/websocat` — Apple Silicon homebrew (macOS arm64, 가장 흔한 dev mac)
2. `/usr/local/bin/websocat` — Intel mac homebrew + Linux 의 일반 prefix
3. `command -v websocat` fallback — Linux 의 user-installed (`~/.cargo/bin` 등)
  prefix 가 `$PATH` 에 등록된 경우 처리

probe 방법은 `exec("test -x <path> && echo y || echo n")` 형태 — websocat 를
실제로 invoke 하지 않으므로 `--version` exit-code 의존 없음 (sibling patch
`proc-spawn-supervised-daemon-silent-exit.md` §(possibly 3) 의 separate 권고와 호환).

`ws_available()` 는 신 fn 의 wrapper 로 동작 (backward compat):

```hexa
pub fn ws_locate_websocat() {
    // probe order: apple-silicon-homebrew → intel-or-linux-prefix → $PATH fallback
    let candidates = ["/opt/homebrew/bin/websocat", "/usr/local/bin/websocat"]
    for path in candidates {
        let hit = to_string(exec("test -x " + path + " && echo y || echo n")).trim()
        if hit == "y" { return path }
    }
    let path_hit = to_string(exec("command -v websocat 2>/dev/null || true")).trim()
    if path_hit != "" { return path_hit }
    return ""
}

pub fn ws_available() {
    let result = #{}
    let ws_path = ws_locate_websocat()
    let py = to_string(exec("command -v python3 >/dev/null 2>&1 && echo y || echo n")).trim()
    result["websocat"] = ws_path != ""
    result["websocat_path"] = ws_path   // NEW field — caller 가 absolute path spawn 가능
    result["python3"] = py == "y"
    result["any"] = result["websocat"] || result["python3"]
    return result
}
```

caller side: `ws_connect` / `_ws_request_response_websocat` 등 내부 호출자는
`exec("websocat ...")` → `exec(ws_available()["websocat_path"] + " ...")` 로 갱신.
downstream consumer (anima 등) 는 무수정 — 기존 boolean field `["websocat"]` 의미는 동일.

---

## §6 — Acceptance test

`selftest_ws_locate_websocat_homebrew_prefix.hexa`:

1. 현재 `$PATH` 를 강제로 `/usr/bin:/bin` 으로 restrict (homebrew prefix 제거)
2. `ws_locate_websocat()` 호출 → macOS arm64 환경에서 `/opt/homebrew/bin/websocat` 반환 (or 그 host 에 적합한 path), no-installed host 에선 empty string
3. 반환된 path 가 비어있지 않으면 `exec("<path> --version")` exit 0 + version line 한 줄 stdout 확인
4. `ws_available()["websocat"] == true` AND `ws_available()["websocat_path"]` 가 step 2 의 path 와 동일

기존 selftest 와의 회귀 점검: `_ws_request_response_websocat` path 가 absolute
path 로 spawn 해도 round-trip success (e.g. echo server) 유지.

---

## §7 — Cross-link

- **downstream (anima)**:
  - `dancinlab/anima` `HEXAD/CHAT/server/akida_bridge.hexa` — cycle 10/EA workaround
    sample case (PATH-prepend launcher patch). 이 stdlib fix landing 후 launcher
    cleanup 가능.
- **시블링 hexa-lang inbox patches** (같은 daemon hardening saga, stacked landable):
  - `proc-spawn-supervised-daemon-silent-exit.md` — `cmd_run_user_direct` exec-capture
    + setvbuf + macOS nohup-fallback (root-cause: hexa.real 가 child output buffer).
    본 patch 와 동시작용 (websocat 못 찾아 FATAL 도 0-byte log 로 가려진다).
  - `websocket-streaming-client-websocat-dependency.md` — websocat 자체 의존성 제거
    (native RFC 6455 client). 본 patch 는 그 dependency 존속 가정 하 discovery 만 fix
    (orthogonal, stack 가능).

---

## §8 — honest C3

- **(a)** Apple Silicon `/opt/homebrew` 만 verified evidence (mini = M2). Intel mac
  `/usr/local/bin` 는 homebrew 공식 prefix doc 가설 — 실측 미수행.
- **(b)** Linux 의 alternative installation (`/snap/bin`, `~/.cargo/bin`, `/usr/local/cargo/bin`,
  nix store) 미커버. `$PATH` fallback 으로 우회 가능하지만 non-interactive 환경에서
  여전히 사각 (cargo install 한 user 의 `~/.cargo/bin` 도 login script 의존).
- **(c)** 동일 패턴이 `nc`, `jq`, `timeout` 등 다른 brew-installed tool 에도 발생 가능.
  본 patch 는 **websocat 단독** scope — 일반화된 `stdlib::tool_discovery` 모듈은
  별 patch 로 분리 (단일 fix point per g21 + 1 patch ≤ 1 concern stacked-PR 원칙).
- **(d)** `ws_available()` 의 boolean field 시그니처 보존 (wrapper) — downstream caller
  가 신 `["websocat_path"]` field 마이그레이션 안 해도 무중단.
- **(e)** anima cycle 10/EA 는 launcher PATH-prepend workaround 로 즉시 복구 가능
  — 본 patch 는 **upstream cleanup** (workaround removal path), 운영 hot-fix 아님.
