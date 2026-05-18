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
  t2_real_workload_verdict = "comb/sim/workload_f1.hexa — ⭐️ real workload F1. uniform/broadcast/hotspot 에서 degree-6 net win (N=1024,10000); stencil LOSE (1-hop). honest workload-dependent verdict."
  t2_yosys_synth = "comb/rtl/synth_comparison.md — yosys generic synth. cell ratio 1.80×."
  t2_pdk_synth = "comb/rtl/pdk_synthesis.md — 🎉 cross-PDK + SKY130 ASIC mapping. FPGA Xilinx 1.37× + Lattice ECP5 1.41× + **SKY130 ASIC sky130_fd_sc_hd 1.516×** (d4=61762.99 μm², d6=93608.53 μm²). F1 verdict robust under measured ASIC area: hex 33% lat win, 29% energy win at t_r6=152. cross-over t_r6=276 → 1.8× margin. SKY130 .lib 12.8MB cloned from efabless mirror."
  decouple_refine = "comb 가 안 하는 것 = 외부 EDA *흡수* (BookSim2/Yosys/OpenROAD/SKY130 — hexa-arch). comb 가 하는 것 = 자체 graph/non-contention 모델 측정."
  next_gate = "(a) RTL 스텁 (hexa→Verilog emitter, comb-side, T2 RTL 측면) (b) T1-B-full = hexa-arch[chip] BookSim2 흡수 (congestion·real-workload 측정)"
  t2_openroad_install = "🎉 OpenROAD cmake CONFIGURED 2026-05-18. deps: brew(13) + source(LEMON-coin 1.3.1, CUDD 3.0.0). macOS 빌드 74%/71% 반복 dead-end (Boost+LEMON C++20+zstd) → ABANDONED in favor of ubu-2 Docker."
  t3_orfs_path = "ubu-2 (Linux x86_64) Docker ORFS 로 전환. `docker pull openroad/orfs:latest` 성공 (이미지에 OpenROAD+yosys+SKY130 PDK 번들 — 빌드 0/패치 0). comb/rtl/orfs/sky130hd/router_d{4,6}/{router_*.v, constraint.sdc, config.mk} = self-contained 디자인 dir, git 정착."
  t3_orfs_attempt = "1차 run: read_sdc 실패 (`remove_from_collection` OpenSTA 미지원). 2차 run: SDC ns-단위 버그 발견 — `-period 1000.0` 가 1MHz, `set_clock_uncertainty 50.0` 가 50ns 로 해석 → -48ns hold 위반 → CTS RSZ-0060 max buffer reached. synth→floorplan→place 완주, CTS 정지."
  t3_sdc_fix = "SDC 4파일 ns-정확본 교체 (router_d{4,6}.sdc + orfs/sky130hd/router_d{4,6}/constraint.sdc). period 5.0ns(200MHz)·uncertainty 0.25ns·io_delay 1.0ns. remove_from_collection/set_driving_cell/set_load 제거 — OpenSTA 최소형."
  t3_blocked = "[과거] ubu-2 ssh timeout — 2차 run 도중. b9whqcpkk 미완. SDC fix push 후 복구 대기."
  t3_orfs_3rd = "bkml0mjdh — ubu-2 복귀 후 ssh-drop resilient detached run. `nohup bash -c \"docker run ... > comb_pnr_out2/orfs_d6.log\" &` 로 ssh 끊겨도 P&R 진행. fresh /tmp/hexa_comb_v2 clone 으로 fix-SDC 픽업 확인. 현재 ubu-2 sshd 다시 starved = 정상 부하 (이번엔 진짜 P&R 진행 신호)."
  t3_template_ready = "comb/rtl/T3_design.md — ORFS 결과 수신 템플릿."
  t2_sim_closure = "🔥 T2 sim closure via REFUTATION (RFC 057 §5 F1-full). same-N=7 fabric cycle-accurate (commit 91061574): d4 mesh 가 모든 workload 에서 d6 hex 이김 (lat 1.5×~4.5× faster). 이론 hop 1.43 vs 1.67 vs 측정 정반대 — Hales caveat 실측. F1 closed-form (non-contention) PASS · F1-full (contention+real workload) FAIL @ N=7. goal '입증/반증' 의 반증 path 만족. authoritative F1 = hexa-arch larger-N records."

# ─── external citations (typed-interface contracts comb consumes) ────

@X x_hexa_arch_f1f2_schema := "hexa-arch:chip:noc:F1F2 typed-interface contract" :: spec [d=2026-05-18 active]
  producer_rfc = "~/core/hexa-arch/proposals/rfc_002_f1f2_export_interface.md"
  schema_doc = "~/core/hexa-arch/exports/chip/noc/f1f2/schema/v1_0.md"
  interface_names = ["hexa-arch:chip:noc:F1F2-record", "hexa-arch:chip:noc:F1F2-pair-verdict"]
  carrier = "HXC v2 byte-canonical wire (g_hxc); JSON of same keyset = interim parse path (rfc_002 §9)"
  read_path = "~/core/hexa-arch/exports/chip/noc/f1f2/{records,pair_verdicts}/<id>.{hxc,json}"
  semver_pin = "schema_version 1.0 (rfc_002 §6 — comb pins MAJOR; producer maintains last two MAJORs)"
  consumer_target_value = "hexa-lang:comb:RFC_057:F1F2"
  decisions_cited = ["hexa-arch design.md D1 public-surface clean-room", "D2 typed-interface", "D7 producer-owned export path"]
  scope = "T1-B-full (modern-node wire model + router cost + traffic-driven latency/throughput). comb 는 소비자 (RFC 057 §6 T1; comb_ultimate.decouple)."
  consumed_by = ["comb/T1_experiment.md §hexa-arch[chip] 인터페이스", "comb/T1A_analytical.md §8 T1-B input contract", "comb/sim/README.md §T1-B-full input expectation"]

