# A4 — PHANES axis: 자율발견/OUROBOROS 논문 흡수 → phanes 아키텍처 cross-link

> ARXIV 도메인 A4 마일스톤. PHANES axis (cs.AI · cs.LG · cs.MA · cs.NE) 본격 흡수.
> A1(ingest POC 12편) + A2(ANIMA 11편) + A3(DEMIURGE 12편)에 이어 **A4 는 자율발견
> SaaS phanes(OUROBOROS hosted-discovery 플랫폼)가 필요로 하는 자율-사이언티스트 /
> self-improving agent / verifier-driven RL / open-endedness / quality-diversity /
> LLM-진화탐색 논문** 10편을 흡수한다.
> **A4 는 A2(ANIMA)와 같은 모양** — verify-able 0 (정직·예상대로). PHANES 는 systems/SaaS
> 축이라 `hexa verify --expr` 에 폐형해 atom 이 없다 (A3 DEMIURGE 의 verify-native 물리상수
> 와 정반대). A4 의 산출 가치 = **citation + phanes 아키텍처 4표면 매핑(g60 handoff)**.

## 1 · 한 문단 요약

arXiv API 8 query → **10편 on-topic 흡수** → 3-class triage:
**verify-able 0** (정직·예상대로 — PHANES 는 OUROBOROS *엔진 소비자*이지 폐형해 수학/물리 도메인이
아님; A2 ANIMA 와 동형) ·
**🟡 citation 5** (atlas reference node) ·
**handoff→phanes 10** (10편 전부 phanes 컴포넌트 — 발견 루프 / verifier 게이트 / provenance /
tenant-objective 모델 — 에 명시 cross-link).
A4 의 핵심 = **흡수한 논문들이 phanes 가 이미 구현한 OUROBOROS 루프를 그대로 서술한다**는 것.

## 2 · 핵심 A4 발견 — PHANES 는 systems 축 (verify 0, A3 와 대조)

HEAD 에서 verify 표면 grep 으로 확인:

- `tool/verify_cli.hexa` — phanes/ouroboros/loop/saturation/novelty 수치 primitive **0개**
  (물리 + 수론 fn 만 존재).
- `compiler/drill/drill.hexa` + `round.hexa` — OUROBOROS 엔진 보유(`drill_run`·`_honesty_gate`·
  `_verifier_run`·`_flush_discoveries_cum`)하나 이는 **루프 오케스트레이션 fn** 이지
  `hexa verify --expr <fn> <args> <v>` 로 재산출되는 스칼라 atom 이 아님.

→ **A2(ANIMA: 0 verify-able, in-tree IIT primitive 부재)와 동일한 모양**. A4 의 산출물은 verify
수치가 아니라 **CITATION + phanes 아키텍처 맵** 이다.

### 핵심 아키텍처 대응 (왜 이 논문들인가)

phanes OUROBOROS 엔진은 이 논문들이 서술하는 루프를 **이미 구현**하고 있다:

| 논문이 서술하는 메커니즘 | phanes 엔진의 실제 구현 (소스) |
|---|---|
| open-endedness / novelty 소진까지 무한 탐색 | drill.hexa "saturation (round yield = 0) or max-rounds" — 6단계 라운드 체인 → 포화 |
| novelty search / QD 정지 기준 | round.hexa `net_novel == 0` = **C5 novelty-fixpoint signal** (그 자체) |
| verifier-driven RL / RLVR / VLM-as-judge | drill.hexa pluggable verifier + `_honesty_gate` (라운드별 verdict 감사) |
| provenance / discovery catalog | overlay 누적(`overlay_append_lines`, 후속 라운드가 atlas overlay 봄) |
| AI-Scientist tenant-objective (idea→exp→verify→refine) | phanes job 모델 `{seed, verifier_ref, rounds_cap}` |

## 3 · 흡수 논문 10편 (phanes surface map)

기호: (b) citation · (c) handoff · (*) verify-able-CANDIDATE (가장 느슨한 의미 — 폐형해 atom 아님)

