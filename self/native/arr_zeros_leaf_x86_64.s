// arr_zeros_leaf_x86_64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE — array ZEROS-LEAF constructors).
// GENERATED: tool/regen_arr_zeros_leaf_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=x86_64-linux-gnu -o arr_zeros_leaf_x86_64.s stdlib/runtime/arr_zeros_leaf.hexa.
//   Provides the 2 boxed-zeros constructor natives (hexa_arr_zeros_leaf{,_int}).
//   ABI: ELF, no underscore. External U-floor: hexa_ptr_alloc hexa_exit — CARRIER-ONLY (HexaVal-ABI); a raw libc U here is a
//   pair-vs-C-ABI miscompile, not a sanctioned floor entrant.
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
    .loc 1 51 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 640 # prologue: alloc spill frame
    mov [rbp - 352], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.L8cdb_hexa_arr_zeros_leaf_bb0:
    mov rsi, 32 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    call hexa_ptr_alloc # call hexa_ptr_alloc
    mov [rbp - 360], rax # store tag L1
    mov r12, rdx # hv: unbox user-call result payload
    mov r13, r12 # assign L2
    mov r11, 0 # tag L1 = TAG_INT (i64-local, fused)
    mov [rbp - 368], r11 # store tag L2
    mov r10, r13 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r14, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 376], r11 # store tag L3
    test r14, r14 # br_cond test
    jz .L8cdb_hexa_arr_zeros_leaf_bb2 # jump-if-zero -> else
    jmp .L8cdb_hexa_arr_zeros_leaf_bb1 # jump -> then
.L8cdb_hexa_arr_zeros_leaf_bb1:
    mov rsi, 1 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    call hexa_exit # call hexa_exit
    mov [rbp - 392], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_bb2 # branch
.L8cdb_hexa_arr_zeros_leaf_bb2:
    mov r10, r13 # hv payload
    mov r11, 0 # hv payload
    mov rsi, 0 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r13 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 400], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, r13 # hv payload
    mov r11, 8 # hv payload
    mov rsi, 0 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r13 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 408], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, r13 # hv payload
    mov r11, 16 # hv payload
    mov rsi, 0 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r13 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 416], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, r13 # hv payload
    mov r11, 24 # hv payload
    mov rsi, 0 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r13 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 424], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, r13 # hv payload
    mov r11, 5 # hv payload
    mov [rbp - 432], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 432] # tag L10 from tag-slot
    mov [rbp - 440], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 352] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 448], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 448] # tag L12 from tag-slot
    mov [rbp - 456], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, 0 # assign L14
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 464], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 472], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    test r10, r10 # br_cond test
    jz .L8cdb_hexa_arr_zeros_leaf_bb4 # jump-if-zero -> else
    jmp .L8cdb_hexa_arr_zeros_leaf_bb3 # jump -> then
.L8cdb_hexa_arr_zeros_leaf_bb3:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 488], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r11, [rbp - 152] # reload L17 from spill slot
    mov r10, r11 # assign L14
    mov r11, [rbp - 488] # tag L17 from tag-slot
    mov [rbp - 464], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_bb5 # branch
.L8cdb_hexa_arr_zeros_leaf_bb4:
    mov r10, rbx # hv payload
    movq xmm0, r10 # __hx_payload_f2i: xmm0 = v.f bits
    cvttsd2si r10, xmm0 # __hx_payload_f2i: r10 = (i64)trunc(v.f)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 496], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov r10, r11 # assign L14
    mov r11, [rbp - 496] # tag L18 from tag-slot
    mov [rbp - 464], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_bb5 # branch
.L8cdb_hexa_arr_zeros_leaf_bb5:
    mov r11, 1 # hv payload
    mov r10, [rbp - 128] # reload L14 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ge: cmp payloads
    setge al # __hx_payload_ge: al = predicate
    movzx r10, al # __hx_payload_ge: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 504], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r10, [rbp - 168] # reload L19 from spill slot
    test r10, r10 # br_cond test
    jz .L8cdb_hexa_arr_zeros_leaf_bb7 # jump-if-zero -> else
    jmp .L8cdb_hexa_arr_zeros_leaf_bb6 # jump -> then
