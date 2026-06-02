#!/usr/bin/env python3
# diff_fuzz_gen.py — deterministic-seeded generator of VALID hexa programs
# for the MISCOMPILE-ZERO differential fuzzer (tool/diff_fuzz.sh).
#
# Each program is parameterized solely by an integer SEED (argv[1]); the
# same seed ALWAYS yields the same .hexa source (reproducibility — no
# Math.random / wall-clock). Output goes to stdout.
#
# The generator only uses language features PROVEN to compile + run on
# both the gen2 native self-host compiler AND the aprime/clang C oracle
# (probed 2026-06: int/hex arith, /, %, comparisons, if/else, while,
# arrays + index, maps, string len, recursion, closures, structs,
# match-expr with `->` arms). It deliberately AVOIDS snapshot-fragile
# surface (for-in ranges, float-heavy paths) so any divergence the
# harness reports is a REAL codegen miscompile, not a parse skew.
#
# Every program ends `exit(<i64>)`; the harness compares the (8-bit
# masked) process exit code between gen2 and the oracle. Exit-code mask
# is identical on both sides, so it is a sound differential signal.

import sys

class Rng:
    # Deterministic LCG (Numerical Recipes constants) — no platform RNG.
    def __init__(self, seed):
        self.s = (seed * 2654435761 + 12345) & 0xFFFFFFFFFFFFFFFF
    def next(self):
        self.s = (self.s * 6364136223846793005 + 1442695040888963407) & 0xFFFFFFFFFFFFFFFF
        return (self.s >> 17) & 0x7FFFFFFF
    def rint(self, lo, hi):
        return lo + self.next() % (hi - lo + 1)
    def pick(self, xs):
        return xs[self.next() % len(xs)]

