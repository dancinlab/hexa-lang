// num_float_core_x86_64.s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 NUM-FLOAT — sh-num-float).
// GENERATED: tool/regen_num_float_core_native_s.sh — aprime_cc _drv.hexa --emit=asm
//   --target=x86_64-linux-gnu -o num_float_core_x86_64.s stdlib/runtime/num_float_core.hexa.
//   Provides the num-float parse half (rt_parse_float_native) as a native
//   raw-mem + float body (__hx_ptr_load8 byte scan + integer mantissa fold +
//   __hx_to_double cast + __hx_payload_{fmul,fdiv} Clinger fast-path scale,
//   bit-exact to strtod on the mantissa<=2^53 AND |exp10|<=22 domain; out of
//   domain returns a TAG_VOID sentinel so the C wrapper falls back to strtod).
//   These leaves are gen2-native-only (the hexat C-transpile bootstrap cannot
//   lower them), so the body enters the shipped runtime.a ONLY via this seed.
//   ABI: ELF, rt_parse_float_native no underscore. External: NONE (fully self-contained; float leaves lower inline).
//   Lets stage_resolve_runtime_a define HEXA_RT_NUM_PARSE_FLOAT_NATIVE + ar this
//   .o into runtime.a so __hx_to_double delegates its string→f64 path to native.
# hexa-lang emit pass — target=x86_64-linux-gnu
# source: /home/summer/dancinlab/hexa-lang/stdlib/runtime/num_float_core.hexa
.intel_syntax noprefix
.file 1 "stdlib/runtime/num_float_core.hexa"
.text
.globl rt_parse_float_native
.hidden rt_parse_float_native
    .p2align 4
rt_parse_float_native:
    .loc 1 71 0
    push rbp # prologue: save rbp
    mov rbp, rsp # prologue: set rbp
    push rbx # prologue: save rbx
    push r12 # prologue: save r12
    push r13 # prologue: save r13
    push r14 # prologue: save r14
    push r15 # prologue: save r15
    sub rsp, 8 # prologue: callee-save align pad
    sub rsp, 2848 # prologue: alloc spill frame
    mov [rbp - 1456], rdi # store tag L0
    mov rbx, rsi # ingress param payload
.L40fd_rt_parse_float_native_bb0:
    mov r11, 0 # hv payload
    mov r10, rbx # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r12, r10 # leaf: payload → dst L1
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1464], r11 # store tag L1
    mov r13, r12 # assign L2
    mov r11, [rbp - 1464] # tag L1 from tag-slot
    mov [rbp - 1472], r11 # store tag L2
    mov r14, 0 # assign L3
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1480], r11 # store tag L3
    mov r15, 1 # assign L4
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1488], r11 # store tag L4
    jmp .L40fd_rt_parse_float_native_bb1 # branch
.L40fd_rt_parse_float_native_bb1:
    mov r11, 0 # hv payload
    mov r10, r15 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1496], r11 # store tag L5
    mov [rbp - 56], r10 # spill L5 to slot
    mov r10, [rbp - 56] # reload L5 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb3 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb2 # jump -> then
.L40fd_rt_parse_float_native_bb2:
    mov r10, r13 # hv payload
    mov r11, r14 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1504], r11 # store tag L6
    mov [rbp - 64], r10 # spill L6 to slot
    mov r11, [rbp - 64] # reload L6 from spill slot
    mov r10, r11 # assign L7
    mov r11, [rbp - 1504] # tag L6 from tag-slot
    mov [rbp - 1512], r11 # store tag L7
    mov [rbp - 72], r10 # spill L7 to slot
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    mov r11, 32 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1520], r11 # store tag L8
    mov [rbp - 80], r10 # spill L8 to slot
    mov r11, [rbp - 80] # reload L8 from spill slot
    mov r10, r11 # assign L9
    mov r11, [rbp - 1520] # tag L8 from tag-slot
    mov [rbp - 1528], r11 # store tag L9
    mov [rbp - 88], r10 # spill L9 to slot
    mov r11, [rbp - 72] # reload L7 from spill slot
    mov r11, r11 # hv payload
    mov r10, 8 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1536], r11 # store tag L10
    mov [rbp - 96], r10 # spill L10 to slot
    mov r11, [rbp - 96] # reload L10 from spill slot
    mov r10, r11 # assign L11
    mov r11, [rbp - 1536] # tag L10 from tag-slot
    mov [rbp - 1544], r11 # store tag L11
    mov [rbp - 104], r10 # spill L11 to slot
    mov r11, 14 # hv payload
    mov r10, [rbp - 72] # reload L7 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1552], r11 # store tag L12
    mov [rbp - 112], r10 # spill L12 to slot
    mov r11, [rbp - 112] # reload L12 from spill slot
    mov r10, r11 # assign L13
    mov r11, [rbp - 1552] # tag L12 from tag-slot
    mov [rbp - 1560], r11 # store tag L13
    mov [rbp - 120], r10 # spill L13 to slot
    mov r11, [rbp - 120] # reload L13 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 104] # reload L11 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1568], r11 # store tag L14
    mov [rbp - 128], r10 # spill L14 to slot
    mov r11, [rbp - 128] # reload L14 from spill slot
    mov r10, r11 # assign L15
    mov r11, [rbp - 1568] # tag L14 from tag-slot
    mov [rbp - 1576], r11 # store tag L15
    mov [rbp - 136], r10 # spill L15 to slot
    mov r11, [rbp - 136] # reload L15 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 88] # reload L9 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1584], r11 # store tag L16
    mov [rbp - 144], r10 # spill L16 to slot
    mov r11, [rbp - 144] # reload L16 from spill slot
    mov r10, r11 # assign L17
    mov r11, [rbp - 1584] # tag L16 from tag-slot
    mov [rbp - 1592], r11 # store tag L17
    mov [rbp - 152], r10 # spill L17 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 152] # reload L17 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1600], r11 # store tag L18
    mov [rbp - 160], r10 # spill L18 to slot
    mov r10, [rbp - 160] # reload L18 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb5 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb4 # jump -> then
.L40fd_rt_parse_float_native_bb3:
    mov r10, r13 # hv payload
    mov r11, r14 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1624], r11 # store tag L21
    mov [rbp - 184], r10 # spill L21 to slot
    mov r11, [rbp - 184] # reload L21 from spill slot
    mov r10, r11 # assign L22
    mov r11, [rbp - 1624] # tag L21 from tag-slot
    mov [rbp - 1632], r11 # store tag L22
    mov [rbp - 192], r10 # spill L22 to slot
    mov r10, 0 # assign L23
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1640], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r10, [rbp - 192] # reload L22 from spill slot
    mov r10, r10 # hv payload
    mov r11, 43 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1648], r11 # store tag L24
    mov [rbp - 208], r10 # spill L24 to slot
    mov r10, [rbp - 208] # reload L24 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb8 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb7 # jump -> then
