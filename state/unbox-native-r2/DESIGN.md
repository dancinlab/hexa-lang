# r2 — 배열 인덱싱 native 언박싱 (HEXA_UNBOX_ARRAY_NATIVE · default-OFF)

> goal 런타임갭 all-closure의 **가장 큰 실이득 라운드**. probe k3_arrmap = **23.23×** 갭. R1(scalar)은 메커니즘을 PROVEN release-safe로 깔았으나 k1_sum이 `%`-bound라 ratio 1.0(정직음성)이었다. **배열은 `%`-bound 아님** → 실제 속도이득 기대. SSOT 보조: `state/runtime-gap-all-closure-roadmap.md` · R1 메커니즘 `state/unbox-native-r5/DESIGN.md` · byteeq 교훈 memory `project_hexa_byteeq_dwarf_cwd_artifact`.

## 근본원인 (probe)
`arr[i]` → `call hexa_index_get`(x86_64_linux.hexa:1523) · `arr[i]=v` → `call hexa_index_set`(:1568). 매 접근이 런타임 call(박싱 HexaVal idx 언박싱 + bounds check + 박싱 load/store). gcc -O2는 `mov [base+idx*8]` 1-instr. 23× = call+박싱+반복 bounds-check.

## 레버 (R1과 동일 단일 메커니즘 재사용)
provably-int 신호(MIR `Local.type_id==1`·R1서 백엔드 도달 실증됨) + typed-array(elem-type 알려짐)일 때만, 박싱 dispatch 차단봉(`&& !_unbox_arr`)으로 **기존 native 경로 fall-through**:
- `arr[i]` (provably-int i, typed arr) → `mov dst, [base + idx*8]`(elem-size scale) + TAG.
- `arr[i]=v` (provably-int i, typed v) → `mov [base + idx*8], v`.
- **bounds-check**: 처음엔 **유지**(elision은 별도·loop-invariant 분석 필요). call→inline cmp+jae trap로만 바꿔도 call 제거분 이득. raw pointer-walk(bounds elision)는 r2b로 분리.
- 불확실(idx 비-int·arr 비-typed·negative idx 가능)이면 **박싱 유지**(soundness firewall = R1과 동일).

## 게이트 (codegen 최고위험·R1과 동일 바)
1. **OFF byteeq gen3≡gen4 3타깃** (flag unset=origin/main과 byte-identical). **반드시 same-cwd 비교**(DWARF cwd 아티팩트 회피·memory project_hexa_byteeq_dwarf_cwd_artifact). `.text` diff로 코드차 vs debug-info차 구분.
2. **레버 실증**: k3_arrmap `aprime --emit=obj` asm서 `hexa_index_get/set` count ON<OFF + **output-parity**(max|Δ|=0·배열은 정수라 bit-exact) + ratio median-of-5 taskset.
3. ship smoke. byteeq 3타깃 CI GREEN 후에만 머지(default-OFF release-safe).

## 기대 결과
- k1_sum과 달리 **%-bound 아님** → ratio < 1.0(실가속) 기대. probe 23× 중 call+박싱 제거분이 먼저, bounds-elision(r2b)이 나머지.
- 정직: ratio가 23×만큼 안 닫히면 잔차 출처 기록(bounds-check 잔존·reg-alloc 미구현·strength-reduction). negative(type_id 미도달 케이스)도 보고.

## 의존성
R1(#4024) byteeq 3타깃 GREEN 머지 후 착수(메커니즘 release-safe 확인). 같은 `compiler/codegen/x86_64_linux.hexa`(+`arm64_darwin.hexa`) STMT 경로. 측정도구=R1 measure.sh 패턴 재사용(build_aprime linux·same-cwd Gate1).
