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
