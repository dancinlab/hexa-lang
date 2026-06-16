// runtime_hi_x86_64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B Z2a).
// GENERATED: tool/regen_runtime_hi_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=x86_64-linux-gnu -o runtime_hi_x86_64.s runtime_hi_lib.hexa (lib-only head of self/runtime_hi.hexa).
//   Provides rt_str_* (zero C): split/lines/pad_left/pad_right/repeat/center +
//   to_upper/to_lower/trim/trim_start/trim_end (11 fns). ABI: ELF, rt_str_* no underscore + .hidden.
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
.La762_rt_str_split_bb0:
    call hexa_array_new # array_lit: new array
    mov rax, rax # array_lit: capture new array
    mov rbx, rax # assign L3
    mov rsi, rsi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    call hexa_len # call hexa_len
    mov r12, rax # hv: unbox call result (rax)
    cmp r12, 0 # binop ==
    sete al # binop == → al
    movzx r13, al # zero-extend al into dst
    test r13, r13 # br_cond test
    jz .La762_rt_str_split_bb2 # jump-if-zero -> else
    jmp .La762_rt_str_split_bb1 # jump -> then
.La762_rt_str_split_bb1:
    mov rsi, rbx # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, rdi # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_array_push # call hexa_array_push
    mov r14, rdx # hv: unbox call result (rdx)
    mov rax, rbx # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.La762_rt_str_split_bb2:
    mov rsi, rsi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    call hexa_len # call hexa_len
    mov r15, rax # hv: unbox call result (rax)
    mov rax, r15 # assign L9
    mov r12, 0 # assign L10
    mov r13, 0 # assign L11
    jmp .La762_rt_str_split_bb3 # branch
.La762_rt_str_split_bb3:
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    call hexa_len # call hexa_len
    mov r14, rax # hv: unbox call result (rax)
    mov r15, r14 # binop lhs into dst
    sub r15, rax # binop -
    cmp r13, r15 # binop <=
    setle al # binop <= → al
    movzx r14, al # zero-extend al into dst
    test r14, r14 # br_cond test
    jz .La762_rt_str_split_bb5 # jump-if-zero -> else
    jmp .La762_rt_str_split_bb4 # jump -> then
.La762_rt_str_split_bb4:
    mov r15, r13 # binop lhs into dst
    add r15, rax # binop +
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, r13 # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    mov r9, r15 # hv arg payload
    mov r8, 0 # hv arg tag = 0
    call hexa_str_substring # call hexa_str_substring
    mov r14, rdx # hv: unbox call result (rdx)
    cmp r14, rsi # binop ==
    sete al # binop == → al
    movzx r15, al # zero-extend al into dst
    test r15, r15 # br_cond test
    jz .La762_rt_str_split_bb7 # jump-if-zero -> else
    jmp .La762_rt_str_split_bb6 # jump -> then
.La762_rt_str_split_bb5:
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    call hexa_len # call hexa_len
    mov r14, rax # hv: unbox call result (rax)
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, r12 # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    mov r9, r14 # hv arg payload
    mov r8, 0 # hv arg tag = 0
    call hexa_str_substring # call hexa_str_substring
    mov r15, rdx # hv: unbox call result (rdx)
    mov rsi, rbx # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, r15 # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_array_push # call hexa_array_push
    mov r14, rdx # hv: unbox call result (rdx)
    mov rax, rbx # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.La762_rt_str_split_bb6:
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, r12 # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    mov r9, r13 # hv arg payload
    mov r8, 0 # hv arg tag = 0
    call hexa_str_substring # call hexa_str_substring
    mov r15, rdx # hv: unbox call result (rdx)
    mov rsi, rbx # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, r15 # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_array_push # call hexa_array_push
    mov r14, rdx # hv: unbox call result (rdx)
    mov rbx, r13 # binop lhs into dst
    add rbx, rax # binop +
    mov r12, rbx # assign L10
    mov r13, r12 # assign L11
    jmp .La762_rt_str_split_bb8 # branch
.La762_rt_str_split_bb7:
    mov r15, r13 # binop lhs into dst
    add r15, 1 # binop +
    mov r13, r15 # assign L11
    jmp .La762_rt_str_split_bb8 # branch
.La762_rt_str_split_bb8:
    jmp .La762_rt_str_split_bb3 # branch
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_lines
.hidden rt_str_lines
    .p2align 4
rt_str_lines:
    .loc 1 45 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
.La762_rt_str_lines_bb0:
    mov rdi, rdi # arg 0
    mov rsi, .LCstr0 # arg 1
    call rt_str_split # call rt_str_split
    mov rax, rax # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_pad_left
.hidden rt_str_pad_left
    .p2align 4
rt_str_pad_left:
    .loc 1 52 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
.La762_rt_str_pad_left_bb0:
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    call hexa_len # call hexa_len
    mov rbx, rax # assign L4
    mov rsi, rdx # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    call hexa_len # call hexa_len
    mov r12, rax # hv: unbox call result (rax)
    mov r13, r12 # assign L6
    cmp rbx, rsi # binop >=
    setge al # binop >= → al
    movzx r14, al # zero-extend al into dst
    test r14, r14 # br_cond test
    jz .La762_rt_str_pad_left_bb2 # jump-if-zero -> else
    jmp .La762_rt_str_pad_left_bb1 # jump -> then
.La762_rt_str_pad_left_bb1:
    mov rax, rdi # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.La762_rt_str_pad_left_bb2:
    cmp r13, 0 # binop ==
    sete al # binop == → al
    movzx r15, al # zero-extend al into dst
    test r15, r15 # br_cond test
    jz .La762_rt_str_pad_left_bb4 # jump-if-zero -> else
    jmp .La762_rt_str_pad_left_bb3 # jump -> then
