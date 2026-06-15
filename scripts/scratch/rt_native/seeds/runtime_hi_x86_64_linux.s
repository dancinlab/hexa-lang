# hexa-lang emit pass — target=x86_64-linux-gnu
# source: /tmp/runtime_hi_lib.hexa
.intel_syntax noprefix
.file 1 "/tmp/runtime_hi_lib.hexa"
.text
.globl rt_str_split
.hidden rt_str_split
    .p2align 4
rt_str_split:
    .loc 1 22 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
.Lb8b9_rt_str_split_bb0:
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
    jz .Lb8b9_rt_str_split_bb2 # jump-if-zero -> else
    jmp .Lb8b9_rt_str_split_bb1 # jump -> then
.Lb8b9_rt_str_split_bb1:
    mov rsi, rbx # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, rdi # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_array_push # call hexa_array_push
    mov r14, rdx # hv: unbox call result (rdx)
    mov rax, rbx # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.Lb8b9_rt_str_split_bb2:
    mov rsi, rsi # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    call hexa_len # call hexa_len
    mov r15, rax # hv: unbox call result (rax)
    mov rax, r15 # assign L9
    mov r12, 0 # assign L10
    mov r13, 0 # assign L11
    jmp .Lb8b9_rt_str_split_bb3 # branch
.Lb8b9_rt_str_split_bb3:
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
    jz .Lb8b9_rt_str_split_bb5 # jump-if-zero -> else
    jmp .Lb8b9_rt_str_split_bb4 # jump -> then
.Lb8b9_rt_str_split_bb4:
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
    jz .Lb8b9_rt_str_split_bb7 # jump-if-zero -> else
    jmp .Lb8b9_rt_str_split_bb6 # jump -> then
.Lb8b9_rt_str_split_bb5:
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
.Lb8b9_rt_str_split_bb6:
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
    jmp .Lb8b9_rt_str_split_bb8 # branch
.Lb8b9_rt_str_split_bb7:
    mov r15, r13 # binop lhs into dst
    add r15, 1 # binop +
    mov r13, r15 # assign L11
    jmp .Lb8b9_rt_str_split_bb8 # branch
.Lb8b9_rt_str_split_bb8:
    jmp .Lb8b9_rt_str_split_bb3 # branch
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_lines
.hidden rt_str_lines
    .p2align 4
rt_str_lines:
    .loc 1 45 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
.Lb8b9_rt_str_lines_bb0:
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
.Lb8b9_rt_str_pad_left_bb0:
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
    jz .Lb8b9_rt_str_pad_left_bb2 # jump-if-zero -> else
    jmp .Lb8b9_rt_str_pad_left_bb1 # jump -> then
.Lb8b9_rt_str_pad_left_bb1:
    mov rax, rdi # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.Lb8b9_rt_str_pad_left_bb2:
    cmp r13, 0 # binop ==
    sete al # binop == → al
    movzx r15, al # zero-extend al into dst
    test r15, r15 # br_cond test
    jz .Lb8b9_rt_str_pad_left_bb4 # jump-if-zero -> else
    jmp .Lb8b9_rt_str_pad_left_bb3 # jump -> then
.Lb8b9_rt_str_pad_left_bb3:
    mov rax, rdi # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.Lb8b9_rt_str_pad_left_bb4:
    mov rax, rsi # binop lhs into dst
    sub rax, rbx # binop -
    mov r12, rax # assign L12
    mov rax, r12 # idiv dividend → rax
    cqo # sign-extend rax into rdx:rax
    idiv r13 # binop /
    mov r14, rax # idiv quotient → dst
    mov r15, r14 # assign L14
    mov rbx, r15 # binop lhs into dst
    imul rbx, r13 # binop *
    cmp rbx, r12 # binop <
    setl al # binop < → al
    movzx rax, al # zero-extend al into dst
    test rax, rax # br_cond test
    jz .Lb8b9_rt_str_pad_left_bb6 # jump-if-zero -> else
    jmp .Lb8b9_rt_str_pad_left_bb5 # jump -> then
.Lb8b9_rt_str_pad_left_bb5:
    mov r14, r15 # binop lhs into dst
    add r14, 1 # binop +
    mov r15, r14 # assign L14
    jmp .Lb8b9_rt_str_pad_left_bb6 # branch
.Lb8b9_rt_str_pad_left_bb6:
    call hexa_array_new # array_lit: new array
    mov r13, rax # array_lit: capture new array
    mov r12, r13 # assign L20
    mov rbx, 0 # assign L21
    jmp .Lb8b9_rt_str_pad_left_bb7 # branch
.Lb8b9_rt_str_pad_left_bb7:
    cmp rbx, r15 # binop <
    setl al # binop < → al
    movzx rax, al # zero-extend al into dst
    test rax, rax # br_cond test
    jz .Lb8b9_rt_str_pad_left_bb9 # jump-if-zero -> else
    jmp .Lb8b9_rt_str_pad_left_bb8 # jump -> then
