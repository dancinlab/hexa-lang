# Step0 defer 특성화 실측 verdict (aiden · linux-x86_64 · hexa v0.587.1 release_build)

## 판정 (캡처 완료 · state/hexa-own/step0_expected_gen2.txt = 실측 출력으로 동결)

| 판정 | 결과 | 의미 |
|---|---|---|
| FRESHRUN==GEN2 | ✅ PASS | run-verb vs build-verb 분기 없음 (동일 드라이버) |
| SHIPRUN==GEN2 | ✅ PASS | shipping v0.577.0도 (링크 env 정정 후) 동일 의미론 |
| GEN2==ORACLE | ❌ → **예측 반증 1건** | C4에서 소스-추적 예측이 실측으로 깨짐 |

## 실측 확증된 gen2 defer 의미론

- **C1 LIFO** ✅ 3-defer 역순 발화. **C2 reached-flag** ✅ early-return 앞 defer 미발화·도달분만 발화.
- **C3 loop at-most-once + drain-time 값** ✅ 3회 반복 defer가 정확히 1회·`i=3`(drain-time)으로 발화.
- **C5 return 후 drain** ✅. **C6 throw는 drain 우회** ✅ (longjmp가 __fn_exit 안 탐).
- **★C4 반증(진짜 발견)**: 루프 안에서 defer가 i=0,1에 도달(flag=1)한 뒤 i=2에서 return하면 — **예측("단일 __fn_exit가 flag 검사로 발화")과 달리 실측은 미발화**. `C4: loop defer fired` 줄이 실제 출력에 없음.

## native vs gen2 C4 대조 — 실측 확정 (aiden · 수동 링크 우회)

`HEXA_BACKEND=native`(aprime_cc, #4446 포함 main) 동일 프로그램 실행 결과: **유일 diff = native가 `C4: loop defer fired, i=2`를 출력**(그 외 전 줄 동일). 즉 native는 규범 의미론(도달 flag=1 → 단일 exit drain·drain-time 값)대로 발화, gen2는 동일 설계 의도(자체 __fn_exit+flag)에도 불구하고 미발화.

**처분 = (b) gen2 C4 미발화를 gen2 결함으로 분류** — 근거: ① 규범 SSOT(M1 merged·defer_test 11게이트)가 reached-flag 의미론을 명시 ② native가 그 스펙과 일치 ③ **기전 실측 확정(emitted C=aiden step0_gen2b.c:169)**: 루프 안(while→if) `return`이 `__ret_val=…; goto __fn_exit` 재라우팅 없이 날 C `return __hexa_fn_arena_return(...)`으로 방출 — drain 블록 우회. 같은 파일 case5의 fn-바디 return은 정상 재라우팅 → **gen2 ReturnStmt defer-reroute가 중첩-블라인드**(관측되려면 중첩 return 앞서 flag=1이어야 해 C4에서만 노출·C2는 flag=0이라 우연히 무해). fix 실행: 러닝 카운터 게이트(_gen2_defer_flag_count)를 pre-scan fn-총량(_gen2_defer_fn_total)으로 교체(5개 사이트·무-defer fn=byte-identical)+defer_test C4 게이트+expected 파일에 C4 발화 줄 반영 — 이 PR로 양 백엔드 C4 일치.

## 부수 결함 3종 (실측 중 노출 · 각각 후속감)

1. **native 파서 bare-return 삼킴**: `return` 다음 줄 ident-선두 문장을 return 값으로 오파싱(HX2001 `undefined name 'defer'`) — gen2는 정상 파싱. 두 프론트엔드 divergence·킷은 if-감싼 return으로 우회.
2. **hexad 데몬 교착**: `HEXA_BACKEND=native ./hexa build` 내부 native_build smoke가 shipping hexad를 경유하다 무한 대기 → 같은 워크트리 재시도가 전부 락 파일럿에 적체(0% CPU 61/35/17분). 우회=완성된 .s를 `gcc <asm> runtime.a -lm -ldl -lpthread`로 수동 링크. 근본수정 후보=데몬 timeout/lock 진단.
3. **운영 함정**: `pkill -f <패턴>`이 패턴 문자열을 담은 자기 ssh를 자기-매칭(2회 자폭) — 원격 kill은 pid 직격 또는 `[b]racket` 패턴.

## 부수 발견 (링크 DX 결함 · 기지 패턴 확장)

`hexa build`의 [2/2] clang 링크가 ① `-lm` 미포함(log2/fma/sin/cos undefined) ② 로그인 env의 stale `HEXA_PREBUILT_RUNTIME`(~/core 타 체크아웃 runtime.a)을 조용히 채택 — pool cuda+ssl 링크벽(memory)과 동족. 우회=`LIBS="-lm -ldl"`+`HEXA_PREBUILT_RUNTIME=<fresh worktree>/build/runtime.a` 명시. 근본 수정 후보=hexa build가 -lm을 기본 포함(수학 심볼은 runtime.a 상수 의존)·PREBUILT 경로-불일치 경고.

재현: state/hexa-own/step0_pool_commands.md + LIBS/HEXA_PREBUILT_RUNTIME 오버라이드(v4). 산출물: /tmp/step0_{run,gen2,freshrun,native}.out (aiden).

## fix 최종 실측 (aiden · hexat 재빌드 · 캐시 퍼지 · PR #4467)

`GEN2==EXPECTED-POSTFIX` ✅ · `GEN2==NATIVE` ✅ · defer_test **14게이트 ALL PASS** ✅(신규 C4 게이트 `-> 2;` 포함). 검증 중 노출된 2차 결함까지 동반 수정: `_gen2_count_defers`가 ExprStmt-래핑 if-expr 바디를 미하강 → 선언 언더카운트(`__defer_1` undeclared C 에러·main에도 기존재). 부수 규명: defer_test는 `tool/stdlib_selftest_aggregate.hexa`(--ci-gate)가 수집하지만 이 aggregate 자체가 "CI gate (future)" — **PR 게이트 미배선**이라 기존 결함이 CI에서 안 들킨 것(후속=aggregate --strict의 PR 게이트 승격 검토). 검증 함정 재확인: stale-hexat(빌드 후 hexat 미갱신)이 1차 검증 위양성 원인 — hexat 삭제 후 release_build로 강제 재생.
