/* self/runtime.h — public ABI of self/runtime.c (PHASE 1.2 first cut)
 *
 * Purpose: replace `#include "runtime.c"` in generated user.c so clang only
 * codegens user code per build; runtime.c is precompiled once to runtime.o.
 *
 * Status (d=2026-05-15): MINIMAL first cut — covers a hand-crafted ~9-fn
 *   smoke (proven 7.75× user-time speedup over `#include "runtime.c"` path,
 *   0.62 s → 0.08 s; see COMPILE-SPEED.log.tape @phase_1_2_smoke).
 *
 *   FINDING from first cut: PHASE 1.1 audit was INCOMPLETE — many `hexa_*`
 *   call sites in hexa_v2-emitted user.c are MACROS (e.g. `hexa_add` at
 *   runtime.c:4757) that expand to internal `static` helpers (`hexa_add_slow`
 *   at runtime.c:4731). To make those macros work via this header, the
 *   helpers must be de-staticized in runtime.c. Tracked as PHASE 1.2 follow-up.
 *
 *   This header currently DECLARES `hexa_add_slow` as extern; running it
 *   against an unpatched runtime.c yields a link error for `_hexa_add_slow`.
 *   Apply the de-static patch (drop `static` on runtime.c:4731) before use.
 *
 * SSOT for signatures: self/runtime.c. When that file's ABI changes, this
 * header must be re-synced (eventual goal: generate from runtime.c, not
 * hand-author).
 */

#ifndef HEXA_RUNTIME_H
#define HEXA_RUNTIME_H

#include <stdint.h>
#include <stddef.h>
#include <stdio.h>     /* hexa_v2-emitted main() calls fflush(stdout/stderr) */
#include <ctype.h>     /* user.c may call isalpha/isalnum/isdigit directly */
#include <stdlib.h>    /* exit, atoi, getenv from try/catch lowering */
#include <setjmp.h>    /* try/catch lowers to setjmp/longjmp + __hexa_try_* */
#include <math.h>      /* hexa_v2 emits direct log/sin/cos/exp calls for math intrinsics */
#include <sys/stat.h>  /* hexa_v2 emits bare mkdir(path,0755) for stdlib mkdir_p */

/* ── Tagged value layout (mirrors runtime.c lines 908–996) ── */

typedef enum {
    TAG_INT = 0, TAG_FLOAT, TAG_BOOL, TAG_STR, TAG_VOID,
    TAG_ARRAY, TAG_MAP, TAG_FN, TAG_CHAR, TAG_CLOSURE,
    TAG_VALSTRUCT
} HexaTag;

typedef struct HexaVal_       HexaVal;
typedef struct HexaValStruct  HexaValStruct;

typedef struct {
    char*    key;     /* owned strdup'd, NULL means empty slot */
    uint32_t hash;
    int      order_idx;
} HexaMapSlot;

typedef struct HexaMapTable {
    HexaMapSlot* slots;
    HexaVal*     vals;
    int          ht_cap;
    char**       order_keys;
    HexaVal*     order_vals;
    int          len;
    int          order_cap;
    int          from_arena;
} HexaMapTable;

typedef struct HexaArr { HexaVal* items; int len; int cap; }            HexaArr;
typedef struct HexaMap { HexaMapTable* tbl; int len; }                  HexaMap;
typedef struct HexaFn  { void* fn_ptr; int arity; }                     HexaFn;
typedef struct HexaClo { void* fn_ptr; int arity; HexaVal* env_box; }   HexaClo;

typedef struct HexaVal_ {
    HexaTag tag;
    union {
        int64_t        i;
        double         f;
        int            b;
        char*          s;
        HexaArr*       arr_ptr;
        HexaMap*       map_ptr;
        HexaFn*        fn_ptr_d;
        HexaClo*       clo_ptr;
        HexaValStruct* vs;
    };
} HexaVal;

/* ── Public API (tiny-program subset) ────────────────────────────────
 *   Signatures must match self/runtime.c exactly. Line refs below are
 *   the definition sites in runtime.c for cross-check.
 */

/* constructors / primitives */
HexaVal hexa_int(int64_t n);                          /* runtime.c:1231 */
HexaVal hexa_bool(int b);                             /* runtime.c:1233 */
HexaVal hexa_void(void);                              /* runtime.c:1234 */
HexaVal hexa_str(const char* s);                      /* runtime.c:1346 */
int     hexa_truthy(HexaVal v);                       /* runtime.c:4686 */
HexaVal hexa_eq(HexaVal a, HexaVal b);                /* runtime.c:4785 */
HexaVal hexa_struct_pack_map(const char* type_name, int n,
                             const char* const* keys,
                             const HexaVal* vals);    /* runtime.c:2155 */

/* Inline-cache slot — user.c declares `static HexaIC` arrays for fast field
 * lookup. Layout mirrors runtime.c:897. */
typedef struct HexaIC {
    void*    keys_ptr;
    int      len;
    int      idx;
    uint64_t hits;
    uint64_t misses;
} HexaIC;

/* arithmetic / conversion
 * NOTE: hexa_add is a MACRO in runtime.c (line 4757) that expands to a
 * hot-path int+int branch + fallback to hexa_add_slow. We must mirror the
 * macro here AND expose hexa_add_slow as extern (runtime.c patched: drop
 * `static` on line 4731).
 */
#define HX_TAG(v)        ((v).tag)
#define HX_INT(v)        ((v).i)
#define HX_INT_U(v)      ((uint64_t)(v).i)
#define HX_BOOL(v)       ((v).b)
#define HX_STR(v)        ((v).s)
#define HX_FLOAT(v)      ((v).f)
#define HX_IS_INT(v)     ((v).tag == TAG_INT)
#define HX_IS_FLOAT(v)   ((v).tag == TAG_FLOAT)
#define HX_IS_STR(v)     ((v).tag == TAG_STR)
#define HX_IS_MAP(v)     ((v).tag == TAG_MAP)
#define HX_IS_ARRAY(v)   ((v).tag == TAG_ARRAY)
#define HX_IS_FN(v)      ((v).tag == TAG_FN)
#define HX_IS_CLOSURE(v) ((v).tag == TAG_CLOSURE)
#define HX_MAP_TBL(v)    (HX_IS_MAP(v) ? (v).map_ptr->tbl : (HexaMapTable*)0)

/* HexaFn / HexaClo descriptor field accessors (read + write) */
#define HX_FN_PTR(v)         ((v).fn_ptr_d->fn_ptr)
#define HX_FN_ARITY(v)       ((v).fn_ptr_d->arity)
#define HX_CLO_PTR(v)        ((v).clo_ptr->fn_ptr)
#define HX_CLO_ARITY(v)      ((v).clo_ptr->arity)
#define HX_CLO_ENV(v)        ((v).clo_ptr->env_box)
#define HX_SET_FN_PTR_D(v, p)  ((v).fn_ptr_d = (p))
#define HX_SET_CLO_PTR_D(v, p) ((v).clo_ptr = (p))
#define HX_SET_CLO_PTR(v, p)   ((v).clo_ptr->fn_ptr = (p))
#define HX_SET_CLO_ARITY(v, n) ((v).clo_ptr->arity = (n))
#define HX_SET_CLO_ENV(v, p)   ((v).clo_ptr->env_box = (p))

HexaVal hexa_add_slow(HexaVal a, HexaVal b);          /* runtime.c:4731 (was static) */
double  __hx_to_double(HexaVal v);                    /* runtime.c:1242 (was `static inline`) */

