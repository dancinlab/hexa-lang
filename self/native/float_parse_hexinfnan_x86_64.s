// float_parse_hexinfnan_x86_64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 NUM-FLOAT — sh-float-hexinfnan).
// GENERATED: tool/regen_float_parse_hexinfnan_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=x86_64-linux-gnu -o float_parse_hexinfnan_x86_64.s stdlib/runtime/float_parse_hexinfnan.hexa.
//   Provides the STRTOD TAIL (rt_str_parse_float_hexinfnan) — the native
//   IEEE-bit-exact hex-float / inf / nan(payload) / malformed string->f64 body
//   (hex exact-by-construction integer round-half-even + inf/nan constants +
//   glibc/Apple nan-payload parse) that replaces the LAST inputs libc strtod
//   served, after the Clinger fast + big-integer EXACT finite tiers decline.
//   Bit-exact to the LINKED host libc strtod (glibc + Apple, cross-probed);
//   returns a TAG_VOID sentinel for true junk so the C wrapper still falls back.
//   These leaves are gen2-native-only (the hexat C-transpile bootstrap cannot
//   lower them), so the body enters the shipped runtime.a ONLY via this seed.
//   ABI: ELF, rt_str_parse_float_hexinfnan no underscore. External: hexa string/value runtime (resolved within runtime.a).
//   Lets stage_resolve_runtime_a define HEXA_RT_STRTOD_TAIL_NATIVE (opt-IN,
//   default-OFF) + ar this .o into runtime.a so __hexa_num_parse_float composes
//   fast(Clinger) -> exact(big-int) -> tail(this) -> C strtod.
# hexa-lang emit pass — target=x86_64-linux-gnu
# source: /home/aiden/hexa-lang/stdlib/runtime/float_parse_hexinfnan.hexa
.intel_syntax noprefix
.file 1 "stdlib/runtime/float_parse_hexinfnan.hexa"
.text
.globl hpx_assemble
.hidden hpx_assemble
    .p2align 4
hpx_assemble:
    .loc 1 59 0
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
.La4b0_hpx_assemble_bb0:
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
    mov rdx, 0 # tag L3 = TAG_INT (i64-local, fused)
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r15, rdx # binop +: capture result payload
    mov [rbp - 144], rax # store tag L4
    mov r10, r15 # assign L5
    mov r11, 0 # tag L4 = TAG_INT (i64-local, fused)
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
    jz .La4b0_hpx_assemble_bb2 # jump-if-zero -> else
    jmp .La4b0_hpx_assemble_bb1 # jump -> then
.La4b0_hpx_assemble_bb1:
    mov r10, 0 # binop lhs into dst
    mov r11, 9223372036854775807 # materialize wide imm to reg (x86 ALU imm is imm32)
    sub r10, r11 # binop -
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 176], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov r10, r10 # binop lhs into dst
    sub r10, 1 # binop -
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 184], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r10, r10 # binop lhs into dst
    add r10, r11 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 192], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L5
    mov r11, 0 # tag L10 = TAG_INT (i64-local, fused)
    mov [rbp - 152], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    jmp .La4b0_hpx_assemble_bb2 # branch
.La4b0_hpx_assemble_bb2:
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, 0 # tag L5 = TAG_INT (i64-local, fused)
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
.globl hpx_pack
.hidden hpx_pack
    .p2align 4
hpx_pack:
    .loc 1 72 0
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
    mov [rbp - 424], r8 # store tag L2
    mov r13, r9 # ingress param payload
    mov r10, [rbp + 16] # ingress stack param 3 tag
    mov [rbp - 432], r10 # store tag L3
    mov r10, [rbp + 24] # ingress stack param 3 payload
    mov r14, r10 # ingress stack param payload
.La4b0_hpx_pack_bb0:
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 416] # tag L1 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r15, rdx # binop ==: capture bool payload
    mov [rbp - 440], rax # store tag L4
    test r15, r15 # br_cond test
    jz .La4b0_hpx_pack_bb2 # jump-if-zero -> else
    jmp .La4b0_hpx_pack_bb1 # jump -> then
.La4b0_hpx_pack_bb1:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 408] # tag L0 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    mov r9, 0 # hv arg payload
    mov r8, 0 # tag default = TAG_INT
    call hpx_assemble # call hpx_assemble
    mov [rbp - 456], rax # store tag L6
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 64], r10 # spill L6 to slot
    mov rdx, [rbp - 64] # reload L6 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 456] # tag L6 from tag-slot
    add rsp, 752 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.La4b0_hpx_pack_bb2:
    mov r10, 0 # assign L7
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 464], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, r12 # assign L8
    mov r11, [rbp - 416] # tag L1 from tag-slot
    mov [rbp - 472], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    jmp .La4b0_hpx_pack_bb3 # branch
.La4b0_hpx_pack_bb3:
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 472] # tag L8 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 480], rax # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_pack_bb5 # jump-if-zero -> else
    jmp .La4b0_hpx_pack_bb4 # jump -> then
.La4b0_hpx_pack_bb4:
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 472] # tag L8 from tag-slot
    mov rcx, 2 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 488], rax # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L8
    mov r11, 0 # tag L10 = TAG_INT (i64-local, fused)
    mov [rbp - 472], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # binop lhs into dst
    add r10, 1 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 496], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L7
    mov r11, 0 # tag L11 = TAG_INT (i64-local, fused)
    mov [rbp - 464], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    jmp .La4b0_hpx_pack_bb3 # branch
.La4b0_hpx_pack_bb5:
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 424] # tag L2 from tag-slot
    mov rcx, [rbp - 72] # reload L7 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, 0 # tag L7 = TAG_INT (i64-local, fused)
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 504], rax # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov r10, r10 # binop lhs into dst
    sub r10, 1 # binop -
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 512], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov r10, r10 # binop lhs into dst
    add r10, 1023 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 520], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, 0 # tag L14 = TAG_INT (i64-local, fused)
    mov [rbp - 528], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    cmp r10, 2047 # binop >=
    setge al # binop >= → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 536], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r10, [rbp - 144] # reload L16 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_pack_bb7 # jump-if-zero -> else
    jmp .La4b0_hpx_pack_bb6 # jump -> then
.La4b0_hpx_pack_bb6:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 408] # tag L0 from tag-slot
    mov rcx, 2047 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    mov r9, 0 # hv arg payload
    mov r8, 0 # tag default = TAG_INT
    call hpx_assemble # call hpx_assemble
    mov [rbp - 552], rax # store tag L18
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 160], r10 # spill L18 to slot
    mov rdx, [rbp - 160] # reload L18 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 552] # tag L18 from tag-slot
    add rsp, 752 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.La4b0_hpx_pack_bb7:
    mov r10, 0 # assign L19
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 560], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    cmp r10, 1 # binop >=
    setge al # binop >= → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 568], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, [rbp - 176] # reload L20 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_pack_bb9 # jump-if-zero -> else
    jmp .La4b0_hpx_pack_bb8 # jump -> then
.La4b0_hpx_pack_bb8:
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # binop lhs into dst
    sub r10, 53 # binop -
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 584], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r10, r11 # assign L19
    mov r11, 0 # tag L22 = TAG_INT (i64-local, fused)
    mov [rbp - 560], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    jmp .La4b0_hpx_pack_bb10 # branch
.La4b0_hpx_pack_bb9:
    mov r10, 0 # binop lhs into dst
    sub r10, 1074 # binop -
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 592], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r10, [rbp - 200] # reload L23 from spill slot
    mov rsi, [rbp - 200] # reload L23 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, 0 # tag L23 = TAG_INT (i64-local, fused)
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 424] # tag L2 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 600], rax # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r11, [rbp - 208] # reload L24 from spill slot
    mov r10, r11 # assign L19
    mov r11, 0 # tag L24 = TAG_INT (i64-local, fused)
    mov [rbp - 560], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    jmp .La4b0_hpx_pack_bb10 # branch
.La4b0_hpx_pack_bb10:
    mov r10, [rbp - 168] # reload L19 from spill slot
    cmp r10, 0 # binop <=
    setle al # binop <= → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 608], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r10, [rbp - 216] # reload L25 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_pack_bb12 # jump-if-zero -> else
    jmp .La4b0_hpx_pack_bb11 # jump -> then
.La4b0_hpx_pack_bb11:
    mov r10, [rbp - 136] # reload L15 from spill slot
    cmp r10, 1 # binop >=
    setge al # binop >= → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 624], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov r10, [rbp - 232] # reload L27 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_pack_bb14 # jump-if-zero -> else
    jmp .La4b0_hpx_pack_bb13 # jump -> then
.La4b0_hpx_pack_bb12:
    sub rsp, 32 # hv: reserve 2 16B stack arg slots
    mov r11, [rbp - 136] # reload L15 from spill slot
    mov r11, r11 # hv arg payload
    mov r10, 0 # tag L15 = TAG_INT (i64-local, fused)
    mov [rsp + 16], r10 # hv stack arg 4 tag
    mov [rsp + 24], r11 # hv stack arg 4 payload
    mov r11, r14 # hv arg payload
    mov r10, [rbp - 432] # tag L3 from tag-slot
    mov [rsp], r10 # hv stack arg 3 tag
    mov [rsp + 8], r11 # hv stack arg 3 payload
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 408] # tag L0 from tag-slot
    mov rcx, r12 # hv arg payload
    mov rdx, [rbp - 416] # tag L1 from tag-slot
    mov r9, [rbp - 168] # reload L19 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, 0 # tag L19 = TAG_INT (i64-local, fused)
    call hpx_round_shift # call hpx_round_shift
    add rsp, 32 # hv: pop 2 stack arg slots
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
.La4b0_hpx_pack_bb13:
    mov r10, r12 # assign L29
    mov r11, [rbp - 416] # tag L1 from tag-slot
    mov [rbp - 640], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r10, 53 # binop lhs into dst
    sub r10, r11 # binop -
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 648], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r11, [rbp - 256] # reload L30 from spill slot
    mov r10, r11 # assign L31
    mov r11, 0 # tag L30 = TAG_INT (i64-local, fused)
    mov [rbp - 656], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    jmp .La4b0_hpx_pack_bb15 # branch
.La4b0_hpx_pack_bb14:
    mov r10, r12 # assign L37
    mov r11, [rbp - 416] # tag L1 from tag-slot
    mov [rbp - 704], r11 # store tag L37
    mov [rbp - 312], r10 # spill L37 to slot
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 424] # tag L2 from tag-slot
    mov rcx, 1074 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 712], rax # store tag L38
    mov [rbp - 320], r10 # spill L38 to slot
    mov r11, [rbp - 320] # reload L38 from spill slot
    mov r10, r11 # assign L39
    mov r11, 0 # tag L38 = TAG_INT (i64-local, fused)
    mov [rbp - 720], r11 # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    jmp .La4b0_hpx_pack_bb18 # branch
.La4b0_hpx_pack_bb15:
    mov r10, [rbp - 264] # reload L31 from spill slot
    cmp r10, 0 # binop >
    setg al # binop > → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 664], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r10, [rbp - 272] # reload L32 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_pack_bb17 # jump-if-zero -> else
    jmp .La4b0_hpx_pack_bb16 # jump -> then
.La4b0_hpx_pack_bb16:
    mov r10, [rbp - 248] # reload L29 from spill slot
    mov rsi, [rbp - 248] # reload L29 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 640] # tag L29 from tag-slot
    mov rcx, 2 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 672], rax # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r11, [rbp - 280] # reload L33 from spill slot
    mov r10, r11 # assign L29
    mov r11, 0 # tag L33 = TAG_INT (i64-local, fused)
    mov [rbp - 640], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r10, [rbp - 264] # reload L31 from spill slot
    mov r10, r10 # binop lhs into dst
    sub r10, 1 # binop -
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 680], r11 # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    mov r11, [rbp - 288] # reload L34 from spill slot
    mov r10, r11 # assign L31
    mov r11, 0 # tag L34 = TAG_INT (i64-local, fused)
    mov [rbp - 656], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    jmp .La4b0_hpx_pack_bb15 # branch
.La4b0_hpx_pack_bb17:
    mov r10, [rbp - 248] # reload L29 from spill slot
    mov rsi, [rbp - 248] # reload L29 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 640] # tag L29 from tag-slot
    mov rcx, 4503599627370496 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 688], rax # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 408] # tag L0 from tag-slot
    mov rcx, [rbp - 136] # reload L15 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, 0 # tag L15 = TAG_INT (i64-local, fused)
    mov r9, [rbp - 296] # reload L35 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, 0 # tag L35 = TAG_INT (i64-local, fused)
    call hpx_assemble # call hpx_assemble
    mov [rbp - 696], rax # store tag L36
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 304], r10 # spill L36 to slot
    mov rdx, [rbp - 304] # reload L36 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 696] # tag L36 from tag-slot
    add rsp, 752 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.La4b0_hpx_pack_bb18:
    mov r10, [rbp - 328] # reload L39 from spill slot
    cmp r10, 0 # binop >
    setg al # binop > → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 728], r11 # store tag L40
    mov [rbp - 336], r10 # spill L40 to slot
    mov r10, [rbp - 336] # reload L40 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_pack_bb20 # jump-if-zero -> else
    jmp .La4b0_hpx_pack_bb19 # jump -> then
.La4b0_hpx_pack_bb19:
    mov r10, [rbp - 312] # reload L37 from spill slot
    mov rsi, [rbp - 312] # reload L37 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 704] # tag L37 from tag-slot
    mov rcx, 2 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 736], rax # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    mov r11, [rbp - 344] # reload L41 from spill slot
    mov r10, r11 # assign L37
    mov r11, 0 # tag L41 = TAG_INT (i64-local, fused)
    mov [rbp - 704], r11 # store tag L37
    mov [rbp - 312], r10 # spill L37 to slot
    mov r10, [rbp - 328] # reload L39 from spill slot
    mov r10, r10 # binop lhs into dst
    sub r10, 1 # binop -
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 744], r11 # store tag L42
    mov [rbp - 352], r10 # spill L42 to slot
    mov r11, [rbp - 352] # reload L42 from spill slot
    mov r10, r11 # assign L39
    mov r11, 0 # tag L42 = TAG_INT (i64-local, fused)
    mov [rbp - 720], r11 # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    jmp .La4b0_hpx_pack_bb18 # branch
.La4b0_hpx_pack_bb20:
    mov r10, [rbp - 312] # reload L37 from spill slot
    mov rsi, [rbp - 312] # reload L37 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 704] # tag L37 from tag-slot
    mov rcx, 4503599627370496 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 752], rax # store tag L43
    mov [rbp - 360], r10 # spill L43 to slot
    mov r10, [rbp - 360] # reload L43 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_pack_bb22 # jump-if-zero -> else
    jmp .La4b0_hpx_pack_bb21 # jump -> then
.La4b0_hpx_pack_bb21:
    mov r10, [rbp - 312] # reload L37 from spill slot
    mov rsi, [rbp - 312] # reload L37 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 704] # tag L37 from tag-slot
    mov rcx, 4503599627370496 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 768], rax # store tag L45
    mov [rbp - 376], r10 # spill L45 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 408] # tag L0 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    mov r9, [rbp - 376] # reload L45 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, 0 # tag L45 = TAG_INT (i64-local, fused)
    call hpx_assemble # call hpx_assemble
    mov [rbp - 776], rax # store tag L46
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 384], r10 # spill L46 to slot
    mov rdx, [rbp - 384] # reload L46 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 776] # tag L46 from tag-slot
    add rsp, 752 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.La4b0_hpx_pack_bb22:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 408] # tag L0 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    mov r9, [rbp - 312] # reload L37 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 704] # tag L37 from tag-slot
    call hpx_assemble # call hpx_assemble
    mov [rbp - 784], rax # store tag L47
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 392], r10 # spill L47 to slot
    mov rdx, [rbp - 392] # reload L47 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 784] # tag L47 from tag-slot
    add rsp, 752 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hpx_round_shift
.hidden hpx_round_shift
    .p2align 4
hpx_round_shift:
    .loc 1 132 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 896 # prologue: alloc spill frame
    mov [rbp - 480], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 488], rdx # store tag L1
    mov r12, rcx # ingress param payload
    mov [rbp - 496], r8 # store tag L2
    mov r13, r9 # ingress param payload
    mov r10, [rbp + 16] # ingress stack param 3 tag
    mov [rbp - 504], r10 # store tag L3
    mov r10, [rbp + 24] # ingress stack param 3 payload
    mov r14, r10 # ingress stack param payload
    mov r10, [rbp + 32] # ingress stack param 4 tag
    mov [rbp - 512], r10 # store tag L4
    mov r10, [rbp + 40] # ingress stack param 4 payload
    mov r15, r10 # ingress stack param payload