.L40fd_rt_parse_float_native_bb4:
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1616], r11 # store tag L20
    mov [rbp - 176], r10 # spill L20 to slot
    mov r10, [rbp - 176] # reload L20 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 1616] # tag L20 from tag-slot
    mov [rbp - 1480], r11 # store tag L3
    jmp .L40fd_rt_parse_float_native_bb6 # branch
.L40fd_rt_parse_float_native_bb5:
    mov r15, 0 # assign L4
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1488], r11 # store tag L4
    jmp .L40fd_rt_parse_float_native_bb6 # branch
.L40fd_rt_parse_float_native_bb6:
    jmp .L40fd_rt_parse_float_native_bb1 # branch
.L40fd_rt_parse_float_native_bb7:
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1664], r11 # store tag L26
    mov [rbp - 224], r10 # spill L26 to slot
    mov r10, [rbp - 224] # reload L26 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 1664] # tag L26 from tag-slot
    mov [rbp - 1480], r11 # store tag L3
    jmp .L40fd_rt_parse_float_native_bb11 # branch
.L40fd_rt_parse_float_native_bb8:
    mov r10, [rbp - 192] # reload L22 from spill slot
    mov r10, r10 # hv payload
    mov r11, 45 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1672], r11 # store tag L27
    mov [rbp - 232], r10 # spill L27 to slot
    mov r10, [rbp - 232] # reload L27 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb10 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb9 # jump -> then
.L40fd_rt_parse_float_native_bb9:
    mov r10, 1 # assign L23
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1640], r11 # store tag L23
    mov [rbp - 200], r10 # spill L23 to slot
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1688], r11 # store tag L29
    mov [rbp - 248], r10 # spill L29 to slot
    mov r10, [rbp - 248] # reload L29 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 1688] # tag L29 from tag-slot
    mov [rbp - 1480], r11 # store tag L3
    jmp .L40fd_rt_parse_float_native_bb10 # branch
.L40fd_rt_parse_float_native_bb10:
    jmp .L40fd_rt_parse_float_native_bb11 # branch
.L40fd_rt_parse_float_native_bb11:
    mov r10, 0 # assign L30
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1696], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    mov r10, 0 # assign L31
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1704], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov r10, 0 # assign L32
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1712], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    mov r10, 0 # assign L33
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1720], r11 # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r10, 0 # assign L34
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1728], r11 # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    mov r10, 1 # assign L35
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1736], r11 # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    jmp .L40fd_rt_parse_float_native_bb12 # branch
.L40fd_rt_parse_float_native_bb12:
    mov r11, 0 # hv payload
    mov r10, [rbp - 296] # reload L35 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1744], r11 # store tag L36
    mov [rbp - 304], r10 # spill L36 to slot
    mov r10, [rbp - 304] # reload L36 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb14 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb13 # jump -> then
.L40fd_rt_parse_float_native_bb13:
    mov r10, r13 # hv payload
    mov r11, r14 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1752], r11 # store tag L37
    mov [rbp - 312], r10 # spill L37 to slot
    mov r11, [rbp - 312] # reload L37 from spill slot
    mov r10, r11 # assign L38
    mov r11, [rbp - 1752] # tag L37 from tag-slot
    mov [rbp - 1760], r11 # store tag L38
    mov [rbp - 320], r10 # spill L38 to slot
    mov r11, [rbp - 320] # reload L38 from spill slot
    mov r11, r11 # hv payload
    mov r10, 47 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1768], r11 # store tag L39
    mov [rbp - 328], r10 # spill L39 to slot
    mov r11, [rbp - 328] # reload L39 from spill slot
    mov r10, r11 # assign L40
    mov r11, [rbp - 1768] # tag L39 from tag-slot
    mov [rbp - 1776], r11 # store tag L40
    mov [rbp - 336], r10 # spill L40 to slot
    mov r11, 58 # hv payload
    mov r10, [rbp - 320] # reload L38 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1784], r11 # store tag L41
    mov [rbp - 344], r10 # spill L41 to slot
    mov r11, [rbp - 344] # reload L41 from spill slot
    mov r10, r11 # assign L42
    mov r11, [rbp - 1784] # tag L41 from tag-slot
    mov [rbp - 1792], r11 # store tag L42
    mov [rbp - 352], r10 # spill L42 to slot
    mov r11, [rbp - 352] # reload L42 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 336] # reload L40 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1800], r11 # store tag L43
    mov [rbp - 360], r10 # spill L43 to slot
    mov r11, [rbp - 360] # reload L43 from spill slot
    mov r10, r11 # assign L44
    mov r11, [rbp - 1800] # tag L43 from tag-slot
    mov [rbp - 1808], r11 # store tag L44
    mov [rbp - 368], r10 # spill L44 to slot
    mov r10, [rbp - 320] # reload L38 from spill slot
    mov r10, r10 # hv payload
    mov r11, 46 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1816], r11 # store tag L45
    mov [rbp - 376], r10 # spill L45 to slot
    mov r11, [rbp - 376] # reload L45 from spill slot
    mov r10, r11 # assign L46
    mov r11, [rbp - 1816] # tag L45 from tag-slot
    mov [rbp - 1824], r11 # store tag L46
    mov [rbp - 384], r10 # spill L46 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 368] # reload L44 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1832], r11 # store tag L47
    mov [rbp - 392], r10 # spill L47 to slot
    mov r10, [rbp - 392] # reload L47 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb16 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb15 # jump -> then
