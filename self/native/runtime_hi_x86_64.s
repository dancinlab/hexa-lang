// runtime_hi_x86_64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B Z2a).
// GENERATED: tool/regen_runtime_hi_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=x86_64-linux-gnu -o runtime_hi_x86_64.s runtime_hi_lib.hexa (lib-only head of self/runtime_hi.hexa).
//   Provides rt_str_* (zero C): split/lines/pad_left/pad_right/repeat/center +
//   to_upper/to_lower/trim/trim_start/trim_end +
//   starts_with_b/ends_with_b/contains_b + from_int (15 fns). ABI: ELF, rt_str_* no underscore + .hidden.
//   Lets this target avoid #include "runtime_hi_gen.c" (leg B ls-reduction).
.intel_syntax noprefix
.file 1 "self/runtime_hi.hexa"
.text
.globl rt_str_split
.hidden rt_str_split
    .p2align 4
rt_str_split:
    .loc 1 22 0
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
.L62a9_rt_str_split_bb0:
    call hexa_array_new # array_lit: new array
    mov r13, rdx # array_lit: capture new array payload
    mov [rbp - 240], rax # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 240] # tag L2 from tag-slot
    mov [rbp - 248], r11 # store tag L3
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 232] # tag L1 from tag-slot
    call hexa_len # call hexa_len
    mov r15, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 256], r11 # store tag L4
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 256] # tag L4 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 264], rax # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_split_bb2 # jump-if-zero -> else
    jmp .L62a9_rt_str_split_bb1 # jump -> then
.L62a9_rt_str_split_bb1:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 248] # tag L3 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 224] # tag L0 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 280], rax # store tag L7
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 72], r10 # spill L7 to slot
    mov rdx, r14 # hv arg payload
    mov rax, [rbp - 248] # tag L3 from tag-slot
    add rsp, 384 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_split_bb2:
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 232] # tag L1 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 288], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 288] # tag L8 from tag-slot
    mov [rbp - 296], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, 0 # assign L10
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 304], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, 0 # assign L11
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 312], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    jmp .L62a9_rt_str_split_bb3 # branch
.L62a9_rt_str_split_bb3:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 224] # tag L0 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 320], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 320] # tag L12 from tag-slot
    mov rcx, [rbp - 88] # reload L9 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 296] # tag L9 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 328], rax # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov rsi, [rbp - 104] # reload L11 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 312] # tag L11 from tag-slot
    mov rcx, [rbp - 120] # reload L13 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 328] # tag L13 from tag-slot
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 336], rax # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r10, [rbp - 128] # reload L14 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_split_bb5 # jump-if-zero -> else
    jmp .L62a9_rt_str_split_bb4 # jump -> then
.L62a9_rt_str_split_bb4:
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 104] # reload L11 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 312] # tag L11 from tag-slot
    mov rcx, [rbp - 88] # reload L9 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 296] # tag L9 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 344], rax # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 224] # tag L0 from tag-slot
    mov rcx, [rbp - 104] # reload L11 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 312] # tag L11 from tag-slot
    mov r9, [rbp - 136] # reload L15 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 344] # tag L15 from tag-slot
    call hexa_str_substring # call hexa_str_substring
    mov [rbp - 352], rax # store tag L16
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 144], r10 # spill L16 to slot
    mov r10, [rbp - 144] # reload L16 from spill slot
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 352] # tag L16 from tag-slot
    mov rcx, r12 # hv arg payload
    mov rdx, [rbp - 232] # tag L1 from tag-slot
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 360], rax # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_split_bb7 # jump-if-zero -> else
    jmp .L62a9_rt_str_split_bb6 # jump -> then
.L62a9_rt_str_split_bb5:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 224] # tag L0 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 408], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 224] # tag L0 from tag-slot
    mov rcx, [rbp - 96] # reload L10 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 304] # tag L10 from tag-slot
    mov r9, [rbp - 200] # reload L23 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 408] # tag L23 from tag-slot
    call hexa_str_substring # call hexa_str_substring
    mov [rbp - 416], rax # store tag L24
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 208], r10 # spill L24 to slot
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 248] # tag L3 from tag-slot
    mov rcx, [rbp - 208] # reload L24 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 416] # tag L24 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 424], rax # store tag L25
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 216], r10 # spill L25 to slot
    mov rdx, r14 # hv arg payload
    mov rax, [rbp - 248] # tag L3 from tag-slot
    add rsp, 384 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_split_bb6:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 224] # tag L0 from tag-slot
    mov rcx, [rbp - 96] # reload L10 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 304] # tag L10 from tag-slot
    mov r9, [rbp - 104] # reload L11 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 312] # tag L11 from tag-slot
    call hexa_str_substring # call hexa_str_substring
    mov [rbp - 376], rax # store tag L19
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 168], r10 # spill L19 to slot
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 248] # tag L3 from tag-slot
    mov rcx, [rbp - 168] # reload L19 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 376] # tag L19 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 384], rax # store tag L20
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 104] # reload L11 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 312] # tag L11 from tag-slot
    mov rcx, [rbp - 88] # reload L9 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 296] # tag L9 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 392], rax # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L10
    mov r11, [rbp - 392] # tag L21 from tag-slot
    mov [rbp - 304], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 304] # tag L10 from tag-slot
    mov [rbp - 312], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    jmp .L62a9_rt_str_split_bb8 # branch
.L62a9_rt_str_split_bb7:
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov rsi, [rbp - 104] # reload L11 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 312] # tag L11 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 400], rax # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 400] # tag L22 from tag-slot
    mov [rbp - 312], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    jmp .L62a9_rt_str_split_bb8 # branch
.L62a9_rt_str_split_bb8:
    jmp .L62a9_rt_str_split_bb3 # branch
    add rsp, 384 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_lines
.hidden rt_str_lines
    .p2align 4
rt_str_lines:
    .loc 1 45 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 16 # prologue: alloc spill frame
    mov [rbp - 56], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.L62a9_rt_str_lines_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 56] # tag L0 from tag-slot
    lea rcx, [rip+.LCstr0] # hv arg payload: &str .LCstr0
    mov rdx, 3 # hv arg tag = TAG_STR
    call rt_str_split # call rt_str_split
    mov [rbp - 64], rax # store tag L1
    mov r12, rdx # hv: unbox user-call result payload
    mov rdx, r12 # hv arg payload
    mov rax, [rbp - 64] # tag L1 from tag-slot
    add rsp, 16 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_pad_left
.hidden rt_str_pad_left
    .p2align 4
rt_str_pad_left:
    .loc 1 52 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 400 # prologue: alloc spill frame
    mov [rbp - 232], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 240], rdx # store tag L1
    mov r12, rcx # ingress param payload
    mov [rbp - 248], r8 # store tag L2
    mov r13, r9 # ingress param payload
.L62a9_rt_str_pad_left_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 232] # tag L0 from tag-slot
    call hexa_len # call hexa_len
    mov r14, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 256], r11 # store tag L3
    mov r15, r14 # assign L4
    mov r11, [rbp - 256] # tag L3 from tag-slot
    mov [rbp - 264], r11 # store tag L4
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 248] # tag L2 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 272], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 272] # tag L5 from tag-slot
    mov [rbp - 280], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 264] # tag L4 from tag-slot
    mov rcx, r12 # hv arg payload
    mov rdx, [rbp - 240] # tag L1 from tag-slot
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 288], rax # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_pad_left_bb2 # jump-if-zero -> else
    jmp .L62a9_rt_str_pad_left_bb1 # jump -> then
.L62a9_rt_str_pad_left_bb1:
    mov rdx, rbx # hv arg payload
    mov rax, [rbp - 232] # tag L0 from tag-slot
    add rsp, 400 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_pad_left_bb2:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 280] # tag L6 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 304], rax # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_pad_left_bb4 # jump-if-zero -> else
    jmp .L62a9_rt_str_pad_left_bb3 # jump -> then
.L62a9_rt_str_pad_left_bb3:
    mov rdx, rbx # hv arg payload
    mov rax, [rbp - 232] # tag L0 from tag-slot
    add rsp, 400 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_pad_left_bb4:
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 240] # tag L1 from tag-slot
    mov rcx, r15 # hv arg payload
    mov rdx, [rbp - 264] # tag L4 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 320], rax # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 320] # tag L11 from tag-slot
    mov [rbp - 328], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 328] # tag L12 from tag-slot
    mov rcx, [rbp - 64] # reload L6 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 280] # tag L6 from tag-slot
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 336], rax # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov r10, r11 # assign L14
    mov r11, [rbp - 336] # tag L13 from tag-slot
    mov [rbp - 344], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r10, [rbp - 128] # reload L14 from spill slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 128] # reload L14 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 344] # tag L14 from tag-slot
    mov rcx, [rbp - 64] # reload L6 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 280] # tag L6 from tag-slot
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 352], rax # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 352] # tag L15 from tag-slot
    mov rcx, [rbp - 112] # reload L12 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 328] # tag L12 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 360], rax # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r10, [rbp - 144] # reload L16 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_pad_left_bb6 # jump-if-zero -> else
    jmp .L62a9_rt_str_pad_left_bb5 # jump -> then
.L62a9_rt_str_pad_left_bb5:
    mov r10, [rbp - 128] # reload L14 from spill slot
    mov rsi, [rbp - 128] # reload L14 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 344] # tag L14 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 376], rax # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov r10, r11 # assign L14
    mov r11, [rbp - 376] # tag L18 from tag-slot
    mov [rbp - 344], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    jmp .L62a9_rt_str_pad_left_bb6 # branch
