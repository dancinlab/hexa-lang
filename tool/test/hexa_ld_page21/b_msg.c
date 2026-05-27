// b_msg.c — object B: defines a string constant that lands in __cstring.
//
// Control/INPUT only (compiled by `clang -c`, NOT linked by clang/ld).
// The `const char[]` with an external linkage symbol forces clang to
// emit the bytes into the __TEXT,__cstring section and a defined
// external symbol `_hxld_msg` pointing at it. Object A references this
// symbol via an adrp/add (PAGE21 + PAGEOFF12) pair.
//
// `used` keeps clang from dead-stripping it at -O; external linkage
// keeps it visible across objects.
__attribute__((used))
const char hxld_msg[] = "hi from cstring\n";
