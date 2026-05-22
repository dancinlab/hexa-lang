# hexa cloud — host-key policy: insecure should be DEFAULT (2026-05-23)

Found while dogfooding `hexa cloud` for anima V3 fire dispatch/monitoring on
RunPod pods. 3 issues; 2 fixed in this note's companion commit, 1 remaining.

---

## Issue 1 — `--insecure` was opt-in; should be DEFAULT  ✅ FIXED

**Symptom**: `hexa cloud run root@<ip> --port <n> -- <cmd>` failed with
`[cloud] cloud_run: no exit-code marker — ssh transport failure` on a fresh
RunPod pod. The pod's SSH host key was unknown → `StrictHostKeyChecking`
blocked the first connection. Adding `--insecure` fixed it.

**Root cause / design critique**: `hexa cloud` is a *cloud-pod dispatch tool*
— its own `--help` says `--port <n>  ssh to a non-22 port (RunPod / vast.ai)`.
RunPod / vast.ai pods are **ephemeral**: a fresh host key every pod. So
`StrictHostKeyChecking` blocks the *normal* case, not the exceptional one.
Making `--insecure` an opt-in flag means every single cloud call needs it,
and forgetting it (as happened here on the first call) yields an opaque
"ssh transport failure".

For a cloud-dispatch tool, insecure host-key policy is the **correct default**;
strict checking is the rare opt-in (persistent, known hosts).

**Fix** (`stdlib/cloud/cloud_cli.hexa::_ssh_opts_cli`):
- `StrictHostKeyChecking=no` + `UserKnownHostsFile=/dev/null` now appended by
  **default**.
- New `--strict` flag opts back INTO host-key checking.
- `--insecure` accepted as a backward-compat no-op (it's the default now).
- help text updated.

verified: `hexa-cloud run root@<ip> --port <n> -- tail train.log` works with
NO connection flag → `[cloud] remote exit 0`.

---

## Issue 2 — `bin/hexa-cloud` binary stale  ✅ FIXED

**Symptom**: `bin/hexa-cloud` (built 2026-05-21, `0.1.0 — cycle A`) lacked
cycle C `preflight`. The source `stdlib/cloud/cloud_cli.hexa` (2026-05-22)
already had it.

**Fix**: `HEXA_MAC_BUILD_OK=1 bash tool/build_hexa_cloud.sh` →
`bin/hexa-cloud 0.2.0 — cycle A + B-1 + B-2 + C(preflight)`. Copied to
`~/.hx/bin/hexa-cloud`.

**Suggestion**: `tool/build_hexa_cloud.sh` should run in CI on any
`stdlib/cloud/*.hexa` change so the binary never drifts from source.

---

## Issue 3 — installed `hexa` does not route `cloud` subcommand  ⚠️ REMAINING

**Symptom**: `hexa cloud version` → `error: unknown subcommand 'cloud'`,
even after copying `hexa-cloud` to `~/.hx/bin/`.

**Root cause**: the installed `~/.hx/bin/hexa` is an older build that predates
the `sub == "cloud"` → `bin/hexa-cloud` routing in `self/main.hexa` (the
`build_hexa_cloud.sh` header references `self/main.hexa:4599` for that route).
The installed `hexa` simply doesn't have the dispatch arm.

**Workaround (current)**: invoke the sub-binary directly —
`~/.hx/bin/hexa-cloud <verb> ...` — or `hexa run stdlib/cloud/cloud_cli.hexa
<verb> ...` from a hexa-lang checkout.

**Proper fix (REMAINING)**: rebuild + reinstall the main `hexa` from a
hexa-lang checkout that has the `cloud` routing arm, OR add a thin shim.
Filed for a hexa-lang toolchain-install cycle.

---

## hexa cloud usage validated (anima V3 fire)

`hexa cloud` used to monitor 2 concurrent RunPod V3 training pods:
```
hexa-cloud run root@<ip> --port <n> -- tail -2 /workspace/p21hr/train.log
  → [P21H] step=500 CE=2.71 ... / [cloud] remote exit 0
```
cycle B `copy-from` will pull ckpt + result on completion (replacing raw scp).

Companion note: `hexa-cloud-runpod-anima-v3-saga-2026-05-22.md` (8 findings).

---

## ## Log

### 2026-05-23 — insecure-default fix + binary rebuild

anima V3 fire dogfooding. Issue 1 (insecure default) + Issue 2 (stale binary)
fixed in companion commit; Issue 3 (installed-hexa routing) remains for a
toolchain-install cycle.
