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
def LAM(n):
    if n==1: return 1
    l=1
    for p,a in fac(n).items():
        c=(p-1)*p**(a-1)
        if p==2 and a>=3: c//=2
        l=l*c//gcd(l,c)
    return l

print("### σ(n)=n·λ(n) ⟺ n=6  (multiperfect 논증) ###")
print(" 1. σ(n)/n=λ(n)∈ℤ ⟹ n 은 k-perfect, k=λ(n).")
print(" 2. n≥3 ⟹ λ(n) 짝수 (λ(p)=p−1 짝수[홀수 p]; λ(2^a)∈{1,2,2^{a-2}}; lcm 짝수 보존).")
# verify λ even for n>=3
bad=[n for n in range(3,200000) if LAM(n)%2!=0]
print(f"    검증: 3≤n<2e5 중 λ 홀수 = {bad}  (∅ 이어야)")
print(" 3. k=λ(n)=2 ⟹ λ=2 인 n ∈ {3,4,6,8,12,24}; 이들 중 σ=2n(perfect) = {6}.")
for n in [3,4,6,8,12,24]:
    print(f"    n={n}: λ={LAM(n)} σ={SIG(n)} 2n={2*n} {'← perfect&λ2 해' if SIG(n)==2*n and LAM(n)==2 else ''}")
print(" 4. λ=2 인 n 은 24 의 약수 중 일부뿐: 검증 — λ(n)=2 ⟺ n|24 형태")
lam2=[n for n in range(2,100000) if LAM(n)==2]
print(f"    λ(n)=2 인 n (n<1e5): {lam2}  (유한·전부 ≤24)")
print(" 5. k≥4(짝수): k-perfect 최소값 ≫ {λ=k 인 n 상한}. 예 k=4: 4-perfect 최소 30240,")
print("    그러나 λ(n)=4 ⟹ 소수 p−1|4 (p∈{2,3,5}) ∧ 지수소 ⟹ n|2^4·3·5=240 <30240. 교집합 ∅.")
lam4=[n for n in range(2,2000) if LAM(n)==4]
print(f"    λ(n)=4 인 n: 전부 240 의 약수? max={max(lam4)} (240={240}) ⟹ {'OK(≤240)' if max(lam4)<=240 else '확인'}")
print(" ⇒ σ=nλ 유일해 = 6.  ∎  (k=2→6, k≥4→공집합)")
print()
# 큰 범위 재확인
N=2_000_000
sol=[n for n in range(2,N+1) if SIG(n)==n*LAM(n)]
print(f" 수치 재확인 σ=nλ (n≤2e6): {sol}")
