# incoming patch: rfc020-enum-payload-variants

> **id**: `rfc020-enum-payload-variants` · **opened**: 2026-05-10 · **status**: `in_progress`
> **trees**: `self/` (대부분 land) + `compiler/` (미반영)
> **source**: `proposals/rfc_020_enum_payload_variants.md` + commits below
> **why this matters**: wilson pi-port 의 load-bearing 갭 G1 — `ai` 패키지의 `AssistantMessageEvent` 가 discriminated union (`{type:"text_delta",...} | {type:"tool_call_start",...} | ...` 수십 종) 이라, hexa-strict 로 표현하려면 다중 ADT 가 필요. RFC-020 결정: **단일 필드 + struct 임베드** 패턴으로 모든 ADT 표현 → `enum AsmEvent { TextDelta(TextDeltaData), ToolCallStart(ToolCallStartData), ... }`. 그게 완전 작동해야 wilson core 착수 가능.

---

## 1. 현 상태 — RFC doc 의 "미구현" 표기는 STALE

RFC-020 (2026-05-09) 작성 시점엔 "부분 작동, 미구현" 이었으나, 그 후 **A1–A3 이 이미 land**:

| Phase | RFC doc | 실제 (2026-05-10) | 위치 |
|---|---|---|---|
| **A1** parser construction `E::V(x)` | "❌ 빈 EnumPath" | ✅ **DONE** | `self/parser.hexa` `parse_primary()` — `if p_peek_kind()=="LParen" { payload_expr = parse_expr(); ... }`, EnumPath 노드에 `"payload_expr"` 필드. commit `3c8be96c` "feat(self/parser): RFC-020 A1 — enum payload construction syntax". `self/native/hexa_cc.c:5556-5587` 에 boot hexa_v2 폴백 패치도 있음. |
| **A2** typechecker payload-type 테이블 | "❌ 이름만" | ✅ **DONE** | `self/type_checker.hexa:114` `enum_all_variant_payload_types` (parallel array), `:346 tc_register_enum_variant` (push ""), `:353 tc_register_enum_variant_payload(vname, ptype)`, `:361 tc_lookup_variant_payload(enum_name, variant_name) -> type name | ""`. |
| **A3** typechecker pattern binding | "❌ pat.left 무시" | ✅ **DONE** | `self/type_checker.hexa:1120` `if pat.kind=="EnumPath"`, `:1128` "RFC-020 A3: bind enum variant payload — `Shape::Circle(r)` introduces `r`". |
| **A4** codegen — struct/union + match 추출 + binding emit | "⚠️ tag만" | 🟡 **PARTIAL** | `self/native/hexa_cc.c:18090` "RFC-020 A4: payload variant construction" — construction site 가 `[tag, payload]` HexaVal array 를 emit (RFC 의 C `union` 안 쓰고 동적 array — interp 와 codegen 일관성). **match-side payload 추출 + arm-scope binding 변수 emit 은 검증 필요** (`gen2_match_cond` `:9539`, `gen2_match_stmt`). |
| **A5** regression test (interp + native 양쪽 PASS) | — | ⬜ **PENDING** — 본 patch 가 `self/test_enum_payload_full.hexa` 신설. |
| **B1** `self/ir/Operand` sum type 마이그레이션 | — | ⬜ NOT STARTED |
| **B2** `compiler/ir/*` sum type 마이그레이션 + `compiler/parse/ast.hexa` payload | — | ⬜ NOT STARTED. `compiler/parse/ast.hexa:7-10` 주석 "stage0 enum variants cannot carry payloads yet" 는 이제 STALE — A1-A3 land 후 갱신 필요. |

> ⚠️ Linux 빌드(`~/.hx/bin/hexa_real`, 4월 27) 는 `3c8be96c` **이전** — 거기선 `Shape::Circle(2)` 가 payload 를 `void` 로 떨어뜨림 (`hexa_real run self/test_enum_variant.hexa` → `void/void/0/assertion failed`). Mac `hexa.real` (5월 7) 또는 현재 소스 재빌드 필요. **본 patch 의 테스트는 현재 빌드에서만 검증됨.**