.L40fd_rt_parse_float_native_bb14:
    mov r10, r13 # hv payload
    mov r11, r14 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2000], r11 # store tag L68
    mov [rbp - 560], r10 # spill L68 to slot
    mov r11, [rbp - 560] # reload L68 from spill slot
    mov r10, r11 # assign L69
    mov r11, [rbp - 2000] # tag L68 from tag-slot
    mov [rbp - 2008], r11 # store tag L69
    mov [rbp - 568], r10 # spill L69 to slot
    mov r10, [rbp - 568] # reload L69 from spill slot
    mov r10, r10 # hv payload
    mov r11, 101 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2016], r11 # store tag L70
    mov [rbp - 576], r10 # spill L70 to slot
    mov r11, [rbp - 576] # reload L70 from spill slot
    mov r10, r11 # assign L71
    mov r11, [rbp - 2016] # tag L70 from tag-slot
    mov [rbp - 2024], r11 # store tag L71
    mov [rbp - 584], r10 # spill L71 to slot
    mov r10, [rbp - 568] # reload L69 from spill slot
    mov r10, r10 # hv payload
    mov r11, 69 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2032], r11 # store tag L72
    mov [rbp - 592], r10 # spill L72 to slot
    mov r11, [rbp - 592] # reload L72 from spill slot
    mov r10, r11 # assign L73
    mov r11, [rbp - 2032] # tag L72 from tag-slot
    mov [rbp - 2040], r11 # store tag L73
    mov [rbp - 600], r10 # spill L73 to slot
    mov r11, [rbp - 600] # reload L73 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 584] # reload L71 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2048], r11 # store tag L74
    mov [rbp - 608], r10 # spill L74 to slot
    mov r11, [rbp - 608] # reload L74 from spill slot
    mov r10, r11 # assign L75
    mov r11, [rbp - 2048] # tag L74 from tag-slot
    mov [rbp - 2056], r11 # store tag L75
    mov [rbp - 616], r10 # spill L75 to slot
    mov r10, 0 # assign L76
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2064], r11 # store tag L76
    mov [rbp - 624], r10 # spill L76 to slot
    mov r10, 0 # assign L77
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2072], r11 # store tag L77
    mov [rbp - 632], r10 # spill L77 to slot
    mov r10, 0 # assign L78
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2080], r11 # store tag L78
    mov [rbp - 640], r10 # spill L78 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 616] # reload L75 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2088], r11 # store tag L79
    mov [rbp - 648], r10 # spill L79 to slot
    mov r10, [rbp - 648] # reload L79 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb30 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb29 # jump -> then
.L40fd_rt_parse_float_native_bb15:
    mov r11, 48 # hv payload
    mov r10, [rbp - 320] # reload L38 from spill slot
    mov r10, r10 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1848], r11 # store tag L49
    mov [rbp - 408], r10 # spill L49 to slot
    mov r11, [rbp - 408] # reload L49 from spill slot
    mov r10, r11 # assign L50
    mov r11, [rbp - 1848] # tag L49 from tag-slot
    mov [rbp - 1856], r11 # store tag L50
    mov [rbp - 416], r10 # spill L50 to slot
    mov r11, [rbp - 256] # reload L30 from spill slot
    mov r11, r11 # hv payload
    mov r10, 900719925474099 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1864], r11 # store tag L51
    mov [rbp - 424], r10 # spill L51 to slot
    mov r11, [rbp - 424] # reload L51 from spill slot
    mov r10, r11 # assign L52
    mov r11, [rbp - 1864] # tag L51 from tag-slot
    mov [rbp - 1872], r11 # store tag L52
    mov [rbp - 432], r10 # spill L52 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 432] # reload L52 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1880], r11 # store tag L53
    mov [rbp - 440], r10 # spill L53 to slot
    mov r10, [rbp - 440] # reload L53 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb18 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb17 # jump -> then
.L40fd_rt_parse_float_native_bb16:
    mov r11, 0 # hv payload
    mov r10, [rbp - 384] # reload L46 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1960], r11 # store tag L63
    mov [rbp - 520], r10 # spill L63 to slot
    mov r10, [rbp - 520] # reload L63 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb23 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb22 # jump -> then
.L40fd_rt_parse_float_native_bb17:
    mov r10, 1 # assign L34
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1728], r11 # store tag L34
    mov [rbp - 288], r10 # spill L34 to slot
    jmp .L40fd_rt_parse_float_native_bb19 # branch
.L40fd_rt_parse_float_native_bb18:
    mov r11, 10 # hv payload
    mov r10, [rbp - 256] # reload L30 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1896], r11 # store tag L55
    mov [rbp - 456], r10 # spill L55 to slot
    mov r11, [rbp - 456] # reload L55 from spill slot
    mov r10, r11 # assign L56
    mov r11, [rbp - 1896] # tag L55 from tag-slot
    mov [rbp - 1904], r11 # store tag L56
    mov [rbp - 464], r10 # spill L56 to slot
    mov r11, [rbp - 416] # reload L50 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 464] # reload L56 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1912], r11 # store tag L57
    mov [rbp - 472], r10 # spill L57 to slot
    mov r11, [rbp - 472] # reload L57 from spill slot
    mov r10, r11 # assign L30
    mov r11, [rbp - 1912] # tag L57 from tag-slot
    mov [rbp - 1696], r11 # store tag L30
    mov [rbp - 256], r10 # spill L30 to slot
    jmp .L40fd_rt_parse_float_native_bb19 # branch
.L40fd_rt_parse_float_native_bb19:
    mov r11, 1 # hv payload
    mov r10, [rbp - 264] # reload L31 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1920], r11 # store tag L58
    mov [rbp - 480], r10 # spill L58 to slot
    mov r11, [rbp - 480] # reload L58 from spill slot
    mov r10, r11 # assign L31
    mov r11, [rbp - 1920] # tag L58 from tag-slot
    mov [rbp - 1704], r11 # store tag L31
    mov [rbp - 264], r10 # spill L31 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 280] # reload L33 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1928], r11 # store tag L59
    mov [rbp - 488], r10 # spill L59 to slot
    mov r10, [rbp - 488] # reload L59 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb21 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb20 # jump -> then
.L40fd_rt_parse_float_native_bb20:
    mov r11, 1 # hv payload
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov r10, r10 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1944], r11 # store tag L61
    mov [rbp - 504], r10 # spill L61 to slot
    mov r11, [rbp - 504] # reload L61 from spill slot
    mov r10, r11 # assign L32
    mov r11, [rbp - 1944] # tag L61 from tag-slot
    mov [rbp - 1712], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    jmp .L40fd_rt_parse_float_native_bb21 # branch
.L40fd_rt_parse_float_native_bb21:
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1952], r11 # store tag L62
    mov [rbp - 512], r10 # spill L62 to slot
    mov r10, [rbp - 512] # reload L62 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 1952] # tag L62 from tag-slot
    mov [rbp - 1480], r11 # store tag L3
    jmp .L40fd_rt_parse_float_native_bb28 # branch
.L40fd_rt_parse_float_native_bb22:
    mov r11, 0 # hv payload
    mov r10, [rbp - 280] # reload L33 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 1976], r11 # store tag L65
    mov [rbp - 536], r10 # spill L65 to slot
    mov r10, [rbp - 536] # reload L65 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb25 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb24 # jump -> then
