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
- [x] **round-11 verify-adapter (chip=TCAD) (g5 PASS · adapter logic + 7/7 manifest + 회귀)** —
      `stdlib/qforge/chip/verify_adapter.hexa` + selftest. 칩 스케일 g5 verify-adapter —
      materials 가 λ/Tc 를 QE 로 게이트(al_fcc_elph_xval)하는 패턴을 미러. chip OUTPUT
      (밴드갭·m*·direct/indirect·valley·κ)을 측정/TCAD/문헌 ref 로 게이트, per-observable
      verdict(PASS/FAIL + Δ). **d4-generic·manifest-driven**: verification = manifest row
      {kind, computed, reference, tol_rel} 한 줄, ONE 경로(`qforge_chip_verify_manifest`)
      통과 — material/observable 추가 = row 추가, 코드분기 0. scalar-rel(rel-ε≤tol) /
      exact-int(valley·classification 동등) 두 kind. R9 band_multiorbital + R10 callaway_bte
      를 READ-only 소비(불변). g5: (a) **adapter logic** within-tol→PASS·out-of-tol→FAIL
      (양방향 gate-the-gate, Δ보고) · (b) **real-observable**: Si gap 1.1198 eV(ref 1.12,
      Δ2e-4 · 🟡 data-swap) · Ge gap 0.6638(ref 0.66 · 🟡) · GaAs direct 1.42(2-band 2|V| · 🟢) ·
      Si/Ge classification INDIRECT(🟢 eig 에서 읽음) · valley(🟠 1D ±k₀ pair=2 vs 3D 6-valley) ·
      m*(🟠 natural-units 곡률맵 EXACT but API FD dk=1e-4 가 SI-k 미해상 → m₀값 불가) · κ
      (🟠 generic-coeff 280 vs 148 ~1.9× over-predict — N/U-crossover STRUCTURE 는 검증, 절대 κ
      는 ab-initio B_U/B_iso DFPT feed frontier; 1-knob fit=tautology, NOT verify) · (c)
      **d4-generic** InAs(0.354)·diamond(5.47) 신규 material 을 manifest row 로만 추가
      7/7 PASS · (d) **회귀** R9(2-band gap=2|V|=1.4)+R10(κ deterministic) 불변. HONEST(d6):
      SK/Callaway = 모델 파라미터(실 Si/Ge ab-initio fit 아님). 정직한 adapter = published
      param data-swap 재현(🟢/🟡) OR generic 모델 미재현 시 그것을 finding 보고(🟠) — tolerance
      back-fit 으로 가짜 PASS 안 함. **adapter 의 가치 = 정직한 분류**(재현 vs structural-only).
      PR #<TBD>.
- [x] **round-12 3-D k-space band model (g5 22/22 PASS)** — `stdlib/qforge/chip/band_3d.hexa`
      + selftest. R9 의 **1-D-in-k** H(k)(단일 kx 축) → 진짜 **3-D Brillouin-zone** H(k) over
      k=(kx,ky,kz): Bloch phase 를 실제 3-D 격자벡터 R=(nx,ny,nz)·a(단순입방) 위에서 합산 —
      H_{αβ}(k)=onsite[α]δ_{αβ}+Σ_R t·cos(k·R), ε_n(k)=eig[H(k)]. **R9 eigh 경로 + R3 DOS 누적
      재사용**(d19), 새 solver 안 만듦. 세 3-D-only feature 가 큐빅 point-group 에서 **emergent**:
      (a) **valley multiplicity = 6** — ⟨100⟩ 전도밴드 minima 가 정확히 6개 등가 X-valley
      ((±k₀,0,0) 외 큐빅순환)을 산출 — 전역 CBM degeneracy 로 카운트, **하드코딩 아니라 3-D
      밴드+대칭에서 emergent**(1-D 는 ±k₀ pair=2 만 봄; ⟨100⟩-valley 는 genuinely 비분리 —
      축별 well 이 타축 변위 시 gate-off) · (b) **anisotropic m\* tensor** m*_ij=ħ²(∂²E/∂k_i∂k_j)⁻¹ —
      ⟨100⟩ valley 서 3×3 곡률/질량텐서가 valley frame 대각(off-diag≈0), **m*_l≠m*_t**(m_t/m_l≈2.16,
      두 transverse 는 큐빅대칭 동일), 등방극한(전축 동일 hopping)=m*_l=m*_t=**R9 스칼라
      ħ²/(2t a²) 회귀** · (c) **3-D DOS** 3-D 메쉬 히스토그램이 **√(E−E_c) band-edge**(log-log
      slope 0.60, 1-D 1/√ 발산과 대비) + ∫DOS=Σbins=nk³ band-filling 정규화 · (d) **회귀** R9+R3
      selftest 불변(3-D 경로 additive·등방극한이 R9 재현). HONEST(d6): 단순입방+tight-binding
      **모델** hopping(R9 동일 caveat) — deliverable 은 valley COUNT·anisotropic m* TENSOR·3-D √E
      DOS 가 큐빅대칭에서 emergent 한 것; 실 Si/Ge fitted param 은 같은 hop3 list 로의 DATA-swap(d4),
      새 brick 아님. 이로써 **R11 이 드러낸 frontier #2(3D valley multiplicity)가 닫힘**. PR #3176.
