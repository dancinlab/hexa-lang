# axis-③ own-link ABI 스큐 — 근인확정: STB_LOCAL `hxlcl_` 바디에 bare libc UND 를 alias

**결론 한 줄:** #4952 가 남긴 "ABI 스큐의 정확한 방출 file:line 미확정" 잔여를 닫는다.
근인 = **`compiler/emit/elf_x86_64.hexa:2399` (A0) FLOOR-NAME ALIAS** 가 bare libc UND `<X>` 를
**STB_LOCAL** `hxlcl_<X>` 바디에 alias 하는 것. **local 심볼의 ABI 는 private 이라 alias 대상이 될 수 없다.**

---

## 1. 근인 (file:line)

`compiler/emit/elf_x86_64.hexa:2399-2434` — 링커가 runtime.a 추출 후 남은 bare libc-floor UND `<X>`
(malloc/free/memcpy/write/**mmap**/…)를 같은 이름의 own 바디 `hxlcl_<X>` 에 **GLOBAL alias** 로 묶는다.
주석 스스로 대상이 **STB_LOCAL** 임을 밝힌다:

> `hxlcl_<X>` in a pulled member (**STB_LOCAL**, so section != 0 puts it in def_names/ldx but a
> bare-name reloc never binds to it) … Register a linker-synthetic GLOBAL ALIAS for the bare name
> at the SAME seg/off as the hxlcl_ body

**그 전제가 틀렸다.** `static` 함수는 internal-linkage 라서 C 컴파일러가 **호출규약을 합법적으로 다시 쓸 수 있다**
(IPA constant-arg elimination). 오브젝트 내 모든 호출부가 어떤 인자를 상수로 넘기면 그 파라미터를 **삭제**한다.
그러면 선언된 C 프로토타입은 **방출된 바디에 대해 아무것도 말해주지 않는다.**

## 2. 실제로 무슨 일이 벌어지나 (디스어셈블)

`hxlcl_mmap` 은 runtime.o 에서 `static`(nm: `t`)이고, **오브젝트 내 호출부 2곳이 전부 `addr=NULL`·`off=0`** 을
넘긴다 → clang 이 두 인자를 지우고 **4-인자 바디**를 방출:

```
hxlcl_mmap:                      ; f(len, prot, flags, fd)
  mov    %rdi,%r9                ; r9  = len   (a0)
  mov    %edx,%r10d              ; r10 = flags (a2)
  movslq %ecx,%r8                ; r8  = fd    (a3)
  mov    %esi,%edx               ; rdx = prot  (a1)
  mov    $0x9,%eax               ; SYS_mmap
  xor    %edi,%edi               ; addr = NULL   ← 하드코딩
  mov    %r9,%rsi
  xor    %r9d,%r9d               ; off  = 0      ← 하드코딩
  syscall
```

한편 **`hxlcl_shim.o` 는 `U mmap`** 을 들고 있다 — 진짜 **6-인자 libc mmap**. 호출자는 `hxheap_alloc`
(FLIP-6 RT-HEAP-NATIVE), 표준 6-인자 규약으로 세팅한다:

```
410c34: mov  $0x400000,%esi      ; len   = 4194304   (rsi)
410c39: xor  %edi,%edi           ; addr  = NULL      (rdi)
410c3b: mov  $0x3,%edx           ; prot  = 3         (rdx)
410c40: mov  $0x22,%ecx          ; flags = 0x22      (rcx)
410c45: mov  $0xffffffff,%r8d    ; fd    = -1        (r8)
410c4b: xor  %r9d,%r9d           ; off   = 0         (r9)
410c4e: call 0x44bafb            ; → 4-인자 hxlcl_mmap  ★ 여기가 스큐 발생점
```

4-인자 바디가 `rdi`(=addr=NULL)를 **len** 으로, `rsi`(=len)를 **prot** 으로, `rdx`(=prot)를 **flags** 로,
`rcx`(=flags)를 **fd** 로 읽는다 ⇒ 인자가 **한 칸씩 밀린다**:

```
의도:  mmap(NULL, 0x400000, 3, 0x22, -1, 0)
실제:  mmap(NULL, 0, 0x400000, 3, 34, 0) = -1 EBADF
```