## 2. 남은 작업 (handoff — 라인 단위)

### A4-finish — match-side payload 추출 + binding 변수 emit

`self/native/hexa_cc.c` `gen2_match_cond(pat, scrutinee_var)` (~`:9539`, `:9540 gen2_match_expr`):
- construction 은 `[tag, payload]` array 를 emit 하므로, match arm 에서 `pat.kind=="EnumPath" && pat.left!=""` 일 때:
  1. tag 비교: `hexa_index_get(<scrutinee>, 0) == <Enum>_<Variant>` (또는 variant 번호)
  2. arm body 진입 직전, payload 캡처: `HexaVal <pat.left> = hexa_index_get(<scrutinee>, 1);` — `pat.left` 가 `r`/`side`/`val` 등 캡처 변수명
  3. body 안에서 `<pat.left>` 가 일반 local 처럼 보이게
- interp 경로 (`self/interpreter.hexa` 또는 `hexa_full.hexa` 의 match eval) 가 이미 `[tag,payload]` 를 동적 처리하는지 확인 — A3 typechecker 가 OK 통과시키므로 interp 에서 binding 이 안 되면 그쪽도 패치.
- diagnostics: payload 있는 variant 를 payload-less 패턴으로 match (`Shape::Circle ->`) 하거나 그 반대일 때 명확한 에러 (English, HX 코드).

### A5 — regression test

`self/test_enum_payload_full.hexa` (본 patch 동봉) — `check(name, actual, expected)` 패턴, `[PASS]/[FAIL]` + count. 커버:
1. int payload — construct + match + arithmetic on captured var (= 기존 `test_enum_variant.hexa` 확장)
2. string payload — `Result::Err("not found")` → match capture → string ops
3. struct-embed payload — `enum Shape2 { Rect(RectData) }` where `struct RectData { w:int, h:int }` → construct + match capture + field access (= RFC §3.1 의 핵심 패턴, A4 frontier)
4. nested match (payload variant inside payload variant)
5. payload-less variant (`Unit`) 와 혼재
6. exhaustiveness (모든 variant cover) — 빠뜨리면 typechecker 에러?
- 실행: `hexa run self/test_enum_payload_full.hexa` (interp) **및** `hexa build self/test_enum_payload_full.hexa -o build/... && build/...` (native). RFC §7-1 "interp vs native 어떤 케이스가 다른지" — 두 출력 byte-compare.
- `tool/_spec_runner_selftest_fixtures` 또는 `tool/raw_all.hexa` 의 selftest 매트릭스에 등록.

### B1 — `self/ir/Operand` sum type

`self/ir/instr.hexa:57` `Operand` struct + string `kind` discriminator → RFC §5 의:
```hexa
enum Operand {
    Value(ValueId), ImmI64(IntData), ImmF64(FloatData), Block(BlockId),
    Func(FuncId), String(StringRef), Phi(PhiData), Switch(SwitchCase),
    Cmp(CmpData), Param(ParamIndex)
}
```
각 payload 는 1-필드 struct (`struct IntData { v: i64 }` 등). `self/ir/instr.hexa` 의 Operand workaround 주석을 "다중 필드 부재" 만 가리키게 좁힘. 모든 Operand 생성/소비 지점 (`self/lower/*`, `self/codegen/*`) 업데이트 — 큰 작업, A4-finish + A5 PASS 후.

### B2 — `compiler/` 트리 반영

- `compiler/parse/ast.hexa` — `ExprKind.EnumPath` 의 payload 를 `Expr.children[]` 또는 새 필드로. `:7-10` STALE 주석 갱신. `ItemKind.Enum` 의 variant payload 타입을 `Item` 에 실어야.
- `compiler/parse/parser.hexa` — A1 동등 (construction `E::V(x)` 파싱).
- `compiler/check/{resolve,bind,types}.hexa` — A2/A3 동등.
- `compiler/lower/ast_to_hir.hexa` + `compiler/ir/{hir,mir,lir}.hexa` — RFC §5 마이그레이션 (`hir.hexa`/`mir.hexa`/`lir.hexa` 의 struct+string-kind → sum type).
- `compiler/codegen/{arm64_darwin,x86_64_linux}.hexa` — payload 캡처 emit.
- self/ ↔ compiler/ 매핑은 RFC §5 테이블 + 이 inbox 의 절차 §2(처리) 참조.

