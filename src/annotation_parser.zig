// ============================================================================
// Annotation Parser - Shared Utilities for Parametrized Annotations
// ============================================================================
// This library provides parsing and querying utilities for Koru annotations.
//
// Koru annotations are stored as opaque strings in the AST:
//   annotations: []const []const u8 = &[_][]const u8{}
//
// Simple annotations: "pure", "comptime", "norun"
// Parametrized annotations: "depends_on(\"a\", \"b\")", "timeout(30)", "retry(3)"
//
// This library enables:
// - Frontend: Parse build orchestration annotations
// - Backend: Parse comptime metaprogramming annotations
// - Future: Any parametrized annotation (cache, retry, timeout, etc.)
//
// Design Philosophy:
// - Parser treats annotations as opaque strings
// - This library interprets the syntax
// - Separation of concerns: syntax vs semantics
// ============================================================================

const std = @import("std");
const expression_parser = @import("expression_parser");
const ast = @import("ast");

/// AnnotationCall represents a parsed parametrized annotation
/// Example: "depends_on(\"compile\", \"test\")" →
///   AnnotationCall{ .name = "depends_on", .args = ["compile", "test"] }
pub const AnnotationCall = struct {
    name: []const u8,
    args: [][]const u8,

    /// Free all memory associated with this annotation call
    pub fn deinit(self: *AnnotationCall, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        for (self.args) |arg| {
            allocator.free(arg);
        }
        allocator.free(self.args);
    }
};

// ============================================================================
// Expression-shaped call arguments - the language's own grammar, opt-in
// ============================================================================
// Annotation contents stay opaque by design; nothing here changes that.
// `parseCallExpr` runs each call argument through the language's own
// ExpressionParser - there is no second grammar for annotations - and
// yields a CallArg per argument:
//
//   .expr - the argument parsed as one whole expression (identifier,
//           literal, binary, call, field access, ...). `release` parses as
//           `.identifier`; `"release"` parses as `.literal.string` - the
//           distinction parseCall's unescaping erases is preserved because
//           arguments are parsed BEFORE quote-stripping.
//   .raw  - the argument is not an expression ("a | b", "v1.2"). The
//           verbatim text rides through as residue; the CONSUMER decides
//           whether that means keep, interpret, or refuse. Parsing is a
//           service offered to consumers, never a gate on annotation
//           contents - an annotation no consumer claims is still legal.
//
// Symbol resolution and meaning are deliberately absent: an identifier is
// a leaf naming whatever the consuming tor's environment binds it to
// (build flags, target lang, profile keys). Evaluation lives with the
// consumer, not in this parser.

/// One argument of a parametrized annotation call: a parsed Koru
/// expression, or the verbatim argument text when it is not one.
pub const CallArg = union(enum) {
    expr: *expression_parser.Expression,
    raw: []const u8,

    pub fn deinit(self: *CallArg, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .expr => |e| e.deinit(allocator),
            .raw => |r| allocator.free(r),
        }
    }
};

/// A parametrized annotation whose arguments have been expression-parsed.
/// Example: "build(!lean || !race)" ->
///   AnnotationCallExpr{ name = "build",
///     args = [ .expr = or(not(id "lean"), not(id "race")) ] }
/// Example: "retry(3)" -> args = [ .expr = literal number "3" ]
pub const AnnotationCallExpr = struct {
    name: []const u8,
    args: []CallArg,

    /// Free all memory associated with this annotation call
    pub fn deinit(self: *AnnotationCallExpr, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        for (self.args) |*arg| {
            arg.deinit(allocator);
        }
        allocator.free(self.args);
    }
};

/// Parse a single annotation string into an AnnotationCall
/// Returns null if the annotation is not a parametrized call (simple annotation)
/// Returns error if the annotation has invalid syntax
///
/// Examples:
///   parseCall("depends_on(\"a\", \"b\")") → AnnotationCall{ name="depends_on", args=["a", "b"] }
///   parseCall("pure") → null (simple annotation)
///   parseCall("timeout(30)") → AnnotationCall{ name="timeout", args=["30"] }
///   parseCall("invalid(") → error.InvalidSyntax
pub fn parseCall(allocator: std.mem.Allocator, annotation: []const u8) !?AnnotationCall {
    const shape = (try callShape(annotation)) orelse return null;
    const raw_args = try splitCallArgs(allocator, shape.args);
    defer allocator.free(raw_args);

    var args = try std.ArrayList([]const u8).initCapacity(allocator, raw_args.len);
    errdefer {
        for (args.items) |arg| allocator.free(arg);
        args.deinit(allocator);
    }
    for (raw_args) |raw| {
        try args.append(allocator, try parseArgumentValue(allocator, raw));
    }

    return AnnotationCall{
        .name = try allocator.dupe(u8, shape.name),
        .args = try args.toOwnedSlice(allocator),
    };
}

/// Parse a single annotation string into an AnnotationCallExpr: each call
/// argument judged by the language's own ExpressionParser - `.expr` when
/// the whole argument parses as one expression, `.raw` carrying the
/// verbatim text when it does not. Arguments are judged BEFORE
/// quote-stripping, so `"release"` is a string literal while `release` is
/// an identifier leaf - a distinction a post-strip parse would erase.
/// Returns null for a simple annotation, error.InvalidSyntax for a
/// malformed `name(...)` shape. Leaf resolution belongs to the consumer.
///
/// Examples:
///   parseCallExpr("build(!lean || !race)") -> name="build", 1 .expr arg
///   parseCallExpr("depends_on(\"compile\")") -> arg is .literal.string
///   parseCallExpr("pin(v1.2 | stable)") -> arg is .raw "v1.2 | stable"
///   parseCallExpr("pure") -> null (simple annotation)
pub fn parseCallExpr(allocator: std.mem.Allocator, annotation: []const u8) !?AnnotationCallExpr {
    const shape = (try callShape(annotation)) orelse return null;
    const raw_args = try splitCallArgs(allocator, shape.args);
    defer allocator.free(raw_args);

    var args = try std.ArrayList(CallArg).initCapacity(allocator, raw_args.len);
    errdefer {
        for (args.items) |*arg| arg.deinit(allocator);
        args.deinit(allocator);
    }
    for (raw_args) |raw| {
        var ep = expression_parser.ExpressionParser.init(allocator, raw);
        defer ep.deinit();
        if (ep.parseAll()) |expr| {
            try args.append(allocator, .{ .expr = expr });
        } else |_| {
            try args.append(allocator, .{ .raw = try allocator.dupe(u8, raw) });
        }
    }

    return AnnotationCallExpr{
        .name = try allocator.dupe(u8, shape.name),
        .args = try args.toOwnedSlice(allocator),
    };
}