.L62a9_rt_str_pad_left_bb6:
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 384], rax # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov r10, r11 # assign L20
    mov r11, [rbp - 384] # tag L19 from tag-slot
    mov [rbp - 392], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, 0 # assign L21
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 400], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    jmp .L62a9_rt_str_pad_left_bb7 # branch
.L62a9_rt_str_pad_left_bb7:
    mov r10, [rbp - 184] # reload L21 from spill slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov rsi, [rbp - 184] # reload L21 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 400] # tag L21 from tag-slot
    mov rcx, [rbp - 128] # reload L14 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 344] # tag L14 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 408], rax # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r10, [rbp - 192] # reload L22 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_pad_left_bb9 # jump-if-zero -> else
    jmp .L62a9_rt_str_pad_left_bb8 # jump -> then
.L62a9_rt_str_pad_left_bb8:
    mov rsi, [rbp - 176] # reload L20 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 392] # tag L20 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 248] # tag L2 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 416], rax # store tag L23
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 200], r10 # spill L23 to slot
    mov r10, [rbp - 184] # reload L21 from spill slot
    mov rsi, [rbp - 184] # reload L21 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 400] # tag L21 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 424], rax # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r11, [rbp - 208] # reload L24 from spill slot
    mov r10, r11 # assign L21
    mov r11, [rbp - 424] # tag L24 from tag-slot
    mov [rbp - 400], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    jmp .L62a9_rt_str_pad_left_bb7 # branch
.L62a9_rt_str_pad_left_bb9:
    mov rsi, [rbp - 176] # reload L20 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 392] # tag L20 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 232] # tag L0 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 432], rax # store tag L25
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 216], r10 # spill L25 to slot
    mov rsi, [rbp - 176] # reload L20 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 392] # tag L20 from tag-slot
    lea rcx, [rip+.LCstr1] # hv arg payload: &str .LCstr1
    mov rdx, 3 # hv arg tag = TAG_STR
    call hexa_str_join # call hexa_str_join
    mov [rbp - 440], rax # store tag L26
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 224], r10 # spill L26 to slot
    mov rdx, [rbp - 224] # reload L26 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 440] # tag L26 from tag-slot
    add rsp, 400 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_pad_right
.hidden rt_str_pad_right
    .p2align 4
rt_str_pad_right:
    .loc 1 70 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 400 # prologue: alloc spill frame
    mov [rbp - 232], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 240], rdx # store tag L1
    mov r12, rcx # ingress param payload
    mov [rbp - 248], r8 # store tag L2
    mov r13, r9 # ingress param payload
.L62a9_rt_str_pad_right_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 232] # tag L0 from tag-slot
    call hexa_len # call hexa_len
    mov r14, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 256], r11 # store tag L3
    mov r15, r14 # assign L4
    mov r11, [rbp - 256] # tag L3 from tag-slot
    mov [rbp - 264], r11 # store tag L4
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 248] # tag L2 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 272], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 272] # tag L5 from tag-slot
    mov [rbp - 280], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 264] # tag L4 from tag-slot
    mov rcx, r12 # hv arg payload
    mov rdx, [rbp - 240] # tag L1 from tag-slot
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 288], rax # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_pad_right_bb2 # jump-if-zero -> else
    jmp .L62a9_rt_str_pad_right_bb1 # jump -> then
.L62a9_rt_str_pad_right_bb1:
    mov rdx, rbx # hv arg payload
    mov rax, [rbp - 232] # tag L0 from tag-slot
    add rsp, 400 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_pad_right_bb2:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 280] # tag L6 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 304], rax # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_pad_right_bb4 # jump-if-zero -> else
    jmp .L62a9_rt_str_pad_right_bb3 # jump -> then
.L62a9_rt_str_pad_right_bb3:
    mov rdx, rbx # hv arg payload
    mov rax, [rbp - 232] # tag L0 from tag-slot
    add rsp, 400 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_pad_right_bb4:
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 240] # tag L1 from tag-slot
    mov rcx, r15 # hv arg payload
    mov rdx, [rbp - 264] # tag L4 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 320], rax # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 320] # tag L11 from tag-slot
    mov [rbp - 328], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 328] # tag L12 from tag-slot
    mov rcx, [rbp - 64] # reload L6 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 280] # tag L6 from tag-slot
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 336], rax # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov r10, r11 # assign L14
    mov r11, [rbp - 336] # tag L13 from tag-slot
    mov [rbp - 344], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r10, [rbp - 128] # reload L14 from spill slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 128] # reload L14 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 344] # tag L14 from tag-slot
    mov rcx, [rbp - 64] # reload L6 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 280] # tag L6 from tag-slot
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 352], rax # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 352] # tag L15 from tag-slot
    mov rcx, [rbp - 112] # reload L12 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 328] # tag L12 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 360], rax # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r10, [rbp - 144] # reload L16 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_pad_right_bb6 # jump-if-zero -> else
    jmp .L62a9_rt_str_pad_right_bb5 # jump -> then
.L62a9_rt_str_pad_right_bb5:
    mov r10, [rbp - 128] # reload L14 from spill slot
    mov rsi, [rbp - 128] # reload L14 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 344] # tag L14 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 376], rax # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov r10, r11 # assign L14
    mov r11, [rbp - 376] # tag L18 from tag-slot
    mov [rbp - 344], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    jmp .L62a9_rt_str_pad_right_bb6 # branch
.L62a9_rt_str_pad_right_bb6:
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 384], rax # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov r10, r11 # assign L20
    mov r11, [rbp - 384] # tag L19 from tag-slot
    mov [rbp - 392], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov rsi, [rbp - 176] # reload L20 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 392] # tag L20 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 232] # tag L0 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 400], rax # store tag L21
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 184], r10 # spill L21 to slot
    mov r10, 0 # assign L22
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 408], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    jmp .L62a9_rt_str_pad_right_bb7 # branch
.L62a9_rt_str_pad_right_bb7:
    mov r10, [rbp - 192] # reload L22 from spill slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov rsi, [rbp - 192] # reload L22 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 408] # tag L22 from tag-slot
    mov rcx, [rbp - 128] # reload L14 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 344] # tag L14 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 416], rax # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r10, [rbp - 200] # reload L23 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_pad_right_bb9 # jump-if-zero -> else
    jmp .L62a9_rt_str_pad_right_bb8 # jump -> then
.L62a9_rt_str_pad_right_bb8:
    mov rsi, [rbp - 176] # reload L20 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 392] # tag L20 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 248] # tag L2 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 424], rax # store tag L24
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 208], r10 # spill L24 to slot
    mov r10, [rbp - 192] # reload L22 from spill slot
    mov rsi, [rbp - 192] # reload L22 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 408] # tag L22 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 432], rax # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r11, [rbp - 216] # reload L25 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 432] # tag L25 from tag-slot
    mov [rbp - 408], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    jmp .L62a9_rt_str_pad_right_bb7 # branch
.L62a9_rt_str_pad_right_bb9:
    mov rsi, [rbp - 176] # reload L20 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 392] # tag L20 from tag-slot
    lea rcx, [rip+.LCstr1] # hv arg payload: &str .LCstr1
    mov rdx, 3 # hv arg tag = TAG_STR
    call hexa_str_join # call hexa_str_join
    mov [rbp - 440], rax # store tag L26
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 224], r10 # spill L26 to slot
    mov rdx, [rbp - 224] # reload L26 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 440] # tag L26 from tag-slot
    add rsp, 400 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_repeat
.hidden rt_str_repeat
    .p2align 4
rt_str_repeat:
    .loc 1 89 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 144 # prologue: alloc spill frame
    mov [rbp - 104], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 112], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L62a9_rt_str_repeat_bb0:
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 112] # tag L1 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r13, rdx # binop <=: capture bool payload
    mov [rbp - 120], rax # store tag L2
    test r13, r13 # br_cond test
    jz .L62a9_rt_str_repeat_bb2 # jump-if-zero -> else
    jmp .L62a9_rt_str_repeat_bb1 # jump -> then
.L62a9_rt_str_repeat_bb1:
    lea rdx, [rip+.LCstr1] # hv arg payload: &str .LCstr1
    mov rax, 3 # hv arg tag = TAG_STR
    add rsp, 144 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_repeat_bb2:
    call hexa_array_new # array_lit: new array
    mov r15, rdx # array_lit: capture new array payload
    mov [rbp - 136], rax # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 136] # tag L4 from tag-slot
    mov [rbp - 144], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, 0 # assign L6
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 152], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    jmp .L62a9_rt_str_repeat_bb3 # branch
.L62a9_rt_str_repeat_bb3:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 152] # tag L6 from tag-slot
    mov rcx, r12 # hv arg payload
    mov rdx, [rbp - 112] # tag L1 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 160], rax # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_repeat_bb5 # jump-if-zero -> else
    jmp .L62a9_rt_str_repeat_bb4 # jump -> then
.L62a9_rt_str_repeat_bb4:
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 144] # tag L5 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 104] # tag L0 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 168], rax # store tag L8
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 152] # tag L6 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 176], rax # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 176] # tag L9 from tag-slot
    mov [rbp - 152], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    jmp .L62a9_rt_str_repeat_bb3 # branch
.L62a9_rt_str_repeat_bb5:
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 144] # tag L5 from tag-slot
    lea rcx, [rip+.LCstr1] # hv arg payload: &str .LCstr1
    mov rdx, 3 # hv arg tag = TAG_STR
    call hexa_str_join # call hexa_str_join
    mov [rbp - 184], rax # store tag L10
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 96], r10 # spill L10 to slot
    mov rdx, [rbp - 96] # reload L10 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 184] # tag L10 from tag-slot
    add rsp, 144 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_center
