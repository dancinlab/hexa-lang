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
  의존). caveat 5건 동반.
- 2026-05-18 — **T1-B-oracle 완료** (`comb/sim/`): T1-B 를 분할 —
  *T1-B-oracle* (graph-level, comb-내부) + *T1-B-full* (wire model +
  congestion, hexa-arch[chip] 의존). 산출: `T1A_verify.txt` (수치 sanity)
  + `noc_distance.hexa` (hexa parse PASS · build OK · 컴파일 바이너리
  실행 → `noc_distance.out`). N=10000: D_hex/D_mesh = 114/198 = 0.5758 ≈
  1/√3 = 0.5774. decoupling 재정의: comb 가 안 하는 것 = 외부 EDA *흡수*
  (hexa-arch); comb 가 하는 것 = 자체 graph-level harness.
- 2026-05-18 — **T2-partial (F1 비경쟁 verdict)** ⭐️ WIN: 비경쟁
  (non-contention) NoC 모델 (Dally & Towles 2004 §3.7 baseline)
  hexa-native 파라메트릭 sweep — `comb/sim/f1_parametric.hexa` (parse
  PASS · build OK · 실행) → `f1_parametric.out`. sweep 차원: t_router_d6
  ∈ {100,150,200}, e_diag ∈ {100,130,175} × N ∈ {256,1024,10000}.
  **결과: 8/8 sweep 행 모두 degree-6 net win** (lat·energy 둘 다).
  근거: D_hex/D_mesh ≈ 0.53 (1/√3 영역) 의 hop 절감이 per-hop 페널티
  (router 1.5x + diag RC 1.75x 최악)를 압도. cross-over: t_router_d6
  ~276 (2.76x baseline) 부터 latency 패배 — 현실 d-linear 1.5x 영역
  훨씬 안. **F1 비경쟁 영역 = degree-6 우세** (RFC 057 §5 F1 falsifier
  비경쟁 한정 통과). caveat: congestion·real-workload·peak distribution
  은 T1-B-full 후 측정 필요 — non-contention 은 lower bound 일 뿐.
  다음 = (a) RTL 스텁(comb-side hexa→Verilog emitter) 으로 T2 RTL 측면
  착수 (b) T1-B-full = hexa-arch[chip] BookSim2 흡수 후.
- 2026-05-18 — **T2 RTL 첫 바이트** (`comb/rtl/emit_routers.hexa` →
  `routers.v` 36줄 스텁). hexa-native Verilog emitter — datapath 미충전.
- 2026-05-18 — **T2 RTL → synthesizable** (`comb/rtl/router_d{4,6}.v`):
  ⭐️ 263줄 합성가능 RTL 작성. router_d4 (5-port XY routing, RR arbiter,
  4-deep FIFO, crossbar) + router_d6 (7-port axial hex dim-order routing,
  동일 구조). **외부 도구 검증**: `iverilog -g2012 -Wall` 둘 다 exit=0
  (sensitivity-list 경고만, benign). T2 RTL 측면 = port skeleton →
  **외부-도구-검증된 합성가능 architectural RTL**. tapeout-ready 까지는
  여전히 Yosys 합성 + OpenROAD P&R + SKY130/SG13G2 PDK 매핑 + DRC·STA =
  hexa-arch[chip] 영역. T2 ~30-40% (sim 비경쟁 PASS + RTL 합성가능).
  T3 = 0%. 다음 = (a) cocotb/SymbiYosys 테스트벤치 (b) hexa-arch[chip]
  Yosys 흡수 후 합성 측정.
- 2026-05-18 — **T2 cycle-accurate functional verify + real workload**:
  ⭐️ `comb/rtl/router_d6_tb.v` + iverilog 실행: 4 destination cases
  (dq=+3 → PQ, dq=-2 → NQ, dr=+4 → PR, local → LL) **4/4 PASS**. 합성
  가능 router_d6.v 가 실제 패킷 트래픽을 cycle-accurate 시뮬에서 올바르게
  라우팅 — RFC 057 T2 sim 측면 *cycle-accurate functional verification*
  최초 도달.
  ⭐️ `comb/sim/workload_f1.hexa` → `workload_f1.out`: 4 real workload
  패턴(uniform/broadcast/hotspot/stencil) × 2 N(1024,10000) F1 verdict.
  **결과: uniform/broadcast/hotspot 에서 degree-6 net win, stencil 에서
  degree-6 LOSE** (1-hop nearest-neighbor 은 router-port 비용만 페널티).
  honest workload-dependent verdict — over-claim 아님. RFC 057 F1
  falsifier 는 workload class 별 결판되며, dense·broadcast traffic 에선
  hex 우세 / nearest-neighbor 에선 mesh 우세.
  T2 sim 측면 ~60% (non-contention + real workload + router cycle-accurate
  verify). T2 RTL 측면 ~50% (synth + functional sim). T2 ~50-60%. T3 = 0%
  (hexa-arch[chip] RTL→GDSII 의존).
