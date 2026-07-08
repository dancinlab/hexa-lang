// alloc_syscall_x86_64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE-ZEROC b3a alloc+syscall).
// GENERATED: tool/regen_alloc_syscall_native_s.sh — aprime _drv.hexa --emit=asm
//   --target=x86_64-linux-gnu (flattened self/rt/alloc.hexa = alloc+syscall).
//   Native alloc+syscall bodies (hexa_arena_*/hexa_ptr_*/sys_*/rt_init) over the
//   M5 leaf surface (__hx_syscall6/__hx_ptr_*/__hx_target_os/__hx_str_ptr + the
//   module-global write path). hexat C-transpile cannot lower these, so they
//   enter runtime.a ONLY via this seed. RUN-proven (F-M5-GSLOT-VAL-DONE, exit 0).
//   ABI: ELF x86_64.
# hexa-lang emit pass — target=x86_64-linux-gnu
# source: /tmp/regen_alloc_syscall.DaawSO/alloc-flat.hexa
.intel_syntax noprefix
.file 1 "self/rt/alloc.hexa"
.text
.globl target_is_linux
.hidden target_is_linux
    .p2align 4
target_is_linux:
    .loc 1 28 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 16 # prologue: alloc spill frame
.Lb05c_target_is_linux_bb0:
    mov r10, 0 # __hx_target_os: 0 = linux
    mov rbx, r10 # leaf: payload → dst L0
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 56], r11 # store tag L0
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 56] # tag L0 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r12, rdx # binop ==: capture bool payload
    mov [rbp - 64], rax # store tag L1
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
.globl target_is_darwin
.hidden target_is_darwin
    .p2align 4
target_is_darwin:
    .loc 1 29 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 16 # prologue: alloc spill frame
.Lb05c_target_is_darwin_bb0:
    mov r10, 0 # __hx_target_os: 0 = linux
    mov rbx, r10 # leaf: payload → dst L0
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 56], r11 # store tag L0
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 56] # tag L0 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r12, rdx # binop ==: capture bool payload
    mov [rbp - 64], rax # store tag L1
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
.globl target_is_arm64
.hidden target_is_arm64
    .p2align 4
target_is_arm64:
    .loc 1 42 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 16 # prologue: alloc spill frame
.Lb05c_target_is_arm64_bb0:
    mov r10, 0 # __hx_target_arch: 0 = x86_64
    mov rbx, r10 # leaf: payload → dst L0
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 56], r11 # store tag L0
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 56] # tag L0 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r12, rdx # binop ==: capture bool payload
    mov [rbp - 64], rax # store tag L1
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
.globl _sc0
.hidden _sc0
    .p2align 4
_sc0:
    .loc 1 51 0
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
.Lb05c__sc0_bb0:
    mov rax, rbx # hv payload
    syscall # __hx_syscall0: Linux syscall
    mov r10, rax # __hx_syscall0: r10 = result
    mov r12, r10 # leaf: payload → dst L1
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 64], r11 # store tag L1
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
.globl _sc1
.hidden _sc1
    .p2align 4
_sc1:
    .loc 1 52 0
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
    mov [rbp - 64], rdx # store tag L1
    mov r12, rcx # ingress param payload
.Lb05c__sc1_bb0:
    mov rdi, r12 # hv payload
    mov rsi, 0 # hv payload
    mov rdx, 0 # hv payload
    mov r10, 0 # hv payload
    mov r8, 0 # hv payload
    mov r9, 0 # hv payload
    mov rax, rbx # hv payload
    syscall # __hx_syscall6: Linux syscall
    mov r11, rax # __hx_syscall6: r11 = result
    mov r13, r11 # leaf: payload → dst L2
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 72], r11 # store tag L2
    mov rdx, r13 # hv arg payload
    mov rax, [rbp - 72] # tag L2 from tag-slot
    add rsp, 32 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl _sc2
.hidden _sc2
    .p2align 4
_sc2:
    .loc 1 53 0
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
    mov [rbp - 64], rdx # store tag L1
    mov r12, rcx # ingress param payload
    mov [rbp - 72], r8 # store tag L2
    mov r13, r9 # ingress param payload
.Lb05c__sc2_bb0:
    mov rdi, r12 # hv payload
    mov rsi, r13 # hv payload
    mov rdx, 0 # hv payload
    mov r10, 0 # hv payload
    mov r8, 0 # hv payload
    mov r9, 0 # hv payload
    mov rax, rbx # hv payload
    syscall # __hx_syscall6: Linux syscall
    mov r11, rax # __hx_syscall6: r11 = result
    mov r14, r11 # leaf: payload → dst L3
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
.globl _sc3
.hidden _sc3
    .p2align 4
_sc3:
    .loc 1 54 0
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
    mov [rbp - 64], rdx # store tag L1
    mov r12, rcx # ingress param payload
    mov [rbp - 72], r8 # store tag L2
    mov r13, r9 # ingress param payload
    mov r10, [rbp + 16] # ingress stack param 3 tag
    mov [rbp - 80], r10 # store tag L3
    mov r10, [rbp + 24] # ingress stack param 3 payload
    mov r14, r10 # ingress stack param payload
.Lb05c__sc3_bb0:
    mov rdi, r12 # hv payload
    mov rsi, r13 # hv payload
    mov rdx, r14 # hv payload
    mov r10, 0 # hv payload
    mov r8, 0 # hv payload
    mov r9, 0 # hv payload
    mov rax, rbx # hv payload
    syscall # __hx_syscall6: Linux syscall
    mov r11, rax # __hx_syscall6: r11 = result
    mov r15, r11 # leaf: payload → dst L4
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 88], r11 # store tag L4
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
.globl _sc4
.hidden _sc4
    .p2align 4
_sc4:
    .loc 1 55 0
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
    mov [rbp - 72], rdx # store tag L1
    mov r12, rcx # ingress param payload
    mov [rbp - 80], r8 # store tag L2
    mov r13, r9 # ingress param payload
    mov r10, [rbp + 16] # ingress stack param 3 tag
    mov [rbp - 88], r10 # store tag L3
    mov r10, [rbp + 24] # ingress stack param 3 payload
    mov r14, r10 # ingress stack param payload
    mov r10, [rbp + 32] # ingress stack param 4 tag
    mov [rbp - 96], r10 # store tag L4
    mov r10, [rbp + 40] # ingress stack param 4 payload
    mov r15, r10 # ingress stack param payload
.Lb05c__sc4_bb0:
    mov rdi, r12 # hv payload
    mov rsi, r13 # hv payload
    mov rdx, r14 # hv payload
    mov r10, r15 # hv payload
    mov r8, 0 # hv payload
    mov r9, 0 # hv payload
    mov rax, rbx # hv payload
    syscall # __hx_syscall6: Linux syscall
    mov r11, rax # __hx_syscall6: r11 = result
    mov r10, r11 # leaf: payload → dst L5
    mov r11, 0 # materialize tag imm 0
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
.globl _sc6
.hidden _sc6
    .p2align 4
_sc6:
    .loc 1 56 0
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
    mov [rbp - 88], rdx # store tag L1
    mov r12, rcx # ingress param payload
    mov [rbp - 96], r8 # store tag L2
    mov r13, r9 # ingress param payload
    mov r10, [rbp + 16] # ingress stack param 3 tag
    mov [rbp - 104], r10 # store tag L3
    mov r10, [rbp + 24] # ingress stack param 3 payload
    mov r14, r10 # ingress stack param payload
    mov r10, [rbp + 32] # ingress stack param 4 tag
    mov [rbp - 112], r10 # store tag L4
    mov r10, [rbp + 40] # ingress stack param 4 payload
    mov r15, r10 # ingress stack param payload
    mov r10, [rbp + 48] # ingress stack param 5 tag
    mov [rbp - 120], r10 # store tag L5
    mov r10, [rbp + 56] # ingress stack param 5 payload
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp + 64] # ingress stack param 6 tag
    mov [rbp - 128], r10 # store tag L6
    mov r10, [rbp + 72] # ingress stack param 6 payload
    mov [rbp - 64], r10 # spill L6 to slot
.Lb05c__sc6_bb0:
    mov rdi, r12 # hv payload
    mov rsi, r13 # hv payload
    mov rdx, r14 # hv payload
    mov r10, r15 # hv payload
    mov r8, [rbp - 56] # reload L5 from spill slot
    mov r8, r8 # hv payload
    mov r9, [rbp - 64] # reload L6 from spill slot
    mov r9, r9 # hv payload
    mov rax, rbx # hv payload
    syscall # __hx_syscall6: Linux syscall
    mov r11, rax # __hx_syscall6: r11 = result
    mov r10, r11 # leaf: payload → dst L7
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 136], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov rdx, [rbp - 72] # reload L7 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 136] # tag L7 from tag-slot
    add rsp, 96 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_READ
.hidden SYS_LINUX_READ
    .p2align 4
SYS_LINUX_READ:
    .loc 1 62 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_READ_bb0:
    mov rdx, 0 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_WRITE
.hidden SYS_LINUX_WRITE
    .p2align 4
SYS_LINUX_WRITE:
    .loc 1 63 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_WRITE_bb0:
    mov rdx, 1 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_OPEN
.hidden SYS_LINUX_OPEN
    .p2align 4
SYS_LINUX_OPEN:
    .loc 1 64 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_OPEN_bb0:
    mov rdx, 2 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_CLOSE
.hidden SYS_LINUX_CLOSE
    .p2align 4
SYS_LINUX_CLOSE:
    .loc 1 65 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_CLOSE_bb0:
    mov rdx, 3 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_STAT
.hidden SYS_LINUX_STAT
    .p2align 4
SYS_LINUX_STAT:
    .loc 1 66 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_STAT_bb0:
    mov rdx, 4 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_FSTAT
.hidden SYS_LINUX_FSTAT
    .p2align 4
SYS_LINUX_FSTAT:
    .loc 1 67 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_FSTAT_bb0:
    mov rdx, 5 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_LSEEK
.hidden SYS_LINUX_LSEEK
    .p2align 4
SYS_LINUX_LSEEK:
    .loc 1 68 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_LSEEK_bb0:
    mov rdx, 8 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_MMAP
.hidden SYS_LINUX_MMAP
    .p2align 4
SYS_LINUX_MMAP:
    .loc 1 69 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_MMAP_bb0:
    mov rdx, 9 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_MUNMAP
.hidden SYS_LINUX_MUNMAP
    .p2align 4
SYS_LINUX_MUNMAP:
    .loc 1 70 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_MUNMAP_bb0:
    mov rdx, 11 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_BRK
.hidden SYS_LINUX_BRK
    .p2align 4
SYS_LINUX_BRK:
    .loc 1 71 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_BRK_bb0:
    mov rdx, 12 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_IOCTL
.hidden SYS_LINUX_IOCTL
    .p2align 4
SYS_LINUX_IOCTL:
    .loc 1 72 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_IOCTL_bb0:
    mov rdx, 16 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_PIPE
.hidden SYS_LINUX_PIPE
    .p2align 4
SYS_LINUX_PIPE:
    .loc 1 73 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_PIPE_bb0:
    mov rdx, 22 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_NANOSLEEP
.hidden SYS_LINUX_NANOSLEEP
    .p2align 4
SYS_LINUX_NANOSLEEP:
    .loc 1 74 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_NANOSLEEP_bb0:
    mov rdx, 35 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_FORK
.hidden SYS_LINUX_FORK
    .p2align 4
SYS_LINUX_FORK:
    .loc 1 75 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_FORK_bb0:
    mov rdx, 57 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_EXECVE
.hidden SYS_LINUX_EXECVE
    .p2align 4
SYS_LINUX_EXECVE:
    .loc 1 76 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_EXECVE_bb0:
    mov rdx, 59 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_WAIT4
.hidden SYS_LINUX_WAIT4
    .p2align 4
SYS_LINUX_WAIT4:
    .loc 1 77 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_WAIT4_bb0:
    mov rdx, 61 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_DUP2
.hidden SYS_LINUX_DUP2
    .p2align 4
SYS_LINUX_DUP2:
    .loc 1 78 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_DUP2_bb0:
    mov rdx, 33 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_GETDENTS64
.hidden SYS_LINUX_GETDENTS64
    .p2align 4
SYS_LINUX_GETDENTS64:
    .loc 1 79 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_GETDENTS64_bb0:
    mov rdx, 217 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_CLOCK_GETTIME
.hidden SYS_LINUX_CLOCK_GETTIME
    .p2align 4
SYS_LINUX_CLOCK_GETTIME:
    .loc 1 80 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_CLOCK_GETTIME_bb0:
    mov rdx, 228 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_EXIT_GROUP
.hidden SYS_LINUX_EXIT_GROUP
    .p2align 4
SYS_LINUX_EXIT_GROUP:
    .loc 1 81 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_EXIT_GROUP_bb0:
    mov rdx, 231 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_UNLINKAT
.hidden SYS_LINUX_UNLINKAT
    .p2align 4
SYS_LINUX_UNLINKAT:
    .loc 1 82 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_UNLINKAT_bb0:
    mov rdx, 263 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_MKDIRAT
.hidden SYS_LINUX_MKDIRAT
    .p2align 4
SYS_LINUX_MKDIRAT:
    .loc 1 83 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_MKDIRAT_bb0:
    mov rdx, 258 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_GETRANDOM
.hidden SYS_LINUX_GETRANDOM
    .p2align 4
SYS_LINUX_GETRANDOM:
    .loc 1 84 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_GETRANDOM_bb0:
    mov rdx, 318 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_ARM64_MMAP
.hidden SYS_LINUX_ARM64_MMAP
    .p2align 4
SYS_LINUX_ARM64_MMAP:
    .loc 1 95 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_ARM64_MMAP_bb0:
    mov rdx, 222 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_ARM64_MUNMAP
.hidden SYS_LINUX_ARM64_MUNMAP
    .p2align 4
SYS_LINUX_ARM64_MUNMAP:
    .loc 1 96 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_ARM64_MUNMAP_bb0:
    mov rdx, 215 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_LINUX_ARM64_EXIT_GROUP
