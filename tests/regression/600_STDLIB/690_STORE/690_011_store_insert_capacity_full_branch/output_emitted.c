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
// std/store: plural store 'pool' created (C lane: SoA cell + insert/insertf/inserth + take + stored-write + apply; rules/views/envwrite are the named-refusal surface); fields hp: i64
static struct {
    long long hp[2];
    long long len;
} __koru_store_pool = {0};

static void std_testing_validate_mocks(void);
enum {
    input___store_insertf_pool_tag_row,
    input___store_insertf_pool_tag_full,
};
struct input___store_insertf_pool_res {
    int tag;
    long long row;
};
struct input___store_insertf_pool_in {
    long long hp;
    long long __site_line;
};
static struct input___store_insertf_pool_res input___store_insertf_pool(struct input___store_insertf_pool_in __koru_in);

static void std_testing_validate_mocks(void) {
    __koru_unreachable("std.testing:validate-mocks: transform/comptime tor invoked on the C lane");
}

static struct input___store_insertf_pool_res input___store_insertf_pool(struct input___store_insertf_pool_in __koru_in) {
    long long const hp = __koru_in.hp;
    long long const __site_line = __koru_in.__site_line;
if (__koru_store_pool.len >= 2) return (struct input___store_insertf_pool_res){ .tag = input___store_insertf_pool_tag_full };
const long long __koru_new_row = __koru_store_pool.len;
__koru_store_pool.hp[__koru_new_row] = hp;
__koru_store_pool.len += 1;
return (struct input___store_insertf_pool_res){ .tag = input___store_insertf_pool_tag_row, .row = __koru_new_row };

}

static void koru_flow_0(void) {
    struct input___store_insertf_pool_res __koru_res_1 = input___store_insertf_pool((struct input___store_insertf_pool_in){ .hp = 1, .__site_line = 14 });
    switch (__koru_res_1.tag) {
    case input___store_insertf_pool_tag_row: {
        long long const _auto_6 = __koru_res_1.row;
__koru_stdout_write("ok"); __koru_stdout_write("\n");        break; }
    case input___store_insertf_pool_tag_full: {
__koru_stdout_write("full"); __koru_stdout_write("\n");        break; }
    default: break;
    }
}

static void koru_flow_1(void) {
    struct input___store_insertf_pool_res __koru_res_2 = input___store_insertf_pool((struct input___store_insertf_pool_in){ .hp = 2, .__site_line = 18 });
    switch (__koru_res_2.tag) {
    case input___store_insertf_pool_tag_row: {
        long long const _auto_7 = __koru_res_2.row;
__koru_stdout_write("ok"); __koru_stdout_write("\n");        break; }
    case input___store_insertf_pool_tag_full: {
__koru_stdout_write("full"); __koru_stdout_write("\n");        break; }
    default: break;
    }
}

static void koru_flow_2(void) {
    struct input___store_insertf_pool_res __koru_res_3 = input___store_insertf_pool((struct input___store_insertf_pool_in){ .hp = 3, .__site_line = 22 });
    switch (__koru_res_3.tag) {
    case input___store_insertf_pool_tag_row: {
        long long const _auto_8 = __koru_res_3.row;
__koru_stdout_write("ok"); __koru_stdout_write("\n");        break; }
    case input___store_insertf_pool_tag_full: {
__koru_stdout_write("full"); __koru_stdout_write("\n");        break; }
    default: break;
    }
}

int main(void) {
    koru_flow_0();
    koru_flow_1();
    koru_flow_2();
    return 0;
}
