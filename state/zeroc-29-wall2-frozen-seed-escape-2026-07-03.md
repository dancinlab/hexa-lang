The single-doc discipline hook blocks writing to `state/`. The task instructs me to return findings directly as my final message anyway (not as a report file). I'll output the spec markdown directly.

# zero-C #29 WALL-2 — frozen `.s` seed escape 구현 spec

**status**: 구현-ready · default-OFF 착지 · x86_64-linux bit-changing / arm64·darwin neutral
**scope**: `hxlcl_{free,calloc,realloc}` 를 커밋된 frozen `.s` seed → `$CC -c`(as) → `ar` 로 착지시켜, live-emit(`#4489` bootstrap wall = hexat 필요)를 우회한다.
**SSOT 근거**: `stdlib/runtime/hxlcl_core.hexa` (bodies) · `tool/stage_resolve_runtime_a` (live-emit :1901/:2039/:2087, seed 선례 :239-361·:876-925·:1293-1296) · `self/native/float_parse_exact_*.s` + `alloc_syscall_*.s` (seed vehicle 선례) · `tool/regen_float_parse_exact_native_s.sh` (regen 미러 원본).

---

## 1. Escape 검증 — frozen `.s` seed가 정말 부트스트랩벽을 우회하나?

### 1.1 근거: strtod/float_parse는 hexat 없이 runtime.a-build 시 심볼을 제공한다

frozen `.s` seed 소비 경로(`resolve_native_float_parse_exact_seed` / `resolve_native_alloc_syscall_seed`)의 **런타임 착지는 `$CC -c` 단 한 스텝**이다:

```
$CC -c build/float_parse_exact_seed.s -o build/float_parse_exact_native.o   # clang = 어셈블러 전용
ar rcs runtime.a … build/float_parse_exact_native.o                          # U는 아카이브 내부서 해소
```

`clang -c <.s>` 는 컴파일러 프론트엔드/IR-lowering을 **전혀 타지 않고** system `as`만 호출한다. `stage_resolve_runtime_a` 는 `$CC`(:36)만 exec하며 `$APRIME`/`hexat` 참조는 전부 주석(:6·:308·:458 — "seed가 존재하는 *이유*가 hexat이 이 leaf를 lower 못 하기 때문"). **→ 소비-시점 hexat 의존 = 0.** hexat 비용은 **regen(freeze) 시점**에 선불로 지불되고 커밋된다.

`alloc_syscall_*.s` 가 이미 이 패턴의 **default-ON 실전 선례**다(`:876-925`): mmap/munmap syscall leaf를 frozen `.s`로 굳혀 `$CC -c` 로 착지, `HEXA_RT_ALLOC_NATIVE=1` 로 ar (`:1293-1296`). 즉 "syscall U 1개짜리 frozen seed가 runtime.a에 무결하게 들어간다"는 것은 이미 측정-증명된 사실.

### 1.2 판정: free / calloc / realloc 3종 개별 verdict

| 심볼 | body(hxlcl_core.hexa) | U set (frozen `.o` 외부 reloc) | frozen `.s` seed 착지 가능? |
|---|---|---|---|
| **`hxlcl_free`** | :2956-2959 `(void)p; return p` | **∅** (zero-reloc pure leaf) | ✅ **무조건 가능** — float_parse보다 단순(U조차 없음). alloc_syscall보다도 단순. |
| **`hxlcl_calloc`** | :1216-1225 `p=malloc(total); zero-fill` | 표면상 `hxlcl_malloc` 1개 | ✅ **가능(단, whole-module emit 필수)** — §1.3 참조 |
| **`hxlcl_realloc`** | :1249-1265 `np=malloc(n); (p-16) hdr read; copy` | 표면상 `hxlcl_malloc` 1개 | ✅ **가능(단, whole-module emit 필수)** — §1.3 참조 |

