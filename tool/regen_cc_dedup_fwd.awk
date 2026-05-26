## tool/regen_cc_dedup_fwd.awk — hexa_cc.c regen pass 2: drop redundant fwd-decls
##
## Ported from self/main.hexa::merge_modules_awk (the 2-pass dedup heredoc).
## 2-pass operation — invoke with the same file twice:
##   awk -f regen_cc_dedup_fwd.awk <mod.c> <mod.c>  > <mod_dedup.c>
##
## Pass 1 (NR==FNR): scan every line, record:
##   - def_line[fn] = line where `HexaVal fn(...) {` definition starts
##   - fwd_line[fn] = line where `HexaVal fn(...);` forward-decl appears
## Pass 2 (FNR==1 trigger): for each fn that has BOTH a fwd-decl and a def,
##   scan lines [fwd+1 .. def-1] for any early reference to that fn. If none
##   exist, mark fwd-decl as droppable. Then re-emit every line, skipping
##   droppable fwd-decls.
##
## Net effect: removes ~141 LOC of redundant fwd-decls across 4 modules. The
## def-only or fwd-only case is left alone (fwd's needed when fn is called
## before its def line — common after the merge that interleaves modules).

NR == FNR {
    lines[FNR] = $0
    if (match($0, /^HexaVal [a-zA-Z_][a-zA-Z0-9_]*\(.*\) \{$/)) {
        split($0, a, "(")
        name = a[1]; sub(/^HexaVal /, "", name)
        def_line[name] = FNR
    }
    if (match($0, /^HexaVal [a-zA-Z_][a-zA-Z0-9_]*\(.*\);$/)) {
        split($0, a, "(")
        name = a[1]; sub(/^HexaVal /, "", name)
        fwd_line[name] = FNR
    }
    next
}
FNR == 1 {
    for (fn in fwd_line) {
        if (fn in def_line) {
            fl = fwd_line[fn]
            dl = def_line[fn]
            has_early_call = 0
            pat  = "[^a-zA-Z0-9_]" fn "[ \t]*\\("
            pat2 = "^" fn "[ \t]*\\("
            for (li = fl + 1; li < dl; li++) {
                if (match(lines[li], pat))  { has_early_call = 1; break }
                if (match(lines[li], pat2)) { has_early_call = 1; break }
            }
            if (!has_early_call) drop_fwd[fn] = 1
        }
    }
}
{
    if (match($0, /^HexaVal [a-zA-Z_][a-zA-Z0-9_]*\(.*\);$/)) {
        split($0, a, "(")
        name = a[1]; sub(/^HexaVal /, "", name)
        if (name in drop_fwd) next
    }
    print
}
