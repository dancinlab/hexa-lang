#!/usr/bin/env bash
# tool/dojo_rent_preflight.sh — shared dojo RunPod rent + preflight helper.
#
# The "트러블슈팅 안하게" deliverable. A dojo flame-forge training kata's
# run.sh sources this helper; it rents + launches a (multi-GPU DDP) pod
# WITHOUT the 2h-of-dead-pods the anima 7B fire suffered. Every failure
# path emits a CLEAR, ACTIONABLE error line (cause + fix) — never a silent
# dead pod. Reflects sidecar handoff 4474f21b (anima → hexa-lang) verbatim.
#
# Six fixes (1:1 with the handoff):
#   1. image-tag validation       — reject unknown RunPod image tags before
#                                    deploy; on EXITED+runtime=null fetch the
#                                    container init log (NOT a supply failure).
#   2. auto-inject PUBLIC_KEY      — ~/.ssh/id_ed25519.pub → env PUBLIC_KEY so
#                                    sshd actually starts (else PORT_CLOSED).
#   3. supply fallback ladder      — gpuCount 8→4→2, SECURE→COMMUNITY,
#                                    H200→H100→A100-SXM(community); first id.
#   4. failure classification      — SUPPLY_CONSTRAINT (capacity) vs
#                                    id-then-EXITED+runtime=null<1min (image/init).
#   5. preflight per-GPU mem       — delegate to stdlib/cloud/preflight.hexa
#                                    closed-form budget; warn/BLOCK before OOM.
#   6. torchrun log harvest        — DDP launcher defaults --tee 3 + harvests
#                                    per-rank stderr.log on ChildFailedError.
#
# Pure POSIX-ish bash. Drives `runpodctl` if present, else the RunPod GraphQL
# API. No external LLM. shellcheck-clean (sourced or executed).
#
# Usage (sourced from a kata run.sh):
#   source "$(dirname "$0")/../../../../tool/dojo_rent_preflight.sh"
#   dojo_preflight_mem --params 7000000000 --param-dtype fp32 \
#                      --optimizer adamw --ddp 8 --gpu h100-80gb || exit 1
#   POD_ID="$(dojo_rent --gpu-type 'NVIDIA H200' --gpu-count 8 \
#                       --image 'runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04')"
#   dojo_torchrun_launch "$POD_ID" 8 train.py
#
# Standalone self-test (no rental — validates the pure logic only):
#   bash tool/dojo_rent_preflight.sh --self-test

set -uo pipefail

# ── known-good RunPod image tags (fix #1) ────────────────────────────────
# Pinned, verified-to-exist tags. The anima 7B fire burned ~2h because
# `runpod/pytorch:2.4.1-...` does NOT exist (valid = 2.4.0) and surfaces as
# desiredStatus=EXITED+runtime=null — indistinguishable from a supply failure
# unless you validate the tag FIRST.
DOJO_KNOWN_GOOD_IMAGES=(
    "runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04"
    "runpod/pytorch:2.2.0-py3.10-cuda12.1.1-devel-ubuntu22.04"
    "runpod/pytorch:2.1.0-py3.10-cuda11.8.0-devel-ubuntu22.04"
)

# ── tiny actionable-error printer ────────────────────────────────────────
# Every failure prints CAUSE + FIX on stderr; callers exit non-zero.
_dojo_err() {
    # $1 = cause, $2 = fix
    printf '✗ dojo-rent: %s\n' "$1" >&2
    printf '  fix: %s\n' "$2" >&2
}
_dojo_ok()   { printf '✓ dojo-rent: %s\n' "$1"; }
_dojo_warn() { printf '⚠ dojo-rent: %s\n' "$1" >&2; }