.La762_rt_str_pad_left_bb3:
    mov rax, rdi # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.La762_rt_str_pad_left_bb4:
    mov rax, rsi # binop lhs into dst
    sub rax, rbx # binop -
    mov r12, rax # assign L12
    mov rax, r12 # idiv dividend → rax
    cqo # sign-extend rax into rdx:rax
    mov r11, r13 # materialize idiv divisor to reg
    idiv r11 # binop /
    mov r14, rax # idiv quotient → dst
    mov r15, r14 # assign L14
    mov rbx, r15 # binop lhs into dst
    imul rbx, r13 # binop *
    cmp rbx, r12 # binop <
    setl al # binop < → al
    movzx rax, al # zero-extend al into dst
    test rax, rax # br_cond test
    jz .La762_rt_str_pad_left_bb6 # jump-if-zero -> else
    jmp .La762_rt_str_pad_left_bb5 # jump -> then
.La762_rt_str_pad_left_bb5:
    mov r14, r15 # binop lhs into dst
    add r14, 1 # binop +
    mov r15, r14 # assign L14
    jmp .La762_rt_str_pad_left_bb6 # branch
.La762_rt_str_pad_left_bb6:
    call hexa_array_new # array_lit: new array
    mov r13, rax # array_lit: capture new array
    mov r12, r13 # assign L20
    mov rbx, 0 # assign L21
    jmp .La762_rt_str_pad_left_bb7 # branch
.La762_rt_str_pad_left_bb7:
    cmp rbx, r15 # binop <
    setl al # binop < → al
    movzx rax, al # zero-extend al into dst
    test rax, rax # br_cond test
    jz .La762_rt_str_pad_left_bb9 # jump-if-zero -> else
    jmp .La762_rt_str_pad_left_bb8 # jump -> then
.La762_rt_str_pad_left_bb8:
    mov rsi, r12 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, rdx # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_array_push # call hexa_array_push
    mov r14, rdx # hv: unbox call result (rdx)
    mov r13, rbx # binop lhs into dst
    add r13, 1 # binop +
    mov rbx, r13 # assign L21
    jmp .La762_rt_str_pad_left_bb7 # branch
.La762_rt_str_pad_left_bb9:
    mov rsi, r12 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, rdi # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_array_push # call hexa_array_push
    mov r15, rdx # hv: unbox call result (rdx)
    mov rsi, r12 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    lea rcx, [rip+.LCstr1] # hv arg payload: &str .LCstr1
    mov rdx, 3 # hv arg tag = 3
    call hexa_str_join # call hexa_str_join
    mov rax, rdx # hv: unbox call result (rdx)
    mov rax, rax # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_pad_right
.hidden rt_str_pad_right
    .p2align 4
rt_str_pad_right:
    .loc 1 70 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
.La762_rt_str_pad_right_bb0:
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    call hexa_len # call hexa_len
    mov rbx, rax # assign L4
    mov rsi, rdx # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    call hexa_len # call hexa_len
    mov r12, rax # hv: unbox call result (rax)
    mov r13, r12 # assign L6
    cmp rbx, rsi # binop >=
    setge al # binop >= → al
    movzx r14, al # zero-extend al into dst
    test r14, r14 # br_cond test
    jz .La762_rt_str_pad_right_bb2 # jump-if-zero -> else
    jmp .La762_rt_str_pad_right_bb1 # jump -> then
.La762_rt_str_pad_right_bb1:
    mov rax, rdi # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.La762_rt_str_pad_right_bb2:
    cmp r13, 0 # binop ==
    sete al # binop == → al
    movzx r15, al # zero-extend al into dst
    test r15, r15 # br_cond test
    jz .La762_rt_str_pad_right_bb4 # jump-if-zero -> else
    jmp .La762_rt_str_pad_right_bb3 # jump -> then
.La762_rt_str_pad_right_bb3:
    mov rax, rdi # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.La762_rt_str_pad_right_bb4:
    mov rax, rsi # binop lhs into dst
    sub rax, rbx # binop -
    mov r12, rax # assign L12
    mov rax, r12 # idiv dividend → rax
    cqo # sign-extend rax into rdx:rax
    mov r11, r13 # materialize idiv divisor to reg
    idiv r11 # binop /
    mov r14, rax # idiv quotient → dst
    mov r15, r14 # assign L14
    mov rbx, r15 # binop lhs into dst
    imul rbx, r13 # binop *
    cmp rbx, r12 # binop <
    setl al # binop < → al
    movzx rax, al # zero-extend al into dst
    test rax, rax # br_cond test
    jz .La762_rt_str_pad_right_bb6 # jump-if-zero -> else
    jmp .La762_rt_str_pad_right_bb5 # jump -> then
.La762_rt_str_pad_right_bb5:
    mov r14, r15 # binop lhs into dst
    add r14, 1 # binop +
    mov r15, r14 # assign L14
    jmp .La762_rt_str_pad_right_bb6 # branch
.La762_rt_str_pad_right_bb6:
    call hexa_array_new # array_lit: new array
    mov r13, rax # array_lit: capture new array
    mov r12, r13 # assign L20
    mov rsi, r12 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, rdi # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_array_push # call hexa_array_push
    mov rbx, rdx # hv: unbox call result (rdx)
    mov rax, 0 # assign L22
    jmp .La762_rt_str_pad_right_bb7 # branch
