# hexa cloud — Vast.ai · RunPod orchestration troubleshooting (2026-05-22)

Empirical findings from a real session that tried to fan out 13 small-cell QE
DFT electron-phonon runs (4-atom Im-3m H₃X family · novel SC candidate screen)
across cloud CPU offerings. Documents the failure modes + concrete API/CLI
gotchas so a future `hexa cloud` skill/SDK can codify the right defaults and
fallback strategies.

Companion records:
- `demiurge/RTSC.md` §9 Log (2026-05-22) — the science context
- `demiurge/project.tape` d8 v1.4 — compute-sizing governance row
- `demiurge/exports/material_discovery/rtsc_h3s_dft_6x6x6q_textbook_proof_20260522.json` — the validated pipeline baseline

---

## TL;DR (for `hexa cloud` design)

A cloud-batch SDK targeting small-cell DFT must handle each of these
silently or surface a clear honest error — *every one of them bit us this
session*:

1. **RunPod CPU pods cap at 8 vCPU** (not in docs front-page; sweet spot absent
   for our workload). Don't pretend bigger CPU pods exist.
2. **Vast.ai CPU-only offers (`num_gpus=0`) systematically return `no_such_ask`**
   on rent even with funded balance + verified email + `has_rented=true`. Path
   forward = GPU offers with idle GPU + host-CPU usage.
3. **Server-side filters lie** — `verified=true` returns 0 matches on Vast
   even when matching offers exist; `cpu_ram>=N` likewise. Use client-side
   filtering on raw search output.
4. **Vast community pod boot times vary 30s–10min**; a hardcoded SSH wait of
   180s misses ~60% of slow boots. 600s+ minimum.
5. **`vastai create instance` returns `no_such_ask` on stale listings**;
   listings stale faster than CLI poll cadence. Always loop over a *fresh*
   `--raw` search per rent attempt.
6. **`--allow-run-as-root` + `OMP_NUM_THREADS=1`** are non-optional on container
   pods running as root; otherwise OpenMPI refuses + libgomp can't spawn
   threads under the container's nproc ulimit.
7. **SSH key resolution is fragile**: `secret get vast.ssh_priv` (note: the
   key is actually named `vast.ssh_private`) returns empty bytes silently
   when the `dancinlab.keychain-db` is not initialized; `ssh -i` then fails
   with `invalid format`. Always verify the registered pubkey on the
   provider matches a *non-empty* disk private key before launching N
   instances.
