#!/usr/bin/env bash
# ── Lane-G lever-4 FRESH-POD driver: full bootstrap → 3-gate → byte-eq → util fire ──
# Single detached driver (survives SSH drops). Logs to /root/lever4.log.
set -u
exec > /root/lever4.log 2>&1
echo "=== LEVER-4 FRESH-POD DRIVER START $(date -u +%FT%TZ) ==="
REPO=/root/hexa-lang
BRANCH=lane-g/rfc046-lever3-batched-gemmfeed  # lever-4 merged here via PR #2543
export HEXA_LANG="$REPO" DEBIAN_FRONTEND=noninteractive

echo "=== [0] toolchain (cuda toolkit + clang) ==="
nvidia-smi --query-gpu=name,compute_cap --format=csv,noheader | head -1
apt-get install -y -qq clang file patchelf wget gnupg 2>&1 | tail -1
# need CUDA >= 11.8 for sm_90 (Hopper). distro nvidia-cuda-toolkit is 11.5 (sm_86 max,
# fails -arch=sm_90), so install cuda-toolkit-12-4 from the NVIDIA apt repo.
if [ ! -x /usr/local/cuda-12.4/bin/nvcc ] && [ ! -x /usr/local/cuda/bin/nvcc ]; then
  echo "  installing cuda-toolkit-12-4 from NVIDIA repo ..."
  wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb -O /tmp/ck.deb 2>&1 | tail -1
  dpkg -i /tmp/ck.deb 2>&1 | tail -1
  apt-get update -qq 2>&1 | tail -1
  apt-get install -y -qq cuda-toolkit-12-4 2>&1 | tail -2
fi
if [ -x /usr/local/cuda-12.4/bin/nvcc ]; then export PATH="/usr/local/cuda-12.4/bin:$PATH"; export CUDA_HOME=/usr/local/cuda-12.4;
elif [ -x /usr/local/cuda/bin/nvcc ]; then export PATH="/usr/local/cuda/bin:$PATH"; export CUDA_HOME=/usr/local/cuda; fi
echo "  nvcc: $(nvcc --version 2>/dev/null | tail -1 || echo MISSING)"
echo "  clang: $(command -v clang || echo MISSING)"
if ! command -v nvcc >/dev/null 2>&1; then echo "FATAL: no nvcc — cannot build CUDA"; echo "DRIVER-EXIT=10"; exit 10; fi

echo "=== [1] clone lever-4 branch ==="
rm -rf "$REPO"
git clone --depth 1 --branch "$BRANCH" https://github.com/dancinlab/hexa-lang.git "$REPO" 2>&1 | tail -2
cd "$REPO" || { echo "FATAL: clone failed"; exit 11; }
git log -1 --format="%h %s"

echo "=== [2] restore frozen seeds → base runtime.c ==="
if [ -x tool/restore_frozen_seeds ]; then bash tool/restore_frozen_seeds 2>&1 | tail -3; fi
ls -la self/runtime.c 2>&1 | tail -1
BASE_RT=self/runtime.c
if [ ! -f "$BASE_RT" ]; then echo "FATAL: no base runtime.c after restore"; exit 12; fi

echo "=== [3] splice lever fragments (a + 2-unbatched + 3-batched + 4) after BF16 externs ==="
cat > /root/lever2_unbatched.c.txt <<'L2EOF'
/* ═══════════════════════════════════════════════════════════════════
 * LEVER (2) — UN-BATCHED transpose-aware GEMM-feed wrappers
 * (reconstructed from runtime.h decls + the lever-2 byte-eq FIX host
 * fallbacks — the original #2515/403735b29 bodies lived only in the lost
 * pod seed). The host fallback DELEGATES through the identical host
 * transpose the oracle reference uses (bit-identical, max|Δ|=0.0); the
 * byte-eq oracle (clm_gemmfeed_eq.hexa, F-RFC046-GEMMFEED-EQ) is the HARD
 * gate that catches any reconstruction drift.
 *
 * _bt : C[M,N] = A[M,K] @ B^T,  B stored row-major [N,K].
 * _atb: C[M,N] = A^T @ B,       A stored row-major [K,M].
 * ═══════════════════════════════════════════════════════════════════ */