class Gen:
    def __init__(self, rng):
        self.rng = rng
        self.lines = []
        self.var_ctr = 0
        self.fn_ctr = 0
        self.funcs = []   # (name, arity)
        self.depth = 0

    def fresh_var(self):
        self.var_ctr += 1
        return "v%d" % self.var_ctr

    # ---- expression generation (pure i64; closes over in-scope vars) ----
    def gen_expr(self, scope, budget):
        # scope: list of in-scope i64 var names
        if budget <= 0 or self.rng.rint(0, 3) == 0:
            k = self.rng.rint(0, 4)
            if k == 0:
                return str(self.rng.rint(0, 99))
            if k == 1:
                return "0x%X" % self.rng.rint(1, 255)   # hex literal
            if scope:
                return self.rng.pick(scope)
            return str(self.rng.rint(1, 50))
        kind = self.rng.rint(0, 5)
        if kind == 0 and scope:
            return self.rng.pick(scope)
        if kind == 1 and self.funcs:
            name, arity = self.rng.pick(self.funcs)
            args = ", ".join(self.gen_expr(scope, budget - 2) for _ in range(arity))
            return "%s(%s)" % (name, args)
        # binary op
        a = self.gen_expr(scope, budget - 1)
        b = self.gen_expr(scope, budget - 1)
        op = self.rng.pick(["+", "-", "*"])
        if op == "*":
            # bound magnitude to keep values well inside i64 (no UB skew)
            b = "(%s %% 7)" % b
        return "(%s %s %s)" % (a, op, b)

    def gen_safe_divmod(self, scope, budget):
        # division/modulo with a guaranteed-nonzero divisor
        a = self.gen_expr(scope, budget)
        d = self.rng.rint(1, 9)
        op = self.rng.pick(["/", "%"])
        return "(%s %s %d)" % (a, op, d)

    # ---- statement / body generation ----
    def gen_body(self, scope, n_stmts):
        scope = list(scope)
        for _ in range(n_stmts):
            kind = self.rng.rint(0, 6)
            if kind == 0:
                v = self.fresh_var()
                self.emit("let %s = %s" % (v, self.gen_expr(scope, 4)))
                scope.append(v)
            elif kind == 1:
                v = self.fresh_var()
                self.emit("let %s = %s" % (v, self.gen_safe_divmod(scope, 3)))
                scope.append(v)
            elif kind == 2 and scope:
                t = self.rng.pick(scope)
                self.emit("%s = %s" % (t, self.gen_expr(scope, 4)))
            elif kind == 3:
                # if / optional else. Bodies only MUTATE existing vars —
                # never declare a leaking `let` (hexa blocks are scoped, so
                # an inner `let` would be undefined outside, producing an
                # INVALID program rather than a miscompile signal). Ensure
                # at least one assignable var exists at body level first.
                if not scope:
                    v = self.fresh_var()
                    self.emit("let %s = %s" % (v, self.gen_expr([], 3)))
                    scope.append(v)
                self.emit("if %s {" % self.gen_cond(scope))
                self.indent_in()
                self.emit("%s = %s" % (self.rng.pick(scope), self.gen_expr(scope, 3)))
                self.indent_out()
                if self.rng.rint(0, 1) == 0:
                    self.emit("} else {")
                    self.indent_in()
                    self.emit("%s = %s" % (self.rng.pick(scope), self.gen_expr(scope, 3)))
                    self.indent_out()
                self.emit("}")
            elif kind == 4:
                # bounded while loop (counter-driven, always terminates)
                c = self.fresh_var(); scope.append(c)
                limit = self.rng.rint(2, 8)
                acc = self.rng.pick(scope) if scope else None
                self.emit("let %s = 0" % c)
                self.emit("while %s < %d {" % (c, limit))
                self.indent_in()
                if acc and acc != c:
                    self.emit("%s = %s + %s" % (acc, acc, c))
                self.emit("%s = %s + 1" % (c, c))
                self.indent_out()
                self.emit("}")
            elif kind == 5:
                # array build + index sum
                arr = self.fresh_var()
                vals = ", ".join(str(self.rng.rint(0, 30)) for _ in range(self.rng.rint(2, 5)))
                self.emit("let %s = [%s]" % (arr, vals))
                idx = self.rng.rint(0, 1)
                v = self.fresh_var()
                self.emit("let %s = %s[%d]" % (v, arr, idx))
                scope.append(v)
            else:
                # match expression
                v = self.fresh_var()
                sel = self.gen_expr(scope, 2)
                self.emit("let %s = match (%s %% 3) {" % (v, sel))
                self.indent_in()
                self.emit("0 -> %d," % self.rng.rint(0, 50))
                self.emit("1 -> %d," % self.rng.rint(0, 50))
                self.emit("_ -> %d" % self.rng.rint(0, 50))
                self.indent_out()
                self.emit("}")
                scope.append(v)
        return scope

    def gen_cond(self, scope):
        a = self.gen_expr(scope, 2)
        b = self.gen_expr(scope, 2)
        op = self.rng.pick(["<", ">", "<=", ">=", "=="])
        return "%s %s %s" % (a, op, b)

    # ---- output helpers ----
    def emit(self, s):
        self.lines.append("    " * self.depth + s)
    def indent_in(self):
        self.depth += 1
    def indent_out(self):
        self.depth -= 1

    # ---- top-level program ----
    def gen_program(self):
        # 1..3 helper functions (some recursive-safe via decreasing arg)
        n_funcs = self.rng.rint(1, 3)
        for _ in range(n_funcs):
            self.fn_ctr += 1
            name = "fn_%d" % self.fn_ctr
            arity = self.rng.rint(1, 3)
            params = ["p%d" % i for i in range(arity)]
            self.depth = 0
            self.emit("fn %s(%s) {" % (name, ", ".join(params)))
            self.indent_in()
            local_scope = list(params)
            local_scope = self.gen_body(local_scope, self.rng.rint(1, 4))
            ret = self.gen_expr(local_scope, 4)
            self.emit("return %s" % ret)
            self.indent_out()
            self.emit("}")
            self.emit("")
            self.funcs.append((name, arity))

        # main
        self.depth = 0
        self.emit("fn main() {")
        self.indent_in()
        scope = self.gen_body([], self.rng.rint(3, 7))
        # final accumulator -> exit
        if scope:
            acc = scope[0]
            for v in scope[1:]:
                acc2 = self.fresh_var()
                self.emit("let %s = %s + %s" % (acc2, acc, v))
                acc = acc2
            self.emit("exit(%s %% 250)" % acc)
        else:
            self.emit("exit(%d)" % self.rng.rint(0, 200))
        self.indent_out()
        self.emit("}")
        return "\n".join(self.lines) + "\n"


def main():
    if len(sys.argv) < 2:
        sys.stderr.write("usage: diff_fuzz_gen.py <seed>\n")
        sys.exit(2)
    seed = int(sys.argv[1])
    rng = Rng(seed)
    g = Gen(rng)
    sys.stdout.write("// diff-fuzz generated program — seed=%d (deterministic)\n" % seed)
    sys.stdout.write(g.gen_program())

if __name__ == "__main__":
    main()
