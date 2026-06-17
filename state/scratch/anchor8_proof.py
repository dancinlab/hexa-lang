import sys
def o(s): print(s, flush=True)
def fac(n,spf):
    f={}
    while n>1:
        p=spf[n]
        while n%p==0: f[p]=f.get(p,0)+1; n//=p
    return f
o("THEOREM(attempt): J2(n)=n·sopfr(n)  ⟺  n=8   (n≥2)\n")
# Part 1 — prime powers (rigorous closed form): p^(a-3)(p^2-1)=a
o("[Part 1] prime powers  p^a:  J2=p^(2a-2)(p^2-1), n·sopfr=a·p^(a+1)")
o("  ⟺ p^(a-3)(p^2-1)=a.  a=1,2: 비정수(해없). a=3: p^2-1=3→p=2→n=8. a≥4: 2^(a-3)·3>a → 해없.")
o("  ⇒ 소수거듭제곱 유일해 = 8  (엄밀).\n")
# Part 2 — composite scan (flushed, N=1e6)
N=1_000_000
spf=list(range(N+1)); i=2
while i*i<=N:
    if spf[i]==i:
        for j in range(i*i,N+1,i):
            if spf[j]==j: spf[j]=i
    i+=1
sols=[]
for n in range(2,N+1):
    f=fac(n,spf)
    j=1
    for p,a in f.items(): j*=p**(2*a-2)*(p*p-1)
    if j==n*sum(p*a for p,a in f.items()): sols.append(n)
o(f"[Part 2] J2(n)=n·sopfr(n) 해 (n≤{N}): {sols}")
o("결론: "+("QED ⇒ n=8 유일 (소수거듭제곱 엄밀 + composite n≤1e6 검증)" if sols==[8] else f"해 {sols}"))