.hidden rt_str_center
    .p2align 4
rt_str_center:
    .loc 1 101 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 624 # prologue: alloc spill frame
    mov [rbp - 344], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 352], rdx # store tag L1
    mov r12, rcx # ingress param payload
    mov [rbp - 360], r8 # store tag L2
    mov r13, r9 # ingress param payload
.L62a9_rt_str_center_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 344] # tag L0 from tag-slot
    call hexa_len # call hexa_len
    mov r14, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 368], r11 # store tag L3
    mov r15, r14 # assign L4
    mov r11, [rbp - 368] # tag L3 from tag-slot
    mov [rbp - 376], r11 # store tag L4
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 360] # tag L2 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 384], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 384] # tag L5 from tag-slot
    mov [rbp - 392], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 376] # tag L4 from tag-slot
    mov rcx, r12 # hv arg payload
    mov rdx, [rbp - 352] # tag L1 from tag-slot
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 400], rax # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_center_bb2 # jump-if-zero -> else
    jmp .L62a9_rt_str_center_bb1 # jump -> then
.L62a9_rt_str_center_bb1:
    mov rdx, rbx # hv arg payload
    mov rax, [rbp - 344] # tag L0 from tag-slot
    add rsp, 624 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_center_bb2:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 392] # tag L6 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 416], rax # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_center_bb4 # jump-if-zero -> else
    jmp .L62a9_rt_str_center_bb3 # jump -> then
.L62a9_rt_str_center_bb3:
    mov rdx, rbx # hv arg payload
    mov rax, [rbp - 344] # tag L0 from tag-slot
    add rsp, 624 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_center_bb4:
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 352] # tag L1 from tag-slot
    mov rcx, r15 # hv arg payload
    mov rdx, [rbp - 376] # tag L4 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 432], rax # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 432] # tag L11 from tag-slot
    mov [rbp - 440], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 440] # tag L12 from tag-slot
    mov rcx, 2 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 448], rax # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov r10, r11 # assign L14
    mov r11, [rbp - 448] # tag L13 from tag-slot
    mov [rbp - 456], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 440] # tag L12 from tag-slot
    mov rcx, [rbp - 128] # reload L14 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 456] # tag L14 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 464], rax # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, [rbp - 136] # reload L15 from spill slot
    mov r10, r11 # assign L16
    mov r11, [rbp - 464] # tag L15 from tag-slot
    mov [rbp - 472], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r10, [rbp - 128] # reload L14 from spill slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 128] # reload L14 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 456] # tag L14 from tag-slot
    mov rcx, [rbp - 64] # reload L6 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 392] # tag L6 from tag-slot
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 480], rax # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r11, [rbp - 152] # reload L17 from spill slot
    mov r10, r11 # assign L18
    mov r11, [rbp - 480] # tag L17 from tag-slot
    mov [rbp - 488], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r10, [rbp - 160] # reload L18 from spill slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 160] # reload L18 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 488] # tag L18 from tag-slot
    mov rcx, [rbp - 64] # reload L6 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 392] # tag L6 from tag-slot
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 496], rax # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r10, [rbp - 168] # reload L19 from spill slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov rsi, [rbp - 168] # reload L19 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 496] # tag L19 from tag-slot
    mov rcx, [rbp - 128] # reload L14 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 456] # tag L14 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 504], rax # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, [rbp - 176] # reload L20 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_center_bb6 # jump-if-zero -> else
    jmp .L62a9_rt_str_center_bb5 # jump -> then
.L62a9_rt_str_center_bb5:
    mov r10, [rbp - 160] # reload L18 from spill slot
    mov rsi, [rbp - 160] # reload L18 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 488] # tag L18 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 520], rax # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r10, r11 # assign L18
    mov r11, [rbp - 520] # tag L22 from tag-slot
    mov [rbp - 488], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    jmp .L62a9_rt_str_center_bb6 # branch
.L62a9_rt_str_center_bb6:
    mov r10, [rbp - 144] # reload L16 from spill slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 472] # tag L16 from tag-slot
    mov rcx, [rbp - 64] # reload L6 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 392] # tag L6 from tag-slot
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 528], rax # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 528] # tag L23 from tag-slot
    mov [rbp - 536], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 208] # reload L24 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 536] # tag L24 from tag-slot
    mov rcx, [rbp - 64] # reload L6 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 392] # tag L6 from tag-slot
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 544], rax # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r10, [rbp - 216] # reload L25 from spill slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov rsi, [rbp - 216] # reload L25 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 544] # tag L25 from tag-slot
    mov rcx, [rbp - 144] # reload L16 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 472] # tag L16 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 552], rax # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r10, [rbp - 224] # reload L26 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_center_bb8 # jump-if-zero -> else
    jmp .L62a9_rt_str_center_bb7 # jump -> then
.L62a9_rt_str_center_bb7:
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov rsi, [rbp - 208] # reload L24 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 536] # tag L24 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 568], rax # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r11, [rbp - 240] # reload L28 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 568] # tag L28 from tag-slot
    mov [rbp - 536], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    jmp .L62a9_rt_str_center_bb8 # branch
.L62a9_rt_str_center_bb8:
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 576], rax # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r11, [rbp - 248] # reload L29 from spill slot
    mov r10, r11 # assign L30
    mov r11, [rbp - 576] # tag L29 from tag-slot
    mov [rbp - 584], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r10, 0 # assign L31
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 592], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    jmp .L62a9_rt_str_center_bb9 # branch
.L62a9_rt_str_center_bb9:
    mov r10, [rbp - 264] # reload L31 from spill slot
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov rsi, [rbp - 264] # reload L31 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 592] # tag L31 from tag-slot
    mov rcx, [rbp - 160] # reload L18 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 488] # tag L18 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 600], rax # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r10, [rbp - 272] # reload L32 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_center_bb11 # jump-if-zero -> else
    jmp .L62a9_rt_str_center_bb10 # jump -> then
.L62a9_rt_str_center_bb10:
    mov rsi, [rbp - 256] # reload L30 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 584] # tag L30 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 360] # tag L2 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 608], rax # store tag L33
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 280], r10 # spill L33 to slot
    mov r10, [rbp - 264] # reload L31 from spill slot
    mov rsi, [rbp - 264] # reload L31 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 592] # tag L31 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 616], rax # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    mov r11, [rbp - 288] # reload L34 from spill slot
    mov r10, r11 # assign L31
    mov r11, [rbp - 616] # tag L34 from tag-slot
    mov [rbp - 592], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    jmp .L62a9_rt_str_center_bb9 # branch
.L62a9_rt_str_center_bb11:
    mov rsi, [rbp - 256] # reload L30 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 584] # tag L30 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 344] # tag L0 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 624], rax # store tag L35
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 296], r10 # spill L35 to slot
    mov r10, 0 # assign L36
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 632], r11 # store tag L36
    mov [rbp - 304], r10 # spill L36 to slot
    jmp .L62a9_rt_str_center_bb12 # branch
.L62a9_rt_str_center_bb12:
    mov r10, [rbp - 304] # reload L36 from spill slot
    mov r11, [rbp - 208] # reload L24 from spill slot
    mov rsi, [rbp - 304] # reload L36 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 632] # tag L36 from tag-slot
    mov rcx, [rbp - 208] # reload L24 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 536] # tag L24 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 640], rax # store tag L37
    mov [rbp - 312], r10 # spill L37 to slot
    mov r10, [rbp - 312] # reload L37 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_center_bb14 # jump-if-zero -> else
    jmp .L62a9_rt_str_center_bb13 # jump -> then
.L62a9_rt_str_center_bb13:
    mov rsi, [rbp - 256] # reload L30 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 584] # tag L30 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 360] # tag L2 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 648], rax # store tag L38
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 320], r10 # spill L38 to slot
    mov r10, [rbp - 304] # reload L36 from spill slot
    mov rsi, [rbp - 304] # reload L36 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 632] # tag L36 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 656], rax # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    mov r11, [rbp - 328] # reload L39 from spill slot
    mov r10, r11 # assign L36
    mov r11, [rbp - 656] # tag L39 from tag-slot
    mov [rbp - 632], r11 # store tag L36
    mov [rbp - 304], r10 # spill L36 to slot
    jmp .L62a9_rt_str_center_bb12 # branch
.L62a9_rt_str_center_bb14:
    mov rsi, [rbp - 256] # reload L30 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 584] # tag L30 from tag-slot
    lea rcx, [rip+.LCstr1] # hv arg payload: &str .LCstr1
    mov rdx, 3 # hv arg tag = TAG_STR
    call hexa_str_join # call hexa_str_join
    mov [rbp - 664], rax # store tag L40
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 336], r10 # spill L40 to slot
    mov rdx, [rbp - 336] # reload L40 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 664] # tag L40 from tag-slot
    add rsp, 624 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_to_upper
.hidden rt_str_to_upper
    .p2align 4
rt_str_to_upper:
    .loc 1 134 0
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
.L62a9_rt_str_to_upper_bb0:
    lea r12, [rip+.LCstr2] # assign L1
    mov r11, 3 # tag const_str = TAG_STR
    mov [rbp - 216], r11 # store tag L1
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 208] # tag L0 from tag-slot
    call hexa_len # call hexa_len
    mov r13, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 224], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 224] # tag L2 from tag-slot
    mov [rbp - 232], r11 # store tag L3
    call hexa_array_new # array_lit: new array
    mov r15, rdx # array_lit: capture new array payload
    mov [rbp - 240], rax # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 240] # tag L4 from tag-slot
    mov [rbp - 248], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, 0 # assign L6
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 256], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    jmp .L62a9_rt_str_to_upper_bb1 # branch
.L62a9_rt_str_to_upper_bb1:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 256] # tag L6 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 232] # tag L3 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 264], rax # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_to_upper_bb3 # jump-if-zero -> else
    jmp .L62a9_rt_str_to_upper_bb2 # jump -> then
