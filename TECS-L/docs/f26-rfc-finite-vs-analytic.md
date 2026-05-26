# RFC — TECS-L 방법론 spec: finite-arithmetic vs analytic-infinite 이분법

> **상태**: ACTIVE · methodology spec (박제용) · F26 INBOX #97 발원
> **발원**: TECS-L F26 brainstorm R7 #97 (2026-05-27)
> **목적**: TECS-L 의 verify-tier 강·약 영역을 명문 spec 으로 고정해, 향후 F-cycle 이
> 새 axis 를 발굴할 때 **분류 → tier 기대 → calc-path 필요 여부 → paper 자격** 을
> 결정론적으로 판정하게 한다.

## 1 · 요약

TECS-L 의 verify-tier 가 **finite-arithmetic axis (exact-integer closed-form) 에 강하고,
analytic-infinite axis (asymptotic · 수렴-기반 · 무한 sum · L-함수 미분) 에 약하다**는 것이
**F22 (RH+BSD millennium retry-2) 에서 honest-negative 로 결정화**됐다. F14-F18 finite-arithmetic
축은 σ/φ/τ/σ_k closed-form 을 hexa-native 가 정확 재현해 🔵 우세였던 반면, F19/F22 의 RH
asymptotic · BSD L'-derivative 축은 hexa-verify 가 자연히 닫지 못해 **0 novel atom · honest
🟠/🔴** 으로 마감됐다. 이는 결함이 아니라 **g5 verify-discipline + g3 over-claim 0 의 정직한
경계 선언**이다. 본 RFC 는 그 경계를 axis 분류 매트릭스 + 결정 트리로 spec 화한다.

## 2 · 배경 — F-cycle 증거

