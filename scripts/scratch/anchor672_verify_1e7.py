import sys
N=10_000_000
# smallest prime factor sieve
spf=list(range(N+1))
i=2
while i*i<=N:
    if spf[i]==i:
        for j in range(i*i,N+1,i):
            if spf[j]==j: spf[j]=i
    i+=1
from math import gcd
sols=[]
for n in range(2,N+1):
    m=n; pf={}
    while m>1:
        p=spf[m]; e=0
        while m%p==0: m//=p; e+=1
        pf[p]=e
    sig=1; phi=1; tau=1; lam=1
    for p,a in pf.items():
        sig*=(p**(a+1)-1)//(p-1)
        phi*=(p-1)*p**(a-1)
        tau*=a+1
        c=(p-1)*p**(a-1)
        if p==2 and a>=3: c//=2
        lam=lam*c//gcd(lam,c)
    if phi*sig==n*lam*tau: sols.append(n)
    if n% 2000000==0: print(f"  ...{n//1000000}M ok, sols={sols}", flush=True)
print(f"φσ=nλτ 해 (n≤10^7): {sols}", flush=True)