.La4b0_hpx_round_shift_bb0:
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 496] # tag L2 from tag-slot
    mov rcx, 64 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 520], rax # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_round_shift_bb2 # jump-if-zero -> else
    jmp .La4b0_hpx_round_shift_bb1 # jump -> then
.La4b0_hpx_round_shift_bb1:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 480] # tag L0 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    mov r9, 0 # hv arg payload
    mov r8, 0 # tag default = TAG_INT
    call hpx_assemble # call hpx_assemble
    mov [rbp - 536], rax # store tag L7
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 72], r10 # spill L7 to slot
    mov rdx, [rbp - 72] # reload L7 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 536] # tag L7 from tag-slot
    add rsp, 896 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.La4b0_hpx_round_shift_bb2:
    mov r10, r12 # assign L8
    mov r11, [rbp - 488] # tag L1 from tag-slot
    mov [rbp - 544], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, r13 # assign L9
    mov r11, [rbp - 496] # tag L2 from tag-slot
    mov [rbp - 552], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, r14 # assign L10
    mov r11, [rbp - 504] # tag L3 from tag-slot
    mov [rbp - 560], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    jmp .La4b0_hpx_round_shift_bb3 # branch
.La4b0_hpx_round_shift_bb3:
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 552] # tag L9 from tag-slot
    mov rcx, 62 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 568], rax # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 104] # reload L11 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_round_shift_bb5 # jump-if-zero -> else
    jmp .La4b0_hpx_round_shift_bb4 # jump -> then
.La4b0_hpx_round_shift_bb4:
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 544] # tag L8 from tag-slot
    mov rcx, 2 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mod # binop %: tag-dispatch hexa_mod
    mov r10, rdx # binop %: capture result payload
    mov [rbp - 576], rax # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    cmp r10, 1 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 584], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 120] # reload L13 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_round_shift_bb7 # jump-if-zero -> else
    jmp .La4b0_hpx_round_shift_bb6 # jump -> then
.La4b0_hpx_round_shift_bb5:
    mov r10, 1 # assign L17
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 616], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, 0 # assign L18
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 624], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    jmp .La4b0_hpx_round_shift_bb8 # branch
.La4b0_hpx_round_shift_bb6:
    mov r10, 1 # assign L10
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 560], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    jmp .La4b0_hpx_round_shift_bb7 # branch
.La4b0_hpx_round_shift_bb7:
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 544] # tag L8 from tag-slot
    mov rcx, 2 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 600], rax # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, [rbp - 136] # reload L15 from spill slot
    mov r10, r11 # assign L8
    mov r11, 0 # tag L15 = TAG_INT (i64-local, fused)
    mov [rbp - 544], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 552] # tag L9 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 608], rax # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L9
    mov r11, 0 # tag L16 = TAG_INT (i64-local, fused)
    mov [rbp - 552], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    jmp .La4b0_hpx_round_shift_bb3 # branch
.La4b0_hpx_round_shift_bb8:
    mov r10, [rbp - 160] # reload L18 from spill slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 160] # reload L18 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, 0 # tag L18 = TAG_INT (i64-local, fused)
    mov rcx, [rbp - 88] # reload L9 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 552] # tag L9 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 632], rax # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r10, [rbp - 168] # reload L19 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_round_shift_bb10 # jump-if-zero -> else
    jmp .La4b0_hpx_round_shift_bb9 # jump -> then
.La4b0_hpx_round_shift_bb9:
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # binop lhs into dst
    imul r10, 2 # binop *
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 640], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r11, [rbp - 176] # reload L20 from spill slot
    mov r10, r11 # assign L17
    mov r11, 0 # tag L20 = TAG_INT (i64-local, fused)
    mov [rbp - 616], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 160] # reload L18 from spill slot
    mov r10, r10 # binop lhs into dst
    add r10, 1 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 648], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L18
    mov r11, 0 # tag L21 = TAG_INT (i64-local, fused)
    mov [rbp - 624], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    jmp .La4b0_hpx_round_shift_bb8 # branch
.La4b0_hpx_round_shift_bb10:
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov r11, [rbp - 152] # reload L17 from spill slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 544] # tag L8 from tag-slot
    mov rcx, [rbp - 152] # reload L17 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, 0 # tag L17 = TAG_INT (i64-local, fused)
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 656], rax # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r10, r11 # assign L23
    mov r11, 0 # tag L22 = TAG_INT (i64-local, fused)
    mov [rbp - 664], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov r11, [rbp - 152] # reload L17 from spill slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 544] # tag L8 from tag-slot
    mov rcx, [rbp - 152] # reload L17 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, 0 # tag L17 = TAG_INT (i64-local, fused)
    call hexa_mod # binop %: tag-dispatch hexa_mod
    mov r10, rdx # binop %: capture result payload
    mov [rbp - 672], rax # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r11, [rbp - 208] # reload L24 from spill slot
    mov r10, r11 # assign L25
    mov r11, 0 # tag L24 = TAG_INT (i64-local, fused)
    mov [rbp - 680], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # magicdiv: r10 = dividend
    mov rax, r10 # magicdiv: rax = dividend
    mov r11, -9223372036854775807 # magicdiv: r11 = signed magic M (movabs imm64)
    imul r11 # magicdiv: rdx:rax = dividend * M (hi → rdx)
    add rdx, r10 # magicdiv: M<0 correction (rdx += dividend)
    mov rax, rdx # magicdiv: rax = t0 (copy for signbit)
    shr rax, 63 # magicdiv: rax = signbit(t0)
    add rdx, rax # magicdiv: rdx = quotient = (t0>>s) + signbit
    mov r10, rdx # magicdiv: dst = quotient (/)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 688], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r11, [rbp - 224] # reload L26 from spill slot
    mov r10, r11 # assign L27
    mov r11, 0 # tag L26 = TAG_INT (i64-local, fused)
    mov [rbp - 696], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L28
    mov r11, 0 # tag L23 = TAG_INT (i64-local, fused)
    mov [rbp - 704], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r10, [rbp - 216] # reload L25 from spill slot
    mov r11, [rbp - 232] # reload L27 from spill slot
    cmp r10, r11 # binop >
    setg al # binop > → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 712], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r10, [rbp - 248] # reload L29 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_round_shift_bb12 # jump-if-zero -> else
    jmp .La4b0_hpx_round_shift_bb11 # jump -> then
.La4b0_hpx_round_shift_bb11:
    mov r10, [rbp - 240] # reload L28 from spill slot
    mov r10, r10 # binop lhs into dst
    add r10, 1 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 728], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov r11, [rbp - 264] # reload L31 from spill slot
    mov r10, r11 # assign L28
    mov r11, 0 # tag L31 = TAG_INT (i64-local, fused)
    mov [rbp - 704], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    jmp .La4b0_hpx_round_shift_bb20 # branch
.La4b0_hpx_round_shift_bb12:
    mov r10, [rbp - 216] # reload L25 from spill slot
    mov r11, [rbp - 232] # reload L27 from spill slot
    cmp r10, r11 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 736], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r10, [rbp - 272] # reload L32 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_round_shift_bb14 # jump-if-zero -> else
    jmp .La4b0_hpx_round_shift_bb13 # jump -> then
.La4b0_hpx_round_shift_bb13:
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov rsi, [rbp - 96] # reload L10 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 560] # tag L10 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 752], rax # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    mov r10, [rbp - 288] # reload L34 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_round_shift_bb16 # jump-if-zero -> else
    jmp .La4b0_hpx_round_shift_bb15 # jump -> then
.La4b0_hpx_round_shift_bb14:
    jmp .La4b0_hpx_round_shift_bb20 # branch
.La4b0_hpx_round_shift_bb15:
    mov r10, [rbp - 240] # reload L28 from spill slot
    mov r10, r10 # binop lhs into dst
    add r10, 1 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 768], r11 # store tag L36
    mov [rbp - 304], r10 # spill L36 to slot
    mov r11, [rbp - 304] # reload L36 from spill slot
    mov r10, r11 # assign L28
    mov r11, 0 # tag L36 = TAG_INT (i64-local, fused)
    mov [rbp - 704], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    jmp .La4b0_hpx_round_shift_bb19 # branch
.La4b0_hpx_round_shift_bb16:
    mov r10, [rbp - 240] # reload L28 from spill slot
    mov r10, r10 # magicdiv: r10 = dividend
    mov rax, r10 # magicdiv: rax = dividend
    mov r11, -9223372036854775807 # magicdiv: r11 = signed magic M (movabs imm64)
    imul r11 # magicdiv: rdx:rax = dividend * M (hi → rdx)
    add rdx, r10 # magicdiv: M<0 correction (rdx += dividend)
    mov rax, rdx # magicdiv: rax = t0 (copy for signbit)
    shr rax, 63 # magicdiv: rax = signbit(t0)
    add rdx, rax # magicdiv: rdx = quotient = (t0>>s) + signbit
    imul rax, rdx, 2 # magicdiv: rax = quotient * d
    sub r10, rax # magicdiv: r10 = dividend - quotient*d (remainder)
    mov r10, r10 # magicdiv: dst = remainder (%)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 776], r11 # store tag L37
    mov [rbp - 312], r10 # spill L37 to slot
    mov r10, [rbp - 312] # reload L37 from spill slot
    cmp r10, 1 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 784], r11 # store tag L38
    mov [rbp - 320], r10 # spill L38 to slot
    mov r10, [rbp - 320] # reload L38 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_round_shift_bb18 # jump-if-zero -> else
    jmp .La4b0_hpx_round_shift_bb17 # jump -> then
.La4b0_hpx_round_shift_bb17:
    mov r10, [rbp - 240] # reload L28 from spill slot
    mov r10, r10 # binop lhs into dst
    add r10, 1 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 800], r11 # store tag L40
    mov [rbp - 336], r10 # spill L40 to slot
    mov r11, [rbp - 336] # reload L40 from spill slot
    mov r10, r11 # assign L28
    mov r11, 0 # tag L40 = TAG_INT (i64-local, fused)
    mov [rbp - 704], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    jmp .La4b0_hpx_round_shift_bb18 # branch
.La4b0_hpx_round_shift_bb18:
    jmp .La4b0_hpx_round_shift_bb19 # branch
.La4b0_hpx_round_shift_bb19:
    jmp .La4b0_hpx_round_shift_bb14 # branch
.La4b0_hpx_round_shift_bb20:
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 512] # tag L4 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 808], rax # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    mov r10, [rbp - 344] # reload L41 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_round_shift_bb22 # jump-if-zero -> else
    jmp .La4b0_hpx_round_shift_bb21 # jump -> then
.La4b0_hpx_round_shift_bb21:
    mov r10, r15 # assign L43
    mov r11, [rbp - 512] # tag L4 from tag-slot
    mov [rbp - 824], r11 # store tag L43
    mov [rbp - 360], r10 # spill L43 to slot
    mov r10, [rbp - 240] # reload L28 from spill slot
    mov r11, 9007199254740992 # materialize wide cmp imm to reg (x86 cmp imm is imm32)
    cmp r10, r11 # binop >=
    setge al # binop >= → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 832], r11 # store tag L44
    mov [rbp - 368], r10 # spill L44 to slot
    mov r10, [rbp - 368] # reload L44 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_round_shift_bb24 # jump-if-zero -> else
    jmp .La4b0_hpx_round_shift_bb23 # jump -> then
.La4b0_hpx_round_shift_bb22:
    mov r10, [rbp - 240] # reload L28 from spill slot
    mov r11, 4503599627370496 # materialize wide cmp imm to reg (x86 cmp imm is imm32)
    cmp r10, r11 # binop >=
    setge al # binop >= → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 904], r11 # store tag L53
    mov [rbp - 440], r10 # spill L53 to slot
    mov r10, [rbp - 440] # reload L53 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_round_shift_bb28 # jump-if-zero -> else
    jmp .La4b0_hpx_round_shift_bb27 # jump -> then
.La4b0_hpx_round_shift_bb23:
    mov r10, [rbp - 240] # reload L28 from spill slot
    mov r10, r10 # magicdiv: r10 = dividend
    mov rax, r10 # magicdiv: rax = dividend
    mov r11, -9223372036854775807 # magicdiv: r11 = signed magic M (movabs imm64)
    imul r11 # magicdiv: rdx:rax = dividend * M (hi → rdx)
    add rdx, r10 # magicdiv: M<0 correction (rdx += dividend)
    mov rax, rdx # magicdiv: rax = t0 (copy for signbit)
    shr rax, 63 # magicdiv: rax = signbit(t0)
    add rdx, rax # magicdiv: rdx = quotient = (t0>>s) + signbit
    mov r10, rdx # magicdiv: dst = quotient (/)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 848], r11 # store tag L46
    mov [rbp - 384], r10 # spill L46 to slot
    mov r11, [rbp - 384] # reload L46 from spill slot
    mov r10, r11 # assign L28
    mov r11, 0 # tag L46 = TAG_INT (i64-local, fused)
    mov [rbp - 704], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r10, [rbp - 360] # reload L43 from spill slot
    mov rsi, [rbp - 360] # reload L43 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 824] # tag L43 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 856], rax # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    mov r11, [rbp - 392] # reload L47 from spill slot
    mov r10, r11 # assign L43
    mov r11, 0 # tag L47 = TAG_INT (i64-local, fused)
    mov [rbp - 824], r11 # store tag L43
    mov [rbp - 360], r10 # spill L43 to slot
    mov r10, [rbp - 360] # reload L43 from spill slot
    mov rsi, [rbp - 360] # reload L43 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 824] # tag L43 from tag-slot
    mov rcx, 2047 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 864], rax # store tag L48
    mov [rbp - 400], r10 # spill L48 to slot
    mov r10, [rbp - 400] # reload L48 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_round_shift_bb26 # jump-if-zero -> else
    jmp .La4b0_hpx_round_shift_bb25 # jump -> then
.La4b0_hpx_round_shift_bb24:
    mov r10, [rbp - 240] # reload L28 from spill slot
    mov r10, r10 # binop lhs into dst
    mov r11, 4503599627370496 # materialize wide imm to reg (x86 ALU imm is imm32)
    sub r10, r11 # binop -
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 888], r11 # store tag L51
    mov [rbp - 424], r10 # spill L51 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 480] # tag L0 from tag-slot
    mov rcx, [rbp - 360] # reload L43 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 824] # tag L43 from tag-slot
    mov r9, [rbp - 424] # reload L51 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, 0 # tag L51 = TAG_INT (i64-local, fused)
    call hpx_assemble # call hpx_assemble
    mov [rbp - 896], rax # store tag L52
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 432], r10 # spill L52 to slot
    mov rdx, [rbp - 432] # reload L52 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 896] # tag L52 from tag-slot
    add rsp, 896 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.La4b0_hpx_round_shift_bb25:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 480] # tag L0 from tag-slot
    mov rcx, 2047 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    mov r9, 0 # hv arg payload
    mov r8, 0 # tag default = TAG_INT
    call hpx_assemble # call hpx_assemble
    mov [rbp - 880], rax # store tag L50
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 416], r10 # spill L50 to slot
    mov rdx, [rbp - 416] # reload L50 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 880] # tag L50 from tag-slot
    add rsp, 896 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.La4b0_hpx_round_shift_bb26:
    jmp .La4b0_hpx_round_shift_bb24 # branch
.La4b0_hpx_round_shift_bb27:
    mov r10, [rbp - 240] # reload L28 from spill slot
    mov r10, r10 # binop lhs into dst
    mov r11, 4503599627370496 # materialize wide imm to reg (x86 ALU imm is imm32)
    sub r10, r11 # binop -
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 920], r11 # store tag L55
    mov [rbp - 456], r10 # spill L55 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 480] # tag L0 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    mov r9, [rbp - 456] # reload L55 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, 0 # tag L55 = TAG_INT (i64-local, fused)
    call hpx_assemble # call hpx_assemble
    mov [rbp - 928], rax # store tag L56
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 464], r10 # spill L56 to slot
    mov rdx, [rbp - 464] # reload L56 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 928] # tag L56 from tag-slot
    add rsp, 896 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.La4b0_hpx_round_shift_bb28:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 480] # tag L0 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    mov r9, [rbp - 240] # reload L28 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, 0 # tag L28 = TAG_INT (i64-local, fused)
    call hpx_assemble # call hpx_assemble
    mov [rbp - 936], rax # store tag L57
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 472], r10 # spill L57 to slot
    mov rdx, [rbp - 472] # reload L57 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 936] # tag L57 from tag-slot
    add rsp, 896 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hpx_hexfloat
