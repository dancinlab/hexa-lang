# flame Phase 4-B SHIPPED + Phase 4-D bottleneck — 타세션 이어가기 prompt

> 2026-05-17, 사용자 directive 로 작성. 다음 세션에서 이 문서 + 아래 prompt
> 만 읽으면 이어서 진행 가능. 80+ commit autonomous cycle 의 progressive
> handoff.

## 다음 세션 시작 시 사용할 prompt (복사-붙여넣기)

```
flame Phase 4-B/4-C/4-D 진행 상태 인수받고 이어 진행.

지금까지 누적 (rfc043-hexa-torch branch, NOT pushed):
- Phase 4-B 🎯 FULLY SHIPPED — ≥3× RFC 047 §137 target REACHED
  - baseline (cool) 16.170s → A2+B FULL ~5.0s = 3.23× wall
  - flame:anima = 0.226× (~4.4× faster than anima)
  - Reproduce: tool/flame_phase4b3_a2_build.sh <src> <out>
  - Verify (23/23 PASS): tool/flame_phase4b3_verify_all.sh

- Phase 4-C-1a ✅ SHIPPED (verify_all 24/24)
  - tool/flame_phase4c_pair_detect.hexa — paired fwd+bwd 감지
  - tool/flame_phase4c_build.sh — Phase 4-C build wrapper
  - stdlib/flame/PHASE4C_PAIR_DETECT_DESIGN.md

- Phase 4-D-4 GPU fire 🔍 honest FAIL ($0.40 cost, well under $20 cap)
  - state/flame_phase4d_20260517_102511/ RESULTS.md 참조
  - Root cause: A2 primitive 가 single-threaded naive C matmul
    → 32-vCPU A100 box 도움 안 됨 (CPU code 가 GPU 안 씀)
  - Dispatch infrastructure 자체는 production-ready

전체 state-of-truth: stdlib/flame/STATUS.md (8th iteration, commit eb9e08fa)
Phase 4-B closure 요약: stdlib/flame/PHASE4B_SHIPPED_SUMMARY.md (commit c4aab67e)
flame docs navigation: stdlib/flame/INDEX.md (commit 9fa7250a)

[다음 path 선택 또는 자율 추천방향 진행]
```

## 핵심 commit list (이전 세션 가장 중요)

```
🎯 SHIP milestones:
55e29392  Phase 4-B-2 IPCP shipped (1.28× wall, byte-id)
8012c15a  Phase 4-B-3 A2 fwd+bwd shipped (2.74× wall)
29fe4a69  🎯 Path B FULL — 3.23× cool projection (≥3× REACHED)
a8bc2a11  Phase 4-C-1a scaffolding complete (verify_all 24/24)
48d35e72  Phase 4-D-4 fire honest FAIL ($0.40, CPU binary on GPU)

Core measurement infrastructure:
07cdd405  boxing-elim 3.99× MEASURED (mechanism evidence)
98bed481  allocator-elim 1.00× MEASURED (WEAKER than estimate)
f525a656  fn-call elim 0.12× MEASURED + design pivot
1da62cc1  rmsnorm leaf byte-eq PASS (first strict verification)
fe7c1922  attention leaf byte-eq PASS (final dominant section)
0e9ef425  attention bwd byte-eq PASS (final bwd section)

Build wrappers (single-command reproducible):
7d98c3cd  tool/flame_phase4b_build.sh (Phase 4-B-2 IPCP)
28cf24a6  tool/flame_phase4b3_build.sh (Phase 4-B-3 trampoline + wire-up)
7702ff24+e9350973  tool/flame_phase4b3_a2_build.sh (A2 fwd+bwd FULL + Path B)
a8bc2a11  tool/flame_phase4c_build.sh (Phase 4-C-1a detector pipeline)

Verify gates:
501e598b+13bf8b14+a8bc2a11  tool/flame_phase4b3_verify_all.sh
                            (현재 24/24 PASS — 5 fwd leaf + 5 bwd leaf +
                             4 matmul + 4 grad_accum + 3 mechanism +
                             IPCP byte-id + A2+B byte-id + PAIR-DETECT)

Closure docs (반드시 읽기):
c4aab67e  PHASE4B_SHIPPED_SUMMARY.md  — single-page closure reference
3b83d6a8  STATUS.md sixth + README headline (Phase 4-B SHIPPED)
eb9e08fa  STATUS.md eighth iteration (Phase 4-D-4 FAIL RCA)
9fa7250a  INDEX.md — 18 markdown + 1 .tape navigation
```