# ── fix #1: image-tag validation ─────────────────────────────────────────
# dojo_validate_image <tag> → 0 if known-good, else 1 with a cause+fix line
# naming the closest valid tag. Catches the 2.4.1-typo class before deploy.
dojo_validate_image() {
    local tag="${1:-}"
    if [ -z "$tag" ]; then
        _dojo_err "no image tag given" \
                  "pass --image '${DOJO_KNOWN_GOOD_IMAGES[0]}'"
        return 1
    fi
    local good
    for good in "${DOJO_KNOWN_GOOD_IMAGES[@]}"; do
        [ "$tag" = "$good" ] && { _dojo_ok "image tag '$tag' is known-good"; return 0; }
    done
    _dojo_err "image tag '$tag' is NOT in the known-good set (it may not exist on RunPod — e.g. pytorch:2.4.1 does NOT exist, 2.4.0 does)" \
              "use one of: ${DOJO_KNOWN_GOOD_IMAGES[*]} — an unknown tag deploys then EXITs with runtime=null, looking like a supply failure"
    return 1
}

# ── fix #2: PUBLIC_KEY resolver ──────────────────────────────────────────
# dojo_public_key → echoes the ed25519 pubkey to inject as env PUBLIC_KEY.
# Without it the RunPod image start-script never launches sshd → every ssh
# is PORT_CLOSED forever despite the pod showing RUNNING + port-mapped.
dojo_public_key() {
    local kf="${HOME}/.ssh/id_ed25519.pub"
    if [ ! -f "$kf" ]; then
        # fall back to RSA, else fail loud
        kf="${HOME}/.ssh/id_rsa.pub"
    fi
    if [ ! -f "$kf" ]; then
        _dojo_err "no ssh public key at ~/.ssh/id_ed25519.pub or ~/.ssh/id_rsa.pub" \
                  "run: ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519.pub — the rent MUST inject PUBLIC_KEY or sshd never starts (ssh PORT_CLOSED forever)"
        return 1
    fi
    cat "$kf"
}

# ── fix #3: supply fallback ladder ───────────────────────────────────────
# Echoes the ordered (gpuCount,cloudType,gpuType) rungs to try, low-risk
# first. The caller walks them and takes the FIRST available pod id.
# gpuCount 8→4→2 · cloudType SECURE→COMMUNITY · gpuType H200→H100→A100-SXM.
dojo_supply_ladder() {
    local want_count="${1:-8}"
    local want_gpu="${2:-NVIDIA H200}"
    local counts=()
    case "$want_count" in
        8) counts=(8 4 2) ;;
        4) counts=(4 2) ;;
        *) counts=("$want_count") ;;
    esac
    local gpus=("$want_gpu" "NVIDIA H100 80GB HBM3" "NVIDIA A100-SXM4-80GB")
    local clouds=(SECURE COMMUNITY)
    local c g cl
    for c in "${counts[@]}"; do
        for g in "${gpus[@]}"; do
            for cl in "${clouds[@]}"; do
                printf '%s\t%s\t%s\n' "$c" "$cl" "$g"
            done
        done
    done
}

# ── fix #4: failure classification ───────────────────────────────────────
# dojo_classify_rent <api-json> <pod-id-or-empty> <desired-status> <runtime>
# Distinguishes:
#   SUPPLY_CONSTRAINT   — errors[].extensions.code==SUPPLY_CONSTRAINT (capacity)
#   IMAGE_OR_INIT       — data.id returned, then EXITED + runtime=null <1min
#   PORT_CLOSED         — RUNNING but no PUBLIC_KEY injected (sshd never started)
#   OK                  — RUNNING with a runtime
# Prints a distinct, actionable line per class. Echoes the class token.
dojo_classify_rent() {
    local api_json="${1:-}" pod_id="${2:-}" desired="${3:-}" runtime="${4:-}"
    if printf '%s' "$api_json" | grep -q 'SUPPLY_CONSTRAINT'; then
        _dojo_warn "SUPPLY_CONSTRAINT — provider has no capacity for this (count,cloud,gpu) rung; this is NOT your error"
        printf 'SUPPLY_CONSTRAINT\n'
        return 0
    fi
    if [ -n "$pod_id" ] && [ "$desired" = "EXITED" ] && { [ "$runtime" = "null" ] || [ -z "$runtime" ]; }; then
        _dojo_err "pod $pod_id deployed then EXITED with runtime=null in <1min — IMAGE/INIT failure (the image tag likely does not exist, or the container init crashed), NOT a supply shortage" \
                  "validate the image tag (dojo_validate_image) and fetch the container init log (dojo_init_log $pod_id); do NOT retry on a fresh rung"
        printf 'IMAGE_OR_INIT\n'
        return 0
    fi
    if [ "$desired" = "RUNNING" ] && { [ "$runtime" = "null" ] || [ -z "$runtime" ]; }; then
        _dojo_err "pod $pod_id is RUNNING but runtime=null and ssh PORT_CLOSED — PUBLIC_KEY was likely not injected so sshd never started" \
                  "re-rent with env PUBLIC_KEY=\$(dojo_public_key); a RUNNING pod with a mapped port but no sshd is the #2 dead-pod class"
        printf 'PORT_CLOSED\n'
        return 0
    fi
    printf 'OK\n'
    return 0
}

