// intern_core_x86_64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 INTERN-R1).
// GENERATED: tool/regen_intern_core_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=x86_64-linux-gnu -o intern_core_x86_64.s stdlib/runtime/intern_core.hexa.
//   Provides the intern-core READ-half (rt_intern_find_native /
//   rt_intern_strcmp0_native) as native raw-mem bodies — the open-addressing
//   find probe over HexaInternTable char** buckets + uint32_t* hashes
//   (__hx_ptr_load64/load8 + __hx_payload_* + __hx_make_val). These intrinsics
//   are gen2-native-only (the hexat C-transpile bootstrap cannot lower them),
//   so the bodies enter the shipped runtime.a ONLY via this seed.
//   ABI: ELF, rt_intern_*_native no underscore. External: none (rt_intern_strcmp0_native is local).
//   Lets stage_resolve_runtime_a define HEXA_RT_INTERN_NATIVE + ar this .o into
//   runtime.a so hexa_intern delegates its find half to the native body.
# hexa-lang emit pass — target=x86_64-linux-gnu
# source: /home/aiden/hexa-lang/stdlib/runtime/intern_core.hexa
.intel_syntax noprefix
.file 1 "stdlib/runtime/intern_core.hexa"
.text
.globl rt_intern_strcmp0_native
.hidden rt_intern_strcmp0_native
    .p2align 4
rt_intern_strcmp0_native:
    .loc 1 48 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 176 # prologue: alloc spill frame
    mov [rbp - 120], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 128], rdx # store tag L1
    mov r12, rcx # ingress param payload
.Le37b_rt_intern_strcmp0_native_bb0:
    mov r13, 0 # assign L2
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 136], r11 # store tag L2
    mov r10, rbx # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r14, r10 # leaf: payload → dst L3
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 144], r11 # store tag L3
    mov r15, r14 # assign L4
    mov r11, [rbp - 144] # tag L3 from tag-slot
    mov [rbp - 152], r11 # store tag L4
    mov r10, r12 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 160], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 160] # tag L5 from tag-slot
    mov [rbp - 168], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    jmp .Le37b_rt_intern_strcmp0_native_bb1 # branch
.Le37b_rt_intern_strcmp0_native_bb1:
    mov r10, r15 # hv payload
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r11, r11 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 176], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    test r10, r10 # br_cond test
    jz .Le37b_rt_intern_strcmp0_native_bb3 # jump-if-zero -> else
    jmp .Le37b_rt_intern_strcmp0_native_bb2 # jump -> then
.Le37b_rt_intern_strcmp0_native_bb2:
    mov r10, r15 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 184], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    test r10, r10 # br_cond test
    jz .Le37b_rt_intern_strcmp0_native_bb5 # jump-if-zero -> else
    jmp .Le37b_rt_intern_strcmp0_native_bb4 # jump -> then
.Le37b_rt_intern_strcmp0_native_bb3:
    mov rdx, 1 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 176 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Le37b_rt_intern_strcmp0_native_bb4:
    mov rdx, 0 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 176 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Le37b_rt_intern_strcmp0_native_bb5:
    mov r11, 1 # hv payload
    mov r10, r13 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 200], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov r13, r10 # assign L2
    mov r11, [rbp - 200] # tag L10 from tag-slot
    mov [rbp - 136], r11 # store tag L2
    mov r10, rbx # hv payload
    mov r11, r13 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 208], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r15, r10 # assign L4
    mov r11, [rbp - 208] # tag L11 from tag-slot
    mov [rbp - 152], r11 # store tag L4
    mov r10, r12 # hv payload
    mov r11, r13 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 216], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 216] # tag L12 from tag-slot
    mov [rbp - 168], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    jmp .Le37b_rt_intern_strcmp0_native_bb1 # branch
    add rsp, 176 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_intern_find_native
.hidden rt_intern_find_native
    .p2align 4
