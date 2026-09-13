// Cross-target math builtins: the host-builtin family that lowers to
// `Math.*` in the JS emitter must produce identical numbers on both lanes —
// Zig builtins on one side, Math.* on the other, same source, same decimals.

import std/io

std/io:print("sin {{ @sin(0.5):d:.4 }} cos {{ @cos(0.5):d:.4 }} tan {{ @tan(0.5):d:.4 }}\n")
std/io:print("exp {{ @exp(1.0):d:.4 }} exp2 {{ @exp2(3.0):d:.4 }} log {{ @log(10.0):d:.4 }} log2 {{ @log2(8.0):d:.4 }} log10 {{ @log10(1000.0):d:.4 }}\n")
std/io:print("floor {{ @floor(1.7):d:.4 }} ceil {{ @ceil(1.2):d:.4 }} trunc {{ @trunc(-1.7):d:.4 }} sqrt {{ @sqrt(2.0):d:.4 }} abs {{ @abs(-3.5):d:.4 }}\n")
std/io:print("min {{ @min(1.0, 2.5):d:.4 }} max {{ @max(1.0, 2.5):d:.4 }}\n")
