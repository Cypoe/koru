// ga.k — native genetic composition fuzzer, in Koru.
//
// Lars's map, made literal: a GA's control flow is outcome dispatch, which
// is what a tor IS. `eval` emits clean/refused/spawn-failed; `classify`
// emits hit/miss; the `| arm` continuations ARE the selection operator —
// elites (hits) get recorded AND bred, cleans get bred, refused get culled.
// `@generation` is the generational back-edge; the filesystem is the
// population store (pop/g<N>/), so no language-level state is needed.
//
// Data prepared by scripts/ga_prep.py (bank/ frags, pop/g0 seeds,
// targets.txt = uncovered cells). Mutation reimplements the GP's
// hole-splice in Zig: pick a block-end in a survivor, insert a corpus frag.
//
// koruc spawn goes through `sh -c` and always exits 0 — reading
// result.term.Exited on a nonzero-exit+stderr child panics under koru
// (pinned bug 400_141); exit code + stderr are read from files instead.

import std/io

// ---------------------------------------------------------------- tors ---

tor scan { dir: string }
! entry string
| done { n: i64, dir: string }
| failed string

proc scan|zig {
    const std = @import("std");
    const a = std.heap.page_allocator;
    var d = std.fs.cwd().openDir(dir, .{ .iterate = true }) catch
        return .{ .failed = "openDir failed" };
    defer d.close();
    var it = d.iterate();
    var n: i64 = 0;
    while (it.next() catch null) |e| {
        if (e.kind != .file) continue;
        if (!std.mem.endsWith(u8, e.name, ".k")) continue;
        const full = std.fmt.allocPrint(a, "{s}/{s}", .{ dir, e.name }) catch continue;
        entry(full);
        n += 1;
    }
    return .{ .done = .{ .n = n, .dir = dir } };
}

tor eval { path: string }
| clean { path: string, cell: string }
| refused { path: string, sig: string }
| spawn-failed

proc eval|zig {
    const std = @import("std");
    const KORUC = "./zig-out/bin/koruc";
    const a = std.heap.page_allocator;
    const efile = std.fmt.allocPrint(a, "{s}.err", .{path}) catch return .{ .spawn_failed = .{} };
    const cfile = std.fmt.allocPrint(a, "{s}.code", .{path}) catch return .{ .spawn_failed = .{} };
    const cmd = std.fmt.allocPrint(a,
        "\"{s}\" -c \"{s}\" 2>\"{s}\"; printf %s $? >\"{s}\"",
        .{ KORUC, path, efile, cfile }) catch return .{ .spawn_failed = .{} };
    const res = std.process.Child.run(.{
        .allocator = a,
        .argv = &.{ "sh", "-c", cmd },
    }) catch return .{ .spawn_failed = .{} };
    defer a.free(res.stdout);
    defer a.free(res.stderr);
    const code_src = std.fs.cwd().readFileAlloc(a, cfile, 64) catch
        return .{ .spawn_failed = .{} };
    const code = std.fmt.parseInt(u8, std.mem.trim(u8, code_src, " \n\r"), 10) catch 255;
    const src = std.fs.cwd().readFileAlloc(a, path, 1 << 22) catch "";
    var cell: []const u8 = "?";
    if (std.mem.indexOf(u8, src, "// ga-cell: ")) |i| {
        const rest = src[i + 12 ..];
        const eol = std.mem.indexOfScalar(u8, rest, '\n') orelse rest.len;
        cell = std.mem.trim(u8, rest[0..eol], " \r\t");
    }
    if (code == 0) return .{ .clean = .{ .path = path, .cell = cell } };
    const sigsrc = std.fs.cwd().readFileAlloc(a, efile, 1 << 16) catch "";
    var sig: []const u8 = "?";
    var it = std.mem.splitScalar(u8, sigsrc, '\n');
    while (it.next()) |l| {
        // the error[] line is the verdict; hints trail it
        if (std.mem.indexOf(u8, l, "error[") != null) {
            sig = l;
            break;
        }
        if (std.mem.trim(u8, l, " \r").len > 0) sig = l;
    }
    return .{ .refused = .{ .path = path, .sig = sig[0..@min(sig.len, 140)] } };
}

