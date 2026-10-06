using System.Diagnostics;
using System.Linq;
using System.Collections.Generic;

// 011_linq_task — the "Effect Branches vs LINQ" headline task, run on the
// cs backend: filter (when guard) -> map (* 3) -> sum (acc) over 1..N.
// The generated arm calls the REAL emitted method —
// main_module.run_event.handler — compiled from output_emitted.cs into
// this assembly. If the emission shape changes, this file stops
// compiling; that is the pin, not a bug.
//
// Comparator set (declared before running): LINQ on a materialized int[]
// is LINQ's best case; LINQ over lazy Enumerable.Range is the true
// source-equivalent — the Koru `for` materializes nothing either. The
// yield arm is the producer-side idiom. foreach over the array and the
// fused handwritten loop are the strong comparators — the LINQ post
// itself measured foreach BEATING Where().Select().Sum() on arrays, so
// racing only LINQ would rig the field.
//
// Every arm sums the same values, so every sum must equal the closed
// form — a stage that never ran shows up as a wrong result.
static class Bench {
    static long last_ms;
    const int N = 10_000_000;

    // GENERATED — the actual emitted artifact. run_event.handler is a
    // plain static method: acc is a ~proc splice, not an ops dispatch,
    // so there is no IOps surface here — the whole task is one call.
    static long TimeGenerated() {
        KoruHost.total = 0;
        var sw = Stopwatch.StartNew();
        main_module.run_event.handler(new main_module.run_event.Input { n = N });
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return KoruHost.total;
    }

    // LINQ-ARRAY — Where().Select().Sum() over a materialized int[]:
    // LINQ's best case, the array-specialized iterator path.
    static long TimeLinqArray(int[] data) {
        var sw = Stopwatch.StartNew();
        long sum = data.Where(x => x % 2 == 0).Select(x => x * 3L).Sum();
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return sum;
    }

    // LINQ-RANGE — the same pipeline over the lazy source: enumerator
    // hops for every element, no array specialization. This is the true
    // source-equivalent of `for(1..(n+1))` — neither materializes.
    static long TimeLinqRange() {
        var sw = Stopwatch.StartNew();
        long sum = Enumerable.Range(1, N)
            .Where(x => x % 2 == 0).Select(x => x * 3L).Sum();
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return sum;
    }

    // YIELD — a producer state machine feeding Select+Sum: the
    // producer-side LINQ idiom, per-element MoveNext + delegate hops.
    static IEnumerable<int> Evens(int n) {
        for (var i = 2; i <= n; i += 2) yield return i;
    }
    static long TimeYield() {
        var sw = Stopwatch.StartNew();
        long sum = Evens(N).Select(x => x * 3L).Sum();
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return sum;
    }

    // FOREACH — the hand loop over the materialized array: no operator
    // objects, but still one element visit + guard + multiply per item.
    static long TimeForeach(int[] data) {
        var sw = Stopwatch.StartNew();
        long sum = 0;
        foreach (var x in data) if (x % 2 == 0) sum += x * 3L;
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return sum;
    }

    // DIRECT — the atom: the fused handwritten loop over the range, no
    // array, no operators. What this task costs at the floor.
    static long TimeDirect() {
        var sw = Stopwatch.StartNew();
        long sum = 0;
        for (long i = 1; i <= N; i++)
            if (i % 2 == 0) sum += i * 3;
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return sum;
    }

    // Closed form: sum of 3*even over 1..N = 3 * 2 * (1 + … + N/2).
    static readonly long EXPECTED = 3L * (N / 2) * (N / 2 + 1);

    static long RunOne(string name, System.Func<long> f) {
        // Warmup rep, then 3 timed reps; min is the estimator (capacity,
        // not noise). The returned sum is the consumed result — live on
        // the value so nothing can be optimized away.
        var sum = f();
        long best = long.MaxValue, bytes = 0;
        for (int rep = 0; rep < 3; rep++) {
            var b0 = System.GC.GetAllocatedBytesForCurrentThread();
            sum = f();
            bytes = System.GC.GetAllocatedBytesForCurrentThread() - b0;
            if (last_ms < best) best = last_ms;
        }
        if (sum != EXPECTED) { System.Console.WriteLine($"{name}: sum={sum} != {EXPECTED} — stage did not run"); System.Environment.Exit(1); }
        System.Console.WriteLine($"  {name,-16} {best,6} ms   {bytes,6} B/rep   sum={sum}");
        return best;
    }

    public static int Main() {
        var data = Enumerable.Range(1, N).ToArray();
        System.Console.WriteLine($"  filter -> map -> sum over 1..{N}, min of 3 reps");
        System.Console.WriteLine();
        RunOne("generated",    TimeGenerated);
        RunOne("linq-array",   () => TimeLinqArray(data));
        RunOne("linq-range",   TimeLinqRange);
        RunOne("yield",        TimeYield);
        RunOne("foreach",      () => TimeForeach(data));
        RunOne("direct",       TimeDirect);
        System.Console.WriteLine();
        return 0;
    }
}
