# `self/native/*.c` 레이어 분류 감사 (RUNTIME.flip B9.native-c-files-port)

> **상태**: audit 단계 (READ-ONLY 분석). 본 문서는 `.c`-zero north-star 캠페인이
> 어떤 파일을 hexa-native 로 포팅 가능한지(layer ①) vs 어떤 파일이 정직한 floor
> 로 C 에 남아야 하는지(layer ③/②) 를 판별한다. **어떤 `.c` 도 수정/삭제하지 않음.**

## 배경 — 레이어 정의

RUNTIME.md north-star("`.hexa`-ONLY · zero `.c`") 와 step3/step4 메모리
("irreducible-core FLOOR" terminal) 기준:

| 레이어 | 정의 | 정책 |
| --- | --- | --- |
| **① reimplementable** | 외부 의존 없는 순수 로직 (math/parser/codec/tensor kernel). HexaVal-wrap 비용만 감수하면 hexa-native 포팅 가능 | zero-C north-star 적용 → **포팅 대상** |
| **② bootstrap / floor** | 컴파일러 self-host bootstrap 산출물, 또는 제거 불가한 런타임 floor (제어레지스터 등) | 포팅 부적격 — bootstrap/floor 로 정당 |
| **③ vendor FFI / OS ABI** | 벤더 라이브러리 ABI (CUDA/NCCL/OpenBLAS/OpenSSL/libsodium) 또는 커널 syscall 래퍼. 순수 로직이 없어 hexa 로 재작성할 대상 자체가 없음 | FFI 경계로 정당 — **C 에 유지** |

> **note**: 본 batch 의 spec(RUNTIME.flip.md L230)은 "38 파일"이라 적었으나
> origin/main 현시점 `self/native/*.c` 실측은 **32 파일**이다. 본 감사는 실측
> 32 파일 전수를 분류한다. (`.h`/`.cu`/`.hexanoport` 마커 파일은 `.c` 가 아니므로 제외.)

## 분류 테이블 (32 파일 전수)

