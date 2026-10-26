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
// std/store: plural store 'bodies' created (C lane: SoA cell + insert/insertf/inserth + take + stored-write + apply; rules/views/envwrite are the named-refusal surface); fields x: f32, big: f64
static struct {
    double x[4];
    double big[4];
    long long len;
} __koru_store_bodies = {0};

static void std_io_print_impl(void);
static void std_testing_validate_mocks(void);
struct input___store_insert_bodies_in {
    double x;
    double big;
    long long __site_line;
};
static void input___store_insert_bodies(struct input___store_insert_bodies_in __koru_in);
enum {
    input___store_apply_bodies_tag_x,
    input___store_apply_bodies_tag_big,
};
struct input___store_apply_bodies_res {
    int tag;
    double x;
    double big;
};
struct input___store_apply_bodies_in {
    uintptr_t row;
    long long field;
    double value_0;
    double value_1;
};
static struct input___store_apply_bodies_res input___store_apply_bodies(struct input___store_apply_bodies_in __koru_in);
struct input___store_write_bodies_in {
    uintptr_t row;
    long long field;
    double value_0;
    double value_1;
};
static void input___store_write_bodies(struct input___store_write_bodies_in __koru_in);
struct input___store_sweepbody_bodies_L32_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71_in {
    uintptr_t __koru_sdix_b_L32;
};
static void input___store_sweepbody_bodies_L32_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71(struct input___store_sweepbody_bodies_L32_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71_in __koru_in);
static void input___store_sweeprun_bodies_L32_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71(void);
struct input___store_sweepbody_bodies_L35_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71_in {
    uintptr_t __koru_sdix_b_L35;
};
static void input___store_sweepbody_bodies_L35_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71(struct input___store_sweepbody_bodies_L35_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71_in __koru_in);
static void input___store_sweeprun_bodies_L35_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71(void);
struct input___store_sweepbody_bodies_L38_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71_in {
    uintptr_t __koru_sdix_b_L38;
};
static void input___store_sweepbody_bodies_L38_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71(struct input___store_sweepbody_bodies_L38_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71_in __koru_in);
static void input___store_sweeprun_bodies_L38_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71(void);
struct input___store_sweepbody_bodies_L41_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71_in {
    uintptr_t __koru_sdix_b_L41;
};
static void input___store_sweepbody_bodies_L41_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71(struct input___store_sweepbody_bodies_L41_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71_in __koru_in);
static void input___store_sweeprun_bodies_L41_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71(void);

static void std_io_print_impl(void) {
    __koru_unreachable("std.io:print.impl: transform/comptime tor invoked on the C lane");
}

static void std_testing_validate_mocks(void) {
    __koru_unreachable("std.testing:validate-mocks: transform/comptime tor invoked on the C lane");
}

static void input___store_insert_bodies(struct input___store_insert_bodies_in __koru_in) {
    double const x = __koru_in.x;
    double const big = __koru_in.big;
    long long const __site_line = __koru_in.__site_line;
if (__koru_store_bodies.len >= 4) __koru_unreachable("std/store: store 'bodies' is full (capacity 4) - declared capacity and the `| full` branch are pinned at 690_011");
const long long __koru_new_row = __koru_store_bodies.len;
__koru_store_bodies.x[__koru_new_row] = x;
__koru_store_bodies.big[__koru_new_row] = big;
__koru_store_bodies.len += 1;
return;

}

static struct input___store_apply_bodies_res input___store_apply_bodies(struct input___store_apply_bodies_in __koru_in) {
    uintptr_t const row = __koru_in.row;
    long long const field = __koru_in.field;
    double const value_0 = __koru_in.value_0;
    double const value_1 = __koru_in.value_1;
switch (field) {
case 0: __koru_store_bodies.x[row] = value_0; return (struct input___store_apply_bodies_res){ .tag = input___store_apply_bodies_tag_x, .x = value_0 };
case 1: __koru_store_bodies.big[row] = value_1; return (struct input___store_apply_bodies_res){ .tag = input___store_apply_bodies_tag_big, .big = value_1 };
default: __koru_unreachable("__store_apply_bodies: field index is not a column of store 'bodies'");
}
return (struct input___store_apply_bodies_res){0};

}

