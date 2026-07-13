// arr_zeros_leaf_x86_64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE — array ZEROS-LEAF constructors).
// GENERATED: tool/regen_arr_zeros_leaf_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=x86_64-linux-gnu -o arr_zeros_leaf_x86_64.s stdlib/runtime/arr_zeros_leaf.hexa.
//   Provides the 2 boxed-zeros constructor natives (hexa_arr_zeros_leaf{,_int}).
//   ABI: ELF, no underscore. External U-floor: malloc calloc write exit hexa_exit (calloc the only new floor entrant; pair-clean, no shim).
//   Lets stage_resolve_runtime_a define HEXA_RT_CORE_ARRAY_ZEROS_LEAF_NATIVE + ar this
//   .o into runtime.a so the 2 zeros constructors drop from the compiled runtime_core.c.
# hexa-lang emit pass — target=x86_64-linux-gnu
# source: /home/summer/hexa-lang/stdlib/runtime/arr_zeros_leaf.hexa
.intel_syntax noprefix
.file 1 "stdlib/runtime/arr_zeros_leaf.hexa"
.text
.globl hexa_arr_zeros_leaf
.hidden hexa_arr_zeros_leaf
    .p2align 4
hexa_arr_zeros_leaf:
    .loc 1 32 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 576 # prologue: alloc spill frame
    mov [rbp - 320], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.L8cdb_hexa_arr_zeros_leaf_bb0:
    mov rsi, 1 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    mov rcx, 32 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call calloc # call calloc
    mov [rbp - 328], rax # store tag L1
    mov r12, rdx # hv: unbox user-call result payload
    mov r13, r12 # assign L2
    mov r11, 0 # tag L1 = TAG_INT (i64-local, fused)
    mov [rbp - 336], r11 # store tag L2
    mov r10, r13 # hv payload
    mov r11, 5 # hv payload
    mov r14, r10 # leaf: payload → dst L3
    mov [rbp - 344], r11 # store tag L3
    mov r15, r14 # assign L4
    mov r11, [rbp - 344] # tag L3 from tag-slot
    mov [rbp - 352], r11 # store tag L4
    mov r10, [rbp - 320] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 360], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 360] # tag L5 from tag-slot
    mov [rbp - 368], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, 0 # assign L7
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 376], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 384], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    test r10, r10 # br_cond test
    jz .L8cdb_hexa_arr_zeros_leaf_bb2 # jump-if-zero -> else
    jmp .L8cdb_hexa_arr_zeros_leaf_bb1 # jump -> then
.L8cdb_hexa_arr_zeros_leaf_bb1:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 400], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 400] # tag L10 from tag-slot
    mov [rbp - 376], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_bb3 # branch
.L8cdb_hexa_arr_zeros_leaf_bb2:
    mov r10, rbx # hv payload
    movq xmm0, r10 # __hx_payload_f2i: xmm0 = v.f bits
    cvttsd2si r10, xmm0 # __hx_payload_f2i: r10 = (i64)trunc(v.f)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 408], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 408] # tag L11 from tag-slot
    mov [rbp - 376], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_bb3 # branch
.L8cdb_hexa_arr_zeros_leaf_bb3:
    mov r11, 1 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ge: cmp payloads
    setge al # __hx_payload_ge: al = predicate
    movzx r10, al # __hx_payload_ge: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 416], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    test r10, r10 # br_cond test
    jz .L8cdb_hexa_arr_zeros_leaf_bb5 # jump-if-zero -> else
    jmp .L8cdb_hexa_arr_zeros_leaf_bb4 # jump -> then
.L8cdb_hexa_arr_zeros_leaf_bb4:
    mov r11, 16 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 432], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 432] # tag L14 from tag-slot
    mov [rbp - 440], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 440] # tag L15 from tag-slot
    call malloc # call malloc
    mov [rbp - 448], rax # store tag L16
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, 0 # tag L16 = TAG_INT (i64-local, fused)
    mov [rbp - 456], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 464], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r10, [rbp - 160] # reload L18 from spill slot
    test r10, r10 # br_cond test
    jz .L8cdb_hexa_arr_zeros_leaf_bb7 # jump-if-zero -> else
    jmp .L8cdb_hexa_arr_zeros_leaf_bb6 # jump -> then
