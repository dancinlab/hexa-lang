// map_core_x86_64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 MAP-CONSTRUCT-R1).
// GENERATED: tool/regen_map_core_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=x86_64-linux-gnu -o map_core_x86_64.s stdlib/runtime/map_core.hexa.
//   Provides the map-core READ-half (rt_map_get_native / rt_map_fnv1a_native /
//   rt_map_strcmp0_native / rt_map_contains_native) PLUS the CONSTRUCT-half
//   in-place write (rt_map_set_inplace_native) as native raw-mem bodies
//   (__hx_ptr_load64/store64 over the HexaArr descriptor + __hx_make_val tag
//   re-stamp). These intrinsics are gen2-native-only (the hexat C-transpile
//   bootstrap cannot lower them), so the bodies enter the shipped runtime.a ONLY
//   via this seed — the rt_hi mechanism (resolve_native_rt_hi_seed / Z2a).
//   ABI: ELF, rt_map_*_native no underscore. External: hexa_to_int (runtime.c).
//   Lets stage_resolve_runtime_a define HEXA_RT_ARRAY_NATIVE + ar this .o into
//   runtime.a so hexa_array_get/set delegate to the native bodies.
# hexa-lang emit pass — target=x86_64-linux-gnu
# source: stdlib/runtime/map_core.hexa
.intel_syntax noprefix
.file 1 "stdlib/runtime/map_core.hexa"
.text
.globl rt_map_fnv1a_native
.hidden rt_map_fnv1a_native
    .p2align 4
rt_map_fnv1a_native:
    .loc 1 38 0
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
.L16d1_rt_map_fnv1a_native_bb0:
    mov r12, 2166136261 # assign L1
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 120], r11 # store tag L1
    mov r13, 0 # assign L2
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 128], r11 # store tag L2
    mov r10, rbx # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r14, r10 # leaf: payload → dst L3
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 136], r11 # store tag L3
    mov r15, r14 # assign L4
    mov r11, [rbp - 136] # tag L3 from tag-slot
    mov [rbp - 144], r11 # store tag L4
    jmp .L16d1_rt_map_fnv1a_native_bb1 # branch
.L16d1_rt_map_fnv1a_native_bb1:
    mov r11, 0 # hv payload
    mov r10, r15 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 152], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    test r10, r10 # br_cond test
    jz .L16d1_rt_map_fnv1a_native_bb3 # jump-if-zero -> else
    jmp .L16d1_rt_map_fnv1a_native_bb2 # jump -> then
.L16d1_rt_map_fnv1a_native_bb2:
    mov r11, r15 # hv payload
    mov r10, r12 # hv payload
    xor r10, r11 # __hx_payload_xor: r10 = a.pl xor b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 160], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r12, r10 # assign L1
    mov r11, [rbp - 160] # tag L6 from tag-slot
    mov [rbp - 120], r11 # store tag L1
    mov r11, 16777619 # hv payload
    mov r10, r12 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 168], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 168] # tag L7 from tag-slot
    mov [rbp - 176], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, 4294967295 # hv payload
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 184], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov r12, r10 # assign L1
    mov r11, [rbp - 184] # tag L9 from tag-slot
    mov [rbp - 120], r11 # store tag L1
    mov r11, 1 # hv payload
    mov r10, r13 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 192], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov r13, r10 # assign L2
    mov r11, [rbp - 192] # tag L10 from tag-slot
    mov [rbp - 128], r11 # store tag L2
    mov r10, rbx # hv payload
    mov r11, r13 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 200], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r15, r10 # assign L4
    mov r11, [rbp - 200] # tag L11 from tag-slot
    mov [rbp - 144], r11 # store tag L4
    jmp .L16d1_rt_map_fnv1a_native_bb1 # branch
.L16d1_rt_map_fnv1a_native_bb3:
    mov rdx, r12 # hv arg payload
    mov rax, [rbp - 120] # tag L1 from tag-slot
    add rsp, 160 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_map_strcmp0_native
.hidden rt_map_strcmp0_native
    .p2align 4
rt_map_strcmp0_native:
    .loc 1 54 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 176 # prologue: alloc spill frame
    mov [rbp - 120], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 128], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L16d1_rt_map_strcmp0_native_bb0:
    mov r13, 0 # assign L2
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 136], r11 # store tag L2
    mov r10, rbx # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r14, r10 # leaf: payload → dst L3
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 144], r11 # store tag L3
    mov r15, r14 # assign L4
    mov r11, [rbp - 144] # tag L3 from tag-slot
    mov [rbp - 152], r11 # store tag L4
    mov r10, r12 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 160], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 160] # tag L5 from tag-slot
    mov [rbp - 168], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    jmp .L16d1_rt_map_strcmp0_native_bb1 # branch
