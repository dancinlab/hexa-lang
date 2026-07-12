// map_query_x86_64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B — map-query DISPATCH).
// GENERATED: tool/regen_map_query_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=x86_64-linux-gnu -o map_query_x86_64.s stdlib/runtime/map_query.hexa.
//   Provides the 8 map-query dispatcher natives (hexa_map_keys/values/entries/
//   map_values/filter_keys/count/any/all) as HX_MAP_TBL null-guard + delegate to
//   the already-hexa-source rt_map_* bodies. hexa_map_contains_key stays C
//   (mixed HexaVal/char*/int ABI — HEXA_RT_CORE_MAP_QUERY_CONTAINS_NATIVE sub-guard).
//   ABI: ELF, no underscore. External: delegates+ctors (all carrier-resolved in runtime.a, ZERO libc UND).
//   Lets stage_resolve_runtime_a define HEXA_RT_CORE_MAP_QUERY_DISPATCH_NATIVE + ar
//   this .o into runtime.a so the 8 dispatchers drop from the compiled runtime_core.c.
# hexa-lang emit pass — target=x86_64-linux-gnu
# source: /tmp/isowt2/stdlib/runtime/map_query.hexa
.intel_syntax noprefix
.file 1 "stdlib/runtime/map_query.hexa"
.text
.globl hexa_map_keys
.hidden hexa_map_keys
    .p2align 4
hexa_map_keys:
    .loc 1 53 0
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
.L50a1_hexa_map_keys_bb0:
    mov r12, [rbp - 128] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 136], r11 # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 136] # tag L1 from tag-slot
    mov [rbp - 144], r11 # store tag L2
    mov r11, 6 # hv payload
    mov r10, r13 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r14, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 152], r11 # store tag L3
    test r14, r14 # br_cond test
    jz .L50a1_hexa_map_keys_bb2 # jump-if-zero -> else
    jmp .L50a1_hexa_map_keys_bb1 # jump -> then
.L50a1_hexa_map_keys_bb1:
    call hexa_array_new # call hexa_array_new
    mov [rbp - 168], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    mov rdx, [rbp - 56] # reload L5 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 168] # tag L5 from tag-slot
    add rsp, 192 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L50a1_hexa_map_keys_bb2:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 176], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 176] # tag L6 from tag-slot
    mov [rbp - 184], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
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
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 208], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    test r10, r10 # br_cond test
    jz .L50a1_hexa_map_keys_bb4 # jump-if-zero -> else
    jmp .L50a1_hexa_map_keys_bb3 # jump -> then
.L50a1_hexa_map_keys_bb3:
    call hexa_array_new # call hexa_array_new
    mov [rbp - 224], rax # store tag L12
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 112], r10 # spill L12 to slot
    mov rdx, [rbp - 112] # reload L12 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 224] # tag L12 from tag-slot
    add rsp, 192 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L50a1_hexa_map_keys_bb4:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 128] # tag L0 from tag-slot
    call rt_map_keys # call rt_map_keys
    mov [rbp - 232], rax # store tag L13
    mov r10, rdx # hv: unbox user-call result payload
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
.globl hexa_map_values
.hidden hexa_map_values
    .p2align 4
hexa_map_values:
    .loc 1 62 0
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
.L50a1_hexa_map_values_bb0:
    mov r12, [rbp - 128] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 136], r11 # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 136] # tag L1 from tag-slot
    mov [rbp - 144], r11 # store tag L2
    mov r11, 6 # hv payload
    mov r10, r13 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r14, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 152], r11 # store tag L3
    test r14, r14 # br_cond test
    jz .L50a1_hexa_map_values_bb2 # jump-if-zero -> else
    jmp .L50a1_hexa_map_values_bb1 # jump -> then
.L50a1_hexa_map_values_bb1:
    call hexa_array_new # call hexa_array_new
    mov [rbp - 168], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    mov rdx, [rbp - 56] # reload L5 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 168] # tag L5 from tag-slot
    add rsp, 192 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L50a1_hexa_map_values_bb2:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 176], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 176] # tag L6 from tag-slot
    mov [rbp - 184], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
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
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 208], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    test r10, r10 # br_cond test
    jz .L50a1_hexa_map_values_bb4 # jump-if-zero -> else
    jmp .L50a1_hexa_map_values_bb3 # jump -> then