.hidden SYS_LINUX_ARM64_EXIT_GROUP
    .p2align 4
SYS_LINUX_ARM64_EXIT_GROUP:
    .loc 1 97 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_LINUX_ARM64_EXIT_GROUP_bb0:
    mov rdx, 94 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_DARWIN_EXIT
.hidden SYS_DARWIN_EXIT
    .p2align 4
SYS_DARWIN_EXIT:
    .loc 1 103 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_DARWIN_EXIT_bb0:
    mov rdx, 33554433 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_DARWIN_FORK
.hidden SYS_DARWIN_FORK
    .p2align 4
SYS_DARWIN_FORK:
    .loc 1 104 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_DARWIN_FORK_bb0:
    mov rdx, 33554434 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_DARWIN_READ
.hidden SYS_DARWIN_READ
    .p2align 4
SYS_DARWIN_READ:
    .loc 1 105 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_DARWIN_READ_bb0:
    mov rdx, 33554435 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_DARWIN_WRITE
.hidden SYS_DARWIN_WRITE
    .p2align 4
SYS_DARWIN_WRITE:
    .loc 1 106 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_DARWIN_WRITE_bb0:
    mov rdx, 33554436 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_DARWIN_OPEN
.hidden SYS_DARWIN_OPEN
    .p2align 4
SYS_DARWIN_OPEN:
    .loc 1 107 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_DARWIN_OPEN_bb0:
    mov rdx, 33554437 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_DARWIN_CLOSE
.hidden SYS_DARWIN_CLOSE
    .p2align 4
SYS_DARWIN_CLOSE:
    .loc 1 108 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_DARWIN_CLOSE_bb0:
    mov rdx, 33554438 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_DARWIN_WAIT4
.hidden SYS_DARWIN_WAIT4
    .p2align 4
SYS_DARWIN_WAIT4:
    .loc 1 109 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_DARWIN_WAIT4_bb0:
    mov rdx, 33554439 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_DARWIN_UNLINK
.hidden SYS_DARWIN_UNLINK
    .p2align 4
SYS_DARWIN_UNLINK:
    .loc 1 110 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_DARWIN_UNLINK_bb0:
    mov rdx, 33554442 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_DARWIN_LSEEK
.hidden SYS_DARWIN_LSEEK
    .p2align 4
SYS_DARWIN_LSEEK:
    .loc 1 111 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_DARWIN_LSEEK_bb0:
    mov rdx, 33554631 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_DARWIN_EXECVE
.hidden SYS_DARWIN_EXECVE
    .p2align 4
SYS_DARWIN_EXECVE:
    .loc 1 112 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_DARWIN_EXECVE_bb0:
    mov rdx, 33554491 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_DARWIN_MUNMAP
.hidden SYS_DARWIN_MUNMAP
    .p2align 4
SYS_DARWIN_MUNMAP:
    .loc 1 113 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_DARWIN_MUNMAP_bb0:
    mov rdx, 33554505 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_DARWIN_MMAP
.hidden SYS_DARWIN_MMAP
    .p2align 4
SYS_DARWIN_MMAP:
    .loc 1 114 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_DARWIN_MMAP_bb0:
    mov rdx, 33554629 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_DARWIN_FSTAT64
.hidden SYS_DARWIN_FSTAT64
    .p2align 4
SYS_DARWIN_FSTAT64:
    .loc 1 115 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_DARWIN_FSTAT64_bb0:
    mov rdx, 33554621 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_DARWIN_GETDIRENTRIES
.hidden SYS_DARWIN_GETDIRENTRIES
    .p2align 4
SYS_DARWIN_GETDIRENTRIES:
    .loc 1 116 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_DARWIN_GETDIRENTRIES_bb0:
    mov rdx, 33554772 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_DARWIN_GETDIRENTRIES64
.hidden SYS_DARWIN_GETDIRENTRIES64
    .p2align 4
SYS_DARWIN_GETDIRENTRIES64:
    .loc 1 117 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_DARWIN_GETDIRENTRIES64_bb0:
    mov rdx, 33554776 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_DARWIN_MKDIR
.hidden SYS_DARWIN_MKDIR
    .p2align 4
SYS_DARWIN_MKDIR:
    .loc 1 118 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_DARWIN_MKDIR_bb0:
    mov rdx, 33554568 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_DARWIN_NANOSLEEP
.hidden SYS_DARWIN_NANOSLEEP
    .p2align 4
SYS_DARWIN_NANOSLEEP:
    .loc 1 119 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_DARWIN_NANOSLEEP_bb0:
    mov rdx, 33554629 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl SYS_DARWIN_CLOCK_GETTIME
.hidden SYS_DARWIN_CLOCK_GETTIME
    .p2align 4
SYS_DARWIN_CLOCK_GETTIME:
    .loc 1 120 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_SYS_DARWIN_CLOCK_GETTIME_bb0:
    mov rdx, 33558008 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl sys_read
.hidden sys_read
    .p2align 4
sys_read:
    .loc 1 126 0
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
    mov [rbp - 104], r8 # store tag L2
    mov r13, r9 # ingress param payload
.Lb05c_sys_read_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 112], rax # store tag L3
    mov r14, rdx # hv: unbox user-call result payload
    test r14, r14 # br_cond test
    jz .Lb05c_sys_read_bb2 # jump-if-zero -> else
    jmp .Lb05c_sys_read_bb1 # jump -> then
.Lb05c_sys_read_bb1:
    call SYS_LINUX_READ # call SYS_LINUX_READ
    mov [rbp - 128], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    sub rsp, 16 # hv: reserve 1 16B stack arg slots
    mov r11, r13 # hv arg payload
    mov r10, [rbp - 104] # tag L2 from tag-slot
    mov [rsp], r10 # hv stack arg 3 tag
    mov [rsp + 8], r11 # hv stack arg 3 payload
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 128] # tag L5 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 88] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 96] # tag L1 from tag-slot
    call _sc3 # call _sc3
    add rsp, 16 # hv: pop 1 stack arg slots
    mov [rbp - 136], rax # store tag L6
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 64], r10 # spill L6 to slot
    mov rdx, [rbp - 64] # reload L6 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 136] # tag L6 from tag-slot
    add rsp, 112 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_sys_read_bb2:
    call SYS_DARWIN_READ # call SYS_DARWIN_READ
    mov [rbp - 144], rax # store tag L7
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 72], r10 # spill L7 to slot
    sub rsp, 16 # hv: reserve 1 16B stack arg slots
    mov r11, r13 # hv arg payload
    mov r10, [rbp - 104] # tag L2 from tag-slot
    mov [rsp], r10 # hv stack arg 3 tag
    mov [rsp + 8], r11 # hv stack arg 3 payload
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 144] # tag L7 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 88] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 96] # tag L1 from tag-slot
    call _sc3 # call _sc3
    add rsp, 16 # hv: pop 1 stack arg slots
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
.globl sys_write
.hidden sys_write
    .p2align 4
sys_write:
    .loc 1 131 0
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
    mov [rbp - 104], r8 # store tag L2
    mov r13, r9 # ingress param payload
.Lb05c_sys_write_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 112], rax # store tag L3
    mov r14, rdx # hv: unbox user-call result payload
    test r14, r14 # br_cond test
    jz .Lb05c_sys_write_bb2 # jump-if-zero -> else
    jmp .Lb05c_sys_write_bb1 # jump -> then
.Lb05c_sys_write_bb1:
    call SYS_LINUX_WRITE # call SYS_LINUX_WRITE
    mov [rbp - 128], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    sub rsp, 16 # hv: reserve 1 16B stack arg slots
    mov r11, r13 # hv arg payload
    mov r10, [rbp - 104] # tag L2 from tag-slot
    mov [rsp], r10 # hv stack arg 3 tag
    mov [rsp + 8], r11 # hv stack arg 3 payload
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 128] # tag L5 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 88] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 96] # tag L1 from tag-slot
    call _sc3 # call _sc3
    add rsp, 16 # hv: pop 1 stack arg slots
    mov [rbp - 136], rax # store tag L6
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 64], r10 # spill L6 to slot
    mov rdx, [rbp - 64] # reload L6 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 136] # tag L6 from tag-slot
    add rsp, 112 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_sys_write_bb2:
    call SYS_DARWIN_WRITE # call SYS_DARWIN_WRITE
    mov [rbp - 144], rax # store tag L7
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 72], r10 # spill L7 to slot
    sub rsp, 16 # hv: reserve 1 16B stack arg slots
    mov r11, r13 # hv arg payload
    mov r10, [rbp - 104] # tag L2 from tag-slot
    mov [rsp], r10 # hv stack arg 3 tag
    mov [rsp + 8], r11 # hv stack arg 3 payload
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 144] # tag L7 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 88] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 96] # tag L1 from tag-slot
    call _sc3 # call _sc3
    add rsp, 16 # hv: pop 1 stack arg slots
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
.globl sys_open
.hidden sys_open
    .p2align 4
sys_open:
    .loc 1 136 0
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
    mov [rbp - 104], r8 # store tag L2
    mov r13, r9 # ingress param payload
.Lb05c_sys_open_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 112], rax # store tag L3
    mov r14, rdx # hv: unbox user-call result payload
    test r14, r14 # br_cond test
    jz .Lb05c_sys_open_bb2 # jump-if-zero -> else
    jmp .Lb05c_sys_open_bb1 # jump -> then
.Lb05c_sys_open_bb1:
    call SYS_LINUX_OPEN # call SYS_LINUX_OPEN
    mov [rbp - 128], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    sub rsp, 16 # hv: reserve 1 16B stack arg slots
    mov r11, r13 # hv arg payload
    mov r10, [rbp - 104] # tag L2 from tag-slot
    mov [rsp], r10 # hv stack arg 3 tag
    mov [rsp + 8], r11 # hv stack arg 3 payload
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 128] # tag L5 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 88] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 96] # tag L1 from tag-slot
    call _sc3 # call _sc3
    add rsp, 16 # hv: pop 1 stack arg slots
    mov [rbp - 136], rax # store tag L6
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 64], r10 # spill L6 to slot
    mov rdx, [rbp - 64] # reload L6 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 136] # tag L6 from tag-slot
    add rsp, 112 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_sys_open_bb2:
    call SYS_DARWIN_OPEN # call SYS_DARWIN_OPEN
    mov [rbp - 144], rax # store tag L7
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 72], r10 # spill L7 to slot
    sub rsp, 16 # hv: reserve 1 16B stack arg slots
    mov r11, r13 # hv arg payload
    mov r10, [rbp - 104] # tag L2 from tag-slot
    mov [rsp], r10 # hv stack arg 3 tag
    mov [rsp + 8], r11 # hv stack arg 3 payload
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 144] # tag L7 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 88] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 96] # tag L1 from tag-slot
    call _sc3 # call _sc3
    add rsp, 16 # hv: pop 1 stack arg slots
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
.globl sys_close
.hidden sys_close
    .p2align 4
sys_close:
    .loc 1 141 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 80 # prologue: alloc spill frame
    mov [rbp - 72], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.Lb05c_sys_close_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 80], rax # store tag L1
    mov r12, rdx # hv: unbox user-call result payload
    test r12, r12 # br_cond test
    jz .Lb05c_sys_close_bb2 # jump-if-zero -> else
    jmp .Lb05c_sys_close_bb1 # jump -> then
.Lb05c_sys_close_bb1:
    call SYS_LINUX_CLOSE # call SYS_LINUX_CLOSE
    mov [rbp - 96], rax # store tag L3
    mov r14, rdx # hv: unbox user-call result payload
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 96] # tag L3 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 72] # tag L0 from tag-slot
    call _sc1 # call _sc1
    mov [rbp - 104], rax # store tag L4
    mov r15, rdx # hv: unbox user-call result payload
    mov rdx, r15 # hv arg payload
    mov rax, [rbp - 104] # tag L4 from tag-slot
    add rsp, 80 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_sys_close_bb2:
    call SYS_DARWIN_CLOSE # call SYS_DARWIN_CLOSE
    mov [rbp - 112], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 112] # tag L5 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 72] # tag L0 from tag-slot
    call _sc1 # call _sc1
    mov [rbp - 120], rax # store tag L6
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 64], r10 # spill L6 to slot
    mov rdx, [rbp - 64] # reload L6 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 120] # tag L6 from tag-slot
    add rsp, 80 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl sys_lseek
.hidden sys_lseek
    .p2align 4
sys_lseek:
    .loc 1 146 0
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
    mov [rbp - 104], r8 # store tag L2
    mov r13, r9 # ingress param payload
.Lb05c_sys_lseek_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 112], rax # store tag L3
    mov r14, rdx # hv: unbox user-call result payload
    test r14, r14 # br_cond test
    jz .Lb05c_sys_lseek_bb2 # jump-if-zero -> else
    jmp .Lb05c_sys_lseek_bb1 # jump -> then
.Lb05c_sys_lseek_bb1:
    call SYS_LINUX_LSEEK # call SYS_LINUX_LSEEK
    mov [rbp - 128], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    sub rsp, 16 # hv: reserve 1 16B stack arg slots
    mov r11, r13 # hv arg payload
    mov r10, [rbp - 104] # tag L2 from tag-slot
    mov [rsp], r10 # hv stack arg 3 tag
    mov [rsp + 8], r11 # hv stack arg 3 payload
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 128] # tag L5 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 88] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 96] # tag L1 from tag-slot
    call _sc3 # call _sc3
    add rsp, 16 # hv: pop 1 stack arg slots
    mov [rbp - 136], rax # store tag L6
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 64], r10 # spill L6 to slot
    mov rdx, [rbp - 64] # reload L6 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 136] # tag L6 from tag-slot
    add rsp, 112 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_sys_lseek_bb2:
    call SYS_DARWIN_LSEEK # call SYS_DARWIN_LSEEK
    mov [rbp - 144], rax # store tag L7
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 72], r10 # spill L7 to slot
    sub rsp, 16 # hv: reserve 1 16B stack arg slots
    mov r11, r13 # hv arg payload
    mov r10, [rbp - 104] # tag L2 from tag-slot
    mov [rsp], r10 # hv stack arg 3 tag
    mov [rsp + 8], r11 # hv stack arg 3 payload
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 144] # tag L7 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 88] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 96] # tag L1 from tag-slot
    call _sc3 # call _sc3
    add rsp, 16 # hv: pop 1 stack arg slots
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
.globl sys_unlink
.hidden sys_unlink
    .p2align 4