rt_intern_find_native:
    .loc 1 72 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 736 # prologue: alloc spill frame
    mov [rbp - 400], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 408], rdx # store tag L1
    mov r12, rcx # ingress param payload
    mov [rbp - 416], r8 # store tag L2
    mov r13, r9 # ingress param payload
    mov r10, [rbp + 16] # ingress stack param 3 tag
    mov [rbp - 424], r10 # store tag L3
    mov r10, [rbp + 24] # ingress stack param 3 payload
    mov r14, r10 # ingress stack param payload
    mov r10, [rbp + 32] # ingress stack param 4 tag
    mov [rbp - 432], r10 # store tag L4
    mov r10, [rbp + 40] # ingress stack param 4 payload
    mov r15, r10 # ingress stack param payload
.Le37b_rt_intern_find_native_bb0:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 440], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 440] # tag L5 from tag-slot
    mov [rbp - 448], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, 0 # hv payload
    mov r10, r12 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 456], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 456] # tag L7 from tag-slot
    mov [rbp - 464], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, 0 # hv payload
    mov r10, r13 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 472], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r10, r11 # assign L10
    mov r11, [rbp - 472] # tag L9 from tag-slot
    mov [rbp - 480], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, 4294967295 # hv payload
    mov r10, r14 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 488], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 488] # tag L11 from tag-slot
    mov [rbp - 496], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov r10, r10 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 504], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov r10, r11 # assign L14
    mov r11, [rbp - 504] # tag L13 from tag-slot
    mov [rbp - 512], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 520], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, [rbp - 136] # reload L15 from spill slot
    mov r10, r11 # assign L16
    mov r11, [rbp - 520] # tag L15 from tag-slot
    mov [rbp - 528], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r10, 0 # assign L17
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 536], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    jmp .Le37b_rt_intern_find_native_bb1 # branch
.Le37b_rt_intern_find_native_bb1:
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 544], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r10, [rbp - 160] # reload L18 from spill slot
    test r10, r10 # br_cond test
    jz .Le37b_rt_intern_find_native_bb3 # jump-if-zero -> else
    jmp .Le37b_rt_intern_find_native_bb2 # jump -> then
.Le37b_rt_intern_find_native_bb2:
    mov r11, 8 # hv payload
    mov r10, [rbp - 144] # reload L16 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 552], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov r10, r11 # assign L20
    mov r11, [rbp - 552] # tag L19 from tag-slot
    mov [rbp - 560], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r11, [rbp - 176] # reload L20 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 568], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 568] # tag L21 from tag-slot
    mov [rbp - 576], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r10, [rbp - 192] # reload L22 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 584], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 584] # tag L23 from tag-slot
    mov [rbp - 592], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 600], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r10, [rbp - 216] # reload L25 from spill slot
    test r10, r10 # br_cond test
    jz .Le37b_rt_intern_find_native_bb5 # jump-if-zero -> else
    jmp .Le37b_rt_intern_find_native_bb4 # jump -> then