HexaVal hexa_forge_dispatch_matmul_bt(HexaVal a_v, HexaVal m_v, HexaVal k_v,
                                      HexaVal b_v, HexaVal n_v, HexaVal c_v) {
    int64_t a_id = hexa_as_num(a_v);
    int64_t M    = hexa_as_num(m_v);
    int64_t K    = hexa_as_num(k_v);
    int64_t b_id = hexa_as_num(b_v);
    int64_t N    = hexa_as_num(n_v);
    int64_t c_id = hexa_as_num(c_v);
    if (M <= 0 || K <= 0 || N <= 0) return hexa_int(-1);
    if (a_id < 0 || a_id >= _hx_farr_count) return hexa_int(-1);
    if (b_id < 0 || b_id >= _hx_farr_count) return hexa_int(-1);
    if (c_id < 0 || c_id >= _hx_farr_count) return hexa_int(-1);
    if (_hx_farr_table[c_id].len < M * N) return hexa_int(-1);
#ifdef HEXA_CUDA
    extern int _hx_cuda_farr_matmul_bt_gpu(int64_t, int64_t, int64_t,
                                           int64_t, int64_t, int64_t);
    int grc = _hx_cuda_farr_matmul_bt_gpu(a_id, M, K, b_id, N, c_id);
    if (grc == 0) return hexa_int(0);
    /* GPU path failed — fall through to the host fallback (correctness kept). */
#endif
    /* no-CUDA host fallback — BYTE-EQ contract (max|Δ|=0.0). The oracle/lever-2
     * reference is host-transpose B[N,K] → Wt[K,N] THEN hexa_farr_matmul(A,M,K,
     * Wt,N). An open-coded ijk dot drifts ~1e-14 from hexa_farr_matmul's ikj
     * unrolled (FMA-contracted) loop, so DELEGATE through the identical Wt
     * transpose — bit-identical by construction. Re-fetch buf by id after each
     * alloc (realloc-move safe). */
    {
        HexaVal wt_h = hexa_farr_zeros(hexa_int(K * N));
        int64_t wt_id = HX_INT(wt_h);
        if (wt_id < 0 || wt_id >= _hx_farr_count) return hexa_int(-1);
        const double* B = _hx_farr_table[b_id].buf;
        double* Wt = _hx_farr_table[wt_id].buf;
        for (int64_t n = 0; n < N; n++)
            for (int64_t k = 0; k < K; k++)
                Wt[k * N + n] = B[n * K + k];
        HexaVal csl = hexa_farr_matmul(hexa_int(a_id), hexa_int(M), hexa_int(K),
                                       hexa_int(wt_id), hexa_int(N));
        int64_t csl_id = HX_INT(csl);
        if (csl_id < 0 || csl_id >= _hx_farr_count) { hexa_farr_free(wt_h); return hexa_int(-1); }
        const double* Csrc = _hx_farr_table[csl_id].buf;
        double* C = _hx_farr_table[c_id].buf;
        for (int64_t t = 0; t < M * N; t++) C[t] = Csrc[t];
        hexa_farr_free(wt_h); hexa_farr_free(csl);
    }
    return hexa_int(0);
}
HexaVal forge_dispatch_matmul_bt(HexaVal a_v, HexaVal m_v, HexaVal k_v,
                                 HexaVal b_v, HexaVal n_v, HexaVal c_v) {
    return hexa_forge_dispatch_matmul_bt(a_v, m_v, k_v, b_v, n_v, c_v);
}

