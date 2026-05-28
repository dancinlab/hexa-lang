# A6 — cross-repo handoff 메커니즘 정립 (g60 INBOX) + 3 debt 정산

> ARXIV 도메인 A6 마일스톤. A2-A5 가 실천한 **cross-repo handoff 메커니즘(g60 INBOX)**
> 을 정본화하고, A2/A3/A4 가 남긴 **3개 핸드오프 부채**(anima/demiurge/phanes 의 dirty 트리에
> working-copy edit 로만 기록되고 commit 되지 못한 INBOX 항목)를 격리 worktree 로 안전하게
> 정산한다 (g48 ack 완료). A5 의 in-repo atlas-feed 가 이 메커니즘의 null/identity 케이스다.

## 1 · 메커니즘 — ARXIV axis 가 어떻게 핸드오프하는가

ARXIV 도메인은 **catalogue-mirror lane** 이다 — arxiv 논문을 흡수·검증·**분배**한다.
분배의 정본 경로(g60 cross-repo handoff):

```
arxiv query → 논문 추상 → claim 추출 → 3갈래 triage
   ├─ (a) verify-able  → hexa verify g5 → atlas fold (in-repo)
   ├─ (b) citation     → 🟡 atlas citation node
   └─ (c) project-specific → cross-repo INBOX handoff (g60)
                              │
                              ▼
   target-repo `INBOX.log.md` 에 항목 filing (slug 앵커 · stub-first · dedup)
                              │
                              ▼
   target-repo 세션이 그 항목을 commit + 소비 + ack (g48)
```

핵심 단계:

1. **ingest** — ARXIV axis 가 한 sibling 프로젝트의 arxiv 카테고리를 query (anima=q-bio.NC,
   demiurge=physics.atom-ph, phanes=cs.AI, hexa-lang=cs.PL/math.NT).
2. **triage** — 흡수 논문을 3-class 로 분류. (c) project-specific = 해당 target repo 가
   소비할 cross-link (anima H_xxx 가설 / demiurge 7공정 / phanes 4표면).
3. **file** — target repo 의 `INBOX.log.md` 에 핸드오프 항목을 append (newest-on-top,
   slug 앵커, stub-first dedup). **naive dump 금지** — 모든 항목이 명시적 cross-link 를 가져야
   흡수로 인정.
4. **ack (g48)** — target repo 세션이 그 항목을 commit + 소비 (cross-link 채택 / verify-able
   -CANDIDATE 채택 판단). 이것이 핸드오프 루프의 닫힘.

**왜 INBOX 인가**: ARXIV 는 흡수 repo(hexa-lang)에 있고 finding 의 소비자는 sibling repo 다.
직접 sibling 의 SSOT(LIFE.md / ANTIMATTER.md / GOAL.md)를 ARXIV 가 편집하면 두 repo 의
authoring 권위가 충돌한다. INBOX 는 **비동기 비파괴 mailbox** — ARXIV 가 항목을 떨어뜨리고,
target 세션이 자기 속도로 소비한다. (sidecar `@D depletion_not_terminal` 와 같은 비동기 lane 모델.)

## 2 · 4-axis 패턴 — 3 cross-repo + 1 self-absorb null case

ARXIV 의 4 axis fan-out 은 핸드오프 메커니즘의 **3 인스턴스 + 1 identity(null) 케이스**다:

| axis | target repo | 관계 | handoff |
|---|---|---|---|
| **A2 ANIMA** | `~/core/anima` (sibling) | cross-repo | 6 H_xxx LIFE cross-link (g60 INBOX) |
| **A3 DEMIURGE** | `~/core/demiurge` (sibling) | cross-repo | 12 ANTIMATTER 7공정 cross-link (g60 INBOX) |
| **A4 PHANES** | `~/core/phanes` (sibling) | cross-repo | 10 phanes 4표면 cross-link (g60 INBOX) |
| **A5 HEXA-LANG** | **hexa-lang 자신** (in-repo) | **self-absorb** | **0 — null/identity 케이스** |

**A5 = self-absorb null case 의 의미**: A5 의 흡수 대상(컴파일러/수론)이 흡수하는 repo
자신(hexa-lang)이다. 핸드오프할 "다른 repo" 가 없으므로 **handoff 횟수 = 0**. 대신 finding 은
hexa 자신의 atlas 로 직접 fold 된다 (`compiler/atlas/embedded.gen.hexa`). 즉