## 3. `.roadmap.codegen` 엔트리 초안 (paste-ready)

> `~/core/hexa-lang/.roadmap.codegen` 는 chflags-locked SSOT 일 수 있음 — 직접 안 씀. 스키마 `hexa-lang/roadmap/2`. unlock → append → lock.

```json
{"id": "CG-RFC020-A4-A5", "kind": "feature", "title": "RFC-020 A4 match-side payload 추출 + binding emit + A5 regression test", "rationale": "A1(parser construction 3c8be96c)/A2(payload-type 테이블)/A3(pattern binding) land 완료. A4 codegen 은 construction([tag,payload] array) 만 됨 — match arm 에서 payload 추출 + arm-scope binding 변수 emit 미검증. A5 회귀 테스트 부재 (test_enum_variant.hexa 는 int-payload 단일 케이스). wilson pi-port G1 load-bearing — ai 패키지 AssistantMessageEvent discriminated union 표현 의존.", "acceptance": "(a) gen2_match_cond/gen2_match_stmt (self/native/hexa_cc.c) — pat.kind==EnumPath && pat.left!='' 일 때 hexa_index_get(scrutinee,1) 을 pat.left 로 캡처 emit; interp 경로도 동일 binding; (b) payload-mismatch 패턴에 명확한 HX 에러 (English); (c) self/test_enum_payload_full.hexa 신설 — int/string/struct-embed payload + nested match + Unit 혼재, interp + native 양쪽 PASS + 두 출력 byte-eq; (d) test_enum_variant.hexa regression 0; (e) tool/raw_all.hexa selftest 매트릭스 등록.", "files_modified": ["self/native/hexa_cc.c", "self/interpreter.hexa", "self/type_checker.hexa"], "files_added": ["self/test_enum_payload_full.hexa"], "depends_on": ["RFC-018"], "cross_link": ["proposals/rfc_020_enum_payload_variants.md", "incoming/patches/rfc020-enum-payload-variants.md", "wilson/docs/hexa-lang-gap-audit.md#g1"], "status": "in_progress", "since": "2026-05-10"}
{"id": "CG-RFC020-B1-OPERAND", "kind": "refactor", "title": "RFC-020 B1 — self/ir/Operand string-kind discriminator → enum payload sum type", "rationale": "A4/A5 PASS 후. self/ir/instr.hexa:57 Operand struct + string kind → enum Operand { Value(ValueId), ImmI64(IntData), ... } (각 1-필드 struct payload). 가독성·타입안전성 ↑. self/lower/* + self/codegen/* 의 모든 Operand 생성/소비 지점 업데이트.", "acceptance": "(a) self/ir/instr.hexa Operand = sum type; (b) self/lower/{ast_to_hir 등가}.hexa + self/codegen/* 컴파일 + selftest PASS; (c) hexa_v2 self-host byte-identical re-build (RC4); (d) Operand workaround 주석 → '다중 필드 부재' 로 의미 좁힘.", "files_modified": ["self/ir/instr.hexa", "self/ir/types.hexa", "self/lower/*.hexa", "self/codegen/*.hexa"], "depends_on": ["CG-RFC020-A4-A5"], "cross_link": ["proposals/rfc_020_enum_payload_variants.md#5", "incoming/patches/rfc020-enum-payload-variants.md"], "status": "PROPOSED", "since": "2026-05-10"}
{"id": "CG-RFC020-B2-COMPILER-TREE", "kind": "feature", "title": "RFC-020 B2 — compiler/ 트리에 enum payload 반영 (parse/ast + check + lower + ir + codegen)", "rationale": "self/ 가 컴파일 버전(compiler/)으로 변신 중 — enum payload 가 self/ 에만 있으면 두 트리 분기. compiler/parse/ast.hexa:7-10 'stage0 enum variants cannot carry payloads yet' STALE 주석 갱신 포함. RFC-020 §5 매핑.", "acceptance": "(a) compiler/parse/{ast,parser}.hexa — EnumPath payload + construction 파싱; (b) compiler/check/{resolve,bind,types}.hexa — payload type 등록 + pattern binding; (c) compiler/lower/ast_to_hir.hexa + compiler/ir/{hir,mir,lir}.hexa — sum type 마이그레이션; (d) compiler/codegen/{arm64_darwin,x86_64_linux}.hexa — payload 캡처 emit; (e) compiler/parse/ast.hexa STALE 주석 갱신; (f) compiler/ test 매트릭스 PASS.", "files_modified": ["compiler/parse/ast.hexa", "compiler/parse/parser.hexa", "compiler/check/resolve.hexa", "compiler/check/bind.hexa", "compiler/check/types.hexa", "compiler/lower/ast_to_hir.hexa", "compiler/ir/hir.hexa", "compiler/ir/mir.hexa", "compiler/ir/lir.hexa", "compiler/codegen/arm64_darwin.hexa", "compiler/codegen/x86_64_linux.hexa"], "depends_on": ["CG-RFC020-A4-A5"], "cross_link": ["proposals/rfc_020_enum_payload_variants.md#5", "incoming/INBOX.md"], "status": "PROPOSED", "since": "2026-05-10"}
{"id": "CG-RFC020-C1-MULTIFIELD", "kind": "feature", "title": "RFC-020 C1 (옵션) — 다중 필드 variant A(int, string)", "rationale": "RFC §3.1 = 단일 필드 + struct 임베드 우선, 다중 필드 후순위. wilson 은 1-필드 struct payload 로 우회 가능 → P3. positional(Rust) vs labeled(Swift) vs tuple 디자인은 1차 정착 후 별도 RFC.", "acceptance": "다중 필드 variant 선언/construction/match destructure/codegen + test PASS", "files_modified": ["self/parser.hexa", "self/type_checker.hexa", "self/native/hexa_cc.c"], "files_added": ["self/test_enum_multifield.hexa"], "depends_on": ["CG-RFC020-B1-OPERAND", "CG-RFC020-B2-COMPILER-TREE"], "cross_link": ["proposals/rfc_020_enum_payload_variants.md#3.1"], "status": "PROPOSED", "since": "2026-05-10"}
```