/// The `name( ... )` surface of an annotation entry: the trimmed name and
/// the raw text between the outer parens. Returns null for a simple
/// annotation (no parens), error.InvalidSyntax for a malformed call.
const CallShape = struct { name: []const u8, args: []const u8 };

fn callShape(annotation: []const u8) !?CallShape {
    const trimmed = std.mem.trim(u8, annotation, " \t\r\n");
    if (trimmed.len == 0) return null;

    const open_paren_pos = std.mem.indexOf(u8, trimmed, "(") orelse {
        // No parenthesis → simple annotation
        return null;
    };

    const name = std.mem.trim(u8, trimmed[0..open_paren_pos], " \t");
    if (name.len == 0) return error.InvalidSyntax;
    if (trimmed[trimmed.len - 1] != ')') return error.InvalidSyntax;

    return CallShape{
        .name = name,
        .args = trimmed[open_paren_pos + 1 .. trimmed.len - 1],
    };
}

/// Split a call's argument list on top-level commas - the one place
/// argument-boundary knowledge lives, shared by parseCall and
/// parseCallExpr. Commas inside "..." strings (with \\ escapes) and
/// inside nested ()/[]/{} pairs stay within their argument, so
/// `f(a, b)` is ONE argument. Returns trimmed raw arg texts as slices
/// into `args_str` (quotes kept); the caller owns the outer slice.
/// Interior empty segments are kept verbatim, matching the pre-shared
/// parseCall behavior; a trailing comma contributes no empty tail.
fn splitCallArgs(allocator: std.mem.Allocator, args_str: []const u8) ![][]const u8 {
    var args = try std.ArrayList([]const u8).initCapacity(allocator, 4);
    errdefer args.deinit(allocator);

    const args_trimmed = std.mem.trim(u8, args_str, " \t");
    if (args_trimmed.len == 0) return args.toOwnedSlice(allocator);

    var i: usize = 0;
    var arg_start: usize = 0;
    var depth: usize = 0;
    var in_string: bool = false;
    var escape_next: bool = false;

    while (i < args_trimmed.len) : (i += 1) {
        const c = args_trimmed[i];

        if (escape_next) {
            escape_next = false;
            continue;
        }
        if (c == '\\') {
            escape_next = true;
            continue;
        }
        if (c == '"') {
            in_string = !in_string;
            continue;
        }
        if (!in_string) {
            switch (c) {
                '(', '[', '{' => depth += 1,
                ')', ']', '}' => {
                    if (depth > 0) depth -= 1;
                },
                ',' => {
                    if (depth == 0) {
                        try args.append(allocator, std.mem.trim(u8, args_trimmed[arg_start..i], " \t"));
                        arg_start = i + 1;
                    }
                },
                else => {},
            }
        }
    }

    // Handle last argument
    if (arg_start < args_trimmed.len) {
        try args.append(allocator, std.mem.trim(u8, args_trimmed[arg_start..], " \t"));
    }
    return args.toOwnedSlice(allocator);
}
/// Parse a single argument value, handling quoted strings and unquoted literals
/// Examples:
///   "\"hello\"" → "hello" (strip quotes, handle escapes)
///   "42" → "42" (keep as-is)
fn parseArgumentValue(allocator: std.mem.Allocator, arg_str: []const u8) ![]const u8 {
    const trimmed = std.mem.trim(u8, arg_str, " \t");

    // If it starts and ends with quotes, it's a string literal
    if (trimmed.len >= 2 and trimmed[0] == '"' and trimmed[trimmed.len - 1] == '"') {
        const inner = trimmed[1 .. trimmed.len - 1];
        // Handle escape sequences
        return try unescapeString(allocator, inner);
    }

    // Otherwise, keep as-is (number, identifier, etc.)
    return try allocator.dupe(u8, trimmed);
}

/// Unescape a string (handle \", \\, \n, etc.)
fn unescapeString(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, s.len);
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < s.len) : (i += 1) {
        if (s[i] == '\\' and i + 1 < s.len) {
            const next = s[i + 1];
            switch (next) {
                '"' => try result.append(allocator, '"'),
                '\\' => try result.append(allocator, '\\'),
                'n' => try result.append(allocator, '\n'),
                't' => try result.append(allocator, '\t'),
                'r' => try result.append(allocator, '\r'),
                else => {
                    // Unknown escape, keep both characters
                    try result.append(allocator, '\\');
                    try result.append(allocator, next);
                },
            }
            i += 1; // Skip the next character
        } else {
            try result.append(allocator, s[i]);
        }
    }

    return try result.toOwnedSlice(allocator);
}

/// Check if an annotation list contains a simple annotation
/// Example: hasSimple(annotations, "pure") checks for ~[pure]
pub fn hasSimple(annotations: []const []const u8, name: []const u8) bool {
    for (annotations) |ann| {
        if (std.mem.eql(u8, ann, name)) return true;
    }
    return false;
}

/// Check if an annotation list contains an annotation part in a compound annotation
/// Compound annotations use | as separator: comptime|transform, comptime|norun
/// Example: hasPart(annotations, "transform") returns true for [comptime|transform]
/// Example: hasPart(annotations, "comptime") returns true for both [comptime] and [comptime|transform]
pub fn hasPart(annotations: []const []const u8, part_name: []const u8) bool {
    for (annotations) |ann| {
        // Check if annotation matches exactly (simple case)
        if (std.mem.eql(u8, ann, part_name)) return true;

        // Check if annotation contains the part as a pipe-separated component
        var iter = std.mem.splitScalar(u8, ann, '|');
        while (iter.next()) |ann_part| {
            const trimmed = std.mem.trim(u8, ann_part, " \t");
            if (std.mem.eql(u8, trimmed, part_name)) return true;
        }
    }
    return false;
}

