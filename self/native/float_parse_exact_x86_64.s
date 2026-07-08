// float_parse_exact_x86_64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 NUM-FLOAT — sh-float-exact).
// GENERATED: tool/regen_float_parse_exact_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=x86_64-linux-gnu -o float_parse_exact_x86_64.s stdlib/runtime/float_parse_exact.hexa.
//   Provides the EXACT correctly-rounded decimal->f64 tail
//   (rt_str_parse_float_exact) as a native big-integer (David Gay / glibc
//   strtod __mpn front + integer round-half-even) body that replaces the
//   strtod TAIL the Clinger fast path declines. Bit-exact to strtod over the
//   full finite-decimal domain; returns a TAG_VOID sentinel for
//   hex/inf/nan/malformed so the C wrapper still falls back to strtod.
//   These leaves are gen2-native-only (the hexat C-transpile bootstrap cannot
//   lower them), so the body enters the shipped runtime.a ONLY via this seed.
//   ABI: ELF, rt_str_parse_float_exact no underscore. External: hexa array runtime (resolved within runtime.a).
//   Lets stage_resolve_runtime_a define HEXA_RT_NUM_PARSE_FLOAT_EXACT (opt-IN)
//   + ar this .o into runtime.a so __hexa_num_parse_float composes
//   fast(Clinger) -> exact(this) -> C strtod.
# hexa-lang emit pass — target=x86_64-linux-gnu
# source: /home/aiden/hexa-lang/stdlib/runtime/float_parse_exact.hexa
.intel_syntax noprefix
.file 1 "stdlib/runtime/float_parse_exact.hexa"
.text
.globl fpe_norm
.hidden fpe_norm
    .p2align 4
fpe_norm:
    .loc 1 59 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 240 # prologue: alloc spill frame
    mov [rbp - 152], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.L7b0c_fpe_norm_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 152] # tag L0 from tag-slot
    call hexa_len # call hexa_len
    mov r12, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 160], r11 # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 160] # tag L1 from tag-slot
    mov [rbp - 168], r11 # store tag L2
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 168] # tag L2 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r14, rdx # binop -: capture result payload
    mov [rbp - 176], rax # store tag L3
    mov r15, r14 # assign L4
    mov r11, [rbp - 176] # tag L3 from tag-slot
    mov [rbp - 184], r11 # store tag L4
    jmp .L7b0c_fpe_norm_bb1 # branch
.L7b0c_fpe_norm_bb1:
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 184] # tag L4 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 192], rax # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_norm_bb3 # jump-if-zero -> else
    jmp .L7b0c_fpe_norm_bb2 # jump -> then
.L7b0c_fpe_norm_bb2:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 152] # tag L0 from tag-slot
    mov rcx, r15 # hv arg payload
    mov rdx, [rbp - 184] # tag L4 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 200], rax # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 200] # tag L6 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 208], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_norm_bb5 # jump-if-zero -> else
    jmp .L7b0c_fpe_norm_bb4 # jump -> then
.L7b0c_fpe_norm_bb3:
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 232], rax # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 232] # tag L10 from tag-slot
    mov [rbp - 240], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, 0 # assign L12
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 248], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    jmp .L7b0c_fpe_norm_bb6 # branch
.L7b0c_fpe_norm_bb4:
    jmp .L7b0c_fpe_norm_bb3 # branch
.L7b0c_fpe_norm_bb5:
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 184] # tag L4 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 224], rax # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov r15, r10 # assign L4
    mov r11, [rbp - 224] # tag L9 from tag-slot
    mov [rbp - 184], r11 # store tag L4
    jmp .L7b0c_fpe_norm_bb1 # branch
.L7b0c_fpe_norm_bb6:
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 248] # tag L12 from tag-slot
    mov rcx, r15 # hv arg payload
    mov rdx, [rbp - 184] # tag L4 from tag-slot
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 256], rax # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 120] # reload L13 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_norm_bb8 # jump-if-zero -> else
    jmp .L7b0c_fpe_norm_bb7 # jump -> then
.L7b0c_fpe_norm_bb7:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 152] # tag L0 from tag-slot
    mov rcx, [rbp - 112] # reload L12 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 248] # tag L12 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 264], rax # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov rsi, [rbp - 104] # reload L11 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 240] # tag L11 from tag-slot
    mov rcx, [rbp - 128] # reload L14 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 264] # tag L14 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 272], rax # store tag L15
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 248] # tag L12 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 280], rax # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 280] # tag L16 from tag-slot
    mov [rbp - 248], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    jmp .L7b0c_fpe_norm_bb6 # branch
.L7b0c_fpe_norm_bb8:
    mov rdx, [rbp - 104] # reload L11 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 240] # tag L11 from tag-slot
    add rsp, 240 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl fpe_is_zero
.hidden fpe_is_zero
    .p2align 4
fpe_is_zero:
    .loc 1 75 0
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
.L7b0c_fpe_is_zero_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 56] # tag L0 from tag-slot
    call hexa_len # call hexa_len
    mov r12, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 64], r11 # store tag L1
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 64] # tag L1 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r13, rdx # binop ==: capture bool payload
    mov [rbp - 72], rax # store tag L2
    test r13, r13 # br_cond test
    jz .L7b0c_fpe_is_zero_bb2 # jump-if-zero -> else
    jmp .L7b0c_fpe_is_zero_bb1 # jump -> then
.L7b0c_fpe_is_zero_bb1:
    mov rdx, 1 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 32 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_fpe_is_zero_bb2:
    mov rdx, 0 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 32 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl fpe_from
.hidden fpe_from
    .p2align 4
fpe_from:
    .loc 1 80 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 96 # prologue: alloc spill frame
    mov [rbp - 80], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.L7b0c_fpe_from_bb0:
    call hexa_array_new # array_lit: new array
    mov r12, rdx # array_lit: capture new array payload
    mov [rbp - 88], rax # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 88] # tag L1 from tag-slot
    mov [rbp - 96], r11 # store tag L2
    mov r14, rbx # assign L3
    mov r11, [rbp - 80] # tag L0 from tag-slot
    mov [rbp - 104], r11 # store tag L3
    jmp .L7b0c_fpe_from_bb1 # branch
.L7b0c_fpe_from_bb1:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 104] # tag L3 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r15, rdx # binop >: capture bool payload
    mov [rbp - 112], rax # store tag L4
    test r15, r15 # br_cond test
    jz .L7b0c_fpe_from_bb3 # jump-if-zero -> else
    jmp .L7b0c_fpe_from_bb2 # jump -> then
.L7b0c_fpe_from_bb2:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 104] # tag L3 from tag-slot
    mov rcx, 10000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mod # binop %: tag-dispatch hexa_mod
    mov r10, rdx # binop %: capture result payload
    mov [rbp - 120], rax # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 96] # tag L2 from tag-slot
    mov rcx, [rbp - 56] # reload L5 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 120] # tag L5 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 128], rax # store tag L6
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 64], r10 # spill L6 to slot
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 104] # tag L3 from tag-slot
    mov rcx, 10000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 136], rax # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 136] # tag L7 from tag-slot
    mov [rbp - 104], r11 # store tag L3
    jmp .L7b0c_fpe_from_bb1 # branch
.L7b0c_fpe_from_bb3:
    mov rdx, r13 # hv arg payload
    mov rax, [rbp - 96] # tag L2 from tag-slot
    add rsp, 96 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl fpe_cmp
.hidden fpe_cmp
    .p2align 4
fpe_cmp:
    .loc 1 90 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 352 # prologue: alloc spill frame
    mov [rbp - 208], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 216], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L7b0c_fpe_cmp_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 208] # tag L0 from tag-slot
    call hexa_len # call hexa_len
    mov r13, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 224], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 224] # tag L2 from tag-slot
    mov [rbp - 232], r11 # store tag L3
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 216] # tag L1 from tag-slot
    call hexa_len # call hexa_len
    mov r15, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 240], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 240] # tag L4 from tag-slot
    mov [rbp - 248], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 232] # tag L3 from tag-slot
    mov rcx, [rbp - 56] # reload L5 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 248] # tag L5 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 256], rax # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_cmp_bb2 # jump-if-zero -> else
    jmp .L7b0c_fpe_cmp_bb1 # jump -> then
.L7b0c_fpe_cmp_bb1:
    mov rsi, 0 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 272], rax # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov rdx, [rbp - 80] # reload L8 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 272] # tag L8 from tag-slot
    add rsp, 352 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_fpe_cmp_bb2:
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 232] # tag L3 from tag-slot
    mov rcx, [rbp - 56] # reload L5 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 248] # tag L5 from tag-slot
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 280], rax # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_cmp_bb4 # jump-if-zero -> else
    jmp .L7b0c_fpe_cmp_bb3 # jump -> then
.L7b0c_fpe_cmp_bb3:
    mov rdx, 1 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 352 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_fpe_cmp_bb4:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 232] # tag L3 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 296], rax # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 296] # tag L11 from tag-slot
    mov [rbp - 304], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    jmp .L7b0c_fpe_cmp_bb5 # branch
.L7b0c_fpe_cmp_bb5:
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 304] # tag L12 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 312], rax # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 120] # reload L13 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_cmp_bb7 # jump-if-zero -> else
    jmp .L7b0c_fpe_cmp_bb6 # jump -> then
.L7b0c_fpe_cmp_bb6:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 208] # tag L0 from tag-slot
    mov rcx, [rbp - 112] # reload L12 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 304] # tag L12 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 320], rax # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 216] # tag L1 from tag-slot
    mov rcx, [rbp - 112] # reload L12 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 304] # tag L12 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 328], rax # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 128] # reload L14 from spill slot
    mov r11, [rbp - 136] # reload L15 from spill slot
    mov rsi, [rbp - 128] # reload L14 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 320] # tag L14 from tag-slot
    mov rcx, [rbp - 136] # reload L15 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 328] # tag L15 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 336], rax # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r10, [rbp - 144] # reload L16 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_cmp_bb9 # jump-if-zero -> else
    jmp .L7b0c_fpe_cmp_bb8 # jump -> then
.L7b0c_fpe_cmp_bb7:
    mov rdx, 0 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 352 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_fpe_cmp_bb8:
    mov rsi, 0 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 352], rax # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov rdx, [rbp - 160] # reload L18 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 352] # tag L18 from tag-slot
    add rsp, 352 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_fpe_cmp_bb9:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 208] # tag L0 from tag-slot
    mov rcx, [rbp - 112] # reload L12 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 304] # tag L12 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 360], rax # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 216] # tag L1 from tag-slot
    mov rcx, [rbp - 112] # reload L12 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 304] # tag L12 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 368], rax # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, [rbp - 168] # reload L19 from spill slot
    mov r11, [rbp - 176] # reload L20 from spill slot
    mov rsi, [rbp - 168] # reload L19 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 360] # tag L19 from tag-slot
    mov rcx, [rbp - 176] # reload L20 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 368] # tag L20 from tag-slot
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 376], rax # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r10, [rbp - 184] # reload L21 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_cmp_bb11 # jump-if-zero -> else
    jmp .L7b0c_fpe_cmp_bb10 # jump -> then
.L7b0c_fpe_cmp_bb10:
    mov rdx, 1 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 352 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_fpe_cmp_bb11:
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 304] # tag L12 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 392], rax # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 392] # tag L23 from tag-slot
    mov [rbp - 304], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    jmp .L7b0c_fpe_cmp_bb5 # branch
    mov eax, 4 # value-less return: tag = TAG_VOID
    xor edx, edx # value-less return: payload = 0
    add rsp, 352 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl fpe_add
.hidden fpe_add
    .p2align 4
fpe_add:
    .loc 1 104 0
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
.L7b0c_fpe_add_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 280] # tag L0 from tag-slot
    call hexa_len # call hexa_len
    mov r13, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 296], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 296] # tag L2 from tag-slot
    mov [rbp - 304], r11 # store tag L3
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 288] # tag L1 from tag-slot
    call hexa_len # call hexa_len
    mov r15, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 312], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 312] # tag L4 from tag-slot
    mov [rbp - 320], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, r14 # assign L6
    mov r11, [rbp - 304] # tag L3 from tag-slot
    mov [rbp - 328], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 320] # tag L5 from tag-slot
    mov rcx, [rbp - 64] # reload L6 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 328] # tag L6 from tag-slot
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 336], rax # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_add_bb2 # jump-if-zero -> else
    jmp .L7b0c_fpe_add_bb1 # jump -> then
.L7b0c_fpe_add_bb1:
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 320] # tag L5 from tag-slot
    mov [rbp - 328], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    jmp .L7b0c_fpe_add_bb2 # branch
.L7b0c_fpe_add_bb2:
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 352], rax # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r10, r11 # assign L10
    mov r11, [rbp - 352] # tag L9 from tag-slot
    mov [rbp - 360], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, 0 # assign L11
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 368], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, 0 # assign L12
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 376], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    jmp .L7b0c_fpe_add_bb3 # branch
.L7b0c_fpe_add_bb3:
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 376] # tag L12 from tag-slot
    mov rcx, [rbp - 64] # reload L6 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 328] # tag L6 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 384], rax # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 120] # reload L13 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_add_bb5 # jump-if-zero -> else
    jmp .L7b0c_fpe_add_bb4 # jump -> then
.L7b0c_fpe_add_bb4:
    mov r10, 0 # assign L14
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 392], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 376] # tag L12 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 304] # tag L3 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 400], rax # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_add_bb7 # jump-if-zero -> else
    jmp .L7b0c_fpe_add_bb6 # jump -> then
.L7b0c_fpe_add_bb5:
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov rsi, [rbp - 104] # reload L11 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 368] # tag L11 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 512], rax # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r10, [rbp - 248] # reload L29 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_add_bb11 # jump-if-zero -> else
    jmp .L7b0c_fpe_add_bb10 # jump -> then
.L7b0c_fpe_add_bb6:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 280] # tag L0 from tag-slot
    mov rcx, [rbp - 112] # reload L12 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 376] # tag L12 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 416], rax # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r11, [rbp - 152] # reload L17 from spill slot
    mov r10, r11 # assign L14
    mov r11, [rbp - 416] # tag L17 from tag-slot
    mov [rbp - 392], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    jmp .L7b0c_fpe_add_bb7 # branch
.L7b0c_fpe_add_bb7:
    mov r10, 0 # assign L18
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 424], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 376] # tag L12 from tag-slot
    mov rcx, [rbp - 56] # reload L5 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 320] # tag L5 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 432], rax # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r10, [rbp - 168] # reload L19 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_add_bb9 # jump-if-zero -> else
    jmp .L7b0c_fpe_add_bb8 # jump -> then
.L7b0c_fpe_add_bb8:
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 288] # tag L1 from tag-slot
    mov rcx, [rbp - 112] # reload L12 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 376] # tag L12 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 448], rax # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L18
    mov r11, [rbp - 448] # tag L21 from tag-slot
    mov [rbp - 424], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    jmp .L7b0c_fpe_add_bb9 # branch
.L7b0c_fpe_add_bb9:
    mov r10, [rbp - 128] # reload L14 from spill slot
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov rsi, [rbp - 128] # reload L14 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 392] # tag L14 from tag-slot
    mov rcx, [rbp - 160] # reload L18 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 424] # tag L18 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 456], rax # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r10, [rbp - 192] # reload L22 from spill slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov rsi, [rbp - 192] # reload L22 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 456] # tag L22 from tag-slot
    mov rcx, [rbp - 104] # reload L11 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 368] # tag L11 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 464], rax # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 464] # tag L23 from tag-slot
    mov [rbp - 472], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov rsi, [rbp - 208] # reload L24 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 472] # tag L24 from tag-slot
    mov rcx, 10000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mod # binop %: tag-dispatch hexa_mod
    mov r10, rdx # binop %: capture result payload
    mov [rbp - 480], rax # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov rsi, [rbp - 96] # reload L10 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 360] # tag L10 from tag-slot
    mov rcx, [rbp - 216] # reload L25 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 480] # tag L25 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 488], rax # store tag L26
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 224], r10 # spill L26 to slot
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov rsi, [rbp - 208] # reload L24 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 472] # tag L24 from tag-slot
    mov rcx, 10000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 496], rax # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov r11, [rbp - 232] # reload L27 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 496] # tag L27 from tag-slot
    mov [rbp - 368], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 376] # tag L12 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 504], rax # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r11, [rbp - 240] # reload L28 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 504] # tag L28 from tag-slot
    mov [rbp - 376], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    jmp .L7b0c_fpe_add_bb3 # branch
.L7b0c_fpe_add_bb10:
    mov rsi, [rbp - 96] # reload L10 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 360] # tag L10 from tag-slot
    mov rcx, [rbp - 104] # reload L11 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 368] # tag L11 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 528], rax # store tag L31
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 264], r10 # spill L31 to slot
    jmp .L7b0c_fpe_add_bb11 # branch
