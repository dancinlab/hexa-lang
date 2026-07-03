# element-pack escape-lattice transitive fix — DESIGN

## Defect (measured, NO-GO from the readiness probe)
HEXA_PACK_ARRAY=1 miscompiled arrays that escape or alias:
  ka_arg_escape  OFF=4096  ON=4095            (arg-escape off-by-one)
  kc_alias       OFF=2126  ON=<value>999064   (alias tag-corruption)
asm-confirmed root cause: a typed-prim array lowers to TWO MIR locals that share
ONE buffer — storage `T` (`array_lit`) and handle `X` (`let X=T`, a HexaVal copy
of T's descriptor). The whole-function escape scan in
compiler/codegen/x86_64_linux.hexa (regmap builder) cleared the packed bit
PER-LOCAL, INDEPENDENTLY, and counted `op=="let"` at arg-position-0 as a
non-escaping "safe" use. So it could leave one member of an aliasing pair PACKED
while the other (a handle / param / second alias) was BOXED. A boxed
(stride-16/tagged) access of a raw-packed (stride-8/untagged) buffer is a layout
mismatch → wrong results.
  - ka: handle X escapes via `sumarr(xs)` → X cleared (boxed), but storage T
        (only used in the safe `let X=T`) stays packed → callee reads packed
        buffer boxed.
  - kc: `let ys = xs` → xs (handle) is args[0] of a `let` = "safe" → xs stays
        packed; alias ys is not marked packed → boxed → ys reads xs's packed
        buffer boxed.

## Fix (reference-match: V8 PACKED→HOLEY made TRANSITIVE over the alias set)
INVARIANT: a packed array and a boxed alias of the SAME buffer must never
coexist. Implemented as an **alias-coherence fixpoint** pass appended to the
regmap builder, after the existing per-local escape scan:

  iterate to fixpoint over every `let A = B` (B a local):
    if rm_packed_ok[A] != rm_packed_ok[B]:   # straddles packed/boxed
        rm_packed_ok[A] = 0; rm_packed_ok[B] = 0   # void BOTH ends

Because a `let A=B` copies B's descriptor into A (they share one buffer), any
disagreement on packed-ness is unsound → both fall back to boxed. Iterating to
fixpoint propagates the void along the whole alias chain (T→X→Y) and also folds
in the escape-scan's per-local void (an escaped handle X drags its storage T to
boxed through the canonical `let X=T`). This SUBSUMES the per-local escape void
for aliased buffers; it is the minimal change that restores the invariant.

Why it preserves the 9.78× fast path: a non-aliased packed array (k3_arrmap:
used only via push / index / index_set, with its sole `let X=T` where BOTH are
packed) never straddles → the coherence pass leaves it packed. The pass only
ever VOIDS (tightens), never adds packing, so it cannot introduce new
miscompiles — worst case it boxes a benign alias (correctness preserved, only
that alias loses the fast path).

scope: native x86_64-linux codegen path only (where element-pack lives). The
default stays env-gated OFF; this makes the opt-in (HEXA_PACK_ARRAY=1) SOUND.
A separate default-ON flip is gated on: escape-stress 9/9 bit-exact +
packing-ON self-host fixpoint (gen3≡gen4, ENCODE-MISS=0) + smoke + 9.78× held.

## Patch location
compiler/codegen/x86_64_linux.hexa — regmap builder, inserted after the escape
scan (`while pb2 ...`) inside the `if _pack_array_enabled()` block (~L829).

## Verification (measure-first, captured outputs — see RESULT.txt)
1. escape-stress 9 kernels (adds Kg direct-alias, Kh alias-then-escape) — all
   OFF==ON bit-exact on the FIXED compiler; ka/kc must FLIP to PASS.
2. no-regression: k0/k3 still emit the packed path (grep ON asm).
3. packing-ON self-host fixpoint (gen3≡gen4 + ENCODE-MISS=0).
4. ship smoke (hello/exit42, HEXA_PACK_ARRAY=1).
5. k3_arrmap 9.78× re-measure (alternating OFF/ON).
GO iff all green → escape-fix PR (+ default-ON flip PR). Any RED → honest pin.
No tune-to-green.
