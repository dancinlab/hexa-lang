# self/stdlib/fs.hexa `== nil` parser reject — main parser와 drift (2026-05-24)

## 한 줄 요약
`self/stdlib/fs.hexa` 의 `fs_stat_size`/`fs_stat_mtime_ns` + selftest 5곳이 `if st == nil`
패턴을 쓰는데, main 의 parser 가 cycle 7-11 batch 중 `nil` 값-비교를 거부하도록 강화됨
(`'nil' is not a value in hexa — use 'None' (Option<T>) or omit the binding`).
결과: `tool/verify_cli.hexa` 등 verify/atlas 도구가 flatten 시 stdlib/fs.hexa 를 끌어와
**parse 단계에서 거부됨** → verify/atlas verbs 비정상.

## 재현
```
cd ~/core/hexa-lang
export HEXA_LANG=$PWD HEXA_MAC_BUILD_OK=1 HEXA_MODULE_LOADER=$PWD/build/hexa_module_loader LOCAL_BUILD=1
./hexa verify --expr welch_t_crit 1 12.706
# Parse error at <line>: 'nil' is not a value in hexa — use 'None' (Option<T>) or omit the binding
```

## 위치 (self/stdlib/fs.hexa)
- L243: `if st == nil { return -1 }`         (fs_stat_size)
- L249: `if st == nil { return -1 }`         (fs_stat_mtime_ns)
- L486: `if st == nil {`                     (selftest 26)
- L515: `if dst == nil {`                    (selftest 31)
- L529: `if mst != nil {`                    (selftest 33)

## 후보 fix (워크어라운드 검증됨)
패턴: `if st == nil { ... }` → `if !st { ... }` (truthy 검사로 강등).
fs_stat 은 missing 시 `hexa_void()` 반환 → `!void` 가 true 임을 확인.
`if mst != nil` → `if mst`.

이 워크어라운드로 verify 게이트 4건 모두 발급:
- `welch_t_crit(1.0)=12.706` → 🟢 SUPPORTED-NUMERICAL
- `wilson_hilferty_p(0.0,10.0)=1.0` → 🟢 SUPPORTED-NUMERICAL
- `ssh_winding(1,2)=1` → 🔵 SUPPORTED-FORMAL
- `tknn_chern(2,5,1)=3` → 🔵 SUPPORTED-FORMAL

## 영향 범위
verify/atlas CLI 외에도 `self/stdlib/fs.hexa` 를 use 하는 모든 도구.
cycle 7-11 batch 의 parser 강화 (PR #585/#594/#595 그룹) 와 stdlib drift 가 원인.

## 조치 제안
- `if x == nil` 패턴을 stdlib 전반에 grep 후 `if !x` (또는 `Option<T>` 명시) 로 마이그레이션.
- parser 의 `== nil` 거부에 대해 호환 path 검토 (deprecation warning 으로 강등).
- 이 finding 은 atlas/rfc047-046-atoms-register-2026-05-24 PR 작업 중 발견됨 (verify gate
  실행이 막혀 surgical fs.hexa 수정 → 게이트 verdict 발급 → 원본 복구).
