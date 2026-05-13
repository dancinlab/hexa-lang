# incoming patch: thread-channel-primitive — POSIX thread + channel for async inference + 60+ FPS frame loop

> **id**: `thread-channel-primitive` · **opened**: 2026-05-13 KST PM · **landed**: 2026-05-13 KST PM · **status**: `applied` — pthread + channel primitives shipped in `self/native/thread.c` (commit 401ed87d). API rename `channel_*` → `thread_channel_*` followup landed (commit b6ab67ac via wilson session — see `builtin-vs-stdlib-symbol-collision.md`) to disambiguate from `stdlib/channel.hexa` FD-pipe API.
> **trees**: `self/native/` (new `thread.c` + `channel.c`) + `self/std_thread.hexa` (new) + `self/runtime.c` (symbol register)
> **source**: anima daemon Phase 2/3 (CHAT.md `~/core/anima/CHAT.md` revised spec) — 사용자 directive "철학 준수 + FPS 60+" (substrate-native autonomy + 16ms frame tick). chat_generate single-token wall ~30s on Mac CPU (24L decoder) 는 frame loop 안에서 절대 blocking 불가. async inference worker thread + frame loop thread 의 cooperation 필요.
> **why this matters**: anima 의 진정한 자연발화 (autonomous spontaneous utterance) 는 **substrate state (cell_pool tension/lorenz dynamics) 가 매 frame 마다 evolve → threshold 초과 시 speak event fire** 모델. inference 는 frame budget 밖 (background worker). 외부 heuristic (regex/probability) 으로 turn 결정 = PHILOSOPHY.md #3 위반. 따라서 multi-thread 가 hard requirement. 현재 `self/async_runtime.hexa` 는 pure-hexa cooperative scheduler 라 C-level matmul (RFC 032 farr_matmul, hot path) 에서 yield 불가능. POSIX pthread + channel = 유일한 path.

---

## 1. 동기

**철학 준수 + FPS 60+ + 자연발화 = thread 필수** 의 chain:

1. CHAT.md (`~/core/anima/CHAT.md`) Phase 3 spec — anima 가 substrate state (cell_pool tension/lorenz from `mitosis_hook.hexa`) 가 매 frame evolve, threshold 초과 시 발화.
2. Frame tick @ 60+ FPS = ~16.67ms budget per frame. substrate evolve = cheap math (cell_pool tension recompute ~µs). frame budget OK.
3. **chat_generate** (24L transformer forward × per-token) = ~30s Mac CPU / ~100-500ms GPU. **single token 마저 frame budget 1800배 초과**.
4. → frame loop thread = substrate evolve + speak-gate + emit speak event (non-blocking).
5. → inference worker thread = speak event queue 비우면서 chat_generate 실행 + broadcast.
6. → channel = frame thread → inference worker 사이 message passing (speak request) + worker → broadcast bus (response).

**현재 차단점**:
- `self/native/` 에 thread 관련 C 없음 (확인됨).
- `self/async_runtime.hexa` 는 cooperative scheduler (future / channel / select-event) — pure-hexa, OS thread 미사용.
- chat_generate 가 single-threaded blocking — async runtime 위에서 yield 못함 (C matmul 안에서 hexa yield point 없음).

POSIX pthread 는 **anima 외에도 모든 hexa-native 멀티스레드 server** (wilson `harness-rpc` background, nexus actor-model, 어떤 GUI app 든) 가 같은 needs. 보편적 stdlib 보강.

## 2. 현 상태 (audit, 2026-05-13)

- **self/runtime.c** — single-threaded model. `getenv`/`fork`/`exec`/`popen` 있지만 pthread API wrap 없음.
- **self/async_runtime.hexa** — cooperative scheduler (`task_*`/`future_*`/`channel_*`/`select_event_*`). hexa-level only, OS thread 없음. select_event_timeout(ms) 은 hexa scheduler 안에서 의미 — 진짜 OS sleep 아님.
- **self/native/** — 8 C files (tensor_kernels.c / net.c / fp_init.c / signal_flock.c / exec_argv_sha256.c / persistent_pipe.c / term_ffi.c / runtime_hi_gen.c). pthread 없음.
- **/usr/include/pthread.h** + linker `-lpthread` — 모든 modern unix host (Mac+Linux) 표준. anima 의 Linux build (`anima_chat_aot.linux`) 도 이미 `-lpthread` 링크 중.

