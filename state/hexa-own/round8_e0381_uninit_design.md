=== Fable round8(E0381 uninit dataflow) 설계 발사 ===
파일 박제는 권한이 막혀 있어 설계 전문을 여기로 낸다 (구현 시 `state/hexa-own/round8_e0381_uninit_design.md`로 저장 권장).

**요약 — CFG는 충분, 보강 불요. 핵심 실측 3개: ① 무초기화 `let x`는 MIR에선 `= 0`과 구별 불가라 등록 지점은 HIR let 암의 `children==0`뿐 ② return으로 끝난 분기는 join 에지가 생략돼 있어 must-init AND-join의 FP가 구조적으로 차단됨 ③ 코퍼스 전체(297k let)에 무초기화 let이 0건이라 FP 노출면이 空 — flag-ON self-host도 diag 변화 0.**

주의: 모든 file:line은 **main(9b462040a)의 hir_to_mir.hexa(5817줄)** 기준. 현 체크아웃 브랜치(fix/install-bare-cuda-pip)의 4568줄 사본과 좌표가 다르니 구현은 main에서 분기할 것.

---

## 0. 실측 — CFG 충분성: 충분

- **CFG**: `Block { id, stmts, preds, succs }` (compiler/ir/mir.hexa:114-119), 에지는 `_add_edge`(hir_to_mir.hexa:741-751)로 전 분기 배선:
  - if/else: entry→then/else 3432-3433; join 에지는 `!then_returned`/`!else_returned` 게이트(**3466, 3493**) → `if c { return } else { x=1 }; use x`에서 return-분기가 join의 pred가 아님 — E0381 FP 차단의 결정적 성질.
  - no-else if: else_id가 곧 after(3525+) → `if c {x=1}; use x`는 uninit pred가 남음(rustc도 fire — 정합).
  - while: 3570/3586-3587, back-edge 3608-3612(`!has_returned` 게이트). break/continue: sentinel(-7001/-7002, 2955-2990)을 `_patch_loop_sentinels`(1533-1580)가 패치하며 실제 에지 추가(1565-1566→849).
  - match: arm_end→join 4228-4263(`!has_returned` 게이트); wildcard 없으면 폴스루 pred 실존(3843) — hexa 의미론상 진짜 uninit 경로.
- `_bck_nll_check`(1020-1145)가 이미 preds-기반 fixpoint(flat 비트행렬·id2ix·cap `nb*4+8`·loud bail)를 실증 — E0381은 이 패턴 클론 + gen/kill transfer만 추가.
- **uninit 표현**: 파서가 `=` 없으면 children=[](parser.hexa:1906-1910); let 암(2993-3001)이 `rhs_op=_const_int_op(0)`으로 `STMT_ASSIGN op:"let"` emit → **MIR상 `=0`과 동일**. 판별은 HIR let 암 `len(e.children)==0`에서만.
- **재대입**: assign 암(3177-3308)이 `_mir_lookup`으로 기존 local id 재사용(did_reuse 3260-3270) → init-킬을 local id로 키잉. RHS가 먼저 lower(3254) → `x = x+1`의 use-before-init 순서 정확.
- **use funnel**: 전 ident 값-사용이 ident 암(1884-1903)→`_bck_check_use`(1900-1902) 단일 관문. `_bck_note_move`(673-680)는 **재사용 안 함** — use-after-move는 HX3012/HX3014 Rule2 축, 이중보고 방지(문서화 under-report).
- **클로저**: `_bck_active` save→false→restore(4612-4613, 4701) — 신규 훅 자동 suspend.
- **코퍼스 census**(Explore 서브에이전트, 전수): 무초기화 let = compiler/stdlib/self **0건**(297k let 라인, working tree·main 모두, whole-line + no-`=` 브로드 + 주석 엣지 3중 확인).

## 1. 최소 상태축

**레지스트리** (모듈 스코프 parallel arrays — no new struct, `_bck_in_borrow_rhs` 567행 뒤; `_bck_reset_fn`(569-594)에 리셋 append):

