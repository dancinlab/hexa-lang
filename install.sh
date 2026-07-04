#!/bin/bash
# hexa-lang installer — one-liner for `hexa` (compiler) + `hx` (package manager)
#
# Usage:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dancinlab/hexa-lang/main/install.sh)"
#
# Env overrides:
#   HX_HOME         install prefix (default: ~/.hx)
#   HEXA_VERSION    release tag to pull hexa binary from (default: latest)
#   HEXA_REPO       upstream repo (default: dancinlab/hexa-lang)
#   HEXA_BRANCH     source branch to clone for stdlib/self/ (default: main)
#   HEXA_SKIP_HX    set to 1 to skip hx package manager install
#   HEXA_SKIP_HEXA  set to 1 to skip hexa compiler install
#   HEXA_SKIP_SRC   set to 1 to skip the stdlib/self/ source clone
#                   (NOTE: `hexa build` of `use "stdlib/..."` programs will
#                    then fail — the source tree provides stdlib/)
#   HEXA_MUSL       linux-x86_64 only: force (1) / disable (0) the statically
#                   linked, glibc-independent `hexa-linux-x86_64-musl.tar.gz`
#                   asset. Unset = auto-detect (use musl on a musl host or when
#                   the host glibc is older than the build floor). darwin/arm64
#                   are unaffected. The musl asset is a SUPPLEMENTARY target
#                   shipped alongside the per-target tarball; if it is absent the
#                   installer falls back to the dynamic glibc asset automatically.
#   HEXA_CUDA       linux-x86_64 only: install the cuBLAS-enabled
#                   `hexa-linux-x86_64-cuda.tar.gz` asset (GPU-accelerated GEMM
#                   via the CUDA-folded runtime.a → cuda_available()=1, anima
#                   #2386). =1 forces it; =0 forces the CPU glibc asset. UNSET =
#                   AUTO: prefer cuda when the host has an NVIDIA GPU (nvidia-smi)
#                   AND a resolvable cuBLAS/cudart runtime (so a GPU consumer's
#                   install lands cuda_available()=1 without opt-in — #3701). The
#                   cuda asset is SUPPLEMENTARY, so on a release where it is
#                   absent the installer falls back to the CPU glibc asset
#                   automatically. Takes precedence over HEXA_MUSL when both apply.

set -eu

HX_HOME="${HX_HOME:-$HOME/.hx}"
HX_BIN="$HX_HOME/bin"
HX_SRC="$HX_HOME/src"
HEXA_REPO="${HEXA_REPO:-dancinlab/hexa-lang}"
HEXA_VERSION="${HEXA_VERSION:-latest}"
HEXA_BRANCH="${HEXA_BRANCH:-main}"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
red()   { printf '\033[31m%s\033[0m\n' "$*" >&2; }
dim()   { printf '\033[2m%s\033[0m\n' "$*"; }

detect_target() {
    local os arch
    case "$(uname -s)" in
        Darwin)  os="darwin"  ;;
        Linux)   os="linux"   ;;
        *) red "unsupported OS: $(uname -s)"; exit 1 ;;
    esac
    case "$(uname -m)" in
        arm64|aarch64) arch="arm64" ;;
        x86_64|amd64)  arch="x86_64" ;;
        *) red "unsupported arch: $(uname -m)"; exit 1 ;;
    esac
    echo "${os}-${arch}"
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || { red "missing: $1"; exit 1; }
}

