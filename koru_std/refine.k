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
//     port: i64 & >1024 & <=65535
//   }
//   meets the `std/proto(Server)` declaration — refined fields must exist
//   there on one agreed base. The meet is name-keyed, total, confluent:
//   `std/refine` blocks in any module fold onto one facet that lands as a
//   typed `Item.facet_decl` — consumers match the node, never comment text.
//
// LAYERING — the point of a separate module: a bound can arrive apart
//   from the declaration. A library declares `std/proto(Server)` plainly;
//   a downstream module writes `std/refine(lib/home:Server) { port: i64 &
//   >1024 }` — `home:Name` rides the named-arg channel (proto's own
//   `app/alpha:Health` convention), addressing the type by home while the
//   facet meets the declaration program-wide. Definition is import-scoped;
//   the constraint rides the type, so enforcement is type-global.
//
// ENFORCEMENT IS THE CONSUMER'S: refine emits data, never a check.
//   `std/store` insert, `std/json` decode, `std/list:push` — each reads the
//   facet at its own boundary and decides. An unconsumed facet is
//   enumerable documentation, not a hole.
//
// v0 ATOMS: `>N` `>=N` `<N` `<=N` `==N` over integer literals, plus the
// `clamp(lo, hi)` normalizer — on integer scalar bases, raw (`i64`) or
// named through a terminal (`Port`). Disjunction (`*a | b`) is next.
//
// NOTE: `.k` files carry no host lines, so host types are spelled through
// `std/compiler:` aliases (Program, Item, Source, Allocator); the
// transform's own proc takes `std` inside its body and uses
// `koru_allocator()` — the canonical accessor emitted into every module
// (emitter_helpers.zig), riding the Debug leak counter.
// The explainer (`koruc <file> explain`) reports the met facet; the impl
// is refine.explain.kz. @retain: the generated gather invokes it.
[comptime|explainer]pub tor explain-refine {
    program: *const std/compiler:Program,
    allocator: std/compiler:Allocator
} -> ExplainReport
[comptime|transform|pre]pub tor default {
    expr: Expression,
    source: Source,
    item: *const std/compiler:Item,
    program: *const std/compiler:Program,
    reporter: *std/compiler:ErrorReporter
} -> SiteResult

proc default|zig {
    const allocator = koru_allocator();

    const flow = if (item.* == .flow)
        &item.flow
    else
        return .{};

    // -- the entry name ---------------------------------------------------

    const type_name = bareName(expr);
    if (type_name.len == 0) {
        return .{ .replacement = ast.refusal(allocator, reporter, .KORU205, flow.location, flow.module, "std/refine: the entry name '{s}' is not usable — a refine name must be a non-empty identifier or a qualified `home:Name`", .{type_name}) };
    }
    const want = blk: {
        if (flow.body.node) |*node| {
            if (node.* == .invocation) {
                break :blk invWant(allocator, &node.invocation, scopeOfFlow(program, flow));
            }
        }
        break :blk Want{ .home = scopeOfFlow(program, flow), .name = type_name };
    };

    // -- pass 1: strict-parse this block ----------------------------------

    var meet = std.ArrayList(Field).initCapacity(allocator, 8) catch unreachable;
    if (parseInto(allocator, reporter, flow, type_name, source.text, &meet, true)) |r| return r;
    if (meet.items.len == 0) {
        return .{ .replacement = ast.refusal(allocator, reporter, .KORU205, flow.location, flow.module, "std/refine({s}): an entry with no fields refines nothing — declare at least one `name: type` field", .{type_name}) };
    }

    // -- pass 2: find the proto anchor ------------------------------------

    var pfields = std.ArrayList(ProtoField).initCapacity(allocator, 8) catch unreachable;
    var anchor_found = false;
    walkProto(allocator, program.items, program.main_module_name, want, &pfields, &anchor_found);
    if (!anchor_found) {
        return .{ .replacement = ast.refusal(allocator, reporter, .KORU205, flow.location, flow.module, "std/refine({s}): no declaration named '{s}' in home '{s}' to refine — refine meets a `std/proto` declaration", .{ type_name, want.name, want.home }) };
    }

    // -- pass 3: every refined field must exist on the anchor -------------

    for (meet.items) |f| {
        var pf: ?ProtoField = null;
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
    walkRefine(allocator, reporter, flow, program.items, program.main_module_name, want, &meet, my_inv);

    // -- pass 5: the total meet must be legal and non-empty per field -----

    for (meet.items) |*f| {
        if (legalBase(allocator, reporter, flow, type_name, program, want.home, f)) |r| return r;
        if (emptyField(f)) |pair| {
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
        if (f.clamp) |c| {
            out.appendSlice(allocator, " & ") catch unreachable;
            out.appendSlice(allocator, c.src) catch unreachable;
        }
    }
    const body = out.toOwnedSlice(allocator) catch unreachable;
    std.debug.print("{s}\n", .{body});

    // If a sibling block already left this facet in the tree, this site
    // dissolves to a tombstone comment — one canonical facet_decl per
    // (home, name). The comment is write-only debug text; nothing parses it.
    if (facetExists(program.items, want.home, want.name)) {
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
            .clamp = if (f.clamp) |c| .{ .lo = c.lo, .hi = c.hi } else null,
        };
    }
    return .{ .replacement = ast.Item{ .facet_decl = ast.FacetDecl{
        .name = allocator.dupe(u8, want.name) catch unreachable,
        .module = allocator.dupe(u8, want.home) catch unreachable,
        .fields = ffields,
        .location = flow.location,
    } } };
}

