# CaH₆ DFT phonon Sternheimer NaN wall — Vast.ai + pool dual platform finding

## TL;DR
7-atom sodalite clathrate CaH₆ (Ma 2022 NATURE 605:147, measured Tc 215 K @ 172 GPa)
DFT phonon 6³q (16 irreducible q-points) 두 platform 에서 모두 numerical
divergence 또는 OOM. demiurge RTSC §9 first-principles el-ph campaign 의 검증
경로가 두 dispatch backend 모두에서 막혔다.

## Platform 1 — pool:ubu-1 (apt QE 7.0)
- 시작: 2026-05-22 ~13:50
- SIGKILL/OOM at 2026-05-22 15:35 (≈1h45m)
- 3/21 representations 완료 후 process dead
- artifact: `done.flag=CAH6_DONE` watcher 가 success 로 오인 — 실제로는
  partial-output + OOM kill. JOB DONE marker 부재 시 fail 처리 필요.

## Platform 2 — Vast.ai pod 37378728 (~/local QE 7.5 conda)
- `-np 32` 첫 시도: MPI deadlock, no progress for >20min
- `-np 15` restart: 진행은 하나 q-point 5 부터 numerical 발산
- ph.out 패턴: `Sternheimer kernel root not converged · thresh < NaN` spam
- Rep #1 of q6 에서 15 ph.x MPI workers 99% CPU 점유, 그러나 stuck
- 5/16 irreducible q-points 후 dead

## 분석 — hexa cloud gap?
- `hexa cloud preflight` 가 small-cell (≤10 atom) + dense q-grid 조합의
  MPI deadlock / Sternheimer convergence wall 을 예측 못 함
- small-cell + dense q-grid 가 비단조 `-np` scaling sweet spot 을 가짐
  (너무 적으면 메모리 압박, 너무 많으면 MPI deadlock) — preflight 미인지
- done.flag watcher 만으로 success 판정 시 partial-output OOM 을 PASS 로
  오인 (Platform 1 사례)

## breakthrough paths 제안 (campaign 직접 적용 + hexa cloud 상위 흡수)
1. `tr2_ph` threshold 완화: 1e-14 → 1e-15 (Sternheimer 수렴 여유)
2. `nmix_ph` 증가: 4 → 6 (charge-mixing damping 강화)
3. `-np` 추가 축소: 15 → 8 (small-cell sweet spot 재탐색)
4. cell pre-relax: `vc-relax` 먼저 (응력 잔존 → 음파수 → 발산 가설)
5. `electron_phonon='interpolated'` recovery mode (q-point checkpoint)

## hexa cloud 가 흡수해야 할 패턴
- **small-cell DFT preflight**: q-grid × atom-count → `-np` 추천 sweet-spot
  mapping (예: ≤10 atom + 6³q → -np 8-12 권장)
- **Sternheimer NaN fail-fast**: `grep -c "thresh < NaN" ph.out > 100` 시
  즉시 abort + 위 breakthrough paths surface
- **OOM detect**: RSS > 90% for >30min → checkpoint write + restart with
  reduced -np (지금은 hard kill 만)
- **done.flag watcher 강화**: `CAH6_DONE` 같은 sentinel 외에 QE 의 native
  `JOB DONE` marker 도 함께 require (watcher artifact 회피)
- **dual-platform divergence diff**: 같은 input 이 pool/Vast 양쪽에서 다른
  wall 에 부딪힐 때, hexa cloud 가 cross-platform symptom diff 를 자동
  수집 → inbox 자동 생성

## 우선순위
- **P0**: Sternheimer NaN fail-fast (현재는 hours 낭비 후 발견)
- **P1**: small-cell `-np` sweet-spot preflight (deadlock 사전 회피)
- **P2**: done.flag watcher dual-marker (false-success 회피)
- **P3**: dual-platform symptom diff auto-collect

## 참조
- demiurge RTSC.md §9 (CaH₆ first-principles el-ph campaign)
- Ma 2022 NATURE 605:147 (measured target)
- pool:ubu-1 log: ~/core/demiurge/state/cah6_dft_pool_20260522.log
- Vast 37378728 log: ~/core/demiurge/state/cah6_dft_vast_37378728.log

## 비고
@D d9 (project.tape) 에 의거하여 Vast finding 을 paper-over 하지 않고
upstream `hexa cloud` 로 surface. campaign 자체 breakthrough paths (위
1-5) 는 demiurge 측에서 병행 시도. 본 patch 는 hexa cloud 의 preflight
정책 / fail-fast / watcher 강화 권고만 담는다.
