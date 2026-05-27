## tool/regen_cc_rename.awk — hexa_cc.c regen pass 3: per-module symbol prefix
##
## String-literal-aware rename pass. Per-module C statics like
## `__hexa_ic_N` / `__hexa_sl_N` / `__hexa_strlit_init` collide across the 4
## merged modules (lexer/parser/type_checker/codegen). This awk prefixes each
## with the module name so the merged binary links without name collisions.
##
## The state-machine walks each line tracking whether we're INSIDE a C
## string literal (between unescaped `"`). gsub renames ONLY happen on text
## OUTSIDE string literals — preventing the binary's codegen template
## (which itself emits `hexa_str("__hexa_sl_N")` text) from being corrupted.
## Without the literal-awareness, the next bootstrap round would lose
## fixpoint (v2 transpile ≠ v1 transpile).
##
## Invoke: awk -v MOD=lexer -f regen_cc_rename.awk <in.c>  > <out.c>

{
    line = $0
    n = length(line)
    out = ""
    i = 1
    in_str = 0
    start = 1
    while (i <= n) {
        ch = substr(line, i, 1)
        if (in_str) {
            if (ch == "\\") { i += 2; continue }
            if (ch == "\"") {
                out = out substr(line, start, i - start + 1)
                in_str = 0
                start = i + 1
                i++
                continue
            }
            i++
        } else {
            if (ch == "\"") {
                chunk = substr(line, start, i - start)
                gsub("__hexa_ic_",      "__hexa_" MOD "_ic_",      chunk)
                gsub("__hexa_sl_",      "__hexa_" MOD "_sl_",      chunk)
                gsub("__hexa_strlit_init", "__hexa_" MOD "_strlit_init", chunk)
                out = out chunk
                start = i
                in_str = 1
                i++
                continue
            }
            i++
        }
    }
    if (in_str) {
        out = out substr(line, start)
    } else {
        chunk = substr(line, start)
        gsub("__hexa_ic_",      "__hexa_" MOD "_ic_",      chunk)
        gsub("__hexa_sl_",      "__hexa_" MOD "_sl_",      chunk)
        gsub("__hexa_strlit_init", "__hexa_" MOD "_strlit_init", chunk)
        out = out chunk
    }
    print out
}
