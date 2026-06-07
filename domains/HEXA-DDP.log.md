# HEXA-DDP — step log (append-only)

## 2026-06-07 — domain init
- Registered the multi-GPU data-parallel (DDP) workstream as a distinct domain (separate from [[HEXA-FUSION]] which is single-GPU util/own-GEMM). 6 milestones DDP-M1..M6 in dependency order.
- Probe finding: flame DDP/all-reduce is docs-only (self/forge/PARADIGM.md·PLAN.md·README — NO collective impl in stdlib/flame); pod rent pattern is num_gpus=1 only. So DDP needs BOTH the hexa-native collective (M1, hardware-free) AND multi-GPU rent infra (M2, hardware wildcard).
- Honest (g5): parallel = throughput, N-GPU speedup always < N× (Amdahl + comm). byte-eq gate (1-GPU == N-GPU) before any speedup. NCCL/cuBLAS = roofline. Single-GPU efficiency already banked by HEXA-FUSION (own-GEMM TF32 PARITY #2870 + conv cure #2868).
- First lever = DDP-M1 (ring-all-reduce hexa-native, 2-rank in-process sim, byte-eq) — buildable NOW with no multi-GPU hardware.

## 2026-06-07 — DDP-M1 GREEN (ring-all-reduce hexa-native, hardware-free)
- Built `stdlib/ddp/ring_all_reduce.hexa`: canonical ring all-reduce over N ranks modelled as N rows of one host buffer (rank r at r*S). Phase 1 reduce-scatter (N-1 steps) + Phase 2 all-gather (N-1 steps). Each step materialises a staging buffer so the simultaneous P2P sends of one ring step don't clobber each other intra-step (matches what real transport guarantees). Chunk partition `ring_chunk_start` handles S not a multiple of N (first S%N chunks get +1 element). Transport = in-process array copy (`t_get`/`t_set` host farr) — M3 swaps this copy for cudaMemcpyPeer/NVLink P2P, schedule unchanged.
- Test `stdlib/ddp/ring_all_reduce_test.hexa`: in-process N-rank sim, distinct deterministic seed per (rank,index) so a wrong chunk/offset surfaces as non-zero Δ. Compares every rank's row against a serial elementwise sum.
- **GATE (g5) GREEN**: 9/9 pass. byte-eq max|Δ|=0 FP64 for N∈{2,4} with S NOT a multiple of N (S=7→4,3 · S=10→3,3,2,2 · S=13→4,3,3,3) plus even S=64. Step count `ring_step_count(N)==2(N-1)` asserted (N=2→2, N=4→6, canonical optimum). Verdict verbatim: `.verdicts/hexa-ddp-m1/F-DDP-RING-BYTEEQ.txt`. Built+ran locally (clang -O2 native, exit 0).
- **HONEST (g5) — scope boundary**: M1 proves the COLLECTIVE ALGORITHM is bit-exact vs serial sum. It does NOT mean parallel training runs. Real multi-GPU transport (P2P/NCCL) = DDP-M3; multi-GPU hardware = DDP-M2 (the wildcard). M1 GREEN unblocks M3 (only the transport leg remains to swap in).
- Falsifiers held: F-DDP-RING-BYTEEQ (sim == serial sum, max|Δ|=0) · F-DDP-RING-STEPS (2(N-1)).

## 2026-06-07 — DDP-M2 INFRA-READY (multi-GPU rent param + topo probe + availability wildcard)
- **num_gpus parametrized**: `tool/ddp_rent_lib.sh` (new, sourceable). `ddp_gpu_pred()` builds the vastai search-offers GPU-count predicate from env `DDP_NUM_GPUS` (default 1). Found the hardcode pattern: every `tool/dispatch_*.sh` literal-embeds `num_gpus=1` in its `vastai search offers '...'` filter (17 scripts) + docs in `stdlib/cloud/vast.hexa` / `stdlib/flame/PHASE4D_DISPATCH_CLI_GUIDE.md`. Rather than touch the single-GPU campaigns, factored the count into one shim a DDP dispatch sources.
- **1-GPU path byte-eq (gate)**: unset / `DDP_NUM_GPUS=1` → `ddp_gpu_pred` emits the EXACT literal `num_gpus=1` (printf, no variation) — byte-identical to the legacy hardcoded token. `>=2` → `num_gpus>=N` (single node, N+ GPUs — DDP needs them on ONE node for cudaMemcpyPeer P2P, not 2 separate pods). Tested: default/=1/=2/=4/bad-value all correct; bad value warns→1 (never silent-bad). DDP-capable opt-in is purely additive.
- **topo probe**: `tool/ddp_topo_probe.sh` (new). Runs `nvidia-smi topo -m` on-pod, emits the verbatim matrix (SSOT) + parses each GPU-GPU cell to NVLink (NV#/NVLINK) / PCIe (PIX/PXB/PHB) / SYS(cross-NUMA NODE/SYS) → a per-pair transport list + a one-line DDP-transport verdict for the first N GPUs (DDP-M3 reads this to pick cudaMemcpyPeer vs host-staging). awk parser verified against synthetic 2-GPU (NVLink) and 4-GPU dual-NUMA (mixed NVLink/SYS) matrices.
- **WILDCARD FACT (read-only vast probe, NO rent)**: `vastai search offers 'num_gpus>=2 ...'` → **64 live 2-GPU offers**, 35 of them NVLink-class (SXM/NVL) & reliability>0.97. Cheapest reliable NVLink **2x A100_SXM4 = $1.4676/hr** (0.997 reliab, ID 35422818); cheapest any-2GPU = $1.2014/hr (2x A100_PCIE). 2x H100_SXM ≈ $2.93/hr. Verbatim raw JSON + analysis: `.verdicts/hexa-ddp-m2/{availability_probe.md,vast_2gpu_offers_raw.json}`. runpodctl present but it's a pod-mgmt CLI (no market search); vast data is authoritative.
- **topo MATRIX = DRY-RUN (g5 HONEST)**: real `nvidia-smi topo -m` needs a live pod; did NOT rent (optional + STORM/leak discipline). Exact leak-0 capture command (search→rent→ssh probe→destroy exact-ID) recorded in availability_probe.md; real matrix = DDP-M3 TODO. Did NOT fake a topo result.
- **HONEST scope boundary (g5)**: M2 delivers infra-readiness + the price/availability FACTS the user needs to decide the wildcard. It does NOT assert multi-GPU TRAINING runs — that is DDP-M3 (P2P all-reduce) + DDP-M4 (1-GPU vs 2-GPU byte-eq). Actual renting + multi-hour spend = the USER's decision; the hardware is available and cheap, so it is not a blocker.

## 2026-06-07 — DDP-M3 GREEN (real 2-GPU ring all-reduce over P2P transport)
- Swapped M1's in-process sim-transport for a REAL inter-GPU transport: `stdlib/ddp/m3_p2p/ring_p2p.cu` keeps the DDP-M1 canonical ring (2(N-1) steps, `chunk_start` partition identical to ring_all_reduce.hexa) and replaces only the per-step "send chunk to neighbour" with a real device-to-device `cudaMemcpyPeer`. Each rank's FP64 vector lives in its own GPU's device memory; reduce-scatter adds via a CUDA kernel, all-gather overwrites. On-pod runner `stdlib/ddp/m3_p2p/run_m3.sh` captures topo + canAccessPeer + builds + runs. Reuses DDP-M2 tooling (tool/ddp_topo_probe.sh, tool/ddp_rent_lib.sh).
- Hardware: vast.ai instance 39786751 = 2x NVIDIA GeForce RTX 3090 on ONE node, driver 535.54.03 / CUDA 12.4 / sm_86. (Forward-compat libcuda shadowed the system driver — resolved with LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu.)
- **GATE (g5) GREEN**: result on every GPU == serial elementwise sum, **byte-eq max|Δ|=0** for N=2, both S=7 (S%N=1, boundary chunking) AND S=1<<20 (large). Verdict verbatim: `.verdicts/hexa-ddp-m3/F-DDP-M3-REAL-P2P-BYTEEQ.txt`.
- **TRANSPORT FINDING (honest)**: nvidia-smi topo -m = PHB (PCIe host-bridge, NOT NVLink — no NV# bond). `cudaDeviceCanAccessPeer(0<->1)=0` both directions → GeForce direct P2P is driver-disabled on this topology, so cudaMemcpyPeer routed through a host-staged copy. Correctness is identical (the ring schedule is transport-agnostic); the perf caveat is that this leg ran without direct NVLink/PCIe-P2P bandwidth. An NVLink-bridged or datacenter node would exercise the direct path — same schedule, same byte-eq gate, faster wire.
- Pod DESTROYED immediately after capture (leak 0, exact-ID; foreign rtsc-li2mgh16-anchor + a pre-existing unlabeled instance left untouched).
- **HONEST (g5) — 관문3 status**: M3 GREEN = the COLLECTIVE works on real multi-GPU hardware byte-exact → 관문3 TRANSPORT HALF CLOSED. NOT yet end-to-end parallel training: DDP-M4 (1-GPU vs 2-GPU same-model byte-eq over a real flame step) and DDP-M5 (4-GPU scale + speedup) remain.

## 2026-06-07 — DDP-M4 GREEN (end-to-end DDP training byte-eq: 1-GPU step == 2-GPU DDP step)
- Closed the g5 HARD GATE: for the SAME global batch + SAME seed, a 1-GPU training step produces byte-identical weights/loss to a 2-GPU DDP step (split batch, local grads, ring SUM all-reduce, identical /B scale + SGD update). `stdlib/ddp/m4_train/ddp_train.cu` + on-pod runner `run_m4.sh`.
- Model (small, exactly reproducible, FP64): 3-layer MLP 16→32→32→8 (ReLU, ReLU, linear), MSE loss vs a fixed deterministic target. NPARAM=1864. B_GLOBAL=64 split 32/32 over world_size=2. LR=0.01.
- The reference is ORDER-MATCHED to the ring (shard-partials s_0 + s_1 then /B), so the gate is a TRUE max|Δ|=0 byte-eq, not a tolerance check — FP non-associativity is sidestepped because data-parallel equivalence IS defined as same global batch / same per-shard partials / same reduction order, which is exactly what the ring computes. The DDP leg carries the per-rank grad SUMs over the M1 ring schedule with M3's real cudaMemcpyPeer device-to-device transport, then every rank applies the same 1/B scale and the same SGD update.
- Hardware: vast.ai instance 39793396 = 2x NVIDIA GeForce RTX 3060 on ONE node, CUDA 12.2 / sm_86. topo = PHB (PCIe host-bridge), cudaDeviceCanAccessPeer(0<->1)=0 → P2P driver-disabled → cudaMemcpyPeer host-staged. Correctness is transport-independent (the ring schedule is the same regardless of wire).
- **GATE (g5) GREEN — all four sub-gates byte-exact (max|Δ|=0)**: WEIGHTS W_ddp vs W_ref = 0 (BYTE-EQ PASS); loss_ref == loss_ddp = 2.1718481686851199 (match 0); averaged grad g_ddp vs g_ref = 0; rank-agreement W1==W0 = 0 (all ranks identical). Verdict verbatim: `.verdicts/hexa-ddp-m4/F-DDP-M4-TRAIN-BYTEEQ.txt`.
- Pod DESTROYED immediately after capture (leak 0, exact-ID 39793396 labeled hexa-ddp-m4; foreign rtsc-li2mgh16-anchor instance 39610026 left untouched).
- **VERDICT (the "new frontier")**: parallel TRAINING byte-exact is DONE — 1-GPU == 2-GPU DDP at the weight level, proving the data-parallel correctness invariant (grad-of-sum = sum-of-grads, scaled) on real 2-GPU hardware. **HONEST (g5)**: this is a small model + single step; full 7B DDP, multi-step gradient accumulation, and 4-GPU speedup (DDP-M5) remain out of scope, but the reduction algebra is scale-invariant. The deferred piece is the flame-trainer wiring at real model scale (M5+); M4 proves the transport+reduction+step pipeline byte-exact on the canonical small model.

## 2026-06-07 — DDP-M5 collective leg GREEN (real 4-GPU ring all-reduce + scaling)
- Extended M3's real-P2P ring from 2 → 4 ranks: `stdlib/ddp/m5_4gpu/ring_p2p_m5.cu` keeps the DDP-M1/M3 canonical ring (2(N-1) steps, `chunk_start` partition + send_chunk/recv_chunk/all-gather formulas byte-identical to M3) and only changes the rank count (env `DDP_NUM_GPUS`, default 4) + adds cudaEvent timing of the comm loop for the N=2 vs N=4 scaling sweep. Per-step transport is still a real device-to-device `cudaMemcpyPeer`. On-pod runner `stdlib/ddp/m5_4gpu/run_m5.sh`.
- Hardware: vast.ai instance 39793429 = 4x NVIDIA GeForce RTX 3060 on ONE node, nvcc 12.4.131 / CUDA 12.4 / sm_86 (image nvidia/cuda:12.4.1-devel-ubuntu22.04).
- **GATE (g5) GREEN**: result on every GPU == serial elementwise sum, **byte-eq max|Δ|=0** for N=4, both S=13 (S%4=1, boundary chunking — NOT a multiple of N) AND S=1<<20 (large). step-count 2(N-1)=6 confirmed. Verdict verbatim: `.verdicts/hexa-ddp-m5/F-DDP-M5-4GPU-COLLECTIVE.txt`.
- **SCALING (g5, measured not modeled)**: same total bytes S=4194304 (32 MiB/rank), median of 5 warm reps. N=2 all-reduce wall 22.2413 ms (per-step 11.1206 ms, 2 steps); N=4 wall 58.7016 ms (per-step 9.7836 ms, 6 steps). The WALL grows 2.64× as N goes 2→4 because the step count tripled; the PER-STEP wall is roughly flat — consistent with near-constant per-rank bandwidth while latency grows with step count. Host-staged transport.
- **TOPO FINDING (honest)**: nvidia-smi topo -m = GPU0/1/2 PHB (PCIe host-bridge, NUMA node 0) + GPU3 SYS (cross-socket SMP interconnect, NUMA node 1); NOT NVLink. `cudaDeviceCanAccessPeer==0` on all 12 directed pairs → GeForce direct P2P driver-disabled → every cudaMemcpyPeer routes host-staged. Correctness identical (ring schedule transport-agnostic); perf caveat = no direct NVLink/PCIe-P2P bandwidth.
- Pod DESTROYED immediately after capture (leak 0; label "hexa-ddp-m5" confirmed before destroy; foreign rtsc-li2mgh16-anchor left untouched).
- **HONEST (g5)**: M5 collective leg GREEN = the ring all-reduce COLLECTIVE scales to 4 REAL GPUs byte-exact, with schedule + step count + per-step wall measured. This is NOT 4-GPU end-to-end training speedup — 4-GPU byte-exact collective ≠ 4-GPU training speedup. That = DDP-M5b (chains on DDP-M4). Expected N-GPU speedup < N× (communication tax; g83), and on this node the transport was host-staged (correctness-grade wall, not bandwidth-optimal).

## 2026-06-07 — DDP-M5b 🟢 GREEN (4-GPU end-to-end training speedup; composes M4 step + M5 ring)
- Composed DDP-M4 (the flame MLP fwd/bwd train step + grad ring all-reduce, 1==2 GPU byte-eq) with DDP-M5 (the canonical 4-rank ring) into one harness: `stdlib/ddp/m5b_speedup/ddp_train_m5b.cu` + `run_m5b.sh`. Runs the SAME global batch (B=64) split across N=1/2/4 ranks, all-reduces the grad over the real cudaMemcpyPeer ring, times the per-step training wall, and runs the N=4 byte-eq gate.
- NODE: vast 4x RTX 3090 (instance 39798076, machine 39565), nvcc 12.4.131 / sm_86. Pod DESTROYED after capture (leak 0; label "hexa-ddp-m5b" + project-tag confirmed mine; the 3 other instances — rtsc-li2mgh16-anchor + two hexa-ddp-m6 from another agent — left untouched).
- **GATE 1 CORRECTNESS (g5 HARD) — byte-eq max|Δ|=0**: 1-GPU W_ref == 4-GPU W_ddp on the SUMMED grad (0), every post-step WEIGHT (0), and across all 4 ranks (0, all identical). The M4 DDP invariant (mean-loss grad = SUM of per-sample grads / B; shard B over W ranks, all-reduce-SUM, /B everywhere ⇒ the exact 1-GPU grad) extended N=2→4.
- **N=4 FP-ASSOCIATIVITY content (the real engineering of this gate)**: the ring reduce-scatter sums each chunk's 4 partials in a chunk-dependent RIGHT-nested tree, NOT a flat left fold — a 4-rank simulation of the actual `d += staging` parenthesization gives chunk0=(3+(2+(1+0))), chunk1=(0+(3+(2+1))), chunk2=(1+(0+(3+2))), chunk3=(2+(1+(0+3))). A naive left-to-right reference (((g0+g1)+g2)+g3) differs at the ULP (measured 1.42e-14 then 3.55e-15 on this node before the fix) — PURE associativity, not transport error. Reducing the 1-GPU reference with the SAME per-chunk right-nested tree drives the gate to a TRUE max|Δ|=0. (N=2 has a single add → M4 was trivially order-invariant; the tree only bites at N≥3, so this is the genuine N=4 content.)
- **GATE 2 SPEEDUP (median 30 reps, 5 warmup discarded, per-step wall = fwd+bwd+all-reduce+sync, model-size sweep H={64,256,1024,2048})**: per-step wall (verbatim) — H=64: N1 0.4984ms N2 0.5660ms N4 0.8197ms; H=256: 1.9139/2.3802/3.0806; H=1024: 13.7338/15.7811/19.9300; H=2048: 50.8762/56.4571/70.2031 ms. 4-GPU speedup 0.608x→0.621x→0.689x→**0.725x** (eff 15.2%→18.1%); 2-GPU 0.881x→0.804x→0.870x→0.901x (eff 40-45%).
- **TOPO**: nvidia-smi topo -m = GPU0/1 NUMA node 0 (NODE), GPU2/3 NUMA node 1 (NODE), pairs across socket = SYS; NOT NVLink. All 12 directed `cudaDeviceCanAccessPeer==0` → GeForce direct P2P driver-disabled → every cudaMemcpyPeer host-staged (same as M3/M5). Correctness identical (ring transport-agnostic).
- **HONEST FINDING (g5/g83)**: 4-GPU data-parallel TRAINING is CORRECT to the last bit (max|Δ|=0, N=4) but does NOT yet speed up this small model — 4-GPU is 0.61-0.73x of 1-GPU (SLOWER) because the host-staged all-reduce of the FP64 grad costs more than the per-step compute saved by sharding B=64. Expected Amdahl/comm reality, NOT a failure (N-GPU speedup always < N×; on host-staged transport with a small model comm > compute). Efficiency rises MONOTONICALLY with model size (4-GPU 15.2%→18.1% as H 64→2048) — the crossover DIRECTION toward 4-GPU winning is measured; the absolute crossover needs (a) a much bigger model (more compute/step) and/or (b) NVLink/direct-P2P (cheaper comm). The durable result is the CORRECTNESS leg: the M4 invariant holds byte-exact at N=4 with the correct ring right-nested reduction tree.
- Verdict verbatim: `.verdicts/hexa-ddp-m5b/F-DDP-M5B-4GPU-SPEEDUP.txt`. Transport = staged-host cudaMemcpyPeer.

## 2026-06-07 — DDP-M6 GREEN: cross-node ring all-reduce byte-eq (TCP socket transport, 2 hosts)
- DDP-M6 closed 🟢. The hexa-native ring all-reduce crosses a REAL node boundary byte-exact. stdlib/ddp/m6_multinode/ring_tcp_m6.c = the EXACT M1/M3/M5 canonical 2(N-1)-step chunk-partition schedule with the per-step transport swapped from cudaMemcpyPeer (intra-node GPU) to host-to-host TCP sendall/recvall on a ring socket. Each rank is a separate process on a separate host; parity-ordering (even send-then-recv / odd recv-then-send) makes the 2-cycle deadlock-free without threads. Host-memory FP64 ring (no CUDA) — isolates cross-node TRANSPORT correctness.
- TRANSPORT=TCP, NODE COUNT=2 genuinely distinct physical hosts / distinct public IPs / distinct countries: rank0 = vast 39797909 Poland 91.150.160.38, rank1 = vast 39797928 Ukraine 82.193.103.124. vast pods expose container ports on their public IP via Docker port-map (direct_port_count>0), so the two pods reached each other over public IP + mapped external port — NO proxy/relay on the data plane. rank0 --succ 82.193.103.124:40074, rank1 --succ 91.150.160.38:16883.
- GATE (g5): byte-eq max|Δ|=0 (FP64) vs serial elementwise sum, BOTH ranks, BOTH cases — S=7 (S%2=1 boundary) and S=1<<20 (large). All four = max|Δ|=0 PASS. FP64 bytes crossed the public Internet between two datacenters and arrived bit-identical (TCP reliable+ordered). Loopback intermediate proof (one host, 2 procs, 127.0.0.1, same binary) also 4/4 byte-eq PASS, labeled NOT-true-multi-host.
- HONEST (g5): ring CORRECTNESS is NOT a multi-host-networking wall — byte-eq is latency-independent. WAN latency dominates small messages (M5 honest note: ring moves 2(N-1)/N× per-rank data) but does not affect correctness. WAN throughput/speedup measurement is a separate perf follow-up (M6b), NOT this gate.
- INFRA FINDING: vast cheap pods ARE inter-node reachable (the HONEST-SCOPING 🟠 network-blocked branch did NOT trigger). Node A's vast SSH *proxy* (ssh4.vast.ai) was flaky, but its DIRECT public-IP SSH and the data-plane ports worked — and the data plane is exactly what M6 tests.
- Pods destroyed: YES, both, tag-verified (label==hexa-ddp-m6) before destroy. Post-destroy 0 hexa-ddp-m6 instances alive (leak 0). The one remaining account instance is foreign-project 'rtsc-li2mgh16-anchor' (untouched).
- verdict: .verdicts/hexa-ddp-m6/F-DDP-M6-MULTINODE.txt (verbatim). All M1..M6 collective milestones now GREEN (M5b 4-GPU e2e speedup done; M6b WAN throughput remains as perf follow-up).

## DDP-M6 (runpod leg) — 2-runpod-node cross-node socket ring all-reduce — 🟢 GREEN (2026-06-07)

- **What**: ported the M1/M3/M5 canonical ring all-reduce (2(N-1) steps, `chunk_start`
  partition byte-identical) to cross a NODE boundary on **runpod** (sibling to the vast leg,
  provider-isolated). Transport swapped from cudaMemcpyPeer (single-node P2P) to
  D2H + TCP send/recv (host network) + H2D, so every chunk physically crosses the wire.
- **Hardware**: 2 separate runpod SECURE-cloud H100 pods — node A `wosowf0qknt0au`
  (216.243.220.230, internal 172.23.0.2) + node B `iz1e1v3h4n6n5y` (216.243.220.219,
  internal 172.21.0.2). Distinct machines (different /16, different docker hostnames).
- **Cross-host proof**: pod A held `ESTAB 172.23.0.2:46206 -> 216.243.220.219:16917`
  carrying the ring data; raw `/dev/tcp` probe A→B public port = OPEN.
- **GATE (g5) BOTH ranks**: S=7 (S%N=1 boundary) max|Δ|=0 PASS; S=1<<20 (large) max|Δ|=0 PASS.
  FP64, result == serial elementwise sum. ALL BYTE-EQ PASS on rank0 AND rank1.
- **Transport finding (honest)**: runpod custom TCP ports (5700/5701) did NOT surface a
  public proxy mapping (`runtime.ports` empty for raw TCP) → cross-node TCP established as an
  SSH port-forward between the two pods' public SSH endpoints. Still real kernel TCP over the
  physical inter-node link; correctness is carrier-independent. NOT an RDMA/IB bandwidth claim,
  NOT multi-node training speedup — collective correctness only.
- **Wiring fix**: connect() over a tunnel port succeeds even when the far listener is down
  (tunnel then drops) → added a deadlock-free interleaved SYN/ACK handshake (`ring_wire`) so
  the ring only proceeds once the far LISTENER is confirmed, startup-order-independent.
- **Code**: stdlib/ddp/m6_socket/ring_socket_m6.cu + run_m6.sh.
- **Verdict**: .verdicts/hexa-ddp-m6-runpod/F-DDP-M6-RUNPOD.txt (verbatim rank stdout).
- **Pods**: BOTH terminated immediately on capture (`runpodctl pod delete` -> deleted; account
  pod list shows 0 of my M6 pods). Leak 0 on runpod.

## DDP-M7 — production 7B-scale DDP byte-eq (1-GPU == N-GPU)  [GREEN]
- node: vast 4x NVIDIA H200 (143771 MiB/GPU, 149.56 GB free, 2015 GB host RAM), nvcc 12.4, sm_90, instance 39809972 (label hexa-ddp-m7, DESTROYED leak-0, project-tag-checked).
- code: stdlib/ddp/m7_7b/ddp_train_m7.cu — M4/M5b flame-MLP fwd/bwd + canonical ring all-reduce; NPARAM pushed to production scale; gate = dtype-independent true max|Δ|=0 (ring per-chunk right-nested tree reference, M5b finding).
- LEG A (FP64): NPARAM=5,492,732,608 (5.493 B, H=74048) — max|Δ|=0 [VRAM-CAPPED]. loss_ref==loss_ddp=340786697.62098843. 19m19s.
- LEG B (fp32): NPARAM=7,010,541,280 (7.011 B, H=83664, HIT 7B TARGET) — max|Δ|=0. loss_ref==loss_ddp=477412959.75987273. 16m21s.
- both legs: weights·grad·loss·rank-agreement all exactly 0; real NVLink P2P cudaMemcpyPeer ring (H200 SXM).
- HONEST: 7B does not fit FP64 VRAM (168 GB/GPU > 143) — 7B leg is fp32 (order-matched true byte-eq, not tolerance). single step; multi-step accum + 7B speedup out of scope.
- FINDING: the DDP byte-eq invariant HOLDS at production 7B scale. M4/M5b small-model max|Δ|=0 + M7 7B max|Δ|=0 bracket the production regime with no gap (grad-of-sum=sum-of-grads is scale-invariant by construction).
- verdict: .verdicts/hexa-ddp-m7/F-DDP-M7-7B-BYTEEQ.txt (both legs verbatim).

## 2026-06-07 — DDP-M5c NVLink crossover (#2901)
- **GOAL**: find the model size where multi-GPU DDP TRAINING beats 1-GPU (speedup >1x)
  on a REAL NVLink node, testing the M5b prediction (NVLink → smaller crossover).
- **A/B on identical silicon**: rented TWO vast 4x A100-SXM4-40GB nodes. First
  (39809783, mach 38233 Germany) = topo PHB, cudaDeviceCanAccessPeer=0 on all 12
  pairs (P2P driver-DISABLED despite SXM4 silicon) → host-staged. Second (39811910,
  mach 41067 Georgia) = topo NV12 on every pair, canAccessPeer=1 on all 12 pairs →
  REAL NVLink direct-P2P ring. Both label hexa-ddp-m5c, BOTH DESTROYED on capture
  (leak 0, tag-checked). KEY transport finding: vast SXM4 does NOT guarantee NVLink
  P2P — the canAccessPeer CUDA probe is the only authoritative check.
- **GATE(1) byte-eq**: N=4, 1-GPU W_ref == 4-GPU W_ddp max|delta|=0 (grad, weight,
  rank-agreement all 0, FP64, ring right-nested reduce tree). Identical on both
  nodes — correctness is transport-independent.
- **GATE(2) crossover**: NVLink removes nearly the ENTIRE comm tax. Efficiency
  jumps 2-GPU 43%→49.5%, 4-GPU 18%→24.2% (near the 50%/25% ideal). BUT per-step
  wall still does NOT cross 1.0x even on NVLink: 2-GPU → 0.99x asymptote, 4-GPU →
  0.974x. Staged node plateaus at 0.86x/0.74x (mirrors M5b).
- **HONEST (g83)**: the 1.0x ceiling is NOT a comm defect (NVLink fixed comm) — it
  is structural: pure data-parallel shards only the batch (B=64), but an H→H MLP
  step is H² GEMM = weight-bound, so sharding 64 rows into 16 barely cuts per-rank
  FLOPs; each rank does ~the full 1-GPU compute + a now-cheap all-reduce. Small-
  batch data-parallel per-step wall is bounded by 1.0x on ANY transport. To beat
  1-GPU: (a) batch-bound regime (large B → throughput, DDP's true use), or (b)
  model/tensor parallelism (shard the H² weight). NVLink is the cure for comm,
  not for the data-parallel structural ceiling.
- **Code**: stdlib/ddp/m5c_crossover/ddp_train_m5c.cu + run_m5c.sh (M5b harness +
  2-GPU crossover track + P2P-any line). **Verdict**:
  .verdicts/hexa-ddp-m5c/F-DDP-M5C-CROSSOVER.txt (both node wall tables +
  canAccessPeer probe + byte-eq verbatim).

## DDP-M6b — WAN throughput characterization of the M6 cross-node ring all-reduce (perf)
- **Scope**: M6 (#2899/#2900) proved cross-node byte-eq only (latency-independent); M6b measures
  the PERF envelope M6 deferred — RTT floor, BW-vs-payload (1KB..256MB), latency->bandwidth
  crossover, and the TCP socket-buffer/window effect. NOT a correctness claim.
- **Hardware**: 2 vast nodes, real intercontinental WAN. rank0 = instance 39810496 Poland
  (91.150.160.38, ring ext :16989); rank1 = instance 39810517 California US (74.48.140.178,
  ring ext :44291). Ring ports exposed via vast Docker port-map; two TCP connections each cross
  the public Internet PL<->CA (~9-10k km). Both label hexa-ddp-m6b, DESTROYED leak-0.
- **Code**: stdlib/ddp/m6b_throughput/ring_perf_m6b.c — M1/M3/M5/M6 canonical 2(N-1) ring
  schedule + chunk_start partition + parity send/recv (M6 host-to-host TCP transport, byte-for-
  byte), instrumented with: 1-byte ping-pong RTT (median of 50), per-size median-wall BW sweep,
  --single (large single-size probe), --sockbuf (SO_SND/RCVBUF window axis).
- **(1) RTT floor**: ~300-320 ms (3 independent runs: 314.79 / 300.70 / 319.08 ms). A full
  all-reduce (reduce-scatter + all-gather, each a blocking send-then-recv phase) pays ~2 RTT min.
- **(2) BW vs size (default buffer, reps=7)**: flat ~3-4e-5 GB/s (~30-40 KB/s) across 1KB..1MB.
  Small S (<=16KB) median ~0.6-1.0s == the ~2 RTT floor; 1MB all-reduce = 30.9 s.
- **(4) TCP-window probe (32 MB SO_SND/RCVBUF, kernel rmem/wmem_max raised to 128MB)**: curve is
  INDISTINGUISHABLE from default-buffer. CLEAN NEGATIVE — the limiter is NOT the window/BDP; it
  is the ring's per-phase blocking send-then-recv serialising a full RTT per phase (RTT-bound).
- **(3) Crossover / ceiling**: never enters a bandwidth-bound regime at any measurable size;
  effective GB/s ceiling ~3-4e-5 GB/s (~30-40 KB/s) — 2-3 orders below the links' ~800 Mbit
  nominal. The cross-country RTT dwarfs transfer time for all realistic gradient sizes.
- **Honest verdict (g5)**: byte-exact (M6) but perf-useless for synchronous DDP at realistic
  gradient sizes over this commodity-WAN-TCP path; viable only when compute >> communication, or
  if the collective is re-pipelined to overlap phases. NOT an RDMA/datacenter number.
- **Verdict**: .verdicts/hexa-ddp-m6b/F-DDP-M6B-WAN-THROUGHPUT.txt (RTT + BW table + sockbuf
  probe, verbatim rank0 stdout).

## DDP-M5d — THROUGHPUT scaling: the regime where DDP actually wins (🟢 GREEN)

- **Falsifier**: per-GPU batch FIXED, global batch = B_perGPU×N → (1) N=4 step byte-eq to
  same-B_global 1-process ref (max|Δ|=0 FP64) AND (2) samples/sec @1/2/4-GPU + scaling eff;
  expect throughput to scale UP with N (unlike M5b/M5c per-step <1×), comm tax → eff < N×.
- **Node**: vast 4x A100-SXM4-40GB, instance 39860052, label hexa-ddp-m5d, DESTROYED leak-0
  (project-tag-checked). topo = NV12 ALL pairs (full NVLink mesh), cudaDeviceCanAccessPeer=1 on
  all 12 directed pairs — the M5c "vast SXM4 ≠ NVLink guaranteed" gotcha explicitly ruled out
  by BOTH topo and the CUDA P2P probe. transport = direct NVLink cudaMemcpyPeer.
- **Model**: MLP 64→H→H→64 (ReLU,ReLU,linear) FP64, B_perGPU=64 FIXED, H∈{256,1024,2048,3072},
  median of 30 reps. throughput = B_global·1000/wall_ms (samples/sec).
- **(1) Correctness**: N=4 byte-eq (H=256, B_global=256) grad/weights/rank-agreement all
  max|Δ|=0 — 1-process ref reduces the same 256 samples' shard partials in the ring's per-chunk
  right-nested order (M5c finding, transport-independent). True byte-eq, not a tolerance.
- **(2) Throughput scaling** (samples/sec, verbatim): N=1/2/4 →
  H=256:  24691 / 46993 / 82513  → 2-GPU 1.903x (95.2%), 4-GPU 3.342x (83.5%)
  H=1024:  4740 /  9230 / 17656  → 2-GPU 1.947x (97.4%), 4-GPU 3.725x (93.1%)
  H=2048:  1350 /  2674 /  5232  → 2-GPU 1.981x (99.0%), 4-GPU 3.874x (96.9%)
  H=3072:   618 /  1229 /  2421  → 2-GPU 1.989x (99.5%), 4-GPU 3.918x (97.9%)
  Efficiency rises MONOTONICALLY with model size toward the ideal N× — the comm tax (the same
  NPARAM-length grad all-reduce) amortizes over larger per-step compute. At H=3072, 4-GPU is
  3.918x = 97.9% of perfect 4× scaling.
- **Explicit contrast vs M5b/M5c**: M5b/M5c FIXED the global batch B=64 and SPLIT it across N →
  per-step wall never beats 1.0x EVEN on NVLink (2-GPU 0.99x, 4-GPU 0.974x) because an H→H step
  is the H² weight-bound GEMM and splitting only the batch barely cuts per-rank FLOPs. M5d fixes
  per-GPU batch and scales the global batch → samples/sec scales ~N×. Throughput is the OPPOSITE
  of per-step latency: in DDP's design regime, multi-GPU FINALLY WINS.
- **Honest verdict (g5/g83)**: throughput scales ~N× in DDP's design regime — near-ideal on real
  NVLink (97.9% 4-GPU eff at H=3072), with the gap to ideal shrinking as the model grows. eff<100%
  is the expected comm tax, NOT a failure. Single-step wide-MLP FP64; the ring carries an
  NPARAM-length grad vector regardless of architecture so the throughput algebra (constant
  per-rank compute, N× samples/step) is scale-invariant; eff is set by the compute/comm ratio.
- **Verdict**: .verdicts/hexa-ddp-m5d/F-DDP-M5D-THROUGHPUT.txt (topo + canAccessPeer + samples/sec
  table @1/2/4-GPU + eff + byte-eq, verbatim stdout).
