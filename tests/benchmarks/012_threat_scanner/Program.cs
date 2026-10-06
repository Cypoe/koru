using System.Diagnostics;
using System.Linq;
using System.Collections.Generic;

// 012_threat_scanner — the literal code from the X post this work answers.
// ThreatScanner.LatestResults below is VERBATIM from the post's screenshot:
// a `Where` threshold filter, a `Select` string interpolation, a `ToList`
// materialize over IEnumerable<Session>.
//
// The generated arm is the real emitted artifact: task.k compiles with
// --lang=cs into output_emitted.cs, built INTO this assembly; the harness
// calls main_module.run_event.handler — the same method a real call site
// invokes. If the emission shape changes, this file stops compiling.
//
// Comparator set, declared before measuring:
//   linq-array  — the verbatim method over a materialized Session[]:
//                 LINQ's best case (array-specialized Where/Select).
//   linq-lazy   — the verbatim method over a yield producer: the
//                 IEnumerable signature literally as posted; the source
//                 is not materialized, matching our producer.
//   foreach     — handwritten loop over Session[] into List<string>.
//   direct      — derives the fields from i like the generated arm does
//                 (no Session objects) — the atom this task reduces to.
//   zig         — the SAME task.k compiled native (ReleaseFast), timed
//                 externally by run.sh; whole-process wall clock, so it
//                 carries process startup the .NET arms don't.
//
// Correctness control: every arm must produce identical count + total
// chars; a stage that never ran shows up as a wrong checksum.

public enum ThreatLevel { Low, Elevated, High, Critical }

public record Session(string IpAddress, int ThreatScore, ThreatLevel ThreatLevel);

public class ThreatScanner
{
    public List<string> LatestResults(IEnumerable<Session> activeSessions, int threshold)
    {
        return activeSessions
            .Where(s => s.ThreatScore >= threshold)
            .Select(s => $"{s.IpAddress} [{s.ThreatLevel}]")
            .ToList();
    }
}

static class Bench {
    static long last_ms;
    const int N = 10_000_000;
    const int Threshold = 40;

    static string LevelName(long l) => l switch {
        0 => "Low", 1 => "Elevated", 2 => "High", _ => "Critical",
    };

    static Session[] BuildSessions() {
        var a = new Session[N];
        for (long i = 0; i < N; i++)
            a[i] = new Session($"10.0.0.{i % 256}", (int)((i * 31) % 100), (ThreatLevel)(i % 4));
        return a;
    }

    // The lazy source: same values, no array — the IEnumerable producer
    // shape the posted signature actually accepts.
    static IEnumerable<Session> Produce() {
        for (long i = 0; i < N; i++)
            yield return new Session($"10.0.0.{i % 256}", (int)((i * 31) % 100), (ThreatLevel)(i % 4));
    }

    // GENERATED — the actual emitted artifact. Checksum is computed from
    // KoruHost.results AFTER the timer stops — identical accounting to the
    // LINQ/foreach arms (the method returns a list; we count it later).
    static (long count, long chars) TimeGenerated() {
        KoruHost.hits = 0; KoruHost.chars = 0; KoruHost.results.Clear();
        var sw = Stopwatch.StartNew();
        main_module.run_event.handler(new main_module.run_event.Input { n = N, threshold = Threshold });
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return Checksum(KoruHost.results);
    }

    // LINQ-ARRAY — the verbatim method over materialized sessions.
    static (long count, long chars) TimeLinqArray(Session[] sessions) {
        var scanner = new ThreatScanner();
        var sw = Stopwatch.StartNew();
        var r = scanner.LatestResults(sessions, Threshold);
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return Checksum(r);
    }

    // LINQ-LAZY — the verbatim method over the yield producer.
    static (long count, long chars) TimeLinqLazy() {
        var scanner = new ThreatScanner();
        var sw = Stopwatch.StartNew();
        var r = scanner.LatestResults(Produce(), Threshold);
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return Checksum(r);
    }

    // FOREACH — the handwritten collection consumer.
    static (long count, long chars) TimeForeach(Session[] sessions) {
        var sw = Stopwatch.StartNew();
        var r = new List<string>();
        foreach (var s in sessions)
            if (s.ThreatScore >= Threshold)
                r.Add($"{s.IpAddress} [{s.ThreatLevel}]");
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return Checksum(r);
    }

    // DIRECT — derives the fields from i like the generated arm; no
    // Session objects. The atom.
    static (long count, long chars) TimeDirect() {
        var sw = Stopwatch.StartNew();
        var r = new List<string>();
        for (long i = 0; i < N; i++) {
            if ((i * 31) % 100 >= Threshold)
                r.Add($"10.0.0.{i % 256} [{LevelName(i % 4)}]");
        }
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return Checksum(r);
    }

    static (long count, long chars) Checksum(List<string> r) {
        long chars = 0;
        foreach (var s in r) chars += s.Length;
        return (r.Count, chars);
    }

    public static int Main() {
        const int reps = 7;
        System.Console.WriteLine($"threat scanner: where -> interpolate -> tolist, N={N}, threshold={Threshold}, min of {reps} reps\n");

        // Session input built once, outside all timing — materializing it
        // is not part of the task; the LINQ arms' best case is a prebuilt
        // array.
        var sessions = BuildSessions();

        var table = new System.Text.StringBuilder();
        long want_count = -1, want_chars = -1;
        var arms = new (string name, System.Func<(long count, long chars)> f)[] {
            ("generated ", () => TimeGenerated()),
            ("linq-array", () => TimeLinqArray(sessions)),
            ("linq-lazy ", () => TimeLinqLazy()),
            ("foreach   ", () => TimeForeach(sessions)),
            ("direct    ", () => TimeDirect()),
        };

        foreach (var (name, f) in arms) {
            long best = long.MaxValue;
            (long count, long chars) res = (0, 0);
            for (int k = 0; k < reps; k++) { res = f(); if (last_ms < best) best = last_ms; }
            if (want_count < 0) { want_count = res.count; want_chars = res.chars; }
            else if (res.count != want_count || res.chars != want_chars) {
                System.Console.WriteLine($"CHECKSUM MISMATCH in {name}: ({res.count},{res.chars}) != ({want_count},{want_chars})");
                return 1;
            }
            table.AppendLine($"{name} {best,6} ms   hits={res.count} chars={res.chars}");
        }
        System.Console.Write(table);
        return 0;
    }
}