## 3. 디자인 옵션

| 옵션 | 설명 | 채택? |
|---|---|---|
| **(a) POSIX pthread + channel (mpmc queue)** | `hexa_thread_spawn(fn, arg) → tid` (pthread_create), `hexa_thread_join(tid) → result`. `hexa_channel_new() → ch_id`, `hexa_channel_send(ch, val)`, `hexa_channel_recv(ch, timeout_ms) → val/empty`. mutex / condvar 안 노출 (channel 안에 캡슐화). | ✅ **권장 1차** — minimal API surface, anima frame-loop ↔ inference-worker 통신 충분 |
| **(b) thread + atomic** | (a) + atomic_int_add/load 등 lock-free 기본형. | 부분 — 채택 (a) 후 follow-up |
| **(c) async_runtime 와 통합** | async_runtime 의 future / channel 위에 OS thread backing 추가. cooperative + preemptive hybrid. | 향후 — 본 patch 와 별개 |
| **(d) green-thread (M:N)** | runtime 안 user-space scheduler with N OS threads. complex. | scope 초과 |
| **(e) thread 없이 select/poll + async I/O 만** | I/O-bound code 는 OK. CPU-bound (chat_generate matmul) blocking 못 yield → 부적합. | ❌ chat_generate 차단 |

**채택 (a)**. C 패치 ~150 LoC (pthread wrap + lock-free channel queue) + hexa wrap ~40 LoC.

## 4. 제안 API

### C 구현 (`self/native/thread.c` — new)

