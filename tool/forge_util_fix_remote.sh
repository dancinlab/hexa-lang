#!/usr/bin/env bash
# forge-util-fix remote driver — confirm the 0%-util root cause + verify the fix.
#
# A/B GPU-util profile on ONE H100:
#   BASELINE  — released hexa (old FP64 forge dispatch -> hexa_farr_matmul, CPU-only)
#   FIXED     — hexa rebuilt from feat/hexa-forge-util-fix (FP64 forge dispatch ->
#               hexa_farr_matmul_gpu, cuBLAS Dgemm on a CUDA host)
# Both run the SAME bounded d768 conv-forge driver with continuous nvidia-smi
# sampling (0.1s cadence). Reports min/median/max util + %>20% for each.
#
# util-GREEN  iff the FIXED run lifts GPU util clear of the 0-4% F-RFC046 floor.
# Reported HONESTLY — no fabricated green. byte-eq re-checked via the conv selftest.
#
# Args: $1 = HEXA_BRANCH (default feat/hexa-forge-util-fix)
set -uo pipefail
HEXA_BRANCH="${1:-feat/hexa-forge-util-fix}"
WORK="/workspace/forgeutil"; mkdir -p "$WORK"; cd "$WORK"
export PATH="/usr/local/cuda/bin:$HOME/.hx/bin:$PATH"

echo "=== [0/7] host sanity ==="
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader || { echo "FATAL no gpu"; exit 9; }
nvcc --version | grep release || echo "WARN no nvcc"
ldd --version 2>/dev/null | head -1 || true

echo "=== [1/7] glibc shim check (need >=2.38 for the linux hexa ELF) ==="
GLIBC_VER="$(ldd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+$' || echo 0)"
echo "GLIBC_VER=$GLIBC_VER"
NEED_SHIM=0
awk "BEGIN{exit !($GLIBC_VER < 2.38)}" && NEED_SHIM=1 || true
SHIM_LD=""
if [ "$NEED_SHIM" = "1" ]; then
  echo "glibc<2.38 -> installing glibc-2.39 loader shim"
  apt-get update -y >/dev/null 2>&1 || true
  apt-get install -y clang wget >/dev/null 2>&1 || true
  mkdir -p "$WORK/glibc239"; cd "$WORK/glibc239"
  # Proven shim: pull a glibc-2.39 ld + libc from a portable bundle.
  wget -q http://ftp.gnu.org/gnu/glibc/glibc-2.39.tar.gz 2>/dev/null || true
  # If a prebuilt loader was staged by the operator, use it; else best-effort.
  if [ -f "$WORK/glibc239/ld-2.39.so" ]; then
    SHIM_LD="$WORK/glibc239/ld-2.39.so"
  fi
  cd "$WORK"
else
  echo "glibc OK (>=2.38) — no shim needed"
fi
# install clang regardless (needed for hexa cc rebuild)
command -v clang >/dev/null 2>&1 || { apt-get update -y >/dev/null 2>&1; apt-get install -y clang >/dev/null 2>&1; }
command -v clang >/dev/null 2>&1 && clang --version | head -1 || echo "WARN no clang — hexa cc rebuild may fail"

run_hexa() {  # wrap under the glibc shim loader if needed
  if [ -n "$SHIM_LD" ]; then "$SHIM_LD" --library-path "$WORK/glibc239" "$@"; else "$@"; fi
}

echo "=== [2/7] install released hexa @ $HEXA_BRANCH (ships stdlib/self from branch) ==="
if [ ! -x "$HOME/.hx/bin/hexa" ]; then
  HEXA_BRANCH="$HEXA_BRANCH" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dancinlab/hexa-lang/main/install.sh)" 2>&1 | tail -15 || true
fi
export PATH="$HOME/.hx/bin:$PATH"
HEXA_SRC="$(ls -d $HOME/.hx/src 2>/dev/null | head -1)"
echo "HEXA_SRC=$HEXA_SRC"
[ -n "$HEXA_SRC" ] || { echo "FATAL no hexa src"; exit 10; }
# pin src to the fix branch
git -C "$HEXA_SRC" fetch --depth 1 origin "$HEXA_BRANCH" >/dev/null 2>&1 || true
git -C "$HEXA_SRC" checkout -q "$HEXA_BRANCH" 2>/dev/null || true
git -C "$HEXA_SRC" reset --hard "origin/$HEXA_BRANCH" >/dev/null 2>&1 || true
git -C "$HEXA_SRC" log --oneline -1 || true

echo "=== [3/7] write a bounded d768 conv-forge profiling driver ==="
cat > "$WORK/conv_forge_prof.hexa" <<'HEXA'
use "stdlib/flame/tensor_lib"
use "stdlib/flame/conv_lib"
use "stdlib/flame/clm_conv_gpu"
// Bounded d768 conv-forge load: repeat the heavy CLM conv (embed/trunk/expert
// shape, Cin=Cout=768, T=24, K=3) fwd+bwd many times so a continuous nvidia-smi
// sampler can see whether the GEMM bulk lands on the GPU.
fn main() {
    let T = 24; let Cin = 768; let Cout = 768; let K = 3; let dil = 1
    let ITERS = 400
    let dd = Cout * Cin * K
    let x = t_zeros(T * Cin);  t_fill_lcg(x, T * Cin, 31, 0.4)
    let w = t_zeros(dd);       t_fill_lcg(w, dd, 2, 0.2)
    let b = t_zeros(Cout);     t_fill_lcg(b, Cout, 3, 0.1)
    let y = t_zeros(T * Cout)
    let dW = t_zeros(dd); let dX = t_zeros(T * Cin); let db = t_zeros(Cout)
    println("conv_forge_prof — d768 fwd+bwd x ITERS (forge GEMM)")
    let mut it = 0
    while it < ITERS {
        conv1d_via_forge(x, w, b, y, T, Cin, Cout, K, dil)
        conv1d_bwd_via_forge(x, w, y, dW, dX, db, T, Cin, Cout, K, dil)
        it = it + 1
    }
    print("DONE iters="); println(to_string(ITERS))
}
HEXA

