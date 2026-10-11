/* G-CC-4 determinism fixture — CompCert-subset C99 only:
 * no VLA, no setjmp/longjmp, no long double, fixed-width ints,
 * MISRA-shaped switch-free control flow. Two pinned-flag ccomp runs
 * must produce a byte-identical binary (scripts/cc_gates.sh g_cc_4). */
#include <stdio.h>
#include <stdint.h>

int main(void)
{
    uint64_t acc = 0;
    int32_t i;
    for (i = 1; i <= 16; i++) {
        acc += (uint64_t)i * 7u;
    }
    printf("%llu\n", (unsigned long long)acc);
    return 0;
}
