# axis-② Tier-1 #3 — array TYPED-LEAF push reduction unit (구현 SSOT)

②-terminal 3번째 유닛. 배포됨: #1 map-query(#4914·--isolate own-obj)·#2 valop(#4916·.s leaf).
설계=Fable 1차(파일접근 없는 자립 프롬프트) → **repo-검증으로 핵심 교정**(아래 §0). 이 문서가 교정 후 SSOT.

## §0 REPO-검증 교정 (Fable 1차 스펙의 오류 — 구현 전 반드시 반영)
Fable는 파일접근 없이 설계 → 다음을 몰랐음. bind.hexa/array_core.hexa 실측으로 교정:
1. **leaf 이미 존재**: `__hx_ptr_load64/store64/load32/store32/load8/store8`가 bind.hexa allowlist에 이미 있고
   `(ptr, offset)` 시그니처(`__hx_ptr_load64(desc, 8)` = desc+8 로드). Fable의 새 `__hx_mem_*` 6개 중 i64/i32
   4개는 **불요**(기존 재사용). array_core.hexa read-half가 이 패턴을 이미 증명(L100-137).
2. **typed vs poly 구분**: array_core.hexa 기존 natives(`rt_array_len/get/set/pop/shift/truncate_native`)는 **poly
   array**(HexaArr 24B·items@0·len@8 i64·cap@16 i64·16B element stride). Fable 타깃 `hexa_arr_i64_push`는 **typed
   packed**(HexaArrI64 16B·data@0·len@8 **i32**·cap@12 **i32**·8B stride) — 다른 자료구조·다른 디스패처 계열
   (guard=`HEXA_RT_CORE_ARRAY_TYPED_LEAF_NATIVE`). 기존 poly natives 확장으로 커버 불가 → 별도 typed 본문 저작.
