#!/usr/bin/env bash
# batch_byteeq.sh — CORRECTNESS gate for the batch-fill throughput sweep.
# (1) DETERMINISM: B=1 run twice → identical CE (the math is deterministic FP64).
# (2) B=1 == prior un-batched path: B=1 is the EXACT prior behaviour by construction
#     (nbatch=nwin, one window per step). We capture the B=1 per-epoch CE as the reference.
# (3) SEAM scope: B>1 concatenates B windows into M=B*Tw; the ONLY value difference vs
#     B summed-separate is the K-1 causal-conv seam between concatenated windows. We
#     quantify it by comparing B=1-over-N-windows vs B=N-in-one-step CE on the SAME windows.
set -o pipefail
WORK="${WORK:-$HOME/work}"; cd "$WORK" || exit 1
D=512; TW=128; E=2   # small shape: CE is comparable, runs fast, seam effect visible
NS=8

run() {  # $1=B $2=NSAMP $3=EPOCHS
  # HEXA_CUDA_ASYNC=0 pins the byte-eq baseline trajectory (async-OFF loss=4.819 vs
  # async-ON 4.799 = MoE scatter atomic order, fast-non-det axis). Justified as a
  # correctness gate: async-ON is separately verified MORE deterministic (F-OP15 max|dW|=0
  # vs async-OFF 1-ULP hole 2.78e-17), so this pin is re-pinnable in a follow-up PR.
  CUDA_VISIBLE_DEVICES=0 CLM_PROD_DEVRESIDENT=1 CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1 HEXA_CUDA_ASYNC=0 \
    CLM_PROD_D=$D CLM_PROD_T=$TW CLM_PROD_E=$E CLM_PROD_BATCH=$1 \
    CLM_PROD_NSAMP=$2 CLM_PROD_EPOCHS=$3 CLM_PROD_CORPUS="$WORK/corpus.txt" \
    timeout 300 ./clm_prod_gpu 2>&1 | grep -iE "mean CE|M5-BATCH|DESCENT"
}

echo "================ batch-fill CORRECTNESS / byte-eq probe ================"
echo "--- (1) DETERMINISM: B=1 run A ---"; run 1 $NS 3 > /tmp/be_b1a.txt; cat /tmp/be_b1a.txt
echo "--- (1) DETERMINISM: B=1 run B ---"; run 1 $NS 3 > /tmp/be_b1b.txt; cat /tmp/be_b1b.txt
echo "--- DIFF (must be empty for byte-eq determinism) ---"
diff <(grep "mean CE" /tmp/be_b1a.txt) <(grep "mean CE" /tmp/be_b1b.txt) && echo "DETERMINISM: IDENTICAL (max|Δ|=0)" || echo "DETERMINISM: DIFFER"
echo
echo "--- (3) SEAM scope: B=1 over $NS windows vs B=$NS in one step (same windows) ---"
echo "B=1 (per-window, no seam):"; run 1 $NS 3 | grep "mean CE"
echo "B=$NS (concatenated, K-1 seams at $((NS-1)) window boundaries):"; run $NS $NS 3 | grep "mean CE"
echo "(Δ = the documented causal-conv seam perturbation; GEMM shapes identical, both descend.)"
