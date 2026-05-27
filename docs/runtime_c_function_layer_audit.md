<!-- @created: 2026-05-28 -->
<!-- @scope: self/runtime.c + self/runtime_core.c 함수 단위 layer ①/②/③ 분류 -->
<!-- @authority: RUNTIME.flip.md B9 (runtime-c-fns-hexa-port + runtime-core-c-fns-hexa-port) 스코핑 -->
<!-- @principle: READ-ONLY 분석. .c 편집/삭제/빌드 없음. north-star = .c/.o/.s ZERO -->

# self/runtime{,_core}.c 함수 단위 layer ①/②/③ 감사 — RUNTIME.flip B9 포팅 스코핑

> **한 문장**: `.c`-zero 캠페인의 가장 큰 잔여 블로커는 runtime 두 파일(~640 fn)이다.
> 그중 **순수 로직(layer ① now-portable)은 절반이 안 되며**, 진짜 벽은 약 **240 fn 규모의
> GC/arena/value-repr FLOOR** — hexa-native 런타임 바닥(self-hosted FLOOR)이 먼저 서기 전까지
> 포팅 불가능한 부분이다.

---

## §0 측정 메타 (2026-05-28)

| 항목 | 값 |
|------|-----|
| `self/runtime.c` 라인 수 | 13,504 |
| `self/runtime_core.c` 라인 수 | 8,025 |
| `runtime.c` 함수 정의 수 | ~437 (단일-라인 sig 403 + 멀티-라인 CUDA sig ~34) |
| `runtime_core.c` 함수 정의 수 | ~237 |
| **합집합 고유 함수** | **~640** |
| 측정 방법 | `grep -oE '^…\(…\)\{$'` 정의-라인 추출 + 접두사 히스토그램 + 대표 본문 ~20개 샘플링 |

> **구조 핵심**: `runtime.c`는 `runtime_core.c`를 별도 컴파일하지 않고 **`#include`로 텍스트 병합**한다
> (RFC 061 Phase P1 2-layer split). 따라서 두 파일은 단일 translation unit이며, 본 감사는 그 union을 다룬다.
> `runtime_core.c` = "irreducible C core"(HexaVal repr · arena · codegen primitives), `runtime.c` HI tier =
> P2/P3 마이그레이션 후보(FFI · term · exec · json · regex · farr · safetensors · tensor · autograd).
> 이 분류는 RFC 061 §4.1 경계 기준과 일치한다.

---

## §1 layer 모델 (LATTICE_POLICY 정신 + RFC 061 §4.1 경계)

| layer | 정의 | 포팅 가능 시점 |
|-------|------|----------------|
| **①** | hexa-native 재구현 가능 — 순수 로직 (string ops · int math · value-repr helper · parser · hasher · comparator) | **지금 가능** (단, value-repr 접근은 hexa codegen이 동일 ABI를 emit해야 함) |
| **②** | kernel ABI / inline svc — raw syscall 또는 libc 필요 (malloc/mmap/file IO/process/thread/termios) | hexa-native syscall surface 일부 완비 후 (codegen-s-self-emit B9 진행 중) |
| **③** | vendor ABI / FFI — irreducible (CUDA driver · dlopen/dlsym · POSIX regex) | 외부 ABI라 영구적으로 thin C shim 잔존 가능 (포팅 ≠ 제거) |
| **FLOOR** | GC/arena/value-repr — raw C 포인터 산술 · NaN-box tag · bump allocator | **hexa self-hosted 런타임 FLOOR 완성 전까지 불가** (진짜 hard subset) |

---

## §2 버킷 표 (함수 정의 수 기준)

### §2.1 `self/runtime_core.c` — CORE tier (~237 fn)

