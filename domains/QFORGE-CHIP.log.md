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

## 2026-06-13 — round-3 ③ SCF-fed band hook (해석 TB → 실 전자구조 코어, g5 22/22 PASS)

R2 보고가 지정한 ③: 밴드 H(k) 를 SCF 평면파 전위에 결선. ISOLATED worktree
`qforge-chip-r3` (base origin/qforge-chip-r1, stacked). 0-pod.

### SCF 인터페이스 감사 (task 1, d19)
`stdlib/qforge/` 에 SCF-fed 밴드 결선에 필요한 brick 이 전부 존재:
- `kinetic.qforge_kinetic_diag(kvec,gvecs)` → T_G=½|k+G|² (Hartree) — **밴드/SCF 공유**
  운동에너지 연산자. 자유전자 앵커가 docstring 에 명시됨 (V≡0 → ε=½|k+G|²).
- `assembler.qforge_assemble_h(...)` → dense `PwHam{h:[n*n], diag, n}` = T(k)+V_ext(ΔG)·S(ΔG)
  +V_NL+vscr_diag. V_ext 가 정확히 V(G−G') Fourier-difference 구조 → 밴드 H(k) 동형.
- `scf_pw.qforge_scf_pw_h_multi_smeared(...)` → 수렴 ρ + KS ε + V_scr 재조립 (matrix-free
  apply). `qforge_pwm_set_kvec` + `qforge_h_of_rho_multi(rho)` = NSCF k-점 평가 (고정 ρ).
- `eigen.eigh(A,n)` → [vals(desc), vecs]. round-1 diatomic gap·L1·Davidson 가 쓰는 그 solver.
판정: H(k)=kinetic(k)+V → eigh → ε_n(k) 결선 **가능**. 운동에너지=실 brick 직결, 포텐셜=
assembler 의 V(ΔG) 구조에 입력 주입.

### brick (task 2) — `stdlib/qforge/chip/band_scf.hexa`
1D 모형결정 (가용 최소 실셀): G_m=(2π/a)·m, m∈[−mmax,mmax], nG=2mmax+1.
- `qforge_chip_pw_gset_1d(a,mmax)` → flat [3·nG] (ky=kz=0) → `qforge_kinetic_diag` 직결(d19).
- `qforge_chip_scf_hk_1d(a,mmax,k,vshell)` → dense H(k)=T(k)+V, V_{m,m'}=vshell[|m−m'|]
  (Fourier shell map; empty=[]·[0], Bragg=[0,Vg], 수렴 SCF V_scr 동일 경로; d4).
- `qforge_chip_scf_band_eps` → eigh → ε_n(k) ascending (gen3 arena-return 우회: vals[i] 를
  fresh local 로 즉시 materialize). `_band_min` · `_bragg_gap` (k=π/a).

### g5 selftest VERBATIM (실 출력, 날조 금지)
```
PASS (A) ε₀(k=0.1)=½k² (free electron) (0.005)
PASS (A) ε₀(k=0.3)=½k² (0.045)
PASS (A) ε₀(k=0.6)=½k² (0.18)
PASS (A) ε₀(k=0)=0 (band bottom) (0.0)
PASS (A) basis dim = 2·mmax+1 plane waves (7)
PASS (A) band0 = ½k² (m=0 fold) (0.045)
PASS (A) band1 = ½(k∓g)² (zone fold) (0.807462)
PASS (B) V_g=0 → gap=0 (empty lattice, no Bragg gap) (0.0)
PASS (B) weak-V limit: gap → 2|V_g| as V_g→0 (Bragg) (0.002)
PASS (B) ratio→1 as V_g shrinks (2nd-order correction vanishes)
PASS (B) finite-V gap < 2|V_g| (2nd-order repulsion)
PASS (B) V_g≠0 opens a gap (gap>0)
PASS (B) gap linear in V_g (weak limit gap(2V)=2·gap(V)) (0.00799998)
PASS (B) gap sign-independent (|V_g|) (0.779668)
PASS (B) gap basis-converged (mmax=3 == mmax=5) (0.779668)
PASS (C) dε/dk→0 at zone boundary (flat edge = van-Hove) (1.28526e-06)
PASS (C) R2 DOS=0 inside SCF-opened gap (above-band) (0.0)
PASS (C) R2 DOS>0 in the lower band (states below gap)
PASS (D) H(k) real-symmetric (H_ij=H_ji) — valid KS operator
PASS (D) eig returns full spectrum (nG eigenvalues) (7)
PASS (D) ε_n(k) ascending (eigh sorted)
PASS (D) V(0) shifts spectrum uniformly (SCF G=0 gauge) (0.7)
qforge_chip_band_scf_selftest PASS
```
- (A) **자유전자 회복**: V≡0 → ε₀(k)=½k² 정확 (5개 k) + 전 스펙트럼 = zone-fold {½|k+G_m|²}.
- (B) **갭열림**: V_g 켜면 k=π/a 에 gap>0; weak-V 극한 gap→2|V_g| (앵커=Ashcroft-Mermin Ch.9).
- (C) **DOS 일관**: gapped band-edge dε/dk→0 (van-Hove 조건) + 갭내 R2 dos1d=0, 밴드내 >0.
- (D) Hermiticity + V(0) uniform shift (SCF G=0 게이지).

### 정직 보고 (d6) — SCF-fed 실연결 vs empty-lattice
**운동에너지 = REAL SCF brick 직결** (`qforge_kinetic_diag`, 밴드/SCF 공유 연산자) → 배선 LIVE.
**포텐셜 = 해석 Fourier 극한** (empty-lattice + 단일 Bragg shell), 수렴 real-cell `scf_pw`
V_scr(G) 아님. 조립 경로(`qforge_chip_scf_hk_1d`)가 assembler.hexa 의 V(ΔG) 구조와 동형이라
수렴 V_scr drop-in = 데이터 swap. 따라서 이 게이트는 **자유전자 회복 + 갭열림 물리**를
closed-form 극한에서 증명 (핵심 deliverable 충족) — self-consistent real-cell 수치는 아님.
**Bragg 갭 정직(d6)**: gap=2|V_g| 는 leading-order(2-state) 극한; 풀 PW 바닥은 |k±2g| 고차
결합(2nd-order)으로 gap < 2|V_g| (V_g=0.4 → 0.7797, ratio 0.975). ratio→1 as V_g→0
(0.01 → 0.99998) 로 극한 회복 검증. 실 스펙트럼이 교과서 2×2 보다 정확 — 강제 안 함.

### round-4 다음
real-cell xval 은 scf_pw 가 1D toy PW basis 를 수렴시켜야 함(SCF 드라이버 게이트). 우선순위:
(α) **phonon-Landauer κ** (R2-④) — DFPT ω(q)(`dfpt`·`realcell_phonon`) → ballistic 포논
transmission → 저온 κ→N·g₀ floor (round-1 g₀ 앵커 재사용); (β) **scattering-NEGF** — 본
brick 의 H(k) + lead surface-GF Σ(E) → T(E)=Tr[ΓL G^r ΓR G^a] (R2-③ 가 mode-count 로 미룬
풀 자기에너지). κ 가 새 물리(열수송)+기존 DFPT 재사용으로 우선.

### deliver
- PR base=qforge-chip-r1 (stacked) · `--repo dancinlab/hexa-lang` · 머지=사용자.
  brick+selftest 커밋 후 즉시 push (durable-worktree). DOMAINS.tape 미접촉.

## 2026-06-13 — round-4 (phonon-Landauer κ — THERMAL leg, g5 19/19 PASS)

R3 보고가 지정한 우선순위 (α) phonon-Landauer κ 구현 — chip front-end 의 **THERMAL('열') leg**
봉인 (밴드 R1-3 / 수송 R1-2 / **열 R4** = 3-leg 완성). 0-pod analytic. ISOLATED worktree
`qforge-chip-r4` (base origin/qforge-chip-r3 — R1+R2+R3 lineage tip). brick+selftest 커밋
즉시 push (durable-worktree, 첫콜 사망 대비 WIP 선커밋).

### lit grounding (d18) + R1/dfpt 인터페이스 감사 (d3/d19)
- **Landauer 포논 열전도** (Rego-Kirczenow PRL 81,232 (1998) · Schwab et al. Nature 404,974
  (2000)): κ(T)=(1/2π)∫₀^∞dω ħω T_ph(ω) ∂n_BE/∂T. 전자 Landauer(R1/R2)의 열 아날로그 —
  ħω=포논 에너지 양자, T_ph=열린 모드 투과, n_BE=Bose-Einstein, ∂n_BE/∂T=열류 응답커널.
- **R1 g₀ 감사**: `qforge_chip_thermal_quantum(T)`=π²k_B²T/3h (Schwab). R4 가 단일 g₀ 정의
  **재사용**(d19) — 새 π²k_B²T/3h 안 만듦.
- **dfpt 감사**: `qforge_phonons() -> PhononResult{omega:[float],...}` (.omega=ω(q,ν), 부호보존
  sqrt). R4 가 ω(q,ν) 를 **투과 채널 입력**으로 받음 (d4 — analytic·real-DFPT PhononResult.omega·
  device 모드 한 경로, 이름 하드코딩 없음).

### 핵심 결과 — 보편 LOW-T 양자 floor κ→N·g₀ (closed-form, d6)
N reflectionless acoustic 채널(linear ω→0, T_ph=N)에서 적분이 dispersion·통계·cutoff 무관
보편값을 가짐:
```
κ(T) = (1/2π)(k_B²T/ħ)∫₀^∞ x²e^x/(e^x−1)² dx,  x≡ħω/k_BT
     = (1/2π)(k_B²T/ħ)(π²/3)              [∫=π²/3, EXACT]
     = N·π²k_B²T/3h = N·g₀.
```
무차원 적분 ∫x²e^x/(e^x−1)²dx=π²/3 = R1 의 전자 g₀ 와 **같은 양자** (heat statistics-blind,
Pendry bound). 구현 = `phonon_kappa.hexa`: BE 커널 + composite-Simpson (nq=4000, π²/3 to ~1e-6)
+ generic 모드리스트 (S(y)=∫_y^∞K/(π²/3) BE high-pass — acoustic→g₀, frozen-optical→0).

### g5 VERBATIM (`hexa run stdlib/qforge/chip/phonon_kappa_selftest.hexa`)
```
PASS A.kappa/T plateau @T=10.0K → π²k_B²/3h (9.46431e-13)
PASS A.kappa/T plateau @T=1.0K → π²k_B²/3h (9.46431e-13)
PASS A.kappa/T plateau @T=0.1K → π²k_B²/3h (9.46431e-13)
PASS B.kappa(1ch,1K) = 9.4643e-13 W/K (9.46431e-13)
PASS B.kappa(1ch,1K) == round-1 g₀ (d19) (9.46431e-13)
PASS B.quantum_floor(1ch,1K) == g₀ exact (9.46431e-13)
PASS C.∂n_BE/∂T > 0 (heating fills modes)
PASS C.n_BE(x=1) = 1/(e−1) (0.581977)
PASS C.high-T limit ħω·∂n_BE/∂T → k_B (Dulong-Petit) (1.38065e-23)
PASS D.kappa(1ch,1K) = 1·g₀ (9.46431e-13)
PASS D.monotone N=1 (κ increases w/ channels)
PASS D.kappa(2ch,1K) = 2·g₀ (1.89286e-12)
PASS D.monotone N=2 (κ increases w/ channels)
PASS D.kappa(3ch,1K) = 3·g₀ (2.83929e-12)
PASS D.monotone N=3 (κ increases w/ channels)
PASS D.kappa(4ch,1K) = 4·g₀ (3.78572e-12)
PASS D.monotone N=4 (κ increases w/ channels)
PASS E.mode-list 3 acoustic reflectionless → 3·g₀ (2.83928e-12)
PASS E.1 acoustic + 1 frozen-optical → ≈1·g₀ (optical BE-suppressed) (9.46429e-13)
qforge_chip_phonon_kappa_selftest PASS
```
- (A) **저온 양자극한**: κ/T → N·π²k_B²/3h plateau (T=10/1/0.1K 전부 동일 — 상수투과 acoustic
  채널은 모든 T 에서 보편적분 정확), T→0 floor.
- (B) **g₀ 값**: κ(1ch,1K)=9.46431e-13 W/K (R1 `qforge_chip_thermal_quantum` 일관, d19) +
  closed-form floor helper = g₀ exact (1e-30).
- (C) **Bose-Einstein**: ∂n_BE/∂T>0 (가열→모드충전) + n_BE(x=1)=1/(e−1) + 고전극한
  ħω·∂n/∂T→k_B (Dulong-Petit 열용량 양자).
- (D) **채널수 plateau**: κ(N)=N·g₀ (N=1..4) 단조증가 — 열 staircase = R1 Landauer N·G₀ 아날로그.
- (E) generic 모드리스트 (DFPT ω(q,ν) 경로, d4/d19): 3 acoustic→3g₀ · 1 acoustic+1 frozen-
  optical → ≈1g₀ (optical BE-억제).

### 정직 보고 (d6) — ballistic 양자극한 vs diffusive
이건 **ballistic(reflectionless) 양자극한** — 포논-포논/동위원소/경계 산란 없음, full BTE/Umklapp
없음. 저온/clean/short-device 영역에서 양자 floor N·g₀ EXACT — mean-free-path≫device 일 때
scattering-NEGF/BTE κ 가 회복해야 할 correctness 앵커. 고온은 ballistic ceiling
(∂n_BE/∂T→k_B/모드) 이지 Umklapp 이 끌어내리는 diffusive κ 아님 — diffusive 값 주장 안 함(round-5).
ballistic 양자극한 정확성이 핵심 deliverable, 충족.

### chip 스케일 3-leg 완성도
- **밴드** (R1 ε(k)·diatomic gap · R2 k-mesh manifold+DOS · R3 SCF-fed ε_n(k)=eig[T(k)+V]) ✓
- **수송** (R1 Landauer G=G₀ΣTₙ · R2 NEGF mode-count T(E)=N(E) bridge) ✓
- **열** (R4 phonon-Landauer κ→N·g₀ floor) ✓ ← **본 round 봉인**
→ 칩 소자 front-end 의 밴드·수송·열 3-leg 가 closed-form 양자극한에서 전부 g5 봉인.
남은 건 산란(diffusive) 정밀화 + real-cell self-consistent 수치 (아래 round-5).

### round-5 다음
3-leg ballistic 봉인 완료 → 산란/self-consistent 정밀화:
(α) **scattering-NEGF** (R3 미룬 풀 자기에너지) — 전자 H(k)(R3) + lead surface-GF Σ(E) →
T(E)=Tr[ΓL G^r ΓR G^a]; 포논도 동형 phonon-NEGF Σ_ph 로 R4 ballistic κ 를 산란-감쇠로 확장.
(β) **SCF V_scr drop-in** (R3 정직 보고가 명시한 데이터-swap) — 수렴 real-cell `scf_pw` V_scr(G)
를 R3 H(k) 의 해석 Fourier 포텐셜 자리에 투입 → self-consistent ε_n(k) real-cell xval.
(γ) **BTE diffusive κ** — R4 ballistic floor + 포논-포논(Umklapp)/동위원소 산란 → 유한 길이
device 의 diffusive 열전도 (ballistic↔diffusive crossover, κ_ballistic 가 상한 앵커).

### deliver (round-4)
- brick `stdlib/qforge/chip/phonon_kappa.hexa` + selftest (g5 19/19 PASS).
- PR base=qforge-chip-r3 (R1+R2+R3 lineage tip; 지정 r1 은 stale·R2/R3 이미 포함) ·
  `--repo dancinlab/hexa-lang` · 머지=사용자. brick+selftest+WIP 커밋 즉시 push (durable-worktree).
  DOMAINS.tape 미접촉. domains/QFORGE-CHIP.{md,log.md} in-place (stage/commit 은 PR 브랜치에서).