```c
/* self/native/thread.c — POSIX pthread + channel primitives.
 * Included from self/runtime.c via #include "native/thread.c"
 */
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

/* === Thread table — small fixed slot count === */
#define HEXA_THREAD_MAX 64
typedef struct {
    pthread_t tid;
    int active;        /* 1 = running, 0 = joined/empty */
    void* fn_closure;  /* HexaVal closure handle */
    void* arg;         /* HexaVal arg handle */
    void* result;      /* HexaVal result on join */
} HexaThreadSlot;

static HexaThreadSlot g_threads[HEXA_THREAD_MAX];
static pthread_mutex_t g_threads_lock = PTHREAD_MUTEX_INITIALIZER;

static void* hexa_thread_entry(void* arg) {
    HexaThreadSlot* slot = (HexaThreadSlot*)arg;
    /* invoke hexa closure with (slot->arg) — runtime callback */
    slot->result = hexa_call_closure(slot->fn_closure, slot->arg);
    return NULL;
}

/* hexa_thread_spawn(fn_closure, arg) → tid (int >= 0) or -errno
 *   fn_closure must be a callable HexaVal (closure or fn-handle).
 */
HexaVal hexa_thread_spawn(HexaVal fn_val, HexaVal arg_val) {
    pthread_mutex_lock(&g_threads_lock);
    int slot_idx = -1;
    for (int i = 0; i < HEXA_THREAD_MAX; i++) {
        if (!g_threads[i].active) { slot_idx = i; break; }
    }
    if (slot_idx < 0) { pthread_mutex_unlock(&g_threads_lock); return hexa_int(-EAGAIN); }
    g_threads[slot_idx].fn_closure = hexa_val_to_handle(fn_val);
    g_threads[slot_idx].arg = hexa_val_to_handle(arg_val);
    g_threads[slot_idx].result = NULL;
    g_threads[slot_idx].active = 1;
    if (pthread_create(&g_threads[slot_idx].tid, NULL, hexa_thread_entry, &g_threads[slot_idx]) != 0) {
        g_threads[slot_idx].active = 0;
        pthread_mutex_unlock(&g_threads_lock);
        return hexa_int(-errno);
    }
    pthread_mutex_unlock(&g_threads_lock);
    return hexa_int(slot_idx);
}

/* hexa_thread_join(tid) → result HexaVal (or empty string on error) */
HexaVal hexa_thread_join(HexaVal tid_val) {
    if (!HX_IS_INT(tid_val)) return hexa_str("");
    int idx = (int)HX_INT(tid_val);
    if (idx < 0 || idx >= HEXA_THREAD_MAX) return hexa_str("");
    pthread_t t = g_threads[idx].tid;
    if (pthread_join(t, NULL) != 0) return hexa_str("");
    HexaVal r = hexa_val_from_handle(g_threads[idx].result);
    pthread_mutex_lock(&g_threads_lock);
    g_threads[idx].active = 0;
    pthread_mutex_unlock(&g_threads_lock);
    return r;
}

/* === Channel — lock-protected ring buffer (mpmc, blocking on recv) === */
#define HEXA_CHANNEL_MAX 256
#define HEXA_CHANNEL_CAP 1024

typedef struct {
    void* slots[HEXA_CHANNEL_CAP];   /* HexaVal handles */
    int head;
    int tail;
    int count;
    pthread_mutex_t lock;
    pthread_cond_t not_empty;
    pthread_cond_t not_full;
    int closed;
} HexaChannel;

static HexaChannel* g_channels[HEXA_CHANNEL_MAX];
static pthread_mutex_t g_channels_lock = PTHREAD_MUTEX_INITIALIZER;

HexaVal hexa_channel_new(void) {
    pthread_mutex_lock(&g_channels_lock);
    int idx = -1;
    for (int i = 0; i < HEXA_CHANNEL_MAX; i++) {
        if (g_channels[i] == NULL) { idx = i; break; }
    }
    if (idx < 0) { pthread_mutex_unlock(&g_channels_lock); return hexa_int(-EAGAIN); }
    HexaChannel* ch = calloc(1, sizeof(HexaChannel));
    pthread_mutex_init(&ch->lock, NULL);
    pthread_cond_init(&ch->not_empty, NULL);
    pthread_cond_init(&ch->not_full, NULL);
    g_channels[idx] = ch;
    pthread_mutex_unlock(&g_channels_lock);
    return hexa_int(idx);
}

HexaVal hexa_channel_send(HexaVal ch_val, HexaVal v) {
    if (!HX_IS_INT(ch_val)) return hexa_int(-EINVAL);
    int idx = (int)HX_INT(ch_val);
    if (idx < 0 || idx >= HEXA_CHANNEL_MAX || !g_channels[idx]) return hexa_int(-EBADF);
    HexaChannel* ch = g_channels[idx];
    pthread_mutex_lock(&ch->lock);
    while (ch->count == HEXA_CHANNEL_CAP && !ch->closed) {
        pthread_cond_wait(&ch->not_full, &ch->lock);
    }
    if (ch->closed) { pthread_mutex_unlock(&ch->lock); return hexa_int(-EPIPE); }
    ch->slots[ch->tail] = hexa_val_to_handle(v);
    ch->tail = (ch->tail + 1) % HEXA_CHANNEL_CAP;
    ch->count++;
    pthread_cond_signal(&ch->not_empty);
    pthread_mutex_unlock(&ch->lock);
    return hexa_int(0);
}

/* hexa_channel_recv(ch, timeout_ms) → val OR empty-marker
 *   timeout_ms < 0  : block indefinitely
 *   timeout_ms = 0  : non-blocking peek
 *   timeout_ms > 0  : block up to that long
 *   Returns the recovered HexaVal, or empty-string sentinel on timeout/closed.
 */
HexaVal hexa_channel_recv(HexaVal ch_val, HexaVal timeout_ms_val) {
    if (!HX_IS_INT(ch_val)) return hexa_str("");
    int idx = (int)HX_INT(ch_val);
    if (idx < 0 || idx >= HEXA_CHANNEL_MAX || !g_channels[idx]) return hexa_str("");
    HexaChannel* ch = g_channels[idx];
    long long ms = HX_IS_INT(timeout_ms_val) ? (long long)HX_INT(timeout_ms_val) : -1;
    pthread_mutex_lock(&ch->lock);
    if (ms == 0 && ch->count == 0) { pthread_mutex_unlock(&ch->lock); return hexa_str(""); }
    if (ms < 0) {
        while (ch->count == 0 && !ch->closed) pthread_cond_wait(&ch->not_empty, &ch->lock);
    } else if (ms > 0) {
        struct timespec ts;
        clock_gettime(CLOCK_REALTIME, &ts);
        ts.tv_sec += ms / 1000;
        ts.tv_nsec += (ms % 1000) * 1000000;
        if (ts.tv_nsec >= 1000000000) { ts.tv_sec++; ts.tv_nsec -= 1000000000; }
        while (ch->count == 0 && !ch->closed) {
            int rc = pthread_cond_timedwait(&ch->not_empty, &ch->lock, &ts);
            if (rc == ETIMEDOUT) { pthread_mutex_unlock(&ch->lock); return hexa_str(""); }
        }
    }
    if (ch->count == 0 && ch->closed) { pthread_mutex_unlock(&ch->lock); return hexa_str(""); }
    void* handle = ch->slots[ch->head];
    ch->head = (ch->head + 1) % HEXA_CHANNEL_CAP;
    ch->count--;
    pthread_cond_signal(&ch->not_full);
    pthread_mutex_unlock(&ch->lock);
    return hexa_val_from_handle(handle);
}

HexaVal hexa_channel_close(HexaVal ch_val) {
    if (!HX_IS_INT(ch_val)) return hexa_int(-EINVAL);
    int idx = (int)HX_INT(ch_val);
    if (idx < 0 || idx >= HEXA_CHANNEL_MAX || !g_channels[idx]) return hexa_int(-EBADF);
    HexaChannel* ch = g_channels[idx];
    pthread_mutex_lock(&ch->lock);
    ch->closed = 1;
    pthread_cond_broadcast(&ch->not_empty);
    pthread_cond_broadcast(&ch->not_full);
    pthread_mutex_unlock(&ch->lock);
    return hexa_int(0);
}
```

