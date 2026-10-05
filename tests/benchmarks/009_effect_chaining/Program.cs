using System.Diagnostics;
using System.Linq;

// 009_effect_chaining — one iteration of "a value through K chained
// stages, summed" under each composition idiom. The generated arm calls
// the REAL emitted method — main_module.chain_event.handler — compiled
// from output_emitted.cs into this assembly: a pure-Koru impl whose
// `step(x): a |> step(a): b |> …` chain emits as K sequential calls
// through the struct-method shim. If the emission shape changes, this
// file stops compiling; that is the pin, not a bug.
//
// Every arm moves the same N values through the same K "+1" stages and
// sums — a benchmark whose arms do different work measures nothing.
static class Bench {
    static long last_ms;

    // GENERATED — the actual emitted artifact. ChainOps stands in for the
    // emitted per-site __koru_handlers_N struct; the JIT monomorphizes
    // handler<ChainOps> exactly as it does handler<__koru_handlers_N>.
    public struct ChainOps : main_module.chain_event.IOps {
        public long step(long v) { return v + 1; }
    }

    // VIRTUAL-CHAIN — classic OOP composition: an interface stage,
    // K virtual calls per element.
    public interface IStep { long Next(long v); }
    public class VStep : IStep { public long Next(long v) { return v + 1; } }

    const int N = 30_000_000;
    const int K = 8;

    static long TimeGenerated() {
        var sw = Stopwatch.StartNew();
        long sum = 0;
        for (long i = 0; i < N; i++)
            sum += main_module.chain_event.handler(new main_module.chain_event.Input { x = i }, new ChainOps()).done;
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return sum;
    }

    // DIRECT — the atom: the same K adds fused in a handwritten loop.
    static long TimeDirect() {
        var sw = Stopwatch.StartNew();
        long sum = 0;
        for (long i = 0; i < N; i++) {
            long v = i;
            v += 1; v += 1; v += 1; v += 1; v += 1; v += 1; v += 1; v += 1;
            sum += v;
        }
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return sum;
    }

    // LINQ — the canonical C# composition idiom: K chained Selects over
    // the N values, Sum consumes. Enumerators are built once per rep;
    // per element the cost is K MoveNext/Current hops + K delegate calls.
    static long TimeLinq() {
        var sw = Stopwatch.StartNew();
        long sum = Enumerable.Range(0, N)
            .Select(x => (long)x + 1).Select(x => x + 1).Select(x => x + 1)
            .Select(x => x + 1).Select(x => x + 1).Select(x => x + 1)
            .Select(x => x + 1).Select(x => x + 1)
            .Sum();
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return sum;
    }

    // FUNC-CHAIN — composition without enumerators: K delegate invokes
    // per element.
    static readonly global::System.Func<long, long> f1 = v => v + 1;
    static long TimeFuncChain() {
        var sw = Stopwatch.StartNew();
        long sum = 0;
        for (long i = 0; i < N; i++) {
            long v = i;
            v = f1(v); v = f1(v); v = f1(v); v = f1(v);
            v = f1(v); v = f1(v); v = f1(v); v = f1(v);
            sum += v;
        }
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return sum;
    }

    // VIRTUAL-CHAIN — K interface calls per element through one stage.
    static long TimeVirtual(IStep s) {
        var sw = Stopwatch.StartNew();
        long sum = 0;
        for (long i = 0; i < N; i++) {
            long v = i;
            v = s.Next(v); v = s.Next(v); v = s.Next(v); v = s.Next(v);
            v = s.Next(v); v = s.Next(v); v = s.Next(v); v = s.Next(v);
            sum += v;
        }
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return sum;
    }

    // Correctness control: every arm moves the same N values through the
    // same K stages, so every sum must equal the closed form. A stage that
    // never ran shows up here — the emitted chain produces x + K per call
    // only if all K hops actually fired.
    static readonly long EXPECTED = (long)N * (N - 1) / 2 + (long)N * K;
    static long RunOne(string name, System.Func<long> f) {
        // Warmup rep, then 3 timed reps; min is the estimator (capacity, not
        // noise). sum is the consumed result — live on the return value.
        var sum = f();
        long best = long.MaxValue, bytes = 0;
        for (int rep = 0; rep < 3; rep++) {
            var b0 = System.GC.GetAllocatedBytesForCurrentThread();
            sum = f();
            bytes = System.GC.GetAllocatedBytesForCurrentThread() - b0;
            if (last_ms < best) best = last_ms;
        }
        if (sum != EXPECTED) { System.Console.WriteLine($"{name}: sum={sum} != {EXPECTED} — stage did not run"); System.Environment.Exit(1); }
        System.Console.WriteLine($"  {name,-16} {best,6} ms   {bytes / N,4} B/call   sum={sum}");
        return best;
    }

    public static int Main() {
        System.Console.WriteLine($"  {N} values x {K} stages per rep, min of 3, stage = v + 1");
        System.Console.WriteLine();
        RunOne("generated",    TimeGenerated);
        RunOne("linq",         TimeLinq);
        RunOne("func-chain",   TimeFuncChain);
        RunOne("virtual",      () => TimeVirtual(new VStep()));
        RunOne("direct",       TimeDirect);
        System.Console.WriteLine();
        return 0;
    }
}