.L16d1_rt_map_strcmp0_native_bb1:
    mov r10, r15 # hv payload
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r11, r11 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 176], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    test r10, r10 # br_cond test
    jz .L16d1_rt_map_strcmp0_native_bb3 # jump-if-zero -> else
    jmp .L16d1_rt_map_strcmp0_native_bb2 # jump -> then
.L16d1_rt_map_strcmp0_native_bb2:
    mov r10, r15 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 184], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    test r10, r10 # br_cond test
    jz .L16d1_rt_map_strcmp0_native_bb5 # jump-if-zero -> else
    jmp .L16d1_rt_map_strcmp0_native_bb4 # jump -> then
.L16d1_rt_map_strcmp0_native_bb3:
    mov rdx, 1 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 176 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L16d1_rt_map_strcmp0_native_bb4:
    mov rdx, 0 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 176 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L16d1_rt_map_strcmp0_native_bb5:
    mov r11, 1 # hv payload
    mov r10, r13 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 200], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov r13, r10 # assign L2
    mov r11, [rbp - 200] # tag L10 from tag-slot
    mov [rbp - 136], r11 # store tag L2
    mov r10, rbx # hv payload
    mov r11, r13 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 208], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r15, r10 # assign L4
    mov r11, [rbp - 208] # tag L11 from tag-slot
    mov [rbp - 152], r11 # store tag L4
    mov r10, r12 # hv payload
    mov r11, r13 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 216], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 216] # tag L12 from tag-slot
    mov [rbp - 168], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    jmp .L16d1_rt_map_strcmp0_native_bb1 # branch
    add rsp, 176 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_map_get_native
.hidden rt_map_get_native
    .p2align 4
rt_map_get_native:
    .loc 1 73 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 848 # prologue: alloc spill frame
    mov [rbp - 456], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 464], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L16d1_rt_map_get_native_bb0:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r13, r10 # leaf: payload → dst L2
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 472], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 472] # tag L2 from tag-slot
    mov [rbp - 480], r11 # store tag L3
    mov r10, r14 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r15, r10 # leaf: payload → dst L4
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 488], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 488] # tag L4 from tag-slot
    mov [rbp - 496], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 504], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 504] # tag L6 from tag-slot
    mov [rbp - 512], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 8 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 520], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 520] # tag L8 from tag-slot
    mov [rbp - 528], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 16 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 536], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 536] # tag L10 from tag-slot
    mov [rbp - 544], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, 4294967295 # hv payload
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 552], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 552] # tag L12 from tag-slot
    mov [rbp - 560], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 464] # tag L1 from tag-slot
    call rt_map_fnv1a_native # call rt_map_fnv1a_native
    mov [rbp - 568], rax # store tag L14
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 568] # tag L14 from tag-slot
    mov [rbp - 576], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov r10, r10 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 584], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, [rbp - 584] # tag L16 from tag-slot
    mov [rbp - 592], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r11, [rbp - 152] # reload L17 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 600], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov r10, r11 # assign L19
    mov r11, [rbp - 600] # tag L18 from tag-slot
    mov [rbp - 608], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r10, 0 # assign L20
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 616], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    jmp .L16d1_rt_map_get_native_bb1 # branch
.L16d1_rt_map_get_native_bb1:
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 176] # reload L20 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 624], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r10, [rbp - 184] # reload L21 from spill slot
    test r10, r10 # br_cond test
    jz .L16d1_rt_map_get_native_bb3 # jump-if-zero -> else
    jmp .L16d1_rt_map_get_native_bb2 # jump -> then
.L16d1_rt_map_get_native_bb2:
    mov r11, 16 # hv payload
    mov r10, [rbp - 168] # reload L19 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 632], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r10, r11 # assign L23
    mov r11, [rbp - 632] # tag L22 from tag-slot
    mov [rbp - 640], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 648], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r11, [rbp - 208] # reload L24 from spill slot
    mov r10, r11 # assign L25
    mov r11, [rbp - 648] # tag L24 from tag-slot
    mov [rbp - 656], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r10, [rbp - 216] # reload L25 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 664], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r11, [rbp - 224] # reload L26 from spill slot
    mov r10, r11 # assign L27
    mov r11, [rbp - 664] # tag L26 from tag-slot
    mov [rbp - 672], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov r10, [rbp - 232] # reload L27 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 680], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r10, [rbp - 240] # reload L28 from spill slot
    test r10, r10 # br_cond test
    jz .L16d1_rt_map_get_native_bb5 # jump-if-zero -> else
    jmp .L16d1_rt_map_get_native_bb4 # jump -> then
