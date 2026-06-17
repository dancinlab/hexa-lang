# ①완성도: 28-law uniqueness at large scale + extended function family
# (Carmichael lambda, omega, Omega, abundancy) self-referential anchor scan.
# frozen-first + full-range control. Pure-python, dependency-free.
import sys
from math import gcd
N = 2_000_000
spf = list(range(N+1))
i=2
while i*i<=N:
    if spf[i]==i:
        for j in range(i*i,N+1,i):
            if spf[j]==j: spf[j]=i
    i+=1
def factor(n):
    f={}
    while n>1:
        p=spf[n]
        while n%p==0: f[p]=f.get(p,0)+1; n//=p
    return f
def sigma(n):
    r=1
    for p,e in factor(n).items(): r*=(p**(e+1)-1)//(p-1)
    return r
def phi(n):
    r=1
    for p,e in factor(n).items(): r*=(p-1)*p**(e-1)
    return r
def tau(n):
    r=1
    for p,e in factor(n).items(): r*=(e+1)
    return r
def psi(n):
    r=1
    for p,e in factor(n).items(): r*=(p+1)*p**(e-1)
    return r
def J2(n):
    r=1
    for p,e in factor(n).items(): r*=(p*p-1)*(p*p)**(e-1)
    return r
def lam(n):  # Carmichael
    if n==1: return 1
    l=1
    for p,e in factor(n).items():
        c=(p-1)*p**(e-1)
        if p==2 and e>=3: c//=2
        l=l*c//gcd(l,c)
    return l
def omega(n): return len(factor(n))
def Omega(n): return sum(factor(n).values())

# --- 28-law uniqueness at scale ---
print(f"=== 28-law (sigma*tau/phi = n) uniqueness, n<= {N} ===", flush=True)
law28=[n for n in range(2,N+1) if sigma(n)*tau(n)==n*phi(n)]
law6 =[n for n in range(2,N+1) if sigma(n)*phi(n)==n*tau(n)]
print(f"  sigma*tau/phi = n :  {law28}   (28-law)", flush=True)
print(f"  sigma*phi/tau = n :  {law6}    (6-law)", flush=True)

# --- extended self-referential fixed points R(n)=n ---
lib = {
 "sigma*tau/phi":  (lambda n: sigma(n)*tau(n), lambda n: phi(n)),
 "sigma*phi/tau":  (lambda n: sigma(n)*phi(n), lambda n: tau(n)),
 "J2/sopfr? J2/lam":(lambda n: J2(n),          lambda n: lam(n)),
 "psi/lam":        (lambda n: psi(n),          lambda n: lam(n)),
 "sigma/lam":      (lambda n: sigma(n),        lambda n: lam(n)),
 "phi*sigma/(lam*tau)":(lambda n: phi(n)*sigma(n), lambda n: lam(n)*tau(n)),
 "lam*tau":        (lambda n: lam(n)*tau(n),   lambda n: 1),       # = n?
 "psi*lam/(sigma)":(lambda n: psi(n)*lam(n),   lambda n: sigma(n)),
 "sigma*omega/(?)":(lambda n: sigma(n),        lambda n: omega(n)+1),
 "J2/(phi*Omega)": (lambda n: J2(n),           lambda n: phi(n)*Omega(n)),
}
print(f"\n=== extended self-ref fixed points R(n)=n (n<=200000) ===", flush=True)
for name,(num,den) in lib.items():
    fps=[]
    for n in range(2,200001):
        d=den(n)
        if d and num(n)%d==0 and num(n)//d==n:
            fps.append(n)
            if len(fps)>6: break
    if fps:
        tag="  <-- UNIQUE" if len(fps)==1 else ""
        print(f"  {name:24s} -> {fps}{tag}", flush=True)
print("\nDONE", flush=True)