.La762_rt_str_pad_right_bb7:
    cmp rax, r15 # binop <
    setl al # binop < → al
    movzx r14, al # zero-extend al into dst
    test r14, r14 # br_cond test
    jz .La762_rt_str_pad_right_bb9 # jump-if-zero -> else
    jmp .La762_rt_str_pad_right_bb8 # jump -> then
.La762_rt_str_pad_right_bb8:
    mov rsi, r12 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, rdx # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_array_push # call hexa_array_push
    mov r13, rdx # hv: unbox call result (rdx)
    mov rbx, rax # binop lhs into dst
    add rbx, 1 # binop +
    mov rax, rbx # assign L22
    jmp .La762_rt_str_pad_right_bb7 # branch
.La762_rt_str_pad_right_bb9:
    mov rsi, r12 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    lea rcx, [rip+.LCstr1] # hv arg payload: &str .LCstr1
    mov rdx, 3 # hv arg tag = 3
    call hexa_str_join # call hexa_str_join
    mov r15, rdx # hv: unbox call result (rdx)
    mov rax, r15 # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_repeat
.hidden rt_str_repeat
    .p2align 4
rt_str_repeat:
    .loc 1 89 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
.La762_rt_str_repeat_bb0:
    cmp rsi, 0 # binop <=
    setle al # binop <= → al
    movzx rax, al # zero-extend al into dst
    test rax, rax # br_cond test
    jz .La762_rt_str_repeat_bb2 # jump-if-zero -> else
    jmp .La762_rt_str_repeat_bb1 # jump -> then
.La762_rt_str_repeat_bb1:
    mov rax, .LCstr1 # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.La762_rt_str_repeat_bb2:
    call hexa_array_new # array_lit: new array
    mov rbx, rax # array_lit: capture new array
    mov r12, rbx # assign L5
    mov r13, 0 # assign L6
    jmp .La762_rt_str_repeat_bb3 # branch
.La762_rt_str_repeat_bb3:
    cmp r13, rsi # binop <
    setl al # binop < → al
    movzx r14, al # zero-extend al into dst
    test r14, r14 # br_cond test
    jz .La762_rt_str_repeat_bb5 # jump-if-zero -> else
    jmp .La762_rt_str_repeat_bb4 # jump -> then
.La762_rt_str_repeat_bb4:
    mov rsi, r12 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, rdi # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_array_push # call hexa_array_push
    mov r15, rdx # hv: unbox call result (rdx)
    mov rax, r13 # binop lhs into dst
    add rax, 1 # binop +
    mov r13, rax # assign L6
    jmp .La762_rt_str_repeat_bb3 # branch
.La762_rt_str_repeat_bb5:
    mov rsi, r12 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    lea rcx, [rip+.LCstr1] # hv arg payload: &str .LCstr1
    mov rdx, 3 # hv arg tag = 3
    call hexa_str_join # call hexa_str_join
    mov rbx, rdx # hv: unbox call result (rdx)
    mov rax, rbx # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_center
.hidden rt_str_center
    .p2align 4
rt_str_center:
    .loc 1 101 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
.La762_rt_str_center_bb0:
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    call hexa_len # call hexa_len
    mov rbx, rax # assign L4
    mov rsi, rdx # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    call hexa_len # call hexa_len
    mov r12, rax # hv: unbox call result (rax)
    mov r13, r12 # assign L6
    cmp rbx, rsi # binop >=
    setge al # binop >= → al
    movzx r14, al # zero-extend al into dst
    test r14, r14 # br_cond test
    jz .La762_rt_str_center_bb2 # jump-if-zero -> else
    jmp .La762_rt_str_center_bb1 # jump -> then
.La762_rt_str_center_bb1:
    mov rax, rdi # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.La762_rt_str_center_bb2:
    cmp r13, 0 # binop ==
    sete al # binop == → al
    movzx r15, al # zero-extend al into dst
    test r15, r15 # br_cond test
    jz .La762_rt_str_center_bb4 # jump-if-zero -> else
    jmp .La762_rt_str_center_bb3 # jump -> then
.La762_rt_str_center_bb3:
    mov rax, rdi # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.La762_rt_str_center_bb4:
    mov rax, rsi # binop lhs into dst
    sub rax, rbx # binop -
    mov r12, rax # assign L12
    mov rax, r12 # idiv dividend → rax
    cqo # sign-extend rax into rdx:rax
    mov r11, 2 # materialize idiv divisor to reg
    idiv r11 # binop /
    mov r14, rax # idiv quotient → dst
    mov r15, r14 # assign L14
    mov rbx, r12 # binop lhs into dst
    sub rbx, r15 # binop -
    mov rax, rbx # assign L16
    mov rax, r15 # idiv dividend → rax
    cqo # sign-extend rax into rdx:rax
    mov r11, r13 # materialize idiv divisor to reg
    idiv r11 # binop /
    mov r14, rax # idiv quotient → dst
    mov r12, r14 # assign L18
    mov rbx, r12 # binop lhs into dst
    imul rbx, r13 # binop *
    cmp rbx, r15 # binop <
    setl al # binop < → al
    movzx r14, al # zero-extend al into dst
    test r14, r14 # br_cond test
    jz .La762_rt_str_center_bb6 # jump-if-zero -> else
    jmp .La762_rt_str_center_bb5 # jump -> then
.La762_rt_str_center_bb5:
    mov r15, r12 # binop lhs into dst
    add r15, 1 # binop +
    mov r12, r15 # assign L18
    jmp .La762_rt_str_center_bb6 # branch
