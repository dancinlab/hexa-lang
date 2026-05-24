---
slug: anima-discovered-2gaps-2026-05-25
status: open
---

# hexa-lang 2-gap — linux `hexa` wrapper broken + import-time `main()` auto-invoke

**Reporter**: anima (`dancinlab/anima` · PURE Phase D fire 도메인)
**Discovered through**: PR #753 (codegen `return void` fix) cross-machine 전파 audit + B14 fire-sanity-hook 작성 중 발견.
**Severity**: G1 high (fleet 운용 차단) · G2 medium (코드 재사용 차단)

## G1 — linux `hexa` wrapper 깨짐 (ubu-1 / ubu-2)

PR #753 fix 를 pool 머신에 전파(`hexa cc` 재빌드)하려는데 두 linux 머신 모두 `hexa` **wrapper** 가 동작 안 함:

| host | 증상 |
|---|---|
| ubu-1 | `hexa.real` 심링크가 없는 파일을 가리킴 (wrapper → missing target) |
| ubu-2 | `hexa` 가 PATH 에 없음 |

직접 `./self/native/hexa_v2` 실행은 정상(그래서 #753 전파는 fallback `clang` 재빌드로 성공)이나, `hexa cc` / `hexa run` / `hexa parse` 등 **모든 wrapper 경유 명령이 linux 에서 silent-fail**. 결과적으로 pool(`pool on ubu-1 …`)을 통한 hexa 작업이 전부 막힘.

**추가 정황** (ubu-2): `runtime.o` 부재 → `runtime.c` 직접 재컴파일 시 clang strict-C99 에서 `ptsname_r`/`unshare`/`setns` implicit-declaration 에러 → `-D_GNU_SOURCE` 필요. 즉 linux 빌드 recipe 가 `-D_GNU_SOURCE` 를 빠뜨리고 있음.

**제안**:
- `hexa` wrapper install 을 linux 에서 재현·복구 (심링크 타겟 검증 + PATH 등록). 설치 스크립트가 `hexa.real` 타겟을 보장하도록.
- linux clang build recipe 에 `-D_GNU_SOURCE` 추가 (runtime.c 의 pty/namespace 호출).

## G2 — import 시 `main()` auto-invoke 가 모듈 재사용 차단

`HEXAD/PURE/eval/corpus_quality_probe.hexa` 의 M3 TTR 계산 로직을 B14 fire-sanity-hook 에서 재사용하려 `import` 했더니, import 만 해도 probe 의 `fn main()` 이 auto-fire 하여 **selftest 6줄을 매번 출력**. 결과적으로 라이브러리로 못 쓰고 TTR 로직을 hook 파일에 **inline 복제**해야 했음 (코드 중복).

이건 알려진 hexa 동작(`fn main()` auto-invoke at run/import)이지만, **라이브러리 모듈 재사용을 구조적으로 막는다**. 동일 패턴이 anima 측 probe/eval 모듈 다수에 존재.

**제안** (택1):
- `import` 시에는 top-level `main()` auto-fire 를 **억제**하고, 직접 `hexa run` 으로 실행할 때만 fire (Python `if __name__=="__main__"` 등가물).
- 또는 import-as-library 를 위한 명시적 가드 키워드 (e.g. `@no_auto_main` 또는 `fn main()` 을 `fn _selftest()` 로 분리하는 컨벤션을 문서화).

**impact**: 가드가 생기면 probe/eval 의 핵심 로직(TTR·register·multilingual)을 단일 소스로 공유 가능 → anima PURE eval 스택의 중복 제거.