.L16d1_rt_map_get_native_bb3:
    mov r10, 0 # hv payload
    mov r11, 4 # hv payload
    mov [rbp - 888], r11 # store tag L54
    mov [rbp - 448], r10 # spill L54 to slot
    mov rdx, [rbp - 448] # reload L54 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 888] # tag L54 from tag-slot
    add rsp, 848 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L16d1_rt_map_get_native_bb4:
    mov r10, 0 # hv payload
    mov r11, 4 # hv payload
    mov [rbp - 696], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov rdx, [rbp - 256] # reload L30 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 696] # tag L30 from tag-slot
    add rsp, 848 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L16d1_rt_map_get_native_bb5:
    mov r10, [rbp - 216] # reload L25 from spill slot
    mov r10, r10 # hv payload
    mov r11, 8 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 704], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov r11, [rbp - 264] # reload L31 from spill slot
    mov r10, r11 # assign L32
    mov r11, [rbp - 704] # tag L31 from tag-slot
    mov [rbp - 712], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r11, 4294967295 # hv payload
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 720], r11 # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r11, [rbp - 280] # reload L33 from spill slot
    mov r10, r11 # assign L34
    mov r11, [rbp - 720] # tag L33 from tag-slot
    mov [rbp - 728], r11 # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    mov r10, [rbp - 288] # reload L34 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 136] # reload L15 from spill slot
    mov r11, r11 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 736], r11 # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    mov r10, [rbp - 296] # reload L35 from spill slot
    test r10, r10 # br_cond test
    jz .L16d1_rt_map_get_native_bb7 # jump-if-zero -> else
    jmp .L16d1_rt_map_get_native_bb6 # jump -> then
.L16d1_rt_map_get_native_bb6:
    mov rsi, [rbp - 232] # reload L27 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 672] # tag L27 from tag-slot
    mov rcx, r12 # hv arg payload
    mov rdx, [rbp - 464] # tag L1 from tag-slot
    call rt_map_strcmp0_native # call rt_map_strcmp0_native
    mov [rbp - 752], rax # store tag L37
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 312], r10 # spill L37 to slot
    mov r11, [rbp - 312] # reload L37 from spill slot
    mov r10, r11 # assign L38
    mov r11, [rbp - 752] # tag L37 from tag-slot
    mov [rbp - 760], r11 # store tag L38
    mov [rbp - 320], r10 # spill L38 to slot
    mov r10, [rbp - 320] # reload L38 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 768], r11 # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    mov r10, [rbp - 328] # reload L39 from spill slot
    test r10, r10 # br_cond test
    jz .L16d1_rt_map_get_native_bb9 # jump-if-zero -> else
    jmp .L16d1_rt_map_get_native_bb8 # jump -> then
.L16d1_rt_map_get_native_bb7:
    mov r11, 1 # hv payload
    mov r10, [rbp - 168] # reload L19 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 856], r11 # store tag L50
    mov [rbp - 416], r10 # spill L50 to slot
    mov r11, [rbp - 416] # reload L50 from spill slot
    mov r10, r11 # assign L51
    mov r11, [rbp - 856] # tag L50 from tag-slot
    mov [rbp - 864], r11 # store tag L51
    mov [rbp - 424], r10 # spill L51 to slot
    mov r11, [rbp - 152] # reload L17 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 424] # reload L51 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 872], r11 # store tag L52
    mov [rbp - 432], r10 # spill L52 to slot
    mov r11, [rbp - 432] # reload L52 from spill slot
    mov r10, r11 # assign L19
    mov r11, [rbp - 872] # tag L52 from tag-slot
    mov [rbp - 608], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 176] # reload L20 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 880], r11 # store tag L53
    mov [rbp - 440], r10 # spill L53 to slot
    mov r11, [rbp - 440] # reload L53 from spill slot
    mov r10, r11 # assign L20
    mov r11, [rbp - 880] # tag L53 from tag-slot
    mov [rbp - 616], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    jmp .L16d1_rt_map_get_native_bb1 # branch
