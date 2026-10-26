// spike — a hand-built Koru scope module (`.dylib`), the mounted-scope
// proof for 440_056. Three verbs:
//
//   touch(handle: *Note<opened>)  — borrows a handle the BOUND scope
//                                   minted, reads through the pointer the
//                                   pool resolves. Cross-scope param.
//   seal(label: string) -> *Stamp<sealed!>
//                                 — mints an obligation inside the dylib:
//                                   the pool token comes back from the
//                                   host, the custody record is booked by
//                                   the interpreter from the spec table
//                                   below.
//   unseal(stamp: *Stamp<!sealed>) — consumes it. Called mid-session or
//                                   swept at hang-up through THIS module's
//                                   dispatcher — the cross-scope discharge
//                                   proof.
//
// The shape mirrors what a `register` block emits for a compiled scope:
// one dispatcher over Invocation/DispatchResult, and the lookup tables
// the enforcement, gate, prompt, and sweep all read — nothing here is a
// second path.

const std = @import("std");
const abi = @import("module_abi.zig");

// The resource mirrors. `Note`'s layout is the bound scope's struct
// field-for-field — the pool hands back the very pointer `open` minted;
// `Stamp` exists only inside this module.
const Note = struct { text: []const u8 };
const Stamp = struct { label: []const u8 };

var host: abi.MountedHostServices = undefined;
var scratch = std.heap.page_allocator;

fn getArg(args: []const abi.Arg, name: []const u8) ?[]const u8 {
    for (args) |a| {
        if (std.mem.eql(u8, a.name, name)) return a.value;
    }
    return null;
}

fn dispatchTouch(inv: *const abi.Invocation, out: *abi.DispatchResult) !void {
    const tok = getArg(inv.args, "handle") orelse return error.MissingArg;
    const raw = host.resolve_dispatch_resource(tok) orelse {
        host.set_dispatch_detail("touch: handle names nothing the session holds");
        return error.DispatchFailed;
    };
    const note: *Note = @ptrCast(@alignCast(raw));
    const S = struct { threadlocal var fields: [1]abi.NamedField = undefined; };
    const text = std.fmt.allocPrint(scratch, "touched:{s}", .{note.text}) catch return error.OutOfMemory;
    S.fields[0] = .{ .name = "__type_ref", .value = .{ .string_val = text } };
    out.* = .{ .branch = "", .fields = S.fields[0..1] };
}

fn dispatchSeal(inv: *const abi.Invocation, out: *abi.DispatchResult) !void {
    const label = getArg(inv.args, "label") orelse return error.MissingArg;
    const stamp = scratch.create(Stamp) catch return error.OutOfMemory;
    stamp.* = .{ .label = scratch.dupe(u8, label) catch return error.OutOfMemory };
    const token = host.register_dispatch_resource("Stamp", stamp);
    const S = struct { threadlocal var fields: [1]abi.NamedField = undefined; };
    S.fields[0] = .{ .name = "__type_ref", .value = .{ .string_val = token } };
    out.* = .{ .branch = "", .fields = S.fields[0..1] };
}

fn dispatchUnseal(inv: *const abi.Invocation, out: *abi.DispatchResult) !void {
    const tok = getArg(inv.args, "stamp") orelse return error.MissingArg;
    const raw = host.resolve_dispatch_resource(tok) orelse {
        host.set_dispatch_detail("unseal: stamp names nothing the session holds");
        return error.DispatchFailed;
    };
    const stamp: *Stamp = @ptrCast(@alignCast(raw));
    scratch.free(stamp.label);
    scratch.destroy(stamp);
    out.* = .{ .branch = "", .fields = &.{} };
}

// -- the scope tables --

const event_names = [_][]const u8{ "touch", "seal", "unseal" };

const touch_input = [_]abi.InputFieldSpec{
    .{ .name = "handle", .type_name = "*Note", .phantom = "opened" },
};
const seal_input = [_]abi.InputFieldSpec{
    .{ .name = "label", .type_name = "string" },
};
const unseal_input = [_]abi.InputFieldSpec{
    .{ .name = "stamp", .type_name = "*Stamp", .phantom = "!sealed" },
};

const seal_creates = [_]abi.CreateSpec{
    .{ .obligation_module = "spike", .obligation_name = "sealed", .field_name = "__type_ref", .resource_type = "Stamp" },
};
const unseal_discharges = [_]abi.DischargeSpec{
    .{ .obligation_module = "spike", .obligation_name = "sealed", .arg_name = "stamp" },
};

fn eventsFn() []const []const u8 {
    return &event_names;
}

fn inputFn(name: []const u8) ?[]const abi.InputFieldSpec {
    if (std.mem.eql(u8, name, "touch")) return &touch_input;
    if (std.mem.eql(u8, name, "seal")) return &seal_input;
    if (std.mem.eql(u8, name, "unseal")) return &unseal_input;
    return null;
}

fn createsSpecFn(name: []const u8) []const abi.CreateSpec {
    if (std.mem.eql(u8, name, "seal")) return &seal_creates;
    return &.{};
}

fn dischargesSpecFn(name: []const u8) []const abi.DischargeSpec {
    if (std.mem.eql(u8, name, "unseal")) return &unseal_discharges;
    return &.{};
}

fn dischargeEventFn(obligation: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, obligation, "sealed")) return "unseal";
    return null;
}

fn branchesFn(name: []const u8) []const abi.BranchSpec {
    _ = name;
    return &.{};
}

fn costFn(name: []const u8) u64 {
    _ = name;
    return 1;
}

fn docFn(name: []const u8) []const u8 {
    if (std.mem.eql(u8, name, "touch")) return "read a held note (borrow, mounted)";
    if (std.mem.eql(u8, name, "seal")) return "mint a sealed stamp (mounted)";
    if (std.mem.eql(u8, name, "unseal")) return "discharge a sealed stamp (mounted)";
    return "";
}

fn dispatcher(inv: *const abi.Invocation, out: *abi.DispatchResult) anyerror!void {
    const name = if (inv.path.segments.len > 0) inv.path.segments[0] else "";
    if (std.mem.eql(u8, name, "touch")) return dispatchTouch(inv, out);
    if (std.mem.eql(u8, name, "seal")) return dispatchSeal(inv, out);
    if (std.mem.eql(u8, name, "unseal")) return dispatchUnseal(inv, out);
    return error.EventDenied;
}

const spike_scope = abi.ScopeRuntime{
    .name = "spike",
    .dispatcher = &dispatcher,
    .cost_fn = &costFn,
    .creates_obligations_fn = null,
    .discharges_obligations_fn = null,
    .discharge_event_fn = &dischargeEventFn,
    .creates_spec_fn = &createsSpecFn,
    .discharges_spec_fn = &dischargesSpecFn,
    .branches_fn = &branchesFn,
    .events_fn = &eventsFn,
    .input_fn = &inputFn,
    .doc_fn = &docFn,
    .manifest = null,
};

// The one exported symbol mount looks up: hand the module the host's
// service table, get the scope's vtable back. The version check is the
// whole compat story — same toolchain or no mount.
export fn koru_module_init(services: *const abi.MountedHostServices) ?*const abi.ScopeRuntime {
    if (services.abi_version != abi.KORU_MOUNTED_ABI_VERSION) return null;
    host = services.*;
    return &spike_scope;
}
