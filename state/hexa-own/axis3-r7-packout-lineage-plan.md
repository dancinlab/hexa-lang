# axis-③ R7 — narrow HEXA_SELFEMIT_PACK_OUT to the x86 ELF emit lineage

**Base:** `origin/main @ 25057d1b5` (⚠️ current local HEAD `4efa2f89b` / `fix/install-bare-cuda-pip` does NOT contain the pack-out code — branch from 25057d1b5).
**Flag:** `HEXA_SELFEMIT_PACK_OUT`, default-OFF, byte-neutral. R7 stays default-OFF; flip only after flag-ON byteeq 3-target GREEN + install smoke.

## Measured defect (R6, #4806, convergence codegen-hexa-2)
Flag-ON aprime cannot compile `fn main(){exit(6*7)}` (HX1101 ×3); native `--emit=obj` self-emit SIGSEGVs after front_begin at 632MB (NOT OOM, NOT serialize wall). OFF-path PASSes.

## Root cause (verified by source read at 25057d1b5)
The lever CREATES packed `TAG_ARRAY_I64` handles at 3 over-broad sites:
- **param block** `self/codegen.hexa:3367` — registers EVERY `[Int]/[i64]/[int]` param, across all 3364 non-emit param sites (atlas/symbolic, reachability, borrowck…).
- **empty-typed-let** `self/codegen.hexa:4691` — packs EVERY `let x:[int]=[]`, incl. atlas `let known:[int]=[]`.
- **ret-fn prescan** `:1068` / `:16449` — registers EVERY `-> [Int]` fn (e.g. `_rc_insert`).

Poly readers (`hexa_arr_poly_*`, runtime_core_emit.hexa:2941-3015) ARE tag-safe (delegate `TAG_ARRAY`→boxed), so the 5 covered use-site arms (index-get/set, push, len×2) are fine. **But** `.push`-via-`hexa_array_push` (runtime_core_emit.hexa:3196) is NOT tag-safe, and USE-SITES OUTSIDE the 5 arms (for-in, slice, concat, plain assignment) walk a packed handle as boxed stride-16 (#4133). Atlas empty-lets mint packed arrays that flow to `[int]` params and hit those uncovered sites → aprime miscompiles.

The out-lineage genuinely needs param routing: `_ew_u16/u32/u64/zero/str(out:[Int])` (elf_x86_64.hexa:94-116) grow `out` via `.push`, and `hexa_array_push` mis-walks a packed arg → **cannot** just delete the param block. So the fix is SCOPE, not removal.

## Fix — option (b) fn-lineage allowlist on CREATION sites
Confine packed origination to the x86 ELF emit lineage by fn-name prefix (`_ew_`, `_ex86_`, `encode_x86_64`, `serialize_elf_x86`, `serialize_elf_exec_x86`). Packed handles then exist ONLY inside that lineage, whose every use-site (push / index-get / index-set / len / pass-to-`_ew_*` / return) is covered. Leave the **ret-call propagation** branch (`:4695 _is_selfemit_pack_out_ret_call`) UNGATED so the one legit cross-module terminal — `main.hexa:1075 let elf_bytes = serialize_elf_x86_64(...)` — still routes.

Edits (all under `_selfemit_pack_out_enabled()`): A new predicate `_selfemit_pack_out_lineage_fn` (~:12990); B new global `_gen2_current_fn_name=""` (:6882); C per-fn assign `_gen2_current_fn_name = node.name` (:3302); D TU reset (:1056, :16437); E param gate `&& _selfemit_pack_out_lineage_fn(node.name)` (:3367); F empty-let branch `&& _selfemit_pack_out_lineage_fn(_gen2_current_fn_name)` (:4691); G ret-fn gate `&& _selfemit_pack_out_lineage_fn(ast[_gi].name)` (:1068, :16449). No change to the 5 use-site arms.

## Why the KILL does NOT fire
The terminal `write_bytes(out_path, elf_bytes)` (main.hexa:1078) is already tag-safe: `rt_write_bytes` reboxes `TAG_ARRAY_I64` under `-DHEXA_SELFEMIT_PACK_OUT` (runtime_core_emit.hexa:9418), independent of codegen registration. `len(elf_bytes)` stays poly-routed via the ungated ret-call branch. So the out-accumulator lineage IS distinguishable (fn-name prefix) and the terminal IS containable. Byte-buffer = deferred principled successor.

## Byteeq neutrality
Every edit nests under `_selfemit_pack_out_enabled()`; OFF-path (release build_aprime) all blocks are dead and the new global emits nothing → bit-identical output. R7 strictly narrows the ON surface vs R6.

## Verify gate (pool host, NOT mini)
1. `HEXA_SELFEMIT_PACK_OUT=1 bash tool/build_aprime.sh`.
2. trivial main → `grep -c HX1101` = 0 AND exit 42.
3. `HEXA_CG_PROFILE=1 HEXA_SELFEMIT_PACK_OUT=1 <aprime> --backend=native --emit=obj --target=x86_64-linux-gnu … -o self.o` → `x86_serialize` mark present, self.o = ELF x86-64, exit 0, peak RSS ~6.8GB.
4. flag-ON byteeq gen3≡gen4 3-target GREEN + install smoke before flip.

## Kill → byte-buffer successor
If step 2/3 still fails post-narrowing (packed handle escapes via the exec-path copy `native_obj_bytes = elf_bytes` at main.hexa:1088, or a lineage-internal non-`_ew_` pass), the name-based routing can't contain a value-copied HexaVal handle → switch to a dedicated `ByteBuf` (native uint8_t[]/int64_t[], `buf_*` ops + `write_bytes(path, ByteBuf)`), retyping `out:[Int]`→`out:ByteBuf` / `-> ByteBuf` across the elf_x86_64.hexa lineage so the ELF stream never lives in a tagged array.

## Follow-ons (out of R7 scope)
- arm64 emit (`serialize_elf_arm64`) — parallel lineage, add prefix when arm64 self-emit is measured.
- exec path `native_obj_bytes` copy — register or ByteBuf; only affects `--emit=exec`, not the emit=obj gate.