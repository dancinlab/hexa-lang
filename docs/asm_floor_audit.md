# `.s` 어셈블리 바닥(floor) 분류 감사

> RUNTIME.flip.md **B9** (`.s` self-emit 목표) 범위 산정용 READ-ONLY 분류.
> 레포 north-star = `.c`/`.o`/`.s` = **ZERO** (`.hexa`-only 컴파일러). `.o` 는 이미 0.
> 남은 `.s` 파일은 4개. 본 문서는 각 파일이 **무엇인지** + **제거/포팅 가능한지** 만 판정한다 (편집·삭제·빌드 없음).

## 분류 기준 (3-way)

- **portable → hexa @asm** — 해당 asm 을 hexa `@asm` 인라인 블록으로 재표현 가능 (zero-`.s` 방향 포팅 후보)
- **irreducible boot-floor** — 하드웨어 reset vector / interrupt vector table / SP 초기화 등 **고정 link 주소의 raw asm 이 필수**인 정직한 바닥 (layer ② 와 동급)
- **stale fixture** — 재생성 가능하거나 삭제 후보인 테스트 잔재

## 요약 표

| file | bytes | what-it-is | class | port/remove path |
|------|-------|------------|-------|------------------|
| `stdlib/hal/t3/boot_rp2040.s` | 2071 | RP2040(Cortex-M0+/ARMv6-M) 최소 boot — `.vector_table` (초기 SP·reset·NMI·HardFault) + reset handler(`.data` copy·`.bss` zero·`harness_main` 호출) | **irreducible boot-floor** | 포팅 불가. vector table 은 FLASH 0x10000100 고정 주소 word 배열 — link-script 가 자리잡는 raw 데이터다. reset handler body 만 `@asm` 후보지만 vector entry 와 분리 불가 |
| `stdlib/hal/t3/boot_stm32h7.s` | 2812 | STM32H7(Cortex-M7/ARMv7-M) 최소 boot — full system vector table(16 entry+240 IRQ pad) + reset handler(CPACR FPU enable·`.data`→DTCMRAM·`.bss` zero·`harness_main`) | **irreducible boot-floor** | 포팅 불가. FLASH 0x08000000 의 vector page 는 reset 시 하드웨어가 직접 fetch — `@asm`(함수 본문용)으로 표현 불가. FPU-enable 시퀀스만 `@asm` 후보지만 reset path 일부라 분리 불가 |
| `stdlib/sscb/firmware/startup/startup_stm32f429.s` | 2844 | STM32F429(Cortex-M4) CMSIS-style startup — `.isr_vector`(weak `Default_Handler` + 명명 IRQ 2개: TIM1_BRK_TIM9·DMA2_Stream2) + weak `Reset_Handler`(`.data` copy·`.bss` zero·`main`) | **irreducible boot-floor** | 포팅 불가. `g_pfnVectors` 는 `_estack`/handler 주소를 담는 link-time word 배열 + `.weak` alias 패턴 — C/hexa 핸들러 override 를 위한 linker 계약이다. 함수 본문이 아니라 데이터 섹션이므로 `@asm`(함수 attr) 대상 밖 |
| `tests/bootstrap/stage_1_forced.s` | 1567 | 2026-05-10 stage-1 forced self-compile **시도 증거 placeholder**. 실제 어셈블러 출력 아님(`//` 주석만 — `as` 가 거부). live 참조 0건(자기 헤더 주석의 자기-경로 1건뿐), cite 한 closure doc 부재 | **stale fixture** | **지금 제거 가능**. 컴파일/링크/테스트 어디서도 참조되지 않음. 본인이 "placeholder, not a real assembler output" 라고 명시. RUNTIME.flip B9 self-emit 과 무관한 죽은 잔재 |

## 파일별 1-2 줄 설명

