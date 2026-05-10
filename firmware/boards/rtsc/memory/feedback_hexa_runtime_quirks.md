---
name: hexa_real interpreter @pure-function flake on resource hosts
description: math_pure transcendentals (sinh_pure, sqrt_pure, pow_pure) sometimes fail "undefined function" when called from helper-fn context on ubu-1/ubu-2. Inline workaround.
type: feedback
---

The `hexa_real` interpreter at `~/.hx/bin/hexa_real` on ubu-1/ubu-2
has flaky name resolution for `@pure`-annotated math_pure functions
when they're called from inside helper functions (not top-level
scope). Symptom:

```
Runtime error: undefined function: sinh_pure
error: division by zero
```

**Why**: Suspected interpreter bug in @pure-decorator import resolution
through nested fn scopes. Reproducible: same script using `sqrt_pure`
inside `fn kernel_integral(...)` fails, while a top-level `let x =
sqrt_pure(...)` succeeds. Other `_pure` functions like `pi_pure`,
`exp_pure`, `log_pure`, `pow_pure`, `log10_pure` are NOT @pure-decorated
in math_pure.hexa source on resource hosts and work reliably.

**How to apply**:

When writing new `verify/numerics_*.hexa` or `firmware/sim/*.hexa`
scripts, prefer the **stable subset** for helper-function code:

- Stable (use freely): `pi_pure()`, `exp_pure(x)`, `log_pure(x)`,
  `log10_pure(x)`, `pow_pure(b, e)`
- Flaky (avoid in helpers): `sinh_pure`, `cosh_pure`, `sqrt_pure`
  (sometimes works, sometimes fails — depends on caller context)

**Inline workarounds**:
```hexa
fn local_sinh(x: float) -> float {
    let ep = exp_pure(x)
    let em = exp_pure(0.0 - x)
    return (ep - em) * 0.5
}
fn local_sqrt(x: float) -> float {
    return pow_pure(x, 0.5)
}
fn arcsinh_via_log(y: float) -> float {
    let one_plus_y2 = 1.0 + y * y
    let root_term = pow_pure(one_plus_y2, 0.5)
    return log_pure(y + root_term)
}
```

For trig (cos/sin), `sin_pure`/`cos_pure` may also flake — fall back
to Taylor series with [-π/2, π/2] reduction (7 terms gives ~1e-12
accuracy):
```hexa
fn local_cos(x: float) -> float {
    // reduce to [-π/2, π/2] via cos(π-x) = -cos(x), then 7-term Taylor
    ...
}
```

This issue is environmental (resource-host interpreter version), not
script bug — the same script may pass on Mac local hexa runtime.
