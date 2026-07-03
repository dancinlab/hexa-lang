#!/usr/bin/env python3
"""compile_gate.py — per-module compile gate (design D: closure-delta avoidance).

Fast per-PR compile check for multi-module hexa programs: transpile ONLY the
changed module (hexa build --c-only, imports pre-stripped by module_loader)
and clang -fsyntax-only it against a cached "interface skeleton" of the rest
of the closure. The whole-closure `hexa build` is demoted to (a) escalation,
(b) anchor refresh (nightly / --anchor), (c) release/verdict builds — which
are UNCHANGED and remain the only source of executed binaries.

SOUNDNESS RULE (non-bypassable, no skip flag exists):
  * the fast path may only return GREEN for body-only edits whose per-module
    syntax/codegen check passes AND whose cross-module call-site arity lints
    clean AND whose anchor is fresh;
  * EVERYTHING else — interface-hash delta, scanner misparse, skeleton
    conflict, ghost import, parse error, clang error, stale/cold/old anchor,
    any infra failure — ESCALATES to the real whole-closure `hexa build`,
    and THAT verdict is reported. The fast path never emits RED directly and
    never GREEN on an interface change.

DETERMINISM: this tool never invokes `hexa run` and never writes into the
run-binary cache namespace (~/.hexa/ run cache). Escalation builds go to the
gate's own cache dir under $HOME (Darwin build guard refuses /tmp).

Emission contract encoded in the skeleton (validated against hexa v0.574.1,
see self/runtime.h:949 hexa_call1 _Generic vs :985 hexa_call4 HexaVal-only):
  * cross-module fn arity 0..4  -> boxed `hexa_callN(name, ...)`  => `HexaVal name;`
  * cross-module fn arity >= 5  -> DIRECT call `name(...)`        => real prototype
  * top-level let               -> bare identifier                => `HexaVal name;`
  * struct ctor                 -> DIRECT call `Name(fields...)`  => real prototype
  * enum variant E::V           -> bare identifier `E__V`         => HexaEnumDesc + #define
"""
import argparse, hashlib, json, os, re, shutil, subprocess, sys, time

GATE_VERSION = "1"
CAVEAT = """\
[compile-gate] CAVEAT — this fast check is PER-MODULE, weaker than the full closure build.
  Skipped whole-TU diagnostics (covered ONLY by escalation + the nightly/pre-release full build):
    - atlas theorem-citation checks on the executable path
    - @invariant cross-module semantics
    - fn-as-value arity residual (boxed HexaVal flows, dynamic dispatch)
    - struct-literal field ORDER (field COUNT is checked; order is not)
  Executed/eval/verdict binaries continue to come exclusively from the whole-closure build.
  Anchor freshness is enforced: a fast GREEN requires a full-build anchor within --anchor-max-age-h."""


