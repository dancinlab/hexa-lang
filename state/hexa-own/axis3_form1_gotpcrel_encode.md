# axis-③ 네이티브 x86_64 ELF 인코더 — FORM-1 GOTPCREL extern-data GOT load (batch-1)

프론티어: 네이티브 x86_64 ELF 인코더(`compiler/emit/elf_x86_64.hexa`)의 self-compile-blocking
operand-FORM 미스를 순차 종결 → axis-①(native-serve) + axis-③(own-emit) 3lane self-host.

## 배경 — 3 FORM 중 2/3은 이미 origin/main 착지
설계 answer-key(scratchpad `frontier_encoder_design.md`)가 지목한 3 FORM 중:
- **FORM-2 (RIP 글로벌-슬롯 STORE `mov [rip+g<id>],reg` → `REX.W 89 /r` + PC32)** — 착지됨
  (origin/main:elf_x86_64.hexa:3232 store mirror, census #1 1796×).
- **FORM-3 (RIP `+offset` `[rip+g<id>+8]` addend split)** — 착지됨
  (`_ex86_addend_pos`/`_ex86_sym_base`/`_ex86_sym_addend`, data_addends 스레딩).
- **FORM-1 (GOTPCREL extern-data GOT load `mov reg,[rip+sym@GOTPCREL]`)** — **본 배치의 유일 잔여**.
  `_ex86_rip_inner`/`_ex86_data_label_of`가 `@`를 거부(→"") → default mem-parse 실패 → loud ENCODE-MISS.

배치-1(jcc→REL32)은 #4780로 이미 main 착지(내 base = b273d1c96).

## 구현 (FORM-1, opt-in --emit=obj, byteeq-neutral-default)
`compiler/emit/elf_x86_64.hexa` 5 edit:
1. `ELF_R_X86_64_GOTPCREL = 9` 상수 추가(SysV AMD64 ABI §B.2 / §4.4.1 Table 4-11: word32, G+GOT+A-P).
   링커측(`compiler/link/hexa_ld.hexa`)은 `_HEXA_LD_R_X86_64_GOTPCREL=9` + `elf_reloc_is_got_typed`로 이미 인지.
2. `_ex86_gotpcrel_sym(s)` 헬퍼 — `[rip+<sym>@GOTPCREL]`에서 `<sym>` 추출(아니면 "").
3. 워커 arm(`_pack_fn_x86`): `mov reg,[rip+sym@GOTPCREL]` → `_ex86_rip_rel_insn(0x8b, rd)`
   (`REX.W 8B /r`, ModRM mod=00 reg=rd rm=101=RIP, disp32=0), `got_offsets`(cur_off+3)/`got_names` push.
4. `pack_lir_x86_64`: `got_offsets`/`got_names` 선언·스레딩.
5. Pass-4: `ELF_R_X86_64_GOTPCREL`(9) reloc emit, addend −4, 미정의 심볼=undef STB_GLOBAL(environ/stderr/stdout/getenv),
   GOT 슬롯은 링커 합성이므로 pre-patch 없음.

트리거: (a) `--shared` 모듈-글로벌 → `[rip+g<id>@GOTPCREL]`; (b) environ/stdout/stderr/getenv 런타임 빌트인.
user-level `env()`는 `hexa_env_var` PLT32 콜로 lower(인라인 GOTPCREL 아님) — GOTPCREL은 `--shared` 글로벌 또는 런타임 바디에서 발생.

## 검증 (aiden x86_64-linux, 측정)
- **(a) objdump/readelf byte cross-check — 정답키 정확 일치 ✅**
  `--shared` 글로벌 프로그램 `hexa-new --backend=native --emit=obj --shared`:
  ```
  37: 48 8b 15 00 00 00 00   mov 0x0(%rip),%rdx
              3a: R_X86_64_GOTPCREL   g0-0x4
  ```
  = `48`(REX.W) `8b`(MOV r64,[mem]) `15`(ModRM mod=00 reg=010=rdx rm=101=RIP) disp32=0,
  reloc @ 0x3a(=insn+3), type 9(GOTPCREL), sym g0, addend −4 — SDM Vol.2A MOV(8B /r)+tcc gen_addrpc32/GOT와 1:1.
- **(b) ENCODE-MISS census before→after (--shared 글로벌 코퍼스 c1/c2/c3) ✅**
  BEFORE(origin/main, no FORM-1): c1=1 c2=6 c3=3, **TOTAL=10**, GOTPCREL-relocs=0.
  AFTER(FORM-1): **TOTAL=0**, GOTPCREL reloc emit(c1=1). 미스 전량 소거.
- **(d) byteeq-neutral(default 비-shared) — 정확 base b273d1c96 vs FORM-1 byte-cmp ✅**
  p1(arith)/p2(userfn)/p3(while-loop)/p4(global) 전량 **BYTE-IDENTICAL 4/4**. FORM-1 arm은
  `@GOTPCREL` operand에만 발화 → default 경로 inert. (주의: 처음 stale base dfd9e7525 vs 비교시
  p3 DIFFER는 #4780 jcc→REL32 base delta 때문이었고 본 변경 무관 — 정확 base 재측정으로 확정.)
  3-target 전체 byteeq는 PR-CI에서 최종.
- **(c) own-emit smoke(7-case)**: 코퍼스는 GOTPCREL 미방출(비-shared·env 없음) → 본 변경에 inert.
  slot 필요(aiden NO-SLOT) → 3-target byteeq는 PR-CI에서 최종.

## next
- SIB scaled-index `[base+index*scale]` [LOW] — 현재 array index는 `call hexa_index_get/set`로 우회, self-compile 경로 밖.
- `@PLT` operand form(현재 loud miss) — 필요 시 다음 배치.
- axis-③ LINK 반쪽: hexa_ld 정적링크시 GOTPCREL GOT 슬롯 합성(별도 rung).
