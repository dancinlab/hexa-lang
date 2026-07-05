#!/usr/bin/env python3
# isolate_seed.py — transitive-closure text-slice a whole-module Route-C seed .s down to
# ONE contract function + its genuine transitive callees (+ referenced data/const + stamps),
# dropping the dead sibling bodies (syscall leaves) that carry darwin-absent externals
# (bl __errno_location). Target-agnostic: works on Mach-O arm64 + ELF x86_64/arm64.
#
# Usage: isolate_seed.py <in.s> <contract-sym e.g. hxlcl_strcmp> <out.s>
#        isolate_seed.py --selftest        (re-isolates committed seeds; no pool needed)
import sys, re, os, subprocess, tempfile

def isolate(inp, contract, out):
    lines = open(inp).read().split("\n")

    # A "function label" = a top-level symbol label at col 0 ending ':' that is NOT an
    # internal basic-block label (those look like `__L<digits>_...` or `.L...` / `L...`).
    # zeroc #29 (#4599 root-cause): bb labels are hashed as `__L<module-hash>_<fn>_bb<n>`
    # where <module-hash> is HEX — a bake whose hash starts with a letter (e.g. `ae95`)
    # made `__Lae95_hxlcl_realloc_bb0:` slip past the digit-anchored patterns below, so it
    # was misread as a NEW function and the whole body from bb0 was sliced off (prologue
    # fell off the end of .text → SIGABRT only under faithful execution, invisible to
    # byteeq/install-link). Classify a bb label by its SUFFIX (`_bb<digits>`), which is
    # hash-agnostic and never appears on a real contract symbol.
    def is_fn_label(l):
        m = re.match(r'^([A-Za-z_][A-Za-z0-9_$.]*):', l)
        if not m: return None
        sym = m.group(1)
        if re.search(r'_bb\d+$', sym): return None            # hex-hash bb labels (suffix-classified)
        if re.match(r'^_?_?L?\.?L?\d', sym): return None      # bb labels
        if re.match(r'^__L\d', sym): return None
        if sym.startswith('.L') or sym.startswith('L'): return None
        return sym

    # Split into: header (before first fn label or first non-text section),
    # __text function blocks, and trailing (non-__text data/const/stamp) sections.
    # Simpler model: walk once, classify each line into segments keyed by owner.
    # Segment types: 'header', 'fn:<sym>', 'data' (everything from the first non-__text
    # .section onward — const/data/stamp pools).
    header, fnblocks, data = [], {}, []
    order = []            # fn symbol order
    cur = 'header'
    in_data = False
    for l in lines:
        s = l.strip()
        # once we hit a non-__text section, everything after is 'data' (pools/stamps)
        if s.startswith('.section') and '__text' not in l and '.text' not in l:
            in_data = True
        if in_data:
            data.append(l); continue
        fl = is_fn_label(l)
        if fl is not None:
            cur = 'fn:' + fl
            fnblocks.setdefault(fl, [])
            order.append(fl)
        if cur == 'header':
            header.append(l)
        else:
            fnblocks[cur[3:]].append(l)

    # reference scan: which fn symbols does a block call/reference (bl/b/call/adr/adrp/=sym)
    ref_re = re.compile(r'\b(?:bl|b|call|callq|adrp|adr|ldr)\b[^;/\n]*?\b(_?[A-Za-z_][A-Za-z0-9_$.]*)')
    def refs_of(block):
        out = set()
        for l in block:
            code = re.split(r'//|;', l, 1)[0]
            for m in re.finditer(r'\b(_?[A-Za-z_][A-Za-z0-9_$.]*)\b', code):
                out.add(m.group(1))
        return out

    # transitive closure of contract over locally-defined fn symbols
    defined = set(fnblocks.keys())
    # contract may be defined as _hxlcl_strcmp (mach-o underscore) or hxlcl_strcmp
    def resolve(sym):
        for cand in (sym, '_'+sym):
            if cand in defined: return cand
        return None
    root = resolve(contract)
    if root is None:
        sys.stderr.write(f"[isolate] FATAL: contract {contract} not defined in {inp}\n"); sys.exit(2)
    # Keep ONLY the contract function's own block. Every hxlcl_* sibling it calls is served
    # by the still-compiled shim (the seed drops exactly ONE shim def, its own contract) and
    # carrier symbols (_hexa_bool) by runtime.o — so leaving those calls as undefined externals
    # is correct and target-uniform (avoids the ELF-PIC GOT cross-reference closure blow-up,
    # and drops the dead syscall-leaf siblings whose `bl __errno_location` is darwin-absent).
    keep = {root}

    # emit: header + kept fn blocks (in original order) + all data/stamp sections.
    # The contract's `.globl <root>` directive lived in a now-dropped sibling's segment,
    # so re-assert it (and drop any stray .globl/.private_extern for dropped syms from the
    # header) to preserve the 1-symbol export contract.
    kept_order = [f for f in order if f in keep]
    # Strip EVERY symbol-attribute directive (.globl/.hidden/.weak/.protected/.internal/
    # .local/.private_extern/.type/.size) that targets a symbol OTHER than the contract.
    # A dropped sibling's leftover `.hidden hxlcl_strrchr` (its body removed) otherwise
    # emits an UNDEFINED hidden symbol into the .o → the ELF hexat link dies with
    # "hidden symbol 'hxlcl_strrchr' isn't defined" (Mach-O tolerated it; ELF does not).
    root_bare = root.lstrip('_')
    attr_re = re.compile(r'^\s*\.(?:globl|hidden|weak|weak_definition|protected|internal|local|private_extern|type|size|no_dead_strip)\b[^;/\n]*?\b(_?[A-Za-z_][A-Za-z0-9_$.]*)')
    def stray_attr(l):
        m = attr_re.match(l)
        return bool(m) and m.group(1).lstrip('_') != root_bare
    body = []
    for f in kept_order:
        body += fnblocks[f]
    outlines = [l for l in (header + body + data) if not stray_attr(l)]
    # re-assert exactly one contract global (its original .globl lived in a dropped segment)
    if not any(re.match(rf'^\s*\.globl\s+_?{re.escape(root_bare)}\b', l) for l in outlines):
        outlines.insert(0, f".globl {root}")
    open(out, "w").write("\n".join(outlines))
    dropped = len(defined) - len(keep)
    sys.stderr.write(f"[isolate] {inp}: kept {len(keep)} fn ({','.join(kept_order[:6])}{'…' if len(kept_order)>6 else ''}), dropped {dropped} dead sibling bodies\n")


