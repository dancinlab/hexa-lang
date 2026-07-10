# axis-③ Road A — own-linker dynamic-link 설계 (sanctioned libc floor → libc.so.6)

기준 좌표: `.worktrees/startfix` (`fix/axis3-ownstart-argc-argv`) `compiler/emit/elf_x86_64.hexa`
(H1 unresolved-reloc hard-error :1896-1912 · H2 STB_LOCAL scoping :1783-1804 포함, 3974 lines).
경로는 전부 `--linker=hexa` opt-in — shipping 무영향, byteeq는 "n_dyn==0이면 신규 코드 전부 미실행"으로 보존.

## ⓪ 최상위 결정 2개 (요청 #6·#4의 답)

**D1. ET_EXEC 고정 vaddr(0x400000) 유지 — PIE(ET_DYN) 기각.**
dynamically-linked ET_EXEC은 완전 합법(gcc `-no-pie` 산출물과 동형). ld.so는 NEEDED lib을
높은 주소에 매핑하고 exec은 고정 주소 그대로 — **기존 vaddr 산술(reloc loop·GOT fill·call
patch) 전부 무변경**. PIE는 kind==1 absolute data reloc 전부를 R_X86_64_RELATIVE로, static
GOT fill 전부를 RELATIVE로 바꿔야 함(수백 reloc + byteeq 전면 churn). 최소변경+확실 = ET_EXEC.

**D2. PLT lazy-bind 전체 기각 — "GLOB_DAT-only + 6-byte jmp stub" 모델.**
JUMP_SLOT/.rela.plt/DT_JMPREL/DT_PLTGOT/DT_PLTREL/PLT0 헤더/lazy resolver 전부 불필요:
- 모든 dynamic UND 심볼(코드+데이터)에 **기존 GOT blob의 슬롯 1개씩** 배정.
- 각 슬롯에 `.rela.dyn`의 **R_X86_64_GLOB_DAT(6)** 1개 — GLOB_DAT은 항상 eager(ld.so가
  시작 전에 채움)이므로 **BIND_NOW 플래그조차 불필요**(DT_FLAGS DF_BIND_NOW는 문서화용 optional).
- 코드 심볼(call 대상)은 text 꼬리에 **6-byte stub `ff 25 disp32` = jmp [rip+slot]** 합성,
  stub을 def_names에 등록 → 기존 reloc loop(:1855-1894 generic PC-rel else)이 call site를
  무변경으로 패치. call site 재작성 불필요(e8 rel32 5B → ff 15 6B 치환은 길이 불일치라 불가).
- tcc의 static→dyn 최소 emit과 동형이되 lazy 기계 생략으로 더 작음.

## ① 신규 데이터 구조물 — 전부 data_bytes 꼬리 탑승 (GOT blob #4785 패턴 재사용)

data blob 안 배치 순서 (GOT allocate :1756-1761 직후 append):
```
[user .rodata++.data][pad8][GOT (기존+dyn 슬롯)][.dynstr][pad8][.dynsym][pad8][DT_HASH][pad8][.rela.dyn][pad8][_DYNAMIC][interp string]
```
serializer는 세그먼트를 통짜로 매핑하므로 **섹션 헤더 불필요**(e_shnum=0 유지 — ld.so는
program header + DT_*만 사용). 모든 vaddr = `data_vaddr_base + blob_off`로 append 시점에 확정
(data_file_off는 len(text)에만 의존, stub 합성 후 text 확정이므로 순서만 지키면 됨).

- **.dynstr**: `\0` + 각 dyn 심볼명 + `libc.so.6\0` + (interp는 별도). offset 기록.
- **.dynsym**: 24B/entry. entry0 = all-zero null. entry i = {st_name=dynstr off,
  st_info=0x10(GLOBAL|NOTYPE), st_other=0, st_shndx=0(UND), st_value=0, st_size=0}.
  NOTYPE로 충분(런타임 lookup은 type 비강제) — H2의 def collect(:1626-1674 local defs)와
  자연 분리: **def_names는 그대로(정적 해석용), .dynsym은 UND 전용 신규 리스트** — 겹치는
  집합이 없음(def 있으면 dyn 아님).
- **DT_HASH (필수·놓치기 쉬움)**: ld.so가 exec을 global scope 첫 객체로 심볼검색하므로
  hash 없으면 lookup 불능. **SysV hash 최소형**: `{nbucket=1, nchain=n_dynsym,
  bucket[0]=(n>1?1:0), chain[i]=i+1, chain[last]=0}` — 해시함수 구현조차 불필요(체인 전탐),
  n≈40이라 O(n) lookup 무의미한 비용. GNU_HASH 불필요.
