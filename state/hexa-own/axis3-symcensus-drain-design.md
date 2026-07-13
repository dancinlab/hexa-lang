# axis-③ run 관문 — codegen↔runtime 심볼-정합 census 드레인 설계 (whack-a-mole 종결)

2026-07-11 · census 기준 = **origin/main 74e770cd5** (#4838 push_nostat 매핑 포함) + in-tree
`build/runtime.a` nm(darwin, Jul 9). ⚠️ 로컬 워킹트리(fix/install-bare-cuda-pip)는 stale —
아래 라인번호는 전부 origin/main blob 기준.

## 0. 교정된 전제 (실측 falsification)

| 요청서 전제 | 실측 |
|---|---|
| types.hexa 화이트리스트 = 37 | **93** (`_is_builtin_method`, compiler/check/types.hexa:2708-2747) |
| 미등재 = 27 | **60** (93 − 매핑 120키 교집합; 27은 부분집합) |
| 매핑 105 | main 기준 **키 120** (arm64_darwin.hexa:1806-2028 단일 공용 테이블 — x86_64_linux.hexa:4984는 같은 fn 호출, 백엔드 divergence 구조적 불가) |
| read_file_bytes = 별개 카테고리 | 맞음 — 그리고 그 카테고리(`_bind_builtin_names`, bind.hexa:1354, 395명)의 갭은 **144 need-map + 48 triage** (아래 Rung B) |

핵심 구조 사실:
- 매핑 fallthrough = `return name`(arm64:2027) → 미등재명은 bare emit → hexa_ld dyn census가
  "runtime.a에 없음=libc"로 **무진단** dynamic 라우팅(elf_x86_64.hexa:1776-1823, origin/main) → rc127/SIGBUS.
- x86에서는 `is_builtin = (target != s.op)`(x86:4994)가 **builtin/user-fn ABI 판별자 겸용** —
  매핑 추가 = 해당 이름이 builtin pair-ABI 경로로 전환(의도된 효과; 기존 링크불가라 회귀 없음).
- `_builtin_ret_box`(arm64:2033-2039) = 대상 runtime fn이 raw int/bool 반환일 때만 필요.
- hexa_ld ELF census 시점에 **runtime.a 전체 def 우주가 없음**: `archive_extract_fixpoint`
  (elf_x86_64.hexa:3343-3449)가 전 멤버 symtab을 파싱해놓고 pulled objs만 반환, 전체 def set은
  폐기(:2314-2326). "near-miss 진단"이 현재 데이터플로우로는 불가능한 이유.
- darwin hexa_ld(tool/hexa_ld.hexa)는 pull-all이라 전체 def가 있으나, 미정의 extern을 무진단
  libSystem import로 분류(:1017-1115) — 동일 클래스가 SIGBUS/dyld-crash로 발현.

## Rung A — array/string/map 메서드 60개 일괄 매핑 (매핑 diff)

삽입 지점: `compiler/codegen/arm64_darwin.hexa` `_builtin_runtime_sym` 테이블(1806-2028, 단일 공용).
전 타깃 nm-확인(darwin runtime.a) 완료 — pod에서 linux runtime.a 재확인 후 머지.

### A-1. 순수 rename (HexaVal-in/out, ret-box 불요) — 49개
```
all→hexa_array_all  any→hexa_array_any  append→hexa_array_push  center→rt_str_center
char_at→hexa_str_char_at  chunk→hexa_array_chunk  drop→hexa_array_drop
entries→hexa_map_entries  enumerate→hexa_array_enumerate  fill→hexa_array_fill
filter→hexa_array_filter  filter_keys→hexa_map_filter_keys  flat_map→hexa_array_flat_map
flatten→hexa_array_flatten  fold→hexa_array_fold  for_each→hexa_array_for_each
frequencies→hexa_array_frequencies  from_array→hexa_map_from_array  group_by→hexa_array_group_by
interleave→hexa_array_interleave  invert→hexa_map_invert  is_empty→hexa_is_empty
lines→rt_str_lines  map→hexa_array_map  mean→hexa_array_mean  merge→hexa_map_merge
pad_end→rt_str_pad_right  pad_start→rt_str_pad_left  parse_float→hexa_str_parse_float
partition→hexa_array_partition  product→hexa_array_product  repeat→rt_str_repeat
reverse→hexa_array_reverse  rotate→hexa_array_rotate  sample→hexa_array_sample
scan→hexa_array_scan  shift→hexa_array_shift  sort→hexa_array_sort  sort_by→hexa_array_sort_by
substr→hexa_str_substr  sum→hexa_sum  swap→hexa_array_swap  take→hexa_array_take
to_array→hexa_map_to_array  trim_end→rt_str_trim_end  trim_start→rt_str_trim_start
unique→hexa_array_unique  values→hexa_map_values  window→hexa_array_window  zip→hexa_array_zip
```
gen2 수렴 근거(self/codegen.hexa): append=push 별칭(:6029) · sum=hexa_sum(:6346, hexa_array_sum 아님) ·
merge/to_array=map 전용(hexa_array_merge/hexa_array_to_array **runtime def 자체가 없음** — 매핑으로 못 만드는
시맨틱; gen2도 map으로만 emit) · pad_start/end=rt_str_pad_left/right 3-인자(:10374; 기존 pad_left/right
엔트리는 2-인자 hexa_pad_left와 별개 유지) · slice=hexa_array_slice(:6444; string은 substr 경로).

### A-2. ret-box 필요 — 2개 (`_builtin_ret_box`에 "int" 추가)
```
rfind→hexa_str_last_index_of   last_index_of→hexa_str_last_index_of
```
근거: `int64_t hexa_str_last_index_of(HexaVal,HexaVal)` (runtime.c:3831) — gen2가 hexa_int() wrap(:6119).

### A-3. HexaVal-순수 shim으로 우회 — 3개 (cstring-인자 원함수 회피)
```
contains_key→hexa_has_key_v   has→hexa_has_key_v   remove→__map_remove_cstr_v
```
근거: `hexa_map_contains_key(HexaVal, const char*)`·`hexa_map_remove(HexaVal, const char*)`는
raw-cstring 인자라 직접 매핑 불가. `hexa_has_key_v`(기존 has_key 타깃)·`__map_remove_cstr_v`
(HexaVal(HexaVal,HexaVal), runtime def 확인)로 우회 — runtime 변경 0.

### A-4. arity-분기 필요 — 2개 (이름만으론 오배선되는 유일군)
```
min: nargs==1→hexa_array_min · nargs==2→hexa_math_min
max: nargs==1→hexa_array_max · nargs==2→hexa_math_max
```
근거: gen2는 AST에서 Field(메서드) vs 자유호출로 구분(:6222-6231 주석 "SHADOW … no ambiguity")하지만
MIR STMT_CALL은 op 텍스트로 합류(hir_to_mir:1702-1717이 recv를 args[0]에 prepend) → **arity가 유일한
판별자**(메서드 .min()=1인자, 자유 min(a,b)=2인자). 이름만 매핑하면 자유 min(a,b)이 hexa_array_min으로
resolve돼 **조용한 오답**(링크는 성공) — 60개 중 유일하게 rename-only가 회귀를 만드는 케이스.
fix: `_builtin_runtime_sym`에 nargs 인자 추가(공용 1곳) 또는 `_builtin_runtime_sym_n(name, nargs)`
신설 + 두 백엔드 호출부(arm64 generic tail·x86:4984)에서 `len(s.args)` 전달.

### A-5. optional-arg void-sentinel 합성 — 4개 이름
gen2는 빠진 뒤 인자를 `hexa_void()`로 채움: slice/slice_fast 1-인자(:6444-6452) ·
count 0-인자(:6204-6210, hexa_count_poly) · substr(3-인자 sentinel). native도 동일 합성 필요.
**삽입 지점 권고 = hir_to_mir.hexa 메서드-호출 lowering(:1702-1717)**: op∈{slice,slice_fast,substr,count}
&& nargs<기대치 → MIR const-void 인자 append. 백엔드 2곳이 아니라 MIR 1곳 — 두 백엔드가 자동 상속,
백엔드간 divergence 원천 차단. (count→hexa_count_poly 매핑은 A-1군에 포함)

## Rung B — free-fn builtin 카테고리 (read_file_bytes 클래스)

원천 = `_bind_builtin_names`(bind.hexa:1354, 395명; 주석 :1613-1615가 "codegen `_builtin_runtime_sym`이
second gate라 generous해도 됨"을 **명시적 설계로 문서화** — 즉 이 클래스는 설계상 링크에서 터지게 되어
있고, dyn census가 그 링크 실패를 rc127 런타임 실패로 뒤로 밀어낸 것이 진짜 회귀 지점).

census: 395 − 매핑 120 − `_is_cabi` 85(x86_64_linux.hexa:2235) − `__hx_*`/`target_is_*` 특수경로 =

- **identity-OK 38** (bare 이름 그대로 runtime.a def — fallthrough가 이미 정답, 조치 불요):
  `__map_*_cstr_v`·`__raw_*`·`term_*` 등 (term류는 hexa_term_* + bare 이중 def).
- **need-map 144** (def가 prefix 밑에만 존재 — Rung A와 동형의 기계적 일괄 엔트리):
  `read_file_bytes→rt_read_file_bytes`(runtime_core.c:9029) · `read_bytes_at→rt_read_bytes_at` ·
  `read_lines→rt_read_lines` · `delete_file→rt_delete_file` · `write_bytes_v/append(_v)→rt_*` ·
  `input→hexa_input` · 나머지 ~135는 `hexa_<name>` 규칙 (net_*/proc_*/pty_*/regex_*/json_*/tensor_*/
  sleep_*/utc_*/crypto류 전부). 전체 리스트 = 본 census 재현 스크립트(§규율)로 기계 생성.
- **triage 48** (runtime def 매칭 0 — 이름별 판정 필요): `__builtin_va_*`(특수-op 경로, 조치 불요) ·
  `ptr_from_int`(arm64 전용분기 있음:3773류 — x86 커버 확인) · `assert/panic/argv/getenv/getpid/
  read_line/copy_file/…`(인터프리터-only 가능성 — native 경로 도달 시 여전히 rc127 클래스; Rung C
  린트가 잔여를 영구 표면화) · `thread_channel_*`/`atomic_cell_*`(native/thread.c 별칭 확인) ·
  `gpu_matmul*`(HEXA_CUDA 게이트) · `X`(추출 아티팩트, 무시).

우선순위: 144 일괄은 A와 같은 PR로 가능하나, **최소변경 원칙상 A(메서드 60)+B의 file-I/O·자주
쓰는 free-fn만 1차 PR, 나머지 144 잔여+triage는 2차** — 단 Rung C 린트가 같은 PR에 들어가면
잔여가 CI RED로 표면화되므로 1차에서 린트는 exemption 파일과 함께 착지.

## Rung C — 재발 영구 차단 3종 (근본안)

### C-1. in-tree 정합 린트 (PR-time 차단 · **주 가드**)
본 census 자체를 스크립트화: `(93 화이트리스트 ∪ 395 bind gate) − (매핑키 ∪ _is_cabi ∪ 특수-op ∪
identity-def exemption) = ∅` 어서션. runtime.a 없이 소스-리스트만으로 돌므로 cloud-CI에서 즉시 가동
(nobaseline-gate.yml에 스텝 추가). 새 builtin을 checker gate에만 넣고 매핑을 빼먹는 순간 PR RED.
3-표면(types.hexa/bind.hexa ↔ gen2 ↔ native 매핑) 비동기화라는 **진짜 root-cause를 원천에서 봉인**.

### C-2. hexa_ld near-miss tripwire (link-time fail-closed · 방어층)
- ELF: `archive_extract_fixpoint`가 이미 파싱한 전 멤버 def set을 반환값에 추가(:3448)해
  `link_elf_x86_64_ownstart`까지 배관(:2314-2326, ~10줄). census(:1776-1823)에서 UND `dnm`을
  dynamic 라우팅하기 **직전**: `hexa_(array_|str_|map_)?dnm`·`rt_(str_)?dnm` ∈ 전체 def set이면
  **hard error rc=3 refuse-emit** — "codegen-runtime sym mismatch: UND 'X' — runtime.a defines 'Y'
  (missing _builtin_runtime_sym entry)". 추가로 dyn 라우팅되는 이름이 hexa-own prefix
  (`hexa_|rt_|_hx_|__hexa|hxlcl_|forge_|farr_`)면 동일 hard error(역방향: drop-list/runtime 누락 검출).
- darwin: tool/hexa_ld.hexa import 분류(:1017-1060/1066-1115) 직전 동일 체크(전체 def set은 pull-all이라 이미 보유).
- **재해석(resolve 재작성)은 절대 안 함** — 진단+거부만. wrong-dynamic 위험 0.
- 관측성: dyn census 결과(이름·개수)를 `HEXA_LD_VERBOSE`서 eprintln(현재 완전 무진단).

### C-3. CI 링크산출물 dynsym 게이트
nobaseline-gate.yml의 advisory 덤프(:320-346)는 **runtime.a의 UND**를 재는 것이라 이 클래스를 원리적으로
못 잡음(불일치명은 프로그램 .o의 UND). 추가 게이트: own-link된 cc-self-bin에
`readelf --dyn-syms | awk UND` ⊆ sanctioned regex(:332-340 체인 재사용) 하드 어서션 — dl* 하드게이트
(:377-390)와 동형. 어떤 미래 emit-경로 신설이 매핑을 우회해도 PR RED.

## 근본안 판정 (파트 3)

**codegen 매핑 완성 = 정본(fix), 링커 방어 = fail-closed 진단 전용(가드), 린트 = 재발 봉인 — 셋 다, 역할 분리.**
- 이름 계약의 주인은 codegen이다(native-canonical): 링커가 부분매치로 **재해석**하면 shadow-guard이자
  wrong-dynamic 리스크(예: 사용자 dylib 심볼 오흡수)를 새로 만든다 — 기각.
- 그러나 "매핑만 완성"은 whack-a-mole 구조를 못 죽인다(다음 builtin 추가에서 재발). 재발 채널은
  ① checker gate에만 추가(C-1이 봉인) ② 새 emit 경로가 매핑 우회(C-2/C-3이 봉인). C-2는 재해석이
  아니라 refuse-emit이므로 "링커 방어=wrong-dynamic 위험" 우려가 성립하지 않는 형태로 취할 수 있음 —
  보장된 rc127 런타임 실패를 정확한 fix 지시문이 붙은 링크타임 에러로 앞당길 뿐.

## byteeq · 검증

- 매핑 추가 = additive: 대상 이름은 기존 native 경로에서 **링크 자체가 불가**했으므로(bare UND)
  기존-GREEN 산출물 불변 — byteeq 3-target GREEN 예상 불변. gen2 C 경로 무접촉.
- 잔여 리스크 프로브 2건(머지 전 필수):
  1) **user-fn shadowing**: `fn zip(){}` 등 화이트리스트 동명 사용자 함수를 native 컴파일 →
     사용자 def로 resolve되는지(기존 get/set/find 엔트리가 이미 공존하므로 사실상 안전 추정이나 실측).
  2) **closure 재진입 ABI**: map/filter/fold/any/all/sort_by/group_by는 runtime→native 콜백 —
     pair-ABI 왕복 스모크.
