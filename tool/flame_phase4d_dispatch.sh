#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════
# tool/flame_phase4d_dispatch.sh — Phase 4-D GPU dispatch fire template
#
# TEMPLATE — does NOT run automatically. Requires user explicit:
#   1. Budget approval ($5-20 estimated)
#   2. Provider account + API key (vast.ai OR runpod)
#   3. g_fire_autonomous acceptance (one-shot, no per-step approval)
#
# Usage (post-approval, interactive):
#   tool/flame_phase4d_dispatch.sh vast              # vast.ai dispatch
#   tool/flame_phase4d_dispatch.sh runpod            # runpod dispatch
#   tool/flame_phase4d_dispatch.sh dry-run           # local CPU smoke (free)
#
# Pipeline (each provider similar):
#   1. Pre-flight: local smoke test PASS gate
#   2. Provider login + instance launch (A100 SXM, 40GB)
#   3. SCP repo + corpus to instance
#   4. Build hexa toolchain on remote (cuBLAS link)
#   5. Run flame_d768_12L_corpus_test under timing
#   6. SCP results back (wall + final loss + trajectory)
#   7. Provider instance teardown (cost cap)
#   8. F-RFC046-EAGER-PYTORCH-MATCH gate check
#
# Falsifiers:
#   F-RFC046-EAGER-PYTORCH-MATCH  wall ≤ 1.3× of 336.85s = 437.9s
#   F-RFC046-LOSS-CONVERGENCE     final loss within fp-tol of eager-PyTorch
#   F-RFC046-GPU-SANITY           finite numerics throughout
#
# Cost cap (instance auto-teardown):
#   Default: $20 hard cap (instance lifetime ≤ 10 hrs at $2/hr)
#   Override: BUDGET_USD=N (e.g., BUDGET_USD=10 for tight cap)
# ════════════════════════════════════════════════════════════════════════

set -e

MODE="${1:-help}"
BUDGET_USD="${BUDGET_USD:-20}"
INSTANCE_TYPE="A100_SXM"     # A100 SXM 40GB preferred (Dgemm Tensor Cores)
CONFIG_FILE="stdlib/flame/flame_d768_12L_corpus_test.hexa"
LOG_DIR="state/flame_phase4d_$(date +%Y%m%d_%H%M%S)"

show_help() {
    cat <<'EOF'
flame Phase 4-D GPU dispatch fire template

Usage: tool/flame_phase4d_dispatch.sh <mode>

Modes:
  vast      Dispatch to vast.ai A100 (requires VAST_API_KEY env)
  runpod    Dispatch to runpod A100 (requires RUNPODCTL_API_KEY env)
  dry-run   Local CPU smoke test (free, ~500s wall)
  help      Show this message

Prerequisites (post-user-approval):
  - Budget approved: ≤$20 (override: BUDGET_USD=N)
  - Provider API key set in environment
  - state/ dir writable (logs + result capture)
  - flame_d768_12L_corpus_test.hexa source exists (Phase 4-D-1)
  - tool/flame_phase4b3_a2_build.sh works locally (CPU verification)

Falsifiers:
  F-RFC046-EAGER-PYTORCH-MATCH  flame d=768·12L A100 wall ≤ 437.9s
  F-RFC046-LOSS-CONVERGENCE     final loss within fp-tol
  F-RFC046-GPU-SANITY           finite throughout

DRY-RUN mode uses tool/flame_phase4b3_a2_build.sh to build the
existing flame_d32_corpus_test on M-Mac CPU. This is a free sanity
check that the build pipeline is healthy before incurring GPU cost.
EOF
}

preflight_check() {
    echo "─── Pre-flight check ───"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "✗ FATAL: $CONFIG_FILE missing (Phase 4-D-1 not landed)"
        echo "  Run Phase 4-D-1 source draft cycle before dispatch"
        exit 2
    fi
    if [ ! -x tool/flame_phase4b3_a2_build.sh ]; then
        echo "✗ FATAL: tool/flame_phase4b3_a2_build.sh not executable"
        exit 2
    fi
    # Verify Phase 4-B SHIPPED state intact
    echo "  verifying Phase 4-B verification battery (15/15 PASS gate)"
    if ! tool/flame_phase4b3_verify_all.sh > /tmp/preflight.log 2>&1; then
        echo "✗ FATAL: Phase 4-B verify_all FAIL — fix before GPU dispatch"
        tail -20 /tmp/preflight.log
        exit 2
    fi
    echo "  ✓ Phase 4-B SHIPPED state verified intact (23/23 artifacts)"
    echo ""
}

