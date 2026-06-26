# 컴파일속도 R7 — gcc-반복컴파일 축 (ccache / pre-converged seed) — INTERIM (측정 infra-blocked)

R6(bootstrap gcc-O1·#4003 머지) 후속. measure-first 원칙으로 R6후 병목 재측정 →
gcc-compile이 여러번 도는 축을 직격하려 했으나 **PHASE-1 측정이 pool 인프라로 차단**.
캠페인 사슬: R1-3 bsearch~3.36× · R4 falsify(병목=seed-converge+gcc-O2 amalgam) ·
R5 double-neg(transpile병렬=perf-dead) · R6 gcc-O1 −11.8% 머지.

## 확정 발견 (aiden 직접 probe · PHASE-1 전)

- **naive ccache = NO-GO (falsified)**: stage 스크립트가 1.8MB `hexa_cc.c` amalgam을
  **compile+link 한 스텝**(`$CC $CFLAGS hexa_cc.c runtime.a -o hexat`, `-c` 없음)으로 빌드.
  `ccache gcc -O2 t.c -o t`(combined) 직접 probe = **2/2 Uncacheable · 0% cacheable**.
  → 태스크가 처음 가정한 `CC="ccache gcc"` wiring은 **적중 불가**.

- **진짜 레버 = split compile(`-c`, 캐시가능)을 link에서 분리** · opt-in `HEXA_CCACHE=1`
  default-OFF. **byteeq-safe by construction**(R6와 동일 논리): ccache same-input⇒same-`.o`
  보장 + hexat은 transpiler라 그 `.o`가 캐시되든 말든 emit하는 C는 `.hexa` source의 함수.

## 컴파일 site 지도 (static read · $CC 경유)

| 파일:라인 | 대상 | 종류 | ccache 적용 |
|---|---|---|---|
| stage_prebuild_hexat:118 | build/hexat | amalgam(1.8MB) | split-cacheable |
| stage_prebuild_hexat:169 | build/hexat (converge loop) | amalgam | split-cacheable |
| stage_build_hexa:168 | build/hexa_v2 (else-branch) | amalgam | split-cacheable |
| stage_build_hexa:176 | hexa_module_loader | emitted-C | split-cacheable(작음) |
| stage_build_hexa:190 | 최종 ./hexa (-O2) | emitted-C | split-cacheable(작음) |
| stage_build_hexa:161 | hexa_v2 (object link) | `.c` 없음 | SKIP |

inline split 패턴(per-site·flags/-I 다양):
```
if [ "${HEXA_CCACHE:-0}" = "1" ] && command -v ccache >/dev/null; then
  ccache $CC <CFLAGS> <-I...> -c "<src.c>" -o "<out>.ccobj.o"
  $CC <CFLAGS> "<out>.ccobj.o" "<linkinputs>" -o "<out>" $LIBS; rm -f "<out>.ccobj.o"
else <원본 combined 라인 verbatim>; fi
```

## GO/NO-GO를 가르는 PHASE-1 데이터 (미측정 — 차단됨)

- **(a) 같은-sha amalgam 컴파일 횟수 N**: committed seed가 fixpoint(0 converge mutation)면
  cold 빌드 1회 안에서 hexat + hexa_v2가 **동일 `hexa_cc.c`** 컴파일 → 2번째가 ccache HIT(split).
  warm rebuild: amalgam+emitted **전부** HIT. ⇒ N≥2 & 동일sha일 때만 in-build 이득 존재.
- **(b) distinct amalgam sha 수**: 1 ⇒ 최대 same-build 재사용 · >1 ⇒ warm-rebuild 재사용만.
- **(c) gcc 누적 %**: 천장 크기(R4=~70%, R6후 갱신 필요).

## fallback 레버 B (pre-converged seed) = 사실상 무효

R4 rank-5(HEXA_SEED_CONVERGE i=0 break)는 **seed가 이미 fixpoint면 converge regen/cc가
이미 no-op** ⇒ free win 없음(비용은 single amalgam compile = 레버 A 영역). seed가 mutate(>0)면
converge skip이 emit 변경 ⇒ byteeq-unsafe ⇒ NO-GO. **순: 레버 B는 거의 무수확, 레버 A가 live.**

## 게이트 (양 레버 공통)
emit-sha(stage1/main.c + module_loader.c) **OFF==ON [필수]** + wall/CPU ON<OFF + smoke GREEN.
emit-sha 다르면 SHIP-BLOCK.

## 🧱 현 상태 = 측정 infra-wall (science 천장 아님)
summer가 **56-112초 재부팅 루프**(문서상 ~30min보다 훨씬 심함)에 경쟁 pool `release_build`로
load>2 유지 → idle-gate가 재부팅 전 안 풀림. aiden 간헐 다운. ~10분 프로파일 빌드가 thrashing
호스트서 완주 불가. **레버 A 설계 완료·구현 보류(측정이 정당화한 뒤)** — pool 안정 시 PHASE-1
(N·sha·% 측정) → 정당화되면 split-ccache 구현+측정+pr-cycle, 아니면 정직 종결. self-harvest
$HOME/r7_RESULT.txt(reboot-proof)로 재시도 중. 빌드=summer/aiden·mini=git/gh·akida금지.
