// array_typed_leaf_f64_x86_64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE — array typed-leaf i64 DISPATCH).
// GENERATED: tool/regen_array_typed_leaf_f64_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=x86_64-linux-gnu -o array_typed_leaf_f64_x86_64.s stdlib/runtime/array_typed_leaf_f64.hexa.
//   Provides the 4 packed-i64 array dispatcher natives (hexa_arr_f64_new/push/len/box).
//   ABI: ELF, no underscore. External U-floor: malloc realloc write hexa_exit hexa_throw (libc-bearing: realloc grow dissolves the
//   array_core.hexa:25 wall via extern realloc CALL; the C body carries the same undefs).
//   Lets stage_resolve_runtime_a define HEXA_RT_CORE_ARRAY_I64_LEAF_NATIVE + ar this
//   .o into runtime.a so the 4 i64 dispatchers drop from the compiled runtime_core.c.
# hexa-lang emit pass — target=x86_64-linux-gnu
# source: /tmp/f64regen/stdlib/runtime/array_typed_leaf_f64.hexa
.intel_syntax noprefix
.file 1 "stdlib/runtime/array_typed_leaf_f64.hexa"
.text
.globl hexa_arr_f64_new
.hidden hexa_arr_f64_new
    .p2align 4
hexa_arr_f64_new:
    .loc 1 38 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 192 # prologue: alloc spill frame
    mov [rbp - 128], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.L1161_hexa_arr_f64_new_bb0:
    mov r12, rbx # assign L1
    mov r11, 0 # tag L0 = TAG_INT (i64-local, fused)
    mov [rbp - 136], r11 # store tag L1
    mov r11, 1 # hv payload
    mov r10, r12 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r13, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 144], r11 # store tag L2
    test r13, r13 # br_cond test
    jz .L1161_hexa_arr_f64_new_bb2 # jump-if-zero -> else
    jmp .L1161_hexa_arr_f64_new_bb1 # jump -> then
.L1161_hexa_arr_f64_new_bb1:
    mov r12, 1 # assign L1
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 136], r11 # store tag L1
    jmp .L1161_hexa_arr_f64_new_bb2 # branch
.L1161_hexa_arr_f64_new_bb2:
    mov rsi, 16 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    call malloc # call malloc
    mov [rbp - 160], rax # store tag L4
    mov r15, rdx # hv: unbox user-call result payload
    mov r10, r15 # assign L5
    mov r11, 0 # tag L4 = TAG_INT (i64-local, fused)
    mov [rbp - 168], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, 8 # hv payload
    mov r10, r12 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 176], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 176] # tag L6 from tag-slot
    mov [rbp - 184], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 184] # tag L7 from tag-slot
    call malloc # call malloc
    mov [rbp - 192], rax # store tag L8
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, 0 # tag L8 = TAG_INT (i64-local, fused)
    mov [rbp - 200], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 208], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 8 # hv payload
    mov rsi, 0 # hv payload
    add r10, r11 # __hx_ptr_store32: addr = ptr + off
    mov dword ptr [r10], esi # __hx_ptr_store32: *(addr) = (i32)val
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 216], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 12 # hv payload
    mov rsi, r12 # hv payload
    add r10, r11 # __hx_ptr_store32: addr = ptr + off
    mov dword ptr [r10], esi # __hx_ptr_store32: *(addr) = (i32)val
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 224], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 5 # hv payload
    mov [rbp - 232], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov rdx, [rbp - 120] # reload L13 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 232] # tag L13 from tag-slot
    add rsp, 192 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_arr_f64_push_bits
.hidden hexa_arr_f64_push_bits
    .p2align 4
hexa_arr_f64_push_bits:
    .loc 1 53 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 512 # prologue: alloc spill frame
    mov [rbp - 288], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 296], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L1161_hexa_arr_f64_push_bits_bb0:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r13, r10 # leaf: payload → dst L2
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 304], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 304] # tag L2 from tag-slot
    mov [rbp - 312], r11 # store tag L3
    mov r10, r14 # hv payload
    mov r11, 8 # hv payload
    add r10, r11 # __hx_ptr_load32: addr = ptr + off
    mov r10d, dword ptr [r10] # __hx_ptr_load32: r10d = *(i32*)addr (zero-ext)
    mov r15, r10 # leaf: payload → dst L4
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 320], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 320] # tag L4 from tag-slot
    mov [rbp - 328], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, r14 # hv payload
    mov r11, 12 # hv payload
    add r10, r11 # __hx_ptr_load32: addr = ptr + off
    mov r10d, dword ptr [r10] # __hx_ptr_load32: r10d = *(i32*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 336], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 336] # tag L6 from tag-slot
    mov [rbp - 344], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ge: cmp payloads
    setge al # __hx_payload_ge: al = predicate
    movzx r10, al # __hx_payload_ge: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 352], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    test r10, r10 # br_cond test
    jz .L1161_hexa_arr_f64_push_bits_bb2 # jump-if-zero -> else
    jmp .L1161_hexa_arr_f64_push_bits_bb1 # jump -> then
