# incoming patch: stdout-4095-byte-truncation-runtime-cap — `hexa run` stdout is hard-capped at 4095 bytes / fire

> **id**: `stdout-4095-byte-truncation-runtime-cap` · **opened**: 2026-05-23 KST · **status**: `fixed — self/runtime.c::hxlcl_vfprintf_fd reformats on the heap via va_copy + malloc when the formatted output exceeds the 4096-byte stack buffer. Verified: println of 7000-x string emits 7001 bytes (was 4095). Resolution path (a) from §4 — the source fix existed at 1dad118d but had not propagated to main; this PR cherry-picks it.`
> **trees**: `self/runtime.c` (`hxlcl_vfprintf_fd` — single function patched)
> **source**: downstream `sidecar` (`~/core/sidecar`, `hooks/commons/bin/_commons.hexa`). The hook emits a Claude Code `hookSpecificOutput` JSON whose `additionalContext` is `commons.tape` (~7 KB) — visible in every SessionStart / UserPromptSubmit / PreCompact / PostCompact firing.
> **observed**: 2026-05-23 · `hexa --version` → `hexa 0.1.0-dispatch`
> **severity**: medium — silent truncation. Downstream payloads beyond 4095 bytes are dropped without error; the consumer sees a clean parse of the truncated prefix and never knows the tail existed. Affects every `hexa run` script that emits structured output larger than 4 KB on stdout.

---

## 1. Failure (verbatim)

```
$ echo '{"hook_event_name":"SessionStart"}' | \
    CLAUDE_PLUGIN_ROOT=…/hooks/commons \
    hexa run …/hooks/commons/bin/_commons.hexa | wc -c
4095
```

`commons.tape` alone is ~7 KB; the JSON-escaped wrapper makes the intended output ~7.3 KB. The actual stdout is exactly **4095 bytes**, regardless of input size.

The truncated tail in the sidecar case: `commons.tape` `@D g18..g35` (rules covering bypass, granular tape form, no-hardcoding, no-workaround, version discipline, slash-command roster, real-limits-first, lattice-as-tool, ship cycle, credentials, CHANGELOG, no-self-authored-bypass, EPERM diagnosis, think-before-coding, simplicity-first, surgical-changes, goal-driven-execution) — silently never reaches the Claude Code session context. The model sees only g1..g17 (partial g18) and assumes that is the full layer.

## 2. Repro — minimal

```hexa
// /tmp/_chunk_test.hexa
fn main() {
    let mut s = ""
    let mut i = 0
    while i < 7000 { s = s + "x"; i = i + 1 }
    println(s)
}
```

```
$ hexa run /tmp/_chunk_test.hexa | wc -c
4095
```

After the fix:

```
$ hexa run /tmp/_chunk_test.hexa | wc -c
7001
```

## 3. Root cause

`hxlcl_vfprintf_fd` formatted into a fixed `char buf[4096]` and clamped the write length to `sizeof(buf) - 1 = 4095`. Any formatted output exceeding 4096 bytes was silently truncated at write time.

## 4. Fix

`hxlcl_vfprintf_fd` now va_copies the args, vsnprintf-probes for the formatted length, and (when the length exceeds the stack buffer) mallocs an exact-size heap buffer, re-renders, writes in full, then frees. The fast path (output ≤ 4095 bytes) is unchanged. On malloc failure, falls back to writing the truncated stack buffer (defensive).

## 5. Operational note

The bug silently truncated production hook output for ≥ 1 day before discovery. Any sidecar hook emitting > 4 KB structured payloads should be re-audited after the fix lands on the user's installed `hexa.real`.