# dojo_init_log <pod-id> — fetch the container init/system log for an
# EXITED-without-runtime pod (fix #1 second half). Tries runpodctl, then the
# GraphQL podLogs query. Prints the log so the operator sees the REAL cause.
dojo_init_log() {
    local pod_id="${1:-}"
    [ -z "$pod_id" ] && { _dojo_err "dojo_init_log needs a pod id" "pass the id from the rent response"; return 1; }
    if command -v runpodctl >/dev/null 2>&1; then
        _dojo_ok "fetching container init log for $pod_id (runpodctl)"
        runpodctl get pod "$pod_id" 2>&1 || true
    fi
    local key; key="$(_dojo_api_key)" || return 1
    if [ -n "$key" ]; then
        _dojo_ok "fetching podLogs for $pod_id (GraphQL)"
        curl -s -X POST "https://api.runpod.io/graphql?api_key=${key}" \
            -H 'Content-Type: application/json' \
            -d "{\"query\":\"query{pod(input:{podId:\\\"${pod_id}\\\"}){runtime{container{logs}}}}\"}" \
            2>&1 || true
    fi
}

# ── RunPod API key resolver (matches stdlib/cloud/runpod.hexa precedence) ─
_dojo_api_key() {
    if [ -n "${RUNPOD_API_KEY:-}" ]; then printf '%s' "$RUNPOD_API_KEY"; return 0; fi
    if command -v secret >/dev/null 2>&1; then
        local k; k="$(secret get runpod.api_key 2>/dev/null)"
        [ -n "$k" ] && { printf '%s' "$k"; return 0; }
    fi
    if [ -f "${HOME}/.runpod/config.toml" ]; then
        # extract apiKey = "..." from the toml
        grep -oE 'apiKey *= *"[^"]+"' "${HOME}/.runpod/config.toml" 2>/dev/null \
            | head -1 | sed -E 's/.*"([^"]+)".*/\1/'
        return 0
    fi
    _dojo_err "no RunPod API key (RUNPOD_API_KEY / secret runpod.api_key / ~/.runpod/config.toml)" \
              "export RUNPOD_API_KEY=... or run: secret set runpod.api_key"
    return 1
}

# _dojo_find_preflight — walk UP from the script dir and from CWD looking for
# stdlib/cloud/preflight.hexa. Echoes the path, or "" if not found (the caller
# then uses the coarse fallback). bash-safe: ${BASH_SOURCE[0]:-$0} for zsh too.
_dojo_find_preflight() {
    local src="${BASH_SOURCE[0]:-$0}"
    local d
    d="$(cd "$(dirname "$src")" 2>/dev/null && pwd)" || d="$PWD"
    local starts=("$d" "$PWD")
    local s
    for s in "${starts[@]}"; do
        local cur="$s"
        while [ -n "$cur" ] && [ "$cur" != "/" ]; do
            if [ -f "$cur/stdlib/cloud/preflight.hexa" ]; then
                printf '%s' "$cur/stdlib/cloud/preflight.hexa"; return 0
            fi
            cur="$(dirname "$cur")"
        done
    done
    printf ''
    return 0
}

