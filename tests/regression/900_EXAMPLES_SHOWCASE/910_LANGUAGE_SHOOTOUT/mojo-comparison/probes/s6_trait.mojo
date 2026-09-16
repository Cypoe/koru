trait AnyTx(Movable):
    pass

struct Tx2[active: Bool](Deinitable where False, Movable, AnyTx):
    var conn_handle: Int
    def __init__(out self, conn_handle: Int):
        self.conn_handle = conn_handle
    def commit(deinit self) where Self.active:
        print("COMMIT")

def consume_it(var x: Some[AnyTx]):
    # x is an existential carrying a linear payload — can it just drop?
    pass

def main():
    var t = Tx2[True](42)
    consume_it(t^)
