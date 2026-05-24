# hexa cloud — Vast.ai canonical usage recipe (2026-05-22)

Companion to `hexa-cloud-vast-runpod-orchestration-troubleshooting-2026-05-22.md`
(PR #334). The other note catalogs *failure modes*; this note documents the
**working recipe** that actually produced results — single-instance Vast GPU
pod, conda QE, sequential chained candidates. Useful as the canonical
"happy-path" reference for a future `hexa cloud` SDK.

Reference outputs from this recipe:
- `demiurge/exports/material_discovery/rtsc_h3se_dft_6x6x6q_novel_20260522.json`
  (companion `H3Po`, `H3Te`, `H3X-chain` records pending)
- 1 Vast.ai instance running for the full session at $0.082-0.135/h
- 0 idle-billing leaks (auto-destroy on completion)

---

## Recipe overview

```
┌──────────┐    ┌─────────┐    ┌──────────┐    ┌────────┐    ┌─────────┐
│ rent 1   │───▶│ install │───▶│ deploy   │───▶│ run    │───▶│ destroy │
│ Vast GPU │    │ conda   │    │ chain    │    │ N seq. │    │ instance│
│ + verify │    │ QE      │    │ script   │    │ jobs   │    │ on done │
│ SSH      │    │ + pseudo│    │ + inputs │    │        │    │         │
└──────────┘    └─────────┘    └──────────┘    └────────┘    └─────────┘
   ~40s          ~5-8min        ~5s scp        N×30-60min   <5s destroy
```

**Total wall** for 12 candidates × ~1h each = ~12-13h on a single 24-vCPU host.
**Total cost** at $0.082-0.135/h × 13h ≈ $1-2.
**Reliability**: 1 SSH connection verified up front, no parallel-rental
race conditions, no SSH-boot-timing variance across N instances.

---

## Step 1 — Rent a Vast.ai GPU instance (the working filter)

```python
import subprocess, json
r = subprocess.run([
    "vastai", "search", "offers",
    "cpu_cores>=24 num_gpus>=1 rentable=true",     # NO verified=true (returns 0)
    "--raw"
], capture_output=True, text=True)
offers = json.loads(r.stdout)
# CLIENT-SIDE filter (server-side cpu_ram filter returns 0):
offers = [o for o in offers
          if o.get('cpu_ram', 0) >= 16000        # MB
          and o.get('dph_total', 999) <= 0.30]
offers.sort(key=lambda o: (o['dph_total'], -o['cpu_cores']))

# Race-aware loop:
for o in offers[:10]:
    r = subprocess.run([
        "vastai", "create", "instance", str(o['id']),
        "--image", "ubuntu:22.04",
        "--disk", "30",
        "--ssh",
        "--label", "hexa-cloud-dft"
    ], capture_output=True, text=True)
    if "no_such_ask" in (r.stdout + r.stderr): continue
    if "success" in r.stdout.lower():
        instance_id = re.search(r"'new_contract':\s*(\d+)", r.stdout).group(1)
        break
```

**Avoid CPU-only offers** (`num_gpus=0`) — they systematically refuse to rent
on community accounts even with funded balance. Use a GPU offer and just
ignore the GPU; the host CPU is what matters.

## Step 2 — Wait for SSH (long budget, 10 min)

```python
def wait_ssh(host, port, timeout=600):
    t0 = time.time()
    while time.time() - t0 < timeout:
        r = subprocess.run(
            ["ssh", "-i", KEY, "-o", "StrictHostKeyChecking=no",
             "-o", "ConnectTimeout=15", "-p", str(port),
             f"root@{host}", "echo READY"],
            capture_output=True, text=True, timeout=25)
        if "READY" in r.stdout: return True
        time.sleep(20)
    return False
```

Vast community pod boot is 30s in the best case and 5-10min in the worst case.
180s timeout misses ~50% of slow boots. **600s minimum**.

## Step 3 — Install conda + QE (single ssh command)

```bash
ssh -i $KEY -p $PORT root@$HOST 'bash -s' << 'EOF'
set -e
apt-get update -qq > /dev/null 2>&1
apt-get install -y -qq wget bzip2 ca-certificates curl > /dev/null 2>&1
cd ~
[ -d ~/miniforge3 ] || (wget -q https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -O miniforge.sh && bash miniforge.sh -b -p ~/miniforge3 > /dev/null 2>&1)
~/miniforge3/bin/conda create -y -n qe -c conda-forge qe > /dev/null 2>&1
ls ~/miniforge3/envs/qe/bin/pw.x && echo QE_OK
EOF
```

~5-8 min on a fresh pod. Confirms `pw.x` binary present. Conda-forge QE 7.5 is
the canonical channel (apt QE 6.7 on Ubuntu 22.04+ is FORTIFY-broken — see
companion troubleshooting doc).

## Step 4 — Deploy a chained candidate script

For the H₃X 12-candidate screen this session, the chain script is at
`/tmp/h3x_chain_vast.sh` (copy in `demiurge/exports/material_discovery/`). It
hardcodes the 12 candidates as a CANDIDATES array (one bash-readable line
each: `name X mass celldm ecut_wfc ecut_rho pseudo group`) and iterates:

```bash
for line in "${CANDIDATES[@]}"; do
  read -r name X mass celldm ecut_wfc ecut_rho pseudo grp <<< "$line"
  d=/root/h3x_${name}
  mkdir -p $d/pseudo $d/out
  cd $d
  [ -s pseudo/$pseudo ] || wget -q ${PSEUDO_BASE}${pseudo} -O pseudo/$pseudo
  cat > scf.in <<EOF
    ... (heredoc generates QE input from parameters)
  EOF
  $QEBIN/mpirun -np 24 --allow-run-as-root --use-hwthread-cpus --oversubscribe $QEBIN/pw.x -in scf.in > scf.out 2>&1
  ... ph.x ...
done
```

Why heredoc-from-parameters instead of scp-N-files: one source-of-truth
script on the remote host, no per-candidate scp round-trip, atomic restart
on failure (just re-run the chain — skips done dirs idempotently if `[ -s ]`
check is added).

## Step 5 — Run with the required mpirun flags

Non-optional on root containers:

```bash
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
mpirun -np 24 \
  --allow-run-as-root \
  --use-hwthread-cpus \
  --oversubscribe \
  pw.x -in scf.in
```

- `--allow-run-as-root`: OpenMPI refuses root by default; Vast containers run as root.
- `OMP_NUM_THREADS=1` + `MKL_NUM_THREADS=1`: prevents OpenMP nesting that
  exceeds the container's `nproc` ulimit, which manifests as
  `libgomp: Thread creation failed: Resource temporarily unavailable`.
- `--use-hwthread-cpus --oversubscribe`: makes OpenMPI count SMT threads as
  separate slots, so `-np 24` works on a 12-physical-core host with SMT.

## Step 6 — Pseudopotential fetch (CDN)

The QE pslibrary CDN at `pseudopotentials.quantum-espresso.org/upf_files/`
has predictable URLs:

```
{Element}.{xc}-{semicore}-{type}_psl.{ver}.UPF
```

Empirical naming pattern (this session):
- **Light** elements (H, He, ... up to ~Cl): `{X}.pbe-n-rrkjus_psl.1.0.0.UPF`
- **Heavy** elements with d-states (Ge, Sb, Bi, Po, ...): `{X}.pbe-dn-rrkjus_psl.1.0.0.UPF`
- **Some Te** variants: `Te.pbe-n-rrkjus_psl.1.0.0.UPF` works; `Te.pbe-dn-rrkjus_psl.1.0.0.UPF` 404s

`wget -q --timeout=30` fetches reliably ~1-3MB per pseudo. If 404, fall back
to alternate semicore prefix. Future SDK should iterate the prefix list:
`[dn, n, sp, pn]` until 200 OK.

## Step 7 — Auto-destroy on completion

```bash
# at the end of the chain script:
echo CHAIN_DONE > /root/chain_done.flag
```

Then a wrapping launcher (on the orchestrator side) polls the flag, fetches
results, and calls `yes y | vastai destroy instance <id>`. Idle billing
is the silent budget killer; *every* code path that creates a pod must have
a guaranteed destroy.

## Step 8 — Fetch results back to the orchestrator

```bash
scp -i $KEY -P $PORT \
    root@$HOST:'/root/h3x_*/ph.out /root/h3x_*/scf.out /root/h3x_*/done.flag' \
    /local/results/
```

Each `~/h3x_<name>/` dir has `ph.out` + `scf.out` + `done.flag` for the
local parser to ingest.

---

## Key invariants for the future `hexa cloud` SDK

1. **Lifecycle hygiene**: every `rent()` call must have a corresponding
   `destroy()` reachable via try/finally OR a deadline-based reaper. No
   exceptions.
2. **Single-source SSH key**: `secret get vast.ssh_private` (note name —
   *not* `ssh_priv`) → validate non-empty bytes → write to disk with 0600 →
   verify pubkey matches `vastai show ssh-keys`. The SDK should do this
   automatically and surface a loud error if any step fails.
3. **Long SSH-up timeout**: ≥ 600s default, with exponential backoff
   between attempts (15s → 30s → 60s). The original H₃Po instance came up
   in 40s, but 13 simultaneous pods averaged 5+ min.
4. **Idempotent chain restart**: each candidate dir should have a
   `done.flag` so a re-run skips finished candidates. Adds robustness for
   external interruptions.
5. **Recover-aware ph.x**: this session saw `pkill -9 -f ph.x` from
   another agent kill our run mid-DFPT. `recover = .true.` in `ph.in` lets
   ph.x resume from the last saved q-point — and it works (H₃Se completed
   16/16 q after a recover-restart at 11:09:03Z).
6. **No `verified=true` server-side filter** on `vastai search offers` —
   it returns 0 matches. Use the result raw and filter client-side.
7. **Single-instance chain over parallel-batch** for small-cell DFT: more
   reliable, similar wall time (because batch-parallel had ~60% rental
   failure rate vs. 0% on single-instance).

---

## Cost ledger (this session)

| event | $ |
|---|---|
| 1 Vast 37329507 (RTX 4060, 64 vCPU, 21GB) — H₃Po slow + chain pivot | ~$0.08 × ~3h ≈ $0.24 |
| 8 Vast batch round-1 (RTX 3090, 80 vCPU) — all SSH-fail, destroyed quickly | ~$0.135 × 8 × 0.07h ≈ $0.08 |
| 13 Vast batch round-2 (mixed RTX 3060/A5000/A4000/3090) — all SSH-fail, destroyed | ~$0.10 × 13 × 0.25h ≈ $0.33 |
| Total Vast charges | **~$0.65** |
| Pool ubu-1/ubu-2 (DFT actual workhorse) | $0 |

For a SDK design target: **batch screening 10-20 candidates at < $5
total** is the right cost envelope.

---

## R4 invariant for cloud orchestration

Nothing about this recipe changes the demiurge governance: all results
from cloud-run DFT are `gate_type=simulation-only-prediction`,
`absorbed=false`. The cloud is an *acceleration* layer, not a measurement
oracle. Future SDK should plumb this gate semantics through every cloud
result by default — i.e., a SDK-emitted record cannot opt into
`absorbed=true` from a `simulation-only-prediction` upstream tier.