#define hexa_add(A, B) \
    ({ HexaVal __ha = (A), __hb = (B); \
       (HX_IS_INT(__ha) && HX_IS_INT(__hb)) \
           ? hexa_int(HX_INT(__ha) + HX_INT(__hb)) \
           : hexa_add_slow(__ha, __hb); })

HexaVal hexa_to_string(HexaVal v);                    /* runtime.c: 777 (decl) */

/* I/O + program state */
void    hexa_println(HexaVal v);                      /* runtime.c:4478 */
void    hexa_set_args(int argc, char** argv);         /* runtime.c:5088 */
HexaVal hexa_args(void);                              /* runtime.c:5103 */

/* arrays */
int     hexa_len(HexaVal v);                          /* runtime.c:2042 */
HexaVal hexa_array_new(void);                         /* runtime.c:1693 */
HexaVal hexa_array_push(HexaVal arr, HexaVal item);   /* runtime.c:1809 */
HexaVal hexa_float(double f);                         /* runtime.c:1232 */

/* arithmetic (non-macro) */
HexaVal hexa_sub(HexaVal a, HexaVal b);               /* runtime.c:5483 */
HexaVal hexa_mul(HexaVal a, HexaVal b);               /* runtime.c:5488 */
HexaVal hexa_mod(HexaVal a, HexaVal b);               /* runtime.c: 770 (decl) */
HexaVal hexa_div(HexaVal a, HexaVal b);               /* runtime.c:5501 */
HexaVal hexa_concat_many(int n, HexaVal* parts);      /* runtime.c:4774 */

/* comparisons */
HexaVal hexa_cmp_lt(HexaVal a, HexaVal b);            /* runtime.c:5537 */
HexaVal hexa_cmp_gt(HexaVal a, HexaVal b);            /* runtime.c:5544 */
HexaVal hexa_cmp_ge(HexaVal a, HexaVal b);            /* runtime.c:5558 */
HexaVal hexa_cmp_le(HexaVal a, HexaVal b);            /* runtime.c: 775 (decl) */

/* string ops */
HexaVal hexa_str_chars(HexaVal s);                    /* runtime.c:3742 */
HexaVal hexa_str_join(HexaVal arr, HexaVal sep);      /* runtime.c:5404 */
HexaVal hexa_str_split(HexaVal s, HexaVal delim);     /* runtime.c:5320 */
HexaVal hexa_str_substring(HexaVal s, HexaVal start, HexaVal end); /* runtime.c:3780 */
int     hexa_str_contains(HexaVal s, HexaVal sub);    /* runtime.c:3753 */
int64_t hexa_str_index_of(HexaVal s, HexaVal sub);    /* runtime.c:3794 */
HexaVal hexa_format_n(HexaVal fmt, HexaVal args);     /* runtime.c:5231 */
HexaVal hexa_char_code(HexaVal s, HexaVal idx);       /* runtime.c:6519 */
HexaVal rt_str_to_upper(HexaVal s);                   /* runtime.c:5390 */
HexaVal rt_str_trim(HexaVal s);                       /* runtime.c:5347 */
int     rt_str_starts_with(HexaVal s, HexaVal prefix); /* runtime.c:3766 */

/* file I/O */
HexaVal rt_read_file(HexaVal path);                   /* runtime.c:4844 */
HexaVal rt_write_file(HexaVal path, HexaVal content); /* runtime.c:4857 */
HexaVal rt_file_exists(HexaVal path);                 /* runtime.c:4877 */

/* process / shell */
HexaVal hexa_exec(HexaVal cmd);                       /* runtime.c:4153 */

/* string parsing / mutation */
HexaVal hexa_str_parse_int(HexaVal s);                /* runtime.c:6785 */
HexaVal hexa_str_replace(HexaVal s, HexaVal old, HexaVal n); /* runtime.c:5357 */

/* arena */
void    hexa_arena_reset(void);                       /* runtime.c:3076 */

/* array lifecycle */
HexaVal hexa_array_free(HexaVal arr);                 /* runtime.c:7182 */

/* ── slice family (codegen-emitted, impl in runtime.c) ─────────────
 * codegen_c2.hexa lowers array `.slice`/`.slice_fast` (lines 2909-2913,
 * 4738-4742, 4937), `str.slice` (cg_string_sym "str_slice", line 327),
 * and `tensor_slice` (lines 3542-3543, 4352) to direct `hexa_*` calls.
 * The C impls exist (runtime.c:6964/1931/6954/11456) and were
 * forward-declared ONLY in runtime.c (lines 820/822/838/860) — never
 * in runtime.h. The AOT-generated user.c TU only `#include "runtime.h"`,
 * so clang implicit-int'd them → `assigning to 'HexaVal' from
 * incompatible type 'int'` on any build transitively using them
 * (anima HEXAD/CHAT/chat_lib.hexa:2455 `ids.slice(0, nids-1)` blocker).
 * Decl-only, additive; signatures byte-match the runtime.c forward-decls.
 * Same root-cause class + fix shape as the safetensors_mmap_* decls. */
HexaVal hexa_array_slice(HexaVal arr, HexaVal start, HexaVal end);      /* runtime.c:6964 */
HexaVal hexa_array_slice_fast(HexaVal arr, HexaVal start, HexaVal end); /* runtime.c:1931 */
HexaVal hexa_str_slice(HexaVal s, HexaVal start, HexaVal end);          /* runtime.c:6954 */
HexaVal hexa_tensor_slice(HexaVal a, HexaVal lo, HexaVal hi);           /* runtime.c:11456 */

/* ── numeric: abs (codegen-emitted, impl in runtime.c) ─────────────
 * 2026-05-16: SAME decl-gap class as the slice-family / safetensors_mmap_*
 * decls above. `hexa_abs` has a runtime.c forward-decl (runtime.c:779) and
 * impl (runtime.c:5212) but was never declared in runtime.h. The
 * AOT-generated user.c TU only #include "runtime.h", so any build calling
 * abs() (anima HEXAD/CHAT/chat_lib.hexa via mitosis_hook_lib.hexa) hit
 * clang implicit-int. Decl-only, additive; byte-matches runtime.c:779. */
HexaVal hexa_abs(HexaVal v);                                            /* runtime.c:5212 */

/* container indexing */
HexaVal hexa_index_get(HexaVal container, HexaVal key); /* runtime.c:2643 */
HexaVal hexa_array_pop(HexaVal arr);                    /* runtime.c:3878 */

/* map predicates */
int     hexa_map_contains_key(HexaVal m, const char* key); /* runtime.c:2452 */

/* conversion */
const char* hexa_to_cstring(HexaVal v);                 /* runtime.c:1287 */
HexaVal hexa_index_set(HexaVal container, HexaVal key, HexaVal val); /* runtime.c:2685 */
HexaVal hexa_iter_get(HexaVal v, int64_t idx);          /* runtime.c:2673 */
HexaVal hexa_contains_poly(HexaVal obj, HexaVal arg);   /* runtime.c:6972 */
HexaVal hexa_type_of(HexaVal v);                        /* runtime.c:4704 */

/* diagnostics */
void    hexa_print_val(HexaVal v);                    /* runtime.c:4436 */
void    hexa_eprint_val(HexaVal v);                   /* runtime.c:4343 */

