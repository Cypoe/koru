var fs = File.Create("/tmp/bakeoff_dotnet_dispose.txt");
fs.Dispose();
fs.WriteByte(1); // compiles — ObjectDisposedException at runtime
Console.WriteLine("done");
