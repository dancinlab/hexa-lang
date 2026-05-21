# N5 Funnel · BETE-NET Real-Run Setup

Practical wrappers to take the N5 novel-material funnel from install-gated stub
to real BETE-NET inference.

## Prerequisites

- BETE-NET cloned at `~/local/bete-net/BETE-NET/` (~5.4 GB weights — 100 ensemble × 3 variants)
- Python 3.10+ (recommend 3.11 on macOS arm64)
- ~8 GB free disk for venv (torch + torch_geometric + e3nn wheels are heavy)

## 5-step quickstart

```bash
# 1. Build venv (one-time · ~10 min on broadband)
bash ~/core/hexa-lang/stdlib/material/_setup/setup_bete_net_venv.sh

# 2. Self-check imports
source ~/core/hexa-lang/stdlib/material/_setup/activate_bete_net.sh

# 3. Dry-run funnel (small pool)
bash ~/core/hexa-lang/stdlib/material/_setup/run_n5_funnel.sh Nb 4 5

# 4. Inspect output
ls /tmp/n5_real_*/

# 5. Scale up (full pool · hours-scale)
bash ~/core/hexa-lang/stdlib/material/_setup/run_n5_funnel.sh "Nb,Ti,V,Mo,W" 6 20 ~/n5_run_full
```

## Honest g3 reminders

The N5 funnel is **gated** as novel-discovery-simulation:
- `gate_type = novel-discovery-simulation` (never substrate/superconductor)
- `absorbed = false` (영구 · permanent · these candidates are not chip-axis material)
- BETE-NET Tc predictions are **screening signal**, not validated Tc
- Top-K outputs require independent DFT/experiment before any device claim

These guards live in `novel_material_funnel.py` and `beenet_adapter.py` —
do not weaken them for downstream pipelines.

## Known issues

### macOS arm64 wheel failures

`torch_scatter` / `torch_cluster` historically have no prebuilt arm64 wheels;
pip falls back to source build which needs:
- Xcode CLT (`xcode-select --install`)
- CUDA flags **must** be off (CPU-only build)

If `setup_bete_net_venv.sh` exits 2:
1. Confirm `python3 --version` is 3.10 or 3.11 (3.12+ wheel coverage thinner)
2. Try the PyG wheel index explicitly:
   ```
   pip install torch_scatter torch_cluster \
     -f https://data.pyg.org/whl/torch-$(python3 -c 'import torch;print(torch.__version__.split("+")[0])')+cpu.html
   ```
3. If still failing — **stop**. Do not attempt Cython / Rust toolchain rebuilds
   in this cohort. File an inbox note and proceed with N5 install-gated stub
   (real-run BETE-NET is non-blocking for chip-axis substrate work).

### Disk pressure

5.4 GB weights + 3-5 GB venv = budget ~10 GB total. If `~/local` is on a small
volume, symlink `~/local/bete-net` to a larger disk before cloning.

### Activation script vs exec

`activate_bete_net.sh` must be **sourced** (`source ...`), not executed.
Executing spawns a subshell where the venv exits before your N5 run.
`run_n5_funnel.sh` sources it automatically — only manual users hit this.

## File map

| Script | Purpose |
|---|---|
| `setup_bete_net_venv.sh` | one-time venv build + dep install |
| `activate_bete_net.sh` | source-only · sets BETE_NET_ROOT + activates venv + self-checks imports |
| `run_n5_funnel.sh` | wraps `novel_material_funnel.py` with activation guard |
| `README.md` | this file |