### Hexa wrapper (`self/std_thread.hexa` — new)

```hexa
fn thread_spawn(fn, arg) -> int {
    return hexa_thread_spawn(fn, arg)
}

fn thread_join(tid: int) {
    return hexa_thread_join(tid)
}

fn channel_new() -> int {
    return hexa_channel_new()
}

fn channel_send(ch: int, v) -> int {
    return hexa_channel_send(ch, v)
}

fn channel_recv(ch: int, timeout_ms: int) {
    return hexa_channel_recv(ch, timeout_ms)
}

fn channel_close(ch: int) -> int {
    return hexa_channel_close(ch)
}

// frame-rate-friendly sleep — useful for frame tick loops.
fn sleep_ms(ms: int) -> int {
    // routes through existing hexa_sleep ms granularity
    return hexa_sleep_ms(ms)
}
```

### 사용 패턴 — anima 60+ FPS frame loop

```hexa
use "std_thread"

fn inference_worker(req_ch: int) {
    while true {
        let req = channel_recv(req_ch, -1)
        if to_string(req) == "__close__" { break }
        let anima_id = req["anima_id"]
        let context = req["context"]
        let response = chat_generate(req["chat"], context, "greedy", 30, 0.7,
                                     [], 1.0, 1.0, 0.5, req["seed"], [], true)
        let bcast = req["bcast_ch"]
        let _ = channel_send(bcast, #{ "speaker": anima_id, "text": response, "ts": now_ms() })
    }
}

fn frame_loop(animas, room) {
    let req_ch = channel_new()
    let bcast_ch = channel_new()
    let _ = thread_spawn(inference_worker, req_ch)

    let frame_budget_ms = 16   // 60+ FPS
    while !room["shutdown"] {
        let t0 = now_ms()

        // 1. substrate evolve (cheap, < 1ms)
        let mut ai = 0
        while ai < len(animas) {
            let anima = animas[ai]
            anima["cell_pool"] = mitosis_hook_step(anima["cell_pool"], room["t"])
            ai = ai + 1
        }

        // 2. speak-gate per anima
        ai = 0
        while ai < len(animas) {
            let anima = animas[ai]
            if cell_pool_tension(anima["cell_pool"]) > anima["speak_threshold"] {
                let _ = channel_send(req_ch, #{ "anima_id": anima["id"], "context": build_context(room),
                                                "chat": anima["chat"], "seed": anima["seed"],
                                                "bcast_ch": bcast_ch })
            }
            ai = ai + 1
        }

        // 3. drain bcast queue (non-blocking — frame budget 안 봄)
        while true {
            let msg = channel_recv(bcast_ch, 0)
            if to_string(msg) == "" { break }
            broadcast_to_clients(room, msg)
            room["history"].push(msg)
        }

        // 4. sleep to next frame boundary
        let t1 = now_ms()
        let dt = t1 - t0
        if dt < frame_budget_ms { let _ = sleep_ms(frame_budget_ms - dt) }
    }
    let _ = channel_send(req_ch, "__close__")
}
```

