// cs_emitter.zig — minimal, hello-world-shaped Koru → C# emitter (the K#
// vertical spike).
//
// SCOPE: this is the `cs` target's first emitter, forked off js_emitter.zig's
// architecture — same AST walk, same four-spelling impl resolution, same
// reached-gating for module events, same fail-loud contract — with every
// output site retargeted to C# 9 (net9.0):
//
//   - event decls → `static class <name>_event { static dynamic
//     handler(dynamic __koru_input) { … } }` nested in `main_module`.
//   - the handler boundary is `dynamic` on purpose: `new { f = arg }` gives
//     the call site the same duck-typed record JS gives an object literal —
//     `result.tag`, `result.done` read back untyped. Records/generics are the
//     real design conversation; the vertical only needs the shape to compile
//     and run.
//   - `|cs` proc bodies, spliced verbatim (opaque host code) after binding
//     input fields as `var field = __koru_input.field;`.
//   - top-level flows → `flowN()` static methods; `Program.Main` invokes them.
//   - rendered-template inline bodies (`~if`, `~for`, `~cond`): the
//     `__koru_continue_N` / `__koru_inline_N` markers resolved inline, same
//     walk the JS emitter does.
//
// It is deliberately NARROW — narrower than the JS emitter, which started the
// same way. Effect-bearing events, label folds (`#L`/`@L`), taps/metatype
// records, destructure payloads and the void-effect splice all REFUSE by
// name rather than emit a shape no test has run. The vertical is `print.ln`
// through `~if`/`~for`/`~cond`; grow construct-by-construct from there.
//
// FAIL LOUD: an invocation it can't resolve, a construct it doesn't model, or
// Zig text detected in the finished buffer is an error, not an approximation.

const std = @import("std");
const ast = @import("ast");
const log = @import("log");
const file_types = @import("file_types");
const annotation_parser = @import("annotation_parser");
const struct_literal = @import("struct_literal");
const codegen_utils = @import("codegen_utils");

pub const CsEmitError = error{
    OutOfMemory,
    UnresolvedEvent,
    UnsupportedConstruct,
    NoCsProcBody,
    // Emitted C# contained Zig-only syntax (an un-lowered construct was pasted
    // verbatim instead of refused). Surfaced as `error[KORU047]` by the driver.
    ZigTextInOutput,
};

/// The variant-tag string this emitter targets — the SAME namespace as
/// `--lang` / `proc.target` / `file_types.hostLangOfFile`, so it selects both
/// a `|cs` proc body and a `.kcs` host line.
const CS_TARGET = "cs";

/// The handler's payload parameter. RESERVED, not `input`: an event may
/// declare a field literally named `input`, and `var input = input.input;` is
/// a redeclaration C# refuses outright. Same reason as the JS/Zig targets.
const INPUT_PARAM = "__koru_input";

/// Emit C# for the given program. Returns a heap-allocated string owned by the
/// caller's allocator. `library` suppresses `Program.Main`: a program runs its
/// flows; a library emits the module class and no entry point.
pub fn emit(allocator: std.mem.Allocator, program: *const ast.Program, library: bool) CsEmitError![]const u8 {
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(allocator);

    var em = Emitter{ .allocator = allocator, .buf = &buf, .items = program.items, .main_module_name = program.main_module_name };

    // Phase 0: `.kcs` host lines verbatim at the TOP of the file (using
    // directives, file-scope declarations) — routed by host language, the same
    // test that selects a `|cs` proc body. Descends into module_decl so an
    // imported facet's host state reaches the output.
    try emitCsHostLines(&em, program.items);

    try em.write("static class main_module {\n");
    // The stdout/stderr surface lives INSIDE main_module so the unqualified
    // `__koru_stdout_write(…)` a |cs transform emits resolves from every flow
    // and proc body. Write (not WriteLine): the transform appends its own
    // newline, mirroring the JS helpers.
    try em.write(
        \\  public static void __koru_stdout_write(dynamic s) => global::System.Console.Out.Write(s);
        \\  public static void __koru_stderr_write(dynamic s) => global::System.Console.Error.Write(s);
        \\
    );

    // Phase 0.5: module-scope [declaration] flows and transform-appended
    // .inline_code, spliced as class members (C# has no file-scope statements;
    // whatever a |cs transform renders there is its own spelling problem).
    try emitCsDeclarations(&em, program.items);
    try emitTopLevelInlineCode(&em, program.items);

    // Which module events the emitted program actually REACHES — computed
    // before anything is written, because Phase 1b needs it to tell an event
    // nobody wants (skip in silence) from one a call site is about to
    // dispatch to (must account for itself). See collectReachedEvents.
    var reached = ReachedEvents.init(allocator);
    defer reached.deinit();
    try em.collectReachedEvents(&reached);

    // Every `<name>_event` key written into main_module so far — the nested
    // classes are one flat namespace while Koru event paths are not, so a
    // refusal stub must never clobber a working handler.
    var emitted_keys = EmittedKeys.init(allocator);
    defer {
        var it = emitted_keys.keyIterator();
        while (it.next()) |k| allocator.free(k.*);
        emitted_keys.deinit();
    }

    // Phase 1: each top-level event decl as a nested `<name>_event` class.
    for (program.items) |*item| {
        if (item.* == .event_decl) {
            try em.emitEventDecl(&item.event_decl, program.items);
            try em.claimEventKey(&emitted_keys, &item.event_decl);
        }
    }

    // Phase 1b: event decls in IMPORTED MODULES — gated on transitive
    // cs-implementability, with a self-naming refusal for anything reached
    // but unlowerable.
    for (program.items) |*item| {
        if (item.* != .module_decl) continue;
        try em.emitModuleEventDecls(&item.module_decl, &reached, &emitted_keys);
    }

    // Phase 2: each top-level flow as a flowN() method.
    var flow_num: usize = 0;
    for (program.items) |*item| {
        if (item.* == .flow) {
            // Subflow implementations are emitted inside their event's
            // handler, not as standalone methods.
            if (item.flow.impl_of != null) continue;
            if (em.isDeclarationFlow(&item.flow)) continue;
            // Skip injected meta-event flows (koru:start / koru:end).
            if (item.flow.inv().path.module_qualifier) |mq| {
                if (std.mem.eql(u8, mq, "koru")) continue;
            }
            if (em.flowIsNorunSite(&item.flow)) continue;
            try em.emitFlow(&item.flow, flow_num);
            flow_num += 1;
        }
    }

    try em.write("}\n");

    // The entry point: Program.Main invokes every emitted flow. A library
    // emits the module class and no door into it.
    if (!library) {
        try em.write("\nstatic class Program {\n  static void Main() {\n");
        for (0..flow_num) |i| {
            try em.writeFmt("    main_module.flow{d}();\n", .{i});
        }
        try em.write("  }\n}\n");
    }

    // THE WALL — same invariant as the JS emitter's validateNoZigInJs: the
    // lowering is permissive by design, so validate the COMPLETE output once
    // here, where every paste path has already landed.
    try validateNoZigInCs(&buf);

    return buf.toOwnedSlice(allocator);
}

/// The refuse-not-paste wall, cs twin of validateNoZigInJs. Same token set —
/// every entry is invalid C# the same way it is invalid JavaScript, and `@` is
/// not a call sigil in either host, so an `@builtin` reaching the buffer can
/// only be an un-lowered construct. Adds one C#-specific catch: `.{` — a Zig
/// anonymous-struct opener that parses as a member access on nothing.
fn validateNoZigInCs(buf: *const std.ArrayList(u8)) CsEmitError!void {
    const text = buf.items;
    var i: usize = 0;
    var in_line_comment = false;
    var in_block_comment = false;
    var in_str: ?u8 = null;
    var line: usize = 1;
    while (i < text.len) : (i += 1) {
        const c = text[i];
        if (c == '\n') line += 1;

        if (in_str) |q| {
            if (c == '\\' and i + 1 < text.len) {
                i += 1;
            } else if (c == q) {
                in_str = null;
            }
            continue;
        }
        if (in_line_comment) {
            if (c == '\n') in_line_comment = false;
            continue;
        }
        if (in_block_comment) {
            if (c == '*' and i + 1 < text.len and text[i + 1] == '/') {
                in_block_comment = false;
                i += 1;
            }
            continue;
        }
        if (c == '"' or c == '\'') {
            in_str = c;
            continue;
        }
        if (c == '/' and i + 1 < text.len and text[i + 1] == '/') {
            in_line_comment = true;
            i += 1;
            continue;
        }
        if (c == '/' and i + 1 < text.len and text[i + 1] == '*') {
            in_block_comment = true;
            i += 1;
            continue;
        }

        if (c == '@') {
            // `@name(` is no C# call — but `@name` alone IS a verbatim
            // identifier, so only the call shape refuses here. The mangle
            // produces `@event`/ `@is` which never have `(` next.
            var p = i + 1;
            while (p < text.len and isIdentChar(text[p])) p += 1;
            const name = text[i .. p];
            if (name.len > 1) {
                for (ZIG_BUILTINS) |b| {
                    if (std.mem.eql(u8, name, b)) {
                        if (p < text.len and text[p] == '(') {
                            return refuseZigInCs(buf, line, b);
                        }
                    }
                }
            }
        } else if (c == ']' and i + 1 < text.len and (text[i + 1] == 'u' or text[i + 1] == 'i') and
            i + 2 < text.len and std.ascii.isDigit(text[i + 2]))
        {
            return refuseZigInCs(buf, line, "]uN Zig array type");
        } else if (c == '.' and i + 2 < text.len and text[i + 1] == '.' and text[i + 2] == ']') {
            return refuseZigInCs(buf, line, "..] Zig slice");
        } else if (c == '.' and i + 1 < text.len and text[i + 1] == '{') {
            return refuseZigInCs(buf, line, ".{ Zig struct literal");
        } else if (c == 'f' and i + 2 < text.len and text[i + 1] == 'n' and text[i + 2] == ' ' and
            (i == 0 or !std.ascii.isAlphanumeric(text[i - 1])) and (i == 0 or text[i - 1] != '_'))
        {
            return refuseZigInCs(buf, line, "fn Zig declaration");
        }
    }
}