def sh(cmd, cwd=None, env=None, timeout=1800):
    e = dict(os.environ)
    if env:
        e.update(env)
    p = subprocess.run(cmd, cwd=cwd, env=e, timeout=timeout,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return p.returncode, p.stdout


def sha(s):
    return hashlib.sha256(s.encode() if isinstance(s, str) else s).hexdigest()


class Infra:
    """Resolved toolchain paths. Any failure here => escalation, never a crash-GREEN."""

    def __init__(self):
        self.hexa = shutil.which("hexa") or ""
        if not self.hexa:
            raise RuntimeError("hexa binary not on PATH")
        rc, out = sh([self.hexa, "--version"])
        if rc != 0:
            raise RuntimeError("hexa --version failed: " + out)
        self.version = out.strip().splitlines()[0]
        inst = os.path.dirname(os.path.realpath(self.hexa))
        self.module_loader = ""
        for c in [os.environ.get("HEXA_MODULE_LOADER", ""),
                  os.path.join(inst, "build", "hexa_module_loader"),
                  os.path.join(os.environ.get("HEXA_LANG", "/nonexistent"), "build", "hexa_module_loader")]:
            if c and os.access(c, os.X_OK):
                self.module_loader = c
                break
        if not self.module_loader:
            raise RuntimeError("hexa_module_loader not found (looked near %s)" % inst)
        self.selfdir = ""
        for c in [os.path.join(os.environ.get("HEXA_LANG", "/nonexistent"), "self"),
                  os.path.join(inst, "self")]:
            if os.path.isfile(os.path.join(c, "runtime.h")):
                self.selfdir = c
                break
        if not self.selfdir:
            raise RuntimeError("runtime.h not found ($HEXA_LANG/self or <install>/self)")
        self.clang = shutil.which("clang") or ""
        if not self.clang:
            raise RuntimeError("clang not on PATH")


# ── closure flatten (production module_loader; catches ghost imports rc=2) ──

MARK_BEGIN = re.compile(r"^// \[module_loader\] begin: (.+)$")
MARK_END = re.compile(r"^// \[module_loader\] end: (.+)$")


def flatten(infra, repo, entry, workdir):
    """Run the compiled module_loader; return (rc, out, ordered [(abspath, segment_text)])."""
    out_path = os.path.join(workdir, "flat_" + sha(entry)[:12] + ".hexa")
    rc, out = sh([infra.module_loader, entry, out_path], cwd=repo,
                 env={"HEXA_MEM_CAP_MB": os.environ.get("HEXA_MEM_CAP_MB", "4096")})
    if rc != 0 or not os.path.isfile(out_path):
        return rc if rc != 0 else 1, out, []
    segs, cur, buf = [], None, []
    with open(out_path, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = MARK_BEGIN.match(line)
            if m:
                cur, buf = m.group(1).strip(), []
                continue
            m = MARK_END.match(line)
            if m and cur is not None:
                p = cur if os.path.isabs(cur) else os.path.join(repo, cur)
                segs.append((os.path.realpath(p), "".join(buf)))
                cur, buf = None, []
                continue
            if cur is not None:
                buf.append(line)
    return 0, out, segs


# ── interface scanner (top-level decls only; anything odd => misparse escalation) ──

QUAL = r"(?:(?:pub|pure|async|extern)\s+)*"
RE_FN = re.compile(r"^" + QUAL + r"fn\s+([A-Za-z_]\w*)\s*\(")
RE_STRUCT = re.compile(r"^" + QUAL + r"struct\s+([A-Za-z_]\w*)\s*\{")
RE_ENUM = re.compile(r"^" + QUAL + r"enum\s+([A-Za-z_]\w*)\s*\{")
RE_LET = re.compile(r"^" + QUAL + r"let\s+(?:mut\s+)?([A-Za-z_]\w*)")


RE_NONCODE = re.compile(r"//[^\n]*"                      # line comment
                        r"|\"(?:\\.|[^\"\\\n])*\"?"      # double-quoted string (may be unterminated at EOL)
                        r"|'(?:\\.|[^'\\\n])*'?")        # single-quoted string


def _strip_comments(text):
    """Remove comments AND collapse string literals to empty ones, so scanner/lint
    never match identifiers inside strings (real false positive: generator.hexa had
    'decoded via clm_decode_argmax (...)' inside a reason string)."""
    return RE_NONCODE.sub(lambda m: '""' if m.group(0)[0] in "\"'" else "", text)


def _read_paren_group(text, start):
    """text[start] == open bracket; return (inner, end_index) respecting nesting+strings."""
    openc = text[start]
    closec = {"(": ")", "{": "}"}[openc]
    depth, i, in_str, buf = 0, start, None, []
    while i < len(text):
        c = text[i]
        if in_str:
            if c == "\\":
                i += 2
                continue
            if c == in_str:
                in_str = None
        elif c in "\"'":
            in_str = c
        elif c in "({":
            depth += 1
            if depth > 1:
                buf.append(c)
            i += 1
            continue
        elif c in ")}":
            depth -= 1
            if depth == 0:
                return "".join(buf), i
            buf.append(c)
            i += 1
            continue
        if depth >= 1:
            buf.append(c)
        i += 1
    raise ValueError("unbalanced bracket at %d" % start)


def _split_top(inner):
    parts, depth, in_str, cur = [], 0, None, []
    for c in inner:
        if in_str:
            if c == in_str:
                in_str = None
            cur.append(c)
            continue
        if c in "\"'":
            in_str = c
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == "," and depth == 0:
            parts.append("".join(cur).strip())
            cur = []
            continue
        cur.append(c)
    tail = "".join(cur).strip()
    if tail:
        parts.append(tail)
    return parts


def scan_interface(text):
    """=> {'fns':{name:arity}, 'structs':{name:[fields]}, 'enums':{name:[(variant,payload_arity)]}, 'lets':[...]}"""
    clean = _strip_comments(text)
    iface = {"fns": {}, "structs": {}, "enums": {}, "lets": [], "externs": []}
    pos = 0
    for line_m in re.finditer(r"^" + QUAL + r"(fn|struct|enum|let)\b[^\n]*", clean, re.M):
        pos = line_m.start()
        head = clean[pos:line_m.end()]
        m = RE_FN.match(head)
        if m:
            inner, _ = _read_paren_group(clean, pos + head.index("("))
            args = [a for a in _split_top(inner) if a]
            iface["fns"][m.group(1)] = len(args)
            if re.match(r"^(?:pub\s+|pure\s+|async\s+)*extern\s", head):
                iface["externs"].append(m.group(1))
            continue
        m = RE_STRUCT.match(head)
        if m:
            inner, _ = _read_paren_group(clean, pos + head.index("{"))
            fields = []
            for chunk in _split_top(inner.replace("\n", ",")):
                fm = re.match(r"([A-Za-z_]\w*)", chunk)
                if fm:
                    fields.append(fm.group(1))
            iface["structs"][m.group(1)] = fields
            continue
        m = RE_ENUM.match(head)
        if m:
            inner, _ = _read_paren_group(clean, pos + head.index("{"))
            variants = []
            for chunk in _split_top(inner.replace("\n", ",")):
                vm = re.match(r"([A-Za-z_]\w*)\s*(\(([^)]*)\))?", chunk)
                if vm and vm.group(1):
                    pay = len([a for a in _split_top(vm.group(3) or "") if a]) if vm.group(2) else -1
                    variants.append((vm.group(1), pay))
            iface["enums"][m.group(1)] = variants
            continue
        m = RE_LET.match(head)
        if m:
            iface["lets"].append(m.group(1))
    iface["lets"] = sorted(set(iface["lets"]))
    iface["externs"] = sorted(set(iface["externs"]))
    return iface


def iface_hash(iface):
    return sha(json.dumps(iface, sort_keys=True))


def own_names(iface):
    names = set(iface["fns"]) | set(iface["structs"]) | set(iface["lets"])
    for e, vs in iface["enums"].items():
        names.add(e)
        for v, _ in vs:
            names.add("%s__%s" % (e, v))
    return names


# ── skeleton generation ──────────────────────────────────────────────────────

def gen_skeleton(sib_ifaces, exclude):
    """sib_ifaces: {path: iface}. exclude: names owned by the target module. => header text.
    Raises ValueError on cross-sibling conflicting declarations (=> escalate)."""
    decl = {}  # name -> (kind, payload)
    def put(name, kind, payload):
        if name in exclude or name == "main":
            return
        if name in decl and decl[name] != (kind, payload):
            raise ValueError("skeleton conflict on symbol %r: %r vs %r" % (name, decl[name], (kind, payload)))
        decl[name] = (kind, payload)

    for iface in sib_ifaces.values():
        ext = set(iface.get("externs", []))
        for n, ar in iface["fns"].items():
            if n in ext:
                continue  # extern fns: runtime/global C symbols — declaring them
                          # HexaVal would conflict with runtime.h prototypes; if truly
                          # missing, clang reports undeclared => escalate (safe)
            put(n, "fn", ar)
        for n in iface["lets"]:
            put(n, "let", 0)
        for n, fields in iface["structs"].items():
            put(n, "struct", len(fields))
        for e, vs in iface["enums"].items():
            for i, (v, pay) in enumerate(vs):
                put("%s__%s" % (e, v), "enum", (e, v, i, pay))

    lines = ["/* compile_gate interface skeleton (generated; DO NOT LINK) */"]
    for name in sorted(decl):
        kind, p = decl[name]
        if kind == "fn":
            if p <= 4:
                lines.append("HexaVal %s;" % name)  # boxed: hexa_callN takes HexaVal
            else:
                lines.append("HexaVal %s(%s);" % (name, ", ".join(["HexaVal"] * p)))
        elif kind == "let":
            lines.append("HexaVal %s;" % name)
        elif kind == "struct":
            lines.append("HexaVal %s(%s);" % (name, ", ".join(["HexaVal"] * p) if p else "void"))
        else:  # enum variant
            e, v, i, pay = p
            if pay < 0:
                lines.append('static const struct HexaEnumDesc __cgskel_%s = '
                             '{ HEXA_ENUM_DESC_MAGIC, %dU, "%s::%s", "%s" };' % (name, i, e, v, e))
                lines.append("#define %s hexa_enum_str_v(&__cgskel_%s)" % (name, name))
            else:
                lines.append("HexaVal %s(%s);" % (name, ", ".join(["HexaVal"] * pay)))
    return "\n".join(lines) + "\n"


# ── cross-module call-site arity lint (bounds the boxed-call false-GREEN) ────

def arity_lint(mod_text, mod_iface, cross_fns):
    """Return [] if clean, else list of complaint strings (=> escalate).
    Single pass over all call sites (969 cross fns x 500KB module was 1.3s the naive way)."""
    clean = _strip_comments(mod_text)
    bad = []
    for m in re.finditer(r"(?<![\w.])([A-Za-z_]\w*)\s*\(", clean):
        name = m.group(1)
        ar = cross_fns.get(name)
        if ar is None or name in mod_iface["fns"]:
            continue  # not cross-module / shadowed by module's own def
        if clean[:m.start()].rstrip().endswith("fn"):
            continue  # a definition, not a call
        try:
            inner, _ = _read_paren_group(clean, m.end() - 1)
        except ValueError:
            bad.append("%s: unbalanced call site (scanner misparse)" % name)
            continue
        nargs = len([a for a in _split_top(inner) if a])
        if nargs != ar:
            bad.append("%s called with %d args, closure interface says %d" % (name, nargs, ar))
    return bad


# ── cache / anchor ───────────────────────────────────────────────────────────

def cache_dir(root, repo, entry):
    key = sha(os.path.realpath(repo) + "::" + entry)[:16]
    d = os.path.join(root, key)
    os.makedirs(d, exist_ok=True)
    return d


def load_manifest(cdir):
    p = os.path.join(cdir, "manifest.json")
    if not os.path.isfile(p):
        return None
    try:
        with open(p) as f:
            return json.load(f)
    except Exception:
        return None


def write_manifest(cdir, infra, entry, segs):
    man = {"gate_version": GATE_VERSION, "hexa_version": infra.version, "entry": entry,
           "anchored_at": time.time(),
           "closure": [p for p, _ in segs],
           "iface": {}, "ihash": {}}
    for p, text in segs:
        iface = scan_interface(text)
        man["iface"][p] = iface
        man["ihash"][p] = iface_hash(iface)
    with open(os.path.join(cdir, "manifest.json"), "w") as f:
        json.dump(man, f)
    return man


# ── verdict paths ────────────────────────────────────────────────────────────

def full_build(infra, repo, entry, cdir, log):
    out = os.path.join(cdir, "escalate_check.bin")
    t0 = time.time()
    rc, o = sh([infra.hexa, "build", entry, "-o", out], cwd=repo)
    log("[compile-gate] ESCALATED full build: hexa build %s  rc=%d  (%.1fs)" % (entry, rc, time.time() - t0))
    if rc != 0:
        log("---- full build output tail ----")
        log("\n".join(o.splitlines()[-30:]))
    return rc, o


def fast_module_check(infra, repo, workdir, mod_path, mod_text, skel, tu_cache):
    """Transpile changed module alone + clang -fsyntax-only against skeleton.
    Returns (ok, detail). Transpile result cached per module-text within the run."""
    key = sha(mod_text)
    if key not in tu_cache:
        src = os.path.join(workdir, "mod_%s.hexa" % key[:12])
        cfile = os.path.join(workdir, "mod_%s.c" % key[:12])
        with open(src, "w") as f:
            f.write(mod_text)
        t0 = time.time()
        rc, o = sh([infra.hexa, "build", src, "-o", cfile, "--c-only"], cwd=workdir)
        dt = time.time() - t0
        if rc != 0 or not os.path.isfile(cfile):
            tu_cache[key] = (None, "per-module transpile failed rc=%d (%.2fs):\n%s"
                             % (rc, dt, "\n".join(o.splitlines()[-15:])))
        else:
            with open(cfile, encoding="utf-8", errors="replace") as f:
                tu_cache[key] = (f.read(), "transpile %.2fs" % dt)
    ctext, detail = tu_cache[key]
    if ctext is None:
        return False, detail
    inc = '#include "runtime.h"'
    if inc not in ctext:
        return False, "emitted C lacks %s (emission convention changed?)" % inc
    combined = ctext.replace(inc, inc + "\n" + skel, 1)
    tu = os.path.join(workdir, "tu_%s_%s.c" % (key[:8], sha(skel)[:8]))
    with open(tu, "w") as f:
        f.write(combined)
    t0 = time.time()
    rc, o = sh([infra.clang, "-fsyntax-only", "-fbracket-depth=4096",
                "-I", infra.selfdir, tu])
    dt = time.time() - t0
    if rc != 0:
        return False, "clang -fsyntax-only failed (%.2fs) on %s:\n%s" % (dt, mod_path,
                                                                         "\n".join(o.splitlines()[-15:]))
    return True, detail + ", clang -fsyntax-only %.2fs" % dt


def gate_entry(infra, repo, entry, changed, croot, workdir, max_age_h, log, force_full=False):
    """Gate one entrypoint. Returns (verdict, mode) verdict in {GREEN, RED, SKIP}."""
    cdir = cache_dir(croot, repo, entry)
    esc = None

    rc, out, segs = flatten(infra, repo, entry, workdir)
    if rc != 0:
        esc = "closure flatten failed rc=%d (ghost import?)\n%s" % (rc, "\n".join(out.splitlines()[-8:]))
        segs = []
    seg_map = dict(segs)
    closure = set(seg_map)

    if esc is None:
        touched = sorted(closure & changed)
        if not touched:
            log("[compile-gate] %s: no changed file in closure — SKIP" % entry)
            return "GREEN", "skip"
        log("[compile-gate] %s: changed in closure: %s" % (entry, ", ".join(os.path.relpath(t, repo) for t in touched)))

    if force_full:
        esc = "--full requested"

    man = None
    if esc is None:
        man = load_manifest(cdir)
        if man is None:
            esc = "cold cache (no green anchor yet)"
        elif man.get("gate_version") != GATE_VERSION or man.get("hexa_version") != infra.version:
            esc = "anchor toolchain mismatch (%s -> %s)" % (man.get("hexa_version"), infra.version)
        elif set(man.get("closure", [])) != closure:
            esc = "closure file set changed"
        elif (time.time() - man.get("anchored_at", 0)) > max_age_h * 3600:
            esc = "anchor older than %dh (nightly full build missing?)" % max_age_h

    cur_iface = {}
    if esc is None:
        try:
            for p, text in segs:
                cur_iface[p] = scan_interface(text)
        except Exception as ex:
            esc = "interface scanner misparse: %s" % ex
    if esc is None:
        for p in closure:
            if iface_hash(cur_iface[p]) != man["ihash"].get(p):
                who = "changed module" if p in changed else "sibling"
                esc = "interface-hash delta on %s %s" % (who, os.path.relpath(p, repo))
                break

    if esc is None:
        cross_fns = {}
        for p in closure:
            for n, ar in cur_iface[p]["fns"].items():
                cross_fns[n] = ar
        tu_cache = {}
        for mod in touched:
            try:
                skel = gen_skeleton({p: man["iface"][p] for p in closure if p != mod},
                                    exclude=own_names(cur_iface[mod]))
            except ValueError as ex:
                esc = str(ex)
                break
            ok, detail = fast_module_check(infra, repo, workdir, mod, seg_map[mod], skel, tu_cache)
            if not ok:
                esc = detail
                break
            log("[compile-gate]   %s: %s" % (os.path.relpath(mod, repo), detail))
            lint = arity_lint(seg_map[mod], cur_iface[mod], cross_fns)
            if lint:
                esc = "arity lint: " + "; ".join(lint)
                break

    if esc is None:
        log(CAVEAT)
        log("[compile-gate] %s: GREEN (fast path, body-only edit)" % entry)
        return "GREEN", "fast"

    # ── escalation: the real compiler decides; its verdict is what we report ──
    log("[compile-gate] %s: escalate — %s" % (entry, esc))
    rc, _ = full_build(infra, repo, entry, cdir, log)
    if rc == 0:
        rc2, out2, segs2 = flatten(infra, repo, entry, workdir)
        if rc2 == 0 and segs2:
            try:
                write_manifest(cdir, infra, entry, segs2)
                log("[compile-gate] %s: anchor refreshed (green closure)" % entry)
            except Exception as ex:
                log("[compile-gate] warn: anchor refresh failed: %s" % ex)
        log("[compile-gate] %s: GREEN (escalated full build)" % entry)
        return "GREEN", "full"
    log("[compile-gate] %s: RED (escalated full build rc=%d)" % (entry, rc))
    return "RED", "full"


# ── changed-file detection ───────────────────────────────────────────────────

def git_changed(repo, base):
    files = set()
    cmds = [["git", "diff", "--name-only", "HEAD"], ["git", "diff", "--name-only", "--cached"],
            ["git", "ls-files", "--others", "--exclude-standard"]]
    if base:
        cmds.append(["git", "diff", "--name-only", base + "...HEAD"])
    for c in cmds:
        rc, out = sh(c, cwd=repo)
        if rc != 0:
            raise RuntimeError("git failed: %s\n%s" % (" ".join(c), out))
        files |= {l.strip() for l in out.splitlines() if l.strip().endswith(".hexa")}
    return {os.path.realpath(os.path.join(repo, f)) for f in files}


def main(argv=None):
    ap = argparse.ArgumentParser(description="per-module compile gate (fast path + non-bypassable escalation)")
    ap.add_argument("--entry", action="append", default=[], help="entrypoint .hexa (repeatable)")
    ap.add_argument("--repo", default=None, help="repo root (default: git toplevel of cwd)")
    ap.add_argument("--changed", action="store_true", help="detect changed files via git")
    ap.add_argument("--base", default=None, help="also diff against this ref (e.g. origin/main)")
    ap.add_argument("--files", nargs="*", default=None, help="explicit changed files (instead of git detection)")
    ap.add_argument("--cache", default=os.path.join(os.path.expanduser("~"), ".hexa-cache", "skel"))
    ap.add_argument("--anchor", action="store_true", help="force full build of each entry + re-anchor (nightly job)")
    ap.add_argument("--anchor-max-age-h", type=float, default=24.0)
    ap.add_argument("--selftest", action="store_true", help="run the built-in fixture battery")
    a = ap.parse_args(argv)

    log = lambda s: print(s, flush=True)
    if a.selftest:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from compile_gate_selftest import run_selftest  # lives next to this file
        return run_selftest(log)

    t0 = time.time()
    repo = a.repo
    if not repo:
        rc, out = sh(["git", "rev-parse", "--show-toplevel"])
        repo = out.strip() if rc == 0 else os.getcwd()
    repo = os.path.realpath(repo)

    entries = a.entry
    cfg = os.path.join(repo, ".compile-gate.json")
    if not entries and os.path.isfile(cfg):
        with open(cfg) as f:
            entries = json.load(f).get("entries", [])
    if not entries:
        log("[compile-gate] error: no --entry given and no .compile-gate.json")
        return 2

    try:
        infra = Infra()
    except RuntimeError as ex:
        log("[compile-gate] infra failure: %s — cannot even escalate; RED" % ex)
        return 1

    workdir = os.path.join(a.cache, "work")
    os.makedirs(workdir, exist_ok=True)

    if a.anchor:
        worst = 0
        for entry in entries:
            cdir = cache_dir(a.cache, repo, entry)
            rc, _ = full_build(infra, repo, entry, cdir, log)
            if rc == 0:
                rc2, _, segs = flatten(infra, repo, entry, workdir)
                if rc2 == 0 and segs:
                    write_manifest(cdir, infra, entry, segs)
                    log("[compile-gate] %s: anchored" % entry)
            else:
                worst = 1
        return worst

    if a.files is not None:
        changed = {os.path.realpath(os.path.join(repo, f)) for f in a.files}
    elif a.changed:
        try:
            changed = git_changed(repo, a.base)
        except RuntimeError as ex:
            log("[compile-gate] %s" % ex)
            return 1
    else:
        log("[compile-gate] error: need --changed, --files or --anchor")
        return 2

    if not changed:
        log("[compile-gate] no changed .hexa files — GREEN (nothing to check)")
        return 0

    worst = "GREEN"
    for entry in entries:
        v, mode = gate_entry(infra, repo, entry, changed, a.cache, workdir,
                             a.anchor_max_age_h, log)
        if v == "RED":
            worst = "RED"
    log("[compile-gate] total wall %.2fs — verdict %s" % (time.time() - t0, worst))
    return 0 if worst == "GREEN" else 1


if __name__ == "__main__":
    sys.exit(main())
