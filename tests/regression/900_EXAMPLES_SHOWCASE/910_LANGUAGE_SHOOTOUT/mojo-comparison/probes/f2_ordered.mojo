# Ordered discharge: must call drain() THEN close() — never close alone,
# never drain alone, exactly that order. Encoded as a second phantom state.

@explicit_destroy("Pipe must be drained then closed")
struct Pipe[drained: Bool](Deinitable where False, Movable):
    var fd: Int
    def __init__(out self, fd: Int):
        self.fd = fd
    def drain(deinit self) -> Pipe[True] where not Self.drained:
        print("DRAIN")
        return Pipe[True](self.fd)
    def close(deinit self) where Self.drained:
        print("CLOSE")

def main():
    var p = Pipe[False](3)
    var p2 = p^.drain()
    p2^.close()
    # order swapped would be: p^.close() -> violated constraint