.L7b0c_fpe_add_bb11:
    mov rsi, [rbp - 96] # reload L10 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 360] # tag L10 from tag-slot
    call fpe_norm # call fpe_norm
    mov [rbp - 536], rax # store tag L32
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 272], r10 # spill L32 to slot
    mov rdx, [rbp - 272] # reload L32 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 536] # tag L32 from tag-slot
    add rsp, 496 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl fpe_sub
.hidden fpe_sub
    .p2align 4
fpe_sub:
    .loc 1 127 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 384 # prologue: alloc spill frame
    mov [rbp - 224], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 232], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L7b0c_fpe_sub_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 224] # tag L0 from tag-slot
    call hexa_len # call hexa_len
    mov r13, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 240], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 240] # tag L2 from tag-slot
    mov [rbp - 248], r11 # store tag L3
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 232] # tag L1 from tag-slot
    call hexa_len # call hexa_len
    mov r15, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 256], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 256] # tag L4 from tag-slot
    mov [rbp - 264], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 272], rax # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 272] # tag L6 from tag-slot
    mov [rbp - 280], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, 0 # assign L8
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 288], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, 0 # assign L9
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 296], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    jmp .L7b0c_fpe_sub_bb1 # branch
.L7b0c_fpe_sub_bb1:
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 296] # tag L9 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 248] # tag L3 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 304], rax # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_sub_bb3 # jump-if-zero -> else
    jmp .L7b0c_fpe_sub_bb2 # jump -> then
.L7b0c_fpe_sub_bb2:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 224] # tag L0 from tag-slot
    mov rcx, [rbp - 88] # reload L9 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 296] # tag L9 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 312], rax # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 312] # tag L11 from tag-slot
    mov [rbp - 320], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, 0 # assign L13
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 328], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 296] # tag L9 from tag-slot
    mov rcx, [rbp - 56] # reload L5 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 264] # tag L5 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 336], rax # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r10, [rbp - 128] # reload L14 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_sub_bb5 # jump-if-zero -> else
    jmp .L7b0c_fpe_sub_bb4 # jump -> then
.L7b0c_fpe_sub_bb3:
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 280] # tag L7 from tag-slot
    call fpe_norm # call fpe_norm
    mov [rbp - 424], rax # store tag L25
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 216], r10 # spill L25 to slot
    mov rdx, [rbp - 216] # reload L25 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 424] # tag L25 from tag-slot
    add rsp, 384 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_fpe_sub_bb4:
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 232] # tag L1 from tag-slot
    mov rcx, [rbp - 88] # reload L9 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 296] # tag L9 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 352], rax # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 352] # tag L16 from tag-slot
    mov [rbp - 328], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    jmp .L7b0c_fpe_sub_bb5 # branch
.L7b0c_fpe_sub_bb5:
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 320] # tag L12 from tag-slot
    mov rcx, [rbp - 120] # reload L13 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 328] # tag L13 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 360], rax # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov rsi, [rbp - 152] # reload L17 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 360] # tag L17 from tag-slot
    mov rcx, [rbp - 80] # reload L8 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 288] # tag L8 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 368], rax # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov r10, r11 # assign L19
    mov r11, [rbp - 368] # tag L18 from tag-slot
    mov [rbp - 376], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r10, [rbp - 168] # reload L19 from spill slot
    mov rsi, [rbp - 168] # reload L19 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 376] # tag L19 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 384], rax # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, [rbp - 176] # reload L20 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_sub_bb7 # jump-if-zero -> else
    jmp .L7b0c_fpe_sub_bb6 # jump -> then
.L7b0c_fpe_sub_bb6:
    mov r10, [rbp - 168] # reload L19 from spill slot
    mov rsi, [rbp - 168] # reload L19 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 376] # tag L19 from tag-slot
    mov rcx, 10000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 400], rax # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r10, r11 # assign L19
    mov r11, [rbp - 400] # tag L22 from tag-slot
    mov [rbp - 376], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r10, 1 # assign L8
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 288], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    jmp .L7b0c_fpe_sub_bb8 # branch
.L7b0c_fpe_sub_bb7:
    mov r10, 0 # assign L8
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 288], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    jmp .L7b0c_fpe_sub_bb8 # branch
.L7b0c_fpe_sub_bb8:
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 280] # tag L7 from tag-slot
    mov rcx, [rbp - 168] # reload L19 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 376] # tag L19 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 408], rax # store tag L23
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 200], r10 # spill L23 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 296] # tag L9 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 416], rax # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r11, [rbp - 208] # reload L24 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 416] # tag L24 from tag-slot
    mov [rbp - 296], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    jmp .L7b0c_fpe_sub_bb1 # branch
    mov eax, 4 # value-less return: tag = TAG_VOID
    xor edx, edx # value-less return: payload = 0
    add rsp, 384 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl fpe_mul_small
.hidden fpe_mul_small
    .p2align 4
fpe_mul_small:
    .loc 1 150 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 368 # prologue: alloc spill frame
    mov [rbp - 216], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 224], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L7b0c_fpe_mul_small_bb0:
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 224] # tag L1 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r13, rdx # binop ==: capture bool payload
    mov [rbp - 232], rax # store tag L2
    test r13, r13 # br_cond test
    jz .L7b0c_fpe_mul_small_bb2 # jump-if-zero -> else
    jmp .L7b0c_fpe_mul_small_bb1 # jump -> then
.L7b0c_fpe_mul_small_bb1:
    call hexa_array_new # array_lit: new array
    mov r15, rdx # array_lit: capture new array payload
    mov [rbp - 248], rax # store tag L4
    mov rdx, r15 # hv arg payload
    mov rax, [rbp - 248] # tag L4 from tag-slot
    add rsp, 368 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_fpe_mul_small_bb2:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 216] # tag L0 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 256], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 256] # tag L5 from tag-slot
    mov [rbp - 264], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 272], rax # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 272] # tag L7 from tag-slot
    mov [rbp - 280], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, 0 # assign L9
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 288], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, 0 # assign L10
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 296], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    jmp .L7b0c_fpe_mul_small_bb3 # branch
.L7b0c_fpe_mul_small_bb3:
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 96] # reload L10 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 296] # tag L10 from tag-slot
    mov rcx, [rbp - 64] # reload L6 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 264] # tag L6 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 304], rax # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 104] # reload L11 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_mul_small_bb5 # jump-if-zero -> else
    jmp .L7b0c_fpe_mul_small_bb4 # jump -> then
.L7b0c_fpe_mul_small_bb4:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 216] # tag L0 from tag-slot
    mov rcx, [rbp - 96] # reload L10 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 296] # tag L10 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 312], rax # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 312] # tag L12 from tag-slot
    mov rcx, r12 # hv arg payload
    mov rdx, [rbp - 224] # tag L1 from tag-slot
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 320], rax # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 320] # tag L13 from tag-slot
    mov rcx, [rbp - 88] # reload L9 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 288] # tag L9 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 328], rax # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 328] # tag L14 from tag-slot
    mov [rbp - 336], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 336] # tag L15 from tag-slot
    mov rcx, 10000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mod # binop %: tag-dispatch hexa_mod
    mov r10, rdx # binop %: capture result payload
    mov [rbp - 344], rax # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 280] # tag L8 from tag-slot
    mov rcx, [rbp - 144] # reload L16 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 344] # tag L16 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 352], rax # store tag L17
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 336] # tag L15 from tag-slot
    mov rcx, 10000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 360], rax # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 360] # tag L18 from tag-slot
    mov [rbp - 288], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov rsi, [rbp - 96] # reload L10 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 296] # tag L10 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 368], rax # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov r10, r11 # assign L10
    mov r11, [rbp - 368] # tag L19 from tag-slot
    mov [rbp - 296], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    jmp .L7b0c_fpe_mul_small_bb3 # branch
.L7b0c_fpe_mul_small_bb5:
    jmp .L7b0c_fpe_mul_small_bb6 # branch
.L7b0c_fpe_mul_small_bb6:
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 288] # tag L9 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 376], rax # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, [rbp - 176] # reload L20 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_mul_small_bb8 # jump-if-zero -> else
    jmp .L7b0c_fpe_mul_small_bb7 # jump -> then
.L7b0c_fpe_mul_small_bb7:
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 288] # tag L9 from tag-slot
    mov rcx, 10000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mod # binop %: tag-dispatch hexa_mod
    mov r10, rdx # binop %: capture result payload
    mov [rbp - 384], rax # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 280] # tag L8 from tag-slot
    mov rcx, [rbp - 184] # reload L21 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 384] # tag L21 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 392], rax # store tag L22
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 192], r10 # spill L22 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 288] # tag L9 from tag-slot
    mov rcx, 10000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 400], rax # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 400] # tag L23 from tag-slot
    mov [rbp - 288], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    jmp .L7b0c_fpe_mul_small_bb6 # branch
.L7b0c_fpe_mul_small_bb8:
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 280] # tag L8 from tag-slot
    call fpe_norm # call fpe_norm
    mov [rbp - 408], rax # store tag L24
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 208], r10 # spill L24 to slot
    mov rdx, [rbp - 208] # reload L24 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 408] # tag L24 from tag-slot
    add rsp, 368 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl fpe_mul
.hidden fpe_mul
    .p2align 4
fpe_mul:
    .loc 1 169 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 752 # prologue: alloc spill frame
    mov [rbp - 408], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 416], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L7b0c_fpe_mul_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 408] # tag L0 from tag-slot
    call fpe_is_zero # call fpe_is_zero
    mov [rbp - 424], rax # store tag L2
    mov r13, rdx # hv: unbox user-call result payload
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 424] # tag L2 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r14, rdx # binop ==: capture bool payload
    mov [rbp - 432], rax # store tag L3
    test r14, r14 # br_cond test
    jz .L7b0c_fpe_mul_bb2 # jump-if-zero -> else
    jmp .L7b0c_fpe_mul_bb1 # jump -> then
.L7b0c_fpe_mul_bb1:
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 448], rax # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov rdx, [rbp - 56] # reload L5 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 448] # tag L5 from tag-slot
    add rsp, 752 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_fpe_mul_bb2:
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 416] # tag L1 from tag-slot
    call fpe_is_zero # call fpe_is_zero
    mov [rbp - 456], rax # store tag L6
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 456] # tag L6 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 464], rax # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_mul_bb4 # jump-if-zero -> else
    jmp .L7b0c_fpe_mul_bb3 # jump -> then
.L7b0c_fpe_mul_bb3:
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 480], rax # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov rdx, [rbp - 88] # reload L9 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 480] # tag L9 from tag-slot
    add rsp, 752 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_fpe_mul_bb4:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 408] # tag L0 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 488], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 488] # tag L10 from tag-slot
    mov [rbp - 496], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 416] # tag L1 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 504], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 504] # tag L12 from tag-slot
    mov [rbp - 512], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 520], rax # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 520] # tag L14 from tag-slot
    mov [rbp - 528], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, 0 # assign L16
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 536], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    jmp .L7b0c_fpe_mul_bb5 # branch
.L7b0c_fpe_mul_bb5:
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov rsi, [rbp - 104] # reload L11 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 496] # tag L11 from tag-slot
    mov rcx, [rbp - 120] # reload L13 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 512] # tag L13 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 544], rax # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 144] # reload L16 from spill slot
    mov r11, [rbp - 152] # reload L17 from spill slot
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 536] # tag L16 from tag-slot
    mov rcx, [rbp - 152] # reload L17 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 544] # tag L17 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 552], rax # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r10, [rbp - 160] # reload L18 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_mul_bb7 # jump-if-zero -> else
    jmp .L7b0c_fpe_mul_bb6 # jump -> then
.L7b0c_fpe_mul_bb6:
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 528] # tag L15 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 560], rax # store tag L19
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 168], r10 # spill L19 to slot
    mov r10, [rbp - 144] # reload L16 from spill slot
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 536] # tag L16 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 568], rax # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r11, [rbp - 176] # reload L20 from spill slot
    mov r10, r11 # assign L16
    mov r11, [rbp - 568] # tag L20 from tag-slot
    mov [rbp - 536], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    jmp .L7b0c_fpe_mul_bb5 # branch
.L7b0c_fpe_mul_bb7:
    mov r10, 0 # assign L21
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 576], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    jmp .L7b0c_fpe_mul_bb8 # branch
.L7b0c_fpe_mul_bb8:
    mov r10, [rbp - 184] # reload L21 from spill slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov rsi, [rbp - 184] # reload L21 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 576] # tag L21 from tag-slot
    mov rcx, [rbp - 104] # reload L11 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 496] # tag L11 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 584], rax # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r10, [rbp - 192] # reload L22 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_mul_bb10 # jump-if-zero -> else
    jmp .L7b0c_fpe_mul_bb9 # jump -> then
.L7b0c_fpe_mul_bb9:
    mov r10, 0 # assign L23
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 592], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r10, 0 # assign L24
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 600], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    jmp .L7b0c_fpe_mul_bb11 # branch
.L7b0c_fpe_mul_bb10:
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 528] # tag L15 from tag-slot
    call fpe_norm # call fpe_norm
    mov [rbp - 792], rax # store tag L48
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 400], r10 # spill L48 to slot
    mov rdx, [rbp - 400] # reload L48 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 792] # tag L48 from tag-slot
    add rsp, 752 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_fpe_mul_bb11:
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov rsi, [rbp - 208] # reload L24 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 600] # tag L24 from tag-slot
    mov rcx, [rbp - 120] # reload L13 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 512] # tag L13 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 608], rax # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r10, [rbp - 216] # reload L25 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_mul_bb13 # jump-if-zero -> else
    jmp .L7b0c_fpe_mul_bb12 # jump -> then
.L7b0c_fpe_mul_bb12:
    mov r10, [rbp - 184] # reload L21 from spill slot
    mov r11, [rbp - 208] # reload L24 from spill slot
    mov rsi, [rbp - 184] # reload L21 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 576] # tag L21 from tag-slot
    mov rcx, [rbp - 208] # reload L24 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 600] # tag L24 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 616], rax # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r11, [rbp - 224] # reload L26 from spill slot
    mov r10, r11 # assign L27
    mov r11, [rbp - 616] # tag L26 from tag-slot
    mov [rbp - 624], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 528] # tag L15 from tag-slot
    mov rcx, [rbp - 232] # reload L27 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 624] # tag L27 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 632], rax # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 408] # tag L0 from tag-slot
    mov rcx, [rbp - 184] # reload L21 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 576] # tag L21 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 640], rax # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 416] # tag L1 from tag-slot
    mov rcx, [rbp - 208] # reload L24 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 600] # tag L24 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 648], rax # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r10, [rbp - 248] # reload L29 from spill slot
    mov r11, [rbp - 256] # reload L30 from spill slot
    mov rsi, [rbp - 248] # reload L29 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 640] # tag L29 from tag-slot
    mov rcx, [rbp - 256] # reload L30 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 648] # tag L30 from tag-slot
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 656], rax # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov r10, [rbp - 240] # reload L28 from spill slot
    mov r11, [rbp - 264] # reload L31 from spill slot
    mov rsi, [rbp - 240] # reload L28 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 632] # tag L28 from tag-slot
    mov rcx, [rbp - 264] # reload L31 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 656] # tag L31 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 664], rax # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov rsi, [rbp - 272] # reload L32 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 664] # tag L32 from tag-slot
    mov rcx, [rbp - 200] # reload L23 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 592] # tag L23 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 672], rax # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r11, [rbp - 280] # reload L33 from spill slot
    mov r10, r11 # assign L34
    mov r11, [rbp - 672] # tag L33 from tag-slot
    mov [rbp - 680], r11 # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    mov r10, [rbp - 288] # reload L34 from spill slot
    mov rsi, [rbp - 288] # reload L34 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 680] # tag L34 from tag-slot
    mov rcx, 10000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mod # binop %: tag-dispatch hexa_mod
    mov r10, rdx # binop %: capture result payload
    mov [rbp - 688], rax # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 528] # tag L15 from tag-slot
    mov rcx, [rbp - 232] # reload L27 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 624] # tag L27 from tag-slot
    mov r9, [rbp - 296] # reload L35 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 688] # tag L35 from tag-slot
    call hexa_index_set # index_set: hexa_index_set
    mov r10, rdx # index_set: store-back container payload
    mov [rbp - 528], rax # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 288] # reload L34 from spill slot
    mov rsi, [rbp - 288] # reload L34 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 680] # tag L34 from tag-slot
    mov rcx, 10000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 696], rax # store tag L36
    mov [rbp - 304], r10 # spill L36 to slot
    mov r11, [rbp - 304] # reload L36 from spill slot
    mov r10, r11 # assign L23
    mov r11, [rbp - 696] # tag L36 from tag-slot
    mov [rbp - 592], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov rsi, [rbp - 208] # reload L24 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 600] # tag L24 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 704], rax # store tag L37
    mov [rbp - 312], r10 # spill L37 to slot
    mov r11, [rbp - 312] # reload L37 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 704] # tag L37 from tag-slot
    mov [rbp - 600], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    jmp .L7b0c_fpe_mul_bb11 # branch
