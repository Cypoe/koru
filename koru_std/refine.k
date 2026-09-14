// Koru Standard Library: Refine — value-level constraints on declared fields
// ===========================================================================
//
// `std/refine(Name) { name: type & constraint… }` — a definition surface for
// constraints on ABSTRACTS: it never touches a value, only meets bounds onto
// a declaration another module made. The `&`-atoms meet per field name,
// order-independently; a meet that lands empty is a loud KORU205 refusal,
// never a last-wins override.
//
// SURFACE:
//   std/refine(Server) {
//     port: int & >1024 & <=65535
//   }
//   meets the `std/proto(Server)` declaration — every refined field must
//   exist there and the base type must agree. The meet is name-keyed,
//   total, and confluent: several `std/refine` blocks (in any module, in
//   any order) fold onto the same facet, and the canonical meet lands in
//   the program tree as a typed `Item.facet_decl` node — consumers match
//   the node, never comment text.
//
// LAYERING — the point of a separate module: a bound can arrive apart from
//   the declaration. A library declares `std/proto(Server)` plainly; a
//   downstream module imports it and writes
//     std/refine(lib/home:Server) { port: int & >1024 }
//   — the `home:Name` spelling rides the named-arg channel (proto's own
//   `app/alpha:Health` convention), no strings needed.
//   — the qualified name addresses the type by home, the facet meets the
//   library's declaration program-wide. Definition is import-scoped (the
//   block resolves only where `std/refine` is imported); the constraint
//   rides the type, so enforcement is type-global.
//
// ENFORCEMENT IS THE CONSUMER'S: refine emits data, never a check.
//   `std/store` insert, `std/json` decode, `std/list:push` — each reads the
//   facet at its own boundary and decides. An unconsumed facet is
//   enumerable documentation, not a hole.
//
// v0 ATOMS: `>N` `>=N` `<N` `<=N` `==N` over integer literals, on an `int`
// base only. Disjunction-with-default (`*a | b`) is the designed next rung.
//
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
    program: *const std/compiler:Program,
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

    // One flat container: a struct inside a proc body is a container, and
    // container members cannot see proc-level consts — every shared type and
    // helper lives inside `R`, members naming siblings bare (proto.kz's
    // `TerminalRef` precedent).
    const R = struct {
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
        const ProtoField = struct { name: []const u8, base: []const u8 };
        const Op = enum { gt, ge, lt, le, eq };
        const Want = struct { home: []const u8, name: []const u8 };

        // The scope owning a declaration flow: the enclosing module's
        // logical name, or the entry module for top-level flows.
        fn scopeOfFlow(prog: *const ast.Program, target: *const ast.Flow) []const u8 {
            const Finder = struct {
                fn find(items: []const ast.Item, needle: *const ast.Flow, scope: []const u8) ?[]const u8 {
                    for (items) |*entry| {
                        switch (entry.*) {
                            .flow => |*f| {
                                if (f == needle) return scope;
                            },
                            .module_decl => |*m| {
                                if (find(m.items, needle, m.logical_name)) |s| return s;
                            },
                            else => {},
                        }
                    }
                    return null;
                }
            };
            return Finder.find(prog.items, target, prog.main_module_name) orelse prog.main_module_name;
        }

        fn bareName(value: []const u8) []const u8 {
            var text = std.mem.trim(u8, value, " \t");
            if (text.len >= 2 and text[0] == '"' and text[text.len - 1] == '"') {
                text = text[1 .. text.len - 1];
            }
            return std.mem.trim(u8, text, " \t");
        }

        fn isProtoDoor(inv: *const ast.Invocation) bool {
            if (inv.path.segments.len != 1) return false;
            const verb = inv.path.segments[0];
            const mq = inv.path.module_qualifier orelse return false;
            return (std.mem.eql(u8, verb, "default") and
                (std.mem.eql(u8, mq, "std.proto") or std.mem.eql(u8, mq, "std/proto"))) or
                (std.mem.eql(u8, verb, "proto") and
                (std.mem.eql(u8, mq, "std.types") or std.mem.eql(u8, mq, "std/types") or
                std.mem.eql(u8, mq, "std.proto") or std.mem.eql(u8, mq, "std/proto")));
        }

        fn isRefineDoor(inv: *const ast.Invocation) bool {
            if (inv.path.segments.len != 1) return false;
            const verb = inv.path.segments[0];
            const mq = inv.path.module_qualifier orelse return false;
            return (std.mem.eql(u8, verb, "default") or std.mem.eql(u8, verb, "refine")) and
                (std.mem.eql(u8, mq, "std.refine") or std.mem.eql(u8, mq, "std/refine"));
        }

        fn invName(inv: *const ast.Invocation) []const u8 {
            if (inv.args.len == 0) return "";
            return bareName(inv.args[0].value);
        }

        // The qualified entry name `home/path:Name` arrives through the
        // named-arg channel — the parser binds `name=home/path`,
        // `value=Name`, `had_explicit_label`. A bare `Name` (or an explicit
        // `expr: Name`) answers to the invocation's own home.
        fn invWant(alloc: std.mem.Allocator, inv: *const ast.Invocation, scope_home: []const u8) Want {
            var w = Want{ .home = scope_home, .name = invName(inv) };
            if (inv.args.len > 0) {
                const a = inv.args[0];
                if (a.had_explicit_label and a.name.len > 0 and
                    !std.mem.eql(u8, a.name, "expr"))
                {
                    const dotted = alloc.dupe(u8, a.name) catch unreachable;
                    for (dotted) |*c| {
                        if (c.* == '/') c.* = '.';
                    }
                    w.home = dotted;
                }
            }
            return w;
        }

        fn invSource(inv: *const ast.Invocation) []const u8 {
            for (inv.args) |a| {
                if (a.source_value) |sv| return sv.text;
            }
            return "";
        }

        // Parse `name: base & atom…` lines (or comma-joined marker text)
        // into a meet keyed by field name. `strict` refuses loudly on
        // malformed input (this block's own text); contributor text parses
        // leniently — a malformed sibling block is refused by its own
        // transform when it runs.
        fn parseInto(
            alloc: std.mem.Allocator,
            rep: *koru_std.koru_compiler.ErrorReporter,
            fl: *const ast.Flow,
            entry_name: []const u8,
            text: []const u8,
            fields: *std.ArrayList(Field),
            strict: bool,
        ) ?SiteResult {
            var lines = std.mem.tokenizeAny(u8, text, "\n,");
            while (lines.next()) |raw| {
                const line = std.mem.trim(u8, raw, " \t\r,");
                if (line.len == 0) continue;

                const colon = std.mem.indexOfScalar(u8, line, ':') orelse {
                    if (!strict) continue;
                    return .{ .replacement = ast.refusal(alloc, rep, .KORU205, fl.location, fl.module, "std/refine({s}): field line '{s}' has no ':' — each field must be `name: type [& constraint…]`", .{ entry_name, line }) };
                };
                const fname = std.mem.trim(u8, line[0..colon], " \t");
                const rest = line[colon + 1 ..];

                var segs = std.mem.splitScalar(u8, rest, '&');
                const base = std.mem.trim(u8, segs.next().?, " \t");
                if (fname.len == 0 or base.len == 0) {
                    if (!strict) continue;
                    return .{ .replacement = ast.refusal(alloc, rep, .KORU205, fl.location, fl.module, "std/refine({s}): field line '{s}' is missing a name or a type", .{ entry_name, line }) };
                }

                var idx_opt: ?usize = null;
                for (fields.items, 0..) |f, i| {
                    if (std.mem.eql(u8, f.name, fname)) {
                        idx_opt = i;
                        break;
                    }
                }
                const idx = idx_opt orelse blk: {
                    fields.append(alloc, .{ .name = fname, .base = base }) catch unreachable;
                    break :blk fields.items.len - 1;
                };
                const f = &fields.items[idx];
                if (!std.mem.eql(u8, f.base, base)) {
                    if (!strict) continue;
                    return .{ .replacement = ast.refusal(alloc, rep, .KORU205, fl.location, fl.module, "std/refine({s}): field '{s}' declared with base '{s}' but already met as '{s}' — a meet needs one base, not two", .{ entry_name, fname, base, f.base }) };
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
                        if (!strict) continue;
                        return .{ .replacement = ast.refusal(alloc, rep, .KORU205, fl.location, fl.module, "std/refine({s}): constraint atom '{s}' is not a bound — refine understands >N >=N <N <=N ==N over integer literals", .{ entry_name, atom }) };
                    }

                    const int_scalars = [_][]const u8{ "i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64" };
                    var int_base = false;
                    for (int_scalars) |s| {
                        if (std.mem.eql(u8, f.base, s)) int_base = true;
                    }
                    if (!int_base) {
                        if (!strict) continue;
                        return .{ .replacement = ast.refusal(alloc, rep, .KORU205, fl.location, fl.module, "std/refine({s}): field '{s}' puts a bound on base '{s}' — bounds refine integer scalars only", .{ entry_name, fname, f.base }) };
                    }

                    const n = std.fmt.parseInt(i64, std.mem.trim(u8, digits, " \t"), 10) catch {
                        if (!strict) continue;
                        return .{ .replacement = ast.refusal(alloc, rep, .KORU205, fl.location, fl.module, "std/refine({s}): bound '{s}' needs an integer literal — '{s}' does not parse", .{ entry_name, atom, digits }) };
                    };
                    const canon = std.fmt.allocPrint(alloc, "{s}{d}", .{ op_str, n }) catch unreachable;

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
                                    if (!strict) continue;
                                    return .{ .replacement = ast.refusal(alloc, rep, .KORU205, fl.location, fl.module, "std/refine({s}): field '{s}' refines to nothing — '{s}' contradicts '{s}'", .{ entry_name, fname, canon, e.src }) };
                                }
                            } else {
                                f.eq = .{ .value = n, .exclusive = false, .src = canon };
                            }
                        },
                    }
                }
            }
            return null;
        }

        // Emptiness of one met interval — returns the two disagreeing
        // bound strings on conflict.
        fn emptyField(f: *const Field) ?[2][]const u8 {
            if (f.lo != null and f.hi != null) {
                const lo = f.lo.?;
                const hi = f.hi.?;
                if (lo.value > hi.value or
                    (lo.value == hi.value and (lo.exclusive or hi.exclusive)))
                {
                    return .{ lo.src, hi.src };
                }
            }
            if (f.eq) |e| {
                if (f.lo) |lo| {
                    if (e.value < lo.value or (e.value == lo.value and lo.exclusive)) {
                        return .{ e.src, lo.src };
                    }
                }
                if (f.hi) |hi| {
                    if (e.value > hi.value or (e.value == hi.value and hi.exclusive)) {
                        return .{ e.src, hi.src };
                    }
                }
            }
            return null;
        }

        fn protoFieldsInto(alloc: std.mem.Allocator, text: []const u8, out: *std.ArrayList(ProtoField)) void {
            var toks = std.mem.tokenizeAny(u8, text, "\n,");
            while (toks.next()) |raw| {
                const line = std.mem.trim(u8, raw, " \t\r,");
                if (line.len == 0) continue;
                const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
                const nm = std.mem.trim(u8, line[0..colon], " \t");
                const base = std.mem.trim(u8, line[colon + 1 ..], " \t,");
                if (nm.len == 0 or base.len == 0) continue;
                out.append(alloc, .{ .name = nm, .base = base }) catch unreachable;
            }
        }

        // The proto anchor: a live `std/proto` invocation or an erased
        // `// proto Name: …` marker in the addressed home — either order of
        // dissolution resolves.
        fn walkProto(alloc: std.mem.Allocator, items: []const ast.Item, scope_home: []const u8, w: Want, out: *std.ArrayList(ProtoField), found: *bool) void {
            for (items) |entry| {
                switch (entry) {
                    .flow => |candidate| {
                        if (candidate.body.node) |*node| {
                            if (node.* == .invocation and isProtoDoor(&node.invocation) and
                                std.mem.eql(u8, scope_home, w.home) and
                                std.mem.eql(u8, invName(&node.invocation), w.name))
                            {
                                found.* = true;
                                protoFieldsInto(alloc, invSource(&node.invocation), out);
                            }
                        }
                    },
                    .inline_code => |ic| {
                        if (!std.mem.eql(u8, scope_home, w.home)) continue;
                        var lines = std.mem.splitScalar(u8, ic.code, '\n');
                        while (lines.next()) |raw| {
                            const line = std.mem.trimLeft(u8, raw, " \t");
                            const prefix = "// proto ";
                            if (!std.mem.startsWith(u8, line, prefix)) continue;
                            const colon = std.mem.indexOfScalar(u8, line[prefix.len..], ':') orelse continue;
                            const nm = std.mem.trim(u8, line[prefix.len .. prefix.len + colon], " \t");
                            if (!std.mem.eql(u8, nm, w.name)) continue;
                            found.* = true;
                            protoFieldsInto(alloc, line[prefix.len + colon + 1 ..], out);
                        }
                    },
                    .module_decl => |module| {
                        walkProto(alloc, module.items, module.logical_name, w, out, found);
                    },
                    else => {},
                }
            }
        }

        // Live `std/refine` invocations and `facet_decl` nodes targeting
        // the same (home, name) — all contributors fold onto one meet, so
        // the facet is visitation-order-independent.
        fn walkRefine(alloc: std.mem.Allocator, rep: *koru_std.koru_compiler.ErrorReporter, fl: *const ast.Flow, items: []const ast.Item, scope_home: []const u8, w: Want, fields: *std.ArrayList(Field), skip: *const ast.Invocation) void {
            for (items) |entry| {
                switch (entry) {
                    .flow => |candidate| {
                        if (candidate.body.node) |*node| {
                            if (node.* == .invocation and isRefineDoor(&node.invocation) and
                                &node.invocation != skip)
                            {
                                const cw = invWant(alloc, &node.invocation, scope_home);
                                if (std.mem.eql(u8, cw.home, w.home) and std.mem.eql(u8, cw.name, w.name)) {
                                    _ = parseInto(alloc, rep, fl, w.name, invSource(&node.invocation), fields, false);
                                }
                            }
                        }
                    },
                    .facet_decl => |*fd| {
                        // A canonical facet left by an earlier std/refine
                        // transform — typed fields, folded straight onto the
                        // meet. No text is parsed.
                        if (!std.mem.eql(u8, fd.module, w.home) or !std.mem.eql(u8, fd.name, w.name)) continue;
                        for (fd.fields) |ff| {
                            var idx_opt: ?usize = null;
                            for (fields.items, 0..) |f, i| {
                                if (std.mem.eql(u8, f.name, ff.name)) {
                                    idx_opt = i;
                                    break;
                                }
                            }
                            const idx = idx_opt orelse blk: {
                                fields.append(alloc, .{ .name = ff.name, .base = ff.type }) catch unreachable;
                                break :blk fields.items.len - 1;
                            };
                            const f = &fields.items[idx];
                            if (!std.mem.eql(u8, f.base, ff.type)) continue;
                            if (ff.eq) |b| {
                                if (f.eq == null) {
                                    f.eq = .{ .value = b.value, .exclusive = false, .src = std.fmt.allocPrint(alloc, "=={d}", .{b.value}) catch unreachable };
                                }
                            } else {
                                if (ff.lo) |b| {
                                    if (f.lo == null or b.value > f.lo.?.value or
                                        (b.value == f.lo.?.value and b.exclusive and !f.lo.?.exclusive))
                                    {
                                        f.lo = .{ .value = b.value, .exclusive = b.exclusive, .src = std.fmt.allocPrint(alloc, "{s}{d}", .{ if (b.exclusive) ">" else ">=", b.value }) catch unreachable };
                                    }
                                }
                                if (ff.hi) |b| {
                                    if (f.hi == null or b.value < f.hi.?.value or
                                        (b.value == f.hi.?.value and b.exclusive and !f.hi.?.exclusive))
                                    {
                                        f.hi = .{ .value = b.value, .exclusive = b.exclusive, .src = std.fmt.allocPrint(alloc, "{s}{d}", .{ if (b.exclusive) "<" else "<=", b.value }) catch unreachable };
                                    }
                                }
                            }
                        }
                    },
                    .module_decl => |module| {
                        walkRefine(alloc, rep, fl, module.items, module.logical_name, w, fields, skip);
                    },
                    else => {},
                }
            }
        }

        // One canonical facet per (home, name): true when a sibling block
        // already left its facet_decl in the tree.
        fn facetExists(items: []const ast.Item, home: []const u8, name: []const u8) bool {
            for (items) |entry| {
                switch (entry) {
                    .facet_decl => |*fd| {
                        if (std.mem.eql(u8, fd.module, home) and std.mem.eql(u8, fd.name, name)) return true;
                    },
                    .module_decl => |module| {
                        if (facetExists(module.items, home, name)) return true;
                    },
                    else => {},
                }
            }
            return false;
        }
    };

    // -- the entry name ---------------------------------------------------

    const type_name = R.bareName(expr);
    if (type_name.len == 0) {
        return .{ .replacement = ast.refusal(allocator, reporter, .KORU205, flow.location, flow.module, "std/refine: the entry name '{s}' is not usable — a refine name must be a non-empty identifier or a qualified `home:Name`", .{type_name}) };
    }
    const want = blk: {
        if (flow.body.node) |*node| {
            if (node.* == .invocation) {
                break :blk R.invWant(allocator, &node.invocation, R.scopeOfFlow(program, flow));
            }
        }
        break :blk R.Want{ .home = R.scopeOfFlow(program, flow), .name = type_name };
    };

    // -- pass 1: strict-parse this block ----------------------------------

    var meet = std.ArrayList(R.Field).initCapacity(allocator, 8) catch unreachable;
    if (R.parseInto(allocator, reporter, flow, type_name, source.text, &meet, true)) |r| return r;
    if (meet.items.len == 0) {
        return .{ .replacement = ast.refusal(allocator, reporter, .KORU205, flow.location, flow.module, "std/refine({s}): an entry with no fields refines nothing — declare at least one `name: type` field", .{type_name}) };
    }

    // -- pass 2: find the proto anchor ------------------------------------

    var pfields = std.ArrayList(R.ProtoField).initCapacity(allocator, 8) catch unreachable;
    var anchor_found = false;
    R.walkProto(allocator, program.items, program.main_module_name, want, &pfields, &anchor_found);
    if (!anchor_found) {
        return .{ .replacement = ast.refusal(allocator, reporter, .KORU205, flow.location, flow.module, "std/refine({s}): no declaration named '{s}' in home '{s}' to refine — refine meets a `std/proto` declaration", .{ type_name, want.name, want.home }) };
    }

    // -- pass 3: every refined field must exist on the anchor -------------

    for (meet.items) |f| {
        var pf: ?R.ProtoField = null;
        for (pfields.items) |p| {
            if (std.mem.eql(u8, p.name, f.name)) {
                pf = p;
                break;
            }
        }
        const p = pf orelse
            return .{ .replacement = ast.refusal(allocator, reporter, .KORU205, flow.location, flow.module, "std/refine({s}): names no field '{s}' — the declaration has none to refine", .{ type_name, f.name }) };
        if (!std.mem.eql(u8, p.base, f.base)) {
            return .{ .replacement = ast.refusal(allocator, reporter, .KORU205, flow.location, flow.module, "std/refine({s}): field '{s}' declares base '{s}' but the declaration says '{s}' — a meet needs one base, not two", .{ type_name, f.name, f.base, p.base }) };
        }
    }

    // -- pass 4: fold every sibling refine declaration onto the meet ------

    const my_inv = blk: {
        if (flow.body.node) |*node| {
            if (node.* == .invocation) break :blk &node.invocation;
        }
        break :blk undefined;
    };
    R.walkRefine(allocator, reporter, flow, program.items, program.main_module_name, want, &meet, my_inv);

    // -- pass 5: the total meet must be non-empty per field ----------------

    for (meet.items) |*f| {
        if (R.emptyField(f)) |pair| {
            return .{ .replacement = ast.refusal(allocator, reporter, .KORU205, flow.location, flow.module, "std/refine({s}): field '{s}' refines to nothing — '{s}' and '{s}' cannot both hold", .{ type_name, f.name, pair[0], pair[1] }) };
        }
    }

    // -- pass 6: canonical marker, dedup against an already-met facet -----

    var out = std.ArrayList(u8).initCapacity(allocator, source.text.len + 32) catch unreachable;
    out.appendSlice(allocator, "refine ") catch unreachable;
    out.appendSlice(allocator, want.home) catch unreachable;
    out.appendSlice(allocator, ":") catch unreachable;
    out.appendSlice(allocator, want.name) catch unreachable;
    out.appendSlice(allocator, ": ") catch unreachable;
    for (meet.items, 0..) |f, i| {
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

    // If a sibling block already left this facet in the tree, this site
    // dissolves to a tombstone comment — one canonical facet_decl per
    // (home, name). The comment is write-only debug text; nothing parses it.
    if (R.facetExists(program.items, want.home, want.name)) {
        return .{ .replacement = ast.Item{ .inline_code = ast.InlineCode{
            .code = std.fmt.allocPrint(allocator, "// refine {s}:{s}: met", .{ want.home, want.name }) catch unreachable,
            .location = flow.location,
            .module = flow.module,
        } } };
    }

    // The canonical facet goes into the program tree as a typed
    // FacetDecl — the declaration later transforms read.
    const ffields = allocator.alloc(ast.FacetField, meet.items.len) catch unreachable;
    for (meet.items, 0..) |f, i| {
        ffields[i] = .{
            .name = allocator.dupe(u8, f.name) catch unreachable,
            .type = allocator.dupe(u8, f.base) catch unreachable,
            .lo = if (f.lo) |b| .{ .value = b.value, .exclusive = b.exclusive } else null,
            .hi = if (f.hi) |b| .{ .value = b.value, .exclusive = b.exclusive } else null,
            .eq = if (f.eq) |b| .{ .value = b.value, .exclusive = b.exclusive } else null,
        };
    }
    return .{ .replacement = ast.Item{ .facet_decl = ast.FacetDecl{
        .name = allocator.dupe(u8, want.name) catch unreachable,
        .module = allocator.dupe(u8, want.home) catch unreachable,
        .fields = ffields,
        .location = flow.location,
    } } };
}
