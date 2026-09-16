# Koru: string<open!> — an obligation atom riding a STDLIB type.
# Mojo: conformance is declared at the type — String is Deinitable forever,
# and you cannot remove a conformance you don't own. The only path is a
# wrapper — and the wrapper is what carries the law, not the payload.
# Probe: the payload can always be moved OUT of the wrapper, and once out,
# it is a plain droppable String again — the obligation never touched it.

struct LinearString(Deinitable where False, Movable):
    var payload: String
    def __init__(out self, var payload: String):
        self.payload = payload^
    def release(deinit self):
        print("released:", self.payload)
    def leak_payload(deinit self) -> String:
        return self.payload^     # the String walks out free

def main():
    var ls = LinearString("open!")
    var s = ls^.leak_payload()   # obligation died with the wrapper
    # s is a plain String — droppable, obligation-free
    print("payload escaped:", s)
