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

/* ── Tagged value layout (mirrors runtime.c lines 908–996) ── */

typedef enum {
    TAG_INT = 0, TAG_FLOAT, TAG_BOOL, TAG_STR, TAG_VOID,
    TAG_ARRAY, TAG_MAP, TAG_FN, TAG_CHAR, TAG_CLOSURE,
    TAG_VALSTRUCT
} HexaTag;

typedef struct HexaVal_       HexaVal;
typedef struct HexaValStruct  HexaValStruct;
typedef struct HexaMapTable   HexaMapTable;

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
HexaVal hexa_void(void);                              /* runtime.c:1234 */
HexaVal hexa_str(const char* s);                      /* runtime.c:1346 */

/* arithmetic / conversion
 * NOTE: hexa_add is a MACRO in runtime.c (line 4757) that expands to a
 * hot-path int+int branch + fallback to hexa_add_slow. We must mirror the
 * macro here AND expose hexa_add_slow as extern (runtime.c patched: drop
 * `static` on line 4731).
 */
#define HX_TAG(v)     ((v).tag)
#define HX_INT(v)     ((v).i)
#define HX_IS_INT(v)  ((v).tag == TAG_INT)

HexaVal hexa_add_slow(HexaVal a, HexaVal b);          /* runtime.c:4731 (was static) */

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

#endif /* HEXA_RUNTIME_H */