def selftest():
    # zeroc #29 regression guard for the bb-label hex-hash misparse (#4599). Two checks
    # over the committed self/native/hxlcl_*.s seeds (no pool bake needed):
    #   (1) IDEMPOTENCY — re-isolating an already-single-fn seed on its own contract must
    #       reproduce byte-identical output (the slicer must not corrupt a clean seed).
    #   (2) HEX-HASH NON-SLICE — synthetically rewrite the seed's (decimal) bb-label module
    #       hash to a hex, letter-leading one (e.g. `__L5211_` -> `__Lae95_`) and re-isolate;
    #       the body MUST survive (bb labels + `ret` retained). Under the OLD digit-anchored
    #       classifier this letter-leading label was misread as a NEW function and the whole
    #       body from bb0 was sliced off — the exact #4599 SIGABRT-only-under-execution bug.
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(here)
    fams = ["strcmp", "strchr", "strncmp", "strdup", "strstr", "free", "calloc"]
    tgts = ["arm64", "arm64-linux", "x86_64"]
    fails, n = [], 0
    with tempfile.TemporaryDirectory() as td:
        for fam in fams:
            for tgt in tgts:
                seed = os.path.join(root, "self", "native", f"hxlcl_{fam}_{tgt}.s")
                if not os.path.isfile(seed):
                    continue
                n += 1
                contract = f"hxlcl_{fam}"
                # (1) idempotency
                o1 = os.path.join(td, "id.s")
                isolate(seed, contract, o1)
                if open(seed).read() != open(o1).read():
                    fails.append(f"IDEMPOTENCY {seed}: re-isolate not byte-identical")
                # (2) hex-hash non-slice
                src = open(seed).read()
                m = re.search(r'(_{0,2}\.?L)([0-9a-fA-F]+)(_hxlcl_)', src)
                if not m:
                    fails.append(f"HEX-HASH {seed}: no bb-label hash found to mutate")
                    continue
                hexed = re.sub(re.escape(m.group(2)) + r'(?=_hxlcl_)', "ae95", src)
                mi = os.path.join(td, "hex_in.s"); mo = os.path.join(td, "hex_out.s")
                open(mi, "w").write(hexed)
                isolate(mi, contract, mo)
                out = open(mo).read()
                if not re.search(r'_bb[0-9]+', out) or not re.search(r'(^|\s)retq?(\s|$)', out, re.M):
                    fails.append(f"HEX-HASH {seed}: body SLICED under hex hash (bb/ret missing — #4599 regression)")
    if fails:
        sys.stderr.write(f"[isolate --selftest] FAIL ({len(fails)}/{n} seeds):\n  " + "\n  ".join(fails) + "\n")
        sys.exit(1)
    sys.stderr.write(f"[isolate --selftest] PASS — {n} committed seeds: idempotent + hex-hash-safe\n")


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "--selftest":
        selftest(); return
    if len(sys.argv) < 4:
        sys.stderr.write("usage: isolate_native_seed.py <in.s> <contract-sym> <out.s>  |  --selftest\n"); sys.exit(2)
    isolate(sys.argv[1], sys.argv[2], sys.argv[3])


main()
