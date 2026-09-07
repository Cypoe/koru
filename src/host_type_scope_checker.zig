const std = @import("std");
const ast = @import("ast");
const errors = @import("errors");
const type_registry = @import("type_registry");

/// Refuse a BARE host (Zig) type reference that crosses a module boundary.
///
/// A host type name is bare inside the module that declares it; across a
/// module boundary the signature spells it fully qualified — `*app/holder:Token`
/// — the same discipline invocations already follow. Bare cross-module names
/// used to resolve program-wide, first declaration wins, and a consumer's
/// import order rewrote a bystander module's own signatures; the spelling is
/// retired (220_031, ruled 2026-09-06).
///
/// Module-local bare stays legal, and so does the program top level's own bare
/// spelling: the writer is checked against the SET of declaring modules
/// (HostTypeDeclSites), not the first-wins winner — on a two-provider
/// collision the writer's own declaration still licenses its bare form.
///
/// What is NOT a refusal site:
///   - already-qualified spellings (`*std/string:String`) — they carry the
///     qualifier in the AST (`field.module_path`, or a `:` inside a
///     return/resume type string) and are the ruled fix, not the fault;
///   - parser-intrinsic types (`Source`, `File`, `Expression`, ...) — keywords,
///     not host-type references;
///   - names no module declares — the backend owns those.
pub const CheckError = error{OutOfMemory};

const TypePrefixes = [_][]const u8{ "[]const ", "?*const ", "*const ", "[]", "?*", "?", "*" };

const Intrinsics = [_][]const u8{ "Source", "File", "EmbedFile", "Expression", "InvocationMeta" };

/// Compiler-owned transform-ABI names that behave as keywords in RETURN
/// positions: the machinery string-matches them BARE (main.zig's
/// returns_program detects `-> Program` / `-> SiteResult` by substring;
/// emitter_helpers' ast_return_types lowers the bare form to `__koru_ast.X`).
/// They are protocol spellings of the compiler's own contract, not
/// module-owned host types — refusing them would break the transform ABI the
/// pins depend on (210_054's `-> *const Program` is load-bearing). PARAM
/// positions stay ruled-strict: `program: *std/compiler:Program` is the
/// migrated spelling and works (proven across the 2026-09-06 board).
const AbiReturnTypes = [_][]const u8{
    "ExplainReport", "SiteResult", "Program", "Item", "Source",
    "Invocation",    "EventDecl",  "ProcDecl", "Flow", "Branch",
    "Continuation",  "ASTNode",
};

pub fn check(allocator: std.mem.Allocator, items: []const ast.Item, reporter: *errors.ErrorReporter) CheckError!void {
    var sites = try type_registry.buildHostTypeDeclSites(allocator, items);
    defer type_registry.deinitHostTypeDeclSites(allocator, &sites);
    try checkItems(allocator, items, "", &sites, reporter);
}

fn checkItems(
    allocator: std.mem.Allocator,
    items: []const ast.Item,
    enclosing_module: []const u8,
    sites: *const type_registry.HostTypeDeclSites,
    reporter: *errors.ErrorReporter,
) CheckError!void {
    for (items) |item| {
        switch (item) {
            .event_decl => |ev| try checkEvent(&ev, enclosing_module, sites, reporter),
            .module_decl => |m| try checkItems(allocator, m.items, m.logical_name, sites, reporter),
            else => {},
        }
    }
}

fn checkEvent(
    event: *const ast.EventDecl,
    writer_module: []const u8,
    sites: *const type_registry.HostTypeDeclSites,
    reporter: *errors.ErrorReporter,
) CheckError!void {
    try checkShape(event.input.fields, writer_module, sites, reporter, event.location);
    for (event.branches) |branch| {
        try checkShape(branch.payload.fields, writer_module, sites, reporter, event.location);
        try checkTypeString(branch.resume_type, writer_module, sites, reporter, event.location);
        if (branch.resume_arms) |arms| {
            for (arms) |arm| try checkTypeString(arm.type, writer_module, sites, reporter, event.location);
        }
    }
    try checkTypeString(event.return_type, writer_module, sites, reporter, event.location);
}

fn checkShape(
    fields: []const ast.Field,
    writer_module: []const u8,
    sites: *const type_registry.HostTypeDeclSites,
    reporter: *errors.ErrorReporter,
    location: errors.SourceLocation,
) CheckError!void {
    for (fields) |field| {
        if (field.is_source or field.is_file or field.is_embed_file or
            field.is_expression or field.is_invocation_meta) continue;
        // The qualified spelling carries its module in the AST — that IS the
        // fix, never the fault.
        if (field.module_path != null) continue;
        try checkTypeString(field.type, writer_module, sites, reporter, location);
    }
}