# Decide whether the linux-x86_64 install should prefer the statically-linked,
# glibc-independent `-musl` asset over the dynamic glibc tarball. This is the
# consumer-side half of the static-musl supplementary target (release.yml
# release-linux-x86_64-musl): a dynamic glibc binary dies with
# `GLIBC_2.xx not found` on a host whose glibc is older than the build floor
# (ubuntu-22.04 → glibc 2.35) or on a pure-musl host (Alpine) that has no glibc
# at all. The static-musl ELF runs on any of them.
#
# Scope: linux-x86_64 AND linux-arm64 (both targets ship a musl asset; the arm64
# musl asset landed in ING #2 r2). Returns 0 (prefer musl) / 1 (keep glibc).
# ADDITIVE — the glibc path is the default and is only overridden on an explicit
# opt-in or a positively-detected need, so normal modern-glibc installs are
# unchanged on either arch.
#
#   HEXA_MUSL=1  → force musl ; HEXA_MUSL=0 → force glibc (escape hatch).
#   auto (unset) → musl when the host is musl-based OR glibc < MUSL_GLIBC_FLOOR.
# Decide whether the linux-x86_64 install should pull the cuBLAS-enabled `-cuda`
# asset (release.yml release-linux-x86_64-cuda). The cuda binary links cuBLAS so a
# consumer `hexa build`/`run` program gets GPU-accelerated GEMM (cuda_available()
# == 1 — anima #2386); the default CPU glibc asset reports cuda_available() == 0.
#
# Selection (linux-x86_64 ONLY — the only target with a cuda asset):
#   HEXA_CUDA=1  → force cuda (explicit opt-in, unchanged).
#   HEXA_CUDA=0  → force CPU glibc (explicit opt-out / escape hatch).
#   unset (auto) → AUTO-PREFER cuda when the host BOTH (a) has an NVIDIA GPU
#                  (`nvidia-smi -L` lists ≥1 device) AND (b) has the cuBLAS/cudart
#                  runtime libs resolvable (ldconfig or the usual CUDA lib dirs).
#                  Requiring BOTH avoids shipping a cuBLAS-linked binary that
#                  would fail to load libcudart on a GPU host without the CUDA
#                  runtime installed — in that case we keep the CPU asset. This is
#                  the consumer half of #3701 (a GPU consumer's `install.sh hexa`
#                  now lands cuda_available()=1 without needing HEXA_CUDA=1).
#
# Returns 0 (prefer cuda) / 1 (keep default). The cuda asset is SUPPLEMENTARY,
# so a release install where the asset is absent falls back to the CPU glibc
# tarball (the generic asset fallback in install_hexa) — the auto-prefer never
# hard-fails an install.
_has_nvidia_gpu() {
    command -v nvidia-smi >/dev/null 2>&1 || return 1
    # `nvidia-smi -L` lists one line per GPU ("GPU 0: ..."). Empty / error → none.
    nvidia-smi -L 2>/dev/null | grep -q '^GPU ' || return 1
    return 0
}
# ── pip-nvidia wiring (bare rent pod: no toolkit, CUDA libs only in pip wheels) ──
# Wheels ship SONAME-only libs (libcudart.so.12 — no bare .so linker name) under
# <site-packages>/nvidia/*/lib and are never in the ldconfig cache. Resolve them
# into a hexa-owned symlink farm $HX_HOME/cuda-libs providing bare linker names
# + one stable -L/-rpath dir — the user's python env is never mutated.
_pip_nvidia_roots() {
    # primary: the live interpreter resolves venv/conda/user/system site in one
    # shot. nvidia is a PEP-420 namespace pkg → __path__ (never __file__). No
    # network, no `pip show` (slow / pip may be absent); sub-100ms, cannot hang.
    for py in python3 python; do
        command -v "$py" >/dev/null 2>&1 || continue
        "$py" -c 'import nvidia; print("\n".join(nvidia.__path__))' 2>/dev/null && return 0
        break    # interpreter present but no nvidia pkg → try the glob fallback
    done
    # fallback (python absent / exotic install): bounded glob, standard roots.
    for r in "${VIRTUAL_ENV:-/nonexistent}"/lib/python3*/site-packages/nvidia \
             /opt/conda/lib/python3*/site-packages/nvidia \
             /usr/local/lib/python3*/dist-packages/nvidia \
             /usr/lib/python3*/dist-packages/nvidia \
             "$HOME"/.local/lib/python3*/site-packages/nvidia; do
        [ -d "$r" ] && printf '%s\n' "$r"
    done
    return 0
}
_wire_pip_cuda_libs() {
    farm="$HX_HOME/cuda-libs"
    roots="$(_pip_nvidia_roots)"
    rm -rf "$farm" 2>/dev/null || true          # idempotent: rebuilt from scratch
    [ -n "$roots" ] || return 1
    mkdir -p "$farm" || return 1
    # Symlink every wheel lib (SONAME name + bare linker name). Glob expansion is
    # sorted → deterministic; ln -sf ascending → the highest .so.N wins the bare name.
    printf '%s\n' "$roots" | while IFS= read -r root; do
        for f in "$root"/*/lib/lib*.so* "$root"/*/lib/lib*.a; do
            [ -e "$f" ] || continue
            b="${f##*/}"
            ln -sf "$f" "$farm/$b"
            case "$b" in
                *.so.*) ln -sf "$f" "$farm/${b%%.so.*}.so" ;;
            esac
        done
    done
    # -lcuda linker name: prefer the REAL driver lib (present whenever nvidia-smi
    # is), else the wheel's lib/stubs/libcuda.so (link-only stub — fine for -lcuda;
    # the loader binds the real driver at run time via its SONAME libcuda.so.1).
    if [ ! -e "$farm/libcuda.so" ]; then
        for c in $(ldconfig -p 2>/dev/null | sed -n 's/.*libcuda\.so\.1 .*=> //p' | head -1) \
                 /usr/lib/x86_64-linux-gnu/libcuda.so.1 /usr/lib64/libcuda.so.1; do
            [ -e "$c" ] || continue
            ln -sf "$c" "$farm/libcuda.so"
            ln -sf "$c" "$farm/libcuda.so.1"
            break
        done
    fi
    if [ ! -e "$farm/libcuda.so" ]; then
        printf '%s\n' "$roots" | while IFS= read -r root; do
            for s in "$root"/*/lib/stubs/libcuda.so; do
                [ -e "$s" ] && [ ! -e "$farm/libcuda.so" ] && ln -sf "$s" "$farm/libcuda.so"
            done
        done
    fi
    # gate on the one lib the link always needs; report the rest loudly.
    if [ ! -e "$farm/libcudart.so" ]; then
        rm -rf "$farm" 2>/dev/null || true
        return 1
    fi
    for need in libcuda.so libcudadevrt.a; do
        [ -e "$farm/$need" ] || red "  ⚠ cuda-libs: $need unresolved — cuda link may fail (check nvidia driver / nvidia-cuda-runtime-cu12 wheel)"
    done
    return 0
}
_has_toolkit_cudart() {
    # cuBLAS/cudart resolvable via the dynamic loader cache or a standard CUDA
    # install dir. The cuda binary links -lcudart -lcublas, so without these it
    # would fail to start — keep the CPU asset in that case.
    if command -v ldconfig >/dev/null 2>&1 && ldconfig -p 2>/dev/null | grep -q 'libcudart\.so'; then
        return 0
    fi
    for d in /usr/local/cuda/lib64 /usr/local/cuda/targets/x86_64-linux/lib \
             /usr/lib/x86_64-linux-gnu /usr/lib64; do
        [ -e "$d"/libcudart.so* ] 2>/dev/null && return 0
    done
    return 1
}
_has_pip_cudart() {
    for r in $(_pip_nvidia_roots); do
        for f in "$r"/*/lib/libcudart.so*; do
            [ -e "$f" ] && return 0
        done
    done
    return 1
}
_has_cuda_runtime() {
    # union: a toolkit OR pip-wheel cudart makes the -cuda asset resolvable.
    _has_toolkit_cudart || _has_pip_cudart
}
prefer_cuda() {
    [ "$(detect_target)" = "linux-x86_64" ] || return 1
    case "${HEXA_CUDA:-}" in
        1) return 0 ;;   # explicit opt-in
        0) return 1 ;;   # explicit opt-out
    esac
    # auto: GPU present AND cuda runtime libs resolvable → prefer cuda.
    if _has_nvidia_gpu && _has_cuda_runtime; then
        return 0
    fi
    return 1
}

