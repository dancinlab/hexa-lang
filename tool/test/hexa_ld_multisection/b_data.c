// b_data.c — object B: defines the three symbols object A references,
// one in each section class the inc3 layout must place:
//
//   ms_str   → __TEXT,__cstring   (read-only C string)
//   ms_init  → __DATA,__data      (initialized mutable global)
//   ms_zero  → __DATA,__bss       (zero-init global; clang emits it as
//                                   a common/zerofill symbol)
//
// Control/INPUT only (compiled by `clang -c`, NOT linked by clang/ld).
// `used` keeps clang from dead-stripping; external linkage keeps them
// visible across objects.

__attribute__((used))
const char ms_str[] = "ms ok\n";        // → __cstring (6 bytes incl '\n')

__attribute__((used))
int ms_init = 7;                         // → __data (initialized)

__attribute__((used))
int ms_zero = 0;                         // → __bss (zero-init)
