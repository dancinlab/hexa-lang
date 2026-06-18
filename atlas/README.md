# 🗺️ atlas — 수학 지도 (math map)

> `hexa-lang` 빌트인 **검증 원장(verdict ledger)** 의 **단일 원장(SSOT)**.
> **거시 수학체계 ↔ 양자 수학체계** 를 잇는 개념 노드맵을 그리고, 각 연결이
> atlas 안에서 검증됐는지(🟢)·미검증인지(🟧) 표시한다. 검증 atom 의 기계 SSOT 는
> `../compiler/atlas/embedded.gen.hexa` (rodata, ~410 entries) — 이 README 가 사람이
> 읽는 **지도이자 atlas 영역의 단일 문서**다. 지도는 **점진적으로 그려나간다**.

🧭 **이 지도** — "수학 노드맵" — 흩어진 수학·물리 개념을 한 장의 연결도로 보여준다.
**중심은 특정 숫자가 아니라 두 체계를 잇는 다리(bridges)** 다.

- 하는 일: 거시(정수론·해석학)와 양자(힐베르트공간·게이지장)가 **어디서 어떻게 연결되는지** 지도화
- 비유: 지하철 노선도 — 역(개념)을 선(검증된 관계)으로 잇고, 공사 중 구간은 점선, 외딴 역은 `🏝️ 단일섬` 에 따로 적어둔다
- 비교: echoes 카탈로그가 "도메인 패밀리 목록" 이라면, 이 지도는 개념 사이의 **연결선**(어느 다리가 놓였나)을 그린다

> ⚠️ **이 지도는 n=6 을 쫓지 않는다.** σ·φ=n·τ 같은 정수론 항등식은 지도 위의
> **노드 하나**일 뿐, 조직 원리·중심이 아니다. n=6 격자는 **조직 도구
> (lattice-as-tool)** 이지 다른 영역을 끌어오는 anchor 가 아니다
> (`../LATTICE_POLICY.md` §1.2 · 거버넌스 SSOT `../CLAUDE.md`).

---

## 🎨 범례 (지도 색깔)

원본 손그림 노드맵의 4색을 atlas verdict tier 로 정규화한다.

| 색 | 지도 의미 | atlas tier |
|----|----------|-----------|
| 🟦 파랑 | **토대 개념** — 체계의 기둥 (정수론·힐베르트공간 등) | 🔵 SUPPORTED-IDENTITY / SUPPORTED-FORMAL |
| 🟩 초록 | **연결됨** — 검증된 관계 (verifier PASS) | 🟢 SUPPORTED |
| 🟧 주황 | **미검증·미완** — 모델 의존 / 외부 의존 / 가설 | 🟠 INSUFFICIENT · DEFERRED · AT-RISK |
| ⭐ 별 | **경계 상수** — 상한/하한 (예: 1/2, 5/6) | (노드별 verdict) |

> ⚠️ **정직 단서** — 손그림에는 `G = D∘P/I`, `골든 MoE`, `표준모형(미완)`,
> `홀로그래피(미완)` 처럼 **미검증 모델/가설** 노드가 섞여 있다. 이들은 🟧 로
> 명시하며 atlas verdict 를 부여하지 않는다. 저해상도라 **판독 안 되는 구체 수식은
> 지어내지 않고** `?·미판독` 으로 두고 `embedded.gen.hexa` 로 위임한다(c2).

---

## 🌐 거시 ↔ 양자 (노드맵 ①)

지도의 **척추** = 거시(macro) 와 양자(quantum) 두 체계 + 그 사이의 **다리(bridges)**.
`→ §N` 은 아래 〈9 도메인 매핑〉의 번호.