| file | layer | rationale | port-target |
| --- | --- | --- | --- |
| `crypto_blowfish.c` | ① | Blowfish 키스케줄 + bcrypt_pbkdf — π-seeded 순수 C 레퍼런스 알고리즘. (`#ifdef HEXA_HAS_LIBSODIUM` 가드 하의 SHA-512 sub-step 만 sodium 사용; cipher core 는 순수) | `stdlib/crypto/blowfish.hexa` (chacha20 선례 — 순수-algo crypto 는 이미 hexa-native) |
| `crypto_openssl.c` | ③ | OpenSSL EVP `EVP_aes_256_ctr` 바인딩. `-lcrypto` 벤더 ABI | 유지 (thin FFI 래퍼) |
| `crypto_sodium.c` | ③ | libsodium ed25519/x25519/sha512/chacha20-poly1305 바인딩. `-lsodium` 벤더 ABI | 유지 (FFI floor) |
| `exec_argv_sha256.c` | ① | FIPS 180-4 SHA-256 순수 레퍼런스 + `fork/execvp` argv 직접 exec. SHA-256 부분은 순수 libc, 외부 의존 0 | `stdlib/crypto/sha256.hexa` (SHA-256 순수 로직); exec 부분은 ③ syscall (분리 필요) |
| `exec_pipe.c` | ③ | `fork`+`exec` + stdout/stderr 분리 pipe. 커널 process/pipe syscall 래퍼 | 유지 (OS ABI floor) |
| `fp_init.c` | ② | MXCSR(x86_64)/FPCR(aarch64) 스레드별 FP 제어레지스터 정규화. IEEE strict 모드 floor — 제어레지스터는 hexa 로 표현 불가 | 유지 (irreducible floor) |
| `gpu_codegen_stub.c` | ① | rt#45 GPU 백엔드 스캐폴드 — 실제 emission 없음, 전부 placeholder. 외부 의존 0, standalone 컴파일 | `compiler/codegen/gpu_*.hexa` (구현 시 hexa codegen 레이어로 흡수 — 단 현재는 빈 contract) |
| `hexa_cc.c` | ② | `hexa cc --regen` 으로 생성된 self-hosted 컴파일러 산출물. bootstrap 산출물 (소스는 `.hexa`) | 유지 (bootstrap; 소스는 이미 hexa) |
| `hxblas_linux.c` | ③ | OpenBLAS `cblas_sgemm` FFI shim (`<cblas.h>`, `-lopenblas`). 벤더 BLAS ABI | 유지 (벤더 BLAS FFI) |
| `hxccl_linux.c` | ③ | NCCL collective (`ncclAllReduce`/`ncclBroadcast`/`ncclAllGather`) FFI shim. 벤더 GPU 통신 ABI (Day-1 stub→NCCL) | 유지 (벤더 NCCL FFI) |
| `hxffi_slot.c` | ③ | out-pointer slot 할당기 — FFI 경계 그 자체 (DuckDB/SQLite/curl out-param 패턴). C heap slot 필수 | 유지 (FFI 인프라 floor) |
| `hxflash_linux.c` | ① **LIVE** | Flash-Attention forward — online-softmax. **B9.6f 재검증: DEAD 아님** — `self/ml/hxflash.hexa` 가 `extern fn hxflash_attn_fwd_packed` + 실제 호출(L133), `gpu_train.hexa`/`train_7b_integrated.hexa`/test 가 consumer · `tool/build_hxflash_linux.hexa` dedicated build | `self/ai_native/flash_attention.hexa` (port = multi-session rewire, NOT clean delete) |
| `hxlayer_linux.c` | ① **LIVE** | fused rmsnorm+silu. **B9.6f 재검증: DEAD 아님** — `self/ml/hxlayer.hexa`(`extern fn hxlayer_rmsnorm_silu` + 호출 L78) + `bench_hxlayer*.hexa`/`test_hxlayer.hexa` consumer · `tool/build_hxlayer_linux.hexa` dedicated build | `stdlib/flame/` fused kernel (port = multi-session rewire, NOT clean delete) |
| `hxlmhead_linux.c` | ③ | fused LM-head fwd/bwd — 모든 matmul 이 `cblas_sgemm`(OpenBLAS/Accelerate) 라우팅. H100 측정 scalar 165× 느림 → BLAS 의존 본질적 | 유지 (벤더 BLAS FFI; scalar 포팅은 perf-부적격) |
| `hxqwen14b.c` | ③ | Qwen2.5-14B LoRA 학습 shim — `#include <cuda_runtime.h>`/`<cublas_v2.h>`/`<cuda_bf16.h>`. 벤더 CUDA/cuBLAS ABI (CPU AdamW 레퍼런스 일부만 순수) | 유지 (벤더 CUDA FFI) |
| `hxqwen32b.c` | ③ | Qwen2.5-32B 변종 (14b 와 동일 ABI, n_layer/ffn_dim 만 차이). 동일 CUDA/cuBLAS 벤더 ABI | 유지 (벤더 CUDA FFI) |
| ~~`hxtok.c`~~ | ① | **DELETED (B9.6e)** — Qwen2.5 BPE C 구현. 빌드/링크/FFI 호출 0건 (standalone shim) · 순수-hexa 등가 `self/ml/qwen_bpe.hexa`·`tokenizer_bpe.hexa` 가 모든 consumer 서빙. dead-file git-rm (v565 패턴) | `self/ml/qwen_bpe.hexa`·`tokenizer_bpe.hexa` (이미 존재 — consumer 전수 사용 중) |
| `hxvdsp_linux.c` | ① **LIVE** | Apple vDSP(RMSNorm/SoftMax/SwiGLU) Linux scalar+libm 대체. **B9.6f 재검증: DEAD 아님** — `bench/hxblas_linux.hexa` 가 `@link("hxvdsp")` + `extern fn hxvdsp_version`/`hxvdsp_rmsnorm_fwd` + 실제 호출(L116/L174) · `tool/build_hxblas_linux.hexa` build · `.hexanoport` 마커 | `stdlib/flame/` eltwise (port = multi-session rewire, NOT clean delete) |
| ~~`hxvocoder.c`~~ | ① **DELETED B9.6f** | 정밀 재검증 결과 0-caller DEAD — 8 export 심볼(`hxvocoder_decode_nv`/`_decode_wave`/`_linear_proj`/`_synth_additive`/`_tanh_vec`/`_vec_zeros`/`_version`/`_write_wav`) 전부 코드 참조 0건. 유일 빌드 참조 = `build_native.hexa` `file_exists` 가드(삭제 시 auto-skip; 그 dead 블록도 제거). `.h`/`.so`/`.o` 0건. (audit 가 "neural_vocoder.hexa 레퍼런스" 라 적었으나 그 파일은 tree 에 부재; 1,922× 보코더는 순수-hexa Griffin-Lim `speech_audio.hexa` 경로) | ~~포팅~~ → git rm (hxtok 패턴 dead-file) |
| `lora_cuda_host.c` | ① | LoRA fwd/bwd **CPU 레퍼런스** — CUDA 커널의 exact-arithmetic 등가 순수 C. CUDA launch 는 weak stub(없으면 CPU 라우팅) | CPU 레퍼런스는 `stdlib/flame/` hexa-native 포팅 적격 (CUDA dispatch 부분만 ③) |
| `mount.c` | ③ | Linux `mount(2)`/`umount(2)` syscall 래퍼 (`<sys/mount.h>`). 커널 ABI | 유지 (커널 syscall floor) |
| `namespace.c` | ③ | Linux `unshare(2)`/`setns(2)`/`pivot_root(2)` + CLONE_NEW* 상수 (`<sched.h>`). 커널 ABI | 유지 (커널 syscall floor) |
| `net.c` | ③ | POSIX TCP 소켓 6 primitive (`socket`/`listen`/`accept`/`connect`/`read`/`write`). 커널 socket ABI | 유지 (OS socket floor; `http_*` 는 이미 `.hexa` 합성) |
| `persistent_pipe.c` | ③ | handle 기반 bidirectional child-process pipe (`fork`+`dup2`+pipe). 커널 process/pipe syscall | 유지 (OS ABI floor) |
| `proc_fork.c` | ③ | `fork()`/`setsid()`/SIGCHLD reap 래퍼. 커널 process syscall | 유지 (OS ABI floor) |
| `pty.c` | ③ | POSIX 의사터미널 + termios (`forkpty`/`tcgetattr`/ioctl `TIOCGWINSZ`). 커널 tty ABI | 유지 (OS tty floor) |
| `signal_flock.c` | ③ | 시그널 트램폴린(self-pipe) + `flock(2)`. async-signal-safe 커널 ABI (`sigprocmask`/`flock`) | 유지 (OS signal floor) |
| `tensor_kernels.c` | ①\* | f32/f64/i32 포인터 read/write + tensor alloc/reshape — 외부 의존 0 순수 C. **단 `@hot_kernel — DO NOT MIGRATE` 명시**: 원소당 HexaVal-wrap = 10-100× 슬로다운 → perf-floor | **포팅 보류** (로직상 ① 이나 정책상 hot-path whitelist 로 C 유지 — perf 정직-floor) |
| `term_ffi.c` | ③ | TUI L1 — termios `cfmakeraw`/`tcsetattr` + ioctl `TIOCGWINSZ` + SIGWINCH/SIGINT. 커널 tty/signal ABI | 유지 (OS tty floor) |
| `thread.c` | ③ | POSIX `pthread` + channel primitive (`pthread_create`/mutex/cond). 커널 스레드 ABI | 유지 (OS thread floor) |
| `v565_grad_analysis.c` | ①\* | gradient SINGULARITY 분석 하니스 — CSV 덤프 분석 도구. 순수 로직이나 `dlopen` 으로 hxqwen14b `.so` 심볼 로드 (도구성, 런타임 floor 아님) | 분석 도구 — 포팅 우선순위 낮음 (런타임 경로 아님) |
| `wait.c` | ③ | `waitpid(2)` 래퍼 (exit/signal status 디코드). 커널 process syscall | 유지 (OS ABI floor) |

