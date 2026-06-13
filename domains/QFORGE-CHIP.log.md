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

## 2026-06-13 — round-9 β (multi-orbital / multi-band H(k), g5 34/34 PASS)

R8 보고가 지정한 (β) 축 = single-band → **multi-orbital band**. R1/R3 의 밴드 leg 는 site 당
궤도 1개(단일 평면파/단일 TB band)였다 — R9 는 site 당 n_orb 궤도로 승격해 H(k) 를
**n_orb×n_orb 행렬**로 만들고 eig 로 다밴드 ε_n(k) 를 얻는다. 0-pod analytic. ISOLATED worktree
`qforge-chip-r9-multiorbital` (base origin/qforge-chip-r8-bte — R1-R8 lineage tip; r3 가 그
조상이라 전 lineage 보존). brick+selftest WIP 선커밋 즉시 push (durable-worktree — 첫콜 사망/
디스크-ENOSPC 대비; 실제로 셀프테스트 중 호스트 디스크 full 발생, push 된 커밋만 생존 → 복구 후 재실행).

### R3 band H(k) 감사 (d3/d19)
- `band_scf.hexa`: ε_n(k)=eig[H(k)], H(k)=T(k)+V — **single-band per G**. 평면파 G 마다 1채널,
  궤도-resolved 구조 없음. eig = `stdlib/alloc/math/eigen.eigh(A,n)` → [vals(desc), vecs].
  V = vshell[|ΔG|] Fourier map (d4 데이터). → R9 가 재사용: **같은 eigh**, 같은 dense-flat 행렬
  규약, 같은 gen3 arena-return 가드(스칼라 즉시 materialise) 패턴.
- multi-orbital 승격 = block 구조: H_{αβ}(k), α,β 궤도. real-space hopping t_{αβ}(R) → Bloch
  H_{αβ}(k)=onsite[α]δ_{αβ}+Σ_R t_{αβ}(R)cos(k·R) (real basis, e^{ikR}+e^{-ikR}).

### brick `stdlib/qforge/chip/band_multiorbital.hexa`
- `qforge_chip_mo_hk(norb,onsite,hops,k,a)` → dense H(k) flat (norb²). onsite 대각 + hop
  {α,β,dx,t} 마다 t·cos(k·dx·a) 를 (α,β)·(β,α) 에 Hermitian 추가.
- `qforge_chip_mo_bands` → eigh → n_orb 밴드 ascending (vals desc reverse, 스칼라 즉시 복사).
- `qforge_chip_mo_effmass` → m*=ħ²/(d²ε/dk²) FD 2차미분 (band-edge curvature → carrier inertia).
- `qforge_chip_mo_two_band(Ea,Eb,V)` → [ε−,ε+]=½(Ea+Eb)±√((½ΔE)²+V²) 닫힌형.
- `qforge_chip_mo_gap_scan(...,nk)` → [gap, kVBM, kCBM, direct]; VBM=valence(band0) max,
  CBM=conduction(band last) min; direct=1 iff k_VBM==k_CBM (mesh tol).
- `qforge_chip_mo_valley_count(...,nk)` → 전 BZ [−π/a,π/a) 전도밴드 strict local minima
  (주기링; ±π/a 경계 1점 fold). min@Γ→1 · min@경계→1 · 이중우물 ±k₀→2.
- `qforge_chip_sk_hop_ss/sp/pp` → Slater-Koster two-centre (ssσ · spσ dir-cosine sign · ppσ
  on-axis l=1; ppπ 가중 0). 궤도/hopping = 데이터 → 실 material = OrbitalModel swap (d4).
- d19 재사용: `eigh` (R1 diatomic gap·R3 PW H(k)·L1·Davidson 공유). d4: norb/hop 무관 단일 builder.

