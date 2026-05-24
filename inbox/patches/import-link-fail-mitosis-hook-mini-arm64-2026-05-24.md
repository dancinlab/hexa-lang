# inbox/patches — import link fail: mitosis_hook lib on mini arm64 (anima imagination_loop blocker)

**Status**: resolved-PR#722-2026-05-25 — bin/hexa-fast runs module_loader flatten on SRC with import/use/from directives (mirrors cmd_build/cmd_run)

## § Header

- 일자: 2026-05-24
- 출처: anima cycle 6 imagination_loop daemon launch failure (agent `a3f66e8902f95eaa1`)
- Severity: **high** — mini arm64 에서 `mitosis_hook` 계열 라이브러리를 `import` 하는 모든 anima daemon launch 차단
- Scope: hexa_v2 transpiler `import` 동작 (extern decl emit ↔ imported lib fn body 컴파일 누락)

## § Symptom (verbatim)

mini arm64 에서 `anima_imagination_loop.hexa` (PR dancinlab/anima#273) 빌드 시 다음 linker error 발생:

```
Undefined symbols for architecture arm64:
  "_cell_pool_init", referenced from: __il_init_pool, _selftest
  "_mitosis_forward_tail", referenced from: _imagine_tick
ld: symbol(s) not found for architecture arm64
```

동일 증상이 `mitosis_hook.hexa` 를 직접 `import` 해도 재현됨 (`split_cell`, `merge_cells` 도 같은 양상).

## § Repro (4-line minimal consumer)

```hexa
// /tmp/repro.hexa
import "/Users/mini/anima_chat_pack/mitosis_hook_lib.hexa"
fn main() {
  let pool = cell_pool_init(8, 2)
  println(pool)
}
```

mini arm64 에서:

```
hexa run /tmp/repro.hexa
```

→ 위 Symptom 과 동일한 `Undefined symbols for architecture arm64` 출력. consumer 만으로 4 줄 재현 확보.

## § Root cause hypothesis

`import "X.hexa"` 처리 시 hexa_v2 transpiler 는

1. imported lib (`X.hexa`) 의 public fn name 들에 대해 **extern declaration 만 emit** 함 (consumer translation unit 안에서 외부 링크 기대)
2. 그러나 imported lib 의 **fn body** 를 consumer translation unit 안으로 함께 컴파일하지 **않음**, 그리고 별도 .o 도 생성하지 **않음**

결과: consumer 의 .o 는 `_cell_pool_init` 등 심볼을 외부에서 찾는데, 같은 링크 단계에 그 심볼을 제공하는 .o 가 전혀 없음 → linker fail. C 헤더만 `#include` 하고 .c 는 빌드 안 한 상태와 동형.

## § Affected modules (anima side)

- `HEXAD/CHAT/server/anima_imagination_loop.hexa` (PR dancinlab/anima#273)
  - 의존: `cell_pool_init`, `mitosis_forward_tail`, `split_cell`, `merge_cells`
  - daemon verb 구현 완료지만 mini arm64 에서 실행 불가
- 향후 `mitosis_hook` 계열을 `import` 하는 모든 anima daemon (chat / monologue / persona-cell-pool 등)

## § Suggested fix candidates (3 ranked by g0)

1. **(a)** hexa_v2 transpiler: `import "X.hexa"` 만나면 X.hexa 의 fn body 들을 consumer translation unit 안으로 함께 컴파일 (single .o link). 가장 단순, C `#include` 동작과 동형, 본 케이스 최소 변경.
2. **(b)** hexa_v2 transpiler: imported lib 마다 별도 .o 생성 + linker 에 자동으로 같이 넣어줌 (multi-file link). C++/Rust 와 더 가까움, 구현 복잡도 ↑, 중복 import 가드 / symbol 충돌 정책 필요.
3. **(c)** workaround: consumer 안에 imported fn body 를 inline 복붙. `import` 의미 자체를 무너뜨림 (anti-g0), 임시 unblock 외 용도 없음.

권장: 단기 (a), 중기 (b) 로 진화.

## § Side finding: mini's hexa wrapper broken

조사 중 mini 의 hexa CLI launch 자체가 깨져 있음을 확인 — 본 issue 와 별개지만 같이 기록:

- 경로 `~/core/hexa-lang/hexa` 는 shim. 내부에서 `hxv2` / `hexa.real` 를 호출하는데 두 바이너리 모두 **존재하지 않음** (AMFI rename saga 잔재 — prior MEMORY 참조)
- 실제로 동작하는 invocation: `~/core/hexa-lang/bin/hexa-fast run <file> <verb>` (`~/.hexa-cache/` 의 cached binary 사용)
- 권장: mini install 에 `hxv2` symlink / binary 복원 (별도 inbox 권장)

## § Cross-link (anima evidence)

- PR dancinlab/anima#273 — `anima_imagination_loop.hexa` daemon verb 구현 LANDED, mini arm64 에서 link fail 로 실행 불가
- anima cycle 6 imagination_loop daemon launch agent `a3f66e8902f95eaa1` — 본 issue 의 1차 관측자
