# UNSHADOW — current state

@title: 🪆 UNSHADOW — "남의 엔진 떼기"

@goal: C/Rust 그림자를 벗은 hexa-only 스택에서 perf·자원·속도를 roofline % 기준으로 실측해 따낸다. "졸업하면 자동으로 빨라짐"이 아니라 "졸업해야 막혔던 최적화를 할 수 있다" — 소유로 열린 최적화를 측정으로 하나씩 확보.

## 전제 — HEXA-STACK (🟡 floor 상속 + 🔵 ceiling 적층)

전략의 핵심 = **LLVM 을 재구현하지 않는다.** M1 baseline 이 native-asm 백엔드가 clang -O2 에 5/5 패배함을 실측했다. 그래서 싸우지 않고 **올라탄다**:

- **🟡 FLOOR = clang -O2 상속 (재구현 0).** C-emit 경로가 이미 clang -O2 를 그대로 통과 → loop-unroll·reg-alloc·SIMD·instruction-sched 를 전부 공짜로 상속한다. raw 스칼라/벡터는 LLVM 과 비김(PTX-diff). 🟡 종목을 직접 다시 짜는 것은 함정.
- **🔵 CEILING = hexa 고유 우위 적층.** LLVM 에 없는 종목(인라인·atlas-fold·proof-carrying·check-elision = 이론·증명·전스택의미·comptime)을 floor 위에 쌓는다. 진짜 ROI 는 여기.
- **블로커 = `runtime.o` C-ABI 벽.** 이번 사이클 두 closed-negative(#2-ext rt_str · C tag-elision)가 한 지점으로 수렴했다 — precompiled `runtime.o` 의 C-ABI 경계 너머로는 clang 이 최적화하지 못하고(🟡 손실), 🔵 cross-layer 변환도 발화하지 못한다. B(layout-only)와 #2(hexa_int, runtime.h-가시)가 통과한 이유 = 경계 안쪽 layout-only 였기 때문.
- **열쇠 = LTO / same-TU 컴파일 = `.c=0` 졸업 (= RUNTIME.flip-floor, 이미 UNSHADOW 의 전제조건).** 이 벽을 제거하면 **두 tier 가 동시에** 열린다 — clang 이 런타임을 관통해 최적화하고(🟡 parity 유지·재구현 0) 🔵 cross-layer 변환이 열린 경계 너머로 발화한다(#2-ext·C 가 🔴→win 으로 전환).
- runtime hexa-native frontier(RUNTIME.flip/floor)는 UNSHADOW 의 **전제조건**. 이 도메인은 그 위에서 얻는 **perf 주권**을 측정한다 — 파일 안 겹침, 병렬 가능. 상세 = `UNSHADOW.easy.md`.

## milestones

- [x] hexa-native primitive vs clang -O2 baseline micro-bench harness (재사용 측정대 · M1)
- [x] 🟢 cross-layer 인라인 측정 — 런타임/유저 C-ABI 벽 제거 시 Δ — `hexa_int` 정수리터럴 박스 인라인(`((HexaVal){.tag=TAG_INT,.i=(N)})`) → mini macOS arm64 hot-loop ~28% faster (1.83→1.31s), -O2 `bl _hexa_int` 13→5; g5 byte-identical (md5 5dd08ae3). 상세 = UNSHADOW.log.md
- [x] 🔵 A atlas-guided const-fold 1건 (검증식 → codegen 직접 fold, "안 돌기" 실증) — `beenet_grid_bins(100.0,10.0)` → 검증 리터럴 `hexa_int(11)` 직접 emit. g5 byte-diff IDENTICAL (HIT+NO-HIT 양쪽, md5 `166d77ac`) · 핫루프 0.26→0.09s (~65%). 상세 = UNSHADOW.log.md
- [x] 🔵 C refinement-type bounds/null/tag-elision (타입정보 = 공짜 license) — **pilot = unary-plus `+literal` 의 numeric-operand tag-guard 삭제** — IntLit/FloatLit 는 정적으로 TAG_INT/TAG_FLOAT 라 `if(!HX_IS_INT||...) hexa_throw` arm 이 unreachable. g5 byte-diff IDENTICAL (HIT+NO-HIT, md5 `e8060fb1`/`8de57030`). 정직: correctness PROVEN(무손실)·perf 는 🔴 CLOSED-NEGATIVE — clang -O2 가 리터럴-tag guard 를 이미 dead-eliminate(base/new asm IDENTICAL). inline-가시 검사는 -O2 와 중복, opaque-value bounds/null 은 runtime.o ABI 벽(#2-EXT 와 동일). 상세 = UNSHADOW.log.md
- [x] 🔵 B proof-carrying 최적화 1건 (cross-layer 인라인과 결합) — 검증된 identity 를 license 로 opaque cross-ABI call 을 layout-only 인라인으로 치환. atlas `verified-lambda_eliashberg-num`(`lambda_eliashberg(0.5)=1.0` 🟢) 이 `lambda_eliashberg(M0)≡2·M0` 보증 → codegen 이 call 대신 `((HexaVal){.tag=TAG_FLOAT,.f=2.0*HX_FLOAT(x)})` 직접 emit(#2 runtime.h-가시 layout 결합). expr 인자 let-bind 1회(single-eval 증명, calls=1). g5 byte-diff IDENTICAL(HIT md5 `570eaa65` · single-eval `d44d54ac` · no-hit emit-C 동일) · 핫루프 0.36→0.19s (~47%, `bl _lambda_eliashberg` 소거). 상세 = UNSHADOW.log.md
- [x] 🟢 전용 arena reclaim 배선 — 자원(RSS·alloc 지연) 측정 — 기존 region-reclaim opt-in(`HEXA_VAL_ARENA`+`HEXA_STR_ARENA`, default ON) fully-off 대비 **peak RSS −40% · wall −26%** (mini, `self/bench/arena_reclaim_bench.hexa`, N=400k), g5 byte-diff 4/4 IDENTICAL. 정직 caveat: constant-factor win 이며 peak RSS 는 여전히 N 에 선형(bound 아님). 상세=`UNSHADOW.bench.md §arena-reclaim`
- [ ] 🔵 E AoS↔SoA 자동전환 OR F CPU/GPU fusion (도메인 택1)
- [x] 🟡 parity 상속 명문화 — C-emit 경로가 clang -O2 패스를 **부분 상속**함을 측정 확인 (재구현 0). 축1(상속): emit-C @-O0→@-O2 = 1.19×~1.78× speedup · hot-fn instr −44% → "rides clang -O2" 참. 축2(raw parity): hexa C-emit @-O2 / idiomatic ref-C @-O2 = **7.9×~1263× (≠1.0)** — runtime.o C-ABI 벽이 cross-TU fold/LICM 차단 → raw parity 는 free 아님, `.c=0` LTO 졸업 의존. g5 3/3 value-IDENTICAL. mini macOS arm64. 상세=`UNSHADOW.bench.md §parity-attest`
- [x] 🔵×🟡 LTO/same-TU unwall 측정 — runtime.o ABI 벽 제거 후 #2-ext(rt_str)·C(bounds/null) 전환 실측 (mini macOS arm64). **진단**: emit user.c=`#include runtime.h`+별 TU `runtime.o` 링크 = 벽; 내부 헬퍼(HX_STRLEN/hxlcl_strncmp/HX_ARR_LEN)는 runtime.c 아말감 안에만. **① `-flto` 불충분**(컴파일-타임 scope 실패, LTO 발화 전). **② same-TU(`#include runtime.c`)**: #2-ext **FLIP 🔴→WIN** 0.36→0.25s −31%, byte-identical(md5 `f869400e`) — 단 win 은 clang -O2 cross-TU 인라이너(맞춤 inline emit 은 redundant, 추가 Δ 0). **C = NULL**: 벽 제거+본문 가시에도 clang 이 opaque bounds check elide 안 함(throw 잔존, Δ 0) — proof-carrying codegen 필요(deferred). verdict=`.verdicts/unshadow-lto-unwall/` · bench=`UNSHADOW.bench.md §lto-unwall` · 재현=`tool/unshadow_lto_unwall_bench.hexa`
- [ ] 🏗️ 적층 원칙 문서화 — 🟡 floor + 🔵 ceiling 스택 (LLVM 위에 올라타기, 싸우지 않기)
- [ ] 🟢 HexaVal 언박싱 / register-pack — small-int·bool·float 값-전달 시 박싱 없이 레지스터 패킹 (parity §parity-attest 의 raw 7.9~1263× 갭 주범 = HexaVal 박싱; 최대 ROI 레버). byte-diff IDENTICAL 필수
- [ ] 🔵×🟡 same-TU 빌드 기본화 — C-emit 경로 runtime same-TU(`#include runtime.c`) default 화 → #2-ext류 경계-호출 cross-layer 전면 개방 (unwall §lto-unwall 가 −31% 입증; `-flto` 불충분). 빌드시간·바이너리 영향 측정 + byte-diff IDENTICAL
- [ ] 🔵 C-class proof-carrying bounds/null elision — opaque 런타임 값 검사(array-get bounds·null)를 검증식 license 로 codegen 삭제 (unwall §lto-unwall 가 NULL 로 분리해낸 별도 axis — 벽 제거만으론 불충분, 증명 필요). byte-diff IDENTICAL 필수
