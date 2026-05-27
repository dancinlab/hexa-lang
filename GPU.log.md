# GPU 도메인 진행 로그 (append-only)

> SSOT = `GPU.md`(snapshot: @goal + `- [ ]` milestones) + 본 `GPU.log.md`(append-only step log). closure rationale·design note·tier disposition 은 여기에 누적한다. 산재 `tool/*_DESIGN*.md` / `*_CLOSURE*.md` 신규 작성 금지 (단일 SSOT).

## 2026-05-27 — 산재 closure doc 4개 → 본 log 일원화

도메인 SSOT 컨벤션 교정. 아래 산재 doc 의 내용을 본 log 로 흡수 후 제거:
`tool/GPU_NEXT_LIST_R2_DESIGNS.md` · `tool/GPU_NEXT_LIST_R3_CLOSURE.md` ·
`tool/GPU_R5_R10_DESIGN_CLOSURE.md` (+ flame 측 `stdlib/flame/FLAME_BACKLOG_CLOSURE.md` → `FLAME.log.tape`).

### round-4 — RFC 055 §13 transcendental 9-family silicon validation 100%

ubu-2 RTX 5070 driver-JIT 실측 (PTX→ptxas→cuModuleLoadDataEx→libm 비교):

| fn | max_abs_err | tol | range |
|---|---|---|---|
| atan | 1.33e-08 | 1e-7 | [-8,8) |
| tanh | 3.06e-14 | 1e-7 | [-8,8) |
| sigmoid | 2.27e-14 | 1e-7 | [-8,8) |
| sin | 3.54e-06 | 1e-5 | [-π,π) |
| cos | 2.47e-05 | 1e-4 | [-π,π) |
| tan | 7.42e-07 | 1e-5 | [-1,1) |
| exp | 1.16e-11 | 1e-9 | [-5,5) |
| log | 1.00e-07 | 1e-5 | [0.5,4) |
| pow | 1.20e-06 | 1e-5 | [0.5,4) |

PR: codegen #1495(tanh) #1496(sigmoid) #1501(pow) #1524(atan) + 기존 sin/cos/tan/exp/log. fire harness #1536/#1595/#1598/#1603. tol calibration #1604/#1606. **ASCII PTX comment fix #1548** — silicon fire 가 잡은 진짜 버그(ptxas non-ASCII 거부), parse-gate 못 잡음 (fire-gate 교훈 #1320→1322 재입증). sin/cos 는 5-term Taylor spec-한계(tol 1e-5/1e-4) — libm-tight(1e-9) 는 R5-L1 Cody-Waite+minimax follow-up.

### round-2/3 — design+runbook batch + host tool + trig codegen

H1 `ptx_to_sass`(#1453) · H2 `gpu_occupancy`(#1455) · G2 `gpu_regpressure`(#1457) · H3 `gpu_profile`(#1458) — host shell 도구. J1 `gpu_sass_diff`(#1497). round-2 15 milestone(D/E/F/G/H) design+runbook tier closure. round-3 sin/cos/tan f64 codegen.

### round-4 I1 — ubu-2 bootstrap link RESOLVED

`hexa_exit`/`hexa_cuda_available` weak stub 이 main `self/runtime.c`(L13434/L13472)에 정식 정의 → ubu-2 fresh-clone build(module_loader→nvptx_emit) link clean(EMIT_RC=0). E1-E4 fire 경로 열림. **deploy refresh 레시피**: `hexa cc` + `clang -O2 self/native/hexa_cc.c self/runtime.o -o build/hexat` + `cp build/hexat ~/.hx/bin/self/native/hexa_v2`.

### round-5~10 — design-terminal (43 milestone)

🟢 즉시-codegen 9: L1(libm-tight) L2(asin/acos=atan 합성) L3(erf A&S) L4(f32 port) BC3(GEMM+act fused) BC6(bf16+fp8) Q1(int4/nf4) C3(MIR DCE) C4(PTX→SASS) — 9-family·round-3 tool batch 위 즉시 진입.
🟠 design-terminal 34: M1-7(ML algorithm) BC1/2/4/5(cuBLAS beyond) D1-4(multi-GPU env blocker) Q2-4(calibration) I1-7(inference, KV-cache 선결) C1/2/5/6/T1/3/5(graph-IR 선결).

**cuBLAS 추월 honest**: standalone GEMM = roofline 동률(g3 "사실상 불가"). **fusion(BC3, fusion-AxisA LayerNorm66%/RMSNorm59%/Softmax65%/SwiGLU63% 선례)+IO-aware(BC4 FlashAttn v3)가 진짜 격차** — attention 은 round-3~7 에서 5-15× slower 출발, BC4 IO-aware 가 break-even 유일 경로(N204 roofline-GEMM transplant 실패가 입증).