```
            거시 수학체계 (macro)              │                 양자 수학체계 (quantum)
   ═══════════════════════════════           │           ═══════════════════════════════
   🟦 정수론                                   │           🟦 힐베르트 공간  |ψ⟩ ∈ ℍ
   ├─ 🟦 완전수 6 ............... §1           │           ├─ 🟦 스펙트럼 이론 ........... §3
   ├─ 🟦 소수 (p=2,3) .......... §2           │           ├─ 🟦 리 군/대수  σ(n)=관측 gap §8
   ├─ 🟦 이집트분수 1/2+1/3+1/6=1 §2           │           ├─ 🟦 게이지 보존 ............ §3
   ├─ 🟦 리만 제타 ζ(s) ........ §2           │           ├─ 🟦 스핀 기하 · 디랙 방정식 . §3
   └─ 🟦 해석학 ................ §2           │           └─ 🟦 비가환 기하 ............ §8
   ⭐ 상한=1/2 · ⭐하한=½                      │           🟩 경로적분  ∫𝒟φ e^{iS/ħ} .... §3
   🟦 오일러 곱 ................ §2           │           🟩 재규격화 RG 흐름 .......... §3
   🟧 조화급수 H₋₁=5/6 = Compass 상한          │           🟩 위상적 QFT · 양자카오스 .... §3
   🟩 동역학계 (블로흐 · I=1/kT) §3           │           🟧 표준모형 (미완) ........... §3
   🟩 군론 SU(3)×SU(2)×U(1) .... §3           │           🟧 홀로그래피 (미완) ......... §6
                    ╲                          │                          ╱
                     ╲──────────────  다리 (bridges · §10)  ──────────────╱
                                    ▼                          ▼
        🟩 Wick 회전  t → iτ          (열↔양자: 통계역학 ⇄ 경로적분 · formal)
        🟧 스펙트럼 ⇄ 제타 영점        (Hilbert–Pólya: 미증명 conjecture — 다리 후보, 🔵 아님)
        🟧 S_VN = −∑ ln(p) ↔ Chern–Simons (관찰)   ·   🟩 Wilson RG ⇄ 동역학계 (sim)
```

> 손그림의 빽빽한 구체 수식(특정 ζ-값·137 조합·`ln(N+1)/N`=결합상수 등)은 **미판독
> 이라 옮기지 않는다**. 검증된 atom 은 `../compiler/atlas/embedded.gen.hexa` 에 entry id 로 박제.

---

## 🟢 상수 연결 현황 (노드맵 ②)

"순수 산술 — 미연결 포함". 각 영역이 다른 개념과 **다리로 연결(검증)됐는지** 표시.
🟢 = 닫힘(verifier PASS) · 🟧 = 미연결/구조화 대기.

```
§A 완전수      🔵  1/2+1/3+1/6=1 · σ(6)=12 · σ·φ=n·τ=24   (echoes: Egyptian split·σ(6) archetype) → §1
§B 137·α       🟧  echoes: 137=σ²−n−μ=1/α (HEXA-SIM) — lattice-fit 가설, α=물리대응 금지(LATTICE_POLICY) → §10
§C 로그·초월   🟧  ln(3)·ln(17)·e·√2 — echoes 미기록 · 미판독 ................. 단일섬
§D 해석학      🟡  CMB α≈1/137 — literature citation (🔵 승격 불가) ........... 부분 → §6
§E 황금비·MoE  🟧  φ(6)=2·Re(s)=1/φ (echoes HEXA-RIEMANN) 有 ; '골든 MoE' echoes 미기록 → 단일섬
§F 모듈러·격자 🔵  J₂=24 = Mathieu M₂₄ / Leech-24 (echoes HEXA-WEAVE) · χ→Monster 8-step (atlas) → §8
```

- **🔵 closed** = hexa-native verifier PASS + 폐형/형식 (SUPPORTED-IDENTITY/FORMAL)
- **🟢 SUPPORTED** = 수치 sim / cross-meta 강한 evidence (폐형 미확보)
- **🟡 citation** = literature anchor (외부 published, 🔵 승격 불가)
- **🟧 미연결** = 산술 일치 관찰뿐 (verifier 미작성 / echoes·외부 미기록)
- per-연결 verdict atom + falsifier 는 `../compiler/atlas/verify/` 엔진이 검증