HexaVal hexa_forge_dispatch_matmul_atb(HexaVal a_v, HexaVal m_v, HexaVal k_v,
                                       HexaVal b_v, HexaVal n_v, HexaVal c_v) {
    int64_t a_id = hexa_as_num(a_v);
    int64_t M    = hexa_as_num(m_v);
    int64_t K    = hexa_as_num(k_v);
    int64_t b_id = hexa_as_num(b_v);
    int64_t N    = hexa_as_num(n_v);
    int64_t c_id = hexa_as_num(c_v);
    if (M <= 0 || K <= 0 || N <= 0) return hexa_int(-1);
    if (a_id < 0 || a_id >= _hx_farr_count) return hexa_int(-1);
    if (b_id < 0 || b_id >= _hx_farr_count) return hexa_int(-1);
    if (c_id < 0 || c_id >= _hx_farr_count) return hexa_int(-1);
    if (_hx_farr_table[c_id].len < M * N) return hexa_int(-1);
#ifdef HEXA_CUDA
    extern int _hx_cuda_farr_matmul_atb_gpu(int64_t, int64_t, int64_t,
                                            int64_t, int64_t, int64_t);
    int grc = _hx_cuda_farr_matmul_atb_gpu(a_id, M, K, b_id, N, c_id);
    if (grc == 0) return hexa_int(0);
#endif
    /* no-CUDA host fallback — BYTE-EQ contract (max|Δ|=0.0). Reference is
     * host-transpose A[K,M] → At[M,K] THEN hexa_farr_matmul(At,M,K, B,N).
     * DELEGATE through the identical transpose so the ikj accumulation matches
     * bit-for-bit (open-coded ijk dot would drift ~1e-14). Re-fetch buf by id
     * after each alloc (realloc-move safe). */
    {
        HexaVal at_h = hexa_farr_zeros(hexa_int(M * K));
        int64_t at_id = HX_INT(at_h);
        if (at_id < 0 || at_id >= _hx_farr_count) return hexa_int(-1);
        const double* A = _hx_farr_table[a_id].buf;
        double* At = _hx_farr_table[at_id].buf;
        for (int64_t k = 0; k < K; k++)
            for (int64_t i = 0; i < M; i++)
                At[i * K + k] = A[k * M + i];
        HexaVal csl = hexa_farr_matmul(hexa_int(at_id), hexa_int(M), hexa_int(K),
                                       hexa_int(b_id), hexa_int(N));
        int64_t csl_id = HX_INT(csl);
        if (csl_id < 0 || csl_id >= _hx_farr_count) { hexa_farr_free(at_h); return hexa_int(-1); }
        const double* Csrc = _hx_farr_table[csl_id].buf;
        double* C = _hx_farr_table[c_id].buf;
        for (int64_t t = 0; t < M * N; t++) C[t] = Csrc[t];
        hexa_farr_free(at_h); hexa_farr_free(csl);
    }
    return hexa_int(0);
}
HexaVal forge_dispatch_matmul_atb(HexaVal a_v, HexaVal m_v, HexaVal k_v,
                                  HexaVal b_v, HexaVal n_v, HexaVal c_v) {
    return hexa_forge_dispatch_matmul_atb(a_v, m_v, k_v, b_v, n_v, c_v);
}
L2EOF
python3 - <<'PY'
base = "/root/hexa-lang/self/runtime.c"
ip   = "/root/hexa-lang/inbox/patches"
src  = open(base).read().splitlines(keepends=True)
# anchor: the 'BF16 substrate externs' comment line
anchor = None
for i,l in enumerate(src):
    if "BF16 substrate externs" in l:
        anchor = i; break
assert anchor is not None, "BF16 substrate externs anchor not found in base runtime.c"
# splice point: after the comment block that contains the anchor — insert right
# before the anchor's comment line is risky; insert AFTER the line so the block
# lands in the BF16 extern region's lead. We insert right BEFORE the anchor line
# (the fragments are self-contained function defs, valid at file scope).
def rd(p):
    return open(p).read()
blocks = []
blocks.append(rd(ip+"/forge-devfeed-lever-a-runtime-c-fragment.c.txt"))
blocks.append(rd("/root/lever2_unbatched.c.txt"))
blocks.append(rd(ip+"/forge-devfeed-lever3-batched-gemmfeed-runtime-c-fragment.c.txt"))
blocks.append(rd(ip+"/forge-devfeed-lever4-fused-step-driver-runtime-c-fragment.c.txt"))
ins = "\n/* ── FORGE-UTILGREEN lever a+2+3+4 wrappers (spliced) ── */\n" + "\n".join(blocks) + "\n"
new = src[:anchor] + [ins] + src[anchor:]
open(base,"w").write("".join(new))
print("  spliced 4 fragment-blocks before BF16-externs (line", anchor, ")")
PY
echo -n "  runtime.c wrappers present: "
grep -cE "^HexaVal hexa_forge_dispatch_(im2col|col2im|adamw|adamw_group|matmul_bt|matmul_atb|matmul_batched_bt|matmul_batched_atb)\(" "$BASE_RT"
echo "  (expect >= 8: im2col,col2im[,im2col_t],adamw,matmul_bt,matmul_atb,matmul_batched_bt,matmul_batched_atb,adamw_group)"