\* `tensor_kernels.c` 는 의존성 기준 layer ① 이나 **perf-floor 정책**(`@hot_kernel`
whitelist)으로 C 유지. `v565_grad_analysis.c` 는 분석 도구로 런타임 경로 밖.

## 요약 카운트

| 레이어 | 파일 수 | 비율 |
| --- | --- | --- |
| **① reimplementable (포팅 적격)** | **11** | 34% |
| **② bootstrap / floor** | **2** | 6% |
| **③ vendor FFI / OS ABI floor** | **19** | 59% |
| 합계 | 32 | 100% |

- **layer ① (portable) = 11** (`hxtok` DELETED B9.6e · `hxvocoder` DELETED B9.6f — 둘 다 0-caller dead standalone; 잔존 list 는 historical) : `crypto_blowfish` · `exec_argv_sha256` · `gpu_codegen_stub`(LIVE: nvptx_target 참조) · `hxflash_linux`(LIVE) · `hxlayer_linux`(LIVE) · ~~`hxtok`~~ · `hxvdsp_linux`(LIVE) · ~~`hxvocoder`~~ · `lora_cuda_host`(LIVE: CUDA build) · `tensor_kernels`(\*perf-floor 보류) · `v565_grad_analysis`(\*도구) — **B9.6f 재검증: hxvocoder 외 layer① 잔존 전부 실제 caller/build-ref 보유 LIVE (clean-delete 불가, port 만 가능)**
- **layer ② (bootstrap/floor) = 2** : `hexa_cc`(self-host 산출물) · `fp_init`(FP 제어레지스터 floor)
- **layer ③ (FFI/OS-ABI floor) = 19** : `crypto_openssl` · `crypto_sodium` · `hxblas_linux` · `hxccl_linux` · `hxffi_slot` · `hxlmhead_linux` · `hxqwen14b` · `hxqwen32b` · `mount` · `namespace` · `net` · `persistent_pipe` · `proc_fork` · `pty` · `signal_flock` · `term_ffi` · `thread` · `wait` · `exec_pipe`