/// Check if an event has the [keyword] annotation
/// Events with [keyword] can be invoked without module qualification
pub fn isKeyword(annotations: []const []const u8) bool {
    return hasPart(annotations, "keyword");
}

/// Get a parametrized annotation call by name
/// Returns the parsed AnnotationCall if found, null otherwise
/// Example: getCall(annotations, "depends_on") → AnnotationCall with args
pub fn getCall(
    allocator: std.mem.Allocator,
    annotations: []const []const u8,
    name: []const u8,
) !?AnnotationCall {
    for (annotations) |ann| {
        // Try to parse as a call
        if (try parseCall(allocator, ann)) |call| {
            // Check if the name matches
            if (std.mem.eql(u8, call.name, name)) {
                return call;
            }
            // Name doesn't match, clean up and continue
            var mutable_call = call;
            mutable_call.deinit(allocator);
        }
    }
    return null;
}

/// Get a parametrized annotation call by name with expression-parsed args
/// Returns the parsed AnnotationCallExpr if found, null otherwise
/// Example: getCallExpr(annotations, "build") -> name + .expr/.raw args
pub fn getCallExpr(
    allocator: std.mem.Allocator,
    annotations: []const []const u8,
    name: []const u8,
) !?AnnotationCallExpr {
    for (annotations) |ann| {
        if (try parseCallExpr(allocator, ann)) |call| {
            if (std.mem.eql(u8, call.name, name)) {
                return call;
            }
            var mutable_call = call;
            mutable_call.deinit(allocator);
        }
    }
    return null;
}

// ============================================================================
// Dialect catalog - std/spec:spec kind-rows for annotation vocabularies
// ============================================================================
// A dialect is DATA: `kind:`-tagged rows on `std/spec:spec` sites,
// harvested from the program's own AST - the collapsed spec vocabulary's
// dialect content (one row vocabulary, per-kind judges; the row verbs
// dialect/entry/env/residue are kind: tags, not tor families). Rows keyed
// by dialect name MERGE; a contradictory binding on one key refuses with
// DialectContradiction, never silently picks a winner.
//
//   ~std/spec:spec { "kind": "dialect", "name": "build",
//                     "reads": ["build"] }
//   ~std/spec:spec { "kind": "entry", "dialect": "build", "name": "build",
//                     "args": "expr", "eval": "flags" }
//   ~std/spec:spec { "kind": "env",    "dialect": "build",
//                     "leaf": "flag" }
//   ~std/spec:spec { "kind": "residue", "dialect": "build",
//                     "unknown-entry": "keep", "raw-arg": "keep" }
//
// The judge (a consumer like build.kz's matchesFlags) loads the rows for
// its dialect name, claims the entries `reads` lists, judges args by the
// entry row's `args` mode and leaves by its `eval` env, and applies the
// residue rows to everything it cannot judge. Rows absent entirely mean
// the default dialect: `build` claimed, expr args, flags env, keep.

pub const ArgsMode = enum { expr, string_star, @"opaque" };
pub const ResidueMode = enum { keep, refuse };

pub const EntryPolicy = struct {
    args: ArgsMode = .expr,
    eval: []const u8 = "flags",
    residue: ResidueMode = .keep,
};

/// One dialect's harvested rows: the entries it claims, per-entry judging
/// policy, the leaf env table, and the residue contract. `env` rows are
/// harvested for judges that want leaf->source bindings; the flags judge
/// resolves through the Provider chain and ignores them.
pub const GrammarDialect = struct {
    name: []const u8 = "",
    reads: std.StringHashMap(void),
    entries: std.StringHashMap(EntryPolicy),
    env: std.StringHashMap([]const u8),
    residue_unknown: ResidueMode = .keep,
    residue_raw: ResidueMode = .keep,
    residue_unknown_seen: bool = false,
    residue_raw_seen: bool = false,
    declared: bool = false,

    pub fn claims(self: *const GrammarDialect, name: []const u8) bool {
        return self.reads.contains(name);
    }

    pub fn entryPolicy(self: *const GrammarDialect, name: []const u8) EntryPolicy {
        return self.entries.get(name) orelse .{};
    }

    pub fn deinit(self: *GrammarDialect, allocator: std.mem.Allocator) void {
        _ = allocator;
        self.reads.deinit();
        self.entries.deinit();
        self.env.deinit();
    }
};

/// The pre-catalog dialect: `build` claimed, default policies. Preserves
/// behavior for programs carrying no spec rows at all.
pub fn defaultDialect(allocator: std.mem.Allocator, name: []const u8) !GrammarDialect {
    var d = GrammarDialect{
        .name = try allocator.dupe(u8, name),
        .reads = std.StringHashMap(void).init(allocator),
        .entries = std.StringHashMap(EntryPolicy).init(allocator),
        .env = std.StringHashMap([]const u8).init(allocator),
    };
    try d.reads.put(try allocator.dupe(u8, name), {});
    return d;
}

fn specSiteSource(item: *const ast.Item) ?[]const u8 {
    const fl = switch (item.*) {
        .flow => |*f| f,
        else => return null,
    };
    const inv = fl.inv();
    const mq = inv.path.module_qualifier orelse return null;
    if (!std.mem.eql(u8, mq, "std.spec") and !std.mem.eql(u8, mq, "std/spec")) return null;
    if (inv.path.segments.len != 1 or !std.mem.eql(u8, inv.path.segments[0], "spec")) return null;
    for (inv.args) |arg| {
        if (std.mem.eql(u8, arg.name, "source")) return arg.value;
    }
    return null;
}

