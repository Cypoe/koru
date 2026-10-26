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
// std/store: plural store 'cells' created (C lane: SoA cell + insert/insertf/inserth + take + stored-write + apply; rules/views/envwrite are the named-refusal surface); fields v: i64, next: i64
// std/store: 'head' created (cell + write-subflow at module scope); fields h: i64
// std/store: 'probe' created (cell + write-subflow at module scope); fields v1: i64
static struct {
    long long v[8];
    long long next[8];
    long long __koru_hslot_row[8];
    unsigned int __koru_hslot_gen[8];
    long long __koru_row_hslot[8];
    long long __koru_hslot_free[8];
    long long __koru_hslot_free_len;
    long long __koru_hslot_next;
    int __koru_ident;
    int __koru_gen0;
    long long len;
} __koru_store_cells = { .__koru_ident = 1, .__koru_gen0 = 1 };
static const long long __koru_brand_cells = 1;
static void __koru_materialize_cells(void) {
    if (!__koru_store_cells.__koru_ident) return;
    for (long long __koru_i = 0; __koru_i < __koru_store_cells.len; __koru_i++) {
        __koru_store_cells.__koru_hslot_row[__koru_i] = __koru_i;
        __koru_store_cells.__koru_row_hslot[__koru_i] = __koru_i;
    }
    __koru_store_cells.__koru_ident = 0;
}
static long long __koru_row_of_cells(long long h) {
    if (h < 0) return -1;
    const unsigned long long u = (unsigned long long)h;
    const unsigned int slot32 = (unsigned int)u;
    if ((slot32 >> 24) != (unsigned int)__koru_brand_cells) return -1;
    const long long slot = (long long)(slot32 & 0xFFFFFFu);
    if (slot >= __koru_store_cells.__koru_hslot_next) return -1;
    if (__koru_store_cells.__koru_gen0) { if ((u >> 32) != 0) return -1; return slot; }
    if ((unsigned int)(u >> 32) != __koru_store_cells.__koru_hslot_gen[slot]) return -1;
    if (__koru_store_cells.__koru_ident) return slot;
    const long long r = __koru_store_cells.__koru_hslot_row[slot];
    if (r >= __koru_store_cells.len) return -1;
    return r;
}
static long long __koru_handle_of_cells(long long dense) {
    if (__koru_store_cells.__koru_gen0) return dense | (__koru_brand_cells << 24);
    long long slot = dense;
    if (!__koru_store_cells.__koru_ident) slot = __koru_store_cells.__koru_row_hslot[dense];
    return (slot | (__koru_brand_cells << 24)) | (((long long)__koru_store_cells.__koru_hslot_gen[slot]) << 32);
}
static long long __koru_resolve_cells(long long h) {
    if (h >= 0) {
        const unsigned long long u = (unsigned long long)h;
        const unsigned int slot32 = (unsigned int)u;
        if ((slot32 >> 24) != (unsigned int)__koru_brand_cells) __koru_unreachable("std/store: 'cells[...]' does not address a row - the value is not a handle this store issued (handles come from `| row` and row cursors)");
        const long long slot = (long long)(slot32 & 0xFFFFFFu);
        if (__koru_store_cells.__koru_gen0) {
            if ((u >> 32) != 0 && slot < __koru_store_cells.__koru_hslot_next) __koru_unreachable("std/store: stale row handle into store 'cells' - the row it addressed was removed (stale-handle trap pinned at 690_115)");
        } else if (slot < __koru_store_cells.__koru_hslot_next && (unsigned int)(u >> 32) != __koru_store_cells.__koru_hslot_gen[slot]) {
            __koru_unreachable("std/store: stale row handle into store 'cells' - the row it addressed was removed (stale-handle trap pinned at 690_115)");
        }
    }
    const long long r = __koru_row_of_cells(h);
    if (r < 0) __koru_unreachable("std/store: 'cells[...]' does not address a row - the value is not a handle this store issued (handles come from `| row` and row cursors)");
    return r;
}

