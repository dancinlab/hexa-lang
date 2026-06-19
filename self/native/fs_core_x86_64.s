// fs_core_x86_64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B FS-R1 write-half).
// GENERATED: tool/regen_fs_core_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=x86_64-linux-gnu -o fs_core_x86_64.s stdlib/runtime/fs_write_core.hexa.
//   Provides the FS-core WRITE-half (fs_write_all_native = open(O_WRONLY|
//   O_CREAT|O_TRUNC,0644)+write+close; fs_append_all_native = O_APPEND) as
//   native syscall bodies over the leaf intrinsics __hx_syscall6 /
//   __hx_target_os / __hx_target_arch (lowered inline). SELF-CONTAINED — no
//   external .globl (the per-target syscall numbers + open flags are inlined),
//   so NO clash with the alloc seed`s syscall surface. These intrinsics are
//   gen2-native-only (hexat C-transpile cannot lower them), so the bodies enter
//   the shipped runtime.a ONLY via this seed.
//   ABI: ELF, fs_*_all_native no underscore.
//   Lets stage_resolve_runtime_a define HEXA_RT_FS_NATIVE + ar this .o into
//   runtime.a so rt_write_bytes / rt_write_bytes_append delegate to it.
# hexa-lang emit pass — target=x86_64-linux-gnu
# source: /home/aiden/fs-lane/stdlib/runtime/fs_write_core.hexa
.intel_syntax noprefix
.file 1 "stdlib/runtime/fs_write_core.hexa"
.text
.globl _fsw_is_linux
.hidden _fsw_is_linux
    .p2align 4
_fsw_is_linux:
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
.L1acd__fsw_is_linux_bb0:
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
.globl _fsw_is_arm64
.hidden _fsw_is_arm64
    .p2align 4
_fsw_is_arm64:
    .loc 1 43 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 16 # prologue: alloc spill frame
.L1acd__fsw_is_arm64_bb0:
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
.globl _fsw_sc3
.hidden _fsw_sc3
    .p2align 4
_fsw_sc3:
    .loc 1 45 0
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
.L1acd__fsw_sc3_bb0:
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
.globl _fsw_sc1
.hidden _fsw_sc1
    .p2align 4
_fsw_sc1:
    .loc 1 46 0
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
.L1acd__fsw_sc1_bb0:
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
.globl _FSW_LINUX_WRITE
.hidden _FSW_LINUX_WRITE
    .p2align 4
_FSW_LINUX_WRITE:
    .loc 1 49 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.L1acd__FSW_LINUX_WRITE_bb0:
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
.globl _FSW_LINUX_OPEN
.hidden _FSW_LINUX_OPEN
    .p2align 4
_FSW_LINUX_OPEN:
    .loc 1 50 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.L1acd__FSW_LINUX_OPEN_bb0:
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
.globl _FSW_LINUX_CLOSE
.hidden _FSW_LINUX_CLOSE
    .p2align 4
_FSW_LINUX_CLOSE:
    .loc 1 51 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.L1acd__FSW_LINUX_CLOSE_bb0:
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
.globl _FSW_DARWIN_WRITE
.hidden _FSW_DARWIN_WRITE
    .p2align 4
_FSW_DARWIN_WRITE:
    .loc 1 53 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.L1acd__FSW_DARWIN_WRITE_bb0:
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
.globl _FSW_DARWIN_OPEN
.hidden _FSW_DARWIN_OPEN
    .p2align 4
_FSW_DARWIN_OPEN:
    .loc 1 54 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.L1acd__FSW_DARWIN_OPEN_bb0:
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
.globl _FSW_DARWIN_CLOSE
.hidden _FSW_DARWIN_CLOSE
    .p2align 4
_FSW_DARWIN_CLOSE:
    .loc 1 55 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.L1acd__FSW_DARWIN_CLOSE_bb0:
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
.globl _FSW_O_WRONLY
.hidden _FSW_O_WRONLY
    .p2align 4
_FSW_O_WRONLY:
    .loc 1 58 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.L1acd__FSW_O_WRONLY_bb0:
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
.globl _FSW_O_CREAT_LINUX
.hidden _FSW_O_CREAT_LINUX
    .p2align 4
_FSW_O_CREAT_LINUX:
    .loc 1 59 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.L1acd__FSW_O_CREAT_LINUX_bb0:
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
.globl _FSW_O_TRUNC_LINUX
.hidden _FSW_O_TRUNC_LINUX
    .p2align 4
