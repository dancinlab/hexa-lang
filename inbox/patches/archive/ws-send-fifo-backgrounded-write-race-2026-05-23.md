# `stdlib/websocket.hexa` `ws_send` — FIFO backgrounded-write 침묵 드롭 race

**Status (2026-05-25)**: RESOLVED — fix (a) (`&` 제거) 를 정공으로 구현. `ws_send`
의 FIFO write 가 이제 foreground 로 실행되고 `exec_with_status` 의 exit code 를 검사해
`return res[1] == 0` — dead reader 의 EPIPE 가 silent-swallow 대신 `false` 로 surface.
`timeout` 가용 시 `timeout 5 sh -c '…'` 로 wrap (사라진 reader 의 FIFO open() 무한
block 방지). 검증: hexa_v2 transpile OK (emit = `hexa_exec_with_status` + `res[1]==0`);
shell-level 증명 — reader 생존 → exit 0 (true) · reader 사망 → exit 124 (false, 기존엔
silent true). `stdlib/websocket.hexa` ws_send 단일 함수 패치.

**Reporter**: anima (`dancinlab/anima` downstream consumer)
**Date**: 2026-05-23
**Severity**: HIGH — 장시간 WS forwarder 가 healthy-looking counter 와 함께 데이터 silent loss
**Affected**: `stdlib/websocket.hexa:408-422` (`ws_send` websocat-backend FIFO 경로)
**Source SSOT**: `dancinlab/anima` PR #200 (`inbox/patches/broker-akida-ingest-to-deque-gap-2026-05-23.md`)
**Cycle**: anima cycle 10 / EA — `akida_bridge` → broker `/ws/akida_ingest` GAP 조사

## TL;DR

`ws_send` websocat backend 의 FIFO write 가 trailing `&` 로 backgrounded 되어, FIFO
reader(websocat stdin)가 죽어도 parent shell 도 `exec()` 도 broken-pipe 를 surface 하지
않는다. 결과적으로 `ws_send` 는 websocat subprocess 사망 후에도 영원히 `true` 를
반환하며, sender 의 forwarded-counter 는 계속 올라간다. 실측 — 1400 spikes
"forwarded" 후 peer broker 의 `STATE.akida_history` 길이는 0.

## Observation (anima 측 실측)

`HEXAD/CHAT/server/akida_bridge.hexa` 가 broker `/ws/akida_ingest` 로 spike frame 을
forward. 다음과 같이 관측됨:

- bridge 측: `forwarded` counter 매 tick 증가 → 1400 spikes 누적 (`ws_send` 매번 `true`)
- broker 측: `/ws/akida_ingest` handler `append` 코드는 정상 (line 340), `/akida/recent`
  endpoint 가 같은 deque 를 읽음 (line 165), `STATE.akida_history` maxlen=200 (line 69)
- 그러나 `STATE.akida_history` length 는 **항상 0**

Anima 측에서 falsify 한 가설 (모두 거짓):

- broker handler not appending → handler code line 340 에서 `append` 확인
- `/akida/recent` 다른 deque 참조 → 같은 `STATE.akida_history` 참조 확인
- maxlen 회전으로 인한 즉시 evict → maxlen=200 충분
- bridge frame JSON invalid → JSON parse 검증 통과
- bridge send mode binary vs text 비호환 → bridge 가 TEXT 송신, broker `receive_text` 호환

→ "ws_send 는 true 를 반환하지만 wire 에 실제로 나가지 않는다" 가 유일한 잔존 가설.

## Root cause hypothesis — backgrounded FIFO write

`stdlib/websocket.hexa:408-422`:

```hexa
pub fn ws_send(h, message: string) -> bool {
    if type_of(h) != "map" { return false }
    if to_string(h["backend"]) == "native" {
        return ws_send_native(h, message)
    }
    let in_path = to_string(h["in"])
    if len(in_path) == 0 { return false }
    let escaped = _ws_shell_escape(message + "\n")
    let _w = exec("printf %s " + escaped + " > " + _ws_shell_escape(in_path) + " &")
    return true
}
```

문제 두 가지:

1. **trailing `&` 가 write 를 backgrounded** — `printf > fifo &` 는 shell 이 즉시
   return. FIFO reader(websocat stdin)가 이미 죽었다면 broken-pipe 시그널은 backgrounded
   subshell 안에서만 발생, parent shell 도 `exec()` 의 caller 도 알 수 없다.
2. **success 판정이 shell 실행 자체** — `ws_send` 는 `exec()` 의 return 만 본다
   (사실은 `_w` 변수에 받아 무시). 이건 "shell 이 실행되었다" 만 확인하고, write 가
   commit 됐는지 / FIFO buffer 에 들어갔는지 / reader 가 살아있는지 전혀 확인 안 함.

순 효과: websocat subprocess 가 죽은 시점부터 `ws_send` 는 **영원히 SUCCESS** 보고 →
bridge 는 `/dev/null` 로 forwarding 하며 counter 만 증가 → peer broker 는 아무것도 못
받음. Silent data loss with healthy-looking sender.

## Repro

