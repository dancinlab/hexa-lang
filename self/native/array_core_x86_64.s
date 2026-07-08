// array_core_x86_64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 ARRAY-R4).
// GENERATED: tool/regen_array_core_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=x86_64-linux-gnu -o array_core_x86_64.s stdlib/runtime/array_core.hexa.
//   Provides the array-core READ-half (rt_array_get_native / rt_array_set_native /
//   rt_array_len_native / rt_array_pop_native) as native raw-mem bodies
//   (__hx_ptr_load64/store64 over the HexaArr descriptor + __hx_make_val tag
//   re-stamp), PLUS the alloc-bearing arena bridge rt_array_arena_alloc_items_native
//   (sh-array-write "alloc not a wall": n*16 bytes via the already-native
//   hexa_arena_alloc — self/rt/alloc.hexa). These intrinsics are gen2-native-only
//   (the hexat C-transpile bootstrap cannot lower them), so the bodies enter the
//   shipped runtime.a ONLY via this seed — the rt_hi mechanism (resolve_native_rt_hi_seed / Z2a).
//   ABI: ELF, rt_array_*_native no underscore. External: hexa_to_int (runtime.c) + hexa_arena_alloc (alloc seed).
//   Lets stage_resolve_runtime_a define HEXA_RT_ARRAY_NATIVE (+ HEXA_RT_ARRAY_ARENA_NATIVE
//   when the alloc seed is native) + ar this .o into runtime.a so hexa_array_get/set
//   delegate to the native bodies + hexa_array_arena_alloc_items uses the native arena.
# hexa-lang emit pass — target=x86_64-linux-gnu
# source: /home/aiden/wt-rfc061-strbuf-arena/stdlib/runtime/array_core.hexa
.intel_syntax noprefix
.file 1 "stdlib/runtime/array_core.hexa"
.text
.globl rt_array_arena_alloc_items_native
.hidden rt_array_arena_alloc_items_native
    .p2align 4
rt_array_arena_alloc_items_native:
    .loc 1 76 0
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
.Ld116_rt_array_arena_alloc_items_native_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 56] # tag L0 from tag-slot
    mov rcx, 16 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r12, rdx # binop *: capture result payload
    mov [rbp - 64], rax # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 64] # tag L1 from tag-slot
    mov [rbp - 72], r11 # store tag L2
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 72] # tag L2 from tag-slot
    call hexa_arena_alloc # call hexa_arena_alloc
    mov [rbp - 80], rax # store tag L3
    mov r14, rdx # hv: unbox user-call result payload
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
.globl rt_array_arena_alloc_desc_native
.hidden rt_array_arena_alloc_desc_native
    .p2align 4
rt_array_arena_alloc_desc_native:
    .loc 1 97 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 80 # prologue: alloc spill frame
.Ld116_rt_array_arena_alloc_desc_native_bb0:
    mov rsi, 24 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    call hexa_arena_alloc # call hexa_arena_alloc
    mov [rbp - 72], rax # store tag L0
    mov rbx, rdx # hv: unbox user-call result payload
    mov r12, rbx # assign L1
    mov r11, [rbp - 72] # tag L0 from tag-slot
    mov [rbp - 80], r11 # store tag L1
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 80] # tag L1 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r13, rdx # binop ==: capture bool payload
    mov [rbp - 88], rax # store tag L2
    test r13, r13 # br_cond test
    jz .Ld116_rt_array_arena_alloc_desc_native_bb2 # jump-if-zero -> else
    jmp .Ld116_rt_array_arena_alloc_desc_native_bb1 # jump -> then
.Ld116_rt_array_arena_alloc_desc_native_bb1:
    mov rdx, 0 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 80 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Ld116_rt_array_arena_alloc_desc_native_bb2:
    mov r10, r12 # hv payload
    mov r11, 0 # hv payload
    mov rsi, 0 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r12 # hv payload
    mov r15, r10 # leaf: payload → dst L4
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 104], r11 # store tag L4
    mov r10, r12 # hv payload
    mov r11, 8 # hv payload
    mov rsi, 0 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r12 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 112], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, r12 # hv payload
    mov r11, 16 # hv payload
    mov rsi, 0 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r12 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 120], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov rdx, r12 # hv arg payload
    mov rax, [rbp - 80] # tag L1 from tag-slot
    add rsp, 80 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_array_len_native
.hidden rt_array_len_native
    .p2align 4
rt_array_len_native:
    .loc 1 107 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 48 # prologue: alloc spill frame
    mov [rbp - 56], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.Ld116_rt_array_len_native_bb0:
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
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r14, r10 # leaf: payload → dst L3
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 80], r11 # store tag L3
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 80] # tag L3 from tag-slot
    call hexa_to_int # call hexa_to_int
    mov [rbp - 88], rax # store tag L4
    mov r15, rdx # hv: unbox user-call result payload
    mov rdx, r15 # hv arg payload
    mov rax, [rbp - 88] # tag L4 from tag-slot
    add rsp, 48 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_array_get_native