.L40fd_rt_parse_float_native_bb23:
    mov r10, 0 # assign L35
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1736], r11 # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    jmp .L40fd_rt_parse_float_native_bb27 # branch
.L40fd_rt_parse_float_native_bb24:
    mov r10, 0 # assign L35
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1736], r11 # store tag L35
    mov [rbp - 296], r10 # spill L35 to slot
    jmp .L40fd_rt_parse_float_native_bb26 # branch
.L40fd_rt_parse_float_native_bb25:
    mov r10, 1 # assign L33
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 1720], r11 # store tag L33
    mov [rbp - 280], r10 # spill L33 to slot
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 1992], r11 # store tag L67
    mov [rbp - 552], r10 # spill L67 to slot
    mov r10, [rbp - 552] # reload L67 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 1992] # tag L67 from tag-slot
    mov [rbp - 1480], r11 # store tag L3
    jmp .L40fd_rt_parse_float_native_bb26 # branch
.L40fd_rt_parse_float_native_bb26:
    jmp .L40fd_rt_parse_float_native_bb27 # branch
.L40fd_rt_parse_float_native_bb27:
    jmp .L40fd_rt_parse_float_native_bb28 # branch
.L40fd_rt_parse_float_native_bb28:
    jmp .L40fd_rt_parse_float_native_bb12 # branch
.L40fd_rt_parse_float_native_bb29:
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2104], r11 # store tag L81
    mov [rbp - 664], r10 # spill L81 to slot
    mov r10, [rbp - 664] # reload L81 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 2104] # tag L81 from tag-slot
    mov [rbp - 1480], r11 # store tag L3
    mov r10, r13 # hv payload
    mov r11, r14 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2112], r11 # store tag L82
    mov [rbp - 672], r10 # spill L82 to slot
    mov r11, [rbp - 672] # reload L82 from spill slot
    mov r10, r11 # assign L83
    mov r11, [rbp - 2112] # tag L82 from tag-slot
    mov [rbp - 2120], r11 # store tag L83
    mov [rbp - 680], r10 # spill L83 to slot
    mov r10, [rbp - 680] # reload L83 from spill slot
    mov r10, r10 # hv payload
    mov r11, 43 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2128], r11 # store tag L84
    mov [rbp - 688], r10 # spill L84 to slot
    mov r10, [rbp - 688] # reload L84 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb32 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb31 # jump -> then
.L40fd_rt_parse_float_native_bb30:
    mov r11, 0 # hv payload
    mov r10, [rbp - 616] # reload L75 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2352], r11 # store tag L112
    mov [rbp - 912], r10 # spill L112 to slot
    mov r10, [rbp - 912] # reload L112 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb45 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb44 # jump -> then
.L40fd_rt_parse_float_native_bb31:
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2144], r11 # store tag L86
    mov [rbp - 704], r10 # spill L86 to slot
    mov r10, [rbp - 704] # reload L86 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 2144] # tag L86 from tag-slot
    mov [rbp - 1480], r11 # store tag L3
    jmp .L40fd_rt_parse_float_native_bb35 # branch
.L40fd_rt_parse_float_native_bb32:
    mov r10, [rbp - 680] # reload L83 from spill slot
    mov r10, r10 # hv payload
    mov r11, 45 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2152], r11 # store tag L87
    mov [rbp - 712], r10 # spill L87 to slot
    mov r10, [rbp - 712] # reload L87 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb34 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb33 # jump -> then
.L40fd_rt_parse_float_native_bb33:
    mov r10, 1 # assign L76
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2064], r11 # store tag L76
    mov [rbp - 624], r10 # spill L76 to slot
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2168], r11 # store tag L89
    mov [rbp - 728], r10 # spill L89 to slot
    mov r10, [rbp - 728] # reload L89 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 2168] # tag L89 from tag-slot
    mov [rbp - 1480], r11 # store tag L3
    jmp .L40fd_rt_parse_float_native_bb34 # branch
.L40fd_rt_parse_float_native_bb34:
    jmp .L40fd_rt_parse_float_native_bb35 # branch
.L40fd_rt_parse_float_native_bb35:
    mov r10, 1 # assign L90
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2176], r11 # store tag L90
    mov [rbp - 736], r10 # spill L90 to slot
    jmp .L40fd_rt_parse_float_native_bb36 # branch
.L40fd_rt_parse_float_native_bb36:
    mov r11, 0 # hv payload
    mov r10, [rbp - 736] # reload L90 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2184], r11 # store tag L91
    mov [rbp - 744], r10 # spill L91 to slot
    mov r10, [rbp - 744] # reload L91 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb38 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb37 # jump -> then
.L40fd_rt_parse_float_native_bb37:
    mov r10, r13 # hv payload
    mov r11, r14 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2192], r11 # store tag L92
    mov [rbp - 752], r10 # spill L92 to slot
    mov r11, [rbp - 752] # reload L92 from spill slot
    mov r10, r11 # assign L93
    mov r11, [rbp - 2192] # tag L92 from tag-slot
    mov [rbp - 2200], r11 # store tag L93
    mov [rbp - 760], r10 # spill L93 to slot
    mov r11, [rbp - 760] # reload L93 from spill slot
    mov r11, r11 # hv payload
    mov r10, 47 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2208], r11 # store tag L94
    mov [rbp - 768], r10 # spill L94 to slot
    mov r11, [rbp - 768] # reload L94 from spill slot
    mov r10, r11 # assign L95
    mov r11, [rbp - 2208] # tag L94 from tag-slot
    mov [rbp - 2216], r11 # store tag L95
    mov [rbp - 776], r10 # spill L95 to slot
    mov r11, 58 # hv payload
    mov r10, [rbp - 760] # reload L93 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2224], r11 # store tag L96
    mov [rbp - 784], r10 # spill L96 to slot
    mov r11, [rbp - 784] # reload L96 from spill slot
    mov r10, r11 # assign L97
    mov r11, [rbp - 2224] # tag L96 from tag-slot
    mov [rbp - 2232], r11 # store tag L97
    mov [rbp - 792], r10 # spill L97 to slot
    mov r11, [rbp - 792] # reload L97 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 776] # reload L95 from spill slot
    mov r10, r10 # hv payload
    and r10, r11 # __hx_payload_and: r10 = a.pl and b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2240], r11 # store tag L98
    mov [rbp - 800], r10 # spill L98 to slot
    mov r11, [rbp - 800] # reload L98 from spill slot
    mov r10, r11 # assign L99
    mov r11, [rbp - 2240] # tag L98 from tag-slot
    mov [rbp - 2248], r11 # store tag L99
    mov [rbp - 808], r10 # spill L99 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 808] # reload L99 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2256], r11 # store tag L100
    mov [rbp - 816], r10 # spill L100 to slot
    mov r10, [rbp - 816] # reload L100 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb40 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb39 # jump -> then
