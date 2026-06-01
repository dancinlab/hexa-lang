# `.tape` `@D` field grammar — kind-aware allowed fields

Canonical SSOT for which **fields** a `@D` directive block may carry in a
`.tape` file. The `.tape` format itself is specified at
`github.com/dancinlab/tape`; this document pins the `@D` *field grammar*
that hexa-lang authors and the sidecar `tape-lint` hook jointly enforce.

Executable SSOT: [`self/stdlib/tape_grammar.hexa`](../self/stdlib/tape_grammar.hexa)
(`tape_d_field_allowed(kind, key)`). Selftest:
[`self/test/test_tape_grammar.hexa`](../self/test/test_tape_grammar.hexa).
The sidecar hook `_tape_lint.hexa` mirrors this list — keep the two in
lockstep (this module is the source, the hook is the enforcer).

## Rule

`@D` field admissibility is **kind-aware** — it depends on the block's
`:: <kind>` annotation:

| `@D` kind | allowed fields |
|---|---|
| `:: governance` | **`do` / `dont` only** (strict — imperative rules, kept minimal/auditable) |
| every other kind (`:: note`, `:: hypothesis`, `:: identity`, `:: spec`, `:: workflow`, `:: domain`, `:: config`, …) | `do` / `dont` **plus** the documented structured fields below |

Governance directives stay strict so the rule surface is auditable. A
pre-registered hypothesis, an identity header, or a clarifying note
legitimately needs structured metadata that does not fit a do/dont
shape — folding it into prose destroys the audit surface (cf anima
`a_claim_manifest`: every claim needs an indexable field).

## Documented structured fields (non-governance `@D`)

Three families:

```
identity / header  : version · kind · brief · parent · ssot · siblings
note / reference   : ref · refs · note · clarify · scope · mode · why
                     · tool · ex · see
pre-registered     : seed · claim · falsifier · axes · target · honest
hypothesis           (anima a_discovery_log / a_paper_significance shape)
```

The **pre-registered-hypothesis** family carries a falsifiable hypothesis
on a `:: hypothesis` `@D` block — `seed` · `claim` · `falsifier` · `axes` ·
`target` · `honest` · `refs` — so a pre-registration lives as indexable
fields with a full audit surface.

Any field NOT in a documented family is refused on every kind (typo /
drift guard).

## Example — a pre-registered hypothesis block

```
@D h_phi_register := "register decoupling pre-registered hypothesis" :: hypothesis [active]
  seed      = "does corpus register predict Phi collapse at 3B scale"
  claim     = "register axis is orthogonal to the Phi ceiling"
  falsifier = "if 5/5 register-matched corpora raise Phi vs control, claim FALSE"
  axes      = "register x scale x Phi"
  target    = "🔴 CLOSED-negative OR 🟢 numerical"
  honest    = "toy-only until the 3B fire"
  refs      = "H_911 · Hc_1306"
```

This parses. The same fields on a `:: governance` block are refused;
governance stays do/dont only.

## Grandfathering

The enforcing hook is diff-aware: pre-existing field violations are
grandfathered; only newly-introduced or worsened items block. Extending
the whitelist (this list) never breaks an existing `.tape`.
