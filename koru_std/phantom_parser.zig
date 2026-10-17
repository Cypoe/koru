// Koru Phantom State Parser Library
// Interprets phantom strings according to Koru's state forwarding semantics

const std = @import("std");

/// Represents a parsed phantom state
pub const PhantomState = union(enum) {
    concrete: ConcreteState,
    variable: StateVariable,
    state_union: StateUnion,

    pub fn parse(allocator: std.mem.Allocator, phantom_str: []const u8) !PhantomState {
        // Check for state variable syntax (contains ' apostrophe)
        // Example: M'owned|borrowed, F'_
        if (std.mem.indexOf(u8, phantom_str, "'")) |apos_idx| {
            // This is a state variable!
            const var_name = phantom_str[0..apos_idx];
            const constraints = if (apos_idx + 1 < phantom_str.len)
                phantom_str[apos_idx + 1..]
            else
                null;

            return .{ .variable = .{
                .name = try allocator.dupe(u8, var_name),
                .constraints = if (constraints) |c|
                    try allocator.dupe(u8, c)
                else
                    null,
            }};
        }

        // Check for state union (contains |) BEFORE stripping !
        // Per-member ! is handled inside parseUnionMember - no union-level ! prefix.
        // [!opened|closing]  = discharge `opened`, just accept `closing` (no discharge)
        // [!opened|!closing] = discharge whichever state the resource is in
        if (std.mem.indexOf(u8, phantom_str, "|")) |_| {
            return parseUnion(allocator, phantom_str);
        }

        // Check for consumption marker (! prefix) - only for concrete states
        // Example: !opened, !fs:opened
        var remaining = phantom_str;
        const consumes_obligation = if (remaining.len > 0 and remaining[0] == '!') blk: {
            remaining = remaining[1..];  // Strip the !
            break :blk true;
        } else false;

        // Check for module-qualified state (uses : like events)
        // Example: mipmap:open, fs:closed, fs:opened!
        if (std.mem.indexOf(u8, remaining, ":")) |colon_idx| {
            // Has module qualifier
            const module_path = remaining[0..colon_idx];
            var state_name = remaining[colon_idx + 1..];

            // Consume marker may also sit AFTER the qualifier — the slash-canon
            // qualified spelling puts the module first (`std/list:!list`, ruled
            // 2026-07-02 as the obligation extension of the 2112 borrow canon).
            // Symmetric with the pre-qualifier form (`!fs:opened`).
            var consumes = consumes_obligation;
            if (state_name.len > 0 and state_name[0] == '!') {
                state_name = state_name[1..];
                consumes = true;
            }

            // Check for cleanup marker (! suffix). In an `@`-join the `!`
            // binds the name atom — splitNameClasses owns it there; bare
            // states keep the string-edge rule.
            var requires_cleanup = false;
            if (std.mem.indexOfScalar(u8, state_name, '@') == null) {
                if (state_name.len > 0 and state_name[state_name.len - 1] == '!') {
                    state_name = state_name[0..state_name.len - 1];  // Strip the !
                    requires_cleanup = true;
                }
            }

            const nc = try splitNameClasses(allocator, state_name);
            requires_cleanup = requires_cleanup or nc.requires_cleanup;

            // Both markers is invalid - consumption is for inputs, production is for outputs
            if (consumes and requires_cleanup) {
                return error.InvalidPhantomState;
            }

            // `<!*>` is refused: `!` is a settlement promise to a NAMED
            // contract — the discharger performs the minting module's
            // semantics, and `*` names nothing. The borrow wildcard is `<*>`.
            if (consumes and std.mem.eql(u8, nc.name, "*")) {
                return error.InvalidPhantomState;
            }
            return .{ .concrete = .{
                .module_path = try allocator.dupe(u8, module_path),
                .name = nc.name,
                .classes = nc.classes,
                .requires_cleanup = requires_cleanup,
                .consumes_obligation = consumes,
            }};
        }

        // Simple local state (no module qualifier)
        // Example: open, closed, opened!, !opened
        var state_name = remaining;

        // Check for cleanup marker (! suffix). In an `@`-join the `!`
        // binds the name atom — splitNameClasses owns it there; bare
        // states keep the string-edge rule.
        var requires_cleanup = false;
        if (std.mem.indexOfScalar(u8, state_name, '@') == null) {
            if (state_name.len > 0 and state_name[state_name.len - 1] == '!') {
                state_name = state_name[0..state_name.len - 1];  // Strip the !
                requires_cleanup = true;
            }
        }

        const nc = try splitNameClasses(allocator, state_name);
        requires_cleanup = requires_cleanup or nc.requires_cleanup;

        // Both markers is invalid - consumption is for inputs, production is for outputs
        if (consumes_obligation and requires_cleanup) {
            return error.InvalidPhantomState;
        }

        // `<!*>` refused — see the qualified branch above.
        if (consumes_obligation and std.mem.eql(u8, nc.name, "*")) {
            return error.InvalidPhantomState;
        }
        return .{ .concrete = .{
            .module_path = null,
            .name = nc.name,
            .classes = nc.classes,
            .requires_cleanup = requires_cleanup,
            .consumes_obligation = consumes_obligation,
        }};
    }

    pub fn deinit(self: *PhantomState, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .concrete => |*c| c.deinit(allocator),
            .variable => |*v| v.deinit(allocator),
            .state_union => |*u| u.deinit(allocator),
        }
    }
};

