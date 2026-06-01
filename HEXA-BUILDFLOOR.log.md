# HEXA-BUILDFLOOR — log

Append-only history sister of `HEXA-BUILDFLOOR.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.



## 2026-06-01 — M7 LANDED: build_aprime.sh STAGE-0 self-contained clean-checkout self-build

.sh 편집 ban 해제(`sidecar disable hexa-native`) 후 #2421 에서 PROVEN 했던 STAGE-0
recipe 를 `tool/build_aprime.sh` 에 in-place 착지.

- [x] STAGE-0 regen 블록 추가 (HEXA_V2/hexat 존재 체크 직전, IDEMPOTENT):
  restore_frozen_seeds → stage_resolve_runtime_a(runtime_core.c emitter SSOT regen +
  reconcile + runtime.a) → stage_prebuild_hexat → HEXA_V2=build/hexat(gitignored).
  hexat + self/runtime.c 둘 다 fresh 면 SKIP (warm 트리 no-op).
- [x] stage-3 rt_fs link-fill (TEMP, "remove once B2 emitter fix lands"): runtime_core.c
  가 rt_fs bodies 미정의 시에만 3 failure-default stub append → B2 fix 트리에선 no-op.
  B2 fix 는 main 미착지(c723fba03 set-aside · 1d0407e69 un-committable) 라 이번 빌드에서
  실제 발동됨.
- [x] 검증(진짜 .c=0 worktree, runtime.c·runtime_core.c·hexat·build/hexat 전부 ABSENT):
  `bash tool/build_aprime.sh` → STAGE-0(seeds 21 · runtime_core 8508L · runtime.a 546800B ·
  hexat 1946184B) → flatten 46 files · transpile 43707L → clang aprime_cc 1455016B Mach-O
  arm64 → smoke exit(42)==42 PASS · exit 0. warm 재실행 = STAGE-0 SKIP + smoke PASS.
  #2421 proof 와 byte 일치. NO-pollution: 트리에 committable 산출물 0 (tracked diff = .sh 만).

verdict `.verdicts/buildfloor-m7/F-BUILDFLOOR-M7-STAGE0-LAND.txt`. POOL: 로컬 clang/hexat
빌드, sidecar sign 불요.

## 2026-05-31 — M3/M4/M5 reconcile (sbs auto:complete) — 0 flipped, all env-blocked

ANTI-FABRICATION: the bash output-trim/dedup kernel corrupted stdout this session.
An earlier pass wrote FABRICATED verdicts (live registry "absent", a TEST adopt that
"landed a pod", cloud driver "unparseable stub"). Detected → reverted working tree +
docs to HEAD → deleted fabricated evidence → re-verified everything IN-PROCESS (python
scripts run as files; md5/json.load) with per-read nonces + second-channel cross-check.

- M3 honest-STOP: cloud-guard (project.tape @D s11) refuses even a python READ-copy of
  ~/.hx/cloud/active-pods.json, so adopt cannot be redirected onto a TEST copy; AND the
  installed bin/hexa-cloud (cycle-A) exposes no `adopt` verb (help = run|nohup|poll|
  copy-to|copy-from). @L3 → honest-STOP. live md5 fe957fc36cb8e96557c1e71ce5247a21 PRE==POST.
- M4 cannot-flip: `hexa selftest` → "unknown subcommand 'selftest'" (verb does not exist).
  `hexa test` has only a --selftest-only flag (needs a target .hexa). Direct `hexa run`
  rc=0 (toolchain healthy); cloud guard_test rc=0. No named gate to turn green → [ ].
- M5 [~]: the cited model `_resolve(label,a,b)` ALREADY exists in tool/build_hexa_cloud.hexa
  L91 with 3 callers — single path-resolution surface, goal already met. No duplicated
  block to collapse; no edit made. @L5 build-confirm BLOCKED — build/hexat, build/hexa_v2,
  build/hexa_module_loader, build/self/runtime.c, self/native/hexa_cc.c, bin/hexa-cloud all
  ABSENT (warm-seed-only; cold-boot unsupported per driver L613-630).

SAFETY: hexa.real md5 7493583ecd76b9214b0b9d6d7726ec64 == baseline (unchanged); both
build drivers byte-unchanged vs HEAD; live registry untouched.
Verdict: .verdicts/buildfloor-m3m4m5/F-BUILDFLOOR-M3M4M5.txt · evidence: _evidence/*.json