| 버킷 | layer | 대략 수 | 예시 | 포팅 가능성 |
|------|-------|---------|------|-------------|
| HexaVal 생성자 / value-repr | **FLOOR** | ~13 | `hexa_int` `hexa_float` `hexa_str` `hexa_bool` `hexa_void` `hexa_val_snapshot_array` | ❌ codegen이 emit하는 tagged-union ABI 그 자체. hexa FLOOR 선행 필수 |
| array 원시 (메모리 op) | **FLOOR** | ~22 | `hexa_array_new` `hexa_array_push` `hexa_array_get/set` `hexa_array_slice_fast` `hexa_array_shallow_clone` | ❌ malloc + raw 포인터 + arena 토글(`HEXA_ARRAY_ARENA`) |
| map / hmap 원시 | **FLOOR** | ~25 | `hexa_map_new` `hmap_alloc` `hmap_grow` `hmap_heapify` `hmap_find` `__map_get_cstr_v` | ❌ 직접 bucket 배열 + 해시 재배치 + 포인터 등치 |
| string repr op | **① / FLOOR 혼합** | ~28 | `hexa_str_contains` `hexa_str_concat` `hexa_substr` `hexa_strlen` `hexa_pad*` `hexa_strbuf*` | ⚠ 로직은 ①이나 `HX_STR(v)`로 raw `char*` 추출 → repr 의존. ABI 정착 후 ① |
| arena / GC 바닥 | **FLOOR** | ~7 | `hexa_arena_alloc` `hexa_arena_mark` `hexa_arena_rewind` `hexa_arena_reset` `hexa_arena_new_block` `hexa_arena_frame_clean` | ❌❌ **가장 hard** — bump allocator + 블록 체인 + 프레임 mark/rewind. self-host 런타임 FLOOR의 정의 그 자체 |
| 비교 / 산술 디스패치 | **FLOOR** | ~6 | `hexa_cmp` `__raw_cmp3` `__raw_add_f` `__vs_ptr_eq` | ❌ tag-기반 디스패치 = repr 의존 |
| to_string / format / print | **② 의존** | ~14 | `hexa_to_string` `__hexa_format_float_for_print` `hexa_print` `hexa_eprint` | ⚠ 포맷 로직은 ①, 출력은 `hxlcl_write`(②). repr 순회도 의존 |
| string intern | **FLOOR-adjacent** | ~3 | `hexa_intern` (`fnv1a` 사용) | ⚠ 해시는 순수 ①, 테이블은 전역 raw 포인터 |
| exec / spawn / pipe | **②** | ~11 | `hexa_exec` `hexa_spawn*` `hexa_pipe*` `__hexa_exec_stream_wrap_*` | ❌ posix_spawn / fork / pipe syscall |
| bootstrap init (ctor) | **② / FLOOR** | ~6 | `_hexa_init_stdio` `_hexa_init_mem_cap` `_hexa_init_small_int_cache` `_hexa_init_cached_strs` | ❌ 전역 캐시 + 환경 + RSS cap 초기화 (priority ctor) |
| enum repr | **FLOOR-adjacent** | ~4 | `_hexa_enum_idx` `_hexa_enum_display` `_hexa_enum_type_name` | ⚠ 디스플레이 로직 ①, 인덱싱은 repr |
| 순수 해시 / utf8 / tokenize | **①** | ~4 | `hexa_fnv1a` `hexa_fnv1a_str` `utf8_cpcount` `hexa_tokenize` | ✅ **순수 로직 — 지금 포팅 가능** (입력이 `char*`/`int`인 한) |
| math (`rt_*`) | **② thin** | ~15 | `rt_sin` `rt_cos` `rt_exp` `rt_sqrt` `rt_fmod` | ⚠ libm 래퍼 — `stdlib_trig_libm` 거버넌스에 따라 hexa libm builtin으로 대체 |

### §2.2 `self/runtime.c` — HI tier (~437 fn)