.L50a1_hexa_map_values_bb3:
    call hexa_array_new # call hexa_array_new
    mov [rbp - 224], rax # store tag L12
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 112], r10 # spill L12 to slot
    mov rdx, [rbp - 112] # reload L12 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 224] # tag L12 from tag-slot
    add rsp, 192 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L50a1_hexa_map_values_bb4:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 128] # tag L0 from tag-slot
    call rt_map_values # call rt_map_values
    mov [rbp - 232], rax # store tag L13
    mov r10, rdx # hv: unbox user-call result payload
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
.globl hexa_map_entries
.hidden hexa_map_entries
    .p2align 4
hexa_map_entries:
    .loc 1 71 0
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
.L50a1_hexa_map_entries_bb0:
    mov r12, [rbp - 128] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 136], r11 # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 136] # tag L1 from tag-slot
    mov [rbp - 144], r11 # store tag L2
    mov r11, 6 # hv payload
    mov r10, r13 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r14, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 152], r11 # store tag L3
    test r14, r14 # br_cond test
    jz .L50a1_hexa_map_entries_bb2 # jump-if-zero -> else
    jmp .L50a1_hexa_map_entries_bb1 # jump -> then
.L50a1_hexa_map_entries_bb1:
    call hexa_array_new # call hexa_array_new
    mov [rbp - 168], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    mov rdx, [rbp - 56] # reload L5 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 168] # tag L5 from tag-slot
    add rsp, 192 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L50a1_hexa_map_entries_bb2:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 176], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 176] # tag L6 from tag-slot
    mov [rbp - 184], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
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
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 208], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    test r10, r10 # br_cond test
    jz .L50a1_hexa_map_entries_bb4 # jump-if-zero -> else
    jmp .L50a1_hexa_map_entries_bb3 # jump -> then
.L50a1_hexa_map_entries_bb3:
    call hexa_array_new # call hexa_array_new
    mov [rbp - 224], rax # store tag L12
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 112], r10 # spill L12 to slot
    mov rdx, [rbp - 112] # reload L12 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 224] # tag L12 from tag-slot
    add rsp, 192 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L50a1_hexa_map_entries_bb4:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 128] # tag L0 from tag-slot
    call rt_map_entries # call rt_map_entries
    mov [rbp - 232], rax # store tag L13
    mov r10, rdx # hv: unbox user-call result payload
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
.globl hexa_map_map_values
.hidden hexa_map_map_values
    .p2align 4
hexa_map_map_values:
    .loc 1 82 0
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
.L50a1_hexa_map_map_values_bb0:
    call hexa_map_new # call hexa_map_new
    mov [rbp - 152], rax # store tag L2
    mov r13, rdx # hv: unbox user-call result payload
    mov r14, r13 # assign L3
    mov r11, [rbp - 152] # tag L2 from tag-slot
    mov [rbp - 160], r11 # store tag L3
    mov r15, [rbp - 136] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 168], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 168] # tag L4 from tag-slot
    mov [rbp - 176], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, 6 # hv payload
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 184], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    test r10, r10 # br_cond test
    jz .L50a1_hexa_map_map_values_bb2 # jump-if-zero -> else
    jmp .L50a1_hexa_map_map_values_bb1 # jump -> then
.L50a1_hexa_map_map_values_bb1:
    mov rdx, r14 # hv arg payload
    mov rax, [rbp - 160] # tag L3 from tag-slot
    add rsp, 208 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L50a1_hexa_map_map_values_bb2:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 200], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 200] # tag L8 from tag-slot
    mov [rbp - 208], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 216], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 216] # tag L10 from tag-slot
    mov [rbp - 224], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 232], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    test r10, r10 # br_cond test
    jz .L50a1_hexa_map_map_values_bb4 # jump-if-zero -> else
    jmp .L50a1_hexa_map_map_values_bb3 # jump -> then
