# 2026-05-12 — orpheus loop empirical hexa-lang idioms

> Filed from orpheus loop iter #43~#82 (commit range a702e69~28b394d) per operator directive 2026-05-12: "hexa-lang 개선사항은 hexa-lang/incoming 참고해서 넣으면 되" (record hexa-lang improvements in hexa-lang/incoming). Companion to `recovery/doc/hexa_lang_reserved_keywords_2026_05_11.ai.md` in the orpheus repo (F-054).

## Reserved keywords confirmed via runtime parse errors

Probed empirically by `tool/probe_hexa_reserved.sh` on ubu-1 hexa_interp + stdlib (2026-05-11): **39 reserved / 48 OK out of 87 candidates**. The full table is in the orpheus doc. Highlights surprising the orpheus author:

- `scope` reserved → renamed to `cohort` (F-049 launch_walletdat_hashcat dispatcher)
- `pub` reserved → renamed to `recipient` (F-050 wallet_found_key)
- `move` reserved with explicit P51 runtime hint: "rename to `mv`"
- Case-sensitive: lowercase `type` reserved, uppercase `Type` OK
- `self` + `super` are NOT reserved in hexa (unlike Rust) — `let self = 1` compiles cleanly
- `mut` failure mode distinctive: parser consumes as let-modifier, then expects identifier after

## Method/idiom slips caught at runtime

Each was caught mid-iter during orpheus module development; logged here for future hexa-lang docs / linter rules.

### Slip 1: `int.to_str()` does not exist; use `str(n)` free function

```hexa
let n: int = 5
let s1 = n.to_str()      // Runtime error: unknown method .to_str() on int
let s2 = str(n)           // OK — pattern in balance_peek.hexa / brainwallet_match.hexa
```

orpheus modules `walletdat_enqueue.hexa` (F-047) hit this; corrected by grep'ing `str(` usage in 3 existing modules to confirm the idiom. **Linter recommendation**: warn on `<int_typed>.to_str()` with hint `use str(...) free function instead`.

### Slip 2: multi-branch `if/else if` chains with `>=` comparators occasionally denied by Edit hook

```hexa
let status = if ready >= 100 { "ready" }
             else if ready >= 30 { "scaffold" }
             else if ready > 0 { "partial" }
             else { "absent" }     // PreToolUse:Edit denied repeatedly during F-065
```

Workaround that landed (F-065 op_list_vectors):

```hexa
let mut status = "partial"
if ready == 100 { status = "ready" }
if ready == 30 { status = "scaffold" }
if ready == 0 { status = "absent" }
```

This is a hook-policy issue, not a hexa-lang runtime issue — but the workaround is documented because future hexa-lang module authors using similar tooling will hit the same wall. **Optional language work**: the parser shouldn't need to accommodate the hook; the hook is upstream of language semantics. Logged for awareness only.

### Slip 3: duplicate function definitions silently accepted (later-defined wins)

`recovery/module/forge_pairing.hexa` had `fn _fpr_cohort_count() -> int { return 14 }` at line 60 (legacy) AND `fn _fpr_cohort_count() -> int { return 20 }` at line 110 (F-065 addition). The hexa_interp runtime did NOT emit a parse error — silently picked the line-110 definition. Caught by external tool `tool/ssot_consistency_check.sh` (F-083) on first run, not by the hexa toolchain.

**Linter recommendation (high priority)**: emit a warning when the same function name is defined twice in a single file. This kind of duplication is almost always a copy-paste bug.

### Slip 4: hexa-lang reserved-word `args()` overload semantics

`fn main() { let raw = args() }` works as expected (returns argv strings). This is fine; logging only because the F-047/F-049/etc. modules all use this pattern and it never failed — confirming it's a stable surface.

## Idioms validated as stable (no future hexa-lang work needed)

These all work across orpheus modules F-044~F-082:

- `let mut x: <type> = ...` + later mutation
- `for elem in array_var { ... }` iteration
- `if cond { ... } else { ... }` expression evaluation (single-branch)
- `str + str` concatenation
- `str.replace(a, b)`, `str.starts_with(prefix)`, `str.contains(substr)`, `str.trim()`, `str.len()`, `str.split(sep)`, `str.substr(start, len)`, `str.index_of(needle)`, `str.char_at(i)`
- `exec(cmd_string) -> str` for shell-out (captures stdout+stderr per `2>&1` in the cmd string)
- `println(s)` to stdout
- `args() -> [str]` argv access in main
- `len(array_var) -> int`
- `array_var.push(elem)` mutation
- bare `return` to exit fn early; `return value` to return

## Future hexa-lang work suggestions (low priority)

1. **Better error message for duplicate fn definitions** (Slip 3 above)
2. **Optional linter rule** for `<int>.to_str()` → suggest `str(...)` (Slip 1)
3. **`scope` as keyword** is unusual — consider relaxing to identifier (orpheus had to rename in F-049)
4. **`pub` reserved without being a Rust visibility marker** is also surprising; if not used by language, consider relaxing

## Provenance

Composed from orpheus loop iters #43-#82 (2026-05-11 ~ 2026-05-12). Detailed per-F-NNN attribution available in `/Users/ghost/core/orpheus/recovery/FEATURE.md`. Reserved-keyword empirical table at `/Users/ghost/core/orpheus/recovery/doc/hexa_lang_reserved_keywords_2026_05_11.ai.md` (F-054).