.L16d1_rt_map_get_native_bb8:
    mov r11, 16 # hv payload
    mov r10, [rbp - 168] # reload L19 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 784], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    mov r11, [rbp - 344] # reload L41 from spill slot
    mov r10, r11 # assign L42
    mov r11, [rbp - 784] # tag L41 from tag-slot
    mov [rbp - 792], r11 # store tag L42
    mov [rbp - 352], r10 # spill L42 to slot
    mov r11, 8 # hv payload
    mov r10, [rbp - 352] # reload L42 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 800], r11 # store tag L43
    mov [rbp - 360], r10 # spill L43 to slot
    mov r11, [rbp - 360] # reload L43 from spill slot
    mov r10, r11 # assign L44
    mov r11, [rbp - 800] # tag L43 from tag-slot
    mov [rbp - 808], r11 # store tag L44
    mov [rbp - 368], r10 # spill L44 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 352] # reload L42 from spill slot
    mov r11, r11 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 816], r11 # store tag L45
    mov [rbp - 376], r10 # spill L45 to slot
    mov r11, [rbp - 376] # reload L45 from spill slot
    mov r10, r11 # assign L46
    mov r11, [rbp - 816] # tag L45 from tag-slot
    mov [rbp - 824], r11 # store tag L46
    mov [rbp - 384], r10 # spill L46 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 368] # reload L44 from spill slot
    mov r11, r11 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 832], r11 # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    mov r11, [rbp - 392] # reload L47 from spill slot
    mov r10, r11 # assign L48
    mov r11, [rbp - 832] # tag L47 from tag-slot
    mov [rbp - 840], r11 # store tag L48
    mov [rbp - 400], r10 # spill L48 to slot
    mov r10, [rbp - 400] # reload L48 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 384] # reload L46 from spill slot
    mov r11, r11 # hv payload
    mov [rbp - 848], r11 # store tag L49
    mov [rbp - 408], r10 # spill L49 to slot
    mov rdx, [rbp - 408] # reload L49 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 848] # tag L49 from tag-slot
    add rsp, 848 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L16d1_rt_map_get_native_bb9:
    jmp .L16d1_rt_map_get_native_bb7 # branch
    add rsp, 848 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_map_contains_native
.hidden rt_map_contains_native
    .p2align 4
rt_map_contains_native:
    .loc 1 115 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 688 # prologue: alloc spill frame
    mov [rbp - 376], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 384], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L16d1_rt_map_contains_native_bb0:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r13, r10 # leaf: payload → dst L2
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 392], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 392] # tag L2 from tag-slot
    mov [rbp - 400], r11 # store tag L3
    mov r10, r14 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r15, r10 # leaf: payload → dst L4
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 408], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 408] # tag L4 from tag-slot
    mov [rbp - 416], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 424], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 424] # tag L6 from tag-slot
    mov [rbp - 432], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    mov r11, 16 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 440], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 440] # tag L8 from tag-slot
    mov [rbp - 448], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, 4294967295 # hv payload
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 456], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 456] # tag L10 from tag-slot
    mov [rbp - 464], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 384] # tag L1 from tag-slot
    call rt_map_fnv1a_native # call rt_map_fnv1a_native
    mov [rbp - 472], rax # store tag L12
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 472] # tag L12 from tag-slot
    mov [rbp - 480], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r10, r10 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 488], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 488] # tag L14 from tag-slot
    mov [rbp - 496], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, [rbp - 136] # reload L15 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 504], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, [rbp - 504] # tag L16 from tag-slot
    mov [rbp - 512], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, 0 # assign L18
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 520], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    jmp .L16d1_rt_map_contains_native_bb1 # branch
.L16d1_rt_map_contains_native_bb1:
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 160] # reload L18 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 528], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r10, [rbp - 168] # reload L19 from spill slot
    test r10, r10 # br_cond test
    jz .L16d1_rt_map_contains_native_bb3 # jump-if-zero -> else
    jmp .L16d1_rt_map_contains_native_bb2 # jump -> then
