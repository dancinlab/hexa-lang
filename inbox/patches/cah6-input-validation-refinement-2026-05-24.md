# CaH₆ Sternheimer NaN 의 root cause refinement — input cell + pressure validation

## 직전 PR #541 의 framing 정정

PR #541 (`cah6-dft-phonon-sternheimer-nan-wall-2026-05-24.md`) 이 Sternheimer NaN 을
hexa cloud 가 catch 못 한 wall 로 file 했으나, pool:ubu-2 에서 동일 candidate (CaH₆)
깨끗한 수렴 (NaN=0) 확인. 진짜 root cause = **input cell choice + pressure missing**.

## 원인

- 직전 Vast input 의 `ibrav=1, nat=14` = conventional cell (2× redundant supercell)
- BCC primitive 가 아닌 redundant cell 이 phonon 계산에서 numerical instability 유발
- `press=0` (default) — Ma 2022 의 stable pressure 170 GPa 미적용
- 두 axis 모두 user-side input error (hexa cloud bug 아님)

## 해결 (CaH₆ retry agent aae98b3f 가 확인)

- `ibrav=3, nat=7` (BCC primitive · Ca 1 + H 6)
- `press=170` GPa (Ma 2022 안정 압력)
- 결과: vc-relax JOB DONE 23 초, ph.x 깨끗한 수렴, NaN=0

## hexa cloud preflight 강화 추천 (PR #541 의 P0-P3 보완)

PR #541 의 P0 (`NaN fail-fast`) 는 *symptom* level. 본 P0-r/s 는 *root cause* level.

- **P0-r — input cell validation**: `ibrav` vs `nat` consistency check
  - 예: `ibrav=3` (BCC) → expected `nat = primitive atom count`
  - `ibrav=1` (cubic-P) 인데 nat 이 supercell-shaped 이면 경고
- **P0-s — pressure-window warning**: high-P phase candidate (H3S · CaH6 · LaH10 등) 인데
  `press=0` 이면 "stable phase 는 보통 N×100 GPa 영역, 0 GPa 의도한 것인가" 경고
- **P1-r — cell relax pre-stage 자동 권고**: vc-relax → ph.x chain 을 default 권고
  (현 cookbook 은 scf 만, vc-relax 생략 시 unstable cell 위에서 phonon 돌림)

## scope 정정

- PR #541 의 P0 (NaN fail-fast) 자체는 여전히 유효 — defensive catch 로 유지
- 본 patch 는 그 *위* 의 input validation layer (P0-r/s) 를 추가하자는 제안
- 즉 PR #541 의 P0 와 본 P0-r/s 는 stack 관계 (둘 다 필요)

## 참고

- pool:ubu-2 (`/home/dancinlife/rtsc-runs/cah6_170gpa/`) 의 clean 수렴 log 가 evidence
- demiurge RTSC.log 에 CaH6 retry 결과 (TBD entry) 와 cross-link