.L40fd_rt_parse_float_native_bb38:
    jmp .L40fd_rt_parse_float_native_bb30 # branch
.L40fd_rt_parse_float_native_bb39:
    mov r11, 48 # hv payload
    mov r10, [rbp - 760] # reload L93 from spill slot
    mov r10, r10 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2272], r11 # store tag L102
    mov [rbp - 832], r10 # spill L102 to slot
    mov r11, [rbp - 832] # reload L102 from spill slot
    mov r10, r11 # assign L103
    mov r11, [rbp - 2272] # tag L102 from tag-slot
    mov [rbp - 2280], r11 # store tag L103
    mov [rbp - 840], r10 # spill L103 to slot
    mov r11, 10 # hv payload
    mov r10, [rbp - 632] # reload L77 from spill slot
    mov r10, r10 # hv payload
    imul r10, r11 # __hx_payload_mul: r10 = a.pl imul b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2288], r11 # store tag L104
    mov [rbp - 848], r10 # spill L104 to slot
    mov r11, [rbp - 848] # reload L104 from spill slot
    mov r10, r11 # assign L105
    mov r11, [rbp - 2288] # tag L104 from tag-slot
    mov [rbp - 2296], r11 # store tag L105
    mov [rbp - 856], r10 # spill L105 to slot
    mov r11, [rbp - 840] # reload L103 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 856] # reload L105 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2304], r11 # store tag L106
    mov [rbp - 864], r10 # spill L106 to slot
    mov r11, [rbp - 864] # reload L106 from spill slot
    mov r10, r11 # assign L77
    mov r11, [rbp - 2304] # tag L106 from tag-slot
    mov [rbp - 2072], r11 # store tag L77
    mov [rbp - 632], r10 # spill L77 to slot
    mov r10, 1 # assign L78
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2080], r11 # store tag L78
    mov [rbp - 640], r10 # spill L78 to slot
    mov r11, [rbp - 632] # reload L77 from spill slot
    mov r11, r11 # hv payload
    mov r10, 1000 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2312], r11 # store tag L107
    mov [rbp - 872], r10 # spill L107 to slot
    mov r11, [rbp - 872] # reload L107 from spill slot
    mov r10, r11 # assign L108
    mov r11, [rbp - 2312] # tag L107 from tag-slot
    mov [rbp - 2320], r11 # store tag L108
    mov [rbp - 880], r10 # spill L108 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 880] # reload L108 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2328], r11 # store tag L109
    mov [rbp - 888], r10 # spill L109 to slot
    mov r10, [rbp - 888] # reload L109 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb42 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb41 # jump -> then
.L40fd_rt_parse_float_native_bb40:
    mov r10, 0 # assign L90
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2176], r11 # store tag L90
    mov [rbp - 736], r10 # spill L90 to slot
    jmp .L40fd_rt_parse_float_native_bb43 # branch
.L40fd_rt_parse_float_native_bb41:
    mov r10, 1000 # assign L77
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2072], r11 # store tag L77
    mov [rbp - 632], r10 # spill L77 to slot
    jmp .L40fd_rt_parse_float_native_bb42 # branch
.L40fd_rt_parse_float_native_bb42:
    mov r11, 1 # hv payload
    mov r10, r14 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2344], r11 # store tag L111
    mov [rbp - 904], r10 # spill L111 to slot
    mov r10, [rbp - 904] # reload L111 from spill slot
    mov r14, r10 # assign L3
    mov r11, [rbp - 2344] # tag L111 from tag-slot
    mov [rbp - 1480], r11 # store tag L3
    jmp .L40fd_rt_parse_float_native_bb43 # branch
.L40fd_rt_parse_float_native_bb43:
    jmp .L40fd_rt_parse_float_native_bb36 # branch
.L40fd_rt_parse_float_native_bb44:
    mov r11, 0 # hv payload
    mov r10, [rbp - 624] # reload L76 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2368], r11 # store tag L114
    mov [rbp - 928], r10 # spill L114 to slot
    mov r10, [rbp - 928] # reload L114 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb47 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb46 # jump -> then
.L40fd_rt_parse_float_native_bb45:
    mov r10, r13 # hv payload
    mov r11, r14 # hv payload
    add r10, r11 # __hx_ptr_load8: addr = ptr + off
    movzx r10, byte ptr [r10] # __hx_ptr_load8: r10 = *(u8*)addr (zero-ext)
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2400], r11 # store tag L118
    mov [rbp - 960], r10 # spill L118 to slot
    mov r11, [rbp - 960] # reload L118 from spill slot
    mov r10, r11 # assign L119
    mov r11, [rbp - 2400] # tag L118 from tag-slot
    mov [rbp - 2408], r11 # store tag L119
    mov [rbp - 968], r10 # spill L119 to slot
    mov r10, 0 # assign L120
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2416], r11 # store tag L120
    mov [rbp - 976], r10 # spill L120 to slot
    mov r10, [rbp - 264] # reload L31 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2424], r11 # store tag L121
    mov [rbp - 984], r10 # spill L121 to slot
    mov r10, [rbp - 984] # reload L121 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb50 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb49 # jump -> then
.L40fd_rt_parse_float_native_bb46:
    mov r11, [rbp - 632] # reload L77 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov r10, r10 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2384], r11 # store tag L116
    mov [rbp - 944], r10 # spill L116 to slot
    mov r11, [rbp - 944] # reload L116 from spill slot
    mov r10, r11 # assign L32
    mov r11, [rbp - 2384] # tag L116 from tag-slot
    mov [rbp - 1712], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    jmp .L40fd_rt_parse_float_native_bb48 # branch
.L40fd_rt_parse_float_native_bb47:
    mov r11, [rbp - 632] # reload L77 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2392], r11 # store tag L117
    mov [rbp - 952], r10 # spill L117 to slot
    mov r11, [rbp - 952] # reload L117 from spill slot
    mov r10, r11 # assign L32
    mov r11, [rbp - 2392] # tag L117 from tag-slot
    mov [rbp - 1712], r11 # store tag L32
    mov [rbp - 272], r10 # spill L32 to slot
    jmp .L40fd_rt_parse_float_native_bb48 # branch
.L40fd_rt_parse_float_native_bb48:
    jmp .L40fd_rt_parse_float_native_bb45 # branch
.L40fd_rt_parse_float_native_bb49:
    mov r10, 1 # assign L120
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2416], r11 # store tag L120
    mov [rbp - 976], r10 # spill L120 to slot
    jmp .L40fd_rt_parse_float_native_bb50 # branch
