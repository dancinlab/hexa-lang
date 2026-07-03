# LANE B — adjacent unbox levers default-ON polarity flip

HEXA-UNBOX wire-to-prod, lane B. Follows the #4163 precedent (element-pack 9.78×
`HEXA_PACK_ARRAY` flipped `=="1"` → `!="0"` once the regular 3-target byteeq gate
was GREEN).

## What flipped (3 spots, `=="1"` → `!="0"`, opt-OUT via `=0`)

| Lever | Spot | env | Origin / measured win |
|-------|------|-----|-----------------------|
| scalar BinOp unbox | `_unbox_native_enabled()` `compiler/codegen/x86_64_linux.hexa:1332` | `HEXA_UNBOX_NATIVE` | #4055 / R5 k1 2.95× |
| native array elem load/store | `_unbox_array_enabled()` `compiler/codegen/x86_64_linux.hexa:1446` | `HEXA_UNBOX_ARRAY_NATIVE` | #4080 r2c k3 2.7× |
| type-id stamping gate clause | `_arru_native_enabled()` `compiler/lower/hir_to_mir.hexa:225` | `HEXA_UNBOX_ARRAY_NATIVE` | (already default-ON via `HEXA_PACK_ARRAY!=0`; flipped for polarity consistency + so stamp fires when PACK opt-OUT but UNBOX_ARRAY at default) |

`grep -rn HEXA_UNBOX_NATIVE\|HEXA_UNBOX_ARRAY_NATIVE compiler/` confirms the fn
defs are the single gate source — all other hits are comments / diagnostic probes.

## Why byteeq-safe (no #4163-class aliasing hazard)

These levers do NOT have the array-aliasing escape issue `HEXA_PACK_ARRAY` had:
- scalar unbox = no array involved at all (provably-int BinOp → native ALU path).
- index-unbox = **boxed storage is unchanged**; it is a native READ path only
  (HexaArr descriptor walk + inline addressing, bounds-check kept). The element
  TAG is preserved exactly as the runtime would return.

OFF (`=0`) path is byte-identical to pre-flip origin by construction (only the
default polarity reversed). x86_64 codegen only; arm64 / gen2 C-transpile / nvptx
are no-ops for these gates.

## Gate (release-integrity > self-host)

NEVER merge before the regular 3-target byteeq is GREEN:
- selfhost byte-eq gen3≡gen4 + determinism + miscompile-zero + codegen-guard
- faithful-nobaseline ×3 (darwin-arm64 / linux-arm64 / linux-x86_64)
- nvptx + shipping smoke

CI = free github-hosted + self-hosted pool (Blacksmith FORBIDDEN, #4016 revert).
mini = git/gh only → local verify impossible → PR → CI decides gen3≡gen4.

Both levers flip at once → if any blocking gate goes RED, bisect (isolate each
lever) before any conclusion. No tune-to-green, no force-merge on RED.

SSOT: memory `project_hexa_runtime_gap_allclosure`.
