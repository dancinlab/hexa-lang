#!/usr/bin/env python3
# isolate_seed.py — transitive-closure text-slice a whole-module Route-C seed .s down to
# ONE contract function + its genuine transitive callees (+ referenced data/const + stamps),
# dropping the dead sibling bodies (syscall leaves) that carry darwin-absent externals
# (bl __errno_location). Target-agnostic: works on Mach-O arm64 + ELF x86_64/arm64.
#
# Usage: isolate_seed.py <in.s> <contract-sym e.g. hxlcl_strcmp> <out.s>
import sys, re

def main():
    inp, contract, out = sys.argv[1], sys.argv[2], sys.argv[3]
    lines = open(inp).read().split("\n")

    # A "function label" = a top-level symbol label at col 0 ending ':' that is NOT an
    # internal basic-block label (those look like `__L<digits>_...` or `.L...` / `L...`).
    def is_fn_label(l):
        m = re.match(r'^([A-Za-z_][A-Za-z0-9_$.]*):', l)
        if not m: return None
        sym = m.group(1)
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
    header = [l for l in header if not re.match(r'^\s*\.(globl|private_extern)\b', l)]
    header.append(f".globl {root}")
    outlines = list(header)
    for f in kept_order:
        outlines += fnblocks[f]
    outlines += data
    open(out, "w").write("\n".join(outlines))
    dropped = len(defined) - len(keep)
    sys.stderr.write(f"[isolate] {inp}: kept {len(keep)} fn ({','.join(kept_order[:6])}{'…' if len(kept_order)>6 else ''}), dropped {dropped} dead sibling bodies\n")

main()
