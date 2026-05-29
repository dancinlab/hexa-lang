# 🍞 부트스트랩 — hexa-native self-host

hexa-lang 은 `.hexa` 소스만으로 빌드되는 native self-hosted 컴파일러다.

부트스트랩 = edge tarball 의 prebuilt `build/runtime.a` + `build/hexat` 를
`tool/release_build` → `tool/release_package` 단일 진입점이 링크한다.
release 와 nobaseline-gate(faithful) 가 동일 스크립트를 호출 → gate ≡ release.
3-플랫폼(darwin-arm64 · linux-x86_64 · linux-arm64) release green.