tor classify { cell: string }
| hit
| miss

proc classify|zig {
    const std = @import("std");
    const TARGETS = ".kfuzz/ga/targets.txt";
    const a = std.heap.page_allocator;
    const data = std.fs.cwd().readFileAlloc(a, TARGETS, 1 << 16) catch
        return .{ .miss = .{} };
    var it = std.mem.splitScalar(u8, data, '\n');
    while (it.next()) |l| {
        if (std.mem.eql(u8, std.mem.trim(u8, l, " \r\t"), cell))
            return .{ .hit = .{} };
    }
    return .{ .miss = .{} };
}

tor breed { path: string }
| wrote string
| skipped
| failed

proc breed|zig {
    const std = @import("std");
    const BANK = ".kfuzz/ga/bank";
    const a = std.heap.page_allocator;
    const r0 = @as(u64, @intCast(std.time.nanoTimestamp())) ^
        std.hash.Wyhash.hash(0, path);
    var prng = std.Random.DefaultPrng.init(r0);
    const rand = prng.random();

    // 20% drift cull even on survivors — selection pressure beyond verdict
    if (rand.float(f32) < 0.2) return .{ .skipped = .{} };

    const src = std.fs.cwd().readFileAlloc(a, path, 1 << 22) catch
        return .{ .failed = .{} };

    // pick a frag from the bank
    var bd = std.fs.cwd().openDir(BANK, .{ .iterate = true }) catch
        return .{ .failed = .{} };
    defer bd.close();
    var names: [128][]const u8 = undefined;
    var nf: usize = 0;
    var bit = bd.iterate();
    while (bit.next() catch null) |e| {
        if (nf >= 128) break;
        if (e.kind != .file or !std.mem.endsWith(u8, e.name, ".frag")) continue;
        names[nf] = a.dupe(u8, e.name) catch continue;
        nf += 1;
    }
    if (nf == 0) return .{ .failed = .{} };
    const fname = names[rand.intRangeAtMost(usize, 0, nf - 1)];
    const fragctor = fname[0 .. std.mem.indexOf(u8, fname, "__") orelse fname.len];
    const frag = bd.readFileAlloc(a, fname, 1 << 18) catch return .{ .failed = .{} };

    // holes: a nonblank line at indent>0 followed by a shallower nonblank
    // line — insert at that line's indent (the block end, GP's own rule)
    var holes: [512]usize = undefined;   // byte offset after line i
    var ctxs: [512]usize = undefined;    // byte offset of ctx line
    var nh: usize = 0;
    var pos: usize = 0;
    var lines: [4096]usize = undefined;  // offsets of line starts
    var nlines: usize = 0;
    lines[nlines] = 0; nlines += 1;
    while (std.mem.indexOfScalarPos(u8, src, pos, '\n')) |nl| {
        lines[nlines] = nl + 1; nlines += 1;
        pos = nl + 1;
    }
    var zig_depth: i64 = 0;  // inside a proc|zig/|fpga/|mlir host body —
    // koru text spliced there is opaque to -c, i.e. a vacuous hit class
    var i: usize = 0;
    while (i + 1 < nlines and nh < 512) : (i += 1) {
        const ls = lines[i];
        const le = std.mem.indexOfScalarPos(u8, src, ls, '\n') orelse src.len;
        const line = src[ls..le];
        const lt = std.mem.trim(u8, line, " \r\t");
        if (zig_depth > 0) {
            for (lt) |ch| {
                if (ch == '{') zig_depth += 1;
                if (ch == '}') zig_depth -= 1;
            }
            continue;
        }
        if (std.mem.indexOf(u8, lt, "|zig") != null or
            std.mem.indexOf(u8, lt, "|fpga") != null or
            std.mem.indexOf(u8, lt, "|mlir") != null) {
            for (lt) |ch| {
                if (ch == '{') zig_depth += 1;
                if (ch == '}') zig_depth -= 1;
            }
            continue;
        }
        if (lt.len == 0) continue;
        const ind = line.len - lt.len;
        if (ind == 0) continue;
        // next nonblank line
        var j = i + 1;
        var next_ind: usize = 0;
        var found = false;
        while (j < nlines) : (j += 1) {
            const ns = lines[j];
            const ne = std.mem.indexOfScalarPos(u8, src, ns, '\n') orelse src.len;
            const nl2 = src[ns..ne];
            const nt = std.mem.trim(u8, nl2, " \r\t");
            if (nt.len == 0) continue;
            next_ind = nl2.len - nt.len;
            found = true;
            break;
        }
        if (found and next_ind < ind) {
            holes[nh] = le + 1;   // insert after this line
            ctxs[nh] = ind;
            nh += 1;
        }
    }
    if (nh == 0) return .{ .skipped = .{} };
    const h = rand.intRangeAtMost(usize, 0, nh - 1);
    const at = holes[h];
    const ind = ctxs[h];

    // ctx construct: walk up for the shallower line that opened the block
    var ctxname: []const u8 = "top";
    var k: usize = 0;
    while (k < nlines) : (k += 1) {
        const ls = lines[k];
        if (ls >= at) break;
        const le = std.mem.indexOfScalarPos(u8, src, ls, '\n') orelse src.len;
        const line = src[ls..le];
        const lt = std.mem.trim(u8, line, " \r\t");
        if (lt.len == 0) continue;
        if (line.len - lt.len < ind) {
            ctxname = blk: {
                if (std.mem.indexOf(u8, lt, "read-lines") != null or
                    std.mem.indexOf(u8, lt, "read_lines") != null) break :blk "read_lines";
                if (std.mem.indexOf(u8, lt, "std/store:") != null) break :blk "store";
                if (std.mem.indexOf(u8, lt, "for(") != null) break :blk "for_each";
                if (std.mem.indexOf(u8, lt, "if(") != null) break :blk "if_cond";
                if (std.mem.indexOf(u8, lt, "when(") != null) break :blk "when";
                if (std.mem.indexOf(u8, lt, "capture") != null) break :blk "capture";
                if (lt.len > 1 and lt[0] == '!') break :blk "effect_arm";
                if (lt.len > 1 and lt[0] == '|' and lt[1] != '>') break :blk "branch_arm";
                if (std.mem.indexOf(u8, lt, "|>") != null) break :blk "pipeline";
                if (std.mem.indexOf(u8, lt, "->") != null) break :blk "bare_return";
                break :blk "other";
            };
        }
    }

    // outdir = pop/g(N+1) derived from parent's own dir
    const pdir = std.fs.path.dirname(path) orelse return .{ .failed = .{} };
    const base = std.fs.path.basename(pdir);
    if (base.len < 2 or base[0] != 'g') return .{ .failed = .{} };
    const gen = std.fmt.parseInt(u32, base[1..], 10) catch return .{ .failed = .{} };
    const popdir = std.fs.path.dirname(pdir) orelse return .{ .failed = .{} };
    const outdir = std.fmt.allocPrint(a, "{s}/g{d}", .{ popdir, gen + 1 })
        catch return .{ .failed = .{} };
    std.fs.cwd().makePath(outdir) catch {};

    // splice: src[0..at] + reindented frag + src[at..]
    const cell = std.fmt.allocPrint(a, "{s}__{s}", .{ ctxname, fragctor })
        catch return .{ .failed = .{} };
    var out = std.ArrayList(u8){};
    defer out.deinit(a);
    out.appendSlice(a, "// ga-cell: ") catch return .{ .failed = .{} };
    out.appendSlice(a, cell) catch return .{ .failed = .{} };
    out.appendSlice(a, "\n") catch return .{ .failed = .{} };
    out.appendSlice(a, src[0..at]) catch return .{ .failed = .{} };
    var fit = std.mem.splitScalar(u8, frag, '\n');
    while (fit.next()) |fl| {
        if (std.mem.trim(u8, fl, " \r\t").len == 0) continue;
        var sp: usize = 0;
        while (sp < ind) : (sp += 1) out.append(a, ' ') catch return .{ .failed = .{} };
        out.appendSlice(a, std.mem.trimRight(u8, fl, "\r")) catch return .{ .failed = .{} };
        out.append(a, '\n') catch return .{ .failed = .{} };
    }
    out.appendSlice(a, src[at..]) catch return .{ .failed = .{} };
    const outpath = std.fmt.allocPrint(a, "{s}/c{d}_{s}__{s}.k",
        .{ outdir, rand.int(u32) % 100000, ctxname, fragctor })
        catch return .{ .failed = .{} };
    const of = std.fs.cwd().createFile(outpath, .{}) catch return .{ .failed = .{} };
    defer of.close();
    of.writeAll(out.items) catch return .{ .failed = .{} };
    return .{ .wrote = outpath };
}