| 버킷 | layer | 대략 수 | 예시 | 포팅 가능성 |
|------|-------|---------|------|-------------|
| `hxlcl_*` libc/syscall shim | **②** | ~101 (정의) | `hxlcl_write` `hxlcl_read` `hxlcl_open` `hxlcl_mmap` `hxlcl_strstr` `hxlcl_strtoll` `hxlcl_socket` `hxlcl_select` | ❌ raw `svc 0x80` inline asm(`_hxlcl_syscall3_cf`) + libc 함수 self-host. **②의 본체** |
| `_hx_cuda_*` GPU driver FFI | **③** | ~34 | `_hx_cuda_farr_matmul_gpu` `_hx_cuda_farr_rope_gpu` `_hx_cuda_to_device` `_hx_cuda_runtime_available` | ❌❌ `dlopen`/`dlsym` → CUDA driver ABI. **irreducible vendor** (포팅 ≠ 제거, thin shim 영구 잔존) |
| `hexa_ffi_*` FFI 디스패치 | **③** | ~4 | `hexa_ffi_dlopen` `hexa_ffi_dlsym` | ❌ dlopen/dlsym 그 자체 |
| `hexa_farr*` / `_hx_farr_*` CPU 텐서 | **① logic / FLOOR-adjacent** | ~48 | `_hx_farr_add_cpu` `_hx_farr_matmul_t_cpu` `hexa_farr_zeros` `hexa_softmax` `hexa_silu` `hexa_rms` | ⚠ 산술 루프는 순수 ①이나 전역 `_hx_farr_table`의 raw `double*` buf 관리(arena-adjacent). buf 관리만 FLOOR, 커널은 ① |
| `hexa_term_*` termios | **②** | ~10 | `hexa_term_raw` `hexa_term_size` `hexa_term_restore` | ❌ tcsetattr/ioctl syscall |
| `hexa_exec*` 프로세스 (HI) | **②** | ~8 | `hexa_exec_capture` `hexa_exec_with_status` | ❌ fork/exec/pipe drain |
| `hexa_safetensors*` mmap 로드 | **②** | ~8 | `hexa_safetensors_load` `hexa_safetensors_tensor` | ❌ mmap + 헤더 파싱(파싱부는 ①, mmap은 ②) |
| `hexa_regex` / `_hexa_re_*` | **③** | ~8 | `_hexa_re_compile` `hexa_regex_match` | ❌ POSIX `regcomp`/`regexec` (vendor) |
| `hexa_struct_*` / trampoline / callback | **FLOOR-adjacent** | ~10 | `hexa_struct_pack_map` `hexa_trampoline*` `hexa_callback*` | ⚠ value-repr 빌드 + fn-ptr 디스패치 |
| `hexa_json*` | **①** | ~2 | `hexa_json_parse` | ✅ 파서 = 순수 ① (출력 value는 repr 의존) |
| `_hx_ad_*` autodiff tape | **① logic** | ~4 | `_hx_ad_record` `_hx_ad_grad_get/put` | ⚠ 로직 ①, grad 테이블은 raw 포인터 |
| `rt_*` fs/str/math (HI) | **② / ①** | ~16 | `rt_fs_mkdir_p` `rt_append_file`(②) · `rt_str_trim_start/end` `rt_isalpha`(①) | 혼합 — fs는 ②, ctype/trim은 ① |
| utc/time/sleep/host/env | **②** | ~15 | `hexa_now` `hexa_sleep` `hexa_setenv` `hexa_cwd` `hexa_host` | ❌ clock/nanosleep/getcwd/getenv syscall |

---

## §3 KEY FINDING — 진짜 잔여 작업 규모

합집합 ~640 fn을 layer로 집계 (혼합 버킷은 우세 layer로 귀속):

| layer | 대략 fn 수 | 비중 | 성격 |
|-------|-----------|------|------|
| **① now-portable (순수 로직)** | **~120** | ~19% | 해시·파서·텐서 커널 산술·ctype·trim·format 로직. 단 대부분 value-repr ABI 정착 후 실효 |
| **② libc/syscall** | **~190** | ~30% | `hxlcl_*` 101 + term/exec/fs/time/safetensors/mmap. hexa syscall surface 완성에 종속 |
| **③ vendor FFI (irreducible)** | **~50** | ~8% | CUDA 34 + ffi 4 + regex 8 + dlopen. **포팅해도 thin C shim 영구 잔존** (제거 불가, north-star의 hard floor가 아니라 hard *boundary*) |
| **FLOOR — GC/arena/value-repr** | **~240** | ~38% | array/map/value 생성자 + arena bump-allocator + 비교/디스패치 + intern + bootstrap init + struct-pack. **`.c`-zero 캠페인 전체를 막는 진짜 벽** |
| (잡/혼합 미분류 잔여) | ~40 | ~6% | — |

