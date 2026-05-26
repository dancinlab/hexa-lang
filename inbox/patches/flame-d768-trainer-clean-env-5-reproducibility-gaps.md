# flame d768 ag_tape trainer — 5 reproducibility gaps surfaced by anima fire #5~14

date: 2026-05-26
severity: HIGH (전부 #1262 / #1261 / #1242 의 후속 영역 — 깨끗한 env 에서 V=151643 trainer 를 빌드/실행하려는 누구나 막힘)
source: anima CORE/DECODER — hexa-native real-BPE(V=151643) GPU 검증, 14 fire(~$6.5, orphan 0)
related: PR #1255 (large-vocab host-loop GPU-port gap, 본 patch 의 상위 컨텍스트) · #1261 (linear bwd CUDA) · #1262 (lm-head/AdamW/gn2 GPU)

## 맥락

#1261/#1262 머지 후 anima 가 V=151643 GPU step 완주 검증 시도. 5 fire 동안 *빌드/실행 실패*, 그 사이 다섯 가지 reproducibility 문제 surface — 모두 fix 자체 아닌 **clean-env 빌드/실행 게이트**. 14 fire 끝에 substrate path 자체는 검증됨 (call 1 P4 backward done — `ag_backward_reg`=863s 가 step wall 의 100%, 별건 #1255 코멘트로 file).

본 patch = 그 5개 reproducibility 게이트의 **정밀 위치 + fix recipe**.

## §1 — 커밋된 `self/native/hexa_cc.c` ↔ `self/codegen.hexa` desync (#1187 farr32 매핑 누락)

- `origin/main:self/codegen.hexa` 는 #1187 farr32 직접호출 매핑 **보유** (line 6637+ `if name == "farr32_zeros" { return "hexa_farr32_zeros(" + a0 + ")" }` 등).
- 그러나 `origin/main:self/native/hexa_cc.c` (커밋된 부트스트랩 트랜스파일러 C) 는 `hexa_farr32_zeros` **0 hits** = regen 누락된 stale 상태.
- ∴ clean `hexa cc` (non-regen, 커밋된 hexa_cc.c 컴파일) → farr32 carrier-form (`hexa_call1(farr32_zeros, …)`) 방출. main `runtime.h` 는 직접호출형(`hexa_farr32_zeros`)만 노출(`extern HexaVal farr32_zeros` 0) → trainer.c `error: use of undeclared identifier 'farr32_zeros'`.
- 회피: `hexa cc --regen` (codegen.hexa → hexa_cc.c.new 재생성, hexa_farr32_zeros 1). 그 경우엔 §2/§3 의존.

**fix**: regen-on-merge 또는 CI 게이트 — codegen.hexa 의 farr32-mapping count 와 hexa_cc.c 의 hexa_farr32 count 일관성 체크 (한 줄 grep diff). 게이트 실패 시 PR 차단.

## §2 — macOS `self/runtime.o` 가 `-D_DARWIN_C_SOURCE` 필요 (`-D_GNU_SOURCE` 는 잘못된 추측)

`hexa cc --regen` link step 이 `self/runtime.o` 부재 시 호출자가 빌드해야 함. clang `-O2 -D_GNU_SOURCE -c self/runtime.c` (Linux 관습) 시도 → 다섯 에러:

```
runtime.c:735:38: error: use of undeclared identifier 'MAP_ANON'
runtime_core.c:450:30: error: no member named 'ru_maxrss' in 'struct rusage'
runtime_core.c:1673:37: error: no member named 'ru_maxrss' in 'struct rusage'
runtime.c:10836:9: error: call to undeclared function 'mkdtemp'
runtime.c:10923:9: error: use of undeclared identifier 'fd_set'
```

모두 `_DARWIN_C_SOURCE` 게이트. `-D_GNU_SOURCE -D_XOPEN_SOURCE=600` (Linux 관습) 은 macOS 의 Darwin 확장을 *숨김*.

**fix**: `tool/build_aprime.sh` 또는 `hexa cc` 의 macOS path 에서 자동으로 `-D_DARWIN_C_SOURCE` 추가 (uname -s 분기 1줄). 동시에 README/CONTRIBUTING 에 "Darwin 빌드 macro" 1-liner 문서화.

## §3 — `hexa cc --regen` link 단계가 사전 `runtime.o` 없으면 실패 (full-auto regen UX 갭)

```
clang -O2 /tmp/hexa_cc.new.o self/runtime.o -o /tmp/hexat.new …
clang: error: no such file or directory: 'self/runtime.o'
  compiled=no
```

regen 이 hexa_cc.c.new (#1187 보유) + `/tmp/hexa_cc.new.o` 까지 만들고 *link 만* runtime.o 부재로 실패. 사용자는 (a) runtime.o 를 manual 로 빌드 (§2 macro 함정) 또는 (b) 무엇이 잘못됐는지 추측해야 함.

**fix**: regen 파이프라인이 link 직전 runtime.o 부재 시 자동 빌드 (clang -c self/runtime.c → self/runtime.o, §2 의 OS-conditional macro 동봉). 또는 명확한 error 메시지: `regen failed at link: self/runtime.o missing. Build it with: <exact command>`.

## §4 — `tool/dispatch_runpod_agtape_d768.sh` 가 런타임 `HEXA_CUDA=1` 환경 export 누락 (#1261 의 env-gate 비활성)

ag_tape.hexa:528·1044 의 #1261 backward 경로:
```
let bwd_cuda_on = env("HEXA_CUDA") == "1"
```

즉 *컴파일* 시 `-DHEXA_CUDA` (디스패치 line 167-169) + *런타임* 시 `env("HEXA_CUDA")=="1"` 둘 다 필요. 현 디스패치(line 177):

```
nohup bash -c '… timeout ${WALL_BUDGET_SEC} ./trainer > trainer.out 2> trainer.err; …'
```

`HEXA_CUDA=1` export 없음. ∴ `_ag_linear_cuda_fp32_bwd` 경로 비활성, host-scalar matmul_bwd_auto 폴백. anima 회피 = generated .c 의 main 진입에 `setenv("HEXA_CUDA", "1", 1)` 삽입 (정상 fix 아님).

**fix**: line 177 `timeout …` 직전 `HEXA_CUDA=1` 추가:
```
nohup bash -c '… HEXA_CUDA=1 timeout ${WALL_BUDGET_SEC} ./trainer …'
```

(한 토큰 추가. compile-time `-DHEXA_CUDA` 와 대칭.)

## §5 — `flame_d768_12L_agtape_fire.hexa` 의 `gn2=Σseed²` V=151643 host 루프 잔존 (#1262 후)

`_agt_decoder_step` 의 #1262 후 코드 (라인 ~209-225 stdlib):
```
let _ = farr_ce_seed_gpu(logits, tgt_ids, 1, V, ce_loss, seed)   // ce_loss · seed GPU ✓
let mut gn2 = 0.0
let mut mk = 0
while mk < V {                                                    // ← V=151643 host
    let dv = t_get(seed, mk)                                      // GPU-resident seed
    gn2 = gn2 + dv * dv                                           // host 누적
    mk = mk + 1
}
```

`seed` 가 GPU-resident farr 인데 `t_get(seed, mk)` 를 V=151643 host 루프로 → per-element device-sync (또는 first-touch full-array sync) = step wall 의 잠재 hog. metric 자체는 *logging* 용이고 `farr_ce_seed_gpu` 가 이미 `ce_loss`(GPU) 를 계산해 둠.

**fix** (mk2-C7, anima .c-patch 검증됨):
```
let gn2 = t_get(ce_loss, 0)   // 1-elem GPU read instead of O(V) host reduction
```

이 한 줄로 trainer.c 의 host O(V)/O(V·d) 루프 *0* (lm-head fwd copy 도 #1262 가 해결). 의미 변화: `gn2=Σseed²`(gradient norm) → `ce_loss`(cross-entropy) — 로깅 metric 만 다르고 F-RFC046 wall gate 는 STEP 시간 측정이라 무영향.

## 검증된 fact (반복 가능 출발점)

`#1261 + #1262 + §1~§5 fix 적용` 후 V=151643 d=768 hexa-native GPU step **완주 가능** (anima fire #13: call 1 의 P4 backward done 마커, fire #14: per-phase 타임스탬프). 단 `ag_backward_reg`=863s/call = step wall 의 ~100% → 별건 #1255 코멘트의 backward 최적화 영역.

## anima 측 참조
- 추적 로그: `dancinlab/anima:CORE/DECODER/DECODER.log.md` (2026-05-26 다섯 엔트리)
- 누적 14 fire, A100-80GB ~$6.5, orphan 0 (전부 teardown)
- generator.hexa M4 stub committed (`dancinlab/anima:CORE/DECODER/generator.hexa`)