/// Harvest `std/spec:spec` rows for `dialect_name` from program items
/// (top-level flows and module_decl items - the spec.sites walk). Returns
/// null when no row declares the dialect: the caller falls back to
/// defaultDialect. A contradictory binding on one key is a loud
/// DialectContradiction.
pub fn loadDialect(
    allocator: std.mem.Allocator,
    items: []const ast.Item,
    dialect_name: []const u8,
) !?GrammarDialect {
    var d = GrammarDialect{
        .name = try allocator.dupe(u8, dialect_name),
        .reads = std.StringHashMap(void).init(allocator),
        .entries = std.StringHashMap(EntryPolicy).init(allocator),
        .env = std.StringHashMap([]const u8).init(allocator),
    };
    errdefer d.deinit(allocator);

    for (items) |*item| {
        switch (item.*) {
            .flow => try dialectRow(allocator, &d, specSiteSource(item), dialect_name),
            .module_decl => |*m| for (m.items) |*mi| {
                try dialectRow(allocator, &d, specSiteSource(mi), dialect_name);
            },
            else => {},
        }
    }

    if (!d.declared) {
        d.deinit(allocator);
        return null;
    }
    // A dialect that never spelled `reads` still claims its own name -
    // the pre-catalog behavior for entries named after the dialect.
    if (d.reads.count() == 0) {
        try d.reads.put(try allocator.dupe(u8, dialect_name), {});
    }
    return d;
}

/// Judge one parsed `std/spec:spec` source block against the dialect:
/// kind-tagged rows merge into their table, contradictions refuse.
fn dialectRow(
    allocator: std.mem.Allocator,
    d: *GrammarDialect,
    maybe_source: ?[]const u8,
    dialect_name: []const u8,
) !void {
    const src = maybe_source orelse return;
    const wrapped = try std.fmt.allocPrint(allocator, "{{{s}}}", .{src});
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, wrapped, .{}) catch return;
    defer parsed.deinit();
    if (parsed.value != .object) return;
    const obj = parsed.value.object;

    const kind_v = obj.get("kind") orelse return;
    const kind = switch (kind_v) { .string => |s| s, else => return };
    if (std.mem.eql(u8, kind, "dialect")) {
        const name = strOf(obj.get("name")) orelse return;
        if (!std.mem.eql(u8, name, dialect_name)) return;
        d.declared = true;
        if (obj.get("reads")) |reads_v| switch (reads_v) {
            .array => |arr| for (arr.items) |elem| {
                if (elem == .string) try d.reads.put(try allocator.dupe(u8, elem.string), {});
            },
            .string => |s| try d.reads.put(try allocator.dupe(u8, s), {}),
            else => {},
        };
    } else if (std.mem.eql(u8, kind, "entry")) {
        if (!isDialect(obj, dialect_name)) return;
        const entry_name = strOf(obj.get("name")) orelse return;
        var policy = EntryPolicy{};
        if (strOf(obj.get("args"))) |a| {
            if (std.mem.eql(u8, a, "expr")) policy.args = .expr;
            if (std.mem.eql(u8, a, "string*")) policy.args = .string_star;
            if (std.mem.eql(u8, a, "opaque")) policy.args = .@"opaque";
        }
        if (strOf(obj.get("eval"))) |e| policy.eval = try allocator.dupe(u8, e);
        if (strOf(obj.get("residue"))) |r| policy.residue = residueOf(r) orelse return error.DialectContradiction;
        if (d.entries.get(entry_name)) |old| {
            if (old.args != policy.args or
                !std.mem.eql(u8, old.eval, policy.eval) or
                old.residue != policy.residue) return error.DialectContradiction;
            return;
        }
        try d.entries.put(try allocator.dupe(u8, entry_name), policy);
    } else if (std.mem.eql(u8, kind, "env")) {
        if (!isDialect(obj, dialect_name)) return;
        var it = obj.iterator();
        while (it.next()) |e| {
            if (std.mem.eql(u8, e.key_ptr.*, "kind") or std.mem.eql(u8, e.key_ptr.*, "dialect")) continue;
            const val = switch (e.value_ptr.*) { .string => |s| s, else => continue };
            if (d.env.get(e.key_ptr.*)) |old| {
                if (!std.mem.eql(u8, old, val)) return error.DialectContradiction;
                continue;
            }
            try d.env.put(try allocator.dupe(u8, e.key_ptr.*), try allocator.dupe(u8, val));
        }
    } else if (std.mem.eql(u8, kind, "residue")) {
        if (!isDialect(obj, dialect_name)) return;
        if (strOf(obj.get("unknown-entry"))) |v| {
            const m = residueOf(v) orelse return error.DialectContradiction;
            if (d.residue_unknown_seen and d.residue_unknown != m) return error.DialectContradiction;
            d.residue_unknown = m;
            d.residue_unknown_seen = true;
        }
        if (strOf(obj.get("raw-arg"))) |v| {
            const m = residueOf(v) orelse return error.DialectContradiction;
            if (d.residue_raw_seen and d.residue_raw != m) return error.DialectContradiction;
            d.residue_raw = m;
            d.residue_raw_seen = true;
        }
    }
}

fn isDialect(obj: std.json.ObjectMap, dialect_name: []const u8) bool {
    const name = strOf(obj.get("dialect")) orelse return false;
    return std.mem.eql(u8, name, dialect_name);
}

fn strOf(v: ?std.json.Value) ?[]const u8 {
    const val = v orelse return null;
    return switch (val) { .string => |s| s, else => null };
}

fn residueOf(v: []const u8) ?ResidueMode {
    if (std.mem.eql(u8, v, "keep")) return .keep;
    if (std.mem.eql(u8, v, "refuse")) return .refuse;
    return null;
}

/// The flag list a scoped judge sees: every flag as passed, PLUS the bare
/// tail of each `scope=value` flag. Under scope `build`, `--build=prod`
/// contributes `prod`, so a bare atom in `build(prod)` judges exactly as
/// `flag(build) == "prod"` does in the gate vocabulary - and a `mode ==
/// "fast"` compound still sees the unscoped flags it names.
pub fn scopeFlags(
    allocator: std.mem.Allocator,
    flags: []const []const u8,
    scope: []const u8,
) ![]const []const u8 {
    var out = try std.ArrayList([]const u8).initCapacity(allocator, flags.len);
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, flags);
    for (flags) |f| {
        if (f.len > scope.len + 1 and f[scope.len] == '=' and std.mem.startsWith(u8, f, scope)) {
            try out.append(allocator, f[scope.len + 1 ..]);
        }
    }
    return out.toOwnedSlice(allocator);
}