.La762_rt_str_center_bb6:
    mov rax, rax # idiv dividend → rax
    cqo # sign-extend rax into rdx:rax
    mov r11, r13 # materialize idiv divisor to reg
    idiv r11 # binop /
    mov rbx, rax # idiv quotient → dst
    mov r14, rbx # assign L24
    mov r15, r14 # binop lhs into dst
    imul r15, r13 # binop *
    cmp r15, rax # binop <
    setl al # binop < → al
    movzx rbx, al # zero-extend al into dst
    test rbx, rbx # br_cond test
    jz .La762_rt_str_center_bb8 # jump-if-zero -> else
    jmp .La762_rt_str_center_bb7 # jump -> then
.La762_rt_str_center_bb7:
    mov r13, r14 # binop lhs into dst
    add r13, 1 # binop +
    mov r14, r13 # assign L24
    jmp .La762_rt_str_center_bb8 # branch
.La762_rt_str_center_bb8:
    call hexa_array_new # array_lit: new array
    mov rax, rax # array_lit: capture new array
    mov r15, rax # assign L30
    mov rbx, 0 # assign L31
    jmp .La762_rt_str_center_bb9 # branch
.La762_rt_str_center_bb9:
    cmp rbx, r12 # binop <
    setl al # binop < → al
    movzx r13, al # zero-extend al into dst
    test r13, r13 # br_cond test
    jz .La762_rt_str_center_bb11 # jump-if-zero -> else
    jmp .La762_rt_str_center_bb10 # jump -> then
.La762_rt_str_center_bb10:
    mov rsi, r15 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, rdx # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_array_push # call hexa_array_push
    mov rax, rdx # hv: unbox call result (rdx)
    mov r12, rbx # binop lhs into dst
    add r12, 1 # binop +
    mov rbx, r12 # assign L31
    jmp .La762_rt_str_center_bb9 # branch
.La762_rt_str_center_bb11:
    mov rsi, r15 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, rdi # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_array_push # call hexa_array_push
    mov r13, rdx # hv: unbox call result (rdx)
    mov rax, 0 # assign L36
    jmp .La762_rt_str_center_bb12 # branch
.La762_rt_str_center_bb12:
    cmp rax, r14 # binop <
    setl al # binop < → al
    movzx rbx, al # zero-extend al into dst
    test rbx, rbx # br_cond test
    jz .La762_rt_str_center_bb14 # jump-if-zero -> else
    jmp .La762_rt_str_center_bb13 # jump -> then
.La762_rt_str_center_bb13:
    mov rsi, r15 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, rdx # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_array_push # call hexa_array_push
    mov r12, rdx # hv: unbox call result (rdx)
    mov r13, rax # binop lhs into dst
    add r13, 1 # binop +
    mov rax, r13 # assign L36
    jmp .La762_rt_str_center_bb12 # branch
.La762_rt_str_center_bb14:
    mov rsi, r15 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    lea rcx, [rip+.LCstr1] # hv arg payload: &str .LCstr1
    mov rdx, 3 # hv arg tag = 3
    call hexa_str_join # call hexa_str_join
    mov r14, rdx # hv: unbox call result (rdx)
    mov rax, r14 # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_to_upper
.hidden rt_str_to_upper
    .p2align 4
rt_str_to_upper:
    .loc 1 134 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    sub rsp, 16 # prologue: alloc spill frame
.La762_rt_str_to_upper_bb0:
    mov rax, .LCstr2 # assign L1
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    call hexa_len # call hexa_len
    mov rbx, rax # hv: unbox call result (rax)
    mov r12, rbx # assign L3
    call hexa_array_new # array_lit: new array
    mov r13, rax # array_lit: capture new array
    mov r14, r13 # assign L5
    mov r10, 0 # assign L6
    mov [rbp - 8], r10 # spill L6 to slot
    jmp .La762_rt_str_to_upper_bb1 # branch
.La762_rt_str_to_upper_bb1:
    mov r10, [rbp - 8] # reload L6 from spill slot
    cmp r10, r12 # binop <
    setl al # binop < → al
    movzx rbx, al # zero-extend al into dst
    test rbx, rbx # br_cond test
    jz .La762_rt_str_to_upper_bb3 # jump-if-zero -> else
    jmp .La762_rt_str_to_upper_bb2 # jump -> then
.La762_rt_str_to_upper_bb2:
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, [rbp - 8] # reload L6 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_str_byte_at # call hexa_str_byte_at
    mov r13, rdx # hv: unbox call result (rdx)
    mov r12, r13 # assign L9
    cmp r12, 97 # binop >=
    setge al # binop >= → al
    movzx rbx, al # zero-extend al into dst
    test rbx, rbx # br_cond test
    jz .La762_rt_str_to_upper_bb5 # jump-if-zero -> else
    jmp .La762_rt_str_to_upper_bb4 # jump -> then
.La762_rt_str_to_upper_bb3:
    mov rsi, r14 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    lea rcx, [rip+.LCstr1] # hv arg payload: &str .LCstr1
    mov rdx, 3 # hv arg tag = 3
    call hexa_str_join # call hexa_str_join
    mov r13, rdx # hv: unbox call result (rdx)
    mov rax, r13 # set return value
    add rsp, 16 # epilogue: free spill frame
    pop rbp # epilogue: restore rbp
    ret # return
.La762_rt_str_to_upper_bb4:
    cmp r12, 122 # binop <=
    setle al # binop <= → al
    movzx r13, al # zero-extend al into dst
    mov r15, r13 # assign L11
    jmp .La762_rt_str_to_upper_bb6 # branch
