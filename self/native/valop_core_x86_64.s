// valop_core_x86_64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 VALOP — sh-val-core).
// GENERATED: tool/regen_valop_core_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=x86_64-linux-gnu -o valop_core_x86_64.s stdlib/runtime/valop_core.hexa.
//   Provides the SCALAR value-op core (rt_truthy_native, rt_sub_native,
//   rt_mul_native, rt_add_native, rt_cmp_*_native, rt_div_native, rt_mod_native) as native raw-mem bodies: __hx_tag
//   tag-read + raw int/float payload arithmetic + __hx_make_val re-box,
//   byte-faithful to the C hexa_truthy/sub/mul/add/cmp/div/mod scalar arms. The
//   intrinsics are
//   gen2-native-only (the hexat C-transpile bootstrap cannot lower them), so
//   the bodies enter the shipped runtime.a ONLY via this seed — the array/
//   num_core mechanism (resolve_native_valop_core_seed).
//   ABI: ELF, no underscore. External: NONE (fully self-contained).
//   Lets stage_resolve_runtime_a define HEXA_RT_VALOP_NATIVE + ar this .o
//   into runtime.a so hexa_truthy/sub/mul/add/cmp/div/mod scalar paths go native.
# hexa-lang emit pass — target=x86_64-linux-gnu
# source: /tmp/isowt2/stdlib/runtime/valop_core.hexa
.intel_syntax noprefix
.file 1 "stdlib/runtime/valop_core.hexa"
.text
.globl rt_truthy_native
.hidden rt_truthy_native
    .p2align 4
rt_truthy_native:
    .loc 1 57 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 1216 # prologue: alloc spill frame
    mov [rbp - 640], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.L0436_rt_truthy_native_bb0:
    mov r12, [rbp - 640] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 648], r11 # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 648] # tag L1 from tag-slot
    mov [rbp - 656], r11 # store tag L2
    mov r10, r13 # hv payload
    mov r11, 2 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r14, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 664], r11 # store tag L3
    test r14, r14 # br_cond test
    jz .L0436_rt_truthy_native_bb2 # jump-if-zero -> else
    jmp .L0436_rt_truthy_native_bb1 # jump -> then
.L0436_rt_truthy_native_bb1:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 680], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 680] # tag L5 from tag-slot
    mov [rbp - 688], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 696], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov rdx, [rbp - 72] # reload L7 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 696] # tag L7 from tag-slot
    add rsp, 1216 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_truthy_native_bb2:
    mov r10, r13 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 704], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    test r10, r10 # br_cond test
    jz .L0436_rt_truthy_native_bb4 # jump-if-zero -> else
    jmp .L0436_rt_truthy_native_bb3 # jump -> then
.L0436_rt_truthy_native_bb3:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 720], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 720] # tag L10 from tag-slot
    mov [rbp - 728], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 736], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 736] # tag L12 from tag-slot
    mov [rbp - 744], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 752], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 752] # tag L14 from tag-slot
    mov [rbp - 760], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov r10, r10 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 768], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov rdx, [rbp - 144] # reload L16 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 768] # tag L16 from tag-slot
    add rsp, 1216 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_truthy_native_bb4:
    mov r10, r13 # hv payload
    mov r11, 1 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 776], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    test r10, r10 # br_cond test
    jz .L0436_rt_truthy_native_bb6 # jump-if-zero -> else
    jmp .L0436_rt_truthy_native_bb5 # jump -> then
.L0436_rt_truthy_native_bb5:
    mov r10, 0 # hv payload
    mov rax, 0 # tag default = TAG_INT
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 792], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov r10, r11 # assign L20
    mov r11, [rbp - 792] # tag L19 from tag-slot
    mov [rbp - 800], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, rbx # hv payload
    mov r11, [rbp - 176] # reload L20 from spill slot
    mov r11, r11 # hv payload
    movq xmm0, r10 # __hx_payload_fle: xmm0 = a.f bits
    movq xmm1, r11 # __hx_payload_fle: xmm1 = b.f bits
    comisd xmm1, xmm0 # __hx_payload_fle: comisd (NaN-correct ordered)
    setae al # __hx_payload_fle: al = predicate
    movzx r10, al # __hx_payload_fle: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 808], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 808] # tag L21 from tag-slot
    mov [rbp - 816], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r10, rbx # hv payload
    mov r11, [rbp - 176] # reload L20 from spill slot
    mov r11, r11 # hv payload
    movq xmm0, r10 # __hx_payload_fge: xmm0 = a.f bits
    movq xmm1, r11 # __hx_payload_fge: xmm1 = b.f bits
    comisd xmm0, xmm1 # __hx_payload_fge: comisd (NaN-correct ordered)
    setae al # __hx_payload_fge: al = predicate
    movzx r10, al # __hx_payload_fge: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 824], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 824] # tag L23 from tag-slot
    mov [rbp - 832], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 192] # reload L22 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 840], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r11, [rbp - 216] # reload L25 from spill slot
    mov r10, r11 # assign L26
    mov r11, [rbp - 840] # tag L25 from tag-slot
    mov [rbp - 848], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 856], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov r11, [rbp - 232] # reload L27 from spill slot
    mov r10, r11 # assign L28
    mov r11, [rbp - 856] # tag L27 from tag-slot
    mov [rbp - 864], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r11, [rbp - 240] # reload L28 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 872], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r11, [rbp - 248] # reload L29 from spill slot
    mov r10, r11 # assign L30
    mov r11, [rbp - 872] # tag L29 from tag-slot
    mov [rbp - 880], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r10, [rbp - 256] # reload L30 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 888], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov r11, [rbp - 264] # reload L31 from spill slot
    mov r10, r11 # assign L32
    mov r11, [rbp - 888] # tag L31 from tag-slot
    mov [rbp - 896], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 904], r11 # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r11, [rbp - 280] # reload L33 from spill slot
    mov r10, r11 # assign L34
    mov r11, [rbp - 904] # tag L33 from tag-slot
    mov [rbp - 912], r11 # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    mov r10, [rbp - 288] # reload L34 from spill slot
    mov r10, r10 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 920], r11 # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    mov rdx, [rbp - 296] # reload L35 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 920] # tag L35 from tag-slot
    add rsp, 1216 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_truthy_native_bb6:
    mov r10, r13 # hv payload
    mov r11, 4 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 928], r11 # store tag L36
    mov [rbp - 304], r10 # spill L36 to slot
    mov r10, [rbp - 304] # reload L36 from spill slot
    test r10, r10 # br_cond test
    jz .L0436_rt_truthy_native_bb8 # jump-if-zero -> else
    jmp .L0436_rt_truthy_native_bb7 # jump -> then
.L0436_rt_truthy_native_bb7:
    mov r10, 0 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 944], r11 # store tag L38
    mov [rbp - 320], r10 # spill L38 to slot
    mov rdx, [rbp - 320] # reload L38 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 944] # tag L38 from tag-slot
    add rsp, 1216 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_truthy_native_bb8:
    mov r10, r13 # hv payload
    mov r11, 3 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 952], r11 # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    mov r10, [rbp - 328] # reload L39 from spill slot
    test r10, r10 # br_cond test
    jz .L0436_rt_truthy_native_bb10 # jump-if-zero -> else
    jmp .L0436_rt_truthy_native_bb9 # jump -> then
