# json_parse: `\uXXXX` raw-passthrough → non-conformant strings (compiled)

> **VERIFIED-CLOSED 2026-05-20** — `_jp_parse_string` in `self/runtime.c` L7686 has the documented `\uXXXX` 6-byte passthrough (comment L7710 explicitly notes the round-trip-lossless contract). Close-only marker.

- **kind:** patch
- **status:** resolved-ssot (re-applied 2026-05-20 after deploy-regen wipe; original land 472646dc 2026-05-16, prior land c7224be9 2026-05-05)
- **source_files:** `self/runtime.c` (`_jp_parse_string`, ~L7708)
- **from:** wilson (`dancinlab/wilson`) — surfaced via `provider-openai-compat`
- **date:** 2026-05-16

## Resolution log (2026-05-20)

Worktree `s1-step2-codegen-perf` HEAD had the raw passthrough back —
`self/runtime.c::_jp_parse_string` `case 'u':` was the literal-6-byte
copy again, despite two prior fix commits:

- `c7224be9` 2026-05-05 — first land (uXXXX decode + slice polymorphism).
- `472646dc` 2026-05-16 — re-applied identically (commit body cites this
  same inbox markdown).

Between those commits and the current worktree HEAD, deploy-regen-style
commits (`b9d1da27 deploy(R7): runtime.c sync` ·
`cff366ae feat(forge): sync runtime.c to RFC 040` ·
`4fb439fc feat(rfc-061-P1): runtime 2-layer split` ·
`26a785af feat(rfc-062): argv[0] dedup`) re-touched `self/runtime.c`
and the `case 'u':` body fell back to raw passthrough. This is the
same SSOT-wipe-by-regen hazard called out in
`@D g_inbox_processing_loop` hazard-guard (c) for `codegen_c2.hexa`,
materialised here for `runtime.c`.

Re-applied the identical `472646dc` body (4-hex → code-point, UTF-16
surrogate-pair recombination for D800-DBFF + DC00-DFFF, 1-4 byte UTF-8
encode). `clang -fsyntax-only self/runtime.c` exits 0. No other lines
changed; behaviour matches the prior two lands.

Binary promote is the next standard deploy step (out of scope per
`@D g_inbox_processing_loop` step 7).

## Symptom

Compiled `json_parse("…\\uc548\\ub155…")` returns the **literal 6 bytes**
`안` instead of the decoded character `안`. The `hexa run`
interpreter / `self/stdlib/json.hexa` path decodes correctly (its self-test
`json_parse_safe("{\"name\":\"caf\\u00e9\"}")` expects `café`), so this is
an **interpreter ↔ compiled divergence**: only the compiled C runtime is
wrong.

Downstream impact (wilson): mlx_lm.server serializes streaming SSE chunks
with `json.dumps(ensure_ascii=True)` (its non-stream path uses
`ensure_ascii=False`), so every non-ASCII char arrives `\uXXXX`-escaped.
`provider-openai-compat` → `json_parse` → the TUI then showed
`안녕 👋` instead of `안녕 👋` for any
CJK / emoji reply from a local OpenAI-compatible model.

## Root cause

`self/runtime.c::_jp_parse_string`, `case 'u':` is an explicit
**raw passthrough**:

```c
case 'u':
    // Raw passthrough (no unicode expansion) — write literal
    // \uXXXX as the 6 bytes so round-trip is lossless.
    if (*pi + 5 < n) { memcpy(buf + len, s + *pi, 6); len += 6; *pi += 6; continue; }
```

This is non-conformant: RFC 8259 §7 requires `\uXXXX` to be decoded to the
corresponding Unicode scalar (with UTF-16 surrogate-pair recombination for
astral code points). Every other escape (`\n \t \" \\ …`) is decoded; only
`\u` is passed through.

## Round-trip note (the cited rationale)

The "lossless round-trip" goal is already moot for the general parser:
`_js_emit_string` (json_stringify) emits bytes ≥ 0x20 **as-is** (UTF-8, no
re-escaping — only controls < 0x20 become `\u00xx`). So a decoded string
re-serializes as raw UTF-8, which is valid JSON and the conventional
behavior. The only change is `"é"` now round-trips to `é`
(UTF-8) rather than the literal `é` — i.e. standard JSON semantics.
(If a byte-identical tokenizer.json reader is needed, `self/native/hxtok.c`
already has its own `json_unescape` and is unaffected.)

## Fix (attached, applied)

Replace the `case 'u':` raw-passthrough with proper decoding:
parse 4 hex → code point; if it is a high surrogate (D800–DBFF) followed by
`\uXXXX` low surrogate (DC00–DFFF), recombine to the astral scalar; UTF-8
encode (1–4 bytes) into the output buffer. Reference UTF-8 encoder pattern
already exists at `self/runtime.c:~7804`.

## Verification

- `hexa build` a probe: `json_parse("{\"t\":\"\\uc548\\ub155\\ud83d\\ude0a\"}")`
  → `t == "안녕😊"` (compiled, not just interpreter).
- wilson `ws -U -p "안녕"` → renders Hangul + emoji correctly with the
  provider-side workaround REMOVED (proves the upstream fix is sufficient).
