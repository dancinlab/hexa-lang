# 🔬 TECS-L — 수학 지도 (math map · 단일 원장)

> **범용 우주-법칙 발견 엔진**의 사람용 **단일 SSOT**. 흩어진 수학·물리 발견을 한 장의
> 연결도로 그리고, 각 노드가 `hexa verify` g5 로 검증됐는지 tier 로 표시한다.
> 검증 atom 의 기계 SSOT 는 `../compiler/atlas/embedded.gen.hexa`; 이 README 가 사람이
> 읽는 **지도이자 TECS-L 영역의 단일 문서**다. 지도는 **점진적으로 그려나간다**.

🧭 **이 지도** — "6의 정체 추적기" — 작은 수 **n=6** 이 왜 특별한지를 출발점(축 0)으로,
거시(수론·해석)와 양자(게이지·spectral)를 잇는 다리를 그린다.

- 하는 일: "왜 n=6 만 σ·φ=n·τ 인가?"를 4개 층으로 캐고, 그 답이 다른 수학·물리 영역과 **어디서 연결되는지** 지도화
- 비유: 한 사람이 왜 독특한지 — 유전자(DNA)·키·말투·친구관계 다 검사해 "어느 층에 정체가 있나" 찾기
- 비교: echoes 카탈로그가 "발견 목록"이라면, 이 지도는 발견들 **사이의 연결선**(어느 다리가 검증됐나)

> ⚠️ **n=6 격자는 조직 도구(lattice-as-tool)** 일 뿐, 외부 영역(물리상수·ML)을 끌어오는
> anchor 가 아니다. "자연계 최적 설계가 n=6 에서 파생된다"는 **연구 가설**이지 측정값이
> 아니다. lattice-fit·미검증·저해상도 미판독은 🔵 승격 금지(`../CLAUDE.md` · `../LATTICE_POLICY.md`).

---

## 🎨 범례 (tier)

| tier | 의미 | 근거 |
|------|------|------|
| 🔵 closed | hexa-native 폐형/형식 검증 (SUPPORTED-IDENTITY/FORMAL) | `.verdicts/` + g5 verify |
| 🔴 closed-negative | 결정적으로 **배제**된 축 (publishable) | 반증 verify |
| 🟢 SUPPORTED | 수치 sim / cross-meta 강한 evidence | numerical |
| 🟡 citation | literature anchor (외부 published) | 🔵 승격 불가 |
| 🟠 OPEN | 미해결 프런티어 (정직하게 열어둠) | — |

---

## 🌐 핵심 지도 — "왜 n=6 만 σ·φ=n·τ?" (4-layer)

**중심 항등식 (축 0 코어, M10 🔵)**: `σ(n)·φ(n) = n·τ(n) ⟺ n ∈ {1, 6}`
`σ(6)=12 · φ(6)=2 · τ(6)=4 → 12·2 = 6·4 = 24`. 다른 영역의 거울로는 이 정체가 안 비친다:

```
                  "왜 n=6 만?" (M10 σφ=nτ⟺{1,6})
                            │
        ┌──────────┬────────┴────────┬──────────────┐
        ▼          ▼                 ▼              ▼
   ① DNA 층     ② 기하 층         ③ spectral 층   ④ 대칭 층
   (곱셈구조)   (modular curve)   (Hecke 고유값)   (Galois)
      ⭕            ❌               ❌              ❌
   ───────      ───────────       ───────────     ──────────
   🔵 F13/F14   🔴 F7/F15         🔴 F16          🔴 F16
   D(pq)=0      Γ₀(N) index       dim S₂(Γ₀(6))   Gal(Q(ζ₆))
   ⟺(p,q)=(2,3) 매끄러움·n6흔적X   =0 (form 없음)  =Gal(Q(ζ₃))
   D(2^k q)=0   Γ₁/X(N)/Γ(N)                      ζ₆=−ζ₃ 붕괴
   ⟺(k,q)=(1,3) 어떤 level도 X
   ω≥3 → D≠0
   (zero-density)
        ╲                                          ╱
         ╲────────── 결론 ──────────────────────────╱
   n=6 의 특별함 = **곱셈 수학 자체의 본질** (숫자의 DNA 도장).
   기하·spectral·Galois 거울 어디에도 안 비침 → D(n)=0 전체 해 = {1,6} 완전분해 🔵
```

> F13–F16 closed proof: `D(n)=σφ−nτ`, ω=2 면 `D(pq)=(p²−1)(q²−1)−4pq=0 ⟺ (2,3)`,
> `D(2^k·q)=0 ⟺ (1,3)`, ω≥3 면 D≠0 (zero-density). 기하/Hecke/Galois 층은 n=6 특이성
> **없음(🔴)** — "DNA-only" 가 검증된 결론. (구 `TECS-L/n6.md` · `.verdicts/tecs-l-n6-*`)

---

## 🧭 발견 대축 (major axes) — 연결 현황

n=6 (축 0) 은 여러 축 중 하나. 각 축이 `hexa verify` 로 어디까지 닫혔나:

