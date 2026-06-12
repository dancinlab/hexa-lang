# QFORGE-CHIP — device band · transport · thermal front-end (chip scale)

@title: 🔌 QFORGE-CHIP — 칩 소자 제일원리 (밴드·수송·열, SCF 재사용)

@goal: QFORGE universal-engine 의 **chip(device) scale** front-end 완성 — 반도체 소자의
밴드구조 → 양자수송(Landauer/NEGF) → 열수송(phonon Landauer/BTE) 을 hexa-native 제일원리로
계산하고 측정/TCAD ref 로 g5 검증. 공통코어(SCF 전자구조·평면파 H(k)·eigen 대각화·DFPT
포논)를 재사용(d19) — materials 스케일과 동형. QFORGE.md §122 line 141 마일스톤.

## milestones

- [x] **round-1 brick — band+transport analytic spine (g5 22/22 PASS)**
      `stdlib/qforge/chip/band_transport.hexa` + selftest. 1D tight-binding
      ε(k)=ε₀−2t·cos(ka) (bandwidth=4t · 밴드edge v_g=0 · van-Hove), diatomic-chain GAP
      via generic `eigh` (반도체 vs 금속), Landauer-Büttiker G=G₀·ΣTₙ 양자화 (G₀=2e²/h ·
      QPC 계단), 보편 열전도 양자 g₀=π²k_B²T/3h (Schwab Nature 404,974). 전부 exact
      closed-form anchor (d6). PR #3127.
- [ ] **round-2 ① k-mesh band sweep** — H(k) 를 MP-mesh(`mpgrid` 재사용)에서 평가 → ε_n(k)
      밴드 manifold · Γ→X 경로 + DOS van-Hove anchor.
- [ ] **round-2 ② 2-terminal NEGF transmission** — T(E)=Tr[ΓL G^r ΓR G^a], 1D TB chain +
      반무한 lead 자기에너지 Σ(E); anchor = G(E) → N·G₀ 양자화 + Fisher-Lee↔mode-count
      bridge (NOVEL 가교 live).
- [x] **round-3 ③ SCF-fed band hook (g5 22/22 PASS)** — `stdlib/qforge/chip/band_scf.hexa`
      + selftest. ε_n(k)=eig[H(k)], H(k)=T(k)+V: T(k)=½|k+G|² 는 SCF 코어의 REAL
      `qforge_kinetic_diag` brick (d19 — 밴드/SCF 가 같은 운동에너지 연산자 공유), V 는
      평면파 Fourier 포텐셜 V_{G,G'}=V(G−G') (assembler.hexa 의 V_ext/V_scr 구조; d4 —
      empty-lattice·단일 Bragg shell·수렴 scf_pw V_scr 모두 한 경로). 대각화 = generic
      `eigh` (d19 — round-1 diatomic gap/L1/Davidson 공유). g5: (A) **자유전자 회복** ε₀(k)=½k²
      (empty-lattice, V≡0) + zone-fold {½|k+G|²} · (B) **Bragg 갭열림** gap→2|V_g| (weak-V
      극한, ratio 0.975→0.99998 as V_g→0; finite-V 는 2nd-order 로 < 2|V_g|, basis-수렴) ·
      (C) R2 DOS 일관 (band-edge dε/dk→0 van-Hove + 갭내 DOS=0) · (D) Hermiticity + V(0)
      uniform shift. HONEST(d6): 운동에너지=실 SCF brick (배선 LIVE), 포텐셜=해석 Fourier 극한
      (empty+Bragg) — 수렴 real-cell scf_pw V_scr 는 데이터 swap (round-4). PR #3127.
