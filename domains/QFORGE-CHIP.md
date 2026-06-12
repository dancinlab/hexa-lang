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
      앵커 = EXACT 양자 floor (저온/clean), diffusive device κ 아님. PR #3135.
- [x] **round-5 α scattering-NEGF (g5 13/13 PASS)** — `stdlib/qforge/chip/negf_scatter.hexa`
      + selftest. 코히어런트 Σ-NEGF T(E)=Tr[Γ_L Gʳ Γ_R Gᵃ] (Caroli/Fisher-Lee), 반무한
      lead surface-GF Σ(E) decimation. PR #3139.
- [x] **round-6 β SCF V_scr(G=0) drop-in (g5 22/22 PASS)** — `stdlib/qforge/chip/band_scf_real.hexa`
      + selftest. 실 `qforge_scf_pw` 수렴 ρ → self-consistent G=0 차폐 V_scr(G=0)=V_xc(ρ̄_sc)
      를 R3 H(k) vshell[0] 에 drop-in (데이터-swap, d4) → real self-consistent ε_n(k) →
      R5 NEGF. HONEST(d6): G=0 leg = 실 self-consistent (converged=true assert); off-diag
      Bragg shell vshell[1+] (G≠0) = FIXED 해석 vbragg (assembler 가 G=0 대각만 수용) →
      round-7. PR #3145.
- [x] **round-7 γ G≠0 full self-consistent screening (g5 19/19 PASS)** —
      `stdlib/qforge/chip/band_scf_gfull.hexa` + selftest. R6 의 마지막 고정-leg(off-diag
      Bragg shell) 봉합: 수렴 ρ → V_scr(r)=V_H[ρ]+V_xc[ρ] dense pow2 FFT line → `fft3` →
      V_scr(G) **전체 shell** → H(k)_{G,G'}=½|k+G|²δ+V_scr(G−G') full Fourier matrix → `eigh`
      → ε_n(k). vshell[1+] = 실 V_scr(G≠0) (ρ_sc 의 함수, 고정 vbragg 아님). g5: (a) **full
      G-space 결선** V_scr(G) 전체 shell NaN0 · G=0==V_xc(ρ̄) · V_scr(G_1) FFT==독립 real-space
      DFT 1e-12 · structured ρ→V_scr(G_1)≠0 · (b) **R6 G=0 연속** uniform ρ→V_scr(G≠0)=0
      정확 → ε_n(k)==R6 G=0 밴드 verbatim · (c) **self-consistent 갭** structured ρ→Bragg
      gap (실 V_scr(G=±g), gap→2|V_g| NFE극한, 강한 변조→큰 갭) · (d) **Hermiticity** ε_n(k)
      real·ascending + SC residual=0(fixed point)/≠0(perturbed). d19 재사용: `qforge_vhartree_
      from_rho`(Poisson) · `fft3_real`(#2076) · `qforge_vxc_point`(LDA) · R3 `qforge_chip_scf_
      band_eps`(arbitrary vshell eig). HONEST(d6): G≠0 leg = 실 self-consistent (V_scr[ρ] FFT).
      PR #<TBD>.
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