### g5 VERBATIM (34/34 PASS)
```
PASS (A) dim H(k) = norb²=4 (2-orbital) (4)
PASS (A) #bands = norb=2 @k=π/3a (2)
PASS (A) band0(k=0)=Es−1=−2 (s-like) (-2.0)
PASS (A) band1(k=0)=Ep−0.5=1.5 (p-like) (1.5)
PASS (A) dim H(k)=norb²=9 (3-orbital) (9)
PASS (A) #bands=norb=3 (3)
PASS (A) norb=1 → 1 band (R1/R3 limit) (1)
PASS (A) norb=1 band(k=0)=ε₀−2t=0.5−2 (-1.5)
PASS (B) m*=ħ²/(2 t a²) @band bottom (t=0.5) (0.0625)
PASS (B) flatter band (t→t/2) → 2× heavier m* (0.125)
PASS (B) m*(flat) > m*(sharp) (small t = heavy)
PASS (B) band-top curvature<0 → m*<0 (hole)
PASS (B) |m*(top)|=|m*(bottom)| (symmetric cosine) (0.0625)
PASS (C) DIRECT model: k_VBM ≈ k_CBM (both at Γ)
PASS (C) DIRECT k_VBM = 0 (Γ) (0.0)
PASS (C) DIRECT k_CBM = 0 (Γ) (0.0)
PASS (C) DIRECT gap ≥ 0
PASS (C) DIRECT gap = Eg−2 = 1 (1.0)
PASS (C) INDIRECT model: k_VBM ≠ k_CBM
PASS (C) INDIRECT k_VBM = 0 (Γ) (0.0)
PASS (C) INDIRECT k_CBM = π/a (zone boundary) (0.785398)
PASS (C) INDIRECT gap ≥ 0
PASS (C) INDIRECT gap = Eg−2 = 1 (1.0)
PASS (D) eig ε− = ½(Ea+Eb)−√((½ΔE)²+V²) (0.579063)
PASS (D) eig ε+ = ½(Ea+Eb)+√((½ΔE)²+V²) (4.42094)
PASS (D) ε− closed value = 2.5−√3.69 (0.579063)
PASS (D) ε+ closed value = 2.5+√3.69 (4.42094)
PASS (D) degenerate Ea=Eb → gap = 2|V| = 1.4 (1.4)
PASS (D) H(k) Hermitian: H_01 == H_10 (1.2)
PASS (D) H(k) Hermitian w/ k-dep hop: H_01==H_10 (0.810872)
PASS (E) single-well conduction band (min Γ) → 1 valley (1)
PASS (E) boundary-min conduction band (±π/a equiv) → 1 valley (1)
PASS (E) double-well conduction band → 2 valleys (±k₀ pair) (2)
qforge_chip_band_multiorbital_selftest PASS
```
- (A) **다밴드 차원**: H(k)=norb² flat, eig→정확히 norb 밴드 (2/3-orbital + norb=1 single-band
  극한 = R1/R3). 단일 밴드 → 다밴드 구조 봉인.
- (B) **유효질량**: m*=ħ²/(d²ε/dk²) band-edge FD == 닫힌형 ħ²/(2ta²) (cosine band, Ashcroft-
  Mermin Ch.12); flat band(t→t/2)→2× heavy m*∝1/t; band-top curvature<0→m*<0 (hole, |m*| 대칭).
- (C) **직접/간접갭**: VBM/CBM k-위치 비교 → DIRECT(둘다 Γ) vs INDIRECT(CBM@π/a) 판별, gap≥0,
  gap=Eg−2=1 두 모델 동일 (eig 에서 읽음, per-model branch 없음·d4).
- (D) **2-band 닫힌형**: 2×2 eig == Wolfsberg ½(Ea+Eb)±√((½ΔE)²+V²) (1e-9), 닫힌값 2.5±√3.69
  (1e-12), degenerate Ea=Eb→gap=2|V|=1.4 avoided-crossing; Hermiticity H_01==H_10 (k-dep hop 포함).
- (E) **valley count**: 전 BZ minima — single-well→1 · boundary(±π/a equiv)→1 · double-well ±k₀→2.

### 정직 보고 (d6) — Slater-Koster/2-band MODEL, 실 Si/Ge fit 아님
hopping 은 **Slater-Koster / generic 2-band 모델** 파라미터다 — 경험적 ss/sp 표·spin-orbit·d-궤도
없는 fitted Si/Ge 파라미터화가 아니다. 이 라운드의 deliverable = **다밴드 행렬 H(k) 구조 +
유효질량(curvature) + 직접/간접 갭 판별 + valley 다중도 + 2-band 닫힌형** — 전부 유도가능
해석 ref (cosine-band 곡률·two-level secular). 실 material 파라미터화는 같은 OrbitalModel
(onsite[] + Hop{α,β,dx,t}[]) 로의 **데이터 swap** 이지 코드 경로가 아니다 (d4). 날조 없음.