.La762_rt_str_to_upper_bb5:
    mov r15, rbx # assign L11
    jmp .La762_rt_str_to_upper_bb6 # branch
.La762_rt_str_to_upper_bb6:
    test r15, r15 # br_cond test
    jz .La762_rt_str_to_upper_bb8 # jump-if-zero -> else
    jmp .La762_rt_str_to_upper_bb7 # jump -> then
.La762_rt_str_to_upper_bb7:
    mov r13, r12 # binop lhs into dst
    sub r13, 97 # binop -
    mov rbx, r12 # binop lhs into dst
    sub rbx, 97 # binop -
    mov r15, rbx # binop lhs into dst
    add r15, 1 # binop +
    mov rsi, rax # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, r13 # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    mov r9, r15 # hv arg payload
    mov r8, 0 # hv arg tag = 0
    call hexa_str_substring # call hexa_str_substring
    mov r12, rdx # hv: unbox call result (rdx)
    mov rsi, r14 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, r12 # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_array_push # call hexa_array_push
    mov rbx, rdx # hv: unbox call result (rdx)
    mov rax, rbx # assign L13
    jmp .La762_rt_str_to_upper_bb9 # branch
.La762_rt_str_to_upper_bb8:
    mov r10, [rbp - 8] # reload L6 from spill slot
    mov r13, r10 # binop lhs into dst
    add r13, 1 # binop +
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, [rbp - 8] # reload L6 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    mov r9, r13 # hv arg payload
    mov r8, 0 # hv arg tag = 0
    call hexa_str_substring # call hexa_str_substring
    mov r15, rdx # hv: unbox call result (rdx)
    mov rsi, r14 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, r15 # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_array_push # call hexa_array_push
    mov r12, rdx # hv: unbox call result (rdx)
    mov rax, r12 # assign L13
    jmp .La762_rt_str_to_upper_bb9 # branch
.La762_rt_str_to_upper_bb9:
    mov r10, [rbp - 8] # reload L6 from spill slot
    mov rbx, r10 # binop lhs into dst
    add rbx, 1 # binop +
    mov r10, rbx # assign L6
    mov [rbp - 8], r10 # spill L6 to slot
    jmp .La762_rt_str_to_upper_bb1 # branch
    add rsp, 16 # epilogue: free spill frame
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_to_lower
.hidden rt_str_to_lower
    .p2align 4
rt_str_to_lower:
    .loc 1 151 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    sub rsp, 16 # prologue: alloc spill frame
.La762_rt_str_to_lower_bb0:
    mov rax, .LCstr3 # assign L1
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    call hexa_len # call hexa_len
    mov rbx, rax # hv: unbox call result (rax)
    mov r12, rbx # assign L3
    call hexa_array_new # array_lit: new array
    mov r13, rax # array_lit: capture new array
    mov r14, r13 # assign L5
    mov r10, 0 # assign L6
    mov [rbp - 8], r10 # spill L6 to slot
    jmp .La762_rt_str_to_lower_bb1 # branch
.La762_rt_str_to_lower_bb1:
    mov r10, [rbp - 8] # reload L6 from spill slot
    cmp r10, r12 # binop <
    setl al # binop < → al
    movzx rbx, al # zero-extend al into dst
    test rbx, rbx # br_cond test
    jz .La762_rt_str_to_lower_bb3 # jump-if-zero -> else
    jmp .La762_rt_str_to_lower_bb2 # jump -> then
.La762_rt_str_to_lower_bb2:
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, [rbp - 8] # reload L6 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_str_byte_at # call hexa_str_byte_at
    mov r13, rdx # hv: unbox call result (rdx)
    mov r12, r13 # assign L9
    cmp r12, 65 # binop >=
    setge al # binop >= → al
    movzx rbx, al # zero-extend al into dst
    test rbx, rbx # br_cond test
    jz .La762_rt_str_to_lower_bb5 # jump-if-zero -> else
    jmp .La762_rt_str_to_lower_bb4 # jump -> then
.La762_rt_str_to_lower_bb3:
    mov rsi, r14 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    lea rcx, [rip+.LCstr1] # hv arg payload: &str .LCstr1
    mov rdx, 3 # hv arg tag = 3
    call hexa_str_join # call hexa_str_join
    mov r13, rdx # hv: unbox call result (rdx)
    mov rax, r13 # set return value
    add rsp, 16 # epilogue: free spill frame
    pop rbp # epilogue: restore rbp
    ret # return
.La762_rt_str_to_lower_bb4:
    cmp r12, 90 # binop <=
    setle al # binop <= → al
    movzx r13, al # zero-extend al into dst
    mov r15, r13 # assign L11
    jmp .La762_rt_str_to_lower_bb6 # branch
.La762_rt_str_to_lower_bb5:
    mov r15, rbx # assign L11
    jmp .La762_rt_str_to_lower_bb6 # branch
.La762_rt_str_to_lower_bb6:
    test r15, r15 # br_cond test
    jz .La762_rt_str_to_lower_bb8 # jump-if-zero -> else
    jmp .La762_rt_str_to_lower_bb7 # jump -> then
.La762_rt_str_to_lower_bb7:
    mov r13, r12 # binop lhs into dst
    sub r13, 65 # binop -
    mov rbx, r12 # binop lhs into dst
    sub rbx, 65 # binop -
    mov r15, rbx # binop lhs into dst
    add r15, 1 # binop +
    mov rsi, rax # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, r13 # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    mov r9, r15 # hv arg payload
    mov r8, 0 # hv arg tag = 0
    call hexa_str_substring # call hexa_str_substring
    mov r12, rdx # hv: unbox call result (rdx)
    mov rsi, r14 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, r12 # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_array_push # call hexa_array_push
    mov rbx, rdx # hv: unbox call result (rdx)
    mov rax, rbx # assign L13
    jmp .La762_rt_str_to_lower_bb9 # branch
