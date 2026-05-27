/* freestanding/stdint.h — minimal int-sized typedefs for bare-metal builds.
 *
 * Brew's arm-none-eabi-gcc ships without picolibc/newlib, so the compiler's
 * own <stdint.h> uses #include_next to layer atop a missing C library and
 * fails compilation. This shim provides the ISO C99 §7.18 fixed-width
 * integer types directly, sufficient for the SSCB firmware scaffold which
 * only uses int8/int16/int32/int64 + their unsigned variants.
 *
 * Activated via the Makefile flag chain:
 *     -ffreestanding
 *     -isystem include/freestanding   (this directory, before gcc's own)
 *
 * If you replace the toolchain with one that bundles newlib/picolibc, this
 * shim becomes unnecessary — delete it and remove the -isystem line from
 * the Makefile.
 */
#ifndef _STDINT_H
#define _STDINT_H 1

typedef signed char           int8_t;
typedef short                 int16_t;
typedef int                   int32_t;
typedef long long             int64_t;

typedef unsigned char         uint8_t;
typedef unsigned short        uint16_t;
typedef unsigned int          uint32_t;
typedef unsigned long long    uint64_t;

typedef int32_t               intptr_t;
typedef uint32_t              uintptr_t;

#define INT8_MIN              (-128)
#define INT16_MIN             (-32768)
#define INT32_MIN             (-2147483647 - 1)
#define INT64_MIN             (-9223372036854775807LL - 1)
#define INT8_MAX              127
#define INT16_MAX             32767
#define INT32_MAX             2147483647
#define INT64_MAX             9223372036854775807LL
#define UINT8_MAX             0xff
#define UINT16_MAX            0xffff
#define UINT32_MAX            0xffffffffu
#define UINT64_MAX            0xffffffffffffffffull

#endif /* _STDINT_H */