.hidden hpx_hexfloat
    .p2align 4
hpx_hexfloat:
    .loc 1 193 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 1680 # prologue: alloc spill frame
    mov [rbp - 872], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 880], rdx # store tag L1
    mov r12, rcx # ingress param payload
    mov [rbp - 888], r8 # store tag L2
    mov r13, r9 # ingress param payload
    mov r10, [rbp + 16] # ingress stack param 3 tag
    mov [rbp - 896], r10 # store tag L3
    mov r10, [rbp + 24] # ingress stack param 3 payload
    mov r14, r10 # ingress stack param payload
.La4b0_hpx_hexfloat_bb0:
    mov r15, r12 # assign L4
    mov r11, [rbp - 880] # tag L1 from tag-slot
    mov [rbp - 904], r11 # store tag L4
    mov r10, 0 # assign L5
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 912], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, 0 # assign L6
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 920], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, 0 # assign L7
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 928], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, 0 # assign L8
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 936], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, 0 # assign L9
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 944], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, 1 # assign L10
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 952], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    jmp .La4b0_hpx_hexfloat_bb1 # branch
.La4b0_hpx_hexfloat_bb1:
    mov r10, [rbp - 96] # reload L10 from spill slot
    cmp r10, 1 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 960], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 104] # reload L11 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb5 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb4 # jump -> then
.La4b0_hpx_hexfloat_bb2:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 872] # tag L0 from tag-slot
    mov rcx, r15 # hv arg payload
    mov rdx, [rbp - 904] # tag L4 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 984], rax # store tag L14
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 984] # tag L14 from tag-slot
    mov [rbp - 992], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, 0 # binop lhs into dst
    sub r10, 1 # binop -
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1000], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, 0 # tag L16 = TAG_INT (i64-local, fused)
    mov [rbp - 1008], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 992] # tag L15 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 1016], rax # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r10, [rbp - 160] # reload L18 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb8 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb7 # jump -> then
.La4b0_hpx_hexfloat_bb3:
    mov r10, [rbp - 64] # reload L6 from spill slot
    cmp r10, 0 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1296], r11 # store tag L53
    mov [rbp - 440], r10 # spill L53 to slot
    mov r10, [rbp - 440] # reload L53 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb43 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb42 # jump -> then
.La4b0_hpx_hexfloat_bb4:
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 904] # tag L4 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 888] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 976], rax # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 976] # tag L13 from tag-slot
    mov [rbp - 968], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    jmp .La4b0_hpx_hexfloat_bb6 # branch
.La4b0_hpx_hexfloat_bb5:
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 960] # tag L11 from tag-slot
    mov [rbp - 968], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    jmp .La4b0_hpx_hexfloat_bb6 # branch
.La4b0_hpx_hexfloat_bb6:
    mov r10, [rbp - 112] # reload L12 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb3 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb2 # jump -> then
.La4b0_hpx_hexfloat_bb7:
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 992] # tag L15 from tag-slot
    mov rcx, 57 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 1032], rax # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r11, [rbp - 176] # reload L20 from spill slot
    mov r10, r11 # assign L19
    mov r11, [rbp - 1032] # tag L20 from tag-slot
    mov [rbp - 1024], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    jmp .La4b0_hpx_hexfloat_bb9 # branch
.La4b0_hpx_hexfloat_bb8:
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov r10, r11 # assign L19
    mov r11, [rbp - 1016] # tag L18 from tag-slot
    mov [rbp - 1024], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    jmp .La4b0_hpx_hexfloat_bb9 # branch
.La4b0_hpx_hexfloat_bb9:
    mov r10, [rbp - 168] # reload L19 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb11 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb10 # jump -> then
.La4b0_hpx_hexfloat_bb10:
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 992] # tag L15 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 1048], rax # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r10, r11 # assign L17
    mov r11, 0 # tag L22 = TAG_INT (i64-local, fused)
    mov [rbp - 1008], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    jmp .La4b0_hpx_hexfloat_bb23 # branch
.La4b0_hpx_hexfloat_bb11:
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 992] # tag L15 from tag-slot
    mov rcx, 97 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 1056], rax # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r10, [rbp - 200] # reload L23 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb13 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb12 # jump -> then
.La4b0_hpx_hexfloat_bb12:
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 992] # tag L15 from tag-slot
    mov rcx, 102 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 1072], rax # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r11, [rbp - 216] # reload L25 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 1072] # tag L25 from tag-slot
    mov [rbp - 1064], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    jmp .La4b0_hpx_hexfloat_bb14 # branch
.La4b0_hpx_hexfloat_bb13:
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 1056] # tag L23 from tag-slot
    mov [rbp - 1064], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    jmp .La4b0_hpx_hexfloat_bb14 # branch
.La4b0_hpx_hexfloat_bb14:
    mov r10, [rbp - 208] # reload L24 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb16 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb15 # jump -> then
.La4b0_hpx_hexfloat_bb15:
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 992] # tag L15 from tag-slot
    mov rcx, 87 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 1088], rax # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov r11, [rbp - 232] # reload L27 from spill slot
    mov r10, r11 # assign L17
    mov r11, 0 # tag L27 = TAG_INT (i64-local, fused)
    mov [rbp - 1008], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    jmp .La4b0_hpx_hexfloat_bb22 # branch
.La4b0_hpx_hexfloat_bb16:
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 992] # tag L15 from tag-slot
    mov rcx, 65 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 1096], rax # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r10, [rbp - 240] # reload L28 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb18 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb17 # jump -> then
.La4b0_hpx_hexfloat_bb17:
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 992] # tag L15 from tag-slot
    mov rcx, 70 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 1112], rax # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r11, [rbp - 256] # reload L30 from spill slot
    mov r10, r11 # assign L29
    mov r11, [rbp - 1112] # tag L30 from tag-slot
    mov [rbp - 1104], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    jmp .La4b0_hpx_hexfloat_bb19 # branch
.La4b0_hpx_hexfloat_bb18:
    mov r11, [rbp - 240] # reload L28 from spill slot
    mov r10, r11 # assign L29
    mov r11, [rbp - 1096] # tag L28 from tag-slot
    mov [rbp - 1104], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    jmp .La4b0_hpx_hexfloat_bb19 # branch
.La4b0_hpx_hexfloat_bb19:
    mov r10, [rbp - 248] # reload L29 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb21 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb20 # jump -> then
.La4b0_hpx_hexfloat_bb20:
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 992] # tag L15 from tag-slot
    mov rcx, 55 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 1128], rax # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r11, [rbp - 272] # reload L32 from spill slot
    mov r10, r11 # assign L17
    mov r11, 0 # tag L32 = TAG_INT (i64-local, fused)
    mov [rbp - 1008], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    jmp .La4b0_hpx_hexfloat_bb21 # branch
.La4b0_hpx_hexfloat_bb21:
    jmp .La4b0_hpx_hexfloat_bb22 # branch
.La4b0_hpx_hexfloat_bb22:
    jmp .La4b0_hpx_hexfloat_bb23 # branch
.La4b0_hpx_hexfloat_bb23:
    mov r10, [rbp - 152] # reload L17 from spill slot
    cmp r10, 0 # binop >=
    setge al # binop >= → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1136], r11 # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r10, [rbp - 280] # reload L33 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb25 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb24 # jump -> then
.La4b0_hpx_hexfloat_bb24:
    mov r10, 1 # assign L6
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 920], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r11, 576460752303423488 # materialize wide cmp imm to reg (x86 cmp imm is imm32)
    cmp r10, r11 # binop <
    setl al # binop < → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1152], r11 # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    mov r10, [rbp - 296] # reload L35 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb27 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb26 # jump -> then
.La4b0_hpx_hexfloat_bb25:
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 992] # tag L15 from tag-slot
    mov rcx, 46 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 1256], rax # store tag L48
    mov [rbp - 400], r10 # spill L48 to slot
    mov r10, [rbp - 400] # reload L48 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb36 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb35 # jump -> then
.La4b0_hpx_hexfloat_bb26:
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # binop lhs into dst
    imul r10, 16 # binop *
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1168], r11 # store tag L37
    mov [rbp - 312], r10 # spill L37 to slot
    mov r10, [rbp - 312] # reload L37 from spill slot
    mov r11, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # binop lhs into dst
    add r10, r11 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1176], r11 # store tag L38
    mov [rbp - 320], r10 # spill L38 to slot
    mov r11, [rbp - 320] # reload L38 from spill slot
    mov r10, r11 # assign L5
    mov r11, 0 # tag L38 = TAG_INT (i64-local, fused)
    mov [rbp - 912], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    cmp r10, 1 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1184], r11 # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    mov r10, [rbp - 328] # reload L39 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb29 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb28 # jump -> then
.La4b0_hpx_hexfloat_bb27:
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov rsi, [rbp - 152] # reload L17 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, 0 # tag L17 = TAG_INT (i64-local, fused)
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1208], r11 # store tag L42
    mov [rbp - 352], r10 # spill L42 to slot
    mov r10, [rbp - 352] # reload L42 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb31 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb30 # jump -> then
.La4b0_hpx_hexfloat_bb28:
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov r10, r10 # binop lhs into dst
    sub r10, 4 # binop -
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1200], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    mov r11, [rbp - 344] # reload L41 from spill slot
    mov r10, r11 # assign L8
    mov r11, 0 # tag L41 = TAG_INT (i64-local, fused)
    mov [rbp - 936], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    jmp .La4b0_hpx_hexfloat_bb29 # branch
.La4b0_hpx_hexfloat_bb29:
    jmp .La4b0_hpx_hexfloat_bb34 # branch
.La4b0_hpx_hexfloat_bb30:
    mov r10, 1 # assign L9
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 944], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    jmp .La4b0_hpx_hexfloat_bb31 # branch
.La4b0_hpx_hexfloat_bb31:
    mov r10, [rbp - 72] # reload L7 from spill slot
    cmp r10, 0 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1224], r11 # store tag L44
    mov [rbp - 368], r10 # spill L44 to slot
    mov r10, [rbp - 368] # reload L44 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb33 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb32 # jump -> then
.La4b0_hpx_hexfloat_bb32:
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov r10, r10 # binop lhs into dst
    add r10, 4 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1240], r11 # store tag L46
    mov [rbp - 384], r10 # spill L46 to slot
    mov r11, [rbp - 384] # reload L46 from spill slot
    mov r10, r11 # assign L8
    mov r11, 0 # tag L46 = TAG_INT (i64-local, fused)
    mov [rbp - 936], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    jmp .La4b0_hpx_hexfloat_bb33 # branch
.La4b0_hpx_hexfloat_bb33:
    jmp .La4b0_hpx_hexfloat_bb34 # branch
.La4b0_hpx_hexfloat_bb34:
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 904] # tag L4 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 1248], rax # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    mov r10, [rbp - 392] # reload L47 from spill slot
    mov r15, r10 # assign L4
    mov r11, 0 # tag L47 = TAG_INT (i64-local, fused)
    mov [rbp - 904], r11 # store tag L4
    jmp .La4b0_hpx_hexfloat_bb41 # branch
.La4b0_hpx_hexfloat_bb35:
    mov r10, [rbp - 72] # reload L7 from spill slot
    cmp r10, 1 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1272], r11 # store tag L50
    mov [rbp - 416], r10 # spill L50 to slot
    mov r10, [rbp - 416] # reload L50 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb38 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb37 # jump -> then
.La4b0_hpx_hexfloat_bb36:
    mov r10, 0 # assign L10
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 952], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    jmp .La4b0_hpx_hexfloat_bb40 # branch
.La4b0_hpx_hexfloat_bb37:
    mov r10, 0 # assign L10
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 952], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    jmp .La4b0_hpx_hexfloat_bb39 # branch
.La4b0_hpx_hexfloat_bb38:
    mov r10, 1 # assign L7
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 928], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 904] # tag L4 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 1288], rax # store tag L52
    mov [rbp - 432], r10 # spill L52 to slot
    mov r10, [rbp - 432] # reload L52 from spill slot
    mov r15, r10 # assign L4
    mov r11, 0 # tag L52 = TAG_INT (i64-local, fused)
    mov [rbp - 904], r11 # store tag L4
    jmp .La4b0_hpx_hexfloat_bb39 # branch
.La4b0_hpx_hexfloat_bb39:
    jmp .La4b0_hpx_hexfloat_bb40 # branch
.La4b0_hpx_hexfloat_bb40:
    jmp .La4b0_hpx_hexfloat_bb41 # branch
.La4b0_hpx_hexfloat_bb41:
    jmp .La4b0_hpx_hexfloat_bb1 # branch
.La4b0_hpx_hexfloat_bb42:
    mov r10, 0 # hv payload
    mov r11, 4 # hv payload
    mov [rbp - 1312], r11 # store tag L55
    mov [rbp - 456], r10 # spill L55 to slot
    mov rdx, [rbp - 456] # reload L55 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 1312] # tag L55 from tag-slot
    add rsp, 1680 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.La4b0_hpx_hexfloat_bb43:
    mov r10, 1 # assign L56
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1320], r11 # store tag L56
    mov [rbp - 464], r10 # spill L56 to slot
    mov r10, 0 # assign L57
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1328], r11 # store tag L57
    mov [rbp - 472], r10 # spill L57 to slot
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 904] # tag L4 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 888] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 1336], rax # store tag L58
    mov [rbp - 480], r10 # spill L58 to slot
    mov r10, [rbp - 480] # reload L58 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb45 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb44 # jump -> then
.La4b0_hpx_hexfloat_bb44:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 872] # tag L0 from tag-slot
    mov rcx, r15 # hv arg payload
    mov rdx, [rbp - 904] # tag L4 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 1352], rax # store tag L60
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 496], r10 # spill L60 to slot
    mov r11, [rbp - 496] # reload L60 from spill slot
    mov r10, r11 # assign L61
    mov r11, [rbp - 1352] # tag L60 from tag-slot
    mov [rbp - 1360], r11 # store tag L61
    mov [rbp - 504], r10 # spill L61 to slot
    mov r10, [rbp - 504] # reload L61 from spill slot
    mov rsi, [rbp - 504] # reload L61 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1360] # tag L61 from tag-slot
    mov rcx, 112 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 1368], rax # store tag L62
    mov [rbp - 512], r10 # spill L62 to slot
    mov r10, [rbp - 512] # reload L62 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb47 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb46 # jump -> then
.La4b0_hpx_hexfloat_bb45:
    mov r10, [rbp - 56] # reload L5 from spill slot
    cmp r10, 0 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1648], r11 # store tag L97
    mov [rbp - 792], r10 # spill L97 to slot
    mov r10, [rbp - 792] # reload L97 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb72 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb71 # jump -> then
.La4b0_hpx_hexfloat_bb46:
    mov r11, [rbp - 512] # reload L62 from spill slot
    mov r10, r11 # assign L63
    mov r11, [rbp - 1368] # tag L62 from tag-slot
    mov [rbp - 1376], r11 # store tag L63
    mov [rbp - 520], r10 # spill L63 to slot
    jmp .La4b0_hpx_hexfloat_bb48 # branch
.La4b0_hpx_hexfloat_bb47:
    mov r10, [rbp - 504] # reload L61 from spill slot
    mov rsi, [rbp - 504] # reload L61 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1360] # tag L61 from tag-slot
    mov rcx, 80 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 1384], rax # store tag L64
    mov [rbp - 528], r10 # spill L64 to slot
    mov r11, [rbp - 528] # reload L64 from spill slot
    mov r10, r11 # assign L63
    mov r11, [rbp - 1384] # tag L64 from tag-slot
    mov [rbp - 1376], r11 # store tag L63
    mov [rbp - 520], r10 # spill L63 to slot
    jmp .La4b0_hpx_hexfloat_bb48 # branch
.La4b0_hpx_hexfloat_bb48:
    mov r10, [rbp - 520] # reload L63 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb50 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb49 # jump -> then