```bash
# 1. websocat 을 long-lived FIFO read 로 시작
mkfifo /tmp/x
websocat ws://target < /tmp/x &
WS_PID=$!

# 2. bridge 가 ws_send 로 /tmp/x 에 backgrounded write
printf '{"hello":1}\n' > /tmp/x &

# 3. websocat 을 강제 종료
kill $WS_PID
# 또는: pkill websocat

# 4. ws_send 계속 호출 — 여전히 true 반환, frame 은 사라짐
printf '{"hello":2}\n' > /tmp/x &
# exit code 0, 그러나 peer 는 아무것도 못 받음
```

Bridge 입장에서는 `exec()` return 만 보므로 단계 4 에서도 `ws_send` → `true` → caller
가 forwarded-counter 증가시킴.

## Suggested fix (cheapest → cleanest)

### (a) Surgical — `&` 제거

```hexa
let _w = exec("printf %s " + escaped + " > " + _ws_shell_escape(in_path))
```

`&` 만 빼면 printf 가 foreground 로 실행되고, FIFO reader 가 죽었으면 parent shell 이
EPIPE 받음 → `exec()` non-zero return → `ws_send` 가 `false` 반환 → upstream caller 가
reconnect / fail-fast 가능.

C3 (honest): foreground write 는 reader 가 일시적으로 slow 일 때 ws_send 가 block 될
수 있다 (FIFO 는 reader 가 drain 할 때까지 writer 를 block). 다만 websocat 은 보통
빠르게 stdin 을 drain 하므로 실제로는 작은 문제. block-tolerance 필요한 caller 는
별도 timeout wrap 권장.

### (b) Better — native TEXT-frame 경로로 우회

`stdlib/net/websocket_native.hexa:337-345`:

```hexa
pub fn ws_send_native(h, message: string) -> bool {
    if type_of(h) != "map" { return false }
    if !h["ok"] { return false }
    let fd = to_int(h["fd"])
    if fd < 0 { return false }
    let frame = _ws_encode_frame(1, message)
    let wrote = net_write_bytes(fd, frame)
    return wrote >= 0
}
```

`_ws_encode_frame(1, message)` 가 이미 native TEXT-frame encoding 을 구현하고
`net_write_bytes` 가 fd 에 직접 쓰므로 FIFO 우회 + websocat subprocess 의존 제거.
`net_write_bytes` 가 EPIPE / partial-write 를 honest 하게 surface 함.

단, native backend 로 강제 전환은 caller 가 `ws_connect_native` 를 명시적으로 쓸 때만
가능 — websocat backend 를 default 로 쓰는 기존 caller 와 호환 break 가능성. 후속
upstream decision.

### (c) Belt-and-suspenders — 주기적 health-probe

매 N writes (예: 50) 마다 작은 health-probe write 를 `&` **없이** foreground 로 실행
하여 FIFO 가 살아있는지 확인. 죽었다면 caller 에게 surface. 기존 path 손대지 않고
추가 가능하지만 N 사이의 race 는 여전히 존재.

## 권장 우선순위

- **즉시**: (a) `&` 제거 — 1 character diff, behavior change 는 EPIPE-on-dead-reader
  뿐, 기존 happy-path 영향 없음
- **중기**: (b) native backend default 전환 검토 — `websocat` external dependency
  제거 + frame-level guarantee
- **(c) 는 (a) 후순위 보강** — (a) 가 race 자체를 닫으면 불필요

## Citations

`hexa-lang` (this repo):

- `hexa-lang/stdlib/websocket.hexa:408-422` — `ws_send` websocat path (this race)
- `hexa-lang/stdlib/net/websocket_native.hexa:337-345` — native TEXT encode (no FIFO race)

`dancinlab/anima` (downstream evidence):

- `HEXAD/CHAT/server/akida_bridge.hexa:162-176` — `stamp_spike` producer
- `HEXAD/CHAT/server/akida_bridge.hexa:230` — `ws_send` call site that increments the
  forwarded-counter even on silent drop
- `HEXAD/CHAT/server/broker.py:69, 163-165, 327-355` — broker side proven correct
  (`STATE.akida_history` maxlen=200, `/akida/recent` reads same deque, handler appends)

## honest C3

- Repro 가 직접 hexa-lang 측에서 재현되진 않음 — anima downstream 1400-spike silent-drop
  실측 + code-path inspection 기반의 root-cause hypothesis. (a) fix 후 anima 측 재측
  결과로 검증 필요.
- 대안 root cause (예: anima 측 broker handler 가 다른 이벤트 루프에서 실행되어 append
  가 visible 하지 않음) 는 anima PR #200 에서 모두 falsified. 잔존 가설 = ws_send-side
  silent drop.
- (a) `&` 제거가 introduces blocking 가능성은 conjectural — production 환경의
  websocat-drain-rate 측정 없이는 quantify 불가.
- severity HIGH 판정 근거: anima 는 long-lived WS forwarder (Phanes akida ingest) 가
  핵심 surface 이며 silent data loss 는 healthy 처럼 보이는 sender counter 와 결합되어
  debugging cost 가 매우 큼 — 같은 패턴 repo 전부에 영향.
