# 2104_09_empty_transaction — Mojo translation
#
# Same model as 2104_02 (family A db.kz): commit() requires Tx[True]
# (<!active>), which only exec() can produce.
#
# The program: connect, begin, commit — without a single exec.
# Koru: MUST_ERROR "Phantom state mismatch" (<!active> demanded, <started!> held)

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
    var tx = conn^.begin()
    var conn2 = tx^.commit()  # Tx[False] — commit is gated to Tx[True]
    conn2^.close()