static void input___store_write_bodies(struct input___store_write_bodies_in __koru_in) {
    uintptr_t const row = __koru_in.row;
    long long const field = __koru_in.field;
    double const value_0 = __koru_in.value_0;
    double const value_1 = __koru_in.value_1;
    struct input___store_apply_bodies_res __koru_res_1 = input___store_apply_bodies((struct input___store_apply_bodies_in){ .row = row, .field = field, .value_0 = value_0, .value_1 = value_1 });
    switch (__koru_res_1.tag) {
    case input___store_apply_bodies_tag_x: {
        double const _auto_6 = __koru_res_1.x;
        break; }
    case input___store_apply_bodies_tag_big: {
        double const _auto_7 = __koru_res_1.big;
        break; }
    default: break;
    }
}

static void input___store_sweepbody_bodies_L32_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71(struct input___store_sweepbody_bodies_L32_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71_in __koru_in) {
    uintptr_t const __koru_sdix_b_L32 = __koru_in.__koru_sdix_b_L32;
    input___store_write_bodies((struct input___store_write_bodies_in){ .row = __koru_sdix_b_L32, .field = 1, .value_0 = 0.0, .value_1 = __koru_store_bodies.x[__koru_sdix_b_L32] });
}

static void input___store_sweeprun_bodies_L32_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71(void) {
{
for (long long __koru_si = 0; __koru_si < __koru_store_bodies.len; __koru_si++) {
input___store_sweepbody_bodies_L32_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71((struct input___store_sweepbody_bodies_L32_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71_in){ .__koru_sdix_b_L32 = __koru_si });
}
}
return;
}

static void input___store_sweepbody_bodies_L35_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71(struct input___store_sweepbody_bodies_L35_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71_in __koru_in) {
    uintptr_t const __koru_sdix_b_L35 = __koru_in.__koru_sdix_b_L35;
    input___store_write_bodies((struct input___store_write_bodies_in){ .row = __koru_sdix_b_L35, .field = 0, .value_0 = 1.5, .value_1 = 0.0 });
}

static void input___store_sweeprun_bodies_L35_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71(void) {
{
for (long long __koru_si = 0; __koru_si < __koru_store_bodies.len; __koru_si++) {
input___store_sweepbody_bodies_L35_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71((struct input___store_sweepbody_bodies_L35_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71_in){ .__koru_sdix_b_L35 = __koru_si });
}
}
return;
}

static void input___store_sweepbody_bodies_L38_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71(struct input___store_sweepbody_bodies_L38_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71_in __koru_in) {
    uintptr_t const __koru_sdix_b_L38 = __koru_in.__koru_sdix_b_L38;
    input___store_write_bodies((struct input___store_write_bodies_in){ .row = __koru_sdix_b_L38, .field = 0, .value_0 = 0.1, .value_1 = 0.0 });
}

static void input___store_sweeprun_bodies_L38_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71(void) {
{
for (long long __koru_si = 0; __koru_si < __koru_store_bodies.len; __koru_si++) {
input___store_sweepbody_bodies_L38_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71((struct input___store_sweepbody_bodies_L38_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71_in){ .__koru_sdix_b_L38 = __koru_si });
}
}
return;
}

static void input___store_sweepbody_bodies_L41_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71(struct input___store_sweepbody_bodies_L41_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71_in __koru_in) {
    uintptr_t const __koru_sdix_b_L41 = __koru_in.__koru_sdix_b_L41;
    input___store_write_bodies((struct input___store_write_bodies_in){ .row = __koru_sdix_b_L41, .field = 1, .value_0 = 0.0, .value_1 = 16777217 });
}

static void input___store_sweeprun_bodies_L41_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71(void) {
{
for (long long __koru_si = 0; __koru_si < __koru_store_bodies.len; __koru_si++) {
input___store_sweepbody_bodies_L41_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71((struct input___store_sweepbody_bodies_L41_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71_in){ .__koru_sdix_b_L41 = __koru_si });
}
}
return;
}

static void koru_flow_0(void) {
    input___store_insert_bodies((struct input___store_insert_bodies_in){ .x = 1.5, .big = 2.25, .__site_line = 29 });
}

static void koru_flow_1(void) {
    input___store_sweeprun_bodies_L32_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71();
}

static void koru_flow_2(void) {
    input___store_sweeprun_bodies_L35_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71();
}

static void koru_flow_3(void) {
    input___store_sweeprun_bodies_L38_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71();
}

static void koru_flow_4(void) {
    input___store_sweeprun_bodies_L41_690_378_witness_marks_ride_lowered_stored_writes_input_4cff71();
}

static void koru_flow_5(void) {
__koru_stdout_write("done"); __koru_stdout_write("\n");}

int main(void) {
    koru_flow_0();
    koru_flow_1();
    koru_flow_2();
    koru_flow_3();
    koru_flow_4();
    koru_flow_5();
    return 0;
}
