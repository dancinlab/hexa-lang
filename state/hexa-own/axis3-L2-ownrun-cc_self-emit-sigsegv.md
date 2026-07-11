# axis-③ L2 own-run 정합성 측정 — cc_self emit-path SIGSEGV (measured wall)

summer, HEAD 8765f524, Fable L2 rung recipe (state/hexa-own/axis3-L2-ownrun-correctness-rung-plan.md).

## 결과 (measured)
- **Step 0** build_native rc=0: cc_native(clang-built)+cc-flat.hexa 생성·stage5 print `[hi] rc=7`(print-flip 확인).
- **Step 1** own-emit+own-link cc_self(full compiler): **rc=0·ENCODE-MISS=0**·**cc_self 4.9MB dynamic ELF EXEC 생성**·RSS **19.38GB**(19.87GB 프론트엔드벽 아래·fit)·wall 69s. (스크립트 오판: cc_self 0644 exec비트 없음=알려진 own-emit chmod 이슈, 파일은 정상.)
- **cc_self RUNS**: `--help` rc=0 → "hexa-compiler — native compiler driver (RFC-018)" 출력 = **own-emit 컴파일러 살아있음+CLI 작동**.
- **Step 2** 정합성: cc_native emit hi.hexa .o rc=0(1072B) vs **cc_self emit `--emit=obj` SIGSEGV(rc=139·코어덤프)** → DIVERGE.

## 벽 (measured)
**own-emit+own-link한 full 컴파일러는 빌드·실행되지만, 자기 native-emit 경로 실행이 miscompile → SIGSEGV.** = axis-③ default-flip의 RUN-correctness 벽.
- 크래시 @0x816012 (.text 내·own-emit 명령)·gdb bt: `#0 0x816012 · #1 0x3`(**garbage return addr=스택손상/bad indirect call**).
- cc_self stripped(nm=0)·objdump own-emit ELF disasm 불가 → 함수 특정 불가(현 툴링).