.L62a9_rt_str_to_upper_bb2:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 208] # tag L0 from tag-slot
    mov rcx, [rbp - 64] # reload L6 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 256] # tag L6 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 272], rax # store tag L8
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 272] # tag L8 from tag-slot
    mov [rbp - 280], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 280] # tag L9 from tag-slot
    mov rcx, 97 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 288], rax # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_to_upper_bb5 # jump-if-zero -> else
    jmp .L62a9_rt_str_to_upper_bb4 # jump -> then
.L62a9_rt_str_to_upper_bb3:
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 248] # tag L5 from tag-slot
    lea rcx, [rip+.LCstr1] # hv arg payload: &str .LCstr1
    mov rdx, 3 # hv arg tag = TAG_STR
    call hexa_str_join # call hexa_str_join
    mov [rbp - 392], rax # store tag L23
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 200], r10 # spill L23 to slot
    mov rdx, [rbp - 200] # reload L23 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 392] # tag L23 from tag-slot
    add rsp, 352 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_to_upper_bb4:
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 280] # tag L9 from tag-slot
    mov rcx, 122 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 304], rax # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 304] # tag L12 from tag-slot
    mov [rbp - 296], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    jmp .L62a9_rt_str_to_upper_bb6 # branch
.L62a9_rt_str_to_upper_bb5:
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 288] # tag L10 from tag-slot
    mov [rbp - 296], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    jmp .L62a9_rt_str_to_upper_bb6 # branch
.L62a9_rt_str_to_upper_bb6:
    mov r10, [rbp - 104] # reload L11 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_to_upper_bb8 # jump-if-zero -> else
    jmp .L62a9_rt_str_to_upper_bb7 # jump -> then
.L62a9_rt_str_to_upper_bb7:
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 280] # tag L9 from tag-slot
    mov rcx, 97 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 320], rax # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 280] # tag L9 from tag-slot
    mov rcx, 97 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 328], rax # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 328] # tag L15 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 336], rax # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 216] # tag L1 from tag-slot
    mov rcx, [rbp - 128] # reload L14 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 320] # tag L14 from tag-slot
    mov r9, [rbp - 144] # reload L16 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 336] # tag L16 from tag-slot
    call hexa_str_substring # call hexa_str_substring
    mov [rbp - 344], rax # store tag L17
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 152], r10 # spill L17 to slot
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 248] # tag L5 from tag-slot
    mov rcx, [rbp - 152] # reload L17 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 344] # tag L17 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 352], rax # store tag L18
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 160], r10 # spill L18 to slot
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 352] # tag L18 from tag-slot
    mov [rbp - 312], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    jmp .L62a9_rt_str_to_upper_bb9 # branch
.L62a9_rt_str_to_upper_bb8:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 256] # tag L6 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 360], rax # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 208] # tag L0 from tag-slot
    mov rcx, [rbp - 64] # reload L6 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 256] # tag L6 from tag-slot
    mov r9, [rbp - 168] # reload L19 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 360] # tag L19 from tag-slot
    call hexa_str_substring # call hexa_str_substring
    mov [rbp - 368], rax # store tag L20
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 176], r10 # spill L20 to slot
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 248] # tag L5 from tag-slot
    mov rcx, [rbp - 176] # reload L20 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 368] # tag L20 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 376], rax # store tag L21
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 376] # tag L21 from tag-slot
    mov [rbp - 312], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    jmp .L62a9_rt_str_to_upper_bb9 # branch
.L62a9_rt_str_to_upper_bb9:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 256] # tag L6 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 384], rax # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 384] # tag L22 from tag-slot
    mov [rbp - 256], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    jmp .L62a9_rt_str_to_upper_bb1 # branch
    add rsp, 352 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_to_lower
.hidden rt_str_to_lower
    .p2align 4
rt_str_to_lower:
    .loc 1 151 0
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
.L62a9_rt_str_to_lower_bb0:
    lea r12, [rip+.LCstr3] # assign L1
    mov r11, 3 # tag const_str = TAG_STR
    mov [rbp - 216], r11 # store tag L1
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 208] # tag L0 from tag-slot
    call hexa_len # call hexa_len
    mov r13, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 224], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 224] # tag L2 from tag-slot
    mov [rbp - 232], r11 # store tag L3
    call hexa_array_new # array_lit: new array
    mov r15, rdx # array_lit: capture new array payload
    mov [rbp - 240], rax # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 240] # tag L4 from tag-slot
    mov [rbp - 248], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, 0 # assign L6
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 256], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    jmp .L62a9_rt_str_to_lower_bb1 # branch
.L62a9_rt_str_to_lower_bb1:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 256] # tag L6 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 232] # tag L3 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 264], rax # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_to_lower_bb3 # jump-if-zero -> else
    jmp .L62a9_rt_str_to_lower_bb2 # jump -> then
.L62a9_rt_str_to_lower_bb2:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 208] # tag L0 from tag-slot
    mov rcx, [rbp - 64] # reload L6 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 256] # tag L6 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 272], rax # store tag L8
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 272] # tag L8 from tag-slot
    mov [rbp - 280], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 280] # tag L9 from tag-slot
    mov rcx, 65 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 288], rax # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_to_lower_bb5 # jump-if-zero -> else
    jmp .L62a9_rt_str_to_lower_bb4 # jump -> then
.L62a9_rt_str_to_lower_bb3:
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 248] # tag L5 from tag-slot
    lea rcx, [rip+.LCstr1] # hv arg payload: &str .LCstr1
    mov rdx, 3 # hv arg tag = TAG_STR
    call hexa_str_join # call hexa_str_join
    mov [rbp - 392], rax # store tag L23
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 200], r10 # spill L23 to slot
    mov rdx, [rbp - 200] # reload L23 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 392] # tag L23 from tag-slot
    add rsp, 352 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_to_lower_bb4:
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 280] # tag L9 from tag-slot
    mov rcx, 90 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 304], rax # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 304] # tag L12 from tag-slot
    mov [rbp - 296], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    jmp .L62a9_rt_str_to_lower_bb6 # branch
.L62a9_rt_str_to_lower_bb5:
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 288] # tag L10 from tag-slot
    mov [rbp - 296], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    jmp .L62a9_rt_str_to_lower_bb6 # branch
.L62a9_rt_str_to_lower_bb6:
    mov r10, [rbp - 104] # reload L11 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_to_lower_bb8 # jump-if-zero -> else
    jmp .L62a9_rt_str_to_lower_bb7 # jump -> then
.L62a9_rt_str_to_lower_bb7:
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 280] # tag L9 from tag-slot
    mov rcx, 65 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 320], rax # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 280] # tag L9 from tag-slot
    mov rcx, 65 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 328], rax # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 328] # tag L15 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 336], rax # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 216] # tag L1 from tag-slot
    mov rcx, [rbp - 128] # reload L14 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 320] # tag L14 from tag-slot
    mov r9, [rbp - 144] # reload L16 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 336] # tag L16 from tag-slot
    call hexa_str_substring # call hexa_str_substring
    mov [rbp - 344], rax # store tag L17
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 152], r10 # spill L17 to slot
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 248] # tag L5 from tag-slot
    mov rcx, [rbp - 152] # reload L17 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 344] # tag L17 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 352], rax # store tag L18
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 160], r10 # spill L18 to slot
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 352] # tag L18 from tag-slot
    mov [rbp - 312], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    jmp .L62a9_rt_str_to_lower_bb9 # branch
.L62a9_rt_str_to_lower_bb8:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 256] # tag L6 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 360], rax # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 208] # tag L0 from tag-slot
    mov rcx, [rbp - 64] # reload L6 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 256] # tag L6 from tag-slot
    mov r9, [rbp - 168] # reload L19 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 360] # tag L19 from tag-slot
    call hexa_str_substring # call hexa_str_substring
    mov [rbp - 368], rax # store tag L20
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 176], r10 # spill L20 to slot
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 248] # tag L5 from tag-slot
    mov rcx, [rbp - 176] # reload L20 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 368] # tag L20 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 376], rax # store tag L21
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 376] # tag L21 from tag-slot
    mov [rbp - 312], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    jmp .L62a9_rt_str_to_lower_bb9 # branch
.L62a9_rt_str_to_lower_bb9:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 256] # tag L6 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 384], rax # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 384] # tag L22 from tag-slot
    mov [rbp - 256], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    jmp .L62a9_rt_str_to_lower_bb1 # branch
    add rsp, 352 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_trim
.hidden rt_str_trim
    .p2align 4
rt_str_trim:
    .loc 1 170 0
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
.L62a9_rt_str_trim_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 264] # tag L0 from tag-slot
    call hexa_len # call hexa_len
    mov r12, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 272], r11 # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 272] # tag L1 from tag-slot
    mov [rbp - 280], r11 # store tag L2
    mov r14, 0 # assign L3
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 288], r11 # store tag L3
    jmp .L62a9_rt_str_trim_bb1 # branch
.L62a9_rt_str_trim_bb1:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 288] # tag L3 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 280] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r15, rdx # binop <: capture bool payload
    mov [rbp - 296], rax # store tag L4
    test r15, r15 # br_cond test
    jz .L62a9_rt_str_trim_bb3 # jump-if-zero -> else
    jmp .L62a9_rt_str_trim_bb2 # jump -> then
