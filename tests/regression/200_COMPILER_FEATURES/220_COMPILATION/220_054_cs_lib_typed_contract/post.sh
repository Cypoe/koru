#!/bin/bash
# 220_054: the cs lib surface must be TYPED end to end — the `dynamic`
# fallback only answers where the decl genuinely cannot name a type.
#   - the record-payload branch emits a generated payload struct and the
#     Output member carries it, not `dynamic`
#   - a correct typed consumer call compiles, runs, and reads the payload
#   - a WRONG-TYPED consumer call fails `dotnet build` — the negative pin:
#     under `dynamic` the same source compiled and detonated at the DLR
#     call-site cache (RuntimeBinderException) instead
# Skips cleanly where the .NET SDK is absent (same opt-in spirit as
# LANGUAGES=cs / 220_053).

if ! command -v dotnet >/dev/null 2>&1 || ! command -v koruc >/dev/null 2>&1; then
    echo "SKIP: dotnet or koruc not on PATH"
    exit 0
fi

koruc lib "$KORU_INPUT" --lang=cs -o lib_out > lib_compile.log 2>&1 || {
    echo "FAIL: koruc lib --lang=cs failed"
    tail -10 lib_compile.log
    exit 1
}
[ -f lib_out.dll ] || { echo "FAIL: lib_out.dll not produced"; exit 1; }

# Shape: the record payload is a generated struct nested in the event
# class, and the Output member carries it — `dynamic` would leave the
# member unbindable until runtime.
grep -q 'struct hit_payload' output_emitted.cs || {
    echo "FAIL: no generated hit_payload struct in output_emitted.cs"
    grep -n 'hit' output_emitted.cs
    exit 1
}
grep -q 'public hit_payload hit;' output_emitted.cs || {
    echo "FAIL: Output.hit is not typed hit_payload"
    grep -n 'public .* hit;' output_emitted.cs
    exit 1
}

# The positive consumer: a correct cross-assembly call through the typed
# payload — the same proof shape as 220_053, one member deeper.
mkdir -p consumer
cat > consumer/consumer.csproj <<'CS'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>disable</ImplicitUsings>
    <Nullable>disable</Nullable>
  </PropertyGroup>
  <ItemGroup>
    <Reference Include="lib_out">
      <HintPath>../lib_out.dll</HintPath>
    </Reference>
  </ItemGroup>
</Project>
CS
cat > consumer/Program.cs <<'CS'
var r = main_module.probe_event.handler(new main_module.probe_event.Input { });
System.Console.WriteLine($"hit.x={r.hit.x} hit.y={r.hit.y}");
CS
dotnet build consumer -o consumer_out --nologo -v:q > consumer_build.log 2>&1 || {
    echo "FAIL: typed consumer did not build"
    tail -10 consumer_build.log
    exit 1
}
consumer_out/consumer > consumer_actual.txt 2>&1 || {
    echo "FAIL: typed consumer apphost did not run"
    cat consumer_actual.txt
    exit 1
}
grep -q 'hit.x=40 hit.y=2' consumer_actual.txt || {
    echo "FAIL: typed payload read returned wrong values"
    cat consumer_actual.txt
    exit 1
}

# The negative pin: a consumer that reads a member the payload does not
# declare must fail at BUILD time. Under `dynamic` this compiled and the
# lie arrived as RuntimeBinderException at the call site instead.
mkdir -p consumer_bad
cat > consumer_bad/consumer_bad.csproj <<'CS'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>disable</ImplicitUsings>
    <Nullable>disable</Nullable>
  </PropertyGroup>
  <ItemGroup>
    <Reference Include="lib_out">
      <HintPath>../lib_out.dll</HintPath>
    </Reference>
  </ItemGroup>
</Project>
CS
cat > consumer_bad/Program.cs <<'CS'
var r = main_module.probe_event.handler(new main_module.probe_event.Input { });
System.Console.WriteLine($"nope={r.hit.nope}");
CS
if dotnet build consumer_bad -o consumer_bad_out --nologo -v:q > consumer_bad_build.log 2>&1; then
    echo "FAIL: wrong-typed consumer call compiled — the payload member is still dynamic"
    exit 1
fi
exit 0