// ============================================================================
// Block tokenizer — nesting- and string-aware entry delimiting
// ============================================================================
// An annotation block is a LIST OF ENTRIES: pipe-separated inline, bullet-
// separated vertical. The pipe is a list delimiter and semantically silent —
// it never delimits inside nested ()/[]/{} pairs or "..." strings, so entries
// like `custom(foo(bar: 1))`, `other[x, y]`, and `doc("a|b")` stay whole.
// These two functions are the ONLY place that knowledge lives; the parser and
// every downstream consumer delimit through them, never with indexOf/split.

/// Scan `text` for the `]` that CLOSES an annotation block whose opening `[`
/// has already been consumed — the first `]` at nesting depth 0. Nested
/// `[...]`/`(...)`/`{...}` pairs and `"..."` strings (with `\` escapes) are
/// skipped over. Returns null when the closer is not in `text` (the vertical
/// form, where the block closes on a later line).
pub fn findBlockClose(text: []const u8) ?usize {
    var depth: usize = 0;
    var in_string = false;
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        const c = text[i];
        if (in_string) {
            if (c == '\\') {
                i += 1;
                continue;
            }
            if (c == '"') in_string = false;
            continue;
        }
        switch (c) {
            '"' => in_string = true,
            '[', '(', '{' => depth += 1,
            ')', '}' => {
                if (depth > 0) depth -= 1;
            },
            ']' => {
                if (depth == 0) return i;
                depth -= 1;
            },
            else => {},
        }
    }
    return null;
}

/// Split annotation-block content (the text between the block's brackets)
/// into top-level entries: pipes at depth 0 delimit; pipes inside nested
/// pairs or strings belong to their entry. Entries are trimmed and empty
/// entries dropped. The returned entries are slices into `content` (no
/// copies); the caller owns (and frees) only the outer slice.
pub fn splitEntries(allocator: std.mem.Allocator, content: []const u8) ![][]const u8 {
    var entries = try std.ArrayList([]const u8).initCapacity(allocator, 4);
    errdefer entries.deinit(allocator);
    var depth: usize = 0;
    var in_string = false;
    var start: usize = 0;
    var i: usize = 0;
    while (i < content.len) : (i += 1) {
        const c = content[i];
        if (in_string) {
            if (c == '\\') {
                i += 1;
                continue;
            }
            if (c == '"') in_string = false;
            continue;
        }
        switch (c) {
            '"' => in_string = true,
            '[', '(', '{' => depth += 1,
            ']', ')', '}' => {
                if (depth > 0) depth -= 1;
            },
            '|' => {
                if (depth == 0) {
                    const entry = std.mem.trim(u8, content[start..i], " \t");
                    if (entry.len > 0) try entries.append(allocator, entry);
                    start = i + 1;
                }
            },
            else => {},
        }
    }
    const last = std.mem.trim(u8, content[start..], " \t");
    if (last.len > 0) try entries.append(allocator, last);
    return entries.toOwnedSlice(allocator);
}

/// Scan annotation-block content for a character that LOOKS like a separator but
/// is not one, and return its offset into `content`.
///
/// Annotations delimit on `|`. A `,` at depth 0 is therefore never a separator
/// and never part of a well-formed entry either — `~[default, depends_on(x)]`
/// parses as ONE entry spelled `"default, depends_on(x)"`, which matches no
/// annotation, so the block silently means nothing it appears to mean. That
/// exact shape shipped in `koru_std/build.kz` and dropped a real `depends_on`
/// dependency with no diagnostic; it is the reason this predicate exists.
///
/// Depth and strings are tracked with the same rules as `splitEntries`, because
/// the comma that IS legal must keep being legal: `depends_on(a, b)` is one
/// entry's argument list (depth 1) and `doc("a, b")` is inside a string. Only a
/// top-level comma is a mistake.
pub fn findInvalidSeparator(content: []const u8) ?usize {
    var depth: usize = 0;
    var in_string = false;
    var i: usize = 0;
    while (i < content.len) : (i += 1) {
        const c = content[i];
        if (in_string) {
            if (c == '\\') {
                i += 1;
                continue;
            }
            if (c == '"') in_string = false;
            continue;
        }
        switch (c) {
            '"' => in_string = true,
            '[', '(', '{' => depth += 1,
            ']', ')', '}' => {
                if (depth > 0) depth -= 1;
            },
            ',' => {
                if (depth == 0) return i;
            },
            else => {},
        }
    }
    return null;
}

/// Rewrite `content`'s top-level `,` separators as `|`, leaving every nested and
/// in-string comma untouched — the corrected spelling to show the author.
///
/// A diagnostic that echoes the broken text back teaches nothing; the whole
/// value of refusing this shape is handing over the form that works. Depth and
/// string rules are shared with `findInvalidSeparator` and `splitEntries`, so
/// the suggestion can never differ from what the parser would then accept.
/// A `, ` collapses to a single `|` rather than `| ` so the result matches the
/// canonical spelling used everywhere in the tree (`~[comptime|transform]`).
/// Caller owns the returned buffer.
pub fn suggestPipeSeparators(allocator: std.mem.Allocator, content: []const u8) ![]u8 {
    var out = try std.ArrayList(u8).initCapacity(allocator, content.len);
    errdefer out.deinit(allocator);

    var depth: usize = 0;
    var in_string = false;
    var i: usize = 0;
    while (i < content.len) : (i += 1) {
        const c = content[i];
        if (in_string) {
            try out.append(allocator, c);
            if (c == '\\' and i + 1 < content.len) {
                i += 1;
                try out.append(allocator, content[i]);
                continue;
            }
            if (c == '"') in_string = false;
            continue;
        }
        switch (c) {
            '"' => {
                in_string = true;
                try out.append(allocator, c);
            },
            '[', '(', '{' => {
                depth += 1;
                try out.append(allocator, c);
            },
            ']', ')', '}' => {
                if (depth > 0) depth -= 1;
                try out.append(allocator, c);
            },
            ',' => {
                if (depth == 0) {
                    try out.append(allocator, '|');
                    // Swallow the run of spaces/tabs that followed the comma so
                    // `a, b` becomes `a|b` and not `a| b`.
                    while (i + 1 < content.len and (content[i + 1] == ' ' or content[i + 1] == '\t')) i += 1;
                } else {
                    try out.append(allocator, c);
                }
            },
            else => try out.append(allocator, c),
        }
    }
    return out.toOwnedSlice(allocator);
}