.L7b0c_fpe_mul_bb13:
    mov r10, [rbp - 184] # reload L21 from spill slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov rsi, [rbp - 184] # reload L21 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 576] # tag L21 from tag-slot
    mov rcx, [rbp - 120] # reload L13 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 512] # tag L13 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 712], rax # store tag L38
    mov [rbp - 320], r10 # spill L38 to slot
    mov r11, [rbp - 320] # reload L38 from spill slot
    mov r10, r11 # assign L39
    mov r11, [rbp - 712] # tag L38 from tag-slot
    mov [rbp - 720], r11 # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    jmp .L7b0c_fpe_mul_bb14 # branch
.L7b0c_fpe_mul_bb14:
    mov r10, [rbp - 200] # reload L23 from spill slot
    mov rsi, [rbp - 200] # reload L23 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 592] # tag L23 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 728], rax # store tag L40
    mov [rbp - 336], r10 # spill L40 to slot
    mov r10, [rbp - 336] # reload L40 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_mul_bb16 # jump-if-zero -> else
    jmp .L7b0c_fpe_mul_bb15 # jump -> then
.L7b0c_fpe_mul_bb15:
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 528] # tag L15 from tag-slot
    mov rcx, [rbp - 328] # reload L39 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 720] # tag L39 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 736], rax # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov rsi, [rbp - 344] # reload L41 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 736] # tag L41 from tag-slot
    mov rcx, [rbp - 200] # reload L23 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 592] # tag L23 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 744], rax # store tag L42
    mov [rbp - 352], r10 # spill L42 to slot
    mov r11, [rbp - 352] # reload L42 from spill slot
    mov r10, r11 # assign L43
    mov r11, [rbp - 744] # tag L42 from tag-slot
    mov [rbp - 752], r11 # store tag L43
    mov [rbp - 360], r10 # spill L43 to slot
    mov r10, [rbp - 360] # reload L43 from spill slot
    mov rsi, [rbp - 360] # reload L43 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 752] # tag L43 from tag-slot
    mov rcx, 10000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mod # binop %: tag-dispatch hexa_mod
    mov r10, rdx # binop %: capture result payload
    mov [rbp - 760], rax # store tag L44
    mov [rbp - 368], r10 # spill L44 to slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 528] # tag L15 from tag-slot
    mov rcx, [rbp - 328] # reload L39 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 720] # tag L39 from tag-slot
    mov r9, [rbp - 368] # reload L44 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 760] # tag L44 from tag-slot
    call hexa_index_set # index_set: hexa_index_set
    mov r10, rdx # index_set: store-back container payload
    mov [rbp - 528], rax # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 360] # reload L43 from spill slot
    mov rsi, [rbp - 360] # reload L43 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 752] # tag L43 from tag-slot
    mov rcx, 10000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 768], rax # store tag L45
    mov [rbp - 376], r10 # spill L45 to slot
    mov r11, [rbp - 376] # reload L45 from spill slot
    mov r10, r11 # assign L23
    mov r11, [rbp - 768] # tag L45 from tag-slot
    mov [rbp - 592], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r10, [rbp - 328] # reload L39 from spill slot
    mov rsi, [rbp - 328] # reload L39 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 720] # tag L39 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 776], rax # store tag L46
    mov [rbp - 384], r10 # spill L46 to slot
    mov r11, [rbp - 384] # reload L46 from spill slot
    mov r10, r11 # assign L39
    mov r11, [rbp - 776] # tag L46 from tag-slot
    mov [rbp - 720], r11 # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    jmp .L7b0c_fpe_mul_bb14 # branch
.L7b0c_fpe_mul_bb16:
    mov r10, [rbp - 184] # reload L21 from spill slot
    mov rsi, [rbp - 184] # reload L21 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 576] # tag L21 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 784], rax # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    mov r11, [rbp - 392] # reload L47 from spill slot
    mov r10, r11 # assign L21
    mov r11, [rbp - 784] # tag L47 from tag-slot
    mov [rbp - 576], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    jmp .L7b0c_fpe_mul_bb8 # branch
    mov eax, 4 # value-less return: tag = TAG_VOID
    xor edx, edx # value-less return: payload = 0
    add rsp, 752 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl fpe_pow2
.hidden fpe_pow2
    .p2align 4
fpe_pow2:
    .loc 1 204 0
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
.L7b0c_fpe_pow2_bb0:
    call hexa_array_new # array_lit: new array
    mov r12, rdx # array_lit: capture new array payload
    mov [rbp - 136], rax # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 136] # tag L1 from tag-slot
    mov [rbp - 144], r11 # store tag L2
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 144] # tag L2 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 152], rax # store tag L3
    mov r14, rdx # hv: unbox call result (rdx)
    mov r15, rbx # assign L4
    mov r11, [rbp - 128] # tag L0 from tag-slot
    mov [rbp - 160], r11 # store tag L4
    jmp .L7b0c_fpe_pow2_bb1 # branch
.L7b0c_fpe_pow2_bb1:
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 160] # tag L4 from tag-slot
    mov rcx, 13 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 168], rax # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_pow2_bb3 # jump-if-zero -> else
    jmp .L7b0c_fpe_pow2_bb2 # jump -> then
.L7b0c_fpe_pow2_bb2:
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 144] # tag L2 from tag-slot
    mov rcx, 8192 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call fpe_mul_small # call fpe_mul_small
    mov [rbp - 176], rax # store tag L6
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r13, r10 # assign L2
    mov r11, [rbp - 176] # tag L6 from tag-slot
    mov [rbp - 144], r11 # store tag L2
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 160] # tag L4 from tag-slot
    mov rcx, 13 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 184], rax # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r15, r10 # assign L4
    mov r11, [rbp - 184] # tag L7 from tag-slot
    mov [rbp - 160], r11 # store tag L4
    jmp .L7b0c_fpe_pow2_bb1 # branch
.L7b0c_fpe_pow2_bb3:
    mov r10, 1 # assign L8
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 192], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, 0 # assign L9
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 200], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    jmp .L7b0c_fpe_pow2_bb4 # branch
.L7b0c_fpe_pow2_bb4:
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 200] # tag L9 from tag-slot
    mov rcx, r15 # hv arg payload
    mov rdx, [rbp - 160] # tag L4 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 208], rax # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_pow2_bb6 # jump-if-zero -> else
    jmp .L7b0c_fpe_pow2_bb5 # jump -> then
.L7b0c_fpe_pow2_bb5:
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 192] # tag L8 from tag-slot
    mov rcx, 2 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 216], rax # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 216] # tag L11 from tag-slot
    mov [rbp - 192], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 200] # tag L9 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 224], rax # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 224] # tag L12 from tag-slot
    mov [rbp - 200], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    jmp .L7b0c_fpe_pow2_bb4 # branch
.L7b0c_fpe_pow2_bb6:
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 144] # tag L2 from tag-slot
    mov rcx, [rbp - 80] # reload L8 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 192] # tag L8 from tag-slot
    call fpe_mul_small # call fpe_mul_small
    mov [rbp - 232], rax # store tag L13
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov r13, r10 # assign L2
    mov r11, [rbp - 232] # tag L13 from tag-slot
    mov [rbp - 144], r11 # store tag L2
    mov rdx, r13 # hv arg payload
    mov rax, [rbp - 144] # tag L2 from tag-slot
    add rsp, 192 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl fpe_pow10
.hidden fpe_pow10
    .p2align 4
fpe_pow10:
    .loc 1 223 0
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
.L7b0c_fpe_pow10_bb0:
    call hexa_array_new # array_lit: new array
    mov r12, rdx # array_lit: capture new array payload
    mov [rbp - 136], rax # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 136] # tag L1 from tag-slot
    mov [rbp - 144], r11 # store tag L2
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 144] # tag L2 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_array_push # call hexa_array_push
    mov [rbp - 152], rax # store tag L3
    mov r14, rdx # hv: unbox call result (rdx)
    mov r15, rbx # assign L4
    mov r11, [rbp - 128] # tag L0 from tag-slot
    mov [rbp - 160], r11 # store tag L4
    jmp .L7b0c_fpe_pow10_bb1 # branch
.L7b0c_fpe_pow10_bb1:
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 160] # tag L4 from tag-slot
    mov rcx, 4 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 168], rax # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_pow10_bb3 # jump-if-zero -> else
    jmp .L7b0c_fpe_pow10_bb2 # jump -> then
.L7b0c_fpe_pow10_bb2:
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 144] # tag L2 from tag-slot
    mov rcx, 10000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call fpe_mul_small # call fpe_mul_small
    mov [rbp - 176], rax # store tag L6
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r13, r10 # assign L2
    mov r11, [rbp - 176] # tag L6 from tag-slot
    mov [rbp - 144], r11 # store tag L2
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 160] # tag L4 from tag-slot
    mov rcx, 4 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 184], rax # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r15, r10 # assign L4
    mov r11, [rbp - 184] # tag L7 from tag-slot
    mov [rbp - 160], r11 # store tag L4
    jmp .L7b0c_fpe_pow10_bb1 # branch
.L7b0c_fpe_pow10_bb3:
    mov r10, 1 # assign L8
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 192], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, 0 # assign L9
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 200], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    jmp .L7b0c_fpe_pow10_bb4 # branch
.L7b0c_fpe_pow10_bb4:
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 200] # tag L9 from tag-slot
    mov rcx, r15 # hv arg payload
    mov rdx, [rbp - 160] # tag L4 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 208], rax # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_pow10_bb6 # jump-if-zero -> else
    jmp .L7b0c_fpe_pow10_bb5 # jump -> then
.L7b0c_fpe_pow10_bb5:
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 192] # tag L8 from tag-slot
    mov rcx, 10 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 216], rax # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 216] # tag L11 from tag-slot
    mov [rbp - 192], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 200] # tag L9 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 224], rax # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 224] # tag L12 from tag-slot
    mov [rbp - 200], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    jmp .L7b0c_fpe_pow10_bb4 # branch
.L7b0c_fpe_pow10_bb6:
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 144] # tag L2 from tag-slot
    mov rcx, [rbp - 80] # reload L8 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 192] # tag L8 from tag-slot
    call fpe_mul_small # call fpe_mul_small
    mov [rbp - 232], rax # store tag L13
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov r13, r10 # assign L2
    mov r11, [rbp - 232] # tag L13 from tag-slot
    mov [rbp - 144], r11 # store tag L2
    mov rdx, r13 # hv arg payload
    mov rax, [rbp - 144] # tag L2 from tag-slot
    add rsp, 192 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl fpe_shl
.hidden fpe_shl
    .p2align 4
fpe_shl:
    .loc 1 242 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 112 # prologue: alloc spill frame
    mov [rbp - 88], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 96], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L7b0c_fpe_shl_bb0:
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 96] # tag L1 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r13, rdx # binop ==: capture bool payload
    mov [rbp - 104], rax # store tag L2
    test r13, r13 # br_cond test
    jz .L7b0c_fpe_shl_bb2 # jump-if-zero -> else
    jmp .L7b0c_fpe_shl_bb1 # jump -> then
.L7b0c_fpe_shl_bb1:
    mov rdx, rbx # hv arg payload
    mov rax, [rbp - 88] # tag L0 from tag-slot
    add rsp, 112 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_fpe_shl_bb2:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 88] # tag L0 from tag-slot
    call fpe_is_zero # call fpe_is_zero
    mov [rbp - 120], rax # store tag L4
    mov r15, rdx # hv: unbox user-call result payload
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 120] # tag L4 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 128], rax # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_shl_bb4 # jump-if-zero -> else
    jmp .L7b0c_fpe_shl_bb3 # jump -> then
.L7b0c_fpe_shl_bb3:
    mov rdx, rbx # hv arg payload
    mov rax, [rbp - 88] # tag L0 from tag-slot
    add rsp, 112 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_fpe_shl_bb4:
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 96] # tag L1 from tag-slot
    call fpe_pow2 # call fpe_pow2
    mov [rbp - 144], rax # store tag L7
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 72], r10 # spill L7 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 88] # tag L0 from tag-slot
    mov rcx, [rbp - 72] # reload L7 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 144] # tag L7 from tag-slot
    call fpe_mul # call fpe_mul
    mov [rbp - 152], rax # store tag L8
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 80], r10 # spill L8 to slot
    mov rdx, [rbp - 80] # reload L8 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 152] # tag L8 from tag-slot
    add rsp, 112 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl fpe_ilog2
.hidden fpe_ilog2
    .p2align 4
fpe_ilog2:
    .loc 1 248 0
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
.L7b0c_fpe_ilog2_bb0:
    mov r12, 0 # assign L1
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 72], r11 # store tag L1
    mov r13, rbx # assign L2
    mov r11, [rbp - 64] # tag L0 from tag-slot
    mov [rbp - 80], r11 # store tag L2
    jmp .L7b0c_fpe_ilog2_bb1 # branch
.L7b0c_fpe_ilog2_bb1:
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 80] # tag L2 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r14, rdx # binop >: capture bool payload
    mov [rbp - 88], rax # store tag L3
    test r14, r14 # br_cond test
    jz .L7b0c_fpe_ilog2_bb3 # jump-if-zero -> else
    jmp .L7b0c_fpe_ilog2_bb2 # jump -> then
.L7b0c_fpe_ilog2_bb2:
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 80] # tag L2 from tag-slot
    mov rcx, 2 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r15, rdx # binop /: capture result payload
    mov [rbp - 96], rax # store tag L4
    mov r13, r15 # assign L2
    mov r11, [rbp - 96] # tag L4 from tag-slot
    mov [rbp - 80], r11 # store tag L2
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 72] # tag L1 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 104], rax # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r12, r10 # assign L1
    mov r11, [rbp - 104] # tag L5 from tag-slot
    mov [rbp - 72], r11 # store tag L1
    jmp .L7b0c_fpe_ilog2_bb1 # branch
.L7b0c_fpe_ilog2_bb3:
    mov rdx, r12 # hv arg payload
    mov rax, [rbp - 72] # tag L1 from tag-slot
    add rsp, 64 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl fpe_bitlen
.hidden fpe_bitlen
    .p2align 4
fpe_bitlen:
    .loc 1 259 0
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
.L7b0c_fpe_bitlen_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 128] # tag L0 from tag-slot
    call fpe_is_zero # call fpe_is_zero
    mov [rbp - 136], rax # store tag L1
    mov r12, rdx # hv: unbox user-call result payload
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 136] # tag L1 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r13, rdx # binop ==: capture bool payload
    mov [rbp - 144], rax # store tag L2
    test r13, r13 # br_cond test
    jz .L7b0c_fpe_bitlen_bb2 # jump-if-zero -> else
    jmp .L7b0c_fpe_bitlen_bb1 # jump -> then
.L7b0c_fpe_bitlen_bb1:
    mov rdx, 0 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 192 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_fpe_bitlen_bb2:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 128] # tag L0 from tag-slot
    call hexa_len # call hexa_len
    mov r15, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 160], r11 # store tag L4
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 160] # tag L4 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 168], rax # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 168] # tag L5 from tag-slot
    mov [rbp - 176], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 128] # tag L0 from tag-slot
    mov rcx, [rbp - 64] # reload L6 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 176] # tag L6 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 184], rax # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 184] # tag L7 from tag-slot
    mov [rbp - 192], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 176] # tag L6 from tag-slot
    mov rcx, 132877 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 200], rax # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 200] # tag L9 from tag-slot
    mov rcx, 10000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 208], rax # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 192] # tag L8 from tag-slot
    call fpe_ilog2 # call fpe_ilog2
    mov [rbp - 216], rax # store tag L11
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov rsi, [rbp - 96] # reload L10 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 208] # tag L10 from tag-slot
    mov rcx, [rbp - 104] # reload L11 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 216] # tag L11 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 224], rax # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 224] # tag L12 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 232], rax # store tag L13
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
.globl fpe_divmod
.hidden fpe_divmod
    .p2align 4
fpe_divmod:
    .loc 1 268 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 1056 # prologue: alloc spill frame
    mov [rbp - 560], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 568], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L7b0c_fpe_divmod_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 560] # tag L0 from tag-slot
    call fpe_is_zero # call fpe_is_zero
    mov [rbp - 576], rax # store tag L2
    mov r13, rdx # hv: unbox user-call result payload
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 576] # tag L2 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r14, rdx # binop ==: capture bool payload
    mov [rbp - 584], rax # store tag L3
    test r14, r14 # br_cond test
    jz .L7b0c_fpe_divmod_bb2 # jump-if-zero -> else
    jmp .L7b0c_fpe_divmod_bb1 # jump -> then
.L7b0c_fpe_divmod_bb1:
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 600], rax # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 600] # tag L5 from tag-slot
    mov [rbp - 608], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 616], rax # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 608] # tag L6 from tag-slot
    mov rcx, [rbp - 72] # reload L7 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 616] # tag L7 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 624], rax # store tag L8
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 80], r10 # spill L8 to slot
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 632], rax # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 608] # tag L6 from tag-slot
    mov rcx, [rbp - 88] # reload L9 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 632] # tag L9 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 640], rax # store tag L10
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 96], r10 # spill L10 to slot
    mov rdx, [rbp - 64] # reload L6 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 608] # tag L6 from tag-slot
    add rsp, 1056 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_fpe_divmod_bb2:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 560] # tag L0 from tag-slot
    mov rcx, r12 # hv arg payload
    mov rdx, [rbp - 568] # tag L1 from tag-slot
    call fpe_cmp # call fpe_cmp
    mov [rbp - 648], rax # store tag L11
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov rsi, [rbp - 104] # reload L11 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 648] # tag L11 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 656], rax # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_divmod_bb4 # jump-if-zero -> else
    jmp .L7b0c_fpe_divmod_bb3 # jump -> then
