#!/usr/bin/env bash
# build_decode_mega.sh — build + run the decode-megakernel chain benchmark on aiden.
# (fleet lane "decode-megakernel GPU" r1; RTX 5070 sm_120). byteeq-NEUTRAL.
set -eu
export PATH=/usr/local/cuda/bin:/usr/local/cuda/nvvm/bin:$PATH
INC=-I/usr/local/cuda/targets/x86_64-linux/include
D="$(dirname "$0")"
nvcc -arch=sm_120 $INC -O3 -std=c++17 "$D/decode_mega_chain.cu" \
     -lcublas -lcudart -lm -o /tmp/decode_mega_chain
/tmp/decode_mega_chain        # all shapes (D in {2048,4096})