.L8cdb_hexa_arr_zeros_leaf_bb5:
    mov rdx, r15 # hv arg payload
    mov rax, [rbp - 352] # tag L4 from tag-slot
    add rsp, 576 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L8cdb_hexa_arr_zeros_leaf_bb6:
    lea r10, [rip+.LCstr0] # hv payload: &str .LCstr0
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 480], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r11, [rbp - 176] # reload L20 from spill slot
    mov r10, r11 # assign L21
    mov r11, [rbp - 480] # tag L20 from tag-slot
    mov [rbp - 488], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov rsi, 2 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    mov rcx, [rbp - 184] # reload L21 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 488] # tag L21 from tag-slot
    mov r9, 27 # hv arg payload
    mov r8, 0 # tag default = TAG_INT
    call write # call write
    mov [rbp - 496], rax # store tag L22
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 192], r10 # spill L22 to slot
    mov rsi, 1 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    call hexa_exit # call hexa_exit
    mov [rbp - 504], rax # store tag L23
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 200], r10 # spill L23 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_bb7 # branch
.L8cdb_hexa_arr_zeros_leaf_bb7:
    mov r10, 0 # assign L24
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 512], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r10, r11 # assign L25
    mov r11, [rbp - 376] # tag L7 from tag-slot
    mov [rbp - 520], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 216] # reload L25 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ge: cmp payloads
    setge al # __hx_payload_ge: al = predicate
    movzx r10, al # __hx_payload_ge: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 528], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r11, [rbp - 224] # reload L26 from spill slot
    mov r10, r11 # assign L27
    mov r11, [rbp - 528] # tag L26 from tag-slot
    mov [rbp - 536], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_bb8 # branch
.L8cdb_hexa_arr_zeros_leaf_bb8:
    mov r10, [rbp - 232] # reload L27 from spill slot
    test r10, r10 # br_cond test
    jz .L8cdb_hexa_arr_zeros_leaf_bb10 # jump-if-zero -> else
    jmp .L8cdb_hexa_arr_zeros_leaf_bb9 # jump -> then
.L8cdb_hexa_arr_zeros_leaf_bb9:
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 208] # reload L24 from spill slot
    mov r11, r11 # hv payload
    mov rsi, 1 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 544], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r11, 8 # hv payload
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 552], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r11, [rbp - 248] # reload L29 from spill slot
    mov r10, r11 # assign L30
    mov r11, [rbp - 552] # tag L29 from tag-slot
    mov [rbp - 560], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 256] # reload L30 from spill slot
    mov r11, r11 # hv payload
    mov rsi, 0 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 568], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov r11, 16 # hv payload
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 576], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r11, [rbp - 272] # reload L32 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 576] # tag L32 from tag-slot
    mov [rbp - 512], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 216] # reload L25 from spill slot
    mov r10, r10 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 584], r11 # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r11, [rbp - 280] # reload L33 from spill slot
    mov r10, r11 # assign L25
    mov r11, [rbp - 584] # tag L33 from tag-slot
    mov [rbp - 520], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 216] # reload L25 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ge: cmp payloads
    setge al # __hx_payload_ge: al = predicate
    movzx r10, al # __hx_payload_ge: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 592], r11 # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    mov r11, [rbp - 288] # reload L34 from spill slot
    mov r10, r11 # assign L27
    mov r11, [rbp - 592] # tag L34 from tag-slot
    mov [rbp - 536], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_bb8 # branch
.L8cdb_hexa_arr_zeros_leaf_bb10:
    mov r10, r13 # hv payload
    mov r11, 0 # hv payload
    mov rsi, [rbp - 152] # reload L17 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r13 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 600], r11 # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    mov r10, r13 # hv payload
    mov r11, 8 # hv payload
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r13 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 608], r11 # store tag L36
    mov [rbp - 304], r10 # spill L36 to slot
    mov r10, r13 # hv payload
    mov r11, 16 # hv payload
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r13 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 616], r11 # store tag L37
    mov [rbp - 312], r10 # spill L37 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_bb5 # branch
    mov eax, 4 # value-less return: tag = TAG_VOID
    xor edx, edx # value-less return: payload = 0
    add rsp, 576 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_arr_zeros_leaf_int