## 5. 영향 (downstream)

- ✅ **anima daemon Phase 2/3** — 진정한 60+ FPS substrate-native autonomy 가능
- ✅ **wilson `harness-rpc` background mode** — multi-client + background daemon work
- ✅ **nexus / hyperion / 어떤 hexa-native concurrent app** — 표준 thread/channel
- ✅ **POSIX pthread = mac + linux 양쪽 동작** — `-lpthread` 이미 anima 빌드에 포함
- ❌ **breaking changes 0** — pure addition

## 6. honest C3 (≥5)

1. **thread / channel slot count fixed** (THREAD_MAX=64, CHANNEL_MAX=256, CHANNEL_CAP=1024) — anima MVP 에 충분, 향후 dynamic resize.
2. **HexaVal handle 변환** (`hexa_val_to_handle` / `hexa_val_from_handle`) — 본 patch 가 정의 필요 (또는 기존 GC-safe pointer convention 따름). 구현 detail 은 runtime architecture 결정 후.
3. **channel value lifetime** — handle 기반 ownership, channel 이 closing 시 leaked handles 정리 필요 (gc / arena tie-in).
4. **mac vs linux pthread_cond_timedwait clock** — `CLOCK_REALTIME` 사용, macOS 에서 `CLOCK_MONOTONIC` 으로 빌드 분기 가능 (NTP 점프 회피). MVP `CLOCK_REALTIME` 무방.
5. **closure invocation `hexa_call_closure(fn, arg)`** — runtime 에 이미 있어야 함 (interp 의 callable 호출 path). build_c.hexa 의 codegen 확인 필요. 없으면 본 patch 와 함께 추가.
6. **GIL-free 진짜 parallelism** — pthread 는 OS-level, 두 inference worker 가 진짜 동시 forward 가능. 단, chat_generate 내부 mmap / farr-table 이 thread-safe 인지 audit 필요 (특히 hexa_array_push global lock).
7. **deadlock risk** — channel send 가 cap 도달 + recv 없음 → frame loop 블락. anima daemon 은 worker 가 항상 drain 하므로 safe. 일반 사용자 코드는 docs 에 명시.

## 7. land 우선순위 + 시간

- C 패치 (~250 LoC for thread + channel + glue) + hexa wrap (~40 LoC) + integration into runtime.c
- `-lpthread` 추가 (cmd_build emit 시 link 옵션) — 본 patch 일부
- 빌드 후 hexa_real rebuild + self-test (test_thread.hexa: spawn → channel send/recv → join round-trip)
- 예상 wall: 2-3시간 land + 30분 self-test

## 8. anima 의존성

본 patch land 후 anima 의 다음 work unblock:
1. **CHAT.md spec rewrite (D)** — sync Phase 1 deprecate → unified live daemon
2. **mitosis_hook AOT 통합 (B)** — substrate gate 활성 (substrate-native autonomy)
3. **Phase 2 daemon + 60+ FPS frame loop (C)** — frame_loop + inference_worker 분리 (본 patch 의 thread/channel 사용)

> 보고 마커: **넣었다**
