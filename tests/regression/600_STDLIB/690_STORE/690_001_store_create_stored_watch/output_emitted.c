#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <errno.h>

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
static long long __koru_len_str(const char *s) { return (long long)strlen(s); }
static int __koru_streq(const char *a, const char *b) { return strcmp(a, b) == 0; }
static char *__koru_str_i64(long long v) {
    char buf[32];
    snprintf(buf, sizeof buf, "%lld", v);
    return __koru_concat(buf, "");
}
static void __koru_stdout_write_i64(long long v) { printf("%lld", v); }
static void __koru_stderr_write_i64(long long v) { fprintf(stderr, "%lld", v); }
static void __koru_stdout_write_f64(double v) { printf("%g", v); }
static void __koru_stderr_write_f64(double v) { fprintf(stderr, "%g", v); }
static void __koru_stdout_write_f64_prec(double v, int prec) { printf("%.*f", prec, v); }
static void __koru_stderr_write_f64_prec(double v, int prec) { fprintf(stderr, "%.*f", prec, v); }
static int __koru_argc;
static char **__koru_argv;
static char __koru_readln_buf[8192];
struct __koru_comptime_Expression { char __koru_comptime; };
struct __koru_comptime_Source { char __koru_comptime; };
static _Noreturn void __koru_unreachable(const char *what) {
    fflush(NULL); // buffered stdout must land before the trap (zig flushes; abort does not)
    fprintf(stderr, "koru: %s\n", what);
    abort();
}
static long long __koru_intcast(long long v, long long lo, long long hi) {
    if (v < lo || v > hi) __koru_unreachable("@intCast out of range");
    return v;
}
static unsigned long long __koru_intcast_u(unsigned long long v, unsigned long long lo, unsigned long long hi) {
    if (v < lo || v > hi) __koru_unreachable("@intCast out of range");
    return v;
}
static long long __koru_max_ll(long long a, long long b) { return a > b ? a : b; }
static long long __koru_min_ll(long long a, long long b) { return a < b ? a : b; }
struct __koru_slice_const_struct_Item { const struct Item *ptr; uintptr_t len; };
// std/store: 'game' created (cell + write-subflow at module scope); fields entities: i64
static struct { long long entities; } __koru_store_game = { .entities = 0 };
static void std_io_print_impl(void);
static void std_testing_validate_mocks(void);
struct input___store_write_game_in {
    long long field;
    long long value;
};
static void input___store_write_game(struct input___store_write_game_in __koru_in);
struct input___store_watch_game_entities_0_in {
    long long e;
};
static void input___store_watch_game_entities_0(struct input___store_watch_game_entities_0_in __koru_in);

static void std_io_print_impl(void) {
    __koru_unreachable("std.io:print.impl: transform/comptime tor invoked on the C lane");
}

static void std_testing_validate_mocks(void) {
    __koru_unreachable("std.testing:validate-mocks: transform/comptime tor invoked on the C lane");
}

static void input___store_write_game(struct input___store_write_game_in __koru_in) {
    long long const field = __koru_in.field;
    long long const value = __koru_in.value;
    if (field == 0) { __koru_store_game.entities = value; input___store_watch_game_entities_0((struct input___store_watch_game_entities_0_in){ .e = value }); return; }
    __koru_unreachable("__store_write_game: field index is not a column of store 'game'");
}

static void input___store_watch_game_entities_0(struct input___store_watch_game_entities_0_in __koru_in) {
    long long const e = __koru_in.e;
__koru_stdout_write("entities: "); __koru_stdout_write_i64((e)); __koru_stdout_write("\n");}

static void koru_flow_0(void) {
    input___store_write_game((struct input___store_write_game_in){ .field = 0, .value = __koru_store_game.entities + 1 });
}

static void koru_flow_1(void) {
    input___store_write_game((struct input___store_write_game_in){ .field = 0, .value = __koru_store_game.entities + 1 });
}

int main(int argc, char **argv) {
    __koru_argc = argc;
    __koru_argv = argv;
    koru_flow_0();
    koru_flow_1();
    return 0;
}
