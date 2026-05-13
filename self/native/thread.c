/* self/native/thread.c — POSIX pthread + channel primitives.
 *
 * Included from self/runtime.c via `#include "native/thread.c"`.
 *
 * Symbols exported (8 primitives via TAG_FN shims):
 *   hexa_thread_spawn(fn_closure, arg) → tid (int >= 0) or -errno
 *   hexa_thread_join(tid)              → result HexaVal (or "" on error)
 *   hexa_channel_new()                 → ch_id (int >= 0) or -errno
 *   hexa_channel_send(ch, val)         → 0 ok / -errno
 *   hexa_channel_recv(ch, timeout_ms)  → val or "" sentinel (on timeout/closed)
 *   hexa_channel_close(ch)             → 0 ok / -errno
 *   hexa_sleep_ms(ms)                  → 0 (frame-budget friendly sleep)
 *   hexa_now_ms()                      → current monotonic time in ms (int)
 *
 * RFC: ~/core/hexa-lang/incoming/patches/thread-channel-primitive.md
 * Motivation: anima daemon Phase 2 (CHAT.md rev 2) — 60+ FPS frame loop
 * needs inference offloaded to background worker thread (chat_generate
 * ~30s/token on Mac CPU 24L) while frame_loop @ 16ms tick continues.
 *
 * Slot tables fixed-size (THREAD_MAX=64, CHANNEL_MAX=256, CHANNEL_CAP=1024).
 * MVP scope — anima N<10 animas × M<100 client subscribers comfortably fits.
 */

#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <time.h>

#define HEXA_THREAD_MAX     64
#define HEXA_CHANNEL_MAX    256
#define HEXA_CHANNEL_CAP    1024

/* === Channel state === */
typedef struct HexaChannel_ {
    HexaVal slots[HEXA_CHANNEL_CAP];
    int head;
    int tail;
    int count;
    int closed;
    pthread_mutex_t lock;
    pthread_cond_t not_empty;
    pthread_cond_t not_full;
} HexaChannel;

static HexaChannel* g_channels[HEXA_CHANNEL_MAX];
static pthread_mutex_t g_channels_lock = PTHREAD_MUTEX_INITIALIZER;

/* === Thread state === */
typedef struct HexaThreadSlot_ {
    pthread_t tid;
    int active;
    HexaVal fn_val;
    HexaVal arg_val;
    HexaVal result;
    int started;
    int finished;
    pthread_mutex_t done_lock;
    pthread_cond_t done_cv;
} HexaThreadSlot;

static HexaThreadSlot g_threads[HEXA_THREAD_MAX];
static pthread_mutex_t g_threads_lock = PTHREAD_MUTEX_INITIALIZER;

/* === Thread entry — invokes closure via runtime's call mechanism === */
static void* _hexa_thread_entry(void* arg) {
    HexaThreadSlot* slot = (HexaThreadSlot*)arg;
    /* Use hexa_call1 if available (closure dispatch). 1-arg invocation.
     * NOTE: This routes through the HexaVal fn dispatch path. The fn_val
     * must be a TAG_FN HexaVal (closure or fn ptr). */
    HexaVal r = hexa_call1(slot->fn_val, slot->arg_val);
    pthread_mutex_lock(&slot->done_lock);
    slot->result = r;
    slot->finished = 1;
    pthread_cond_broadcast(&slot->done_cv);
    pthread_mutex_unlock(&slot->done_lock);
    return NULL;
}

/* hexa_thread_spawn(fn_val, arg) → tid (>= 0) or -errno */
HexaVal hexa_thread_spawn(HexaVal fn_val, HexaVal arg_val) {
    pthread_mutex_lock(&g_threads_lock);
    int idx = -1;
    for (int i = 0; i < HEXA_THREAD_MAX; i++) {
        if (!g_threads[i].active) { idx = i; break; }
    }
    if (idx < 0) {
        pthread_mutex_unlock(&g_threads_lock);
        return hexa_int(-EAGAIN);
    }
    g_threads[idx].fn_val   = fn_val;
    g_threads[idx].arg_val  = arg_val;
    g_threads[idx].result   = hexa_str("");
    g_threads[idx].started  = 1;
    g_threads[idx].finished = 0;
    pthread_mutex_init(&g_threads[idx].done_lock, NULL);
    pthread_cond_init(&g_threads[idx].done_cv, NULL);
    g_threads[idx].active = 1;
    if (pthread_create(&g_threads[idx].tid, NULL, _hexa_thread_entry, &g_threads[idx]) != 0) {
        int e = errno;
        g_threads[idx].active = 0;
        pthread_mutex_destroy(&g_threads[idx].done_lock);
        pthread_cond_destroy(&g_threads[idx].done_cv);
        pthread_mutex_unlock(&g_threads_lock);
        return hexa_int(-e);
    }
    pthread_mutex_unlock(&g_threads_lock);
    return hexa_int(idx);
}

/* hexa_thread_join(tid) → result HexaVal (or "" on error) */
HexaVal hexa_thread_join(HexaVal tid_val) {
    if (!HX_IS_INT(tid_val)) return hexa_str("");
    int idx = (int)HX_INT(tid_val);
    if (idx < 0 || idx >= HEXA_THREAD_MAX) return hexa_str("");
    HexaThreadSlot* slot = &g_threads[idx];
    if (!slot->active) return hexa_str("");
    if (pthread_join(slot->tid, NULL) != 0) return hexa_str("");
    HexaVal r = slot->result;
    pthread_mutex_lock(&g_threads_lock);
    pthread_mutex_destroy(&slot->done_lock);
    pthread_cond_destroy(&slot->done_cv);
    slot->active = 0;
    pthread_mutex_unlock(&g_threads_lock);
    return r;
}

