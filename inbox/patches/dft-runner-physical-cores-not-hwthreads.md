# DFT runner / pod-orchestration tools: `nproc` returns host hwthreads in containers — physical-core derivation needed

**Reporter**: demiurge (`dancinlab/demiurge` RTSC DFT campaign, 2026-05-23)
**Severity**: high (silent 8× MPI overcommit → pw.x zombie storm → 1h+ wall with zero progress; no error, just hang)
**Affected (potential)**: any hexa-native tooling that dispatches MPI / OpenMP jobs into containerized rentals (Vast.ai, RunPod, generic Docker hosts) and reads `nproc` for `-np` / `OMP_NUM_THREADS`. Specifically demiurge's `dft_runner.sh` (already source-fixed today on demiurge side), but the *same* footgun is latent in `stdlib/cloud` cookbook / recipe surface and any future `hexa cloud run --auto-mpi-np` helper.

## Problem statement

Inside Vast.ai (and similar Docker-host rental) containers, `nproc` and `/proc/cpuinfo` report the **host's full hwthread count**, ignoring the container's cgroup CPU quota. A host with 48 effective cores (96 hwthreads) typically gives a `nproc` reading of 96–384 inside a rented container, regardless of the actual `--cpus` allocation negotiated at rental time.

Any caller that does:

```bash
NP=$(nproc)
mpirun -np $NP --use-hwthread-cpus --oversubscribe pw.x …
```

triggers 8× overcommit of MPI ranks vs. allocated CPU shares. Observed symptom: `pw.x` ranks fork into zombie state competing for the same time slice; aggregate progress drops to ~0; no error, no `EAGAIN`, no OOM — the run just sits at `Self-consistent Calculation` for an hour with zero new lines in the QE output.

## Repro (real instance, 2026-05-23)

```
Vast.ai instance: 37424615
Machine:          14472
Host eff-cores:   48
nproc inside ct.: 384   (96 hwthreads × 4-fold misread)
Cgroup quota:     ~16 cores (per rental contract)

$ NP=$(nproc); echo $NP
384
$ mpirun -np 384 --use-hwthread-cpus --oversubscribe pw.x -in scf.in > scf.out
# → 1h 02m wall, scf.out frozen at first SCF iter, ~384 pw.x procs visible in ps,
#   load avg climbing past 200, no kernel error, no QE error.
```

The same job with `-np 16` (matching cgroup quota) finishes the SCF in ~3 minutes on the same instance.

## Root cause

`nproc` (`coreutils`) reads `/sys/devices/system/cpu/online`, which is the **host's** CPU set — Docker's default `--cpus N` cgroup *throttles* CPU time but does not *hide* CPUs from `/sys` or `/proc/cpuinfo`. The container has no portable way to learn "how many cores am I actually entitled to" short of reading `/sys/fs/cgroup/cpu.max` (cgroups v2) or `cpu.cfs_quota_us / cpu.cfs_period_us` (v1) — which most caller scripts don't do.

Derived **physical-core count** (one rank per physical core, ignoring SMT siblings) is a much better default for HPC kernels like `pw.x`, and is trivially derivable from `/proc/cpuinfo`:

```bash
PHYS=$(awk '/^core id/{print $4}' /proc/cpuinfo | sort -u | wc -l)
```

For containerized rentals this still over-reports (returns host physical-core count, not cgroup quota), so a hard ceiling is necessary:

```bash
NP=$PHYS
[ "$NP" -gt 16 ] && NP=16            # rental SLA ceiling
mpirun -np "$NP" --bind-to none …    # NO --use-hwthread-cpus, NO --oversubscribe
```

The two `mpirun` flags `--use-hwthread-cpus` and `--oversubscribe` are an *active* hazard here — they tell Open MPI "ignore the binding logic, just pack ranks in" — which is the opposite of what an SMT-aware HPC kernel wants.

## Demiurge-side source fix (landed 2026-05-23)