fn refuseZigInCs(buf: *const std.ArrayList(u8), line: usize, what: []const u8) CsEmitError {
    const text = buf.items;
    var start: usize = 0;
    if (line > 1) {
        var found: usize = 0;
        var l: usize = 1;
        while (l < line and found < text.len) : (found += 1) {
            if (text[found] == '\n') l += 1;
        }
        start = found;
    }
    var end = start;
    while (end < text.len and text[end] != '\n') : (end += 1) {}
    const ctx_len = @min(end - start, @as(usize, 80));
    log.err("[cs_emitter] REFUSE: {s} found in emitted C# at line {d} (un-lowered construct reached the output instead of refusing)\n", .{ what, line });
    log.err("  context: {s}\n", .{text[start .. start + ctx_len]});
    return CsEmitError.ZigTextInOutput;
}

const ZIG_BUILTINS = [_][]const u8{
    "@import",   "@as",        "@intCast",  "@floatCast", "@ptrCast",
    "@bitCast",  "@truncate",  "@min",      "@max",       "@mod",
    "@memcpy",   "@memset",    "@sizeOf",   "@TypeOf",    "@typeOf",
    "@alignOf",  "@field",     "@call",     "@intFrom",   "@floatFrom",
    "@enumFrom", "@unionInit", "@splat",    "@reduce",    "@panic",
    "@compileError", "@intTo", "@floatTo",  "@enumTo",    "@intFromFloat",
    "@floatFromInt", "@intFromBool", "@intFromEnum", "@enumFromInt",
    "@errorName", "@setRuntimeSafety", "@this", "@typeInfo", "@typeName",
    "@embedFile", "@cImport",  "@extern",   "@select",    "@mulAdd",
    "@addWithOverflow", "@subWithOverflow", "@mulWithOverflow",
    "@divTrunc",  "@divFloor", "@divExact", "@rem",       "@abs",
    "@clz",       "@ctz",      "@popCount", "@byteSwap",  "@bitReverse",
    "@log2",      "@log10",    "@exp2",     "@floor",     "@ceil",
    "@round",     "@fabs",     "@fmin",     "@fmax",      "@copysign",
    "@tagName",   "@breakpoint", "@returnAddress", "@frameAddress",
    "@hasDecl",   "@hasField", "@wasmMemorySize", "@wasmMemoryGrow",
};

/// Phase 0's walker: every `.kcs`-sourced host line in `items`, in order,
/// descending through `module_decl` so an imported facet's module-level C#
/// state reaches the output alongside the entry file's.
fn emitCsHostLines(em: *Emitter, items: []const ast.Item) CsEmitError!void {
    for (items) |*item| {
        switch (item.*) {
            .host_line => |*line| {
                const host = file_types.hostLangOfFile(line.location.file) orelse continue;
                if (!std.mem.eql(u8, host, CS_TARGET)) continue;
                try em.write(line.content);
                try em.write("\n");
            },
            .module_decl => |*m| try emitCsHostLines(em, m.items),
            else => {},
        }
    }
}

/// Module-scope `[declaration]` flows — a `const {}` introducing names into
/// the enclosing scope. Spliced inside main_module as class members through
/// the host-text lowering (a rendered `const|zig` body with `@as` refuses
/// there; a `const|cs` template renders its own spelling).
fn emitCsDeclarations(em: *Emitter, items: []const ast.Item) CsEmitError!void {
    for (items) |*item| {
        switch (item.*) {
            .flow => |*f| {
                if (!em.isDeclarationFlow(f)) continue;
                const body = stripInlineStmtMarker(f.inline_body.?);
                try em.write("  ");
                try em.writeHostText(std.mem.trim(u8, body, " \t\r\n"));
                try em.write("\n");
            },
            .module_decl => |*m| try emitCsDeclarations(em, m.items),
            else => {},
        }
    }
}

/// Every top-level `.inline_code` item, descending through `module_decl` —
/// host declarations a comptime transform appended beside the site it rewrote.
/// Emitted as class members; the transform renders them in the build language.
fn emitTopLevelInlineCode(em: *Emitter, items: []const ast.Item) CsEmitError!void {
    for (items) |*item| {
        switch (item.*) {
            .inline_code => |*ic| {
                try em.write("  ");
                try em.write(ic.code);
                try em.write("\n");
            },
            .module_decl => |*m| try emitTopLevelInlineCode(em, m.items),
            else => {},
        }
    }
}

/// Event decls the emitted program reaches, by POINTER identity — two modules
/// may declare the same path, and only the pointer distinguishes them.
const ReachedEvents = std.AutoHashMap(*const ast.EventDecl, void);

/// The `<name>_event` keys already written into `main_module`. Nested classes
/// are one flat namespace; Koru event paths are not.
const EmittedKeys = std.StringHashMap(void);

