#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>

static char *__koru_concat(const char *a, const char *b) {
    size_t la = strlen(a), lb = strlen(b);
    char *r = (char *)malloc(la + lb + 1);
    if (!r) { fputs("koru: out of memory\n", stderr); abort(); }
    memcpy(r, a, la);
    memcpy(r + la, b, lb + 1);
    return r;
}
static void __koru_stdout_write(const char *s) { fputs(s, stdout); }
static void __koru_stderr_write(const char *s) { fputs(s, stderr); }
static long long __koru_len(const char *s) { return (long long)strlen(s); }
static char *__koru_str_i64(long long v) {
    char buf[32];
    snprintf(buf, sizeof buf, "%lld", v);
    return __koru_concat(buf, "");
}
static void __koru_stdout_write_i64(long long v) { printf("%lld", v); }
static void __koru_stderr_write_i64(long long v) { fprintf(stderr, "%lld", v); }
static void __koru_stdout_write_f64(double v) { printf("%g", v); }
static void __koru_stderr_write_f64(double v) { fprintf(stderr, "%g", v); }
static _Noreturn void __koru_unreachable(const char *what) {
    fflush(NULL); // buffered stdout must land before the trap (zig flushes; abort does not)
    fprintf(stderr, "koru: %s\n", what);
    abort();
}
// std/store: 's' created (cell + write-subflow at module scope); fields v: i64
static struct { long long v; } __koru_store_s = { .v = 7 };
static long long app_ops_peek(void);
static void app_ops_bump(void);
static void std_testing_validate_mocks(void);
struct input___store_write_s_in {
    long long field;
    long long value;
};
static void input___store_write_s(struct input___store_write_s_in __koru_in);

static long long app_ops_peek(void) {
    return __koru_store_s.v;
}

static void app_ops_bump(void) {
    input___store_write_s((struct input___store_write_s_in){ .field = 0, .value = 42 });
}

static void std_testing_validate_mocks(void) {
    __koru_unreachable("std.testing:validate-mocks: transform/comptime tor invoked on the C lane");
}

static void input___store_write_s(struct input___store_write_s_in __koru_in) {
    long long const field = __koru_in.field;
    long long const value = __koru_in.value;
    if (field == 0) { __koru_store_s.v = value; return; }
    __koru_unreachable("__store_write_s: field index is not a column of store 's'");
}

static void koru_flow_0(void) {
    app_ops_bump();
    long long const a = app_ops_peek();
__koru_stdout_write("v="); __koru_stdout_write_i64((a)); __koru_stdout_write("\n");}

int main(void) {
    koru_flow_0();
    return 0;
}