.L7b0c_fpe_divmod_bb3:
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 672], rax # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 672] # tag L14 from tag-slot
    mov [rbp - 680], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 688], rax # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 680] # tag L15 from tag-slot
    mov rcx, [rbp - 144] # reload L16 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 688] # tag L16 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 696], rax # store tag L17
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 152], r10 # spill L17 to slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 680] # tag L15 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 560] # tag L0 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 704], rax # store tag L18
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 160], r10 # spill L18 to slot
    mov rdx, [rbp - 136] # reload L15 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 680] # tag L15 from tag-slot
    add rsp, 1056 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_fpe_divmod_bb4:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 560] # tag L0 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 712], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov r10, r11 # assign L20
    mov r11, [rbp - 712] # tag L19 from tag-slot
    mov [rbp - 720], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 728], rax # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 728] # tag L21 from tag-slot
    mov [rbp - 736], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 744], rax # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 744] # tag L23 from tag-slot
    mov [rbp - 752], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r10, [rbp - 176] # reload L20 from spill slot
    mov rsi, [rbp - 176] # reload L20 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 720] # tag L20 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 760], rax # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r11, [rbp - 216] # reload L25 from spill slot
    mov r10, r11 # assign L26
    mov r11, [rbp - 760] # tag L25 from tag-slot
    mov [rbp - 768], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    jmp .L7b0c_fpe_divmod_bb5 # branch
.L7b0c_fpe_divmod_bb5:
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov rsi, [rbp - 224] # reload L26 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 768] # tag L26 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 776], rax # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov r10, [rbp - 232] # reload L27 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_divmod_bb7 # jump-if-zero -> else
    jmp .L7b0c_fpe_divmod_bb6 # jump -> then
.L7b0c_fpe_divmod_bb6:
    mov rsi, [rbp - 208] # reload L24 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 752] # tag L24 from tag-slot
    mov rcx, 10000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call fpe_mul_small # call fpe_mul_small
    mov [rbp - 784], rax # store tag L28
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 240], r10 # spill L28 to slot
    mov r11, [rbp - 240] # reload L28 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 784] # tag L28 from tag-slot
    mov [rbp - 752], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 560] # tag L0 from tag-slot
    mov rcx, [rbp - 224] # reload L26 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 768] # tag L26 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 792], rax # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov rsi, [rbp - 248] # reload L29 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 792] # tag L29 from tag-slot
    call fpe_from # call fpe_from
    mov [rbp - 800], rax # store tag L30
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 256], r10 # spill L30 to slot
    mov rsi, [rbp - 208] # reload L24 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 752] # tag L24 from tag-slot
    mov rcx, [rbp - 256] # reload L30 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 800] # tag L30 from tag-slot
    call fpe_add # call fpe_add
    mov [rbp - 808], rax # store tag L31
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 264], r10 # spill L31 to slot
    mov r11, [rbp - 264] # reload L31 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 808] # tag L31 from tag-slot
    mov [rbp - 752], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r10, 0 # assign L32
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 816], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r10, 9999 # assign L33
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 824], r11 # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r10, 0 # assign L34
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 832], r11 # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    jmp .L7b0c_fpe_divmod_bb8 # branch
.L7b0c_fpe_divmod_bb7:
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 984], rax # store tag L53
    mov [rbp - 440], r10 # spill L53 to slot
    mov r11, [rbp - 440] # reload L53 from spill slot
    mov r10, r11 # assign L54
    mov r11, [rbp - 984] # tag L53 from tag-slot
    mov [rbp - 992], r11 # store tag L54
    mov [rbp - 448], r10 # spill L54 to slot
    mov rsi, [rbp - 192] # reload L22 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 736] # tag L22 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1000], r11 # store tag L55
    mov [rbp - 456], r10 # spill L55 to slot
    mov r10, [rbp - 456] # reload L55 from spill slot
    mov rsi, [rbp - 456] # reload L55 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1000] # tag L55 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 1008], rax # store tag L56
    mov [rbp - 464], r10 # spill L56 to slot
    mov r11, [rbp - 464] # reload L56 from spill slot
    mov r10, r11 # assign L57
    mov r11, [rbp - 1008] # tag L56 from tag-slot
    mov [rbp - 1016], r11 # store tag L57
    mov [rbp - 472], r10 # spill L57 to slot
    jmp .L7b0c_fpe_divmod_bb16 # branch
.L7b0c_fpe_divmod_bb8:
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov r11, [rbp - 280] # reload L33 from spill slot
    mov rsi, [rbp - 272] # reload L32 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 816] # tag L32 from tag-slot
    mov rcx, [rbp - 280] # reload L33 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 824] # tag L33 from tag-slot
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 840], rax # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    mov r10, [rbp - 296] # reload L35 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_divmod_bb10 # jump-if-zero -> else
    jmp .L7b0c_fpe_divmod_bb9 # jump -> then
.L7b0c_fpe_divmod_bb9:
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov r11, [rbp - 280] # reload L33 from spill slot
    mov rsi, [rbp - 272] # reload L32 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 816] # tag L32 from tag-slot
    mov rcx, [rbp - 280] # reload L33 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 824] # tag L33 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 848], rax # store tag L36
    mov [rbp - 304], r10 # spill L36 to slot
    mov r10, [rbp - 304] # reload L36 from spill slot
    mov rsi, [rbp - 304] # reload L36 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 848] # tag L36 from tag-slot
    mov rcx, 2 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 856], rax # store tag L37
    mov [rbp - 312], r10 # spill L37 to slot
    mov r11, [rbp - 312] # reload L37 from spill slot
    mov r10, r11 # assign L38
    mov r11, [rbp - 856] # tag L37 from tag-slot
    mov [rbp - 864], r11 # store tag L38
    mov [rbp - 320], r10 # spill L38 to slot
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 568] # tag L1 from tag-slot
    mov rcx, [rbp - 320] # reload L38 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 864] # tag L38 from tag-slot
    call fpe_mul_small # call fpe_mul_small
    mov [rbp - 872], rax # store tag L39
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 328], r10 # spill L39 to slot
    mov r11, [rbp - 328] # reload L39 from spill slot
    mov r10, r11 # assign L40
    mov r11, [rbp - 872] # tag L39 from tag-slot
    mov [rbp - 880], r11 # store tag L40
    mov [rbp - 336], r10 # spill L40 to slot
    mov rsi, [rbp - 336] # reload L40 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 880] # tag L40 from tag-slot
    mov rcx, [rbp - 208] # reload L24 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 752] # tag L24 from tag-slot
    call fpe_cmp # call fpe_cmp
    mov [rbp - 888], rax # store tag L41
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 344], r10 # spill L41 to slot
    mov r11, [rbp - 344] # reload L41 from spill slot
    mov r10, r11 # assign L42
    mov r11, [rbp - 888] # tag L41 from tag-slot
    mov [rbp - 896], r11 # store tag L42
    mov [rbp - 352], r10 # spill L42 to slot
    mov r10, [rbp - 352] # reload L42 from spill slot
    mov rsi, [rbp - 352] # reload L42 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 896] # tag L42 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 904], rax # store tag L43
    mov [rbp - 360], r10 # spill L43 to slot
    mov r10, [rbp - 360] # reload L43 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_divmod_bb12 # jump-if-zero -> else
    jmp .L7b0c_fpe_divmod_bb11 # jump -> then
.L7b0c_fpe_divmod_bb10:
    mov rsi, [rbp - 192] # reload L22 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 736] # tag L22 from tag-slot
    mov rcx, [rbp - 288] # reload L34 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 832] # tag L34 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 936], rax # store tag L47
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 392], r10 # spill L47 to slot
    mov r10, [rbp - 288] # reload L34 from spill slot
    mov rsi, [rbp - 288] # reload L34 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 832] # tag L34 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 944], rax # store tag L48
    mov [rbp - 400], r10 # spill L48 to slot
    mov r10, [rbp - 400] # reload L48 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_divmod_bb15 # jump-if-zero -> else
    jmp .L7b0c_fpe_divmod_bb14 # jump -> then
.L7b0c_fpe_divmod_bb11:
    mov r11, [rbp - 320] # reload L38 from spill slot
    mov r10, r11 # assign L34
    mov r11, [rbp - 864] # tag L38 from tag-slot
    mov [rbp - 832], r11 # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    mov r10, [rbp - 320] # reload L38 from spill slot
    mov rsi, [rbp - 320] # reload L38 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 864] # tag L38 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 920], rax # store tag L45
    mov [rbp - 376], r10 # spill L45 to slot
    mov r11, [rbp - 376] # reload L45 from spill slot
    mov r10, r11 # assign L32
    mov r11, [rbp - 920] # tag L45 from tag-slot
    mov [rbp - 816], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    jmp .L7b0c_fpe_divmod_bb13 # branch
.L7b0c_fpe_divmod_bb12:
    mov r10, [rbp - 320] # reload L38 from spill slot
    mov rsi, [rbp - 320] # reload L38 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 864] # tag L38 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 928], rax # store tag L46
    mov [rbp - 384], r10 # spill L46 to slot
    mov r11, [rbp - 384] # reload L46 from spill slot
    mov r10, r11 # assign L33
    mov r11, [rbp - 928] # tag L46 from tag-slot
    mov [rbp - 824], r11 # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    jmp .L7b0c_fpe_divmod_bb13 # branch
.L7b0c_fpe_divmod_bb13:
    jmp .L7b0c_fpe_divmod_bb8 # branch
.L7b0c_fpe_divmod_bb14:
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 568] # tag L1 from tag-slot
    mov rcx, [rbp - 288] # reload L34 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 832] # tag L34 from tag-slot
    call fpe_mul_small # call fpe_mul_small
    mov [rbp - 960], rax # store tag L50
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 416], r10 # spill L50 to slot
    mov rsi, [rbp - 208] # reload L24 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 752] # tag L24 from tag-slot
    mov rcx, [rbp - 416] # reload L50 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 960] # tag L50 from tag-slot
    call fpe_sub # call fpe_sub
    mov [rbp - 968], rax # store tag L51
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 424], r10 # spill L51 to slot
    mov r11, [rbp - 424] # reload L51 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 968] # tag L51 from tag-slot
    mov [rbp - 752], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    jmp .L7b0c_fpe_divmod_bb15 # branch
.L7b0c_fpe_divmod_bb15:
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov rsi, [rbp - 224] # reload L26 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 768] # tag L26 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 976], rax # store tag L52
    mov [rbp - 432], r10 # spill L52 to slot
    mov r11, [rbp - 432] # reload L52 from spill slot
    mov r10, r11 # assign L26
    mov r11, [rbp - 976] # tag L52 from tag-slot
    mov [rbp - 768], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    jmp .L7b0c_fpe_divmod_bb5 # branch
.L7b0c_fpe_divmod_bb16:
    mov r10, [rbp - 472] # reload L57 from spill slot
    mov rsi, [rbp - 472] # reload L57 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1016] # tag L57 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 1024], rax # store tag L58
    mov [rbp - 480], r10 # spill L58 to slot
    mov r10, [rbp - 480] # reload L58 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_divmod_bb18 # jump-if-zero -> else
    jmp .L7b0c_fpe_divmod_bb17 # jump -> then
.L7b0c_fpe_divmod_bb17:
    mov rsi, [rbp - 192] # reload L22 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 736] # tag L22 from tag-slot
    mov rcx, [rbp - 472] # reload L57 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 1016] # tag L57 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 1032], rax # store tag L59
    mov [rbp - 488], r10 # spill L59 to slot
    mov rsi, [rbp - 448] # reload L54 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 992] # tag L54 from tag-slot
    mov rcx, [rbp - 488] # reload L59 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 1032] # tag L59 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 1040], rax # store tag L60
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 496], r10 # spill L60 to slot
    mov r10, [rbp - 472] # reload L57 from spill slot
    mov rsi, [rbp - 472] # reload L57 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1016] # tag L57 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 1048], rax # store tag L61
    mov [rbp - 504], r10 # spill L61 to slot
    mov r11, [rbp - 504] # reload L61 from spill slot
    mov r10, r11 # assign L57
    mov r11, [rbp - 1048] # tag L61 from tag-slot
    mov [rbp - 1016], r11 # store tag L57
    mov [rbp - 472], r10 # spill L57 to slot
    jmp .L7b0c_fpe_divmod_bb16 # branch
.L7b0c_fpe_divmod_bb18:
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 1056], rax # store tag L62
    mov [rbp - 512], r10 # spill L62 to slot
    mov r11, [rbp - 512] # reload L62 from spill slot
    mov r10, r11 # assign L63
    mov r11, [rbp - 1056] # tag L62 from tag-slot
    mov [rbp - 1064], r11 # store tag L63
    mov [rbp - 520], r10 # spill L63 to slot
    mov rsi, [rbp - 448] # reload L54 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 992] # tag L54 from tag-slot
    call fpe_norm # call fpe_norm
    mov [rbp - 1072], rax # store tag L64
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 528], r10 # spill L64 to slot
    mov rsi, [rbp - 520] # reload L63 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1064] # tag L63 from tag-slot
    mov rcx, [rbp - 528] # reload L64 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 1072] # tag L64 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 1080], rax # store tag L65
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 536], r10 # spill L65 to slot
    mov rsi, [rbp - 208] # reload L24 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 752] # tag L24 from tag-slot
    call fpe_norm # call fpe_norm
    mov [rbp - 1088], rax # store tag L66
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 544], r10 # spill L66 to slot
    mov rsi, [rbp - 520] # reload L63 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1064] # tag L63 from tag-slot
    mov rcx, [rbp - 544] # reload L66 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 1088] # tag L66 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 1096], rax # store tag L67
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 552], r10 # spill L67 to slot
    mov rdx, [rbp - 520] # reload L63 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 1064] # tag L63 from tag-slot
    add rsp, 1056 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl fpe_to_i64
.hidden fpe_to_i64
    .p2align 4
fpe_to_i64:
    .loc 1 320 0
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
.L7b0c_fpe_to_i64_bb0:
    mov r12, 0 # assign L1
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 104], r11 # store tag L1
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 96] # tag L0 from tag-slot
    call hexa_len # call hexa_len
    mov r13, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 112], r11 # store tag L2
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 112] # tag L2 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r14, rdx # binop -: capture result payload
    mov [rbp - 120], rax # store tag L3
    mov r15, r14 # assign L4
    mov r11, [rbp - 120] # tag L3 from tag-slot
    mov [rbp - 128], r11 # store tag L4
    jmp .L7b0c_fpe_to_i64_bb1 # branch
.L7b0c_fpe_to_i64_bb1:
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 128] # tag L4 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 136], rax # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_to_i64_bb3 # jump-if-zero -> else
    jmp .L7b0c_fpe_to_i64_bb2 # jump -> then
.L7b0c_fpe_to_i64_bb2:
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 104] # tag L1 from tag-slot
    mov rcx, 10000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 144], rax # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 96] # tag L0 from tag-slot
    mov rcx, r15 # hv arg payload
    mov rdx, [rbp - 128] # tag L4 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 152], rax # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 144] # tag L6 from tag-slot
    mov rcx, [rbp - 72] # reload L7 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 152] # tag L7 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 160], rax # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov r12, r10 # assign L1
    mov r11, [rbp - 160] # tag L8 from tag-slot
    mov [rbp - 104], r11 # store tag L1
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 128] # tag L4 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 168], rax # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov r15, r10 # assign L4
    mov r11, [rbp - 168] # tag L9 from tag-slot
    mov [rbp - 128], r11 # store tag L4
    jmp .L7b0c_fpe_to_i64_bb1 # branch
.L7b0c_fpe_to_i64_bb3:
    mov rdx, r12 # hv arg payload
    mov rax, [rbp - 104] # tag L1 from tag-slot
    add rsp, 128 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl fpe_assemble
.hidden fpe_assemble
    .p2align 4
fpe_assemble:
    .loc 1 332 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 160 # prologue: alloc spill frame
    mov [rbp - 112], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 120], rdx # store tag L1
    mov r12, rcx # ingress param payload
    mov [rbp - 128], r8 # store tag L2
    mov r13, r9 # ingress param payload
.L7b0c_fpe_assemble_bb0:
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 120] # tag L1 from tag-slot
    mov rcx, 4503599627370496 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r14, rdx # binop *: capture result payload
    mov [rbp - 136], rax # store tag L3
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 128] # tag L2 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 136] # tag L3 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r15, rdx # binop +: capture result payload
    mov [rbp - 144], rax # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 144] # tag L4 from tag-slot
    mov [rbp - 152], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 112] # tag L0 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 160], rax # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_fpe_assemble_bb2 # jump-if-zero -> else
    jmp .L7b0c_fpe_assemble_bb1 # jump -> then
