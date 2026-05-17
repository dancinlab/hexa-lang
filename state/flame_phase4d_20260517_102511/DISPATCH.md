# Phase 4-D-4 GPU Dispatch — runpod A100 SXM 80GB

**Date**: 2026-05-17
**Branch**: rfc043-hexa-torch
**Pod ID**: uwnkt6g0605hon
**Cost**: $1.39/hr (community cloud)
**SSH**: root@216.249.100.66 -p 20162

## Hardware
- GPU: NVIDIA A100-SXM4-80GB
- CPU: 32 vCPU (256 cores on host)
- RAM: 251 GiB (2TB host)
- OS: Ubuntu 24.04 LTS
- Compiler: clang 18.1.3

## Source
- Config: stdlib/flame/flame_d768_12L_corpus_test.hexa (commit 84f514f3)
- Build: tool/flame_phase4b3_a2_build.sh stdlib/flame/flame_d768_12L_corpus_test.hexa
- C output: build/artifacts/flame_d768_12L_corpus_test_a2.c (163KB)
- Remote build cmd: clang -O2 -D_GNU_SOURCE -D_XOPEN_SOURCE=600 -I self -lm -lpthread

## Falsifier Gate
- F-RFC046-EAGER-PYTORCH-MATCH: wall ≤ 437.9s (1.3× of 336.85s eager-PyTorch baseline)

## Config Detail
- T=1024, d=768, nh=12, nkv=4, h=3072, V=256, n_layer=12
- nsamp=4, stride=4096, n_steps=20
- lr=0.03, b1=0.9, b2=0.999, eps=1e-8, wd=0.01, seed=42
- model: 104,024,832 doubles (832 MB)
- cache: 346,842,881 doubles (2.78 GB)

## Dispatch Path
1. Local M-Mac build → produces .c artifacts (~6 min)
2. SCP runtime.c + native/*.c + flame .c + corpus → pod
3. Remote clang -O2 build → 493KB ELF x86_64 binary
4. Single-threaded CPU run on A100 box (no CUDA in this binary)

