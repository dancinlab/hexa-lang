# HEXA-OWN L2 × Wall A 정적 타입 — 통합 레시피 (lane B · workflow w4gwzr7rz)

## Wall A 현황 (main @ 9f1b7a70d · 검증)

- `HEXA_STATIC_TYPES=1`이 거부하는 것 = **스칼라 5형뿐**, 전부 HX3011 · 전부 `compiler/check/types.hexa` `_infer_expr` 내부: r1 let-리터럴(:2119) · r2 let ident/call RHS(:2140) · r3 decl/init-split assign(:2199·Block 레코더 :1940) · r4 배열 원소 index-assign(:2205·`[]name` 키 :1971) · r5 struct 필드 assign(:2234·`{}name` 키 :1991).
- 타입 정보 = 파스타임 어노테이션만(`name|typename` 인코딩+side registry) · unification 없음 · env() 라이브 read 3곳(캐시 없음 — default 플립 전 캐시 필수).
- 미커버: fn param/call-arg 엄격화 · return 엄격화 · cross-fn 컨테이너 불변성 · generics/trait(별도 HEXA_CONST_GENERICS·HX3007-9) · match arm.
- **r7+ 벽(브랜치가 선언·소스 확증)**: `_types_lower_type_ref`가 generic/fn/tuple TypeRef를 빈-args 문자열 sentinel로 강등(types.hexa:931-939) · check쪽 배열 branch 부재(HIR쪽 ast_to_hir.hexa:159-169엔 있음) — r6=마지막 scope-wireable 단.

## r6 (PR #4108) 머지성

- 내용: StructLit 필드-init 스칼라 mismatch REJECT 1건(+155줄·types.hexa+51). byteeq-중립 구조(env() 첫 피연산자 short-circuit·check/docs만 터치).
- 307 커밋 뒤처짐 · merge-tree 충돌 **ARCHITECTURE.json 1건뿐**(compiler 파일 자동머지) → 기계적 해소 가능(#4135 교훈: JSON 검증 후 커밋).
- 부수 결함 2건: ① `state/rfc_static_types_rust_ladder.md` 참조가 dangling(파일 부재) ② HX3011 explain 텍스트가 r1 범위만 서술(catalog.hexa:339-345 stale).

## @own(L2) 통합 레시피 (검증된 앵커)

- **파서 무수정**: parse_stmt가 이미 임의 `@name` 어노테이션을 let 앞에서 수집(parser.hexa:1744-1748→Expr.annotations :1731). types.hexa는 raw AST를 걷기 때문에 r1~r5 arm이 `e.annotations`를 직접 읽음.
- **패스 배치**: tail-slot 모듈 패스가 아니라 **기존 `_infer_expr` Block arm의 순차 benv-threading 루프(types.hexa:1936-1998) 확장** — use-after-move는 문장 순서가 필요하고 그건 이 루프만 가짐. move-site는 이미 노출: let-RHS :2140 · Assign :2180-2292 · call args :2577/:2629 · return :2067 · match scrutinee :2659.
- **own-ness 저장 = side registry(병렬 배열·r5 형태·type_check :3490서 리셋)** — Type{} 신규 필드는 83 구축지점 파급이라 금지, env-키 재정의는 `_types_env_lookup` first-hit-wins(:1466-1476)라 **조용히 불발**(함정·필수 회피).
- **warning 템플릿**: `_exh_check_module`(types.hexa:2892-2907·HX3006 Warning·abort 안 함 main.hexa:224-231) = own-lint r1의 골격.
- **플래그**: `HEXA_OWN_LINT` 독립 opt-in(모든 신규 사이트에서 첫 && 피연산자) → 코퍼스 clean 실측 후 HEXA_STATIC_TYPES 편입 검토(HX3006식 승격 경로).
- **미결(사용자 콜)**: fn param의 @own 표면 — fn-레벨 `@own("pname")` 인자형(파서 무수정·비정통) vs Param에 annotations 필드 추가(정통 Rust식·AST 파급). Param(ast.hexa:52-63)엔 현재 annotations 없음 + parse_stmt가 non-let 어노테이션을 조용히 드랍(parser.hexa:1741-1743).

## 리스크 요지

- `--ignore-errors`(main.hexa:696)가 HX3011 지나 codegen까지 통과 가능 — "flag-ON=무조건 pre-codegen 차단" 주장엔 이 단서 필요.
- aprime-전용 @own은 gen2(self/) 어노테이션 체계와의 drift 생성(Wall A가 이미 지는 갈래) — PR에 명시.
- r6 flag-ON은 헤드라인 체크 외에 field-init 내부식 신규 진단도 켬(의도됨·PR 설명 필요).

## 다음 라운드 순서

1. **r6(#4108) 먼저 착지**: main 머지+ARCHITECTURE 충돌 해소+dangling RFC 저작(or 참조 스크럽)+HX3011 explain 현행화 → byteeq 재확인 → 머지.
2. **@own r1 슬라이스**: HEXA_OWN_LINT warning-band use-after-move(블록-로컬 `@own let` 한정) — 위 레시피 그대로.
3. (r6 천장 RFC와 별개 프레임) check-side 배열 lowering 패리티 = cross-fn 컨테이너 불변성 선행 작업(flag-neutral).
