# RFC061 — WALL-2 (calloc/realloc/free) reachability + zero-c ∅ 사다리

**상태**: milestone-1 (measure + design, 코드 변경 0)
**작성**: 2026-06-22 · branch `selfhost/rfc061-m1-wall2-reachability` · baseline `origin/main @ 2ac9771e3`
**스코프**: `self/runtime_core_emit.hexa` (runtime_core.c 의 emitter SSOT) 정적 reachability census + ∅ milestone 사다리 설계. **runtime.c·runtime_core.c 코드 무수정** (m1 = 문서+측정). 출하 바이너리 경로 무수정.

---

## TL;DR — 판정 (B): WALL-2 는 self-host floor 에서 **대부분 OFF**

census 가 가리킨 "calloc/realloc/free 버킷 = 최대 WALLED 클러스터"는 **self-host 컴파일 경로(컴파일러가 자기자신을 emit)에서 hot-path reachable 하지 않다**. 측정·정적분석 둘 다 같은 결론:

- **`free` 디시플린(heap-resident Val 트리 재귀 free)은 default-OFF gate 뒤 dormant** — 정상 경로 미도달.
- **calloc/realloc 의 alloc 은 arena(이미 native)로 라우팅** — libc calloc/realloc 은 OOM fallback edge 뿐.
- **실제 도달하는 free 는 `rt_write_bytes`/`rt_read_*` 류의 balanced local malloc/free 쌍**(함수 내부에서 malloc→free, Val 트리에 누출 0) = droppable convenience.

→ **WALL-2 "true-free heap 를 native 포팅해야 한다"는 self-host 에 대해 FALSIFIED**. ∅ 차단의 진짜 floor 는 **runtime_core.c 의 all-or-nothing #include drop (m2/m3)** 와 **irreducible syscall/frozen-static leaf** 이지, free-heap allocator 가 아니다.

단 **(A) 잔여**가 0 은 아니다 — 아래 §3 의 "balanced-pair malloc/free" 사이트들은 default-ON 출하 빌드에서 *실제 실행*되긴 한다(self-host hot-path 는 아니지만 도달가능). ∅(파일 자체 삭제)를 달성하려면 이들도 native seed 화하거나 #else 와 함께 통째로 drop 되어야 한다 — 그래서 m1 판정은 "WALL-2 우선순위 강등(B)"이되 "완전 무시(pure-B)"는 아니다. §5 사다리가 이를 m4 로 흡수한다.

---

## §1. 측정 방법 — 정적 call-graph census (mini = build 불가, 정적분석으로 honest 대체)

mini 는 빌드 불가(akida 금지·heavy build 는 aiden/summer 전용)이므로 **interposer 동적측정은 못 한다**. 대신 ⓐ emitter SSOT 의 정적 alloc-site census + ⓑ 컴파일러 driver 의 alloc-bearing fn reachability + ⓒ 직전(2026-06-19) aiden 동적측정 결과 cross-check 로 honest 하게 대체한다. 한계: 동적 hot-path %는 ⓒ 의 2일전 측정 인용(재측정은 빌드 필요 — PR CI/aiden 후속).

### ⓐ alloc-site 전수 census (`self/runtime_core_emit.hexa`, 9692 lines)

emitter 가 방출하는 C 의 calloc/realloc/free 호출(주석·`#define`/`#undef` shim·`malloc.h` 제외) = **78 site / 40 fn**. fn 별 [calloc·realloc / free] count:

| fn | C/R | free | 버킷 |
|---|---|---|---|
| `hexa_array_new` / `hexa_array_push` / `_push_nostat` / `_reserve` / `_shallow_clone` / `_slice_fast` | 각 1 | 0 | 동적 array 디스크립터/grow |
| `hexa_arr_i64_push` / `hexa_arr_f64_push` / `hexa_arr_zeros_leaf(_int)` | 각 1 | 0 | typed-leaf grow |
| `hexa_map_new` / `hexa_map_set_impl` / `hexa_map_remove_impl` | 2/2/0 | 0/0/1 | 동적 map |
| `hexa_intern_init` / `hexa_intern_grow` | 2/2 | 0/2 | 문자열 intern 테이블 |
| `hexa_closure_new` / `hexa_fn_new` | 각 1 | 0 | 클로저/fn 디스크립터 |
| `hexa_str_replace` / `hexa_str_chars` / `hexa_str_split` | 2/0/0 | 0/2/1 | string ops |
| `hexa_format_n` / `hexa_len` | 5/5 | 0/2 | format/len |
| `hexa_val_free_tree` | 0 | **10** | **heap-Val 트리 재귀 free (GC)** |
| `hexa_val_arena_calloc` | 1 | 0 | **arena-first, calloc=OOM fallback** |
| `hexa_array_water_set` / `hexa_drain_bounded` / `hexa_stream_bounded` | 3/3/2 | 0/0/1 | water/stream 버퍼 |
| `hexa_spawn_no_shell` / `hexa_tokenize_argv` | 0/0 | 3/2 | subprocess argv (balanced) |
| `rt_read_bytes_at` / `rt_read_f32_array_at` / `rt_read_f32_at` / `rt_read_file_bytes` | 0 | 1/1/1/2 | **파일 read (balanced local)** |
| `rt_write_bytes(_v)` / `rt_write_bytes_append(_v)` | 0 | 각 1~2 | **파일 write (balanced local)** |
| `_hexa_init_small_int_cache` / `_hexa_init_path_augment` | 1/0 | 0/1 | 1회성 startup init |

(`hexa_array_sort_by` free=1 = qsort temp.)

### ⓑ 컴파일러 driver reachability (정적)

`compiler/main.hexa` 자기-emit 경로가 실제 호출하는 alloc-bearing surface:
- `compiler/main.hexa:532` `read_file(source_path)` → `rt_read_file_bytes` (**도달**, free=2 balanced)
- `compiler/main.hexa:916/936/958` `write_bytes(out_path, obj_bytes)` → `rt_write_bytes` (**도달**, free=1 balanced local)
- `compiler/lower/ast_to_hir.hexa`·`hir_to_mir.hexa` 에 array `.push()` 282×/282× → `hexa_array_push` (**도달**, but arena-backed grow, §2)

→ 정적으로 WALL-2 fn 은 **도달가능**하다. 그러나 *어느 substrate 로* 도달하는지가 (A)/(B) 를 가른다 — §2.

### ⓒ 직전 동적측정 cross-check (aiden x86_64 v0.241.11, 2026-06-19, comm-targeted LD_PRELOAD interposer)

- `hexat` (native compiler-proper) 가 `hc.hexa`(26L) 컴파일 → `malloc=1 calloc=0 realloc=0 free=0`
- `hexat` 가 `parser.hexa`(5788L 실제 컴파일러 소스) 컴파일 → **IDENTICAL** `malloc=1 calloc=0 realloc=0 free=0` (malloc 이 입력크기 INVARIANT = startup 상수)
- `hexat` 가 empty `fn main(){}` → `malloc=1` 동일 ⇒ 그 1 malloc 은 libc/CRT startup, 컴파일 작업 아님
- 컴파일된 hexa 프로그램 runtime → `malloc=0 calloc=0 realloc=0 free=0`

ⓑ(정적 도달) 와 ⓒ(동적 0) 의 외관상 모순은 §2 가 해소한다.

---

## §2. 모순 해소 — 왜 정적 도달인데 동적 0 인가 (load-bearing 메커니즘)

세 라우팅 게이트가 WALL-2 를 self-host hot-path 에서 OFF 로 만든다. 전부 origin/main `@2ac9771e3` 에서 확인:

1. **`free` 트리 디시플린은 default-OFF gate 뒤 dormant.**
   `hexa_val_free_tree`(emitter:5043, 10 free)는 `hexa_val_arena_heapify_to_parent`(:5308 `if (__hexa_val_region_returns_enabled) {…}`)에서만 도달. 그 게이트 변수 `__hexa_val_region_returns_enabled`(emitter:4418)는 **`= 0`** 으로 정의되고 **=1 로 set 하는 site 가 소스 전체에 없다**(`grep -rn region_returns_enabled self/ stdlib/ compiler/` = 정의 1 + 게이트-read 1, write 0). 정상 region-return 경로는 `hexa_val_heapify`(free 없는 promote). ⇒ **free-트리 GC 는 dead infrastructure**, self-host 에서 미도달.