sys_unlink:
    .loc 1 151 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 80 # prologue: alloc spill frame
    mov [rbp - 72], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.Lb05c_sys_unlink_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 80], rax # store tag L1
    mov r12, rdx # hv: unbox user-call result payload
    test r12, r12 # br_cond test
    jz .Lb05c_sys_unlink_bb2 # jump-if-zero -> else
    jmp .Lb05c_sys_unlink_bb1 # jump -> then
.Lb05c_sys_unlink_bb1:
    call SYS_LINUX_UNLINKAT # call SYS_LINUX_UNLINKAT
    mov [rbp - 96], rax # store tag L3
    mov r14, rdx # hv: unbox user-call result payload
    sub rsp, 16 # hv: reserve 1 16B stack arg slots
    mov r11, 0 # hv arg payload
    mov r10, 0 # tag default = TAG_INT
    mov [rsp], r10 # hv stack arg 3 tag
    mov [rsp + 8], r11 # hv stack arg 3 payload
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 96] # tag L3 from tag-slot
    mov rcx, -100 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    mov r9, rbx # hv arg payload
    mov r8, [rbp - 72] # tag L0 from tag-slot
    call _sc3 # call _sc3
    add rsp, 16 # hv: pop 1 stack arg slots
    mov [rbp - 104], rax # store tag L4
    mov r15, rdx # hv: unbox user-call result payload
    mov rdx, r15 # hv arg payload
    mov rax, [rbp - 104] # tag L4 from tag-slot
    add rsp, 80 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_sys_unlink_bb2:
    call SYS_DARWIN_UNLINK # call SYS_DARWIN_UNLINK
    mov [rbp - 112], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 112] # tag L5 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 72] # tag L0 from tag-slot
    call _sc1 # call _sc1
    mov [rbp - 120], rax # store tag L6
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 64], r10 # spill L6 to slot
    mov rdx, [rbp - 64] # reload L6 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 120] # tag L6 from tag-slot
    add rsp, 80 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl sys_mkdir
.hidden sys_mkdir
    .p2align 4
sys_mkdir:
    .loc 1 159 0
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
    mov [rbp - 88], rdx # store tag L1
    mov r12, rcx # ingress param payload
.Lb05c_sys_mkdir_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 96], rax # store tag L2
    mov r13, rdx # hv: unbox user-call result payload
    test r13, r13 # br_cond test
    jz .Lb05c_sys_mkdir_bb2 # jump-if-zero -> else
    jmp .Lb05c_sys_mkdir_bb1 # jump -> then
.Lb05c_sys_mkdir_bb1:
    call SYS_LINUX_MKDIRAT # call SYS_LINUX_MKDIRAT
    mov [rbp - 112], rax # store tag L4
    mov r15, rdx # hv: unbox user-call result payload
    sub rsp, 16 # hv: reserve 1 16B stack arg slots
    mov r11, r12 # hv arg payload
    mov r10, [rbp - 88] # tag L1 from tag-slot
    mov [rsp], r10 # hv stack arg 3 tag
    mov [rsp + 8], r11 # hv stack arg 3 payload
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 112] # tag L4 from tag-slot
    mov rcx, -100 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    mov r9, rbx # hv arg payload
    mov r8, [rbp - 80] # tag L0 from tag-slot
    call _sc3 # call _sc3
    add rsp, 16 # hv: pop 1 stack arg slots
    mov [rbp - 120], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    mov rdx, [rbp - 56] # reload L5 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 120] # tag L5 from tag-slot
    add rsp, 96 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_sys_mkdir_bb2:
    call SYS_DARWIN_MKDIR # call SYS_DARWIN_MKDIR
    mov [rbp - 128], rax # store tag L6
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 64], r10 # spill L6 to slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 128] # tag L6 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 80] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 88] # tag L1 from tag-slot
    call _sc2 # call _sc2
    mov [rbp - 136], rax # store tag L7
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 72], r10 # spill L7 to slot
    mov rdx, [rbp - 72] # reload L7 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 136] # tag L7 from tag-slot
    add rsp, 96 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl sys_mmap
.hidden sys_mmap
    .p2align 4
sys_mmap:
    .loc 1 167 0
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
    mov r10, [rbp + 16] # ingress stack param 3 tag
    mov [rbp - 168], r10 # store tag L3
    mov r10, [rbp + 24] # ingress stack param 3 payload
    mov r14, r10 # ingress stack param payload
    mov r10, [rbp + 32] # ingress stack param 4 tag
    mov [rbp - 176], r10 # store tag L4
    mov r10, [rbp + 40] # ingress stack param 4 payload
    mov r15, r10 # ingress stack param payload
    mov r10, [rbp + 48] # ingress stack param 5 tag
    mov [rbp - 184], r10 # store tag L5
    mov r10, [rbp + 56] # ingress stack param 5 payload
    mov [rbp - 56], r10 # spill L5 to slot
.Lb05c_sys_mmap_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 192], rax # store tag L6
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    test r10, r10 # br_cond test
    jz .Lb05c_sys_mmap_bb2 # jump-if-zero -> else
    jmp .Lb05c_sys_mmap_bb1 # jump -> then
.Lb05c_sys_mmap_bb1:
    call target_is_arm64 # call target_is_arm64
    mov [rbp - 208], rax # store tag L8
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    test r10, r10 # br_cond test
    jz .Lb05c_sys_mmap_bb4 # jump-if-zero -> else
    jmp .Lb05c_sys_mmap_bb3 # jump -> then
.Lb05c_sys_mmap_bb2:
    call SYS_DARWIN_MMAP # call SYS_DARWIN_MMAP
    mov [rbp - 256], rax # store tag L14
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 128], r10 # spill L14 to slot
    sub rsp, 64 # hv: reserve 4 16B stack arg slots
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r11, r11 # hv arg payload
    mov r10, [rbp - 184] # tag L5 from tag-slot
    mov [rsp + 48], r10 # hv stack arg 6 tag
    mov [rsp + 56], r11 # hv stack arg 6 payload
    mov r11, r15 # hv arg payload
    mov r10, [rbp - 176] # tag L4 from tag-slot
    mov [rsp + 32], r10 # hv stack arg 5 tag
    mov [rsp + 40], r11 # hv stack arg 5 payload
    mov r11, r14 # hv arg payload
    mov r10, [rbp - 168] # tag L3 from tag-slot
    mov [rsp + 16], r10 # hv stack arg 4 tag
    mov [rsp + 24], r11 # hv stack arg 4 payload
    mov r11, r13 # hv arg payload
    mov r10, [rbp - 160] # tag L2 from tag-slot
    mov [rsp], r10 # hv stack arg 3 tag
    mov [rsp + 8], r11 # hv stack arg 3 payload
    mov rsi, [rbp - 128] # reload L14 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 256] # tag L14 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 144] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 152] # tag L1 from tag-slot
    call _sc6 # call _sc6
    add rsp, 64 # hv: pop 4 stack arg slots
    mov [rbp - 264], rax # store tag L15
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 136], r10 # spill L15 to slot
    mov rdx, [rbp - 136] # reload L15 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 264] # tag L15 from tag-slot
    add rsp, 224 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_sys_mmap_bb3:
    call SYS_LINUX_ARM64_MMAP # call SYS_LINUX_ARM64_MMAP
    mov [rbp - 224], rax # store tag L10
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 96], r10 # spill L10 to slot
    sub rsp, 64 # hv: reserve 4 16B stack arg slots
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r11, r11 # hv arg payload
    mov r10, [rbp - 184] # tag L5 from tag-slot
    mov [rsp + 48], r10 # hv stack arg 6 tag
    mov [rsp + 56], r11 # hv stack arg 6 payload
    mov r11, r15 # hv arg payload
    mov r10, [rbp - 176] # tag L4 from tag-slot
    mov [rsp + 32], r10 # hv stack arg 5 tag
    mov [rsp + 40], r11 # hv stack arg 5 payload
    mov r11, r14 # hv arg payload
    mov r10, [rbp - 168] # tag L3 from tag-slot
    mov [rsp + 16], r10 # hv stack arg 4 tag
    mov [rsp + 24], r11 # hv stack arg 4 payload
    mov r11, r13 # hv arg payload
    mov r10, [rbp - 160] # tag L2 from tag-slot
    mov [rsp], r10 # hv stack arg 3 tag
    mov [rsp + 8], r11 # hv stack arg 3 payload
    mov rsi, [rbp - 96] # reload L10 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 224] # tag L10 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 144] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 152] # tag L1 from tag-slot
    call _sc6 # call _sc6
    add rsp, 64 # hv: pop 4 stack arg slots
    mov [rbp - 232], rax # store tag L11
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 104], r10 # spill L11 to slot
    mov rdx, [rbp - 104] # reload L11 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 232] # tag L11 from tag-slot
    add rsp, 224 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_sys_mmap_bb4:
    call SYS_LINUX_MMAP # call SYS_LINUX_MMAP
    mov [rbp - 240], rax # store tag L12
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 112], r10 # spill L12 to slot
    sub rsp, 64 # hv: reserve 4 16B stack arg slots
    mov r11, [rbp - 56] # reload L5 from spill slot
    mov r11, r11 # hv arg payload
    mov r10, [rbp - 184] # tag L5 from tag-slot
    mov [rsp + 48], r10 # hv stack arg 6 tag
    mov [rsp + 56], r11 # hv stack arg 6 payload
    mov r11, r15 # hv arg payload
    mov r10, [rbp - 176] # tag L4 from tag-slot
    mov [rsp + 32], r10 # hv stack arg 5 tag
    mov [rsp + 40], r11 # hv stack arg 5 payload
    mov r11, r14 # hv arg payload
    mov r10, [rbp - 168] # tag L3 from tag-slot
    mov [rsp + 16], r10 # hv stack arg 4 tag
    mov [rsp + 24], r11 # hv stack arg 4 payload
    mov r11, r13 # hv arg payload
    mov r10, [rbp - 160] # tag L2 from tag-slot
    mov [rsp], r10 # hv stack arg 3 tag
    mov [rsp + 8], r11 # hv stack arg 3 payload
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 240] # tag L12 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 144] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 152] # tag L1 from tag-slot
    call _sc6 # call _sc6
    add rsp, 64 # hv: pop 4 stack arg slots
    mov [rbp - 248], rax # store tag L13
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 120], r10 # spill L13 to slot
    mov rdx, [rbp - 120] # reload L13 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 248] # tag L13 from tag-slot
    add rsp, 224 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl sys_munmap
.hidden sys_munmap
    .p2align 4
sys_munmap:
    .loc 1 175 0
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
.Lb05c_sys_munmap_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 128], rax # store tag L2
    mov r13, rdx # hv: unbox user-call result payload
    test r13, r13 # br_cond test
    jz .Lb05c_sys_munmap_bb2 # jump-if-zero -> else
    jmp .Lb05c_sys_munmap_bb1 # jump -> then
.Lb05c_sys_munmap_bb1:
    call target_is_arm64 # call target_is_arm64
    mov [rbp - 144], rax # store tag L4
    mov r15, rdx # hv: unbox user-call result payload
    test r15, r15 # br_cond test
    jz .Lb05c_sys_munmap_bb4 # jump-if-zero -> else
    jmp .Lb05c_sys_munmap_bb3 # jump -> then
.Lb05c_sys_munmap_bb2:
    call SYS_DARWIN_MUNMAP # call SYS_DARWIN_MUNMAP
    mov [rbp - 192], rax # store tag L10
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 96], r10 # spill L10 to slot
    mov rsi, [rbp - 96] # reload L10 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 192] # tag L10 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 112] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 120] # tag L1 from tag-slot
    call _sc2 # call _sc2
    mov [rbp - 200], rax # store tag L11
    mov r10, rdx # hv: unbox user-call result payload
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
.Lb05c_sys_munmap_bb3:
    call SYS_LINUX_ARM64_MUNMAP # call SYS_LINUX_ARM64_MUNMAP
    mov [rbp - 160], rax # store tag L6
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 64], r10 # spill L6 to slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 160] # tag L6 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 112] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 120] # tag L1 from tag-slot
    call _sc2 # call _sc2
    mov [rbp - 168], rax # store tag L7
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 72], r10 # spill L7 to slot
    mov rdx, [rbp - 72] # reload L7 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 168] # tag L7 from tag-slot
    add rsp, 160 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_sys_munmap_bb4:
    call SYS_LINUX_MUNMAP # call SYS_LINUX_MUNMAP
    mov [rbp - 176], rax # store tag L8
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 80], r10 # spill L8 to slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 176] # tag L8 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 112] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 120] # tag L1 from tag-slot
    call _sc2 # call _sc2
    mov [rbp - 184], rax # store tag L9
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 88], r10 # spill L9 to slot
    mov rdx, [rbp - 88] # reload L9 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 184] # tag L9 from tag-slot
    add rsp, 160 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl sys_exit
.hidden sys_exit
    .p2align 4
sys_exit:
    .loc 1 183 0
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
.Lb05c_sys_exit_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 112], rax # store tag L1
    mov r12, rdx # hv: unbox user-call result payload
    test r12, r12 # br_cond test
    jz .Lb05c_sys_exit_bb2 # jump-if-zero -> else
    jmp .Lb05c_sys_exit_bb1 # jump -> then
.Lb05c_sys_exit_bb1:
    call target_is_arm64 # call target_is_arm64
    mov [rbp - 128], rax # store tag L3
    mov r14, rdx # hv: unbox user-call result payload
    test r14, r14 # br_cond test
    jz .Lb05c_sys_exit_bb4 # jump-if-zero -> else
    jmp .Lb05c_sys_exit_bb3 # jump -> then
