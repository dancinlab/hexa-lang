// ════════════════════════════════════════════════════════════════════════════
//  self/native/hxffi_slot.c — out-pointer slot allocator for hexa C FFI
//
//  PURPOSE
//  -------
//  Many C APIs (DuckDB, SQLite, libcurl, ...) use the "out-parameter pointer"
//  pattern, where the caller passes the *address* of a void* slot and the
//  callee writes the resulting handle into that slot:
//
//      duckdb_state duckdb_open(const char *path, duckdb_database *out_db);
//
//  Hexa's `extern fn` lane passes pointers as int (uintptr_t). Until this
//  shim, there was no way for hexa code to (a) allocate an 8-byte slot,
//  (b) pass its address to such a C API, then (c) dereference the slot
//  back into an int handle for subsequent calls.
//
//  This shim provides exactly that — three tiny helpers that hexa binds via
//  `extern fn` and that close the gap. The slot lives on the C heap (not the
//  hexa stack) so its address survives the FFI call and is well-aligned for
//  void* writes.
//
//  USAGE (from hexa)
//  -----------------
//      let slot = hxffi_alloc_ptr_slot()         // calloc(1, 8) → addr
//      duckdb_open(path, slot)                   // C writes *slot = db
//      let db = hxffi_load_ptr(slot)             // *(void**)slot → int
//      hxffi_free_ptr_slot(slot)                 // free(slot)
//
//  BUILD
//  -----
//      cc -O2 -fPIC -shared self/native/hxffi_slot.c \
//          -o self/native/build/libhxffi_slot.dylib  (macOS)
//      cc -O2 -fPIC -shared self/native/hxffi_slot.c \
//          -o self/native/build/libhxffi_slot.so     (Linux)
//
//  LINKAGE
//  -------
//      @link("hxffi_slot")   → resolved by hexa_ffi_dlopen via
//      ${HEXA_LANG}/self/native/build/libhxffi_slot.{dylib,so}
//
//  SAFETY
//  ------
//   * `hxffi_load_ptr(NULL)` returns NULL (caller must free anyway).
//   * `hxffi_free_ptr_slot(NULL)` is a no-op (matches free() semantics).
//   * Slots are zero-initialized so an unmodified slot loads as NULL
//     (lets callers detect "C didn't write" without sentinel hacks).
//
//  @since 2026-05-09
//  @maintainer anima-core
// ════════════════════════════════════════════════════════════════════════════

#include <stdlib.h>
#include <string.h>
#include <stdint.h>

// hxffi_alloc_ptr_slot — return a freshly zero-initialized 8-byte slot.
// Returns NULL only on allocation failure (extremely rare).
void* hxffi_alloc_ptr_slot(void) {
    return calloc(1, sizeof(void*));
}

// hxffi_load_ptr — dereference an out-pointer slot.
// `slot` must be an address returned by hxffi_alloc_ptr_slot. NULL safe.
void* hxffi_load_ptr(void* slot) {
    if (!slot) return NULL;
    void* val;
    memcpy(&val, slot, sizeof(void*));
    return val;
}

// hxffi_store_ptr — write a pointer into an out-pointer slot.
// Useful for callers that want to seed a slot or reset it.
void hxffi_store_ptr(void* slot, void* value) {
    if (!slot) return;
    memcpy(slot, &value, sizeof(void*));
}

// hxffi_free_ptr_slot — release a slot allocated by hxffi_alloc_ptr_slot.
// NULL safe.
void hxffi_free_ptr_slot(void* slot) {
    free(slot);
}

// hxffi_alloc_buf — allocate a zero-initialized buffer of arbitrary size.
// Useful for C APIs that take a pointer to a struct (not just a pointer
// to a pointer). Caller must free via hxffi_free_ptr_slot.
void* hxffi_alloc_buf(long size) {
    if (size <= 0) return NULL;
    return calloc(1, (size_t)size);
}

// hxffi_slot_selftest — internal sanity check. Allocates a slot, stores a
// known sentinel, loads it back, frees the slot. Returns 1 on success, 0 on
// failure. Bound from hexa side as part of the c_ffi selftest battery.
int hxffi_slot_selftest(void) {
    void* slot = hxffi_alloc_ptr_slot();
    if (!slot) return 0;
    // Empty slot must read back as NULL (calloc zero-init contract).
    if (hxffi_load_ptr(slot) != NULL) {
        hxffi_free_ptr_slot(slot);
        return 0;
    }
    // Store a sentinel and read it back.
    void* sentinel = (void*)(uintptr_t)0xDEADBEEFCAFEBABEULL;
    hxffi_store_ptr(slot, sentinel);
    if (hxffi_load_ptr(slot) != sentinel) {
        hxffi_free_ptr_slot(slot);
        return 0;
    }
    hxffi_free_ptr_slot(slot);
    return 1;
}