const Emitter = struct {
    allocator: std.mem.Allocator,
    buf: *std.ArrayList(u8),
    items: []const ast.Item,
    /// The program's main module name — reconciles a qualified call
    /// (`std.io:print.ln`) against the entry module's own decls.
    main_module_name: []const u8 = "",
    /// Monotonic counter for unique `result_<id>` names.
    id_counter: usize = 0,
    /// The event whose SUBFLOW impl body is currently being emitted, or null
    /// outside one — a call to one of that event's own effect arms is a
    /// FIRING, not an event invocation. The vertical refuses both anyway;
    /// the field stays so the shape of the check survives.
    impl_event: ?*const ast.EventDecl = null,

    fn nextId(self: *Emitter) usize {
        const id = self.id_counter;
        self.id_counter += 1;
        return id;
    }

    fn write(self: *Emitter, text: []const u8) CsEmitError!void {
        try self.buf.appendSlice(self.allocator, text);
    }

    fn writeFmt(self: *Emitter, comptime fmt: []const u8, args: anytype) CsEmitError!void {
        try self.buf.print(self.allocator, fmt, args);
    }

    /// Identifier formation boundary: names are kebab-canonical in the
    /// pipeline; a dash lowers to underscore while writing a C# identifier
    /// (C# cannot spell `-` in one — unlike JS object keys, an anonymous-
    /// object's member names are identifiers, so keys lower here too).
    fn writeIdent(self: *Emitter, name: []const u8) CsEmitError!void {
        for (name) |c| {
            try self.buf.append(self.allocator, if (c == '-') '_' else c);
        }
    }

    /// Same boundary, for a name in BINDING position — `var <n>`, a member
    /// name on an anonymous object, a member read. Adds the C# reserved-word
    /// escape on top of the kebab lowering: `event` → `@event`, which is a
    /// verbatim identifier and still readable — the native mechanism JS's
    /// `$`-suffix stands in for. Keys come here too (unlike JS, whose keys
    /// stay raw): `new { @event = v }` and `result.@event` are both valid C#,
    /// so writer and reader agree by construction.
    fn writeBinding(self: *Emitter, name: []const u8) CsEmitError!void {
        const needs_mangle = blk: {
            var stem_buf: [256]u8 = undefined;
            if (name.len <= stem_buf.len) {
                for (name, 0..) |c, i| stem_buf[i] = if (c == '-') '_' else c;
                break :blk codegen_utils.isCsReservedForEmit(stem_buf[0..name.len]);
            }
            break :blk false;
        };
        if (needs_mangle) try self.buf.append(self.allocator, '@');
        try self.writeIdent(name);
    }

    /// Buffer variant of the identifier lowering, for sites that need the
    /// lowered name as a string (format args).
    fn lowerIdentBuf(buf: []u8, name: []const u8) []const u8 {
        @memcpy(buf[0..name.len], name);
        for (buf[0..name.len]) |*c| {
            if (c.* == '-') c.* = '_';
        }
        return buf[0..name.len];
    }

    /// Read a property off a `dynamic` — `base.key`. A payload key lowers to a
    /// C# identifier (kebab → underscore; the producer wrote it through the
    /// same writeIdent on the anonymous object's member name).
    fn writeMember(self: *Emitter, base: []const u8, key: []const u8) CsEmitError!void {
        try self.write(base);
        try self.write(".");
        try self.writeBinding(key);
    }

    /// Find the |cs proc for `event_path` WITHIN a given item scope
    /// (segment-equal). Mirrors findJsProcIn: `[transform]`/`[template]` procs
    /// are skipped — their `|cs` bodies are stage-C host code that EMITS C#,
    /// not C# itself, and splicing one put Zig inside the JS output the first
    /// time this distinction was missed.
    fn findCsProcIn(self: *Emitter, scope: []const ast.Item, event_path: *const ast.DottedPath) ?*const ast.ProcDecl {
        _ = self;
        for (scope) |*item| {
            if (item.* != .proc_decl) continue;
            const proc = &item.proc_decl;
            if (proc.path.segments.len != event_path.segments.len) continue;
            var match = true;
            for (proc.path.segments, event_path.segments) |sa, sb| {
                if (!std.mem.eql(u8, sa, sb)) {
                    match = false;
                    break;
                }
            }
            if (!match) continue;
            const target = proc.target orelse continue;
            if (!std.mem.eql(u8, target, CS_TARGET)) continue;
            if (annotation_parser.hasPart(proc.annotations, "transform")) continue;
            if (annotation_parser.hasPart(proc.annotations, "template")) continue;
            return proc;
        }
        return null;
    }

    /// Resolve an invocation path to its event decl, descending into imported
    /// modules — module-qualified call sites reconciled by pathsEqualWithModule.
    fn findEventDecl(self: *Emitter, path: *const ast.DottedPath) ?*const ast.EventDecl {
        return self.findEventDeclIn(self.items, path, null);
    }

    fn findEventDeclIn(self: *Emitter, scope: []const ast.Item, path: *const ast.DottedPath, current_module: ?[]const u8) ?*const ast.EventDecl {
        for (scope) |*item| {
            switch (item.*) {
                .event_decl => |*e| {
                    if (pathsEqualWithModule(&e.path, path, current_module, self.main_module_name)) return e;
                },
                .module_decl => |*m| {
                    if (self.findEventDeclIn(m.items, path, m.logical_name)) |found| return found;
                },
                else => {},
            }
        }
        return null;
    }

    /// A `[declaration]` flow introduces names into the enclosing scope rather
    /// than executing — spliced as a class member (Phase 0.5), never a flowN().
    fn isDeclarationFlow(self: *Emitter, flow: *const ast.Flow) bool {
        if (flow.inline_body == null) return false;
        const decl = self.findEventDecl(&flow.inv().path) orelse return false;
        return annotation_parser.hasPart(decl.annotations, "declaration");
    }

    /// A `[norun]` event claims its site as AST data — the flow never
    /// executes and no handler call may reach the output. Mirrors the JS
    /// emitter's guard (visitor walk's is_norun twin).
    fn flowIsNorunSite(self: *Emitter, flow: *const ast.Flow) bool {
        if (flow.inline_body != null or flow.preamble_code != null) return false;
        for (flow.inv().annotations) |ann| {
            if (std.mem.startsWith(u8, ann, "@pass_ran")) return false;
        }
        const site = self.findDeclSiteIn(self.items, &flow.inv().path, null) orelse return false;
        return annotation_parser.hasPart(site.decl.annotations, "norun");
    }

    /// How an event's behaviour is supplied — the four spellings, resolved in
    /// the same order the JS emitter resolves them: `|cs` proc first, then an
    /// immediate/arrow impl, then a subflow, and LAST a `|template|` proc
    /// (not a body — the absence of one at the decl site).
    const EventImpl = union(enum) {
        proc: *const ast.ProcDecl,
        template_stub: *const ast.ProcDecl,
        immediate: *const ast.ImmediateImpl,
        subflow: *const ast.Flow,
    };

    fn findImplIn(self: *Emitter, scope: []const ast.Item, event_path: *const ast.DottedPath) ?EventImpl {
        if (self.findCsProcIn(scope, event_path)) |proc| return .{ .proc = proc };

        for (scope) |*item| {
            if (item.* != .immediate_impl) continue;
            if (pathsEqual(&item.immediate_impl.event_path, event_path)) {
                return .{ .immediate = &item.immediate_impl };
            }
        }

        for (scope) |*item| {
            if (item.* != .flow) continue;
            const flow = &item.flow;
            const impl_of = flow.impl_of orelse continue;
            if (flow.impl_variant != null) continue;
            if (pathsEqual(&impl_of, event_path)) return .{ .subflow = flow };
        }

        for (scope) |*item| {
            if (item.* != .proc_decl) continue;
            const proc = &item.proc_decl;
            if (!pathsEqual(&proc.path, event_path)) continue;
            if (templateProcTargetsCs(proc)) return .{ .template_stub = proc };
        }

        return null;
    }

    /// Emit one event decl as `static class <name>_event { … handler … }`.
    fn emitEventDecl(self: *Emitter, event: *const ast.EventDecl, scope: []const ast.Item) CsEmitError!void {
        const impl = self.findImplIn(scope, &event.path) orelse {
            log.err("[cs_emitter] event '{s}' has no |cs proc, immediate, or subflow body\n", .{event.path.segments[event.path.segments.len - 1]});
            return CsEmitError.NoCsProcBody;
        };

        const name = event.path.segments[event.path.segments.len - 1];

        var has_effect = false;
        for (event.branches) |b| {
            if (b.kind == .effect) {
                has_effect = true;
                break;
            }
        }
        // The vertical does not model effect dispatch (Handlers objects,
        // arm fires). Refuse by name rather than emit a shape unmeasured.
        if (has_effect) {
            log.err("[cs_emitter] event '{s}' declares effect branches, which the cs target does not model\n", .{name});
            return CsEmitError.UnsupportedConstruct;
        }

        var name_buf: [256]u8 = undefined;
        try self.writeFmt("  public static class {s}_event {{\n", .{lowerIdentBuf(&name_buf, name)});
        try self.writeFmt("    public static dynamic handler(dynamic {s}) {{\n", .{INPUT_PARAM});

        // Bind input fields as locals: `var n = __koru_input.n;`. Every impl
        // kind reads its inputs by bare name, so this precedes all four
        // bodies. A field DEFAULT applies here (C# anonymous objects have no
        // defaults either — same hole, same fix): `?? <dflt>` reads through
        // dynamic the way JS's `??` does.
        for (event.input.fields) |field| {
            try self.write("      var ");
            try self.writeBinding(field.name);
            try self.writeFmt(" = {s}.", .{INPUT_PARAM});
            try self.writeBinding(field.name);
            if (field.default) |dflt| {
                try self.write(" ?? ");
                try self.writeCsExpr(dflt);
            }
            try self.write(";\n");
        }

        switch (impl) {
            .proc => |proc| {
                // A [transform] tor has NO runtime body: the transform's
                // output replaced every call site, so the decl-site handler
                // is dead — splice a self-naming stub, not the proc's
                // stage-C Zig source.
                if (annotation_parser.hasPart(event.annotations, "transform")) {
                    try self.writeFmt("      throw new global::System.Exception(\"{s}: [transform] tor is lowered at compile time and must never be called\");\n", .{name});
                } else {
                    try self.emitReindented(proc.body.text, "      ");
                }
                try self.write("\n");
            },
            // A per-call `|template|` proc was rendered into every call site
            // before the emitter ran — the decl-site handler is dead code and
            // its body is template text. The stub NAMES itself.
            .template_stub => try self.writeFmt(
                "      throw new global::System.Exception(\"{s}: |template| proc is inlined at call sites and must never be called\");\n",
                .{name},
            ),
            .immediate => |ii| try self.emitBranchConstructorReturn(&ii.value, "      "),
            .subflow => |flow| try self.emitSubflowImplBody(event, flow, "      "),
        }
        try self.write("    }\n  }\n");
    }

    /// Emit `return <value>;` for a BranchConstructor — the shared shape
    /// behind an immediate impl (`greet -> "hi"`, `step => continue`) and a
    /// subflow arm that produces an outcome. The C# spelling reads back
    /// through `dynamic` exactly as the JS tagged object does:
    ///
    ///   `-> expr`          → `return <expr>;`                    (no tag)
    ///   `=> b`             → `return new { tag = "b" };`
    ///   `=> b v`           → `return new { tag = "b", b = v };`
    ///   `=> b { f: v, … }` → `return new { tag = "b", b = new { f = v, … } };`
    ///
    /// Payload member names go through writeBinding (kebab → underscore,
    /// reserved → `@name`); the tag string stays raw. Producer and reader
    /// agree by construction.
    fn emitBranchConstructorReturn(self: *Emitter, bc: *const ast.BranchConstructor, indent: []const u8) CsEmitError!void {
        if (bc.is_bare_return) {
            try self.writeFmt("{s}return ", .{indent});
            if (bc.plain_value) |pv| {
                try self.writeProduceValue(pv);
            } else {
                try self.write("null");
            }
            try self.write(";\n");
            return;
        }

        try self.writeFmt("{s}return new {{ tag = \"{s}\"", .{ indent, bc.branch_name });
        if (bc.plain_value) |pv| {
            try self.write(", ");
            try self.writeBinding(bc.branch_name);
            try self.write(" = ");
            try self.writeProduceValue(pv);
        } else if (bc.fields.len > 0) {
            try self.write(", ");
            try self.writeBinding(bc.branch_name);
            try self.write(" = new { ");
            for (bc.fields, 0..) |field, k| {
                if (k > 0) try self.write(", ");
                try self.writeBinding(field.name);
                try self.write(" = ");
                try self.writeCsExpr(if (field.expression_str) |e| e else field.type);
            }
            try self.write(" }");
        }
        try self.write(" };\n");
    }

    /// A produce value is an expression or a Koru STRUCT LITERAL in braces
    /// (`-> { final.sum, final.max }`). The braced form re-emits as a C#
    /// anonymous object under the pun law; plain-value braces unwrap.
    /// `struct_literal`'s predicates decide which — the same law the parser
    /// and both other emitters read.
    fn writeProduceValue(self: *Emitter, value: []const u8) CsEmitError!void {
        const trimmed = std.mem.trim(u8, value, " \t\r\n");
        if (trimmed.len < 2 or trimmed[0] != '{' or trimmed[trimmed.len - 1] != '}') {
            return self.writeCsExpr(value);
        }
        const inner = std.mem.trim(u8, trimmed[1 .. trimmed.len - 1], " \t\r\n");
        if (inner.len > 0 and struct_literal.isBracedPlainExpression(trimmed)) {
            return self.writeCsExpr(inner);
        }
        const fields = struct_literal.parseFields(self.allocator, trimmed) catch
            return self.writeCsExpr(value);
        if (fields.len == 0) return self.writeCsExpr(value);
        try self.write("new { ");
        for (fields, 0..) |f, i| {
            if (i > 0) try self.write(", ");
            try self.writeBinding(f.name);
            try self.write(" = ");
            try self.writeCsExpr(f.value);
        }
        try self.write(" }");
    }

    /// Emit the body of a SUBFLOW implementation — a flow whose `impl_of`
    /// names the event being emitted. The body is an ordinary dispatch; the
    /// only difference is that it sits inside a handler method, which is what
    /// turns a branch-constructor arm into a `return`.
    fn emitSubflowImplBody(self: *Emitter, event: *const ast.EventDecl, flow: *const ast.Flow, indent: []const u8) CsEmitError!void {
        const saved = self.impl_event;
        self.impl_event = event;
        defer self.impl_event = saved;

        if (flow.preamble_code != null and !preambleThenCall(flow.inv())) {
            try self.emitPreamble(flow.preamble_code, indent);
            try self.emitPreambleContinuations(flow.body.continuations, indent);
            return;
        }
        try self.emitPreamble(flow.preamble_code, indent);

        if (flow.inline_body) |raw| {
            var consumed: u64 = 0;
            try self.emitInlineBodyResolvingContinuations(stripInlineStmtMarker(raw), flow.body.continuations, indent, &consumed);
            try self.write("\n");
            try self.emitUnconsumedContinuations(flow.body.continuations, consumed, indent);
            return;
        }
        if (flow.pre_label) |label| {
            log.err("[cs_emitter] #{s} folds are not yet modelled on the cs target\n", .{label});
            return CsEmitError.UnsupportedConstruct;
        }
        try self.emitInvocationWithContinuations(flow.inv(), flow.body.continuations, indent);
    }

    /// Write a KORU expression as C# — through codegen_utils's `.cs` arm:
    /// `and`/`or` → `&&`/`||`, `.len` → `.Length`, `++` → `+`, unknown
    /// `@builtins` refuse.
    fn writeCsExpr(self: *Emitter, expr: []const u8) CsEmitError!void {
        try self.writeLowered(expr, .koru_expr);
    }

    /// Write HOST text (a rendered template body) — the `.host_text` mode:
    /// `++` stays (a genuine increment in C# text), operators and builtins
    /// still lower.
    fn writeHostText(self: *Emitter, text: []const u8) CsEmitError!void {
        try self.writeLowered(text, .host_text);
    }

    const LowerMode = codegen_utils.ExprMode;

    /// The emitter's door onto the shared lowering — turns a refused
    /// operation into this emitter's own diagnostic.
    fn writeLowered(self: *Emitter, text: []const u8, mode: LowerMode) CsEmitError!void {
        var diag = codegen_utils.LowerDiag{};
        const lowered = codegen_utils.lowerKoruExpr(self.allocator, text, .cs, mode, &diag) catch |err| switch (err) {
            error.OutOfMemory => return CsEmitError.OutOfMemory,
            error.UnsupportedBuiltin => {
                log.err("[cs_emitter] host builtin '@{s}' has no C# lowering\n", .{diag.unknown_builtin});
                return CsEmitError.UnsupportedConstruct;
            },
        };
        defer self.allocator.free(lowered);
        try self.buf.appendSlice(self.allocator, lowered);
    }

    /// Where an event declaration was found, paired with the item list its
    /// implementation resolves against.
    const DeclSite = struct {
        decl: *const ast.EventDecl,
        scope: []const ast.Item,
    };

    /// Bound for the implementability walk — the event graph is cyclic, so
    /// the walk needs a stop. Same cap as the JS emitter.
    const IMPL_WALK_DEPTH: u8 = 32;

    fn findDeclSiteIn(self: *Emitter, scope: []const ast.Item, path: *const ast.DottedPath, current_module: ?[]const u8) ?DeclSite {
        for (scope) |*item| {
            switch (item.*) {
                .event_decl => |*e| {
                    if (pathsEqualWithModule(&e.path, path, current_module, self.main_module_name)) {
                        return .{ .decl = e, .scope = scope };
                    }
                },
                .module_decl => |*m| {
                    if (self.findDeclSiteIn(m.items, path, m.logical_name)) |found| return found;
                },
                else => {},
            }
        }
        return null;
    }

    /// Is this event's behaviour reachable ON THE CS TARGET — does every leaf
    /// its body reaches have a cs body? The transitive predicate that keeps
    /// unported stdlib events out of the output without skipping anything a
    /// call site can dispatch to.
    fn eventIsCsImplementable(self: *Emitter, site: DeclSite, depth: u8) bool {
        if (depth == 0) return false;
        const impl = self.findImplIn(site.scope, &site.decl.path) orelse return false;
        return switch (impl) {
            .proc, .template_stub => true,
            .immediate => true,
            .subflow => |flow| self.subflowIsCsImplementable(site.decl, flow, depth - 1),
        };
    }

    fn subflowIsCsImplementable(self: *Emitter, event: *const ast.EventDecl, flow: *const ast.Flow, depth: u8) bool {
        if (flow.inline_body != null) return true;
        if (!self.invocationIsCsImplementable(event, flow.inv(), depth)) return false;
        return self.continuationsAreCsImplementable(event, flow.body.continuations, depth);
    }

    fn continuationsAreCsImplementable(self: *Emitter, event: *const ast.EventDecl, conts: []const ast.Continuation, depth: u8) bool {
        for (conts) |*cont| {
            if (cont.node) |*node| {
                switch (node.*) {
                    .invocation => |*inv| {
                        if (!self.invocationIsCsImplementable(event, inv, depth)) return false;
                    },
                    .label_with_invocation => return false, // folds unmodelled
                    .terminal, .branch_constructor => {},
                    .inline_code => |text| if (!self.csHostTextLowers(text)) return false,
                    else => return false,
                }
            }
            if (!self.continuationsAreCsImplementable(event, cont.continuations, depth)) return false;
        }
        return true;
    }

    /// Trial-lower `.inline_code` text the way `emitPreamble` will — a
    /// lowering failure means this leaf cannot emit.
    fn csHostTextLowers(self: *Emitter, text: []const u8) bool {
        var it = std.mem.splitScalar(u8, text, '\n');
        while (it.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0) continue;
            var diag = codegen_utils.LowerDiag{};
            const lowered = codegen_utils.lowerKoruExpr(self.allocator, trimmed, .cs, .host_text, &diag) catch return false;
            self.allocator.free(lowered);
        }
        return true;
    }

    fn invocationIsCsImplementable(self: *Emitter, impl_event: *const ast.EventDecl, inv: *const ast.Invocation, depth: u8) bool {
        if (inv.inline_body != null) return true;
        if (findEffectArm(impl_event, &inv.path) != null) return true;
        const site = self.findDeclSiteIn(self.items, &inv.path, null) orelse return false;
        return self.eventIsCsImplementable(site, depth);
    }

    /// Record `event`'s lowered class key as taken.
    fn claimEventKey(self: *Emitter, keys: *EmittedKeys, event: *const ast.EventDecl) CsEmitError!void {
        var buf: [256]u8 = undefined;
        const name = event.path.segments[event.path.segments.len - 1];
        if (name.len > buf.len) return;
        const key = lowerIdentBuf(&buf, name);
        if (keys.contains(key)) return;
        try keys.put(try self.allocator.dupe(u8, key), {});
    }

    /// Emit the events of an imported module. Three outcomes, same as the JS
    /// emitter: implementable → ordinary handler; not implementable + not
    /// reached → absent in silence (most of the stdlib); not implementable
    /// but REACHED → a handler that throws, naming itself and its module —
    /// `NullReferenceException` at the call frame would say neither.
    fn emitModuleEventDecls(
        self: *Emitter,
        module: *const ast.ModuleDecl,
        reached: *const ReachedEvents,
        emitted_keys: *EmittedKeys,
    ) CsEmitError!void {
        for (module.items) |*item| {
            switch (item.*) {
                .event_decl => |*event| {
                    const site = DeclSite{ .decl = event, .scope = module.items };
                    if (self.eventIsCsImplementable(site, IMPL_WALK_DEPTH)) {
                        try self.emitEventDecl(event, module.items);
                        try self.claimEventKey(emitted_keys, event);
                        continue;
                    }
                    if (!reached.contains(event)) continue;
                    var name_buf: [256]u8 = undefined;
                    const name = event.path.segments[event.path.segments.len - 1];
                    if (name.len > name_buf.len) continue;
                    const key = lowerIdentBuf(&name_buf, name);
                    if (emitted_keys.contains(key)) continue;
                    try self.emitUnlowerableEventRefusal(event, module);
                    try self.claimEventKey(emitted_keys, event);
                },
                .module_decl => |*nested| try self.emitModuleEventDecls(nested, reached, emitted_keys),
                else => {},
            }
        }
    }

    /// A handler for an event this target cannot lower, whose whole body is
    /// the diagnostic — the exception that arrives AT the call frame and says
    /// which event and why.
    fn emitUnlowerableEventRefusal(self: *Emitter, event: *const ast.EventDecl, module: *const ast.ModuleDecl) CsEmitError!void {
        var name_buf: [256]u8 = undefined;
        const name = event.path.segments[event.path.segments.len - 1];
        try self.writeFmt("  public static class {s}_event {{\n", .{lowerIdentBuf(&name_buf, name)});
        try self.writeFmt("    public static dynamic handler(dynamic {s}) {{\n", .{INPUT_PARAM});
        try self.writeFmt(
            "      throw new global::System.Exception(\"{s}:{s} has no C# implementation — its body resolves only to a non-cs target (|zig / [comptime]), directly or through a callee\");\n",
            .{ module.logical_name, name },
        );
        try self.write("    }\n  }\n");
    }

    /// The event decls the emitted program actually reaches, seeded from the
    /// flows Phase 2 will emit — the same filter, so the two cannot disagree.
    fn collectReachedEvents(self: *Emitter, reached: *ReachedEvents) CsEmitError!void {
        for (self.items) |*item| {
            if (item.* != .flow) continue;
            const flow = &item.flow;
            if (flow.impl_of != null) continue;
            if (self.isDeclarationFlow(flow)) continue;
            if (flow.inv().path.module_qualifier) |mq| {
                if (std.mem.eql(u8, mq, "koru")) continue;
            }
            if (self.flowIsNorunSite(flow)) continue;
            try self.reachFlow(null, flow, reached, IMPL_WALK_DEPTH);
        }
    }

    fn reachFlow(self: *Emitter, impl_event: ?*const ast.EventDecl, flow: *const ast.Flow, reached: *ReachedEvents, depth: u8) CsEmitError!void {
        if (depth == 0) return;
        try self.reachInvocation(impl_event, flow.inv(), reached, depth);
        try self.reachContinuations(impl_event, flow.body.continuations, reached, depth);
    }

    fn reachContinuations(self: *Emitter, impl_event: ?*const ast.EventDecl, conts: []const ast.Continuation, reached: *ReachedEvents, depth: u8) CsEmitError!void {
        if (depth == 0) return;
        for (conts) |*cont| {
            if (cont.node) |*node| switch (node.*) {
                .invocation => |*inv| try self.reachInvocation(impl_event, inv, reached, depth),
                else => {},
            };
            try self.reachContinuations(impl_event, cont.continuations, reached, depth);
        }
    }

    fn reachInvocation(self: *Emitter, impl_event: ?*const ast.EventDecl, inv: *const ast.Invocation, reached: *ReachedEvents, depth: u8) CsEmitError!void {
        if (depth == 0) return;
        if (impl_event) |ie| {
            if (findEffectArm(ie, &inv.path) != null) return;
        }
        // A call site a comptime transform already rendered to host text is
        // spliced, not dispatched — the callee is NOT reached.
        if (inv.inline_body != null) return;
        const site = self.findDeclSiteIn(self.items, &inv.path, null) orelse return;
        if ((try reached.getOrPut(site.decl)).found_existing) return;
        const impl = self.findImplIn(site.scope, &site.decl.path) orelse return;
        switch (impl) {
            .subflow => |flow| {
                if (flow.inline_body != null) return;
                try self.reachFlow(site.decl, flow, reached, depth - 1);
            },
            else => {},
        }
    }

    /// Emit a top-level flow as `flowN()`.
    fn emitFlow(self: *Emitter, flow: *const ast.Flow, flow_num: usize) CsEmitError!void {
        try self.writeFmt("  public static void flow{d}() {{\n", .{flow_num});
        // PREAMBLE REPLACES THE CALL — a dissolving transform hangs the real
        // declaration on `preamble_code`; emitting the handler call as well
        // would call a comptime event that has no runtime body.
        if (flow.preamble_code != null and !preambleThenCall(flow.inv())) {
            try self.emitPreamble(flow.preamble_code, "    ");
            try self.emitPreambleContinuations(flow.body.continuations, "    ");
            try self.write("  }\n");
            return;
        }
        try self.emitPreamble(flow.preamble_code, "    ");
        if (flow.inline_body) |inline_body_raw| {
            const stripped = stripInlineStmtMarker(inline_body_raw);
            var consumed: u64 = 0;
            try self.emitInlineBodyResolvingContinuations(stripped, flow.body.continuations, "    ", &consumed);
            try self.write("\n");
            try self.emitUnconsumedContinuations(flow.body.continuations, consumed, "    ");
        } else if (flow.pre_label) |label| {
            log.err("[cs_emitter] #{s} folds are not yet modelled on the cs target\n", .{label});
            return CsEmitError.UnsupportedConstruct;
        } else {
            try self.emitInvocationWithContinuations(flow.inv(), flow.body.continuations, "    ");
        }
        try self.write("  }\n");
    }

    /// Emit a flow's `preamble_code` — host DECLARATION text a comptime
    /// transform hung on the flow to run ahead of its dispatch. Authored in
    /// the BUILD language by the transform itself, so it goes through
    /// writeHostText only.
    fn emitPreamble(self: *Emitter, preamble: ?[]const u8, indent: []const u8) CsEmitError!void {
        const text = preamble orelse return;
        const trimmed = std.mem.trim(u8, text, " \t\r\n");
        var it = std.mem.splitScalar(u8, trimmed, '\n');
        while (it.next()) |line| {
            const line_trimmed = std.mem.trim(u8, line, " \t\r");
            if (line_trimmed.len == 0) continue;
            try self.write(indent);
            try self.writeHostText(line_trimmed);
            try self.write("\n");
        }
    }

    /// Emit the continuations of a flow whose `preamble_code` REPLACED its
    /// invocation — body-only, in source order (no result value, no tag to
    /// dispatch on).
    fn emitPreambleContinuations(
        self: *Emitter,
        continuations: []const ast.Continuation,
        indent: []const u8,
    ) CsEmitError!void {
        for (continuations) |*cont| {
            try self.emitInlineContinuationBody(cont, indent);
        }
    }

    /// Emit a rendered template body (e.g. `~if`'s `if (cond) { … } else { …
    /// }`), resolving the splice markers template_processor mints:
    ///
    ///   - `__koru_continue_N`             — a terminal continuation hand-off.
    ///   - `__koru_inline[_scoped]_N(arg)` — an EFFECT-handler splice — the
    ///                                       vertical refuses these (effects
    ///                                       are unmodelled).
    ///
    /// Scan by marker POSITION: earliest remaining marker, verbatim text
    /// before it through writeHostText, resolve, repeat.
    fn emitInlineBodyResolvingContinuations(
        self: *Emitter,
        body: []const u8,
        continuations: []const ast.Continuation,
        indent: []const u8,
        consumed: ?*u64,
    ) CsEmitError!void {
        if (consumed) |c| {
            if (continuations.len > 64) c.* = ~@as(u64, 0);
        }
        const body_indent = try std.fmt.allocPrint(self.allocator, "{s}  ", .{indent});
        defer self.allocator.free(body_indent);

        const SPLICE_PREFIX = "__koru_inline_";
        const CONTINUE_PREFIX = "__koru_continue_";
        const BARE_INFIX = "bare_";

        const trimmed = std.mem.trim(u8, body, " \t\r\n");
        var pos: usize = 0;
        while (true) {
            const splice_at = std.mem.indexOfPos(u8, trimmed, pos, SPLICE_PREFIX);
            const continue_at = std.mem.indexOfPos(u8, trimmed, pos, CONTINUE_PREFIX);
            var m: usize = undefined;
            var is_continue: bool = undefined;
            if (splice_at) |s| {
                if (continue_at) |r| {
                    is_continue = r < s;
                    m = if (is_continue) r else s;
                } else {
                    is_continue = false;
                    m = s;
                }
            } else if (continue_at) |r| {
                is_continue = true;
                m = r;
            } else {
                break;
            }

            try self.writeHostText(trimmed[pos..m]);

            if (is_continue) {
                var i = m + CONTINUE_PREFIX.len;
                const is_bare = std.mem.startsWith(u8, trimmed[i..], BARE_INFIX);
                if (is_bare) i += BARE_INFIX.len;
                const idx = codegen_utils.scanDecimalIndex(trimmed, &i) orelse {
                    log.err("[cs_emitter] malformed __koru_continue marker\n", .{});
                    return CsEmitError.UnsupportedConstruct;
                };
                if (idx >= continuations.len) {
                    log.err("[cs_emitter] __koru_continue_{d} has no matching continuation (have {d})\n", .{ idx, continuations.len });
                    return CsEmitError.UnsupportedConstruct;
                }
                if (consumed) |c| {
                    if (idx < 64) c.* |= @as(u64, 1) << @intCast(idx);
                }
                const cont = &continuations[idx];
                const guarded = !is_bare and cont.condition != null;
                try self.write("{ ");
                if (guarded) {
                    try self.write("if (");
                    try self.writeCsExpr(cont.condition.?);
                    try self.write(") { ");
                }
                try self.emitInlineContinuationBody(cont, body_indent);
                if (guarded) try self.write(" }");
                try self.write(" }");
                pos = i;
                continue;
            }

            // EFFECT splice — `__koru_inline[_scoped]_N(arg)`. The vertical
            // does not model effect handlers; refuse by name rather than
            // splice a shape unmeasured.
            log.err("[cs_emitter] effect-handler splice (__koru_inline_N) reached — effect continuations are not yet modelled on the cs target\n", .{});
            return CsEmitError.UnsupportedConstruct;
        }
        try self.writeHostText(trimmed[pos..]);
    }

    /// Emit the continuations of an inline body that resolved NO splice
    /// marker — the caller's own chain steps that drain body-only after a
    /// template consumed its arms. Mirrors emitUnconsumedContinuations in the
    /// JS emitter: named leftovers of a dispatcher body are the template's
    /// own (skip); unnamed leftovers (and everything on a rendered-statement
    /// body) drain.
    fn emitUnconsumedContinuations(
        self: *Emitter,
        continuations: []const ast.Continuation,
        consumed: u64,
        indent: []const u8,
    ) CsEmitError!void {
        for (continuations, 0..) |*cont, ci| {
            if (cont.kind != .terminal) continue;
            if (ci < 64 and (consumed & (@as(u64, 1) << @intCast(ci))) != 0) continue;
            if (consumed != 0) {
                if (cont.branch.len != 0) continue;
                try self.emitInlineContinuationBody(cont, indent);
            } else {
                try self.emitTerminalContinuation(cont, null, indent, false, false, null);
            }
        }
    }

    /// Emit the body of a terminal continuation spliced inline by a template
    /// marker — the body itself, no tag-dispatch guard and no payload bind
    /// (the template's own conditional does the branching).
    fn emitInlineContinuationBody(self: *Emitter, cont: *const ast.Continuation, indent: []const u8) CsEmitError!void {
        const node = cont.node orelse return;
        switch (node) {
            .invocation => |*inv| {
                if (inv.preamble_code) |preamble| try self.emitPreamble(preamble, indent);
                try self.emitInvocationWithContinuations(inv, cont.continuations, indent);
            },
            .terminal => {},
            .branch_constructor => |*bc| try self.emitBranchConstructorReturn(bc, indent),
            .expression => |expr| {
                try self.writeFmt("{s}return ", .{indent});
                try self.writeCsExpr(expr);
                try self.write(";\n");
            },
            .assignment => |asgn| {
                try self.emitAssignment(&asgn, indent);
                try self.emitPreambleContinuations(cont.continuations, indent);
            },
            .inline_code => |text| {
                try self.emitPreamble(text, indent);
                try self.emitPreambleContinuations(cont.continuations, indent);
            },
            else => {
                log.err("[cs_emitter] inline continuation body is a {s}, which the cs target does not model\n", .{@tagName(node)});
                return CsEmitError.UnsupportedConstruct;
            },
        }
    }

    /// Emit a `captured { … }` write as field stores into the cell — snapshot
    /// semantics (RHS temps hoist before any store), same ruling as both
    /// other targets.
    fn emitAssignment(self: *Emitter, asgn: anytype, indent: []const u8) CsEmitError!void {
        if (asgn.fields.len > 1) {
            try self.writeFmt("{s}{{\n", .{indent});
            const inner = try std.fmt.allocPrint(self.allocator, "{s}  ", .{indent});
            defer self.allocator.free(inner);
            for (asgn.fields, 0..) |field, i| {
                try self.writeFmt("{s}var __koru_asgn_{d} = ", .{ inner, i });
                try self.writeCsExpr(if (field.expression_str) |e| e else field.type);
                try self.write(";\n");
            }
            for (asgn.fields, 0..) |field, i| {
                try self.writeFmt("{s}{s}.{s} = __koru_asgn_{d};\n", .{ inner, asgn.target, field.name, i });
            }
            try self.writeFmt("{s}}}\n", .{indent});
            return;
        }
        for (asgn.fields) |field| {
            try self.writeFmt("{s}{s}.{s} = ", .{ indent, asgn.target, field.name });
            try self.writeCsExpr(if (field.expression_str) |e| e else field.type);
            try self.write(";\n");
        }
    }

    /// The call-site `: name` bind, or null when there is nothing to NAME
    /// (`_` is a discard).
    fn namedReturnBinding(inv: *const ast.Invocation) ?[]const u8 {
        const rb = inv.return_binding orelse return null;
        if (std.mem.eql(u8, rb, "_")) return null;
        return rb;
    }

    /// Recursively emit a dispatch: resolve `inv`'s event, call its handler,
    /// then drive the TERMINAL continuations on the returned `.tag`.
    /// Effect-bearing events and arm fires REFUSE — the Handlers-object
    /// machinery is a design conversation the vertical does not pre-empt.
    fn emitInvocationWithContinuations(
        self: *Emitter,
        inv: *const ast.Invocation,
        continuations: []const ast.Continuation,
        indent: []const u8,
    ) CsEmitError!void {
        // TRANSFORM-PRODUCED INLINE BODY: a comptime|transform rerouted this
        // invocation to an impl stub and stored target-lowered code on
        // inv.inline_body. Splice it here, at every depth.
        if (inv.inline_body) |inline_body_raw| {
            const stripped = stripInlineStmtMarker(inline_body_raw);
            var consumed: u64 = 0;
            try self.emitInlineBodyResolvingContinuations(stripped, continuations, indent, &consumed);
            try self.write("\n");
            try self.emitUnconsumedContinuations(continuations, consumed, indent);
            return;
        }
        // An effect-arm fire is a callback into the caller — and unmodelled.
        if (self.impl_event) |impl_ev| {
            if (findEffectArm(impl_ev, &inv.path)) |arm| {
                log.err("[cs_emitter] effect-arm fire '{s}' is not yet modelled on the cs target\n", .{arm.name});
                return CsEmitError.UnsupportedConstruct;
            }
        }

        const event = self.findEventDecl(&inv.path) orelse {
            log.err("[cs_emitter] flow invokes unresolved event\n", .{});
            return CsEmitError.UnresolvedEvent;
        };

        var event_has_effect = false;
        var terminal_branches: usize = 0;
        for (event.branches) |b| {
            if (b.kind == .effect) {
                event_has_effect = true;
            } else {
                terminal_branches += 1;
            }
        }
        if (event_has_effect) {
            log.err("[cs_emitter] invocation of effect-bearing event '{s}' is not yet modelled on the cs target\n", .{event.path.segments[event.path.segments.len - 1]});
            return CsEmitError.UnsupportedConstruct;
        }
        const callee_bare_return = terminal_branches == 0 and event.return_type != null;

        // Only allocate a result binding when a continuation actually reads
        // it (a payload bind, a 2+ branch dispatch, a call-site `: name`).
        var needs_result = false;
        var terminal_count: usize = 0;
        for (continuations) |*cont| {
            if (cont.kind != .terminal) continue;
            terminal_count += 1;
            if (cont.binding != null and !std.mem.eql(u8, cont.binding.?, "_")) {
                needs_result = true;
            }
            if (cont.destructure.len > 0) needs_result = true;
        }
        if (terminal_count >= 2 and !callee_bare_return) needs_result = true;
        if (namedReturnBinding(inv) != null) needs_result = true;

        var ev_name_buf: [256]u8 = undefined;
        const ev_name = lowerIdentBuf(&ev_name_buf, event.path.segments[event.path.segments.len - 1]);
        const result_name: ?[]const u8 = if (!needs_result) null else if (namedReturnBinding(inv)) |rb|
            try self.allocator.dupe(u8, rb)
        else blk: {
            const rid = self.nextId();
            break :blk try std.fmt.allocPrint(self.allocator, "result_{d}", .{rid});
        };
        defer if (result_name) |rn| self.allocator.free(rn);

        if (result_name) |rn| {
            try self.writeFmt("{s}var {s} = main_module.{s}_event.handler(", .{ indent, rn, ev_name });
        } else {
            try self.writeFmt("{s}main_module.{s}_event.handler(", .{ indent, ev_name });
        }
        try self.emitArgsObject(inv.args);
        try self.write(");\n");

        // A BIND-POSITION destructure (`~locate(): { pos: { x, y } } |> …`).
        if (inv.return_destructure.len > 0) {
            if (result_name) |rn| {
                try self.emitDestructureBindings(inv.return_destructure, rn, indent);
            }
        }

        // Drive terminal continuations — 2+ branches dispatch on `.tag`.
        const needs_dispatch = terminal_count >= 2 and !callee_bare_return;
        try self.emitTerminalContinuations(continuations, result_name, indent, needs_dispatch, callee_bare_return);
    }

    /// Emit the terminal `| branch` continuations of a dispatch. A `when`
    /// guard anywhere in the set switches the whole group to the guarded
    /// `__matched` chain (first match wins, conditions read their bindings).
    fn emitTerminalContinuations(
        self: *Emitter,
        continuations: []const ast.Continuation,
        result_name: ?[]const u8,
        indent: []const u8,
        dispatch: bool,
        bare_return: bool,
    ) CsEmitError!void {
        var needs_chain = false;
        for (continuations) |*cont| {
            if (cont.kind != .terminal) continue;
            if (cont.condition != null) needs_chain = true;
        }

        var matched: ?[]const u8 = null;
        defer if (matched) |m| self.allocator.free(m);
        if (needs_chain) {
            matched = try std.fmt.allocPrint(self.allocator, "__matched_{d}", .{self.nextId()});
            try self.writeFmt("{s}var {s} = false;\n", .{ indent, matched.? });
        }

        for (continuations) |*cont| {
            if (cont.kind != .terminal) continue;
            try self.emitTerminalContinuation(cont, result_name, indent, dispatch, bare_return, matched);
        }
    }

    /// Emit a terminal continuation: `| done r |> BODY` →
    /// `var r = <result>.done;` then BODY.
    fn emitTerminalContinuation(
        self: *Emitter,
        cont: *const ast.Continuation,
        result_name: ?[]const u8,
        indent: []const u8,
        dispatch: bool,
        bare_return: bool,
        matched: ?[]const u8,
    ) CsEmitError!void {
        var indents: [2][]u8 = undefined;
        var indent_count: usize = 0;
        defer for (indents[0..indent_count]) |s| self.allocator.free(s);
        var body_indent = indent;
        var open_braces: usize = 0;

        const deeper = struct {
            fn f(em: *Emitter, base: []const u8) CsEmitError![]u8 {
                return std.fmt.allocPrint(em.allocator, "{s}  ", .{base});
            }
        }.f;

        if (matched) |mv| {
            try self.writeFmt("{s}if (!{s}", .{ indent, mv });
            if (dispatch and cont.branch.len > 0) {
                const rn = result_name orelse {
                    log.err("[cs_emitter] guarded terminal chain needs a result value but none was emitted\n", .{});
                    return CsEmitError.UnsupportedConstruct;
                };
                try self.writeFmt(" && {s}.tag == \"{s}\"", .{ rn, cont.branch });
            }
            try self.write(") {\n");
            indents[indent_count] = try deeper(self, indent);
            body_indent = indents[indent_count];
            indent_count += 1;
            open_braces += 1;
        } else if (dispatch) {
            const rn = result_name orelse {
                log.err("[cs_emitter] terminal dispatch needs a result value but none was emitted\n", .{});
                return CsEmitError.UnsupportedConstruct;
            };
            try self.writeFmt("{s}if ({s}.tag == \"{s}\") {{\n", .{ indent, rn, cont.branch });
            indents[indent_count] = try deeper(self, indent);
            body_indent = indents[indent_count];
            indent_count += 1;
            open_braces += 1;
        }

        if (cont.binding) |binding| {
            if (!std.mem.eql(u8, binding, "_")) {
                const rn = result_name orelse {
                    log.err("[cs_emitter] terminal continuation binds '{s}' (branch '{s}') but no result binding was emitted\n", .{ binding, cont.branch });
                    return CsEmitError.UnsupportedConstruct;
                };
                if (bare_return or cont.branch.len == 0) {
                    try self.writeFmt("{s}var ", .{body_indent});
                    try self.writeBinding(binding);
                    try self.writeFmt(" = {s};\n", .{rn});
                } else {
                    try self.writeFmt("{s}var ", .{body_indent});
                    try self.writeBinding(binding);
                    try self.write(" = ");
                    try self.writeMember(rn, cont.branch);
                    try self.write(";\n");
                }
            }
        }

        if (cont.destructure.len > 0) {
            const rn = result_name orelse {
                log.err("[cs_emitter] terminal continuation destructures a payload but no result binding was emitted\n", .{});
                return CsEmitError.UnsupportedConstruct;
            };
            var base_buf = std.ArrayList(u8).empty;
            defer base_buf.deinit(self.allocator);
            try base_buf.appendSlice(self.allocator, rn);
            if (!(bare_return or cont.branch.len == 0)) {
                try base_buf.append(self.allocator, '.');
                var kb: [256]u8 = undefined;
                if (cont.branch.len <= kb.len) {
                    const lowered = lowerIdentBuf(&kb, cont.branch);
                    try base_buf.appendSlice(self.allocator, lowered);
                }
            }
            try self.emitDestructureBindings(cont.destructure, base_buf.items, body_indent);
        }

        // The `when` guard runs AFTER the bindings — it reads them.
        if (cont.condition) |condition| {
            try self.writeFmt("{s}if (", .{body_indent});
            try self.writeCsExpr(condition);
            try self.write(") {\n");
            indents[indent_count] = try deeper(self, body_indent);
            body_indent = indents[indent_count];
            indent_count += 1;
            open_braces += 1;
        }

        if (matched) |mv| try self.writeFmt("{s}{s} = true;\n", .{ body_indent, mv });

        if (cont.node) |node| {
            switch (node) {
                .invocation => |*inv| {
                    try self.emitInvocationWithContinuations(inv, cont.continuations, body_indent);
                },
                .terminal => {},
                .branch_constructor => |*bc| try self.emitBranchConstructorReturn(bc, body_indent),
                .expression => |expr| {
                    try self.writeFmt("{s}return ", .{body_indent});
                    try self.writeCsExpr(expr);
                    try self.write(";\n");
                },
                .assignment => |asgn| {
                    try self.emitAssignment(&asgn, body_indent);
                    try self.emitPreambleContinuations(cont.continuations, body_indent);
                },
                .inline_code => |text| {
                    try self.emitPreamble(text, body_indent);
                    try self.emitPreambleContinuations(cont.continuations, body_indent);
                },
                else => {
                    log.err("[cs_emitter] terminal continuation body is a {s}, which the cs target does not model\n", .{@tagName(node)});
                    return CsEmitError.UnsupportedConstruct;
                },
            }
        }

        var to_close = open_braces;
        while (to_close > 0) : (to_close -= 1) {
            const close_at = if (to_close == 1) indent else indents[to_close - 2];
            try self.writeFmt("{s}}}\n", .{close_at});
        }
    }

    /// Bind a shape-destructure's fields off `base`, recursing into nested
    /// destructures by lengthening the access path.
    fn emitDestructureBindings(
        self: *Emitter,
        fields: []const ast.DestructureField,
        base: []const u8,
        indent: []const u8,
    ) CsEmitError!void {
        for (fields) |field| {
            if (std.mem.eql(u8, field.name, "_")) continue;
            if (field.sub.len > 0) {
                const path = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ base, field.name });
                defer self.allocator.free(path);
                try self.emitDestructureBindings(field.sub, path, indent);
                continue;
            }
            try self.writeFmt("{s}var ", .{indent});
            try self.writeBinding(field.name);
            try self.write(" = ");
            try self.writeMember(base, field.name);
            try self.write(";\n");
        }
    }

    /// Emit the args as a C# anonymous object: `new { name = value, … }`.
    fn emitArgsObject(self: *Emitter, args: []const ast.Arg) CsEmitError!void {
        if (args.len == 0) {
            try self.write("new { }");
            return;
        }
        try self.write("new { ");
        for (args, 0..) |arg, idx| {
            if (idx > 0) try self.write(", ");
            try self.writeBinding(arg.name);
            try self.write(" = ");
            try self.writeCsExpr(arg.value);
        }
        try self.write(" }");
    }

    /// Re-indent a multi-line opaque body to `indent`, trimming leading blank
    /// lines and trailing whitespace. `$mod.` resolves to `main_module.` —
    /// the module-scope spelling a |cs body uses, where JS's file scope made
    /// the same name bare.
    fn emitReindented(self: *Emitter, body: []const u8, indent: []const u8) CsEmitError!void {
        const stripped = try csModQualify(self.allocator, body);
        defer self.allocator.free(stripped);
        const trimmed = std.mem.trim(u8, stripped, " \t\r\n");
        var it = std.mem.splitScalar(u8, trimmed, '\n');
        var first = true;
        while (it.next()) |line| {
            if (!first) try self.write("\n");
            first = false;
            const line_trimmed = std.mem.trimRight(u8, line, " \t\r");
            const content = std.mem.trimLeft(u8, line_trimmed, " \t");
            if (content.len == 0) continue;
            try self.write(indent);
            try self.write(content);
        }
    }
};

