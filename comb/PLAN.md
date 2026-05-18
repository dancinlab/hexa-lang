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
  T2 sim 측면 ~60%. T2 RTL 측면 ~50%.
- 2026-05-18 — **🎉 BREAKTHROUGH: yosys 실합성 완료**: brew 로 yosys 0.65
  + sv2v 0.0.13 시스템 설치 (`/opt/homebrew/bin/{yosys,sv2v}`, 가역).
  sv2v 가 SV array port → V2k flat 변환, yosys 가 generic synth. 측정
  결과 (`comb/rtl/{router_d4,router_d6}.synth.out` + `synth_comparison.md`):
  cell 수 router_d4 = **12,105**, router_d6 = **21,790**, **ratio 1.80×**
  (assumption 1.5× 대비 worse — but F1 검증). DFF 1.39× · MUX 1.65× ·
  XOR 4.07× (hex 의 3축 route compare 가 조합 폭증 견인).
  **F1 재계산 (실측 t_r6=180 적용)**: lat hex/mesh = 9520/12800 = 0.744
  (25% win) · energy hex/mesh = 10030/12800 = 0.784 (22% win). **F1
  verdict robust** — 측정된 synth 비용에서도 비-stencil workload 모두
  hex 우세 유지. cross-over t_r6 = 276 → 50% margin.
  T2 RTL 측면 ~50% → ~70% (RTL synthesis 완료, PDK 매핑·STA·P&R 미수행).
  T2 overall ~60-70%. T3 = 0%.
  다음 strict tapeout step = SKY130 std cell library 매핑 (`yosys -p
  "abc -liberty sky130_fd_sc_hd__tt_025C_1v80.lib"`) → 실 area in mm² +
  OpenSTA timing → OpenROAD P&R → DRC.
- 2026-05-18 — **🎉 BREAKTHROUGH: SKY130 ASIC PDK 매핑 완료**:
  efabless mirror `skywater-pdk-libs-sky130_fd_sc_hd` git clone →
  `sky130_fd_sc_hd__tt_025C_1v80.lib` (12.8 MB) 확보. yosys+dfflibmap+abc
  로 진짜 ASIC 매핑. 실측 chip area:
    router_d4 = **61,762.99 μm²** (0.062 mm², 79% sequential)
    router_d6 = **93,608.53 μm²** (0.094 mm², 73% sequential)
    **ratio = 1.516×** (FPGA 1.37-1.41× 와 generic 1.80× 사이; 1.5×
    가정과 ±1% 일치)
  F1 재검증 (실측 t_r6=152): lat hex 33% win, e hex 29% win, cross-over
  t_r6=276 → 1.8× margin. **SKY130 ASIC 실측 면적 비용에서도 F1 PASS**.
  비-stencil workload 전수, stencil 은 여전히 mesh 우세 — workload-
  dependent verdict 4번째 PDK flow 에서도 robust. T2 RTL 측면이 strict
  ASIC PDK-mapped 단계 도달. T2 RTL ~85% → ~95% (PDK-mapped area 실측
  완료, OpenSTA timing + OpenROAD P&R + DRC 만 남음 — 별도 도구 설치).
  T2 overall ~80-85%. T3 = 0% (P&R + GDSII 미수행).
- 2026-05-18 — **🎉 OpenROAD cmake CONFIGURED + make 빌드 시작**:
  의존성 전수 해결 (다단계):
    brew: bison · lemon(parser) · spdlog · or-tools · swig · flex ·
          googletest · yaml-cpp · libffi · libomp · cmake · boost · eigen
          · tcl-tk · klayout(cask)
    source: COIN-OR LEMON graph 1.3.1 (cs.elte.hu, CMakeLists 패치) →
            /opt/homebrew/opt/coin-lemon
            CUDD 3.0.0 (github ivmai/cudd) → /opt/homebrew/opt/cudd
    cmake flags: OpenMP_CXX_FLAGS (macOS clang + libomp), LEMON_DIR,
                 CUDD_LIB, TCL_LIBRARY, FLEX_INCLUDE_DIR,
                 BISON_EXECUTABLE 명시
  cmake configure: Makefile 생성 (4.5s generate). repo 1.7GB / 8551 files
  + submodules (OpenSTA, abc). make -j4 background (PID 25059) — 빌드는
  3rd-party ABC + odb/def + libabc 부터 진행 중. 추정 30-60min.
  → 완료 시 `/tmp/OpenROAD/build/src/openroad` 바이너리 생산. 그 시점
  부터 comb 가 P&R 직접 실행 가능 (router_d6 → routed netlist → GDSII).
  T3 의 "별도 hexa-arch[chip] 절대 의존" 가정이 깨짐 — comb-side 에서도
  도구 풀체인 설치 가능. 단 P&R 실행 자체 (SDC + def + lef 설정 +
  routing 단계) 는 별도 multi-cycle 작업.