.L40fd_rt_parse_float_native_bb50:
    mov r11, 0 # hv payload
    mov r10, [rbp - 288] # reload L34 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2440], r11 # store tag L123
    mov [rbp - 1000], r10 # spill L123 to slot
    mov r10, [rbp - 1000] # reload L123 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb52 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb51 # jump -> then
.L40fd_rt_parse_float_native_bb51:
    mov r10, 1 # assign L120
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2416], r11 # store tag L120
    mov [rbp - 976], r10 # spill L120 to slot
    jmp .L40fd_rt_parse_float_native_bb52 # branch
.L40fd_rt_parse_float_native_bb52:
    mov r11, 0 # hv payload
    mov r10, [rbp - 616] # reload L75 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2456], r11 # store tag L125
    mov [rbp - 1016], r10 # spill L125 to slot
    mov r10, [rbp - 1016] # reload L125 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb54 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb53 # jump -> then
.L40fd_rt_parse_float_native_bb53:
    mov r10, [rbp - 640] # reload L78 from spill slot
    mov r10, r10 # hv payload
    mov r11, 0 # hv payload
    cmp r10, r11 # __hx_payload_eq: cmp payloads
    sete al # __hx_payload_eq: al = (a==b)
    movzx r10, al # __hx_payload_eq: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2472], r11 # store tag L127
    mov [rbp - 1032], r10 # spill L127 to slot
    mov r10, [rbp - 1032] # reload L127 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb56 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb55 # jump -> then
.L40fd_rt_parse_float_native_bb54:
    mov r11, 0 # hv payload
    mov r10, [rbp - 968] # reload L119 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2488], r11 # store tag L129
    mov [rbp - 1048], r10 # spill L129 to slot
    mov r10, [rbp - 1048] # reload L129 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb58 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb57 # jump -> then
.L40fd_rt_parse_float_native_bb55:
    mov r10, 1 # assign L120
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2416], r11 # store tag L120
    mov [rbp - 976], r10 # spill L120 to slot
    jmp .L40fd_rt_parse_float_native_bb56 # branch
.L40fd_rt_parse_float_native_bb56:
    jmp .L40fd_rt_parse_float_native_bb54 # branch
.L40fd_rt_parse_float_native_bb57:
    mov r10, 1 # assign L120
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2416], r11 # store tag L120
    mov [rbp - 976], r10 # spill L120 to slot
    jmp .L40fd_rt_parse_float_native_bb58 # branch
.L40fd_rt_parse_float_native_bb58:
    mov r11, [rbp - 272] # reload L32 from spill slot
    mov r11, r11 # hv payload
    mov r10, 22 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2504], r11 # store tag L131
    mov [rbp - 1064], r10 # spill L131 to slot
    mov r11, [rbp - 1064] # reload L131 from spill slot
    mov r10, r11 # assign L132
    mov r11, [rbp - 2504] # tag L131 from tag-slot
    mov [rbp - 2512], r11 # store tag L132
    mov [rbp - 1072], r10 # spill L132 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2520], r11 # store tag L133
    mov [rbp - 1080], r10 # spill L133 to slot
    mov r11, [rbp - 1080] # reload L133 from spill slot
    mov r10, r11 # assign L134
    mov r11, [rbp - 2520] # tag L133 from tag-slot
    mov [rbp - 2528], r11 # store tag L134
    mov [rbp - 1088], r10 # spill L134 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 1072] # reload L132 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2536], r11 # store tag L135
    mov [rbp - 1096], r10 # spill L135 to slot
    mov r10, [rbp - 1096] # reload L135 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb60 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb59 # jump -> then
.L40fd_rt_parse_float_native_bb59:
    mov r10, 1 # assign L120
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2416], r11 # store tag L120
    mov [rbp - 976], r10 # spill L120 to slot
    jmp .L40fd_rt_parse_float_native_bb60 # branch
.L40fd_rt_parse_float_native_bb60:
    mov r11, 0 # hv payload
    mov r10, [rbp - 1088] # reload L134 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2552], r11 # store tag L137
    mov [rbp - 1112], r10 # spill L137 to slot
    mov r10, [rbp - 1112] # reload L137 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb62 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb61 # jump -> then
.L40fd_rt_parse_float_native_bb61:
    mov r11, [rbp - 272] # reload L32 from spill slot
    mov r11, r11 # hv payload
    mov r10, 0 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2568], r11 # store tag L139
    mov [rbp - 1128], r10 # spill L139 to slot
    mov r11, [rbp - 1128] # reload L139 from spill slot
    mov r10, r11 # assign L140
    mov r11, [rbp - 2568] # tag L139 from tag-slot
    mov [rbp - 2576], r11 # store tag L140
    mov [rbp - 1136], r10 # spill L140 to slot
    mov r11, [rbp - 1136] # reload L140 from spill slot
    mov r11, r11 # hv payload
    mov r10, 22 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2584], r11 # store tag L141
    mov [rbp - 1144], r10 # spill L141 to slot
    mov r11, [rbp - 1144] # reload L141 from spill slot
    mov r10, r11 # assign L142
    mov r11, [rbp - 2584] # tag L141 from tag-slot
    mov [rbp - 2592], r11 # store tag L142
    mov [rbp - 1152], r10 # spill L142 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 1152] # reload L142 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2600], r11 # store tag L143
    mov [rbp - 1160], r10 # spill L143 to slot
    mov r10, [rbp - 1160] # reload L143 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb64 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb63 # jump -> then
.L40fd_rt_parse_float_native_bb62:
    mov r11, 0 # hv payload
    mov r10, [rbp - 976] # reload L120 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2616], r11 # store tag L145
    mov [rbp - 1176], r10 # spill L145 to slot
    mov r10, [rbp - 1176] # reload L145 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb66 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb65 # jump -> then
.L40fd_rt_parse_float_native_bb63:
    mov r10, 1 # assign L120
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2416], r11 # store tag L120
    mov [rbp - 976], r10 # spill L120 to slot
    jmp .L40fd_rt_parse_float_native_bb64 # branch
.L40fd_rt_parse_float_native_bb64:
    jmp .L40fd_rt_parse_float_native_bb62 # branch
.L40fd_rt_parse_float_native_bb65:
    mov r10, 0 # hv payload
    mov r11, 4 # hv payload
    mov [rbp - 2632], r11 # store tag L147
    mov [rbp - 1192], r10 # spill L147 to slot
    mov rdx, [rbp - 1192] # reload L147 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 2632] # tag L147 from tag-slot
    add rsp, 2848 # epilogue: free spill frame
    add rsp, 8 # epilogue: drop callee-save align pad
    pop r15 # epilogue: restore r15
    pop r14 # epilogue: restore r14
    pop r13 # epilogue: restore r13
    pop r12 # epilogue: restore r12
    pop rbx # epilogue: restore rbx
    pop rbp # epilogue: restore rbp
    ret # return