/* missing symbols flagged 2026-05-15 by wilson clean build against runtime.h
 * (see incoming/patches/runtime-h-incomplete-after-phase-1-3-b.md). All seven
 * are non-static functions in runtime.c — the gap was a header authoring miss,
 * not a `static` issue. Each line cites its definition for SSOT re-sync. */
HexaVal hexa_map_keys(HexaVal m);                     /* runtime.c:2430 — ordered key array */
HexaVal hexa_json_parse(HexaVal s);                   /* runtime.c:10538 — JSON → HexaVal */
HexaVal hexa_str_substr(HexaVal s, HexaVal start, HexaVal len); /* runtime.c:7495 — (start, length) overload distinct from hexa_str_substring(start, end) */
HexaVal hexa_input(HexaVal prompt);                   /* runtime.c:7616 — line-input prompt */
HexaVal hexa_read_stdin(void);                        /* runtime.c:9962 — full-stdin slurp */
HexaVal hexa_exec_with_status(HexaVal cmd);           /* runtime.c:4281 — exec returning {rc, stdout, stderr} */
HexaVal hexa_timestamp(void);                         /* runtime.c:9877 — UNIX millis */
HexaVal hexa_from_char_code(HexaVal n);               /* runtime.c:7668 — int → 1-char string */
HexaVal hexa_sleep_ms(HexaVal ms);                    /* runtime.c:10000 — non-blocking-ish sleep */
HexaVal hexa_term_winsize_rows(void);                 /* runtime.c:11340 — terminal rows (TIOCGWINSZ) */
HexaVal hexa_term_winsize_cols(void);                 /* runtime.c:11345 — terminal cols (TIOCGWINSZ) */
HexaVal hexa_term_write_str(HexaVal s);               /* runtime.c:11357 — write(2) raw bytes to STDOUT_FILENO */
HexaVal hexa_term_raw_enter(void);                    /* runtime.c:11337 — termios cfmakeraw + tcsetattr */
HexaVal hexa_term_raw_restore(void);                  /* runtime.c:11338 — restore saved termios */
HexaVal hexa_term_poll_stdin(HexaVal ms);             /* runtime.c:11351 — poll(2) STDIN for `ms` */
HexaVal hexa_term_read_byte(void);                    /* runtime.c:11355 — read(2) 1 byte from STDIN */
HexaVal hexa_term_install_sigwinch(void);             /* runtime.c:11366 — install SIGWINCH handler */
HexaVal hexa_term_sigwinch_pending(void);             /* runtime.c:11367 — drain SIGWINCH-pending flag */
HexaVal hexa_term_install_sigint(void);               /* runtime.c:11368 — install SIGINT handler */
HexaVal hexa_term_sigint_pending(void);               /* runtime.c:11369 — drain SIGINT-pending flag */
HexaVal hexa_term_getppid(void);                      /* runtime.c:11372 — getppid() as HexaVal int */
HexaVal hexa_time_ms(void);                           /* runtime.c:9889 — monotonic millis (CLOCK_MONOTONIC) */
HexaVal hexa_json_stringify(HexaVal v);               /* runtime.c:10639 — HexaVal → JSON */
HexaVal hexa_bytes_to_str_raw(HexaVal arr);           /* runtime.c:7718 — byte array → raw string */
HexaVal rt_append_file(HexaVal path, HexaVal content); /* runtime.c:9830 — fs append (HexaVal-typed wrapper) */
HexaVal rt_str_to_lower(HexaVal s);                   /* runtime.c:5407 — ASCII lowercase */

/* rt_* high-layer stdlib (runtime_hi_gen.c — autogen from runtime_hi.hexa
 * via tool/extract_runtime_hi.sh). PHASE 1.3.B (2026-05-15): de-static'd
 * so user.c → runtime.h can resolve at link time. */
HexaVal rt_str_split(HexaVal s, HexaVal delim);       /* runtime_hi_gen.c:40 */
HexaVal rt_str_lines(HexaVal s);                      /* runtime_hi_gen.c:65 — split("\n") wrapper */
HexaVal rt_str_pad_left(HexaVal s, HexaVal width, HexaVal pad);  /* runtime_hi_gen.c:72 */
HexaVal rt_str_pad_right(HexaVal s, HexaVal width, HexaVal pad); /* runtime_hi_gen.c:99 */
HexaVal rt_str_repeat(HexaVal s, HexaVal count);      /* runtime_hi_gen.c:126 */
HexaVal rt_str_center(HexaVal s, HexaVal width, HexaVal pad);    /* runtime_hi_gen.c:142 */
int     rt_str_ends_with(HexaVal s, HexaVal suffix);  /* runtime.c:3781 — non-static, int return */

HexaVal hexa_map_remove(HexaVal m, const char* key);  /* runtime.c:2606 — Robin-Hood delete */
HexaVal hexa_find_poly(HexaVal obj, HexaVal arg);     /* runtime.c:7007 — generic .find() */
HexaVal hexa_dict_keys(HexaVal m);                    /* runtime.c:9948 — alias of hexa_map_keys */
HexaVal hexa_base64_encode(HexaVal s);                /* runtime.c:10931 — RFC 4648 */
HexaVal rt_read_file_bytes(HexaVal path);             /* runtime.c:4957 — fs read → byte array */
HexaVal hexa_to_int(HexaVal v);                       /* runtime.c:5214 — coerce-to-int */

/* libsodium-backed crypto primitives (live in native/crypto_sodium.c when
 * HEXA_HAS_LIBSODIUM; codegen emits direct calls regardless, so the header
 * must declare them so user.c compiles cleanly. Link with -lsodium when used). */
HexaVal hexa_chacha20_xor(HexaVal key, HexaVal nonce, HexaVal data); /* native/crypto_sodium.c:224 */
HexaVal hexa_poly1305_onetimeauth(HexaVal key, HexaVal msg);         /* native/crypto_sodium.c:252 */
HexaVal hexa_sha256_bytes(HexaVal data);                             /* native/crypto_sodium.c:101 */
HexaVal hexa_sha256(HexaVal s_val);                                  /* native/exec_argv_sha256.c:290 */
HexaVal hexa_sha256_file(HexaVal path_val);                          /* native/exec_argv_sha256.c:303 */
HexaVal hexa_ed25519_verify(HexaVal pub, HexaVal msg, HexaVal sig);  /* native/crypto_sodium.c:160 */
HexaVal hexa_sha512(HexaVal data);                                   /* native/crypto_sodium.c:81 */
HexaVal hexa_ed25519_sign(HexaVal priv, HexaVal msg);                /* native/crypto_sodium.c:135 */
HexaVal hexa_x25519_keypair(void);                                   /* native/crypto_sodium.c:181 */
HexaVal hexa_x25519_scalarmult(HexaVal scalar, HexaVal point);       /* native/crypto_sodium.c:198 */
HexaVal hexa_aes256_ctr_xor(HexaVal key, HexaVal iv, HexaVal data);  /* native/crypto_openssl.c:20 (HEXA_HAS_OPENSSL) */
HexaVal hexa_bcrypt_pbkdf(HexaVal pass, HexaVal salt, HexaVal rounds, HexaVal keylen); /* native/crypto_blowfish.c:457 */

