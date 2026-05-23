# RFC 046 sim-universe ssh/hofstadter 정수-identity atom 등록 BLOCKED — verify int-path 미지원 (2026-05-24)

## 한 줄 요약
RFC 046 (sim-universe) 의 🔵 FORMAL 후보 중 정수-위상 불변량 2종 (SSH Zak/winding
number ∈ {0,1} · Hofstadter TKNN Chern label via Diophantine `r=qs+pt`) 을 atlas
atom 으로 등록하려 했으나, `hexa verify --expr` 계산기 시스템에 **이 물리 정수-불변량
fn 들의 recompute path 가 없어** (number-theoretic `fn(int)->int` 만 지원) g5 게이트
(🔵 FORMAL / 🟢 NUMERICAL) 를 충족 불가 → **등록 보류, finding note only**.

cycle 6 lane 3 교훈과 동일 구조 ("verify 계산기는 정수론 닫힌형만"), 단 이번엔
인자/값이 정수임에도 (float 통계 변환이 아님에도) 해당 **함수 이름** 자체가 계산기에
없어 막힌 케이스다.

## dup-race precheck (PASS — 신규)
- `hexa atlas lookup --prefix=ssh` → `# no nodes match prefix: ssh`
- `hexa atlas lookup --prefix=hofstadter` → `# no nodes match prefix: hofstadter`
- `hexa atlas lookup --prefix=zak` → `# no nodes match prefix: zak`
- `git log --grep=ssh_topology|hofstadter|zak|Chern|RFC 046 -i --all` → sim-universe
  흡수/flame 커밋만, ssh/hofstadter 수학 atom 커밋 0건.
- `gh pr list --search "ssh hofstadter zak chern RFC 046" --state all` → 0건.
- 결론: 제안 atom (`ssh_zak_winding` · `hofstadter_tknn_chern`) 미등록 — dup 아님.

## 추출한 정수-identity (출처: stdlib/sim_universe/experiments/)

### 1. SSH Zak/winding number ∈ {0,1} — `ssh_topology/ssh_topo.hexa`
- 위치: `fn _winding_closed() -> i64` (L329-332):
  ```
  fn _winding_closed() -> i64 {
      if __w > __v { return 1 }   // topological  (w > v)
      return 0                    // trivial      (v > w)
  }
  ```
- 정수 위상 불변량 W = 1 (topological, w>v) / 0 (trivial, v>w). Zak phase γ = πW.
  King-Smith–Vanderbilt loop 의 discretized Berry phase (`_zak_winding`, L341-369)
  와 closed-form 이 일치해야 하는 bulk-boundary correspondence 의 정수 라벨.
- 출처: SSH 1979 (Su, Schrieffer, Heeger, PRL 42 1698).

### 2. Hofstadter TKNN Chern label via Diophantine — `hofstadter/hofstadter.hexa`
- 위치: `fn _dio_label(rgap, p, q) -> [i64]` (L385-404) + `fn _ext_euclid` (L365-383).
- gap r (r=1..q-1) 의 정수 Hall conductance / Chern 수 (s,t) 가 Diophantine
  방정식 `r = q*s + p*t` (gcd(q,p)=1) 을 풀고, `|t| <= q/2` 로 lattice-shift 한
  유일한 TKNN/Wannier 라벨. 반환 `[s, t]`, t = filled-band 아래 누적 Chern 수.
- 출처: TKNN 1982 (Thouless, Kohmoto, Nightingale, den Nijs, PRL 49 405) ·
  Hofstadter 1976 (PRB 14 2239).

이 두 fn 은 모두 순수 정수 입출력 (`fn(int...)->int`) 닫힌형이라 **원리상 verify
int-path 의 자연스러운 후보**다 — 막힌 것은 시그니처 부적합이 아니라 함수가 계산기
dispatch 에 미등록이라는 점뿐이다.

## 블로커 — g5 게이트 충족 불가 (VERBATIM verify verdict)

`hexa verify --expr <fn> ...` 의 recompute 시스템 (`tool/verify_cli.hexa::_recompute`
· `_recompute2`, 그리고 register-sink 가 mirror 하는 `tool/atlas_cli.hexa::
_recompute_register` · `_recompute2_register`) 은 **정수론 닫힌형 화이트리스트만**
지원한다 (sigma · sigma_0 · sigma_2 · phi · mu · tau · is_perfect · aliquot ·
gamma0_index · gamma0_cusps · gamma0_genus · isotropy_lcm · first_cusp_form_weight
· 2-op sigma_k · jacobi · kronecker · dim_cusp_forms). 위상-불변량 (Zak winding ·
TKNN Chern · Diophantine label · ext-euclid · sign) 을 표현할 dispatch 가 없다.

실측 (VERBATIM):

