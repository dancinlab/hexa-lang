# incoming patch: hexa-run-clang-fork-cache-miss-per-invocation

> **id**: `hexa-run-clang-fork-cache-miss-per-invocation` · **opened**: 2026-05-23 KST PM · **status**: `fixed — self/main.hexa cmd_run_user_direct + cmd_run now key the cache on sha256_file(source)+version_str(); identical sources reuse the linked binary and skip the clang fork. Build step renames .tmp.<ns> → final atomically; concurrent rebuilds race benignly (byte-identical output). Requires hexa rebuild to take effect.`
> **observed**: 2026-05-23 14:18 KST PM (Mac, Apple Silicon, macOS 26.5)
> **trees**: probably `self/runtime/hexa_run.hexa` or wherever `hexa_run.<ns>` cache directory is named
> **impact**: macOS system load amplification — repeated `hexa run` (slash-command CLIs, sidecar plugin verbs, agent driver loops) saturates XprotectService + syspolicyd with fork/exec events. Confirmed CPU profile shows 2× `clang -cc1` at 20–25% each whenever multiple `hexa run` invocations overlap.

---

## 1. Symptom

Running the *exact same* `.hexa` source three times in a row produces three full clang compile rounds (~400 ms each), instead of a sub-50 ms cache hit on runs 2 and 3.

```
$ cat /tmp/test_cache.hexa
fn main():
  println("hi")

$ for i in 1 2 3; do
    START=$(date +%s%N)
    hexa run /tmp/test_cache.hexa >/dev/null 2>&1
    END=$(date +%s%N)
    echo "run $i: $((($END-$START)/1000000))ms"
  done
run 1: 380ms
run 2: 444ms
run 3: 429ms
```

Each call leaves a brand-new `~/.hexa-cache/hexa_run.<ns_epoch>` entry:

```
$ ls -t ~/.hexa-cache/ | head -5
hexa_run.1779513636430629000.tmp.91910
hexa_run.1779513635900742000
hexa_run.1779513634362480000
hexa_run.1779513633382258000
hexa_run.1779513633389137000
```

The trailing 19-digit number is `clock_gettime` ns epoch — unique per invocation by construction, so the cache key never collides with the previous run even when the source byte-content is identical.

## 2. Why it matters at the system level

On Mac, `clang -cc1` fork shows up in `ps aux` as a 20–25 % CPU process every time `hexa run` runs. When several agent loops or slash-commands invoke `hexa run` in parallel:

```
fork/exec storm (clang -cc1 × N, hexa parser × N)
   ├─→ XprotectService   (yara eval per exec)   →  ~70 % CPU
   ├─→ syspolicyd        (codesign per exec)    →  ~12 % CPU
   └─→ Mullvad eslogger  (ESF subscriber, fork) →  ~18 % CPU when split-tunnel on
```

Measured on a Mac with 6 concurrent Claude sessions driving sidecar `/cloud`, `/inbox`, `/domain`, `/imagine`, `/paper`, `/research:yt` slash-commands (all of which shell to `hexa run`). Switching the cache key from `<ns_epoch>` to a content hash would let runs 2-N of identical sources return without forking clang, which should collapse the `XprotectService` / `syspolicyd` load to near-idle.

Reference cross-link: [[airgenome/HUSH.md]] (consumer-side mitigation log; documents the system-level effect).

## 3. Proposed fix sketch

Replace the timestamp-based suffix with a content-addressed key:

```
key  = sha256(canonicalized_source ++ hexa_version ++ target_triple ++ link_libs)
dir  = ~/.hexa-cache/hexa_run.<key[:16]>
```

- **cache hit**: dir exists with a successfully-linked binary → skip clang, exec it
- **cache miss**: build into `hexa_run.<key[:16]>.tmp.<pid>` then atomic-rename → handles concurrent rebuilds without TOCTOU
- **GC**: optional LRU sweep (e.g. cap `~/.hexa-cache/hexa_run.*` to 256 entries or 2 GB by mtime)

The current `.tmp.<pid>` suffix on the in-flight directory already shows the atomic-rename pattern is in place — only the durable key needs to change.

Variables that *must* contribute to the cache key (otherwise stale binaries get exec'd):

- the .hexa source content (after `--include` / module resolution)
- compiler version (`hexa --version`)
- linker version (`clang --version`)
- target triple (`arm64-apple-macosx<sdk>`)
- HEXA_HAS_LIBSODIUM / HEXA_HAS_OPENSSL feature flags
- any `-D` macros from `hexa run` flags

Anything that *doesn't* change runtime behavior (e.g. wall-clock time, pid, tempdir name) must **not** contribute.

## 4. Compat & migration

- The cache directory layout doesn't appear on any external API surface; renaming the suffix scheme is internal.
- Older `hexa_run.<ns_epoch>` directories can be left to expire via the GC sweep, or one-shot wiped on the first run after the version that introduces content-addressing (cheap, since they're regeneratable).

## 5. Reference numbers from the consumer side

System on 2026-05-23 14:18 KST PM, mid-incident:

| process | %CPU | role |
|---|---|---|
| `XprotectService` | 70 | yara eval per exec |
| `WindowServer` | 50 | active work display refresh |
| `clang -cc1` × 2 | 25 + 20 | `hexa run` C → object |
| `syspolicyd` | 12 | codesign verify per exec |
| load average (1m) | **82.81** | overall amplification |

After the proposed fix, runs 2-N of an identical slash-command should return in <50 ms with no clang fork — XprotectService / syspolicyd should drop to <5 % on their own.

## 6. Out of scope

- Reducing the *first*-run cost (would need a different angle: precompiled hexa stdlib, persistent runtime daemon, AOT bundling).
- Whatever incident triggered XprotectService specifically — that's an OS-side gating decision; the patch only removes the *unnecessary* exec storm.
