/* self/runtime_core_decls.h — ZERO-C leg-B (ING #35, r9) include-drop decl surface.
 *
 * WHAT THIS IS
 * ────────────
 * When the whole-file `#include "runtime_core.c"` is DROPPED from the frozen
 * runtime.c (HEXA_ZEROC_DROP_RTCORE_INCLUDE, default OFF — top-level
 * `ls self/*.c` 3→1), the trailing runtime.c HI-tier body loses every
 * declaration runtime_core.c used to supply by textual concatenation: the
 * HexaVal type-ABI (struct + HX_* macros), the base aggregate types
 * (HexaArr/HexaMap/HexaFn/HexaClo/HexaValStruct/HexaMapTable + the HexaArena
 * pair), and the forward-decl prototypes of the CORE-tier primitives. This
 * header re-supplies that surface so the trailing body COMPILES against the
 * SEPARATE runtime_core.c seed .o.
 *
 * It is injected — ONLY under the drop flag — by tool/zeroc_drop_rtcore_include.sh
 * immediately before the (guarded-out) `#include "runtime_core.c"` line. The
 * DEFAULT build never includes it (the concatenation supplies everything), so
 * default byte-identity is untouched — this file exists purely for the drop-ON
 * compile.
 *
 * SSOT: the declarations below mirror self/runtime_core_emit.hexa. The base
 * type-ABI + HX_* macros come from self/runtime_hexaval_abi.h (the always-on
 * extracted SSOT) and the broad prototype surface from self/runtime.h (the
 * native-.o supply path's external view). This file adds ONLY the pieces those
 * two do not already carry: the HexaArena struct pair, HX_STRLEN, the 2
 * promoted file-scope externs, and the handful of prototypes runtime.h omits.
 */
#ifndef HEXA_RUNTIME_CORE_DECLS_H
#define HEXA_RUNTIME_CORE_DECLS_H

/* (1) the broad external prototype + base-type surface (HexaTag/HexaArr/…,
 *     HexaVal, and most hexa_* prototypes). runtime.h is the native-.o path's
 *     SSOT for runtime_core.c's external ABI. */
#include "runtime.h"

/* (2) the HX_* accessor/mutator macro family + HexaVal (the always-on
 *     extracted type-ABI SSOT). Idempotent: guarded by its own include guard;
 *     a second inclusion (if runtime.h already pulled it) is a no-op. */
#include "runtime_hexaval_abi.h"

/* (3) the HexaArena bump-allocator struct pair — the frozen HI-tier body's
 *     arena-stats walk (`for (HexaArenaBlock* b = __hexa_arena.head; …)`)
 *     dereferences these. runtime.h does not carry them (they are CORE-only). */
#ifndef HEXA_RTCORE_DECLS_ARENA_TYPES
#define HEXA_RTCORE_DECLS_ARENA_TYPES
typedef struct HexaArenaBlock {
    struct HexaArenaBlock* next;   /* NULL for last block */
    size_t cap;                    /* usable bytes in data[] */
    size_t used;                   /* bytes allocated from this block */
    char   data[];                 /* flexible; cap bytes follow the header */
} HexaArenaBlock;

typedef struct {
    HexaArenaBlock* head;   /* first block (never freed until arena_destroy) */
    HexaArenaBlock* cur;    /* current bump block */
} HexaArena;
#endif

/* (4) HX_STRLEN — defined inline in runtime_core.c (not in abi.h). */
#ifndef HX_STRLEN
#define HX_STRLEN(v)    hexa_strlen_v_inline(HX_STR(v))
#define HX_STRLEN_S(s)  hexa_strlen_v_inline(s)
#endif

/* (5) the 2 promoted file-scope globals (static→external under the drop;
 *     see HX_RTCORE_LOCAL note in runtime_core_emit.hexa). The frozen body
 *     reads __hexa_arena and toggles __hexa_val_region_returns_enabled. */
extern HexaArena __hexa_arena;
extern int __hexa_val_region_returns_enabled;

#endif /* HEXA_RUNTIME_CORE_DECLS_H */