.L8cdb_hexa_arr_zeros_leaf_bb6:
    mov r11, 16 # hv payload
    mov r10, [rbp - 128] # reload L14 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 520], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 520] # tag L21 from tag-slot
    mov [rbp - 528], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov rsi, [rbp - 192] # reload L22 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 528] # tag L22 from tag-slot
    call hexa_ptr_alloc # call hexa_ptr_alloc
    mov [rbp - 536], rax # store tag L23
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L24
    mov r11, 0 # tag L23 = TAG_INT (i64-local, fused)
    mov [rbp - 544], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 552], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r10, [rbp - 216] # reload L25 from spill slot
    test r10, r10 # br_cond test
    jz .L8cdb_hexa_arr_zeros_leaf_bb9 # jump-if-zero -> else
    jmp .L8cdb_hexa_arr_zeros_leaf_bb8 # jump -> then
.L8cdb_hexa_arr_zeros_leaf_bb7:
    mov rdx, [rbp - 104] # reload L11 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 440] # tag L11 from tag-slot
    add rsp, 640 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L8cdb_hexa_arr_zeros_leaf_bb8:
    mov rsi, 1 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    call hexa_exit # call hexa_exit
    mov [rbp - 568], rax # store tag L27
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 232], r10 # spill L27 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_bb9 # branch
.L8cdb_hexa_arr_zeros_leaf_bb9:
    mov r10, 0 # assign L28
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 576], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L29
    mov r11, [rbp - 464] # tag L14 from tag-slot
    mov [rbp - 584], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 248] # reload L29 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ge: cmp payloads
    setge al # __hx_payload_ge: al = predicate
    movzx r10, al # __hx_payload_ge: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 592], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r11, [rbp - 256] # reload L30 from spill slot
    mov r10, r11 # assign L31
    mov r11, [rbp - 592] # tag L30 from tag-slot
    mov [rbp - 600], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_bb10 # branch
.L8cdb_hexa_arr_zeros_leaf_bb10:
    mov r10, [rbp - 264] # reload L31 from spill slot
    test r10, r10 # br_cond test
    jz .L8cdb_hexa_arr_zeros_leaf_bb12 # jump-if-zero -> else
    jmp .L8cdb_hexa_arr_zeros_leaf_bb11 # jump -> then
.L8cdb_hexa_arr_zeros_leaf_bb11:
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 240] # reload L28 from spill slot
    mov r11, r11 # hv payload
    mov rsi, 1 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 608], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r11, 8 # hv payload
    mov r10, [rbp - 240] # reload L28 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 616], r11 # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r11, [rbp - 280] # reload L33 from spill slot
    mov r10, r11 # assign L34
    mov r11, [rbp - 616] # tag L33 from tag-slot
    mov [rbp - 624], r11 # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 288] # reload L34 from spill slot
    mov r11, r11 # hv payload
    mov rsi, 0 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 632], r11 # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    mov r11, 16 # hv payload
    mov r10, [rbp - 240] # reload L28 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 640], r11 # store tag L36
    mov [rbp - 304], r10 # spill L36 to slot
    mov r11, [rbp - 304] # reload L36 from spill slot
    mov r10, r11 # assign L28
    mov r11, [rbp - 640] # tag L36 from tag-slot
    mov [rbp - 576], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 248] # reload L29 from spill slot
    mov r10, r10 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 648], r11 # store tag L37
    mov [rbp - 312], r10 # spill L37 to slot
    mov r11, [rbp - 312] # reload L37 from spill slot
    mov r10, r11 # assign L29
    mov r11, [rbp - 648] # tag L37 from tag-slot
    mov [rbp - 584], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 248] # reload L29 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ge: cmp payloads
    setge al # __hx_payload_ge: al = predicate
    movzx r10, al # __hx_payload_ge: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 656], r11 # store tag L38
    mov [rbp - 320], r10 # spill L38 to slot
    mov r11, [rbp - 320] # reload L38 from spill slot
    mov r10, r11 # assign L31
    mov r11, [rbp - 656] # tag L38 from tag-slot
    mov [rbp - 600], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_bb10 # branch
