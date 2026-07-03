# 컴파일속도 R6 — bootstrap gcc -O1 verdict: **GO** (byteeq-safe·measured 11.8% faster)

branch `perf/bootstrap-gcc-o1` (c7638e02) · summer 격리 `/tmp/r6_work_*` 클론 · self-harvest 스크립트 (verdict → `~/r6_RESULT.txt` reboot-proof + `/tmp/r6_RESULT.txt`). gen3≡gen4 컴파일러 byteeq와 무관한 **빌드-오케스트레이션 -O 레벨** 변경.

## 배경 (R4 → R5 → R6)
- R4: bsearch(#3952/#3956)가 Stage-1 transpiler를 55%→3.8%로 붕괴시킨 뒤, 새 #1 빌드비용 = transpiler C(`hexa_cc.c` 1.85MB · `module_loader.c`)의 **gcc -O2 컴파일**(~70% of build). seed-converge 76s도 각 pass의 gcc 컴파일이 지배.
- R5(transpile 4모듈 병렬화): perf-dead ~0% — 진짜 비용은 transpile이 아니라 그걸 컴파일하는 gcc. **진짜 레버 = gcc 컴파일 직격**으로 재확인.
- R6: 중간 부트스트랩 transpiler 바이너리(`build/hexat`·`build/hexa_v2`·`build/hexa_module_loader`)만 **-O1**, 출하 `./hexa`+`runtime.a`는 **-O2 유지**.

## 구현 (tool/ 스크립트만)
opt-in `HEXA_BOOTSTRAP_O1=1` (default-OFF). `tool/stage_build_hexa` + `tool/stage_prebuild_hexat`에 `CFLAGS_BOOTSTRAP`(opt-in 시 `-O2`→`-O1`, 그 외 byte-for-byte 기존 경로) 도입:
- 적용(중간·-O1): hexat 컴파일(prebuild ×2) · hexa_v2 컴파일·native-seed link · module_loader 컴파일.
- 유지(-O2): 최종 `$OUT_HEXA`(stage_build_hexa 마지막 줄 `$CFLAGS`) · `runtime.a`(stage_resolve_runtime_a 상류).
polarity: 플래그가 켜는 것 = 실험적 fast-bootstrap 제약(opt-in) · UNSET = 역사적 -O2-everywhere 경로 비트동일.

## 측정 (summer linux-x86_64 gcc-13 · taskset 0-5 · N=2/config · whole-build cold `rm -rf build`)
**가설 검증 핵심 = emit C가 transpiler 바이너리의 -O 레벨과 무관하게 결정적인가 → YES.**

| 항목 | OFF (-O2 all) | ON (HEXA_BOOTSTRAP_O1=1) | 판정 |
|---|---|---|---|
| **emit `build/stage1/main.c` sha256** | `1093c20a…d4610` | `1093c20a…d4610` | **IDENTICAL ✅ (게이트)** |
| **emit `build/stage1/module_loader.c` sha256** | `776505c0…b20d0` | `776505c0…b20d0` | **IDENTICAL ✅ (게이트)** |
| 출하 `./hexa` sha256 | `5fd6c7ce…e918a` | `5fd6c7ce…e918a` | IDENTICAL (출하물 불변 보너스) |
| `runtime.a` sha256 | `c4339482…1a338` | `c4339482…1a338` | IDENTICAL (둘 다 -O2) |
| `hexat`==`hexa_v2` 바이너리 | `807ccf17…` | `5299e9d2…` | DIFFER (기대됨 · -O1 vs -O2 중간물) |
| whole-build wall (cold,warm) | 212s, 76s → med 144s | 193s, 62s → med 127s | **−11.8%** |
| whole-build CPU User+Sys | 211s, 77s → med 144s | 193s, 61s → med 127s | **−11.8%** |
| smoke `--version`/hello/exit42 | hexa 0.1.0-dispatch / hello / rc=42 | 동일 GREEN | **GREEN ✅** |

**노이즈 정직 노트**: wall은 bimodal(cold ~210s vs warm page-cache ~62-76s). 그러나 ON이 **두 캐시 레짐 모두에서** 더 빠르다 — cold 212→193(−9%), warm 76→62(−18%) — 방향 일관. CPU(User+Sys)는 동시성/캐시-immune 신호로 채택했고 단일코어 빌드라 wall과 근사일치(−11.8%). R6-run1은 동시 CI `build_aprime` 빌드가 끼어들어 ON wall을 오염시켰고(load 1.89) summer가 ~30분마다 재부팅됨 → run2는 broad idle-gate(타빌드 0 + load<1.5 2폴 안정)로 **단독 실행** 후 측정.

## 판정: **GO** — emit-sha OFF==ON(byteeq-safe) ✅ · smoke GREEN ✅ · ON < OFF(−11.8% wall/CPU) ✅
- 머지: default-OFF(release-safe) opt-in. 출하 `./hexa`/`runtime.a`는 byte-identical(출하 무영향).
- **default-ON flip = follow-up** — 3타깃(x86_64-linux·arm64-linux·darwin-arm64) byteeq CI에서 emit-sha OFF==ON 전수 확인 후 별도 PR(릴리스 무결성 > self-host 진척). 특히 emit이 -O 레벨 독립임을 x86_64 1타깃 외 2타깃에서도 재확인 필요(현 측정 = x86_64 단일).
- next round 후보(honest): R6-r2 = ON을 default-ON으로 올리는 3타깃 byteeq 게이트 PR. / R5-r2 = deterministic `ar rcD`+SOURCE_DATE_EPOCH로 `runtime.a`/바이너리 재현성(현재 emit만 결정적, .a는 ar 비결정 가능 — 이번엔 우연히 동일).