- 2026-05-18 — **T1-B-full 첫 입력 record 도달** (consumer-side
  observation): hexa-arch[chip] 가 본 campaign 의 첫 F1/F2 pair-verdict
  record 를 emit. 위치 = `~/core/hexa-arch/exports/chip/noc/f1f2/
  pair_verdicts/2026-05-18_d4_vs_d6_tornado_22nm_4ghz.json` (baseline
  record = `records/2026-05-18_d4_mesh_tornado_22nm_4ghz.json`,
  candidate = `records/2026-05-18_d6_hex_tornado_22nm_4ghz.json`).
  **verdict = INCONCLUSIVE** (f1, f2 둘 다) — rfc_001 §9 live open Qs
  (i) hex placement variants · (ii) clock-frequency sweep across
  1–6 GHz · (iii) newer-FinFET wire-delay sensitivity 가 미해소.
  내부 비공식 표기는 LEAN-PASS-FOR-D6 (이 단일 (4 GHz, 22 nm, axial-
  hex-on-square-grid placement) 포인트에서 d=6 가 zero-load latency
  0.887×, saturation throughput 1.26× — 1.5× router port cost 와 2-
  cycle 대각 link 페널티 *후*); verdict enum 은 INCONCLUSIVE 유지
  (g3 no-over-claim · single point ≠ regime claim).
  계약: `hexa-arch:chip:noc:F1F2-pair-verdict` schema_version 1.0
  (`COMB.tape @X x_hexa_arch_f1f2_schema`; rfc_002 §3 + §D); carrier
  HXC v2 deferred (rfc_002 §9), JSON interim. provenance.absorbed =
  false (`measurement_gate = GATE_OPEN`; rfc_002 §4 + §8); record =
  capture-only. T2-partial f1_parametric (8/8 sweep degree-6 net win,
  non-contention only) 과 *독립* 측정점 — congestion·real-workload·
  peak distribution 은 여전히 hexa-arch[chip] 흐름 (T1-B-full 후속
  스윕 + rfc_001 §9 open Qs 결판) 이 채울 영역.
  다음 = (a) `T1A_analytical.md` §8 매핑표로 §3 부등식 우변 변수
  채우기 (b) rfc_001 §9 open Q 결판 대기 — pair verdict 가 PASS/FAIL
  로 굳을 때까지 RFC 057 F1/F2 closed-status 보류.
- 2026-05-18 — **T3 P&R 전환: macOS → ubu-2 Docker (ORFS)**. macOS 로컬
  OpenROAD 빌드 dead-end (부하·pool-routing 충돌 + 3 macOS 패치 후에도
  74%·71% 지점 반복 실패). ubu-2 (Linux x86_64, 12 코어, 387GB free,
  docker + passwordless sudo) 로 전환. `docker pull openroad/orfs:latest`
  성공 (이미지 자체에 OpenROAD + yosys + SKY130 PDK 번들 — 빌드 0, 패치 0).
- 2026-05-18 — **comb ORFS 디자인 디렉토리 git 정착**: `comb/rtl/orfs/
  sky130hd/router_d{4,6}/{router_*.v, constraint.sdc, config.mk}` —
  sv2v-flat Verilog 2005 RTL + SDC + ORFS config. ubu-2 git fetch 가
  pack-delta 깨져서 `git clone --depth=1 --branch rfc043-hexa-torch` 로
  /tmp/hexa_comb 우회. 28 commits 푸시 (commit `e420c7db` 까지 + flat
  v2k 추가 commit + ORFS 디자인 dir commit).
- 2026-05-18 — **ORFS 1차 run: read_sdc 실패** (commit context).
  yosys synth PASS (router_d6 → SKY130 cells), OpenROAD link_design OK,
  `Error: invalid command name "remove_from_collection"` — OpenSTA 가
  Synopsys 전용 명령 미지원.