## 가설 (mechanism-families·Fable watch)
스택손상 시그니처(#1=0x3 garbage return)가 **try/catch setjmp** 클래스와 강하게 일치(memory project_hexa_native_trycatch_setjmp_defect: longjmp pool-reg rollback+torn). 후보 순위: ①try/catch setjmp ②HexaVal boxed ABI/string-print ABI(N5) ③multi-fn-alias ④i64→BigInt ⑤own exit-path.

## 다음 rung (근인)
symbol-emit own-emit 빌드 or cc_native 함수레이아웃 매핑 or fixture bisect로 0x816012→소스함수 특정→miscompile class 확정→codegen fix. measurement-only(opt-in·shipping 무변경).

## ★근인 확정 (gdb fingerprint + source — 가설 try/catch 반증)
- **faulting insn @0x816012 = `movdqa 0x8d3b5(%rip),%xmm0  # 0x8a33cf`** (직접 $pc·gdb 메모리 disasm). movdqa = 16-byte ALIGNED SSE 로드. target 0x8a33cf & 0xf = 15 (홀수·미정렬) → **정렬폴트 SIGSEGV**.
- (Fable 정정: cc_self e_shnum=0·CFI無라 gdb #1=0x3 garbage frame는 날조=스택손상 근거 약함. 하지만 movdqa fingerprint는 직접 faulting insn이라 견고.)
- **SOURCE 확정**: elf_x86_64.hexa:2534 `.rodata follows .rela.text, 8-aligned (string literal pool)` · :2537 `.data ... 8-aligned`. own-emit이 rodata를 **8-byte 정렬**·movdqa는 **16 필수** → SSE 16-byte 상수 미정렬. clang/system-ld는 sh_addralign=16 준수(cc_native 작동)·own-emit 8-align(cc_self 폴트).
- 0x8a33cf가 홀수 = rodata 풀이 개별 상수를 패킹(섹션시작만 8-align·상수별 padding 없음).

## fix 방향 (next-session first move)
own-emit ELF의 rodata 풀에서 **SSE 16-byte 상수(movdqa/movaps operand)를 개별 16-byte 정렬**(emit 시 16-align padding). 단순 섹션 8→16 정렬 아님(개별 상수 정렬 필요). 사이트=compiler/emit/elf_x86_64.hexa rodata 풀 emit(:2534 근처)+own-link vaddr 배치(:2011/2828 page-align은 OK). 검증=re-emit cc_self→L2 step-2(cc_self emit==cc_native emit byte-id)+own-link determinism gate(#4854). measurement-only(own-emit opt-in·shipping 무변경). ★codegen 설계=Fable 위임 후보(SSE 16-align 상수풀 mechanism).

## ★★근인 REFINED (fix 사이트 정밀특정 — 이전 :2534 정정)
- own-emit codegen은 **movdqa 생성 안 함**(elf_x86_64.hexa/self/codegen grep=0·:1290/1300은 movd 스칼라). → **movdqa는 clang-compiled runtime.a**(memcpy/struct-copy/SSE)에서 옴 → own-LINK이 미정렬 배치. = Fable A/B의 **branch A(own-LINK 버그)** 확정.
- **정확한 fix 사이트 = elf_x86_64.hexa:1660** `link_elf_x86_64_ownstart` merge loop:
  ```
  let ro_base = len(data_bytes)   // ← 16-align 없음
  obj_rodata_base.push(ro_base)
  while rri < len(obj.rodata) { data_bytes.push(obj.rodata[rri] & 0xff); ... }
  ```
  각 obj rodata를 이전 blob 끝에 그냥 append → 첫 obj는 data_vaddr_base(page-align=16OK)·후속 obj는 미정렬 → clang .rodata.cst16(16-align 요구·movdqa operand) 미정렬 → 정렬폴트.
- **fix**: obj rodata append 전 `while (len(data_bytes) & 15) != 0 { data_bytes.push(0) }` (16-align ro_base). (nuance: obj.rodata blob 내 cst16 offset이 16-align인지=.o reader가 .rodata.cst16 sh_addralign 보존하는지 확인 필요 — Fable 설계중.)
- 검증=re-emit cc_self→L2 step2(no SIGSEGV·byte-id)+own-link determ gate(#4854). measurement-only(own-emit opt-in).

## ★★★Fable 설계 확증 (2-site 보강 · pid 76693 완료)
근인 = own-LINK이 clang runtime.a member의 .rodata.cst16(sh_addralign=16·movdqa operand)을 미정렬 배치. **2개 풀링 사이트가 sh_addralign 드롭**:
1. parse_elf_x86_obj Pass A(:3117-3134): .rodata/.str1.1/.cst16 back-to-back 풀링·sh+0x30 안 읽음→obj.rodata 내부 cst16 offset 홀수 가능.
2. link_elf_x86_64_ownstart concat(:1663/:1667): ro_base/da_base = len(data_bytes) raw append·own-emit 홀수길이 string pool이 후속 clang member parity 밀어냄.
.o writer 8-align(:2534)은 무관(own-emit .o엔 SSE 상수 없음·in-memory pack_lir obj 소비). 세그먼트 congruence는 이미 OK(:2016 page-align).
**fix = sh_addralign honor, 4 edit (linker-side only)**:
- E1 struct ElfX86Obj(:77): +rodata_align/data_align/bss_align (min1)
- E2 parse_elf_x86_obj(:3060 literal +Pass A): 필드 1 init·salign=clamp(_er_u64le(buf,sh+0x30),1,4096)·각 풀 pbase 전 pad·max 추적 (slot3/4/5)
- E3 pack_lir_x86_64(:4234 literal): rodata/data/bss_align=8 init
- E4 concat loop(:1663/:1667/:1671): data_bytes를 obj.*_align로 pad 후 ro_base/da_base·bss pad는 +obj.bss_size 전·+dyn-blob 후 ~:2130 16-pad(bss base 16-align, movaps 정적 bss)
검증(summer/aiden): pre-fix objdump movdqa+cst16 probe→fix후 objdump awk(movdqa target %16==0)·cc_self emit no-SIGSEGV·hi_self.o==hi_native.o(cmp)·#4854 gate GREEN(ET_EXEC bytes 1회 shift·결정론적). class=measurement-only(opt-in·no shipping bytes·byteeq-3-target 의무 없음).

## ★★★★ verdict-integrity 대반전 — cc_self own-emit는 2개 STACKED base 블로커 (2026-07-11)
summer 실측(fix 브랜치 + origin/main baseline 둘 다):
1. **`free` tripwire (선재 base 블로커·BASELINE 확증)**: own-emit cc_self가 rc=3로 실패 —
   `hexa_ld(elf,ownstart): codegen-runtime sym mismatch: UND 'free' — runtime.a defines 'hexa_array_free' (missing _builtin_runtime_sym entry)`.
   근인=유저 `fn free`(compiler/free/free.hexa discovery verb)를 **네이티브 own-emit이 gen2의 u_ 맹글 없이 bare `free`로 emit**. gen2 C-path는 self/codegen.hexa `_hexa_name_is_reserved`(:11 free/malloc/…)→`_hexa_mangle_ident`(:244 `"u_"+name`) def(:1737,:3423)+ref(:695) 적용→`u_free` 내부해석. 네이티브 초크포인트 `_fmt_label`(asm.hexa:147)은 `_`접두만·`u_`없음·x86 ELF은 passthrough→bare `free` 누출. stale runtime.a(hexa_array_free 부재)에선 libc free로 (오)라우팅=잠재 miscompile→링크됨; fresh runtime.a에선 guard C-2가 refuse.
   → **내 이전 L2 "cc_self builds+runs+SIGSEGV" 측정은 STALE runtime.a 아티팩트**(verdict-integrity 대단서). movdqa SIGSEGV는 그 오라우팅 이후 도달.
   → 이건 **내 정렬 수정과 완전 독립**(baseline=origin/main 동일 실패로 확증). Fable 설계 위임(fable_free_mangle.md·pid 48515): 네이티브 reserved-name 맹글 단일 초크포인트+byteeq 스코프.
2. **movdqa/rodata-align (내 수정·fix/axis3-l2-rodata-align push됨)**: (1) 클리어돼야 도달. 독립검증=#4854 rt_pull 픽스처(유저 free 無)로 determinism gate GREEN+movdqa %16==0 (summer align-verify 진행중).
크리티컬패스 순서: **①`free` 네이티브 맹글 fix → cc_self 링크 → ②정렬 fix로 movdqa SIGSEGV 소멸 검증**.

## 정렬 fix 독립검증 = INCONCLUSIVE (rt_pull 너무 작음·2026-07-11)
summer align-verify(fix 브랜치): ✓ #4854 T1 emit-twice byte-identical(내 parse/pack 변경 결정론적·회귀 없음). ✗ own-linked rt_pull의 movdqa-total=0 — rt_pull 픽스처가 movdqa-bearing clang member(memcpy/memset SSE)를 안 당김→정렬 fix 효과 노출 불가. (gate rc=2·rt_pull run 126은 내 스크립트 CWD/exec-perm 아티팩트·infra-neutral.)
→ **정렬 버그 유일 신뢰 repro=full cc_self**(movdqa @0x816012). 즉 `free` 블로커를 뚫어 cc_self를 빌드해야 정렬 fix도 최종검증 가능. 크리티컬패스=`free` 맹글 fix 우선.

## ★★★★★ verdict-integrity #3 — `free` tripwire = STALE runtime.a 아티팩트 (2026-07-11·측정확정)
summer nm 전수조사로 근인 3번째 반전:
- own-link이 당기는 runtime.a = **`~/.hx/bin/build/runtime.a`(설치본·STALE)** — bare `U free` **2개**(clang libc free 호출·size 3460388·CUDA포함).
- **fresh `build/runtime.a`**(내 build_native 산출) = **`U free` 0개**(size 1608594·free를 hxlcl_free/__libc_free로 라우팅).
- cc-flat.o도 fresh runtime.a도 bare free reloc **전무**(objdump -r 확증) → tripwire의 `free`는 오직 stale ~/.hx runtime.a에서.
- 즉 **`free` 조사 전체(cc-flat 유저fn free 가설 포함)가 stale-runtime.a 오라클 착시**. guard C-2 tripwire는 정상(stale runtime.a의 bare free를 hexa_array_free near-miss로 잡음)이나 입력이 stale.
- **내 verify 스크립트 버그**: `HEXA_PREBUILT_RUNTIME` 미설정 → own-link이 stale ~/.hx 당김. 우회=`HEXA_PREBUILT_RUNTIME=$PWD/build/runtime.a`(메모리 pool_cuda_ssl_link_deadlock 기지).
- **fix/axis3-l2-ufree-mangle(내 codegen 맹글)**: 유저 fn free→u_free는 정확 작동(uf.hexa 검증 T u_free·call u_free·reloc u_free)이나 **cc-flat은 free 미사용(DCE) → L2 unblock 아님**. 실재하는 별개 latent-bug fix로 보존하되 "L2 unblock" 주장 철회.
- **진짜 L2 경로**: fresh runtime.a로 own-link → tripwire 소멸 → cc_self 빌드 → movdqa 정렬 fix(fix/axis3-l2-rodata-align) 검증. (confirm=bg bdn1gz115)

## ✅ L2 완전 규명 — 2블로커 분리 확정 (2026-07-12·fresh runtime.a)
HEXA_PREBUILT_RUNTIME=$PWD/build/runtime.a(fresh)로 own-emit cc_self:
- cc_self own-emit rc=0·5MB·tripwire 라인 0 → **`free` 블로커=stale runtime.a 아티팩트 확정**(fresh는 U-free=0).
- cc_self --help rc=0 → 실행됨.
- cc_self /tmp/hi.hexa --emit=obj → **RC=139 SIGSEGV 재현**(정렬fix 없는 ufree-branch 빌드) → movdqa 정렬버그=진짜 L2 correctness 버그·moot 아님.
- cc_native(레퍼런스) --emit=obj → rc=0·hi_native.o 1072B.
→ 2블로커: ①`free`=stale runtime.a(HEXA_PREBUILT_RUNTIME=fresh) ②movdqa=rodata-align fix. 이제 clean repro로 정렬 fix 최종검증 가능.
주의: 이전 진단의 rc=0은 `| tail`이 tail의 rc를 잡은 아티팩트(파이프 없이 RC=139).

## ✅✅ movdqa SIGSEGV 종결 + byte-eq 19B 발산 발견 (2026-07-12·summer)
fix/axis3-l2-rodata-align cc_native + fresh runtime.a로:
- own-emit cc_self rc=0·5MB·실행 --help rc=0.
- **cc_self --emit=obj hi.hexa RC=0** (이전 139 SIGSEGV) → **내 rodata-align fix가 movdqa #GP 종결** ✅ (own-emit cc_self가 emit 경로 완주).
- 단 hi_self.o(1056B) ≠ hi_native.o(1072B): 발산=**.text만**(self 0x61=97B vs native 0x74=116B·19B차·.rodata/symtab/rela 동일). → own-emit cc_self가 cc_native와 다른 기계코드 생성.
- 내 align fix=own-LINK(link_elf_x86_64_ownstart)만·.o writer(:2534) 불변 → 19B .text 차는 **선재 self-host 발산**(SIGSEGV가 가려옴). cc_native=gen2-C빌드 vs cc_self=native빌드 = 알려진 2-backend path-mismatch(project_hexa_codegen_two_backend_path_mismatch).
→ ✅ SIGSEGV rung 종결(rodata fix 머지 대상·measurement-only·byteeq CI 게이트). ⚠️ 다음 rung=19B .text byte-eq 발산 root-cause(Fable 위임).

## byte-eq 19B 발산 = 레지스터 할당 차이 → gen2≠gen3 재프레이밍 (2026-07-12)
objdump 디스어셈블: cc_self(27insn·regalloc 레지스터유지·mov %rdx,%rbx·스택슬롯無) vs cc_native(31insn·스택스필 -0x38/-0x40·sub $0x10,%rsp·%r12). 둘다 유효코드·발산=.text regalloc만.
★재프레이밍: cc_native=**gen2**(C-transpile빌드)·cc_self=**gen3**(native빌드). 부트스트랩서 gen2≠gen3는 정상(진짜 fixpoint=gen3≡gen4). 19B 차는 알려진 2-backend path-mismatch(project_hexa_codegen_two_backend_path_mismatch)일 수 있음=버그 아님.
→ 올바른 L2 게이트=gen3≡gen4(cc_self로 cc_self2 재own-emit→byte-id?). Fable 위임(fable_byteeq_rung.md·pid TBD): gen2≠gen3 benign 판정 + gen3≡gen4 recipe. PASS면 movdqa fix(#4864)+gen3≡gen4로 L2 own-run-correctness 종결.

## L2 fixpoint 판정 = case(ii) OPEN — cc_self own-emit miscompile (env/runtime-resolution) (2026-07-12·gen-ladder)
Fable gen-ladder recipe 실측(summer·fresh runtime.a):
- C1 semantics: SEM-OK cc_native(hi·rc7) / **SEM-FAIL cc_self**(exec 미생성·rc127).
- GEN4(cc_self→cc_self2): rc=1·ENCODE-MISS=0·MaxRSS 8.7GB(OOM아님)·cc_self2 미생성.
- 실패사유(verdict-integrity로 확인): `FATAL - no runtime.a found; set HEXA_PREBUILT_RUNTIME` — **cc_self가 HEXA_PREBUILT_RUNTIME export를 무시**(cc_native는 존중)+atlas 경로 `/core/hexa-lang`(summer 아님·baked). = cc_self의 env/runtime-resolution/string-handling 경로가 own-emit **miscompile**(Fable 판정 case ii·flag/env-parse 의심 적중).
- 즉 cc_self는 --emit=obj는 되나(19B .text 발산) --emit=exec은 env결함으로 불가 → own 계보 fixpoint 도달 못함.
★L2 판정: SIGSEGV rung=movdqa fix #4864 머지로 종결✅. **fixpoint/byte-eq rung=OPEN**(cc_self env-handling miscompile). 다음(멀티세션)=cc_self의 HEXA_PREBUILT_RUNTIME/env-var 읽기 miscompile root-cause(gen2-C vs native codegen 차·2-backend path-mismatch)→고치면 gen4≡gen5 재판정. 부수확인=hi_self.o를 작동링커로 링크+실행해 19B emit 정합성 격리테스트(미실시).

## ★★★★★★ L2 근인 CONFIRMED — native env() TAG_STR 드롭 (2026-07-12·workflow+최소repro)
워크플로우 wf_87f56dd2-28d 3-finding 수렴 + 최소 repro 확증:
- 근인 = **네이티브 백엔드가 env()(hexa_env_var) 반환 HexaVal의 TAG_STR(3)를 드롭** → env() 모든 키에 빈문자열 반환. builtin-call return-unbox가 result local에 tag-slot 없으면 _x86_store_tag_reg no-op(off<0 return)→읽을때 TAG_INT=0 default→string이 int로 오독→빈값.
- 최소 repro(summer·~2초): HOME=/home/summer인데 `fn main(){print(env("HOME"));print(len(env("HOME")))}` native-emit exec 실행→출력 "0"(빈+len0). **19GB cc_self 불필요**.
- 증상 연쇄: self/main.hexa:3307 `env("HEXA_BACKEND")`, resolve_prebuilt_runtime `env("HEXA_PREBUILT_RUNTIME")`, atlas static_index.hexa:104 `env("HOME")+"/core/hexa-lang/"` → 전부 빈값 → cc_self가 runtime.a 못찾음+atlas `/core` 경로. 19B .text 발산=BENIGN(둘다 hi/rc7·regalloc 차·워크플로우 링크+실행 확인).
- gen2-C 면역(C HexaVal struct {tag,payload} 분리불가). 동류=x86:3086 global-tag-persist fix(cross-fn read TAG_INT=0)의 call-result 판.
- fix 위치(워크플로우 근사)=compiler/codegen/x86_64_linux.hexa builtin-call return-unbox tag store(_x86_store_tag_reg) + tag-slot 할당(_x86_tag_off)이 string-returning builtin result에 off<0 안되게. Fable에 정밀 fix 위임 예정.

## ★★★★★★★ 근인 정정 (verdict-integrity 3중) — own-start `environ` 미populate (2026-07-12)
워크플로우의 codegen tag-drop 이론을 디스어셈블로 FALSIFY→진짜 근인 도달:
- 디스어셈블(최소 repro et.o main): env() 반환 rax:rdx가 -0x38/r12 경유 print rdi(tag)/rsi(payload)로 **정상 threaded**(tag 드롭 아님). 워크플로우 finding#2(tag-slot no-op) FALSIFIED.
- hexa_env_var(name:string)->string(self/rt/proc.hexa:146)=정상 HexaVal ABI·runtime.a에 T 정의. hxlcl_getenv=**`environ` 전역 직접 walk**(zeroc_hxlcl_delegate_emit:189+disasm `mov (%rip),%rbx`).
- own-start _start stub(elf_x86_64.hexa:1553·23-byte)=`mov rdi,[rsp]`(argc)+`lea rsi,[rsp+8]`(argv)만 캡처, **envp/environ 미설정**. → own-start 바이너리는 crt(__libc_start_main) 없어 environ uninit → hxlcl_getenv 모든키 빈값.
- cc_native=crt-linked라 environ 정상→env 읽음. cc_self/own-start=environ 미populate→env 빈값=L2 블로커.
- 연결: flip7_flipd_BLOCKED_environ_multiobj(environ 심볼 undefined·link)와 관련되나 별개 facet(내것=런타임 populate 미비).
★정정 근인 = **own-start _start가 initial-stack envp를 environ 셀에 populate 안 함**. fix=stub이 argc 읽어 envp offset([rsp+8+(argc+1)*8]) 계산→environ 전역 store. codegen tag-slot과 무관(#4864 movdqa fix만 유효). Fable 정밀설계 재위임(correct premise).

## ✅✅✅ environ fix VERIFIED + gen4 next-rung=atlas-embed (2026-07-12·summer)
fix/axis3-l2-ownstart-environ 검증:
- ★ Test1 env(HOME)=>'/home/summer'·env(FOO=barbaz)=>'barbaz' — **own-start env() 작동**(이전 빈값). runtime.a _hxlcl_environ=B 확인.
- Test2 exit-code fn main(){return 42}=>42 — regression OK.
- cc_self own-emit rc=0·cc_self --emit=obj rc=0 — env 읽혀 /core 차단 해소.
- ⚠️ gen4(cc_self→cc_self2·full cc-flat) rc=1: `atlas: no nodes at /home/summer/core/hexa-lang/...`($HOME 이제 정상해석되나 atlas embed 기본경로 $HOME/core/hexa-lang가 summer 체크아웃 아님→empty atlas)→하류 `array[0]: container is not an array(tag=12)`. MaxRSS 8.8GB(OOM아님).
→ environ fix=검증완료·머지대상(env 작동+cc_self emit·byteeq CI 게이트). **다음 rung=cc_self atlas embed 미로드**(embedded.gen.hexa rodata 미탑재 or embed-path 감지실패→$HOME/core/hexa-lang 파일폴백). gen4≡gen5 L2 close는 atlas-embed rung 후.

## L2 잔존 rung = cc_self atlas-parse miscompile (2026-07-12·genclose 정정)
HEXA_ATLAS_EMBED=$PWD/compiler/atlas 설정 후 재측정: 경로는 정확(/home/summer/hexa-lang/compiler/atlas/embedded.gen.hexa·존재·cc_native가 17265노드 로드)이나 **cc_self는 "no nodes parsed — serving EMPTY index"**(0노드 파싱)→하류 `array[0]: container is not an array(tag=12)`→gen4 rc=1.
→ test-env 갭(경로)은 해소됐으나 **진짜 cc_self own-emit miscompile 잔존**: static_atlas() text-parse(compiler/atlas/static_index.hexa·embedded.gen.hexa를 read_file후 const-array/string 파싱)가 cc_self에선 0노드 산출. cc_native(gen2-C)는 정상 17265. = case(ii) genuine own-emit codegen miscompile in the atlas-parse path.
잔존 resume: cc_self가 embedded.gen.hexa(~9.7MB)를 파싱하는 코드(static_index.hexa static_atlas/_unescape_hx/const-array reader)의 어느 construct를 gen2-C와 다르게 컴파일하는지 root-cause. 최소repro=cc_self로 작은 embedded.gen.hexa fixture 파싱→노드수 0 vs cc_native. 후보=대형 string const/array-of-struct 파싱·index_of jumps·substring. movdqa #4864+environ #4868은 종결·이게 gen4≡gen5(L2 close) 앞 마지막 알려진 rung.

## ★ bisection 종착 — cc_self `read_file` 전면 파손 (2026-07-12·최종 narrowing)
- cc_self read_file(11MB embedded.gen.hexa) => len 0·rc=1. cc_native => 11265830.
- cc_self read_file(small 24B /tmp/small.txt) => **len 0 + garbage payload(131988287656816)·rc=15**. → large-file 아니라 **어떤 파일에도 read_file이 깨진 HexaVal string 반환**.
- 즉 gen4 실패 체인 = cc_self read_file 파손 → atlas empty(0노드) → `array[0] not an array(tag=12)` → gen4 rc=1.
- read_file는 runtime.a fn(cc_self·cc_native 동일 링크)이므로 body 동일 → 차이는 (a) cc_self가 read_file CALL의 arg/return-string ABI 미스컴파일(env-tag류) or (b) own-start에서 read_file이 쓰는 libc-stdio(fopen/fread) 미초기화(environ류 own-start 갭). garbage payload+len0 = string-return HexaVal 손상 시사.
잔존 resume(멀티세션): cc_self read_file root-cause. (1) read_file impl 확인(self/rt·runtime_emit_full: hxlcl_open/read raw vs libc fopen/fread)→own-start stdio 갭이면 environ류 fix(런타임 init) (2) 아니면 read_file CALL의 string-return codegen 미스컴파일 디스어셈블. own-start runtime 완결성 캠페인(environ #4868가 첫 rung·read_file이 다음). fix후 gen4≡gen5=L2 CLOSE.
이번세션 성과=#4864 movdqa + #4868 environ MERGED(둘다 검증)·L2 근인 read_file까지 bisect.

## ★★★ 근인 razor-sharp (bisect 완료) — cc_self 배열-리터럴-반환 tag 미스컴파일
read_to_end(fd)->[int] (self/rt/io.hexa:70)는 `return [buf, filled]`(2-int 배열 리터럴·buf=포인터int). hexa_read_file이 `result[0]`/`result[1]` 인덱싱. **gen4의 `array[0]: container is not an array(tag=12)`가 정확히 이 result[0]** = cc_self가 `[buf,filled]` 배열-리터럴/반환에 **garbage tag 12(TAG_ARRAY 아님) 부여** → result[0] 인덱싱 실패 → read_file len0+garbage → atlas 0노드 → gen4 rc=1.
= env-tag(#4868 계열) 동류의 native tag-handling 미스컴파일이나 **배열-리터럴-반환** 판. cc_native(gen2-C·struct {tag,payload} 분리불가) 정상.
잔존 resume(멀티세션 frontier=own-emit codegen tag-completeness): cc_self가 `[int]` 배열 리터럴 반환(read_to_end)의 tag를 garbage로 내는 native codegen 미스컴파일 root-cause. 최소repro=`fn f()->[int]{return [111,222]} fn main(){let r=f();print(r[0])}` cc_self native-emit→tag=12? 디스어셈블로 배열-리터럴 tag-store 확인(x86_64_linux.hexa tag-slot·env-tag와 유사 사이트). fix후 gen4≡gen5=L2 CLOSE.
이번세션 종합: #4864 movdqa + #4868 environ MERGED·L2 근인을 read_file→read_to_end 배열-tag까지 razor bisect(측정 8-falsify 연쇄).

## ✅ 근인 CONFIRMED — cc_self 배열-리터럴-반환 미스컴파일 (최소 repro 확보·2026-07-12)
최소 repro(summer·19GB/atlas 불필요): `fn f()->[int]{let x=111;let y=222;return [x,y]} fn main(){print(f()[0]);print(f()[1])}`
- cc_self native-emit(--linker=hexa) 실행 → **빈 출력·rc=0**(f()[0]/[1] 손상).
- cc_native(레퍼런스) → `111222` 정상.
→ **cc_self가 [int] 배열-리터럴-반환을 미스컴파일**(반환 배열이 손상/빈값) 확증. read_to_end의 return [buf,filled]가 이 클래스라 read_file 파손→atlas 0노드→gen4 rc=1(tag=12는 buf=포인터int 문맥의 변종). = L2 own-run-correctness의 CONFIRMED 최종 블로커.
잔존(멀티세션 frontier): 이 최소 repro로 cc_self native-emit 디스어셈블→배열-리터럴 build/return tag+payload 미스컴파일 사이트 root-cause(x86_64_linux.hexa·env-tag #4868 동류 tag-slot 계열)→fix→gen4≡gen5=L2 CLOSE. 빠른 iteration 가능(작은 repro).

## 결정적 cmp — cc_self는 arr.o를 byte-DIFF emit (self-host 부트스트랩 miscompile·2026-07-12)
- cc_self emit arr.o=1376B vs cc_native emit arr.o=1424B → **BYTE-DIFF**(offset 41·48B 작음). cc_native-emit arr exe=111222 정상.
- 즉 cc_self가 arr.hexa(배열-리터럴-반환)를 **다르게(깨진) 기계코드로 emit** = cc_self의 배열-literal codegen이 깨짐. cc_self·cc_native는 같은 native-backend 소스인데 다르게 emit → **cc_native가 cc-flat→cc_self 빌드 시 native-backend의 배열-tag 코드를 미스컴파일**(compiler-miscompiles-itself·self-host 부트스트랩 depth).
- 연결: hi.hexa 19B .text 발산(BENIGN·워크플로우 확인)과 동일 "cc_self≠cc_native emit" 계열이나 arr는 non-benign(깨짐). cc_self가 systematic하게 다른 코드 emit(자기빌드 miscompile), 단순프로그램=benign·배열-리터럴-반환=broken.
워크플로우 wf_d242cb9b-3a6가 disasm으로 offset-41 명령 diff+배열-tag 미스컴파일 사이트 특정 중. fix=cc_native의 native-backend 배열-literal tag codegen(x86_64_linux.hexa) 수정→cc_self 재빌드→arr repro 정상→gen4≡gen5.

## ★★★★ 워크플로우 수렴 — cc_self=miscompiled gen3(aggregate-return in _x86_compute_live_ranges) (2026-07-12·wf_d242cb9b)
3-각 수사 수렴(high-conf):
- 증명: 동일 소스 x86_64_linux.hexa인데 cc_native가 emit한 arr.o=111222(정상)·cc_self가 emit한 arr.o=1376B≠1424B·segfault → **emit이 버그 아니라 cc_self 자체가 miscompiled gen3 바이너리**.
- 단일 상류 부패: cc_self 내부 `_x86_compute_live_ranges`가 **빈 X86Intervals 반환**(ids len 0·:298 def·:492 by-value struct-of-arrays return). → 모든 fn이 len(iv.ids)==0→frame_size=0→degenerate _x86_64_reg_for_local id-modulo fallback(rax/rbx/rcx·tag-slot off<0 no-op)→배열 payload rcx 충돌+return `mov $0x0,%rax`(NULL payload)→segfault.
- 트리거: cc_native가 cc_self 빌드시 aggregate/struct-of-arrays fn-return을 미스컴파일. 단 control(flat-array-return·struct-with-array-return)은 cc_native 정상 실행 → **트리거가 generic aggregate-return보다 좁음**(X86Intervals 특유의 무언가).
- fix 위치(설계): x86_64_linux.hexa:5439(STMT_RETURN pair-return _x86_hv_box_arg rax/rdx)+regmap builder(반환-live temp이 degenerate fallback 대신 real spill home+tag-slot 받게). 설계=#4868 env-tag 선례 미러(payload→rdx·tag→rax·aliasing 없이·payload-first materialize).
잔존 next(멀티세션·pin 우선): **objdump-diff cc_self OWN _x86_compute_live_ranges/_x86_64_assign_regs vs cc_native**로 정확히 drop된 instruction 특정(arr.o만으론 불가·cc_self stripped라 fn 위치 매핑 필요). 그후 source fix→cc_self 재빌드→arr.hexa=111222→gen4≡gen5=L2 CLOSE. 빠른 iteration=arr.hexa(작은 repro).
이번세션 종합: #4864 movdqa + #4868 environ MERGED·L2 근인을 "cc_self가 miscompiled gen3(빈 liveness→degenerate regmap)"까지 razor 수렴(측정 다단 falsify + 3-각 워크플로우).

## ★★★★★ PIN — 네이티브 백엔드 struct-of-arrays-return COMPILE-HANG (최소 repro·2026-07-12)
결정적: `cc_native --backend=native --emit=obj ivrepro.hexa` → **rc=124 COMPILE-HANG**(무한루프). ivrepro=`struct Iv{ids:[i64],starts:[i64]} fn build()->Iv{...loop push...; return Iv{ids:ids,starts:starts}} main{print(build().ids[0])}`(state/hexa-own/l2_ivrepro_struct_of_arrays_return.hexa).
→ **네이티브 백엔드(x86_64_linux.hexa)가 struct-of-arrays 반환에 compile-time 무한루프** = cc_self-특정 아니라 cc_native 자체 native codegen 버그. 단순 array-lit-return(arr.hexa)은 정상(arr_n=111222)이나 struct-of-multiple-arrays 반환은 hang.
= _x86_compute_live_ranges의 `return X86Intervals{ids,starts,ends}`(struct 3-array)와 같은 영역. cc_self가 broadly 파손된 것(빈 liveness→degenerate regmap→모든 array-return segfault/hang)의 상류 트리거.
잔존 next(멀티세션·하지만 극도로 debuggable): summer에서 `gdb --args cc_native --backend=native --emit=obj ivrepro.o ivrepro.hexa` 실행→SIGINT로 무한루프 위치 backtrace→x86_64_linux.hexa의 struct-of-arrays-return regmap/liveness/emit 루프 특정→fix→cc_self 재빌드→arr.hexa=111222+ivrepro=3/0/10→gen4≡gen5=L2 CLOSE. 최소 compile-hang repro라 self-host 전체 불필요.
이번세션: #4864 movdqa + #4868 environ MERGED · L2 근인을 "네이티브 백엔드 struct-of-arrays-return compile-hang"까지 razor PIN(최소 repro 확보).

## ⚠️ verdict-integrity — struct-hang은 pool 오염 아티팩트 (2026-07-12)
결정타: 대조군 arr.hexa(이전 안정 컴파일·arr_n=111222)가 재측정서 hang(120s)+summer load 14/12코어. → 내 'timeout N cc_native' struct 테스트 반복이 leftover 무한루프 프로세스 누적→pool 포화→모든 측정(대조군 포함) hang. **struct-hang(ivrepro/vmin/vmin) 발견은 오염 아티팩트로 폐기**(infra-wall-noneval). Fable hang-rootcause 분석도 오염 전제라 폐기.
클린 신호(초기·healthy summer 측정)만 유효:
- ✅ #4864 movdqa + #4868 environ MERGED(검증).
- ✅ 진짜 L2 블로커 = **cc_self가 arr.hexa(배열-리터럴-반환)를 byte-diff emit(arr_s 1376≠arr_n 1424B)·segfault**·cc_native는 111222. 워크플로우 근인=cc_self의 _x86_compute_live_ranges가 빈 X86Intervals→degenerate regmap. 이게 own-run-correctness 블로커.
잔존 resume(멀티세션·summer 회복 후): summer load<3 확인→클린 단일측정으로 cc_self arr.hexa miscompile 재확인→cc_self OWN _x86_compute_live_ranges disasm(ptrace 있는 셋업)→native regmap fix→gen4≡gen5. struct 별도조사는 healthy pool서 재개(오염 폐기). infra=summer가 leftover looper로 saturated·회복 필요.

## ✅ 오염 종결 확정 (idle aiden·2026-07-12)
idle aiden(load 0.00)에서 vmin(struct P{x:i64}) + arr.hexa 둘 다 rc=0 정상 컴파일. → **struct-hang은 100% summer 오염(진짜 struct 버그 없음)**. 클린 진짜 블로커 = cc_self가 arr.hexa 배열-리터럴-반환을 miscompile(byte-diff emit·segfault·워크플로우 근인=cc_self _x86_compute_live_ranges 빈 X86Intervals→degenerate regmap). 이후 pool=aiden(healthy·summer 폐기·회복대기).

## ★★★★★★ 근인 CONFIRMED (verify-first·aiden) — native struct-literal array-field 미스컴파일 (2026-07-12·wf_94d0aa63)
정답지-research 워크플로우 2각 수렴 + verify-first 실측:
- cc_native --backend=native가 **struct-with-array-field(ivrepro: struct Iv{ids:[i64],starts:[i64]}·return Iv{ids:a,starts:b})를 미스컴파일**→RUN **segfault(rc=139)**(emit rc=0 fast·segfault 결정론적=오염무관). scalar struct(vmin P{x:i64})는 정상. → 버그=**array-typed 필드를 가진 struct literal**.
- 근인: struct_lit build(x86_64_linux.hexa:3274-3299)가 각 필드를 _x86_hv_box_arg(:3284)로 boxing·array 필드의 TAG_ARRAY는 별도 frame tag-slot(_x86_tag_resolve :1380)서 복구하는데 그게 hexa_map_set/get 왕복서 손실(env-tag #4868 동류·separated tag-slot). read-side :3341-3355. → X86Intervals(3 array 필드) 반환이 손상→cc_self의 _x86_compute_live_ranges 빈 ids→degenerate regmap→cc_self가 모든 array-return 미스컴파일.
- fix: x86_64_linux.hexa:3284 struct_lit array-field boxing + :3341 read + :1380 tag-slot이 TAG_ARRAY 보존(gen2-C :6030/:9316 미러=whole {tag,payload} inseparable).
검증(aiden): fix후 cc_native --backend=native로 ivrepro RUN=3/0/10 정상→cc_self 재빌드→arr.hexa=111222→gen4≡gen5=axis-③ L2 CLOSE.

## narrowing: pack-array 무관 — 일반 struct_lit array-field 버그 (2026-07-12·aiden)
verify-first: ivrepro를 HEXA_PACK_ARRAY=0(legacy boxed)로도 RUN segfault(rc=139)·default(pack ON)도 동일. → **pack-fuse(_x86_local_type==1→TAG_INT) 가설 FALSIFIED**. 버그는 packed/boxed array 무관 = 일반 struct_lit map-store/get of array-field-value(box→hexa_map_set→hexa_map_get→index 경로 어딘가). scalar-field struct(vmin)+direct array-return(arr)은 정상. Fable가 정밀 trace 중(pid 4815). aiden load 13(워크플로우 cc_self 빌드로 상승·회복대기·segfault는 무관).

## ★★★★★★★ 근인 DISASM-CONFIRMED — array-mutate(push) receiver writeback 누락 (2026-07-12·aiden wbuild)
wbuild(struct 빌드만·읽기無)도 segfault → WRITE side. objdump 전체 main:
- a: hexa_arr_i64_new_esc→payload home=r12·tag-slot=-0x48(rbp).
- a.push(9)=hexa_arr_poly_push(arr=r12:-0x48, item=9): 반환 rax:rdx(새 tag:payload)를 **mov rdx,r13 · mov rax,-0x50**(임시)에 캡처. **a의 home r12/-0x48에 write-back 안 함**.
- struct_lit S{a:a}: **mov r12,r8**(STALE payload)·mov -0x48,rcx(STALE tag)→hexa_map_set에 freed/realloc된 stale 포인터 저장→use-after-realloc segfault.
근인 = **mutating array method(push)가 realloc한 새 배열을 receiver local `a`에 write-back 안 함**(결과가 fresh temp로 감·a stale). arr.hexa(push無 직접 array-return)는 정상=이 버그 회피. cc_self의 _x86_compute_live_ranges가 ids/starts/ends를 loop push로 빌드→빈/stale 배열 반환→degenerate regmap의 진짜 상류. Fable tag-path trace는 오방향(실제=payload writeback 아니라 tag).
fix 방향: hir_to_mir의 `recv.push(x)` lowering이 dst=receiver(a) 재대입인지 or 코드젠 regalloc이 push-result-a와 후속-use-a에 다른 home 주는지. `a=hexa_arr_poly_push(a,x)`로 receiver home에 write-back 보장. cc_native(gen2-C빌드)는 정상=native emit만 버그(cc-flat push 정상=gen2-C가 write-back함).
검증(aiden): fix후 wbuild=built-ok·ivrepro=3/0/10·cc_self 재빌드→arr.hexa=111222→gen4≡gen5=L2 CLOSE.

## ★★★★★★★★ 근인 최종확정 — native array-push writeback BROADLY broken (2026-07-12·aiden load0)
DECISIVE: **push-then-index(struct無)도 segfault**(clean·aiden load0). `fn main(){let mut a:[i64]=[];a.push(11);a.push(22);print(a[0]);print(a[1])}` → segfault. → array-push writeback가 struct 무관 **broad broken**. disasm: hexa_arr_poly_push 반환(새 payload rdx)을 임시(r13/-0x50)에만 캡처·receiver a의 home(r12/-0x48)에 write-back 안 함→후속 사용 전부 stale/freed 참조. cc_native(gen2-C)는 정상·native-emit만 버그(cc-flat push투성이가 cc_self서 broken). 이게 cc_self miscompile의 근본(_x86_compute_live_ranges의 loop-push X86Intervals 빈배열, 모든 array-return miscompile).
fix: hir_to_mir의 `recv.push(x)` lowering이 dst=receiver(a=push(a,x)) 인지, 아니면 codegen이 push-result를 receiver home에 write-back 하는지. native-emit이 receiver에 안 씀=고칠 지점.
검증(aiden load<3): fix후 pidx=11/22·wbuild=built-ok·ivrepro=3/0/10·cc_self 재빌드→arr.hexa=111222→gen4≡gen5=axis-③ L2 CLOSE.

## ★★★★★★★★★ AUTHORITATIVE 근인 — workflow wud8b08c0 (4-agent·aiden 실측·gcc-link 격리·high-conf · 2026-07-12)
gcc-link 격리로 **두 버그 분리**(내 push-writeback 이론=own-link 오염이었음·SUPERSEDED):
- **BUG-A (own-link/own-start stack corruption)**: 동일 t0.o가 `--linker=hexa`서 SIGSEGV(rsp=0x2/rbp=0x1) but gcc-link서 정상("4217"). own-start stub(#4868 계열) 스택정렬 손상. → pidx.hexa own-linked segfault=이 버그(codegen 아님).
- **BUG-B (codegen: struct-field packed-array read→boxed reader)**: gcc-linked 격리 repro=loop-built [i64] BARE return len=5(정상)·struct-wrapped return len=0(WRONG). struct_lit는 {TAG_ARRAY_I64,descriptor} 정확 저장하나, caller `len(iv.ids)`(field-access 결과)가 boxed `hexa_len` emit(poly 아님). runtime 직접증명: TAG_ARRAY_I64에 poly_len=5 vs hexa_len=0(self/runtime_core.c:3297 HX_IS_ARRAY(v) false→0). 근인=poly-routing gate `_x86_operand_pack_esc`가 static type_id 101-104 요구→field-access 결과는 map-backed struct 통과로 type 소거→false→boxed hexa_len→n=0→degenerate regalloc. cc_native(gen2-C)=boxed TAG_ARRAY(hexa_len 인식)이라 안 걸림=two-backend divergence.
fix 옵션(workflow): (a) x86_64_linux.hexa:4991 len gate + :3513 index gate = escaping-packed unknown-static-type도 poly로 route; (b) hir_to_mir = struct field [i64] elem type_id(101/102)를 field-access 결과 local에 전파→기존 gate 발화; (c) runtime_core.c:3297 hexa_len(+boxed index/push) = TAG_ARRAY_I64-aware(runtime discriminate)=poly reader가 이미 가진 uniform-representation soundness 완성.
runtime.a=SOUND(poly_len/get 정확). cc_self=BUG-A+BUG-B 둘다 hit(own-emit+own-link). 검증: fix→gcc-link repro struct-return len=5→own-link BUG-A도 fix→gen4≡gen5.

## ★★★★★★★★★★ BUG-B FIXED — MEASURED GREEN (aiden · 2026-07-12 07:35)
Fix = boxed hexa_len/hexa_index_get/hexa_iter_get discriminate packed tags (TAG_ARRAY_I64/F64/F32) via poly reader (self/runtime_core_emit.hexa + self/native/rtcore_*emit.hexa). Branch fix/l2-boxed-reader-poly-aware (31679c41a).
- struct-of-arrays repro (Iv{ids,starts} return · len+index+iter): `5020100` = len(iv.ids)=5 · iv.ids[0]=0 · iv.ids[2]=20 · for-in sum=100. ALL CORRECT (was 0/abort tag=12).
- 2 RED runs before = pure STALE runtime.a: build_native reuses HEXA_PREBUILT_RUNTIME=build/runtime.a (mtime 05:25, pre-fix); stage_resolve_runtime_a skips regen if present. Force `rm build/runtime.a self/runtime_core.c && HEXA_PREBUILT_RUNTIME= stage_resolve_runtime_a` → fresh 07:35 → patch in self/runtime_core.c (packed-branch=2) → GREEN.
- LIVE variant = BOXED (runtime_core.c); native rtcore_*.c NOT generated this build (first boxed commit was already correct; native-variant commit = completeness for native-runtime config).
- BUG-A = PHANTOM (workflow Lane A): own-start stub bytes correct; rsp=0x2 = gdb fp-walker artifact on stripped cc_self (stub omits xor ebp,ebp); real crash was movdqa rodata-misalign = #4864 MERGED. So L2 had ONE codegen blocker (BUG-B), now fixed.
- NEXT: full cc_self rebuild (fresh runtime.a) → arr.hexa=111222 → gen4≡gen5 = L2 CLOSE. CI 3-target byteeq gates the runtime change.
