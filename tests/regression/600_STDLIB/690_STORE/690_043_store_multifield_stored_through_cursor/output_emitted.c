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
// std/store: plural store 'game' created (C lane: SoA cell + insert/insertf/inserth + take + stored-write + apply; rules/views/envwrite are the named-refusal surface); fields a: i64, b: i64
static struct {
    long long a[64];
    long long b[64];
    long long len;
} __koru_store_game = {0};

static void std_io_print_impl(void);
static void std_testing_validate_mocks(void);
enum {
    input___store_insertf_game_tag_row,
    input___store_insertf_game_tag_full,
};
struct input___store_insertf_game_res {
    int tag;
    long long row;
};
struct input___store_insertf_game_in {
    long long a;
    long long b;
    long long __site_line;
};
static struct input___store_insertf_game_res input___store_insertf_game(struct input___store_insertf_game_in __koru_in);
struct input___store_envwrite_game_in {
    uintptr_t row;
    long long field;
    long long value_0;
    long long value_1;
};
static void input___store_envwrite_game(struct input___store_envwrite_game_in __koru_in);
struct input___store_announce_game_in {
    uintptr_t row;
    long long field;
};
static void input___store_announce_game(struct input___store_announce_game_in __koru_in);
struct input___store_sweepbody_game_L18_690_043_store_multifield_stored_through_cursor_input_b2bd05_in {
    uintptr_t __koru_sdix_e_L18;
};
static void input___store_sweepbody_game_L18_690_043_store_multifield_stored_through_cursor_input_b2bd05(struct input___store_sweepbody_game_L18_690_043_store_multifield_stored_through_cursor_input_b2bd05_in __koru_in);
static void input___store_sweeprun_game_L18_690_043_store_multifield_stored_through_cursor_input_b2bd05(void);
struct input___store_sweepbody_game_L21_690_043_store_multifield_stored_through_cursor_input_b2bd05_in {
    long long __koru_srf_e_L21_a;
    long long __koru_srf_e_L21_b;
    uintptr_t __koru_sdix_e_L21;
};
static void input___store_sweepbody_game_L21_690_043_store_multifield_stored_through_cursor_input_b2bd05(struct input___store_sweepbody_game_L21_690_043_store_multifield_stored_through_cursor_input_b2bd05_in __koru_in);
static void input___store_sweeprun_game_L21_690_043_store_multifield_stored_through_cursor_input_b2bd05(void);

static void std_io_print_impl(void) {
    __koru_unreachable("std.io:print.impl: transform/comptime tor invoked on the C lane");
}

static void std_testing_validate_mocks(void) {
    __koru_unreachable("std.testing:validate-mocks: transform/comptime tor invoked on the C lane");
}

static struct input___store_insertf_game_res input___store_insertf_game(struct input___store_insertf_game_in __koru_in) {
    long long const a = __koru_in.a;
    long long const b = __koru_in.b;
    long long const __site_line = __koru_in.__site_line;
if (__koru_store_game.len >= 64) return (struct input___store_insertf_game_res){ .tag = input___store_insertf_game_tag_full };
const long long __koru_new_row = __koru_store_game.len;
__koru_store_game.a[__koru_new_row] = a;
__koru_store_game.b[__koru_new_row] = b;
__koru_store_game.len += 1;
return (struct input___store_insertf_game_res){ .tag = input___store_insertf_game_tag_row, .row = __koru_new_row };

}

static void input___store_envwrite_game(struct input___store_envwrite_game_in __koru_in) {
    uintptr_t const row = __koru_in.row;
    long long const field = __koru_in.field;
    long long const value_0 = __koru_in.value_0;
    long long const value_1 = __koru_in.value_1;
const unsigned long long __koru_mask = (unsigned long long)field;
if (__koru_mask & (1ULL << 0)) __koru_store_game.a[row] = value_0;
if (__koru_mask & (1ULL << 1)) __koru_store_game.b[row] = value_1;

}

static void input___store_announce_game(struct input___store_announce_game_in __koru_in) {
    uintptr_t const row = __koru_in.row;
    long long const field = __koru_in.field;
(void)row; (void)field;
}

