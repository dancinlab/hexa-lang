#!/bin/bash
set +e
cd /tmp

echo "=== Round 8b — correct bf16 WMMA fragment count + TMA syntax ==="
echo ""

# bf16 m16n16k16: A/B fragments are 4 × .b32 (each .b32 holds 2 bf16)
# C/D fragments are 8 × .f32
cat > /tmp/wmma_bf16_f32b.ptx <<'EOF'
.version 7.4
.target sm_80
.address_size 64
.visible .entry wmma_bf16f32(.param .u64 a, .param .u64 b, .param .u64 c)
{
    .reg .b64 %rda, %rdb, %rdc;
    .reg .b32 %ra0, %ra1, %ra2, %ra3;
    .reg .b32 %rb0, %rb1, %rb2, %rb3;
    .reg .f32 %rc0, %rc1, %rc2, %rc3, %rc4, %rc5, %rc6, %rc7;
    ld.param.u64 %rda, [a];
    ld.param.u64 %rdb, [b];
    ld.param.u64 %rdc, [c];
    wmma.load.a.sync.aligned.row.m16n16k16.global.bf16 {%ra0, %ra1, %ra2, %ra3}, [%rda], 16;
    wmma.load.b.sync.aligned.col.m16n16k16.global.bf16 {%rb0, %rb1, %rb2, %rb3}, [%rdb], 16;
    wmma.mma.sync.aligned.row.col.m16n16k16.f32.bf16.bf16.f32 {%rc0, %rc1, %rc2, %rc3, %rc4, %rc5, %rc6, %rc7}, {%ra0, %ra1, %ra2, %ra3}, {%rb0, %rb1, %rb2, %rb3}, {%rc0, %rc1, %rc2, %rc3, %rc4, %rc5, %rc6, %rc7};
    wmma.store.d.sync.aligned.row.m16n16k16.global.f32 [%rdc], {%rc0, %rc1, %rc2, %rc3, %rc4, %rc5, %rc6, %rc7}, 16;
    ret;
}
EOF
echo "=== §3b bf16×bf16→f32 WMMA (4-frag A/B, 8-frag C) ==="
ptxas -arch=sm_80 -o /tmp/wmma_bf16f32b.cubin /tmp/wmma_bf16_f32b.ptx 2>&1
rc=$?
echo "ptxas_rc=$rc"
echo ""

# TMA syntax: cp.async.bulk.tensor needs different state-space encoding
# Simpler form without TMA descriptor — just verify cp.async.bulk basic form
cat > /tmp/tma_basic.ptx <<'EOF'
.version 8.0
.target sm_90
.address_size 64
.shared .align 16 .b8 dst[256];
.visible .entry tma_basic(.param .u64 src)
{
    .reg .b64 %rd1, %rd2, %rd3;
    .reg .b32 %r0;
    ld.param.u64 %rd1, [src];
    mov.b64 %rd2, dst;
    cvta.shared.u64 %rd3, %rd2;
    cvta.to.shared.u64 %rd3, %rd3;
    mov.u32 %r0, 256;
    cp.async.bulk.shared::cta.global [%rd3], [%rd1], %r0;
    ret;
}
EOF
echo "=== §3c TMA cp.async.bulk (basic form, sm_90) ==="
ptxas -arch=sm_90 -o /tmp/tma_basic.cubin /tmp/tma_basic.ptx 2>&1
rc=$?
echo "ptxas_rc=$rc"
echo ""

# Re-verify f16f16f16 + ldmatrix + mbarrier with explicit RC capture
echo "=== Round 8 re-verify ptxas_rc explicit ==="
for f in wmma_f16_f16_f16.ptx ldmatrix_smoke.ptx mbarrier_smoke.ptx coop_grid.ptx gpu_print.ptx gpu_assert.ptx atom_shared.ptx; do
  case $f in
    mbarrier_smoke.ptx) arch=sm_90 ;;
    *) arch=sm_80 ;;
  esac
  ptxas -arch=$arch -o /tmp/${f%.ptx}_v.cubin /tmp/$f >/dev/null 2>&1
  echo "$f arch=$arch ptxas_rc=$?"
done
