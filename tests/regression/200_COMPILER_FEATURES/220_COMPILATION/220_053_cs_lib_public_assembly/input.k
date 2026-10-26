// 220_053: `koruc lib --lang=cs` produces a callable .NET class library —
// the csproj flips to OutputType=Library and main_module goes public so
// its <tor>_event handler classes are reachable cross-assembly. An
// ASP.NET host drops output_emitted.cs into a project or references the
// .dll; main_module.answer_event.handler(...) is the callable surface.
// The zig run below is just the harness contract — post.sh drives the
// lib-mode compile and asserts the assembly shape.
import std/io

pub tor answer {} -> i64

proc answer|zig {
    return 42;
}

proc answer|cs {
    return 42;
}

std/io:print.ln("assembly")