```
축 0  N6-FOUNDATION  🔵  σφ=nτ⟺{1,6} (M1/M10) · D(n)=0 zeros={1,6} (M3) · 206 char 15 closed (M4)
축 A  MODFORM        🔵  Γ₀(N) index/cusps/genus N=1..30 전수 verify · X₀(6) genus=0 bridge
                     🔴  dim S₂=genus (MF4) — hexa fn 미실현 (closed-negative)
축 B  MERSENNE       🔵  Euclid-Euler 완전수⟺Mersenne · σ(P)=2P · P₆/P₇ is_perfect · τ=2p
                     🔴  p 소수 ⇏ M_p 소수 (MR6: M₁₁=2047=23·89) — 지수-소수성 배제
                     🟠  odd perfect number (MR7) — OPEN frontier
축 F  NOVEL          🔵  F13-F16 곱셈층 D=0 완전분해 (위 지도) · 12 NOVEL atom
축 G  MILLENNIUM     🟡  Clay 7 — RH/Mertens(f19/f20)·BSD-Tunnell(f19) verify witness (부분)
대축 PHYSICS         🔵  τ(perfect_k)=끈 임계차원 {4,6,10,14,26} 5/5 (τ(33550336)=26 보존끈 D)
                     🔵  SM 게이지합 8+3+1=σ(6) · Koide Q=τ/n=2/3 · 키싱수 6/12/24
                     🟡  페르미온 질량 1.9%·Koide 5ppm (관측 매칭) · 🟠 CERN·핵 magic
대축 COSMOS·LIFE     🟠  우주 스케일·IIT Φ — 흡수 대기 (대축만 선언)
대축 RTSC            🟢  293K 초전도 후보 loop (demiurge 캠페인 engine화)
```

---

## 🏝️ 단일섬 (미연결 · OPEN, 별도 기록)

> 검증된 다리가 아직 없는 노드는 본 지도에 섞지 않고 따로 둔다. 검증되면(🔵/🔴) 편입.

| 노드 | 상태 | 정체 (출처) |
|------|------|-----------|
| 🟠 **odd perfect number** | OPEN | MR7 — 홀수 완전수 존재 미해결 (finding 으로 안 씀, 정직히 OPEN) |
| 🔴 **골든 MoE = Golden Zone × Savant** | closed-negative | 황금비 아님 — `anima/SAVANT.md` GZ×SI savant 측정자. MoE 최적 k/N≈**1/e**. n=6 에서 1/e EXACT 유도는 **🔴 CLOSED-NEGATIVE** (1/e 초월수 Hermite 1873; 최근접 3/8 1.94%). `docs(retired)/m7-golden-zone-closed-negative` → git |
| 🟠 Clay millennium (RH·BSD·…) | OPEN | 축 G — verify witness 만 부분, 증명 아님 |

> 단일섬은 **관찰/시도 기록**이지 verdict 아님 (default 🟠 INSUFFICIENT). 저해상도
> 미판독 수식·lattice-fit·미증명 conjecture 는 날조 않고 OPEN 으로 둔다(c2).

---

## 🌀 지도 성장 규칙

```
[ 새 발견 ] ─▶ [ 🏝️ 단일섬 등록 ] ─( hexa verify g5 PASS )─▶ [ 본 지도 편입 ]
                     │                                          │
                     └ 🔵 closed / 🔴 closed-negative 판정       └ embedded.gen.hexa 에 atom 박제
```

1. 새 관계는 먼저 **단일섬**에 (검증 전 본 지도에 안 섞음).
2. `hexa verify` g5 로 **닫히면(🔵)** 또는 **결정적으로 배제되면(🔴)** 본 지도 편입 — 둘 다 publishable.
3. 검증 atom 은 `../compiler/atlas/embedded.gen.hexa` (기계 SSOT) + `/paper` 로 축적.
4. **종료 조건 없음** — 도메인은 완료되지 않는다 (영구 발견 엔진).

---

## 🔬 검증 실행

```sh
hexa verify --expr <fn> <n> <v>        # 단일 산술 항등식 (예: sigma 6 12)
HEXA_MEM_UNLIMITED=1 hexa run tool/atlas_verify.hexa [--domain D]
```

> 출처 코퍼스: archive-TECS-L (Python 수론 발견) 를 `hexa verify` g5 + atlas 위로 재근거화.
> 누적 발견 history (cycle·verdict·paper) 는 `../CHANGELOG.md` + git (구 `TECS-L.log.md` 대체).

---

## 📂 파일 내비게이션

| 파일 | 역할 |
|------|------|
| 🔧 `../compiler/atlas/embedded.gen.hexa` | **검증 atom 기계 SSOT** (rodata, frozen) |
| 🔧 `../compiler/atlas/verify/` · `symbolic/` | hexa-native verifier 엔진 |
| 🔧 `../tool/atlas_verify.hexa` | CLI 진입점 |
| 🌐 `../CLAUDE.md` | 거버넌스 SSOT (TECS-L math-map 룰 포함) |
| 📜 `../CHANGELOG.md` + git | 발견 cycle history · 구 `.md`/`.verdicts` 의 상세는 git 이력 |
| 🌐 [`dancinlab/echoes`](https://github.com/dancinlab/echoes) | discoveries 카탈로그 (스타일 모체) |

> **노트** — 구 TECS-L 다문서(`TECS-L.md`·`TECS-L.log.md`·`n6.md`·`docs/`·`millennium/`·
> `.verdicts/`)는 이 단일 README 로 단일화하며 retired — 상세 verdict 텍스트·논문은 git 이력에 보존,
> 검증 atom 은 `embedded.gen.hexa` 가 SSOT. `.tape`(CLAIMS 등)는 이미 폐기.