.L62a9_rt_str_trim_bb2:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 264] # tag L0 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 288] # tag L3 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 304], rax # store tag L5
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 304] # tag L5 from tag-slot
    mov [rbp - 312], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 312] # tag L6 from tag-slot
    mov rcx, 32 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 320], rax # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_trim_bb5 # jump-if-zero -> else
    jmp .L62a9_rt_str_trim_bb4 # jump -> then
.L62a9_rt_str_trim_bb3:
    mov r10, r13 # assign L16
    mov r11, [rbp - 280] # tag L2 from tag-slot
    mov [rbp - 392], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    jmp .L62a9_rt_str_trim_bb16 # branch
.L62a9_rt_str_trim_bb4:
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 320] # tag L7 from tag-slot
    mov [rbp - 328], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    jmp .L62a9_rt_str_trim_bb6 # branch
.L62a9_rt_str_trim_bb5:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 312] # tag L6 from tag-slot
    mov rcx, 9 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 336], rax # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 336] # tag L9 from tag-slot
    mov [rbp - 328], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    jmp .L62a9_rt_str_trim_bb6 # branch
.L62a9_rt_str_trim_bb6:
    mov r10, [rbp - 80] # reload L8 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_trim_bb8 # jump-if-zero -> else
    jmp .L62a9_rt_str_trim_bb7 # jump -> then
.L62a9_rt_str_trim_bb7:
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L10
    mov r11, [rbp - 328] # tag L8 from tag-slot
    mov [rbp - 344], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    jmp .L62a9_rt_str_trim_bb9 # branch
.L62a9_rt_str_trim_bb8:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 312] # tag L6 from tag-slot
    mov rcx, 10 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 352], rax # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L10
    mov r11, [rbp - 352] # tag L11 from tag-slot
    mov [rbp - 344], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    jmp .L62a9_rt_str_trim_bb9 # branch
.L62a9_rt_str_trim_bb9:
    mov r10, [rbp - 96] # reload L10 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_trim_bb11 # jump-if-zero -> else
    jmp .L62a9_rt_str_trim_bb10 # jump -> then
.L62a9_rt_str_trim_bb10:
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 344] # tag L10 from tag-slot
    mov [rbp - 360], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    jmp .L62a9_rt_str_trim_bb12 # branch
.L62a9_rt_str_trim_bb11:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 312] # tag L6 from tag-slot
    mov rcx, 13 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 368], rax # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 368] # tag L13 from tag-slot
    mov [rbp - 360], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    jmp .L62a9_rt_str_trim_bb12 # branch
.L62a9_rt_str_trim_bb12:
    mov r10, [rbp - 112] # reload L12 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_trim_bb14 # jump-if-zero -> else
    jmp .L62a9_rt_str_trim_bb13 # jump -> then
.L62a9_rt_str_trim_bb13:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 288] # tag L3 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 384], rax # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 384] # tag L15 from tag-slot
    mov [rbp - 288], r11 # store tag L3
    jmp .L62a9_rt_str_trim_bb15 # branch
.L62a9_rt_str_trim_bb14:
    jmp .L62a9_rt_str_trim_bb3 # branch
.L62a9_rt_str_trim_bb15:
    jmp .L62a9_rt_str_trim_bb1 # branch
.L62a9_rt_str_trim_bb16:
    mov r10, [rbp - 144] # reload L16 from spill slot
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 392] # tag L16 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 288] # tag L3 from tag-slot
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 400], rax # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_trim_bb18 # jump-if-zero -> else
    jmp .L62a9_rt_str_trim_bb17 # jump -> then
.L62a9_rt_str_trim_bb17:
    mov r10, [rbp - 144] # reload L16 from spill slot
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 392] # tag L16 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 408], rax # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 264] # tag L0 from tag-slot
    mov rcx, [rbp - 160] # reload L18 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 408] # tag L18 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 416], rax # store tag L19
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 168], r10 # spill L19 to slot
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov r10, r11 # assign L20
    mov r11, [rbp - 416] # tag L19 from tag-slot
    mov [rbp - 424], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, [rbp - 176] # reload L20 from spill slot
    mov rsi, [rbp - 176] # reload L20 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 424] # tag L20 from tag-slot
    mov rcx, 32 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 432], rax # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r10, [rbp - 184] # reload L21 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_trim_bb20 # jump-if-zero -> else
    jmp .L62a9_rt_str_trim_bb19 # jump -> then
.L62a9_rt_str_trim_bb18:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 264] # tag L0 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 288] # tag L3 from tag-slot
    mov r9, [rbp - 144] # reload L16 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 392] # tag L16 from tag-slot
    call hexa_str_substring # call hexa_str_substring
    mov [rbp - 504], rax # store tag L30
    mov r10, rdx # hv: unbox call result (rdx)
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
.L62a9_rt_str_trim_bb19:
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 432] # tag L21 from tag-slot
    mov [rbp - 440], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    jmp .L62a9_rt_str_trim_bb21 # branch
.L62a9_rt_str_trim_bb20:
    mov r10, [rbp - 176] # reload L20 from spill slot
    mov rsi, [rbp - 176] # reload L20 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 424] # tag L20 from tag-slot
    mov rcx, 9 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 448], rax # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 448] # tag L23 from tag-slot
    mov [rbp - 440], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    jmp .L62a9_rt_str_trim_bb21 # branch
.L62a9_rt_str_trim_bb21:
    mov r10, [rbp - 192] # reload L22 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_trim_bb23 # jump-if-zero -> else
    jmp .L62a9_rt_str_trim_bb22 # jump -> then
.L62a9_rt_str_trim_bb22:
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 440] # tag L22 from tag-slot
    mov [rbp - 456], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    jmp .L62a9_rt_str_trim_bb24 # branch
.L62a9_rt_str_trim_bb23:
    mov r10, [rbp - 176] # reload L20 from spill slot
    mov rsi, [rbp - 176] # reload L20 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 424] # tag L20 from tag-slot
    mov rcx, 10 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 464], rax # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r11, [rbp - 216] # reload L25 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 464] # tag L25 from tag-slot
    mov [rbp - 456], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    jmp .L62a9_rt_str_trim_bb24 # branch
.L62a9_rt_str_trim_bb24:
    mov r10, [rbp - 208] # reload L24 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_trim_bb26 # jump-if-zero -> else
    jmp .L62a9_rt_str_trim_bb25 # jump -> then
.L62a9_rt_str_trim_bb25:
    mov r11, [rbp - 208] # reload L24 from spill slot
    mov r10, r11 # assign L26
    mov r11, [rbp - 456] # tag L24 from tag-slot
    mov [rbp - 472], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    jmp .L62a9_rt_str_trim_bb27 # branch
.L62a9_rt_str_trim_bb26:
    mov r10, [rbp - 176] # reload L20 from spill slot
    mov rsi, [rbp - 176] # reload L20 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 424] # tag L20 from tag-slot
    mov rcx, 13 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 480], rax # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov r11, [rbp - 232] # reload L27 from spill slot
    mov r10, r11 # assign L26
    mov r11, [rbp - 480] # tag L27 from tag-slot
    mov [rbp - 472], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    jmp .L62a9_rt_str_trim_bb27 # branch
.L62a9_rt_str_trim_bb27:
    mov r10, [rbp - 224] # reload L26 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_trim_bb29 # jump-if-zero -> else
    jmp .L62a9_rt_str_trim_bb28 # jump -> then
.L62a9_rt_str_trim_bb28:
    mov r10, [rbp - 144] # reload L16 from spill slot
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 392] # tag L16 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 496], rax # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r11, [rbp - 248] # reload L29 from spill slot
    mov r10, r11 # assign L16
    mov r11, [rbp - 496] # tag L29 from tag-slot
    mov [rbp - 392], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    jmp .L62a9_rt_str_trim_bb30 # branch
.L62a9_rt_str_trim_bb29:
    jmp .L62a9_rt_str_trim_bb18 # branch
.L62a9_rt_str_trim_bb30:
    jmp .L62a9_rt_str_trim_bb16 # branch
    add rsp, 464 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_trim_start
.hidden rt_str_trim_start
    .p2align 4
rt_str_trim_start:
    .loc 1 196 0
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
.L62a9_rt_str_trim_start_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 152] # tag L0 from tag-slot
    call hexa_len # call hexa_len
    mov r12, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 160], r11 # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 160] # tag L1 from tag-slot
    mov [rbp - 168], r11 # store tag L2
    mov r14, 0 # assign L3
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 176], r11 # store tag L3
    jmp .L62a9_rt_str_trim_start_bb1 # branch
.L62a9_rt_str_trim_start_bb1:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 176] # tag L3 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 168] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r15, rdx # binop <: capture bool payload
    mov [rbp - 184], rax # store tag L4
    test r15, r15 # br_cond test
    jz .L62a9_rt_str_trim_start_bb3 # jump-if-zero -> else
    jmp .L62a9_rt_str_trim_start_bb2 # jump -> then
.L62a9_rt_str_trim_start_bb2:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 152] # tag L0 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 176] # tag L3 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 192], rax # store tag L5
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 192] # tag L5 from tag-slot
    mov [rbp - 200], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 200] # tag L6 from tag-slot
    mov rcx, 32 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 208], rax # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_trim_start_bb5 # jump-if-zero -> else
    jmp .L62a9_rt_str_trim_start_bb4 # jump -> then
