# 2104_14_open_tx_commit_close — Mojo translation (positive control)
#
# Family B db.kz (the open_tx vocabulary): same state machine as 02/08/09,
# different names —
#   open(connstr) -> *Connection<connected!> | connection-failed
#   tx.begin { conn: *<!connected|!active> } -> *Transaction<started!>
#   tx.exec  { tx: *<!started|!active>, sql } -> *Transaction<active!>
#   tx.commit/tx.rollback { tx: *<!active> }  -> *Connection<active!>
#   close    { conn: *<!active> }
# `tx.begin`/`tx.exec`/… are module paths in Koru; in Mojo they are methods
# on the value (`conn^.begin()`, `tx^.exec(sql)`, …) — the same consume
# spelled at the call site by `^`.
#
# The program: the full happy path — open, begin, exec, commit, close.
# Koru: MUST_RUN — prints the three lines below, exit 0.

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
    conn2^.close()
