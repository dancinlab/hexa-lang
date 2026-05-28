# UNSHADOW — current state

@title: 🪆 UNSHADOW — "남의 엔진 떼기"

@goal: C/Rust 그림자를 벗은 hexa-only 스택에서 perf·자원·속도를 roofline % 기준으로 실측해 따낸다. "졸업하면 자동으로 빨라짐"이 아니라 "졸업해야 막혔던 최적화를 할 수 있다" — 소유로 열린 최적화를 측정으로 하나씩 확보.

## 전제 (별개 축과의 관계)

- `.c=0` 졸업(`drafts/dotc-graduation-plan.md` · Phase 1~5)은 UNSHADOW 의 **전제조건**(그림자 떼기). 이 도메인은 그 위에서 얻는 **perf 주권**을 측정한다 — 파일 안 겹침, 병렬 가능.
- 정직한 천장: LLVM/clang -O2 는 스칼라/벡터에서 이미 roofline 근처. 증거 = PTX-diff(vec-add 동일=bandwidth-bound, GEMM nvcc 2~4×=LLVM loop-unroll/ILP). 이득은 "C-ABI 벽이 막던 cross-layer 최적화"에서 나옴, raw 벤치는 LLVM 급을 재구현해야.

## milestones

- [ ] hexa-native primitive vs clang -O2 baseline micro-bench harness (재사용 측정대)
- [ ] cross-layer 인라인 측정 — 런타임/유저 C-ABI 벽 제거 시 Δ (가장 유망한 이득축)
- [ ] 전용 arena allocator vs libc malloc — 자원(RSS·alloc 지연) 측정
- [ ] atlas-guided codegen fold 1건 실증 (검증식 → codegen 직접 fold)
- [ ] custom calling-convention (내부 호출 C-ABI 세금 제거) 측정
