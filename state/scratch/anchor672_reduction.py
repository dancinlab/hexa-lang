# φσ(n)=nλ(n)τ(n) ⟺ n=672 : reduction (★) + why size-bound CANNOT finish.
from fractions import Fraction as F
from math import gcd
def fac(n):
    f={};d=2;m=n
    while d*d<=m:
        while m%d==0: f[d]=f.get(d,0)+1;m//=d
        d+=1
    if m>1: f[m]=f.get(m,0)+1
    return f
def SIG(n):
    r=1
    for p,a in fac(n).items(): r*=(p**(a+1)-1)//(p-1)
    return r
def PHI(n):
    r=1
    for p,a in fac(n).items(): r*=(p-1)*p**(a-1)
    return r
def TAU(n):
    r=1
    for p,a in fac(n).items(): r*=a+1
    return r
def LAM(n):
    if n==1: return 1
    l=1
    for p,a in fac(n).items():
        c=(p-1)*p**(a-1)
        if p==2 and a>=3: c//=2
        l=l*c//gcd(l,c)
    return l
def star(n):
    r=F(1)
    for p,a in fac(n).items(): r*=F(p**(a+1)-1,p)
    return r
# 동치 (★): φσ=nλτ ⟺ ∏(p^{a+1}-1)/p = λτ
bad=[n for n in range(2,200000) if (PHI(n)*SIG(n)==n*LAM(n)*TAU(n)) != (star(n)==LAM(n)*TAU(n))]
print(f"(★) 동치 검증 (n<2e5): 불일치 {bad}  (∅ 이어야)")
print(f"  @672: ∏(p^(a+1)-1)/p={star(672)} = λτ={LAM(672)*TAU(672)} ✓  (=576)")
# 해
sol=[n for n in range(2,200000) if PHI(n)*SIG(n)==n*LAM(n)*TAU(n)]
print(f"  해(n<2e5): {sol}")
# 크기-only 불가: λτ<n 인 n 밀도 (size 만으로 유계 불가능 입증)
c=sum(1 for n in range(2,200001) if LAM(n)*TAU(n)<n)
print(f"  λτ(n)<n 밀도(n≤2e5): {c}/{200000-1} ≈ {c/199999:.3f} → 크기-only 유계 불가(양의 밀도) [정직]")