.L7b0c_fpe_assemble_bb1:
    mov rsi, 0 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    mov rcx, 9223372036854775807 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 176], rax # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 176] # tag L8 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 184], rax # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 152] # tag L5 from tag-slot
    mov rcx, [rbp - 88] # reload L9 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 184] # tag L9 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 192], rax # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L5
    mov r11, [rbp - 192] # tag L10 from tag-slot
    mov [rbp - 152], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    jmp .L7b0c_fpe_assemble_bb2 # branch
.L7b0c_fpe_assemble_bb2:
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 152] # tag L5 from tag-slot
    call hexa_bits_to_float # call hexa_bits_to_float
    mov [rbp - 200], rax # store tag L11
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 104], r10 # spill L11 to slot
    mov rdx, [rbp - 104] # reload L11 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 200] # tag L11 from tag-slot
    add rsp, 160 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_parse_float_exact
.hidden rt_str_parse_float_exact
    .p2align 4
rt_str_parse_float_exact:
    .loc 1 342 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 3664 # prologue: alloc spill frame
    mov [rbp - 1864], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.L7b0c_rt_str_parse_float_exact_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 1864] # tag L0 from tag-slot
    call hexa_byte_len # call hexa_byte_len
    mov [rbp - 1872], rax # store tag L1
    mov r12, rdx # hv: unbox call result (rdx)
    mov r13, r12 # assign L2
    mov r11, [rbp - 1872] # tag L1 from tag-slot
    mov [rbp - 1880], r11 # store tag L2
    mov r14, 0 # assign L3
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1888], r11 # store tag L3
    jmp .L7b0c_rt_str_parse_float_exact_bb1 # branch
.L7b0c_rt_str_parse_float_exact_bb1:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 1888] # tag L3 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 1880] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r15, rdx # binop <: capture bool payload
    mov [rbp - 1896], rax # store tag L4
    test r15, r15 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb3 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb2 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb2:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 1864] # tag L0 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 1888] # tag L3 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 1904], rax # store tag L5
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 1904] # tag L5 from tag-slot
    mov [rbp - 1912], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1912] # tag L6 from tag-slot
    mov rcx, 32 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 1920], rax # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb5 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb4 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb3:
    mov r10, 0 # assign L16
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1992], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 1888] # tag L3 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 1880] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 2000], rax # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb17 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb16 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb4:
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 1920] # tag L7 from tag-slot
    mov [rbp - 1928], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb6 # branch
.L7b0c_rt_str_parse_float_exact_bb5:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1912] # tag L6 from tag-slot
    mov rcx, 9 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 1936], rax # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 1936] # tag L9 from tag-slot
    mov [rbp - 1928], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb6 # branch
.L7b0c_rt_str_parse_float_exact_bb6:
    mov r10, [rbp - 80] # reload L8 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb8 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb7 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb7:
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L10
    mov r11, [rbp - 1928] # tag L8 from tag-slot
    mov [rbp - 1944], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb9 # branch
.L7b0c_rt_str_parse_float_exact_bb8:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1912] # tag L6 from tag-slot
    mov rcx, 10 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 1952], rax # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L10
    mov r11, [rbp - 1952] # tag L11 from tag-slot
    mov [rbp - 1944], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb9 # branch
.L7b0c_rt_str_parse_float_exact_bb9:
    mov r10, [rbp - 96] # reload L10 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb11 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb10 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb10:
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 1944] # tag L10 from tag-slot
    mov [rbp - 1960], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb12 # branch
.L7b0c_rt_str_parse_float_exact_bb11:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1912] # tag L6 from tag-slot
    mov rcx, 13 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 1968], rax # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 1968] # tag L13 from tag-slot
    mov [rbp - 1960], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb12 # branch
.L7b0c_rt_str_parse_float_exact_bb12:
    mov r10, [rbp - 112] # reload L12 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb14 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb13 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb13:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 1888] # tag L3 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 1984], rax # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 1984] # tag L15 from tag-slot
    mov [rbp - 1888], r11 # store tag L3
    jmp .L7b0c_rt_str_parse_float_exact_bb15 # branch
.L7b0c_rt_str_parse_float_exact_bb14:
    jmp .L7b0c_rt_str_parse_float_exact_bb3 # branch
.L7b0c_rt_str_parse_float_exact_bb15:
    jmp .L7b0c_rt_str_parse_float_exact_bb1 # branch
.L7b0c_rt_str_parse_float_exact_bb16:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 1864] # tag L0 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 1888] # tag L3 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 2016], rax # store tag L19
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 168], r10 # spill L19 to slot
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov r10, r11 # assign L20
    mov r11, [rbp - 2016] # tag L19 from tag-slot
    mov [rbp - 2024], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, [rbp - 176] # reload L20 from spill slot
    mov rsi, [rbp - 176] # reload L20 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2024] # tag L20 from tag-slot
    mov rcx, 45 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 2032], rax # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r10, [rbp - 184] # reload L21 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb19 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb18 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb17:
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 2080], rax # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov r11, [rbp - 232] # reload L27 from spill slot
    mov r10, r11 # assign L28
    mov r11, [rbp - 2080] # tag L27 from tag-slot
    mov [rbp - 2088], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r10, 0 # assign L29
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2096], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r10, 0 # assign L30
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2104], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r10, 0 # assign L31
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2112], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov r10, 1 # assign L32
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2120], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb23 # branch
.L7b0c_rt_str_parse_float_exact_bb18:
    mov r10, 1 # assign L16
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1992], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 1888] # tag L3 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 2048], rax # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r10, [rbp - 200] # reload L23 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 2048] # tag L23 from tag-slot
    mov [rbp - 1888], r11 # store tag L3
    jmp .L7b0c_rt_str_parse_float_exact_bb22 # branch
.L7b0c_rt_str_parse_float_exact_bb19:
    mov r10, [rbp - 176] # reload L20 from spill slot
    mov rsi, [rbp - 176] # reload L20 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2024] # tag L20 from tag-slot
    mov rcx, 43 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 2056], rax # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r10, [rbp - 208] # reload L24 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb21 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb20 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb20:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 1888] # tag L3 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 2072], rax # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 2072] # tag L26 from tag-slot
    mov [rbp - 1888], r11 # store tag L3
    jmp .L7b0c_rt_str_parse_float_exact_bb21 # branch
.L7b0c_rt_str_parse_float_exact_bb21:
    jmp .L7b0c_rt_str_parse_float_exact_bb22 # branch
.L7b0c_rt_str_parse_float_exact_bb22:
    jmp .L7b0c_rt_str_parse_float_exact_bb17 # branch
.L7b0c_rt_str_parse_float_exact_bb23:
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov rsi, [rbp - 272] # reload L32 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2120] # tag L32 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 2128], rax # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r10, [rbp - 280] # reload L33 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb27 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb26 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb24:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 1864] # tag L0 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 1888] # tag L3 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 2152], rax # store tag L36
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 304], r10 # spill L36 to slot
    mov r11, [rbp - 304] # reload L36 from spill slot
    mov r10, r11 # assign L37
    mov r11, [rbp - 2152] # tag L36 from tag-slot
    mov [rbp - 2160], r11 # store tag L37
    mov [rbp - 312], r10 # spill L37 to slot
    mov r10, [rbp - 312] # reload L37 from spill slot
    mov rsi, [rbp - 312] # reload L37 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2160] # tag L37 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 2168], rax # store tag L38
    mov [rbp - 320], r10 # spill L38 to slot
    mov r10, [rbp - 320] # reload L38 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb30 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb29 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb25:
    mov r10, [rbp - 256] # reload L30 from spill slot
    mov rsi, [rbp - 256] # reload L30 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2104] # tag L30 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 2312], rax # store tag L56
    mov [rbp - 464], r10 # spill L56 to slot
    mov r10, [rbp - 464] # reload L56 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb44 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb43 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb26:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 1888] # tag L3 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 1880] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 2144], rax # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    mov r11, [rbp - 296] # reload L35 from spill slot
    mov r10, r11 # assign L34
    mov r11, [rbp - 2144] # tag L35 from tag-slot
    mov [rbp - 2136], r11 # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb28 # branch
.L7b0c_rt_str_parse_float_exact_bb27:
    mov r11, [rbp - 280] # reload L33 from spill slot
    mov r10, r11 # assign L34
    mov r11, [rbp - 2128] # tag L33 from tag-slot
    mov [rbp - 2136], r11 # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb28 # branch
.L7b0c_rt_str_parse_float_exact_bb28:
    mov r10, [rbp - 288] # reload L34 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb25 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb24 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb29:
    mov r10, [rbp - 312] # reload L37 from spill slot
    mov rsi, [rbp - 312] # reload L37 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2160] # tag L37 from tag-slot
    mov rcx, 57 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 2184], rax # store tag L40
    mov [rbp - 336], r10 # spill L40 to slot
    mov r11, [rbp - 336] # reload L40 from spill slot
    mov r10, r11 # assign L39
    mov r11, [rbp - 2184] # tag L40 from tag-slot
    mov [rbp - 2176], r11 # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb31 # branch
.L7b0c_rt_str_parse_float_exact_bb30:
    mov r11, [rbp - 320] # reload L38 from spill slot
    mov r10, r11 # assign L39
    mov r11, [rbp - 2168] # tag L38 from tag-slot
    mov [rbp - 2176], r11 # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb31 # branch
.L7b0c_rt_str_parse_float_exact_bb31:
    mov r10, [rbp - 328] # reload L39 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb33 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb32 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb32:
    mov rsi, [rbp - 240] # reload L28 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2088] # tag L28 from tag-slot
    mov rcx, 10 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call fpe_mul_small # call fpe_mul_small
    mov [rbp - 2200], rax # store tag L42
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 352], r10 # spill L42 to slot
    mov r10, [rbp - 312] # reload L37 from spill slot
    mov rsi, [rbp - 312] # reload L37 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2160] # tag L37 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 2208], rax # store tag L43
    mov [rbp - 360], r10 # spill L43 to slot
    mov rsi, [rbp - 360] # reload L43 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2208] # tag L43 from tag-slot
    call fpe_from # call fpe_from
    mov [rbp - 2216], rax # store tag L44
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 368], r10 # spill L44 to slot
    mov rsi, [rbp - 352] # reload L42 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2200] # tag L42 from tag-slot
    mov rcx, [rbp - 368] # reload L44 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 2216] # tag L44 from tag-slot
    call fpe_add # call fpe_add
    mov [rbp - 2224], rax # store tag L45
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 376], r10 # spill L45 to slot
    mov r11, [rbp - 376] # reload L45 from spill slot
    mov r10, r11 # assign L28
    mov r11, [rbp - 2224] # tag L45 from tag-slot
    mov [rbp - 2088], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r10, [rbp - 256] # reload L30 from spill slot
    mov rsi, [rbp - 256] # reload L30 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2104] # tag L30 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 2232], rax # store tag L46
    mov [rbp - 384], r10 # spill L46 to slot
    mov r11, [rbp - 384] # reload L46 from spill slot
    mov r10, r11 # assign L30
    mov r11, [rbp - 2232] # tag L46 from tag-slot
    mov [rbp - 2104], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r10, [rbp - 264] # reload L31 from spill slot
    mov rsi, [rbp - 264] # reload L31 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2112] # tag L31 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 2240], rax # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    mov r10, [rbp - 392] # reload L47 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb35 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb34 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb33:
    mov r10, [rbp - 312] # reload L37 from spill slot
    mov rsi, [rbp - 312] # reload L37 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2160] # tag L37 from tag-slot
    mov rcx, 46 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 2272], rax # store tag L51
    mov [rbp - 424], r10 # spill L51 to slot
    mov r10, [rbp - 424] # reload L51 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb37 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb36 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb34:
    mov r10, [rbp - 248] # reload L29 from spill slot
    mov rsi, [rbp - 248] # reload L29 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2096] # tag L29 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 2256], rax # store tag L49
    mov [rbp - 408], r10 # spill L49 to slot
    mov r11, [rbp - 408] # reload L49 from spill slot
    mov r10, r11 # assign L29
    mov r11, [rbp - 2256] # tag L49 from tag-slot
    mov [rbp - 2096], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb35 # branch
.L7b0c_rt_str_parse_float_exact_bb35:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 1888] # tag L3 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 2264], rax # store tag L50
    mov [rbp - 416], r10 # spill L50 to slot
    mov r10, [rbp - 416] # reload L50 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 2264] # tag L50 from tag-slot
    mov [rbp - 1888], r11 # store tag L3
    jmp .L7b0c_rt_str_parse_float_exact_bb42 # branch
.L7b0c_rt_str_parse_float_exact_bb36:
    mov r10, [rbp - 264] # reload L31 from spill slot
    mov rsi, [rbp - 264] # reload L31 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2112] # tag L31 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 2288], rax # store tag L53
    mov [rbp - 440], r10 # spill L53 to slot
    mov r10, [rbp - 440] # reload L53 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb39 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb38 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb37:
    mov r10, 0 # assign L32
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2120], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb41 # branch
.L7b0c_rt_str_parse_float_exact_bb38:
    mov r10, 0 # assign L32
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2120], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb40 # branch
.L7b0c_rt_str_parse_float_exact_bb39:
    mov r10, 1 # assign L31
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2112], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 1888] # tag L3 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 2304], rax # store tag L55
    mov [rbp - 456], r10 # spill L55 to slot
    mov r10, [rbp - 456] # reload L55 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 2304] # tag L55 from tag-slot
    mov [rbp - 1888], r11 # store tag L3
    jmp .L7b0c_rt_str_parse_float_exact_bb40 # branch
.L7b0c_rt_str_parse_float_exact_bb40:
    jmp .L7b0c_rt_str_parse_float_exact_bb41 # branch
.L7b0c_rt_str_parse_float_exact_bb41:
    jmp .L7b0c_rt_str_parse_float_exact_bb42 # branch
.L7b0c_rt_str_parse_float_exact_bb42:
    jmp .L7b0c_rt_str_parse_float_exact_bb23 # branch
.L7b0c_rt_str_parse_float_exact_bb43:
    mov r10, 0 # hv payload
    mov r11, 4 # hv payload
    mov [rbp - 2328], r11 # store tag L58
    mov [rbp - 480], r10 # spill L58 to slot
    mov rdx, [rbp - 480] # reload L58 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 2328] # tag L58 from tag-slot
    add rsp, 3664 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_rt_str_parse_float_exact_bb44:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 1888] # tag L3 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 1880] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 2336], rax # store tag L59
    mov [rbp - 488], r10 # spill L59 to slot
    mov r10, [rbp - 488] # reload L59 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb46 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb45 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb45:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 1864] # tag L0 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 1888] # tag L3 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 2352], rax # store tag L61
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 504], r10 # spill L61 to slot
    mov r11, [rbp - 504] # reload L61 from spill slot
    mov r10, r11 # assign L62
    mov r11, [rbp - 2352] # tag L61 from tag-slot
    mov [rbp - 2360], r11 # store tag L62
    mov [rbp - 512], r10 # spill L62 to slot
    mov r10, [rbp - 512] # reload L62 from spill slot
    mov rsi, [rbp - 512] # reload L62 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2360] # tag L62 from tag-slot
    mov rcx, 101 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 2368], rax # store tag L63
    mov [rbp - 520], r10 # spill L63 to slot
    mov r10, [rbp - 520] # reload L63 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb48 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb47 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb46:
    jmp .L7b0c_rt_str_parse_float_exact_bb72 # branch
.L7b0c_rt_str_parse_float_exact_bb47:
    mov r11, [rbp - 520] # reload L63 from spill slot
    mov r10, r11 # assign L64
    mov r11, [rbp - 2368] # tag L63 from tag-slot
    mov [rbp - 2376], r11 # store tag L64
    mov [rbp - 528], r10 # spill L64 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb49 # branch
.L7b0c_rt_str_parse_float_exact_bb48:
    mov r10, [rbp - 512] # reload L62 from spill slot
    mov rsi, [rbp - 512] # reload L62 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2360] # tag L62 from tag-slot
    mov rcx, 69 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 2384], rax # store tag L65
    mov [rbp - 536], r10 # spill L65 to slot
    mov r11, [rbp - 536] # reload L65 from spill slot
    mov r10, r11 # assign L64
    mov r11, [rbp - 2384] # tag L65 from tag-slot
    mov [rbp - 2376], r11 # store tag L64
    mov [rbp - 528], r10 # spill L64 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb49 # branch
.L7b0c_rt_str_parse_float_exact_bb49:
    mov r10, [rbp - 528] # reload L64 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb51 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb50 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb50:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 1888] # tag L3 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 2400], rax # store tag L67
    mov [rbp - 552], r10 # spill L67 to slot
    mov r10, [rbp - 552] # reload L67 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 2400] # tag L67 from tag-slot
    mov [rbp - 1888], r11 # store tag L3
    mov r10, 1 # assign L68
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2408], r11 # store tag L68
    mov [rbp - 560], r10 # spill L68 to slot
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 1888] # tag L3 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 1880] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 2416], rax # store tag L69
    mov [rbp - 568], r10 # spill L69 to slot
    mov r10, [rbp - 568] # reload L69 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb53 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb52 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb51:
    jmp .L7b0c_rt_str_parse_float_exact_bb46 # branch