/* exec stream (long-running child process IO) */
HexaVal hexa_exec_stream_open(HexaVal cmd);                          /* runtime.c:11961 */
HexaVal hexa_exec_stream_close_stdin(HexaVal handle);                /* runtime.c:11963 */
HexaVal hexa_exec_stream_write(HexaVal handle, HexaVal data);        /* runtime.c:11962 */
/* exec_stream_* — raw-symbol variants (no hexa_ prefix) used by callers that
 * pass them through `hexa_call1(exec_stream_async, …)` _Generic dispatch. */
HexaVal exec_stream_async(HexaVal cmd);                              /* runtime.c:11826 */
HexaVal exec_stream_poll(HexaVal handle);                            /* runtime.c:11829 */
HexaVal exec_stream_close(HexaVal handle);                           /* runtime.c:11832 */

/* Network primitives (native/net.c — POSIX socket wrappers; codegen emits
 * direct calls so they must be declared here for clean user.c compile). */
HexaVal hexa_net_connect(HexaVal addr);                  /* native/net.c:368 — connect("host:port") → fd */
HexaVal hexa_net_write_bytes(HexaVal fd, HexaVal arr);   /* native/net.c:489 — write(fd, byte_arr) */
HexaVal hexa_net_read_bytes(HexaVal fd, HexaVal maxlen); /* native/net.c:530 — read(fd, max) → byte_arr */
HexaVal hexa_net_close(HexaVal fd);                      /* native/net.c:168 */

/* ── Additional native/*.c forward-decls (auto-generated 2026-05-15) ──
 * Sourced from grep of self/native/*.c hexa_* definitions; ensures user.c
 * compiled by hexa_v2 codegen never relies on implicit-decl. Link only
 * the platform-applicable .o files (gated by HEXA_HAS_* macros). */
/* native/crypto_sodium.c */
HexaVal hexa_ed25519_keypair(void);     /* native/crypto_sodium.c:118 */
HexaVal hexa_chacha20_poly1305_encrypt(HexaVal key_v, HexaVal nonce_v, HexaVal aad_v, HexaVal pt_v);     /* native/crypto_sodium.c:276 */
HexaVal hexa_chacha20_poly1305_decrypt(HexaVal key_v, HexaVal nonce_v, HexaVal aad_v, HexaVal ct_v);     /* native/crypto_sodium.c:308 */
HexaVal hexa_libsodium_available(void);     /* native/crypto_sodium.c:42 */

/* native/exec_argv_sha256.c */
HexaVal hexa_exec_argv(HexaVal argv_val);     /* native/exec_argv_sha256.c:174 */
HexaVal hexa_exec_argv_with_status(HexaVal argv_val);     /* native/exec_argv_sha256.c:178 */

/* native/exec_pipe.c */
HexaVal hexa_exec_pipe_open(HexaVal argv_v, HexaVal env_v);     /* native/exec_pipe.c:27 */

/* native/fp_init.c */
void hexa_fp_init(void);     /* native/fp_init.c:37 */

/* native/mount.c */
HexaVal hexa_mount(HexaVal src_v, HexaVal tgt_v, HexaVal fs_v, HexaVal flags_v, HexaVal data_v);     /* native/mount.c:27 */
HexaVal hexa_umount(HexaVal tgt_v, HexaVal flags_v);     /* native/mount.c:44 */

/* runtime.c core helpers the 2026-05-15 auto-gen grep missed (defined in
 * runtime.c but only forward-declared inside its own TU). Multi-file
 * flatten emits cross-TU calls to these, so the consuming user.c TU needs
 * the decls to avoid implicit-int → HexaVal init errors. */
HexaVal hexa_str_char_code_at(HexaVal s, HexaVal idx); /* runtime.c:3891 */
HexaVal rt_file_size(HexaVal path);                    /* runtime.c:5110 */

/* native/namespace.c */
HexaVal hexa_unshare(HexaVal flags_v);     /* native/namespace.c:37 */
HexaVal hexa_setns(HexaVal fd_v, HexaVal nstype_v);     /* native/namespace.c:48 */
HexaVal hexa_pivot_root(HexaVal new_root_v, HexaVal put_old_v);     /* native/namespace.c:59 */
HexaVal hexa_namespace_clone_const(HexaVal name_v);     /* native/namespace.c:76 */

/* native/net.c */
HexaVal hexa_net_listen(HexaVal addr_val);     /* native/net.c:129 */
HexaVal hexa_net_accept(HexaVal listen_val);     /* native/net.c:160 */
HexaVal hexa_net_set_nonblock(HexaVal fd_val);     /* native/net.c:183 */
HexaVal hexa_net_select(HexaVal fds_val, HexaVal timeout_ms_val);     /* native/net.c:206 */
HexaVal hexa_net_send_fd(HexaVal sock_v, HexaVal fd_v, HexaVal payload_v);     /* native/net.c:274 */
HexaVal hexa_net_recv_fd(HexaVal sock_v, HexaVal max_payload_v);     /* native/net.c:309 */
HexaVal hexa_net_read(HexaVal fd_val);     /* native/net.c:386 */
HexaVal hexa_net_read_n(HexaVal fd_val, HexaVal n_val);     /* native/net.c:415 */
HexaVal hexa_net_set_timeout(HexaVal fd_val, HexaVal ms_val);     /* native/net.c:447 */
HexaVal hexa_net_write(HexaVal fd_val, HexaVal data_val);     /* native/net.c:465 */

/* native/persistent_pipe.c */
HexaVal hexa_pipe_spawn(HexaVal cmd_val);     /* native/persistent_pipe.c:152 */
HexaVal hexa_pipe_send_line(HexaVal h_val, HexaVal payload_val);     /* native/persistent_pipe.c:234 */
HexaVal hexa_pipe_recv_line(HexaVal h_val, HexaVal timeout_val);     /* native/persistent_pipe.c:270 */
HexaVal hexa_pipe_close(HexaVal h_val);     /* native/persistent_pipe.c:345 */
HexaVal hexa_pipe_alive(HexaVal h_val);     /* native/persistent_pipe.c:388 */

/* native/proc_fork.c */
HexaVal hexa_proc_fork(void);     /* native/proc_fork.c:16 */
HexaVal hexa_proc_setsid(void);     /* native/proc_fork.c:22 */
HexaVal hexa_proc_reap_zombies(void);     /* native/proc_fork.c:28 */

/* native/pty.c */
HexaVal hexa_tcsetattr(HexaVal fd_v, HexaVal when_v, HexaVal attrs_v);     /* native/pty.c:117 */
HexaVal hexa_tty_isatty(HexaVal fd_v);     /* native/pty.c:145 */
HexaVal hexa_tty_ttyname(HexaVal fd_v);     /* native/pty.c:150 */
HexaVal hexa_pty_forkexec(HexaVal argv_v, HexaVal env_v, HexaVal rows_v, HexaVal cols_v);     /* native/pty.c:166 */
HexaVal hexa_pty_open(void);     /* native/pty.c:47 */
HexaVal hexa_pty_get_winsize(HexaVal fd_v);     /* native/pty.c:74 */
HexaVal hexa_pty_set_winsize(HexaVal fd_v, HexaVal r_v, HexaVal c_v, HexaVal xp_v, HexaVal yp_v);     /* native/pty.c:87 */
HexaVal hexa_tcgetattr(HexaVal fd_v);     /* native/pty.c:99 */

