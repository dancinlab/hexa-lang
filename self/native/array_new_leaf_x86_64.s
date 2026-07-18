// array_new_leaf_x86_64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE — array ARR-NEW constructors).
// GENERATED: tool/regen_array_new_leaf_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=x86_64-linux-gnu -o array_new_leaf_x86_64.s stdlib/runtime/array_new_leaf.hexa.
//   Provides the empty-array constructor native (hexa_array_new · carrier mint + explicit zero).
//   ABI: ELF, no underscore. External U-floor: hexa_heap_zalloc hexa_exit hexa_bool — CARRIER-ONLY (HexaVal-ABI); a raw libc U here is a
//   pair-vs-C-ABI miscompile, not a sanctioned floor entrant (the #4930 break).
//   Lets stage_resolve_runtime_a define HEXA_RT_CORE_ARRAY_ZEROS_LEAF_NATIVE + ar this
//   .o into runtime.a so hexa_array_new drops from the compiled runtime_core.c.
# hexa-lang emit pass — target=x86_64-linux-gnu
# source: /home/aiden/hexa-lang/stdlib/runtime/array_new_leaf.hexa
.intel_syntax noprefix
.file 1 "stdlib/runtime/array_new_leaf.hexa"
.text
.globl hexa_array_new
.hidden hexa_array_new
    .p2align 4
hexa_array_new:
    .loc 1 56 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 64 # prologue: alloc spill frame
.L0635_hexa_array_new_bb0:
    mov rsi, 32 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    call hexa_heap_zalloc # call hexa_heap_zalloc
    mov [rbp - 64], rax # store tag L0
    mov rbx, rdx # hv: unbox user-call result payload
    mov r12, rbx # assign L1
    mov r11, 0 # tag L0 = TAG_INT (i64-local, fused)
    mov [rbp - 72], r11 # store tag L1
    mov r10, r12 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r13, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 80], r11 # store tag L2
    test r13, r13 # br_cond test
    jz .L0635_hexa_array_new_bb2 # jump-if-zero -> else
    jmp .L0635_hexa_array_new_bb1 # jump -> then
.L0635_hexa_array_new_bb1:
    mov rsi, 1 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    call hexa_exit # call hexa_exit
    mov [rbp - 96], rax # store tag L4
    mov r15, rdx # hv: unbox user-call result payload
    jmp .L0635_hexa_array_new_bb2 # branch
.L0635_hexa_array_new_bb2:
    mov r10, r12 # hv payload
    mov r11, 5 # hv payload
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
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .note.GNU-stack,"",@progbits
