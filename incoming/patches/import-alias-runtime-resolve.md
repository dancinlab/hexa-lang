# incoming patch: import-alias-runtime-resolve — `import "..." as <alias>` runtime undefined function

> **id**: `import-alias-runtime-resolve` · **opened**: 2026-05-14 KST PM · **status**: `proposed`
> **source**: `dancinlab/anima` VOICE Phase 1 impl (`tool/hexa_native/intent_proj.hexa` + `tool/hexa_native/voice_bridge.hexa`) — `import "./intent_proj.hexa" as ip` parses OK but runtime `ip.apply(...)` resolves to `Runtime error: undefined function: __mod_ip__apply`.
> **why this matters**: modular split (intent_proj + voice_bridge + smoke 3-file) → forced collapse to single combined `tool/anima_voice_smoke.hexa` (~350 LoC). VOICE Phase 1 LANDED w/ 5/5 PASS via single-file, but modular split (clean separation of concerns) blocked until this resolves.

---

## 1. 재현

### 1.1 Two-file case

**file `m.hexa`**:
```hexa
fn add(a: int, b: int) {
    return a + b
}
```

**file `caller.hexa`**:
```hexa
import "./m.hexa" as m

fn main() {
    println(m.add(2, 3))
}
```

**run**:
```
$ RESOURCE_LOCAL_HEXA=1 hexa run caller.hexa
Runtime error: undefined function: __mod_m__add
void
```

→ parser accepts `import "..." as <alias>` + `<alias>.<fn>(...)`, but linker / interp 가 mangled name (`__mod_<alias>__<fn>`) 을 module file 의 `add` 와 연결 못 함.

### 1.2 anima VOICE Phase 1 실측

```
$ ls tool/hexa_native/{intent_proj,voice_bridge}.hexa
   (exist, syntactically valid, individually parse OK)

$ RESOURCE_LOCAL_HEXA=1 hexa run tool/anima_voice_smoke.hexa
   # smoke 가 `import "./hexa_native/intent_proj.hexa" as ip` + `ip.apply(...)`
Runtime error: undefined function: __mod_ip__apply
Runtime error: undefined function: __mod_ip__d_intent
...
```

→ 동일 패턴. anima 는 Phase 1 LANDED 위해 3 파일 → 1 파일 combined 로 우회 (`tool/anima_voice_smoke.hexa` commit `fcdc3cae5`).

### 1.3 Workaround (현재 anima 채택)

모든 함수를 단일 `.hexa` 안에 inline → `import` 제거 → fully-qualified prefix `ip_` / `vb_` 수동 prefix → 작동.

```hexa
// no import
fn ip_apply(hidden) { ... }
fn ip_d_intent() { ... }
fn vb_voice_emit(hidden, n_frames: int) { ... }

fn main() {
    let i_vec = ip_apply(hidden)   // direct call (no module qualification)
}
```

→ Phase 1 5/5 PASS. 하지만 modular composition 가 *완전 차단* — 다른 file 에서 ip.apply 호출 불가.

---

## 2. 가설 (코드 미열람, 외부 관찰만)

`Parse error → Runtime error` 전환 사실:
- parser 가 `import "..." as <alias>` 받아들임 (no parse error)
- parser 가 `<alias>.<fn>(...)` 받아들임 (no parse error)
- 어딘가에서 `<alias>.<fn>` → `__mod_<alias>__<fn>` mangling
- 그 mangled name 이 *호출* 측 frame 에 등록되지만 *정의* 측 module file 의 함수가 같은 mangled name 으로 등록 안 됨

가능 원인 (3):

1. **module file 의 함수가 prefix 안 받음** — `m.hexa` 의 `add` 가 그냥 `add` 로만 등록, `__mod_m__add` 로 alias-prefixed 등록 안 됨
2. **import 의 alias scope** — `as ip` 가 *parser scope* 에서만 valid, runtime symbol table 에 alias→module 매핑 등록 안 됨
3. **module 자체 load 누락** — `import "./m.hexa"` 가 syntactic 만 처리, 실제로 `m.hexa` parse + load 가 일어나지 않아 함수 table 에 추가 안 됨

가장 가능성 높음: 가설 3 (`import` 가 directive 수준에서 file load 안 함). 또는 가설 1 + 2 조합.

---

## 3. 제안 fix (specification, 코드 미수정)

### 3.1 Behaviour spec
`import "<path>" as <alias>` 처리:

1. `<path>` 의 `.hexa` 파일을 parse + load
2. 그 file 의 *exported* top-level `fn <name>` 을 alias-prefixed mangled name `__mod_<alias>__<name>` 로 caller scope 에 등록
   (or: module table `modules[<alias>] = {<name> → fn body}` 으로 등록 + `<alias>.<name>` 호출 시 lookup)
