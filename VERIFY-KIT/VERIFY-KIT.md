# VERIFY-KIT — verify primitive 확장 도메인 (도메인 SSOT)

@title: 🔧 VERIFY-KIT — 측정 도구함 확장 ("verify primitive 키트")
@goal: `hexa verify` 의 계산 primitive 를 단계적으로 확장 — value-less compute mode · 특수함수(Γ·erf·bessel·ζ) · IIT Φ 엔진 · tolerance verify · plugin verifier. catalogue-mirror(OEIS·DLMF·ARXIV) 흡수의 공통 upstream. 흡수가 부딪힌 "측정 도구 부재(P3 coverage wall)" 를 푼다.

> 흡수 family upstream: OEIS(정수 primitive ✓ 흡수성공) · DLMF(특수함수 ✗ 🔴) · ARXIV(Φ ✗ 0-verify). 셋 다 같은 뿌리 = hexa verify 에 도메인 primitive 부재. VERIFY-KIT 가 그 primitive 를 키운다.

## 0 · 한 문단 상태 (2026-05-26 개시)

`hexa verify --expr <fn> <n> <v>` 는 값 `<v>` 를 미리 줘야 재확인만 함 (compute 불가). V2 가 value-less compute mode 신설 → `σ(7)=8` 을 CLI 가 직접 산출. 이후 특수함수·Φ·tolerance 로 확장해 DLMF/ARXIV 흡수를 재개시한다. 우선순위 P0(미러통합·compute) → P1(특수함수·tolerance) → P2(IIT Φ) → P3(자동등록·조합론) → P4(plugin·물리) → P5(PSLQ·bignum·symbolic).

## 1 · 로드맵 (P0-P5)

- [x] V1 (P0a) — 미러통합: register delegation → allen_dynes_tc atlas 흡수 가능 (INBOX RTSC unblock). root fix(proposal a) — `register --from-verify` 가 `hexa verify --expr … --compute` 로 위임(atlas 미러 의존 0); float `cmd_expr_float` 에 value-less COMPUTE mode 추가 + `cmd_register` 가 value-bearing 🟠(arity miss)→compute auto-route + 명시 `--compute`. 흡수 acceptance 통과: allen_dynes_tc(0.615,591.18,0.1)=14.5511 🟢 (was 🟠). RTSC 3-arg 16-fn class unblock.
- [x] V2 (P0b) — value-less compute mode: `hexa verify --expr <fn> <n>` (값 생략) = 계산+출력 (B1 unblock · OEIS O3) ← 이번 PR
- [ ] V3 (P1a) — tolerance verify: `--approx <fn> <x> <v> <eps>` 연속값 ε 비교 (🟢)
- [ ] V4 (P1b) — 특수함수 stdlib `stdlib/special/`: gamma·erf·bessel·zeta (libm 기반) → DLMF 재개
- [ ] V5 (P2) — IIT Φ 엔진 `stdlib/consciousness/iit4/` n≤8 exact (PyPhi calibrate · anima 공유 g61) → ARXIV A2
- [ ] V6 (P3a) — primitive 자동등록 `register --from-selftest`
- [ ] V7 (P3b) — 조합론/소수 fn: catalan·bell·stirling·partition·nextprime·factorint·radical
- [ ] V8 (P4a) — verifier plugin `--verifier-cmd` (phanes "tenants bring verifier" 연결)
- [ ] V9 (P4b) — 물리 primitive: Penning 트랩 주파수·cyclotron·antihydrogen binding (demiurge)
- [ ] V10 (P5) — 난제 묶음: PSLQ·연분수·arbitrary-precision(bignum)·symbolic 항등식·수치적분

## 2 · 거버넌스
- verify 정본 g5. 새 primitive 는 단일 home (미러 desync 금지). codegen 변경 = `hexa cc --regen` 경로 (hexa_cc.c 직접편집 금지).
- catalogue 흡수 도메인(OEIS/ARXIV)이 downstream consumer — primitive landing 시 그쪽 milestone unblock.

## 3 · 비범위
- GPU-accel verify · distributed verify farm (실행 인프라 — 도구 확장 아님).
- LLM 자기판정 (g5 위반).
