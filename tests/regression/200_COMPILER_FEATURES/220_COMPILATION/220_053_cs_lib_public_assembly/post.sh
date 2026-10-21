#!/bin/bash
# koruc lib --lang=cs must produce a callable .NET assembly:
#   - csproj OutputType=Library (not Exe)
#   - a real <name>.dll artifact
#   - main_module declared public — internal would trap the public
#     <tor>_event classes inside the .dll, unreachable cross-assembly
#   - a separate consumer assembly references the .dll and calls
#     main_module.answer_event.handler() — the cross-assembly claim
#     the whole mode exists for.
# Skips cleanly where the .NET SDK is absent (same opt-in spirit as
# LANGUAGES=cs).

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
grep -q '<OutputType>Library</OutputType>' koru.csproj || {
    echo "FAIL: csproj is not OutputType=Library"
    exit 1
}
grep -q 'public static class main_module' output_emitted.cs || {
    echo "FAIL: main_module is not public — handlers unreachable cross-assembly"
    exit 1
}

# The source greps above prove shape; this fixture proves the claim —
# a separate .NET assembly references lib_out.dll and calls through.
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
var r = main_module.answer_event.handler(new main_module.answer_event.Input { });
System.Console.WriteLine($"answer={r}");
CS
dotnet build consumer -o consumer_out --nologo -v:q > consumer_build.log 2>&1 || {
    echo "FAIL: consumer project referencing lib_out.dll did not build"
    tail -10 consumer_build.log
    exit 1
}
consumer_out/consumer > consumer_actual.txt 2>&1 || {
    echo "FAIL: consumer apphost did not run"
    cat consumer_actual.txt
    exit 1
}
grep -q 'answer=42' consumer_actual.txt || {
    echo "FAIL: cross-assembly handler call returned wrong output"
    cat consumer_actual.txt
    exit 1
}
exit 0
