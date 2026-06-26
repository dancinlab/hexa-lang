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

---

## 측정 verdict (2026-06-27 · summer · branch perf/codegen-unbox-array-r2)

🧱 **honest NEGATIVE — 레버 NO EFFECT · root-cause = HIR type-lowering substrate gap (ⓑ, NOT codegen guard bug ⓐ).** 머지 안 함.

### 측정값 (state/unbox-native-r2/RESULT.txt · k3_arrmap N=4096 REP=2e5)
- **Gate1 OFF-byteeq = PASS** — patched-OFF .o == baseline(origin/main) .o, same-cwd, sha `1ef30e6ad3177696`. **메커니즘 release-safe(byte-neutral by construction) 실증.**
- **Gate2 lever = NO EFFECT** — patched asm OFF==ON **byte-identical** (`hexa_index_get=2 hexa_index_set=1` 둘 다 동일). 언박싱 가드가 한 번도 안 켜짐.
- **Gate3 ratio = 1.001** (레버 미발화의 자명한 귀결).
- **Gate4 parity = OK** (OFF==ON 동일 emit이라 자명).
- **Gate5 smoke = harness artifact** — `~/.hx/bin/hexa run hello`는 flag 없이 rc=0(정상)·OFF==ON 동일 emit이라 flag가 smoke를 깰 수 없음. measure 하네스의 cwd/runtime 아티팩트(진짜 회귀 아님).

### root-cause (HEXA_ARRU_DEBUG=1 probe로 실측 특정)
codegen 가드는 **정확히 배선됨** — `local_type` 빌드됨·idx `type_id==1` 백엔드 도달 실증(`ARRU index: cont.kind=local cont.type_id=0 idx.kind=local idx.type_id=1 local_type.len=5/10`). 유일한 갭 = **container 배열 local의 type_id=0(101 아님)**. `_type_id_of` probe로 정확한 Type shape 캡처:

```
TYIDOF kind=generic:Array name=void nargs=0
```

3-레이어 dissection (파일:라인 인용):
1. `compiler/parse/parser.hexa:439` — `[i64]` → `TypeRef { kind: "generic", name: "Array", args: [inner] }`. **element type는 `args[0]`에 보존됨**(여기까진 신호 존재).
2. `compiler/lower/ast_to_hir.hexa:144-151` `_hir_lower_type_ref` — non-"named" TypeRef를 fallthrough에서 `Type { kind: tr.kind + ":" + tr.name, args: [] }`로 변환 → **`kind="generic:Array"` 이고 `args: []` (element type DROP)**. 여기서 elem-type 신호가 파괴됨.
3. `compiler/lower/hir_to_mir.hexa:205-210` `_type_id_of` — `t.kind == "array"`만 101..104로 매핑. 실제 shape는 `"generic:Array"`라 **이 분기는 영영 매칭 안 됨(dead code)** + `nargs=0`이라 element 복구 불가 → `return 0`.

### 분류: ⓑ substrate gap (lattice-widening 선행 필요) — NOT ⓐ guard bug
- elem-type 신호는 **parser에는 존재**하나 **HIR type-lowering이 폐기**한다 → codegen-side 어떤 작업으로도 typed-prim-array를 인식 불가. `_type_id_of`의 array 분기(101-104)는 **현재 dead** — nvptx GPU-kernel array-param 경로(nvptx_target.hexa:398-401 decode)도 이 type_id를 **현재 못 받고 있을 것**(같은 갭, 별도 확인 대상).
- r2의 codegen 메커니즘(가드+native load/store+bounds)은 **완성·byte-neutral·release-safe**(Gate1 PASS). 발화만 못 함.

### 선결 작업 (r2-pre · lattice-widening, 별도 cycle)
typed-prim-array 인식을 켜려면 **ungated 공유 HIR 변경** 2곳:
- (A) `_hir_lower_type_ref`(ast_to_hir.hexa)가 `kind=="generic" && name=="Array"`(및 `"Array:<elem>:<N>"`)일 때 `tr.args`를 재귀 lower해 element type을 보존하고 array kind를 emit.
- (B) `_type_id_of`(hir_to_mir.hexa)가 그 shape를 101..104로 매핑(현 `kind=="array"` 분기를 실제 shape에 정렬).
- **byteeq 리스크**: 둘 다 모든 배열 Type의 MIR `Local.type_id`를 0→101..104로 바꿈 → nvptx codegen·기타 type_id 소비자에 영향 → **3타깃 byteeq + nvptx 회귀 전수 측정 필요**. r2 PR 범위 밖(릴리스무결성 > self-host 진척).
- r2-pre 착지 후 이 branch의 codegen 메커니즘 재측정하면 ratio<1.0 기대(메커니즘은 이미 준비됨).

### 산출물 상태
- branch `perf/codegen-unbox-array-r2`(commit fa004ae17) = codegen 메커니즘 완성·Gate1 byte-neutral 실증. **머지 보류**(레버 미발화 = 단독 가치 없음·byteeq-neutral이라 무해하나 dead). r2-pre 선결 후 재활성 or r2-pre에 흡수.