.Lb8b9_rt_str_pad_left_bb8:
    mov rsi, r12 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, rdx # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_array_push # call hexa_array_push
    mov r14, rdx # hv: unbox call result (rdx)
    mov r13, rbx # binop lhs into dst
    add r13, 1 # binop +
    mov rbx, r13 # assign L21
    jmp .Lb8b9_rt_str_pad_left_bb7 # branch
.Lb8b9_rt_str_pad_left_bb9:
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
.Lb8b9_rt_str_pad_right_bb0:
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
    jz .Lb8b9_rt_str_pad_right_bb2 # jump-if-zero -> else
    jmp .Lb8b9_rt_str_pad_right_bb1 # jump -> then
.Lb8b9_rt_str_pad_right_bb1:
    mov rax, rdi # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.Lb8b9_rt_str_pad_right_bb2:
    cmp r13, 0 # binop ==
    sete al # binop == → al
    movzx r15, al # zero-extend al into dst
    test r15, r15 # br_cond test
    jz .Lb8b9_rt_str_pad_right_bb4 # jump-if-zero -> else
    jmp .Lb8b9_rt_str_pad_right_bb3 # jump -> then
.Lb8b9_rt_str_pad_right_bb3:
    mov rax, rdi # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.Lb8b9_rt_str_pad_right_bb4:
    mov rax, rsi # binop lhs into dst
    sub rax, rbx # binop -
    mov r12, rax # assign L12
    mov rax, r12 # idiv dividend → rax
    cqo # sign-extend rax into rdx:rax
    idiv r13 # binop /
    mov r14, rax # idiv quotient → dst
    mov r15, r14 # assign L14
    mov rbx, r15 # binop lhs into dst
    imul rbx, r13 # binop *
    cmp rbx, r12 # binop <
    setl al # binop < → al
    movzx rax, al # zero-extend al into dst
    test rax, rax # br_cond test
    jz .Lb8b9_rt_str_pad_right_bb6 # jump-if-zero -> else
    jmp .Lb8b9_rt_str_pad_right_bb5 # jump -> then
.Lb8b9_rt_str_pad_right_bb5:
    mov r14, r15 # binop lhs into dst
    add r14, 1 # binop +
    mov r15, r14 # assign L14
    jmp .Lb8b9_rt_str_pad_right_bb6 # branch
.Lb8b9_rt_str_pad_right_bb6:
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
    jmp .Lb8b9_rt_str_pad_right_bb7 # branch
.Lb8b9_rt_str_pad_right_bb7:
    cmp rax, r15 # binop <
    setl al # binop < → al
    movzx r14, al # zero-extend al into dst
    test r14, r14 # br_cond test
    jz .Lb8b9_rt_str_pad_right_bb9 # jump-if-zero -> else
    jmp .Lb8b9_rt_str_pad_right_bb8 # jump -> then
.Lb8b9_rt_str_pad_right_bb8:
    mov rsi, r12 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, rdx # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_array_push # call hexa_array_push
    mov r13, rdx # hv: unbox call result (rdx)
    mov rbx, rax # binop lhs into dst
    add rbx, 1 # binop +
    mov rax, rbx # assign L22
    jmp .Lb8b9_rt_str_pad_right_bb7 # branch
.Lb8b9_rt_str_pad_right_bb9:
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
.Lb8b9_rt_str_repeat_bb0:
    cmp rsi, 0 # binop <=
    setle al # binop <= → al
    movzx rax, al # zero-extend al into dst
    test rax, rax # br_cond test
    jz .Lb8b9_rt_str_repeat_bb2 # jump-if-zero -> else
    jmp .Lb8b9_rt_str_repeat_bb1 # jump -> then
.Lb8b9_rt_str_repeat_bb1:
    mov rax, .LCstr1 # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.Lb8b9_rt_str_repeat_bb2:
    call hexa_array_new # array_lit: new array
    mov rbx, rax # array_lit: capture new array
    mov r12, rbx # assign L5
    mov r13, 0 # assign L6
    jmp .Lb8b9_rt_str_repeat_bb3 # branch
.Lb8b9_rt_str_repeat_bb3:
    cmp r13, rsi # binop <
    setl al # binop < → al
    movzx r14, al # zero-extend al into dst
    test r14, r14 # br_cond test
    jz .Lb8b9_rt_str_repeat_bb5 # jump-if-zero -> else
    jmp .Lb8b9_rt_str_repeat_bb4 # jump -> then
.Lb8b9_rt_str_repeat_bb4:
    mov rsi, r12 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, rdi # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_array_push # call hexa_array_push
    mov r15, rdx # hv: unbox call result (rdx)
    mov rax, r13 # binop lhs into dst
    add rax, 1 # binop +
    mov r13, rax # assign L6
    jmp .Lb8b9_rt_str_repeat_bb3 # branch
.Lb8b9_rt_str_repeat_bb5:
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
.Lb8b9_rt_str_center_bb0:
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
    jz .Lb8b9_rt_str_center_bb2 # jump-if-zero -> else
    jmp .Lb8b9_rt_str_center_bb1 # jump -> then