> **self 에게 handoff = in-repo atlas feed = INBOX hop 없음.**

이것이 메커니즘의 항등원(identity)이다 — cross-repo handoff 를 "target=self" 로 특수화하면
INBOX mailbox 단계가 사라지고 atlas fold 만 남는다. A5 의 math.NT 8편이 σ/τ/φ/μ/nth_prime/
catalan/partition 을 DIRECT recompute 한 것(30+ 🔵)이 바로 이 in-repo atlas-feed 의 실증이다.

## 3 · dirty-tree commit hazard — 왜 부채가 생겼나

A2/A3/A4 가 핸드오프를 **filing** 했지만 **commit** 하지 못한 구조적 이유:

target repo 들이 전부 **non-main feature 브랜치 + dirty working tree** 위에 있었다:

| repo | A2-A4 당시 브랜치 상태 | dirty 형태 |
|---|---|---|
| anima | `ops/f-curricula-1-orphan-recover-2026-05-25` | orphan-recover (root SSOT 가 main 을 shadow) |
| demiurge | `feat/rtsc-magnet-wheeler-v2` | `M INBOX.log.md` + untracked hexa-fusion-7gate PDF |
| phanes | `domain/init-phanes` (1 ahead / 4 behind main) | clean 이지만 non-main |

**hazard**: hexa-lang 의 메모리 패턴(`feedback-closure-is-physical-limit` ·
`shared-worktree-branch-hazard`)에 따르면, ARXIV agent 가 **남의 repo 의 공유 dirty 트리에서
직접 commit** 하면 — (1) 그 트리에 진행 중인 무관한 WIP 를 핸드오프 커밋에 끌어들이거나,
(2) feature 브랜치에 묶여 main 에 안 닿거나, (3) 8세션 공유 git 객체 스토어에서 race 를 일으킨다.
그래서 A2-A4 는 **working-copy edit (append, stub-first, dedup) 으로만 기록하고 commit 은
target 세션에게 위임**했다 — 정직한 보수적 선택이었으나, 그 결과 핸드오프가 main 에 닿지 못한
**3개 부채**가 남았다 (g48 ack 미완).

**resolution (A6 가 실행)** — **target repo 별 격리 worktree off origin/main**:

```
cd ~/core/<repo> && git fetch origin main
git worktree add /tmp/wt-<repo>-inbox origin/main   # 깨끗한 origin/main 사본
# worktree 에서 INBOX.log.md 에 핸드오프 항목 추가 (남의 dirty 트리 무관)
git commit -m "docs(INBOX): ARXIV <axis> ingest handoff …"
git push origin HEAD:main      # 또는 main 게이트면 PR
git worktree remove /tmp/wt-<repo>-inbox
```

격리 worktree 는 **target 의 dirty feature 트리를 전혀 건드리지 않는다** — origin/main 의 깨끗한
사본에서만 작업하므로 hazard 3종이 모두 소거된다. 이것이 cross-repo handoff 의 **commit-safe 정본**이다.

### A6 의 3 debt 정산 결과 (g48 ack 완료)