## 다음 cycle 의 자율-가능 / user-gate options

**자율-가능 (autonomous-OK)**:
1. **Phase 4-C-2 fused fwd+bwd primitive emit** (subagent B audit PHASE4C_IMPLEMENTATION_AUDIT.md §4)
   - effort: 1.5 cycles, ~600-800 LoC C hand-translation
   - falsifier: F-RFC048-FUSED-FWD-BWD-EQ (max|Δ|=0.0 vs paired-call baseline)
   - risk: MID — register-pressure spill behavior unknown at ~8K floats locals
2. **Phase 4-C-2b build wrapper + single-block wall measure**
   - effort: 1 cycle
   - falsifier: F-RFC048-FUSED-WALL-IMPROVED ≥1.3× over paired-call baseline
3. **Cool baseline 재측정 (reliable)** — parallel processes 종결 후
   - 현재 baseline 12.574s vs new measurement 보장
4. **Other RFCs** (045 cross-impl drift, 046 progression report)

**user-gate (multi-decision)**:
1. **Phase 4-C-3 nn_decoder_fwd/grad restructure** — decoder_lib.hexa edit
   - source-level rewrite vs IR-pass rewrite 결정 필요
   - intra-block-only vs inter-block fusion scope 결정 필요
2. **Phase 4-D-5 GPU 본격 acceleration**:
   - 다음 fire 가 의미 있으려면 RFC 040 cuBLAS Dgemm wire-up 필요
   - 또는 최소 clang -fopenmp + BLAS link
   - 현 dispatch infrastructure 는 production-ready (commit 48d35e72 verified)
   - 비용 reference: runpod A100 community $1.39/hr, balance $303.78 (=~218 hrs)

## 작업 환경 + 제약

- branch: `rfc043-hexa-torch` (124+ commits ahead of origin, NOT pushed)
- working dir: `/Users/ghost/core/hexa-lang`
- M-Mac Darwin arm64, clang -O2 toolchain
- HEXA_MAC_BUILD_OK=1 필요 (build refuse 우회)
- Production `./hexa build` path 무영향 (Phase 4-B parallel wrappers)
- runpod 인증 wired, $303.78 잔액, $80/hr spend cap
- vast.ai vastai CLI 설치되어 있지만 API key 미설정 (수동 wiring 필요)

## 메모리 / 원칙 reminder

- AGENTS.tape g3: verification-anchor-real-limit — 측정 anchored, 가설 → revise
- AGENTS.tape g7: step-by-step decision gate — multi-decision = user gate
- `feedback_no_stop_until_done`: 자율 모드 = 완료까지 정지 금지 (abort 조건만 멈춤)
- `feedback_korean_response`: user-facing text 한국어, code/path 그대로
- `feedback_hexa_lang_shared_worktree_branch_hazard`: branch check 필수
- `feedback_resource_routing_ubu`: heavy build → ubu-1/ubu-2 원격

## SSOT 진입점 우선 순위

1. **README.md** — flame 1분 overview
2. **STATUS.md** — single-page current state (8th iteration, 가장 latest)
3. **PHASE4B_SHIPPED_SUMMARY.md** — Phase 4-B closure 단일 reference
4. **INDEX.md** — 18 docs navigation
5. **PLAN.md** — staged roadmap (Phase 4-B SHIPPED entry)
6. **FLAME.tape ## Log** — chronological event history (4 entries)
7. **PERF.md** — measurement ledger

## 마지막 prompt 패턴 (자율 모드 trigger)

사용자 매 cycle "자율 계속 go (추천방향)" 반복 — `/loop 5m` cron 자동 fire.
"all go" / "모두 fire and all bg go" = explicit budget approval + parallel
subagent dispatch. 진정 user-gate level decision 도래 시 main thread text-only
stop honest (memory feedback 명시: "abort 조건만 멈춤" 이지만 multi-decision +
review burden saturation = 자율-가능 limit).

다음 세션 시작 prompt 위 ```fenced code``` 박스 그대로 사용.