.La762_rt_str_to_lower_bb8:
    mov r10, [rbp - 8] # reload L6 from spill slot
    mov r13, r10 # binop lhs into dst
    add r13, 1 # binop +
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, [rbp - 8] # reload L6 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    mov r9, r13 # hv arg payload
    mov r8, 0 # hv arg tag = 0
    call hexa_str_substring # call hexa_str_substring
    mov r15, rdx # hv: unbox call result (rdx)
    mov rsi, r14 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, r15 # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_array_push # call hexa_array_push
    mov r12, rdx # hv: unbox call result (rdx)
    mov rax, r12 # assign L13
    jmp .La762_rt_str_to_lower_bb9 # branch
.La762_rt_str_to_lower_bb9:
    mov r10, [rbp - 8] # reload L6 from spill slot
    mov rbx, r10 # binop lhs into dst
    add rbx, 1 # binop +
    mov r10, rbx # assign L6
    mov [rbp - 8], r10 # spill L6 to slot
    jmp .La762_rt_str_to_lower_bb1 # branch
    add rsp, 16 # epilogue: free spill frame
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_trim
.hidden rt_str_trim
    .p2align 4
rt_str_trim:
    .loc 1 170 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
.La762_rt_str_trim_bb0:
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    call hexa_len # call hexa_len
    mov rbx, rax # assign L2
    mov r12, 0 # assign L3
    jmp .La762_rt_str_trim_bb1 # branch
.La762_rt_str_trim_bb1:
    cmp r12, rbx # binop <
    setl al # binop < → al
    movzx r13, al # zero-extend al into dst
    test r13, r13 # br_cond test
    jz .La762_rt_str_trim_bb3 # jump-if-zero -> else
    jmp .La762_rt_str_trim_bb2 # jump -> then
.La762_rt_str_trim_bb2:
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, r12 # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_str_byte_at # call hexa_str_byte_at
    mov r14, rdx # hv: unbox call result (rdx)
    mov r15, r14 # assign L6
    cmp r15, 32 # binop ==
    sete al # binop == → al
    movzx rax, al # zero-extend al into dst
    test rax, rax # br_cond test
    jz .La762_rt_str_trim_bb5 # jump-if-zero -> else
    jmp .La762_rt_str_trim_bb4 # jump -> then
.La762_rt_str_trim_bb3:
    mov r13, rbx # assign L16
    jmp .La762_rt_str_trim_bb16 # branch
.La762_rt_str_trim_bb4:
    mov r14, rax # assign L8
    jmp .La762_rt_str_trim_bb6 # branch
.La762_rt_str_trim_bb5:
    cmp r15, 9 # binop ==
    sete al # binop == → al
    movzx rbx, al # zero-extend al into dst
    mov r14, rbx # assign L8
    jmp .La762_rt_str_trim_bb6 # branch
.La762_rt_str_trim_bb6:
    test r14, r14 # br_cond test
    jz .La762_rt_str_trim_bb8 # jump-if-zero -> else
    jmp .La762_rt_str_trim_bb7 # jump -> then
.La762_rt_str_trim_bb7:
    mov rax, r14 # assign L10
    jmp .La762_rt_str_trim_bb9 # branch
.La762_rt_str_trim_bb8:
    cmp r15, 10 # binop ==
    sete al # binop == → al
    movzx rbx, al # zero-extend al into dst
    mov rax, rbx # assign L10
    jmp .La762_rt_str_trim_bb9 # branch
.La762_rt_str_trim_bb9:
    test rax, rax # br_cond test
    jz .La762_rt_str_trim_bb11 # jump-if-zero -> else
    jmp .La762_rt_str_trim_bb10 # jump -> then
.La762_rt_str_trim_bb10:
    mov r14, rax # assign L12
    jmp .La762_rt_str_trim_bb12 # branch
.La762_rt_str_trim_bb11:
    cmp r15, 13 # binop ==
    sete al # binop == → al
    movzx rbx, al # zero-extend al into dst
    mov r14, rbx # assign L12
    jmp .La762_rt_str_trim_bb12 # branch
.La762_rt_str_trim_bb12:
    test r14, r14 # br_cond test
    jz .La762_rt_str_trim_bb14 # jump-if-zero -> else
    jmp .La762_rt_str_trim_bb13 # jump -> then
.La762_rt_str_trim_bb13:
    mov rax, r12 # binop lhs into dst
    add rax, 1 # binop +
    mov r12, rax # assign L3
    jmp .La762_rt_str_trim_bb15 # branch
.La762_rt_str_trim_bb14:
    jmp .La762_rt_str_trim_bb3 # branch
.La762_rt_str_trim_bb15:
    jmp .La762_rt_str_trim_bb1 # branch
.La762_rt_str_trim_bb16:
    cmp r13, r12 # binop >
    setg al # binop > → al
    movzx r15, al # zero-extend al into dst
    test r15, r15 # br_cond test
    jz .La762_rt_str_trim_bb18 # jump-if-zero -> else
    jmp .La762_rt_str_trim_bb17 # jump -> then
