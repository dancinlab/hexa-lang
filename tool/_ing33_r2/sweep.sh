#!/usr/bin/env bash
# ING #33 r2 — sibling-seam sweep + dead-wrapper symbol-coverage proof.
# Runs on summer (nvcc present). Builds the CUDA-variant runtime.a from the
# r2 branch source, then enumerates:
#   (A) every forge_dispatch_* / hexa_forge_dispatch_* symbol exported (T) by runtime.a
#   (B) any consumer-facing symbol UNDEFINED (U) in runtime.a that is only
#       provided under #ifndef HEXA_CUDA in the SSOT (sibling-seam risk)
#   (C) the 3 dead-wrapper symbols are all covered by the SSOT archive
#       (so deletion is undefined-ref-safe)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
echo "==== ING#33 r2 sweep — ROOT=$ROOT  branch=$(git branch --show-current) head=$(git rev-parse --short HEAD)"

# CUDA env
export CUDA_HOME="${CUDA_HOME:-/usr/local/cuda}"
export PATH="$CUDA_HOME/bin:$PATH"
command -v nvcc >/dev/null 2>&1 && echo "nvcc: $(nvcc --version | tail -1)" || { echo "NO nvcc — abort"; exit 2; }
SM="${SM:-120}"; export SM

# Build CUDA-variant runtime.a via the release-faithful stage.
export CC="${CC:-cc}"
export HEXA_CUDA=1
export CFLAGS_COMMON="-O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs"
echo "==== stage_resolve_runtime_a (HEXA_CUDA=1) ..."
bash tool/stage_resolve_runtime_a 2>&1 | tail -25
RA="build/runtime.a"
if [ ! -f "$RA" ]; then echo "FAIL: $RA not produced"; exit 3; fi
echo "==== runtime.a built: $(ls -l $RA | awk '{print $5}') bytes"

echo ""
echo "######## (A) forge_dispatch symbols EXPORTED (T) by CUDA-variant runtime.a ########"
nm "$RA" 2>/dev/null | grep -iE ' T (hexa_)?forge_dispatch_' | awk '{print $3}' | sort -u | tee /tmp/r2_fd_exported.txt
echo "---- count exported = $(wc -l < /tmp/r2_fd_exported.txt)"

echo ""
echo "######## forge_dispatch symbols UNDEFINED (U) in runtime.a (should be 0 of the host family) ########"
nm "$RA" 2>/dev/null | grep -iE ' U (hexa_)?forge_dispatch_' | awk '{print $2}' | sort -u | tee /tmp/r2_fd_undef.txt
echo "---- count undefined = $(wc -l < /tmp/r2_fd_undef.txt)"

echo ""
echo "######## (B) ALL undefined (U) symbols in runtime.a (full sibling sweep) ########"
# Anything U here that no other shipped object provides = a link risk for a -DHEXA_CUDA consumer.
nm "$RA" 2>/dev/null | grep -E ' U ' | awk '{print $2}' | sort -u > /tmp/r2_all_undef.txt
echo "---- total distinct undefined = $(wc -l < /tmp/r2_all_undef.txt)"
echo "---- undefined that look like host-seam dispatchers / hx_* glue (candidate siblings):"
grep -iE 'dispatch|^_?hx_|forge|_gpu$|fused|megafwd|valley|moe_|groupnorm|im2col|adamw' /tmp/r2_all_undef.txt | sort -u | tee /tmp/r2_undef_candidates.txt
echo "---- candidate count = $(wc -l < /tmp/r2_undef_candidates.txt 2>/dev/null || echo 0)"

echo ""
echo "######## (C) dead-wrapper symbol coverage proof ########"
# Every forge_dispatch symbol the 3 dead wrappers define must already be a T in runtime.a.
for s in forge_dispatch_adamw_fused hexa_forge_dispatch_adamw_fused \
         forge_dispatch_clm_megafwd hexa_forge_dispatch_clm_megafwd \
         forge_dispatch_moe_block2 hexa_forge_dispatch_moe_block2 ; do
  if nm "$RA" 2>/dev/null | grep -qE " T $s$"; then echo "  COVERED (T in runtime.a): $s"
  else echo "  *** MISSING from runtime.a: $s ***"; fi
done
echo "  -- clm_valley1/valley2: are they referenced by any non-dead consumer? (expect 0)"
nm "$RA" 2>/dev/null | grep -iE 'clm_valley' || echo "  (no clm_valley symbol in runtime.a — wrapper-only, safe to delete)"

echo ""
echo "######## (D) consumer link probe — undefined refs from a forge-dispatch-calling TU ########"
# Build clm_prod.hexa's transpiled object if a runner exists; else synthesize a
# tiny C TU that calls the full forge_dispatch host family and link against runtime.a.
cat > /tmp/r2_probe.c <<'PROBE'
#include <stdint.h>
typedef struct { int64_t a, b; } HexaVal;
/* declare the consumer-facing host dispatchers anima/clm_prod call */
extern HexaVal forge_dispatch_groupnorm_gelu();
extern HexaVal forge_dispatch_groupnorm();
extern HexaVal forge_dispatch_gelu();
extern HexaVal forge_dispatch_im2col();
extern HexaVal forge_dispatch_moe_router();
extern HexaVal forge_dispatch_adamw();
extern HexaVal forge_dispatch_matmul();
extern HexaVal forge_dispatch_adamw_fused();
extern HexaVal forge_dispatch_clm_megafwd();
extern HexaVal forge_dispatch_moe_block2();
extern HexaVal forge_dispatch_residual_add();
extern HexaVal forge_dispatch_groupnorm_gelu_residual();
int main(void){
  volatile void* p[12];
  p[0]=(void*)forge_dispatch_groupnorm_gelu; p[1]=(void*)forge_dispatch_groupnorm;
  p[2]=(void*)forge_dispatch_gelu; p[3]=(void*)forge_dispatch_im2col;
  p[4]=(void*)forge_dispatch_moe_router; p[5]=(void*)forge_dispatch_adamw;
  p[6]=(void*)forge_dispatch_matmul; p[7]=(void*)forge_dispatch_adamw_fused;
  p[8]=(void*)forge_dispatch_clm_megafwd; p[9]=(void*)forge_dispatch_moe_block2;
  p[10]=(void*)forge_dispatch_residual_add; p[11]=(void*)forge_dispatch_groupnorm_gelu_residual;
  return (int)(intptr_t)p[0];
}
PROBE
LDEXTRA=""
[ -f build/runtime_cuda.o ] && LDEXTRA="$LDEXTRA build/runtime_cuda.o"
[ -f build/runtime_cuda_dlink.o ] && LDEXTRA="$LDEXTRA build/runtime_cuda_dlink.o"
echo "  link probe: cc -DHEXA_CUDA r2_probe.c runtime.a $LDEXTRA -lm -lcudart -lcuda -lcudadevrt"
if cc -DHEXA_CUDA /tmp/r2_probe.c "$RA" $LDEXTRA -L"$CUDA_HOME/lib64" -lm -lcudart -lcuda -lcudadevrt -o /tmp/r2_probe 2>/tmp/r2_link.err; then
  echo "  LINK GREEN — 0 undefined forge_dispatch refs"
else
  echo "  LINK had errors — filtering for forge_dispatch undefined refs:"
  grep -iE 'undefined reference to .forge_dispatch|undefined reference to .hexa_forge' /tmp/r2_link.err || echo "  (no forge_dispatch undefined refs — other libs missing is fine)"
  echo "  --- full link stderr tail ---"; tail -20 /tmp/r2_link.err
fi
echo ""
echo "==== SWEEP DONE ===="