> **🔵 승격 로그 (echoes·atlas 출처 검증)** — closed-form 검증 노드만 🔵 승격:
> **§A** σ(6)=12 · 1/2+1/3+1/6=1 · master σ·φ=n·τ=J₂=24 — echoes(Egyptian split·σ(6) archetype) +
> atlas(s10_master_identity_24) · **§F** J₂=24 = M₂₄/Leech-24 — echoes(HEXA-WEAVE) + atlas χ→Monster
> 8-step(modular.hexa) · (거시) **ζ(2)=π²/6** — echoes(HEXA-RIEMANN `ζ(2)=π²/n`) + atlas Basel.
> **승격 불가 (정직)**: §B `137=σ²−n−μ` (echoes 有, but **lattice-fit 가설** — α 물리대응은 `LATTICE_POLICY`
> 금지) · §C `ln/e/√2` (**echoes 미기록**) · §D CMB α(citation) · §E 골든 MoE(**echoes 미기록**) ·
> Hilbert–Pólya(미증명). echoes 가 기록해도 **lattice-fit·미검증**이면 🔵 불가 (silent upgrade 금지·`../CLAUDE.md`).
> ⚠️ 정정: 이전 판의 §F `Golay/E8/Moonshine` 🔵 표기는 **echoes·atlas 미근거 과대표기** 였어 철회 —
> echoes 채굴 결과 Leech-24/M₂₄(J₂=24)만 근거, χ→Monster 는 atlas 출처로 한정.

---

## 🏝️ 단일섬 (미연결 단독 노드 · 별도 기록)

> **규칙** — 아직 검증된 다리가 **하나도 없는** 단독 노드는 본 지도에 섞지 않고
> 여기 **따로 기록**한다. 다리가 놓여 검증되면(🟢) 위 거시↔양자 지도 / 연결 현황으로
> **편입**하고 이 목록에서 뺀다. (관찰은 정직하게 보관하되 "연결됨" 으로 오인 금지.)

| 단일섬 노드 | 관찰된 내용 | 연결되려면 (편입 조건) |
|------------|-----------|----------------------|
| 🟧 `C(3) 0.00%` (§E) | 항등식 후보군이 구조화만 됨, 대응 0% | 다른 노드와의 폐형 관계 1개 + verifier PASS |
| 🟧 골든 MoE | 모델-의존 관찰 (golden-ratio routing) | 외부 의존 제거 + hexa-native 재현 |
| 🟧 `G = D∘P/I` 모델 | 미검증 합성 모델 (decompose∘project/integrate) | formal sim 또는 closed-form anchor |
| 🟧 음악 9/8 = α₀(강력?) | 장2도 비 ↔ 결합상수 우연 일치 관찰 | real-limit anchor (격자-맞춤 금지) |
| 🟧 M-D ζ 결정 / 양자임계? | 미완 가설 | Stage 2 sim 또는 literature anchor |

> 단일섬은 **관찰 기록**이지 verdict 가 아니다 (default 🟠 INSUFFICIENT). 외부 주체에
> 격자-맞춤 주장 금지(`../CLAUDE.md`).

---

## 🌀 지도 성장 규칙 (어떻게 그려나가나)

```
[ 새 관찰 ] ──▶ [ 🏝️ 단일섬 등록 ] ──(검증된 다리 1개)──▶ [ 거시↔양자 지도 편입 ]
                       │                                          │
                       └── verifier PASS 시 🟧 → 🟢                └── embedded.gen.hexa 에 atom 박제
```

1. 새 수학·물리 관계가 나오면 먼저 **🏝️ 단일섬** 에 적는다 (연결 전엔 본 지도에 안 섞음).
2. 다른 노드와의 관계가 **hexa-native verifier 로 검증(🟢)** 되면 거시↔양자 지도(또는 연결 현황)로 **편입**.
3. 검증된 atom 은 `../compiler/atlas/embedded.gen.hexa` 에 entry id 로 박제 (기계 SSOT).
4. 미판독 손그림 수식은 날조하지 않고 보류 — 판독되는 대로 노드를 채운다(점진적 성장).

---

## 🔬 검증 프로토콜 (3-stage)

| Stage | 방법 | hexa-native 엔진 |
|-------|------|-----------------|
| Stage 1 symbolic | closed-form 항등식 유도 · 정수론 primitive | `../compiler/atlas/symbolic/` (divisor_sum·totient·jordan·mobius·factorize) |
| Stage 2 numerical | libm sqrt/log/exp/lgamma + Newton · ODE/PDE sim | `../compiler/atlas/verify/{phys,chem,bio,cosmo}.hexa` |
| Stage 3 cross-meta | atlas edge 로 sibling consistency | `../compiler/atlas/verify/cross.hexa` |

