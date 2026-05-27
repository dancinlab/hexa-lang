#!/usr/bin/env bash
# tool/hexa_annot/_ast_extract.sh — shared helper for the 29 hexa-* wrappers.
#
# Sources two helpers:
#   resolve_files <args...>      → populates the global FILES array from
#                                  positional args + an optional `--dir <dir>`.
#                                  Pure-bash, no fancy parsing.
#   run_ast_extract              → runs _ast_extract.hexa on FILES[@] and
#                                  prints TSV rows to stdout. Honors
#                                  HEXA_ANNOT_EXTRACTOR env (defaults to the
#                                  sibling _ast_extract.hexa).
#   ast_kv_to_json_obj "<raw>"   → converts the raw_args string emitted by
#                                  _ast_extract.hexa (e.g. `a = "x" , b = 1`)
#                                  to a JSON-object body fragment (without
#                                  the surrounding `{...}` braces). Quoted
#                                  values stay as JSON strings; bare numbers
#                                  and booleans pass through; bare idents
#                                  become JSON strings.
#   ast_kv_extract "<raw>" KEY   → returns the (unquoted) value for KEY, or
#                                  empty string if not present. Mirrors the
#                                  per-tool `extract_kv` awk helpers.
#   ast_json_escape "<s>"        → JSON string escape (returns to stdout).
#
# All helpers are bash 3.2 compatible (macOS /usr/bin/env bash).

# Caller-populated array.
FILES=()

resolve_files() {
    FILES=()
    if [ $# -lt 1 ]; then
        return 0
    fi
    if [ "$1" = "--dir" ]; then
        if [ $# -lt 2 ]; then return 1; fi
        local dir="$2"
        if [ ! -d "$dir" ]; then
            echo "error: not a directory: $dir" >&2
            return 1
        fi
        while IFS= read -r -d '' f; do
            FILES+=("$f")
        done < <(find "$dir" -type f \
            -not -path "*/.claude/*" \
            -not -path "*/node_modules/*" \
            -name '*.hexa' -print0)
    else
        local f
        for f in "$@"; do
            if [ ! -f "$f" ]; then
                echo "error: not a file: $f" >&2
                return 1
            fi
            FILES+=("$f")
        done
    fi
    return 0
}

run_ast_extract() {
    # Locate the .hexa sibling relative to *this* script, not $0
    # (callers may invoke from arbitrary cwd).
    local helper_dir
    helper_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local extractor="${HEXA_ANNOT_EXTRACTOR:-${helper_dir}/_ast_extract.hexa}"
    if [ ! -f "$extractor" ]; then
        echo "error: extractor not found: $extractor" >&2
        return 1
    fi
    if [ ${#FILES[@]} -eq 0 ]; then
        return 0
    fi
    HEXA_NO_SENTINEL=1 hexa run "$extractor" "${FILES[@]}"
}

ast_json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//	/\\t}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    printf '%s' "$s"
}

# Decode TSV-escaped raw_args (the extractor encodes \n→\\n, \r→\\r,
# \t→\\t, \→\\\\). Inverse of _ast_extract_esc in _ast_extract.hexa.
ast_decode_esc() {
    local s="$1"
    local out=""
    local i=0
    local n=${#s}
    local c next
    while [ $i -lt $n ]; do
        c="${s:$i:1}"
        if [ "$c" = "\\" ] && [ $((i + 1)) -lt $n ]; then
            next="${s:$((i+1)):1}"
            case "$next" in
                n)  out="$out
"; i=$((i + 2)); continue ;;
                r)  out="$out"$'\r'; i=$((i + 2)); continue ;;
                t)  out="$out	"; i=$((i + 2)); continue ;;
                \\) out="$out\\"; i=$((i + 2)); continue ;;
            esac
        fi
        out="$out$c"
        i=$((i + 1))
    done
    printf '%s' "$out"
}

# Awk helper. Given a raw_args string (already TSV-decoded), parse
# key=value pairs at top-depth and emit them as awk's print of:
#   KEY<TAB>VALUE_RAW<TAB>VALUE_QUOTED_BOOL
# Used by per-tool wrappers; kept as inline-awk in callers.