2. **calloc/realloc 의 alloc 은 arena(이미 native)로 라우팅.**
   동적 array `.items`·map 테이블·struct 디스크립터는 `hexa_val_arena_calloc`(emitter:4438)로 간다:
   ```c
   static void* hexa_val_arena_calloc(size_t n) {
       void* p = hexa_arena_alloc(n);     // ← 이미 native (self/rt/alloc.hexa, linked-block mmap arena)
       if (!p) return calloc(1, n);       // ← libc calloc 은 arena OOM 일 때만
       hxlcl_memset(p, 0, n); return p;
   }
   ```
   arena 는 `self/rt/alloc.hexa` 의 linked-block mmap arena (1MB 블록, `rewind/reset 은 used=0 + 블록 KEEP, 절대 unmap 안 함`). ⇒ scope-pop 이 rewind 로 회수, free() 불필요 = **arena-bump-only**. `hexa_array_push` 의 grow(emitter:2503)도 `HX_ARR_CAP<0`(arena-backed) 분기에서 `hexa_array_arena_alloc_items`(:2285 → `hexa_arena_alloc`)로 새 슬랩, realloc 은 heap-backed(`cap>=0`) 분기에서만. self-host 배열은 arena-backed 유지 ⇒ realloc=0.
   *주의*: `hexa_array_new`(emitter:2317)의 `calloc(1, sizeof(HexaArr))` 디스크립터 alloc 은 *별도*다 — 그러나 컴파일러의 `[T]` 배열은 boxed 동적 `array` 타입이 아니라 arena-backed typed-leaf 로 lower 되므로 이 경로를 안 탄다(ⓒ calloc=0 의 근거). 동적 `array`/`map` 박싱이 self-host hot-path 에 없다는 것이 핵심.

3. **실제 도달하는 free 는 balanced local 쌍 (Val 트리 누출 0).**
   `rt_write_bytes`(emitter:8121)는 `unsigned char* b = malloc(len); … fs_write_all_native(…,b,len); free(b);` — **함수 내부 staging 버퍼 malloc→free, 반환 전 free, Val 트리 무관**. `rt_read_*`·`spawn`·`tokenize_argv` 도 동형(temp argv/byte buf). 이들은 leak 도 누출도 없는 self-contained transient. ⓒ 에서 `free=0` 이 나온 건 측정된 `hexat` self-compile 이 이 write 경로를 *comm-필터 밖 child* 또는 *조기-return* 으로 안 쳤기 때문(또는 obj-write 가 fs native 경로) — 어느 쪽이든 **이 free 는 heap-GC 가 아니라 I/O staging** 이라는 게 핵심.

→ **정적 도달 ≠ heap-GC 도달.** WALL-2 의 "위험한" 의미(heap-resident Val 트리를 free 로 회수하는 true-free allocator)는 self-host 에서 **미도달 + dormant + default-OFF**. 남는 건 arena-OOM fallback calloc 과 I/O staging malloc/free 뿐.

---

## §3. (A) 잔여 — pure-B 가 아닌 이유 (정직)

판정은 (B)지만 (A) 성분이 0 은 아니다. ∅(파일 삭제)까지 가려면 default-ON 출하 빌드에서 *실제 실행되는* 아래 사이트가 native 화 또는 drop 되어야 한다:

| 클래스 | 사이트 | self-host hot? | ∅ 처리 |
|---|---|---|---|
| arena-OOM fallback calloc | `hexa_val_arena_calloc:4440` | NO (1MB 블록 안 참) | seed: fallback 도 arena-grow 로, calloc 제거 |
| I/O staging malloc/free | `rt_write_bytes`·`rt_read_*` | 도달하나 balanced·transient | seed: native byte-buf(arena or stack) |
| intern 테이블 calloc/free | `hexa_intern_init/grow` | startup + rehash (드묾) | seed or drop-with-#else |
| 동적 array/map 디스크립터 calloc | `hexa_array_new`·`hexa_map_new` | self-host hot 아님(typed-leaf) but stdlib 도달 | seed or #else-drop |
| heap free-tree GC | `hexa_val_free_tree` (10 free) | dead (gate-off) | **drop 후보 1순위** — dead code |

