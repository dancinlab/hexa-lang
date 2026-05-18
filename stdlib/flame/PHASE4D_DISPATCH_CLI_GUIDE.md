# Phase 4-D Dispatch CLI Guide — vast.ai + runpod

Companion to `tool/flame_phase4d_dispatch.sh` (commit 01198d8e) and
`stdlib/flame/PHASE4D_GPU_DISPATCH_DESIGN.md` (commit c5d49425).

Purpose: get from "Phase 4-D-2 design landed" to "Phase 4-D-4 fire executable"
without burning a dollar on guesswork. Read-only pre-flight commands only.

---

## §1 CLI availability (snapshot, this Mac)

Verified 2026-05-17 on this workstation (Darwin arm64):

| Tool        | Status                | Version          | Location                                                  |
|-------------|----------------------|------------------|-----------------------------------------------------------|
| `vastai`    | ✅ working (pip)      | 0.5.0            | `~/Library/Python/3.14/bin/vastai`                        |
| `vastai`    | ⚠️  broken (Python 3.9) | 1.0.9 (import err) | `~/Library/Python/3.9/bin/vastai` — `match` stmt SyntaxError on 3.9 |
| `runpodctl` | ✅ working (Go)       | 2.1.9-673143d    | `/opt/homebrew/Cellar/runpodctl/2.1.9/bin/runpodctl`      |
| `runpodctl` | ❌ PATH symlink broken | —                | `/opt/homebrew/bin/runpodctl → ~/.local/bin/runpodctl` (target gone) |
| `runpod`    | ✅ working (pip)      | 1.8.2            | `~/Library/Python/3.9/bin/runpod` (Python SDK CLI, distinct from Go `runpodctl`) |

Auth status:

| Provider | Auth file              | Status                                       |
|----------|------------------------|----------------------------------------------|
| vast.ai  | `~/.vast_api_key` or `VAST_API_KEY` env | ❌ NOT configured                |
| runpod   | `~/.runpod/config.toml` | ✅ configured (balance $304.22, spend cap $80/hr) |

Practical aliases for `tool/flame_phase4d_dispatch.sh`:

```bash
# Add to your shell rc (or current session):
export PATH="$HOME/Library/Python/3.14/bin:$PATH"     # vastai 0.5.0
alias runpodctl='/opt/homebrew/Cellar/runpodctl/2.1.9/bin/runpodctl'
```

Verify after sourcing:

```bash
vastai --version       # → 0.5.0
runpodctl user         # → JSON with balance
```

---

## §2 Install (only if missing on a fresh machine)

### vast.ai — `vastai` CLI

Official: https://docs.vast.ai/cli/overview

Preferred (pip, cross-platform). The newer 0.5.x line works on Python 3.13+;
1.0.x has known import bugs on Python 3.9.

```bash
# Python 3.13+ (recommended):
pip3 install --user vastai

# Or pin the working line if older Python:
pip3 install --user 'vastai>=0.5,<1.0'
```

GitHub releases (raw download fallback):
https://github.com/vast-ai/vast-python/releases

Verify install:

```bash
vastai --version
vastai search offers 'gpu_name=A100_SXM4 num_gpus=1' --limit 3   # no auth needed
```

### runpod — `runpodctl` (Go CLI, recommended) + `runpod` (Python SDK CLI)

Official: https://docs.runpod.io/runpodctl/install-runpodctl

**Mac / Homebrew:**

```bash
brew install runpod/runpodctl/runpodctl
# (current Cellar: 2.1.9; latest as of guide write: 2.3.0)
```

**Mac / Linux direct download:**

```bash
# Latest release tarball (replace VERSION):
curl -L https://github.com/runpod/runpodctl/releases/latest/download/runpodctl-darwin-arm64.tar.gz \
  | tar -xz -C /usr/local/bin
chmod +x /usr/local/bin/runpodctl
```

**Python SDK CLI (optional, project commands):**

```bash
pip3 install --user runpod                # exposes `runpod` command
```

Verify install:

```bash
runpodctl --version           # 2.x
runpodctl doctor              # prompts for API key if absent
```

Fix the broken PATH symlink on this machine:

```bash
# Option A — re-link to Cellar binary
ln -sf /opt/homebrew/Cellar/runpodctl/2.1.9/bin/runpodctl /opt/homebrew/bin/runpodctl

# Option B — upgrade (clears the stale tap link)
brew upgrade runpodctl
```

---

## §3 API key setup

### vast.ai

1. Browse to https://cloud.vast.ai/account/ → "API Keys" tab
2. Create key (full read/write for instance create+destroy)
3. Persist locally — either:

   ```bash
   # Option A — env var (used by dispatch script)
   export VAST_API_KEY='<paste-key>'

   # Option B — vastai CLI persistence
   vastai set api-key <paste-key>     # writes ~/.vast_api_key (chmod 600)
   ```

