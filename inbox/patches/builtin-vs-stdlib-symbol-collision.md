# incoming patch: builtin-vs-stdlib-symbol-collision — pthread `channel_*` globals collide with `stdlib/channel.hexa` FD-pipe API

> **id**: `builtin-vs-stdlib-symbol-collision` · **opened**: 2026-05-13 KST PM · **landed**: 2026-05-13 18:00 KST PM (downstream rebuild verified) · **status**: `fixed in-session — rename thread.c globals → `thread_channel_*`. RFC update + interp-side cleanup remain (see §7).`
> **trees**: `self/native/thread.c` (rename globals — DONE) · `self/hexa_full.hexa` (interp's own `fn channel_send/recv/close` for TAG_CHANNEL Val store — unchanged, no collision now) · `inbox/patches/thread-channel-primitive.md` (API rename — TODO)
> **source**: wilson `hexa build core/main.hexa -o build/Darwin-arm64/wilson` failed at clang link on Mac Darwin-arm64
> **observed**: 2026-05-13 17:25 KST PM · **fixed**: 17:55 KST PM
> **severity (was)**: blocked `hexa build` of any downstream binary that links `stdlib/channel.hexa` (the FD-pipe variant) — wilson, anything using `stdlib/jsonl_pool`.

---

## 1. Failure (verbatim, from `wilson` build on Mac)

```
=== Building core/main.hexa -> build/Darwin-arm64/wilson ===
  [flat] module_loader → /tmp/.hexa-runtime/hexa_build_expanded.…tmp.hexa
  [1/2] hexa_v2 expanded.tmp.hexa → build/artifacts/wilson.c  OK
  [2/2] clang -O2 -I .../hexa-lang/self wilson.c -o wilson
    build/artifacts/wilson.c:99:9: error: redefinition of 'sleep_ms' as different kind of symbol
       99 | HexaVal sleep_ms(HexaVal ms);
            ^
    self/native/thread.c:249:9: note: previous definition is here
      249 | HexaVal sleep_ms;
            ^
    build/artifacts/wilson.c:26354:65: error: called object type 'HexaVal' (…) is not a function or function pointer
    26354 | … channel_close(hexa_index_get(cell, __hexa_sl_1899)) …
                                                ^
    self/native/thread.c:249:9: note: previous definition is here
      249 | HexaVal channel_close;
            ^
    8 errors generated.
error: clang compile failed — binary not produced
```

`sleep_ms` 는 같은 패턴의 작은 케이스 (wilson side 에서 `pub fn sleep_ms` 폴백을 들고 있었음 — 제거하면 sleep_ms 만 해결). 하지만 **channel_close / channel_send / channel_recv 는 wilson 이 정의한 게 아니라 hexa_full.hexa 에서 옴**:

```
self/hexa_full.hexa:18807:fn channel_send(ch, item) {
self/hexa_full.hexa:18818:fn channel_recv(ch) {
self/hexa_full.hexa:18831:fn channel_close(ch) {
```

wilson 의 build flow 가 `tool/flatten_imports.hexa` 로 hexa_full.hexa 를 flatten 해서 wilson.c 에 emit 하니까, 같은 심볼이 thread.c 의 builtin 글로벌과 충돌.

## 2. Root cause (corrected)

첫 분석에서 hexa_full.hexa 의 `fn channel_send/recv/close` 가 범인이라고 적었지만 그건 인터프리터의 TAG_CHANNEL Val store 전용 (in-interp, 다른 의미)이고 wilson 의 flatten 에 포함되지 않음. **진짜 충돌은**:

- `stdlib/channel.hexa:231-448` — POSIX **FD-pipe** 채널 API: `pub fn channel_send(fd, msg)`, `channel_recv(fd, timeout_ms)`, `channel_close(fd)`, `channel_send_sync`, `channel_recv_lines`. wilson 의 `plugins/swarm/main.hexa` 가 `stdlib/jsonl_pool` 통해 사용. → 컴파일 시 wilson.c 에 함수 정의 emit.
- `self/native/thread.c:246-249` — **pthread+condvar** 채널 API 의 fn-value 글로벌: `HexaVal channel_send;` 등. → 같은 wilson.c 가 runtime.c 통해 글로벌 변수 declaration 도 받음.

→ clang: "redefinition of 'channel_close' as different kind of symbol" (글로벌 vs 함수). 의미가 다른 두 API 가 같은 이름을 점유한 게 root cause.

이전 (구) 본문 — hexa_full.hexa 가 범인이라고 적은 분석은 오인이었음. 보존:

`self/native/thread.c:246-250` 은 channel/sleep API 를 **call-by-value `HexaVal` 글로벌** 로 expose 했음 (RFC `thread-channel-primitive.md` 의 land 결과):

```c
// self/native/thread.c
HexaVal channel_new;       // line 246
HexaVal channel_send;       // 247
HexaVal channel_recv;       // 248
HexaVal channel_close;      // 249
HexaVal sleep_ms;           // 250

// 그 다음 runtime init 에서 fn-value 로 묶음:
channel_close = hexa_fn_new((void*)hexa_channel_close, 1);   // 259
sleep_ms      = hexa_fn_new((void*)hexa_sleep_ms,      1);   // 256
```

이게 옳은 ABI 디자인이긴 한데 (이래야 first-class fn-value 로 다닐 수 있음 — `let f = channel_close; f(ch)` 등), **hexa_full.hexa 의 인터프리터-측 reference impl 이 같은 이름의 `fn` 으로 남아있음**. hexa_v2 codegen 이 그 `fn` 들을 `HexaVal channel_close(HexaVal ch) { ... }` 함수로 emit 하니까 → clang: "redefinition of 'channel_close' as different kind of symbol" (global var vs function).

추가 follow-on: 클라이언트 코드가 `channel_close(cell["x"])` 를 부르면, codegen 은 `channel_close(...)` 가 fn-value 인지 함수인지 판단을 못해서 직접 `channel_close(...)` 호출문으로 emit (line 26354). 그 시점엔 thread.c 의 글로벌이 winner 라 "called object type 'HexaVal' is not a function or function pointer" 가 추가로 떠.

## 3. 해결 옵션 (3 후보)

### 옵션 A — hexa_full.hexa 에서 redundant `fn` 들 제거 (가장 작음)

```diff
- fn channel_send(ch, item) { … }
- fn channel_recv(ch) { … }
- fn channel_close(ch) { … }
```

선결 조건: hexa_full.hexa 인터프리터-pass 가 `channel_*` 를 부를 때 builtin 으로 resolve 되어야 함. 17077~17091 부근 `if method == "close" { channel_close(obj); … }` 같은 콜사이트가 builtin 으로 직접 라우팅 가능한지 확인 필요. (인터프리터 builtin table 에 `channel_close` 가 이미 등록돼 있을 가능성 높음 — sleep_ms 가 그렇듯.)

**downside**: 인터프리터의 channel impl 도 같이 사라짐 → hexa interp 모드에서 channel 사용하는 코드는 native runtime 없이 못 돌게 됨. (vs 지금: interp 가 hexa-level fallback 으로 channel 시뮬레이션 가능.)

### 옵션 B — codegen 에서 "builtin-named user fn" emit 스킵

`self/native/hexa_v2/` (또는 codegen 경로 어디든) 에서 fn 이름이 builtin global 의 등록된 이름과 같으면 그 fn 정의를 skip 하고 builtin 만 노출.

**upside**: hexa_full.hexa 안 건드림 (인터프리터 fallback 유지). 단 builtin-list 가 codegen 에 hardcoded 되는 게 단점.

### 옵션 C — hexa_full.hexa 의 인터프리터-내부 fn 들 이름 rename (`_interp_channel_close` 등)

가장 안전하지만 hexa_full.hexa 안에서 grep-replace 가 많음. 인터프리터 안 17077 부근 method-dispatch 도 같이 고쳐야 함.

→ **권장 = A** (소규모, 한 곳, 인터프리터-only channel 사용 사례는 native 가 사실상 표준이라 거의 영향 없음).

## 3.5. 채택된 fix (실제 land 됨, 2026-05-13 17:55 KST)

위 옵션들 중 어느 것도 정답이 아니었음 — 근본 원인이 stdlib vs thread.c 인 걸 알아내고 채택한 건 **D. thread.c 글로벌 rename → `thread_channel_*`**:

```diff
- HexaVal channel_new;
- HexaVal channel_send;
- HexaVal channel_recv;
- HexaVal channel_close;
+ HexaVal thread_channel_new;
+ HexaVal thread_channel_send;
+ HexaVal thread_channel_recv;
+ HexaVal thread_channel_close;
```

(`self/native/thread.c:244-262` 의 globals 와 `_hexa_init_thread_fn_shims` init 양쪽 다 rename.)

**이유**: pthread+condvar 채널은 신생 RFC (`thread-channel-primitive.md`), 사용처 없음. `stdlib/channel.hexa` FD-pipe 채널은 이미 wilson swarm/jsonl_pool 이 사용 중. 신생 쪽을 양보. 의미가 다른 두 API 가 distinct names 으로 분리되니까 "어느 channel_send 가 호출되었는가" 가 명확해진 effect.

**검증**: wilson 빌드 PASS (`./build/Darwin-arm64/wilson --version` → 28-plugin bundle), `wilson test` 17/17 PASS (pool round 추가 — `pool_doctor/propose/review/reject` smoke 통과).

## 3.5.1. 미land 후속작업 (TODO)

- **interp 측 정리** — `self/hexa_full.hexa:18807-18834` 의 `fn channel_send/recv/close` 는 interp 의 TAG_CHANNEL Val store 위한 코드. thread.c 글로벌이 더 이상 충돌하지 않으니 그대로 둬도 OK. 다만 인터프리터 코드 안에서 `channel_send(args[0], args[1])` 콜사이트 (line 9345 / 14070 / 14074 / 14079 / 17077 / 17079 / 17086 / 17091) 가 이제 pthread API 가 아닌 interp 의 `fn` 로 resolve 됨 — 의도된 동작이지만 readability 개선 차원에서 함수 이름을 `_interp_channel_*` 으로 prefix 하는 게 향후 cleaner.
- **RFC 문서 업데이트** — `inbox/patches/thread-channel-primitive.md` 의 API 예시 (`channel_new()` → `thread_channel_new()` 등) 도 같이 수정.
- **anima 등 RFC 직접 소비자** 가 land 되기 전이라 (현재 사용처 0개) 외부 break 없음. 새로운 소비자는 `thread_channel_*` 이름으로 작성.

## 4. 검증

선택한 옵션 적용 후:

```sh
cd ~/core/wilson
export HEXA_LANG=~/core/hexa-lang HEXA_SHIM_NO_DARWIN_LANDING=1
~/.hx/bin/hexa build core/main.hexa -o build/Darwin-arm64/wilson
./build/Darwin-arm64/wilson --version    # → wilson 0.0.1 + 28-plugin bundle
./build/Darwin-arm64/wilson test          # → 13/13 PASS (smoke baseline)
```

추가 회귀 가드: `wilson tool pool_doctor` (host_plugin_call 경유, channel_* 안 거침) + `wilson tool pool_propose --json '{"action":"add","host":"x"}'` (proposal 파일 작성) 가 작동해야 함.

## 5. wilson 측 워크어라운드 (이미 적용)

`core/portability.hexa:114` 의 `pub fn sleep_ms` (이전 toolchain 폴백) 제거 — 인라인 코멘트에 "[BACKLOG: drop this `fn` once every host's `hexa` has the builtin]" 라 적혀있던 그대로. 이걸 빼면 `sleep_ms` 충돌만은 해결되지만 `channel_close` 는 여전히 막힘 (hexa_full.hexa 측 fix 가 필요).

## 6. 영향 범위

- **막힌 빌드**: wilson `hexa build core/main.hexa` (Darwin-arm64). 다른 downstream (anima, nexus, …) 도 hexa_full.hexa flatten 하면 같은 증상.
- **막히지 않는 빌드**: `hexa parse <file>` (whole repo parse-clean), `hexa run <file>` (인터프리터 모드 — 글로벌-vs-fn 충돌이 native link 단계에서 일어나니까).
- **이전에 OK 였던 시점**: 같은 Mac 에서 2026-05-13 17:23 KST 빌드는 PASS. 그 뒤 toolchain 이 channel-builtins 으로 변경된 듯 (`~/.hx/bin/hexa_real` 의 native/thread.c 빌드 시점 = 그 사이).

— ghost (via wilson agent, 2026-05-13 PM)