.Lb05c_sys_exit_bb2:
    call SYS_DARWIN_EXIT # call SYS_DARWIN_EXIT
    mov [rbp - 176], rax # store tag L9
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 88], r10 # spill L9 to slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 176] # tag L9 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 104] # tag L0 from tag-slot
    call _sc1 # call _sc1
    mov [rbp - 184], rax # store tag L10
    mov r10, rdx # hv: unbox user-call result payload
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
.Lb05c_sys_exit_bb3:
    call SYS_LINUX_ARM64_EXIT_GROUP # call SYS_LINUX_ARM64_EXIT_GROUP
    mov [rbp - 144], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 144] # tag L5 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 104] # tag L0 from tag-slot
    call _sc1 # call _sc1
    mov [rbp - 152], rax # store tag L6
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 64], r10 # spill L6 to slot
    mov rdx, [rbp - 64] # reload L6 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 152] # tag L6 from tag-slot
    add rsp, 144 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_sys_exit_bb4:
    call SYS_LINUX_EXIT_GROUP # call SYS_LINUX_EXIT_GROUP
    mov [rbp - 160], rax # store tag L7
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 72], r10 # spill L7 to slot
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 160] # tag L7 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 104] # tag L0 from tag-slot
    call _sc1 # call _sc1
    mov [rbp - 168], rax # store tag L8
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 80], r10 # spill L8 to slot
    mov rdx, [rbp - 80] # reload L8 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 168] # tag L8 from tag-slot
    add rsp, 144 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl sys_getrandom
.hidden sys_getrandom
    .p2align 4
sys_getrandom:
    .loc 1 191 0
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
    mov [rbp - 152], r8 # store tag L2
    mov r13, r9 # ingress param payload
.Lb05c_sys_getrandom_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 160], rax # store tag L3
    mov r14, rdx # hv: unbox user-call result payload
    test r14, r14 # br_cond test
    jz .Lb05c_sys_getrandom_bb2 # jump-if-zero -> else
    jmp .Lb05c_sys_getrandom_bb1 # jump -> then
.Lb05c_sys_getrandom_bb1:
    call SYS_LINUX_GETRANDOM # call SYS_LINUX_GETRANDOM
    mov [rbp - 176], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    sub rsp, 16 # hv: reserve 1 16B stack arg slots
    mov r11, r13 # hv arg payload
    mov r10, [rbp - 152] # tag L2 from tag-slot
    mov [rsp], r10 # hv stack arg 3 tag
    mov [rsp + 8], r11 # hv stack arg 3 payload
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 176] # tag L5 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 136] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 144] # tag L1 from tag-slot
    call _sc3 # call _sc3
    add rsp, 16 # hv: pop 1 stack arg slots
    mov [rbp - 184], rax # store tag L6
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 64], r10 # spill L6 to slot
    mov rdx, [rbp - 64] # reload L6 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 184] # tag L6 from tag-slot
    add rsp, 208 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_sys_getrandom_bb2:
    lea r10, [rip+.LCstr0] # hv payload: &str .LCstr0
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 192], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 192] # tag L7 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    mov r9, 0 # hv arg payload
    mov r8, 0 # tag default = TAG_INT
    call sys_open # call sys_open
    mov [rbp - 200], rax # store tag L8
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 200] # tag L8 from tag-slot
    mov [rbp - 208], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 208] # tag L9 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 216], rax # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    test r10, r10 # br_cond test
    jz .Lb05c_sys_getrandom_bb4 # jump-if-zero -> else
    jmp .Lb05c_sys_getrandom_bb3 # jump -> then
.Lb05c_sys_getrandom_bb3:
    mov rdx, [rbp - 88] # reload L9 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 208] # tag L9 from tag-slot
    add rsp, 208 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_sys_getrandom_bb4:
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 208] # tag L9 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 136] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 144] # tag L1 from tag-slot
    call sys_read # call sys_read
    mov [rbp - 232], rax # store tag L12
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 232] # tag L12 from tag-slot
    mov [rbp - 240], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov rsi, [rbp - 88] # reload L9 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 208] # tag L9 from tag-slot
    call sys_close # call sys_close
    mov [rbp - 248], rax # store tag L14
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 128], r10 # spill L14 to slot
    mov rdx, [rbp - 120] # reload L13 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 240] # tag L13 from tag-slot
    add rsp, 208 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl sys_clock_gettime
.hidden sys_clock_gettime
    .p2align 4
sys_clock_gettime:
    .loc 1 201 0
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
    mov [rbp - 88], rdx # store tag L1
    mov r12, rcx # ingress param payload
.Lb05c_sys_clock_gettime_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 96], rax # store tag L2
    mov r13, rdx # hv: unbox user-call result payload
    test r13, r13 # br_cond test
    jz .Lb05c_sys_clock_gettime_bb2 # jump-if-zero -> else
    jmp .Lb05c_sys_clock_gettime_bb1 # jump -> then
.Lb05c_sys_clock_gettime_bb1:
    call SYS_LINUX_CLOCK_GETTIME # call SYS_LINUX_CLOCK_GETTIME
    mov [rbp - 112], rax # store tag L4
    mov r15, rdx # hv: unbox user-call result payload
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 112] # tag L4 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 80] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 88] # tag L1 from tag-slot
    call _sc2 # call _sc2
    mov [rbp - 120], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    mov rdx, [rbp - 56] # reload L5 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 120] # tag L5 from tag-slot
    add rsp, 96 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_sys_clock_gettime_bb2:
    call SYS_DARWIN_CLOCK_GETTIME # call SYS_DARWIN_CLOCK_GETTIME
    mov [rbp - 128], rax # store tag L6
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 64], r10 # spill L6 to slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 128] # tag L6 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 80] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 88] # tag L1 from tag-slot
    call _sc2 # call _sc2
    mov [rbp - 136], rax # store tag L7
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 72], r10 # spill L7 to slot
    mov rdx, [rbp - 72] # reload L7 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 136] # tag L7 from tag-slot
    add rsp, 96 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl sys_fork
.hidden sys_fork
    .p2align 4
sys_fork:
    .loc 1 213 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 64 # prologue: alloc spill frame
.Lb05c_sys_fork_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 64], rax # store tag L0
    mov rbx, rdx # hv: unbox user-call result payload
    test rbx, rbx # br_cond test
    jz .Lb05c_sys_fork_bb2 # jump-if-zero -> else
    jmp .Lb05c_sys_fork_bb1 # jump -> then
.Lb05c_sys_fork_bb1:
    call SYS_LINUX_FORK # call SYS_LINUX_FORK
    mov [rbp - 80], rax # store tag L2
    mov r13, rdx # hv: unbox user-call result payload
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 80] # tag L2 from tag-slot
    call _sc0 # call _sc0
    mov [rbp - 88], rax # store tag L3
    mov r14, rdx # hv: unbox user-call result payload
    mov rdx, r14 # hv arg payload
    mov rax, [rbp - 88] # tag L3 from tag-slot
    add rsp, 64 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_sys_fork_bb2:
    call SYS_DARWIN_FORK # call SYS_DARWIN_FORK
    mov [rbp - 96], rax # store tag L4
    mov r15, rdx # hv: unbox user-call result payload
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 96] # tag L4 from tag-slot
    call _sc0 # call _sc0
    mov [rbp - 104], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
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
.globl sys_execve
.hidden sys_execve
    .p2align 4
sys_execve:
    .loc 1 219 0
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
    mov [rbp - 104], r8 # store tag L2
    mov r13, r9 # ingress param payload
.Lb05c_sys_execve_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 112], rax # store tag L3
    mov r14, rdx # hv: unbox user-call result payload
    test r14, r14 # br_cond test
    jz .Lb05c_sys_execve_bb2 # jump-if-zero -> else
    jmp .Lb05c_sys_execve_bb1 # jump -> then
.Lb05c_sys_execve_bb1:
    call SYS_LINUX_EXECVE # call SYS_LINUX_EXECVE
    mov [rbp - 128], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    sub rsp, 16 # hv: reserve 1 16B stack arg slots
    mov r11, r13 # hv arg payload
    mov r10, [rbp - 104] # tag L2 from tag-slot
    mov [rsp], r10 # hv stack arg 3 tag
    mov [rsp + 8], r11 # hv stack arg 3 payload
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 128] # tag L5 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 88] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 96] # tag L1 from tag-slot
    call _sc3 # call _sc3
    add rsp, 16 # hv: pop 1 stack arg slots
    mov [rbp - 136], rax # store tag L6
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 64], r10 # spill L6 to slot
    mov rdx, [rbp - 64] # reload L6 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 136] # tag L6 from tag-slot
    add rsp, 112 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_sys_execve_bb2:
    call SYS_DARWIN_EXECVE # call SYS_DARWIN_EXECVE
    mov [rbp - 144], rax # store tag L7
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 72], r10 # spill L7 to slot
    sub rsp, 16 # hv: reserve 1 16B stack arg slots
    mov r11, r13 # hv arg payload
    mov r10, [rbp - 104] # tag L2 from tag-slot
    mov [rsp], r10 # hv stack arg 3 tag
    mov [rsp + 8], r11 # hv stack arg 3 payload
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 144] # tag L7 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 88] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 96] # tag L1 from tag-slot
    call _sc3 # call _sc3
    add rsp, 16 # hv: pop 1 stack arg slots
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
.globl sys_wait4
.hidden sys_wait4
    .p2align 4
sys_wait4:
    .loc 1 225 0
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
    mov [rbp - 104], rdx # store tag L1
    mov r12, rcx # ingress param payload
    mov [rbp - 112], r8 # store tag L2
    mov r13, r9 # ingress param payload
    mov r10, [rbp + 16] # ingress stack param 3 tag
    mov [rbp - 120], r10 # store tag L3
    mov r10, [rbp + 24] # ingress stack param 3 payload
    mov r14, r10 # ingress stack param payload
.Lb05c_sys_wait4_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 128], rax # store tag L4
    mov r15, rdx # hv: unbox user-call result payload
    test r15, r15 # br_cond test
    jz .Lb05c_sys_wait4_bb2 # jump-if-zero -> else
    jmp .Lb05c_sys_wait4_bb1 # jump -> then
.Lb05c_sys_wait4_bb1:
    call SYS_LINUX_WAIT4 # call SYS_LINUX_WAIT4
    mov [rbp - 144], rax # store tag L6
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 64], r10 # spill L6 to slot
    sub rsp, 32 # hv: reserve 2 16B stack arg slots
    mov r11, r14 # hv arg payload
    mov r10, [rbp - 120] # tag L3 from tag-slot
    mov [rsp + 16], r10 # hv stack arg 4 tag
    mov [rsp + 24], r11 # hv stack arg 4 payload
    mov r11, r13 # hv arg payload
    mov r10, [rbp - 112] # tag L2 from tag-slot
    mov [rsp], r10 # hv stack arg 3 tag
    mov [rsp + 8], r11 # hv stack arg 3 payload
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 144] # tag L6 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 96] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 104] # tag L1 from tag-slot
    call _sc4 # call _sc4
    add rsp, 32 # hv: pop 2 stack arg slots
    mov [rbp - 152], rax # store tag L7
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 72], r10 # spill L7 to slot
    mov rdx, [rbp - 72] # reload L7 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 152] # tag L7 from tag-slot
    add rsp, 128 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_sys_wait4_bb2:
    call SYS_DARWIN_WAIT4 # call SYS_DARWIN_WAIT4
    mov [rbp - 160], rax # store tag L8
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 80], r10 # spill L8 to slot
    sub rsp, 32 # hv: reserve 2 16B stack arg slots
    mov r11, r14 # hv arg payload
    mov r10, [rbp - 120] # tag L3 from tag-slot
    mov [rsp + 16], r10 # hv stack arg 4 tag
    mov [rsp + 24], r11 # hv stack arg 4 payload
    mov r11, r13 # hv arg payload
    mov r10, [rbp - 112] # tag L2 from tag-slot
    mov [rsp], r10 # hv stack arg 3 tag
    mov [rsp + 8], r11 # hv stack arg 3 payload
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 160] # tag L8 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 96] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 104] # tag L1 from tag-slot
    call _sc4 # call _sc4
    add rsp, 32 # hv: pop 2 stack arg slots
    mov [rbp - 168], rax # store tag L9
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 88], r10 # spill L9 to slot
    mov rdx, [rbp - 88] # reload L9 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 168] # tag L9 from tag-slot
    add rsp, 128 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl sys_pipe
.hidden sys_pipe
    .p2align 4
sys_pipe:
    .loc 1 234 0
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
.Lb05c_sys_pipe_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 64], rax # store tag L1
    mov r12, rdx # hv: unbox user-call result payload
    test r12, r12 # br_cond test
    jz .Lb05c_sys_pipe_bb2 # jump-if-zero -> else
    jmp .Lb05c_sys_pipe_bb1 # jump -> then
.Lb05c_sys_pipe_bb1:
    call SYS_LINUX_PIPE # call SYS_LINUX_PIPE
    mov [rbp - 80], rax # store tag L3
    mov r14, rdx # hv: unbox user-call result payload
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 80] # tag L3 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 56] # tag L0 from tag-slot
    call _sc1 # call _sc1
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
.Lb05c_sys_pipe_bb2:
    mov rdx, -1 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 48 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl sys_dup2
.hidden sys_dup2
    .p2align 4
sys_dup2:
    .loc 1 242 0
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
    mov [rbp - 72], rdx # store tag L1
    mov r12, rcx # ingress param payload
.Lb05c_sys_dup2_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 80], rax # store tag L2
    mov r13, rdx # hv: unbox user-call result payload
    test r13, r13 # br_cond test
    jz .Lb05c_sys_dup2_bb2 # jump-if-zero -> else
    jmp .Lb05c_sys_dup2_bb1 # jump -> then
