#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────
# tool/selfhost_arm64_remote_run.sh — runs ON a native aarch64-linux host to
# drive the full SELFHOST-NEXT native self-emit + byte-eq fixpoint past the
# #2578 OOM wall (pi5 OOM'd ~7.76 GiB on a 7.8 GiB host, 0 ENCODE-MISS).
#
# Steps (all REAL, exit codes captured separately, NO pipe-mask):
#   1. apt deps (gcc, binutils, python3, git, time)
#   2. clone origin/main
#   3. TARGET=linux-arm64 CC=gcc LIBS='-lm -ldl' bash tool/release_build  → ./hexa
#   4. /usr/bin/time -v bash tool/build_native_linux_arm64 --self-emit
#        → cc_native + native ELF emit/link/run + COMPILER SELF-EMIT (cc-self.o).
#        peak RSS = the OOM-wall measurement.
#   5. byte-eq fixpoint: re-run the SAME self-emit command on cc_native → cc-self2.o,
#        `cmp cc-self.o cc-self2.o` (gen3-emits-gen4 determinism / fixpoint, native).
#
# Output: a self-contained REPORT block to stdout (parsed by the dispatcher).
# ─────────────────────────────────────────────────────────────────────────
set -u
WORK="${1:-$HOME/hx-selfhost}"
REPO="$WORK/hexa-lang"
LOG="$WORK/run.log"
mkdir -p "$WORK"
exec > >(tee "$LOG") 2>&1

echo "=== HOST ==="; uname -a; nproc; free -g; echo

echo "=== STEP 1: apt deps ==="
sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gcc binutils python3 git time >/dev/null
gcc --version | head -1; ld --version | head -1; python3 --version

echo "=== STEP 2: clone origin/main ==="
rm -rf "$REPO"
git clone --depth 1 https://github.com/dancinlab/hexa-lang.git "$REPO"
cd "$REPO"
HEAD_SHA="$(git rev-parse --short HEAD)"
echo "HEAD=$HEAD_SHA"

echo "=== STEP 3: release_build (linux-arm64 / gcc) ==="
set +e
TARGET=linux-arm64 CC=gcc LIBS='-lm -ldl' bash tool/release_build
RB_RC=$?
set -e 2>/dev/null || true
echo "RELEASE_BUILD_RC=$RB_RC"
ls -la ./hexa 2>&1 | head -1

echo "=== STEP 4: native self-emit (RSS-instrumented) ==="
/usr/bin/time -v bash tool/build_native_linux_arm64 --self-emit > "$WORK/selfemit.out" 2> "$WORK/time.out"
SE_RC=$?
echo "SELF_EMIT_RC=$SE_RC"
tail -40 "$WORK/selfemit.out"
echo "--- /usr/bin/time -v (RSS) ---"
grep -iE "Maximum resident|Elapsed|Exit status|OOM|killed" "$WORK/time.out" || cat "$WORK/time.out" | tail -20
PEAK_KB="$(grep -i 'Maximum resident' "$WORK/time.out" | grep -oE '[0-9]+' | tail -1)"
PEAK_GIB="$(awk -v k="${PEAK_KB:-0}" 'BEGIN{printf "%.2f", k/1024/1024}')"
echo "PEAK_RSS_GIB=$PEAK_GIB"

# locate the work dir build_native used (default $REPO/build/larm64)
LWORK="$REPO/build/larm64"
SELF_O="$LWORK/cc-self.o"
ENCODE_MISS="$(grep -c 'ENCODE-MISS' "$LWORK/selfemit.log" 2>/dev/null || echo NA)"
SELF_SZ="$(stat -c%s "$SELF_O" 2>/dev/null || echo 0)"
echo "ENCODE_MISS=$ENCODE_MISS  CC_SELF_O=$SELF_SZ B  ($SELF_O)"

echo "=== STEP 5: byte-eq fixpoint (re-emit + cmp) ==="
CMP_RESULT="SKIPPED"
FIRSTDIFF="NA"
if [ -s "$SELF_O" ] && [ -x "$LWORK/cc_native" ] && [ -s "$LWORK/cc-flat.hexa" ]; then
  mkdir -p "$LWORK/noatlas2"
  HEXA_ATLAS_EMBED="$LWORK/noatlas2" "$LWORK/cc_native" _drv.hexa --emit=obj --backend=native \
    --target=arm64-linux-gnu --ignore-errors -o "$LWORK/cc-self2.o" "$LWORK/cc-flat.hexa" \
    > "$WORK/selfemit2.log" 2>&1
  RE_RC=$?
  echo "RE_EMIT_RC=$RE_RC  cc-self2.o=$(stat -c%s "$LWORK/cc-self2.o" 2>/dev/null || echo 0) B"
  if cmp "$SELF_O" "$LWORK/cc-self2.o"; then
    CMP_RESULT="BYTE-EQ-FIXPOINT"
  else
    CMP_RESULT="DIFFER"
    FIRSTDIFF="$(cmp "$SELF_O" "$LWORK/cc-self2.o" 2>&1 | head -1)"
  fi
else
  echo "cc-self.o absent or cc_native missing — self-emit did not produce an object (see STEP 4)"
fi

echo
echo "==================== REPORT ===================="
echo "HEAD=$HEAD_SHA"
echo "HOST_ARCH=$(uname -m)  HOST_RAM_GIB=$(free -g | awk '/Mem:/{print $2}')"
echo "RELEASE_BUILD_RC=$RB_RC"
echo "SELF_EMIT_RC=$SE_RC"
echo "PEAK_RSS_GIB=$PEAK_GIB"
echo "ENCODE_MISS=$ENCODE_MISS"
echo "CC_SELF_O_BYTES=$SELF_SZ"
echo "FIXPOINT_CMP=$CMP_RESULT"
echo "FIXPOINT_FIRSTDIFF=$FIRSTDIFF"
echo "================================================"
