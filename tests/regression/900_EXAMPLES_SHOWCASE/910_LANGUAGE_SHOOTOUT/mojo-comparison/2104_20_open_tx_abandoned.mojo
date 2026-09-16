# 2104_20_open_tx_abandoned — Mojo translation
#
# Family B model, identical to 2104_14.
#
# The program: open, begin — then the <started!> transaction is abandoned
# mid-flight (bound to `_`/dropped).
# Koru: MUST_ERROR "<started!> was not discharged" / "not discharged".

@explicit_destroy("Connection must be closed via .close()")
struct Connection[used: Bool](Deinitable where False, Movable):
    var handle: Int

    def __init__(out self, handle: Int):
        self.handle = handle

    def begin(deinit self) -> Tx[False]:
        return Tx[False](self.handle)

    def close(deinit self) where Self.used:
        print("Connection closed")


@explicit_destroy("Transaction must be finished via .commit() or .rollback()")
struct Tx[active: Bool](Deinitable where False, Movable):
    var conn_handle: Int

    def __init__(out self, conn_handle: Int):
        self.conn_handle = conn_handle

    def exec(deinit self, sql: String) -> Tx[True]:
        print("Executing:", sql)
        return Tx[True](self.conn_handle)

    def commit(deinit self) -> Connection[True] where Self.active:
        print("COMMIT")
        return Connection[True](self.conn_handle)

    def rollback(deinit self) -> Connection[True] where Self.active:
        print("ROLLBACK")
        return Connection[True](self.conn_handle)


def open(connstr: String) -> Connection[False]:
    return Connection[False](42)


def main():
    var conn = open("postgres://localhost/test")
    var tx = conn^.begin()
    # tx (Tx[False]) abandoned — never exec'd, never finished.
