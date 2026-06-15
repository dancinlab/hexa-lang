# Structural characterization of the self-referential anchor laws via MULTIPLICATIVITY.
# σ,τ,φ,id all multiplicative ⇒ the ratio g(n)=σ(n)τ(n)/(n φ(n)) is multiplicative.
# Law στ=nφ  ⟺  ∏_p g(p^a)=1.  Law σφ=nτ ⟺ ∏_p h(p^a)=1, h=σφ/(nτ).
# Anchor = a multiset of prime-powers whose g- (or h-) values multiply to exactly 1.
from fractions import Fraction as F
def gpow(p,a):   # g(p^a)=σ·τ/(n·φ)
    sig=(p**(a+1)-1)//(p-1); tau=a+1; n=p**a; phi=p**(a-1)*(p-1)
    return F(sig*tau, n*phi)
def hpow(p,a):   # h(p^a)=σ·φ/(n·τ)
    sig=(p**(a+1)-1)//(p-1); tau=a+1; n=p**a; phi=p**(a-1)*(p-1)
    return F(sig*phi, n*tau)
primes=[2,3,5,7,11,13,17,19,23,29,31,37,41,43,47]

print("=== 28-law  στ=nφ  ⟺  ∏ g(p^a)=1 ===")
print(f"  g(2²)=σ τ/(nφ) = {gpow(2,2)}   g(7)=  {gpow(7,1)}   곱 = {gpow(2,2)*gpow(7,1)}  ⇒ 28=2²·7 가 해")
print("  prime-power g-values (g>1 인 것만이 '키' — 곱 1 만들려면 g>1 ×  g<1 reciprocal 필요):")
big=[]
for p in primes:
    for a in range(1,6):
        v=gpow(p,a)
        if v>1: big.append((f"{p}^{a}",v)); 
print("   g>1 :", [(k,str(v)) for k,v in big])
print("   → 유한개(2^1=3,2^2=21/8,2^3=15/8,2^4=155/128,3^1=4/3)뿐. 곱=1 은 이들과 g<1 의 정확 약분쌍 필요.")

print("\n=== 6-law  σφ=nτ  ⟺  ∏ h(p^a)=1 ===")
print(f"  h(2)= {hpow(2,1)}   h(3)= {hpow(3,1)}   곱 = {hpow(2,1)*hpow(3,1)}  ⇒ 6=2·3 가 해")

# brute: which squarefree-ish products of prime powers hit exactly 1 (small search)
import itertools
print("\n=== g-값 곱 = 1 되는 prime-power 조합 탐색 (지수 1..4, 소수 ≤200) ===")
sm=[2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97,101,103,107,109,113,127,131,137,139,149,151,157,163,167,173,179,181,191,193,197,199]
ppw=[]
for p in sm:
    for a in range(1,5): ppw.append((p,a,gpow(p,a)))
found=[]
# anchors are products over DISTINCT primes; search pairs & triples
for combo in itertools.combinations([x for x in ppw],2):
    if len({c[0] for c in combo})<2: continue
    if combo[0][2]*combo[1][2]==1:
        n=1
        for p,a,_ in combo: n*=p**a
        found.append(n)
for combo in itertools.combinations([x for x in ppw],3):
    if len({c[0] for c in combo})<3: continue
    if combo[0][2]*combo[1][2]*combo[2][2]==1:
        n=1
        for p,a,_ in combo: n*=p**a
        found.append(n)
print("  στ=nφ 해 (2·3-prime 조합, n=∏p^a):", sorted(set(found)))
print("DONE")