static struct { long long h; } __koru_store_head = { .h = -1 };
static struct { long long v1; } __koru_store_probe = { .v1 = 0 };
static void app_lib_world_seed(void);
static void app_lib_world_peek(void);
enum {
    app_lib_world___store_apply_cells_tag_v,
    app_lib_world___store_apply_cells_tag_next,
};
struct app_lib_world___store_apply_cells_res {
    int tag;
    long long v;
    long long next;
};
struct app_lib_world___store_apply_cells_in {
    uintptr_t row;
    long long field;
    long long value_0;
    long long value_1;
};
static struct app_lib_world___store_apply_cells_res app_lib_world___store_apply_cells(struct app_lib_world___store_apply_cells_in __koru_in);
enum {
    app_lib_world___store_insertf_cells_tag_row,
    app_lib_world___store_insertf_cells_tag_full,
};
struct app_lib_world___store_insertf_cells_res {
    int tag;
    long long row;
};
struct app_lib_world___store_insertf_cells_in {
    long long v;
    long long next;
    long long __site_line;
};
static struct app_lib_world___store_insertf_cells_res app_lib_world___store_insertf_cells(struct app_lib_world___store_insertf_cells_in __koru_in);
struct app_lib_world___store_write_cells_in {
    uintptr_t row;
    long long field;
    long long value_0;
    long long value_1;
};
static void app_lib_world___store_write_cells(struct app_lib_world___store_write_cells_in __koru_in);
struct app_lib_world___store_write_head_in {
    long long field;
    long long value;
};
static void app_lib_world___store_write_head(struct app_lib_world___store_write_head_in __koru_in);
struct app_lib_world___store_write_probe_in {
    long long field;
    long long value;
};
static void app_lib_world___store_write_probe(struct app_lib_world___store_write_probe_in __koru_in);
struct app_lib_world___store_sweepbody_cells_L10_lib_systems_d08031_in {
    long long k;
    long long h;
    uintptr_t __koru_sdix_e_L10;
};
static void app_lib_world___store_sweepbody_cells_L10_lib_systems_d08031(struct app_lib_world___store_sweepbody_cells_L10_lib_systems_d08031_in __koru_in);
static long long app_lib_systems_tick(void);
static void app_lib_systems_scale_and_link(void);
static void std_testing_validate_mocks(void);

static void app_lib_world_seed(void) {
    struct app_lib_world___store_insertf_cells_res __koru_res_1 = app_lib_world___store_insertf_cells((struct app_lib_world___store_insertf_cells_in){ .v = 10, .next = -1, .__site_line = 10 });
    switch (__koru_res_1.tag) {
    case app_lib_world___store_insertf_cells_tag_row: {
        long long const _auto_6 = __koru_res_1.row;
        struct app_lib_world___store_insertf_cells_res __koru_res_2 = app_lib_world___store_insertf_cells((struct app_lib_world___store_insertf_cells_in){ .v = 20, .next = -1, .__site_line = 11 });
        switch (__koru_res_2.tag) {
        case app_lib_world___store_insertf_cells_tag_row: {
            long long const _auto_7 = __koru_res_2.row;
            struct app_lib_world___store_insertf_cells_res __koru_res_3 = app_lib_world___store_insertf_cells((struct app_lib_world___store_insertf_cells_in){ .v = 30, .next = -1, .__site_line = 12 });
            switch (__koru_res_3.tag) {
            case app_lib_world___store_insertf_cells_tag_row: {
                long long const _auto_8 = __koru_res_3.row;
                break; }
            case app_lib_world___store_insertf_cells_tag_full: {
                break; }
            default: break;
            }
            break; }
        case app_lib_world___store_insertf_cells_tag_full: {
            break; }
        default: break;
        }
        break; }
    case app_lib_world___store_insertf_cells_tag_full: {
        break; }
    default: break;
    }
}

static void app_lib_world_peek(void) {
    app_lib_world___store_write_probe((struct app_lib_world___store_write_probe_in){ .field = 0, .value = __koru_store_cells.v[__koru_resolve_cells(__koru_store_head.h)] });
__koru_stdout_write("head v "); __koru_stdout_write_i64((__koru_store_probe.v1)); __koru_stdout_write("\n");}

static struct app_lib_world___store_apply_cells_res app_lib_world___store_apply_cells(struct app_lib_world___store_apply_cells_in __koru_in) {
    uintptr_t const row = __koru_in.row;
    long long const field = __koru_in.field;
    long long const value_0 = __koru_in.value_0;
    long long const value_1 = __koru_in.value_1;
switch (field) {
case 0: __koru_store_cells.v[row] = value_0; return (struct app_lib_world___store_apply_cells_res){ .tag = app_lib_world___store_apply_cells_tag_v, .v = value_0 };
case 1: __koru_store_cells.next[row] = value_1; return (struct app_lib_world___store_apply_cells_res){ .tag = app_lib_world___store_apply_cells_tag_next, .next = value_1 };
default: __koru_unreachable("__store_apply_cells: field index is not a column of store 'cells'");
}
return (struct app_lib_world___store_apply_cells_res){0};

}