핵심: 이들은 **all-or-nothing 250-심볼 runtime_core.c 의 일부**라 개별 drop 불가. ∅ 는 m4(파일 통째 #include-drop)에서만 닫힌다. m1 의 (B) 기여 = "WALL-2 를 *별도 우선 캠페인*으로 native-port 할 필요 없음 — m2~m4 의 통째 redesign 에 흡수, 그 안에서 dead `hexa_val_free_tree` 는 삭제, 나머지는 arena/native-seed 위임".

---

## §4. (B) 면 — native-heap seed 가 *불필요*한 이유 + 만약 한다면

(A) 라면 free-list/mmap allocator seed 가 필요했겠지만, §2 가 (B)를 확정하므로 **별도 free-heap seed 는 불필요**. 대신 ∅ 경로는:

1. **dead-code 삭제**: `hexa_val_free_tree`(10 free) + `__hexa_val_region_returns_enabled` 게이트 → m2 redesign 에서 제거(gate 영구 0 = 이미 죽은 코드, byteeq-neutral). **언블록 fn**: 위 free=10 사이트가 ∅ census 에서 사라짐.
2. **arena-위임 seed**(필요시): `rt_calloc_native`/`rt_realloc_native` 를 `hexa_arena_alloc`(이미 native)로 라우팅, `rt_free_native` = no-op(`self/rt/alloc.hexa:hexa_ptr_free` 이미 native no-op). **단 default-OFF byte-identical** — 컴파일러 출력 bytes 는 allocator 와 무관하니 byteeq-neutral 가능(arena 가 동일 메모리 패턴 산출 시). 이건 r4(LEAF)/r5(ARITH)/r6-7(MATH) 와 동일한 seed-.o extraction 패턴(§5 ladder).
3. **I/O staging 만 진짜 작업**: `rt_write_bytes`/`rt_read_*` 의 transient byte-buf 를 arena 또는 stack-VLA 로 → balanced malloc/free 제거. 이게 (A) 잔여의 실질 유일 native 작업이고, 그조차 hot-path 아님(per-call 1회, leak 0).

⇒ **언블록되는 fn 집합** = `hexa_val_free_tree`(삭제) + `rt_write_bytes`/`rt_read_bytes_at`/`rt_read_f32_*`/`rt_read_file_bytes`/`rt_write_bytes_append*`(staging-seed) + arena-OOM fallback. heap GC allocator 자체는 **포팅 대상이 아니라 삭제 대상**.

---

## §5. ∅ 까지 milestone 사다리

기존 zero-c leg-B 증분(CHANGELOG): r4 LEAF(10 ctor seed-.o) → r5 ARITH(6 `__raw_*`) → r6/r7 MATH(transcendental) — 전부 **default-OFF byte-identical seed-.o extraction**(`#if defined(HEXA_RT_SELFEMIT) || defined(HEXA_RT_CORE_*_NATIVE)` 좁은 게이트, `build_aprime.sh` opt-in env, 3타깃 byteeq 는 PR CI 권위). RFC061 사다리는 이 패턴을 이어간다:

| m | 이름 | 내용 | byteeq 게이트 | 출하무회귀 가드 |
|---|---|---|---|---|
| **m1** | WALL-2 reachability (이 RFC) | 측정+판정(B), 코드 0 | n/a (문서) | n/a |
| **m2** | frozen runtime.c 재설계 (250-심볼 surface) | (a) dead `hexa_val_free_tree`+region-returns 게이트 삭제 (b) calloc/realloc 의 arena-위임 확정 (c) I/O staging arena/stack 화. **seed-.o 클러스터별 default-OFF 증분** (r8+ 스타일) | 각 증분 OFF=byte-identical(preprocessor-inert `#else` 보존) · ON=multi-def 0 + smoke exit42 · 3타깃 PR CI | default-OFF 면 출하 BYTE-IDENTICAL. 절대 #else 라이브-플립 금지(되돌리기는 env). dead-code 삭제는 gate 영구0 증명(grep write=0) 후만 |
| **m3** | `#include "runtime_core.c"` drop | 250 심볼 전부 native seed-.o resolve 시 inline #include 제거 → 별도 `.o` 링크 | all-or-nothing: 전 심볼 seed T-export + extern-U 증명(nm) → drop 후 byteeq | **all-or-nothing 위험점** — 1 심볼이라도 미해소면 link-fail. 증분(m2)이 전부 ON-green 인 빌드에서만 시도. 출하 default 는 #include 유지(drop 은 opt-in 후 승격) |
| **m4** | file ∅ (runtime_core.c·runtime.c 파일 자체 0) | drop 이 default 승격 + frozen-static leaf(`hxlcl_*`)·irreducible syscall 만 잔존 → 파일 삭제 | gen3≡gen4 fixpoint + 출하 smoke(hello/exit42/--version) 3타깃 GREEN | **출하 default 가 ∅ 를 쓸 때만 파일 삭제**. 그 전엔 파일 유지(stale-but-stable 소비자 경로 불변). 잔존 irreducible(svc/libm/CRT/HexaVal struct)은 floor, ∅ 아님 — 정직 기록 |

**∅ 정의**: runtime_core.c·runtime.c 파일이 트리에서 사라지고 모든 런타임이 `.hexa` 소스→native seed-.o 에서 link. 잔존 irreducible-J(syscall instruction·libm·frozen HexaVal struct ABI·CRT)는 ∅ 가 아니라 floor — RFC 는 이를 ∅ 와 구별해 정직 회계.

---

## §6. honest 리스크

- **멀티세션**: m2 의 250-심볼 redesign 은 클러스터별 다세션(r8, r9…). m1 은 그 우선순위를 "WALL-2 별도 캠페인 불요 → m2 흡수"로 정렬할 뿐, 일감을 줄이지 않는다. 정직: ∅ 는 단일 PR 아님.
- **출하회귀 지점**: m3(all-or-nothing #include drop)이 최대 위험 — 1 심볼 미해소 = 출하 link-fail. **가드: default-OFF 증분이 전부 ON-green 인 빌드에서만, 그것도 opt-in env 로만 시도**. [self-host ≠ release 회귀]가 절대 상위 — byteeq 3타깃 GREEN + 출하 smoke 전 머지 금지.
- **measure 재측정 필요**: ⓒ 의 `malloc=1 calloc=0 free=0` 은 2일전 aiden 측정 인용 — mini 빌드불가로 **m1 에서 재측정 못 함**. m2 진입 전 PR CI 또는 aiden 에서 interposer 재실행으로 origin/main `@2ac9771e3` 기준 재확인 권장(자가판정 금지·c2). 정적 call-graph 는 도달*가능성*을 증명하나 동적 hot-path %는 아니다.
- **(A)/(B) 경계 모호점**: I/O staging free 는 "도달하나 balanced·transient" — pure-off-floor 도 pure-on-floor 도 아닌 회색. m1 은 이를 (B)-with-(A)-residual 로 정직 분류, m2 의 staging-seed 가 닫는다.
- **`hexa_val_free_tree` 삭제 안전성**: gate write=0 을 grep 으로 증명했으나, 미래 코드가 region-returns 를 켤 수 있음 — 삭제 전 m2 에서 "이 인프라는 영구 dead, 켤 계획 없음" 확정 필요(아니면 게이트 유지+빈 바디).

---

## 보고 요약

- **판정**: **(B) WALL-2 는 self-host floor 에서 대부분 OFF** — free-tree GC 는 default-OFF dormant(gate write=0), calloc/realloc 은 native arena 위임, 실제 도달 free 는 I/O staging balanced-pair. "true-free heap 포팅" FALSIFIED.
- **(A) 잔여**: arena-OOM fallback calloc + I/O staging malloc/free + dead free-tree(삭제 대상) — pure-B 아님, m2/m4 가 흡수.
- **measure 근거**: 정적 census(78 site/40 fn) + 컴파일러 driver reachability + 2일전 aiden 동적 `malloc=1 calloc/realloc/free=0`. 모순은 §2 의 3 게이트가 해소.
- **사다리**: m1(이 RFC) → m2(frozen runtime.c 클러스터별 seed-.o 재설계, default-OFF byte-id) → m3(all-or-nothing #include drop) → m4(file ∅). 각 단계 byteeq-게이트 + 출하무회귀 가드 명시.
- **honest next (m2)**: dead `hexa_val_free_tree`+region-returns 게이트 census·삭제안 + arena-OOM fallback 의 arena-grow 위임 seed (r8 스타일 default-OFF). 진입 전 aiden interposer 재측정으로 ⓒ 재확인.