- **`boot_rp2040.s`** — ARMv6-M(Cortex-M0+) 최소 reset path. `.word _stack_top` / `.word _reset_handler+1` 로 시작하는 vector table 을 `.vector_table` 섹션에 박고, reset handler 가 `.data` 를 FLASH→RAM 복사·`.bss` 0-초기화 후 `harness_main()` 으로 점프한다. T3 Renode 하니스 polling 전용(인터럽트 미배선).
- **`boot_stm32h7.s`** — ARMv7-M(Cortex-M7) 최소 reset path + FPU(CPACR CP10/CP11) enable. 16개 system entry + 240개 IRQ pad 의 full vector table 을 FLASH 0x08000000 에 두고, reset handler 가 FPU 켜고 `.data`→DTCMRAM 복사·`.bss` zero 후 `harness_main()` 호출.
- **`startup_stm32f429.s`** — Cortex-M4 CMSIS 표준 startup. `g_pfnVectors`(`_estack`+모든 핸들러 주소 word 배열, 대부분 `Default_Handler` 무한루프, IRQ 24/58 만 명명) + `.weak Reset_Handler`. weak alias 패턴으로 production firmware 가 named C 핸들러로 override 한다.
- **`stage_1_forced.s`** — 실제 `.s` 가 아니라 stage-1 강제 self-compile 시도가 1800s timeout 으로 죽은 사실을 기록한 **증거용 주석 placeholder**. host contention(parallel agent #4 와 경합)으로 splice→types 경계를 못 넘겼다는 메모만 담겨 있고, 어떤 빌드/테스트에서도 참조되지 않는다.

## `@asm` facility 존재 여부

**존재함 (단, function-body 용도로 한정·codegen lowering 보류 중).**

- 라이브러리 capability: `stdlib/firmware/asm.hexa` — `asm_emit_block(body, clobbers)` 가 GCC `__asm__ volatile (...)` 인라인 fragment 를 생성. 지원 arch = `armv6-m` / `armv7e-m` / `armv8-m.main` (FIRMWARE.md §4 G-F4 + RFC 063, anti-balloon ≤5 sites 규율).
- codegen 인지: `self/codegen.hexa:1851` 가 `@target`/`@mmio`/`@interrupt`/`@asm` annotation 을 **인식은 하되 lowering 은 RFC 063/064 로 deferred** —
  ```
  /* FIRMWARE.md @target/@mmio/@interrupt/@asm — codegen lowering pending RFC 063/064 (treated as no-op on this lane) */
  ```

핵심 한계: `@asm` 는 **함수 본문 안의 인라인 escape hatch**(예: `wfi`, `dsb` 단일 명령)를 위한 것이지, **고정 link 주소에 놓이는 vector table word 배열**을 위한 것이 아니다. 위 3개 boot 파일의 본질은 함수가 아니라 reset 시 하드웨어가 직접 fetch 하는 **데이터 섹션**(`.vector_table` / `.isr_vector`)이므로 현재의 `@asm`(또는 lowering 완료 후의 `@asm`)로도 대체 불가.

## 최종 판정 (verdict)

| 판정 | 개수 | 파일 |
|------|------|------|
| **지금 제거 가능 (stale)** | **1** | `tests/bootstrap/stage_1_forced.s` |
| **정직한 irreducible boot-floor** | **3** | `boot_rp2040.s` · `boot_stm32h7.s` · `startup_stm32f429.s` |

- **제거 가능 = 1.** `stage_1_forced.s` 는 실제 asm 도 아니고(`as` 가 거부) live 참조도 0건인 죽은 증거 placeholder. RUNTIME.flip B9 `.s` self-emit 카운트에서 빼야 할 항목 — 별도 cleanup PR 로 삭제 가능(본 감사는 READ-ONLY 라 삭제는 미수행).
- **irreducible = 3.** 세 HAL boot 파일은 layer ② 와 동급의 정직한 하드웨어 바닥이다. vector table 은 reset 시 CPU 가 직접 읽는 고정 주소 word 배열이고, weak-alias linker 계약·SP 초기화는 함수-본문 `@asm` 로 환원 불가. self-emit 목표가 의미를 가지려면 컴파일러가 **link-script 에 박히는 데이터 섹션** 자체를 `.hexa` 로 방출해야 하며(reset vector 를 `@target`/`@interrupt` annotation 으로 1급 처리하는 RFC 063/064 lowering 완료가 전제), 이는 현재 `@asm` capability 범위 밖이다.

### B9 self-emit 범위 함의

- 진짜 분모는 `.s` 4개가 아니라 **3개**(stale 1개 제외 후).
- 이 3개는 "포팅 불가 = 실패" 가 아니라 layer ② 식 **정직한 floor 선언** 대상이다. zero-`.s` 를 강제하려면 RFC 063/064 가 `@interrupt`/`@target` vector-table lowering 을 1급으로 끝내야 하며, 그 전까지는 honest floor 로 남긴다.
