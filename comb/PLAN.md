# comb/ PLAN — n=6 compute architecture R&D

> 도메인 자체 SSOT (AGENTS.tape §3 `g_plan_consolidation` 예외 — flame/forge 동형).
> Head + `## 진행 로그` (아래 chronological append).

## 헤드

- 트랙: n=6 non-von-Neumann · non-quantum 컴퓨팅 아키텍처
- 상태: DRAFT — 4축 전개 + 딥리서치 2건 완료. **RFC 057 확정** (충돌0).
- 골격 확정: **B축(육각 위상) = backbone** (Hales 2001 정리 앵커) ·
  C축 = motivation (memory wall, radix-중립) · A축 = DE-SCOPED WALL (반증됨).
- 거버넌스: 격자는 도구 (g1·g2). n=6 정리-최적은 B축 1개뿐 — 리서치 교차검증.
  타일 로직 = 이진-디지털 고정 (다치논리 금지). 모든 B 주장에 EDA-cost caveat.

## 진행 로그

- 2026-05-18 — comb/ 스캐폴드 생성 (README.md · PLAN.md · COMB.tape).
  HEXA-FABRIC 컨셉 + 3축 분해 + 실제-한계 정직 평가표 저장. 축 선택 user gate 대기.
- 2026-05-18 — user "전부 진행 + arxiv/web 딥리서치". 산출:
  · research/SURVEY.md — 딥리서치 2건(arxiv+web) 교차검증 통합 (출처 포함)
  · axis_b_topology.md — B backbone (Hales 2001 / kissing#6 / Leighton B3)
  · axis_a_radix.md — A DE-SCOPED, HARD_WALL ×3 (radix economy·noise·EDA)
  · axis_c_model.md — C motivation (memory wall 측정, radix-중립)
  · RFC.md — 합본 초안: degree-6 hex fabric + 이진 타일 + 5 falsifier
  핵심 발견: 상용 degree-6 실리콘 0건; UC Davis 65nm 2012 단 1측정(13yr stale).
- 2026-05-18 — RFC 번호 **057 확정** (inbox/rfc_drafts 체인 rfc_056 위, 충돌0;
  proposals/ 흡수체인 044–048 과도 무충돌). comb/ 커밋 (branch rfc043-hexa-torch,
  comb/ 경로만 — 타 세션 작업 미포함). 다음 게이트: F1/F2 해소용 hex NoC
  시뮬 (modern node) — user gate 대기.