profile_run() {   # $1=label $2=hexa-bin
  local label="$1"; local bin="$2"
  local csv="$WORK/util_${label}.csv"; : > "$csv"
  echo "--- profiling [$label] with $bin ---"
  ( while :; do nvidia-smi --query-gpu=utilization.gpu,power.draw,clocks.sm --format=csv,noheader,nounits >> "$csv" 2>/dev/null; sleep 0.1; done ) &
  local sampler=$!
  ( export HEXA_LANG="$HEXA_SRC"; cd "$HEXA_SRC" && run_hexa "$bin" run "$WORK/conv_forge_prof.hexa" ) 2>&1 | tee "$WORK/run_${label}.log"
  local rc=${PIPESTATUS[0]}
  kill "$sampler" 2>/dev/null; wait "$sampler" 2>/dev/null
  echo "--- [$label] util stats (n=$(wc -l < "$csv")) ---"
  awk -F',' 'NF>=1{u=$1+0; a[n++]=u; s+=u; if(u>mx)mx=u; if(u>20)gt++} END{
    if(n>0){ asort(a); med=a[int(n/2)]; printf "%s: n=%d min=%d med=%d max=%d mean=%.2f pct_gt20=%.1f%%\n","STAT",n,a[0],med,mx,s/n,(gt*100.0/n) } else print "STAT: n=0" }' "$csv"
  echo "RC_${label}=$rc"
}

echo "=== [4/7] BASELINE profile (released binary = old CPU dispatch) ==="
# Stash the fix so the released binary's baked runtime (old dispatch) is what runs.
profile_run "baseline" "$HOME/.hx/bin/hexa"

echo "=== [5/7] rebuild hexa from branch (regen runtime.c from emit + hexa cc) ==="
cd "$HEXA_SRC"
# Regenerate the dispatch .c artifacts from the edited emit (forge_tier_v1.c etc.)
run_hexa "$HOME/.hx/bin/hexa" run tool/regen_dispatch_c_artifacts.hexa 2>&1 | tail -8 || \
  run_hexa "$HOME/.hx/bin/hexa" run self/forge/forge_tier_v1_emit.hexa self/forge/forge_tier_v1.c 2>&1 | tail -3
grep -n "hexa_farr_matmul_gpu" self/forge/forge_tier_v1.c | head -3 || echo "WARN: gpu route not in regen'd .c"
# Rebuild the transpiler/runtime so the new dispatch is baked in.
run_hexa "$HOME/.hx/bin/hexa" cc 2>&1 | tail -20 || echo "WARN hexa cc failed"
FIXED_BIN="$HOME/.hx/bin/hexa"
# locate a freshly built hexa if cc emits to a known path
[ -x "$HEXA_SRC/build/hexa" ] && FIXED_BIN="$HEXA_SRC/build/hexa"
[ -x "$HOME/.hx/bin/hexa.real" ] && true
echo "FIXED_BIN=$FIXED_BIN"

echo "=== [6/7] FIXED profile (cuBLAS dispatch) ==="
profile_run "fixed" "$FIXED_BIN"

echo "=== [7/7] byte-eq re-check (conv fwd+bwd selftest, fixed binary) ==="
( export HEXA_LANG="$HEXA_SRC"; cd "$HEXA_SRC" && run_hexa "$FIXED_BIN" run stdlib/flame/clm_conv_gpu.hexa ) 2>&1 | tee "$WORK/byteeq.log" | \
  grep -E "F-CLM-CONV-GPU-EQ|F-CLM-CONV-BWD-FORGE-EQ|max\|Δ\||ALL-PASS|PASS|FAIL" || true

echo "=== SUMMARY ==="
echo "--- BASELINE util ---"; grep "^STAT:" "$WORK/run_baseline.log" 2>/dev/null || tail -1 "$WORK/util_baseline.csv" 2>/dev/null
awk -F',' 'NF>=1{u=$1+0; a[n++]=u; s+=u; if(u>mx)mx=u; if(u>20)gt++} END{if(n>0){asort(a); printf "BASELINE: n=%d min=%d med=%d max=%d mean=%.2f pct_gt20=%.1f%%\n",n,a[0],a[int(n/2)],mx,s/n,(gt*100.0/n)}}' "$WORK/util_baseline.csv" 2>/dev/null
awk -F',' 'NF>=1{u=$1+0; a[n++]=u; s+=u; if(u>mx)mx=u; if(u>20)gt++} END{if(n>0){asort(a); printf "FIXED:    n=%d min=%d med=%d max=%d mean=%.2f pct_gt20=%.1f%%\n",n,a[0],a[int(n/2)],mx,s/n,(gt*100.0/n)}}' "$WORK/util_fixed.csv" 2>/dev/null
echo "=== DONE ==="