static struct app_lib_world___store_insertf_cells_res app_lib_world___store_insertf_cells(struct app_lib_world___store_insertf_cells_in __koru_in) {
    long long const v = __koru_in.v;
    long long const next = __koru_in.next;
    long long const __site_line = __koru_in.__site_line;
if (__koru_store_cells.len >= 8) return (struct app_lib_world___store_insertf_cells_res){ .tag = app_lib_world___store_insertf_cells_tag_full };
const long long __koru_new_row = __koru_store_cells.len;
long long __koru_hslot;
if (__koru_store_cells.__koru_hslot_free_len > 0) {
    __koru_store_cells.__koru_hslot_free_len -= 1;
    __koru_hslot = __koru_store_cells.__koru_hslot_free[__koru_store_cells.__koru_hslot_free_len];
} else {
    __koru_hslot = __koru_store_cells.__koru_hslot_next;
    __koru_store_cells.__koru_hslot_next += 1;
}
if (!__koru_store_cells.__koru_ident) {
    __koru_store_cells.__koru_hslot_row[__koru_hslot] = __koru_new_row;
    __koru_store_cells.__koru_row_hslot[__koru_new_row] = __koru_hslot;
}
__koru_store_cells.v[__koru_new_row] = v;
__koru_store_cells.next[__koru_new_row] = next;
__koru_store_cells.len += 1;
return (struct app_lib_world___store_insertf_cells_res){ .tag = app_lib_world___store_insertf_cells_tag_row, .row = __koru_handle_of_cells(__koru_new_row) };

}

static void app_lib_world___store_write_cells(struct app_lib_world___store_write_cells_in __koru_in) {
    uintptr_t const row = __koru_in.row;
    long long const field = __koru_in.field;
    long long const value_0 = __koru_in.value_0;
    long long const value_1 = __koru_in.value_1;
    struct app_lib_world___store_apply_cells_res __koru_res_4 = app_lib_world___store_apply_cells((struct app_lib_world___store_apply_cells_in){ .row = row, .field = field, .value_0 = value_0, .value_1 = value_1 });
    switch (__koru_res_4.tag) {
    case app_lib_world___store_apply_cells_tag_v: {
        long long const _auto_9 = __koru_res_4.v;
        break; }
    case app_lib_world___store_apply_cells_tag_next: {
        long long const _auto_10 = __koru_res_4.next;
        break; }
    default: break;
    }
}

static void app_lib_world___store_write_head(struct app_lib_world___store_write_head_in __koru_in) {
    long long const field = __koru_in.field;
    long long const value = __koru_in.value;
    if (field == 0) { __koru_store_head.h = value; return; }
    __koru_unreachable("__store_write_head: field index is not a column of store 'head'");
}

static void app_lib_world___store_write_probe(struct app_lib_world___store_write_probe_in __koru_in) {
    long long const field = __koru_in.field;
    long long const value = __koru_in.value;
    if (field == 0) { __koru_store_probe.v1 = value; return; }
    __koru_unreachable("__store_write_probe: field index is not a column of store 'probe'");
}

static void app_lib_world___store_sweepbody_cells_L10_lib_systems_d08031(struct app_lib_world___store_sweepbody_cells_L10_lib_systems_d08031_in __koru_in) {
    long long const k = __koru_in.k;
    long long const h = __koru_in.h;
    uintptr_t const __koru_sdix_e_L10 = __koru_in.__koru_sdix_e_L10;
    app_lib_world___store_write_cells((struct app_lib_world___store_write_cells_in){ .row = __koru_sdix_e_L10, .field = 0, .value_0 = __koru_store_cells.v[__koru_sdix_e_L10] * k, .value_1 = 0 });
    app_lib_world___store_write_cells((struct app_lib_world___store_write_cells_in){ .row = __koru_sdix_e_L10, .field = 1, .value_0 = 0, .value_1 = __koru_store_head.h });
    app_lib_world___store_write_head((struct app_lib_world___store_write_head_in){ .field = 0, .value = h });
}

static long long app_lib_systems_tick(void) {
    return 2;
}

static void app_lib_systems_scale_and_link(void) {
    long long const k = app_lib_systems_tick();
    {
    for (long long __koru_si = 0; __koru_si < __koru_store_cells.len; __koru_si++) {
    app_lib_world___store_sweepbody_cells_L10_lib_systems_d08031((struct app_lib_world___store_sweepbody_cells_L10_lib_systems_d08031_in){ .k = k, .h = __koru_handle_of_cells(__koru_si), .__koru_sdix_e_L10 = __koru_si });
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
    app_lib_systems_scale_and_link();
}

static void koru_flow_2(void) {
    app_lib_world_peek();
}

int main(void) {
    koru_flow_0();
    koru_flow_1();
    koru_flow_2();
    return 0;
}
