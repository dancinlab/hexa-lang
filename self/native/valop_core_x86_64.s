// valop_core_x86_64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 VALOP — sh-val-core).
// GENERATED: tool/regen_valop_core_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=x86_64-linux-gnu -o valop_core_x86_64.s stdlib/runtime/valop_core.hexa.
//   Provides the SCALAR value-op core (rt_truthy_native, rt_sub_native,
//   rt_mul_native) as native raw-mem bodies: __hx_tag tag-read + raw int/
//   float payload arithmetic + __hx_make_val re-box, byte-faithful to the C
//   hexa_truthy/hexa_sub/hexa_mul scalar switch arms. These intrinsics are
//   gen2-native-only (the hexat C-transpile bootstrap cannot lower them), so
//   the bodies enter the shipped runtime.a ONLY via this seed — the array/
//   num_core mechanism (resolve_native_valop_core_seed).
//   ABI: ELF, no underscore. External: NONE (fully self-contained).
//   Lets stage_resolve_runtime_a define HEXA_RT_VALOP_NATIVE + ar this .o
//   into runtime.a so hexa_truthy/hexa_sub/hexa_mul scalar paths go native.
# hexa-lang emit pass — target=x86_64-linux-gnu
# source: /home/aiden/scratch-valcore/stdlib/runtime/valop_core.hexa
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
    sub rsp, 608 # prologue: alloc spill frame
    mov [rbp - 336], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.Le0aa_rt_truthy_native_bb0:
    mov r12, [rbp - 336] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 344], r11 # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 344] # tag L1 from tag-slot
    mov [rbp - 352], r11 # store tag L2
    mov r10, r13 # hv payload
    mov r11, 2 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r14, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 360], r11 # store tag L3
    test r14, r14 # br_cond test
    jz .Le0aa_rt_truthy_native_bb2 # jump-if-zero -> else
    jmp .Le0aa_rt_truthy_native_bb1 # jump -> then
.Le0aa_rt_truthy_native_bb1:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 376], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 376] # tag L5 from tag-slot
    mov [rbp - 384], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 392], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov rdx, [rbp - 72] # reload L7 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 392] # tag L7 from tag-slot
    add rsp, 608 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Le0aa_rt_truthy_native_bb2:
    mov r10, r13 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 400], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    test r10, r10 # br_cond test
    jz .Le0aa_rt_truthy_native_bb4 # jump-if-zero -> else
    jmp .Le0aa_rt_truthy_native_bb3 # jump -> then
.Le0aa_rt_truthy_native_bb3:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 416], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 416] # tag L10 from tag-slot
    mov [rbp - 424], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 432], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 432] # tag L12 from tag-slot
    mov [rbp - 440], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 448], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 448] # tag L14 from tag-slot
    mov [rbp - 456], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov r10, r10 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 464], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov rdx, [rbp - 144] # reload L16 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 464] # tag L16 from tag-slot
    add rsp, 608 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Le0aa_rt_truthy_native_bb4:
    mov r10, r13 # hv payload
    mov r11, 1 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 472], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    test r10, r10 # br_cond test
    jz .Le0aa_rt_truthy_native_bb6 # jump-if-zero -> else
    jmp .Le0aa_rt_truthy_native_bb5 # jump -> then
.Le0aa_rt_truthy_native_bb5:
    mov r10, 0 # hv payload
    mov rax, 0 # tag default = TAG_INT
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 488], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov r10, r11 # assign L20
    mov r11, [rbp - 488] # tag L19 from tag-slot
    mov [rbp - 496], r11 # store tag L20
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
    mov [rbp - 504], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 504] # tag L21 from tag-slot
    mov [rbp - 512], r11 # store tag L22
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
    mov [rbp - 520], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 520] # tag L23 from tag-slot
    mov [rbp - 528], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 192] # reload L22 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 536], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r11, [rbp - 216] # reload L25 from spill slot
    mov r10, r11 # assign L26
    mov r11, [rbp - 536] # tag L25 from tag-slot
    mov [rbp - 544], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 552], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov r11, [rbp - 232] # reload L27 from spill slot
    mov r10, r11 # assign L28
    mov r11, [rbp - 552] # tag L27 from tag-slot
    mov [rbp - 560], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r11, [rbp - 240] # reload L28 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 568], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r11, [rbp - 248] # reload L29 from spill slot
    mov r10, r11 # assign L30
    mov r11, [rbp - 568] # tag L29 from tag-slot
    mov [rbp - 576], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r10, [rbp - 256] # reload L30 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 584], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov r11, [rbp - 264] # reload L31 from spill slot
    mov r10, r11 # assign L32
    mov r11, [rbp - 584] # tag L31 from tag-slot
    mov [rbp - 592], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 600], r11 # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r11, [rbp - 280] # reload L33 from spill slot
    mov r10, r11 # assign L34
    mov r11, [rbp - 600] # tag L33 from tag-slot
    mov [rbp - 608], r11 # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    mov r10, [rbp - 288] # reload L34 from spill slot
    mov r10, r10 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 616], r11 # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    mov rdx, [rbp - 296] # reload L35 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 616] # tag L35 from tag-slot
    add rsp, 608 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Le0aa_rt_truthy_native_bb6:
    mov r10, r13 # hv payload
    mov r11, 4 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 624], r11 # store tag L36
    mov [rbp - 304], r10 # spill L36 to slot
    mov r10, [rbp - 304] # reload L36 from spill slot
    test r10, r10 # br_cond test
    jz .Le0aa_rt_truthy_native_bb8 # jump-if-zero -> else
    jmp .Le0aa_rt_truthy_native_bb7 # jump -> then
.Le0aa_rt_truthy_native_bb7:
    mov r10, 0 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 640], r11 # store tag L38
    mov [rbp - 320], r10 # spill L38 to slot
    mov rdx, [rbp - 320] # reload L38 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 640] # tag L38 from tag-slot
    add rsp, 608 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Le0aa_rt_truthy_native_bb8:
    mov r10, 1 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 648], r11 # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    mov rdx, [rbp - 328] # reload L39 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 648] # tag L39 from tag-slot
    add rsp, 608 # epilogue: free spill frame
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
    .loc 1 109 0
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
.Le0aa_rt_sub_native_bb0:
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
    jz .Le0aa_rt_sub_native_bb2 # jump-if-zero -> else
    jmp .Le0aa_rt_sub_native_bb1 # jump -> then
.Le0aa_rt_sub_native_bb1:
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
.Le0aa_rt_sub_native_bb2:
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
    .loc 1 131 0
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
.Le0aa_rt_mul_native_bb0:
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
    jz .Le0aa_rt_mul_native_bb2 # jump-if-zero -> else
    jmp .Le0aa_rt_mul_native_bb1 # jump -> then
.Le0aa_rt_mul_native_bb1:
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
.Le0aa_rt_mul_native_bb2:
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
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