.La4b0_hpx_hexfloat_bb49:
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 904] # tag L4 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 1400], rax # store tag L66
    mov [rbp - 544], r10 # spill L66 to slot
    mov r11, [rbp - 544] # reload L66 from spill slot
    mov r10, r11 # assign L67
    mov r11, 0 # tag L66 = TAG_INT (i64-local, fused)
    mov [rbp - 1408], r11 # store tag L67
    mov [rbp - 552], r10 # spill L67 to slot
    mov r10, 1 # assign L68
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1416], r11 # store tag L68
    mov [rbp - 560], r10 # spill L68 to slot
    mov r10, [rbp - 552] # reload L67 from spill slot
    mov rsi, [rbp - 552] # reload L67 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, 0 # tag L67 = TAG_INT (i64-local, fused)
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 888] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 1424], rax # store tag L69
    mov [rbp - 568], r10 # spill L69 to slot
    mov r10, [rbp - 568] # reload L69 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb52 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb51 # jump -> then
.La4b0_hpx_hexfloat_bb50:
    jmp .La4b0_hpx_hexfloat_bb45 # branch
.La4b0_hpx_hexfloat_bb51:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 872] # tag L0 from tag-slot
    mov rcx, [rbp - 552] # reload L67 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, 0 # tag L67 = TAG_INT (i64-local, fused)
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 1440], rax # store tag L71
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 584], r10 # spill L71 to slot
    mov r11, [rbp - 584] # reload L71 from spill slot
    mov r10, r11 # assign L72
    mov r11, [rbp - 1440] # tag L71 from tag-slot
    mov [rbp - 1448], r11 # store tag L72
    mov [rbp - 592], r10 # spill L72 to slot
    mov r10, [rbp - 592] # reload L72 from spill slot
    mov rsi, [rbp - 592] # reload L72 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1448] # tag L72 from tag-slot
    mov rcx, 45 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 1456], rax # store tag L73
    mov [rbp - 600], r10 # spill L73 to slot
    mov r10, [rbp - 600] # reload L73 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb54 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb53 # jump -> then
.La4b0_hpx_hexfloat_bb52:
    mov r10, 0 # assign L80
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1512], r11 # store tag L80
    mov [rbp - 656], r10 # spill L80 to slot
    mov r10, 0 # assign L81
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1520], r11 # store tag L81
    mov [rbp - 664], r10 # spill L81 to slot
    jmp .La4b0_hpx_hexfloat_bb58 # branch
.La4b0_hpx_hexfloat_bb53:
    mov r10, 0 # binop lhs into dst
    sub r10, 1 # binop -
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1472], r11 # store tag L75
    mov [rbp - 616], r10 # spill L75 to slot
    mov r11, [rbp - 616] # reload L75 from spill slot
    mov r10, r11 # assign L68
    mov r11, 0 # tag L75 = TAG_INT (i64-local, fused)
    mov [rbp - 1416], r11 # store tag L68
    mov [rbp - 560], r10 # spill L68 to slot
    mov r10, [rbp - 552] # reload L67 from spill slot
    mov r10, r10 # binop lhs into dst
    add r10, 1 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1480], r11 # store tag L76
    mov [rbp - 624], r10 # spill L76 to slot
    mov r11, [rbp - 624] # reload L76 from spill slot
    mov r10, r11 # assign L67
    mov r11, 0 # tag L76 = TAG_INT (i64-local, fused)
    mov [rbp - 1408], r11 # store tag L67
    mov [rbp - 552], r10 # spill L67 to slot
    jmp .La4b0_hpx_hexfloat_bb57 # branch
.La4b0_hpx_hexfloat_bb54:
    mov r10, [rbp - 592] # reload L72 from spill slot
    mov rsi, [rbp - 592] # reload L72 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1448] # tag L72 from tag-slot
    mov rcx, 43 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 1488], rax # store tag L77
    mov [rbp - 632], r10 # spill L77 to slot
    mov r10, [rbp - 632] # reload L77 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb56 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb55 # jump -> then
.La4b0_hpx_hexfloat_bb55:
    mov r10, [rbp - 552] # reload L67 from spill slot
    mov r10, r10 # binop lhs into dst
    add r10, 1 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1504], r11 # store tag L79
    mov [rbp - 648], r10 # spill L79 to slot
    mov r11, [rbp - 648] # reload L79 from spill slot
    mov r10, r11 # assign L67
    mov r11, 0 # tag L79 = TAG_INT (i64-local, fused)
    mov [rbp - 1408], r11 # store tag L67
    mov [rbp - 552], r10 # spill L67 to slot
    jmp .La4b0_hpx_hexfloat_bb56 # branch
.La4b0_hpx_hexfloat_bb56:
    jmp .La4b0_hpx_hexfloat_bb57 # branch
.La4b0_hpx_hexfloat_bb57:
    jmp .La4b0_hpx_hexfloat_bb52 # branch
.La4b0_hpx_hexfloat_bb58:
    mov r10, [rbp - 552] # reload L67 from spill slot
    mov rsi, [rbp - 552] # reload L67 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, 0 # tag L67 = TAG_INT (i64-local, fused)
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 888] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 1528], rax # store tag L82
    mov [rbp - 672], r10 # spill L82 to slot
    mov r10, [rbp - 672] # reload L82 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb60 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb59 # jump -> then
.La4b0_hpx_hexfloat_bb59:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 872] # tag L0 from tag-slot
    mov rcx, [rbp - 552] # reload L67 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, 0 # tag L67 = TAG_INT (i64-local, fused)
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 1536], rax # store tag L83
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 680], r10 # spill L83 to slot
    mov r11, [rbp - 680] # reload L83 from spill slot
    mov r10, r11 # assign L84
    mov r11, [rbp - 1536] # tag L83 from tag-slot
    mov [rbp - 1544], r11 # store tag L84
    mov [rbp - 688], r10 # spill L84 to slot
    mov r10, [rbp - 688] # reload L84 from spill slot
    mov rsi, [rbp - 688] # reload L84 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1544] # tag L84 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 1552], rax # store tag L85
    mov [rbp - 696], r10 # spill L85 to slot
    mov r10, [rbp - 696] # reload L85 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb62 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb61 # jump -> then
.La4b0_hpx_hexfloat_bb60:
    mov r10, [rbp - 664] # reload L81 from spill slot
    cmp r10, 1 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1632], r11 # store tag L95
    mov [rbp - 776], r10 # spill L95 to slot
    mov r10, [rbp - 776] # reload L95 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb70 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb69 # jump -> then
.La4b0_hpx_hexfloat_bb61:
    mov r10, [rbp - 688] # reload L84 from spill slot
    mov rsi, [rbp - 688] # reload L84 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1544] # tag L84 from tag-slot
    mov rcx, 57 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 1568], rax # store tag L87
    mov [rbp - 712], r10 # spill L87 to slot
    mov r11, [rbp - 712] # reload L87 from spill slot
    mov r10, r11 # assign L86
    mov r11, [rbp - 1568] # tag L87 from tag-slot
    mov [rbp - 1560], r11 # store tag L86
    mov [rbp - 704], r10 # spill L86 to slot
    jmp .La4b0_hpx_hexfloat_bb63 # branch
.La4b0_hpx_hexfloat_bb62:
    mov r11, [rbp - 696] # reload L85 from spill slot
    mov r10, r11 # assign L86
    mov r11, [rbp - 1552] # tag L85 from tag-slot
    mov [rbp - 1560], r11 # store tag L86
    mov [rbp - 704], r10 # spill L86 to slot
    jmp .La4b0_hpx_hexfloat_bb63 # branch
.La4b0_hpx_hexfloat_bb63:
    mov r10, [rbp - 704] # reload L86 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb65 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb64 # jump -> then
.La4b0_hpx_hexfloat_bb64:
    mov r10, [rbp - 656] # reload L80 from spill slot
    mov r10, r10 # binop lhs into dst
    imul r10, 10 # binop *
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1584], r11 # store tag L89
    mov [rbp - 728], r10 # spill L89 to slot
    mov r10, [rbp - 688] # reload L84 from spill slot
    mov rsi, [rbp - 688] # reload L84 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1544] # tag L84 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 1592], rax # store tag L90
    mov [rbp - 736], r10 # spill L90 to slot
    mov r10, [rbp - 728] # reload L89 from spill slot
    mov r11, [rbp - 736] # reload L90 from spill slot
    mov r10, r10 # binop lhs into dst
    add r10, r11 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1600], r11 # store tag L91
    mov [rbp - 744], r10 # spill L91 to slot
    mov r11, [rbp - 744] # reload L91 from spill slot
    mov r10, r11 # assign L80
    mov r11, 0 # tag L91 = TAG_INT (i64-local, fused)
    mov [rbp - 1512], r11 # store tag L80
    mov [rbp - 656], r10 # spill L80 to slot
    mov r10, 1 # assign L81
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1520], r11 # store tag L81
    mov [rbp - 664], r10 # spill L81 to slot
    mov r10, [rbp - 656] # reload L80 from spill slot
    cmp r10, 100000 # binop >
    setg al # binop > → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1608], r11 # store tag L92
    mov [rbp - 752], r10 # spill L92 to slot
    mov r10, [rbp - 752] # reload L92 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb67 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb66 # jump -> then
.La4b0_hpx_hexfloat_bb65:
    jmp .La4b0_hpx_hexfloat_bb60 # branch
.La4b0_hpx_hexfloat_bb66:
    mov r10, 100000 # assign L80
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1512], r11 # store tag L80
    mov [rbp - 656], r10 # spill L80 to slot
    jmp .La4b0_hpx_hexfloat_bb67 # branch
.La4b0_hpx_hexfloat_bb67:
    mov r10, [rbp - 552] # reload L67 from spill slot
    mov r10, r10 # binop lhs into dst
    add r10, 1 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1624], r11 # store tag L94
    mov [rbp - 768], r10 # spill L94 to slot
    mov r11, [rbp - 768] # reload L94 from spill slot
    mov r10, r11 # assign L67
    mov r11, 0 # tag L94 = TAG_INT (i64-local, fused)
    mov [rbp - 1408], r11 # store tag L67
    mov [rbp - 552], r10 # spill L67 to slot
    jmp .La4b0_hpx_hexfloat_bb68 # branch
.La4b0_hpx_hexfloat_bb68:
    jmp .La4b0_hpx_hexfloat_bb58 # branch
.La4b0_hpx_hexfloat_bb69:
    mov r11, [rbp - 560] # reload L68 from spill slot
    mov r10, r11 # assign L56
    mov r11, 0 # tag L68 = TAG_INT (i64-local, fused)
    mov [rbp - 1320], r11 # store tag L56
    mov [rbp - 464], r10 # spill L56 to slot
    mov r11, [rbp - 656] # reload L80 from spill slot
    mov r10, r11 # assign L57
    mov r11, 0 # tag L80 = TAG_INT (i64-local, fused)
    mov [rbp - 1328], r11 # store tag L57
    mov [rbp - 472], r10 # spill L57 to slot
    mov r10, [rbp - 552] # reload L67 from spill slot
    mov r15, r10 # assign L4
    mov r11, 0 # tag L67 = TAG_INT (i64-local, fused)
    mov [rbp - 904], r11 # store tag L4
    jmp .La4b0_hpx_hexfloat_bb70 # branch
.La4b0_hpx_hexfloat_bb70:
    jmp .La4b0_hpx_hexfloat_bb50 # branch
.La4b0_hpx_hexfloat_bb71:
    mov r10, [rbp - 88] # reload L9 from spill slot
    cmp r10, 0 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1664], r11 # store tag L99
    mov [rbp - 808], r10 # spill L99 to slot
    mov r10, [rbp - 808] # reload L99 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_hexfloat_bb74 # jump-if-zero -> else
    jmp .La4b0_hpx_hexfloat_bb73 # jump -> then
.La4b0_hpx_hexfloat_bb72:
    mov r10, [rbp - 464] # reload L56 from spill slot
    mov r11, [rbp - 472] # reload L57 from spill slot
    mov r10, r10 # binop lhs into dst
    imul r10, r11 # binop *
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1696], r11 # store tag L103
    mov [rbp - 840], r10 # spill L103 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov r11, [rbp - 840] # reload L103 from spill slot
    mov r10, r10 # binop lhs into dst
    add r10, r11 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1704], r11 # store tag L104
    mov [rbp - 848], r10 # spill L104 to slot
    mov r11, [rbp - 848] # reload L104 from spill slot
    mov r10, r11 # assign L105
    mov r11, 0 # tag L104 = TAG_INT (i64-local, fused)
    mov [rbp - 1712], r11 # store tag L105
    mov [rbp - 856], r10 # spill L105 to slot
    sub rsp, 16 # hv: reserve 1 16B stack arg slots
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r11, r11 # hv arg payload
    mov r10, 0 # tag L9 = TAG_INT (i64-local, fused)
    mov [rsp], r10 # hv stack arg 3 tag
    mov [rsp + 8], r11 # hv stack arg 3 payload
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 896] # tag L3 from tag-slot
    mov rcx, [rbp - 56] # reload L5 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, 0 # tag L5 = TAG_INT (i64-local, fused)
    mov r9, [rbp - 856] # reload L105 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, 0 # tag L105 = TAG_INT (i64-local, fused)
    call hpx_pack # call hpx_pack
    add rsp, 16 # hv: pop 1 stack arg slots
    mov [rbp - 1720], rax # store tag L106
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 864], r10 # spill L106 to slot
    mov rdx, [rbp - 864] # reload L106 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 1720] # tag L106 from tag-slot
    add rsp, 1680 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.La4b0_hpx_hexfloat_bb73:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 896] # tag L3 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    mov r9, 0 # hv arg payload
    mov r8, 0 # tag default = TAG_INT
    call hpx_assemble # call hpx_assemble
    mov [rbp - 1680], rax # store tag L101
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 824], r10 # spill L101 to slot
    mov rdx, [rbp - 824] # reload L101 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 1680] # tag L101 from tag-slot
    add rsp, 1680 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.La4b0_hpx_hexfloat_bb74:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 896] # tag L3 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    mov r9, 0 # hv arg payload
    mov r8, 0 # tag default = TAG_INT
    call hpx_assemble # call hpx_assemble
    mov [rbp - 1688], rax # store tag L102
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 832], r10 # spill L102 to slot
    mov rdx, [rbp - 832] # reload L102 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 1688] # tag L102 from tag-slot
    add rsp, 1680 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hpx_nan_payload
.hidden hpx_nan_payload
    .p2align 4
hpx_nan_payload:
    .loc 1 288 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 1488 # prologue: alloc spill frame
    mov [rbp - 776], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 784], rdx # store tag L1
    mov r12, rcx # ingress param payload
    mov [rbp - 792], r8 # store tag L2
    mov r13, r9 # ingress param payload
.La4b0_hpx_nan_payload_bb0:
    mov r14, r12 # assign L3
    mov r11, [rbp - 784] # tag L1 from tag-slot
    mov [rbp - 800], r11 # store tag L3
    mov r15, 10 # assign L4
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 808], r11 # store tag L4
    mov r10, 0 # assign L5
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 816], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 800] # tag L3 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 792] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 824], rax # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb2 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb1 # jump -> then
.La4b0_hpx_nan_payload_bb1:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 776] # tag L0 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 800] # tag L3 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 840], rax # store tag L8
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 840] # tag L8 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 848], rax # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 848] # tag L9 from tag-slot
    mov [rbp - 832], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    jmp .La4b0_hpx_nan_payload_bb3 # branch
.La4b0_hpx_nan_payload_bb2:
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 824] # tag L6 from tag-slot
    mov [rbp - 832], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    jmp .La4b0_hpx_nan_payload_bb3 # branch
.La4b0_hpx_nan_payload_bb3:
    mov r10, [rbp - 72] # reload L7 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb5 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb4 # jump -> then
.La4b0_hpx_nan_payload_bb4:
    mov r15, 8 # assign L4
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 808], r11 # store tag L4
    mov r10, 1 # assign L5
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 816], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 800] # tag L3 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 864], rax # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r14, r10 # assign L3
    mov r11, 0 # tag L11 = TAG_INT (i64-local, fused)
    mov [rbp - 800], r11 # store tag L3
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 800] # tag L3 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 792] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 872], rax # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb7 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb6 # jump -> then
.La4b0_hpx_nan_payload_bb5:
    mov r10, 0 # assign L43
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1120], r11 # store tag L43
    mov [rbp - 360], r10 # spill L43 to slot
    mov r10, 0 # assign L44
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1128], r11 # store tag L44
    mov [rbp - 368], r10 # spill L44 to slot
    mov r10, 0 # assign L45
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1136], r11 # store tag L45
    mov [rbp - 376], r10 # spill L45 to slot
    mov r10, 0 # assign L46
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1144], r11 # store tag L46
    mov [rbp - 384], r10 # spill L46 to slot
    jmp .La4b0_hpx_nan_payload_bb34 # branch
