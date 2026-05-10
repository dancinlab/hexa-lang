# incoming patch: wilson-needs-hexa-build-out-of-tree

> **id**: `wilson-needs-hexa-build-out-of-tree` · **opened**: 2026-05-11 · **status**: `pending_external`
> **trees**: build driver (`hexa build` / `hexa cc` command in `compiler/main.hexa` or `self/main.hexa::cmd_build`/`cmd_run`), and the install layout (`~/.hx/bin/`)
> **priority**: ★★ — currently blocks `hexa build` of any multi-module project that lives outside the hexa-lang tree (= wilson). Workarounds exist (manual flatten + symlink) but they're fragile.

---

## Context

`wilson` (`~/core/wilson`, the new hexa-native AI coding agent) is a multi-module project — `core/{types,host,event_bus,loader,agent_loop,main,dispatch_table}.hexa` + `plugins/<id>/{plugin,main}.hexa` — that `use`s wilson-local modules (`use "core/types"`, `use "plugins/hello/plugin"`) and hexa-lang stdlib (`use "self/stdlib/anthropic_sdk"`, `use "self/stdlib/proc"`, `use "self/tui/render"`, ...). The entry is `core/main.hexa`. After the G2 binary promotion, `~/.hx/bin/hexa_real build core/main.hexa` (from `~/core/wilson`, `HEXA_LANG=~/core/hexa-lang`) hits these:

### 1. `hexa build <file>` does NOT pre-flatten `use`/`import` — only that one file is transpiled

`hexa build core/main.hexa` runs `hexa_v2 (hexa-cc) core/main.hexa build/artifacts/app.c` → `app.c` is ~26 KB and contains **only `core/main.hexa`'s code** + forward-declarations of `cfg_load` / `eb_new` / `fire_hook` / `host_*` / `loader_*` / `reg_new` / `dispatch_static_ids` etc. — the `use`d modules' bodies are NOT in it → `clang` compiles fine but `ld` fails with `Undefined symbols: _helper, _eb_new, ...`. Reproduced on a trivial 2-file program too (`use "lib"` + `fn main() { println(helper()) }` → `Undefined symbols: _helper`).

Meanwhile `hexa run x.hexa` DOES work for multi-module — because `cmd_run`'s `aot_build_slot` does a **pre-flatten step via `self/module_loader.hexa`** (the `@resolver-bypass` comment in `module_loader.hexa` documents exactly this — "invoked by aot_build_slot pre-flatten step in main.hexa::cmd_run"). `hexa_v2` (hexa-cc) is "Usage: `hexa-cc <input.hexa> <output.c>`" — one file in, one file out — so it relies on the caller having already flattened.

**Ask**: `hexa build <entry.hexa>` should mirror `hexa run`'s pipeline minus the exec — i.e. **flatten (`module_loader.hexa`) → transpile (`hexa_v2`) → clang**. Or a `--flatten` / `--project` flag, or honor `project.hexa`'s `@project(...)` as the entry-point manifest. Right now the only way to build a multi-module out-of-tree project is the manual 3-step pipeline.

### 2. `clang -I` is `<argv[0]-dir>/self` → `~/.hx/bin/self`, which doesn't exist

The transpiled `app.c` starts with `#include "runtime.c"`. `hexa build`'s clang invocation is `clang -O2 -Wno-trigraphs -fbracket-depth=4096 -I '/Users/ghost/.hx/bin/self' app.c -o ...` — i.e. the `-I` is `<dir-of-hexa_real-binary>/self`. But the installed `hexa_real` lives at `~/.hx/bin/hexa_real`, so `~/.hx/bin/self/runtime.c` → **`fatal error: 'runtime.c' file not found`**. (`runtime.c` actually lives at `$HEXA_LANG/self/runtime.c`.) **Workaround applied**: `ln -s ~/core/hexa-lang/self ~/.hx/bin/self`. **Ask**: the `-I` for the `#include "runtime.c"` should be `$HEXA_LANG/self` (the module loader already uses `$HEXA_LANG` for `self/...` resolution) or a stable install path that `hx install` populates. Related: `hexa cc <file> <out.c>` (transpile-only) also broke — it tried `clang ... self/native/hexa_cc.c -o self/native/hexa_v2` relative to the cwd ("rebuilding hexa_cc transpiler") and failed with `no such file 'self/native/hexa_cc.c'` when run from `~/core/wilson`; it should look under `$HEXA_LANG`.

### 3. (minor) `module_loader.hexa` flatten is slow on the stage0 interpreter for moderate graphs

`hexa_real self/module_loader.hexa core/main.hexa /tmp/flat.hexa` on wilson's graph (~7 core files + 6 bundled plugins × 2 files + the stdlib they `use` — maybe ~30–40 modules) ran >150s without finishing (the `module_loader.hexa` header itself warns about RSS blowup on big graphs). `hexa run`'s `aot_build_slot` presumably caches/optimizes this. A **compiled** module-flattener (or exposing `aot_build_slot`'s flatten path as a standalone `hexa flatten <in> <out>` command) would make `hexa build` of a real project fast. Not urgent if (1) is fixed in a way that's efficient.

## What unblocks (wilson side)

Once `hexa build core/main.hexa` (or `hexa build` reading `project.hexa`) does flatten→transpile→clang automatically and finds `runtime.c`: wilson's build loop becomes a single command, and `wilson --version` / `wilson` REPL / `wilson -p "..."` are reachable. Until then wilson uses the manual `module_loader.hexa` → `hexa_v2` → `clang -I $HEXA_LANG/self` pipeline. Reference: `~/core/wilson/docs/build-fix-checklist.md` §C.

(Other wilson-side build fixes already applied directly, not hexa-lang asks: `handle` is a reserved word → renamed locals; entry module C-emitted before deps so cross-module struct constructors aren't forward-declared → use a `pub fn ..._new(...)` helper; `main(argv)` → `main()` + `args()`; `json_to_string` is a wilson alias over the `json_stringify` builtin; etc. — all in `~/core/wilson/docs/build-fix-checklist.md`.)