- 2026-05-18 — **ORFS 2차 run: CTS hold-buffer 폭발 (b9whqcpkk)**. SDC
  를 OpenROAD 호환으로 1차 정정했으나 *근본 단위 버그* 발견:
  `create_clock -period 1000.0` 가 의도(1 GHz=1000ps)와 달리 liberty
  time_unit=1ns 라서 **1 MHz** 로 해석 + `set_clock_uncertainty 50.0`
  = **50 ns** uncertainty → 모든 짧은 reg-to-reg 경로가 -48 ns hold
  위반 → 2913 hold buffer 삽입 후 `RSZ-0060 max buffer count reached`
  CTS 실패. 진척: synth→floorplan→place 완주, CTS 에서 정지.
- 2026-05-18 — **SDC 단위 버그 fix (commit pending)**: 4 SDC 파일
  (router_d{4,6}.sdc + orfs/sky130hd/router_d{4,6}/constraint.sdc) 전부
  ns-정확본으로 교체. period 5.0 ns (200 MHz, SKY130 130nm 현실 타겟),
  uncertainty 0.25 ns (250 ps), io_delay 1.0 ns. `remove_from_collection`
  · `set_driving_cell` · `set_load` 제거 — OpenSTA-호환 최소형.
- 2026-05-18 — **ubu-2 인프라 다운 (당시)**: 2차 ORFS run 도중 ubu-2 ssh
  banner-exchange timeout. b9whqcpkk task 출력 0byte · 완료 통지 없음.
  원격 reachability comb-fix 불가 — 박스 점검 대기. SDC fix push 후 fresh
  clone 재실행 1-step 경로 확보.
- 2026-05-18 — **ubu-2 복구 → ORFS 3차 run (bkml0mjdh, detached)**:
  b9whqcpkk 완료 통지 후 확인하니 ubu-2 sshd 복귀. 이전 comb_pnr_out 의
  4_1_cts.log 가 BAD-SDC(-48ns hold) 데이터 — 즉 b9whqcpkk 의 docker 는
  ssh 끊기기 전 짧은 시점에 시작했어도 *완주 못 함*. 3차 run 은 **ssh-drop
  resilient 패턴**으로 launch:
    nohup bash -c "docker run ... > comb_pnr_out2/orfs_d6.log 2>&1" &
  → docker 가 ubu-2 PID 1 detach 라 ssh 가 죽어도 P&R 진행. fresh
  `git clone --depth=1 --branch rfc043-hexa-torch /tmp/hexa_comb_v2` 로
  fix-SDC 픽업 검증 통과. 직후 ubu-2 ssh 다시 starved (정상 부하 패턴 —
  이번엔 docker 가 진짜 도는 신호). 결과 대기.
- 2026-05-18 — **T3_design.md 템플릿 작성** (`comb/rtl/T3_design.md`):
  ORFS bkml0mjdh 완료 시 placeholder 자리에 GDS area / STA WNS·TNS·fmax
  / 와이어길이 / DRC 결과 즉시 채울 수 있게 사전 골격. 정직 스코프 명시:
  단일 디자인포인트 (200 MHz · sky130hd · tt corner · slow/fast 미실행),
  F1/F2 falsifier status 는 hexa-arch[chip] measurement_gate closure 전
  OPEN 유지 (comb-internal P&R 은 corroboration, authoritative 아님).
- 2026-05-18 — **🔥 F1-full FALSIFIED at fabric cycle-accurate N=7**:
  세 turn 누적 fabric-level sustained sim. 산출 trio:
    `comb/rtl/fabric_2x2_sustained_tb.v`     (commit 3220ffc5, 4-node d4)
    `comb/rtl/fabric_hex7_sustained_tb.v`    (commit 683262a8, 7-node d6)
    `comb/rtl/fabric_mesh7_sustained_tb.v`   (commit 91061574, 7-node d4 ★)
  마지막 commit 이 same-N fair comparison — d6 hex 가 d4 mesh 에게 *모든
  workload 에서* 패배: uniform d4 1.5× / stencil 4.5× / diameter 2.5× /
  hotspot tie. **이론(hop 1.43 < 1.67) 과 측정 정반대** — Hales 2001
  caveat "least-perimeter ≠ least-latency" 실측 확인. Hex center R0 의
  6-port concentration 이 single-issue LL sink 와 결합해 sustained 부하
  하에서 hex 전체를 throttle. RFC 057 §5 F1 disposition 갱신:
    F1 (closed-form non-contention)  ✅ PASS  (workload_f1.hexa 8/8)
    F1-full (cycle-accurate fabric)  ❌ FAIL  at N=7 small-scale
  반증 = honest refutation, goal "입증하거나 *동일 엄밀도로 반증*" 의
  반증 path 만족. comb T2 sim 측면 strict closure 도달.
  *남은 strict gaps* (외부 wait):
    T2 tapeout-ready (STA·P&R·DRC) — ORFS bkml0mjdh on ubu-2
    T3 (GDSII)                     — 同上
    authoritative F1 (larger N + per-link load) — hexa-arch §9 sweep
  → comb-internal F1-full = FALSIFIED at this test point; 더 큰 N
    또는 production-grade sim 이 verdict 를 flip 할 가능성 명시
    (`d4_vs_d6_fabric_compare.md` §Same-N=7 fair comparison).
