---
schema: hexa-lang/stdlib/semver/ai-native/1
last_updated: 2026-05-11
module: stdlib/semver.hexa
depends_on: (none — pure stdlib, imports nothing)
status: preview
since: 2026-05-11
driver: wilson session — core/loader.hexa loader_validate (f) requires_host semver range, (g) dep version constraints
selftest: stdlib/test/test_semver.hexa — 110/110 PASS (interp, macOS arm64)
---

# stdlib/semver (AI-native)

SemVer 2.0.0 version parsing, precedence comparison, and npm-style range
satisfaction. **Pure** — no exec, no fs, no network. Self-contained (no
stdlib imports).

## TL;DR

- `semver_parse(s) -> map` — `#{ "ok", "major", "minor", "patch", "prerelease", "build" }`. Optional leading `v`. Malformed → `ok=false` + zeros. Build metadata parsed but **ignored for precedence** (spec §10). A bare `1.2` / `1` is **not** a valid *version* (`ok=false`) — only `X.Y.Z`. (Partials *are* accepted inside *ranges* — see `semver_satisfies`.)
- `semver_valid(s) -> bool` — `= semver_parse(s)["ok"]`.
- `semver_compare(a, b) -> int` — `-1 / 0 / 1` by SemVer §11. Fallback: an **unparseable string sorts strictly lowest** (two unparseable strings compare equal). Never panics.
- `semver_eq / semver_gt / semver_gte / semver_lt / semver_lte (a, b) -> bool` — thin wrappers over `semver_compare`.
- `semver_satisfies(version, range) -> bool` — exact, `>=`/`>`/`<=`/`<`/`=`/`==`, caret `^`, tilde `~`, x-ranges (`1.x`, `1.2.x`, `*`, `""`), space-separated AND, `||` OR. Returns `false` (never panics) on an unparseable range/version.
- `semver_max(versions) -> string` — highest by `semver_compare`; `""` if empty. Unparseable entries lose to any parseable.
- `semver_satisfying_max(versions, range) -> string` — highest entry that satisfies `range`; `""` if none.

## API surface

```hexa
use "stdlib/semver"

pub fn semver_parse(s: string) -> map     // #{ ok, major, minor, patch, prerelease, build }
pub fn semver_valid(s: string) -> bool
pub fn semver_compare(a: string, b: string) -> int   // -1 / 0 / 1
pub fn semver_eq (a: string, b: string) -> bool
pub fn semver_gt (a: string, b: string) -> bool
pub fn semver_gte(a: string, b: string) -> bool
pub fn semver_lt (a: string, b: string) -> bool
pub fn semver_lte(a: string, b: string) -> bool
pub fn semver_satisfies(version: string, range: string) -> bool
pub fn semver_max(versions: [string]) -> string
pub fn semver_satisfying_max(versions: [string], range: string) -> string
```

## Range grammar (what `semver_satisfies` understands)

| Form | Meaning |
|------|---------|
| `1.2.3` | exact match (prerelease/build comparable) |
| `=1.2.3` / `==1.2.3` | exact (explicit) |
| `>1.2.3` `>=1.2.3` `<1.2.3` `<=1.2.3` | comparator |
| `^1.2.3` | `>=1.2.3 <2.0.0` |
| `^0.2.3` | `>=0.2.3 <0.3.0` (first non-zero element pinned) |
| `^0.0.3` | `>=0.0.3 <0.0.4` |
| `^1` / `^1.2` | `>=1.0.0 <2.0.0` / `>=1.2.0 <2.0.0` (major pinned when >0) |
| `~1.2.3` | `>=1.2.3 <1.3.0` |
| `~1.2` | `>=1.2.0 <1.3.0` |
| `~1` | `>=1.0.0 <2.0.0` |
| `1.x` / `1.X` | `>=1.0.0 <2.0.0` |
| `1.2.x` | `>=1.2.0 <1.3.0` |
| `*` / `x` / `X` / `""` | any stable version |
| `>=1.2.0 <2.0.0` | AND of space-separated comparators (all must hold) |
| `^1.0.0 \|\| ^2.0.0` | OR of `\|\|`-separated clauses (any must hold) |

## Honesty caveats (read these)

