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

@N comb_evidence := "딥리서치 교차검증 결론" :: note [d=2026-05-18 active]
  finding = "n=6 정리-최적은 B축(육각 위상) 1개뿐. A축 radix 는 b=3 에 열위 (반증). C축 radix-중립."
  negative = "상용 degree-6 실리콘 0건 (Cerebras·SambaNova·Tenstorrent·Groq·Loihi·NorthPole·SpiNNaker 전부 degree-3/4). UC Davis VCL 65nm 2012 단 1측정, 13yr stale, 미productize."
  rule = "타일 로직 = 이진-디지털 고정. 다치논리 = 금지·WALL. 모든 B 주장 = least-perimeter≠least-latency + EDA-cost caveat 동반."
  |> "research/SURVEY.md (출처: Hales DCG 25 2001 · Hayes Am.Sci 2001 · Maghami CSSP 38 2019 · Gholami IEEE Micro 2024 · Stillmaker/Baas VLSI-SoC 2012)"

# §X — campaign artifact index (branch·SHA·path·RFC#)
@N x_comb_artifacts := "comb/ 산출물 인덱스" :: note [d=2026-05-18 active]
  branch = "rfc043-hexa-torch (uncommitted — 공유 worktree, 커밋 user gate)"
  readme = "comb/README.md — 1-pager · 3축 정직표"
  survey = "comb/research/SURVEY.md — 딥리서치 2건 통합 + primary sources"
  axis_b = "comb/axis_b_topology.md — backbone (DESIGN)"
  axis_a = "comb/axis_a_radix.md — DE-SCOPED WALL (AUDITED)"
  axis_c = "comb/axis_c_model.md — motivation (DESIGN)"
  rfc = "comb/RFC.md — 합본 DRAFT, RFC 057 (확정, 충돌0 above rfc_056), 5 falsifier (F1–F5)"
  plan = "comb/PLAN.md — 진행 로그 SSOT"
  next_gate = "F1/F2 해소용 hex NoC 시뮬 (modern node) — user gate 대기"
