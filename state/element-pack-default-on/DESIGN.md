# element-pack default-ON readiness — DESIGN

## Subject
Merged lever **HEXA_PACK_ARRAY** (#4114, ebfd40b77 -> main) packs PROVEN
non-escaping typed-prim (i64/i32) arrays as raw contiguous `HexaArrI64`
(stride 8, no per-element HexaVal tag) and lets a packed element flow directly
into native `add/imul/cmp` (no boxed re-pair). Isolated measure = k3 array
~9.78x. Currently **default-OFF** (opt-in env). Question: is it safe to flip to
**default-ON** for all typed-prim arrays?

## Flip points (where default-ON would land)
- `compiler/codegen/x86_64_linux.hexa`
  - `_pack_array_enabled()` (~L1307) — `env("HEXA_PACK_ARRAY") == "1"` -> would become default-true
  - `_pack_fuse_enabled()` (~L1318) — delegates to `_pack_array_enabled()`
- `compiler/lower/hir_to_mir.hexa`
  - `_arrpk_fuse_enabled()` (~L265) — `env("HEXA_PACK_ARRAY") == "1"`
  - element-kind gate (~L219) `env("HEXA_UNBOX_ARRAY_NATIVE")||env("HEXA_PACK_ARRAY")`
- PACK is **x86_64-linux only** (arm64/darwin/nvptx have 0 PACK refs -> their
  emit MUST stay byte-identical OFF==ON; that is itself a check).

## Soundness model (what the escape lattice guarantees)
A typed-prim array local is kept PACKED iff the whole-function escape scan
(regmap builder, x86_64_linux.hexa ~L728-830) sees EVERY use as one of:
  - dst of `array_lit` / `let`
  - arg-position-0 of `index` / `index_set` / `let` (ASSIGN)
  - arg-position-0 of `push` / `len` (CALL)
ANY other appearance (call-arg to a user fn, return, value-position, 2nd
let-copy of the storage T) voids the proof -> the binding stays BOXED (V8
PACKED->HOLEY fallback). OFF leaves the lattice `[]` -> byte-identical firewall.

## Identified theoretical risk (to be MEASURED, not assumed)
`let ys = xs` (alias): the escape scan treats op=="let" at arg-0 as SAFE, so the
SOURCE `xs` is NOT voided and may remain PACKED; meanwhile the alias handle `ys`
has `let_src=xs` where `xs` is a HANDLE (not an array_lit dst), so `ys` is NOT
marked packed -> BOXED. A boxed (stride-16/tagged) read of a raw-packed
(stride-8/untagged) buffer is a layout mismatch. Kernel **Kc** targets exactly
this. If Kc diverges OFF!=ON -> real alias hole -> NO-GO.

## Verification plan (measure-first, captured outputs)
1. **escape-soundness stress** (correctness gate, cheap): 7 kernels under
   `kernels/` covering ⓐ arg-escape (Ka) ⓑ return-escape (Kb) ⓒ alias (Kc)
   ⓓ global (Kd) ⓔ untyped/non-prim (Ke) + positive control (K0) + reassign
   (Kf). For each: emit x86_64 asm with HEXA_PACK_ARRAY unset (OFF) and =1 (ON),
   link both (gcc + runtime.a), run both, assert **stdout bit-exact OFF==ON**.
   Any divergence => lattice hole => NO-GO + precise root-cause.
2. **self-host fixpoint, packing-ON** (heavy): full self-host build on aiden
   with `HEXA_PACK_ARRAY=1` in env -> assert **gen3 == gen4 byte-identical**
   (compiler's own arrays packed, determinism held) AND **ENCODE-MISS=0 /
   miscompile-zero** (self-emit faithful). Captured sha256 of cc-gen3.o/cc-gen4.o.
3. **ship smoke**: hello/exit42 compiled+run with HEXA_PACK_ARRAY=1.
4. **byteeq 3 targets**: x86_64-linux fixpoint on aiden; arm64-linux +
   darwin-arm64 must be OFF==ON byte-identical (no PACK refs) — delegated to CI
   per release-integrity rule; nvptx local where available.

## Recipe (proven, from fused-branch iso.sh)
```
HEXA_PACK_ARRAY=1 ./aprime_cc _drv.hexa --emit=asm --target=x86_64-linux-gnu -o on.s K.hexa
                  ./aprime_cc _drv.hexa --emit=asm --target=x86_64-linux-gnu -o off.s K.hexa
gcc -O2 on.s  runtime.a -o on.bin  -lm
gcc -O2 off.s runtime.a -o off.bin -lm
./off.bin ; ./on.bin   # compare stdout bit-exact
```
aprime_cc built fresh from origin/main via `tool/build_selfhost.sh -j` (stage0)
or `tool/build_aprime.sh`. runtime.a from `~/.hx/bin/build/runtime.a`.

## Verdict rubric (honesty > goal-hook)
- escape-stress ALL bit-exact AND fixpoint gen3==gen4 AND miscompile-zero AND
  smoke GREEN  => **GO** (flip `_pack_array_enabled`/`_arrpk_fuse_enabled`
  defaults to ON; byteeq 3-target CI).
- ANY red => **NO-GO**: keep default-OFF (opt-in), pin which case blocks
  (alias hole? fixpoint nondeterminism? miscompile?). No tune-to-green.