1. **Build metadata is ignored for precedence** (SemVer 2.0.0 §10). `1.0.0+a` and `1.0.0+b` compare equal; `semver_satisfies("1.0.0+a", "1.0.0")` is true.
2. **`semver_parse` rejects partials.** `"1.2"` and `"1"` give `ok=false`. Partials are only meaningful *inside ranges*. If a consumer has version strings that may be partial, normalise first (e.g. pad to `X.Y.Z`) or treat `ok=false` as "not a concrete version".
3. **Prerelease-in-range rule (chosen — npm-ish, simplified):** a version that carries a prerelease (e.g. `1.2.3-alpha`) satisfies a range **only if** some comparator bound in the range carries a prerelease on the **same `[major, minor, patch]` tuple**. Otherwise a prerelease version never satisfies a "stable" range — even if numerically in-window. `*` / `""` likewise do **not** match prereleases. A *stable* version is unaffected by this rule. (Full npm semantics also propagate prerelease-allowance across `||` clauses with shared tuples; this module does not — keep your prerelease bound in the clause that should admit it.)
4. **Unparseable input never panics.** `semver_compare` treats an unparseable string as lower than any valid version (two unparseable strings = equal). `semver_satisfies` returns `false` if *either* the version *or* the range fails to parse. `semver_max` / `semver_satisfying_max` skip non-string entries and rank unparseable strings below parseable ones.
5. **Source has no `>=` / `<=` operators** (RULES.md §1 — `<` / `>` only). Internally "a ≥ b" is `semver_compare(a,b) > -1` etc. Behaviour is unchanged; just a heads-up if you read the source.

## Typical consumer pattern (the wilson `loader_validate` shape)

```hexa
use "stdlib/semver"

// (f) requires_host semver range satisfied by host_api_version()?
if !semver_satisfies(host_api_version(), manifest_get(m, "requires_host", "*")) {
    return reject("requires_host " + manifest_get(m, "requires_host", "*") +
                  " not satisfied by host " + host_api_version())
}

// (g) per-dep version constraint
for dep in deps {
    let installed = registry_version(dep["name"])      // "" if absent
    if installed == "" { return reject("missing dep " + dep["name"]) }
    if !semver_satisfies(installed, dep["range"]) {
        return reject(dep["name"] + " " + installed + " ∉ " + dep["range"])
    }
}

// pick the newest installed build that satisfies a constraint
let best = semver_satisfying_max(installed_versions(name), wanted_range)
if best == "" { return reject("no installed " + name + " satisfies " + wanted_range) }
```

## Selftest matrix

`stdlib/test/test_semver.hexa` (110/110 PASS) covers:

| Group | Cases |
|-------|-------|
| 1 | parse: `X.Y.Z`, leading `v`, `-prerelease`, `+build`, `1.0.0-x.7.z.92`, partial-invalid (`1.2`, `1`), garbage, leading-zero, trailing-junk, `semver_valid` |
| 2 | compare: numeric chain `1.0.0 < 2.0.0 < 2.1.0 < 2.1.1`; prerelease < release; the canonical SemVer §11 chain `alpha < alpha.1 < alpha.beta < beta < beta.2 < beta.11 < rc.1 < 1.0.0` |
| 3 | build metadata ignored for precedence |
| 4 | `eq/gt/gte/lt/lte` spot checks |
| 5 | satisfies: exact, `=`/`==`, `^` (incl. `^0.x`, `^0.0.x`, `^1`, `^1.2`), `~` (incl. `~1.2`, `~1`), `>`/`<`/`<=`/`>=`, `||`, `1.x`, `1.2.x`, `*`, `""`, garbage range/version |
| 6 | prerelease-in-range rule (excluded from stable range / `*`; admitted by same-tuple prerelease bound; excluded on different tuple; stable version unaffected) |
| 7 | `semver_max` (incl. empty, with-prerelease) / `semver_satisfying_max` (incl. none) |

## See also

- `stdlib/semver.hexa` — implementation + header doc.
- `stdlib/test/test_semver.hexa` — selftest.
- `incoming/PATCHES.yaml#stdlib-semver` — the patch entry.
- https://semver.org/spec/v2.0.0.html — the spec this implements (with the caveats above).