| arxiv id | 제목 (저자) | 기여 | class | phanes 표면 |
|---|---|---|---|---|
| 2406.04268 | Open-Endedness is Essential for ASI (Hughes+ / DeepMind 2024) | open-ended·자기개선 AI = ASI 경로; novelty+learnability 가 OE 두 재료 | (b)+(c) | OUROBOROS 루프 존재이유 (saturation = bounded-OE 라운드 캡) |
| 2306.01711 | OMNI: Open-endedness via Models of Interestingness (Zhang/Lehman/Stanley 2023) | LLM 을 "흥미도" 모델로 → 다음에 추구할 learnable task 선택(무한 task 공간 필터) | (b)+(c) | seed/task 제안자 + 라운드별 next-seed 선택 (round.hexa) |
| 2405.15568 | OMNI-EPIC: ...Environments Programmed in Code (Faldor/Zhang/Cully 2024) | OMNI 확장 — LLM 이 task **와** 코드 success-함수(env+verifier)를 같이 작성 | (c)* | verifier-as-code: tenant 가 obj+verifier 코드를 가져옴 |
| 2003.03384 | AutoML-Zero: Evolving ML Algorithms From Scratch (Real/Liang/So 2020) | 진화탐색이 primitive op 에서 ML 알고리즘 전체 발견; fitness 만 신호 | (b)+(c) | 엔진 조상: search + 자동 eval 루프 |
| 2504.05108 | Algorithm Discovery With LLMs: Evolutionary Search Meets RL (Surina/Mansouri+ 2025) | LLM-진화탐색 + RL 이 알고리즘 발견 향상; eval 신호가 루프 구동 | (c)* | OUROBOROS = LLM-제안 + verify + refine 루프 |
| 2511.02864 | Mathematical exploration and discovery at scale (Georgiev/Gómez-Serrano/**Tao** 2025) | AlphaEvolve: 범용 진화 코딩 에이전트, LLM 생성 + **자동 eval**, propose/test/refine 반복 | (c)* | **직접 analog**: phanes = tenant obj+verifier 용 hosted "AlphaEvolve" |
| 2502.14297 | Evaluating Sakana's AI Scientist (Beel/Kan/Baumgart 2025) | end-to-end AI-Scientist 독립 평가; 혼합 결과·over-claim 위험 (ARI) | (b)+(c) | honest-scope 선례 (g3: verifier=권위, over-claim 카피 금지) |
| 2508.15126 | aiXiv: Open-Access Ecosystem for AI-Scientist Discovery (Zhang+ 2025) | AI-생성 제안 + 자동 peer-review + 반복 refine 인프라 | (c)* | provenance/catalog + exportable verified 카탈로그 |
| 2504.21024 | WebEvolver: Web Agent Self-Improvement w/ Coevolving World Model (Fang/Zhang+ 2025) | 에이전트가 자기-샘플 trajectory + coevolving world model 로 자기개선 | (c) | 루프의 self-improving 소비자 (라운드 재사용) |
| 2602.11549 | Native Reasoning Models: Reason on Unverifiable Data (Wang/Liu/Li 2026) | RLVR 의 외부-verifier 의존이 병목; verifier 없이 추론 학습(unverifiable frontier) | (b)+(c) | verifier-gap 에스컬레이션: oracle 없을 때(tenant-verifier 한계, P2.6) |

`(*)` = 가장 느슨한 의미의 verify-able-CANDIDATE — phanes 가 구현한 루프/eval 메커니즘을 서술하나
**어느 것도 `hexa verify --expr` 스칼라로 환원 안 됨**. phanes 폐형해 atom 부재(A3 물리상수와 대조).
A4 정직 verify count = **0**. `(*)` 는 **미래 in-engine instrumentation 지표**(예: net-novelty-rate /
saturation-round 폐형해) 후보 표시일 뿐, 현재 🟢 아님.

## 4 · phanes 아키텍처 4표면 cross-link 매핑 (10 handoff)

phanes `~/core/phanes` (GOAL.md / ROADMAP.md / project.tape) 의 4 핵심 표면에 논문 매핑:

| phanes 표면 | 흡수 논문 → 기여 | 상태 |
|---|---|---|
| **OUROBOROS 발견 루프** (goal→falsifier→saturation, drill_run) | 2406.04268 OE-essential(bounded-OE=라운드 캡) · 2003.03384 AutoML-Zero(search+eval 조상) · 2511.02864 AlphaEvolve(**직접 hosted-analog**) · 2504.05108 LLM-진화+RL 루프 | citation + handoff (엔진 = upstream hexa-lang drill) |
| **pluggable verifier 게이트** (_honesty_gate · _verifier_run, P2.4/P2.6) | 2405.15568 OMNI-EPIC verifier-as-code · 2602.11549 unverifiable-data frontier(=tenant-verifier 한계) · (verifier-driven RLVR/PRM 계보 = 게이트 설계공간) | handoff (P2.6 pluggable-verifier upstream patch 추적) |
| **provenance / catalog** (overlay 누적 · DrillResult audit trail) | 2508.15126 aiXiv(AI-생성 + 자동-review + exportable 카탈로그) · 2511.02864 AlphaEvolve(refine 감사 trail) | handoff (P-B R2 datastore 카탈로그 연결) |
| **tenant-objective 모델** ({seed, verifier_ref, rounds_cap}) | 2306.01711 OMNI interestingness(=next-seed 선택) · 2502.14297 Sakana eval(=honest-scope/over-claim 가드, verifier=sole authority) · 2504.21024 WebEvolver(self-improve 소비자) | handoff (tenant API 추상화 설계) |

**가장 강한 대응**: AlphaEvolve(2511.02864, Tao+)는 phanes "hosted LLM-propose + automated-verify +
refine" 루프의 **직접 analog** — phanes 는 tenant 가 obj+verifier 를 꽂는 hosted AlphaEvolve.
OMNI/OMNI-EPIC(2306.01711/2405.15568)는 라운드별 next-seed / verifier-as-code 표면에 정보 제공.
"Open-Endedness Essential for ASI"(2406.04268)는 루프의 존재이유이자 saturation 을 bounded
open-endedness 로 framing. "Native Reasoning on Unverifiable Data"(2602.11549)는 verifier-gap
에스컬레이션 — oracle 없을 때 tenant-verifier-as-sole-authority frontier(phanes P2.6).

## 5 · 미래 verify-able-CANDIDATE seed (현재 🟢 아님)

A4 가 닫은 것 = **없음(0, 정직)**. PHANES 는 verify-native 가 아님. 미래 후보:

1. **net-novelty-rate / saturation-round 폐형해** — round.hexa 가 이미 `net_novel`(C5 novelty
   fixpoint) 을 계산. instrumented "포화까지 기대 라운드 수" 또는 "novelty 감쇠율" 폐형해가 미래
   엔진-instrumentation lane 에서 `hexa verify --expr` atom 이 **될 수도** 있음. 단 이는 엔진
   작업이지 arxiv-인용 수학이 아니라 정직하게 A4 verify 로 세지 않음.

## 6 · 거버넌스 · 정직성

- verify 정본 = `hexa verify` g5 — A4 는 triage + 아키텍처 매핑. verify 수치 0(honest). LLM 자기판정 금지.
- A4 verify-able = **정직하게 0** (A2 ANIMA 와 동형 — PHANES 는 systems/SaaS, A3 DEMIURGE 의
  verify-native 와 정반대). A4 가치 = citation + phanes cross-pollination(4표면 맵).
- naive dump 금지 — 10편 전부 phanes 컴포넌트 명시 cross-link 보유 → 흡수 인정.
- arXiv = open-access. attribution = arxiv id + 저자 + 제목.
- 도메인-특화 AI-Scientist 인스턴스(astro/medical) · QD 응용(robot/Lenia) · RLVR/critic/PRM 변형 ·
  open-ended TEXT 생성(다른 의미) 다수는 off-axis/subsumed 로 DROP (verdict 참조).
- **phanes handoff 주의 (publish gap)**: phanes working tree 가 feature 브랜치(`domain/init-phanes`,
  1 ahead / 4 behind origin/main) 위 — **clean 하지만 main 아님**. A2/A3 cross-repo handoff 패턴 +
  memory `feedback_closure` 에 따라 A4 는 **phanes/INBOX.log.md 를 생성**(기존 부재)하고 핸드오프를
  **working-copy edit (append, stub-first, dedup)** 으로만 기록, **non-main phanes 트리에서 commit
  하지 않음**. phanes 세션이 commit + domain/init-phanes 브랜치 reconcile 必 (parent 보고).

## 7 · 다음 (A5 readiness)

A4 = PHANES axis CLOSED (citation 5 🟡 + handoff 10 + **0 verify-able, 정직**).
다음 = **A5 HEXA-LANG axis** (compiler / number-theory 논문 → atlas/codegen 보강, **in-repo**).
A5 는 A3 처럼 verify-native 일 가능성 높음 — hexa-lang 이 number-theory atom(σ/τ/φ 등)을
`hexa verify --expr` 에 이미 보유 → arxiv 수론 논문의 폐형해 claim 이 DIRECT verify 닫힘 후보.
PHANES verify-able(net-novelty 폐형해)은 엔진-instrumentation lane 랜딩 후 재방문.
