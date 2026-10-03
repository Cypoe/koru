using System.Threading.Channels;

var ch = Channel.CreateBounded<Src>(8);
var s = new Src { Id = 1 };
ch.Writer.TryWrite(s);
Console.WriteLine($"poisoned read {s.Id}");

class Src { public long Id; }