- [x] **round-4 ④ phonon-Landauer κ (g5 19/19 PASS)** — `stdlib/qforge/chip/phonon_kappa.hexa`
      + selftest. ballistic 포논 열전도 κ(T)=(1/2π)∫dω ħω T_ph(ω) ∂n_BE/∂T (Rego-Kirczenow
      PRL 81,232 · Schwab Nature 404,974). DFPT ω(q,ν)(`dfpt` PhononResult.omega·d19) = 투과
      채널 (d4 — analytic·real-DFPT·device 모드 한 경로, 이름 하드코딩 없음). 보편 LOW-T floor:
      N reflectionless acoustic 채널 → κ=(1/2π)(k_B²T/ħ)·(π²/3)=N·g₀ (∫x²e^x/(e^x−1)²dx=π²/3
      EXACT, dispersion-blind). g₀ = round-1 `qforge_chip_thermal_quantum` 재사용 (d19 — 단일
      π²k_B²T/3h). g5: (A) **저온 양자극한** κ/T→N·π²k_B²/3h (T=10/1/0.1K plateau) · (B) **g₀값**
      κ(1ch,1K)=9.46431e-13 W/K (round-1 일관) · (C) **Bose-Einstein** ∂n_BE/∂T>0 + 고전극한
      ħω·∂n/∂T→k_B (Dulong-Petit) · (D) **채널수 plateau** κ(N)=N·g₀ (N=1..4, 열 staircase =
      Landauer N·G₀ 의 열 아날로그) · (E) generic 모드리스트 (3 acoustic→3g₀, frozen-optical
      BE-억제). HONEST(d6): ballistic 양자극한 — 포논-포논/Umklapp 산란·diffusive BTE 아님;
      앵커 = EXACT 양자 floor (저온/clean), diffusive device κ 아님. PR #<TBD>.
- [x] **round-9 β multi-orbital band H(k) (g5 34/34 PASS)** — `stdlib/qforge/chip/band_multiorbital.hexa`
      + selftest. R1/R3 의 **single-band** ε(k) → **multi-orbital / multi-band** H(k):
      H_{αβ}(k)=onsite[α]δ_{αβ}+Σ_hop t·cos(k·dx·a) (각 site 가 n_orb 궤도; Slater-Koster
      ssσ/spσ/ppσ/ppπ two-centre · Slater-Koster PR 94,1498 (1954) — 또는 generic 2-band).
      ε_n(k)=eig[H(k)] n_orb 밴드 (generic `eigh` 재사용·d19 — R1 diatomic gap/R3 PW H(k)/L1/
      Davidson 공유). 궤도·hopping = **데이터** (OrbitalModel: onsite[] + Hop{α,β,dx,t}[] — 궤도/
      SK채널/이웃 추가 = 데이터 편집, builder 불변·d4). g5: (A) **다밴드 차원** H(k) n_orb×n_orb ·
      ε_n(k) n_orb개 (2/3-orbital + norb=1 single-band 극한) · (B) **유효질량** m*=ħ²/(d²ε/dk²)
      band-edge FD vs 닫힌형 m*=ħ²/(2ta²) (Ashcroft-Mermin Ch.12; flat band→heavy m*∝1/t · band-top
      curvature<0→m*<0 hole) · (C) **직접/간접갭** VBM(valence max)/CBM(conduction min) k-위치 비교 →
      DIRECT(같은 k=Γ)/INDIRECT(다른 k, CBM@π/a) 판별 (eig 에서 읽음·d4) · (D) **2-band 닫힌형**
      2×2 eig == ½(Ea+Eb)±√((½ΔE)²+V²) (Wolfsberg/two-level · degenerate→gap=2|V| avoided-crossing)
      + Hermiticity H_{αβ}=H_{βα} · (E) **valley count** 전 BZ [−π/a,π/a) 전도밴드 minima
      (single-well→1 · boundary→1 · double-well ±k₀→2). HONEST(d6): SK/2-band **모델** 파라미터 —
      실 Si/Ge fit 아님(경험 ss/sp 표·spin-orbit·d-궤도 없음); 다밴드 구조+유효질량+갭판별+2-band
      닫힌형이 deliverable, 실 material = OrbitalModel 데이터 swap(d4). PR #<TBD>.
