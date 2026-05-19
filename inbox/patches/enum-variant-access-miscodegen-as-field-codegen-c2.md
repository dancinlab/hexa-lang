# inbox patch — enum-variant access miscodegen'd as field-access (codegen_c2)

> **status**: resolved-ssot — codegen-side Shape-A fix landed in
> `self/codegen_c2.hexa`: `gen2_enum_decl` now registers every enum
> `node.name` into a module-scope `_enum_names` set (decl pass, before fn
> bodies); the `if k == "Field"` arm consults `_is_enum_name(node.left.name)`
> for a bare-Ident left and emits the existing `<EnumName>_<VARIANT>`
> #define instead of `hexa_map_get_ic(<typename>, ...)`. Non-enum field
> access unchanged. Verified: `hexa_real parse self/codegen_c2.hexa`
> parse-clean. Runtime end-to-end (leighton/sweep `hexa run`) is
> verify-PENDING — the deployed `self/native/hexa_v2` bootstrap binary
> still predates this source edit (binary rebuild/promote is an explicit
> out-of-scope separate deploy step); the stale binary reproduces the
> exact bug (`#define RegionShape_K_BY_K` present + `hexa_map_get_ic(
> RegionShape,"K_BY_K")` emitted), confirming the diagnosis and that the
> source fix targets precisely that emission. Parser-side EnumPath rework
> deliberately NOT done (noted as the larger, more-principled option).

> Filed 2026-05-19 by the demiurge consumer session (id002 path —
> consumer hit a hexa-lang gap; inbox patch, never inline-patched).
> One concept per file. Compiler-core change → review/PR per
> CLAUDE.md "direct fold-to-live forbidden; every equation via PR".

## Symptom

`hexa run` of any module that `use`s a module defining an `enum`
and accesses a variant as `<EnumName>.<VARIANT>` fails the C compile:

```
build/artifacts/hexa_run.*.c:2948:76:
  error: use of undeclared identifier 'RegionShape'
  HexaVal inp = LeightonInput(..., hexa_map_get_ic(RegionShape,
                "K_BY_K", &__hexa_ic_224), ...);
... also TrafficKind (stdlib/booksim/traffic.hexa:68)
```

Reproduce:

```
cd ~/core/hexa-lang
hexa run stdlib/booksim/sweep.hexa      # RegionShape/TrafficKind undeclared
hexa run stdlib/booksim/leighton.hexa   # RegionShape undeclared
```

(`stdlib/booksim/booksim.hexa` works ONLY because it was forced to
`use` just `anynet` and avoid sweep/leighton — see its header note.)

## Root cause

`enum`s are emitted correctly by `gen2_enum_decl`
(`self/codegen_c2.hexa:5829`):

```
#define <EnumName>_<VARIANT> hexa_int(<idx>)   // e.g. RegionShape_K_BY_K
```

But a *variant access* `RegionShape.K_BY_K` reaches the generic
field-access arm (`self/codegen_c2.hexa:3845`, `if k == "Field"`):

```
return "hexa_map_get_ic(" + obj + ", \"" + field + "\", &" + slot + ")"
//        obj = gen2_expr(node.left)  ==>  the bare token "RegionShape"
```

So it emits `hexa_map_get_ic(RegionShape, "K_BY_K", &ic)` — but
`RegionShape` is an enum *type name*, not a C runtime value; only the
`RegionShape_K_BY_K` #define exists. Hence "undeclared identifier".

The same path breaks enum-equality: `input.region ==
RegionShape.HEX_AXIAL_R` (`stdlib/booksim/leighton.hexa:156`) — the
RHS is the same mis-emitted field access. This is exactly the
rfc_003 finding "enum-equality broken" — same underlying defect.

## Proposed fix (codegen_c2.hexa, `if k == "Field"` arm)

Before the generic `hexa_map_get_ic` emission, detect the
enum-variant shape and emit the existing #define instead:

```
if k == "Field" {
    // NEW: <EnumName>.<VARIANT> is an enum-variant constant, not a
    // runtime field access. node.left is a bare Identifier whose
    // name is a known enum type → emit the gen2_enum_decl #define.
    if node.left.kind == "Ident" && _is_enum_name(node.left.name) {
        return node.left.name + "_" + node.name      // RegionShape_K_BY_K
    }
    // ... existing generic field-access emission unchanged ...
}
```

`_is_enum_name(name)` needs an enum-name set the codegen pass already
has the data for — `gen2_enum_decl` sees every `enum` declaration;
collect `node.name` into a module-scope `Set<str>` during the decl
pass (enums are declared before fn bodies that reference them — the
ordering note at `codegen_c2.hexa:7654` confirms decls precede
bodies), then consult it in the Field arm.

If a cleaner layering is preferred: have the *parser* classify
`<UpperIdent>.<IDENT>` as an `EnumPath` node (the codegen already has
EnumPath handling per the comment at `codegen_c2.hexa:5817`), so the
Field arm never sees enum-variant access at all. Parser-side is the
more principled fix; the codegen-side guard above is the minimal,
lower-risk one.

## Impact (why this blocks measured progress)

This is the single blocker for the demiurge chip-§B measurement path
(rfc_001 §8) and the rfc_006 Yosys modules:

- `stdlib/booksim/sweep.hexa` + `leighton.hexa` + `traffic.hexa`
  cannot compile → `booksim.hexa` cannot wire `cmd_sweep` /
  `cmd_measure` → no F1F2 record → rfc_001 §8 gate stays OPEN.
- rfc_006 §4 modules (`read_verilog` / `passes` / `abc_map` /
  `write_verilog`) will hit the same wall the moment any of them
  uses an enum — they are being written int/struct-only purely to
  dodge this bug. Fixing it upstream removes that constraint.

g3: until this lands, "booksim absorbed" / chip §B
GATE_CLOSED_MEASURED cannot be claimed — not for lack of an oracle
(comb already measured d4=61,762.99 / d6=93,608.53 µm² / 1.5156×)
but because the hexa-native flow physically cannot compile its
enum-bearing modules. This patch is the gate, not the tools.

## Verification (once applied)

```
cd ~/core/hexa-lang
hexa run stdlib/booksim/leighton.hexa   # expect: its fn main() PASS
hexa run stdlib/booksim/sweep.hexa      # expect: its fn main() PASS
# then booksim.hexa can re-add `use sweep/leighton/traffic` and wire
# cmd_sweep/cmd_measure (separate follow-on).
```
