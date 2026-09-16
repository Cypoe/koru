@explicit_destroy("Tx must be finished via .commit() or .rollback()")
struct Tx[active: Bool](Deinitable where False, Movable):
    var conn_handle: Int
    def __init__(out self, conn_handle: Int):
        self.conn_handle = conn_handle
    def exec(deinit self, sql: String) -> Tx[True]:
        return Tx[True](self.conn_handle)
    def commit(deinit self) -> Int where Self.active:
        return self.conn_handle
    def rollback(deinit self) -> Int where Self.active:
        return self.conn_handle

def begin() -> Tx[False]:
    return Tx[False](42)
def main():
    var t = begin()          # Tx[False] arrives from another function
    var t2 = t^.exec("x")
    _ = t2^.commit()         # if this line is removed -> must fail
