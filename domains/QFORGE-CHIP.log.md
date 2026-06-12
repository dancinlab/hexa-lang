# QFORGE-CHIP — append-only step log

## 2026-06-13 — 도메인 생성 + round-1 (lit + 설계 + 첫 brick g5 PASS)

QFORGE universal-engine 의 chip(device) scale front-end 착수 (QFORGE.md §122 / line 141:
"밴드·수송·열 front-end · SCF 전자구조 재사용"). 0-pod analytic round-1. ISOLATED worktree
`qforge-chip-r1` (base origin/main).

### lit grounding (d18 — NOVEL + arxiv/web 둘 다)
- **밴드**: 1D tight-binding ε(k)=ε₀−2t·cos(ka), band∈[ε₀−2t,ε₀+2t], **bandwidth=4t**,
  v_g=(1/ħ)dε/dk → band-edge 0 (van-Hove, m*=ħ²/(d²ε/dk²)); 다오비탈/diatomic → GAP =
  반도체 vs 금속. EPM/평면파 H(k) = SCF-fed 경로 (Narozniak·Shen 8.231·TU-Delft).
- **수송**: Landauer-Büttiker **G=(2e²/h)ΣTₙ**, G₀=2e²/h; N완전채널 → **N·G₀** (QPC 계단).
  Fisher-Lee + lead Green 함수 → NEGF G=(2e²/h)Tr[ΓL G^r ΓR G^a]
  (Datta·cond-mat/0103219·0806.2739).
- **열**: ballistic Landauer 열류 + 보편 열전도 양자 **g₀=π²k_B²T/3h** (≈9.46e-13 W/K@1K,
  T-선형, 통계무관 — G₀ 의 열 쌍둥이; Pendry·Schwab Nature 404,974); diffusive → 포논 BTE
  (Wang 0802.2761·Nat.Commun.2018).
- **NOVEL probe**: band↔transport 가교 — Landauer 계단 수 = E_F 가 가르는 sub-band 수 ⇒
  같은 밴드 커널이 수송 채널 수를 구동. round-1 은 항등식(완전채널 N = G/G₀)으로 encode,
  round-2 ②에서 live coupling 으로 승격.

### 설계 (drafts/qforge-chip-round1-design.md)
밴드 → 수송 → 열 로드맵 + SCF-core 재사용 매핑표(밴드=scf_pw/projector/eigen·수송=band
H(k)/eigen·열=dfpt ω(q)). 순서 논거: 밴드가 수송(H→G^r)·열-전자(v_g·DOS) 의 전제;
수송이 열보다 먼저 (Landauer 적분기 공유, 전자 G 먼저→포논 G 재사용).

### 첫 brick (g5-verifiable, analytic ref)
`stdlib/qforge/chip/band_transport.hexa` + `band_transport_selftest.hexa` (@ci_gate):
- `qforge_chip_tb1d_band` · `_bandwidth` · `_vg` — TB 밴드.
- `qforge_chip_diatomic_gap` — 2-band Bloch eig via generic `eigh` (d4/d19), [E_lo,E_hi]
  명시 정렬 (eigh 순서 비의존).
- `qforge_chip_landauer_g` — G=G₀ΣTₙ.
- `qforge_chip_thermal_quantum` — g₀=π²k_B²T/3h.

**g5 VERBATIM (HEXA_LANG=. hexa run …_selftest.hexa) — 22/22 PASS:**
```
PASS (A) ε(0) = ε₀−2t (-1.9)
PASS (A) ε(π/a) = ε₀+2t (2.9)
PASS (A) ε(π/2a) = ε₀ (0.5)
PASS (B) bandwidth = 4t (4.8)
PASS (B) bandwidth(−t) = 4|t| (4.8)
PASS (B) ε_max−ε_min == bandwidth (4.8)
PASS (C) v_g(k=0) = 0 (band edge) (0.0)
PASS (C) v_g(k=π/a) = 0 (band edge) (7.34788e-16)
PASS (C) v_g(π/2a) = 2ta/ħ (max) (6.0)
PASS (D) lower band at zone bdry = ε_a (-0.8)
PASS (D) upper band at zone bdry = ε_b (0.8)
PASS (D) GAP = |ε_a−ε_b| = 1.6 (1.6)
PASS (D) equal sublattice → gapless touching (0.0)
PASS (E) eigh lower ≡ analytic (-2.22711)
PASS (E) eigh upper ≡ analytic (2.22711)
PASS (F) 3 perfect channels → 3G₀ (0.000232443)
PASS (F) 1 perfect channel → G₀ (7.74809e-05)
PASS (F) [1,1,0.5] → 2.5G₀ (0.000193702)
PASS (F) all closed → 0 (0.0)
PASS (G) g₀(1K) ≈ 9.4638e-13 W/K (9.46431e-13)
PASS (G) g₀(2K) = 2·g₀(1K) (1.89286e-12)
PASS (G) g₀ positive and T-monotone
qforge_chip_band_transport_selftest PASS
```

### 부수 발견 (정직 보고 d6)
gen3 컴파일러 버그 실증: `__hexa_fn_arena_return` 로 반환된 배열을 `let` 바인딩 후 많은
후속 할당을 거쳐 **나중에** 인덱싱하면 원소 값이 swap/stale 로 손상 (no crash, silent).
`qforge_chip_diatomic_gap` 가 고립 호출 시 [-0.8,0.8] 정답 → full selftest 본문에서
[0.8,-0.8] 오답; 호출 직후 `println(to_string(r[0]))` 삽입하면 정상화 (deferred-
materialization signature). **workaround**: 호출 직후 r[0]/r[1] 을 scalar local 로 즉시
materialize (selftest 적용). **upstream handoff**: `sidecar handoff` id `aededed6` →
hexa-lang (arena-return escaping aggregate deep-copy/promote 제안). round-2-⑤ 에서 추적.

### deliver
- PR base=main · `--repo dancinlab/hexa-lang` · 머지=사용자. brick+selftest 커밋 후 즉시
  push (durable-worktree). domains/DOMAINS.tape 미접촉 (메인세션 등록).