.Lb05c_sys_dup2_bb1:
    call SYS_LINUX_DUP2 # call SYS_LINUX_DUP2
    mov [rbp - 96], rax # store tag L4
    mov r15, rdx # hv: unbox user-call result payload
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 96] # tag L4 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 64] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 72] # tag L1 from tag-slot
    call _sc2 # call _sc2
    mov [rbp - 104], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
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
.Lb05c_sys_dup2_bb2:
    mov rdx, -1 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 64 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl sys_nanosleep
.hidden sys_nanosleep
    .p2align 4
sys_nanosleep:
    .loc 1 248 0
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
    mov [rbp - 88], rdx # store tag L1
    mov r12, rcx # ingress param payload
.Lb05c_sys_nanosleep_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 96], rax # store tag L2
    mov r13, rdx # hv: unbox user-call result payload
    test r13, r13 # br_cond test
    jz .Lb05c_sys_nanosleep_bb2 # jump-if-zero -> else
    jmp .Lb05c_sys_nanosleep_bb1 # jump -> then
.Lb05c_sys_nanosleep_bb1:
    call SYS_LINUX_NANOSLEEP # call SYS_LINUX_NANOSLEEP
    mov [rbp - 112], rax # store tag L4
    mov r15, rdx # hv: unbox user-call result payload
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 112] # tag L4 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 80] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 88] # tag L1 from tag-slot
    call _sc2 # call _sc2
    mov [rbp - 120], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    mov rdx, [rbp - 56] # reload L5 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 120] # tag L5 from tag-slot
    add rsp, 96 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_sys_nanosleep_bb2:
    call SYS_DARWIN_NANOSLEEP # call SYS_DARWIN_NANOSLEEP
    mov [rbp - 128], rax # store tag L6
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 64], r10 # spill L6 to slot
    mov rsi, [rbp - 64] # reload L6 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 128] # tag L6 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 80] # tag L0 from tag-slot
    mov r9, r12 # hv arg payload
    mov r8, [rbp - 88] # tag L1 from tag-slot
    call _sc2 # call _sc2
    mov [rbp - 136], rax # store tag L7
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 72], r10 # spill L7 to slot
    mov rdx, [rbp - 72] # reload L7 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 136] # tag L7 from tag-slot
    add rsp, 96 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl O_RDONLY
.hidden O_RDONLY
    .p2align 4
O_RDONLY:
    .loc 1 257 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_O_RDONLY_bb0:
    mov rdx, 0 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl O_WRONLY
.hidden O_WRONLY
    .p2align 4
O_WRONLY:
    .loc 1 258 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_O_WRONLY_bb0:
    mov rdx, 1 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl O_RDWR
.hidden O_RDWR
    .p2align 4
O_RDWR:
    .loc 1 259 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_O_RDWR_bb0:
    mov rdx, 2 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl O_CREAT_LINUX
.hidden O_CREAT_LINUX
    .p2align 4
O_CREAT_LINUX:
    .loc 1 262 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_O_CREAT_LINUX_bb0:
    mov rdx, 64 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl O_APPEND_LINUX
.hidden O_APPEND_LINUX
    .p2align 4
O_APPEND_LINUX:
    .loc 1 263 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_O_APPEND_LINUX_bb0:
    mov rdx, 1024 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl O_TRUNC_LINUX
.hidden O_TRUNC_LINUX
    .p2align 4
O_TRUNC_LINUX:
    .loc 1 264 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_O_TRUNC_LINUX_bb0:
    mov rdx, 512 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl O_CREAT_DARWIN
.hidden O_CREAT_DARWIN
    .p2align 4
O_CREAT_DARWIN:
    .loc 1 265 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_O_CREAT_DARWIN_bb0:
    mov rdx, 512 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl O_APPEND_DARWIN
.hidden O_APPEND_DARWIN
    .p2align 4
O_APPEND_DARWIN:
    .loc 1 266 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_O_APPEND_DARWIN_bb0:
    mov rdx, 8 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl O_TRUNC_DARWIN
.hidden O_TRUNC_DARWIN
    .p2align 4
O_TRUNC_DARWIN:
    .loc 1 267 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_O_TRUNC_DARWIN_bb0:
    mov rdx, 1024 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl flag_o_creat
.hidden flag_o_creat
    .p2align 4
flag_o_creat:
    .loc 1 269 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 32 # prologue: alloc spill frame
.Lb05c_flag_o_creat_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 56], rax # store tag L0
    mov rbx, rdx # hv: unbox user-call result payload
    test rbx, rbx # br_cond test
    jz .Lb05c_flag_o_creat_bb2 # jump-if-zero -> else
    jmp .Lb05c_flag_o_creat_bb1 # jump -> then
.Lb05c_flag_o_creat_bb1:
    call O_CREAT_LINUX # call O_CREAT_LINUX
    mov [rbp - 72], rax # store tag L2
    mov r13, rdx # hv: unbox user-call result payload
    mov rdx, r13 # hv arg payload
    mov rax, [rbp - 72] # tag L2 from tag-slot
    add rsp, 32 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_flag_o_creat_bb2:
    call O_CREAT_DARWIN # call O_CREAT_DARWIN
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
.globl flag_o_append
.hidden flag_o_append
    .p2align 4
flag_o_append:
    .loc 1 273 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 32 # prologue: alloc spill frame
.Lb05c_flag_o_append_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 56], rax # store tag L0
    mov rbx, rdx # hv: unbox user-call result payload
    test rbx, rbx # br_cond test
    jz .Lb05c_flag_o_append_bb2 # jump-if-zero -> else
    jmp .Lb05c_flag_o_append_bb1 # jump -> then
.Lb05c_flag_o_append_bb1:
    call O_APPEND_LINUX # call O_APPEND_LINUX
    mov [rbp - 72], rax # store tag L2
    mov r13, rdx # hv: unbox user-call result payload
    mov rdx, r13 # hv arg payload
    mov rax, [rbp - 72] # tag L2 from tag-slot
    add rsp, 32 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_flag_o_append_bb2:
    call O_APPEND_DARWIN # call O_APPEND_DARWIN
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
.globl flag_o_trunc
.hidden flag_o_trunc
    .p2align 4
flag_o_trunc:
    .loc 1 277 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 32 # prologue: alloc spill frame
.Lb05c_flag_o_trunc_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 56], rax # store tag L0
    mov rbx, rdx # hv: unbox user-call result payload
    test rbx, rbx # br_cond test
    jz .Lb05c_flag_o_trunc_bb2 # jump-if-zero -> else
    jmp .Lb05c_flag_o_trunc_bb1 # jump -> then
.Lb05c_flag_o_trunc_bb1:
    call O_TRUNC_LINUX # call O_TRUNC_LINUX
    mov [rbp - 72], rax # store tag L2
    mov r13, rdx # hv: unbox user-call result payload
    mov rdx, r13 # hv arg payload
    mov rax, [rbp - 72] # tag L2 from tag-slot
    add rsp, 32 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_flag_o_trunc_bb2:
    call O_TRUNC_DARWIN # call O_TRUNC_DARWIN
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
.globl PROT_READ
.hidden PROT_READ
    .p2align 4
PROT_READ:
    .loc 1 286 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_PROT_READ_bb0:
    mov rdx, 1 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl PROT_WRITE
.hidden PROT_WRITE
    .p2align 4
PROT_WRITE:
    .loc 1 287 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_PROT_WRITE_bb0:
    mov rdx, 2 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl PROT_EXEC
.hidden PROT_EXEC
    .p2align 4
PROT_EXEC:
    .loc 1 288 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_PROT_EXEC_bb0:
    mov rdx, 4 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl MAP_PRIVATE
.hidden MAP_PRIVATE
    .p2align 4
MAP_PRIVATE:
    .loc 1 289 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_MAP_PRIVATE_bb0:
    mov rdx, 2 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl MAP_ANON_LINUX
.hidden MAP_ANON_LINUX
    .p2align 4
MAP_ANON_LINUX:
    .loc 1 290 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_MAP_ANON_LINUX_bb0:
    mov rdx, 32 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl MAP_ANON_DARWIN
.hidden MAP_ANON_DARWIN
    .p2align 4
MAP_ANON_DARWIN:
    .loc 1 291 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_MAP_ANON_DARWIN_bb0:
    mov rdx, 4096 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl flag_map_anon
.hidden flag_map_anon
    .p2align 4
flag_map_anon:
    .loc 1 292 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 32 # prologue: alloc spill frame
.Lb05c_flag_map_anon_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 56], rax # store tag L0
    mov rbx, rdx # hv: unbox user-call result payload
    test rbx, rbx # br_cond test
    jz .Lb05c_flag_map_anon_bb2 # jump-if-zero -> else
    jmp .Lb05c_flag_map_anon_bb1 # jump -> then
.Lb05c_flag_map_anon_bb1:
    call MAP_ANON_LINUX # call MAP_ANON_LINUX
    mov [rbp - 72], rax # store tag L2
    mov r13, rdx # hv: unbox user-call result payload
    mov rdx, r13 # hv arg payload
    mov rax, [rbp - 72] # tag L2 from tag-slot
    add rsp, 32 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_flag_map_anon_bb2:
    call MAP_ANON_DARWIN # call MAP_ANON_DARWIN
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
.globl CLOCK_REALTIME
.hidden CLOCK_REALTIME
    .p2align 4
CLOCK_REALTIME:
    .loc 1 301 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_CLOCK_REALTIME_bb0:
    mov rdx, 0 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl CLOCK_MONOTONIC_LINUX
.hidden CLOCK_MONOTONIC_LINUX
    .p2align 4
CLOCK_MONOTONIC_LINUX:
    .loc 1 302 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_CLOCK_MONOTONIC_LINUX_bb0:
    mov rdx, 1 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl CLOCK_MONOTONIC_DARWIN
.hidden CLOCK_MONOTONIC_DARWIN
    .p2align 4
CLOCK_MONOTONIC_DARWIN:
    .loc 1 303 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_CLOCK_MONOTONIC_DARWIN_bb0:
    mov rdx, 6 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl clock_monotonic
.hidden clock_monotonic
    .p2align 4
clock_monotonic:
    .loc 1 304 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 32 # prologue: alloc spill frame
.Lb05c_clock_monotonic_bb0:
    call target_is_linux # call target_is_linux
    mov [rbp - 56], rax # store tag L0
    mov rbx, rdx # hv: unbox user-call result payload
    test rbx, rbx # br_cond test
    jz .Lb05c_clock_monotonic_bb2 # jump-if-zero -> else
    jmp .Lb05c_clock_monotonic_bb1 # jump -> then
.Lb05c_clock_monotonic_bb1:
    call CLOCK_MONOTONIC_LINUX # call CLOCK_MONOTONIC_LINUX
    mov [rbp - 72], rax # store tag L2
    mov r13, rdx # hv: unbox user-call result payload
    mov rdx, r13 # hv arg payload
    mov rax, [rbp - 72] # tag L2 from tag-slot
    add rsp, 32 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_clock_monotonic_bb2:
    call CLOCK_MONOTONIC_DARWIN # call CLOCK_MONOTONIC_DARWIN
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
.globl HEXA_ARENA_BLOCK_SIZE
.hidden HEXA_ARENA_BLOCK_SIZE
    .p2align 4
HEXA_ARENA_BLOCK_SIZE:
    .loc 1 335 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_HEXA_ARENA_BLOCK_SIZE_bb0:
    mov rdx, 1048576 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl BLOCK_HDR
.hidden BLOCK_HDR
    .p2align 4
BLOCK_HDR:
    .loc 1 336 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_BLOCK_HDR_bb0:
    mov rdx, 24 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl __env_extend
.hidden __env_extend
    .p2align 4
__env_extend:
    .loc 1 348 0
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
    mov [rbp - 104], rdx # store tag L1
    mov r12, rcx # ingress param payload
.Lb05c___env_extend_bb0:
    mov r10, [rip+g2] # load global value: g2
    mov rsi, [rip+g2] # load global value: g2
    mov rsi, rsi # hv arg payload
    mov rdi, [rip+g2+8] # tag g2 from global slot+8
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r13, rdx # binop ==: capture bool payload
    mov [rbp - 112], rax # store tag L2
    test r13, r13 # br_cond test
    jz .Lb05c___env_extend_bb2 # jump-if-zero -> else
    jmp .Lb05c___env_extend_bb1 # jump -> then
.Lb05c___env_extend_bb1:
    mov r13, rbx # assign L2
    mov r11, [rbp - 96] # tag L0 from tag-slot
    mov [rbp - 112], r11 # store tag L2
    mov [rip+g2], r13 # global write: g2
    mov r11, [rbp - 112] # global tag: reload g2 tag-slot
    mov [rip+g2+8], r11 # global tag write: g2+8
    jmp .Lb05c___env_extend_bb5 # branch
.Lb05c___env_extend_bb2:
    mov r11, [rip+g2] # load global value: g2
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 96] # tag L0 from tag-slot
    mov rcx, [rip+g2] # load global value: g2
    mov rcx, rcx # hv arg payload
    mov rdx, [rip+g2+8] # tag g2 from global slot+8
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r15, rdx # binop <: capture bool payload
    mov [rbp - 128], rax # store tag L4
    test r15, r15 # br_cond test
    jz .Lb05c___env_extend_bb4 # jump-if-zero -> else
    jmp .Lb05c___env_extend_bb3 # jump -> then
.Lb05c___env_extend_bb3:
    mov r13, rbx # assign L2
    mov r11, [rbp - 96] # tag L0 from tag-slot
    mov [rbp - 112], r11 # store tag L2
    mov [rip+g2], r13 # global write: g2
    mov r11, [rbp - 112] # global tag: reload g2 tag-slot
    mov [rip+g2+8], r11 # global tag write: g2+8
    jmp .Lb05c___env_extend_bb4 # branch
.Lb05c___env_extend_bb4:
    jmp .Lb05c___env_extend_bb5 # branch