.L16d1_rt_map_contains_native_bb2:
    mov r11, 16 # hv payload
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 536], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r11, [rbp - 176] # reload L20 from spill slot
    mov r10, r11 # assign L21
    mov r11, [rbp - 536] # tag L20 from tag-slot
    mov [rbp - 544], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 552], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r11, [rbp - 192] # reload L22 from spill slot
    mov r10, r11 # assign L23
    mov r11, [rbp - 552] # tag L22 from tag-slot
    mov [rbp - 560], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r10, [rbp - 200] # reload L23 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 568], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r11, [rbp - 208] # reload L24 from spill slot
    mov r10, r11 # assign L25
    mov r11, [rbp - 568] # tag L24 from tag-slot
    mov [rbp - 576], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r10, [rbp - 216] # reload L25 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 584], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r10, [rbp - 224] # reload L26 from spill slot
    test r10, r10 # br_cond test
    jz .L16d1_rt_map_contains_native_bb5 # jump-if-zero -> else
    jmp .L16d1_rt_map_contains_native_bb4 # jump -> then
.L16d1_rt_map_contains_native_bb3:
    mov r10, 0 # hv payload
    mov r11, 0 # hv payload
    mov [rbp - 728], r11 # store tag L44
    mov [rbp - 368], r10 # spill L44 to slot
    mov rdx, [rbp - 368] # reload L44 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 728] # tag L44 from tag-slot
    add rsp, 688 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L16d1_rt_map_contains_native_bb4:
    mov r10, 0 # hv payload
    mov r11, 0 # hv payload
    mov [rbp - 600], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov rdx, [rbp - 240] # reload L28 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 600] # tag L28 from tag-slot
    add rsp, 688 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L16d1_rt_map_contains_native_bb5:
    mov r10, [rbp - 200] # reload L23 from spill slot
    mov r10, r10 # hv payload
    mov r11, 8 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 608], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r11, [rbp - 248] # reload L29 from spill slot
    mov r10, r11 # assign L30
    mov r11, [rbp - 608] # tag L29 from tag-slot
    mov [rbp - 616], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r11, 4294967295 # hv payload
    mov r10, [rbp - 256] # reload L30 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 624], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov r11, [rbp - 264] # reload L31 from spill slot
    mov r10, r11 # assign L32
    mov r11, [rbp - 624] # tag L31 from tag-slot
    mov [rbp - 632], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov r11, r11 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 640], r11 # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r10, [rbp - 280] # reload L33 from spill slot
    test r10, r10 # br_cond test
    jz .L16d1_rt_map_contains_native_bb7 # jump-if-zero -> else
    jmp .L16d1_rt_map_contains_native_bb6 # jump -> then
.L16d1_rt_map_contains_native_bb6:
    mov rsi, [rbp - 216] # reload L25 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 576] # tag L25 from tag-slot
    mov rcx, r12 # hv arg payload
    mov rdx, [rbp - 384] # tag L1 from tag-slot
    call rt_map_strcmp0_native # call rt_map_strcmp0_native
    mov [rbp - 656], rax # store tag L35
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 296], r10 # spill L35 to slot
    mov r11, [rbp - 296] # reload L35 from spill slot
    mov r10, r11 # assign L36
    mov r11, [rbp - 656] # tag L35 from tag-slot
    mov [rbp - 664], r11 # store tag L36
    mov [rbp - 304], r10 # spill L36 to slot
    mov r10, [rbp - 304] # reload L36 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 672], r11 # store tag L37
    mov [rbp - 312], r10 # spill L37 to slot
    mov r10, [rbp - 312] # reload L37 from spill slot
    test r10, r10 # br_cond test
    jz .L16d1_rt_map_contains_native_bb9 # jump-if-zero -> else
    jmp .L16d1_rt_map_contains_native_bb8 # jump -> then
.L16d1_rt_map_contains_native_bb7:
    mov r11, 1 # hv payload
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 696], r11 # store tag L40
    mov [rbp - 336], r10 # spill L40 to slot
    mov r11, [rbp - 336] # reload L40 from spill slot
    mov r10, r11 # assign L41
    mov r11, [rbp - 696] # tag L40 from tag-slot
    mov [rbp - 704], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    mov r11, [rbp - 136] # reload L15 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 712], r11 # store tag L42
    mov [rbp - 352], r10 # spill L42 to slot
    mov r11, [rbp - 352] # reload L42 from spill slot
    mov r10, r11 # assign L17
    mov r11, [rbp - 712] # tag L42 from tag-slot
    mov [rbp - 512], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 160] # reload L18 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 720], r11 # store tag L43
    mov [rbp - 360], r10 # spill L43 to slot
    mov r11, [rbp - 360] # reload L43 from spill slot
    mov r10, r11 # assign L18
    mov r11, [rbp - 720] # tag L43 from tag-slot
    mov [rbp - 520], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    jmp .L16d1_rt_map_contains_native_bb1 # branch
