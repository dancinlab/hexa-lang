# Famous open-problem falsifiable probes — fast, flushed, dependency-free.
# NOT proofs; bounded computational verification (honest). frozen-first.
import sys
def out(s): print(s, flush=True)
NP=200000
sieve=bytearray([1])*(NP+1); sieve[0]=sieve[1]=0
for i in range(2,int(NP**0.5)+1):
    if sieve[i]: sieve[i*i::i]=b'\x00'*len(sieve[i*i::i])
primes=[i for i in range(NP+1) if sieve[i]]
isp=lambda x: x<=NP and sieve[x]

out("=== 1. Collatz (3n+1), n<=300000 : 모두 1 도달? + 최장 ===")
recN=recS=0; ok=True
for n in range(2,300001):
    s=0;m=n
    while m!=1:
        m=3*m+1 if m&1 else m>>1
        s+=1
    if s>recS: recS,recN=s,n
out(f"  반례 0 (모두 1 도달) · 최장 정지시간 n={recN} → {recS} steps")

out("\n=== 2. Goldbach (even>2=p+q), even<=100000 ===")
minc=(10**9,0); viol=0
for e in range(4,100001,2):
    c=0
    for p in primes:
        if p>e//2: break
        if isp(e-p): c+=1
    if c==0: viol+=1
    if c<minc[0]: minc=(c,e)
out(f"  반례(0표현) 짝수: {viol}개 · 최소표현 even={minc[1]}→{minc[0]}reps (성립)")

out("\n=== 3. Twin primes (p,p+2), <200000 ===")
tw=[p for p in primes if isp(p+2)]
out(f"  쌍 개수 {len(tw)} · 마지막 ({tw[-1]},{tw[-1]+2}) · 최대간격 {max(tw[i+1]-tw[i] for i in range(len(tw)-1))}")

out("\n=== 4. Erdős–Straus 4/n=1/x+1/y+1/z, n=2..5000 ===")
from math import gcd
def es(n):
    for x in range((n+3)//4, n+1):
        num=4*x-n
        if num<=0: continue
        den=n*x; g=gcd(num,den); a,b=num//g, den//g
        y=max((b//a)+1, x)
        while a*y<=2*b:
            t=a*y-b
            if t>0 and (b*y)%t==0: return True
            y+=1
    return False
fail=[n for n in range(2,5001) if not es(n)]
out(f"  4/n 분해 실패: {fail if fail else '없음 (추측 성립, n≤5000)'}")
out("\nDONE")