### chip 스케일 밴드 leg 상태 — 실밴드 구조 봉인
- **밴드** leg: R1 ε(k)·diatomic gap · R2 k-mesh manifold+DOS · R3 single-band SCF-fed
  ε_n(k)=eig[T(k)+V] · **R9 multi-orbital n_orb-band H(k) + m*·직접/간접·valley** ✓ ← 본 round 봉인.
  → single-band 에서 **다밴드(실 반도체 특징: 다궤도·유효질량·간접갭·valley)** 구조까지 도달.
- chip front-end **밴드·수송·열 3-leg + 다밴드 구조** = closed-form 양자/해석 극한에서 g5 봉인.
- **chip depletion 판정**: 아직 NOT depleted. 다밴드 구조는 봉인됐으나 (1) phonon-NEGF/BTE 산란
  (R10 후보), (2) p-d 혼성 실 파라미터화 + SCF V_scr drop-in(R3 정직보고 데이터-swap),
  (3) verify-adapter(chip=TCAD) 표준화, (4) NEXUS edge 등록 미해결 → 도메인 open.

### round-10 다음
다밴드 봉인 → 산란/실파라미터 정밀화:
(α) **phonon-NEGF / Callaway BTE** — R4 ballistic κ + R8 RTA-BTE 에 phonon-NEGF Σ_ph(ω) 또는
  Callaway 모델(normal+Umklapp 분리, τ_N 모멘텀보존 보정)로 ballistic↔diffusive crossover
  정밀화 (저온 floor N·g₀ = 상한 앵커). ← 본 보고 우선 지정.
(β) **p-d 혼성 + SCF V_scr drop-in** — R9 OrbitalModel 에 d-궤도(ddσ/ddπ/ddδ) + R3 가 미룬
  수렴 real-cell scf_pw V_scr(G) 데이터 투입 → self-consistent multi-band ε_n(k).
(γ) **verify-adapter(chip=TCAD)** — 밴드갭·m*·직접/간접·valley·κ 를 측정/TCAD ref 표준화.

### deliver (round-9)
- brick `stdlib/qforge/chip/band_multiorbital.hexa` + selftest (g5 34/34 PASS).
- PR base=qforge-chip-r8-bte (R1-R8 lineage tip; r3 가 조상이라 지정 base 의 전 lineage 보존) ·
  `--repo dancinlab/hexa-lang` · 머지=사용자. WIP 커밋 즉시 push (durable-worktree — 호스트
  디스크 ENOSPC 도중 발생, push 된 커밋만 생존해 복구). DOMAINS.tape 미접촉.
  domains/QFORGE-CHIP.{md,log.md} in-place.

## 2026-06-13 — round-10 (Callaway BTE — N/U-separated phonon scattering, ballistic↔diffusive crossover)

R9 multi-orbital H(k) 봉인 후 산란 정밀화 lane(α) 진입. R4 ballistic κ(N·g₀) + R8 RTA-BTE κ
(Matthiessen Umklapp/isotope/boundary) 위에 **Callaway 모델**(Callaway, Phys Rev 113, 1046
(1959)) 로 ballistic↔diffusive crossover 를 정밀화. 0-pod pure-stdlib + verify. ISOLATED
worktree `qforge-chip-r10-callaway` (base origin/qforge-chip-r3 — R5-R10 lineage 보존).

### 핵심 — Normal/Umklapp 분리 + β-보정 (RTA 의 N over-damp 결함 복원)
RTA-BTE(R8)의 알려진 결함: **Normal(N) 3-phonon** 과정(모멘텀 보존)을 단순 저항처럼 over-damp
한다 — 실제로 N 은 crystal momentum 을 **재분배**할 뿐 heat flux 를 직접 relax 하지 않는다. 그래서
고순도/저온(N 지배) 결정의 κ 를 과소평가한다. Callaway 는 N 과 resistive(R=Umklapp+isotope+
boundary)를 **분리**하고 β-보정항으로 N 이 재분배한 모멘텀을 복원한다. Debye-적분형:
- K(x)=x⁴eˣ/(eˣ−1)² (Debye κ integrand — R4/R8 conductance kernel 의 x² 가 아닌 **x⁴**: Debye
  DOS g(ω)∝ω² × v² weighting 이 ∫dω→∫dx 에서 x² 추가; Bose factor eˣ/(eˣ−1)² 는 동일·d19).
