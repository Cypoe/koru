# 2104_02_uncommitted_tx — Mojo translation
#
# Faithful to this case's db.kz (family A, connected!/started!/active!):
#   connect  { host }                          -> *Connection<connected!>
#   begin    { conn: *<!connected|!active> }   -> *Transaction<started!>
#   exec     { tx: *<!started|!active>, sql }  -> *Transaction<active!>
#   commit   { tx: *<!active> }                -> *Connection<active!>
#   rollback { tx: *<!active> }                -> *Connection<active!>
#   close    { conn: *<!active> }              -> string
#
# Mojo mapping: one parametric type per resource, a Bool parameter per state —
#   Connection[False] = <connected!>   Connection[True] = <active!>
#   Tx[False]         = <started!>     Tx[True]         = <active!>
# `deinit self` = consume (Koru `<!state>`); `where Self.<param>` gates a
# method to one state (Koru `<!active>`-only parameter). begin/exec remint
# the state by returning a differently-parameterized value — Koru's
# consume-and-reissue.
#
# The program: connect, begin, then abandon the started transaction.
# Koru: MUST_ERROR "<started!> was not discharged" / "Call: exec"

@explicit_destroy("Connection must be closed via .close()")
struct Connection[used: Bool](Deinitable where False, Movable):
    var handle: Int

    def __init__(out self, handle: Int):
        self.handle = handle

    # Koru: conn: *Connection<!connected|!active> — unconstrained, any state.
    def begin(deinit self) -> Tx[False]:
        return Tx[False](self.handle)

    # Koru: conn: *Connection<!active> — gated to the used state.
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
    # tx is <started!> and never touched — exec/commit/rollback uncalled.