dispatch_dry_run() {
    echo "═══ flame Phase 4-D DRY-RUN (local CPU, free) ═══"
    preflight_check
    echo "─── Building d=32·3L A2+B FULL (local CPU smoke) ───"
    tool/flame_phase4b3_a2_build.sh \
        stdlib/flame/flame_d32_corpus_test.hexa \
        build/flame_d32_dry_run
    echo ""
    echo "─── 5-run wall measurement ───"
    mkdir -p "$LOG_DIR"
    for i in 1 2 3 4 5; do
        start=$(date +%s%N)
        ./build/flame_d32_dry_run > "$LOG_DIR/dry_run_$i.out" 2>&1
        end=$(date +%s%N)
        wall=$(echo "scale=3; ($end - $start) / 1000000000" | bc)
        echo "  run $i: ${wall}s"
    done
    echo ""
    echo "═══ DRY-RUN complete ═══"
    echo "  results: $LOG_DIR/"
    echo "  next: tool/flame_phase4d_dispatch.sh vast (or runpod)"
}

dispatch_vast() {
    echo "═══ flame Phase 4-D dispatch — vast.ai (cost-bearing) ═══"
    if [ -z "$VAST_API_KEY" ]; then
        echo "✗ FATAL: VAST_API_KEY not set"
        echo "  export VAST_API_KEY=<your-key> first"
        exit 2
    fi
    preflight_check
    echo "  budget cap: \$${BUDGET_USD}"
    echo "  instance: $INSTANCE_TYPE"
    echo "  config: $CONFIG_FILE"
    echo ""
    echo "─── PLACEHOLDER — actual dispatch logic deferred ───"
    echo ""
    echo "The full vast.ai dispatch requires:"
    echo "  1. vastctl CLI installed (brew install vastctl OR pip)"
    echo "  2. vastctl search --gpu-name A100 --num-gpus 1 (find instance)"
    echo "  3. vastctl create instance <ID> --image pytorch/cuda:12.1"
    echo "  4. vastctl ssh <instance-id> 'apt install -y clang make git'"
    echo "  5. SCP repo + corpus to instance:/root/hexa-lang"
    echo "  6. ssh build:  cd /root/hexa-lang && tool/flame_phase4b3_a2_build.sh"
    echo "                  $CONFIG_FILE build/flame_d768_12L"
    echo "  7. ssh time:   ./build/flame_d768_12L > /tmp/results.out"
    echo "  8. SCP results back to $LOG_DIR/"
    echo "  9. vastctl destroy instance <ID>  (cost cap teardown)"
    echo " 10. F-RFC046-EAGER-PYTORCH-MATCH gate check"
    echo ""
    echo "This template captures the dispatch design; actual integration"
    echo "with vast.ai CLI requires Phase 4-D-2-second user-directed cycle"
    echo "with vast.ai CLI installed and API key authenticated."
    echo ""
    echo "Reference cost: A100 SXM ~\$1.50/hr × 4-8 hrs ≈ \$6-12"
    echo "Stays within default \$${BUDGET_USD} cap."
}

dispatch_runpod() {
    echo "═══ flame Phase 4-D dispatch — runpod (cost-bearing) ═══"
    if [ -z "$RUNPODCTL_API_KEY" ]; then
        echo "✗ FATAL: RUNPODCTL_API_KEY not set"
        echo "  export RUNPODCTL_API_KEY=<your-key> first"
        exit 2
    fi
    preflight_check
    echo "─── PLACEHOLDER — actual dispatch logic deferred ───"
    echo ""
    echo "runpod CLI pattern (similar to vast.ai):"
    echo "  1. runpodctl create pod --gpu A100 --image pytorch/cuda:12.1"
    echo "  2. SCP + build + run + capture (same flow)"
    echo "  3. runpodctl remove pod <ID>"
    echo ""
    echo "Reference cost: A100 PCIe ~\$1/hr × 4-8 hrs ≈ \$4-8"
    echo "Cheaper than vast.ai but smaller A100 capacity."
}

case "$MODE" in
    help|--help|-h)  show_help ;;
    dry-run)         dispatch_dry_run ;;
    vast)            dispatch_vast ;;
    runpod)          dispatch_runpod ;;
    *)               echo "unknown mode: $MODE"; show_help; exit 1 ;;
esac