.L50a1_hexa_map_map_values_bb3:
    mov rdx, r14 # hv arg payload
    mov rax, [rbp - 160] # tag L3 from tag-slot
    add rsp, 208 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L50a1_hexa_map_map_values_bb4:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 136] # tag L0 from tag-slot
    mov rcx, r12 # hv arg payload
    mov rdx, [rbp - 144] # tag L1 from tag-slot
    mov r9, r14 # hv arg payload
    mov r8, [rbp - 160] # tag L3 from tag-slot
    call rt_map_map_values # call rt_map_map_values
    mov [rbp - 248], rax # store tag L14
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 128], r10 # spill L14 to slot
    mov rdx, [rbp - 128] # reload L14 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 248] # tag L14 from tag-slot
    add rsp, 208 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_map_filter_keys
.hidden hexa_map_filter_keys
    .p2align 4
hexa_map_filter_keys:
    .loc 1 92 0
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
.L50a1_hexa_map_filter_keys_bb0:
    call hexa_map_new # call hexa_map_new
    mov [rbp - 152], rax # store tag L2
    mov r13, rdx # hv: unbox user-call result payload
    mov r14, r13 # assign L3
    mov r11, [rbp - 152] # tag L2 from tag-slot
    mov [rbp - 160], r11 # store tag L3
    mov r15, [rbp - 136] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 168], r11 # store tag L4
    mov r10, r15 # assign L5
    mov r11, [rbp - 168] # tag L4 from tag-slot
    mov [rbp - 176], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r11, 6 # hv payload
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 184], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    test r10, r10 # br_cond test
    jz .L50a1_hexa_map_filter_keys_bb2 # jump-if-zero -> else
    jmp .L50a1_hexa_map_filter_keys_bb1 # jump -> then
.L50a1_hexa_map_filter_keys_bb1:
    mov rdx, r14 # hv arg payload
    mov rax, [rbp - 160] # tag L3 from tag-slot
    add rsp, 208 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L50a1_hexa_map_filter_keys_bb2:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 200], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 200] # tag L8 from tag-slot
    mov [rbp - 208], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 216], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 216] # tag L10 from tag-slot
    mov [rbp - 224], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 232], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    test r10, r10 # br_cond test
    jz .L50a1_hexa_map_filter_keys_bb4 # jump-if-zero -> else
    jmp .L50a1_hexa_map_filter_keys_bb3 # jump -> then
.L50a1_hexa_map_filter_keys_bb3:
    mov rdx, r14 # hv arg payload
    mov rax, [rbp - 160] # tag L3 from tag-slot
    add rsp, 208 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L50a1_hexa_map_filter_keys_bb4:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 136] # tag L0 from tag-slot
    mov rcx, r12 # hv arg payload
    mov rdx, [rbp - 144] # tag L1 from tag-slot
    mov r9, r14 # hv arg payload
    mov r8, [rbp - 160] # tag L3 from tag-slot
    call rt_map_filter_keys # call rt_map_filter_keys
    mov [rbp - 248], rax # store tag L14
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 128], r10 # spill L14 to slot
    mov rdx, [rbp - 128] # reload L14 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 248] # tag L14 from tag-slot
    add rsp, 208 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_map_count
.hidden hexa_map_count
    .p2align 4
hexa_map_count:
    .loc 1 104 0
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
.L50a1_hexa_map_count_bb0:
    mov r13, [rbp - 208] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 224], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 224] # tag L2 from tag-slot
    mov [rbp - 232], r11 # store tag L3
    mov r11, 6 # hv payload
    mov r10, r14 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r15, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 240], r11 # store tag L4
    test r15, r15 # br_cond test
    jz .L50a1_hexa_map_count_bb2 # jump-if-zero -> else
    jmp .L50a1_hexa_map_count_bb1 # jump -> then