- **.rela.dyn**: 24B/entry = {r_offset=slot_vaddr(u64), r_info=(dynsym_idx<<32)|6, r_addend=0}.
  슬롯당 1개.
- **_DYNAMIC** (16B/entry): DT_NEEDED(1)=dynstr("libc.so.6") · DT_HASH(4) · DT_STRTAB(5) ·
  DT_SYMTAB(6) · DT_STRSZ(10) · DT_SYMENT(11)=24 · DT_RELA(7) · DT_RELASZ(8) ·
  DT_RELAENT(9)=24 · [optional DT_FLAGS(30)=0x8] · DT_NULL(0). DT_DEBUG 생략(RW라 무해하나 불필요).
  glibc≥2.34는 dlopen/dlsym/dlerror도 libc.so.6 안(libdl 통합) → **DT_NEEDED 1개로 종결**.
- **interp string**: `/lib64/ld-linux-x86-64.so.2\0` — kernel이 file offset으로 직접 읽으므로
  data blob 탑승 OK.

## ② 함수별 삽입 지점 + 스케치 (elf_x86_64.hexa)

### (A) dyn-UND census — :1693 (call-patch 직후, GOT collect :1695 직전)
def 테이블 완성 시점. 전체 obj reloc 스캔: def_names에 없는 이름 → `dyn_names` 수집,
`dyn_needs_stub[i]`(kind 2/4 site 존재) / kind==9 site 존재 여부 분류. 난이도 하(기존
GOT-collect 루프 :1706-1731 복제형). **kind==1 UND는 즉시 hard-error 유지**(text-site면
DT_TEXTREL 벽 — 넘지 않음; data-site R_X86_64_64 dyn reloc은 관측되면 후속 rung).

### (B) stub 합성 — census 직후, layout consts :1739 이전 (text 길이 확정 필요)
```
stub_off[i] = len(text_bytes); push ff 25 00 00 00 00   // jmp [rip+disp32] placeholder
def_names.push(name); def_seg.push(0); def_off.push(stub_off[i])
def_bind.push(ELF_STB_GLOBAL); def_obj.push(-1)
```
→ 기존 reloc loop이 모든 call site를 stub으로 무변경 해석(핵심 우아함: **reloc loop 코드 0줄
변경으로 call 라우팅 완성**). disp32는 layout 후 STUB-FILL 패스에서
`slot_vaddr - (text_seg_vaddr + stub_off + 6)`로 기입(GOT-FILL :1919 옆에 동형 루프).
0x400000 기반 text↔data 거리 ≪ ±2GB — overflow 없음. 난이도 하.

### (C) GOT collect/alloc 확장 — :1706-1761
`got_syms`에 dyn_names 전원 추가(데이터 GOTPCREL 대상 + stub 대상 공용 슬롯; 같은 심볼이
호출+주소취득 양쪽이어도 슬롯 1개). GOT-FILL :1937-1944의 undefined hard-error를
**"dyn 집합이면 슬롯 0으로 skip"**(ld.so가 GLOB_DAT으로 채움)으로 분기. 난이도 하.

### (D) reloc loop kind==9 호이스트 — :1831/:1869
현재 kind==9 분기가 `found_idx >= 0` 안에 중첩 → **UND GOTPCREL(environ/stdout 등)이 H1
error로 떨어짐**. kind==9 패치는 s_vaddr을 안 쓰므로(슬롯 주소만 사용) **def-lookup 앞으로
호이스트** — resolved 케이스는 동일 gdelta 산술이라 byte-neutral, UND 케이스는 자연 관통.
이후 H1 else는 "kind∉{9} && stub 없음 && def 없음"만 잡음(= kind1 UND, 정당한 잔존 error).
난이도 중(byteeq 회귀 주의 — 기존 elf_ownstart_gotpcrel_test로 검증).

### (E) 신규 serializer `serialize_elf_exec_x86_64_dyn` — :2358 `_2seg` 복제 + 60줄
`(text, data, bss_size, interp_off, interp_len, dyn_off, dyn_sz)` 시그니처.
phnum=4 → code_off=64+56*4=**288**. phdr 순서: **PT_INTERP · PT_LOAD(R-X) · PT_LOAD(RW) ·
PT_DYNAMIC** (관례; kernel/ld.so 모두 순서 비강제. PT_PHDR 불필요 — ET_EXEC은 AT_PHDR로 충분).
- PT_INTERP: p_offset=data_file_off+interp_off, p_vaddr=data_vaddr+interp_off,
  p_filesz=p_memsz=interp_len, p_flags=PF_R, align=1.
