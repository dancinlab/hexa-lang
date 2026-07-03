#!/usr/bin/env python3
"""compile_gate_selftest.py — seeded-fault battery for tool/compile_gate.py.

Covers the design gates that are testable hermetically:
  G-NEG   : parse error / ghost symbol / ghost import / symbol removed /
            wrong-arity cross-module call (boxed AND direct >=5) each
            RED-or-escalate, never silently fast-GREEN
  G-ESC   : interface-hash delta and infra faults force the full-compile
            path; no skip/override flag exists in the CLI
  G-STALE : toolchain-tag bump cold-regenerates the anchor; body edit
            re-verifies; stale (old) anchor escalates
  G-DET   : static audit — the gate never invokes `hexa run` and exposes
            no escalation-bypass flag
Run: python3 tool/compile_gate.py --selftest
"""
import json, os, re, shutil, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
GATE = os.path.join(HERE, "compile_gate.py")

LIB = """\
fn foo(a, b) { return a + b }
fn foo4(a, b, c, d) { return a + b + c + d }
fn big6(a, b, c, d, e, f) { return a + b + c + d + e + f }
struct Point { x, y }
enum Color { Red, Green }
let G_CONST = 7
"""

APP = """\
use "lib"
fn body(y) {
    let s = Point { x: y, y: y }
    let e = Color::Red
    let q = foo4(1, 2, 3, y)
    let z = big6(1, 2, 3, 4, 5, y)
    return foo(y, 1) + G_CONST + s.x + q + z
}
fn main() { println(to_string(body(20))) }
"""


def run_gate(scratch, cache, files, extra=None):
    cmd = [sys.executable, GATE, "--repo", scratch, "--cache", cache,
           "--entry", "app.hexa", "--files"] + files
    if extra:
        cmd += extra
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return p.returncode, p.stdout