.L8cdb_hexa_arr_zeros_leaf_bb12:
    mov r10, r13 # hv payload
    mov r11, 0 # hv payload
    mov rsi, [rbp - 208] # reload L24 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r13 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 664], r11 # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    mov r10, r13 # hv payload
    mov r11, 8 # hv payload
    mov rsi, [rbp - 128] # reload L14 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r13 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 672], r11 # store tag L40
    mov [rbp - 336], r10 # spill L40 to slot
    mov r10, r13 # hv payload
    mov r11, 16 # hv payload
    mov rsi, [rbp - 128] # reload L14 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r13 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 680], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_bb7 # branch
    mov eax, 4 # value-less return: tag = TAG_VOID
    xor edx, edx # value-less return: payload = 0
    add rsp, 640 # epilogue: free spill frame
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
    .loc 1 94 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 640 # prologue: alloc spill frame
    mov [rbp - 352], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.L8cdb_hexa_arr_zeros_leaf_int_bb0:
    mov rsi, 32 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    call hexa_ptr_alloc # call hexa_ptr_alloc
    mov [rbp - 360], rax # store tag L1
    mov r12, rdx # hv: unbox user-call result payload
    mov r13, r12 # assign L2
    mov r11, 0 # tag L1 = TAG_INT (i64-local, fused)
    mov [rbp - 368], r11 # store tag L2
    mov r10, r13 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r14, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 376], r11 # store tag L3
    test r14, r14 # br_cond test
    jz .L8cdb_hexa_arr_zeros_leaf_int_bb2 # jump-if-zero -> else
    jmp .L8cdb_hexa_arr_zeros_leaf_int_bb1 # jump -> then
.L8cdb_hexa_arr_zeros_leaf_int_bb1:
    mov rsi, 1 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    call hexa_exit # call hexa_exit
    mov [rbp - 392], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_int_bb2 # branch
.L8cdb_hexa_arr_zeros_leaf_int_bb2:
    mov r10, r13 # hv payload
    mov r11, 0 # hv payload
    mov rsi, 0 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r13 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 400], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, r13 # hv payload
    mov r11, 8 # hv payload
    mov rsi, 0 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r13 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 408], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, r13 # hv payload
    mov r11, 16 # hv payload
    mov rsi, 0 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r13 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 416], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, r13 # hv payload
    mov r11, 24 # hv payload
    mov rsi, 0 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r13 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 424], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, r13 # hv payload
    mov r11, 5 # hv payload
    mov [rbp - 432], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 432] # tag L10 from tag-slot
    mov [rbp - 440], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 352] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 448], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 448] # tag L12 from tag-slot
    mov [rbp - 456], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, 0 # assign L14
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 464], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 472], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    test r10, r10 # br_cond test
    jz .L8cdb_hexa_arr_zeros_leaf_int_bb4 # jump-if-zero -> else
    jmp .L8cdb_hexa_arr_zeros_leaf_int_bb3 # jump -> then
.L8cdb_hexa_arr_zeros_leaf_int_bb3:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 488], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r11, [rbp - 152] # reload L17 from spill slot
    mov r10, r11 # assign L14
    mov r11, [rbp - 488] # tag L17 from tag-slot
    mov [rbp - 464], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_int_bb5 # branch
.L8cdb_hexa_arr_zeros_leaf_int_bb4:
    mov r10, rbx # hv payload
    movq xmm0, r10 # __hx_payload_f2i: xmm0 = v.f bits
    cvttsd2si r10, xmm0 # __hx_payload_f2i: r10 = (i64)trunc(v.f)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 496], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov r10, r11 # assign L14
    mov r11, [rbp - 496] # tag L18 from tag-slot
    mov [rbp - 464], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_int_bb5 # branch
.L8cdb_hexa_arr_zeros_leaf_int_bb5:
    mov r11, 1 # hv payload
    mov r10, [rbp - 128] # reload L14 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ge: cmp payloads
    setge al # __hx_payload_ge: al = predicate
    movzx r10, al # __hx_payload_ge: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 504], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r10, [rbp - 168] # reload L19 from spill slot
    test r10, r10 # br_cond test
    jz .L8cdb_hexa_arr_zeros_leaf_int_bb7 # jump-if-zero -> else
    jmp .L8cdb_hexa_arr_zeros_leaf_int_bb6 # jump -> then
.L8cdb_hexa_arr_zeros_leaf_int_bb6:
    mov r11, 16 # hv payload
    mov r10, [rbp - 128] # reload L14 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 520], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 520] # tag L21 from tag-slot
    mov [rbp - 528], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov rsi, [rbp - 192] # reload L22 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 528] # tag L22 from tag-slot
    call hexa_ptr_alloc # call hexa_ptr_alloc
    mov [rbp - 536], rax # store tag L23
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L24
    mov r11, 0 # tag L23 = TAG_INT (i64-local, fused)
    mov [rbp - 544], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 552], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r10, [rbp - 216] # reload L25 from spill slot
    test r10, r10 # br_cond test
    jz .L8cdb_hexa_arr_zeros_leaf_int_bb9 # jump-if-zero -> else
    jmp .L8cdb_hexa_arr_zeros_leaf_int_bb8 # jump -> then
