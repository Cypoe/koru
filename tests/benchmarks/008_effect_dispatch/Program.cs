using System.Diagnostics;

// 008_effect_dispatch — one iteration of "call the tor, it fires its arm
// once, caller consumes the result" under each dispatch shape. Every arm's
// arm-body does the same work: fires++ on a shared static. The generated arm
// calls the REAL emitted method — main_module.beat_event.handler — compiled
// from output_emitted.cs into this assembly. If the emission shape changes
// (IOps renamed, handler signature changed), this file stops compiling; that
// is the pin, not a bug.
static class Bench {
    static long fires;
    static long last_ms;

    // GENERATED — the actual emitted artifact. BenchOps stands in for the
    // emitted per-site __koru_handlers_N struct (private nested, not
    // constructible from here); the JIT monomorphizes handler<BenchOps>
    // exactly as it does handler<__koru_handlers_N>.
    public struct BenchOps : main_module.beat_event.IOps {
        public global::System.Func<dynamic> tick { get; set; }
    }
    // GENERATED-SUBFLOW — `pulse` is the same tor shape with a pure-Koru
    // impl (`pulse = tick() => done 0`), so the emitter generates its
    // produce — the typed-envelope path: handler<H>(Input, H) -> Output.
    public struct PulseOps : main_module.pulse_event.IOps {
        public global::System.Func<dynamic> tick { get; set; }
    }

    // STRUCT-METHOD — the handwritten-idiomatic analogue of comptime __H:
    // generic-struct ops with void METHODS, typed input, typed return.
    public interface IOpsM { void tick(); }
    public struct MOps : IOpsM { public void tick() { fires++; } }
    public static int handlerM<H>(int input, H ops) where H : struct, IOpsM {
        ops.tick();
        return 0;
    }

    // VIRTUAL — the classic OOP idiom: interface call on a class.
    public interface IOpsV { void tick(); }
    public class VOps : IOpsV { public void tick() { fires++; } }
    public static int handlerV(int input, IOpsV ops) {
        ops.tick();
        return 0;
    }

    // ANON-FUNC — the previous k-sharp shape: dynamic anonymous object,
    // Func<dynamic> members, dynamic member access at every touch.
    public static dynamic handlerA(dynamic input, dynamic handlers) {
        var tick = handlers.tick;
        tick();
        return new { tag = "done", done = 0 };
    }

    // TYPED-FUNC — same IOps/Func-property surface as generated, but
    // statically typed payloads: isolates what `dynamic` itself costs.
    public interface IOpsT { global::System.Func<int> tick { get; } }
    public struct TOps : IOpsT { public global::System.Func<int> tick { get; set; } }
    public static int handlerT<H>(int input, H ops) where H : struct, IOpsT {
        var t = ops.tick;
        return t();
    }

    // TYPED-IO — same dispatch surface as generated (Func<dynamic> props on a
    // generic-struct ops) but input and result are real structs: no anonymous
    // allocations, no binder on the result read. A hypothesis arm — the shape
    // a typed-envelope emitter would produce — not current emission.
    public interface IOpsGT { global::System.Func<dynamic> tick { get; } }
    public struct GTOps : IOpsGT { public global::System.Func<dynamic> tick { get; set; } }
    public struct In { }
    public struct Out { public int done; }
    public static Out handlerGT<H>(In input, H ops) where H : struct, IOpsGT {
        var tick = ops.tick;
        tick();
        return new Out { done = 0 };
    }

    // DIRECT — the atom: a static call to a static body.
    static void tickD() { fires++; }
    static int beatD() { tickD(); return 0; }

    const int N = 30_000_000;

    static long TimeGenerated() {
        fires = 0;
        var sw = Stopwatch.StartNew();
        long sum = 0;
        for (int i = 0; i < N; i++) {
            var r = main_module.beat_event.handler(new main_module.beat_event.Input { }, new BenchOps {
                tick = (global::System.Func<dynamic>)(() => { fires++; return null; }),
            });
            sum += (int)r.done;
        }
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return sum;
    }
    static long TimeGenSubflow() {
        fires = 0;
        var sw = Stopwatch.StartNew();
        long sum = 0;
        for (int i = 0; i < N; i++) {
            var r = main_module.pulse_event.handler(new main_module.pulse_event.Input { }, new PulseOps {
                tick = (global::System.Func<dynamic>)(() => { fires++; return null; }),
            });
            sum += r.done;
        }
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return sum;
    }
    static long TimeStructMethod() {
        fires = 0;
        var sw = Stopwatch.StartNew();
        long sum = 0;
        for (int i = 0; i < N; i++) sum += handlerM(0, new MOps());
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return sum;
    }
    static long TimeVirtual(IOpsV ops) {
        fires = 0;
        var sw = Stopwatch.StartNew();
        long sum = 0;
        for (int i = 0; i < N; i++) sum += handlerV(0, ops);
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return sum;
    }
    static long TimeAnon() {
        fires = 0;
        var sw = Stopwatch.StartNew();
        long sum = 0;
        for (int i = 0; i < N; i++) {
            var r = handlerA(new { }, new { tick = (global::System.Func<dynamic>)(() => { fires++; return null; }) });
            sum += (int)r.done;
        }
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return sum;
    }
    static long TimeTypedFunc() {
        fires = 0;
        var sw = Stopwatch.StartNew();
        long sum = 0;
        for (int i = 0; i < N; i++) sum += handlerT(0, new TOps { tick = (global::System.Func<int>)(() => { fires++; return 0; }) });
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return sum;
    }
    static long TimeTypedIO() {
        fires = 0;
        var sw = Stopwatch.StartNew();
        long sum = 0;
        for (int i = 0; i < N; i++) sum += handlerGT(new In(), new GTOps { tick = (global::System.Func<dynamic>)(() => { fires++; return null; }) }).done;
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return sum;
    }
    static long TimeDirect() {
        fires = 0;
        var sw = Stopwatch.StartNew();
        long sum = 0;
        for (int i = 0; i < N; i++) sum += beatD();
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return sum;
    }
    // GEN-NOREAD — generated minus the `.done` dynamic member read: isolates
    // the DLR binder's share of the envelope cost.
    static long TimeGenNoRead() {
        fires = 0;
        var sw = Stopwatch.StartNew();
        long sum = 0;
        for (int i = 0; i < N; i++) {
            var r = main_module.beat_event.handler(new main_module.beat_event.Input { }, new BenchOps {
                tick = (global::System.Func<dynamic>)(() => { fires++; return null; }),
            });
            if (r != null) sum++;
        }
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return sum;
    }

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
        if (fires != N) { System.Console.WriteLine($"{name}: fires={fires} != {N} — arm did not run"); System.Environment.Exit(1); }
        System.Console.WriteLine($"  {name,-16} {best,6} ms   {bytes / N,4} B/call   sum={sum}");
        return best;
    }

    public static int Main() {
        var vops = new VOps();
        System.Console.WriteLine($"  {N} calls per rep, min of 3, arm body = fires++");
        System.Console.WriteLine();
        RunOne("generated",    TimeGenerated);
        RunOne("gen-subflow",  TimeGenSubflow);
        RunOne("typed-io",     TimeTypedIO);
        RunOne("typed-func",   TimeTypedFunc);
        RunOne("gen-noread",   TimeGenNoRead);
        RunOne("struct-method",TimeStructMethod);
        RunOne("virtual",      () => TimeVirtual(vops));
        RunOne("anon-func",    TimeAnon);
        RunOne("direct",       TimeDirect);
        System.Console.WriteLine();
        return 0;
    }
}