.L0436_rt_truthy_native_bb9:
    mov r10, rbx # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 968], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    mov r11, [rbp - 344] # reload L41 from spill slot
    mov r10, r11 # assign L42
    mov r11, [rbp - 968] # tag L41 from tag-slot
    mov [rbp - 976], r11 # store tag L42
    mov [rbp - 352], r10 # spill L42 to slot
    mov r10, [rbp - 352] # reload L42 from spill slot
    mov r10, r10 # hv payload
    cmp r10, 0 # __hx_payload_nz: cmp payload, 0
    setne al # __hx_payload_nz: al = (pl != 0)
    movzx r10, al # __hx_payload_nz: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 984], r11 # store tag L43
    mov [rbp - 360], r10 # spill L43 to slot
    mov r11, [rbp - 360] # reload L43 from spill slot
    mov r10, r11 # assign L44
    mov r11, [rbp - 984] # tag L43 from tag-slot
    mov [rbp - 992], r11 # store tag L44
    mov [rbp - 368], r10 # spill L44 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 368] # reload L44 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1000], r11 # store tag L45
    mov [rbp - 376], r10 # spill L45 to slot
    mov r11, [rbp - 376] # reload L45 from spill slot
    mov r10, r11 # assign L46
    mov r11, [rbp - 1000] # tag L45 from tag-slot
    mov [rbp - 1008], r11 # store tag L46
    mov [rbp - 384], r10 # spill L46 to slot
    mov r10, [rbp - 384] # reload L46 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1016], r11 # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    mov r10, [rbp - 392] # reload L47 from spill slot
    test r10, r10 # br_cond test
    jz .L0436_rt_truthy_native_bb12 # jump-if-zero -> else
    jmp .L0436_rt_truthy_native_bb11 # jump -> then
.L0436_rt_truthy_native_bb10:
    mov r10, r13 # hv payload
    mov r11, 5 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1096], r11 # store tag L57
    mov [rbp - 472], r10 # spill L57 to slot
    mov r10, [rbp - 472] # reload L57 from spill slot
    test r10, r10 # br_cond test
    jz .L0436_rt_truthy_native_bb14 # jump-if-zero -> else
    jmp .L0436_rt_truthy_native_bb13 # jump -> then
.L0436_rt_truthy_native_bb11:
    mov r10, 0 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 1032], r11 # store tag L49
    mov [rbp - 408], r10 # spill L49 to slot
    mov rdx, [rbp - 408] # reload L49 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 1032] # tag L49 from tag-slot
    add rsp, 1216 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_truthy_native_bb12:
    mov r10, rbx # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_str_byte: r10 = s + i
    movzx r10, byte ptr [r10] # __hx_str_byte: r10 = s[i]
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1040], r11 # store tag L50
    mov [rbp - 416], r10 # spill L50 to slot
    mov r11, [rbp - 416] # reload L50 from spill slot
    mov r10, r11 # assign L51
    mov r11, [rbp - 1040] # tag L50 from tag-slot
    mov [rbp - 1048], r11 # store tag L51
    mov [rbp - 424], r10 # spill L51 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 424] # reload L51 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1056], r11 # store tag L52
    mov [rbp - 432], r10 # spill L52 to slot
    mov r11, [rbp - 432] # reload L52 from spill slot
    mov r10, r11 # assign L53
    mov r11, [rbp - 1056] # tag L52 from tag-slot
    mov [rbp - 1064], r11 # store tag L53
    mov [rbp - 440], r10 # spill L53 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 440] # reload L53 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1072], r11 # store tag L54
    mov [rbp - 448], r10 # spill L54 to slot
    mov r11, [rbp - 448] # reload L54 from spill slot
    mov r10, r11 # assign L55
    mov r11, [rbp - 1072] # tag L54 from tag-slot
    mov [rbp - 1080], r11 # store tag L55
    mov [rbp - 456], r10 # spill L55 to slot
    mov r10, [rbp - 456] # reload L55 from spill slot
    mov r10, r10 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 1088], r11 # store tag L56
    mov [rbp - 464], r10 # spill L56 to slot
    mov rdx, [rbp - 464] # reload L56 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 1088] # tag L56 from tag-slot
    add rsp, 1216 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_truthy_native_bb13:
    mov r10, rbx # hv payload
    mov r10d, dword ptr [r10 + 8] # __hx_arr_len: r10d = arr->len (int32, zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1112], r11 # store tag L59
    mov [rbp - 488], r10 # spill L59 to slot
    mov r11, [rbp - 488] # reload L59 from spill slot
    mov r10, r11 # assign L60
    mov r11, [rbp - 1112] # tag L59 from tag-slot
    mov [rbp - 1120], r11 # store tag L60
    mov [rbp - 496], r10 # spill L60 to slot
    mov r10, 0 # hv payload
    mov r11, 0 # hv payload
    mov [rbp - 1128], r11 # store tag L61
    mov [rbp - 504], r10 # spill L61 to slot
    mov r11, [rbp - 504] # reload L61 from spill slot
    mov r10, r11 # assign L62
    mov r11, [rbp - 1128] # tag L61 from tag-slot
    mov [rbp - 1136], r11 # store tag L62
    mov [rbp - 512], r10 # spill L62 to slot
    mov r11, [rbp - 512] # reload L62 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 496] # reload L60 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_gt: cmp payloads
    setg al # __hx_payload_gt: al = predicate
    movzx r10, al # __hx_payload_gt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1144], r11 # store tag L63
    mov [rbp - 520], r10 # spill L63 to slot
    mov r11, [rbp - 520] # reload L63 from spill slot
    mov r10, r11 # assign L64
    mov r11, [rbp - 1144] # tag L63 from tag-slot
    mov [rbp - 1152], r11 # store tag L64
    mov [rbp - 528], r10 # spill L64 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 528] # reload L64 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1160], r11 # store tag L65
    mov [rbp - 536], r10 # spill L65 to slot
    mov r11, [rbp - 536] # reload L65 from spill slot
    mov r10, r11 # assign L66
    mov r11, [rbp - 1160] # tag L65 from tag-slot
    mov [rbp - 1168], r11 # store tag L66
    mov [rbp - 544], r10 # spill L66 to slot
    mov r10, [rbp - 544] # reload L66 from spill slot
    mov r10, r10 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 1176], r11 # store tag L67
    mov [rbp - 552], r10 # spill L67 to slot
    mov rdx, [rbp - 552] # reload L67 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 1176] # tag L67 from tag-slot
    add rsp, 1216 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_truthy_native_bb14:
    mov r10, r13 # hv payload
    mov r11, 10 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1184], r11 # store tag L68
    mov [rbp - 560], r10 # spill L68 to slot
    mov r10, [rbp - 560] # reload L68 from spill slot
    test r10, r10 # br_cond test
    jz .L0436_rt_truthy_native_bb16 # jump-if-zero -> else
    jmp .L0436_rt_truthy_native_bb15 # jump -> then
.L0436_rt_truthy_native_bb15:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1200], r11 # store tag L70
    mov [rbp - 576], r10 # spill L70 to slot
    mov r11, [rbp - 576] # reload L70 from spill slot
    mov r10, r11 # assign L71
    mov r11, [rbp - 1200] # tag L70 from tag-slot
    mov [rbp - 1208], r11 # store tag L71
    mov [rbp - 584], r10 # spill L71 to slot
    mov r10, [rbp - 584] # reload L71 from spill slot
    mov r10, r10 # hv payload
    cmp r10, 0 # __hx_payload_nz: cmp payload, 0
    setne al # __hx_payload_nz: al = (pl != 0)
    movzx r10, al # __hx_payload_nz: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1216], r11 # store tag L72
    mov [rbp - 592], r10 # spill L72 to slot
    mov r11, [rbp - 592] # reload L72 from spill slot
    mov r10, r11 # assign L73
    mov r11, [rbp - 1216] # tag L72 from tag-slot
    mov [rbp - 1224], r11 # store tag L73
    mov [rbp - 600], r10 # spill L73 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 600] # reload L73 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1232], r11 # store tag L74
    mov [rbp - 608], r10 # spill L74 to slot
    mov r11, [rbp - 608] # reload L74 from spill slot
    mov r10, r11 # assign L75
    mov r11, [rbp - 1232] # tag L74 from tag-slot
    mov [rbp - 1240], r11 # store tag L75
    mov [rbp - 616], r10 # spill L75 to slot
    mov r10, [rbp - 616] # reload L75 from spill slot
    mov r10, r10 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 1248], r11 # store tag L76
    mov [rbp - 624], r10 # spill L76 to slot
    mov rdx, [rbp - 624] # reload L76 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 1248] # tag L76 from tag-slot
    add rsp, 1216 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_truthy_native_bb16:
    mov r10, 1 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 1256], r11 # store tag L77
    mov [rbp - 632], r10 # spill L77 to slot
    mov rdx, [rbp - 632] # reload L77 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 1256] # tag L77 from tag-slot
    add rsp, 1216 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_sub_native