```bash
# dft_runner.sh — before
NP=$(nproc)
mpirun -np "$NP" --use-hwthread-cpus --oversubscribe pw.x -in scf.in > scf.out

# dft_runner.sh — after (this is the fix landing in demiurge today)
PHYS=$(awk '/^core id/{print $4}' /proc/cpuinfo | sort -u | wc -l)
NP=$PHYS
[ "$NP" -gt 16 ] && NP=16
mpirun -np "$NP" --bind-to none pw.x -in scf.in > scf.out
```

This unblocked the campaign. Filed here because the same pattern is latent in hexa-native tooling.

## Suggested upstream fix (hexa-lang side)

Two non-mutually-exclusive surface points where the fix should land so downstream tooling stops re-deriving this:

**(A) `hexa cloud run` exposes `HEXA_NPROC_PHYS` environment variable**

When `hexa cloud` opens an SSH session to a rented host, it could probe physical cores once and inject the result into the remote env:

```
hexa cloud run <host> -- env | grep HEXA_NPROC_PHYS
HEXA_NPROC_PHYS=16
```

Implementation sketch (`stdlib/cloud/cloud.hexa` or `runpod.hexa`):

```hexa
// inside the remote-exec wrapper, before the user's command:
let phys = ssh_probe(host, "awk '/^core id/{print $4}' /proc/cpuinfo | sort -u | wc -l").trim()
let cap  = 16  // sensible default; configurable via flag
let nproc = min(parse_int(phys), cap)
let env_prelude = "HEXA_NPROC_PHYS=" + to_string(nproc) + " "
exec(env_prelude + user_command)
```

Then any caller can write `mpirun -np "$HEXA_NPROC_PHYS"` with one fewer footgun.

**(B) `stdlib/cloud` cookbook entry / recipe doc**

A short cookbook page (`stdlib/cloud/RECIPES.md` or a sibling under `inbox/recipes/`) titled "MPI on rented containers — don't trust `nproc`" with:

- The repro above (`nproc=384` on a 48-core host)
- The `awk '/^core id/' /proc/cpuinfo | sort -u | wc -l` derivation
- The cap pattern (`[ "$NP" -gt 16 ] && NP=16`)
- The two flags to **never** pass to `mpirun` in this context

Demiurge would link this from its DFT cookbook so future runs don't re-discover the gap.

## Impact / cost

- 1h+ wall lost on Vast.ai instance 37424615 before symptom was diagnosed (~$0.50 of compute, but cascade-blocked downstream verification of an h-BN supercell run that gates the SX500 RTSC §9.7 candidate).
- Class of failure is **silent** (no error, no exit code, no log line) — the only signal is "QE output file isn't growing". Hard to catch in CI.
- Latent in any future `hexa cloud --auto-mpi-np` style helper; landing fix (A) prophylactically prevents the class.

## honest C3

- The demiurge-side source fix landed today; this inbox patch is purely "carry the lesson upstream so the *next* downstream consumer doesn't pay the same cost".
- The `cap=16` is rental-SLA-specific; for owned hardware (pool:ubu-1/ubu-2) it should be `PHYS` directly. A flag (`--mpi-cap N`, default = no cap on owned hosts, `16` on rentals) covers both.
- `--bind-to none` is the right default for QE / pw.x; other kernels (e.g. flame training loops) may want different binding. The recipe entry should call this out.
- demiurge never edits hexa-lang source — this file lives in `inbox/patches/` per upstream-downstream invariant (commons `@D g11` — file the gap, fix at source).

## Cross-link

- `dancinlab/demiurge` 2026-05-23 RTSC DFT campaign — `dft_runner.sh` source-fix commit (demiurge side)
- `dancinlab/demiurge` `CLAUDE.md @D d8` — "compute sizing for DFT electron-phonon": Vast.ai CPU market sized for batch / acceleration; this gap was the operational hazard that almost void-classed that policy
- `dancinlab/hexa-lang` `inbox/patches/cloud-cli-operational-improvements-anima-2026-05-20.md` — sibling consolidation request from anima; P-list could absorb this as **P12 — `--mpi-np-phys` auto-derivation**