echo "=== [4] self-host rebuild hexa ==="
export CC=gcc LIBS="-lm -ldl -lpthread -lrt" CFLAGS_COMMON="-O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs" OUT_HEXA="$REPO/build/hexa_fresh"
bash tool/stage_build_hexa > /root/stage4.log 2>&1; echo "STAGE_RC=$?"; tail -4 /root/stage4.log
HEXA_BIN="$REPO/build/hexa_fresh"
if [ ! -x "$HEXA_BIN" ]; then echo "FATAL: self-host build failed"; tail -20 /root/stage4.log; exit 13; fi
mkdir -p /root/.hx/bin; ln -sf "$HEXA_BIN" /root/.hx/bin/hexa; ln -sf "$HEXA_BIN" /usr/local/bin/hexa
echo -n "  CUDA link ENGAGED baked: "; strings "$HEXA_BIN" 2>/dev/null | grep -c "CUDA link ENGAGED"

echo "=== [5] pre-emit runtime_cuda.c ==="
rm -rf "$HOME/.hexa-cache" /root/.hexa-cache 2>/dev/null
HEXA_NO_CUDA=1 HEXA_CUDA_LINK= hexa run self/cuda/runtime_cuda_emit.hexa self/cuda/runtime_cuda.c 2>&1 | tail -1
echo -n "  runtime_cuda.c adamw_group kernel: "; grep -c "_hx_cuda_farr_adamw_group_gpu" self/cuda/runtime_cuda.c
echo -n "  runtime_cuda.c bt/atb/batched kernels: "; grep -cE "_hx_cuda_farr_matmul_(batched_)?(bt|atb)_gpu" self/cuda/runtime_cuda.c

echo "=== [GATE1] BUILD clm_prod HEXA_CUDA_LINK=1 ==="
rm -f "$REPO/clm_prod"
HEXA_CUDA_LINK=1 HEXA_USE_RUNTIME_C=1 "$HEXA_BIN" build stdlib/flame/clm_prod.hexa -o "$REPO/clm_prod" > /root/build_cuda4.log 2>&1
echo "BUILD_RC=$?"
G1=$(grep -c "CUDA link ENGAGED" /root/build_cuda4.log); echo "GATE1_CUDA_LINK_ENGAGED=$G1"
tail -6 /root/build_cuda4.log

echo "=== [GATE2] nvcc -x cu runtime_cuda.c sm_90 ==="
nvcc -x cu -c "$REPO/self/cuda/runtime_cuda.c" -arch=sm_90 -DHEXA_CUDA -I "$REPO/self" -o "$REPO/self/cuda/runtime_cuda.90.o" 2>/tmp/nvcc4.err
echo "GATE2_NVCC_EXIT=$?  obj=$(stat -c%s "$REPO/self/cuda/runtime_cuda.90.o" 2>/dev/null||echo 0)B err=$(grep -c error /tmp/nvcc4.err)"
grep -i error /tmp/nvcc4.err | head -5

echo "=== [relink -lcuda if clm_prod absent] ==="
if [ ! -x "$REPO/clm_prod" ]; then
  UC="$REPO/build/artifacts/clm_prod.c"
  RTCUDA_O=$(ls -t /root/.hexa-cache/runtime.*.cuda.o 2>/dev/null | head -1)
  RTCU_90="$REPO/self/cuda/runtime_cuda.90.o"
  echo "  UC=$UC RTCUDA_O=$RTCUDA_O"
  clang -O2 -DHEXA_CUDA -I ${CUDA_HOME:-/usr/local/cuda}/include -D_GNU_SOURCE -Wno-trigraphs -fbracket-depth=4096 -I "$REPO/self" \
    "$UC" "$RTCUDA_O" "$RTCU_90" -o "$REPO/clm_prod" \
    -lm -lpthread -L${CUDA_HOME:-/usr/local/cuda}/lib64 -L/usr/lib/x86_64-linux-gnu -lcublas -lcudart -lcuda -ldl -lrt -lstdc++ \
    > /root/relink4.log 2>&1
  echo "RELINK_RC=$?"; tail -6 /root/relink4.log
fi

echo "=== [GATE3] clm_prod ldd + symbols ==="
G3=0
if [ -x "$REPO/clm_prod" ]; then
  G3=$(ldd "$REPO/clm_prod" 2>/dev/null | grep -icE "cublas|cudart|libcuda.so|cublasLt")
  echo "GATE3_CUDA_LIBS=$G3"; ldd "$REPO/clm_prod" 2>/dev/null | grep -iE "cublas|cudart|libcuda|cublasLt"
  echo -n "  clm_prod links adamw_group sym: "; strings "$REPO/clm_prod" 2>/dev/null | grep -c "adamw_group"