def run_anchor(scratch, cache):
    p = subprocess.run([sys.executable, GATE, "--repo", scratch, "--cache", cache,
                        "--entry", "app.hexa", "--anchor"],
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return p.returncode, p.stdout


def run_selftest(log):
    scratch = os.path.join(os.path.expanduser("~"), ".hexa-cache", "compile-gate-selftest", "repo")
    cache = os.path.join(os.path.expanduser("~"), ".hexa-cache", "compile-gate-selftest", "cache")
    shutil.rmtree(os.path.dirname(scratch), ignore_errors=True)
    os.makedirs(scratch)

    def write(name, text):
        with open(os.path.join(scratch, name), "w") as f:
            f.write(text)

    def reset():
        write("lib.hexa", LIB)
        write("app.hexa", APP)

    results, t_all = [], time.time()

    def check(name, cond, detail=""):
        results.append((name, bool(cond), detail))
        log("  [%s] %s%s" % ("PASS" if cond else "FAIL", name, (" — " + detail) if detail and not cond else ""))

    log("[selftest] scratch=%s" % scratch)
    reset()

    # ── anchor (green closure) ───────────────────────────────────────────
    rc, out = run_anchor(scratch, cache)
    check("anchor: green full build", rc == 0 and "anchored" in out, out[-400:])

    # ── fast GREEN on body-only edit ─────────────────────────────────────
    write("app.hexa", APP.replace("return foo(y, 1)", "// body tweak\n    return foo(y, 1)"))
    rc, out = run_gate(scratch, cache, ["app.hexa"])
    check("body-only edit -> fast GREEN", rc == 0 and "GREEN (fast path" in out, out[-600:])
    check("fast GREEN prints caveat block (G-FLAG)", "CAVEAT" in out and "atlas theorem-citation" in out)

    # ── G-NEG 1: parse error ─────────────────────────────────────────────
    reset()
    write("app.hexa", APP + "\nfn broken( { let = }\n")
    rc, out = run_gate(scratch, cache, ["app.hexa"])
    check("parse error -> escalate + RED", rc == 1 and "escalate" in out and "RED" in out, out[-400:])

    # ── G-NEG 2: ghost symbol (undeclared identifier) ────────────────────
    reset()
    write("app.hexa", APP.replace("return foo(y, 1)", "return ghost_fn_nowhere(y)"))
    rc, out = run_gate(scratch, cache, ["app.hexa"])
    check("ghost symbol -> escalate + RED", rc == 1 and "escalate" in out, out[-400:])

    # ── G-NEG 3: ghost import path ───────────────────────────────────────
    reset()
    write("app.hexa", 'use "no_such_module"\n' + APP)
    rc, out = run_gate(scratch, cache, ["app.hexa"])
    check("ghost import -> escalate + RED", rc == 1 and "escalate" in out, out[-400:])

    # ── G-NEG 4: cross-module symbol removed (sibling interface delta) ───
    reset()
    write("lib.hexa", LIB.replace("fn foo(a, b) { return a + b }\n", ""))
    rc, out = run_gate(scratch, cache, ["lib.hexa"])
    check("symbol removed -> interface-delta escalate + RED",
          rc == 1 and "interface-hash delta" in out and "RED" in out, out[-400:])

    # ── G-NEG 5a: wrong-arity boxed call (<=4) caught by arity lint ──────
    reset()
    write("app.hexa", APP.replace("foo(y, 1)", "foo(y)"))
    rc, out = run_gate(scratch, cache, ["app.hexa"])
    check("wrong-arity boxed call -> lint escalate + RED",
          rc == 1 and "arity lint" in out and "RED" in out, out[-400:])

    # ── G-NEG 5b: wrong-arity direct call (>=5) caught by clang prototype ─
    reset()
    write("app.hexa", APP.replace("big6(1, 2, 3, 4, 5, y)", "big6(1, 2, 3, 4, y)"))
    rc, out = run_gate(scratch, cache, ["app.hexa"])
    check("wrong-arity direct call (>=5) -> escalate + RED", rc == 1, out[-400:])

    # ── G-ESC: interface ADD never fast-GREENs ───────────────────────────
    reset()
    write("app.hexa", APP + "\nfn new_api(x) { return x }\n")
    rc, out = run_gate(scratch, cache, ["app.hexa"])
    check("interface add -> escalated, GREEN only via full build",
          rc == 0 and "interface-hash delta" in out and "GREEN (escalated full build)" in out
          and "GREEN (fast path" not in out, out[-600:])

    # ── G-ESC: no bypass flag exists (c18) ───────────────────────────────
    with open(GATE) as f:
        src = f.read()
    check("no skip/bypass/no-escalate flag in CLI",
          not re.search(r'add_argument\(\s*"--[^"]*(skip|bypass|escalat|green)', src))

    # ── G-DET: never `hexa run`, never run-cache writes ──────────────────
    hexa_subs = re.findall(r'infra\.hexa,\s*"(\w+)"', src)
    check("static audit: only `hexa build` subcommand (never `hexa run`)",
          bool(hexa_subs) and set(hexa_subs) == {"build"}, str(hexa_subs))

    # ── G-STALE 1: toolchain tag bump -> cold re-anchor, then fast again ─
    reset()
    rc, out = run_anchor(scratch, cache)  # re-anchor clean state
    mans = []
    for root, _, fs in os.walk(cache):
        mans += [os.path.join(root, x) for x in fs if x == "manifest.json"]
    check("anchor manifest exists", len(mans) >= 1)
    for mp in mans:
        with open(mp) as f:
            man = json.load(f)
        man["hexa_version"] = "hexa v0.0.0-STALE"
        with open(mp, "w") as f:
            json.dump(man, f)
    write("app.hexa", APP.replace("return foo(y, 1)", "// stale probe\n    return foo(y, 1)"))
    rc, out = run_gate(scratch, cache, ["app.hexa"])
    check("toolchain bump -> escalate (no stale-GREEN) + re-anchor",
          rc == 0 and "toolchain mismatch" in out and "anchor refreshed" in out, out[-600:])
    write("app.hexa", APP.replace("return foo(y, 1)", "// stale probe 2\n    return foo(y, 1)"))
    rc, out = run_gate(scratch, cache, ["app.hexa"])
    check("after re-anchor -> fast GREEN again", rc == 0 and "GREEN (fast path" in out, out[-400:])

    # ── G-STALE 2: old anchor (nightly missing) -> escalate ──────────────
    for mp in mans:
        with open(mp) as f:
            man = json.load(f)
        man["anchored_at"] = time.time() - 48 * 3600
        with open(mp, "w") as f:
            json.dump(man, f)
    rc, out = run_gate(scratch, cache, ["app.hexa"])
    check("anchor older than 24h -> escalate (G-FLAG freshness)",
          rc == 0 and "older than" in out, out[-400:])

    n_fail = sum(1 for _, ok, _ in results if not ok)
    log("[selftest] %d/%d pass (%.1fs)" % (len(results) - n_fail, len(results), time.time() - t_all))
    return 1 if n_fail else 0


if __name__ == "__main__":
    sys.exit(run_selftest(lambda s: print(s, flush=True)))