### §3.1 결론 (사용자가 알아야 할 진짜 크기)

1. **지금 당장 hexa로 옮길 수 있는 순수 로직은 전체의 1/5(~120 fn)에 불과**하다. 그나마도 대부분
   value-repr ABI가 codegen 측에서 동일하게 emit되어야 "실제로 의미 있는" 포팅이 된다.
2. **전체의 ~38%(~240 fn)가 GC/arena/value-repr FLOOR**다. 이것이 `.c`-zero의 진짜 블로커다.
   `hexa_arena_alloc`(bump allocator) · `hexa_array_new`/`hexa_map_new`(raw malloc + tagged-union) ·
   `hexa_int`/`hexa_str`(NaN-box repr) — 이들은 **hexa가 자체 런타임 FLOOR(repr/arena/GC)를 self-host
   할 수 있기 전까지 포팅 불가능**하다. 이는 MEMORY의 `project-hexa-selfhosted-state-2026-05-26`가 말한
   "잔여 = runtime FLOOR(repr/arena/GC) C→hexa + hexa-native 링커(phase H)"와 정확히 일치한다.
3. **layer ③(~50 fn)은 포팅의 대상이 아니다** — CUDA driver / dlopen / POSIX regex는 외부 ABI라
   thin C shim이 영구적으로 남는다. north-star `.c` ZERO를 글자 그대로 달성하려면 이 부분은
   "hexa-native inline-asm/FFI 경계"로 재정의해야 하며, 순수 제거는 비현실적이다.
4. 즉 **실효 포팅 가능 상한은 layer ① + layer ②(syscall surface 완성 가정) ≈ 전체의 절반**이고,
   나머지 절반은 (a) FLOOR(self-host 런타임 선행) (b) vendor FFI(영구 shim)로 나뉜다.

---

## §4 권장 포팅 순서 (쉬운 layer ① → 가장 어려운 FLOOR)

| 순번 | tranche | layer | 의존성 / 리스크 | 비고 |
|------|---------|-------|------------------|------|
| **T1** | 순수 해시/유틸 — `hexa_fnv1a` `hexa_fnv1a_str` `utf8_cpcount` `rt_isalpha`/`isalnum` `rt_str_trim_*` | ① | 입력이 `char*`/`int` → repr 무관. **가장 안전한 첫 착지** | 이미 `stdlib/runtime/numeric.hexa` 88 fn 류로 일부 LANDED |
| **T2** | JSON 파서 + base64 + sha1 (`hexa_json_parse` `_bt73_*`) | ① | 입력 파싱은 순수, 출력 value만 repr 경계 통과 | 출력은 codegen 생성자 통해 |
| **T3** | math (`rt_sin`/`cos`/`exp`/`sqrt`/`fmod`) | ② thin | `stdlib_trig_libm` 거버넌스 — hexa libm builtin으로 대체 | hand-rolled Taylor 금지 |
| **T4** | CPU 텐서 커널 산술 (`_hx_farr_add_cpu` 등 산술 루프) | ① | `_hx_farr_table` buf 관리(FLOOR-adjacent)와 커널 로직 **분리** 후 커널만 | buf 관리는 T7로 미룸 |
| **T5** | string repr op (`hexa_str_contains` `hexa_substr` `hexa_pad*`) | ① | `HX_STR` repr 추출 의존 → **value-repr ABI 확정 후**에만 의미 | T6와 lockstep |
| **T6** | value-repr 생성자 ABI 합의 (`hexa_int`/`float`/`str`/`bool`) | FLOOR | **codegen-s-self-emit(B9)이 동일 tagged-union emit** 해야 함 | RUNTIME.flip B9 codegen tranche와 동시 진행 |
| **T7** | array/map 원시 + intern (`hexa_array_new` `hmap_*`) | FLOOR | malloc + 해시 재배치. T6 위에 빌드 | wipe-prone(`runtime_c_deploy_regen_wipe`) — 후속 sync commit 시 patch 생존 확인 필수 |
| **T8** | **arena bump-allocator** (`hexa_arena_alloc`/`mark`/`rewind`) | FLOOR | **가장 hard** — hexa self-host 런타임 FLOOR의 핵 | phase-H 링커(`hexa_ld`) 선행 |
| **T9** | syscall surface (`hxlcl_*` 101 fn) | ② | hexa-native inline svc emit 필요 (`codegen/runtime_arm64.hexa`) | 일부 LANDED #1252/#1297/#1315 |
| **(영구)** | vendor FFI (CUDA 34 · regex 8 · dlopen) | ③ | thin C shim 잔존 — 포팅 대상 아님 | north-star 재정의 필요 |