| F-id | axis | primary verdict | 핵심 근거 |
|------|------|-----------------|-----------|
| F14-F16 | σφ=nτ ω-tower · σ_k k=4,5 · modular dim S_k | 🔵 우세 | exact-integer closed-form, hexa-native σ/τ 정확 재현 (#1361) |
| F17 | ω=6/7/8 + σ_k + Ore subfamily + L-function | 🔵 우세 | finite divisor-sum closed-form (#1361) |
| F18 | ω=9/10 D-sweep + σ_k k=6,7,8 + weight-4 newform recovery | 🔵 우세 | 4 novel atom fold, σ_k 정수 (bignum caveat) (#1419) |
| F19 | Clay-RH/BSD methodology-transfer candidate-spec | 🟠 (0 novel) | analytic 축 → calc-path 부재, extreme-honesty spec (#1372) |
| F22 | RH + BSD millennium retry-2 (둘 다) | 🟠/🔴 (0 novel) | **honest negative** — framework recasting, analytic-infinite out-of-scope (#1432) |
| F23 | finite-arithmetic 강점 복귀 + weight-4 recovery | 🔵 우세 (3 novel) | F22 negative 후 finite 축 복귀로 3 atom fold (#1435) |
| F25 | PHYSICS NOVEL probe (string·gauge·AdS analogy) | ⚪/🟡 (0 novel) | 13 🔵 atom 재인용 + 7 ⚪ pairing, framework-analogy negative (#1440) |

**패턴**: finite 축(F14-F18, F23) = 🔵 우세 + novel atom fold. analytic/observation 축(F19,
F22, F25) = honest negative + 0 novel atom. **F22 가 변곡점** — RH/BSD 두 축을 모두 정직하게
out-of-scope 선언, 그 직후 F23 가 finite 강점으로 복귀해 회복.

## 3 · 이분법 정의

```
┌───────────────────────────────────────────────────────────────────────┐
│ FINITE-ARITHMETIC (TECS-L 강점, 🔵/🟢)                                  │
│   = exact-integer closed-form · 유한 산술 조합                          │
│   primitive: σ, φ, τ, σ_k, σ* (unitary), ω, Ω, μ, λ_Liouville,          │
│              Pisano π(n), Pell, multi-perfect, HCN, practical            │
│   성질: 정수 입력 → 정수/유리수 출력, 결정론적, ≤30 verify call,        │
│         hexa-native 가 정확 재현 (no float drift, no convergence)        │
├───────────────────────────────────────────────────────────────────────┤
│ ANALYTIC-INFINITE (TECS-L 약점, 🟠/🟡/⚪)                                │
│   = asymptotic · 수렴-기반 · 무한 sum · L-함수 미분                      │
│   axis: RH (ζ zeros asymptotic) · BSD (L'-derivative) · Λ (우주상수) ·   │
│         H₀ (Hubble) · α (미세구조) · ζ(3) Apéry · IIT Φ                  │
│   성질: 무한 극한/수렴 필요 · 초월수 출력 가능 · 외부 관측상수 의존 ·    │
│         hexa-native closed-form 경로 부재 → g5 자연 닫힘 불가            │
└───────────────────────────────────────────────────────────────────────┘
```

**경계의 본질** (M7 golden-zone closed-negative 와 동일 논증): σ(6)·τ(6)·φ(6) 같은 정수의
유한 산술 조합은 전부 **유리수**다. 1/e · ζ(3) · RH 임계선 같은 **초월/asymptotic 대상은
유리수 ≠ 초월수** 라 정확 유도가 결정론적으로 불가능 — 근사만 가능. 이것이 finite↔analytic
경계의 수학적 뿌리다.

## 4 · tier-axis 결정 매트릭스

```
┌──────────────────────────────┬──────────────┬─────────────────────────────┐
│ axis 클래스                  │ 기대 tier    │ 예시 atom                   │
├──────────────────────────────┼──────────────┼─────────────────────────────┤
│ exact-integer closed-form    │ 🔵 FORMAL    │ σ(6)=12 · τ(6)=4 · φ(6)=2   │
│  (multiplicative · divisor)  │              │ σ_k(P_k) tower · D(n)=0     │
├──────────────────────────────┼──────────────┼─────────────────────────────┤
│ numerical bounded recompute  │ 🟢 NUMERICAL │ libm/Newton 수치 재현       │
│  (libm · Newton, non-symbolic)│             │ (~10min suite, 유한 정밀)   │
├──────────────────────────────┼──────────────┼─────────────────────────────┤
│ atlas/문헌 등록, hexa 재현 無 │ 🟡 CITATION  │ Heegner h=1 · Δ(τ) 24 ·     │
│  (sympy/OEIS carry)          │              │ weight-4 Hecke a_p (T_p 부재)│
├──────────────────────────────┼──────────────┼─────────────────────────────┤
│ closed-form 존재 BUT primitive│ 🟠 calc-gap  │ σ*(unitary) · sigma_3 ·     │
│  부재 (calc-gap family #1230) │  INSUFFICIENT│ λ_Carmichael · Pisano · Bell│
├──────────────────────────────┼──────────────┼─────────────────────────────┤
│ asymptotic/수렴-기반/무한 sum │ 🟠 DEFERRED  │ RH ζ-zeros · BSD L' ·       │
│  · L'-derivative             │  (analytic)  │ ζ(3) Apéry rationality      │
├──────────────────────────────┼──────────────┼─────────────────────────────┤
│ 외부 관측상수/실험 의존       │ 🟠 DEFERRED  │ α · Λ · H₀ (external hw/data)│
│  (experimental constant)     │  (external)  │ IIT Φ faithful (calc-gap)   │
├──────────────────────────────┼──────────────┼─────────────────────────────┤
│ calc 가 주장과 결정론적 불일치│ 🔴 FALSIFIED │ Golden-zone 1/e EXACT 유도  │
│  (closed negative)           │              │ (유리수≠초월수) · Polya     │
├──────────────────────────────┼──────────────┼─────────────────────────────┤
│ 상상/은유 (verify N/A)        │ ⚪ FENCED     │ string·gauge·AdS framework  │
│                              │              │ analogy (F25, SF≠proven)    │
└──────────────────────────────┴──────────────┴─────────────────────────────┘
```

> tier 라벨은 `hexa verify rubric` SSOT 와 1:1 일치 (§7 인용). 🔵/🟢 = terminal-positive,
> 🔴 = terminal-negative, 🟡/🟠/⚪ = non-terminal (paper gate 부적격).

## 5 · 결정 트리

새 F-cycle 이 axis 를 발굴하면 `hexa verify --expr <fn>` 호출 **전에** 본 트리로 기대 tier 를
선판정한다.

```
새 axis 발굴
   │
   ├─(a) closed-form 존재? ──── NO ──► ⚪ SPECULATION-FENCED (--fence)
   │      │                            (상상/은유, verify N/A, paper 부적격)
   │     YES
   │      │
   ├─(b) integer-exact? ─────── NO ──┐
   │      │                          │
   │     YES                  ┌──── 수치 bounded? ── YES ─► 🟢 NUMERICAL (terminal)
   │      │                   │       (libm/Newton)    NO
   │      │                   │                          │
   │      │                   │                          └─► 다음 (c) 로
   │      │                   │
   ├─(c) primitive 존재? ──── NO ──► 🟠 INSUFFICIENT (calc-gap family #1230)
   │      │                          → INBOX 등록 (stdlib/verify_cli primitive 요청)
   │     YES                         → primitive land 후 재분류
   │      │
   ├─(d) 수렴-기반/asymptotic/무한 sum/L'-derivative?
   │      │
   │     YES ──► 🟠 DEFERRED (analytic-infinite, out-of-scope)
   │      │      → honest-negative ok (paper_negative_ok 대상 if 결정론적 배제)
   │     NO
   │      │
   ├─(e) 외부 관측상수/실험 의존?
   │      │
   │     YES ──► 🟠 DEFERRED (external hw/data/API)
   │     NO
   │      │
   └─► hexa verify --expr <fn> 실행
          │
          ├─ calc ≡ 주장 ──► 🔵 SUPPORTED-FORMAL (terminal, auto-absorb to atlas)
          └─ calc ≢ 주장 ──► 🔴 FALSIFIED (terminal closed-negative, publishable)
```

**핵심 순서**: (a) closed-form? → (b) integer-exact? → (c) primitive? → (d) 수렴-기반? →
verify. 분기 (d)/(e) 에서 멈추면 analytic-infinite 약점 영역 — F22 패턴 재현 회피용 게이트.

## 6 · MILLENNIUM/PHYSICS/COSMOS 대축 — 정직한 한계 선언

| 대축 | 분류 | hexa-verify 가 자연히 못 닫는 이유 |
|------|------|------------------------------------|
| MILLENNIUM-G (RH) | analytic-infinite | ζ-zeros 의 임계선 위치 = asymptotic 분포, ζ-zero verifier primitive 부재 (#1372/#1432) |
| MILLENNIUM-G (BSD) | analytic-infinite | rank ↔ L(E,s) 의 **L'-derivative @ s=1** = 무한 Euler product 미분, closed-form 경로 없음 |
| MILLENNIUM (P vs NP, Hodge, …) | structural/analytic | 정수 산술 항등식으로 환원 불가, framework-recasting 만 (F22 honest negative) |
| PHYSICS — α (미세구조상수) | external observation | 측정값 1/137.035999… = 실험 결정, 정수 closed-form 부재 (F25 ⚪/🟡) |
| PHYSICS — string/gauge/AdS | speculation | framework analogy, ⚪ SF≠proven, verify N/A (F25 honest negative) |
| COSMOS — Λ (우주상수) | external observation | 관측 의존, hexa-native 산술 경로 없음 → 🟠 DEFERRED |
| COSMOS — H₀ (허블상수) | external observation | 측정값(+허블 텐션), experimental constant → 🟠 DEFERRED |
| LIFE — IIT Φ | calc-gap (analytic) | `iit4_faithful_phi` primitive 부재 + 작은 network 만 tractable → 🟠 |

**선언**: 위 대축들의 🟠/⚪ 는 TECS-L 의 **실패가 아니라 정직한 scope 경계**다 (g3 over-claim 0).
finite-arithmetic 강점 영역(축 0 n=6, MODFORM dim, MERSENNE, NOVEL σ_k tower)에서만 🔵 를
주장하고, analytic-infinite 영역은 honest-negative 로 명시 — F22 가 이를 결정화했다.

## 7 · 거버넌스 cross-link

| 거버넌스 | 1-line 인용 | 본 RFC 적용 |
|----------|-------------|-------------|
| **g3 over-claim 0** | 측정·검증되지 않은 주장 금지 | analytic 축을 🔵 로 over-claim 하지 않고 🟠 정직 분류 |
| **g5 verify-via-CLI-only** | `hexa verify` (절대경로 게이트) 만이 tier 부여 권위 | tier 라벨은 `hexa verify rubric` SSOT 인용, LLM self-judge 금지 |
| **paper_significance** | pre-registered falsifier + real measurement + Δ-finding | analytic 축은 measurement 불가 → paper 부적격 |
| **paper_negative_ok** | 🔴 FALSIFIED 가 한 axis 를 결정론적 배제하면 publishable | golden-zone 1/e · F22 closed-negative = 유효 negative paper |

`hexa verify rubric` 8-tier SSOT (verbatim):

```
🔵 SUPPORTED-FORMAL      closed-form/symbolic identity 정확 재현 (Tier 1, deterministic)
🟢 SUPPORTED-NUMERICAL   numerical recompute 일치 (libm/Newton, Tier 2 ~10min)
🟡 SUPPORTED-BY-CITATION atlas/literature 등록, hexa recompute 無 (citation carry)
🟠 INSUFFICIENT          not in atlas + no calc path (calc-gap default)
🟠 DEFERRED              external hw/data/API dep (closure-external)
🔴 FALSIFIED             calc 가 결정론적으로 주장과 불일치 (closed negative)
⚪ SPECULATION-FENCED    imagination/metaphor (verify N/A, SF≠proven, g4 honest fence)
```

## 8 · F-cycle 적용 운영 규칙

새 brainstorm round 가 axis 를 발굴하면, §4 매트릭스 + §5 트리로 분류한 후 다음 4 결정을 한다:

| 결정 | 판정 기준 (본 RFC 트리 기반) |
|------|------------------------------|
| **(i) tier 기대** | §5 트리 종착 라벨 — 분기 (a)~(e) 통과 결과를 verify 전 선언 |
| **(ii) calc-path 필요?** | (c) 에서 primitive 부재면 YES → calc-gap family #1230 INBOX 등록 |
| **(iii) paper 후보 자격?** | 🔵/🟢/🔴 terminal + pre-registered falsifier + Δ-finding 만 적격 (🟠/🟡/⚪ 부적격) |
| **(iv) honest-negative ok?** | (d)/(e) analytic/external 분기 = honest 🟠 마감 ok, 결정론적 배제면 🔴 paper |

**운영 흐름**: 발굴 → §4/§5 분류 → (i)~(iv) 판정 → finite 축이면 verify+fold, analytic 축이면
honest-negative 마감 + INBOX 등록. **F22 패턴**(analytic 축 깊이 파고들어 0 novel atom 으로
좌초)을 트리 분기 (d)/(e) 가 사전 차단한다.

## 9 · 참고 — 기존 F-cycle 메모 / commit

| anchor | commit | 비고 |
|--------|--------|------|
| F19 Clay methodology-transfer | `007e8e8d` / `51d6e187` (#1372) | analytic 축 첫 honest spec (0 novel) |
| F22 RH+BSD retry-2 | `609c4a19` / `7846ee51` (#1432) | **honest-negative 변곡점** — 본 RFC 발원 |
| F23 finite 강점 복귀 | `0b54eb39` / `9113cecd` (#1435) | F22 후 finite 복귀, 3 novel atom fold |
| F25 PHYSICS NOVEL probe | `0b7dc055` (#1440) | framework-analogy negative, 13 🔵 재인용 |
| F26 axis brainstorm depletion | `TECS-L/docs/f26-brainstorm-summary.md` | 본 RFC 발원 R7 #97 |
| calc-gap family #1230 | `INBOX.md` (sigma_3 · σ* · sopfr · pow · J_k · iit4_faithful_phi) | (c) 분기 primitive 부재 추적 |
| golden-zone closed-negative | `TECS-L/docs/m7-golden-zone-closed-negative.md` | finite↔analytic 경계 논증 원형 (유리수≠초월수) |

---

> **closure**: 본 RFC 는 mergeable spec 으로, 향후 F-cycle 들이 axis 분류 시 §4 매트릭스 ·
> §5 트리 · §8 운영 규칙을 cite 할 수 있다. tooling 구현은 out-of-scope (별도 PR).
