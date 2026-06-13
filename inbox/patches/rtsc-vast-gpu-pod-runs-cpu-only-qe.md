# rtsc vast gpu pod runs cpu only qe

> Materialized from cross-repo handoff `23ffc7ed` (from demiurge, 1780271507) per demiurge @D d8
> (vast/cloud finding -> hexa-lang/inbox/patches so `hexa cloud` absorbs upstream).

RTSC el-ph campaign rents vast.ai GPU pods (RTX PRO 6000 ~$1.5/hr) but runs CPU-only QE: provision installs Debian apt 'quantum-espresso' (QE 6.7MaX, no CUDA) and chain is 'mpirun -np <physcores> pw.x/ph.x' (stdlib/cloud/dft_dispatch.hexa _dft_provision_cmd L826 + _dft_chain L870-886). GPU sits 100% idle (nvidia-smi 0%/0MiB). EVIDENCE-BACKED VERDICT: do NOT add GPU-QE to the provision step. ph.x (DFPT phonon) is the bottleneck (~1.3h/q-pt, multi-cycle) and ph.x GPU support did NOT exist until QE 7.2 (PHonon GPU port) — QE 6.7 cannot GPU-accelerate ph.x at all. Most cells are tiny (4-21 atoms; only Li2MgH16=38) where even pw.x GPU gain is small (kernel-launch overhead) and pw.x is the cheap stage anyway. The GPU premium is INTENTIONAL per d7 (vast CPU-only offers scarce/unreliable; GPU offers rented for reliable CPUs). RECOMMENDED FIXES (low effort, real win): (1) dft_rent_query L224 already filters cpu_cores_effective>=16 + dph_total<2.0 — add an explicit '?CPU offer first, GPU fallback' tier so the rent query prefers the cheapest reliable CPU-meeting offer and only pays GPU premium when no CPU offer clears the reliability/core floor (cuts $/job with zero compute loss). (2) IF a GPU-QE path is ever wanted, it requires bumping the provision image to QE>=7.2 GPU build (e.g. NGC qe container) AND only pays off on the few >=20-atom decks for the pw.x relax/scf stage, NOT ph.x. File as RFC, do not auto-adopt — marginal win, ph.x bottleneck untouched.

---
source: sidecar handoff `23ffc7ed` (demiurge -> hexa-lang) · status: open (awaiting hexa-lang absorb)