.La4b0_hpx_nan_payload_bb6:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 776] # tag L0 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 800] # tag L3 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 888], rax # store tag L14
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 888] # tag L14 from tag-slot
    mov [rbp - 896], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 896] # tag L15 from tag-slot
    mov rcx, 120 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 904], rax # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r10, [rbp - 144] # reload L16 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb9 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb8 # jump -> then
.La4b0_hpx_nan_payload_bb7:
    jmp .La4b0_hpx_nan_payload_bb5 # branch
.La4b0_hpx_nan_payload_bb8:
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, [rbp - 904] # tag L16 from tag-slot
    mov [rbp - 912], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    jmp .La4b0_hpx_nan_payload_bb10 # branch
.La4b0_hpx_nan_payload_bb9:
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov rsi, [rbp - 136] # reload L15 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 896] # tag L15 from tag-slot
    mov rcx, 88 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 920], rax # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov r10, r11 # assign L17
    mov r11, [rbp - 920] # tag L18 from tag-slot
    mov [rbp - 912], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    jmp .La4b0_hpx_nan_payload_bb10 # branch
.La4b0_hpx_nan_payload_bb10:
    mov r10, [rbp - 152] # reload L17 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb12 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb11 # jump -> then
.La4b0_hpx_nan_payload_bb11:
    mov r10, 0 # assign L20
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 936], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 800] # tag L3 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 944], rax # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r10, [rbp - 184] # reload L21 from spill slot
    mov rsi, [rbp - 184] # reload L21 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, 0 # tag L21 = TAG_INT (i64-local, fused)
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 792] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 952], rax # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r10, [rbp - 192] # reload L22 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb14 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb13 # jump -> then
.La4b0_hpx_nan_payload_bb12:
    jmp .La4b0_hpx_nan_payload_bb7 # branch
.La4b0_hpx_nan_payload_bb13:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 800] # tag L3 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 968], rax # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 776] # tag L0 from tag-slot
    mov rcx, [rbp - 208] # reload L24 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, 0 # tag L24 = TAG_INT (i64-local, fused)
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 976], rax # store tag L25
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 216], r10 # spill L25 to slot
    mov r11, [rbp - 216] # reload L25 from spill slot
    mov r10, r11 # assign L26
    mov r11, [rbp - 976] # tag L25 from tag-slot
    mov [rbp - 984], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov rsi, [rbp - 224] # reload L26 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 984] # tag L26 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 992], rax # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov r10, [rbp - 232] # reload L27 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb16 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb15 # jump -> then
.La4b0_hpx_nan_payload_bb14:
    mov r10, [rbp - 176] # reload L20 from spill slot
    cmp r10, 0 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1088], r11 # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    mov r10, [rbp - 328] # reload L39 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb33 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb32 # jump -> then
.La4b0_hpx_nan_payload_bb15:
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov rsi, [rbp - 224] # reload L26 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 984] # tag L26 from tag-slot
    mov rcx, 57 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 1008], rax # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r11, [rbp - 248] # reload L29 from spill slot
    mov r10, r11 # assign L28
    mov r11, [rbp - 1008] # tag L29 from tag-slot
    mov [rbp - 1000], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    jmp .La4b0_hpx_nan_payload_bb17 # branch
.La4b0_hpx_nan_payload_bb16:
    mov r11, [rbp - 232] # reload L27 from spill slot
    mov r10, r11 # assign L28
    mov r11, [rbp - 992] # tag L27 from tag-slot
    mov [rbp - 1000], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    jmp .La4b0_hpx_nan_payload_bb17 # branch
.La4b0_hpx_nan_payload_bb17:
    mov r10, [rbp - 240] # reload L28 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb19 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb18 # jump -> then
.La4b0_hpx_nan_payload_bb18:
    mov r10, 1 # assign L20
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 936], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    jmp .La4b0_hpx_nan_payload_bb31 # branch
.La4b0_hpx_nan_payload_bb19:
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov rsi, [rbp - 224] # reload L26 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 984] # tag L26 from tag-slot
    mov rcx, 97 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 1024], rax # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov r10, [rbp - 264] # reload L31 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb21 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb20 # jump -> then
.La4b0_hpx_nan_payload_bb20:
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov rsi, [rbp - 224] # reload L26 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 984] # tag L26 from tag-slot
    mov rcx, 102 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 1040], rax # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r11, [rbp - 280] # reload L33 from spill slot
    mov r10, r11 # assign L32
    mov r11, [rbp - 1040] # tag L33 from tag-slot
    mov [rbp - 1032], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    jmp .La4b0_hpx_nan_payload_bb22 # branch
.La4b0_hpx_nan_payload_bb21:
    mov r11, [rbp - 264] # reload L31 from spill slot
    mov r10, r11 # assign L32
    mov r11, [rbp - 1024] # tag L31 from tag-slot
    mov [rbp - 1032], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    jmp .La4b0_hpx_nan_payload_bb22 # branch
.La4b0_hpx_nan_payload_bb22:
    mov r10, [rbp - 272] # reload L32 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb24 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb23 # jump -> then
.La4b0_hpx_nan_payload_bb23:
    mov r10, 1 # assign L20
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 936], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    jmp .La4b0_hpx_nan_payload_bb30 # branch
.La4b0_hpx_nan_payload_bb24:
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov rsi, [rbp - 224] # reload L26 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 984] # tag L26 from tag-slot
    mov rcx, 65 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 1056], rax # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    mov r10, [rbp - 296] # reload L35 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb26 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb25 # jump -> then
.La4b0_hpx_nan_payload_bb25:
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov rsi, [rbp - 224] # reload L26 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 984] # tag L26 from tag-slot
    mov rcx, 70 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 1072], rax # store tag L37
    mov [rbp - 312], r10 # spill L37 to slot
    mov r11, [rbp - 312] # reload L37 from spill slot
    mov r10, r11 # assign L36
    mov r11, [rbp - 1072] # tag L37 from tag-slot
    mov [rbp - 1064], r11 # store tag L36
    mov [rbp - 304], r10 # spill L36 to slot
    jmp .La4b0_hpx_nan_payload_bb27 # branch
.La4b0_hpx_nan_payload_bb26:
    mov r11, [rbp - 296] # reload L35 from spill slot
    mov r10, r11 # assign L36
    mov r11, [rbp - 1056] # tag L35 from tag-slot
    mov [rbp - 1064], r11 # store tag L36
    mov [rbp - 304], r10 # spill L36 to slot
    jmp .La4b0_hpx_nan_payload_bb27 # branch
.La4b0_hpx_nan_payload_bb27:
    mov r10, [rbp - 304] # reload L36 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb29 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb28 # jump -> then
.La4b0_hpx_nan_payload_bb28:
    mov r10, 1 # assign L20
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 936], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    jmp .La4b0_hpx_nan_payload_bb29 # branch
.La4b0_hpx_nan_payload_bb29:
    jmp .La4b0_hpx_nan_payload_bb30 # branch
.La4b0_hpx_nan_payload_bb30:
    jmp .La4b0_hpx_nan_payload_bb31 # branch
.La4b0_hpx_nan_payload_bb31:
    jmp .La4b0_hpx_nan_payload_bb14 # branch
.La4b0_hpx_nan_payload_bb32:
    mov r10, 0 # binop lhs into dst
    sub r10, 1 # binop -
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1104], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    mov rdx, [rbp - 344] # reload L41 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, 0 # tag L41 = TAG_INT (i64-local, fused)
    add rsp, 1488 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.La4b0_hpx_nan_payload_bb33:
    mov r15, 16 # assign L4
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 808], r11 # store tag L4
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 800] # tag L3 from tag-slot
    mov rcx, 2 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 1112], rax # store tag L42
    mov [rbp - 352], r10 # spill L42 to slot
    mov r10, [rbp - 352] # reload L42 from spill slot
    mov r14, r10 # assign L3
    mov r11, 0 # tag L42 = TAG_INT (i64-local, fused)
    mov [rbp - 800], r11 # store tag L3
    jmp .La4b0_hpx_nan_payload_bb12 # branch
.La4b0_hpx_nan_payload_bb34:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 800] # tag L3 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 792] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 1152], rax # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    mov r10, [rbp - 392] # reload L47 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb36 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb35 # jump -> then
.La4b0_hpx_nan_payload_bb35:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 776] # tag L0 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 800] # tag L3 from tag-slot
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 1160], rax # store tag L48
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 400], r10 # spill L48 to slot
    mov r11, [rbp - 400] # reload L48 from spill slot
    mov r10, r11 # assign L49
    mov r11, [rbp - 1160] # tag L48 from tag-slot
    mov [rbp - 1168], r11 # store tag L49
    mov [rbp - 408], r10 # spill L49 to slot
    mov r10, 0 # binop lhs into dst
    sub r10, 1 # binop -
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1176], r11 # store tag L50
    mov [rbp - 416], r10 # spill L50 to slot
    mov r11, [rbp - 416] # reload L50 from spill slot
    mov r10, r11 # assign L51
    mov r11, 0 # tag L50 = TAG_INT (i64-local, fused)
    mov [rbp - 1184], r11 # store tag L51
    mov [rbp - 424], r10 # spill L51 to slot
    mov r10, [rbp - 408] # reload L49 from spill slot
    mov rsi, [rbp - 408] # reload L49 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1168] # tag L49 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 1192], rax # store tag L52
    mov [rbp - 432], r10 # spill L52 to slot
    mov r10, [rbp - 432] # reload L52 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb38 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb37 # jump -> then
.La4b0_hpx_nan_payload_bb36:
    mov r10, [rbp - 384] # reload L46 from spill slot
    cmp r10, 0 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1456], r11 # store tag L85
    mov [rbp - 696], r10 # spill L85 to slot
    mov r10, [rbp - 696] # reload L85 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb62 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb61 # jump -> then
.La4b0_hpx_nan_payload_bb37:
    mov r10, [rbp - 408] # reload L49 from spill slot
    mov rsi, [rbp - 408] # reload L49 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1168] # tag L49 from tag-slot
    mov rcx, 57 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 1208], rax # store tag L54
    mov [rbp - 448], r10 # spill L54 to slot
    mov r11, [rbp - 448] # reload L54 from spill slot
    mov r10, r11 # assign L53
    mov r11, [rbp - 1208] # tag L54 from tag-slot
    mov [rbp - 1200], r11 # store tag L53
    mov [rbp - 440], r10 # spill L53 to slot
    jmp .La4b0_hpx_nan_payload_bb39 # branch
.La4b0_hpx_nan_payload_bb38:
    mov r11, [rbp - 432] # reload L52 from spill slot
    mov r10, r11 # assign L53
    mov r11, [rbp - 1192] # tag L52 from tag-slot
    mov [rbp - 1200], r11 # store tag L53
    mov [rbp - 440], r10 # spill L53 to slot
    jmp .La4b0_hpx_nan_payload_bb39 # branch
.La4b0_hpx_nan_payload_bb39:
    mov r10, [rbp - 440] # reload L53 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb41 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb40 # jump -> then
.La4b0_hpx_nan_payload_bb40:
    mov r10, [rbp - 408] # reload L49 from spill slot
    mov rsi, [rbp - 408] # reload L49 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1168] # tag L49 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 1224], rax # store tag L56
    mov [rbp - 464], r10 # spill L56 to slot
    mov r11, [rbp - 464] # reload L56 from spill slot
    mov r10, r11 # assign L51
    mov r11, 0 # tag L56 = TAG_INT (i64-local, fused)
    mov [rbp - 1184], r11 # store tag L51
    mov [rbp - 424], r10 # spill L51 to slot
    jmp .La4b0_hpx_nan_payload_bb53 # branch
.La4b0_hpx_nan_payload_bb41:
    mov r10, [rbp - 408] # reload L49 from spill slot
    mov rsi, [rbp - 408] # reload L49 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1168] # tag L49 from tag-slot
    mov rcx, 97 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 1232], rax # store tag L57
    mov [rbp - 472], r10 # spill L57 to slot
    mov r10, [rbp - 472] # reload L57 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb43 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb42 # jump -> then
.La4b0_hpx_nan_payload_bb42:
    mov r10, [rbp - 408] # reload L49 from spill slot
    mov rsi, [rbp - 408] # reload L49 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1168] # tag L49 from tag-slot
    mov rcx, 102 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 1248], rax # store tag L59
    mov [rbp - 488], r10 # spill L59 to slot
    mov r11, [rbp - 488] # reload L59 from spill slot
    mov r10, r11 # assign L58
    mov r11, [rbp - 1248] # tag L59 from tag-slot
    mov [rbp - 1240], r11 # store tag L58
    mov [rbp - 480], r10 # spill L58 to slot
    jmp .La4b0_hpx_nan_payload_bb44 # branch
.La4b0_hpx_nan_payload_bb43:
    mov r11, [rbp - 472] # reload L57 from spill slot
    mov r10, r11 # assign L58
    mov r11, [rbp - 1232] # tag L57 from tag-slot
    mov [rbp - 1240], r11 # store tag L58
    mov [rbp - 480], r10 # spill L58 to slot
    jmp .La4b0_hpx_nan_payload_bb44 # branch
.La4b0_hpx_nan_payload_bb44:
    mov r10, [rbp - 480] # reload L58 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb46 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb45 # jump -> then
.La4b0_hpx_nan_payload_bb45:
    mov r10, [rbp - 408] # reload L49 from spill slot
    mov rsi, [rbp - 408] # reload L49 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1168] # tag L49 from tag-slot
    mov rcx, 87 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 1264], rax # store tag L61
    mov [rbp - 504], r10 # spill L61 to slot
    mov r11, [rbp - 504] # reload L61 from spill slot
    mov r10, r11 # assign L51
    mov r11, 0 # tag L61 = TAG_INT (i64-local, fused)
    mov [rbp - 1184], r11 # store tag L51
    mov [rbp - 424], r10 # spill L51 to slot
    jmp .La4b0_hpx_nan_payload_bb52 # branch
.La4b0_hpx_nan_payload_bb46:
    mov r10, [rbp - 408] # reload L49 from spill slot
    mov rsi, [rbp - 408] # reload L49 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1168] # tag L49 from tag-slot
    mov rcx, 65 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 1272], rax # store tag L62
    mov [rbp - 512], r10 # spill L62 to slot
    mov r10, [rbp - 512] # reload L62 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb48 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb47 # jump -> then
.La4b0_hpx_nan_payload_bb47:
    mov r10, [rbp - 408] # reload L49 from spill slot
    mov rsi, [rbp - 408] # reload L49 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1168] # tag L49 from tag-slot
    mov rcx, 70 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 1288], rax # store tag L64
    mov [rbp - 528], r10 # spill L64 to slot
    mov r11, [rbp - 528] # reload L64 from spill slot
    mov r10, r11 # assign L63
    mov r11, [rbp - 1288] # tag L64 from tag-slot
    mov [rbp - 1280], r11 # store tag L63
    mov [rbp - 520], r10 # spill L63 to slot
    jmp .La4b0_hpx_nan_payload_bb49 # branch
.La4b0_hpx_nan_payload_bb48:
    mov r11, [rbp - 512] # reload L62 from spill slot
    mov r10, r11 # assign L63
    mov r11, [rbp - 1272] # tag L62 from tag-slot
    mov [rbp - 1280], r11 # store tag L63
    mov [rbp - 520], r10 # spill L63 to slot
    jmp .La4b0_hpx_nan_payload_bb49 # branch
.La4b0_hpx_nan_payload_bb49:
    mov r10, [rbp - 520] # reload L63 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb51 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb50 # jump -> then
.La4b0_hpx_nan_payload_bb50:
    mov r10, [rbp - 408] # reload L49 from spill slot
    mov rsi, [rbp - 408] # reload L49 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1168] # tag L49 from tag-slot
    mov rcx, 55 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 1304], rax # store tag L66
    mov [rbp - 544], r10 # spill L66 to slot
    mov r11, [rbp - 544] # reload L66 from spill slot
    mov r10, r11 # assign L51
    mov r11, 0 # tag L66 = TAG_INT (i64-local, fused)
    mov [rbp - 1184], r11 # store tag L51
    mov [rbp - 424], r10 # spill L51 to slot
    jmp .La4b0_hpx_nan_payload_bb51 # branch