- κ_RTA  = pref ∫₀^{Θ/T} τ_c K dx,  1/τ_c = 1/τ_N + 1/τ_R  (N·R Matthiessen).
- κ_corr = pref [∫(τ_c/τ_N)K]² / [∫(τ_c/(τ_N τ_R))K],  pref=(k_B/2π²v)(k_BT/ħ)³.
- κ_Callaway = κ_RTA + κ_corr.
τ_U/τ_iso/τ_bd/Matthiessen = **R8 bte_kappa primitive 재사용**(d19, 재유도 없음); τ_N 은 채널 하나
더(d4 — Matthiessen 이 generic 하게 합산). Simpson 적분 = R4 quadrature 스킴 재사용(d19).

### g5 VERBATIM (19/19 PASS · LLM self-judge 없음)
```
PASS (a) τ_N→∞: κ_Callaway → κ_RTA(τ_R) exact [round-8 baseline] (419.12)
PASS (a) τ_N→∞: β-correction κ_corr → 0 (vanishes vs κ_RTA scale)
PASS (a) κ_RTA part == round-8 RTA Debye κ (τ_c→τ_R reduction) (419.12)
PASS (b) low-T pure-N κ_Callaway BOUNDED by boundary ballistic ceiling
PASS (b) κ_Callaway/κ_ceiling ∈ (0,1] (finite, no κ→∞)
    [b] low-T(15K) pure-N κ_Callaway=5.50398  ceiling κ_ball=5.50398  ratio=1.0 (=1: N is flux-NEUTRAL, β-corr restores boundary κ)
PASS (b) +Umklapp: κ_Callaway STRICTLY below ceiling (non-trivial bound)
    [b] round-4 ballistic N·g₀(1ch,15K)=1.41965e-11 W/K (Landauer floor anchor)
PASS (c) high-T κ(2T)/κ(T) → 1/2 (Umklapp κ∝1/T, Peierls) (0.493984)
    [c] high-T κ(6000.0K)=11.2102  κ(2T)=5.53765  ratio=0.493984 (→1/2)
PASS (c) low-T κ(2T)/κ(T) → 8 (=2³, Debye boundary plateau κ∝T³) (8)
    [c] low-T κ(4.0K)=0.104372  κ(8.0K)=0.834974  ratio=8 (→8=2³)
PASS (c) β-correction LOAD-BEARING: κ_full > κ_RTA-only (N-dominated)
    [c] N-dominated κ_full=5.47858  κ_RTA-only=2.67202e-08  κ_corr=5.47858 (>0, load-bearing)
PASS (d) round-8 τ_bd=F·L/v unchanged (2e-10)
PASS (d) round-8 isotope ω⁴ ratio(2ω/ω)=16 unchanged (16.0)
PASS (d) round-8 Umklapp ω² ratio(2ω/ω)=4 unchanged (4.0)
PASS (d) round-8 Matthiessen 1/τ=Σ1/τ_i unchanged (5.22903e+09)
PASS (d) round-4 g₀(1ch,1K)=9.46431e-13 W/K unchanged (9.46431e-13)
qforge_chip_callaway_bte_selftest PASS
```
regression VERBATIM:
```
qforge_chip_phonon_kappa_selftest PASS   (R4 ballistic g₀)
qforge_chip_bte_kappa_selftest PASS      (R8 RTA-BTE)
```

