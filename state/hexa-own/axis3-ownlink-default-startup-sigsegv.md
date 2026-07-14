# axis-③ own-link DEFAULT-ON → 링크된 바이너리가 startup SIGSEGV (근인규명)

**결론 한 줄:** stdlib-selftest-gate 의 SIGSEGV(139) 는 **#4947 이 만든 것도, `farr_*` 와 관련된 것도 아니다.**
근인은 **own-link default-ON 플립(#4902)** — 링커가 rc=0 으로 "성공"하면서 **실행 즉시 죽는 바이너리**를 낳는다.
#4947 은 무죄이며, 그 revert(#4951)는 이 결함을 고치지 못한다.

---

## 1. 무엇이 관측됐나

`main @ 6a1888023` (#4947 머지 커밋) 에서 `stdlib-selftest-gate` 가 RED:

```
Gate — @ci_gate stdlib selftests must all PASS
  ./hexa run tool/stdlib_selftest_aggregate.hexa --ci-gate --strict
  Segmentation fault (core dumped)
  ##[error]Process completed with exit code 139
```

직전 커밋(686fcd13b)이 CI 에서 SUCCESS 였기 때문에 #4947 이 범인으로 지목됐고, 그 근거로 revert(#4951) 가 올라갔다.
**그 이분법이 틀렸다.**

주목할 점: `./hexa --version` 는 통과했고, 크래시는 gate 시작 **0.12초** 만에 났다.
컴파일이 진행됐다기엔 너무 빠르며, `tool/stdlib_selftest_aggregate.hexa` 는 **`farr_*` 를 단 한 번도 호출하지 않는다.**

## 2. 대조군이 똑같이 죽는다 (#4947 무죄)

부모 커밋(686fcd13b = CI 가 "SUCCESS" 라 부른 그 커밋)을 **GitHub 새 clone** 으로 빌드해 같은 명령을 돌리면
**동일한 SIGSEGV** 가 난다. 4개 빌드구성 × 2개 호스트 전부:

| 구성 | 호스트 | green(686fcd13b) | red(6a1888023 = #4947) |
|---|---|---|---|
| cold clone + ccache | aiden | **SEGV 139** | SEGV 139 |
| cold clone, ccache 완전 비활성 | aiden | **SEGV 139** | SEGV 139 |
| warm tree (CI 워크스페이스 사본) | aiden | **SEGV 139** | SEGV 139 |
| cold clone + ccache | summer | **SEGV 139** | SEGV 139 |

`summer` 는 CI 의 "SUCCESS" 대조군들이 **전부 실제로 돌았던 바로 그 호스트**다. 거기서도 green 이 죽는다.

결정타 — green 트리에서 aggregate 를 직접 빌드해 실행:

```
$ ./hexa build tool/stdlib_selftest_aggregate.hexa -o /tmp/agg_g
OK: built /tmp/agg_g (native own-link, own-start — no clang, no ld)   ← rc=0 "성공"
$ /tmp/agg_g --ci-gate --strict
Segmentation fault (core dumped)    rc=139, 출력 0바이트
$ strace -f -e trace=execve /tmp/agg_g … | grep -c execve
1        ← 자식 프로세스 0개. 자기 자신이 시작하자마자 죽는다.
```

⇒ `#4947` 의 diff 는 이 크래시와 **무관**하다. (bind.hexa / hir_to_mir.hexa / arm64_darwin.hexa 를
green 위에 하나씩 얹는 sub-bisect 도 전부 SEGV — 즉 **어떤 파일도 범인이 아니었다**. 대조군 자체가 이미 빨간색이었기 때문.)

## 3. 진짜 근인 — own-link 가 깨진 바이너리를 낳는다

`self/main.hexa:3623` (cmd_build) 과 `self/main.hexa:4763` (cmd_run) 은 linux-x86_64 호스트에서
own-emit + own-LINK(`hexa_ld`) 경로를 **DEFAULT-ON** 으로 태운다 (`HEXA_OWNLINK_DEFAULT != "0"`, 플립 = **#4902**).
그 경로가 만든 바이너리가 **시작하자마자** 죽는다.

`strace` 로 잡은 폴트 (aiden · summer 동일):

```
mmap(NULL, 4194304, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x71d941400000   ← 정상 (arena 4MB)
mmap(NULL, 0, 0x400000 /* PROT_??? */, MAP_SHARED_VALIDATE, 34, 0) = -1 EBADF                  ← 쓰레기 인자
--- SIGSEGV {si_signo=SIGSEGV, si_code=SEGV_MAPERR, si_addr=NULL} ---
```

두 번째 `mmap` 의 인자를 의도한 값과 맞춰보면 **2번 인자부터 전부 레지스터 한 칸씩 밀렸다**:

| 슬롯 | 의도 | 실제 전달 |
|---|---|---|
| len | 4194304 | **0** |
| prot | 3 | **4194304** ← len 이 여기로 |
| flags | 0x22 | **3** ← prot 이 여기로 |
| fd | -1 | **34 (=0x22)** ← flags 가 여기로 |

즉 **선두에 레지스터 하나가 더 끼어든 C-ABI 호출** = 이 리포의 고질 **pair-ABI ↔ C-ABI 스큐**.
(own-emit 규약은 인자당 2레지스터 = tag+payload. `self/native/alloc_syscall_x86_64.s::_sc6` 프롤로그가
`mov [rbp-80], rdi # store tag L0` / `mov rbx, rsi # ingress param payload` 로 그 규약을 그대로 보여준다.)

반환된 `-1`/NULL 을 **검사 없이** 베이스로 써서 zero-fill 저장 루프가 NULL 을 통해 쓴다:

```
gdb=> 0x44add6:  mov %r8,(%rax,%rsi,8)     rax=0x0  rsi=0x0  rdi=0x3
```

### behavioral 게이트 — 같은 트리·같은 커밋·같은 바이너리, env 하나만 다름

```
[A] own-link DEFAULT (CI 가 도는 그대로)
    ./hexa run tool/stdlib_selftest_aggregate.hexa --ci-gate --strict
    → rc=139  Segmentation fault  출력 0줄

[B] HEXA_OWNLINK_DEFAULT=0 (own-link 옵트아웃)
    → rc=1    aggregate 가 정상 기동:
      # stdlib_selftest_aggregate  found=94  strict=true  ci_gate=1
      # summary pass=86 fail=5 timeout=3 error=0 total=94
      # wrote state/stdlib_selftest_20260714T025605Z.jsonl
```

이 A/B 는 **green(686fcd13b) 트리**에서 측정했다 — #4947 없이도 재현된다는 뜻.

## 4. 왜 아무 게이트도 못 잡았나 (구조적 교훈)

1. **own-link 는 rc=0 으로 "성공"한다.** `self/main.hexa` 의 안전망 주석("ANY emit/own-link failure STILL
   falls through to tier-B ld")은 **이 결함엔 작동하지 않는다** — 실패가 아니라 *조용한 오염*이라서
   fallback 이 영영 호출되지 않는다. `hexa build` 는 `OK: built …` 를 찍는다.
2. **플립을 뒷받침한 증거(byteeq · ownlink-corpus-parity #4881)는 링커의 방출 바이트/exit code 를 비교하지,
   링크된 바이너리의 런타임 거동을 비교하지 않는다.** 그래서 전부 GREEN 인 채로 통과했다.
   ⇒ `test -x` · `rc==0` · 심볼 존재 · 바이트 동일성은 **behavior 를 대신하지 못한다.**
3. **stdlib-selftest-gate 의 초록 이력도 신뢰할 수 없다.** `hexa run` 은 컴파일 결과를
   `~/.hexa-cache/hexa_run.<sha>_<ver>` 로 캐시하고(`self/main.hexa:4251`) self-hosted 러너는 `$HOME` 을
   잡업 간 **유지**한다. 즉 게이트는 소스+버전 키가 그대로인 동안 **예전에 컴파일된 바이너리를 재사용**할 수 있다.
   (이미 등재된 재발방지 학습 `CLI-RUNCACHE-STALE-ABI` 와 같은 계열.)

   ⚠️ **정직한 잔여 미해결점:** 위 캐시 가설이 CI 의 green 통과를 실제로 설명하는지는 **확증하지 못했다.**
   내가 만든 어떤 clean-room 구성에서도 green 은 통과하지 않았다(전부 SEGV). 따라서 "CI 의 green 이
   왜 초록이었나" 는 **열린 질문**이며, 러너에 남아 있던 상태(warm workspace / `~/.hexa-cache`)가
   유력 후보지만 **측정으로 못 박지 못했다.** 확실한 것은 위 §2 — **green 은 from-scratch 로는 어디서도 통과하지 않는다.**

## 5. 이번 PR 이 하는 일

거버넌스 그대로 — *release integrity > self-host progress*, *every flip opt-in-first → byteeq GREEN
**+ shipping smoke** → default-ON* — **#4902 의 default-ON 승격을 철회**하고 own-link 를 **opt-in
(`HEXA_OWNLINK_DEFAULT=1`)** 으로 되돌린다. 두 사이트(`cmd_build` · `cmd_run`)를 lockstep 으로.

- 경로 자체는 살아 있다(플래그로 계속 axis-③ 작업 가능). polarity 영구 반전이 아니라,
  **shipping smoke 를 통과하지 못한 승격의 철회**다.
- 사용자 대면 경로(`hexa build`/`run`)가 즉시 복구된다.

## 6. 다음 rung (이 PR 범위 밖 — 정직한 경계)

- **ABI 스큐의 정확한 방출 지점**은 아직 file:line 으로 못 박지 못했다. 폴트 시그니처(선두 레지스터 1개 초과)와
  결함 계열(pair-ABI ↔ C-ABI)은 확정했으나, own-link 가 어느 호출에서 tag 레지스터를 흘리는지는
  링크된 바이너리 디스어셈블로 추적해야 한다. **이것이 own-link 를 다시 default-ON 하기 위한 게이트다.**
- **own-link 승격 게이트에 behavioral 검사를 추가해야 한다** — "링크된 바이너리를 *실행*해서 기대 출력이 나오는가".
  링커 바이트 동일성만으로는 이 결함이 또 통과한다.
- **stdlib-selftest-gate 는 `~/.hexa-cache` 를 비우고 돌려야** 실제로 컴파일하는 것을 잰다(현재는 캐시 히트 가능).
