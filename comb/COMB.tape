#!/usr/bin/env tape
# COMB.tape — n=6 compute architecture campaign index (flame/forge FLAME.tape 동형)
# tape v1.2 grammar: see repo-root AGENTS.tape header primer.

@V := "tape" :: spec [active]
  version = "1.2"

@I comb_id := "comb" :: identity-claim [d=2026-05-18 draft]
  kind = "n=6 non-von-Neumann · non-quantum compute architecture R&D track"
  brief = "육각 PIM 패브릭 후보 — 고전 다치 상태 + 6이웃 인메모리 흐름, 버스 없음"
  alias = "HEXA-FABRIC / 벌집 컴퓨터"
  parent = "hexa-lang"
  placement = "루트 직속 comb/ — stdlib/flame · self/forge 와 형제 (stdlib 도 GPU 런타임도 아님)"
  ssot = "comb/{README.md, PLAN.md, COMB.tape}"

@N comb_axes := "3축 분해 + 정직 앵커" :: note [d=2026-05-18 active]
  a_radix = "6-값 senary digit. ⚠️ radix economy 비최적 (b=e, 정수 b=3 우위). 6=2·3 sub-word SIMD 만 이점."
  b_topology = "6-이웃 육각 메시. ✅ 정리-최적: 2D kissing number=6 (Thue), 벌집 추측 (Hales 2001 등면적 최소둘레)."
  c_model = "폰노이만 탈피 (PIM/dataflow). 🟡 von Neumann bottleneck 실재. 6 = 편의 상수."
  honest = "n=6 정리-최적은 B축 1개뿐. 권장 골격 = B 뼈대 + A/C 옵션. g1·g2 격자는 도구."

@D comb_gate := "축 선택 user gate" :: decision [d=2026-05-18 active]
  status = "RESOLVED — 전부 진행 (4축 전개 + arxiv/web 딥리서치)"
  outcome = "B = backbone (Hales 2001 정리) · C = motivation (memory wall, radix-중립) · A = DE-SCOPED WALL"
  ~> "EXPLORATION 미선택 상태 supersede"

@D comb_ultimate := "궁극 최종골 (T2 + T3 design-only)" :: decision [d=2026-05-18 active]
  tier_t1 = "ANSWERED — F1–F5 를 modern-node hex axial NoC 사이클 시뮬로 전수 판정 (이김/죽음)"
  tier_t2 = "PROVEN — hexa-native 사이클정확 시뮬 + tapeout-ready RTL 로 degree-6 hex 이진-타일 spatial PIM > degree-4 mesh 실워크로드 입증 OR 동일 엄밀도 반증"
  tier_t3 = "DESIGN-ONLY (설계만) — comb 물리-실현 설계를 별도 standalone repo `~/core/hexa-arch` 의 chip 도메인을 *사용*해 산출. 외부 EDA 흡수(gem5-Garnet·Yosys·OpenROAD·Verilator·ngspice·SKY130·Chisel)는 hexa-arch 책임. comb = 소비자, 흡수 주체 아님. 실제 fab/FPGA = 비(非)목표."
  decouple = "hexa-arch ≠ comb. EDA 외부흡수 = ~/core/hexa-arch (standalone repo, commit c812ac6, HANDOFF.md 자기완결). comb = chip 도메인 소비자. T1 NoC sim 도 hexa-arch[chip] 경유 (comb 직접 흡수 X)."
  guard = "T3 종착 = hexa-native 설계 산출물. 칩 fab over-reach 금지 (g5 hexa-native-only) · over-claim 금지 (g1·g2)."
  ssot = "root GOAL.md ③ (north-star SSOT) · comb/RFC.md §6 (gated plan T1→T2→T3)"
  ~> "founding 골(RFC 057+falsifier 정초) → '현 단계'로 강등; 본 궁극골이 north-star"