.L62a9_rt_str_trim_start_bb3:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 152] # tag L0 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 176] # tag L3 from tag-slot
    mov r9, r13 # hv arg payload
    mov r8, [rbp - 168] # tag L2 from tag-slot
    call hexa_str_substring # call hexa_str_substring
    mov [rbp - 280], rax # store tag L16
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 144], r10 # spill L16 to slot
    mov rdx, [rbp - 144] # reload L16 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 280] # tag L16 from tag-slot
    add rsp, 240 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_trim_start_bb4:
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 208] # tag L7 from tag-slot
    mov [rbp - 216], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    jmp .L62a9_rt_str_trim_start_bb6 # branch
.L62a9_rt_str_trim_start_bb5:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 200] # tag L6 from tag-slot
    mov rcx, 9 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 224], rax # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 224] # tag L9 from tag-slot
    mov [rbp - 216], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    jmp .L62a9_rt_str_trim_start_bb6 # branch
.L62a9_rt_str_trim_start_bb6:
    mov r10, [rbp - 80] # reload L8 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_trim_start_bb8 # jump-if-zero -> else
    jmp .L62a9_rt_str_trim_start_bb7 # jump -> then
.L62a9_rt_str_trim_start_bb7:
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L10
    mov r11, [rbp - 216] # tag L8 from tag-slot
    mov [rbp - 232], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    jmp .L62a9_rt_str_trim_start_bb9 # branch
.L62a9_rt_str_trim_start_bb8:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 200] # tag L6 from tag-slot
    mov rcx, 10 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 240], rax # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L10
    mov r11, [rbp - 240] # tag L11 from tag-slot
    mov [rbp - 232], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    jmp .L62a9_rt_str_trim_start_bb9 # branch
.L62a9_rt_str_trim_start_bb9:
    mov r10, [rbp - 96] # reload L10 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_trim_start_bb11 # jump-if-zero -> else
    jmp .L62a9_rt_str_trim_start_bb10 # jump -> then
.L62a9_rt_str_trim_start_bb10:
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 232] # tag L10 from tag-slot
    mov [rbp - 248], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    jmp .L62a9_rt_str_trim_start_bb12 # branch
.L62a9_rt_str_trim_start_bb11:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 200] # tag L6 from tag-slot
    mov rcx, 13 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 256], rax # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 256] # tag L13 from tag-slot
    mov [rbp - 248], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    jmp .L62a9_rt_str_trim_start_bb12 # branch
.L62a9_rt_str_trim_start_bb12:
    mov r10, [rbp - 112] # reload L12 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_trim_start_bb14 # jump-if-zero -> else
    jmp .L62a9_rt_str_trim_start_bb13 # jump -> then
.L62a9_rt_str_trim_start_bb13:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 176] # tag L3 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 272], rax # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 272] # tag L15 from tag-slot
    mov [rbp - 176], r11 # store tag L3
    jmp .L62a9_rt_str_trim_start_bb15 # branch
.L62a9_rt_str_trim_start_bb14:
    jmp .L62a9_rt_str_trim_start_bb3 # branch
.L62a9_rt_str_trim_start_bb15:
    jmp .L62a9_rt_str_trim_start_bb1 # branch
    add rsp, 240 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_trim_end
.hidden rt_str_trim_end
    .p2align 4
rt_str_trim_end:
    .loc 1 210 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 256 # prologue: alloc spill frame
    mov [rbp - 160], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.L62a9_rt_str_trim_end_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 160] # tag L0 from tag-slot
    call hexa_len # call hexa_len
    mov r12, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 168], r11 # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 168] # tag L1 from tag-slot
    mov [rbp - 176], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 176] # tag L2 from tag-slot
    mov [rbp - 184], r11 # store tag L3
    jmp .L62a9_rt_str_trim_end_bb1 # branch
.L62a9_rt_str_trim_end_bb1:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 184] # tag L3 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r15, rdx # binop >: capture bool payload
    mov [rbp - 192], rax # store tag L4
    test r15, r15 # br_cond test
    jz .L62a9_rt_str_trim_end_bb3 # jump-if-zero -> else
    jmp .L62a9_rt_str_trim_end_bb2 # jump -> then
.L62a9_rt_str_trim_end_bb2:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 184] # tag L3 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 200], rax # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 160] # tag L0 from tag-slot
    mov rcx, [rbp - 56] # reload L5 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 200] # tag L5 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 208], rax # store tag L6
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 208] # tag L6 from tag-slot
    mov [rbp - 216], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 216] # tag L7 from tag-slot
    mov rcx, 32 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 224], rax # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_trim_end_bb5 # jump-if-zero -> else
    jmp .L62a9_rt_str_trim_end_bb4 # jump -> then
.L62a9_rt_str_trim_end_bb3:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 160] # tag L0 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    mov r9, r14 # hv arg payload
    mov r8, [rbp - 184] # tag L3 from tag-slot
    call hexa_str_substring # call hexa_str_substring
    mov [rbp - 296], rax # store tag L17
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 152], r10 # spill L17 to slot
    mov rdx, [rbp - 152] # reload L17 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 296] # tag L17 from tag-slot
    add rsp, 256 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_trim_end_bb4:
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 224] # tag L8 from tag-slot
    mov [rbp - 232], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    jmp .L62a9_rt_str_trim_end_bb6 # branch
.L62a9_rt_str_trim_end_bb5:
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 216] # tag L7 from tag-slot
    mov rcx, 9 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 240], rax # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 240] # tag L10 from tag-slot
    mov [rbp - 232], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    jmp .L62a9_rt_str_trim_end_bb6 # branch
.L62a9_rt_str_trim_end_bb6:
    mov r10, [rbp - 88] # reload L9 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_trim_end_bb8 # jump-if-zero -> else
    jmp .L62a9_rt_str_trim_end_bb7 # jump -> then
.L62a9_rt_str_trim_end_bb7:
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 232] # tag L9 from tag-slot
    mov [rbp - 248], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    jmp .L62a9_rt_str_trim_end_bb9 # branch
.L62a9_rt_str_trim_end_bb8:
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 216] # tag L7 from tag-slot
    mov rcx, 10 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 256], rax # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 256] # tag L12 from tag-slot
    mov [rbp - 248], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    jmp .L62a9_rt_str_trim_end_bb9 # branch
.L62a9_rt_str_trim_end_bb9:
    mov r10, [rbp - 104] # reload L11 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_trim_end_bb11 # jump-if-zero -> else
    jmp .L62a9_rt_str_trim_end_bb10 # jump -> then
.L62a9_rt_str_trim_end_bb10:
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 248] # tag L11 from tag-slot
    mov [rbp - 264], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    jmp .L62a9_rt_str_trim_end_bb12 # branch
.L62a9_rt_str_trim_end_bb11:
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 216] # tag L7 from tag-slot
    mov rcx, 13 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 272], rax # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 272] # tag L14 from tag-slot
    mov [rbp - 264], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    jmp .L62a9_rt_str_trim_end_bb12 # branch
.L62a9_rt_str_trim_end_bb12:
    mov r10, [rbp - 120] # reload L13 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_trim_end_bb14 # jump-if-zero -> else
    jmp .L62a9_rt_str_trim_end_bb13 # jump -> then
.L62a9_rt_str_trim_end_bb13:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 184] # tag L3 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 288], rax # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r10, [rbp - 144] # reload L16 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 288] # tag L16 from tag-slot
    mov [rbp - 184], r11 # store tag L3
    jmp .L62a9_rt_str_trim_end_bb15 # branch
.L62a9_rt_str_trim_end_bb14:
    jmp .L62a9_rt_str_trim_end_bb3 # branch
.L62a9_rt_str_trim_end_bb15:
    jmp .L62a9_rt_str_trim_end_bb1 # branch
    add rsp, 256 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_starts_with_b
.hidden rt_str_starts_with_b
    .p2align 4
rt_str_starts_with_b:
    .loc 1 233 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 208 # prologue: alloc spill frame
    mov [rbp - 136], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 144], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L62a9_rt_str_starts_with_b_bb0:
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 144] # tag L1 from tag-slot
    call hexa_len # call hexa_len
    mov r13, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 152], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 152] # tag L2 from tag-slot
    mov [rbp - 160], r11 # store tag L3
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 136] # tag L0 from tag-slot
    call hexa_len # call hexa_len
    mov r15, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 168], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 168] # tag L4 from tag-slot
    mov [rbp - 176], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 160] # tag L3 from tag-slot
    mov rcx, [rbp - 56] # reload L5 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 176] # tag L5 from tag-slot
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 184], rax # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_starts_with_b_bb2 # jump-if-zero -> else
    jmp .L62a9_rt_str_starts_with_b_bb1 # jump -> then
.L62a9_rt_str_starts_with_b_bb1:
    mov rdx, 0 # hv arg payload
    mov rax, 2 # tag const_bool = TAG_BOOL
    add rsp, 208 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_starts_with_b_bb2:
    mov r10, 0 # assign L8
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 200], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    jmp .L62a9_rt_str_starts_with_b_bb3 # branch
.L62a9_rt_str_starts_with_b_bb3:
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 200] # tag L8 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 160] # tag L3 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 208], rax # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_starts_with_b_bb5 # jump-if-zero -> else
    jmp .L62a9_rt_str_starts_with_b_bb4 # jump -> then
.L62a9_rt_str_starts_with_b_bb4:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 136] # tag L0 from tag-slot
    mov rcx, [rbp - 80] # reload L8 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 200] # tag L8 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 216], rax # store tag L10
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 96], r10 # spill L10 to slot
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 144] # tag L1 from tag-slot
    mov rcx, [rbp - 80] # reload L8 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 200] # tag L8 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 224], rax # store tag L11
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov rsi, [rbp - 96] # reload L10 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 216] # tag L10 from tag-slot
    mov rcx, [rbp - 104] # reload L11 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 224] # tag L11 from tag-slot
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 232], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_starts_with_b_bb7 # jump-if-zero -> else
    jmp .L62a9_rt_str_starts_with_b_bb6 # jump -> then
