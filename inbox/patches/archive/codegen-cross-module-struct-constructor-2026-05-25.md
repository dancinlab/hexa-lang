# codegen: cross-module struct constructor — VinaAtom prototype not emitted

> **Status: resolved-already 2026-05-25** — 재현 불가. 본 패치 회부 시점의
> 증상은 `module_loader` 의 silent raw-src fallback (RSS cap 768 MB 초과 →
> flatten 실패 → `cmd_build` 가 raw `core/main.hexa` 를 `hexa_v2` 에 직접
> 전달 → codegen 의 `_resolve_use_emit` 경로 진입 → cross-module struct
> 생성자 extern 미생성 → clang `undeclared function` 폭발) 의 표면이었음.
> 해당 silent-fallback 의 루트 원인은 commit `215578a3` (2026-05-13,
> "cmd_build: raise module_loader RSS cap to 4096 MB") 에서 이미 해결됨.
> 후속 `3ba02522` 는 transpile-stage hexa_v2 도 4096 MB 로 끌어올림.
>
> 검증 (2026-05-25, worktree `inbox/codegen-cross-module-struct-resolved-2026-05-25`):
> - `hexa parse stdlib/chem/vina/search_test.hexa` → OK
> - `HEXA_MAC_BUILD_OK=1 hexa build stdlib/chem/vina/search_test.hexa` → **OK** (clang 통과 + 산출물 실행 가능)
> - `HEXA_MAC_BUILD_OK=1 hexa build stdlib/chem/vina/scoring_test.hexa` → **OK** (cycle-2 의 동일-증상 sibling 도 통과)
> - 빌드 로그 `[flat] module_loader → /tmp/.hexa-runtime/hexa_build_expanded.*.tmp.hexa` — flatten 경로 성공, raw-src fallback 미발동.
> - 강제 `HEXA_MEM_CAP_MB=128` 로도 vina-search 입력 크기에서는 flatten 성공.
>
> 인보 회부 에이전트 (PR #672) 는 `215578a3` 이후 main 에서 한 번 더 재현을
> 시도하지 않고 PR #644 의 표면 워크어라운드 컨벤션 (`hexa parse` PASS) 만
> 기록했음. 그 워크어라운드 컨벤션 자체는 유효하지만, 본 cycle 의
> root-cause 는 이미 닫혔으므로 별도 codegen 수정 불필요.
>
> **잔여 follow-up (옵션, 본 archive 와 분리):**
> 1. `compiler/codegen_c2.hexa:619` `_resolve_use_emit` 경로의 extern 미생성
>    동작 자체는 여전히 존재 (silent raw-src fallback 시 재발생 위험).
>    선택지: (a) 본 경로 자체를 deprecate · (b) 본 경로에서 cross-module
>    struct 생성자 extern 도 함께 emit. 본 archive 의 cycle-2 컨벤션과는
>    독립.
> 2. PR #644 의 `scoring_test.hexa` 가 cycle-2 컨벤션 명세 (parse-only) 로
>    landing 됐지만, 현재 main 에서는 `hexa build` 도 통과함. 컨벤션
>    노트는 follow-up cycle 에서 갱신 가능.

**Date:** 2026-05-25
**Surfaced by:** stdlib/chem/vina/ Monte Carlo search cycle (search.hexa + grid.hexa land).
**Repo:** dancinlab/hexa-lang
**Severity:** Blocks `hexa build` for any file that uses `import` (or `use`)
to bring a struct in and then constructs it with positional-args sugar — but
the struct is defined in a transitively-imported module rather than the
directly-imported one.
**Workaround:** `hexa parse` PASS is honored (cycle-2 convention; see
PR #644 / commit `c45b6dc6` — the cycle-2 scoring_test.hexa exhibits the
SAME error and was landed under the same convention).

## Minimal repro

```hexa
// scoring.hexa
pub struct VinaAtom { x: float, y: float, z: float, atype: string }
pub fn vina_pair_energy(a: VinaAtom, b: VinaAtom) -> float { return 0.0 }
```

```hexa
// search.hexa
use "stdlib/chem/vina/scoring"
pub fn whatever(a: VinaAtom) -> float { return 0.0 }
```

```hexa
// search_test.hexa
use "stdlib/chem/vina/scoring"
use "stdlib/chem/vina/search"
fn main() {
    let a = VinaAtom { x: 0.0, y: 0.0, z: 0.0, atype: "C" }   // <-- error
    println(to_string(whatever(a)))
}
```

`hexa parse search_test.hexa` → OK.
`HEXA_MAC_BUILD_OK=1 hexa build search_test.hexa` →

```
error: call to undeclared function 'VinaAtom'; ISO C99 and later do not
       support implicit function declarations
error: passing 'int' to parameter of incompatible type 'HexaVal'
```

C codegen emits `VinaAtom(...)` constructor calls in the test file's
translation unit but doesn't emit the corresponding C prototype that the
defining-module's translation unit declares.

## Same-symptom precedent

PR #644 (autodock-vina cycle 2, merged 2026-05-23) cycle-2 `scoring_test.hexa`
exhibits the identical clang error today on the merged main branch. It was
landed because `hexa parse` was clean. This memo formalizes the workaround
convention and registers the codegen fix for a follow-up cycle.

## Suggested fix axis

`compiler/codegen_c2.hexa` — when a translation unit references a struct
constructor whose definition lives in a module brought in via a transitive
`use`/`import` chain, propagate the constructor prototype into the
test-file's emitted C header. The direct-import case already works (the
cycle-1 single-file pattern, e.g. `ode_test.hexa` against `ode.hexa`).

## Files surfaced by this cycle

- `stdlib/chem/vina/grid.hexa` (new)
- `stdlib/chem/vina/search.hexa` (new)
- `stdlib/chem/vina/search_test.hexa` (new)

All three `hexa parse` clean. Build deferred until codegen fix lands.

## DEFER rationale (per @D g11/g59)

The MC search + grid affinity map implementations are SSOT-correct and
parse-clean. Building them needs the codegen fix above, which is a
compiler-internal change scoped to a sibling cycle. Landing the .hexa
source under the cycle-2 convention (PR #644) keeps the docking surface
moving forward without conflating with the codegen work.