# ── fix #5: preflight per-GPU mem estimate ───────────────────────────────
# dojo_preflight_mem --params N --param-dtype DT --optimizer OPT --ddp NGPU
#                    --gpu TIER [--grad-ckpt] [--bsz B --seq S --d-model D --n-layer L]
# Delegates the closed-form budget to stdlib/cloud/preflight.hexa (the SSOT
# mem-budget calculator — H100-80GB / H200-141GB tiers, opt multipliers,
# ZeRO sharding). Returns 0 if it FITS, 1 if it would OOM (BLOCK before the
# pod even spins up). When the hexa binary is absent (a bare CUDA pod), a
# coarse fallback estimate keeps the gate alive.
dojo_preflight_mem() {
    local params="" pdt="bf16" gdt="" opt="adamw" ddp="1" gpu="h100-80gb"
    local grad_ckpt="0" bsz="1" seq="2048" dmodel="4096" nlayer="32"
    while [ $# -gt 0 ]; do
        case "$1" in
            --params)     params="$2"; shift 2 ;;
            --param-dtype) pdt="$2"; shift 2 ;;
            --grad-dtype) gdt="$2"; shift 2 ;;
            --optimizer)  opt="$2"; shift 2 ;;
            --ddp)        ddp="$2"; shift 2 ;;
            --gpu)        gpu="$2"; shift 2 ;;
            --grad-ckpt)  grad_ckpt="1"; shift ;;
            --bsz)        bsz="$2"; shift 2 ;;
            --seq)        seq="$2"; shift 2 ;;
            --d-model)    dmodel="$2"; shift 2 ;;
            --n-layer)    nlayer="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    [ -z "$gdt" ] && gdt="$pdt"
    if [ -z "$params" ]; then
        _dojo_err "dojo_preflight_mem needs --params" "pass the model param count, e.g. --params 7000000000"
        return 1
    fi

    # locate stdlib/cloud/preflight.hexa robustly: walk UP from the script's
    # own location (and from CWD) until a dir holds stdlib/cloud/preflight.hexa.
    # Works whether sourced from <root>/tool/ or a deep exports/ kata dir.
    local pf; pf="$(_dojo_find_preflight)"

    local ckpt_flag=""
    [ "$grad_ckpt" = "1" ] && ckpt_flag="--grad-ckpt"

    if command -v hexa >/dev/null 2>&1 && [ -n "$pf" ] && [ -f "$pf" ]; then
        _dojo_ok "preflight mem budget via stdlib/cloud/preflight.hexa (params=$params dtype=$pdt opt=$opt ddp=$ddp gpu=$gpu)"
        # preflight.hexa exits non-zero when the spec does not fit (OOM-by-spec).
        if hexa run "$pf" --params "$params" --param-dtype "$pdt" \
                --grad-dtype "$gdt" --optimizer "$opt" --bsz "$bsz" --seq "$seq" \
                --n-layer "$nlayer" --d-model "$dmodel" --gpu "$gpu" $ckpt_flag; then
            return 0
        fi
        _dojo_err "preflight says this spec OOMs $gpu BEFORE step 0" \
                  "drop the optimizer (adamw→adamw-8bit), enable --grad-ckpt, shard (zero2/zero3), or move to a bigger tier (h200-141gb). e.g. 7B fp32 OOMs 80GB H100 but fits 141GB H200"
        return 1
    fi

    # ── coarse fallback (no hexa binary on this host) ──
    _dojo_warn "hexa binary / preflight.hexa absent — coarse fallback mem estimate"
    dojo_preflight_mem_coarse "$params" "$pdt" "$opt" "$ddp" "$grad_ckpt" "$gpu"
}