.L62a9_rt_str_starts_with_b_bb5:
    mov rdx, 1 # hv arg payload
    mov rax, 2 # tag const_bool = TAG_BOOL
    add rsp, 208 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_starts_with_b_bb6:
    mov rdx, 0 # hv arg payload
    mov rax, 2 # tag const_bool = TAG_BOOL
    add rsp, 208 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_starts_with_b_bb7:
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 200] # tag L8 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 248], rax # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 248] # tag L14 from tag-slot
    mov [rbp - 200], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    jmp .L62a9_rt_str_starts_with_b_bb3 # branch
    add rsp, 208 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_ends_with_b
.hidden rt_str_ends_with_b
    .p2align 4
rt_str_ends_with_b:
    .loc 1 245 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 256 # prologue: alloc spill frame
    mov [rbp - 160], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 168], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L62a9_rt_str_ends_with_b_bb0:
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 168] # tag L1 from tag-slot
    call hexa_len # call hexa_len
    mov r13, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 176], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 176] # tag L2 from tag-slot
    mov [rbp - 184], r11 # store tag L3
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 160] # tag L0 from tag-slot
    call hexa_len # call hexa_len
    mov r15, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 192], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 192] # tag L4 from tag-slot
    mov [rbp - 200], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 184] # tag L3 from tag-slot
    mov rcx, [rbp - 56] # reload L5 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 200] # tag L5 from tag-slot
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 208], rax # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_ends_with_b_bb2 # jump-if-zero -> else
    jmp .L62a9_rt_str_ends_with_b_bb1 # jump -> then
.L62a9_rt_str_ends_with_b_bb1:
    mov rdx, 0 # hv arg payload
    mov rax, 2 # tag const_bool = TAG_BOOL
    add rsp, 256 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_ends_with_b_bb2:
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 200] # tag L5 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 184] # tag L3 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 224], rax # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 224] # tag L8 from tag-slot
    mov [rbp - 232], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, 0 # assign L10
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 240], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    jmp .L62a9_rt_str_ends_with_b_bb3 # branch
.L62a9_rt_str_ends_with_b_bb3:
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov rsi, [rbp - 96] # reload L10 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 240] # tag L10 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 184] # tag L3 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 248], rax # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 104] # reload L11 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_ends_with_b_bb5 # jump-if-zero -> else
    jmp .L62a9_rt_str_ends_with_b_bb4 # jump -> then
.L62a9_rt_str_ends_with_b_bb4:
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 232] # tag L9 from tag-slot
    mov rcx, [rbp - 96] # reload L10 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 240] # tag L10 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 256], rax # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 160] # tag L0 from tag-slot
    mov rcx, [rbp - 112] # reload L12 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 256] # tag L12 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 264], rax # store tag L13
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 120], r10 # spill L13 to slot
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 168] # tag L1 from tag-slot
    mov rcx, [rbp - 96] # reload L10 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 240] # tag L10 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 272], rax # store tag L14
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 128], r10 # spill L14 to slot
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 264] # tag L13 from tag-slot
    mov rcx, [rbp - 128] # reload L14 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 272] # tag L14 from tag-slot
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 280], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_ends_with_b_bb7 # jump-if-zero -> else
    jmp .L62a9_rt_str_ends_with_b_bb6 # jump -> then
.L62a9_rt_str_ends_with_b_bb5:
    mov rdx, 1 # hv arg payload
    mov rax, 2 # tag const_bool = TAG_BOOL
    add rsp, 256 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_ends_with_b_bb6:
    mov rdx, 0 # hv arg payload
    mov rax, 2 # tag const_bool = TAG_BOOL
    add rsp, 256 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_ends_with_b_bb7:
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov rsi, [rbp - 96] # reload L10 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 240] # tag L10 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 296], rax # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r11, [rbp - 152] # reload L17 from spill slot
    mov r10, r11 # assign L10
    mov r11, [rbp - 296] # tag L17 from tag-slot
    mov [rbp - 240], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    jmp .L62a9_rt_str_ends_with_b_bb3 # branch
    add rsp, 256 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_contains_b
.hidden rt_str_contains_b
    .p2align 4
rt_str_contains_b:
    .loc 1 258 0
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
.L62a9_rt_str_contains_b_bb0:
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
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 248] # tag L5 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 256], rax # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_contains_b_bb2 # jump-if-zero -> else
    jmp .L62a9_rt_str_contains_b_bb1 # jump -> then
.L62a9_rt_str_contains_b_bb1:
    mov rdx, 1 # hv arg payload
    mov rax, 2 # tag const_bool = TAG_BOOL
    add rsp, 352 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_contains_b_bb2:
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 248] # tag L5 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 232] # tag L3 from tag-slot
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 272], rax # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_contains_b_bb4 # jump-if-zero -> else
    jmp .L62a9_rt_str_contains_b_bb3 # jump -> then
.L62a9_rt_str_contains_b_bb3:
    mov rdx, 0 # hv arg payload
    mov rax, 2 # tag const_bool = TAG_BOOL
    add rsp, 352 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_contains_b_bb4:
    mov r10, 0 # assign L10
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 288], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    jmp .L62a9_rt_str_contains_b_bb5 # branch
.L62a9_rt_str_contains_b_bb5:
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov rsi, [rbp - 96] # reload L10 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 288] # tag L10 from tag-slot
    mov rcx, [rbp - 56] # reload L5 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 248] # tag L5 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 296], rax # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov rsi, [rbp - 104] # reload L11 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 296] # tag L11 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 232] # tag L3 from tag-slot
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 304], rax # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_contains_b_bb7 # jump-if-zero -> else
    jmp .L62a9_rt_str_contains_b_bb6 # jump -> then
.L62a9_rt_str_contains_b_bb6:
    mov r10, 0 # assign L13
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 312], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, 1 # assign L14
    mov r11, 2 # tag const_bool = TAG_BOOL
    mov [rbp - 320], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    jmp .L62a9_rt_str_contains_b_bb8 # branch
.L62a9_rt_str_contains_b_bb7:
    mov rdx, 0 # hv arg payload
    mov rax, 2 # tag const_bool = TAG_BOOL
    add rsp, 352 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_contains_b_bb8:
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 312] # tag L13 from tag-slot
    mov rcx, [rbp - 56] # reload L5 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 248] # tag L5 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 328], rax # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_contains_b_bb10 # jump-if-zero -> else
    jmp .L62a9_rt_str_contains_b_bb9 # jump -> then
.L62a9_rt_str_contains_b_bb9:
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov rsi, [rbp - 96] # reload L10 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 288] # tag L10 from tag-slot
    mov rcx, [rbp - 120] # reload L13 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 312] # tag L13 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 336], rax # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 208] # tag L0 from tag-slot
    mov rcx, [rbp - 144] # reload L16 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 336] # tag L16 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 344], rax # store tag L17
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 152], r10 # spill L17 to slot
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 216] # tag L1 from tag-slot
    mov rcx, [rbp - 120] # reload L13 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 312] # tag L13 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 352], rax # store tag L18
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 160], r10 # spill L18 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov rsi, [rbp - 152] # reload L17 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 344] # tag L17 from tag-slot
    mov rcx, [rbp - 160] # reload L18 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 352] # tag L18 from tag-slot
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 360], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r10, [rbp - 168] # reload L19 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_contains_b_bb12 # jump-if-zero -> else
    jmp .L62a9_rt_str_contains_b_bb11 # jump -> then
.L62a9_rt_str_contains_b_bb10:
    mov r10, [rbp - 128] # reload L14 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_contains_b_bb15 # jump-if-zero -> else
    jmp .L62a9_rt_str_contains_b_bb14 # jump -> then
.L62a9_rt_str_contains_b_bb11:
    mov r10, 0 # assign L14
    mov r11, 2 # tag const_bool = TAG_BOOL
    mov [rbp - 320], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 248] # tag L5 from tag-slot
    mov [rbp - 312], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    jmp .L62a9_rt_str_contains_b_bb13 # branch
.L62a9_rt_str_contains_b_bb12:
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 312] # tag L13 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 376], rax # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 376] # tag L21 from tag-slot
    mov [rbp - 312], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    jmp .L62a9_rt_str_contains_b_bb13 # branch
.L62a9_rt_str_contains_b_bb13:
    jmp .L62a9_rt_str_contains_b_bb8 # branch
.L62a9_rt_str_contains_b_bb14:
    mov rdx, 1 # hv arg payload
    mov rax, 2 # tag const_bool = TAG_BOOL
    add rsp, 352 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_contains_b_bb15:
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov rsi, [rbp - 96] # reload L10 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 288] # tag L10 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 392], rax # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L10
    mov r11, [rbp - 392] # tag L23 from tag-slot
    mov [rbp - 288], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    jmp .L62a9_rt_str_contains_b_bb5 # branch
    add rsp, 352 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_from_int
.hidden rt_str_from_int
    .p2align 4
rt_str_from_int:
    .loc 1 294 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 624 # prologue: alloc spill frame
    mov [rbp - 344], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.L62a9_rt_str_from_int_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 344] # tag L0 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r12, rdx # binop ==: capture bool payload
    mov [rbp - 352], rax # store tag L1
    test r12, r12 # br_cond test
    jz .L62a9_rt_str_from_int_bb2 # jump-if-zero -> else
    jmp .L62a9_rt_str_from_int_bb1 # jump -> then