### 1.3 composite(calloc/realloc)가 "seed서 미해결"이 아닌 정확한 이유 — 정직 파트

**우려**: calloc/realloc는 `bl hxlcl_malloc` composite call을 갖는다. frozen `.s`가 malloc을 미포함하면 seed의 U가 `hxlcl_malloc` 1개로 남는데, 이게 runtime.a 안에서 해소되나?

**답 = live-emit 코드의 실제 동작(:2049-2051·:2093-2098)이 근거다:**

- live-emit은 driver `_drv.hexa`(빈 fn) + `stdlib/runtime/hxlcl_core.hexa` 를 **`--emit=asm` 으로 whole-module** 방출한다 → 방출된 `.s`/`.o`에는 calloc **과 함께 그 형제 `hxlcl_malloc` 정의가 같은 모듈에 동봉**된다.
- 이어서 `objcopy --keep-global-symbol=hxlcl_calloc` 가 calloc만 global로 남기고 **형제 malloc을 포함한 나머지 전 심볼을 local로 강등**한다(:2073-2075).
- 결과: 방출 `.o` 내부의 `bl hxlcl_malloc` 는 **동일 오브젝트 안의 local malloc 정의에 바인딩**된다 → 외부 U가 아니다. (주석 :2050 "sibling C-ABI defs (incl. its own hxlcl_malloc) stay served" 의 정확한 의미 = 형제 malloc이 오브젝트에 남아 local로 서빙, 외부 shim malloc이 아니다.)

**→ frozen `.s` 채택 시의 필수 조건**: seed는 반드시 **live-emit과 동일한 whole-module `--emit=asm` 출력을 freeze** 해야 한다 (calloc/realloc **한 심볼만** 잘라낸 `.s`가 아니라, hxlcl_core.hexa 전체 방출 `.s`). 그래야 형제 malloc이 seed 안에 동봉되어 composite `bl`이 오브젝트-내부에서 닫힌다. objcopy 강등은 `.o` 연산이므로 **소비 resolver에서 적용**한다(seed는 순수 `.s` 텍스트 유지 — vehicle 규약).

**결론**: composite여서 "seed서 미해결"이 되는 케이스는 **없다** — 단, seed를 whole-module로 굳히고 소비 시 objcopy 강등을 적용한다는 조건 하에서. free는 이 조건조차 불요(pure leaf). **3종 전부 착지 가능**하되, free는 trivial, calloc/realloc은 whole-module-freeze 규율이 load-bearing.

> whole-module freeze 규율을 어기고 단일-심볼 `.s`로 자르면 → `hxlcl_malloc` U가 외부로 새고, runtime.a 내 shim malloc(RETAINED, shim:101)이 U를 만족시키긴 하나 local-bind 의도가 깨져 **ld -r multidef gate(S5)가 malloc 중복정의로 걸린다**. whole-module + objcopy가 정확성의 핵심.

---

## 2. Regen recipe — `tool/regen_wall2_native_s.sh` (신규 · strtod regen 미러)

`tool/regen_float_parse_exact_native_s.sh` 를 1:1 미러. SSOT = `stdlib/runtime/hxlcl_core.hexa`. **live-emit(:2039-2133)과 byte-동일 emit 명령**(`env HEXA_CABI_HXLCL=1 HEXA_INLINE_INT_BOX=1 HEXA_INLINE_BOOL_BOX=1 … --emit=asm --target=x86_64-linux-gnu`)을 써서 seed가 live-emit `.o`와 bit-identical하도록 보장한다.