# Lookup a single key from a raw_args string. Echo the *unquoted* value.
# Empty when key not found. Handles `key = "..."` and `key = bare`.
# Also tolerates `key : "..."` (e.g. @intent(description: "...")).
ast_kv_extract() {
    local raw="$1"
    local key="$2"
    awk -v raw="$raw" -v key="$key" 'BEGIN {
        s = raw
        # try " key = " or "( key = " or starting form
        pat_eq    = "(^|[ \t,(])" key "[ \t]*=[ \t]*"
        pat_colon = "(^|[ \t,(])" key "[ \t]*:[ \t]*"
        pos = match(s, pat_eq)
        if (pos == 0) {
            pos = match(s, pat_colon)
            if (pos == 0) { exit 0 }
        }
        rest = substr(s, pos + RLENGTH)
        sub(/^[ \t]+/, "", rest)
        if (substr(rest, 1, 1) == "\"") {
            val = ""
            i = 2
            n = length(rest)
            while (i <= n) {
                c = substr(rest, i, 1)
                if (c == "\\" && i < n) {
                    nc = substr(rest, i + 1, 1)
                    if (nc == "\"") { val = val "\""; i += 2; continue }
                    if (nc == "\\") { val = val "\\"; i += 2; continue }
                    val = val c
                    i++
                    continue
                }
                if (c == "\"") break
                val = val c
                i++
            }
            print val
            exit 0
        }
        if (match(rest, /[,)[:space:]]/)) {
            print substr(rest, 1, RSTART - 1)
        } else {
            print rest
        }
    }'
}

