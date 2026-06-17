#include <stdio.h>
#include <stdint.h>
#include <string.h>
static uint32_t hexa_fnv1a(const char* s, size_t len) {
    uint32_t h = 2166136261u;
    for (size_t i = 0; i < len; i++) { h ^= (uint8_t)s[i]; h *= 16777619u; }
    return h;
}
int main(void) {
    const char* cases[] = {"", "a", "hexa", "no .c 완전돌파", "The quick brown fox", "fnv1a"};
    for (int k = 0; k < 6; k++) printf("%u\n", hexa_fnv1a(cases[k], strlen(cases[k])));
    return 0;
}
