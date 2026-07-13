// array_typed_leaf_f64_x86_64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE — array typed-leaf i64 DISPATCH).
// GENERATED: tool/regen_array_typed_leaf_f64_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=x86_64-linux-gnu -o array_typed_leaf_f64_x86_64.s stdlib/runtime/array_typed_leaf_f64.hexa.
//   Provides the 4 packed-i64 array dispatcher natives (hexa_arr_f64_new/push/len/box).
//   ABI: ELF, no underscore. External U-floor: hexa_heap_alloc hexa_heap_realloc hexa_throw hexa_bool (libc-bearing: realloc grow dissolves the
//   array_core.hexa:25 wall via extern realloc CALL; the C body carries the same undefs).
//   Lets stage_resolve_runtime_a define HEXA_RT_CORE_ARRAY_I64_LEAF_NATIVE + ar this
//   .o into runtime.a so the 4 i64 dispatchers drop from the compiled runtime_core.c.
# hexa-lang emit pass — target=x86_64-linux-gnu
# source: /tmp/f2/stdlib/runtime/array_typed_leaf_f64.hexa
.intel_syntax noprefix
.file 1 "stdlib/runtime/array_typed_leaf_f64.hexa"
.text
.globl hexa_arr_f64_new_seed
.hidden hexa_arr_f64_new_seed
    .p2align 4
hexa_arr_f64_new_seed:
    .loc 1 49 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 304 # prologue: alloc spill frame
    mov [rbp - 184], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.Le5a1_hexa_arr_f64_new_seed_bb0:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r12, r10 # leaf: payload → dst L1
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 192], r11 # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 192] # tag L1 from tag-slot
    mov [rbp - 200], r11 # store tag L2
    mov r11, 1 # hv payload
    mov r10, r13 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r14, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 208], r11 # store tag L3
    test r14, r14 # br_cond test
    jz .Le5a1_hexa_arr_f64_new_seed_bb2 # jump-if-zero -> else
    jmp .Le5a1_hexa_arr_f64_new_seed_bb1 # jump -> then
.Le5a1_hexa_arr_f64_new_seed_bb1:
    mov r13, 1 # assign L2
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 200], r11 # store tag L2
    jmp .Le5a1_hexa_arr_f64_new_seed_bb2 # branch
.Le5a1_hexa_arr_f64_new_seed_bb2:
    mov rsi, 24 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    call hexa_heap_alloc # call hexa_heap_alloc
    mov [rbp - 224], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, 0 # tag L5 = TAG_INT (i64-local, fused)
    mov [rbp - 232], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 240], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    test r10, r10 # br_cond test
    jz .Le5a1_hexa_arr_f64_new_seed_bb4 # jump-if-zero -> else
    jmp .Le5a1_hexa_arr_f64_new_seed_bb3 # jump -> then
.Le5a1_hexa_arr_f64_new_seed_bb3:
    lea rsi, [rip+.LCstr0] # hv arg payload: &str .LCstr0
    mov rdi, 3 # hv arg tag = TAG_STR
    call hexa_throw # call hexa_throw
    mov [rbp - 256], rax # store tag L9
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 88], r10 # spill L9 to slot
    jmp .Le5a1_hexa_arr_f64_new_seed_bb4 # branch
.Le5a1_hexa_arr_f64_new_seed_bb4:
    mov r11, 8 # hv payload
    mov r10, r13 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 264], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 264] # tag L10 from tag-slot
    mov [rbp - 272], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov rsi, [rbp - 104] # reload L11 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 272] # tag L11 from tag-slot
    call hexa_heap_alloc # call hexa_heap_alloc
    mov [rbp - 280], rax # store tag L12
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L13
    mov r11, 0 # tag L12 = TAG_INT (i64-local, fused)
    mov [rbp - 288], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 296], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r10, [rbp - 128] # reload L14 from spill slot
    test r10, r10 # br_cond test
    jz .Le5a1_hexa_arr_f64_new_seed_bb6 # jump-if-zero -> else
    jmp .Le5a1_hexa_arr_f64_new_seed_bb5 # jump -> then
.Le5a1_hexa_arr_f64_new_seed_bb5:
    lea rsi, [rip+.LCstr0] # hv arg payload: &str .LCstr0
    mov rdi, 3 # hv arg tag = TAG_STR
    call hexa_throw # call hexa_throw
    mov [rbp - 312], rax # store tag L16
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 144], r10 # spill L16 to slot
    jmp .Le5a1_hexa_arr_f64_new_seed_bb6 # branch
.Le5a1_hexa_arr_f64_new_seed_bb6:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 320], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    mov r11, 8 # hv payload
    mov rsi, 0 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 328], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    mov r11, 16 # hv payload
    mov rsi, r13 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 336], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    mov r11, 5 # hv payload
    mov [rbp - 344], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov rdx, [rbp - 176] # reload L20 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 344] # tag L20 from tag-slot
    add rsp, 304 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_arr_f64_push_bits_seed
