# TECS-L 축 F F9 — NOVEL = verify-infra growth driver (g59 INBOX pipeline)

> SSOT 위치: `TECS-L/docs/f9-inbox-pipe-novel-verify-infra.md`
> Anchors: 축 A MF4 (PR #1083 · slug `tecs-l-modform-dim-genus`) · 축 E E2 (PR #1096 · slug `tecs-l-atlas-health`)
> 본 문서는 **신규 verify 0건** (M10/MR1/E3/F8 동일 패턴 = synthesis-by-anchor) —
> NOVEL 축이 단순 발견 lane이 아니라 verify infra 자체를 키우는 lane임을 두 입증
> 사례(MF4, E2)로 정리한다. terminal-empirical workflow.

---

## §1. 동기 — NOVEL은 verify-infra growth driver

TECS-L 축 F (NOVEL · "발견") 의 family 분류는 다음과 같다.

- (a) random verify · (b) seed verify · (c) 외부광맥(OEIS·arxiv mining)
- (d) 반증사냥 · (e) 범위확장 · (f) **도구확장** · (g) 파이프라인

겉보기에는 (a)..(e) 가 "발견 본진", (f) 가 보조처럼 보인다. 그러나 실제로
NOVEL 라운드를 굴려보면 새 칸을 두드릴 때마다 **hexa-lang 의 calc-fn 자체에
gap (없거나, 있어도 표준 정의를 실현 안 함) 이 노출**되는 게 다반사다. 이때
선택지는 두 가지다.

1. **gap 우회** — fn 을 안 쓰고 closed-form 손계산으로 verify 만 통과시킨다.
   라운드는 닫히지만 infra 는 정체된다.
2. **gap 업스트림** — `.tape`/`AGENTS.tape` 거버넌스 `g59` 가 명시한 INBOX
   파이프로 즉시 보고하고, 다음 hexa-lang 패치 사이클이 stdlib/compiler/verify
   를 보강하게 한다. 라운드도 닫히고 infra 도 자란다.

후자가 **F9 의 정의**다. NOVEL 축은 (i) honest tier 로 발견을 영속화하고
(ii) 그 옆얼굴에서 발견된 fn gap을 INBOX 업스트림으로 흘려보내, 다음 라운드
의 verify 가용 fn 집합을 키운다. 즉 NOVEL = discovery + verify-infra growth
의 이중 lane.

이번 세션에서 정확히 그 패턴이 두 축에서 동시에 나타났다 — 축 A MF4(modular
forms 도메인) 와 축 E E2(atlas health 도메인). 이하 §2/§3 가 각 사례,
§4 가 canonical pipeline, §5 가 도메인 입증.

---

## §2. 입증 사례 1 — 축 A MF4 (`dim_cusp_forms` 정의 갭, PR #1083)

### 2.1 발견
- milestone: "dim S₂(Γ₀(N)) = genus(X₀(N)) 정리를 hexa fn 으로 verify (🔵)"
  — 고전 modular forms 정리: weight-2 cusp form 공간의 차원은 modular curve
  X_0(N) 의 genus 와 같다. hexa 가 이미 `gamma0_genus(N)` (MF3 에서 22/22
  고전 표 일치 확인됨, 신뢰 가능) 과 `dim_cusp_forms(N, k)` 를 제공한다.
  → 단순 cross-equality `dim_cusp_forms(N,2) == gamma0_genus(N)` 가 N=1..30
  전수에서 성립해야 🔵.
- 결과(N=1..30 sweep, PR #1083):

| 영역 | match | mismatch | 비고 |
|------|-------|----------|------|
| N=1..10 | 10/10 | 0/10 | 전부 genus=0, **우연** 일치 |
| N=11..30 | 0/20 | **20/20** | ~67% mismatch (사실상 정리 fail) |

대표값 (`gamma0_genus(N)` 가 기준):

```
N=11: dim_cusp_forms=0, gamma0_genus=1, 고전 dim S_2=1   →  ✗
N=14: dim_cusp_forms=2, gamma0_genus=1, 고전 dim S_2=1   →  ✗
N=20: dim_cusp_forms=4, gamma0_genus=1, 고전 dim S_2=1   →  ✗
N=30: dim_cusp_forms=6, gamma0_genus=3, 고전 dim S_2=3   →  ✗
```

→ hexa 의 `dim_cusp_forms(N, 2)` 는 **표준 dim S_2(Γ_0(N)) 를 직접 제공하지
않는다**. 다른 정의/관례 또는 버그.

### 2.2 honest tier — 🔴 CLOSED-NEGATIVE
MF4 verdict = "hexa `dim_cusp_forms` 는 표준 dim S_2 fn 이 아니다"  🔴
(paper_negative_ok). 정리 자체는 고전적으로 참 (gamma0_genus 는 표준 표와
일치), hexa fn 만 정리를 실현 안 함. over-claim 0.

5 verdict + 5 @C 영속화 (slug `tecs-l-modform-dim-genus`, group TECS-L) ·
PR #1083 MERGED.

### 2.3 INBOX 업스트림 행동 (INBOX.log.md 2026-05-25T15:00Z 항목)
헤더: "hexa `dim_cusp_forms(N,2)` 가 표준 dim S₂(Γ₀(N))=genus 와 불일치"

기록 행동 항목:
- `dim_cusp_forms(N, k)` 의 실제 계산 정의 명세 확인 (소스: `compiler/atlas/atlas_cli.hexa` `_recompute2` 또는 `static_atlas` 내부)
- 표준 dim S_k(Γ_0(N)) 와 다르다면 fn 명/시그니처 분리 (가령 `dim_cusp_forms_standard` vs 현행)
- 또는 dim S_k 표준 정의로 수정 (genus + boundary 식)
- 참고 verdicts: `.verdicts/tecs-l-modform-dim-genus/dim_vs_genus_sweep.txt`
- cross-link: `TECS-L/docs/mf4-dim-genus-mismatch.md` · g59 upstream

### 2.4 grown infra 의 미래 사용
패치 머지 (hexa-lang stdlib/compiler) 후 NOVEL 다음 라운드 가용성:
- 직접: MODFORM 후속 milestone (dim S_k(Γ_0(N)) k≥2 전수 verify) 즉시 가능.
- 간접: dim S_k = trace formula 응용 (Eisenstein subspace, newform/oldform
  분해) 의 fn-level 정확성도 같은 패치로 안전해진다.

→ MF4 한 발견의 INBOX 한 줄이 MODFORM 도메인 전체 round 의 verify-fn 신뢰
바닥을 끌어올리는 효과.

---

## §3. 입증 사례 2 — 축 E E2 (atlas binary≠source divergence, PR #1096)

### 3.1 발견
- milestone (축 E E2): "atlas health audit — `hexa atlas stats --audit` 출력
  파싱·정합성 verify".
- 직전 라운드 (축 E E1, PR #1070) 가 6개 atom 을 `hexa atlas register
  --from-verify` 로 source `compiler/atlas/embedded.gen.hexa` 에 fold 했다
  (verified-{tau-33550336, tau-496, tau-8128, is_perfect-8589869056,
  gamma0_genus-6, gamma0_cusps-6}).
- E2 audit 결과 (PR #1096):

```
source SSOT (origin/main:compiler/atlas/embedded.gen.hexa):
    verified-{6 개} 6/6 PRESENT  →  E1 fold 가 source 에 완료됨

binary lookup (hexa atlas lookup --prefix=verified-):
    74 hits (타 에이전트 분), 내 E1 6 개 = 0/6 FINDABLE

audit (hexa atlas stats --audit):
    16101 entries, merged·clean (binary 내부 정합성 OK)
```

원인: 메모리 노트(`project_atlas_hxc_irreplaceable_ssot`) 는 "atlas SSOT =
`compiler/atlas/embedded.gen.hexa`, runtime 이 TEXT-parse 로 직접 읽음;
HEXA_ATLAS_EMBED overlay 가능" 으로 명시한다. 그러나 실제로는 installed
`hexa atlas lookup` 이 **binary-builtin (last `hexa cc --regen` 시점 freeze)
을 우선/단독** 읽어, source fold 만으로는 query 에 반영 안 됨.

### 3.2 honest tier — 🟡 SUPPORTED-BY-CITATION (verify-infra observability gap)
E2 verdict = "atlas binary lookup ≠ source SSOT — register fold 가 query 에
반영되려면 hexa 재빌드 필요"  🟡 (감시 수단으로서 audit 은 동작; 그러나
SSOT 명세-동작 갭 = infra defect).

PR #1096 MERGED · slug `tecs-l-atlas-health` 그룹 TECS-L.

### 3.3 INBOX 업스트림 행동 (INBOX.log.md 2026-05-25T18:00Z 항목)
헤더: "atlas binary-builtin lookup vs source embedded.gen.hexa divergence"

기록 행동 항목:
- `hexa atlas lookup` 이 HEXA_ATLAS_EMBED env 또는 cwd `compiler/atlas/embedded.gen.hexa` 를 binary-builtin 보다 우선 읽도록 동작 명세 정리/수정
- OR `hexa atlas register --from-verify` 가 source fold 후 binary-builtin 상태에도 in-memory 반영 (현재는 source 만 갱신)
- OR register 가 자동으로 `hexa cc --regen` 트리거 옵션 제공 (heavy, off by default)
- 참고: `.verdicts/tecs-l-atlas-health/binary_vs_source_divergence.txt` — 정량 데이터
- cross-link: TECS-L 축 E E3 (register install-dir leak, PR #1102) 와 짝 — register hazard(쓰기) + query staleness(읽기) 양면

### 3.4 grown infra 의 미래 사용
패치 머지 후 NOVEL 다음 라운드 가용성:
- 직접: E1 의 register-then-lookup 라운드가 1회 close (즉시 query 반영) —
  발견-등록-조회 cycle 단축, 라운드당 IO 1회 감소.
- 간접: atlas 가 NOVEL F11 ("terminal 발견 → atlas fold") 의 보편 메커니즘
  이므로, query staleness 해소가 모든 fold-back 라운드(F-pipeline 전 가지)
  의 신뢰 바닥을 끌어올린다.

→ E2 한 발견의 INBOX 한 줄이 NOVEL 파이프라인 의 (axis E + axis F11) 전체
신뢰 baseline 을 끌어올리는 효과.

---

## §4. Canonical pipeline (5-step workflow)

```
   ┌──────────────────────┐
   │ (1) NOVEL 라운드     │ ─── 축 A/B/C/.../E 발견 시도
   │     (verify try)     │     · hexa verify --expr / atlas / fence
   └──────────┬───────────┘
              │
              │ fn gap / 정의 불일치 / 동작 ≠ 명세 노출
              ▼
   ┌──────────────────────┐
   │ (2) honest tier 기록 │ ─── 🔴 closed-negative / 🟡 citation /
   │   (over-claim 금지)  │     🟠 deferred — 절대 🔵/🟢 위장 금지
   └──────────┬───────────┘     (CLAUDE.md @D claim_verify)
              │
              │ verdict 영속화 (.verdicts/<slug>/<id>.txt)
              ▼
   ┌──────────────────────┐
   │ (3) g59 INBOX 업스트림│ ─── INBOX.log.md prepend
   │     (reflex)         │     · 구체 issue 헤더
   └──────────┬───────────┘     · 정량 데이터
              │                  · 권고 actions (`- [ ]`)
              │                  · cross-link verdict + 문서
              ▼
   ┌──────────────────────┐
   │ (4) hexa-lang patch  │ ─── 다른 세션/agent 가 INBOX 항목을 anchor
   │     (다른 세션)      │     로 stdlib/compiler/verify 패치 머지
   └──────────┬───────────┘
              │
              │ 패치 머지 + atlas/binary 재빌드 (필요시)
              ▼
   ┌──────────────────────┐
   │ (5) NOVEL 다음 라운드 │ ─── 새 fn / 새 동작 명세 활용 가능
   │  (grown infra)       │     · 후속 milestone close
   └──────────────────────┘     · 다른 축 (F11 fold, MR/MF 계산) 신뢰 ↑
```

### 4.1 단계별 정직 게이트

| step | 게이트 | 위반 시 |
|------|--------|---------|
| 1 | `hexa verify` g5 closed-form / RUNEQ 만 verdict 발급 | LLM 자기판정 = 차단 (claim_verify) |
| 2 | tier = 실제 verdict 정확히 (🔴/🟡/🟠/⚪) | over-claim → paper_violation, 즉시 revoke |
| 3 | INBOX 헤더 + 정량 데이터 + 권고 actions 모두 필수 | 헤더만 있으면 다음 agent 가 anchor 못 잡음 |
| 4 | 본 세션은 (4) 까지 안 가도 됨 — 다음 세션 책임 | 그러나 (3) 이 형식 미달이면 (4) 가 영영 안 옴 |
| 5 | grown infra 활용은 후속 milestone 으로 별도 기록 | F9 본 문서는 (1)~(3) 까지만 입증 |

### 4.2 NOVEL ≠ "discovery-only" lane — 이 워크플로의 본질

NOVEL 축이 단순 발견 lane 이라면 (1)~(2) 만 있고 (3)~(5) 가 없어야 한다.
그러나 hexa-lang 같은 self-host self-verify-tooled 시스템은 발견을 시도하는
순간 자기 fn 의 한계를 노출시킨다. F9 의 주장은:

> **NOVEL 축은 자체 verify infra 의 boundary-prober 다. 발견의 부산물로
> stdlib/compiler/verify 의 gap 을 매 라운드 산출하며, 그 gap 을 g59 INBOX
> 로 자동 흘려보내는 한, NOVEL 라운드 수만큼 infra 가 자란다.**

이 자가-성장 메커니즘이 F9 milestone 의 정의다 — calc-fn gap → g59 INBOX →
hexa stdlib/compiler/verify 패치 → 다음 round 활용 → (반복).

---

## §5. TECS-L 도메인 입증

### 5.1 NOVEL 의 verify-외적 가치
TECS-L 의 NOVEL 축 (F1..F12) 은 본디 σφ=nτ 정체성 군 확장(F1) / 외부광맥
mining(F3/F4) / 반증사냥(F5) / 범위확장(F6/F7) 같은 "발견 본진" milestone
들로 구성된다. F8 (cross-domain bridge) 와 F9 (도구확장) 는 family 분류상
보조 lane 처럼 보이지만, 본 문서는 F9 가 실제로는 **NOVEL 축의 1차 가치
명제 의 절반** 임을 보인다.

| family | 1차 가치 | 측정 |
|--------|----------|------|
| (a)..(d) | 발견 본진 — 정체성/반증/외부 hit | verdict count |
| (e)    | 범위확장 — n=6 외 candidate | verdict count |
| (f) **F9** | **verify-infra growth** | INBOX 업스트림 → 패치 머지 → grown fn 가용 |
| (g)    | 파이프라인 자동화 | round throughput |

이번 세션 (2026-05-25) 측정:
- 축 A MF4 (PR #1083 MERGED) → INBOX 업스트림 1건 → modform domain
  dim S_k fn signature 갭 보고.
- 축 E E2 (PR #1096 MERGED) → INBOX 업스트림 1건 → atlas SSOT vs binary
  lookup 갭 보고.

→ **2 개 NOVEL 라운드 = 2 개 verify-infra growth 입력**. 100% rate (이번
세션 표본 한정).

### 5.2 honest scope (over-claim 차단)
F9 는 다음을 주장하지 **않는다**:

- ✗ NOVEL 라운드가 항상 fn gap 을 노출한다 — 노출 안 할 수도 있다(라운드의
  fn 이 이미 완벽한 경우).
- ✗ INBOX 업스트림이 자동으로 hexa-lang 패치를 보장한다 — 본 세션은 (3) 까지
  만 입증, (4)~(5) 는 다른 세션 / 시간축에 위임.
- ✗ NOVEL 만이 infra growth lane 이다 — RUNTIME/COMPILER/CANON 도메인의
  자체 cycle 도 별도 growth 경로다 (예: RUNTIME.md step3/4/5).

F9 가 주장하는 것:

- ✓ NOVEL 라운드는 자주 fn gap 을 노출시키며, 그것을 g59 INBOX 로 흘려
  보내는 reflex 가 있는 한, NOVEL 라운드 수가 infra growth 의 lower bound
  를 만든다.
- ✓ 이번 세션 2 개 라운드 (MF4 / E2) 가 정확히 그 패턴으로 종결됐다 —
  workflow §4 의 (1)~(3) 단계 완료, verdict + INBOX 영속화.

### 5.3 method
- **synthesis** (M10/MR1/E3/F8 동일) — 신규 산술 verify 0건, 기존 2 PR
  앵커.
- INBOX 업스트림 reflex 가 거버넌스 (`AGENTS.tape` g59/g60 commons rule) 로
  이미 명문화되어 있으며, F9 는 그것을 NOVEL 축 milestone framework 안에서
  명시적으로 인용·정형화한다.
- paper_significance 불충족 (별도 falsifier 없음, infrastructure-workflow
  doc) → /paper 비대상. paper_gate 통과 안 함이 정상.

### 5.4 결론
NOVEL 축의 진가는 발견 더미가 아니라 — **발견 시도가 자기 infra 의 한계를
지속적으로 노출시켜 patch loop 의 입력을 만든다는 점**. F9 = 이 메커니즘의
canonical 문서화. terminal-empirical synthesis (workflow_pipe verdict §4).

---

## 영속화

- verdict: `.verdicts/tecs-l-novel-inbox-pipe/pipe_workflow.txt` (ASCII 요약 +
  MF4 / E2 anchor PR #1083 / #1096 인용).
- CLAIMS.tape: 1 @C `tecs_l_novel_inbox_pipe_workflow` (slug
  `tecs-l-novel-inbox-pipe`, group TECS-L, method `synthesis`,
  status 🟢 empirical workflow — 2 입증 케이스).
- 도메인 업데이트:
  - `TECS-L/TECS-L.md` F9 → `- [x]`
  - `TECS-L/TECS-L.log.md` 신규 prepend `## 2026-05-25T... — 축 F F9 …`
- 후속 (deferred · F9 외):
  - MF4 INBOX 의 hexa-lang patch 머지 → MODFORM domain dim S_k 후속 milestone
  - E2 INBOX 의 hexa-lang patch 머지 → 축 E E1 register-then-lookup 즉시 cycle
  - 위 두 라운드는 별도 milestone (F9 의 (4)~(5) 단계) 으로 독립 기록
