# HEXA-SELFHOST+ — log

Append-only history sister of `HEXA-SELFHOST+.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.


## 2026-05-31 메타도메인 등록 (init + goal + 롤업 마일스톤)

세 self-host 도메인(BUILDFLOOR 0% · RUNTIME 80% · CC-NATIVE 12%)을 한 북극성
("hexa 가 C 없이 자기를 빌드")으로 묶어 메타도메인 HEXA-SELFHOST+ 등록.
의존 흐름: BUILDFLOOR(레시피) → RUNTIME(런타임) → CC-NATIVE(컴파일러).
메타 규약: 실제 flip 은 자식 SSOT 에서, 이 파일은 cross-domain 조율/차단/의존만.
4 milestone: 의존순서 박제 · 공통-벽 카탈로그 · 다음-칸 셀렉터 · 졸업 게이트.
HEXA-CC-ZERO(✅100% 커밋.c=0)의 자매 = 빌드산출.c=0 한 단계 더.

## 2026-05-31 CC-NATIVE 핸드오프 흡수 + 공통-벽 카탈로그 갱신

타세션이 CC-NATIVE 도메인을 중복 진행 → 사용자 중단 → 이 세션(메타)으로 일원화.
drafts/SESSION-HANDOFF-hexa-cc-native.md 참고. 타세션 결과(#2270 N6 phase-2)는
이미 main 박제: native print/stdout = IO-floor codegen 벽 honest-STOP.

- 공통-벽 카탈로그에 (4) native backend IO-floor 추가 — (1) codegen type-erasure 와
  같은 뿌리(codegen emit 단). RUNTIME 순수-fn · GPU 1b-cons · CC-NATIVE native-print
  = 동일 codegen emit 벽 3-자식 동시 차단. 레버 = emit 단 1회 개방(sign+in-process 검증).
- 다음-칸 셀렉터: 회전 이력 박제(3 codegen honest-STOP) → 현재 칸 BUILDFLOOR M1
  (.sh fix, codegen 벽 無, agent 진행 중)이 유일 grounded.
- 메타 milestone 2개([~]): 공통-벽 카탈로그 · 다음-칸 셀렉터 진전.

## 2026-05-31 공통-벽 카탈로그 완성 — N5 type-checker + 재빌드 게이트 흡수 (#2271 누락분)

#2271 이 다음-칸 셀렉터만 갱신하고 공통-벽 카탈로그 Edit 가 string-mismatch 로 누락됨.
이 커밋이 마저 채움 — CC-NATIVE 핸드오프(drafts/SESSION-HANDOFF-hexa-cc-native.md) 흡수 완료.

- 카탈로그 (4) native backend IO-floor / type-checker: native codegen print/stdout 미지원
  + native type-checker 150 FATAL(HX2001/HX3001/HX2003/HX0011 = HexaVal carrier 갭, types.hexa)
  = CC-NATIVE N5 frontier(#2270·STEP0 BLOCKED).
- 카탈로그 (5) aprime_cc 재빌드 = pool/darwin sign 게이트: linux 빌드 실패(build_aprime.sh
  -arch arm64 하드코딩 + hxlcl_* darwin-shim 미배선), darwin 은 사용자 sign 게이트.
- 수렴: (1)·(4) 같은 뿌리(codegen emit 단) → 3-자식 동시 차단. 레버 = emit 단 1회 개방.
- 카탈로그 [~] 진전. CC-NATIVE 타세션 중복 진행 → 이 메타로 일원화 완료.

## 2026-05-31 BUILDFLOOR M1 흡수 + 공통-벽 카탈로그 (4)(5) 완성

BUILDFLOOR M1 agent(af16f2dd)는 push 가 reaper 로 전부 취소돼 미착지(PR 0). 그러나
검증된 발견을 이 커밋이 흡수: build_hexa_cloud.sh = 트리 부재, 이미 hexa-native
tool/build_hexa_cloud.hexa(PR #2102)로 대체 + 3 fix(build/hexa_v2·build/self/runtime.c·
-I build/self) 이미 origin/main 에 존재(L31/34/35 검증) = "3경로 수정" 코드 추가 불요.

- M1 [ ]→[~]: 코드 deliverable 검증됨 · build/smoke 는 transpiler 재빌드 sign 게이트로
  BLOCKED(honest-STOP, @L4 genuine wall). hexa.real md5 PRE==POST 무손상.
- 공통-벽 카탈로그 [~]: (4) native IO-floor/type-checker (이전 #2271/#2272 string-mismatch
  로 누락된 것 재착지) + (5) aprime_cc/transpiler 재빌드 = sign/pool 게이트 추가.
  M1·N5 둘 다 (5) 재빌드 게이트가 공통 블로커임이 드러남.
- 수렴 확정: 3 codegen honest-STOP(RUNTIME/GPU/CC-NATIVE) + 1 rebuild-gate(BUILDFLOOR)
  = 메타 4-자식이 2개 공통 벽((1)/(4) emit단 · (5) 재빌드 게이트)으로 수렴.
