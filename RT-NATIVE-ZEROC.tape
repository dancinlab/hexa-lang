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

2026-06-17 :: M4 ARRAY-R2 — __hx_make_val(tag,payload) constructor-intrinsic
  LANDED (the symmetric WRITE-half of __hx_tag; c2/c9/c10, verdict
  F-M4-ARRAY-R2-MAKEVAL). The NAMED unblocking lever from B4 (F-M4-B4-ARRAY) +
  B1 (F-M4-B1-NANBOX): WRITES a {tag,payload} 16B HexaVal from two raw int64
  words WITHOUT hexa_int/float/str boxing (which forces a fixed tag and loses
  the caller's tag), so an array-slot payload word can be re-stamped with its
  REAL element tag. ADD-only 4 files, mirrors the landed __hx_tag/__hx_payload_*
  leaves: bind.hexa allowlist · arm64_darwin STMT_CALL leaf (disjoint x0:x1/
  x2:x3 load, lo=tag hi=payload, stp, NO bl) · x86_64_linux STMT_CALL leaf +
  _x86_hv_store_leaf_tagreg (reg tag not const: payload→r10 dst/spill, tag→r11→
  tag-slot, NO call) · self/codegen C-transpile ((HexaVal){.tag=(HexaTag)HX_INT
  (t),.i=HX_INT(p)}). DECISIVE (c2, aiden real x86_64 emit→as→link→run):
  makeval_gate exit=8 — TAG SURVIVES round-trip: make_val(TAG_STR,P)→__hx_tag==3
  (STR), NOT flattened to TAG_INT(0); +FLOAT/BOOL/INT + 4 payload-exact. No
  regression: M1 leaf gate PASS (enc 7/7 + core16/str3/arena5) + aprime smoke 42.
  Fixpoint: grep __hx_make_val over compiler/self/tool/stdlib = 0 call-sites
  outside the 4 def files → new branch dead during self-emit → whole-compiler
  bytes unchanged (interactive whole-compiler obj byte-eq = pool-wrapper OOM,
  infra limit not a regression; CI selfhost-byteeq-real authority). probe
  m4_makeval_roundtrip.hexa, gate makeval_gate.sh. Next r3 = B4 array_core
  re-attempt (get/set/pop/len via __hx_ptr_load64 + __hx_make_val; new/push/
  reserve stay C #else, WALL-2 alloc-blocked).
2026-06-17 :: M5 PILOT (rt_str) — drop-mechanism ALREADY PROVEN+SHIPPED, honest
  ALREADY-DONE (c2/c9/c16, verdict F-M5-PILOT-RTSTR). Investigation-first task to
  prove the .c-content-drop on rt_str (standalone links native rt_*.o + excise
  #else + byteeq-real green) found the work ALREADY LANDED by the Z2a campaign
  (#3455 casefold/trim · #3457 trim-ends · #3465 search-pred _b). MEASURED on aiden
  x86_64 (the EXACT CI builder CC=gcc bash tool/stage_resolve_runtime_a):
  resolve_native_rt_hi_seed runs UNCONDITIONALLY + auto-sets HEXA_ZEROC_RT_HI=1
  (seed exists for darwin-arm64 + linux-x86_64) → build_runtime_a_from_source
  sed-removes runtime_hi_gen.c #include + ar's build/rt_hi_native.o (14 rt_str_*
  syms). nm build/runtime.o: only the 2 int-return BRIDGES (starts_with/ends_with)
  are T; the 8 task-named fns (to_upper/to_lower/trim/trim_start/trim_end/
  starts_with_b/ends_with_b/contains_b + casefold) = EXTERN-only (bodies in the
  .o). Emitter rt_str body count 3(d99ecc321^) → 0(main). runtime_core.c=411120B.
  Standalone link: all rt_str_* resolved, NO undefined. byteeq-real CI GREEN on
  main (selfhost-byteeq-gate.yml = STANDALONE config). LONE residual = the 2
  int-return bridges' standalone #ifndef C body (hxlcl_strncmp/strcmp, codegen
  emits the int-return symbol; seed exports only _b HexaVal form) — ABI adapter
  below the type system, NO native body to migrate (twin of F-M4-B1 nanbox); drop
  needs new hand-asm seed fns ×2 ABIs OR a codegen call-site change → leaves the
  Z2a template → deferred codegen/seed micro-unit, NOT faked (c9/c10). RE-CONFIRMS
  F-LEGB-RTSTR-HEXASOURCE-COMPLETE + #3468 (Z2a EXHAUSTED). No emitter/build/seed
  edit → fixpoint untouched. NO PR (no genuine new drop without faking). Real
  ls==∅ lever stays M4 common-core port + runtime.c substrate redesign.
2026-06-17 :: M4 B4 array-core — mechanism-BLOCKED (construct WALL-1 + alloc
  WALL-2), array_core.hexa NOT viable, __hx_make_val NAMED as the lever.
  Read self/runtime_core.c struct+fn bodies (HexaArr{items@0,len@8,cap@16}/24;
  HexaVal{tag@0,payload@8}/16; element stride 16; cap<0 arena-sentinel; grow
  ladder 8,16,32,64). WALL-1 (B1 twin): hexa_array_get/pop/new return a 16B
  HexaVal ELEMENT but NO (tag,payload)->HexaVal intrinsic exists — every __hx_*
  leaf boxes its result TAG_INT/BOOL/FLOAT (grep-confirmed both backends +
  self/codegen.hexa); a raw payload-word load comes back hexa_int(word), the
  element's real tag lost+unre-stampable. `arr[idx]` in hexa source lowers to
  hexa_index_get (RAN build/hexat probe2) = circular. WALL-2: new=calloc,
  push/reserve=realloc+arena(__hexa_val_mark_top/arena_alloc_items/neg-cap)+
  hexa_val_heapify+_hx_stats, snapshot=arena->heap promote = real substrate,
  not intrinsic-expressible. C-diff gate scripts/scratch/rt_native/
  b4_array_gate.c links STANDALONE runtime.c (PRIMARY CI config) + drives
  new/push(empty,single,grow-to-40=>cap64)/set/get/mixed-tag(str+float)/pop/
  reserve(128)/snapshot-identity, asserting layout + each element's raw 16B
  {tag,payload} image. RAN on summer x86_64: GATE PASS 32/32, 0 fails.
  array_core.hexa NOT authored (c9/c10, circular/redundant). #else drop = NO
  until M5 (gate LINKED that standalone runtime.c => C bodies LIVE; delete =>
  release_build ./hexa link fail). UNBLOCKING LEVER (NAMED, r2): __hx_make_val(
  tag,payload)->HexaVal = the symmetric write-half of __hx_tag; ADD-only both
  backends + C-mirror + bind => fixpoint structurally preserved; unblocks B4/B5
  element returns AND B1 nanbox.hexa file-reduction (hexa_int=__hx_make_val(0,n)).
  WALL-2 alloc is SEPARATE (needs B2 arena + malloc-floor decision). No
  runtime/emitter change (ADD: gate.c + verdict). verdict F-M4-B4-ARRAY.