static void input___store_sweepbody_game_L18_690_043_store_multifield_stored_through_cursor_input_b2bd05(struct input___store_sweepbody_game_L18_690_043_store_multifield_stored_through_cursor_input_b2bd05_in __koru_in) {
    uintptr_t const __koru_sdix_e_L18 = __koru_in.__koru_sdix_e_L18;
    input___store_envwrite_game((struct input___store_envwrite_game_in){ .row = __koru_sdix_e_L18, .field = 0x3ull, .value_0 = __koru_store_game.a[__koru_sdix_e_L18] + 1, .value_1 = __koru_store_game.b[__koru_sdix_e_L18] + 1 });
    input___store_announce_game((struct input___store_announce_game_in){ .row = __koru_sdix_e_L18, .field = 0 });
    input___store_announce_game((struct input___store_announce_game_in){ .row = __koru_sdix_e_L18, .field = 1 });
}

static void input___store_sweeprun_game_L18_690_043_store_multifield_stored_through_cursor_input_b2bd05(void) {
{
for (long long __koru_si = 0; __koru_si < __koru_store_game.len; __koru_si++) {
input___store_sweepbody_game_L18_690_043_store_multifield_stored_through_cursor_input_b2bd05((struct input___store_sweepbody_game_L18_690_043_store_multifield_stored_through_cursor_input_b2bd05_in){ .__koru_sdix_e_L18 = __koru_si });
}
}
return;
}

static void input___store_sweepbody_game_L21_690_043_store_multifield_stored_through_cursor_input_b2bd05(struct input___store_sweepbody_game_L21_690_043_store_multifield_stored_through_cursor_input_b2bd05_in __koru_in) {
    long long const __koru_srf_e_L21_a = __koru_in.__koru_srf_e_L21_a;
    long long const __koru_srf_e_L21_b = __koru_in.__koru_srf_e_L21_b;
    uintptr_t const __koru_sdix_e_L21 = __koru_in.__koru_sdix_e_L21;
__koru_stdout_write("a "); __koru_stdout_write_i64((__koru_srf_e_L21_a)); __koru_stdout_write(" b "); __koru_stdout_write_i64((__koru_srf_e_L21_b)); __koru_stdout_write("\n");}

static void input___store_sweeprun_game_L21_690_043_store_multifield_stored_through_cursor_input_b2bd05(void) {
{
for (long long __koru_si = 0; __koru_si < __koru_store_game.len; __koru_si++) {
long long const __koru_srf_e_L21_a = __koru_store_game.a[__koru_si];
long long const __koru_srf_e_L21_b = __koru_store_game.b[__koru_si];
input___store_sweepbody_game_L21_690_043_store_multifield_stored_through_cursor_input_b2bd05((struct input___store_sweepbody_game_L21_690_043_store_multifield_stored_through_cursor_input_b2bd05_in){ .__koru_srf_e_L21_a = __koru_srf_e_L21_a, .__koru_srf_e_L21_b = __koru_srf_e_L21_b, .__koru_sdix_e_L21 = __koru_si });
}
}
return;
}

static void koru_flow_0(void) {
    struct input___store_insertf_game_res __koru_res_1 = input___store_insertf_game((struct input___store_insertf_game_in){ .a = 1, .b = 10, .__site_line = 13 });
    switch (__koru_res_1.tag) {
    case input___store_insertf_game_tag_row: {
        long long const _auto_6 = __koru_res_1.row;
        break; }
    case input___store_insertf_game_tag_full: {
        break; }
    default: break;
    }
}

static void koru_flow_1(void) {
    input___store_sweeprun_game_L18_690_043_store_multifield_stored_through_cursor_input_b2bd05();
}

static void koru_flow_2(void) {
    input___store_sweeprun_game_L21_690_043_store_multifield_stored_through_cursor_input_b2bd05();
}

int main(void) {
    koru_flow_0();
    koru_flow_1();
    koru_flow_2();
    return 0;
}
