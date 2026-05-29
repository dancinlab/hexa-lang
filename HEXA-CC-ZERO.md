@title: 🌱 HEXA-CC-ZERO — "마지막 C 씨앗 제거"
@goal: self/native/hexa_cc.c 를 repo에서 완전히 제거한다 — `hexa cc --regen` 이 4개 .hexa SSOT 모듈에서 트랜스파일러를 warm-rebuild 하게 하여, 손으로 유지하던 마지막 C 시드를 없애고 "0 .c" self-host에 도달한다.

# HEXA-CC-ZERO — current state

손-유지 C는 사실상 `self/native/hexa_cc.c`(트랜스파일러 씨앗) 하나만 남았다. 이걸 없애면 컴파일러가 자기 자신을 자기 언어로만 다시 만든다.

## progress

- [ ] P1 — `hexa cc --regen` fixpoint byte-eq (재생성 트랜스파일러 == 기존 트랜스파일러)
- [ ] P2 — cross-host kill-storm-free (Mac arm64 + ubu x86_64 둘 다 warm-rebuild PASS)
- [ ] P3 — stage-(-1) seed 전략 (hexa_cc.c 없이 cold bootstrap 경로 확정)
- [ ] P5 — `--prefer-regen` opt-in flag 활성 (build_hexa_cli.hexa step 0)
- [ ] P6 — `self/native/hexa_cc.c` git rm + CI/fresh-clone green