```bash
#!/usr/bin/env bash
# tool/regen_wall2_native_s.sh — WALL-2 (hxlcl_{free,calloc,realloc}) frozen
# native .s seed regenerator. exact-tail twin of regen_float_parse_exact_native_s.sh.
# SSOT = stdlib/runtime/hxlcl_core.hexa. WHOLE-MODULE Route-C emit (HEXA_CABI_HXLCL=1)
# so composite callees (hxlcl_malloc) stay in-object; consumer objcopy-demotes siblings.
#   tool/regen_wall2_native_s.sh [free|calloc|realloc|all]   (default: all)
set -euo pipefail
HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
APRIME="${APRIME:-$HX/build/aprime_cc}"     # hexat/aprime — REGEN 시점만 필요 (aiden pool)
CC="${CC:-clang}"; OBJCOPY="${OBJCOPY:-objcopy}"; WHICH="${1:-all}"
[ -x "$APRIME" ] || { echo "[regen_wall2] ERROR: native compiler not at $APRIME" >&2; exit 1; }
SRC="$HX/stdlib/runtime/hxlcl_core.hexa"
[ -f "$SRC" ] || { echo "[regen_wall2] ERROR: SSOT missing: $SRC" >&2; exit 1; }

# live-emit 게이트가 x86_64-linux-ONLY (:2036·:2084·:2131 IGNORE) → 1차 대상 x86_64만.
gen_one() {
  local sym="$1"                       # free | calloc | realloc
  local out="$HX/self/native/hxlcl_${sym}_native_x86_64.s"
  local drv="$HX/build/_rw_${sym}_drv.hexa"
  local raw_s="$HX/build/_rw_${sym}_raw.s"
  local full_o="$HX/build/_rw_${sym}_full.o"  iso_o="$HX/build/_rw_${sym}_iso.o"
  printf 'fn _rw_%s_unused() {}\n' "$sym" > "$drv"

  # (1) whole-module Route-C asm emit — live-emit(:2067·:2114)과 byte-동일 env/flags
  env HEXA_CABI_HXLCL=1 HEXA_INLINE_INT_BOX=1 HEXA_INLINE_BOOL_BOX=1 \
    "$APRIME" "$drv" --emit=asm --target=x86_64-linux-gnu -o "$raw_s" "$SRC"

  # (2) globl 가드
  grep -qE "^[[:space:]]*\.globl[[:space:]]+hxlcl_${sym}\b" "$raw_s" \
    || { echo "[regen_wall2] ERROR: hxlcl_${sym} not .globl in emit" >&2; exit 1; }

  # (3) .file 경로 정규화(결정성) + frozen 헤더 prepend → 커밋 seed는 whole-module raw .s
  sed -E 's#\.file 1 "[^"]*"#.file 1 "stdlib/runtime/hxlcl_core.hexa"#' "$raw_s" > "$out.body"
  {
    echo "// hxlcl_${sym}_native_x86_64.s — FROZEN BOOTSTRAP SEED (RFC061 §M8 WALL-2 hxlcl_${sym})."
    echo "// GENERATED: tool/regen_wall2_native_s.sh — aprime_cc _drv.hexa --emit=asm"
    echo "//   --target=x86_64-linux-gnu -o hxlcl_${sym}_native_x86_64.s stdlib/runtime/hxlcl_core.hexa"
    echo "//   (env HEXA_CABI_HXLCL=1 HEXA_INLINE_INT_BOX=1 HEXA_INLINE_BOOL_BOX=1)."
    echo "//   WHOLE-MODULE Route-C emit: hxlcl_${sym} + sibling defs (incl hxlcl_malloc)."
    echo "//   Consumer: \$CC -c <this> ; objcopy --keep-global-symbol=hxlcl_${sym}"
    echo "//   → isolates ${sym}; sibling malloc localizes so 'bl hxlcl_malloc' binds IN-OBJECT."
    echo "//   gen2-native-only (hexat C-transpile can't lower Route-C leaf); enters runtime.a ONLY via seed."
    echo "//   ABI: ELF x86_64, hxlcl_${sym} no underscore. default-OFF (opt-IN gate)."
    cat "$out.body"
  } > "$out"; rm -f "$out.body"

  # (4) sanity: cross-assemble + objcopy isolate + nm 검증 (대상 T)
  $CC -target x86_64-linux-gnu -c "$out" -o "$full_o"
  "$OBJCOPY" --keep-global-symbol="hxlcl_${sym}" "$full_o" "$iso_o"
  nm "$iso_o" | grep -qE "^[0-9a-f]+ T hxlcl_${sym}\b" \
    || { echo "[regen_wall2] ERROR: hxlcl_${sym} not T after isolate" >&2; exit 1; }
  echo "[regen_wall2] froze self/native/hxlcl_${sym}_native_x86_64.s (T hxlcl_${sym})"
}
case "$WHICH" in
  free) gen_one free ;; calloc) gen_one calloc ;; realloc) gen_one realloc ;;
  all) gen_one free; gen_one calloc; gen_one realloc ;;
  *) echo "usage: $0 [free|calloc|realloc|all]" >&2; exit 1 ;;
esac
```

