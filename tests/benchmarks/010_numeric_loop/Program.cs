using System.Diagnostics;

// 010_numeric_loop — a generated Koru `for` loop driving a typed compute +
// a state write per element, vs the same work handwritten in C#. The
// generated arm calls the real emitted artifact: main_module.run_event.
// handler — compiled from output_emitted.cs into this assembly. If the
// emission shape changes, this file stops compiling; that is the pin.
//
// Arm semantics, identical work in every arm: work(i) = i*i+i, then add
// into an accumulator. `direct` keeps the accumulator in a register local;
// `direct-static` writes a static field per element — the honest twin of
// the generated program's `total` (module state is memory, not a local),
// so dispatch cost is not confused with accumulator residence.
static class Bench {
    const long N = 100_000_000;
    static long last_ms;
    static long cell;

    // GENERATED — the real emitted handler; the for/arms are emitted code.
    static long TimeGenerated() {
        KoruHost.total = 0;
        var sw = Stopwatch.StartNew();
        main_module.run_event.handler(new main_module.run_event.Input { n = N });
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return KoruHost.total;
    }

    // DIRECT — the atom: one fused handwritten loop, register accumulator.
    static long TimeDirect() {
        var sw = Stopwatch.StartNew();
        long sum = 0;
        for (long i = 0; i < N; i++) sum += i * i + i;
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return sum;
    }

    // DIRECT-STATIC — same loop, accumulator lives in a static field (the
    // memory residence a Koru module cell actually pays).
    static long TimeDirectStatic() {
        cell = 0;
        var sw = Stopwatch.StartNew();
        for (long i = 0; i < N; i++) cell += i * i + i;
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return cell;
    }

    // VIRTUAL — classic composition: Work+Acc behind an interface, two
    // virtual calls per element.
    interface IWork { long Work(long i); void Acc(long v); }
    class W : IWork {
        public long Work(long i) => i * i + i;
        public void Acc(long v) => cell += v;
    }
    static long TimeVirtual(IWork w) {
        cell = 0;
        var sw = Stopwatch.StartNew();
        for (long i = 0; i < N; i++) w.Acc(w.Work(i));
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return cell;
    }

    // DIRECT-INT — same register accumulator, int counter like the
    // emitted loop's (emitted `for` uses `var` over 0 → int).
    static long TimeDirectInt() {
        var sw = Stopwatch.StartNew();
        long sum = 0;
        for (int i = 0; i < N; i++) sum += (long)i * i + i;
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return sum;
    }

    // TWIN — the emitted shape, handwritten: int counter, per-iteration
    // call into a static work method, accumulate via a static method
    // writing a static field. What a person writing the same program
    // in the same shape would write.
    static long TwinWork(int i) => (long)i * i + i;
    static void TwinAcc(long v) => cell += v;
    static long TimeTwin() {
        cell = 0;
        var sw = Stopwatch.StartNew();
        for (int i = 0; i < N; i++) TwinAcc(TwinWork(i));
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return cell;
    }

    // FUNC — the composed-function idiom: a delegate call per element.
    static long TimeFunc(System.Func<long, long> f) {
        var sw = Stopwatch.StartNew();
        long sum = 0;
        for (long i = 0; i < N; i++) sum += f(i);
        sw.Stop();
        last_ms = sw.ElapsedMilliseconds;
        return sum;
    }

    static long RunOne(string name, System.Func<long> f) {
        var sum = f(); // warmup
        long best = long.MaxValue, bytes = 0;
        for (int rep = 0; rep < 3; rep++) {
            var b0 = System.GC.GetAllocatedBytesForCurrentThread();
            sum = f();
            bytes = System.GC.GetAllocatedBytesForCurrentThread() - b0;
            if (last_ms < best) best = last_ms;
        }
        if (sum != expected) {
            System.Console.WriteLine($"{name}: sum={sum} != {expected} — a hop did not run");
            System.Environment.Exit(1);
        }
        System.Console.WriteLine($"  {name,-16} {best,6} ms   {bytes / N,4} B/elem   sum={sum}");
        return best;
    }

    static long expected;

    public static int Main() {
        expected = TimeDirect(); // reference value; every arm must agree
        System.Console.WriteLine($"  {N} elements per rep, min of 3, work = i*i+i + accumulate");
        System.Console.WriteLine();
        RunOne("generated",     TimeGenerated);
        RunOne("twin",          TimeTwin);
        RunOne("func",          () => TimeFunc(i => i * i + i));
        RunOne("virtual",       () => TimeVirtual(new W()));
        RunOne("direct-static", TimeDirectStatic);
        RunOne("direct-int",    TimeDirectInt);
        RunOne("direct",        TimeDirect);
        System.Console.WriteLine();
        return 0;
    }
}