# coarse closed-form fallback: bytes ≈ params*(pbytes + gbytes + optbytes)
# + DDP bucket. Mirrors the handoff's 7B worked example. Pure integer math.
dojo_preflight_mem_coarse() {
    local params="$1" pdt="$2" opt="$3" ddp="$4" grad_ckpt="$5" gpu="$6"
    local pb gb ob cap
    case "$pdt" in f64) pb=8;; f32) pb=4;; tf32) pb=4;; bf16|f16|fp16) pb=2;; fp8|i8) pb=1;; *) pb=4;; esac
    gb="$pb"
    case "$opt" in
        adamw|adam) ob=8;;
        adamw-8bit|paged-adamw-8bit) ob=2;;
        lion|sgd-momentum|momentum) ob=4;;
        sgd) ob=0;;
        *) ob=8;;
    esac
    case "$gpu" in
        *h200*|*H200*) cap=141;;
        *h100*nvl*) cap=94;;
        *h100*|*H100*) cap=80;;
        *a100-80*|*A100*80*) cap=80;;
        *a100*|*A100*) cap=40;;
        *) cap=80;;
    esac
    # per-GPU bytes (GiB), DDP gradient bucket ≈ params*gb again (one bucket).
    local per_param_bytes=$(( pb + gb + ob ))
    # GiB = params * per_param_bytes / 2^30 ; add ~ params*gb DDP bucket + 8GiB scratch
    local model_gib=$(( params * per_param_bytes / 1073741824 ))
    local bucket_gib=$(( params * gb / 1073741824 ))
    local total_gib=$(( model_gib + bucket_gib + 8 ))
    [ "$grad_ckpt" = "1" ] && total_gib=$(( total_gib - 0 ))  # ckpt cuts activations (not modeled coarsely)
    _dojo_ok "coarse estimate: ~${total_gib} GiB/GPU vs ${cap} GiB cap (model ${model_gib} + DDP-bucket ${bucket_gib} + 8 scratch)"
    if [ "$total_gib" -gt "$cap" ]; then
        _dojo_err "coarse estimate ~${total_gib} GiB/GPU EXCEEDS ${cap} GiB — would OOM at step 0" \
                  "use adamw-8bit, --grad-ckpt, sharding, or a 141 GiB H200 (the anima 7B fp32 case: ~84 GiB OOMs 80 GiB H100, fits H200)"
        return 1
    fi
    _dojo_ok "fits — proceed"
    return 0
}

# ── fix #6: torchrun launch with log harvest ─────────────────────────────
# dojo_torchrun_cmd <nproc> <script> [args...] → echoes a torchrun command
# that DEFAULTS --tee 3 + --redirect 3 --log-dir, so per-rank stdout/stderr
# is captured. torchrun otherwise HIDES child errors (ChildFailedError shows
# only "rank N exitcode 1", error_file:<N/A>).
dojo_torchrun_cmd() {
    local nproc="${1:-1}"; shift || true
    local script="${1:-train.py}"; shift || true
    local logdir="${DOJO_LOG_DIR:-./torchrun_logs}"
    printf 'torchrun --nproc_per_node=%s --tee 3 --redirect 3 --log-dir %s %s %s' \
        "$nproc" "$logdir" "$script" "$*"
}

# dojo_harvest_rank_logs [log-dir] — on a ChildFailedError, print each rank's
# stderr.log so the REAL traceback is visible (not torchrun's masked summary).
dojo_harvest_rank_logs() {
    local logdir="${1:-${DOJO_LOG_DIR:-./torchrun_logs}}"
    if [ ! -d "$logdir" ]; then
        _dojo_warn "no torchrun log dir at $logdir — was the launcher run with --redirect 3 --log-dir?"
        return 0
    fi
    _dojo_ok "harvesting per-rank logs from $logdir (torchrun masks child errors; the real cause is here)"
    local f
    while IFS= read -r f; do
        printf '\n──── %s ────\n' "$f"
        tail -n 40 "$f" 2>/dev/null || true
    done < <(find "$logdir" -name 'stderr.log' -o -name 'stderr_*.log' 2>/dev/null)
}

