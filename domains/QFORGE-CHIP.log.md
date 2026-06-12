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