// ============================================================================
// Tests
// ============================================================================

test "findBlockClose - flat block" {
    try std.testing.expectEqual(@as(?usize, 4), findBlockClose("pure]event x"));
}

test "findBlockClose - skips nested pairs" {
    // custom(foo[1])]rest → the closer is after the balanced nesting
    const text = "custom(foo[1])]rest";
    try std.testing.expectEqual(@as(?usize, 14), findBlockClose(text));
}

test "findBlockClose - skips strings with escapes and brackets" {
    const text = "doc(\"a ] b \\\" ]\")]x";
    try std.testing.expectEqual(@as(?usize, 17), findBlockClose(text));
}

test "findBlockClose - vertical form returns null" {
    try std.testing.expectEqual(@as(?usize, null), findBlockClose(""));
    try std.testing.expectEqual(@as(?usize, null), findBlockClose("- comptime"));
    try std.testing.expectEqual(@as(?usize, null), findBlockClose("balanced [x] only"));
}

test "splitEntries - flat pipes with and without spaces" {
    const allocator = std.testing.allocator;
    const entries = try splitEntries(allocator, "comptime|transform | fuseable");
    defer allocator.free(entries);
    try std.testing.expectEqual(@as(usize, 3), entries.len);
    try std.testing.expectEqualStrings("comptime", entries[0]);
    try std.testing.expectEqualStrings("transform", entries[1]);
    try std.testing.expectEqualStrings("fuseable", entries[2]);
}

test "splitEntries - pipes inside nesting and strings stay put" {
    const allocator = std.testing.allocator;
    const entries = try splitEntries(allocator, "custom(a|b) | other[x|y] | doc(\"p|q\")");
    defer allocator.free(entries);
    try std.testing.expectEqual(@as(usize, 3), entries.len);
    try std.testing.expectEqualStrings("custom(a|b)", entries[0]);
    try std.testing.expectEqualStrings("other[x|y]", entries[1]);
    try std.testing.expectEqualStrings("doc(\"p|q\")", entries[2]);
}

test "splitEntries - expression-shaped entries survive whole" {
    const allocator = std.testing.allocator;
    const entries = try splitEntries(allocator, "build == \"release\" | version >= 15");
    defer allocator.free(entries);
    try std.testing.expectEqual(@as(usize, 2), entries.len);
    try std.testing.expectEqualStrings("build == \"release\"", entries[0]);
    try std.testing.expectEqualStrings("version >= 15", entries[1]);
}

test "splitEntries - empty entries dropped" {
    const allocator = std.testing.allocator;
    const entries = try splitEntries(allocator, " | a || b | ");
    defer allocator.free(entries);
    try std.testing.expectEqual(@as(usize, 2), entries.len);
    try std.testing.expectEqualStrings("a", entries[0]);
    try std.testing.expectEqualStrings("b", entries[1]);
}

test "findInvalidSeparator - top-level comma is the real-world defect" {
    // The exact shape that shipped in koru_std/build.kz and silently dropped a
    // depends_on dependency.
    try std.testing.expectEqual(@as(?usize, 7), findInvalidSeparator("default, depends_on(compile_backend)"));
}

test "findInvalidSeparator - argument-list commas stay legal" {
    // depth 1: one entry's own argument list, which is correct syntax.
    try std.testing.expectEqual(@as(?usize, null), findInvalidSeparator("depends_on(a, b)"));
    try std.testing.expectEqual(@as(?usize, null), findInvalidSeparator("build(\"debug\", \"trace\")"));
    try std.testing.expectEqual(@as(?usize, null), findInvalidSeparator("other[x, y]"));
}

test "findInvalidSeparator - commas inside strings stay legal" {
    try std.testing.expectEqual(@as(?usize, null), findInvalidSeparator("doc(\"a, b\")"));
    try std.testing.expectEqual(@as(?usize, null), findInvalidSeparator("doc(\"esc \\\" , still inside\")"));
}

test "parseCallExpr - expression args parse against the language grammar" {
    const allocator = std.testing.allocator;
    var call = (try parseCallExpr(allocator, "build(!lean || !race)")).?;
    defer call.deinit(allocator);
    try std.testing.expectEqualStrings("build", call.name);
    try std.testing.expectEqual(@as(usize, 1), call.args.len);
    try std.testing.expect(call.args[0] == .expr);
    try std.testing.expect(call.args[0].expr.node == .binary);
    try std.testing.expectEqual(expression_parser.BinaryOperator.or_op, call.args[0].expr.node.binary.op);
}

test "parseCallExpr - quoted strings stay literals, bare words are leaves" {
    const allocator = std.testing.allocator;
    var call = (try parseCallExpr(allocator, "depends_on(\"compile\", test)")).?;
    defer call.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), call.args.len);
    // "compile" parses as a string literal; `test` parses as an identifier leaf.
    try std.testing.expect(call.args[0].expr.node == .literal);
    try std.testing.expect(call.args[0].expr.node.literal == .string);
    try std.testing.expect(call.args[1].expr.node == .identifier);
}

test "parseCallExpr - non-expression args ride as raw residue" {
    const allocator = std.testing.allocator;
    var call = (try parseCallExpr(allocator, "pin(v1.2 | stable)")).?;
    defer call.deinit(allocator);
    // "v1.2 | stable" is not an expression - the consumer keeps or refuses it.
    try std.testing.expect(call.args[0] == .raw);
    try std.testing.expectEqualStrings("v1.2 | stable", call.args[0].raw);
}

test "parseCallExpr - commas inside nested calls stay one argument" {
    const allocator = std.testing.allocator;
    var call = (try parseCallExpr(allocator, "expr(f(a, b), c)")).?;
    defer call.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), call.args.len);
    try std.testing.expect(call.args[0] == .expr);
    try std.testing.expect(call.args[1] == .expr);
}