.hidden rt_array_get_native
    .p2align 4
rt_array_get_native:
    .loc 1 116 0
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
    mov [rbp - 136], rdx # store tag L1
    mov r12, rcx # ingress param payload
.Ld116_rt_array_get_native_bb0:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r13, r10 # leaf: payload → dst L2
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 144], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 144] # tag L2 from tag-slot
    mov [rbp - 152], r11 # store tag L3
    mov r10, r14 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r15, r10 # leaf: payload → dst L4
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 160], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 160] # tag L4 from tag-slot
    mov [rbp - 168], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, 16 # hv payload
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
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r11, r11 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 192], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 192] # tag L8 from tag-slot
    mov [rbp - 200], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, 8 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 208], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r11, r11 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 216], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 216] # tag L11 from tag-slot
    mov [rbp - 224], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r11, r11 # hv payload
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
.globl rt_array_set_native
.hidden rt_array_set_native
    .p2align 4
rt_array_set_native:
    .loc 1 130 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 224 # prologue: alloc spill frame
    mov [rbp - 144], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 152], rdx # store tag L1
    mov r12, rcx # ingress param payload
    mov [rbp - 160], r8 # store tag L2
    mov r13, r9 # ingress param payload
.Ld116_rt_array_set_native_bb0:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r14, r10 # leaf: payload → dst L3
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 168], r11 # store tag L3
    mov r15, r14 # assign L4
    mov r11, [rbp - 168] # tag L3 from tag-slot
    mov [rbp - 176], r11 # store tag L4
    mov r10, r15 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 184], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 184] # tag L5 from tag-slot
    mov [rbp - 192], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, 16 # hv payload
    mov r10, r12 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 200], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 200] # tag L7 from tag-slot
    mov [rbp - 208], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 160] # tag L2 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 216], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r10, r11 # assign L10
    mov r11, [rbp - 216] # tag L9 from tag-slot
    mov [rbp - 224], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, 0 # hv payload
    mov r10, r13 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 232], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 232] # tag L11 from tag-slot
    mov [rbp - 240], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r11, r11 # hv payload
    mov rsi, [rbp - 96] # reload L10 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 248], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r11, 8 # hv payload
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 256], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r11, r11 # hv payload
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 264], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov rdx, rbx # hv arg payload
    mov rax, [rbp - 144] # tag L0 from tag-slot
    add rsp, 224 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_array_pop_native
.hidden rt_array_pop_native
    .p2align 4
rt_array_pop_native:
    .loc 1 146 0
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
.Ld116_rt_array_pop_native_bb0:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r12, r10 # leaf: payload → dst L1
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 104], r11 # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 104] # tag L1 from tag-slot
    mov [rbp - 112], r11 # store tag L2
    mov r10, r13 # hv payload
    mov r11, 8 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r14, r10 # leaf: payload → dst L3
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 120], r11 # store tag L3
    mov r15, r14 # assign L4
    mov r11, [rbp - 120] # tag L3 from tag-slot
    mov [rbp - 128], r11 # store tag L4
    mov r11, 1 # hv payload
    mov r10, r15 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 136], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 136] # tag L5 from tag-slot
    mov [rbp - 144], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 96] # tag L0 from tag-slot
    mov rcx, [rbp - 64] # reload L6 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 144] # tag L6 from tag-slot
    call rt_array_get_native # call rt_array_get_native
    mov [rbp - 152], rax # store tag L7
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 72], r10 # spill L7 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 152] # tag L7 from tag-slot
    mov [rbp - 160], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, r13 # hv payload
    mov r11, 8 # hv payload
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r13 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 168], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov rdx, [rbp - 80] # reload L8 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 160] # tag L8 from tag-slot
    add rsp, 128 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_array_shift_native
.hidden rt_array_shift_native
    .p2align 4
rt_array_shift_native:
    .loc 1 163 0
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
.Ld116_rt_array_shift_native_bb0:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r12, r10 # leaf: payload → dst L1
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 272], r11 # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 272] # tag L1 from tag-slot
    mov [rbp - 280], r11 # store tag L2
    mov r10, r13 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r14, r10 # leaf: payload → dst L3
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 288], r11 # store tag L3
    mov r15, r14 # assign L4
    mov r11, [rbp - 288] # tag L3 from tag-slot
    mov [rbp - 296], r11 # store tag L4
    mov r10, r13 # hv payload
    mov r11, 8 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 304], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 304] # tag L5 from tag-slot
    mov [rbp - 312], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, 0 # hv payload
    mov r10, 0 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 320], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 320] # tag L7 from tag-slot
    mov [rbp - 328], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 264] # tag L0 from tag-slot
    mov rcx, [rbp - 80] # reload L8 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 328] # tag L8 from tag-slot
    call rt_array_get_native # call rt_array_get_native
    mov [rbp - 336], rax # store tag L9
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r10, r11 # assign L10
    mov r11, [rbp - 336] # tag L9 from tag-slot
    mov [rbp - 344], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 352], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 352] # tag L11 from tag-slot
    mov [rbp - 360], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, 0 # assign L13
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 368], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    jmp .Ld116_rt_array_shift_native_bb1 # branch
.Ld116_rt_array_shift_native_bb1:
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 376], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r10, [rbp - 128] # reload L14 from spill slot
    test r10, r10 # br_cond test
    jz .Ld116_rt_array_shift_native_bb3 # jump-if-zero -> else
    jmp .Ld116_rt_array_shift_native_bb2 # jump -> then