.La762_rt_str_trim_bb17:
    mov rbx, r13 # binop lhs into dst
    sub rbx, 1 # binop -
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, rbx # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_str_byte_at # call hexa_str_byte_at
    mov r14, rdx # hv: unbox call result (rdx)
    mov rax, r14 # assign L20
    cmp rax, 32 # binop ==
    sete al # binop == → al
    movzx r15, al # zero-extend al into dst
    test r15, r15 # br_cond test
    jz .La762_rt_str_trim_bb20 # jump-if-zero -> else
    jmp .La762_rt_str_trim_bb19 # jump -> then
.La762_rt_str_trim_bb18:
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, r12 # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    mov r9, r13 # hv arg payload
    mov r8, 0 # hv arg tag = 0
    call hexa_str_substring # call hexa_str_substring
    mov rbx, rdx # hv: unbox call result (rdx)
    mov rax, rbx # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.La762_rt_str_trim_bb19:
    mov r14, r15 # assign L22
    jmp .La762_rt_str_trim_bb21 # branch
.La762_rt_str_trim_bb20:
    cmp rax, 9 # binop ==
    sete al # binop == → al
    movzx r12, al # zero-extend al into dst
    mov r14, r12 # assign L22
    jmp .La762_rt_str_trim_bb21 # branch
.La762_rt_str_trim_bb21:
    test r14, r14 # br_cond test
    jz .La762_rt_str_trim_bb23 # jump-if-zero -> else
    jmp .La762_rt_str_trim_bb22 # jump -> then
.La762_rt_str_trim_bb22:
    mov rbx, r14 # assign L24
    jmp .La762_rt_str_trim_bb24 # branch
.La762_rt_str_trim_bb23:
    cmp rax, 10 # binop ==
    sete al # binop == → al
    movzx r15, al # zero-extend al into dst
    mov rbx, r15 # assign L24
    jmp .La762_rt_str_trim_bb24 # branch
.La762_rt_str_trim_bb24:
    test rbx, rbx # br_cond test
    jz .La762_rt_str_trim_bb26 # jump-if-zero -> else
    jmp .La762_rt_str_trim_bb25 # jump -> then
.La762_rt_str_trim_bb25:
    mov r12, rbx # assign L26
    jmp .La762_rt_str_trim_bb27 # branch
.La762_rt_str_trim_bb26:
    cmp rax, 13 # binop ==
    sete al # binop == → al
    movzx r14, al # zero-extend al into dst
    mov r12, r14 # assign L26
    jmp .La762_rt_str_trim_bb27 # branch
.La762_rt_str_trim_bb27:
    test r12, r12 # br_cond test
    jz .La762_rt_str_trim_bb29 # jump-if-zero -> else
    jmp .La762_rt_str_trim_bb28 # jump -> then
.La762_rt_str_trim_bb28:
    mov r15, r13 # binop lhs into dst
    sub r15, 1 # binop -
    mov r13, r15 # assign L16
    jmp .La762_rt_str_trim_bb30 # branch
.La762_rt_str_trim_bb29:
    jmp .La762_rt_str_trim_bb18 # branch
.La762_rt_str_trim_bb30:
    jmp .La762_rt_str_trim_bb16 # branch
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_trim_start
.hidden rt_str_trim_start
    .p2align 4
rt_str_trim_start:
    .loc 1 196 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
.La762_rt_str_trim_start_bb0:
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    call hexa_len # call hexa_len
    mov rbx, rax # assign L2
    mov r12, 0 # assign L3
    jmp .La762_rt_str_trim_start_bb1 # branch
.La762_rt_str_trim_start_bb1:
    cmp r12, rbx # binop <
    setl al # binop < → al
    movzx r13, al # zero-extend al into dst
    test r13, r13 # br_cond test
    jz .La762_rt_str_trim_start_bb3 # jump-if-zero -> else
    jmp .La762_rt_str_trim_start_bb2 # jump -> then
.La762_rt_str_trim_start_bb2:
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, r12 # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_str_byte_at # call hexa_str_byte_at
    mov r14, rdx # hv: unbox call result (rdx)
    mov r15, r14 # assign L6
    cmp r15, 32 # binop ==
    sete al # binop == → al
    movzx rax, al # zero-extend al into dst
    test rax, rax # br_cond test
    jz .La762_rt_str_trim_start_bb5 # jump-if-zero -> else
    jmp .La762_rt_str_trim_start_bb4 # jump -> then
.La762_rt_str_trim_start_bb3:
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, r12 # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    mov r9, rbx # hv arg payload
    mov r8, 0 # hv arg tag = 0
    call hexa_str_substring # call hexa_str_substring
    mov r13, rdx # hv: unbox call result (rdx)
    mov rax, r13 # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.La762_rt_str_trim_start_bb4:
    mov r14, rax # assign L8
    jmp .La762_rt_str_trim_start_bb6 # branch
.La762_rt_str_trim_start_bb5:
    cmp r15, 9 # binop ==
    sete al # binop == → al
    movzx rbx, al # zero-extend al into dst
    mov r14, rbx # assign L8
    jmp .La762_rt_str_trim_start_bb6 # branch
.La762_rt_str_trim_start_bb6:
    test r14, r14 # br_cond test
    jz .La762_rt_str_trim_start_bb8 # jump-if-zero -> else
    jmp .La762_rt_str_trim_start_bb7 # jump -> then
.La762_rt_str_trim_start_bb7:
    mov r13, r14 # assign L10
    jmp .La762_rt_str_trim_start_bb9 # branch
.La762_rt_str_trim_start_bb8:
    cmp r15, 10 # binop ==
    sete al # binop == → al
    movzx rax, al # zero-extend al into dst
    mov r13, rax # assign L10
    jmp .La762_rt_str_trim_start_bb9 # branch