.hidden hexa_arr_zeros_leaf_int
    .p2align 4
hexa_arr_zeros_leaf_int:
    .loc 1 70 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 576 # prologue: alloc spill frame
    mov [rbp - 320], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.L8cdb_hexa_arr_zeros_leaf_int_bb0:
    mov rsi, 1 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    mov rcx, 32 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call calloc # call calloc
    mov [rbp - 328], rax # store tag L1
    mov r12, rdx # hv: unbox user-call result payload
    mov r13, r12 # assign L2
    mov r11, 0 # tag L1 = TAG_INT (i64-local, fused)
    mov [rbp - 336], r11 # store tag L2
    mov r10, r13 # hv payload
    mov r11, 5 # hv payload
    mov r14, r10 # leaf: payload → dst L3
    mov [rbp - 344], r11 # store tag L3
    mov r15, r14 # assign L4
    mov r11, [rbp - 344] # tag L3 from tag-slot
    mov [rbp - 352], r11 # store tag L4
    mov r10, [rbp - 320] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 360], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 360] # tag L5 from tag-slot
    mov [rbp - 368], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, 0 # assign L7
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 376], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 384], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    test r10, r10 # br_cond test
    jz .L8cdb_hexa_arr_zeros_leaf_int_bb2 # jump-if-zero -> else
    jmp .L8cdb_hexa_arr_zeros_leaf_int_bb1 # jump -> then
.L8cdb_hexa_arr_zeros_leaf_int_bb1:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 400], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 400] # tag L10 from tag-slot
    mov [rbp - 376], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_int_bb3 # branch
.L8cdb_hexa_arr_zeros_leaf_int_bb2:
    mov r10, rbx # hv payload
    movq xmm0, r10 # __hx_payload_f2i: xmm0 = v.f bits
    cvttsd2si r10, xmm0 # __hx_payload_f2i: r10 = (i64)trunc(v.f)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 408], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 408] # tag L11 from tag-slot
    mov [rbp - 376], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_int_bb3 # branch
.L8cdb_hexa_arr_zeros_leaf_int_bb3:
    mov r11, 1 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ge: cmp payloads
    setge al # __hx_payload_ge: al = predicate
    movzx r10, al # __hx_payload_ge: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 416], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    test r10, r10 # br_cond test
    jz .L8cdb_hexa_arr_zeros_leaf_int_bb5 # jump-if-zero -> else
    jmp .L8cdb_hexa_arr_zeros_leaf_int_bb4 # jump -> then
.L8cdb_hexa_arr_zeros_leaf_int_bb4:
    mov r11, 16 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 432], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 432] # tag L14 from tag-slot
    mov [rbp - 440], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 440] # tag L15 from tag-slot
    call malloc # call malloc
    mov [rbp - 448], rax # store tag L16
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, 0 # tag L16 = TAG_INT (i64-local, fused)
    mov [rbp - 456], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 464], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r10, [rbp - 160] # reload L18 from spill slot
    test r10, r10 # br_cond test
    jz .L8cdb_hexa_arr_zeros_leaf_int_bb7 # jump-if-zero -> else
    jmp .L8cdb_hexa_arr_zeros_leaf_int_bb6 # jump -> then
.L8cdb_hexa_arr_zeros_leaf_int_bb5:
    mov rdx, r15 # hv arg payload
    mov rax, [rbp - 352] # tag L4 from tag-slot
    add rsp, 576 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L8cdb_hexa_arr_zeros_leaf_int_bb6:
    lea r10, [rip+.LCstr1] # hv payload: &str .LCstr1
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 480], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r11, [rbp - 176] # reload L20 from spill slot
    mov r10, r11 # assign L21
    mov r11, [rbp - 480] # tag L20 from tag-slot
    mov [rbp - 488], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov rsi, 2 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    mov rcx, [rbp - 184] # reload L21 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 488] # tag L21 from tag-slot
    mov r9, 31 # hv arg payload
    mov r8, 0 # tag default = TAG_INT
    call write # call write
    mov [rbp - 496], rax # store tag L22
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 192], r10 # spill L22 to slot
    mov rsi, 1 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    call hexa_exit # call hexa_exit
    mov [rbp - 504], rax # store tag L23
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 200], r10 # spill L23 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_int_bb7 # branch
.L8cdb_hexa_arr_zeros_leaf_int_bb7:
    mov r10, 0 # assign L24
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 512], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r10, r11 # assign L25
    mov r11, [rbp - 376] # tag L7 from tag-slot
    mov [rbp - 520], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 216] # reload L25 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ge: cmp payloads
    setge al # __hx_payload_ge: al = predicate
    movzx r10, al # __hx_payload_ge: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 528], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r11, [rbp - 224] # reload L26 from spill slot
    mov r10, r11 # assign L27
    mov r11, [rbp - 528] # tag L26 from tag-slot
    mov [rbp - 536], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_int_bb8 # branch
