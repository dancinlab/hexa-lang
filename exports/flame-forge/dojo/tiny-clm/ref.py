#!/usr/bin/env python3
# flame-forge dojo kata — torch REFERENCE (NOT the production path)
# slug: tiny-clm  ·  kata: tiny-clm
#
# A side-by-side PyTorch reference for the SAME kata. The hexa
# train.hexa is the production surface (flame substrate, self/forge
# GPU); this torch script is the familiar-framework CONTRAST that
# motivates the kata. It is NOT what ships — it is the oracle you
# compare the flame descent against.
import torch

torch.manual_seed(0)
d, N, EPOCHS, LR = 16, 64, 50, 0.01

V = 16
ids = torch.arange(N) % V
tgt = (ids + 1) % V
embed = torch.nn.Embedding(V, d)
head = torch.nn.Linear(d, V)
opt = torch.optim.AdamW(list(embed.parameters()) + list(head.parameters()), lr=LR)
lossfn = torch.nn.CrossEntropyLoss()
for ep in range(EPOCHS):
    opt.zero_grad()
    loss = lossfn(head(embed(ids)), tgt)
    if ep == 0: first = loss.item()
    loss.backward(); opt.step()
print(f'epoch-1 CE={first}  epoch-{EPOCHS} CE={loss.item()}')