### 저온 κ vs N·g₀ ceiling + 두 T-극한 멱법칙
- 저온(15K) pure-N κ_Callaway = **5.50398 W·m⁻¹·K⁻¹** = boundary-limited ballistic ceiling
  (ratio=1.0). 이건 Callaway 의 **시그니처 결과**: pure-N 은 flux 를 relax 하지 않으므로(flux-
  neutral) boundary+N 만 있으면 κ 는 N 세기와 무관하게 boundary-limited ceiling 과 정확히 같다 —
  β-보정이 RTA 가 부당하게 제거할 모멘텀을 정확히 복원. R4 Landauer N·g₀(1ch,15K)=1.41965e-11 W/K
  은 동일 thermal-leg 의 ballistic floor 앵커(per-channel 양자; Debye boundary ceiling 과 diffusive
  bridge·d19). +Umklapp 시 κ 는 ceiling 보다 STRICTLY 아래(non-trivial bound).
- **고온 극한**(T≫Θ_D=645, T=6000K): κ∝**1/T** — κ(2T)/κ(T)=0.4940→1/2 (Peierls–Eucken;
  1/τ_U∝ω²T 포화 → τ_R∝1/T).
- **저온 극한**(T≪Θ_D, T=4→8K, boundary plateau): κ∝**T³** — κ(2T)/κ(T)=8.000=2³ EXACT
  (Debye prefactor∝T³, ∫K 포화, τ→τ_bd const). 두 극한이 닫힌형 Debye-적분 점근과 일치.

### SEALED vs OPEN (정직 — 모델계수 caveat)
- **SEALED**: Callaway N/U-분리 crossover **구조** — (a) RTA 회복(τ_N→∞ ⇒ R8 baseline EXACT),
  (b) ballistic ceiling boundedness(발산 X), (c) T³–1/T 극한 + β-보정 load-bearing, (d) R4/R8 회귀.
  전부 유도가능 closed-form 극한·항등식에 앵커(d6). g5 19/19 + 회귀 2/2 PASS.
- **OPEN / HONEST caveat (d6)**: τ_N/τ_U = 표준 Callaway 멱법칙 **모델 계수**(1/τ_N=B_N ω²T³ ·
  1/τ_U=B_U ω²T·exp(−Θ/3T)) — first-principles ab-initio el-ph 아님(그건 QE/QFORGE-materials
  DFPT lane). deliverable = N/U-분리 crossover **구조** + 올바른 극한; 실 Si/Ge κ(T) **fit 곡선은
  주장하지 않음**(published 계수 + 인용 없이는). 실 material = 같은 brick 에 (B_N,B_U,a,b,α,Θ_D,v)
  데이터 swap(d4) 이지 코드 경로 아님. 날조 없음.

### chip depletion 판정 — 여전히 NOT depleted (도메인 open)
열(thermal) leg 은 R4(ballistic floor) → R8(RTA diffusive) → **R10(Callaway N/U crossover)** 으로
ballistic↔diffusive 전 구간을 닫음. 그러나 미해결 frontier:
- (1) **p-d 혼성 실 파라미터화** — R9 OrbitalModel 에 d-궤도(ddσ/ddπ/ddδ) + R3 가 미룬 수렴 real-cell
  scf_pw V_scr(G) 데이터 투입 → self-consistent multi-band ε_n(k) (R3/R9 정직보고 데이터-swap).
- (2) **verify-adapter (chip=TCAD)** — 밴드갭/m*/직접·간접/valley/κ 를 측정·TCAD ref 로 표준화.
- (3) **NEXUS edge** — QFORGE-CHIP → {소자 도메인} 재사용 그래프 등록 (materials c7 패턴).
- (4) Callaway 계수 published-fit 실material 데이터-swap(Si/Ge·Morelli 2002 계수) — 0-pod, 데이터만.

### round-11 다음 — named
(α) **verify-adapter(chip=TCAD)** ← 우선 지정. 밴드갭·m*·직접/간접·valley·κ(Callaway) 를 측정/
  TCAD ref 표준화 → chip 전 leg 의 verify-adapter 일반화 축 닫기 (verdict 표준화 = depletion 게이트).
(β) **p-d 혼성 + SCF V_scr drop-in** — R9 OrbitalModel d-궤도 + R3 수렴 real-cell V_scr(G) 데이터.
(γ) **Callaway 실material 계수 swap** — Si/Ge published 계수(Morelli/Slack) 데이터 투입 + 인용 →
  fitted κ(T) 곡선(0-pod 데이터-only; 본 round 의 구조 위 데이터 swap·d4).