.La4b0_hpx_nan_payload_bb51:
    jmp .La4b0_hpx_nan_payload_bb52 # branch
.La4b0_hpx_nan_payload_bb52:
    jmp .La4b0_hpx_nan_payload_bb53 # branch
.La4b0_hpx_nan_payload_bb53:
    mov r10, [rbp - 424] # reload L51 from spill slot
    cmp r10, 0 # binop <
    setl al # binop < → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1312], r11 # store tag L67
    mov [rbp - 552], r10 # spill L67 to slot
    mov r10, [rbp - 552] # reload L67 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb55 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb54 # jump -> then
.La4b0_hpx_nan_payload_bb54:
    mov r11, [rbp - 552] # reload L67 from spill slot
    mov r10, r11 # assign L68
    mov r11, [rbp - 1312] # tag L67 from tag-slot
    mov [rbp - 1320], r11 # store tag L68
    mov [rbp - 560], r10 # spill L68 to slot
    jmp .La4b0_hpx_nan_payload_bb56 # branch
.La4b0_hpx_nan_payload_bb55:
    mov r10, [rbp - 424] # reload L51 from spill slot
    cmp r10, r15 # binop >=
    setge al # binop >= → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1328], r11 # store tag L69
    mov [rbp - 568], r10 # spill L69 to slot
    mov r11, [rbp - 568] # reload L69 from spill slot
    mov r10, r11 # assign L68
    mov r11, [rbp - 1328] # tag L69 from tag-slot
    mov [rbp - 1320], r11 # store tag L68
    mov [rbp - 560], r10 # spill L68 to slot
    jmp .La4b0_hpx_nan_payload_bb56 # branch
.La4b0_hpx_nan_payload_bb56:
    mov r10, [rbp - 560] # reload L68 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb58 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb57 # jump -> then
.La4b0_hpx_nan_payload_bb57:
    mov r10, 0 # binop lhs into dst
    sub r10, 1 # binop -
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1344], r11 # store tag L71
    mov [rbp - 584], r10 # spill L71 to slot
    mov rdx, [rbp - 584] # reload L71 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, 0 # tag L71 = TAG_INT (i64-local, fused)
    add rsp, 1488 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.La4b0_hpx_nan_payload_bb58:
    mov r10, [rbp - 384] # reload L46 from spill slot
    mov r10, r10 # binop lhs into dst
    add r10, 1 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1352], r11 # store tag L72
    mov [rbp - 592], r10 # spill L72 to slot
    mov r11, [rbp - 592] # reload L72 from spill slot
    mov r10, r11 # assign L46
    mov r11, 0 # tag L72 = TAG_INT (i64-local, fused)
    mov [rbp - 1144], r11 # store tag L46
    mov [rbp - 384], r10 # spill L46 to slot
    mov r10, [rbp - 368] # reload L44 from spill slot
    mov r10, r10 # binop lhs into dst
    imul r10, r15 # binop *
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1360], r11 # store tag L73
    mov [rbp - 600], r10 # spill L73 to slot
    mov r10, [rbp - 600] # reload L73 from spill slot
    mov r11, [rbp - 424] # reload L51 from spill slot
    mov r10, r10 # binop lhs into dst
    add r10, r11 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1368], r11 # store tag L74
    mov [rbp - 608], r10 # spill L74 to slot
    mov r11, [rbp - 608] # reload L74 from spill slot
    mov r10, r11 # assign L75
    mov r11, 0 # tag L74 = TAG_INT (i64-local, fused)
    mov [rbp - 1376], r11 # store tag L75
    mov [rbp - 616], r10 # spill L75 to slot
    mov r10, [rbp - 360] # reload L43 from spill slot
    mov r10, r10 # binop lhs into dst
    imul r10, r15 # binop *
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1384], r11 # store tag L76
    mov [rbp - 624], r10 # spill L76 to slot
    mov r10, [rbp - 616] # reload L75 from spill slot
    mov rsi, [rbp - 616] # reload L75 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, 0 # tag L75 = TAG_INT (i64-local, fused)
    mov rcx, 4294967296 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r10, rdx # binop /: capture result payload
    mov [rbp - 1392], rax # store tag L77
    mov [rbp - 632], r10 # spill L77 to slot
    mov r10, [rbp - 624] # reload L76 from spill slot
    mov r11, [rbp - 632] # reload L77 from spill slot
    mov r10, r10 # binop lhs into dst
    add r10, r11 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1400], r11 # store tag L78
    mov [rbp - 640], r10 # spill L78 to slot
    mov r11, [rbp - 640] # reload L78 from spill slot
    mov r10, r11 # assign L79
    mov r11, 0 # tag L78 = TAG_INT (i64-local, fused)
    mov [rbp - 1408], r11 # store tag L79
    mov [rbp - 648], r10 # spill L79 to slot
    mov r10, [rbp - 616] # reload L75 from spill slot
    mov rsi, [rbp - 616] # reload L75 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, 0 # tag L75 = TAG_INT (i64-local, fused)
    mov rcx, 4294967296 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mod # binop %: tag-dispatch hexa_mod
    mov r10, rdx # binop %: capture result payload
    mov [rbp - 1416], rax # store tag L80
    mov [rbp - 656], r10 # spill L80 to slot
    mov r11, [rbp - 656] # reload L80 from spill slot
    mov r10, r11 # assign L44
    mov r11, 0 # tag L80 = TAG_INT (i64-local, fused)
    mov [rbp - 1128], r11 # store tag L44
    mov [rbp - 368], r10 # spill L44 to slot
    mov r10, [rbp - 648] # reload L79 from spill slot
    mov r11, 4294967296 # materialize wide cmp imm to reg (x86 cmp imm is imm32)
    cmp r10, r11 # binop >=
    setge al # binop >= → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1424], r11 # store tag L81
    mov [rbp - 664], r10 # spill L81 to slot
    mov r10, [rbp - 664] # reload L81 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb60 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb59 # jump -> then
.La4b0_hpx_nan_payload_bb59:
    mov r10, 1 # assign L45
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1136], r11 # store tag L45
    mov [rbp - 376], r10 # spill L45 to slot
    jmp .La4b0_hpx_nan_payload_bb60 # branch
.La4b0_hpx_nan_payload_bb60:
    mov r10, [rbp - 648] # reload L79 from spill slot
    mov rsi, [rbp - 648] # reload L79 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, 0 # tag L79 = TAG_INT (i64-local, fused)
    mov rcx, 4294967296 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_mod # binop %: tag-dispatch hexa_mod
    mov r10, rdx # binop %: capture result payload
    mov [rbp - 1440], rax # store tag L83
    mov [rbp - 680], r10 # spill L83 to slot
    mov r11, [rbp - 680] # reload L83 from spill slot
    mov r10, r11 # assign L43
    mov r11, 0 # tag L83 = TAG_INT (i64-local, fused)
    mov [rbp - 1120], r11 # store tag L43
    mov [rbp - 360], r10 # spill L43 to slot
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 800] # tag L3 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 1448], rax # store tag L84
    mov [rbp - 688], r10 # spill L84 to slot
    mov r10, [rbp - 688] # reload L84 from spill slot
    mov r14, r10 # assign L3
    mov r11, 0 # tag L84 = TAG_INT (i64-local, fused)
    mov [rbp - 800], r11 # store tag L3
    jmp .La4b0_hpx_nan_payload_bb34 # branch
.La4b0_hpx_nan_payload_bb61:
    mov r10, [rbp - 56] # reload L5 from spill slot
    cmp r10, 0 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1472], r11 # store tag L87
    mov [rbp - 712], r10 # spill L87 to slot
    mov r11, [rbp - 712] # reload L87 from spill slot
    mov r10, r11 # assign L86
    mov r11, [rbp - 1472] # tag L87 from tag-slot
    mov [rbp - 1464], r11 # store tag L86
    mov [rbp - 704], r10 # spill L86 to slot
    jmp .La4b0_hpx_nan_payload_bb63 # branch
.La4b0_hpx_nan_payload_bb62:
    mov r11, [rbp - 696] # reload L85 from spill slot
    mov r10, r11 # assign L86
    mov r11, [rbp - 1456] # tag L85 from tag-slot
    mov [rbp - 1464], r11 # store tag L86
    mov [rbp - 704], r10 # spill L86 to slot
    jmp .La4b0_hpx_nan_payload_bb63 # branch
.La4b0_hpx_nan_payload_bb63:
    mov r10, [rbp - 704] # reload L86 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb65 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb64 # jump -> then
.La4b0_hpx_nan_payload_bb64:
    mov r10, 0 # binop lhs into dst
    sub r10, 1 # binop -
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1488], r11 # store tag L89
    mov [rbp - 728], r10 # spill L89 to slot
    mov rdx, [rbp - 728] # reload L89 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, 0 # tag L89 = TAG_INT (i64-local, fused)
    add rsp, 1488 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.La4b0_hpx_nan_payload_bb65:
    mov r10, [rbp - 376] # reload L45 from spill slot
    cmp r10, 1 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1496], r11 # store tag L90
    mov [rbp - 736], r10 # spill L90 to slot
    mov r10, [rbp - 736] # reload L90 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_hpx_nan_payload_bb67 # jump-if-zero -> else
    jmp .La4b0_hpx_nan_payload_bb66 # jump -> then
.La4b0_hpx_nan_payload_bb66:
    mov rdx, 2251799813685247 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 1488 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.La4b0_hpx_nan_payload_bb67:
    mov r10, [rbp - 360] # reload L43 from spill slot
    mov r10, r10 # magicdiv: r10 = dividend
    mov rax, r10 # magicdiv: rax = dividend
    mov r11, -9223372036854775807 # magicdiv: r11 = signed magic M (movabs imm64)
    imul r11 # magicdiv: rdx:rax = dividend * M (hi → rdx)
    add rdx, r10 # magicdiv: M<0 correction (rdx += dividend)
    mov rax, rdx # magicdiv: rax = t0 (copy for signbit)
    shr rax, 63 # magicdiv: rax = signbit(t0)
    sar rdx, 18 # magicdiv: rdx = t0 >> s (arithmetic)
    add rdx, rax # magicdiv: rdx = quotient = (t0>>s) + signbit
    imul rax, rdx, 524288 # magicdiv: rax = quotient * d
    sub r10, rax # magicdiv: r10 = dividend - quotient*d (remainder)
    mov r10, r10 # magicdiv: dst = remainder (%)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1512], r11 # store tag L92
    mov [rbp - 752], r10 # spill L92 to slot
    mov r10, [rbp - 752] # reload L92 from spill slot
    mov r10, r10 # binop lhs into dst
    mov r11, 4294967296 # materialize wide imm to reg (x86 ALU imm is imm32)
    imul r10, r11 # binop *
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1520], r11 # store tag L93
    mov [rbp - 760], r10 # spill L93 to slot
    mov r10, [rbp - 760] # reload L93 from spill slot
    mov r11, [rbp - 368] # reload L44 from spill slot
    mov r10, r10 # binop lhs into dst
    add r10, r11 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1528], r11 # store tag L94
    mov [rbp - 768], r10 # spill L94 to slot
    mov rdx, [rbp - 768] # reload L94 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, 0 # tag L94 = TAG_INT (i64-local, fused)
    add rsp, 1488 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_str_parse_float_hexinfnan
.hidden rt_str_parse_float_hexinfnan
    .p2align 4
