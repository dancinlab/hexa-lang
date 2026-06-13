# Self-host re-promote recipe — close the deployed front-end residual

**Status:** ✅ VERIFIED 0-pod that a current-source rebuild closes the deployed
OP-124 residual (see `.verdicts/hexa-0pod/F-OP126-SELFHOST-REPROMOTE-VERIFY.txt`).
This doc is the **turnkey promote + rollback** a user/build-host runs to make the
fix live in `hexa run`. The default flip is a **user-gated decision** — OP-126
proved the rebuild works but deliberately did NOT flip the default.

**Scope note:** this is the **deployed-toolchain** re-promote (what `hexa run`
uses on your machine). The **CI frozen-seed** re-pin (`FROZEN_SEED_REF`) is a
*separate* build-host job — see `docs/selfhost-next-constfold-promote.md`.

---

## 0. Why the residual exists (the dispatch topology)

`hexa run X` does NOT go through the self-hosted `gen3`. Measured on `~/.hx/bin`:

```
hexa            -> exec hexa.real
hexa.real       -> symlink -> hx-selfhost-cli          (tier2 flip)
hx-selfhost-cli : carries --emit=<x> -> gen3  (compile surface only)
                  EVERYTHING else      -> DELEGATE to hexa.real.pre-selfhost.<ts>
                                          (the shipped dispatch binary)
```

`run` carries no `--emit`, so it **delegates to the shipped dispatch binary**
(a prebuilt release tarball installed by `install.sh`, currently the Jun-7 build).
That binary pre-dates the OP-37/OP-40 codegen fixes and #1747 → both bugs survive
end-to-end even though current SOURCE is fixed and `gen3 --emit` is fixed.

**Two ways to close it** (pick one):
- **(A) Refresh the dispatch binary** from current source — closes `run`/all
  subcommands. This is the full fix.
- **(B) Route `run` to a current-source compiler** in `hx-selfhost-cli` — narrower.

This recipe documents **(A)** via the canonical self-host promote, which produces a
current-source `gen3` + dispatch and is the path the gates validate.

---

## 1. 0-pod fast PROOF build (what OP-126 ran — ~32 s, local CPU)

Proves current source closes the residual WITHOUT the 3.5h ladder. Scratch only.

```bash
cd <repo>                                  # holds compiler/main.hexa
W="$PWD/build/op126-scratch"; mkdir -p "$W"

# (1) restore frozen bootstrap seeds (hexa_cc.c + runtime.c; gitignored)
bash tool/restore_frozen_seeds

# (2) build hexat — ROT WORKAROUND: build_selfhost.sh omits runtime.c here, so its
#     clang link fails `Undefined symbols … ___hexa_last_error`. Compile BOTH in 1 TU:
clang -O2 -arch arm64 -std=gnu11 -D_GNU_SOURCE -D_DARWIN_C_SOURCE -Wno-trigraphs \
      -I self -I . self/native/hexa_cc.c self/runtime.c -o build/hexat -lm

# (3) build aprime_cc (native compiler) from CURRENT compiler/main.hexa via hexat
bash tool/build_aprime.sh -r "$PWD" -o "$W/aprime_cc" -v "$PWD/build/hexat"

# (4) runtime object for linking the repros
clang -c -O2 -arch arm64 -std=gnu11 -D_GNU_SOURCE -D_DARWIN_C_SOURCE -Wno-trigraphs \
      -I self -I . self/runtime.c -o "$W/rt.o"

# (5a) BUG-1 proof: 1-2+10 must print 9 (deployed prints 1)
printf 'fn main(){\n  let f = 1\n    - 2\n    + 10\n  print(f)\n}\n' > "$W/repro1.hexa"
NOATLAS=$(mktemp -d); HEXA_ATLAS_EMBED="$NOATLAS" "$W/aprime_cc" _drv.hexa \
  --emit=obj --target=arm64-apple-darwin -o "$W/repro1.o" "$W/repro1.hexa"
"${HX_HOME:-$HOME/.hx}/self/native/selfhost/hexa_ld" \
  -o "$W/repro1.bin" "$W/repro1.o" "$W/rt.o" --lc-main _main
"$W/repro1.bin"                              # expect: 9   (deployed: 1)

# (5b) BUG-2 proof: comptime-folded -1.797…e308 baked as EXACT IEEE bits
printf 'fn main(){\n  let a = -1.7976931348623157e308\n  let b = a + 0.0\n  exit(0)\n}\n' > "$W/lit2.hexa"
HEXA_ATLAS_EMBED="$NOATLAS" "$W/aprime_cc" _drv.hexa \
  --emit=obj --target=arm64-apple-darwin -o "$W/lit2.o" "$W/lit2.hexa"
xxd -p "$W/lit2.o" | tr -d '\n' | grep -oi ffffffffffffefff \
  && echo "EXACT 0xFFEFFFFFFFFFFFFF baked"   # deployed bakes hexa_float(-1.79769e+308) (%g)
```