@N comb_evidence := "딥리서치 교차검증 결론" :: note [d=2026-05-18 active]
  finding = "n=6 정리-최적은 B축(육각 위상) 1개뿐. A축 radix 는 b=3 에 열위 (반증). C축 radix-중립."
  negative = "상용 degree-6 실리콘 0건 (Cerebras·SambaNova·Tenstorrent·Groq·Loihi·NorthPole·SpiNNaker 전부 degree-3/4). UC Davis VCL 65nm 2012 단 1측정, 13yr stale, 미productize."
  rule = "타일 로직 = 이진-디지털 고정. 다치논리 = 금지·WALL. 모든 B 주장 = least-perimeter≠least-latency + EDA-cost caveat 동반."
  |> "research/SURVEY.md (출처: Hales DCG 25 2001 · Hayes Am.Sci 2001 · Maghami CSSP 38 2019 · Gholami IEEE Micro 2024 · Stillmaker/Baas VLSI-SoC 2012)"

# §X — campaign artifact index (branch·SHA·path·RFC#)
@N x_comb_artifacts := "comb/ 산출물 인덱스" :: note [d=2026-05-18 active]
  branch = "rfc043-hexa-torch (공유 worktree; comb/ 경로만 커밋 — 1차 c0e7aae7 + 궁극골 갱신 후속커밋)"
  readme = "comb/README.md — 1-pager · 3축 정직표"
  survey = "comb/research/SURVEY.md — 딥리서치 2건 통합 + primary sources"
  axis_b = "comb/axis_b_topology.md — backbone (DESIGN)"
  axis_a = "comb/axis_a_radix.md — DE-SCOPED WALL (AUDITED)"
  axis_c = "comb/axis_c_model.md — motivation (DESIGN)"
  rfc = "comb/RFC.md — 합본 DRAFT, RFC 057 (확정, 충돌0 above rfc_056), 5 falsifier (F1–F5)"
  plan = "comb/PLAN.md — 진행 로그 SSOT"
  t1_spec = "comb/T1_experiment.md — F1/F2 pre-registered 측정 명세 (consumer-side)"
  t1a_done = "comb/T1A_analytical.md — T1-A 완료 (sim 불요). 표준 NoC 문헌 인용·정리, 산술 elementary, caveat 5건. 핵심: diameter hex/mesh = 1/√3, avg dist 1/√3, hop 절감 ≈ 0.845√N, degree·links 1.5×, hop 부등식 §3."
  t1b_oracle_done = "comb/sim/noc_distance.hexa — T1-B-oracle. hexa parse PASS · build OK · 컴파일 바이너리 실행. N=10000 D_hex/D_mesh=114/198=0.5758 ≈ 1/√3."
  t2_partial_f1_done = "comb/sim/f1_parametric.hexa — T2-partial F1 (비경쟁 NoC, Dally & Towles §3.7). 8/8 sweep degree-6 net win. cross-over t_router_d6 ≈ 276. ⭐️ commit 1c18ed40."
  t2_rtl_first_byte = "comb/rtl/emit_routers.hexa → routers.v (36줄 스텁, hexa-native emitter)."
  t2_rtl_synthesizable = "comb/rtl/router_d{4,6}.v — ⭐️ 263줄 합성가능 RTL. d4 (5-port XY) + d6 (7-port hex axial dim-order). FIFO+RR arbiter+crossbar 풀 데이터패스. iverilog -g2012 PASS. NOT tapeout-ready (Yosys/OpenROAD/DRC/PDK = hexa-arch[chip])."
  t2_cycle_accurate_func = "comb/rtl/router_d6_tb.v — ⭐️ iverilog cycle-accurate functional verify. 4 destination cases (dq=+3→PQ, dq=-2→NQ, dr=+4→PR, local→LL) **4/4 PASS**. 실제 패킷 트래픽이 합성가능 RTL 에서 cycle-accurate 라우팅."
  t2_real_workload_verdict = "comb/sim/workload_f1.hexa — ⭐️ real workload F1. uniform/broadcast/hotspot 에서 degree-6 net win (N=1024,10000); **stencil 에서 degree-6 LOSE** (1-hop = router-port 비용만). honest workload-dependent verdict."
  decouple_refine = "comb 가 안 하는 것 = 외부 EDA *흡수* (BookSim2/Yosys/OpenROAD/SKY130 — hexa-arch). comb 가 하는 것 = 자체 graph/non-contention 모델 측정."
  next_gate = "(a) RTL 스텁 (hexa→Verilog emitter, comb-side, T2 RTL 측면) (b) T1-B-full = hexa-arch[chip] BookSim2 흡수 (congestion·real-workload 측정)"
