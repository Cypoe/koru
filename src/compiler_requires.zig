const std = @import("std");
const log = @import("log");
const ast = @import("ast");

/// CompilerRequiresCollector gathers build requirements from the AST.
/// It distinguishes between:
/// - std.compiler:requires → for BACKEND compilation (backend.zig)
/// - std.build:requires → for OUTPUT binary (output_emitted.zig)
/// App bundle identity declared via `std/build:app { name:, id:, version:,
/// icon: }`. Collected like a build requirement but consumed as DATA — the
/// emitter turns it into an Info.plist embedded in __TEXT,__info_plist of the
/// output binary. `icon` is a path (resolved against the entry file's dir) to
/// an .icns that `koru bundle` drops in Contents/Resources and names as
/// CFBundleIconFile.
pub const AppDecl = struct {
    name: []const u8,
    id: []const u8,
    version: ?[]const u8,
    icon: ?[]const u8,
};

pub const CompilerRequiresCollector = struct {
    allocator: std.mem.Allocator,
    compiler_requirements: std.ArrayList([]const u8), // For backend.zig
    build_requirements: std.ArrayList([]const u8), // For output binary
    seen_compiler: std.StringHashMap(void), // Deduplication per target
    seen_build: std.StringHashMap(void), // Deduplication per target
    app_decl: ?AppDecl = null, // From std/build:app — at most one wins

    pub fn init(allocator: std.mem.Allocator) !CompilerRequiresCollector {
        return CompilerRequiresCollector{
            .allocator = allocator,
            .compiler_requirements = try std.ArrayList([]const u8).initCapacity(allocator, 0),
            .build_requirements = try std.ArrayList([]const u8).initCapacity(allocator, 0),
            .seen_compiler = std.StringHashMap(void).init(allocator),
            .seen_build = std.StringHashMap(void).init(allocator),
        };
    }

    pub fn deinit(self: *CompilerRequiresCollector) void {
        for (self.compiler_requirements.items) |req| {
            self.allocator.free(req);
        }
        self.compiler_requirements.deinit(self.allocator);

        for (self.build_requirements.items) |req| {
            self.allocator.free(req);
        }
        self.build_requirements.deinit(self.allocator);
        self.seen_compiler.deinit();
        self.seen_build.deinit();

        if (self.app_decl) |decl| {
            self.allocator.free(decl.name);
            self.allocator.free(decl.id);
            if (decl.version) |v| self.allocator.free(v);
            if (decl.icon) |v| self.allocator.free(v);
        }
    }

    // Legacy alias for backwards compatibility
    pub fn getRequirements(self: *CompilerRequiresCollector) []const []const u8 {
        return self.compiler_requirements.items;
    }

    /// Collect all ~build:requires / ~compiler:requires from a program AST.
    pub fn collectFromProgram(self: *CompilerRequiresCollector, program: *const ast.Program) !void {
        log.debug("[CompilerRequiresCollector] Starting collection from {} items\n", .{program.items.len});
        try self.collectFromItems(program.items, 0);
    }

    /// Legacy alias — same walk as `collectFromProgram`.
    pub fn collectFromSourceFile(self: *CompilerRequiresCollector, source_file: *const ast.Program) !void {
        try self.collectFromProgram(source_file);
    }

    fn collectFromItems(self: *CompilerRequiresCollector, items: []const ast.Item, depth: usize) !void {
        for (items) |item| {
            switch (item) {
                .flow => |flow| try self.checkFlowForRequires(&flow, depth),
                .module_decl => |module| {
                    log.debug("[CompilerRequiresCollector] Checking module: {s} ({} items)\n", .{ module.logical_name, module.items.len });
                    try self.collectFromItems(module.items, depth + 1);
                },
                else => {},
            }
        }
    }

    fn checkFlowForRequires(self: *CompilerRequiresCollector, flow: *const ast.Flow, depth: usize) !void {
        if (flow.inv().path.module_qualifier) |mq| {
            if (flow.inv().path.segments.len < 1) return;

            // DEBUG: Print what we're checking
            log.debug("[CompilerRequiresCollector] Checking flow: {s}:{s}\n", .{ mq, flow.inv().path.segments[0] });

            // Check for std.build:requires (for OUTPUT binary)
            const is_build_module = std.mem.endsWith(u8, mq, ".build") or std.mem.eql(u8, mq, "build");
            const is_build_requires = is_build_module and
                flow.inv().path.segments.len == 1 and
                std.mem.eql(u8, flow.inv().path.segments[0], "requires");

            // Check for std.compiler:requires or std.compiler_requirements:requires (for BACKEND)
            const is_compiler_module = std.mem.endsWith(u8, mq, ".compiler") or std.mem.eql(u8, mq, "compiler");
            const is_compiler_requirements_module = std.mem.endsWith(u8, mq, ".compiler_requirements") or std.mem.eql(u8, mq, "compiler_requirements");
            const is_compiler_requires = (is_compiler_module or is_compiler_requirements_module) and
                flow.inv().path.segments.len == 1 and
                std.mem.eql(u8, flow.inv().path.segments[0], "requires");

            if (is_build_requires) {
                log.debug("[CompilerRequiresCollector] ✓ FOUND build:requires (for output binary)!\n", .{});
                try self.extractAndAddSource(flow, &self.build_requirements, &self.seen_build);
            } else if (is_compiler_requires) {
                log.debug("[CompilerRequiresCollector] ✓ FOUND compiler:requires (for backend)!\n", .{});
                try self.extractAndAddSource(flow, &self.compiler_requirements, &self.seen_compiler);
            } else if (is_build_module and depth == 0 and flow.inv().path.segments.len == 1 and
                std.mem.eql(u8, flow.inv().path.segments[0], "app"))
            {
                // Entry-program-only: an imported module declaring `app` is
                // ignored — bundle identity belongs to the executable, and a
                // library silently naming it would be an invisible override.
                log.debug("[CompilerRequiresCollector] ✓ FOUND build:app (bundle identity)!\n", .{});
                try self.extractAppDecl(flow);
            }
        }
    }

    /// Extract `std/build:app { name: "…", id: "…", version: "…" }` from the
    /// captured Source block into `app_decl`. The block is raw text — the
    /// tor's input shape preserves it (an input-field record would have been
    /// checked and dropped before serialization). `name` + `id` are required;
    /// an unknown key, an unquoted value, or a missing comma refuses the
    /// declaration rather than manufacturing a partial identity. Multiple
    /// top-level declarations: last one wins (entry-file identity is a
    /// singleton — a second declaration is an override, not an error).
    fn extractAppDecl(self: *CompilerRequiresCollector, flow: *const ast.Flow) !void {
        var text: ?[]const u8 = null;
        for (flow.inv().args) |arg| {
            // Same binding as requires: "source" (named) or the anonymous block.
            if (std.mem.eql(u8, arg.name, "source") or (std.mem.eql(u8, arg.name, "") and arg.source_value != null)) {
                text = if (arg.source_value) |sv| sv.text else arg.value;
            }
        }
        const src = text orelse return;

        var name: ?[]const u8 = null;
        var id: ?[]const u8 = null;
        var version: ?[]const u8 = null;
        var icon: ?[]const u8 = null;

        var pos: usize = 0;
        while (true) {
            pos = skipSep(src, pos);
            if (pos >= src.len) break;
            const key = readKey(src, &pos) orelse return appRefusal();
            pos = skipWs(src, pos);
            if (pos >= src.len or src[pos] != ':') return appRefusal();
            pos = skipWs(src, pos + 1);
            const val = readQuoted(src, &pos) orelse return appRefusal();
            if (std.mem.eql(u8, key, "name")) {
                name = val;
            } else if (std.mem.eql(u8, key, "id")) {
                id = val;
            } else if (std.mem.eql(u8, key, "version")) {
                version = val;
            } else if (std.mem.eql(u8, key, "icon")) {
                icon = val;
            } else {
                return appRefusal();
            }
        }

        if (name == null or id == null) return appRefusal();

        if (self.app_decl) |prev| {
            self.allocator.free(prev.name);
            self.allocator.free(prev.id);
            if (prev.version) |v| self.allocator.free(v);
            if (prev.icon) |v| self.allocator.free(v);
        }
        self.app_decl = .{
            .name = try self.allocator.dupe(u8, name.?),
            .id = try self.allocator.dupe(u8, id.?),
            .version = if (version) |v| try self.allocator.dupe(u8, v) else null,
            .icon = if (icon) |v| try self.allocator.dupe(u8, v) else null,
        };
    }

    /// The one refusal path for a malformed `std/build:app` block: a legible
    /// stderr line first, then the error the caller's `try` turns into a
    /// failed compile — never a silently-defaulted identity.
    fn appRefusal() error{AppDeclMalformed} {
        std.fs.File.stderr().writeAll(
            "error[KORU210]: std/build:app block is malformed — expected `name: \"…\", id: \"…\"` with optional `version: \"…\"`, `icon: \"…\"`; unknown keys refuse\n",
        ) catch {};
        return error.AppDeclMalformed;
    }

    fn skipWs(src: []const u8, start: usize) usize {
        var pos = start;
        while (pos < src.len and (src[pos] == ' ' or src[pos] == '\t' or src[pos] == '\n' or src[pos] == '\r')) pos += 1;
        return pos;
    }

    fn skipSep(src: []const u8, start: usize) usize {
        var pos = skipWs(src, start);
        while (pos < src.len and (src[pos] == ',' or src[pos] == '{' or src[pos] == '}')) pos = skipWs(src, pos + 1);
        return pos;
    }

    /// A `key` is either `"quoted"` or a bare run of identifier bytes.
    fn readKey(src: []const u8, pos: *usize) ?[]const u8 {
        if (pos.* >= src.len) return null;
        if (src[pos.*] == '"') {
            return readQuoted(src, pos);
        }
        const start = pos.*;
        while (pos.* < src.len) {
            const c = src[pos.*];
            const ident = (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_' or c == '-';
            if (!ident) break;
            pos.* += 1;
        }
        if (pos.* == start) return null;
        return src[start..pos.*];
    }

    /// A `"quoted"` value; `\"` escapes are left to the consumer (identity
    /// fields do not carry them in practice — an embedded quote leaves the
    /// remainder unparsed and the trailing junk refuses).
    fn readQuoted(src: []const u8, pos: *usize) ?[]const u8 {
        if (pos.* >= src.len or src[pos.*] != '"') return null;
        pos.* += 1;
        const start = pos.*;
        while (pos.* < src.len and src[pos.*] != '"') pos.* += 1;
        if (pos.* >= src.len) return null;
        const v = src[start..pos.*];
        pos.* += 1;
        return v;
    }

    /// The collected app identity, if any `std/build:app` flow was seen.
    pub fn getAppDecl(self: *const CompilerRequiresCollector) ?AppDecl {
        return self.app_decl;
    }

    fn extractAndAddSource(self: *CompilerRequiresCollector, flow: *const ast.Flow, target_list: *std.ArrayList([]const u8), seen: *std.StringHashMap(void)) !void {
        for (flow.inv().args) |arg| {
            // Accept both "source" (named) and "" (anonymous block with source_value)
            if (std.mem.eql(u8, arg.name, "source") or (std.mem.eql(u8, arg.name, "") and arg.source_value != null)) {
                const source_code = if (arg.source_value) |sv| sv.text else arg.value;

                // Deduplicate by content within the same target
                if (seen.contains(source_code)) {
                    log.debug("[CompilerRequiresCollector]   Skipping duplicate requirement\n", .{});
                    continue;
                }

                const source_copy = try self.allocator.dupe(u8, source_code);
                try target_list.append(self.allocator, source_copy);
                try seen.put(source_copy, {});
                log.debug("[CompilerRequiresCollector]   Added requirement ({d} bytes)\n", .{source_code.len});
            }
        }
    }

    /// Get compiler requirements (for backend.zig)
    pub fn getCompilerRequirements(self: *CompilerRequiresCollector) []const []const u8 {
        return self.compiler_requirements.items;
    }

    /// Get build requirements (for output binary)
    pub fn getBuildRequirements(self: *CompilerRequiresCollector) []const []const u8 {
        return self.build_requirements.items;
    }
};

// Tests
test "collects single compiler:requires" {
    const allocator = std.testing.allocator;

    var collector = try CompilerRequiresCollector.init(allocator);
    defer collector.deinit();

    // Create a minimal flow with compiler:requires
    var segments = [_][]const u8{"requires"};
    var args = [_]ast.Argument{
        ast.Argument{
            .name = "source",
            .value = "exe.linkSystemLibrary(\"sqlite3\");",
            .source_value = null,
        },
    };

    const flow = ast.Flow{
        .body = ast.rootSite(ast.Invocation{
            .path = ast.DottedPath{
                .segments = &segments,
                .module_qualifier = "compiler",
            },
            .args = &args,
        }, &.{}, .{ .file = "generated", .line = 0, .column = 0 }),
    };

    try collector.checkFlowForRequires(&flow, 0);

    const reqs = collector.getCompilerRequirements();
    try std.testing.expectEqual(@as(usize, 1), reqs.len);
    try std.testing.expectEqualStrings("exe.linkSystemLibrary(\"sqlite3\");", reqs[0]);
}

test "collects multiple compiler:requires" {
    const allocator = std.testing.allocator;

    var collector = try CompilerRequiresCollector.init(allocator);
    defer collector.deinit();

    // Create two flows
    var segments = [_][]const u8{"requires"};
    var args1 = [_]ast.Argument{
        ast.Argument{
            .name = "source",
            .value = "exe.linkSystemLibrary(\"sqlite3\");",
            .source_value = null,
        },
    };
    var args2 = [_]ast.Argument{
        ast.Argument{
            .name = "source",
            .value = "exe.linkSystemLibrary(\"c\");",
            .source_value = null,
        },
    };

    const flow1 = ast.Flow{
        .body = ast.rootSite(ast.Invocation{
            .module_qualifier = "compiler",
            .path = ast.DottedPath{
                .segments = &segments,
                .module_qualifier = "compiler",
            },
            .args = &args1,
        }, &.{}, .{ .file = "generated", .line = 0, .column = 0 }),
    };

    const flow2 = ast.Flow{
        .body = ast.rootSite(ast.Invocation{
            .module_qualifier = "compiler",
            .path = ast.DottedPath{
                .segments = &segments,
                .module_qualifier = "compiler",
            },
            .args = &args2,
        }, &.{}, .{ .file = "generated", .line = 0, .column = 0 }),
    };

    try collector.checkFlowForRequires(&flow1, 0);
    try collector.checkFlowForRequires(&flow2, 0);

    const reqs = collector.getCompilerRequirements();
    try std.testing.expectEqual(@as(usize, 2), reqs.len);
    try std.testing.expectEqualStrings("exe.linkSystemLibrary(\"sqlite3\");", reqs[0]);
    try std.testing.expectEqualStrings("exe.linkSystemLibrary(\"c\");", reqs[1]);
}

test "ignores non-compiler:requires flows" {
    const allocator = std.testing.allocator;

    var collector = try CompilerRequiresCollector.init(allocator);
    defer collector.deinit();

    // Create a flow that is NOT compiler:requires
    var segments = [_][]const u8{"somethingElse"};
    var args = [_]ast.Argument{
        ast.Argument{
            .name = "source",
            .value = "this should be ignored",
            .source_value = null,
        },
    };

    const flow = ast.Flow{
        .body = ast.rootSite(ast.Invocation{
            .path = ast.DottedPath{
                .segments = &segments,
                .module_qualifier = "compiler",
            },
            .args = &args,
        }, &.{}, .{ .file = "generated", .line = 0, .column = 0 }),
    };

    try collector.checkFlowForRequires(&flow, 0);

    const reqs = collector.getCompilerRequirements();
    try std.testing.expectEqual(@as(usize, 0), reqs.len);
    // Also check build requirements are empty
    try std.testing.expectEqual(@as(usize, 0), collector.getBuildRequirements().len);
}
