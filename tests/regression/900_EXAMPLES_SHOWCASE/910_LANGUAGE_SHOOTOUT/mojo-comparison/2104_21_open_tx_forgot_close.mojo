# 2104_21_open_tx_forgot_close — Mojo translation
#
# Family B model, identical to 2104_14. The program text is identical to
# 2104_15's — the difference is Koru-side: this test runs with
# --auto-discharge=disable (see its COMPILER_FLAGS), so the dropped
# <active!> connection is a refusal, not a synthesized close().
# Koru: MUST_ERROR "<active!> was not discharged" / "not discharged".
#
# Mojo has no auto-discharge flag to disable because there is no auto mode:
# a `Deinitable where False` value refuses abandonment on every CFG edge,
# unconditionally.

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
    # conn2 dropped — forgot close. Same program text as 2104_15.