- PT_DYNAMIC: 동형으로 dyn_off/dyn_sz, p_flags=PF_R|PF_W, align=8.
- 나머지는 _2seg 그대로. `_2seg`는 무변경 보존(정적 경로 byte-identical).
ownstart 쪽: `let phnum = if n_dyn > 0 { 4 } else if has_data { 2 } else { 1 }` (:1741),
serialize 분기 :1968에 3번째 arm. 난이도 하(기계적).

### (F) own-start stub 확장 — :1576-1586 (correctness rung — MVP 직후 필수)
dynamic glibc를 `__libc_start_main` 없이 쓰는 데서 오는 2개 구멍:
1. **environ**: glibc의 `environ`은 __libc_start_main이 채움 — 우리는 안 부르므로 NULL.
   runtime.a가 environ을 GOTPCREL로 직접 읽는 이상 **stub이 envp를 계산해 libc environ에
   store**: `mov rax,[rsp]; lea rdx,[rsp+8+rax*8+8]; mov rcx,[rip+environ@GOTslot]; mov [rcx],rdx`
   (~18B, environ 슬롯 재사용).
2. **exit 라우팅**: 현 syscall-60 직행은 stdio flush/atexit 미실행 → buffered 출력 유실.
   `mov edi,edx; call exit@stub` (exit도 UND 집합에 이미 있음)로 교체. syscall 폴백은 exit
   미반환 보증이라 불필요하나 `hlt` 1B 방어 가능.
대안(canonical-max): crt1 계약 그대로 `__libc_start_main(main_shim, argc, argv, 0, 0, rdx)` —
단 emitted main이 HexaVal(payload=edx) 반환이라 **eax≠exit-code 문제** → `main_shim: call main;
mov eax,edx; ret` 셰임 필요. glibc 초기화 완전 커버리지가 장점이나 rung-4 optional로 미룸
(ld.so가 libc.so.6의 __libc_early_init+DT_INIT을 이미 돌려주므로 malloc/stdio/dlopen은
직행-call 모델로도 초기화됨).

## ③ rung 순서 (최소 실행가능 경로 우선)

- **rung-1 (MVP — 위 A~E 한 덩어리·분리 불가·~300줄)**: dyn census + stub 합성 + GOT/GLOB_DAT
  + dynsym/dynstr/hash/rela.dyn/_DYNAMIC/interp append + phnum=4 serializer + kind==9 호이스트.
  검증: pod에서 micro .hexa(println+strlen 경유 libc 도달) → `readelf -dlr` → 실행 →
  `ldd` 정합. 기존 정적 테스트(exit_code/hello_str/gotpcrel) byte-identical 확인.
- **rung-2**: stub environ-store + exit@libc 라우팅 (getenv·flush correctness).
- **rung-3**: cc-self-bin 실전 run + fallout. **선행 프로브(pod 1줄씩)**:
  `nm -D libc.so.6 | grep -w -e atexit -e __stack_chk_guard` —
  (i) `atexit`은 libc.so.6에 compat-version으로만 있을 가능성(정상 static link는
  libc_nonshared.a에서 얻음) — unversioned UND가 바인딩되는지 실측; 실패 시 runtime 자체
  atexit(hxlcl) 또는 __cxa_atexit 위임 rung.
  (ii) `__stack_chk_guard`는 x86_64 glibc 비수출(fs:0x28 방식) — 진짜 UND로 관측되면
  **linker가 local 8-byte bss 슬롯 합성**(양쪽 동일값 read라 semantics 보존) 또는 runtime.a
  재빌드 시 -fno-stack-protector.
- **rung-4 (optional)**: __libc_start_main crt1 계약(+main_shim) · GOT per-(obj,name) dedup
  (기존 :1924-1927 명시 latent) · data-site R_X86_64_64 dyn reloc(관측 시).

## ④ 위험/난이도 총평
| 요소 | 난이도 | 위험 |
|---|---|---|
| A census + C GOT 확장 | 하 | 낮음 (기존 루프 복제형) |
| B stub 합성+fill | 하 | 낮음 (disp32 산술 단일점) |
| D kind==9 호이스트 | 중 | **byteeq 회귀 주의** — resolved-경로 바이트 불변 증명 필요 |
| E serializer 4-phdr | 하 | 낮음 (신규 fn, 기존 보존) |
| dynsym/hash/dynamic emit | 중 | DT_HASH 누락·r_info 패킹(idx<<32) 오류가 전형 함정 |
| F stub environ/exit | 중 | glibc-init 미묘점 — 실측으로만 확정 (atexit/guard 프로브 선행) |

버전 심볼(DT_VERNEED)은 미발행 — unversioned UND는 default version에 바인딩(glibc 규약),
cc-self-bin의 UND 집합엔 충분. musl/비-glibc pod는 interp 경로부터 다름 — Ubuntu pool 전제.