fi
if [ "$G1" -lt 1 ] || [ ! -x "$REPO/clm_prod" ] || [ "$G3" -lt 3 ]; then
  echo "GATE-FAIL — no fire (G1=$G1 clm_prod=$([ -x $REPO/clm_prod ] && echo Y||echo N) G3=$G3)"; echo "DRIVER-EXIT=5"; exit 5
fi
echo "3-GATE-PASS"

echo "=== [byte-eq] g5 verbatim — STOP on any drift ==="
BYTEEQ_OK=1
for o in clm_gemmfeed_eq clm_batched_gemmfeed_eq clm_conv_devfeed clm_conv_batched clm_fused_step_eq; do
  echo "#### $o (HEXA_NO_CUDA host oracle) ####"
  OUT=$(HEXA_NO_CUDA=1 hexa run stdlib/flame/$o.hexa 2>&1)
  echo "$OUT" | grep -E "F-|max|PASS|FAIL|rc=" | head -12
  echo "$OUT" | grep -q "FAIL" && BYTEEQ_OK=0
done
echo "#### clm_fused_step_eq (ON-DEVICE HEXA_CUDA — real builtin) ####"
OUTD=$(HEXA_CUDA_LINK=1 hexa run stdlib/flame/clm_fused_step_eq.hexa 2>&1)
echo "$OUTD" | grep -E "F-|max|PASS|FAIL|rc=" | head -12
echo "$OUTD" | grep -q "FAIL" && BYTEEQ_OK=0
echo "BYTEEQ_OK=$BYTEEQ_OK"
if [ "$BYTEEQ_OK" -ne 1 ]; then echo "BYTEEQ-DRIFT — STOP, NO FIRE (revert)"; echo "DRIVER-EXIT=6"; exit 6; fi
echo "BYTEEQ-PASS"

echo "=== [FIRE] util fire — fused driver d~1536/T~512 ==="
cp /root/clm_mid_5lang_c4.txt "$REPO/stdlib/flame/testdata/clm_mid_5lang_c4.txt" 2>/dev/null || true
CORPUS="$REPO/stdlib/flame/testdata/clm_mid_5lang_c4.txt"
[ -f "$CORPUS" ] || CORPUS="$REPO/stdlib/flame/testdata/clm_semantic_parallel.txt"
pkill -f clm_prod 2>/dev/null; pkill -f "nvidia-smi --query-gpu=utilization" 2>/dev/null; sleep 1
SAMP=/root/util_samples_lever4.csv; rm -f "$SAMP"
OUT_CLM="$REPO/exports/clm_lever4_d1536_t512.clm"; mkdir -p "$REPO/exports"
nohup bash -c 'while true; do nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -i 0 2>/dev/null; sleep 0.1; done' > "$SAMP" 2>/dev/null &
echo $! > /root/sampler4.pid
env CLM_PROD_D=1536 CLM_PROD_T=512 CLM_PROD_E=2 CLM_PROD_NSAMP=32 CLM_PROD_EPOCHS=3 \
  CLM_PROD_CORPUS="$CORPUS" CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1 CLM_PROD_OUT="$OUT_CLM" \
  HEXA_CUDA_LINK=1 "$REPO/clm_prod" > /root/train_lever4.log 2>&1
FIRE_RC=$?
kill $(cat /root/sampler4.pid) 2>/dev/null
echo "FIRE_RC=$FIRE_RC"
echo "=== util stats ==="
python3 - <<'PY'
vals=[]
for l in open("/root/util_samples_lever4.csv"):
    l=l.strip()
    if l.isdigit(): vals.append(int(l))
if vals:
    n=len(vals); peak=max(vals); mean=sum(vals)/n; ge20=sum(1 for v in vals if v>=20)
    print(f"UTIL n={n} PEAK={peak}% MEAN={mean:.4f}% busy_ge20={ge20} pct_ge20={100*ge20/n:.2f}%")
else:
    print("UTIL n=0 (no samples)")
PY
echo "=== train tail (descent) ==="
grep -E "epoch|CE|F-CLM-PROD-DESCENT|PASS|FAIL" /root/train_lever4.log | tail -12
echo "=== clm artifact ==="
ls -la "$OUT_CLM" 2>&1 | tail -1; sha256sum "$OUT_CLM" 2>/dev/null
echo "=== DRIVER-DONE $(date -u +%FT%TZ) ==="
