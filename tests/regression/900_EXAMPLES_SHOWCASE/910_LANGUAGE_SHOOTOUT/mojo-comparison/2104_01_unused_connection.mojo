# 2104_01_unused_connection — Mojo translation
#
# Faithful to this case's own db.kz (the older family-A vocabulary):
#   connect  { host }            -> *Connection<open!>
#   begin    { conn: *<!open> }  -> *Transaction<active!>
#   execute  { tx: *<active> }   -> { tx, result }   (borrow — tx stays alive)
#   commit   { tx: *<!active> }  -> void             ([!] default discharger)
#   rollback { tx: *<!active> }  -> void             ([!] alternative)
#
# Mojo mapping: a struct that is `Deinitable where False` cannot be dropped;
# `deinit self` methods are the named destructors — commit XOR rollback is
# "pick exactly one." A borrow is `self` (execute does not consume tx).
#
# The program: a connection is opened and never used.
# Koru: MUST_ERROR "<open!> was not discharged. Call: app.db:begin"

@explicit_destroy("Connection must be used via .begin()")
struct Connection(Deinitable where False, Movable):
    var handle: Int

    def __init__(out self, handle: Int):
        self.handle = handle

    def begin(deinit self) -> Transaction:
        return Transaction(self.handle)


struct QueryResult(ImplicitlyCopyable):
    var rows: Int

    def __init__(out self, rows: Int):
        self.rows = rows


@explicit_destroy("Transaction must be finished via .commit() or .rollback()")
struct Transaction(Deinitable where False, Movable):
    var conn_handle: Int

    def __init__(out self, conn_handle: Int):
        self.conn_handle = conn_handle

    # Koru execute borrows the tx; `self` here is a read borrow — the
    # obligation stays live on the caller's binding.
    def execute(self, sql: String) -> QueryResult:
        print("Executing:", sql)
        return QueryResult(1)

    def commit(deinit self):
        print("COMMIT")

    def rollback(deinit self):
        print("ROLLBACK")


def connect(host: String) -> Connection:
    return Connection(42)


def main():
    var conn = connect("localhost")
    # conn is never used — Koru's <open!> obligation undischarged.