/* native/signal_flock.c */
HexaVal hexa_os_sig_install(HexaVal sig_val, HexaVal name_val);     /* native/signal_flock.c:103 */
HexaVal hexa_os_sig_uninstall(HexaVal sig_val);     /* native/signal_flock.c:124 */
HexaVal hexa_os_sig_current(HexaVal sig_val);     /* native/signal_flock.c:138 */
HexaVal hexa_os_sig_raise(HexaVal sig_val);     /* native/signal_flock.c:146 */
HexaVal hexa_os_sig_kill(HexaVal pid_val, HexaVal sig_val);     /* native/signal_flock.c:153 */
HexaVal hexa_os_sig_drain(void);     /* native/signal_flock.c:163 */
HexaVal hexa_os_sig_block(HexaVal arr_val);     /* native/signal_flock.c:196 */
HexaVal hexa_os_sig_unblock(HexaVal arr_val);     /* native/signal_flock.c:200 */
HexaVal hexa_os_flock_open(HexaVal path_val, HexaVal mode_val);     /* native/signal_flock.c:212 */
HexaVal hexa_os_flock_close(HexaVal fd_val);     /* native/signal_flock.c:241 */
HexaVal hexa_os_getpid(void);     /* native/signal_flock.c:252 */
HexaVal hexa_os_sig_pipe_fd(void);     /* native/signal_flock.c:97 */

/* native/tensor_kernels.c */
HexaVal hexa_f32_to_bytes_le(HexaVal val);     /* native/tensor_kernels.c:107 */
HexaVal hexa_bytes_to_f32_le(HexaVal arr, HexaVal offset);     /* native/tensor_kernels.c:120 */
HexaVal hexa_f64_to_bytes_le(HexaVal val);     /* native/tensor_kernels.c:139 */
HexaVal hexa_bytes_to_f64_le(HexaVal arr, HexaVal offset);     /* native/tensor_kernels.c:152 */
HexaVal hexa_bytes_to_f32_le_v(HexaVal arr, HexaVal offset);     /* native/tensor_kernels.c:176 */
HexaVal hexa_bytes_to_f64_le_v(HexaVal arr, HexaVal offset);     /* native/tensor_kernels.c:200 */
HexaVal hexa_struct_pack_f32(HexaVal* args, int nargs);     /* native/tensor_kernels.c:241 */
HexaVal hexa_struct_unpack_f32(HexaVal ptr, HexaVal index);     /* native/tensor_kernels.c:251 */
HexaVal hexa_tensor_new(HexaVal r, HexaVal c);     /* native/tensor_kernels.c:263 */
HexaVal hexa_tensor_randn(HexaVal r, HexaVal c);     /* native/tensor_kernels.c:272 */
HexaVal hexa_tensor_data_ptr(HexaVal tv);     /* native/tensor_kernels.c:284 */
HexaVal hexa_tensor_from_ptr(HexaVal p, HexaVal r, HexaVal c);     /* native/tensor_kernels.c:289 */
HexaVal hexa_ptr_read_f64(HexaVal ptr, HexaVal offset);     /* native/tensor_kernels.c:55 */

/* native/thread.c */
HexaVal hexa_thread_join(HexaVal tid_val);     /* native/thread.c:112 */
HexaVal hexa_channel_new(void);     /* native/thread.c:129 */
HexaVal hexa_channel_send(HexaVal ch_val, HexaVal v);     /* native/thread.c:152 */
HexaVal hexa_channel_recv(HexaVal ch_val, HexaVal timeout_ms_val);     /* native/thread.c:178 */
HexaVal hexa_channel_close(HexaVal ch_val);     /* native/thread.c:219 */
HexaVal hexa_now_ms(void);     /* native/thread.c:236 */
HexaVal hexa_thread_spawn(HexaVal fn_val, HexaVal arg_val);     /* native/thread.c:81 */

/* native/wait.c */
HexaVal hexa_proc_wait(HexaVal pid_v, HexaVal flags_v);     /* native/wait.c:21 */
HexaVal hexa_proc_wait_flag_const(HexaVal name_v);     /* native/wait.c:58 */


/* try/catch lowering (codegen emits __hexa_try_push/pop around fn bodies
 * with non-void try-blocks; __hexa_try_top is read as a saved-depth marker)
 * DE-STATIC NEEDED in runtime.c (line 4386): drop `static` on __hexa_try_top. */
extern int __hexa_try_top;                            /* runtime.c:4386 (was static) */
void    __hexa_try_push(jmp_buf* jb);                 /* runtime.c:4389 */
void    __hexa_try_cleanup(int* saved);               /* runtime.c:4396 */
HexaVal __hexa_last_error(void);                      /* runtime.c:4391 */

/* maps */
HexaVal hexa_map_new(void);                             /* runtime.c:2143 */
HexaVal hexa_map_set(HexaVal m, const char* key, HexaVal val); /* runtime.c:2254 */
HexaVal hexa_map_get(HexaVal m, const char* key);       /* runtime.c:2319 */

/* Hot-path inline-cache map lookup — MACRO that mirrors runtime.c:2409.
 * Required for hexa_v2-emitted user.c (1294 calls in hexa_cc.c alone).
 * Depends on these statics being de-staticized in runtime.c (PHASE 1.2.A.2
 * follow-up patches — without them, link fails with undefined refs):
 *   - g_hexa_ic_hits             runtime.c:2350
 *   - g_hexa_ic_stats_enabled    runtime.c:2352
 *   - hexa_map_get_ic_slow       runtime.c:2383
 */
extern uint64_t g_hexa_ic_hits;
extern int      g_hexa_ic_stats_enabled;
HexaVal         hexa_map_get_ic_slow(HexaVal m, const char* key, HexaIC* ic);

#define hexa_map_get_ic(M, KEY, IC) \
    ({ HexaVal __ic_m = (M); HexaIC* __ic = (IC); \
       (HX_MAP_TBL(__ic_m) \
        && (void*)HX_MAP_TBL(__ic_m)->order_keys == __ic->keys_ptr \
        && HX_MAP_TBL(__ic_m)->len == __ic->len \
        && __ic->idx < __ic->len) \
           ? (g_hexa_ic_stats_enabled > 0 \
              ? (__ic->hits++, g_hexa_ic_hits++, HX_MAP_TBL(__ic_m)->order_vals[__ic->idx]) \
              : HX_MAP_TBL(__ic_m)->order_vals[__ic->idx]) \
           : hexa_map_get_ic_slow(__ic_m, (KEY), __ic); })

/* misc */
HexaVal hexa_exit(HexaVal code);                        /* runtime.c:7518 */
void    hexa_throw(HexaVal err);                        /* runtime.c:4398 */
HexaVal hexa_env_var(HexaVal name);                     /* runtime.c:9608 */
HexaVal hexa_clock(void);                               /* runtime.c:6514 */
HexaVal hexa_mono_ns(void);                             /* runtime.c:10044 */
int64_t hexa_as_num(HexaVal v);                         /* runtime.c:1262 */

/* exec streaming impl decl (wrappers + _Generic macro live at the bottom
 * of this header, after hexa_fn_new is in scope). */
HexaVal hexa_exec_stream_impl(HexaVal cmd, HexaVal on_line);  /* runtime.c:4215 */

/* math */
HexaVal hexa_sqrt(HexaVal v);                           /* runtime.c:5152 */
HexaVal hexa_pow(HexaVal base, HexaVal exp);            /* runtime.c:5156 */
HexaVal hexa_rms_norm(HexaVal x, HexaVal gamma, HexaVal eps); /* runtime.c:10846 */