.hidden rt_sub_native
    .p2align 4
rt_sub_native:
    .loc 1 139 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 416 # prologue: alloc spill frame
    mov [rbp - 240], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 248], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L0436_rt_sub_native_bb0:
    mov r13, [rbp - 240] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 256], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 256] # tag L2 from tag-slot
    mov [rbp - 264], r11 # store tag L3
    mov r15, [rbp - 248] # tag L1 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 272], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 272] # tag L4 from tag-slot
    mov [rbp - 280], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, r14 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 288], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 288] # tag L6 from tag-slot
    mov [rbp - 296], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 304], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 304] # tag L8 from tag-slot
    mov [rbp - 312], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 320], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 320] # tag L10 from tag-slot
    mov [rbp - 328], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 336], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    test r10, r10 # br_cond test
    jz .L0436_rt_sub_native_bb2 # jump-if-zero -> else
    jmp .L0436_rt_sub_native_bb1 # jump -> then
.L0436_rt_sub_native_bb1:
    mov r11, r12 # hv payload
    mov r10, rbx # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 352], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 352] # tag L14 from tag-slot
    mov [rbp - 360], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 368], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, [rbp - 368] # tag L16 from tag-slot
    mov [rbp - 376], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    mov [rbp - 384], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov rdx, [rbp - 160] # reload L18 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 384] # tag L18 from tag-slot
    add rsp, 416 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_sub_native_bb2:
    mov r10, rbx # hv payload
    mov rax, [rbp - 240] # tag L0 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 392], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov r10, r11 # assign L20
    mov r11, [rbp - 392] # tag L19 from tag-slot
    mov [rbp - 400], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, r12 # hv payload
    mov rax, [rbp - 248] # tag L1 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 408], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 408] # tag L21 from tag-slot
    mov [rbp - 416], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r10, [rbp - 176] # reload L20 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r11, r11 # hv payload
    movq xmm0, r10 # __hx_payload_fsub: xmm0 = a.f bits
    movq xmm1, r11 # __hx_payload_fsub: xmm1 = b.f bits
    subsd xmm0, xmm1 # __hx_payload_fsub: xmm0 = a.f subsd b.f
    movq r10, xmm0 # __hx_payload_fsub: r10 = result bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 424], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 424] # tag L23 from tag-slot
    mov [rbp - 432], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 440], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r11, [rbp - 216] # reload L25 from spill slot
    mov r10, r11 # assign L26
    mov r11, [rbp - 440] # tag L25 from tag-slot
    mov [rbp - 448], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov r10, r10 # hv payload
    mov r11, 1 # hv payload
    mov [rbp - 456], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov rdx, [rbp - 232] # reload L27 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 456] # tag L27 from tag-slot
    add rsp, 416 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_mul_native
.hidden rt_mul_native
    .p2align 4
rt_mul_native:
    .loc 1 161 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 416 # prologue: alloc spill frame
    mov [rbp - 240], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 248], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L0436_rt_mul_native_bb0:
    mov r13, [rbp - 240] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 256], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 256] # tag L2 from tag-slot
    mov [rbp - 264], r11 # store tag L3
    mov r15, [rbp - 248] # tag L1 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 272], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 272] # tag L4 from tag-slot
    mov [rbp - 280], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, r14 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 288], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 288] # tag L6 from tag-slot
    mov [rbp - 296], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 304], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 304] # tag L8 from tag-slot
    mov [rbp - 312], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 320], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 320] # tag L10 from tag-slot
    mov [rbp - 328], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 336], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    test r10, r10 # br_cond test
    jz .L0436_rt_mul_native_bb2 # jump-if-zero -> else
    jmp .L0436_rt_mul_native_bb1 # jump -> then
.L0436_rt_mul_native_bb1:
    mov r11, r12 # hv payload
    mov r10, rbx # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 352], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 352] # tag L14 from tag-slot
    mov [rbp - 360], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 368], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, [rbp - 368] # tag L16 from tag-slot
    mov [rbp - 376], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    mov [rbp - 384], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov rdx, [rbp - 160] # reload L18 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 384] # tag L18 from tag-slot
    add rsp, 416 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_mul_native_bb2:
    mov r10, rbx # hv payload
    mov rax, [rbp - 240] # tag L0 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 392], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov r10, r11 # assign L20
    mov r11, [rbp - 392] # tag L19 from tag-slot
    mov [rbp - 400], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, r12 # hv payload
    mov rax, [rbp - 248] # tag L1 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 408], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 408] # tag L21 from tag-slot
    mov [rbp - 416], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r10, [rbp - 176] # reload L20 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r11, r11 # hv payload
    movq xmm0, r10 # __hx_payload_fmul: xmm0 = a.f bits
    movq xmm1, r11 # __hx_payload_fmul: xmm1 = b.f bits
    mulsd xmm0, xmm1 # __hx_payload_fmul: xmm0 = a.f mulsd b.f
    movq r10, xmm0 # __hx_payload_fmul: r10 = result bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 424], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 424] # tag L23 from tag-slot
    mov [rbp - 432], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 440], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r11, [rbp - 216] # reload L25 from spill slot
    mov r10, r11 # assign L26
    mov r11, [rbp - 440] # tag L25 from tag-slot
    mov [rbp - 448], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov r10, r10 # hv payload
    mov r11, 1 # hv payload
    mov [rbp - 456], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov rdx, [rbp - 232] # reload L27 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 456] # tag L27 from tag-slot
    add rsp, 416 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_add_native
.hidden rt_add_native
    .p2align 4
rt_add_native:
    .loc 1 189 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 416 # prologue: alloc spill frame
    mov [rbp - 240], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 248], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L0436_rt_add_native_bb0:
    mov r13, [rbp - 240] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 256], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 256] # tag L2 from tag-slot
    mov [rbp - 264], r11 # store tag L3
    mov r15, [rbp - 248] # tag L1 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 272], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 272] # tag L4 from tag-slot
    mov [rbp - 280], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, r14 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 288], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 288] # tag L6 from tag-slot
    mov [rbp - 296], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 304], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 304] # tag L8 from tag-slot
    mov [rbp - 312], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 320], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 320] # tag L10 from tag-slot
    mov [rbp - 328], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 336], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    test r10, r10 # br_cond test
    jz .L0436_rt_add_native_bb2 # jump-if-zero -> else
    jmp .L0436_rt_add_native_bb1 # jump -> then
.L0436_rt_add_native_bb1:
    mov r11, r12 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 352], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 352] # tag L14 from tag-slot
    mov [rbp - 360], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 368], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, [rbp - 368] # tag L16 from tag-slot
    mov [rbp - 376], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    mov [rbp - 384], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov rdx, [rbp - 160] # reload L18 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 384] # tag L18 from tag-slot
    add rsp, 416 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_add_native_bb2:
    mov r10, rbx # hv payload
    mov rax, [rbp - 240] # tag L0 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 392], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov r10, r11 # assign L20
    mov r11, [rbp - 392] # tag L19 from tag-slot
    mov [rbp - 400], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, r12 # hv payload
    mov rax, [rbp - 248] # tag L1 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 408], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 408] # tag L21 from tag-slot
    mov [rbp - 416], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r10, [rbp - 176] # reload L20 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r11, r11 # hv payload
    movq xmm0, r10 # __hx_payload_fadd: xmm0 = a.f bits
    movq xmm1, r11 # __hx_payload_fadd: xmm1 = b.f bits
    addsd xmm0, xmm1 # __hx_payload_fadd: xmm0 = a.f addsd b.f
    movq r10, xmm0 # __hx_payload_fadd: r10 = result bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 424], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 424] # tag L23 from tag-slot
    mov [rbp - 432], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 440], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r11, [rbp - 216] # reload L25 from spill slot
    mov r10, r11 # assign L26
    mov r11, [rbp - 440] # tag L25 from tag-slot
    mov [rbp - 448], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov r10, r10 # hv payload
    mov r11, 1 # hv payload
    mov [rbp - 456], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov rdx, [rbp - 232] # reload L27 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 456] # tag L27 from tag-slot
    add rsp, 416 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_cmp_lt_native