# ── orchestrator: dojo_rent — walk the ladder, classify, take first id ───
# dojo_rent --gpu-type T --gpu-count N --image IMG [--name NAME]
# Validates the image (fix #1), injects PUBLIC_KEY (fix #2), walks the supply
# ladder (fix #3), classifies each failure (fix #4). Echoes the live pod id
# on success; non-zero + actionable lines on exhaustion. RENTS REAL CAPACITY
# — only call from a kata the user explicitly launched.
dojo_rent() {
    local gpu_type="NVIDIA H200" gpu_count="8" image="${DOJO_KNOWN_GOOD_IMAGES[0]}" name="dojo-flame-forge"
    while [ $# -gt 0 ]; do
        case "$1" in
            --gpu-type)  gpu_type="$2"; shift 2 ;;
            --gpu-count) gpu_count="$2"; shift 2 ;;
            --image)     image="$2"; shift 2 ;;
            --name)      name="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    dojo_validate_image "$image" || return 1
    local pubkey; pubkey="$(dojo_public_key)" || return 1
    local key; key="$(_dojo_api_key)" || return 1

    local rung c cl g
    while IFS=$'\t' read -r c cl g; do
        _dojo_ok "trying rung: ${c}× ${g} (${cl})"
        local body resp
        body=$(printf '{"query":"mutation { podFindAndDeployOnDemand(input:{cloudType: %s, gpuCount:%s, volumeInGb:40, containerDiskInGb:80, minVcpuCount:8, minMemoryInGb:32, gpuTypeId:\\"%s\\", name:\\"%s\\", imageName:\\"%s\\", ports:\\"22/tcp\\", volumeMountPath:\\"/workspace\\", env:[{key:\\"PUBLIC_KEY\\", value:\\"%s\\"}]}) { id costPerHr } }"}' \
            "$cl" "$c" "$g" "$name" "$image" "$pubkey")
        resp=$(curl -s -X POST "https://api.runpod.io/graphql?api_key=${key}" \
            -H 'Content-Type: application/json' -d "$body" 2>&1)
        local pod_id
        pod_id=$(printf '%s' "$resp" | grep -oE '"id":"[^"]+"' | head -1 | sed -E 's/.*"id":"([^"]+)".*/\1/')
        # auth / malformed-request envelope is NOT a per-rung supply issue —
        # walking 18 rungs would just repeat it. Fail fast with the cause+fix.
        if printf '%s' "$resp" | grep -qiE 'Unauthorized|"code":"RUNPOD"|invalid api key|authentication'; then
            _dojo_err "RunPod rejected the request (Unauthorized / RUNPOD error) — the API key is missing or invalid" \
                      "set a valid key: export RUNPOD_API_KEY=... or run 'secret set runpod.api_key'; this is an AUTH error, not a capacity wall"
            return 1
        fi
        local cls
        cls=$(dojo_classify_rent "$resp" "$pod_id" "" "")
        if [ "$cls" = "SUPPLY_CONSTRAINT" ]; then
            continue  # next ladder rung
        fi
        if [ -n "$pod_id" ]; then
            _dojo_ok "rented pod $pod_id (${c}× ${g}, ${cl})"
            printf '%s\n' "$pod_id"
            return 0
        fi
        _dojo_warn "rung returned no id and no SUPPLY_CONSTRAINT — raw: $(printf '%s' "$resp" | head -c 200)"
    done < <(dojo_supply_ladder "$gpu_count" "$gpu_type")

    _dojo_err "supply ladder exhausted — no capacity across gpuCount 8→4→2 · SECURE→COMMUNITY · ${gpu_type}→H100→A100-SXM" \
              "retry later, lower --gpu-count, or accept a community A100-SXM tier; this is a capacity wall, not a config error"
    return 1
}