.hidden hexa_arr_f64_push_bits_seed
    .p2align 4
hexa_arr_f64_push_bits_seed:
    .loc 1 66 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 496 # prologue: alloc spill frame
    mov [rbp - 280], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 288], rdx # store tag L1
    mov r12, rcx # ingress param payload
.Le5a1_hexa_arr_f64_push_bits_seed_bb0:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r13, r10 # leaf: payload → dst L2
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 296], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 296] # tag L2 from tag-slot
    mov [rbp - 304], r11 # store tag L3
    mov r11, 0 # hv payload
    mov r10, r12 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r15, r10 # leaf: payload → dst L4
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 312], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 312] # tag L4 from tag-slot
    mov [rbp - 320], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, r14 # hv payload
    mov r11, 8 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 328], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 328] # tag L6 from tag-slot
    mov [rbp - 336], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, r14 # hv payload
    mov r11, 16 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 344], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 344] # tag L8 from tag-slot
    mov [rbp - 352], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ge: cmp payloads
    setge al # __hx_payload_ge: al = predicate
    movzx r10, al # __hx_payload_ge: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 360], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    test r10, r10 # br_cond test
    jz .Le5a1_hexa_arr_f64_push_bits_seed_bb2 # jump-if-zero -> else
    jmp .Le5a1_hexa_arr_f64_push_bits_seed_bb1 # jump -> then
.Le5a1_hexa_arr_f64_push_bits_seed_bb1:
    mov r11, 2 # hv payload
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 376], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 376] # tag L12 from tag-slot
    mov [rbp - 384], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, r14 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 392], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 392] # tag L14 from tag-slot
    mov [rbp - 400], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, 8 # hv payload
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 408], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, [rbp - 408] # tag L16 from tag-slot
    mov [rbp - 416], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 400] # tag L15 from tag-slot
    mov rcx, [rbp - 152] # reload L17 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 416] # tag L17 from tag-slot
    call hexa_heap_realloc # call hexa_heap_realloc
    mov [rbp - 424], rax # store tag L18
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 160], r10 # spill L18 to slot
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov r10, r11 # assign L19
    mov r11, 0 # tag L18 = TAG_INT (i64-local, fused)
    mov [rbp - 432], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r10, [rbp - 168] # reload L19 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 440], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, [rbp - 176] # reload L20 from spill slot
    test r10, r10 # br_cond test
    jz .Le5a1_hexa_arr_f64_push_bits_seed_bb4 # jump-if-zero -> else
    jmp .Le5a1_hexa_arr_f64_push_bits_seed_bb3 # jump -> then
.Le5a1_hexa_arr_f64_push_bits_seed_bb2:
    mov r10, r14 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 480], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r11, [rbp - 216] # reload L25 from spill slot
    mov r10, r11 # assign L26
    mov r11, [rbp - 480] # tag L25 from tag-slot
    mov [rbp - 488], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r11, 8 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 496], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov r11, [rbp - 232] # reload L27 from spill slot
    mov r10, r11 # assign L28
    mov r11, [rbp - 496] # tag L27 from tag-slot
    mov [rbp - 504], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 240] # reload L28 from spill slot
    mov r11, r11 # hv payload
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 512], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 520], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r11, [rbp - 256] # reload L30 from spill slot
    mov r10, r11 # assign L31
    mov r11, [rbp - 520] # tag L30 from tag-slot
    mov [rbp - 528], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov r10, r14 # hv payload
    mov r11, 8 # hv payload
    mov rsi, [rbp - 264] # reload L31 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r14 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 536], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov rdx, rbx # hv arg payload
    mov rax, [rbp - 280] # tag L0 from tag-slot
    add rsp, 496 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Le5a1_hexa_arr_f64_push_bits_seed_bb3:
    lea rsi, [rip+.LCstr1] # hv arg payload: &str .LCstr1
    mov rdi, 3 # hv arg tag = TAG_STR
    call hexa_throw # call hexa_throw
    mov [rbp - 456], rax # store tag L22
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 192], r10 # spill L22 to slot
    jmp .Le5a1_hexa_arr_f64_push_bits_seed_bb4 # branch
.Le5a1_hexa_arr_f64_push_bits_seed_bb4:
    mov r10, r14 # hv payload
    mov r11, 0 # hv payload
    mov rsi, [rbp - 168] # reload L19 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r14 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 464], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r10, r14 # hv payload
    mov r11, 16 # hv payload
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r14 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 472], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    jmp .Le5a1_hexa_arr_f64_push_bits_seed_bb2 # branch
    mov eax, 4 # value-less return: tag = TAG_VOID
    xor edx, edx # value-less return: payload = 0
    add rsp, 496 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_arr_f64_len_seed
.hidden hexa_arr_f64_len_seed
    .p2align 4
