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
