# -cuda release "runtime_cuda.c not emitted" 근본 = gen3 self-host obj-emit segfault (mac 격리 재현)

**증상**: release `-cuda` job 의 stage_resolve_runtime_a 가 `CUDA-R1: WARN runtime_cuda.c not
emitted (runner failed?) — unsetting HEXA_CUDA, CPU runtime.a` → `✗ runtime.a is missing the
CUDA objects` (exit 1). #3694/#3696/#3699 후에도 재현. → x86_64-cuda asset 영구 미출하.

**mac 직접 진단 (격리 재현)**:
- `hexa run self/cuda/runtime_cuda_emit.hexa /tmp/rtcuda.c` → **emit 텍스트는 성공** (333KB,
  정상 `runtime_cuda.c` 생성, RC=0). 즉 emitter(`emit_runtime_cuda_c`) 로직 자체는 정상.
- 그러나 실행 중 `hexa.real` native-run fast-path(line 103)가:
  ```
  Segmentation fault: 11  "$GEN3" _drv.hexa "$src" --emit=obj -o "$_nr_o" >/dev/null 2>&1
  ```
  = **gen3 self-host 바이너리(`$SLOT/gen3`, ~2MB)가 `_drv.hexa --emit=obj` 컴파일 시 segfault**.
  mac 에선 `>/dev/null 2>&1` + `&&` 체인이라 fast-path 실패→delegate(인터프리트 fallback)로 emit
  은 성공. **CI self-host 환경에선 이 gen3 obj-emit 경로가 치명적 → runtime_cuda.c 미생성으로 이어짐**(추정).

**근본 후보**: gen3(self-host 컴파일러)의 `--emit=obj` 가 `runtime_cuda_emit.hexa`-derived
`_drv.hexa`(대형, 7041줄 emitter) 컴파일 시 segfault. emitter `.hexa` 자체가 아니라 **gen3
코드젠 버그**. #3699(RT-NATIVE CORES staleness / fs_core_native.o)가 같은 영역이나 미해결.

**재현**:
```
hexa run self/cuda/runtime_cuda_emit.hexa /tmp/rtcuda.c
# stderr: Segmentation fault: 11 "$GEN3" _drv.hexa "$src" --emit=obj ...
# stdout: [runtime_cuda_emit] wrote /tmp/rtcuda.c   (fallback 으로 성공, 333KB)
```

**요청**: gen3 self-host 의 `--emit=obj` segfault(대형 emitter-derived `_drv.hexa`)를 격리·수정.
이게 풀리면 -cuda Package step 의 runtime_cuda.c emit 이 fast-path 에서도 성공 → CUDA objects 가
runtime.a 에 fold → x86_64-cuda asset 출하. anima GPU decode 가속 실측(#2386, cuBLAS Dgemm =
core/DECODER/flame_mm.hexa::mm farr_matmul_gpu)이 이 asset 부재로 막혀 있음.

**참고**: cuda 빌드 링크의 별개 결함(`-lcuda` stubs 누락)은 #3707(fix(cuda) self-compile
-L<lib>/stubs)로 이미 해결 — 이 emit-segfault 는 그 다음 단계의 잔여 결함.