MUSL_GLIBC_FLOOR_MAJOR=2
MUSL_GLIBC_FLOOR_MINOR=34
prefer_musl() {
    # Only the linux targets have a musl asset (x86_64 + arm64).
    case "$(detect_target)" in
        linux-x86_64|linux-arm64) ;;
        *) return 1 ;;
    esac

    # Explicit override wins.
    case "${HEXA_MUSL:-}" in
        1) return 0 ;;
        0) return 1 ;;
    esac

    # Pure-musl host (e.g. Alpine): `ldd --version` names musl, or there is no
    # glibc-style libc at all. ldd is in busybox on Alpine and prints to stderr.
    local ldd_out
    ldd_out="$( (ldd --version) 2>&1 | head -1 )"
    case "$ldd_out" in
        *musl*) return 0 ;;
    esac

    # glibc host: read the runtime glibc version (getconf is the portable probe;
    # `ldd --version` is the fallback). Prefer musl when it is older than the
    # build floor so the dynamic asset's GLIBC_2.xx symbols would be missing.
    local ver major minor
    ver="$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $NF}')"
    [ -n "$ver" ] || ver="$(printf '%s\n' "$ldd_out" | awk '{print $NF}')"
    major="${ver%%.*}"
    minor="${ver#*.}"; minor="${minor%%.*}"
    case "$major" in ''|*[!0-9]*) return 1 ;; esac   # unparseable → keep glibc
    case "$minor" in ''|*[!0-9]*) minor=0 ;; esac
    if [ "$major" -lt "$MUSL_GLIBC_FLOOR_MAJOR" ] \
       || { [ "$major" -eq "$MUSL_GLIBC_FLOOR_MAJOR" ] && [ "$minor" -lt "$MUSL_GLIBC_FLOOR_MINOR" ]; }; then
        return 0
    fi
    return 1
}

