# QFORGE-PERF — append-only step log

## 2026-06-01 — 도메인 생성 (el-ph 가속 백로그 시드 · depletion brainstorm)

hexa-native QFORGE el-ph 엔진(stdlib/qforge · SCF·DFPT·λ·Tc · d_qforge_engine canonical,
QE = cross-val ref)의 measured hot loops(qforge_h_apply assembler.hexa:140 scalar O(n²)
matvec · dv_project davidson.hexa:67 VᵀHV · Sternheimer CG sternheimer.hexa per-pert ·
screening.hexa CPU FFT-Poisson)를 두 벽(QE ph.x no-GPU · O(N³)+dense-DFPT) 너머로 가속할
PROPOSAL 백로그를 도메인으로 박제. demiurge 29-pod CPU-DFPT teardown 이 직접 동기.

세 LANE depletion brainstorm 4 라운드 → genuine-new 0 에서 정지:
- R1 (d18 lane-fanout · NOVEL probe + arxiv/web per lane): EPW Wannier |g| interp(dense-DFPT
  killer 확정) · CheFSI · cuFFT/mixed-prec DFPT · Jrystal/Grad-DFT diff-DFT · MACE/BETE-NET GNN.
- R2 (NOVEL hexa kick/drill mk9): verdict=skip (⚪ unverified proposals · g63 정직 · fold atom 0).
- R3 (lane-B/C corner): randomized sketched eigensolver · Pulay/Broyden+TPA · active-learning
  D-opt · Δ-ML/HamGNN AD-deriv el-ph.
- R4 (depletion check): 재확인만 · 신규 mechanism 0 → DEPLETED.