_FSW_O_TRUNC_LINUX:
    .loc 1 60 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.L1acd__FSW_O_TRUNC_LINUX_bb0:
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
.globl _FSW_O_APPEND_LINUX
.hidden _FSW_O_APPEND_LINUX
    .p2align 4
_FSW_O_APPEND_LINUX:
    .loc 1 61 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.L1acd__FSW_O_APPEND_LINUX_bb0:
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
.globl _FSW_O_CREAT_DARWIN
.hidden _FSW_O_CREAT_DARWIN
    .p2align 4
_FSW_O_CREAT_DARWIN:
    .loc 1 62 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.L1acd__FSW_O_CREAT_DARWIN_bb0:
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
.globl _FSW_O_TRUNC_DARWIN
.hidden _FSW_O_TRUNC_DARWIN
    .p2align 4
_FSW_O_TRUNC_DARWIN:
    .loc 1 63 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.L1acd__FSW_O_TRUNC_DARWIN_bb0:
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
.globl _FSW_O_APPEND_DARWIN
.hidden _FSW_O_APPEND_DARWIN
    .p2align 4
_FSW_O_APPEND_DARWIN:
    .loc 1 64 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
.L1acd__FSW_O_APPEND_DARWIN_bb0:
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
.globl _fsw_open
.hidden _fsw_open
    .p2align 4
_fsw_open:
    .loc 1 66 0
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
.L1acd__fsw_open_bb0:
    call _fsw_is_linux # call _fsw_is_linux
    mov [rbp - 112], rax # store tag L3
    mov r14, rdx # hv: unbox user-call result payload
    test r14, r14 # br_cond test
    jz .L1acd__fsw_open_bb2 # jump-if-zero -> else
    jmp .L1acd__fsw_open_bb1 # jump -> then
.L1acd__fsw_open_bb1:
    call _FSW_LINUX_OPEN # call _FSW_LINUX_OPEN
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
    call _fsw_sc3 # call _fsw_sc3
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
.L1acd__fsw_open_bb2:
    call _FSW_DARWIN_OPEN # call _FSW_DARWIN_OPEN
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
    call _fsw_sc3 # call _fsw_sc3
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
.globl _fsw_write
.hidden _fsw_write
    .p2align 4
_fsw_write:
    .loc 1 70 0
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
.L1acd__fsw_write_bb0:
    call _fsw_is_linux # call _fsw_is_linux
    mov [rbp - 112], rax # store tag L3
    mov r14, rdx # hv: unbox user-call result payload
    test r14, r14 # br_cond test
    jz .L1acd__fsw_write_bb2 # jump-if-zero -> else
    jmp .L1acd__fsw_write_bb1 # jump -> then
.L1acd__fsw_write_bb1:
    call _FSW_LINUX_WRITE # call _FSW_LINUX_WRITE
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
    call _fsw_sc3 # call _fsw_sc3
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
.L1acd__fsw_write_bb2:
    call _FSW_DARWIN_WRITE # call _FSW_DARWIN_WRITE
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
    call _fsw_sc3 # call _fsw_sc3
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
.globl _fsw_close
.hidden _fsw_close
    .p2align 4
_fsw_close:
    .loc 1 74 0
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
.L1acd__fsw_close_bb0:
    call _fsw_is_linux # call _fsw_is_linux
    mov [rbp - 80], rax # store tag L1
    mov r12, rdx # hv: unbox user-call result payload
    test r12, r12 # br_cond test
    jz .L1acd__fsw_close_bb2 # jump-if-zero -> else
    jmp .L1acd__fsw_close_bb1 # jump -> then
.L1acd__fsw_close_bb1:
    call _FSW_LINUX_CLOSE # call _FSW_LINUX_CLOSE
    mov [rbp - 96], rax # store tag L3
    mov r14, rdx # hv: unbox user-call result payload
    mov rsi, r14 # hv arg payload
    mov rdi, [rbp - 96] # tag L3 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 72] # tag L0 from tag-slot
    call _fsw_sc1 # call _fsw_sc1
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
.L1acd__fsw_close_bb2:
    call _FSW_DARWIN_CLOSE # call _FSW_DARWIN_CLOSE
    mov [rbp - 112], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    mov rsi, [rbp - 56] # reload L5 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 112] # tag L5 from tag-slot
    mov rcx, rbx # hv arg payload
    mov rdx, [rbp - 72] # tag L0 from tag-slot
    call _fsw_sc1 # call _fsw_sc1
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
.globl fs_write_all_native
.hidden fs_write_all_native
    .p2align 4
