# Bug — `&var` address-of + `or`/`and` keywords rejected by current parser

**Reporter**: anima-physics verification cycle 2026-05-21 (22 ✅ entries re-fire)
**Filed**: 2026-05-21
**Severity**: LOW (workaround in source — files quarantined) / MEDIUM (language-drift signal — older landed files no longer transpile).
**Status**: OPEN — port deferred to a future cycle. anima-physics `entries/substrate/consciousness-loop/*` README badges accordingly downgraded ✅ → 🟡 with pointer to this note.

## Symptom

`hexa run anima-physics/consciousness-loop/src/main.hexa` reports:

```
Parse error at 318:40: expected RParen, got Ident ('engine')
Parse error at 318:46: unexpected token Comma (',')
Parse error at 318:52: unexpected token RParen (')')
Parse error at 319:38: unexpected token BitAnd ('&')
```

`main_longrun.hexa:87`:
```
Parse error at 87:29: expected LBrace, got Ident ('or')
Parse error at 87:50: unexpected token LBrace ('{')
```

`snn_main.hexa:196`:
```
Parse error at 196:65: expected RParen, got Ident ('f')
Parse error at 196:66: unexpected token RParen (')')
```

All 3 files were ✅ LANDED in earlier hexa-lang releases (anima-physics
README §3 listed them PASS) but no longer transpile against
`hexa 0.1.0-dispatch`.

## Two source patterns the parser rejects

### Pattern 1 — `or` / `and` keywords (boolean ops)

```hexa
if step % 1000 == 0 or step == STEPS - 1 {     // main_longrun.hexa:87
    println("  step {step}: ...")
}
```

Current parser only accepts `||` / `&&`. The memory note
`feedback_hexa_lang_syntax_gotchas` already documents this — these files
predate that change.

### Pattern 2 — `&var` address-of

```hexa
fn engine_process(self: *ConsciousnessEngine, input: [f32]) { ... }
// ...
engine_process(&engine, quiet_input)                // main.hexa:317
engine_intra_faction_sync(&engine, 0.15)            // main.hexa:318
```

Function signatures use `*Type` (pointer parameter) but the parser rejects
the matching call-site `&var` (address-of). Modern hexa likely passes the
struct by-value or accepts a bare `engine` ident for `*Type` parameter
slots (autoref), but the precise convention isn't documented and other
PASSing hexa files in the codebase don't use the same mutate-by-pointer
pattern.

## Repro

```hexa
// addr_of.hexa
record Engine { tick: int }

fn bump(self: *Engine) { self.tick = self.tick + 1 }

fn main() {
    var e = Engine { tick: 0 }
    bump(&e)               // <-- Parse error: expected RParen
    println(e.tick)
}
```

```
$ hexa run addr_of.hexa
Parse error at <line>:<col>: expected RParen, got Ident ('e')
```

## Affected anima-physics files (3, scope quantified)

```
$ grep -c '&[a-z]' consciousness-loop/src/{main,main_longrun,snn_main}.hexa
main.hexa:20
main_longrun.hexa:9
snn_main.hexa:8

$ grep -c '\(\bor\b\| or \|\band\b\| and \)' consciousness-loop/src/main_longrun.hexa
main_longrun.hexa:~3 lines
```

## Port options (none picked this cycle)

1. **Rewrite to functional style** — `engine_process(engine, input) -> Engine`,
   reassign `engine = engine_process(engine, ...)`. Pure but invasive (touches ~40 call sites across 3 files).
2. **Add language-level autoref for `*Type` params** — upstream hexa-lang RFC. Smallest user-side change but largest upstream change.
3. **Restore `&var` parsing as alias for autoref** — upstream parser tweak, lets old files transpile without modification.

Decision deferred until upstream owner (`dancinlab/hexa-lang`) confirms which direction modern hexa is going for struct-self mutation.

## Workaround in anima-physics this cycle

- 3 files left as-is in the repo
- README badge ✅ → 🟡 with "(toolchain stale — see hexa-lang inbox 2026-05-21)"
- 22-entry verification reported the FAIL honestly

## Related

- Sibling inbox note same date:
  `2026-05-21-anima-physics-parser-diag-shell-interp.md`
  — fixes the wrapper-side diagnostic rendering. Pattern 1/2 bug is
  source-side, separate from the diag-rendering bug.
- `memory/feedback_hexa_lang_syntax_gotchas.md` already lists `&&`/`||`
  required vs `and`/`or`; this note adds `&var` to that list.