### deliver (round-10)
- brick `stdlib/qforge/chip/callaway_bte.hexa` + selftest (g5 19/19 PASS · 회귀 R4/R8 PASS).
- PR base=qforge-chip-r3 (R5-R10 lineage 보존 — r9 와 동일 앵커; pr-cycle auto-merge 가 round-chain
  브랜치 삭제하므로 생존 r3 앵커 기준) · `--repo dancinlab/hexa-lang` · 머지=사용자. WIP 커밋 즉시
  push(durable-worktree). DOMAINS.tape 미접촉. domains/QFORGE-CHIP.{md,log.md} in-place. 0-pod.

## round-11 — verify-adapter (chip=TCAD) · depletion 게이트 (g5 PASS, 0-pod)

### deliver
- brick `stdlib/qforge/chip/verify_adapter.hexa` (d4-generic·manifest verdict 엔진) + selftest.
- g5 PASS: adapter logic(양방향 gate-the-gate) + real-observable(6관측, 정직 tier) + d4(7/7 manifest,
  InAs·diamond 신규 row) + 회귀(R9/R10 READ-only 불변). 0-pod·pure-stdlib.
- base=qforge-chip-r3 (R5-R10 lineage 보존) · DOMAINS.tape 미접촉 · md/log.md in-place.

### 패턴 (materials verify-adapter 미러 — 발명 아님, d4)
materials 가 λ/Tc 를 QE 로 게이트하는 xval-test(`al_fcc_elph_xval`: compute → cited ref → rel-ε vs
tol → PASS/FAIL + provenance)를 그대로 칩에 미러. 차이 = manifest 엔진으로 일반화 — verification 이
row {kind, computed, reference, tol_rel} 한 줄이고 ONE 경로(`qforge_chip_verify_manifest`)를 통과.
material/observable 추가 = row 추가, 코드분기 0(d4). kind: scalar-rel(rel-ε≤tol · gap/m*/κ) /
exact-int(동등 · valley/classification). tier(🟢/🟡/🟠) 판정은 caller 의 정직성 판단(엔진은 순수 수치).

### per-observable verdict (verbatim · 정직 tier)
| observable | computed | ref | Δ | tier | cite |
|---|---|---|---|---|---|
| Si indirect gap | 1.1198 eV | 1.12 | 2.0e-4 | 🟡 PASS | Sze 3rd Tab.1 / Madelung (data-swap onsite) |
| Si classification | INDIRECT(0) | 0 | 0 | 🟢 PASS | Sze §1.2 (eig 에서 읽음) |
| Ge indirect gap | 0.6638 eV | 0.66 | 5.7e-3 | 🟡 PASS | Sze Tab.1 / Madelung (data-swap) |
| Ge classification | INDIRECT(0) | 0 | 0 | 🟢 PASS | Sze §1.2 |
| GaAs direct Γ-gap | 1.42 eV | 1.42 | 0 | 🟢 PASS | Sze Tab.1 / Blakemore 1982 (2-band 2\|V\|) |
| Si valley pair (1D) | 2 | 2 | 0 | 🟡 PASS | ±k₀ pair (1D-representable part) |
| Si valley (3D) | 2 | 6 | 4 | 🟠 FAIL→finding | Sze §1.2 — 6 ⟨100⟩ X-valleys; 1D=pair only |
| m* natural-units | 0.03125 | 1/32 | 1.2e-8 | 🟡 PASS | Ashcroft-Mermin Ch.12 m*=ħ²/2ta² |
| m* (m₀ 물리값) | — | 0.26 m₀ | — | 🟠 finding | API FD dk=1e-4 가 SI-k 미해상 |
| Si κ (300K) | 280.3 W/m·K | 148 | 0.894 | 🟠 FAIL→finding | Glassbrenner-Slack 1964 — generic coeff over-predict ~1.9× |
| κ finite&positive | 1 | 1 | 0 | 🟡 PASS | R10 N/U-crossover bounded κ |

🟠 3개는 **숨긴 실패가 아니라 정직한 adapter 결과**(d6): 모델이 generic 파라미터로 실material 을
재현 못 함을 게이트가 올바르게 드러냄. tolerance back-fit 으로 가짜 PASS 만들지 않음(1-knob fit=
tautology, 정직하게 거부). adapter 의 가치 = 재현(🟢/🟡) vs structural-only(🟠) 의 정직한 분류.