3. **문서화된 realloc 벽**: array_core.hexa L22-36 — "push()'s realloc grow-branch stay C (🧱 the seed cannot
   express a persistent individually-freeable heap)". 단 이는 **r2(#3488) 시절 판정 = --isolate extern-carrier-call
   메커니즘(map-query #4914) 이전**. 이 유닛의 진짜 프론티어 = **그 벽이 --isolate로 realloc을 extern 심볼로
   호출(seed가 realloc 알고리즘을 native로 표현하는 게 아니라 libc realloc을 CALL)해 해소되는지 실증**. C 본문도
   realloc을 호출할 뿐이므로 --isolate seed가 U-floor에 realloc을 두면 최종 프로그램 링크(libc)서 해소 — 원리상 가능.

## §1 Feasibility 판정 (교정): i64-typed-push FIRST · realloc-wall 해소 실증이 핵심
- **i64 typed push/len/box/new = 기존 leaf + extern realloc로 표현 가능** (신규 leaf 0). len/cap=`__hx_ptr_load32`,
  data-ptr=`__hx_ptr_load64`, grow=`extern realloc`(--isolate U-floor), store=`__hx_ptr_store64(data, len*8, x)`.
- **f64 typed push = double-store가 유일 갭**: `data[len]`(double 8B) 기록. 기존 store64는 i64. double bit-pattern을
  i64로 재해석해 store64하려면 **bit-reinterpret**(numeric convert 아님) 필요 — `__hx_payload_f2i`는 valop서
  numeric convert로 쓰임(bit-reinterpret 여부 미확인). ⇒ f64는 (a)`__hx_ptr_storef64`/`loadf64` 신규 leaf 또는
  (b)f64→i64 bit-reinterpret leaf 확인 필요. **f64는 i64 성공 후 follow-on으로 분리**(유닛 축소·de-risk).
- **arena-route 기각(default-ON)**: bump-grow는 doubling마다 옛 버퍼 유기 → push-heavy(self-emit) 누수·19.87GB
  frontend 벽 하 회귀. 별도 `HEXA_RT_ARRAY_ARENA_NATIVE` 토글로 격리, 범위 밖(Fable §1 동의).

**판정**: PR-1 = **i64 typed 4-fn(new/push/len/box) native seed via --isolate, extern realloc 호출로 realloc-wall
해소 실증**. f64 4-fn = 별도 follow-on(double-store leaf 판정 후). 이렇게 하면 신규 leaf 0로 realloc-wall 돌파를
먼저 측정 → 벽이 진짜면 f64와 무관하게 조기 판명.

## §2 Fn 목록 (교정 · guard가 블록 전체 swap이므로 주의)
⚠️ **guard 스캐폴드 재확인 필요**: `HEXA_RT_CORE_ARRAY_TYPED_LEAF_NATIVE`(에미터 ~2760/3049/9408)가 i64+f64 8-fn을
**한 블록**으로 extern 전환하는지, i64/f64 블록이 분리 가능한지 실측. 한 블록이면 i64-first가 불가 → f64 double-store
leaf를 PR-1에 포함(유닛 확대). **구현 첫 스텝 = 에미터 2760/3049 블록 경계 확인**(i64/f64 분리 가능 여부가
PR-1 범위를 결정).
- 분리 가능: PR-1=i64 4-fn(new/push/len/box), PR-2 flip i64, follow-on=f64.
- 한 블록: PR-1=8-fn 전부(f64 double-store leaf 포함).
HEXA_THREADS arm = 범위 밖(ship 단일스레드 #else 미러) — Fable §2 `#error` 조합가드 채택.

## §3 Seed path: `--isolate` own-obj (map-query식) — realloc/malloc/캐리어 호출 때문
U-floor keeplist: `malloc`·`realloc`(new/push grow) · `write`·`exit`(OOM) · `hexa_throw`·`hexa_str`(box) ·
`hexa_int`(i64_box) · tag-construct 캐리어(`HX_MAKE_TAG`/`HX_SET_ARR_PTR` — ⚠️§0/Fable W3: 저작 전 nm으로 함수형
캐리어 확인; 매크로뿐이면 scalar payload/tag leaf로 인라인 tagging).

## §4 본문 + 배선 (i64-first)
구조: HexaArrI64 {data@0(8B)·len@8(i32)·cap@12(i32)}·sizeof 16·8B stride. array_core.hexa WRITE-half 확장,
C-ABI export `hexa_arr_i64_*`. 본문(에미터 실제 inline-C를 레퍼런스로 복사 — 이 스케치 아님):
```
push(v,x): a=__hx_arr_ptr(v); len=__hx_ptr_load32(a,8); cap=__hx_ptr_load32(a,12)
  if len>=cap: ncap=cap*2; nd=realloc(__hx_ptr_load64(a,0), 8*ncap)
    if nd==0: write(2,"OOM in arr_i64_push\n",20); exit(1)
    __hx_ptr_store64(a,0,nd); __hx_ptr_store32(a,12,ncap)
  __hx_ptr_store64(__hx_ptr_load64(a,0), len*8, x); __hx_ptr_store32(a,8,len+1); return v
len(v): return __hx_ptr_load32(__hx_arr_ptr(v),8)
box(v,i): a=__hx_arr_ptr(v); len=__hx_ptr_load32(a,8)
  if i<0||i>=len: hexa_throw(hexa_str("index out of bounds"))
  return hexa_int(__hx_ptr_load64(__hx_ptr_load64(a,0), i*8))
new(cap): if cap<1:cap=1; a=malloc(16); d=malloc(8*cap)  // 에미터 C 그대로(malloc 체크 유무 포함)
  __hx_ptr_store64(a,0,d); __hx_ptr_store32(a,8,0); __hx_ptr_store32(a,12,cap); return <TAG_ARRAY-boxed a>
```
⚠️ `__hx_ptr_store32/load32` 인자순서·offset semantics를 store64 사용부(L100-137)와 대조 확인. i32 store가
인접 필드(len@8 store가 data 상위/cap 하위) clobber 안 하는지 = Fable W2 tripwire(PR-1 유닛테스트).
배선: bind.hexa(신규 leaf 있으면만) · array_core.hexa 본문 · stage_resolve_runtime_a `resolve_native_array_core_seed`
symlist + `--isolate` keeplist · guard flip `-DHEXA_RT_CORE_ARRAY_TYPED_LEAF_NATIVE=1`(single-TU + MULTIOBJ 양 lane).
검증(convergence runtime-core-emit-hexa-1): `rm build/runtime.a` 선행, guard-ON nm: `hexa_arr_i64_*`=runtime_core.o `U`·seed.o `T` 양 lane.

## §5 스테이징 + 게이트 + 벽
**PR-1(extend·guard-OFF)**: (신규 leaf 있으면 bind.hexa+양 codegen) + i64 4-fn seed 본문 + resolver + regen;
기본빌드 byte-unchanged. 게이트: gen3≡gen4 byteeq(leaf 추가 시 SKIP 불가·leaf 없으면 array_core는 self/ import 여부로
neutral 판정) · byteeq 3-target · faithful-nobaseline · shipping smoke · i32-store 폭 유닛테스트(W2).
**PR-2(flip i64 default-ON)**: `-D` 양 lane + `#error` 조합가드. 게이트: byteeq 3-target · faithful · own-link corpus
parity · shipping smoke · nm U/T 양 lane 캡처.
**follow-on**: f64 4-fn(double-store leaf 판정 후).
**벽(정직)**:
- W0(★핵심 실증): realloc-wall — array_core.hexa L25가 "realloc stays C"라 문서화. --isolate extern-realloc-call이
  이를 해소하는지가 이 유닛의 실측 대상. 해소 실패(seed가 extern realloc 링크 불가·ABI 문제)면 벽 재확정+박제.
- W1: guard i64/f64 블록 분리 가능 여부(§2) — 첫 스텝서 결정.
- W2: i32 정확폭 store 인접필드 non-clobber — PR-1 유닛테스트 tripwire.
- W3: tag-construct 캐리어 함수형 존재(nm 선검증).
- W4: f64 double-store leaf(follow-on).