.L16d1_rt_map_contains_native_bb8:
    mov r10, 1 # hv payload
    mov r11, 0 # hv payload
    mov [rbp - 688], r11 # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    mov rdx, [rbp - 328] # reload L39 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 688] # tag L39 from tag-slot
    add rsp, 688 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L16d1_rt_map_contains_native_bb9:
    jmp .L16d1_rt_map_contains_native_bb7 # branch
    add rsp, 688 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_map_set_inplace_native
.hidden rt_map_set_inplace_native
    .p2align 4
rt_map_set_inplace_native:
    .loc 1 163 0
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
    mov [rbp - 576], r8 # store tag L2
    mov r13, r9 # ingress param payload
.L16d1_rt_map_set_inplace_native_bb0:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r14, r10 # leaf: payload → dst L3
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 584], r11 # store tag L3
    mov r15, r14 # assign L4
    mov r11, [rbp - 584] # tag L3 from tag-slot
    mov [rbp - 592], r11 # store tag L4
    mov r10, r15 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 600], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r10, r11 # assign L6
    mov r11, [rbp - 600] # tag L5 from tag-slot
    mov [rbp - 608], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 616], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 616] # tag L7 from tag-slot
    mov [rbp - 624], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    mov r11, 8 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 632], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r10, r11 # assign L10
    mov r11, [rbp - 632] # tag L9 from tag-slot
    mov [rbp - 640], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    mov r11, 32 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 648], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 648] # tag L11 from tag-slot
    mov [rbp - 656], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    mov r10, r10 # hv payload
    mov r11, 16 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 664], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov r10, r11 # assign L14
    mov r11, [rbp - 664] # tag L13 from tag-slot
    mov [rbp - 672], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, 4294967295 # hv payload
    mov r10, [rbp - 128] # reload L14 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 680], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, [rbp - 136] # reload L15 from spill slot
    mov r10, r11 # assign L16
    mov r11, [rbp - 680] # tag L15 from tag-slot
    mov [rbp - 688], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 568] # tag L1 from tag-slot
    call rt_map_fnv1a_native # call rt_map_fnv1a_native
    mov [rbp - 696], rax # store tag L17
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 152], r10 # spill L17 to slot
    mov r11, [rbp - 152] # reload L17 from spill slot
    mov r10, r11 # assign L18
    mov r11, [rbp - 696] # tag L17 from tag-slot
    mov [rbp - 704], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 144] # reload L16 from spill slot
    mov r10, r10 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 712], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov r10, r11 # assign L20
    mov r11, [rbp - 712] # tag L19 from tag-slot
    mov [rbp - 720], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r11, [rbp - 176] # reload L20 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 160] # reload L18 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 728], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 728] # tag L21 from tag-slot
    mov [rbp - 736], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r10, 0 # assign L23
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 744], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r10, [rbp - 576] # tag L2 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 752], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r11, [rbp - 208] # reload L24 from spill slot
    mov r10, r11 # assign L25
    mov r11, [rbp - 752] # tag L24 from tag-slot
    mov [rbp - 760], r11 # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r11, 0 # hv payload
    mov r10, r13 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 768], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r11, [rbp - 224] # reload L26 from spill slot
    mov r10, r11 # assign L27
    mov r11, [rbp - 768] # tag L26 from tag-slot
    mov [rbp - 776], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    jmp .L16d1_rt_map_set_inplace_native_bb1 # branch
.L16d1_rt_map_set_inplace_native_bb1:
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 200] # reload L23 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 784], r11 # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r10, [rbp - 240] # reload L28 from spill slot
    test r10, r10 # br_cond test
    jz .L16d1_rt_map_set_inplace_native_bb3 # jump-if-zero -> else
    jmp .L16d1_rt_map_set_inplace_native_bb2 # jump -> then
.L16d1_rt_map_set_inplace_native_bb2:
    mov r11, 16 # hv payload
    mov r10, [rbp - 192] # reload L22 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 792], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r11, [rbp - 248] # reload L29 from spill slot
    mov r10, r11 # assign L30
    mov r11, [rbp - 792] # tag L29 from tag-slot
    mov [rbp - 800], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r11, [rbp - 256] # reload L30 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 808], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov r11, [rbp - 264] # reload L31 from spill slot
    mov r10, r11 # assign L32
    mov r11, [rbp - 808] # tag L31 from tag-slot
    mov [rbp - 816], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 824], r11 # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r11, [rbp - 280] # reload L33 from spill slot
    mov r10, r11 # assign L34
    mov r11, [rbp - 824] # tag L33 from tag-slot
    mov [rbp - 832], r11 # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    mov r10, [rbp - 288] # reload L34 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 840], r11 # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    mov r10, [rbp - 296] # reload L35 from spill slot
    test r10, r10 # br_cond test
    jz .L16d1_rt_map_set_inplace_native_bb5 # jump-if-zero -> else
    jmp .L16d1_rt_map_set_inplace_native_bb4 # jump -> then
