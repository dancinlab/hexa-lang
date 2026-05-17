# comb/ PLAN — n=6 compute architecture R&D

> 도메인 자체 SSOT (AGENTS.tape §3 `g_plan_consolidation` 예외 — flame/forge 동형).
> Head + `## 진행 로그` (아래 chronological append).

## 헤드

- 트랙: n=6 non-von-Neumann · non-quantum 컴퓨팅 아키텍처
- 궁극 골 (T2+T3, user-확정): degree-6 hex 이진-타일 spatial PIM > degree-4
  mesh @ modern node 를 hexa-native 사이클정확 시뮬+RTL 로 입증/반증 → 물리
  -실현 *설계*는 별도 standalone repo `~/core/hexa-arch` 의 chip 도메인
  (외부 EDA 흡수는 *그쪽* 책임)을 *사용*해 산출 — comb=소비자 (fab 비목표).
  SSOT = root `GOAL.md` ③ + `~/core/hexa-arch/HANDOFF.md`.
- 상태: DRAFT — 정초 완료. **RFC 057 확정** (충돌0). T1(hex NoC sim) 미착수.
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
  proposals/ 흡수체인 044–048 과도 무충돌). comb/ 커밋 c0e7aae7 (branch
  rfc043-hexa-torch, comb/ 경로만 — 타 세션 작업 미포함).
- 2026-05-18 — **궁극 골 확정** (user gate, T2+T3): T2 = degree-6 > degree-4
  입증/반증 (hexa-native 사이클정확 시뮬 + tapeout-ready RTL), T3 = 물리
  -실현 *설계*를 별도 standalone repo `~/core/hexa-arch` 의 chip 도메인을
  *사용*해 산출 (comb=소비자, EDA 흡수는 hexa-arch; fab/FPGA 비목표;
  hexa-arch 생성 commit c812ac6). root `GOAL.md` ③
  comb north-star + RESUME 복붙블록 추가. comb/ + GOAL.md 커밋 55b9af4f.
- 2026-05-18 — comb 진행: `T1_experiment.md` 작성 (F1/F2 pre-registered
  측정 명세 — 두 위상 정밀정의 · modern-node wire model 변수 · Leighton
  symbolic 앵커 · pass/fail · hexa-arch[chip] 인터페이스). T1 분할:
  **T1-A** 해석적 앵커(comb-side, sim 불요) / **T1-B** sim 측정(blocked-on
  hexa-arch[chip] NoC sim 흡수).
- 2026-05-18 — **T1-A 완료** (`comb/T1A_analytical.md`): 표준 NoC 문헌
  인용 정리. 핵심 상수: N hex region = 3R²+3R+1 · diameter hex/mesh = 1/√3 ≈
  0.577 · avg dist hex/mesh = 1/√3 · #links 1.5× · degree 1.5× · hop 절감
  ≈ 0.845√N. 승리 부등식 §3 (좌변 그래프 상수 고정, 우변 process·placement
  의존). F1/F2 operationalize 완성. caveat 5건 동반 (least-perimeter≠
  least-latency · honeycomb≠hexagonal mesh 명명 등). 산술 모두 elementary,
  sympy/Wolfram 인용 0. 출처: Leighton 1992 · Dally & Towles 2004 · Hales
  2001 · Conway/Sloane 1999 · Stojmenović 1997 · Stillmaker/Baas 2012.
  다음 = T1-B (hexa-arch[chip] NoC sim 흡수 후, 별도 repo 진행).