.L7b0c_rt_str_parse_float_exact_bb52:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 1864] # tag L0 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 1888] # tag L3 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 2432], rax # store tag L71
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 584], r10 # spill L71 to slot
    mov r11, [rbp - 584] # reload L71 from spill slot
    mov r10, r11 # assign L72
    mov r11, [rbp - 2432] # tag L71 from tag-slot
    mov [rbp - 2440], r11 # store tag L72
    mov [rbp - 592], r10 # spill L72 to slot
    mov r10, [rbp - 592] # reload L72 from spill slot
    mov rsi, [rbp - 592] # reload L72 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2440] # tag L72 from tag-slot
    mov rcx, 45 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 2448], rax # store tag L73
    mov [rbp - 600], r10 # spill L73 to slot
    mov r10, [rbp - 600] # reload L73 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb55 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb54 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb53:
    mov r10, 0 # assign L80
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2504], r11 # store tag L80
    mov [rbp - 656], r10 # spill L80 to slot
    mov r10, 0 # assign L81
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2512], r11 # store tag L81
    mov [rbp - 664], r10 # spill L81 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb59 # branch
.L7b0c_rt_str_parse_float_exact_bb54:
    mov rsi, 0 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 2464], rax # store tag L75
    mov [rbp - 616], r10 # spill L75 to slot
    mov r11, [rbp - 616] # reload L75 from spill slot
    mov r10, r11 # assign L68
    mov r11, [rbp - 2464] # tag L75 from tag-slot
    mov [rbp - 2408], r11 # store tag L68
    mov [rbp - 560], r10 # spill L68 to slot
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 1888] # tag L3 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 2472], rax # store tag L76
    mov [rbp - 624], r10 # spill L76 to slot
    mov r10, [rbp - 624] # reload L76 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 2472] # tag L76 from tag-slot
    mov [rbp - 1888], r11 # store tag L3
    jmp .L7b0c_rt_str_parse_float_exact_bb58 # branch
.L7b0c_rt_str_parse_float_exact_bb55:
    mov r10, [rbp - 592] # reload L72 from spill slot
    mov rsi, [rbp - 592] # reload L72 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2440] # tag L72 from tag-slot
    mov rcx, 43 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 2480], rax # store tag L77
    mov [rbp - 632], r10 # spill L77 to slot
    mov r10, [rbp - 632] # reload L77 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb57 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb56 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb56:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 1888] # tag L3 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 2496], rax # store tag L79
    mov [rbp - 648], r10 # spill L79 to slot
    mov r10, [rbp - 648] # reload L79 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 2496] # tag L79 from tag-slot
    mov [rbp - 1888], r11 # store tag L3
    jmp .L7b0c_rt_str_parse_float_exact_bb57 # branch
.L7b0c_rt_str_parse_float_exact_bb57:
    jmp .L7b0c_rt_str_parse_float_exact_bb58 # branch
.L7b0c_rt_str_parse_float_exact_bb58:
    jmp .L7b0c_rt_str_parse_float_exact_bb53 # branch
.L7b0c_rt_str_parse_float_exact_bb59:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 1888] # tag L3 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 1880] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 2520], rax # store tag L82
    mov [rbp - 672], r10 # spill L82 to slot
    mov r10, [rbp - 672] # reload L82 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb61 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb60 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb60:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 1864] # tag L0 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 1888] # tag L3 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 2528], rax # store tag L83
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 680], r10 # spill L83 to slot
    mov r11, [rbp - 680] # reload L83 from spill slot
    mov r10, r11 # assign L84
    mov r11, [rbp - 2528] # tag L83 from tag-slot
    mov [rbp - 2536], r11 # store tag L84
    mov [rbp - 688], r10 # spill L84 to slot
    mov r10, [rbp - 688] # reload L84 from spill slot
    mov rsi, [rbp - 688] # reload L84 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2536] # tag L84 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 2544], rax # store tag L85
    mov [rbp - 696], r10 # spill L85 to slot
    mov r10, [rbp - 696] # reload L85 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb63 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb62 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb61:
    mov r10, [rbp - 664] # reload L81 from spill slot
    mov rsi, [rbp - 664] # reload L81 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2512] # tag L81 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 2624], rax # store tag L95
    mov [rbp - 776], r10 # spill L95 to slot
    mov r10, [rbp - 776] # reload L95 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb71 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb70 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb62:
    mov r10, [rbp - 688] # reload L84 from spill slot
    mov rsi, [rbp - 688] # reload L84 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2536] # tag L84 from tag-slot
    mov rcx, 57 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 2560], rax # store tag L87
    mov [rbp - 712], r10 # spill L87 to slot
    mov r11, [rbp - 712] # reload L87 from spill slot
    mov r10, r11 # assign L86
    mov r11, [rbp - 2560] # tag L87 from tag-slot
    mov [rbp - 2552], r11 # store tag L86
    mov [rbp - 704], r10 # spill L86 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb64 # branch
.L7b0c_rt_str_parse_float_exact_bb63:
    mov r11, [rbp - 696] # reload L85 from spill slot
    mov r10, r11 # assign L86
    mov r11, [rbp - 2544] # tag L85 from tag-slot
    mov [rbp - 2552], r11 # store tag L86
    mov [rbp - 704], r10 # spill L86 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb64 # branch
.L7b0c_rt_str_parse_float_exact_bb64:
    mov r10, [rbp - 704] # reload L86 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb66 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb65 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb65:
    mov r10, [rbp - 656] # reload L80 from spill slot
    mov rsi, [rbp - 656] # reload L80 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2504] # tag L80 from tag-slot
    mov rcx, 10 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 2576], rax # store tag L89
    mov [rbp - 728], r10 # spill L89 to slot
    mov r10, [rbp - 688] # reload L84 from spill slot
    mov rsi, [rbp - 688] # reload L84 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2536] # tag L84 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 2584], rax # store tag L90
    mov [rbp - 736], r10 # spill L90 to slot
    mov r10, [rbp - 728] # reload L89 from spill slot
    mov r11, [rbp - 736] # reload L90 from spill slot
    mov rsi, [rbp - 728] # reload L89 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2576] # tag L89 from tag-slot
    mov rcx, [rbp - 736] # reload L90 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 2584] # tag L90 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 2592], rax # store tag L91
    mov [rbp - 744], r10 # spill L91 to slot
    mov r11, [rbp - 744] # reload L91 from spill slot
    mov r10, r11 # assign L80
    mov r11, [rbp - 2592] # tag L91 from tag-slot
    mov [rbp - 2504], r11 # store tag L80
    mov [rbp - 656], r10 # spill L80 to slot
    mov r10, 1 # assign L81
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2512], r11 # store tag L81
    mov [rbp - 664], r10 # spill L81 to slot
    mov r10, [rbp - 656] # reload L80 from spill slot
    mov rsi, [rbp - 656] # reload L80 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2504] # tag L80 from tag-slot
    mov rcx, 100000 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 2600], rax # store tag L92
    mov [rbp - 752], r10 # spill L92 to slot
    mov r10, [rbp - 752] # reload L92 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb68 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb67 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb66:
    jmp .L7b0c_rt_str_parse_float_exact_bb61 # branch
.L7b0c_rt_str_parse_float_exact_bb67:
    mov r10, 100000 # assign L80
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2504], r11 # store tag L80
    mov [rbp - 656], r10 # spill L80 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb68 # branch
.L7b0c_rt_str_parse_float_exact_bb68:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 1888] # tag L3 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 2616], rax # store tag L94
    mov [rbp - 768], r10 # spill L94 to slot
    mov r10, [rbp - 768] # reload L94 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 2616] # tag L94 from tag-slot
    mov [rbp - 1888], r11 # store tag L3
    jmp .L7b0c_rt_str_parse_float_exact_bb69 # branch
.L7b0c_rt_str_parse_float_exact_bb69:
    jmp .L7b0c_rt_str_parse_float_exact_bb59 # branch
.L7b0c_rt_str_parse_float_exact_bb70:
    mov r10, 0 # hv payload
    mov r11, 4 # hv payload
    mov [rbp - 2640], r11 # store tag L97
    mov [rbp - 792], r10 # spill L97 to slot
    mov rdx, [rbp - 792] # reload L97 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 2640] # tag L97 from tag-slot
    add rsp, 3664 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_rt_str_parse_float_exact_bb71:
    mov r10, [rbp - 560] # reload L68 from spill slot
    mov r11, [rbp - 656] # reload L80 from spill slot
    mov rsi, [rbp - 560] # reload L68 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2408] # tag L68 from tag-slot
    mov rcx, [rbp - 656] # reload L80 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 2504] # tag L80 from tag-slot
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 2648], rax # store tag L98
    mov [rbp - 800], r10 # spill L98 to slot
    mov r10, [rbp - 248] # reload L29 from spill slot
    mov r11, [rbp - 800] # reload L98 from spill slot
    mov rsi, [rbp - 248] # reload L29 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2096] # tag L29 from tag-slot
    mov rcx, [rbp - 800] # reload L98 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 2648] # tag L98 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 2656], rax # store tag L99
    mov [rbp - 808], r10 # spill L99 to slot
    mov r11, [rbp - 808] # reload L99 from spill slot
    mov r10, r11 # assign L29
    mov r11, [rbp - 2656] # tag L99 from tag-slot
    mov [rbp - 2096], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb51 # branch
.L7b0c_rt_str_parse_float_exact_bb72:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 1888] # tag L3 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 1880] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 2664], rax # store tag L100
    mov [rbp - 816], r10 # spill L100 to slot
    mov r10, [rbp - 816] # reload L100 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb74 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb73 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb73:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 1864] # tag L0 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 1888] # tag L3 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 2672], rax # store tag L101
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 824], r10 # spill L101 to slot
    mov r11, [rbp - 824] # reload L101 from spill slot
    mov r10, r11 # assign L102
    mov r11, [rbp - 2672] # tag L101 from tag-slot
    mov [rbp - 2680], r11 # store tag L102
    mov [rbp - 832], r10 # spill L102 to slot
    mov r10, [rbp - 832] # reload L102 from spill slot
    mov rsi, [rbp - 832] # reload L102 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2680] # tag L102 from tag-slot
    mov rcx, 32 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 2688], rax # store tag L103
    mov [rbp - 840], r10 # spill L103 to slot
    mov r10, [rbp - 840] # reload L103 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb76 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb75 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb74:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 1888] # tag L3 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 1880] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 2760], rax # store tag L112
    mov [rbp - 912], r10 # spill L112 to slot
    mov r10, [rbp - 912] # reload L112 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb88 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb87 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb75:
    mov r11, [rbp - 840] # reload L103 from spill slot
    mov r10, r11 # assign L104
    mov r11, [rbp - 2688] # tag L103 from tag-slot
    mov [rbp - 2696], r11 # store tag L104
    mov [rbp - 848], r10 # spill L104 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb77 # branch
.L7b0c_rt_str_parse_float_exact_bb76:
    mov r10, [rbp - 832] # reload L102 from spill slot
    mov rsi, [rbp - 832] # reload L102 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2680] # tag L102 from tag-slot
    mov rcx, 9 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 2704], rax # store tag L105
    mov [rbp - 856], r10 # spill L105 to slot
    mov r11, [rbp - 856] # reload L105 from spill slot
    mov r10, r11 # assign L104
    mov r11, [rbp - 2704] # tag L105 from tag-slot
    mov [rbp - 2696], r11 # store tag L104
    mov [rbp - 848], r10 # spill L104 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb77 # branch
.L7b0c_rt_str_parse_float_exact_bb77:
    mov r10, [rbp - 848] # reload L104 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb79 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb78 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb78:
    mov r11, [rbp - 848] # reload L104 from spill slot
    mov r10, r11 # assign L106
    mov r11, [rbp - 2696] # tag L104 from tag-slot
    mov [rbp - 2712], r11 # store tag L106
    mov [rbp - 864], r10 # spill L106 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb80 # branch
.L7b0c_rt_str_parse_float_exact_bb79:
    mov r10, [rbp - 832] # reload L102 from spill slot
    mov rsi, [rbp - 832] # reload L102 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2680] # tag L102 from tag-slot
    mov rcx, 10 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 2720], rax # store tag L107
    mov [rbp - 872], r10 # spill L107 to slot
    mov r11, [rbp - 872] # reload L107 from spill slot
    mov r10, r11 # assign L106
    mov r11, [rbp - 2720] # tag L107 from tag-slot
    mov [rbp - 2712], r11 # store tag L106
    mov [rbp - 864], r10 # spill L106 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb80 # branch
.L7b0c_rt_str_parse_float_exact_bb80:
    mov r10, [rbp - 864] # reload L106 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb82 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb81 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb81:
    mov r11, [rbp - 864] # reload L106 from spill slot
    mov r10, r11 # assign L108
    mov r11, [rbp - 2712] # tag L106 from tag-slot
    mov [rbp - 2728], r11 # store tag L108
    mov [rbp - 880], r10 # spill L108 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb83 # branch
.L7b0c_rt_str_parse_float_exact_bb82:
    mov r10, [rbp - 832] # reload L102 from spill slot
    mov rsi, [rbp - 832] # reload L102 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2680] # tag L102 from tag-slot
    mov rcx, 13 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 2736], rax # store tag L109
    mov [rbp - 888], r10 # spill L109 to slot
    mov r11, [rbp - 888] # reload L109 from spill slot
    mov r10, r11 # assign L108
    mov r11, [rbp - 2736] # tag L109 from tag-slot
    mov [rbp - 2728], r11 # store tag L108
    mov [rbp - 880], r10 # spill L108 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb83 # branch
.L7b0c_rt_str_parse_float_exact_bb83:
    mov r10, [rbp - 880] # reload L108 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb85 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb84 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb84:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 1888] # tag L3 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 2752], rax # store tag L111
    mov [rbp - 904], r10 # spill L111 to slot
    mov r10, [rbp - 904] # reload L111 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 2752] # tag L111 from tag-slot
    mov [rbp - 1888], r11 # store tag L3
    jmp .L7b0c_rt_str_parse_float_exact_bb86 # branch
.L7b0c_rt_str_parse_float_exact_bb85:
    jmp .L7b0c_rt_str_parse_float_exact_bb74 # branch
.L7b0c_rt_str_parse_float_exact_bb86:
    jmp .L7b0c_rt_str_parse_float_exact_bb72 # branch
.L7b0c_rt_str_parse_float_exact_bb87:
    mov r10, 0 # hv payload
    mov r11, 4 # hv payload
    mov [rbp - 2776], r11 # store tag L114
    mov [rbp - 928], r10 # spill L114 to slot
    mov rdx, [rbp - 928] # reload L114 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 2776] # tag L114 from tag-slot
    add rsp, 3664 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_rt_str_parse_float_exact_bb88:
    mov rsi, [rbp - 240] # reload L28 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2088] # tag L28 from tag-slot
    call fpe_is_zero # call fpe_is_zero
    mov [rbp - 2784], rax # store tag L115
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 936], r10 # spill L115 to slot
    mov r10, [rbp - 936] # reload L115 from spill slot
    mov rsi, [rbp - 936] # reload L115 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2784] # tag L115 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 2792], rax # store tag L116
    mov [rbp - 944], r10 # spill L116 to slot
    mov r10, [rbp - 944] # reload L116 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb90 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb89 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb89:
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1992] # tag L16 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    mov r9, 0 # hv arg payload
    mov r8, 0 # tag default = TAG_INT
    call fpe_assemble # call fpe_assemble
    mov [rbp - 2808], rax # store tag L118
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 960], r10 # spill L118 to slot
    mov rdx, [rbp - 960] # reload L118 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 2808] # tag L118 from tag-slot
    add rsp, 3664 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_rt_str_parse_float_exact_bb90:
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 2816], rax # store tag L119
    mov [rbp - 968], r10 # spill L119 to slot
    mov r11, [rbp - 968] # reload L119 from spill slot
    mov r10, r11 # assign L120
    mov r11, [rbp - 2816] # tag L119 from tag-slot
    mov [rbp - 2824], r11 # store tag L120
    mov [rbp - 976], r10 # spill L120 to slot
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 2832], rax # store tag L121
    mov [rbp - 984], r10 # spill L121 to slot
    mov r11, [rbp - 984] # reload L121 from spill slot
    mov r10, r11 # assign L122
    mov r11, [rbp - 2832] # tag L121 from tag-slot
    mov [rbp - 2840], r11 # store tag L122
    mov [rbp - 992], r10 # spill L122 to slot
    mov r10, [rbp - 248] # reload L29 from spill slot
    mov rsi, [rbp - 248] # reload L29 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2096] # tag L29 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 2848], rax # store tag L123
    mov [rbp - 1000], r10 # spill L123 to slot
    mov r10, [rbp - 1000] # reload L123 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb92 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb91 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb91:
    mov rsi, [rbp - 248] # reload L29 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2096] # tag L29 from tag-slot
    call fpe_pow10 # call fpe_pow10
    mov [rbp - 2864], rax # store tag L125
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1016], r10 # spill L125 to slot
    mov rsi, [rbp - 240] # reload L28 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2088] # tag L28 from tag-slot
    mov rcx, [rbp - 1016] # reload L125 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 2864] # tag L125 from tag-slot
    call fpe_mul # call fpe_mul
    mov [rbp - 2872], rax # store tag L126
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1024], r10 # spill L126 to slot
    mov r11, [rbp - 1024] # reload L126 from spill slot
    mov r10, r11 # assign L120
    mov r11, [rbp - 2872] # tag L126 from tag-slot
    mov [rbp - 2824], r11 # store tag L120
    mov [rbp - 976], r10 # spill L120 to slot
    mov rsi, 1 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    call fpe_from # call fpe_from
    mov [rbp - 2880], rax # store tag L127
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1032], r10 # spill L127 to slot
    mov r11, [rbp - 1032] # reload L127 from spill slot
    mov r10, r11 # assign L122
    mov r11, [rbp - 2880] # tag L127 from tag-slot
    mov [rbp - 2840], r11 # store tag L122
    mov [rbp - 992], r10 # spill L122 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb93 # branch