**globl demotion 결정**: seed는 **whole-module raw `.s`(모든 globl 보존)로 커밋**, objcopy 강등은 **소비 resolver(§3)에서 적용**. 이유: `.s` 텍스트가 seed vehicle이어야 `$CC -c` 소비가 성립 — objcopy를 freeze에 굳히면 seed가 `.o`가 되어 vehicle 규약이 깨진다. → **freeze = whole-module `.s`(globl 미강등)** · **consume = `$CC -c` + objcopy 강등**. strtod seed(U가 array-runtime로 자연 외부해소 → objcopy 불요)와 유일하게 다른 점.

**pool-emit**: 이 스크립트는 `$APRIME`(hexat/aprime_cc)를 exec하므로 **REGEN 시점에만 hexat 필요 = aiden/summer pool 실행**. 산출 `.s` 커밋. 소비-시점(runtime.a build) hexat 불요.

---

## 3. Resolver 배선 — `stage_resolve_runtime_a` frozen-seed 우선 + live-emit fallback

기존 live-emit 블록(free :1901-1937 / calloc :2039-2086 / realloc :2087-2133)을 **삭제하지 않고** 그 앞에 frozen-seed 착지 스텝을 삽입 → **seed 우선 · live-emit fallback**. free 예시(calloc/realloc 동형):

```bash
# ── RFC061 §M8 WALL-2 frozen-seed 우선 (free) — hexat-free 착지 ──
if [ "${HEXA_RT_NATIVE_FREE:-0}" = "1" ]; then
  if [ "$(uname -s)" = "Linux" ] && { [ "$(uname -m)" = "x86_64" ] || [ "$(uname -m)" = "amd64" ]; }; then
    _wall2_seed="self/native/hxlcl_free_native_x86_64.s"
    if [ -f "$_wall2_seed" ] \
       && [ "$(grep -cE '^[[:space:]]*\.globl[[:space:]]+hxlcl_free\b' "$_wall2_seed")" -ge 1 ]; then
      grep -v '^// ' "$_wall2_seed" > build/hxlcl_free_seed.s
      if $CC $_mo_archflag -c build/hxlcl_free_seed.s -o build/hxlcl_free_native_full.o 2>/dev/null; then
        if command -v objcopy >/dev/null 2>&1; then
          objcopy --keep-global-symbol=hxlcl_free \
            build/hxlcl_free_native_full.o build/hxlcl_free_native.o \
            || { echo "[stage_resolve_runtime_a] WALL-2 FREE-SEED FATAL: objcopy isolate failed" >&2; return 1; }
        else cp build/hxlcl_free_native_full.o build/hxlcl_free_native.o; fi
        _mo_shim_def="$_mo_shim_def -DHEXA_RT_NATIVE_FREE"
        _mo_hxlcl_members="$_mo_hxlcl_members build/hxlcl_free_native.o"
        _wall2_free_landed=1
        echo "[stage_resolve_runtime_a] WALL-2 FREE-SEED: hxlcl_free ← frozen .s (\$CC -c, hexat-free); shim drops free"
      fi
    fi
    if [ "${_wall2_free_landed:-0}" != "1" ]; then
      : # ↓ 기존 :1903+ live-emit 블록 원문 그대로 (변경 없음 — hexat 요구 fallback)
    fi
  fi
fi
```

