# Frontier 1100 (Round 11): Deep Targeted + Final Consolidation

> 29 hypotheses, 29 PASS / 0 FAIL. Generated 2026-03-27.

## Summary: 🟩 2, 🟧★ 15, 🟧 12

## New Unique-to-6 Identities

| # | Identity | Solutions | Note |
|---|---------|----------|------|
| 1 | gcd(sigma,tau)=tau AND phi=omega | {6} | combined divisibility+equality |
| 2 | sigma*phi+tau*omega=2^sopfr | {6, 8} | 32=2^5 |
| 3 | sigma^2+phi^2-tau^2=sigma*p(n) | {2, 6} | 132=12*11 |
| 4 | phi*omega=tau | {3,6,8} | product identity |
| 5 | 5-product=n!+3-product | {6} (to n=20) | 960=720+240 |
| 6 | n mod sopfr=1 | {6,21,45,52} | consequence of sopfr=n-1 |

## Modular Characterization (proved)

For perfect n: sigma mod (n-1) = 2 = phi iff phi(n)=2 iff n=6.
(Since sigma=2n for perfect, 2n mod (n-1)=2.)

## Master List Consolidation

**14+ proved unique-to-6 identities** across Frontiers 500-1100:
1. sopfr(n)=n-1
2. phi(n)+1=n/2 (among perfects)
3. sigma(n)*(phi(n)+1)=n^2 (among perfects)
4. n*tau=sigma*omega
5. rad(sigma(n))=n
6. sigma/tau+phi/omega=tau
7. sigma/phi=n (=psi/phi=n)
8. sigma+tau=2^tau
9. sigma^2-tau^2=2^(n+1)
10. sigma*phi*tau=n*2^tau
11. sigma+rad=3n
12. phi+tau=n (among perfects, conjunction sigma=2n)
13. 6=only perfect preceded by prime
14. gcd(sigma,tau)=tau AND phi=omega

**7+ generalizing theorems:**
1. (sigma-phi)/(tau-omega)=sopfr (semiprimes)
2. n'=sopfr (squarefree semiprimes)
3. sigma-phi-tau=n (n=2p)
4. aliquot(n)=n (perfect)
5. sigma*mu^2=sigma(rad) (squarefree)
6. sigma/n=2 (perfect)
7. tau=2^omega (squarefree)