- **pod 프로브**(linux runtime.a는 native-seed 구성이 darwin과 다름 — rt_str_* 공급원이 seed가 아닌 C 브랜치):
  1) `nm -g runtime.a | grep -E '^0.* T (hexa_array_(all|any|chunk|…)|rt_str_(lines|trim_start|…)|hexa_(sum|is_empty)|hexa_map_(merge|to_array|…)|__map_remove_cstr_v|hexa_math_(min|max)|rt_read_file_bytes)'` — 타깃 60+144 linux 실재 확인.
  2) 배치 후: self-emit cc-self-bin own-link rc0 + `readelf --dyn-syms` UND ⊆ sanctioned + run rc0.
  3) ABI 스모크 .hexa(신규 매핑 전 메서드 + optional-arg형: slice 1-인자·count 0-인자·substr 2-인자 +
     rfind ret-box + 자유 min/max 2-인자) — gen2 산출을 oracle로 출력 비교.

## census 재현 (mini read-only)
```sh
git show origin/main:compiler/codegen/arm64_darwin.hexa | awk '/pub fn _builtin_runtime_sym/,/^}/' \
  | grep -oE 'name == "[a-z_0-9]+"' | sed 's/.*"\(.*\)"/\1/' | sort -u > mapped
git show origin/main:compiler/check/types.hexa | awk '/fn _is_builtin_method/,/^}/' \
  | grep -oE '"[a-z_0-9]+"' | tr -d '"' | sort -u > whitelist
comm -23 whitelist mapped   # = 60
# free-fn: bind.hexa _bind_builtin_names(:1354) 동일 추출 − mapped − _is_cabi(x86_64_linux.hexa:2235) − __hx_*/target_is_*
# 타깃 매칭: nm -g build/runtime.a | awk '$2~/^[TDWSR]$/{sub(/^_/,"",$3);print $3}' | sort -u
```
