# `self/runtime.c` — `hxlcl_*` libc-replacement family incomplete: missing `hxlcl_memcpy` / `hxlcl_strdup` / `hxlcl_strchr`

**Severity**: high (blocks **every** `hexa build` / `hexa run` of any program
  that pulls in `runtime_core.c` on Mac — including unmodified
  `stdlib/flame/flame_d768_12L_corpus_test.hexa` template)

**Layer**: self / runtime (codegen-independent — pure C source completeness)

**Reporter**: anima (`dancinlab/anima`) downstream consumer — discovered
  while attempting to fire `§185 train_s185_psicouple.hexa` under
  `@D g_train_via_hexa_cloud_and_hexa_lang` mandate (`.hexa` trainer +
  hexa cloud dispatch). Per anima downstream-consumer invariant
  (`g_train_via_hexa_cloud_and_hexa_lang.dont`: "hexa-lang upstream
  직접 수정") — filing patch, NOT editing upstream.

**Status**: not_started (filed 2026-05-20)

**Cross-link**:
- `dancinlab/anima` `@D g_train_via_hexa_cloud_and_hexa_lang` (2026-05-20
  TOP MANDATE) — blocked until this patch lands
- prior patch `runtime-h-incomplete-after-phase-1-3-b.md` (CLOSED
  2026-05-20) handled `hexa_*` extern symbols; this patch handles the
  separate `hxlcl_*` static-helper family

## Reproduction (Mac, darwin 25.5.0 arm64)

Pristine flame template — anima made zero edits to upstream:

```bash
$ HEXA_LANG=/Users/ghost/core/hexa-lang HEXA_MAC_BUILD_OK=1 \
    timeout 30 hexa run \
    /Users/ghost/core/hexa-lang/stdlib/flame/flame_d768_12L_corpus_test.hexa
…
/Users/ghost/core/hexa-lang/self/runtime_core.c:212:29: error: call to undeclared function 'hxlcl_strchr'; ISO C99 and later do not support implicit function declarations
/Users/ghost/core/hexa-lang/self/runtime_core.c:1696:9: error: call to undeclared function 'hxlcl_memcpy'; ISO C99 and later do not support implicit function declarations
/Users/ghost/core/hexa-lang/self/runtime_core.c:1739:9: error: call to undeclared function 'hxlcl_memcpy'; …
/Users/ghost/core/hexa-lang/self/runtime_core.c:2220:33: error: call to undeclared function 'hxlcl_strdup'; …
…
fatal error: too many errors emitted, stopping now [-ferror-limit=]
20 errors generated.
error: clang compile failed — binary not produced
```

## Diagnosis

`self/runtime.c:50-82` defines 3 hxlcl-prefix libc replacements
**before** `#include "runtime_core.c"` at line 91:

```c
// self/runtime.c:60
static size_t __attribute__((noinline)) hxlcl_strlen(const char *s) { … }
static int    __attribute__((noinline)) hxlcl_memcmp(const void *a, const void *b, size_t n) { … }
static int    __attribute__((noinline)) hxlcl_strcmp(const char *a, const char *b) { … }
…
// self/runtime.c:87-89
#define strlen(s)      hxlcl_strlen((const char *)(s))
#define memcmp(a,b,n)  hxlcl_memcmp((const void *)(a), (const void *)(b), (size_t)(n))
#define strcmp(a,b)    hxlcl_strcmp((const char *)(a), (const char *)(b))

// self/runtime.c:91
#include "runtime_core.c"
```

But `self/runtime_core.c` contains **literal** calls to **three more**
hxlcl-prefix helpers that are never defined anywhere in `self/*.c` or
`self/*.h`:

| Symbol         | Call sites in `runtime_core.c` | Count |
|----------------|--------------------------------|------:|
| `hxlcl_memcpy` | 456, 503, 685, 1696, 1739, 1841, 1974, 2204, 2240, 2315, 2316, 3866, 4027, 4028, 4133, … | ≥15  |
| `hxlcl_strdup` | 2220, 2243, 2298, 3389 | 4  |
| `hxlcl_strchr` | 212 | 1  |

verified via:

```bash
$ grep -rn 'hxlcl_memcpy\|hxlcl_strdup\|hxlcl_strchr' /Users/ghost/core/hexa-lang/self/*.c /Users/ghost/core/hexa-lang/self/*.h
# all matches are USE-sites in runtime_core.c — zero DEFINE-sites
```

These uses bypass libc on purpose — same rationale as `hxlcl_strlen` /
`hxlcl_memcmp` / `hxlcl_strcmp` (see comment at `runtime.c:50-59`: "so
the linker no longer pulls in _strlen / _strcmp / _memcmp" + "Step-2
later cycle ports each helper to stdlib/runtime/<name>.hexa"). The
3-helper extension was simply never landed.

## Suggested fix (drop into `self/runtime.c` between line 82 and line 84)

```c
static void* __attribute__((noinline)) hxlcl_memcpy(void *dst, const void *src, size_t n) {
    unsigned char *pd = (unsigned char *)dst;
    const unsigned char *ps = (const unsigned char *)src;
    for (size_t i = 0; i < n; i++) pd[i] = ps[i];
    return dst;
}
static char* __attribute__((noinline)) hxlcl_strdup(const char *s) {
    if (!s) return NULL;
    size_t n = hxlcl_strlen(s);
    /* malloc is fine here — same allocator used elsewhere in runtime_core.c */
    char *r = (char*)malloc(n + 1);
    if (!r) return NULL;
    for (size_t i = 0; i <= n; i++) r[i] = s[i];
    return r;
}
static const char* __attribute__((noinline)) hxlcl_strchr(const char *s, int c) {
    if (!s) return NULL;
    for (size_t i = 0; ; i++) {
        if ((unsigned char)s[i] == (unsigned char)c) return s + i;
        if (s[i] == 0) return NULL;
    }
}
```

And extend the libc textual-override block at `runtime.c:87-89` so any
**residual** macro-expansion or header-inline reference to libc names
also routes through the helpers (mirrors existing `strlen`/`memcmp`/
`strcmp` lines):

```c
#define memcpy(d,s,n)  hxlcl_memcpy((void *)(d), (const void *)(s), (size_t)(n))
#define strdup(s)      hxlcl_strdup((const char *)(s))
#define strchr(s,c)    hxlcl_strchr((const char *)(s), (int)(c))
```

**Caveat on `#define memcpy`**: the existing `runtime.c:129` (line
inside `hexa_ffi_extract_libname`) and other code paths call `memcpy`
directly with libc semantics. If a textual override breaks any
inline-asm or builtin recognition, the safer minimal patch is **defs
only** (3 static functions) — `runtime_core.c` already spells
`hxlcl_*` literally so just defining the symbols is enough to compile.
The `#define` extension is a tidiness add for cross-TU consistency
with the existing 3 macros; can be skipped.

## Verification (after patch)

```bash
$ cd /Users/ghost/core/hexa-lang
$ HEXA_MAC_BUILD_OK=1 hexa run stdlib/flame/flame_d768_12L_corpus_test.hexa
# expected: no hxlcl_* undeclared errors; build proceeds to user.c
#           (template may still hit user-level diagnostics — that's fine,
#            symptom is just "the 3 hxlcl_* errors vanish")
```

Anima-side smoke target (independent of dual-head / multi-objective —
those are separate inbox `flame-anima-dual-head-multiobjective.md`):

```bash
$ HEXA_LANG=/Users/ghost/core/hexa-lang HEXA_MAC_BUILD_OK=1 hexa run \
    /Users/ghost/core/anima/HEXAD/UNCLASSIFIED/state/all_taps_release_s184_2026_05_20/train_s185_psicouple.hexa
# expected: passes runtime_core.c compile stage; CE+entropy single-loss
#           skeleton runs at d=192 L=4 nsamp=4 n_steps=200 on Mac CPU
```

## Honest C3 / scope

1. **Mac-only reproduction so far** — Linux clang/gcc may have different
   implicit-decl rules (Linux gcc still accepts implicit int return
   under `-std=gnu89`); if Linux build was green, this is a Mac
   regression introduced when `runtime_core.c` added the hxlcl_memcpy /
   strdup / strchr call sites without the matching defs.
2. **No `runtime_core.c` line audit** — patch is scoped to "add the 3
   missing defs"; whether the call-site authors intended these names
   or meant libc `memcpy` (which would have linked fine under the
   strlen/memcmp/strcmp macro precedent) is a maintainer call.
3. **Possible 4th symbol latent**: `grep -nE 'hxlcl_[a-z]+' runtime_core.c`
   may surface more — only the 3 that clang stopped on are in scope here.
   Recommend a one-time `comm -23` audit of `grep hxlcl_ runtime_core.c |
   sort -u` against `grep 'hxlcl_[a-z]\+' runtime.c | sort -u` to catch
   any future drift.