/// Does this proc declare `[template]` and apply to the cs build? A null
/// target is target-agnostic, `|cs` is ours, anything else is not.
fn templateProcTargetsCs(proc: *const ast.ProcDecl) bool {
    var annotated = false;
    for (proc.annotations) |ann| {
        if (std.mem.eql(u8, ann, "template")) {
            annotated = true;
            break;
        }
    }
    if (!annotated) return false;
    const target = proc.target orelse return true;
    return std.mem.eql(u8, target, CS_TARGET);
}

/// Strip the leading `//@koru:inline_stmt\n` marker that template_processor
/// prepends to a statement-shaped rendered body.
fn stripInlineStmtMarker(text: []const u8) []const u8 {
    const marker = "//@koru:inline_stmt\n";
    if (std.mem.startsWith(u8, text, marker)) return text[marker.len..];
    return text;
}

/// Is `path` a bare reference to one of `event`'s own EFFECT arms?
fn findEffectArm(event: *const ast.EventDecl, path: *const ast.DottedPath) ?*const ast.Branch {
    if (path.segments.len != 1) return null;
    if (path.module_qualifier) |mq| {
        if (event.path.module_qualifier) |emq| {
            if (!std.mem.eql(u8, mq, emq)) return null;
        }
    }
    for (event.branches) |*b| {
        if (b.kind == .effect and std.mem.eql(u8, b.name, path.segments[0])) return b;
    }
    return null;
}

