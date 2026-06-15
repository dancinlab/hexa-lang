# read_f32_at — native (gen3 / arm64) toolchain link gap — FOLLOW-UP to #3357

> anima 1B model-mount finding (anima → hexa-lang/inbox per a_runpod_inbox).
> #3357 landed `read_f32_at` on the **C-emit / bootstrap** path only. The
> **active default toolchain on this host is the native self-host compiler
> (`gen3`)**, which does NOT recognise the builtin → 1B engine-generation is
> still blocked. This note specifies the exact remaining edits.

## Symptom (on a host whose default `hexa run` is native gen3)

```
$ export HEXA_LANG=$PWD
$ cat > /tmp/s.hexa <<'EOF'
fn main() { let a = read_f32_at("…/h1167_1b.bin", 20, 8); println(len(a)) }
EOF
$ hexa run /tmp/s.hexa
# gen3 path:  HexaError [HX2001] undefined name `read_f32_at`
# then launcher falls back to the pre-selfhost C-emit binary, which ALSO fails:
#   error: use of undeclared identifier 'read_f32_at'; did you mean 'rt_read_f32_at'?
#   HexaVal a = hexa_call3(read_f32_at, …)        ← codegen.hexa mapping not in the
#                                                    INSTALLED delegate binary
```

`read_bytes_at` (the #3352 sibling) compiles fine through gen3 → the native path
works for ranged readers in general; `read_f32_at` is simply unregistered there.

## Root cause — #3357 touched only `self/` (C-emit). 4 files changed:

`inbox/patches/read-f32-at-native-ranged-reader.md`, `self/codegen.hexa`,
`self/runtime.h`, `self/runtime_core_emit.hexa`.

Three things the **native gen3 toolchain** needs are therefore still missing:

1. **Binder** — `compiler/check/bind.hexa` builtin name list (line ~1256) has
   `read_bytes_at` but NOT `read_f32_at` → gen3 rejects the call as `undefined name`.

2. **Native codegen lowering** — `compiler/codegen/arm64_darwin.hexa::_builtin_runtime_sym`
   maps each builtin name → its `rt_*` ABI symbol EXPLICITLY (not auto-prefix). It has
   `read_bytes_at → rt_read_bytes_at` but no `read_f32_at → rt_read_f32_at` arm.
   (x86_64 / other targets in `compiler/codegen/` need the same arm if cross-target.)

3. **Runtime symbol** — `self/runtime_core.c` (the GENERATED, committed C; and the
   installed `rt.o`) does **not** define `rt_read_f32_at` — only `runtime_core_emit.hexa`
   (the emitter) carries the body. `nm rt.o | grep read_f32_at` → empty (only
   `_rt_read_bytes_at` is present). So even after (1)+(2), the LINK fails until the
   runtime object is regenerated from the updated emitter and re-shipped.

## Fix checklist (to make 1B load-once GENERATION actually run on a native host)

- [ ] add `"read_f32_at"` to the `compiler/check/bind.hexa` builtin name list
      (alongside `"read_bytes_at"`).
- [ ] add `if name == "read_f32_at" { return "rt_read_f32_at" }` to
      `compiler/codegen/arm64_darwin.hexa::_builtin_runtime_sym` (and the equivalent
      lowering for any other native target compiled into `gen3`).
- [ ] regenerate `self/runtime_core.c` from `self/runtime_core_emit.hexa` so
      `rt_read_f32_at` is a defined symbol; rebuild + reship `rt.o`.
- [ ] rebuild the self-host compiler (`tool/build_selfhost.sh`) → gen3 fixpoint, then
      `tool/promote_selfhost.sh install` so the active toolchain picks it up.
- [ ] sanity: `read_f32_at("…/h1167_1b.bin", 20, 8)` → `len == 8` (NOT a compile error)
      AND `len(a)` prints `8` through the DEFAULT `hexa run`.

## Why it matters

This is the gate for anima's 1B ByteGPT engine GENERATION (load-once, no 16× boxing,
~8 GB resident vs SIGKILL-137). The C-emit path of #3357 is correct but unused on
native-default hosts; the three edits above close the native path.
