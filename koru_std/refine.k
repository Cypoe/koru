// Koru Standard Library: Refine — value-level constraints on declared fields
// ===========================================================================
//
// `std/refine(Name) { name: type & constraint… }` — a `name: type` field
// grammar plus a CONSTRAINT-SUFFIX position this module owns. `&`-atoms meet
// per field name, order-independently; a meet that lands empty is a loud
// KORU-layer refusal (KORU205), never a last-wins override. A field may be
// declared on several lines — `port: int & >1024` and `port: int & <=65535`
// meet to one interval — which is the lattice act CUE made famous, as a Koru
// facet: the concept, not the language. No external syntax, no general
// evaluator; the meet is name-keyed, total, and confluent.
//
// SURFACE:
//   std/refine(Server) {
//     port: int & >1024 & <=65535
//     host: string
//   }
//   declares a compile-time refinement entry. v0 validates the meet and
//   leaves a `// refine Name: …` marker carrying the canonical constraint
//   set; consumers (proto fields, stores, grids, manifests) read the facet
//   as the system grows. Importing IS the vocabulary — the block does not
//   resolve in a module that did not import std/refine, so the grammar is
//   spellable exactly where it was brought in.
//
// v0 ATOMS: `>N` `>=N` `<N` `<=N` `==N` over integer literals, on an `int`
// base only. Disjunction-with-default (`*a | b`) is the designed next rung;
// ambient handling of OTHER tors' Source blocks rides the import-activation
// mechanism pinned by 110_035 and wants an ownership contract first.

// NOTE on the signature: no `allocator` param. `.k` files carry no host
// lines, so `std.mem.Allocator` cannot be spelled here — the transform ABI
// binds params by name into the emitted Input struct, and host types are
// emitted verbatim. The proc takes `std` inside its body instead, and uses
// `koru_allocator()` — the canonical accessor emitted into every module
// (emitter_helpers.zig), which rides the Debug leak counter like all
// Koru-managed allocations.
[comptime|transform]pub tor default {
    expr: Expression,
    source: Source,
    item: *const std/compiler:Item,
    reporter: *std/compiler:ErrorReporter
} -> SiteResult

