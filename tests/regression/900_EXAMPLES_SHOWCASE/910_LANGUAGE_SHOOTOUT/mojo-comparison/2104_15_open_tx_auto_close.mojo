# 2104_15_open_tx_auto_close — Mojo translation
#
# Family B model, identical to 2104_14. The program is also identical to
# 2104_21's: open, begin, exec, commit — then the returned Connection[True]
# (<active!>) is bound to `_` and dropped.
#
# Koru: MUST_RUN — auto-discharge synthesizes the missing close() on the
# dropped obligation; the binary prints the same trace as 14.
#
# Mojo's regime is binary: `Deinitable where False` means a value can ONLY die
# by a named deinit; adding `__del__` would make every abandonment legal
# (Rust's Drop shape). There is no "prefer explicit, synthesize if absent" —
# the synthesis Koru performs here is the thing this model cannot express.

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
    var tx2 = tx^.exec("INSERT INTO users VALUES (1, 'alice')")
    var conn2 = tx2^.commit()
    # conn2 (Connection[True]) dropped here — Koru synthesizes close().