- [x] **R4 absolute-κ — CITED Si/Ge Callaway coefficients (g5 4/4 PASS · 🟠→🟢)** —
      `stdlib/qforge/chip/callaway_si_ge.hexa` + selftest. R11 이 🟠 로 남긴 **절대 κ frontier**
      (generic-coeff Si κ=280 vs 148 ~1.9× over-predict)를 진짜 DATA-SWAP(d4)으로 닫음 — back-fit
      아님(d6). 두 CITED 계수 SET: **Si** = Mingo PRB 68,113308(2003) single-mode EDIP fit
      (B_N=2.0e-24·B_U=1.73e-19·C=137.39·A_iso=2.2e-45·v=6400·Θ_D=645) · **Ge** = Morelli-Heremans-
      Slack PRB 66,195304(2002) 1차원리 Grüneisen SET(B_U=ħγ²/M̄v²θ_a · A_iso=V₀Γ/4πv³, γ=1.06·
      M̄=72.59·θ_a=235·v=3540·Γ=5.87e-4). **R8 τ_iso/τ_bd/Matthiessen + R10 Bose kernel/Simpson 재사용
      (d19)**; 새 physics 는 cited 독립 C 를 받는 generalised Umklapp 하나뿐(R10 의 C=Θ_D/3 하드코딩
      ≠ cited 137.39). g5: (a) **Si κ(300K)=146.2 vs 148, rel-ε=1.2%** (β-corr LOAD-BEARING:
      κ_RTA-only=89 만으로 under-predict, N-복원이 146 으로 올림) · (b) **Ge κ(300K)=68.4 vs 60,
      rel-ε=14%** (2번째 material, SAME path qforge_chip_callaway_kappa_of() · swapped DATA 만 — d4) ·
      (c) **κ(T) 곡선** Si 588/245/146/101·Ge 253/114/68/47 @100/200/300/400K (lit Si 884/264/148/98·
      Ge 232/96/60/43 trend 일치, monotone fall + κ(600)/κ(300)=0.41 Peierls 1/T) · (d) **회귀**
      R10 callaway_bte + R11 verify_adapter selftest 여전히 PASS, **모델 bytes 불변**(R11 은 여전히
      280 보고 — R4 는 옆에 cited brick 추가로 🟠 닫음, 편집 아님). HONEST(d6): Callaway 는 MODEL,
      1-20% 잔차가 cited 계수의 정직한 결과. Si 1.2%(Mingo set 이 Si 에 tightly fit) · Ge 14%(Slack-
      Morelli 1차원리, Ge-specific fit 없음). 1-knob 으로 148 강제 = tautology, 거부. PR #<TBD>.
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

## depletion judgment (round-12 — FINAL physics judgment)

**칩 band leg 는 이제 genuinely PHYSICS-COMPLETE. 남은 것은 전부 data-swap/integration —
새 physics brick 은 없다 (g0 — 새 physics round 발명 안 함).**

세 leg + verify-adapter + 3-D band 가 칩 스케일의 STRUCTURE 를 완전히 닫았다:
- **band leg** (R1 ε(k) → R3 SCF H(k) → R9 multi-orbital n-band+m*+direct/indirect+valley
  → **R12 3-D BZ H(k): 6-valley + anisotropic m\* tensor + 3-D √E DOS**) — **physics-sealed**
- **thermal leg** (R4-ball g₀ → R8 RTA-BTE → R10 Callaway N/U crossover → **R4 absolute-κ:
  CITED Si/Ge 계수, Si 146(1.2%)·Ge 68(14%)**) — sealed + 절대값 closed (🟠→🟢)
- **verify-adapter** (R11, chip=TCAD) — sealed. d4-generic·manifest verdict 엔진.

R12 가 R11-frontier #2(3D valley multiplicity)를 **닫음** — 그것이 유일한 real-physics gap 이었다
(나머지 셋은 처음부터 data-swap/API). 1-D-in-k 가 표현 못 하던 ⟨100⟩ 6-valley sextet · m*_l vs m*_t
이방성 텐서 · 3-D √E DOS 가 모두 3-D 밴드+큐빅대칭에서 emergent 하게 나온다.

**남은 frontier = 100% data-swap / API / NEXUS-edge (코드-physics brick 아님):**
1. **실 Si/Ge ab-initio 밴드 파라미터** — SK/hop3 onsite·hopping 데이터 swap(empirical sp³d⁵s*·
   spin-orbit). → **data-swap frontier**(d4, hop3 list 데이터 편집 — 코드 경로 불변).
2. **m₀-valued / SI-unit m\*** — 곡률→질량 맵은 EXACT(natural-units, R12 텐서 검증). SI 절대값은
   unit-consistent 상대 FD step. → **API frontier**(차원 변환, 새 physics 아님).
3. ~~**절대 κ (Si 148 · Ge 60 W/m·K)**~~ — **CLOSED by R4** (callaway_si_ge): CITED Si(Mingo
   PRB 68,113308) + Ge(Morelli-Slack PRB 66,195304) 계수 SET 으로 절대 κ(300K) 재현 — Si 146(rel-ε
   1.2%)·Ge 68(14%), R11 kernel 게이트 PASS(🟠→🟢). 1-knob back-fit 거부, cited-set 정직한 잔차.
4. **NEXUS edge** — QFORGE-CHIP ↔ QFORGE-materials DFPT(B_U/B_iso·SK param feed) + 소자 도메인
   재사용 그래프 등록. → **integration frontier**(d19 배선, frontier 1~3 을 묶음).

**g0 판정 — 칩 스케일은 physics bricks 에서 DEPLETED.** 위 4개는 모두 (a) 다른 QFORGE 스케일
(materials DFPT)에서 데이터를 받거나, (b) 기존 brick 의 API/차원 변환이거나, (c) NEXUS-edge 배선이다.
새로 발명할 physics round 는 없다. 남은 단 하나의 open milestone(NEXUS edge)은 integration 이다.