.L16d1_rt_map_set_inplace_native_bb3:
    mov r10, 0 # hv payload
    mov r11, 0 # hv payload
    mov [rbp - 1096], r11 # store tag L67
    mov [rbp - 552], r10 # spill L67 to slot
    mov rdx, [rbp - 552] # reload L67 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 1096] # tag L67 from tag-slot
    add rsp, 1056 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L16d1_rt_map_set_inplace_native_bb4:
    mov r10, 0 # hv payload
    mov r11, 0 # hv payload
    mov [rbp - 856], r11 # store tag L37
    mov [rbp - 312], r10 # spill L37 to slot
    mov rdx, [rbp - 312] # reload L37 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 856] # tag L37 from tag-slot
    add rsp, 1056 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L16d1_rt_map_set_inplace_native_bb5:
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov r10, r10 # hv payload
    mov r11, 8 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 864], r11 # store tag L38
    mov [rbp - 320], r10 # spill L38 to slot
    mov r11, [rbp - 320] # reload L38 from spill slot
    mov r10, r11 # assign L39
    mov r11, [rbp - 864] # tag L38 from tag-slot
    mov [rbp - 872], r11 # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    mov r11, 4294967295 # hv payload
    mov r10, [rbp - 328] # reload L39 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 880], r11 # store tag L40
    mov [rbp - 336], r10 # spill L40 to slot
    mov r11, [rbp - 336] # reload L40 from spill slot
    mov r10, r11 # assign L41
    mov r11, [rbp - 880] # tag L40 from tag-slot
    mov [rbp - 888], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    mov r10, [rbp - 344] # reload L41 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov r11, r11 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 896], r11 # store tag L42
    mov [rbp - 352], r10 # spill L42 to slot
    mov r10, [rbp - 352] # reload L42 from spill slot
    test r10, r10 # br_cond test
    jz .L16d1_rt_map_set_inplace_native_bb7 # jump-if-zero -> else
    jmp .L16d1_rt_map_set_inplace_native_bb6 # jump -> then
.L16d1_rt_map_set_inplace_native_bb6:
    mov rsi, [rbp - 288] # reload L34 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 832] # tag L34 from tag-slot
    mov rcx, r12 # hv arg payload
    mov rdx, [rbp - 568] # tag L1 from tag-slot
    call rt_map_strcmp0_native # call rt_map_strcmp0_native
    mov [rbp - 912], rax # store tag L44
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 368], r10 # spill L44 to slot
    mov r11, [rbp - 368] # reload L44 from spill slot
    mov r10, r11 # assign L45
    mov r11, [rbp - 912] # tag L44 from tag-slot
    mov [rbp - 920], r11 # store tag L45
    mov [rbp - 376], r10 # spill L45 to slot
    mov r10, [rbp - 376] # reload L45 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 928], r11 # store tag L46
    mov [rbp - 384], r10 # spill L46 to slot
    mov r10, [rbp - 384] # reload L46 from spill slot
    test r10, r10 # br_cond test
    jz .L16d1_rt_map_set_inplace_native_bb9 # jump-if-zero -> else
    jmp .L16d1_rt_map_set_inplace_native_bb8 # jump -> then
.L16d1_rt_map_set_inplace_native_bb7:
    mov r11, 1 # hv payload
    mov r10, [rbp - 192] # reload L22 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1064], r11 # store tag L63
    mov [rbp - 520], r10 # spill L63 to slot
    mov r11, [rbp - 520] # reload L63 from spill slot
    mov r10, r11 # assign L64
    mov r11, [rbp - 1064] # tag L63 from tag-slot
    mov [rbp - 1072], r11 # store tag L64
    mov [rbp - 528], r10 # spill L64 to slot
    mov r11, [rbp - 176] # reload L20 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 528] # reload L64 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1080], r11 # store tag L65
    mov [rbp - 536], r10 # spill L65 to slot
    mov r11, [rbp - 536] # reload L65 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 1080] # tag L65 from tag-slot
    mov [rbp - 736], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 200] # reload L23 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1088], r11 # store tag L66
    mov [rbp - 544], r10 # spill L66 to slot
    mov r11, [rbp - 544] # reload L66 from spill slot
    mov r10, r11 # assign L23
    mov r11, [rbp - 1088] # tag L66 from tag-slot
    mov [rbp - 744], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    jmp .L16d1_rt_map_set_inplace_native_bb1 # branch