/// Class vocabulary for `<name@class>` — names are module-coined and open,
/// classes are an open tag set joined after the name position. The compiler
/// enforces the classes it knows; any other class rides along for modules
/// to honor — an imported module is a compiler plugin.
///   scoped — may not occupy output position: the debt dies with the
///            producing frame; reissue through `->`, a branch payload, or a
///            store column refuses. Settles only inside its own scope.
///   static — immortal lifetime; documents intent, carries no extra rule.
/// Split a bare state name on `@`: the FIRST part is the identity name, every
/// later part is a class. Positions are fixed — there is no classification
/// dictionary, so `a@b` is always "name `a`, class `b`".
///
/// The `!` binds the NAME atom, not the join: `alloc!@scoped` owes a debt and
/// is confined, `alloc@scoped!` refuses (`!` may not hang on a class), and a
/// `!` inside a part (`scr!atch`) refuses — markers live at atom edges.
///
/// Classes are OPEN vocabulary: the compiler enforces `scoped`; any other
/// class is carried, inert, for an imported module to honor — a module is a
/// compiler plugin. A typo'd class is carried the way a typo'd state name is:
/// it parses, fires nothing, and mismatches downstream like any other name.
const NameClasses = struct {
    name: []const u8,
    classes: [][]const u8,
    requires_cleanup: bool = false,
};

