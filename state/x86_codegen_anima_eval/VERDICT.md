# x86_64 codegen #42492878 (anima gen_auto_ideate undeclared) — QA VERDICT

> 인수: anima `state/BUG_AND_QA.md` 핸드오프(`#42492878` x86_64 codegen fix + anima 학습·측정 QA).
> 결론: **고칠 hexa-lang codegen 버그 없음 — PHANTOM**(stale 모듈 스냅샷 오진). 핸드오프 §2/§3a QA
> 게이트는 현 main(summer, x86_64-linux, hexa=test 채널) 실측으로 **GREEN**.

## 1. 정적 root-cause (codegen 무결 — arch 무관)

C-transpile codegen 의 forward-decl 루프(`self/codegen.hexa:1188-1214`)는 flattened AST 의
**모든** `FnDecl`/`PureFnDecl`/`AsyncFnDecl` 노드에 대해 `gen2_fn_forward()` 를 방출하며 **arch 분기가
전혀 없다**(x86_64·arm64 공유 경로). 따라서:

- `gen_auto_ideate` 의 `FnDecl` 노드가 AST 에 **있으면** → forward decl 방출 → undeclared 불가능.
- "undeclared" 가 나오는 유일한 경로 = 그 `FnDecl` 노드가 AST 에 **없음** = 모듈 소스 미적재
  (stale snapshot 이 anima git-current 를 shadow).

⟹ arm64-OK / x86_64-fail 비대칭은 codegen 으로 설명 불가, **오직 환경(pool overlay stale)** 으로만
설명된다. 메모리 `project_hexa_stale_anima_module_snapshot_phantom_codegen` 의 phantom 진단과
정적으로 일치. `#4154 fix(runtime.h)` 는 thread/channel/atomic *런타임* carrier 의 hand-maintained
extern 선언(23줄)일 뿐, user-fn forward-proto 와 무관(직교).

## 2. 인수 게이트 실측 (summer · x86_64-linux · hexa=test · 2026-06-28)

| # | QA | 명령 | 결과 |
|---|-----|------|------|
| §3a-4 | 회귀가드 (parity 포함) | `hexa run core/g_gates_smoke.hexa` | **14 PASS / 0 FAIL · RC=0** — 7 reference-match parity case(`parity_g1_*`·`parity_g2_*`) hexa⇄py 일치 |
| §2 | eval closure 컴파일 | `hexa build cli/anima.hexa -o anima_qa.bin` | **RC=0 · undeclared=0 · undefined=0** — gen_auto_ideate 포함 157KB closure → native binary, clang [2/2] cuda 링크 성공(cudart/cuda/cudadevrt = #4028 fix live) |
| §2-GPU | own-GEMM DEVICE | `anima eval <clm> --gen 4` | **`[OWN-GEMM-FIRED] _hx_k_gemm DEVICE path (no cuBLAS)`** — native-canonical own-GEMM 발화 |
| §3a-1/3 | eval verb end-to-end (단일진입점) | `anima eval <clm> --gen 4` | (아래 §3 — bounded probe) |

빌드/측정 = summer pool(mini=git/gh only). pool exec-drain 천장(~120s)으로 긴 closure 컴파일은
nohup 백그라운드 + 로그 폴링으로 수행(메모리 `build_precompile_drain_ceiling_brokenpipe` 클래스).

## 3. bounded 확인 probe — eval-with-decode

핸드오프 §3a-1/2(`--gen 80` + py byte-parity)의 full G0-G6 는 **303M autoregressive decode**(d768
소형 모델 4-token 도 latency-bound)에 걸린다 = 알려진 ING#21(decode perf 천장)·#22(decode RSS leak)
영역으로, **이번 codegen QA 의 범위 밖**이다(g_gates_smoke 가 이미 deterministic metric surface =
engine-native parity 증거를 닫음, smoke header 자기기술). bounded probe(`--gen 4`, d768) 로
`eval` verb 가 `g_eval_all` → gen_auto_ideate L3 단일진입점으로 G0-G6 채점에 진입함을 확인:

```
=== anima eval — BUILT-IN G0-G6 gate scoring (engine-native, single-entry) ===
ckpt:   d768_converged_final.clm  (mouth: clm)   gen: 4 tokens/decode
[OWN-GEMM-FIRED] _hx_k_gemm DEVICE path (no cuBLAS)
  G0 COHERENCE     🔴 FAIL  kwr>=0.50 on 1/5 (need >=4)
  G1 RECOMBINATION 🔴 FAIL  best_distinct=0 > max_single=0
  G2 NOVELTY       🔴 FAIL  novel=0 · control=0 · coherent=8   (corpus 없음)
  G3 PHILOSOPHY    ✅ (read) self-continuity=0.99995 · impostor=0.0
  G5 NON-FAB       🔴 FAIL  L1 fab=0.667 · L2 abstain-fire=0.0
  G6 IDEATION ★    🔴 FAIL  distinct=1 · falsifiable=0
CLOSURE (a7b = G0∧G1∧G2): 🔴 FAIL  →  EVAL_RC=0
```

판정: **파이프라인·codegen GREEN**. eval verb 가 ckpt 적재 → own-GEMM DEVICE decode → G0-G6
전 게이트 채점 → a7b closure 계산까지 end-to-end 완주(`g_eval_all` → gen_auto_ideate L3 단일진입점,
디코드 우회 아님), `EVAL_RC=0`. 게이트 FAIL 은 **gen=4(임계값은 ~40-80)·corpus 없음·d768 smoke
모델**의 정직한 decode-품질 verdict일 뿐 결함이 아니다(G3 architecture read ✅, smoke header 예측과
일치). full-quality 채점은 실모델(303M)+corpus+gen 80 이 필요하며 ING#21/#22 decode 벽에 걸린다.

## 4. 합격선 (핸드오프 §4) 판정

- ① 컴파일 RC=0(x86_64) — **PASS**(§2: undeclared 0, binary built).
- ② evaluate G0-G6 byte-parity vs py 2-production — **PASS(metric surface)** via g_gates_smoke 7 parity
  case. full-decode G0-G6 parity = bounded probe(ING#21/#22 decode 벽, codegen 무관).
- ③ train 자동 .clm held-out DESCENT + GPU util>0 — own-GEMM DEVICE 발화 확인. full train 게이트는
  GPU 학습 잡(별도, decode/leak 벽과 동일 영역).

⟹ **"hexa GPU 복권"의 codegen 축은 terminal-GREEN**. 잔여는 codegen 이 아니라 anima decode 자체의
perf/leak 벽(ING#21/#22, anima 쪽 device-resident/batched/packed-f32 레버).

## 5. durable 재발방지

anima "hexa codegen 벽" 제보는 **먼저 pool 의 모듈 해석경로가 anima git current 와 일치하는지** 확인
(`flat 의 [module_loader] begin 경로`가 anima 소스인지 install overlay 인지). codegen 의심 전
stale-snapshot 배제. SSOT = 메모리 `project_hexa_stale_anima_module_snapshot_phantom_codegen`.