.La762_rt_str_trim_start_bb9:
    test r13, r13 # br_cond test
    jz .La762_rt_str_trim_start_bb11 # jump-if-zero -> else
    jmp .La762_rt_str_trim_start_bb10 # jump -> then
.La762_rt_str_trim_start_bb10:
    mov rbx, r13 # assign L12
    jmp .La762_rt_str_trim_start_bb12 # branch
.La762_rt_str_trim_start_bb11:
    cmp r15, 13 # binop ==
    sete al # binop == → al
    movzx r14, al # zero-extend al into dst
    mov rbx, r14 # assign L12
    jmp .La762_rt_str_trim_start_bb12 # branch
.La762_rt_str_trim_start_bb12:
    test rbx, rbx # br_cond test
    jz .La762_rt_str_trim_start_bb14 # jump-if-zero -> else
    jmp .La762_rt_str_trim_start_bb13 # jump -> then
.La762_rt_str_trim_start_bb13:
    mov rax, r12 # binop lhs into dst
    add rax, 1 # binop +
    mov r12, rax # assign L3
    jmp .La762_rt_str_trim_start_bb15 # branch
.La762_rt_str_trim_start_bb14:
    jmp .La762_rt_str_trim_start_bb3 # branch
.La762_rt_str_trim_start_bb15:
    jmp .La762_rt_str_trim_start_bb1 # branch
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_trim_end
.hidden rt_str_trim_end
    .p2align 4
rt_str_trim_end:
    .loc 1 210 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
.La762_rt_str_trim_end_bb0:
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    call hexa_len # call hexa_len
    mov rbx, rax # assign L2
    mov r12, rbx # assign L3
    jmp .La762_rt_str_trim_end_bb1 # branch
.La762_rt_str_trim_end_bb1:
    cmp r12, 0 # binop >
    setg al # binop > → al
    movzx r13, al # zero-extend al into dst
    test r13, r13 # br_cond test
    jz .La762_rt_str_trim_end_bb3 # jump-if-zero -> else
    jmp .La762_rt_str_trim_end_bb2 # jump -> then
.La762_rt_str_trim_end_bb2:
    mov r14, r12 # binop lhs into dst
    sub r14, 1 # binop -
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, r14 # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_str_byte_at # call hexa_str_byte_at
    mov r15, rdx # hv: unbox call result (rdx)
    mov rax, r15 # assign L7
    cmp rax, 32 # binop ==
    sete al # binop == → al
    movzx rbx, al # zero-extend al into dst
    test rbx, rbx # br_cond test
    jz .La762_rt_str_trim_end_bb5 # jump-if-zero -> else
    jmp .La762_rt_str_trim_end_bb4 # jump -> then
.La762_rt_str_trim_end_bb3:
    mov rsi, rdi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    mov r9, r12 # hv arg payload
    mov r8, 0 # hv arg tag = 0
    call hexa_str_substring # call hexa_str_substring
    mov r13, rdx # hv: unbox call result (rdx)
    mov rax, r13 # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.La762_rt_str_trim_end_bb4:
    mov r14, rbx # assign L9
    jmp .La762_rt_str_trim_end_bb6 # branch
.La762_rt_str_trim_end_bb5:
    cmp rax, 9 # binop ==
    sete al # binop == → al
    movzx r15, al # zero-extend al into dst
    mov r14, r15 # assign L9
    jmp .La762_rt_str_trim_end_bb6 # branch
.La762_rt_str_trim_end_bb6:
    test r14, r14 # br_cond test
    jz .La762_rt_str_trim_end_bb8 # jump-if-zero -> else
    jmp .La762_rt_str_trim_end_bb7 # jump -> then
.La762_rt_str_trim_end_bb7:
    mov r13, r14 # assign L11
    jmp .La762_rt_str_trim_end_bb9 # branch
.La762_rt_str_trim_end_bb8:
    cmp rax, 10 # binop ==
    sete al # binop == → al
    movzx rbx, al # zero-extend al into dst
    mov r13, rbx # assign L11
    jmp .La762_rt_str_trim_end_bb9 # branch
.La762_rt_str_trim_end_bb9:
    test r13, r13 # br_cond test
    jz .La762_rt_str_trim_end_bb11 # jump-if-zero -> else
    jmp .La762_rt_str_trim_end_bb10 # jump -> then
.La762_rt_str_trim_end_bb10:
    mov r15, r13 # assign L13
    jmp .La762_rt_str_trim_end_bb12 # branch
.La762_rt_str_trim_end_bb11:
    cmp rax, 13 # binop ==
    sete al # binop == → al
    movzx r14, al # zero-extend al into dst
    mov r15, r14 # assign L13
    jmp .La762_rt_str_trim_end_bb12 # branch
.La762_rt_str_trim_end_bb12:
    test r15, r15 # br_cond test
    jz .La762_rt_str_trim_end_bb14 # jump-if-zero -> else
    jmp .La762_rt_str_trim_end_bb13 # jump -> then
.La762_rt_str_trim_end_bb13:
    mov rbx, r12 # binop lhs into dst
    sub rbx, 1 # binop -
    mov r12, rbx # assign L3
    jmp .La762_rt_str_trim_end_bb15 # branch
.La762_rt_str_trim_end_bb14:
    jmp .La762_rt_str_trim_end_bb3 # branch
.La762_rt_str_trim_end_bb15:
    jmp .La762_rt_str_trim_end_bb1 # branch
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
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