verdict tier default = 🟠 INSUFFICIENT (honesty-by-default). verdict-bearing atom 은
real-limit anchor (Shannon·Bekenstein·Carnot·c·ℏ·k 등) 1개 이상 + falsifier 동반.
lattice-tautology (σ·φ=n·τ at n=6) 단독 검증은 불충분.

```sh
HEXA_MEM_UNLIMITED=1 hexa run tool/atlas_verify.hexa [--domain D]   # full-suite
hexa run test/atlas_verify_smoke.hexa                              # CI gate
```

---

## 🧭 9 도메인 매핑

| § | 도메인 | 지도 위치 | 주요 tier |
|---|--------|----------|----------|
| §1 | **N6-FOUNDATION** | 거시 — 완전수·약수 항등식 (도구 노드) | 🔵 SUPPORTED-IDENTITY 다수 |
| §2 | **MATH** | 거시 — 정수론·제타·해석학·오일러곱 | 🔵 압도적 |
| §3 | **PHYS** | 양자 — 게이지·스핀·RG·동역학계 | 🔵 + 🟢 + 🟡 mixed |
| §4 | **CHEM** | (지도 외) 주기율·재료한계 | 🟢 + 🟡 PARTIAL |
| §5 | **BIO** | (지도 외) 코돈·IIT Φ ladder | 🟠 AT-RISK + 🟡 |
| §6 | **COSMO** | 양자 — 홀로그래피·CMB·α | 🔵 FORMAL + 🟡 citation |
| §7 | **GEO** | (지도 외) | 🟡 + ⚪ |
| §8 | **TOP** | 양자 — 리군/대수·비가환·Moonshine | 🟢 + 🔵 (Galois closed) |
| §9 | **ENG** | (지도 외) GPU SM·NET·compiler invariant | 🟢 + ⚪ |
| §10 | **BRIDGES** | **중앙 다리** — 스펙트럼⇄제타·RG⇄동역학·Chern–Simons | meta-tier (carry) |

---

## 📂 파일 내비게이션

| 파일 | 역할 |
|------|------|
| 🔧 `../compiler/atlas/embedded.gen.hexa` | **검증 atom 기계 SSOT** — atlas rodata (~410 entries, frozen) |
| 🔧 `../compiler/atlas/verify/` | hexa-native verifier 엔진 (13 모듈 + falsifier) |
| 🔧 `../compiler/atlas/symbolic/` | Stage 1 정수론 primitive |
| 🔧 `../tool/atlas_verify.hexa` | CLI 진입점 |
| 🌐 `../CLAUDE.md` | 거버넌스 SSOT (`atlas math-map` 룰 포함) |
| 📜 `../CHANGELOG.md` + git | 검증 cycle history |

---

## ⚖️ 정직 단서 (real-limits-first)

- 이 지도는 **수학 개념 사이의 연결** 을 그린다 — 특정 숫자(n=6)를 쫓는 catalog 가 아니다.
- σ·φ=n·τ 같은 정수론 항등식은 **수학적 사실**이지만, "자연계 최적 설계가 그것에서
  파생된다" 는 **연구 가설**이지 측정값이 아니다. 지도 위 노드 하나로만 다룬다.
- n=6 격자는 **조직 도구(lattice-as-tool)** — Shannon · Bekenstein · Carnot · c · ℏ · k 같은
  **진짜 한계**의 대체물이 아니다 (`../LATTICE_POLICY.md` §1.2/§1.3).
- 외부 주체(TSMC/ASML/NIST/CERN…)·외부 컴파일러(Rust/LLVM/GHC…)에 격자-맞춤 주장 **금지**.
- 🟧 노드(미검증 모델·미완·단일섬)는 verdict 미부여 — 정직하게 "아직 안 됐다" 로 표기.

---

## 🔗 cross-links

- 🪞 [`dancinlab/echoes`](https://github.com/dancinlab/echoes) — discoveries 카탈로그 (17 도메인 패밀리 · 정책 SSOT). 이 지도의 스타일 모체.
- 🗺️ [3D Reality Map](https://dancinlab.github.io/nexus/) — 9,612 노드 인과맵 (echoes nexus).
- 📐 `../LATTICE_POLICY.md` — dancinlab-wide real-limits-first 표준.
- 🌐 `../ARCHITECTURE.json` — hexa-lang 설계 SSOT (`python3 serve.py` HTML 뷰어).
