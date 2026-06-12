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
      closed-form anchor (d6). PR #<TBD>.
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
      (empty+Bragg) — 수렴 real-cell scf_pw V_scr 는 데이터 swap (round-4). PR #<TBD>.
- [ ] **round-2 ④ phonon-Landauer κ** — DFPT ω(q)(`dfpt`·`realcell_phonon`) 를 포논
      transmission 으로 재사용 · ballistic κ → N·g₀ 저온 floor anchor.
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
