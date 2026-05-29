# UNSHADOW — current state

@title: 🪆 UNSHADOW — "남의 엔진 떼기"

@goal: C/Rust 그림자를 벗은 hexa-only 스택에서 perf·자원·속도를 roofline % 기준으로 실측해 따낸다. "졸업하면 자동으로 빨라짐"이 아니라 "졸업해야 막혔던 최적화를 할 수 있다" — 소유로 열린 최적화를 측정으로 하나씩 확보.

## 전제 (별개 축과의 관계)

- runtime hexa-native frontier(RUNTIME.flip/floor)는 UNSHADOW 의 **전제조건**. 이 도메인은 그 위에서 얻는 **perf 주권**을 측정한다 — 파일 안 겹침, 병렬 가능.
- 정직한 천장 + 재프레임(v2): raw 스칼라/벡터는 LLVM 과 비김(PTX-diff). **진짜 ROI 는 🔵 hexa-arch 추월** — LLVM 에 없는 종목(이론·증명·전스택의미·comptime). 🟡 "LLVM 재구현"은 함정, 후순위. 상세 = `UNSHADOW.easy.md`.

## milestones

- [x] hexa-native primitive vs clang -O2 baseline micro-bench harness (재사용 측정대 · M1)
- [x] 🟢 cross-layer 인라인 측정 — 런타임/유저 C-ABI 벽 제거 시 Δ — `hexa_int` 정수리터럴 박스 인라인(`((HexaVal){.tag=TAG_INT,.i=(N)})`) → mini macOS arm64 hot-loop ~28% faster (1.83→1.31s), -O2 `bl _hexa_int` 13→5; g5 byte-identical (md5 5dd08ae3). 상세 = UNSHADOW.log.md
- [x] 🔵 A atlas-guided const-fold 1건 (검증식 → codegen 직접 fold, "안 돌기" 실증) — `beenet_grid_bins(100.0,10.0)` → 검증 리터럴 `hexa_int(11)` 직접 emit. g5 byte-diff IDENTICAL (HIT+NO-HIT 양쪽, md5 `166d77ac`) · 핫루프 0.26→0.09s (~65%). 상세 = UNSHADOW.log.md
- [ ] 🔵 C refinement-type bounds/null/tag-elision (타입정보 = 공짜 license)
- [ ] 🔵 B proof-carrying 최적화 1건 (cross-layer 인라인과 결합)
- [x] 🟢 전용 arena reclaim 배선 — 자원(RSS·alloc 지연) 측정 — 기존 region-reclaim opt-in(`HEXA_VAL_ARENA`+`HEXA_STR_ARENA`, default ON) fully-off 대비 **peak RSS −40% · wall −26%** (mini, `self/bench/arena_reclaim_bench.hexa`, N=400k), g5 byte-diff 4/4 IDENTICAL. 정직 caveat: constant-factor win 이며 peak RSS 는 여전히 N 에 선형(bound 아님). 상세=`UNSHADOW.bench.md §arena-reclaim`
- [ ] 🔵 E AoS↔SoA 자동전환 OR F CPU/GPU fusion (도메인 택1)