fs_write_all_native:
    .loc 1 83 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 480 # prologue: alloc spill frame
    mov [rbp - 272], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 280], rdx # store tag L1
    mov r12, rcx # ingress param payload
    mov [rbp - 288], r8 # store tag L2
    mov r13, r9 # ingress param payload
.L1acd_fs_write_all_native_bb0:
    call _FSW_O_WRONLY # call _FSW_O_WRONLY
    mov [rbp - 296], rax # store tag L3
    mov r14, rdx # hv: unbox user-call result payload
    mov r15, r14 # assign L4
    mov r11, [rbp - 296] # tag L3 from tag-slot
    mov [rbp - 304], r11 # store tag L4
    call _fsw_is_linux # call _fsw_is_linux
    mov [rbp - 312], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    test r10, r10 # br_cond test
    jz .L1acd_fs_write_all_native_bb2 # jump-if-zero -> else
    jmp .L1acd_fs_write_all_native_bb1 # jump -> then
.L1acd_fs_write_all_native_bb1:
    call _FSW_O_CREAT_LINUX # call _FSW_O_CREAT_LINUX
    mov [rbp - 328], rax # store tag L7
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 72], r10 # spill L7 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 304] # tag L4 from tag-slot
    mov rcx, [rbp - 72] # reload L7 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 328] # tag L7 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 336], rax # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    call _FSW_O_TRUNC_LINUX # call _FSW_O_TRUNC_LINUX
    mov [rbp - 344], rax # store tag L9
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 336] # tag L8 from tag-slot
    mov rcx, [rbp - 88] # reload L9 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 344] # tag L9 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 352], rax # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov r15, r10 # assign L4
    mov r11, [rbp - 352] # tag L10 from tag-slot
    mov [rbp - 304], r11 # store tag L4
    jmp .L1acd_fs_write_all_native_bb3 # branch
.L1acd_fs_write_all_native_bb2:
    call _FSW_O_CREAT_DARWIN # call _FSW_O_CREAT_DARWIN
    mov [rbp - 360], rax # store tag L11
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 304] # tag L4 from tag-slot
    mov rcx, [rbp - 104] # reload L11 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 360] # tag L11 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 368], rax # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    call _FSW_O_TRUNC_DARWIN # call _FSW_O_TRUNC_DARWIN
    mov [rbp - 376], rax # store tag L13
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 368] # tag L12 from tag-slot
    mov rcx, [rbp - 120] # reload L13 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 376] # tag L13 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 384], rax # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r10, [rbp - 128] # reload L14 from spill slot
    mov r15, r10 # assign L4
    mov r11, [rbp - 384] # tag L14 from tag-slot
    mov [rbp - 304], r11 # store tag L4
    jmp .L1acd_fs_write_all_native_bb3 # branch
.L1acd_fs_write_all_native_bb3:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 272] # tag L0 from tag-slot
    mov rcx, r15 # hv arg payload
    mov rdx, [rbp - 304] # tag L4 from tag-slot
    mov r9, 420 # hv arg payload
    mov r8, 0 # tag default = TAG_INT
    call _fsw_open # call _fsw_open
    mov [rbp - 392], rax # store tag L15
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, [rbp - 136] # reload L15 from spill slot
    mov r10, r11 # assign L16
    mov r11, [rbp - 392] # tag L15 from tag-slot
    mov [rbp - 400], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r10, [rbp - 144] # reload L16 from spill slot
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 400] # tag L16 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 408], rax # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    test r10, r10 # br_cond test
    jz .L1acd_fs_write_all_native_bb5 # jump-if-zero -> else
    jmp .L1acd_fs_write_all_native_bb4 # jump -> then
.L1acd_fs_write_all_native_bb4:
    mov rdx, [rbp - 144] # reload L16 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 400] # tag L16 from tag-slot
    add rsp, 480 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L1acd_fs_write_all_native_bb5:
    mov r10, 0 # assign L19
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 424], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    jmp .L1acd_fs_write_all_native_bb6 # branch
.L1acd_fs_write_all_native_bb6:
    mov r10, [rbp - 168] # reload L19 from spill slot
    mov rsi, [rbp - 168] # reload L19 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 424] # tag L19 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 288] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 432], rax # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, [rbp - 176] # reload L20 from spill slot
    test r10, r10 # br_cond test
    jz .L1acd_fs_write_all_native_bb8 # jump-if-zero -> else
    jmp .L1acd_fs_write_all_native_bb7 # jump -> then