install_hexa() {
    bold "▸ installing hexa (compiler)"
    local target tag base asset url tmp src
    target="$(detect_target)"
    tag="$HEXA_VERSION"
    base="https://github.com/${HEXA_REPO}/releases"

    # Asset selection. Default = the per-target tarball (`hexa-${target}`). On
    # the linux targets (x86_64 + arm64), prefer the static-musl asset when the
    # host needs it (old or absent glibc) or it is forced via HEXA_MUSL — see
    # prefer_musl(). The musl tarball's inner dir is `hexa-${target}-musl/`,
    # matching the asset name.
    asset="hexa-${target}"
    if prefer_cuda; then
        # HEXA_CUDA=1 opt-in (linux-x86_64): cuBLAS-enabled asset. Takes precedence
        # over musl (a CUDA host is glibc + has an NVIDIA GPU; the cuda asset is a
        # dynamic glibc binary, not static-musl).
        asset="hexa-${target}-cuda"
        if [ "${HEXA_CUDA:-}" = "1" ]; then
            dim "  HEXA_CUDA=1 → preferring cuBLAS-enabled asset (GPU-accelerated)"
        else
            dim "  NVIDIA GPU + cuda runtime detected → preferring cuBLAS-enabled asset (cuda_available=1; HEXA_CUDA=0 to opt out)"
        fi
    elif prefer_musl; then
        asset="hexa-${target}-musl"
        dim "  glibc-independent host → preferring static-musl asset"
    fi

    _asset_url() {
        if [ "$tag" = "latest" ]; then
            echo "${base}/latest/download/${1}.tar.gz"
        else
            echo "${base}/download/${tag}/${1}.tar.gz"
        fi
    }
    url="$(_asset_url "$asset")"

    tmp="$(mktemp -d)"

    dim "  fetching $url"
    if ! curl -fsSL "$url" -o "$tmp/hexa.tar.gz"; then
        # The musl AND cuda assets are SUPPLEMENTARY targets; a release may not
        # carry them. Fall back to the default glibc asset rather than fail —
        # this keeps a forced/auto-musl or HEXA_CUDA=1 request working
        # (it just lands the glibc binary, which is what shipped before).
        if [ "$asset" != "hexa-${target}" ]; then
            dim "  ⚠ ${asset}.tar.gz not found (musl/cuda assets are supplementary) → glibc asset"
            asset="hexa-${target}"
            url="$(_asset_url "$asset")"
            dim "  fetching $url"
            curl -fsSL "$url" -o "$tmp/hexa.tar.gz" || true
        fi
    fi
    if [ ! -s "$tmp/hexa.tar.gz" ]; then
        red "  ✗ release asset not found: ${asset}.tar.gz"
        red "    (tag: ${tag}, repo: ${HEXA_REPO})"
        echo ""
        echo "  Fallback: build from source"
        echo "    git clone https://github.com/${HEXA_REPO}.git"
        echo "    cd hexa-lang && ./hexa install.hexa"
        rm -rf "$tmp"
        return 1
    fi

    tar -xzf "$tmp/hexa.tar.gz" -C "$tmp"

    # Archive layout: <asset>/{hexa, build/<sidecar binaries>}
    # Dispatcher resolves sidecar binaries relative to argv[0] (<dir>/build/),
    # so preserve the build/ directory alongside the hexa binary. `asset` is the
    # tarball basename actually fetched (musl or glibc), matching the inner dir.
    src="$tmp/${asset}"
    [ -d "$src" ] || src="$tmp"

    # Dispatcher resolves its sidecar binaries via dirname(argv[0]).
    # When invoked through PATH, argv[0]="hexa" has no slash and resolution
    # falls back to cwd — wrong. Install the native binary under a private
    # name and place a thin shim at $HX_BIN/hexa that exec's it with an
    # absolute argv[0].
    #
    # Canonical on-disk name = `hexad` (AMFI burning-matcher treadmill
    # terminal: hexadrv → hexa.real → hxv2 → hexad · cli_wrappers.hexa:38,
    # tool/bin/build.hexa:119). The shim (cli_wrappers.hexa SSOT) resolves
    # `hexad` FIRST and `exec -a hexa` it, so the on-disk name AMFI's burning
    # matcher sees is the un-burnt `hexad`. The shim below execs `hexad`
    # DIRECTLY (matching cli_wrappers.hexa SSOT + the dev-build path), so
    # `hexad` is the single canonical surface every layer keys on.
    #
    # `hexad` is the FLIP SENTINEL too (tool/promote_selfhost.sh): an unflipped
    # install has `hexad` as a plain REAL FILE — required BOTH for the AMFI
    # escape (AMFI evaluates the resolved real-file name; a symlink would
    # re-expose a burnt name) AND so `[ -L hexad ]` flip-detection reports a
    # fresh install as "NOT flipped". A tier2 default-flip backs the real file
    # up to `hexad.pre-selfhost.<ts>` and replaces `hexad` with a symlink →
    # `hx-selfhost-cli`; AMFI escape survives the flip because the symlink
    # RESOLVES to the un-burnt `hx-selfhost-cli` real-file name. `--revert`
    # restores the backup real file, returning the shipped surface.
    #
    # `hexa.real` and `hxv2` are retired-name compat symlinks → `hexad`. Every
    # legacy consumer of those PATHs (firmware fixtures, glibc preflight,
    # module_loader check) keeps resolving losslessly through the symlink.
    install -m 0755 "$src/hexa" "$HX_BIN/hexad"
    # retired-name compat symlinks (relative target — install dir relocatable).
    ln -sf hexad "$HX_BIN/hexa.real"
    ln -sf hexad "$HX_BIN/hxv2"
    # standalone-rtlink: the shim exports HEXA_PREBUILT_RUNTIME at the persisted
    # native-seed runtime.a ($HX_BIN/build/runtime.a, dropped by install_src's
    # stage_resolve_runtime_a step) so a consumer `hexa build`/`run` in a FRESH
    # shell links that archive — without it the shipped binary compiles a
    # content-hash runtime.<sha>.o from `clang -c runtime.c` which, after the
    # emitter-regen declared rt_{array,map}_*_native extern, can no longer
    # resolve those symbols (undefined reference at the app link). This is the
    # ONLY channel that reaches the CURRENTLY-shipped binary (its
    # resolve_prebuilt_runtime() already honors the env var; the env-free
    # <hxroot>/build/runtime.a fallback only lands in a future binary). Guards:
    # respect a user-set HEXA_PREBUILT_RUNTIME (do not override), and only export
    # when the archive actually exists (install_src may have failed / been skipped
    # — then fall through to the legacy content-hash path with the unpatched
    # frozen seed, no regression).
    cat > "$HX_BIN/hexa" <<EOF
#!/bin/bash
if [ -z "\${HEXA_PREBUILT_RUNTIME:-}" ] && [ -f "$HX_BIN/build/runtime.a" ]; then
    export HEXA_PREBUILT_RUNTIME="$HX_BIN/build/runtime.a"
fi
exec "$HX_BIN/hexad" "\$@"
EOF
    chmod 0755 "$HX_BIN/hexa"
    # Copy build/ verbatim so any sidecar binary the release ships
    # (e.g. hexa_module_loader) just works.
    if [ -d "$src/build" ]; then
        mkdir -p "$HX_BIN/build"
        cp -R "$src/build/." "$HX_BIN/build/"
        chmod -R u+rwX,go+rX "$HX_BIN/build"
    fi
    # Place the shipped precompile cache at the install dir. The tarball carries
    # release/precompile/hexa_run.<key> (stage_precompile_package), and the
    # compiler's _precompile_lookup probes <install_dir>/release/precompile/ — but
    # nothing placed it here, so the shipped cache never reached consumers and
    # every `hexa run <shipped-script>` (and `hexa cloud` via cmd_run) re-forked
    # clang. release/precompile/ is .gitignore'd, so the install_src clone can NOT
    # deliver it either — the tarball is the ONLY channel. Keys are
    # sha256(source)[:16] + "_" + version, so a stale entry can never be served
    # (source/version change → cache miss → recompile); placing it is purely a
    # cold-start speedup with no staleness risk.
    if [ -d "$src/release/precompile" ]; then
        mkdir -p "$HX_BIN/release/precompile"
        cp -R "$src/release/precompile/." "$HX_BIN/release/precompile/"
        chmod -R u+rwX,go+rX "$HX_BIN/release/precompile"
    fi
    # Purge any stale standalone sub-binaries from a prior LOCAL build. `hexa
    # cloud` / `hexa sim-universe` prefer an install-dir bin/hexa-<sub> binary
    # over the source/version-keyed cmd_run path — and that standalone binary is
    # NOT shipped or refreshed by the release, so a once-built one (e.g. a 6/5
    # bin/hexa-cloud that predates a merged source fix) silently shadows every
    # later change (ING #66/#67 — `--offer` ignored). Removing it forces dispatch
    # through cmd_run, which is source-hash + version keyed and therefore can
    # never go stale. A fresh standalone built from current source is fine; this
    # only removes the unrefreshed shadow.
    rm -f "$HX_BIN/bin/hexa-cloud" "$HX_BIN/bin/hexa-sim-universe" 2>/dev/null || true
    # #3723 fix — mark a cuda-runtime install so a consumer `hexa run/build` auto-links
    # cudart/cublas WITHOUT needing HEXA_CUDA=1 on every invocation. The cuda asset's
    # runtime.a (runtime_cuda.o) references cudaLaunchKernel/cublas; main.hexa
    # os_clang_ldflags reads $HX_HOME/.cuda-runtime and adds -lcudart -lcublas when
    # present. Idempotent: a CPU/musl (re)install REMOVES the marker (no stale cuda link).
    if [ "${asset##*-}" = "cuda" ]; then
        : > "$HX_HOME/.cuda-runtime" 2>/dev/null || true
        # bare-pod pip wiring: ONLY when no toolkit cudart resolves — a toolkit host
        # takes today's exact path (no farm → os_clang_ldflags CUDA_HOME branch →
        # byte-identical link line). The farm's existence IS the record.
        if _has_toolkit_cudart; then
            rm -rf "$HX_HOME/cuda-libs" 2>/dev/null || true
        elif _wire_pip_cuda_libs; then
            dim "  pip-nvidia libs wired → $HX_HOME/cuda-libs (bare .so linker names + rpath dir)"
        else
            red "  ⚠ cuda asset installed but no resolvable libcudart (toolkit or pip nvidia-cuda-runtime-cu12) — cuda link will fail"
        fi
    else
        rm -f "$HX_HOME/.cuda-runtime" 2>/dev/null || true
        rm -rf "$HX_HOME/cuda-libs" 2>/dev/null || true
    fi
    # macOS — defeat the two kill vectors a DOWNLOADED binary hits that a
    # local build does not:
    #   (1) Gatekeeper quarantine — curl'd assets carry com.apple.quarantine,
    #       so first exec triggers a Gatekeeper assessment that rejects an
    #       ad-hoc / non-notarized binary. Running THIS script is the user's
    #       trust act (Homebrew / rustup model), so strip the xattr.
    #   (2) AppleSystemPolicy burning matcher — ad-hoc-signed (flags=0x2)
    #       binaries get SIGKILLed by name after heavy exec. Re-sign with a
    #       stable identity (flags=0x0) to escape it: HEXA_CODESIGN_IDENTITY,
    #       else the first available codesigning identity, else ad-hoc
    #       fallback (quarantine already stripped).
    # A Developer-ID-notarized release tarball makes both harmless no-ops.
    if [ "$(uname -s)" = "Darwin" ]; then
        # Operate on the real file (hexad), not the hexa.real/hxv2 symlinks —
        # codesign/xattr must sign the Mach-O, not a symlink.
        xattr -dr com.apple.quarantine "$HX_BIN/hexad" "$HX_BIN/build" 2>/dev/null || true
        if command -v codesign >/dev/null 2>&1; then
            _sid="${HEXA_CODESIGN_IDENTITY:-}"
            if [ -z "$_sid" ] && command -v security >/dev/null 2>&1; then
                _sid="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/[0-9]+\)/{print $2; exit}')"
            fi
            [ -n "$_sid" ] || _sid="-"
            codesign --force --sign "$_sid" --identifier hexad "$HX_BIN/hexad" 2>/dev/null || true
            if [ "$_sid" = "-" ]; then
                dim "  codesign: ad-hoc (set HEXA_CODESIGN_IDENTITY=<cert> for a stable identity)"
            else
                dim "  codesign: stable identity"
            fi
        fi
    fi

    # selfhost persistence — the `install …` line above resets hexad to a
    # fresh copy of the canonical (C-transpile) binary, silently reverting a
    # tier2 native default-flip (tool/promote_selfhost.sh install --default).
    # If the native default was promoted (marker present) and the self-host
    # slot + CLI shim survived this reinstall, re-apply the flip so the native
    # compile surface stays the default. The flip mv's the real hexad file to a
    # backup and symlinks hexad → hx-selfhost-cli (the unique `[ -L hexad ]`
    # state promote_selfhost.sh keys on). codesign above already signed the
    # real hexad before this flip; a `--revert` restores the backup file and
    # the shipped surface returns. The hexa.real/hxv2 compat symlinks → hexad
    # follow the flip transparently (they resolve to whatever hexad points at).
    if [ -f "$HX_HOME/.selfhost-default" ] && [ -x "$HX_BIN/hx-selfhost-cli" ] \
       && [ -x "$HX_HOME/self/native/selfhost/gen3" ]; then
        mv "$HX_BIN/hexad" "$HX_BIN/hexad.pre-selfhost.$(date +%Y%m%d-%H%M%S)"
        ln -sf "$HX_BIN/hx-selfhost-cli" "$HX_BIN/hexad"
        green "  ✓ selfhost-default marker → re-applied native tier2 flip"
    fi
    # glibc preflight (Linux only) — the prebuilt binary is built on ubuntu-22.04
    # (glibc 2.35 floor) so it runs on 22.04+ cloud pods. If the host glibc is
    # OLDER still (e.g. 20.04 / glibc 2.31), exec fails with a cryptic
    # "GLIBC_2.xx not found" dynamic-loader error — surface a clear, actionable
    # message instead so the failure is understandable (not a silent crash).
    if [ "$(uname -s)" = "Linux" ]; then
        if ! "$HX_BIN/hexad" --version >/dev/null 2>"$tmp/glibc.err"; then
            if grep -q "GLIBC_" "$tmp/glibc.err" 2>/dev/null; then
                red "  ✗ hexa cannot run on this host's glibc:"
                red "    $(grep -m1 GLIBC_ "$tmp/glibc.err")"
                hostglibc="$(ldd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+$' || echo '?')"
                red "    host glibc: ${hostglibc} — the hexa release needs ≥ 2.35 (ubuntu 22.04+)."
                echo "    Fix: use a glibc ≥ 2.35 image (ubuntu 22.04 / 24.04, debian 12+), OR" >&2
                echo "    build from source: git clone https://github.com/${HEXA_REPO}.git && cd hexa-lang && ./hexa install.hexa" >&2
                rm -rf "$tmp"
                return 1
            fi
            # non-glibc failure (e.g. missing lib) — show it but don't hard-fail the install
            dim "  (note: hexad --version exited nonzero: $(head -1 "$tmp/glibc.err" 2>/dev/null))"
        fi
    fi
    green "  ✓ $HX_BIN/hexa"
    rm -rf "$tmp"
}