.L1161_hexa_arr_f64_push_bits_bb1:
    mov r11, 2 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 368], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 368] # tag L10 from tag-slot
    mov [rbp - 376], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, r14 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 384], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 384] # tag L12 from tag-slot
    mov [rbp - 392], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r11, 8 # hv payload
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 400], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 400] # tag L14 from tag-slot
    mov [rbp - 408], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 392] # tag L13 from tag-slot
    mov rcx, [rbp - 136] # reload L15 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 408] # tag L15 from tag-slot
    call realloc # call realloc
    mov [rbp - 416], rax # store tag L16
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, 0 # tag L16 = TAG_INT (i64-local, fused)
    mov [rbp - 424], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 432], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r10, [rbp - 160] # reload L18 from spill slot
    test r10, r10 # br_cond test
    jz .L1161_hexa_arr_f64_push_bits_bb4 # jump-if-zero -> else
    jmp .L1161_hexa_arr_f64_push_bits_bb3 # jump -> then
.L1161_hexa_arr_f64_push_bits_bb2:
    mov r10, r14 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 496], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r11, [rbp - 224] # reload L26 from spill slot
    mov r10, r11 # assign L27
    mov r11, [rbp - 496] # tag L26 from tag-slot
    mov [rbp - 504], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov r11, 8 # hv payload
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 512], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r11, [rbp - 240] # reload L28 from spill slot
    mov r10, r11 # assign L29
    mov r11, [rbp - 512] # tag L28 from tag-slot
    mov [rbp - 520], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r10, [rbp - 232] # reload L27 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 248] # reload L29 from spill slot
    mov r11, r11 # hv payload
    mov rsi, r12 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, [rbp - 232] # reload L27 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 528], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 536], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov r11, [rbp - 264] # reload L31 from spill slot
    mov r10, r11 # assign L32
    mov r11, [rbp - 536] # tag L31 from tag-slot
    mov [rbp - 544], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r10, r14 # hv payload
    mov r11, 8 # hv payload
    mov rsi, [rbp - 272] # reload L32 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store32: addr = ptr + off
    mov dword ptr [r10], esi # __hx_ptr_store32: *(addr) = (i32)val
    mov r10, r14 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 552], r11 # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov rdx, rbx # hv arg payload
    mov rax, [rbp - 288] # tag L0 from tag-slot
    add rsp, 512 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L1161_hexa_arr_f64_push_bits_bb3:
    lea r10, [rip+.LCstr0] # hv payload: &str .LCstr0
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 448], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r11, [rbp - 176] # reload L20 from spill slot
    mov r10, r11 # assign L21
    mov r11, [rbp - 448] # tag L20 from tag-slot
    mov [rbp - 456], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov rsi, 2 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    mov rcx, [rbp - 184] # reload L21 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 456] # tag L21 from tag-slot
    mov r9, 20 # hv arg payload
    mov r8, 0 # tag default = TAG_INT
    call write # call write
    mov [rbp - 464], rax # store tag L22
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 192], r10 # spill L22 to slot
    mov rsi, 1 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    call hexa_exit # call hexa_exit
    mov [rbp - 472], rax # store tag L23
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 200], r10 # spill L23 to slot
    jmp .L1161_hexa_arr_f64_push_bits_bb4 # branch
.L1161_hexa_arr_f64_push_bits_bb4:
    mov r10, r14 # hv payload
    mov r11, 0 # hv payload
    mov rsi, [rbp - 152] # reload L17 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r14 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 480], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r10, r14 # hv payload
    mov r11, 12 # hv payload
    mov rsi, [rbp - 104] # reload L11 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store32: addr = ptr + off
    mov dword ptr [r10], esi # __hx_ptr_store32: *(addr) = (i32)val
    mov r10, r14 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 488], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    jmp .L1161_hexa_arr_f64_push_bits_bb2 # branch
    mov eax, 4 # value-less return: tag = TAG_VOID
    xor edx, edx # value-less return: payload = 0
    add rsp, 512 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_arr_f64_len
.hidden hexa_arr_f64_len
    .p2align 4