.hidden rt_cmp_lt_native
    .p2align 4
rt_cmp_lt_native:
    .loc 1 224 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 416 # prologue: alloc spill frame
    mov [rbp - 240], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 248], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L0436_rt_cmp_lt_native_bb0:
    mov r13, [rbp - 240] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 256], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 256] # tag L2 from tag-slot
    mov [rbp - 264], r11 # store tag L3
    mov r15, [rbp - 248] # tag L1 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 272], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 272] # tag L4 from tag-slot
    mov [rbp - 280], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, r14 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 288], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 288] # tag L6 from tag-slot
    mov [rbp - 296], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 304], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 304] # tag L8 from tag-slot
    mov [rbp - 312], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 320], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 320] # tag L10 from tag-slot
    mov [rbp - 328], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 336], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    test r10, r10 # br_cond test
    jz .L0436_rt_cmp_lt_native_bb2 # jump-if-zero -> else
    jmp .L0436_rt_cmp_lt_native_bb1 # jump -> then
.L0436_rt_cmp_lt_native_bb1:
    mov r11, r12 # hv payload
    mov r10, rbx # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 352], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 352] # tag L14 from tag-slot
    mov [rbp - 360], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 368], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, [rbp - 368] # tag L16 from tag-slot
    mov [rbp - 376], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 384], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov rdx, [rbp - 160] # reload L18 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 384] # tag L18 from tag-slot
    add rsp, 416 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_cmp_lt_native_bb2:
    mov r10, rbx # hv payload
    mov rax, [rbp - 240] # tag L0 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 392], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov r10, r11 # assign L20
    mov r11, [rbp - 392] # tag L19 from tag-slot
    mov [rbp - 400], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, r12 # hv payload
    mov rax, [rbp - 248] # tag L1 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 408], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 408] # tag L21 from tag-slot
    mov [rbp - 416], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r10, [rbp - 176] # reload L20 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r11, r11 # hv payload
    movq xmm0, r10 # __hx_payload_flt: xmm0 = a.f bits
    movq xmm1, r11 # __hx_payload_flt: xmm1 = b.f bits
    comisd xmm1, xmm0 # __hx_payload_flt: comisd (NaN-correct ordered)
    seta al # __hx_payload_flt: al = predicate
    movzx r10, al # __hx_payload_flt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 424], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 424] # tag L23 from tag-slot
    mov [rbp - 432], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 440], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r11, [rbp - 216] # reload L25 from spill slot
    mov r10, r11 # assign L26
    mov r11, [rbp - 440] # tag L25 from tag-slot
    mov [rbp - 448], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov r10, r10 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 456], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov rdx, [rbp - 232] # reload L27 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 456] # tag L27 from tag-slot
    add rsp, 416 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_cmp_gt_native
.hidden rt_cmp_gt_native
    .p2align 4
rt_cmp_gt_native:
    .loc 1 243 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 416 # prologue: alloc spill frame
    mov [rbp - 240], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 248], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L0436_rt_cmp_gt_native_bb0:
    mov r13, [rbp - 240] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 256], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 256] # tag L2 from tag-slot
    mov [rbp - 264], r11 # store tag L3
    mov r15, [rbp - 248] # tag L1 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 272], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 272] # tag L4 from tag-slot
    mov [rbp - 280], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, r14 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 288], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 288] # tag L6 from tag-slot
    mov [rbp - 296], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 304], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 304] # tag L8 from tag-slot
    mov [rbp - 312], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 320], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 320] # tag L10 from tag-slot
    mov [rbp - 328], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 336], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    test r10, r10 # br_cond test
    jz .L0436_rt_cmp_gt_native_bb2 # jump-if-zero -> else
    jmp .L0436_rt_cmp_gt_native_bb1 # jump -> then
.L0436_rt_cmp_gt_native_bb1:
    mov r11, r12 # hv payload
    mov r10, rbx # hv payload
    cmp r10, r11 # __hx_payload_gt: cmp payloads
    setg al # __hx_payload_gt: al = predicate
    movzx r10, al # __hx_payload_gt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 352], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 352] # tag L14 from tag-slot
    mov [rbp - 360], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 368], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, [rbp - 368] # tag L16 from tag-slot
    mov [rbp - 376], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 384], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov rdx, [rbp - 160] # reload L18 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 384] # tag L18 from tag-slot
    add rsp, 416 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_cmp_gt_native_bb2:
    mov r10, rbx # hv payload
    mov rax, [rbp - 240] # tag L0 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 392], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov r10, r11 # assign L20
    mov r11, [rbp - 392] # tag L19 from tag-slot
    mov [rbp - 400], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, r12 # hv payload
    mov rax, [rbp - 248] # tag L1 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 408], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 408] # tag L21 from tag-slot
    mov [rbp - 416], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r10, [rbp - 176] # reload L20 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r11, r11 # hv payload
    movq xmm0, r10 # __hx_payload_fgt: xmm0 = a.f bits
    movq xmm1, r11 # __hx_payload_fgt: xmm1 = b.f bits
    comisd xmm0, xmm1 # __hx_payload_fgt: comisd (NaN-correct ordered)
    seta al # __hx_payload_fgt: al = predicate
    movzx r10, al # __hx_payload_fgt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 424], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 424] # tag L23 from tag-slot
    mov [rbp - 432], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 440], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r11, [rbp - 216] # reload L25 from spill slot
    mov r10, r11 # assign L26
    mov r11, [rbp - 440] # tag L25 from tag-slot
    mov [rbp - 448], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov r10, r10 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 456], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov rdx, [rbp - 232] # reload L27 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 456] # tag L27 from tag-slot
    add rsp, 416 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_cmp_le_native
.hidden rt_cmp_le_native
    .p2align 4
rt_cmp_le_native:
    .loc 1 262 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 416 # prologue: alloc spill frame
    mov [rbp - 240], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 248], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L0436_rt_cmp_le_native_bb0:
    mov r13, [rbp - 240] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 256], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 256] # tag L2 from tag-slot
    mov [rbp - 264], r11 # store tag L3
    mov r15, [rbp - 248] # tag L1 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 272], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 272] # tag L4 from tag-slot
    mov [rbp - 280], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, r14 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 288], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 288] # tag L6 from tag-slot
    mov [rbp - 296], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 304], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 304] # tag L8 from tag-slot
    mov [rbp - 312], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 320], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 320] # tag L10 from tag-slot
    mov [rbp - 328], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 336], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    test r10, r10 # br_cond test
    jz .L0436_rt_cmp_le_native_bb2 # jump-if-zero -> else
    jmp .L0436_rt_cmp_le_native_bb1 # jump -> then