install_src() {
    # Problem: the release tarball ships only {hexa binary, build/}. It does
    # NOT contain stdlib/ or self/. The compiler has install-relative stdlib/
    # discovery (commit df9e7f6b) — it probes <install_dir>/stdlib and
    # <install_dir>/self/stdlib — but nothing ever PLACES stdlib/ there. So a
    # fresh `hexa build` of any `use "stdlib/..."` program fails.
    #
    # Fix (works TODAY, no new release needed): shallow-clone the hexa-lang
    # source into $HX_SRC, then symlink the support trees next to the hexad
    # binary so the compiler's install-relative discovery resolves them:
    #   $HX_BIN/stdlib -> $HX_SRC/stdlib   (ml_stdlib_install_candidates: <inst>/stdlib)
    #   $HX_BIN/self   -> $HX_SRC/self     (<inst>/self/stdlib  AND  hexa cc's
    #                                       <inst>/self/native/hexa_cc.c)
    # install_dir_from_argv0() realpath-resolves hexad to $HX_BIN, so these
    # land exactly where the resolver looks.
    bold "▸ installing hexa source (stdlib/ + self/)"
    local repo_url
    repo_url="https://github.com/${HEXA_REPO}.git"

    if ! command -v git >/dev/null 2>&1; then
        red "  ✗ git not found — cannot install stdlib/ source"
        red "    \`hexa build\` of programs using \"stdlib/...\" will fail."
        red "    install git, then re-run, or set HEXA_SKIP_SRC=1 to silence."
        return 1
    fi

    if [ -d "$HX_SRC/.git" ]; then
        dim "  updating existing source at $HX_SRC"
        # Pin origin to the hexa-lang repo BEFORE fetching, then re-clone if the
        # update fails. Guards the wrong-repo silent-staleness class: if $HX_SRC was
        # previously cloned from a DIFFERENT repo (observed on a pool host whose
        # origin pointed at dancinlab/anima), the `|| true`-swallowed fetch/reset
        # would otherwise track THAT repo's main → self/ symlinked to a foreign tree
        # → user `hexa build` fails with confusing 'undeclared identifier' errors
        # that re-running install could never cure (the binary updates but self/
        # stays stale). set-url forces the correct source; a still-failing update
        # falls back to a fresh clone so a corrupt/foreign tree can never persist.
        git -C "$HX_SRC" remote set-url origin "$repo_url" >/dev/null 2>&1 || true
        if git -C "$HX_SRC" fetch --depth 1 origin "$HEXA_BRANCH" >/dev/null 2>&1 \
           && git -C "$HX_SRC" reset --hard FETCH_HEAD >/dev/null 2>&1; then
            :
        else
            dim "  update failed — re-cloning fresh from $repo_url"
            rm -rf "$HX_SRC"
            if ! git clone --depth 1 --branch "$HEXA_BRANCH" "$repo_url" "$HX_SRC" >/dev/null 2>&1; then
                red "  ✗ git clone failed: $repo_url ($HEXA_BRANCH)"
                return 1
            fi
        fi
    else
        dim "  cloning $repo_url (branch: $HEXA_BRANCH, shallow)"
        rm -rf "$HX_SRC"
        if ! git clone --depth 1 --branch "$HEXA_BRANCH" "$repo_url" "$HX_SRC" >/dev/null 2>&1; then
            red "  ✗ git clone failed: $repo_url ($HEXA_BRANCH)"
            return 1
        fi
    fi

    if [ ! -d "$HX_SRC/stdlib" ]; then
        red "  ✗ cloned source has no stdlib/ — repo layout changed?"
        return 1
    fi

    # Wire the install-relative discovery anchors. ln -sfn: replace any stale
    # link/dir atomically without descending into it.
    ln -sfn "$HX_SRC/stdlib" "$HX_BIN/stdlib"
    ln -sfn "$HX_SRC/self"   "$HX_BIN/self"
    green "  ✓ $HX_SRC (stdlib/ + self/ linked into $HX_BIN)"

    # Restore the bootstrap runtime seed (handoff 87a5f82e). The clone above is
    # a `.c=0` tree: self/runtime.c (and its #include fragments) are .gitignore'd
    # build inputs with NO emitter — absent on a fresh clone. Without them the
    # module_loader build below has no runtime to link, fails ('module_loader
    # build failed'), and runtime.c is left ungenerated → every later `hexa run`
    # dies with 'clang: no such file: self/runtime.c'. The pre-warm rescue lower
    # down can't break this: it is itself a `hexa build` that needs the same
    # runtime, and it runs AFTER this point. So restore the frozen seed NOW,
    # via the canonical tool, into the cloned tree (cwd=$HX_SRC; the tool uses
    # `git checkout <ref> -- self/runtime.c` and handles the shallow clone by
    # fetching the ref on demand). This is platform-neutral — it checks out C
    # text, no clang/-arch involved — so it fixes linux x86_64 and arm64 alike.
    bold "▸ restoring runtime seed (self/runtime.c)"
    if [ -x "$HX_SRC/tool/restore_frozen_seeds" ]; then
        if ( cd "$HX_SRC" && bash tool/restore_frozen_seeds >/dev/null 2>&1 ) \
            && [ -f "$HX_SRC/self/runtime.c" ]; then
            green "  ✓ $HX_SRC/self/runtime.c ($(wc -l < "$HX_SRC/self/runtime.c" | tr -d ' ') lines)"
        else
            red "  ✗ restore_frozen_seeds failed — self/runtime.c was not produced."
            red "    \`hexa build\`/\`hexa run\` will fail with 'no such file: self/runtime.c'."
            red "    Re-run install.sh (needs network to fetch the seed ref on a"
            red "    shallow clone), or run: cd $HX_SRC && tool/restore_frozen_seeds"
            return 1
        fi
    else
        red "  ✗ $HX_SRC/tool/restore_frozen_seeds missing — repo layout changed?"
        red "    Cannot generate self/runtime.c; \`hexa build\` will fail."
        return 1
    fi

    # standalone-rtlink: resolve build/runtime.a via stage_resolve_runtime_a so
    # the installed toolchain links the SAME native-seed-bearing runtime archive
    # the release/CI path builds — NOT just the surgically-patched frozen seed.
    #
    # WHY: restore_frozen_seeds above leaves a STALE frozen runtime_core.c. The
    # release pipeline instead runs stage_resolve_runtime_a, which (1) regenerates
    # runtime_core.c from its emitter SSOT and (2) assembles the arch-matched
    # native rt_{array,map}_*_native bodies from self/native/{array,map}_core_*.s
    # into runtime.a. The regenerated runtime_core.c declares those native symbols
    # `extern` UNCONDITIONALLY (#3629), so a plain `clang -c runtime.c` link can no
    # longer resolve them — only the runtime.a that ar's the assembled native
    # objects can. Running the canonical tool HERE (cwd=$HX_SRC, the same recipe
    # build_aprime.sh Stage 0b uses) closes the install↔release gap: the consumer
    # link picks up runtime.a via resolve_prebuilt_runtime()'s env-free fallback
    # (main.hexa: <hxroot>/build/runtime.a), so rt_*_native resolve with 0
    # residual-undefined. NON-FATAL: on failure we leave the surgically-patched
    # frozen seed (status quo) and warn — the legacy C #else element bodies in the
    # frozen runtime_core.c still satisfy the link, so no regression.
    bold "▸ resolving native runtime.a (stage_resolve_runtime_a — release parity)"
    _rtlink_ok=0
    # ING-82 guard — do NOT overwrite a cuda asset's cuBLAS-linked runtime.a with a
    # CPU rebuild. The cuda tarball ships build/runtime.a containing runtime_cuda.o
    # (cudart/cublas refs + the native rt_*_native seeds), already copied verbatim to
    # $HX_BIN/build/runtime.a by install_hexa. stage_resolve_runtime_a below rebuilds a
    # CPU-only runtime.a (no -DHEXA_CUDA, no runtime_cuda.o) and `cp`s it OVER that one,
    # so a `HEXA_CUDA=1` install lands cuda_available()=0 (the original ING #82 bug — the
    # asset was fine, the install clobbered it). The shipped cuBLAS runtime.a already has
    # the native rt_*_native seeds (built by the same release recipe), so it satisfies the
    # consumer link without a rebuild. Skip stage_resolve_runtime_a entirely for cuda.
    # Detect "cuda install" via the $HX_HOME/.cuda-runtime marker install_hexa drops for a
    # cuda asset (line ~317) — install-local + always in scope (the $asset var is set in a
    # different function and unreliable under `set -u`/dash).
    if [ -f "$HX_HOME/.cuda-runtime" ] && [ -f "$HX_BIN/build/runtime.a" ]; then
        # Mirror the cuBLAS archive into $HX_SRC/build/ too so the pre-warm build
        # (HEXA_LANG=$HX_SRC) links it instead of content-hash-compiling a CPU
        # runtime.c — keeping the warmed object cuda-consistent with the shim.
        mkdir -p "$HX_SRC/build"
        cp -f "$HX_BIN/build/runtime.a" "$HX_SRC/build/runtime.a" 2>/dev/null || true
        green "  ✓ cuda asset — keeping tarball's cuBLAS runtime.a (skip CPU stage_resolve overwrite)"
        _rtlink_ok=1
    elif [ -x "$HX_SRC/tool/stage_resolve_runtime_a" ]; then
        if ( cd "$HX_SRC" \
             && CC="${CC:-clang}" \
                CFLAGS_COMMON="${CFLAGS_COMMON:--O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs}" \
                bash tool/stage_resolve_runtime_a >/dev/null 2>&1 ) \
            && [ -f "$HX_SRC/build/runtime.a" ]; then
            # Mirror the archive next to the driver dir ($HX_BIN) too: a consumer
            # `hexa build` with HEXA_LANG unset resolves hxroot via argv0 ->
            # $HX_BIN, and resolve_prebuilt_runtime() looks for <hxroot>/build/
            # runtime.a. The pre-warm build below sets HEXA_LANG=$HX_SRC so it
            # finds the $HX_SRC copy; real consumer builds find the $HX_BIN copy.
            mkdir -p "$HX_BIN/build"
            cp -f "$HX_SRC/build/runtime.a" "$HX_BIN/build/runtime.a" 2>/dev/null || true
            _rtlink_ok=1
            green "  ✓ $HX_SRC/build/runtime.a + $HX_BIN/build/runtime.a (native rt_*_native linked)"
        else
            red "  ⚠ stage_resolve_runtime_a failed — falling back to surgically-patched frozen seed."
            red "    (legacy C #else element bodies still satisfy the link; no regression.)"
        fi
    else
        dim "  ⚠ stage_resolve_runtime_a missing — using surgically-patched frozen seed (status quo)"
    fi

    # The `hexa build` flatten step (resolve_module_loader_compiled in
    # self/main.hexa) needs a COMPILED module_loader binary at
    # <install>/build/hexa_module_loader. It is .gitignored, so the clone
    # above does NOT contain it — but module_loader.hexa has zero `use`
    # statements (self-contained), so it builds with no pre-existing
    # module_loader. Build it now from the fresh source so end-to-end
    # `hexa build` works on this install without a new release.
    bold "▸ building module_loader (hexa build flatten helper)"
    if [ ! -x "$HX_BIN/hexad" ]; then
        red "  ✗ hexad missing — cannot build module_loader"
        return 1
    fi
    mkdir -p "$HX_BIN/build"
    if HEXA_MAC_BUILD_OK=1 HEXA_LANG="$HX_SRC" \
        "$HX_BIN/hexa" build "$HX_SRC/self/module_loader.hexa" \
        -o "$HX_BIN/build/hexa_module_loader" >/dev/null 2>&1 \
        && [ -x "$HX_BIN/build/hexa_module_loader" ]; then
        green "  ✓ $HX_BIN/build/hexa_module_loader"
    else
        red "  ✗ module_loader build failed — \`hexa build\` of programs using"
        red "    \"stdlib/...\" will fall back to raw-src and fail. Re-run, or"
        red "    build manually: cd $HX_SRC && tool/build_hexa_module_loader.sh"
        return 1
    fi

    # Pre-warm the runtime object cache so the FIRST `hexa build` / `hexa run`
    # in EVERY project is storm-free. The content-hash `runtime.<sha>.o` under
    # ~/.hexa-cache is otherwise compiled lazily on the first cache miss (~8 s
    # `clang -O2` of the ~18-TU runtime amalgam) — paid once per machine per
    # runtime revision, but it lands as a surprise CPU spike on the user's very
    # first build. Warm it HERE via one throwaway `hexa build` so the cache is
    # populated by the CANONICAL build path (exact os_clang_cflags), not a
    # hand-rolled clang that could drift from main.hexa. Run inside a temp cwd
    # so no build/artifacts/ litters the install dir. Non-fatal: a failed probe
    # just defers the one-time compile to the first real build (status quo).
    bold "▸ pre-warming runtime cache (storm-free first build in every project)"
    _pw_dir="$(mktemp -d)"
    printf 'fn main() {}\n' > "$_pw_dir/_prewarm.hexa"
    if ( cd "$_pw_dir" && HEXA_MAC_BUILD_OK=1 HEXA_LANG="$HX_SRC" \
         "$HX_BIN/hexa" build _prewarm.hexa -o _prewarm.bin ) >/dev/null 2>&1; then
        green "  ✓ ~/.hexa-cache/runtime.<sha>.o warmed (first build = link-only)"
        # Drop a FIXED-NAME copy so a build can still link a runtime when
        # self/runtime.c later goes MISSING (broken self symlink, or a linux
        # install that left runtime.c ungenerated — handoff 87a5f82e). In that
        # state the content-hash path can neither key nor compile the source;
        # main.hexa's Layer-2 rescue links this prebuilt instead, whose path
        # depends on NEITHER runtime.c NOR the self symlink. Keyed identically
        # to main.hexa (sha1 of runtime*.c + native/*.c + *.h under $HX_SRC/self,
        # NOT the symlink) so it matches the object the warm build just produced.
        _rt_sha="$(cat "$HX_SRC/self"/runtime*.c "$HX_SRC/self"/runtime*.h \
                       "$HX_SRC/self"/native/*.c "$HX_SRC/self"/native/*.h \
                   2>/dev/null | shasum -a 1 2>/dev/null | cut -d' ' -f1)"
        if [ -n "$_rt_sha" ] && [ -f "$HOME/.hexa-cache/runtime.$_rt_sha.o" ]; then
            cp -f "$HOME/.hexa-cache/runtime.$_rt_sha.o" \
                  "$HOME/.hexa-cache/runtime.prebuilt.o" 2>/dev/null \
                && green "  ✓ ~/.hexa-cache/runtime.prebuilt.o (rescue for missing runtime.c)"
        fi
    else
        dim   "  ⚠ runtime pre-warm skipped — first real build compiles runtime once"
    fi
    rm -rf "$_pw_dir"
}