.L50a1_hexa_map_count_bb1:
    mov r10, 0 # hv payload
    mov r11, 0 # hv payload
    mov [rbp - 256], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov rdx, [rbp - 64] # reload L6 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 256] # tag L6 from tag-slot
    add rsp, 352 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L50a1_hexa_map_count_bb2:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 264], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 264] # tag L7 from tag-slot
    mov [rbp - 272], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 280], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r10, r11 # assign L10
    mov r11, [rbp - 280] # tag L9 from tag-slot
    mov [rbp - 288], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 296], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 104] # reload L11 from spill slot
    test r10, r10 # br_cond test
    jz .L50a1_hexa_map_count_bb4 # jump-if-zero -> else
    jmp .L50a1_hexa_map_count_bb3 # jump -> then
.L50a1_hexa_map_count_bb3:
    mov r10, 0 # hv payload
    mov r11, 0 # hv payload
    mov [rbp - 312], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov rdx, [rbp - 120] # reload L13 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 312] # tag L13 from tag-slot
    add rsp, 352 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L50a1_hexa_map_count_bb4:
    mov r10, [rbp - 216] # tag L1 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 320], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 320] # tag L14 from tag-slot
    mov [rbp - 328], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov r10, r10 # hv payload
    mov r11, 4 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 336], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r10, [rbp - 144] # reload L16 from spill slot
    test r10, r10 # br_cond test
    jz .L50a1_hexa_map_count_bb6 # jump-if-zero -> else
    jmp .L50a1_hexa_map_count_bb5 # jump -> then
.L50a1_hexa_map_count_bb5:
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov r10, r10 # hv payload
    mov r11, 40 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 352], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov r10, r11 # assign L19
    mov r11, [rbp - 352] # tag L18 from tag-slot
    mov [rbp - 360], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r11, 4294967295 # hv payload
    mov r10, [rbp - 168] # reload L19 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 368], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r11, [rbp - 176] # reload L20 from spill slot
    mov r10, r11 # assign L21
    mov r11, [rbp - 368] # tag L20 from tag-slot
    mov [rbp - 376], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r10, [rbp - 184] # reload L21 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    mov [rbp - 384], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov rdx, [rbp - 192] # reload L22 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 384] # tag L22 from tag-slot
    add rsp, 352 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L50a1_hexa_map_count_bb6:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 208] # tag L0 from tag-slot
    mov rcx, r12 # hv arg payload
    mov rdx, [rbp - 216] # tag L1 from tag-slot
    call rt_map_count_pred # call rt_map_count_pred
    mov [rbp - 392], rax # store tag L23
    mov r10, rdx # hv: unbox user-call result payload
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
.globl hexa_map_any
.hidden hexa_map_any
    .p2align 4
hexa_map_any:
    .loc 1 121 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 288 # prologue: alloc spill frame
    mov [rbp - 176], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 184], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L50a1_hexa_map_any_bb0:
    mov r13, [rbp - 176] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 192], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 192] # tag L2 from tag-slot
    mov [rbp - 200], r11 # store tag L3
    mov r11, 6 # hv payload
    mov r10, r14 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r15, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 208], r11 # store tag L4
    test r15, r15 # br_cond test
    jz .L50a1_hexa_map_any_bb2 # jump-if-zero -> else
    jmp .L50a1_hexa_map_any_bb1 # jump -> then
.L50a1_hexa_map_any_bb1:
    mov r10, 0 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 224], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov rdx, [rbp - 64] # reload L6 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 224] # tag L6 from tag-slot
    add rsp, 288 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L50a1_hexa_map_any_bb2:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 232], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 232] # tag L7 from tag-slot
    mov [rbp - 240], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 248], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r10, r11 # assign L10
    mov r11, [rbp - 248] # tag L9 from tag-slot
    mov [rbp - 256], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 264], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 104] # reload L11 from spill slot
    test r10, r10 # br_cond test
    jz .L50a1_hexa_map_any_bb4 # jump-if-zero -> else
    jmp .L50a1_hexa_map_any_bb3 # jump -> then