.Ld116_rt_array_shift_native_bb2:
    mov r11, 16 # hv payload
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 384], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, [rbp - 136] # reload L15 from spill slot
    mov r10, r11 # assign L16
    mov r11, [rbp - 384] # tag L15 from tag-slot
    mov [rbp - 392], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, 16 # hv payload
    mov r10, [rbp - 144] # reload L16 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 400], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r11, [rbp - 152] # reload L17 from spill slot
    mov r10, r11 # assign L18
    mov r11, [rbp - 400] # tag L17 from tag-slot
    mov [rbp - 408], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r10, r15 # hv payload
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov r11, r11 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 416], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov r10, r11 # assign L20
    mov r11, [rbp - 416] # tag L19 from tag-slot
    mov [rbp - 424], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r11, 8 # hv payload
    mov r10, [rbp - 160] # reload L18 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 432], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 432] # tag L21 from tag-slot
    mov [rbp - 440], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r10, r15 # hv payload
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r11, r11 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 448], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 448] # tag L23 from tag-slot
    mov [rbp - 456], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r10, r15 # hv payload
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r11, r11 # hv payload
    mov rsi, [rbp - 176] # reload L20 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r15 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 464], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r11, 8 # hv payload
    mov r10, [rbp - 144] # reload L16 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 472], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r11, [rbp - 224] # reload L26 from spill slot
    mov r10, r11 # assign L27
    mov r11, [rbp - 472] # tag L26 from tag-slot
    mov [rbp - 480], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov r10, r15 # hv payload
    mov r11, [rbp - 232] # reload L27 from spill slot
    mov r11, r11 # hv payload
    mov rsi, [rbp - 208] # reload L24 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r15 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 488], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 496], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r11, [rbp - 248] # reload L29 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 496] # tag L29 from tag-slot
    mov [rbp - 368], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    jmp .Ld116_rt_array_shift_native_bb1 # branch
.Ld116_rt_array_shift_native_bb3:
    mov r10, r13 # hv payload
    mov r11, 8 # hv payload
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r13 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 504], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov rdx, [rbp - 96] # reload L10 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 344] # tag L10 from tag-slot
    add rsp, 464 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_array_truncate_native
.hidden rt_array_truncate_native
    .p2align 4
rt_array_truncate_native:
    .loc 1 194 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 224 # prologue: alloc spill frame
    mov [rbp - 144], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 152], rdx # store tag L1
    mov r12, rcx # ingress param payload
.Ld116_rt_array_truncate_native_bb0:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r13, r10 # leaf: payload → dst L2
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 160], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 160] # tag L2 from tag-slot
    mov [rbp - 168], r11 # store tag L3
    mov r10, r14 # hv payload
    mov r11, 8 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r15, r10 # leaf: payload → dst L4
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 176], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 176] # tag L4 from tag-slot
    mov [rbp - 184], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, 0 # hv payload
    mov r10, 0 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 192], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 192] # tag L6 from tag-slot
    mov [rbp - 200], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r11, 0 # hv payload
    mov r10, r12 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 208], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 208] # tag L8 from tag-slot
    mov [rbp - 216], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 224], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    test r10, r10 # br_cond test
    jz .Ld116_rt_array_truncate_native_bb2 # jump-if-zero -> else
    jmp .Ld116_rt_array_truncate_native_bb1 # jump -> then
.Ld116_rt_array_truncate_native_bb1:
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 200] # tag L7 from tag-slot
    mov [rbp - 216], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    jmp .Ld116_rt_array_truncate_native_bb2 # branch
.Ld116_rt_array_truncate_native_bb2:
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 240], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    test r10, r10 # br_cond test
    jz .Ld116_rt_array_truncate_native_bb4 # jump-if-zero -> else
    jmp .Ld116_rt_array_truncate_native_bb3 # jump -> then
.Ld116_rt_array_truncate_native_bb3:
    mov r11, 0 # hv payload
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 256], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 256] # tag L14 from tag-slot
    mov [rbp - 216], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    jmp .Ld116_rt_array_truncate_native_bb4 # branch
.Ld116_rt_array_truncate_native_bb4:
    mov r10, r14 # hv payload
    mov r11, 8 # hv payload
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, r14 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 264], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov rdx, rbx # hv arg payload
    mov rax, [rbp - 144] # tag L0 from tag-slot
    add rsp, 224 # epilogue: free spill frame
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