/// `$mod.` → `main_module.` — the sanctioned module-scope spelling resolves
/// to the named static class on C#, where JS's file scope made it bare.
/// Skips string/char literal contents.
fn csModQualify(allocator: std.mem.Allocator, body: []const u8) ![]u8 {
    var out = try std.ArrayList(u8).initCapacity(allocator, body.len + 32);
    errdefer out.deinit(allocator);
    var i: usize = 0;
    var q: u8 = 0;
    while (i < body.len) {
        const c = body[i];
        if (q != 0) {
            try out.append(allocator, c);
            if (c == '\\' and i + 1 < body.len) {
                try out.append(allocator, body[i + 1]);
                i += 2;
                continue;
            }
            if (c == q) q = 0;
            i += 1;
            continue;
        }
        if (c == '"' or c == '\'') {
            q = c;
            try out.append(allocator, c);
            i += 1;
            continue;
        }
        if (c == '$' and i + 5 < body.len and std.mem.eql(u8, body[i .. i + 5], "$mod.")) {
            try out.appendSlice(allocator, "main_module.");
            i += 5;
            continue;
        }
        try out.append(allocator, c);
        i += 1;
    }
    return out.toOwnedSlice(allocator);
}

fn isIdentChar(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or
        (c >= '0' and c <= '9') or c == '_';
}