.Lb05c___env_extend_bb5:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 96] # tag L0 from tag-slot
    mov rcx, r12 # hv arg payload
    mov rdx, [rbp - 104] # tag L1 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 144], rax # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 144] # tag L6 from tag-slot
    mov [rbp - 152], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r11, [rip+g3] # load global value: g3
    mov rsi, [rbp - 72] # reload L7 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 152] # tag L7 from tag-slot
    mov rcx, [rip+g3] # load global value: g3
    mov rcx, rcx # hv arg payload
    mov rdx, [rip+g3+8] # tag g3 from global slot+8
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 160], rax # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    test r10, r10 # br_cond test
    jz .Lb05c___env_extend_bb7 # jump-if-zero -> else
    jmp .Lb05c___env_extend_bb6 # jump -> then
.Lb05c___env_extend_bb6:
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 152] # tag L7 from tag-slot
    mov [rbp - 120], r11 # store tag L3
    mov [rip+g3], r14 # global write: g3
    mov r11, [rbp - 120] # global tag: reload g3 tag-slot
    mov [rip+g3+8], r11 # global tag write: g3+8
    jmp .Lb05c___env_extend_bb7 # branch
.Lb05c___env_extend_bb7:
    add rsp, 128 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_arena_env_lo
.hidden hexa_arena_env_lo
    .p2align 4
hexa_arena_env_lo:
    .loc 1 358 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_hexa_arena_env_lo_bb0:
    mov rdx, [rip+g2] # load global value: g2
    mov rdx, rdx # hv arg payload
    mov rax, [rip+g2+8] # tag g2 from global slot+8
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_arena_env_hi
.hidden hexa_arena_env_hi
    .p2align 4
hexa_arena_env_hi:
    .loc 1 359 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_hexa_arena_env_hi_bb0:
    mov rdx, [rip+g3] # load global value: g3
    mov rdx, rdx # hv arg payload
    mov rax, [rip+g3+8] # tag g3 from global slot+8
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_arena_head
.hidden hexa_arena_head
    .p2align 4
hexa_arena_head:
    .loc 1 370 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_hexa_arena_head_bb0:
    mov rdx, [rip+g0] # load global value: g0
    mov rdx, rdx # hv arg payload
    mov rax, [rip+g0+8] # tag g0 from global slot+8
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_arena_cur
.hidden hexa_arena_cur
    .p2align 4
hexa_arena_cur:
    .loc 1 371 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_hexa_arena_cur_bb0:
    mov rdx, [rip+g1] # load global value: g1
    mov rdx, rdx # hv arg payload
    mov rax, [rip+g1+8] # tag g1 from global slot+8
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl __blk_data
.hidden __blk_data
    .p2align 4
__blk_data:
    .loc 1 372 0
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
.Lb05c___blk_data_bb0:
    call BLOCK_HDR # call BLOCK_HDR
    mov [rbp - 64], rax # store tag L1
    mov r12, rdx # hv: unbox user-call result payload
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 56] # tag L0 from tag-slot
    mov rcx, r12 # hv arg payload
    mov rdx, [rbp - 64] # tag L1 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r13, rdx # binop +: capture result payload
    mov [rbp - 72], rax # store tag L2
    mov rdx, r13 # hv arg payload
    mov rax, [rbp - 72] # tag L2 from tag-slot
    add rsp, 32 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl align_up
.hidden align_up
    .p2align 4
align_up:
    .loc 1 374 0
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
    mov [rbp - 72], rdx # store tag L1
    mov r12, rcx # ingress param payload
.Lb05c_align_up_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 64] # tag L0 from tag-slot
    mov rcx, r12 # hv arg payload
    mov rdx, [rbp - 72] # tag L1 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r13, rdx # binop +: capture result payload
    mov [rbp - 80], rax # store tag L2
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 80] # tag L2 from tag-slot
    mov rcx, 1 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r14, rdx # binop -: capture result payload
    mov [rbp - 88], rax # store tag L3
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 88] # tag L3 from tag-slot
    mov rcx, r12 # hv arg payload
    mov rdx, [rbp - 72] # tag L1 from tag-slot
    call hexa_div # binop /: tag-dispatch hexa_div
    mov r15, rdx # binop /: capture result payload
    mov [rbp - 96], rax # store tag L4
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 96] # tag L4 from tag-slot
    mov rcx, r12 # hv arg payload
    mov rdx, [rbp - 72] # tag L1 from tag-slot
    call hexa_mul # binop *: tag-dispatch hexa_mul
    mov r10, rdx # binop *: capture result payload
    mov [rbp - 104], rax # store tag L5
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
.globl __blk_next
.hidden __blk_next
    .p2align 4
__blk_next:
    .loc 1 379 0
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
.Lb05c___blk_next_bb0:
    mov r10, rbx # hv payload
    mov r11, 0 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r12, r10 # leaf: payload → dst L1
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 64], r11 # store tag L1
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
.globl __blk_cap
.hidden __blk_cap
    .p2align 4
__blk_cap:
    .loc 1 380 0
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
.Lb05c___blk_cap_bb0:
    mov r10, rbx # hv payload
    mov r11, 8 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r12, r10 # leaf: payload → dst L1
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 64], r11 # store tag L1
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
.globl __blk_used
.hidden __blk_used
    .p2align 4
__blk_used:
    .loc 1 381 0
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
.Lb05c___blk_used_bb0:
    mov r10, rbx # hv payload
    mov r11, 16 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r12, r10 # leaf: payload → dst L1
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 64], r11 # store tag L1
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
.globl __blk_set_next
.hidden __blk_set_next
    .p2align 4
__blk_set_next:
    .loc 1 382 0
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
    mov [rbp - 64], rdx # store tag L1
    mov r12, rcx # ingress param payload
.Lb05c___blk_set_next_bb0:
    mov r10, rbx # hv payload
    mov r11, 0 # hv payload
    mov rsi, r12 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, rbx # hv payload
    mov r13, r10 # leaf: payload → dst L2
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 72], r11 # store tag L2
    mov rdx, r13 # hv arg payload
    mov rax, [rbp - 72] # tag L2 from tag-slot
    add rsp, 32 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl __blk_set_cap
.hidden __blk_set_cap
    .p2align 4
__blk_set_cap:
    .loc 1 383 0
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
    mov [rbp - 64], rdx # store tag L1
    mov r12, rcx # ingress param payload
.Lb05c___blk_set_cap_bb0:
    mov r10, rbx # hv payload
    mov r11, 8 # hv payload
    mov rsi, r12 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, rbx # hv payload
    mov r13, r10 # leaf: payload → dst L2
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 72], r11 # store tag L2
    mov rdx, r13 # hv arg payload
    mov rax, [rbp - 72] # tag L2 from tag-slot
    add rsp, 32 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl __blk_set_used
.hidden __blk_set_used
    .p2align 4
__blk_set_used:
    .loc 1 384 0
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
    mov [rbp - 64], rdx # store tag L1
    mov r12, rcx # ingress param payload
.Lb05c___blk_set_used_bb0:
    mov r10, rbx # hv payload
    mov r11, 16 # hv payload
    mov rsi, r12 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, rbx # hv payload
    mov r13, r10 # leaf: payload → dst L2
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 72], r11 # store tag L2
    mov rdx, r13 # hv arg payload
    mov rax, [rbp - 72] # tag L2 from tag-slot
    add rsp, 32 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_arena_new_block
.hidden hexa_arena_new_block
    .p2align 4
hexa_arena_new_block:
    .loc 1 387 0
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
.Lb05c_hexa_arena_new_block_bb0:
    call HEXA_ARENA_BLOCK_SIZE # call HEXA_ARENA_BLOCK_SIZE
    mov [rbp - 240], rax # store tag L1
    mov r12, rdx # hv: unbox user-call result payload
    mov r13, r12 # assign L2
    mov r11, [rbp - 240] # tag L1 from tag-slot
    mov [rbp - 248], r11 # store tag L2
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 232] # tag L0 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 248] # tag L2 from tag-slot
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r14, rdx # binop >: capture bool payload
    mov [rbp - 256], rax # store tag L3
    test r14, r14 # br_cond test
    jz .Lb05c_hexa_arena_new_block_bb2 # jump-if-zero -> else
    jmp .Lb05c_hexa_arena_new_block_bb1 # jump -> then
.Lb05c_hexa_arena_new_block_bb1:
    mov r13, rbx # assign L2
    mov r11, [rbp - 232] # tag L0 from tag-slot
    mov [rbp - 248], r11 # store tag L2
    jmp .Lb05c_hexa_arena_new_block_bb2 # branch
.Lb05c_hexa_arena_new_block_bb2:
    call BLOCK_HDR # call BLOCK_HDR
    mov [rbp - 272], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 272] # tag L5 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 248] # tag L2 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 280], rax # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 280] # tag L6 from tag-slot
    mov [rbp - 288], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    call MAP_PRIVATE # call MAP_PRIVATE
    mov [rbp - 296], rax # store tag L8
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 80], r10 # spill L8 to slot
    call flag_map_anon # call flag_map_anon
    mov [rbp - 304], rax # store tag L9
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 296] # tag L8 from tag-slot
    mov rcx, [rbp - 88] # reload L9 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 304] # tag L9 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 312], rax # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 312] # tag L10 from tag-slot
    mov [rbp - 320], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    call PROT_READ # call PROT_READ
    mov [rbp - 328], rax # store tag L12
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 112], r10 # spill L12 to slot
    call PROT_WRITE # call PROT_WRITE
    mov [rbp - 336], rax # store tag L13
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 328] # tag L12 from tag-slot
    mov rcx, [rbp - 120] # reload L13 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 336] # tag L13 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 344], rax # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 344] # tag L14 from tag-slot
    mov [rbp - 352], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    sub rsp, 48 # hv: reserve 3 16B stack arg slots
    mov r11, 0 # hv arg payload
    mov r10, 0 # tag default = TAG_INT
    mov [rsp + 32], r10 # hv stack arg 5 tag
    mov [rsp + 40], r11 # hv stack arg 5 payload
    mov r11, -1 # hv arg payload
    mov r10, 0 # tag default = TAG_INT
    mov [rsp + 16], r10 # hv stack arg 4 tag
    mov [rsp + 24], r11 # hv stack arg 4 payload
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r11, r11 # hv arg payload
    mov r10, [rbp - 320] # tag L11 from tag-slot
    mov [rsp], r10 # hv stack arg 3 tag
    mov [rsp + 8], r11 # hv stack arg 3 payload
    mov rsi, 0 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    mov rcx, [rbp - 72] # reload L7 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 288] # tag L7 from tag-slot
    mov r9, [rbp - 136] # reload L15 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 352] # tag L15 from tag-slot
    call sys_mmap # call sys_mmap
    add rsp, 48 # hv: pop 3 stack arg slots
    mov [rbp - 360], rax # store tag L16
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, [rbp - 360] # tag L16 from tag-slot
    mov [rbp - 368], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov rsi, [rbp - 152] # reload L17 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 368] # tag L17 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 376], rax # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r10, [rbp - 160] # reload L18 from spill slot
    test r10, r10 # br_cond test
    jz .Lb05c_hexa_arena_new_block_bb4 # jump-if-zero -> else
    jmp .Lb05c_hexa_arena_new_block_bb3 # jump -> then
.Lb05c_hexa_arena_new_block_bb3:
    mov rsi, 137 # hv arg payload
    mov rdi, 0 # tag default = TAG_INT
    call sys_exit # call sys_exit
    mov [rbp - 392], rax # store tag L20
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 176], r10 # spill L20 to slot
    mov rdx, 0 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 400 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_hexa_arena_new_block_bb4:
    mov rsi, [rbp - 152] # reload L17 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 368] # tag L17 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call __blk_set_next # call __blk_set_next
    mov [rbp - 400], rax # store tag L21
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 184], r10 # spill L21 to slot
    mov rsi, [rbp - 152] # reload L17 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 368] # tag L17 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 248] # tag L2 from tag-slot
    call __blk_set_cap # call __blk_set_cap
    mov [rbp - 408], rax # store tag L22
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 192], r10 # spill L22 to slot
    mov rsi, [rbp - 152] # reload L17 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 368] # tag L17 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call __blk_set_used # call __blk_set_used
    mov [rbp - 416], rax # store tag L23
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 200], r10 # spill L23 to slot
    call BLOCK_HDR # call BLOCK_HDR
    mov [rbp - 424], rax # store tag L24
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 208], r10 # spill L24 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r11, [rbp - 208] # reload L24 from spill slot
    mov rsi, [rbp - 152] # reload L17 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 368] # tag L17 from tag-slot
    mov rcx, [rbp - 208] # reload L24 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 424] # tag L24 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 432], rax # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov rsi, [rbp - 216] # reload L25 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 432] # tag L25 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 248] # tag L2 from tag-slot
    call __env_extend # call __env_extend
    mov [rbp - 440], rax # store tag L26
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 224], r10 # spill L26 to slot
    mov rdx, [rbp - 152] # reload L17 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 368] # tag L17 from tag-slot
    add rsp, 400 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl rt_init
.hidden rt_init
    .p2align 4
rt_init:
    .loc 1 405 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 16 # prologue: alloc spill frame
.Lb05c_rt_init_bb0:
    call HEXA_ARENA_BLOCK_SIZE # call HEXA_ARENA_BLOCK_SIZE
    mov [rbp - 56], rax # store tag L0
    mov rbx, rdx # hv: unbox user-call result payload
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 56] # tag L0 from tag-slot
    call hexa_arena_new_block # call hexa_arena_new_block
    mov [rbp - 64], rax # store tag L1
    mov r12, rdx # hv: unbox user-call result payload
    mov rbx, r12 # assign L0
    mov r11, [rbp - 64] # tag L1 from tag-slot
    mov [rbp - 56], r11 # store tag L0
    mov [rip+g0], rbx # global write: g0
    mov r11, [rbp - 56] # global tag: reload g0 tag-slot
    mov [rip+g0+8], r11 # global tag write: g0+8
    mov r10, [rip+g0] # load global value: g0
    mov r12, r10 # assign L1
    mov r11, [rip+g0+8] # tag g0 from global slot+8
    mov [rbp - 64], r11 # store tag L1
    mov [rip+g1], r12 # global write: g1
    mov r11, [rbp - 64] # global tag: reload g1 tag-slot
    mov [rip+g1+8], r11 # global tag write: g1+8
    add rsp, 16 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_arena_on
