# flame-forge dojo kata — tiny-clm (tiny-clm)

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

## this kata: tiny-clm

A minimal causal LM: a byte-vocab embedding → a linear head →
softmax cross-entropy on next-token prediction. Closed softmax-CE
backward (`dlogits = probs - onehot`) scatters into the head + the
embedding row. The bridge toward the full `dojo/clm` CLMConvMoE
trainer — same descent discipline, a fraction of the model.

## files

- `train.hexa` — the self-contained flame trainer + descent gate
- `run.sh` — `hexa run train.hexa` + assert `F-FLAMEFORGE-TINYCLM`
- `ref.py` — the torch REFERENCE contrast (emitted with `--lang=py|both`; NOT production)

## references

- `stdlib/flame/` — the flame substrate (`tensor_lib` · `nn_lib` · `optim_lib` · `ag_tape`)
- `stdlib/dojo/clm.hexa` — the full CLMConvMoE cloud trainer this ladder bridges toward
- `docs/hexa-dojo.md` — the two dojo tracks + the kata ladder