4. Verify auth:

   ```bash
   vastai show user
   # → JSON with email, credit, etc. (NOT "failed with error 400")
   ```

### runpod

1. Browse to https://www.runpod.io/console/user/settings → "API Keys"
2. Create key with "Read/Write" pod scope
3. Persist locally — either:

   ```bash
   # Option A — env var
   export RUNPODCTL_API_KEY='<paste-key>'

   # Option B — runpodctl persistence (writes ~/.runpod/config.toml)
   runpodctl config --apiKey <paste-key>
   # or interactive:
   runpodctl doctor
   ```

4. Verify auth:

   ```bash
   runpodctl user                # JSON with clientBalance, spendLimit
   ```

---

## §4 Pre-flight CLI commands (no cost, verify everything)

Run these in order BEFORE invoking `tool/flame_phase4d_dispatch.sh vast` or
`runpod`. Every command here is read-only. None launch an instance.

### 4.1 — Local CPU smoke (free, ~500s)

```bash
tool/flame_phase4d_dispatch.sh dry-run
```

Confirms build pipeline + Phase 4-B verify_all gate (23/23) intact.

### 4.2 — vast.ai pre-flight

```bash
# (a) Auth round-trip
vastai show user                                          # account JSON
vastai show credit                                        # current credit balance

# (b) Inventory check (A100 SXM 40GB, single-GPU, cheap-first)
vastai search offers 'gpu_name=A100_SXM4 num_gpus=1 disk_space>=50' \
  --order 'dph_total' --limit 5

# Note: vast.ai A100 SXM is mostly 40GB (some 80GB).
# For 80GB explicitly:
vastai search offers 'gpu_name=A100_SXM4 num_gpus=1 gpu_ram>=80' \
  --order 'dph_total' --limit 5

# (c) Image availability — sanity that the dispatch image exists
vastai search offers 'gpu_name=A100_SXM4 num_gpus=1' --raw \
  | python3 -c "import json,sys;d=json.load(sys.stdin);print('offers:',len(d))"
```

### 4.3 — runpod pre-flight

```bash
# (a) Auth round-trip
runpodctl user                                            # account JSON + balance
runpodctl billing                                         # billing snapshot

# (b) GPU inventory
runpodctl gpu list                                        # all GPU types
runpodctl gpu list | grep -A4 'A100 SXM'                  # confirm A100 SXM stock
runpodctl datacenter                                      # region availability

# (c) SSH key wiring (dispatch will need this)
runpodctl ssh list                                        # confirm a key registered
ls ~/.runpod/ssh/                                         # local key file present
# Expect: RunPod-Key-Go (per reference_runpod_heavy_build.md)

# (d) Pod listing — confirm zero leftover pods (avoid surprise $/hr)
runpodctl pod list                                        # MUST be empty before fire
```

### 4.4 — Dispatch script visibility check

```bash
chmod +x tool/flame_phase4d_dispatch.sh                   # if not already
tool/flame_phase4d_dispatch.sh help                       # print help, no side-effects
```

---

## §5 Cost reference table

Updated 2026-05-17. Per-provider, per-GPU, on-demand, single-GPU pods.
Spot / interruptible may be cheaper but unsuitable for a measured fire.

| Provider | GPU              | VRAM  | Variant  | $/hr range     | Notes                                       |
|----------|------------------|-------|----------|----------------|---------------------------------------------|
| vast.ai  | A100 SXM4        | 40GB  | SXM      | $0.73 – $1.10  | Verified hosts; cheapest first via --order  |
| vast.ai  | A100 SXM4        | 80GB  | SXM      | $1.00 – $1.50  | Lower stock than 40GB                       |
| vast.ai  | A100 PCIe        | 40/80 | PCIe     | $0.50 – $0.90  | Slower interconnect; OK for single-GPU run  |
| vast.ai  | H100 SXM5        | 80GB  | SXM      | $1.80 – $3.00  | Out of Phase 4-D scope (over budget)        |
| runpod   | A100 SXM         | 80GB  | SECURE   | $1.89 – $2.49  | Reference from prior fire ($1.89 for 16vCPU/188GiB box) |
| runpod   | A100 PCIe        | 80GB  | COMMUNITY| $1.19 – $1.69  | Cheaper but variable stock                  |
| runpod   | RTX PRO 6000 BW  | 96GB  | SECURE   | $1.89          | RAM-rich (188 GiB); compute-class A100-ish  |
| runpod   | H100 SXM         | 80GB  | SECURE   | $2.79 – $3.69  | Out of Phase 4-D scope                      |
| runpod   | B200             | 180GB | SECURE   | $5.99+         | Out of Phase 4-D scope                      |