.L8cdb_hexa_arr_zeros_leaf_int_bb8:
    mov r10, [rbp - 232] # reload L27 from spill slot
    test r10, r10 # br_cond test
    jz .L8cdb_hexa_arr_zeros_leaf_int_bb10 # jump-if-zero -> else
    jmp .L8cdb_hexa_arr_zeros_leaf_int_bb9 # jump -> then
.L8cdb_hexa_arr_zeros_leaf_int_bb9:
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 208] # reload L24 from spill slot
    mov r11, r11 # hv payload
    mov rsi, 0 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 544], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r11, 8 # hv payload
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 552], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r11, [rbp - 248] # reload L29 from spill slot
    mov r10, r11 # assign L30
    mov r11, [rbp - 552] # tag L29 from tag-slot
    mov [rbp - 560], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 256] # reload L30 from spill slot
    mov r11, r11 # hv payload
    mov rsi, 0 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 568], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov r11, 16 # hv payload
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 576], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r11, [rbp - 272] # reload L32 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 576] # tag L32 from tag-slot
    mov [rbp - 512], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 216] # reload L25 from spill slot
    mov r10, r10 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 584], r11 # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r11, [rbp - 280] # reload L33 from spill slot
    mov r10, r11 # assign L25
    mov r11, [rbp - 584] # tag L33 from tag-slot
    mov [rbp - 520], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 216] # reload L25 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ge: cmp payloads
    setge al # __hx_payload_ge: al = predicate
    movzx r10, al # __hx_payload_ge: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 592], r11 # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    mov r11, [rbp - 288] # reload L34 from spill slot
    mov r10, r11 # assign L27
    mov r11, [rbp - 592] # tag L34 from tag-slot
    mov [rbp - 536], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_int_bb8 # branch
.L8cdb_hexa_arr_zeros_leaf_int_bb10:
    mov r10, r13 # hv payload
    mov r11, 0 # hv payload
    mov rsi, [rbp - 152] # reload L17 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r13 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 600], r11 # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    mov r10, r13 # hv payload
    mov r11, 8 # hv payload
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r13 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 608], r11 # store tag L36
    mov [rbp - 304], r10 # spill L36 to slot
    mov r10, r13 # hv payload
    mov r11, 16 # hv payload
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r13 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 616], r11 # store tag L37
    mov [rbp - 312], r10 # spill L37 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_int_bb5 # branch
    mov eax, 4 # value-less return: tag = TAG_VOID
    xor edx, edx # value-less return: payload = 0
    add rsp, 576 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.section .rodata
.LCstr0:
    .byte 0x4f, 0x4f, 0x4d, 0x20, 0x69, 0x6e, 0x20, 0x68, 0x65, 0x78, 0x61, 0x5f, 0x61, 0x72, 0x72, 0x5f
    .byte 0x7a, 0x65, 0x72, 0x6f, 0x73, 0x5f, 0x6c, 0x65, 0x61, 0x66, 0x0a, 0x00
.section .rodata
.LCstr1:
    .byte 0x4f, 0x4f, 0x4d, 0x20, 0x69, 0x6e, 0x20, 0x68, 0x65, 0x78, 0x61, 0x5f, 0x61, 0x72, 0x72, 0x5f
    .byte 0x7a, 0x65, 0x72, 0x6f, 0x73, 0x5f, 0x6c, 0x65, 0x61, 0x66, 0x5f, 0x69, 0x6e, 0x74, 0x0a, 0x00
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .note.GNU-stack,"",@progbits