## 4. 테스트

`self/test_enum_payload_full.hexa` — 본 patch 와 함께 추가됨. 15 케이스 (int payload / string payload / nested match / struct-embed payload §4 = A4 frontier).

- stale Linux 빌드 (`~/.hx/bin/hexa_real`, 4월 27, pre-`3c8be96c`) 실행 결과: **5/15 PASS** — payload 있는 모든 케이스가 `got: void` (construction 이 payload 를 떨굼). no-payload 케이스 (Unit, payload 안 쓰는 nested) 만 PASS. 즉 테스트는 well-formed, 갭을 정확히 드러냄.
- 현재 빌드 (Mac `hexa.real` 5월 7, 또는 재빌드 self/) 기대치: A1-A3 land 됐으므로 §1~3 PASS, §4 (struct-embed payload) 는 A4 codegen 이 struct payload 추출하면 PASS / 아니면 거기가 fix 지점. 목표 = 15/15 interp + native 양쪽 + byte-eq.

## 5. 처리 체크리스트

- [ ] A4-finish: `gen2_match_cond` payload 추출 + binding emit (self/)
- [ ] A4-finish: interp 경로 binding 일치 확인 + payload-mismatch 에러
- [x] A5: `self/test_enum_payload_full.hexa` 작성 (← 본 patch)
- [ ] A5: interp + native 양쪽 PASS + byte-eq, selftest 매트릭스 등록
- [ ] B1: `self/ir/Operand` sum type 마이그레이션
- [ ] B2: `compiler/` 트리 반영 + ast.hexa STALE 주석 갱신
- [ ] C1 (옵션): 다중 필드 variant
- [ ] `.roadmap.codegen` 엔트리 4개 배치 (unlock → append → lock)
- [ ] `PATCHES.yaml` status `in_progress` → `synced` (A5 양쪽 PASS 후) → `archived` (B 정착 후)