.L16d1_rt_map_set_inplace_native_bb8:
    mov r11, 16 # hv payload
    mov r10, [rbp - 192] # reload L22 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 944], r11 # store tag L48
    mov [rbp - 400], r10 # spill L48 to slot
    mov r11, [rbp - 400] # reload L48 from spill slot
    mov r10, r11 # assign L49
    mov r11, [rbp - 944] # tag L48 from tag-slot
    mov [rbp - 952], r11 # store tag L49
    mov [rbp - 408], r10 # spill L49 to slot
    mov r11, 8 # hv payload
    mov r10, [rbp - 408] # reload L49 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 960], r11 # store tag L50
    mov [rbp - 416], r10 # spill L50 to slot
    mov r11, [rbp - 416] # reload L50 from spill slot
    mov r10, r11 # assign L51
    mov r11, [rbp - 960] # tag L50 from tag-slot
    mov [rbp - 968], r11 # store tag L51
    mov [rbp - 424], r10 # spill L51 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 408] # reload L49 from spill slot
    mov r11, r11 # hv payload
    mov rsi, [rbp - 216] # reload L25 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 976], r11 # store tag L52
    mov [rbp - 432], r10 # spill L52 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 424] # reload L51 from spill slot
    mov r11, r11 # hv payload
    mov rsi, [rbp - 232] # reload L27 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 984], r11 # store tag L53
    mov [rbp - 440], r10 # spill L53 to slot
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov r10, r10 # hv payload
    mov r11, 12 # hv payload
    add r10, r11 # __hx_ptr_load32: addr = ptr + off
    mov r10d, dword ptr [r10] # __hx_ptr_load32: r10d = *(i32*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 992], r11 # store tag L54
    mov [rbp - 448], r10 # spill L54 to slot
    mov r11, [rbp - 448] # reload L54 from spill slot
    mov r10, r11 # assign L55
    mov r11, [rbp - 992] # tag L54 from tag-slot
    mov [rbp - 1000], r11 # store tag L55
    mov [rbp - 456], r10 # spill L55 to slot
    mov r11, 16 # hv payload
    mov r10, [rbp - 456] # reload L55 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1008], r11 # store tag L56
    mov [rbp - 464], r10 # spill L56 to slot
    mov r11, [rbp - 464] # reload L56 from spill slot
    mov r10, r11 # assign L57
    mov r11, [rbp - 1008] # tag L56 from tag-slot
    mov [rbp - 1016], r11 # store tag L57
    mov [rbp - 472], r10 # spill L57 to slot
    mov r11, 8 # hv payload
    mov r10, [rbp - 472] # reload L57 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1024], r11 # store tag L58
    mov [rbp - 480], r10 # spill L58 to slot
    mov r11, [rbp - 480] # reload L58 from spill slot
    mov r10, r11 # assign L59
    mov r11, [rbp - 1024] # tag L58 from tag-slot
    mov [rbp - 1032], r11 # store tag L59
    mov [rbp - 488], r10 # spill L59 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 472] # reload L57 from spill slot
    mov r11, r11 # hv payload
    mov rsi, [rbp - 216] # reload L25 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1040], r11 # store tag L60
    mov [rbp - 496], r10 # spill L60 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 488] # reload L59 from spill slot
    mov r11, r11 # hv payload
    mov rsi, [rbp - 232] # reload L27 from spill slot
    mov rsi, rsi # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1048], r11 # store tag L61
    mov [rbp - 504], r10 # spill L61 to slot
    mov r10, 1 # hv payload
    mov r11, 0 # hv payload
    mov [rbp - 1056], r11 # store tag L62
    mov [rbp - 512], r10 # spill L62 to slot
    mov rdx, [rbp - 512] # reload L62 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 1056] # tag L62 from tag-slot
    add rsp, 1056 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L16d1_rt_map_set_inplace_native_bb9:
    jmp .L16d1_rt_map_set_inplace_native_bb7 # branch
    add rsp, 1056 # epilogue: free spill frame
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
