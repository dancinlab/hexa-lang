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
 *   call sites in hexat-emitted user.c are MACROS (e.g. `hexa_add` at
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
#include <stdio.h>     /* hexat-emitted main() calls fflush(stdout/stderr) */
#include <ctype.h>     /* user.c may call isalpha/isalnum/isdigit directly */
#include <stdlib.h>    /* exit, atoi, getenv from try/catch lowering */
#include <setjmp.h>    /* try/catch lowers to setjmp/longjmp + __hexa_try_* */
#include <math.h>      /* hexat emits direct log/sin/cos/exp calls for math intrinsics */
#include <sys/stat.h>  /* hexat emits bare mkdir(path,0755) for stdlib mkdir_p */

/* ── Tagged value layout (mirrors runtime.c lines 908–996) ── */

typedef enum {
    TAG_INT = 0, TAG_FLOAT, TAG_BOOL, TAG_STR, TAG_VOID,
    TAG_ARRAY, TAG_MAP, TAG_FN, TAG_CHAR, TAG_CLOSURE,
    TAG_VALSTRUCT,
    /* PR-2.0 (enum-to-string-codegen-emit RFC, stack PR-2/3, 2026-05-24):
     * dedicated tag for enum values so `to_string(Color::Red)` can render
     * "Color::Red" instead of "0".  PR-2.0 (this PR) only reserves the
     * tag slot + defensive `_hexa_to_string_rec` / `hexa_eq` /
     * `hexa_type_of` branches — no codegen site emits TAG_ENUM yet
     * (gen2_enum_decl still produces `#define Color_Red hexa_int(0)`).
     * Slot kept LAST to preserve existing TAG_VALSTRUCT integer value
     * (no ABI shift on any pre-built object that hard-codes the tag int). */
    TAG_ENUM
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
/* PR-2.1 (enum-to-string-codegen-emit, stack PR-2/3, 2026-05-24): TAG_ENUM
 * constructor for a single migrated unit-variant enum (Direction). `display`
 * is a codegen-emitted "<Type>::<Variant>" string literal. */
HexaVal hexa_enum_str(const char* display);           /* runtime_core.c — TAG_ENUM */
/* PROBE r14-TTTT (enum-ordering RFC, 2026-05-24): TAG_ENUM descriptor — the
 * codegen `#define <Name>_<V>` emits this. Forward-decl HexaEnumDesc as a
 * struct tag so user.c can declare static-const-initializer literals without
 * including runtime_core.c. Layout MUST mirror the definition in
 * runtime_core.c: { uint32_t magic; uint32_t variant_idx; const char* display;
 * const char* type_name; }. */
struct HexaEnumDesc;
HexaVal hexa_enum_str_v(const struct HexaEnumDesc* desc); /* runtime_core.c — TAG_ENUM w/ idx */
#ifndef HEXA_ENUM_DESC_MAGIC
#define HEXA_ENUM_DESC_MAGIC 0x484E5544U
#endif
#ifndef HEXA_ENUM_DESC_DEFINED
#define HEXA_ENUM_DESC_DEFINED 1
struct HexaEnumDesc {
    uint32_t    magic;       /* = HEXA_ENUM_DESC_MAGIC */
    uint32_t    variant_idx; /* 0-based declaration order */
    const char* display;     /* "<Type>::<Variant>" */
    const char* type_name;   /* "<Type>" — same-enum gate */
};
#endif
int     hexa_truthy(HexaVal v);                       /* runtime.c:4686 */
HexaVal hexa_eq(HexaVal a, HexaVal b);                /* runtime.c:4785 */
HexaVal hexa_struct_pack_map(const char* type_name, int n,
                             const char* const* keys,
                             const HexaVal* vals);    /* runtime.c:2155 */
HexaVal hexa_await_unwrap(HexaVal v);                 /* runtime_core.c:3046 — codegen Await emits this */

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
/* Step 3 cycle 98 — pointer-eq accessors for hexa_eq TAG_VALSTRUCT / TAG_MAP
 * branches (RUNTIME.md 잔여 #4). Raw struct-pointer access is required to
 * port the C `hexa_eq` cases that compare `HX_VS(a) == HX_VS(b)` and
 * `HX_MAP_TBL(a) == HX_MAP_TBL(b)` from hexa source via the new
 * `__vs_ptr_eq` / `__map_ptr_eq` codegen-inline builtins. The macros
 * remain header-only — no new C symbols. */
#ifndef HX_VS
#define HX_VS(v)         ((v).vs)
#endif

/* Step 3 cycle 100 — pointer-eq inline builtins for hexa_eq TAG_VALSTRUCT
 * + TAG_MAP branches (RUNTIME.md 잔여 #4, 4 of 9 branches ported). The
 * aprime_cc codegen inlines these to `hexa_bool(HX_VS(a)==HX_VS(b))` etc
 * directly at the call site (self/codegen.hexa near pow). The hexat
 * bootstrap transpiler is unaware of the inline lowering and emits
 * `hexa_call2(__vs_ptr_eq, a, b)`; the static-inline defs below satisfy
 * that indirect-call path (resolved via the `hexa_call2` _Generic
 * dispatch on `HexaVal (*)(HexaVal, HexaVal)`). Either way the lowered
 * compare is byte-identical to the legacy C body. */
#ifndef __vs_ptr_eq_DEFINED
#define __vs_ptr_eq_DEFINED
static inline HexaVal __vs_ptr_eq(HexaVal a, HexaVal b) {
    return hexa_bool((HX_VS(a)) == (HX_VS(b)));
}
#endif
#ifndef __map_ptr_eq_DEFINED
#define __map_ptr_eq_DEFINED
static inline HexaVal __map_ptr_eq(HexaVal a, HexaVal b) {
    return hexa_bool((HX_MAP_TBL(a)) == (HX_MAP_TBL(b)));
}
#endif

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
HexaVal rt_str_trim_start(HexaVal s);                 /* runtime.c:6969 */
HexaVal rt_str_trim_end(HexaVal s);                   /* runtime.c:6976 */
int     rt_str_starts_with(HexaVal s, HexaVal prefix); /* runtime.c:3766 */

/* file I/O */
HexaVal rt_read_file(HexaVal path);                   /* runtime.c:4844 */
HexaVal rt_write_file(HexaVal path, HexaVal content); /* runtime.c:4857 */
HexaVal rt_file_exists(HexaVal path);                 /* runtime.c:4877 */
HexaVal rt_read_lines(HexaVal path);                  /* runtime.c:4921 — defined but header-decl was missing → implicit-decl error in transpiled user.c */
HexaVal rt_read_bytes_at(HexaVal path, HexaVal offset, HexaVal nbytes); /* runtime_core.c:6849 — ditto */

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
 * codegen.hexa lowers array `.slice`/`.slice_fast` (lines 2909-2913,
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
HexaVal hexa_array_truncate(HexaVal arr, HexaVal new_len_v); /* runtime.c:2041 */

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
HexaVal hexa_print(HexaVal v);                        /* runtime_core.c — cycle-102 entry for `print(v)` (symmetry with hexa_eprint) */

/* missing symbols flagged 2026-05-15 by wilson clean build against runtime.h
 * (see incoming/patches/runtime-h-incomplete-after-phase-1-3-b.md). All seven
 * are non-static functions in runtime.c — the gap was a header authoring miss,
 * not a `static` issue. Each line cites its definition for SSOT re-sync. */
HexaVal hexa_map_keys(HexaVal m);                     /* runtime.c:2430 — ordered key array */
HexaVal hexa_json_parse(HexaVal s);                   /* runtime.c:10538 — JSON → HexaVal */
HexaVal hexa_str_substr(HexaVal s, HexaVal start, HexaVal len); /* runtime.c:7495 — (start, length) overload distinct from hexa_str_substring(start, end) */
HexaVal hexa_input(HexaVal prompt);                   /* runtime.c:7616 — line-input prompt */
HexaVal hexa_read_stdin(void);                        /* runtime.c:9962 — full-stdin slurp */
HexaVal hexa_exec_with_status(HexaVal cmd);           /* runtime.c:4281 — exec returning [stdout, exit_code] (2-tuple, stderr LOST → merged via 2>&1 only). DEPRECATED for new code: prefer hexa_exec_capture() which returns the canonical 3-tuple [stdout, stderr, exit_code] via pipe/fork/select. See inbox/patches/exec-with-status-3tuple-migration.md (PROBE r8). */
HexaVal hexa_exec_replace(HexaVal cmd);               /* runtime.c:4639 — execvp("/bin/sh","-c",cmd); no return on success (R7 lsp) */
HexaVal hexa_http_get(HexaVal url);                   /* runtime.c:11463 — HTTP GET (R7 Phase 4 bridges: oeis/arxiv/gw/…) */
HexaVal rt_delete_file(HexaVal path);                 /* runtime.c:10940 — unlink path (R7 Phase 3: compiler/molt) */
HexaVal hexa_list_dir(HexaVal path);                  /* runtime.c — ls -1 shellout → [entries] (R7: compiler/atlas/merger, atlas_cli) */
HexaVal hexa_timestamp(void);                         /* runtime.c:9877 — UNIX millis */
HexaVal hexa_from_char_code(HexaVal n);               /* runtime.c:7668 — int → 1-char string */
HexaVal hexa_chr_byte(HexaVal n);                     /* runtime.c — chr(N) byte-level 1-byte string (N&0xFF) */
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
HexaVal hexa_byte_len(HexaVal v);                     /* runtime.c:5326 — byte length of string/array/map */
HexaVal hexa_json_stringify(HexaVal v);               /* runtime.c:10639 — HexaVal → JSON */
HexaVal hexa_bytes_to_str_raw(HexaVal arr);           /* runtime.c:7718 — byte array → raw string */
HexaVal rt_append_file(HexaVal path, HexaVal content); /* runtime.c:9830 — fs append (HexaVal-typed wrapper) */
HexaVal rt_fs_append_atomic(HexaVal path, HexaVal data);                /* runtime.c — G5 (A2) POSIX O_APPEND atomic write(2), returns bytes_written or -errno */
HexaVal rt_fs_stat(HexaVal path);                                       /* runtime.c — G5 (B) POSIX stat(2), returns [size, mtime_ns, is_dir, mode] or void */
HexaVal rt_fs_rotate_if_over(HexaVal path, HexaVal max_bytes, HexaVal suffix); /* runtime.c — G5 (B) single-proc atomic rotate via rename(2) */
HexaVal rt_fs_mkdir_p(HexaVal path);                                    /* runtime.c — G5 (B) POSIX mkdir(2) loop, fork-free */
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
HexaVal __fd_write_bytes(HexaVal fd, HexaVal s);      /* runtime.c — Step 5 #4 POSIX write(2) shim */
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
HexaVal hexa_sha1(HexaVal s_val);                                    /* native/exec_argv_sha256.c — 40-char lowercase hex (RFC 6455 WS handshake) */
HexaVal hexa_sha1_bytes(HexaVal s_val);                              /* native/exec_argv_sha256.c — raw 20-byte digest (binary-safe) */
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
HexaVal hexa_net_read_raw(HexaVal fd, HexaVal len);      /* native/net.c — RFC 093 R4: read EXACTLY len bytes → byte_arr (NUL-preserving) */
HexaVal hexa_os_getuid(void);                            /* native/net.c — RFC 093 R4: getuid(2) → Int */
HexaVal hexa_net_close(HexaVal fd);                      /* native/net.c:168 */

/* ── Additional native/*.c forward-decls (auto-generated 2026-05-15) ──
 * Sourced from grep of self/native/*.c hexa_* definitions; ensures user.c
 * compiled by hexat codegen never relies on implicit-decl. Link only
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
/* Five more forward-decls 2026-05-17 sweep exposed (interp-retire R5):
 * tier-2 hexa-build path errored with "call to undeclared function" on
 * runtime symbols defined-but-not-declared. Each is in runtime.c, only
 * the header was missing the prototype. */
HexaVal hexa_setenv(HexaVal name, HexaVal value);                                  /* runtime.c:10777 */
HexaVal hexa_cstring(HexaVal s);                                                   /* runtime.c:6342 */
HexaVal hexa_ptr_write(HexaVal ptr, HexaVal offset, HexaVal val);                  /* runtime.c:6556 */
HexaVal hexa_ptr_read(HexaVal ptr, HexaVal offset);                                /* runtime.c:6575 */
HexaVal hexa_range_array(HexaVal start, HexaVal end, HexaVal step, int inclusive); /* runtime.c:7388 */
HexaVal hexa_range_field(HexaVal v, const char* key);                              /* runtime.c (PROBE r14) */
int64_t hexa_str_index_of_from(HexaVal s, HexaVal sub, HexaVal start);             /* runtime.c:4112 */
HexaVal hexa_array_reverse(HexaVal arr);                                           /* runtime.c:4197 */
HexaVal hexa_array_sort(HexaVal arr);                                              /* runtime.c:4240 */
HexaVal hexa_exec_capture(HexaVal cmd);                                            /* runtime.c:10789 */
HexaVal hexa_exec_with_status3(HexaVal cmd);                                       /* runtime.c — canonical 3-tuple [stdout, stderr, exit_code]; delegates to hexa_exec_capture. New non-breaking surface for exec_with_status (PROBE r8). */
HexaVal hexa_from_cstring(HexaVal ptr);                                            /* runtime.c:6347 */
HexaVal hexa_to_float(HexaVal v);                                                  /* runtime.c:5507 */
HexaVal hexa_utc_compact_now(void);                                                /* runtime.c:11391 */
HexaVal hexa_utc_iso_now(void);                                                    /* runtime.c:11116 */
HexaVal hexa_null_coal(HexaVal a, HexaVal b);                                      /* runtime.c:1339 */
HexaVal hexa_math_lgamma(HexaVal x);                                               /* runtime.c:7963 */
/* VERIFY-KIT V4 2026-05-26 — special-function primitives via native libm. */
HexaVal hexa_math_tgamma(HexaVal x);
HexaVal hexa_math_erf(HexaVal x);
HexaVal hexa_math_erfc(HexaVal x);
HexaVal hexa_math_j0(HexaVal x);
HexaVal hexa_math_j1(HexaVal x);
/* Forward-decls exposed by interp regen (hexa_full → C → clang) — same
 * "defined-but-not-declared" class as the AOT path additions above. */
HexaVal hexa_array_truncate(HexaVal arr, HexaVal new_len_v);                       /* runtime.c:2037 */
HexaVal hexa_bin(HexaVal n);                                                       /* runtime.c:10905 */
HexaVal hexa_hex(HexaVal n);                                                       /* runtime.c:10916 */
HexaVal hexa_str_bytes(HexaVal s);                                                 /* runtime.c:817 (proto), def 4029 */
HexaVal hexa_valstruct_new_v(HexaVal, HexaVal, HexaVal, HexaVal, HexaVal,
                             HexaVal, HexaVal, HexaVal, HexaVal, HexaVal,
                             HexaVal, HexaVal);                                    /* runtime.c:884 (proto), def 2774 — 12-arg */
HexaVal rt_write_bytes(HexaVal path, HexaVal arr);                                 /* runtime.c:788 (proto), def 5196 */
HexaVal hexa_ceil(HexaVal v);                                                      /* runtime.c:5483 */
HexaVal hexa_floor(HexaVal v);                                                     /* runtime.c:5464 */
HexaVal hexa_math_isfinite(HexaVal x);                                             /* runtime.c:849 (proto) */
HexaVal hexa_math_isinf(HexaVal x);                                                /* runtime.c:848 (proto) */
HexaVal hexa_math_isnan(HexaVal x);                                                /* runtime.c:847 (proto) */
/* hexa_math_* transcendental/arith builtins — defined runtime.c:2144+ but
 * previously undeclared, causing C99 implicit-declaration build failures
 * for any AOT-compiled hexa using acos/cos/sqrt/etc. */
HexaVal hexa_math_tanh(HexaVal x);                                                 /* runtime.c:2144 */
HexaVal hexa_math_sin(HexaVal x);                                                  /* runtime.c:2145 */
HexaVal hexa_math_cos(HexaVal x);                                                  /* runtime.c:2146 */
HexaVal hexa_math_tan(HexaVal x);                                                  /* runtime.c:2147 */
HexaVal hexa_math_asin(HexaVal x);                                                 /* runtime.c:2148 */
HexaVal hexa_math_acos(HexaVal x);                                                 /* runtime.c:2149 */
HexaVal hexa_math_atan(HexaVal x);                                                 /* runtime.c:2150 */
HexaVal hexa_math_atan2(HexaVal y, HexaVal x);                                     /* runtime.c:2151 */
HexaVal hexa_math_log(HexaVal x);                                                  /* runtime.c:2152 */
HexaVal hexa_math_exp(HexaVal x);                                                  /* runtime.c:2153 */
HexaVal hexa_math_abs(HexaVal x);                                                  /* runtime.c:2154 */
HexaVal hexa_math_sqrt(HexaVal x);                                                 /* runtime.c:2155 */
HexaVal hexa_float_to_bits(HexaVal x);                                             /* f64->bits reinterpret (INBOX 2026-05-27) */
HexaVal hexa_bits_to_float(HexaVal x);                                             /* bits->f64 reinterpret (INBOX 2026-05-27) */
HexaVal hexa_math_floor(HexaVal x);                                                /* runtime.c:2156 */
HexaVal hexa_math_ceil(HexaVal x);                                                 /* runtime.c:2157 */
HexaVal hexa_random(void);                                                         /* runtime.c:2531 — PRNG [0,1) */
HexaVal hexa_math_round(HexaVal x);                                                /* runtime.c:2158 */
HexaVal hexa_math_pow(HexaVal b, HexaVal e);                                       /* runtime.c:2159 */
HexaVal hexa_math_fmod(HexaVal a, HexaVal b);                                      /* runtime.c — blocker-3 fmod-shim */
HexaVal hexa_math_min(HexaVal a, HexaVal b);                                       /* runtime.c:2160 */
HexaVal hexa_math_max(HexaVal a, HexaVal b);                                       /* runtime.c:2169 */
HexaVal hexa_str_parse_float(HexaVal s);                                           /* runtime.c:815 (proto) */

/* De-staticized 2026-05-17 (wilson P0#2 interp rebuild) — file-scope
 * `static [inline]` wrappers in runtime.c that the interp-transpiled
 * user.c calls cross-TU. Without these forward-decls clang errors
 * "call to undeclared function" / "use of undeclared identifier". */
HexaVal farr_vec_reflect(HexaVal ot, HexaVal a, HexaVal b, HexaVal s, HexaVal n);  /* runtime.c:7099 */
HexaVal farr_vec_blend(HexaVal ot, HexaVal a, HexaVal b, HexaVal s, HexaVal n);    /* runtime.c:7103 */
HexaVal farr_vertex_copy(HexaVal dh, HexaVal dv, HexaVal sh, HexaVal sv, HexaVal n); /* runtime.c:7107 */
HexaVal farr_pauli_exp_inplace(HexaVal re_v, HexaVal im_v, HexaVal alpha_v,
                               HexaVal flip_v, HexaVal zmask_v, HexaVal ymask_v,
                               HexaVal cy_v, HexaVal nq_v);                        /* runtime.c:7149 */
HexaVal farr_pauli_expectation(HexaVal re_v, HexaVal im_v, HexaVal flip_v,
                               HexaVal zmask_v, HexaVal ymask_v, HexaVal cy_v,
                               HexaVal nq_v);                                      /* runtime.c:7156 */
extern HexaVal farr_simplex_centroid;                                              /* runtime.c:7120 (fn-pointer carrier) */
extern HexaVal farr_simplex_get;                                                   /* runtime.c:7124 */
extern HexaVal farr_simplex_shrink;                                                /* runtime.c:7125 */
extern HexaVal farr_simplex_sort;                                                  /* runtime.c:7126 */
extern HexaVal bit_or;                                                             /* runtime.c:7173 (fn-pointer carrier) */
HexaVal farr_simplex_set(HexaVal sx, HexaVal v, HexaVal j, HexaVal n, HexaVal x);  /* runtime.c:7113 */
HexaVal hexa_farr_int_zeros(HexaVal n_v);                                          /* runtime.c:6878 (proto), def 8300 */
HexaVal hexa_farr_int_get(HexaVal h_v, HexaVal i_v);                               /* runtime.c:6879 (proto), def 8334 */
HexaVal hexa_farr_int_set(HexaVal h_v, HexaVal i_v, HexaVal x_v);                  /* runtime.c:6880 (proto), def 8343 */
HexaVal hexa_farr_int_len(HexaVal h_v);                                            /* runtime.c:6881 (proto), def 8354 */
HexaVal hexa_farr_int_fill_from_array(HexaVal h_v, HexaVal arr_v);                 /* runtime.c:6882 (proto), def 8365 */
HexaVal hexa_farr_int_copy(HexaVal src_v);                                         /* runtime.c:6883 (proto), def 8399 */
HexaVal hexa_farr_int_free(HexaVal h_v);                                           /* runtime.c:6885 (proto), def 8424 */
HexaVal hexa_farr_int_sum(HexaVal h_v);                                            /* runtime.c:6884 (proto), def 8417 */
HexaVal hexa_farr_pauli_expectation_batch(HexaVal re_v, HexaVal im_v,
                                          HexaVal flips_v, HexaVal zmasks_v,
                                          HexaVal ymasks_v, HexaVal counts_v,
                                          HexaVal coefs_v, HexaVal n_p_v,
                                          HexaVal nq_v);                           /* runtime.c:7090 (proto), def 8848 */
extern HexaVal ham_free;                                                           /* runtime.c:7127 (fn-pointer carrier) */
extern HexaVal ansatz_free;                                                        /* runtime.c:7128 */
HexaVal farr_uccsd_apply(HexaVal re_v, HexaVal im_v, HexaVal theta_v,
                         HexaVal ansatz_v, HexaVal nq_v);                          /* runtime.c:7136 */
HexaVal ham_pack(HexaVal flip_v, HexaVal z_v, HexaVal y_v, HexaVal cy_v,
                 HexaVal coef_v, HexaVal shift_v, HexaVal nq_v);                   /* runtime.c:7140 */
HexaVal ansatz_pack(HexaVal param_idx_v, HexaVal coef_v, HexaVal flip_v,
                    HexaVal z_v, HexaVal y_v, HexaVal cy_v,
                    HexaVal hf_v, HexaVal nq_v);                                   /* runtime.c:7145 */
HexaVal farr_parameter_shift_grad(HexaVal re_v, HexaVal im_v,
                                  HexaVal theta_v, HexaVal grad_v,
                                  HexaVal n_p_v, HexaVal ham_v,
                                  HexaVal ans_v, HexaVal nq_v);                    /* runtime.c:7150 */

/* Forward-decls exposed by the R7 measured-cutover parity gate
 * (tool/parity_interp_vs_compiled.sh) — array HOFs + string/array
 * helpers defined in runtime.c but never declared in this header, so
 * the tier-2 `hexa build` path errored "call to undeclared function"
 * (C99 implicit-decl) on test/{t43,t44,t45,t45b,t49,…}. Same
 * defined-but-not-declared class as the interp-retire R5 sweep above;
 * signatures byte-match the runtime.c definitions. */
HexaVal hexa_array_map(HexaVal arr, HexaVal fn);                                   /* runtime.c:7313 */
HexaVal hexa_array_filter(HexaVal arr, HexaVal fn);                                /* runtime.c:7322 */
HexaVal hexa_array_fold(HexaVal arr, HexaVal init, HexaVal fn);                    /* runtime.c:7332 */
HexaVal hexa_array_any(HexaVal arr, HexaVal fn);                                   /* runtime.c:7356 */
HexaVal hexa_array_all(HexaVal arr, HexaVal fn);                                   /* runtime.c:7367 */
HexaVal hexa_array_enumerate(HexaVal arr);                                         /* runtime.c:7472 */
HexaVal hexa_array_flatten(HexaVal arr);                                           /* runtime.c:7524 */
HexaVal hexa_array_fill(HexaVal arr, HexaVal v);                                   /* runtime.c:7552 */
HexaVal hexa_array_swap(HexaVal arr, HexaVal iv, HexaVal jv);                      /* runtime.c:7834 */
HexaVal hexa_array_sort_by(HexaVal arr, HexaVal key_fn);                           /* runtime.c:4270 */
HexaVal hexa_array_get(HexaVal arr, int64_t idx);                                  /* runtime.c:1981 */
HexaVal hexa_array_last(HexaVal arr);                                              /* runtime_core.c — .last() codegen, single-eval */
HexaVal hexa_str_char_at(HexaVal s, HexaVal idx);                                  /* runtime.c:4156 */
HexaVal hexa_str_char_count(HexaVal s);                                            /* runtime.c — UTF-8 codepoint count */
HexaVal hexa_str_graphemes(HexaVal s);                                             /* runtime_core.c — UAX-29 grapheme cluster substrings (r15-D10) */
HexaVal hexa_str_grapheme_count(HexaVal s);                                        /* runtime_core.c — UAX-29 grapheme cluster count (r15-D10) */
HexaVal hexa_str_nth_char(HexaVal s, HexaVal n);                                   /* runtime.c — nth codepoint as 1-cp str */
HexaVal hexa_str_char_substring(HexaVal s, HexaVal start, HexaVal end);            /* runtime.c — codepoint-indexed [start..end) substring */
HexaVal hexa_str_byte_at(HexaVal s, HexaVal idx);                                  /* runtime.c — byte at offset (0..255) or -1 OOB */
HexaVal hexa_is_empty(HexaVal v);                                                  /* runtime.c:7486 */
HexaVal hexa_sum(HexaVal a);                                                       /* runtime.c:11955 */

/* hx_* alias TAG_FN carriers — defined in native/persistent_pipe.c and
 * native/exec_argv_sha256.c, initialized at startup via _hexa_init_*_fn_shims.
 * Interp uses bare `hx_pipe_spawn` etc. (not `hexa_pipe_spawn`) as
 * fn-pointer references across the runtime.o TU boundary. */
extern HexaVal hx_setenv;                                                          /* runtime.c:12099 */
extern HexaVal hx_exec_capture;                                                    /* runtime.c:12100 */
extern HexaVal exec_with_status3;                                                  /* runtime.c - PROBE r8 3-tuple bare-ident bridge (regen-gated; pre-regen hexat emits hexa_call1(exec_with_status3,...)) */
extern HexaVal hx_pipe_spawn;                                                      /* native/persistent_pipe.c:415 */
extern HexaVal hx_pipe_send_line;                                                  /* native/persistent_pipe.c:416 */
extern HexaVal hx_pipe_recv_line;                                                  /* native/persistent_pipe.c:417 */
extern HexaVal hx_pipe_close;                                                      /* native/persistent_pipe.c:418 */
extern HexaVal hx_pipe_alive;                                                      /* native/persistent_pipe.c:419 */
extern HexaVal hx_exec_argv;                                                       /* native/exec_argv_sha256.c:331 */
extern HexaVal hx_exec_argv_with_status;                                           /* native/exec_argv_sha256.c:332 */
extern HexaVal hx_sha256;                                                          /* native/exec_argv_sha256.c (init shim) */
extern HexaVal sha1;                                                               /* runtime.c — RFC 6455 WS handshake bare-ident bridge (regen-gated) */
extern HexaVal sha1_bytes;                                                         /* runtime.c — raw 20-byte digest bare-ident bridge (regen-gated) */
HexaVal hexa_farr_apply_single_farr(HexaVal re_v, HexaVal im_v,
                                    HexaVal gre_h, HexaVal gim_h,
                                    HexaVal target_v, HexaVal nq_v);               /* runtime.c:6924 (proto), def 8512 */
HexaVal hexa_farr_apply_cnot(HexaVal src_re_v, HexaVal src_im_v,
                             HexaVal dst_re_v, HexaVal dst_im_v,
                             HexaVal control_v, HexaVal target_v,
                             HexaVal nq_v);                                        /* runtime.c:6927 (proto), def 8545 */

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
HexaVal hexa_float_to_bits(HexaVal val);     /* native/tensor_kernels.c (f64↔i64 reinterpret) */
HexaVal hexa_bits_to_float(HexaVal val);     /* native/tensor_kernels.c (i64↔f64 reinterpret) */
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
 * Required for hexat-emitted user.c (1294 calls in hexa_cc.c alone).
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
HexaVal hexa_cwd(void);                                 /* runtime.c — PROBE r8 cwd() builtin */
HexaVal hexa_glob(HexaVal pattern);                     /* runtime.c — PROBE r8 POSIX-fs cluster */
HexaVal hexa_listdir(HexaVal path);                     /* runtime.c — PROBE r8 POSIX-fs cluster */
HexaVal hexa_tempfile(void);                            /* runtime.c — PROBE r8 POSIX-fs cluster */
HexaVal hexa_tempdir(void);                             /* runtime.c — PROBE r8 POSIX-fs cluster */
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
 * Mirrors runtime.c:4262-4272. The hexat codegen emits
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
/* FP32 forge mirror — same int-handle/HexaVal returns as the FP64 farr_*.
 * Without these prototypes a codegenned trainer.c (#include "runtime.h")
 * implicit-declares them `int`, mis-initing `HexaVal h = hexa_farr32_zeros(n)`. */
HexaVal hexa_farr32_zeros(HexaVal n_v);                                 /* runtime.c — FP32 forge */
HexaVal hexa_farr32_get(HexaVal h_v, HexaVal i_v);                      /* runtime.c — FP32 forge */
HexaVal hexa_farr32_set(HexaVal h_v, HexaVal i_v, HexaVal x_v);         /* runtime.c — FP32 forge */
HexaVal hexa_farr32_free(HexaVal h_v);                                  /* runtime.c — FP32 forge */
HexaVal hexa_farr32_matmul(HexaVal a_v, HexaVal ar_v, HexaVal ac_v,
                           HexaVal b_v, HexaVal bc_v);                  /* runtime.c — FP32 forge */
HexaVal hexa_farr32_matmul_NT_b(HexaVal a_v, HexaVal ar_v, HexaVal ac_v,
                                HexaVal b_v, HexaVal br_v);             /* runtime.c — FP32 forge (A·Bᵀ) */
HexaVal hexa_farr32_matmul_NT_a(HexaVal a_v, HexaVal ar_v, HexaVal ac_v,
                                HexaVal b_v, HexaVal bc_v);             /* runtime.c — FP32 forge (Aᵀ·B) */
HexaVal hexa_farr_add_gaussian_noise(HexaVal target_v, HexaVal sigma_v); /* runtime.c — RFC 033 */

/* ── RFC 041 Phase B forge RoPE — 6-arg direct wrappers ─────────────
 * codegen.hexa lowers the `farr_rope_gpu`/`farr_rope_bwd_gpu`
 * builtins to direct `hexa_farr_rope_*_gpu` calls (6-arg, past the
 * hexa_callN ceiling). The generated user.c TU only #include
 * "runtime.h", so the prototype must be visible — without it the
 * d768 ag_tape trainer.c implicit-int mis-inits `HexaVal q = ...`.
 * CUDA build → _hx_cuda_farr_rope_gpu kernel; no-CUDA → byte-identical
 * _hx_farr_rope_cpu fallback. Body (SSOT): self/runtime.c. The bare
 * `farr_rope_gpu` forms are the older bootstrap-seam path. */
HexaVal hexa_farr_rope_gpu(HexaVal t, HexaVal cos, HexaVal sin,
                           HexaVal T, HexaVal nh, HexaVal hd);          /* runtime.c — RFC 041 */
HexaVal hexa_farr_rope_bwd_gpu(HexaVal t, HexaVal cos, HexaVal sin,
                               HexaVal T, HexaVal nh, HexaVal hd);      /* runtime.c — RFC 041 */
HexaVal farr_rope_gpu(HexaVal t, HexaVal cos, HexaVal sin,
                      HexaVal T, HexaVal nh, HexaVal hd);               /* runtime.c — RFC 041 seam */
HexaVal farr_rope_bwd_gpu(HexaVal t, HexaVal cos, HexaVal sin,
                          HexaVal T, HexaVal nh, HexaVal hd);           /* runtime.c — RFC 041 seam */

/* ── RFC gpu-resident-large-vocab-lmhead-loss: GPU CE/seed kernel ───
 * farr_ce_seed_gpu(logits_id, target_ids_id, R, V, out_loss_id,
 *                  out_dlogits_id) -> int rc (0 ok / -1).
 * GPU-resident large-vocab lm-head cross-entropy loss + seed grad in
 * ONE kernel — logits stay device-resident (no 78M H2D). The two
 * outputs are CALLER-allocated and filled in place: out_loss[R] = per-
 * row CE loss (caller sums the R values on host), out_dlogits[R*V] =
 * softmax(logits) - onehot(target) (the backward seed). 6-arg → past
 * the hexa_callN ceiling, so codegen lowers to a direct
 * `hexa_farr_ce_seed_gpu` call (same seam as farr_rope_gpu). CUDA build
 * → _hx_cuda_farr_ce_seed_gpu kernel; no-CUDA → _hx_farr_ce_seed_cpu
 * (the host FP64 reference, also the numeric oracle). The bare
 * `farr_ce_seed_gpu` form is the bootstrap-seam alias. */
HexaVal hexa_farr_ce_seed_gpu(HexaVal logits_v, HexaVal target_ids_v,
                              HexaVal R_v, HexaVal V_v,
                              HexaVal out_loss_v, HexaVal out_dlogits_v); /* runtime.c — RFC lmhead-ce */
HexaVal farr_ce_seed_gpu(HexaVal logits_v, HexaVal target_ids_v,
                         HexaVal R_v, HexaVal V_v,
                         HexaVal out_loss_v, HexaVal out_dlogits_v);      /* runtime.c — RFC lmhead-ce seam */

/* ── RFC 050 L1 slice 1: forge dispatcher callable from hexa ────────
 * codegen.hexa lowers the 5-arg `forge_dispatch_matmul` builtin to a
 * direct `hexa_forge_dispatch_matmul` call. It packs a ForgeShapeInfo +
 * ForgeArgs and routes through forge_tier_dispatch_v1 (RFC 050 §6.1),
 * then yields the output farr handle (or hexa_int(-1) on a dispatch
 * error). Same runtime.h-split contract as the farr ABI above — the
 * generated user.c TU only #include "runtime.h", so the prototype must
 * be visible to avoid an implicit-int mis-init of `HexaVal c = ...`.
 * Body (SSOT): self/runtime.c, defined after the forge_tier_v1.c
 * inline include so forge_tier_dispatch_v1 is in scope. */
HexaVal hexa_forge_dispatch_matmul(HexaVal a_v, HexaVal m_v, HexaVal k_v,
                                   HexaVal b_v, HexaVal n_v);          /* runtime.c — RFC 050 */
/* Bare-symbol seam: the deployed hexat bootstrap emits the builtin as
 * a literal `forge_dispatch_matmul(...)` call (≥5-arg direct-C path),
 * the generated user.c TU only sees runtime.h — declare the bare form
 * too so it links to runtime.c's extern wrapper without a bootstrap
 * rebuild. SSOT codegen (codegen.hexa) lowers to hexa_* directly. */
HexaVal forge_dispatch_matmul(HexaVal a_v, HexaVal m_v, HexaVal k_v,
                              HexaVal b_v, HexaVal n_v);               /* runtime.c — RFC 050 seam */

/* ── RFC 050 PERF-INHERITANCE: forge BF16 FFN dispatch wrapper ──────
 * `forge_dispatch_ffn_fp64_via_bf16(x, w1, w2, y, M, D, FD)` — 7-arg
 * builtin. Takes FP64 farr handles, internally allocates HexaFarrBf16
 * staging, RNE-casts FP64 → BF16, routes through
 * forge_tier_dispatch_v1(FFN_FUSED, PURE_BF16) to the RFC 049 measured
 * substrate (hexa_farr_ffn_bf16_gpu, 11.66× FP64 cuBLAS Dgemm on A100
 * at d768·12L FFN), casts BF16 → FP64 back into the caller's FP64
 * output farr. Returns 0 on success, -1 on any error (no-CUDA host,
 * OOM, dispatch failure, shape mismatch).
 *
 * Same bare-symbol seam as forge_dispatch_matmul above — the deployed
 * hexat emits a literal forge_dispatch_ffn_fp64_via_bf16(...) call,
 * and these two prototypes resolve it to the runtime.c wrapper.
 * Body (SSOT): self/runtime.c. State design doc:
 *   state/forge_rfc050_perf_inherit_2026_05_19/design.md.            */
HexaVal hexa_forge_dispatch_ffn_fp64_via_bf16(HexaVal x_v, HexaVal w1_v,
                                              HexaVal w2_v, HexaVal y_v,
                                              HexaVal m_v, HexaVal d_v,
                                              HexaVal fd_v);            /* runtime.c — RFC 050 PERF */
HexaVal forge_dispatch_ffn_fp64_via_bf16(HexaVal x_v, HexaVal w1_v,
                                         HexaVal w2_v, HexaVal y_v,
                                         HexaVal m_v, HexaVal d_v,
                                         HexaVal fd_v);                 /* runtime.c — RFC 050 PERF seam */

/* ── flame spiking STDP pair-based GPU dispatch wrapper ─────────────
 * `forge_dispatch_stdp_pair(W, tr_pre, tr_post, spike, out,
 *                           A_plus, A_minus, w_max)` — 8-arg builtin.
 * Caller-allocated output (matches mk2-C5 silu_gate / rmsnorm_mh
 * device-residency contract). On HEXA_CUDA: 2D-grid __global__ kernel
 * `_hx_cuda_kern_stdp_pair`, one thread per (i, j) weight cell. On
 * no-CUDA: byte-identical CPU oracle (mirrors spiking_lib.hexa
 * flame_stdp_pair scalar order). Returns 0 on success, -1 on error.
 * Same bare-symbol seam as forge_dispatch_matmul / _ffn above — the
 * deployed hexat emits a literal forge_dispatch_stdp_pair(...) call,
 * these prototypes resolve it to the runtime.c wrappers without a
 * bootstrap rebuild. Body (SSOT): self/runtime.c + self/cuda/
 * runtime_cuda.c. Patch SSOT:
 *   inbox/patches/flame-stdp-pair-gpu-kernel.md (anima LEGO §141).  */
HexaVal hexa_forge_dispatch_stdp_pair(HexaVal W_v, HexaVal tr_pre_v,
                                      HexaVal tr_post_v, HexaVal spike_v,
                                      HexaVal out_v, HexaVal A_plus_v,
                                      HexaVal A_minus_v, HexaVal w_max_v); /* runtime.c — flame STDP GPU */
HexaVal forge_dispatch_stdp_pair(HexaVal W_v, HexaVal tr_pre_v,
                                 HexaVal tr_post_v, HexaVal spike_v,
                                 HexaVal out_v, HexaVal A_plus_v,
                                 HexaVal A_minus_v, HexaVal w_max_v);      /* runtime.c — flame STDP GPU seam */

/* ── safetensors mmap-backed zero-copy load (RFC 025) ──────────────
 * codegen.hexa lowers safetensors_mmap_* builtins to direct
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
/* Generic-fallback symbols the CURRENT committed hexat codegen emits
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

/* ── RFC 055 055-P1 (2026-05-19): hexa-native @gpu_kernel launch ABI ──
 * `gpu_launch(kernel, gx,gy,gz, bx,by,bz, args...)` lowers to this thin
 * Driver-API wrapper. Definition lives in self/cuda/runtime_cuda.c
 * under `#ifdef HEXA_CUDA`; the no-CUDA path is a no-op stub returning
 * 0 (F-RFC055-FALLBACK). Cubin blob + length are produced by the NVPTX
 * codegen target + `ptxas` and embedded in the host binary as a
 * .rodata LSection (RFC 055 §6.5). gpu/SPEC.md §7 governs the surface;
 * the C-side signature here is the consumer-stable bridge. */
int _hx_cuda_launch_kernel(const void*    cubin_blob,
                           size_t         cubin_len,
                           const char*    kernel_name,
                           int            gx, int gy, int gz,
                           int            bx, int by, int bz,
                           const int64_t* farr_ids,
                           int            n_farr,
                           const int64_t* extra_i64_args,
                           int            n_extra);                     /* self/cuda/runtime_cuda.c — RFC 055 */

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
/* RFC 041 Phase B forge RoPE — bare 6-arg direct wrappers (runtime.c
 * L11965/L11978). Declared here so the COMMITTED hexat codegen
 * (which emits the bare name `farr_rope_gpu(...)`, unprefixed) links
 * WITHOUT a transpiler bootstrap rebuild. CUDA build → RFC 041
 * __global__ kernel; no-CUDA → byte-identical `_hx_farr_rope_cpu`
 * (flame gap(d), Decision 9; mirrors the farr_matmul_gpu pattern). */
HexaVal farr_rope_gpu(HexaVal t, HexaVal cos, HexaVal sin,
                      HexaVal T, HexaVal nh, HexaVal hd);               /* runtime.c — RFC 041 (6-arg direct) */
HexaVal farr_rope_bwd_gpu(HexaVal t, HexaVal cos, HexaVal sin,
                          HexaVal T, HexaVal nh, HexaVal hd);           /* runtime.c — RFC 041 (6-arg direct) */

/* ── anima RFC 040 (2026-05-16): Phase B scaffolding — remaining ops ─────
 * Same `#ifdef HEXA_CUDA` / `#ifndef HEXA_CUDA` pattern as Phase A. The
 * d_train5 hot-path candidates for GPU offload (per RFC 040 §"Hot-path op
 * survey"): row-wise softmax, RMSNorm row reduction, elementwise add,
 * elementwise scale. Each gets a `*_gpu` builtin that on the no-CUDA
 * build routes to a NEW SMALL CPU helper (no pre-existing equivalent in
 * the farr surface — the existing `ad_softmax_cross_entropy` is the
 * loss-coupled fused op, not a row-softmax-only kernel). On the HEXA_CUDA
 * build the bodies are TODO[cuda] stubs returning -1 (honest no-fake
 * PASS, per AGENTS.tape g3). Real CUDA `__global__` kernels =
 * next-cycle deliverable on a CUDA host.
 *
 *   farr_softmax_rows_gpu(x_id, R, C) -> int new farr [R*C] with
 *      numerically-stable row-softmax (subtract row max). -1 on err.
 *   farr_rmsnorm_rows_gpu(x_id, R, C, eps_v) -> int new farr [R*C] with
 *      row-RMSNorm (y = x / sqrt(mean(x^2) + eps)). -1 on err.
 *   farr_add_gpu(a_id, b_id, n) -> int new farr [n] with c = a + b.
 *      -1 on err.
 *   farr_scale_gpu(x_id, alpha_v, n) -> int new farr [n] with y = α·x.
 *      -1 on err.
 *
 * Phase B is also SCAFFOLDING: the equivalence harness (no-CUDA build)
 * proves the dispatchers route to the CPU helpers byte-equal; real GPU
 * kernels + their parity vs CPU oracle = next-cycle deliverable. */
HexaVal hexa_farr_softmax_rows_gpu(HexaVal x_v, HexaVal r_v, HexaVal c_v);    /* runtime.c — RFC 040 Phase B */
HexaVal hexa_farr_rmsnorm_rows_gpu(HexaVal x_v, HexaVal r_v, HexaVal c_v,
                                   HexaVal eps_v);                            /* runtime.c — RFC 040 Phase B */
HexaVal hexa_farr_add_gpu(HexaVal a_v, HexaVal b_v, HexaVal n_v);             /* runtime.c — RFC 040 Phase B */
HexaVal hexa_farr_scale_gpu(HexaVal x_v, HexaVal alpha_v, HexaVal n_v);       /* runtime.c — RFC 040 Phase B */
extern HexaVal farr_softmax_rows_gpu;                                          /* runtime.c — RFC 040 fn carrier */
extern HexaVal farr_rmsnorm_rows_gpu;                                          /* runtime.c — RFC 040 fn carrier */
extern HexaVal farr_add_gpu;                                                   /* runtime.c — RFC 040 fn carrier */
extern HexaVal farr_scale_gpu;                                                 /* runtime.c — RFC 040 fn carrier */

/* mk2-closure port (rfc043-flame-camp 61e29993, 2026-05-19):
 * RFC 056 §6.4 device-residence disposition carrier — `farr_set_out_disposition(d)`
 * toggles FORGE_OUT_DEVICE_KEEP for the next forge op so its output stays
 * device-resident (lazy-D2H on host scalar access). Body in runtime.c. */
HexaVal hexa_farr_set_out_disposition(HexaVal d_v);                            /* runtime.c — RFC 056 */
extern HexaVal farr_set_out_disposition;                                       /* runtime.c — RFC 056 fn carrier */

/* mk2-closure port (rfc043-flame-camp 1c98b5b9 + 2425e674 + 32d457b3 +
 * c2689508 + c42ac263, 2026-05-19):
 *   - mk2-C2 farr_rmsnorm_mh_gpu  (7-arg bare): multi-head RMSNorm fwd
 *   - mk2-C4 farr_attn_dt_fwd_gpu (9-arg bare): GQA attention-dt fwd
 *   - mk2-C4-bwd farr_attn_dt_bwd_gpu (12-arg bare): GQA attention-dt bwd
 *   - mk2-C5 farr_copy_slice_gpu / _transpose_2d_gpu / _fill_dt_lcg_gpu
 *     (5+/6+/5-arg bare): device memcpy / 2-D transpose / LCG fill
 *   - mk2-C5 hexa_farr_zero_slice_gpu / _add_inplace_gpu (3-arg, carrier
 *     + hexa_fn_new dispatch). */
HexaVal hexa_farr_zero_slice_gpu(HexaVal dst_v, HexaVal doff_v, HexaVal n_v);  /* runtime.c — mk2-C5 */
HexaVal hexa_farr_add_inplace_gpu(HexaVal dst_v, HexaVal src_v, HexaVal n_v);  /* runtime.c — mk2-C5 */
extern HexaVal farr_zero_slice_gpu;                                            /* runtime.c — mk2-C5 fn carrier */
extern HexaVal farr_add_inplace_gpu;                                           /* runtime.c — mk2-C5 fn carrier */
HexaVal farr_copy_slice_gpu(HexaVal src_v, HexaVal soff_v, HexaVal dst_v,
                            HexaVal doff_v, HexaVal n_v);                      /* runtime.c — mk2-C5 (5-arg bare) */
HexaVal farr_transpose_2d_gpu(HexaVal src_v, HexaVal soff_v, HexaVal dst_v,
                              HexaVal doff_v, HexaVal d_out_v,
                              HexaVal d_in_v);                                 /* runtime.c — mk2-C5 (6-arg bare) */
HexaVal farr_fill_dt_lcg_gpu(HexaVal dst_v, HexaVal doff_v, HexaVal n_v,
                             HexaVal seed_v, HexaVal scale_v);                 /* runtime.c — mk2-C5 (5-arg bare) */
HexaVal farr_rmsnorm_mh_gpu(HexaVal x_v, HexaVal g_v, HexaVal y_v,
                            HexaVal xn_v, HexaVal inv_v, HexaVal T_v,
                            HexaVal d_v);                                      /* runtime.c — mk2-C2 (7-arg bare) */
HexaVal farr_attn_dt_fwd_gpu(HexaVal q_v, HexaVal k_v, HexaVal v_v,
                             HexaVal p_v, HexaVal ctx_v, HexaVal T_v,
                             HexaVal nh_v, HexaVal nkv_v, HexaVal hd_v);       /* runtime.c — mk2-C4 (9-arg bare) */
HexaVal farr_attn_dt_bwd_gpu(HexaVal q_v, HexaVal k_v, HexaVal v_v,
                             HexaVal p_v, HexaVal dctx_v, HexaVal dq_v,
                             HexaVal dk_v, HexaVal dv_v, HexaVal T_v,
                             HexaVal nh_v, HexaVal nkv_v,
                             HexaVal hd_v);                                    /* runtime.c — mk2-C4-bwd (12-arg bare) */

/* anima RFC 040 Phase B2 (2026-05-16): d_train5 hot-path completion.
 * The remaining DOMINANT-FLOP farr ops the Phase E refactor of
 * HEXAD/D/d_train5_lib.hexa needs so every boxed c3_/dt2_ op has a
 * matching farr-gpu swap target. Scaffolding only (Mac, no CUDA):
 * no-CUDA = verified CPU helper == trusted boxed reference; HEXA_CUDA =
 * TODO[cuda] stub returning -1 (honest, no-fake-PASS, AGENTS.tape g3).
 *
 *   farr_matmul_t_gpu(M,R,C,u)        -> int new farr [C]    (M^T . u)
 *   farr_outer_gpu(u,v,R,C)           -> int new farr [R.C]  (u outer v)
 *   farr_mul_gpu(a,b,n)               -> int new farr [n]    (Hadamard)
 *   farr_silu_gpu(x,n)                -> int new farr [n]    (x.sigmoid)
 *   farr_silu_grad_gpu(x,n)           -> int new farr [n]    (silu grad)
 *   farr_rmsnorm_bwd_rows_gpu(x,dxn,R,C) -> int new farr [R.C] (vjp dx)
 *   farr_adamw_step_gpu(W,m,v,g,n,lr,b1,b2,eps,wd,step_t)
 *                                     -> int new farr [n] (updated W;
 *                                        m,v updated in place)
 *   farr_rope_gpu(t,cos,sin,T,nheads,hd)     -> int new farr [T.nheads.hd]
 *                                        (rotary pos-emb forward)
 *   farr_rope_bwd_gpu(t,cos,sin,T,nheads,hd) -> int new farr [T.nheads.hd]
 *                                        (rotary pos-emb backward)
 */
HexaVal hexa_farr_matmul_t_gpu(HexaVal m_v, HexaVal r_v, HexaVal c_v,
                               HexaVal u_v);                                   /* runtime.c — RFC 040 Phase B2 */
HexaVal hexa_farr_outer_gpu(HexaVal u_v, HexaVal v_v, HexaVal r_v,
                            HexaVal c_v);                                      /* runtime.c — RFC 040 Phase B2 */
HexaVal hexa_farr_mul_gpu(HexaVal a_v, HexaVal b_v, HexaVal n_v);             /* runtime.c — RFC 040 Phase B2 */
HexaVal hexa_farr_silu_gpu(HexaVal x_v, HexaVal n_v);                         /* runtime.c — RFC 040 Phase B2 */
HexaVal hexa_farr_silu_grad_gpu(HexaVal x_v, HexaVal n_v);                    /* runtime.c — RFC 040 Phase B2 */
HexaVal hexa_farr_silu_gate_gpu(HexaVal a_v, HexaVal b_v, HexaVal n_v);       /* runtime.c — mk2-C1b silu·b gate */
HexaVal hexa_farr_rmsnorm_bwd_rows_gpu(HexaVal x_v, HexaVal dxn_v,
                                       HexaVal r_v, HexaVal c_v);             /* runtime.c — RFC 040 Phase B2 */
HexaVal hexa_farr_adamw_step_gpu(HexaVal w_v, HexaVal m_v, HexaVal v_v,
                                 HexaVal g_v, HexaVal n_v, HexaVal lr_v,
                                 HexaVal b1_v, HexaVal b2_v, HexaVal eps_v,
                                 HexaVal wd_v, HexaVal step_v);               /* runtime.c — RFC 040 Phase B2 */
extern HexaVal farr_matmul_t_gpu;                                              /* runtime.c — RFC 040 fn carrier */
extern HexaVal farr_outer_gpu;                                                 /* runtime.c — RFC 040 fn carrier */
extern HexaVal farr_mul_gpu;                                                   /* runtime.c — RFC 040 fn carrier */
extern HexaVal farr_silu_gpu;                                                  /* runtime.c — RFC 040 fn carrier */
extern HexaVal farr_silu_grad_gpu;                                             /* runtime.c — RFC 040 fn carrier */
extern HexaVal farr_silu_gate_gpu;                                             /* runtime.c — mk2-C1b fn carrier */
extern HexaVal farr_rmsnorm_bwd_rows_gpu;                                      /* runtime.c — RFC 040 fn carrier */
HexaVal farr_adamw_step_gpu(HexaVal w, HexaVal m, HexaVal v, HexaVal g,
                            HexaVal n, HexaVal lr, HexaVal b1, HexaVal b2,
                            HexaVal eps, HexaVal wd, HexaVal step_t);          /* runtime.c — RFC 040 Phase B2 (11-arg direct) */


/* ═══════════════════════════════════════════════════════════════
 * mass declaration — defined-but-undeclared backlog clearance
 *
 * 102 codegen-called runtime functions whose definitions exist in
 * runtime.c / runtime_core.c but lacked forward declarations here.
 * Each is emitted by self/codegen.hexa as it lowers a user
 * feature (array iterator method, format, math intrinsic, regex,
 * callbacks, exec_stream, terminal, JSON, struct, arena, …).
 * Without these decls modern clang treats every such call as a
 * hard error (ISO C99+ rejects implicit function declarations) —
 * features parsed + codegen'd cleanly but failed at link.
 *
 * Class siblings already shipped individually:
 *   #348 hexa_is_type       — trait/impl dispatch
 *   #350 hexa_array_shift   — .shift()
 *   #356 hexa_await_unwrap  — await <expr>
 * Class survey + automation proposal: inbox patch #357.
 * ═══════════════════════════════════════════════════════════════ */
HexaVal hexa_argmax(HexaVal a); /* runtime.c:11052 */
HexaVal hexa_array_chunk(HexaVal arr, HexaVal nv); /* runtime.c:3952 */
HexaVal hexa_array_drop(HexaVal arr, HexaVal nv); /* runtime.c:3875 */
HexaVal hexa_array_find(HexaVal arr, HexaVal fn); /* runtime.c:3507 */
HexaVal hexa_array_flat_map(HexaVal arr, HexaVal fn); /* runtime.c:3555 */
HexaVal hexa_array_for_each(HexaVal arr, HexaVal fn); /* runtime.c:3720 */
HexaVal hexa_array_frequencies(HexaVal arr); /* runtime.c:4333 */
HexaVal hexa_array_group_by(HexaVal arr, HexaVal fn); /* runtime.c:4310 */
HexaVal hexa_array_interleave(HexaVal a, HexaVal b); /* runtime.c:4142 */
HexaVal hexa_array_max(HexaVal arr); /* runtime.c:3623 */
HexaVal hexa_array_mean(HexaVal arr); /* runtime.c:4245 */
HexaVal hexa_array_min(HexaVal arr); /* runtime.c:3611 */
HexaVal hexa_array_partition(HexaVal arr, HexaVal fn); /* runtime.c:4105 */
HexaVal hexa_array_product(HexaVal arr); /* runtime.c:4208 */
HexaVal hexa_array_push_nostat(HexaVal arr, HexaVal item); /* runtime_core.c:1909 */
HexaVal hexa_array_rotate(HexaVal arr, HexaVal kv); /* runtime.c:4070 */
HexaVal hexa_array_sample(HexaVal arr, HexaVal nv); /* runtime.c:4356 */
HexaVal hexa_array_scan(HexaVal arr, HexaVal init, HexaVal fn); /* runtime.c:4182 */
HexaVal hexa_array_set(HexaVal arr, int64_t idx, HexaVal val); /* runtime_core.c:2014 */
HexaVal hexa_array_shift(HexaVal arr); /* runtime_core.c:4722 */
HexaVal hexa_array_take(HexaVal arr, HexaVal nv); /* runtime.c:3863 */
HexaVal hexa_array_unique(HexaVal arr); /* runtime.c:4034 */
HexaVal hexa_array_window(HexaVal arr, HexaVal nv); /* runtime.c:3996 */
/* PROBE r16 Q5: additional iterator adapters (runtime.c) */
HexaVal hexa_array_take_while(HexaVal arr, HexaVal fn);
HexaVal hexa_array_skip_while(HexaVal arr, HexaVal fn);
HexaVal hexa_array_min_by(HexaVal arr, HexaVal fn);
HexaVal hexa_array_max_by(HexaVal arr, HexaVal fn);
HexaVal hexa_array_position(HexaVal arr, HexaVal fn);
HexaVal hexa_array_reduce(HexaVal arr, HexaVal fn);
HexaVal hexa_array_dedup(HexaVal arr);
HexaVal hexa_array_step_by(HexaVal arr, HexaVal nv);
HexaVal hexa_array_zeros_float(HexaVal nv); /* runtime.c:3789 */
HexaVal hexa_array_zip(HexaVal a, HexaVal b); /* runtime.c:3918 */
HexaVal hexa_array_concat(HexaVal a, HexaVal b); /* runtime.c — PROBE r14-JJJJ (.chain) */
HexaVal hexa_await_unwrap(HexaVal v); /* runtime_core.c:3046 */
HexaVal hexa_callback_create(HexaVal fn_val); /* runtime.c:2628 */
HexaVal hexa_callback_free(HexaVal ptr); /* runtime.c:2647 */
HexaVal hexa_callback_slot_id(HexaVal ptr); /* runtime.c:2661 */
HexaVal hexa_clamp(HexaVal xv, HexaVal lov, HexaVal hiv); /* runtime.c:11122 */
HexaVal hexa_count_poly(HexaVal obj, HexaVal arg); /* runtime.c:3482 */
HexaVal hexa_deref(HexaVal ptr); /* runtime.c:2448 */
HexaVal hexa_exec_stream_kill(HexaVal handle); /* runtime.c:12276 */
HexaVal hexa_farr_apply_single(HexaVal re_v, HexaVal im_v, HexaVal gate_re, HexaVal gate_im, HexaVal target_v, HexaVal nq_v); /* runtime.c:5730 */
HexaVal hexa_fma(HexaVal a, HexaVal b, HexaVal c); /* runtime_core.c:6863 */
HexaVal hexa_format(HexaVal fmt, HexaVal arg); /* runtime_core.c:6479 */
HexaVal hexa_format_float(HexaVal f, HexaVal prec); /* runtime_core.c:7009 */
HexaVal hexa_format_float_sci(HexaVal f, HexaVal prec); /* runtime_core.c:7028 */
HexaVal hexa_gelu(HexaVal a); /* runtime.c:11040 */
HexaVal hexa_hadamard(HexaVal a, HexaVal b); /* runtime.c:11015 */
HexaVal hexa_host_ffi_call(HexaVal fn_ptr, HexaVal args_arr, HexaVal float_mask, HexaVal ret_kind); /* runtime.c:2275 */
HexaVal hexa_host_ffi_open(HexaVal lib_name); /* runtime.c:2230 */
HexaVal hexa_host_ffi_sym(HexaVal handle, HexaVal symbol); /* runtime.c:2239 */
HexaVal hexa_is_error(HexaVal v); /* runtime.c:4661 */
HexaVal hexa_json_decode(HexaVal s);  /* runtime.c:10832 */
HexaVal hexa_json_encode(HexaVal v);  /* runtime.c:10943 */
HexaVal hexa_map_entries(HexaVal m); /* runtime_core.c:2668 */
HexaVal hexa_map_filter_keys(HexaVal m, HexaVal fn); /* runtime_core.c:2733 */
HexaVal hexa_map_from_array(HexaVal self_map, HexaVal arr); /* runtime_core.c:2796 */
HexaVal hexa_map_invert(HexaVal m); /* runtime_core.c:2770 */
HexaVal hexa_map_map_values(HexaVal m, HexaVal fn); /* runtime_core.c:2728 */
HexaVal hexa_map_merge(HexaVal a, HexaVal b); /* runtime_core.c:2706 */
HexaVal hexa_map_remove_impl(HexaVal m, const char* key); /* runtime_core.c:2888 */
HexaVal hexa_map_set_impl(HexaVal m, const char* key, HexaVal val); /* runtime_core.c:2374 */
HexaVal hexa_map_to_array(HexaVal m); /* runtime_core.c:2691 */
HexaVal hexa_map_values(HexaVal m); /* runtime_core.c:2624 */
HexaVal hexa_matmul(HexaVal a, HexaVal b, HexaVal mv, HexaVal kv, HexaVal nv); /* runtime.c:11242 */
HexaVal hexa_matvec(HexaVal w, HexaVal x, HexaVal rows_v, HexaVal cols_v); /* runtime.c:4617 */
HexaVal hexa_now_monotonic_s(void); /* runtime.c:10278 */
HexaVal hexa_one_hot(HexaVal idxv, HexaVal nv); /* runtime.c:11142 */
HexaVal hexa_pad_left(HexaVal s, HexaVal width); /* runtime_core.c:6797 */
HexaVal hexa_pad_right(HexaVal s, HexaVal width); /* runtime_core.c:6826 */
HexaVal hexa_ptr_addr(HexaVal v); /* runtime.c:2213 */
HexaVal hexa_ptr_null(void);  /* runtime.c:2224 */
HexaVal hexa_ptr_offset(HexaVal ptr, HexaVal offset); /* runtime.c:2442 */
HexaVal hexa_real_args(); /* runtime_core.c:6308 */
HexaVal hexa_regex_findall(HexaVal pat_v, HexaVal s_v); /* runtime.c:10446 */
HexaVal hexa_regex_match(HexaVal pat_v, HexaVal s_v); /* runtime.c:10397 */
HexaVal hexa_regex_match_full(HexaVal pat_v, HexaVal s_v); /* runtime.c:10411 */
HexaVal hexa_regex_replace(HexaVal pat_v, HexaVal s_v, HexaVal repl_v); /* runtime.c:10512 */
HexaVal hexa_regex_search(HexaVal pat_v, HexaVal s_v); /* runtime.c:10427 */
HexaVal hexa_regex_split(HexaVal pat_v, HexaVal s_v); /* runtime.c:10476 */
HexaVal hexa_script_path(); /* runtime_core.c:6302 */
HexaVal hexa_silu(HexaVal a); /* runtime.c:11030 */
HexaVal hexa_sleep(HexaVal sec); /* runtime.c:4458 */
HexaVal hexa_sleep_ns(HexaVal ns); /* runtime.c:10262 */
HexaVal hexa_sleep_s(HexaVal n); /* runtime.c:10229 */
HexaVal hexa_softmax(HexaVal a); /* runtime.c:11202 */
HexaVal hexa_struct_free(HexaVal ptr); /* runtime.c:2516 */
HexaVal hexa_struct_pack(HexaVal* args, int nargs); /* runtime.c:2467 */
HexaVal hexa_struct_point(HexaVal x, HexaVal y); /* runtime.c:2500 */
HexaVal hexa_struct_rect(HexaVal x, HexaVal y, HexaVal w, HexaVal h); /* runtime.c:2490 */
HexaVal hexa_struct_size_pack(HexaVal w, HexaVal h); /* runtime.c:2508 */
HexaVal hexa_struct_unpack(HexaVal ptr, HexaVal index); /* runtime.c:2481 */
HexaVal hexa_swiglu_vec(HexaVal gate, HexaVal up); /* runtime.c:10946 */
HexaVal hexa_tensor_add(HexaVal a, HexaVal b); /* runtime.c:10974 */
HexaVal hexa_tensor_dot(HexaVal a, HexaVal b); /* runtime.c:10988 */
HexaVal hexa_tensor_mul_scalar(HexaVal a, HexaVal sv); /* runtime.c:11001 */
HexaVal hexa_tensor_ones(HexaVal nv); /* runtime.c:10935 */
HexaVal hexa_tensor_zeros(HexaVal nv); /* runtime.c:10925 */
HexaVal hexa_term_fd_close(HexaVal fd); /* runtime.c:11884 */
HexaVal hexa_term_fd_poll(HexaVal fd, HexaVal timeout_ms); /* runtime.c:11889 */
HexaVal hexa_term_fd_read(HexaVal fd, HexaVal max_bytes); /* runtime.c:11860 */
HexaVal hexa_term_fd_write(HexaVal fd, HexaVal data); /* runtime.c:11875 */
HexaVal hexa_term_isatty_stdin(void);  /* runtime.c:11826 */
HexaVal hexa_term_isatty_stdout(void); /* runtime.c:11827 */
HexaVal hexa_term_pty_reap(HexaVal pid); /* runtime.c:11896 */
HexaVal hexa_term_pty_spawn_sh(HexaVal cmd, HexaVal rows, HexaVal cols); /* runtime.c:11840 */
HexaVal hexa_to_bool(HexaVal v); /* runtime.c:10585 */
HexaVal hexa_u_floor(HexaVal a, HexaVal b); /* runtime_core.c:6364 */
HexaVal hexa_utc_iso_format(HexaVal epoch_v); /* runtime.c:10313 */
HexaVal hexa_utc_iso_parse(HexaVal s_v); /* runtime.c:10326 */

/* codegen-called wrappers that were defined-but-undeclared (inbox patch
 * runtime-h-undeclared-fn-class). User-code TU includes runtime.h before
 * runtime.c, so a missing forward-decl is a clang C99 implicit-declaration
 * hard-error the moment codegen lowers the matching feature. */
HexaVal hexa_base64_decode(HexaVal s);                  /* runtime.c:11317 */
HexaVal hexa_host_ffi_call_6(HexaVal fn_ptr, HexaVal nargs_v, HexaVal float_mask, HexaVal ret_kind, HexaVal a0, HexaVal a1, HexaVal a2, HexaVal a3, HexaVal a4, HexaVal a5); /* runtime.c:2327 */
int     hexa_is_type(HexaVal v, const char* type_name); /* runtime_core.c:3046 */
HexaVal hexa_log2(HexaVal v);                           /* runtime_core.c:6484 */
HexaVal hexa_map_count(HexaVal m, HexaVal pred);        /* runtime_core.c:2866 */
HexaVal hexa_str_concat(HexaVal a, HexaVal b);          /* runtime_core.c:4321 */
int     hexa_str_eq(HexaVal a, HexaVal b);              /* runtime_core.c:4446 */

#endif /* HEXA_RUNTIME_H */