## Portable subset — `.c`-zero 캠페인이 실제 포팅 가능한 파일

zero-C north-star 가 **실측 진행 가능한** 우선순위 (perf-floor/도구 제외한 순수 후보):

1. ~~**`hxtok.c`**~~ → **DELETED (B9.6e)**. 정밀 audit 결과 standalone dead shim — 빌드 스크립트·링크·FFI 호출 0건이고 순수-hexa 등가(`self/ml/qwen_bpe.hexa`·`tokenizer_bpe.hexa`)가 이미 8개 consumer 전수 서빙. "포팅" 아니라 dead-file git-rm (v565 패턴). `.c` 228→227.
2. **`exec_argv_sha256.c`** (SHA-256 부분) → FIPS 180-4 순수 해시. crypto stdlib 의 자연스러운 hexa-native 흡수 대상. (exec 부분은 ③ 으로 분리.)
3. **`crypto_blowfish.c`** (Blowfish/bcrypt core) → π-seeded 순수 알고리즘. chacha20 hexa-native 선례 그대로. (SHA-512 sub-step 만 ③ sodium 위임.)
4. **`hxvocoder.c`** → 이미 `neural_vocoder.hexa` 레퍼런스 존재. C 는 libm 가속본 — hexa 재흡수 가능 (perf 는 native codegen libm 호출로 회수).
5. **`hxflash_linux.c`** → 이미 `flash_attention.hexa` 레퍼런스 존재. C 는 transliteration — hexa 가 SSOT.
6. **`hxvdsp_linux.c`** / **`hxlayer_linux.c`** → scalar+libm eltwise. native codegen 의 auto-vec 으로 perf 회수 가능 시 포팅.
7. **`lora_cuda_host.c`** (CPU 레퍼런스 부분) → exact-arithmetic 순수 C. CUDA dispatch 만 ③ 분리.

**보류/주의:**
- `tensor_kernels.c` : 로직상 ① 이나 `@hot_kernel — DO NOT MIGRATE` whitelist. 원소당 HexaVal-wrap 비용으로 10-100× 슬로다운 → **정직한 perf-floor**. native codegen 이 HexaVal-free f32 경로를 emit 하기 전까지 포팅 부적격.
- `gpu_codegen_stub.c` : 현재 빈 contract. 실제 GPU codegen 구현 시 `compiler/codegen/` 의 hexa 레이어로 흡수되는 게 맞으나, 지금은 포팅할 로직이 없음.
- `v565_grad_analysis.c` : 분석 도구(`dlopen` 으로 학습 `.so` 로드). 런타임 경로가 아니므로 우선순위 낮음.

## 정직한-floor (③) 결론

19 개 layer ③ 파일은 **모두 정당한 C floor**:
- **벤더 GPU/ML ABI** (6): `hxqwen14b`/`hxqwen32b`(CUDA/cuBLAS) · `hxccl_linux`(NCCL) · `hxblas_linux`/`hxlmhead_linux`(OpenBLAS) · `hxffi_slot`(FFI 경계 인프라)
- **벤더 crypto ABI** (2): `crypto_openssl`(EVP) · `crypto_sodium`(ed25519/x25519/chacha20)
- **커널 syscall floor** (11): `mount`/`namespace`(컨테이너) · `net`(socket) · `pty`/`term_ffi`(tty) · `thread`(pthread) · `signal_flock`(시그널) · `proc_fork`/`wait`/`exec_pipe`/`persistent_pipe`(process)

이들은 LATTICE_POLICY 의 FFI-정당 기준을 만족한다 — 재작성할 순수 로직이
존재하지 않고, 커널/벤더 ABI 가 본질적 경계다. zero-C 캠페인은 이 19 파일을
**floor 로 인정**하고 layer ① 11 파일(실효 7 후보)에 집중해야 한다.