/* FFI (raw pointer / extern dispatch + dlopen/dlsym; latter two are
 * de-staticized to expose to runtime.h consumers — runtime.c:5658, 5782) */
HexaVal hexa_extern_call(void* fn_ptr, HexaVal* hargs, int nargs, int ret_kind); /* runtime.c:5846 */
HexaVal hexa_ptr_alloc(HexaVal size);                   /* runtime.c:6241 */
HexaVal hexa_ptr_free(HexaVal ptr, HexaVal size);       /* runtime.c:6248 */
void*   hexa_ffi_dlopen(const char* lib_name);          /* runtime.c:5658 (was static) */
void*   hexa_ffi_dlsym(void* handle, const char* symbol); /* runtime.c:5782 (was static) */

/* Tensor-kernel raw-pointer ops. DEFINED in self/native/tensor_kernels.c
 * (NOT runtime.c) — programs using these must link the tensor_kernels.o
 * artifact in addition to runtime.o. clm_train_bench / hxblas_linux /
 * m4_inference_e2e are the main consumers. */
HexaVal hexa_ptr_read_f32(HexaVal ptr, HexaVal offset);                  /* tensor_kernels.c:64 */
HexaVal hexa_ptr_read_i32(HexaVal ptr, HexaVal offset);                  /* tensor_kernels.c:73 */
HexaVal hexa_ptr_write_f32(HexaVal ptr, HexaVal offset, HexaVal val);    /* tensor_kernels.c:37 */
HexaVal hexa_ptr_write_i32(HexaVal ptr, HexaVal offset, HexaVal val);    /* tensor_kernels.c:46 */

/* string queries */
int64_t hexa_str_last_index_of(HexaVal s, HexaVal sub); /* runtime.c:3831 */

/* arena (codegen wraps fn bodies) */
void    __hexa_fn_arena_enter(void);                  /* runtime.c:3652 */
HexaVal __hexa_fn_arena_return(HexaVal ret);          /* runtime.c:3657 */

/* ── Closures + fn-pointer call dispatch (header-defined static inline)
 *
 * These mirror runtime.c:1110–1227. Stripped of internal _hx_stats_* counter
 * bumps that referenced static-in-runtime.c symbols; behavior is identical
 * from the caller's perspective (closures + fn-pointer values still create /
 * dispatch correctly), only the per-TU stat accounting differs. The runtime.c
 * TU still has the original stats-instrumented bodies for its own callers.
 *
 * Filed as fix for incoming/patches/runtime-h-incomplete-after-phase-1-3-b.md
 * (wilson stdlib/sort + event-bus folds hit `_undeclared` link errors against
 * the post-PHASE-1.3.B runtime.h surface).
 */

static inline HexaVal hexa_closure_new(void* fn_ptr, int arity, HexaVal env_arr) {
    HexaVal v = {.tag=TAG_CLOSURE};
    HX_SET_CLO_PTR_D(v, (HexaClo*)calloc(1, sizeof(HexaClo)));
    HX_SET_CLO_PTR(v, fn_ptr);
    HX_SET_CLO_ARITY(v, arity);
    HX_SET_CLO_ENV(v, (HexaVal*)malloc(sizeof(HexaVal)));
    *HX_CLO_ENV(v) = env_arr;
    return v;
}

static inline HexaVal hexa_fn_new(void* fn_ptr, int arity) {
    HexaVal v = {.tag=TAG_FN};
    HX_SET_FN_PTR_D(v, (HexaFn*)calloc(1, sizeof(HexaFn)));
    HX_FN_PTR(v) = fn_ptr;
    HX_FN_ARITY(v) = arity;
    return v;
}

static inline HexaVal hexa_closure_env(HexaVal c) {
    if (!HX_IS_CLOSURE(c) || !HX_CLO_ENV(c)) return hexa_array_new();
    return *HX_CLO_ENV(c);
}

static inline HexaVal hexa_call0(HexaVal f) {
    if (HX_IS_CLOSURE(f)) {
        HexaVal (*fp)(HexaVal) = (HexaVal(*)(HexaVal))HX_CLO_PTR(f);
        return fp(hexa_closure_env(f));
    }
    if (HX_IS_FN(f)) {
        HexaVal (*fp)(void) = (HexaVal(*)(void))HX_FN_PTR(f);
        return fp();
    }
    return hexa_void();
}

static inline HexaVal hexa_call1_hv(HexaVal f, HexaVal a1) {
    if (HX_IS_CLOSURE(f)) {
        HexaVal (*fp)(HexaVal, HexaVal) = (HexaVal(*)(HexaVal, HexaVal))HX_CLO_PTR(f);
        return fp(hexa_closure_env(f), a1);
    }
    if (HX_IS_FN(f)) {
        HexaVal (*fp)(HexaVal) = (HexaVal(*)(HexaVal))HX_FN_PTR(f);
        return fp(a1);
    }
    return hexa_void();
}
static inline HexaVal __hexa_call1_fp1(HexaVal (*fp)(HexaVal), HexaVal a1) {
    return fp(a1);
}
#define hexa_call1(f, a1) _Generic((f), \
    HexaVal: hexa_call1_hv, \
    HexaVal (*)(HexaVal): __hexa_call1_fp1, \
    default: hexa_call1_hv)((f), (a1))

static inline HexaVal hexa_call2_hv(HexaVal f, HexaVal a1, HexaVal a2) {
    if (HX_IS_CLOSURE(f)) {
        HexaVal (*fp)(HexaVal, HexaVal, HexaVal) = (HexaVal(*)(HexaVal, HexaVal, HexaVal))HX_CLO_PTR(f);
        return fp(hexa_closure_env(f), a1, a2);
    }
    if (HX_IS_FN(f)) {
        HexaVal (*fp)(HexaVal, HexaVal) = (HexaVal(*)(HexaVal, HexaVal))HX_FN_PTR(f);
        return fp(a1, a2);
    }
    return hexa_void();
}
static inline HexaVal __hexa_call2_fp2(HexaVal (*fp)(HexaVal, HexaVal), HexaVal a1, HexaVal a2) {
    return fp(a1, a2);
}
#define hexa_call2(f, a1, a2) _Generic((f), \
    HexaVal: hexa_call2_hv, \
    HexaVal (*)(HexaVal, HexaVal): __hexa_call2_fp2, \
    default: hexa_call2_hv)((f), (a1), (a2))

static inline HexaVal hexa_call3(HexaVal f, HexaVal a1, HexaVal a2, HexaVal a3) {
    if (HX_IS_CLOSURE(f)) {
        HexaVal (*fp)(HexaVal, HexaVal, HexaVal, HexaVal) = (HexaVal(*)(HexaVal, HexaVal, HexaVal, HexaVal))HX_CLO_PTR(f);
        return fp(hexa_closure_env(f), a1, a2, a3);
    }
    if (HX_IS_FN(f)) {
        HexaVal (*fp)(HexaVal, HexaVal, HexaVal) = (HexaVal(*)(HexaVal, HexaVal, HexaVal))HX_FN_PTR(f);
        return fp(a1, a2, a3);
    }
    return hexa_void();
}

