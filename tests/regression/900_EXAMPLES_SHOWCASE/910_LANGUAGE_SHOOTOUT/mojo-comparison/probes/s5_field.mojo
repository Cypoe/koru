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
struct Holder(Movable):
    var tx: Tx[True]
    def __init__(out self, var tx: Tx[True]):
        self.tx = tx^
def main():
    var h = Holder(begin()^.exec("x"))
    # h drops holding a live linear field — contagious or laundered?