- 2026-05-18 — **comb 완료 closure 작성** (`comb/CLOSURE.md`). 5
  falsifier 종합 verdict 표 + track-level closure status + handoff
  summary (hexa-arch[chip] 가 comb 으로부터 inherit 하는 inputs ·
  comb 가 receive 받기로 기대하는 outputs) + "comb 완료" 정의 명시.
  Verdict 요약:
    F1   MIXED — closed-form 8/8 PASS · cycle-accurate FAIL @ N=7
                 (honest refutation, goal '입증or동일엄밀도 반증' 의
                  반증 path 만족; authoritative = hexa-arch §9)
    F2   PARTIAL — synth area 1.516× confirmed · routed deferred
    F3   OUT OF COMB SCOPE — Axis-C lowering separate RFC
    F4   ✅ PASS by axis-A DE-SCOPED WALL (3 × HARD_WALL)
    F5   ✅ PASS by audit — every perf claim B1/B2/B3 anchored
  Track closure: T1 ✅ · T2 sim ✅ via refutation · T2 synth ✅ ·
  T2 tapeout ⏸ handoff · T3 ⏸ delegated.
  comb 단독 산출물 모두 land · 외부의존 항목은 typed-interface 핸드오프
  (RFC 002 schema_version 1.0 pin) 와 re-entry condition 으로 기록.
  본 entry = comb stand-alone scope closure marker. 후속 comb-side
  작업은 scope-extension (신규 falsifier · 신규 test point · 신규
  axis lowering) — 본 RFC 057 scope closure 는 아님.
- 2026-05-18 — **T3 design-only deliverable DELIVERED**
  (`comb/T3_DESIGN_FINAL.md`). T3 를 두 part 로 분해:
    Part D (NoC architectural design) ✅ COMPLETE — hexa-arch[chip]
      가 produce (rfc_001 §8 BookSim2 baseline + §9 46-record sweep:
      22nm/7nm × 1-6GHz × 4 placements; Leighton oracle 6/6 PASS),
      comb 가 rfc_002 typed-interface 로 consume.
    Part E (routed-GDS execution) ⏸ EDA-execution compute-gate —
      OpenROAD binary roster 부재 (ubu-2 banner timeout 지속 확인 ·
      mini no-docker · macOS 금지). design gap 아님 — RTL/synth/PDK/
      ORFS-config 전부 staged + predicted P&R falsifier 사전등록.
  **핵심 발견 — comb⇄hexa-arch[chip] F1 reconciliation**: hexa-arch
  §9 가 정확히 comb 의 N=7 반증이 deferred 한 "larger-N + multi-issue"
  re-test. comb N=7 (single-issue LL sink) → d4 wins (hex center
  concentration); hexa-arch N=64 (IQ-iSLIP VC8) → d6 LEAN-PASS lat
  0.81-0.89× thr 1.19-1.81× clock-robust 1-6GHz. **상보적, 모순 아님**
  — comb 의 사전등록 reversal caveat (larger N/multi-issue 시 flip
  가능) 가 실증됨. verdict enum 양쪽 INCONCLUSIVE 유지 (rfc_002 §8
  GATE_OPEN, absorbed=false) — regime/paradigm claim 금지 (g3).
  synth-area oracle 1.5156× = hexa-arch §9 cost model
  router_port_area_norm 1.516 과 정확 일치 (loop closed).
  T3 = design-only (RFC 057 §6) 정의 충족: 물리실현 *설계* 가
  hexa-arch[chip] 통해 produce·quantify 됨. routed-GDS 는 fab 비목표와
  동일 성격의 execution gate. CLOSURE.md T3 row · COMB.tape
  comb_t3_f1_reconcile · README 갱신 동반.