test "getCallExpr - finds by name across simple annotations" {
    const allocator = std.testing.allocator;
    const anns = [_][]const u8{ "pure", "build(release)", "expr(a == b)" };
    var call = (try getCallExpr(allocator, &anns, "expr")).?;
    defer call.deinit(allocator);
    try std.testing.expectEqualStrings("expr", call.name);
    try std.testing.expect(call.args[0].expr.node.binary.op == .equal);
    try std.testing.expect((try getCallExpr(allocator, &anns, "nope")) == null);
}

test "parseCallExpr - simple annotation and malformed call keep old contract" {
    const allocator = std.testing.allocator;
    try std.testing.expect((try parseCallExpr(allocator, "pure")) == null);
    try std.testing.expectError(error.InvalidSyntax, parseCallExpr(allocator, "invalid("));
}

test "findInvalidSeparator - well-formed pipe blocks are clean" {
    try std.testing.expectEqual(@as(?usize, null), findInvalidSeparator("comptime|transform"));
    try std.testing.expectEqual(@as(?usize, null), findInvalidSeparator("default|depends_on(compile_backend)"));
}

test "findInvalidSeparator - a comma after a closed call is still top level" {
    // Regression guard on the depth bookkeeping: the `(` ... `)` must return to
    // depth 0 so the following comma is caught rather than swallowed.
    try std.testing.expectEqual(@as(?usize, 16), findInvalidSeparator("depends_on(a, b), default"));
}

test "suggestPipeSeparators - the real-world defect gets its fix spelled out" {
    const allocator = std.testing.allocator;
    const fixed = try suggestPipeSeparators(allocator, "default, depends_on(compile_backend)");
    defer allocator.free(fixed);
    try std.testing.expectEqualStrings("default|depends_on(compile_backend)", fixed);
}

test "suggestPipeSeparators - nested and quoted commas survive untouched" {
    const allocator = std.testing.allocator;
    const fixed = try suggestPipeSeparators(allocator, "build(\"a, b\"), other[x, y]");
    defer allocator.free(fixed);
    try std.testing.expectEqualStrings("build(\"a, b\")|other[x, y]", fixed);
}

test "suggestPipeSeparators - already-correct content round-trips" {
    const allocator = std.testing.allocator;
    const fixed = try suggestPipeSeparators(allocator, "comptime|transform");
    defer allocator.free(fixed);
    try std.testing.expectEqualStrings("comptime|transform", fixed);
}

test "suggestPipeSeparators - the suggestion is what splitEntries then accepts" {
    // The two functions must never disagree: whatever the hint tells the author
    // to write has to split into the entries they were trying to express.
    const allocator = std.testing.allocator;
    const fixed = try suggestPipeSeparators(allocator, "default, depends_on(a, b)");
    defer allocator.free(fixed);
    const entries = try splitEntries(allocator, fixed);
    defer allocator.free(entries);
    try std.testing.expectEqual(@as(usize, 2), entries.len);
    try std.testing.expectEqualStrings("default", entries[0]);
    try std.testing.expectEqualStrings("depends_on(a, b)", entries[1]);
    try std.testing.expectEqual(@as(?usize, null), findInvalidSeparator(fixed));
}

test "parseCall - simple annotation returns null" {
    const allocator = std.testing.allocator;
    const result = try parseCall(allocator, "pure");
    try std.testing.expect(result == null);
}

test "parseCall - empty args" {
    const allocator = std.testing.allocator;
    var result = (try parseCall(allocator, "timeout()")).?;
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("timeout", result.name);
    try std.testing.expectEqual(@as(usize, 0), result.args.len);
}

test "parseCall - single quoted arg" {
    const allocator = std.testing.allocator;
    var result = (try parseCall(allocator, "depends_on(\"compile\")")).?;
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("depends_on", result.name);
    try std.testing.expectEqual(@as(usize, 1), result.args.len);
    try std.testing.expectEqualStrings("compile", result.args[0]);
}

test "parseCall - multiple quoted args" {
    const allocator = std.testing.allocator;
    var result = (try parseCall(allocator, "depends_on(\"compile\", \"test\", \"lint\")")).?;
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("depends_on", result.name);
    try std.testing.expectEqual(@as(usize, 3), result.args.len);
    try std.testing.expectEqualStrings("compile", result.args[0]);
    try std.testing.expectEqualStrings("test", result.args[1]);
    try std.testing.expectEqualStrings("lint", result.args[2]);
}

test "parseCall - numeric arg" {
    const allocator = std.testing.allocator;
    var result = (try parseCall(allocator, "timeout(30)")).?;
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("timeout", result.name);
    try std.testing.expectEqual(@as(usize, 1), result.args.len);
    try std.testing.expectEqualStrings("30", result.args[0]);
}

test "parseCall - whitespace tolerance" {
    const allocator = std.testing.allocator;
    var result = (try parseCall(allocator, "  depends_on ( \"a\" , \"b\" )  ")).?;
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("depends_on", result.name);
    try std.testing.expectEqual(@as(usize, 2), result.args.len);
    try std.testing.expectEqualStrings("a", result.args[0]);
    try std.testing.expectEqualStrings("b", result.args[1]);
}

test "parseCall - escaped quotes" {
    const allocator = std.testing.allocator;
    var result = (try parseCall(allocator, "msg(\"Hello \\\"world\\\"\")")).?;
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("msg", result.name);
    try std.testing.expectEqual(@as(usize, 1), result.args.len);
    try std.testing.expectEqualStrings("Hello \"world\"", result.args[0]);
}

test "hasSimple - finds simple annotation" {
    const annotations = &[_][]const u8{ "pure", "comptime", "norun" };
    try std.testing.expect(hasSimple(annotations, "pure"));
    try std.testing.expect(hasSimple(annotations, "comptime"));
    try std.testing.expect(!hasSimple(annotations, "async"));
}

test "hasPart - finds parts in compound annotations" {
    const annotations = &[_][]const u8{ "comptime|transform", "runtime", "comptime|norun" };

    // Should find both parts of compound annotations
    try std.testing.expect(hasPart(annotations, "comptime"));
    try std.testing.expect(hasPart(annotations, "transform"));
    try std.testing.expect(hasPart(annotations, "norun"));

    // Should find simple annotations too
    try std.testing.expect(hasPart(annotations, "runtime"));

    // Should not find non-existent parts
    try std.testing.expect(!hasPart(annotations, "async"));
    try std.testing.expect(!hasPart(annotations, "pure"));
}