8. **CLI version drift**: `runpodctl create pod` (deprecated) vs
   `runpodctl pod create`; `vastai pod list` (doesn't exist) vs
   `vastai instance list` (also doesn't exist — actual: `vastai show ...`).
   Pin CLI version in the recipe.
9. **Python 3.9 SyntaxError on `vastai` CLI** — needs Python ≥3.11. macOS
   default `python3 = 3.9` (Xcode CLT) breaks the install silently. Force
   `python3.12 -m pip install --user vastai`.

The honest takeaway: **single robust Vast.ai GPU instance with a chained
sequential launcher** outperformed every parallel-batch attempt on the
shared community cloud. Two rounds of 13-way parallel rental both delivered
**0/13 jobs running** within the wait budget — even with 4-parallel waves +
600s SSH timeout. Meanwhile the local pool (two Linux desktops, 6c each,
free) completed 50–60% of three real candidates in the same wall time.

---

## Section 1 — RunPod (what we learned)

### CLI

```
runpodctl pod create --compute-type cpu --image ubuntu:22.04 --container-disk-in-gb 30 --ports 22/tcp --name <slug>
```

- `--vcpu` / `--memory` flags **do not exist** on `pod create` (only on the
  deprecated `create pod`). Result: every CPU pod launches at the **smallest
  tier** = 2 vCPU / 4 GB RAM. Useless for DFT.
- `--gpu-id` is **required** for `podFindAndDeployOnDemand` GraphQL mutation
  even when `computeType: CPU`. Workaround: do not use that mutation for CPU
  pods.
- `runpodctl pod terminate` is wrong; correct is `pod delete <id>`.

### Authentication

- API key stored in `~/.runpod/config.toml` separately from any secret
  manager. `secret set runpod.api_key` does **not** sync this file — you
  must either `runpodctl doctor` (interactive) or rewrite the file:
  ```
  printf "apikey = '%s'\napiurl = '%s'\n" \
    "$(secret get runpod.api_key)" "https://api.runpod.io/graphql" \
    > ~/.runpod/config.toml
  ```

### CPU ceiling (firm)

Per [docs.runpod.io/flash/configuration/cpu-types](https://docs.runpod.io/flash/configuration/cpu-types):

| family | max vCPU | max RAM |
|---|---:|---:|
| cpu3c, cpu5c (compute-optimized) | **8** | 16 GB |
| cpu3g (general-purpose) | **8** | 32 GB |

No 16+, 32+, 64+ vCPU SKUs exist on RunPod CPU. For workloads needing >8
vCPU on CPU, RunPod is not the right host.

### GPU pods as CPU substitutes

GPU instances ship with 16–64 vCPU host but bill at GPU rate ($0.50–$4/h).
Worth it only when the GPU is also useful. For pure-CPU QE workloads, the
GPU $/h overhead is unamortized.

---

## Section 2 — Vast.ai (where most of the time went)

### Key naming

The secret-store entries are:
- `vast.api_key` (51-char `rpa_…`)
- `vast.ssh_private` ← **not** `vast.ssh_priv` (silent empty-fetch
  otherwise → `ssh -i invalid format`)
- `vast.ssh_pub`

A `hexa cloud` SDK should validate non-empty bytes on fetch and surface a
loud error.

### CPU-only offer trap

15+ search-result offers matching `cpu_cores≥32 num_gpus=0 verified=true
rentable=true` all returned `no_such_ask` on `vastai create instance`.
Account state was: balance $257, `email_verified=true`, `has_rented=true`,
`can_pay=true`. Root cause unconfirmed — possibly a platform-level CPU-only
deny for community accounts, possibly stale listings. **Workaround that
worked**: rent a GPU offer (24–64 vCPU host) and ignore the GPU.

### Server-side filter list

These filters silently miss matching offers:
- `verified=true` → 0 results when removing the filter shows 64
- `cpu_ram>=N` (in MB) → 0 results when client-side filter on raw list
  matches plenty

Use:
```python
offers = vastai_search("cpu_cores>=24 num_gpus>=1 rentable=true", raw=True)
offers = [o for o in offers if o['cpu_ram'] >= MIN_RAM_MB
                              and o['dph_total'] <= MAX_DPH]
```

### Boot timing

Empirical SSH-up distribution from this session:
- 1 instance (original H₃Po, 37329507): SSH up at ~40s ✓
- 13 instances (round 1, parallel-8): all >180s, 0 reached SSH
- 13 instances (round 2, parallel-4, 600s timeout): 1 reached SSH (QE install
  then failed); 7 timed out at 600s; 3 were "no rentable offer" (post-rent
  release of an offer that just got taken)

**Recommended budgets**: SSH wait ≥ 600s (10 min); per-rent retries ≥ 3
with backoff; serial rent with 5s gaps to reduce thundering-herd at the
proxy.

### CPU pinning + threading

```bash
mpirun -np 16 --allow-run-as-root --use-hwthread-cpus --oversubscribe pw.x ...
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
```

Without `--allow-run-as-root`: OpenMPI refuses (container = root user).
Without `OMP_NUM_THREADS=1`: `libgomp: Thread creation failed: Resource
temporarily unavailable` from `nproc` ulimit on the container.

### CLI quirks

- `vastai pod list` does not exist; use `vastai show instances`.
- `vastai create ssh-key --ssh_key …` is wrong; positional arg:
  `vastai create ssh-key "<pubkey-line>"`.
- `vastai destroy instance <id>` requires `yes y |` for the y/N prompt
  (no `--force` flag).
- Python 3.9 `import vastai` → SyntaxError (uses 3.10+ syntax). Install
  with `python3.12 -m pip install --user vastai`.

---

## Section 3 — What worked

1. **Single Vast GPU instance + manual SSH + QE conda + sequential runs**.
   Once an instance is verified-up (~40s ideal, allow 10min worst), every
   subsequent QE workload runs reliably; the cost overhead is just $/h of
   the instance. For 13 candidates × ~1h each on 32-vCPU mpirun ≈ 13 h ×
   ~$0.10/h ≈ $1.30, far cheaper and more reliable than 13 parallel pods.
2. **Local pool (ubu-1, ubu-2)** at 6c Ryzen 9600X each remained the
   workhorse for the validated baseline candidates. Free, no SSH boot
   variance, just slower per run.
3. **`--allow-run-as-root + OMP=1`** unblocked QE on Vast root containers.

---

## Section 4 — Concrete design hints for `hexa cloud`

A `hexa cloud` SDK should:

```hexa
// minimal API sketch (not real syntax)
let pod = cloud.rent({
    backend:  Vast,                    // or RunPod, AWS, Hetzner
    min_vcpu: 32,
    min_ram_gb: 16,
    max_dph: 0.30,
    ssh_wait_sec: 600,                 // 10 min default
    rent_retries: 5,                   // listing race retries
    ssh_key: secret_get("vast.ssh_private"),  // must validate non-empty
    image: "ubuntu:22.04",
})
pod.install(QeConda)                   // 5-8 min
pod.upload(scf_input, ph_input, pseudos)
let job = pod.run("pw.x -in scf.in && ph.x -in ph.in",
                   env: ["OMP_NUM_THREADS=1", "MKL_NUM_THREADS=1"],
                   mpirun_extra: "--allow-run-as-root --use-hwthread-cpus")
job.await_or_kill(max_hr=2.0)
pod.fetch(["ph.out", "*.dyn0"], to: local_dir)
pod.destroy()                          // always — idle billing kills you
```

Key invariants the SDK should enforce automatically:

1. **`secret get` validation** — empty fetch → loud error, not silent zero
   bytes.
2. **Single source of truth for SSH key** — `vast.ssh_private` from
   `secret`, sync to `~/.ssh/`, sync to provider, all checksummed.
3. **Auto-destroy idle pods** — every rented pod has a deadline; if no
   `await_or_kill` resolves, the SDK destroys at deadline.
4. **Parallel rentals serialized through a single shared `taken` set**
   (we open-coded this in `/tmp/h3x_orchestrator.py` ThreadPool, but a
   library should hide it).
5. **Backend-specific quirks abstracted**: `--allow-run-as-root` is
   container-root; AWS EC2 c7a doesn't need it. The SDK chooses
   per-backend mpirun args.
6. **Backend selector** — given `(min_vcpu, max_dph)`, pick the cheapest
   backend that *can serve it*. RunPod CPU never serves > 8 vCPU; the
   selector should know.

---

## Section 5 — Honest scope-out

This troubleshooting note is **operational**, not scientific. It does not
claim or imply that any candidate was successfully evaluated on a cloud
host this session — only that the local pool produced the validated 6×6×6
H₃S textbook-grade result, and that *future* hexa cloud orchestration must
correct each of the failure modes above to make Vast / RunPod a reliable
alternative to the pool for our small-cell DFT batch screening.

R4 invariant holds across this note: nothing here flips `absorbed=true`;
all referenced records remain `simulation-only-prediction`.