.L1acd_fs_write_all_native_bb7:
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 280] # tag L1 from tag-slot
    mov rcx, [rbp - 168] # reload L19 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 424] # tag L19 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 440], rax # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 288] # tag L2 from tag-slot
    mov rcx, [rbp - 168] # reload L19 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 424] # tag L19 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 448], rax # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 400] # tag L16 from tag-slot
    mov rcx, [rbp - 184] # reload L21 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 440] # tag L21 from tag-slot
    mov r9, [rbp - 192] # reload L22 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 448] # tag L22 from tag-slot
    call _fsw_write # call _fsw_write
    mov [rbp - 456], rax # store tag L23
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 456] # tag L23 from tag-slot
    mov [rbp - 464], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov rsi, [rbp - 208] # reload L24 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 464] # tag L24 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 472], rax # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r10, [rbp - 216] # reload L25 from spill slot
    test r10, r10 # br_cond test
    jz .L1acd_fs_write_all_native_bb10 # jump-if-zero -> else
    jmp .L1acd_fs_write_all_native_bb9 # jump -> then
.L1acd_fs_write_all_native_bb8:
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 400] # tag L16 from tag-slot
    call _fsw_close # call _fsw_close
    mov [rbp - 520], rax # store tag L31
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 264], r10 # spill L31 to slot
    mov rdx, [rbp - 168] # reload L19 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 424] # tag L19 from tag-slot
    add rsp, 480 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L1acd_fs_write_all_native_bb9:
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 400] # tag L16 from tag-slot
    call _fsw_close # call _fsw_close
    mov [rbp - 488], rax # store tag L27
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 232], r10 # spill L27 to slot
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov rsi, [rbp - 208] # reload L24 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 464] # tag L24 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 496], rax # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r10, [rbp - 240] # reload L28 from spill slot
    test r10, r10 # br_cond test
    jz .L1acd_fs_write_all_native_bb12 # jump-if-zero -> else
    jmp .L1acd_fs_write_all_native_bb11 # jump -> then
.L1acd_fs_write_all_native_bb10:
    mov r10, [rbp - 168] # reload L19 from spill slot
    mov r11, [rbp - 208] # reload L24 from spill slot
    mov rsi, [rbp - 168] # reload L19 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 424] # tag L19 from tag-slot
    mov rcx, [rbp - 208] # reload L24 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 464] # tag L24 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 512], rax # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r11, [rbp - 256] # reload L30 from spill slot
    mov r10, r11 # assign L19
    mov r11, [rbp - 512] # tag L30 from tag-slot
    mov [rbp - 424], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    jmp .L1acd_fs_write_all_native_bb6 # branch
.L1acd_fs_write_all_native_bb11:
    mov rdx, [rbp - 208] # reload L24 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 464] # tag L24 from tag-slot
    add rsp, 480 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L1acd_fs_write_all_native_bb12:
    mov rdx, [rbp - 168] # reload L19 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 424] # tag L19 from tag-slot
    add rsp, 480 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.globl fs_append_all_native
.hidden fs_append_all_native
    .p2align 4
fs_append_all_native:
    .loc 1 108 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 480 # prologue: alloc spill frame
    mov [rbp - 272], rdi # store tag L0
    mov rbx, rsi # ingress param payload
    mov [rbp - 280], rdx # store tag L1
    mov r12, rcx # ingress param payload
    mov [rbp - 288], r8 # store tag L2
    mov r13, r9 # ingress param payload
.L1acd_fs_append_all_native_bb0:
    call _FSW_O_WRONLY # call _FSW_O_WRONLY
    mov [rbp - 296], rax # store tag L3
    mov r14, rdx # hv: unbox user-call result payload
    mov r15, r14 # assign L4
    mov r11, [rbp - 296] # tag L3 from tag-slot
    mov [rbp - 304], r11 # store tag L4
    call _fsw_is_linux # call _fsw_is_linux
    mov [rbp - 312], rax # store tag L5
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    test r10, r10 # br_cond test
    jz .L1acd_fs_append_all_native_bb2 # jump-if-zero -> else
    jmp .L1acd_fs_append_all_native_bb1 # jump -> then