.L8cdb_hexa_arr_zeros_leaf_int_bb7:
    mov rdx, [rbp - 104] # reload L11 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 440] # tag L11 from tag-slot
    add rsp, 640 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L8cdb_hexa_arr_zeros_leaf_int_bb8:
    mov rsi, 1 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    call hexa_exit # call hexa_exit
    mov [rbp - 568], rax # store tag L27
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 232], r10 # spill L27 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_int_bb9 # branch
.L8cdb_hexa_arr_zeros_leaf_int_bb9:
    mov r10, 0 # assign L28
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 576], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L29
    mov r11, [rbp - 464] # tag L14 from tag-slot
    mov [rbp - 584], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 248] # reload L29 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ge: cmp payloads
    setge al # __hx_payload_ge: al = predicate
    movzx r10, al # __hx_payload_ge: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 592], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r11, [rbp - 256] # reload L30 from spill slot
    mov r10, r11 # assign L31
    mov r11, [rbp - 592] # tag L30 from tag-slot
    mov [rbp - 600], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_int_bb10 # branch
.L8cdb_hexa_arr_zeros_leaf_int_bb10:
    mov r10, [rbp - 264] # reload L31 from spill slot
    test r10, r10 # br_cond test
    jz .L8cdb_hexa_arr_zeros_leaf_int_bb12 # jump-if-zero -> else
    jmp .L8cdb_hexa_arr_zeros_leaf_int_bb11 # jump -> then
.L8cdb_hexa_arr_zeros_leaf_int_bb11:
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 240] # reload L28 from spill slot
    mov r11, r11 # hv payload
    mov rsi, 0 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 608], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r11, 8 # hv payload
    mov r10, [rbp - 240] # reload L28 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 616], r11 # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r11, [rbp - 280] # reload L33 from spill slot
    mov r10, r11 # assign L34
    mov r11, [rbp - 616] # tag L33 from tag-slot
    mov [rbp - 624], r11 # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 288] # reload L34 from spill slot
    mov r11, r11 # hv payload
    mov rsi, 0 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 632], r11 # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    mov r11, 16 # hv payload
    mov r10, [rbp - 240] # reload L28 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 640], r11 # store tag L36
    mov [rbp - 304], r10 # spill L36 to slot
    mov r11, [rbp - 304] # reload L36 from spill slot
    mov r10, r11 # assign L28
    mov r11, [rbp - 640] # tag L36 from tag-slot
    mov [rbp - 576], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 248] # reload L29 from spill slot
    mov r10, r10 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 648], r11 # store tag L37
    mov [rbp - 312], r10 # spill L37 to slot
    mov r11, [rbp - 312] # reload L37 from spill slot
    mov r10, r11 # assign L29
    mov r11, [rbp - 648] # tag L37 from tag-slot
    mov [rbp - 584], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 248] # reload L29 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ge: cmp payloads
    setge al # __hx_payload_ge: al = predicate
    movzx r10, al # __hx_payload_ge: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 656], r11 # store tag L38
    mov [rbp - 320], r10 # spill L38 to slot
    mov r11, [rbp - 320] # reload L38 from spill slot
    mov r10, r11 # assign L31
    mov r11, [rbp - 656] # tag L38 from tag-slot
    mov [rbp - 600], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_int_bb10 # branch
.L8cdb_hexa_arr_zeros_leaf_int_bb12:
    mov r10, r13 # hv payload
    mov r11, 0 # hv payload
    mov rsi, [rbp - 208] # reload L24 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r13 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 664], r11 # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    mov r10, r13 # hv payload
    mov r11, 8 # hv payload
    mov rsi, [rbp - 128] # reload L14 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r13 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 672], r11 # store tag L40
    mov [rbp - 336], r10 # spill L40 to slot
    mov r10, r13 # hv payload
    mov r11, 16 # hv payload
    mov rsi, [rbp - 128] # reload L14 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r13 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 680], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    jmp .L8cdb_hexa_arr_zeros_leaf_int_bb7 # branch
    mov eax, 4 # value-less return: tag = TAG_VOID
    xor edx, edx # value-less return: payload = 0
    add rsp, 640 # epilogue: free spill frame
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