.L50a1_hexa_map_any_bb3:
    mov r10, 0 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 280], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov rdx, [rbp - 120] # reload L13 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 280] # tag L13 from tag-slot
    add rsp, 288 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L50a1_hexa_map_any_bb4:
    mov r10, [rbp - 184] # tag L1 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 288], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 288] # tag L14 from tag-slot
    mov [rbp - 296], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov r10, r10 # hv payload
    mov r11, 4 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 304], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r10, [rbp - 144] # reload L16 from spill slot
    test r10, r10 # br_cond test
    jz .L50a1_hexa_map_any_bb6 # jump-if-zero -> else
    jmp .L50a1_hexa_map_any_bb5 # jump -> then
.L50a1_hexa_map_any_bb5:
    mov r10, 0 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 320], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov rdx, [rbp - 160] # reload L18 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 320] # tag L18 from tag-slot
    add rsp, 288 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L50a1_hexa_map_any_bb6:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 176] # tag L0 from tag-slot
    mov rcx, r12 # hv arg payload
    mov rdx, [rbp - 184] # tag L1 from tag-slot
    call rt_map_any_pred_b # call rt_map_any_pred_b
    mov [rbp - 328], rax # store tag L19
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 168], r10 # spill L19 to slot
    mov rdx, [rbp - 168] # reload L19 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 328] # tag L19 from tag-slot
    add rsp, 288 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_map_all
.hidden hexa_map_all
    .p2align 4
hexa_map_all:
    .loc 1 133 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 288 # prologue: alloc spill frame
    mov [rbp - 176], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 184], rdx # store tag L1
    mov r12, rcx # ingress param payload
.L50a1_hexa_map_all_bb0:
    mov r13, [rbp - 176] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 192], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 192] # tag L2 from tag-slot
    mov [rbp - 200], r11 # store tag L3
    mov r11, 6 # hv payload
    mov r10, r14 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r15, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 208], r11 # store tag L4
    test r15, r15 # br_cond test
    jz .L50a1_hexa_map_all_bb2 # jump-if-zero -> else
    jmp .L50a1_hexa_map_all_bb1 # jump -> then
.L50a1_hexa_map_all_bb1:
    mov r10, 1 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 224], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov rdx, [rbp - 64] # reload L6 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 224] # tag L6 from tag-slot
    add rsp, 288 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L50a1_hexa_map_all_bb2:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 232], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r10, r11 # assign L8
    mov r11, [rbp - 232] # tag L7 from tag-slot
    mov [rbp - 240], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 248], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov r10, r11 # assign L10
    mov r11, [rbp - 248] # tag L9 from tag-slot
    mov [rbp - 256], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 264], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r10, [rbp - 104] # reload L11 from spill slot
    test r10, r10 # br_cond test
    jz .L50a1_hexa_map_all_bb4 # jump-if-zero -> else
    jmp .L50a1_hexa_map_all_bb3 # jump -> then
.L50a1_hexa_map_all_bb3:
    mov r10, 1 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 280], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov rdx, [rbp - 120] # reload L13 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 280] # tag L13 from tag-slot
    add rsp, 288 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L50a1_hexa_map_all_bb4:
    mov r10, [rbp - 184] # tag L1 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 288], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 288] # tag L14 from tag-slot
    mov [rbp - 296], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    mov r10, r10 # hv payload
    mov r11, 4 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 304], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r10, [rbp - 144] # reload L16 from spill slot
    test r10, r10 # br_cond test
    jz .L50a1_hexa_map_all_bb6 # jump-if-zero -> else
    jmp .L50a1_hexa_map_all_bb5 # jump -> then
.L50a1_hexa_map_all_bb5:
    mov r10, 1 # hv payload
    mov r11, 2 # hv payload
    mov [rbp - 320], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov rdx, [rbp - 160] # reload L18 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 320] # tag L18 from tag-slot
    add rsp, 288 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L50a1_hexa_map_all_bb6:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 176] # tag L0 from tag-slot
    mov rcx, r12 # hv arg payload
    mov rdx, [rbp - 184] # tag L1 from tag-slot
    call rt_map_all_pred_b # call rt_map_all_pred_b
    mov [rbp - 328], rax # store tag L19
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 168], r10 # spill L19 to slot
    mov rdx, [rbp - 168] # reload L19 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 328] # tag L19 from tag-slot
    add rsp, 288 # epilogue: free spill frame
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
