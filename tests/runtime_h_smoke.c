/* tests/runtime_h_smoke.c — runtime.h public-ABI surface smoke test
 *
 * Compile-only smoke that exercises every header symbol the post-PHASE-1.3.B
 * native codegen path needs from runtime.h. If anyone modifies hexa_v2
 * codegen to emit a new helper, or shrinks runtime.h to drop one, this
 * test fails to compile.
 *
 * Originally filed as the reproducer for
 * incoming/patches/runtime-h-incomplete-after-phase-1-3-b.md (wilson stdlib/
 * sort + event-bus folds hit undeclared-function errors on first compile
 * after pulling hexa-lang main). The fix at commit 8be9b03f promoted the
 * missing surface; this test guards against future regressions.
 *
 * Usage:
 *   bin/hexa-fast check
 * or manually:
 *   clang -O0 -c tests/runtime_h_smoke.c -I self
 */

#include "runtime.h"

/* ── identity / sort_by-style consumer of hexa_call1 + hexa_fn_new ── */

HexaVal _identity(HexaVal x) { return x; }

HexaVal sort_by_keys(HexaVal xs, HexaVal key_fn) {
    HexaVal keys = hexa_array_new();
    int n = hexa_len(xs);
    int i = 0;
    while (i < n) {
        hexa_array_push(keys,
            hexa_call1(key_fn, hexa_index_get(xs, hexa_int(i))));
        i = i + 1;
    }
    return keys;
}

HexaVal sort_asc(HexaVal xs) {
    return __hexa_fn_arena_return(
        sort_by_keys(xs, hexa_fn_new((void*)_identity, 0))
    );
}

/* ── array-pop (event-bus frame stack pattern) ── */

HexaVal pop_test(HexaVal arr) {
    return hexa_array_pop(arr);
}

/* ── map predicate + cstring conversion (policy-helper pattern) ── */

int has_key_test(HexaVal m, HexaVal k) {
    return hexa_map_contains_key(m, hexa_to_cstring(k));
}

/* ── closure-new (struct fn-field auto-wrap pattern) ── */

HexaVal closure_make(void) {
    HexaVal env = hexa_array_new();
    return hexa_closure_new((void*)_identity, 1, env);
}

/* ── hexa_call0..4 dispatch (arity-spanning fn-call pattern) ── */

HexaVal call_test(HexaVal f, HexaVal a, HexaVal b, HexaVal c, HexaVal d) {
    HexaVal v0 = hexa_call0(f);
    HexaVal v1 = hexa_call1(f, a);
    HexaVal v2 = hexa_call2(f, a, b);
    HexaVal v3 = hexa_call3(f, a, b, c);
    HexaVal v4 = hexa_call4(f, a, b, c, d);
    (void)v0; (void)v1; (void)v2; (void)v3; (void)v4;
    return v4;
}

int main(int argc, char** argv) {
    hexa_set_args(argc, argv);
    return 0;
}
