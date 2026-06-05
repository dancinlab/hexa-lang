# flame-forge dojo kata — linreg (linreg)

The **NN-training** arm of the dojo. Each kata is a small, complete
flame trainer over the stdlib/flame substrate (`t_*` tensor ops,
`t_matmul` forge matmul, `opt_adamw_step` optimizer) you read + run
end-to-end. Each emits a **descent gate** (loss strictly descends).

- spec: `d=16`  `T=64`  `epochs=50`  `lr=0.01`  `host=ubu-1`
- run: `bash run.sh`  (`hexa run train.hexa` + assert the gate)

## kata ladder

| rung | kata | model · loss |
|---|---|---|
| 1 | linreg | `y = X·w + b` · MSE · closed gradient |
| 2 | mlp | `relu(X·W1+b1)·W2+b2` · MSE · 2-stage backprop |
| 3 | tiny-clm | byte-vocab embed + linear head · mean CE · softmax backward |

## this kata: linreg

Linear regression `y = X·w + b` against a planted true `w`/bias.
Forward is one `t_matmul`; the closed gradient is `dw = (2/N)·Xᵀ·r`,
`db = (2/N)·Σ r` (r = residual). One `opt_adamw_step` per param. The
floor rung — a single matmul + the closed vjp + the descent gate.

## files

- `train.hexa` — the self-contained flame trainer + descent gate
- `run.sh` — `hexa run train.hexa` + assert `F-FLAMEFORGE-LINREG`
- `ref.py` — the torch REFERENCE contrast (emitted with `--lang=py|both`; NOT production)

## references

- `stdlib/flame/` — the flame substrate (`tensor_lib` · `nn_lib` · `optim_lib` · `ag_tape`)
- `stdlib/dojo/clm.hexa` — the full CLMConvMoE cloud trainer this ladder bridges toward
- `docs/hexa-dojo.md` — the two dojo tracks + the kata ladder