.L62a9_rt_str_from_int_bb1:
    lea rdx, [rip+.LCstr4] # hv arg payload: &str .LCstr4
    mov rax, 3 # hv arg tag = TAG_STR
    add rsp, 624 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L62a9_rt_str_from_int_bb2:
    lea r14, [rip+.LCstr5] # assign L3
    mov r11, 3 # tag const_str = TAG_STR
    mov [rbp - 368], r11 # store tag L3
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 344] # tag L0 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r15, rdx # binop <: capture bool payload
    mov [rbp - 376], rax # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 376] # tag L4 from tag-slot
    mov [rbp - 384], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 392], rax # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 392] # tag L6 from tag-slot
    mov [rbp - 400], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, rbx # assign L8
    mov r11, [rbp - 344] # tag L0 from tag-slot
    mov [rbp - 408], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_from_int_bb4 # jump-if-zero -> else
    jmp .L62a9_rt_str_from_int_bb3 # jump -> then
.L62a9_rt_str_from_int_bb3:
    jmp .L62a9_rt_str_from_int_bb5 # branch
.L62a9_rt_str_from_int_bb4:
    jmp .L62a9_rt_str_from_int_bb10 # branch
.L62a9_rt_str_from_int_bb5:
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 408] # tag L8 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 424], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_from_int_bb7 # jump-if-zero -> else
    jmp .L62a9_rt_str_from_int_bb6 # jump -> then
.L62a9_rt_str_from_int_bb6:
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 408] # tag L8 from tag-slot
    mov rcx, 10 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mod # binop %: tag-dispatch hexa_mod
    mov r10, rdx # binop %: capture result payload
    mov [rbp - 432], rax # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    nop # unhandled stmt kind unop
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 440] # tag L12 from tag-slot
    mov [rbp - 448], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 448] # tag L13 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 456], rax # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r10, [rbp - 128] # reload L14 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_from_int_bb9 # jump-if-zero -> else
    jmp .L62a9_rt_str_from_int_bb8 # jump -> then
.L62a9_rt_str_from_int_bb7:
    jmp .L62a9_rt_str_from_int_bb13 # branch
.L62a9_rt_str_from_int_bb8:
    nop # unhandled stmt kind unop
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 472] # tag L16 from tag-slot
    mov [rbp - 448], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    jmp .L62a9_rt_str_from_int_bb9 # branch
.L62a9_rt_str_from_int_bb9:
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 448] # tag L13 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 480], rax # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 368] # tag L3 from tag-slot
    mov rcx, [rbp - 120] # reload L13 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 448] # tag L13 from tag-slot
    mov r9, [rbp - 152] # reload L17 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 480] # tag L17 from tag-slot
    call hexa_str_substring # call hexa_str_substring
    mov [rbp - 488], rax # store tag L18
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 160], r10 # spill L18 to slot
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 400] # tag L7 from tag-slot
    mov rcx, [rbp - 160] # reload L18 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 488] # tag L18 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 496], rax # store tag L19
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 168], r10 # spill L19 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 408] # tag L8 from tag-slot
    mov rcx, 10 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 504], rax # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r11, [rbp - 176] # reload L20 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 504] # tag L20 from tag-slot
    mov [rbp - 408], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    jmp .L62a9_rt_str_from_int_bb5 # branch
.L62a9_rt_str_from_int_bb10:
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 408] # tag L8 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 512], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r10, [rbp - 184] # reload L21 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_from_int_bb12 # jump-if-zero -> else
    jmp .L62a9_rt_str_from_int_bb11 # jump -> then
.L62a9_rt_str_from_int_bb11:
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 408] # tag L8 from tag-slot
    mov rcx, 10 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mod # binop %: tag-dispatch hexa_mod
    mov r10, rdx # binop %: capture result payload
    mov [rbp - 520], rax # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r10, r11 # assign L23
    mov r11, [rbp - 520] # tag L22 from tag-slot
    mov [rbp - 528], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r10, [rbp - 200] # reload L23 from spill slot
    mov rsi, [rbp - 200] # reload L23 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 528] # tag L23 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 536], rax # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 368] # tag L3 from tag-slot
    mov rcx, [rbp - 200] # reload L23 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 528] # tag L23 from tag-slot
    mov r9, [rbp - 208] # reload L24 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 536] # tag L24 from tag-slot
    call hexa_str_substring # call hexa_str_substring
    mov [rbp - 544], rax # store tag L25
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 216], r10 # spill L25 to slot
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 400] # tag L7 from tag-slot
    mov rcx, [rbp - 216] # reload L25 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 544] # tag L25 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 552], rax # store tag L26
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 224], r10 # spill L26 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 408] # tag L8 from tag-slot
    mov rcx, 10 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 560], rax # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov r11, [rbp - 232] # reload L27 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 560] # tag L27 from tag-slot
    mov [rbp - 408], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    jmp .L62a9_rt_str_from_int_bb10 # branch
.L62a9_rt_str_from_int_bb12:
    jmp .L62a9_rt_str_from_int_bb13 # branch
.L62a9_rt_str_from_int_bb13:
    call hexa_array_new # array_lit: new array
    mov r10, rdx # array_lit: capture new array payload
    mov [rbp - 568], rax # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r11, [rbp - 240] # reload L28 from spill slot
    mov r10, r11 # assign L29
    mov r11, [rbp - 568] # tag L28 from tag-slot
    mov [rbp - 576], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_from_int_bb15 # jump-if-zero -> else
    jmp .L62a9_rt_str_from_int_bb14 # jump -> then
.L62a9_rt_str_from_int_bb14:
    mov rsi, [rbp - 248] # reload L29 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 576] # tag L29 from tag-slot
    lea rcx, [rip+.LCstr6] # hv arg payload: &str .LCstr6
    mov rdx, 3 # hv arg tag = TAG_STR
    call hexa_array_push # call hexa_array_push
    mov [rbp - 592], rax # store tag L31
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 264], r10 # spill L31 to slot
    jmp .L62a9_rt_str_from_int_bb15 # branch
.L62a9_rt_str_from_int_bb15:
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 400] # tag L7 from tag-slot
    call hexa_len # call hexa_len
    mov r10, rax # hv: unbox call result (rax)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 600], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r11, [rbp - 272] # reload L32 from spill slot
    mov r10, r11 # assign L33
    mov r11, [rbp - 600] # tag L32 from tag-slot
    mov [rbp - 608], r11 # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r10, [rbp - 280] # reload L33 from spill slot
    mov rsi, [rbp - 280] # reload L33 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 608] # tag L33 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 616], rax # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    mov r11, [rbp - 288] # reload L34 from spill slot
    mov r10, r11 # assign L35
    mov r11, [rbp - 616] # tag L34 from tag-slot
    mov [rbp - 624], r11 # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    jmp .L62a9_rt_str_from_int_bb16 # branch
.L62a9_rt_str_from_int_bb16:
    mov r10, [rbp - 296] # reload L35 from spill slot
    mov rsi, [rbp - 296] # reload L35 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 624] # tag L35 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 632], rax # store tag L36
    mov [rbp - 304], r10 # spill L36 to slot
    mov r10, [rbp - 304] # reload L36 from spill slot
    test r10, r10 # br_cond test
    jz .L62a9_rt_str_from_int_bb18 # jump-if-zero -> else
    jmp .L62a9_rt_str_from_int_bb17 # jump -> then
.L62a9_rt_str_from_int_bb17:
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 400] # tag L7 from tag-slot
    mov rcx, [rbp - 296] # reload L35 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 624] # tag L35 from tag-slot
    call hexa_index_get # index: hexa_index_get
    mov r10, rdx # index: capture element payload
    mov [rbp - 640], rax # store tag L37
    mov [rbp - 312], r10 # spill L37 to slot
    mov rsi, [rbp - 248] # reload L29 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 576] # tag L29 from tag-slot
    mov rcx, [rbp - 312] # reload L37 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 640] # tag L37 from tag-slot
    call hexa_array_push # call hexa_array_push
    mov [rbp - 648], rax # store tag L38
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 320], r10 # spill L38 to slot
    mov r10, [rbp - 296] # reload L35 from spill slot
    mov rsi, [rbp - 296] # reload L35 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 624] # tag L35 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 656], rax # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    mov r11, [rbp - 328] # reload L39 from spill slot
    mov r10, r11 # assign L35
    mov r11, [rbp - 656] # tag L39 from tag-slot
    mov [rbp - 624], r11 # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    jmp .L62a9_rt_str_from_int_bb16 # branch
.L62a9_rt_str_from_int_bb18:
    mov rsi, [rbp - 248] # reload L29 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 576] # tag L29 from tag-slot
    lea rcx, [rip+.LCstr1] # hv arg payload: &str .LCstr1
    mov rdx, 3 # hv arg tag = TAG_STR
    call hexa_str_join # call hexa_str_join
    mov [rbp - 664], rax # store tag L40
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 336], r10 # spill L40 to slot
    mov rdx, [rbp - 336] # reload L40 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 664] # tag L40 from tag-slot
    add rsp, 624 # epilogue: free spill frame
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
    .byte 0x0a, 0x00
.section .rodata
.LCstr1:
    .byte 0x00
.section .rodata
.LCstr2:
    .byte 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d, 0x4e, 0x4f, 0x50
    .byte 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x00
.section .rodata
.LCstr3:
    .byte 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a, 0x6b, 0x6c, 0x6d, 0x6e, 0x6f, 0x70
    .byte 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x00
.section .rodata
.LCstr4:
    .byte 0x30, 0x00
.section .rodata
.LCstr5:
    .byte 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x00
.section .rodata
.LCstr6:
    .byte 0x2d, 0x00
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