# Generic emitter for the "annotations[]+summary" JSON shape used by 15+
# of the hexa-* wrappers. Reads AST TSV on stdin and emits a JSON blob:
#
#   {"version":"0.2","source":"ast",
#    "annotations":[{kind,fn,file,line,meta{...}}, ...],
#    "summary":{ <kind1>:N, ..., total:M }}
#
# Args:
#   $1 — kinds_csv  : comma-separated list of accepted kinds (the summary
#                     emits a per-kind count in this exact order). Also acts
#                     as the kind filter.
#   $2 — filter     : optional single-kind filter (e.g. `effect`); empty
#                     means "all kinds in kinds_csv".
#   $3 — extra_keys : optional comma-separated extra summary keys (e.g.
#                     `phases_covered:array`) — pass empty for none. Format:
#                     `name:array` (currently only array supported).
#
# When `filter` is non-empty and not in `kinds_csv`, returns a 1-line empty
# JSON shell (caller should validate filter before calling).
ast_emit_kindmap_json() {
    local kinds_csv="$1"
    local filter="${2:-}"
    awk -v kinds_csv="$kinds_csv" -v filter="$filter" -v tools_helper_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" '
    function json_escape(s,   r) {
        r = s
        gsub(/\\/, "\\\\", r)
        gsub(/"/, "\\\"", r)
        gsub(/\t/, "\\t", r)
        gsub(/\r/, "\\r", r)
        gsub(/\n/, "\\n", r)
        return r
    }
    function decode_esc(s,   out, i, n, c, nc) {
        out = ""
        n = length(s)
        i = 1
        while (i <= n) {
            c = substr(s, i, 1)
            if (c == "\\" && i < n) {
                nc = substr(s, i + 1, 1)
                if (nc == "n")  { out = out "\n"; i += 2; continue }
                if (nc == "r")  { out = out "\r"; i += 2; continue }
                if (nc == "t")  { out = out "\t"; i += 2; continue }
                if (nc == "\\") { out = out "\\"; i += 2; continue }
            }
            out = out c
            i++
        }
        return out
    }
    # Build kv-object body from raw_args. Returns the comma-separated `"k":v`
    # list (no enclosing braces). Empty when raw_args is empty.
    function kv_to_json(raw,    s, n, i, c, key, val, depth, n_out, is_str, nc, out, sep) {
        s = raw
        sub(/^[ \t]+/, "", s)
        n = length(s)
        i = 1
        n_out = 0
        out = ""
        while (i <= n) {
            while (i <= n && (substr(s, i, 1) == " " || substr(s, i, 1) == "\t" || substr(s, i, 1) == ",")) i++
            if (i > n) break
            key = ""
            while (i <= n) {
                c = substr(s, i, 1)
                if ((c >= "A" && c <= "Z") || (c >= "a" && c <= "z") || (c >= "0" && c <= "9") || c == "_") {
                    key = key c
                    i++
                } else { break }
            }
            if (key == "") {
                val = ""
                depth = 0
                while (i <= n) {
                    c = substr(s, i, 1)
                    if (c == "(" || c == "[" || c == "{") depth++
                    else if (c == ")" || c == "]" || c == "}") depth--
                    else if (c == "," && depth == 0) break
                    val = val c
                    i++
                }
                gsub(/^[ \t]+|[ \t]+$/, "", val)
                if (val == "") continue
                n_out++
                if (n_out > 1) out = out ","
                # Strip surrounding double quotes if present (bare positional StringLit).
                if (length(val) >= 2 && substr(val, 1, 1) == "\"" && substr(val, length(val), 1) == "\"") {
                    val = substr(val, 2, length(val) - 2)
                }
                out = out "\"_pos_" n_out "\":\"" json_escape(val) "\""
                continue
            }
            while (i <= n && (substr(s, i, 1) == " " || substr(s, i, 1) == "\t")) i++
            sep = substr(s, i, 1)
            if (sep != "=" && sep != ":") {
                # Bare key (e.g. `@effect(io)`). Preserve grep-MVP behavior:
                # emit as empty string (the grep extractors treated bare
                # tokens as "key with no value" — represented as "").
                n_out++
                if (n_out > 1) out = out ","
                out = out "\"" json_escape(key) "\":\"\""
                continue
            }
            i++
            while (i <= n && (substr(s, i, 1) == " " || substr(s, i, 1) == "\t")) i++
            if (i > n) break
            val = ""
            is_str = 0
            if (substr(s, i, 1) == "\"") {
                is_str = 1
                i++
                while (i <= n) {
                    c = substr(s, i, 1)
                    if (c == "\\" && i < n) {
                        nc = substr(s, i + 1, 1)
                        if (nc == "\"") { val = val "\""; i += 2; continue }
                        if (nc == "\\") { val = val "\\"; i += 2; continue }
                        val = val c
                        i++
                        continue
                    }
                    if (c == "\"") { i++; break }
                    val = val c
                    i++
                }
            } else {
                depth = 0
                while (i <= n) {
                    c = substr(s, i, 1)
                    if (c == "(" || c == "[" || c == "{") depth++
                    else if (c == ")" || c == "]" || c == "}") depth--
                    else if (c == "," && depth == 0) break
                    val = val c
                    i++
                }
                gsub(/^[ \t]+|[ \t]+$/, "", val)
            }
            n_out++
            if (n_out > 1) out = out ","
            if (is_str) {
                out = out "\"" json_escape(key) "\":\"" json_escape(val) "\""
            } else if (val == "true" || val == "false" || val == "null") {
                out = out "\"" json_escape(key) "\":" val
            } else if (val ~ /^-?[0-9]+$/ || val ~ /^-?[0-9]+\.[0-9]+$/) {
                out = out "\"" json_escape(key) "\":" val
            } else {
                out = out "\"" json_escape(key) "\":\"" json_escape(val) "\""
            }
        }
        return out
    }
    BEGIN {
        FS = "\t"
        # Build kinds set from kinds_csv (preserving order).
        n_kinds = split(kinds_csv, kinds_arr, ",")
        for (i = 1; i <= n_kinds; i++) {
            k = kinds_arr[i]
            kinds_idx[k] = i
            counts[k] = 0
        }
        body = ""
        total = 0
    }
    /^# error\t/ { next }
    {
        kind = $1
        tgtk = $2
        fn   = $3
        file = $4
        line = $5
        raw  = decode_esc($6)
        if (!(kind in kinds_idx)) next
        if (filter != "" && kind != filter) next
        # The kind-map family of wrappers only count annotations attached to
        # fn decls (mirrors the grep-MVP heuristic which scanned for "next
        # fn"). Skip struct/enum/let/etc. attachments — names like @align,
        # @schema, @adapter collide with struct-targeting tools.
        if (tgtk != "fn") next
        counts[kind]++
        if (total > 0) body = body ","
        total++
        body = body "{"
        body = body "\"kind\":\""  json_escape(kind) "\""
        body = body ",\"fn\":\""   json_escape(fn) "\""
        body = body ",\"file\":\"" json_escape(file) "\""
        body = body ",\"line\":"   line
        kv_body = kv_to_json(raw)
        body = body ",\"meta\":{" kv_body "}"
        body = body "}"
    }
    END {
        sum = ""
        for (i = 1; i <= n_kinds; i++) {
            k = kinds_arr[i]
            if (i > 1) sum = sum ","
            sum = sum "\"" k "\":" counts[k]
        }
        if (n_kinds > 0) sum = sum ","
        sum = sum "\"total\":" total
        printf("{\"version\":\"0.2\",\"source\":\"ast\",\"annotations\":[%s],\"summary\":{%s}}\n", body, sum)
    }
    '
}