.L40fd_rt_parse_float_native_bb66:
    mov r10, [rbp - 256] # reload L30 from spill slot
    mov r10, r10 # hv payload
    mov rax, [rbp - 1696] # tag L30 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 2640], r11 # store tag L148
    mov [rbp - 1200], r10 # spill L148 to slot
    mov r11, [rbp - 1200] # reload L148 from spill slot
    mov r10, r11 # assign L149
    mov r11, [rbp - 2640] # tag L148 from tag-slot
    mov [rbp - 2648], r11 # store tag L149
    mov [rbp - 1208], r10 # spill L149 to slot
    mov r11, 1 # hv payload
    mov r10, 0 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2656], r11 # store tag L150
    mov [rbp - 1216], r10 # spill L150 to slot
    mov r11, [rbp - 1216] # reload L150 from spill slot
    mov r10, r11 # assign L151
    mov r11, [rbp - 2656] # tag L150 from tag-slot
    mov [rbp - 2664], r11 # store tag L151
    mov [rbp - 1224], r10 # spill L151 to slot
    mov r10, [rbp - 1224] # reload L151 from spill slot
    mov r10, r10 # hv payload
    mov rax, [rbp - 2664] # tag L151 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 2672], r11 # store tag L152
    mov [rbp - 1232], r10 # spill L152 to slot
    mov r11, [rbp - 1232] # reload L152 from spill slot
    mov r10, r11 # assign L153
    mov r11, [rbp - 2672] # tag L152 from tag-slot
    mov [rbp - 2680], r11 # store tag L153
    mov [rbp - 1240], r10 # spill L153 to slot
    mov r11, 10 # hv payload
    mov r10, 0 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2688], r11 # store tag L154
    mov [rbp - 1248], r10 # spill L154 to slot
    mov r11, [rbp - 1248] # reload L154 from spill slot
    mov r10, r11 # assign L155
    mov r11, [rbp - 2688] # tag L154 from tag-slot
    mov [rbp - 2696], r11 # store tag L155
    mov [rbp - 1256], r10 # spill L155 to slot
    mov r10, [rbp - 1256] # reload L155 from spill slot
    mov r10, r10 # hv payload
    mov rax, [rbp - 2696] # tag L155 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 2704], r11 # store tag L156
    mov [rbp - 1264], r10 # spill L156 to slot
    mov r11, [rbp - 1264] # reload L156 from spill slot
    mov r10, r11 # assign L157
    mov r11, [rbp - 2704] # tag L156 from tag-slot
    mov [rbp - 2712], r11 # store tag L157
    mov [rbp - 1272], r10 # spill L157 to slot
    mov r11, [rbp - 272] # reload L32 from spill slot
    mov r10, r11 # assign L158
    mov r11, [rbp - 1712] # tag L32 from tag-slot
    mov [rbp - 2720], r11 # store tag L158
    mov [rbp - 1280], r10 # spill L158 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 272] # reload L32 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2728], r11 # store tag L159
    mov [rbp - 1288], r10 # spill L159 to slot
    mov r11, [rbp - 1288] # reload L159 from spill slot
    mov r10, r11 # assign L160
    mov r11, [rbp - 2728] # tag L159 from tag-slot
    mov [rbp - 2736], r11 # store tag L160
    mov [rbp - 1296], r10 # spill L160 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 1296] # reload L160 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2744], r11 # store tag L161
    mov [rbp - 1304], r10 # spill L161 to slot
    mov r10, [rbp - 1304] # reload L161 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb68 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb67 # jump -> then
.L40fd_rt_parse_float_native_bb67:
    mov r11, [rbp - 272] # reload L32 from spill slot
    mov r11, r11 # hv payload
    mov r10, 0 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2760], r11 # store tag L163
    mov [rbp - 1320], r10 # spill L163 to slot
    mov r11, [rbp - 1320] # reload L163 from spill slot
    mov r10, r11 # assign L158
    mov r11, [rbp - 2760] # tag L163 from tag-slot
    mov [rbp - 2720], r11 # store tag L158
    mov [rbp - 1280], r10 # spill L158 to slot
    jmp .L40fd_rt_parse_float_native_bb68 # branch
.L40fd_rt_parse_float_native_bb68:
    mov r10, 0 # assign L164
    mov r11, 0 # tag default = TAG_INT
    mov [rbp - 2768], r11 # store tag L164
    mov [rbp - 1328], r10 # spill L164 to slot
    jmp .L40fd_rt_parse_float_native_bb69 # branch
.L40fd_rt_parse_float_native_bb69:
    mov r11, [rbp - 1280] # reload L158 from spill slot
    mov r11, r11 # hv payload
    mov r10, [rbp - 1328] # reload L164 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_lt: cmp payloads
    setl al # __hx_payload_lt: al = predicate
    movzx r10, al # __hx_payload_lt: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2776], r11 # store tag L165
    mov [rbp - 1336], r10 # spill L165 to slot
    mov r10, [rbp - 1336] # reload L165 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb71 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb70 # jump -> then
.L40fd_rt_parse_float_native_bb70:
    mov r10, [rbp - 1240] # reload L153 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 1272] # reload L157 from spill slot
    mov r11, r11 # hv payload
    movq xmm0, r10 # __hx_payload_fmul: xmm0 = a.f bits
    movq xmm1, r11 # __hx_payload_fmul: xmm1 = b.f bits
    mulsd xmm0, xmm1 # __hx_payload_fmul: xmm0 = a.f mulsd b.f
    movq r10, xmm0 # __hx_payload_fmul: r10 = result bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 2784], r11 # store tag L166
    mov [rbp - 1344], r10 # spill L166 to slot
    mov r11, [rbp - 1344] # reload L166 from spill slot
    mov r10, r11 # assign L153
    mov r11, [rbp - 2784] # tag L166 from tag-slot
    mov [rbp - 2680], r11 # store tag L153
    mov [rbp - 1240], r10 # spill L153 to slot
    mov r11, 1 # hv payload
    mov r10, [rbp - 1328] # reload L164 from spill slot
    mov r10, r10 # hv payload
    add r10, r11 # __hx_payload_add: r10 = a.pl add b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2792], r11 # store tag L167
    mov [rbp - 1352], r10 # spill L167 to slot
    mov r11, [rbp - 1352] # reload L167 from spill slot
    mov r10, r11 # assign L164
    mov r11, [rbp - 2792] # tag L167 from tag-slot
    mov [rbp - 2768], r11 # store tag L164
    mov [rbp - 1328], r10 # spill L164 to slot
    jmp .L40fd_rt_parse_float_native_bb69 # branch
