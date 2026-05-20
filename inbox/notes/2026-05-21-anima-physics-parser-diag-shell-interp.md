# Bug — parser diagnostic body shell-interpreted in `transpile failed` path

**Reporter**: anima-physics verification cycle 2026-05-21 (22 ✅ entries re-fire)
**Filed**: 2026-05-21
**Severity**: MEDIUM — masks real parser diagnostics with confusing shell errors.
  Compile errors `exit 1` correctly; the user just sees garbled output instead
  of the actionable parser message (e.g. `auto-invoke conflict — add @manual_main`).
**Status**: OPEN — patch hunk below; not applied (work tree dirty on
  `runtime-cycle66-exec-recovery-2026-05-21`, unrelated cycle in flight).

## Symptom

Running `hexa run <file>` on a source that triggers a parser hard-fail prints:

```
sh: command substitution: line 0: syntax error near unexpected token `('
sh: command substitution: line 0: `fn main()'
sh: command substitution: line 1: syntax error: unexpected end of file
sh: command substitution: line 1: syntax error: unexpected end of file
sh: @manual_main: command not found
sh: fn: command not found
error: transpile failed — C file not produced: build/artifacts/hexa_run.<ts>.c
```

The parser's intended diagnostic was:

```
error: auto-invoke conflict — `fn main()` is auto-called by hexa-strict
       AND a top-level `main()` call was found, which would run main() twice...
hint: remove the explicit `main()` call (auto-invoke handles it)
hint: OR add `@manual_main` attribute on `fn main` to opt out of auto-invoke
```

The backticked tokens (`` `fn main()` ``, `` `@manual_main` ``, `` `main()` ``)
in the parser's stderr get re-shell-interpreted as backtick command substitution
in the wrapper.

## Repro

```bash
# Any file with `fn main()` AND a top-level `main()` call, no @manual_main
$ cat > /tmp/double_main.hexa <<'EOF'
fn main() {
    println("hi")
}
main()
EOF

$ hexa run /tmp/double_main.hexa
# Observed: shell-interp garbage as shown above.
# Expected: parser diagnostic with backticks rendered verbatim.
```

Real-world impact: 8 / 22 anima-physics ✅ entries (arduino/cmos/fpga/memristor
cloud_facade_poc, quantum/bell_state, quantum/cloud_facade_poc, tool/mk_xii
aggregator v1/v2) silently look "broken" until you grep parser source for the
strings the shell tried to interpret. `tool/v3` PASSED only because it carried
`@manual_main` already (so the parser never reached the broken diag path).

## Root cause

`self/main.hexa:2169`:

```hexa
let has_perr = exec("printf '%s' \"" + r1 + "\" | grep -q 'Parse error' && printf yes || printf no")
```

`r1` is the captured parser stdout/stderr (`v2 + " " + src + " " + c_file + " 2>&1"`).
It is embedded into a **double-quoted** shell string. Double quotes preserve
backticks and `$()` for command substitution, so any backticks in the parser
diagnostic become live shell command substitutions. With current parser
diagnostics containing backticked tokens, every error path triggers this.

## Fix (proposed patch hunk)

Replace the shell pipe with a hexa-native string contains check. The whole
`exec("printf | grep -q")` round-trip exists only to ask "does this string
contain `Parse error`" — which is a pure-hexa operation.

```diff
--- a/self/main.hexa
+++ b/self/main.hexa
@@ -2166,7 +2166,9 @@
     if len(r1) > 0 { println("    " + r1) }
     // 파싱 실패는 hexa_v2 가 stdout 에 "Parse error" 로 찍고도 exit 0 인
     // 특성이 있어(cmd_parse 주석 참고), 출력 grep + .c 파일 존재로 2중 판정.
-    let has_perr = exec("printf '%s' \"" + r1 + "\" | grep -q 'Parse error' && printf yes || printf no")
+    // SAFETY: do NOT shell-interpolate r1 — parser diagnostics contain
+    // backticks (e.g. `fn main()`, `@manual_main`) which would re-trigger
+    // shell command substitution. Use pure-hexa contains() instead.
+    let has_perr = if r1.contains("Parse error") { "yes" } else { "no" }
     if has_perr == "yes" {
         println("error: transpile failed (parse error) — " + src)
         exit(1)
```

Surface scan: `grep -n 'exec(".*" + r1 + "' self/main.hexa` → only this one
hit. Other `exec()` call sites do not interpolate parser output.

## Validation

After patching anima-physics entries (added `@manual_main` annotation,
arduino/cloud_facade_poc) the transpile + run cleanly:

```
$ hexa run arduino/cloud_facade_poc.hexa
... 4 G-gate checks run, marker.json emitted, exit 0
```

The diagnostic-rendering path is harder to test locally without reverting
the user file annotation, but the patch is the minimum change to render
backticked parser output as literal text.

## Related

- Parser hard-fail itself is CORRECT (silent-failure enforcement Class 1,
  parser.hexa:599-644). Only the wrapper-side diag rendering is buggy.
- Same anti-pattern (unsafe shell interpolation of upstream tool output)
  may exist in `tool/build_native.hexa` / `tool/cross_compile_linux.hexa` —
  not audited this cycle.

## Cross-ref

- `anima-physics/README.md` § 6 cheat sheet, § 8 next-action — 22-entry
  re-verify produced 11 PASS / 11 FAIL initially; (A) class = this bug,
  (B) class = `&engine` address-of drift (separate inbox note).
- anima-physics commits: a8be95335 (patched 8 files with @manual_main).