tor record { path: string, cell: string }
| kept
| failed

proc record|zig {
    const std = @import("std");
    const FINDINGS = ".kfuzz/ga/findings";
    const a = std.heap.page_allocator;
    std.fs.cwd().makePath(FINDINGS) catch {};
    const dst = std.fmt.allocPrint(a, "{s}/{s}__{s}",
        .{ FINDINGS, cell, std.fs.path.basename(path) })
        catch return .{ .failed = .{} };
    const data = std.fs.cwd().readFileAlloc(a, path, 1 << 22) catch
        return .{ .failed = .{} };
    const f = std.fs.cwd().createFile(dst, .{}) catch return .{ .failed = .{} };
    defer f.close();
    f.writeAll(data) catch return .{ .failed = .{} };
    return .{ .kept = .{} };
}

tor nextgen { dir: string, max: i64 }
| next string
| exhausted

proc nextgen|zig {
    const std = @import("std");
    const a = std.heap.page_allocator;
    const base = std.fs.path.basename(dir);
    if (base.len < 2 or base[0] != 'g') return .{ .exhausted = .{} };
    const gen = std.fmt.parseInt(i64, base[1..], 10) catch
        return .{ .exhausted = .{} };
    if (gen + 1 > max) return .{ .exhausted = .{} };
    const popdir = std.fs.path.dirname(dir) orelse return .{ .exhausted = .{} };
    return .{ .next = std.fmt.allocPrint(a, "{s}/g{d}", .{ popdir, gen + 1 })
        catch return .{ .exhausted = .{} } };
}

