# `hexa cloud run`: argv guard false-positives on legitimate shell redirects inside `bash -lc '…'`

> **Status:** already-resolved-in-source (2026-05-23) — `cloud_lint_argv` (`stdlib/cloud/cloud.hexa:204`) only flags C-style `/* */` comment fragments + embedded newlines; it does NOT scan for `#`, `//`, or shell redirects. All four campaign repro payloads verified hit=0 against the current guard logic (`ls -la /tmp 2>/dev/null` · `pkill -f pw.x 2>/dev/null; …` · `cd /workspace && ./reset.sh >reset.log 2>&1` · `cat /proc/cpuinfo | grep … # quick probe`), while a genuine `/* misplaced note */` correctly still hits. The demiurge false-positives were against a stale deployed `hexa` binary carrying the older broad guard — resolution is a fresh deploy, no further source change.

**Reporter**: demiurge (`dancinlab/demiurge` RTSC DFT campaign, 2026-05-23)
**Severity**: medium (workaround exists — write a local script, scp + run — but the workaround is itself a g11 violation: paper-over instead of fix-at-source)
**Affected**: `stdlib/cloud/cloud_cli.hexa` — the argv pre-flight guard that scans positional args for "looks like a misplaced shell comment" patterns. Hit on every diagnostic / kill / reset command during the 2026-05-23 RTSC dispatch.

## Problem statement

`hexa cloud run <host> -- bash -lc '<cmd>'` packages `<cmd>` as a single argv entry. The argv guard's intent is good — catch the common mistake of pasting a `# comment` fragment into the argv stream where it would be silently dropped by the shell. But the guard fires on any `<cmd>` that contains:

- shell redirects: `2>/dev/null`, `1>&2`, `&>log`, `< input.txt`
- `#`-prefixed substrings that are **inside** the single-quoted bash payload (legitimate shell comments)
- `//` substrings (e.g. paths like `//tmp/file`, accidental — but also legitimate)

These are all **legitimate shell content** inside a `bash -lc '…'` payload — the outer argv guard has no business inspecting the inside of a quoted shell string.

## Repro (minimal, 2026-05-23)

```
$ hexa cloud run root@<host> --port 12345 --insecure -- bash -lc 'ls -la /tmp 2>/dev/null'
hexa cloud: argv[2] looks like a C-style comment fragment — shell comments
are `#`; this is almost certainly a misplaced note. refusing to dispatch.
$ echo $?
1
```

The command is valid bash; the redirect is to suppress noisy `Permission denied` lines on hidden files. Same false-positive on:

```
hexa cloud run host … -- bash -lc 'pkill -f pw.x 2>/dev/null; sleep 1; pgrep -af pw.x || echo clear'
hexa cloud run host … -- bash -lc 'cd /workspace && ./reset.sh >reset.log 2>&1'
hexa cloud run host … -- bash -lc 'cat /proc/cpuinfo | grep "^cpu MHz" | head -1  # quick probe'
```

Every diagnostic / kill / reset command in the campaign tripped this.

## Workaround we used (and why it's a g11 violation)

```bash
# write the real command to a local file
cat > /tmp/diag.sh <<'EOF'
#!/bin/bash
pkill -f pw.x 2>/dev/null
sleep 1
pgrep -af pw.x || echo clear
EOF

# scp it, then run it
hexa cloud copy-to host /tmp/diag.sh /tmp/diag.sh
hexa cloud run host -- bash /tmp/diag.sh
```

Three SSH round-trips instead of one, plus a temp file on both sides, **just to evade a guard whose intent is satisfied** (the redirect is legitimate, not a misplaced shell comment). This is "workaround in caller" rather than "fix in producer" — exactly the pattern commons `@D g11` forbids ("no gap workarounds — fix at source").

## Root cause

The argv guard inspects each positional arg as if it were a top-level shell token, without considering that the arg may itself be an opaque payload (the `<cmd>` after `bash -lc`). Once the argv shape is `[…, "bash", "-lc", "<arbitrary shell program>"]`, the third arg is *by contract* not inspectable from the outside.

The guard is correctly catching:

```
hexa cloud run host -- ls -la // this lists the root dir   ← genuine misplaced comment
                            ^^                              ← argv[3] = "//" — looks like a comment