.Le37b_rt_intern_find_native_bb3:
    mov r10, 0 # hv payload
    mov r11, 0 # hv payload
    mov [rbp - 776], r11 # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    mov rdx, [rbp - 392] # reload L47 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 776] # tag L47 from tag-slot
    add rsp, 736 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Le37b_rt_intern_find_native_bb4:
    mov r10, 0 # hv payload
    mov r11, 0 # hv payload
    mov [rbp - 616], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov rdx, [rbp - 232] # reload L27 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 616] # tag L27 from tag-slot
    add rsp, 736 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Le37b_rt_intern_find_native_bb5:
    mov r11, 4 # hv payload
    mov r10, [rbp - 144] # reload L16 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 624], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r11, [rbp - 240] # reload L28 from spill slot
    mov r10, r11 # assign L29
    mov r11, [rbp - 624] # tag L28 from tag-slot
    mov [rbp - 632], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r11, [rbp - 248] # reload L29 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 640], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r11, [rbp - 256] # reload L30 from spill slot
    mov r10, r11 # assign L31
    mov r11, [rbp - 640] # tag L30 from tag-slot
    mov [rbp - 648], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov r10, [rbp - 264] # reload L31 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 656], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r11, [rbp - 272] # reload L32 from spill slot
    mov r10, r11 # assign L33
    mov r11, [rbp - 656] # tag L32 from tag-slot
    mov [rbp - 664], r11 # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r11, 4294967295 # hv payload
    mov r10, [rbp - 280] # reload L33 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 672], r11 # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    mov r11, [rbp - 288] # reload L34 from spill slot
    mov r10, r11 # assign L35
    mov r11, [rbp - 672] # tag L34 from tag-slot
    mov [rbp - 680], r11 # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    mov r10, [rbp - 296] # reload L35 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r11, r11 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 688], r11 # store tag L36
    mov [rbp - 304], r10 # spill L36 to slot
    mov r10, [rbp - 304] # reload L36 from spill slot
    test r10, r10 # br_cond test
    jz .Le37b_rt_intern_find_native_bb7 # jump-if-zero -> else
    jmp .Le37b_rt_intern_find_native_bb6 # jump -> then
.Le37b_rt_intern_find_native_bb6:
    mov rsi, [rbp - 208] # reload L24 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 592] # tag L24 from tag-slot
    mov rcx, r15 # hv arg payload
    mov rdx, [rbp - 432] # tag L4 from tag-slot
    call rt_intern_strcmp0_native # call rt_intern_strcmp0_native
    mov [rbp - 704], rax # store tag L38
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 320], r10 # spill L38 to slot
    mov r11, [rbp - 320] # reload L38 from spill slot
    mov r10, r11 # assign L39
    mov r11, [rbp - 704] # tag L38 from tag-slot
    mov [rbp - 712], r11 # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    mov r10, [rbp - 328] # reload L39 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 720], r11 # store tag L40
    mov [rbp - 336], r10 # spill L40 to slot
    mov r10, [rbp - 336] # reload L40 from spill slot
    test r10, r10 # br_cond test
    jz .Le37b_rt_intern_find_native_bb9 # jump-if-zero -> else
    jmp .Le37b_rt_intern_find_native_bb8 # jump -> then
.Le37b_rt_intern_find_native_bb7:
    mov r11, 1 # hv payload
    mov r10, [rbp - 144] # reload L16 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 744], r11 # store tag L43
    mov [rbp - 360], r10 # spill L43 to slot
    mov r11, [rbp - 360] # reload L43 from spill slot
    mov r10, r11 # assign L44
    mov r11, [rbp - 744] # tag L43 from tag-slot
    mov [rbp - 752], r11 # store tag L44
    mov [rbp - 368], r10 # spill L44 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 368] # reload L44 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 760], r11 # store tag L45
    mov [rbp - 376], r10 # spill L45 to slot
    mov r11, [rbp - 376] # reload L45 from spill slot
    mov r10, r11 # assign L16
    mov r11, [rbp - 760] # tag L45 from tag-slot
    mov [rbp - 528], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 768], r11 # store tag L46
    mov [rbp - 384], r10 # spill L46 to slot
    mov r11, [rbp - 384] # reload L46 from spill slot
    mov r10, r11 # assign L17
    mov r11, [rbp - 768] # tag L46 from tag-slot
    mov [rbp - 536], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    jmp .Le37b_rt_intern_find_native_bb1 # branch
.Le37b_rt_intern_find_native_bb8:
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    mov [rbp - 736], r11 # store tag L42
    mov [rbp - 352], r10 # spill L42 to slot
    mov rdx, [rbp - 352] # reload L42 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 736] # tag L42 from tag-slot
    add rsp, 736 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Le37b_rt_intern_find_native_bb9:
    jmp .Le37b_rt_intern_find_native_bb7 # branch
    add rsp, 736 # epilogue: free spill frame
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