```hexa
pub let mut _bcki_ids: [i64] = []          // tracked = 무초기화 let의 local id만
pub let mut _bcki_names: [string] = []
pub let mut _bcki_decl_lines: [i64] = []
pub let mut _bcki_ev_kind: [i64] = []      // 0=INIT(kill) 1=USE — push순=블록내 프로그램순
pub let mut _bcki_ev_t: [i64] = []         // _bcki_ids 인덱스
pub let mut _bcki_ev_blocks: [i64] = []
pub let mut _bcki_ev_spans: [Span] = []
pub let mut _bcki_in_place_base = false    // field/index_set base 억제 플래그
pub let mut _bcki_e_lines: [i64] = []      // HX3035 전용 dedup (기존 _bck_e_*와 분리)
pub let mut _bcki_e_cols: [i64] = []
```

**배선 4지점** (전부 `_bck_active` 게이트):
- **W1 등록** — let 암 `_bind`(3082) 직후: `_bck_active && len(nm)>0 && len(e.children)==0` → push(dst.id, nm, e.span.line). 타입 무관 전부 등록.
- **W2 use** — `_bck_check_use`(950) 진입부, `ti<0` early-return(967-968) **앞**: `if !_bcki_in_place_base { t=_bcki_find(local_id); if t>=0 → USE-event }`. `_bck_in_borrow_rhs` 억제는 미적용(rustc는 `&x`도 E0381).
- **W3 init** — assign 암 stmt push 뒤(3305 부근): `did_reuse && lhs.kind=="ident"` && tracked(dst.id) → INIT-event. (tracked는 let이 _bind했으므로 항상 did_reuse 경로.)
- **W4 place-write** — field_set(3199-3225)·index_set(3227-3252): base lower(3200/3228)만 E5 패턴(2267-2272) 자구 클론으로 `_bcki_in_place_base` save/set/restore — **key expr(3229)·RHS는 제외**(`a[i]=v`의 uninit `i`는 정상 fire). stmt push 후 base가 tracked면 **INIT-event**(부분초기화=silent).

**fixpoint `_bcki_check()`** — 5620-5625 기존 게이트에 `_bck_nll_check()` 옆 병치:
- early-out `len(_bcki_ids)==0` → 코퍼스 0건이라 flag-ON에서도 사실상 전 fn 즉귀.
- rustc MaybeUninitializedPlaces 정합(may-analysis): bit=1 ⇔ entry에서 maybe-uninit. seed `IN[entry][t]=1`; transfer `OUT[b][t] = 0 if b has INIT(t) else IN[b][t]`(gen=∅·kill=init); join `IN[b][t] = OR(preds OUT)` — 정답지 must-init AND의 dual. 단조증가→수렴; 1026-1113 클론(id2ix·flat `nb×T` 행렬·cap `nb*4+8`·loud bail=해당 fn 결과 드롭).
- emit 판정: USE-event u에서 `IN[block(u)][t]==1` **AND** 같은 블록 내 u보다 앞선 인덱스의 INIT(t) 부재 → emit. (`let x; x=1; use x` clean / `let x; use x; x=1` fire.)

## 2. emit / catalog

- `_bcki_emit_uninit_use(name, decl_line, sp)` = `_bck_emit_use_while_mut`(892-918) 클론: 전용 dedup → `diag_new("HX3035")` → args(name, decl_line) → `if _bck_strict { diag_with_severity(d, Severity::Error) }` → `_lr_diag.push`.
- catalog(HX3027 블록 488-505 뒤): severity **Warning**, stage "S3", `fix_it_kind: FixItKind::None`, template `` "used binding `{name}` is possibly-uninitialized (declared without an initializer at line {decl_line})" ``. explain 완결블록: 옵트인 HEXA_BORROWCK=1 · rustc E0381 + rustc_mir_dataflow MaybeUninitializedPlaces reference-match · OR-join(=must-init AND dual) forward fixpoint · 같은-블록 순서 정밀 · silent 경계(§3) · STRICT 재밴딩 · flag-OFF byteeq-neutral · Fix 가이드.
- ⚠️ **catalog-hexa-1**: main 오늘 최대 코드 = **HX3027**. HX3028-3034는 in-flight round4-7 가정 — 구현 시 `grep -o 'HX3[0-9][0-9][0-9]'` 재확인, 충돌 시 next-free로 밀 것.