---

## §5 PR/세션 규모 추정 (정직한 추정)

> ⚪ **추정치 — speculation-fenced.** 실측이 아니라 함수 수 + 의존 그래프 + wipe-risk 기반 산정.

- **layer ① now-portable (~120 fn)**: tranche T1·T2·T4의 repr-독립 부분만. 한 PR당 ~10–15 fn 안전 착지
  (wipe_guard + diff_guard 통과 단위) → **~8–10 PR / 2–3 세션**.
- **layer ② syscall surface (~190 fn)**: `hxlcl_*` 101개가 codegen inline-svc emit에 직결 →
  codegen-s-self-emit(B9)와 lockstep. 호스트별(Mac arm64 svc 0x80 vs Linux x86_64 syscall) 분기 →
  **~15–20 PR / 4–6 세션**.
- **FLOOR (~240 fn)**: 진짜 벽. value-repr ABI 합의(T6) → array/map(T7) → arena(T8) → phase-H 링커.
  각 단계가 self-host bootstrap을 깨지 않아야 하고(`compiler_selfbuild_blockers` OOM 인프라 제약 +
  공유 worktree 경합으로 canon fix가 wipe됨), serial 진행 강제 → **~25–35 PR / 8–12 세션**.
- **layer ③ (~50 fn)**: 포팅이 아니라 "FFI 경계 재정의" 작업 → **~3–5 PR / 1–2 세션** (제거 아님).

**총합 honest 추정: ~50–70 PR · 15–25 세션** (FLOOR가 전체 비용의 절반 이상).
가장 큰 미지수는 arena/GC self-host(T8) — hexa-native 런타임 FLOOR + phase-H 링커가 서야만 착수
가능하므로, 그 선행 인프라가 없으면 위 추정의 FLOOR 부분은 **블로킹**(추정 불가 → 인프라 게이트).

---

## §6 교차 참조

- `RUNTIME.flip.md` B9 — `runtime-c-fns-hexa-port` + `runtime-core-c-fns-hexa-port` + `self-host-linker`(phase-H)
- `LATTICE_POLICY.md` — real-limits-first 검증 (격자가 한계를 정하지 않음)
- RFC 061 §4.1 — runtime.c/runtime_core.c 2-layer 경계 기준 (본 감사의 layer 모델 출처)
- MEMORY `project-hexa-selfhosted-state-2026-05-26` — "잔여 = runtime FLOOR(repr/arena/GC) C→hexa + hexa-native 링커(phase H)"
- MEMORY `feedback-runtime-c-deploy-regen-wipe` — surgical edit 후 후속 sync commit에서 patch 생존 grep 확인 필수
- `stdlib/runtime/numeric.hexa` (88 fn 외) — 이미 LANDED된 layer ① 착지 사례

---

*End — `.c`-zero north-star의 진짜 크기: 순수 로직 ~1/5(지금) · syscall ~1/3(codegen 종속) ·
GC/arena FLOOR ~2/5(self-host 런타임 선행) · vendor FFI ~8%(영구 shim). 벽은 FLOOR다.*
