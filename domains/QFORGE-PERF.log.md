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
