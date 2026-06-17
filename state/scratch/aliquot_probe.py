# Math open-problem probe: aliquot dynamics (bridges our 6/28 perfect-number work).
# s(n)=sigma(n)-n. Fixed points=perfect, 2-cycles=amicable, k-cycles=sociable.
# Catalan-Dickson conjecture (OPEN): does every aliquot sequence terminate or
# become periodic? frozen-first; results are exact/verifiable (open part flagged).
N=1_000_000
s=[0]*(N+1)                      # proper-divisor-sum sieve  O(N log N)
for d in range(1,N//2+1):
    for m in range(2*d,N+1,d): s[m]+=d

perfect=[n for n in range(2,N+1) if s[n]==n]
amicable=[]
for n in range(2,N+1):
    m=s[n]
    if 1<m<=N and m!=n and s[m]==n and n<m: amicable.append((n,m))
print(f"=== aliquot dynamics  s(n)=sigma(n)-n,  n<= {N} ===")
print(f"고정점 (perfect, s(n)=n):     {perfect}")
print(f"2-cycle (amicable pairs): {len(amicable)} pairs, first 6 = {amicable[:6]}")

# sociable cycles length>=3 (small search, follow orbit within N)
def orbit_cycle(n, cap=60):
    seen={}; x=n; path=[]
    for i in range(cap):
        if x in seen: 
            j=seen[x]; return path[j:] if len(path)-j>=3 else None
        if x<1 or x>N: return None
        seen[x]=len(path); path.append(x); x=s[x]
    return None
socs=set()
for n in [12496,14316,1264460,2115324]:
    if n<=N:
        c=orbit_cycle(n)
        if c: socs.add(tuple(c))
print(f"sociable cycle(s) (len>=3): {[len(c) for c in socs]} found e.g. {list(socs)[:1]}")

# Catalan-Dickson OPEN cases — the 'Lehmer five' smallest unresolved start values.
# Iterate with on-the-fly sigma (trial division) a bounded number of steps.
def sigma_big(n):
    r=1; m=n; d=2
    while d*d<=m:
        if m%d==0:
            pe=1; e=0
            while m%d==0: m//=d; e+=1
            r*=(d**(e+1)-1)//(d-1)
        d+=1
    if m>1: r*=(m+1)
    return r
print("\n=== Catalan-Dickson OPEN starters (Lehmer five) — 50-step trace ===")
for start in [276,552,564,660,966]:
    x=start; mx=start; term=None
    for i in range(50):
        x=sigma_big(x)-x
        if x==0: term="terminates(→0)"; break
        if x>mx: mx=x
    print(f"  n={start:<4} after 50 steps: value~{len(str(x))} digits, max~{len(str(mx))} digits, {term or 'STILL GROWING (open)'}")
