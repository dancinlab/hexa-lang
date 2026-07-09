# axis-③ LINK 반쪽 — 정적링크 GOTPCREL(9) GOT-슬롯 합성 (own linker · ZERO binutils)

프론티어: 인코더가 self-emit하는 `R_X86_64_GOTPCREL`(9) reloc(#4783 FORM-1
`mov reg,[rip+sym@GOTPCREL]`)을 own linker가 정적링크 시점에 **GOT를 합성**해
해소(G+GOT+A−P). 인코드 반쪽(#4783)의 짝 = LINK 반쪽. 3lane self-host axis-③.

## ★ 재타깃 (설계 answer-key 판정 — 태스크 framing 대비 정정)
태스크는 `compiler/link/hexa_ld.hexa::link_elf`에 `build_elf64_exec_got` +
2nd PT_LOAD + reloc loop + `find_symbol_by_index` 신설을 지시했으나, **origin/main
grep 재확인 결과 그 경로는 dead code**:
- `main.hexa`의 `--linker=hexa` × `x86_64-linux-gnu` 경로는 L1276/1278에서
  **`link_elf_x86_64_ownstart`**(`compiler/emit/elf_x86_64.hexa:1558`)를 호출.
  `hexa_ld.hexa::link_elf`(L1475)는 이 경로에서 **호출되지 않음**(그 파일 내부
  dispatch L2806/L3124에서만 자기호출; x86 --emit=obj 소비자 아님).
- `hexa_ld.hexa::link_elf`는 text-only scaffold(단일 R+X PT_LOAD e_phnum=1 하드코딩,
  reloc loop 無) → GOT 넣으려면 section-layout 대공사(설계 verdict = NEEDS-LAYOUT-REFACTOR).
- 반면 `link_elf_x86_64_ownstart`는 **#4783 reloc의 실소비자**: `parse_elf_x86_obj`가
  `kind=rtype`(L2495)로 두므로 kind==9가 이미 reloc loop에 흘러들어와 generic PC-rel
  `else`(S+A−P)로 **오컴파일**(disp32가 GOT 슬롯이 아니라 심볼 자체를 가리킴). 이미
  2×PT_LOAD(`serialize_elf_exec_x86_64_2seg`)+def_names/def_seg/def_off 심볼맵+reloc
  loop 전부 존재 → GOT는 data blob 꼬리에 라이딩 = **serializer 무변경·신규 세그먼트 無**.

→ **`link_elf_x86_64_ownstart`에 구현. `hexa_ld.hexa`는 일절 미변경**(그 파일의
`_build_elf64_image`/`build_elf64_exec`는 손대지 않음 → trivially byte-identical).
이것은 feature 추가이자 **live miscompile 교정**.

## 구현 (compiler/emit/elf_x86_64.hexa::link_elf_x86_64_ownstart · 4-pass)
reference-match: tcc `x86_64-link.c` put_got_entry(sym_attr->got_offset 메모이즈 =
심볼당 1슬롯) + relocate_section case R_X86_64_GOTPCREL
(`val = got->sh_addr + got_offset + r_addend − addr`); SysV AMD64 psABI §12.2
(GOT entry = word64) / §B.2 (GOTPCREL word32 G+GOT+A−P).

1. **COLLECT** (obj-concat 뒤, layout 상수 앞): 모든 reloc 중 `kind==9` 타깃 심볼명을
   first-seen 순서로 dedup → `got_syms`, `n_got`. (심볼당 1슬롯 = tcc memoize.)
2. **ALLOCATE**: `has_data`에 `|| (n_got>0)` 추가(GOT-only 프로그램도 RW 세그 확보) →
   `data_vaddr_base` 확정 후 data_bytes 8-align 후 `n_got*8` 0바이트 append
   (`got_blob_off`). **reloc loop 前에 append** → .bss vaddr
   (`data_vaddr_base+len(data_bytes)+off`)가 GOT 뒤에 자연 배치. GOT는 data blob 내
   실파일바이트(p_filesz 커버) → serializer 무변경.
3. **FILL** (reloc loop 뒤, serialize 前): 각 슬롯 = 심볼 최종 vaddr S를 8B LE로 기록.
   S 리졸버는 reloc loop과 동일(seg0=text / seg2=bss / else=data). 정적링크라 슬롯이
   곧 S(동적링크면 ld.so가 GLOB_DAT로 채움).
4. **PATCH** (reloc loop 양팔 = data-site + text-site 각각 `else if r.kind==9` 신설):
   disp32 = `slot_vaddr + r.addend − p_vaddr` = G+GOT+A−P. addend(−4)는 RELA 필드에서
   그대로 읽음(하드코딩 금지). signed word32 overflow guard 포함. generic PC-rel
   `else`(kind 2/4)가 삼키던 kind==9를 정확히 대체.

`link_elf_x86_64_ownstart_ar`은 call-through(L1804)라 자동 상속.

## release-integrity (opt-in · default byte-identical)
- 이 경로는 `--linker=hexa` × `--emit=obj`(#4783 own-emit)에서만 도달. default
  `hexa build`/`run` = C-transpile / system ld → **완전 무영향**.
- GOTPCREL 없는 프로그램 = `n_got==0` → GOT append 無·kind==9 arm inert → 기존과
  **byte-identical**(--linker=hexa 내부에서도). ⇒ PR-CI byteeq 3-target GREEN = 증명.

## 검증
- **구조 게이트(신규 in-tree 테스트)**: `compiler/test/elf_ownstart_gotpcrel_test.hexa`
  — datareloc 테스트 idiom 미러. hand-built ElfX86Obj(main이 `g`를 GOTPCREL로 2회 로드
  = dedup) → in-process 링크 → ET_EXEC 바이트 self-derived 검증: (a) e_phnum==2
  (2 PT_LOAD), (b) data p_filesz==16(g슬롯8 + GOT 1슬롯8 = **dedup 증명**), (c) GOT 슬롯
  = g 최종 vaddr 8B LE, (d) 두 disp32 = slot_vaddr−4−P = got_slot_vaddr−rip_next
  (정답키 일치). 헐메틱(x86 호스트 불요).
- **★ run-correctness(실행+binutils diff)**: 미측정 — 로컬 `~/.hx/bin/hexa`(v0.574.1
  stale)는 C-transpile flatten-collision(`_symc_names`(elf_arm64) vs `_symh_names`
  (elf_x86_64) 로컬 오버랩)로 **미변경 origin/main datareloc 테스트조차 동일 clang RED**
  → 로컬 오라클 무효(내 변경 무관: 내 코드는 transpile OK, clang은 기존 _symc/_symh만
  에러). pool도 과부하(aiden 11·summer 8 > 4). → **PR-CI 및 idle-pool로 이월**.
- byteeq 3-target = default 경로 무변경 증명(PR-CI).

## next wall
- **undefined GOTPCREL 심볼**(environ/stdout/stderr 등 extern/libc): 정적 own-link가
  주소 조작 불가 → 현재 명확 error(return 3). 다음 rung = dynamic-link GOT
  (`R_X86_64_GLOB_DAT` via ld.so) 또는 runtime.a 리졸브.
- weak-undef → S=0 슬롯(psABI)는 이번 컷 미구현(error로 통합) — 필요 시 후속.
- `hexa_ld.hexa` 통합은 여전히 layout-refactor(별도 rung); 최저비용 경로는 disk `.o`를
  `parse_elf_x86_obj`+`link_elf_x86_64_ownstart`로 흘리는 것.