```
$ hexa verify --expr winding 1 0
verify --expr winding(1)=0
  tier   = 🟠 INSUFFICIENT
  reason = calculator system has NO path for 'winding'
  gap    = extend tool/verify_cli.hexa::_recompute (계산기시스템 개선 후보)

$ hexa verify --expr zak_winding 1 0
verify --expr zak_winding(1)=0
  tier   = 🟠 INSUFFICIENT
  reason = calculator system has NO path for 'zak_winding'
  gap    = extend tool/verify_cli.hexa::_recompute (계산기시스템 개선 후보)

$ hexa verify --expr chern 1 0
verify --expr chern(1)=0
  tier   = 🟠 INSUFFICIENT
  reason = calculator system has NO path for 'chern'
  gap    = extend tool/verify_cli.hexa::_recompute (계산기시스템 개선 후보)

$ hexa verify --expr tknn 1 0
verify --expr tknn(1)=0
  tier   = 🟠 INSUFFICIENT
  reason = calculator system has NO path for 'tknn'
  gap    = extend tool/verify_cli.hexa::_recompute (계산기시스템 개선 후보)

$ hexa verify --expr ext_euclid 3 6 1
verify --expr ext_euclid(3,6)=1
  tier   = 🟠 INSUFFICIENT
  reason = calculator system has NO path for 'ext_euclid'
  gap    = extend tool/verify_cli.hexa::_recompute (계산기시스템 개선 후보)
```

(추가 probe — 모두 동일 🟠 INSUFFICIENT: `ssh_winding` · `dio_label` ·
`diophantine` · `zak` · `hofstadter_chern` · `winding_closed` · `gcd` ·
`extended_euclid` · `bezout` · `sign` · `sgn`.)

- verdict = **🟠 INSUFFICIENT** (≠ 🟢 NUMERICAL · ≠ 🔵 FORMAL).
- 계산기가 진짜로 동작함은 sanity 로 확인: `kronecker(3,5)` 는 -1 을 계산해
  내 의도적 오답(=1)에 대해 **🔴 FALSIFIED** 를 정확히 발급 (LLM self-judge 아님).
- `hexa atlas register --from-verify` 경로도 막힘: 어댑터가 `_recompute_register`
  no-path → `🟠 INSUFFICIENT` event 를 생성하고, canonical sink
  `tool/atlas_cli.hexa::register_from_event` 는 `verdict != "🔵 SUPPORTED-FORMAL"`
  인 event 를 **거부** (L829-831). 따라서 등록 자체가 불가.

작업 지시의 제약 — "🔵/🟢 미발급 (verify int-path 도 못 함) 이면 finding note 만,
NO-OP 코드 금지" — 에 따라 등록을 보류하고 본 note 만 남긴다. (g5: verify verdict
VERBATIM 인용 · LLM self-judge 금지 · sympy/Wolfram cite 금지.)

## 등록을 풀려면 (carry-forward — cycle 8 lane 1 머지 후 재시도)
g5 를 충족하려면 verify 계산기에 위상-불변량 정수 recompute path 를 추가해야 한다.
이 두 atom 은 **순수 정수론 path 확장만으로** (float 미필요) 닫을 수 있어 cycle 8
lane 1 (verify float-path) 과 독립적으로도 가능하다 — 단, 두 작업이 동일 dispatcher
(`_recompute` / `_recompute2`) 를 건드리므로 머지 순서를 정렬하는 편이 안전하다.

1. **`tool/verify_cli.hexa::_recompute2` 의 정수 확장** (그리고 `atlas_cli.hexa` 의
   mirror): 신규 dispatch 추가 —
   - `ssh_winding(v, w)` : `if w > v { 1 } else { 0 }` 재계산 →
     예 `ssh_winding(0,1) == 1` (topo) · `ssh_winding(1,0) == 0` (trivial),
     tolerance 0 → 🔵 SUPPORTED-FORMAL.
   - `tknn_chern(p, q, r)` (3-op 필요 — 현 `--expr` 는 2-op 까지만 파싱):
     `_dio_label(r,p,q)` 의 t 성분 재계산 → 예 φ=1/3, gap r=1 의 t 값과 일치 검증.
     3-op 인자 경로가 신규로 필요하다.
2. **공유 dispatcher 추출**: `verify_cli` 와 `atlas_cli` 가 `_recompute*` 를 중복
   inline (atlas_cli L470-472 주석 "extract once a 3rd consumer arrives"). 위상-
   불변량 확장은 이 추출과 묶는 것이 자연스럽다.
3. 그 후 `hexa verify --expr` 가 🔵 FORMAL 을 내면 두 atom 을 kind `@X`
   (cross-domain topology↔number-theory) 또는 `@P` (physics) 로 등록 —
   embedded.gen.hexa 직접 splice + PR-only (@D atlas_fold).

## cross-link
- RFC 046 (sim-universe absorption) · `proposals/rfc_046_sim_universe_absorption.md`
- `stdlib/sim_universe/experiments/ssh_topology/ssh_topo.hexa` (693 LoC,
  `_winding_closed` L329 · `_zak_winding` L341)
- `stdlib/sim_universe/experiments/hofstadter/hofstadter.hexa` (823 LoC,
  `_dio_label` L385 · `_ext_euclid` L365)
- 자매 케이스: `inbox/notes/2026-05-24-rfc047-mc-integrate-atoms-verify-gap.md`
  (RFC 047 float-path BLOCKED, 동일 register_from_event 거부 메커니즘) — 본 건은
  int-path 함수 미등록, 그쪽은 float 시그니처 부재.
- gov: project.tape `@D atlas_fold` (embedded.gen.hexa via branch→commit→PR) ·
  commons g5 (verify verdict VERBATIM · LLM self-judge 금지)
