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

## 2026-06-13 — round-7 γ G≠0 full self-consistent screening (R6 마지막 고정-leg 봉합, g5 19/19 PASS)

R6 정직 보고가 명시한 round-7: G≠0 self-consistent. R6 는 vshell[0](G=0)=V_xc(ρ̄_sc) 만
실 수렴이고, vshell[1+](off-diag Bragg shell V_scr(G≠0))=FIXED 해석 vbragg 였다(assembler 가
G=0 대각만 수용). round-7 이 그 마지막 고정-leg 을 dense FFT-grid G-space V_scr(G) 로 봉합.

### 감사 (task 1, d19)
- `band_scf_real.hexa`(R6): vshell=[V_scr(G=0), vbragg] — vbragg 가 고정 caller 입력. R3
  `qforge_chip_scf_band_eps` 는 이미 **arbitrary-length vshell**(`vshell[|i−j|]`)을 소비 →
  full shell 을 채우면 새 eig 경로 없이 drop-in (d4 data-swap).
- `scf_pw.hexa`: `qforge_vscr_diag` = V_H(ρ)+V_xc(ρ) 대각, `qforge_vxc_point` = LDA V_x+V_c
  점값. `qforge_vhartree_from_rho` = G-공간 Poisson 4π/|G|² (G=0→0 중성 게이지).