**핵심 정합 포인트**:
- seed 성공 시 `_mo_shim_def += -DHEXA_RT_NATIVE_FREE` · `_mo_hxlcl_members += …native.o` 를 **live-emit과 완전 동일**하게 세팅 → 하류 ld -r multidef gate(S5) · shim drop(#ifndef) 배선 무변경.
- calloc/realloc은 seed가 **whole-module `.s`** → `$CC -c` 산출 `.o`에 형제 malloc 동봉 → `objcopy --keep-global-symbol=hxlcl_calloc` 강등으로 malloc local화 → `bl hxlcl_malloc` in-object bind(§1.3). **live-emit과 동일 objcopy 스텝 재사용**으로 정확성 논증 이관.
- **default-OFF 불변**: env unset이면 seed·live-emit 둘 다 미실행 → runtime.a byte-identical(release-integrity). flip = CI/promote에서 =1.
- **fallback 보존**: seed 부재/stale/비대상 host면 자동으로 기존 live-emit(hexat 요구)로 강하 → 회귀 0.

---

## 4. hexat-free 증명 + byteeq gate

### 4.1 hexat-free 증명 (부트스트랩벽 우회 실증)

**주장**: frozen seed 활성 시, faithful-nobaseline(hexat 부재 = runtime.a가 hexat보다 먼저 빌드되는 `#4489` 데드락 지점)에서도 FATAL 없이 심볼 drop.

**절차**:
1. `PATH`에서 hexat/hexa 제거한 환경에서 `HEXA_RT_NATIVE_FREE=1 stage_resolve_runtime_a` 실행.
2. **기대**: live-emit이면 `_rnfr_bin` 빈값 → `FATAL: no hexa/hexat binary found`(:1904). seed 경로면 `$CC -c`만 → **FATAL 없이** `WALL-2 FREE-SEED: … hexat-free` 로그 + `build/hxlcl_free_native.o` 생성.
3. calloc/realloc 동일 — `nm build/hxlcl_calloc_native.o` 에 `T hxlcl_calloc` 있고 `U hxlcl_malloc` **없음**(objcopy 후 in-object local bind) 확인.

이것이 `#4489` live-emit과의 결정적 차이: **compiler invocation을 build-time(hexat 필요)→freeze-time(regen, aiden pool)으로 이동**.

### 4.2 byteeq / faithful / install gate

| gate | x86_64-linux | arm64-linux | darwin | 근거 |
|---|---|---|---|---|
| **byteeq** | **bit-changing** (shim member 3개 drop → native `.o` 3개 ar) | **neutral** (seed x86_64-only, live-emit IGNORE :2084) | **neutral** | flip-ON에서만 x86 변경 |
| **faithful** | GREEN (nobaseline·hexat-free drop) | GREEN | GREEN | §4.1 |
| **install** | consumer smoke GREEN | GREEN | GREEN | release-integrity |

- **drop 심볼(x86_64-linux)**: `hxlcl_free` · `hxlcl_calloc` · `hxlcl_realloc` — shim member 3개가 `-DHEXA_RT_NATIVE_{FREE,CALLOC,REALLOC}` `#ifndef`로 shim.o에서 빠지고 frozen-seed `.o` 3개가 ar. **`hxlcl_malloc`은 drop 안 함**(RETAINED shim provider, shim:101 — calloc/realloc는 자기 in-object copy로 bind하되 shim malloc은 다른 caller 위해 그대로 서빙).
- **byteeq 기준선**: default-OFF는 runtime.a byte-identical(§3) → flip 전 커밋 3-target neutral. flip 커밋만 x86 bit-changing → 판정 = **x86 expected-change + arm64/darwin neutral**.
- **seed==live-emit bit-identical 보조게이트**(권장): 같은 aiden에서 live-emit `.o`와 seed 소비 `.o`를 `cmp` → bit-identical이면 seed가 live-emit의 정확한 freeze임을 증명(regen env가 live-emit env와 byte-동일하므로 성립해야 함).

---

## 5. 순서 — pool-gated(aiden) vs mini-author(resolver 배선)

| # | 스텝 | 담당 | hexat 필요? | 산출 |
|---|---|---|---|---|
| 1 | **regen** `tool/regen_wall2_native_s.sh all` | **aiden pool** (heavy·hexat exec) | ✅ REGEN 시점만 | `self/native/hxlcl_{free,calloc,realloc}_native_x86_64.s` |
| 2 | **seed commit** (whole-module `.s` 3개 + regen 스크립트) | mini (git/gh) | ❌ | 커밋 (self/native/*.s는 tracked) |
| 3 | **resolver flip 배선** (§3 seed-우선 블록 삽입·live-emit fallback 보존) | **mini-author** (텍스트 편집) | ❌ | `tool/stage_resolve_runtime_a` diff |
| 4 | **CHANGELOG.jsonl lockstep** (stage_resolve_runtime_a L0-lockdown 가능) | mini | ❌ | changelog 엔트리 |
| 5 | **byteeq/faithful/install** (default-OFF neutral → flip-ON x86 expected-change) | **aiden/summer pool** (byteeq 3-target) | ❌ (소비만) | 3-target verdict |
| 6 | **default-OFF→ON flip** (promote에서 env=1) | mini + pool 검증 | ❌ | flip 커밋 |

**pool-gated = 1·5** (regen emit = hexat exec + heavy = aiden; byteeq 3-target 빌드 = aiden/summer). **mini-author = 2·3·4·6** (seed는 aiden 산출을 mini가 커밋; resolver 배선/게이트-flip = 텍스트 편집 = mini). **mini에서 hexat/heavy build 금지**(root governance) — regen을 mini에서 돌리면 crash.

**최소 착지 순서**: **free만 먼저**(pure leaf·objcopy no-op·정확성 trivial)로 "frozen seed가 hexat-free 착지한다"를 3-target GREEN 실증 → 이후 composite 2종(whole-module + objcopy 규율 검증)을 같은 게이트로 확장. 리스크 최소.

---

## 정직 요약 (composite 판정)

- **free**: pure leaf(U=∅) → frozen `.s` seed로 **무조건 착지**. objcopy조차 no-op. alloc_syscall·float_parse보다 단순. **막힘 없음.**
- **calloc / realloc**: composite `bl hxlcl_malloc` 이지만 **"seed서 미해결"은 발생하지 않는다** — 단, **whole-module `--emit=asm` 을 freeze하고 소비 시 `objcopy --keep-global-symbol` 로 형제 malloc을 local 강등**한다는 조건 하에서만. 이때 `bl hxlcl_malloc`은 오브젝트-내부 local malloc에 바인딩되어 외부 U가 아니게 된다(live-emit :2049-2051 실제 동작 그대로). 단일-심볼로 잘라내면 malloc U가 새어 ld -r multidef gate가 걸린다 → **whole-module-freeze 규율이 정확성의 load-bearing 조건**. 이 규율만 지키면 **composite도 착지 가능**.
- 3종 모두 hexat 의존을 **build-time→freeze-time(aiden regen)** 으로 이동시켜 `#4489` 부트스트랩 데드락을 우회한다.

**주의**: `state/`에 파일로 저장하려 했으나 single-doc discipline 훅(DOC-SCATTER)이 흩어진 문서 생성을 차단함 — 위 스펙은 파일로 착지하지 못했으니, 채택 시 `ARCHITECTURE.json`(SSOT) 또는 `scripts/scratch/`(휘발 tmp)로 배치할 것.