fn splitNameClasses(allocator: std.mem.Allocator, raw: []const u8) !NameClasses {
    if (std.mem.indexOfScalar(u8, raw, '@') == null) {
        return .{ .name = try allocator.dupe(u8, raw), .classes = &.{} };
    }
    var classes: std.ArrayListUnmanaged([]const u8) = .{};
    errdefer {
        for (classes.items) |c| allocator.free(c);
        classes.deinit(allocator);
    }
    var iter = std.mem.tokenizeScalar(u8, raw, '@');
    var name = iter.next() orelse return error.InvalidPhantomState;
    var requires_cleanup = false;
    if (name.len > 0 and name[name.len - 1] == '!') {
        name = name[0 .. name.len - 1];
        requires_cleanup = true;
    }
    if (name.len == 0 or std.mem.indexOfScalar(u8, name, '!') != null) {
        return error.InvalidPhantomState;
    }
    while (iter.next()) |part| {
        if (part.len == 0 or std.mem.indexOfScalar(u8, part, '!') != null) {
            return error.InvalidPhantomState;
        }
        // `*` is a marker — the wildcard name — not a class.
        if (std.mem.eql(u8, part, "*")) return error.InvalidPhantomState;
        try classes.append(allocator, try allocator.dupe(u8, part));
    }
    // A dangling `@` (`a@`, `@scoped`) is not a join — there is nothing
    // classed to confine.
    if (classes.items.len == 0) return error.InvalidPhantomState;
    // Canonical order: classes sort ascending so `@a@b` and `@b@a` are one set.
    std.mem.sort([]const u8, classes.items, {}, struct {
        fn lt(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.lt);
    return .{
        .name = try allocator.dupe(u8, name),
        .classes = try classes.toOwnedSlice(allocator),
        .requires_cleanup = requires_cleanup,
    };
}

/// Concrete phantom state (e.g., "open", "mipmap:open", "fs:closed", "opened!", "!opened")
pub const ConcreteState = struct {
    module_path: ?[]const u8,  // null for local, "mipmap" for module-qualified
    name: []const u8,           // identity part of "open", "scratch@scoped" -> "scratch"
    classes: [][]const u8 = &.{},  // `@`-joined classes, sorted; owned
    requires_cleanup: bool = false,  // true if state name ended with ! (e.g., "opened!")
    consumes_obligation: bool = false,  // true if state name starts with ! (e.g., "!opened")

    pub fn deinit(self: *ConcreteState, allocator: std.mem.Allocator) void {
        if (self.module_path) |path| allocator.free(path);
        allocator.free(self.name);
        for (self.classes) |c| allocator.free(c);
        if (self.classes.len > 0) allocator.free(self.classes);
    }

    pub fn hasClass(self: ConcreteState, class: []const u8) bool {
        for (self.classes) |c| {
            if (std.mem.eql(u8, c, class)) return true;
        }
        return false;
    }
};

/// State variable for forwarding (e.g., "M'owned|borrowed", "F'_")
pub const StateVariable = struct {
    name: []const u8,           // Variable name like "M", "F"
    constraints: ?[]const u8,   // "owned|borrowed|gc" or "_" for wildcard

    pub fn deinit(self: *StateVariable, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        if (self.constraints) |c| allocator.free(c);
    }

    /// Check if a concrete state satisfies this variable's constraints
    pub fn allows(self: StateVariable, state: []const u8) bool {
        const cons = self.constraints orelse return true; // No constraints = allow all

        // Wildcard constraint
        if (std.mem.eql(u8, cons, "_")) return true;

        // Check if state is in the constraint list
        var iter = std.mem.tokenizeScalar(u8, cons, '|');
        while (iter.next()) |allowed| {
            if (std.mem.eql(u8, allowed, state)) return true;
        }

        return false;
    }
};

/// State union for input flexibility (e.g., "open|closing", "fs:open|gzip:compressed")
/// Unions accept ANY of the listed states - used for flexible input handling
/// Unions CANNOT appear in output position (a resource is always in ONE known state)
/// To check if a union discharges an obligation, inspect each member.consumes_obligation.
pub const StateUnion = struct {
    members: []ConcreteState,       // Each member can have its own module_path

    pub fn deinit(self: *StateUnion, allocator: std.mem.Allocator) void {
        for (self.members) |*member| {
            member.deinit(allocator);
        }
        allocator.free(self.members);
    }

    /// Check if a concrete state matches any member of this union
    pub fn matches(self: StateUnion, state: ConcreteState) bool {
        for (self.members) |member| {
            // `*` — the catch-all member: matches every qualification.
            if (std.mem.eql(u8, member.name, "*")) return true;
            // Module paths must match
            const module_match = if (member.module_path) |mem_mod|
                if (state.module_path) |state_mod|
                    std.mem.eql(u8, mem_mod, state_mod)
                else
                    false
            else
                state.module_path == null;

            if (module_match and std.mem.eql(u8, member.name, state.name)) {
                return true;
            }
        }
        return false;
    }

    /// Whether the union contains a `*` catch-all member — accepts any
    /// qualification, including an unqualified value.
    pub fn acceptsAnything(self: StateUnion) bool {
        for (self.members) |member| {
            if (std.mem.eql(u8, member.name, "*")) return true;
        }
        return false;
    }
};

/// Parse a state union (e.g., "open|closing", "fs:open|gzip:compressed", "!opened|!closing")
/// The ! prefix is per-member only - handled inside parseUnionMember.
fn parseUnion(allocator: std.mem.Allocator, str: []const u8) !PhantomState {
    var members: std.ArrayListUnmanaged(ConcreteState) = .{};
    errdefer {
        for (members.items) |*m| m.deinit(allocator);
        members.deinit(allocator);
    }

    var iter = std.mem.tokenizeScalar(u8, str, '|');
    while (iter.next()) |member_str| {
        const member = try parseUnionMember(allocator, member_str);

        // Unions cannot have production markers (! suffix) - they can't be output
        if (member.requires_cleanup) {
            var m = member;
            m.deinit(allocator);
            return error.InvalidPhantomState;
        }

        try members.append(allocator, member);
    }

    // A union must have at least 2 members
    if (members.items.len < 2) {
        for (members.items) |*m| m.deinit(allocator);
        members.deinit(allocator);
        return error.InvalidPhantomState;
    }

    return .{ .state_union = .{
        .members = try members.toOwnedSlice(allocator),
    } };
}

/// Parse a single member of a state union.
/// Members may carry ! prefix (e.g. "!closing" in "opened|!closing") to indicate
/// per-member obligation consumption, or ! may be handled at the union level.
fn parseUnionMember(allocator: std.mem.Allocator, str: []const u8) !ConcreteState {
    var state_str = str;

    // Check for per-member consumption marker (! prefix)
    const consumes_obligation = if (state_str.len > 0 and state_str[0] == '!') blk: {
        state_str = state_str[1..];
        break :blk true;
    } else false;

    // Check for module qualifier
    if (std.mem.indexOf(u8, state_str, ":")) |colon_idx| {
        const module_path = state_str[0..colon_idx];
        var state_name = state_str[colon_idx + 1 ..];

        // Post-qualifier consume marker (`std/list:!list`) — see parse().
        var consumes = consumes_obligation;
        if (state_name.len > 0 and state_name[0] == '!') {
            state_name = state_name[1..];
            consumes = true;
        }

        // Check for ! suffix (will be rejected by caller, but we need to
        // detect it). In an `@`-join the `!` binds the name atom —
        // splitNameClasses owns it there; bare states keep the string-edge.
        var requires_cleanup = false;
        if (std.mem.indexOfScalar(u8, state_name, '@') == null) {
            if (state_name.len > 0 and state_name[state_name.len - 1] == '!') {
                state_name = state_name[0 .. state_name.len - 1];
                requires_cleanup = true;
            }
        }

        const nc = try splitNameClasses(allocator, state_name);
        requires_cleanup = requires_cleanup or nc.requires_cleanup;

        if (consumes and requires_cleanup) return error.InvalidPhantomState;
        if (consumes and std.mem.eql(u8, nc.name, "*")) return error.InvalidPhantomState;

        return .{
            .module_path = try allocator.dupe(u8, module_path),
            .name = nc.name,
            .classes = nc.classes,
            .requires_cleanup = requires_cleanup,
            .consumes_obligation = consumes,
        };
    }

    // Local state
    var state_name = state_str;
    var requires_cleanup = false;
    if (std.mem.indexOfScalar(u8, state_name, '@') == null) {
        if (state_name.len > 0 and state_name[state_name.len - 1] == '!') {
            state_name = state_name[0 .. state_name.len - 1];
            requires_cleanup = true;
        }
    }

    const nc = try splitNameClasses(allocator, state_name);
    requires_cleanup = requires_cleanup or nc.requires_cleanup;

    if (consumes_obligation and requires_cleanup) return error.InvalidPhantomState;
    if (consumes_obligation and std.mem.eql(u8, nc.name, "*")) return error.InvalidPhantomState;
    return .{
        .module_path = null,
        .name = nc.name,
        .classes = nc.classes,
        .requires_cleanup = requires_cleanup,
        .consumes_obligation = consumes_obligation,
    };
}

/// Check if two phantom states are compatible for shape checking
pub fn areCompatible(allocator: std.mem.Allocator, required_str: ?[]const u8, provided_str: ?[]const u8) !bool {
    // A qualifier is part of the type: unqualified `T` accepts only
    // unqualified `T` — `string` is not `string<state>`. Sites that accept
    // any qualification spell it explicitly with `<*>`.
    if (required_str == null) return provided_str == null;

    const req_str = required_str.?;

    // `<*>` — the any-qualification wildcard: marked or unmarked, all
    // accepted. Canonicalization keeps `*` bare (it has no home module);
    // `module:*` is matched too for callers that canonicalize anyway.
    // A `!` anywhere makes it a consume spelling — `!foo:*` is NOT a
    // borrow wildcard; it must reach the parser, which refuses it.
    if (std.mem.indexOfScalar(u8, req_str, '!') == null and
        (std.mem.eql(u8, req_str, "*") or std.mem.endsWith(u8, req_str, ":*"))) return true;

    // Parse the requirement — a union containing `*` (`<a|*>`) accepts any
    // qualification, including an unqualified value.
    const required = try PhantomState.parse(allocator, req_str);
    defer {
        var req_copy = required;
        req_copy.deinit(allocator);
    }
    switch (required) {
        .state_union => |u| if (u.acceptsAnything()) return true,
        else => {},
    }

    // State required but not provided = incompatible
    const prov_str = provided_str orelse return false;

    const provided = try PhantomState.parse(allocator, prov_str);
    defer {
        var prov_copy = provided;
        prov_copy.deinit(allocator);
    }
    
    // Check compatibility based on types
    switch (required) {
        .concrete => |req_concrete| {
            switch (provided) {
                .concrete => |prov_concrete| {
                    // Module paths must match
                    const module_match = if (req_concrete.module_path) |req_mod|
                        if (prov_concrete.module_path) |prov_mod|
                            std.mem.eql(u8, req_mod, prov_mod)
                        else
                            false
                    else
                        prov_concrete.module_path == null;

                    if (!module_match) return false;

                    // Names must match
                    return std.mem.eql(u8, req_concrete.name, prov_concrete.name);
                },
                .variable => return false, // Can't match concrete with variable
                .state_union => return false, // Can't provide union when concrete required
            }
        },
        .variable => |req_var| {
            switch (provided) {
                .concrete => |prov_concrete| {
                    // Check if concrete state satisfies variable constraints
                    const state_name = prov_concrete.name;
                    return req_var.allows(state_name);
                },
                .variable => |prov_var| {
                    // Variable names must match for forwarding
                    if (!std.mem.eql(u8, req_var.name, prov_var.name)) return false;

                    // Constraints must be compatible
                    // TODO: More sophisticated constraint checking
                    const req_cons = req_var.constraints orelse "_";
                    const prov_cons = prov_var.constraints orelse "_";
                    return std.mem.eql(u8, req_cons, prov_cons);
                },
                .state_union => return false, // Can't provide union when variable required
            }
        },
        .state_union => |req_union| {
            switch (provided) {
                .concrete => |prov_concrete| {
                    // Union accepts any matching member
                    return req_union.matches(prov_concrete);
                },
                .variable => return false, // Can't match union with variable
                .state_union => |prov_union| {
                    // Union-to-union: provided must be subset of required
                    // For now, require exact match (same members)
                    if (req_union.members.len != prov_union.members.len) return false;
                    for (prov_union.members) |prov_member| {
                        if (!req_union.matches(prov_member)) return false;
                    }
                    return true;
                },
            }
        },
    }
}

/// Check if a phantom string represents a state variable
pub fn isStateVariable(phantom_str: []const u8) bool {
    return std.mem.indexOf(u8, phantom_str, "'") != null;
}

/// Extract the variable name from a state variable phantom
pub fn getVariableName(phantom_str: []const u8) ?[]const u8 {
    if (std.mem.indexOf(u8, phantom_str, "'")) |apos_idx| {
        return phantom_str[0..apos_idx];
    }
    return null;
}

/// Check if two phantom strings represent the same forwarding variable
pub fn isSameVariable(phantom1: []const u8, phantom2: []const u8) bool {
    const var1 = getVariableName(phantom1);
    const var2 = getVariableName(phantom2);

    if (var1 == null or var2 == null) return false;
    return std.mem.eql(u8, var1.?, var2.?);
}

/// Check if a phantom string represents a state union
pub fn isStateUnion(phantom_str: []const u8) bool {
    // Union has | but no ' (apostrophe indicates state variable)
    return std.mem.indexOf(u8, phantom_str, "'") == null
        and std.mem.indexOf(u8, phantom_str, "|") != null;
}

// Tests
test "parse concrete state" {
    const allocator = std.testing.allocator;
    
    const state = try PhantomState.parse(allocator, "open");
    defer {
        var s = state;
        s.deinit(allocator);
    }
    
    try std.testing.expectEqual(@as(std.meta.Tag(PhantomState), .concrete), @as(std.meta.Tag(PhantomState), state));
    const concrete = state.concrete;
    try std.testing.expect(concrete.module_path == null);
    try std.testing.expectEqualStrings("open", concrete.name);
}

test "parse module-qualified state" {
    const allocator = std.testing.allocator;

    const state = try PhantomState.parse(allocator, "mipmap:open");
    defer {
        var s = state;
        s.deinit(allocator);
    }

    try std.testing.expectEqual(@as(std.meta.Tag(PhantomState), .concrete), @as(std.meta.Tag(PhantomState), state));
    const concrete = state.concrete;
    try std.testing.expectEqualStrings("mipmap", concrete.module_path.?);
    try std.testing.expectEqualStrings("open", concrete.name);
}

test "parse state variable with constraints" {
    const allocator = std.testing.allocator;

    const state = try PhantomState.parse(allocator, "M'owned|borrowed|gc");
    defer {
        var s = state;
        s.deinit(allocator);
    }

    try std.testing.expectEqual(@as(std.meta.Tag(PhantomState), .variable), @as(std.meta.Tag(PhantomState), state));
    const variable = state.variable;
    try std.testing.expectEqualStrings("M", variable.name);
    try std.testing.expectEqualStrings("owned|borrowed|gc", variable.constraints.?);
}

test "parse state variable with wildcard" {
    const allocator = std.testing.allocator;

    const state = try PhantomState.parse(allocator, "F'_");
    defer {
        var s = state;
        s.deinit(allocator);
    }

    try std.testing.expectEqual(@as(std.meta.Tag(PhantomState), .variable), @as(std.meta.Tag(PhantomState), state));
    const variable = state.variable;
    try std.testing.expectEqualStrings("F", variable.name);
    try std.testing.expectEqualStrings("_", variable.constraints.?);
}

test "state variable allows constraint" {
    const allocator = std.testing.allocator;

    const state = try PhantomState.parse(allocator, "M'owned|borrowed");
    defer {
        var s = state;
        s.deinit(allocator);
    }

    const variable = state.variable;
    try std.testing.expect(variable.allows("owned"));
    try std.testing.expect(variable.allows("borrowed"));
    try std.testing.expect(!variable.allows("gc"));
}

test "compatibility checking" {
    const allocator = std.testing.allocator;

    // Concrete states must match exactly
    try std.testing.expect(try areCompatible(allocator, "open", "open"));
    try std.testing.expect(!try areCompatible(allocator, "open", "closed"));

    // Module-qualified states must match
    try std.testing.expect(try areCompatible(allocator, "fs:open", "fs:open"));
    try std.testing.expect(!try areCompatible(allocator, "fs:open", "mipmap:open"));

    // Variables with same name are compatible
    try std.testing.expect(try areCompatible(allocator, "M'owned|borrowed", "M'owned|borrowed"));
    try std.testing.expect(!try areCompatible(allocator, "M'owned", "N'owned"));

    // Wildcard accepts any state
    try std.testing.expect(try areCompatible(allocator, "F'_", "F'_"));

    // An unqualified requirement accepts only unqualified values —
    // `string` is not `string<state>`
    try std.testing.expect(!try areCompatible(allocator, null, "open"));
    try std.testing.expect(try areCompatible(allocator, null, null));

    // `<*>` accepts any qualification — marked or unmarked
    try std.testing.expect(try areCompatible(allocator, "*", "open"));
    try std.testing.expect(try areCompatible(allocator, "*", null));
}

test "parse cleanup marker - local state" {
    const allocator = std.testing.allocator;

    const state = try PhantomState.parse(allocator, "opened!");
    defer {
        var s = state;
        s.deinit(allocator);
    }

    try std.testing.expectEqual(@as(std.meta.Tag(PhantomState), .concrete), @as(std.meta.Tag(PhantomState), state));
    const concrete = state.concrete;
    try std.testing.expect(concrete.module_path == null);
    try std.testing.expectEqualStrings("opened", concrete.name);  // ! stripped
    try std.testing.expect(concrete.requires_cleanup);  // Flag set
}

test "parse cleanup marker - module-qualified state" {
    const allocator = std.testing.allocator;

    const state = try PhantomState.parse(allocator, "fs:opened!");
    defer {
        var s = state;
        s.deinit(allocator);
    }

    try std.testing.expectEqual(@as(std.meta.Tag(PhantomState), .concrete), @as(std.meta.Tag(PhantomState), state));
    const concrete = state.concrete;
    try std.testing.expectEqualStrings("fs", concrete.module_path.?);
    try std.testing.expectEqualStrings("opened", concrete.name);  // ! stripped
    try std.testing.expect(concrete.requires_cleanup);  // Flag set
}

test "parse non-cleanup state" {
    const allocator = std.testing.allocator;

    const state = try PhantomState.parse(allocator, "closed");
    defer {
        var s = state;
        s.deinit(allocator);
    }

    try std.testing.expectEqual(@as(std.meta.Tag(PhantomState), .concrete), @as(std.meta.Tag(PhantomState), state));
    const concrete = state.concrete;
    try std.testing.expectEqualStrings("closed", concrete.name);
    try std.testing.expect(!concrete.requires_cleanup);  // No cleanup needed
    try std.testing.expect(!concrete.consumes_obligation);  // Doesn't consume
}

test "parse consumption marker - local state" {
    const allocator = std.testing.allocator;

    const state = try PhantomState.parse(allocator, "!opened");
    defer {
        var s = state;
        s.deinit(allocator);
    }

    try std.testing.expectEqual(@as(std.meta.Tag(PhantomState), .concrete), @as(std.meta.Tag(PhantomState), state));
    const concrete = state.concrete;
    try std.testing.expect(concrete.module_path == null);
    try std.testing.expectEqualStrings("opened", concrete.name);  // ! prefix stripped
    try std.testing.expect(!concrete.requires_cleanup);  // No ! suffix
    try std.testing.expect(concrete.consumes_obligation);  // ! prefix set
}

test "parse consumption marker - module-qualified state" {
    const allocator = std.testing.allocator;

    const state = try PhantomState.parse(allocator, "!fs:opened");
    defer {
        var s = state;
        s.deinit(allocator);
    }

    try std.testing.expectEqual(@as(std.meta.Tag(PhantomState), .concrete), @as(std.meta.Tag(PhantomState), state));
    const concrete = state.concrete;
    try std.testing.expectEqualStrings("fs", concrete.module_path.?);
    try std.testing.expectEqualStrings("opened", concrete.name);  // ! prefix stripped
    try std.testing.expect(!concrete.requires_cleanup);  // No ! suffix
    try std.testing.expect(concrete.consumes_obligation);  // ! prefix set
}

test "parse both markers - invalid" {
    const allocator = std.testing.allocator;

    // !opened! is invalid: consumption (!) is for inputs, production (!) is for outputs
    // Having both on the same annotation makes no sense positionally
    const result = PhantomState.parse(allocator, "!opened!");
    try std.testing.expectError(error.InvalidPhantomState, result);
}

test "parse both markers module-qualified - invalid" {
    const allocator = std.testing.allocator;

    // Same rule applies to module-qualified states
    const result = PhantomState.parse(allocator, "!fs:opened!");
    try std.testing.expectError(error.InvalidPhantomState, result);
}

// ============================================================================
// State Union Tests
// ============================================================================

test "parse simple union" {
    const allocator = std.testing.allocator;

    const state = try PhantomState.parse(allocator, "open|closing");
    defer {
        var s = state;
        s.deinit(allocator);
    }

    try std.testing.expectEqual(@as(std.meta.Tag(PhantomState), .state_union), @as(std.meta.Tag(PhantomState), state));
    const u = state.state_union;
    try std.testing.expectEqual(@as(usize, 2), u.members.len);

    // First member: open (no !)
    try std.testing.expect(u.members[0].module_path == null);
    try std.testing.expectEqualStrings("open", u.members[0].name);
    try std.testing.expect(!u.members[0].consumes_obligation);

    // Second member: closing (no !)
    try std.testing.expect(u.members[1].module_path == null);
    try std.testing.expectEqualStrings("closing", u.members[1].name);
    try std.testing.expect(!u.members[1].consumes_obligation);
}

test "parse union with consumption marker" {
    const allocator = std.testing.allocator;

    // !open|closing: only the first member carries !, second does not
    const state = try PhantomState.parse(allocator, "!open|closing");
    defer {
        var s = state;
        s.deinit(allocator);
    }

    try std.testing.expectEqual(@as(std.meta.Tag(PhantomState), .state_union), @as(std.meta.Tag(PhantomState), state));
    const u = state.state_union;
    try std.testing.expectEqual(@as(usize, 2), u.members.len);

    // First member "open" has per-member !
    try std.testing.expectEqualStrings("open", u.members[0].name);
    try std.testing.expect(u.members[0].consumes_obligation);

    // Second member "closing" has no !
    try std.testing.expectEqualStrings("closing", u.members[1].name);
    try std.testing.expect(!u.members[1].consumes_obligation);
}

test "parse union with per-member consumption markers" {
    const allocator = std.testing.allocator;

    // !opened|!closing - both members have explicit ! prefix, both discharge
    const state = try PhantomState.parse(allocator, "!opened|!closing");
    defer {
        var s = state;
        s.deinit(allocator);
    }

    try std.testing.expectEqual(@as(std.meta.Tag(PhantomState), .state_union), @as(std.meta.Tag(PhantomState), state));
    const u = state.state_union;
    try std.testing.expectEqual(@as(usize, 2), u.members.len);

    // Both members carry their own !
    try std.testing.expectEqualStrings("opened", u.members[0].name);
    try std.testing.expect(u.members[0].consumes_obligation);

    try std.testing.expectEqualStrings("closing", u.members[1].name);
    try std.testing.expect(u.members[1].consumes_obligation);
}

test "parse union with partial per-member consumption marker" {
    const allocator = std.testing.allocator;

    // opened|!closing - only second member has ! prefix, no outer !
    const state = try PhantomState.parse(allocator, "opened|!closing");
    defer {
        var s = state;
        s.deinit(allocator);
    }

    try std.testing.expectEqual(@as(std.meta.Tag(PhantomState), .state_union), @as(std.meta.Tag(PhantomState), state));
    const u = state.state_union;
    try std.testing.expectEqual(@as(usize, 2), u.members.len);

    try std.testing.expectEqualStrings("opened", u.members[0].name);
    try std.testing.expect(!u.members[0].consumes_obligation);

    try std.testing.expectEqualStrings("closing", u.members[1].name);
    try std.testing.expect(u.members[1].consumes_obligation);
}

test "parse three-member union" {
    const allocator = std.testing.allocator;

    const state = try PhantomState.parse(allocator, "open|closing|closed");
    defer {
        var s = state;
        s.deinit(allocator);
    }

    try std.testing.expectEqual(@as(std.meta.Tag(PhantomState), .state_union), @as(std.meta.Tag(PhantomState), state));
    const u = state.state_union;
    try std.testing.expectEqual(@as(usize, 3), u.members.len);
    try std.testing.expectEqualStrings("open", u.members[0].name);
    try std.testing.expectEqualStrings("closing", u.members[1].name);
    try std.testing.expectEqualStrings("closed", u.members[2].name);
}

test "parse module-qualified union - same module" {
    const allocator = std.testing.allocator;

    const state = try PhantomState.parse(allocator, "fs:open|fs:closing");
    defer {
        var s = state;
        s.deinit(allocator);
    }

    try std.testing.expectEqual(@as(std.meta.Tag(PhantomState), .state_union), @as(std.meta.Tag(PhantomState), state));
    const u = state.state_union;
    try std.testing.expectEqual(@as(usize, 2), u.members.len);

    try std.testing.expectEqualStrings("fs", u.members[0].module_path.?);
    try std.testing.expectEqualStrings("open", u.members[0].name);

    try std.testing.expectEqualStrings("fs", u.members[1].module_path.?);
    try std.testing.expectEqualStrings("closing", u.members[1].name);
}

test "parse mixed-module union" {
    const allocator = std.testing.allocator;

    // Real use case: accept file in either state from different pipelines
    const state = try PhantomState.parse(allocator, "fs:open|gzip:compressed");
    defer {
        var s = state;
        s.deinit(allocator);
    }

    try std.testing.expectEqual(@as(std.meta.Tag(PhantomState), .state_union), @as(std.meta.Tag(PhantomState), state));
    const u = state.state_union;
    try std.testing.expectEqual(@as(usize, 2), u.members.len);

    try std.testing.expectEqualStrings("fs", u.members[0].module_path.?);
    try std.testing.expectEqualStrings("open", u.members[0].name);

    try std.testing.expectEqualStrings("gzip", u.members[1].module_path.?);
    try std.testing.expectEqualStrings("compressed", u.members[1].name);
}

test "parse union with production marker - invalid" {
    const allocator = std.testing.allocator;

    // Unions cannot have production markers - they can't be output
    // A resource is always in ONE known state
    const result = PhantomState.parse(allocator, "open!|closing");
    try std.testing.expectError(error.InvalidPhantomState, result);
}

test "parse union with production marker on second member - invalid" {
    const allocator = std.testing.allocator;

    const result = PhantomState.parse(allocator, "open|closing!");
    try std.testing.expectError(error.InvalidPhantomState, result);
}

test "union matches concrete state" {
    const allocator = std.testing.allocator;

    const state = try PhantomState.parse(allocator, "open|closing");
    defer {
        var s = state;
        s.deinit(allocator);
    }

    const u = state.state_union;

    // Should match "open"
    const open_state = ConcreteState{ .module_path = null, .name = "open" };
    try std.testing.expect(u.matches(open_state));

    // Should match "closing"
    const closing_state = ConcreteState{ .module_path = null, .name = "closing" };
    try std.testing.expect(u.matches(closing_state));

    // Should NOT match "closed"
    const closed_state = ConcreteState{ .module_path = null, .name = "closed" };
    try std.testing.expect(!u.matches(closed_state));
}

test "union matches module-qualified concrete state" {
    const allocator = std.testing.allocator;

    const state = try PhantomState.parse(allocator, "fs:open|gzip:compressed");
    defer {
        var s = state;
        s.deinit(allocator);
    }

    const u = state.state_union;

    // Should match fs:open
    try std.testing.expect(u.matches(.{ .module_path = "fs", .name = "open" }));

    // Should match gzip:compressed
    try std.testing.expect(u.matches(.{ .module_path = "gzip", .name = "compressed" }));

    // Should NOT match fs:compressed (wrong state for module)
    try std.testing.expect(!u.matches(.{ .module_path = "fs", .name = "compressed" }));

    // Should NOT match open without module (module mismatch)
    try std.testing.expect(!u.matches(.{ .module_path = null, .name = "open" }));
}

test "areCompatible - union accepts matching concrete" {
    const allocator = std.testing.allocator;

    // Union requires open|closing, provide open → compatible
    try std.testing.expect(try areCompatible(allocator, "open|closing", "open"));

    // Union requires open|closing, provide closing → compatible
    try std.testing.expect(try areCompatible(allocator, "open|closing", "closing"));

    // Union requires open|closing, provide closed → NOT compatible
    try std.testing.expect(!try areCompatible(allocator, "open|closing", "closed"));
}

test "areCompatible - union with module qualifiers" {
    const allocator = std.testing.allocator;

    // Mixed module union
    try std.testing.expect(try areCompatible(allocator, "fs:open|gzip:compressed", "fs:open"));
    try std.testing.expect(try areCompatible(allocator, "fs:open|gzip:compressed", "gzip:compressed"));
    try std.testing.expect(!try areCompatible(allocator, "fs:open|gzip:compressed", "fs:compressed"));
}

test "areCompatible - concrete cannot accept union" {
    const allocator = std.testing.allocator;

    // Concrete requires open, provide union → NOT compatible
    // You can't provide ambiguity when certainty is required
    try std.testing.expect(!try areCompatible(allocator, "open", "open|closing"));
}

test "isStateUnion helper" {
    // Should detect unions
    try std.testing.expect(isStateUnion("open|closing"));
    try std.testing.expect(isStateUnion("!open|closing"));
    try std.testing.expect(isStateUnion("fs:open|gzip:compressed"));
    try std.testing.expect(isStateUnion("a|b|c"));

    // Should NOT detect these as unions
    try std.testing.expect(!isStateUnion("open")); // Single state
    try std.testing.expect(!isStateUnion("fs:open")); // Module-qualified
    try std.testing.expect(!isStateUnion("M'open|closing")); // State variable with constraints
    try std.testing.expect(!isStateUnion("M'_")); // State variable wildcard
}

// ============================================================================
// Class-join (`@`) tests — `name[!]@class[@class]*`: the name holds the
// first position and may carry `!`; every later part is a class, open
// vocabulary, sorted canonically.
// ============================================================================

test "parse class join - name!@class with cleanup" {
    const allocator = std.testing.allocator;

    const state = try PhantomState.parse(allocator, "scratch!@scoped");
    defer {
        var s = state;
        s.deinit(allocator);
    }

    try std.testing.expectEqual(@as(std.meta.Tag(PhantomState), .concrete), @as(std.meta.Tag(PhantomState), state));
    const concrete = state.concrete;
    try std.testing.expectEqualStrings("scratch", concrete.name);
    try std.testing.expect(concrete.requires_cleanup);
    try std.testing.expectEqual(@as(usize, 1), concrete.classes.len);
    try std.testing.expectEqualStrings("scoped", concrete.classes[0]);
    try std.testing.expect(concrete.hasClass("scoped"));
    try std.testing.expect(!concrete.hasClass("static"));
}

test "parse class join - class order is irrelevant, name position is not" {
    const allocator = std.testing.allocator;

    // Classes are a set: `a@b@c` and `a@c@b` are the same state.
    var a = try PhantomState.parse(allocator, "alloc@scoped@static");
    defer a.deinit(allocator);
    var b = try PhantomState.parse(allocator, "alloc@static@scoped");
    defer b.deinit(allocator);

    try std.testing.expectEqualStrings("alloc", a.concrete.name);
    try std.testing.expectEqualStrings("alloc", b.concrete.name);
    try std.testing.expect(a.concrete.hasClass("scoped"));
    try std.testing.expect(a.concrete.hasClass("static"));
    try std.testing.expect(b.concrete.hasClass("scoped"));
    try std.testing.expect(b.concrete.hasClass("static"));

    // But the name owns position one: `scoped@alloc` is name `scoped` +
    // class `alloc` — a different (legal) state, not a reordering.
    var c = try PhantomState.parse(allocator, "scoped@alloc");
    defer c.deinit(allocator);
    try std.testing.expectEqualStrings("scoped", c.concrete.name);
    try std.testing.expect(c.concrete.hasClass("alloc"));
    try std.testing.expect(!c.concrete.hasClass("scoped"));
}

test "parse class join - consume marker survives" {
    const allocator = std.testing.allocator;

    const state = try PhantomState.parse(allocator, "!scratch@scoped");
    defer {
        var s = state;
        s.deinit(allocator);
    }

    try std.testing.expectEqualStrings("scratch", state.concrete.name);
    try std.testing.expect(state.concrete.consumes_obligation);
    try std.testing.expect(state.concrete.hasClass("scoped"));
}

test "parse class join - module-qualified" {
    const allocator = std.testing.allocator;

    const state = try PhantomState.parse(allocator, "std/fmt:scratch!@scoped");
    defer {
        var s = state;
        s.deinit(allocator);
    }

    try std.testing.expectEqualStrings("std/fmt", state.concrete.module_path.?);
    try std.testing.expectEqualStrings("scratch", state.concrete.name);
    try std.testing.expect(state.concrete.requires_cleanup);
    try std.testing.expect(state.concrete.hasClass("scoped"));
}

test "parse class join - open vocabulary carries unknown classes" {
    const allocator = std.testing.allocator;

    // Classes are open: `@bogus` is a class tag a module may honor, not a
    // parse error — same late-mismatch model as typo'd state names.
    var state = try PhantomState.parse(allocator, "a@bogus");
    defer state.deinit(allocator);
    try std.testing.expectEqualStrings("a", state.concrete.name);
    try std.testing.expect(state.concrete.hasClass("bogus"));
    try std.testing.expect(!state.concrete.hasClass("scoped"));
}

test "parse class join - bang refuses on class parts and inside names" {
    const allocator = std.testing.allocator;

    // `!` binds the name atom only — it may not hang on a class
    // (`scoped@alloc!` refuses; write `alloc!@scoped`)...
    try std.testing.expectError(error.InvalidPhantomState, PhantomState.parse(allocator, "scoped@alloc!"));
    try std.testing.expectError(error.InvalidPhantomState, PhantomState.parse(allocator, "alloc@scoped!"));
    // ...nor live inside an identity (`scr!atch`) or a class part...
    try std.testing.expectError(error.InvalidPhantomState, PhantomState.parse(allocator, "scr!atch@scoped"));
    try std.testing.expectError(error.InvalidPhantomState, PhantomState.parse(allocator, "alloc@scop!ed"));
    // ...and a dangling `@` joins nothing, and `*` — the wildcard name —
    // is a marker, not a class.
    try std.testing.expectError(error.InvalidPhantomState, PhantomState.parse(allocator, "@scoped"));
    try std.testing.expectError(error.InvalidPhantomState, PhantomState.parse(allocator, "alloc@"));
    try std.testing.expectError(error.InvalidPhantomState, PhantomState.parse(allocator, "alloc@*"));
}

test "areCompatible - classed value fits base-named surface" {
    const allocator = std.testing.allocator;

    // Compatibility matches on the name part: `allocated@scoped` satisfies a
    // declared `allocated` (in-direction), and `scratch` fits `scratch@scoped`.
    try std.testing.expect(try areCompatible(allocator, "allocated", "allocated@scoped"));
    try std.testing.expect(try areCompatible(allocator, "scratch@scoped", "scratch"));
    // ...but identities still discriminate across names.
    try std.testing.expect(!try areCompatible(allocator, "view", "scratch@scoped"));
}