.L0436_rt_cmp_le_native_bb1:
    mov r11, r12 # hv payload
    mov r10, rbx # hv payload
    cmp r10, r11 # __hx_payload_le: cmp payloads
    setle al # __hx_payload_le: al = predicate
    movzx r10, al # __hx_payload_le: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 352], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 352] # tag L14 from tag-slot
    mov [rbp - 360], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 368], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, [rbp - 368] # tag L16 from tag-slot
    mov [rbp - 376], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 384], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov rdx, [rbp - 160] # reload L18 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 384] # tag L18 from tag-slot
    add rsp, 416 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_cmp_le_native_bb2:
    mov r10, rbx # hv payload
    mov rax, [rbp - 240] # tag L0 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 392], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov r10, r11 # assign L20
    mov r11, [rbp - 392] # tag L19 from tag-slot
    mov [rbp - 400], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, r12 # hv payload
    mov rax, [rbp - 248] # tag L1 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 408], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 408] # tag L21 from tag-slot
    mov [rbp - 416], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r10, [rbp - 176] # reload L20 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r11, r11 # hv payload
    movq xmm0, r10 # __hx_payload_fle: xmm0 = a.f bits
    movq xmm1, r11 # __hx_payload_fle: xmm1 = b.f bits
    comisd xmm1, xmm0 # __hx_payload_fle: comisd (NaN-correct ordered)
    setae al # __hx_payload_fle: al = predicate
    movzx r10, al # __hx_payload_fle: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 424], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 424] # tag L23 from tag-slot
    mov [rbp - 432], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 440], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r11, [rbp - 216] # reload L25 from spill slot
    mov r10, r11 # assign L26
    mov r11, [rbp - 440] # tag L25 from tag-slot
    mov [rbp - 448], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov r10, r10 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 456], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov rdx, [rbp - 232] # reload L27 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 456] # tag L27 from tag-slot
    add rsp, 416 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_cmp_ge_native
.hidden rt_cmp_ge_native
    .p2align 4
rt_cmp_ge_native:
    .loc 1 281 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 416 # prologue: alloc spill frame
    mov [rbp - 240], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 248], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L0436_rt_cmp_ge_native_bb0:
    mov r13, [rbp - 240] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 256], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 256] # tag L2 from tag-slot
    mov [rbp - 264], r11 # store tag L3
    mov r15, [rbp - 248] # tag L1 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 272], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 272] # tag L4 from tag-slot
    mov [rbp - 280], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, r14 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 288], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 288] # tag L6 from tag-slot
    mov [rbp - 296], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 304], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 304] # tag L8 from tag-slot
    mov [rbp - 312], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 320], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 320] # tag L10 from tag-slot
    mov [rbp - 328], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 336], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    test r10, r10 # br_cond test
    jz .L0436_rt_cmp_ge_native_bb2 # jump-if-zero -> else
    jmp .L0436_rt_cmp_ge_native_bb1 # jump -> then
.L0436_rt_cmp_ge_native_bb1:
    mov r11, r12 # hv payload
    mov r10, rbx # hv payload
    cmp r10, r11 # __hx_payload_ge: cmp payloads
    setge al # __hx_payload_ge: al = predicate
    movzx r10, al # __hx_payload_ge: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 352], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 352] # tag L14 from tag-slot
    mov [rbp - 360], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 368], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, [rbp - 368] # tag L16 from tag-slot
    mov [rbp - 376], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 384], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov rdx, [rbp - 160] # reload L18 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 384] # tag L18 from tag-slot
    add rsp, 416 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_cmp_ge_native_bb2:
    mov r10, rbx # hv payload
    mov rax, [rbp - 240] # tag L0 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 392], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov r10, r11 # assign L20
    mov r11, [rbp - 392] # tag L19 from tag-slot
    mov [rbp - 400], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, r12 # hv payload
    mov rax, [rbp - 248] # tag L1 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 408], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 408] # tag L21 from tag-slot
    mov [rbp - 416], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r10, [rbp - 176] # reload L20 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r11, r11 # hv payload
    movq xmm0, r10 # __hx_payload_fge: xmm0 = a.f bits
    movq xmm1, r11 # __hx_payload_fge: xmm1 = b.f bits
    comisd xmm0, xmm1 # __hx_payload_fge: comisd (NaN-correct ordered)
    setae al # __hx_payload_fge: al = predicate
    movzx r10, al # __hx_payload_fge: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 424], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 424] # tag L23 from tag-slot
    mov [rbp - 432], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 440], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r11, [rbp - 216] # reload L25 from spill slot
    mov r10, r11 # assign L26
    mov r11, [rbp - 440] # tag L25 from tag-slot
    mov [rbp - 448], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov r10, r10 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 456], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov rdx, [rbp - 232] # reload L27 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 456] # tag L27 from tag-slot
    add rsp, 416 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_div_native
.hidden rt_div_native
    .p2align 4
rt_div_native:
    .loc 1 311 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 80 # prologue: alloc spill frame
    mov [rbp - 72], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 80], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L0436_rt_div_native_bb0:
    mov r11, r12 # hv payload
    mov r10, rbx # hv payload
    mov rax, r10 # __hx_payload_div: rax = a.pl (dividend)
    cqo # __hx_payload_div: sign-extend rax → rdx:rax
    idiv r11 # __hx_payload_div: rax=quo rdx=rem (a.pl / b.pl)
    mov r10, rax # __hx_payload_div: r10 = quotient
    mov r13, r10 # leaf: payload → dst L2
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 88], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 88] # tag L2 from tag-slot
    mov [rbp - 96], r11 # store tag L3
    mov r11, 0 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r15, r10 # leaf: payload → dst L4
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 104], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 104] # tag L4 from tag-slot
    mov [rbp - 112], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    mov [rbp - 120], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov rdx, [rbp - 64] # reload L6 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 120] # tag L6 from tag-slot
    add rsp, 80 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_mod_native
.hidden rt_mod_native
    .p2align 4
rt_mod_native:
    .loc 1 318 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 80 # prologue: alloc spill frame
    mov [rbp - 72], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 80], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L0436_rt_mod_native_bb0:
    mov r11, r12 # hv payload
    mov r10, rbx # hv payload
    mov rax, r10 # __hx_payload_mod: rax = a.pl (dividend)
    cqo # __hx_payload_mod: sign-extend rax → rdx:rax
    idiv r11 # __hx_payload_mod: rax=quo rdx=rem (a.pl / b.pl)
    mov r10, rdx # __hx_payload_mod: r10 = remainder
    mov r13, r10 # leaf: payload → dst L2
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 88], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 88] # tag L2 from tag-slot
    mov [rbp - 96], r11 # store tag L3
    mov r11, 0 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r15, r10 # leaf: payload → dst L4
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 104], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 104] # tag L4 from tag-slot
    mov [rbp - 112], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    mov [rbp - 120], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov rdx, [rbp - 64] # reload L6 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 120] # tag L6 from tag-slot
    add rsp, 80 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_eq_scalar_native
.hidden rt_eq_scalar_native
    .p2align 4
rt_eq_scalar_native:
    .loc 1 332 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 1184 # prologue: alloc spill frame
    mov [rbp - 624], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 632], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L0436_rt_eq_scalar_native_bb0:
    mov r13, [rbp - 624] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 640], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 640] # tag L2 from tag-slot
    mov [rbp - 648], r11 # store tag L3
    mov r15, [rbp - 632] # tag L1 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 656], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 656] # tag L4 from tag-slot
    mov [rbp - 664], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, r14 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 672], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 672] # tag L6 from tag-slot
    mov [rbp - 680], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, r14 # hv payload
    mov r11, 1 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 688], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 688] # tag L8 from tag-slot
    mov [rbp - 696], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 704], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 704] # tag L10 from tag-slot
    mov [rbp - 712], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 1 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 720], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 720] # tag L12 from tag-slot
    mov [rbp - 728], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 736], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 736] # tag L14 from tag-slot
    mov [rbp - 744], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 752], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, [rbp - 752] # tag L16 from tag-slot
    mov [rbp - 760], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r11, [rbp - 152] # reload L17 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov r10, r10 # hv payload
    or r10, r11 # __hx_payload_or: r10 = a.pl or b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 768], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov r10, r11 # assign L19
    mov r11, [rbp - 768] # tag L18 from tag-slot
    mov [rbp - 776], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 784], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r11, [rbp - 176] # reload L20 from spill slot
    mov r10, r11 # assign L21
    mov r11, [rbp - 784] # tag L20 from tag-slot
    mov [rbp - 792], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 168] # reload L19 from spill slot
    mov r10, r10 # hv payload
    or r10, r11 # __hx_payload_or: r10 = a.pl or b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 800], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r10, r11 # assign L23
    mov r11, [rbp - 800] # tag L22 from tag-slot
    mov [rbp - 808], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 200] # reload L23 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 816], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r10, [rbp - 208] # reload L24 from spill slot
    test r10, r10 # br_cond test
    jz .L0436_rt_eq_scalar_native_bb2 # jump-if-zero -> else
    jmp .L0436_rt_eq_scalar_native_bb1 # jump -> then