Phase 4-D-4 fire estimate (A100 SXM, ~4-8 hours):

| Provider | Estimated wall | Estimated cost |
|----------|---------------|----------------|
| vast.ai  | 4-8 hr        | $4 – $12       |
| runpod   | 4-8 hr        | $8 – $20       |

Both fit the default `BUDGET_USD=20` cap in `flame_phase4d_dispatch.sh`.
vast.ai is cheaper headline; runpod has higher reliability + already-funded
account ($304 balance, $80/hr spend cap).

Recommendation: **runpod for the first Phase 4-D-4 fire** (auth configured,
prior-fire SSH wiring intact, SECURE pod tier eliminates community-cloud
preemption risk). Fall back to vast.ai if runpod A100 SXM stock dries up.

---

## §6 Specific commands BEFORE Phase 4-D-4 fire

Copy-pasteable sequence. Run top-to-bottom. STOP at the first failure.

```bash
# §6.1 — environment (this Mac, current session)
export PATH="$HOME/Library/Python/3.14/bin:$PATH"
alias runpodctl='/opt/homebrew/Cellar/runpodctl/2.1.9/bin/runpodctl'

# §6.2 — auth sanity (no cost)
runpodctl user                          # must print JSON with positive balance
vastai --version                        # must print 0.5.0 (or upgrade)
# If using vast.ai too:
# vastai set api-key '<paste>' && vastai show user

# §6.3 — local pipeline sanity (free, ~500s)
cd ~/core/hexa-lang
git branch --show-current               # confirm intended branch
tool/flame_phase4d_dispatch.sh dry-run  # builds d32 + 5-run wall

# §6.4 — provider inventory sanity (no cost)
runpodctl gpu list | grep -A4 'A100 SXM'
runpodctl pod list                      # MUST be empty (no leftover pods)

# §6.5 — confirm spend ceiling
runpodctl user | grep -E '(clientBalance|spendLimit|currentSpendPerHr)'

# §6.6 — only after all above pass:
BUDGET_USD=20 tool/flame_phase4d_dispatch.sh runpod
# or:
BUDGET_USD=20 tool/flame_phase4d_dispatch.sh vast
```

Post-fire teardown (CRITICAL — prior session lost $5/hr to forgotten pods):

```bash
runpodctl pod list                      # see what's running
runpodctl pod stop  <pod-id>            # graceful
runpodctl pod delete <pod-id>           # hard cap

# vast.ai equivalent:
vastai show instances
vastai destroy instance <instance-id>
```

---

## §7 Known issues / gotchas

1. **vastai 1.0.9 broken on Python 3.9** — `match` statement (Python 3.10+
   syntax) in `serverless/client/client.py:132`. Use the Python 3.14 binary
   at `~/Library/Python/3.14/bin/vastai` (v0.5.0) instead.

2. **runpodctl PATH symlink broken on this Mac** — `/opt/homebrew/bin/runpodctl`
   points to `~/.local/bin/runpodctl` which doesn't exist. Use the Cellar path
   directly or re-link (see §2). `brew upgrade runpodctl` also fixes it.

3. **runpod SUPPLY_CONSTRAINT on CPU pods** (per `reference_runpod_heavy_build`)
   — GPU pods serve as RAM hosts. For Phase 4-D the GPU is actually used, so
   this is a non-issue, but listing CPU-only pods will return empty.

4. **runpod minimal image lacks clang** — dispatch script must `apt install -y
   clang make git` on remote before `tool/flame_phase4b3_a2_build.sh` runs.
   Use `runpod/base:1.0.2-ubuntu2404` (GLIBC 2.39, needed for prebuilt
   `hexa_interp.linux`).

5. **Never leave pods running** — `runpodctl pod list` before AND after every
   fire. Prior incident: $5/hr leak from multi-pod concurrent test.

6. **Branch hygiene** — `git branch --show-current` before any dispatch. This
   workstation shares the hexa-lang main directory across ~8 sessions; firing
   on the wrong branch corrupts the cycle.

---

## §8 References

- `tool/flame_phase4d_dispatch.sh` — dispatch script (this guide is its companion)
- `stdlib/flame/PHASE4D_GPU_DISPATCH_DESIGN.md` — Phase 4-D scope + falsifiers
- `~/.claude/projects/.../memory/reference_runpod_heavy_build.md` — prior-fire notes
- vast.ai CLI docs: https://docs.vast.ai/cli/overview
- runpodctl docs: https://docs.runpod.io/runpodctl/install-runpodctl
- vast-python source: https://github.com/vast-ai/vast-python
- runpodctl source: https://github.com/runpod/runpodctl