/// True when the invocation asks for its preamble AND its handler call — the
/// `@preamble_then_call` contract. Every other preamble REPLACES the call.
fn preambleThenCall(inv: *const ast.Invocation) bool {
    for (inv.annotations) |ann| {
        if (std.mem.eql(u8, ann, "@preamble_then_call")) return true;
    }
    return false;
}

fn pathsEqual(a: *const ast.DottedPath, b: *const ast.DottedPath) bool {
    if (a.segments.len != b.segments.len) return false;
    for (a.segments, b.segments) |sa, sb| {
        if (!std.mem.eql(u8, sa, sb)) return false;
    }
    return true;
}

/// `long` ends with `short` on a `.`/`:` boundary — so `std.io` matches `io`.
fn qualifierSuffixMatch(long: []const u8, short: []const u8) bool {
    if (long.len <= short.len) return false;
    if (!std.mem.endsWith(u8, long, short)) return false;
    const sep = long[long.len - short.len - 1];
    return sep == '.' or sep == ':';
}

/// Two module qualifiers refer to the same module if equal, or one is a
/// dotted suffix of the other (`std.io` ≡ `io`).
fn moduleQualifiersMatch(a: []const u8, b: []const u8) bool {
    if (std.mem.eql(u8, a, b)) return true;
    return qualifierSuffixMatch(a, b) or qualifierSuffixMatch(b, a);
}

/// Module-aware path equality — declaration path vs call-site path, with
/// the qualifier reconciled against the effective module context.
fn pathsEqualWithModule(
    decl_path: *const ast.DottedPath,
    inv_path: *const ast.DottedPath,
    current_module: ?[]const u8,
    main_module: []const u8,
) bool {
    const a_mod = decl_path.module_qualifier;
    const b_mod = inv_path.module_qualifier;
    if (a_mod != null and b_mod != null) {
        if (!moduleQualifiersMatch(a_mod.?, b_mod.?)) return false;
    } else if ((a_mod != null) != (b_mod != null)) {
        const qual = if (a_mod != null) a_mod.? else b_mod.?;
        const effective = current_module orelse main_module;
        if (effective.len == 0) return false;
        if (!moduleQualifiersMatch(effective, qual)) return false;
    }
    if (decl_path.segments.len != inv_path.segments.len) return false;
    for (decl_path.segments, inv_path.segments) |sa, sb| {
        if (!std.mem.eql(u8, sa, sb)) return false;
    }
    return true;
}