test "getCall - finds parametrized annotation" {
    const allocator = std.testing.allocator;
    const annotations = &[_][]const u8{ "pure", "depends_on(\"a\", \"b\")", "comptime" };

    var result = (try getCall(allocator, annotations, "depends_on")).?;
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("depends_on", result.name);
    try std.testing.expectEqual(@as(usize, 2), result.args.len);
    try std.testing.expectEqualStrings("a", result.args[0]);
    try std.testing.expectEqualStrings("b", result.args[1]);
}

test "getCall - returns null when not found" {
    const allocator = std.testing.allocator;
    const annotations = &[_][]const u8{ "pure", "comptime" };

    const result = try getCall(allocator, annotations, "depends_on");
    try std.testing.expect(result == null);
}

test "dialectRow - kind-rows merge into one dialect table" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var d = GrammarDialect{
        .name = "build",
        .reads = std.StringHashMap(void).init(allocator),
        .entries = std.StringHashMap(EntryPolicy).init(allocator),
        .env = std.StringHashMap([]const u8).init(allocator),
    };

    try dialectRow(allocator, &d, ROW_DIALECT, "build");
    try dialectRow(allocator, &d, ROW_ENTRY, "build");
    try dialectRow(allocator, &d, ROW_RESIDUE_REFUSE_UNKNOWN, "build");

    try std.testing.expect(d.declared);
    try std.testing.expect(d.claims("build"));
    try std.testing.expect(d.claims("profile"));
    try std.testing.expect(!d.claims("other"));
    const pol = d.entryPolicy("build");
    try std.testing.expect(pol.args == .expr);
    try std.testing.expectEqualStrings("flags", pol.eval);
    try std.testing.expect(d.residue_unknown == .refuse);
    try std.testing.expect(d.residue_raw == .keep);
}

const ROW_DIALECT =
    \\ "kind": "dialect", "name": "build", "reads": ["build", "profile"]
    ;
const ROW_ENTRY =
    \\ "kind": "entry", "dialect": "build", "name": "build", "args": "expr", "eval": "flags"
    ;
const ROW_RESIDUE_REFUSE_UNKNOWN =
    \\ "kind": "residue", "dialect": "build", "unknown-entry": "refuse"
    ;
const ROW_RESIDUE_KEEP_RAW =
    \\ "kind": "residue", "dialect": "build", "raw-arg": "keep"
    ;
const ROW_RESIDUE_REFUSE_RAW =
    \\ "kind": "residue", "dialect": "build", "raw-arg": "refuse"
    ;
const ROW_ENTRY_OPAQUE =
    \\ "kind": "entry", "dialect": "build", "name": "build", "args": "opaque"
    ;
const ROW_LANE_ENTRY_OPAQUE =
    \\ "kind": "entry", "dialect": "lane", "name": "build", "args": "opaque"
    ;
const ROW_LANE_RESIDUE_REFUSE_RAW =
    \\ "kind": "residue", "dialect": "lane", "raw-arg": "refuse"
    ;
const ROW_DIALECT_ONLY =
    \\ "kind": "dialect", "name": "build"
    ;

test "dialectRow - rows for other dialects do not merge" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var d = GrammarDialect{
        .name = "build",
        .reads = std.StringHashMap(void).init(allocator),
        .entries = std.StringHashMap(EntryPolicy).init(allocator),
        .env = std.StringHashMap([]const u8).init(allocator),
    };

    try dialectRow(allocator, &d, ROW_DIALECT_ONLY, "build");
    try dialectRow(allocator, &d, ROW_LANE_ENTRY_OPAQUE, "build");
    try dialectRow(allocator, &d, ROW_LANE_RESIDUE_REFUSE_RAW, "build");

    try std.testing.expect(d.entryPolicy("build").args == .expr);
    try std.testing.expect(d.residue_raw == .keep);
}

test "dialectRow - contradictory policy refuses loudly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var d = GrammarDialect{
        .name = "build",
        .reads = std.StringHashMap(void).init(allocator),
        .entries = std.StringHashMap(EntryPolicy).init(allocator),
        .env = std.StringHashMap([]const u8).init(allocator),
    };

    try dialectRow(allocator, &d, ROW_DIALECT_ONLY, "build");
    try dialectRow(allocator, &d, ROW_ENTRY, "build");
    try std.testing.expectError(error.DialectContradiction,
        dialectRow(allocator, &d, ROW_ENTRY_OPAQUE, "build"));

    // The seen-flag, not the value, makes a second binding a decision:
    // keep then refuse contradicts even though keep is the default.
    try dialectRow(allocator, &d, ROW_RESIDUE_KEEP_RAW, "build");
    try std.testing.expectError(error.DialectContradiction,
        dialectRow(allocator, &d, ROW_RESIDUE_REFUSE_RAW, "build"));
}

test "dialectRow - identical rows merge idempotently" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var d = GrammarDialect{
        .name = "build",
        .reads = std.StringHashMap(void).init(allocator),
        .entries = std.StringHashMap(EntryPolicy).init(allocator),
        .env = std.StringHashMap([]const u8).init(allocator),
    };

    try dialectRow(allocator, &d, ROW_ENTRY, "build");
    try dialectRow(allocator, &d, ROW_ENTRY, "build");
    try std.testing.expect(d.entries.count() == 1);
}

test "scopeFlags - scope tails join the flag set" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const flags = &[_][]const u8{ "build=prod", "lean", "target=c" };
    const scoped = try scopeFlags(allocator, flags, "build");

    var saw_prod = false;
    var saw_lean = false;
    var saw_target_tail = false;
    for (scoped) |f| {
        if (std.mem.eql(u8, f, "prod")) saw_prod = true;
        if (std.mem.eql(u8, f, "lean")) saw_lean = true;
        if (std.mem.eql(u8, f, "c")) saw_target_tail = true;
    }
    try std.testing.expect(saw_prod);
    try std.testing.expect(saw_lean);
    try std.testing.expect(!saw_target_tail);
    try std.testing.expect(scoped.len == 4);
}
