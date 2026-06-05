#!/usr/bin/env python3
# hexa-cuda dojo kata — ctypes CONTRAST driver (NOT the production path)
# slug: vec-add  ·  kata: vec-add
#
# Shows the classic CUDA-from-Python flow: nvcc the .cu to a shared
# object, ctypes-load it, marshal host buffers. The hexa path
# (kernel.hexa + gpu_launch) needs NONE of this glue — it is the
# contrast that motivates the kata. Edit the spec, re-emit.
import ctypes, subprocess, sys

SM = "sm_90"
N = 1024

def build():
    # nvcc -shared -Xcompiler -fPIC -arch=SM kernel.cu -o kernel.so
    subprocess.run([
        "nvcc", "-shared", "-Xcompiler", "-fPIC",
        "-arch=" + SM, "kernel.cu", "-o", "kernel.so",
    ], check=True)

def main():
    build()
    lib = ctypes.CDLL("./kernel.so")
    # NOTE: a real launch needs a host wrapper that cudaMalloc/Memcpy
    # and cudaLaunchKernel — the .cu above is device-only. This
    # contrast stops at the build to keep the kata self-contained;
    # the hexa path replaces ALL of this with one gpu_launch line.
    print(f"hexa-cuda contrast: built kernel.so (arch={SM}, N={N})")
    print("see kernel.hexa for the production hexa-native path")

if __name__ == "__main__":
    main()