## 3. conservative 경계 (FP-0)

- **Silent**: 초기화 있는 let 전부·param·match/for 바인딩·클로저 바디/캡처·부분초기화(`s.f=1`은 base억제+INIT킬 → 이후 `use s`도 silent; rustc는 fire지만 FP-0 우선 — hexa 런타임에선 uninit에 field_set 자체가 abort하는 별개 결함)·@own move(킬 없음).
- **필수-clean 보장**: `if{x=1}else{x=2};use x`(OR-join dual) · `if c{return}else{x=1};use x`(3466/3493 에지 생략) · `let x; x=1; use x`(블록내 순서) · unreachable 블록(pred 없음→IN=0).
- **conservative-fire(레퍼런스 정합, FP 아님)**: no-else if 후 use · while 첫 반복 전 use · wildcard 없는 match 후 use(폴스루 실존) · hexa-특이 스코프 누수(`if c { let x }; use x`가 flat `_lr_bindings` newest-wins로 inner에 resolve — hexa 의미론상 진짜 uninit 경로, explain 명시).

## 4. companion test — compiler/check/borrowck_test.hexa에 probe 추가 (3-모드 관례, ★union 금지·probe별 명시 카운트)

| probe | 골자 | OFF | ON | STRICT |
|---|---|---|---|---|
| hz_use_before_init | `let x: i64` → `let y = x+1` | 0 | ×1 | ×1 Error-band |
| hz_use_then_init | `let mut x: i64` → `let y = x` → `x=1` | 0 | ×1 | ×1 |
| hz_loop_first_iter | `let mut x: i64` → `while c { let y=x  x=1 }` | 0 | ×1 | ×1 |
| fp_init_then_use | `x=1` 후 use | 0 | 0 | 0 |
| fp_init_both_branches | if/else 양쪽 init 후 use | 0 | 0 | 0 |
| fp_return_branch | `if c { return 0 } else { x=1 }` 후 use | 0 | 0 | 0 |
| fp_field_partial | `let s: P` → `s.f=1` → use `s.f` | 0 | 0 | 0 |
| fp_normal_let | `let x=1; use x` (control) | 0 | 0 | 0 |

STRICT 레그는 `_count_error_band == _count_code("HX3035")`(기존 96-106 헬퍼 재사용); OFF 전량 0 = diag-stream byteeq 증명.

## 5. byteeq 중립 논증

① 신규 지점 전부 `_bck_active`(기본 false, env latch 5654-5665 재사용 — 신규 env read 0) 뒤 ② 패스는 관찰 전용 — MIR stmt/local/block 무변경(M3/M4 계약 438-444 상속) → flag-OFF MIR 바이트 동일 ③ 코퍼스 무초기화 let 0건 → flag-**ON**조차 self-host diag 변화 0 (gen3≡gen4 이중 안전).

## 6. 위험 / 미검증

- HX3035 번호는 in-flight 가정치 — 구현 시 catalog 재grep 필수.
- fixpoint 비용: T==0 early-out으로 실질 0; T>0만 `nb×T` — M4 봉투 내, loud bail.
- 미검증 ①: `let x: i64` 뒤 `x=1`의 did_reuse 실행 검증 — fp_init_then_use가 즉시 잡음. ②: match 폴스루 카운트 — v1 probe 제외, round9(HX3006 exhaustive 축 교차)로 이월.
- W4 save/restore 누락 시 place-write마다 오발 — E5 2267-2272 자구 클론으로 자기치유.
- 라인 드리프트: round5-7 머지 선행 가능 — 배선 앵커는 라인이 아닌 **심볼**(`_bck_check_use` 진입부 / let 암 `_bind` 직후 / assign 암 did_reuse push 뒤 / field·index_set base lower / `_bck_nll_check()` 게이트)로 잡을 것.