반환된 `-1`/NULL 을 무검사로 써서 zero-fill 저장 루프가 NULL 을 통해 쓴다
(`mov %r8,(%rax,%rsi,8)`, rax=0) → **SIGSEGV si_addr=NULL**. #4952 가 잡은 폴트 시그니처와 정확히 일치.

### 왜 `ld` 는 멀쩡했나
**STB_LOCAL 정의는 다른 오브젝트의 UND 를 만족시킬 수 없다** (ELF 규칙). 그래서 `ld` 는 `mmap` 을
`mmap@plt`(glibc)에 바인딩한다 — 6-인자 ABI 그대로. own-link 만 이 alias 를 강제한다.

### 정량 증거 (같은 프로그램, 링커만 다름)
`gdb catch syscall mmap` 으로 mmap 호출을 전수 포집:

| | mmap 호출 | 결과 |
|---|---|---|
| **ld** | 2회, 전부 `len=0x400000 prot=3 flags=0x22` | 정상 |
| **own-link (수정 전)** | 4회 — **전부 같은 rip(0x44bb15)**: 2회 정상(4-인자 호출자) + **2회 쓰레기**(6-인자 호출자) | SIGSEGV |

한 바디에 **호출규약이 다른 두 호출자**가 묶였다는 직접 증거다.

## 3. 수정

**STB_GLOBAL `hxlcl_<X>` 바디에만 alias 한다.** export 된 심볼은 컴파일러가 호출자를 알 수 없으므로
**선언된 C ABI 를 반드시 지킨다** — 이 alias 가 의존하는 바로 그 성질이다.

```hexa
if oix >= 0 && def_bind[oix] != ELF_STB_GLOBAL { oix = -1 }
```

**영향 범위 (실측 census, 배포 runtime.a):**
- `hxlcl_*` 바디 **GLOBAL 63개** → alias 유지 (bug3 의 static-exec 이득 보존)
- bare UND 로 실제 참조되는 **LOCAL-only 이름 7개** = `{mmap, exit, fclose, fdopen, fwrite, getpid, gmtime_r}`
  → alias 제거 → `ld` 와 **똑같이** libc 로 라우팅. `mmap` 이 이번에 터진 것이고, **나머지 6개는 같은 계열의
  잠복 위험**(clang 이 언제든 특수화할 수 있다)이었다.
- staticness 손실 **없음**: own-link 바이너리는 **이미 PT_INTERP 를 달고 있다**(dynamic). 즉 이 7개를
  dyn 라우팅해도 잃을 static 성질이 애초에 없다.
- C-2 near-miss tripwire 는 `hexa_array_/hexa_str_/hexa_map_/rt_str_` 복합변형이 있는 이름만 거부하는데
  이 7개는 해당 없음 → 안전하게 통과.

## 4. behavioral 게이트 (링크된 바이너리를 실제 실행)

같은 트리·같은 커밋, **own-link 경로**(`HEXA_OWNLINK_DEFAULT=1`):

```
수정 전: hello-world      → Segmentation fault (rc=139)
         aggregate        → rc=139, 출력 0바이트, execve 1개(자식 0)

수정 후: hello-world      → out='hi'                              ← 크래시 소멸
         strace           → mmap(NULL, 4194304, PROT_READ|PROT_WRITE,
                                 MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)  ← 인자 정상
         aggregate        → rc=1, found=94 pass=76 fail=1 timeout=17  ← 실제로 돈다
```

## 5. 정직한 잔여

- **hello-world 의 `rc=2`** — 출력은 `hi` 로 맞는데 exit code 가 2다. **양쪽 링커에서 동일**
  (`ld: out=hi rc=2` · `own-link: out=hi rc=2`) ⇒ **선재결함이며 링커와 무관**. 이 PR 범위 밖, 별도 rung.
- **aggregate 의 timeout 17** 은 부하 아티팩트(측정 시 aiden load 4.5~6.5, 하니스 캡은 테스트당 30s).
  ld 경로도 한산할 때 timeout 2였다. 크래시 소멸이 이 PR 의 주장이고, 통과율은 주장하지 않는다.
- **own-link default-ON 재승격은 이 PR 이 하지 않는다.** #4952 의 강등을 유지한다 — 재승격은
  **링크된 바이너리를 실행하는 behavioral 게이트**가 CI 에 들어간 뒤에 별도로 판단할 일이다
  (byteeq/corpus-parity 는 링커의 방출 바이트만 비교해서 이 결함을 4개 게이트가 전부 놓쳤다).