hexa_arr_f64_len:
    .loc 1 79 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 32 # prologue: alloc spill frame
    mov [rbp - 56], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.L1161_hexa_arr_f64_len_bb0:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r12, r10 # leaf: payload → dst L1
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 64], r11 # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 64] # tag L1 from tag-slot
    mov [rbp - 72], r11 # store tag L2
    mov r10, r13 # hv payload
    mov r11, 8 # hv payload
    add r10, r11 # __hx_ptr_load32: addr = ptr + off
    mov r10d, dword ptr [r10] # __hx_ptr_load32: r10d = *(i32*)addr (zero-ext)
    mov r14, r10 # leaf: payload → dst L3
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 80], r11 # store tag L3
    mov rdx, r14 # hv arg payload
    mov rax, [rbp - 80] # tag L3 from tag-slot
    add rsp, 32 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_arr_f64_box
.hidden hexa_arr_f64_box
    .p2align 4
hexa_arr_f64_box:
    .loc 1 86 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 272 # prologue: alloc spill frame
    mov [rbp - 168], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 176], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L1161_hexa_arr_f64_box_bb0:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r13, r10 # leaf: payload → dst L2
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 184], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 184] # tag L2 from tag-slot
    mov [rbp - 192], r11 # store tag L3
    mov r10, r14 # hv payload
    mov r11, 8 # hv payload
    add r10, r11 # __hx_ptr_load32: addr = ptr + off
    mov r10d, dword ptr [r10] # __hx_ptr_load32: r10d = *(i32*)addr (zero-ext)
    mov r15, r10 # leaf: payload → dst L4
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 200], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 200] # tag L4 from tag-slot
    mov [rbp - 208], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, 0 # hv payload
    mov r10, r12 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 216], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    test r10, r10 # br_cond test
    jz .L1161_hexa_arr_f64_box_bb2 # jump-if-zero -> else
    jmp .L1161_hexa_arr_f64_box_bb1 # jump -> then
.L1161_hexa_arr_f64_box_bb1:
    lea rsi, [rip+.LCstr1] # hv arg payload: &str .LCstr1
    mov rdi, 3 # hv arg tag = TAG_STR
    call hexa_throw # call hexa_throw
    mov [rbp - 232], rax # store tag L8
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 80], r10 # spill L8 to slot
    jmp .L1161_hexa_arr_f64_box_bb2 # branch
.L1161_hexa_arr_f64_box_bb2:
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r11, r11 # hv payload
    mov r10, r12 # hv payload
    cmp r10, r11 # __hx_payload_ge: cmp payloads
    setge al # __hx_payload_ge: al = predicate
    movzx r10, al # __hx_payload_ge: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 240], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    test r10, r10 # br_cond test
    jz .L1161_hexa_arr_f64_box_bb4 # jump-if-zero -> else
    jmp .L1161_hexa_arr_f64_box_bb3 # jump -> then
.L1161_hexa_arr_f64_box_bb3:
    lea rsi, [rip+.LCstr1] # hv arg payload: &str .LCstr1
    mov rdi, 3 # hv arg tag = TAG_STR
    call hexa_throw # call hexa_throw
    mov [rbp - 256], rax # store tag L11
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 104], r10 # spill L11 to slot
    jmp .L1161_hexa_arr_f64_box_bb4 # branch
.L1161_hexa_arr_f64_box_bb4:
    mov r10, r14 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 264], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 264] # tag L12 from tag-slot
    mov [rbp - 272], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r11, 8 # hv payload
    mov r10, r12 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 280], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 280] # tag L14 from tag-slot
    mov [rbp - 288], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 136] # reload L15 from spill slot
    mov r11, r11 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 296], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, [rbp - 296] # tag L16 from tag-slot
    mov [rbp - 304], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 312], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov rdx, [rbp - 160] # reload L18 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 312] # tag L18 from tag-slot
    add rsp, 272 # epilogue: free spill frame
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
    .byte 0x4f, 0x4f, 0x4d, 0x20, 0x69, 0x6e, 0x20, 0x61, 0x72, 0x72, 0x5f, 0x66, 0x36, 0x34, 0x5f, 0x70
    .byte 0x75, 0x73, 0x68, 0x0a, 0x00
.section .rodata
.LCstr1:
    .byte 0x69, 0x6e, 0x64, 0x65, 0x78, 0x20, 0x6f, 0x75, 0x74, 0x20, 0x6f, 0x66, 0x20, 0x62, 0x6f, 0x75
    .byte 0x6e, 0x64, 0x73, 0x00
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .note.GNU-stack,"",@progbits
