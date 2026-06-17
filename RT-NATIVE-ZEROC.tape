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

2026-06-17 :: 🧱 m5 r2 — runtime_core.c standalone-#else 인구조사 TERMINAL (per-family
  drop lane EXHAUSTED). r1 의 marker-filter 인구조사(F-LEGB-RTCORE-PURE-CANDIDATES-ZERO)와
  독립적으로 r2 의 정밀 프레임(standalone #else 경로)으로 재실행 — 수렴. 생성된
  self/runtime_core.c(8734L) 를 파서로 walk: 37 `#ifdef HEXA_HAS_HEXA_RT_STDLIB` guarded
  블록(with #else:35, no-#else:2), 43 delegate-extern, ~40 guarded fn. 결정적 검증:
  43/43 native-arm extern(rt_null_coal/rt_len/rt_map_*/rt_print*/rt_cmp_*/rt_eq_*/
  rt_add_slow/sub/mul/div/mod 등) 전부 hexa-source body 보유(self/rt/core.hexa ·
  stdlib/runtime/numeric.hexa) = ALREADY-NATIVE. auto-classifier 가 6개를 PURE? 후보로
  표시했으나 본문 RAN: map_set/remove→_impl(ALLOC) · println→printf/fflush(stdio substrate) ·
  to_string→재귀버퍼(ALLOC) · null_coal/len = 진짜 pure 이나 rt_null_coal/rt_len 이미
  hexa-source(self/rt/core.hexa:32,45) = ALREADY-NATIVE. PURE-PORTABLE(포트 필요) 버킷 = 0.
  #else 정체: runtime_core.c:3173 "standalone link doesn't define HEXA_HAS_HEXA_RT_STDLIB" —
  full aprime_cc 빌드는 native arm 선택, #else = 이미-native 코드의 standalone-link 중복.
  결론: per-family native-seed 드롭 레버 EXHAUSTED(c16 TRUE-CEILING — migratable body 부재).
  잔여 ls 레버 단 둘, m5-per-family 범위 밖: (i) __hx_make_val construct-unlock(array-r2 lane,
  CONSTRUCT-WALLED arith/cmp/eq/to_string 13패밀리) (ii) standalone #else 중복제거/runtime.c
  substrate 재설계(M5 standalone-redesign lane, build 작업). 포트 강제 안 함(c9). runtime_core.c
  byte delta = 0. verdict F-M5-R2-RTCORE-CENSUS. m5 DEPLETED(per-family-drop lane).

## 2026-06-17 — alloc r2 (x86 arena): briefed #else-excise = NO-GO (dup of standing NO-GO)
RT-NATIVE-ZEROC alloc r2. branch rt-native-alloc-r2-x86-arena. docs-only.
brief: mirror arm64 rt_arena_* → x86_64 + excise #else arena + runtime_core.c bytes DECREASE.
RAN (read real bodies, no build burned):
  · arm64 rt_arena_* (runtime_arm64.hexa:2237-2543) = hexa-source emitting RAW ARM64
    MACHINE-CODE bytes (svc mmap=197/munmap=73, _arena_state ADRP+ADD PAGE21/PAGEOFF12) =
    darwin-arm64-SPECIFIC, NOT portable hexa. #else arena (runtime_core_emit.hexa:3882-4049)
    = SEPARATE portable-C linked-block bump. "mirror" = WRITE x86 machine-code emitter, no
    portable body to copy. no x86 analog (grep '^fn rt_arena' self/codegen = ARM64 only).
  · DECISIVE: arm64 rt_arena_* = PROVEN-BUT-DORMANT — consumed only by PoC/test .o
    (poc_arena_bundle_emit, emit_runtime_obj), NEVER by release_build/stage_resolve_runtime_a
    (grep empty). BOTH targets ship the C standalone arena (stage_resolve_runtime_a:271
    $CC -c self/runtime.c, no -DHEXA_HAS, #includes runtime_core.c #else). x86's shipped
    arena is C for the SAME reason arm64's is = NO mirror parity-gap. r1 "x86=bounded mirror"
    framing CORRECTED.
  · briefed bar (excise #else, bytes DECREASE) = the F-LEGB-STANDALONE-ELSE-NOGO pattern the
    brief warned against — delete = breaks release_build (CI judge); F-M5-R2-RTCORE-CENSUS
    (#3487) already TERMINAL'd per-family #else-drop. reduction reachable ONLY via forbidden
    delete = NO-GO. no source change → no CI run; byteeq-real on main GREEN, untouched.
real GO sub-unit (DEFERRED, not a reduction): x86 rt_arena_* ELF machine-code emitter twin IS
  buildable (elf_x86_64.hexa has .data/.bss + R_X86_64_64/PC32 reloc+resolve + multi-sym wrap),
  but DORMANT-parity (links into nothing shipped) ⇒ ZERO byte-delta. a brick for M5 standalone-
  redesign (relink native rt_*.o), pick up WITH that relink so it lands non-dormant.
verdict F-ALLOC-R2-X86-ARENA. runtime_core.c byte delta = 0. emitter/runtime/build UNCHANGED.
NEXT r3 = map_* allocator(arena over __hx_syscall6 mmap + __hx_ptr_*)+construct(__hx_make_val
  #3488) half, map_core_gate.c C-diff depletion test; #else drop BLOCKED-on-M5. coordinate:
  array lane owns array_core.hexa, alloc takes map_*.
PROCESS: shared-worktree collision — array lane reset --hard + committed array-r3 WIP onto this
  branch (c39f9c8a5); preserved as tag recover/array-r3-wip-c39f9c8a5, branch re-based clean on
  origin/main 8534e3173. fleet lanes must not share a worktree dir.
## 2026-06-17 — array r3 (READ-half): get/set/len/pop native raw-mem; PROVEN; ship=seed(r4)
RT-NATIVE-ZEROC array r3. branch rt-native-array-r3-arraycore (HEAD 6e6396b8f). base 8534e3173.
heavy on aiden x86_64 (build_aprime.sh → /tmp/aprime_gated, smoke exit42 PASS).
SHIPPED: stdlib/runtime/array_core.hexa (rt_array_{get,set,len,pop}_native raw-mem over
  __hx_payload_add(arr,0)=HexaArr* + __hx_ptr_load64/store64 at items+idx*16+{0,8} +
  __hx_make_val for tag-faithful element reconstruct; NO arr[idx] = no circular). delegation
  in self/runtime_core_emit.hexa gated #ifdef HEXA_RT_ARRAY_NATIVE (DEFAULT-OFF).
PROVEN (RAN aiden, c2):
  · native emit array_core.o → nm rt_array_*_native = T, ZERO undefined __hx_* (intrinsics
    inline) = frozen-.s-seed route FEASIBLE. cross-emit arm64-darwin+arm64-linux rc=0.
  · direct-call gate (b4_array_native_gate via direct_gate, native array_core.o + runtime.a)
    = exit 12 PASS: int get/set + len + MIXED-TAG set "hi"(STR)/true(BOOL) read EXACT (tag NOT
    flattened, the __hx_make_val faithfulness) + pop last + len shrink + survivor intact.
  · C oracle b4_array_gate.c (C #else path) = GATE PASS 32/32 (no-regression).
🧱 WALL-3 (bootstrap-transpile gap, c16 ≥2 lenses): importing array_core.hexa into
  compiler/main.hexa BROKE the build — hexat (C-transpile bootstrap) does NOT lower the raw-mem
  intrinsics (only self/codegen.hexa gen2 does); __hx_payload_add/__hx_ptr_load64/__hx_make_val
  undeclared (RAN). import REMOVED. runtime_hi.hexa (rt_str seed SSOT) uses ZERO __hx_ by design;
  the bodies enter ONLY via the native frozen .s seed (rt_hi mechanism build_aprime:241-263).
  build_aprime/release define HEXA_HAS_HEXA_RT_STDLIB → gating under THAT macro broke the link
  (undefined rt_array_get_native) → dedicated DEFAULT-OFF HEXA_RT_ARRAY_NATIVE → build_aprime
  PASS, fixpoint preserved (28 inert emitted-C lines, compiled active bytes unchanged).
BYTE DELTA (honest): runtime_core.c +~1KB inert text (INCREASE, not decrease) — the genuine
  ls-drop (#else removal) is r4, as briefed. selfhost-byteeq-real structurally preserved.
r4 = freeze array_core_{x86_64,arm64}.s + ar into runtime.a + define HEXA_RT_ARRAY_NATIVE +
  DROP get/set #else (first non-string runtime-substrate ls byte-DECREASE); depletion test =
  build_aprime + faithful-3target + byteeq-real GREEN w/ macro on + native .o linked + nm
  runtime.a rt_array_*_native=T (from .o not #else) + b4_array_native_gate exit12 on real
  arm64+x86_64 + runtime_core.c bytes DECREASE. array twin of alloc lane's M5 relink brick.
  verdict F-M4-B4-ARRAY-R3-READHALF. GO (proven partial, zero-regression).

2026-06-17 :: ALLOC r1 FEASIBILITY — ALLOC-floor REDUCIBLE (GO + non-circular).
  census(F-M5-R2)의 ALLOC-WALLED 버킷(map _impl·to_string·array push 의 alloc-half
  + bump-arena substrate)이 .hexa 로 표현 가능한지 RAN 조사. 결과:
  ① 인트린식 커버리지 = 100% (MISSING 0): mmap/munmap=__hx_syscall6(9/197·11/73,
     6-arg ABI 확인) · raw 64/32/8 load+store=__hx_ptr_* · bump arith=int payload ·
     bound cmp=__hx_payload_lt/ge · construct=__hx_make_val(array-r2 #3488).
  ② 순환성 = NON-CIRCULAR (결정타). bump arena 는 pre-mmap 영역 위 int64/pointer
     공간에 전부 상주 — arena BODY 가 HexaVal box/string lit/array temp 를 만들지
     않음 ⇒ hexa_array/map 으로 재귀 없음.
  ③ PoC RAN (aiden x86_64, build/aprime_m4): bump_arena_linux_poc.hexa —
     mmap(9) 8192B 슬랩 → 200 cell i^2 store/load 왕복 → munmap(11) →
     exit(sum==2646700?0:1). emit rc=0(404L asm)·as rc=0·gcc -no-pie+runtime.o
     link rc=0·RUN exit=0 ★ arena fidelity EXACT. 비순환 witness(nm/objdump):
     arena_* = T 심볼 · malloc/calloc/realloc/free/mmap 심볼참조 0 · syscall 명령
     정확히 2개(mmap+munmap=floor) · 잔여 undef = hexa_add_slow/mul/exit(int 바디
     =hexa_int(..) 스택값, alloc 없음).
  분류(c16): ARENA 플로어(bump alloc/reset/release over mmap)=GO·인트린식 100%·
  비순환(arm64 native runtime 이 이미 runtime_arm64.hexa rt_arena_* 로 hexa-source
  방출; x86_64 는 codegen 미러, missing-intrinsic 아님). calloc=fresh-anon-page
  bump(커널 zero-fill)·realloc order=alloc+ptr-copy = GO. HexaVal-RETURNING 패밀리
  (map_*/array push)=GATED-on-make_val(construct-half = array-r2 #3488 unlock).
  HONEST 잔여: 임의 블록 free + 범용 hxlcl_malloc 은 reducible 주장 안 함(bump arena
  는 bulk reset, per-object free 아님 — Go/Rust 도 syscall 위 동일 트레이드오프) =
  accounting floor, re-assessable. 진짜 irreducible floor = syscall 명령+libm,
  allocator 로직 아님. compiler edit 0(docs+PoC only, CI 무영향).
  verdict F-ALLOC-R1-FEASIBILITY. PoC scripts/scratch/rt_native/bump_arena_linux_poc.hexa.
  NEXT(r2, array-lane #3488 merge 후): hexa_arena_alloc/bump-from-arena calloc 를
  __hx_syscall6 mmap+__hx_ptr_* hexa-source 바디로 포팅(runtime_arm64.hexa rt_arena_*
  를 x86_64 native runtime + standalone path 로 미러) = 첫 ALLOC-WALLED 패밀리
  allocator-half C-free 증명. map_* 는 __hx_make_val 뒤에 체이닝.
  (NOTE: r1 의 "x86_64 = bounded mirror" 프레이밍은 후속 F-ALLOC-R2-X86-ARENA 가 정정 —
  arm64 rt_arena_* 는 dormant machine-code emitter(portable hexa 아님), shipped-runtime
  parity gap 없음. feasibility + non-circularity 발견은 유효.)

## [array-r4 LANDED + M5 roadmap clarified] 2026-06-17
- ARRAY-R4 byte-DECREASE LANDED on main (#3494, 321f038ad): runtime_core.c −1264 B/−24 L
  + faithful 3-target + byteeq-real + 10 more = 13/13 CI GREEN. get/set #else dropped to
  unconditional rt_array_{get,set}_native; 3-target native seed (darwin-arm64 + linux-x86_64
  + linux-arm64); single-TU dev builds wire build/array_core_native.o (rt_hi Z2a mirror).
  blast-radius MEASURED: authoritative gates use release_build→runtime.a(seed ar'd) + byteeq
  = object compare → gate-safe; build_aprime/build_native_linux_arm64 in NO workflow (dev).
- ROADMAP to ls==∅ (clarified, c9 honest horizon = MULTI-SESSION):
  * The remaining runtime_core.c #else bodies split into TWO buckets (per F-M5-R2-RTCORE-CENSUS):
    (A) CONSTRUCT-WALLED (arith/cmp/eq/to_string) — build a HexaVal result from computed
        words → needs __hx_make_val (landed #3488). ARRAY-R4 was the FIRST breakthrough of this
        wall. Next bricks = same template (write raw-mem hexa-source body + freeze .s seed +
        ar into runtime.a + wire single-TU dev builds + drop #else). Each ~array-sized.
    (B) ALLOC-WALLED (map _impl set/remove, snapshot, println/stdio) — needs a hexa allocator
        over mmap+__hx_ptr_* (arena lane) OR stays C substrate floor (honest-keep like Go/Rust).
  * map_get's NATIVE arm already = rt_map_get_v (hexa-source); its #else is the standalone-link
    duplicate — but map is ALLOC-walled (set/remove _impl) so the family ships C until the arena
    lane lands. map READ-half alone could brick like array if separated from set/remove.
  * self/rt/*.hexa families are mostly PURE (0 __hx_) = already hexat-transpilable (rt_str did
    this via runtime_hi_gen.c); the genuine residual #else is the construct/alloc-walled set.
  * Completion = (M4) drop each construct-walled family via the array template + (arena lane)
    unlock alloc-walled + (M5) standalone redesign linking all native rt_*.o + (M6) wholesale
    runtime_core.c drop + ls self/*.c==∅ with gen3≡gen4 on both targets. ~15-family scale.

## [M5 feasibility PROVEN] 2026-06-17
- PROBE (aiden, captured): `build/hexat self/rt/core.hexa /tmp/core_gen.c` → rc=0, 392 lines C,
  emits rt_eq / rt_cmp_{lt,gt,le,ge} / rt_len / rt_truthy bodies (externs rt_add/hexa_bool resolve
  from runtime.c). ⇒ the runtime_hi_gen.c (rt_str) gen.c-bundle pattern GENERALIZES to the pure
  self/rt/*.hexa families (0 __hx_): hexat transpiles them to standalone C with NO native .s seed.
- M5 IMPLEMENTATION (next focused cycle — fixpoint-sensitive, deserves a clean run, NOT a rushed
  tail): generate gen.c bundles for the pure rt_* families (core + numeric + …) the way
  extract_runtime_hi.sh does for rt_str; have stage_resolve_runtime_a #include them into the
  standalone runtime build + define HEXA_HAS_HEXA_RT_STDLIB for those fns; drop the now-duplicate
  #else bodies wholesale → a LARGE runtime_core.c byte-DECREASE in one cycle. GATE = build_aprime
  + faithful 3-target + byteeq-real GREEN (the gen3≡gen4 fixpoint is the campaign invariant — must
  not tune-to-green; verify by captured CI). Residual after pure-family M5 = alloc-walled families
  (map _impl/snapshot, stdio) → arena lane (hexa allocator over mmap+__hx_ptr_*) OR honest-keep as
  Go/Rust-equivalent substrate floor. Then M6 = wholesale runtime_core.c drop + ls self/*.c==∅.

## [M5/M6 mechanism FULLY MAPPED — concrete blockers + execution path] 2026-06-17
- ENDPOINT identified: `self/rt/mod.hexa` = the runtime-replacement module index ("collectively
  replace self/runtime.c"), `use self::rt::{syscall,alloc,io,fmt,proc,fs,math,...}`. M5/M6 = complete
  + transpile + wire this to drop runtime_core.c.
- PROBED on aiden (captured) — 3 concrete M5 blockers, each a bounded sub-unit for the next cycle:
  1. PER-FAMILY transpile is NOT self-contained: `hexat self/rt/core.hexa` rc=0 but the C FAILS to
     compile — core.hexa calls `hexa_call1(float_of, …)` (float_of = a HEXA fn in convert.hexa, NOT a
     C builtin). ⇒ each gen.c bundle needs its inter-family CLOSURE, not a single file.
  2. CLOSURE FLATTEN gap: `tool/larm64_flatten.py self/rt/mod.hexa` only walks `import "path"` edges,
     NOT the `use self::rt::x` path syntax the rt tree uses → produced 34L (skeleton only, modules
     unresolved). M5 needs a `use`-path resolver (extend larm64_flatten) OR import-style conversion.
  3. mod.hexa is a P7-7 SKELETON (2026-04-17): except/ffi/intern DEFERRED; the math module is a
     Taylor/Newton libm-replacement (codegen-fragile per CLAUDE.md trig rule) — completion needed.
- EXECUTION PATH (next cycles, each gated by build_aprime + faithful-3 + byteeq-real, NO tune-to-green):
  (M5a) extend larm64_flatten.py to resolve `use self::rt::` → flatten the rt closure.
  (M5b) hexat-transpile the flattened closure → rt_full_gen.c (mirror runtime_hi_gen.c) + resolve the
        float_of/int_of_float closure (convert.hexa) so it compiles in the runtime.c TU.
  (M5c) wire stage_resolve_runtime_a to #include rt_full_gen.c into the standalone build + define
        HEXA_HAS_HEXA_RT_STDLIB for the covered fns → drop their #else WHOLESALE = large byte-DECREASE.
  (arena) alloc-walled families (map _impl/snapshot, stdio) via a hexa allocator over mmap+__hx_ptr_*
        OR honest-keep as Go/Rust-equivalent substrate floor.
  (M6) wholesale runtime_core.c drop + ls self/*.c == ∅ with gen3≡gen4 on both targets.
- HONEST horizon (c9): "RT-NATIVE-ZEROC 모두 완료" = a MAJOR multi-session campaign (complete the
  self/rt/ runtime-replacement tree + the 3 blockers above). This session LANDED array-r4 (−1264 B,
  13/13 CI green) + fully mapped M5/M6 to concrete executable sub-units. Completion is NOT one-turn.

## [session handoff — next-brick terrain explored] 2026-06-17
- LANDED this session: #3494 ARRAY-R4 byte-DECREASE −1264B (13/13 CI green) · #3495/#3496 M5/M6
  full mapping · #3497 M5a (larm64_flatten resolves `use self::rt::`, compiler flatten byte-identical).
- NEXT-BRICK terrain probed (so the next cycle skips re-derivation):
  * map READ-half is NOT a clean array-template fit: HexaMapTable = open-addressing hash
    (slots[HexaMapSlot{key:char*@0, hash:u32@8, order_idx:int@12}=16B] @0, vals:HexaVal*@8,
    ht_cap:int@16, …); hmap_find = fnv1a(key) + open-addressing probe + strcmp. map_get takes
    `const char* key` (raw C string, NOT HexaVal) ⇒ porting needs fnv1a + strcmp over __hx_ptr_load8
    on a char* + a probe loop — substantial, and the char* signature fights the HexaVal-centric
    intrinsics. Viable but ~3× the array effort; do as a dedicated cycle if pursued.
  * M5c rt-stdlib #else (rt_null_coal/rt_len/rt_eq/cmp): the native arm delegates to hexa-source
    bodies (self/rt/core.hexa · stdlib/runtime/numeric.hexa) that call helpers via `hexa_call1`
    (DYNAMIC dispatch, e.g. float_of) — NOT a static use/import edge, so larm64_flatten can't
    assemble the closure. Needs the FULL rt-stdlib bundle (numeric+core+convert) transpiled together
    OR a dynamic-symbol-table seed. = the genuine wholesale M5, careful + large.
  * libc-floor (self/rt/mod.hexa, now flattenable via M5a → 8 files/2093L): P7-7 skeleton
    (except/ffi/intern deferred; math = Taylor/Newton libm-replacement). The syscall/mmap/libm core
    is the "irreducible substrate" (architecture) — partial honest-keep candidate (Go/Rust-equiv).
- ASSESSMENT (c9): each remaining brick is a substantial, fixpoint-sensitive, dedicated cycle. No
  quick clean brick remains after array (the sole new-port construct-walled case). "모두 완료"
  (ls==∅) = a major multi-session campaign with the above three lanes, all mapped + gated.
