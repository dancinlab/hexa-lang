# bug3 잔존 dynamic 심볼 실측 (fix/axis1-bug3-extract-floor-pull dc149ecbd · aiden 2026-07-12)

extraction floor-pull(#4871 LOCUS1/2) 후 measured on /tmp/xout:
- RELASZ 936B→480B (n_dyn 39→20 · hxlcl_ 로컬바디는 전부 pull됨)
- 그러나 PT_INTERP + DT_NEEDED libc.so.6 지속 → own _start/ld.so 하이브리드 → rc139 (CROSS_OK 출력후 SIGSEGV)

## 잔존 20 R_X86_64_GLOB_DAT (readelf --use-dynamic -r /tmp/xout · 전부 libc)
stderr, __stack_chk_fail, fdopen, _exit, strtod, fileno, gmtime_r, fwrite, fflush,
fclose, stdout, getc, setvbuf, mmap, __isoc23_strtol, munmap, __isoc23_strtoll,
ptsname_r, abort, cfmakeraw

## 분류
- stdio FILE*: stderr, stdout, fdopen, fileno, fwrite, fflush, fclose, getc, setvbuf
- 종료/가드: _exit, abort, __stack_chk_fail
- 파싱: strtod, __isoc23_strtol, __isoc23_strtoll
- 메모리: mmap, munmap
- 시간: gmtime_r
- tty: ptsname_r, cfmakeraw

= clang-컴파일 runtime.a(runtime.c) 멤버가 import하는 진짜 외부 libc 의존. hxlcl_ 바디 없음 → linker alias로 풀 수 없음.

## Fable 결정 (2026-07-12): Path 2 CRT1-HANDOFF (n_dyn>0 게이트)
동적링크 유지 + crt1.o pull → 그 _start(=__libc_start_main 호출)를 진입점·own stub 억제 → glibc teardown 계약 충족(rc139 치유). n_dyn=0시 자동 pure own-start 복귀=수렴적. 4로키(census pre-pass·entry selection·serializer entry_off param·crt1 sourcing).

## crt1.o recon (aiden glibc 2.39·구현 선결 실측)
- defines: _start(T) _dl_relocate_static_pie(T) _IO_stdin_used(R) __data_start(D) data_start(W) __abi_tag(r)
- UND: main, __libc_start_main, **_GLOBAL_OFFSET_TABLE_** (Fable 예측보다 1개 많음 — linker가 GOT base 정의 필요)
- .rela.text: main=R_X86_64_REX_GOTPCRELX(kind42), __libc_start_main=R_X86_64_GOTPCRELX(**kind41**) — 2종
- .rela.eh_frame: R_X86_64_PC32 ×2 vs .text (reader eh_frame skip 확인 필요)
- sections: .note.gnu.property .note.ABI-tag .text .rela.text .rodata.cst4 .eh_frame .rela.eh_frame .data .bss

## CRT1-HANDOFF 검증 (aiden 018b5d179·2026-07-12·PARTIAL-진전)
- ELF_TYPE=EXEC · ENTRY=0x400120 = **crt1 _start 확정**(gdb: endbr64;xor ebp,ebp;mov r9,rdx;pop rsi;...;call [__libc_start_main];hlt) — 진입점 계약 성공
- DYN_RELOC=21 (20 libc + __libc_start_main) — crt1.o pull 성공
- main 실행·CROSS_OK 출력(stdout 정상 동작) · **그러나 XOUT_RAN=139 지속**
- crash 이동: own-start teardown → **exit시 libc _IO_flush_all**. gdb: rip=libc 0x..5807 `testl $0x8000,(%rdi)`, **rdi=0x25ff000195a325ff=garbage**(내부 ff25 jmp-GOT 코드바이트), 스택 #5=runtime 0x43fe36(stack-protector C fn), #8=_GLOBAL_OFFSET_TABLE_ from ld.so
- **PIPE_RC=0** (파이프시 stdout 버퍼링 다름→문제 스트림 회피·직접 tty만 rc139)
- 가설: 손상된 FILE* _chain/vtable OR stdout/stderr(libc DATA 심볼) COPY-reloc vs GLOB_DAT 미스매치 OR fdopen 스트림 등록 문제. Fable 위임.

## exit-crash 선수집 데이터 (aiden runtime.c·Fable 위임 보강)
- **hxlcl_fdopen(runtime.c:1378) = 가짜 FILE* `(void*)(fd+1)` 반환** (실제 libc FILE 아님)·fileno/fread가 디코드. hxlcl_fopen:1294·hxlcl_setvbuf:1387·hxlcl_posix_openpt:3965.
- 매크로 redirect(runtime.c:2914+): fopen/fdopen/setvbuf/fileno → hxlcl_. 그러나 **fwrite/fflush/fclose/stdout/stderr는 실제 libc 유지**(그래서 CROSS_OK 출력됨=실 libc stdout).
- 혼합-stdio 위험: 가짜 FILE*가 실 libc fn에 전달되거나 libc _IO_list_all 체인 유입 → exit flush시 garbage. rdi=0x25ff...=fake/corrupt.
- 15640: `fdopen(pipefd[0],"r")`(→hxlcl), 13366: `fopen(...,"ab")`(→hxlcl). Fable: 근인=COPY-reloc vs GLOB_DAT(stdout/stderr) OR fake-FILE* 체인유입 OR init_array 미발행.

## Fable 근인 확정 (라운드3·측정확인)
★근인: census(elf_x86_64.hexa ~2263)가 **reloc kind로 stub 여부 판단**(kind2 PC32→dyn_stub=1) — **심볼 타입 무시**. stdout/stderr(STT_OBJECT·20중 유일 data)가 6B jmp-stub(ff 25 disp32)에 바인딩됨→ 데이터 로드가 stub 코드바이트를 FILE*로 읽음→ rdi=0x25ff000195a325ff=**두 stub 패킹**(ff25 a3 95 01 00 | ff25). 함수엔 맞음(poor-man PLT), 데이터엔 치명.
측정확인: pipe_rc PIPESTATUS[0]=139=tty_rc (buffering설 FALSIFIED·pipefail 아티팩트=known memory). CROSS_OK는 hxlcl_ write(2) lane + PIE GOT lane(kind41/42)로 출력·crash는 non-PIC PC32 lane(exit-flush 0x43fe36).
★fix=R_X86_64_COPY lane(4로키): A=libc.so.6 .dynsym 읽어 type/size, B=census 3-way(FUNC+nonGOT→stub·OBJECT+nonGOT→copy·GOT→GLOB_DAT), C=.bss에 st_size 예약+GLOBAL data def, D=dynsym defined+`.rela.dyn` R_X86_64_COPY(r_type=5). build_aprime -fPIC 강제 금지(정답지=linker가 PIC/non-PIC 혼합 처리·polarity). n_dyn>0 게이트 유지=byteeq neutral.
후속 tripwire: DT_INIT_ARRAY(runtime .init_array ctor) dyn path 미수집(별개·이 crash 아님).

## ★ bug3 종결 PASS (aiden 423a47cde·2026-07-12)
LIVE_VERDICT=PASS·XOUT_RAN=0(rc139→rc0)·XOUT_OUTPUT=[CROSS_OK]·TTY_RC=0·PIPE_PIPESTATUS=0·EXECVE_FOREIGN=0(clang-0)·APRIME_RC=0·2×R_X86_64_COPY(stdout@4a1658/stderr@4a1660).
3-fix 스택: #4871 extraction floor-pull(936→480) + CRT1-HANDOFF(crt1 _start 진입) + R_X86_64_COPY lane(stdout/stderr 데이터 바인딩). own-linker(clang/ld/as 0) 크로스 바이너리 첫 정상실행. axis-① rung-2 clang-0 cross LIVE(pool 측정). 머지게이트=byteeq 3-target PR-CI GREEN(n_dyn>0 opt-in 게이트라 shipping byteeq-neutral 기대).

## ★★ MERGED — axis-① rung-2 LIVE (2026-07-12)
#4866 bug2(+x chmod·main.hexa) MERGED c9af152d3 · #4871 bug3(3-fix·elf_x86_64.hexa) MERGED f0810d165. byteeq 3-target GREEN(selfhost-byteeq-real·413d5fc3e·elf 무변경 조성). n_dyn>0/--linker=hexa opt-in 게이트=shipping byteeq-neutral. clang-0 크로스빌드(own-linker→정상실행 rc0 CROSS_OK) = LIVE. 후속 tripwire(별개·미배선): DT_INIT_ARRAY(runtime .init_array ctor)·environ gap(crt 경로·#4868이 own-start쪽 처리). 다음 프런티어=2lane(L4 정적타입·L5 메모리관리).

## (별건·L5) round-2 census verify-done (aiden main 7da6d50ff·2026-07-12)
census-final: HX30XX_TOTAL_FIRES=0 (HX3014 48 FP→0 via gen/kill #4889·HX3055 42 TP→0 via mut #4879)·WOULD_MOVE=0·COST_DELTA 2.7%(<5%). B1 게이트 '0 HX3014' SATISFIED. round-2 verify-done. next=B3 default-ON warn band flip(round-3·byteeq 3-target).