/// Check a type spelled as a bare string (return types, effect resume types,
/// resume arms). The parser keeps these as written: a qualified spelling keeps
/// its `module:` colon; a bare one does not. A phantom tail (`<state>`) is
/// normally split off by the parser; cut defensively anyway.
fn checkTypeString(
    type_str: ?[]const u8,
    writer_module: []const u8,
    sites: *const type_registry.HostTypeDeclSites,
    reporter: *errors.ErrorReporter,
    location: errors.SourceLocation,
) CheckError!void {
    const rt = type_str orelse return;
    const trimmed = std.mem.trim(u8, rt, " \t");
    // A record return (`-> { ctx: X, value: u32 }`) stays one raw string; its
    // per-field types each get the bare check (top-level commas only — commas
    // nested in <>/{}/[]/() belong to a field's own type).
    if (trimmed.len >= 2 and trimmed[0] == '{' and trimmed[trimmed.len - 1] == '}') {
        const inner = trimmed[1 .. trimmed.len - 1];
        var depth: i32 = 0;
        var start: usize = 0;
        for (inner, 0..) |c, i| {
            switch (c) {
                '<', '{', '[', '(' => depth += 1,
                '>', '}', ']', ')' => depth -= 1,
                ',' => if (depth == 0) {
                    try checkRecordField(inner[start..i], writer_module, sites, reporter, location);
                    start = i + 1;
                },
                else => {},
            }
        }
        try checkRecordField(inner[start..], writer_module, sites, reporter, location);
        return;
    }
    if (std.mem.indexOfScalar(u8, rt, ':') != null) return; // qualified spelling
    var base = rt;
    if (std.mem.indexOfScalar(u8, base, '<')) |lt| base = base[0..lt];
    for (TypePrefixes) |prefix| {
        if (std.mem.startsWith(u8, base, prefix)) {
            base = base[prefix.len..];
            break;
        }
    }
    for (AbiReturnTypes) |abi| {
        if (std.mem.eql(u8, base, abi)) return;
    }
    try refuseIfForeign(base, writer_module, sites, reporter, location);
}

/// One `name: type` pair of a record return. The pair's own `:` separator is
/// not a type qualifier — split at the FIRST top-level colon and check the
/// type tail alone.
fn checkRecordField(
    field_text: []const u8,
    writer_module: []const u8,
    sites: *const type_registry.HostTypeDeclSites,
    reporter: *errors.ErrorReporter,
    location: errors.SourceLocation,
) CheckError!void {
    const text = std.mem.trim(u8, field_text, " \t");
    if (text.len == 0) return;
    var depth: i32 = 0;
    for (text, 0..) |c, i| {
        switch (c) {
            '<', '{', '[', '(' => depth += 1,
            '>', '}', ']', ')' => depth -= 1,
            ':' => if (depth == 0) {
                try checkTypeString(text[i + 1 ..], writer_module, sites, reporter, location);
                return;
            },
            else => {},
        }
    }
}

fn refuseIfForeign(
    base: []const u8,
    writer_module: []const u8,
    sites: *const type_registry.HostTypeDeclSites,
    reporter: *errors.ErrorReporter,
    location: errors.SourceLocation,
) CheckError!void {
    if (base.len == 0) return;
    for (base) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '-') return;
    }
    for (Intrinsics) |intrinsic| {
        if (std.mem.eql(u8, base, intrinsic)) return;
    }
    const decls = sites.get(base) orelse return;
    // Module-local bare: the writer (or the top level, for its own decls)
    // declares the name itself — legal, however many other modules also do.
    for (decls.items) |home| {
        if (type_registry.moduleNamesMatch(home, writer_module)) return;
    }
    if (decls.items.len == 1) {
        const home = decls.items[0];
        const home_slash = try dottedToSlash(reporter.allocator, home);
        defer reporter.allocator.free(home_slash);
        try reporter.addErrorAtLocationWithHint(
            .KORU115,
            location,
            "bare host type '{s}' is declared in module '{s}' — host types are bare only inside the module that declares them",
            .{ base, home_slash },
            "spell it fully qualified across a module boundary: *{s}:{s} (declaring module + ':' + type name, same as invocations)",
            .{ home_slash, base },
        );
    } else {
        var homes_buf = try std.ArrayList(u8).initCapacity(reporter.allocator, 0);
        defer homes_buf.deinit(reporter.allocator);
        for (decls.items, 0..) |home, i| {
            const home_slash = try dottedToSlash(reporter.allocator, home);
            defer reporter.allocator.free(home_slash);
            if (i > 0) try homes_buf.appendSlice(reporter.allocator, ", ");
            try homes_buf.appendSlice(reporter.allocator, home_slash);
        }
        try reporter.addErrorAtLocationWithHint(
            .KORU115,
            location,
            "bare host type '{s}' is declared by several modules ({s}) — the bare spelling cannot say which one a signature means",
            .{ base, homes_buf.items },
            "qualify it with the module you mean: *<module>:{s}",
            .{base},
        );
    }
}