.L7b0c_rt_str_parse_float_exact_bb92:
    mov r11, [rbp - 240] # reload L28 from spill slot
    mov r10, r11 # assign L120
    mov r11, [rbp - 2088] # tag L28 from tag-slot
    mov [rbp - 2824], r11 # store tag L120
    mov [rbp - 976], r10 # spill L120 to slot
    mov r11, [rbp - 248] # reload L29 from spill slot
    mov rsi, 0 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    mov rcx, [rbp - 248] # reload L29 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 2096] # tag L29 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 2888], rax # store tag L128
    mov [rbp - 1040], r10 # spill L128 to slot
    mov rsi, [rbp - 1040] # reload L128 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2888] # tag L128 from tag-slot
    call fpe_pow10 # call fpe_pow10
    mov [rbp - 2896], rax # store tag L129
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1048], r10 # spill L129 to slot
    mov r11, [rbp - 1048] # reload L129 from spill slot
    mov r10, r11 # assign L122
    mov r11, [rbp - 2896] # tag L129 from tag-slot
    mov [rbp - 2840], r11 # store tag L122
    mov [rbp - 992], r10 # spill L122 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb93 # branch
.L7b0c_rt_str_parse_float_exact_bb93:
    mov r10, 0 # assign L130
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2904], r11 # store tag L130
    mov [rbp - 1056], r10 # spill L130 to slot
    mov rsi, [rbp - 976] # reload L120 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2824] # tag L120 from tag-slot
    call fpe_bitlen # call fpe_bitlen
    mov [rbp - 2912], rax # store tag L131
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1064], r10 # spill L131 to slot
    mov rsi, [rbp - 992] # reload L122 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2840] # tag L122 from tag-slot
    call fpe_bitlen # call fpe_bitlen
    mov [rbp - 2920], rax # store tag L132
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1072], r10 # spill L132 to slot
    mov r10, [rbp - 1064] # reload L131 from spill slot
    mov r11, [rbp - 1072] # reload L132 from spill slot
    mov rsi, [rbp - 1064] # reload L131 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2912] # tag L131 from tag-slot
    mov rcx, [rbp - 1072] # reload L132 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 2920] # tag L132 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 2928], rax # store tag L133
    mov [rbp - 1080], r10 # spill L133 to slot
    mov r11, [rbp - 1080] # reload L133 from spill slot
    mov r10, r11 # assign L134
    mov r11, [rbp - 2928] # tag L133 from tag-slot
    mov [rbp - 2936], r11 # store tag L134
    mov [rbp - 1088], r10 # spill L134 to slot
    mov r10, [rbp - 1088] # reload L134 from spill slot
    mov rsi, [rbp - 1088] # reload L134 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2936] # tag L134 from tag-slot
    mov rcx, 53 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 2944], rax # store tag L135
    mov [rbp - 1096], r10 # spill L135 to slot
    mov r10, [rbp - 1096] # reload L135 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb95 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb94 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb94:
    mov r10, [rbp - 1088] # reload L134 from spill slot
    mov rsi, [rbp - 1088] # reload L134 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2936] # tag L134 from tag-slot
    mov rcx, 52 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 2960], rax # store tag L137
    mov [rbp - 1112], r10 # spill L137 to slot
    mov r11, [rbp - 1112] # reload L137 from spill slot
    mov r10, r11 # assign L138
    mov r11, [rbp - 2960] # tag L137 from tag-slot
    mov [rbp - 2968], r11 # store tag L138
    mov [rbp - 1120], r10 # spill L138 to slot
    mov rsi, [rbp - 992] # reload L122 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2840] # tag L122 from tag-slot
    mov rcx, [rbp - 1120] # reload L138 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 2968] # tag L138 from tag-slot
    call fpe_shl # call fpe_shl
    mov [rbp - 2976], rax # store tag L139
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1128], r10 # spill L139 to slot
    mov r11, [rbp - 1128] # reload L139 from spill slot
    mov r10, r11 # assign L122
    mov r11, [rbp - 2976] # tag L139 from tag-slot
    mov [rbp - 2840], r11 # store tag L122
    mov [rbp - 992], r10 # spill L122 to slot
    mov r10, [rbp - 1056] # reload L130 from spill slot
    mov r11, [rbp - 1120] # reload L138 from spill slot
    mov rsi, [rbp - 1056] # reload L130 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2904] # tag L130 from tag-slot
    mov rcx, [rbp - 1120] # reload L138 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 2968] # tag L138 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 2984], rax # store tag L140
    mov [rbp - 1136], r10 # spill L140 to slot
    mov r11, [rbp - 1136] # reload L140 from spill slot
    mov r10, r11 # assign L130
    mov r11, [rbp - 2984] # tag L140 from tag-slot
    mov [rbp - 2904], r11 # store tag L130
    mov [rbp - 1056], r10 # spill L130 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb98 # branch
.L7b0c_rt_str_parse_float_exact_bb95:
    mov r11, [rbp - 1088] # reload L134 from spill slot
    mov rsi, 52 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    mov rcx, [rbp - 1088] # reload L134 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 2936] # tag L134 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 2992], rax # store tag L141
    mov [rbp - 1144], r10 # spill L141 to slot
    mov r11, [rbp - 1144] # reload L141 from spill slot
    mov r10, r11 # assign L142
    mov r11, [rbp - 2992] # tag L141 from tag-slot
    mov [rbp - 3000], r11 # store tag L142
    mov [rbp - 1152], r10 # spill L142 to slot
    mov r10, [rbp - 1152] # reload L142 from spill slot
    mov rsi, [rbp - 1152] # reload L142 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3000] # tag L142 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 3008], rax # store tag L143
    mov [rbp - 1160], r10 # spill L143 to slot
    mov r10, [rbp - 1160] # reload L143 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb97 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb96 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb96:
    mov r10, 0 # assign L142
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 3000], r11 # store tag L142
    mov [rbp - 1152], r10 # spill L142 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb97 # branch
.L7b0c_rt_str_parse_float_exact_bb97:
    mov rsi, [rbp - 976] # reload L120 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2824] # tag L120 from tag-slot
    mov rcx, [rbp - 1152] # reload L142 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 3000] # tag L142 from tag-slot
    call fpe_shl # call fpe_shl
    mov [rbp - 3024], rax # store tag L145
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1176], r10 # spill L145 to slot
    mov r11, [rbp - 1176] # reload L145 from spill slot
    mov r10, r11 # assign L120
    mov r11, [rbp - 3024] # tag L145 from tag-slot
    mov [rbp - 2824], r11 # store tag L120
    mov [rbp - 976], r10 # spill L120 to slot
    mov r10, [rbp - 1056] # reload L130 from spill slot
    mov r11, [rbp - 1152] # reload L142 from spill slot
    mov rsi, [rbp - 1056] # reload L130 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2904] # tag L130 from tag-slot
    mov rcx, [rbp - 1152] # reload L142 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 3000] # tag L142 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 3032], rax # store tag L146
    mov [rbp - 1184], r10 # spill L146 to slot
    mov r11, [rbp - 1184] # reload L146 from spill slot
    mov r10, r11 # assign L130
    mov r11, [rbp - 3032] # tag L146 from tag-slot
    mov [rbp - 2904], r11 # store tag L130
    mov [rbp - 1056], r10 # spill L130 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb98 # branch
.L7b0c_rt_str_parse_float_exact_bb98:
    mov rsi, 52 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    call fpe_pow2 # call fpe_pow2
    mov [rbp - 3040], rax # store tag L147
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1192], r10 # spill L147 to slot
    mov r11, [rbp - 1192] # reload L147 from spill slot
    mov r10, r11 # assign L148
    mov r11, [rbp - 3040] # tag L147 from tag-slot
    mov [rbp - 3048], r11 # store tag L148
    mov [rbp - 1200], r10 # spill L148 to slot
    mov rsi, 53 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    call fpe_pow2 # call fpe_pow2
    mov [rbp - 3056], rax # store tag L149
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1208], r10 # spill L149 to slot
    mov r11, [rbp - 1208] # reload L149 from spill slot
    mov r10, r11 # assign L150
    mov r11, [rbp - 3056] # tag L149 from tag-slot
    mov [rbp - 3064], r11 # store tag L150
    mov [rbp - 1216], r10 # spill L150 to slot
    mov r10, 0 # assign L151
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 3072], r11 # store tag L151
    mov [rbp - 1224], r10 # spill L151 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb99 # branch
.L7b0c_rt_str_parse_float_exact_bb99:
    mov r10, [rbp - 1224] # reload L151 from spill slot
    mov rsi, [rbp - 1224] # reload L151 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3072] # tag L151 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 3080], rax # store tag L152
    mov [rbp - 1232], r10 # spill L152 to slot
    mov r10, [rbp - 1232] # reload L152 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb101 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb100 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb100:
    mov rsi, [rbp - 992] # reload L122 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2840] # tag L122 from tag-slot
    mov rcx, [rbp - 1200] # reload L148 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 3048] # tag L148 from tag-slot
    call fpe_mul # call fpe_mul
    mov [rbp - 3088], rax # store tag L153
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1240], r10 # spill L153 to slot
    mov r11, [rbp - 1240] # reload L153 from spill slot
    mov r10, r11 # assign L154
    mov r11, [rbp - 3088] # tag L153 from tag-slot
    mov [rbp - 3096], r11 # store tag L154
    mov [rbp - 1248], r10 # spill L154 to slot
    mov rsi, [rbp - 992] # reload L122 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2840] # tag L122 from tag-slot
    mov rcx, [rbp - 1216] # reload L150 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 3064] # tag L150 from tag-slot
    call fpe_mul # call fpe_mul
    mov [rbp - 3104], rax # store tag L155
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1256], r10 # spill L155 to slot
    mov r11, [rbp - 1256] # reload L155 from spill slot
    mov r10, r11 # assign L156
    mov r11, [rbp - 3104] # tag L155 from tag-slot
    mov [rbp - 3112], r11 # store tag L156
    mov [rbp - 1264], r10 # spill L156 to slot
    mov rsi, [rbp - 976] # reload L120 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2824] # tag L120 from tag-slot
    mov rcx, [rbp - 1264] # reload L156 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 3112] # tag L156 from tag-slot
    call fpe_cmp # call fpe_cmp
    mov [rbp - 3120], rax # store tag L157
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1272], r10 # spill L157 to slot
    mov r10, [rbp - 1272] # reload L157 from spill slot
    mov rsi, [rbp - 1272] # reload L157 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3120] # tag L157 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 3128], rax # store tag L158
    mov [rbp - 1280], r10 # spill L158 to slot
    mov r10, [rbp - 1280] # reload L158 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb103 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb102 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb101:
    mov r10, [rbp - 1056] # reload L130 from spill slot
    mov rsi, [rbp - 1056] # reload L130 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2904] # tag L130 from tag-slot
    mov rcx, 1075 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 3200], rax # store tag L167
    mov [rbp - 1352], r10 # spill L167 to slot
    mov r11, [rbp - 1352] # reload L167 from spill slot
    mov r10, r11 # assign L168
    mov r11, [rbp - 3200] # tag L167 from tag-slot
    mov [rbp - 3208], r11 # store tag L168
    mov [rbp - 1360], r10 # spill L168 to slot
    mov r10, [rbp - 1360] # reload L168 from spill slot
    mov rsi, [rbp - 1360] # reload L168 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3208] # tag L168 from tag-slot
    mov rcx, 2047 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 3216], rax # store tag L169
    mov [rbp - 1368], r10 # spill L169 to slot
    mov r10, [rbp - 1368] # reload L169 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb109 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb108 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb102:
    mov rsi, [rbp - 992] # reload L122 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2840] # tag L122 from tag-slot
    mov rcx, 2 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call fpe_mul_small # call fpe_mul_small
    mov [rbp - 3144], rax # store tag L160
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1296], r10 # spill L160 to slot
    mov r11, [rbp - 1296] # reload L160 from spill slot
    mov r10, r11 # assign L122
    mov r11, [rbp - 3144] # tag L160 from tag-slot
    mov [rbp - 2840], r11 # store tag L122
    mov [rbp - 992], r10 # spill L122 to slot
    mov r10, [rbp - 1056] # reload L130 from spill slot
    mov rsi, [rbp - 1056] # reload L130 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2904] # tag L130 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 3152], rax # store tag L161
    mov [rbp - 1304], r10 # spill L161 to slot
    mov r11, [rbp - 1304] # reload L161 from spill slot
    mov r10, r11 # assign L130
    mov r11, [rbp - 3152] # tag L161 from tag-slot
    mov [rbp - 2904], r11 # store tag L130
    mov [rbp - 1056], r10 # spill L130 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb107 # branch
.L7b0c_rt_str_parse_float_exact_bb103:
    mov rsi, [rbp - 976] # reload L120 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2824] # tag L120 from tag-slot
    mov rcx, [rbp - 1248] # reload L154 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 3096] # tag L154 from tag-slot
    call fpe_cmp # call fpe_cmp
    mov [rbp - 3160], rax # store tag L162
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1312], r10 # spill L162 to slot
    mov r10, [rbp - 1312] # reload L162 from spill slot
    mov rsi, [rbp - 1312] # reload L162 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3160] # tag L162 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 3168], rax # store tag L163
    mov [rbp - 1320], r10 # spill L163 to slot
    mov r10, [rbp - 1320] # reload L163 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb105 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb104 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb104:
    mov rsi, [rbp - 976] # reload L120 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2824] # tag L120 from tag-slot
    mov rcx, 2 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call fpe_mul_small # call fpe_mul_small
    mov [rbp - 3184], rax # store tag L165
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1336], r10 # spill L165 to slot
    mov r11, [rbp - 1336] # reload L165 from spill slot
    mov r10, r11 # assign L120
    mov r11, [rbp - 3184] # tag L165 from tag-slot
    mov [rbp - 2824], r11 # store tag L120
    mov [rbp - 976], r10 # spill L120 to slot
    mov r10, [rbp - 1056] # reload L130 from spill slot
    mov rsi, [rbp - 1056] # reload L130 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2904] # tag L130 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 3192], rax # store tag L166
    mov [rbp - 1344], r10 # spill L166 to slot
    mov r11, [rbp - 1344] # reload L166 from spill slot
    mov r10, r11 # assign L130
    mov r11, [rbp - 3192] # tag L166 from tag-slot
    mov [rbp - 2904], r11 # store tag L130
    mov [rbp - 1056], r10 # spill L130 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb106 # branch
.L7b0c_rt_str_parse_float_exact_bb105:
    mov r10, 1 # assign L151
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 3072], r11 # store tag L151
    mov [rbp - 1224], r10 # spill L151 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb106 # branch
.L7b0c_rt_str_parse_float_exact_bb106:
    jmp .L7b0c_rt_str_parse_float_exact_bb107 # branch
.L7b0c_rt_str_parse_float_exact_bb107:
    jmp .L7b0c_rt_str_parse_float_exact_bb99 # branch