### depletion 판정 — 칩 STRUCTURALLY SEALED (g0, 새 physics round 발명 안 함)
band leg(R1·R3·R9) + thermal leg(R4·R8·R10) + verify-adapter(R11) 가 칩 스케일 STRUCTURE 를 닫음.
R11 이 드러낸 남은 frontier 는 **전부 data-swap / API / integration**(코드-physics 아님):
- m₀-valued m\* = unit-consistent FD step (API frontier)
- 3D valley multiplicity = 3D-band 모델 (R9 차원 확장)
- 절대 κ = ab-initio B_U/B_iso (QFORGE-materials DFPT coeff feed)
- 실 Si/Ge 밴드 파라미터 = SK 테이블 data-swap (d4)
새 brick 아님 → /domain 에 새 round 안 만듦. 남은 milestone(NEXUS edge)은 integration 배선.

### round-12 — named
**NEXUS edge 등록** (QFORGE-CHIP ↔ QFORGE-materials DFPT coeff feed + 소자 도메인 재사용 그래프) —
frontier 1~3 을 묶는 d19 재사용 배선이지 새 physics 가 아님. 그 외 frontier 는 전부 data-swap
(SK 실 파라미터 · Callaway published 계수)으로 0-pod·데이터-only. **칩 STRUCTURE 자체는 round-11 sealed.**

### round-12 — DONE · 3-D k-space band model (g5 22/22 PASS, 0-POD)
`stdlib/qforge/chip/band_3d.{hexa,selftest}` — band leg 의 마지막 genuine-physics 완성.
R9 의 1-D-in-k H(k)(단일 kx 축) → 진짜 3-D Brillouin-zone H(k) over k=(kx,ky,kz):
Bloch phase 를 실제 3-D 격자벡터 R=(nx,ny,nz)·a(단순입방)에서 합산. R9 eigh + R3 DOS 재사용(d19).

g5 (VERBATIM verdicts in PR): 세 3-D-only feature 가 큐빅 point-group 에서 emergent —
- (a) valley multiplicity = **6** — ⟨100⟩ 전도밴드 minima 정확히 6개 등가 X-valley(전역 CBM
  degeneracy). 하드코딩 아님; 1-D 는 ±k₀ pair=2 만. ⟨100⟩-valley 는 genuinely 비분리(축별 well 이
  타축 변위 시 gate-off — 분리형은 ⟨111⟩=8 을 줌). 6 valley E_cbm=−1.040 degenerate.
- (b) anisotropic m* tensor — ⟨100⟩ valley 서 3×3 곡률/질량텐서 valley-frame 대각(off-diag≈1e-10),
  **m*_l=0.0239 ≠ m*_t=0.0516**(ratio 2.16, 두 transverse 큐빅대칭 동일). 등방극한=R9 스칼라
  ħ²/(2t a²)=0.0625 회귀.
- (c) 3-D DOS — 메쉬 히스토그램 √(E−E_c) edge(log-log slope 0.60, 1-D 1/√ 발산과 대비) +
  ∫DOS=Σbins=nk³=125000 정규화.
- (d) 회귀 — R9 band_multiorbital + R3 band_kmesh selftest PASS(불변, 3-D 경로 additive).

HONEST(d6): 단순입방 + tight-binding 모델 hopping(R9 동일 caveat). deliverable = 3-D 밴드
STRUCTURE(valley COUNT·anisotropic m* TENSOR·3-D √E DOS) emergent; 실 Si/Ge param = hop3 data-swap.

