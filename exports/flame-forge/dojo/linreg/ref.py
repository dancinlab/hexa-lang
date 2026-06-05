#!/usr/bin/env python3
# flame-forge dojo kata — torch REFERENCE (NOT the production path)
# slug: linreg  ·  kata: linreg
#
# A side-by-side PyTorch reference for the SAME kata. The hexa
# train.hexa is the production surface (flame substrate, self/forge
# GPU); this torch script is the familiar-framework CONTRAST that
# motivates the kata. It is NOT what ships — it is the oracle you
# compare the flame descent against.
import torch

torch.manual_seed(0)
d, N, EPOCHS, LR = 16, 64, 50, 0.01

w_true = torch.randn(d, 1); b_true = 0.5
X = torch.randn(N, d)
y = X @ w_true + b_true
model = torch.nn.Linear(d, 1)
opt = torch.optim.AdamW(model.parameters(), lr=LR)
for ep in range(EPOCHS):
    opt.zero_grad()
    loss = ((model(X) - y) ** 2).mean()
    if ep == 0: first = loss.item()
    loss.backward(); opt.step()
print(f'epoch-1 MSE={first}  epoch-{EPOCHS} MSE={loss.item()}')