.hidden hexa_arena_on
    .p2align 4
hexa_arena_on:
    .loc 1 410 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.Lb05c_hexa_arena_on_bb0:
    mov rdx, 1 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_arena_alloc
.hidden hexa_arena_alloc
    .p2align 4
hexa_arena_alloc:
    .loc 1 418 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 656 # prologue: alloc spill frame
    mov [rbp - 360], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.Lb05c_hexa_arena_alloc_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 360] # tag L0 from tag-slot
    mov rcx, 8 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call align_up # call align_up
    mov [rbp - 368], rax # store tag L1
    mov r12, rdx # hv: unbox user-call result payload
    mov r13, r12 # assign L2
    mov r11, [rbp - 368] # tag L1 from tag-slot
    mov [rbp - 376], r11 # store tag L2
    mov r14, r13 # assign L3
    mov r11, [rbp - 376] # tag L2 from tag-slot
    mov [rbp - 384], r11 # store tag L3
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 384] # tag L3 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r15, rdx # binop ==: capture bool payload
    mov [rbp - 392], rax # store tag L4
    test r15, r15 # br_cond test
    jz .Lb05c_hexa_arena_alloc_bb2 # jump-if-zero -> else
    jmp .Lb05c_hexa_arena_alloc_bb1 # jump -> then
.Lb05c_hexa_arena_alloc_bb1:
    mov r14, 8 # assign L3
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 384], r11 # store tag L3
    jmp .Lb05c_hexa_arena_alloc_bb2 # branch
.Lb05c_hexa_arena_alloc_bb2:
    mov r10, [rip+g0] # load global value: g0
    mov rsi, [rip+g0] # load global value: g0
    mov rsi, rsi # hv arg payload
    mov rdi, [rip+g0+8] # tag g0 from global slot+8
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 408], rax # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r10, [rbp - 64] # reload L6 from spill slot
    test r10, r10 # br_cond test
    jz .Lb05c_hexa_arena_alloc_bb4 # jump-if-zero -> else
    jmp .Lb05c_hexa_arena_alloc_bb3 # jump -> then
.Lb05c_hexa_arena_alloc_bb3:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 384] # tag L3 from tag-slot
    call hexa_arena_new_block # call hexa_arena_new_block
    mov [rbp - 424], rax # store tag L8
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 80], r10 # spill L8 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov rbx, r10 # assign L0
    mov r11, [rbp - 424] # tag L8 from tag-slot
    mov [rbp - 360], r11 # store tag L0
    mov [rip+g0], rbx # global write: g0
    mov r11, [rbp - 360] # global tag: reload g0 tag-slot
    mov [rip+g0+8], r11 # global tag write: g0+8
    mov r10, [rip+g0] # load global value: g0
    mov r12, r10 # assign L1
    mov r11, [rip+g0+8] # tag g0 from global slot+8
    mov [rbp - 368], r11 # store tag L1
    mov [rip+g1], r12 # global write: g1
    mov r11, [rbp - 368] # global tag: reload g1 tag-slot
    mov [rip+g1+8], r11 # global tag write: g1+8
    mov r10, [rip+g0] # load global value: g0
    mov rsi, [rip+g0] # load global value: g0
    mov rsi, rsi # hv arg payload
    mov rdi, [rip+g0+8] # tag g0 from global slot+8
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 432], rax # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 88] # reload L9 from spill slot
    test r10, r10 # br_cond test
    jz .Lb05c_hexa_arena_alloc_bb6 # jump-if-zero -> else
    jmp .Lb05c_hexa_arena_alloc_bb5 # jump -> then
.Lb05c_hexa_arena_alloc_bb4:
    mov r11, [rip+g1] # load global value: g1
    mov r10, r11 # assign L11
    mov r11, [rip+g1+8] # tag g1 from global slot+8
    mov [rbp - 448], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov rsi, [rbp - 104] # reload L11 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 448] # tag L11 from tag-slot
    call __blk_used # call __blk_used
    mov [rbp - 456], rax # store tag L12
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 112], r10 # spill L12 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 456] # tag L12 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 384] # tag L3 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 464], rax # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov rsi, [rbp - 104] # reload L11 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 448] # tag L11 from tag-slot
    call __blk_cap # call __blk_cap
    mov [rbp - 472], rax # store tag L14
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 128], r10 # spill L14 to slot
    mov r10, [rbp - 120] # reload L13 from spill slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov rsi, [rbp - 120] # reload L13 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 464] # tag L13 from tag-slot
    mov rcx, [rbp - 128] # reload L14 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 472] # tag L14 from tag-slot
    call hexa_cmp_gt # binop >: tag-dispatch hexa_cmp_gt
    mov r10, rdx # binop >: capture bool payload
    mov [rbp - 480], rax # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r10, [rbp - 136] # reload L15 from spill slot
    test r10, r10 # br_cond test
    jz .Lb05c_hexa_arena_alloc_bb8 # jump-if-zero -> else
    jmp .Lb05c_hexa_arena_alloc_bb7 # jump -> then
.Lb05c_hexa_arena_alloc_bb5:
    mov rdx, 0 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 656 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_hexa_arena_alloc_bb6:
    jmp .Lb05c_hexa_arena_alloc_bb4 # branch
.Lb05c_hexa_arena_alloc_bb7:
    mov rsi, [rbp - 104] # reload L11 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 448] # tag L11 from tag-slot
    call __blk_next # call __blk_next
    mov [rbp - 496], rax # store tag L17
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 152], r10 # spill L17 to slot
    mov r11, [rbp - 152] # reload L17 from spill slot
    mov r10, r11 # assign L18
    mov r11, [rbp - 496] # tag L17 from tag-slot
    mov [rbp - 504], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    jmp .Lb05c_hexa_arena_alloc_bb9 # branch
.Lb05c_hexa_arena_alloc_bb8:
    call BLOCK_HDR # call BLOCK_HDR
    mov [rbp - 640], rax # store tag L35
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 296], r10 # spill L35 to slot
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r11, [rbp - 296] # reload L35 from spill slot
    mov rsi, [rbp - 104] # reload L11 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 448] # tag L11 from tag-slot
    mov rcx, [rbp - 296] # reload L35 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 640] # tag L35 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 648], rax # store tag L36
    mov [rbp - 304], r10 # spill L36 to slot
    mov rsi, [rbp - 104] # reload L11 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 448] # tag L11 from tag-slot
    call __blk_used # call __blk_used
    mov [rbp - 656], rax # store tag L37
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 312], r10 # spill L37 to slot
    mov r10, [rbp - 304] # reload L36 from spill slot
    mov r11, [rbp - 312] # reload L37 from spill slot
    mov rsi, [rbp - 304] # reload L36 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 648] # tag L36 from tag-slot
    mov rcx, [rbp - 312] # reload L37 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 656] # tag L37 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 664], rax # store tag L38
    mov [rbp - 320], r10 # spill L38 to slot
    mov r11, [rbp - 320] # reload L38 from spill slot
    mov r10, r11 # assign L39
    mov r11, [rbp - 664] # tag L38 from tag-slot
    mov [rbp - 672], r11 # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    mov rsi, [rbp - 104] # reload L11 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 448] # tag L11 from tag-slot
    call __blk_used # call __blk_used
    mov [rbp - 680], rax # store tag L40
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 336], r10 # spill L40 to slot
    mov r10, [rbp - 336] # reload L40 from spill slot
    mov rsi, [rbp - 336] # reload L40 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 680] # tag L40 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 384] # tag L3 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 688], rax # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    mov rsi, [rbp - 104] # reload L11 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 448] # tag L11 from tag-slot
    mov rcx, [rbp - 344] # reload L41 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 688] # tag L41 from tag-slot
    call __blk_set_used # call __blk_set_used
    mov [rbp - 696], rax # store tag L42
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 352], r10 # spill L42 to slot
    mov rdx, [rbp - 328] # reload L39 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 672] # tag L39 from tag-slot
    add rsp, 656 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_hexa_arena_alloc_bb9:
    mov r10, [rbp - 160] # reload L18 from spill slot
    mov rsi, [rbp - 160] # reload L18 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 504] # tag L18 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 512], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    mov r10, [rbp - 168] # reload L19 from spill slot
    test r10, r10 # br_cond test
    jz .Lb05c_hexa_arena_alloc_bb11 # jump-if-zero -> else
    jmp .Lb05c_hexa_arena_alloc_bb10 # jump -> then
.Lb05c_hexa_arena_alloc_bb10:
    mov rsi, [rbp - 160] # reload L18 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 504] # tag L18 from tag-slot
    call __blk_cap # call __blk_cap
    mov [rbp - 520], rax # store tag L20
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, [rbp - 176] # reload L20 from spill slot
    mov rsi, [rbp - 176] # reload L20 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 520] # tag L20 from tag-slot
    mov rcx, r14 # hv arg payload
    mov rdx, [rbp - 384] # tag L3 from tag-slot
    call hexa_cmp_ge # binop >=: tag-dispatch hexa_cmp_ge
    mov r10, rdx # binop >=: capture bool payload
    mov [rbp - 528], rax # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r10, [rbp - 184] # reload L21 from spill slot
    test r10, r10 # br_cond test
    jz .Lb05c_hexa_arena_alloc_bb13 # jump-if-zero -> else
    jmp .Lb05c_hexa_arena_alloc_bb12 # jump -> then
.Lb05c_hexa_arena_alloc_bb11:
    mov r10, [rbp - 160] # reload L18 from spill slot
    mov rsi, [rbp - 160] # reload L18 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 504] # tag L18 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 552], rax # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r10, [rbp - 208] # reload L24 from spill slot
    test r10, r10 # br_cond test
    jz .Lb05c_hexa_arena_alloc_bb15 # jump-if-zero -> else
    jmp .Lb05c_hexa_arena_alloc_bb14 # jump -> then
.Lb05c_hexa_arena_alloc_bb12:
    jmp .Lb05c_hexa_arena_alloc_bb11 # branch
.Lb05c_hexa_arena_alloc_bb13:
    mov rsi, [rbp - 160] # reload L18 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 504] # tag L18 from tag-slot
    call __blk_next # call __blk_next
    mov [rbp - 544], rax # store tag L23
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L18
    mov r11, [rbp - 544] # tag L23 from tag-slot
    mov [rbp - 504], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    jmp .Lb05c_hexa_arena_alloc_bb9 # branch
.Lb05c_hexa_arena_alloc_bb14:
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 384] # tag L3 from tag-slot
    call hexa_arena_new_block # call hexa_arena_new_block
    mov [rbp - 568], rax # store tag L26
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 224], r10 # spill L26 to slot
    mov r11, [rbp - 224] # reload L26 from spill slot
    mov r10, r11 # assign L18
    mov r11, [rbp - 568] # tag L26 from tag-slot
    mov [rbp - 504], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r10, [rbp - 160] # reload L18 from spill slot
    mov rsi, [rbp - 160] # reload L18 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 504] # tag L18 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 576], rax # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov r10, [rbp - 232] # reload L27 from spill slot
    test r10, r10 # br_cond test
    jz .Lb05c_hexa_arena_alloc_bb17 # jump-if-zero -> else
    jmp .Lb05c_hexa_arena_alloc_bb16 # jump -> then
.Lb05c_hexa_arena_alloc_bb15:
    mov rsi, [rbp - 160] # reload L18 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 504] # tag L18 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call __blk_set_used # call __blk_set_used
    mov [rbp - 632], rax # store tag L34
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 288], r10 # spill L34 to slot
    mov r10, [rbp - 160] # reload L18 from spill slot
    mov r12, r10 # assign L1
    mov r11, [rbp - 504] # tag L18 from tag-slot
    mov [rbp - 368], r11 # store tag L1
    mov [rip+g1], r12 # global write: g1
    mov r11, [rbp - 368] # global tag: reload g1 tag-slot
    mov [rip+g1+8], r11 # global tag write: g1+8
    mov r11, [rbp - 160] # reload L18 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 504] # tag L18 from tag-slot
    mov [rbp - 448], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    jmp .Lb05c_hexa_arena_alloc_bb8 # branch
.Lb05c_hexa_arena_alloc_bb16:
    mov rdx, 0 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 656 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_hexa_arena_alloc_bb17:
    mov r11, [rip+g1] # load global value: g1
    mov r10, r11 # assign L29
    mov r11, [rip+g1+8] # tag g1 from global slot+8
    mov [rbp - 592], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    jmp .Lb05c_hexa_arena_alloc_bb18 # branch
.Lb05c_hexa_arena_alloc_bb18:
    mov rsi, [rbp - 248] # reload L29 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 592] # tag L29 from tag-slot
    call __blk_next # call __blk_next
    mov [rbp - 600], rax # store tag L30
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 256], r10 # spill L30 to slot
    mov r10, [rbp - 256] # reload L30 from spill slot
    mov rsi, [rbp - 256] # reload L30 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 600] # tag L30 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 608], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov r10, [rbp - 264] # reload L31 from spill slot
    test r10, r10 # br_cond test
    jz .Lb05c_hexa_arena_alloc_bb20 # jump-if-zero -> else
    jmp .Lb05c_hexa_arena_alloc_bb19 # jump -> then
.Lb05c_hexa_arena_alloc_bb19:
    mov rsi, [rbp - 248] # reload L29 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 592] # tag L29 from tag-slot
    call __blk_next # call __blk_next
    mov [rbp - 616], rax # store tag L32
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 272], r10 # spill L32 to slot
    mov r11, [rbp - 272] # reload L32 from spill slot
    mov r10, r11 # assign L29
    mov r11, [rbp - 616] # tag L32 from tag-slot
    mov [rbp - 592], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    jmp .Lb05c_hexa_arena_alloc_bb18 # branch