proc default|zig {
    const std = @import("std");
    const ast = @import("ast");
    const allocator = koru_allocator();

    const flow = if (item.* == .flow)
        &item.flow
    else
        return .{};

    var type_name = expr;
    if (type_name.len >= 2 and type_name[0] == '"' and type_name[type_name.len - 1] == '"') {
        type_name = type_name[1 .. type_name.len - 1];
    }
    const name = std.mem.trim(u8, type_name, " \t");
    if (name.len == 0) {
        return .{ .replacement = ast.refusal(allocator, reporter, .KORU205, flow.location, flow.module, "std/refine: the entry name '{s}' is not usable — a refine name must be a non-empty identifier", .{name}) };
    }

    const Bound = struct {
        value: i64,
        exclusive: bool,
        src: []const u8,
    };
    const Field = struct {
        name: []const u8,
        base: []const u8,
        lo: ?Bound = null,
        hi: ?Bound = null,
        eq: ?Bound = null,
    };
    const Op = enum { gt, ge, lt, le, eq };

    var fields = std.ArrayList(Field).initCapacity(allocator, 8) catch unreachable;

    var lines = std.mem.splitScalar(u8, source.text, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r,");
        if (line.len == 0) continue;

        const colon = std.mem.indexOfScalar(u8, line, ':') orelse
            return .{ .replacement = ast.refusal(allocator, reporter, .KORU205, flow.location, flow.module, "std/refine({s}): field line '{s}' has no ':' — each field must be `name: type [& constraint…]`", .{ name, line }) };
        const fname = std.mem.trim(u8, line[0..colon], " \t");
        const rest = line[colon + 1 ..];

        var segs = std.mem.splitScalar(u8, rest, '&');
        const base = std.mem.trim(u8, segs.next().?, " \t");
        if (fname.len == 0 or base.len == 0) {
            return .{ .replacement = ast.refusal(allocator, reporter, .KORU205, flow.location, flow.module, "std/refine({s}): field line '{s}' is missing a name or a type", .{ name, line }) };
        }

        // Find-or-insert by name — the meet is name-keyed, so a field may be
        // refined across several lines of the block.
        var idx_opt: ?usize = null;
        for (fields.items, 0..) |f, i| {
            if (std.mem.eql(u8, f.name, fname)) {
                idx_opt = i;
                break;
            }
        }
        const idx = idx_opt orelse blk: {
            fields.append(allocator, .{ .name = fname, .base = base }) catch unreachable;
            break :blk fields.items.len - 1;
        };
        const f = &fields.items[idx];
        if (!std.mem.eql(u8, f.base, base)) {
            return .{ .replacement = ast.refusal(allocator, reporter, .KORU205, flow.location, flow.module, "std/refine({s}): field '{s}' declared with base '{s}' but already met as '{s}' — a meet needs one base, not two", .{ name, fname, base, f.base }) };
        }

        while (segs.next()) |seg| {
            const atom = std.mem.trim(u8, seg, " \t");
            if (atom.len == 0) continue;

            var op: Op = undefined;
            var digits: []const u8 = undefined;
            var op_str: []const u8 = undefined;
            if (std.mem.startsWith(u8, atom, ">=")) {
                op = .ge; digits = atom[2..]; op_str = ">=";
            } else if (std.mem.startsWith(u8, atom, "<=")) {
                op = .le; digits = atom[2..]; op_str = "<=";
            } else if (std.mem.startsWith(u8, atom, "==")) {
                op = .eq; digits = atom[2..]; op_str = "==";
            } else if (std.mem.startsWith(u8, atom, ">")) {
                op = .gt; digits = atom[1..]; op_str = ">";
            } else if (std.mem.startsWith(u8, atom, "<")) {
                op = .lt; digits = atom[1..]; op_str = "<";
            } else {
                return .{ .replacement = ast.refusal(allocator, reporter, .KORU205, flow.location, flow.module, "std/refine({s}): constraint atom '{s}' is not a bound — refine understands >N >=N <N <=N ==N over integer literals", .{ name, atom }) };
            }

            if (!std.mem.eql(u8, f.base, "int")) {
                return .{ .replacement = ast.refusal(allocator, reporter, .KORU205, flow.location, flow.module, "std/refine({s}): field '{s}' puts a bound on base '{s}' — bounds refine `int` only", .{ name, fname, f.base }) };
            }

            const n = std.fmt.parseInt(i64, std.mem.trim(u8, digits, " \t"), 10) catch
                return .{ .replacement = ast.refusal(allocator, reporter, .KORU205, flow.location, flow.module, "std/refine({s}): bound '{s}' needs an integer literal — '{s}' does not parse", .{ name, atom, digits }) };
            const canon = std.fmt.allocPrint(allocator, "{s}{d}", .{ op_str, n }) catch unreachable;

            switch (op) {
                .gt, .ge => {
                    const excl = op == .gt;
                    if (f.lo == null or n > f.lo.?.value or
                        (n == f.lo.?.value and excl and !f.lo.?.exclusive))
                    {
                        f.lo = .{ .value = n, .exclusive = excl, .src = canon };
                    }
                },
                .lt, .le => {
                    const excl = op == .lt;
                    if (f.hi == null or n < f.hi.?.value or
                        (n == f.hi.?.value and excl and !f.hi.?.exclusive))
                    {
                        f.hi = .{ .value = n, .exclusive = excl, .src = canon };
                    }
                },
                .eq => {
                    if (f.eq) |e| {
                        if (e.value != n) {
                            return .{ .replacement = ast.refusal(allocator, reporter, .KORU205, flow.location, flow.module, "std/refine({s}): field '{s}' refines to nothing — '{s}' contradicts '{s}'", .{ name, fname, canon, e.src }) };
                        }
                    } else {
                        f.eq = .{ .value = n, .exclusive = false, .src = canon };
                    }
                },
            }

            // Emptiness of the met interval, checked after each atom so the
            // refusal names the two bounds that actually disagree.
            if (f.lo != null and f.hi != null) {
                const lo = f.lo.?;
                const hi = f.hi.?;
                if (lo.value > hi.value or
                    (lo.value == hi.value and (lo.exclusive or hi.exclusive)))
                {
                    return .{ .replacement = ast.refusal(allocator, reporter, .KORU205, flow.location, flow.module, "std/refine({s}): field '{s}' refines to nothing — '{s}' and '{s}' cannot both hold", .{ name, fname, lo.src, hi.src }) };
                }
            }
            if (f.eq) |e| {
                if (f.lo) |lo| {
                    if (e.value < lo.value or (e.value == lo.value and lo.exclusive)) {
                        return .{ .replacement = ast.refusal(allocator, reporter, .KORU205, flow.location, flow.module, "std/refine({s}): field '{s}' refines to nothing — '{s}' contradicts '{s}'", .{ name, fname, e.src, lo.src }) };
                    }
                }
                if (f.hi) |hi| {
                    if (e.value > hi.value or (e.value == hi.value and hi.exclusive)) {
                        return .{ .replacement = ast.refusal(allocator, reporter, .KORU205, flow.location, flow.module, "std/refine({s}): field '{s}' refines to nothing — '{s}' contradicts '{s}'", .{ name, fname, e.src, hi.src }) };
                    }
                }
            }
        }
    }

    if (fields.items.len == 0) {
        return .{ .replacement = ast.refusal(allocator, reporter, .KORU205, flow.location, flow.module, "std/refine({s}): an entry with no fields refines nothing — declare at least one `name: type` field", .{name}) };
    }

    // Canonical meet: the surviving atom set, lo before hi, eq alone.
    var out = std.ArrayList(u8).initCapacity(allocator, source.text.len + 32) catch unreachable;
    out.appendSlice(allocator, "refine ") catch unreachable;
    out.appendSlice(allocator, name) catch unreachable;
    out.appendSlice(allocator, ": ") catch unreachable;
    for (fields.items, 0..) |f, i| {
        if (i > 0) out.appendSlice(allocator, ", ") catch unreachable;
        out.appendSlice(allocator, f.name) catch unreachable;
        out.appendSlice(allocator, ": ") catch unreachable;
        out.appendSlice(allocator, f.base) catch unreachable;
        if (f.eq) |e| {
            out.appendSlice(allocator, " & ") catch unreachable;
            out.appendSlice(allocator, e.src) catch unreachable;
        } else {
            if (f.lo) |lo| {
                out.appendSlice(allocator, " & ") catch unreachable;
                out.appendSlice(allocator, lo.src) catch unreachable;
            }
            if (f.hi) |hi| {
                out.appendSlice(allocator, " & ") catch unreachable;
                out.appendSlice(allocator, hi.src) catch unreachable;
            }
        }
    }
    const body = out.toOwnedSlice(allocator) catch unreachable;
    std.debug.print("{s}\n", .{body});

    // Layout-silent self-erase: one comment line carries the canonical facet
    // for readers of the emitted module — proto's marker collapse is the
    // precedent, and the one-line rule is load-bearing there for the same
    // reason it is here.
    const code = std.fmt.allocPrint(allocator, "// {s}", .{body}) catch unreachable;
    return .{ .replacement = ast.Item{ .inline_code = ast.InlineCode{
        .code = code,
        .location = flow.location,
        .module = flow.module,
    } } };
}
