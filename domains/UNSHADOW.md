# UNSHADOW — current state

@title: 🪆 UNSHADOW — "남의 엔진 떼기"

@goal: C/Rust 그림자를 벗은 hexa-only 스택에서 perf·자원·속도를 roofline % 기준으로 실측해 따낸다. "졸업하면 자동으로 빨라짐"이 아니라 "졸업해야 막혔던 최적화를 할 수 있다" — 소유로 열린 최적화를 측정으로 하나씩 확보.

## 전제 (별개 축과의 관계)

- `.c=0` 졸업(`drafts/dotc-graduation-plan.md` · Phase 1~5)은 UNSHADOW 의 **전제조건**(그림자 떼기). 이 도메인은 그 위에서 얻는 **perf 주권**을 측정한다 — 파일 안 겹침, 병렬 가능.
- 정직한 천장 + 재프레임(v2): raw 스칼라/벡터는 LLVM 과 비김(PTX-diff). **진짜 ROI 는 🔵 hexa-arch 추월** — LLVM 에 없는 종목(이론·증명·전스택의미·comptime). 🟡 "LLVM 재구현"은 함정, 후순위. 상세 = `UNSHADOW.easy.md`.

## milestones

- [ ] hexa-native primitive vs clang -O2 baseline micro-bench harness (재사용 측정대 · M1)
- [ ] 🟢 cross-layer 인라인 측정 — 런타임/유저 C-ABI 벽 제거 시 Δ
- [ ] 🔵 A 루프→closed-form 제거 1건 (atlas Faulhaber류 — "안 돌기" 실증)
- [ ] 🔵 C refinement-type bounds/null/tag-elision (타입정보 = 공짜 license)
- [ ] 🔵 B proof-carrying 최적화 1건 (cross-layer 인라인과 결합)
- [ ] 🟢 전용 arena reclaim 배선 — 자원(RSS·alloc 지연) 측정
- [ ] 🔵 E AoS↔SoA 자동전환 OR F CPU/GPU fusion (도메인 택1)