.L1acd_fs_append_all_native_bb1:
    call _FSW_O_CREAT_LINUX # call _FSW_O_CREAT_LINUX
    mov [rbp - 328], rax # store tag L7
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 72], r10 # spill L7 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 304] # tag L4 from tag-slot
    mov rcx, [rbp - 72] # reload L7 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 328] # tag L7 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 336], rax # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    call _FSW_O_APPEND_LINUX # call _FSW_O_APPEND_LINUX
    mov [rbp - 344], rax # store tag L9
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 88], r10 # spill L9 to slot
    mov r10, [rbp - 80] # reload L8 from spill slot
    mov r11, [rbp - 88] # reload L9 from spill slot
    mov rsi, [rbp - 80] # reload L8 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 336] # tag L8 from tag-slot
    mov rcx, [rbp - 88] # reload L9 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 344] # tag L9 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 352], rax # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r10, [rbp - 96] # reload L10 from spill slot
    mov r15, r10 # assign L4
    mov r11, [rbp - 352] # tag L10 from tag-slot
    mov [rbp - 304], r11 # store tag L4
    jmp .L1acd_fs_append_all_native_bb3 # branch
.L1acd_fs_append_all_native_bb2:
    call _FSW_O_CREAT_DARWIN # call _FSW_O_CREAT_DARWIN
    mov [rbp - 360], rax # store tag L11
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, [rbp - 104] # reload L11 from spill slot
    mov rsi, r15 # hv arg payload
    mov rdi, [rbp - 304] # tag L4 from tag-slot
    mov rcx, [rbp - 104] # reload L11 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 360] # tag L11 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 368], rax # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    call _FSW_O_APPEND_DARWIN # call _FSW_O_APPEND_DARWIN
    mov [rbp - 376], rax # store tag L13
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 120], r10 # spill L13 to slot
    mov r10, [rbp - 112] # reload L12 from spill slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov rsi, [rbp - 112] # reload L12 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 368] # tag L12 from tag-slot
    mov rcx, [rbp - 120] # reload L13 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 376] # tag L13 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 384], rax # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r10, [rbp - 128] # reload L14 from spill slot
    mov r15, r10 # assign L4
    mov r11, [rbp - 384] # tag L14 from tag-slot
    mov [rbp - 304], r11 # store tag L4
    jmp .L1acd_fs_append_all_native_bb3 # branch
.L1acd_fs_append_all_native_bb3:
    mov rsi, rbx # hv arg payload
    mov rdi, [rbp - 272] # tag L0 from tag-slot
    mov rcx, r15 # hv arg payload
    mov rdx, [rbp - 304] # tag L4 from tag-slot
    mov r9, 420 # hv arg payload
    mov r8, 0 # tag default = TAG_INT
    call _fsw_open # call _fsw_open
    mov [rbp - 392], rax # store tag L15
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, [rbp - 136] # reload L15 from spill slot
    mov r10, r11 # assign L16
    mov r11, [rbp - 392] # tag L15 from tag-slot
    mov [rbp - 400], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r10, [rbp - 144] # reload L16 from spill slot
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 400] # tag L16 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 408], rax # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r10, [rbp - 152] # reload L17 from spill slot
    test r10, r10 # br_cond test
    jz .L1acd_fs_append_all_native_bb5 # jump-if-zero -> else
    jmp .L1acd_fs_append_all_native_bb4 # jump -> then
.L1acd_fs_append_all_native_bb4:
    mov rdx, [rbp - 144] # reload L16 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 400] # tag L16 from tag-slot
    add rsp, 480 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L1acd_fs_append_all_native_bb5:
    mov r10, 0 # assign L19
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 424], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    jmp .L1acd_fs_append_all_native_bb6 # branch
.L1acd_fs_append_all_native_bb6:
    mov r10, [rbp - 168] # reload L19 from spill slot
    mov rsi, [rbp - 168] # reload L19 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 424] # tag L19 from tag-slot
    mov rcx, r13 # hv arg payload
    mov rdx, [rbp - 288] # tag L2 from tag-slot
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 432], rax # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, [rbp - 176] # reload L20 from spill slot
    test r10, r10 # br_cond test
    jz .L1acd_fs_append_all_native_bb8 # jump-if-zero -> else
    jmp .L1acd_fs_append_all_native_bb7 # jump -> then