.Lb8b9_rt_str_center_bb1:
    mov rax, rdi # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.Lb8b9_rt_str_center_bb2:
    cmp r13, 0 # binop ==
    sete al # binop == → al
    movzx r15, al # zero-extend al into dst
    test r15, r15 # br_cond test
    jz .Lb8b9_rt_str_center_bb4 # jump-if-zero -> else
    jmp .Lb8b9_rt_str_center_bb3 # jump -> then
.Lb8b9_rt_str_center_bb3:
    mov rax, rdi # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.Lb8b9_rt_str_center_bb4:
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
    idiv r13 # binop /
    mov r14, rax # idiv quotient → dst
    mov r12, r14 # assign L18
    mov rbx, r12 # binop lhs into dst
    imul rbx, r13 # binop *
    cmp rbx, r15 # binop <
    setl al # binop < → al
    movzx r14, al # zero-extend al into dst
    test r14, r14 # br_cond test
    jz .Lb8b9_rt_str_center_bb6 # jump-if-zero -> else
    jmp .Lb8b9_rt_str_center_bb5 # jump -> then
.Lb8b9_rt_str_center_bb5:
    mov r15, r12 # binop lhs into dst
    add r15, 1 # binop +
    mov r12, r15 # assign L18
    jmp .Lb8b9_rt_str_center_bb6 # branch
.Lb8b9_rt_str_center_bb6:
    mov rax, rax # idiv dividend → rax
    cqo # sign-extend rax into rdx:rax
    idiv r13 # binop /
    mov rbx, rax # idiv quotient → dst
    mov r14, rbx # assign L24
    mov r15, r14 # binop lhs into dst
    imul r15, r13 # binop *
    cmp r15, rax # binop <
    setl al # binop < → al
    movzx rbx, al # zero-extend al into dst
    test rbx, rbx # br_cond test
    jz .Lb8b9_rt_str_center_bb8 # jump-if-zero -> else
    jmp .Lb8b9_rt_str_center_bb7 # jump -> then
.Lb8b9_rt_str_center_bb7:
    mov r13, r14 # binop lhs into dst
    add r13, 1 # binop +
    mov r14, r13 # assign L24
    jmp .Lb8b9_rt_str_center_bb8 # branch
.Lb8b9_rt_str_center_bb8:
    call hexa_array_new # array_lit: new array
    mov rax, rax # array_lit: capture new array
    mov r15, rax # assign L30
    mov rbx, 0 # assign L31
    jmp .Lb8b9_rt_str_center_bb9 # branch
.Lb8b9_rt_str_center_bb9:
    cmp rbx, r12 # binop <
    setl al # binop < → al
    movzx r13, al # zero-extend al into dst
    test r13, r13 # br_cond test
    jz .Lb8b9_rt_str_center_bb11 # jump-if-zero -> else
    jmp .Lb8b9_rt_str_center_bb10 # jump -> then
.Lb8b9_rt_str_center_bb10:
    mov rsi, r15 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, rdx # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_array_push # call hexa_array_push
    mov rax, rdx # hv: unbox call result (rdx)
    mov r12, rbx # binop lhs into dst
    add r12, 1 # binop +
    mov rbx, r12 # assign L31
    jmp .Lb8b9_rt_str_center_bb9 # branch
.Lb8b9_rt_str_center_bb11:
    mov rsi, r15 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, rdi # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_array_push # call hexa_array_push
    mov r13, rdx # hv: unbox call result (rdx)
    mov rax, 0 # assign L36
    jmp .Lb8b9_rt_str_center_bb12 # branch
.Lb8b9_rt_str_center_bb12:
    cmp rax, r14 # binop <
    setl al # binop < → al
    movzx rbx, al # zero-extend al into dst
    test rbx, rbx # br_cond test
    jz .Lb8b9_rt_str_center_bb14 # jump-if-zero -> else
    jmp .Lb8b9_rt_str_center_bb13 # jump -> then
.Lb8b9_rt_str_center_bb13:
    mov rsi, r15 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    mov rcx, rdx # hv arg payload
    mov rdx, 0 # hv arg tag = 0
    call hexa_array_push # call hexa_array_push
    mov r12, rdx # hv: unbox call result (rdx)
    mov r13, rax # binop lhs into dst
    add r13, 1 # binop +
    mov rax, r13 # assign L36
    jmp .Lb8b9_rt_str_center_bb12 # branch
.Lb8b9_rt_str_center_bb14:
    mov rsi, r15 # hv arg payload
    mov rdi, 0 # hv arg tag = 0
    lea rcx, [rip+.LCstr1] # hv arg payload: &str .LCstr1
    mov rdx, 3 # hv arg tag = 3
    call hexa_str_join # call hexa_str_join
    mov r14, rdx # hv: unbox call result (rdx)
    mov rax, r14 # set return value
    pop rbp # epilogue: restore rbp
    ret # return
.section .rodata
.LCstr0:
    .byte 0x0a, 0x00
.section .rodata
.LCstr1:
    .byte 0x00
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