.L7b0c_rt_str_parse_float_exact_bb108:
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1992] # tag L16 from tag-slot
    mov rcx, 2047 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    mov r9, 0 # hv arg payload
    mov r8, 0 # tag default = TAG_INT
    call fpe_assemble # call fpe_assemble
    mov [rbp - 3232], rax # store tag L171
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1384], r10 # spill L171 to slot
    mov rdx, [rbp - 1384] # reload L171 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 3232] # tag L171 from tag-slot
    add rsp, 3664 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_rt_str_parse_float_exact_bb109:
    mov r10, [rbp - 1360] # reload L168 from spill slot
    mov rsi, [rbp - 1360] # reload L168 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3208] # tag L168 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 3240], rax # store tag L172
    mov [rbp - 1392], r10 # spill L172 to slot
    mov r10, [rbp - 1392] # reload L172 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb111 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb110 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb110:
    mov rsi, [rbp - 976] # reload L120 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2824] # tag L120 from tag-slot
    mov rcx, [rbp - 992] # reload L122 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 2840] # tag L122 from tag-slot
    call fpe_divmod # call fpe_divmod
    mov [rbp - 3256], rax # store tag L174
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1408], r10 # spill L174 to slot
    mov r11, [rbp - 1408] # reload L174 from spill slot
    mov r10, r11 # assign L175
    mov r11, [rbp - 3256] # tag L174 from tag-slot
    mov [rbp - 3264], r11 # store tag L175
    mov [rbp - 1416], r10 # spill L175 to slot
    mov rsi, [rbp - 1416] # reload L175 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3264] # tag L175 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 3272], rax # store tag L176
    mov [rbp - 1424], r10 # spill L176 to slot
    mov rsi, [rbp - 1424] # reload L176 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3272] # tag L176 from tag-slot
    call fpe_to_i64 # call fpe_to_i64
    mov [rbp - 3280], rax # store tag L177
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1432], r10 # spill L177 to slot
    mov r11, [rbp - 1432] # reload L177 from spill slot
    mov r10, r11 # assign L178
    mov r11, [rbp - 3280] # tag L177 from tag-slot
    mov [rbp - 3288], r11 # store tag L178
    mov [rbp - 1440], r10 # spill L178 to slot
    mov rsi, [rbp - 1416] # reload L175 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3264] # tag L175 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 3296], rax # store tag L179
    mov [rbp - 1448], r10 # spill L179 to slot
    mov rsi, [rbp - 1448] # reload L179 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3296] # tag L179 from tag-slot
    mov rcx, 2 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call fpe_mul_small # call fpe_mul_small
    mov [rbp - 3304], rax # store tag L180
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1456], r10 # spill L180 to slot
    mov rsi, [rbp - 1456] # reload L180 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3304] # tag L180 from tag-slot
    mov rcx, [rbp - 992] # reload L122 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 2840] # tag L122 from tag-slot
    call fpe_cmp # call fpe_cmp
    mov [rbp - 3312], rax # store tag L181
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1464], r10 # spill L181 to slot
    mov r11, [rbp - 1464] # reload L181 from spill slot
    mov r10, r11 # assign L182
    mov r11, [rbp - 3312] # tag L181 from tag-slot
    mov [rbp - 3320], r11 # store tag L182
    mov [rbp - 1472], r10 # spill L182 to slot
    mov r10, 0 # assign L183
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 3328], r11 # store tag L183
    mov [rbp - 1480], r10 # spill L183 to slot
    mov r10, [rbp - 1472] # reload L182 from spill slot
    mov rsi, [rbp - 1472] # reload L182 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3320] # tag L182 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 3336], rax # store tag L184
    mov [rbp - 1488], r10 # spill L184 to slot
    mov r10, [rbp - 1488] # reload L184 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb113 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb112 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb111:
    mov r11, [rbp - 1360] # reload L168 from spill slot
    mov rsi, 1 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    mov rcx, [rbp - 1360] # reload L168 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 3208] # tag L168 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 3480], rax # store tag L202
    mov [rbp - 1632], r10 # spill L202 to slot
    mov r11, [rbp - 1632] # reload L202 from spill slot
    mov r10, r11 # assign L203
    mov r11, [rbp - 3480] # tag L202 from tag-slot
    mov [rbp - 3488], r11 # store tag L203
    mov [rbp - 1640], r10 # spill L203 to slot
    mov rsi, [rbp - 992] # reload L122 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2840] # tag L122 from tag-slot
    mov rcx, [rbp - 1640] # reload L203 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 3488] # tag L203 from tag-slot
    call fpe_shl # call fpe_shl
    mov [rbp - 3496], rax # store tag L204
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1648], r10 # spill L204 to slot
    mov r11, [rbp - 1648] # reload L204 from spill slot
    mov r10, r11 # assign L205
    mov r11, [rbp - 3496] # tag L204 from tag-slot
    mov [rbp - 3504], r11 # store tag L205
    mov [rbp - 1656], r10 # spill L205 to slot
    mov rsi, [rbp - 976] # reload L120 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2824] # tag L120 from tag-slot
    mov rcx, [rbp - 1656] # reload L205 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 3504] # tag L205 from tag-slot
    call fpe_divmod # call fpe_divmod
    mov [rbp - 3512], rax # store tag L206
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1664], r10 # spill L206 to slot
    mov r11, [rbp - 1664] # reload L206 from spill slot
    mov r10, r11 # assign L207
    mov r11, [rbp - 3512] # tag L206 from tag-slot
    mov [rbp - 3520], r11 # store tag L207
    mov [rbp - 1672], r10 # spill L207 to slot
    mov rsi, [rbp - 1672] # reload L207 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3520] # tag L207 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 3528], rax # store tag L208
    mov [rbp - 1680], r10 # spill L208 to slot
    mov rsi, [rbp - 1680] # reload L208 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3528] # tag L208 from tag-slot
    call fpe_to_i64 # call fpe_to_i64
    mov [rbp - 3536], rax # store tag L209
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1688], r10 # spill L209 to slot
    mov r11, [rbp - 1688] # reload L209 from spill slot
    mov r10, r11 # assign L210
    mov r11, [rbp - 3536] # tag L209 from tag-slot
    mov [rbp - 3544], r11 # store tag L210
    mov [rbp - 1696], r10 # spill L210 to slot
    mov rsi, [rbp - 1672] # reload L207 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3520] # tag L207 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 3552], rax # store tag L211
    mov [rbp - 1704], r10 # spill L211 to slot
    mov rsi, [rbp - 1704] # reload L211 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3552] # tag L211 from tag-slot
    mov rcx, 2 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call fpe_mul_small # call fpe_mul_small
    mov [rbp - 3560], rax # store tag L212
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1712], r10 # spill L212 to slot
    mov rsi, [rbp - 1712] # reload L212 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3560] # tag L212 from tag-slot
    mov rcx, [rbp - 1656] # reload L205 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 3504] # tag L205 from tag-slot
    call fpe_cmp # call fpe_cmp
    mov [rbp - 3568], rax # store tag L213
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1720], r10 # spill L213 to slot
    mov r11, [rbp - 1720] # reload L213 from spill slot
    mov r10, r11 # assign L214
    mov r11, [rbp - 3568] # tag L213 from tag-slot
    mov [rbp - 3576], r11 # store tag L214
    mov [rbp - 1728], r10 # spill L214 to slot
    mov r10, 0 # assign L215
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 3584], r11 # store tag L215
    mov [rbp - 1736], r10 # spill L215 to slot
    mov r10, [rbp - 1728] # reload L214 from spill slot
    mov rsi, [rbp - 1728] # reload L214 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3576] # tag L214 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 3592], rax # store tag L216
    mov [rbp - 1744], r10 # spill L216 to slot
    mov r10, [rbp - 1744] # reload L216 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb126 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb125 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb112:
    mov r10, 1 # assign L183
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 3328], r11 # store tag L183
    mov [rbp - 1480], r10 # spill L183 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb118 # branch
.L7b0c_rt_str_parse_float_exact_bb113:
    mov r10, [rbp - 1472] # reload L182 from spill slot
    mov rsi, [rbp - 1472] # reload L182 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3320] # tag L182 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 3352], rax # store tag L186
    mov [rbp - 1504], r10 # spill L186 to slot
    mov r10, [rbp - 1504] # reload L186 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb115 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb114 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb114:
    mov r10, [rbp - 1440] # reload L178 from spill slot
    mov rsi, [rbp - 1440] # reload L178 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3288] # tag L178 from tag-slot
    mov rcx, 2 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mod # binop %: tag-dispatch hexa_mod
    mov r10, rdx # binop %: capture result payload
    mov [rbp - 3368], rax # store tag L188
    mov [rbp - 1520], r10 # spill L188 to slot
    mov r10, [rbp - 1520] # reload L188 from spill slot
    mov rsi, [rbp - 1520] # reload L188 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3368] # tag L188 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 3376], rax # store tag L189
    mov [rbp - 1528], r10 # spill L189 to slot
    mov r10, [rbp - 1528] # reload L189 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb117 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb116 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb115:
    jmp .L7b0c_rt_str_parse_float_exact_bb118 # branch
.L7b0c_rt_str_parse_float_exact_bb116:
    mov r10, 1 # assign L183
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 3328], r11 # store tag L183
    mov [rbp - 1480], r10 # spill L183 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb117 # branch
.L7b0c_rt_str_parse_float_exact_bb117:
    jmp .L7b0c_rt_str_parse_float_exact_bb115 # branch
.L7b0c_rt_str_parse_float_exact_bb118:
    mov r10, [rbp - 1480] # reload L183 from spill slot
    mov rsi, [rbp - 1480] # reload L183 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3328] # tag L183 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 3392], rax # store tag L191
    mov [rbp - 1544], r10 # spill L191 to slot
    mov r10, [rbp - 1544] # reload L191 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb120 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb119 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb119:
    mov r10, [rbp - 1440] # reload L178 from spill slot
    mov rsi, [rbp - 1440] # reload L178 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3288] # tag L178 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 3408], rax # store tag L193
    mov [rbp - 1560], r10 # spill L193 to slot
    mov r11, [rbp - 1560] # reload L193 from spill slot
    mov r10, r11 # assign L178
    mov r11, [rbp - 3408] # tag L193 from tag-slot
    mov [rbp - 3288], r11 # store tag L178
    mov [rbp - 1440], r10 # spill L178 to slot
    mov r10, [rbp - 1440] # reload L178 from spill slot
    mov rsi, [rbp - 1440] # reload L178 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3288] # tag L178 from tag-slot
    mov rcx, 9007199254740992 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 3416], rax # store tag L194
    mov [rbp - 1568], r10 # spill L194 to slot
    mov r10, [rbp - 1568] # reload L194 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb122 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb121 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb120:
    mov r10, [rbp - 1360] # reload L168 from spill slot
    mov rsi, [rbp - 1360] # reload L168 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3208] # tag L168 from tag-slot
    mov rcx, 2047 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 3440], rax # store tag L197
    mov [rbp - 1592], r10 # spill L197 to slot
    mov r10, [rbp - 1592] # reload L197 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb124 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb123 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb121:
    mov r10, 4503599627370496 # assign L178
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 3288], r11 # store tag L178
    mov [rbp - 1440], r10 # spill L178 to slot
    mov r10, [rbp - 1360] # reload L168 from spill slot
    mov rsi, [rbp - 1360] # reload L168 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3208] # tag L168 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 3432], rax # store tag L196
    mov [rbp - 1584], r10 # spill L196 to slot
    mov r11, [rbp - 1584] # reload L196 from spill slot
    mov r10, r11 # assign L168
    mov r11, [rbp - 3432] # tag L196 from tag-slot
    mov [rbp - 3208], r11 # store tag L168
    mov [rbp - 1360], r10 # spill L168 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb122 # branch
.L7b0c_rt_str_parse_float_exact_bb122:
    jmp .L7b0c_rt_str_parse_float_exact_bb120 # branch
.L7b0c_rt_str_parse_float_exact_bb123:
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1992] # tag L16 from tag-slot
    mov rcx, 2047 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    mov r9, 0 # hv arg payload
    mov r8, 0 # tag default = TAG_INT
    call fpe_assemble # call fpe_assemble
    mov [rbp - 3456], rax # store tag L199
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1608], r10 # spill L199 to slot
    mov rdx, [rbp - 1608] # reload L199 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 3456] # tag L199 from tag-slot
    add rsp, 3664 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_rt_str_parse_float_exact_bb124:
    mov r10, [rbp - 1440] # reload L178 from spill slot
    mov rsi, [rbp - 1440] # reload L178 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3288] # tag L178 from tag-slot
    mov rcx, 4503599627370496 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 3464], rax # store tag L200
    mov [rbp - 1616], r10 # spill L200 to slot
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1992] # tag L16 from tag-slot
    mov rcx, [rbp - 1360] # reload L168 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 3208] # tag L168 from tag-slot
    mov r9, [rbp - 1616] # reload L200 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 3464] # tag L200 from tag-slot
    call fpe_assemble # call fpe_assemble
    mov [rbp - 3472], rax # store tag L201
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1624], r10 # spill L201 to slot
    mov rdx, [rbp - 1624] # reload L201 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 3472] # tag L201 from tag-slot
    add rsp, 3664 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_rt_str_parse_float_exact_bb125:
    mov r10, 1 # assign L215
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 3584], r11 # store tag L215
    mov [rbp - 1736], r10 # spill L215 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb131 # branch
.L7b0c_rt_str_parse_float_exact_bb126:
    mov r10, [rbp - 1728] # reload L214 from spill slot
    mov rsi, [rbp - 1728] # reload L214 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3576] # tag L214 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 3608], rax # store tag L218
    mov [rbp - 1760], r10 # spill L218 to slot
    mov r10, [rbp - 1760] # reload L218 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb128 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb127 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb127:
    mov r10, [rbp - 1696] # reload L210 from spill slot
    mov rsi, [rbp - 1696] # reload L210 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3544] # tag L210 from tag-slot
    mov rcx, 2 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mod # binop %: tag-dispatch hexa_mod
    mov r10, rdx # binop %: capture result payload
    mov [rbp - 3624], rax # store tag L220
    mov [rbp - 1776], r10 # spill L220 to slot
    mov r10, [rbp - 1776] # reload L220 from spill slot
    mov rsi, [rbp - 1776] # reload L220 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3624] # tag L220 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 3632], rax # store tag L221
    mov [rbp - 1784], r10 # spill L221 to slot
    mov r10, [rbp - 1784] # reload L221 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb130 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb129 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb128:
    jmp .L7b0c_rt_str_parse_float_exact_bb131 # branch
.L7b0c_rt_str_parse_float_exact_bb129:
    mov r10, 1 # assign L215
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 3584], r11 # store tag L215
    mov [rbp - 1736], r10 # spill L215 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb130 # branch
.L7b0c_rt_str_parse_float_exact_bb130:
    jmp .L7b0c_rt_str_parse_float_exact_bb128 # branch
.L7b0c_rt_str_parse_float_exact_bb131:
    mov r10, [rbp - 1736] # reload L215 from spill slot
    mov rsi, [rbp - 1736] # reload L215 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3584] # tag L215 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 3648], rax # store tag L223
    mov [rbp - 1800], r10 # spill L223 to slot
    mov r10, [rbp - 1800] # reload L223 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb133 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb132 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb132:
    mov r10, [rbp - 1696] # reload L210 from spill slot
    mov rsi, [rbp - 1696] # reload L210 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3544] # tag L210 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 3664], rax # store tag L225
    mov [rbp - 1816], r10 # spill L225 to slot
    mov r11, [rbp - 1816] # reload L225 from spill slot
    mov r10, r11 # assign L210
    mov r11, [rbp - 3664] # tag L225 from tag-slot
    mov [rbp - 3544], r11 # store tag L210
    mov [rbp - 1696], r10 # spill L210 to slot
    jmp .L7b0c_rt_str_parse_float_exact_bb133 # branch
.L7b0c_rt_str_parse_float_exact_bb133:
    mov r10, [rbp - 1696] # reload L210 from spill slot
    mov rsi, [rbp - 1696] # reload L210 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3544] # tag L210 from tag-slot
    mov rcx, 4503599627370496 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 3672], rax # store tag L226
    mov [rbp - 1824], r10 # spill L226 to slot
    mov r10, [rbp - 1824] # reload L226 from spill slot
    test r10, r10 # br_cond test
    jz .L7b0c_rt_str_parse_float_exact_bb135 # jump-if-zero -> else
    jmp .L7b0c_rt_str_parse_float_exact_bb134 # jump -> then
.L7b0c_rt_str_parse_float_exact_bb134:
    mov r10, [rbp - 1696] # reload L210 from spill slot
    mov rsi, [rbp - 1696] # reload L210 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 3544] # tag L210 from tag-slot
    mov rcx, 4503599627370496 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 3688], rax # store tag L228
    mov [rbp - 1840], r10 # spill L228 to slot
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1992] # tag L16 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    mov r9, [rbp - 1840] # reload L228 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 3688] # tag L228 from tag-slot
    call fpe_assemble # call fpe_assemble
    mov [rbp - 3696], rax # store tag L229
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1848], r10 # spill L229 to slot
    mov rdx, [rbp - 1848] # reload L229 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 3696] # tag L229 from tag-slot
    add rsp, 3664 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L7b0c_rt_str_parse_float_exact_bb135:
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1992] # tag L16 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    mov r9, [rbp - 1696] # reload L210 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 3544] # tag L210 from tag-slot
    call fpe_assemble # call fpe_assemble
    mov [rbp - 3704], rax # store tag L230
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1856], r10 # spill L230 to slot
    mov rdx, [rbp - 1856] # reload L230 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 3704] # tag L230 from tag-slot
    add rsp, 3664 # epilogue: free spill frame
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