- [x] **round-10 ⑩ Callaway BTE — N/U-separated crossover (g5 19/19 PASS)** —
      `stdlib/qforge/chip/callaway_bte.hexa` + selftest. R4 ballistic κ(N·g₀) + R8 RTA-BTE κ
      에 **Callaway 모델**(Phys Rev 113,1046 (1959)) 로 ballistic↔diffusive crossover 정밀화 —
      Normal(N·모멘텀보존) vs resistive(R=Umklapp+isotope+boundary) 산란을 **분리**하고 β-보정항
      추가(N-process 는 heat flux 를 직접 relax 안 하고 **재분배**만 함; RTA 의 N over-damp 결함을
      Callaway 가 복원). Debye-적분형 κ=κ_RTA+κ_corr, K(x)=x⁴eˣ/(eˣ−1)², 1/τ_c=1/τ_N+1/τ_R,
      κ_corr=pref[∫(τ_c/τ_N)K]²/[∫(τ_c/(τ_N τ_R))K]. τ_U/τ_iso/τ_bd/Matthiessen = **R8 primitive
      재사용**(d19), τ_N 은 한 채널 더(d4). g5: (a) **RTA 회복** τ_N→∞ ⇒ κ_corr→0 ⇒ κ_Callaway →
      R8 RTA Debye κ EXACT(419.12) · (b) **ballistic ceiling** pure-N/clean 저온은 Casimir
      boundary-limited ceiling 에 BOUNDED(발산 X; N=flux-neutral → ratio=1, +Umklapp → strictly
      below) · (c) **crossover T-scaling** 저온 κ∝T³(ratio 2T/T=8 EXACT) → peak → 고온 κ∝1/T
      (Umklapp, 2T/T→0.494≈1/2 Peierls) + β-보정 LOAD-BEARING(N-dom 서 κ_full≫κ_RTA-only) ·
      (d) **회귀** R4(ballistic g₀)+R8(RTA-BTE) selftest 여전히 PASS, 공유 primitive 불변.
      HONEST(d6): τ_N/τ_U = 표준 Callaway 멱법칙 **모델 계수**(1/τ_N=B_N ω²T³ · 1/τ_U=B_U ω²T·exp)
      — ab-initio el-ph 아님(QE/QFORGE-materials DFPT lane); deliverable = N/U-분리 crossover
      **구조**(RTA-회복/ceiling/T³–1/T 극한 정확), 실 Si/Ge κ(T) fit 은 published-계수 데이터
      swap(d4) 이지 주장 아님. PR #<TBD>.
- [ ] **verify-adapter (chip=TCAD)** — 밴드갭/effective-mass/컨덕턴스/κ 를 측정·TCAD ref
      로 표준화 (verify-adapter 일반화 축).
- [ ] **NEXUS edge** — QFORGE-CHIP → {소자 도메인} 재사용 그래프 등록 (materials c7 패턴).

## reuse (d19)
- `stdlib/qforge/scf_pw` · `projector` · `kinetic` · `vloc` — SCF 전자구조 → H(k).
- `stdlib/alloc/math/eigen` (`eigh`) — Bloch H(k) / NEGF lead-mode 대각화 (L1·Davidson 도 재사용).
- `stdlib/qforge/mpgrid` · `kmesh_elph` — k-mesh.
- `stdlib/qforge/dfpt` · `realcell_phonon` — 포논 ω(q) → 열수송 입력.
- `stdlib/signal/fft3` — k-공간 lead / Poisson (수송·열).

## honest scope (d6 / @L5)
round-1 = lit + 설계 + ONE g5 analytic brick (밴드 정확성 + 수송 양자화 + 열 양자).
전체 TCAD(self-consistent Poisson-Schrödinger · drift-diffusion · scattering NEGF · 3D
thermal FEM)는 다중 round 대공사 — round-1 에서 주장하지 않음. brick 값 = exact analytic
ref, device-scale 시뮬레이션 결과 아님.

설계 SSOT: `drafts/qforge-chip-round1-design.md`.