# Convert the raw_args kv-list to a JSON-object body fragment (no enclosing
# braces). Quoted values → JSON strings; bare true/false/int/float pass
# through as JSON literals; bare idents become JSON strings. Output is the
# comma-separated `"k":v` list to stdout.
ast_kv_to_json_obj() {
    local raw="$1"
    awk -v raw="$raw" '
    function jesc(s,    r) {
        r = s
        gsub(/\\/, "\\\\", r)
        gsub(/"/, "\\\"", r)
        gsub(/\t/, "\\t", r)
        gsub(/\r/, "\\r", r)
        gsub(/\n/, "\\n", r)
        return r
    }
    BEGIN {
        s = raw
        sub(/^[ \t]+/, "", s)
        n_out = 0
        n = length(s)
        i = 1
        # State machine: read key, optional sep (= or :), value (string or bare),
        # then comma. We tolerate the depth-0 only; nested parens are kept in
        # the raw bare-value stretch.
        while (i <= n) {
            # skip ws + comma + leading paren artifacts
            while (i <= n && (substr(s, i, 1) == " " || substr(s, i, 1) == "\t" || substr(s, i, 1) == ",")) i++
            if (i > n) break
            # key: must be ident-like
            key = ""
            while (i <= n) {
                c = substr(s, i, 1)
                if ((c >= "A" && c <= "Z") || (c >= "a" && c <= "z") || (c >= "0" && c <= "9") || c == "_") {
                    key = key c
                    i++
                } else { break }
            }
            if (key == "") {
                # bare positional value like @effect(io) — store under "_pos_<idx>"
                # gather until comma at depth 0
                val = ""
                depth = 0
                while (i <= n) {
                    c = substr(s, i, 1)
                    if (c == "(" || c == "[" || c == "{") depth++
                    else if (c == ")" || c == "]" || c == "}") depth--
                    else if (c == "," && depth == 0) break
                    val = val c
                    i++
                }
                gsub(/^[ \t]+|[ \t]+$/, "", val)
                if (val == "") continue
                n_out++
                if (n_out > 1) printf ","
                # naked value — treat as string
                printf "\"_pos_%d\":\"%s\"", n_out, jesc(val)
                continue
            }
            # skip ws
            while (i <= n && (substr(s, i, 1) == " " || substr(s, i, 1) == "\t")) i++
            sep = substr(s, i, 1)
            if (sep != "=" && sep != ":") {
                # bare key (e.g. `pure` argless inside parens) — emit as bool true
                n_out++
                if (n_out > 1) printf ","
                printf "\"%s\":true", jesc(key)
                continue
            }
            i++ # consume = or :
            while (i <= n && (substr(s, i, 1) == " " || substr(s, i, 1) == "\t")) i++
            if (i > n) break
            v = ""
            is_str = 0
            if (substr(s, i, 1) == "\"") {
                is_str = 1
                i++
                while (i <= n) {
                    c = substr(s, i, 1)
                    if (c == "\\" && i < n) {
                        nc = substr(s, i + 1, 1)
                        if (nc == "\"") { v = v "\""; i += 2; continue }
                        if (nc == "\\") { v = v "\\"; i += 2; continue }
                        v = v c
                        i++
                        continue
                    }
                    if (c == "\"") { i++; break }
                    v = v c
                    i++
                }
            } else {
                depth = 0
                while (i <= n) {
                    c = substr(s, i, 1)
                    if (c == "(" || c == "[" || c == "{") depth++
                    else if (c == ")" || c == "]" || c == "}") depth--
                    else if (c == "," && depth == 0) break
                    v = v c
                    i++
                }
                gsub(/^[ \t]+|[ \t]+$/, "", v)
            }
            n_out++
            if (n_out > 1) printf ","
            if (is_str) {
                printf "\"%s\":\"%s\"", jesc(key), jesc(v)
            } else {
                # bare value — emit as JSON literal if it looks like bool/null/int/float,
                # otherwise quote as string.
                if (v == "true" || v == "false" || v == "null") {
                    printf "\"%s\":%s", jesc(key), v
                } else if (v ~ /^-?[0-9]+$/ || v ~ /^-?[0-9]+\.[0-9]+$/) {
                    printf "\"%s\":%s", jesc(key), v
                } else {
                    printf "\"%s\":\"%s\"", jesc(key), jesc(v)
                }
            }
        }
    }'
}
