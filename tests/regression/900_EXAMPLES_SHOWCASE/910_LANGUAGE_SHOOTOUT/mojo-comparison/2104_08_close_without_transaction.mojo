# 2104_08_close_without_transaction — Mojo translation
#
# Same model as 2104_02 (family A db.kz): close() requires Connection[True]
# (<!active>), which only commit/rollback can produce.
#
# The program: connect, then close immediately — never began a transaction.
# Koru: MUST_ERROR "Phantom state mismatch" (<!active> demanded, <connected!> held)

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


def connect(host: String) -> Connection[False]:
    return Connection[False](42)


def main():
    var conn = connect("localhost")
    conn^.close()  # Connection[False] — close is gated to Connection[True]
