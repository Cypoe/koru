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
// std/store: plural store 'items' created (C lane: SoA cell + insert/insertf/inserth + take + stored-write + apply; rules/views/envwrite are the named-refusal surface); fields v: i64
static struct {
    long long v[8];
    long long len;
} __koru_store_items = {0};

static void std_io_print_impl(void);
static void app_lib_world_seed(void);
struct app_lib_world___store_insert_items_in {
    long long v;
    long long __site_line;
};
static void app_lib_world___store_insert_items(struct app_lib_world___store_insert_items_in __koru_in);
enum {
    app_lib_world___store_apply_items_tag_v,
};
struct app_lib_world___store_apply_items_res {
    int tag;
    long long v;
};
struct app_lib_world___store_apply_items_in {
    uintptr_t row;
    long long field;
    long long value_0;
};
static struct app_lib_world___store_apply_items_res app_lib_world___store_apply_items(struct app_lib_world___store_apply_items_in __koru_in);
struct app_lib_world___store_write_items_in {
    uintptr_t row;
    long long field;
    long long value_0;
};
static void app_lib_world___store_write_items(struct app_lib_world___store_write_items_in __koru_in);
struct app_lib_world___store_sweepbody_items_L9_lib_systems_ff0692_in {
    long long k;
    uintptr_t __koru_sdix_e_L9;
};
static void app_lib_world___store_sweepbody_items_L9_lib_systems_ff0692(struct app_lib_world___store_sweepbody_items_L9_lib_systems_ff0692_in __koru_in);
struct app_lib_world___store_sweepbody_items_L46_115_043_sweep_capture_across_module_boundary_input_f49189_in {
    long long __koru_srf_e_L46_v;
    uintptr_t __koru_sdix_e_L46;
};
static void app_lib_world___store_sweepbody_items_L46_115_043_sweep_capture_across_module_boundary_input_f49189(struct app_lib_world___store_sweepbody_items_L46_115_043_sweep_capture_across_module_boundary_input_f49189_in __koru_in);
static void app_lib_world___store_sweeprun_items_L46_115_043_sweep_capture_across_module_boundary_input_f49189(void);
static long long app_lib_systems_tick(void);
static void app_lib_systems_scale(void);
static void std_testing_validate_mocks(void);

static void std_io_print_impl(void) {
    __koru_unreachable("std.io:print.impl: transform/comptime tor invoked on the C lane");
}

static void app_lib_world_seed(void) {
    app_lib_world___store_insert_items((struct app_lib_world___store_insert_items_in){ .v = 10, .__site_line = 7 });
}

static void app_lib_world___store_insert_items(struct app_lib_world___store_insert_items_in __koru_in) {
    long long const v = __koru_in.v;
    long long const __site_line = __koru_in.__site_line;
if (__koru_store_items.len >= 8) __koru_unreachable("std/store: store 'items' is full (capacity 8) - declared capacity and the `| full` branch are pinned at 690_011");
const long long __koru_new_row = __koru_store_items.len;
__koru_store_items.v[__koru_new_row] = v;
__koru_store_items.len += 1;
return;

}

static struct app_lib_world___store_apply_items_res app_lib_world___store_apply_items(struct app_lib_world___store_apply_items_in __koru_in) {
    uintptr_t const row = __koru_in.row;
    long long const field = __koru_in.field;
    long long const value_0 = __koru_in.value_0;
switch (field) {
case 0: __koru_store_items.v[row] = value_0; return (struct app_lib_world___store_apply_items_res){ .tag = app_lib_world___store_apply_items_tag_v, .v = value_0 };
default: __koru_unreachable("__store_apply_items: field index is not a column of store 'items'");
}
return (struct app_lib_world___store_apply_items_res){0};

}

static void app_lib_world___store_write_items(struct app_lib_world___store_write_items_in __koru_in) {
    uintptr_t const row = __koru_in.row;
    long long const field = __koru_in.field;
    long long const value_0 = __koru_in.value_0;
    struct app_lib_world___store_apply_items_res __koru_res_1 = app_lib_world___store_apply_items((struct app_lib_world___store_apply_items_in){ .row = row, .field = field, .value_0 = value_0 });
    switch (__koru_res_1.tag) {
    case app_lib_world___store_apply_items_tag_v: {
        long long const _auto_6 = __koru_res_1.v;
        break; }
    default: break;
    }
}

static void app_lib_world___store_sweepbody_items_L9_lib_systems_ff0692(struct app_lib_world___store_sweepbody_items_L9_lib_systems_ff0692_in __koru_in) {
    long long const k = __koru_in.k;
    uintptr_t const __koru_sdix_e_L9 = __koru_in.__koru_sdix_e_L9;
    app_lib_world___store_write_items((struct app_lib_world___store_write_items_in){ .row = __koru_sdix_e_L9, .field = 0, .value_0 = __koru_store_items.v[__koru_sdix_e_L9] * k });
}

static void app_lib_world___store_sweepbody_items_L46_115_043_sweep_capture_across_module_boundary_input_f49189(struct app_lib_world___store_sweepbody_items_L46_115_043_sweep_capture_across_module_boundary_input_f49189_in __koru_in) {
    long long const __koru_srf_e_L46_v = __koru_in.__koru_srf_e_L46_v;
    uintptr_t const __koru_sdix_e_L46 = __koru_in.__koru_sdix_e_L46;
__koru_stdout_write("v "); __koru_stdout_write_i64((__koru_srf_e_L46_v)); __koru_stdout_write("\n");}

static void app_lib_world___store_sweeprun_items_L46_115_043_sweep_capture_across_module_boundary_input_f49189(void) {
{
for (long long __koru_si = 0; __koru_si < __koru_store_items.len; __koru_si++) {
long long const __koru_srf_e_L46_v = __koru_store_items.v[__koru_si];
app_lib_world___store_sweepbody_items_L46_115_043_sweep_capture_across_module_boundary_input_f49189((struct app_lib_world___store_sweepbody_items_L46_115_043_sweep_capture_across_module_boundary_input_f49189_in){ .__koru_srf_e_L46_v = __koru_srf_e_L46_v, .__koru_sdix_e_L46 = __koru_si });
}
}
return;
}

static long long app_lib_systems_tick(void) {
    return 2;
}

static void app_lib_systems_scale(void) {
    long long const k = app_lib_systems_tick();
    {
    for (long long __koru_si = 0; __koru_si < __koru_store_items.len; __koru_si++) {
    app_lib_world___store_sweepbody_items_L9_lib_systems_ff0692((struct app_lib_world___store_sweepbody_items_L9_lib_systems_ff0692_in){ .k = k, .__koru_sdix_e_L9 = __koru_si });
    }
    }
}

static void std_testing_validate_mocks(void) {
    __koru_unreachable("std.testing:validate-mocks: transform/comptime tor invoked on the C lane");
}

static void koru_flow_0(void) {
    app_lib_world_seed();
}

static void koru_flow_1(void) {
    app_lib_systems_scale();
}

static void koru_flow_2(void) {
    app_lib_world___store_sweeprun_items_L46_115_043_sweep_capture_across_module_boundary_input_f49189();
}

int main(void) {
    koru_flow_0();
    koru_flow_1();
    koru_flow_2();
    return 0;
}