.L0436_rt_eq_scalar_native_bb1:
    mov r10, rbx # hv payload
    mov rax, [rbp - 624] # tag L0 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 832], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r11, [rbp - 224] # reload L26 from spill slot
    mov r10, r11 # assign L27
    mov r11, [rbp - 832] # tag L26 from tag-slot
    mov [rbp - 840], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov r10, r12 # hv payload
    mov rax, [rbp - 632] # tag L1 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 848], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r11, [rbp - 240] # reload L28 from spill slot
    mov r10, r11 # assign L29
    mov r11, [rbp - 848] # tag L28 from tag-slot
    mov [rbp - 856], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r10, [rbp - 232] # reload L27 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 248] # reload L29 from spill slot
    mov r11, r11 # hv payload
    movq xmm0, r10 # __hx_payload_fle: xmm0 = a.f bits
    movq xmm1, r11 # __hx_payload_fle: xmm1 = b.f bits
    comisd xmm1, xmm0 # __hx_payload_fle: comisd (NaN-correct ordered)
    setae al # __hx_payload_fle: al = predicate
    movzx r10, al # __hx_payload_fle: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 864], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r11, [rbp - 256] # reload L30 from spill slot
    mov r10, r11 # assign L31
    mov r11, [rbp - 864] # tag L30 from tag-slot
    mov [rbp - 872], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov r10, [rbp - 232] # reload L27 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 248] # reload L29 from spill slot
    mov r11, r11 # hv payload
    movq xmm0, r10 # __hx_payload_fge: xmm0 = a.f bits
    movq xmm1, r11 # __hx_payload_fge: xmm1 = b.f bits
    comisd xmm0, xmm1 # __hx_payload_fge: comisd (NaN-correct ordered)
    setae al # __hx_payload_fge: al = predicate
    movzx r10, al # __hx_payload_fge: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 880], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r11, [rbp - 272] # reload L32 from spill slot
    mov r10, r11 # assign L33
    mov r11, [rbp - 880] # tag L32 from tag-slot
    mov [rbp - 888], r11 # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 264] # reload L31 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 896], r11 # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    mov r11, [rbp - 288] # reload L34 from spill slot
    mov r10, r11 # assign L35
    mov r11, [rbp - 896] # tag L34 from tag-slot
    mov [rbp - 904], r11 # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 280] # reload L33 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 912], r11 # store tag L36
    mov [rbp - 304], r10 # spill L36 to slot
    mov r11, [rbp - 304] # reload L36 from spill slot
    mov r10, r11 # assign L37
    mov r11, [rbp - 912] # tag L36 from tag-slot
    mov [rbp - 920], r11 # store tag L37
    mov [rbp - 312], r10 # spill L37 to slot
    mov r11, [rbp - 312] # reload L37 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 296] # reload L35 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 928], r11 # store tag L38
    mov [rbp - 320], r10 # spill L38 to slot
    mov r11, [rbp - 320] # reload L38 from spill slot
    mov r10, r11 # assign L39
    mov r11, [rbp - 928] # tag L38 from tag-slot
    mov [rbp - 936], r11 # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    mov r10, [rbp - 328] # reload L39 from spill slot
    mov r10, r10 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 944], r11 # store tag L40
    mov [rbp - 336], r10 # spill L40 to slot
    mov rdx, [rbp - 336] # reload L40 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 944] # tag L40 from tag-slot
    add rsp, 1184 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_eq_scalar_native_bb2:
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 952], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    mov r11, [rbp - 344] # reload L41 from spill slot
    mov r10, r11 # assign L42
    mov r11, [rbp - 952] # tag L41 from tag-slot
    mov [rbp - 960], r11 # store tag L42
    mov [rbp - 352], r10 # spill L42 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 352] # reload L42 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 968], r11 # store tag L43
    mov [rbp - 360], r10 # spill L43 to slot
    mov r10, [rbp - 360] # reload L43 from spill slot
    test r10, r10 # br_cond test
    jz .L0436_rt_eq_scalar_native_bb4 # jump-if-zero -> else
    jmp .L0436_rt_eq_scalar_native_bb3 # jump -> then
.L0436_rt_eq_scalar_native_bb3:
    mov r11, r12 # hv payload
    mov r10, rbx # hv payload
    cmp r10, r11 # __hx_payload_le: cmp payloads
    setle al # __hx_payload_le: al = predicate
    movzx r10, al # __hx_payload_le: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 984], r11 # store tag L45
    mov [rbp - 376], r10 # spill L45 to slot
    mov r11, [rbp - 376] # reload L45 from spill slot
    mov r10, r11 # assign L46
    mov r11, [rbp - 984] # tag L45 from tag-slot
    mov [rbp - 992], r11 # store tag L46
    mov [rbp - 384], r10 # spill L46 to slot
    mov r11, r12 # hv payload
    mov r10, rbx # hv payload
    cmp r10, r11 # __hx_payload_ge: cmp payloads
    setge al # __hx_payload_ge: al = predicate
    movzx r10, al # __hx_payload_ge: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1000], r11 # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    mov r11, [rbp - 392] # reload L47 from spill slot
    mov r10, r11 # assign L48
    mov r11, [rbp - 1000] # tag L47 from tag-slot
    mov [rbp - 1008], r11 # store tag L48
    mov [rbp - 400], r10 # spill L48 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 384] # reload L46 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1016], r11 # store tag L49
    mov [rbp - 408], r10 # spill L49 to slot
    mov r11, [rbp - 408] # reload L49 from spill slot
    mov r10, r11 # assign L50
    mov r11, [rbp - 1016] # tag L49 from tag-slot
    mov [rbp - 1024], r11 # store tag L50
    mov [rbp - 416], r10 # spill L50 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 400] # reload L48 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1032], r11 # store tag L51
    mov [rbp - 424], r10 # spill L51 to slot
    mov r11, [rbp - 424] # reload L51 from spill slot
    mov r10, r11 # assign L52
    mov r11, [rbp - 1032] # tag L51 from tag-slot
    mov [rbp - 1040], r11 # store tag L52
    mov [rbp - 432], r10 # spill L52 to slot
    mov r11, [rbp - 432] # reload L52 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 416] # reload L50 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1048], r11 # store tag L53
    mov [rbp - 440], r10 # spill L53 to slot
    mov r11, [rbp - 440] # reload L53 from spill slot
    mov r10, r11 # assign L54
    mov r11, [rbp - 1048] # tag L53 from tag-slot
    mov [rbp - 1056], r11 # store tag L54
    mov [rbp - 448], r10 # spill L54 to slot
    mov r10, [rbp - 448] # reload L54 from spill slot
    mov r10, r10 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 1064], r11 # store tag L55
    mov [rbp - 456], r10 # spill L55 to slot
    mov rdx, [rbp - 456] # reload L55 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 1064] # tag L55 from tag-slot
    add rsp, 1184 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_eq_scalar_native_bb4:
    mov r10, r14 # hv payload
    mov r11, 2 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1072], r11 # store tag L56
    mov [rbp - 464], r10 # spill L56 to slot
    mov r11, [rbp - 464] # reload L56 from spill slot
    mov r10, r11 # assign L57
    mov r11, [rbp - 1072] # tag L56 from tag-slot
    mov [rbp - 1080], r11 # store tag L57
    mov [rbp - 472], r10 # spill L57 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 2 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1088], r11 # store tag L58
    mov [rbp - 480], r10 # spill L58 to slot
    mov r11, [rbp - 480] # reload L58 from spill slot
    mov r10, r11 # assign L59
    mov r11, [rbp - 1088] # tag L58 from tag-slot
    mov [rbp - 1096], r11 # store tag L59
    mov [rbp - 488], r10 # spill L59 to slot
    mov r11, [rbp - 488] # reload L59 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 472] # reload L57 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1104], r11 # store tag L60
    mov [rbp - 496], r10 # spill L60 to slot
    mov r11, [rbp - 496] # reload L60 from spill slot
    mov r10, r11 # assign L61
    mov r11, [rbp - 1104] # tag L60 from tag-slot
    mov [rbp - 1112], r11 # store tag L61
    mov [rbp - 504], r10 # spill L61 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 504] # reload L61 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1120], r11 # store tag L62
    mov [rbp - 512], r10 # spill L62 to slot
    mov r10, [rbp - 512] # reload L62 from spill slot
    test r10, r10 # br_cond test
    jz .L0436_rt_eq_scalar_native_bb6 # jump-if-zero -> else
    jmp .L0436_rt_eq_scalar_native_bb5 # jump -> then