// -------------------------------------------------------------- driver ---
// generation = scan each candidate → eval → classify → record/breed/cull.
// The fold idiom is corpus-proven (020_028): `#g` marks the step, `@g`
// re-invokes it with new args, and an arm producing `-> e` is the loop
// exit that satisfies the subflow's return — a bare `|>` continuation on
// the exit arm has no produce and the fold never terminates.

tor generation { dir: string, max: i64 } -> i64

generation = #g scan(dir)
! entry p |> eval(path: p)
    | clean c |> classify(c.cell)
        | hit |> std/io:print.ln(c.cell) |> record(c.path, c.cell)
            | kept |> breed(c.path)
                | wrote w |> std/io:print.ln(w)
                | skipped |> _
                | failed |> _
            | failed |> breed(c.path)
                | wrote w |> std/io:print.ln(w)
                | skipped |> _
                | failed |> _
        | miss |> breed(c.path)
            | wrote _ |> _
            | skipped |> _
            | failed |> _
    | refused r |> std/io:print.ln(r.sig)
    | spawn-failed |> std/io:print.ln("spawnfail")
| done d |> nextgen(d.dir, max)
    | next nd |> @g(dir: nd)
    | exhausted -> 0
| failed _ -> 1

generation(dir: ".kfuzz/ga/pop/g0", max: 5): _
|> std/io:print.ln("GA done")