.Lb05c_hexa_arena_alloc_bb20:
    mov rsi, [rbp - 248] # reload L29 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 592] # tag L29 from tag-slot
    mov rcx, [rbp - 160] # reload L18 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 504] # tag L18 from tag-slot
    call __blk_set_next # call __blk_set_next
    mov [rbp - 624], rax # store tag L33
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 280], r10 # spill L33 to slot
    jmp .Lb05c_hexa_arena_alloc_bb15 # branch
    add rsp, 656 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_arena_mark
.hidden hexa_arena_mark
    .p2align 4
hexa_arena_mark:
    .loc 1 452 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 48 # prologue: alloc spill frame
.Lb05c_hexa_arena_mark_bb0:
    mov r10, [rip+g1] # load global value: g1
    mov rsi, [rip+g1] # load global value: g1
    mov rsi, rsi # hv arg payload
    mov rdi, [rip+g1+8] # tag g1 from global slot+8
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov rbx, rdx # binop ==: capture bool payload
    mov [rbp - 56], rax # store tag L0
    test rbx, rbx # br_cond test
    jz .Lb05c_hexa_arena_mark_bb2 # jump-if-zero -> else
    jmp .Lb05c_hexa_arena_mark_bb1 # jump -> then
.Lb05c_hexa_arena_mark_bb1:
    mov r10, 0 # hv payload
    mov r11, 0 # hv payload
    mov r13, r10 # leaf: payload → dst L2
    mov [rbp - 72], r11 # store tag L2
    mov rdx, r13 # hv arg payload
    mov rax, [rbp - 72] # tag L2 from tag-slot
    add rsp, 48 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_hexa_arena_mark_bb2:
    mov rsi, [rip+g1] # load global value: g1
    mov rsi, rsi # hv arg payload
    mov rdi, [rip+g1+8] # tag g1 from global slot+8
    call __blk_used # call __blk_used
    mov [rbp - 80], rax # store tag L3
    mov r14, rdx # hv: unbox user-call result payload
    mov r10, r14 # hv payload
    mov r11, [rip+g1] # load global value: g1
    mov r11, r11 # hv payload
    mov r15, r10 # leaf: payload → dst L4
    mov [rbp - 88], r11 # store tag L4
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
.globl hexa_arena_rewind
.hidden hexa_arena_rewind
    .p2align 4
hexa_arena_rewind:
    .loc 1 458 0
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
.Lb05c_hexa_arena_rewind_bb0:
    mov r12, [rbp - 144] # tag L0 from tag-slot
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 152], r11 # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 152] # tag L1 from tag-slot
    mov [rbp - 160], r11 # store tag L2
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r14, r10 # leaf: payload → dst L3
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 168], r11 # store tag L3
    mov r15, r14 # assign L4
    mov r11, [rbp - 168] # tag L3 from tag-slot
    mov [rbp - 176], r11 # store tag L4
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 160] # tag L2 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov r10, rdx # binop ==: capture bool payload
    mov [rbp - 184], rax # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    test r10, r10 # br_cond test
    jz .Lb05c_hexa_arena_rewind_bb2 # jump-if-zero -> else
    jmp .Lb05c_hexa_arena_rewind_bb1 # jump -> then
.Lb05c_hexa_arena_rewind_bb1:
    mov r10, [rip+g0] # load global value: g0
    mov rsi, [rip+g0] # load global value: g0
    mov rsi, rsi # hv arg payload
    mov rdi, [rip+g0+8] # tag g0 from global slot+8
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 200], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    test r10, r10 # br_cond test
    jz .Lb05c_hexa_arena_rewind_bb4 # jump-if-zero -> else
    jmp .Lb05c_hexa_arena_rewind_bb3 # jump -> then
.Lb05c_hexa_arena_rewind_bb2:
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 160] # tag L2 from tag-slot
    mov rcx, r15 # hv arg payload
    mov rdx, [rbp - 176] # tag L4 from tag-slot
    call __blk_set_used # call __blk_set_used
    mov [rbp - 224], rax # store tag L10
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 96], r10 # spill L10 to slot
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 160] # tag L2 from tag-slot
    call __blk_next # call __blk_next
    mov [rbp - 232], rax # store tag L11
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 232] # tag L11 from tag-slot
    mov [rbp - 240], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    jmp .Lb05c_hexa_arena_rewind_bb5 # branch
.Lb05c_hexa_arena_rewind_bb3:
    mov rsi, [rip+g0] # load global value: g0
    mov rsi, rsi # hv arg payload
    mov rdi, [rip+g0+8] # tag g0 from global slot+8
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call __blk_set_used # call __blk_set_used
    mov [rbp - 216], rax # store tag L9
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rip+g0] # load global value: g0
    mov r12, r10 # assign L1
    mov r11, [rip+g0+8] # tag g0 from global slot+8
    mov [rbp - 152], r11 # store tag L1
    mov [rip+g1], r12 # global write: g1
    mov r11, [rbp - 152] # global tag: reload g1 tag-slot
    mov [rip+g1+8], r11 # global tag write: g1+8
    jmp .Lb05c_hexa_arena_rewind_bb4 # branch
.Lb05c_hexa_arena_rewind_bb4:
    add rsp, 224 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_hexa_arena_rewind_bb5:
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 240] # tag L12 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r10, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 248], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 120] # reload L13 from spill slot
    test r10, r10 # br_cond test
    jz .Lb05c_hexa_arena_rewind_bb7 # jump-if-zero -> else
    jmp .Lb05c_hexa_arena_rewind_bb6 # jump -> then
.Lb05c_hexa_arena_rewind_bb6:
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 240] # tag L12 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call __blk_set_used # call __blk_set_used
    mov [rbp - 256], rax # store tag L14
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 128], r10 # spill L14 to slot
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 240] # tag L12 from tag-slot
    call __blk_next # call __blk_next
    mov [rbp - 264], rax # store tag L15
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, [rbp - 136] # reload L15 from spill slot
    mov r10, r11 # assign L12
    mov r11, [rbp - 264] # tag L15 from tag-slot
    mov [rbp - 240], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    jmp .Lb05c_hexa_arena_rewind_bb5 # branch
.Lb05c_hexa_arena_rewind_bb7:
    mov r12, r13 # assign L1
    mov r11, [rbp - 160] # tag L2 from tag-slot
    mov [rbp - 152], r11 # store tag L1
    mov [rip+g1], r12 # global write: g1
    mov r11, [rbp - 152] # global tag: reload g1 tag-slot
    mov [rip+g1+8], r11 # global tag write: g1+8
    add rsp, 224 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_arena_reset
.hidden hexa_arena_reset
    .p2align 4
hexa_arena_reset:
    .loc 1 477 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 64 # prologue: alloc spill frame
.Lb05c_hexa_arena_reset_bb0:
    mov r10, [rip+g0] # load global value: g0
    mov rsi, [rip+g0] # load global value: g0
    mov rsi, rsi # hv arg payload
    mov rdi, [rip+g0+8] # tag g0 from global slot+8
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop ==: tag-dispatch hexa_eq
    mov rbx, rdx # binop ==: capture bool payload
    mov [rbp - 64], rax # store tag L0
    test rbx, rbx # br_cond test
    jz .Lb05c_hexa_arena_reset_bb2 # jump-if-zero -> else
    jmp .Lb05c_hexa_arena_reset_bb1 # jump -> then
.Lb05c_hexa_arena_reset_bb1:
    add rsp, 64 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.Lb05c_hexa_arena_reset_bb2:
    mov r10, [rip+g0] # load global value: g0
    mov r13, r10 # assign L2
    mov r11, [rip+g0+8] # tag g0 from global slot+8
    mov [rbp - 80], r11 # store tag L2
    jmp .Lb05c_hexa_arena_reset_bb3 # branch
.Lb05c_hexa_arena_reset_bb3:
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 80] # tag L2 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_eq # binop !=: tag-dispatch hexa_eq
    mov rdi, rax # binop !=: eq.tag → truthy arg lo
    mov rsi, rdx # binop !=: eq.payload → truthy arg hi
    call hexa_truthy # binop !=: truthy(eq) → rax
    xor rax, 1 # binop !=: !truthy
    mov r14, rax # binop !=: capture bool payload
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 88], r11 # store tag L3
    test r14, r14 # br_cond test
    jz .Lb05c_hexa_arena_reset_bb5 # jump-if-zero -> else
    jmp .Lb05c_hexa_arena_reset_bb4 # jump -> then
.Lb05c_hexa_arena_reset_bb4:
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 80] # tag L2 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call __blk_set_used # call __blk_set_used
    mov [rbp - 96], rax # store tag L4
    mov r15, rdx # hv: unbox user-call result payload
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 80] # tag L2 from tag-slot
    call __blk_next # call __blk_next
    mov [rbp - 104], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    mov r13, r10 # assign L2
    mov r11, [rbp - 104] # tag L5 from tag-slot
    mov [rbp - 80], r11 # store tag L2
    jmp .Lb05c_hexa_arena_reset_bb3 # branch
.Lb05c_hexa_arena_reset_bb5:
    mov r10, [rip+g0] # load global value: g0
    mov r12, r10 # assign L1
    mov r11, [rip+g0+8] # tag g0 from global slot+8
    mov [rbp - 72], r11 # store tag L1
    mov [rip+g1], r12 # global write: g1
    mov r11, [rbp - 72] # global tag: reload g1 tag-slot
    mov [rip+g1+8], r11 # global tag write: g1+8
    add rsp, 64 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_ptr_alloc
.hidden hexa_ptr_alloc
    .p2align 4
hexa_ptr_alloc:
    .loc 1 490 0
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
.Lb05c_hexa_ptr_alloc_bb0:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 56] # tag L0 from tag-slot
    call hexa_arena_alloc # call hexa_arena_alloc
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
.globl hexa_ptr_free
.hidden hexa_ptr_free
    .p2align 4
hexa_ptr_free:
    .loc 1 494 0
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
    mov [rbp - 64], rdx # store tag L1
    mov r12, rcx # ingress param payload
.Lb05c_hexa_ptr_free_bb0:
    mov rdx, 0 # hv arg payload
    mov rax, 0 # tag default = TAG_INT
    add rsp, 16 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_ptr_write_byte
.hidden hexa_ptr_write_byte
    .p2align 4
hexa_ptr_write_byte:
    .loc 1 499 0
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
    mov [rbp - 64], rdx # store tag L1
    mov r12, rcx # ingress param payload
    mov [rbp - 72], r8 # store tag L2
    mov r13, r9 # ingress param payload
.Lb05c_hexa_ptr_write_byte_bb0:
    mov r10, rbx # hv payload
    mov r11, r12 # hv payload
    mov rsi, r13 # hv payload
    add r10, r11 # __hx_ptr_store8: addr = ptr + off
    mov byte ptr [r10], sil # __hx_ptr_store8: *(u8*)addr = (u8)val
    mov r10, rbx # hv payload
    mov r14, r10 # leaf: payload → dst L3
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 80], r11 # store tag L3
    mov rdx, r13 # hv arg payload
    mov rax, [rbp - 72] # tag L2 from tag-slot
    add rsp, 32 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_ptr_read_byte
.hidden hexa_ptr_read_byte
    .p2align 4
hexa_ptr_read_byte:
    .loc 1 504 0
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
    mov [rbp - 64], rdx # store tag L1
    mov r12, rcx # ingress param payload
.Lb05c_hexa_ptr_read_byte_bb0:
    mov r10, rbx # hv payload
    mov r11, r12 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r13, r10 # leaf: payload → dst L2
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 72], r11 # store tag L2
    mov rdx, r13 # hv arg payload
    mov rax, [rbp - 72] # tag L2 from tag-slot
    add rsp, 32 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_ptr_write_64
.hidden hexa_ptr_write_64
    .p2align 4
hexa_ptr_write_64:
    .loc 1 508 0
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
    mov [rbp - 64], rdx # store tag L1
    mov r12, rcx # ingress param payload
    mov [rbp - 72], r8 # store tag L2
    mov r13, r9 # ingress param payload
.Lb05c_hexa_ptr_write_64_bb0:
    mov r10, rbx # hv payload
    mov r11, r12 # hv payload
    mov rsi, r13 # hv payload
    add r10, r11 # __hx_ptr_store64: addr = ptr + off
    mov qword ptr [r10], rsi # __hx_ptr_store64: *(addr) = val
    mov r10, rbx # hv payload
    mov r14, r10 # leaf: payload → dst L3
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 80], r11 # store tag L3
    mov rdx, r13 # hv arg payload
    mov rax, [rbp - 72] # tag L2 from tag-slot
    add rsp, 32 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl hexa_ptr_read_64
.hidden hexa_ptr_read_64
    .p2align 4
hexa_ptr_read_64:
    .loc 1 513 0
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
    mov [rbp - 64], rdx # store tag L1
    mov r12, rcx # ingress param payload
.Lb05c_hexa_ptr_read_64_bb0:
    mov r10, rbx # hv payload
    mov r11, r12 # hv payload
    add r10, r11 # __hx_ptr_load64: addr = ptr + off
    mov r10, qword ptr [r10] # __hx_ptr_load64: r10 = *(addr)
    mov r13, r10 # leaf: payload → dst L2
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 72], r11 # store tag L2
    mov rdx, r13 # hv arg payload
    mov rax, [rbp - 72] # tag L2 from tag-slot
    add rsp, 32 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
    .p2align 4
.section .rodata
.LCstr0:
    .byte 0x2f, 0x64, 0x65, 0x76, 0x2f, 0x75, 0x72, 0x61, 0x6e, 0x64, 0x6f, 0x6d, 0x00
.section .data
    .p2align 3
g0:
    .quad 0
    .quad 0
    .p2align 3
g1:
    .quad 0
    .quad 0
    .p2align 3
g2:
    .quad 0
    .quad 0
    .p2align 3
g3:
    .quad 0
    .quad 0
.section .hexa.cap,"",@progbits
_hexa_cap_manifest:
.section .hexa.abi,"",@progbits
_hexa_abi_stamp:
    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

.section .note.GNU-stack,"",@progbits
