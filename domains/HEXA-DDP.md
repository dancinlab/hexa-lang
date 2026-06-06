# HEXA-DDP — current state

@title: 🔗 HEXA-DDP — multi-GPU data-parallel training (hexa-native collectives)

@goal: hexa flame 트레이너가 2+ GPU 에서 data-parallel(DDP)로 학습 — gradient all-reduce 를 hexa-native 로 (NCCL 의존 없이) 구현해, 단일-GPU 효율(이미 [[HEXA-FUSION]] own-GEMM PARITY + conv cure 로 확보)을 다중-GPU throughput 로 확장한다. **정직 경계 (g5)**: 병렬은 throughput(처리량)↑이지 단일-step util 해법이 아님 — N-GPU 가속은 항상 N배 미만(통신·동기화·Amdahl 세금). 모든 단계 byte-eq 게이트(1-GPU == N-GPU 결과) FIRST, 그 다음 speedup 측정. cuBLAS/NCCL = roofline, 우위 주장 0.

@blocker: ① 통신 프리미티브(all-reduce)가 hexa 에 없음 (현재 docs-only) ② 멀티-GPU pod rent 인프라 없음 (현재 num_gpus=1 단일-rent 패턴만) — ②는 하드웨어 접근 wildcard(사용자가 풀어야).

## ── milestones (의존성 순) ──

- [ ] **DDP-M1 — ring-all-reduce 통신 프리미티브 (hexa-native) ★ FIRST, 하드웨어 불요** — gradient sum 을 N-rank 가 나눠 합치는 ring-all-reduce 를 hexa 로 구현. **단일-GPU 안에서 2-rank in-process 시뮬**로 정합성 선검증: all-reduce(g0,g1) 결과 == 직렬 sum, byte-eq max|Δ|=0 (g5). 하드웨어 없이 지금 착수 가능 — DDP 의 진짜 심장. falsifier: 2-rank sim all-reduce == serial-sum byte-eq.
- [ ] **DDP-M2 — 멀티-GPU pod rent 인프라** — tool/ 의 rent 경로가 `num_gpus≥2` 인스턴스(vast/runpod)를 잡고 NVLink/PCIe 토폴로지를 프로브하도록 확장 (현재 num_gpus=1 고정). 하드웨어-접근 wildcard — 전체 일정의 율속단계. falsifier: 2-GPU 한 노드 rent + `nvidia-smi topo -m` 캡처.
- [ ] **DDP-M3 — 단일노드 2-GPU P2P all-reduce (실 하드웨어)** — DDP-M1 의 ring 을 실제 2-GPU 에 cudaMemcpyPeer/NVLink P2P 로 land. 의존: M1+M2. falsifier: 2-GPU all-reduce == 1-GPU serial byte-eq.
- [ ] **DDP-M4 — DDP 정합성 게이트 (1-GPU vs 2-GPU)** — 같은 모델·시드·step 을 1-GPU 와 2-GPU(글로벌 batch 동일)로 돌려 weight/loss byte-eq. 의존: M3. **g5 HARD GATE** — 이게 통과해야 DDP 가 '정확'. falsifier: 1 vs 2 GPU max|Δ|=0.
- [ ] **DDP-M5 — 4-GPU ring 확장 + speedup 측정** — M4 후 ring 을 4-rank 로. 정직: 가속 < 4× 기대(통신세). 의존: M4. falsifier: byte-eq 유지 ∧ 4-GPU step/s vs 1-GPU 기록(가속률 honest).
- [ ] **DDP-M6 — 노드간(멀티노드) all-reduce — socket/IB** — 노드 경계 넘는 all-reduce (단일노드 P2P 불가). 가장 뒤·가장 어려움. 의존: M5. falsifier: 2-노드 byte-eq ∧ 인터커넥트 가속률.