static inline HexaVal hexa_call4(HexaVal f, HexaVal a1, HexaVal a2, HexaVal a3, HexaVal a4) {
    if (HX_IS_CLOSURE(f)) {
        HexaVal (*fp)(HexaVal, HexaVal, HexaVal, HexaVal, HexaVal) = (HexaVal(*)(HexaVal, HexaVal, HexaVal, HexaVal, HexaVal))HX_CLO_PTR(f);
        return fp(hexa_closure_env(f), a1, a2, a3, a4);
    }
    if (HX_IS_FN(f)) {
        HexaVal (*fp)(HexaVal, HexaVal, HexaVal, HexaVal) = (HexaVal(*)(HexaVal, HexaVal, HexaVal, HexaVal))HX_FN_PTR(f);
        return fp(a1, a2, a3, a4);
    }
    return hexa_void();
}

/* ── exec_stream wrappers (declared after hexa_fn_new is in scope) ──
 * Mirrors runtime.c:4262-4272. The hexa_v2 codegen emits
 *   `hexa_exec_stream(cmd, on_line_ident)` with a raw C fn-pointer as the
 * second arg; _Generic picks the wrap that boxes it into a TAG_FN HexaVal
 * before forwarding to hexa_exec_stream_impl. */
static inline HexaVal __hexa_exec_stream_wrap_fp(HexaVal cmd, HexaVal (*fp)(HexaVal)) {
    return hexa_exec_stream_impl(cmd, hexa_fn_new((void*)fp, 1));
}
static inline HexaVal __hexa_exec_stream_wrap_hv(HexaVal cmd, HexaVal cb) {
    return hexa_exec_stream_impl(cmd, cb);
}
#define hexa_exec_stream(cmd, cb) _Generic((cb), \
    HexaVal: __hexa_exec_stream_wrap_hv, \
    default: __hexa_exec_stream_wrap_fp)((cmd), (cb))

/* ── packed-double farr ABI (RFC 030/032/033) ──────────────────────
 * The codegen lowers farr_zeros/get/set/len/free + farr_matmul/copy to
 * direct `hexa_farr_*` calls; the runtime.h split (PHASE 1.2/1.3) must
 * declare them so the user.c TU does not implicit-int them (which would
 * otherwise mis-init `HexaVal h = hexa_farr_zeros(n)` from int). SSOT:
 * self/runtime.c. */
HexaVal hexa_farr_zeros(HexaVal n_v);                                  /* runtime.c */
HexaVal hexa_farr_get(HexaVal h_v, HexaVal i_v);                       /* runtime.c */
HexaVal hexa_farr_set(HexaVal h_v, HexaVal i_v, HexaVal x_v);          /* runtime.c */
HexaVal hexa_farr_len(HexaVal h_v);                                    /* runtime.c */
HexaVal hexa_farr_free(HexaVal h_v);                                   /* runtime.c */
HexaVal hexa_farr_matmul(HexaVal a_v, HexaVal ar_v, HexaVal ac_v,
                         HexaVal b_v, HexaVal bc_v);                    /* runtime.c — RFC 032 */
HexaVal hexa_farr_copy(HexaVal src_v);                                 /* runtime.c — RFC 033 */
HexaVal hexa_farr_add_gaussian_noise(HexaVal target_v, HexaVal sigma_v); /* runtime.c — RFC 033 */

/* ── safetensors mmap-backed zero-copy load (RFC 025) ──────────────
 * codegen_c2.hexa lowers safetensors_mmap_* builtins to direct
 * `hexa_safetensors_mmap_*` calls (1-arg: open/header/data_offset/
 * size/close; 3-arg: read_f32_farr/read_bf16_to_f32_farr/read_bytes).
 * Same runtime.h-split contract as the farr ABI above: the generated
 * user.c TU only #include "runtime.h", so without these prototypes
 * clang implicit-ints them and mis-inits `HexaVal h = ..._open(p)`
 * from int (anima HEXAD/CHAT/chat_lib.hexa R2 Phase-5 wire blocker).
 * Bodies (SSOT) + interp fn_shim carriers: self/runtime.c. */
HexaVal hexa_safetensors_mmap_open(HexaVal path_v);                    /* runtime.c — RFC 025 */
HexaVal hexa_safetensors_mmap_header(HexaVal h_v);                     /* runtime.c — RFC 025 */
HexaVal hexa_safetensors_mmap_data_offset(HexaVal h_v);               /* runtime.c — RFC 025 */
HexaVal hexa_safetensors_mmap_size(HexaVal h_v);                       /* runtime.c — RFC 025 */
HexaVal hexa_safetensors_mmap_read_f32_farr(HexaVal h_v, HexaVal off_v,
                                            HexaVal n_v);              /* runtime.c — RFC 025 */
HexaVal hexa_safetensors_mmap_read_bf16_to_f32_farr(HexaVal h_v,
                                                    HexaVal off_v,
                                                    HexaVal n_v);      /* runtime.c — RFC 025 */
HexaVal hexa_safetensors_mmap_read_bytes(HexaVal h_v, HexaVal off_v,
                                         HexaVal n_v);                 /* runtime.c — RFC 025 */
HexaVal hexa_safetensors_mmap_close(HexaVal h_v);                      /* runtime.c — RFC 025 */

/* ── anima RFC 034 (2026-05-16): farr reverse-mode autograd ─────────
 * CE-softmax (closed B-D-4 Jacobian) + AdamW pure-hexa training step.
 * anima HEXAD/PLAN.md Phase 5 unblock. Definitions: self/runtime.c.
 *
 * Native impls (hexa_ad_* / hexa_adamw_step) — used by the interp
 * dispatch + a future `hexa cc --regen`'d typed codegen path. */
HexaVal hexa_ad_tape_begin(void);                                      /* runtime.c — RFC 034 */
HexaVal hexa_ad_tape_end(HexaVal tid_v);                               /* runtime.c — RFC 034 */
HexaVal hexa_ad_matmul(HexaVal a_v, HexaVal ar_v, HexaVal ac_v,
                       HexaVal b_v, HexaVal bc_v);                      /* runtime.c — RFC 034 */
HexaVal hexa_ad_softmax_cross_entropy(HexaVal logits_v, HexaVal nr_v,
                                      HexaVal nc_v, HexaVal tgt_v);     /* runtime.c — RFC 034 */
HexaVal hexa_ad_backward(HexaVal tid_v);                               /* runtime.c — RFC 034 */
HexaVal hexa_ad_grad(HexaVal param_v);                                 /* runtime.c — RFC 034 */
HexaVal hexa_adamw_step(HexaVal p_v, HexaVal g_v, HexaVal m_v, HexaVal v_v,
                        HexaVal n_v, HexaVal lr_v, HexaVal b1_v, HexaVal b2_v,
                        HexaVal eps_v, HexaVal wd_v, HexaVal t_v);      /* runtime.c — RFC 034 */
/* Generic-fallback symbols the CURRENT committed hexa_v2 codegen emits
 * (no codegen branch needed): ≤4-arg → hexa_callN(<carrier>, …) needs
 * a visible HexaVal carrier; ≥5-arg → bare ad_matmul(…)/adamw_step(…)
 * direct call needs a visible function. External linkage in runtime.c.
 * This is what makes the *compiled* smoke link with the unmodified
 * committed transpiler (no hexa_cc.c rebaseline). */
extern HexaVal ad_tape_begin;                                          /* runtime.c — RFC 034 fn carrier */
extern HexaVal ad_tape_end;                                            /* runtime.c — RFC 034 fn carrier */
extern HexaVal ad_softmax_cross_entropy;                               /* runtime.c — RFC 034 fn carrier */
extern HexaVal ad_backward;                                            /* runtime.c — RFC 034 fn carrier */
extern HexaVal ad_grad;                                                /* runtime.c — RFC 034 fn carrier */
HexaVal ad_matmul(HexaVal a, HexaVal ar, HexaVal ac,
                  HexaVal b, HexaVal bc);                               /* runtime.c — RFC 034 (5-arg direct) */
