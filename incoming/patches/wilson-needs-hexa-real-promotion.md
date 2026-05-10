# incoming patch: wilson-needs-hexa-real-promotion

> **id**: `wilson-needs-hexa-real-promotion` · **opened**: 2026-05-10 · **status**: `pending_external`
> **trees**: build artifacts (`~/.hx/bin/hexa_real`, `~/.hx/packages/hexa/hexa.real`) — no source-tree change needed unless the rebuild itself surfaces a bug.
> **why**: G2 source landed (`9210e024 feat(codegen+stdlib): RFC-022 G2 async integration — wilson gate FINAL CLEAR`; RFC-022 status "Integrated") — but the **deployed interpreter binary doesn't reflect it yet**, so wilson can't compile-verify its `core/` + `plugins/` scaffolds. This is the *last* concrete blocker for wilson P1 verification (G1✅ + G2✅-source + G3✅ — gate is source-clear, runtime-binary not).

---

## Observed state (2026-05-10, from a wilson session via `ssh mac`)

- `~/.hx/bin/hexa_real` — still the **5월 2 build** (1,580,720 bytes). `hexa_real run` on `async fn`/`await` → `Parse error: unexpected token Await`. `hexa_real run self/test_async_codegen.hexa` → **0/4 PASS** (all `got=void`). i.e. the parser/interp `AwaitExpr` work from `9210e024` (`self/{parser,hexa_full}.hexa`) is **not in this binary**.
- `~/.hx/packages/hexa/hexa.real` — churning: seen at 2.9 MB (5월10 18:58), 2.96 MB (21:51), and 401 KB (22:37); `~/.hx/packages/hexa/hexa.real.bak.1778419304` (2.96 MB, 22:21). The 22:37 build **hung / timed out** when running `self/test_async_codegen.hexa` (likely the stage-1 OOM class — cf. `86afadb0 doc: stage 1 punch list v2 — host OOM dominates`, `a0f5cd5d fix(self/runtime+stage0): per-phase arena reset`). So whatever's currently at `~/.hx/packages/hexa/hexa.real` is **not stable enough to promote**.
- Net: the only `hexa_real` that runs reliably is the one without G2; the one with G2 either doesn't exist as a stable binary yet, or OOMs/hangs.

## Ask

1. **Rebuild `hexa_real` (stage0 self-host)** from current `self/hexa_full.hexa` + `self/parser.hexa` + `self/native/hexa_cc.c` so the deployed binary has the `AwaitExpr` parse + `NK_AWAIT_EXPR` interp + `hexa_await_unwrap` runtime branches. (`9210e024` commit msg: "self/native/hexa_cc.c is SSOT for deployed binary — manual slot+IC additions ensured rebuild path picks up new branches" — so the rebuild path should pick them up.)
2. **Stabilize the OOM/hang** on the rebuilt binary enough that `hexa_real run self/test_async_codegen.hexa` completes and reports **4/4 PASS** (interp path), and `hexa build self/test_async_codegen.hexa && ./<out>` reports **4/4 PASS** (native AOT path). (If the per-phase-arena-reset mitigation from `a0f5cd5d` isn't enough for this workload, that's the actual remaining work — file it under your stage-1 punch list.)
3. **Promote**: install the stable rebuilt binary as `~/.hx/bin/hexa_real` (the one most tooling + the `~/.hx/bin/hexa` shim's `*` case + `bin/hexa-r mac` use). Keep a `.bak.<ts>` of the prior one (you've been doing this).
4. **Confirm** (and reply on this patch / append to `incoming/manifest_log.jsonl`): `~/.hx/bin/hexa_real run self/test_async_codegen.hexa` → 4/4, and `cc`/`build` of a trivial `async fn`/`await` program succeeds.

## Once done — what unblocks (wilson side, not yours)

- wilson P1 compile-verify: `ssh mac '... ~/.hx/bin/hexa_real cc core/*.hexa plugins/*/*.hexa'` no longer needs the "exit codes unreliable / use the May-2 binary" caveat.
- wilson whole-program `hexa build` of `core/main.hexa` + `plugins/_bundle` once the `core/dispatch_table.hexa` wiring + the bundled `plugins/*` are complete (wilson is doing that in parallel).

(Reference: `~/core/wilson/docs/hexa-lang-gap-audit.md` §업데이트(d), `~/core/wilson/docs/ROADMAP.md` P0 / open-decision #5.)