install_hx() {
    bold "▸ installing hx (package manager)"
    local url="https://raw.githubusercontent.com/${HEXA_REPO}/main/tool/pkg/hx"
    curl -fsSL "$url" -o "$HX_BIN/hx"
    chmod +x "$HX_BIN/hx"
    green "  ✓ $HX_BIN/hx"
}

install_darwin_marker() {
    # Stamp darwin-bypass eligibility marker so the resolver shim
    # (~/.hx/bin/hexa) can route safe argv (--version, --help, lsp)
    # directly to native hexa instead of docker hard-landing.
    [ "$(uname -s)" = "Darwin" ] || return 0
    bold "▸ stamping darwin-bypass eligibility marker"
    local marker="$HX_HOME/.darwin-bypass-eligible"
    mkdir -p "$HX_HOME" 2>/dev/null || true
    if : > "$marker" 2>/dev/null; then
        green "  ✓ $marker"
    else
        red "  ✗ failed to stamp $marker (read-only HOME?) — resolver will self-heal"
    fi
}

update_path_hint() {
    case ":$PATH:" in
        *":$HX_BIN:"*) return 0 ;;
    esac

    echo ""
    bold "▸ PATH setup"

    # Pick the rc file that the user's login shell actually sources, per
    # OS + shell combo, and the export line in that shell's own syntax.
    #   - zsh:  ~/.zshrc        (sourced for interactive shells on all OSes)
    #   - bash: ~/.bashrc on Linux; ~/.bash_profile on macOS — a login bash
    #           on macOS (every Terminal.app window IS a login shell) reads
    #           ~/.bash_profile / ~/.profile, NOT ~/.bashrc.
    #   - fish: ~/.config/fish/config.fish — fish has no `export`; use
    #           `fish_add_path` (idempotent, prepends to $PATH).
    local rc="" line="" os
    os="$(uname -s)"
    case "${SHELL:-}" in
        */zsh)
            rc="$HOME/.zshrc"
            line='export PATH="$HOME/.hx/bin:$PATH"'
            ;;
        */bash)
            if [ "$os" = "Darwin" ]; then
                rc="$HOME/.bash_profile"
            else
                rc="$HOME/.bashrc"
            fi
            line='export PATH="$HOME/.hx/bin:$PATH"'
            ;;
        */fish)
            rc="$HOME/.config/fish/config.fish"
            line='fish_add_path "$HOME/.hx/bin"'
            ;;
    esac

    if [ -n "$rc" ]; then
        # Create the rc file (and any parent dir) if missing — a fresh user
        # may have no rc file at all, in which case the old code did nothing.
        mkdir -p "$(dirname "$rc")" 2>/dev/null || true
        [ -f "$rc" ] || : > "$rc" 2>/dev/null || true

        if [ -f "$rc" ] && [ -w "$rc" ]; then
            if ! grep -q '.hx/bin' "$rc" 2>/dev/null; then
                printf '\n# hexa-lang\n%s\n' "$line" >> "$rc"
                green "  ✓ added to $rc"
                echo "  restart your shell, or run:"
                echo "    $line"
            else
                dim "  already present in $rc"
            fi
        else
            red "  ✗ cannot write $rc — add this line manually:"
            echo "    $line"
        fi
    else
        echo "  add this to your shell rc file:"
        echo '    export PATH="$HOME/.hx/bin:$PATH"   # bash/zsh'
        echo '    fish_add_path "$HOME/.hx/bin"        # fish'
    fi

    # ── ING #80: system-wide PATH for login / non-interactive shells ──────────
    # The per-user rc above is read ONLY by INTERACTIVE shells. Cloud pods launch
    # `hexa run` from detached / non-interactive shells (setsid · nohup · the
    # `bash -c` one-liner emitted by `hexa cloud nohup/fire`), which never source
    # ~/.bashrc → a bare `hexa` is "command not found" and the job dies silently.
    # /etc/profile.d/hexa.sh is sourced by LOGIN shells (`bash -lc`), so a
    # login-shell launch finds hexa on PATH (cloud-side complement: have
    # `cloud exec/nohup` run the remote command via a login shell). Best-effort:
    # written only when /etc/profile.d is writable (e.g. root on a pod); an
    # unprivileged user silently keeps the per-user rc above.
    if [ -d /etc/profile.d ] && [ -w /etc/profile.d ] && [ ! -f /etc/profile.d/hexa.sh ]; then
        if printf '# hexa-lang (ING #80) — PATH for login/non-interactive shells\nexport PATH="$HOME/.hx/bin:$PATH"\n' > /etc/profile.d/hexa.sh 2>/dev/null; then
            green "  ✓ system PATH: /etc/profile.d/hexa.sh (login shells)"
        fi
    fi
}