.L1acd_fs_append_all_native_bb7:
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov rsi, r12 # hv arg payload
    mov rdi, [rbp - 280] # tag L1 from tag-slot
    mov rcx, [rbp - 168] # reload L19 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 424] # tag L19 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 440], rax # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 168] # reload L19 from spill slot
    mov rsi, r13 # hv arg payload
    mov rdi, [rbp - 288] # tag L2 from tag-slot
    mov rcx, [rbp - 168] # reload L19 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 424] # tag L19 from tag-slot
    call hexa_sub # binop -: tag-dispatch hexa_sub
    mov r10, rdx # binop -: capture result payload
    mov [rbp - 448], rax # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 400] # tag L16 from tag-slot
    mov rcx, [rbp - 184] # reload L21 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 440] # tag L21 from tag-slot
    mov r9, [rbp - 192] # reload L22 from spill slot
    mov r9, r9 # hv arg payload
    mov r8, [rbp - 448] # tag L22 from tag-slot
    call _fsw_write # call _fsw_write
    mov [rbp - 456], rax # store tag L23
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, [rbp - 200] # reload L23 from spill slot
    mov r10, r11 # assign L24
    mov r11, [rbp - 456] # tag L23 from tag-slot
    mov [rbp - 464], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov rsi, [rbp - 208] # reload L24 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 464] # tag L24 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_le # binop <=: tag-dispatch hexa_cmp_le
    mov r10, rdx # binop <=: capture bool payload
    mov [rbp - 472], rax # store tag L25
    mov [rbp - 216], r10 # spill L25 to slot
    mov r10, [rbp - 216] # reload L25 from spill slot
    test r10, r10 # br_cond test
    jz .L1acd_fs_append_all_native_bb10 # jump-if-zero -> else
    jmp .L1acd_fs_append_all_native_bb9 # jump -> then
.L1acd_fs_append_all_native_bb8:
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 400] # tag L16 from tag-slot
    call _fsw_close # call _fsw_close
    mov [rbp - 520], rax # store tag L31
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 264], r10 # spill L31 to slot
    mov rdx, [rbp - 168] # reload L19 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 424] # tag L19 from tag-slot
    add rsp, 480 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L1acd_fs_append_all_native_bb9:
    mov rsi, [rbp - 144] # reload L16 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 400] # tag L16 from tag-slot
    call _fsw_close # call _fsw_close
    mov [rbp - 488], rax # store tag L27
    mov r10, rdx # hv: unbox user-call result payload
    mov [rbp - 232], r10 # spill L27 to slot
    mov r10, [rbp - 208] # reload L24 from spill slot
    mov rsi, [rbp - 208] # reload L24 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 464] # tag L24 from tag-slot
    mov rcx, 0 # hv arg payload
    mov rdx, 0 # tag default = TAG_INT
    call hexa_cmp_lt # binop <: tag-dispatch hexa_cmp_lt
    mov r10, rdx # binop <: capture bool payload
    mov [rbp - 496], rax # store tag L28
    mov [rbp - 240], r10 # spill L28 to slot
    mov r10, [rbp - 240] # reload L28 from spill slot
    test r10, r10 # br_cond test
    jz .L1acd_fs_append_all_native_bb12 # jump-if-zero -> else
    jmp .L1acd_fs_append_all_native_bb11 # jump -> then
.L1acd_fs_append_all_native_bb10:
    mov r10, [rbp - 168] # reload L19 from spill slot
    mov r11, [rbp - 208] # reload L24 from spill slot
    mov rsi, [rbp - 168] # reload L19 from spill slot
    mov rsi, rsi # hv arg payload
    mov rdi, [rbp - 424] # tag L19 from tag-slot
    mov rcx, [rbp - 208] # reload L24 from spill slot
    mov rcx, rcx # hv arg payload
    mov rdx, [rbp - 464] # tag L24 from tag-slot
    call hexa_add_slow # binop +: tag-dispatch hexa_add_slow
    mov r10, rdx # binop +: capture result payload
    mov [rbp - 512], rax # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r11, [rbp - 256] # reload L30 from spill slot
    mov r10, r11 # assign L19
    mov r11, [rbp - 512] # tag L30 from tag-slot
    mov [rbp - 424], r11 # store tag L19
    mov [rbp - 168], r10 # spill L19 to slot
    jmp .L1acd_fs_append_all_native_bb6 # branch
.L1acd_fs_append_all_native_bb11:
    mov rdx, [rbp - 208] # reload L24 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 464] # tag L24 from tag-slot
    add rsp, 480 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L1acd_fs_append_all_native_bb12:
    mov rdx, [rbp - 168] # reload L19 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 424] # tag L19 from tag-slot
    add rsp, 480 # epilogue: free spill frame
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
