# 2104_22_open_tx_exec_no_finish — Mojo translation
#
# Family B model, identical to 2104_14.
#
# The program: open, begin, exec — real work done, then the <active!>
# transaction is dropped without commit or rollback.
# Koru: MUST_ERROR "<active!> was not discharged. Call: tx.commit / tx.rollback"
# — and the diagnostic names only the dischargers; exec is NOT listed, because
# exec re-issues the obligation (net accounting nonzero). Mojo's refusal names
# whichever verbs the type author wrote into @explicit_destroy — the same
# words, but authored, not derived.

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
    # tx2 (Tx[True]) abandoned — work ran, but no commit or rollback.
