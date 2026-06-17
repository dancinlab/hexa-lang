# RT-NATIVE-ZEROC.tape — append-only step log
@V := "RT-NATIVE-ZEROC" :: log

2026-06-17 :: M1 x86_64 leaf-intrinsic parity DONE — 25/25 __hx_* leaves ported
  to compiler/codegen/x86_64_linux.hexa (was 0; grep __hx_ empty). ADD-ONLY new
  STMT_CALL cases + 2 helpers (_x86_hv_payload/_x86_hv_store_leaf) + enabling
  const_float-payload root-fix (float_to_bits imm in _x86_op_resolve;
  _x86_64_op_for_operand_st). 2 scratch-discipline bugs caught by run+fixed
  (to_double r12→rax; syscall6 pool-stage→direct ABI regs). Encoding c2: GNU as
  ↔ objdump byte-match (x86_leaf_gate.sh §A). Semantic c2: emit→as→link→run
  core=16/str=3/arena=5 PASS on aiden x86_64. Honest residuals (orthogonal,
  pre-existing): const_str-assign bare-label + unop `!` unimplemented = M2.
  verdict F-M1-X86-LEAF-PARITY. build aiden. M1 [x].
- 2026-06-17 02:44 done: M1 x86_64 leaf-intrinsic

2026-06-17 :: M4 B1 (nanbox-ctor) — mechanism DONE, file-drop BLOCKED-on-M5.
  Found B1 already native 3 ways: (a) codegen _hv_load inline (arm64_darwin.hexa:1090),
  (b) HEXA_RT_SELFEMIT byte-emitter rt_hexa_void/int/bool/float/enum_str/enum_str_v
  (self/codegen/runtime_arm64.hexa, bundled by emit_hexa_val_ctors_o.hexa), (c) __hx_*
  read intrinsics. Authored C-differential gate scripts/scratch/rt_native/b1_nanbox_gate.c
  (PART A C-path standalone runtime.c oracle + PART B arm64 rt_hexa_* byte-seq decode) →
  RAN on aiden x86_64: GATE PASS 35/35, 0 fails (negatives/INT64_MIN-MAX/NaN/inf/+-0/
  DBL_MAX-MIN/bool/void/enum-ptr). Probed stdlib/runtime/nanbox.hexa viability via
  ./build/hexat: a HexaVal struct-literal in hexa source emits HexaVal(hexa_int(0),n) =
  self-recursive — ctors live below the type system, only byte-emitter/intrinsic express
  them; nanbox.hexa NOT authored (c9/c10, twin of F-LEGB-RTSTR already-native finding).
  #else drop-verdict = NO until M5: CI byteeq/release (release_build->stage_resolve_runtime_a
  :271) links STANDALONE runtime.c, nm shows hexa_int/float/bool/void/bits_to_float/enum_str
  all DEFINED(T) -> deletion breaks ./hexa link. No runtime/emitter change (ADD-only gate +
  verdict) -> fixpoint structurally preserved. verdict F-M4-B1-NANBOX.

2026-06-17 :: M4 PTR8 micro-PR DONE — __hx_ptr_store8/load8 byte raw-mem leaves
  added to BOTH backends (the only emitter touch in M4; unblocks B3 strbuf
  byte-write). arm64 strb/ldrb (STRB native encoder NEW in macho_arm64.hexa,
  0x39000000 base; ldrb pre-existed) · x86 mov byte ptr / movzx byte ptr ·
  self/codegen.hexa C-mirror (uint8_t cast = no sign-ext) · bind whitelist +2.
  Encoding c2: GNU as↔objdump 4/4 (x86 41 88 32 / 4d 0f b6 12; arm64 39000025 /
  39400021). Semantic c2: emit→as→link→RUN on real x86_64 (summer) exit=7 —
  ZERO-EXTEND confirmed (0xFF→255 not -1, 0x80→128 not -128) + low-byte-only +
  adjacent isolation + chainable. aprime_m4 smoke exit42; M1 gate regression
  PASS. Fixpoint preserved by construction (ADD-ONLY, compiler never calls
  __hx_ptr_*). Honest residual (c9, PRE-EXISTING M1-wide): x86 ELF object emitter
  lacks size-prefix mem-operand parse → --emit=obj ENCODE-MISS for all raw-mem
  leaves; asm-text/C-transpile/fixpoint unaffected, arm64 --emit=obj fine.
  gate scripts/scratch/rt_native/ptr8_gate.sh · verdict F-M4-PTR8. M2 raw-mem
  set complete (64/32/8). PTR8 [x].