```

but it should *not* catch:

```
hexa cloud run host -- bash -lc 'ls -la 2>/dev/null'        ← legitimate redirect inside quoted payload
                                        ^^^^^^^^^^^         ← inside argv[3], not a separate arg
```

## Suggested fix (design only — demiurge does not edit hexa-lang)

Three options ordered by surgical-ness:

**(1) Context-aware guard suppression — `bash -lc` / `sh -c` / `-c` shape detection**

When the guard sees `argv` of shape `[…, "bash", "-lc", X]` or `[…, "sh", "-c", X]` or any `["-c", X]` pair, treat `X` as opaque and skip the guard on it. The user has explicitly said "this is a shell program, not a shell token sequence" — the producer should respect that contract.

```hexa
// stdlib/cloud/cloud_cli.hexa — sketch
fn argv_guard(args: [str]) -> Result<unit, str> {
    let mut i = 0
    while i < len(args) {
        let a = args[i]
        // skip the payload of bash -lc / sh -c
        if (a == "-c" || a == "-lc") && i + 1 < len(args) {
            i = i + 2  // skip the next arg, it's opaque shell program
            continue
        }
        if looks_like_misplaced_comment(a) {
            return Err("argv[" + to_string(i) + "] looks like a C-style comment fragment …")
        }
        i = i + 1
    }
    return Ok(())
}
```

**(2) Whitelist common shell redirect patterns**

Even outside `-c` context, the guard could whitelist `2>/dev/null`, `1>&2`, `&>`, `2>&1`, `>` <path>, `< path`, etc. — these are unambiguously shell redirects, not misplaced comments. Cheap to implement; doesn't require shape detection.

**(3) `--unsafe-argv` / `--no-argv-guard` opt-out flag**

The escape hatch. Caller scripts that know they're sending legitimate complex shell programs can pass `--no-argv-guard` and accept the responsibility. Combined with (1) this is rarely needed, but it removes the "I literally cannot dispatch this command" failure mode entirely.

**Recommended combo**: (1) + (3). (1) handles the 95% case automatically; (3) is the escape hatch for the long tail. (2) is unnecessary if (1) lands.

## Impact / cost

- Every diagnostic / kill / reset / log-tail command during 2026-05-23 RTSC campaign required the scp-script workaround. Estimated ~15-20 of those, each costing ~3 extra SSH round-trips and a temp file on local and remote.
- The workaround pattern is **easy to forget and harder to undo** — once a campaign script has the `scp + run script.sh` shape baked in, it stays there even after the guard is fixed, polluting the codebase.
- g11 violation pressure: each workaround is a "paper-over downstream" rather than "fix at source". Filing here is the g11-compliant alternative.

## honest C3

- The guard's *intent* is correct — misplaced shell-comment fragments in argv are a real bug class (we've seen it elsewhere). The fix is to make the guard **context-aware**, not to remove it.
- The opt-out flag (option 3) alone is the minimum-viable fix; option (1) is the proper fix. Both are low-risk: option (1) is a 4-line shape check at the top of the guard loop, option (3) is a flag-passing change.
- Demiurge's worktree contains the workaround scp-scripts from today's campaign — once this lands, those should be re-collapsed back to inline `bash -lc '…'` form to remove the g11-violation residue.
- demiurge never edits hexa-lang source — this file lives in `inbox/patches/` per upstream-downstream invariant (commons `@D g11` — file the gap, fix at source).

## Cross-link

- `dancinlab/demiurge` 2026-05-23 RTSC DFT campaign — diagnostic dispatch scripts (the workaround-script residue lives in demiurge/scripts/dft/)
- `dancinlab/hexa-lang` `inbox/patches/cloud-cli-operational-improvements-anima-2026-05-20.md` — sibling consolidation; could absorb this as **P13 — argv guard context-aware for `bash -lc`**
- `dancinlab/hexa-lang` commons `@D g11` (no gap workarounds — fix at source) — the rule that motivates filing this rather than carrying the scp-script workaround silently