# ─── stand-alone closure marker ──────────────────────────────────────

@D comb_closure := "comb stand-alone scope CLOSURE — 2026-05-18" :: closure [d=2026-05-18 ok]
  scope = "T1 + T2 sim + T2 RTL synth + 5 falsifier verdicts. External-dependency tracks (T2 tapeout routed P&R, T3 GDSII) HANDED OFF to ~/core/hexa-arch[chip] via typed-interface (rfc_002 schema_version 1.0)."
  verdict_f1 = "MIXED — closed-form (non-contention) PASS 8/8 (workload_f1.hexa) · cycle-accurate fabric N=7 FAIL (d4 mesh wins all 4 workloads 1.5×–4.5× latency). Honest refutation path of goal '입증or동일엄밀도 반증'. Pre-registered Hales caveat (least-perimeter ≠ least-latency) realized empirically. Authoritative re-test = hexa-arch §9 larger-N sweep + multi-issue sink."
  verdict_f2 = "PARTIAL — synth area SKY130 sky130_fd_sc_hd 1.516× confirmed (d6 93608.53 μm² / d4 61762.99 μm²); routed P&R DEFERRED to hexa-arch[chip] (ORFS bkml0mjdh ubu-2 incomplete; comb-side corroboration only)."
  verdict_f3 = "OUT OF COMB SCOPE — fabric vs vN+HBM at workload level requires (1) PIM tile execution model (Axis-C lowering — separate RFC) (2) HBM3 chiplet baseline. RFC 057 §6 already notes 'C-axis dataflow lowering = separate RFC if pursued'."
  verdict_f4 = "PASS — A-axis frozen as counter-evidence per RFC 057 §3 + axis_a_radix.md. 3 × HARD_WALL (radix economy Hayes 2001 · noise margin Maghami 2019 · EDA-cost empirics) kill multi-valued physical logic as differentiator."
  verdict_f5 = "PASS by audit — every perf claim traces to B1 (Hales DCG 25 2001) / B2 (2D kissing#6 Conway-Sloane 1999) / B3 (Leighton 1992). RFC 057 §4: '6' = inherited convenience constant, NOT independently justified."
  track_t1 = "CLOSED — T1A analytical + axis_{a,b,c} + RFC 057 + SURVEY"
  track_t2_sim = "CLOSED via refutation — fabric_{mesh,hex}7_sustained_tb + d4_vs_d6_fabric_compare.md"
  track_t2_synth = "CLOSED — synth_comparison + pdk_synthesis (FPGA + ASIC SKY130) + synth_netlists/router_{d4,d6}.sky130.v"
  track_t2_tapeout = "DEFERRED — handoff to hexa-arch[chip]; rtl/orfs/sky130hd/router_d{4,6}/ inputs pre-staged (ns-correct SDC 5.0ns/200MHz)"
  track_t3 = "DESIGN-COMPLETE (design-only) — Part D NoC architectural design produced by hexa-arch[chip] (rfc_001 §8 baseline + §9 46-record sweep 22nm/7nm × 1-6GHz × 4 placements; Leighton 6/6 PASS), consumed via rfc_002 typed interface. Part E routed-GDS = EDA-execution compute-gate (OpenROAD binary absent on roster — not a design gap). SSOT comb/T3_DESIGN_FINAL.md."

@D comb_t3_f1_reconcile := "comb⇄hexa-arch[chip] F1 reconciliation" :: note [d=2026-05-18 active]
  comb_n7 = "N=7 R=1 hex region, single-issue 1-cycle LL sink, ~50% sustained inj, uniform/hotspot/stencil/diameter → d4 mesh wins all (hex 6-port center concentration bottleneck). FALSIFIED at this test point (comb/CLOSURE.md b5e9ee9b)."
  hexa_arch_n64 = "N=64 8×8 grid, IQ-iSLIP VC8 buf8 pkt20 (production router), tornado, per-link 90/162 ps/mm (22/7nm). d6 LEAN-PASS: zero-load lat 0.81–0.89× · avg hops 0.78–0.84× · saturation thr 1.19–1.81×. clock-robust 1-6 GHz (never flips). §9(i) placement CLOSED (king/brick > axial), §9(ii) clock CLOSED, §9(iii) FinFET partly open."
  reconcile = "NOT contradictory — orthogonal effects. comb single-issue sink exposes hex center concentration (small-N + weak-router penalty); hexa-arch IQ-iSLIP VC relieves center → hex lower hop count + higher bisection (Leighton B3) dominates. comb's pre-registered reversal caveat (larger N / multi-issue may flip) empirically vindicated."
  honesty = "verdict enum INCONCLUSIVE both sides (rfc_002 §8 measurement_gate=GATE_OPEN, absorbed=false). LEAN-PASS-d6 = informal aggregate at measured points, placement-conditional. NOT a regime/paradigm claim (g3). n=6 = topology commitment only (F5 PASS)."
  |> "comb/T3_DESIGN_FINAL.md §2 + ~/core/hexa-arch/exports/chip/noc/f1f2/pair_verdicts/"
  ~> "comb_closure.verdict_f1 'authoritative re-test = hexa-arch §9' — re-test now produced, result recorded INCONCLUSIVE/lean-d6"
  ssot = "comb/CLOSURE.md (closure statement) · comb/PLAN.md (chronological) · this entry (tape index)"
  rule = "Subsequent comb-side work = scope-extension (new falsifier · new test point · new axis lowering), NOT closure of original RFC 057 scope."
  ~> "comb_ultimate (궁극 최종골) — equal-rigor refutation path satisfied"