총 deduped 22 아이디어 (⚡Lane A 7 · 🧮Lane B 8 · 🧠Lane C 7). priority 상위 5 = EPW-Wannier
interp(🧮 #1 dense-DFPT killer) · H_apply/Davidson GPU-GEMM(⚡ #2) · diff-DFT reverse-mode
LR(🧠 #3) · CheFSI(🧮 #4) · MLIP pre-screen(🧠 #5). 모든 항목 PROPOSAL — 실 hexa bench
roofline + Δ-vs-baseline 전엔 ⚡/🧮 closed 아님 (g6/g63 정직). docs-only — stdlib/qforge
edit 회피 (별도 CaH6-run agent 활성 · d9 isolation).

tier breakdown: ⚡hardware-PR 7 · 🧮algorithmic 8 · 🧠paradigm 7 · 🔬research-probe 7 ·
🟢bench-needed 8 · ⚪speculative 9 (tier 태그는 중첩 — 한 항목이 lane+상태 둘 다 보유).

## 2026-06-01 — baseline grounding (Δ-baseline 분모 박제 · 완성도 closure)

진짜 병목 = 보드 전체가 PROPOSAL 인데 측정 baseline(speedup 비율의 분모)이 0 이었음.
이걸 메움 — GPU pod 불필요, stdlib/qforge edit 불필요 (docs-only · 별도 CaH6-run agent
활성 · d9 isolation 준수). mini · Apple M4 · hexa 0.1.0-dispatch.

- 드라이버 (bench/qforge/, docs-only — 엔진 read-only `use`):
  - h_apply_core.hexa = `qforge_h_apply_bench(n,reps)` 순수 fn (main 없음 · core)
  - h_apply_n{256,512,1024}.hexa = per-n 리터럴 wrapper (`hexa bench` 가 `-- argv`
    미전달 → 리터럴 하드코딩). reps 는 matvec 루프 ~20s (≫ build/startup) 가 되게 sizing.
  - roofline_bound.hexa = closed-form roofline 천장 (결정론 → g5 verify 표면).
- 측정 CPU-scalar baseline (qforge_h_apply v↦H·v · assembler.hexa:140):
  n=256→0.1394 · n=512→0.1408 · n=1024→0.1417 GFLOP/s · **mean ≈ 0.140 · n 에 평탄**.
  평탄성 = memory-bound 지문 (AI=2/b 가 n-독립).
- closed-form roofline (RTX 5070 실측 peak · GPU-ROOFLINE.bench.md):
  AI fp64 0.25 / fp32 0.5 ≪ ridge_fp32 60.96 ≪ ridge_tc 226.1 → 🟢 **MEMORY-BOUND**.
  메모리 천장 = BW·AI = fp64 139.88 · fp32 279.76 GFLOP/s. 단일 GEMV tensor-peak
  도달 불가(GEMM batch 시에만). ⚡ 현실 천장 ≈ 1000–2000× (memory roof).
- verdict 박제: `.verdicts/qforge-perf-roofline/h-apply-membound.txt`
  (🟢 SUPPORTED-NUMERICAL · verifier=roofline_bound.hexa · expect=VERDICT=MEMORY-BOUND).
- 보드 grounding: @goal 캐비엇 갱신 · `## baseline` anchor 섹션 신설 · H_apply GPU-GEMM
  항목에 Δ-baseline 0.140 GFLOP/s + 천장 명기 · scope 섹션에 "측정·박제된 3 항목" 예외.
- 산출물 요약 = domains/QFORGE-PERF.bench.md (provenance + 4 표 + 정직 scope).
- 정직 scope (g6/g63): 측정·closed = baseline wall + roofline 천장 + memory-bound verdict
  3 개뿐. ⚡/🧮/🧠 *구현* 항목은 여전히 `- [ ]` PROPOSAL — GPU pod(전부 STOPPING) +
  stdlib/qforge edit 필요라 이 docs-only 도메인 범위 밖. 각 항목은 자기 hexa bench Δ-vs-
  0.140 을 bench.md 에 게시할 때 closed.

## 2026-06-01 — full closure: all four hot loops grounded (per-call wall baselines)

H_apply(matvec) 하나만 측정돼 있던 baseline 을 보드가 인용한 **네 hot loop 전부**로
확장 — FFT-Poisson · Davidson · Sternheimer 의 per-call wall 분모를 깔아 도메인을
완전 grounding. docs-only (엔진 read-only `use`) · 공유 working tree → 격리 worktree
랜딩 · co-tenant DFT 캠페인 동시 실행(load ~16).

- 드라이버 (bench/qforge/, docs-only · 엔진 무수정):
  - fft_poisson_core.hexa + nz{256,1024,4096} wrapper — `qforge_vhartree_from_drho`.
  - davidson_core.hexa + n{128,256,512} wrapper — `qforge_davidson` end-to-end solve.
  - sternheimer_core.hexa + n{128,256,512} wrapper — `qforge_sternheimer` 1회 eigh
    setup 후 reps CG solve (eigh 는 timed 루프 밖).
- 측정 (per-call wall · **user_s 기준** — 공유 호스트라 real_s 오염, user 가 robust):
  - FFT-Poisson : nz 256/1024/4096 → 11.5 / 217 / 4180 ms (build-anchored reps).
  - Davidson    : n 128/256/512   → 15.2 / 54.7 / 169 ms (~O(n^1.8)).
  - Sternheimer : n 128/256/512   → 15.8 / 107 / 1372 ms (~O(n^2.6) · the el-ph wall).
- 발견 (정직 라벨): FFT-Poisson 의 fft3_real 은 radix-2 FFT(O(N log N), code-inspected)
  인데 per-call wall 은 ~O(N²) (4× nz → ~19× time). 원인 = butterfly 가 아니라 call 당
  O(N) scratch 할당(drho 사본 + spec/vre/vim/back) + 캐시 압박. → cuFFT 이득이 mesh
  크기에 log-linear 예측보다 빠르게 커짐. 알고리즘-복잡도 발견으로 과대주장 안 함(g63).
- 부차 관측 (flagged · not fixed): 큰 grid 반복 FFT 호출 시 메모리 누적 → 부하 하 OOM
  (nz1024@reps150 · nz4096@reps30 사망; single/bounded-reps 는 클린). stdlib/signal·
  runtime 영역 — 본 docs-only 도메인 범위 밖이라 엔진 owner 에게 handoff.
- 보드 grounding: `## baseline` anchor 에 4-loop 표 추가 · @goal/scope 는 직전 단계에서
  이미 갱신됨. bench.md §7 신설 (7a FFT · 7b Davidson · 7c Sternheimer · 7d 커버리지).
- 정직 scope (g6/g63): 네 hot loop 의 **분모**가 이제 전부 측정됨. ⚡/🧮 구현 항목은
  여전히 `- [ ]` PROPOSAL — GPU pod + stdlib/qforge edit 필요(범위 밖). 각자 GPU Δ 를
  게시할 때 closed. = docs-only 도메인에서 가능한 완전 closure.

## 2026-06-01 — domain 100% closure: 5 closed-form corollaries + 21/21 terminal

baseline grounding(4/4 hot loop) 위에, 측정 baseline + memory-bound roofline 의
**closed-form 귀결**로 5개 보드 항목을 GPU·엔진수정 없이 닫음 → 21/21 항목 terminal.

- 검증기: bench/qforge/roofline_corollaries.hexa (결정론 · 항목당 VERDICT_<TAG> 1줄).
  5개 hexa verify → 전부 🟢 SUPPORTED-NUMERICAL · .verdicts/qforge-perf-roofline/:
  - simd-inert.txt    : 🔴 CLOSED-NEGATIVE — memory-bound wall ∝ bytes/BW, compute
    throughput 불변 → SIMD speedup 1.0 (무력). band-loop 지배 커널 = H_apply matvec.
  - mixedprec-2x.txt  : fp32 byte-halving → AI 0.25→0.5 (여전히 ≪ ridge) → 정확히 2×.
    arxiv 6× 는 compute-bound regime 으로 BW-bound 커널에 비적용.
  - multigrid-fav.txt : multigrid V-cycle O(N) ≺ 측정 FFT wall ~O(N^2.1) (§7a). favorable.
  - symmetry-48.txt   : λ=Σ_q w_q λ_q 가 star-sum 복원에 불변(정확) · q-count ÷|Oh|=48
    (LaH10 Fm-3m · CaH6 Im-3m 입방정). Γ-only → q-count=1.
  - threading-10.txt  : 독립 q-point + λ-sum 가환 → Amdahl serial≈0 → min(N_q,N_core)=10.
- 보드 closure: 5 항목 `- [x]` flip + verdict ptr · `## closure status` 21-row terminal
  표 신설(5 closed-form + 4 grounded + 12 gated · 0 ambiguous) · @goal/scope 갱신.
- bench.md §8 (5-corollary 표 + 8a 도메인 closure) 신설.
- terminal 분류 (g63 정직): closed 9 (5 closed-form + 4 grounded 분모) · GATED 12
  (GPU pod 전부 STOPPING · stdlib/qforge edit 타 에이전트 소유 · 🧠 ML 학습 infra) —
  각 blocker + unblock trigger 명시. = docs-only 도메인에서 가능한 100% closure.

## 2026-06-01 — Lanczos vs Davidson closed-MEASURED (docs-only bench)

GATED-IMPL 항목 중 docs-only bench-driver 로 실측 가능한 것을 닫음 — "Lanczos vs
Davidson 비교" (🧮 LANE B · ⚪speculative).

- driver: bench/qforge/lanczos_vs_davidson.hexa — 대칭 Lanczos(full-reorth) 를 bench 에
  구현, 엔진 qforge_davidson 을 read-only 호출, davidson_core 와 동일 결정론 행렬(n=256).
- 측정: 두 솔버 λ₀=1.86294 로 **1e-8 일치** (equal-accuracy gate 통과 → iter Δ 유의미).
  동일 정확도에서 Lanczos 75 matvec vs Davidson 11 preconditioned iter.
- closure: Lanczos 는 이 well-separated spectrum 에서 matvec 이점 없음 — 대각
  preconditioned Davidson 이 압도. **Davidson 유지** (swap-in 불필요). 🟢 verdict 박제.
- 보드: Lanczos `- [x]` flip + verdict ptr · closure-status 갱신 (closed 6 · GATED-IMPL
  5 · 합 21 terminal) · bench.md §8b 신설.
- 남은 GATED-IMPL (5): EPW-Wannier(연구급) · CheFSI(SCF-context Ritz bound 필요) ·
  DIIS-mixing(SCF loop 필요) · randomized(lowest-eig 비표준) · adaptive-q(el-ph 파이프
  필요) — 각 honest blocker. GATED-GPU 4 + GATED-RESEARCH 6 동일.

## 2026-06-01 — 2nd-gen closed-form corollaries (brainstorm-depletion → 완성도 모두 진행)

Brainstorm(6 rounds, depletion) surfaced 28 new ideas beyond the 21 board items;
the closeable-from-docs-only subset (11) was implemented as a second corollary driver
`bench/qforge/accel_corollaries.hexa` (no GPU, engine read-only). All 11 🟢
SUPPORTED-NUMERICAL, verdicts under `.verdicts/qforge-perf-roofline/`:

- RIDGE (nb≥121.9 fp32 / 452.2 tensor to leave memory roof) + AMDAHL (matvec-only GPU
  capped at 1/(1-p)) → closed-form CEILINGS on the 4 GATED-GPU items.
- TCPREC (d ln Tc/d ln λ=0.685, fp32→8e-8) + FP16 (relerr 7e-4 ≪ budget 0.146) →
  precision is Tc-safe (deepens mixedprec); GAMMA (q=0 real → 2×/4×) deepens symmetry-48.
- DIAGCROSS (dense beats Davidson only past M=5N; measured 168≪2560) → iterative favored.
- WANNIER (27× for 12³/4³) · DIIS (√κ=7.07×) · QMC (N_q≥(CV/ε)²=400) → closed-form
  grounding numbers on gated EPW / DIIS / adaptive-q.
- NEW terminal closed items: ECUT (matvec cost ∝ E_cut³ → 10% cut = 27.1%) +
  ADCORR (Allen-Dynes f1·f2 wall fraction ~1.3e-7 → 🔴 optimizing pointless).

Board: 21/21 → 23/23 terminal (8 closed + 4 grounded + 11 gated). The GATED items keep
`- [ ]` (a pod/engine is still needed to MEASURE) but now carry closed-form bounds so
their eventual GPU Δ is interpretable. bench.md §9 documents all 11. docs-only, 0 engine
edits, 0 deletions.

## 2026-06-01 — RIDGE corollary GPU-measured on pool RTX 5070 (pool GPU 활용)

The pool (summer/aiden) carries idle RTX 5070s — the same card as GPU-ROOFLINE.bench.md.
Used summer to empirically validate the RIDGE closed-form corollary via `tool/gpu_qforge_ridge.cu`
(standalone cuBLAS SGEMM nb-sweep at n=4096, NO stdlib/qforge edit):

- HBM 580 GB/s · FP32 34.11 TFLOP/s · measured ridge 58.81 → predicted nb-crossover 117.6.
- nb=1 (H_apply GEMV): **295 GFLOP/s, memory-bound** (HBM 101.8%) = the §3 closed-form ceiling
  (280) confirmed on silicon; ~2100× the CPU-scalar baseline but bandwidth-capped as RIDGE says.
- regime flip memory→compute at **nb=122–144**, dead-on the closed-form 117.6/121.9.
- → RIDGE upgraded from closed-form to closed-form + GPU-measured-validated (bench §10).

Honest scope: cuBLAS PROXY, not the engine GPU-GEMM (still gated on the stdlib/qforge edit). It
grounds the ceiling empirically — does NOT ungate. Board GATED-GPU blocker corrected: the real
blocker is the ENGINE edit, not pod availability (pool GPU is free). docs-only, 0 engine edits.