rt_str_parse_float_hexinfnan:
    .loc 1 339 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 2256 # prologue: alloc spill frame
    mov [rbp - 1160], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.La4b0_rt_str_parse_float_hexinfnan_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 1160] # tag L0 from tag-slot
    call hexa_byte_len # call hexa_byte_len
    mov [rbp - 1168], rax # store tag L1
    mov r12, rdx # hv: unbox call result (rdx)
    mov r13, r12 # assign L2
    mov r11, [rbp - 1168] # tag L1 from tag-slot
    mov [rbp - 1176], r11 # store tag L2
    mov r14, 0 # assign L3
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1184], r11 # store tag L3
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb1 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb1:
    mov rsi, r14 # hv arg payload
    mov rdi, 0 # tag L3 = TAG_INT (i64-local, fused)
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 1176] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r15, rdx # binop <: capture bool payload
    mov [rbp - 1192], rax # store tag L4
    test r15, r15 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb3 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb2 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb2:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 1160] # tag L0 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, 0 # tag L3 = TAG_INT (i64-local, fused)
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 1200], rax # store tag L5
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 1200] # tag L5 from tag-slot
    mov [rbp - 1208], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1208] # tag L6 from tag-slot
    mov rcx, 32 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 1216], rax # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb5 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb4 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb3:
    mov r10, 0 # assign L20
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1320], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov rsi, r14 # hv arg payload
    mov rdi, 0 # tag L3 = TAG_INT (i64-local, fused)
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 1176] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 1328], rax # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r10, [rbp - 184] # reload L21 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb23 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb22 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb4:
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 1216] # tag L7 from tag-slot
    mov [rbp - 1224], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb6 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb5:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1208] # tag L6 from tag-slot
    mov rcx, 9 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 1232], rax # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 1232] # tag L9 from tag-slot
    mov [rbp - 1224], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb6 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb6:
    mov r10, [rbp - 80] # reload L8 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb8 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb7 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb7:
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L10
    mov r11, [rbp - 1224] # tag L8 from tag-slot
    mov [rbp - 1240], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb9 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb8:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1208] # tag L6 from tag-slot
    mov rcx, 10 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 1248], rax # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L10
    mov r11, [rbp - 1248] # tag L11 from tag-slot
    mov [rbp - 1240], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb9 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb9:
    mov r10, [rbp - 96] # reload L10 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb11 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb10 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb10:
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 1240] # tag L10 from tag-slot
    mov [rbp - 1256], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb12 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb11:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1208] # tag L6 from tag-slot
    mov rcx, 11 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 1264], rax # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 1264] # tag L13 from tag-slot
    mov [rbp - 1256], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb12 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb12:
    mov r10, [rbp - 112] # reload L12 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb14 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb13 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb13:
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L14
    mov r11, [rbp - 1256] # tag L12 from tag-slot
    mov [rbp - 1272], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb15 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb14:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1208] # tag L6 from tag-slot
    mov rcx, 12 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 1280], rax # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, [rbp - 136] # reload L15 from spill slot
    mov r10, r11 # assign L14
    mov r11, [rbp - 1280] # tag L15 from tag-slot
    mov [rbp - 1272], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb15 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb15:
    mov r10, [rbp - 128] # reload L14 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb17 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb16 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb16:
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L16
    mov r11, [rbp - 1272] # tag L14 from tag-slot
    mov [rbp - 1288], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb18 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb17:
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1208] # tag L6 from tag-slot
    mov rcx, 13 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 1296], rax # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r11, [rbp - 152] # reload L17 from spill slot
    mov r10, r11 # assign L16
    mov r11, [rbp - 1296] # tag L17 from tag-slot
    mov [rbp - 1288], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb18 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb18:
    mov r10, [rbp - 144] # reload L16 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb20 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb19 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb19:
    mov r10, r14 # binop lhs into dst
    add r10, 1 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1312], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r10, [rbp - 168] # reload L19 from spill slot
    mov r14, r10 # assign L3
    mov r11, 0 # tag L19 = TAG_INT (i64-local, fused)
    mov [rbp - 1184], r11 # store tag L3
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb21 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb20:
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb3 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb21:
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb1 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb22:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 1160] # tag L0 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, 0 # tag L3 = TAG_INT (i64-local, fused)
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 1344], rax # store tag L23
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 1344] # tag L23 from tag-slot
    mov [rbp - 1352], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov rsi, [rbp - 208] # reload L24 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1352] # tag L24 from tag-slot
    mov rcx, 45 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 1360], rax # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r10, [rbp - 216] # reload L25 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb25 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb24 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb23:
    mov rsi, r14 # hv arg payload
    mov rdi, 0 # tag L3 = TAG_INT (i64-local, fused)
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 1176] # tag L2 from tag-slot
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 1408], rax # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov r10, [rbp - 264] # reload L31 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb30 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb29 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb24:
    mov r10, 1 # assign L20
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1320], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, r14 # binop lhs into dst
    add r10, 1 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1376], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov r10, [rbp - 232] # reload L27 from spill slot
    mov r14, r10 # assign L3
    mov r11, 0 # tag L27 = TAG_INT (i64-local, fused)
    mov [rbp - 1184], r11 # store tag L3
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb28 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb25:
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov rsi, [rbp - 208] # reload L24 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1352] # tag L24 from tag-slot
    mov rcx, 43 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 1384], rax # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r10, [rbp - 240] # reload L28 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb27 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb26 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb26:
    mov r10, r14 # binop lhs into dst
    add r10, 1 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1400], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r10, [rbp - 256] # reload L30 from spill slot
    mov r14, r10 # assign L3
    mov r11, 0 # tag L30 = TAG_INT (i64-local, fused)
    mov [rbp - 1184], r11 # store tag L3
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb27 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb27:
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb28 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb28:
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb23 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb29:
    mov r10, 0 # hv payload
    mov r11, 4 # hv payload
    mov [rbp - 1424], r11 # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov rdx, [rbp - 280] # reload L33 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 1424] # tag L33 from tag-slot
    add rsp, 2256 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.La4b0_rt_str_parse_float_hexinfnan_bb30:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 1160] # tag L0 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, 0 # tag L3 = TAG_INT (i64-local, fused)
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 1432], rax # store tag L34
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 288], r10 # spill L34 to slot
    mov r11, [rbp - 288] # reload L34 from spill slot
    mov r10, r11 # assign L35
    mov r11, [rbp - 1432] # tag L34 from tag-slot
    mov [rbp - 1440], r11 # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    mov r10, [rbp - 296] # reload L35 from spill slot
    mov r10, r10 # binop lhs into dst
    or r10, 32 # binop |
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1448], r11 # store tag L36
    mov [rbp - 304], r10 # spill L36 to slot
    mov r11, [rbp - 304] # reload L36 from spill slot
    mov r10, r11 # assign L37
    mov r11, 0 # tag L36 = TAG_INT (i64-local, fused)
    mov [rbp - 1456], r11 # store tag L37
    mov [rbp - 312], r10 # spill L37 to slot
    mov r10, [rbp - 312] # reload L37 from spill slot
    cmp r10, 105 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1464], r11 # store tag L38
    mov [rbp - 320], r10 # spill L38 to slot
    mov r10, [rbp - 320] # reload L38 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb32 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb31 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb31:
    lea r10, [rip+.LCstr0] # assign L40: &str .LCstr0
    mov r11, 3 # tag const_str = TAG_STR
    mov [rbp - 1480], r11 # store tag L40
    mov [rbp - 336], r10 # spill L40 to slot
    mov r10, 0 # assign L41
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1488], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb33 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb32:
    mov r10, [rbp - 312] # reload L37 from spill slot
    cmp r10, 110 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1632], r11 # store tag L59
    mov [rbp - 488], r10 # spill L59 to slot
    mov r10, [rbp - 488] # reload L59 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb47 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb46 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb33:
    mov r10, [rbp - 344] # reload L41 from spill slot
    cmp r10, 8 # binop <
    setl al # binop < → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1496], r11 # store tag L42
    mov [rbp - 352], r10 # spill L42 to slot
    mov r10, [rbp - 352] # reload L42 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb37 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb36 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb34:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 1160] # tag L0 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, 0 # tag L3 = TAG_INT (i64-local, fused)
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 1520], rax # store tag L45
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 376], r10 # spill L45 to slot
    mov r10, [rbp - 376] # reload L45 from spill slot
    mov r10, r10 # binop lhs into dst
    or r10, 32 # binop |
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1528], r11 # store tag L46
    mov [rbp - 384], r10 # spill L46 to slot
    mov r11, [rbp - 384] # reload L46 from spill slot
    mov r10, r11 # assign L47
    mov r11, 0 # tag L46 = TAG_INT (i64-local, fused)
    mov [rbp - 1536], r11 # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    mov rsi, [rbp - 336] # reload L40 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1480] # tag L40 from tag-slot
    mov rcx, [rbp - 344] # reload L41 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, 0 # tag L41 = TAG_INT (i64-local, fused)
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 1544], rax # store tag L48
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 400], r10 # spill L48 to slot
    mov r10, [rbp - 392] # reload L47 from spill slot
    mov r11, [rbp - 400] # reload L48 from spill slot
    mov rsi, [rbp - 392] # reload L47 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, 0 # tag L47 = TAG_INT (i64-local, fused)
    mov rcx, [rbp - 400] # reload L48 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 1544] # tag L48 from tag-slot
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1552], r11 # store tag L49
    mov [rbp - 408], r10 # spill L49 to slot
    mov r10, [rbp - 408] # reload L49 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb40 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb39 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb35:
    mov r10, [rbp - 344] # reload L41 from spill slot
    cmp r10, 3 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1584], r11 # store tag L53
    mov [rbp - 440], r10 # spill L53 to slot
    mov r10, [rbp - 440] # reload L53 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb42 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb41 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb36:
    mov rsi, r14 # hv arg payload
    mov rdi, 0 # tag L3 = TAG_INT (i64-local, fused)
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 1176] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 1512], rax # store tag L44
    mov [rbp - 368], r10 # spill L44 to slot
    mov r11, [rbp - 368] # reload L44 from spill slot
    mov r10, r11 # assign L43
    mov r11, [rbp - 1512] # tag L44 from tag-slot
    mov [rbp - 1504], r11 # store tag L43
    mov [rbp - 360], r10 # spill L43 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb38 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb37:
    mov r11, [rbp - 352] # reload L42 from spill slot
    mov r10, r11 # assign L43
    mov r11, [rbp - 1496] # tag L42 from tag-slot
    mov [rbp - 1504], r11 # store tag L43
    mov [rbp - 360], r10 # spill L43 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb38 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb38:
    mov r10, [rbp - 360] # reload L43 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb35 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb34 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb39:
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb35 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb40:
    mov r10, r14 # binop lhs into dst
    add r10, 1 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1568], r11 # store tag L51
    mov [rbp - 424], r10 # spill L51 to slot
    mov r10, [rbp - 424] # reload L51 from spill slot
    mov r14, r10 # assign L3
    mov r11, 0 # tag L51 = TAG_INT (i64-local, fused)
    mov [rbp - 1184], r11 # store tag L3
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov r10, r10 # binop lhs into dst
    add r10, 1 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1576], r11 # store tag L52
    mov [rbp - 432], r10 # spill L52 to slot
    mov r11, [rbp - 432] # reload L52 from spill slot
    mov r10, r11 # assign L41
    mov r11, 0 # tag L52 = TAG_INT (i64-local, fused)
    mov [rbp - 1488], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb33 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb41:
    mov r11, [rbp - 440] # reload L53 from spill slot
    mov r10, r11 # assign L54
    mov r11, [rbp - 1584] # tag L53 from tag-slot
    mov [rbp - 1592], r11 # store tag L54
    mov [rbp - 448], r10 # spill L54 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb43 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb42:
    mov r10, [rbp - 344] # reload L41 from spill slot
    cmp r10, 8 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1600], r11 # store tag L55
    mov [rbp - 456], r10 # spill L55 to slot
    mov r11, [rbp - 456] # reload L55 from spill slot
    mov r10, r11 # assign L54
    mov r11, [rbp - 1600] # tag L55 from tag-slot
    mov [rbp - 1592], r11 # store tag L54
    mov [rbp - 448], r10 # spill L54 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb43 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb43:
    mov r10, [rbp - 448] # reload L54 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb45 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb44 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb44:
    mov rsi, [rbp - 176] # reload L20 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, 0 # tag L20 = TAG_INT (i64-local, fused)
    mov rcx, 2047 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    mov r9, 0 # hv arg payload
    mov r8, 0 # tag default = TAG_INT
    call hpx_assemble # call hpx_assemble
    mov [rbp - 1616], rax # store tag L57
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 472], r10 # spill L57 to slot
    mov rdx, [rbp - 472] # reload L57 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 1616] # tag L57 from tag-slot
    add rsp, 2256 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.La4b0_rt_str_parse_float_hexinfnan_bb45:
    mov r10, 0 # hv payload
    mov r11, 4 # hv payload
    mov [rbp - 1624], r11 # store tag L58
    mov [rbp - 480], r10 # spill L58 to slot
    mov rdx, [rbp - 480] # reload L58 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 1624] # tag L58 from tag-slot
    add rsp, 2256 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.La4b0_rt_str_parse_float_hexinfnan_bb46:
    mov r10, r14 # binop lhs into dst
    add r10, 2 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1648], r11 # store tag L61
    mov [rbp - 504], r10 # spill L61 to slot
    mov r10, [rbp - 504] # reload L61 from spill slot
    mov rsi, [rbp - 504] # reload L61 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, 0 # tag L61 = TAG_INT (i64-local, fused)
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 1176] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 1656], rax # store tag L62
    mov [rbp - 512], r10 # spill L62 to slot
    mov r10, [rbp - 512] # reload L62 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb49 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb48 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb47:
    mov r10, [rbp - 296] # reload L35 from spill slot
    mov rsi, [rbp - 296] # reload L35 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1440] # tag L35 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 2184], rax # store tag L128
    mov [rbp - 1040], r10 # spill L128 to slot
    mov r10, [rbp - 1040] # reload L128 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb97 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb96 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb48:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 1160] # tag L0 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, 0 # tag L3 = TAG_INT (i64-local, fused)
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 1672], rax # store tag L64
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 528], r10 # spill L64 to slot
    mov r10, [rbp - 528] # reload L64 from spill slot
    mov r10, r10 # binop lhs into dst
    or r10, 32 # binop |
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1680], r11 # store tag L65
    mov [rbp - 536], r10 # spill L65 to slot
    mov r11, [rbp - 536] # reload L65 from spill slot
    mov r10, r11 # assign L66
    mov r11, 0 # tag L65 = TAG_INT (i64-local, fused)
    mov [rbp - 1688], r11 # store tag L66
    mov [rbp - 544], r10 # spill L66 to slot
    mov r10, r14 # binop lhs into dst
    add r10, 1 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1696], r11 # store tag L67
    mov [rbp - 552], r10 # spill L67 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 1160] # tag L0 from tag-slot
    mov rcx, [rbp - 552] # reload L67 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, 0 # tag L67 = TAG_INT (i64-local, fused)
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 1704], rax # store tag L68
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 560], r10 # spill L68 to slot
    mov r10, [rbp - 560] # reload L68 from spill slot
    mov r10, r10 # binop lhs into dst
    or r10, 32 # binop |
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1712], r11 # store tag L69
    mov [rbp - 568], r10 # spill L69 to slot
    mov r11, [rbp - 568] # reload L69 from spill slot
    mov r10, r11 # assign L70
    mov r11, 0 # tag L69 = TAG_INT (i64-local, fused)
    mov [rbp - 1720], r11 # store tag L70
    mov [rbp - 576], r10 # spill L70 to slot
    mov r10, r14 # binop lhs into dst
    add r10, 2 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1728], r11 # store tag L71
    mov [rbp - 584], r10 # spill L71 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 1160] # tag L0 from tag-slot
    mov rcx, [rbp - 584] # reload L71 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, 0 # tag L71 = TAG_INT (i64-local, fused)
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 1736], rax # store tag L72
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 592], r10 # spill L72 to slot
    mov r10, [rbp - 592] # reload L72 from spill slot
    mov r10, r10 # binop lhs into dst
    or r10, 32 # binop |
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1744], r11 # store tag L73
    mov [rbp - 600], r10 # spill L73 to slot
    mov r11, [rbp - 600] # reload L73 from spill slot
    mov r10, r11 # assign L74
    mov r11, 0 # tag L73 = TAG_INT (i64-local, fused)
    mov [rbp - 1752], r11 # store tag L74
    mov [rbp - 608], r10 # spill L74 to slot
    mov r10, 0 # assign L75
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1760], r11 # store tag L75
    mov [rbp - 616], r10 # spill L75 to slot
    mov r10, [rbp - 544] # reload L66 from spill slot
    cmp r10, 110 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1768], r11 # store tag L76
    mov [rbp - 624], r10 # spill L76 to slot
    mov r10, [rbp - 624] # reload L76 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb51 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb50 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb49:
    mov r10, 0 # hv payload
    mov r11, 4 # hv payload
    mov [rbp - 2176], r11 # store tag L127
    mov [rbp - 1032], r10 # spill L127 to slot
    mov rdx, [rbp - 1032] # reload L127 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 2176] # tag L127 from tag-slot
    add rsp, 2256 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.La4b0_rt_str_parse_float_hexinfnan_bb50:
    mov r10, [rbp - 576] # reload L70 from spill slot
    cmp r10, 97 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1784], r11 # store tag L78
    mov [rbp - 640], r10 # spill L78 to slot
    mov r11, [rbp - 640] # reload L78 from spill slot
    mov r10, r11 # assign L77
    mov r11, [rbp - 1784] # tag L78 from tag-slot
    mov [rbp - 1776], r11 # store tag L77
    mov [rbp - 632], r10 # spill L77 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb52 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb51:
    mov r11, [rbp - 624] # reload L76 from spill slot
    mov r10, r11 # assign L77
    mov r11, [rbp - 1768] # tag L76 from tag-slot
    mov [rbp - 1776], r11 # store tag L77
    mov [rbp - 632], r10 # spill L77 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb52 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb52:
    mov r10, [rbp - 632] # reload L77 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb54 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb53 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb53:
    mov r10, [rbp - 608] # reload L74 from spill slot
    cmp r10, 110 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1800], r11 # store tag L80
    mov [rbp - 656], r10 # spill L80 to slot
    mov r11, [rbp - 656] # reload L80 from spill slot
    mov r10, r11 # assign L79
    mov r11, [rbp - 1800] # tag L80 from tag-slot
    mov [rbp - 1792], r11 # store tag L79
    mov [rbp - 648], r10 # spill L79 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb55 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb54:
    mov r11, [rbp - 632] # reload L77 from spill slot
    mov r10, r11 # assign L79
    mov r11, [rbp - 1776] # tag L77 from tag-slot
    mov [rbp - 1792], r11 # store tag L79
    mov [rbp - 648], r10 # spill L79 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb55 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb55:
    mov r10, [rbp - 648] # reload L79 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb57 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb56 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb56:
    mov r10, 1 # assign L75
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1760], r11 # store tag L75
    mov [rbp - 616], r10 # spill L75 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb57 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb57:
    mov r10, [rbp - 616] # reload L75 from spill slot
    cmp r10, 1 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1816], r11 # store tag L82
    mov [rbp - 672], r10 # spill L82 to slot
    mov r10, [rbp - 672] # reload L82 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb59 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb58 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb58:
    mov r10, r14 # binop lhs into dst
    add r10, 3 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1832], r11 # store tag L84
    mov [rbp - 688], r10 # spill L84 to slot
    mov r10, [rbp - 688] # reload L84 from spill slot
    mov r14, r10 # assign L3
    mov r11, 0 # tag L84 = TAG_INT (i64-local, fused)
    mov [rbp - 1184], r11 # store tag L3
    mov r10, 2251799813685248 # assign L85
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1840], r11 # store tag L85
    mov [rbp - 696], r10 # spill L85 to slot
    mov rsi, r14 # hv arg payload
    mov rdi, 0 # tag L3 = TAG_INT (i64-local, fused)
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 1176] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 1848], rax # store tag L86
    mov [rbp - 704], r10 # spill L86 to slot
    mov r10, [rbp - 704] # reload L86 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb61 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb60 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb59:
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb49 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb60:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 1160] # tag L0 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, 0 # tag L3 = TAG_INT (i64-local, fused)
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 1864], rax # store tag L88
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 720], r10 # spill L88 to slot
    mov r11, [rbp - 720] # reload L88 from spill slot
    mov r10, r11 # assign L89
    mov r11, [rbp - 1864] # tag L88 from tag-slot
    mov [rbp - 1872], r11 # store tag L89
    mov [rbp - 728], r10 # spill L89 to slot
    mov r10, [rbp - 728] # reload L89 from spill slot
    mov rsi, [rbp - 728] # reload L89 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1872] # tag L89 from tag-slot
    mov rcx, 40 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 1880], rax # store tag L90
    mov [rbp - 736], r10 # spill L90 to slot
    mov r10, [rbp - 736] # reload L90 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb63 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb62 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb61:
    mov rsi, [rbp - 176] # reload L20 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, 0 # tag L20 = TAG_INT (i64-local, fused)
    mov rcx, 2047 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    mov r9, [rbp - 696] # reload L85 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, 0 # tag L85 = TAG_INT (i64-local, fused)
    call hpx_assemble # call hpx_assemble
    mov [rbp - 2168], rax # store tag L126
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1024], r10 # spill L126 to slot
    mov rdx, [rbp - 1024] # reload L126 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 2168] # tag L126 from tag-slot
    add rsp, 2256 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.La4b0_rt_str_parse_float_hexinfnan_bb62:
    mov r10, r14 # binop lhs into dst
    add r10, 1 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1896], r11 # store tag L92
    mov [rbp - 752], r10 # spill L92 to slot
    mov r11, [rbp - 752] # reload L92 from spill slot
    mov r10, r11 # assign L93
    mov r11, 0 # tag L92 = TAG_INT (i64-local, fused)
    mov [rbp - 1904], r11 # store tag L93
    mov [rbp - 760], r10 # spill L93 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb64 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb63:
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb61 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb64:
    mov r10, [rbp - 760] # reload L93 from spill slot
    mov rsi, [rbp - 760] # reload L93 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, 0 # tag L93 = TAG_INT (i64-local, fused)
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 1176] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 1912], rax # store tag L94
    mov [rbp - 768], r10 # spill L94 to slot
    mov r10, [rbp - 768] # reload L94 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb66 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb65 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb65:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 1160] # tag L0 from tag-slot
    mov rcx, [rbp - 760] # reload L93 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, 0 # tag L93 = TAG_INT (i64-local, fused)
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 1920], rax # store tag L95
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 776], r10 # spill L95 to slot
    mov r11, [rbp - 776] # reload L95 from spill slot
    mov r10, r11 # assign L96
    mov r11, [rbp - 1920] # tag L95 from tag-slot
    mov [rbp - 1928], r11 # store tag L96
    mov [rbp - 784], r10 # spill L96 to slot
    mov r10, 0 # assign L97
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1936], r11 # store tag L97
    mov [rbp - 792], r10 # spill L97 to slot
    mov r10, [rbp - 784] # reload L96 from spill slot
    mov rsi, [rbp - 784] # reload L96 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1928] # tag L96 from tag-slot
    mov rcx, 48 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 1944], rax # store tag L98
    mov [rbp - 800], r10 # spill L98 to slot
    mov r10, [rbp - 800] # reload L98 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb68 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb67 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb66:
    mov r10, [rbp - 760] # reload L93 from spill slot
    mov rsi, [rbp - 760] # reload L93 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, 0 # tag L93 = TAG_INT (i64-local, fused)
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 1176] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 2080], rax # store tag L115
    mov [rbp - 936], r10 # spill L115 to slot
    mov r10, [rbp - 936] # reload L115 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb90 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb89 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb67:
    mov r10, [rbp - 784] # reload L96 from spill slot
    mov rsi, [rbp - 784] # reload L96 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1928] # tag L96 from tag-slot
    mov rcx, 57 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 1960], rax # store tag L100
    mov [rbp - 816], r10 # spill L100 to slot
    mov r11, [rbp - 816] # reload L100 from spill slot
    mov r10, r11 # assign L99
    mov r11, [rbp - 1960] # tag L100 from tag-slot
    mov [rbp - 1952], r11 # store tag L99
    mov [rbp - 808], r10 # spill L99 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb69 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb68:
    mov r11, [rbp - 800] # reload L98 from spill slot
    mov r10, r11 # assign L99
    mov r11, [rbp - 1944] # tag L98 from tag-slot
    mov [rbp - 1952], r11 # store tag L99
    mov [rbp - 808], r10 # spill L99 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb69 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb69:
    mov r10, [rbp - 808] # reload L99 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb71 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb70 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb70:
    mov r10, 1 # assign L97
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1936], r11 # store tag L97
    mov [rbp - 792], r10 # spill L97 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb86 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb71:
    mov r10, [rbp - 784] # reload L96 from spill slot
    mov rsi, [rbp - 784] # reload L96 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1928] # tag L96 from tag-slot
    mov rcx, 97 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 1976], rax # store tag L102
    mov [rbp - 832], r10 # spill L102 to slot
    mov r10, [rbp - 832] # reload L102 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb73 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb72 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb72:
    mov r10, [rbp - 784] # reload L96 from spill slot
    mov rsi, [rbp - 784] # reload L96 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1928] # tag L96 from tag-slot
    mov rcx, 122 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 1992], rax # store tag L104
    mov [rbp - 848], r10 # spill L104 to slot
    mov r11, [rbp - 848] # reload L104 from spill slot
    mov r10, r11 # assign L103
    mov r11, [rbp - 1992] # tag L104 from tag-slot
    mov [rbp - 1984], r11 # store tag L103
    mov [rbp - 840], r10 # spill L103 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb74 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb73:
    mov r11, [rbp - 832] # reload L102 from spill slot
    mov r10, r11 # assign L103
    mov r11, [rbp - 1976] # tag L102 from tag-slot
    mov [rbp - 1984], r11 # store tag L103
    mov [rbp - 840], r10 # spill L103 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb74 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb74:
    mov r10, [rbp - 840] # reload L103 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb76 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb75 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb75:
    mov r10, 1 # assign L97
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1936], r11 # store tag L97
    mov [rbp - 792], r10 # spill L97 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb85 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb76:
    mov r10, [rbp - 784] # reload L96 from spill slot
    mov rsi, [rbp - 784] # reload L96 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1928] # tag L96 from tag-slot
    mov rcx, 65 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 2008], rax # store tag L106
    mov [rbp - 864], r10 # spill L106 to slot
    mov r10, [rbp - 864] # reload L106 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb78 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb77 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb77:
    mov r10, [rbp - 784] # reload L96 from spill slot
    mov rsi, [rbp - 784] # reload L96 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1928] # tag L96 from tag-slot
    mov rcx, 90 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 2024], rax # store tag L108
    mov [rbp - 880], r10 # spill L108 to slot
    mov r11, [rbp - 880] # reload L108 from spill slot
    mov r10, r11 # assign L107
    mov r11, [rbp - 2024] # tag L108 from tag-slot
    mov [rbp - 2016], r11 # store tag L107
    mov [rbp - 872], r10 # spill L107 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb79 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb78:
    mov r11, [rbp - 864] # reload L106 from spill slot
    mov r10, r11 # assign L107
    mov r11, [rbp - 2008] # tag L106 from tag-slot
    mov [rbp - 2016], r11 # store tag L107
    mov [rbp - 872], r10 # spill L107 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb79 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb79:
    mov r10, [rbp - 872] # reload L107 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb81 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb80 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb80:
    mov r10, 1 # assign L97
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1936], r11 # store tag L97
    mov [rbp - 792], r10 # spill L97 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb84 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb81:
    mov r10, [rbp - 784] # reload L96 from spill slot
    mov rsi, [rbp - 784] # reload L96 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 1928] # tag L96 from tag-slot
    mov rcx, 95 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 2040], rax # store tag L110
    mov [rbp - 896], r10 # spill L110 to slot
    mov r10, [rbp - 896] # reload L110 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb83 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb82 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb82:
    mov r10, 1 # assign L97
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1936], r11 # store tag L97
    mov [rbp - 792], r10 # spill L97 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb83 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb83:
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb84 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb84:
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb85 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb85:
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb86 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb86:
    mov r10, [rbp - 792] # reload L97 from spill slot
    cmp r10, 0 # binop ==
    sete al # binop == → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2056], r11 # store tag L112
    mov [rbp - 912], r10 # spill L112 to slot
    mov r10, [rbp - 912] # reload L112 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb88 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb87 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb87:
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb66 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb88:
    mov r10, [rbp - 760] # reload L93 from spill slot
    mov r10, r10 # binop lhs into dst
    add r10, 1 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2072], r11 # store tag L114
    mov [rbp - 928], r10 # spill L114 to slot
    mov r11, [rbp - 928] # reload L114 from spill slot
    mov r10, r11 # assign L93
    mov r11, 0 # tag L114 = TAG_INT (i64-local, fused)
    mov [rbp - 1904], r11 # store tag L93
    mov [rbp - 760], r10 # spill L93 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb64 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb89:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 1160] # tag L0 from tag-slot
    mov rcx, [rbp - 760] # reload L93 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, 0 # tag L93 = TAG_INT (i64-local, fused)
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 2096], rax # store tag L117
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 952], r10 # spill L117 to slot
    mov r10, [rbp - 952] # reload L117 from spill slot
    mov rsi, [rbp - 952] # reload L117 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2096] # tag L117 from tag-slot
    mov rcx, 41 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 2104], rax # store tag L118
    mov [rbp - 960], r10 # spill L118 to slot
    mov r11, [rbp - 960] # reload L118 from spill slot
    mov r10, r11 # assign L116
    mov r11, [rbp - 2104] # tag L118 from tag-slot
    mov [rbp - 2088], r11 # store tag L116
    mov [rbp - 944], r10 # spill L116 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb91 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb90:
    mov r11, [rbp - 936] # reload L115 from spill slot
    mov r10, r11 # assign L116
    mov r11, [rbp - 2080] # tag L115 from tag-slot
    mov [rbp - 2088], r11 # store tag L116
    mov [rbp - 944], r10 # spill L116 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb91 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb91:
    mov r10, [rbp - 944] # reload L116 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb93 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb92 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb92:
    mov r10, r14 # binop lhs into dst
    add r10, 1 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2120], r11 # store tag L120
    mov [rbp - 976], r10 # spill L120 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 1160] # tag L0 from tag-slot
    mov rcx, [rbp - 976] # reload L120 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, 0 # tag L120 = TAG_INT (i64-local, fused)
    mov r9, [rbp - 760] # reload L93 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, 0 # tag L93 = TAG_INT (i64-local, fused)
    call hpx_nan_payload # call hpx_nan_payload
    mov [rbp - 2128], rax # store tag L121
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 984], r10 # spill L121 to slot
    mov r11, [rbp - 984] # reload L121 from spill slot
    mov r10, r11 # assign L122
    mov r11, 0 # tag L121 = TAG_INT (i64-local, fused)
    mov [rbp - 2136], r11 # store tag L122
    mov [rbp - 992], r10 # spill L122 to slot
    mov r10, [rbp - 992] # reload L122 from spill slot
    cmp r10, 0 # binop >=
    setge al # binop >= → al
    movzx r10, al # zero-extend al into dst
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2144], r11 # store tag L123
    mov [rbp - 1000], r10 # spill L123 to slot
    mov r10, [rbp - 1000] # reload L123 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb95 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb94 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb93:
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb63 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb94:
    mov r10, [rbp - 696] # reload L85 from spill slot
    mov r11, [rbp - 992] # reload L122 from spill slot
    mov r10, r10 # binop lhs into dst
    add r10, r11 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2160], r11 # store tag L125
    mov [rbp - 1016], r10 # spill L125 to slot
    mov r11, [rbp - 1016] # reload L125 from spill slot
    mov r10, r11 # assign L85
    mov r11, 0 # tag L125 = TAG_INT (i64-local, fused)
    mov [rbp - 1840], r11 # store tag L85
    mov [rbp - 696], r10 # spill L85 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb95 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb95:
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb93 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb96:
    mov r10, r14 # binop lhs into dst
    add r10, 1 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2200], r11 # store tag L130
    mov [rbp - 1056], r10 # spill L130 to slot
    mov r10, [rbp - 1056] # reload L130 from spill slot
    mov rsi, [rbp - 1056] # reload L130 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, 0 # tag L130 = TAG_INT (i64-local, fused)
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 1176] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 2208], rax # store tag L131
    mov [rbp - 1064], r10 # spill L131 to slot
    mov r11, [rbp - 1064] # reload L131 from spill slot
    mov r10, r11 # assign L129
    mov r11, [rbp - 2208] # tag L131 from tag-slot
    mov [rbp - 2192], r11 # store tag L129
    mov [rbp - 1048], r10 # spill L129 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb98 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb97:
    mov r11, [rbp - 1040] # reload L128 from spill slot
    mov r10, r11 # assign L129
    mov r11, [rbp - 2184] # tag L128 from tag-slot
    mov [rbp - 2192], r11 # store tag L129
    mov [rbp - 1048], r10 # spill L129 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb98 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb98:
    mov r10, [rbp - 1048] # reload L129 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb100 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb99 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb99:
    mov r10, r14 # binop lhs into dst
    add r10, 1 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2224], r11 # store tag L133
    mov [rbp - 1080], r10 # spill L133 to slot
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 1160] # tag L0 from tag-slot
    mov rcx, [rbp - 1080] # reload L133 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, 0 # tag L133 = TAG_INT (i64-local, fused)
    call hexa_str_byte_at # call hexa_str_byte_at
    mov [rbp - 2232], rax # store tag L134
    mov r10, rdx # hv: unbox call result (rdx)
    mov [rbp - 1088], r10 # spill L134 to slot
    mov r11, [rbp - 1088] # reload L134 from spill slot
    mov r10, r11 # assign L135
    mov r11, [rbp - 2232] # tag L134 from tag-slot
    mov [rbp - 2240], r11 # store tag L135
    mov [rbp - 1096], r10 # spill L135 to slot
    mov r10, [rbp - 1096] # reload L135 from spill slot
    mov rsi, [rbp - 1096] # reload L135 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2240] # tag L135 from tag-slot
    mov rcx, 120 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 2248], rax # store tag L136
    mov [rbp - 1104], r10 # spill L136 to slot
    mov r10, [rbp - 1104] # reload L136 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb102 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb101 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb100:
    mov r10, 0 # hv payload
    mov r11, 4 # hv payload
    mov [rbp - 2296], r11 # store tag L142
    mov [rbp - 1152], r10 # spill L142 to slot
    mov rdx, [rbp - 1152] # reload L142 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 2296] # tag L142 from tag-slot
    add rsp, 2256 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.La4b0_rt_str_parse_float_hexinfnan_bb101:
    mov r11, [rbp - 1104] # reload L136 from spill slot
    mov r10, r11 # assign L137
    mov r11, [rbp - 2248] # tag L136 from tag-slot
    mov [rbp - 2256], r11 # store tag L137
    mov [rbp - 1112], r10 # spill L137 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb103 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb102:
    mov r10, [rbp - 1096] # reload L135 from spill slot
    mov rsi, [rbp - 1096] # reload L135 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 2240] # tag L135 from tag-slot
    mov rcx, 88 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 2264], rax # store tag L138
    mov [rbp - 1120], r10 # spill L138 to slot
    mov r11, [rbp - 1120] # reload L138 from spill slot
    mov r10, r11 # assign L137
    mov r11, [rbp - 2264] # tag L138 from tag-slot
    mov [rbp - 2256], r11 # store tag L137
    mov [rbp - 1112], r10 # spill L137 to slot
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb103 # branch
.La4b0_rt_str_parse_float_hexinfnan_bb103:
    mov r10, [rbp - 1112] # reload L137 from spill slot
    test r10, r10 # br_cond test
    jz .La4b0_rt_str_parse_float_hexinfnan_bb105 # jump-if-zero -> else
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb104 # jump -> then
.La4b0_rt_str_parse_float_hexinfnan_bb104:
    mov r10, r14 # binop lhs into dst
    add r10, 2 # binop +
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2280], r11 # store tag L140
    mov [rbp - 1136], r10 # spill L140 to slot
    sub rsp, 16 # hv: reserve 1 16B stack arg slots
    mov r11, [rbp - 176] # reload L20 from spill slot
    mov r11, r11 # hv arg payload
    mov r10, 0 # tag L20 = TAG_INT (i64-local, fused)
    mov [rsp], r10 # hv stack arg 3 tag
    mov [rsp + 8], r11 # hv stack arg 3 payload
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 1160] # tag L0 from tag-slot
    mov rcx, [rbp - 1136] # reload L140 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, 0 # tag L140 = TAG_INT (i64-local, fused)
    mov r9, r13 # hv arg payload
    mov r8, [rbp - 1176] # tag L2 from tag-slot
    call hpx_hexfloat # call hpx_hexfloat
    add rsp, 16 # hv: pop 1 stack arg slots
    mov [rbp - 2288], rax # store tag L141
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 1144], r10 # spill L141 to slot
    mov rdx, [rbp - 1144] # reload L141 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 2288] # tag L141 from tag-slot
    add rsp, 2256 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.La4b0_rt_str_parse_float_hexinfnan_bb105:
    jmp .La4b0_rt_str_parse_float_hexinfnan_bb100 # branch
    mov eax, 4 # value-less return: tag = TAG_VOID
    xor edx, edx # value-less return: payload = 0
    add rsp, 2256 # epilogue: free spill frame
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
    .byte 0x69, 0x6e, 0x66, 0x69, 0x6e, 0x69, 0x74, 0x79, 0x00
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

.section .note.GNU-stack,"",@progbits