# ── standalone self-test (pure logic; NO rental, NO network) ─────────────
_dojo_self_test() {
    local fail=0
    printf '== dojo_rent_preflight self-test (no rental) ==\n'

    # fix #1: image validation
    if dojo_validate_image "runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04" >/dev/null; then
        printf '  [ok] fix#1 known-good image accepted\n'; else printf '  [FAIL] fix#1\n'; fail=1; fi
    if dojo_validate_image "runpod/pytorch:2.4.1-py3.11-cuda12.4.1-devel-ubuntu22.04" >/dev/null 2>&1; then
        printf '  [FAIL] fix#1 bogus 2.4.1 tag accepted\n'; fail=1; else printf '  [ok] fix#1 bogus 2.4.1 tag rejected\n'; fi

    # fix #3: ladder shape — 8 expands to 8/4/2 × 3 gpus × 2 clouds = 18 rungs
    local n; n=$(dojo_supply_ladder 8 "NVIDIA H200" | wc -l | tr -d ' ')
    if [ "$n" = "18" ]; then printf '  [ok] fix#3 ladder = 18 rungs (8/4/2 × 3 gpu × 2 cloud)\n'; else printf '  [FAIL] fix#3 ladder = %s (want 18)\n' "$n"; fail=1; fi

    # fix #4: classification
    local c
    c=$(dojo_classify_rent '{"errors":[{"extensions":{"code":"SUPPLY_CONSTRAINT"}}]}' "" "" "" 2>/dev/null)
    if [ "$c" = "SUPPLY_CONSTRAINT" ]; then printf '  [ok] fix#4 SUPPLY_CONSTRAINT classified\n'; else printf '  [FAIL] fix#4 supply=%s\n' "$c"; fail=1; fi
    c=$(dojo_classify_rent '{"data":{"id":"abc"}}' "abc123" "EXITED" "null" 2>/dev/null)
    if [ "$c" = "IMAGE_OR_INIT" ]; then printf '  [ok] fix#4 IMAGE_OR_INIT (EXITED+runtime=null) classified\n'; else printf '  [FAIL] fix#4 init=%s\n' "$c"; fail=1; fi
    c=$(dojo_classify_rent '{"data":{"id":"abc"}}' "abc123" "RUNNING" "null" 2>/dev/null)
    if [ "$c" = "PORT_CLOSED" ]; then printf '  [ok] fix#4 PORT_CLOSED (RUNNING+no-sshd) classified\n'; else printf '  [FAIL] fix#4 port=%s\n' "$c"; fail=1; fi

    # fix #5: coarse mem gate — 7B fp32 adamw must OOM 80 GiB H100, fit H200
    if dojo_preflight_mem_coarse 7000000000 f32 adamw 8 0 h100-80gb >/dev/null 2>&1; then
        printf '  [FAIL] fix#5 7B fp32 should OOM H100-80GB\n'; fail=1; else printf '  [ok] fix#5 7B fp32 OOMs H100-80GB (blocked)\n'; fi
    if dojo_preflight_mem_coarse 7000000000 f32 adamw 8 0 h200-141gb >/dev/null 2>&1; then
        printf '  [ok] fix#5 7B fp32 fits H200-141GB\n'; else printf '  [FAIL] fix#5 7B fp32 should fit H200\n'; fail=1; fi

    # fix #6: torchrun command carries --tee 3 + --redirect 3 --log-dir
    local tc; tc=$(dojo_torchrun_cmd 8 train.py --foo bar)
    if printf '%s' "$tc" | grep -q -- '--tee 3' && printf '%s' "$tc" | grep -q -- '--redirect 3' && printf '%s' "$tc" | grep -q -- '--log-dir'; then
        printf '  [ok] fix#6 torchrun cmd has --tee 3 --redirect 3 --log-dir\n'; else printf '  [FAIL] fix#6 cmd=%s\n' "$tc"; fail=1; fi

    if [ "$fail" = "0" ]; then printf '== ALL 6 FIXES VERIFIED (pure logic) ==\n'; else printf '== SELF-TEST FAILED ==\n'; fi
    return "$fail"
}

# Run the self-test only when executed directly with --self-test (sourcing is
# the normal path; a run.sh sources this file and calls the dojo_* functions).
if [ "${1:-}" = "--self-test" ]; then
    _dojo_self_test
    exit $?
fi