.L0436_rt_eq_scalar_native_bb5:
    mov r11, r12 # hv payload
    mov r10, rbx # hv payload
    cmp r10, r11 # __hx_payload_le: cmp payloads
    setle al # __hx_payload_le: al = predicate
    movzx r10, al # __hx_payload_le: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1136], r11 # store tag L64
    mov [rbp - 528], r10 # spill L64 to slot
    mov r11, [rbp - 528] # reload L64 from spill slot
    mov r10, r11 # assign L65
    mov r11, [rbp - 1136] # tag L64 from tag-slot
    mov [rbp - 1144], r11 # store tag L65
    mov [rbp - 536], r10 # spill L65 to slot
    mov r11, r12 # hv payload
    mov r10, rbx # hv payload
    cmp r10, r11 # __hx_payload_ge: cmp payloads
    setge al # __hx_payload_ge: al = predicate
    movzx r10, al # __hx_payload_ge: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1152], r11 # store tag L66
    mov [rbp - 544], r10 # spill L66 to slot
    mov r11, [rbp - 544] # reload L66 from spill slot
    mov r10, r11 # assign L67
    mov r11, [rbp - 1152] # tag L66 from tag-slot
    mov [rbp - 1160], r11 # store tag L67
    mov [rbp - 552], r10 # spill L67 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 536] # reload L65 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1168], r11 # store tag L68
    mov [rbp - 560], r10 # spill L68 to slot
    mov r11, [rbp - 560] # reload L68 from spill slot
    mov r10, r11 # assign L69
    mov r11, [rbp - 1168] # tag L68 from tag-slot
    mov [rbp - 1176], r11 # store tag L69
    mov [rbp - 568], r10 # spill L69 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 552] # reload L67 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1184], r11 # store tag L70
    mov [rbp - 576], r10 # spill L70 to slot
    mov r11, [rbp - 576] # reload L70 from spill slot
    mov r10, r11 # assign L71
    mov r11, [rbp - 1184] # tag L70 from tag-slot
    mov [rbp - 1192], r11 # store tag L71
    mov [rbp - 584], r10 # spill L71 to slot
    mov r11, [rbp - 584] # reload L71 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 568] # reload L69 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1200], r11 # store tag L72
    mov [rbp - 592], r10 # spill L72 to slot
    mov r11, [rbp - 592] # reload L72 from spill slot
    mov r10, r11 # assign L73
    mov r11, [rbp - 1200] # tag L72 from tag-slot
    mov [rbp - 1208], r11 # store tag L73
    mov [rbp - 600], r10 # spill L73 to slot
    mov r10, [rbp - 600] # reload L73 from spill slot
    mov r10, r10 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 1216], r11 # store tag L74
    mov [rbp - 608], r10 # spill L74 to slot
    mov rdx, [rbp - 608] # reload L74 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 1216] # tag L74 from tag-slot
    add rsp, 1184 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_eq_scalar_native_bb6:
    mov r10, 0 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 1224], r11 # store tag L75
    mov [rbp - 616], r10 # spill L75 to slot
    mov rdx, [rbp - 616] # reload L75 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 1224] # tag L75 from tag-slot
    add rsp, 1184 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_to_int_native
.hidden rt_to_int_native
    .p2align 4
rt_to_int_native:
    .loc 1 378 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 128 # prologue: alloc spill frame
    mov [rbp - 96], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.L0436_rt_to_int_native_bb0:
    mov r12, [rbp - 96] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 104], r11 # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 104] # tag L1 from tag-slot
    mov [rbp - 112], r11 # store tag L2
    mov r10, r13 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r14, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 120], r11 # store tag L3
    test r14, r14 # br_cond test
    jz .L0436_rt_to_int_native_bb2 # jump-if-zero -> else
    jmp .L0436_rt_to_int_native_bb1 # jump -> then
.L0436_rt_to_int_native_bb1:
    mov rdx, rbx # hv arg payload
    mov rax, [rbp - 96] # tag L0 from tag-slot
    add rsp, 128 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_to_int_native_bb2:
    mov r10, rbx # hv payload
    movq xmm0, r10 # __hx_payload_f2i: xmm0 = v.f bits
    cvttsd2si r10, xmm0 # __hx_payload_f2i: r10 = (i64)trunc(v.f)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 136], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 136] # tag L5 from tag-slot
    mov [rbp - 144], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 152], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 152] # tag L7 from tag-slot
    mov [rbp - 160], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    mov [rbp - 168], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov rdx, [rbp - 88] # reload L9 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 168] # tag L9 from tag-slot
    add rsp, 128 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_to_float_native
.hidden rt_to_float_native
    .p2align 4
rt_to_float_native:
    .loc 1 387 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 128 # prologue: alloc spill frame
    mov [rbp - 96], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.L0436_rt_to_float_native_bb0:
    mov r12, [rbp - 96] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 104], r11 # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 104] # tag L1 from tag-slot
    mov [rbp - 112], r11 # store tag L2
    mov r10, r13 # hv payload
    mov r11, 1 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r14, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 120], r11 # store tag L3
    test r14, r14 # br_cond test
    jz .L0436_rt_to_float_native_bb2 # jump-if-zero -> else
    jmp .L0436_rt_to_float_native_bb1 # jump -> then
.L0436_rt_to_float_native_bb1:
    mov rdx, rbx # hv arg payload
    mov rax, [rbp - 96] # tag L0 from tag-slot
    add rsp, 128 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_to_float_native_bb2:
    mov r10, rbx # hv payload
    cvtsi2sd xmm0, r10 # __hx_payload_i2f: xmm0 = (double)v.i
    movq r10, xmm0 # __hx_payload_i2f: r10 = converted bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 136], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 136] # tag L5 from tag-slot
    mov [rbp - 144], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 152], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 152] # tag L7 from tag-slot
    mov [rbp - 160], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov r10, r10 # hv payload
    mov r11, 1 # hv payload
    mov [rbp - 168], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov rdx, [rbp - 88] # reload L9 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 168] # tag L9 from tag-slot
    add rsp, 128 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_abs_native
.hidden rt_abs_native
    .p2align 4
rt_abs_native:
    .loc 1 397 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 464 # prologue: alloc spill frame
    mov [rbp - 264], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.L0436_rt_abs_native_bb0:
    mov r12, [rbp - 264] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 272], r11 # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 272] # tag L1 from tag-slot
    mov [rbp - 280], r11 # store tag L2
    mov r10, r13 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r14, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 288], r11 # store tag L3
    test r14, r14 # br_cond test
    jz .L0436_rt_abs_native_bb2 # jump-if-zero -> else
    jmp .L0436_rt_abs_native_bb1 # jump -> then