/// Diagnostic spellings use the surface (slash) form the writer would type;
/// the registry's logical names are dotted canon (`app.holder` → `app/holder`).
fn dottedToSlash(allocator: std.mem.Allocator, dotted: []const u8) ![]u8 {
    const out = try allocator.dupe(u8, dotted);
    for (out) |*c| {
        if (c.* == '.') c.* = '/';
    }
    return out;
}

const testing = std.testing;

fn siteMap(allocator: std.mem.Allocator, pairs: []const struct { []const u8, []const u8 }) !type_registry.HostTypeDeclSites {
    var sites = type_registry.HostTypeDeclSites.init(allocator);
    for (pairs) |pair| {
        const gop = try sites.getOrPut(pair[0]);
        if (!gop.found_existing) gop.value_ptr.* = try std.ArrayList([]const u8).initCapacity(allocator, 0);
        try gop.value_ptr.append(allocator, pair[1]);
    }
    return sites;
}

test "refusal: a bare host type written outside its declaring module is refused, naming the qualified fix" {
    const a = testing.allocator;
    var sites = try siteMap(a, &.{ .{ "Token", "app.holder" } });
    defer type_registry.deinitHostTypeDeclSites(a, &sites);
    var reporter = try errors.ErrorReporter.init(a, "input.kz", "tor x { t: *Token }");
    defer reporter.deinit();

    try refuseIfForeign("Token", "", &sites, &reporter, .{ .file = "input.kz", .line = 1, .column = 10 });
    try testing.expect(reporter.hasErrors());
    const err = reporter.errors.items[0];
    try testing.expectEqual(errors.ErrorCode.KORU115, err.code);
    const rendered = try std.fmt.allocPrint(a, "{s}\nhint: {s}", .{ err.message, err.hint.? });
    defer a.free(rendered);
    // The diagnostic must name the fix, spelled as the ruled qualified form.
    try testing.expect(std.mem.indexOf(u8, rendered, "*app/holder:Token") != null);
}

test "module-local bare stays legal: the writer declaring the name licenses its bare spelling" {
    const a = testing.allocator;
    // Two providers for the same name: only the WRITER's own declaration counts.
    var sites = try siteMap(a, &.{ .{ "Value", "std.eval" }, .{ "Value", "std.interpreter" } });
    defer type_registry.deinitHostTypeDeclSites(a, &sites);
    var reporter = try errors.ErrorReporter.init(a, "eval.kz", "");
    defer reporter.deinit();

    try refuseIfForeign("Value", "std.eval", &sites, &reporter, .{ .file = "eval.kz", .line = 1, .column = 1 });
    try testing.expect(!reporter.hasErrors());
}

test "transform-ABI return keywords keep their bare spelling (behavior-bearing)" {
    const a = testing.allocator;
    var sites = try siteMap(a, &.{ .{ "Program", "std.compiler" } });
    defer type_registry.deinitHostTypeDeclSites(a, &sites);
    var reporter = try errors.ErrorReporter.init(a, "input.kz", "");
    defer reporter.deinit();

    // `-> *const Program` / `-> SiteResult` are the transform protocol's own
    // spellings: main.zig's returns_program and the emitter's ast_return_types
    // string-match them bare. A bare foreign `*Token` return still refuses.
    try checkTypeString("*const Program", "", &sites, &reporter, .{ .file = "input.kz", .line = 1, .column = 1 });
    try checkTypeString("SiteResult", "", &sites, &reporter, .{ .file = "input.kz", .line = 1, .column = 1 });
    try refuseIfForeign("Token", "", &sites, &reporter, .{ .file = "input.kz", .line = 1, .column = 1 });
    try testing.expect(reporter.hasErrors());
    try testing.expectEqual(@as(usize, 1), reporter.errors.items.len);
}

test "qualified spellings and undeclared names are not refusal sites" {
    const a = testing.allocator;
    var sites = try siteMap(a, &.{ .{ "Token", "app.holder" } });
    defer type_registry.deinitHostTypeDeclSites(a, &sites);
    var reporter = try errors.ErrorReporter.init(a, "input.kz", "");
    defer reporter.deinit();

    // Qualified spelling: legal everywhere (this is the ruled fix).
    try checkTypeString("*app/holder:Token", "", &sites, &reporter, .{ .file = "input.kz", .line = 1, .column = 1 });
    // A name no module declares: the backend owns it, no refusal.
    try refuseIfForeign("u32", "", &sites, &reporter, .{ .file = "input.kz", .line = 1, .column = 1 });
    // Parser-intrinsic metatypes are keywords, not host-type references.
    try refuseIfForeign("Source", "", &sites, &reporter, .{ .file = "input.kz", .line = 1, .column = 1 });
    try testing.expect(!reporter.hasErrors());
}
