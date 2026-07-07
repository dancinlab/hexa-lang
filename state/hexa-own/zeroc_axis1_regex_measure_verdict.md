# zeroc #29 axis-① round-1 + regex corpus — aiden 실측 verdict (2026-07-07)

## axis-① round-1 (HEXA_BUILD_NATIVE leg-B) — arm WIRED, leg-B ld link BUG found
- `hexa run self/main.hexa build /tmp/s.hexa` (fresh arm source) → `[build-native]` trace 등장 = **arm 발화 확인**(배선 OK).
- 그러나 `[build-native] ld link failed → C fallback`. Root cause = `/usr/bin/ld: cannot find entry symbol _start`.
- Trace: leg-B가 own-start crt-drop ld 명령(no crt1.o) 사용 — `ld --dynamic-linker … bnobj.o runtime.a --start-group -lc -lpthread -lm --end-group -L/usr/lib/x86_64-linux-gnu -o …`.
- 원인: arm의 `_bnzc = env_var("HEXA_ZEROC_OWN_START") != "0"`(default-ON)이 **resolved runtime.a가 실제로 own `_start`를 carry하는지 검증 없이** crt-drop. aiden의 prebuilt runtime.a(`~/.hx/bin/build/runtime.a`·설치 릴리스)는 own-start 없음 → ld가 _start 못 찾음.
- FIX (이 라운드): #4638 consumer-link 패턴 미러 — nm-probe로 runtime.a에 ` T _start` 있을 때만 crt-drop, 없으면 crt-keep. cmd_run leg-B도 동일 패턴 적용 검토.
- 부수: outer `hexa run self/main.hexa` native-emit는 HX2006(cannot assign to immutable `exe`)로 clang fallback — main.hexa native-emit borrowck 엄격성(별개 finding·측정 무관).

## regex corpus — harness WORKS, ON build native-regex 미engage (stale-hexa)
- step-0 probe GREEN: glibc backref=1(D3 diverges expected), interval_alt_longest=1 등.
- `PASS: oracle golden == OFF runtime ledger (verbatim-port fidelity)` — oracle이 OFF 런타임의 정확한 verbatim 포팅 확증(핵심 검증).
- C-class parity-clean(non-D FAIL 없음).
- 그러나 `WARN: ON build did not report native regex seed assembly` + gate 3c FAIL(D1/D2/D3 never diverged) — 설치 hexa v0.577.0의 ON 빌드가 native regex seed 미조립 → ON==OFF → D-divergence 없음. **parity 결함 아님·native regex 미engage(stale-hexa)**.
- 재측정 필요: native regex seed를 조립하는 current-main hexa(또는 seed .o present + 올바른 resolver).