HexaVal adamw_step(HexaVal p, HexaVal g, HexaVal m, HexaVal v,
                   HexaVal n, HexaVal lr, HexaVal b1, HexaVal b2,
                   HexaVal eps, HexaVal wd, HexaVal t);                 /* runtime.c — RFC 034 (11-arg direct) */

/* ── anima RFC 035 (2026-05-16): bf16/fp16 mixed-precision training ──
 * Depends on RFC 034. bf16 storage round-trip + loss-scaled, skip-on-
 * nonfinite mixed-precision AdamW (f64 master weight, low-prec grad).
 * anima HEXAD/PLAN.md Phase 5 lower-memory D-training. Defs: runtime.c.
 * (Distinct from the 2026-05-13 internal NM-step "RFC 035" — that one
 *  is farr_simplex_*; this draft RFC's namespace is bf16/adamw_mixed.) */
HexaVal hexa_farr_to_bf16(HexaVal src_v, HexaVal dst_v, HexaVal n_v);   /* runtime.c — RFC 035 */
HexaVal hexa_farr_from_bf16(HexaVal src_v, HexaVal dst_v, HexaVal n_v); /* runtime.c — RFC 035 */
HexaVal hexa_adamw_step_mixed(HexaVal p_v, HexaVal g_v, HexaVal m_v,
                              HexaVal v_v, HexaVal n_v, HexaVal lr_v,
                              HexaVal b1_v, HexaVal b2_v, HexaVal eps_v,
                              HexaVal wd_v, HexaVal t_v, HexaVal ls_v);  /* runtime.c — RFC 035 */
extern HexaVal farr_to_bf16;                                           /* runtime.c — RFC 035 fn carrier */
extern HexaVal farr_from_bf16;                                         /* runtime.c — RFC 035 fn carrier */
HexaVal adamw_step_mixed(HexaVal p, HexaVal g, HexaVal m, HexaVal v,
                         HexaVal n, HexaVal lr, HexaVal b1, HexaVal b2,
                         HexaVal eps, HexaVal wd, HexaVal t,
                         HexaVal ls);                                   /* runtime.c — RFC 035 (12-arg direct) */

/* ── anima RFC 036 (2026-05-16): phi_rs MI/Φ byte-equal primitive ────
 * Native C replica of phi_rs::mi_from_paired_vectors + spatial-Φ
 * pipeline (deterministic numeric core). The ACTUAL phi_rs Rust FFI
 * link is a NAMED BLOCKER (phi_rs is PyO3-cdylib, no extern "C" ABI) —
 * see rfc_036 §"FFI shim (named blocker)". Defs: runtime.c. */
HexaVal hexa_phi_mi_pair(HexaVal a_v, HexaVal b_v, HexaVal n_v,
                         HexaVal nb_v);                                 /* runtime.c — RFC 036 */
HexaVal hexa_phi_spatial(HexaVal st_v, HexaVal nc_v, HexaVal dim_v,
                         HexaVal nb_v);                                 /* runtime.c — RFC 036 */
extern HexaVal phi_mi_pair;                                            /* runtime.c — RFC 036 fn carrier */
extern HexaVal phi_spatial;                                            /* runtime.c — RFC 036 fn carrier */

/* ── anima RFC 040 (2026-05-16): farr GPU/CUDA backend — Phase A scaffolding ─
 * Device-farr residence descriptor + dispatcher + CPU-fallback for the
 * GPU-routed compute path. The default build (no `-DHEXA_CUDA`) MUST be
 * byte-identical to today: every existing farr is loc=FARR_HOST with
 * d_buf=NULL, and `farr_matmul_gpu` falls back to the RFC 032 CPU
 * `farr_matmul`. With `-DHEXA_CUDA` the dispatcher signatures match but
 * the bodies remain TODO[cuda] stubs (the real cuBLAS/kernel impls are
 * a future CUDA-box cycle — Phase A scaffolding only). See
 * inbox/rfc_drafts_2026_05_12/rfc_040_farr_gpu_cuda_backend.md §"Phase A".
 *
 *   cuda_available()         -> 1 iff CUDA toolkit+device present at
 *                                runtime; else 0. No-CUDA build = 0.
 *   cuda_device_count()      -> # visible GPUs (0 = none).
 *   farr_to_device(id)       -> 1 ok / 0 err / -1 no-cuda. No-op + 1 on
 *                                CPU-fallback (caller code stays valid).
 *   farr_to_host(id)         -> mirror of farr_to_device (D2H side).
 *   farr_pin(id)             -> mark resident-on-device, do not evict.
 *   farr_device_free(id)     -> free d_buf, keep host buf.
 *   farr_matmul_gpu(A,Ar,Ac,B,Bc) -> int farr (ABI-identical to RFC 032
 *                                farr_matmul; same shape, same -1 errs;
 *                                no-CUDA → routes to CPU farr_matmul).
 *
 * Honest carve-out (AGENTS.tape g3): this scaffolding lands NO CUDA
 * kernels. The GPU paths are TODO[cuda] stubs verified on Mac via the
 * CPU-fallback equivalence — the actual cuBLAS Dgemm + kernels are the
 * next-cycle deliverable on a CUDA host. */
HexaVal hexa_cuda_available(void);                                     /* runtime.c — RFC 040 */
HexaVal hexa_cuda_device_count(void);                                  /* runtime.c — RFC 040 */
HexaVal hexa_farr_to_device(HexaVal h_v);                              /* runtime.c — RFC 040 */
HexaVal hexa_farr_to_host(HexaVal h_v);                                /* runtime.c — RFC 040 */
HexaVal hexa_farr_pin(HexaVal h_v);                                    /* runtime.c — RFC 040 */
HexaVal hexa_farr_device_free(HexaVal h_v);                            /* runtime.c — RFC 040 */
HexaVal hexa_farr_matmul_gpu(HexaVal a_v, HexaVal ar_v, HexaVal ac_v,
                             HexaVal b_v, HexaVal bc_v);                /* runtime.c — RFC 040 */
/* Generic-fallback carriers (≤4-arg: `hexa_callN(<carrier>, …)`) and
 * direct-call wrappers (5-arg `farr_matmul_gpu(…)` bare). Both linked
 * external so the committed codegen's fallback path resolves cleanly. */
extern HexaVal cuda_available;                                         /* runtime.c — RFC 040 fn carrier */
extern HexaVal cuda_device_count;                                      /* runtime.c — RFC 040 fn carrier */
extern HexaVal farr_to_device;                                         /* runtime.c — RFC 040 fn carrier */
extern HexaVal farr_to_host;                                           /* runtime.c — RFC 040 fn carrier */
extern HexaVal farr_pin;                                               /* runtime.c — RFC 040 fn carrier */
extern HexaVal farr_device_free;                                       /* runtime.c — RFC 040 fn carrier */
HexaVal farr_matmul_gpu(HexaVal a, HexaVal ar, HexaVal ac,
                        HexaVal b, HexaVal bc);                         /* runtime.c — RFC 040 (5-arg direct) */

#endif /* HEXA_RUNTIME_H */