hexa_arr_f64_len_seed:
    .loc 1 89 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 64 # prologue: alloc spill frame
    mov [rbp - 64], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.Le5a1_hexa_arr_f64_len_seed_bb0:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r12, r10 # leaf: payload → dst L1
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 72], r11 # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 72] # tag L1 from tag-slot
    mov [rbp - 80], r11 # store tag L2
    mov r10, r13 # hv payload
    mov r11, 8 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r14, r10 # leaf: payload → dst L3
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 88], r11 # store tag L3
    mov r15, r14 # assign L4
    mov r11, [rbp - 88] # tag L3 from tag-slot
    mov [rbp - 96], r11 # store tag L4
    mov r10, r15 # hv payload
    mov r11, 0 # hv payload
    mov [rbp - 104], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov rdx, [rbp - 56] # reload L5 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 104] # tag L5 from tag-slot
    add rsp, 64 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_arr_f64_box_seed
.hidden hexa_arr_f64_box_seed
    .p2align 4
hexa_arr_f64_box_seed:
    .loc 1 97 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 304 # prologue: alloc spill frame
    mov [rbp - 184], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 192], rdx # store tag L1
    mov r12, rcx # ingress param payload
.Le5a1_hexa_arr_f64_box_seed_bb0:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r13, r10 # leaf: payload → dst L2
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 200], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 200] # tag L2 from tag-slot
    mov [rbp - 208], r11 # store tag L3
    mov r11, 0 # hv payload
    mov r10, r12 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r15, r10 # leaf: payload → dst L4
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 216], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 216] # tag L4 from tag-slot
    mov [rbp - 224], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, r14 # hv payload
    mov r11, 8 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 232], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 232] # tag L6 from tag-slot
    mov [rbp - 240], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 248], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    test r10, r10 # br_cond test
    jz .Le5a1_hexa_arr_f64_box_seed_bb2 # jump-if-zero -> else
    jmp .Le5a1_hexa_arr_f64_box_seed_bb1 # jump -> then
.Le5a1_hexa_arr_f64_box_seed_bb1:
    lea rsi, [rip+.LCstr2] # hv arg payload: &str .LCstr2
    mov rdi, 3 # hv arg tag = TAG_STR
    call hexa_throw # call hexa_throw
    mov [rbp - 264], rax # store tag L10
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 96], r10 # spill L10 to slot
    jmp .Le5a1_hexa_arr_f64_box_seed_bb2 # branch
.Le5a1_hexa_arr_f64_box_seed_bb2:
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ge: cmp payloads
    setge al # __hx_payload_ge: al = predicate
    movzx r10, al # __hx_payload_ge: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 272], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 104] # reload L11 from spill slot
    test r10, r10 # br_cond test
    jz .Le5a1_hexa_arr_f64_box_seed_bb4 # jump-if-zero -> else
    jmp .Le5a1_hexa_arr_f64_box_seed_bb3 # jump -> then
.Le5a1_hexa_arr_f64_box_seed_bb3:
    lea rsi, [rip+.LCstr2] # hv arg payload: &str .LCstr2
    mov rdi, 3 # hv arg tag = TAG_STR
    call hexa_throw # call hexa_throw
    mov [rbp - 288], rax # store tag L13
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 120], r10 # spill L13 to slot
    jmp .Le5a1_hexa_arr_f64_box_seed_bb4 # branch
.Le5a1_hexa_arr_f64_box_seed_bb4:
    mov r10, r14 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 296], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 296] # tag L14 from tag-slot
    mov [rbp - 304], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, 8 # hv payload
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 312], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, [rbp - 312] # tag L16 from tag-slot
    mov [rbp - 320], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 152] # reload L17 from spill slot
    mov r11, r11 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 328], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov r10, r11 # assign L19
    mov r11, [rbp - 328] # tag L18 from tag-slot
    mov [rbp - 336], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r10, [rbp - 168] # reload L19 from spill slot
    mov r10, r10 # hv payload
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 344], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov rdx, [rbp - 176] # reload L20 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 344] # tag L20 from tag-slot
    add rsp, 304 # epilogue: free spill frame
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
    .byte 0x4f, 0x4f, 0x4d, 0x20, 0x69, 0x6e, 0x20, 0x61, 0x72, 0x72, 0x5f, 0x66, 0x36, 0x34, 0x5f, 0x6e
    .byte 0x65, 0x77, 0x00
.section .rodata
.LCstr1:
    .byte 0x4f, 0x4f, 0x4d, 0x20, 0x69, 0x6e, 0x20, 0x61, 0x72, 0x72, 0x5f, 0x66, 0x36, 0x34, 0x5f, 0x70
    .byte 0x75, 0x73, 0x68, 0x00
.section .rodata
.LCstr2:
    .byte 0x69, 0x6e, 0x64, 0x65, 0x78, 0x20, 0x6f, 0x75, 0x74, 0x20, 0x6f, 0x66, 0x20, 0x62, 0x6f, 0x75
    .byte 0x6e, 0x64, 0x73, 0x00
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .note.GNU-stack,"",@progbits