**FINAL 칩 depletion 판정 (g0):** band leg 이제 physics-complete. R11 이 드러낸 유일한 real-physics
gap(frontier #2: 3D valley multiplicity)이 R12 로 닫힘. 남은 frontier = 100% data-swap/API/NEXUS-edge
(실 SK param·SI-unit m*·ab-initio κ 계수·NEXUS 배선) — **새 physics round 없음. 칩 = physics bricks
DEPLETED.** 남은 open milestone(NEXUS edge)은 integration 배선이다.

---

## R4 — absolute-κ ab-initio coefficient feed (CITED Si/Ge Callaway, 🟠→🟢)

R11 verify-adapter 가 🟠 STRUCTURAL-ONLY 로 남긴 절대 κ frontier(generic-coeff Si κ≈280 vs
148 ~1.9× over-predict)를 진짜 DATA-SWAP(d4)으로 닫음 — back-fit 아님(d6). 새 brick =
`stdlib/qforge/chip/callaway_si_ge.{hexa,selftest}` (R10 callaway_bte + R11 verify_adapter
MODEL bytes 불변; 옆에 cited-계수 brick 추가).

**두 CITED 계수 SET (모든 값 출처, target 에 fit 한 knob 없음):**
- **Si** — Mingo PRB 68,113308 (2003) single-mode EDIP fit (nanoHUB 표): 1/τ_N=B_N ω²T³
  (B_N=2.0e-24), 1/τ_U=B_U ω²T exp(−C/T) (B_U=1.73e-19·C=137.39K), 1/τ_iso=A_iso ω⁴
  (A_iso=2.2e-45), Θ_D=645K·v=6400m/s·L=7.16mm. CROSS-VAL(d19 독립): Slack-Morelli 1차원리
  B_U=ħγ²/(M̄v²θ_a)=1.74e-19 가 Mingo fit 1.73e-19 과 <1% 일치, C=θ_a/3≈132 vs 137 (<4%) —
  무관한 두 출처가 같은 계수로 수렴.
- **Ge** — Morelli-Heremans-Slack PRB 66,195304 (2002) + Morelli&Slack 2006 Tab.2.2 1차원리:
  γ=1.06·M̄=72.59·θ_a=235K·v=3540m/s·a=5.658Å·Γ=5.87e-4 → B_U=ħγ²/M̄v²θ_a=3.34e-19·
  C=θ_a/3=78.3K·A_iso=V₀Γ/4πv³=2.38e-44·B_N=(B_N/B_U)_Si·B_U_Ge=3.86e-24. Θ_D=374K(Itoh, Ge
  isotope)·L=5mm.

**g5 4/4 VERBATIM:**
- (a) **Si κ(300K)=146.192 W/m·K vs exp 148, rel-ε=0.0122** (tol 5% → PASS). β-corr
  LOAD-BEARING: κ_RTA-only=89.4 만으로 under-predict, Callaway N-복원이 146 으로 올림(knob 튜닝
  아님). cite: Mingo PRB 68,113308(2003); exp Glassbrenner-Slack PR 134,A1058(1964).
- (b) **Ge κ(300K)=68.386 W/m·K vs exp 60, rel-ε=0.1398** (tol 20% → PASS). 2번째 material =
  SAME fn qforge_chip_callaway_kappa_of() · swapped DATA 만(d4-generic). cite: Morelli-Slack
  PRB 66,195304(2002).
- (c) **κ(T) 곡선 SHAPE**: Si 587.9/244.8/146.2/100.8·Ge 252.9/113.9/68.4/47.5 @100/200/300/400K
  (lit Si 884/264/148/98·Ge 232/96/60/43 trend 일치). monotone 하강(peak 지나 Umklapp 1/T) +
  Si κ(600)/κ(300)=0.414 (<0.6, Peierls 1/T-dominated).
- (d) **REGRESSION**: R10 callaway_bte (τ_N→∞ ⇒ κ_corr→0 EXACT; deterministic) + R11
  verify_adapter (verdict kernel within→PASS/out→FAIL) selftest 여전히 PASS. R11 은 여전히
  generic κ=280.337 보고 — 모델 bytes 불변 확인. R11 kernel 이 이제 Si κ(146) vs 148 을 PASS 게이트
  (🟠 closed).

**HONEST(d6/g63):** Callaway 는 MODEL. 1-20% 잔차가 CITED 독립 계수 SET 의 정직한 결과 —
single knob 으로 148 강제(tautology) 거부(R11 agent 가 명시 거부했던 것). Si 1.2%(Mingo set 이
Si 에 tightly fit) · Ge 14%(Slack-Morelli 1차원리, Ge-specific fit 없음). 둘 다 verbatim 보고.
이로써 R11 frontier #3(절대 κ)이 닫힘 — thermal leg 절대값까지 sealed.