Both green = current source closes the residual. (OP-126 verdict: PROVEN.)

---

## 2. Full PROMOTE (build-host — makes the fix LIVE in `hexa run`)

> ⚠ NOT 0-pod. The self-host gen3 byte-eq ladder is THREE ~68-min self-emits
> (~3.5 h). Highest-blast-radius op in the repo — a bad seed breaks bootstrap.

```bash
cd <repo>

# (a) build the self-host fixpoint (gen3 + hexa_ld + rt.o, ~3.5h)
nohup bash tool/build_selfhost.sh -r "$PWD" -w "$PWD/build/selfhost" \
      --detached "$PWD/build/selfhost/mark.txt" > build/selfhost/build.log 2>&1 &
# wait for: GATE=BYTE-EQ  (cc-gen3.o == cc-gen4.o) in mark.txt — REQUIRED.

# (b) GATED side-by-side install (tier1) — parity gate is a HARD precondition.
#     ~/.hx/bin default stays UNTOUCHED; opt-in via `hx-selfhost <args>`.
bash tool/promote_selfhost.sh install -w "$PWD/build/selfhost"

# (c) DEFAULT FLIP (tier2) — USER-GATED. Requires the explicit review flag.
#     Backs up the current hexa.real to hexa.real.pre-selfhost.<ts>, symlinks
#     hexa.real -> hx-selfhost-cli, writes the persistence marker.
bash tool/promote_selfhost.sh install --default --i-have-reviewed-parity \
     -w "$PWD/build/selfhost"

bash tool/promote_selfhost.sh --status      # confirm: default FLIPPED to selfhost
```

**To make `hexa run` itself current-source** (option A, full close): the dispatch
binary that `hx-selfhost-cli` delegates to must be the current-source build — i.e.
re-install from a current-source release tarball (re-run `install.sh` against a
freshly-built release), OR extend `hx-selfhost-cli` so non-`--emit` `run`/`build`
also route to a current-source compiler instead of the stale `pre-selfhost` backup.
(gen3 alone fixes the `--emit` surface; the `run` delegation target is the dispatch
binary and must also be refreshed.)

---

## 3. ROLLBACK (`--revert`)

```bash
bash tool/promote_selfhost.sh --revert
# restores hexa.real from the newest hexa.real.pre-selfhost.<ts> backup
# and clears the ~/.hx/.selfhost-default persistence marker. Idempotent.

bash tool/promote_selfhost.sh --status      # confirm: default = shipped (NOT flipped)
```

`--revert` is a no-op (exit 2, harmless) if `hexa.real` is already a real binary
(not a selfhost symlink) or there is no backup.

---

## 4. What's proven vs decided

| Item                                            | State                          |
|-------------------------------------------------|--------------------------------|
| Current source closes BUG-1 (1-2+10 → 9)        | ✅ PROVEN 0-pod (aprime_cc)    |
| Current source closes BUG-2 (exact e308 bits)   | ✅ PROVEN 0-pod (obj-disasm)   |
| Proving build is 0-pod-feasible (~32 s)         | ✅ PROVEN                      |
| gen3 byte-eq fixpoint ladder (~3.5 h)           | build-host (not 0-pod)         |
| **Default flip / dispatch refresh**             | **USER DECISION (not done)**   |

The verify question — *does a local re-promote close the deployed residual?* — is
**YES, PROVEN**. The flip itself is intentionally left to the user.