| repo | slug | main 게이트 | 정산 방법 | 결과 |
|---|---|---|---|---|
| **anima** | `arxiv-a2-iit-empirical-ingest` | protected (review 1, enforce_admins=false) | 격리 worktree → PR → admin-merge | ✅ committed (PR #576, merge `4618d7c9`) |
| **demiurge** | `arxiv-a3-antimatter-factory-ingest` | unprotected | 격리 worktree → 직접 push main | ✅ committed (`10f909ca`) |
| **phanes** | `arxiv-a4-autonomous-discovery-ingest` | unprotected | 격리 worktree → 직접 push main (파일 신규 생성) | ✅ committed (`22414be4`) |

3/3 부채 정산 완료. 각 target repo 의 main 이 이제 핸드오프 항목을 보유 → target 세션이 소비 가능
(g48 ack 의 hexa-lang 측 절반 = "committed by A6", target 측 절반 = "consumed by session" 은
각 repo 세션 몫).

## 4 · verify-density 상관 — 핸드오프-축의 검증가능성 ∝ target-repo 폐형해 밀도

핸드오프 4-axis 를 측정하면 **그 축의 verify-ability 가 target repo 의 closed-form(폐형해) 밀도에
정비례**한다는 구조적 상관이 드러난다:

| axis | target | verify-able (🔵 recompute) | 폐형해 밀도 | 성격 |
|---|---|---|---|---|
| **A3 DEMIURGE** | demiurge | **5종 물리상수 🔵** (+1 🔴 neg ctrl) | **high** — RFC-045 물리 fn 이 `hexa verify --expr` 에 깔림 | verify-native producer |
| **A5 HEXA-LANG** | hexa-lang (self) | **16 fn · 30+ recompute 🔵** (+1 🔴) | **highest** — σ/τ/φ/μ/nth_prime/catalan/partition TECS-L Tier1 | verify-native (in-repo) |
| **A2 ANIMA** | anima | **0** (in-tree IIT primitive 부재) | **0** — Φ/EI/PCI 폐형해 atom 없음 | consumer (V5 IIT 엔진 후 회수) |
| **A4 PHANES** | phanes | **0** (정직·예상) | **0** — OUROBOROS 엔진 소비자, SaaS 축 | consumer |

**상관의 메커니즘**: verify-able recompute 는 "논문이 인용하는 *값*을 hexa atom 으로 재계산"
하는 것이다. 그 값이 hexa 의 폐형해 atom 으로 이미 존재해야(= target 도메인이 verify-native)
DIRECT recompute 가 된다. 그렇지 않으면(consumer 도메인) 핸드오프는 citation + cross-link 만
남고 verify 수치 = 0.

```
verify-density  ∝  target-repo 의 closed-form atom 밀도

  DEMIURGE  (물리 factor/exponent 폐형해)   → 5 🔵   ┐ verify-native
  HEXA-LANG (수론 σ/τ/φ 폐형해, self)        → 30+ 🔵 ┘
  ─────────────────────────────────────────────────
  ANIMA     (Φ/EI primitive 부재)            → 0      ┐ consumer
  PHANES    (OUROBOROS 엔진 소비자, SaaS)     → 0      ┘
```

이것은 **honest negative 가 아니라 구조적 사실**이다 — ANIMA(A2)/PHANES(A4)의 0 verify 는
실패가 아니라 그 축이 **소비자 도메인**이라는 정직한 측정이다. A2 의 4편 verify-able-CANDIDATE
(exact-EI / neural-complexity / ETC / CTM)은 V5 IIT 엔진(`stdlib/consciousness/iit4`)이 랜딩하면
ANIMA 의 폐형해 밀도가 0→양수로 바뀌어 첫 🟢 가 가능해진다 — 즉 상관은 시간에 따라 움직인다
(target repo 가 verify-native 로 진화하면 핸드오프-축도 verify-able 로 승격).

> **A2-A5 측정 표 (위)가 본 상관의 실증이다**: producer 축 2개(D/HL) = 폐형해 밀도 high →
> verify 35+ 🔵 ; consumer 축 2개(A/P) = 폐형해 밀도 0 → verify 0. 핸드오프의 산출 가치는
> producer 축에서는 citation+handoff+**verify**, consumer 축에서는 citation+handoff (cross-pollination).

## 5 · 거버넌스 · 정직성

- verify 정본 = `hexa verify` g5. A6 는 메커니즘 정본화 + 부채 정산이지 새 verify 산출 아님.
- cross-repo handoff = g60 INBOX. ack = g48 (filed → committed → consumed).
- **commit-safe 정본 = 격리 worktree off origin/main** — 남의 dirty 트리 직접 commit 금지
  (`shared-worktree-branch-hazard` · `feedback-closure-is-physical-limit`).
- naive dump 금지 — 3 핸드오프 항목 전부 명시적 cross-link 보유 (anima 6 H · demiurge 7공정 ·
  phanes 4표면).
- target repo 의 기존 dirty feature 트리 / 진행 중 WIP 는 건드리지 않음 (격리 worktree 만 사용).

## 6 · 다음 (A7 readiness)

A6 = cross-repo handoff 메커니즘 CLOSED — 정본 정립 + 3 debt 정산(anima/demiurge/phanes 전부
main 커밋, g48 ack 완료). 다음 = **A7 catalogue closure report** — 4-repo 흡수 ledger +
reuse edge (g67 DOMAINS.tape) + OEIS/DLMF/ARXIV catalogue-mirror family 의 종합 closure 보고.
verify-density 상관(§4)이 A7 ledger 의 한 축이 된다 (producer vs consumer 축 분류).
