# HEXA-DDP M2 — 2-GPU availability probe (the wildcard fact)

Probe date: 2026-06-07 (UTC). Read-only `vastai search offers` — NO rent.
Raw JSON: `.verdicts/hexa-ddp-m2/vast_2gpu_offers_raw.json` (64 offers, verbatim).

## Verdict: 2-GPU nodes are ABUNDANT and CHEAP.

Filter: `num_gpus>=2 rentable=true cuda_max_good>=12.2 disk_space>40`,
over {A100/H100/H200 family}. **64 matching 2+GPU offers live.**

### Cheapest 2-GPU offers (sorted by $/hr) — verbatim
```
ID         GPU          N    $/hr      $/hr/GPU  inet_dn  reliab
39699018   A100_PCIE    2x   1.2014    0.6007    1123     0.951
38565865   A100_SXM4    2x   1.3343    0.6671    797      0.900
35422818   A100_SXM4    2x   1.4676    0.7338    4650     0.997
39598343   A100_PCIE    2x   1.5014    0.7507    3442     0.996
29202323   A100_PCIE    2x   1.6023    0.8012    5348     0.996
25139284   A100_PCIE    2x   1.7343    0.8671    655      0.997
```

### NVLink-class (SXM/NVL) — the DDP-relevant config (real P2P)
`gpu_name in [A100_SXM4,H100_SXM,H100_NVL] num_gpus>=2 reliability>0.97`
→ **35 reliable offers.** Cheapest reliable: **2x A100_SXM4 @ $1.4676/hr
(0.997 reliability, ID 35422818).** 2x H100_SXM around $2.93/hr.

## Wildcard answer (g5 HONEST)
- **Available?** YES — 64 two-GPU offers, 35 of them NVLink-class & reliable.
- **Affordable?** YES — cheapest reliable NVLink 2-GPU node ≈ **$1.47/hr**;
  a DDP-M3/M4 correctness run (minutes) costs cents. A multi-hour training
  job is the user's spend decision, but the hardware is not a blocker.
- M2 delivers infra-readiness + this price fact. It does NOT assert that
  multi-GPU TRAINING runs end-to-end — that is DDP-M3 (P2P all-reduce) and
  DDP-M4 (1-GPU vs 2-GPU byte-eq), which depend on this rent capability.

## Topology capture (DDP-M3 input) — DRY-RUN (not yet rented)
The real `nvidia-smi topo -m` matrix needs a live 2-GPU pod. The exact
command that captures it (leak-0: search → rent → probe → destroy):

```bash
# 1) pick cheapest reliable NVLink 2-GPU offer
OID=$(vastai search offers \
  'gpu_name in [A100_SXM4,H100_SXM,H100_NVL] num_gpus>=2 rentable=true reliability>0.97 cuda_max_good>=12.2 disk_space>40' \
  -o dph_total --raw | python3 -c 'import json,sys;print(json.load(sys.stdin)[0]["id"])')

# 2) rent (DDP_NUM_GPUS=2 → ddp_gpu_pred yields num_gpus>=2)
IID=$(vastai create instance "$OID" --image pytorch/pytorch:2.4.0-cuda12.4-cudnn9-devel \
      --disk 40 --ssh --direct --label ddp-m2-topo --raw \
      | python3 -c 'import json,sys;print(json.load(sys.stdin)["new_contract"])')

# 3) on-pod topology probe (records NVLink/PCIe/SYS link matrix)
ssh -p <port> root@<host> 'bash -s' < tool/ddp_topo_probe.sh > .verdicts/hexa-ddp-m2/topo.txt

# 4) DESTROY immediately (leak-0, exact ID)
vastai destroy instance "$IID"
```

TODO(DDP-M3): run the above once to capture the real link matrix; expected
for 2x A100_SXM4 = `GPU0 <-> GPU1 : NVLink` → transport = cudaMemcpyPeer P2P.
Parser (`tool/ddp_topo_probe.sh`) verified against synthetic 2-GPU and
4-GPU (dual-NUMA mixed) matrices.