/* === Channel === */
HexaVal hexa_channel_new(void) {
    pthread_mutex_lock(&g_channels_lock);
    int idx = -1;
    for (int i = 0; i < HEXA_CHANNEL_MAX; i++) {
        if (g_channels[i] == NULL) { idx = i; break; }
    }
    if (idx < 0) {
        pthread_mutex_unlock(&g_channels_lock);
        return hexa_int(-EAGAIN);
    }
    HexaChannel* ch = (HexaChannel*)calloc(1, sizeof(HexaChannel));
    if (!ch) {
        pthread_mutex_unlock(&g_channels_lock);
        return hexa_int(-ENOMEM);
    }
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
    if (ch->closed) {
        pthread_mutex_unlock(&ch->lock);
        return hexa_int(-EPIPE);
    }
    ch->slots[ch->tail] = v;
    ch->tail = (ch->tail + 1) % HEXA_CHANNEL_CAP;
    ch->count++;
    pthread_cond_signal(&ch->not_empty);
    pthread_mutex_unlock(&ch->lock);
    return hexa_int(0);
}

/* hexa_channel_recv(ch, timeout_ms) → val OR "" sentinel
 *   timeout_ms < 0  : block indefinitely
 *   timeout_ms = 0  : non-blocking peek
 *   timeout_ms > 0  : block up to that long
 */
HexaVal hexa_channel_recv(HexaVal ch_val, HexaVal timeout_ms_val) {
    if (!HX_IS_INT(ch_val)) return hexa_str("");
    int idx = (int)HX_INT(ch_val);
    if (idx < 0 || idx >= HEXA_CHANNEL_MAX || !g_channels[idx]) return hexa_str("");
    HexaChannel* ch = g_channels[idx];
    long long ms = HX_IS_INT(timeout_ms_val) ? (long long)HX_INT(timeout_ms_val) : -1;
    pthread_mutex_lock(&ch->lock);
    if (ms == 0 && ch->count == 0) {
        pthread_mutex_unlock(&ch->lock);
        return hexa_str("");
    }
    if (ms < 0) {
        while (ch->count == 0 && !ch->closed) {
            pthread_cond_wait(&ch->not_empty, &ch->lock);
        }
    } else if (ms > 0) {
        struct timespec ts;
        clock_gettime(CLOCK_REALTIME, &ts);
        ts.tv_sec  += ms / 1000;
        ts.tv_nsec += (ms % 1000) * 1000000;
        if (ts.tv_nsec >= 1000000000) { ts.tv_sec++; ts.tv_nsec -= 1000000000; }
        while (ch->count == 0 && !ch->closed) {
            int rc = pthread_cond_timedwait(&ch->not_empty, &ch->lock, &ts);
            if (rc == ETIMEDOUT) {
                pthread_mutex_unlock(&ch->lock);
                return hexa_str("");
            }
        }
    }
    if (ch->count == 0 && ch->closed) {
        pthread_mutex_unlock(&ch->lock);
        return hexa_str("");
    }
    HexaVal v = ch->slots[ch->head];
    ch->head = (ch->head + 1) % HEXA_CHANNEL_CAP;
    ch->count--;
    pthread_cond_signal(&ch->not_full);
    pthread_mutex_unlock(&ch->lock);
    return v;
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

/* === Time helpers ===
 * hexa_sleep_ms already exists in runtime.c (returns hexa_void); we reuse via
 * TAG_FN shim. Only hexa_now_ms is new (anima frame loop wall-clock query).
 */
HexaVal hexa_now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    long long ms = (long long)ts.tv_sec * 1000LL + (long long)(ts.tv_nsec / 1000000LL);
    return hexa_int((int64_t)ms);
}

/* === TAG_FN shim globals ===
 *
 * 2026-05-13 PM: The pthread+condvar channel primitives use `thread_channel_*`
 * names to avoid clobbering the older `stdlib/channel.hexa` FD-pipe channels
 * (`pub fn channel_send(fd, msg)` etc.) — both APIs are otherwise valid and
 * have separate use cases. wilson's swarm/jsonl_pool uses the FD variant;
 * anima's frame-loop ↔ inference-worker bridge (the RFC motivation) uses
 * these pthread variants. Distinct names = no clang "redefinition of
 * 'channel_close' as different kind of symbol" link error when both end up
 * in the same downstream binary.
 */
HexaVal thread_spawn;
HexaVal thread_join;
HexaVal thread_channel_new;
HexaVal thread_channel_send;
HexaVal thread_channel_recv;
HexaVal thread_channel_close;
HexaVal sleep_ms;
HexaVal now_ms;

static void _hexa_init_thread_fn_shims(void) {
    thread_spawn         = hexa_fn_new((void*)hexa_thread_spawn,         2);
    thread_join          = hexa_fn_new((void*)hexa_thread_join,          1);
    thread_channel_new   = hexa_fn_new((void*)hexa_channel_new,          0);
    thread_channel_send  = hexa_fn_new((void*)hexa_channel_send,         2);
    thread_channel_recv  = hexa_fn_new((void*)hexa_channel_recv,         2);
    thread_channel_close = hexa_fn_new((void*)hexa_channel_close,        1);
    sleep_ms             = hexa_fn_new((void*)hexa_sleep_ms,             1);
    now_ms               = hexa_fn_new((void*)hexa_now_ms,               0);
}