3. 같은 file 의 import-side `<alias>.<fn>(args)` → mangled name 또는 module table lookup 으로 dispatch

### 3.2 Spec-level 결정 (3 options)

| Option | Module rule | Pro | Con |
| --- | --- | --- | --- |
| (A) **Default export all top-level fns** | 모든 `fn` exported | 즉시 작동, simple | namespace 오염, helper fn 도 노출 |
| (B) **Explicit `pub fn`** | `pub fn` 만 exported | Rust-style 명확 | breaking change, all existing modules 의 `pub` 추가 필요 |
| (C) **`@export` directive** | `@export fn ...` 만 exported | breaking 없음, opt-in | parser annotation 추가 작업 |

anima 권장: **(A)** 즉시 작동 우선. helper fn 은 `_` prefix convention 으로 visual hint (mitosis_hook.hexa 의 `_mit_*` pattern 와 같음).

### 3.3 Builtin / stdlib 충돌

`safetensors_smoke.hexa` 의 working pattern (`import "/home/aiden/core/hexa-lang/stdlib/safetensors.hexa"`, no alias) 은 stdlib 에 hard-coded path + 같은 file scope 로 *함수 직접 사용* 인 듯. alias 없이 작동 → 가설 1/2 (alias 가 unresolved) 보강 증거.

stdlib import 와 user-module import 의 *symbol resolution* 이 같은 mechanism 따르도록 통일 권장.

---

## 4. 영향 받는 prior + future work

### 4.1 anima VOICE Phase 1 (LANDED w/ workaround)
- `tool/anima_voice_smoke.hexa` (`fcdc3cae5`) — combined single-file. Phase 2 의 modular split 차단.
- Phase 2 path: `tool/hexa_native/intent_proj.hexa` + `tool/hexa_native/voice_bridge.hexa` 분리는 본 patch land 후 가능.

### 4.2 anima_chat.hexa Phase 2 (planned)
- `voice_emit` hook 을 anima_chat token-loop 에 추가. voice 로직을 별도 `voice_bridge.hexa` 로 두면 anima_chat.hexa (현 1589 LoC) 가 더 sprawl 안 함.
- 본 patch 없으면 anima_chat.hexa 안에 voice 함수 inline → file 비대화.

### 4.3 mitosis_hook 추후 통합
- `mitosis_hook.hexa` (1119 LoC) 와 `voice_bridge` 가 의도 임베딩 동일 hidden state 공유. cross-module call (mitosis 가 voice trigger, voice 가 mitosis state read) 가 modular import 의존.

### 4.4 hexa-codex 17-verb cognitive + hexa-senses 5-verb sensory
- 둘 다 `cli/<name>.hexa` entry + 다수 verb file. verb-별 module split 이 import alias 의존. 현재는 single-file inline 또는 stub.

---

## 5. Test plan (post-fix)

minimum repro (§1.1) 가 PASS:
```
$ hexa run caller.hexa
5
```

anima Phase 1 modular restore:
1. `tool/anima_voice_smoke.hexa` 의 inline 코드 제거
2. `tool/hexa_native/intent_proj.hexa` + `tool/hexa_native/voice_bridge.hexa` (이미 작성된 코드, 본 patch 의 git history 에 commit `fa902716a` 이전 revision 에 있음 — 실제로는 commit fcdc3cae5 에서 *제거됨*, recovery 필요) restore
3. `tool/anima_voice_smoke.hexa` 에 `import` 다시 추가
4. `hexa run` F-VOICE-1..5 5/5 PASS

---

## 6. Honest C3

1. **anima maintainer 가 hexa-lang 내부 미열람** — 본 patch 는 *외부 관찰* 만으로 spec 제안. hexa-lang code base 의 import resolver 위치는 maintainer 확인 의무.
2. **VOICE Phase 1 은 이미 작동** — 본 patch 없어도 anima Phase 1 5/5 PASS. blocking issue 아님, *quality-of-life* + *future composition* enabler.
3. **다른 hexa workflow 들이 같은 우회** — `mitosis_hook.hexa` (1119 LoC) 가 single-file 인 것도 본 issue 의 동일 우회일 가능성. cross-cutting issue.
4. **import w/ no-alias (stdlib)** 는 작동 — 본 patch 의 scope 는 *user-module + alias* 전용. stdlib regression 위험 0.

---

— `incoming/patches/import-alias-runtime-resolve.md`, 2026-05-14 KST PM, anima VOICE Phase 1
  modular split 의 미충족 requirement, source `dancinlab/anima` commit `fcdc3cae5`