main() {
    need_cmd curl
    need_cmd tar
    mkdir -p "$HX_BIN"

    bold "⬡ hexa-lang installer"
    dim "  prefix: $HX_HOME"
    echo ""

    local hexa_ok=1 src_ok=1
    if [ "${HEXA_SKIP_HEXA:-}" != "1" ]; then
        install_hexa || hexa_ok=0
        echo ""
    fi

    # stdlib/ + self/ source — required for `hexa build` of any program that
    # does `use "stdlib/..."`. Skipped only when the compiler itself was
    # skipped or HEXA_SKIP_SRC=1.
    if [ "${HEXA_SKIP_SRC:-}" != "1" ] && [ "$hexa_ok" = "1" ]; then
        install_src || src_ok=0
        echo ""
    fi

    if [ "${HEXA_SKIP_HX:-}" != "1" ]; then
        install_hx
    fi

    install_darwin_marker
    update_path_hint

    echo ""
    if [ "$hexa_ok" = "1" ]; then
        green "✓ done. try:"
        echo "    hexa version"
        echo "    hx search"
        if [ "$src_ok" != "1" ] && [ "${HEXA_SKIP_SRC:-}" != "1" ]; then
            echo ""
            red "  ⚠ stdlib/ source install failed — \`hexa build\` of programs"
            red "    using \"stdlib/...\" will not work until you re-run with git"
            red "    available, or clone ${HEXA_REPO} and set HEXA_LANG to it."
        fi
    else
        red "✗ hexa compiler install failed (hx installed ok)"
        exit 1
    fi
}

main "$@"