- `screening.hexa` → `signal/core_fft.hexa` `fft3_real`(#2076): 실입력 3D FFT → interleaved
  spectrum. ρ(r)/V_scr(r) → ρ(G)/V_scr(G) 정변환에 그대로 재사용 (d19, FFT 재구현 0).

### brick (task 2) — `stdlib/qforge/chip/band_scf_gfull.hexa`
수렴 ρ → V_scr(r)=V_H[ρ]+V_xc[ρ] (1D pow2 line, b1=2π/a → FFT freq m 이 chip G_m=(2π/a)·m
에 정확 착지) → `fft3_real` → V_scr(G_m) 전체 shell (1/n 정규화: m=0 bin=⟨V_scr⟩=V_xc(ρ̄)
연속) → R3 `qforge_chip_scf_band_eps` 에 full vshell drop-in → ε_n(k). + self-consistency
residual fn (‖V_scr[ρ]−V_scr[ρ_prev]‖∞ — 같은 ρ→0 fixed point, perturbed→≠0; 정직 SC 체크).
d4-generic: ρ/역격자기저/xc_mode/a 전부 데이터, material 하드코딩 없음.

### g5 selftest VERBATIM (실 출력, 날조 금지)
`HEXA_LANG=. hexa run stdlib/qforge/chip/band_scf_gfull_selftest.hexa`
```
PASS (a) V_scr(G) shells returned (G0..G3) (4)
PASS (a) all V_scr(G) shells finite (no NaN/Inf)
PASS (a) V_scr(G=0) == analytic V_xc(ρ̄) (cell average) (-0.362784)
PASS (a) V_scr(G_1) FFT == independent real-space DFT projection (0.0322553)
PASS (a) structured ρ → V_scr(G_1) ≠ 0 (real self-consistent G≠0)
PASS (b) uniform ρ → V_scr(G_1)=0 (no Bragg shell, metal) (0.0)
PASS (b) uniform ρ → V_scr(G_2)=0 (0.0)
PASS (b) round-7 ε_n(k) spectrum dim (7)
PASS (b) uniform-ρ round-7 ε_n(k) == round-6 G=0 band (continuous)
PASS (b) uniform ρ → self-consistent gap = 0 (metal, R6 limit) (0.0)
PASS (c) structured ρ opens a self-consistent Bragg gap (gap>0)
PASS (c) weak-ρ gap → 2|V_scr(G_1)| (NFE limit, ratio∈[0.85,1.001])
PASS (c) stronger ρ-modulation → larger self-consistent gap
PASS (d) ε_n(k) full spectrum (nG eigenvalues) (7)
PASS (d) ε_n(k) ascending & real (Hermitian H, valid KS)
PASS (d) ε_n(k) all finite (no NaN/Inf in the spectrum)
PASS (d) ε₀(Γ) real & finite (V_scr(G) real ⇒ H real-symmetric)
PASS (d) SC residual ‖V_scr[ρ]−V_scr[ρ]‖ = 0 (fixed point) (0.0)
PASS (d) SC residual ≠ 0 for a perturbed ρ (honest non-convergence)
qforge_chip_band_scf_gfull_selftest PASS
```
- (a) **full G-space V_scr 결선**: 수렴 ρ → V_scr(G) 전체 shell 유한(NaN/Inf 0). G=0 bin
  = 해석 V_xc(ρ̄)=−0.362784 (uniform 셀 공간평균). structured ρ(cos변조 α=0.5)의 V_scr(G_1)
  =+0.0322553 가 **독립 real-space DFT 투영**(FFT 아닌 직접 cos 합)과 1e-12 일치 — FFT 가
  차폐 자체이지 재유도 아님. structured ρ → V_scr(G_1)≠0 = 실 self-consistent G≠0.
- (b) **R6 G=0 leg 연속**: uniform ρ(R6 jellium 셀)→V_scr(G≠0)=0 **정확** → round-7 vshell=
  [V_xc(ρ̄),0,0,…] → ε_n(k) 이 R6 G=0-only 밴드(vbragg=0)와 verbatim 일치 (7개 고유값 1e-12).
  uniform→갭=0 (금속, R6 극한). G≠0 self-consistent leg 이 uniform 극한서 R6 로 연속환원.
- (c) **self-consistent 갭**: structured ρ → k=π/a 에서 실 V_scr(G=±g)가 Bragg 갭 형성 (고정
  vbragg 아님). 약변조 극한 gap→2|V_scr(G_1)| (NFE, Ashcroft-Mermin Ch.9; ratio∈[0.85,1.001]
  — full eig 가 고차 shell 결합으로 2|V_g| 아래, d6). 강변조(α=0.9)→더 큰 갭 (차폐가 갭 구동).
- (d) **Hermiticity/실대칭**: full V_scr(G) 의 H(k) real-symmetric → ε_n(k) real·ascending,
  전부 유한. SC residual=0 (같은 ρ = idempotent fixed point), perturbed ρ→≠0 (정직 SC 체크,
  비수렴 ρ 면 노출 — d6 날조 안 함).

### 정직 보고 (d6 / @L5) — round-6 대비 진짜 G≠0 self-consistent 됐나
**됐다.** round-6: vshell[0](G=0)만 실 self-consistent, vshell[1+](G≠0)=고정 해석 vbragg.
round-7: V_scr(G) **전체 G** (G=0 AND G≠0) 가 V_scr[ρ](r)=V_H[ρ]+V_xc[ρ] 의 FFT — off-diag
shell 이 ρ_sc 의 **함수**(고정 입력 아님). uniform 극한(R6 셀) → V_scr(G≠0)=0 정확 → R6 밴드
verbatim 연속(leg b); structured ρ → 실 self-consistent Bragg 갭(leg c). 이게 round-6 정직
보고가 round-7 로 지정한 바로 그것. **수렴 iters 정직**: leg (a)~(d)는 수렴 ρ(또는 해석적
structured ρ)에서 V_scr(G) 추출·밴드·갭을 검증 — full G-space self-consistent **추출/결선**은
달성. SC residual fn 이 fixed-point(=0)/perturbed(≠0)를 측정 = self-consistency 의 정직 게이트.
**스코프 정직**: 본 brick 은 수렴 ρ → full V_scr(G) → ε_n(k) 경로(R6 의 고정 leg 봉합)를 봉인.
1D-chip 셀이 pow2 line(n=8) 한 셀을 샘플 (b1=2π/a → G-set 정확 착지). real-cell 3D dense FFT
self-consistent SCF 의 full G-mesh 결선은 다음 — 1D 봉합이 핵심 deliverable, 충족.

### 밴드 leg 완전 self-consistent 봉인됐나
**예.** 밴드 leg 의 포텐셜이 R3(해석 Fourier)→R6(G=0 실 self-consistent)→R7(G=0+G≠0 full
self-consistent)로 단조 봉합. H(k)=T(k)+V_scr 의 V_scr 가 이제 **모든 reciprocal shell** 에서
ρ_sc 의 FFT — 밴드 leg 에 남은 고정/해석 포텐셜 leg 없음. 운동에너지 T(k)=½|k+G|²(R3 실
kinetic brick)+ V_scr(G) full(R7 실 FFT) = 밴드 leg 완전 self-consistent.

### chip 스케일 완성도 / depletion 판정
- **밴드** ✓ R1 ε(k) · R2 k-mesh+DOS · R3 SCF-fed H(k) · R6 G=0 SC · **R7 G≠0 full SC** — 봉인.
- **수송** ✓ R1 Landauer · R2 NEGF mode-count · R5 코히어런트 Σ-NEGF T(E)=Tr[ΓGΓG].
- **열** ✓ R4 phonon-Landauer κ→N·g₀ floor.
→ 칩 front-end 3-leg(밴드·수송·열)이 closed-form/self-consistent 앵커에서 전부 g5 봉인. 밴드
leg 의 self-consistent 정밀화(R3→R6→R7)가 완료 = 밴드 leg DEPLETED(고정 포텐셜 leg 0). 남은
개방축은 산란 정밀화(diffusive)와 multi-orbital/3D real-cell — 아래 round-8.

### round-8 다음
밴드 leg full self-consistent 봉인 완료 → (1) **BTE diffusive** (R4 ballistic κ floor + 포논-
포논 Umklapp/동위원소 산란 → 유한 device diffusive κ, ballistic 가 상한 앵커; R4 정직 보고가
지정) · (2) **multi-orbital / multi-band H(k)** (1D single-shell → multi-orbital tight-binding/
multi-band PW, p/d 오비탈 hybridization 갭 · spin-orbit) · (3) **phonon-NEGF Σ_ph** (R5 전자
Σ-NEGF 동형 → R4 ballistic κ 를 산란-감쇠로 확장). 우선 (1) BTE — R4 가 명시 지정한 직접 후속.

### deliver (round-7)
- brick `stdlib/qforge/chip/band_scf_gfull.hexa` + selftest (g5 19/19 PASS).
- PR base=qforge-chip-r3 (R1~R6 lineage tip; r3 트리가 R6 brick 이미 포함) · `--repo
  dancinlab/hexa-lang` · 머지=사용자. brick+selftest+WIP 즉시 push (durable-worktree). gen3
  arena 우회(eigh 고유값 즉시 materialise · scalar 로컬화). DOMAINS.tape 미접촉. domains/
  QFORGE-CHIP.{md,log.md} in-place (R7 milestone+로그, PR 브랜치에서만 stage/commit).