.L0436_rt_abs_native_bb1:
    mov r10, 0 # hv payload
    mov r11, 0 # hv payload
    mov [rbp - 304], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 304] # tag L5 from tag-slot
    mov [rbp - 312], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r11, r11 # hv payload
    mov r10, rbx # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 320], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 320] # tag L7 from tag-slot
    mov [rbp - 328], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 336], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r10, r11 # assign L10
    mov r11, [rbp - 336] # tag L9 from tag-slot
    mov [rbp - 344], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 352], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 104] # reload L11 from spill slot
    test r10, r10 # br_cond test
    jz .L0436_rt_abs_native_bb4 # jump-if-zero -> else
    jmp .L0436_rt_abs_native_bb3 # jump -> then
.L0436_rt_abs_native_bb2:
    mov r10, 0 # hv payload
    mov rax, 0 # tag default = TAG_INT
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 408], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov r10, r11 # assign L19
    mov r11, [rbp - 408] # tag L18 from tag-slot
    mov [rbp - 416], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r10, rbx # hv payload
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov r11, r11 # hv payload
    movq xmm0, r10 # __hx_payload_flt: xmm0 = a.f bits
    movq xmm1, r11 # __hx_payload_flt: xmm1 = b.f bits
    comisd xmm1, xmm0 # __hx_payload_flt: comisd (NaN-correct ordered)
    seta al # __hx_payload_flt: al = predicate
    movzx r10, al # __hx_payload_flt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 424], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r11, [rbp - 176] # reload L20 from spill slot
    mov r10, r11 # assign L21
    mov r11, [rbp - 424] # tag L20 from tag-slot
    mov [rbp - 432], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 184] # reload L21 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 440], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r10, r11 # assign L23
    mov r11, [rbp - 440] # tag L22 from tag-slot
    mov [rbp - 448], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r10, [rbp - 200] # reload L23 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 456], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r10, [rbp - 208] # reload L24 from spill slot
    test r10, r10 # br_cond test
    jz .L0436_rt_abs_native_bb6 # jump-if-zero -> else
    jmp .L0436_rt_abs_native_bb5 # jump -> then
.L0436_rt_abs_native_bb3:
    mov rdx, rbx # hv arg payload
    mov rax, [rbp - 264] # tag L0 from tag-slot
    add rsp, 464 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_abs_native_bb4:
    mov r11, rbx # hv payload
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 368], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov r10, r11 # assign L14
    mov r11, [rbp - 368] # tag L13 from tag-slot
    mov [rbp - 376], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 128] # reload L14 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 384], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, [rbp - 136] # reload L15 from spill slot
    mov r10, r11 # assign L16
    mov r11, [rbp - 384] # tag L15 from tag-slot
    mov [rbp - 392], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r10, [rbp - 144] # reload L16 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    mov [rbp - 400], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov rdx, [rbp - 152] # reload L17 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 400] # tag L17 from tag-slot
    add rsp, 464 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_abs_native_bb5:
    mov rdx, rbx # hv arg payload
    mov rax, [rbp - 264] # tag L0 from tag-slot
    add rsp, 464 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_abs_native_bb6:
    mov r10, [rbp - 168] # reload L19 from spill slot
    mov r10, r10 # hv payload
    mov r11, rbx # hv payload
    movq xmm0, r10 # __hx_payload_fsub: xmm0 = a.f bits
    movq xmm1, r11 # __hx_payload_fsub: xmm1 = b.f bits
    subsd xmm0, xmm1 # __hx_payload_fsub: xmm0 = a.f subsd b.f
    movq r10, xmm0 # __hx_payload_fsub: r10 = result bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 472], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r11, [rbp - 224] # reload L26 from spill slot
    mov r10, r11 # assign L27
    mov r11, [rbp - 472] # tag L26 from tag-slot
    mov [rbp - 480], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 232] # reload L27 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 488], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r11, [rbp - 240] # reload L28 from spill slot
    mov r10, r11 # assign L29
    mov r11, [rbp - 488] # tag L28 from tag-slot
    mov [rbp - 496], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r10, [rbp - 248] # reload L29 from spill slot
    mov r10, r10 # hv payload
    mov r11, 1 # hv payload
    mov [rbp - 504], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov rdx, [rbp - 256] # reload L30 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 504] # tag L30 from tag-slot
    add rsp, 464 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_null_coal_native
.hidden rt_null_coal_native
    .p2align 4
rt_null_coal_native:
    .loc 1 418 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 320 # prologue: alloc spill frame
    mov [rbp - 192], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 200], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L0436_rt_null_coal_native_bb0:
    mov r13, [rbp - 192] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 208], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 208] # tag L2 from tag-slot
    mov [rbp - 216], r11 # store tag L3
    mov r10, r14 # hv payload
    mov r11, 4 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r15, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 224], r11 # store tag L4
    test r15, r15 # br_cond test
    jz .L0436_rt_null_coal_native_bb2 # jump-if-zero -> else
    jmp .L0436_rt_null_coal_native_bb1 # jump -> then
.L0436_rt_null_coal_native_bb1:
    mov rdx, r12 # hv arg payload
    mov rax, [rbp - 200] # tag L1 from tag-slot
    add rsp, 320 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_null_coal_native_bb2:
    mov r10, r14 # hv payload
    mov r11, 3 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 240], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    test r10, r10 # br_cond test
    jz .L0436_rt_null_coal_native_bb4 # jump-if-zero -> else
    jmp .L0436_rt_null_coal_native_bb3 # jump -> then
.L0436_rt_null_coal_native_bb3:
    mov r10, rbx # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 256], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 256] # tag L8 from tag-slot
    mov [rbp - 264], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov r10, r10 # hv payload
    cmp r10, 0 # __hx_payload_nz: cmp payload, 0
    setne al # __hx_payload_nz: al = (pl != 0)
    movzx r10, al # __hx_payload_nz: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 272], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 272] # tag L10 from tag-slot
    mov [rbp - 280], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 288], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 288] # tag L12 from tag-slot
    mov [rbp - 296], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 304], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r10, [rbp - 128] # reload L14 from spill slot
    test r10, r10 # br_cond test
    jz .L0436_rt_null_coal_native_bb6 # jump-if-zero -> else
    jmp .L0436_rt_null_coal_native_bb5 # jump -> then
.L0436_rt_null_coal_native_bb4:
    mov rdx, rbx # hv arg payload
    mov rax, [rbp - 192] # tag L0 from tag-slot
    add rsp, 320 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_null_coal_native_bb5:
    mov rdx, r12 # hv arg payload
    mov rax, [rbp - 200] # tag L1 from tag-slot
    add rsp, 320 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_null_coal_native_bb6:
    mov r10, rbx # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_str_byte: r10 = s + i
    movzx r10, byte ptr [r10] # __hx_str_byte: r10 = s[i]
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 320], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, [rbp - 320] # tag L16 from tag-slot
    mov [rbp - 328], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 336], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov r10, r11 # assign L19
    mov r11, [rbp - 336] # tag L18 from tag-slot
    mov [rbp - 344], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r10, [rbp - 168] # reload L19 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 352], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, [rbp - 176] # reload L20 from spill slot
    test r10, r10 # br_cond test
    jz .L0436_rt_null_coal_native_bb8 # jump-if-zero -> else
    jmp .L0436_rt_null_coal_native_bb7 # jump -> then
.L0436_rt_null_coal_native_bb7:
    mov rdx, r12 # hv arg payload
    mov rax, [rbp - 200] # tag L1 from tag-slot
    add rsp, 320 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L0436_rt_null_coal_native_bb8:
    mov rdx, rbx # hv arg payload
    mov rax, [rbp - 192] # tag L0 from tag-slot
    add rsp, 320 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .note.GNU-stack,"",@progbits