.L40fd_rt_parse_float_native_bb71:
    mov r11, [rbp - 1208] # reload L149 from spill slot
    mov r10, r11 # assign L168
    mov r11, [rbp - 2648] # tag L149 from tag-slot
    mov [rbp - 2800], r11 # store tag L168
    mov [rbp - 1360], r10 # spill L168 to slot
    mov r11, 0 # hv payload
    mov r10, [rbp - 1296] # reload L160 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2808], r11 # store tag L169
    mov [rbp - 1368], r10 # spill L169 to slot
    mov r10, [rbp - 1368] # reload L169 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb73 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb72 # jump -> then
.L40fd_rt_parse_float_native_bb72:
    mov r10, [rbp - 1208] # reload L149 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 1240] # reload L153 from spill slot
    mov r11, r11 # hv payload
    movq xmm0, r10 # __hx_payload_fdiv: xmm0 = a.f bits
    movq xmm1, r11 # __hx_payload_fdiv: xmm1 = b.f bits
    divsd xmm0, xmm1 # __hx_payload_fdiv: xmm0 = a.f divsd b.f
    movq r10, xmm0 # __hx_payload_fdiv: r10 = result bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 2824], r11 # store tag L171
    mov [rbp - 1384], r10 # spill L171 to slot
    mov r11, [rbp - 1384] # reload L171 from spill slot
    mov r10, r11 # assign L168
    mov r11, [rbp - 2824] # tag L171 from tag-slot
    mov [rbp - 2800], r11 # store tag L168
    mov [rbp - 1360], r10 # spill L168 to slot
    jmp .L40fd_rt_parse_float_native_bb74 # branch
.L40fd_rt_parse_float_native_bb73:
    mov r10, [rbp - 1208] # reload L149 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 1240] # reload L153 from spill slot
    mov r11, r11 # hv payload
    movq xmm0, r10 # __hx_payload_fmul: xmm0 = a.f bits
    movq xmm1, r11 # __hx_payload_fmul: xmm1 = b.f bits
    mulsd xmm0, xmm1 # __hx_payload_fmul: xmm0 = a.f mulsd b.f
    movq r10, xmm0 # __hx_payload_fmul: r10 = result bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 2832], r11 # store tag L172
    mov [rbp - 1392], r10 # spill L172 to slot
    mov r11, [rbp - 1392] # reload L172 from spill slot
    mov r10, r11 # assign L168
    mov r11, [rbp - 2832] # tag L172 from tag-slot
    mov [rbp - 2800], r11 # store tag L168
    mov [rbp - 1360], r10 # spill L168 to slot
    jmp .L40fd_rt_parse_float_native_bb74 # branch
.L40fd_rt_parse_float_native_bb74:
    mov r11, 0 # hv payload
    mov r10, [rbp - 200] # reload L23 from spill slot
    mov r10, r10 # hv payload
    cmp r10, r11 # __hx_payload_ne: cmp payloads
    setne al # __hx_payload_ne: al = predicate
    movzx r10, al # __hx_payload_ne: zero-extend bool
    mov r11, 2 # materialize tag imm 2
    mov [rbp - 2840], r11 # store tag L173
    mov [rbp - 1400], r10 # spill L173 to slot
    mov r10, [rbp - 1400] # reload L173 from spill slot
    test r10, r10 # br_cond test
    jz .L40fd_rt_parse_float_native_bb76 # jump-if-zero -> else
    jmp .L40fd_rt_parse_float_native_bb75 # jump -> then
.L40fd_rt_parse_float_native_bb75:
    mov r11, 1 # hv payload
    mov r10, 0 # hv payload
    sub r10, r11 # __hx_payload_sub: r10 = a.pl sub b.pl
    mov r11, 0 # materialize tag imm 0
    mov [rbp - 2856], r11 # store tag L175
    mov [rbp - 1416], r10 # spill L175 to slot
    mov r11, [rbp - 1416] # reload L175 from spill slot
    mov r10, r11 # assign L176
    mov r11, [rbp - 2856] # tag L175 from tag-slot
    mov [rbp - 2864], r11 # store tag L176
    mov [rbp - 1424], r10 # spill L176 to slot
    mov r10, [rbp - 1424] # reload L176 from spill slot
    mov r10, r10 # hv payload
    mov rax, [rbp - 2864] # tag L176 from tag-slot
    mov r11, r10 # __hx_to_double: r11 = original (float) bits
    cvtsi2sd xmm0, r10 # __hx_to_double: xmm0 = (double)int
    movq r10, xmm0 # __hx_to_double: r10 = converted bits
    cmp rax, 1 # __hx_to_double: tag == TAG_FLOAT?
    cmove r10, r11 # __hx_to_double: if FLOAT keep original bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 2872], r11 # store tag L177
    mov [rbp - 1432], r10 # spill L177 to slot
    mov r11, [rbp - 1432] # reload L177 from spill slot
    mov r10, r11 # assign L178
    mov r11, [rbp - 2872] # tag L177 from tag-slot
    mov [rbp - 2880], r11 # store tag L178
    mov [rbp - 1440], r10 # spill L178 to slot
    mov r10, [rbp - 1360] # reload L168 from spill slot
    mov r10, r10 # hv payload
    mov r11, [rbp - 1440] # reload L178 from spill slot
    mov r11, r11 # hv payload
    movq xmm0, r10 # __hx_payload_fmul: xmm0 = a.f bits
    movq xmm1, r11 # __hx_payload_fmul: xmm1 = b.f bits
    mulsd xmm0, xmm1 # __hx_payload_fmul: xmm0 = a.f mulsd b.f
    movq r10, xmm0 # __hx_payload_fmul: r10 = result bits
    mov r11, 1 # materialize tag imm 1
    mov [rbp - 2888], r11 # store tag L179
    mov [rbp - 1448], r10 # spill L179 to slot
    mov r11, [rbp - 1448] # reload L179 from spill slot
    mov r10, r11 # assign L168
    mov r11, [rbp - 2888] # tag L179 from tag-slot
    mov [rbp - 2800], r11 # store tag L168
    mov [rbp - 1360], r10 # spill L168 to slot
    jmp .L40fd_rt_parse_float_native_bb76 # branch
.L40fd_rt_parse_float_native_bb76:
    mov rdx, [rbp - 1360] # reload L168 from spill slot
    mov rdx, rdx # hv arg payload
    mov rax, [rbp - 2800] # tag L168 from tag-slot
    add rsp, 2848 # epilogue: free spill frame
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
